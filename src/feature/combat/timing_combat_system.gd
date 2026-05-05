## TimingCombatSystem — 14-State Signal-Driven Combat FSM
##
## Orchestrates every encounter from first turn to final blow. Owns the turn
## order, round structure, and all resolution logic. Coordinates six downstream
## systems: InputTimingDetector (window dispatch), AbilitySystem (action
## resolution), EnemySystem (AI evaluation), StatusEffects (modifier queries),
## PartyCompositionManager (combatant roster), and AudioSystem (encounter audio).
##
## Implements: design/gdd/timing-combat-system.md
## Architecture: docs/architecture/adr-0006-combat-state-machine.md
##
## Story implementation map:
##   Story 001 — FSM skeleton, begin_encounter, TIMING_WINDOW CONNECT_ONE_SHOT,
##               ENCOUNTER_END cleanup (this file)
##   Story 002 — Turn order, TPR formula, SPD-descending sort
##   Story 003 — Damage formula, block mitigation, HP mutation, AbilitySystem wiring
##   Story 004 — PERFECT block counter
##   Story 005 — CC economy, cc_changed coalescing
##   Story 006 — Terminal condition checks, Victory/Defeat
##   Story 007 — Multi-hit, timing_optional, enemy self-buff
##   Story 008 — Enemy AI evaluation (EnemySystem wiring)
##   Story 009 — Edge cases: SPD min, status suppression
##   Story 010 — force_close_window audio calls, begin/end_combat_layer
##   Story 011 — CombatEventBus relay wiring
##
## Placement: Direct child of BattleSceneRoot (ADR-0006 Rule 4).
## All injected references are set by BattleSceneRoot before begin_encounter().
## TCS does NOT null-check injected references at call time — composition root
## is responsible for correct wiring.
##
## NEVER reference CombatEventBus by global name.
## NEVER call get_node("/root/...") — TCS is a leaf system.
class_name TimingCombatSystem extends Node

# ─── State Machine ─────────────────────────────────────────────────────────

## All 14 combat states. Transitions are documented in ADR-0006 Rule 1.
enum State {
	IDLE,
	ENCOUNTER_START,
	ROUND_START,
	TURN_START,
	TURN_SKIPPED,
	PLAYER_ACTION,
	TIMING_WINDOW,
	ACTION_RESOLVE,
	ENEMY_ACTION,
	BLOCK_WINDOW,
	BLOCK_RESOLVE,
	TURN_END,
	ROUND_END,
	ENCOUNTER_END
}

## Current FSM state. Read externally for testing; never set from outside TCS.
var _state: State = State.IDLE

# ─── Injected References (set by BattleSceneRoot before begin_encounter) ───

## Input & Timing Detection — window dispatch and test seams.
## Set by BattleSceneRoot._ready() via tcs.itd = $InputTimingDetector.
var itd: InputTimingDetector

## Ability System — action resolution. Story 003.
var as_: Node  # AbilitySystem — Story 003

## Enemy System — AI evaluation and enemy stat lookup. Story 008.
var es: Node  # EnemySystem — Story 008

## Status Effects — modifier queries and expiry. Story 009.
var se: Node  # StatusEffects — Story 009

## Party Composition Manager — active combatant roster.
var pcm: PartyCompositionManager

## Audio System — encounter-scoped audio events. Story 010.
var audio_system: Node  # AudioSystem — Story 010

# ─── Enemy HP (ADR-0006 Rule 3) ────────────────────────────────────────────

## Current HP for each enemy combatant, keyed by instance_id (101+).
## Owned by TCS for the duration of one encounter; cleared at ENCOUNTER_END.
var _enemy_hp: Dictionary[int, int] = {}

## Maximum HP for each enemy combatant, keyed by instance_id.
## Populated at ENCOUNTER_START and treated as read-only thereafter.
var _enemy_max_hp: Dictionary[int, int] = {}

## EnemyData references keyed by instance_id — used for encounter_state builds.
## Story 008 stub: populated at ENCOUNTER_START.
var _enemy_data_map: Dictionary[int, EnemyData] = {}  # Story 008

# ─── HP Danger Zone Tracking ───────────────────────────────────────────────

## Tracks whether each combatant has already crossed the 25% HP threshold
## this encounter. Toggled on crossing; re-emits if healed above then drops again.
var _hp_danger_zone_crossed: Dictionary[int, bool] = {}  # Story 003

# ─── Turn & Round State ────────────────────────────────────────────────────

## Ordered list of instance_ids for the current round's turn queue.
## Built at ROUND_START; entries consumed as turns complete.
var _turn_queue: Array[int] = []

## Index into _turn_queue for the currently active combatant.
var _active_queue_index: int = 0

## Party members cached from begin_encounter(). Used for instance_id mapping.
var _party_members: Array[CharacterData] = []

## Current round number. Starts at 1, increments at each ROUND_END.
## Reset to 0 at ENCOUNTER_END.
var _round_number: int = 0

## Party-wide Combo Charge. Clamped to [0, MAX_CHARGE]. Reset at ENCOUNTER_END.
## Story 005 stub: declared here, CC logic implemented in Story 005.
var _cc: int = 0  # Story 005

## Grade received from ITD for the current timing or block window.
var _current_grade: StringName = &""

# ─── Per-Action Transient State ────────────────────────────────────────────

## Ability ID selected by the player this turn. Set by submit_player_action().
var _pending_ability_id: StringName = &""

## Remaining hits for a multi-hit enemy ability. Story 007.
var _hits_remaining: int = 0  # Story 007

## Prevents multiple PERFECT counter emissions per ability. Story 004.
var _perfect_counter_fired: bool = false  # Story 004

## Pending CC delta accumulated across a single action resolution. Story 005.
var _pending_cc_delta: int = 0  # Story 005

# ─── Configuration Constants ───────────────────────────────────────────────

## Fallback action window size in frames before CharacterStatsUtil integration.
## Story 002 replaces this with the FLUX-based formula from CharacterStatsUtil.
const DEFAULT_ACTION_WINDOW_FRAMES: int = 8  # Story 002

# ─── Signals (ADR-0006 Rule 1; all declared, implemented per story) ─────────

## Emitted at ENCOUNTER_START after roster is built.
## Story 001 declares; Story 011 wires to CombatEventBus.
signal encounter_started(enemy_ids: Array[StringName])

## Emitted at ENCOUNTER_END before state is cleared.
## Story 006 drives victory/defeat logic; Story 011 wires to CombatEventBus.
signal encounter_ended(result: StringName)

## Emitted at TURN_START for the active combatant.
signal turn_started(combatant_id: int, is_player_turn: bool)

## Emitted at TURN_END for the combatant that just acted.
signal turn_ended(combatant_id: int)

## Emitted after damage is applied and HP is updated.
## Story 003 emits this; declared here for Story 011 wiring.
signal damage_dealt(target_id: int, amount: int, grade: StringName)

## Emitted when a combatant reaches HP = 0.
signal combatant_incapacitated(combatant_id: int, is_enemy: bool)

## Emitted the first time a combatant's HP crosses below 25% this encounter.
signal hp_danger_zone_entered(combatant_id: int)

## Emitted when a status condition is applied or removed from an enemy.
signal enemy_condition_changed(enemy_instance_id: int, condition: StringName)

## Emitted after any HP mutation. Carries old and new values for HUD display.
signal hp_changed(combatant_id: int, new_hp: int, max_hp: int, old_hp: int)

## Emitted when the turn queue is (re)built at ROUND_START.
signal turn_order_changed(ordered_ids: Array[int], active_id: int)

## Emitted when ITD opens a timing or block window.
signal timing_window_opened(mode: StringName, frames: int)

## Emitted after the grade from a timing or block window is resolved.
## NOT emitted for timing_optional abilities (GDD Rule 14).
signal grade_resolved(combatant_id: int, grade: StringName)

## Emitted when a PERFECT block triggers a counter opportunity. Story 004.
signal perfect_counter_started(blocker_id: int)

## Emitted when CC is spent by an ability. Story 005.
signal cc_spent(amount: int)

## Emitted once per action resolution after all CC gains are coalesced. Story 005.
signal cc_changed(new_cc: int, delta: int, source_type: StringName)

# ─── Public API ────────────────────────────────────────────────────────────

## Begin an encounter with the given party and enemy group.
##
## Transitions: IDLE → ENCOUNTER_START → ROUND_START → TURN_START → PLAYER_ACTION
## (or ENEMY_ACTION if the first combatant is an enemy).
##
## Guard: if _state is not IDLE, this call is a no-op. BattleSceneRoot must not
## call begin_encounter() while a previous encounter is still active.
##
## party: array of CharacterData, ordered by PCM slot (index 0 = slot 1).
## enemies: array of EnemyData, ordered by encounter slot (index 0 = slot 101).
func begin_encounter(party: Array[CharacterData], enemies: Array[EnemyData]) -> void:
	if _state != State.IDLE:
		push_warning("TimingCombatSystem.begin_encounter() called while not in IDLE (state=%s) — no-op." \
				% State.find_key(_state))
		return

	# ENCOUNTER_START — build roster, no combatant action taken here (AC-35)
	_state = State.ENCOUNTER_START
	_party_members = party
	_initialize_party_hp(party)
	_initialize_enemy_hp(enemies)
	_round_number = 1
	_cc = 0
	_active_queue_index = 0

	var enemy_ids: Array[StringName] = []
	for enemy: EnemyData in enemies:
		enemy_ids.append(enemy.id)
	encounter_started.emit(enemy_ids)

	# Advance to ROUND_START synchronously
	_process_round_start()


## Submit the player's chosen ability for the current turn.
##
## Guard: only valid in PLAYER_ACTION state. Calls from other states push a
## warning and return without changing state.
##
## ability_id: StringName matching an AbilityData.id in the Ability System.
## Story 001 stub: always transitions to TIMING_WINDOW regardless of ability flags.
## Story 003 adds timing_optional check: if ability.timing_optional, skip to ACTION_RESOLVE.
func submit_player_action(ability_id: StringName) -> void:
	if _state != State.PLAYER_ACTION:
		push_warning("TimingCombatSystem.submit_player_action() called outside PLAYER_ACTION (state=%s) — no-op." \
				% State.find_key(_state))
		return
	_pending_ability_id = ability_id
	_enter_timing_window()


## Force-close any open timing or block window with a MISS grade.
##
## Delegates to itd.force_close_window(), which emits input_result(mode, "MISS").
## The CONNECT_ONE_SHOT handler (_on_timing_grade_received or _on_block_grade_received)
## fires automatically, advancing TCS to ACTION_RESOLVE or BLOCK_RESOLVE with MISS.
##
## No-op if _state is not TIMING_WINDOW or BLOCK_WINDOW (ADR-0006 Rule 5).
## Story 010 adds audio calls around this (begin/end_combat_layer boundary).
func force_close_window() -> void:
	if _state not in [State.TIMING_WINDOW, State.BLOCK_WINDOW]:
		return
	itd.force_close_window()  # Story 010 — add audio call here

# ─── Private FSM Handlers ──────────────────────────────────────────────────

## ENCOUNTER_START → ROUND_START.
## Builds the turn queue using TPR formula and SPD-descending sort.
## Emits turn_order_changed, then immediately advances to TURN_START.
## Called at the start of every round (rounds are rebuilt from scratch each time).
func _process_round_start() -> void:
	_state = State.ROUND_START
	_active_queue_index = 0
	var living: Array[int] = _get_living_combatants()
	var spd_min: int = _compute_spd_min(living)
	_build_turn_queue(living, spd_min)
	if _turn_queue.is_empty():
		# All combatants incapacitated — should be caught by Story 006 terminal check
		_process_encounter_end(&"VICTORY")
		return
	turn_order_changed.emit(_turn_queue.duplicate(), _turn_queue[0])
	_process_turn_start()


## Returns instance_ids of all living combatants (HP > 0) in encounter order.
## Party slots first (1–N), then enemies (101+). Order is insertion order;
## SPD sorting happens in _build_turn_queue().
func _get_living_combatants() -> Array[int]:
	var living: Array[int] = []
	for i: int in range(_party_members.size()):
		if _party_members[i].hp_current > 0:
			living.append(i + 1)  # 1-based slot → instance_id
	for iid: int in _enemy_hp:
		if _enemy_hp[iid] > 0:
			living.append(iid)
	return living


## Returns the effective SPD of a combatant (party or enemy).
## Applies inheritance sum + status modifier via CharacterStatsUtil.effective_stat().
## For enemies, inheritance_sum is always 0 (enemies have no inheritance system).
func _get_effective_spd(instance_id: int) -> int:
	if instance_id <= 4:
		var member: CharacterData = _party_members[instance_id - 1]
		var inheritance_sum: int = 0
		for nio: NamedInheritanceObject in member.inheritances:
			if nio.stat == &"spd":
				inheritance_sum += nio.magnitude
		var status_mod: int = se.get_modifier(instance_id, &"spd")
		return CharacterStatsUtil.effective_stat(member.base_spd, inheritance_sum, status_mod)
	else:
		if not _enemy_data_map.has(instance_id):
			push_warning("TimingCombatSystem._get_effective_spd(): unknown instance_id %d" % instance_id)
			return 1
		var enemy: EnemyData = _enemy_data_map[instance_id]
		var status_mod: int = se.get_modifier(instance_id, &"spd")
		return CharacterStatsUtil.effective_stat(enemy.base_spd, 0, status_mod)


## Returns the minimum effective SPD across all living combatants.
## Used as the denominator base in the TPR formula.
func _compute_spd_min(living: Array[int]) -> int:
	if living.is_empty():
		return 1  # guard — never divide by zero in TPR
	var min_spd: int = 99
	for iid: int in living:
		var spd: int = _get_effective_spd(iid)
		if spd < min_spd:
			min_spd = spd
	return max(1, min_spd)  # clamp to [1, 99] — no zero denominator


## Computes Turns Per Round for a combatant.
## Formula: TPR = min(2, 1 + floor(spd_c / (spd_min × 1.5)))
## When all combatants have equal SPD: floor(spd / (spd × 1.5)) = floor(0.666) = 0 → TPR = 1.
## Result is clamped to [1, 2] — TPR is always at least 1.
func _compute_tpr(spd_c: int, spd_min: int) -> int:
	var threshold: float = float(spd_min) * 1.5
	return mini(2, 1 + int(float(spd_c) / threshold))


## Builds the frozen turn queue for the current round.
## Two-pass construction:
##   Pass 1: all living combatants, SPD descending (ties: lower instance_id first).
##   Pass 2: only combatants with TPR = 2, same sort order.
## The queue is frozen after this call; mid-round SPD changes do not affect it (AC-4).
func _build_turn_queue(living: Array[int], spd_min: int) -> void:
	_turn_queue.clear()
	if living.is_empty():
		return
	# Pre-compute SPD and TPR to avoid redundant calls inside sort comparator
	var spd_cache: Dictionary[int, int] = {}
	var tpr_cache: Dictionary[int, int] = {}
	for iid: int in living:
		var spd: int = _get_effective_spd(iid)
		spd_cache[iid] = spd
		tpr_cache[iid] = _compute_tpr(spd, spd_min)
	# Sort: SPD descending; ties broken by instance_id ascending
	# (party slot 1 < slot 2 < ... < enemy slot 1 < enemy slot 2)
	var sorted: Array[int] = living.duplicate()
	sorted.sort_custom(func(a: int, b: int) -> bool:
		var spd_a: int = spd_cache[a]
		var spd_b: int = spd_cache[b]
		if spd_a != spd_b:
			return spd_a > spd_b  # higher SPD sorts first
		return a < b              # lower instance_id wins ties
	)
	# Pass 1: every living combatant appears once
	for iid: int in sorted:
		_turn_queue.append(iid)
	# Pass 2: combatants with TPR = 2 appear a second time
	for iid: int in sorted:
		if tpr_cache[iid] == 2:
			_turn_queue.append(iid)


## ROUND_START → TURN_START.
## Sets TCS to the active combatant's state (PLAYER_ACTION or ENEMY_ACTION).
## Emits turn_started signal for HUD display.
## AC-6: incapacitated combatants (HP = 0) are silently skipped via TURN_SKIPPED.
## AC-7: combatants with an active stun/skip status are silently skipped via TURN_SKIPPED.
func _process_turn_start() -> void:
	_state = State.TURN_START
	if _active_queue_index >= _turn_queue.size():
		# Queue exhausted — should not happen under normal flow; go to ROUND_END
		_process_round_end()
		return

	var active_id: int = _turn_queue[_active_queue_index]
	var is_player_turn: bool = active_id <= 4  # Party IDs are 1–4 (ADR-0006 Rule 2)

	# AC-6: skip if combatant was incapacitated since the queue was built
	if _is_incapacitated(active_id):
		_process_turn_skipped()
		return

	# AC-7: skip if a status effect (STUNNED, etc.) requests a turn skip
	if se.check_turn_skip(active_id):
		_process_turn_skipped()
		return

	turn_started.emit(active_id, is_player_turn)

	if is_player_turn:
		_process_player_action()
	else:
		_process_enemy_action()


## TURN_START → PLAYER_ACTION.
## Sets state and returns. Waits for submit_player_action() call from HUD.
## Does NOT auto-advance — FSM is suspended here until player input (AC-36).
func _process_player_action() -> void:
	_state = State.PLAYER_ACTION
	# FSM suspends here. Resume path: submit_player_action() → _enter_timing_window()


## PLAYER_ACTION → TIMING_WINDOW.
## Connects to itd.input_result with CONNECT_ONE_SHOT and opens the action window.
## The FSM suspends here until ITD emits input_result (AC-37).
func _enter_timing_window() -> void:
	_state = State.TIMING_WINDOW
	itd.input_result.connect(_on_timing_grade_received, CONNECT_ONE_SHOT)
	var window_frames: int = _compute_action_window_frames()
	timing_window_opened.emit(&"ACTION", window_frames)
	itd.open_action_window(window_frames)


## TIMING_WINDOW → ACTION_RESOLVE.
## Fired by the CONNECT_ONE_SHOT connection on itd.input_result.
## The connection is automatically disconnected after this single emission (AC-37).
## Never transitions back to TIMING_WINDOW for the same turn.
func _on_timing_grade_received(mode: StringName, grade: StringName) -> void:
	_state = State.ACTION_RESOLVE
	_current_grade = grade
	_process_action_resolve()


## TURN_START → ENEMY_ACTION.
## Story 008 implements full enemy AI evaluation. Stub transitions directly to TURN_END.
func _process_enemy_action() -> void:  # Story 008
	_state = State.ENEMY_ACTION
	# Story 008 stub: real path calls es.evaluate_turn(instance_id, _build_encounter_state())
	# then opens a block window if the action targets party members.
	_process_turn_end()


## BLOCK_WINDOW → BLOCK_RESOLVE.
## Fired by CONNECT_ONE_SHOT connection on itd.input_result during enemy turns.
## Story 003/004/007 implement full block mitigation and PERFECT counter logic.
func _on_block_grade_received(_mode: StringName, _grade: StringName) -> void:  # Story 003
	_state = State.BLOCK_RESOLVE
	# Story 003 stub: real path applies damage mitigation based on grade
	_process_turn_end()


## ACTION_RESOLVE → TURN_END.
## Story 003 implements full damage formula, HP mutation, CC gain, status application.
## Stub passes through directly to _process_turn_end().
func _process_action_resolve() -> void:  # Story 003
	_state = State.ACTION_RESOLVE
	# Story 003 stub: real path calls as_.resolve_ability(...) and applies results
	# Story 005 stub: real path coalesces _pending_cc_delta and emits cc_changed
	_process_turn_end()


## ACTION_RESOLVE / BLOCK_RESOLVE → TURN_END.
## Story 002/006: real path checks terminal conditions and queue state.
## Stub: if queue is exhausted, go to ROUND_END; otherwise advance to next turn.
func _process_turn_end() -> void:  # Story 002, Story 006
	_state = State.TURN_END
	# Story 009 stub: real path ticks status effects on the active combatant here
	var active_id: int = _turn_queue[_active_queue_index] if _active_queue_index < _turn_queue.size() else 0
	if active_id != 0:
		turn_ended.emit(active_id)

	_active_queue_index += 1

	# Story 006 stub: real path checks terminal conditions (all enemies HP=0, all party HP=0)
	# For Story 001, go to ROUND_END when queue exhausted, else continue turns
	if _active_queue_index >= _turn_queue.size():
		_process_round_end()
	else:
		_process_turn_start()


## TURN_END → ROUND_END → ROUND_START.
## Increments the round counter and rebuilds the turn queue for the next round.
## Story 006: real path inserts a terminal condition check (Victory/Defeat) here
## before rebuilding the queue — placeholder skipped for now.
func _process_round_end() -> void:  # Story 006 adds terminal check
	_state = State.ROUND_END
	_round_number += 1
	# Story 006 stub: check all-enemy HP = 0 (VICTORY) or all-party HP = 0 (DEFEAT)
	_process_round_start()


## ROUND_END → ENCOUNTER_END → IDLE.
## Emits encounter_ended signal (Story 006/010), then clears all encounter state.
## After this method returns, _state = IDLE and all encounter data is gone (AC-38).
##
## result: &"VICTORY" or &"DEFEAT" (Story 006 drives which value is passed).
func _process_encounter_end(result: StringName) -> void:
	_state = State.ENCOUNTER_END
	# Story 006 stub: encounter_ended signal emission belongs here
	# Story 010 stub: audio_system.end_combat_layer() belongs here
	# encounter_ended.emit(result)  # Story 006

	# Clear all encounter state (AC-38)
	_enemy_hp.clear()
	_enemy_max_hp.clear()
	_enemy_data_map.clear()
	_turn_queue.clear()
	_hp_danger_zone_crossed.clear()
	_party_members.clear()
	_active_queue_index = 0
	_round_number = 0
	_cc = 0
	_pending_ability_id = &""
	_current_grade = &""
	_hits_remaining = 0
	_perfect_counter_fired = false
	_pending_cc_delta = 0
	_state = State.IDLE


## Returns true if the combatant has HP = 0.
## Used by _process_turn_start() to skip incapacitated queue slots (AC-6).
func _is_incapacitated(instance_id: int) -> bool:
	if instance_id <= 4:
		return _party_members[instance_id - 1].hp_current == 0
	return _enemy_hp.get(instance_id, 0) == 0


## TURN_START → TURN_SKIPPED → TURN_END.
## Entered when the active combatant is incapacitated (AC-6) or has a turn-skip
## status effect (AC-7). Emits no turn_started signal — the turn is consumed silently.
func _process_turn_skipped() -> void:
	_state = State.TURN_SKIPPED
	_process_turn_end()

# ─── Initialization Helpers ────────────────────────────────────────────────

## Initialize party member runtime HP from their base_hp at encounter start.
## Sets hp_current on each CharacterData reference obtained from BattleSceneRoot.
func _initialize_party_hp(party: Array[CharacterData]) -> void:
	for member: CharacterData in party:
		member.hp_current = member.base_hp


## Initialize enemy HP tables from EnemyData at encounter start (ADR-0006 Rule 3).
## Enemy instance_id = 100 + encounter_slot (1-based), so first enemy = 101.
func _initialize_enemy_hp(enemies: Array[EnemyData]) -> void:
	for i: int in range(enemies.size()):
		var instance_id: int = 101 + i
		_enemy_hp[instance_id] = enemies[i].base_hp
		_enemy_max_hp[instance_id] = enemies[i].base_hp
		_enemy_data_map[instance_id] = enemies[i]  # Story 008

# ─── Damage Application (Story 003) ────────────────────────────────────────

## Apply damage to an enemy combatant and emit hp_changed / combatant_incapacitated.
## Story 003 implements this; stub declared here to satisfy signal contract.
func _apply_damage_to_enemy(instance_id: int, amount: int) -> void:  # Story 003
	var old_hp: int = _enemy_hp[instance_id]
	_enemy_hp[instance_id] = maxi(0, old_hp - amount)
	hp_changed.emit(instance_id, _enemy_hp[instance_id], _enemy_max_hp[instance_id], old_hp)
	if old_hp > 0 and _enemy_hp[instance_id] == 0:
		combatant_incapacitated.emit(instance_id, true)


## Apply damage to a party member and emit hp_changed / combatant_incapacitated.
## Story 003 implements this; stub declared here to satisfy signal contract.
func _apply_damage_to_party_member(member: CharacterData, instance_id: int, amount: int) -> void:  # Story 003
	var old_hp: int = member.hp_current
	member.hp_current = maxi(0, old_hp - amount)
	hp_changed.emit(instance_id, member.hp_current, member.base_hp, old_hp)
	if old_hp > 0 and member.hp_current == 0:
		combatant_incapacitated.emit(instance_id, false)

# ─── Instance ID Helpers ────────────────────────────────────────────────────

## Map a CharacterData reference to its encounter instance_id (1-based slot index).
## Story 001: uses array index + 1 from _party_members cache.
## Story 002: replace with PCM slot lookup once turn ordering is wired.
func _party_instance_id(member: CharacterData) -> int:
	for i: int in range(_party_members.size()):
		if _party_members[i] == member:
			return i + 1
	push_error("TimingCombatSystem._party_instance_id(): CharacterData not found in _party_members")
	return -1

# ─── Window Frame Calculation (Story 002) ──────────────────────────────────

## Compute the action timing window width in frames for the active combatant.
## Uses CharacterStatsUtil.timing_window_frames(effective_flux) — Formula 2a (ADR-0007).
## The active combatant at timing window open is always a party member (player turn only).
## Guard: falls back to DEFAULT_ACTION_WINDOW_FRAMES for enemy active IDs (should not occur).
func _compute_action_window_frames() -> int:
	var active_id: int = _turn_queue[_active_queue_index]
	if active_id <= 4:
		var member: CharacterData = _party_members[active_id - 1]
		var inheritance_sum: int = 0
		for nio: NamedInheritanceObject in member.inheritances:
			if nio.stat == &"flux":
				inheritance_sum += nio.magnitude
		var status_mod: int = se.get_modifier(active_id, &"flux")
		var effective_flux: int = CharacterStatsUtil.effective_stat(member.base_flux, inheritance_sum, status_mod)
		return CharacterStatsUtil.timing_window_frames(effective_flux)
	# Guard: enemy IDs don't have FLUX — fall back to default
	push_warning("TimingCombatSystem._compute_action_window_frames(): active_id %d is not a party member" % active_id)
	return DEFAULT_ACTION_WINDOW_FRAMES

# ─── Enemy AI Snapshot (Story 008) ─────────────────────────────────────────

## Build a fresh encounter_state Dictionary for enemy AI evaluation.
## Called once per ENEMY_ACTION entry. Never reused or mutated between turns.
## Story 008 implements full wiring to EnemySystem; stub declared here for shape.
func _build_encounter_state(active_instance_id: int) -> Dictionary:  # Story 008
	var party_data: Array[Dictionary] = []
	for member: CharacterData in _party_members:
		var mid: int = _party_instance_id(member)
		party_data.append({
			"instance_id": mid,
			"hp_current": member.hp_current,
			"hp_max": member.base_hp,
			# Story 009 stub: active_effects wired when StatusEffects exists
			# "active_effects": se.get_active_effect_ids(mid)
			"active_effects": [] as Array[StringName]
		})

	var enemy_data: Array[Dictionary] = []
	for iid: int in _enemy_hp:
		if _enemy_hp[iid] > 0:
			enemy_data.append({
				"instance_id": iid,
				"enemy_id": _enemy_data_map[iid].id if _enemy_data_map.has(iid) else &"",
				"hp_current": _enemy_hp[iid],
				"hp_max": _enemy_max_hp[iid],
				# Story 009 stub: active_effects wired when StatusEffects exists
				# "active_effects": se.get_active_effect_ids(iid)
				"active_effects": [] as Array[StringName]
			})

	return {
		"round_number": _round_number,
		"living_party": party_data,
		"living_enemies": enemy_data,
		"active_instance_id": active_instance_id
	}

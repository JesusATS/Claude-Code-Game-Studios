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
##   Story 004 — PERFECT block counter ✓
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

## Terminal condition result. Story 006.
## Victory (all enemies incapacitated) is always checked before Defeat (AC-33).
enum TerminalResult {
	NONE,      ## Encounter continues — both sides have living combatants
	VICTORY,   ## All enemies at HP = 0 — checked first per GDD rule and AC-33
	DEFEAT     ## All party members at HP = 0
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

## Source type for the current pending CC delta. Tracks whether gains came from a timing
## window result or an ability's built-in cc_delta. Reset by _flush_cc(). Story 005.
var _pending_cc_source: StringName = &"window_grade"  # Story 005

## Full damage from the current enemy action before block mitigation. Story 003.
## Set at ENEMY_ACTION start; read at BLOCK_RESOLVE; cleared after block resolves.
var _pending_enemy_damage: int = 0  # Story 003

## Instance ID of the enemy whose action opened the current block window.
## Set when entering BLOCK_WINDOW; cleared at ENCOUNTER_END.
var _current_enemy_instance_id: int = 0  # Story 004

## Ability ID returned by EnemySystem for the current enemy turn.
## Used by _dispatch_block_status_payloads() to emit ability_resolved. Story 009.
var _current_enemy_ability_id: StringName = &""  # Story 009

## Party member instance_id designated as the blocker for the current block window.
## Single-target: first living party member. PARTY_ALL: lowest living instance_id (slot 1 default).
## Set when entering BLOCK_WINDOW; cleared at ENCOUNTER_END.
var _block_window_blocker_id: int = 0  # Story 004

## True when the current block window covers all living party members (PARTY_ALL ability).
## Set when entering BLOCK_WINDOW; cleared at ENCOUNTER_END.
var _block_window_is_party_all: bool = false  # Story 004

# ─── Configuration Constants ───────────────────────────────────────────────

## Fallback action window size in frames before CharacterStatsUtil integration.
## Story 002 replaces this with the FLUX-based formula from CharacterStatsUtil.
const DEFAULT_ACTION_WINDOW_FRAMES: int = 8  # Story 002

## Fallback block window size in frames when TEMPO data is unavailable.
const DEFAULT_BLOCK_WINDOW_FRAMES: int = 8

## Fraction of full damage taken on a HIT block (GDD Formula 3b). — TR-TCS-007.
## Configurable tuning knob — never hardcode this fraction in damage calculations.
const BLOCK_MITIGATION_FACTOR: float = 0.5

## HP fraction below which hp_danger_zone_entered is emitted (once per combatant per encounter).
const HP_DANGER_ZONE_THRESHOLD: float = 0.25

## Maximum Combo Charge a party can hold. Gains above this cap are discarded. Story 005.
## Configurable tuning knob — exported here for balance adjustment.
const MAX_CHARGE: int = 6

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
signal timing_window_opened(window_type: StringName, window_frames: int, actor_id: int)

## Emitted after the grade from a timing or block window is resolved.
## NOT emitted for timing_optional abilities (GDD Rule 14).
signal grade_resolved(combatant_id: int, grade: StringName)

## Emitted when a PERFECT block triggers a counter opportunity. Story 004.
signal perfect_counter_started(blocker_id: int)

## Emitted when CC is spent by an ability. Story 005.
signal cc_spent(amount: int)

## Emitted once per action resolution after all CC gains are coalesced. Story 005.
signal cc_changed(new_cc: int, delta: int, source_type: StringName)

## Emitted when an ability resolves with its final grade.
## StatusEffects connects to this with CONNECT_DEFAULT for synchronous application (ADR-0009).
## AC-56: never emitted on MISS attack. AC-41: never emitted on PERFECT block.
signal ability_resolved(ability_id: StringName, target_ids: Array[int], grade: StringName)

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
	audio_system.begin_combat_layer()  # AC-I4: called once at ENCOUNTER_START (Story 010)
	encounter_started.emit(enemy_ids)

	# Advance to ROUND_START synchronously
	_process_round_start()


## Submit the player's chosen ability for the current turn.
##
## Guard: only valid in PLAYER_ACTION state. Calls from other states push a
## warning and return without changing state.
##
## CC cost check: if as_ is wired and ability.cc_cost > _cc, returns early
## without advancing state (AC-29). No cc_spent emission on guard failure.
## If cc_cost > 0 and check passes: deducts CC, emits cc_spent before window (AC-57).
##
## ability_id: StringName matching an AbilityData.id in the Ability System.
func submit_player_action(ability_id: StringName) -> void:
	if _state != State.PLAYER_ACTION:
		push_warning("TimingCombatSystem.submit_player_action() called outside PLAYER_ACTION (state=%s) — no-op." \
				% State.find_key(_state))
		return
	_pending_ability_id = ability_id
	# CC cost check and deduction — only when AS is wired
	if as_ != null:
		var ability: Variant = as_.get_ability(ability_id)
		if ability != null:
			var cc_cost: int = int(ability.cc_cost) if "cc_cost" in ability else 0
			if cc_cost > _cc:
				return  # AC-29: insufficient CC — do not advance state
			if cc_cost > 0:
				_cc -= cc_cost
				cc_spent.emit(cc_cost)  # AC-57: emitted before window opens
			var is_timing_optional: bool = bool(ability.timing_optional) if "timing_optional" in ability else false
			if is_timing_optional:
				_enter_action_resolve_direct()
				return
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
	itd.force_close_window()

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


## PLAYER_ACTION → ACTION_RESOLVE (timing_optional path).
## For timing_optional abilities: grade = HIT internally; no timing window opens;
## grade_resolved is NOT emitted (GDD Rule 14 / AC-58).
## Sets _pending_cc_source to "ability_delta" before resolution so _process_action_resolve()
## knows to use ability cc_delta rather than grade-based CC.
func _enter_action_resolve_direct() -> void:
	_current_grade = &"HIT"
	_pending_cc_source = &"ability_delta"  # AC-58: source is ability, not window
	_state = State.ACTION_RESOLVE
	_process_action_resolve()


## PLAYER_ACTION → TIMING_WINDOW.
## Connects to itd.input_result with CONNECT_ONE_SHOT and opens the action window.
## The FSM suspends here until ITD emits input_result (AC-37).
func _enter_timing_window() -> void:
	_state = State.TIMING_WINDOW
	itd.input_result.connect(_on_timing_grade_received, CONNECT_ONE_SHOT)
	var window_frames: int = _compute_action_window_frames()
	timing_window_opened.emit(&"ACTION", window_frames, _turn_queue[_active_queue_index])
	itd.open_action_window(window_frames)


## ENEMY_ACTION / BLOCK_RESOLVE → BLOCK_WINDOW.
## Called for each hit of a multi-hit ability, including the first (AC-45, AC-51).
## Emits timing_window_opened once per entry (AC-51).
## Connects CONNECT_ONE_SHOT to avoid accumulating listeners across multi-hit cycles.
func _enter_block_window() -> void:
	_state = State.BLOCK_WINDOW
	var window_frames: int = _compute_block_window_frames()
	timing_window_opened.emit(&"BLOCK", window_frames, _current_enemy_instance_id)  # AC-51: once per BLOCK_WINDOW entry
	itd.input_result.connect(_on_block_grade_received, CONNECT_ONE_SHOT)
	itd.open_block_window(window_frames)


## TIMING_WINDOW → ACTION_RESOLVE.
## Fired by the CONNECT_ONE_SHOT connection on itd.input_result.
## The connection is automatically disconnected after this single emission (AC-37).
## Never transitions back to TIMING_WINDOW for the same turn.
func _on_timing_grade_received(mode: StringName, grade: StringName) -> void:
	_state = State.ACTION_RESOLVE
	_current_grade = grade
	_process_action_resolve()


## TURN_START → ENEMY_ACTION.
## Routes to BLOCK_WINDOW (targetted ability) or ACTION_RESOLVE (self-buff, AC-49).
## When EnemySystem is not yet wired (es == null), falls straight to TURN_END (Story 008 stub).
## AC-46: _perfect_counter_fired reset here so the flag is fresh for each new ability.
func _process_enemy_action() -> void:
	_state = State.ENEMY_ACTION
	_perfect_counter_fired = false  # Reset per-ability turn (AC-46)
	var active_id: int = _turn_queue[_active_queue_index]
	_current_enemy_instance_id = active_id
	if es != null:
		var result: Dictionary = es.evaluate_turn(active_id, _build_encounter_state(active_id))
		_current_enemy_ability_id = result.get("ability_id", &"")  # Story 009: track for status dispatch
		_hits_remaining = maxi(0, result.get("hit_count", 1) - 1)
		var targets: Array = result.get("targets", [])
		if targets.is_empty():
			_process_action_resolve_enemy_self_buff()  # AC-49: self-buff skips BLOCK_WINDOW
			return
		var first_target: CharacterData = _find_first_living_party_member()
		_block_window_blocker_id = _party_instance_id(first_target) if first_target != null else 0
		_block_window_is_party_all = result.get("is_party_all", false)
		var atk_eff: int = _get_effective_atk(active_id)
		var def_eff: int = 1
		if _block_window_blocker_id >= 1 and _block_window_blocker_id <= 4:
			def_eff = _get_effective_def(_block_window_blocker_id)
		_pending_enemy_damage = maxi(1, atk_eff - def_eff)
		_enter_block_window()
	else:
		_process_turn_end()  # Story 008 stub: no EnemySystem wired


## BLOCK_WINDOW → BLOCK_RESOLVE.
## Fired by CONNECT_ONE_SHOT connection on itd.input_result during enemy turns.
## Dispatches to single-target or PARTY_ALL resolver based on _block_window_is_party_all.
## Story 004 adds PERFECT counter logic. Story 007 adds multi-hit handling.
func _on_block_grade_received(_mode: StringName, grade: StringName) -> void:
	_state = State.BLOCK_RESOLVE
	if _block_window_is_party_all:
		_process_block_resolve_party_all(grade)
	else:
		_process_block_resolve_single(grade)


## BLOCK_RESOLVE for single-target enemy abilities.
## Applies block damage to the designated blocker, fires PERFECT counter if applicable,
## checks terminal condition (AC-20), then either loops back to BLOCK_WINDOW for
## multi-hit abilities (AC-45) or advances to TURN_END.
## If _block_window_blocker_id is 0 (not set), falls back to first living party member.
func _process_block_resolve_single(grade: StringName) -> void:
	var full_damage: int = _pending_enemy_damage  # Preserved for multi-hit loop (AC-45)
	var final_damage: int = _compute_block_damage(_pending_enemy_damage, grade)
	_pending_enemy_damage = 0
	# Resolve blocker: explicit id if set, else first living member
	var blocker_id: int = _block_window_blocker_id
	var blocker: CharacterData = null
	if blocker_id >= 1 and blocker_id <= 4:
		blocker = _party_members[blocker_id - 1]
	else:
		blocker = _find_first_living_party_member()
		if blocker != null:
			blocker_id = _party_instance_id(blocker)
	if blocker != null:
		_apply_damage_to_party_member(blocker, blocker_id, final_damage)
		damage_dealt.emit(blocker_id, final_damage, grade)
	var attacker_id: int = _current_enemy_instance_id if _current_enemy_instance_id > 0 \
			else (_turn_queue[_active_queue_index] if _active_queue_index < _turn_queue.size() else 0)
	grade_resolved.emit(attacker_id, grade)
	# AC-26/27: PERFECT block gains +1 CC; HIT and MISS gain 0 (AC-27)
	if grade == &"PERFECT":
		_accumulate_cc(1, &"window_grade")
	# AC-18: PERFECT block fires counter from the blocker
	if grade == &"PERFECT" and not _perfect_counter_fired and blocker_id > 0 and _current_enemy_instance_id > 0:
		_perfect_counter_fired = true
		_execute_perfect_counter(blocker_id, _current_enemy_instance_id)
		# AC-20: if encounter ended during counter, do not proceed to TURN_END
		if _state == State.IDLE:
			return
	# AC-41/42: PERFECT suppresses status payload; HIT and MISS dispatch it (GDD Rule 13)
	if grade != &"PERFECT":
		var targets: Array[int] = [blocker_id] if blocker_id > 0 else []
		_dispatch_block_status_payloads(_current_enemy_ability_id, targets, grade)
	_flush_cc()
	# AC-45: multi-hit loop — if hits remain, restore damage and open next BLOCK_WINDOW
	if _hits_remaining > 0:
		_hits_remaining -= 1
		_pending_enemy_damage = full_damage  # Restore for next hit
		_enter_block_window()
	else:
		_process_turn_end()


## BLOCK_RESOLVE for PARTY_ALL enemy abilities.
## One block window was opened; the grade applies uniformly to all living party members.
## PERFECT counter fires once from _block_window_blocker_id (AC-22).
func _process_block_resolve_party_all(grade: StringName) -> void:
	var full_damage: int = _pending_enemy_damage
	_pending_enemy_damage = 0
	# Apply grade to every living party member
	for member: CharacterData in _party_members:
		if member.hp_current > 0:
			var mid: int = _party_instance_id(member)
			var damage: int = _compute_block_damage(full_damage, grade)
			_apply_damage_to_party_member(member, mid, damage)
			damage_dealt.emit(mid, damage, grade)
	var attacker_id: int = _current_enemy_instance_id if _current_enemy_instance_id > 0 \
			else (_turn_queue[_active_queue_index] if _active_queue_index < _turn_queue.size() else 0)
	grade_resolved.emit(attacker_id, grade)
	# AC-26/27: PERFECT block gains +1 CC (PARTY_ALL: one window, one grade, one CC gain)
	if grade == &"PERFECT":
		_accumulate_cc(1, &"window_grade")
	# AC-22: PERFECT counter fires once from the designated blocker
	if grade == &"PERFECT" and not _perfect_counter_fired and _block_window_blocker_id > 0 and _current_enemy_instance_id > 0:
		_perfect_counter_fired = true
		_execute_perfect_counter(_block_window_blocker_id, _current_enemy_instance_id)
		if _state == State.IDLE:
			return
	# AC-41/42: PERFECT suppresses status payload; HIT and MISS dispatch it (GDD Rule 13)
	if grade != &"PERFECT":
		var targets: Array[int] = []
		for member: CharacterData in _party_members:
			if member.hp_current > 0:
				targets.append(_party_instance_id(member))
		_dispatch_block_status_payloads(_current_enemy_ability_id, targets, grade)
	_flush_cc()
	# AC-45: multi-hit loop — if hits remain, restore damage and open next BLOCK_WINDOW
	if _hits_remaining > 0:
		_hits_remaining -= 1
		_pending_enemy_damage = full_damage  # Restore for next hit
		_enter_block_window()
	else:
		_process_turn_end()


## Execute a free counter-attack from blocker_id against attacker_id at HIT grade.
## No timing window opens; damage uses basic_attack ability and HIT grade multiplier.
## Checks terminal condition after damage — transitions to ENCOUNTER_END if Victory.
## Caller is responsible for setting _perfect_counter_fired = true before calling.
func _execute_perfect_counter(blocker_id: int, attacker_id: int) -> void:
	if blocker_id < 1 or blocker_id > 4:
		push_warning("TimingCombatSystem._execute_perfect_counter(): blocker_id %d is not a party member" % blocker_id)
		return
	perfect_counter_started.emit(blocker_id)
	var blocker: CharacterData = _party_members[blocker_id - 1]
	var inheritance_sum: int = 0
	for nio: NamedInheritanceObject in blocker.inheritances:
		if nio.stat == &"atk":
			inheritance_sum += nio.magnitude
	var atk_mod: int = se.get_modifier(blocker_id, &"atk")
	var atk_eff: int = CharacterStatsUtil.effective_stat(blocker.base_atk, inheritance_sum, atk_mod)
	var def_eff: int = _get_effective_def(attacker_id)
	var damage_mult: float = 1.0
	if as_ != null:
		var ability: Variant = as_.get_ability(&"basic_attack")
		if ability != null:
			damage_mult = float(ability.damage_multiplier)
	var damage: int = _compute_attack_damage(atk_eff, def_eff, damage_mult, &"HIT")
	_apply_damage_to_enemy(attacker_id, damage)
	# AC-50: HIT attack from counter gains +1 CC (part of same BLOCK_RESOLVE accumulation)
	_accumulate_cc(1, &"window_grade")
	# AC-20/AC-31: victory if counter killed the last enemy
	var counter_terminal: TerminalResult = _check_terminal()
	if counter_terminal != TerminalResult.NONE:
		_state = State.ENCOUNTER_END
		_process_encounter_end(&"VICTORY" if counter_terminal == TerminalResult.VICTORY else &"DEFEAT")


## Returns the terminal condition for the current encounter state.
## Checks Victory (all enemies at HP = 0) before Defeat (all party at HP = 0)
## per AC-33 — if both sides are wiped simultaneously, Victory takes precedence.
func _check_terminal() -> TerminalResult:
	if _get_living_enemies().is_empty():
		return TerminalResult.VICTORY
	if _get_living_party_members().is_empty():
		return TerminalResult.DEFEAT
	return TerminalResult.NONE


## Returns instance IDs of enemies with HP > 0.
func _get_living_enemies() -> Array[int]:
	var living: Array[int] = []
	for iid: int in _enemy_hp:
		if _enemy_hp[iid] > 0:
			living.append(iid)
	return living


## Returns party members with hp_current > 0.
func _get_living_party_members() -> Array[CharacterData]:
	var living: Array[CharacterData] = []
	for member: CharacterData in _party_members:
		if member.hp_current > 0:
			living.append(member)
	return living


## ACTION_RESOLVE → TURN_END.
## Resolves player action: looks up ability from AS, computes attack damage using
## ATK/DEF effective stats and the timing grade multiplier, applies HP mutation.
## Story 005: accumulates grade-based CC (or ability cc_delta for timing_optional),
## then flushes exactly once via _flush_cc() before advancing to TURN_END.
## Story 009 adds status application.
func _process_action_resolve() -> void:
	_state = State.ACTION_RESOLVE
	var actor_id: int = _turn_queue[_active_queue_index]
	var atk_eff: int = _get_effective_atk(actor_id)
	var phm: float = _get_phm(actor_id)
	var damage_multiplier: float = 1.0
	var ability_cc_delta: int = 0
	if as_ != null:
		var ability: Variant = as_.get_ability(_pending_ability_id)
		if ability != null:
			damage_multiplier = float(ability.damage_multiplier)
			if "cc_delta" in ability:
				ability_cc_delta = int(ability.cc_delta)
	var target_id: int = _find_first_living_enemy()
	if target_id == -1:
		# AC-40: all enemies incapacitated after action selection — no-op (0 damage, 0 CC)
		_flush_cc()
		_process_turn_end()
		return
	var def_eff: int = _get_effective_def(target_id)
	var damage: int = _compute_attack_damage(atk_eff, def_eff, damage_multiplier, _current_grade, phm)
	_apply_damage_to_enemy(target_id, damage)
	damage_dealt.emit(target_id, damage, _current_grade)
	# Story 005: timing_optional path — no grade_resolved, CC from ability cc_delta only (AC-58)
	var is_timing_optional: bool = (_pending_cc_source == &"ability_delta")
	if is_timing_optional:
		if ability_cc_delta > 0:
			_accumulate_cc(ability_cc_delta, &"ability_delta")
	else:
		grade_resolved.emit(actor_id, _current_grade)
		# Grade-based CC gain (AC-23/24/25)
		match _current_grade:
			&"PERFECT":
				_accumulate_cc(2, &"window_grade")
			&"HIT":
				_accumulate_cc(1, &"window_grade")
			# MISS: no CC gain
	# AC-56: MISS suppresses status payload dispatch; HIT and PERFECT apply it
	if _current_grade != &"MISS":
		_dispatch_attack_status_payloads(_pending_ability_id, [target_id], _current_grade)
	_flush_cc()  # AC-50: emit cc_changed exactly once per resolution
	_process_turn_end()


## ENEMY_ACTION → ACTION_RESOLVE (self-buff / self-heal path).
## Entered when es.evaluate_turn() returns an empty targets array (AC-49).
## No damage is dealt to the party; no BLOCK_WINDOW opens; no player input is requested.
## Story 008 stub: real path would call as_.resolve_ability() to apply buffs/heals.
func _process_action_resolve_enemy_self_buff() -> void:
	_state = State.ACTION_RESOLVE
	# Story 008 stub: real path → as_.resolve_ability(_current_enemy_instance_id, &"", ability_id, &"HIT")
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

	# AC-31/32: check terminal before advancing queue
	var terminal: TerminalResult = _check_terminal()
	match terminal:
		TerminalResult.VICTORY:
			_state = State.ENCOUNTER_END
			_process_encounter_end(&"VICTORY")
			return
		TerminalResult.DEFEAT:
			_state = State.ENCOUNTER_END
			_process_encounter_end(&"DEFEAT")
			return

	_active_queue_index += 1

	if _active_queue_index >= _turn_queue.size():
		_process_round_end()
	else:
		_process_turn_start()


## TURN_END → ROUND_END → ROUND_START.
## Increments the round counter and rebuilds the turn queue for the next round.
## Story 006: defensive terminal check before queue rebuild catches any state
## that slipped through _process_turn_end() (e.g. TURN_SKIPPED paths).
func _process_round_end() -> void:
	_state = State.ROUND_END
	_round_number += 1
	# Defensive terminal check: catches any mid-round state that slipped through turn_end
	var terminal: TerminalResult = _check_terminal()
	if terminal == TerminalResult.VICTORY:
		_state = State.ENCOUNTER_END
		_process_encounter_end(&"VICTORY")
		return
	elif terminal == TerminalResult.DEFEAT:
		_state = State.ENCOUNTER_END
		_process_encounter_end(&"DEFEAT")
		return
	_process_round_start()


## ROUND_END → ENCOUNTER_END → IDLE.
## Emits encounter_ended signal (Story 006/010), then clears all encounter state.
## After this method returns, _state = IDLE and all encounter data is gone (AC-38).
##
## result: &"VICTORY" or &"DEFEAT" (Story 006 drives which value is passed).
func _process_encounter_end(result: StringName) -> void:
	_state = State.ENCOUNTER_END
	audio_system.end_combat_layer()  # AC-I5: called once at ENCOUNTER_END (ADR-0006 Rule 7: audio before signal)
	encounter_ended.emit(result)  # AC-31/32: emitted after audio teardown, before state is cleared

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
	_pending_cc_source = &"window_grade"
	_pending_enemy_damage = 0
	_current_enemy_instance_id = 0
	_current_enemy_ability_id = &""
	_block_window_blocker_id = 0
	_block_window_is_party_all = false
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

# ─── CC Economy (Story 005) ─────────────────────────────────────────────────

## Accumulate a CC delta during action resolution. Never call _cc directly —
## always go through this function so coalescing and source tracking work correctly.
## source: &"window_grade" (timing/block result) or &"ability_delta" (timing_optional).
## "window_grade" takes precedence: once set, no subsequent ability_delta call can override.
func _accumulate_cc(delta: int, source: StringName) -> void:
	_pending_cc_delta += delta
	if source == &"window_grade":
		_pending_cc_source = &"window_grade"
	elif _pending_cc_source != &"window_grade":
		_pending_cc_source = source


## Emit cc_changed exactly once with all accumulated CC for this resolution.
## Short-circuits if _pending_cc_delta == 0 (MISS attack, no-CC block, etc.).
## Resets accumulators after emission.
## Must be called once, at the very end of every complete action resolution.
func _flush_cc() -> void:
	if _pending_cc_delta == 0:
		_pending_cc_source = &"window_grade"  # Reset source for next resolution
		return
	var old_cc: int = _cc
	_cc = mini(_cc + _pending_cc_delta, MAX_CHARGE)
	var actual_delta: int = _cc - old_cc
	var emit_source: StringName = _pending_cc_source
	_pending_cc_delta = 0
	_pending_cc_source = &"window_grade"
	if actual_delta > 0:
		cc_changed.emit(_cc, actual_delta, emit_source)

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

## Apply damage to an enemy combatant.
## Emits hp_changed every call, combatant_incapacitated on reaching HP=0,
## and hp_danger_zone_entered the first time HP falls to or below 25% max.
func _apply_damage_to_enemy(instance_id: int, amount: int) -> void:
	var old_hp: int = _enemy_hp[instance_id]
	_enemy_hp[instance_id] = maxi(0, old_hp - amount)
	hp_changed.emit(instance_id, _enemy_hp[instance_id], _enemy_max_hp[instance_id], old_hp)
	if old_hp > 0 and _enemy_hp[instance_id] == 0:
		combatant_incapacitated.emit(instance_id, true)
		# AC-54: re-emit turn_order_changed immediately after incapacitation
		var active_id: int = _turn_queue[_active_queue_index] if _active_queue_index < _turn_queue.size() else 0
		turn_order_changed.emit(_get_living_combatants(), active_id)
	elif _enemy_hp[instance_id] > 0:
		# AC-55: track danger zone re-entry — reset flag when HP heals above threshold
		var threshold: int = maxi(1, int(float(_enemy_max_hp[instance_id]) * HP_DANGER_ZONE_THRESHOLD))
		var below_threshold: bool = _enemy_hp[instance_id] <= threshold
		var was_below: bool = _hp_danger_zone_crossed.get(instance_id, false)
		if below_threshold and not was_below:
			_hp_danger_zone_crossed[instance_id] = true
			hp_danger_zone_entered.emit(instance_id)
		elif not below_threshold and was_below:
			_hp_danger_zone_crossed[instance_id] = false  # AC-55: reset for next crossing


## Apply damage to a party member.
## Emits hp_changed every call, combatant_incapacitated on reaching HP=0,
## and hp_danger_zone_entered the first time HP falls to or below 25% max.
func _apply_damage_to_party_member(member: CharacterData, instance_id: int, amount: int) -> void:
	var old_hp: int = member.hp_current
	member.hp_current = maxi(0, old_hp - amount)
	hp_changed.emit(instance_id, member.hp_current, member.base_hp, old_hp)
	if old_hp > 0 and member.hp_current == 0:
		combatant_incapacitated.emit(instance_id, false)
		# AC-54: re-emit turn_order_changed immediately after incapacitation
		var active_id: int = _turn_queue[_active_queue_index] if _active_queue_index < _turn_queue.size() else 0
		turn_order_changed.emit(_get_living_combatants(), active_id)
	elif member.hp_current > 0:
		# AC-55: track danger zone re-entry — reset flag when HP heals above threshold
		var threshold: int = maxi(1, int(float(member.base_hp) * HP_DANGER_ZONE_THRESHOLD))
		var below_threshold: bool = member.hp_current <= threshold
		var was_below: bool = _hp_danger_zone_crossed.get(instance_id, false)
		if below_threshold and not was_below:
			_hp_danger_zone_crossed[instance_id] = true
			hp_danger_zone_entered.emit(instance_id)
		elif not below_threshold and was_below:
			_hp_danger_zone_crossed[instance_id] = false  # AC-55: reset for next crossing

# ─── Damage Formulas (Story 003) ───────────────────────────────────────────

## Attack damage formula (GDD Formula 3a). — TR-TCS-007.
## MISS → 0. PERFECT → grade_multiplier = phm. HIT → grade_multiplier = 1.0.
## floor() applied to the ENTIRE product — never to intermediate results.
## phm = 1.0 by default (selects HIT behaviour when not specified).
func _compute_attack_damage(
		atk_eff: int,
		def_eff: int,
		damage_multiplier: float,
		grade: StringName,
		phm: float = 1.0) -> int:
	if grade == &"MISS":
		return 0
	var grade_multiplier: float = phm if grade == &"PERFECT" else 1.0
	return floori(maxf(1.0, float(atk_eff - def_eff)) * damage_multiplier * grade_multiplier)


## Block mitigation formula (GDD Formula 3b). — TR-TCS-007.
## PERFECT → 0 damage. HIT → floor(full_damage × BLOCK_MITIGATION_FACTOR). MISS → full damage.
func _compute_block_damage(full_damage: int, grade: StringName) -> int:
	match grade:
		&"PERFECT":
			return 0
		&"HIT":
			return floori(float(full_damage) * BLOCK_MITIGATION_FACTOR)
		_:
			return full_damage  # MISS = no mitigation


## Returns effective ATK for a combatant (party or enemy) after inheritance sums and status modifiers.
func _get_effective_atk(instance_id: int) -> int:
	if instance_id <= 4:
		var member: CharacterData = _party_members[instance_id - 1]
		var inheritance_sum: int = 0
		for nio: NamedInheritanceObject in member.inheritances:
			if nio.stat == &"atk":
				inheritance_sum += nio.magnitude
		var status_mod: int = se.get_modifier(instance_id, &"atk")
		return CharacterStatsUtil.effective_stat(member.base_atk, inheritance_sum, status_mod)
	if not _enemy_data_map.has(instance_id):
		push_warning("TimingCombatSystem._get_effective_atk(): unknown instance_id %d" % instance_id)
		return 1
	var enemy: EnemyData = _enemy_data_map[instance_id]
	var status_mod: int = se.get_modifier(instance_id, &"atk")
	return CharacterStatsUtil.effective_stat(enemy.base_atk, 0, status_mod)


## Returns effective DEF for a combatant (party or enemy) after inheritance sums and status modifiers.
func _get_effective_def(instance_id: int) -> int:
	if instance_id <= 4:
		var member: CharacterData = _party_members[instance_id - 1]
		var inheritance_sum: int = 0
		for nio: NamedInheritanceObject in member.inheritances:
			if nio.stat == &"def":
				inheritance_sum += nio.magnitude
		var status_mod: int = se.get_modifier(instance_id, &"def")
		return CharacterStatsUtil.effective_stat(member.base_def, inheritance_sum, status_mod)
	if not _enemy_data_map.has(instance_id):
		push_warning("TimingCombatSystem._get_effective_def(): unknown instance_id %d" % instance_id)
		return 1
	var enemy: EnemyData = _enemy_data_map[instance_id]
	var status_mod: int = se.get_modifier(instance_id, &"def")
	return CharacterStatsUtil.effective_stat(enemy.base_def, 0, status_mod)


## Returns the actor's perfect_hit_multiplier from CharacterData.
## Only party members (instance_id 1–4) have PHM — enemies always return 1.0.
func _get_phm(actor_id: int) -> float:
	if actor_id >= 1 and actor_id <= 4:
		return _party_members[actor_id - 1].perfect_hit_multiplier
	return 1.0


## Returns the instance_id of the first living enemy, or -1 if none are living.
func _find_first_living_enemy() -> int:
	for iid: int in _enemy_hp:
		if _enemy_hp[iid] > 0:
			return iid
	return -1


## Returns the first living party member, or null if all are incapacitated.
func _find_first_living_party_member() -> CharacterData:
	for member: CharacterData in _party_members:
		if member.hp_current > 0:
			return member
	return null


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


## Compute the block window width in frames for the current enemy attacker.
## Uses EnemyData.base_tempo + status modifier via CharacterStatsUtil.block_window_frames().
## Falls back to DEFAULT_BLOCK_WINDOW_FRAMES when TEMPO data is unavailable (Story 007).
func _compute_block_window_frames() -> int:
	if _current_enemy_instance_id > 0 and _enemy_data_map.has(_current_enemy_instance_id):
		var enemy: EnemyData = _enemy_data_map[_current_enemy_instance_id]
		var status_mod: int = se.get_modifier(_current_enemy_instance_id, &"tempo")
		var effective_tempo: int = CharacterStatsUtil.effective_stat(enemy.base_tempo, 0, status_mod)
		return CharacterStatsUtil.block_window_frames(effective_tempo)
	return DEFAULT_BLOCK_WINDOW_FRAMES

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
			"active_effects": se.get_active_effect_ids(mid)  # Story 009: wired
		})

	var enemy_data: Array[Dictionary] = []
	for iid: int in _enemy_hp:
		if _enemy_hp[iid] > 0:
			enemy_data.append({
				"instance_id": iid,
				"enemy_id": _enemy_data_map[iid].id if _enemy_data_map.has(iid) else &"",
				"hp_current": _enemy_hp[iid],
				"hp_max": _enemy_max_hp[iid],
				"active_effects": se.get_active_effect_ids(iid)  # Story 009: wired
			})

	return {
		"round_number": _round_number,
		"living_party": party_data,
		"living_enemies": enemy_data,
		"active_instance_id": active_instance_id
	}

# ─── Status Payload Dispatch (Story 009) ────────────────────────────────────

## Emit ability_resolved for a player attack action.
## StatusEffects connects to ability_resolved with CONNECT_DEFAULT (ADR-0009).
## AC-56: called only when grade != MISS — MISS suppresses all status payloads.
func _dispatch_attack_status_payloads(ability_id: StringName, target_ids: Array[int], grade: StringName) -> void:
	ability_resolved.emit(ability_id, target_ids, grade)


## Emit ability_resolved for an enemy attack action after BLOCK_RESOLVE.
## AC-41: never called on PERFECT — PERFECT block suppresses all ability effects (GDD Rule 13).
## AC-42: called on HIT; MISS block also delivers status payloads (only PERFECT suppresses).
func _dispatch_block_status_payloads(ability_id: StringName, target_ids: Array[int], grade: StringName) -> void:
	ability_resolved.emit(ability_id, target_ids, grade)

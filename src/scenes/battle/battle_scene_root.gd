## BattleSceneRoot — Composition root for the battle scene.
##
## Responsibilities:
## - Wire InputTimingDetector signal connections to HUD disable/enable
## - Wire TCS, SE, and AS signals to CombatEventBus relay methods
## - Manage HUD input processing during timing windows
## - Establish scene-level dependencies and initialization order
##
## References are either found from scene children in _ready() or injected
## externally before _ready() runs (enables testability without a full scene).
##
## Architecture:
##   ADR-0003: Input Routing and Dual-Focus Strategy
##   ADR-0004: Combat Event Signal Bus
class_name BattleSceneRoot extends Node

# ─── Scene Dependencies ────────────────────────────────────────────────────

## Reference to InputTimingDetector (direct child of this root).
## Must be positioned above HUDSystem in the scene tree to ensure _input() fires first.
@onready var _itd: InputTimingDetector = $InputTimingDetector

## Reference to HUDSystem CanvasLayer (contains all HUD Controls).
## During a timing window, this subtree is disabled via set_process_input(false).
@onready var _hud_root: CanvasLayer = $HUDSystem

## Reference to TimingCombatSystem. Set externally (tests) or resolved from
## scene children in _ready(). Must be wired before _ready() completes.
var _tcs: TimingCombatSystem = null

## Reference to StatusEffects. Set externally or resolved in _ready() when available.
## Node type used because StatusEffects class is not yet defined.
var _se: Node = null  # untyped: StatusEffects not yet implemented

## Reference to AbilitySystem. Set externally or resolved in _ready() when available.
## Node type used because AbilitySystem class is not yet defined.
var _as: Node = null  # untyped: AbilitySystem not yet implemented

## CombatEventBus Autoload reference. Fetched from /root in _ready() if not set.
## Only composition roots may access Autoloads by global name (ADR-0002 rule).
var _bus: CombatEventBus = null


# ─── Lifecycle ────────────────────────────────────────────────────────────

## Resolve scene references, then wire all signal connections:
##   1. ITD → HUD (input gating, ADR-0003)
##   2. TCS → CombatEventBus relay (ADR-0004)
##   3. SE → CombatEventBus relay (ADR-0004, guarded until SE implemented)
##   4. AS → CombatEventBus relay (ADR-0004, guarded until AS implemented)
func _ready() -> void:
	_resolve_scene_refs()
	assert(_bus != null, "CombatEventBus Autoload not registered at position 5 — check Project Settings")

	# ITD → HUD input gating (ADR-0003)
	_itd.window_opened.connect(_on_timing_window_opened)
	_itd.window_closed.connect(_on_timing_window_closed)

	# TCS → CombatEventBus relay (ADR-0004)
	_wire_tcs_to_bus()

	# SE → CombatEventBus relay (ADR-0004)
	# String-based connect used until StatusEffects class is defined.
	if _se != null:
		_se.connect("status_effect_applied", _on_se_status_effect_applied)
		_se.connect("status_effect_expired", _on_se_status_effect_expired)
		_se.connect("status_effect_tick", _on_se_status_effect_tick)

	# AS → CombatEventBus relay (ADR-0004)
	# String-based connect used until AbilitySystem class is defined.
	if _as != null:
		_as.connect("ability_list_changed", _on_as_ability_list_changed)


## Resolves Autoload and scene-child references unless already injected externally.
## Composition root privilege — only roots may access Autoloads by global name (ADR-0002).
func _resolve_scene_refs() -> void:
	if _bus == null:
		_bus = get_node("/root/CombatEventBus")
	if _tcs == null and has_node("TimingCombatSystem"):
		_tcs = get_node("TimingCombatSystem") as TimingCombatSystem
	if _se == null and has_node("StatusEffects"):
		_se = get_node("StatusEffects")
	if _as == null and has_node("AbilitySystem"):
		_as = get_node("AbilitySystem")


## Connects all TCS signals to their CombatEventBus relay handlers (ADR-0004).
## No-ops silently when _tcs is null (TCS not present or injected in this scene).
func _wire_tcs_to_bus() -> void:
	if _tcs == null:
		return
	_tcs.encounter_started.connect(_on_tcs_encounter_started)
	_tcs.encounter_ended.connect(_on_tcs_encounter_ended)
	_tcs.turn_started.connect(_on_tcs_turn_started)
	_tcs.turn_ended.connect(_on_tcs_turn_ended)
	_tcs.damage_dealt.connect(_on_tcs_damage_dealt)
	_tcs.combatant_incapacitated.connect(_on_tcs_combatant_incapacitated)
	_tcs.hp_danger_zone_entered.connect(_on_tcs_hp_danger_zone_entered)
	_tcs.enemy_condition_changed.connect(_on_tcs_enemy_condition_changed)
	_tcs.hp_changed.connect(_on_tcs_hp_changed)
	_tcs.turn_order_changed.connect(_on_tcs_turn_order_changed)
	_tcs.timing_window_opened.connect(_on_tcs_timing_window_opened)
	_tcs.grade_resolved.connect(_on_tcs_grade_resolved)
	_tcs.perfect_counter_started.connect(_on_tcs_perfect_counter_started)
	_tcs.cc_spent.connect(_on_tcs_cc_spent)
	_tcs.cc_changed.connect(_on_tcs_cc_changed)


# ─── ITD → HUD Signal Handlers ────────────────────────────────────────────

## Called when ITD opens a timing window (ACTION_WINDOW or BLOCK_WINDOW).
##
## Disables HUD input processing via recursive set_process_input(false).
## This prevents child Controls from consuming events during the window.
##
## ⚠️ SMOKE TEST REQUIRED (AC-R4 in evidence):
##   Does set_process_input(false) on CanvasLayer suppress _gui_input() on child Controls?
##   If smoke test FAILS, replace this with fallback implementation (see ADR-0003 lines 103-117).
func _on_timing_window_opened(_mode: StringName) -> void:
	_hud_root.set_process_input(false)
	_hud_root.set_process_unhandled_input(false)


## Called when ITD closes a timing window (due to grade emission or force_close).
##
## Re-enables HUD input processing, allowing Controls to resume normal _gui_input() handling.
func _on_timing_window_closed(_grade: StringName) -> void:
	_hud_root.set_process_input(true)
	_hud_root.set_process_unhandled_input(true)


# ─── TCS → CombatEventBus Relay Handlers ─────────────────────────────────
# int → StringName conversion happens here, at the relay boundary (ADR-0006 Rule 2).
# CombatEventBus signals use StringName IDs; TCS signals use int IDs.

func _on_tcs_encounter_started(enemy_ids: Array[StringName]) -> void:
	_bus.relay_encounter_started(enemy_ids)

func _on_tcs_encounter_ended(result: StringName) -> void:
	_bus.relay_encounter_ended(result)

func _on_tcs_turn_started(combatant_id: int, is_player_turn: bool) -> void:
	_bus.relay_turn_started(str(combatant_id), is_player_turn)

func _on_tcs_turn_ended(combatant_id: int) -> void:
	_bus.relay_turn_ended(str(combatant_id))

func _on_tcs_damage_dealt(target_id: int, amount: int, grade: StringName) -> void:
	_bus.relay_damage_dealt(str(target_id), amount, grade)

func _on_tcs_combatant_incapacitated(combatant_id: int, is_enemy: bool) -> void:
	_bus.relay_combatant_incapacitated(str(combatant_id), is_enemy)

func _on_tcs_hp_danger_zone_entered(combatant_id: int) -> void:
	_bus.relay_hp_danger_zone_entered(str(combatant_id))

func _on_tcs_enemy_condition_changed(enemy_instance_id: int, condition: StringName) -> void:
	_bus.relay_enemy_condition_changed(str(enemy_instance_id), condition)

func _on_tcs_hp_changed(combatant_id: int, new_hp: int, max_hp: int, old_hp: int) -> void:
	_bus.relay_hp_changed(str(combatant_id), new_hp, max_hp, old_hp)

func _on_tcs_turn_order_changed(ordered_ids: Array[int], active_id: int) -> void:
	var string_ids: Array[StringName] = []
	for id: int in ordered_ids:
		string_ids.append(str(id))
	_bus.relay_turn_order_changed(string_ids, str(active_id))

func _on_tcs_timing_window_opened(window_type: StringName, window_frames: int, actor_id: int) -> void:
	_bus.relay_timing_window_opened(window_type, window_frames, str(actor_id))

func _on_tcs_grade_resolved(combatant_id: int, grade: StringName) -> void:
	_bus.relay_grade_resolved(str(combatant_id), grade)

func _on_tcs_perfect_counter_started(blocker_id: int) -> void:
	_bus.relay_perfect_counter_started(str(blocker_id))

func _on_tcs_cc_spent(amount: int) -> void:
	_bus.relay_cc_spent(amount)

func _on_tcs_cc_changed(new_cc: int, delta: int, source_type: StringName) -> void:
	_bus.relay_cc_changed(new_cc, delta, source_type)


# ─── SE → CombatEventBus Relay Handlers ──────────────────────────────────
# SE signals use StringName combatant IDs — no conversion needed.

func _on_se_status_effect_applied(combatant_id: StringName, effect_id: StringName, turns_remaining: int, stat_delta_key: StringName, modifier_delta: int, is_refresh: bool) -> void:
	_bus.relay_status_effect_applied(combatant_id, effect_id, turns_remaining, stat_delta_key, modifier_delta, is_refresh)

func _on_se_status_effect_expired(combatant_id: StringName, effect_id: StringName, cause: StringName) -> void:
	_bus.relay_status_effect_expired(combatant_id, effect_id, cause)

func _on_se_status_effect_tick(combatant_id: StringName, effect_id: StringName, turns_remaining: int) -> void:
	_bus.relay_status_effect_tick(combatant_id, effect_id, turns_remaining)


# ─── AS → CombatEventBus Relay Handlers ──────────────────────────────────

func _on_as_ability_list_changed(combatant_id: StringName, new_list: Array[StringName]) -> void:
	_bus.relay_ability_list_changed(combatant_id, new_list)

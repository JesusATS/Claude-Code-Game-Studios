## CombatEventBus — Combat event relay Autoload (position 5).
##
## Thin relay between battle-scoped TCS/SE/AS and persistent consumers
## (HUDSystem, AudioSystem). BattleSceneRoot connects TCS/SE/AS signals to
## relay methods in _ready(). Persistent consumers subscribe to bus signals
## once in their own _ready() — no per-battle re-subscription needed.
##
## int → StringName conversion for combatant IDs happens in BattleSceneRoot
## relay handlers before calling relay_* methods here.
##
## Architecture: docs/architecture/adr-0004-combat-event-signal-bus.md
## Autoload order: position 5 (ADR-0002)
class_name CombatEventBus extends Node

# ─── TCS-originated signals ───────────────────────────────────────────────────

signal encounter_started(enemy_ids: Array[StringName])
signal encounter_ended(result: StringName)
signal turn_started(combatant_id: StringName, is_player_turn: bool)
signal turn_ended(combatant_id: StringName)
signal damage_dealt(target_id: StringName, amount: int, grade: StringName)
signal combatant_incapacitated(combatant_id: StringName, is_enemy: bool)
signal hp_danger_zone_entered(combatant_id: StringName)
signal enemy_condition_changed(enemy_instance_id: StringName, condition: StringName)
signal hp_changed(combatant_id: StringName, new_hp: int, max_hp: int, old_hp: int)
signal turn_order_changed(ordered_ids: Array[StringName], active_id: StringName)
signal timing_window_opened(window_type: StringName, window_frames: int, actor_id: StringName)
signal grade_resolved(combatant_id: StringName, grade: StringName)
signal perfect_counter_started(blocker_id: StringName)
signal cc_spent(amount: int)
signal cc_changed(new_cc: int, delta: int, source_type: StringName)

# ─── SE-originated signals ────────────────────────────────────────────────────

signal status_effect_applied(combatant_id: StringName, effect_id: StringName, turns_remaining: int, stat_delta_key: StringName, modifier_delta: int, is_refresh: bool)
signal status_effect_expired(combatant_id: StringName, effect_id: StringName, cause: StringName)
signal status_effect_tick(combatant_id: StringName, effect_id: StringName, turns_remaining: int)

# ─── AS-originated signals ────────────────────────────────────────────────────

signal ability_list_changed(combatant_id: StringName, new_list: Array[StringName])

# ─── TCS relay methods ────────────────────────────────────────────────────────

## Forwards TCS encounter_started to persistent bus subscribers.
func relay_encounter_started(enemy_ids: Array[StringName]) -> void:
	encounter_started.emit(enemy_ids)

## Forwards TCS encounter_ended to persistent bus subscribers.
func relay_encounter_ended(result: StringName) -> void:
	encounter_ended.emit(result)

## Forwards TCS turn_started (combatant_id already converted to StringName).
func relay_turn_started(combatant_id: StringName, is_player_turn: bool) -> void:
	turn_started.emit(combatant_id, is_player_turn)

## Forwards TCS turn_ended (combatant_id already converted to StringName).
func relay_turn_ended(combatant_id: StringName) -> void:
	turn_ended.emit(combatant_id)

## Forwards TCS damage_dealt (target_id already converted to StringName).
func relay_damage_dealt(target_id: StringName, amount: int, grade: StringName) -> void:
	damage_dealt.emit(target_id, amount, grade)

## Forwards TCS combatant_incapacitated (combatant_id already converted to StringName).
func relay_combatant_incapacitated(combatant_id: StringName, is_enemy: bool) -> void:
	combatant_incapacitated.emit(combatant_id, is_enemy)

## Forwards TCS hp_danger_zone_entered (combatant_id already converted to StringName).
func relay_hp_danger_zone_entered(combatant_id: StringName) -> void:
	hp_danger_zone_entered.emit(combatant_id)

## Forwards TCS enemy_condition_changed (enemy_instance_id already converted to StringName).
func relay_enemy_condition_changed(enemy_instance_id: StringName, condition: StringName) -> void:
	enemy_condition_changed.emit(enemy_instance_id, condition)

## Forwards TCS hp_changed (combatant_id already converted to StringName).
func relay_hp_changed(combatant_id: StringName, new_hp: int, max_hp: int, old_hp: int) -> void:
	hp_changed.emit(combatant_id, new_hp, max_hp, old_hp)

## Forwards TCS turn_order_changed (all IDs already converted to StringName).
func relay_turn_order_changed(ordered_ids: Array[StringName], active_id: StringName) -> void:
	turn_order_changed.emit(ordered_ids, active_id)

## Forwards TCS timing_window_opened to persistent bus subscribers.
func relay_timing_window_opened(window_type: StringName, window_frames: int, actor_id: StringName) -> void:
	timing_window_opened.emit(window_type, window_frames, actor_id)

## Forwards TCS grade_resolved (combatant_id already converted to StringName).
func relay_grade_resolved(combatant_id: StringName, grade: StringName) -> void:
	grade_resolved.emit(combatant_id, grade)

## Forwards TCS perfect_counter_started (blocker_id already converted to StringName).
func relay_perfect_counter_started(blocker_id: StringName) -> void:
	perfect_counter_started.emit(blocker_id)

## Forwards TCS cc_spent to persistent bus subscribers.
func relay_cc_spent(amount: int) -> void:
	cc_spent.emit(amount)

## Forwards TCS cc_changed to persistent bus subscribers.
func relay_cc_changed(new_cc: int, delta: int, source_type: StringName) -> void:
	cc_changed.emit(new_cc, delta, source_type)

# ─── SE relay methods ─────────────────────────────────────────────────────────

## Forwards SE status_effect_applied to persistent bus subscribers.
func relay_status_effect_applied(combatant_id: StringName, effect_id: StringName, turns_remaining: int, stat_delta_key: StringName, modifier_delta: int, is_refresh: bool) -> void:
	status_effect_applied.emit(combatant_id, effect_id, turns_remaining, stat_delta_key, modifier_delta, is_refresh)

## Forwards SE status_effect_expired to persistent bus subscribers.
func relay_status_effect_expired(combatant_id: StringName, effect_id: StringName, cause: StringName) -> void:
	status_effect_expired.emit(combatant_id, effect_id, cause)

## Forwards SE status_effect_tick to persistent bus subscribers.
func relay_status_effect_tick(combatant_id: StringName, effect_id: StringName, turns_remaining: int) -> void:
	status_effect_tick.emit(combatant_id, effect_id, turns_remaining)

# ─── AS relay methods ─────────────────────────────────────────────────────────

## Forwards AS ability_list_changed to persistent bus subscribers.
func relay_ability_list_changed(combatant_id: StringName, new_list: Array[StringName]) -> void:
	ability_list_changed.emit(combatant_id, new_list)

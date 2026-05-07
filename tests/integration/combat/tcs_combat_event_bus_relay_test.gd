## TCS CombatEventBus Relay Integration Tests
##
## Validates the signal relay chain from TCS through BattleSceneRoot relay
## handlers to CombatEventBus. Uses real TCS + real ITD (for CONNECT_ONE_SHOT
## compatibility) + real CombatEventBus node + recording stubs for all other
## systems. Tests are source-code checks and live signal emission checks.
##
## Covers:
##   AC-B1: All required .connect() calls present in battle_scene_root.gd
##   AC-B2: encounter_started relayed to bus with same enemy_ids array
##   AC-B3: hp_changed combatant_id converted int → StringName at relay boundary
##   AC-B4: No CONNECT_PERSIST flag — Godot auto-disconnect guaranteed on node free
##   AC-B5: TCS source contains no direct CombatEventBus reference
##
## Framework: GdUnit4 (extends GdUnitTestSuite)
## Run via: GdUnit4 panel in Godot editor, or:
##   godot --headless --script tests/gdunit4_runner.gd
##
## Implements: design/gdd/timing-combat-system.md
## Architecture: docs/architecture/adr-0004-combat-event-signal-bus.md
class_name TcsCombatEventBusRelayTest extends GdUnitTestSuite

# ─── Stubs ────────────────────────────────────────────────────────────────────

class StubAbility extends RefCounted:
	var damage_multiplier: float = 1.0
	var cc_cost: int = 0
	var timing_optional: bool = false
	var cc_delta: int = 0


class StubAS extends Node:
	var _ability: StubAbility = StubAbility.new()

	func get_ability(_id: StringName) -> StubAbility:
		return _ability


class StubSE extends Node:
	func get_modifier(_combatant_id: int, _stat: StringName) -> int:
		return 0

	func check_turn_skip(_combatant_id: int) -> bool:
		return false

	func get_active_effect_ids(_combatant_id: int) -> Array[StringName]:
		return [] as Array[StringName]


class StubES extends Node:
	func evaluate_turn(_enemy_id: int, _encounter_state: Dictionary) -> Dictionary:
		return {
			"ability_id": &"enemy_basic",
			"hit_count": 1,
			"targets": [1],
			"is_party_all": false
		}


class StubPCM extends Node:
	var members: Array[CharacterData] = []

	func get_active_combatants() -> Array[CharacterData]:
		return members


class StubAudio extends Node:
	func begin_combat_layer() -> void: pass
	func end_combat_layer() -> void: pass


## Records bus signal emissions for assertion.
class BusSpy extends Node:
	var encounter_started_calls: int = 0
	var last_enemy_ids: Array[StringName] = []
	var hp_changed_calls: int = 0
	var last_hp_combatant_id: StringName = ""
	var last_hp_combatant_id_type: int = -1

	func subscribe(bus: CombatEventBus) -> void:
		bus.encounter_started.connect(_on_encounter_started)
		bus.hp_changed.connect(_on_hp_changed)

	func _on_encounter_started(enemy_ids: Array[StringName]) -> void:
		encounter_started_calls += 1
		last_enemy_ids = enemy_ids

	func _on_hp_changed(combatant_id: StringName, _new_hp: int, _max_hp: int, _old_hp: int) -> void:
		hp_changed_calls += 1
		last_hp_combatant_id = combatant_id
		last_hp_combatant_id_type = typeof(combatant_id)


## Minimal composition root that mirrors BattleSceneRoot TCS relay wiring.
## Used in tests to wire a real TCS to a real CombatEventBus without needing
## the full scene tree. Relay handler logic is identical to BattleSceneRoot.
class TestCompositionRoot extends Node:
	var tcs: TimingCombatSystem
	var bus: CombatEventBus

	func wire() -> void:
		tcs.encounter_started.connect(_on_tcs_encounter_started)
		tcs.encounter_ended.connect(_on_tcs_encounter_ended)
		tcs.turn_started.connect(_on_tcs_turn_started)
		tcs.turn_ended.connect(_on_tcs_turn_ended)
		tcs.damage_dealt.connect(_on_tcs_damage_dealt)
		tcs.combatant_incapacitated.connect(_on_tcs_combatant_incapacitated)
		tcs.hp_danger_zone_entered.connect(_on_tcs_hp_danger_zone_entered)
		tcs.enemy_condition_changed.connect(_on_tcs_enemy_condition_changed)
		tcs.hp_changed.connect(_on_tcs_hp_changed)
		tcs.turn_order_changed.connect(_on_tcs_turn_order_changed)
		tcs.timing_window_opened.connect(_on_tcs_timing_window_opened)
		tcs.grade_resolved.connect(_on_tcs_grade_resolved)
		tcs.perfect_counter_started.connect(_on_tcs_perfect_counter_started)
		tcs.cc_spent.connect(_on_tcs_cc_spent)
		tcs.cc_changed.connect(_on_tcs_cc_changed)

	# int → StringName conversions mirror BattleSceneRoot relay handlers exactly.
	func _on_tcs_encounter_started(enemy_ids: Array[StringName]) -> void:
		bus.relay_encounter_started(enemy_ids)
	func _on_tcs_encounter_ended(result: StringName) -> void:
		bus.relay_encounter_ended(result)
	func _on_tcs_turn_started(combatant_id: int, is_player_turn: bool) -> void:
		bus.relay_turn_started(str(combatant_id), is_player_turn)
	func _on_tcs_turn_ended(combatant_id: int) -> void:
		bus.relay_turn_ended(str(combatant_id))
	func _on_tcs_damage_dealt(target_id: int, amount: int, grade: StringName) -> void:
		bus.relay_damage_dealt(str(target_id), amount, grade)
	func _on_tcs_combatant_incapacitated(combatant_id: int, is_enemy: bool) -> void:
		bus.relay_combatant_incapacitated(str(combatant_id), is_enemy)
	func _on_tcs_hp_danger_zone_entered(combatant_id: int) -> void:
		bus.relay_hp_danger_zone_entered(str(combatant_id))
	func _on_tcs_enemy_condition_changed(enemy_instance_id: int, condition: StringName) -> void:
		bus.relay_enemy_condition_changed(str(enemy_instance_id), condition)
	func _on_tcs_hp_changed(combatant_id: int, new_hp: int, max_hp: int, old_hp: int) -> void:
		bus.relay_hp_changed(str(combatant_id), new_hp, max_hp, old_hp)
	func _on_tcs_turn_order_changed(ordered_ids: Array[int], active_id: int) -> void:
		var string_ids: Array[StringName] = []
		for id: int in ordered_ids:
			string_ids.append(str(id))
		bus.relay_turn_order_changed(string_ids, str(active_id))
	func _on_tcs_timing_window_opened(window_type: StringName, window_frames: int, actor_id: int) -> void:
		bus.relay_timing_window_opened(window_type, window_frames, str(actor_id))
	func _on_tcs_grade_resolved(combatant_id: int, grade: StringName) -> void:
		bus.relay_grade_resolved(str(combatant_id), grade)
	func _on_tcs_perfect_counter_started(blocker_id: int) -> void:
		bus.relay_perfect_counter_started(str(blocker_id))
	func _on_tcs_cc_spent(amount: int) -> void:
		bus.relay_cc_spent(amount)
	func _on_tcs_cc_changed(new_cc: int, delta: int, source_type: StringName) -> void:
		bus.relay_cc_changed(new_cc, delta, source_type)


# ─── Fixtures ─────────────────────────────────────────────────────────────────

var _itd: InputTimingDetector
var _tcs: TimingCombatSystem
var _bus: CombatEventBus
var _spy: BusSpy
var _root: TestCompositionRoot
var _stub_as: StubAS
var _stub_es: StubES
var _stub_se: StubSE
var _stub_pcm: StubPCM
var _stub_audio: StubAudio


func before_test() -> void:
	_itd = InputTimingDetector.new()
	add_child(_itd)

	_stub_as = StubAS.new()
	add_child(_stub_as)
	_stub_es = StubES.new()
	add_child(_stub_es)
	_stub_se = StubSE.new()
	add_child(_stub_se)
	_stub_pcm = StubPCM.new()
	add_child(_stub_pcm)
	_stub_audio = StubAudio.new()
	add_child(_stub_audio)

	_tcs = TimingCombatSystem.new()
	_tcs.itd = _itd
	_tcs.as_ = _stub_as
	_tcs.es = _stub_es
	_tcs.se = _stub_se
	_tcs.pcm = _stub_pcm
	_tcs.audio_system = _stub_audio
	add_child(_tcs)

	_bus = CombatEventBus.new()
	add_child(_bus)

	_spy = BusSpy.new()
	_spy.subscribe(_bus)
	add_child(_spy)

	_root = TestCompositionRoot.new()
	_root.tcs = _tcs
	_root.bus = _bus
	_root.wire()
	add_child(_root)


func after_test() -> void:
	if is_instance_valid(_tcs):
		_tcs.queue_free()
	_itd.queue_free()
	_stub_as.queue_free()
	_stub_es.queue_free()
	_stub_se.queue_free()
	_stub_pcm.queue_free()
	_stub_audio.queue_free()
	_bus.queue_free()
	_spy.queue_free()
	_root.queue_free()


## Build a party member. base_spd=10 by default (faster than enemy SPD 8 → party goes first).
func _make_char(base_hp: int = 100, base_spd: int = 10) -> CharacterData:
	var c := CharacterData.new()
	c.id = &"test_char"
	c.base_hp = base_hp
	c.hp_current = base_hp
	c.base_atk = 10
	c.base_def = 5
	c.base_spd = base_spd
	c.base_flux = 5
	c.perfect_hit_multiplier = 1.0
	c.inheritances = [] as Array[NamedInheritanceObject]
	return c


## Build an enemy. base_spd=8 by default (slower than default party SPD 10).
func _make_enemy(base_hp: int = 50) -> EnemyData:
	var e := EnemyData.new()
	e.id = &"test_enemy"
	e.base_atk = 5
	e.base_def = 3
	e.base_spd = 8
	e.base_hp = base_hp
	e.base_tempo = 5
	return e


# ─── AC-B1: Required .connect() calls present in source ───────────────────────

func test_tcs_bus_relay_b1_all_required_tcs_signal_connects_present_in_source() -> void:
	# Verify battle_scene_root.gd contains a .connect() call for every TCS signal
	# required by the Composition Root Checklist (ADR-0004 / control manifest).
	var f := FileAccess.open("res://src/scenes/battle/battle_scene_root.gd", FileAccess.READ)
	assert_that(f).is_not_null()
	var content: String = f.get_as_text()
	f.close()

	var required_tcs_signals: Array[String] = [
		"encounter_started", "encounter_ended", "turn_started", "turn_ended",
		"damage_dealt", "combatant_incapacitated", "hp_danger_zone_entered",
		"enemy_condition_changed", "hp_changed", "turn_order_changed",
		"timing_window_opened", "grade_resolved", "perfect_counter_started",
		"cc_spent", "cc_changed"
	]
	for sig_name: String in required_tcs_signals:
		assert_bool(content.contains("_tcs." + sig_name + ".connect(")).is_true()


func test_tcs_bus_relay_b1_se_and_as_relay_connects_present_in_source() -> void:
	# Verify SE and AS signal connect calls are present (string-based until classes defined).
	var f := FileAccess.open("res://src/scenes/battle/battle_scene_root.gd", FileAccess.READ)
	assert_that(f).is_not_null()
	var content: String = f.get_as_text()
	f.close()

	assert_bool(content.contains("\"status_effect_applied\"")).is_true()
	assert_bool(content.contains("\"status_effect_expired\"")).is_true()
	assert_bool(content.contains("\"status_effect_tick\"")).is_true()
	assert_bool(content.contains("\"ability_list_changed\"")).is_true()


# ─── AC-B2: encounter_started relayed with same data ──────────────────────────

func test_tcs_bus_relay_b2_encounter_started_reaches_bus_with_correct_enemy_ids() -> void:
	# Arrange: party SPD=10 > enemy SPD=8 → party goes first
	var party: Array[CharacterData] = [_make_char()]
	_stub_pcm.members = party

	# Act: begin_encounter triggers ENCOUNTER_START → encounter_started emits
	_tcs.begin_encounter(party, [_make_enemy()])

	# Assert (AC-B2): bus received encounter_started exactly once with same enemy_ids
	assert_that(_spy.encounter_started_calls).is_equal(1)
	assert_that(_spy.last_enemy_ids).is_equal([&"test_enemy"] as Array[StringName])


func test_tcs_bus_relay_b2_encounter_started_not_emitted_before_encounter_begins() -> void:
	# Assert: spy receives nothing before begin_encounter is called
	assert_that(_spy.encounter_started_calls).is_equal(0)


# ─── AC-B3: int → StringName conversion for hp_changed ───────────────────────

func test_tcs_bus_relay_b3_hp_changed_combatant_id_converted_int_to_string_name() -> void:
	# Arrange: party goes first (SPD 10 > enemy SPD 8); enemy starts with 50 HP
	var party: Array[CharacterData] = [_make_char()]
	_stub_pcm.members = party
	_tcs.begin_encounter(party, [_make_enemy(50)])
	assert_that(_tcs._state).is_equal(TimingCombatSystem.State.PLAYER_ACTION)

	# Act: player attacks — inject input on frame 1 (HIT grade)
	_tcs.submit_player_action(&"basic_attack")
	_itd.inject_input(&"timing_confirm")
	_itd.advance_frame()
	# Damage is dealt → hp_changed emits on enemy → relay converts int → StringName

	# Assert (AC-B3): bus received hp_changed; combatant_id is TYPE_STRING_NAME
	assert_that(_spy.hp_changed_calls).is_greater(0)
	assert_that(_spy.last_hp_combatant_id_type).is_equal(TYPE_STRING_NAME)
	# Enemy id is "test_enemy" as string (TCS stores int instance_id for enemies)
	assert_bool(_spy.last_hp_combatant_id.is_empty()).is_false()


# ─── AC-B4: No CONNECT_PERSIST — Godot auto-disconnect guaranteed ─────────────

func test_tcs_bus_relay_b4_no_connect_persist_flag_in_battle_scene_root() -> void:
	# AC-B4 (structural): Connections must NOT use CONNECT_PERSIST.
	# CONNECT_PERSIST prevents Godot's automatic signal disconnection when a node
	# is freed — using it would leave dangling relay connections after TCS is freed.
	# Auto-disconnect is the architectural guarantee per ADR-0004.
	var f := FileAccess.open("res://src/scenes/battle/battle_scene_root.gd", FileAccess.READ)
	assert_that(f).is_not_null()
	var content: String = f.get_as_text()
	f.close()

	assert_bool(content.contains("CONNECT_PERSIST")).is_false()


# ─── AC-B5: TCS source has no CombatEventBus reference ───────────────────────

func test_tcs_bus_relay_b5_tcs_source_contains_no_combat_event_bus_reference() -> void:
	# TCS must be bus-unaware: no CombatEventBus reference by global name (ADR-0002 / ADR-0004).
	# All bus access is exclusively the composition root's responsibility.
	var f := FileAccess.open("res://src/feature/combat/timing_combat_system.gd", FileAccess.READ)
	assert_that(f).is_not_null()
	var content: String = f.get_as_text()
	f.close()

	assert_bool(content.contains("CombatEventBus")).is_false()

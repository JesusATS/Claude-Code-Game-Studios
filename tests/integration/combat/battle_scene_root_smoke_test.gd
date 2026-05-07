## BattleSceneRoot ADR Smoke Tests
##
## Validates the 4 ADR guarantees that BattleSceneRoot is responsible for enforcing.
## All tests run headlessly without a full scene or physical input.
##
## Covers:
##   AC-1: ADR-0001 — duplicate_deep() produces an isolated CharacterData copy
##   AC-2: ADR-0002 — only battle_scene_root.gd accesses CombatEventBus by global name
##   AC-3: ADR-0003 — HUD CanvasLayer input disabled/re-enabled at window open/close
##   AC-4: ADR-0004 — no CONNECT_PERSIST in battle_scene_root.gd (auto-disconnect proven)
##
## Approach for AC-3:
##   BattleSceneRoot is instantiated but NOT added to the scene tree. This bypasses
##   @onready (which would fail without scene children) and allows direct injection of
##   a CanvasLayer into _hud_root. The handler methods are called directly.
##
## Framework: GdUnit4 (extends GdUnitTestSuite)
## Run via: godot --headless --script tests/gdunit4_runner.gd
##
## Implements: production/epics/timing-combat-system/story-012-bsr-adr-smoke-tests.md
## Architecture: docs/architecture/adr-0001..0004
class_name BattleSceneRootSmokeTest extends GdUnitTestSuite

const BSR_PATH := "res://src/scenes/battle/battle_scene_root.gd"
const TCS_PATH := "res://src/feature/combat/timing_combat_system.gd"
const BUS_PATH := "res://src/foundation/combat_event_bus.gd"


# ─── AC-1: ADR-0001 — duplicate_deep() produces an isolated Resource copy ────
##
## ADR-0001 Verification Required:
##   "duplicate_deep() on an Array[CharacterData] — confirm element identity."
##   CharacterData.inheritances is Array[NamedInheritanceObject] (Array of Resource
##   subclasses) — this is the exact scenario ADR-0001 flagged for smoke testing.

func test_bsr_adr0001_duplicate_deep_produces_isolated_copy() -> void:
	# Arrange: CharacterData with one NamedInheritanceObject in inheritances
	var original := CharacterData.new()
	original.id = &"smoke_test_char"
	original.base_atk = 10
	original.base_hp = 50
	var nio := NamedInheritanceObject.new()
	nio.name = "Test Inheritance"
	nio.stat = &"flux"
	nio.magnitude = 5
	original.apply_inheritance(nio)

	# Act
	var copy: CharacterData = original.duplicate_deep()

	# Assert: copy is a non-null, distinct object
	assert_that(copy).is_not_null()
	assert_that(copy.get_instance_id()).is_not_equal(original.get_instance_id())

	# Assert: field values are preserved in the copy
	assert_that(copy.base_atk).is_equal(original.base_atk)
	assert_that(copy.base_hp).is_equal(original.base_hp)
	assert_that(copy.inheritances.size()).is_equal(1)

	# Assert: nested NamedInheritanceObject is a distinct object — deep copy, not shallow
	var orig_nio: NamedInheritanceObject = original.inheritances[0]
	var copy_nio: NamedInheritanceObject = copy.inheritances[0]
	assert_that(copy_nio.get_instance_id()).is_not_equal(orig_nio.get_instance_id())
	assert_that(copy_nio.magnitude).is_equal(orig_nio.magnitude)
	assert_that(copy_nio.stat).is_equal(orig_nio.stat)

	# Assert: mutation of copy's nested object does not affect original (true isolation)
	copy_nio.magnitude = 99
	assert_that(orig_nio.magnitude).is_equal(5)


# ─── AC-2: ADR-0002 — only the composition root accesses the bus by global name ─
##
## ADR-0002 Rule: "Game code must NEVER access an Autoload by global name directly
## in business logic. The Autoload global name is only referenced in two places:
## 1. Scene root / composition root
## 2. Unit tests"
##
## This test verifies the rule holds for CombatEventBus specifically.

func test_bsr_adr0002_only_composition_root_accesses_bus_by_global_name() -> void:
	# Positive: battle_scene_root.gd IS the composition root — it must use global name
	var bsr_file := FileAccess.open(BSR_PATH, FileAccess.READ)
	assert_that(bsr_file).is_not_null()
	var bsr_content := bsr_file.get_as_text()
	bsr_file.close()
	assert_that(bsr_content.contains("get_node(\"/root/CombatEventBus\")")).is_true()

	# Negative: timing_combat_system.gd must not access CombatEventBus by global name
	# (ADR-0002: only composition roots use get_node("/root/AutoloadName") — TCS is a leaf)
	# Note: comments in TCS may mention "CombatEventBus" for architecture documentation;
	# only the actual access pattern get_node("/root/CombatEventBus") is forbidden.
	var tcs_file := FileAccess.open(TCS_PATH, FileAccess.READ)
	assert_that(tcs_file).is_not_null()
	var tcs_content := tcs_file.get_as_text()
	tcs_file.close()
	assert_that(tcs_content.contains("get_node(\"/root/CombatEventBus\")")).is_false()

	# Negative: combat_event_bus.gd must not self-access other Autoloads by global name
	# (CombatEventBus is itself an Autoload — it has no reason to call get_node("/root/..."))
	var bus_file := FileAccess.open(BUS_PATH, FileAccess.READ)
	assert_that(bus_file).is_not_null()
	var bus_content := bus_file.get_as_text()
	bus_file.close()
	assert_that(bus_content.contains("get_node(\"/root/\")")).is_false()


# ─── AC-3: ADR-0003 — HUD input disabled/re-enabled at timing window open/close ─
##
## ADR-0003 Verification Required:
##   "Smoke test: open a timing window, confirm a focused HUD Control does NOT consume
##    the timing_confirm action before ITD._input() processes it."
##
## This test verifies the structural side of that guarantee: that BattleSceneRoot's
## window_opened/closed handlers correctly call set_process_input() on the HUD root.
## Full runtime verification (actual input routing during a live window) is deferred
## to the production smoke check once BattleSceneRoot is integrated in a full scene.

func test_bsr_adr0003_hud_input_suppressed_during_timing_window() -> void:
	# Arrange: BattleSceneRoot not added to scene tree — bypasses @onready so _hud_root
	# can be injected directly without needing scene children to exist.
	var bsr := BattleSceneRoot.new()
	var mock_hud := CanvasLayer.new()
	bsr._hud_root = mock_hud

	# Act: simulate ITD emitting window_opened (ACTION or BLOCK window)
	bsr._on_timing_window_opened(&"ACTION_WINDOW")

	# Assert: both input processing flags are suppressed on the HUD root
	assert_that(mock_hud.is_processing_input()).is_false()
	assert_that(mock_hud.is_processing_unhandled_input()).is_false()

	# Act: simulate ITD emitting window_closed (after grade resolution or force_close)
	bsr._on_timing_window_closed(&"PERFECT")

	# Assert: both input processing flags are restored on the HUD root
	assert_that(mock_hud.is_processing_input()).is_true()
	assert_that(mock_hud.is_processing_unhandled_input()).is_true()

	# Cleanup: free nodes that were not added to the scene tree
	bsr.free()
	mock_hud.free()


# ─── AC-4: ADR-0004 — no CONNECT_PERSIST (Godot auto-disconnect guaranteed) ─────
##
## ADR-0004 Verification Required:
##   "Confirm that when TCS is freed at battle end, CombatEventBus no longer emits
##    encounter_started (verify Godot auto-disconnect on node free)."
##
## Godot 4.x automatically disconnects all signal connections when a Node is freed,
## UNLESS the CONNECT_PERSIST flag was used. Absence of CONNECT_PERSIST in
## _wire_tcs_to_bus() is the sufficient structural condition for auto-disconnect.
## This mirrors the AC-B4 check from Story 011 (which tested the TCS→Bus relay
## layer); this test applies the same check at the BattleSceneRoot source level.

func test_bsr_adr0004_no_connect_persist_flag_in_battle_scene_root() -> void:
	var bsr_file := FileAccess.open(BSR_PATH, FileAccess.READ)
	assert_that(bsr_file).is_not_null()
	var content := bsr_file.get_as_text()
	bsr_file.close()

	# CONNECT_PERSIST is the only flag that overrides Godot's auto-disconnect on free.
	# Its absence guarantees that all TCS→Bus connections established in _wire_tcs_to_bus()
	# will be automatically severed when BattleSceneRoot (and its child TCS node) is freed.
	assert_that(content.contains("CONNECT_PERSIST")).is_false()

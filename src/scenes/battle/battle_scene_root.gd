## BattleSceneRoot — Composition root for the battle scene.
##
## Responsibilities:
## - Wire InputTimingDetector signal connections to HUD disable/enable
## - Manage HUD input processing during timing windows
## - Establish scene-level dependencies and initialization order
##
## Architecture: Follows ADR-0003 (Input Routing and Dual-Focus Strategy)
class_name BattleSceneRoot extends Node

# ─── Scene Dependencies (via @onready) ────────────────────────────────────

## Reference to InputTimingDetector (direct child of this root).
## Must be positioned above HUDSystem in the scene tree to ensure _input() fires first.
@onready var _itd: InputTimingDetector = $InputTimingDetector

## Reference to HUDSystem CanvasLayer (contains all HUD Controls).
## During a timing window, this subtree is disabled via set_process_input(false).
@onready var _hud_root: CanvasLayer = $HUDSystem


# ─── Lifecycle ────────────────────────────────────────────────────────────

## Initialize signal wiring between ITD and HUD disable logic.
func _ready() -> void:
	_itd.window_opened.connect(_on_timing_window_opened)
	_itd.window_closed.connect(_on_timing_window_closed)


# ─── Signal Handlers ──────────────────────────────────────────────────────

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

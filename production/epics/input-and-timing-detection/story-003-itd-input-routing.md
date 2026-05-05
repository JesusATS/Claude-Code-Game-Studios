# Story 003: ITD Input Routing — HUD Isolation, Dual-Focus, and Scene Wiring

> **Epic**: Input & Timing Detection
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-05-04

## Context

**GDD**: `design/gdd/input-and-timing-detection.md`
**Requirement**: `TR-ITD-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Input Routing and Dual-Focus Strategy (Godot 4.6)
**ADR Decision Summary**: `timing_confirm` is a standalone InputMap action (not aliased to `ui_accept`). ITD is a direct child of BattleSceneRoot (above HUD CanvasLayer) so `_input()` fires first. During a timing window, BattleSceneRoot calls `_hud_root.set_process_input(false)` + `set_process_unhandled_input(false)` recursively — restored on `window_closed`. Passive HUD Controls use `mouse_filter = MOUSE_FILTER_IGNORE`.

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: ADR-0003 flags two unverified behaviors in Godot 4.6:
1. `set_process_input(false)` on a CanvasLayer (extends Node, not Control) — does it suppress `_gui_input()` on child Controls? Smoke test REQUIRED before marking Done.
2. Recursive Control disable (Godot 4.5+): `set_process_input(false)` on a Control propagates to all children. Verify on CanvasLayer-rooted subtrees specifically.
If the smoke test fails: use the fallback — iterate all interactive HUD Controls and set `mouse_filter = MOUSE_FILTER_IGNORE` directly on `window_opened`, restore on `window_closed`.

**Control Manifest Rules (Foundation layer)**:
- Required: `InputTimingDetector` as a direct child of battle scene root — NOT nested under CanvasLayer
- Required: `timing_confirm` registered as standalone InputMap action (Space + JOY_BUTTON_A), separate entry from `ui_accept`
- Required: BattleSceneRoot wires `ITD.window_opened` → HUD `set_process_input(false)` and `ITD.window_closed` → HUD `set_process_input(true)` in `_ready()`
- Forbidden: `timing_confirm` aliased to `ui_accept` in InputMap
- Forbidden: HUD input active during an open ITD timing window

---

## Acceptance Criteria

*From GDD `design/gdd/input-and-timing-detection.md` and ADR-0003, scoped to this story:*

- [ ] **AC-R1** — Project Settings InputMap has `timing_confirm` as a standalone entry with Space (keyboard) and JOY_BUTTON_A (gamepad), separate from `ui_accept`. Verify no `timing_confirm` key/button is merged into `ui_accept`'s mapping.
- [ ] **AC-R2** — `InputTimingDetector` node is a direct child of the battle scene root, positioned above the HUDSystem CanvasLayer in the scene tree. Verify via scene inspection.
- [ ] **AC-R3** — GIVEN a timing window is open, WHEN `timing_confirm` (Space or JOY_BUTTON_A) is pressed, THEN the event reaches `ITD._input()` and the correct grade is emitted — no HUD Control consumes or duplicates the event.
- [ ] **AC-R4** — GIVEN a timing window is open, WHEN HUD input disable is active (`set_process_input(false)` on HUD root), THEN no HUD Control fires `_gui_input()` for any input event during the window.
- [ ] **AC-R5** — GIVEN `window_closed` fires after a timing window, THEN HUD Controls resume normal `_gui_input()` processing (e.g., `ui_accept` navigates menus correctly).
- [ ] **AC-R6** — GIVEN passive HUD display Controls (HP bars, status icons, turn order strip), THEN each has `mouse_filter = Control.MOUSE_FILTER_IGNORE` set — they do not capture mouse events.
- [ ] **AC-R7** — GIVEN keyboard-only navigation outside of a timing window (menus, world exploration), THEN `grab_focus()` on the first interactive menu element correctly sets keyboard/gamepad focus (Godot 4.6 dual-focus: this does NOT affect mouse focus — confirm via smoke test).

---

## Implementation Notes

*Derived from ADR-0003 Implementation Guidelines:*

### InputMap Configuration (Godot Editor)
This step is a manual Godot Editor configuration — it cannot be set in GDScript:
```
Project Settings → Input Map:
  timing_confirm:
    keys: [Space]
    joypad_buttons: [JOY_BUTTON_A]
  ui_accept:        ← SEPARATE entry (may also have Space, but as a DISTINCT action)
    keys: [Enter, Space]
    joypad_buttons: [JOY_BUTTON_A]
```

### Scene Tree — ITD Placement
BattleSceneRoot.tscn scene tree order:
```
BattleSceneRoot (Node)
  ├── InputTimingDetector      ← _input() fires here first
  ├── TimingCombatSystem
  ├── AbilitySystem
  └── HUDSystem (CanvasLayer layer=10)
        └── HUDContainer (Node2D)
              └── [all HUD Controls]
```

### BattleSceneRoot `_ready()` — Composition Root Wiring
```gdscript
@onready var _itd: InputTimingDetector = $InputTimingDetector
@onready var _hud_root: CanvasLayer = $HUDSystem

func _ready() -> void:
    _itd.window_opened.connect(_on_timing_window_opened)
    _itd.window_closed.connect(_on_timing_window_closed)

func _on_timing_window_opened(_mode: StringName) -> void:
    # ⚠️ SMOKE TEST REQUIRED: Does set_process_input(false) on CanvasLayer
    # suppress _gui_input() on all child Controls?
    _hud_root.set_process_input(false)
    _hud_root.set_process_unhandled_input(false)

func _on_timing_window_closed(_grade: StringName) -> void:
    _hud_root.set_process_input(true)
    _hud_root.set_process_unhandled_input(true)
```

**If the smoke test fails** (CanvasLayer disable does not suppress child Control `_gui_input()`):
Use the fallback approach from ADR-0003 — iterate all interactive HUD Controls and set `mouse_filter = MOUSE_FILTER_IGNORE` directly. Also call `release_focus()` on any focused Control before opening the window.

### Passive HUD Controls
All HUD display Controls (HP bars, status icons, turn-order strip, enemy condition indicator) must have `mouse_filter = Control.MOUSE_FILTER_IGNORE` set in the scene or in their `_ready()`. This prevents mouse-click bleed-through during combat.

### Smoke Test Protocol (ADR-0003 Verification Required)
Before marking this story Done, the smoke test in ADR-0003 must be run:
1. Open a battle scene with both ITD and HUDSystem present
2. Open a timing window via `itd.open_action_window(8)`
3. Click or press `timing_confirm` — confirm grade is emitted by ITD
4. Confirm NO HUD Control fires `_gui_input()` during the window
5. Close the window — confirm HUD resumes normal `ui_accept` navigation
6. Test with both keyboard (Space) and gamepad (JOY_BUTTON_A)
7. Log the test result in the evidence doc

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: ITD FSM implementation, grade classification, test seam
- **Story 002**: Edge cases, `force_close_window()`, forgiveness window
- **HUD System epic**: Timing indicator visual implementation — this story only covers the input routing and HUD-disable wiring, not the indicator bar animation

---

## QA Test Cases

*Integration story — manual verification steps required. Smoke test evidence doc required.*

- **AC-R1**: InputMap configuration
  - Setup: Open Godot Editor → Project Settings → Input Map
  - Verify: `timing_confirm` entry exists with Space + JOY_BUTTON_A; `ui_accept` is a separate entry; no `timing_confirm` key is ONLY in `ui_accept` (may share keys, but must be distinct entries)
  - Pass condition: Both entries present separately; no merger

- **AC-R2**: Scene tree placement
  - Setup: Open BattleSceneRoot.tscn in Godot Editor
  - Verify: `InputTimingDetector` is a direct child of root node; it appears ABOVE `HUDSystem` in the children list
  - Pass condition: Scene tree order confirmed; no nesting under CanvasLayer

- **AC-R3**: Timing confirm reaches ITD during window
  - Setup: Battle scene running; `itd.open_action_window(8)` triggered
  - When: Press Space (keyboard) or JOY_BUTTON_A (gamepad) on frame 4
  - Verify: `input_result` signal emitted with `&"HIT"` grade; no duplicate signal
  - Pass condition: Exactly one `input_result` per press; correct grade

- **AC-R4**: HUD disabled during window
  - Setup: Open timing window; HUD has at least one interactive Control with focus
  - When: Press any key during the window
  - Verify: No HUD Control fires `_gui_input()`; HUD UI does not respond
  - Pass condition: HUD input suppressed for duration of window

- **AC-R5**: HUD restored after window closes
  - Setup: Close timing window (via grade or `force_close_window()`)
  - When: Navigate HUD menu with `ui_accept` (Enter or JOY_BUTTON_A)
  - Verify: HUD responds normally to menu navigation
  - Pass condition: Menu navigation works correctly after window close

- **AC-R6**: Passive HUD Controls have MOUSE_FILTER_IGNORE
  - Setup: Open BattleSceneRoot.tscn; inspect HP bar, status icon, turn-order strip
  - Verify: Each passive Control has `mouse_filter = Control.MOUSE_FILTER_IGNORE`
  - Pass condition: All passive Controls confirmed

- **AC-R7**: Dual-focus — grab_focus() sets keyboard/gamepad focus only
  - Setup: Open any menu screen; call `grab_focus()` on first interactive element
  - Verify: Element responds to keyboard/d-pad navigation; mouse hover focus is independent
  - Pass condition: Both focus types work independently (Godot 4.6 dual-focus confirmed)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/input/input_routing_smoke_test.gd` (automated, if headless runner supports input routing) OR `production/qa/evidence/itd-input-routing-evidence.md` (manual walkthrough doc + lead sign-off)

**Smoke test result must document**: pass/fail for `set_process_input(false)` on CanvasLayer, and whether primary or fallback implementation was used.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 Done (ITD FSM must exist to wire up signals)
- Unlocks: Any TCS story that calls `open_action_window()` / `open_block_window()`; any HUD timing indicator story

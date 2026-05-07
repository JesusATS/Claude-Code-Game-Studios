# ADR-0003: Input Routing and Dual-Focus Strategy (Godot 4.6)

## Status
Accepted

## Date
2026-05-04

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Input |
| **Knowledge Risk** | HIGH — Dual-focus system introduced in Godot 4.6; recursive Control disable added in Godot 4.5 |
| **References Consulted** | `docs/engine-reference/godot/modules/input.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | Dual-focus system (Godot 4.6): `grab_focus()` now only captures keyboard/gamepad focus, not mouse focus. Recursive Control disable (Godot 4.5): `Control.set_process_input(false)` propagates to all children. |
| **Verification Required** | Smoke test: open a timing window, confirm a focused HUD Control does NOT consume the `timing_confirm` action before ITD._input() processes it. Test with both keyboard and gamepad input methods. Test that recursive disable on HUD root correctly silences all child Control input during a window. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (Accepted) — ITD is wired into the battle scene via the composition root pattern |
| **Enables** | Any HUD story that uses Control focus navigation (must follow the focus rules here) |
| **Blocks** | ITD implementation; HUD implementation — both must follow the routing rules defined here |
| **Ordering Note** | Must be Accepted before any ITD or HUD story is written |

## Context

### Problem Statement

In Godot 4.6, mouse/touch focus and keyboard/gamepad focus are now separate systems (dual-focus). `InputTimingDetector` (ITD) uses `_input(event: InputEvent)` to detect `timing_confirm` presses at precise frame timing. HUD Controls — which may have keyboard focus for menu navigation — could potentially consume input events before or after ITD processes them, causing missed timing detections or phantom UI navigation inputs during combat windows.

Additionally, during non-combat phases (menu navigation, world exploration), ITD should not interfere with normal UI navigation. Clear mode-separation rules are needed for both phases.

### Constraints
- ITD must use `_input(event)` as specified in the ITD GDD (fires before GUI processing — consistent with timing precision requirement)
- `timing_confirm` is the sole action ITD responds to — it must not overlap with any `ui_*` action
- HUD system uses CanvasLayer nodes at layers 10, 11, 12 — these affect how mouse events route to underlying nodes
- Godot 4.6: `grab_focus()` on a Control only claims keyboard/gamepad focus, not mouse focus
- Godot 4.5+: `set_process_input(false)` on a Control recursively disables input for its entire subtree (one call covers all children)

### Requirements
- `timing_confirm` presses during an open timing window must reach ITD reliably with no dropped events
- HUD Controls must not have keyboard focus during an open timing window
- ITD must not consume or interfere with `ui_*` navigation events during menu phases
- The solution must work for both keyboard/mouse and gamepad input methods

## Decision

### Rule 1: `timing_confirm` is a Dedicated Non-UI Action

`timing_confirm` is registered in Project Settings InputMap as a standalone action:
- **Keyboard**: `Space` (or configurable)
- **Gamepad**: `JOY_BUTTON_A` (South button)

`timing_confirm` must NOT be aliased to `ui_accept`, `ui_select`, or any other `ui_*` action. They may share the same physical key/button but are separate logical actions. This prevents any Control from consuming the event under the guise of UI navigation.

```
Project Settings → Input Map:
  timing_confirm:
    keys: [Space]
    joypad_buttons: [JOY_BUTTON_A]
  ui_accept:        # SEPARATE entry — shares buttons but different logical action
    keys: [Enter, Space]
    joypad_buttons: [JOY_BUTTON_A]
```

When a timing window is open, the HUD input subtree is disabled (Rule 2), so `ui_accept` on HUD Controls cannot fire. `timing_confirm` reaches ITD cleanly.

### Rule 2: Recursive HUD Input Disable During Timing Windows

⚠️ **ENGINE RISK — VERIFY BEFORE CLOSING ANY HUD OR ITD STORY**

The intended behavior is: during a timing window, no HUD Control can grab focus, consume events, or respond to input. The implementation approach below must be validated by the smoke test before any story depending on it is marked Done.

**Why the risk exists**: `set_process_input(false)` called on a `CanvasLayer` (which extends `Node`, not `Control`) disables `_input()` processing on that specific node. However, Godot's GUI input system routes `_gui_input()` through the Control tree independently of `set_process_input()`. Child Controls may still receive `_gui_input()` events even when their ancestor CanvasLayer has `set_process_input(false)`. The 4.5 recursive Control disable applies specifically to mouse filter propagation, not to `set_process_input()`.

**Current implementation (smoke test required):**

```gdscript
# In BattleSceneRoot (composition root):
@onready var _itd: InputTimingDetector = $InputTimingDetector
@onready var _hud_root: CanvasLayer = $HUDSystem/HUDCanvasLayer

func _ready() -> void:
    _itd.window_opened.connect(_on_window_opened)
    _itd.window_closed.connect(_on_window_closed)

func _on_window_opened(_mode: StringName) -> void:
    # ⚠️ UNVERIFIED: Does set_process_input(false) on CanvasLayer suppress
    # _gui_input() on all child Controls? If the smoke test fails, replace
    # with the fallback implementation below.
    _hud_root.set_process_input(false)
    _hud_root.set_process_unhandled_input(false)

func _on_window_closed(_grade: StringName) -> void:
    _hud_root.set_process_input(true)
    _hud_root.set_process_unhandled_input(true)
```

**Fallback if smoke test fails** — iterate all interactive Controls directly:

```gdscript
func _on_window_opened(_mode: StringName) -> void:
    # Reliable fallback: set mouse_filter on all interactive HUD Controls
    for control in _get_interactive_hud_controls():
        control.mouse_filter = Control.MOUSE_FILTER_IGNORE
    # Also release keyboard focus so no Control holds timing_confirm
    if _hud_root.get_viewport().gui_get_focus_owner() != null:
        _hud_root.get_viewport().gui_get_focus_owner().release_focus()

func _on_window_closed(_grade: StringName) -> void:
    for control in _get_interactive_hud_controls():
        control.mouse_filter = Control.MOUSE_FILTER_PASS  # restore default
```

This means: during a timing window, no HUD Control can grab focus, consume events, or respond to input. ITD receives the `timing_confirm` event via `_input()` without competition.

### Rule 3: `_input()` Order — ITD at Battle Scene Root Level

ITD is placed as a direct child of the battle scene root (not nested under CanvasLayer or any HUD node). In Godot 4.x, `_input()` fires top-to-bottom in the scene tree. ITD at root level fires before any nested HUD nodes, giving it first access to every event.

```
BattleSceneRoot (Node)
  ├── InputTimingDetector      ← _input() fires here first
  ├── TimingCombatSystem
  ├── AbilitySystem
  └── HUDSystem (CanvasLayer)  ← disabled during timing windows (Rule 2)
        └── HUDContainer (Node2D)
              └── [all HUD Controls]
```

### Rule 4: HUD Combat Controls Use `MOUSE_FILTER_IGNORE`

All HUD Controls that display combat state (HP bars, status effect icons, turn order, enemy condition) and do NOT require mouse interaction during combat set:

```gdscript
mouse_filter = Control.MOUSE_FILTER_IGNORE
```

This prevents these Controls from capturing mouse events that should pass through to the game world. Controls that DO require mouse interaction (ability selection menus, target selection) retain their default mouse filter but follow Rule 2 (disabled during active timing windows).

### Rule 5: Dual-Focus Awareness for Menu Navigation

Outside of combat timing windows (menus, world exploration), normal Control focus is used for keyboard/gamepad navigation:

- `grab_focus()` is called on the first interactive element in each menu screen — this only sets keyboard/gamepad focus (Godot 4.6 confirmed)
- Mouse focus is automatic (hover-based) and separate
- Hover-only interactions are forbidden (per `technical-preferences.md`) — all interactive elements must have a keyboard/gamepad equivalent, consistent with the dual-focus model

### Key Interfaces

```gdscript
# InputTimingDetector API (from ITD GDD):
signal window_opened(mode: StringName)      # broadcast before first frame tick
signal window_frame_tick(current_frame: int, total_frames: int, mode: StringName)
signal window_closed(grade: StringName)
signal input_result(mode: StringName, grade: StringName)

func open_action_window(frames: int) -> void
func open_block_window(frames: int) -> void
func force_close_window() -> void

# Test seam (for unit tests):
func inject_input(action: StringName) -> void
func advance_frame() -> void
```

### Architecture Diagram

```
TIMING WINDOW OPEN:
  Physical button press
       │
       ▼
  Godot Input System
       │
       ├──► ITD._input(event)          [fires first — ITD at scene root]
       │         ↓
       │    is_action_pressed(&"timing_confirm")
       │         ↓
       │    window grade calculated → emit input_result(mode, grade)
       │         ↓
       │    accept_event() ← marks event handled (optional safety)
       │
       └──► HUDSystem._input(event)    [BLOCKED — set_process_input(false)]
                 (never fires during window)

MENU PHASE (no timing window):
  Physical button press
       │
       ▼
  Godot Input System
       │
       ├──► ITD._input(event)          [ITD not in IDLE state → ignores all events]
       │
       └──► Focused Control._gui_input(event)   [normal UI navigation]
```

## Alternatives Considered

### Alternative 1: `_unhandled_input()` in ITD
- **Description**: ITD uses `_unhandled_input()` instead of `_input()` — fires only after GUI processing completes
- **Pros**: ITD naturally doesn't interfere with UI navigation; no need to disable HUD input during windows
- **Cons**: A focused Control that handles `timing_confirm` (or any action sharing the same key) could consume the event before ITD sees it; `_unhandled_input()` fires after GUI processing, adding one extra processing step per frame — minor but non-zero latency
- **Rejection Reason**: Timing precision is critical for PERFECT/GOOD/BLOCK grades; any processing step between button press and ITD receipt risks a missed grade in edge-case frames. `_input()` provides deterministic first-access.

### Alternative 2: Viewport Container Separation
- **Description**: Run HUD in a separate `SubViewport` container, completely isolating its input from the gameplay viewport
- **Pros**: Perfect separation — HUD input never reaches gameplay layer
- **Cons**: Requires `SubViewportContainer` which adds rendering complexity and `CanvasLayer`-equivalent coordinate translation; two separate input streams to coordinate; architectural complexity far exceeds the problem being solved
- **Rejection Reason**: Over-engineered for a turn-based RPG with a simple battle scene

### Alternative 3: Action Overlap Prevention Only (No Window Disable)
- **Description**: Rely solely on `timing_confirm` having no `ui_*` overlap; no recursive HUD disable
- **Pros**: Simpler — no signal connection to manage window state in composition root
- **Cons**: Leaves a future risk surface: if any programmer accidentally binds a HUD Control to respond to `timing_confirm` directly (via `_gui_input` with direct key checks), events could still be duplicated; no defense in depth
- **Rejection Reason**: Defense in depth is preferable for a timing-critical system; the recursive disable is low-cost (two signal connections in the composition root) and eliminates the entire class of accidental focus interference

## Consequences

### Positive
- ITD receives `timing_confirm` with deterministic timing across all input methods
- No HUD element can silently consume a timing window input
- Dual-focus complexity is contained to one composition root pattern (Rules 2 and 5)
- `MOUSE_FILTER_IGNORE` on passive HUD Controls prevents accidental click-throughs

### Negative
- Battle scene composition root must wire up `window_opened` / `window_closed` signals to HUD disable/enable — this is coupling that must not be forgotten when adding new battle scenes
- Any new HUD Controls added in future must be evaluated: does it need input during combat? If not, `MOUSE_FILTER_IGNORE` must be set.
- `timing_confirm` appearing in both InputMap as its own action AND sharing keys with `ui_accept` requires documentation — a programmer unfamiliar with the rule might wonder why two actions share the same key

### Risks
- **Risk**: A future battle scene is created without the `window_opened`/`window_closed` wiring
  **Mitigation**: Control Manifest explicitly lists this as a required composition root wire-up. `/story-done` check includes "HUD disable wired to ITD signals" as a validation criterion for any ITD story.
- **Risk**: `set_process_input(false)` recursive behavior removed or changed in a future Godot version
  **Mitigation**: Godot 4.5 feature, stable in 4.6. Low version-churn risk for a single-engine project. Document the assumption in the smoke test.
- **Risk**: `timing_confirm` is accidentally added to `ui_accept`'s mapping in Project Settings
  **Mitigation**: They are separate InputMap entries. The Control Manifest documents this explicitly as a forbidden configuration.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| `input-and-timing-detection.md` | ITD uses `_input(event: InputEvent)` for event detection | Confirmed as the routing method; Rule 3 (scene position) ensures it fires first |
| `input-and-timing-detection.md` | `timing_confirm` action must not be echo-filtered out | `event.is_echo()` guard in ITD (GDD requirement) combined with `_input()` first-access |
| `input-and-timing-detection.md` | `_input()` processes before `_physics_process()` in the same frame (verified Godot 4.6) | Confirmed in engine reference; architecture note preserved |
| `hud-system.md` | HUD uses CanvasLayer 10/11/12 with Node2D child containers | `MOUSE_FILTER_IGNORE` rule applies to all passive HUD Controls in these layers |
| `hud-system.md` | HUD must not interfere with combat input | Recursive disable during timing windows (Rule 2) provides hard separation |
| `timing-combat-system.md` | TCS calls `itd.open_action_window(frames)` at turn start | Established interface preserved; composition root wiring documented here |

## Performance Implications
- **CPU**: Negligible — two signal connections in the composition root; one `set_process_input()` call per timing window open/close
- **Memory**: No impact
- **Load Time**: No impact
- **Network**: Not applicable

## Migration Plan

No existing code to migrate. This pattern is established before any gameplay system is implemented.

When adding new HUD Controls:
1. Evaluate: does this Control require player input during active combat timing windows?
2. If no: set `mouse_filter = Control.MOUSE_FILTER_IGNORE`
3. If yes: confirm the Control is correctly silenced by the `_hud_root.set_process_input(false)` call during windows

## Validation Criteria

- [ ] Project Settings InputMap has `timing_confirm` as a standalone entry, separate from `ui_accept`
- [ ] During an open timing window, a focused HUD Control does not fire `_gui_input()` when `Space`/`JOY_BUTTON_A` is pressed
- [ ] ITD `_input()` records the `timing_confirm` event with the correct frame count during a window (PERFECT / GOOD / MISS verified)
- [ ] After `window_closed` fires, HUD Controls resume responding to `ui_accept` normally
- [ ] Passive HUD Controls (HP bars, status icons) have `mouse_filter = MOUSE_FILTER_IGNORE`
- [ ] Test with gamepad: d-pad navigation in menus works correctly; switching to combat phase silences HUD input; timing windows accept JOY_BUTTON_A

## Related Decisions
- ADR-0002: Autoload Singleton Strategy — establishes composition root pattern used to wire ITD signals to HUD disable
- ADR-0004: Combat Event Signal Bus — determines the full signal topology connecting TCS → HUD; ITD's signals to composition root are a subset of this
- `design/gdd/input-and-timing-detection.md` — source of ITD FSM, signal schema, and `timing_confirm` requirements
- `design/gdd/hud-system.md` — source of CanvasLayer structure and MOUSE_FILTER_IGNORE constraint

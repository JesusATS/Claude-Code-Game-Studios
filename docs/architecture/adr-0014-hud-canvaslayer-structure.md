# ADR-0014: HUD CanvasLayer Structure

## Status

Accepted

## Date

2026-05-04

## Last Verified

2026-05-04

## Decision Makers

Jesus Gallegos + Claude Code (Technical Director review)

## Summary

The HUD requires a three-layer CanvasLayer hierarchy (10/11/12) for visual separation of combat information, grade flash overlay, and encounter result text, but `CanvasLayer` in Godot 4.x extends `Node` (not `CanvasItem`) and has no `modulate` property, preventing direct tween-based warm/cool palette participation. This ADR establishes the `Node2D` container pattern that gives each HUD CanvasLayer a tweakable modulate surface, specifies the ratio-driven `_process()` model for the timing bar animation (required for sub-3-frame window fidelity), and defines the custom `HUDInputRouter` for simultaneous gamepad and mouse navigation of the Action Menu.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 (Compatibility renderer) |
| **Domain** | UI / Rendering |
| **Knowledge Risk** | LOW — CanvasLayer extends Node since Godot 4.0; create_tween() on Node since 4.0; await get_tree().process_frame is standard Godot 4.x |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `design/gdd/hud-system.md` Rule 10 CanvasLayer modulate note |
| **Post-Cutoff APIs Used** | None — all APIs in this ADR are available since Godot 4.0 |
| **Verification Required** | Confirm CanvasLayer.layer property range allows 10–12 with no conflict against Godot's built-in UI layers (layer 128+). Confirm `Node2D.modulate` tween is visible when CanvasLayer.layer is set to non-default value. |

> **Note**: Knowledge Risk is LOW. CanvasLayer has extended Node (not CanvasItem) since Godot 4.0 and this is documented behaviour. No re-validation required unless upgrading past Godot 4.x major version.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (Autoload Strategy — PCM injection pattern); ADR-0003 (Input Routing — timing_confirm separation); ADR-0004 (CombatEventBus — HUD subscribes to bus signals); ADR-0006 (Combat State Machine — CombatEnvironmentController placement stub, BattleSceneRoot scene tree) |
| **Enables** | HUD System epic and all HUD stories |
| **Blocks** | HUD System implementation epic — cannot begin until this ADR is Accepted |
| **Ordering Note** | ADR-0006 established CombatEnvironmentController as a BattleSceneRoot-level peer; this ADR specifies the CanvasModulate coordination contract between CombatEnvironmentController and the HUD Node2D containers. |

## Context

### Problem Statement

Three architectural gaps block HUD implementation:

1. **CanvasLayer modulate participation**: The GDD (Rule 10) requires HUD panels to participate in the warm/cool palette shift triggered by `CanvasModulate` at encounter end. `CanvasLayer` extends `Node`, not `CanvasItem` — it has no `modulate` property. Without a structural workaround, the HUD cannot respond to encounter result colour transitions using `create_tween()`.

2. **Timing bar animation fidelity at minimum window sizes**: Formula H1 computes `cursor_fill_px` from elapsed real time, not from ITD frame ticks. At minimum window sizes (W=2, `window_duration_seconds ≈ 0.033s`), only 0–1 ITD tick signals arrive before the window closes. A tick-driven animation would appear visually frozen. The animation must run at render rate via `_process()`.

3. **Dual gamepad/mouse Action Menu navigation**: The GDD (Rule 2) explicitly states this is NOT Godot's built-in `Control` dual-focus system. Gamepad d-pad selection index and mouse hover position must track independently without interfering with each other, and neither must suppress `timing_confirm` input events (ADR-0003 constraint).

### Current State

No HUD implementation exists. The scene tree placeholder from ADR-0006 reserves CanvasLayer positions 10–12 but does not specify internal structure.

### Constraints

- `CanvasLayer` has no `modulate` property (Godot 4.x architectural fact — not a version-specific limitation)
- Timing bar animation must complete gracefully even at W=2 (≈2 render frames total)
- Action Menu input routing must not compete with `timing_confirm` action (ADR-0003)
- HUD subscribes to `CombatEventBus` signals only — never to TCS/SE nodes directly (ADR-0004)
- All HUD child nodes must live under their CanvasLayer's `Node2D` container, not as direct CanvasLayer children (no modulate access otherwise)
- CanvasLayer layers 10–12 are HUD-reserved; layers ≥ 20 are non-HUD overlays (pause, dialogue, scene transitions)

### Requirements

- TR-HUD-001: CanvasLayer 10/11/12 hierarchy with modulate-capable Node2D containers
- TR-HUD-002: Ratio-driven timing bar updating at render rate in `_process()`
- TR-HUD-003: Custom dual-input routing (gamepad index + mouse hover independent)
- CanvasLayer 10 and 11 Node2D containers tween modulate to warm/cool overlays on `encounter_ended`
- CanvasLayer 12 Node2D container does NOT receive modulate tween — result text colour carries the palette signal
- All modulate tweens reset to `Color.WHITE` on `encounter_started` (any in-flight tween killed first)

## Decision

### 1. CanvasLayer 10/11/12 Assignment

Three CanvasLayer nodes exist as children of `BattleSceneRoot`, with fixed layer assignments:

| Node Name | Layer | Contents | Modulate Tween |
|-----------|-------|----------|----------------|
| `HUDLayer10` | 10 | Main HUD: turn strip, party HP bars, CC bar, enemy status panels, timing bar, action menu | YES — warm/cool on encounter end |
| `HUDLayer11` | 11 | Grade flash overlay | YES — warm/cool on encounter end |
| `HUDLayer12` | 12 | Encounter result text (VICTORY / DEFEAT) | NO — text colour carries the palette |

Layers ≥ 20 are reserved for non-HUD overlays and are not defined here.

### 2. Node2D Container Pattern

Each CanvasLayer has exactly one `Node2D` as its direct child (the **container**). All HUD elements are children of this container — never direct children of the CanvasLayer itself.

```
BattleSceneRoot (Node2D)
  ├── TimingCombatSystem (Node)              [ADR-0006]
  ├── InputTimingDetector (Node)             [ADR-0006]
  ├── AbilitySystem (Node)                   [ADR-0009]
  ├── StatusEffects (Node)                   [ADR-0009]
  ├── AudioSystem (Node)                     [ADR-0006]
  ├── CombatEnvironmentController (Node)     [ADR-0006 — owns CanvasModulate]
  ├── HUDLayer10 (CanvasLayer, layer=10)
  │     └── HUDLayer10Root (Node2D)          ← sole direct child; tween .modulate here
  │           ├── TurnOrderStrip (Node2D)
  │           ├── PartyHPPanel (Node2D)
  │           ├── CCBar (Node2D)
  │           ├── EnemyStatusPanel (Node2D)
  │           ├── TimingBar (Node2D)
  │           └── ActionMenu (Node2D)
  ├── HUDLayer11 (CanvasLayer, layer=11)
  │     └── HUDLayer11Root (Node2D)          ← sole direct child; tween .modulate here
  │           └── GradeFlash (Node2D)
  └── HUDLayer12 (CanvasLayer, layer=12)
        └── HUDLayer12Root (Node2D)          ← sole direct child; NO modulate tween
              └── EncounterResultText (Node2D)
```

**Why Node2D, not Control?** Container nodes at this level are layout roots, not interactive Controls. `Node2D` is lighter-weight, carries a `modulate` property, and does not participate in Godot's `Control` focus chain — which would interfere with ADR-0003's dual-focus input routing.

### 3. Modulate Coordination with CombatEnvironmentController

`CombatEnvironmentController` (established in ADR-0006) is the sole writer of `CanvasModulate` in the battle scene. It also coordinates the HUD container modulate tweens by emitting signals that `HUDSystem` subscribes to (via `CombatEventBus.encounter_ended`).

On `encounter_ended("VICTORY")`:
- `HUDLayer10Root.modulate` tweens toward warm-tinted overlay. Duration: 1.5s, `TRANS_SINE`. Begins on the same frame as the scene `CanvasModulate` shift.
- `HUDLayer11Root.modulate` tweens identically.
- `HUDLayer12Root.modulate` is NOT tweened.

On `encounter_ended("DEFEAT")`:
- `HUDLayer10Root.modulate` and `HUDLayer11Root.modulate` tween toward a desaturated cool overlay. Duration: 1.5–2.0s, `TRANS_SINE`.

On `encounter_started`:
1. Kill any in-flight tween on `HUDLayer10Root`, `HUDLayer11Root`, `HUDLayer12Root`.
2. Immediately set all three container `modulate = Color.WHITE`.

```gdscript
# HUDSystem._on_encounter_ended(result: StringName)
func _on_encounter_ended(result: StringName) -> void:
    var tween: Tween = create_tween().set_parallel(true)
    if result == &"VICTORY":
        tween.tween_property(_layer10_root, "modulate", WARM_OVERLAY_COLOR, 1.5)\
             .set_trans(Tween.TRANS_SINE)
        tween.tween_property(_layer11_root, "modulate", WARM_OVERLAY_COLOR, 1.5)\
             .set_trans(Tween.TRANS_SINE)
    elif result == &"DEFEAT":
        tween.tween_property(_layer10_root, "modulate", COOL_OVERLAY_COLOR, 2.0)\
             .set_trans(Tween.TRANS_SINE)
        tween.tween_property(_layer11_root, "modulate", COOL_OVERLAY_COLOR, 2.0)\
             .set_trans(Tween.TRANS_SINE)

# HUDSystem._on_encounter_started(...)
func _on_encounter_started(_combatant_ids: Array[StringName], _enemy_ids: Array[StringName]) -> void:
    if _active_tween and _active_tween.is_running():
        _active_tween.kill()
    _layer10_root.modulate = Color.WHITE
    _layer11_root.modulate = Color.WHITE
    _layer12_root.modulate = Color.WHITE
```

Exact overlay colour values (`WARM_OVERLAY_COLOR`, `COOL_OVERLAY_COLOR`) are specified by the UX spec (`design/ux/hud.md`). HUDSystem reads them from a `const` in a companion data file — not hardcoded inline.

### 4. Ratio-Driven Timing Bar (_process() Model)

`TimingBar` is a `Node2D` child of `HUDLayer10Root`. It accumulates `delta` in `_process()` to compute `t`, then applies Formula H1 to set the cursor width every render frame.

```gdscript
class_name TimingBar extends Node2D

const DEFAULT_BAR_PIXEL_WIDTH: int = 200
const MIN_WINDOW_FRAMES: int = 2

var bar_pixel_width: int = DEFAULT_BAR_PIXEL_WIDTH   # tuning knob
var _window_open: bool = false
var _window_duration_seconds: float = 0.0
var _elapsed_seconds: float = 0.0
var _total_frames: int = 0
var _perfect_zone_px: int = 0

# Called by HUDSystem when CombatEventBus relays timing_window_opened
func open_window(window_frames: int, perfect_zone_size: int) -> void:
    if window_frames < MIN_WINDOW_FRAMES:
        push_error("TimingBar: window_frames %d < %d, clamping" \
                   % [window_frames, MIN_WINDOW_FRAMES])
        window_frames = MIN_WINDOW_FRAMES
    _total_frames = window_frames
    _window_duration_seconds = window_frames / 60.0
    _elapsed_seconds = 0.0
    _perfect_zone_px = floori(bar_pixel_width * (perfect_zone_size / float(window_frames)))
    _perfect_zone_px = maxi(1, _perfect_zone_px)
    _window_open = true
    show()
    _apply_h1()

func _process(delta: float) -> void:
    if not _window_open:
        return
    _elapsed_seconds = minf(_elapsed_seconds + delta, _window_duration_seconds)
    _apply_h1()

func _apply_h1() -> void:
    var t: float = _elapsed_seconds / _window_duration_seconds
    t = clampf(t, 0.0, 1.0)
    var cursor_fill_px: float = bar_pixel_width * (1.0 - t)
    _cursor_rect.size.x = cursor_fill_px   # sub-pixel float, Godot renders correctly

# Called by HUDSystem when CombatEventBus relays grade_resolved
func on_grade_resolved(grade: StringName) -> void:
    _window_open = false
    if grade == &"PERFECT":
        _do_perfect_flash.call_deferred()
    else:
        hide()

func _do_perfect_flash() -> void:
    # Frame N (grade_resolved fired): bar is in current depleted state — no change yet
    await get_tree().process_frame
    # Frame N+1: fill to full width, set Victory Gold
    _cursor_rect.size.x = bar_pixel_width
    _cursor_rect.modulate = VICTORY_GOLD
    await get_tree().process_frame
    # Frame N+2: collapse
    hide()
    _cursor_rect.modulate = Color.WHITE   # reset for next use
```

**Why `_process()`, not per-tick signals?** At W=2 (`window_duration_seconds ≈ 0.033s`), ITD emits at most 1 `window_frame_tick` signal before the window closes. Tick-driven width updates would show 1–2 discrete jumps, not a smooth depletion. `_process()` runs every render frame (~16ms), producing ~2 width samples even in the W=2 case — visually continuous.

**Why `call_deferred()` on `_do_perfect_flash`?** `on_grade_resolved` may be called from a signal dispatch during `_process()`. Deferring the coroutine ensures frame boundary alignment — the first `await get_tree().process_frame` lands on the next frame cleanly.

### 5. PERFECT Flash Coroutine Contract

The two-await coroutine pattern in `_do_perfect_flash()` is the mandated implementation for the PERFECT grade visual. No alternative is permitted:

- **Forbidden**: Polling `_process()` with a frame counter to drive the PERFECT flash — this creates shared state between the depletion animation loop and the flash sequence.
- **Forbidden**: Using `Timer` nodes or `SceneTreeTimer` for the 1-frame delay — timer resolution is not frame-aligned.
- **Permitted**: `await get_tree().process_frame` (twice). Each await yields until the next rendered frame. This is the GDD's explicit specification (Rule 7, VA-2.4 note).

### 6. Custom HUDInputRouter (Dual Gamepad/Mouse Action Menu)

`HUDInputRouter` is a `Node` child of `ActionMenu`. It is active only when `ActionMenu` is visible (during `PLAYER_ACTION` TCS state). It handles `_input()` directly — not via `Control` focus.

```gdscript
class_name HUDInputRouter extends Node

signal ability_selected(ability_index: int)

var _ability_count: int = 0
var _gamepad_index: int = 0       # last d-pad selection; persists until menu closes
var _mouse_hover_index: int = -1  # -1 = no hover; updated every MouseMotion event
var _active: bool = false

func activate(ability_count: int) -> void:
    _ability_count = ability_count
    _gamepad_index = 0
    _mouse_hover_index = -1
    _active = true
    _emit_highlight()

func deactivate() -> void:
    _active = false

func _input(event: InputEvent) -> void:
    if not _active:
        return
    # Gamepad d-pad: moves selection index; does NOT move mouse cursor
    if event is InputEventJoypadButton and event.pressed:
        if event.button_index == JOY_BUTTON_DPAD_DOWN:
            _gamepad_index = (_gamepad_index + 1) % _ability_count
            _emit_highlight()
            get_viewport().set_input_as_handled()
        elif event.button_index == JOY_BUTTON_DPAD_UP:
            _gamepad_index = (_gamepad_index - 1 + _ability_count) % _ability_count
            _emit_highlight()
            get_viewport().set_input_as_handled()
        elif event.is_action_pressed(&"ui_accept"):
            ability_selected.emit(_gamepad_index)
            get_viewport().set_input_as_handled()
    # Mouse motion: updates hover index; does NOT change gamepad selection
    elif event is InputEventMouseMotion:
        _mouse_hover_index = _get_index_at_position(event.position)
        _emit_highlight()
    # Mouse click: confirms hover index if valid
    elif event is InputEventMouseButton and event.pressed \
            and event.button_index == MOUSE_BUTTON_LEFT:
        if _mouse_hover_index >= 0:
            ability_selected.emit(_mouse_hover_index)
            get_viewport().set_input_as_handled()

func _emit_highlight() -> void:
    # ActionMenu listens to this to update visual highlight
    # Gamepad highlight takes precedence if mouse is not hovering
    var highlight_index: int = _mouse_hover_index if _mouse_hover_index >= 0 \
                               else _gamepad_index
    pass  # ActionMenu wires highlight_changed signal
```

**Key invariant**: `timing_confirm` (`Space` / `JOY_BUTTON_A`) is never handled by `HUDInputRouter`. ADR-0003 forbids aliasing `timing_confirm` to `ui_accept`. `HUDInputRouter` only handles `JOY_BUTTON_DPAD_UP/DOWN` and `ui_accept` for menu navigation — these are distinct actions that do not overlap with `timing_confirm`.

**Why not Godot's Control dual-focus?** Godot's built-in Control focus system applies to `Control` nodes and manages a single focus ring. It cannot simultaneously track a gamepad selection index (positional, not focus-based) and a mouse hover position (spatial, not focus-based) as independent cursors. The custom router solves this with two independent index variables.

## Alternatives Considered

### Alternative 1: CanvasLayer Modulate via Shader

Apply a colour-modulate shader to each CanvasLayer's material to simulate warm/cool palette participation.

- **Pros**: No Node2D container required; applies to all direct children regardless of type.
- **Cons**: Requires per-CanvasLayer shader material; shader parameters need the same tween logic anyway; adds GPU overhead; Compatibility renderer shader complexity is undesirable for a simple tween effect.
- **Rejection Reason**: Node2D container pattern achieves identical visual output with zero shader cost and a `create_tween()` call that implementers already know.

### Alternative 2: Timing Bar via ITD window_frame_tick Signal

Update `cursor_fill_px` once per `window_frame_tick` signal from ITD rather than per `_process()` frame.

- **Pros**: Perfectly aligned with simulation frames; eliminates real-time delta accumulation.
- **Cons**: At W=2 (minimum window size), only 1–2 ticks fire before window close. Tick-driven animation at this scale produces a visually frozen bar. The GDD explicitly prohibits tick-driven animation for this reason (Formula H1 implementation constraint).
- **Rejection Reason**: Violates GDD Formula H1 specification. `_process()` at render rate is mandatory.

### Alternative 3: Godot Control Dual-Focus for Action Menu

Use Godot 4.6's built-in `Control` focus and `set_focus_mode()` to manage the Action Menu navigation.

- **Pros**: Built-in, no custom code; handles keyboard navigation automatically.
- **Cons**: `Control` focus is a single cursor — cannot simultaneously represent independent gamepad selection index and mouse hover index. D-pad navigation would visually move the OS focus ring, not a custom highlight. GDD Rule 2 explicitly bans this approach.
- **Rejection Reason**: Explicitly prohibited by the GDD. Custom `HUDInputRouter` is the specified design.

## Consequences

### Positive

- Modulate-based warm/cool HUD participation requires no per-element custom logic — tween the Node2D container and all children inherit.
- `_process()` timing bar is correct at all window sizes (W=2 through W=30) without special-casing.
- `HUDInputRouter` is testable in isolation: inject synthetic `InputEvent` objects and assert `ability_selected` emission.
- CanvasLayer 10/11/12 separation enables independent z-ordering of grade flash over HUD elements without z_index fighting within a single layer.

### Negative

- Node2D container adds one node per CanvasLayer (3 extra nodes in the scene tree). Negligible performance cost; minor structural overhead.
- `HUDInputRouter` custom code is a maintenance surface. If Godot introduces native dual-cursor support in a future version, this class may become redundant.
- `_do_perfect_flash()` coroutine creates a short-lived async gap. If `HUDSystem` is freed during the 2-frame wait, the coroutine will attempt to access freed objects. Guard with `is_instance_valid(self)` at each resume point.

### Neutral

- Exact overlay colour constants (`WARM_OVERLAY_COLOR`, `COOL_OVERLAY_COLOR`) are deferred to the UX spec. This ADR establishes the tween pattern; the UX spec fills in the colour values.
- CanvasLayer layer numbers 10–12 do not conflict with Godot's reserved layer range (128+).

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| `_do_perfect_flash` coroutine uses freed node | Low | Medium — null access error during fast battle exit | Add `if not is_instance_valid(self): return` after each `await` |
| Tween not killed before `encounter_started` resets modulate | Low | Low — visual glitch (flash of wrong colour) | `kill()` any active tween before `Color.WHITE` reset in `_on_encounter_started` |
| HUDInputRouter swallows `timing_confirm` events | Very Low | High — missed timing input | `HUDInputRouter` never handles `timing_confirm` or `JOY_BUTTON_A` for confirm (only DPAD + `ui_accept`); `timing_confirm` is a separate action (ADR-0003) |
| Node2D container `modulate` property conflicts with child element modulate | Low | Low — tinting stacks multiplicatively | Acceptable: all HUD elements default `modulate = Color.WHITE`; parent tint is the intended effect |

## Performance Implications

| Metric | Before | Expected After | Budget |
|--------|--------|----------------|--------|
| CPU (frame time) | 0ms (not implemented) | ~0.05ms for `_process()` timing bar width update | ≪16.6ms |
| Memory | 0 | 3 extra Node2D nodes, 1 HUDInputRouter Node | Negligible |
| Draw Calls | 0 | ~6 Node2D containers in scene tree | No change to renderer calls |

## Migration Plan

No existing HUD implementation — this is a greenfield spec.

**Rollback plan**: If Node2D container pattern causes unexpected rendering issues (z-ordering, occlusion), the fallback is to move HUD elements to a single flat CanvasLayer and apply warm/cool tween via a CanvasLayer-level shader uniform. This would supersede sections 2–3 of this ADR.

## Validation Criteria

- [ ] `HUDLayer10Root.modulate` transitions to warm colour on VICTORY, cool colour on DEFEAT, resets to WHITE on new `encounter_started` — verified by GUT integration test with mock CombatEventBus signals
- [ ] Timing bar cursor width at W=2: bar depletes visibly over 2 rendered frames (not frozen) — verified by GUT test driving `_process(delta)` manually with `delta = 1.0/60.0`
- [ ] PERFECT flash: bar stays at depleted width on resolve frame, fills Victory Gold on frame N+1, hides on frame N+2 — verified by GUT test advancing `get_tree().process_frame` twice
- [ ] `HUDInputRouter`: d-pad navigation changes `_gamepad_index` without affecting `_mouse_hover_index` — verified by unit test injecting `InputEventJoypadButton` then asserting `_mouse_hover_index == -1`
- [ ] `HUDInputRouter`: `timing_confirm` events are not consumed by the router — verified by unit test injecting `timing_confirm` action event and confirming `ability_selected` is NOT emitted
- [ ] All three CanvasLayer Node2D containers exist as sole direct children in the scene — verified by editor scene inspection

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|---|---|---|---|
| `design/gdd/hud-system.md` | HUD System | TR-HUD-001: CanvasLayer 10/11/12 with Node2D containers for modulate | Establishes three-layer assignment, Node2D sole-direct-child pattern, and `create_tween()` targeting Node2D containers |
| `design/gdd/hud-system.md` | HUD System | TR-HUD-002: Ratio-driven timing bar (frame tick) | Specifies `_process()` delta-accumulation model, H1 formula application per render frame, and two-await PERFECT flash coroutine |
| `design/gdd/hud-system.md` | HUD System | TR-HUD-003: Custom dual-input routing (gamepad + mouse independent) | Defines `HUDInputRouter` with independent `_gamepad_index` and `_mouse_hover_index` state that do not interfere; explicitly not Godot's Control dual-focus system |
| `design/gdd/hud-system.md` | HUD System | Rule 10 CanvasLayer modulate participation | `HUDLayer10Root` and `HUDLayer11Root` receive TRANS_SINE tween on encounter_ended; HUDLayer12Root is excluded per GDD spec |

## Related

- ADR-0003 — Input Routing: `timing_confirm` separation that `HUDInputRouter` must respect
- ADR-0004 — CombatEventBus: HUD subscribes at `_ready()` — source of all combat signals consumed by this ADR
- ADR-0006 — Combat State Machine: CombatEnvironmentController placement stub (peer of TCS at BattleSceneRoot); this ADR specifies the modulate coordination protocol
- ADR-0009 — Status Effect Application Contract: `status_effect_applied` signal schema (6-param) consumed by Rule 7a MUTED narrowing logic in `TimingBar`

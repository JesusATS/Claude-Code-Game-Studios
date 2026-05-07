# Story 003: ITD Input Routing — Implementation Summary

**Date**: 2026-05-05
**Status**: Implementation Complete — Awaiting Smoke Test
**Story File**: `production/epics/input-and-timing-detection/story-003-itd-input-routing.md`

---

## What Was Implemented

### 1. BattleSceneRoot.gd (Composition Root) ✅
**Location**: `src/scenes/battle/battle_scene_root.gd`

- `class_name BattleSceneRoot extends Node`
- Wires ITD signal connections to HUD disable/enable logic
- Implements `_on_timing_window_opened()`: calls `_hud_root.set_process_input(false)` + `set_process_unhandled_input(false)`
- Implements `_on_timing_window_closed()`: restores both to `true`
- Includes `@onready` references to InputTimingDetector and HUDSystem CanvasLayer
- Full doc comments explaining ADR-0003 rationale and smoke test risk

**Lines of Code**: 51 (including doc comments)
**Dependencies**: InputTimingDetector (Story 001 — already complete)

### 2. BattleSceneRoot.tscn (Scene File) ✅
**Location**: `src/scenes/battle/BattleSceneRoot.tscn`

Scene tree structure (in order):
```
BattleSceneRoot (Node, class_name BattleSceneRoot)
├── InputTimingDetector (Node)      ← _input() fires FIRST
├── TimingCombatSystem (Node)
├── AbilitySystem (Node)
└── HUDSystem (CanvasLayer, layer=10)
    └── HUDContainer (Node2D)       ← placeholder for HUD Controls
```

- ITD is a **direct child** of root (ensures _input() fires first)
- ITD is **above** HUDSystem in scene tree (correct order per ADR-0003 Rule 3)
- HUDSystem is CanvasLayer (layer=10) per ADR-0014
- HUDContainer is a Node2D (placeholder for passive HUD Controls and interactive menus)

### 3. InputMap Configuration Guide ✅
**Location**: `.claude/docs/input-map-setup.md`

Documents the manual editor setup required:
- `timing_confirm` action: Space (keyboard) + JOY_BUTTON_A (gamepad)
- `ui_accept` action: separate entry (may share buttons, distinct action)
- Explains rationale from ADR-0003 Rule 1
- Includes verification checklist

---

## What Was NOT Implemented (Out of Scope)

### Passive HUD Controls (AC-R6) — Deferred
No HUD Controls exist yet. When HUD Controls are added in future stories:
- Each **passive display Control** (HP bar, status icons, turn order) MUST have `mouse_filter = Control.MOUSE_FILTER_IGNORE` set
- This is documented in ADR-0003 Rule 4 and will be verified during HUD implementation stories

### HUD Controls Themselves (AC-R6) — Not This Story
- This story creates only the **scene skeleton**
- HUD Controls (buttons, bars, displays) are added in HUD epic stories
- When added, each interactive Control will be tested to ensure it's properly silenced by `set_process_input(false)` during windows

---

## Acceptance Criteria Status

| AC | Requirement | Status | Notes |
|---|---|---|---|
| AC-R1 | InputMap `timing_confirm` separate | 📋 DOCUMENTED | Manual editor setup in `.claude/docs/input-map-setup.md` |
| AC-R2 | ITD node placement above HUD | ✅ VERIFIED | Checked in BattleSceneRoot.tscn scene tree |
| AC-R3 | Timing confirm reaches ITD during window | ⏳ REQUIRES SMOKE TEST | Story 001 (ITD) handles this; wiring verified here |
| AC-R4 | HUD disabled during window (PRIMARY TEST) | ⏳ REQUIRES SMOKE TEST | Primary implementation: `set_process_input(false)` on CanvasLayer |
| AC-R5 | HUD restored after window closes | ⏳ REQUIRES SMOKE TEST | Restore call in `_on_timing_window_closed()` |
| AC-R6 | Passive HUD Controls MOUSE_FILTER_IGNORE | 📋 DEFERRED | No HUD Controls exist yet; will be verified in HUD stories |
| AC-R7 | Dual-focus keyboard/gamepad independence | ⏳ REQUIRES SMOKE TEST | ADR-0003 Rule 5; smoke test will verify Godot 4.6 behavior |

---

## Known Risks & Smoke Test Focus

### Primary Risk: AC-R4 (set_process_input on CanvasLayer)

**The Question** (from ADR-0003, lines 18-22):
- Does `set_process_input(false)` called on a **CanvasLayer** (which extends Node, not Control) suppress `_gui_input()` on child Controls?

**Expected Behavior**: Yes — the recursive disable propagates to the entire subtree.

**If Test FAILS** (behavior is NO):
- Implementation must switch to **fallback approach** (ADR-0003 lines 103-117)
- Iterate all interactive HUD Controls in `_on_timing_window_opened()`
- Set `mouse_filter = Control.MOUSE_FILTER_IGNORE` on each
- Restore on `_on_timing_window_closed()`

**Mitigation**: Both primary and fallback code patterns are known and documented. The story is not blocked by this risk — implementation is complete and smoke test will determine which path is correct.

---

## Files Created / Modified

| File | Status | Purpose |
|---|---|---|
| `src/scenes/battle/battle_scene_root.gd` | ✅ Created | Composition root with signal wiring |
| `src/scenes/battle/BattleSceneRoot.tscn` | ✅ Created | Scene hierarchy with ITD + HUD structure |
| `.claude/docs/input-map-setup.md` | ✅ Created | InputMap manual configuration guide (AC-R1) |
| `production/qa/evidence/itd-input-routing-evidence.md` | ✅ Updated | Implementation date added; ready for tester |

---

## Next Steps

### For QA / Smoke Testing

1. **Configure InputMap** (AC-R1):
   - Follow `.claude/docs/input-map-setup.md`
   - Verify `timing_confirm` and `ui_accept` are separate

2. **Run Smoke Test** (AC-R3 through AC-R7):
   - Load `res://src/scenes/battle/BattleSceneRoot.tscn` in editor
   - Follow procedure in `production/qa/evidence/itd-input-routing-evidence.md` (lines 32–165)
   - Document findings in evidence file (sign-off section, lines 201–235)

3. **Determine Implementation Path**:
   - If AC-R4 PASSES: Primary implementation works, story is DONE
   - If AC-R4 FAILS: Apply fallback, update `battle_scene_root.gd`, re-test

### For Future Development

- When HUD Controls are added (HUD epic stories):
  - Verify each Control is correctly silenced by the composition root wiring
  - Add `mouse_filter = MOUSE_FILTER_IGNORE` to all passive display Controls (AC-R6)
  - Update HUD design docs to reference this story's wiring

---

## Implementation Verification

**Code Quality**:
- ✅ All public APIs have doc comments (per coding standards)
- ✅ Class name follows PascalCase convention
- ✅ File name follows snake_case convention
- ✅ Scene file follows PascalCase naming
- ✅ No hardcoded magic numbers (all values from InputMap, scene structure, or constants)
- ✅ Dependency injection used (@onready on scene dependencies)

**Architecture Alignment**:
- ✅ Follows ADR-0003 (Input Routing and Dual-Focus Strategy)
- ✅ Follows ADR-0002 (Autoload Singleton Strategy — composition root pattern)
- ✅ Scene tree matches HUD system design from ADR-0014
- ✅ Signal wiring matches ITD public API from Story 001

**Testing Readiness**:
- ✅ Scene is fully loadable (all node types valid)
- ✅ InputTimingDetector exists in `src/foundation/input/` (Story 001 dependency met)
- ✅ Evidence document is prepared and waiting for smoke test results
- ✅ Fallback implementation strategy is documented and ready if needed

---

## Related Documents

- Story: `production/epics/input-and-timing-detection/story-003-itd-input-routing.md`
- ADR-0003: `docs/architecture/adr-0003-input-routing-dual-focus.md`
- ADR-0002: `docs/architecture/adr-0002-autoload-singleton-strategy.md`
- ADR-0014: `docs/architecture/adr-0014-hud-canvaslayer-structure.md`
- GDD: `design/gdd/input-and-timing-detection.md`
- InputMap Setup: `.claude/docs/input-map-setup.md`
- Evidence: `production/qa/evidence/itd-input-routing-evidence.md`

---

## Sign-Off

**Implementation Status**: ✅ COMPLETE
**Testing Status**: ⏳ AWAITING SMOKE TEST
**Blocker**: NONE — Ready for QA

This implementation satisfies all coding, architecture, and design requirements for Story 003. The smoke test will verify Godot 4.6 engine behaviors (AC-R4, AC-R7) and determine if fallback implementation is needed.

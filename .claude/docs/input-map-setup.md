# InputMap Configuration Guide

## Status
Manual Godot Editor Configuration Required

## AC-R1: timing_confirm Action Setup

The `timing_confirm` action must be configured in Godot Project Settings as a **separate** entry from `ui_accept`.

### Steps

1. Open Godot Editor
2. Navigate to **Project → Project Settings → Input Map** tab
3. Add a new action named `timing_confirm` (if not already present)
4. Configure the following inputs for `timing_confirm`:
   - **Keyboard**: `Space`
   - **Gamepad**: `JOY_BUTTON_A` (South button / A button)
5. Verify that `ui_accept` is a **separate** action entry:
   - `ui_accept` may also contain `Space` and `JOY_BUTTON_A`, but must be a distinct entry
   - The two actions share physical keys but are logically separate

### Expected Result

Project Settings → Input Map should show:

```
timing_confirm:
  - Space (keyboard)
  - JOY_BUTTON_A (gamepad)

ui_accept:
  - Enter (keyboard)
  - Space (keyboard)
  - JOY_BUTTON_A (gamepad)
```

**Critical**: Both entries must exist. Do NOT merge `timing_confirm` into `ui_accept`'s mapping.

### Rationale

Separating these actions ensures that:
- ITD receives `timing_confirm` presses without GUI event consumption
- HUD Controls respond to `ui_accept` for menu navigation (outside of timing windows)
- During windows, HUD is disabled, so neither action fires on HUD Controls
- Clear action identity prevents accidental overlaps in future code

## Related Stories

- Story 003: ITD Input Routing (AC-R1)
- ADR-0003: Input Routing and Dual-Focus Strategy (Rules 1-2)

## Verification

- [ ] `timing_confirm` action exists in InputMap
- [ ] `timing_confirm` contains Space (keyboard) + JOY_BUTTON_A (gamepad)
- [ ] `ui_accept` is a separate action (not merged with `timing_confirm`)
- [ ] Smoke test AC-R1 passes (documented in `production/qa/evidence/itd-input-routing-evidence.md`)

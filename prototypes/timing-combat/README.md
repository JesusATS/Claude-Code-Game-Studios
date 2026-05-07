# Prototype: Timing Combat

**Question**: Is the timing combat mechanic intrinsically satisfying?
Does it feel "musical" and rewarding to a human player?

**Date**: 2026-05-06
**Status**: Ready to run

---

## How to Run

1. Open the Godot 4.6 editor with this project
2. Open `prototypes/timing-combat/timing_combat_prototype.tscn`
3. Press **F5** (or click Play Scene) to run
4. Play through the 8-round session
5. Fill in the playtest questions shown on the summary screen
6. Record your answers in `REPORT.md`

## Controls

| Key | Action |
|-----|--------|
| **SPACE** | Register timing input (press when cursor is in gold zone) |
| **R** | Restart from round 1 |

## How It Works

1. **Enemy Charging** — A red bar fills over ~2 seconds. Get ready.
2. **Window Opens** — A horizontal bar appears with three zones:
   - **GOLD (leftmost 35%)** = PERFECT
   - **GREEN (middle 40%)** = HIT
   - **DARK RED (rightmost 25%)** = MISS
3. **White cursor sweeps left → right** across the bar as the window counts down
4. **Press SPACE** while the cursor is in the gold zone for PERFECT
5. After 8 rounds, the summary screen appears with playtest questions

## Tuning Knobs

All in `timing_combat_prototype.gd` at the top:

| Constant | Default | What it controls |
|----------|---------|-----------------|
| `CHARGE_DURATION` | `2.0` | Seconds between windows (shorter = more intense) |
| `WINDOW_FRAMES` | `30` | Frames the window is open (~0.5s at 60fps) |
| `PERFECT_THRESHOLD` | `0.35` | How much of the bar is PERFECT zone |
| `HIT_THRESHOLD` | `0.75` | Where HIT zone ends and MISS begins |
| `TOTAL_ROUNDS` | `8` | Rounds per session |
| `FEEDBACK_DURATION` | `0.9` | Seconds to show grade before next round |

## What This Prototype Does NOT Include

- Damage formulas, HP, CC economy
- Status effects, abilities, enemy AI
- Audio feedback
- Art assets (all placeholder colored rectangles)
- Production architecture (no CombatEventBus, no ResourceRegistry)

This is a pure feel test for the core timing mechanic.

## After Testing

Fill in `REPORT.md` with your playtest observations.
Run `/playtest-report` to create a formal playtest document.

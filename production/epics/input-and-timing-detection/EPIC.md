# Epic: Input & Timing Detection

> **Layer**: Foundation
> **GDD**: design/gdd/input-and-timing-detection.md
> **Architecture Module**: `InputTimingDetector` (`src/core/input/input_timing_detector.gd`)
> **Status**: Ready
> **Stories**: 3 stories created

## Overview

This epic implements the frame-accurate input capture layer that underlies every timed action in *Lux Aeterna*. `InputTimingDetector` (class_name, standalone .gd) runs a 4-state FSM (IDLE / ACTION_WINDOW / BLOCK_WINDOW / BLOCK_FORGIVENESS), captures player input via `_input()` before `_physics_process()` at 60 fps, classifies each result as MISS / HIT / PERFECT, and emits `window_closed(grade)`. It is placed above all CanvasLayers in the battle scene root so it receives input before any HUD Control; during a timing window, the HUD root's `set_process_input(false)` is called recursively to prevent input stealing (Godot 4.5+ recursive disable). The `timing_confirm` InputMap action is distinct from `ui_accept`. Test seams `inject_input()` and `advance_frame()` are exposed for GUT unit tests. `force_close_window()` is public API for pause/cutscene interruption.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0003: Input Routing and Dual-Focus | timing_confirm ≠ ui_accept; _input() at scene root; HUD disabled via set_process_input(false) recursive during window; dual-focus (Godot 4.6) | HIGH |
| ADR-0008: Timing Window FSM Architecture | 4-state FSM; _input() fires before _physics_process() (verified 4.6); inject_input()/advance_frame() test seam; force_close_window() | MEDIUM |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-ITD-001 | FSM: IDLE / ACTION_WINDOW / BLOCK_WINDOW / BLOCK_FORGIVENESS | ADR-0008 ✅ |
| TR-ITD-002 | Frame-precise input via `_input()` + `_physics_process()` at 60fps | ADR-0008 ✅ |
| TR-ITD-003 | `class_name InputTimingDetector` for typed references | ADR-0003 ⚠️ Partial |
| TR-ITD-004 | Node above CanvasLayer / dual-focus routing (Godot 4.6) | ADR-0003 ✅ |
| TR-ITD-005 | `force_close_window()` public API | ADR-0008 ✅ |
| TR-ITD-006 | `inject_input()` / `advance_frame()` test seam | ADR-0008 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/input-and-timing-detection.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | ITD FSM Core — 4-State Machine, Grade Classification, Test Seam | Logic | Ready | ADR-0008 |
| 002 | ITD Edge Cases — Formula Bounds, Forgiveness, Conflict, Force Close | Logic | Ready | ADR-0008 |
| 003 | ITD Input Routing — HUD Isolation, Dual-Focus, and Scene Wiring | Integration | Ready | ADR-0003 |

## Next Step

Run `/story-readiness production/epics/input-and-timing-detection/story-001-itd-fsm-core.md` then `/dev-story` to begin implementation.

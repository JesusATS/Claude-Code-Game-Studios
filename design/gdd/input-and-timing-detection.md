# Input & Timing Detection

> **Status**: Approved
> **Author**: Jesus Gallegos Ontiveros + agents
> **Last Updated**: 2026-05-02
> **Implements Pillar**: Rhythm Is Respect

## Overview

Input & Timing Detection is the frame-accurate input capture layer that underlies every timed action in *Lux Aeterna*. Its sole responsibility is to determine, for any given player input event, whether that input fell inside a designated timing window, and if so, at what quality (miss / hit / perfect hit). It owns no combat logic — it resolves only one question per action: *did the input land?* The answer, along with quality grade, is emitted as a signal to the Timing Combat System, which applies the result.

The system operates in two modes. In **action mode**, it opens a timing window of duration TIMING_WINDOW_FRAMES (derived from the acting combatant's FLUX stat via Formula 2a) and listens for a confirm input within that window. In **block mode**, it opens a window of duration BLOCK_WINDOW_FRAMES (derived from the enemy's TEMPO stat via Formula 2b) during an incoming enemy attack and listens for a guard input. In both modes, the system closes the window on input or on window expiry, emits the result, and returns to idle. Without this system, no other mechanic in the game can distinguish a timed hit from an untimed one — the entire timing-combat hypothesis collapses to a standard turn-based system with no rhythmic layer.

## Player Fantasy

This system is the game's promise to the player, made and kept on every turn: when the game says *Perfect*, you were perfect. When it says *Miss*, you missed. The word "Rhythm Is Respect" requires a foundation — this is that foundation.

Players will never think about frame-counting or input callbacks. What they will feel, over dozens of battles, is that the game is honest with them. That trust is what allows timing combat to feel like a skill rather than a gamble. A timing window that sometimes rewards sloppy inputs — or punishes clean ones — would corrode the entire combat fantasy. Input & Timing Detection prevents that corrosion. Its Player Fantasy is *negative space*: the absence of doubt about whether a result was deserved.

The anchor moment is the first Perfect Hit landed under pressure — an enemy with a tight TEMPO, a narrow BLOCK_WINDOW, the right frame chosen — and the clean impact that follows. That moment only carries weight if the player trusts the measurement. This system is the reason they can.

## Detailed Design

### Core Rules

1. The system is a Finite State Machine (FSM) with three states: `IDLE`, `ACTION_WINDOW`, and `BLOCK_WINDOW`.
2. The system owns no combat logic. Its single responsibility is timing measurement. It never reads or modifies stats, HP, damage, or ability effects.
3. All inputs entering this system are filtered to a single designated action: `timing_confirm`. No other player input is observed while a window is open. Simultaneous inputs on the same frame are deduped — only the first event that matches `timing_confirm` is processed.
4. Frames are counted by incrementing an integer counter in `_physics_process()` at 60fps. Each `_physics_process()` call = one frame. This is the authoritative frame counter for all window measurements. **Implementation constraint:** The counter is incremented at the **start** of `_physics_process()`, before any grade evaluation or window expiry check runs. **Engine constraint (Godot 4.6 verified):** `_input()` processes before `_physics_process()` within the same frame — all input for a given frame is captured before grade evaluation runs.
5. Input is captured via the `_input(event)` callback using `event.is_action_pressed(&"timing_confirm")`. This captures the frame the input arrives. `is_action_just_pressed()` is not used — `_input()` provides the event at the callback point; the frame counter at that moment determines the grade. **Implementation constraint:** The `_input()` callback must discard key-repeat echo events before any grade evaluation: `if event.is_echo(): return`. Without this guard, a held key generates OS-level repeat events inside the window that contaminate grade detection — directly violating the Player Fantasy guarantee.
6. A window opened in ACTION mode and a window opened in BLOCK mode cannot be simultaneously open. If a BLOCK trigger arrives while an ACTION window is open, the ACTION window closes immediately with result `MISS` and the BLOCK window opens. (Priority: BLOCK overrides ACTION. An enemy attack supersedes a pending action timing opportunity — the player loses that window.) **Exception:** When in BLOCK_FORGIVENESS state, `open_action_window` closes forgiveness as MISS and opens ACTION_WINDOW — BLOCK_FORGIVENESS is not an active block window and does not suppress incoming ACTION signals.
7. Windows are strict: inputs arriving before frame 1 (before the window opens) are ignored. No pre-buffering. **Accessibility mitigation:** `WINDOW_SCALE_FACTOR` (Character Stats GDD) widens all windows proportionally — this is the primary accessibility lever for players affected by input latency. No pre-buffer toggle is provided; window widening is the correct compensation mechanism.
8. On ACTION window expiry (no input received), the system emits `input_result(ACTION, MISS)` immediately and returns to `IDLE`.
9. On BLOCK window expiry (no input received), the system does NOT immediately emit MISS. Instead it enters a **forgiveness window** of `BLOCK_FORGIVENESS_FRAMES` additional physics ticks (default 1). If a `timing_confirm` input arrives during the forgiveness window, the result grades as **HIT** (not PERFECT — the perfect zone ended with the window). If no input arrives before the forgiveness window expires, the result is **MISS**. The forgiveness window only applies to BLOCK mode — ACTION windows close with MISS immediately on expiry.

### Quality Grade Classification

For a window of `W` frames total, with `PERFECT_HIT_RATIO` (default 0.25):

| Grade | Condition |
|-------|-----------|
| **MISS** | No input received before window expires (frame count reaches W) |
| **HIT** | Input received on frames 1 through `W − perfect_zone_size` |
| **PERFECT** | Input received on frames `(W − perfect_zone_size + 1)` through `W` |

Where `perfect_zone_size = max(1, floor(W × PERFECT_HIT_RATIO))`.

The same grade classification applies to both ACTION and BLOCK modes. The Timing Combat System interprets grade differently per mode (a PERFECT in BLOCK mode = full damage negation; a PERFECT in ACTION mode = perfect-hit multiplier applied), but Input & Timing Detection does not know about these interpretations — it only reports the grade.

### States and Transitions

| State | Entry Trigger | Exit Trigger | On Exit |
|-------|--------------|--------------|---------|
| `IDLE` | System start; window closed | `open_action_window(frames)` signal received | — |
| `IDLE` | — | `open_block_window(frames)` signal received | — |
| `ACTION_WINDOW` | `open_action_window(frames)` | Input received | Emit `input_result(ACTION, grade)`, `window_closed(grade)`, return to IDLE |
| `ACTION_WINDOW` | — | Frame count = W (expiry) | Emit `input_result(ACTION, MISS)`, `window_closed(MISS)`, return to IDLE |
| `ACTION_WINDOW` | — | `open_block_window(frames)` received mid-window | Emit `input_result(ACTION, MISS)`, open BLOCK_WINDOW |
| `BLOCK_WINDOW` | `open_block_window(frames)` | Input received | Emit `input_result(BLOCK, grade)`, `window_closed(grade)`, return to IDLE |
| `BLOCK_WINDOW` | — | Frame count = W (expiry) | Begin BLOCK_FORGIVENESS phase — do not emit yet |
| `BLOCK_FORGIVENESS` | BLOCK_WINDOW expiry | Input received within BLOCK_FORGIVENESS_FRAMES | Emit `input_result(BLOCK, HIT)`, `window_closed(HIT)`, return to IDLE |
| `BLOCK_FORGIVENESS` | — | BLOCK_FORGIVENESS_FRAMES ticks expire with no input | Emit `input_result(BLOCK, MISS)`, `window_closed(MISS)`, return to IDLE |
| `BLOCK_FORGIVENESS` | — | `open_action_window(frames)` received | Emit `input_result(BLOCK, MISS)`, `window_closed(MISS)`, open ACTION_WINDOW |
| `BLOCK_FORGIVENESS` | — | `open_block_window(frames)` received | Emit `input_result(BLOCK, MISS)`, `window_closed(MISS)`, open new BLOCK_WINDOW (second enemy attack supersedes forgiveness of first) |

No concurrent windows. `window_closed` is always emitted alongside `input_result` on every window close path.

### Signal Schema

**Inputs received (from Timing Combat System):**
- `open_action_window(window_frames: int)` — begins ACTION mode. `window_frames` = pre-computed TIMING_WINDOW_FRAMES value from Formula 2a. This system does not compute the window size itself.
- `open_block_window(window_frames: int)` — begins BLOCK mode. `window_frames` = pre-computed BLOCK_WINDOW_FRAMES value from Formula 2b.

**Outputs emitted (to Timing Combat System):**
- `input_result(mode: StringName, grade: StringName)` — emitted synchronously on window close. `mode` = `&"ACTION"` or `&"BLOCK"`. `grade` = `&"MISS"`, `&"HIT"`, or `&"PERFECT"`. No frame position data is included — only the grade.

**Outputs emitted (to Visual / Audio layers):**
- `window_frame_tick(current_frame: int, total_frames: int, mode: StringName)` — emitted each `_physics_process()` tick while a window is open. The HUD System reads `current_frame / total_frames` as a normalized ratio to drive animation at render rate (`_process()`); this signal is a data source, not an animation trigger.
- `window_closed(grade: StringName)` — emitted on window close for visual feedback and audio cue dispatch. Grade value is uppercase: `&"MISS"`, `&"HIT"`, or `&"PERFECT"`.

**Public API:**
- `force_close_window()` — closes the currently open window (ACTION_WINDOW, BLOCK_WINDOW, or BLOCK_FORGIVENESS) as MISS. Emits `input_result(mode, &"MISS")` and `window_closed(&"MISS")`, then returns to IDLE. No-op if called in IDLE state. Must be called by the Timing Combat System before any pause, cutscene trigger, or scene transition that occurs while a window is open.

### Interactions with Other Systems

| System | Direction | Data |
|--------|-----------|------|
| **Timing Combat System** | → receives | `open_action_window(frames)`, `open_block_window(frames)` |
| **Timing Combat System** | ← emits | `input_result(mode, grade)` |
| **Character Stats & Growth** | no direct link | Window durations are computed by the Timing Combat System from FLUX/TEMPO stats and passed in — this system never reads stats directly |
| **HUD System** | ← emits | `window_frame_tick(...)`, `window_closed(grade)` for indicator animation |
| **Audio System** | ← emits | `window_closed(grade)` triggers grade-specific audio cue (owned by Audio System) |

## Formulas

### Formula 1: PERFECT_ZONE_SIZE

The PERFECT_ZONE_SIZE formula is defined as:

`PERFECT_ZONE_SIZE = max(1, floor(W × PERFECT_HIT_RATIO))`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Window duration | W | int | 2–30 | Total frames in the current timing window (TIMING_WINDOW_FRAMES or BLOCK_WINDOW_FRAMES, passed in by Timing Combat System) |
| Perfect hit ratio | PERFECT_HIT_RATIO | float | 0.20–0.35 | Fraction of the window that counts as Perfect. Tunable. Default 0.25. |

**Output Range:** 1 to 10 frames under normal play. At default PERFECT_HIT_RATIO=0.25: W=8 → 2 frames; W=30 → 7 frames.

**Design constraint:** Due to `floor()`, windows with W ≤ 7 all produce zone size 1 at the default ratio of 0.25 (since `floor(W × 0.25) ≤ 1` for W ≤ 7). No currently registered character has FLUX below 8, so this plateau does not affect the shipped character set. If a future character or enemy is designed with FLUX 4–7, this formula should be revisited.

**Design note — Ne's PERFECT zone:** Ne's 2-frame PERFECT zone (33ms) is the **intended expression of her high-risk/high-reward character identity**, not an arithmetic accident. Most players will land HIT with Ne consistently; PERFECT with Ne is an aspirational mastery ceiling. This is a deliberate design choice that differentiates Ne from Setsuna (50ms) and Clawd (67ms). The global `WINDOW_SCALE_FACTOR` accessibility knob widens all windows proportionally — this is the primary mitigation for players who need a wider PERFECT window with Ne.

**Examples at PERFECT_HIT_RATIO = 0.25 (default):**

| Character | FLUX | W | PERFECT_ZONE_SIZE | Perfect frames | Hit frames |
|-----------|------|---|-------------------|----------------|------------|
| Ne | 8 | 8 | 2 | 7–8 (33ms) | 1–6 (100ms) |
| Setsuna | 12 | 12 | 3 | 10–12 (50ms) | 1–9 (150ms) |
| Clawd | 16 | 16 | 4 | 13–16 (67ms) | 1–12 (200ms) |
| Minimum window | — | 2 | 1 | frame 2 (16ms) | frame 1 (16ms) |
| Maximum window | — | 30 | 7 | 24–30 (117ms) | 1–23 (383ms) |

---

### Formula 2a (Reference): TIMING_WINDOW_FRAMES

*Defined in: Character Stats & Growth GDD. Consumed here as the ACTION window duration.*

`TIMING_WINDOW_FRAMES = max(2, min(TIMING_WINDOW_FRAMES_MAX, round(FLUX_c × WINDOW_SCALE_FACTOR)))`

Output range: 2–30 frames. Governs the duration of the `ACTION_WINDOW` state. Computed by the Timing Combat System from the acting combatant's FLUX stat and passed to this system via `open_action_window(frames)`. This system does not compute it.

---

### Formula 2b (Reference): BLOCK_WINDOW_FRAMES

*Defined in: Character Stats & Growth GDD. Consumed here as the BLOCK window duration.*

`BLOCK_WINDOW_FRAMES = max(2, min(30, round((BLOCK_WINDOW_BASE − TEMPO_enemy) × WINDOW_SCALE_FACTOR)))`

Output range: 2–30 frames. Governs the duration of the `BLOCK_WINDOW` state. Computed by the Timing Combat System from the attacking enemy's TEMPO stat and passed to this system via `open_block_window(frames)`. This system does not compute it.

## Edge Cases

### Input Events

- **If the player taps vs. holds `timing_confirm`:** The system captures input on key-down via `event.is_action_pressed()`. Hold duration is irrelevant — the grade is determined by arrival frame only. Tap and hold are identical outcomes.
- **If the player never releases `timing_confirm` between consecutive windows (holds across the gap):** No new key-down event fires during the second window. `_input()` requires a fresh press. Result: MISS on the second window. This is correct behavior and creates a natural rhythm incentive — players must release and re-press between windows.
- **If keyboard and gamepad `timing_confirm` both fire on the same frame:** The system processes the first event and sets an `_input_consumed` flag for the duration of the window. Subsequent `timing_confirm` events within the same window are discarded. Grade is determined by the first event's arrival frame.
- **If the button is already held when the window opens (held from before frame 1):** No new `_input()` event fires. Result: MISS. Pre-held inputs are never buffered (per Core Rule 7).

### Frame Rate & Real-Time Timing

- **If the game runs below 60fps during an open window (frame rate drop):** The frame counter increments once per `_physics_process()` call, not by elapsed real time. A W=8 window at 30fps lasts 267ms of real time instead of 133ms. This is correct behavior — window duration is defined in physics ticks, not milliseconds. No real-time fallback is applied. Delta-time accumulation would introduce fractional-frame decisions inconsistent with the discrete-frame model.
- **If a single large delta spike occurs (e.g., load stall of 500ms):** `_physics_process()` is called once for that stall tick; the frame counter increments by 1. **Known limitation: timing windows are not stall-compensated. A system stall exceeding `W × 16.6ms` will expire the open window as MISS.**
- **If `Engine.physics_ticks_per_second` is changed at runtime (e.g., slow-motion effect):** Physics ticks slow, stretching the window's real-time duration. **Constraint for the Timing Combat System: do not emit `open_action_window` or `open_block_window` while `Engine.physics_ticks_per_second ≠ 60`. Any slow-motion system must gate window signals accordingly.**

### Signal Collisions

- **If `open_action_window` and `open_block_window` arrive on the same physics frame while in IDLE:** BLOCK wins unconditionally, regardless of arrival order. The ACTION signal is discarded without opening an ACTION_WINDOW and without emitting MISS (no window was meaningfully open). **Implementation constraint:** GDScript signals are synchronous and have no pending queue — "check for a pending BLOCK" is not a valid GDScript pattern. The correct implementation: both `open_action_window` and `open_block_window` handlers set a pending-open flag (not immediately transitioning state). In `_physics_process()`, before incrementing the frame counter, the FSM checks pending flags and applies the BLOCK-overrides-ACTION priority rule. All state transitions occur inside `_physics_process()`, not inside signal handlers.
- **If `open_action_window` arrives while already in ACTION_WINDOW:** Ignored. Current window continues uninterrupted.
- **If `open_block_window` arrives while already in BLOCK_WINDOW:** Ignored. Current window continues uninterrupted.
- **If a re-entrant signal opens a new window inside the `input_result` handler:** The FSM must set state to `IDLE` and reset all per-window state *before* emitting `input_result`. This prevents a handler that responds to `input_result` by immediately emitting `open_action_window` from finding the FSM in a non-IDLE state. **Implementation constraint: `IDLE` state must be set before signal emission on every close path.**

### Formula Bounds

- **If `PERFECT_HIT_RATIO` is set at or above 0.50 (outside safe range):** The Perfect zone equals or exceeds the Hit zone in frame count, inverting the difficulty curve. Perfect becomes as easy or easier to achieve than Hit. **Runtime assertion: `assert(PERFECT_HIT_RATIO < 0.50)` at window open.** Practical safe range is 0.20–0.35.
- **If `PERFECT_ZONE_SIZE ≥ W`:** The Hit grade becomes unreachable — all inputs grade as PERFECT, MISS is still possible. This is a degenerate configuration only reachable outside the documented safe range.
- **If any future character or enemy has FLUX 4–7 (W = 4–7 at default scale):** `floor(W × 0.25)` evaluates to 1 for all W in this range — Perfect zone is identical across all four window sizes, eliminating FLUX differentiation. **Design constraint: characters and enemies should be designed with FLUX ≥ 8. If FLUX below 8 is required, revisit PERFECT_HIT_RATIO for that context.**

### Block Forgiveness Window

- **If the player inputs during the BLOCK forgiveness window (frames W+1 through W+BLOCK_FORGIVENESS_FRAMES):** The result is HIT. PERFECT is not possible in the forgiveness window — the perfect zone ended at frame W. The `input_result(BLOCK, HIT)` signal is emitted normally. From the player's perspective this is indistinguishable from a late HIT within the window.
- **If BLOCK_FORGIVENESS_FRAMES = 0:** BLOCK windows behave identically to ACTION windows — expiry immediately emits MISS with no grace period.
- **If a BLOCK_WINDOW is interrupted by `open_action_window` during the forgiveness phase:** The forgiveness window closes immediately with MISS (per the BLOCK-overrides-ACTION priority rule, which also applies in reverse — if ACTION arrives during BLOCK forgiveness, close BLOCK forgiveness as MISS and enter ACTION_WINDOW).

### Game State

- **If the game is paused while a window is open:** `_physics_process()` stops; the frame counter freezes. **Constraint for the Timing Combat System: call `force_close_window()` on this FSM before pausing the scene tree.** `force_close_window()` closes the window as MISS, emits `input_result` and `window_closed`, and returns to IDLE. It is a no-op if called in IDLE.
- **If a cutscene or scene transition begins mid-window:** Same as pause — the initiating system must call `force_close_window()` before seizing control.
- **If the node is freed while a window is open (`NOTIFICATION_EXIT_TREE`):** Close the window silently — no signals emitted (connected listeners may already be freed). Reset state to IDLE internally.

### Visual (HUD Constraint)

- **If W = 2 and the HUD animates based on tick events:** Only 1–2 tick signals arrive before close — insufficient for a smooth sweep animation. **Constraint for the HUD System: the timing indicator must use `current_frame / total_frames` as a normalized ratio to drive interpolation at render rate (`_process()`), not frame-by-frame animation triggered by tick events.**
- **If the player inputs on frame 1 (earliest possible input):** `_input()` processes before `_physics_process()`. The window closes before the first tick fires. The HUD receives 0 `window_frame_tick` signals before `window_closed`. **HUD must handle `window_closed` arriving after 0 ticks.**
- **If the player inputs on frame W (PERFECT on a narrow window):** The window closes before the W-th tick fires. The HUD receives W−1 tick signals before `window_closed`. **HUD must handle `window_closed` arriving after any number of ticks from 0 to W−1, not exactly W.**

## Dependencies

### Upstream Dependencies (what this system depends on)

None. Input & Timing Detection is a Foundation layer system. It has no upstream game system dependencies. Its only external dependencies are engine-level:
- Godot's `InputMap` must have a `timing_confirm` action configured (keyboard, gamepad face button minimum — mapped by the setup process, not by this system)
- `Engine.physics_ticks_per_second` must equal 60 while any window is open

### Downstream Dependents (systems that depend on this system)

| System | Dependency Type | Interface |
|--------|----------------|-----------|
| **Timing Combat System** | Hard — cannot function without this system | Sends: `open_action_window(frames)`, `open_block_window(frames)`. Receives: `input_result(mode, grade)`. Must call `force_close_window()` before pausing or yielding control. |
| **HUD System** | Hard — timing indicator cannot display without this system | Receives: `window_frame_tick(current_frame, total_frames, mode)` each physics tick while open. Receives: `window_closed(grade)` on close. Must drive the indicator via normalized ratio (`current_frame / total_frames`), not tick-count animation. |
| **Audio System** | Soft — combat resolves without audio, but grade feedback is silent | Receives: `window_closed(grade)` to trigger grade-appropriate audio cues (grade-specific SFX owned by Audio System GDD). |

### Cross-System Interface Obligations

Two constraints established in this GDD that downstream GDDs must acknowledge:

1. **Timing Combat System must call `force_close_window()`** before any pause, cutscene trigger, or scene transition that occurs while a window is open. It must also not emit window signals when `Engine.physics_ticks_per_second ≠ 60`. These obligations belong in the Timing Combat System GDD's Dependencies and Edge Cases sections.

2. **HUD System must use ratio-driven rendering** for the timing indicator (`current_frame / total_frames`), not discrete-tick animation. `window_closed` may arrive after any number of ticks from 1 to W — the HUD cannot assume exactly W ticks will arrive. This obligation belongs in the HUD System GDD.

### Implementation Constraints

- **`class_name InputTimingDetector`** must be declared on the FSM script. TCS, HUD System, and Audio System all hold references to this node — typed references (`var itd: InputTimingDetector`) require the class name to be declared for compile-time validation.
- **Node placement**: The ITD FSM node must be placed above the UI CanvasLayer in the scene tree, **or** all timing indicator Control nodes must have `mouse_filter = IGNORE` and never call `grab_focus()`. Godot 4.6's dual-focus system (keyboard focus + gamepad focus) will cause any focused Control node to consume `timing_confirm` events before the FSM's `_input()` callback. This is a hard architectural requirement, not an open question. (Supersedes OQ-2.)

### Intentional Non-Dependencies

- **Character Stats & Growth**: this system does not read stats. Window durations are pre-computed by the Timing Combat System from FLUX and TEMPO values and passed in as integers. If the stat vocabulary changes, this system is unaffected.
- **Party Composition Manager**: party membership is irrelevant to input detection.
- **Story State & Flag System**: timing behavior does not vary based on story state.

## Tuning Knobs

### Knobs Owned by This System

| Knob | Default | Safe Range | Too Low | Too High |
|------|---------|-----------|---------|---------|
| `PERFECT_HIT_RATIO` | 0.25 | 0.20–0.35 | At <0.20: Ne's window (W=8) produces a 1-frame (16ms) Perfect zone — frame-perfect, inappropriate for a turn-based RPG. FLUX differentiation collapses for FLUX 4–7. | At >0.35: Clawd's wide window approaches a 100ms+ Perfect zone. The grade loses meaning. Above 0.50: Perfect zone exceeds Hit zone — grade hierarchy inverts. |
| `BLOCK_FORGIVENESS_FRAMES` | 1 | 0–2 | At 0: BLOCK windows are as strict as ACTION windows. Players may perceive valid block attempts as misses due to PC input latency variance (1 frame = 16ms). | At 3+: The forgiveness window becomes perceptible as a grace period. Players may learn to rely on it, reducing the reactive skill expression of block timing. |

**Derived constant (not independently tunable):** `TOTAL_BLOCK_OBSERVABLE_DURATION = BLOCK_WINDOW_FRAMES + BLOCK_FORGIVENESS_FRAMES`. This is the total frame span during which a block attempt can succeed. At defaults: W=8, BLOCK_FORGIVENESS_FRAMES=1 → 9 frames total observable block window. Designers evaluating block feel should reference this aggregate, not BLOCK_WINDOW_FRAMES alone.

**Knob interaction:** `PERFECT_HIT_RATIO` interacts with `WINDOW_SCALE_FACTOR` (Character Stats GDD). If `WINDOW_SCALE_FACTOR` is raised for accessibility, Perfect zones grow proportionally alongside Hit zones — holistic difficulty reduction. Both knobs should be reviewed together during accessibility tuning passes.

### Referenced Knobs (Owned by Character Stats & Growth GDD)

These knobs are defined and tuned in the Character Stats GDD but directly affect the window durations this system operates on. Changes to them require re-validation of timing feel.

| Knob | Default | Effect on This System |
|------|---------|----------------------|
| `WINDOW_SCALE_FACTOR` | 1.0 (range 0.6–1.6) | Scales all TIMING_WINDOW_FRAMES and BLOCK_WINDOW_FRAMES values. Primary global accessibility lever. Setting to 1.6 gives all characters ~60% wider windows. |
| `TIMING_WINDOW_FRAMES_MAX` | 30 frames (range 20–45) | Ceiling on ACTION window duration. Prevents FLUX from creating windows so wide they eliminate rhythmic challenge. |
| `BLOCK_WINDOW_BASE` | 32 frames | Numerator offset in BLOCK_WINDOW_FRAMES formula. Controls how tight the block window is for high-TEMPO enemies at all TEMPO levels. |

## Visual/Audio Requirements

*Full visual and audio design is deferred to the HUD System GDD and Audio System GDD. The following constraints are design requirements that those GDDs must satisfy.*

**PERFECT zone perceptibility (mandatory):**
Because PERFECT is placed at the *end* of the timing window (not the beginning), the shrinking-bar metaphor alone does not communicate when PERFECT becomes reachable — a depleting bar signals "act before it closes," the opposite of "wait until the end." The player cannot build trust in the measurement system unless they can perceive when the PERFECT zone begins.

1. **The PERFECT zone must be visually and/or audibly distinguishable from the HIT zone while the window is open.** The player must be able to identify, before inputting, that they are in the PERFECT zone.
2. **The HUD timing indicator must mark the PERFECT zone boundary.** The specific implementation (color change in the final zone, a pulsing marker, a distinct visual layer at the end of the bar) is owned by the HUD GDD — but the requirement that such a mark exists belongs here.
3. **Grade feedback must be immediate and unambiguous on window close.** The visual/audio response to MISS, HIT, and PERFECT must be distinct enough that a player always knows which grade they received without reading a text label.
4. **The audio cue timing specification** for grade feedback is owned by the Audio System GDD. The `window_closed(grade)` signal is the trigger point.

**Onboarding constraint:** The game must teach the player that PERFECT is a late-window grade during onboarding (tutorial combat encounter). Players cannot intuit this from a depleting bar alone.

## UI Requirements

*Owned by HUD System GDD. This system's UI obligations are specified in the HUD System GDD's timing indicator rules. See also: Cross-System Interface Obligations in the Dependencies section.*

## Acceptance Criteria

All criteria are LOGIC — BLOCKING (automated unit test required) unless noted. Format: GIVEN / WHEN / THEN. **Test-seam requirement:** The FSM must expose `inject_input(action: StringName)` and `advance_frame()` methods (or equivalent) to allow deterministic per-frame testing without relying on real-time input timing. GUT's standard `simulate_physics_frames()` does not provide per-frame `_input()` injection. Grade-classification ACs (AC-3 through AC-14) cannot be automated without this seam. Grade values in all ACs use the canonical uppercase vocabulary: `&"MISS"`, `&"HIT"`, `&"PERFECT"`, `&"ACTION"`, `&"BLOCK"`.

### FSM State Entry

- **AC-1:** GIVEN the FSM is in IDLE, WHEN `open_action_window(8)` is received, THEN the FSM enters ACTION_WINDOW state and begins emitting `window_frame_tick` signals with mode `&"ACTION"`.
- **AC-2:** GIVEN the FSM is in IDLE, WHEN `open_block_window(8)` is received, THEN the FSM enters BLOCK_WINDOW state and begins emitting `window_frame_tick` signals with mode `&"BLOCK"`.

### Grade Classification — ACTION mode, W=8, PERFECT_HIT_RATIO=0.25 (PERFECT_ZONE_SIZE=2)

- **AC-3:** GIVEN an ACTION_WINDOW opens with W=8 and PERFECT_HIT_RATIO=0.25, WHEN `timing_confirm` arrives on frame 1 (first HIT frame), THEN `input_result(&"ACTION", &"HIT")` is emitted.
- **AC-4:** GIVEN an ACTION_WINDOW opens with W=8 and PERFECT_HIT_RATIO=0.25, WHEN `timing_confirm` arrives on frame 6 (last HIT frame), THEN `input_result(&"ACTION", &"HIT")` is emitted.
- **AC-5:** GIVEN an ACTION_WINDOW opens with W=8 and PERFECT_HIT_RATIO=0.25, WHEN `timing_confirm` arrives on frame 7 (first PERFECT frame), THEN `input_result(&"ACTION", &"PERFECT")` is emitted.
- **AC-6:** GIVEN an ACTION_WINDOW opens with W=8 and PERFECT_HIT_RATIO=0.25, WHEN `timing_confirm` arrives on frame 8 (last PERFECT frame), THEN `input_result(&"ACTION", &"PERFECT")` is emitted.
- **AC-7:** GIVEN an ACTION_WINDOW opens with W=8, WHEN W physics ticks advance with no `timing_confirm` event, THEN `input_result(&"ACTION", &"MISS")` is emitted on tick W (not deferred to tick W+1).

### Grade Classification — BLOCK mode, W=8, PERFECT_HIT_RATIO=0.25 (PERFECT_ZONE_SIZE=2)

- **AC-3b:** GIVEN a BLOCK_WINDOW opens with W=8 and PERFECT_HIT_RATIO=0.25, WHEN `timing_confirm` arrives on frame 1 (first HIT frame), THEN `input_result(&"BLOCK", &"HIT")` is emitted.
- **AC-4b:** GIVEN a BLOCK_WINDOW opens with W=8 and PERFECT_HIT_RATIO=0.25, WHEN `timing_confirm` arrives on frame 6 (last HIT frame), THEN `input_result(&"BLOCK", &"HIT")` is emitted.
- **AC-5b:** GIVEN a BLOCK_WINDOW opens with W=8 and PERFECT_HIT_RATIO=0.25, WHEN `timing_confirm` arrives on frame 7 (first PERFECT frame), THEN `input_result(&"BLOCK", &"PERFECT")` is emitted.
- **AC-6b:** GIVEN a BLOCK_WINDOW opens with W=8 and PERFECT_HIT_RATIO=0.25, WHEN `timing_confirm` arrives on frame 8 (last PERFECT frame), THEN `input_result(&"BLOCK", &"PERFECT")` is emitted.

### Grade Classification — Minimum window (W=2, tests `max(1,...)` formula floor)

- **AC-8:** GIVEN an ACTION_WINDOW opens with W=2 and PERFECT_HIT_RATIO=0.25 (PERFECT_ZONE_SIZE=max(1,floor(0.5))=1), WHEN `timing_confirm` arrives on frame 1, THEN `input_result(&"ACTION", &"HIT")` is emitted (frame 1 is the only HIT frame).
- **AC-9:** GIVEN an ACTION_WINDOW opens with W=2 and PERFECT_HIT_RATIO=0.25, WHEN `timing_confirm` arrives on frame 2, THEN `input_result(&"ACTION", &"PERFECT")` is emitted (frame 2 is the only PERFECT frame).

### PERFECT_HIT_RATIO Boundary Values

- **AC-10:** GIVEN PERFECT_HIT_RATIO=0.20 and W=8 (PERFECT_ZONE_SIZE=1, only frame 8 is PERFECT), WHEN `timing_confirm` arrives on frame 7, THEN grade is `&"HIT"`.
- **AC-11:** GIVEN PERFECT_HIT_RATIO=0.35 and W=8 (PERFECT_ZONE_SIZE=2, frames 7–8 are PERFECT), WHEN `timing_confirm` arrives on frame 6, THEN grade is `&"HIT"`.

### BLOCK Mode — Forgiveness Window

- **AC-12:** GIVEN a BLOCK_WINDOW opens with W=8 and BLOCK_FORGIVENESS_FRAMES=1, WHEN W physics ticks advance with no input, then `timing_confirm` arrives on tick W+1, THEN `input_result(&"BLOCK", &"HIT")` is emitted (not `&"PERFECT"`).
- **AC-13:** GIVEN a BLOCK_WINDOW opens with W=8 and BLOCK_FORGIVENESS_FRAMES=1, WHEN W+1 physics ticks advance with no `timing_confirm` event, THEN `input_result(&"BLOCK", &"MISS")` is emitted at the start of tick W+1 — after incrementing the forgiveness counter to 1 and evaluating expiry (not deferred to tick W+2).
- **AC-14:** GIVEN a BLOCK_WINDOW opens with W=8 and BLOCK_FORGIVENESS_FRAMES=0, WHEN W physics ticks advance with no input, THEN `input_result(&"BLOCK", &"MISS")` is emitted on tick W (no forgiveness delay).

### Mode Conflict — BLOCK Overrides ACTION

- **AC-15:** GIVEN an ACTION_WINDOW is open on frame 3, WHEN `open_block_window(6)` is received, THEN `input_result(&"ACTION", &"MISS")` is emitted synchronously, followed by the FSM entering BLOCK_WINDOW state (confirmed by subsequent `window_frame_tick` signals carrying mode `&"BLOCK"`).
- **AC-16:** GIVEN the FSM is in IDLE, WHEN `open_action_window(8)` and `open_block_window(6)` are both received in the same physics tick, THEN the FSM enters BLOCK_WINDOW (not ACTION_WINDOW), no `input_result` is emitted for the discarded ACTION signal, and subsequent `window_frame_tick` signals carry mode `&"BLOCK"`.
- **AC-17:** GIVEN a BLOCK_WINDOW has expired and the FSM is in the forgiveness phase, WHEN `open_action_window(8)` is received, THEN `input_result(&"BLOCK", &"MISS")` is emitted and the FSM enters ACTION_WINDOW.

### Input Filtering and Deduplication

- **AC-18:** GIVEN the FSM is in IDLE, WHEN `timing_confirm` is pressed, THEN no signal is emitted.
- **AC-19:** GIVEN an ACTION_WINDOW is open on frame 3, WHEN any input action other than `timing_confirm` is pressed, THEN no `input_result` is emitted and the window continues counting normally.
- **AC-20:** GIVEN an ACTION_WINDOW is open, WHEN keyboard `timing_confirm` and gamepad `timing_confirm` both arrive on frame 3, THEN exactly one `input_result` signal is emitted and no duplicate fires. *(Manual test — GUT cannot inject simultaneous events from two input devices on the same physics frame. Verify via manual playtest with keyboard+gamepad connected simultaneously.)*
- **AC-21:** GIVEN `timing_confirm` is held down before `open_action_window` is received, WHEN the window opens and W physics ticks advance with no new key-down event (and no echo events — per Core Rule 5 echo guard), THEN `input_result(&"ACTION", &"MISS")` is emitted. *(Requires test-seam for held-key state. Programmer must confirm injection mechanism — see OQ-1.)*

### Duplicate Window Signals

- **AC-22:** GIVEN an ACTION_WINDOW is open counting on frame 3, WHEN `open_action_window(8)` is received again, THEN the current window continues uninterrupted (frame counter does not reset; no duplicate signals fire).
- **AC-23:** GIVEN a BLOCK_WINDOW is open counting on frame 3, WHEN `open_block_window(8)` is received again, THEN the current window continues uninterrupted.

### `force_close_window()` API

- **AC-24:** GIVEN an ACTION_WINDOW is open on frame 3, WHEN `force_close_window()` is called, THEN `input_result(&"ACTION", &"MISS")` and `window_closed(&"MISS")` are both emitted and the FSM returns to IDLE.
- **AC-24b:** GIVEN a BLOCK_WINDOW is open on frame 3, WHEN `force_close_window()` is called, THEN `input_result(&"BLOCK", &"MISS")` and `window_closed(&"MISS")` are both emitted and the FSM returns to IDLE.
- **AC-24c:** GIVEN the FSM is in BLOCK_FORGIVENESS state, WHEN `force_close_window()` is called, THEN `input_result(&"BLOCK", &"MISS")` and `window_closed(&"MISS")` are both emitted and the FSM returns to IDLE.
- **AC-25:** GIVEN the FSM is in IDLE, WHEN `force_close_window()` is called, THEN no signals are emitted and the FSM remains in IDLE (no-op).

### Re-entrancy Safety

- **AC-25b:** GIVEN a window is closing (any state → IDLE transition), WHEN a listener on `input_result` immediately emits `open_action_window(8)` back to the FSM, THEN the FSM is confirmed to be in IDLE state before the `input_result` signal fires — the re-entrant `open_action_window` opens a new ACTION_WINDOW cleanly without finding the FSM in a non-IDLE state.

### Signal Correctness

- **AC-26:** GIVEN an ACTION_WINDOW opens with W=8, WHEN each physics tick fires while the window is open, THEN each `window_frame_tick` signal carries `current_frame` incrementing from 1, `total_frames = 8`, and `mode = &"ACTION"`.
- **AC-27:** GIVEN an ACTION_WINDOW opens with W=8, WHEN `timing_confirm` arrives on frame 8 (PERFECT), THEN both `input_result(&"ACTION", &"PERFECT")` and `window_closed(&"PERFECT")` are emitted with matching grades — and at most 7 `window_frame_tick` signals were emitted before close (`_input()` runs before `_physics_process()`, so the final tick is pre-empted by the input).

## Open Questions

| ID | Question | Owner | Target |
|----|----------|-------|--------|
| OQ-1 | **Held-key test-seam**: AC-21 requires simulating a button held before the window opens without re-firing `_input()`. GUT's standard `simulate_action` fires a new input event. The implementing programmer must either (a) expose a test-injectable input source on the FSM, or (b) document that AC-21 is verified via manual playtest rather than automated test. Resolution needed before the test suite is written. | Gameplay Programmer | Architecture phase |
| OQ-2 | ~~**Dual-focus architecture**~~ — **RESOLVED.** Promoted to Implementation Constraint in the Dependencies section. FSM node must be placed above the UI CanvasLayer, OR all indicator Controls must have `mouse_filter = IGNORE` and never call `grab_focus()`. ADR required before implementation. | Lead Programmer | Architecture phase |
| OQ-3 | **BLOCK timing feel in playtest**: BLOCK_FORGIVENESS_FRAMES=1 is a design default, not a validated feel target. The actual right value (0, 1, or 2) should be confirmed in the first `/prototype timing-combat` playtest session. BLOCK_FORGIVENESS_FRAMES is a tuning knob and can be adjusted post-prototype without changes to the GDD. | Playtester / Game Designer | After timing-combat prototype |

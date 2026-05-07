## Prototype Report: Timing Combat

### Hypothesis
A moving cursor sweeping across a zoned timing bar creates an intrinsically satisfying
"musical" feel when the player must press a button at the right moment. The mechanic
should produce a reward response (PERFECT grade) that feels good independent of any
narrative or damage context — pure timing satisfaction.

### Approach
Built a standalone Godot 4.6 scene (~270 lines of GDScript, no src/ imports).
8-round session: 2-second enemy charge → cursor sweeps 30-frame window → SPACE press
grades PERFECT (0–35%) / HIT (35–75%) / MISS (75–100%). Summary screen with playtest
questions after round 8. Placeholder colored rectangles only — no art, audio, or damage.

Shortcuts taken: hardcoded all values, programmatic UI (no .tscn node tree), no
error handling, no save state.

### Result

Mechanic is intrinsically satisfying. The charge → window → grade cycle felt rhythmic
rather than purely reflexive. Hitting PERFECT produced a clear reward response. No
confusion, no bugs, immediate replay impulse (pressed R unprompted). Default tuning
held up without adjustment.

### Metrics

- **Feel assessment**: Satisfying — pressing SPACE at the right moment produced a clear reward
- **Musical quality**: Yes — cycle felt rhythmic, not just a reflex test
- **PERFECT response**: Rewarding — grade display reinforced the hit
- **Window timing**: About right at WINDOW_FRAMES=30 (~0.5s)
- **Replay impulse**: Yes — pressed R to play again without prompting
- **One-word description**: Electric
- **Iteration count**: 0 — default constants required no tuning

### Recommendation: PROCEED

The core timing mechanic is intrinsically satisfying and validates the "Rhythm Is
Respect" design pillar. The mechanic produced an "electric" feel and immediate replay
impulse with zero art, audio, or narrative context — confirming that the moment-to-
moment input feel is strong enough to anchor the game's combat identity. Proceed to
production implementation.

### If Proceeding
Production implementation requirements derived from GDD and ADR work already complete:

- Architecture: Signal-driven FSM via `CombatEventBus` (ADR-0004); `timing_window_opened`
  signal must emit 3 params (`window_type`, `window_frames`, `actor_id`) — resolve
  parameter mismatch backlog item before HUD story
- Performance: Window evaluation must complete within 1 frame; no allocation in
  `_process()` hot path
- Audio: Sound feedback on PERFECT/HIT/MISS is required for "musical" pillar — audio
  prototype or at minimum placeholder beeps should be added in first production story
- Art: Timing bar visual design must follow art bible Section 4 (UI palette) and Section 7
  (HUD layout philosophy)
- Test evidence: Logic stories require unit tests in `tests/unit/combat/`; Integration
  stories require bus relay test in `tests/integration/combat/`

### If Pivoting
[Fill in if the core mechanic tests poorly — describe the alternative direction the
results suggest. For example: shrinking bar instead of moving cursor, rhythm-game
button sequence instead of single press, etc.]

### If Killing
[Fill in if the mechanic fails to produce satisfaction in any configuration.]

### Lessons Learned

[Fill in after testing. What did you discover about the mechanic that affects other
systems? E.g.: "The 2-second charge phase creates too much dead time — consider
reducing to 1.2s or adding a visual escalation during charge."]

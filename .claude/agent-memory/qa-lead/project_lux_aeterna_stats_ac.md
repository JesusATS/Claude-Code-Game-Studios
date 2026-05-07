---
name: Lux Aeterna — Character Stats & Growth AC status
description: AC critique completed for AC-1 through AC-16; 3 ACs failed review, 3 partial; 5 missing ACs identified; not yet written to GDD file
type: project
---

## Character Stats & Growth — AC Status

- 16 acceptance criteria drafted (AC-1 to AC-16) covering all formulas, core rules, and key edge cases
- Criteria are in GIVEN-WHEN-THEN format
- NOT YET written to `design/gdd/character-stats-and-growth.md` — awaiting user approval
- The GDD section "Acceptance Criteria" currently reads "[To be designed]"

## AC Review Results (2026-04-30) — 24-AC adversarial review

### Confirmed Contradiction (AC-11 vs. AC-22)
- AC-11 claims Ne's effective FLUX = 9 after +1 inheritance; AC-22 claims effective FLUX = 10 after minimum-guarantee override to +2
- AC-22 is correct (FLUX_INHERITANCE_MIN = 2); AC-11's effective FLUX claim is wrong
- Fix: split AC-11 into formula-output AC (INHERITANCE_MAX = 1, no effective stat claim) and retain AC-22 as the minimum-guarantee test

### New BLOCKING findings (2026-04-30)
- AC-4: "turn order strip" UI assertion mixed into logic AC — must split into AC-4a (logic) and AC-4b (UI)
- AC-24: TEMPO stat undefined; formula absent; BLOCK_WINDOW formula not stated — not independently testable
- AC-10: tests midpoints only, not boundary values — needs all 8 boundary/near-boundary values; split logic/UI
- AC-12: still not split (visual + data model mixed) — was flagged 2026-04-22, still present
- Inheritance stacking across multiple Named Inheritance Objects: no AC
- TEMPO stat vocabulary: no range, floor, ceiling, or holder defined in any AC
- Defeat scenario inheritance: designer must rule before AC can be written (blocker on designer, not implementer)

### New RECOMMENDED findings (2026-04-30)
- PHM in AC-2 has no formula or inheritance AC — confirm deferral to Timing Combat GDD
- Inheritance object removal rule missing — add AC for permanence or define removal
- UI display of minimum-guarantee-elevated inheritance not tested (gap between AC-12b and AC-22)
- AC-17 precondition underspecified — add fixture isolation and explicit rule statement
- Multiple simultaneous incapacitations turn-slot order not tested
- HP_current clamping when HP_max reduced below HP_current not tested

### Gate status: CANNOT PASS sprint gate
- 8 BLOCKING findings; 6 RECOMMENDED
- Designer clarification required on defeat scenario before AC can be written

## AC Review Results (2026-04-22)

### Failed ACs (must be rewritten before implementation)

**AC-10** — FAIL
- Tests midpoints only (74, 49, 24, 0), not boundary values (75, 50, 25)
- "Immediately" is untestable in a unit test (rendering/timing concern)
- Must be split into AC-10a (logic, BLOCKING) and AC-10b (HUD sync, UI, ADVISORY)
- GDD designer must confirm whether HP thresholds are inclusive or exclusive before implementation

**AC-12** — FAIL
- Mixes logic (data model) and visual (accent color at 60% opacity) in one criterion
- Cannot be verified by a single test type
- Must be split into AC-12a (data model, LOGIC, BLOCKING) and AC-12b (screen rendering, UI, ADVISORY)
- Color/opacity verification requires screenshot + Art Director sign-off — not automatable

### Partial ACs (need additions before sprint review)

**AC-11** — Partial
- Tests floor case but not rounding behavior of round() specifically
- GDScript round() uses half-up; if implemented as int(), behavior differs at 0.5
- Need AC-11b: test round(0.7)→1 (no clamp) and round(0.3)→0→clamp→1

**AC-14** — Partial
- Tests only one inheritance object; inheritances[] is an array
- Need AC-14b: multiple inheritance objects survive save/load roundtrip
- Mechanism ("game is saved and reloaded") needs precision — disk write vs. memory buffer

**AC-15** — Partial
- "When the encounter ends" is undefined in engine terms (all enemies dead? victory screen? overworld load?)
- HP interaction with inheritance application unspecified
- Requires designer clarification before test can be written

**AC-16** — Partial
- Tests floor clamping in the full calculation stack
- Does not test the 99 ceiling within the base+inheritance subtotal in a full-stack scenario

### Missing ACs (behaviors with no AC)

- **AC-17**: SPD tiebreaker — player characters act before enemies at equal SPD (LOGIC, BLOCKING)
- **AC-18**: Inheritance accumulation ceiling — base + inheritances clamped to 99 (LOGIC, BLOCKING)
- **AC-19**: Status effect buffs not capped at 99 — confirms no post-status cap exists (LOGIC, BLOCKING; also surfaces GDD ambiguity)
- **AC-20**: Mid-round SPD change deferred to next round (LOGIC, BLOCKING)
- **AC-21**: Double-action boundary — test at threshold (SPD ratio crossing floor() boundary) (LOGIC, BLOCKING)

### Coverage gaps previously flagged (intentional deferrals — unchanged)

- Perfect-hit multiplier application → Timing Combat GDD AC
- SPD tiebreaker → now flagged as missing (should be AC-17, not deferred)
- Status effect stacking permission → Status Effects GDD integration tests
- Visual/UI story criteria → advisory gate; screenshot evidence required

### Story type classification for this GDD

- Primary type: Logic (BLOCKING — automated unit tests required in tests/unit/)
- Cross-system: Integration (BLOCKING — save/load test required; AC-14 covers this)
- UI/Visual elements: Advisory gate (screenshot evidence in production/qa/evidence/)

### Gate label requirement

All ACs need explicit gate-level tags before the AC list is finalized:
- [LOGIC — BLOCKING]: AC-1, AC-2, AC-3, AC-4, AC-5, AC-6, AC-7, AC-8, AC-9, AC-11, AC-12a, AC-13, AC-16, AC-17, AC-18, AC-19, AC-20, AC-21
- [INTEGRATION — BLOCKING]: AC-14, AC-15
- [UI — ADVISORY]: AC-10b, AC-12b

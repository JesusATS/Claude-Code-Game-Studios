---
name: Lux Aeterna — Ability System AC status
description: Adversarial review completed 2026-04-30; 10 BLOCKING issues; 16 weak ACs needing rewrite; 12 coverage gaps; CANNOT PASS gate
type: project
---

## Ability System — AC Status

- 25 acceptance criteria reviewed (AC-1 to AC-25) — adversarial pass
- GDD Revision Pass 1 applied (2026-04-30); CC scope, grade vocabulary, "GOOD" → "HIT", and "system cancellation" issues RESOLVED in GDD body
- Gate status: CANNOT PASS — 10 blocking issues; 16 ACs need rewrite; 12 coverage gaps

## Resolved Since Prior Review (Revision Pass 1)

1. CC scope — GDD now clearly says party-wide CC owned by TCS. All CC Economy ACs updated accordingly.
2. Grade vocabulary — GDD body and all ACs now use "HIT" (not "GOOD").
3. "System cancellation" — AC-6 now scoped to signal ordering only (cc_spent before timing_window_opened); clean and testable.
4. CC gain on PERFECT — GDD body now says +2 on PERFECT attack, +1 on HIT attack. Internally consistent.

## Remaining Cross-GDD Conflicts (designer ruling required — UNRESOLVED)

1. **MAX_CHARGE conflict** — AS GDD says 6; TCS GDD and HUD GDD reportedly say 4. AC-4 hardcodes "6." One canonical source required. BLOCKING.
2. **CC gain on PERFECT — cross-system value** — AS GDD says +2 PERFECT attack; if TCS GDD says a different value, AC-2 integration test will fail against TCS. Must reconcile before test authoring. BLOCKING.
3. **timing_optional CC gain** — GDD body says "no CC is gained" for timing_optional abilities but AC-22 only covers PERFECT suppression; HIT-grade normal CC gain (+1) is ambiguous. Designer must rule: 0 CC or +1 CC? BLOCKING.
4. **OQ-1 unresolved** — enhanced effect schema undefined; AC-9 untestable. BLOCKING.
5. **OQ-3 unresolved** — Ability B armed + unaffordable simultaneously — display state not defined. BLOCKING.
6. **STUNNED turn gap** — whether a STUNNED turn decrements turns_remaining is not ruled. Blocks AC-11 completeness.

## BLOCKING Issues (10 total)

- CONFLICT-1: MAX_CHARGE cross-GDD conflict (6 vs 4) — blocks AC-4 boundary test
- CONFLICT-2: CC gain on PERFECT cross-system value — blocks AC-2 integration test
- CONFLICT-3: OQ-3 Ability B armed + unaffordable — blocks AC-19 and AC-5b
- CONFLICT-4: timing_optional CC ambiguity — blocks AC-21 and AC-22
- CONFLICT-5: OQ-1 enhanced effect schema — blocks AC-9
- GAP-1: No AC for passive ability CC gain exclusion
- GAP-2: No AC for CC non-refund on character incapacitation
- GAP-9: No AC for get_ability() return schema completeness / resolve_ability() API contract
- GAP-10: No AC for Formula 1 rounding at 0.5 boundary (fractional WINDOW_SCALE_FACTOR)
- AC-9: Itself untestable until OQ-1 resolved (counted above as CONFLICT-5)

## ACs Needing Rewrite (16)

AC-2 (reclassify as Integration), AC-4 (reference constant not literal), AC-5 (split Logic/UI),
AC-7 (specify field values), AC-8 (add AC-8b for armed-state preservation), AC-11 (STUNNED gap flagged),
AC-12 (enumerate all fields in overwrite), AC-14 (split 14a/14b/14c with GDD fixtures),
AC-15 (split 15a/b/c; OQ-5 block), AC-16 (enumerate tested actions; add 16b save/load),
AC-17 (split 17a Logic / 17b UI), AC-19 (reclassify UI/Advisory), AC-20 (reclassify UI/Advisory; enumerate d-pad actions),
AC-21 (split 21a/b/c), AC-22 (pending timing_optional CC ruling), AC-23 (split 23a/b), AC-24 (split 24a/b)

## Coverage Gaps (12)

- GAP-1: Passive ability CC exclusion (BLOCKING)
- GAP-2: CC non-refund on incapacitation (BLOCKING)
- GAP-3: combo_sfx_id empty for non-route abilities (RECOMMENDED)
- GAP-4: Scan/Analyze on incapacitated enemy resolves normally (RECOMMENDED)
- GAP-5: Multiple inherited abilities resolve independently (RECOMMENDED)
- GAP-6: flux_offset content validation clamp ±15 at import (RECOMMENDED)
- GAP-7: AbilityData read-only mutation safety — two characters same entry (RECOMMENDED)
- GAP-8: ability_resolved(id, grade, target) signal emitted after each resolution (RECOMMENDED)
- GAP-9: get_ability() return schema / resolve_ability() API contract (BLOCKING)
- GAP-10: Formula 1 rounding at 0.5 boundary (BLOCKING)
- GAP-11: CC not reset at encounter end, only at start (ADVISORY)
- GAP-12: Combo self-reference authoring warning (ADVISORY)

## Gate Classification (updated after adversarial pass)

- Logic ACs (BLOCKING gate): AC-1, AC-2, AC-3, AC-4, AC-5a, AC-6, AC-7, AC-8, AC-10, AC-11, AC-12, AC-13, AC-14a, AC-14b, AC-14c, AC-15b, AC-16a, AC-21a, AC-21b, AC-22, AC-23a, AC-23b, AC-24a, AC-25
- UI/Advisory ACs: AC-5b, AC-15c, AC-17b, AC-19, AC-20, AC-21c
- Integration ACs (BLOCKING gate): AC-2 (TCS), AC-13, AC-15a, AC-16b, AC-NEW-2, AC-NEW-4, AC-NEW-8, AC-NEW-9
- Architecture/Code Review: AC-24b
- Config/Data (smoke check): AC-NEW-3, AC-NEW-6, AC-NEW-12

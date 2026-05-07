# Review Log: Character Stats & Growth

---

## Review — 2026-04-30 — Verdict: APPROVED (after Revision Pass 1)

Scope signal: L
Specialists: game-designer, systems-designer, economy-designer, gameplay-programmer, ux-designer, qa-lead, godot-specialist, audio-director, creative-director (senior)
Blocking items: 15 resolved in Revision Pass 1 | Recommended: 11 noted
Prior verdict resolved: Yes — MAJOR REVISION NEEDED (2026-04-23) → APPROVED

Summary: Revision Pass 1 resolved all 15 blocking items. Key fixes: AC-11/AC-22 contradiction resolved (effective FLUX=10, not 9); turn order strip model corrected to reference HUD GDD single-chip + ×2 badge; rounding convention specified (round-half-up, use `int(value + 0.5)` not bare GDScript `round()`); BLOCK_WINDOW_BASE safe range raised from 20–50 to 28–50 (Episode 1 enemies with TEMPO 20–24 would collapse to 2-frame floor at BASE=20); FLUX mid-round computation point specified (live at action dispatch); inheritance queue Defeat behavior specified (persists — Pillar 3 aligned); `get_stat()` API contract clarified (fully aggregated with status modifiers passed as parameter); "~45% accumulated growth" note corrected; 3 new ACs added (AC-25 TEMPO vocabulary, AC-26 non-removability, AC-27 sum-then-clamp); AC-4 split (data only, display deferred to HUD GDD); AC-12 split (AC-12a data, AC-12b visual advisory); OQ-4 updated to flag TCS revival gap. Cross-GDD note: OQ-4 revival remains unresolved in TCS; do not author revival abilities until TCS defines REVIVED state.

---

## Review — 2026-04-23 — Verdict: MAJOR REVISION NEEDED → Revised in-session

Scope signal: L
Specialists: game-designer, systems-designer, qa-lead, creative-director
Blocking items: 7 | Recommended: 7
Summary: The fantasy framing ("The Scar That Sings") was strong and pillar-aligned, but the specification layer had critical implementability gaps. The enemy FLUX/block-window relationship was contradictory and lacked a formula entirely; the TEMPO stat was introduced to resolve this. Ne's FLUX inheritance failed the GDD's own perceptual feel threshold (+1 frame < ±2 frame minimum), resolved by adding FLUX_INHERITANCE_MIN=2. Status effect buffs had no ceiling clamp (symmetric with the existing floor), HP inheritance was ambiguous between HP_max and HP_current, and two variable tables contained inconsistent range definitions. All 7 blockers were resolved in-session with user design decisions. 8 new acceptance criteria added (AC-17 through AC-24). Document status updated to "In Review."
Prior verdict resolved: N/A — first review.

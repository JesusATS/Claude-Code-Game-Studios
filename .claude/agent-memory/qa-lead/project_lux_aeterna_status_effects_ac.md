---
name: Lux Aeterna — Status Effects AC status
description: Pass 3 adversarial review completed 2026-05-02; 9 BLOCKING findings (new/unresolved); 8 RECOMMENDED; 3 ADVISORY; CANNOT PASS gate; AC set is AC-1 to AC-34 (Revision Pass 2 rewrite)
type: project
---

## Status Effects — AC Status

- 34 acceptance criteria reviewed (AC-1 to AC-34) — Pass 3 adversarial review (2026-05-02)
- Gate status: CANNOT PASS — 9 blocking issues; 8 recommended; 3 advisory

## Pass 3 BLOCKING Findings (9 total — new/unresolved)

- AC-20: Ellipsis omits positions 4–6 of 7-param signal; `assert_signal_emitted_with_parameters` requires full array
- AC-6/AC-34: Audio refresh suppression gated Advisory; must be BLOCKING (functional correctness, not cosmetic)
- AC-14: `modifier_value = −50` invalid per StatusEffectData schema (range −30 to +30); fixture is out-of-range data
- AC-26: Counter-exemption integration test delegated to TCS with no cross-reference or tracking anywhere
- Missing: No AC for `get_active_effect_ids()` return type and content correctness
- Missing: No AC for `get_active_effects()` deep copy isolation (mutation does not corrupt tracker)
- AC-15/16: Logic portion (`get_modifier` return value) still filed under Advisory gate; misclassification
- AC-17a/17b: "before round start"/"mid-round" not defined as API event; untestable as written
- AC-20: BLOCKING signal assertion filed under Advisory UI gate; will be skipped without promotion

## Pass 3 RECOMMENDED Findings (8 total)

- Missing: No AC for `get_modifier` returning 0 with no active effects (all 4 stats)
- Missing: No AC for `initialize_encounter` on clean first-game state (no trackers)
- Missing: No AC for `has_effect` on unregistered combatant_id (no crash, returns false)
- AC-9/22: No assertion that `status_effect_tick` is absent on expiry tick; mutual exclusion unverified
- AC-11: Audio suppression on incapacitation/encounter-end expiry path has no gate anywhere
- AC-12: "at least one combatant" insufficient; multi-combatant signal completeness unverified
- AC-5: `push_error` assertion too weak; must assert message contains effect_id + combatant_id
- AC-25: Section header (BLOCKING) contradicts inline annotation (Advisory); resolve
- AC-33: No cross-reference to TCS test guarding incapacitation target path

## Pass 3 ADVISORY Findings (3 total)

- AC-1/2: Truth-table cross-reference for HIT-with-PERFECT-threshold case not explicit
- AC-27: Cap formula inconsistency (precomputed vs. stated `duration_turns × 2`)
- AC-32: "direction = buff" references non-existent field; validation condition must use `modifier_value > 0`

## Designer Rulings Required (UNRESOLVED — blocks test authoring)

1. **Finding 27 (AC-NEW-2)** — What does Status Effects do when `apply_effect` is called for a combatant whose StatusTracker was cleared by `notify_incapacitated()`? GDD says "not a Status Effects concern" but does not specify guard vs. passthrough behavior. BLOCKING.
2. **Finding 34 (AC-11 cross-GDD)** — Transition table says `status_expired` IS emitted on incapacitation. Visual/Audio section says no expiry audio. But `status_expired` has no `cause` parameter — HUD cannot distinguish natural vs. forced expiry from signal alone. Options: add `cause` param; add separate `status_force_cleared` signal; or suppress sfx_expire_id inside Status Effects during incapacitation clearing. Designer + TD must rule. BLOCKING.

## GDD-Wide Vocabulary Fix Required

- "GOOD" used throughout GDD body and ACs instead of canonical "HIT" (MISS / HIT / PERFECT).
- Affected: Formula 3 encoding table, truth table, Application Rules, Tuning Knobs, ACs 1-3.
- Action: Designer does find/replace "GOOD" → "HIT"; updates Formula 3 encoding table (HIT = 1).

## Pass 2 BLOCKING Issues (13 total — now superseded by Pass 3)

- AC-1: Pass condition underspecified (no signal/state observation defined); vocabulary error
- AC-2: "GOOD-or-better-gated" not a field name; missing PERFECT subcase; vocabulary error
- AC-3: Verification method unspecified; three status_trigger_grade cases not enumerated
- AC-6: Refresh signal emission not specified (status_applied must fire on refresh per transition table)
- AC-9: Signal not referenced; Logic/UI conflated (split into 9a Logic + 9b UI)
- AC-11: "Immediately" unmeasurable; audio suppression mechanism contradicts transition table (see Finding 34)
- AC-15: Integration story misclassified as Logic; "before round start" undefined at API level
- AC-17: "next round" / "following round" ambiguous; two ACs in one; round boundary not defined by API event
- AC-18: "Larger" unmeasurable; no measurement method or fixture; Integration story misclassified
- AC-19: "Smaller" unmeasurable; Logic/UI conflated; Visual portion requires sign-off
- AC-22: UI timing assertion ("before next combatant's turn begins") unverifiable by automated test
- Finding 34: status_expired signal schema insufficient for incapacitation vs. natural expiry distinction
- Finding 35: "GOOD" vocabulary used throughout GDD body

## RECOMMENDED Issues (12 total)

- AC-4: Three-case enumeration missing; logic layer not verified (only visual)
- AC-5: Log verification unspecified; ENEMY_ONLY/ALLY_ONLY both directions not enumerated
- AC-7: No concrete fixture; "sum of both modifiers" needs fixed inputs
- AC-8: Hardcoded magnitudes (DISSONANCE −5, RESONANCE +6) fragile vs. tuning; use QA fixture
- AC-10: Fixture duration_turns not stated; decrement order not explicit
- AC-12: Tests passive start-state only; enemy trackers not covered; clearing event not tested
- AC-13: Hardcoded DISSONANCE −6; use QA fixture
- AC-14: No fixture inputs; floor/ceiling cases not enumerated separately; clamping layer not specified
- AC-16: "After the enemy's first action" undefined at signal level
- AC-20: Signal/UI conflated; turns_remaining value not verified
- AC-21: Does not distinguish natural expiry from incapacitation-triggered clearing
- AC-23: Human-judgment visual test; must be classified Visual/Advisory with lead sign-off
- AC-24: Log verification unspecified; "no crash" insufficient as sole pass condition
- AC-25: "Loadable" undefined; should be Config/Data smoke check (Advisory), not BLOCKING

## Missing ACs (8 total)

- AC-NEW-1 (BLOCKING): status_applied emitted on refresh path (not just initial application)
- AC-NEW-2 (BLOCKING — needs ruling): apply_effect targeting post-incapacitation combatant
- AC-NEW-3 (BLOCKING — needs ruling): condition evaluation order (MISS check before valid_targets check)
- AC-NEW-4 (Integration/BLOCKING): sfx_apply_id fires exactly once on application, including on refresh
- AC-NEW-5 (BLOCKING — needs ruling): encounter-end active clearing (does status_expired fire during initialize_encounter?)
- AC-NEW-6 (Integration/BLOCKING): QUICKEN duration=1 mid-round yields zero benefit (documented edge case, no AC)
- AC-NEW-7 (BLOCKING): content warning log verified on valid_targets mismatch (WARNING level, includes effect_id + combatant_id)
- AC-NEW-8 (BLOCKING): get_stat_modifier() returns 0 with no active effects (all 4 stats)

## Key Pattern Notes

- Status Effects ACs heavily mix Logic/Integration/UI layers — split each AC by story type
- Integration ACs (SPD, FLUX effects) require TCS in the test harness — cannot be unit-tested in isolation
- All magnitude-hardcoded ACs (8, 13) should use QA-fixture StatusEffectData entries, not production values
- "Before round start" / "mid-round" must always be defined by the API event that marks the boundary

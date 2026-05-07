# Review Log: Status Effects

---

## Review — 2026-05-02 (Re-review Pass 3) — Verdict: APPROVED (Revision Pass 3 applied; user accepted without re-review)

Scope signal: L
Specialists: game-designer, systems-designer, qa-lead, gameplay-programmer, audio-director, godot-specialist, creative-director (senior)
Blocking items: 12 resolved in Revision Pass 3 | Recommended: 10+ applied
Prior verdict resolved: Yes — RP2 blockers confirmed resolved; 12 new blockers identified and resolved in this pass

Summary: Third adversarial pass revealed one critical signal contract defect (`old_value`/`new_value` unimplementable — SE cannot compute effective-stat without an undeclared CS&G dependency), a missing design decision (`status_trigger_grade` not documented per effect in the Effect Catalogue), and multiple AC precision errors. Key changes: (1) `status_effect_applied` redesigned from 7 to 6 params: `old_value`/`new_value` replaced with `modifier_delta: int` (SE-owned modifier layer only); on refresh `modifier_delta == 0` documented with explicit HUD zero-delta handling requirement. (2) "Typical Trigger Grade" column added to Effect Catalogue (SLUGGISH=PERFECT, MUTED=PERFECT, all others=HIT) with authoring note. (3) `notify_incapacitated` clear-vs-discard ambiguity resolved: clears `active_effects` but leaves tracker in registry. (4) `duplicate_deep()` pre-implementation smoke test required with manual copy fallback specified. (5) AC-37 added (BLOCKING, 6-param positional signal payload assertion); AC-14 fixture fixed (two −25 entries instead of invalid −50); AC-15/16 split into Logic/BLOCKING and Integration/Advisory; AC-17a/17b round-boundary states defined as explicit API call sequences; AC-26b added (PERFECT counter-exemption TCS integration test); AC-34 reclassified BLOCKING; AC-35/36 added (get_active_effect_ids return type; deep-copy isolation); AC-22 mutual-exclusion assertion added. Typed Dictionary fallback note removed; `class_name` uniqueness warning added. Audio System GDD blockers correctly documented as pending implementation-blocking amendments (not SE approval-blocking). Approved by user without 4th-pass re-review.

---

## Review — 2026-05-02 (Re-review) — Verdict: NEEDS REVISION (Revision Pass 2 applied; re-review required)

Scope signal: L
Specialists: game-designer, systems-designer, qa-lead, gameplay-programmer, audio-director, godot-specialist, creative-director (senior)
Blocking items: 7 resolved in Revision Pass 2 | Recommended: 10 applied
Prior verdict resolved: Partial — RP1 (15 blockers) confirmed resolved; 7 new blockers identified and resolved in this pass

Summary: Re-review after RP1. Root cause of new blockers: SE GDD was revised in isolation — it updated internal signal payloads but did not reconcile with the HUD GDD (Approved) or Audio System GDD (Designed). Key changes: (1) Signal schema reconciled with HUD GDD: `status_applied` → `status_effect_applied` (extended with `stat_delta_key`, `old_value`, `new_value`, `is_refresh: bool`); `status_expired` → `status_effect_expired`; `status_effect_tick` declared as new signal. (2) `is_refresh: bool` added to eliminate Audio System shadow-tracking requirement. (3) TCS Round End Sequence contradiction documented and cross-GDD amendment filed. (4) Required Audio System GDD Amendments section added (6 items). (5) `extend_effect_duration` cap expression made explicit. (6) Formula 3 truth table "ANY" phantom rows removed; exhaustive truth table with correct rows added. (7) RefCounted base class mandated for ActiveStatusEffect and StatusTracker. (8) Full AC revision pass: ACs 1–22 rewritten for GUT testability; AC-32–34 added. Cross-GDD amendments still pending before implementation.

### Revision Pass 2 Changes
- Signal names: `status_applied` → `status_effect_applied`; `status_expired` → `status_effect_expired`; `status_effect_tick` declared
- `status_effect_applied` extended payload: `stat_delta_key: StringName`, `old_value: int`, `new_value: int`, `is_refresh: bool`
- `is_refresh` flag: `false` on first application, `true` on refresh — Audio System suppresses sfx_apply_id when `is_refresh == true`
- Transition table updated to emit correct signal names with is_refresh values
- `tick_turn` description updated: emits both `status_effect_expired` (on expiry) and `status_effect_tick` (on decrement)
- `initialize_encounter` description: added "first-call no-op is correct" clarification
- Duration and Expiry: added `ability_resolved` CONNECT_DEFAULT requirement; added TCS Round End Sequence contradiction note
- RefCounted base class: mandated for `ActiveStatusEffect` and `StatusTracker` in class_name requirement note
- Typed Dictionary fallback note added for Godot 4.6 verification
- `extend_effect_duration` cap: explicit formula `min(turns_remaining + bonus_turns, StatusEffectData.duration_turns × 2)`; which `duration_turns` specified
- Formula 3 truth table: removed 3 "ANY" rows (non-authored StringName); added 2 missing MISS rows; table is now exhaustive; "ANY" numeric constant clarified as design-reasoning reference only
- Formula 2 STATUS_MOD range: "(MVP practical bound; theoretical max −60 to +60)" note added
- `sum(NIO)` range: `~0 to 15` → `0 to INHERITANCE_MAX × max_guests_per_stat` with CS&G cross-reference
- Stacking rules: "one buff + one debuff per stat" explicitly labeled as MVP emergent property, not enforced invariant
- Encounter authoring note: enemy self-debuff first-hit discount documented in Duration section
- QUICKEN duration-1 validation: elevated from "recommended" to "required" with AC-32
- Required Audio System GDD Amendments: new section listing 6 required changes (shadow-tracking, mixing priority tiers, delay mechanism, signal routing, pool budget, CC chime cross-reference)
- ACs 1–3: observation methods added (has_effect(), assert_signal_emitted_with_parameters)
- ACs 6, 9, 11, 12, 15, 17, 18, 19, 20–22: rewritten for GUT testability; conflated Logic/UI assertions split; signal names updated
- AC-17 split into AC-17a and AC-17b; AC-18/19 split into 18a/18b and 19a/19b/19c
- WINDOW_SCALE_FACTOR anchored to Character Stats & Growth GDD in ACs 18b/19b
- AC-22: rewritten to reference `status_effect_tick` signal assertion instead of unverifiable timing clause
- AC-26: observation method added
- AC-27b: at-cap no-op behavior test added
- AC-32: QUICKEN duration-1 required validation AC
- AC-33: post-incapacitation targeting AC (documents intentional absence of guard)
- AC-34: audio refresh suppression integration test
- GUT signal assertion methodology note added at top of ACs section
- Cross-GDD Work Required table added to Open Questions (TCS, HUD, Audio, AS amendments)
- systems-index.md updated

### Cross-GDD Work Required Before Implementation
- TCS GDD: (1) add `notify_incapacitated` to SE interface table; (2) correct Round End Sequence Step 1 description; (3) add CONNECT_DEFAULT note for SE's `ability_resolved` subscription
- HUD GDD: confirm signal schema reconciliation (SE now matches HUD GDD Required Upstream Amendments); confirm Rule 7a covers all MUTED applications
- Audio System GDD: full amendments per Required Audio System GDD Amendments section (6 items)
- AS GDD: add `extend_effect_duration()` call contract and clarify call timing vs. `ability_resolved`
- Architecture ADR: scene-tree placement (OQ-5) — still pending; conditional approval on all above systems

---

## Review — 2026-05-02 — Verdict: MAJOR REVISION NEEDED (Revision Pass 1 applied; re-review pending)

Scope signal: XL
Specialists: game-designer, systems-designer, economy-designer, qa-lead, gameplay-programmer, godot-specialist, audio-director, creative-director (senior)
Blocking items: 15 resolved in Revision Pass 1 | Recommended: 12+ noted
Prior verdict resolved: N/A — first review

Summary: First review found MAJOR REVISION NEEDED. Root causes: (1) Grade vocabulary used "GOOD" throughout instead of canonical "HIT" (AS GDD revised this months ago; SE GDD never back-propagated). (2) Complete TCS API mismatch — SE published `get_stat_modifier`, `notify_turn_ended` while TCS (Approved, authoritative) calls `get_modifier`, `tick_turn`, and additionally requires `tick_round_end` and `check_turn_skip` which SE did not define. (3) `apply_effect()` incorrectly listed in public API — internal-only method. (4) `status_expired` signal had no `cause` parameter, making it impossible for Audio System or HUD to distinguish natural expiry from incapacitation suppression or encounter-end cleanup. (5) Audio ownership unspecified — who subscribes to SE signals vs. who calls whom was undefined. (6) STATUS_ADD combo enhancement had no delivery mechanism (no public API method for AS to call). All 15 blockers resolved in Revision Pass 1 in-session. Three design decisions made by user: (a) PERFECT counter is EXEMPT from SE duration counting (TCS-fired counter ≠ combatant's own action); (b) `sfx_apply_id` does NOT replay on refresh (silent); (c) STATUS_ADD delivery path = `extend_effect_duration()` added to SE public API.

### Revision Pass 1 Changes
- Grade vocabulary: "GOOD" → "HIT" globally (Application Rules §3, Formula 3 encoding table and truth table, ACs 1/2)
- `get_stat_modifier` → `get_modifier(combatant_id, stat) → int`; `notify_turn_ended` → `tick_turn(combatant_id) → void`
- `tick_round_end(combatant_id) → void` added: MVP no-op stub; exists for post-MVP round-scoped effects (STUN)
- `check_turn_skip(combatant_id) → bool` added: MVP always-false stub; TCS interface contract satisfied
- `get_active_effects()` split: struct version for HUD (returns `Array[ActiveStatusEffect]`, `duplicate_deep()`); `get_active_effect_ids()` for TCS (returns `Array[StringName]`)
- `apply_effect()` removed from public API table; documented as internal-only
- `status_expired` signal extended: `cause: StringName` added (`"natural"`, `"incapacitated"`, `"encounter_end"`); cause behavior table added; audio suppression rule documented
- Audio ownership: Pattern B — Audio System subscribes to SE signals; SE does not call AudioSystem directly; cross-reference note added
- `extend_effect_duration(combatant_id, effect_id, bonus_turns: int) → void`: new public API for AS STATUS_ADD payoff; capped at `duration_turns × 2`; no-op if effect not active or bonus_turns ≤ 0
- Encounter-end cleanup: `initialize_encounter` now emits `status_expired(…, "encounter_end")` for each active effect before discarding trackers (prevents HUD stale icons)
- `notify_incapacitated` cross-reference note: TCS GDD must be amended to add this call to its SE interface table
- Godot 4.6 class_name mandates: `ActiveStatusEffect` and `StatusTracker` must each declare class_name in their own `.gd` files for typed Array/Dictionary support
- `get_active_effects()` deep-copy: `duplicate_deep()` specified (Godot 4.5+); plain `duplicate()` deprecated for nested objects
- Signal re-entrancy scope clarified: SE internal mutation is synchronous; only SE→TCS callbacks would need `call_deferred()` (none exist at MVP)
- PERFECT counter exempt: edge case added; AC-26 added; Duration and Expiry section updated
- DISSONANCE+MUTED compounding: encounter design constraint documented (not system constraint)
- `sfx_expire_id` guidance: per-effect table added; all 8 MVP effects recommended non-empty
- Runtime implementation note: `status_trigger_grade` is StringName at runtime (AS GDD schema); Formula 3 numeric encoding is a design reference, not a runtime encoding
- OQ-1 (TCS Approved?) and OQ-2 (signal re-entrancy) marked RESOLVED; OQ-5 added (scene-tree ADR for TCS+AS+SE — conditional approval dependency)
- AC-26 added (counter exempt); AC-27–29 (extend_effect_duration contract); AC-30–31 (tick_round_end / check_turn_skip stubs)

### Cross-GDD Work Required Before Implementation
- TCS GDD: Add `notify_incapacitated(combatant_id)` to SE interface table (currently missing)
- Audio System GDD: Add Status Effects as upstream signal source in Interactions table
- AS GDD: Add `extend_effect_duration()` call contract in STATUS_ADD payoff path
- Architecture ADR: Scene-tree placement for TCS + AbilitySystem + StatusEffectSystem (OQ-5 in SE, OQ-4 in AS, OQ-5 in TCS) — required before any implementation begins

# Review Log: Ability System

---

## Review — 2026-04-30 — Verdict: APPROVED (after Revision Pass 3)

Scope signal: XL
Specialists: game-designer, systems-designer, economy-designer, gameplay-programmer, audio-director, godot-specialist [6/7 — qa-lead pending at time of revision; user accepted without qa-lead re-review]
Blocking items: 19 resolved in Revision Pass 3 | Recommended: 10+ noted
Prior verdict resolved: Yes — NEEDS REVISION (re-review after Revision Pass 2, 2026-04-30) → Revision Pass 3 applied and Approved

Summary: Full 6-specialist re-review surfaced 19 new blockers across 6 themes. All resolved in-session via Revision Pass 3 and user accepted as Approved. Key fixes: `damage_applied` removed from `resolve_ability()` return (TCS now computes damage directly; return is `{cc_delta, effects_applied}`); `resolve_ability()` restricted to single target (TCS loops per target); `combo_sfx_id_hit: StringName` field added (separate HIT-grade combo payoff asset — no more "reduced volume"); `enhanced_effect` per-type HIT scaling formally defined for all three types (STATUS_ADD and ADDITIONAL_HIT use proportional scaling, value×0.5 rounded toward zero, with degenerate-zero note for value<2); `get_combo_state()` and `reset_encounter_state()` added to Public API; encounter-end ComboState transition added to state machine; two-gate validation (editor property setter + runtime `_load_and_validate()`) specified for `combo_window_turns`, `cc_delta`, and `status_trigger_grade`; `ComboState` and `InheritedAbilityUnlockRecord` require `class_name` declarations for Godot 4.6 typed Dictionary support; `get_ability()` null-return GDScript hint note added; signal re-entrancy addressed via `call_deferred()` pattern mandate; `timing_optional` execution sequence documented; combo arm cue timing specified (after grade tone, not simultaneous); 1-frame expiry cue changed to 80–150ms with tonal contrast requirement; `sfx_id` restricted to preparation/commitment sounds only; AC-28 scope corrected to fire for all abilities; ACs AC-31 through AC-38 + AC-23c/33/34/35/36/37/38 added (38 total ACs). TCS Amendments table added with three mandatory TCS revisions (MAX_CHARGE 4→6, `cc_changed` source_type parameter, `damage` → `damage_applied` field name) — TCS must be revised and re-approved before any AS or TCS implementation begins.

### Revision Pass 3 Changes
- `resolve_ability()` return: removed `damage_applied`; return is now `{cc_delta: int, effects_applied: Array[StringName]}`
- `resolve_ability()` signature: `target_ids: Array[StringName]` → `target_id: StringName` (single target; TCS loops)
- `combo_sfx_id_hit: StringName` field: added to AbilityData schema; HIT-grade combo payoff requires distinct authored asset
- `enhanced_effect` HIT scaling per type: per-type table added; STATUS_ADD/ADDITIONAL_HIT use int(value×0.5) rounded toward zero
- `get_combo_state(combatant_id)`: added to Public API; HUD must use API, not direct dictionary access
- `reset_encounter_state()`: added to Public API; encounter-end and encounter-start transition documented
- Two-gate validation: editor setter + runtime `_load_and_validate()` for combo_window_turns, cc_delta, status_trigger_grade
- `class_name` requirement: ComboState and InheritedAbilityUnlockRecord must declare class_name for Godot 4.6 typed Dicts
- `get_ability()` null return: GDScript 4.x typed return is hint not contract; null-check required despite annotation
- Signal re-entrancy: `call_deferred()` pattern mandated for Status Effects→TCS callbacks
- `timing_optional` execution sequence: explicit frame-by-frame sequence added
- Combo arm cue: fires after grade tone completes, not simultaneously
- Expiry cue: 1-frame → 80–150ms; tonal contrast (falling/neutral) required vs. arm cue (rising/positive)
- `sfx_id` semantics: preparation/commitment sound only; impact/payoff sounds prohibited at confirmation trigger
- AC-28 corrected: `ability_resolved` fires for all abilities (not just those with status_effect_id)
- AC-25 rewritten: two-gate validation pattern; runtime load gate required
- Combo overwrite analysis: strategy documented as valid play pattern; tuning mitigation noted
- TCS Amendments table: three mandatory TCS changes with locations and consequences documented
- Interactions table: updated for new resolve_ability() contract and get_combo_state() API
- Basic Attack sfx_id clarified: per-character sfx_id, no combo fields

### Cross-GDD Work Required (TCS must be revised before implementation)
- TCS GDD: MAX_CHARGE 4→6; safe range 3–6→4–8; CC MAX display updated from 4 to 6 segments
- TCS GDD: `cc_changed(new_cc, delta)` → `cc_changed(new_cc, delta, source_type: StringName)` with audio suppression AC
- TCS GDD: Provisional Assumptions `result["damage"]` → remove damage from resolve_ability() contract entirely (TCS computes damage itself)

---

## Review — 2026-04-30 — Verdict: NEEDS REVISION (re-review after Revision Pass 2)

Scope signal: XL
Specialists: game-designer, systems-designer, economy-designer, qa-lead, gameplay-programmer, godot-specialist, audio-director, creative-director (senior) [full re-review; all agents freshly spawned]
Blocking items: 18 resolved in Revision Pass 2 | Recommended: 12 resolved in Revision Pass 2
Prior verdict resolved: Yes — NEEDS REVISION (re-review after Revision Pass 1, 2026-04-30) → Revision Pass 2 applied

Summary: Full 7-specialist re-review surfaced 18 new blockers and 12 recommended items across combo payoff, signal ownership, CC ambiguity, data schema, and API contract. All items resolved in-session via Revision Pass 2. Key fixes: grade-scaled combo payoff adopted (PERFECT=full enhanced_effect.value; HIT=½ bonus; MISS=base power only, combo consumed); `enhanced_effect` schema formally defined; `cc_delta` field added to AbilityData and declared in `resolve_ability()` canonical return as `{damage_applied, cc_delta, effects_applied}`; `scan_resolved(enemy_id)` signal declared AS-owned (HUD dependency resolved); `timing_optional` CC ruling clarified to 0 CC from all grade inputs (only cc_delta path); OQ-3 resolved (CC lock priority — Ability B armed+unaffordable = non-selectable, combo ticks toward expiry); AbilityData formal field schema table added; `ComboState` and `InheritedAbilityUnlockRecord` typed inner-class structures defined; `get_combatant_abilities()` and `get_ability()` declared in Public API subsection; Signals/Outputs table added; `vfx_id: StringName` field added (required for Inherited); sfx trigger timing specified (at CC deduction, before window opens); `combo_sfx_id` layered behavior specified; AC-26–AC-30 added; ACs 4/9/11/14/19/22/24/25 revised. Cross-GDD work still required: TCS MAX_CHARGE (4→6), HUD MAX_CHARGE (4→6 pips), Status Effects GOOD→HIT vocabulary, Architecture ADR (OQ-4/OQ-5 scene-tree), Guest Character System GDD stub (OQ-5). Re-review required in a new session — run `/design-review design/gdd/ability-system.md` after `/clear`.

### Revision Pass 2 Changes
- Combo payoff: grade-scaled (PERFECT=full `enhanced_effect.value`; HIT=½ bonus; MISS=base only, combo consumed)
- `enhanced_effect` schema: `{type: StringName, value: float, bonus_status_id: StringName}` defined on AbilityData
- `cc_delta: int` field: added to AbilityData schema; default 0; non-negative; returned in resolve_ability response
- `resolve_ability()` canonical return: `{damage_applied: int, cc_delta: int, effects_applied: Array[StringName]}`
- `scan_resolved(enemy_id: StringName)`: declared as AS signal; emitted after timing_optional resolution; HUD receives
- `timing_optional` CC: 0 CC from all grade inputs (AC-22 updated); only cc_delta awards CC on these abilities
- OQ-3: CC lock takes priority — Ability B non-selectable when armed+unaffordable; combo ticks normally
- AbilityData Schema: formal field table added (name, type, description, default for all fields incl. vfx_id, cc_delta, damage_multiplier, enhanced_effect)
- `ComboState` typed inner class: `{armed, setup_id, target_id, turns_remaining}`; stored as `Dictionary[StringName, ComboState]`
- `InheritedAbilityUnlockRecord` typed inner class: `{ability_id, source_guest_id, unlocked_at_chapter}`; stored as `Dictionary[StringName, Array[InheritedAbilityUnlockRecord]]`
- Public API subsection: `get_combatant_abilities()`, `get_ability()` (null+push_error on miss), `resolve_ability()` formally declared
- Signals/Outputs table: all AS signals listed with payload and consumer
- `vfx_id: StringName` field: added to AbilityData; required for Inherited abilities
- sfx_id trigger timing: fires at ability confirmation (CC deduction moment), before timing window opens
- combo_sfx_id: both sfx_id AND combo_sfx_id play on payoff; sfx_id at confirmation; combo_sfx_id after grade resolution
- AC-4: removed literal "6"; AC-9: grade-scaled payoff rows; AC-11: turn-end ordering; AC-14 split into AC-14a/b/c
- AC-19: armed+unaffordable display spec; AC-22: all grades (not just PERFECT); AC-23 split a/b; AC-24: null+push_error
- AC-25: upper bound ≤3 added; AC-26: passives don't grant CC; AC-27: no CC refund on incapacitation
- AC-28: ability_resolved emission; AC-29: ability_list_changed timing; AC-30: Formula 1 rounding boundary

### Cross-GDD Work Still Remaining
- TCS GDD: MAX_CHARGE tuning knob (4→6); safe range (3–6→4–8); `damage_applied` field name canonical; `ability_list_changed`/`scan_resolved` awareness
- HUD GDD: CC pip count (4→6 segments); all hardcoded CC=4 references
- Status Effects GDD: GOOD→HIT grade vocabulary revision
- Architecture ADR: scene-tree placement for TCS and AbilitySystem (OQ-4/OQ-5) — must be authored before any implementation begins
- Guest Character System GDD: stub required before inherited ability contracts can be finalized (OQ-5)

---

## Review — 2026-04-30 — Verdict: NEEDS REVISION (re-review after Revision Pass 1)

Scope signal: XL
Specialists: game-designer, systems-designer, economy-designer, qa-lead, gameplay-programmer, godot-specialist, audio-director, creative-director (senior) [synthesized from prior-session review; full specialist re-validation required in new session]
Blocking items: 21 resolved in Revision Pass 1 | Recommended: 7 noted
Prior verdict resolved: Yes — MAJOR REVISION NEEDED (first review, 2026-04-30) → Revision Pass 1 applied

Summary: Revision Pass 1 resolved all 21 blocking items. Root cause confirmed: TCS Revision Passes 1–3 were never back-propagated to AS. Key fixes: CC model changed from per-character to party-wide (TCS Rule 7); CC gain updated to +2 PERFECT attack / +1 HIT attack / +1 PERFECT block; grade vocabulary GOOD→HIT throughout; `add_combo_charge`/`spend_combo_charge` removed from AS public API (TCS owns CC state entirely); `timing_optional` grade corrected to HIT with `grade_resolved` suppression (TCS Rule 14); Formula 1 rounding changed to `int(value+0.5)` per CS&G convention; Formula 1 floor raised from 2 to 4 frames; Formula 2 (per-character CC transitions) removed and replaced with TCS ownership reference; MAX_CHARGE raised from 4 to 6 (safe range 4–8) to maintain scarcity under skilled play; `AbilityData` read-only policy specified (Godot Resource mutation safety — mutable state in separate per-character structures); TCS designated as `sfx_id`/`combo_sfx_id` trigger owner; `combo_sfx_id: StringName` field added to AbilityData audio schema; Player Fantasy rewritten for party-wide CC model; AC-2 and AC-3 corrected for vocabulary and gain amounts; AC-21 updated (HIT grade + grade_resolved suppression); OQ-4 added (AbilitySystem scene-tree placement — defer to Architecture ADR); OQ-5 added (Guest Character System GDD missing — inherited ability contracts blocked until stub authored). Re-review required in a new session — run `/design-review design/gdd/ability-system.md` after `/clear`.

### Revision Pass 1 Changes
- CC model: per-character `cc_current` → party-wide CC owned by TCS; AS is a consumer
- CC gain: +1 PERFECT → +2 PERFECT attack / +1 HIT attack / +1 PERFECT block
- Grade vocabulary: all "GOOD" → "HIT" (lines 52, 86, 117, 256, AC-2, AC-3, AC-21, AC-22)
- `add_combo_charge` / `spend_combo_charge`: removed from AS public API and interaction table
- Execution flow: removed CC management steps; AS has 3 responsibilities (provide AbilityData, supply timing params, update combo state)
- `timing_optional`: grade → HIT; `grade_resolved` suppression noted (TCS Rule 14)
- CC State subsection: removed; replaced with TCS ownership reference
- Interaction table TCS row: corrected to data-provider-only contract
- Formula 1: `round()` → `int(...+0.5)`; `max(2,...)` → `max(4,...)`; output range updated to 4–30 frames
- Formula 2: per-character CC transition formulas removed; MAX_CHARGE constant retained with updated value
- MAX_CHARGE: 4 → 6; safe range 3–6 → 4–8
- AbilityData read-only policy: specified (Godot Resource mutation safety)
- `sfx_id` trigger owner: TCS designated; `combo_sfx_id: StringName` field added
- Player Fantasy: rewritten for party-wide CC model
- CC Display (UI Requirements): updated to party-wide pip count (6 pips)
- AC-2: rewritten — PERFECT attack +2 / HIT attack +1 / MISS 0
- AC-3: updated — PERFECT block +1 / HIT block 0
- AC-6: `cc_spent` signal order noted
- AC-21: HIT grade + grade_resolved suppression
- OQ-4 added: scene-tree placement (defer to Architecture ADR)
- OQ-5 added: Guest Character System GDD missing

### Cross-GDD Work Still Remaining
- Status Effects GDD: GOOD→HIT grade vocabulary revision
- Guest Character System GDD: stub required before inherited ability contracts can be finalized (OQ-5)
- Architecture ADR (OQ-5 in TCS, OQ-4 in AS): scene-tree placement for both TCS and AbilitySystem — must be authored before any implementation begins

---

## Review — 2026-04-30 — Verdict: MAJOR REVISION NEEDED

Scope signal: XL
Specialists: game-designer, systems-designer, economy-designer, qa-lead, gameplay-programmer, godot-specialist, ux-designer, audio-director, creative-director (senior)
Blocking items: 18 | Recommended: 12
Prior verdict resolved: N/A — first review

Summary: 18 blocking items, all traceable to a single root cause: TCS Revision Pass 2 (completed 2026-04-30) was not back-propagated to this GDD. Key cross-GDD conflicts: CC model is per-character in AS vs party-wide in TCS Rule 7 and HUD GDD; CC gain is +1 PERFECT attack in AS vs +2 PERFECT / +1 HIT in TCS; "GOOD" grade vocabulary used throughout vs canonical MISS/HIT/PERFECT; `add_combo_charge` and `spend_combo_charge` are claimed by both AS and TCS, creating double-award and double-deduction bugs. New findings from this review: CC economy collapses under skilled play at TCS's +2 gain rate (Ne fills MAX_CHARGE=4 in one round, no scarcity); Formula 1 (INHERITED_TIMING_WINDOW_FRAMES) missing rounding convention from CS&G; flux_offset=-11 on Ne (FLUX=8) produces a 2-frame / 33ms timing window silently; AS scene-tree position entirely unspecified; inherited ability unlock persistence architecture unresolvable (Godot shared Resource mutation risk); sfx_id trigger path for ability-identity SFX is unowned by any system; combo payoff audio has no data field and no trigger owner. Guest Character System GDD does not exist, blocking inherited ability integration contract verification. Two pillars at risk: Pillar 2 (CC economy has no stable contract between AS and TCS) and Pillar 3 (inherited ability pipeline has no safe authoring path, no menu visual distinction, no audio path). Creative director recommendation: per-character CC at +1 per PERFECT action; unified MISS/HIT/PERFECT grade vocabulary; single TCS CC ownership (remove add_combo_charge/spend_combo_charge from AS public API); Formula 1 minimum viable window floor (4 frames); Player Fantasy rewrite to match confirmed CC model; Guest Character System GDD stub authored before inherited ability implementation begins.

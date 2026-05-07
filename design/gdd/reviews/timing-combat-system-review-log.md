# Review Log: Timing Combat System

---

## Review — 2026-04-30 — Verdict: APPROVED (after Revision Pass 3)

Scope signal: L
Specialists: game-designer, systems-designer, qa-lead, gameplay-programmer, audio-director, godot-specialist, ux-designer, ai-programmer, creative-director (senior)
Blocking items: 7 resolved in Revision Pass 3 | Recommended: 8 noted
Prior verdict resolved: Yes — NEEDS REVISION (re-review, 2026-04-30) → APPROVED

Summary: Revision Pass 3 resolved 7 blocking items — all interface contract precision gaps plus one creative-director design amendment. Key fixes: `get_stat()` API aligned to CS&G approved signature (passes SE modifier as parameter; returns effective aggregated value); `evaluate_turn()` return extended with `hit_count: int` (fixes multi-hit loop with no source for hit count); `get_active_effects(combatant_id)` added to Status Effects interface (required to build `encounter_state.active_effects`); `encounter_state` freshness mandate added (Godot 4.6 Dictionaries are reference types — new instance per call); `cc_spent(cost: int)` signal added (fires at selection before window, fixes HUD CC bar timing gap); `grade_resolved` suppressed for `timing_optional` abilities (was incorrectly flashing HIT for automatic actions); PERFECT block counter source changed from "highest-ATK living party member" to "the party member who performed the PERFECT block" (creative-director amendment — blocker's mastery, blocker's reward; OQ-3 resolved as a side effect). 4 new ACs added (AC-56–AC-59). Dependency table statuses corrected (Enemy System, CS&G, SSFS, Audio System). Commitment mechanic and block asymmetry documented as explicit design intent. OQ-5 (Architecture ADR) and OQ-6 (CanvasModulate owner) remain open pre-implementation.

### Revision Pass 3 Changes
- `get_stat()` interface: `→ base value` corrected to `get_stat(stat_name, status_modifiers: Array[int]) → int` matching CS&G approved signature
- `evaluate_turn()` return: `{ability_id, targets[]}` → `{ability_id: StringName, targets: Array[int], hit_count: int}`
- SE interface: `get_active_effects(combatant_id: int) → Array[StringName]` added
- encounter_state: "new Dictionary per call" implementation mandate added
- HUD signals: `cc_spent(cost: int)` added (fires before window open at selection); `grade_resolved` annotated as suppressed for `timing_optional`
- Counter source: "highest-ATK living party member" → "party member who performed the PERFECT block" (Rule, AC-18, AC-19, AC-22, PARTY_ALL rule, PERFECT counter held-beat note)
- OQ-3: Resolved — counter-source change makes ATK tie-break question moot
- Rule 14 (timing_optional): grade_resolved suppression explicitly stated
- CC Economy section: CC commitment mechanic documented as intentional design; block MISS asymmetry documented as deliberate
- UI Requirements: PARTY_ALL scope label requirement added ("ALL MEMBERS" indicator before window opens)
- Dependency table: Enemy System → Approved; CS&G → Approved + corrected interface; SSFS → Approved; Audio System → Designed
- AC-56: MISS suppresses status payload on player abilities
- AC-57: CC deduction timing (before window, cc_spent signal fires first)
- AC-58: timing_optional cc_delta from AS IS applied; grade_resolved NOT emitted
- AC-59: Round counter increments correctly at ROUND_END

### Cross-GDD Work Still Remaining
- Ability System GDD: GOOD→HIT, remove per-character CC, remove `add_combo_charge`, update CC gain values, add `get_active_effects()` as consumer note — MAJOR REVISION NEEDED (18 blockers from 2026-04-30 review)
- Enemy System GDD: `evaluate_turn()` return schema must be updated to include `hit_count: int` field; add `sfx_incapacitated_id: StringName` to EnemyData
- Audio System GDD: Author upstream amendments (stem-add/swap API, MUTED hook, APEX detection)
- OQ-5 + OQ-6: Author Architecture ADR before any TCS implementation

---

## Review — 2026-04-30 — Verdict: APPROVED (after Revision Pass 2)

Scope signal: L
Specialists: game-designer, systems-designer, ai-programmer, qa-lead, ux-designer, gameplay-programmer, audio-director, godot-specialist, creative-director (senior)
Blocking items: 14 resolved in Revision Pass 2 | Recommended: 3 resolved
Prior verdict resolved: Yes — NEEDS REVISION (2026-04-30, Revision Pass 1) → APPROVED

Summary: Revision Pass 2 resolved all 14 blocking items from the re-review. Key fixes: Formula 1 output range corrected (~27, not ~147); Audio System added as Hard upstream dependency; AC stat values aligned to Formula table canon (Ne ATK 18, Boing-Boing DEF 4, Clawd SPD 11, Ne SPD 20, SPD_min 9); AC-19 impossible scenario replaced; AC-33 rewritten as testable code-ordering assertion; PERFECT counter UI Requirements corrected to show COUNTER badge driven by `perfect_counter_started` signal; SWIFT_THRESHOLD safe range corrected to 1.2–3.0; audio bus routing corrected (danger-zone tone removed from TCS-initiated table); 6 new ACs (AC-50–AC-55) added for coalescing, per-hit signals, Victory mid-loop, and turn_order_changed conditions; 4 new edge cases added; OQ-6 added for CanvasModulate writer conflict. Two open questions remain pre-implementation: OQ-5 (Architecture ADR — scene-tree placement, window API, combatant ID type, HP store) and OQ-6 (CanvasModulate single-owner node).

### Revision Pass 2 Changes
- Formula 1 output range: `~147` → `~27` (Ne ATK 18 vs DEF 1 example); theoretical max documented
- Audio System added to upstream dependencies (Hard; `begin_combat_layer()` / `end_combat_layer()`)
- Ability System status updated: "Not Started" → "Designed (Needs Revision)"
- HUD System (downstream) status updated: "Not Started" → "Approved"
- SWIFT_THRESHOLD safe range corrected: 1.2–2.0 → 1.2–3.0
- UI Requirements PERFECT counter row: "No additional HUD change" → COUNTER badge + `perfect_counter_started` signal
- AC-2/AC-3: Corrected to Formula-table character stats (Ne SPD 20, Setsuna SPD 15, Clawd SPD 11, SPD_min 9)
- AC-10/AC-11: Corrected to Formula-table stats (Ne ATK 18, Boing-Boing DEF 4 → damage 14 / 22)
- AC-19: Removed impossible scenario; replaced with valid last-survivor PERFECT block case
- AC-33: Rewritten as testable code-ordering assertion (Victory check precedes Defeat check in same function)
- AC-46: Added `perfect_counter_started` signal emission count assertion
- Audio bus table: Removed "Block MISS danger-zone secondary tone" from TCS-initiated events; added note Audio System subscribes independently
- Edge Cases: Added SLUGGISH SPD_min interaction, HIT block on 1 damage = 0 received, `turn_order_changed` firing conditions, Victory mid-multi-hit break-out
- AC-50–AC-55 added: cc_changed coalescing, timing_window_opened per-hit, Victory mid-loop, turn_order_changed ×2, hp_danger_zone re-entry
- OQ-3 updated: AC-50 noted added; ATK tie-break AC still pending AS revision
- OQ-6 added: CanvasModulate writer conflict → CombatEnvironmentController single-owner node required

### Cross-GDD Work Remaining
- Ability System GDD: GOOD→HIT, remove per-character CC, remove `add_combo_charge`, update CC gain values
- Enemy System GDD: Update EC-4.1 to one shared PARTY_ALL window; add `sfx_incapacitated_id: StringName` to EnemyData
- Audio System GDD: Author upstream amendments (stem-add/swap API, MUTED hook, APEX detection)
- OQ-5 + OQ-6: Author Architecture ADR before any TCS implementation

---

## Review — 2026-04-30 — Verdict: NEEDS REVISION → Revision Pass 1 applied

Scope signal: L
Specialists: game-designer, systems-designer, ai-programmer, qa-lead, ux-designer, gameplay-programmer, audio-director, godot-specialist, creative-director (senior)
Blocking items: 24 | Recommended: 12
Prior verdict resolved: No — first review

Summary: The TCS design is architecturally sound and delivers on the "Conducting the Encounter" player fantasy. The core loop (act, respond, build, spend), damage formulas, turn order system, and state machine structure are internally consistent. However, the document could not be implemented as-is due to: 7 cross-GDD contradictions (CC ownership, grade vocabulary, PARTY_ALL window model, missing signals, status suppression, stale interface, ID type), undefined interface contracts blocking 3+ downstream systems, 2 design choices that threatened the player fantasy (CC-on-MISS punishment kept as intentional commitment mechanic; automatic PERFECT counter now has anticipatory telegraph added), and state machine gaps for `timing_optional` and multi-hit abilities. Revision Pass 1 resolved 21 of 24 blockers in TCS. 4 architecture ADR blockers (scene-tree placement, `open_window()` return type, combatant ID type, HP store ownership) deferred to OQ-5 — must resolve before implementation.

### Design Decisions Made (2026-04-30)
- CC model: Party-wide (TCS model). PERFECT attack = +2, HIT attack = +1, PERFECT block = +1. AS per-character model retired.
- Grade vocabulary: MISS / HIT / PERFECT. AS/SE "GOOD" → "HIT" (AS and SE GDDs require revision).
- PARTY_ALL window: One shared window (TCS model). EC-4.1 in Enemy System GDD to be updated.
- CC on MISS: NOT refunded (commitment mechanic confirmed, AC-30 stands).

### Revision Pass 1 Changes
- Rules 12–15 added to Core Rules (MISS/status, PERFECT block suppression, timing_optional, round counter)
- `timing_optional` path added to PLAYER_ACTION state machine
- `encounter_state` schema defined; `enemy_id` → `instance_id` corrected
- HUD signal table expanded: +5 signals (`encounter_started`, `timing_window_opened`, `hp_changed` +old_hp, `hp_danger_zone_entered`, `combatant_incapacitated`)
- PERFECT block counter: 4–6 frame anticipatory held beat + `COUNTER` badge added
- Multi-hit ability loop documented (Edge Cases) + AC-45/46
- Edge Cases: round counter, timing_optional CC, multi-hit counter limit
- Audio bus routing table added (12 events specified)
- CC gain coalescing rule added
- Provisional Assumptions rewritten (AS GDD now exists; cross-GDD decisions documented)
- OQ-1/OQ-2 resolved; OQ-5 added for architecture ADR
- ACs: AC-41 to AC-49 added (total now 49)

### Cross-GDD Work Pending After This Review
- Ability System GDD: remove `add_combo_charge`, change GOOD → HIT
- Status Effects GDD: change GOOD → HIT
- Audio System GDD: author upstream amendments (stem-add/swap, MUTED hook, ducking API)
- Enemy System GDD: add `sfx_incapacitated_id` field to EnemyData; update EC-4.1 PARTY_ALL to one shared window

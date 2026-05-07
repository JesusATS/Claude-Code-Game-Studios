# Dialogue System — Review Log

## Review — 2026-04-29 — Verdict: APPROVED
Scope signal: L
Specialists: game-designer, systems-designer, godot-specialist, ux-designer, qa-lead, narrative-director, creative-director
Blocking items: 20 resolved in-session | Recommended: 0
Summary: Re-review of Revision Pass 3. All prior blockers confirmed resolved. 20 new blocking issues identified and resolved in-session. Key changes: `condition_mode` definition deduplicated (C.1 is authoritative); `operand` Variant serialization warning added; `DialogueFlagWrite.value` gains `StringName` + runtime `typeof()` guard; `_node_map: Dictionary[int, DialogueNode]` fully specified in `start()` step 1; DFS clarified to cover all edge types including `else_next` (DFS data structures must be local to `_validate_graph()`); `CONDITIONAL_STACK_DEPTH_LIMIT` off-by-one fixed; `advance()` end-node and `_advance_pending` guards added; typed empty array `Array[DialogueChoice]()` on line dispatch; `create_timer(x, false)` + critical carry-over await; UI parented to Autoload; `HOLD_TO_REREAD_MS` split from `CRITICAL_ADVANCE_MS`; consecutive `is_recognition` nodes replay accent; Compatibility renderer constraint documented; `[pause=N]` pipeline fully specified; accessibility toggle covers both hold behaviors; 10 new ACs (AC-53–AC-62), 62 ACs total.
Prior verdict resolved: Yes — NEEDS REVISION (2026-04-29)

## Review — 2026-04-29 — Verdict: NEEDS REVISION → Revision Pass 3 Complete
Scope signal: L
Specialists: game-designer, systems-designer, godot-specialist, ux-designer, qa-lead, narrative-director, creative-director
Blocking items: 19 resolved in-session | Recommended: 4 (documented in GDD)
Summary: Re-review of Revision Pass 2. The 12 prior blockers were confirmed resolved; 19 new blocking issues were identified and resolved in-session. Key changes: `is_recognition` redesigned as authored field on `DialogueNode` (not inferred from routing); `importance: &"critical"` field added for hold-to-confirm advance friction on guest departure lines; dialogue UI lifecycle spec (persistent node, no reconnect); C.5 step 7 ownership fixed to DialogueManager; selectable_count=1 subcase added; flag rename warning in C.6; all crash-class `start()` aborts now emit `dialogue_ended`; typeof guard requirement in C.3/E.4; Godot 4.6 dual-focus input lock implementation; AC table revised (AC-7, AC-17, AC-18, AC-19, AC-22, AC-35, AC-37 split, AC-38 reworked) and expanded to 52 ACs (AC-39–AC-52 new). Re-review required in a fresh session.
Prior verdict resolved: Yes — NEEDS REVISION (2026-04-29)

## Review — 2026-04-29 — Verdict: NEEDS REVISION → Revision Pass 2 Complete
Scope signal: L
Specialists: game-designer, systems-designer, godot-specialist, ux-designer, qa-lead, creative-director
Blocking items: 12 resolved in-session | Recommended: 10 (documented in GDD)
Summary: Re-review of Revision Pass 1. The 25 prior blockers were confirmed resolved; the architecture is sound. 12 new blocking issues identified — all introduced or left unresolved by the revision: recognition indicator signal gap (is_recognition: bool added to dialogue_line_ready), filter_choices() insufficient for locked rendering (clarifying rule added), else_next C.1/C.2 contradiction (resolved), K=0 infinite loop regression (dialogue_ended immediately), DFS path-based tracking requirement, hold-to-re-read underspecified (HOLD_TO_REREAD_MS = 400ms added), d-pad navigation algorithm, AC-20 fixture prerequisite, 4 new ACs (OR all-fail, locked-pass, recognition indicator, legibility convention). Re-review required in a fresh session.
Prior verdict resolved: Yes — MAJOR REVISION NEEDED (2026-04-29)

## Review — 2026-04-29 — Verdict: MAJOR REVISION NEEDED → Revision Pass 1 Complete
Scope signal: L
Specialists: game-designer, systems-designer, narrative-director, ux-designer, qa-lead, godot-specialist, creative-director
Blocking items: 25 resolved in-session | Recommended: 14 (documented in GDD)
Summary: First full design-review. Creative director verdict: "The system as specified cannot deliver its own stated fantasy." Five top issues identified: recognition legibility gap (no mechanism for players to perceive context-sensitive lines), AND-only conditions insufficient for OR-logic, hidden choices contradict the recognition fantasy, advance(-1) sentinel collides with GDScript negative indexing, inner Resource classes require class_name + standalone .gd files. All 25 blockers resolved in-session. Major additions: condition_mode (AND/OR), display field on choices (hidden/locked), else_next field on conditional nodes, filter_choices() helper, _visible_to_original mapping, input lock, WCAG AA contrast spec, recognition visual indicator, semantic one-shot naming, OQ-3 elevated. 15 new/rewritten ACs (AC-24 through AC-34). Re-review required in a fresh session.
Prior verdict resolved: First review

## Authoring — 2026-04-29 — Status: In Review (pending design-review)
Scope signal: M
Specialists: None (authoring session — design-review not yet run)
Sections authored: 11 (Overview, Player Fantasy, Detailed Rules C.1–C.6, Formulas D.1–D.2, Edge Cases E.1–E.7, Dependencies, Tuning Knobs, Visual/Audio Requirements, UI Requirements, Acceptance Criteria AC-1–23, Open Questions OQ-1–4)
Summary: GDD authored from scratch in a single session. Core layer system — DialogueManager Autoload singleton backed by DialogueGraph custom Resource (.tres). Four node types: line, choice, conditional, end. Five condition operators including has_key for Narrative Event Dictionary field access. DialogueFlagWrite fires before dispatch; one-shot pattern uses seen-flags in StoryState (C.6). 23 ACs covering unit, integration, and manual test types. 4 open questions deferred: Character Registry scope (OQ-1), text reveal default (OQ-2), authoring tooling (OQ-3), HUD suppression mechanism (OQ-4). Ready for /design-review in a fresh session.
Prior verdict resolved: First authoring session

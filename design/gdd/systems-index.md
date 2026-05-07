# Systems Index: Lux Aeterna

> **Status**: Draft
> **Created**: 2026-04-21
> **Last Updated**: 2026-04-21
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

*Lux Aeterna* is a 2D turn-based RPG with real-time timing mechanics and a rotating
guest character system where every departure leaves a permanent mechanical trace. The
game is organized into 20 discrete systems spanning combat, party management, world
exploration, narrative infrastructure, audio, and UI. The mechanical core — the timing
combat system and its supporting input detection layer — is the highest-priority
design target and the subject of the MVP prototype. Narrative infrastructure (story
flags, dialogue, cutscenes) is deferred to Vertical Slice, when the guest character
system needs a memory layer to make departures feel lasting. All 5 game pillars
(Story Earns Its Emotion; Rhythm Is Respect; The Company Changes You; The World Has
Memory; Scope Is Story) have been used to prioritize and order the design work.

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | Timing Combat System | Gameplay | MVP | Approved | design/gdd/timing-combat-system.md | 2, 3, 4, 5, 7, 8, 15 | <!-- Revision Pass 4 complete 2026-04-30 (AS-mandated amendments): MAX_CHARGE 4→6 (safe range 4–8); CC bar 4-segment→6-segment; cc_changed signal extended with source_type: StringName ("window_grade"/"ability_delta"); Audio System suppresses CC chime for ability_delta; resolve_ability contract updated — AS no longer returns damage_applied; TCS computes damage using own formula with ability.damage_multiplier from AbilityData; damage formula updated to include damage_multiplier; Provisional Assumptions corrected; AC-43/50/57/58 updated for new contracts; OQ-5 (Architecture ADR) and OQ-6 (CanvasModulate owner) remain open pre-implementation --> |
| 2 | Input & Timing Detection | Core | MVP | Approved | design/gdd/input-and-timing-detection.md | — | <!-- Approved 2026-05-03 after Revision Pass 1 (10 blockers resolved): grade vocabulary uppercase (MISS/HIT/PERFECT/ACTION/BLOCK); PERFECT zone perceptibility requirements added to Visual/Audio section; force_close_window() added to Signal Schema; open_block_window during BLOCK_FORGIVENESS FSM row added; echo filter constraint added to Core Rule 5; frame counter increment order specified; BLOCK mode grade ACs added (AC-3b–6b); force_close_window() ACs for BLOCK_WINDOW and BLOCK_FORGIVENESS added (AC-24b/24c); same-frame signal collision implementation pattern corrected; class_name + OQ-2 promoted to Implementation Constraints. -->
| 3 | Ability System | Gameplay | MVP | Approved | design/gdd/ability-system.md | 8 | <!-- Approved 2026-04-30 after Revision Pass 3 (19 blockers resolved): damage_applied removed from resolve_ability() return — TCS computes damage directly; resolve_ability() restricted to single target (loop per target); combo_sfx_id_hit field added (separate HIT-grade asset); enhanced_effect per-type HIT scaling defined (STATUS_ADD/ADDITIONAL_HIT proportional); get_combo_state() + reset_encounter_state() added to Public API; encounter-end ComboState transition added; two-gate validation (editor+runtime load) for combo_window_turns/cc_delta/status_trigger_grade; ComboState+InheritedAbilityUnlockRecord require class_name declarations; get_ability() null GDScript note; call_deferred() re-entrancy pattern; timing_optional execution sequence; combo arm cue timing (after grade tone); 1-frame expiry → 80-150ms; sfx_id preparation-sound requirement; AC-28 scope corrected (all abilities); AC-31–AC-38+AC-23c/33/34/35/36/37/38 added; TCS Amendments table added (MAX_CHARGE=4→6; cc_changed+source_type; damage→damage_applied) — TCS must be revised+re-approved before implementation. --> |
| 4 | Enemy System | Gameplay | MVP | Approved | design/gdd/enemy-system.md | 3, 5, 8 | <!-- Approved 2026-04-29 after 3 revision passes. 107 ACs. --> |
| 5 | Status Effects | Gameplay | MVP | Approved | design/gdd/status-effects.md | 8 | <!-- RP1 (2026-05-02): 15 blockers resolved. RP2 (2026-05-02): 7 new blockers resolved — signal schema reconciled with HUD GDD; is_refresh added; RefCounted mandated; Formula 3 truth table fixed; ACs restructured (AC-32–34 added). RP3 (2026-05-02): 12 blockers resolved — status_effect_applied redesigned (old_value/new_value → modifier_delta:int, 6 params); notify_incapacitated clear-vs-discard clarified; duplicate_deep() smoke-test+fallback added; Typical Trigger Grade column added (SLUGGISH/MUTED=PERFECT, rest=HIT); AC-37 added (BLOCKING payload); AC-14 fixture fixed; AC-15/16 split Logic/Integration; AC-17a/17b round-boundary API defined; AC-26b added; AC-34 BLOCKING; AC-35/36 added; Typed Dict fallback removed; class_name uniqueness warning added; AC-22 mutual-exclusion added. Approved 2026-05-02. Cross-GDD amendments pending before implementation: TCS (4 items), HUD (re-verify modifier_delta schema), Audio System (6 items), AS. -->
| 6 | Guest Character System | Gameplay | Vertical Slice | Not Started | — | 3, 7, 8, 15 |
| 7 | Party Composition Manager | Core | MVP | Approved | design/gdd/party-composition-manager.md | 8 | <!-- Approved 2026-05-03 after Revision Pass 1 (7 blockers resolved): is_initialized() added to Public API; INV-5/duplication contradiction resolved (caller duplicates before passing; PCM holds live reference); TCS API seam fixed (get_living_party→get_active_combatants; HP delta data flow corrected in TCS GDD); guest_slot_changed documented as mechanical-only with binding GCS contract; wrong-length core_data edge case added; get_active_combatants returns shallow copy; get_party_snapshot uses String keys for JSON round-trip safety; 5 new ACs (AC-22 through AC-25 + AC-16a-e split). TCS amended simultaneously (get_living_party→get_active_combatants; HP delta data flows corrected). -->
| 8 | Character Stats & Growth | Core | MVP | Approved | design/gdd/character-stats-and-growth.md | — | <!-- Approved 2026-04-30 after Revision Pass 1; 15 blockers resolved, 27 ACs total; OQ-4 revival unresolved in TCS --> |
| 9 | World Exploration | Gameplay | Vertical Slice | Not Started | — | 4, 10, 15 |
| 10 | Scene Management | Core | Vertical Slice | Not Started | — | — |
| 11 | NPC System (inferred) | Narrative | Episode 1 | Not Started | — | 10, 14, 15 |
| 12 | Save System (inferred) | Persistence | Vertical Slice | Not Started | — | 7, 8, 15 |
| 13 | Party Relationship Dynamics | Narrative | Vertical Slice | Not Started | — | 3, 14, 15 |
| 14 | Dialogue System (inferred) | Narrative | Vertical Slice | Approved | design/gdd/dialogue-system.md | 15 | <!-- Approved 2026-04-29 after Revision Pass 4; 20 blockers resolved, 62 ACs total --> |
| 15 | Story State & Flag System (inferred) | Core | Vertical Slice | Approved | design/gdd/story-state-flag-system.md | — |
| 16 | Cutscene System (inferred) | Narrative | Vertical Slice | Not Started | — | 14, 15, 18 |
| 17 | Item System (inferred) | Economy | Vertical Slice | Not Started | — | 8 |
| 18 | Audio System (inferred) | Audio | MVP | Approved | design/gdd/audio-system.md | — | <!-- Approved 2026-05-04 after Revision Pass 1 (16 blockers resolved): 5-player architecture added (ApexLayerPlayerA/B for APEX condition-phase stems); 2-tier SFX pool priority system (PROTECTED: grade tones/CC chime/HP danger tone; STANDARD: all others); 7 missing signal subscriptions added (status_effect_applied/expired, enemy_condition_changed, hp_danger_zone_entered, combatant_incapacitated, cc_changed, encounter_started); CC chime suppression for ability_delta; is_refresh suppression; sfx_expire_id cause-gating; MUTED pre-baked _muted variant approach; void_shriek ducking mechanism; play_sfx_delayed API; NORMALIZED_TO_DB n<0 guard; T_position>T_length formula guard; SFX_POOL_SIZE raised to 12; Visual/Audio Requirements filled (grade tone spec, HP danger tone, MUTED variants); 5 duplicate AC pairs removed; 8 AC testability fixes; 18 new ACs (AC-61 through AC-78). --> |
| 19 | HUD System (inferred) | UI | MVP | Approved | design/gdd/hud-system.md | 1, 7, 8 | <!-- Approved 2026-04-29 after Revision Pass 3; 17 blockers resolved, 64 ACs total; user accepted without re-review. Consistency Pass 1 (2026-05-02): MAX_CHARGE 4→6 propagated from TCS RP4; MUTED Rule 7a/H3 rewritten for SE RP3 modifier_delta signal schema; MUTED_SCALE_FACTOR tuning knob added. --> |
| 20 | Menu & Settings System (inferred) | UI | Episode 1 | Not Started | — | 12, 18 |

---

## Categories

| Category | Description | Systems in This Game |
|----------|-------------|----------------------|
| **Core** | Foundation systems everything depends on | Input & Timing Detection, Party Composition Manager, Character Stats & Growth, Scene Management, Story State & Flag System |
| **Gameplay** | The systems that make the game mechanically distinct | Timing Combat System, Ability System, Enemy System, Status Effects, Guest Character System, World Exploration |
| **Narrative** | Story and dialogue delivery | Dialogue System, Party Relationship Dynamics, Cutscene System, NPC System |
| **Economy** | Items and consumables | Item System |
| **Persistence** | Save state and continuity | Save System |
| **Audio** | Sound and music infrastructure | Audio System |
| **UI** | Player-facing information displays | HUD System, Menu & Settings System |

---

## Priority Tiers

| Tier | Definition | Target Milestone | Design Urgency |
|------|------------|------------------|----------------|
| **MVP** | Required to test "is timing combat intrinsically satisfying?" | Timing combat prototype | Design FIRST |
| **Vertical Slice** | Required for one complete chapter experience with guest system | Opening chapter + 1 guest | Design SECOND |
| **Episode 1** | Required for a shippable, polished Episode 1 release | Episode 1 launch | Design THIRD |
| **Full Vision** | Polish, extended content, full novel scope | Multi-year | Design as needed |

---

## Dependency Map

### Foundation Layer (no dependencies)

1. **Input & Timing Detection** — The raw input layer; no game logic feeds into it. Designed first because timing feel is the MVP hypothesis.
2. **Character Stats & Growth** — The stat vocabulary used by every other system; must be defined before any other system references stats.
3. **Scene Management** — Pure area-transition infrastructure; nothing feeds into it.
4. **Story State & Flag System** — The game's memory layer; just stores flags. Everything that tracks events reads from it, nothing writes to its schema.
5. **Audio System** — Pure playback infrastructure; nothing feeds into it.

### Core Layer (depends on Foundation)

6. **Ability System** — depends on: 8 (Character Stats — abilities reference and modify stats)
7. **Status Effects** — depends on: 8 (Character Stats — effects are modifications to stat values)
8. **Party Composition Manager** — depends on: 8 (Character Stats — defines what a party member IS)
9. **Dialogue System** — depends on: 15 (Story State — dialogue branches on flag values)

### Feature Layer A (depends on Core + Foundation)

10. **Enemy System** — depends on: 3 (Ability System), 5 (Status Effects), 8 (Character Stats)
11. **Guest Character System** — depends on: 3 (Ability System — inheritance target), 7 (Party Composition), 8 (Character Stats), 15 (Story State)
12. **Item System** — depends on: 8 (Character Stats — items affect stat values)
13. **Save System** — depends on: 7 (Party Composition), 8 (Character Stats), 15 (Story State — must save all flag state)
14. **Party Relationship Dynamics** — depends on: 3 (Ability System — combo routes are abilities), 14 (Dialogue System), 15 (Story State)
15. **Cutscene System** — depends on: 14 (Dialogue System), 15 (Story State), 18 (Audio System)
16. **NPC System** — depends on: 10 (Scene Management), 14 (Dialogue System), 15 (Story State)

### Feature Layer B (depends on Feature A)

17. **Timing Combat System** — depends on: 2 (Input & Timing Detection), 3 (Ability System), 4 (Enemy System), 5 (Status Effects), 7 (Party Composition Manager), 8 (Character Stats), 15 (Story State). This is the most connected system in the graph — design it only after Feature A systems are defined.
18. **World Exploration** — depends on: 4 (Enemy System — visible enemy placement), 10 (Scene Management), 15 (Story State)

### Presentation Layer (wraps Feature systems)

19. **HUD System** — depends on: 1 (Timing Combat System — reads all combat state for display), 7 (Party Composition Manager), 8 (Character Stats)
20. **Menu & Settings System** — depends on: 12 (Save System — drives Continue option), 18 (Audio System — settings control audio)

---

## Recommended Design Order

| Order | System | Priority | Layer | Est. Effort |
|-------|--------|----------|-------|-------------|
| 1 | Character Stats & Growth | MVP | Foundation | M |
| 2 | Input & Timing Detection | MVP | Foundation | M |
| 3 | Audio System | MVP | Foundation | S |
| 4 | Ability System | MVP | Core | L |
| 5 | Status Effects | MVP | Core | M |
| 6 | Party Composition Manager | MVP | Core | S |
| 7 | Enemy System | MVP | Feature A | L |
| 8 | Timing Combat System | MVP | Feature B | L |
| 9 | HUD System | MVP | Presentation | M |
| 10 | Story State & Flag System | Vertical Slice | Foundation | M |
| 11 | Dialogue System | Vertical Slice | Core | M |
| 12 | Item System | Vertical Slice | Feature A | S |
| 13 | Guest Character System | Vertical Slice | Feature A | L |
| 14 | Cutscene System | Vertical Slice | Feature A | M |
| 15 | Party Relationship Dynamics | Vertical Slice | Feature A | M |
| 16 | Scene Management | Vertical Slice | Foundation | S |
| 17 | Save System | Vertical Slice | Feature A | S |
| 18 | World Exploration | Vertical Slice | Feature B | M |
| 19 | NPC System | Episode 1 | Feature A | M |
| 20 | Menu & Settings System | Episode 1 | Presentation | S |

*Effort estimates: S = 1 session · M = 2–3 sessions · L = 4+ sessions. Systems at the same layer and same priority tier can be designed in parallel.*

---

## Circular Dependencies

**None found.** The dependency graph is acyclic — all 20 systems sort cleanly into layers.

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|-----------------|------------|
| **Input & Timing Detection** | Technical | Frame-precise timing at the 2–3 frame level requires careful Godot implementation; wrong timing feel = failed prototype | Prototype this before any other system; validate in Godot 4.6 with the exact rendering path |
| **Timing Combat System** | Design | "Feels musical" is hard to specify; timing window tuning requires iteration | `/prototype timing-combat` after GDD; treat tuning as a separate sprint |
| **Character Stats & Growth** | Scope | This is the shared vocabulary — wrong stat names or missing stats require cascading rework across 9 other systems | Design this carefully and first; do not stub it — fully resolve stat vocabulary before writing any other GDD |
| **Story State & Flag System** | Technical | Wrong data model for flags (event-based vs. boolean vs. state machine) = refactoring pain across 8 dependent systems | Research comparable implementations (Sea of Stars, Disco Elysium); decide the model during GDD authoring, not implementation |
| **Guest Character System** | Design | Inheritance mechanic must feel emotionally meaningful AND mechanically significant; if either fails, Pillar 3 (The Company Changes You) collapses | Design simultaneously with narrative (guest character arcs in novel); prototype with 1 guest before designing the system fully |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 20 |
| Design docs started | 11 |
| Design docs reviewed | 11 |
| Design docs approved | 11 |
| MVP systems designed | 9 / 9 |
| MVP systems approved | 9 / 9 |
| Vertical Slice systems designed | 2 / 9 |
| Episode 1 systems designed | 0 / 2 |

---

## Next Steps

- [x] Systems enumeration approved
- [x] Dependency map validated
- [x] Priority tiers approved
- [ ] Design MVP-tier systems in order — start with `/design-system character-stats-and-growth`
- [ ] Run `/design-review design/gdd/[system].md` after each GDD is authored
- [ ] Run `/prototype timing-combat` after Timing Combat System GDD is written — validate before full production
- [ ] Run `/gate-check pre-production` when all MVP GDDs are designed

# Cross-GDD Review Report
**Date**: 2026-04-29
**Skill**: `/review-all-gdds` (full mode)
**GDDs Reviewed**: 9 system GDDs
**Systems Covered**: Character Stats & Growth, Input & Timing Detection, Audio System, Ability System, Status Effects, Party Composition Manager, Enemy System, Timing Combat System, HUD System
**Also Reviewed**: game-concept.md, systems-index.md, design/registry/entities.yaml

---

## Verdict: FAIL

7 blocking issues must be resolved before architecture begins.
8 warnings should be resolved but will not block.

---

## Consistency Issues

### Blocking (must resolve before architecture begins)

---

**C-01 — CC Economy Contradiction: per-character vs. party-wide; value table mismatch**
- `timing-combat-system.md` §CC Awards table: PERFECT attack = +2 CC, HIT attack = +1 CC; CC is described as a party-wide shared resource accumulated during combat
- `ability-system.md` §Combo Counter section: PERFECT = +1 CC, non-PERFECT hit = 0 CC; CC is described per-character
- Two contradictions in one: (1) the award values disagree (PERFECT: 2 vs 1; HIT: 1 vs 0), and (2) the ownership model disagrees (party-wide vs. per-character)
- Both GDDs define authoritative CC rules with no cross-reference to each other
- **Required action**: Decide CC model (party-wide or per-character) and award values (TCS table or Ability System table). One GDD must be updated to match the other. Document the authoritative source.

---

**C-02 — Grade Vocabulary Fragmentation: HIT vs. GOOD**
- `input-and-timing-detection.md` and `timing-combat-system.md`: use three-tier vocabulary MISS / HIT / PERFECT throughout — in formulas, signal names, AC fixtures, and rule conditions
- `ability-system.md` and `status-effects.md`: use MISS / GOOD / PERFECT — GOOD where TCS/ITD say HIT
- This is not cosmetic: `timing_result_assessed(grade: StringName)` emits one of these values; Ability System and Status Effects subscribe to this signal and branch on grade values. A HIT emitted by TCS will never match GOOD in Ability System's branch — the grade check silently fails
- **Required action**: Standardize on one vocabulary across all GDDs and all signal parameter documentation. If HIT is chosen, update Ability System and Status Effects. If GOOD is chosen, update ITD and TCS.

---

**C-03 — TCS Provisional Interface Not Updated After Enemy System Approval**
- `timing-combat-system.md` §Dependencies or §Provisional Interface section lists several Enemy System signals and data fields as "provisional pending Enemy System GDD authoring"
- Enemy System GDD is now Approved (2026-04-29) with a final signal schema. The provisional notes in TCS are stale and no longer reflect the authoritative Enemy System spec
- Specifically: `enemy_condition_changed` now carries `stinger_tier: StringName` as a fourth parameter (added in Revision Pass 3); TCS provisional entry predates this
- **Required action**: Update TCS §Dependencies / §Provisional Interface to reference approved Enemy System GDD. Remove "provisional" flags on enemy-related interfaces. Verify all signal signatures in TCS match the Enemy System final spec.

---

**C-04 — Status Effects Signal Names/Signatures Contradict HUD GDD**
- `status-effects.md` §Signals declares: `status_applied(target_id: int, status_name: StringName, duration: int)` and `status_expired(target_id: int, status_name: StringName)`
- `hud-system.md` §Signal Subscriptions lists: `status_effect_applied(target_id: int, status_name: StringName, duration: int, stacks: int)` and `status_effect_expired(target_id: int, status_name: StringName)` and `status_effect_tick(target_id: int, status_name: StringName, remaining: int)`
- Mismatches: (1) `status_applied` vs. `status_effect_applied` — different names; (2) HUD expects a `stacks: int` 4th parameter that Status Effects does not emit; (3) HUD subscribes to `status_effect_tick` which Status Effects does not declare at all
- HUD is Approved. Status Effects is Designed. The contract between them is broken.
- **Required action**: Align signal names and signatures. Decide: does Status Effects add `stacks` to `status_applied` and add a new `status_tick` signal? Or does HUD remove these dependencies? Update the non-authoritative GDD to match.

---

**C-05 — TCS Missing Signals Referenced by Downstream GDDs**
- `enemy-system.md` §5 Downstream Signal Consumers lists TCS as emitting `encounter_started` (triggering music layer activation) and `timing_window_opened` (used for accessibility overlay timing)
- `hud-system.md` §Signal Subscriptions lists `hp_changed(character_id: int, old_hp: int, new_hp: int)` — a 3-parameter variant
- `timing-combat-system.md` §Signals section: does not declare `encounter_started`, does not declare `timing_window_opened`, and declares `hp_changed` as a 2-parameter signal `hp_changed(character_id: int, new_hp: int)` without `old_hp`
- Downstream GDDs depend on signals TCS has not committed to emitting
- **Required action**: TCS must add `encounter_started` and `timing_window_opened` to its §Signals section with full parameter signatures. TCS must extend `hp_changed` to 3-parameter form, or HUD must be updated to use the 2-parameter form.

---

**C-06 — PARTY_ALL Block Window: One Shared Window vs. Per-Target Window**
- `timing-combat-system.md` §Multi-Target Resolution: when an enemy ability uses `PARTY_ALL` targeting, TCS opens a single shared block window — one BLOCK_WINDOW_FRAMES duration for the whole party; result applies to all targets simultaneously
- `enemy-system.md` §Edge Cases EC-4.1: "PARTY_ALL abilities open one block window per targeted character; each character's result is resolved independently"
- These rules directly contradict. Under TCS: one window, one input, result propagates. Under Enemy System: N windows for N targets, N independent inputs required
- The contradiction affects player input design (one button press vs. one per character), UI requirements (one prompt vs. N prompts), and difficulty balance
- **Required action**: Decide the authoritative model. Update the non-authoritative GDD. If per-target: TCS must add multi-window sequencing rules. If shared: Enemy System EC-4.1 must be rewritten.

---

**C-07 — PERFECT Block Status Suppression: Undeclared in TCS and Status Effects**
- `enemy-system.md` Core Rules §2 and multiple ACs (AC-12, AC-13, AC-100, AC-101): PERFECT block suppresses the enemy ability's status payload — the status effect is not applied to the party member who achieves PERFECT
- `timing-combat-system.md` §Block Resolution: describes PERFECT block as reducing damage to 0; no mention of status suppression
- `status-effects.md` §Application Rules: describes how status effects are applied; no mention of block grade affecting application; no rule connecting timing grade to status application
- PERFECT block status suppression is a significant mechanic (it defines skill expression against status-heavy enemies) but only one of three GDDs that must implement it knows it exists
- **Required action**: Add PERFECT block → status suppression rule to TCS §Block Resolution. Add corresponding rule to Status Effects §Application Rules. Ensure the rule is consistent with bounce_barrage's multi-hit independent resolution (each window's suppression applies only to that hit's payload).

---

### Warnings (should resolve; will not block architecture)

---

**C-08 — Dependency Asymmetry: Audio System lists no dependents**
- `audio-system.md` §Dependencies: lists no downstream dependents
- `enemy-system.md`, `timing-combat-system.md`, `hud-system.md` all list Audio System as a dependency or signal consumer
- Audio System was designed before these downstream GDDs existed — its Depended On By section was never updated
- **Recommended action**: Add Enemy System, TCS, and HUD System to Audio System §Depended On By. Low-effort update; prevents future authors from assuming Audio System is a leaf node.

---

**C-09 — Entity Registry: referenced_by Lists Incomplete**
- `design/registry/entities.yaml`: 8 entities and 14 constants registered, but `referenced_by` fields are sparsely populated — most entities list only 1-2 GDDs despite being referenced in 4-6
- Example: `BLOCK_WINDOW_FRAMES` constant lists `referenced_by: [timing-combat-system.md]` but is also used authoritatively in enemy-system.md (WSF table, accessibility note) and ability-system.md
- **Recommended action**: Run `/consistency-check` after all blocking issues are resolved to rebuild the registry from GDD content. The current state is a useful skeleton but not reliable as a conflict baseline.

---

**C-10 — Character Stats GDD: FLUX and TEMPO Stat Definitions Partially Stale**
- `character-stats-and-growth.md` defines FLUX and TEMPO with value ranges and growth rates
- `enemy-system.md` D2 formula tables and WSF worked-example table use TEMPO values (e.g., Boing-Boing TEMPO 11, Sectarian Leader TEMPO 24) that were confirmed in Revision Pass 1 after a contradiction was found and resolved
- `timing-combat-system.md` uses TEMPO as input to BLOCK_WINDOW_FRAMES formula; formula boundary analysis depends on the TEMPO ceiling defined in character-stats.md
- If Character Stats GDD has not been updated to reflect the TEMPO=24 Sectarian Leader decision and the SPD → TEMPO relationship, downstream formulas are verified against a stale stat ceiling
- **Recommended action**: Verify Character Stats TEMPO ceiling and SPD→TEMPO growth formula against Enemy System D2 table values. Update if stale.

---

**C-11 — Party Composition Manager: APEX composition rule not cross-referenced**
- `enemy-system.md` AC-106: "No encounter in Episode 1 may contain two APEX-tier enemies" — blocking composition constraint
- `party-composition-manager.md`: does not reference APEX composition limits (this is an enemy-side constraint, not a party-side constraint, but PCM governs encounter setup in the systems map)
- Encounter composition enforcement is currently owned only by Enemy System with no note in PCM or TCS about who enforces it at runtime
- **Recommended action**: Add a note to TCS §Encounter Setup (or PCM §Encounter Rules) clarifying that APEX composition validation is performed at encounter load time, citing Enemy System §5 as authoritative. Prevents the constraint from being missed during implementation.

---

**C-12 — Status Effects: DISSONANCE payload not defined in Status Effects GDD**
- `enemy-system.md`: Sectarian Leader `void_surge` delivers DISSONANCE payload to HIGHEST_ATK target
- `status-effects.md`: defines MUTED, RESONANCE, BRUISED, and other effects — DISSONANCE does not appear in the status effects registry
- Either DISSONANCE needs to be added to status-effects.md, or void_surge's payload should reference an existing effect
- **Recommended action**: Add DISSONANCE to status-effects.md with full definition (stat affected, magnitude, duration, stack behavior, removal conditions), or clarify in enemy-system.md that DISSONANCE is an alias for an existing effect.

---

**C-13 — Audio System: Three Unresolved Upstream Amendments**
- `production/session-state/active.md` §Required Upstream Amendments lists three Audio System changes required before implementation:
  1. Add stem-add/swap API for APEX ambient layers
  2. Stinger routing contract (via `stinger_tier` signal param, confirmed in Revision Pass 3)
  3. MUTED active-state audio hook
  4. Ducking API (void_shriek −6dB rule has no implementation path)
- These amendments were identified during Enemy System review but Audio System GDD has not been updated
- **Recommended action**: Update audio-system.md with these four items before architecture begins. The stem API and stinger routing contract are load-bearing for APEX encounters.

---

**C-14 — HUD System: INCAPACITATED chip behavior references TCS signal not yet confirmed**
- `hud-system.md` §INCAPACITATED display rules references a `character_incapacitated` signal from TCS
- `timing-combat-system.md` §Signals: does not list `character_incapacitated` (it was deferred to HUD GDD authority per Enemy System Revision Pass 1 resolution)
- The deferral resolved the contradiction but left TCS with no declaration of the signal
- **Recommended action**: Add `character_incapacitated(character_id: int)` to TCS §Signals, citing HUD GDD as the authority for display behavior. This is a documentation gap, not a design conflict.

---

**C-15 — systems-index.md: Progress Tracker counts stale**
- `systems-index.md` §Progress Tracker: "Design docs approved: 3" — but 4 GDDs are now Approved (HUD, Story State, Dialogue, Enemy System as of 2026-04-29)
- "Vertical Slice systems designed: 2 / 9" — Story State and Dialogue are both Approved and are Vertical Slice tier; count should be at minimum 2, but the entry may not reflect the Dialogue System approval
- **Recommended action**: Update Progress Tracker counts. Low-effort housekeeping; prevents producer confusion at gate-check.

---

### Info (noted; no action required)

---

**C-16 — Ability System: Ability slot count not cross-referenced in PCM**
- Ability System defines per-character ability slot limits. PCM defines party composition. Neither cross-references the other's limits for total party ability count at any given moment. Not a contradiction — just an unlinked relationship. Relevant at balance review stage.

---

**C-17 — ITD: Frame-rate dependency note missing from BLOCK_WINDOW_FRAMES**
- BLOCK_WINDOW_FRAMES formula output is in frames (at 60fps). ITD GDD correctly notes that all timing is frame-based. Neither ITD nor TCS adds a note about what happens at non-60fps framerates (V-sync disabled, variable delta). Non-blocking for design phase; flag for technical architecture.

---

**C-18 — Story State & Flag System: no flags defined for Enemy System encounter state**
- Story State GDD defines the flag schema. No flags are defined for "has player encountered Mother Zarg" or similar enemy-encounter memory. This may be intentional (world-memory via Story State is a Vertical Slice feature; Enemy System is MVP). Flag for Vertical Slice design pass.

---

## Game Design Issues

### Blocking

---

**D-01 — Grade Vocabulary Fragmentation breaks Pillar 2 skill communication (linked to C-02)**
- Pillar 2 (Rhythm Is Respect): the game communicates timing quality back to the player as the primary skill signal. The grade vocabulary is the language of that communication.
- If HIT and GOOD coexist in different GDDs and one is silently ignored in signal handlers, the player receives no feedback for a class of timing inputs — the skill signal is broken
- **This is a design blocker, not just a consistency blocker.** The pillar depends on this working.
- **Required action**: Same as C-02. Standardize vocabulary first; architecture cannot proceed with a broken skill feedback loop.

---

**D-02 — PERFECT Block Status Suppression: Undeclared rule creates undefined player experience (linked to C-07)**
- PERFECT block status suppression is a significant moment of player mastery expression — "I timed perfectly and avoided the debuff." This is a direct Pillar 2 payoff.
- If TCS and Status Effects do not implement this rule, the mechanic silently fails: PERFECT block happens, damage is suppressed, but the status is applied anyway. The player receives no mastery reward for the timing achievement.
- The player will discover this inconsistency and conclude that PERFECT block is not worth pursuing over GOOD block — undermining the entire timing skill curve.
- **Required action**: Same as C-07. This is both a consistency and design blocker.

---

### Warnings

---

**D-03 — Cognitive Load: 5 simultaneously active systems during combat**
- During a standard combat turn, a player must actively manage:
  1. Timing Combat System — timing window input (active)
  2. Ability System — ability selection and CC routing (active)
  3. Status Effects — tracking active debuffs and planning around them (active)
  4. Enemy System AI — reading enemy state and anticipating next action (active)
  5. Party Composition Manager — party HP and role balance awareness (active)
- Research benchmark: 3-4 concurrent active systems is the comfortable limit for most players
- **Recommendation**: Audit which systems can provide passive telegraphing (e.g., enemy AI state visible in HUD as an icon, removing active "read the enemy" burden from player). Status effects could be made more passive via clear icon language. This is a tuning and UX concern, not a design failure — the systems are individually well-designed. Addressed in UX pass.

---

**D-04 — MUTED status: dominant counter-strategy for SUPPORT enemies**
- Status Effects + Enemy System interaction: MUTED silences SUPPORT enemies (Sectarian), preventing curse_of_weakness application. If MUTED is easy to apply and lasts multiple turns, SUPPORT enemies become trivially ignorable.
- Conversely, if MUTED is rare or costs too much CC, Sectarian can stack curse_of_weakness freely — creating a spike difficulty curve when two Sectarians appear
- Neither GDD specifies MUTED application cost, duration, or CC acquisition rate in encounters that include a Sectarian
- **Recommendation**: Balance pass needed: define MUTED duration vs. Sectarian curse_of_weakness reapplication rate. Add a worked example to the Enemy System encounter balance table showing a 2-Sectarian encounter with and without MUTED.

---

**D-05 — CC positive feedback loop: no explicit dampener defined**
- Ability System: CC enables high-cost abilities. High-cost abilities deal more damage. More damage kills enemies faster. Faster kills mean fewer enemy attacks, meaning fewer status effects, meaning more turns spent attacking, meaning faster CC generation.
- This is a positive feedback loop: early CC advantage → bigger abilities → faster kills → more CC → bigger abilities
- No GDD defines a CC generation ceiling, decay mechanic, or catch-up mechanism for losing teams
- **Recommendation**: Add CC decay or per-turn CC generation cap to Ability System. Alternatively, define that enemy status effects are the primary CC counterweight — but this requires the MUTED balance note above to be resolved first.

---

**D-06 — APEX encounter pacing: only 2 APEX archetypes in Episode 1, composition rules create a ceiling**
- Enemy System AC-106: no encounter may contain two APEX enemies. Episode 1 has two APEX archetypes (Mother Zarg, Sectarian Leader). Combined with 3 non-APEX archetypes, the maximum encounter complexity is 1 APEX + 1 non-APEX by the SUPPORT ≤ 1 rule.
- This is a well-reasoned constraint, but it means Episode 1 has at most 3 encounter archetypes by composition: non-APEX solo, non-APEX group (max 1 SUPPORT), APEX + non-APEX companion
- The TCS GDD describes late-game difficulty scaling. With only 3 valid composition types, difficulty escalation must come entirely from stat scaling and AI complexity, not encounter variety
- **Recommendation**: Acknowledge this ceiling in the Enemy System §5 pacing notes. Confirm that Episode 1 difficulty curve is achievable with stat/AI scaling alone. If not, Episode 1 needs additional non-APEX archetypes.

---

**D-07 — Player Fantasy coherence: "mastery through timing" vs. "party management" identities**
- TCS/ITD Player Fantasy: "You are a rhythmic master — timing is skill expression, every block is earned"
- PCM/Ability System Player Fantasy: "You are a party strategist — role balance and CC routing define your power"
- These are not contradictory, but they represent two different player types. The game asks both of the same player simultaneously.
- In practice: a player who optimizes party composition for CC generation may find timing skill less important; a player who masters timing may find party composition secondary. The dominant strategy finding (D-05) amplifies this.
- **Recommendation**: Design a CC generation scenario where correct party composition AND good timing are both required for optimal outcome — not either-or. This integration point is not currently specified in any GDD.

---

**D-08 — WSF=0.6 accessibility floor creates a 5-frame window approaching reaction time limit**
- Enemy System §WSF worked-example table (added Revision Pass 3): at WSF=0.6 and high TEMPO values (APEX archetypes), BLOCK_WINDOW_FRAMES = 5 frames = ~83ms
- Human simple reaction time is approximately 150–250ms. 83ms is below the reliable human reaction threshold for most players.
- The Enemy System flags this as an "accessibility concern" in the worked-example table, but no GDD defines what the accessibility accommodation is
- **Recommendation**: Define the accessibility fallback explicitly: either a minimum frame floor override in settings (e.g., WSF cannot be set below 0.8 in accessibility mode), or an input-assist option that widens windows. This must be specified before UX design begins.

---

**D-09 — Audio System ducking rule (void_shriek −6dB) has no implementation path**
- Enemy System §Audio: void_shriek (Sectarian Leader) triggers a −6dB music ducking rule during cast
- Audio System GDD does not define a ducking API. The Required Upstream Amendments list notes this gap.
- Without a ducking API, the −6dB rule cannot be implemented, and the atmospheric design intent (silence during void_shriek) fails silently
- **Recommendation**: Same as C-13 item 4. The ducking API must be added to Audio System before architecture begins for the audio layer.

---

**D-10 — Party Relationship Dynamics (Vertical Slice): no mechanical hooks defined in MVP GDDs**
- Guest Character System and Party Relationship Dynamics are Vertical Slice priority. However, Pillar 3 (The Company Changes You) is the game's emotional core.
- No MVP GDD reserves any hooks, flags, or signal endpoints for relationship state. If all MVP systems are implemented without these hooks, retrofitting relationship mechanics will require touching every MVP system.
- **Recommendation**: Identify the minimum set of hook points (signals, stat modifiers, flag checks) each MVP system needs to expose for Pillar 3. Document as a "future integration notes" section in each relevant GDD before architecture begins. This is a design-phase action, not an implementation-phase one.

---

### Info

---

**D-11 — No defined difficulty modes or accessibility skill assists in MVP**
- Multiple GDDs (TCS, Enemy System) imply difficulty scaling is tuning-driven, but no GDD defines a "difficulty mode" system. This is appropriate for MVP scope. Flag for Episode 1 design pass.

---

**D-12 — Tutorial encounter as documented exception to D3 ratio is fragile**
- Enemy System documents Tutorial (1× Boing-Boing, ratio 2.0) as an exception to the D3 Tutorial target (2.5–4.0). This is correct. However, if a second Tutorial encounter is added later, it must re-enter the balance validation. The documented exception should note this explicitly.

---

## Cross-System Scenario Issues

**Scenarios walked**: 5

1. Player achieves PERFECT block against Mother Zarg fire_breath (APEX combat + block + status suppression)
2. Boing-Boing bounce_barrage against full party (multi-hit + PARTY_ALL + per-character vs. shared window)
3. Sectarian Leader activates void_shriek with MUTED active party member (enemy AI + status + audio)
4. Player crosses CC threshold mid-Sectarian-encounter (CC economy + ability unlock + enemy response)
5. Player levels up mid-encounter (progression + combat state + HUD update)

---

### Blockers

---

**S-01 — PERFECT block against fire_breath: status suppression silently fails**
Systems: enemy-system.md, timing-combat-system.md, status-effects.md

Trigger: Player achieves PERFECT block on Mother Zarg fire_breath

Step-by-step:
1. TCS: timing_window_opened, player inputs within PERFECT window
2. TCS §Block Resolution: damage → 0; `timing_result_assessed(PERFECT)` emitted
3. **Missing step**: No rule in TCS connects PERFECT result to status payload suppression
4. Status Effects §Application: `status_applied` fires for fire_breath's BURNED payload — TCS never told it to suppress
5. Player: takes 0 damage but receives BURNED anyway
6. Player experience: "I got a PERFECT and still got burned" — Pillar 2 mastery signal is broken

This is a BLOCKER. The skill feedback loop is broken at the TCS → Status Effects boundary.

**Resolution path**: Add PERFECT block status suppression rule to TCS §Block Resolution (emit suppress_status flag or gate Status Effects application on grade). Update Status Effects §Application to respect the gate.

---

**S-02 — bounce_barrage multi-window: shared vs. per-target contradiction produces undefined state**
Systems: enemy-system.md, timing-combat-system.md

Trigger: Boing-Boing uses bounce_barrage against full party

Step-by-step (under Enemy System Multi-Hit Resolution rule):
1. Enemy System: two independent block windows, sequentially
2. **TCS §Multi-Target (PARTY_ALL)**: one shared window for all targets simultaneously
3. Window 1: opens — but TCS opens one window for all three party members, while Enemy System expects one window per hit
4. If TCS shared-window rule applies: one input covers both hits for all targets — second window never opens
5. If Enemy System per-window rule applies: 2 hits × 3 targets = 6 sequential windows — not defined in TCS

Undefined behavior: TCS and Enemy System each have internally consistent rules that are mutually exclusive. The interaction between bounce_barrage's multi-hit model and PARTY_ALL targeting is not defined anywhere.

This is a BLOCKER. Two approved rules produce contradictory behavior for the same ability.

**Resolution path**: Same as C-06. Decide PARTY_ALL window model first. Then add a bounce_barrage + PARTY_ALL explicit rule: likely 2 sequential windows, each covering all targets simultaneously (most practical).

---

### Warnings

---

**S-03 — CC accumulation at Sectarian encounter: GOOD vs. HIT grade silently zeroes CC award**
Systems: timing-combat-system.md, ability-system.md

Trigger: Player achieves HIT (or GOOD) timing grade during attack in a Sectarian encounter

Step-by-step:
1. ITD: timing result computed, grade emitted as StringName "HIT" (per ITD vocabulary)
2. TCS: CC award table reads "HIT = +1 CC" — awards CC
3. Ability System: grade handler receives "HIT", tries to match "GOOD" branch — no match; 0 CC awarded
4. If both TCS and Ability System manage CC independently: player receives +1 CC from TCS source and +0 from Ability System source — double-counting or silent drop depending on architecture

Unintended outcome: CC accumulates at an incorrect rate. In a Sectarian encounter where CC is needed to apply MUTED before curse_of_weakness stacks, incorrect CC means the player can't execute the intended counter-strategy reliably.

**Recommendation**: Resolve C-02 (grade vocabulary). Confirm single CC authority.

---

**S-04 — APEX condition change signal mid-combat: HUD stinger fires vs. Audio System routing**
Systems: enemy-system.md, hud-system.md, audio-system.md

Trigger: Mother Zarg crosses BREAKING threshold during combat

Step-by-step:
1. Enemy System: `enemy_condition_changed(instance_id, PRESSURED, BREAKING, "tier_3")` emitted
2. HUD System: subscribes to signal, updates health chip color and phase indicator
3. Audio System: subscribes to signal, reads `stinger_tier = "tier_3"`, plays BREAKING stinger
4. **Concern**: Audio System GDD does not yet define the stinger routing contract or `stinger_tier` vocabulary (C-13 upstream amendment)
5. Audio System has no defined behavior for the `stinger_tier` parameter — the implementation will guess or hardcode

Unintended outcome: BREAKING stinger either doesn't play or plays the wrong tier. Emotionally flat encounter climax.

**Recommendation**: Resolve C-13 (Audio System upstream amendments) before implementation. This is a warning, not a blocker, because the data is being transmitted correctly — the receiving system just hasn't been updated yet.

---

### Info

---

**S-05 — Level-up mid-encounter: no defined interaction with combat state**
Systems: character-stats-and-growth.md, timing-combat-system.md, hud-system.md

Character Stats GDD and TCS do not define what happens if a character gains a level (stat recalculation) mid-combat (e.g., from a late-fight experience award). This is an edge case that is unlikely in a turn-based system with level-up deferred to post-combat, but neither GDD explicitly defers level-up to post-combat. Flag for implementation handoff notes.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| timing-combat-system.md | C-01 (CC values), C-02 (grade vocabulary), C-03 (provisional interface stale), C-05 (missing signals), C-06 (PARTY_ALL window), C-07 (PERFECT block suppression) | Consistency | Blocking |
| ability-system.md | C-01 (CC ownership/values), C-02 (grade vocabulary) | Consistency | Blocking |
| status-effects.md | C-04 (signal names/signatures), C-07 (PERFECT block suppression), C-12 (DISSONANCE undefined) | Consistency | Blocking |
| audio-system.md | C-08 (no dependents listed), C-13 (3 upstream amendments unresolved), D-09 (ducking API) | Consistency + Design | Warning |
| character-stats-and-growth.md | C-10 (TEMPO ceiling/SPD formula verify against Enemy System D2) | Consistency | Warning |
| hud-system.md | C-14 (character_incapacitated signal not confirmed in TCS) | Consistency | Warning |
| enemy-system.md | C-06 (PARTY_ALL per-target EC-4.1 must align with TCS decision), D-06 (Episode 1 variety ceiling note) | Consistency + Design | Warning |
| systems-index.md | C-15 (progress tracker counts stale — 4 Approved, not 3) | Consistency | Warning |
| design/registry/entities.yaml | C-09 (referenced_by lists incomplete) | Consistency | Warning |

---

## Required Actions Before Architecture (Blocking)

In priority order:

1. **Standardize grade vocabulary** (C-02, D-01) — Pick HIT or GOOD. Update all GDDs. Unblocks signal contract validation for all downstream systems.
2. **Resolve CC ownership and award values** (C-01) — Decide: party-wide or per-character; TCS table or Ability System table. Update the non-authoritative GDD.
3. **Resolve PARTY_ALL block window model** (C-06) — Decide: one shared window or per-target. Update TCS and Enemy System EC-4.1.
4. **Add PERFECT block status suppression to TCS and Status Effects** (C-07, D-02, S-01) — Add rule to both GDDs. Define interaction with bounce_barrage multi-hit model.
5. **Fix Status Effects signal names/signatures** (C-04) — Align with HUD GDD. Add stacks param and status_tick signal or update HUD.
6. **Add missing TCS signals** (C-05) — Add encounter_started, timing_window_opened, extend hp_changed to 3-param.
7. **Update TCS provisional interface** (C-03) — Remove provisional flags on enemy interfaces; update to approved Enemy System signal spec.

---

*Report generated by `/review-all-gdds` (full mode) — Consistency agent: systems-designer · Design theory agent: game-designer · Senior lead: creative-director*

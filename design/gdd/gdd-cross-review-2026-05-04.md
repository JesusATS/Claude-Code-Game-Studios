# Cross-GDD Review Report
**Date**: 2026-05-04
**Skill**: `/review-all-gdds` (full mode)
**GDDs Reviewed**: 11 system GDDs
**Systems Covered**: Character Stats & Growth, Input & Timing Detection, Audio System, Ability System, Status Effects, Party Composition Manager, Enemy System, Timing Combat System, HUD System, Story State & Flag System, Dialogue System
**Also Reviewed**: game-concept.md, systems-index.md, design/registry/entities.yaml, gdd-cross-review-2026-04-29.md (prior review)
**Prior Review**: 2026-04-29 (Verdict: FAIL -- 7 blockers, 8 warnings)

---

## Verdict: CONCERNS (revised from FAIL after in-session fixes)

~~8 blocking issues must be resolved before architecture begins.~~ All 8 resolved (see Addendum).
12 warnings should be resolved but will not block.
5 cross-system scenarios walked; 2 produced blocking findings (both resolved).

---

## Prior Blocker Resolution: 6 of 7 Resolved

| ID | Issue | Status | Evidence |
|----|-------|--------|----------|
| C-01 | CC Economy Contradiction (party-wide vs per-character) | RESOLVED | CC party-wide, PERFECT +2 / HIT +1 / PERFECT block +1 consistent across TCS and AS |
| C-02 | Grade Vocabulary Fragmentation (HIT vs GOOD) | PARTIALLY RESOLVED | All GDDs standardized except Enemy System -- 8+ instances of "GOOD" remain |
| C-03 | TCS Provisional Interface stale | RESOLVED | TCS RP4 interaction table reflects approved ES API |
| C-04 | SE Signal Names contradict HUD | RESOLVED | SE RP3 6-param schema matches HUD Consistency Pass 1 |
| C-05 | TCS Missing Signals | RESOLVED | encounter_started, timing_window_opened, hp_changed all present |
| C-06 | PARTY_ALL Block Window model | RESOLVED | TCS Rule 14: one shared window, uniform grade |
| C-07 | PERFECT Block Status Suppression | RESOLVED | TCS Rule 13 explicit; SE cross-references TCS as owner |

---

## Consistency Issues

### Blocking (must resolve before architecture begins)

---

**C-02r -- Enemy System Grade Vocabulary Not Updated**
- `enemy-system.md` still uses "GOOD" in 8+ places: Multi-Hit Resolution rule, archetype status-payload descriptions, AC-18, AC-62, AC-101
- All other GDDs standardized to uppercase HIT during ITD RP1 (2026-05-03)
- Implementor using ES as reference will match against "GOOD" when ITD emits "HIT" -- silent branch failure
- **Required action**: Find-replace GOOD with HIT in enemy-system.md (8 locations). [systems-designer]

---

**N-01 -- TCS `get_active_effects()` Return Type Contradicts SE Public API**
- TCS Interactions table calls `get_active_effects(combatant_id) -> Array[StringName]`
- SE RP3 split this into `get_active_effects() -> Array[ActiveStatusEffect]` (for HUD) and `get_active_effect_ids() -> Array[StringName]` (for TCS)
- TCS references a method that no longer exists on SE with the wrong return type
- **Required action**: Update TCS SE interface row to call `get_active_effect_ids()`. [systems-designer]

---

**N-02 -- TCS Round End Sequence Factually Wrong Per SE RP3**
- TCS Round End Sequence Step 1: "Notify Status Effects: end-of-round tick (decrement durations, expire finished effects)"
- SE RP3 declares `tick_round_end` a no-op at MVP; all decrements happen at TURN_END via `tick_turn`
- SE cross-GDD work section explicitly flags this as a required TCS amendment
- **Required action**: Update TCS round-end step to reflect SE RP3 contract. [systems-designer]

---

**N-03 -- TCS Missing `notify_incapacitated()` in SE Interface Table**
- SE RP3 defines `notify_incapacitated(combatant_id)` as a public API method TCS must call at HP=0
- SE cross-GDD amendments section flags this as pending on TCS
- TCS interface table lists get_modifier, get_active_effects, tick_turn, tick_round_end, check_turn_skip -- notify_incapacitated is absent
- Incapacitated combatants would retain stale status trackers and active HUD icons
- **Required action**: Add `notify_incapacitated(combatant_id)` to TCS SE interface. [systems-designer]

---

**N-04 -- Enemy System Missing `sfx_incapacitated_id` Field**
- TCS Visual/Audio section states: "Requires `sfx_incapacitated_id: StringName` field on EnemyData"
- Audio System Rule 3.10 and AC-70 both reference `EnemyData.sfx_incapacitated_id`
- Enemy System EnemyData schema does not include this field
- **Required action**: Add `sfx_incapacitated_id: StringName` to EnemyData schema in enemy-system.md. [systems-designer]

---

**N-05 -- `cc_changed` Signal Signature Mismatch (TCS 3-param vs HUD 1-param)**
- TCS emits `cc_changed(new_cc: int, delta: int, source_type: StringName)` -- 3 parameters
- HUD subscribes to `cc_changed(new_cc: int)` -- 1 parameter
- Audio System correctly uses 3-param form for CC chime suppression
- Latent connection bug: HUD will silently drop delta and source_type
- **Required action**: Update HUD cc_changed subscription to 3-param form. [systems-designer]

---

**N-10 -- QUICKEN + TPR Freeze Contradiction Between SE and TCS**
- SE catalogue says QUICKEN "repositions turn order or pushes a character over SWIFT_THRESHOLD for a double-action window" -- implying real-time effect
- TCS freezes TPR at ROUND_START; mid-round QUICKEN does not change turn count
- Player applying QUICKEN mid-round expects a second action this round; TCS won't deliver it
- SE language actively misleads about the mechanic's timing
- **Required action**: Resolve: (a) QUICKEN only affects next round (update SE catalogue language), or (b) TCS supports mid-round TPR recalc for QUICKEN. Add HUD note for visibility timing. [game-designer]

---

**N-11 -- MUTED Applied to Ne Violates ITD FLUX Floor Constraint**
- Ne (FLUX 8) + MUTED (magnitude -5) -> effective FLUX 3 -> TIMING_WINDOW_FRAMES = 3 (50ms), PERFECT_ZONE_SIZE = 1 frame (16ms)
- ITD documents FLUX < 8 as a "design constraint violation" -- no shipped character should have FLUX below 8
- MUTED on Ne produces exactly this violation; the window is below the reliable human reaction threshold
- Found during Scenario 3 walkthrough: HUD PERFECT zone collapses to a single pixel sliver
- **Required action**: Define a FLUX floor for MUTED: `effective_FLUX = max(FLUX_MUTED_FLOOR, base_FLUX + modifiers)`. Specify in SE (as MUTED constraint) and ITD/CSG (as window floor). Or cap MUTED magnitude to prevent FLUX < 8. [game-designer, systems-designer]

---

### Warnings (should resolve; will not block architecture)

---

**N-06 -- `turn_order_changed` ID Type Mismatch (int vs StringName)**
- TCS: `int`. HUD: `StringName`. Gated on TCS OQ-5 (Architecture ADR). Must be resolved in one pass before implementation.

---

**N-07 -- Systemic `combatant_id` Type Split**
- TCS uses `int` in all signals; HUD, SE, AS, PCM all use `StringName`. Deferred to OQ-5.

---

**N-08 -- `encounter_started` Parameter Naming Inconsistency**
- TCS: `enemy_ids: Array[StringName]`. HUD: `combatant_ids: Array[StringName]`. Same data, different names.

---

**N-09 -- SE `status_effect_expired` Missing `cause` Param in HUD Table**
- HUD table shows 2-param form; SE defines 3-param with `cause`. Audio System correctly uses `cause`. HUD doesn't need `cause` but the mismatch will confuse implementors.

---

## Game Design Issues

### Blocking

---

**B-01 -- CC Spend-Before-Window OQ-2 Unresolved in Approved GDD**
- TCS deducts CC at ability confirmation before the timing window opens
- `refund_cc_on_miss: bool` escape valve is OQ-2 (open, unresolved)
- For 3-CC inherited abilities: MISS = 50% resource wipe with no recovery at MAX_CHARGE = 6
- An approved GDD with an open question on a core economy mechanic is a design hole that blocks encounter design for APEX fights
- **Required action**: Resolve OQ-2 before architecture. Define whether commitment-before-window is unconditional or whether specific inherited abilities get `refund_cc_on_miss = true`. [game-designer]

---

### Warnings

---

**W-01 -- Cognitive Load (D-03) Still Open, Slightly Worsened**
- 5 active systems + new HUD elements (MUTED badges, MAX CC glow, combo armed state)
- No information priority hierarchy defined for simultaneous active-system moments
- Recommended: Define HUD information priority hierarchy during UX spec. [game-designer]

---

**W-02 -- MUTED Dominant Strategy (D-04) New Vector: Enemy-Applied MUTED -> CC Spiral**
- Enemy-applied MUTED narrows PERFECT zone -> CC generation drops -> fewer abilities -> fewer removal options -> MUTED persists
- No worked example validates this loop is bounded by MUTED's 2-turn duration
- Recommended: Add worked APEX-with-MUTED encounter note. [game-designer]

---

**W-03 -- CC Positive Feedback (D-05) Worsened by PERFECT Counter**
- PERFECT block now yields: +1 CC (block) + free HIT counter + +1 CC (counter) = +2 CC per block
- Three PERFECT blocks in a round = +6 CC = full bar from defense alone at MAX_CHARGE = 6
- No per-round CC generation ceiling analysis exists
- Recommended: Calculate theoretical max CC/round at Episode 1 configurations. [game-designer, systems-designer]

---

**W-04 -- APEX Pacing Ceiling (D-06) Unchanged**
- Only 2 APEX archetypes in Episode 1; APEX music infrastructure (4 stems per APEX) has low amortization
- Recommended: Confirm Vertical Slice includes enough APEX encounters to justify system complexity. [game-designer]

---

**W-05 -- Player Fantasy (D-07) Three Identity Claims Now Active**
- Rhythmic master (ITD/TCS) + party strategist (TCS/AS) + inherited-ability historian (AS/Pillar 3)
- No integration design showing all three cohere in a single encounter
- Recommended: Design one benchmark encounter testing all three identities simultaneously. [game-designer]

---

**W-06 -- WSF Accessibility (D-08) No Floor Policy**
- No accessibility mode, no per-encounter TEMPO ceiling for first exposure, no WSF recommendation for new players
- Recommended: Define accessibility fallback (minimum WSF override or input-assist option). [game-designer]

---

**W-07 -- Dialogue System Status Tracking Error**
- GDD header says "In Design"; systems-index says "Approved"
- Recommended: Audit and align. [systems-designer]

---

**W-08 -- Combo Route CC-Lock Expiry Creates Undefined Punishment**
- Armed combo with CC-locked Ability B: combo window ticks down but player can't afford the ability
- Design intent (urgency vs punishment?) is undocumented
- Recommended: Define intended behavior explicitly. [game-designer]

---

**W-09 -- No Pillar 3 Mechanical Hooks in MVP GDDs (D-10) Unchanged**
- No MVP GDD reserves integration stubs for Guest Character System
- Retrofitting across 9 approved GDDs when GCS is designed will require re-reviewing every MVP GDD
- Recommended: Identify minimum hook points before architecture begins. [game-designer]

---

**W-10 -- PARTY_ALL PERFECT Block Counter Agent Undefined**
- One shared window, one input, three party members. Who performs the counter?
- Affects counter animation, damage calc (which ATK?), and combo arm check
- Discovered in Scenario 1 walkthrough. [systems-designer]

---

**W-11 -- PERFECT Counter CC Gain `source_type` Undefined**
- Counter has no timing window (not "window_grade") and is not an ability delta
- Audio CC chime (Rule 3.11) only plays for "window_grade"; counter +1 CC may silently skip the chime
- Discovered in Scenario 1 walkthrough. [systems-designer, audio-director]

---

**W-12 -- No HP Floor Policy for PARTY_ALL AoE**
- Mother Zarg fire_breath x2 (double-action MISS chain) could theoretically wipe party in one round
- No minimum damage cap or defined failure curve for PARTY_ALL abilities
- Recommended: Define HP floor policy or confirm full-wipe-in-2-turns is design intent. [game-designer]

---

## Cross-System Scenario Issues

**Scenarios walked**: 5

### Scenario 1: PERFECT Block Against APEX Boss Ability With Status Payload
**Systems**: TCS, ES, SE, Audio, HUD
**Trigger**: Player achieves PERFECT block on Mother Zarg fire_breath (PARTY_ALL)

1. TCS opens shared BLOCK_WINDOW -> ITD BLOCK_WINDOW state -> HUD renders timing bar
2. Player inputs at PERFECT zone -> ITD emits `input_result(BLOCK, PERFECT)`
3. Audio: PROTECTED-tier PERFECT block tone plays (no race condition -- co-emitted signals)
4. TCS BLOCK_RESOLVE: damage = 0 for all party members; status (BURNED) suppressed per Rule 13
5. PERFECT counter fires -- **but which party member is the counter agent?** (W-10)
6. Counter at HIT grade: +1 CC. **source_type undefined for audio chime** (W-11)
7. Total: +2 CC this action (+1 block, +1 counter)

**Severity**: Warning (W-10, W-11)

### Scenario 2: Double-Turn PERFECT Attack Chain -> Inherited Ability
**Systems**: TCS, AS, HUD
**Trigger**: Clawd (TPR=2) lands PERFECT attack on turn 1, wants 3-CC inherited ability on turn 2

1. Turn 1 PERFECT: +2 CC. Current CC = 2.
2. Turn 2: 3-CC ability locked (3 > 2). Player must select alternate action.
3. CC availability depends on other combatants' actions between Clawd's two turns
4. Turn strip shows x2 badge but does not communicate intra-round position relative to others

**Severity**: Warning (HUD legibility gap)

### Scenario 3: MUTED Ne Attacks
**Systems**: TCS, SE, ITD, Audio, HUD
**Trigger**: Ne (FLUX 8) has MUTED active (magnitude -5), selects basic_attack

1. Effective FLUX = max(1, 8-5) = 3 -> W = max(2, 3) = 3 frames (50ms)
2. PERFECT zone = max(1, floor(3 x 0.25)) = 1 frame (16ms)
3. **FLUX < 8 = ITD design constraint violation** (N-11, BLOCKING)
4. HUD PERFECT zone: single pixel sliver after MUTED narrowing formula
5. Audio: `sfx_ne_attack_muted` plays correctly via _muted variant routing

**Severity**: BLOCKING (N-11)

### Scenario 4: APEX Encounter Start -> Music + HUD Setup
**Systems**: TCS, Audio, HUD, ES
**Trigger**: Encounter with Mother Zarg starts

1. TCS emits `encounter_started(enemy_ids)`. Audio detects `is_apex = true`.
2. Audio calls `begin_combat_layer()` + `begin_apex_layers()` from same handler
3. **Call order not specified** -- CombatLayerPlayer may start slightly before ApexLayerPlayerA (phase drift)
4. HUD slide-in begins before `turn_order_changed` fires -- turn strip empty during 12-frame slide-in
5. `enemy_ids` vs `combatant_ids` naming inconsistency (N-08)

**Severity**: Warning (phase coordination), Info (turn strip timing, naming)

### Scenario 5: HP Danger Zone Entry
**Systems**: TCS, Audio, HUD, SE
**Trigger**: Ne HP drops from 35% to 20% (below 25% danger threshold)

1. TCS emits `hp_changed` + `hp_danger_zone_entered` same frame
2. Emission order undocumented -- HUD bar update vs audio tone sequencing depends on order
3. HUD: Danger Red transition. Audio: PROTECTED-tier HP danger tone.
4. If Ne is simultaneously MUTED: four stress signals converge (Danger Red + MUTED badge + HP tone + narrow window)

**Severity**: Info (emission order), Info (stress convergence)

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| timing-combat-system.md | N-01 (SE API), N-02 (round end), N-03 (notify_incapacitated), N-05 (cc_changed sig) | Consistency | Blocking |
| enemy-system.md | C-02r (GOOD->HIT, 8 locations), N-04 (sfx_incapacitated_id) | Consistency | Blocking |
| status-effects.md | N-10 (QUICKEN language), N-11 (MUTED FLUX floor) | Consistency + Design | Blocking |
| hud-system.md | N-05 (cc_changed 1->3 param), N-09 (status_effect_expired cause) | Consistency | Blocking |
| audio-system.md | N-08 (encounter_started param name) | Consistency | Warning |
| dialogue-system.md | W-07 (header status "In Design" vs index "Approved") | Consistency | Warning |

---

## Required Actions Before Architecture (Blocking)

In priority order:

1. **ES grade vocabulary** (C-02r) -- Replace GOOD with HIT in 8 locations in enemy-system.md. Mechanical edit.
2. **TCS SE interface update** (N-01, N-02, N-03) -- Fix `get_active_effects` -> `get_active_effect_ids`, correct round-end tick, add `notify_incapacitated()`. Three targeted edits.
3. **ES EnemyData schema** (N-04) -- Add `sfx_incapacitated_id: StringName` field. One-line addition.
4. **HUD cc_changed signature** (N-05) -- Update subscription to 3-param form. One edit.
5. **QUICKEN + TPR resolution** (N-10) -- Design decision required: next-round-only or mid-round recalc. Update SE + TCS.
6. **MUTED FLUX floor** (N-11) -- Design decision required: define effective FLUX floor or cap MUTED magnitude. Update SE + ITD/CSG.
7. **Resolve TCS OQ-2** (B-01) -- Design decision required: define refund_cc_on_miss policy for inherited abilities.

Items 1-4 are mechanical edits (no design decisions needed; ~5 minutes total).
Items 5-7 require user design decisions.

---

---

## Addendum: Blocker Resolution (2026-05-04, same session)

All 8 blocking issues were resolved immediately after the initial report:

| ID | Resolution | GDD Modified |
|----|-----------|-------------|
| C-02r | GOOD replaced with HIT (all instances) | enemy-system.md |
| N-01 | `get_active_effects` -> `get_active_effect_ids` | timing-combat-system.md |
| N-02 | Round-end tick corrected to "no-op at MVP" | timing-combat-system.md |
| N-03 | `notify_incapacitated()` added to SE interface | timing-combat-system.md |
| N-04 | `sfx_incapacitated_id` added to EnemyData schema | enemy-system.md |
| N-05 | `cc_changed` updated to 3-param form | hud-system.md |
| N-10 | QUICKEN catalogue: "takes effect at next ROUND_START" | status-effects.md |
| N-11 | MUTED FLUX floor: `EFFECTIVE_FLUX_FLOOR = 8` added | status-effects.md |
| B-01 | Already resolved in TCS RP4 (OQ-2 confirmed 2026-04-30) | (no change needed) |

**Revised verdict: CONCERNS** -- 0 blockers, 12 warnings remain (advisory).

---

*Report generated by `/review-all-gdds` (full mode) -- Consistency agent: systems-designer -- Design theory agent: game-designer -- Scenarios: game-designer*

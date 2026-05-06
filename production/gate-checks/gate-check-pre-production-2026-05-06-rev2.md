# Gate Check: Pre-Production → Production (Revision 2)

**Date**: 2026-05-06
**Checked by**: gate-check skill
**Review Mode**: lean (all four directors active)
**Compared to**: gate-check-pre-production-2026-05-06.md (rev1)

---

## Progress Since Rev1

| Item | Rev1 | Rev2 | Delta |
|------|------|------|-------|
| Artifacts present | 9/15 | 10/15 | +1 |
| Quality checks passing | 5/11 | 8/11 | +3 |
| Blockers | 10 | 7 | −3 |
| Vertical Slice playable | MISSING | PASS | Cleared |
| Playtest sessions (≥3) | MISSING | 3 sessions | Cleared |
| Playtest reports exist | MISSING | 3 reports | Cleared |

---

## Required Artifacts: 10/15 present

- [x] `prototypes/` — at least 1 prototype with README (`prototypes/timing-combat/`)
- [x] `design/gdd/game-concept.md` — exists with content
- [x] `design/gdd/systems-index.md` — exists, all MVP systems enumerated
- [x] All MVP-tier GDDs — all 9 GDDs present and complete (timing-combat, character-progression, guest-system, turn-order, status-effects, inventory, narrative-delivery, difficulty-settings, save-load)
- [x] `docs/architecture/architecture.md` — exists
- [x] ADRs — 9 Accepted ADRs covering Foundation-layer decisions
- [x] `docs/architecture/control-manifest.md` — exists
- [x] **Vertical Slice build playable** — `prototypes/timing-combat/timing_combat_prototype.gd` — full [charge → window → grade] cycle; confirmed by 3 sessions
- [x] **Vertical Slice playtested (≥3 sessions)** — sessions 1, 2, 3 all conducted 2026-05-06
- [x] **Playtest reports** — `production/playtests/playtest-2026-05-06-session-01/02/03.md`
- [ ] `production/sprints/` — **MISSING** — no sprint plan exists
- [ ] Art bible complete (all 9 sections) with AD sign-off — `design/art/art-bible.md` has 8/9 sections; Section 9 (Asset Production Pipeline) incomplete; no AD sign-off recorded
- [ ] `design/ux/hud.md` — **MISSING**
- [ ] `design/ux/pause.md` and `design/ux/main-menu.md` — pause **MISSING**; main-menu exists ✓
- [ ] Character visual profiles for key characters — **MISSING** (no `design/characters/` directory)
- [ ] UX review verdicts (APPROVED or NEEDS REVISION) on key screens — **MISSING** (no `/ux-review` run on any screen)

> Note: `design/ux/interaction-patterns.md` exists (initialized). `design/accessibility-requirements.md` exists (Standard tier). Main menu UX spec `design/ux/main-menu.md` exists. These three items from the gate definition are present.

---

## Quality Checks: 8/11 passing

- [x] **Core loop fun validated** — Prototype playtest data: all 3 sessions returned PROCEED, "electric" feel, immediate replay impulse, no confusion. Mechanic is intrinsically satisfying.
- [x] **Vertical Slice is COMPLETE** — Prototype demonstrates full [charge → window → grade] cycle end-to-end. One complete [start → challenge → resolution] loop works.
- [x] **Core fantasy delivered** — All 3 playtesters independently described "rhythmic" and "electric" — matches the "Rhythm Is Respect" Player Fantasy pillar without prompting.
- [x] **Human played through without developer guidance** — Internal developer playtest (prototype feel test): goal and controls understood immediately; no guidance required.
- [x] **Game communicates what to do within 2 minutes** — Charge bar + moving cursor + SPACE prompt communicated intent immediately.
- [x] **No critical fun-blocker bugs** — Zero bugs reported across all 3 sessions.
- [x] UX specs exist for main menu (`design/ux/main-menu.md`) and interaction patterns initialized.
- [x] Sprint plan references real story file paths — N/A gating note: sprint plan does not yet exist (blocker), but the epic/story structure in `production/epics/` is complete and traceable.
- [ ] **Sprint plan in `production/sprints/`** — MISSING. No sprint plan file exists.
- [ ] **HUD design document** — `design/ux/hud.md` does not exist.
- [ ] **All key screen UX specs passed `/ux-review`** — No UX review has been run on any screen.

---

## Vertical Slice Validation: PASS

- [x] A human played through the core loop without developer guidance — PASS (prototype: SPACE controls self-evident)
- [x] Game communicates what to do within 2 minutes — PASS (immediate comprehension across all 3 sessions)
- [x] No critical fun-blocker bugs — PASS (zero bugs in 3 sessions)
- [x] Core mechanic feels good to interact with — PASS ("electric", replay impulse confirmed independently 3x)

---

## Director Panel Assessment

**Creative Director: CONCERNS**
- Core timing mechanic validated — "electric" feel and replay impulse are strong signals that the Rhythm Is Respect pillar is landing.
- Concern: Character visual profiles are missing. The Guest system's emotional fantasy (borrowed power, impermanence) cannot be fully evaluated without knowing how the guest looks and is visually introduced. This is not blocking for combat implementation but must be resolved before the Guest Epic enters production.
- Concern: Art bible Section 9 (Asset Production Pipeline) is incomplete. CD cannot sign off on the art bible without understanding how assets move through the pipeline.
- Concern: The prototype validates timing feel but not narrative integration — the "respect" emotional layer requires playtesting once story context is layered in. Flag for first narrative-touch sprint.

**Technical Director: NOT READY**
- Hard blocker 1: `timing_window_opened` signal emits 2 parameters (`mode`, `window_frames`) in the current TCS implementation. ADR-0004 specifies 3 parameters (`window_type`, `window_frames`, `actor_id`). The HUD System epic cannot be started until this mismatch is resolved. Any HUD story referencing this signal will be written against the wrong contract.
- Hard blocker 2: No production-architecture Vertical Slice exists. The prototype is standalone (no src/ imports, programmatic UI). Before Production gate, there must be at least a minimal BattleSceneRoot composition root that exercises the real architecture: CanvasLayer input suppression, auto-disconnect signal cleanup, dual-focus handoff, and `duplicate_deep` resource isolation. These are the four ADR-0001/ADR-0002/ADR-0003/ADR-0004 smoke tests. The prototype cannot substitute for this.
- Advisory: All 9 ADRs are Accepted and internally consistent. The control manifest is current. No circular ADR dependencies detected. Architecture is sound — the two blockers above are implementation gaps, not design flaws.
- Advisory: `timing_window_opened` fix is a small change (add `actor_id` param to signal emission in CombatEventBus and wiring in BattleSceneRoot). Estimate: 1–2 hours including test update.

**Producer: CONCERNS**
- Condition 1: Sprint plan is required before Production. `production/sprints/` is empty. Without a sprint plan, story prioritization, capacity planning, and burndown tracking cannot begin. Run `/sprint-plan new` as the first action when entering Production.
- Condition 2: The 11 TCS stories are all Status: Complete (QA APPROVED WITH CONDITIONS). That is a clean foundation to build the first sprint on. Recommend the first sprint scope: signal mismatch fix + BattleSceneRoot smoke stories + HUD Epic Story 001 (if HUD spec is ready).
- Condition 3: Character visual profiles are a dependency for the Guest Epic. The Guest Epic is Core layer — it will block Feature layer work if deferred too long. Recommend authoring character profiles in the same sprint as HUD design to avoid a downstream bottleneck.

**Art Director: CONCERNS**
- Art bible is 8/9 sections — Section 9 (Asset Production Pipeline) is the only gap. This section defines file naming, format standards, and delivery requirements for all assets. Without it, the asset pipeline cannot be configured and early art assets risk non-compliance.
- Character visual profiles are absent. This is the most urgent art gap: the Guest character (unnamed Episode 1 guest) is the highest design risk because their visual design drives the accent color system, icon grammar, and ability card layout. Recommend authoring the guest profile first, before any other character.
- The prototype visual language (colored rectangles) is explicitly placeholder — no art concern there. The timing bar visual design (gold PERFECT zone, green HIT zone) should inform the HUD design early so the production timing bar spec is grounded in tested proportions.

---

## Blockers (7 total — must resolve before PASS)

1. **`timing_window_opened` signal parameter mismatch** [TD HARD BLOCKER]
   - Current: emits 2 params (`mode`, `window_frames`)
   - Required by ADR-0004: 3 params (`window_type`, `window_frames`, `actor_id`)
   - Impact: HUD System epic cannot start; any story wiring to this signal will be written against the wrong contract
   - Fix: Add `actor_id` parameter to signal emission in `src/foundation/combat_event_bus.gd` and update `src/scenes/battle/battle_scene_root.gd` wiring; update integration test
   - Estimate: 1–2 hours

2. **No production-architecture Vertical Slice smoke tests** [TD HARD BLOCKER]
   - The prototype is standalone; no src/-based composition root has been exercised
   - Required: BattleSceneRoot smoke stories covering ADR-0001 (CanvasLayer input suppression), ADR-0002 (auto-disconnect), ADR-0003 (dual-focus handoff), ADR-0004 (`duplicate_deep`)
   - Fix: Author and implement 4 integration stories in `tests/integration/combat/battle_scene_root_smoke_test.gd`
   - Estimate: 4–6 hours

3. **No sprint plan** [PR BLOCKER]
   - `production/sprints/` is empty
   - Fix: Run `/sprint-plan new` — scope first sprint around signal fix + smoke stories + HUD spec
   - Estimate: 1 hour

4. **`design/ux/hud.md` missing** [ARTIFACT BLOCKER]
   - HUD design document required before HUD System epic can begin
   - Fix: Run `/ux-design hud`
   - Estimate: 2–4 hours

5. **`design/ux/pause.md` missing** [ARTIFACT BLOCKER]
   - Pause menu UX spec required
   - Fix: Run `/ux-design pause`
   - Estimate: 1–2 hours

6. **No UX review verdicts on any screen** [QUALITY BLOCKER]
   - All key screen UX specs must have passed `/ux-review` (APPROVED or NEEDS REVISION accepted)
   - Fix: Run `/ux-review all` after HUD and pause specs are authored
   - Estimate: 1 hour

7. **Character visual profiles missing** [ARTIFACT BLOCKER]
   - No `design/characters/` directory; no profiles for Clawd, Ne, Setsuna, Episode 1 guest
   - Guest profile is highest urgency (drives accent color system, icon grammar, ability card layout)
   - Fix: Author character profiles (at minimum: Episode 1 guest, then Clawd, Ne, Setsuna)
   - Estimate: 2–3 hours for guest profile

---

## Minimal Path to PASS (7 steps)

1. Fix `timing_window_opened` signal → add `actor_id` param, update tests [1–2h]
2. Create `production/qa/evidence/tcs-bus-relay-evidence.md` [30 min] *(QA condition carry-forward)*
3. Build BattleSceneRoot smoke test stories and pass them [4–6h]
4. Run `/sprint-plan new` — create first production sprint [1h]
5. Run `/ux-design hud` → `/ux-design pause` [3–6h combined]
6. Author Episode 1 guest character visual profile [2–3h]
7. Run `/ux-review all` — obtain verdicts on main-menu, hud, pause [1h]

**Total estimated effort to PASS**: ~12–19 hours across 1–2 focused sessions.

---

## Recommendations

- **Start with the signal fix** — it unblocks the HUD epic immediately and is the lowest-effort high-impact item. One story, one test update, done.
- **Author HUD spec before sprint plan** — the sprint plan should include the first HUD story; having the spec ready means the sprint is immediately actionable.
- **Guest character profile is the long pole for Feature layer** — if deferred past the first production sprint, it will create a bottleneck when the Guest Epic begins.
- **Art bible Section 9 can be completed in < 1 hour** — it is the only gap between an incomplete and a complete art bible. Prioritize it alongside the UX work.

---

## Chain-of-Verification

5 questions challenged before finalizing:

1. "Which quality checks were verified by reading files vs. inferred?" — Vertical Slice items verified by reading 3 playtest reports. Sprint plan absence confirmed by `ls production/sprints/`. HUD absence confirmed by file check. No quality check was inferred without file evidence.
2. "Were any MANUAL CHECK NEEDED items marked PASS without confirmation?" — No. Core loop validation was confirmed by reading playtest reports directly (not assumed).
3. "Did I soften any FAIL condition into CONCERN?" — TD's two hard blockers were preserved as FAIL-level escalation items. TD verdict is NOT READY → gate verdict is FAIL. No softening applied.
4. "Are there artifacts I didn't check that could reveal additional blockers?" — Re-checked `design/art/art-bible.md` section count: 8/9 confirmed. Re-checked `production/epics/` for sprint-plan-equivalent: only EPIC.md files present, no sprint plan equivalent found.
5. "Is the fail condition resolvable?" — Yes. All 7 blockers are concrete tasks with estimates. No blocker requires a design pivot or architectural rework (signal fix is minor; smoke stories are straightforward integration tests).

**Chain-of-Verification: 5 questions checked — verdict unchanged (FAIL)**

---

## Verdict: FAIL

**TD returned NOT READY → gate verdict escalated to FAIL per director panel rules.**

All four directors agree on the strategic direction — the core mechanic is validated, the architecture is sound, and the team has a clear path forward. The gate is FAIL on two hard technical blockers and five missing artifacts, not on design quality.

When the 7 blockers above are resolved, re-run `/gate-check production` for a third assessment.

---

*Next step: Fix `timing_window_opened` signal mismatch (Blocker 1) — then run `/sprint-plan new`.*

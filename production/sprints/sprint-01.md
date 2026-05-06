# Sprint 1 — 2026-05-06 to 2026-05-20

## Sprint Goal
Clear the remaining Pre-Production → Production gate blockers and lay the design foundation for the next three implementation epics.

## Capacity
- Total days: 14
- Buffer (20%): 3 days reserved for unplanned work
- Available: 11 days

---

## Tasks

### Must Have (Gate Blockers — all 5 block the Production gate)

| ID | Task | Owner | Est. | Story File | Acceptance Criteria |
|----|------|-------|------|------------|---------------------|
| S1-01 | **BattleSceneRoot ADR Smoke Tests** — Author + implement 4 integration tests covering ADR-0001 (CanvasLayer input suppression), ADR-0002 (auto-disconnect on node free), ADR-0003 (dual-focus handoff), ADR-0004 (duplicate_deep resource isolation). Tests live in `tests/integration/combat/battle_scene_root_smoke_test.gd`. | engine-programmer | 1.5 days | `production/epics/timing-combat-system/story-012-bsr-adr-smoke-tests.md` | 4 integration tests pass headlessly; no engine errors; all 4 ADR guarantees covered |
| S1-02 | **HUD UX Spec** — Run `/ux-design hud`. Author `design/ux/hud.md` covering HUD philosophy, information architecture (all MVP GDD UI Requirements), layout zones, element specs, states by gameplay context, visual budget. | ux-designer | 1 day | `design/ux/hud.md` | All GDD UI Requirements covered; `/ux-review hud` verdict recorded (APPROVED or NEEDS REVISION) |
| S1-03 | **Pause Menu UX Spec** — Run `/ux-design pause`. Author `design/ux/pause.md`. | ux-designer | 0.5 days | `design/ux/pause.md` | Spec covers pause states, resume/quit flow, input map; `/ux-review pause` verdict recorded |
| S1-04 | **Episode 1 Guest Character Visual Profile** — Author `design/characters/guest-ep1.md` covering visual identity, accent color, icon grammar, ability card layout, emotion palette. Required before HUD System and Guest epic can begin. | art-director | 0.75 days | `design/characters/guest-ep1.md` | Profile includes: visual concept, accent color (hex + usage rules), icon grammar, ability card layout reference; AD review recorded |
| S1-05 | **UX Review — All Key Screens** — Run `/ux-review all` on `main-menu.md`, `hud.md`, `pause.md`. Obtain APPROVED or NEEDS REVISION verdict on each. | qa-lead | 0.25 days | Verdicts recorded in each spec file | All 3 screens have a review verdict; no MAJOR REVISION NEEDED |

### Should Have

| ID | Task | Owner | Est. | Story File | Acceptance Criteria |
|----|------|-------|------|------------|---------------------|
| S1-06 | **Art Bible Section 9** — Complete `design/art/art-bible.md` Section 9 (Asset Production Pipeline): file naming conventions, format standards, delivery requirements. Required for art bible AD sign-off. | art-director | 0.25 days | `design/art/art-bible.md` | Section 9 complete; AD sign-off verdict recorded in art-bible.md |
| S1-07 | **Create Ability System Stories** — Run `/create-stories ability-system`. Break the AS epic into implementable stories with embedded GDD requirements, ADR guidance, and QA test cases. | game-designer | 0.5 days | `production/epics/ability-system/story-*.md` | Stories written; all have Story Type, TR-ID, and Test Evidence sections |
| S1-08 | **Create Story State & Flag System Stories** — Run `/create-stories story-state-flag-system`. | game-designer | 0.5 days | `production/epics/story-state-flag-system/story-*.md` | Stories written with TR-IDs and test evidence |

### Nice to Have

| ID | Task | Owner | Est. | Story File | Acceptance Criteria |
|----|------|-------|------|------------|---------------------|
| S1-09 | **Ability System Story 001** — Implement first AS story once stories are created (S1-07). | gameplay-programmer | 1 day | First story from S1-07 | Story 001 implemented, tests pass, `/story-done` complete |
| S1-10 | **Character Visual Profiles — Core Party** — Author `design/characters/clawd.md`, `ne.md`, `setsuna.md`. Lower urgency than guest but needed before character art begins. | art-director | 0.75 days | `design/characters/{clawd,ne,setsuna}.md` | Each profile: visual concept, color palette, distinguishing silhouette notes |

---

## Carryover from Previous Sprint
None — Sprint 1 is the first sprint.

---

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| BattleSceneRoot smoke tests reveal ADR-0003 CanvasLayer `set_process_input()` failure mode | Medium | High — requires ADR fallback implementation | ADR-0003 documents the fallback; implement immediately if smoke test fails |
| HUD spec scope grows beyond 1 day (9 GDD UI Requirements is substantial) | Medium | Medium — delays UX review | Timebox to 1 day; defer non-MVP HUD elements to Sprint 2 |
| Guest character profile requires narrative consultation | Low | Low — profile can be iterated | Start with visual-only placeholder; lock accent color first (highest dependency) |

---

## Dependencies on External Factors
- Gate check rev3 cannot run until S1-01 through S1-05 are all complete
- HUD System epic stories cannot be created until S1-02 (HUD spec) and S1-05 (UX review) are done
- Ability System implementation (S1-09) depends on S1-07 (stories created first)

---

## Definition of Done for Sprint 1
- [ ] All Must Have tasks (S1-01 through S1-05) completed and verified
- [ ] BattleSceneRoot smoke test: 4 integration tests pass headlessly
- [ ] `design/ux/hud.md` and `design/ux/pause.md` exist with UX review verdicts
- [ ] `design/characters/guest-ep1.md` exists with AD review note
- [ ] QA plan for this sprint exists (`production/qa/qa-plan-sprint-1-2026-05-06.md`)
- [ ] `/gate-check production` rev3 returns PASS
- [ ] No S1 or S2 bugs in delivered work

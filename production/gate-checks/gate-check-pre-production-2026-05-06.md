# Gate Check: Pre-Production → Production

**Date**: 2026-05-06
**Checked by**: gate-check skill
**Review mode**: lean (directors ran — this is a phase gate)
**Current stage**: Pre-Production
**Verdict**: FAIL

---

## Required Artifacts: 9/15 present

- [x] `production/epics/` — Foundation + Core layer epics present (9 epics: input-and-timing-detection, character-stats-and-growth, ability-system, status-effects, party-composition-manager, story-state-flag-system, audio-system, timing-combat-system, dialogue-system)
- [x] All MVP-tier GDDs complete — 9/9 approved (TCS, ITD, Ability, Enemy, Status Effects, PCM, Character Stats, Audio, HUD)
- [x] `docs/architecture/architecture.md` — exists, content confirmed
- [x] 3+ Foundation-layer ADRs — 16 ADRs confirmed (ADR-0001–0011, ADR-0014–0016)
- [x] `docs/architecture/control-manifest.md` — exists
- [x] `design/art/art-bible.md` — 9 sections confirmed; AD-ART-BIBLE sign-off skipped (lean mode); accepted — this gate verdict serves as AD sign-off
- [x] `design/ux/main-menu.md` — exists; **Status: "In Design" — not reviewed**
- [x] `/architecture-review` run — `docs/architecture/architecture-review-2026-05-04.md` exists
- [x] Epics defined (Foundation + Core) — present
- [ ] At least 1 prototype in `prototypes/` with README — **MISSING**
- [ ] First sprint plan in `production/sprints/` — **MISSING**
- [ ] Character visual profiles for key characters — **MISSING** (no `design/characters/` or `design/art/characters/`)
- [ ] Vertical Slice build (playable, not just scoped) — **MISSING**
- [ ] 3+ playtest sessions documented — **MISSING** (0 sessions; `production/playtests/` does not exist)
- [ ] UX specs for main menu, core gameplay HUD, pause menu — **PARTIAL**: `design/ux/hud.md` and `design/ux/pause.md` both missing; main menu is In Design only
- [ ] HUD design document at `design/ux/hud.md` — **MISSING**
- [ ] All key screen UX specs passed `/ux-review` — **MISSING** (no review verdicts anywhere)

---

## Quality Checks: 5/11 passing

- [x] Architecture document — Foundation layer open questions resolved
- [x] All ADRs have Engine Compatibility sections with engine version stamped
- [x] All ADRs have ADR Dependencies sections
- [x] No S1/S2 bugs (QA sign-off APPROVED WITH CONDITIONS — 0 bugs)
- [x] CI/CD pipeline operational — GdUnit4 GitHub Actions workflow confirmed
- [ ] Core loop fun is validated — FAIL: no playtest data exists
- [ ] UX specs cover all UI Requirements from MVP GDDs — FAIL: HUD spec missing
- [ ] Vertical Slice is COMPLETE — FAIL: no playable build
- [ ] A human has played the core loop without developer guidance — FAIL: no evidence
- [ ] Core fantasy delivered (playtester independently described it) — FAIL: 0 sessions
- [ ] Tests passing — ADVISORY: developer-confirmed 137 passing; Godot binary not on PATH in shell

---

## Director Panel Assessment

**Creative Director**: CONCERNS
> Pillar 2 (Rhythm Is Respect) is the strongest — implemented, tested, proven. Pillars 3 and 4 designed at the seam level but unvalidated; the guest departure experience has never been prototyped or playtested. Pillar 4 (The World Has Memory) is entirely aspirational — no system, GDD, or prototype addresses it. Companion half of the core fantasy is unvalidated. Also flagged: Audio System file header reads "In Revision" while systems index says "Approved" — metadata inconsistency must be resolved.

**Technical Director**: CONCERNS
> Architecture is excellent — 96% traceability coverage, topologically sound ADR dependency order, CI operational, 11 source files and 21 test files passing. Two HIGH concerns: (1) `timing_window_opened` 2-vs-3 parameter mismatch with ADR-0004 — must be resolved before any HUD story; (2) no playable build means engine-specific assumptions (CanvasLayer input suppression, dual-focus, set_process_input recursive) are unvalidated. Recommends a 2-week Vertical Slice sprint before Production entry, running all 4 ADR smoke tests.

**Producer**: NOT READY
> 9 of 15 gate requirements met; 6 missing, all blocking. Vertical Slice cannot be skipped — paper designs frequently fail when implemented; scope corrections in Production are 10x more expensive than in Pre-Production. Estimated path: 14–21 sessions to clear all blockers. Critical path: scope VS → build VS → playtest × 3 → sprint plan.

**Art Director**: CONCERNS
> Art bible quality is genuinely strong — it is a directive instrument, not a checklist; accepted as formal sign-off replacing the lean-mode-skipped AD-ART-BIBLE gate. Two concerns: (1) no character visual profiles — the first sprite commission will have no prior document to review against; (2) HUD and pause UX specs missing — art bible Section 7 gives visual language but UX spec defines the structure it hangs on. Also flagged 3 unresolved art-direction questions in `design/ux/main-menu.md` that must be resolved before main menu implementation.

**Escalation applied**: Producer returned NOT READY → overall panel verdict is NOT READY → gate verdict is FAIL.

---

## Blockers (must resolve before PASS)

### Vertical Slice (highest priority — critical path)
1. **No prototype / playable build** — `prototypes/` is empty. Run `/prototype timing-combat` to build the timing combat vertical slice. Does not require art — placeholder geometry is sufficient to validate engine behavior and timing feel.
2. **No Vertical Slice playtests** — 0 of 3 required sessions exist. After the prototype is playable, run 3 internal playtests and document via `/playtest-report`.
3. **No playtest report in `production/playtests/`** — required before advancing.

### Planning
4. **No sprint plan** — `production/sprints/` is empty. Run `/sprint-plan new` after Vertical Slice is validated.

### UX
5. **HUD design document missing** — `design/ux/hud.md` does not exist. Required before HUD System epic begins. Run `/ux-design hud`.
6. **Pause menu UX spec missing** — `design/ux/pause.md` does not exist. Run `/ux-design pause`.
7. **No UX review verdicts** — `main-menu.md` is "In Design"; none of the three required key screens have passed `/ux-review`. Run `/ux-review all` once HUD and pause specs are authored.

### Art
8. **No character visual profiles** — Clawd, Ne, Setsuna, and the Episode 1 guest have no visual profiles. Guest profile must be completed before first character sprite is commissioned; core party profiles must precede first LOD submission review.

### QA sign-off carry-forwards (from TCS epic — required before downstream epics)
9. **`timing_window_opened` parameter mismatch** — implementation emits 2 params; ADR-0004 specifies 3 (`window_type`, `window_frames`, `actor_id`). Either update the implementation or formally amend ADR-0004. Must be resolved before any HUD story consumes this signal.
10. **`production/qa/evidence/tcs-bus-relay-evidence.md` missing** — Scene-level Godot auto-disconnect verification not documented. Must exist before HUD/Audio epics begin.

---

## Recommendations

The project's design and architecture foundation is genuinely strong. This is not a design failure — it is a pre-validation gap. The path to clearing this gate is well-defined:

| Step | Action | Resolves |
|------|--------|---------|
| 1 | `/prototype timing-combat` — build minimal playable combat encounter | Blockers 1, 2, 3 |
| 2 | Run 3 internal playtests + `/playtest-report` | Blockers 2, 3 |
| 3 | `/ux-design hud` | Blocker 5 |
| 4 | `/ux-design pause` | Blocker 6 |
| 5 | `/ux-review all` | Blocker 7 |
| 6 | Create character visual profiles (4 characters) | Blocker 8 |
| 7 | Resolve `timing_window_opened` — backlog item + fix or ADR amendment | Blocker 9 |
| 8 | Create `production/qa/evidence/tcs-bus-relay-evidence.md` | Blocker 10 |
| 9 | `/sprint-plan new` after VS learnings | Blocker 4 |
| 10 | `/gate-check production` | Re-run this gate |

Steps 3–8 can run in parallel with Steps 1–2.

---

## What Is Already Production-Grade

- **9/9 MVP GDDs approved** — all 8 required sections, revision passes completed
- **16 ADRs** — Accepted, dependency-ordered, engine-stamped
- **137 passing tests** — deterministic, GdUnit4, CI-gated
- **Architecture traceability: 96%** — 47/49 requirements covered
- **Art bible** — directive-quality, all 9 sections; accepted as formal AD sign-off
- **QA infrastructure** — qa-plan, smoke-check, team-qa, sign-off reports operational
- **9 epics defined** — Foundation + Core + Feature layers scoped

---

## Next Step

Do not advance `production/stage.txt` to Production. Run `/prototype timing-combat` as the immediate next action.

Re-run `/gate-check production` once all 10 blockers are resolved.

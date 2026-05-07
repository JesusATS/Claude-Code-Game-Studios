# Review Log — Enemy System GDD

---

## Approved — 2026-04-29

User accepted Revision Pass 3 revisions and marked Enemy System GDD as APPROVED. No further re-review conducted. 107 total ACs. All 4 prior review passes' blockers resolved.

---

## Review — 2026-04-29 — Verdict: NEEDS REVISION (Revision Pass 3 applied in-session)

Scope signal: XL
Specialists: game-designer, systems-designer, ai-programmer, qa-lead, audio-director, godot-specialist, ux-designer, creative-director
Blocking items: 5 resolved in-session | Recommended: 10 resolved in-session
Summary: Fourth review cycle. Five blockers identified and resolved: (1) Sectarian Leader first-half flatness (above 50% HP + MUTED active → basic_attack spam) — resolved by adding void_surge as Rule 5 (`PARTY_STATUS_ACTIVE("muted") → USE_ABILITY("void_surge", HIGHEST_ATK)`); (2) Mother Zarg PRESSURED band flatness (50–75% HP = basic_attack) — resolved by lowering heat_coil threshold from SELF_HP_RATIO_ABOVE(0.75) to SELF_HP_RATIO_ABOVE(0.50); (3) bounce_barrage multi-window unspecified — resolved by adding Multi-Hit Ability Resolution rule to Core Rules (two independent windows, each resolved independently); (4) stinger routing required Audio System to query EnemyData.encounter_role (contradiction with Audio GDD non-dependency statement) — resolved by embedding `stinger_tier: StringName` in `enemy_condition_changed` signal payload; (5) Tutorial action balance table showed enemy_turns=1/ratio=4.0 — corrected to enemy_turns=2/ratio=2.0 (Boing-Boing earns double turns at SPD_min 11; documented exception). Ten recommended items also resolved: Player Fantasy fluency arc softened, WSF=0.6 worked-example table added, GRUNT→SKIRMISHER typo fixed, GRUNT→SKIRMISHER table, EC-1.3 NEAR_BREAKING label fix + D2/EC-1.3 authority note, AC-36/AC-37 off-by-one boundary fix (HP≥46→HP≥45), D4 stale "not yet authored" reference updated, void_surge added to animation/SFX/VFX tables, SFX typo infernstrike→infernostrike fixed, MOD(n) synchronization hazard note added. 8 new ACs added (AC-100 to AC-106 + AC-104): total now 107. Prior verdict resolved: Yes — all 4 Revision Pass 2 blockers confirmed resolved.

---

## Review — 2026-04-29 — Verdict: NEEDS REVISION (Revision Pass 2 applied in-session)

Scope signal: XL
Specialists: game-designer, systems-designer, ai-programmer, qa-lead, audio-director, godot-specialist, creative-director
Blocking items: 4 resolved in-session | Recommended: 10 | Nice-to-Have: 8
Summary: Third review. All 12 Revision Pass 1 blockers confirmed resolved. Four new blockers identified: (1) void_shriek targeted HIGHEST_FLUX, punishing rhythmic mastery in direct contradiction of Pillar 2 — resolved by changing target to RANDOM; (2) AC-31 precondition referenced eliminated dark_prayer_active marker — rewritten to use ALLY_STATUS_ABSENT(BRUISER, "resonance"); (3) OQ-6 cited AC-74/75 as BLOCKED instead of AC-95 — corrected; (4) Sectarian Rule 2 (PARTY_STATUS_ABSENT → curse_of_weakness) was behaviorally identical to Rule 4 (ALWAYS → curse_of_weakness) — Rule 2 removed, rules renumbered to 3-rule list, ACs updated. Key recommended items: Mother Zarg mid-phase flatness (50–75% HP = basic_attack spam), Sectarian Leader dominant-state gap (above 50% HP with MUTED active = no press-advantage rule), WSF=0.6 accessibility unanalyzed, Player Fantasy overpromises third-encounter fluency that Chapter 1 encounter count cannot deliver.
Prior verdict resolved: Yes — all 12 Revision Pass 1 blockers confirmed resolved

---

## Review — 2026-04-29 — Verdict: NEEDS REVISION (Revision Pass 1 applied in-session)

Scope signal: XL
Specialists: game-designer, systems-designer, godot-specialist, ux-designer, qa-lead, gameplay-programmer, audio-director, creative-director
Blocking items: 12 resolved in-session | Recommended: 4 resolved in-session
Summary: Re-review of Revision Pass 0 (14 blockers resolved 2026-04-28). Eight new blocking clusters identified: per-instance identity gap (EnemyData.id shared across two Boing-Boings, breaking TCS cache, signal routing, and Scan tracking — resolved by adding instance_id: int encounter-slot index and duplicate_deep() obligation); two cross-GDD UI contradictions with APPROVED HUD GDD (turn strip chip layout: "appear twice" vs. single chip with ×2 badge; INCAPACITATED panel/chip behavior — resolved by deferring to HUD GDD authority); WSF=1.6 floor calculation wrong by ~10 TEMPO (claimed TEMPO≥21 activates 2-frame floor; correct threshold is TEMPO≥31; no Episode 1 enemy affected — resolved); dark_prayer_active tracking marker schema-incompatible with Status Effects GDD (stat_affected=NONE and magnitude=0 both forbidden — resolved by restructuring Sectarian Rule 1 to use new ALLY_STATUS_ABSENT(BRUISER, "resonance") condition, eliminating the tracking marker entirely); PARTY_HP_RATIO_BELOW(RANDOM) already fixed in prior pass (confirmed LOWEST_HP in document); float vs. integer contradiction already consistent (EC-1.3 is recommendation, not contradiction); Tutorial encounter ratio 1.0 violates D3's Tutorial target 2.5–4.0 (resolved: Tutorial = 1× Boing-Boing, ratio 4.0; 2× Boing-Boing documented as exception); recursive ConditionExpr (Array[ConditionExpr]) unsupported in Godot 4.6 .tres serialization (resolved: flattened to single-predicate schema, AND compound form removed, ALLY_STATUS_ABSENT/ALLY_STATUS_ACTIVE added to condition table); AC-35 off-by-one (HP≤45 gives ratio 0.25 exactly, fails strictly-less-than — fixed to HP≤44); AC-27c target mode error (said LOWEST_HP, actual rule 2 is RANDOM — fixed); APEX audio spec gaps — idle ambient stem IDs and condition stinger trigger specs missing (resolved: added APEX Condition-State Ambient Stems table and Stinger Triggers table with explicit IDs and routing contract). Four recommended items also resolved: Sectarian Leader basic attack named (sectarian_leader_strike); duplicate_deep() obligation added to §5; AC-36 and AC-33 fixture preconditions tightened. AC count: 95+2 → 99. User accepted revisions in-session.
Prior verdict resolved: Yes — all 14 blockers from 2026-04-28 confirmed resolved

---

## Review — 2026-04-28 — Verdict: NEEDS REVISION (revised in-session)

Scope signal: L
Specialists: game-designer, systems-designer, economy-designer, ai-programmer, level-designer, audio-director, qa-lead, creative-director
Blocking items: 14 | Recommended: 4
Summary: Full adversarial review identified 14 blocking items spanning AI design errors (dark_prayer phantom status, final_invocation dead code, USE_ABILITY_RANDOM target mode mismatch), a composition rule violation (solo Sectarian in Chapter 1 intro), stat inconsistencies (Sectarian Leader TEMPO), formula boundary issues (AC HP thresholds), missing ConditionExpr AND syntax, audio architecture gaps (APEX adaptive music, fire_breath SFX split requirement), and under-specified acceptance criteria. All 14 blockers were resolved in-session following four user design decisions: Sectarian Leader TEMPO set to 24, final_invocation moved to HP < 25% trigger, dark_prayer_active registered as Status Effects tracking marker, Mother Zarg NEAR_BREAKING music changed to "desperate fire" direction. 9 new ACs added (AC-87 through AC-95 plus AC-27b/c). AC count revised from 86 to 95+2.
Prior verdict resolved: N/A — first review

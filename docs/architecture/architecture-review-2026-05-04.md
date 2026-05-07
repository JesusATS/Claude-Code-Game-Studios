# Architecture Review Report

**Date**: 2026-05-04
**Engine**: Godot 4.6 (Compatibility renderer)
**GDDs Reviewed**: 11 (9 MVP + 2 Vertical Slice)
**ADRs Reviewed**: 5 (ADR-0001 through ADR-0005, all Accepted)
**Reviewer**: /architecture-review (Opus)

---

## Traceability Summary

| Status | Count | % |
|--------|-------|---|
| Covered | 11 | 22% |
| Partial | 4 | 8% |
| Gap | 34 | 70% |
| **Total** | **49** | **100%** |

---

## Coverage Gaps (no ADR exists)

### Foundation Layer Gaps

- TR-CSG-002: CS&G -- effective_stat formula (base + NIO + status)
  Suggested ADR: `/architecture-decision effective stat computation`
  Domain: Foundation | Engine Risk: LOW

- TR-CSG-003: CS&G -- Window frame formulas (FLUX->attack, TEMPO->block)
  Suggested ADR: `/architecture-decision timing window frame computation`
  Domain: Foundation | Engine Risk: LOW

- TR-CSG-004: CS&G -- WINDOW_SCALE_FACTOR accessibility knob (0.6-1.6)
  Suggested ADR: (covered by ADR-0007 or ADR-0008 when written)
  Domain: Foundation | Engine Risk: LOW

- TR-ITD-001: ITD -- FSM: IDLE / ACTION_WINDOW / BLOCK_WINDOW / BLOCK_FORGIVENESS
  Suggested ADR: `/architecture-decision timing window frame computation`
  Domain: Foundation | Engine Risk: HIGH (dual-focus)

- TR-ITD-002: ITD -- Frame-precise input via _input() + _physics_process() at 60fps
  Suggested ADR: (same as above)
  Domain: Foundation | Engine Risk: HIGH

- TR-ITD-005: ITD -- force_close_window() public API
  Suggested ADR: (same as above)
  Domain: Foundation | Engine Risk: LOW

- TR-ITD-006: ITD -- inject_input() / advance_frame() test seam
  Suggested ADR: (same as above)
  Domain: Foundation | Engine Risk: LOW

- TR-AUD-001: Audio -- 5 pre-allocated AudioStreamPlayer nodes
  Suggested ADR: `/architecture-decision audio system architecture`
  Domain: Foundation | Engine Risk: LOW

- TR-AUD-002: Audio -- 2-tier SFX pool (PROTECTED/STANDARD), size=12
  Suggested ADR: (same as above)
  Domain: Foundation | Engine Risk: LOW

- TR-AUD-003: Audio -- play_sfx_delayed() via create_timer().timeout
  Suggested ADR: (same as above)
  Domain: Foundation | Engine Risk: LOW

### Core Layer Gaps

- TR-AS-002: AS -- resolve_ability() single-target contract
  Suggested ADR: (covered by ADR-0009 when written)
  Domain: Core | Engine Risk: LOW

- TR-AS-005: AS -- get_combo_state() / reset_encounter_state() APIs
  Suggested ADR: (covered by ADR-0009)
  Domain: Core | Engine Risk: LOW

- TR-AS-006: AS -- Inherited ability persistence from guest departures
  Suggested ADR: `/architecture-decision inherited ability guest departure`
  Domain: Feature | Engine Risk: LOW

- TR-SE-003: SE -- get_modifier() / tick_turn() / initialize_encounter() API
  Suggested ADR: `/architecture-decision status effect application contract`
  Domain: Core | Engine Risk: LOW

- TR-SE-004: SE -- CONNECT_DEFAULT for ability_resolved subscription
  Suggested ADR: (same as above)
  Domain: Core | Engine Risk: LOW

- TR-SE-006: SE -- EFFECTIVE_FLUX_FLOOR = 8 clamp
  Suggested ADR: `/architecture-decision effective stat computation`
  Domain: Core | Engine Risk: LOW

- TR-PCM-001: PCM -- 4-slot fixed registry (slots 1-3 core, slot 4 guest)
  Suggested ADR: `/architecture-decision party slot model`
  Domain: Core | Engine Risk: LOW

- TR-PCM-002: PCM -- get_active_combatants() returns shallow copy
  Suggested ADR: (same as above)
  Domain: Core | Engine Risk: LOW

- TR-PCM-003: PCM -- is_initialized() guard before any query
  Suggested ADR: (same as above)
  Domain: Core | Engine Risk: LOW

- TR-PCM-004: PCM -- get_party_snapshot() with String keys for JSON safety
  Suggested ADR: (same as above)
  Domain: Core | Engine Risk: LOW

- TR-PCM-005: PCM -- MAX_PARTY_SIZE = 4 project constant
  Suggested ADR: (same as above)
  Domain: Core | Engine Risk: LOW

### Feature Layer Gaps

- TR-TCS-001: TCS -- Full combat FSM (11 states)
  Suggested ADR: `/architecture-decision turn-based combat state machine`
  Domain: Feature | Engine Risk: LOW

- TR-TCS-002: TCS -- Orchestrates ITD, AS, ES, SE, PCM
  Suggested ADR: (same as above)
  Domain: Feature | Engine Risk: LOW

- TR-TCS-003: TCS -- Audio calls: begin/end combat_layer, apex_layers
  Suggested ADR: (same as above)
  Domain: Feature | Engine Risk: LOW

- TR-TCS-005: TCS -- force_close_window() before pause/cutscene
  Suggested ADR: (same as above)
  Domain: Feature | Engine Risk: LOW

- TR-TCS-006: TCS -- Enemy AI priority rule evaluation (first-match)
  Suggested ADR: `/architecture-decision enemy ai condition evaluation`
  Domain: Feature | Engine Risk: LOW

- TR-TCS-007: TCS -- HP mutation direct to CharacterData references
  Suggested ADR: `/architecture-decision party slot model`
  Domain: Feature | Engine Risk: LOW

- TR-ES-002: ES -- get_condition_state() derived lazily from HP ratio
  Suggested ADR: `/architecture-decision enemy ai condition evaluation`
  Domain: Feature A | Engine Risk: LOW

- TR-ES-004: ES -- get_exact_hp() locked behind scan_resolved
  Suggested ADR: (same as above)
  Domain: Feature A | Engine Risk: LOW

- TR-ES-005: ES -- Multi-hit: sequential independent block windows
  Suggested ADR: (same as above)
  Domain: Feature A | Engine Risk: LOW

### Presentation Layer Gaps

- TR-HUD-001: HUD -- CanvasLayer 10/11/12 with Node2D containers for modulate
  Suggested ADR: `/architecture-decision hud canvaslayer structure`
  Domain: Presentation | Engine Risk: HIGH (CanvasLayer has no modulate)

- TR-HUD-002: HUD -- Ratio-driven timing bar (frame tick)
  Suggested ADR: (same as above)
  Domain: Presentation | Engine Risk: LOW

---

## Cross-ADR Conflicts

### Conflict 1: ADR-0004 `status_effect_applied` Signal Signature Mismatch

**Type**: Integration contract
**ADR-0004 claims**: `status_effect_applied(combatant_id: StringName, effect_id: StringName, stacks: int)` -- 3 parameters
**Architecture.md / SE GDD claims**: `status_effect_applied(combatant_id, effect_id, turns_remaining, stat_delta_key, modifier_delta, is_refresh)` -- 6 parameters
**Impact**: HUD MUTED narrowing requires `stat_delta_key` and `modifier_delta`. Audio System requires `is_refresh` to suppress refresh SFX. ADR-0004's relay method cannot forward these fields.
**Resolution options**:
  1. Update ADR-0004 relay signature to match the 6-parameter SE GDD signal (recommended)
  2. Add a separate MUTED-specific signal (over-engineering)

### Conflict 2: ADR-0004 `status_effect_tick` Parameter Mismatch

**Type**: Integration contract
**ADR-0004 claims**: `status_effect_tick(combatant_id, effect_id, damage)` -- third param is `damage`
**Architecture.md claims**: `status_effect_tick(combatant_id, effect_id, turns_remaining)` -- third param is `turns_remaining`
**Impact**: HUD displays remaining turns countdown, not damage. Wrong parameter semantics.
**Resolution**: Update ADR-0004 third parameter to `turns_remaining: int`.

### Conflict 3: ADR-0004 `combatant_incapacitated` Missing Parameter

**Type**: Integration contract
**ADR-0004 claims**: `combatant_incapacitated(combatant_id: StringName)` -- 1 parameter
**Architecture.md claims**: `combatant_incapacitated(combatant_id: StringName, is_enemy: bool)` -- 2 parameters
**Impact**: Audio System needs `is_enemy` to route to enemy incapacitation SFX vs party incapacitation (silent at MVP).
**Resolution**: Add `is_enemy: bool` parameter to ADR-0004 relay.

### Conflict 4: ADR-0004 `encounter_started` Parameter Scope

**Type**: Integration contract
**ADR-0004 claims**: `encounter_started(combatant_ids: Array[StringName])` -- all combatants
**Architecture.md claims**: `encounter_started(enemy_ids: Array[StringName])` -- enemies only
**Impact**: Audio System uses this to detect APEX enemies. Parameter name and content scope disagree.
**Resolution**: Align on `enemy_ids` (architecture.md convention). ADR-0004 to update.

### Gap: ADR-0004 Missing 5 TCS Relay Signals

**Type**: Coverage gap
**Missing from bus**: `turn_order_changed`, `timing_window_opened`, `grade_resolved`, `cc_changed`, `scan_resolved`
**Impact**: HUD (persistent CanvasLayer) needs all 5 from TCS (scene-local). Without bus relays, HUD's Turn Order Strip, Timing Window Bar, Grade Flash, CC Bar, and Scan HP unlock cannot function.
**Resolution**: Add all 5 signals + relay methods to CombatEventBus. Specific signatures:
  - `turn_order_changed(ordered_ids: Array[StringName], active_id: StringName)`
  - `timing_window_opened(window_type: StringName, window_frames: int, actor_id: StringName)`
  - `grade_resolved(grade: StringName)`
  - `cc_changed(new_cc: int, delta: int, source_type: StringName)`
  - `scan_resolved(enemy_id: StringName)`

---

## ADR Dependency Order

### Recommended ADR Implementation Order (topologically sorted)

**Foundation (no dependencies):**
  1. ADR-0001: Data-Driven Resource Registry Pattern
  2. ADR-0005: RefCounted Class Naming and Typed Collections

**Depends on Foundation:**
  3. ADR-0002: Autoload Singleton Strategy (requires ADR-0001)
  4. ADR-0003: Input Routing Dual-Focus (requires ADR-0002)

**Depends on Foundation + Autoloads:**
  5. ADR-0004: Combat Event Signal Bus (requires ADR-0002, ADR-0003)

All 5 Foundation ADRs are Accepted with correct dependency ordering. No cycles detected. No unresolved dependencies among existing ADRs.

---

## GDD Revision Flags

No GDD revision flags -- all GDD assumptions are consistent with verified engine behaviour.

---

## Engine Compatibility Issues

### Engine Audit Results

**Engine**: Godot 4.6
**ADRs with Engine Compatibility section**: 5 / 5 total

**Deprecated API References**: None found.

**Stale Version References**: None found -- all 5 ADRs reference Godot 4.6.

**Post-Cutoff API Consistency**:
| API | ADRs | Version Required | Status |
|-----|------|-----------------|--------|
| `Dictionary[K, V]` typed syntax | ADR-0001, ADR-0005 | 4.4+ | Consistent |
| `duplicate_deep()` on Resources | ADR-0001, ADR-0005 | 4.5+ | Consistent -- smoke test documented |
| Dual-focus system (separate mouse/keyboard focus) | ADR-0003 | 4.6 | Consistent |
| `set_process_input()` recursive behavior | ADR-0003 | 4.5+ | Consistent |
| `@abstract` decorator | ADR-0005 (mentioned) | 4.5+ | Consistent |

**Post-Cutoff API Conflicts**: None.

### Engine Specialist Findings

A domain-expert godot-specialist review surfaced 3 additional issues:

**Finding 1 — ADR-0003 Rule 2 (HIGH)**: `set_process_input(false)` on a `CanvasLayer` may NOT suppress child `Control._gui_input()` calls. The 4.5 recursive disable applies to mouse filter, not `set_process_input()`. If the smoke test fails, timing windows are unprotected. ADR-0003 updated with fallback pattern. Smoke test must be first test written.

**Finding 2 — EnemyActionRule base class conflict (MEDIUM)**: ADR-0005 listed `EnemyActionRule extends RefCounted`; ADR-0001 uses it as `@export Array[Resource]`. These are incompatible — `RefCounted` instances cannot be authored in the Inspector or serialized to `.tres`. EnemyActionRule must extend `Resource`. Both ADRs updated.

**Finding 3 — ADR-0001 `duplicate(true)` (MEDIUM)**: Key Invariant 3 used the deprecated `resource.duplicate(true)` instead of `resource.duplicate_deep()`. Updated.

---

## Architecture Document Coverage

`docs/architecture/architecture.md` (v1.0, 2026-05-04):

- All 20 systems from `systems-index.md` appear in the layer map
- Data flow covers: player turn, enemy turn, save/load, initialization order
- API boundaries documented for all 11 approved GDD systems
- No orphaned architecture (no system in arch doc without a GDD counterpart)

**Stale sections requiring update**:
- ADR Audit section (line ~610): says "No ADRs exist yet" -- 5 ADRs now Accepted
- OQ-ARCH-001 (line ~406, ~821): listed as open -- resolved by ADR-0004
- OQ-ARCH-003 (line ~823): listed as open -- resolved by ADR-0004

---

## Verdict: CONCERNS

The 5 Foundation ADRs are complete, properly ordered, and engine-consistent. The architecture.md is comprehensive. All blocking issues identified during this review were resolved in-session (see below). 34 TR gaps remain but are expected at this stage and covered by the planned ADR-0006 through ADR-0016 roadmap.

### Issues Resolved In-Session

1. **ADR-0004 signal signature mismatches (4 conflicts)** -- FIXED. `encounter_started`, `combatant_incapacitated`, `status_effect_applied`, and `status_effect_tick` relay signatures corrected to match architecture.md contracts.
2. **ADR-0004 missing 5 relay signals** -- FIXED. `turn_order_changed`, `timing_window_opened`, `grade_resolved`, `cc_changed`, and `scan_resolved` added with relay methods and BattleSceneRoot wiring.
3. **ADR-0003 Rule 2 unverified (HIGH)** -- DOCUMENTED. `set_process_input(false)` on CanvasLayer may not suppress child `_gui_input()`. Fallback pattern (iterate Controls, set `MOUSE_FILTER_IGNORE`) added; smoke test required before any ITD/HUD story is closed.
4. **EnemyActionRule base class conflict (MEDIUM)** -- FIXED. ADR-0005 class list and ADR-0001 EnemyData schema updated; `EnemyActionRule` and `ConditionExpr` now correctly listed as `Resource` subclasses.
5. **ADR-0001 `duplicate(true)` deprecated (MEDIUM)** -- FIXED. Key Invariant 3 updated to `resource.duplicate_deep()`.

### Non-Blocking Concerns

6. **architecture.md stale sections** -- ADR Audit and Open Questions reference pre-ADR state; update OQ-ARCH-001/003 as resolved
7. **34 TR gaps** -- Expected at this stage; architecture.md roadmap (ADR-0006 through ADR-0016) covers all gaps; needed before their respective systems enter implementation

### Top 3 Immediate Actions

1. **Update architecture.md** -- Mark OQ-ARCH-001 and OQ-ARCH-003 as resolved; update ADR Audit section (now says "No ADRs exist yet")
2. **Write ADR-0006 (Combat State Machine)** -- Highest-impact gap; blocks all TCS stories
3. **Run `/test-setup`** -- Scaffold GUT framework and CI workflow (pre-production gate blocker)

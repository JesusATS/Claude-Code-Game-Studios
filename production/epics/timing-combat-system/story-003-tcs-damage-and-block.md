# Story 003: TCS Damage and Block Formulas — Attack Damage and Block Mitigation

> **Epic**: Timing Combat System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-05-04

## Context

**GDD**: `design/gdd/timing-combat-system.md`
**Requirement**: `TR-TCS-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Combat State Machine Architecture + ADR-0007: Effective Stat Computation
**ADR Decision Summary**: TCS owns damage computation and HP mutation. Attack formula: `floor(max(1, ATK_eff − DEF_eff) × damage_multiplier × grade_multiplier)`. MISS = 0 damage. Block mitigation: HIT = `floor(full_damage × 0.5)`, PERFECT = 0, MISS = full damage. TCS mutates party HP directly on CharacterData references (Rule 3). Enemy HP lives in TCS-owned `_enemy_hp` dictionary. CharacterStatsUtil (ADR-0007) is the static class providing effective stat values.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `maxi()` (int max) is preferred over `max()` for integer operations — available since Godot 4.0.

**Control Manifest Rules (Core / Feature Layer)**:
- Required: Typed collections in all public APIs
- Required: CharacterStatsUtil static methods for effective stat lookup — TCS does not reimplement stat logic
- Forbidden: No hardcoded gameplay values — `BLOCK_MITIGATION_FACTOR = 0.5` must be a constant or exported var

---

## Acceptance Criteria

*From GDD `design/gdd/timing-combat-system.md`, scoped to this story:*

**Attack Damage Formula:**
- [ ] **AC-8** — GIVEN Clawd (ATK 12) attacks Zarg (DEF 13) at HIT grade, WHEN damage resolves, THEN damage = 1 (floor applied after max(1, base)).
- [ ] **AC-9** — GIVEN Clawd (ATK 12) attacks Zarg (DEF 13) at PERFECT grade (PHM 1.3), WHEN damage resolves, THEN damage = 1 (floor(1 × 1.3) = 1).
- [ ] **AC-10** — GIVEN Ne (ATK 18) attacks Boing-Boing (DEF 4) at HIT grade, WHEN damage resolves, THEN damage = 14 (floor(max(1, 18−4) × 1.0) = floor(14)).
- [ ] **AC-11** — GIVEN Ne (ATK 18) attacks Boing-Boing (DEF 4) at PERFECT grade (PHM 1.6), WHEN damage resolves, THEN damage = 22 (floor(14 × 1.6) = floor(22.4) = 22).
- [ ] **AC-12** — GIVEN any attacker attacks at MISS grade, WHEN damage resolves, THEN damage = 0 regardless of ATK/DEF values.
- [ ] **AC-13** — GIVEN an attack where ATK_eff = DEF_eff (base damage = 0) at HIT grade, WHEN damage resolves, THEN damage = 1 (max(1, 0) × 1.0 = 1).

**Block Mitigation Formula:**
- [ ] **AC-14** — GIVEN an enemy deals 8 full_damage and the party blocks at HIT grade, WHEN mitigation resolves, THEN party receives 4 damage (floor(8 × 0.5)).
- [ ] **AC-15** — GIVEN an enemy deals 22 full_damage and the party blocks at PERFECT grade, WHEN mitigation resolves, THEN party receives 0 damage.
- [ ] **AC-16** — GIVEN an enemy deals 7 full_damage and the party blocks at HIT grade, WHEN mitigation resolves, THEN party receives 3 damage (floor(7 × 0.5) = floor(3.5) = 3).
- [ ] **AC-17** — GIVEN an enemy deals 8 full_damage and the party misses the block window, WHEN mitigation resolves, THEN party receives 8 damage (no reduction).

---

## Implementation Notes

*Derived from ADR-0006 (Rules 3, 7) and ADR-0007 Implementation Guidelines:*

### Attack Damage Formula

```gdscript
func _compute_attack_damage(
    atk_eff: int,
    def_eff: int,
    damage_multiplier: float,
    grade: StringName
) -> int:
    if grade == &"MISS":
        return 0
    var grade_multiplier: float = 1.0
    if grade == &"PERFECT":
        grade_multiplier = _get_phm(actor_id)
    return floori(maxf(1.0, float(atk_eff - def_eff)) * damage_multiplier * grade_multiplier)
```

**Critical**: `max(1, base)` is applied BEFORE `grade_multiplier`. `floor()` is applied to the ENTIRE product — never to intermediate results.

### Block Mitigation Formula

```gdscript
const BLOCK_MITIGATION_FACTOR: float = 0.5  # Tuning knob — exported var in production

func _compute_block_damage(full_damage: int, grade: StringName) -> int:
    match grade:
        &"PERFECT": return 0
        &"HIT":     return floori(float(full_damage) * BLOCK_MITIGATION_FACTOR)
        _:          return full_damage  # MISS = no reduction
```

### HP Mutation (ADR-0006 Rule 3)

**Party HP** — mutate directly on CharacterData reference:
```gdscript
func _apply_damage_to_party_member(member: CharacterData, amount: int) -> void:
    var old_hp: int = member.hp
    member.hp = maxi(0, member.hp - amount)
    hp_changed.emit(_party_instance_id(member), member.hp, member.hp_max, old_hp)
    if old_hp > 0 and member.hp == 0:
        combatant_incapacitated.emit(_party_instance_id(member), false)
```

**Enemy HP** — mutate TCS-owned `_enemy_hp` dictionary:
```gdscript
func _apply_damage_to_enemy(instance_id: int, amount: int) -> void:
    var old_hp: int = _enemy_hp[instance_id]
    _enemy_hp[instance_id] = maxi(0, old_hp - amount)
    hp_changed.emit(instance_id, _enemy_hp[instance_id], _enemy_max_hp[instance_id], old_hp)
    if old_hp > 0 and _enemy_hp[instance_id] == 0:
        combatant_incapacitated.emit(instance_id, true)
```

### Effective Stat Lookup (ADR-0007)

```gdscript
# Get ATK/DEF via CharacterStatsUtil + StatusEffects modifier:
var atk_modifier: int = se.get_modifier(actor_id, &"ATK")
var atk_eff: int = actor.get_stat(&"ATK", [atk_modifier])
```

TCS calls `se.get_modifier(combatant_id, stat_name)` first, passes result into `CharacterData.get_stat()`. CharacterStatsUtil does not call SE internally — TCS bridges them.

### `damage_multiplier` Source

TCS reads `ability.damage_multiplier` from the `AbilityData` returned by `AS.get_ability(ability_id)`. AS does NOT compute damage. TCS computes damage using the formula above.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: FSM class scaffold and state transitions
- **Story 004**: PERFECT block counter (auto free attack after PERFECT block) — this story handles the mitigation formula only
- **Story 005**: CC changes associated with damage resolution
- **Story 009**: Status suppression on MISS and PERFECT block (AC-41, AC-42, AC-56)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these.*

- **AC-8**: Damage floor when ATK < DEF (HIT)
  - Given: ATK_eff = 12, DEF_eff = 13, grade = HIT, damage_multiplier = 1.0
  - When: `_compute_attack_damage(12, 13, 1.0, &"HIT")`
  - Then: returns 1 (max(1, -1) × 1.0 = 1; floor(1.0) = 1)
  - Edge cases: ATK = DEF exactly → base = 0 → max(1, 0) = 1

- **AC-9**: Damage floor persists through PERFECT multiplier
  - Given: ATK_eff = 12, DEF_eff = 13, grade = PERFECT, PHM = 1.3
  - When: `_compute_attack_damage(12, 13, 1.0, &"PERFECT")` with PHM 1.3
  - Then: returns 1 (max(1, -1) × 1.3 = 1.3; floor(1.3) = 1)

- **AC-10**: Standard HIT damage
  - Given: ATK_eff = 18, DEF_eff = 4, grade = HIT, damage_multiplier = 1.0
  - When: `_compute_attack_damage(18, 4, 1.0, &"HIT")`
  - Then: returns 14

- **AC-11**: PERFECT with high PHM
  - Given: ATK_eff = 18, DEF_eff = 4, grade = PERFECT, PHM = 1.6, damage_multiplier = 1.0
  - When: `_compute_attack_damage(18, 4, 1.0, &"PERFECT")` with PHM 1.6
  - Then: returns 22 (floor(14 × 1.6) = floor(22.4) = 22)

- **AC-12**: MISS deals 0 damage
  - Given: any ATK, DEF values, grade = MISS
  - When: `_compute_attack_damage(99, 1, 2.0, &"MISS")`
  - Then: returns 0

- **AC-13**: Equal ATK/DEF at HIT
  - Given: ATK_eff = 10, DEF_eff = 10, grade = HIT
  - When: formula runs
  - Then: base = 0; max(1, 0) = 1; floor(1.0) = 1

- **AC-14**: HIT block halves even number
  - Given: full_damage = 8, grade = HIT
  - When: `_compute_block_damage(8, &"HIT")`
  - Then: returns 4

- **AC-15**: PERFECT block negates all damage
  - Given: full_damage = 22, grade = PERFECT
  - When: `_compute_block_damage(22, &"PERFECT")`
  - Then: returns 0

- **AC-16**: HIT block floors odd numbers
  - Given: full_damage = 7, grade = HIT
  - When: `_compute_block_damage(7, &"HIT")`
  - Then: returns 3 (floor(3.5) = 3)

- **AC-17**: MISS block is no reduction
  - Given: full_damage = 8, grade = MISS
  - When: `_compute_block_damage(8, &"MISS")`
  - Then: returns 8

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat/tcs_damage_and_block_test.gd` — must exist and pass

**Status**: [x] `tests/unit/combat/tcs_damage_and_block_test.gd` — 17 test functions (2 AC-8, 1 AC-9, 1 AC-10, 1 AC-11, 2 damage_multiplier live-grade, 2 AC-12, 1 AC-13, 1 AC-14, 1 AC-15, 1 AC-16, 1 AC-17, 2 integration, 2 danger zone)

---

## Dependencies

- Depends on: Story 001 (TCS FSM Core) — Complete; class and state enum must exist
- Depends on: Story 002 (TCS Turn Order) — Complete; action resolution requires active turn context
- Unlocks: Story 004 (PERFECT block counter uses basic_attack at HIT grade); Story 005 (CC economy hooks into grade resolution)

---

## Completion Notes
**Completed**: 2026-05-06
**Criteria**: 10/10 passing
**Deviations**:
- ADVISORY: `var ability: Variant` for AS duck-typing in `_process_action_resolve()` — acceptable until Story 008 fully types AbilitySystem; must be resolved by Story 008.
- ADVISORY: `_hp_danger_zone_crossed` flag never resets on healing — Story 003 scope excludes healing. The healing story implementer must toggle `_hp_danger_zone_crossed[id]` back to `false` when HP crosses above the 25% threshold (see comments in `_apply_damage_to_enemy` / `_apply_damage_to_party_member`).
- ADVISORY: `grade_resolved` emits unconditionally when no living enemy in `_process_action_resolve()` — Story 006 to evaluate guard or document subscriber contract.
**Test Evidence**: Logic — `tests/unit/combat/tcs_damage_and_block_test.gd` (17 test functions; 2 tests added at close to cover `damage_multiplier != 1.0` on live grades)
**Code Review**: APPROVED WITH SUGGESTIONS — godot-gdscript-specialist, godot-specialist, qa-tester

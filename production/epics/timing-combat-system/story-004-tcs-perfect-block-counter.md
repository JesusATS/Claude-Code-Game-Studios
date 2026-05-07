# Story 004: TCS PERFECT Block Counter — Counter Attack and PARTY_ALL Block Window

> **Epic**: Timing Combat System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3-4 hours
> **Manifest Version**: 2026-05-04

## Context

**GDD**: `design/gdd/timing-combat-system.md`
**Requirement**: `TR-TCS-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Combat State Machine Architecture
**ADR Decision Summary**: On PERFECT block, TCS automatically fires a free counter-attack from the blocker at HIT grade. No timing window opens for the counter. A `_perfect_counter_fired: bool` flag (reset at ENEMY_ACTION entry) ensures at most one counter fires per ability turn. For PARTY_ALL abilities, one block window opens; the returned grade applies uniformly to all living party members.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: No post-cutoff APIs required. Signal emission ordering is deterministic within a GDScript frame.

**Control Manifest Rules (Core / Feature Layer)**:
- Required: `perfect_counter_started(actor_id: int)` signal emitted before counter animation begins
- Required: Typed collections in all public APIs
- Forbidden: No direct Autoload access inside TCS

---

## Acceptance Criteria

*From GDD `design/gdd/timing-combat-system.md`, scoped to this story:*

**PERFECT Block Counter:**
- [ ] **AC-18** — GIVEN a PERFECT block is achieved against a single-target enemy attack, WHEN the counter fires, THEN the party member who performed the PERFECT block executes basic_attack at HIT grade against the attacker; no timing window opens.
- [ ] **AC-19** — GIVEN the last surviving party member performs a PERFECT block, WHEN the counter fires, THEN the counter executes from that member normally (that member is the blocker by definition).
- [ ] **AC-20** — GIVEN a PERFECT block is achieved and the counter incapacitates the last enemy, WHEN the counter resolves, THEN Victory is declared immediately; the enemy's remaining turn (if any) does not execute.

**PARTY_ALL Block Window:**
- [ ] **AC-21** — GIVEN an enemy uses a PARTY_ALL ability, WHEN the block window resolves, THEN one window opens, one player input is accepted, and the returned grade (MISS/HIT/PERFECT) applies identically to all living party members.
- [ ] **AC-22** — GIVEN a PARTY_ALL ability and a PERFECT block grade, WHEN the counter fires, THEN exactly one counter executes from the party member who performed the PERFECT block.

---

## Implementation Notes

*Derived from ADR-0006 Implementation Guidelines:*

### PERFECT Counter Execution

```gdscript
# In BLOCK_RESOLVE state handler
func _process_block_resolve(blocker_id: int, attacker_id: int, grade: StringName) -> void:
    if grade == &"PERFECT" and not _perfect_counter_fired:
        _perfect_counter_fired = true
        _execute_perfect_counter(blocker_id, attacker_id)
```

```gdscript
func _execute_perfect_counter(blocker_id: int, attacker_id: int) -> void:
    perfect_counter_started.emit(blocker_id)
    # No timing window — grade is HIT internally
    var blocker: CharacterData = _get_combatant_data(blocker_id)
    var atk_mod: int = se.get_modifier(blocker_id, &"ATK")
    var atk_eff: int = blocker.get_stat(&"ATK", [atk_mod])
    var def_eff: int = _get_enemy_def(attacker_id)
    var ability_data: AbilityData = as_.get_ability(&"basic_attack")
    var damage: int = _compute_attack_damage(atk_eff, def_eff, ability_data.damage_multiplier, &"HIT")
    _apply_damage_to_enemy(attacker_id, damage)
    # CC from this HIT resolves in same action resolution (coalesced with block CC)
    _pending_cc_delta += 1  # HIT attack + 1 CC
    # Check terminal condition — Victory if last enemy incapacitated
    if _check_terminal():
        _state = State.ENCOUNTER_END
        _process_encounter_end()
        return
```

**`_perfect_counter_fired` flag**: Reset to `false` at the start of every `ENEMY_ACTION`. Ensures at most one counter per ability even for multi-hit abilities (see Story 007).

### PARTY_ALL Block Window

```gdscript
# At BLOCK_WINDOW entry: check ability target type
if ability_target_type == &"PARTY_ALL":
    # Open one shared window
    _block_window_blocker_id = _party_member_with_highest_spd()  # or slot 1 if tied — see GDD
    _block_window_is_party_all = true
    _state = State.BLOCK_WINDOW
    itd.input_result.connect(_on_block_grade_received, CONNECT_ONE_SHOT)
    itd.open_block_window(_compute_block_window_frames())
```

```gdscript
func _process_block_resolve_party_all(grade: StringName) -> void:
    for member: CharacterData in pcm.get_active_combatants():
        var damage: int = _compute_block_damage(ability_full_damage, grade)
        _apply_damage_to_party_member(member, damage)
    # PERFECT counter fires once from the blocker (same rule as single-target)
    if grade == &"PERFECT" and not _perfect_counter_fired:
        _perfect_counter_fired = true
        _execute_perfect_counter(_block_window_blocker_id, _current_enemy_instance_id)
```

**PARTY_ALL blocker definition**: The party member who "performed" the PERFECT block for PARTY_ALL is the one identified as the blocker for the shared window. Use slot 1 as the default blocker unless the GDD specifies otherwise — GDD does not define selection criteria beyond "the party member who performed the block."

### AC-20: Victory on Counter Kill

After `_apply_damage_to_enemy()` in the counter, check `_check_terminal()`. If Victory: set `_state = ENCOUNTER_END` and return from the current `BLOCK_RESOLVE` handler immediately. The outer loop (multi-hit or turn continuation) must check the state after the counter resolves and exit if `_state == ENCOUNTER_END`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 003**: Block mitigation formula (HIT/MISS damage calculation)
- **Story 005**: CC gain from PERFECT block (+1 CC) — this story only fires the counter; CC coalescing is Story 005
- **Story 006**: Full terminal condition check implementation
- **Story 007**: Multi-hit `_perfect_counter_fired` reset logic (Story 007 implements multi-hit BLOCK_WINDOW loops)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these.*

- **AC-18**: PERFECT block → counter fires from blocker
  - Given: Party member (instance_id 1) performs PERFECT block; enemy instance_id 101 was the attacker
  - When: BLOCK_RESOLVE processes PERFECT grade
  - Then: `perfect_counter_started(1)` emitted; counter resolves as `basic_attack` at HIT grade from instance 1 vs 101; no timing window opened; `_perfect_counter_fired = true`
  - Edge cases: counter with MISS block — `perfect_counter_started` NOT emitted; counter not fired

- **AC-19**: Last party member can counter
  - Given: Only instance_id 2 is alive (others INCAPACITATED); instance 2 performs PERFECT block
  - When: Counter fires
  - Then: Counter executes from instance 2 normally; no crash or skip

- **AC-20**: Counter kills last enemy → Victory declared
  - Given: Enemy HP = 1 (1 point from death); PERFECT block achieved; counter would deal 5 damage
  - When: `_apply_damage_to_enemy()` runs
  - Then: Enemy HP → 0; `combatant_incapacitated(101, true)` emitted; `_check_terminal()` returns VICTORY; `_state = ENCOUNTER_END`; remaining enemy turn does not continue
  - Edge cases: confirm BLOCK_WINDOW does NOT reopen after encounter ends

- **AC-21**: PARTY_ALL — one window, grade applied to all members
  - Given: Enemy uses PARTY_ALL ability; party has 3 living members (instances 1, 2, 3)
  - When: BLOCK_WINDOW opens, player inputs → HIT grade
  - Then: Exactly one `timing_window_opened` emission; each of the 3 members receives `floor(full_damage × 0.5)` damage
  - Edge cases: MISS grade → all 3 receive full damage; PERFECT → all receive 0 damage + 1 counter fires

- **AC-22**: PARTY_ALL PERFECT → exactly one counter
  - Given: PARTY_ALL ability; PERFECT block achieved
  - When: BLOCK_RESOLVE runs
  - Then: `perfect_counter_started` emitted exactly once; counter executes from the designated blocker (slot 1 or defined blocker); `_perfect_counter_fired = true` after first counter

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat/tcs_perfect_block_counter_test.gd` — must exist and pass

**Status**: [x] `tests/unit/combat/tcs_perfect_block_counter_test.gd` — 15 test functions covering AC-18 through AC-22, flag reset, formula PHM-exclusion, and invalid blocker_id signal suppression

---

## Dependencies

- Depends on: Story 001 (TCS FSM Core) — Complete
- Depends on: Story 003 (TCS Damage and Block) — Complete; `_compute_attack_damage()` and `_apply_damage_to_enemy()` must exist
- Unlocks: Story 006 (terminal conditions — AC-20 preview already implemented here); Story 007 (multi-hit uses `_perfect_counter_fired` flag)

---

## Completion Notes
**Completed**: 2026-05-06
**Criteria**: 5/5 passing
**Deviations**:
- ADVISORY: `_check_terminal()` returns `true` on empty `_enemy_hp` dict (post-encounter clear). Story 006 must handle when expanding.
- ADVISORY: `StubPCM.new() as PartyCompositionManager` silently returns null — safe for Story 004 (no pcm calls in tested paths); fix before Story 005/008.
- ADVISORY: `Variant` for ability lookup in `_execute_perfect_counter` — pre-existing AS duck-typing limitation; resolve by Story 008.
- ADVISORY: Redundant `_state = State.ENCOUNTER_END` before `_process_encounter_end()` call — harmless cosmetic noise.
- Blocking issue resolved: `perfect_counter_started` signal was emitted before validity guard — fixed (guard now precedes emit).
**Test Evidence**: Logic — `tests/unit/combat/tcs_perfect_block_counter_test.gd` (15 test functions; signal contract, PHM exclusion, invalid blocker_id suppression, and BLOCK_WINDOW-reopen edge case added at close)
**Code Review**: APPROVED WITH SUGGESTIONS (godot-gdscript-specialist, qa-tester) — one blocking issue found and resolved before close

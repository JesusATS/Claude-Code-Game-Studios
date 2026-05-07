# Story 009: TCS Edge Cases — SPD Threshold, Incapacitation Mid-Queue, Status Suppression, turn_order_changed, HP Danger Zone

> **Epic**: Timing Combat System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-05-04

## Context

**GDD**: `design/gdd/timing-combat-system.md`
**Requirement**: `TR-TCS-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Combat State Machine Architecture + ADR-0009: Status Effect Application Contract
**ADR Decision Summary**: TCS handles the following edge cases: invalid target (INCAPACITATED after selection), SPD = SPD_min resulting in TPR=1, PERFECT block suppresses status payloads while HIT block allows them, `turn_order_changed` emits at ROUND_START and immediately after any incapacitation event, HP danger zone signal re-fires on each HP crossing below 25%.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: ADR-0009 specifies that SE connects to `ability_resolved` with `CONNECT_DEFAULT` (synchronous) — same-frame status visibility guaranteed. TCS bridges `int instance_id` ↔ AS `StringName character_id`.

**Control Manifest Rules (Core / Feature Layer)**:
- Required: `turn_order_changed(ordered_ids: Array[int], active_id: int)` emitted at ROUND_START and after each `combatant_incapacitated`
- Required: `hp_danger_zone_entered(combatant_id: int)` re-emitted on each HP crossing below 25%

---

## Acceptance Criteria

*From GDD `design/gdd/timing-combat-system.md`, scoped to this story:*

- [ ] **AC-39** — GIVEN a combatant with SPD = SPD_min (e.g., SPD = 8, SPD_min = 8), WHEN TPR is calculated, THEN TPR = 1 (not 2) because `floor(8 / 12)` = 0.
- [ ] **AC-40** — GIVEN a target is INCAPACITATED after target selection but before resolution, WHEN the Ability System reports 0 valid targets, THEN TCS treats the action as a no-op (0 damage, 0 CC gain) and the turn advances to `TURN_END`.
- [ ] **AC-41** — GIVEN an enemy ability carries a status payload (e.g., MUTED) and the party achieves PERFECT block, WHEN `BLOCK_RESOLVE` runs, THEN the status payload is NOT applied to any party member; only the +1 CC and zero damage are resolved.
- [ ] **AC-42** — GIVEN an enemy ability carries a status payload and the party blocks at HIT grade, WHEN `BLOCK_RESOLVE` runs, THEN the status payload IS applied to the targeted party member(s) in addition to the mitigated damage.
- [ ] **AC-53** — GIVEN a round begins with 3 party members and 2 enemies all alive, WHEN `ROUND_START` completes, THEN `turn_order_changed(ordered_combatant_ids, active_id)` is emitted exactly once; subsequent turn transitions within that round do NOT re-emit the signal unless a combatant is incapacitated.
- [ ] **AC-54** — GIVEN a combatant is INCAPACITATED mid-round, WHEN `combatant_incapacitated` fires, THEN `turn_order_changed` is emitted immediately after with the updated `ordered_combatant_ids` array (excluding the incapacitated combatant) and the current `active_id`.
- [ ] **AC-55** — GIVEN a party member's HP drops below 25%, recovers above 25% via a heal, and then drops below 25% again in the same encounter, WHEN the second drop occurs, THEN `hp_danger_zone_entered(combatant_id)` is emitted a second time; the signal fires on each crossing, not only once per encounter.
- [ ] **AC-56** — GIVEN a player selects an ability that carries a status payload AND the timing window returns MISS, WHEN the action resolves, THEN the status payload is NOT applied to any combatant; damage = 0; only CC changes (per MISS rule) are applied.

---

## Implementation Notes

*Derived from ADR-0006 and ADR-0009 Implementation Guidelines:*

### AC-39: SPD = SPD_min → TPR = 1

Formula: `TPR = min(2, 1 + floor(SPD_c / (SPD_min × 1.5)))`
When SPD_c = SPD_min = 8: `floor(8 / 12.0)` = `floor(0.666)` = 0 → TPR = 1.
Note: `8 × 1.5 = 12.0` — ensure float division, not integer division.

```gdscript
func _compute_tpr(spd_c: int, spd_min: int) -> int:
    return mini(2, 1 + floori(float(spd_c) / (float(spd_min) * 1.5)))
```

### AC-40: Invalid Target (INCAPACITATED After Selection)

In `_process_action_resolve()`, after calling `as_.resolve_ability()`:
```gdscript
if as_result.get("effects_applied", []).is_empty() and damage == 0:
    # Treat as no-op — 0 valid targets reported
    _flush_cc()  # Flush any pending CC (may be 0)
    _state = State.TURN_END
    _process_turn_end()
```
More accurately: if all targets in the target list are INCAPACITATED, TCS skips damage application and proceeds to TURN_END.

### AC-41/AC-42: PERFECT Block Suppresses Status Payloads

```gdscript
func _process_block_resolve(grade: StringName) -> void:
    var damage: int = _compute_block_damage(_current_ability_full_damage, grade)
    _apply_damage_to_party_members(damage)  # 0 on PERFECT, mitigated on HIT, full on MISS
    if grade != &"PERFECT":
        # AC-42: HIT and MISS — status payload IS delivered
        _dispatch_block_status_payloads(_current_enemy_ability_id, grade)
    # AC-41: PERFECT — status payload suppressed (do NOT call _dispatch_block_status_payloads)
    # PERFECT counter fires here (Story 004)
```

**Note**: MISS block also delivers status payloads per AC-42 (rule: only PERFECT suppresses). Verify GDD rule 13: "On a PERFECT block, all effects carried by the blocked ability are suppressed."

### AC-56: MISS Suppresses Status Payloads on Attack

```gdscript
func _process_action_resolve() -> void:
    if _current_grade == &"MISS":
        # AC-56 + GDD Rule 12: No damage, no status, only CC changes (0 on MISS)
        _flush_cc()
        _state = State.TURN_END
        _process_turn_end()
        return
    # ... apply damage and status payloads for HIT/PERFECT
    _dispatch_attack_status_payloads(_current_ability_id, _current_grade)
```

### AC-53/AC-54: `turn_order_changed` Signal Conditions

`turn_order_changed` emits in exactly two places:
1. At end of `_process_round_start()` — once per round after queue is built (Story 002)
2. Immediately after `combatant_incapacitated` emits — update the ordered list

```gdscript
func _apply_damage_to_party_member(member: CharacterData, amount: int) -> void:
    # ... (Story 003)
    if old_hp > 0 and member.hp == 0:
        combatant_incapacitated.emit(mid, false)
        turn_order_changed.emit(_get_living_combatant_ids(), _current_actor_id)
```

**AC-53**: Single `turn_order_changed` emission at ROUND_START. Do NOT emit it again at each TURN_START — only emit when queue structure changes (incapacitation or new round).

### AC-55: HP Danger Zone Re-entry

```gdscript
var _hp_danger_zone_crossed: Dictionary[int, bool] = {}  # Tracks current below-threshold state

func _check_hp_danger_zone(combatant_id: int, hp: int, max_hp: int) -> void:
    var threshold: int = floori(float(max_hp) * 0.25)
    var below: bool = hp <= threshold
    var was_below: bool = _hp_danger_zone_crossed.get(combatant_id, false)
    if below and not was_below:
        _hp_danger_zone_crossed[combatant_id] = true
        hp_danger_zone_entered.emit(combatant_id)
    elif not below and was_below:
        _hp_danger_zone_crossed[combatant_id] = false  # Reset so next crossing re-fires
```

Call `_check_hp_danger_zone()` after every HP change in `_apply_damage_to_party_member()` and any healing logic.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 002**: Base TPR formula implementation — this story only verifies the SPD=SPD_min edge case
- **Story 003**: `_apply_damage_to_party_member()` base implementation
- **Story 005**: `_flush_cc()` for MISS case — Story 005 defines the function; Story 009 calls it
- **Story 006**: Terminal condition check after incapacitation during AC-54 resolution

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these.*

- **AC-39**: SPD = SPD_min → TPR = 1
  - Given: `spd_c = 8`, `spd_min = 8`
  - When: `_compute_tpr(8, 8)` called
  - Then: returns 1 (not 2)
  - Edge cases: `spd_c = 12`, `spd_min = 8` → `floor(12/12.0)` = 1 → TPR = min(2, 2) = 2 — confirm boundary

- **AC-40**: No-op on INCAPACITATED target
  - Given: Target enemy instance_id 101 is INCAPACITATED (HP = 0) after player selected it
  - When: `_process_action_resolve()` checks targets
  - Then: Damage = 0; CC = 0; turn advances to TURN_END; no crash
  - Edge cases: ensure `combatant_incapacitated` is NOT re-emitted for already-dead combatant

- **AC-41**: PERFECT block suppresses status payload
  - Given: Enemy ability carries MUTED status payload; player achieves PERFECT block
  - When: `_process_block_resolve(&"PERFECT")` runs
  - Then: `se` (StatusEffects) receives NO status application call for MUTED; `_dispatch_block_status_payloads()` NOT called for PERFECT

- **AC-42**: HIT block applies status payload
  - Given: Same enemy ability with MUTED; player blocks at HIT
  - When: `_process_block_resolve(&"HIT")` runs
  - Then: `_dispatch_block_status_payloads()` called; StatusEffects receives MUTED application for targeted member

- **AC-53**: `turn_order_changed` emitted once at ROUND_START
  - Given: 3 party + 2 enemies alive; round starts
  - When: `_process_round_start()` completes; 3 turn transitions occur within the round
  - Then: `turn_order_changed` spy records exactly 1 emission for that round (from ROUND_START only)

- **AC-54**: `turn_order_changed` re-emits after incapacitation
  - Given: Combatant ID 102 is INCAPACITATED mid-round
  - When: `combatant_incapacitated(102, true)` fires
  - Then: `turn_order_changed` emits immediately after with `ordered_combatant_ids` not containing 102

- **AC-55**: HP danger zone re-fires on second crossing
  - Given: Party member HP = 20/40 (below 25%); healed to 25/40 (above 25%); then drops to 9/40 (below 25%)
  - When: Second drop occurs
  - Then: `hp_danger_zone_entered(member_id)` emitted a second time; spy records 2 total emissions

- **AC-56**: MISS attack suppresses status payload
  - Given: Ability with MUTED status payload; timing window returns MISS
  - When: `_process_action_resolve()` runs
  - Then: `_dispatch_attack_status_payloads()` NOT called; damage = 0; no status applied to any combatant

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat/tcs_edge_cases_test.gd` — must exist and pass

**Status**: [x] Created — `tests/unit/combat/tcs_edge_cases_test.gd` (13 test functions)

---

## Dependencies

- Depends on: Story 001 (TCS FSM Core) — Complete
- Depends on: Story 002 (TCS Turn Order) — Complete; TPR formula and `turn_order_changed` base emission
- Depends on: Story 003 (TCS Damage and Block) — Complete; `_apply_damage_to_party_member()` and `_apply_damage_to_enemy()`
- Depends on: Story 005 (TCS CC Economy) — Complete; MISS handling uses `_flush_cc()`
- Unlocks: Story 010 (integration — all edge case behaviors must be present for full encounter flow)

---

## Completion Notes
**Completed**: 2026-05-06
**Criteria**: 8/8 passing
**Deviations**:
- ADVISORY: TCS emits its own `ability_resolved` signal rather than delegating to AS per ADR-0009 Rule 1–2 (intentional — AS not yet implemented; reconcile in Story 011 signal audit)
- ADVISORY: Test function name typo `advances_fom_to_idle_via_victory` (non-functional)
**Test Evidence**: Logic — `tests/unit/combat/tcs_edge_cases_test.gd` (13 test functions)
**Code Review**: APPROVED WITH SUGGESTIONS (inline review — lean mode)

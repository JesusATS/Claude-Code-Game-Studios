# ADR-0006: Combat State Machine Architecture

## Status
Accepted

## Date
2026-05-04

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core (Combat) |
| **Knowledge Risk** | LOW — signal `connect()`, `CONNECT_ONE_SHOT`, node reference injection, and Dictionary typed generics are stable from Godot 4.0 through 4.6 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md` |
| **Post-Cutoff APIs Used** | `Dictionary[K, V]` typed generics (Godot 4.4+) — used for `_enemy_hp: Dictionary[int, int]`. Verify that typed Dictionary syntax is accepted by the GDScript parser in Godot 4.6 before implementation. |
| **Verification Required** | Confirm `CONNECT_ONE_SHOT` disconnects correctly after signal emission. Confirm typed `Dictionary[int, int]` parses without error. Confirm that freeing the BattleSceneRoot at encounter end clears all TCS signal connections to HUD/AudioSystem via CombatEventBus (ADR-0004 Godot auto-disconnect guarantee). |

> **Note**: If Knowledge Risk is MEDIUM or HIGH, this ADR must be re-validated if the
> project upgrades engine versions. Flag it as "Superseded" and write a new ADR.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Accepted) — CharacterData as Resource; ADR-0002 (Accepted) — Autoload strategy; ADR-0003 (Accepted) — ITD node placement and input routing; ADR-0004 (Accepted) — CombatEventBus relay pattern for persistent-system signals; ADR-0005 (Accepted) — RefCounted naming; ADR-0007 (Accepted) — CharacterStatsUtil for window frame calculation; ADR-0008 (Accepted) — ITD FSM and force_close_window() API |
| **Enables** | All TCS implementation stories; HUD combat stories (HUD wired at BattleSceneRoot); AudioSystem combat stories; all enemy AI stories |
| **Blocks** | TR-TCS-001 through TR-TCS-007 — all TCS implementation is blocked until this ADR is Accepted |
| **Ordering Note** | Must be Accepted before any TCS, HUD combat, or AudioSystem combat story is created. Resolves GDD OQ-5 (coroutine vs signal-driven FSM; canonical combatant ID type; HP authority for enemies; TCS scene-tree placement) and OQ-6 (CanvasModulate writer conflict). |

## Summary

The Timing Combat System (TCS) requires four unresolved architectural decisions before implementation can begin: (1) signal-driven FSM vs. coroutine-based state machine, (2) canonical combatant instance ID type, (3) authoritative HP store for enemies during combat, and (4) TCS scene-tree placement. This ADR adopts a **14-state signal-driven FSM** using `CONNECT_ONE_SHOT` for external input waits, integer `instance_id` with TCS-owned enemy HP, and BattleSceneRoot-level node placement.

## Context

### Problem Statement

The TCS GDD defines a 14-state combat FSM orchestrating six downstream systems (ITD, AS, ES, SE, PCM, Audio). Four architectural questions are explicitly flagged as blockers (GDD OQ-5):

1. **FSM implementation pattern**: Should TCS be a coroutine chain (`await` on signals) or a signal-driven state machine (explicit enum state, signal handler transitions)?
2. **Canonical combatant ID type**: Should combatant identifiers be `int` (slot-based) or `StringName` (name-based)? ADR-0004 CombatEventBus uses `StringName`; the GDD encounter_state schema uses `int`.
3. **Enemy HP authority**: Enemy current HP is mutable during combat. Neither `EnemyData` (a read-only Resource) nor `EnemySystem` (stateless per ADR-0001 Resource model) owns this. Who does?
4. **TCS scene-tree placement**: TCS must be at or above the CanvasLayer in the scene tree (ITD is at root level per ADR-0003). Where exactly does TCS live?

A fifth open question, OQ-6, requires a **CombatEnvironmentController** to resolve CanvasModulate write conflicts from three concurrent TCS-driven tweens (encounter start/end, per-turn mood shift, per-incapacitation cold stack). This ADR establishes the controller's existence and signal contract; visual implementation belongs to the HUD ADR.

### Constraints

- ITD must be above HUD's CanvasLayer (ADR-0003 Rule 3) — TCS orchestrates ITD and must be at the same scope
- `EnemyData` is a read-only Resource (ADR-0001) — mutable encounter HP cannot live on it
- Persistent systems (HUD, AudioSystem) subscribe to CombatEventBus, not to TCS directly (ADR-0004)
- TCS must not access any Autoload directly (ADR-0002 Rule 3) — all wiring via composition root
- `force_close_window()` (TR-TCS-005) must interrupt any pending timing or block window cleanly

### Requirements

- 14-state FSM matching the GDD state table
- Deterministic testability: GUT tests must be able to trigger grade resolution and verify state transitions without real-time input
- HP authority for enemies is unambiguous — no double-mutation risk
- `force_close_window()` works from any non-IDLE state, no-op in IDLE
- Enemy AI evaluation reads a freshly constructed `encounter_state` snapshot per turn
- Audio calls fire at correct FSM boundaries (encounter start/end)
- `cc_changed` signal coalesces all CC gain events from a single action resolution into one emission

## Decision

### Rule 1: Signal-Driven FSM (not coroutines)

TCS implements a **signal-driven FSM** using an explicit `State` enum. When TCS must wait for external input (player action selection, ITD grade), it:

1. Sets `_state` to the waiting state
2. Connects to the relevant signal using `CONNECT_ONE_SHOT`
3. Returns from the current method (yields control back to the engine)
4. Resumes in the signal handler, which transitions `_state` and continues processing

This is rejected in favor of `await`-based coroutines because:
- `force_close_window()` must interrupt a pending wait synchronously. Cancelling a GDScript coroutine mid-`await` requires the coroutine to be stored and freed, which is fragile. With `CONNECT_ONE_SHOT`, TCS can disconnect the pending handler and call `itd.force_close_window()` (which emits `input_result(MISS)`) to trigger clean resolution.
- Per-state GUT tests require inspecting `_state` between frames. A coroutine FSM embeds state implicitly in the call stack, making frame-level state inspection opaque.

```gdscript
# src/feature/combat/timing_combat_system.gd
class_name TimingCombatSystem extends Node

enum State {
    IDLE,
    ENCOUNTER_START,
    ROUND_START,
    TURN_START,
    TURN_SKIPPED,
    PLAYER_ACTION,
    TIMING_WINDOW,
    ACTION_RESOLVE,
    ENEMY_ACTION,
    BLOCK_WINDOW,
    BLOCK_RESOLVE,
    TURN_END,
    ROUND_END,
    ENCOUNTER_END
}

var _state: State = State.IDLE
```

**FSM transition trigger summary:**

| From | To | Trigger |
|------|-----|---------|
| IDLE | ENCOUNTER_START | `begin_encounter(party, enemies)` called by BattleSceneRoot |
| ENCOUNTER_START | ROUND_START | synchronous (roster built) |
| ROUND_START | TURN_START | synchronous (queue frozen, signal emitted) |
| TURN_START | TURN_SKIPPED | INCAPACITATED or `check_turn_skip()` = true |
| TURN_START | PLAYER_ACTION | active combatant is party member |
| TURN_START | ENEMY_ACTION | active combatant is enemy |
| TURN_SKIPPED | TURN_END | synchronous |
| PLAYER_ACTION | TIMING_WINDOW | `submit_player_action()` called (standard ability) |
| PLAYER_ACTION | ACTION_RESOLVE | `submit_player_action()` called (timing_optional ability) |
| TIMING_WINDOW | ACTION_RESOLVE | `itd.input_result` signal fires (CONNECT_ONE_SHOT) |
| ENEMY_ACTION | BLOCK_WINDOW | enemy action targets party member(s) |
| ENEMY_ACTION | ACTION_RESOLVE | enemy action has no party target |
| BLOCK_WINDOW | BLOCK_RESOLVE | `itd.input_result` signal fires (CONNECT_ONE_SHOT) |
| BLOCK_RESOLVE | BLOCK_WINDOW | multi-hit: `_hits_remaining > 0` and no terminal condition |
| BLOCK_RESOLVE | ENCOUNTER_END | terminal condition met (e.g., PERFECT counter kills last enemy) |
| BLOCK_RESOLVE | TURN_END | single-hit or last hit of multi-hit resolved |
| ACTION_RESOLVE | TURN_END | synchronous (damage and CC applied) |
| ACTION_RESOLVE | ENCOUNTER_END | terminal condition met during resolve |
| TURN_END | ENCOUNTER_END | terminal condition met |
| TURN_END | ROUND_END | turn queue exhausted |
| TURN_END | TURN_START | more turns remain in queue |
| ROUND_END | ENCOUNTER_END | terminal condition met |
| ROUND_END | ROUND_START | no terminal condition |
| ENCOUNTER_END | IDLE | synchronous (signals emitted, state cleared) |

### Rule 2: Canonical Combatant ID is `int`; Relay Converts at Bus Boundary

All TCS-internal operations (encounter_state schema, signal emissions, HP dictionary keys, turn queue) use **`int` instance_id**.

Assignment convention at ENCOUNTER_START:

```gdscript
# Party members: PCM slot index (1-based)
#   Slot 1 → instance_id 1
#   Slot 2 → instance_id 2
#   Slot 3 → instance_id 3
#   Slot 4 (guest) → instance_id 4

# Enemies: 100 + encounter slot index (1-based)
#   Encounter slot 1 → instance_id 101
#   Encounter slot 2 → instance_id 102
#   Encounter slot 3 → instance_id 103
```

This produces a non-overlapping, stable, readable namespace for the duration of one encounter. IDs are not reused: if enemy at slot 1 is INCAPACITATED, instance_id 101 ceases to appear in the living roster but is not reassigned.

**Bus relay boundary**: BattleSceneRoot's relay methods convert `int → StringName` via `str(instance_id)` when wiring TCS signals to CombatEventBus relay methods. The conversion is deterministic and reversible (`int(str_id)` recovers the original value). TCS signals declare `int` parameter types; CombatEventBus signals declare `StringName` (per ADR-0004).

```gdscript
# BattleSceneRoot wiring (example relay for hp_changed)
func _on_tcs_hp_changed(combatant_id: int, new_hp: int, max_hp: int, old_hp: int) -> void:
    CombatEventBus.relay_hp_changed(str(combatant_id), new_hp, max_hp, old_hp)
```

### Rule 3: TCS Owns Enemy HP During Combat; Party HP Lives on CharacterData

**Party HP**: TCS mutates `CharacterData.hp` directly on the references obtained from `PCM.get_active_combatants()`. PCM is not notified separately; mutation is visible via reference semantics.

**Enemy HP**: `EnemyData` is a read-only Resource (ADR-0001). TCS owns a mutable HP table for the duration of an encounter:

```gdscript
# Keyed by instance_id (int); values are current HP
var _enemy_hp: Dictionary[int, int] = {}
var _enemy_max_hp: Dictionary[int, int] = {}  # populated at ENCOUNTER_START, read-only after

func _initialize_enemy_hp(enemies: Array[EnemyData]) -> void:
    for i: int in range(enemies.size()):
        var instance_id: int = 101 + i
        _enemy_hp[instance_id] = enemies[i].hp_max
        _enemy_max_hp[instance_id] = enemies[i].hp_max

func _apply_damage_to_enemy(instance_id: int, amount: int) -> void:
    var old_hp: int = _enemy_hp[instance_id]
    _enemy_hp[instance_id] = maxi(0, old_hp - amount)
    hp_changed.emit(instance_id, _enemy_hp[instance_id], _enemy_max_hp[instance_id], old_hp)
    if old_hp > 0 and _enemy_hp[instance_id] == 0:
        combatant_incapacitated.emit(instance_id, true)
```

At ENCOUNTER_END, `_enemy_hp` and `_enemy_max_hp` are cleared. No persistent state leaks to the next encounter.

**Note on hp_danger_zone_entered**: TCS emits this signal the first time a combatant's HP crosses below 25% of max HP in an encounter. Re-entry (healed above 25%, then drops again) re-emits. TCS tracks this with a `_hp_danger_zone_crossed: Dictionary[int, bool]` that is cleared at ENCOUNTER_START and toggled per crossing.

### Rule 4: TCS Scene-Tree Placement

TCS lives as a direct child of BattleSceneRoot, at the same level as ITD and AudioSystem. BattleSceneRoot is the composition root for all battle-scoped systems.

```
BattleSceneRoot (Node2D)
  ├── TimingCombatSystem (Node)            ← FSM + orchestrator (this ADR)
  ├── InputTimingDetector (Node)           ← timing window FSM (ADR-0008)
  ├── AudioSystem (Node)                   ← pre-allocated audio pool (ADR-0011)
  ├── CombatEnvironmentController (Node)   ← CanvasModulate owner (Rule 8)
  ├── HUD (CanvasLayer, layer 10)          ← presentation; subscribes to CombatEventBus
  ├── PartyView (Node2D)                   ← party sprite containers
  └── EnemyView (Node2D)                   ← enemy sprite containers
```

TCS does NOT access HUD or AudioSystem directly. All communication to persistent consumers is via signals relayed through CombatEventBus (ADR-0004). Direct injected references held by TCS are: ITD, AbilitySystem, EnemySystem, StatusEffects, PCM, AudioSystem (audio calls are direct, not via bus — see Rule 7).

BattleSceneRoot performs all wiring in its `_ready()` before calling `tcs.begin_encounter()`.

### Rule 5: `force_close_window()` Delegation Chain

When a pause, cutscene, or scene transition interrupts combat, the caller invokes `tcs.force_close_window()`:

```gdscript
func force_close_window() -> void:
    if _state not in [State.TIMING_WINDOW, State.BLOCK_WINDOW]:
        return  # No-op in all other states
    # ITD.force_close_window() emits input_result(mode, "MISS")
    # The CONNECT_ONE_SHOT handler fires automatically → TCS resolves as MISS
    itd.force_close_window()
```

**Why this works**: When TCS enters TIMING_WINDOW or BLOCK_WINDOW, it connects to `itd.input_result` with `CONNECT_ONE_SHOT`. ITD's `force_close_window()` (ADR-0008 Rule 4) closes any open window as MISS and emits both `input_result` and `window_closed`. The CONNECT_ONE_SHOT handler fires, TCS transitions to ACTION_RESOLVE or BLOCK_RESOLVE with grade = MISS, and the FSM continues normally. No dangling connection exists after resolution.

**TCS does not call `itd.force_close_window()` directly at any other time.** TCS calls `itd.open_action_window(frames)` or `itd.open_block_window(frames)` to open windows. The ITD closes them on its own schedule (grade or expiry) unless TCS interrupts via `force_close_window()`.

### Rule 6: Enemy AI Evaluation — Fresh `encounter_state` Per Turn

At each `ENEMY_ACTION` state entry, TCS builds a fresh `encounter_state` Dictionary before calling `es.evaluate_turn(instance_id, encounter_state)`. The Dictionary is **never reused or mutated between turns**.

```gdscript
func _build_encounter_state(active_instance_id: int) -> Dictionary:
    var party_data: Array[Dictionary] = []
    for member: CharacterData in pcm.get_active_combatants():
        var mid: int = _party_instance_id(member)
        party_data.append({
            "instance_id": mid,
            "hp_current": member.hp,
            "hp_max": member.hp_max,
            "active_effects": se.get_active_effect_ids(mid)
        })

    var enemy_data: Array[Dictionary] = []
    for iid: int in _enemy_hp:
        if _enemy_hp[iid] > 0:
            enemy_data.append({
                "instance_id": iid,
                "enemy_id": _enemy_data[iid].id,
                "hp_current": _enemy_hp[iid],
                "hp_max": _enemy_max_hp[iid],
                "active_effects": se.get_active_effect_ids(iid)
            })

    return {
        "round_number": _round_number,
        "living_party": party_data,
        "living_enemies": enemy_data,
        "active_instance_id": active_instance_id
    }
```

Enemy System returns `{ability_id: StringName, targets: Array[int], hit_count: int}`. TCS reads `hit_count` to set `_hits_remaining` before entering the first BLOCK_WINDOW of the turn. The PERFECT counter fires at most once per ability (`_perfect_counter_fired` flag, reset at ENEMY_ACTION entry).

### Rule 7: Audio Integration — Direct Injection, Not Bus

AudioSystem is injected into TCS at composition root (not an Autoload per ADR-0002). TCS calls AudioSystem directly for encounter-scoped audio events:

```gdscript
# Called at ENCOUNTER_START
func _start_audio(enemy_ids: Array[StringName]) -> void:
    audio_system.begin_combat_layer()
    # AudioSystem checks internally if any enemy is APEX archetype

# Called at ENCOUNTER_END
func _end_audio() -> void:
    audio_system.end_combat_layer()
```

All other audio events (grade tones, CC chimes, incapacitation sounds) are driven by **AudioSystem subscribing to CombatEventBus signals** (ADR-0004 / ADR-0011). TCS does not call AudioSystem methods for those events; it emits signals that flow through the bus.

The `cc_changed` signal carries `source_type: StringName` (`"window_grade"` or `"ability_delta"`) so AudioSystem can suppress the CC chime for non-window CC awards, per GDD rule.

**CC signal coalescing**: TCS accumulates all CC gains from a single action resolution into `_pending_cc_delta`. After all events in the resolution complete, TCS emits `cc_changed` once. If multiple gain paths fire (e.g., PERFECT block +1 then PERFECT counter +1), both are summed: `cc_changed(new_cc=2, delta=2, source_type="window_grade")`.

### Rule 8: CombatEnvironmentController Owns CanvasModulate Writes (Resolves OQ-6)

Three TCS-driven visual events write to scene `CanvasModulate` concurrently:
1. Encounter start/end 1.5s tween (warm↔cool palette)
2. Per-turn micro-shift (warms on player turn, cools on enemy turn)
3. Per-incapacitation cold stack (accumulates as party members fall)

Without a single owner, these tweens conflict. **CombatEnvironmentController** is a dedicated Node at BattleSceneRoot level that owns all `CanvasModulate` writes during combat. TCS emits signals; the controller subscribes and manages tween sequencing.

TCS signals that the controller consumes (all relayed via CombatEventBus):

| Signal | CanvasModulate Effect |
|--------|-----------------------|
| `encounter_started` | Begin 1.5s warm→cool tween |
| `encounter_ended` | Begin 1.5s cool→warm tween |
| `turn_order_changed(ordered_ids, active_id)` | Micro-shift: warm if `active_id` is party (instance_id ≤ 4), cool if enemy |
| `combatant_incapacitated(id, is_enemy=false)` | Increment cold stack (party members only) |

The visual target values, tween curve, and cold-stack increment amount belong to the **HUD/Visual ADR** (planned ADR-0014). CombatEnvironmentController must exist in BattleSceneRoot before any visual combat story is created.

## Alternatives Considered

### Alternative 1: Coroutine-Based FSM (`await` chain)

- **Description**: TCS's main loop is an `async` function that `await`s ITD signals, player input signals, and status check calls in sequence. The entire combat flow is a single coroutine chain.
- **Pros**: Extremely readable — the flow reads like pseudocode. No state enum bookkeeping. Less boilerplate.
- **Cons**: `force_close_window()` cannot interrupt a coroutine safely without storing and `free()`ing the coroutine reference, which is fragile. GUT per-frame state inspection is opaque. Coroutine stack is implicitly the state — impossible to assert "TCS is in BLOCK_WINDOW state" from a test without probing side effects.
- **Rejection Reason**: `force_close_window()` is a GDD hard requirement (TR-TCS-005). Signal-driven FSM resolves this cleanly via the CONNECT_ONE_SHOT pattern without coroutine lifecycle management.

### Alternative 2: `StringName` as Canonical Combatant ID

- **Description**: Use `StringName` throughout — party members identified by character name (e.g., `&"clawd"`), enemies by archetype+slot (e.g., `&"zarg_01"`).
- **Pros**: Human-readable in logs and signals. Directly matches CombatEventBus signal types (ADR-0004).
- **Cons**: The GDD encounter_state schema explicitly uses `int` instance_id (to distinguish multiple enemies of the same archetype). `StringName` requires a naming scheme that must be consistent across TCS, SE, and ES. The relay boundary conversion (`int → str → StringName`) is trivial and transparent; standardizing on `int` internally keeps all arithmetic and dictionary operations simple.
- **Rejection Reason**: The GDD schema and encounter boundary bookkeeping are simpler with `int`. The bus boundary handles the type conversion in one place (BattleSceneRoot relay wiring).

### Alternative 3: EnemySystem Owns Enemy HP

- **Description**: EnemySystem holds a mutable HP table (instance_id → current_hp) and TCS calls `es.apply_damage(instance_id, amount)` rather than mutating directly.
- **Pros**: HP authority is centralized in the system that owns enemy definitions.
- **Cons**: EnemySystem's purpose is action selection (stateless evaluation per turn). Making it mutable introduces a second responsibility that conflicts with the clean separation defined in ADR-0001 (EnemyData as read-only Resource). TCS already mutates CharacterData directly for party HP; symmetric treatment for enemies is simpler and consistent.
- **Rejection Reason**: Violates single-responsibility for EnemySystem. TCS-owned HP table matches the pattern established for party HP (direct mutation on combat data) and is cleared at encounter end.

## Consequences

### Positive

- Signal-driven FSM is fully unit-testable frame-by-frame via `itd.inject_input()` + `itd.advance_frame()` test seams (ADR-0008)
- `force_close_window()` interrupts any pending window cleanly via a single `itd.force_close_window()` delegation
- Enemy HP lifecycle is unambiguous — created at encounter start, owned by TCS, discarded at encounter end
- CombatEnvironmentController resolves the CanvasModulate conflict before any visual story begins
- CONNECT_ONE_SHOT eliminates manual signal disconnection bookkeeping for timing window waits

### Negative

- Signal-driven FSM requires more boilerplate than a coroutine chain (~14 handler methods instead of one linear function)
- `int → StringName` relay conversion is a permanent type boundary in BattleSceneRoot wiring
- CombatEnvironmentController is an additional required node that must be scaffolded before visual stories

### Neutral

- TCS holds injected references to 6 sub-systems (ITD, AS, ES, SE, PCM, Audio) — all set by BattleSceneRoot before `begin_encounter()` is called; TCS does not lazy-initialize or null-check these at runtime (composition root is responsible for correct wiring)

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Addresses It |
|---|---|---|---|
| `timing-combat-system.md` | Timing Combat System | TR-TCS-001: Full combat FSM (14 states per GDD table; described as "11 states" in the architecture document's initial TR extraction) | Rule 1: 14-state signal-driven FSM with documented transitions covering all GDD states (IDLE through ENCOUNTER_END) |
| `timing-combat-system.md` | Timing Combat System | TR-TCS-002: Orchestrates ITD, AS, ES, SE, PCM | Rule 4 (composition root injection) + Rule 6 (encounter_state schema) establish the TCS-as-orchestrator pattern; injected references wired by BattleSceneRoot |
| `timing-combat-system.md` | Timing Combat System | TR-TCS-003: Audio calls: begin/end combat_layer, apex_layers | Rule 7: direct AudioSystem injection; `begin_combat_layer()` at ENCOUNTER_START, `end_combat_layer()` at ENCOUNTER_END |
| `timing-combat-system.md` | Timing Combat System | TR-TCS-005: force_close_window() before pause/cutscene | Rule 5: `tcs.force_close_window()` delegates to `itd.force_close_window()` which emits `input_result(MISS)` → CONNECT_ONE_SHOT handler resolves cleanly |
| `timing-combat-system.md` | Timing Combat System | TR-TCS-006: Enemy AI priority rule evaluation (first-match) | Rule 6: TCS builds fresh `encounter_state` snapshot per `evaluate_turn()` call; Enemy System owns the first-match evaluation; no stale state reuse |
| `timing-combat-system.md` | Timing Combat System | TR-TCS-007: HP mutation direct to CharacterData references | Rule 3: party HP mutated directly on CharacterData references from PCM; enemy HP owned in TCS `_enemy_hp` dictionary during encounter |

**Note on TR-TCS-004** (Combat signals relayed to persistent consumers): TR-TCS-004 is covered by ADR-0004 (CombatEventBus relay pattern). This ADR establishes the int→StringName conversion at the relay boundary in Rule 2, completing the signal contract between TCS and the bus.

## Performance Implications

- **CPU**: Signal-driven FSM: one signal connection and one Dictionary lookup per state transition — negligible. `_build_encounter_state()` constructs a new Dictionary per enemy turn: O(party_size + enemy_count) allocation. At 3+3 combatants, this is 6 Dictionary entries per enemy turn — unmeasurable.
- **Memory**: `_enemy_hp` and `_enemy_max_hp`: 2 Dictionaries × max 6 enemies × 8 bytes per entry = ~96 bytes. `_pending_cc_delta` and other per-turn transient fields: < 100 bytes total.
- **Load Time**: No preloading required — TCS is instantiated when the battle scene loads.
- **Network**: Not applicable.

## Migration Plan

No existing code to migrate. When implementing TimingCombatSystem:

1. Create `src/feature/combat/timing_combat_system.gd` — declare `class_name TimingCombatSystem extends Node`
2. Implement the 14-state enum and `_state` variable
3. Implement `begin_encounter(party: Array[CharacterData], enemies: Array[EnemyData])` as the BattleSceneRoot entry point
4. Implement ROUND_START, TURN_START, PLAYER_ACTION, TIMING_WINDOW, ACTION_RESOLVE, ENEMY_ACTION, BLOCK_WINDOW, BLOCK_RESOLVE, TURN_END, ROUND_END, ENCOUNTER_END handlers
5. Implement `submit_player_action(ability_id: StringName)` as the HUD callback for player input
6. Implement `force_close_window()` per Rule 5
7. Implement `_build_encounter_state()` per Rule 6
8. Wire all 6 injected references in BattleSceneRoot `_ready()`
9. Create `CombatEnvironmentController` stub node (full implementation deferred to HUD ADR)
10. Write unit tests covering all 59 acceptance criteria from the TCS GDD using ITD test seams

## Validation Criteria

- [ ] TCS._state = IDLE at construction
- [ ] `begin_encounter()` transitions IDLE → ENCOUNTER_START → ROUND_START → TURN_START synchronously in one call
- [ ] TIMING_WINDOW: `itd.inject_input("timing_confirm")` + `itd.advance_frame()` fires `input_result` → TCS transitions to ACTION_RESOLVE
- [ ] `force_close_window()` in TIMING_WINDOW or BLOCK_WINDOW: calls `itd.force_close_window()`, TCS resolves with MISS grade, no dangling CONNECT_ONE_SHOT connection remains
- [ ] `force_close_window()` in IDLE, ROUND_START, TURN_START is a no-op (no signal emission, no state change)
- [ ] `_build_encounter_state()` returns a new Dictionary instance each call (not a cached reference)
- [ ] Enemy instance_id 101+ never collides with party instance_id 1-4
- [ ] `_enemy_hp[id]` for a living enemy equals its initialized value minus all applied damage
- [ ] `_enemy_hp` is empty after ENCOUNTER_END resolves
- [ ] Multi-hit: two BLOCK_WINDOW → BLOCK_RESOLVE cycles fire for a 2-hit enemy ability; `perfect_counter_started` emitted at most once per ability
- [ ] `cc_changed` emitted exactly once per action resolution, even when PERFECT block (+1) and PERFECT counter (+1) both occur in the same resolution
- [ ] `grade_resolved` NOT emitted for `timing_optional` abilities
- [ ] `begin_combat_layer()` called once at ENCOUNTER_START; `end_combat_layer()` called once at ENCOUNTER_END
- [ ] TCS does not reference any Autoload by global name in production code (audit with Grep)
- [ ] All 59 TCS GDD acceptance criteria pass in GUT test suite

## Related Decisions

- ADR-0003: Input Routing — ITD placement and timing_confirm action; force_close_window() pattern that TCS delegates to
- ADR-0004: Combat Event Signal Bus — relay pattern that TCS signals feed into; int→StringName boundary at BattleSceneRoot
- ADR-0007: CharacterStatsUtil — provides `timing_window_frames()` and `block_window_frames()` used by TCS before calling `itd.open_action_window()` / `itd.open_block_window()`
- ADR-0008: ITD FSM Architecture — `inject_input()` / `advance_frame()` test seams used by TCS unit tests; `force_close_window()` delegation chain
- ADR-0011: Audio System — `begin_combat_layer()` / `end_combat_layer()` APIs that TCS calls directly
- `design/gdd/timing-combat-system.md` — source of all FSM states, interaction table, damage formulas, signal schemas, and all 59 acceptance criteria

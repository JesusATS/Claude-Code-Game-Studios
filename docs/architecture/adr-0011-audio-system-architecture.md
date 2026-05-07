# ADR-0011: Audio System Node Architecture

## Status
Accepted

## Date
2026-05-04

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Foundation (Audio) |
| **Knowledge Risk** | LOW -- AudioStreamPlayer, AudioBus, and AudioServer APIs are stable from Godot 4.0 through 4.6 |
| **References Consulted** | `docs/engine-reference/godot/modules/audio.md`, `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None -- `AudioStreamPlayer.play()`, `AudioStreamPlayer.bus`, `AudioServer.set_bus_volume_db()`, `get_tree().create_timer()` are all stable |
| **Verification Required** | Confirm 5 simultaneous AudioStreamPlayer nodes produce no audio glitches on target hardware. Confirm `create_timer().timeout` signal fires with <=1 frame latency at 60fps. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (Accepted) -- AudioSystem is a composition-root-injected reference, NOT an Autoload; ADR-0004 (Accepted) -- AudioSystem subscribes to CombatEventBus signals for combat audio triggers |
| **Enables** | All audio implementation stories; HUD audio feedback stories; combat grade tone stories |
| **Blocks** | None |
| **Ordering Note** | Must be Accepted before any Audio System implementation story |

## Context

### Problem Statement

Three GDD technical requirements define the Audio System's node-level architecture:

1. **TR-AUD-001**: The music system uses 5 pre-allocated `AudioStreamPlayer` nodes to support simultaneous playback of area music (crossfade pair), combat layer, and APEX condition-phase pair (crossfade pair). Pre-allocation avoids runtime node creation during combat transitions.

2. **TR-AUD-002**: SFX playback uses a pooled system with 2 priority tiers: PROTECTED (grade tones -- never stolen) and STANDARD (ambient, impact SFX -- stealable when pool is full). Total pool size is 12 AudioStreamPlayer nodes. The tier system ensures timing feedback audio (the primary player feedback signal per Pillar 2) is never interrupted.

3. **TR-AUD-003**: `play_sfx_delayed()` uses `get_tree().create_timer().timeout` for frame-accurate delayed playback of staggered SFX (e.g., multi-hit ability sounds). This avoids custom timer management.

### Constraints
- Godot's `AudioStreamPlayer` is the correct node for non-positional 2D audio (no `AudioStreamPlayer2D` needed for a turn-based RPG without spatial audio)
- Audio buses (Music, SFX, UI, Voice) are configured in Godot's Audio Bus Layout (`.tres` file), not in code
- AudioSystem is NOT an Autoload (ADR-0002 qualification: it needs scene-tree access for `create_timer()` but does not qualify as a project-wide singleton -- it subscribes to combat signals that only exist during battle)
- Pool size of 12 was derived from the Audio GDD's analysis of maximum concurrent SFX (grade tone + ability impact + status effect + ambient = 4 simultaneous, with 3x headroom)

### Requirements
- 5 music players pre-allocated as child nodes
- 12 SFX pool nodes pre-allocated as child nodes
- 2-tier priority system: PROTECTED slots never stolen, STANDARD slots use LRU eviction
- Delayed SFX via `create_timer().timeout` -- no custom timer class
- All nodes created in `_ready()`, not at runtime

## Decision

### Rule 1: 5 Pre-Allocated Music Players

The AudioSystem node has 5 `AudioStreamPlayer` children for music:

```gdscript
# Music player roles (pre-allocated in _ready())
var _area_player_a: AudioStreamPlayer    # Current area track
var _area_player_b: AudioStreamPlayer    # Crossfade target
var _combat_player: AudioStreamPlayer    # Combat music layer
var _apex_player_a: AudioStreamPlayer    # APEX phase A
var _apex_player_b: AudioStreamPlayer    # APEX phase B (crossfade)
```

All 5 are created in `_ready()` with `bus = &"Music"`. Crossfading between area tracks uses `_area_player_a` and `_area_player_b` alternately -- one fades out while the other fades in via `Tween`. Combat layer and APEX players follow the same crossfade pattern for their respective transitions.

No music player is created or freed at runtime. Scene transitions change the stream, not the player.

### Rule 2: 12-Slot SFX Pool with 2-Tier Priority

```gdscript
const SFX_POOL_SIZE: int = 12
const PROTECTED_SLOTS: int = 4   # Slots 0-3: grade tones, never stolen
const STANDARD_SLOTS: int = 8    # Slots 4-11: general SFX, LRU eviction

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_last_used: Array[int] = []  # Frame number of last play() call per slot
```

**PROTECTED tier** (slots 0-3): Reserved for grade tones (`PERFECT`, `HIT`, `MISS` feedback) and critical combat feedback. These slots are never evicted. If all 4 PROTECTED slots are playing, a new protected request queues until one finishes (grade tones are short -- 200-500ms).

**STANDARD tier** (slots 4-11): General SFX (ability impacts, status effects, ambient). When all STANDARD slots are playing, the oldest (LRU by frame number) is stopped and reused.

```gdscript
func play_sfx(stream: AudioStream, tier: StringName = &"STANDARD") -> void:
    var slot := _find_available_slot(tier)
    if slot < 0:
        return  # All PROTECTED slots busy, no eviction allowed
    _sfx_pool[slot].stream = stream
    _sfx_pool[slot].play()
    _sfx_last_used[slot] = Engine.get_physics_frames()
```

All 12 SFX pool nodes are created in `_ready()` with `bus = &"SFX"`.

### Rule 3: Delayed SFX via `create_timer().timeout`

```gdscript
func play_sfx_delayed(stream: AudioStream, delay_seconds: float, tier: StringName = &"STANDARD") -> void:
    get_tree().create_timer(delay_seconds).timeout.connect(
        func(): play_sfx(stream, tier)
    )
```

This is the GDD-specified pattern for staggered multi-hit ability sounds. `create_timer()` returns a `SceneTreeTimer` that automatically frees itself after timeout. No custom timer class is needed.

**Constraint**: `play_sfx_delayed()` requires the AudioSystem node to be in the scene tree (`get_tree()` must not return null). This is guaranteed by the composition root pattern (ADR-0002).

### Rule 4: Node Hierarchy

```
AudioSystem (Node)
  ├── AreaPlayerA (AudioStreamPlayer, bus: Music)
  ├── AreaPlayerB (AudioStreamPlayer, bus: Music)
  ├── CombatPlayer (AudioStreamPlayer, bus: Music)
  ├── ApexPlayerA (AudioStreamPlayer, bus: Music)
  ├── ApexPlayerB (AudioStreamPlayer, bus: Music)
  ├── SFXPool_00 (AudioStreamPlayer, bus: SFX)   ← PROTECTED
  ├── SFXPool_01 (AudioStreamPlayer, bus: SFX)   ← PROTECTED
  ├── SFXPool_02 (AudioStreamPlayer, bus: SFX)   ← PROTECTED
  ├── SFXPool_03 (AudioStreamPlayer, bus: SFX)   ← PROTECTED
  ├── SFXPool_04 (AudioStreamPlayer, bus: SFX)   ← STANDARD
  ├── ...
  └── SFXPool_11 (AudioStreamPlayer, bus: SFX)   ← STANDARD
```

Total: 17 child nodes (5 music + 12 SFX). All created in `_ready()`, none freed until the AudioSystem node is freed.

### Rule 5: Audio Bus Layout

The project uses 4 audio buses configured in the Godot Audio Bus Layout (`.tres` file):

| Bus | Purpose | Default Volume |
|-----|---------|---------------|
| Master | Global volume | 0 dB |
| Music | All music players | -6 dB |
| SFX | All SFX pool nodes | 0 dB |
| UI | UI click/hover sounds (future) | -3 dB |

Voice bus is reserved for future dialogue VO but not pre-allocated at MVP.

Volume control via `AudioServer.set_bus_volume_db()` -- exposed through settings UI (not part of this ADR).

## Alternatives Considered

### Alternative 1: Dynamic Node Creation (Create on Play, Free on Finish)
- **Description**: Create an `AudioStreamPlayer` each time `play_sfx()` is called; connect `finished` signal to `queue_free()`
- **Pros**: No pre-allocation; no pool management
- **Cons**: Node creation during combat is a GC pressure source. 12 concurrent SFX = 12 nodes created and freed per combat turn. Godot's `add_child()` / `queue_free()` are not free -- measurable overhead at scale. No priority system possible without additional tracking.
- **Rejection Reason**: The GDD explicitly specifies pre-allocation to avoid runtime node churn during timing-sensitive combat.

### Alternative 2: Single AudioStreamPlayer with Polyphony
- **Description**: Use `AudioStreamPlayer.max_polyphony` property to allow multiple simultaneous streams
- **Pros**: Single node; simpler hierarchy
- **Cons**: `max_polyphony` on a single player shares one bus and one volume. Cannot independently control grade tone volume vs. ambient SFX volume. No priority eviction possible -- Godot's internal polyphony eviction is undocumented and not guaranteed to preserve grade tones.
- **Rejection Reason**: 2-tier priority (PROTECTED grade tones) requires per-slot control. Single-node polyphony cannot provide this.

### Alternative 3: AudioSystem as Autoload
- **Description**: Register AudioSystem as a project Autoload so it persists across scenes
- **Pros**: Music crossfades survive scene transitions naturally
- **Cons**: ADR-0002 limits Autoloads to qualified singletons. AudioSystem subscribes to combat signals (CombatEventBus) that only fire during battle scenes. As an Autoload, it would hold signal connections to a bus that has no emitters outside combat. The composition root pattern (inject AudioSystem reference at scene load) is cleaner.
- **Rejection Reason**: Violates ADR-0002 qualification criteria. Combat audio should live in the battle scene scope.

## Consequences

### Positive
- Zero runtime node allocation during combat -- all 17 nodes pre-exist
- Grade tones (PROTECTED) are never stolen by lower-priority sounds -- Pillar 2 preserved
- `create_timer().timeout` for delayed SFX avoids custom timer management
- Clear node hierarchy makes Inspector debugging straightforward

### Negative
- 17 pre-allocated nodes even when most are idle (acceptable -- AudioStreamPlayer idle cost is negligible)
- PROTECTED tier has a hard cap of 4 -- if a future design requires >4 simultaneous protected sounds, pool size must increase
- AudioSystem must be in the scene tree for `create_timer()` -- cannot be used in headless/test contexts without a SceneTree

### Risks
- **Risk**: 12 SFX pool slots insufficient for a complex multi-hit encounter
  **Mitigation**: STANDARD tier uses LRU eviction. Oldest sound is stopped -- in practice, the oldest SFX is already nearly finished. Pool size is a tuning knob (`SFX_POOL_SIZE` constant).
- **Risk**: `create_timer()` introduces latency >1 frame for delayed SFX
  **Mitigation**: `SceneTreeTimer` fires on the next process frame after the timer expires. At 60fps this is <=16.6ms latency. Acceptable for staggered ability sounds (50-200ms delays).

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| `audio-system.md` | TR-AUD-001: 5 pre-allocated AudioStreamPlayer nodes | Rule 1: 5 music players (area crossfade pair, combat layer, APEX crossfade pair), all created in `_ready()` |
| `audio-system.md` | TR-AUD-002: 2-tier SFX pool (PROTECTED/STANDARD), size=12 | Rule 2: 12-slot pool with PROTECTED (4 slots, never evicted) and STANDARD (8 slots, LRU eviction) |
| `audio-system.md` | TR-AUD-003: play_sfx_delayed() via create_timer().timeout | Rule 3: `play_sfx_delayed()` connects a lambda to `get_tree().create_timer(delay).timeout` |

## Performance Implications
- **CPU**: Negligible -- `AudioStreamPlayer.play()` delegates to the audio thread; pool lookup is O(12) linear scan
- **Memory**: 17 AudioStreamPlayer nodes ~1KB each = ~17KB total (negligible)
- **Load Time**: 17 `add_child()` calls in `_ready()` -- unmeasurable
- **Network**: Not applicable

## Migration Plan

No existing code to migrate. When implementing AudioSystem:
1. Create `src/foundation/audio/audio_system.gd`
2. Declare `class_name AudioSystem extends Node`
3. Create 17 child AudioStreamPlayer nodes in `_ready()`
4. Implement `play_sfx()` with tier-based slot selection
5. Implement `play_sfx_delayed()` with `create_timer()` pattern
6. Configure audio bus layout `.tres` with Music, SFX, UI buses
7. Write unit tests for: pool slot selection (PROTECTED not evicted), LRU eviction in STANDARD tier, delayed playback fires after specified delay

## Validation Criteria

- [ ] AudioSystem._ready() creates exactly 17 child nodes (5 music + 12 SFX)
- [ ] `play_sfx(stream, &"PROTECTED")` uses slots 0-3 only
- [ ] `play_sfx(stream, &"STANDARD")` uses slots 4-11 only
- [ ] When all STANDARD slots are playing, new STANDARD request evicts the oldest
- [ ] When all PROTECTED slots are playing, new PROTECTED request does NOT evict (returns without playing)
- [ ] `play_sfx_delayed(stream, 0.1)` fires play_sfx after ~100ms (within 1 frame tolerance)
- [ ] All 5 music players have `bus = "Music"`
- [ ] All 12 SFX pool players have `bus = "SFX"`
- [ ] No AudioStreamPlayer is created at runtime (no `add_child()` calls after `_ready()`)

## Related Decisions
- ADR-0002: Autoload Singleton Strategy -- AudioSystem is NOT an Autoload; injected via composition root
- ADR-0004: Combat Event Signal Bus -- AudioSystem subscribes to bus for combat audio triggers
- `design/gdd/audio-system.md` -- source of music player architecture, SFX pool design, and delayed playback pattern

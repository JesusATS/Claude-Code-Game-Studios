# Audio System

> **Status**: In Revision (Revision Pass 1 — 2026-05-03)
> **Author**: Jesus Gallegos + agents
> **Last Updated**: 2026-05-03
> **Implements Pillar**: Pillar 2 (Rhythm Is Respect), Pillar 1 (Story Earns Its Emotion)

## Overview

The Audio System is the game's sound layer — it delivers the original soundtrack and every piece of combat feedback audio that makes Lux Aeterna's timing mechanics feel consequential. When a player lands a perfect hit, the Audio System plays the sound that confirms it. When the music swells as a guest character departs, the Audio System crossfades to the emotional cue. When the player adjusts their volume in Settings, the Audio System responds. The system exposes an event-driven interface that all other systems call into — no system needs to know how audio works, only which event to fire. It manages four independent buses (Music, SFX, UI, Voice), crossfading across five pre-allocated music players (area crossfade pair, combat layer, and APEX condition-phase pair), and an SFX pool with priority tiers so that grade tones — the primary player feedback signal — are never stolen by secondary sounds. The player never interacts with the Audio System directly; they interact with combat and story, and the Audio System makes those moments land.

## Player Fantasy

The audio system is the game's most honest voice. When you press the input and land a perfect hit, you know it before the screen confirms — a resonant tone plays in the gap between input and result, and your body registers it as truth. Over time you stop watching for the visual and start listening. Combat becomes a conversation in sound. The audio system is what turns "timing window" from a UI mechanic into something that feels musical, because the grade you earned has a sound that is unmistakably different from the one you didn't.

The soundtrack accumulates emotional weight across the session. A guest character's theme plays through exploration, combat, and quiet dialogue until it becomes the sound of that chapter. When the guest departs, the theme fades. Later, when a few bars surface in a new key inside another area's music, the absence arrives before the player can name it. The music carried the memory without announcing it. This is how Pillars 1 and 3 live in the audio design — dramatic moments are not underscored, they are *prepared*.

Silence is a resource, not a gap. After three combat encounters, the SFX bus goes quiet and a single sustained note carries into a story scene. The player leans in. The audio system does not fill every moment — it knows when to pull back so that the moments that follow land in a space that amplifies them. Volume is managed across four buses precisely so that intimacy and tension can be distinct states, not defaults.

*Implements Pillar 2 (Rhythm Is Respect): audio feedback makes mastery audible, not just visible. Implements Pillar 1 (Story Earns Its Emotion): the soundtrack prepares emotional beats rather than announcing them.*

## Detailed Design

### Core Rules

**1. Bus Structure and Responsibility**

Four independent `AudioServer` buses. No sound crosses bus ownership.

| Bus | Owns | Does NOT Own |
|-----|------|--------------|
| `Music` | All background music: exploration themes, combat layer, cutscene cues, guest-variant area tracks, boss themes | SFX, UI sounds, voice lines |
| `SFX` | All gameplay-origin sounds: combat grade SFX (perfect hit, hit, miss, perfect block, regular block, block failure), world ambience | Music, UI sounds, voice lines |
| `UI` | Interface sounds: menu cursor, confirm, cancel, menu open/close | Music, SFX, voice lines |
| `Voice` | Reserved for future VO assets. No tracks are routed through this bus in Episode 1. | Everything currently active |

Bus master volume is set exclusively via `AudioServer.set_bus_volume_db()`. No other volume mechanism is used.

**2. Music Playback Model — Three-Player Architecture**

Rule 2.1 — The Music layer uses five pre-allocated `AudioStreamPlayer` nodes: `MusicPlayerA`, `MusicPlayerB`, `CombatLayerPlayer`, `ApexLayerPlayerA`, and `ApexLayerPlayerB`. `MusicPlayerA` and `MusicPlayerB` handle area music crossfades; they alternate as active/standby players. `CombatLayerPlayer` handles the additive combat layer for standard encounters (see Rule 2.9). `ApexLayerPlayerA` and `ApexLayerPlayerB` handle APEX boss condition-phase ambient stems and crossfades between condition phases (see Rules 2.15–2.20). All five players are pre-allocated at scene load — none are created at runtime.

Rule 2.2 — Music is requested via `play_music(track_id: StringName, transition: StringName)`. `track_id` identifies the track resource. `transition` is one of `&"crossfade"`, `&"immediate"`, or `&"finish_then_play"`. The Audio System owns the lookup from `track_id` to `AudioStream` resource — no caller passes a resource directly.

Rule 2.3 — Crossfade transition: the standby player loads the new track and begins playback at -∞ dB. A `Tween` ramps the active player to -∞ dB and simultaneously ramps the standby player to the Music bus target volume over `MUSIC_CROSSFADE_DURATION_SEC` (default: 1.5 seconds). On completion, the formerly active player stops and the A/B roles swap. The `CombatLayerPlayer` state is preserved through area transitions — if combat is active, it keeps playing.

Rule 2.4 — Immediate transition: the active player stops with no fade. The standby player loads and begins the new track at full bus volume. Roles swap. Reserved for hard cuts (abrupt narrative moments, instant scene changes) — may be used by the Cutscene System.

Rule 2.5 — Finish-then-play: the active player plays to completion via the `finished` signal (not `_process()`). On `finished`, the standby player begins the new track. Used for one-shot completion cues and intro-to-loop handoffs.

Rule 2.6 — Intro-loop structure: a track flagged `has_intro: true` consists of two resources — a one-shot intro stream and a looping stream. On `play_music()`, the intro loads on the active player with `loop = false`. When `finished` fires, the loop stream replaces it with `loop = true`. The pair is treated as one logical track.

Rule 2.7 — Idempotency: if `play_music()` is called with the same `track_id` as the currently playing track, no action is taken. Prevents spurious restarts when combat and exploration both assume responsibility for music on the same frame.

Rule 2.8 — During crossfade, if a second `play_music()` call arrives, it is queued (depth 1 — only the final queued request is retained). The in-progress crossfade completes normally; the queued request begins immediately after. This prevents audible glitches from overlapping fades.

**3. Music Playback Model — Combat Layer**

Rule 2.9 — On area entry, `CombatLayerPlayer` loads the combat layer stem for the current area (if one exists) and begins playback simultaneously with the active area player at -∞ dB (inaudible). Both players start together so they are always in phase. Areas without a combat stem skip this step — `CombatLayerPlayer` remains stopped.

Rule 2.10 — When combat begins (via `begin_combat_layer()` method call from the Timing Combat System), a `Tween` ramps `CombatLayerPlayer` volume from -∞ dB to 0 dB over `COMBAT_LAYER_FADE_IN_SEC` (default: 1.5s). The active area player continues at full volume, uninterrupted.

Rule 2.11 — When combat ends (via `end_combat_layer()` method call from the Timing Combat System), a `Tween` ramps `CombatLayerPlayer` volume from 0 dB to -∞ dB over `COMBAT_LAYER_FADE_OUT_SEC` (default: 2.0s). The area player continues uninterrupted. The combat layer player remains running at -∞ dB and stays in phase for the next encounter in the same area.

Rule 2.12 — If an area transition is requested while the combat layer is active, `end_combat_layer()` is called first. The area music transition waits `COMBAT_LAYER_FADE_OUT_SEC` before crossfading, or proceeds immediately if `&"immediate"` transition is requested.

**4. Guest Theme Support**

Rule 2.13 — Guest character themes are embedded in area music as compositional variants, not as separately triggered tracks. When a guest joins, the Guest Character System calls `play_music(area_guest_track_id, &"crossfade")` to transition from the base area variant to the guest-leitmotif variant. When the guest departs, it calls `play_music(area_base_track_id, &"crossfade")` to return to the base variant. The Audio System has no knowledge of why a track change is requested — it only executes the transition.

Rule 2.14 — Guest arrival stinger: a short one-shot stinger plays on the `Music` bus the moment a guest walks on screen, before the crossfade to the guest area variant. This is requested via `play_music(guest_stinger_id, &"finish_then_play")` followed immediately by `play_music(area_guest_track_id, &"crossfade")`. The stinger completes, then the guest area variant begins.

**5. APEX Condition-Phase Music Model**

Rule 2.15 — APEX encounter detection: on `encounter_started(enemy_ids)` from the Timing Combat System, the Audio System checks whether any enemy in the roster is an APEX archetype (via `EnemyData.is_apex: bool` field in config). If an APEX enemy is present, the APEX layer is initialised for that encounter.

Rule 2.16 — `begin_apex_layers(apex_enemy_id: StringName)` is called by the Timing Combat System when an APEX enemy is detected. The Audio System loads the UNWOUNDED condition-phase stem for `apex_enemy_id` onto `ApexLayerPlayerA` at -∞ dB, starts playback simultaneously with `CombatLayerPlayer` (in phase at position 0.0), then fades `ApexLayerPlayerA` to 0 dB over `APEX_LAYER_FADE_IN_SEC` (default: 1.5 s) via normalised tween. `ApexLayerPlayerB` remains loaded and stopped as the standby player.

Rule 2.17 — On `enemy_condition_changed(instance_id, old_state, new_state, stinger_tier)` where the changed enemy is the active APEX enemy: the Audio System crossfades the active APEX player (whichever of A/B is playing) to the new condition-phase stem on the standby player. The active player fades to -∞ dB; the standby loads the new stem and fades to 0 dB over `APEX_LAYER_CROSSFADE_SEC` (default: 1.0 s). Roles swap on completion. Mapping `(apex_enemy_id, condition_state) → stem resource` is owned by the Audio System's configuration data.

Rule 2.18 — Condition stingers: on `enemy_condition_changed`, if `stinger_tier` is non-empty, the Audio System calls `play_sfx(stinger_sfx_id)` where `stinger_sfx_id` is looked up from config as `(stinger_tier) → sfx_id`. Standard enemies without a stinger set `stinger_tier = &""` — no stinger plays. Stinger SFX are `STANDARD` pool tier.

Rule 2.19 — `end_apex_layers()` is called by the Timing Combat System at encounter end. Both `ApexLayerPlayerA` and `ApexLayerPlayerB` fade to -∞ dB over `APEX_LAYER_FADE_OUT_SEC` (default: 2.0 s) then stop. `CombatLayerPlayer` fade-out proceeds independently per Rule 2.11.

Rule 2.20 — APEX phase synchronisation: `ApexLayerPlayerA` starts simultaneously with `CombatLayerPlayer` on `begin_apex_layers()` (position 0.0 on both). The in-phase guarantee matches Rule 2.9. If phase drift exceeds 0.05 s, restart the active APEX player at `CombatLayerPlayer.get_playback_position()`. Recovery path only.

---

**6. SFX Playback Model**

Rule 3.1 — SFX play from a pre-allocated pool of `AudioStreamPlayer` nodes. Pool size: `SFX_POOL_SIZE` (default: 8). No `AudioStreamPlayer` nodes are created at runtime.

Rule 3.2 — SFX are requested via `play_sfx(sfx_id: StringName)`. The Audio System owns the lookup from `sfx_id` to `AudioStream`. No caller passes a resource directly.

Rule 3.3 — Pool allocation: on `play_sfx()`, the system finds the first idle pool player (`is_playing() == false`). If no idle player exists, the steal algorithm applies SFX priority tiers:

**Priority tiers** (encoded per `sfx_id` in configuration data as `sfx_priority: StringName`):
- `&"PROTECTED"` — Grade tones (MISS/HIT/PERFECT), CC gain chime (fired when `cc_changed` has `source_type = "window_grade"`), HP danger zone tone. A playing PROTECTED player is **never stolen** regardless of remaining time.
- `&"STANDARD"` — All other SFX: status apply stings, status expiry stings, condition stingers, incapacitation SFX, ability sounds.

**Steal logic:** (1) Find any idle player (`is_playing() == false`) — steal it first. (2) If none, find the STANDARD player with shortest `T_remaining = T_length - T_position`. (3) If all active players are PROTECTED and no STANDARD players are active, the new SFX is silently dropped and a warning is logged — a pool of exclusively protected sounds cannot yield a slot to a standard sound. (4) A PROTECTED player is never stolen while any STANDARD player is active.

Rule 3.4 — Pool player idle state is tracked exclusively via the `finished` signal connected at initialization. `_process()` is never used to poll playback state.

Rule 3.5 — Combat grade SFX are triggered by the Audio System listening to `window_closed(grade)` from Input & Timing Detection. The Audio System tracks `current_mode` from the preceding `input_result(mode, grade)` signal (both are co-emitted on the same frame — no race condition). The mapping from `(mode, grade)` to `sfx_id` is owned by the Audio System's configuration data, not hardcoded.

Rule 3.6 — UI nodes call `play_sfx(sfx_id)` directly for menu navigation sounds. These pool players are assigned to the `UI` bus, not the `SFX` bus. The pool player's bus assignment is reset to the pool default (`&"SFX"`) at steal time or at `finished` callback — a rerouted UI player does not remain on the `UI` bus permanently.

Rule 3.7 — `play_sfx_delayed(sfx_id: StringName, delay_sec: float)` schedules an SFX to play after `delay_sec` seconds. Implementation: `get_tree().create_timer(delay_sec).timeout` signal connected to `play_sfx(sfx_id)`. The callback validates `is_instance_valid(self)` before calling `play_sfx()`. Default delay for status apply stings: `STING_DELAY_SEC` (default: 0.1 s, 100 ms) — this gives the grade tone onset primacy before the status sting fires. Delayed calls do not reserve a pool slot; the pool state at fire time determines allocation.

Rule 3.8 — Status effect signal handling: the Audio System subscribes to `status_effect_applied` and `status_effect_expired` from the Status Effects system.
- `status_effect_applied(combatant_id, effect_id, ..., is_refresh: bool)` with `is_refresh == false` → `play_sfx_delayed(sfx_apply_id, STING_DELAY_SEC)`. With `is_refresh == true` → no audio (refresh is silent; the sting does not replay).
- `status_effect_expired(combatant_id, effect_id, cause)` with `cause = &"natural"` → `play_sfx(sfx_expire_id)` if `sfx_expire_id` is non-empty. `cause = &"incapacitated"` or `&"encounter_end"` → no audio.
- `sfx_apply_id` and `sfx_expire_id` are fields on `StatusEffectData`, looked up by `effect_id` via the Status Effects data registry. Both are `STANDARD` pool tier.

Rule 3.9 — Enemy condition signal handling: the Audio System subscribes to `enemy_condition_changed(instance_id, old_state, new_state, stinger_tier)` from the Timing Combat System. If the changed enemy is the active APEX enemy for this encounter, apply the condition-phase stem crossfade per Rule 2.17. Regardless of APEX status, if `stinger_tier` is non-empty, play the condition stinger per Rule 2.18. For standard enemies, if no stinger config entry exists for the tier, the call is silently ignored.

Rule 3.10 — Combat event signal handling: the Audio System subscribes to `hp_danger_zone_entered(combatant_id)`, `combatant_incapacitated(combatant_id, is_enemy: bool)`, and `encounter_started(enemy_ids)` from the Timing Combat System.
- `hp_danger_zone_entered` → `play_sfx(sfx_hp_danger_tone_id)`. This tone is `PROTECTED` pool tier. Re-fires on re-entry (TCS re-emits the signal when a combatant re-crosses the 25% HP threshold after being healed above it).
- `combatant_incapacitated` with `is_enemy == true` → look up `EnemyData.sfx_incapacitated_id` from config and `play_sfx(sfx_incapacitated_id)`. `is_enemy == false` → no SFX defined at MVP.
- `encounter_started(enemy_ids)` → detect APEX archetype per Rule 2.15 and call `begin_apex_layers()` if applicable.

Rule 3.11 — CC chime suppression: the Audio System subscribes to `cc_changed(new_cc: int, delta: int, source_type: StringName)` from the Timing Combat System. When `source_type == &"window_grade"` → `play_sfx(sfx_cc_gain_chime_id)`. When `source_type == &"ability_delta"` → no audio. The CC chime is a mastery signal; non-window CC gains (e.g., from `timing_optional` abilities) do not earn the chime. CC chime is `PROTECTED` pool tier.

Rule 3.12 — MUTED status audio hook: the MUTED status effect requires a muffled character on the affected combatant's attack SFX. Implementation: pre-baked `_muted` asset variants. Every attack SFX affected by MUTED has a corresponding `sfx_id_muted` variant in the SFX config (e.g., `&"sfx_ne_attack"` has companion `&"sfx_ne_attack_muted"`). `play_sfx()` accepts an optional combatant parameter: `play_sfx(sfx_id: StringName, combatant_id: StringName = &"")`. When `combatant_id` is non-empty and that combatant has MUTED active (`_muted_combatants` internal set), the Audio System appends `"_muted"` to the `sfx_id` and looks up the variant; if the variant does not exist, the unfiltered version plays as fallback. MUTED state is tracked internally: `status_effect_applied` for MUTED with `is_refresh == false` → add to `_muted_combatants`; `status_effect_expired` for MUTED → remove from `_muted_combatants`.

Rule 3.13 — SFX bus ducking: SFX events configured with `plays_duck: true`, `duck_db: float`, and `duck_duration_ms: float` in their config data trigger a brief SFX bus volume reduction immediately on playback. Implementation: immediately on pool allocation, call internal `_duck_sfx_bus(duck_db, duck_duration_ms / 1000.0)`. This method: reads the current SFX bus volume via `AudioServer.get_bus_volume_db()`, subtracts `duck_db` (e.g., −6.0), applies via `AudioServer.set_bus_volume_db()`, then schedules restoration via `get_tree().create_timer(duration_sec)`. Duration in milliseconds avoids visual-frame vs. audio-frame ambiguity. If a duck is already active when a second duck fires, retain the higher reduction and the longer remaining duration.

**6. Volume Control Model**

Rule 4.1 — The Menu & Settings System is the sole authority for setting bus volumes. It calls `set_bus_volume(bus_name: StringName, normalized_value: float)` where `normalized_value` is in [0.0, 1.0]. The Audio System converts to dB (see Formulas) and calls `AudioServer.set_bus_volume_db()`.

Rule 4.2 — No gameplay system sets bus volumes directly. All music and SFX requests go through the Audio System's interface.

Rule 4.3 — `get_bus_volume(bus_name) -> float` returns the current normalized volume for slider initialization. Only the Menu & Settings System calls this getter.

Rule 4.4 — Volume state is not persisted by the Audio System. The Save/Settings System is responsible for restoring volumes on session start by calling `set_bus_volume()`.

### States and Transitions

**Music FSM** (governs MusicPlayerA and MusicPlayerB for area music):

| State | Description |
|-------|-------------|
| `SILENT` | Both `MusicPlayerA` and `MusicPlayerB` are stopped. Initial state. |
| `PLAYING` | One player is active at full bus volume. The other is stopped. |
| `PLAYING_INTRO` | The active player is playing the one-shot intro of an intro-loop track. Always resolves to `PLAYING` when the intro's `finished` fires. |
| `CROSSFADING` | Both players are active: the outgoing fades out, the incoming fades in via Tween. New `play_music()` calls during this state are queued (depth 1). |

| From | Trigger | To | Action |
|------|---------|----|--------|
| `SILENT` | `play_music(id, any)` (non-intro track) | `PLAYING` | Load on standby, play at full volume. Swap roles. No tween needed. |
| `SILENT` | `play_music(id, any)` (intro track, `has_intro: true`) | `PLAYING_INTRO` | Load intro on active player. Connect `finished`. |
| `PLAYING` | `play_music(new_id, &"crossfade")` | `CROSSFADING` | Load new track on standby at -∞ dB. Start Tween. |
| `PLAYING` | `play_music(new_id, &"immediate")` | `PLAYING` | Stop active. Load new on standby at full volume. Swap roles. State remains `PLAYING`. |
| `PLAYING` | `play_music(new_id, &"finish_then_play")` | `PLAYING` | Connect `finished` on active; new track begins when it fires. State remains `PLAYING`. |
| `PLAYING` | Active `finished` fires (one-shot non-looping track ends) | `SILENT` | No queued request. Both stopped. |
| `PLAYING_INTRO` | `finished` fires (intro completes) | `PLAYING` | Load loop stream on same player with `loop = true`. |
| `PLAYING_INTRO` | `play_music(new_id, *)` | `CROSSFADING` | Treat intro player as outgoing. Begin crossfade. |
| `CROSSFADING` | Tween completes | `PLAYING` | Stop outgoing player. Swap roles. Process any queued request. |
| `CROSSFADING` | `play_music(new_id, *)` received | `CROSSFADING` (continues) | Queue request, replacing any prior queued request. |
| Any | `stop_music()` | `SILENT` | Stop both players. Cancel Tween. Clear queue. |

**Combat Layer Dimension** (independent of Music FSM; governs CombatLayerPlayer):

| State | Trigger | To | Action |
|-------|---------|----|----|
| `LAYER_SILENT` | `begin_combat_layer()` (no stem for this area) | `LAYER_SILENT` | No-op. |
| `LAYER_SILENT` | `begin_combat_layer()` (stem loaded, in phase) | `LAYER_FADING_IN` | Tween volume -∞ dB → 0 dB over `COMBAT_LAYER_FADE_IN_SEC`. |
| `LAYER_FADING_IN` | Tween completes | `LAYER_ACTIVE` | — |
| `LAYER_ACTIVE` | `end_combat_layer()` | `LAYER_FADING_OUT` | Tween volume 0 dB → -∞ dB over `COMBAT_LAYER_FADE_OUT_SEC`. |
| `LAYER_FADING_OUT` | Tween completes | `LAYER_SILENT` | Player remains running at -∞ dB in phase. |
| Any | Area transition | — | `end_combat_layer()` called first; player reloaded on area entry. |

**APEX Layer Dimension** (independent of Music FSM and Combat Layer; governs ApexLayerPlayerA/B pair):

| State | Trigger | To | Action |
|-------|---------|----|----|
| `APEX_INACTIVE` | `begin_apex_layers(apex_enemy_id)` | `APEX_FADING_IN` | Load UNWOUNDED stem on ApexLayerPlayerA at -∞ dB; start in phase with CombatLayerPlayer; begin fade-in tween. |
| `APEX_FADING_IN` | Tween completes | `APEX_ACTIVE` | — |
| `APEX_ACTIVE` | `enemy_condition_changed` (new phase for this APEX) | `APEX_CROSSFADING` | Load new condition stem on standby APEX player; begin crossfade over `APEX_LAYER_CROSSFADE_SEC`. |
| `APEX_CROSSFADING` | Tween completes | `APEX_ACTIVE` | Stop outgoing APEX player; swap ApexLayerPlayerA/B roles. |
| `APEX_ACTIVE` or `APEX_FADING_IN` | `end_apex_layers()` | `APEX_FADING_OUT` | Fade active APEX player to -∞ dB over `APEX_LAYER_FADE_OUT_SEC`. |
| `APEX_FADING_OUT` | Tween completes | `APEX_INACTIVE` | Stop both ApexLayerPlayers. |
| Any | Area transition with `&"immediate"` | `APEX_INACTIVE` | Stop both players immediately. |

**SFX Pool**: No FSM. Each pool player is binary: idle (`is_playing() == false`) or playing. The `finished` signal transitions playing → idle.

### Interactions with Other Systems

| System | Sends / Requests | Audio Response | Interface Owner | Dependency |
|--------|-----------------|----------------|-----------------|------------|
| **Input & Timing Detection** | `input_result(mode, grade)` signal | Stores `current_mode` for next `window_closed` handler | I&TD owns signal; Audio owns listener | Soft |
| **Input & Timing Detection** | `window_closed(grade)` signal | Calls `play_sfx()` with SFX mapped to `(current_mode, grade)` from config data | I&TD owns signal; Audio owns mapping | Soft |
| **Timing Combat System** | `play_music(track_id, transition)` — combat/boss music request | Begins music transition per Rules 2.2–2.8 | TCS owns when/which; Audio owns how | Soft |
| **Timing Combat System** | `begin_combat_layer()` / `end_combat_layer()` method calls | Fades combat stem in/out per Rules 2.10–2.11 | TCS owns timing; Audio owns execution | Soft |
| **Timing Combat System** | `encounter_started(enemy_ids)` signal | Detects APEX archetype; calls `begin_apex_layers()` if applicable (Rule 2.15) | TCS owns timing; Audio owns detection + execution | Soft |
| **Timing Combat System** | `begin_apex_layers(apex_enemy_id)` / `end_apex_layers()` method calls | Initialises/tears down APEX condition-phase stems (Rules 2.16–2.19) | TCS owns when; Audio owns execution | Soft |
| **Timing Combat System** | `enemy_condition_changed(instance_id, old_state, new_state, stinger_tier)` signal | Crossfades APEX stem to new phase (Rule 2.17); plays condition stinger (Rule 2.18) | TCS/ES own emission; Audio owns response | Soft |
| **Timing Combat System** | `cc_changed(new_cc, delta, source_type)` signal | Plays CC gain chime when `source_type = "window_grade"`; suppresses for `source_type = "ability_delta"` (Rule 3.11) | TCS owns emission; Audio owns suppression logic | Soft |
| **Timing Combat System** | `hp_danger_zone_entered(combatant_id)` signal | Plays `sfx_hp_danger_tone_id` (PROTECTED tier); re-fires on re-entry (Rule 3.10) | TCS owns emission; Audio owns response | Soft |
| **Timing Combat System** | `combatant_incapacitated(combatant_id, is_enemy: bool)` signal | Plays `sfx_incapacitated_id` for enemy incapacitation (Rule 3.10) | TCS owns emission; Audio owns response | Soft |
| **Status Effects** | `status_effect_applied(combatant_id, effect_id, ..., is_refresh: bool)` signal | Plays `sfx_apply_id` delayed 100 ms when `is_refresh == false`; silent on refresh (Rule 3.8) | SE owns emission; Audio owns playback + suppression | Soft |
| **Status Effects** | `status_effect_expired(combatant_id, effect_id, cause)` signal | Plays `sfx_expire_id` when `cause = "natural"` only; silent for `"incapacitated"` / `"encounter_end"` (Rule 3.8) | SE owns emission; Audio owns cause-gating | Soft |
| **Guest Character System** | `play_music(guest_stinger_id, &"finish_then_play")` on arrival; `play_music(area_guest_track_id, &"crossfade")` after stinger; `play_music(area_base_track_id, &"crossfade")` on departure | Executes the transition; no return value | GCS owns when and which track; Audio owns how | Soft |
| **World Exploration / Scene Management** | `play_music(track_id, transition)` on area entry; loads combat stem on `CombatLayerPlayer` simultaneously | Begins area music; starts combat layer at -∞ dB in phase | Scene/World owns when; Audio owns execution | Soft |
| **Cutscene System** | `play_music(track_id, transition)` or `stop_music()` for intentional silence | Executes transition or stop | Cutscene System owns when; Audio owns how | Soft |
| **Menu & Settings System** | `set_bus_volume(bus_name, normalized_value)` | Converts to dB, calls `AudioServer.set_bus_volume_db()` | Settings owns value/timing; Audio owns conversion | Hard |
| **Menu & Settings System** | `get_bus_volume(bus_name) -> float` | Returns current normalized [0.0, 1.0] | Settings owns read timing; Audio owns storage | Hard |
| **HUD / UI nodes** | `play_sfx(sfx_id)` for UI navigation sounds (cursor, confirm, cancel) | Allocates UI-bus pool player and plays stream | Calling node owns when; Audio owns playback | Soft |
| **Save System** | No direct interaction | Audio System holds no persistent state | N/A | None |

**Intentional non-dependencies**: The Audio System does not read story flags, character stats, damage numbers, or party composition. All music *selection* decisions are delegated to the requesting system; the Audio System executes what it is told to play and responds to the combat-event signals listed above. It does not query HP values or enemy identity directly — all combat-state information arrives via signals from TCS and SE.

## Formulas

The Audio System defines two named formulas. Three additional mathematical relationships are noted in Edge Cases.

---

**The NORMALIZED_TO_DB formula is defined as:**

`dB = -INF  (if n ≤ 0.0)` / `dB = 20 × log10(n)  (if n > 0.0)`

The input `n` is **pre-clamped to [0.0, 1.0] inside the conversion function** before any branch is evaluated. Negative inputs are clamped to 0.0 (treated as silence). This clamp must be applied by the conversion function itself — not only by `set_bus_volume()` — so that any internal caller is protected. A Tween floating-point overshoot (e.g., n = 1.0000001) is clamped to 1.0 before the log10 branch, preventing a positive dB result.

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Normalized volume | n | float | [0.0, 1.0] | Input clamped to this range before branch evaluation |
| Decibel value | dB | float | (-INF, 0.0] | Output passed to `AudioServer.set_bus_volume_db()` |

**Output Range:** (-INF, 0.0]. Upper-bounded at 0 dB (no amplification). Lower-bounded at -INF (AudioServer treats -INF as complete silence). The formula does not clamp on the low end — the n ≤ 0.0 branch returns -INF correctly.

**Edge case — n = 0.0:** `log10(0)` is undefined; the branch returns -INF, which AudioServer accepts as muted. Do not use an epsilon floor (e.g., `max(0.0001, n)`) — doing so would prevent the slider from reaching true silence.

**Edge case — n < 0.0:** Clamped to 0.0 before branch evaluation. `log10(negative)` returns NaN in GDScript; this path must never be reached. The clamp inside the conversion function is the guard.

**Example:**

| n (slider position) | Calculation | dB result | Perceived loudness |
|---------------------|-------------|-----------|-------------------|
| 0.00 | -INF (branch) | -INF dB | Silence (muted) |
| 0.25 | 20 × log10(0.25) | -12.04 dB | ~25% perceived loudness |
| 0.50 | 20 × log10(0.50) | -6.02 dB | ~50% perceived loudness |
| 0.75 | 20 × log10(0.75) | -2.50 dB | ~75% perceived loudness |
| 1.00 | 20 × log10(1.00) | 0.00 dB | Full volume, no attenuation |

*Note: GDScript provides `linear_to_db(n)` as a built-in that implements this exact formula including the -INF case. The inverse — used by `get_bus_volume()` — uses `db_to_linear(dB)` (GDScript built-in). Neither function needs to be reimplemented manually.*

---

**The REMAINING_PLAYBACK_TIME formula is defined as:**

`T_remaining = T_length - T_position`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Stream total length | T_length | float | [0.0, +INF) | Total stream duration in seconds, from `AudioStream.get_length()` |
| Current playback position | T_position | float | [0.0, T_length] | Current position in seconds, from `AudioStreamPlayer.get_playback_position()` |
| Remaining time | T_remaining | float | [0.0, T_length] | Remaining playback time; used to select the pool steal candidate |

**Output Range:** [0.0, T_length] under normal conditions. The guard below covers the degenerate cases.

**Guard:** `if T_length == 0.0 OR T_position > T_length: T_remaining = INF`. This covers two cases: (a) streaming assets whose length is not yet known (`T_length = 0.0`), and (b) Ogg Vorbis streaming assets whose `get_length()` returns a small positive value before full buffering while `T_position` has already advanced past it — producing a negative raw result. Players with `T_remaining = INF` are never selected as steal candidates unless all pool players report `INF`.

**Example:**

Pool of 3 occupied players when a 4th SFX is requested:

| Player | T_length | T_position | T_remaining |
|--------|----------|------------|-------------|
| Pool[0] | 2.0s | 0.3s | 1.7s |
| Pool[1] | 1.5s | 1.2s | **0.3s ← stolen** |
| Pool[2] | 3.0s | 0.5s | 2.5s |

Pool[1] is stolen because it has the least time remaining.

---

*Note: Three additional mathematical relationships are noted in Edge Cases: (1) the crossfade tween ease mode constraint, (2) the combat layer fade-in tween strategy (normalize, not dB), and (3) the db_to_linear inverse for `get_bus_volume()`. These are implementation constraints, not named formulas.*

## Edge Cases

### Music — play_music() Boundary States

- **If `play_music()` is called while FSM is `SILENT` with a non-looping, non-intro track**: Load on the active player and begin playback. When `finished` fires and no queue exists, transition to `SILENT`. No error.
- **If `play_music()` is called while FSM is `SILENT` with an intro-loop track (`has_intro: true`)**: Transition to `PLAYING_INTRO`. Connect `finished` on the active player. When `finished` fires, load the loop stream with `loop = true` and transition to `PLAYING`.
- **If `play_music()` is called with the same `track_id` as the currently active track** (any FSM state): No action taken. No restart, no fade, no queue entry. This idempotency guard prevents spurious restarts when multiple systems (e.g., Timing Combat System and World Exploration) assume ownership of music state on the same frame.
- **If `play_music(id, &"crossfade")` is called while already in `CROSSFADING`**: The new request is queued (replacing any prior queued request — queue depth 1). The in-progress crossfade completes normally. Immediately after the tween completes and roles swap, the queued request is dispatched.
- **If `play_music(id, &"immediate")` is called while in `CROSSFADING`**: Treat as override. Cancel the in-progress tween immediately. Stop both players. Load the new track on the next standby player at full volume. Swap roles. Transition to `PLAYING`. Clear any queued request.
- **If `play_music(id, &"finish_then_play")` is called while the active track is already looping** (loop = true): The active track loops forever and `finished` never fires. This is a caller bug — `finish_then_play` must only be issued against tracks known to be non-looping (stingers, one-shots, intros). The Audio System does not validate this; callers are responsible.
- **If `play_music()` is called while FSM is `PLAYING_INTRO`**: Treat the intro player as the outgoing track. Begin a crossfade from the intro player to the new track. Transition to `CROSSFADING`. Disconnect the `finished` listener on the intro player before beginning the crossfade to prevent a stale intro-completion signal from triggering a spurious loop load.
- **If the intro stream's `finished` fires during a crossfade** (i.e., the intro player was set as outgoing mid-intro): Ignore the signal. The `finished` listener must be disconnected before the crossfade begins to prevent this case. If the listener was not disconnected, the signal fires and attempts to load the loop stream on a player that is already fading out — this must be guarded by checking whether the player is currently the active (not outgoing) player before acting on `finished`.
- **If area transition occurs while FSM is `PLAYING_INTRO`**: The outgoing player (playing the intro) begins fading. Disconnect the `finished` listener before the crossfade begins to suppress the intro completion handler.
- **If a track resource cannot be loaded** (missing file, corrupt asset): Log an error. Do not crash. FSM state remains unchanged — the Audio System continues operating without audio rather than entering an undefined state.

### Music — stop_music() and MUSIC_CROSSFADE_DURATION_SEC

- **If `stop_music()` is called while FSM is `SILENT`**: No-op. No error.
- **If `stop_music()` is called while FSM is `CROSSFADING`**: Cancel the tween immediately. Stop both players. Clear any queued request. Transition to `SILENT`. No fade-out — `stop_music()` is a hard cut.
- **If `stop_music()` is called while FSM is `PLAYING_INTRO`**: Stop the active player. Disconnect the `finished` listener to suppress the intro completion handler. Transition to `SILENT`.
- **If `MUSIC_CROSSFADE_DURATION_SEC` is set to 0.0**: The crossfade tween has zero duration. Treat as an immediate cut — skip the tween, stop the outgoing player, bring the incoming player to full volume immediately, swap roles. Do not create a zero-duration tween.

### Combat Layer Edge Cases

- **If `begin_combat_layer()` is called for an area with no combat stem loaded**: No-op. `LAYER_SILENT` → `LAYER_SILENT`. No error. The Audio System checks whether `CombatLayerPlayer` has a stream loaded before acting.
- **If `begin_combat_layer()` is called while state is `LAYER_FADING_IN`** (already fading in): No-op. Let the in-progress tween complete.
- **If `begin_combat_layer()` is called while state is `LAYER_ACTIVE`**: No-op. The stem is already fully audible.
- **If `begin_combat_layer()` is called while state is `LAYER_FADING_OUT`** (mid-fade-out from a previous combat): Cancel the outgoing tween. Read `V_current` — the normalized volume at the moment of interruption (do not snap to 0.0). Start a new fade-in tween from `V_current` to 1.0. Transition to `LAYER_FADING_IN`. This prevents an audible volume snap.
- **If `end_combat_layer()` is called while state is `LAYER_SILENT`**: No-op.
- **If `end_combat_layer()` is called while state is `LAYER_FADING_OUT`**: No-op. Let the in-progress tween complete.
- **If `end_combat_layer()` is called while state is `LAYER_FADING_IN`** (combat ended before the stem fully faded in): Cancel the incoming tween. Read `V_current`. Start a fade-out tween from `V_current` to 0.0. Transition to `LAYER_FADING_OUT`. This prevents an audible snap to silence.
- **If an area transition is requested while state is `LAYER_ACTIVE` or `LAYER_FADING_IN`**: Call `end_combat_layer()` first. If the area music transition type is `&"crossfade"` or `&"finish_then_play"`, wait `COMBAT_LAYER_FADE_OUT_SEC` before initiating the music crossfade. If transition type is `&"immediate"`, skip the wait and cut both players simultaneously.
- **If `CombatLayerPlayer` falls out of phase with the area player** (e.g., due to a timing bug or manual seek): The in-phase guarantee only holds if both players started simultaneously on area entry. If phase drift is detected (implementation-defined — e.g., position delta > 0.05s), stop and restart `CombatLayerPlayer` at the matching position. This is a recovery path, not expected behavior.

### SFX Pool Edge Cases

- **If `play_sfx()` is called with an unrecognized `sfx_id`**: Log a warning. Do not crash. Do not allocate a pool player. Return silently. Unknown SFX IDs indicate a configuration gap, not a runtime failure.
- **If `SFX_POOL_SIZE` is set to 0**: `play_sfx()` always finds no available players and no stealable players. All SFX calls are silently dropped. This is a valid configuration for profiling or debugging but produces no audio. Log a warning on initialization.
- **If all pool players are active and `T_length` is 0.0 for any candidate** (stream length unknown): Treat that candidate's `T_remaining` as +INF for comparison purposes — never steal a player whose remaining time cannot be computed. A player with unknown stream length may have just started or may be a streaming asset whose length is not yet available. Use a guard: `if T_length == 0.0: T_remaining = INF`.
- **If the `finished` signal fires on a pool player while the steal-candidate iteration is in progress** (edge case in single-threaded GDScript): The signal fires at the end of the current frame, after `_physics_process` completes. Pool state changes from `finished` are deferred to the next frame. This is not a true race condition in GDScript — the iteration is safe.
- **If `play_sfx()` is called with a `sfx_id` mapped to the `UI` bus**: The pool player must be assigned to the `UI` bus, not `SFX`. The Audio System's SFX configuration data must record the intended bus per `sfx_id`. Callers do not specify the bus — the Audio System resolves it from config.

### Volume Control Edge Cases

- **If `set_bus_volume()` receives a `normalized_value` outside [0.0, 1.0]**: Clamp to [0.0, 1.0] before applying NORMALIZED_TO_DB. Log a warning. Do not propagate an out-of-range value to `AudioServer`.
- **If `set_bus_volume()` is called before a `play_music()` or `play_sfx()` call on the same frame**: The volume is set immediately. Any subsequent playback on that frame uses the new volume. Callers should not depend on a specific ordering; the Audio System does not guarantee sequencing between unrelated callers.
- **If `set_bus_volume()` is called with an unrecognized `bus_name`**: Log a warning. Do not call `AudioServer.set_bus_volume_db()`. This prevents silently creating a new AudioServer bus or modifying the wrong bus.

### Signal Handling Edge Cases

- **If `window_closed(grade)` fires but `current_mode` has not been set** (i.e., no preceding `input_result` on the same frame): Log a warning and skip SFX playback for this event. This indicates a signal-connection ordering bug — `input_result` must be connected before `window_closed` in `_ready()` to guarantee `current_mode` is set before the SFX lookup.
- **If `window_closed(grade)` fires twice on the same frame** (malformed signal emission): The second call uses the same `current_mode` stored from `input_result`. Both calls attempt to allocate a pool player — if a player is available, two SFX play. This is a caller-side bug in Input & Timing Detection; the Audio System does not de-duplicate.
- **If `input_result` and `window_closed` are connected in reverse order** (i.e., `window_closed` connected before `input_result` in `_ready()`): `window_closed` fires with a stale or uninitialized `current_mode`. This causes the wrong SFX to play. Enforce connection order: connect `input_result` first, `window_closed` second, in every `_ready()` implementation.
- **If a guest arrival stinger's `finished` signal is used to trigger the subsequent `play_music(area_guest_track_id, &"crossfade")` call, but `play_music` is also called on the same frame inline** (stinger + crossfade issued simultaneously): The inline call and the `finished`-triggered call both execute, resulting in two crossfade requests on the same or adjacent frames. The correct pattern: issue only `play_music(stinger_id, &"finish_then_play")` inline; issue `play_music(area_guest_track_id, &"crossfade")` exclusively from the stinger's `finished` handler. Do not issue the second call on the same frame as the stinger request.

### Tween Strategy Constraints

- **If a crossfade tween interpolates `AudioServer` bus dB values directly** (e.g., tweening from -60 dB to 0 dB linearly): The result is a perceptually exponential fade — volume appears to jump in the last portion of the tween. All crossfade tweens must interpolate a normalized value in [0.0, 1.0] and call `linear_to_db()` at each step to drive the actual bus volume. The tween target is the normalized value; the dB conversion is a per-step side effect.
- **If a combat layer fade tween interpolates dB values directly**: Same constraint applies. `COMBAT_LAYER_FADE_IN_SEC` and `COMBAT_LAYER_FADE_OUT_SEC` fades must tween normalized [0.0, 1.0] and call `linear_to_db()` each step on `CombatLayerPlayer`. Mid-interruption fades (see Combat Layer Edge Cases above) must read `V_current` as a normalized value — use `db_to_linear(CombatLayerPlayer.volume_db)` to convert the player's current dB back to normalized before starting the interrupted tween.

## Dependencies

### Upstream Dependencies

The Audio System subscribes to signals from other systems but does not call into them. Its signal subscriptions create soft runtime dependencies on the signal-emitting systems:

| System | Dependency Type | Signals Subscribed |
|--------|----------------|--------------------|
| **Input & Timing Detection** | Soft (signal subscriber) | `input_result`, `window_closed` |
| **Timing Combat System** | Soft (signal subscriber) | `encounter_started`, `enemy_condition_changed`, `cc_changed`, `hp_danger_zone_entered`, `combatant_incapacitated` |
| **Status Effects** | Soft (signal subscriber) | `status_effect_applied`, `status_effect_expired` |

The Audio System initialises and operates without any of these systems present — if no signals are connected, it simply receives no audio events. It reads from Godot's `AudioServer` directly and requires no data from any GDD-defined system to initialise its buses or players.

### Downstream Dependents

| System | Dependency Type | Interface Used | What Breaks Without Audio |
|--------|----------------|----------------|--------------------------|
| **Timing Combat System** | Hard | `begin_combat_layer()`, `end_combat_layer()`, `play_music(track_id, transition)` | Combat and boss music absent; timing feedback SFX absent |
| **Menu & Settings System** | Hard | `set_bus_volume(bus_name, normalized_value)`, `get_bus_volume(bus_name) -> float` | Volume sliders cannot read or write audio state |
| **World Exploration / Scene Management** | Soft | `play_music(track_id, transition)` on area entry; combat stem load on `CombatLayerPlayer` | Area music absent; in-phase combat stem guarantee lost |
| **Guest Character System** | Soft | `play_music(stinger_id, &"finish_then_play")`, `play_music(area_guest_track_id, &"crossfade")`, `play_music(area_base_track_id, &"crossfade")` | Guest arrival stinger and leitmotif variants absent |
| **Cutscene System** | Soft | `play_music(track_id, transition)`, `stop_music()` | Cutscene music and intentional silence absent |
| **HUD / UI nodes** | Soft | `play_sfx(sfx_id)` | Menu navigation sounds absent |
| **Input & Timing Detection** | Soft (listener only) | `input_result(mode, grade)` signal, `window_closed(grade)` signal | Combat grade SFX absent |
| **Status Effects** | Soft (listener only) | `status_effect_applied`, `status_effect_expired` signals | Status apply stings and expiry stings absent |
| **Enemy System** | Soft (listener only, via TCS) | `enemy_condition_changed` signal | Condition stingers and APEX phase transitions absent |

### Bidirectionality Note

The Input & Timing Detection GDD must note that the Audio System listens to its `input_result` and `window_closed` signals. The Timing Combat System GDD, Menu & Settings System GDD, and other dependent GDDs must reference this system when they describe their audio interaction. All interfaces are owned by their callers — the Audio System exposes a stable interface and does not call back into any dependent system.

## Tuning Knobs

| Knob | Default | Safe Range | Too Low | Too High | Interacts With |
|------|---------|------------|---------|----------|----------------|
| `MUSIC_CROSSFADE_DURATION_SEC` | 1.5 s | 0.5–3.0 s | Cut feels abrupt; area transitions lose emotional smoothness | Fade outlasts the transition context; next area's music starts late | `COMBAT_LAYER_FADE_OUT_SEC` — if both are long, area transitions with active combat feel sluggish |
| `COMBAT_LAYER_FADE_IN_SEC` | 1.5 s | 0.5–3.0 s | Combat stem snaps in too quickly; feels mechanical | Combat is already progressing before the layer is audible; tension build-up missed | Should be ≤ `COMBAT_LAYER_FADE_OUT_SEC` to ensure fade-in is snappier than fade-out |
| `COMBAT_LAYER_FADE_OUT_SEC` | 2.0 s | 1.0–4.0 s | Stem cuts off too quickly after combat; emotional release truncated | Stem audible long after combat ends; undermines post-combat calm | Must complete before area music transition begins (unless `&"immediate"` override) |
| `SFX_POOL_SIZE` | 12 | 8–16 | Pool exhausts during dense combat; STANDARD SFX stolen mid-playback | Excess idle nodes consume memory with no benefit | Realistic worst-case burst (grade tone + CC chime + HP danger tone + status sting + condition stinger + incapacitation SFX + expiry sting + void_shriek duck) = 8 slots simultaneously; 12 provides headroom for a double-turn PERFECT resolution (10–12 simultaneous). Note: changing pool size requires a corresponding scene-level node-count change — not a pure data change. The priority tier system (PROTECTED tier) protects grade tones from being stolen regardless of pool saturation. |
| `APEX_LAYER_FADE_IN_SEC` | 1.5 s | 0.5–3.0 s | APEX ambient stem snaps in too quickly | APEX encounter is well underway before phase 1 stem is audible | Should match or exceed `COMBAT_LAYER_FADE_IN_SEC` for a unified combat-layer arrival |
| `APEX_LAYER_FADE_OUT_SEC` | 2.0 s | 1.0–4.0 s | APEX stem cuts off too quickly at encounter end | Stem audible long after encounter ends | Should complete before area music transition begins (unless `&"immediate"` override) |
| `APEX_LAYER_CROSSFADE_SEC` | 1.0 s | 0.3–2.0 s | Condition-phase transition feels abrupt | Crossfade outlasts the transition context; new phase arrives late | Shorter than `MUSIC_CROSSFADE_DURATION_SEC` to feel like a sharpening of tension, not an area change |
| `STING_DELAY_SEC` | 0.1 s | 0.05–0.2 s | Status sting onset too close to grade tone onset; auditory masking muddies both signals | Sting delay is perceptibly separate from the action it describes | 100 ms gives grade tone onset primacy while keeping the sting within the post-masking window of the grade event |

**Interaction notes:**
- `MUSIC_CROSSFADE_DURATION_SEC = 0.0` is valid — treated as immediate cut (see Edge Cases).
- `COMBAT_LAYER_FADE_IN_SEC` and `COMBAT_LAYER_FADE_OUT_SEC` are independent tweens. Mid-interruption fades resume from `V_current`, so asymmetric values (fast in, slow out) produce natural-feeling combat tension ramps.
- `SFX_POOL_SIZE` is the only knob that requires a scene-level change (adding or removing `AudioStreamPlayer` nodes). All other knobs are pure float constants.

## Visual/Audio Requirements

### Grade Tone Distinctiveness (Pillar 2 — Rhythm Is Respect)

The grade tone is the primary player feedback signal. The Player Fantasy claims the player "knows before the screen confirms." For this to hold, all three grade tones must be perceptually distinct without visual context at any volume setting.

**Minimum distinctiveness requirements (testable at playtest):**

| Grade | Required Character | Onset Type | Duration Range |
|-------|--------------------|------------|---------------|
| PERFECT | Resolved, harmonic, affirming — a tone that feels complete | Clean onset (no noise floor) | 200–400 ms |
| HIT | Neutral, functional — confirmation without celebration | Moderate onset | 120–250 ms |
| MISS | Unresolved, incomplete, or dissonant — communicates non-achievement actively, not by absence | Sharp or muted onset | 80–180 ms |

**Constraint: perceptual test.** A listener presented with only the grade tone audio (no visual context) must correctly identify the grade at a ≥90% pass rate in informal playtest conditions. "All three sound similar" is a production failure, not a tuning issue.

**Mix position:** Grade tones must be authored such that when the SFX bus is at 50% normalised volume and the Music bus is at 100%, the grade tone onset remains audible above the music. Recommended authoring target: grade tones authored at −6 dBFS so they have headroom to sit above a full-volume combat layer.

**PERFECT zone perceptibility:** The PERFECT tone must be audibly distinct from the HIT tone in at least two dimensions (e.g., pitch register + harmonic character, or duration + timbre). A player who has never seen the HUD must be able to learn the PERFECT tone is different from HIT through audio alone. Onboarding must include an audio-only demonstration of PERFECT vs. HIT grade tones.

### HP Danger Zone Tone

The HP danger zone tone (`sfx_hp_danger_tone_id`) fires when a combatant crosses below 25% HP. It is a `PROTECTED` pool tier sound — the most emotionally loaded proactive audio event (all other sounds are reactive to player input).

**Required character:** A secondary, sustained, low-register unresolved tone. Must not clash with the current MISS grade tone in frequency; should occupy the lower register (below 500 Hz) so it does not compete with grade tone onset transients. Duration: sustained (300 ms minimum) — not a one-shot sting.

**Re-entry behaviour:** If the same combatant is healed above 25% and then drops below again, the tone re-fires. The second firing may use a shorter or attenuated variant if authored — the Audio System plays whichever `sfx_id` is configured; variant selection is a production decision.

### Silence as a Compositional Resource

"Silence is a resource, not a gap" (Player Fantasy). The Audio System does not implement an automatic silence mechanism. Silence before dramatic moments is achieved through:
- Compositional choices in soundtrack authoring (story scene music begins with a single sustained note, not a full cue)
- Deliberate `stop_music()` calls from the Cutscene System before emotionally significant scenes
- The SFX bus's natural silence between combat encounters (no SFX fire outside combat unless authored)

No system rule or AC is needed for this — it is a production and direction responsibility.

### MUTED Variant Audio Character

`_muted` SFX variants must have a low-pass filter applied at authoring time (cutoff: 800–1200 Hz, gentle rolloff). The goal is "muffled" — the sound is recognisably the same attack but clearly degraded. The muted variant must be distinct from the unfiltered version at 50% SFX bus volume. Buff and debuff application stings must be audibly distinct in tone: buffs lean warm/ascending; debuffs lean dissonant/descending.

## UI Requirements

[To be designed]

## Acceptance Criteria

60 criteria across 7 groups. All are BLOCKING — the Audio System is Logic and Integration work. Visual/feel verification (crossfade smoothness, combat layer feel) is handled separately as manual evidence in `production/qa/evidence/`.

### Group 1 — Music Playback

- **AC-1** — GIVEN Music FSM is `SILENT`, WHEN `play_music(track_a, &"immediate")` for a non-intro track, THEN active player plays track_a at full volume, FSM → `PLAYING`. *(No-tween clause: verify with `_debug_tween_active() -> bool`; assert `false` post-call.)*
- **AC-2** — GIVEN FSM is `PLAYING` track_a, WHEN `play_music(track_b, &"crossfade")`, THEN standby loads track_b at -INF dB; tween ramps outgoing to -INF dB and incoming to target volume over `MUSIC_CROSSFADE_DURATION_SEC`; on completion outgoing stops and roles swap; FSM → `PLAYING`.
- **AC-3** — GIVEN FSM is `PLAYING` track_a, WHEN `play_music(track_b, &"immediate")`, THEN active stops with no fade; standby loads track_b at full volume immediately; roles swap; FSM stays `PLAYING`. No tween created.
- **AC-4** — GIVEN FSM is `PLAYING` a non-looping track_a, WHEN `play_music(track_b, &"finish_then_play")`, THEN track_a plays to completion; on `finished` signal, standby loads track_b and begins at full volume. No `_process()` polling used.
- **AC-5** — GIVEN FSM is `SILENT`, WHEN `play_music(track_a)` for a track flagged `has_intro: true`, THEN intro stream loads with `loop = false`; FSM → `PLAYING_INTRO`; on `finished`, loop stream replaces it with `loop = true`; FSM → `PLAYING`. Presented as one logical track.
- **AC-6** — GIVEN FSM is `PLAYING` track_a, WHEN `play_music(track_a, &"crossfade")` with identical `track_id`, THEN no action taken: player continues uninterrupted, no tween starts, no queue entry created, no role swap. (Idempotency guard — applies regardless of transition type.)
- **AC-7** — GIVEN FSM is `PLAYING` track_a, WHEN `play_music(track_a, &"immediate")` with identical `track_id`, THEN same no-op as AC-6.
- **AC-8** — GIVEN FSM is `CROSSFADING` with no prior queued track, WHEN `play_music(track_c)` arrives, THEN in-progress tween continues; track_c is queued (any prior queued track is displaced — queue depth remains 1); immediately after tween completes and roles swap, track_c is dispatched automatically.
- **AC-9** — GIVEN FSM is `CROSSFADING`, WHEN two successive calls arrive (track_c then track_d) before tween completes, THEN only track_d retained in queue. Queue depth never exceeds 1.
- **AC-10** — GIVEN FSM is `CROSSFADING`, WHEN `play_music(track_c, &"immediate")`, THEN in-progress tween cancelled; both players stop; track_c loads at full volume; roles swap; FSM → `PLAYING`; queue cleared.
- **AC-11** — GIVEN FSM is any non-`SILENT` state, WHEN `stop_music()`, THEN both players stop, tween cancelled, queue cleared, FSM → `SILENT`. Hard cut — no fade-out.
- **AC-12** — GIVEN FSM is `SILENT`, WHEN `stop_music()`, THEN no action, no error. (No-op idempotency.)
*(AC-13 removed — exact duplicate of AC-53. See AC-53 for the canonical test.)*
- **AC-14** — GIVEN guest stinger requested via `play_music(stinger_id, &"finish_then_play")`, WHEN stinger plays, THEN stinger plays to full completion; `play_music(area_guest_track_id, &"crossfade")` is dispatched exclusively from the stinger's `finished` handler, not inline on the same frame. One crossfade transition only.
- **AC-15** — GIVEN FSM is `PLAYING_INTRO`, WHEN `play_music(new_id)`, THEN intro player treated as outgoing; `finished` listener disconnected before crossfade begins; FSM → `CROSSFADING`. No spurious loop-load from stale `finished`.

### Group 2 — Combat Layer

- **AC-16** — GIVEN area with valid combat stem is entered, WHEN area loads, THEN `CombatLayerPlayer` loads stem and begins simultaneously with active area player at -INF dB. Both players start at same position: `abs(CombatLayerPlayer.get_playback_position() - ActiveAreaPlayer.get_playback_position()) ≤ 0.05 s` within one frame of startup. `CombatLayerPlayer` inaudible but running.
- **AC-17** — GIVEN `CombatLayerPlayer` is `LAYER_SILENT` (in-phase), WHEN `begin_combat_layer()`, THEN tween ramps -INF dB → 0 dB over `COMBAT_LAYER_FADE_IN_SEC`. Area player unaffected. On completion, state → `LAYER_ACTIVE`.
- **AC-18** — GIVEN `LAYER_ACTIVE`, WHEN `end_combat_layer()`, THEN tween ramps 0 dB → -INF dB over `COMBAT_LAYER_FADE_OUT_SEC`. Area player uninterrupted. On completion, `CombatLayerPlayer` remains running at -INF dB in-phase; state → `LAYER_SILENT`.
*(AC-19 removed — exact duplicate of AC-54. See AC-54 for the canonical test.)*
- **AC-20** — GIVEN `LAYER_FADING_IN`, WHEN `begin_combat_layer()`, THEN no-op; in-progress tween continues.
- **AC-21** — GIVEN `LAYER_ACTIVE`, WHEN `begin_combat_layer()`, THEN no-op.
- **AC-22** — GIVEN `LAYER_SILENT` with no combat stem loaded for current area, WHEN `begin_combat_layer()`, THEN no-op, no error, no tween.
- **AC-23** — GIVEN `LAYER_SILENT`, WHEN `end_combat_layer()`, THEN no-op, no error.
- **AC-24** — GIVEN `LAYER_FADING_OUT`, WHEN `end_combat_layer()`, THEN no-op; tween continues.
- **AC-25** — GIVEN `LAYER_FADING_IN`, WHEN `end_combat_layer()`, THEN incoming tween cancelled; `V_current` read as normalized; fade-out tween runs from `V_current` to 0.0; state → `LAYER_FADING_OUT`. No snap. *(Same debug-method mitigation as AC-19.)*
- **AC-26** — GIVEN `LAYER_ACTIVE` and area transition with `&"crossfade"`, WHEN transition processed, THEN `end_combat_layer()` called first; area music crossfade does not begin until `COMBAT_LAYER_FADE_OUT_SEC` has elapsed. *(Requires frame-step test harness or timer mock to assert the delay. Add to testability flags table. The Music FSM remains `PLAYING` during the wait period — it is not in a transitional state.)*
- **AC-27** — GIVEN `LAYER_ACTIVE` and area transition with `&"immediate"`, WHEN processed, THEN both `CombatLayerPlayer` and area player stop simultaneously with no fade-out wait.

### Group 3 — SFX Pool

- **AC-28** — GIVEN pool has at least one idle player, WHEN `play_sfx(known_sfx_id)`, THEN first idle player assigned stream and begins playback. No steal occurs.
- **AC-29** — GIVEN all `SFX_POOL_SIZE` players active (all `STANDARD` tier), WHEN `play_sfx(known_sfx_id)` for a `STANDARD` sound, THEN system computes `T_remaining` for each STANDARD player (guarded: `if T_length == 0.0 OR T_position > T_length: T_remaining = INF`); STANDARD player with minimum `T_remaining` stopped and reassigned; playback begins immediately. Tiebreaker: lowest pool index.
- **AC-30** — GIVEN pool with 3 of `SFX_POOL_SIZE` players active (all `STANDARD` tier, remaining times 1.7 s / 0.3 s / 2.5 s), WHEN steal required for a new `STANDARD` SFX, THEN the 0.3 s player is stolen.
- **AC-31** — GIVEN a pool player where `T_length = 0.0` OR `T_position > T_length` (streaming asset, pre-buffer or lag case), WHEN steal-candidate selection runs, THEN that player's `T_remaining` treated as +INF; never selected as steal candidate unless all candidates report +INF.
- **AC-32** — GIVEN a pool player's stream finishes, WHEN `finished` fires, THEN: (a) player's idle state is updated (`is_playing() == false`); (b) the player is selectable by a subsequent `play_sfx()` call on the next allocation; (c) no `_process()` or `_physics_process()` polling is used to track idle state. *(Clause c: code review gate — confirm idle tracking uses `finished` signal only. Clause b: verify by calling `play_sfx()` immediately after `finished` fires and asserting the pool player count does not increase beyond pool size.)*
- **AC-33** — GIVEN `play_sfx()` called with unrecognized `sfx_id`, WHEN processed, THEN warning logged, no pool player allocated, no crash, pool state unchanged.
- **AC-34** — GIVEN `sfx_id` configured to route to `UI` bus, WHEN `play_sfx(ui_sfx_id)`, THEN allocated pool player assigned to `UI` bus, not `SFX`. Bus resolved from config, not from caller.
- **AC-35** — GIVEN `SFX_POOL_SIZE = 8`, WHEN `play_sfx()` called 8 times in sequence within one frame (without yielding to the engine — all 8 calls before any `_process()` tick), THEN all 8 sounds begin playback, no steal occurs, all 8 players active.

### Group 4 — Volume Control

- **AC-36** — GIVEN any Music bus state, WHEN `set_bus_volume(&"Music", 1.0)`, THEN `AudioServer.set_bus_volume_db()` called with `0.0 dB` for Music bus. No other bus affected.
- **AC-37** — GIVEN any Music bus state, WHEN `set_bus_volume(&"Music", 0.0)`, THEN `AudioServer.set_bus_volume_db()` called with `-INF dB` (via `linear_to_db(0.0)`). No epsilon floor applied — bus reaches true silence.
- **AC-38** — GIVEN any Music bus state, WHEN `set_bus_volume(&"Music", 0.5)`, THEN `AudioServer.set_bus_volume_db()` called with approximately `-6.02 dB` (±0.01 dB tolerance).
- **AC-39** — GIVEN Music bus set to normalized value n, WHEN `get_bus_volume(&"Music")`, THEN returns float in [0.0, 1.0] that round-trips within ±0.001 of n.
*(AC-40 removed — duplicate of AC-55 with fewer assertions. See AC-55 for the canonical test.)*
- **AC-41** — GIVEN `set_bus_volume()` called with `normalized_value = -0.2`, WHEN processed, THEN clamped to 0.0; `AudioServer` receives `-INF dB`; warning logged.
- **AC-42** — GIVEN `set_bus_volume()` called with unrecognized `bus_name`, WHEN processed, THEN warning logged; `AudioServer.set_bus_volume_db()` NOT called; no bus volume changes.
- **AC-43** — GIVEN all four buses configured, WHEN `set_bus_volume(bus_name, n)` called for each bus independently, THEN only the target bus volume changes; the three others are unaffected.

### Group 5 — Signal Handling

- **AC-44** — GIVEN Audio System initialized with `input_result` connected before `window_closed`, WHEN `input_result(mode, grade)` fires followed by `window_closed(grade)` in the same `_physics_process()` tick, THEN stored `current_mode` + `grade` used to look up `sfx_id`; `play_sfx()` called. *(Frame-sequence verification: requires a frame-step integration test harness that advances one physics frame and samples state; add to testability flags table. The "same frame" ordering guarantee comes from ITD's signal architecture — both signals emit in the same `_physics_process()`.)*
- **AC-45** — GIVEN `window_closed(grade)` fires with no preceding `input_result` received, WHEN handler runs, THEN warning logged and SFX playback skipped for this event. No crash.
*(AC-46 removed — merged into AC-32, which now covers both idle-state update and subsequent selectability.)*
- **AC-47** — GIVEN guest stinger uses `&"finish_then_play"`, WHEN stinger's `finished` fires, THEN `play_music(area_guest_track_id, &"crossfade")` dispatched from that handler exclusively — not also dispatched inline on the same frame as the stinger request. One crossfade transition only.

### Group 6 — Tween Behavior

- **AC-48** — GIVEN a crossfade is in progress, WHEN tween step runs, THEN interpolated value is a normalized float in [0.0, 1.0]; `linear_to_db()` applied each step to compute actual dB; tween does NOT interpolate dB values directly. *(Mitigation: sample bus volume at t=50% of crossfade duration; assert ≈ -6.02 dB. A midpoint near -30 dB indicates dB-direct interpolation.)*
- **AC-49** — GIVEN combat layer fade-in or fade-out in progress, WHEN tween step runs, THEN same constraint: tween interpolates [0.0, 1.0] normalized; `linear_to_db()` called each step on `CombatLayerPlayer.volume_db`. *(Same midpoint-sampling mitigation as AC-48.)*
- **AC-50** — GIVEN `CombatLayerPlayer` is mid-fade-out at `V_current`, WHEN `begin_combat_layer()` interrupts, THEN new fade-in tween starts at `V_current` normalized (read via `db_to_linear(CombatLayerPlayer.volume_db)`), not at 0.0. *(Requires frame-step harness to sample `_debug_layer_volume_normalized()` on the new tween's first step. Assert value matches pre-interruption reading ±0.5 dB. Add to testability flags table.)*
- **AC-51** — GIVEN `stop_music()` called while crossfade tween active, WHEN processed, THEN tween cancelled on same frame; both players stop; no further tween callbacks fire; FSM → `SILENT`.

### Group 7 — Edge Cases

*(AC-52 removed — subsumed by AC-11 which covers "GIVEN FSM is any non-SILENT state, WHEN stop_music()". CROSSFADING is a non-SILENT state.)*
- **AC-53** — GIVEN `MUSIC_CROSSFADE_DURATION_SEC = 0.0`, WHEN `play_music(track_b, &"crossfade")`, THEN identical to `&"immediate"`: outgoing stops, standby at full volume, roles swap, no Tween object instantiated. Post-fade cleanup (stop outgoing, swap roles) executes via the shared `_complete_crossfade()` helper — not left to tween completion callback. *(Untestable clause "no Tween created": `_debug_tween_active() -> bool`; assert `false` post-call. Audible check: no gap or pop.)*
- **AC-54** — GIVEN `LAYER_FADING_OUT`, WHEN `begin_combat_layer()`: (1) fade-out tween cancelled, (2) `V_current` read as normalized via `db_to_linear(CombatLayerPlayer.volume_db)`, (3) fade-in tween runs from `V_current` to 1.0, (4) state → `LAYER_FADING_IN`. No audible snap to 0.0. *(Untestable clause "no snap": `_debug_layer_volume_normalized() -> float`; assert value in (0.0, 1.0) exclusive at interruption frame via frame-step harness; ±0.5 dB tolerance.)*
- **AC-55** — GIVEN `set_bus_volume(&"Music", 1.5)`, WHEN processed, THEN clamped to 1.0; dB output is `0.0 dB`; warning emitted; no positive dB value passed to `AudioServer`.
- **AC-56** — GIVEN `play_sfx()` called with unknown `sfx_id`, WHEN processed, THEN game does not crash; pool state unchanged; warning in Godot output log containing the unrecognized `sfx_id` string.
- **AC-57** — GIVEN area with no combat stem, WHEN `begin_combat_layer()`, THEN state remains `LAYER_SILENT`; no tween started; no error logged; area music continues uninterrupted.
- **AC-58** — GIVEN FSM is `PLAYING` track_a, WHEN `play_music(track_a, &"finish_then_play")` with same `track_id`, THEN idempotency guard fires before finish-then-play logic; no action taken; no `finished` listener connected; track_a continues. *(Audible no-restart check; duplicate listener check at code review.)*
- **AC-59** — GIVEN FSM is `PLAYING_INTRO`, WHEN `stop_music()`, THEN active player stops; `finished` listener on intro player disconnected; FSM → `SILENT`. No loop stream loads after stop.
- **AC-60** — GIVEN `track_id` maps to no loaded asset, WHEN `play_music(bad_track_id, any)`, THEN error logged; FSM state unchanged; no player enters broken state; Audio System continues operating.

### Group 8 — Missing Spec Coverage (Rules in Detailed Design with no prior AC)

- **AC-61** — GIVEN FSM is `PLAYING` a looping track (`loop = true`), WHEN `play_music(other_id, &"finish_then_play")`, THEN the active track continues looping; no `finished` listener is connected; no action is taken; the Audio System continues operating without hanging. *(Specified caller-bug behaviour per Edge Cases section — must not hang or crash.)*

- **AC-62** — GIVEN area transition with `&"crossfade"` occurs while `CombatLayerPlayer` is running at -INF dB (in-phase), WHEN the area transition completes and the new area loads, THEN `CombatLayerPlayer` is reloaded with the new area's combat stem and begins playback simultaneously with the new active area player (in-phase). `CombatLayerPlayer` continues to be inaudible (-INF dB) after the transition. *(Verifies Rule 2.3: CombatLayerPlayer state is preserved and re-phased through area transitions.)*

### Group 9 — Signal Handling (New Subscriptions — Rules 3.8–3.13)

- **AC-63** — GIVEN `status_effect_applied(combatant_id, effect_id, ..., is_refresh: false)` fires, WHEN processed, THEN `play_sfx_delayed(sfx_apply_id, STING_DELAY_SEC)` is scheduled; a pool player begins playing `sfx_apply_id` after the configured delay (within ±20 ms). No immediate SFX on same frame.

- **AC-64** — GIVEN `status_effect_applied(combatant_id, effect_id, ..., is_refresh: true)` fires, WHEN processed, THEN no audio is played; no delayed SFX scheduled; pool state unchanged.

- **AC-65** — GIVEN `status_effect_expired(combatant_id, effect_id, cause: "natural")` fires and `sfx_expire_id` is non-empty, WHEN processed, THEN `play_sfx(sfx_expire_id)` called immediately. Pool allocates a player.

- **AC-66** — GIVEN `status_effect_expired(combatant_id, effect_id, cause: "incapacitated")` or `cause: "encounter_end"` fires, WHEN processed, THEN no audio; pool state unchanged.

- **AC-67** — GIVEN `cc_changed(new_cc, delta, source_type: "window_grade")` fires, WHEN processed, THEN `play_sfx(sfx_cc_gain_chime_id)` called; pool allocates a `PROTECTED` player.

- **AC-68** — GIVEN `cc_changed(new_cc, delta, source_type: "ability_delta")` fires, WHEN processed, THEN no audio; pool state unchanged; no CC chime plays.

- **AC-69** — GIVEN `hp_danger_zone_entered(combatant_id)` fires, WHEN processed, THEN `play_sfx(sfx_hp_danger_tone_id)` called; the allocated pool player is `PROTECTED` tier (not stealable while playing); no STANDARD player is stolen to accommodate it.

- **AC-70** — GIVEN `combatant_incapacitated(combatant_id, is_enemy: true)` fires and `EnemyData.sfx_incapacitated_id` is non-empty, WHEN processed, THEN `play_sfx(sfx_incapacitated_id)` called. GIVEN `is_enemy: false`, THEN no audio.

- **AC-71** — GIVEN `encounter_started(enemy_ids)` fires with at least one APEX enemy in the roster, WHEN processed, THEN `begin_apex_layers(apex_enemy_id)` called; `ApexLayerPlayerA` loads the UNWOUNDED stem and begins playback simultaneously with `CombatLayerPlayer` at -INF dB; APEX Layer FSM → `APEX_FADING_IN`. GIVEN no APEX enemy in the roster, THEN no apex layer activated.

- **AC-72** — GIVEN `enemy_condition_changed(instance_id, old_state: "UNWOUNDED", new_state: "BLOODIED", stinger_tier: "apex")` fires for the active APEX enemy, WHEN processed, THEN: (a) APEX layer crossfade begins — active APEX player fades to -INF dB while standby loads BLOODIED stem and fades to 0 dB over `APEX_LAYER_CROSSFADE_SEC`; (b) condition stinger `play_sfx(stinger_sfx_id)` fires. APEX layer roles swap on crossfade completion.

- **AC-73** — GIVEN MUTED status is active on `combatant_id`, WHEN `play_sfx(sfx_ne_attack, combatant_id)` called, THEN Audio System looks up `sfx_ne_attack_muted` variant; if the variant exists, the muted version plays; if the variant does not exist, the unfiltered version plays as fallback (no crash, no silence).

- **AC-74** — GIVEN MUTED status expires on `combatant_id` (`status_effect_expired` for MUTED fires), WHEN the next `play_sfx(sfx_ne_attack, combatant_id)` is called, THEN the unfiltered `sfx_ne_attack` plays (combatant removed from `_muted_combatants`).

- **AC-75** — GIVEN a SFX event configured with `plays_duck: true`, `duck_db: -6.0`, `duck_duration_ms: 33.0`, WHEN `play_sfx(ducking_sfx_id)` called, THEN SFX bus volume is reduced by 6 dB immediately; original SFX bus volume is restored after ≈33 ms (±10 ms). No other bus affected.

### Group 10 — Pool Priority Tiers

- **AC-76** — GIVEN all pool players active and all playing `STANDARD` tier SFX, WHEN `play_sfx(sfx_grade_tone_perfect_id)` called (PROTECTED tier), THEN the STANDARD player with the shortest `T_remaining` is stolen; the PROTECTED grade tone begins playback. No PROTECTED player is stolen.

- **AC-77** — GIVEN all pool players active, some playing `PROTECTED` sounds (grade tones) and some playing `STANDARD` sounds, WHEN `play_sfx(sfx_status_sting_id)` called (STANDARD tier), THEN a STANDARD player is stolen (shortest T_remaining among STANDARD players); no PROTECTED player is stolen; any playing grade tones continue uninterrupted.

- **AC-78** — GIVEN all pool players active and all are `PROTECTED` tier (edge case: saturated with grade tones and CC chimes), WHEN `play_sfx(sfx_status_sting_id)` called (STANDARD), THEN no player is stolen; the status sting is silently dropped; a warning is logged; all PROTECTED sounds continue playing.

### Test Location and Story Type

| AC Range | Story Type | Gate | Location |
|----------|-----------|------|----------|
| AC-1 to AC-43 (excl. removed) | Logic (FSM, formulas, pool, volume) | BLOCKING | `tests/unit/audio/` |
| AC-44 to AC-51 | Integration (signals, multi-system, tweens) | BLOCKING | `tests/integration/audio/` |
| AC-53 to AC-62 (excl. removed) | Logic / Integration (edge cases) | BLOCKING | `tests/unit/audio/` or `tests/integration/audio/` |
| AC-63 to AC-78 | Integration (new signal subscriptions, priority tiers, APEX) | BLOCKING | `tests/integration/audio/` |

### Testability Flags

Clauses requiring a debug method, code-review gate, or frame-step harness rather than standard manual QA:

| AC | Untestable Clause | Mitigation |
|----|-------------------|------------|
| AC-1, AC-53 | "No Tween created" | `_debug_tween_active() -> bool`; assert `false` post-call |
| AC-25, AC-50, AC-54 | "No volume snap at interruption" | `_debug_layer_volume_normalized() -> float`; frame-step harness; ±0.5 dB tolerance |
| AC-26 | "Crossfade not before COMBAT_LAYER_FADE_OUT_SEC elapsed" | Frame-step integration harness or timer mock |
| AC-32 | "No `_process()` polling" | Code review gate — `/code-review` checklist |
| AC-44 | "Same `_physics_process()` tick ordering" | Frame-step integration harness |
| AC-48, AC-49 | "Tween interpolates normalised, not dB" | Sample bus at t=50% of fade duration; assert ≈ −6.02 dB (±0.1 dB tolerance) |
| AC-50 | "First tween step matches pre-interruption volume" | Frame-step harness; `_debug_layer_volume_normalized()` |
| AC-58 | "No duplicate `finished` listener" | Audible no-restart check + code review |

## Open Questions

| # | Question | Owner | Target Resolution |
|---|----------|-------|-------------------|
| OQ-1 | **SFX config data format.** The design references a config-driven mapping: `sfx_id → (AudioStream, bus_name)` and `(mode, grade) → sfx_id`. The format of this config (exported Dictionary, `.tres` Resource, inline constants) hasn't been specified. Wrong choice here affects how the Audio System is constructed and whether designers can edit it without code changes. | Lead Programmer / Audio Director | Before Audio System implementation story is written |
| OQ-2 | **Debug method exposure.** AC-13, AC-19, AC-25, AC-50, AC-53 reference `_debug_tween_active()` and `_debug_layer_volume_normalized()` as debug-only methods. GDScript exposure strategy not decided (`OS.is_debug_build()` guard, conditional compile block, or `@tool` annotation). Must be resolved before test suite is scaffolded. | Lead Programmer | Before `/test-setup` for Audio System |
| OQ-3 | **Combat stem area association.** Rule 2.9 states `CombatLayerPlayer` loads the combat stem for the current area "if one exists." The data contract for associating a stem with an area (area Resource property, lookup dictionary, Scene Management metadata) is not yet defined. This decision belongs to the Scene Management or World Exploration GDD. | Systems Designer | When Scene Management (design order #16) or World Exploration (#18) GDD is authored |
| OQ-4 | **`finish_then_play` looping track guard.** Edge Cases note that issuing `finish_then_play` against a looping track is a caller bug — `finished` never fires. Currently specified as caller responsibility with no Audio System validation. Should the Audio System detect this (check `stream.loop` before connecting `finished`) and log a warning? Adds robustness at minimal cost but adds a check path not currently in spec. | Lead Programmer | Before implementation; decision affects Edge Cases section |
| OQ-5 | **Voice bus activation path.** The Voice bus is reserved for future VO. **VO must NOT be routed through `play_sfx()` and the SFX pool** — voice lines are long (3–15 s), they would hold pool slots and become steal candidates. When VO is implemented, it requires a dedicated `play_voice(line_id, character_id)` method backed by a separate, non-pooled `AudioStreamPlayer` node (or a small dedicated pool of 2–3 players for concurrent VO). Per-character VO volume must use per-character sub-buses or player-level volume, not the shared Voice bus. Document the expected interface before Episode 2 design begins. | Audio Director / Narrative Director | Before Episode 2 pre-production |

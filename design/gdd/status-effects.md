# Status Effects

> **Status**: Approved (2026-05-02, Revision Pass 3)
> **Author**: Jesus Gallegos + agents
> **Last Updated**: 2026-05-02
> **Implements Pillar**: Pillar 2 (Rhythm Is Respect), Pillar 3 (The Company Changes You)

## Overview

The Status Effects system is *Lux Aeterna*'s layer of temporary combat modifiers — a registry of active conditions applied to combatants that alter their stats for a defined duration, then expire cleanly. At the data layer, it sits between Character Stats & Growth (which defines the permanent stat profile) and the Timing Combat System (which reads the final effective stat). When a status effect is active, it contributes a signed integer to the effective stat calculation alongside the base stat and any Named Inheritance Objects; when it expires, the stat returns to its prior value without any other action required. At the design layer, Status Effects is the system through which ability precision pays off beyond CC gain — landing a perfect hit on a technique with a status payload means the enemy's ATK drops for the next two turns, or your own DEF spikes before a punishing sequence. It makes the timing economy consequential beyond the moment of impact. Status effects also flow in the enemy direction: enemies apply debuffs to the party through their attacks, raising the cost of failing to block. The system owns the definition of every named status effect, the logic for applying and expiring them, and the interface through which all other systems query whether a given combatant is currently affected.

**Status effects are an intentional consequence layer, not a management layer.** The decision space lives in the Ability System (which ability to use, which target to debuff, spend CC now or save it). Status Effects delivers the consequences of those decisions across subsequent turns. No removal mechanic is planned for MVP — this is a deliberate scope boundary aligned with the target audience (storyteller-type players who want combat to feel consequential, not combinatorially complex). The 8 MVP effects are purely stat modifiers; players do not remove, extend (outside of STATUS_ADD combo payoffs), or otherwise interact with active effects directly.

## Player Fantasy

**Fantasy: The Tempo You Set**

By the time the player understands that landing a perfect hit can debuff an enemy — reduce their ATK for two turns, cut their SPD before a dangerous double-action window — the system has already been working quietly. They already noticed that a punishing enemy attack landed soft. They already felt, rather than calculated, that the encounter was moving at their pace. Status effects do not announce themselves as a system. They arrive as a consequence of playing well, and the recognition arrives the same way.

The anchoring moment is small: the player lands a PERFECT on a debuff technique mid-encounter. They did not do it to manage a buff bar. They did it because it was the right move and they nailed the timing. Two turns later, the enemy attack that was threatening hits for less, and the player exhales — not because they got lucky, but because they built that safety deliberately. The debuff icon on the enemy is not the reward. The lighter hit is.

The mirror matters too. When a player fails to block and a debuff lands on their character, their next attack hits softer. The cost of missing the timing window is not just HP — it is two turns of reduced capability, visible on screen, shaping every decision until it fades. The system is symmetrical by design. Precision imposes conditions; inattention absorbs them.

Status effects complete the timing economy. The Ability System gives CC for precision; this system gives persistence — consequences that outlast the turn they were earned on. The player who is already engaged with the rhythm of combat gets a second payoff: the knowledge that what they did now will shape what happens next. Mastery in *Lux Aeterna* is not just about landing perfect hits. It is about landing the right hit, at the right moment, for a reason that echoes across the next two turns.

**HUD and the quiet arrival:** The HUD confirms what the player already felt — it does not announce what is coming. Icons and turn counters appear on application, but the design intent is that the player notices the consequence (the softer hit, the narrowed window) before they read the icon. The system teaches through feel first; the UI reinforces through confirmation. The MUTED first-encounter callout is the single exception: because MUTED's effect (narrower timing window) could be mistaken for a skill regression rather than an applied debuff, an explicit first-encounter notification is necessary for player comprehension.

*Implements Pillar 2 (Rhythm Is Respect): precision shapes the rhythm of future turns, not just the current one. The timing economy is consequential across the whole encounter, not just at the moment of input.*

## Detailed Design

### Core Rules

**Effect Catalogue**

Status Effects is a stat modifier system. At MVP, it operates exclusively on four stats: ATK, DEF, SPD, and FLUX. All modifiers are signed integers that contribute to the effective stat formula owned by Character Stats & Growth:

```
effective_stat = max(1, min(99, base_stat + sum(Named_Inheritance_Objects) + sum(active_status_modifiers)))
```

Eight named effects are defined at MVP — two per stat, one buff and one debuff, with two exceptions noted below:

| Effect Name | Stat | Direction | Applies To | Typical Magnitude | Typical Duration | Typical Trigger Grade | Design Intent |
|-------------|------|-----------|------------|-------------------|------------------|-----------------------|---------------|
| **DISSONANCE** | ATK | Debuff | Both | −4 to −7 | 2 turns | HIT | Primary offensive debuff. Accessible at HIT to ensure the "lighter hit two turns later" payoff fires in normal play. Softens enemy attacks; enemy-applied DISSONANCE punishes missed blocks. The anchoring moment of the Player Fantasy. |
| **RESONANCE** | ATK | Buff | Player only | +4 to +6 | 2 turns | HIT | Power window setup. Accessible at HIT — player uses it proactively before a high-cost ability. Enemy-applied ATK buff excluded — raises encounter complexity beyond MVP. |
| **FRACTURE** | DEF | Debuff | Both | −3 to −6 | 2 turns | HIT | Lowers damage mitigation. HIT-gated to make the FRACTURE+RESONANCE burst window achievable without requiring two sequential PERFECTs. |
| **FORTIFY** | DEF | Buff | Player only | +3 to +5 | 2 turns | HIT | Defensive positioning. Applied before a known dangerous enemy turn. Accessible at HIT — reactive tool that should not require precision to apply. |
| **SLUGGISH** | SPD | Debuff | Both | −4 to −8 | 2 turns | PERFECT | Most tactically consequential debuff: stripping a double-action is a high-impact tempo swing reserved for precision play. PERFECT-gate means the player earns this outcome. Wide magnitude range — encounter designers calibrate per ability. |
| **QUICKEN** | SPD | Buff | Player only | +3 to +6 | Authored per ability | HIT | Increases effective SPD; takes effect at the next ROUND_START (TPR is frozen at round start per TCS). May push a character over SWIFT_THRESHOLD for a double-action window in the following round. HIT-gated — accessible speed manipulation. Duration authored per ability in StatusEffectData (1 or 2 turns). Enemy-applied QUICKEN excluded — see design note below. |
| **TREMOLO** | FLUX | Buff | Player only | +4 to +8 | 2 turns | HIT | Widens timing windows temporarily. HIT-gated — accessible quality-of-life tool, especially for low-FLUX characters. Enemies do not apply this — gifting enemies wider windows has no meaningful effect. |
| **MUTED** | FLUX | Debuff | Enemy only | −3 to −6 | 2 turns | PERFECT | Narrows player timing windows. PERFECT-gated because MUTED is the most psychologically impactful enemy debuff — only precise enemy abilities (high-skill encounters) should be able to impose this. Restricted to enemies. **FLUX floor**: effective FLUX after MUTED (and all modifiers) is clamped to min 8 — the ITD design minimum. `effective_FLUX = max(EFFECTIVE_FLUX_FLOOR, base_FLUX + sum(modifiers))` where `EFFECTIVE_FLUX_FLOOR = 8`. This prevents sub-reaction-threshold windows (Ne at FLUX 8 with MUTED −5 would otherwise produce a 3-frame/50ms window with a 1-frame PERFECT zone). **HUD requirement**: MUTED's effect must be clearly communicated on application — the HUD GDD must ensure MUTED iconography and a timing-window-shrink notification are implemented. |

> **Trigger grade authoring note**: `status_trigger_grade` is authored per ability in `AbilityData`, not per `StatusEffectData` entry. The "Typical Trigger Grade" column above documents the **design intent** for standard ability implementations. Encounter designers may author abilities that gate the same effect at a different threshold (e.g., a PERFECT-only DISSONANCE for a high-skill encounter boss), but the typical grade establishes the expected feel and tuning baseline.

**Why no enemy-applied QUICKEN:** Enemy self-applied QUICKEN is excluded because it changes the turn economy unpredictably without player counterplay. Native high-SPD enemies are a known quantity visible from round 1 — the player can target them with SLUGGISH, prioritize them, or plan around their double-action. An enemy that applies QUICKEN to itself mid-encounter changes TURNS_PER_ROUND unpredictably in a system where that value is locked at round start; the player cannot react until the following round, and the effect may already have expired. This violates Pillar 2 (Rhythm Is Respect) — the rhythm changes without the player having a chance to read it. Revisit post-MVP if encounter design requires it.

**Why no player-applied FLUX debuff on enemies:** Enemy FLUX governs the offensive window given to the player, not a resource the enemy accumulates. Debuffing it would be a do-nothing effect. Revisit if the Timing Combat System establishes that FLUX affects enemy offensive windows.

**StatusEffectData — Registry Entry Schema**

Each named effect is a `StatusEffectData` resource in the effect registry. The registry is authoritative — no status effect exists at runtime that is not registered. All fields are **read-only at runtime** — no system may mutate a `StatusEffectData` instance after it has been loaded (same policy as `AbilityData` in the AS GDD). All tunable fields must be marked `@export` for editor access.

| Field | Type | Range | Description |
|-------|------|-------|-------------|
| `id` | StringName | Unique, non-empty | Machine key; referenced by `status_effect_id` in AbilityData |
| `display_name` | String | 1–24 characters | Player-facing label in HUD and status list |
| `stat_affected` | enum | ATK=0, DEF=1, SPD=2, FLUX=3 | Which stat this effect modifies |
| `modifier_value` | int | −30 to +30, excluding 0 | Signed integer; negative = debuff, positive = buff |
| `duration_turns` | int | 1–5 | Number of the *affected combatant's own turns* the effect persists |
| `valid_targets` | enum | ENEMY_ONLY=0, ALLY_ONLY=1, ANY=2 | Design-time targeting constraint; enforced at application; violations are silently rejected with a content warning |
| `icon_id` | StringName | Non-empty | Asset reference for HUD icon |
| `color_tint` | Color | — | HUD tint; convention: cool tones for debuffs, warm for buffs |
| `sfx_apply_id` | StringName | Non-empty | Audio event ID passed to Audio System on first application (not replayed on refresh) |
| `sfx_expire_id` | StringName | Non-empty recommended; see Visual/Audio Requirements | Audio event ID passed to Audio System on natural expiry only |

**Application Rules**

Status effects are applied via the `ability_resolved(id, grade, target)` signal emitted by the Ability System after each ability execution. Status Effects listens to this signal and applies the effect if ALL of the following are true:

1. `AbilityData.status_effect_id` is non-empty (the ability has a status payload)
2. `grade` is HIT or PERFECT — a MISS never triggers a status effect regardless of `status_trigger_grade`
3. `grade >= status_trigger_grade` using the ordered comparison HIT=1, PERFECT=2, ANY=0 (ANY is satisfied by any non-MISS grade). At runtime this is a string-based match, not a numeric comparison — see Formula 3.
4. The target passes the `valid_targets` check on the StatusEffectData
5. The named effect is registered

Conditions are evaluated in the order listed and short-circuit at the first failure. Condition 1 (empty check) is the cheapest gate and eliminates the most frequent case — most abilities have no status payload. Condition 5 (registry lookup) is last to avoid unnecessary registry reads for abilities that fail earlier conditions.

If any condition fails, application is silently skipped. The ability still resolved; only the status payload was not applied.

**PERFECT block suppression — TCS responsibility:** On a PERFECT block, TCS does not call `resolve_ability()` for the blocked enemy ability and therefore does not emit `ability_resolved`. SE has no guard for this case — it relies entirely on TCS gating the signal. This is documented here for cross-reference clarity; the implementation responsibility belongs to TCS.

**Stacking Rules**

- **Same effect (same `effect_id`)**: Refresh only. The existing entry's `turns_remaining` resets to `duration_turns`. Magnitude does not increase. No second entry is added.
- **Different effects on the same stat**: Additive stacking. Both modifier values contribute to `sum(active_status_modifiers)`. No hard cap — at MVP with 8 defined effects and refresh-only same-effect stacking, a combatant can have at most one buff and one debuff active per stat at any time. **This is an emergent MVP property, not an enforced architectural invariant.** A future expansion that adds a second ATK debuff with a different `effect_id` would allow two debuffs on the same stat simultaneously, and STATUS_MOD could reach the −60 to +60 theoretical range from Formula 1. The effective_stat clamp handles this safely, but encounter authors must be aware that the practical bound may widen in later episodes.
- **Conflicting buffs and debuffs on the same stat**: Both remain active. The effective stat formula sums all modifiers. Both icons are visible; the net result is transparent.

**Duration and Expiry**

- **Duration unit**: Each of the *affected combatant's own actions* decrements `turns_remaining` by 1. A double-action round counts as two decrements — two actions, two `tick_turn` calls.
- **Decrement timing**: Fires at **turn-end** — the moment the combatant's action resolves and control passes to the next combatant. Driven by TCS calling `tick_turn(combatant_id)`.
- **`tick_round_end` is a no-op at MVP**: All duration decrements happen via `tick_turn`. The `tick_round_end` method is a stub for post-MVP round-scoped effects. TCS calls it at round end; SE ignores it at MVP.
- **PERFECT counter exempt**: A PERFECT block triggers a counter (basic_attack at HIT grade fired by TCS on the blocker's behalf). This counter is not player-initiated and does not constitute "the combatant's own action" for SE duration purposes. `tick_turn` does not fire for the blocking character when a counter resolves.
- **Same-ability effect visibility**: Effects applied synchronously within the `ability_resolved` handler are immediately visible to any `get_modifier()` call made after the handler returns, including to TCS's damage calculation for that same ability. A debuff applied by ability X will affect that same ability's damage calculation if TCS reads stats after `resolve_ability()` returns.

> **Encounter-design authoring note:** An enemy ability that applies DISSONANCE (−ATK) to a player character as part of its payload will reduce its own effective ATK on that same hit — because DISSONANCE fires before TCS computes damage at step 5. The first application will deal slightly less damage than the authored `ATK_base` value alone would produce. Encounter authors must account for this first-hit discount when calibrating DISSONANCE-carrying enemy abilities. Subsequent turns are not affected — the debuff was already active on those.
- **Natural expiry**: When `turns_remaining` reaches 0, the entry is removed immediately and `status_effect_expired(combatant_id, effect_id, "natural")` is emitted. The effective stat recalculates on the next read — no explicit recalculation call is required.
- **Incapacitation**: When a combatant reaches `HP_current = 0`, all active effects are cleared immediately. `status_effect_expired(combatant_id, effect_id, "incapacitated")` is emitted for each entry so the HUD clears correctly. No expiry audio plays.
- **Encounter boundary**: All status state is encounter-scoped. `status_effect_expired(combatant_id, effect_id, "encounter_end")` is emitted for each active effect on each combatant before trackers are discarded (inside `initialize_encounter`). No expiry audio plays. No active effect survives encounter end. Nothing is written to save data.
- **Signal re-entrancy**: SE's internal state mutation and `status_effect_applied`/`status_effect_expired`/`status_effect_tick` signal emissions are synchronous within the `ability_resolved` handler. Only callbacks back into TCS (if any arise in future revisions) must use `call_deferred()` to prevent signal re-entrancy; the preferred pattern for future connections back to TCS is `connect(callable, CONNECT_DEFERRED)` at connection time, not `call_deferred()` at call sites. No such callbacks exist at MVP — SE does not call back into TCS from within `ability_resolved`.
- **`ability_resolved` connection mode**: SE must connect to the AbilitySystem's `ability_resolved` signal with `CONNECT_DEFAULT` (not `CONNECT_DEFERRED`). The "immediately visible" guarantee for same-ability effect visibility depends on SE's handler running synchronously within the `resolve_ability()` call before TCS reads stats at step 5 of its resolution sequence. Deferred connection would silently break this ordering.
- **TCS `tick_round_end` note**: The TCS GDD Round End Sequence currently reads "Notify Status Effects: end-of-round tick (decrement durations, expire finished effects)." This description is inaccurate for MVP — `tick_round_end` is a no-op and no decrements occur at round end; all decrements happen at TURN_END via `tick_turn`. The TCS GDD requires an amendment to this sequence item to match. See cross-GDD work required.

---

### States and Transitions

An effect instance has three states, encoded in array membership and `turns_remaining`:

| State | Represented As | Meaning |
|-------|---------------|---------|
| INACTIVE | Entry absent from `active_effects` | Effect is not present on this combatant |
| ACTIVE | Entry present; `turns_remaining ≥ 1` | Modifier is applied to all stat queries |
| EXPIRED | `turns_remaining == 0` (transient) | Removed immediately in the same frame |

There is no QUEUED or PENDING state. Application is synchronous — effects are present or absent, never mid-flight.

**Transition table:**

| From | To | Trigger | Action |
|------|----|---------|--------|
| INACTIVE | ACTIVE | `ability_resolved` received; grade qualifies; target valid; no matching `effect_id` exists | Append new `ActiveStatusEffect`; `turns_remaining = duration_turns`; emit `status_effect_applied(..., is_refresh: false)`; Audio System plays `sfx_apply_id` |
| INACTIVE | ACTIVE (refresh) | `ability_resolved` received; grade qualifies; matching `effect_id` already present | Reset existing `turns_remaining = duration_turns`; emit `status_effect_applied(..., is_refresh: true)`; **audio does NOT replay** — Audio System reads `is_refresh` flag; HUD updates counter only |
| ACTIVE | ACTIVE | `tick_turn(combatant_id)` called; `turns_remaining > 1` | `turns_remaining -= 1`; emit `status_effect_tick(combatant_id, effect_id, turns_remaining)` |
| ACTIVE | EXPIRED | `tick_turn(combatant_id)` called; `turns_remaining == 1` | `turns_remaining = 0`; emit `status_effect_expired(combatant_id, effect_id, "natural")`; remove entry |
| ACTIVE | INACTIVE (forced — incapacitated) | `notify_incapacitated(combatant_id)` called | Remove all entries; emit `status_effect_expired(combatant_id, effect_id, "incapacitated")` for each; no audio |
| ACTIVE | INACTIVE (forced — encounter end) | `initialize_encounter(combatant_ids)` called | Emit `status_effect_expired(combatant_id, effect_id, "encounter_end")` for each active entry; remove all; discard tracker; no audio |

**Per-combatant runtime state (StatusTracker):**

```
ActiveStatusEffect {
  effect_id:       StringName   # references StatusEffectData.id
  stat_affected:   int (enum)   # cached from StatusEffectData at application time
  modifier_value:  int          # cached from StatusEffectData at application time
  turns_remaining: int          # 1–5 at application; decrements to 0 at expiry
}

StatusTracker {
  combatant_id:    StringName
  active_effects:  Array[ActiveStatusEffect]
}
```

StatusTrackers are instantiated at encounter start and discarded at encounter end. They are not Resources and are not persisted.

> **Godot 4.6 — class_name requirement:** `ActiveStatusEffect` must be defined in `active_status_effect.gd` with `class_name ActiveStatusEffect`. `StatusTracker` must be defined in `status_tracker.gd` with `class_name StatusTracker`. **Both must extend `RefCounted`** (not `Object`, not `Node`) — `RefCounted` subclasses are freed automatically when no references remain, which is required for correct memory management when trackers are discarded at encounter end. Using `Object` instead will cause memory leaks every encounter. Both files are required for typed `Array[ActiveStatusEffect]` in Godot 4.6 GDScript — inner classes without `class_name` are not valid typed array type parameters at compile time. This is the same requirement applied to `ComboState` and `InheritedAbilityUnlockRecord` in the Ability System GDD. Both class_names must be globally unique in the project — a duplicate `class_name` declaration causes silent registration failure where one definition wins unpredictably.
>
> **Typed Dictionary:** `Dictionary[StringName, StatusTracker]` typed syntax was added in Godot 4.4 and is confirmed available in Godot 4.6. Use the typed form — do not use an untyped `Dictionary`. The untyped fallback is not an accepted implementation path; it disables compile-time type checks for all tracker lookups.

**Public API (methods exposed to other systems):**

| Method | Called By | Description |
|--------|-----------|-------------|
| `get_modifier(combatant_id, stat) → int` | Timing Combat System | Returns summed signed modifier for the given stat. Returns 0 if no effects active. *(Renamed from `get_stat_modifier` to match TCS GDD interface contract.)* |
| `get_active_effects(combatant_id) → Array[ActiveStatusEffect]` | HUD System | Returns a deep copy of all active effect structs. Each element must be an independent instance; callers may not mutate elements to corrupt tracker state. Used by HUD for icon display and turn-count rendering. **Implementation note:** `Array.duplicate_deep()` (Godot 4.5+) creates new instances for `Resource` subclasses but its behavior for `RefCounted` subclasses in a typed Array is unverified in the project engine reference docs. A pre-implementation smoke test is required to confirm `duplicate_deep()` on `Array[ActiveStatusEffect]` creates new object instances. If it does not, use a manual copy loop: `var copy: Array[ActiveStatusEffect] = []; for e in active_effects: var c = ActiveStatusEffect.new(); c.effect_id = e.effect_id; c.stat_affected = e.stat_affected; c.modifier_value = e.modifier_value; c.turns_remaining = e.turns_remaining; copy.append(c); return copy`. |
| `get_active_effect_ids(combatant_id) → Array[StringName]` | Timing Combat System | Returns only the `effect_id` StringNames of all active effects. Used by TCS to populate `encounter_state.active_effects`. |
| `extend_effect_duration(combatant_id, effect_id, bonus_turns: int) → void` | Ability System (STATUS_ADD combo enhancement) | Adds `bonus_turns` to the named effect's `turns_remaining` if it is currently active on the combatant. Implementation: `turns_remaining = min(turns_remaining + bonus_turns, StatusEffectData.duration_turns × 2)` where `duration_turns` is the authored immutable value from `StatusEffectData`, not the current `turns_remaining`. If `turns_remaining` is already at the cap, the call is a no-op. No-op if the effect is not active or `bonus_turns ≤ 0`. No signal emitted. |
| `has_effect(combatant_id, effect_id) → bool` | Passive triggers, authoring checks | True if the named effect is currently active on the combatant. |
| `tick_turn(combatant_id) → void` | Timing Combat System | Decrements `turns_remaining`; removes expired entries; emits `status_effect_expired` for each expired entry and `status_effect_tick` for each entry that decremented but did not expire. Called once per action at TURN_END. *(Renamed from `notify_turn_ended` to match TCS GDD interface contract.)* |
| `tick_round_end(combatant_id) → void` | Timing Combat System | **MVP stub — always no-op.** All duration decrements occur via `tick_turn`. This method exists for post-MVP round-scoped effects (e.g., STUN). TCS calls it; SE ignores it at MVP. |
| `check_turn_skip(combatant_id) → bool` | Timing Combat System | **MVP stub — always returns `false`.** No STUN or turn-skip effects exist at MVP. Post-MVP: returns `true` if a turn-skip effect is active on the named combatant. |
| `initialize_encounter(combatant_ids) → void` | Timing Combat System (from `ENCOUNTER_START` state) | Emits `status_effect_expired(combatant_id, effect_id, "encounter_end")` for all currently active effects before discarding trackers. Creates a fresh `StatusTracker` per combatant. If no trackers exist (game start / first encounter), the emit loop is a no-op — this is correct. Called by TCS only — no other system calls this at MVP. |
| `notify_incapacitated(combatant_id) → void` | Timing Combat System | Calls `active_effects.clear()` on the named combatant's existing `StatusTracker`, then emits `status_effect_expired(combatant_id, effect_id, "incapacitated")` for each cleared entry. **The tracker object itself remains in the combatant registry — it is NOT removed.** Only `initialize_encounter` removes trackers from the registry. This means a subsequent `apply_effect` call targeting an incapacitated combatant will find a valid (empty) tracker and add a new entry — SE adds no guard; TCS is responsible for preventing targeting of incapacitated combatants (see Edge Cases: Post-Incapacitation Targeting and AC-33). *(Note: the TCS GDD's SE interface table must be updated to include this call — it is currently missing from that table.)* |

> **Internal only — not in public API:** `apply_effect(combatant_id, effect_id)` is an internal method called by the `ability_resolved` signal handler after all external conditions (grade check, target validity, registration) have been verified. It is not callable by external systems and cannot be used to bypass grade enforcement.

**Signals emitted:**

| Signal | Payload | Subscribers | Notes |
|--------|---------|-------------|-------|
| `status_effect_applied(combatant_id, effect_id, turns_remaining, stat_delta_key, modifier_delta, is_refresh)` | StringName, StringName, int, StringName, int, bool | HUD System, Audio System | `stat_delta_key` is the StringName of the affected stat (e.g., `&"ATK"`, `&"FLUX"`). `modifier_delta: int` is the signed change in STATUS_MOD caused by this application — the value SE actually owns. On first application (`is_refresh == false`): `modifier_delta == modifier_value` from StatusEffectData (the full signed modifier). On refresh (`is_refresh == true`): `modifier_delta == 0` — the modifier is unchanged; only `turns_remaining` reset. **HUD handling of refresh zero-delta:** On receiving `status_effect_applied` with `is_refresh == true`, the HUD must not rely on `modifier_delta` to update display state (it will always be 0). HUD subscribers requiring current effective-stat values (e.g., to re-compute the MUTED timing-bar width on refresh) must query their own CharacterData source. `is_refresh: bool` — `true` when the effect was already active and `turns_remaining` was reset; `false` on first application. Audio System plays `sfx_apply_id` only when `is_refresh == false`. *(Renamed from `status_applied`; redesigned in RP3: old_value/new_value replaced with modifier_delta — SE owns only the modifier layer and cannot compute effective-stat values without an undeclared CS&G dependency.)* |
| `status_effect_expired(combatant_id, effect_id, cause)` | StringName, StringName, StringName | HUD System, Audio System | `cause` ∈ `{"natural", "incapacitated", "encounter_end"}`. *(Renamed from `status_expired`.)* |
| `status_effect_tick(combatant_id, effect_id, turns_remaining)` | StringName, StringName, int | HUD System | Emitted from `tick_turn` when an effect decrements but does not expire (`turns_remaining > 1` after decrement). Used by the HUD for per-turn countdown updates without polling. Not emitted on expiry (a `status_effect_expired` fires instead). *(New signal; declared per HUD GDD Required Upstream Amendment.)* |

**`status_effect_expired` cause behavior:**

| Cause | Audio behavior | HUD animation |
|-------|---------------|---------------|
| `"natural"` | Play `sfx_expire_id` (if non-empty) | Fade-out |
| `"incapacitated"` | No audio | Snap-remove |
| `"encounter_end"` | No audio | Snap-remove |

**Audio ownership:** The Audio System subscribes to `status_effect_applied` and `status_effect_expired` signals and calls `play_sfx()` with the appropriate `sfx_apply_id` / `sfx_expire_id` from StatusEffectData. SE does not call the Audio System directly. The `is_refresh` flag on `status_effect_applied` allows the Audio System to suppress audio on refresh without maintaining shadow state. The Audio System GDD's Interactions table must be updated to include Status Effects as an upstream signal source. See the Required Audio System GDD Amendments section in Visual/Audio Requirements for the full list of changes needed.

---

### Interactions with Other Systems

| System | Direction | What Flows |
|--------|-----------|------------|
| **Ability System** | Upstream → Status Effects | `ability_resolved(id, grade, target)` signal; AbilityData fields `status_effect_id` and `status_trigger_grade` carry the payload definition. AS also calls `extend_effect_duration()` for STATUS_ADD combo enhancements. |
| **Character Stats & Growth** | Upstream (provides base stats) | Status Effects contributes `sum(active_status_modifiers)` via `get_modifier()`; the full effective-stat formula is evaluated by the querying system, not by Status Effects |
| **Timing Combat System** | Bidirectional | TCS calls `get_modifier()` before every stat-dependent calculation; `tick_turn()` at each TURN_END; `tick_round_end()` at ROUND_END (no-op at MVP); `check_turn_skip()` at TURN_START (always false at MVP); `notify_incapacitated()` on HP=0; `initialize_encounter()` at ENCOUNTER_START |
| **HUD System** | Status Effects → downstream | `status_effect_applied`, `status_effect_expired`, and `status_effect_tick` signals; `get_active_effects()` for full struct access (icon display, turn count); `get_active_effect_ids()` not needed by HUD |
| **Audio System** | Status Effects → downstream | `status_effect_applied` signal (Audio System plays `sfx_apply_id` when `is_refresh == false`); `status_effect_expired` with `cause = "natural"` (Audio System plays `sfx_expire_id` if non-empty) |
| **Enemy System** | Sibling, shared data | Enemies apply effects via the same `ability_resolved` path; enemies receive effects from player abilities via the same application logic. `valid_targets` is the only directional constraint |
| **Save System** | No dependency | Status state is encounter-scoped and never persisted |

## Formulas

### Formula 1 — STATUS_MOD (Status Modifier Aggregation)

The Status Effects system contributes a single signed integer per combatant per stat to the effective stat formula. This is the sum of all active modifier values for the given stat on the given combatant.

```
STATUS_MOD(combatant, stat) = sum of modifier_value
  for all ActiveStatusEffect entries in combatant.active_effects
  where entry.stat_affected == stat
```

**Variables:**

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `modifier_value` (per entry) | int | −30 to +30, excluding 0 | Signed integer from `StatusEffectData.modifier_value`; cached in `ActiveStatusEffect` at application time |
| `active_effects` | Array | 0–N entries | All currently active effects on this combatant; only entries matching `stat_affected` contribute |

**Output range:** −60 to +60 (theoretical maximum: two effects on the same stat, each at ±30). In practice at MVP, at most one buff and one debuff can be active per stat simultaneously, bounding STATUS_MOD to −30 to +30 per stat. Returns 0 if no effects are active for this combatant+stat combination.

This is `get_modifier(combatant_id, stat)` in the public API.

---

### Formula 2 — Effective Stat with Status Modifiers (Reference)

This formula is owned by Character Stats & Growth. Restated here with the STATUS_MOD term made explicit to show where Status Effects plugs in.

```
effective_stat = max(1, min(99, base_stat + sum(NIO) + STATUS_MOD))
```

**Variables:**

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `base_stat` | int | 1–99 | Character's permanent stat from Character Stats & Growth |
| `sum(NIO)` | int | 0 to `INHERITANCE_MAX × max_guests_per_stat` | Sum of all Named Inheritance Object modifiers for this stat. Exact ceiling derived from CS&G GDD INHERITANCE_MAX formula and the maximum number of departing guests per episode. The effective_stat double-clamp (max 1, min 99) handles any combination regardless of exact ceiling. |
| `STATUS_MOD` | int | −30 to +30 (MVP practical bound; theoretical max −60 to +60 — see Formula 1 Output Range) | Output of Formula 1 for this combatant+stat |
| `effective_stat` | int | 1–99 | Final stat used by Timing Combat System; clamped to floor 1, ceiling 99 |

**Output range:** Always 1–99. A debuff cannot drive a stat to zero. A buff cannot exceed 99.

**Worked example — ATK debuff on enemy:**
- Enemy ATK (base) = 18, no inheritance objects
- Active effect: DISSONANCE with `modifier_value = −6`
- `STATUS_MOD = −6`
- `effective_stat = max(1, min(99, 18 + 0 + (−6))) = 12`

**Worked example — competing ATK effects on a party member:**
- Ne ATK (base) = 18, no inheritance objects
- Active effect 1: DISSONANCE (−5, enemy-applied after a missed block)
- Active effect 2: RESONANCE (+6, player-applied on a prior turn — different `effect_id`, same stat)
- `STATUS_MOD = −5 + 6 = +1`
- `effective_stat = max(1, min(99, 18 + 0 + 1)) = 19`

**Worked example — DEF buff on Clawd with inheritance:**
- Clawd DEF (base) = 16, Named Inheritance Object = +2
- Active effect: FORTIFY with `modifier_value = +5`
- `STATUS_MOD = +5`
- `effective_stat = max(1, min(99, 16 + 2 + 5)) = 23`

---

### Formula 3 — Grade Threshold Comparison (Formal)

Governs whether a timing grade qualifies to trigger a status effect payload.

```
effect_triggers = (grade != MISS) AND (grade >= status_trigger_grade)
```

**Grade encoding (design-reasoning reference only — not used as runtime values):**

| Grade | Ordering value | Notes |
|-------|---------------|-------|
| MISS | −1 | Never triggers; excluded by explicit guard |
| HIT | 1 | Authored as `StringName &"HIT"` at runtime |
| PERFECT | 2 | Authored as `StringName &"PERFECT"` at runtime |

> `"ANY"` (ordering value 0) is **not a valid authored value** for `status_trigger_grade` at runtime. `status_trigger_grade ∈ {&"HIT", &"PERFECT"}` — no other values are permitted per the AbilityData schema in the Ability System GDD. To achieve "trigger on any non-MISS grade," author `status_trigger_grade = &"HIT"`. The integer encoding above is a design-reasoning reference only; the runtime implementation uses a string-based match/lookup, not a numeric `>=` operator.

**Truth table (exhaustive — all valid input combinations):**

| Incoming Grade | status_trigger_grade | Triggers? | Reason |
|----------------|---------------------|-----------|--------|
| MISS | `"HIT"` | No | MISS always excluded by explicit guard |
| MISS | `"PERFECT"` | No | MISS always excluded by explicit guard |
| HIT | `"HIT"` | Yes | Grade matches threshold |
| PERFECT | `"HIT"` | Yes | Grade exceeds threshold (2 > 1) |
| HIT | `"PERFECT"` | No | Grade below threshold (1 < 2) |
| PERFECT | `"PERFECT"` | Yes | Grade matches threshold |

**Design intent:** PERFECT-gated effects are reserved for the most impactful status payloads — they require genuine timing precision to apply. HIT-or-better effects (`status_trigger_grade = "HIT"`) are accessible with baseline competence and trigger on both HIT and PERFECT; use sparingly to avoid undermining the timing economy.

**Note on the MISS guard:** The explicit `grade != MISS` check is logically redundant when `status_trigger_grade = "HIT"` (MISS always fails the HIT comparison regardless). It is retained as an explicit safety assertion for implementer clarity.

---

**What this section does NOT define:**
- The damage formula — owned by Timing Combat System GDD; ATK and DEF effective stats feed into it as inputs
- Duration or magnitude values per named effect — authored per `StatusEffectData` entry, not global formulas

## Edge Cases

### MUTED Applied While TREMOLO Is Active (Competing FLUX Effects)

If TREMOLO (FLUX+6) is active on a character and MUTED (FLUX−4) is then applied by an enemy, both entries coexist in `active_effects`. `STATUS_MOD` for FLUX = +6 + (−4) = +2. The timing window is slightly wider than native — the net result is visible from both active icons. Neither effect cancels the other. Both count down independently.

### SLUGGISH Applied — SPD Drops Below SWIFT_THRESHOLD Mid-Round

TURNS_PER_ROUND is calculated at round start and locked for the full round (per Character Stats & Growth GDD). If SLUGGISH is applied to a double-acting enemy during the round — after their first action but before their second — the turn order for the current round is unchanged. The suppressed double-action takes effect at the start of the next round when TURNS_PER_ROUND recalculates using the now-reduced effective SPD. SLUGGISH applied before a round starts suppresses double-action for that entire round.

### SLUGGISH Applied — Net SPD Still Above SWIFT_THRESHOLD

If SLUGGISH does not push the target below SWIFT_THRESHOLD (e.g., Ne SPD=20 takes SLUGGISH −4 → effective SPD 16; SPD_min=11; 16/(11×1.5)=0.97 — still double-acting), the character continues to double-act. Both actions in that round decrement `turns_remaining`. The player applied a debuff that was not strong enough — the double-action burns through the debuff faster. This is correct and intended.

### QUICKEN Applied — Pushes Character Over SWIFT_THRESHOLD

If QUICKEN raises net SPD above SWIFT_THRESHOLD when it previously was not, the double-action does not take effect until the next round (TURNS_PER_ROUND is locked at round start). The bonus action appears at the top of the next round. If QUICKEN expires before the next round starts, the double-action never materializes. Duration-1 QUICKEN applied after a round starts provides no double-action benefit for that round.

**Authoring requirement:** `duration_turns = 1` on QUICKEN creates a silent trap. If applied after the round starts, the effect decrements on the character's remaining action in the current round, then expires before the next TURNS_PER_ROUND recalculation — the double-action benefit is never realized. Content authors must use `duration_turns >= 2` for QUICKEN unless the ability is specifically designed to be applied before round start. A **required** load-time content validation (`assert` or `push_error` in debug/editor builds) must flag any QUICKEN `StatusEffectData` entry with `duration_turns = 1`. This is not advisory — silent mechanical failure with no player feedback is not acceptable. See AC-32 for the acceptance criterion.

### PERFECT Counter Is Exempt from Duration Counting

A PERFECT block triggers a counter — a basic_attack at HIT grade fired by TCS on the blocking character's behalf. This counter is not player-initiated and does not consume CC. It does not constitute "the combatant's own action" for SE duration purposes. `tick_turn` does not fire for the blocking character when the counter resolves. Active buffs (e.g., FORTIFY, TREMOLO) on the blocking character are not decremented by the counter. Skilled defensive play does not burn through its own buffs.

### DISSONANCE and MUTED Compounding in the Same Turn

If an enemy ability or sequence of enemy actions applies both DISSONANCE and MUTED to the same party member in the same turn, the player simultaneously has weakened offense and a narrowed timing window for 2 turns. This is the most punishing compound state the system can produce.

**Encounter design constraint:** Enemy ability configurations or turn sequences that deliver both DISSONANCE and MUTED to the same party member in the same turn must be followed by a recovery window (at minimum one full round without additional DISSONANCE- or MUTED-carrying enemy actions targeting that character). This is an encounter-design responsibility — the Status Effects system has no guard for it.

### Status Effect Applied to an Already-Incapacitated Combatant

If `ability_resolved` fires targeting a combatant whose `HP_current = 0`, their `StatusTracker` was already cleared by `notify_incapacitated()`. A new entry would be added to an otherwise empty tracker — technically valid but meaningless. This is not a Status Effects concern — targeting an incapacitated combatant is the Timing Combat System's responsibility to prevent. Status Effects adds no guard; it processes whatever targets TCS sends.

### valid_targets Mismatch at Runtime

If an ability's `status_effect_id` references an effect with `valid_targets = ENEMY_ONLY` but the ability resolves against an ally target, the application check fails silently and a content warning is logged. The ability executes; only the status payload is not applied. This is an authoring error — it surfaces in content review, not as a runtime exception.

### Refresh on an Effect with turns_remaining = 1

If DISSONANCE is at `turns_remaining = 1` and the same `effect_id` is applied again: `turns_remaining` resets to the full `duration_turns`. There is no partial refresh — the reset is always to full duration. Chained PERFECT hits with status payloads restore the full window on each hit. `status_effect_applied` fires on refresh with `is_refresh = true`; audio does not replay.

### Same Effect Applied Twice in One Turn (Two Sources)

If both a player ability and an enemy ability resolve in the same turn with the same `status_effect_id` targeting the same combatant, the second `apply_effect` call finds the entry already present and refreshes `turns_remaining` to full. The net result is full duration, as if applied once. Order of signal delivery determines which is "first"; both produce the same outcome. `status_effect_applied` fires with `is_refresh = false` on the first application (Audio System plays sfx); `status_effect_applied` fires again with `is_refresh = true` on the refresh (Audio System suppresses sfx).

### FORTIFY or RESONANCE Targeting an Enemy

FORTIFY and RESONANCE have `valid_targets = ALLY_ONLY`. If authored against an enemy target, the `valid_targets` check fails silently. Content warning logged. These are authoring errors; correct in content review before ship.

### Encounter Ends Mid-Effect

When an encounter ends while status effects are active, `status_effect_expired(combatant_id, effect_id, "encounter_end")` is emitted for each active effect on each combatant inside `initialize_encounter` before trackers are discarded. No expiry audio plays — the encounter-end context is the dominant event. The HUD snap-removes all status icons on receiving `status_effect_expired` with `cause = "encounter_end"`. Party members enter every encounter with clean stat profiles (base + Named Inheritance Objects only).

## Dependencies

### Upstream (Status Effects requires these to function)

| System | What Is Required | When |
|--------|-----------------|------|
| **Ability System** | `ability_resolved(id, grade, target)` signal; AbilityData fields `status_effect_id` and `status_trigger_grade` carry the payload definition | After each ability execution |
| **Character Stats & Growth** | Stat vocabulary definition (ATK, DEF, SPD, FLUX); effective stat formula structure (Status Effects contributes STATUS_MOD to it) | At design time — this GDD must not contradict the stat schema |
| **Timing Combat System** | Calls `tick_turn(combatant_id)` per action at TURN_END; calls `tick_round_end(combatant_id)` at ROUND_END (no-op at MVP); calls `check_turn_skip(combatant_id)` at TURN_START (always false at MVP); calls `notify_incapacitated(combatant_id)` on HP=0; calls `initialize_encounter(combatant_ids)` at ENCOUNTER_START | During every encounter |

### Downstream (systems that depend on Status Effects)

| System | What It Receives | When |
|--------|-----------------|------|
| **Timing Combat System** | `get_modifier(combatant_id, stat)` — used before every stat-dependent calculation (damage, turn order, timing window); `get_active_effect_ids(combatant_id)` for encounter_state population | Each turn, during combat resolution |
| **HUD System** | `status_effect_applied`, `status_effect_expired`, and `status_effect_tick` signals; `get_active_effects()` for full struct access and display reconstruction | Continuously during combat |
| **Audio System** | `status_effect_applied` signal (→ play `sfx_apply_id` when `is_refresh == false`); `status_effect_expired` with `cause = "natural"` (→ play `sfx_expire_id` if non-empty) | On application and natural expiry |
| **Ability System** | SE exposes `extend_effect_duration(combatant_id, effect_id, bonus_turns)` for STATUS_ADD combo payoffs | After PERFECT combo payoff resolves on a STATUS_ADD ability |
| **Enemy System** | Enemies receive and apply effects through the same path as player abilities. Enemy System is responsible for authoring `status_effect_id` and `status_trigger_grade` in enemy AbilityData entries | At enemy ability execution |

### Shared Data

| System | Relationship |
|--------|-------------|
| **Effect Registry** | The StatusEffectData registry is owned and read by this system. All other systems reference effects by `id` (StringName) only — they never read StatusEffectData fields directly. |

### What This System Does NOT Depend On

- **Save System** — Status state is encounter-scoped and never persisted.
- **Guest Character System** — Inherited abilities may carry `status_effect_id` payloads, but the delivery mechanism is identical to any other ability. No special path.
- **Party Composition Manager** — Status Effects receives `combatant_id` values from TCS at `initialize_encounter`; it does not query the party roster directly.
- **Input & Timing Detection** — Grades flow ITD → TCS → Ability System → `ability_resolved`. Status Effects never touches raw input.

## Tuning Knobs

All values listed here are data-driven and externally configurable. No magnitude, duration, or threshold is hardcoded.

### Per-Effect Knobs (authored in StatusEffectData)

| Knob | Field | Default Range | Safe Range | Effect |
|------|-------|---------------|------------|--------|
| Effect magnitude | `modifier_value` | −4 to −7 (debuffs) / +3 to +6 (buffs) | −30 to +30 | How much the stat shifts. Below ±2: imperceptible on most stat ranges. Above ±12: risks pushing stats toward floor/ceiling in short encounters. |
| Effect duration | `duration_turns` | 2 turns (most effects); 1–2 (QUICKEN) | 1–5 | How long the effect persists. Above 3: effects persist across most of an average encounter, blurring distinction from permanent stat changes. |
| Grade threshold | `status_trigger_grade` | PERFECT for high-impact effects; HIT for moderate | `"HIT"`, `"PERFECT"` (StringName; see Formula 3) | Lower threshold = more frequent application = weaker timing pressure. Reserve `"HIT"` (ANY-grade behavior) for very low-magnitude effects only. |

### Global Knobs (inherited from upstream systems)

| Knob | Owned By | Default | Effect on Status Effects |
|------|----------|---------|--------------------------|
| `SWIFT_THRESHOLD` | Character Stats & Growth | 1.5 | Determines when SLUGGISH suppresses double-action. Changing this affects how large a SLUGGISH magnitude needs to be to strip double-action from a given enemy. |
| `TIMING_WINDOW_FRAMES_MAX` | Character Stats & Growth | 30 | Ceiling clamp on timing windows. A large TREMOLO buff on a high-FLUX character approaches this ceiling — TREMOLO's visible effect shrinks as effective FLUX approaches 30. |
| `EFFECTIVE_FLUX_FLOOR` | Status Effects (this GDD) | 8 | Minimum effective FLUX after all status modifiers. Prevents MUTED from creating sub-reaction-threshold timing windows. At 8: minimum TIMING_WINDOW_FRAMES = 8 (~133ms), PERFECT_ZONE_SIZE = 2 frames. Safe range: 6–10. Below 6: approaches reaction-time limit. Above 10: MUTED has negligible impact on high-FLUX characters. |

### What Is NOT Tunable

- Which stats Status Effects can modify — fixed at ATK, DEF, SPD, FLUX at MVP
- Stacking rules (refresh-only for same effect; additive for different effects) — architectural
- Turn-counting model (action-counted via `tick_turn`, not round-counted) — architectural
- Whether MISS can trigger effects — always false; not configurable

## Visual/Audio Requirements

Status Effects is a Gameplay/Combat system — visual and audio communication is mandatory.

### Per-Effect Application

- Each effect application must produce a visual indicator on the affected combatant (sprite flash, particle, or aura) distinct from the ability animation. Must read clearly at combat camera distance.
- Each first application fires `sfx_apply_id` — a short audio sting unique per effect, distinct from ability hit sounds. **Refresh does not replay the sting** — `status_effect_applied` fires on refresh with `is_refresh = true`; the Audio System suppresses audio when `is_refresh` is `true`.
- Buff and debuff application sounds must be audibly different in tone: buffs lean warm/ascending; debuffs lean dissonant/descending — consistent with the game's musical vocabulary.

### Audio Ownership

The Audio System subscribes to `status_effect_applied` and `status_effect_expired` signals. SE does not call the Audio System directly.

- `status_effect_applied` with `is_refresh == false` → Audio System plays `sfx_apply_id`
- `status_effect_applied` with `is_refresh == true` → Audio System suppresses audio (no sfx)
- `status_effect_expired` with `cause = "natural"` → Audio System plays `sfx_expire_id` if non-empty
- `status_effect_expired` with `cause = "incapacitated"` → no audio
- `status_effect_expired` with `cause = "encounter_end"` → no audio

### Mixing Priority

Status effect apply stings are a secondary feedback layer. On a PERFECT hit with a status payload and CC gain, multiple SFX may fire in the same frame (ability hit sound, grade tone, CC chime, status sting). Status stings must be assigned lower pool-steal priority than grade tones in the Audio System — grade tones are the primary timing feedback signal and must not be interrupted or stolen. The Audio System GDD's mixing rules must specify this tier. A 50–100ms delay before the status sting fires after the grade tone is recommended to avoid simultaneous pool saturation.

**CC chime coexistence:** On a PERFECT hit that grants both a status effect and CC (via `cc_changed` with `source_type = "window_grade"`), a status apply sting and a grade tone fire simultaneously alongside the CC chime. The CC chime suppression rule (for `source_type = "ability_delta"`) does not affect status stings — these are independent audio events. The Audio System must auditionally validate this multi-event scenario.

---

### Required Audio System GDD Amendments

The following changes must be made to `design/gdd/audio-system.md` before SE implementation begins. They are documented here because the Audio System GDD was last updated before Revision Pass 1 added Pattern B audio ownership and the extended signal schema.

1. **Add SE to the Interactions table** as an upstream signal source: `status_effect_applied`, `status_effect_expired`.
2. **Specify refresh suppression logic**: When `status_effect_applied` is received, Audio System plays `sfx_apply_id` only when `is_refresh == false`. When `is_refresh == true`, no audio is played. (The `is_refresh` flag eliminates the shadow-tracking requirement.)
3. **Define mixing priority tiers** for the pool-steal algorithm: grade tones (PROTECT — never stolen while playing); status stings (secondary — lower steal priority). Without priority tiers, a pool-saturated scenario can steal a grade tone to play a status sting, breaking the primary timing feedback signal.
4. **Specify the apply-sting delay mechanism**: A 50–100ms delay before status apply stings fire after the grade tone is required to avoid simultaneous pool saturation. The Audio System must define the mechanism (e.g., `play_sfx_delayed(sfx_id, delay_sec)` or a deferred call timer) and state whether this delay is applied per-signal or configured globally for the status-sting audio category.
5. **Document `sfx_expire_id` handling**: When `status_effect_expired` fires with `cause = "natural"`, Audio System plays `sfx_expire_id` if non-empty. Expiry audio shares the same pool as apply stings; confirm pool budget against simultaneous late-round expiry (up to 4–6 natural expiries in the same tick window is plausible).
6. **Cross-reference CC chime suppression**: The CC chime suppression rule for `source_type = "ability_delta"` must be documented in the Audio System GDD. Its interaction with status stings (they are independent audio events, unaffected by CC chime suppression) must be stated explicitly.

---

### HUD Status Icons

- Active effects display as icons on the affected combatant's combat portrait (party) or enemy condition display (enemies).
- Icon color uses `color_tint` from StatusEffectData: **cool tones for debuffs, warm tones for buffs** — consistent with the game's color philosophy.
- `turns_remaining` is displayed as a number on or beside each icon; updates immediately at each `tick_turn` decrement.
- Icons must be readable in greyscale — shape distinguishes buff/debuff, not color alone (colorblind accessibility).

### Per-Effect Expiry Audio Guidance

All 8 MVP effects should have non-empty `sfx_expire_id` — each expiry is tactically significant information for the player.

| Effect | sfx_expire_id | Rationale |
|--------|---------------|-----------|
| DISSONANCE | Non-empty | Enemy ATK restored / player ATK restored — offensive positioning changes |
| RESONANCE | Non-empty | Power window closing — player should stop expecting the damage bonus |
| FRACTURE | Non-empty | Enemy DEF restored — burst window closing |
| FORTIFY | Non-empty | Defensive window closing — player is now vulnerable again |
| SLUGGISH | Non-empty | Enemy speed restored — double-action may return next round |
| QUICKEN | Non-empty | Speed buff expired — double-action window no longer active |
| TREMOLO | Non-empty | Timing window narrows back to baseline — player should re-calibrate |
| MUTED | Non-empty | Most important expiry of all 8 — timing window restored; player must be notified |

### Effect Expiry

- On natural expiry (`cause = "natural"`): icon fades out; `sfx_expire_id` fires if non-empty.
- On incapacitation (`cause = "incapacitated"`): icons snap-removed with no expiry audio — the incapacitation event is the dominant feedback.
- On encounter end (`cause = "encounter_end"`): icons snap-removed with no expiry audio.

### MUTED — Special Communication Requirement

MUTED narrows the player's timing window — a subtle effect that may not be immediately legible. On MUTED application:
- The timing window visual must reflect the narrowed zone — the PERFECT zone indicator should be measurably smaller.
- A distinct MUTED application sting plays — audibly "dampening" in character (muffled, not a standard debuff sting). This requires Audio Director sign-off during asset review; it must not be authored as a standard descending debuff sweep.
- The HUD GDD must implement a first-encounter callout for MUTED explaining that the timing window has narrowed.

> **Asset Spec flag**: Visual/Audio requirements are defined. After the art bible is approved, run `/asset-spec system:status-effects` to produce per-asset visual descriptions and generation prompts from this section. MUTED's `sfx_apply_id` is flagged as a special case requiring Audio Director review — not standard debuff treatment.

## UI Requirements

- Active status effects display as icon + turn count per affected combatant. Party member effects appear on their portrait panel; enemy effects appear on the enemy condition display.
- The HUD must accommodate up to 8 simultaneous icons per combatant without clipping (MVP maximum: one per named effect; typical: 2–4).
- Icons must be accessible without mouse hover — effect name must be legible via keyboard/gamepad navigation at MVP.
- Buff icons and debuff icons must be visually distinguishable by shape, not color alone.
- `turns_remaining` count updates immediately at `tick_turn` call — not at the start of the affected character's next turn.

> **UX Flag — Status Effects**: This system has UI requirements. In Phase 4 (Pre-Production), run `/ux-design` to create a UX spec for the combat HUD status display before writing implementation stories. Stories referencing status icon layout should cite `design/ux/hud.md`, not this GDD directly.

## Acceptance Criteria

Each criterion must be independently verifiable by a QA tester.

> **GUT signal assertion methodology**: All ACs that require verifying a signal was emitted must use GUT v7.x's `watch_signals(subject)` before the action under test, followed by `assert_signal_emitted_with_parameters(subject, "signal_name", [arg1, arg2, ...])` to verify the full payload. "Signal fired" without payload verification is insufficient. In all cases, `subject` is the StatusEffects autoload/node.

**Effect Application** *(Logic — unit tests, BLOCKING gate)*

- AC-1: A PERFECT-grade ability with `status_trigger_grade = &"PERFECT"` applies the named effect to the target. Verify: `has_effect(target_id, effect_id) == true` after the `ability_resolved` signal fires with grade PERFECT. A HIT-grade signal with the same ability does not apply the effect: `has_effect(target_id, effect_id) == false`. Two separate test functions required.
- AC-2: An ability with `status_trigger_grade = &"HIT"` applies the effect on HIT grade (`has_effect(target_id, effect_id) == true`) and on PERFECT grade (`has_effect(target_id, effect_id) == true`). A MISS grade with the same ability does not apply the effect (`has_effect(target_id, effect_id) == false`). Three separate test functions required.
- AC-3: A MISS grade never applies a status effect regardless of `status_trigger_grade` being `&"HIT"` or `&"PERFECT"`. Verify: `has_effect(target_id, effect_id) == false` after `ability_resolved` fires with grade MISS. Two test cases required (one per authored threshold value).
- AC-4: An ability with an empty `status_effect_id` applies no status effect regardless of timing grade. Verify: `has_effect(target_id, &"")` returns false; `get_active_effects(target_id)` returns an empty array.
- AC-5: Applying an effect with `valid_targets = ALLY_ONLY` against an enemy target silently skips application: `has_effect(enemy_id, effect_id) == false` after `ability_resolved`. Applying an effect with `valid_targets = ENEMY_ONLY` against an ally target silently skips application: `has_effect(ally_id, effect_id) == false`. Both mismatch directions must be tested. A content warning is logged in both cases (assert on `push_error` invocation in debug build).

**Stacking and Refresh** *(Logic — unit tests, BLOCKING gate)*

- AC-6: Reapplying the same effect (`effect_id`) to a combatant that already has it active resets `turns_remaining` to `duration_turns`. Verify: (1) `get_active_effects(target_id)` returns exactly one entry for that `effect_id`; (2) that entry's `turns_remaining == duration_turns`; (3) `status_effect_applied` fired — assert full payload `(target_id, effect_id, duration_turns, stat_delta_key, 0, true)` where `modifier_delta == 0` (refresh does not change the modifier) and `is_refresh == true`; (4) a mock subscriber attached to `status_effect_applied` asserts that `sfx_play` (or equivalent audio trigger) was NOT invoked on the refresh (Audio System suppresses when `is_refresh == true`). Boundary test required: apply at `turns_remaining = 1` (one tick from expiry) — refresh must reset to full duration.
- AC-7: Applying a QA-fixture ATK debuff (fixed `modifier_value = −3`) and a QA-fixture ATK buff (fixed `modifier_value = +5`) to the same combatant results in `get_modifier(combatant_id, ATK) == 2`. Both entries appear in `get_active_effects()`.
- AC-8: Two QA-fixture ATK effects with `modifier_value = −5` and `modifier_value = +6` produce `get_modifier(combatant_id, ATK) == 1`. Assert using QA-owned `StatusEffectData` constants, not production DISSONANCE/RESONANCE values (production magnitudes may be retuned).

**Duration and Expiry** *(Logic — unit tests, BLOCKING gate)*

- AC-9: Apply a QA-fixture effect with `duration_turns = 2` to a combatant. After one `tick_turn(combatant_id)` call: `has_effect(combatant_id, effect_id) == true` and the entry's `turns_remaining == 1`. After a second `tick_turn(combatant_id)` call: `has_effect(combatant_id, effect_id) == false`; `status_effect_expired` fired with payload `(combatant_id, effect_id, "natural")`. Verify full signal payload.
- AC-10: Apply a QA-fixture effect with `duration_turns = 2` to a combatant. Call `tick_turn(combatant_id)` twice (simulating a double-action round). Verify `has_effect(combatant_id, effect_id) == false` after both calls. No TCS required — expressed as two direct `tick_turn` calls.
- AC-11: Call `notify_incapacitated(combatant_id)` on a combatant with two active effects. Verify: `get_active_effects(combatant_id)` returns an empty array; `status_effect_expired` fired with `cause = "incapacitated"` for each of the two effects (verify both signals via `assert_signal_emitted_with_parameters`). No expiry audio plays (verified in integration with Audio System).
- AC-12: Apply active effects to at least one combatant. Call `initialize_encounter(combatant_ids)`. Verify: `status_effect_expired` fired with `cause = "encounter_end"` for each previously active effect; `get_active_effects(combatant_id)` returns an empty array for all combatants after the call.

**Effective Stat** *(Logic — unit tests, BLOCKING gate)*

- AC-13: Apply a QA-fixture ATK debuff with `modifier_value = −6` to an enemy. Assert `get_modifier(enemy_id, ATK) == −6`. The calling system computes `effective_stat = max(1, min(99, 18 + 0 + (−6))) = 12` using this value; the formula arithmetic is verified in the CS&G test suite.
- AC-14: Apply two QA-fixture ATK effects with `modifier_value = −25` each to the same combatant (two different `effect_id`s). Assert `get_modifier(combatant_id, ATK) == −50`. Each individual fixture is within the valid StatusEffectData range (−30 to +30); the combined output tests multi-entry aggregation beyond the single-entry maximum. The effective_stat clamp (≥1) is verified in CS&G tests, not here.

**SPD Effects (Logic portion)** *(Logic — unit tests, BLOCKING gate)*

- AC-15a: Apply a QA-fixture SPD debuff to an enemy. Assert `get_modifier(enemy_id, SPD)` returns the debuff's `modifier_value`. No TCS required — SE side only.
- AC-16a: Apply a QA-fixture SPD debuff to an enemy, then call `tick_turn(enemy_id)`. Assert `get_modifier(enemy_id, SPD)` still returns the debuff's `modifier_value` (effect not yet expired). No TCS required.

**SPD Effects (Integration portion)** *(Integration — require TCS in test harness, Advisory gate)*

- AC-15b: In a TCS test harness, apply a SPD debuff whose `modifier_value` pushes enemy effective SPD below `SWIFT_THRESHOLD` before `tick_round_end` fires. TCS side: `TURNS_PER_ROUND == 1` for that enemy in the following round. The `get_modifier` assertion is covered in AC-15a.
- AC-16b: In a TCS test harness, call `tick_turn(enemy_id)` once (simulating the enemy's first action in a round — establish mid-round state), then apply a SPD debuff. Assert: `TURNS_PER_ROUND` for the current round is unchanged (round is locked). Assert: at the start of the next round recalculation, effective SPD is below SWIFT_THRESHOLD and `TURNS_PER_ROUND == 1`. Test setup: "mid-round" state is established by calling `tick_turn(enemy_id)` exactly once on an enemy with `TURNS_PER_ROUND == 2` for the current round, prior to the enemy's second action.
- AC-17a *(Integration)*: In a TCS test harness, establish a "pre-round" state by calling `tick_round_end()` (completing the prior round) and before any `tick_turn` calls in the new round. Apply QUICKEN to a combatant whose base SPD + QUICKEN modifier > SWIFT_THRESHOLD. Assert: TCS reads `get_modifier(combatant_id, SPD)` > 0 before TURNS_PER_ROUND calculation for the new round; `TURNS_PER_ROUND == 2` for that combatant in the new round.
- AC-17b *(Integration)*: In a TCS test harness, apply QUICKEN after one `tick_turn(combatant_id)` call within a round (mid-round state, as defined in AC-16b). Assert: `TURNS_PER_ROUND` for the current round is unchanged. Assert: `TURNS_PER_ROUND == 2` only from the next round's recalculation (when QUICKEN is still active).

**FLUX Effects** *(Integration — require TCS in test harness, Advisory gate)*

- AC-18a *(Logic — unit test, BLOCKING)*: Apply a QA-fixture FLUX buff with `modifier_value = +6` to a combatant with base FLUX=10 (QA fixture, not production stat). Assert `get_modifier(combatant_id, FLUX) == +6`.
- AC-18b *(Integration)*: In a TCS test harness, with effective FLUX=16 (base 10 + modifier +6), assert timing window frame count = `floor(16 × WINDOW_SCALE_FACTOR)` where `WINDOW_SCALE_FACTOR` is defined in the Character Stats & Growth GDD. The PERFECT zone is measurably wider than baseline FLUX=10.
- AC-19a *(Logic — unit test, BLOCKING)*: Apply a QA-fixture FLUX debuff with `modifier_value = −4` to a combatant with base FLUX=10 (QA fixture). Assert `get_modifier(combatant_id, FLUX) == −4`.
- AC-19b *(Integration)*: In a TCS test harness, with effective FLUX=6 (base 10 + modifier −4), assert timing window frame count = `floor(6 × WINDOW_SCALE_FACTOR)` where `WINDOW_SCALE_FACTOR` is from CS&G GDD. Frame count is smaller than baseline FLUX=10.
- AC-19c *(Visual/Advisory — HUD story, lead sign-off required)*: The HUD timing window visual reflects the narrowed PERFECT zone when MUTED is active on a party member. Requires screenshot evidence and HUD lead sign-off. Specified in HUD GDD Rule 7a.

**Signal Payload Integrity** *(Logic — unit tests, BLOCKING gate)*

- AC-37: Apply a QA-fixture effect (first application, `is_refresh = false`). Assert `status_effect_applied` fired with exact positional payload `(combatant_id, effect_id, duration_turns, stat_delta_key, modifier_value, false)` where all 6 parameters match the fixture values. `stat_delta_key` must equal the StringName of the affected stat (e.g., `&"ATK"`); `modifier_delta` must equal the fixture's `modifier_value` (signed). Separate test function required for refresh: apply same effect again and assert `status_effect_applied` fired with `(combatant_id, effect_id, duration_turns, stat_delta_key, 0, true)` — `modifier_delta == 0` on refresh.

**HUD** *(UI/Advisory — manual walkthrough or interaction test)*

- AC-20: When `status_effect_applied` fires with `is_refresh = false`, the named effect's icon appears on the target combatant's display. Signal payload correctness is verified in AC-37 (BLOCKING). Icon appearance verified via HUD walkthrough doc.
- AC-21a: When `status_effect_expired` fires with `cause = "natural"`: icon fades out; verify `cause` parameter via signal assertion.
- AC-21b: When `status_effect_expired` fires with `cause = "incapacitated"`: icon snap-removed. Verify `cause` parameter.
- AC-21c: When `status_effect_expired` fires with `cause = "encounter_end"`: icon snap-removed. Verify `cause` parameter.
- AC-22: Apply a QA-fixture effect with `duration_turns = 2`. Call `tick_turn(combatant_id)` once. Assert `status_effect_tick` fired with payload `(combatant_id, effect_id, 1)` — `turns_remaining` is the post-decrement value (2 → 1). Assert `status_effect_expired` was NOT emitted on this tick. Call `tick_turn` a second time. Assert `status_effect_expired` fired with `(combatant_id, effect_id, "natural")`. Assert `status_effect_tick` was NOT emitted on this tick (expiry and tick signals are mutually exclusive on any single `tick_turn` call). HUD countdown update verified via signal assertions — no TCS context required.
- AC-23: Buff icons and debuff icons are distinguishable by shape in a greyscale screenshot. *(Visual/Advisory — lead sign-off required.)*

**Registry Integrity** *(Logic — unit tests, BLOCKING gate)*

- AC-24: `apply_effect` (internal) with an unregistered `effect_id` is silently skipped. Verify: no entry added to `get_active_effects(target_id)`; `push_error` invoked (assert in debug build); no crash.
- AC-25: All 8 MVP named effects (DISSONANCE, RESONANCE, FRACTURE, FORTIFY, SLUGGISH, QUICKEN, TREMOLO, MUTED) are registered and loadable at encounter start. For each: `StatusEffectRegistry.get_effect(&"EFFECT_ID")` returns a non-null `StatusEffectData`; `sfx_apply_id.is_empty() == false`; `sfx_expire_id.is_empty() == false`; `icon_id.is_empty() == false`. *(Config/Data smoke check, Advisory gate.)*

**PERFECT Counter Exemption** *(Logic — unit test, BLOCKING gate)*

- AC-26: Apply a QA-fixture effect with `duration_turns = 2` to a combatant (`turns_remaining = 2`). Do NOT call `tick_turn(combatant_id)`. Assert `get_active_effects(combatant_id)[0].turns_remaining == 2` (unchanged). This verifies SE's side of the counter exemption — that `tick_turn` not being called is sufficient to preserve duration.
- AC-26b *(Integration — require TCS in test harness, BLOCKING)*: In a TCS test harness, simulate a PERFECT block scenario: combatant A blocks combatant B's attack at PERFECT grade, triggering a counter-attack by A. Assert: `tick_turn(combatant_A_id)` is NOT called during the counter-attack resolution (TCS must not call SE's tick for the blocker during its counter). Assert: after the counter resolves, any active buff on combatant A (e.g., a fixture with `duration_turns = 2`) still has `turns_remaining == 2`. This test validates TCS's side of the counter-exemption contract. Track in the TCS cross-GDD work table if TCS does not yet expose this scenario in its test harness.

**extend_effect_duration (STATUS_ADD combo enhancement)** *(Logic — unit tests, BLOCKING gate)*

- AC-27a: Apply a QA-fixture effect with `duration_turns = 2` (cap = 4). Decrement to `turns_remaining = 1` via `tick_turn`. Call `extend_effect_duration(combatant_id, effect_id, 1)`. Assert `turns_remaining == 2`. Call `tick_turn` — effect does not expire (assert `has_effect == true`).
- AC-27b: Apply the same fixture. Call `extend_effect_duration` until `turns_remaining == 4` (the cap `duration_turns × 2 = 4`). Call `extend_effect_duration(..., 2)` again. Assert `turns_remaining == 4` (unchanged — cap is enforced). No new entry created.
- AC-28: Call `extend_effect_duration` for an `effect_id` not active on the combatant. Assert `get_active_effects(combatant_id).size() == 0` (unchanged); no crash.
- AC-29: Call `extend_effect_duration(combatant_id, effect_id, 0)` and `extend_effect_duration(combatant_id, effect_id, −1)`. Both are no-ops. Assert `turns_remaining` is unchanged after both calls. Both boundary values must be tested.

**Public API Contract** *(Logic — unit tests, BLOCKING gate)*

- AC-35: `get_active_effect_ids(combatant_id)` returns an `Array[StringName]` containing only `effect_id` strings — not structs. Apply two QA-fixture effects with known `effect_id`s. Assert: the return value contains exactly those two StringNames; assert each element `is StringName` (not an `ActiveStatusEffect`); assert the array does NOT contain any struct fields or extra data. Verify callers receive lightweight ID-only data, not full struct references.
- AC-36: `get_active_effects(combatant_id)` returns a copy whose mutation does not corrupt tracker state. Apply a QA-fixture effect. Call `get_active_effects(combatant_id)`. Mutate the returned array (modify the first element's `turns_remaining` field, or append a new element). Assert: the live tracker is unchanged — `get_modifier(combatant_id, stat)` still returns the original value; `get_active_effects(combatant_id)` still returns the original array with original `turns_remaining`. This verifies the deep-copy isolation guarantee. *(If the pre-implementation smoke test in the API note finds that `duplicate_deep()` does not create independent instances for RefCounted elements, this AC will catch the failure.)*

**API Stubs (MVP)** *(Logic — unit tests, BLOCKING gate)*

- AC-30: `tick_round_end(combatant_id)` is a no-op at MVP. Assert: `get_active_effects(combatant_id)` returns identical content before and after the call.
- AC-31: `check_turn_skip(combatant_id)` returns `false` for all combatants at MVP regardless of active effects.

**QUICKEN Duration-1 Content Validation** *(Config/Data — required validation, Advisory gate)*

- AC-32: At editor/debug load time, any `StatusEffectData` resource of type QUICKEN (or effect with stat_affected = SPD, direction = buff) with `duration_turns = 1` triggers a `push_error` message identifying the problematic resource by `id`. The registry load does not silently accept this configuration. *(Required validation — not advisory. See QUICKEN edge case in Detailed Rules.)*

**Post-Incapacitation Targeting** *(Logic — unit test, BLOCKING gate)*

- AC-33: Simulate an incapacitated combatant by calling `notify_incapacitated(combatant_id)` (clearing their tracker). Then fire an `ability_resolved` signal targeting that combatant with a valid status payload. Assert: a new `ActiveStatusEffect` entry IS added to that combatant's tracker (SE adds no guard — this is by design; TCS is responsible for preventing targeting of incapacitated combatants). No crash. Assert: `has_effect(combatant_id, effect_id) == true` after the signal. This test documents the intentional absence of a guard, not a bug.

**Audio System Refresh Suppression** *(Integration — require Audio System in harness, BLOCKING gate)*

- AC-34: Subscribe the Audio System to SE signals in an integration harness. Apply an effect (first application, `is_refresh = false`): assert `sfx_play` was called with the correct `sfx_apply_id`. Apply the same effect again (refresh, `is_refresh = true`): assert `sfx_play` was NOT called a second time. Audio refresh suppression is a behavioral rule in the transition table (not advisory); this test is a blocking gate for the SE+Audio integration. The mock subscriber assertion in AC-6 covers the unit-test layer; this AC covers the full Audio System integration layer. This test belongs in the Audio System test suite but is tracked here as the defining cross-system AC for this behavior.

## Open Questions

- ~~**OQ-1 — Damage formula interaction**~~: **RESOLVED** — TCS GDD (Revision Pass 4) is approved. The damage formula is `floor(max(1, ATK_eff − DEF_eff) × damage_multiplier × grade_multiplier)`. DISSONANCE, RESONANCE, FRACTURE, and FORTIFY magnitudes at default ranges are consistent with this formula; no retuning required at MVP.
- ~~**OQ-2 — TURNS_PER_ROUND mid-round recalculation**~~: **RESOLVED** — TCS GDD (Revision Pass 4) confirms TURNS_PER_ROUND is locked at round start. SLUGGISH and QUICKEN applied mid-round take effect at the next round. The SPD edge cases in this GDD are consistent with the TCS specification.
- **OQ-3 — Enemy status effect display**: Exact form of enemy status display (icons on sprite, separate panel, combined with HP condition state) is deferred to HUD System GDD and `/ux-design`.
- **OQ-4 — Post-MVP effect types**: HP damage-over-time, TEMPO modification, and named conditions (Stun, Exposed) are explicitly out of MVP scope. If Vertical Slice or Episode 1 encounter design requires them, a GDD revision is required before implementation. The `tick_round_end` and `check_turn_skip` MVP stubs exist to support post-MVP STUN without API changes.
- **OQ-5 — Scene-tree placement ADR**: SE's signal connection to AbilitySystem's `ability_resolved` signal depends on scene-tree placement (who connects, when, in which lifecycle hook). This is pending the Architecture ADR for scene-tree placement (OQ-4 in AS GDD, OQ-5 in TCS GDD). **This GDD is conditionally approved pending that ADR** — signal wiring implementation must not begin until the ADR is written and accepted.

### Cross-GDD Work Required Before Implementation

| System | Amendment Required | Status |
|--------|-------------------|--------|
| **TCS GDD** | (1) Add `notify_incapacitated(combatant_id)` to SE interface table. (2) Correct Round End Sequence Step 1 to: "Call `tick_round_end(combatant_id)` — no-op at MVP; stub for future round-scoped effects." (3) Add `CONNECT_DEFAULT` note for SE's `ability_resolved` subscription. (4) Expose PERFECT block counter scenario in TCS test harness for AC-26b — confirm `tick_turn` is not called for the blocking combatant during counter resolution. | Pending |
| **HUD GDD** | (1) Confirm signal schema reconciliation: SE now declares `status_effect_applied` (6 params: `combatant_id, effect_id, turns_remaining, stat_delta_key, modifier_delta, is_refresh`), `status_effect_expired`, `status_effect_tick`. **Note:** `old_value`/`new_value` were replaced with `modifier_delta: int` in RP3 — the HUD GDD's Required Upstream Amendments section must be re-verified against this revised schema. (2) Confirm Rule 7a MUTED timing-bar narrowing: HUD must NOT use `modifier_delta` to re-narrow the timing bar on refresh (`modifier_delta == 0` on refresh); HUD must recompute timing-bar width independently whenever `status_effect_applied` fires for a FLUX-stat effect. | Pending verification |
| **Audio System GDD** | Add SE integration spec per Required Audio System GDD Amendments section above. Must be done before SE implementation. | Pending |
| **AS GDD** | Add `extend_effect_duration()` call contract in STATUS_ADD payoff path. Clarify whether call occurs before or after `ability_resolved` fires (determines re-entrancy safety). | Pending |

# HUD System

> **Status**: Approved (2026-05-02, Consistency Pass 1)
> **Author**: Jesus Gallegos + agents
> **Last Updated**: 2026-05-02 (Consistency Pass 1 — MAX_CHARGE 4→6; MUTED Rule 7a rewritten for SE RP3 modifier_delta schema)
> **Implements Pillar**: Pillar 2 (Rhythm Is Respect)

## Overview

The HUD System is the combat information layer of *Lux Aeterna* — the visual surface through which the player reads every encounter. It consumes real-time signals from the Timing Combat System (turn order, grades, CC, encounter state), the Enemy System (condition portraits, HP after Scan, status effects), the Party Composition Manager (who is in the fight), and Character Stats & Growth (HP values, stat-derived thresholds). It owns no game logic — it does not calculate damage, resolve timing, or evaluate AI — but it is the sole presenter of combat state to the player.

At the player layer, the HUD is how rhythm becomes legible. The timing window bar makes the block window visible as a shrinking space; the grade flash confirms precision; the CC bar tracks the accumulating reward for clean play; the turn order strip reveals the encounter's structure before it unfolds. A well-designed HUD disappears — the player stops reading numbers and starts reading the encounter as a shape. A poorly designed HUD forces the player to think about the interface instead of the fight, breaking Pillar 2's promise that mastery arrives as fluency. The HUD's design goal is transparency: present exactly what the player needs to make rhythmic decisions, exactly when they need it, and nothing more.

The system also handles the combat-to-exploration transition: HUD panels slide in at encounter start and slide out at encounter end, following the timing defined by the TCS Visual/Audio section (0.15–0.20s per panel). Outside combat, the HUD is absent — Lux Aeterna has no persistent overworld HUD in the MVP scope.

## Player Fantasy

**Fantasy: Reading the Music Before It Plays**

The HUD is the score to a performance already in motion. You are not reacting to numbers — you are reading the shape of the encounter the way a musician reads a phrase ahead. The timing bar shrinks toward its close: you don't watch it deplete, you feel the window's width and arrive on time. The CC bar fills its third segment with warm amber: you don't add up units, you know the finisher is one perfect away. The turn order strip cycles the enemy's chip forward: you don't calculate threat, you see the pressure arriving before it lands.

The anchor moment arrives mid-fight. You glance at the turn strip, see the enemy queued next, check your CC at 4/6 segments, and *know* — before your turn begins — that a perfect block into a combo finisher will close this encounter. You don't deliberate. You read. The HUD gave you that fluency.

Mastery means the HUD disappears. Not visually — every element remains — but perceptually. The player stops reading bars and starts reading *openings*. The information becomes spatial intuition. This is Pillar 2 realized as interface: rhythm is respect, and the HUD respects the player by giving them exactly enough light to find the path. Nothing more.

*Implements Pillar 2 (Rhythm Is Respect): the HUD converts raw combat state into readable rhythm. When it works, the player stops seeing the interface and starts seeing the music.*

## Detailed Design

### Core Rules

#### Element Registry

The HUD owns exactly ten display elements in MVP combat. Every element listed below is the sole authoritative mapping from live combat state to visual output. No element may read game state directly from source systems — all data arrives via signals or an initial synchronization call at encounter start.

---

**Rule 1 — Turn Order Strip**

- **Location**: Top edge of screen, horizontal, spanning full width.
- **Data source**: TCS signal `turn_order_changed(ordered_combatant_ids: Array[StringName], active_id: StringName)`.
- **Update trigger**: Signal fires at ROUND_START (full reorder) and after any INCAPACITATED event (chip visual changes; strip order does not reorder mid-round).
- **Visual behavior**:
  - Each combatant has **one chip** regardless of TPR. If TPR = 2, a small `×2` badge appears at the chip's bottom-right corner. The HUD deduplicates the `ordered_combatant_ids` array — if a combatant ID appears twice (TPR = 2), it renders as one chip with the badge, positioned at its first occurrence in the array.
  - Active combatant chip: 32x32px, Amber Hearth pulse animation (player turn) or Cold Slate pulse (enemy turn).
  - Inactive combatant chips: 24x24px, no pulse.
  - INCAPACITATED chip: 24x24px, Spent Coal palette, reduced opacity (0.4). Chip persists as acknowledged absence — not removed. `×2` badge is removed on INCAPACITATED.
  - Chip identity: character portrait thumbnail cropped to chip dimensions; enemy chips use the enemy sprite thumbnail in UNWOUNDED state.
  - Order is left-to-right, matching the frozen turn queue for the current round (first occurrence of each combatant ID). The chip at index 0 is always the active combatant.
  - On ROUND_START: chips snap to new order in one frame (no slide animation).
  - On TURN_START within a round: the chip at position 0 expands from 24px to 32px; the previous active chip contracts from 32px to 24px. Both snaps are instantaneous.
  - **Maximum chip count**: 7 (3 party members + 3 enemies + 1 guest). At 32px active + 6×24px inactive + spacing ≈ 180px — well within 320px native width.

---

**Rule 2 — Action Menu**

- **Location**: Bottom-right corner of screen.
- **Data source**: Ability System (authoritative source for all ability data). HUD hydrates the active party roster's abilities from the Ability System at encounter start via `AbilitySystem.get_combatant_abilities(combatant_id: StringName) -> Array[AbilityData]`. When TCS enters `PLAYER_ACTION`, HUD shows the pre-loaded ability list for the active combatant — TCS provides the state-change signal only, not ability data. If `ability_list_changed(combatant_id, new_list)` fires mid-combat (e.g., guest joins with inherited abilities), HUD rebuilds the cached menu for that combatant.
- **Update trigger**: Slides in when TCS enters `PLAYER_ACTION`; slides out when TCS exits `PLAYER_ACTION`. Slide duration: 0.15s.
- **Visual behavior**:
  - Lists all abilities known by the active party member plus the basic attack option.
  - Each entry shows: ability name, CC cost badge (if CC cost > 0).
  - Invalid abilities (CC cost > current CC): visually suppressed — desaturated at 0.5 opacity, not interactive.
  - Highlighted entry: Amber Hearth tint on selection cursor. Gamepad: d-pad navigation. Keyboard/mouse: click to select.
  - **Custom input routing (not Godot built-in dual-focus)**: gamepad d-pad navigation and mouse selection operate independently. A custom input manager tracks gamepad selection index separately from mouse cursor position. Pressing d-pad does not move the mouse; clicking does not steal gamepad selection index. This is NOT Godot's built-in dual-focus system, which applies to `Control` focus rings and does not cover sprite-based chip selection.
  - No time pressure on menu — remains open until a valid selection is made or the encounter ends.

---

**Rule 3 — CC Bar**

- **Location**: Bottom area, adjacent to the action menu, always visible during combat.
- **Data source**: TCS signal `cc_changed(new_cc: int, delta: int, source_type: StringName)`. Initial state: 0 at encounter start. HUD uses `new_cc` for display; `delta` and `source_type` reserved for future animation differentiation.
- **Update trigger**: Signal fires immediately after any CC mutation.
- **Visual behavior**:
  - 6 segments arranged horizontally (MAX_CHARGE = 6). Each segment = 1 CC unit.
  - Filled segments: Amber Hearth color.
  - Empty segments: Spent Coal color with visible segment border.
  - On CC gain: segment(s) fill on the same frame. 2-frame brightness pulse (~25% white mix), then settle to base Amber Hearth on frame 3. For +2: both segments pulse simultaneously on the same 2-frame window.
  - On CC spend: spent segments return to Spent Coal on the same frame the ability activates — before ability animation.
  - At MAX_CHARGE (CC = 6): all segments shift from Amber Hearth to Victory Gold. Slow sine-wave brightness modulate at ~1.5s per cycle (modulate color updated every 2 frames as a GDScript optimization — not a 2-frame toggle). "MAX" label appears above the bar (14-16px, Deep Linen, all-caps). Disappears on same frame CC is spent.

---

**Rule 4 — Party HP Bars**

- **Location**: Bottom-left panel, one row per party slot. Slots 1-3 always visible. Slot 4 visible if and only if a guest is present.
- **Data source**: TCS signal `hp_changed(combatant_id: StringName, new_hp: int, max_hp: int)`.
- **Update trigger**: Signal fires after every HP mutation.
- **Visual behavior**:
  - HP bar width scales linearly with `new_hp / max_hp`. Width update is instantaneous (no drain animation).
  - Normal fill color: Deep Linen.
  - Danger threshold: `new_hp / max_hp <= 0.25` — fill color shifts to Danger Red on the same frame.
  - On INCAPACITATED (new_hp = 0): bar extinguishes to Spent Coal immediately. Portrait thumbnail shifts to Spent Coal tint at reduced opacity.
  - Character name label displayed beside bar at all times.
  - Current HP value displayed as integer readout next to or beneath the bar.

---

**Rule 5 — Enemy Status Panel**

- **Location**: Upper-right area of screen, below the turn strip, one panel per enemy. Max 3 panels (Episode 1 encounter size limit). Exact pixel positions (including spacing below turn strip) deferred to UX spec (`/ux-design hud`).
- **Data source**:
  - `display_name` from EnemyData (static, read at encounter start).
  - Condition portrait: `enemy_condition_changed(enemy_id, old_state, new_state)` — swaps portrait to `condition_portrait_ids[new_state]`.
  - Condition badge text: derived from `new_state` ("Unwounded" / "Pressured" / "Bloodied" / "Near Breaking").
  - Exact HP: `get_exact_hp(enemy_id)` — callable only after `scan_resolved(enemy_id)` fires. Live thereafter via `hp_changed`.
  - Approximate HP bar (always shown): scales from `hp_changed` data without exact values until Scan. Rendered with a **dashed 1px border** (instead of solid) to signal that this value is estimated, not known. After `scan_resolved` fires, the border becomes solid and bar color shifts to the threshold-correct color (Danger Red if ≤ 25%, Deep Linen otherwise).
- **Update trigger**: `enemy_condition_changed` for portrait/badge; `hp_changed` for HP bar; `scan_resolved` to unlock exact display.
- **Visual behavior**:
  - Portrait transitions on the same frame `enemy_condition_changed` fires.
  - INCAPACITATED: all panel elements shift to Spent Coal at opacity 0.4. Panel persists (acknowledged absence).

---

**Rule 6 — Enemy Status Effects Display**

- **Location**: Within or adjacent to Enemy Status Panel, one row of icons per enemy.
- **Data source**: Status Effects signals `status_effect_applied`, `status_effect_expired`, `status_effect_tick`.
- **Visual behavior**:
  - One icon per active effect on the target enemy (from `StatusEffectData.icon_id`).
  - Duration indicator: integer countdown showing `duration_remaining` in turns.
  - On expiry: icon disappears on the same frame `status_effect_expired` fires.
  - Maximum icons displayed simultaneously: 4. If exceeded, clip oldest (leftmost).

---

**Rule 7 — Timing Window Bar (Attack Mode)**

- **Location**: Center of screen, horizontal bar. Width defined by `BAR_PIXEL_WIDTH` tuning knob (default 200px). Exact position and vertical placement deferred to UX spec.
- **Data source**: TCS signal `timing_window_opened(window_type: StringName, window_frames: int, actor_id: StringName)` and `grade_resolved(grade: StringName)`.
- **Update trigger**: Appears on `timing_window_opened` with type "ATTACK". Collapses on `grade_resolved`.
- **Visual behavior**:
  - Full bar width: background rail showing total available window.
  - Depleting cursor zone: bright segment shrinks from right to left at `bar_total_width / window_frames` px/frame.
  - PERFECT zone: fixed-width highlighted segment at leading edge. Color: Amber Hearth. Width = PERFECT_ZONE_SIZE frames (from ITD formula).
  - HIT zone: remainder of cursor zone behind PERFECT segment. Color: muted Deep Linen.
  - On `grade_resolved(MISS)`: bar collapses in one frame. No flash.
  - On `grade_resolved(HIT)`: bar collapses in one frame.
  - On `grade_resolved(PERFECT)`: bar fills Victory Gold starting on frame 2 (not frame 1 — see VA-2.4), then collapses on frame 3. **Implementation:** On `grade_resolved("PERFECT")`, do NOT immediately fill or collapse. Record the resolve frame. Use `await get_tree().process_frame` twice in a coroutine: first await → fill bar Victory Gold; second await → remove bar. A coroutine is preferred over polling `_process()` for this one-shot sequence.

---

**Rule 7a — MUTED Narrowing (Blocking Requirement from Enemy System OQ-6)**

- **Trigger**: `status_effect_applied(target_id, effect_id="muted", duration_remaining, stat_delta_key, modifier_delta, is_refresh)` where target is any party member and `stat_delta_key = "FLUX"`. `modifier_delta` is the signed SE modifier applied to FLUX (always negative for MUTED). **All data arrives via signal — no CharacterData coupling required.**
- **Effect**: When at least one party member has MUTED active, the PERFECT zone width is visually reduced using H3. Floor of MUTED_FLOOR_RATIO ensures zone remains visible.
- **Deactivation**: When `status_effect_expired(target_id, "muted")` fires and no other party member has MUTED, bar returns to normal width.
- **Multiple MUTED**: Bar applies narrowing from the party member with the largest `abs(modifier_delta)` (worst-case narrowing visible).
- **Refresh behaviour**: On MUTED refresh (`is_refresh=true`), `modifier_delta == 0`. HUD re-reads the cached value from `muted_party_members` — do not update the stored `modifier_delta` when `modifier_delta == 0`.
- **Application notification**: On MUTED application (`is_refresh=false`), brief 2-frame Danger Red pulse on the PERFECT zone (if bar open) or bar frame border (if closed).
- **Persistent indicator**: A small MUTED badge (using the effect's `icon_id`, rendered at 8–12px) appears adjacent to the affected party member's name label on their HP row. The badge persists until `status_effect_expired(target_id, "muted")` fires and no other party member has MUTED active. If multiple party members are MUTED, each shows their own badge independently.
- **HUD internal tracking**: `muted_party_members: Dictionary[StringName, int]` maps party member ID → `modifier_delta` (raw signed value from signal). Updated on every MUTED `status_effect_applied` where `modifier_delta != 0`; entry removed on `status_effect_expired`. `ratio_m` is computed from stored `modifier_delta` when the timing bar is active — not stored pre-computed.

---

**Rule 8 — Timing Window Bar (Block Mode)**

- **Data source**: TCS signal `timing_window_opened(window_type="BLOCK", window_frames: int, actor_id: StringName)`.
- **Update trigger**: Appears on `timing_window_opened` type "BLOCK". Collapses on `grade_resolved`.
- **Visual behavior**:
  - Same bar layout as attack mode.
  - PARTY_ALL: single bar for all party members. Small icon row beneath bar shows all living party member portraits.
  - MUTED narrowing applies identically to attack mode (Rule 7a).
  - PERFECT zone color: slightly cooler tint of Amber Hearth (exact hex in UX spec).
  - On `grade_resolved(PERFECT)`: bar fills Victory Gold starting on frame 2 (same 1-frame fill, delayed to avoid overlap with grade flash — see VA-2.6), then collapses on frame 3.

---

**Rule 9 — Grade Flash**

- **Location**: Center of screen, overlaying timing bar position. Duration: exactly 12 frames (0.2s).
- **Data source**: TCS signal `grade_resolved(grade: StringName)`.
- **Visual behavior**:
  - MISS: text "MISS" in Cold Slate, 16-18px. No glow.
  - HIT: text "HIT" in Deep Linen, 16-18px. Thin warm outline.
  - PERFECT: text "PERFECT" in Victory Gold, 18-20px, 1px warm-gold drop shadow. Persists 2 extra frames.
  - Grade flash is purely cosmetic — does not gate any TCS state.

---

**Rule 10 — Encounter Result Screen**

- **Visibility**: Shown only during TCS state `ENCOUNTER_END`.
- **Data source**: TCS signal `encounter_ended(result: StringName)` — "VICTORY" or "DEFEAT".
- **VICTORY**: CanvasModulate reverses to exploration warm palette over 1.5s. CC bar holds state one beat, then resets. HUD panels slide out in reverse order. After the CanvasModulate shift completes (1.5s), "VICTORY" fades in — Deep Linen, 14-16px, parchment-style font, centered, 2s fade-in, then fades out. The warmth returning IS the primary signal; the text is a legibility anchor for players who have not yet learned the color grammar.
- **DEFEAT**: Final party member defeat animation holds 10-12 extra frames. Warm sources fade. Final state: near-monochrome, cool-tinted. Residual Ember (art bible 2.8): cluster of deep dark red-orange pixels at one fallen party member. After the cool palette settles, "DEFEAT" fades in — Cold Slate, 14-16px, same font and spec as VICTORY text, centered, 2s fade-in, then fades out. The absence is the primary signal; the text is the legibility anchor.
- **Transition**: Scene transition begins after slideout/cooldown completes. HUD signals scene management that transition may proceed.

**CanvasLayer Modulate Participation (Godot architecture requirement):**

`CanvasModulate` operates on the main 2D scene's WorldCanvasItem tree and **does not affect CanvasLayer nodes**. The battle scene's CanvasModulate warm/cool shift is invisible to the HUD unless the HUD applies its own modulate response. Required behavior:

**CanvasLayer modulate implementation note:** `CanvasLayer` extends `Node`, not `CanvasItem`, and has no `modulate` property. Each HUD CanvasLayer must have a `Node2D` container as its sole direct child (e.g., `HUDLayer10Root: Node2D`, `HUDLayer11Root: Node2D`). All HUD elements are children of this container. The `create_tween()` call and `modulate` property tween target the `Node2D` container, not the `CanvasLayer` node itself.

- **VICTORY**: On `encounter_ended("VICTORY")`, the `Node2D` containers on CanvasLayer 10 and 11 begin a `create_tween()` easing their `modulate` toward a warm-tinted overlay (slightly warm, slightly brightened — exact target color defined in UX spec). Duration: 1.5s, `TRANS_SINE`. Synchronized to begin on the same frame as the battle scene's CanvasModulate shift.
- **DEFEAT**: On `encounter_ended("DEFEAT")`, CanvasLayer 10 and 11 `Node2D` container `modulate` tweens toward a desaturated cool overlay (slight blue-cool desaturation — exact target color defined in UX spec). Duration: 1.5–2.0s, synchronized with the cool palette settling in the scene.
- **Result text**: Rendered on **CanvasLayer 12** (reserved for encounter result text — separate from grade flash on layer 11 so both can coexist during the transition). No modulate tint applied to layer 12 — text color carries the warmth or cold.
- **Reset**: On `encounter_started`, all three CanvasLayer root `Node2D` container `modulate` values reset to `Color.WHITE` immediately (before slide-in begins). Any in-flight modulate tween is killed first.

**CanvasLayer reserved assignments (HUD):**
- Layer 10: Main HUD (turn strip, HP bars, CC bar, enemy panels, timing bar, action menu)
- Layer 11: Grade flash overlay
- Layer 12: Encounter result text (VICTORY / DEFEAT)
- Layer ≥ 20: All non-HUD overlays (pause, dialogue, scene transitions)

---

#### Contextual Show/Hide Logic

**Rule 11 — Elements active per TCS state**

| TCS State | Turn Strip | Action Menu | CC Bar | Party HP | Enemy Panel | Timing Bar | Grade Flash |
|-----------|-----------|-------------|--------|----------|-------------|------------|-------------|
| IDLE (no encounter) | Hidden | Hidden | Hidden | Hidden | Hidden | Hidden | Hidden |
| ENCOUNTER_START | Sliding in | Sliding in | Sliding in | Sliding in | Sliding in | Hidden | Hidden |
| ROUND_START | Visible | Hidden | Visible | Visible | Visible | Hidden | Hidden |
| PLAYER_ACTION | Visible | Visible | Visible | Visible | Visible | Hidden | Hidden |
| TIMING_WINDOW | Visible | Sliding out | Visible | Visible | Visible | Visible (ATTACK) | Hidden |
| ACTION_RESOLVE | Visible | Hidden | Visible | Visible | Visible | Hidden | Visible |
| ENEMY_ACTION | Visible | Hidden | Visible | Visible | Visible | Hidden | Hidden |
| BLOCK_WINDOW | Visible | Hidden | Visible | Visible | Visible | Visible (BLOCK) | Hidden |
| BLOCK_RESOLVE | Visible | Hidden | Visible | Visible | Visible | Hidden | Visible |
| ENCOUNTER_END | Sliding out | Hidden | Sliding out | Sliding out | Sliding out | Hidden | Hidden |

**Slide-in sequence** (ENCOUNTER_START, staggered 4 frames apart):
1. Party HP panel from left (frame 0)
2. Turn strip from top (frame 4)
3. Enemy panel from right (frame 8)
4. CC bar and action menu area from bottom-right (frame 12)

**Slide-out sequence** (ENCOUNTER_END, reverse order):
1. Action menu area to bottom-right (frame 0)
2. CC bar to bottom (frame 4)
3. Enemy panel to right (frame 8)
4. Turn strip to top (frame 12)
5. Party HP panel to left (frame 16)

**Rule 12 — Action menu slides out when timing window opens**

When TCS transitions from `PLAYER_ACTION` to `TIMING_WINDOW`, the action menu slides out over 0.10s (faster than slide-in). Timing bar does not wait for menu slide-out — both animations run simultaneously.

---

### States and Transitions

The HUD state machine mirrors TCS state but adds visual-layer states for animations in progress.

| HUD State | Description | Exits To |
|-----------|-------------|----------|
| `HUD_IDLE` | No encounter. All elements hidden. | → `HUD_ENTERING` on `encounter_started` |
| `HUD_ENTERING` | Slide-in animation in progress. | → `HUD_COMBAT_IDLE` when all panels visible; → `HUD_EXITING` on `encounter_ended` (EC-7.1: kill in-flight Tweens, snap panels to final positions, begin slide-out) |
| `HUD_COMBAT_IDLE` | Waiting for TCS turn. All panels visible, no action menu or timing bar. | → `HUD_PLAYER_TURN` / `HUD_ENEMY_TURN` / `HUD_EXITING` |
| `HUD_PLAYER_TURN` | Action menu open. Awaiting player selection. | → `HUD_TIMING_ATTACK` on selection |
| `HUD_TIMING_ATTACK` | Attack timing bar active. Menu sliding out. | → `HUD_GRADE_FLASH` on `grade_resolved` |
| `HUD_ENEMY_TURN` | Enemy action in progress. No player input. | → `HUD_TIMING_BLOCK` / `HUD_COMBAT_IDLE` |
| `HUD_TIMING_BLOCK` | Block timing bar active. | → `HUD_GRADE_FLASH` on `grade_resolved` |
| `HUD_GRADE_FLASH` | Grade text visible (12-14 frames). Rendered as a parallel CanvasLayer overlay — does not block other state transitions. **Timer ownership:** The GradeFlash node on CanvasLayer 11 is self-managing — it starts its own internal tween/timer when `grade_resolved` fires and auto-hides on completion. The HUD state machine transitions to the next state immediately on `grade_resolved` receipt; it does NOT wait for the flash to expire. If a second `grade_resolved` fires before the previous flash expires, the GradeFlash node cancels the current timer and starts fresh. | → `HUD_COMBAT_IDLE` / `HUD_EXITING` (grade flash continues on its layer regardless of main state) |
| `HUD_EXITING` | Slide-out animation in progress. | → `HUD_RESULT` when panels cleared |
| `HUD_RESULT` | Victory or Defeat state only. Result text animation runs (2s fade-in + 1s hold + 2s fade-out = 5s total). After animation completes, HUD emits `hud_result_complete()` signal. Scene Management listens and begins the scene transition. When Scene Management emits `scene_transition_started()`, HUD transitions to `HUD_IDLE` and resets all CanvasLayer container `modulate` to `Color.WHITE`. Fallback: if `scene_transition_started` does not arrive within 10s of `hud_result_complete`, HUD self-transitions to `HUD_IDLE` and logs a warning. | → `HUD_IDLE` on `scene_transition_started` (or fallback timer) |

**Forbidden transitions** (log as errors):
- `HUD_IDLE` → anything except `HUD_ENTERING`
- `HUD_TIMING_ATTACK` → `HUD_PLAYER_TURN` (cannot re-open menu mid-window)
- `HUD_RESULT` → `HUD_COMBAT_IDLE` (cannot resume from result)
- Any state → `HUD_ENTERING` while already in combat (double encounter start)

**Process Mode (Godot requirement):**

The HUD node (and all children) must use `process_mode` to prevent spurious updates outside combat:

- **In `HUD_IDLE`**: `process_mode = PROCESS_MODE_DISABLED`. Prevents `_process()` from running (no H1 elapsed_seconds drift), prevents `_input()` from firing, and ensures no signal-driven animation callbacks execute during exploration.
- **On `encounter_started` (entering `HUD_ENTERING`)**: Set `process_mode = PROCESS_MODE_INHERIT` before beginning any animation work.
- **On `HUD_IDLE` entry (transitioning from `HUD_RESULT`)**: Set `process_mode = PROCESS_MODE_DISABLED` immediately.
- **Signal handler guard**: Every signal handler method must begin with `if current_state == HUD_IDLE: return` — a defensive guard against late-dispatched signals that arrive after the HUD has returned to idle and processing has been disabled. Without this guard, a `cc_changed` or `hp_changed` signal dispatched mid-frame at encounter end could trigger visual updates against a hidden HUD.

---

### Interactions with Other Systems

#### Timing Combat System (Primary Source — 6 signals consumed)

> **Required TCS GDD amendments (before implementation):** TCS must formally add the following signals to its signal table with exact parameter signatures: (1) `encounter_started(combatant_ids: Array[StringName])` — fires after roster built in ENCOUNTER_START, before ROUND_START; (2) `timing_window_opened(window_type: StringName, window_frames: int, actor_id: StringName)` — fires when TCS dispatches a window to ITD; (3) `hp_changed` must include `max_hp: int` as a third parameter. Without these, the HUD cannot initialize, cannot show timing bars, and cannot compute HP bar fill.

| Signal | Parameters | HUD Response |
|--------|-----------|--------------|
| `encounter_started` | `combatant_ids: Array[StringName]` | Transition to `HUD_ENTERING`. Hydrate initial state from PCM and Enemy System. |
| `turn_order_changed` | `ordered_ids: Array[StringName], active_id: StringName` | Rebuild turn strip. Set active chip to 32px. |
| `hp_changed` | `combatant_id: StringName, new_hp: int, max_hp: int` | Update HP bar. Check Danger Red threshold. Apply INCAPACITATED visual if 0. **Routing:** HUD maintains `_party_ids: Dictionary[StringName, bool]` built from `get_active_combatants()` at encounter start, updated when `guest_slot_changed` fires. If `combatant_id in _party_ids` → route to party HP bar panel; else → route to enemy status panel. |
| `cc_changed` | `new_cc: int, delta: int, source_type: StringName` | Update CC bar segments. Apply MAX visual if = MAX_CHARGE. `delta` and `source_type` available for future animation differentiation (e.g., suppress fill pulse on ability_delta). |
| `grade_resolved` | `grade: StringName` | Display grade flash (12 frames). Apply timing bar PERFECT glow if applicable. |
| `timing_window_opened` | `window_type: StringName, window_frames: int, actor_id: StringName` | Show timing bar (ATTACK or BLOCK mode). Begin depletion. |
| `encounter_ended` | `result: StringName` | Transition to `HUD_EXITING`. Show encounter result. |

HUD provides **nothing** to TCS. Pure subscriber — no callbacks, no return values.

#### Enemy System (1 signal + 2 API calls)

| Signal/Call | HUD Response |
|-------------|--------------|
| `enemy_condition_changed(enemy_id, old_state, new_state)` | Swap portrait. Update badge text. |
| `get_encounter_enemies()` (pull at encounter start) | Build enemy status panels. |
| `get_exact_hp(enemy_id)` (pull after `scan_resolved`) | Initialize live HP integer readout. |

#### Party Composition Manager (1 signal + 2 API calls)

| Signal/Call | HUD Response |
|-------------|--------------|
| `guest_slot_changed(guest_data)` | Add/remove slot 4 HP bar. |
| `get_active_combatants()` (pull at encounter start) | Build party HP bar list. |
| `is_guest_present()` (pull at encounter start) | Set slot 4 visibility. |

#### Status Effects System (3 signals)

| Signal | HUD Response |
|--------|--------------|
| `status_effect_applied(target_id, effect_id, duration_remaining, stat_delta_key, modifier_delta, is_refresh)` | Add/refresh icon + counter. If MUTED on party member (`stat_delta_key = "FLUX"` and `modifier_delta != 0`): update `muted_party_members[target_id] = modifier_delta`; recompute H3 narrowing. On refresh (`modifier_delta == 0`): update icon counter only, do not change stored modifier. |
| `status_effect_expired(target_id, effect_id)` | Remove icon. If MUTED expired: check Rule 7a restoration. |
| `status_effect_tick(target_id, effect_id, duration_remaining)` | Update duration counter on icon. |

*(SE GDD Approved 2026-05-02: `status_effect_applied` signal schema confirmed as 6-param with `modifier_delta: int` and `is_refresh: bool`. `status_effect_tick` formally declared. No further amendment required.)*

#### Ability System (1 signal)

| Signal | HUD Response |
|--------|--------------|
| `scan_resolved(enemy_id)` | Unlock exact HP display for that enemy. Call `get_exact_hp()`. |

---

**Cross-GDD signal gaps (provisional — to resolve during review):**
1. `encounter_started` — not explicitly in TCS signal list; HUD needs it for hydration
2. `timing_window_opened` — TCS calls ITD internally but needs to broadcast to HUD
3. `scan_resolved` — attributed to Ability System (confirm when AS GDD is reviewed)

## Formulas

The HUD is a pure presentation layer and owns no game-logic calculations. The formulas in this section govern only visual output: how pixel widths are computed from frame counts and stat ratios. All gameplay values (TIMING_WINDOW_FRAMES, BLOCK_WINDOW_FRAMES, PERFECT_ZONE_SIZE, HP_current, HP_max, FLUX) arrive as signals or initial hydration calls from upstream systems — the HUD does not compute them.

---

### Formula H1: Timing Bar Cursor Fill Width

The timing bar depletes in real time during a timing window. Its width at any render frame is computed from normalized window progress.

`cursor_fill_px = BAR_PIXEL_WIDTH * (1 - t)`

where `t = elapsed_seconds / window_duration_seconds`

**Variables:**

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| BAR_PIXEL_WIDTH | int | 160-240 px | Total pixel width of timing bar rail. UX spec defines; assume 200px. |
| elapsed_seconds | float | 0.0 - window_duration_seconds | Time elapsed since `timing_window_opened` fired, tracked by an internal timer reset at each window open. Incremented in `_process()` via `delta`. |
| window_duration_seconds | float | 0.033 - 0.500 | Window duration in seconds: `total_frames / 60.0`. |
| total_frames | int | 2 - 30 | Window duration in frames (TIMING_WINDOW_FRAMES or BLOCK_WINDOW_FRAMES). Used to compute `window_duration_seconds`. |
| t | float | 0.0 - 1.0 | Normalized progress: `elapsed_seconds / window_duration_seconds`. Clamped to [0.0, 1.0]. 0.0 = bar full, 1.0 = bar empty. |

**Output Range:** 0.0 to BAR_PIXEL_WIDTH. No floor/round — float assigned to Control size (Godot renders sub-pixel).

**Implementation constraint:** Cursor width MUST be computed from `t` in `_process()` at render rate, using elapsed real time — not updated discretely per ITD signal tick. At W=2 (window_duration_seconds ≈ 0.033s), only 0–1 ITD ticks arrive before the window closes; tick-driven animation would be visually frozen. The `window_frame_tick` signal from ITD is used for window lifecycle management (knowing when the window closes), not for driving bar animation. Implementation guard: if `total_frames < 2`, clamp to 2 and `push_error()`.

**Example — Ne attacking (FLUX=8, W=8), BAR_PIXEL_WIDTH=200:**
- Window opens: t=0/8=0.0 → 200px (full)
- Frame 4: t=4/8=0.5 → 100px (half)
- Frame 7: t=7/8=0.875 → 25px (nearly empty)

---

### Formula H2: PERFECT Zone Pixel Width

The PERFECT zone is the leading (rightmost) Amber Hearth segment of the cursor zone. Its width maps PERFECT_ZONE_SIZE (frames) to pixels proportionally.

`perfect_zone_px = floor(BAR_PIXEL_WIDTH * (PERFECT_ZONE_SIZE / total_frames))`

**Variables:**

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| BAR_PIXEL_WIDTH | int | 160-240 px | Same as H1. |
| PERFECT_ZONE_SIZE | int | 1 - 10 | From ITD: `max(1, floor(W * PERFECT_HIT_RATIO))`. |
| total_frames | int | 2 - 30 | Same source as H1. |

**Output Range:** 1 to floor(BAR_PIXEL_WIDTH / 2) px. The true maximum occurs at minimum window size (W=2), where PERFECT_ZONE_SIZE = max(1, floor(2 × any_ratio)) = 1, giving `floor(BAR × 1/2)`. At default BAR=200: maximum = 100px (see EC-1.2). At BAR=300 (tuning safe range max): maximum = 150px. The previously referenced 80px maximum assumed BAR≤240 and W≥3 — those constraints are not enforced. Minimum 1px guaranteed by PERFECT_ZONE_SIZE floor of 1.

**Design note:** At PERFECT_HIT_RATIO=0.25, `perfect_zone_px` is approximately 50px for the registered Episode 1 characters (Ne W=8, Setsuna W=12, Clawd W=16 — all multiples of 4). **This stability does NOT hold for all W values.** When W is not a multiple of 4, the `floor()` operations cause the zone to deviate: W=2 → 100px (50%), W=3 → 66px (33%), W=5 → 40px (20%), W=6 → 33px (16%), W=7 → 28px (14%). Designers tuning FLUX or WINDOW_SCALE_FACTOR must verify zone width at the resulting W values before finalizing. The PERFECT zone is position-predictable only when character FLUX values produce W at multiples of 4.

**Example — BAR_PIXEL_WIDTH=200, PERFECT_HIT_RATIO=0.25:**

| Character | FLUX | W | PERFECT_ZONE_SIZE | perfect_zone_px |
|-----------|------|---|-------------------|-----------------|
| Ne | 8 | 8 | 2 | floor(200 * 2/8) = **50px** |
| Setsuna | 12 | 12 | 3 | floor(200 * 3/12) = **50px** |
| Clawd | 16 | 16 | 4 | floor(200 * 4/16) = **50px** |

---

### Formula H3: MUTED PERFECT Zone Narrowing

When any party member has MUTED active, the PERFECT zone display narrows. The HUD applies worst-case narrowing across all MUTED members.

**Step 1** — Narrowing ratio per MUTED member `m`:

`ratio_m = max(MUTED_FLOOR_RATIO, 1.0 − abs(modifier_delta_m) / MUTED_SCALE_FACTOR)`

`modifier_delta_m` is the signed FLUX modifier from the `status_effect_applied` signal payload (always negative for MUTED; `abs()` makes the formula sign-independent). `MUTED_SCALE_FACTOR` calibrates the ratio to the SE modifier range: at default 30, `modifier_delta_m = −30` (maximum SE debuff) produces `1.0 − 30/30 = 0.0`, floored to `MUTED_FLOOR_RATIO` (maximum narrowing). A `modifier_delta_m = 0` (refresh event) produces `ratio_m = 1.0` — no narrowing, so refresh signals never accidentally narrow the bar.

**Step 2** — Worst-case ratio:

`muted_ratio = min(ratio_m) for all m where MUTED is active`

**Step 3** — Narrowed width:

`muted_zone_px = max(1, floor(perfect_zone_px × muted_ratio))`

The `max(1, ...)` floor guarantees a minimum 1px zone regardless of `MUTED_FLOOR_RATIO` tuning or low `perfect_zone_px` values. Without this floor, `floor(1px × 0.05)` = 0px — zone disappears entirely.

**Variables:**

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| modifier_delta_m | int | −30 to 0 | MUTED member's SE FLUX modifier. From `status_effect_applied` payload (`modifier_delta`). Stored in `muted_party_members[id]`. |
| MUTED_SCALE_FACTOR | float | 15–30 | Tuning knob (see Tuning Knobs). Default 30 (full-range calibration: max SE debuff = max narrowing). |
| MUTED_FLOOR_RATIO | float | 0.05–0.20 | Tuning knob (see Tuning Knobs). Default 0.1. |
| ratio_m | float | MUTED_FLOOR_RATIO–1.0 | Narrowing factor per MUTED member. Floored at MUTED_FLOOR_RATIO. |
| muted_ratio | float | MUTED_FLOOR_RATIO–1.0 | Minimum ratio across all MUTED party members. |
| perfect_zone_px | int | 1–150 | Normal width from H2. True maximum: floor(BAR_PIXEL_WIDTH/2) at W=2; 100px at default BAR=200, 150px at BAR=300. |
| muted_zone_px | int | 1–150 | Narrowed width. Minimum 1px guaranteed by max(1,...) floor in Step 3. |

**Output Range:** 1px (minimum, guaranteed by `max(1,...)` in Step 3) to `perfect_zone_px`. The 1px Amber Hearth zone border from VA-2.5 ensures findability at the minimum floor.

**Example — Ne MUTED (modifier_delta = −10), MUTED_SCALE_FACTOR = 30:**
- ratio_Ne = max(0.1, 1.0 − 10/30) = max(0.1, 0.667) = 0.667
- perfect_zone_px = 50px → muted_zone_px = floor(50 × 0.667) = **33px**

**Maximum narrowing — modifier_delta = −30, MUTED_SCALE_FACTOR = 30:**
- ratio = max(0.1, 1.0 − 30/30) = max(0.1, 0.0) = 0.1
- muted_zone_px = max(1, floor(50 × 0.1)) = **5px**

**Worst case — Ne and Setsuna both MUTED (modifier_delta = −10 each):**
- muted_ratio = min(0.667, 0.667) = 0.667
- muted_zone_px = floor(50 × 0.667) = **33px** (identical magnitude — same narrowing)

**TREMOLO+MUTED interaction:** TREMOLO raises FLUX via a separate SE modifier. When MUTED applies to a TREMOLO-active combatant, `modifier_delta` in the signal reflects only the MUTED layer (SE-owned). The formula is unaffected by TREMOLO's modifier — `modifier_delta_m` is the MUTED contribution alone. No upper-clamp against TREMOLO interaction needed (the prior `min(1.0, ...)` clamp is no longer required with this formula).

**Floor rationale:** `MUTED_FLOOR_RATIO` is the tuning knob (default 0.1). The formula references the knob variable, not a literal, so tuning propagates correctly.

---

### Formula H4: Party HP Bar Fill Width

Linear mapping from HP ratio to pixel width with a 1px floor for living characters.

`fill_px = max(1, floor(BAR_HP_WIDTH * (HP_current / HP_max))) if HP_current > 0 else 0`

**Variables:**

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| BAR_HP_WIDTH | int | TBD by UX spec | Total pixel width of HP bar rail. |
| HP_current | int | 0-HP_max | From `hp_changed` signal. |
| HP_max | int | 1-999 | From same signal. Clawd=120, Ne=80, Setsuna=100. |

**Output Range:** 0 (INCAPACITATED) to BAR_HP_WIDTH (full). At HP > 0, minimum 1px — bar never fully disappears while character lives.

**Danger threshold (reference):** Color change at `HP_current / HP_max <= 0.25` uses the same ratio. Evaluated on every `hp_changed` — not a separate formula, a branch on the same computed value.

**Example — Clawd (HP_max=120, BAR_HP_WIDTH=160):**

| HP_current | Ratio | fill_px | State |
|------------|-------|---------|-------|
| 120 | 1.000 | **160px** | Full |
| 90 | 0.750 | **120px** | Pressured threshold |
| 30 | 0.250 | **40px** | Danger Red triggers |
| 1 | 0.008 | **1px** | Near zero — floor holds |
| 0 | 0.000 | **0px** | INCAPACITATED |

## Edge Cases

### Category 1 — Timing Bar at Extreme Window Sizes

**EC-1.1 — H1 depletion at W=2**: If `timing_window_opened` fires with `window_frames = 2`: bar is visible for exactly 2 render frames (~33ms). Must be driven by `_process()` float interpolation — a tick-driven bar would appear frozen then collapse. Depletes from full to half to zero in two steps.

**EC-1.2 — H2 PERFECT zone at W=2**: If `total_frames = 2`: `PERFECT_ZONE_SIZE = max(1, floor(2*0.25)) = 1`. `perfect_zone_px = floor(200 * 1/2) = 100px`. PERFECT zone is half the full bar — correct behavior. Almost any input within the window qualifies as PERFECT. Do not treat 100px zone as a bug.

**EC-1.3 — H3 MUTED narrowing at W=2 with floor**: If W=2 and `muted_ratio = 0.1`: `muted_zone_px = floor(100 * 0.1) = 10px`. Zone remains findable at minimum window size.

---

### Category 2 — MUTED Narrowing Extremes

**EC-2.1 — All three party members MUTED simultaneously**: H3 selects worst-case ratio. All at FLUX floor (effective=1): Clawd ratio=0.1, Ne ratio=0.125, Setsuna ratio=0.1. `muted_ratio = 0.1`. `muted_zone_px = floor(50*0.1) = 5px`. Zone remains visible.

**EC-2.2 — MUTED applied while timing bar is already open**: HUD immediately recomputes H3 and resizes PERFECT zone on the same frame. Depletion cursor continues from current `t`. 2-frame red pulse fires. If window closes on same frame MUTED applies: MUTED recorded but pulse/resize skipped (bar already collapsed).

**EC-2.3 — MUTED applied between timing windows (bar closed)**: Narrowing stored in `muted_party_members` dictionary. Next `timing_window_opened` opens bar pre-narrowed — no full-width flash before narrowing.

**EC-2.4 — Last MUTED expires mid-window**: PERFECT zone snaps back to `perfect_zone_px` on the same frame `status_effect_expired` fires. No animation — instant width restoration.

---

### Category 3 — Simultaneous Signals on Same Frame

**EC-3.1 — Two `hp_changed` on same frame (AoE)**: Godot signal queue dispatches sequentially within frame. Both HP bars update within same rendered frame — visually simultaneous. H4 evaluated independently per signal. No batching needed.

**EC-3.2 — `grade_resolved(PERFECT)` and `encounter_ended(VICTORY)` on same frame**: Grade flash (14 frames) plays during slide-out animation. Both are separate CanvasLayer elements — coexist without conflict. `HUD_GRADE_FLASH` → `HUD_EXITING` fires on same frame.

**EC-3.3 — `hp_changed(HP=0)` and `encounter_ended` on same frame**: Either signal order produces correct final state because slide-out animates position, not color. Enemy panel color/opacity updates even while sliding. Flag: TCS must document signal emission order within a frame as a contract.

---

### Category 4 — Guest Slot Edge Cases

**EC-4.1 — Guest departs between encounters**: `guest_slot_changed(null)` fires in `HUD_IDLE` (all panels already hidden). Updates internal `slot_4_visible = false` — visual no-op but state correct for next encounter. PCM guarantees no mid-combat departure.

**EC-4.2 — Encounter starts with no guest**: HUD builds 3 HP bar rows only. Slot 4 row not instantiated. Both encounter-start hydration path and `guest_slot_changed` subscription path must independently be capable of building slot 4 row.

**EC-4.3 — Turn strip chip count varies with guest presence**: Chip count = number of unique combatant IDs after deduplication of the `turn_order_changed` array. A combatant with TPR=2 appears twice in the array but produces one chip with a ×2 badge — not two chips. Maximum chip count is 7 (3 party + 3 enemies + 1 guest). No hard-coded chip count in HUD.

---

### Category 5 — Turn Strip Maximum Chips

**EC-5.1 — Strip maximum with single-chip-per-combatant redesign**: Maximum 7 chips (3 party + 3 enemies + 1 guest), each with an optional ×2 badge. Width at maximum: 32px active + 6×24px inactive + spacing ≈ 180px — well within 320px native width. The ×2 badge is cosmetic and does not expand chip size. No overflow risk at any Episode 1 encounter configuration.

**EC-5.2 — Episode 1 actual maximum**: With registered enemies and SWIFT_THRESHOLD=1.5, double-turns are rare. All encounters use at most 3 enemies + 3 party + 1 guest = 7 chips maximum. Overflow cannot occur with Episode 1 content.

---

### Category 6 — HP Bar at Boundaries

**EC-6.1 — HP_current = 1**: H4 `max(1, floor(BAR_HP_WIDTH * 1/HP_max))`. For all registered party members with BAR_HP_WIDTH >= HP_max: floor produces >= 1px naturally. Floor only activates if BAR_HP_WIDTH < HP_max (currently impossible). Specified defensively for future characters.

**EC-6.2 — Scan resolves on same frame as enemy damage**: Either signal processing order produces correct final state. `scan_resolved` sets `scan_done = true` and seeds initial exact HP. Subsequent `hp_changed` on same frame overwrites with current value. No stale display possible because both update the same variable.

---

### Category 7 — INCAPACITATED During HUD_ENTERING

**EC-7.1 — encounter_ended during slide-in**: If `encounter_ended` fires while HUD is in `HUD_ENTERING`: state machine must handle undefined transition. Resolution: `HUD_ENTERING` listens for `encounter_ended` and skips directly to `HUD_EXITING`. Implementation: call `Tween.kill()` on all in-flight slide-in tweens, then immediately set each panel's `position` to its fully-slid-in target value (the same position it would have reached had the slide completed), then begin slide-out sequence. Log as abnormal path. Extremely unlikely in Episode 1 (no initial status ticks exist).

**EC-7.2 — hp_changed during HUD_ENTERING (non-terminal)**: HUD updates panel data model immediately on signal receipt, even before panel slide-in completes. Panel displays current HP when it becomes visible — not stale hydration value.

---

### Category 8 — Action Menu Edge Cases

**EC-8.1 — All abilities invalid except basic attack**: Basic attack always has CC cost 0 — always interactive. If basic attack were somehow removed (data error): menu locks open (no valid selection). Guard: if zero interactive entries, push_error() and auto-select basic attack as failsafe. Content constraint: basic attack must always be zero-cost.

**EC-8.2 — Inherited abilities in action menu**: Inherited abilities suppressed by same CC cost rule as native abilities. Menu is agnostic to ability origin. Distinction only visible when timing window opens (uses INHERITED_TIMING_WINDOW_FRAMES).

---

### Category 9 — CC Overflow

**EC-9.1 — CC at MAX_CHARGE when PERFECT resolves**: TCS discards +2 gain, emits `cc_changed(6)` — same value. HUD must track `previous_cc` internally. If `new_cc == previous_cc`: skip fill pulse animation. Victory Gold oscillation and "MAX" label persist without interruption.

**EC-9.2 — CC MAX state exits on same frame as ability activation**: `cc_changed(0)` fires, "MAX" label disappears, Victory Gold ceases, bar snaps to Spent Coal — all on same frame before ability animation begins. Rule 3 already specifies this. Ensure HUD signal handler runs before ability animation node's `_process()`.

---

### Category 10 — Grade Flash During State Transitions

**EC-10.1 — grade_resolved during HUD_EXITING**: Cannot occur in normal TCS flow (no windows after encounter_ended). If received due to signal ordering: silently discard. Log warning.

**EC-10.2 — grade_resolved during HUD_ENTERING**: Invalid TCS state sequence. Discard flash, log error. Do not display grade flash while panels are partially visible.

**EC-10.3 — Grade flash still playing when ROUND_START fires**: Flash is separate CanvasLayer overlay — coexists with turn strip rebuild. Flash expires on its own 12-frame timer. If flash and timing bar overlap in screen region: z-order grade flash above timing bar.

---

**Cross-GDD issues surfaced:**
1. ~~EC-7.1: `HUD_ENTERING` → `HUD_EXITING` transition~~ — **RESOLVED**: state machine table updated; EC-7.1 specifies `Tween.kill()` + snap behavior; AC-46/AC-46b test this path
2. EC-3.3: TCS must define signal emission order within a frame (flagged for TCS review — OQ-3)
3. EC-5.1: Turn strip pixel budget not an issue with single-chip-per-combatant redesign (max 7 chips ≈ 180px)

## Dependencies

### Upstream (HUD depends on)

| System | Dependency Type | Interface | Data Flow |
|--------|----------------|-----------|-----------|
| **Timing Combat System** | HARD | 7 signals: `encounter_started`, `turn_order_changed`, `timing_window_opened`, `grade_resolved`, `cc_changed`, `hp_changed`, `encounter_ended` — **3 require TCS GDD amendment** (see Interactions section note) | TCS → HUD (read-only) |
| **Enemy System** | HARD | 1 signal: `enemy_condition_changed`; 2 API calls: `get_enemy_status_effects()`, `get_enemy_hp()` (Scan-gated) | Enemy → HUD (read-only) |
| **Party Composition Manager** | HARD | 1 signal: `party_changed`; 2 API calls: `get_active_combatants()`, `is_guest_present()` | PCM → HUD (read-only) |
| **Status Effects** | HARD (for MUTED narrowing) / SOFT (icon display) | 3 signals: `status_effect_applied` (extended payload), `status_effect_expired`, `status_effect_tick` — **requires Status Effects GDD amendment** | Status → HUD (read-only) |
| **Input & Timing Detection** | HARD (timing bar lifecycle) / SOFT (menu navigation) | `window_frame_tick(current_frame, total_frames, mode)` signal used for window lifecycle management (knowing when the window closes); H1 cursor animation is driven by `_process()` elapsed time, not this signal. Godot InputEvent for menu d-pad/keyboard navigation. | ITD → HUD (read-only) |
| **Ability System** | HARD | 1 API call: `get_combatant_abilities(combatant_id)` — called at encounter start for each party member to pre-load ability data. 1 signal: `ability_list_changed(combatant_id, new_list)` — triggers a menu rebuild mid-combat (e.g., guest joins). **HARD**: if this API call fails, the action menu cannot be built — the player has no way to select an action and Pillar 2 is broken. No graceful degradation path exists. | Ability → HUD (read-only) |

### Downstream (depends on HUD)

| System | Dependency Type | Interface |
|--------|----------------|-----------|
| *None* | — | HUD is a pure presentation terminal. No system reads from it. |

### Dependency Classification

- **HARD**: HUD cannot display combat state without these systems emitting signals. Missing any HARD dependency means blank/frozen elements.
- **SOFT**: HUD degrades gracefully — status effect icons don't appear, ability menu doesn't show CC costs, but core combat display (turn strip, timing bar, HP bars, grades) still functions.

### Required Upstream GDD Amendments

These are not provisional assumptions — they are architectural gaps that block implementation:

1. **TCS GDD** — Add to signal table: `encounter_started(combatant_ids: Array[StringName])`, `timing_window_opened(window_type: StringName, window_frames: int, actor_id: StringName)`, and extend `hp_changed` to 3-param: `hp_changed(combatant_id: StringName, new_hp: int, max_hp: int)`.
2. **Status Effects GDD** — ✓ RESOLVED (Approved 2026-05-02, Revision Pass 3): `status_effect_applied` declared as 6-param signal `(combatant_id, effect_id, turns_remaining, stat_delta_key, modifier_delta: int, is_refresh: bool)`; `status_effect_tick` formally declared. HUD Rule 7a updated to use `modifier_delta` via Formula H3.
3. **Resolve OQ-3** — Confirm `scan_resolved(enemy_id)` is emitted by Ability System (current assumption).

### CanvasLayer Architecture Note

The HUD uses three `CanvasLayer` nodes. Assign reserved integer values to prevent z-ordering conflicts with other systems:
- `layer = 10` — Main HUD (turn strip, action menu, CC bar, HP bars, enemy panels, timing bar)
- `layer = 11` — Grade flash overlay (renders above all main HUD elements)
- `layer = 12` — Encounter result text (VICTORY / DEFEAT) — separate from grade flash layer so both can coexist during the result transition

Other systems (pause menu, dialogue, scene transitions) must use `layer ≥ 20` to avoid HUD collision. Document in a project-level CanvasLayer registry (see OQ-8).

## Tuning Knobs

| Knob | Default | Safe Range | Affects | Breaks If |
|------|---------|------------|---------|-----------|
| `BAR_PIXEL_WIDTH` | 200 | 120–300 | Timing bar total width (H1, H2, H3) | < 120: PERFECT zone unreadable at muted extremes; > 300: dominates screen |
| `BAR_HP_WIDTH` | 160 | 80–240 | Party HP bar rail width (H4) | < 80: multi-character bars too narrow to compare; > 240: excessive screen share |
| `CHIP_ACTIVE_SIZE` | 32 | 24–48 | Active combatant chip in turn strip | < 24: indistinguishable from inactive; > 48: strip overflows at 7 combatants |
| `CHIP_INACTIVE_SIZE` | 24 | 16–32 | Inactive combatant chips | < 16: unreadable portraits; > 32: no visual distinction from active |
| `INCAPACITATED_OPACITY` | 0.4 | 0.2–0.6 | Dead chip visibility | < 0.2: invisible; > 0.6: looks alive |
| `SLIDE_IN_DURATION` | 0.15 | 0.08–0.30 | Panel entry animation (seconds) | < 0.08: perceptually instant (jarring); > 0.30: delays combat start |
| `SLIDE_OUT_DURATION` | 0.10 | 0.05–0.20 | Panel exit / action menu dismiss | < 0.05: imperceptible; > 0.20: sluggish between turns |
| `GRADE_FLASH_FRAMES` | 12 | 8–20 | Grade overlay duration | < 8: unreadable; > 20: overlaps next timing window |
| `CC_SEGMENT_COUNT` | 6 | 3–8 | Segments in CC bar (Rule 3) | < 3: segments fill too fast, low granularity; > 8: each gain feels negligible |
| `DANGER_HP_THRESHOLD` | 0.25 | 0.15–0.40 | HP ratio triggering Danger Red (Rule 4) | < 0.15: warning fires too late; > 0.40: constant red makes it meaningless |
| `STATUS_ICON_CAP` | 4 | 3–6 | Max visible status effect icons per enemy (Rule 6) | < 3: common states hidden; > 6: cluttered, unreadable at glance |
| `MUTED_FLOOR_RATIO` | 0.1 | 0.05–0.20 | Minimum MUTED narrowing factor (H3) | < 0.05: zone < 3px, effectively invisible; > 0.20: MUTED loses difficulty bite |
| `MUTED_SCALE_FACTOR` | 30 | 15–30 | Denominator calibrating MUTED narrowing to SE modifier range (H3) | < 15: moderate modifiers cause extreme narrowing; > 30: MUTED feels visually weak |
| `STAGGER_DELAY` | 0.067 | 0.02–0.10 | Delay between sequential panel slides (Rule 11) — 4 frames at 60fps | < 0.02: no perceptible stagger; > 0.10: entry sequence feels slow |

**Interaction notes:**
- `BAR_PIXEL_WIDTH` and `MUTED_FLOOR_RATIO` interact: lowering BAR width while keeping floor at 0.1 may produce sub-5px zones. If BAR < 150, consider raising floor to 0.15.
- `GRADE_FLASH_FRAMES` and TCS's `TIMING_WINDOW_FRAMES` interact: if flash > window, the next timing bar opens while flash is still visible. Ensure GRADE_FLASH_FRAMES < min(TIMING_WINDOW_FRAMES) across all characters. Note: PERFECT grade flash always runs for `GRADE_FLASH_FRAMES + 2` frames (the +2 extension is hardcoded in Rule 9). Budget for `GRADE_FLASH_FRAMES + 2` when evaluating overlap with the next window, not `GRADE_FLASH_FRAMES` alone.
- `CC_SEGMENT_COUNT` is locked to `MAX_CHARGE` from Character Stats GDD. Changing one requires changing both.

## Visual/Audio Requirements

### VA-1. Art Bible Principles That Govern the HUD

Three art bible principles apply directly to every decision in this section.

**Principle: Light Earns Its Real Estate.** Warm colors on the HUD — Amber Hearth, Victory Gold — must correspond to a meaningful event or state, not ambient decoration. A CC bar that glows warm at all times teaches the player nothing. A CC bar that reaches Victory Gold oscillation only at MAX_CHARGE teaches them exactly one thing: the finisher is ready. Every warm pulse must answer: *why here, why now?*

**Principle: Silhouette Carries the Feeling.** At combat resolution speed, the player cannot read text first. Grade flash text is confirmed by color and size, not leading with it. The PERFECT zone is found by position and color, not by reading a label. Every HUD event must communicate its grade to a desaturated monochrome view before color is added.

**Principle: The World Is Older Than the Visit (applied to UI).** The HUD panels use the parchment-and-aged-metal UI language from the art bible. Even in rapid feedback states — grade flash, danger pulse — the surface beneath the event should read as an artifact, not a float. Feedback animations ride on top of the panel surface; they do not replace it.

**Wall Rule applied to HUD**: At any moment in combat, a player should be able to answer "where is the warmth, and what is it fighting against?" from the HUD alone. The CC bar holds the warmth. The turn strip shows the cold arriving. The danger-red HP bar shows the warmth failing. Every VFX decision below must preserve this readable grammar.

---

### VA-2. VFX and Visual Feedback by HUD Element

#### VA-2.1 Grade Flash (Rule 9)

| Grade | Text Color | Size | Glow / Outline | Duration |
|---|---|---|---|---|
| MISS | Cold Slate | 16px | None | 12 frames |
| HIT | Deep Linen | 16px | 1px Amber Hearth outline | 12 frames |
| PERFECT | Victory Gold | 20px | 1px drop shadow (darker gold), 1px warm outline | 14 frames (2 extra) |

- MISS carries no warm color — Cold Slate signals the warmth did not land.
- HIT earns a thin warm outline: something connected, not nothing.
- PERFECT is the one moment Victory Gold appears at the grade layer. It must feel like the warmth reasserted.
- All three grades must pass the monochrome legibility test: size and position alone must communicate relative quality before color is resolved.
- The flash renders on its own CanvasLayer above all other HUD elements. It does not interrupt or replace the timing bar's final frame.

#### VA-2.2 CC Bar (Rule 3)

**Idle fill (0–5 segments):** Filled segments: Amber Hearth. Empty segments: Spent Coal with visible 1px segment border. No animation while stable.

**On CC gain pulse:** Filled segment(s) brighten by one step (~25% white mix) for exactly 2 frames, then return to base Amber Hearth. No easing — snap bright, snap back. For +2 gain: both segments pulse simultaneously on the same 2-frame window.

**At MAX_CHARGE (CC = 6):** All six segments shift from Amber Hearth to Victory Gold. 2-frame brightness oscillation at ~1.5s cycle — a slow, warm breath, not an alarm. "MAX" label: 14px, Deep Linen, all-caps, appears above the bar on the same frame Victory Gold activates. Disappears on the same frame CC is spent.

**On CC spend:** Spent segments return to Spent Coal on the same frame the ability activates, before any ability animation plays. The warmth is gone the moment the decision is made — not drained over time. No drain animation. Absence is instantaneous.

#### VA-2.3 Party HP Bars (Rule 4)

**Normal state (HP > 25%):** Fill color Deep Linen. No animation while stable.

**Danger state transition (HP drops to ≤ 25%):** Fill color snaps to Danger Red on the same frame as `hp_changed`. No tween, no gradient — instant.

**Danger pulse:** Once in Danger state, the bar holds a slow, 2-frame brightness oscillation at ~2.0s cycle — slower than the CC MAX oscillation, lower urgency register. Communicates *ongoing threat*, not *immediate alarm*.

**INCAPACITATED (HP = 0):** Bar extinguishes to Spent Coal on the same frame. Portrait thumbnail shifts to Spent Coal tint at `INCAPACITATED_OPACITY = 0.4`.

**Colorblind safety:** Danger state gains a 1px Danger Red inner border (shape backup) and a small damage indicator icon at bar's left edge, visible only in Danger state. Ensures the state reads without relying on color distinction alone.

#### VA-2.4 Timing Window Bar — Attack Mode (Rule 7)

**Rail (background):** Spent Coal, full width.

**Cursor zone (HIT region):** Deep Linen. Width depletes right-to-left per Formula H1.

**PERFECT zone (leading edge of cursor):** Amber Hearth. Fixed pixel width per Formula H2. Occupies the rightmost portion of the cursor zone. The player moves toward the warmth as the bar depletes.

**On `grade_resolved(PERFECT)` — delayed Victory Gold fill:** On frame 1 of grade_resolved, the bar holds its current state (grade flash text "PERFECT" in Victory Gold is rendering on this frame — filling the bar Victory Gold simultaneously would produce unreadable Victory Gold text on a Victory Gold background). On frame 2, the entire bar fills Victory Gold for 1 frame — the only moment the whole bar is warm. Bar collapses on frame 3.

**On `grade_resolved(HIT)` or `grade_resolved(MISS)` — immediate collapse:** Bar collapses in one frame. No fill flash.

**Pixel-snap requirement:** PERFECT zone boundary must land on a pixel boundary. Use `floor()` per Formula H2. No sub-pixel PERFECT zone edge at 320×180 native.

#### VA-2.5 MUTED Narrowing Visual (Rule 7a)

**MUTED application — 2-frame red pulse:** When `status_effect_applied(MUTED)` fires, the PERFECT zone flashes Danger Red for 2 frames, then returns to Amber Hearth at its new narrowed width. If the bar is closed, the bar frame border flashes Danger Red for 2 frames.

**Narrowed PERFECT zone width:** Snaps to `muted_zone_px` (Formula H3) immediately after the 2-frame pulse — not a tween.

**Visual treatment:** Even at minimum floor (~5px), maintain 1px Amber Hearth zone border so the zone's edge remains findable.

**Restoration (MUTED expired):** PERFECT zone snaps back to `perfect_zone_px` on the same frame `status_effect_expired` fires. No easing. 2-frame green (Deep Linen brightened) flash on the PERFECT zone — symmetrical to the application pulse, confirming restoration. MUTED badge on the affected HP row is removed on the same frame.

#### VA-2.6 Timing Window Bar — Block Mode (Rule 8)

All behavior identical to Attack Mode (VA-2.4) with two differences:

**PERFECT zone color:** Cooler Amber Hearth tint — desaturate ~20% and shift hue 15° toward blue. Candidate hex: `#B49060` (final confirmation deferred to UX spec). Distinguishes block from attack at a glance without abandoning the warmth grammar.

**PARTY_ALL icon row:** Portrait icons below the bar use chip-style thumbnails at 16px, Spent Coal background. No special coloring.

#### VA-2.7 Turn Order Strip (Rule 1)

**Active chip pulse — Player turn:** Amber Hearth, 2-frame brightness oscillation at ~1.0s cycle.

**Active chip pulse — Enemy turn:** Cold Slate, same oscillation parameters. The cold is active; the warm is waiting.

**INCAPACITATED chip:** Spent Coal fill at `INCAPACITATED_OPACITY = 0.4`. No pulse. Slot persists as acknowledged absence.

**Chip size snaps:** 24px ↔ 32px transitions are instantaneous (one frame). No tween.

#### VA-2.8 Enemy Status Panel — Condition Portraits (Rule 5)

**Portrait transition:** Swaps on the same frame `enemy_condition_changed` fires. No cross-fade.

**INCAPACITATED state:** All panel elements shift to Spent Coal at 0.4 opacity.

**Approximate HP bar (pre-Scan):** Cold Slate fill with a **dashed 1px border** — the dashed border signals this value is estimated, not known. After `scan_resolved` fires: border becomes solid and bar color shifts to threshold-correct color (Danger Red if ≤ 25%, Deep Linen otherwise). Integer HP readout appears at the same moment the border solidifies.

#### VA-2.9 HUD Entry/Exit Slide Animations (Rule 11)

**Slide direction:** Each panel slides from the screen edge it anchors to. Begins 100% off-screen.

**Duration:** `SLIDE_IN_DURATION = 0.15s`. `SLIDE_OUT_DURATION = 0.10s`.

**Pixel-snap:** Panel positions computed at integer pixel values throughout slide. No sub-pixel interpolation.

**Implementation requirement:** Panel slide animations must NOT use `tween_property()` to animate `position` directly — `tween_property()` writes raw float values, bypassing per-frame `roundi()`. Use `tween_method()` with a pixel-snapping setter instead:

```gdscript
func _set_panel_px(pos: Vector2) -> void:
    panel.position = Vector2i(roundi(pos.x), roundi(pos.y))

tween.tween_method(_set_panel_px, start_pos, end_pos, duration)
```

This ensures integer pixel values are assigned on every interpolated frame.

**Easing:** None. Linear slide only. Easing implies organic motion; HUD panels are information architecture.

**Stagger timing:** 4 frames (~0.067s) between sequential panel slides per Rule 11 sequence.

#### VA-2.10 Encounter Result Text Overlays (Rule 10)

**Trigger timing:**
- VICTORY text: appears after the CanvasModulate warm palette shift completes (~1.5s after `encounter_ended`). The warmth returning is the primary signal; text is the legibility anchor.
- DEFEAT text: appears after the cool palette settles (~1.5–2.0s after final party member INCAPACITATED animation completes).

**Shared visual specification:**
- Font: parchment-style (same font family as UI panels — aged, not synthetic)
- Size: 14–16px at native 320×180
- Position: centered horizontally and vertically on screen
- Animation: 2s fade-in (opacity 0 → 1), holds 1s at full opacity, then 2s fade-out (opacity 1 → 0)
- Rendering: separate CanvasLayer above main HUD (layer ≥ 11) so it does not interfere with panel slide-out

**VICTORY text:**
- Content: "VICTORY"
- Color: Deep Linen — warm, settled, relief rather than triumph. The gold has done its work; this is the exhale.

**DEFEAT text:**
- Content: "DEFEAT"
- Color: Cold Slate — not black (forbidden), not red (that was the warning before this). Cold Slate is the quiet after warmth fails.

**Accessibility rationale:** Color grammar (CanvasModulate warm/cool) is the primary signal and must be visually complete before text appears. Players who read color first are not interrupted. Players who need text find it arriving once the scene has settled.

---

### VA-3. Color Usage Rules Specific to HUD Elements

| Color | HUD Meaning | Appears On | Must NOT Appear On |
|-------|-------------|-----------|-------------------|
| **Amber Hearth** | Player agency or safety | Active chip (player turn), CC filled segments, PERFECT zone (attack), action menu cursor | Enemy-turn chip, enemy status elements, INCAPACITATED states |
| **Victory Gold** | Warmth earned at this moment | CC at MAX_CHARGE, PERFECT grade flash, 1-frame timing bar fill on PERFECT | Decoratively, as persistent UI color, during active damage on same frame |
| **Cold Slate** | Threat not yet resolved | Enemy-turn chip pulse, pre-Scan HP bar, MISS grade flash | Player-turn elements, positive feedback states |
| **Danger Red** | Damage arriving or sustained | HP bar ≤25%, MUTED 2-frame pulse, enemy-inflicted status icons | Enemy conditions the player applies to enemies |
| **Spent Coal** | Something that was warm and is no longer | INCAPACITATED chips/portraits, empty CC segments, timing bar rail | Generic UI backgrounds in combat (use Deep Linen) |
| **Deep Linen** | Resting state | HP bars at safe HP, HIT grade text, panel parchment surfaces | Should never pulse or oscillate |

**True black (`#000000`) is forbidden on all HUD surfaces**, consistent with art bible. All darks trend toward Spent Coal.

---

### VA-4. Audio Cues by HUD Event

Audio direction only — specific SFX design delegated to audio lead.

**Ownership split (important):** Grade audio (MISS/HIT/PERFECT) is **owned by the Audio System**, triggered via the `window_closed` signal from ITD or `grade_resolved` from TCS — the HUD is not responsible for playing grade SFX. The HUD owns visual feedback only for grade events (Rule 9, VA-2.1). All HUD-owned audio events call `play_sfx(sfx_id)` on the Audio System; the SFX ID list, bus assignments, and SFX design are maintained in the Audio System GDD. Victory/Defeat music transitions (warm swell, residual ember) are Audio System responsibility — the HUD coordinates timing via the encounter result state but does not own music playback.

| HUD Event | Audio Cue Direction | Register | Owner |
|---|---|---|---|
| Grade: MISS | Short, dry, tonally neutral — no sustain | Percussive absence | **Audio System** (not HUD) |
| Grade: HIT | Short, warm-toned single hit — contact confirmation | Warm, brief | **Audio System** (not HUD) |
| Grade: PERFECT | Bright short hit + warm sustain chord (the affirmation) | Musical, brief + tail | **Audio System** (not HUD) |
| CC segment fills | Single soft warm chime per segment; +2 = two chimes rapid succession | Warm, light | HUD (`play_sfx`) |
| CC at MAX_CHARGE | Quiet resolved chord — not a fanfare, a held breath | Musical, sustained low | HUD (`play_sfx`) |
| CC spent (from MAX) | Short, decisive warmth-withdrawal — deployment sound | Warm, conclusive | HUD (`play_sfx`) |
| HP → Danger Red | Low, brief warning pulse — single, not looping | Tense, single event | HUD (`play_sfx`) |
| HP = 0 (INCAPACITATED) | Warm source extinguishing — something going out | Solemn, brief | HUD (`play_sfx`) |
| MUTED applied | Dampening — higher frequencies cut, felt narrowing | Dull, constrictive | HUD (`play_sfx`) |
| MUTED restored | Brief brightening — warmth returning to the zone | Light, relieved | HUD (`play_sfx`) |
| Timing bar opens (Attack) | Quiet, taut — tension without alarm | Neutral-tense | HUD (`play_sfx`) |
| Timing bar opens (Block) | Same register as Attack but slightly cooler, braced | Braced, defensive | HUD (`play_sfx`) |
| Enemy turn — active chip | Low, cold tone with Cold Slate pulse | Cold, quiet | HUD (`play_sfx`) |
| HUD panels slide in | Subtle material sound per panel (parchment/aged-metal aesthetic) | Diegetic-adjacent | HUD (`play_sfx`) |
| Encounter end — Victory | Gentle warmth swell — not fanfare | Musical, warm swell | **Audio System** (not HUD) |
| Encounter end — Defeat | Near-silence, residual ember audio — something still there | Solemn, sparse | **Audio System** (not HUD) |

**Audio direction note on MUTED SFX:** "Higher frequencies cut" describes artistic direction for the SFX designer — the audio asset should sound like dampening/narrowing (e.g., recorded with a baked-in low-pass effect). This is NOT a runtime DSP bus filter operation. The HUD calls `play_sfx(sfx_id)` as with all other HUD-owned events; the SFX asset itself carries the dampened character.

**Audio constraint:** No cue should mask another within a single frame. Simultaneous events (e.g., PERFECT grade + CC fill) must be mixed to coexist — PERFECT leads, CC chime follows within 3 frames.

**HUD audio interface contract:** The HUD calls `AudioSystem.play_sfx(sfx_id: StringName)` for each HUD-owned event in the table above. The SFX ID constants, bus routing, and audio design for each ID are defined and maintained in the Audio System GDD — not in this document. The HUD holds only the mapping from HUD event → sfx_id string.

## UI Requirements

The HUD System *is* the primary combat UI surface. Its UI requirements are fully specified in Sections C (Detailed Design) and the Visual/Audio Requirements above. This section captures cross-cutting UI concerns not covered elsewhere.

### Screen Context

- **Screen**: Combat HUD overlay (no separate screen — renders atop the battle scene via CanvasLayer)
- **Resolution**: 320×180 native, integer-scaled to display resolution
- **Persistence**: Combat-only. Absent during exploration, menus, cutscenes, and dialogue

### Input Handling

- **Action Menu**: Keyboard (Up/Down + Confirm/Cancel) and gamepad (d-pad + A/B) navigation. Mouse click on ability entries also valid.
- **Dual-focus (Godot 4.6)**: Mouse focus and keyboard/gamepad focus are independent. Action menu must support both simultaneously — clicking an ability does not steal keyboard focus; pressing d-pad does not move mouse cursor.
- **No hover-only interactions**: Every mouse-interactive element must have a keyboard/gamepad equivalent per technical preferences.

### Accessibility Notes

- All color-coded states have shape or icon backups (see VA-2.3 colorblind safety)
- Grade flash communicates via size + position before color (VA-2.1 monochrome legibility)
- No rapidly flashing elements: slowest oscillation is 1.0s cycle (turn strip), fastest pulse is 2-frame snap (not a repeating flash)
- Text sizes: grade flash 16–20px, "MAX" label 14px — all at native 320×180, scaled with display

### UX Spec Dependency

Full layout, spacing, and pixel-precise positioning are deferred to the UX spec:
> Run `/ux-design hud` to produce `design/ux/hud.md` before implementation.

The GDD defines *what* each element displays and *when*. The UX spec defines *where* each element sits and *how large* it is at final layout.

## Acceptance Criteria

**Total: 64 ACs** — 49 BLOCKING, 4 ADVISORY, 10 PROVISIONAL (unconfirmed cross-GDD signals), 1 DEFERRED (UX spec dependency).

> **PROVISIONAL policy**: PROVISIONAL ACs depend on cross-GDD signal contracts not yet formally declared. They are BLOCKING in intent — they must pass before ship — but cannot be tested until the Required Upstream GDD Amendments (see Dependencies section) are ratified and implemented. PROVISIONAL ACs become standard BLOCKING ACs once their signals are confirmed.
>
> **Enforcement gate**: During sprint planning for any story that tests a PROVISIONAL AC, the sprint lead must first confirm that the corresponding upstream GDD amendment has been ratified and implemented. A story containing PROVISIONAL ACs must NOT be marked READY until that confirmation is recorded in the story file. The `/story-readiness` check will flag stories containing PROVISIONAL ACs as NOT READY if their upstream dependency is unresolved.

---

### Group A: Turn Order Strip (Rule 1)

**AC-1: Active chip expands on turn start**
GIVEN the HUD is in `HUD_COMBAT_IDLE` and the turn strip has been built, WHEN TCS emits `turn_order_changed` with a new `active_id`, THEN the chip at index 0 is rendered at 32px and all other chips are rendered at 24px within the same frame.

**AC-2: INCAPACITATED chip persists at reduced opacity**
GIVEN a combatant chip is present in the turn strip, WHEN TCS emits `hp_changed(combatant_id, new_hp=0, max_hp=N)`, THEN that chip remains at 24px, shifts to Spent Coal, and renders at `INCAPACITATED_OPACITY` (0.4) — not removed from the strip.

**AC-3: Strip rebuilds on ROUND_START without slide animation**
GIVEN the HUD is in `HUD_COMBAT_IDLE`, WHEN TCS emits `turn_order_changed` at round start with a new ordered_ids array, THEN chips snap to the new order within one frame — no tween or slide transition.

**AC-4: Strip chip count matches unique combatant count**
GIVEN the HUD receives `turn_order_changed` with an array containing N unique combatant IDs (some may appear twice for TPR=2), WHEN the strip renders, THEN exactly N chips are displayed (one per unique ID, with ×2 badge if ID appeared twice) — no hard-coded cap, maximum 7.

**AC-5: Active chip pulse color matches turn owner** [ADVISORY]
GIVEN the turn strip is visible, WHEN the active combatant is a player character vs. an enemy, THEN the chip at index 0 pulses Amber Hearth (player) or Cold Slate (enemy) — screenshot evidence required.

---

### Group B: Action Menu (Rule 2)

**AC-6: Action menu slides in on PLAYER_ACTION, slides out on exit**
GIVEN the HUD is in `HUD_PLAYER_TURN`, WHEN TCS transitions to `PLAYER_ACTION`, THEN the action menu completes slide-in within `SLIDE_IN_DURATION` (0.15s); on exit, completes slide-out within `SLIDE_OUT_DURATION` (0.10s).

**AC-7: Abilities with CC cost > current CC are rendered suppressed**
GIVEN the action menu is open and current CC is 2, WHEN the menu builds its ability list, THEN abilities with CC cost > 2 render at 0.5 opacity and are non-interactive; abilities with CC cost ≤ 2 are full opacity and interactive.

**AC-8: Basic attack is always interactive**
GIVEN the action menu is open at any CC value including 0, WHEN the ability list is built, THEN basic attack (CC cost = 0) is always full opacity and interactive — never suppressed.

**AC-9: Action menu supports keyboard, gamepad, and mouse independently** [ADVISORY]
GIVEN the action menu is open with multiple entries, WHEN the player uses keyboard Up/Down + Confirm, then gamepad d-pad + A, then mouse click, THEN each input method successfully highlights and selects an ability without requiring another method first.

**AC-10: Gamepad focus and mouse focus are independent (dual-focus)** [ADVISORY]
GIVEN the action menu is open, WHEN the player clicks a menu entry with mouse then presses d-pad, THEN d-pad moves gamepad focus without repositioning mouse cursor.

---

### Group C: CC Bar (Rule 3)

**AC-11: CC bar segment count equals cc_changed value**
GIVEN the CC bar is visible, WHEN TCS emits `cc_changed(new_cc=N)` for N in {0, 1, 2, 3, 4, 5, 6}, THEN exactly N segments are Amber Hearth and (6 − N) are Spent Coal within the same frame.

**AC-12: CC gain pulse fires for exactly 2 frames**
GIVEN CC is at 1, WHEN TCS emits `cc_changed(new_cc=3)`, THEN both newly-filled segments pulse at increased brightness for exactly 2 frames and return to base Amber Hearth on frame 3.

**AC-13: MAX_CHARGE activates Victory Gold and "MAX" label**
GIVEN CC is at 5, WHEN TCS emits `cc_changed(new_cc=6)`, THEN all six segments shift to Victory Gold and a "MAX" label (14px, Deep Linen, all-caps) appears above the bar on the same frame.

**AC-14: "MAX" label disappears on CC spend**
GIVEN CC is at 6 with "MAX" label displayed, WHEN TCS emits `cc_changed(new_cc=N)` where N < 6, THEN "MAX" disappears, Victory Gold ceases, and spent segments return to Spent Coal — all on the same frame before ability animation begins.

**AC-15: Redundant cc_changed at MAX_CHARGE skips fill pulse**
GIVEN CC is already at 6 with Victory Gold active, WHEN TCS emits `cc_changed(new_cc=6)` again, THEN no fill pulse fires — Victory Gold oscillation continues uninterrupted.

---

### Group D: Party HP Bars (Rule 4)

**AC-16: HP bar fill width computed by Formula H4**
GIVEN Clawd's HP bar with `BAR_HP_WIDTH=160` and `HP_max=120`, WHEN TCS emits `hp_changed(clawd_id, new_hp=90, max_hp=120)`, THEN fill width is `floor(160 * 90/120) = 120px`.

**AC-17: HP bar 1px floor holds at HP_current=1**
GIVEN `BAR_HP_WIDTH=160` and `HP_max=120`, WHEN TCS emits `hp_changed(member_id, new_hp=1, max_hp=120)`, THEN fill width is `max(1, floor(160 * 1/120)) = 1px`.

**AC-18: HP bar extinguishes to 0px on INCAPACITATED**
GIVEN a party member is alive, WHEN TCS emits `hp_changed(member_id, new_hp=0, max_hp=120)`, THEN fill width becomes 0px and portrait shifts to Spent Coal at `INCAPACITATED_OPACITY`.

**AC-19: Danger Red triggers at HP ratio ≤ 0.25 (inclusive)**
GIVEN HP bar is Deep Linen (ratio > 0.25), WHEN `hp_changed` results in `HP_current / HP_max = 0.25` (Clawd: new_hp=30), THEN fill color snaps to Danger Red on the same frame.

**AC-20: Slot 4 HP bar visible only when guest is present**
GIVEN encounter starts with `is_guest_present()` returning false, WHEN the HUD builds HP bars, THEN exactly 3 rows are instantiated — slot 4 does not exist.

**AC-21: Slot 4 HP bar added on guest_slot_changed** PROVISIONAL
GIVEN slot 4 is not present, WHEN PCM emits `guest_slot_changed(guest_data)` where guest_data is not null, THEN slot 4 HP bar row is instantiated.

**AC-22: Colorblind safety — Danger state has shape backup** [ADVISORY]
GIVEN HP bar is in Danger state, WHEN viewed in monochrome simulation, THEN the 1px inner border and damage indicator icon are visible without relying on color — screenshot evidence required.

---

### Group E: Enemy Status Panel (Rule 5)

**AC-23: Enemy portrait swaps on same frame as condition signal** PROVISIONAL
GIVEN an enemy panel is visible, WHEN Enemy System emits `enemy_condition_changed(enemy_id, "UNWOUNDED", "PRESSURED")`, THEN portrait texture changes and badge updates within the same frame — no cross-fade.

**AC-24: Exact HP display unlocked only after scan_resolved** PROVISIONAL
GIVEN an enemy has approximate HP bar visible (no integer readout), WHEN `scan_resolved(enemy_id)` fires, THEN integer HP readout appears — must not appear before scan.

**AC-25: INCAPACITATED enemy panel persists at 0.4 opacity**
GIVEN an enemy panel is visible, WHEN TCS emits `hp_changed(enemy_id, new_hp=0)`, THEN all panel elements shift to Spent Coal at 0.4 opacity — panel not removed.

**AC-26: Max 3 enemy panels in Episode 1**
GIVEN `get_encounter_enemies()` returns 3 enemies, WHEN HUD builds panels, THEN exactly 3 panels are instantiated.

---

### Group F: Enemy Status Effects (Rule 6)

**AC-27: Status icon appears on same frame as applied signal** PROVISIONAL
GIVEN an enemy panel has 0 icons, WHEN `status_effect_applied(enemy_id, effect_id, duration=3)` fires, THEN a new icon with countdown "3" appears within the same frame.

**AC-28: Status icon disappears on same frame as expired signal** PROVISIONAL
GIVEN an enemy panel shows 1 icon with duration 1, WHEN `status_effect_expired(enemy_id, effect_id)` fires, THEN that icon is removed within the same frame.

**AC-29: Status icon cap at 4 — oldest clipped**
GIVEN an enemy has 4 active icons, WHEN a 5th `status_effect_applied` fires, THEN the leftmost (oldest) icon is removed and the new icon appears — total remains 4.

---

### Group G: Timing Window Bar (Rules 7, 7a, 8 — Formulas H1/H2/H3)

**AC-30: H1 — Cursor fill computed at render rate** PROVISIONAL
GIVEN `window_frames=2` and `BAR_PIXEL_WIDTH=200`, WHEN `_process()` evaluates at t=0, t=0.5, t=1.0, THEN cursor widths are 200px, 100px, 0px — computed from float `t`, not discrete ticks.

**AC-31: H2 — PERFECT zone constant at ~25% across FLUX values**
GIVEN `BAR_PIXEL_WIDTH=200` and `PERFECT_HIT_RATIO=0.25`, WHEN windows open for Ne (W=8), Setsuna (W=12), Clawd (W=16), THEN `perfect_zone_px` = 50px in all three cases.

**AC-32: H3 — MUTED worst-case ratio across all MUTED members**
GIVEN Ne (ratio=0.5) and Setsuna (ratio=0.167) both MUTED, `perfect_zone_px=50`, WHEN timing bar renders, THEN `muted_ratio=0.167` and `muted_zone_px=floor(50*0.167)=8px`.

**AC-33: H3 — MUTED 0.1 floor prevents zero-width zone**
GIVEN all party members MUTED with `FLUX_effective=1`, WHEN `muted_ratio` is computed, THEN `max(0.1, ...)` ensures `muted_zone_px ≥ floor(perfect_zone_px * 0.1)`.

**AC-34: MUTED pre-applied when bar opens after between-window application**
GIVEN MUTED is active (applied while bar was closed), WHEN next `timing_window_opened` fires, THEN bar opens with PERFECT zone already at `muted_zone_px` — no full-width flash.

**AC-35: MUTED applied mid-window — zone resizes same frame** PROVISIONAL
GIVEN timing window open at t=0.4, WHEN `status_effect_applied(member_id, "muted")` fires, THEN PERFECT zone snaps to `muted_zone_px` and 2-frame red pulse fires — depletion cursor does not reset.

**AC-36: MUTED expiry mid-window — zone snaps back** PROVISIONAL
GIVEN timing window open with active MUTED narrowing, WHEN `status_effect_expired(member_id, "muted")` fires and no other member has MUTED, THEN PERFECT zone snaps to `perfect_zone_px` — no tween, no pulse.

**AC-37: PERFECT grade — Victory Gold fill on frame 2, collapse on frame 3**
GIVEN timing window is open, WHEN TCS emits `grade_resolved("PERFECT")`, THEN on frame 1 bar holds state (no fill), on frame 2 entire bar fills Victory Gold, on frame 3 bar is removed — Victory Gold fill must NOT appear on frame 1 (grade flash text is rendering in Victory Gold on frame 1; simultaneous fill creates unreadable Victory Gold-on-Victory-Gold).

**AC-38: HIT/MISS grade — bar collapses in one frame, no fill**
GIVEN timing window is open, WHEN TCS emits `grade_resolved("HIT")` or `grade_resolved("MISS")`, THEN bar collapses within one frame — no Victory Gold fill.

---

### Group H: Grade Flash (Rule 9)

**AC-39: Grade flash duration — MISS/HIT = 12 frames, PERFECT = 14 frames**
GIVEN HUD is in `HUD_GRADE_FLASH`, WHEN grade_resolved fires for each grade, THEN MISS/HIT text visible for 12 frames; PERFECT text visible for 14 frames.

**AC-40: Grade flash renders above all other HUD elements**
GIVEN a timing bar is partially depleted and grade flash triggers, WHEN HUD renders, THEN grade flash CanvasLayer has higher z-index than timing bar CanvasLayer.

**AC-41: Grade flash does not gate TCS state transitions**
GIVEN grade flash is playing (frames 1–12), WHEN TCS emits the next state signal, THEN TCS transitions proceed normally — flash timer does not block or delay upstream events.

---

### Group I: State Machine (Rules 11, 12)

**AC-42: Slide-in sequence completes in staggered order** PROVISIONAL
GIVEN HUD is in `HUD_IDLE`, WHEN `encounter_started` fires, THEN panels slide in staggered: Party HP (frame 0), Turn strip (frame 4), Enemy panel (frame 8), CC bar (frame 12).

**AC-43: Slide-out sequence completes in reverse order**
GIVEN HUD is in `HUD_COMBAT_IDLE`, WHEN TCS emits `encounter_ended`, THEN panels slide out reverse-staggered: action area (frame 0), CC bar (frame 4), Enemy panel (frame 8), Turn strip (frame 12), Party HP (frame 16).

**AC-44: Action menu slides out simultaneously with timing bar appearance**
GIVEN action menu is visible, WHEN TCS transitions to timing window, THEN menu slide-out (0.10s) begins on the same frame as timing bar appearance — neither waits.

**AC-45: Forbidden transition — HUD_TIMING_ATTACK cannot revert to HUD_PLAYER_TURN**
GIVEN HUD is in `HUD_TIMING_ATTACK`, WHEN any condition would trigger return to `HUD_PLAYER_TURN`, THEN state machine logs `push_error()` and does not transition.

**AC-46: HUD_ENTERING handles encounter_ended — skips to HUD_EXITING**
GIVEN HUD is in `HUD_ENTERING`, WHEN TCS emits `encounter_ended`, THEN HUD transitions to `HUD_EXITING` — partially-slid panels snap to final positions then slide out.

**AC-47: grade_resolved during HUD_EXITING is discarded**
GIVEN HUD is in `HUD_EXITING`, WHEN `grade_resolved` fires, THEN no flash displays and a warning is logged.

**AC-48: HUD_ENTERING → HUD_EXITING kills in-flight Tweens**
GIVEN HUD is in `HUD_ENTERING` with panels partially slid in, WHEN TCS emits `encounter_ended`, THEN all slide-in Tweens are killed, panels snap to their final slide-in positions, and slide-out begins — no panel left mid-animation at an intermediate position.

---

### Group I-b: Enemy HP Scan Transition

**AC-49: Enemy HP bar border becomes solid on scan** PROVISIONAL
GIVEN an enemy HP bar shows pre-Scan state (Cold Slate fill, dashed 1px border), WHEN `scan_resolved(enemy_id)` fires, THEN the border transitions from dashed to solid on the same frame and bar color shifts to Danger Red (if ≤ 25%) or Deep Linen (if > 25%).

**AC-50: Enemy HP bar integer readout absent before scan**
GIVEN an enemy panel is visible before `scan_resolved` has fired, WHEN the HUD renders, THEN no integer HP value is displayed for that enemy — approximate bar only.

---

### Group I-c: Encounter Result Text

**AC-51: VICTORY text appears after palette shift, not before**
GIVEN `encounter_ended("VICTORY")` fires, WHEN CanvasModulate warm palette shift completes (~1.5s), THEN "VICTORY" text fades in (Deep Linen, 14–16px, parchment font, centered) — text must NOT appear during or before the palette shift.

**AC-52: DEFEAT text appears after cool palette settles**
GIVEN final party member reaches INCAPACITATED, WHEN cool palette animation completes, THEN "DEFEAT" text fades in (Cold Slate, same spec as VICTORY) — text must NOT appear before palette is settled.

---

### Group I-d: Turn Strip ×2 Badge

**AC-53: TPR=2 combatant renders as single chip with ×2 badge**
GIVEN `turn_order_changed` fires with a combatant_id appearing twice in the array, WHEN the strip renders, THEN exactly one chip is displayed for that combatant with a ×2 badge at the chip's bottom-right corner — not two separate chips.

**AC-54: ×2 badge removed on INCAPACITATED**
GIVEN a chip has a ×2 badge, WHEN TCS emits `hp_changed(combatant_id, new_hp=0)`, THEN the ×2 badge is removed from the chip on the same frame it shifts to INCAPACITATED state.

---

### Group J: Performance

**AC-55: Timing bar cursor driven by _process(), not signal tick**
GIVEN `window_frames=2`, WHEN bar evaluates across 2 render frames at 60fps, THEN cursor updates every `_process()` call using float formula — a discrete per-tick implementation that updates only twice constitutes a FAIL.

**AC-56: Slide animations complete within budget**
GIVEN default `SLIDE_IN_DURATION=0.15s` and `SLIDE_OUT_DURATION=0.10s`, WHEN panels animate, THEN each completes within its duration at 60fps.

**AC-57: Slide panel positions are pixel-snapped** DEFERRED
GIVEN a panel is mid-slide, WHEN interpolation runs per frame, THEN position is set via `roundi()` to integer pixel value — no fractional position assigned.
*DEFERRED: anchor positions defined by UX spec.*

---

### Group K: Cross-System Signal Handling

**AC-58: HUD idle with no encounter signal**
GIVEN HUD initialized and no `encounter_started` has fired, WHEN `_ready()` completes, THEN all elements hidden, state is `HUD_IDLE`.

**AC-59: Two hp_changed signals on same frame both update correct bars**
GIVEN AoE hits two party members, WHEN TCS emits `hp_changed` for both within one frame, THEN both HP bars reflect new values in the same rendered frame.

**AC-60: PERFECT grade and encounter_ended on same frame — both execute**
GIVEN final hit produces PERFECT + VICTORY, WHEN both signals fire on the same frame, THEN grade flash begins (14 frames) and slide-out begins simultaneously.

---

### Group L: MUTED Persistent Indicator (Rule 7a)

**AC-61: MUTED badge appears on HP row when MUTED applied**
GIVEN a party member's HP row is visible, WHEN `status_effect_applied(member_id, "muted", ...)` fires, THEN a MUTED badge (8–12px icon) appears adjacent to that member's name label on the same frame — independently of whether the timing bar is open.

**AC-62: MUTED restoration — green flash and badge removal**
GIVEN a party member has an active MUTED badge on their HP row and the timing bar is open, WHEN `status_effect_expired(member_id, "muted")` fires and no other party member has MUTED, THEN: PERFECT zone snaps to `perfect_zone_px`; a 2-frame green flash fires on the PERFECT zone; MUTED badge is removed from the HP row — all on the same frame.

---

### Group M: hp_changed Routing (Rule 4 / Rule 5)

**AC-63: hp_changed routed correctly to party vs enemy panel**
GIVEN HUD has initialized `_party_ids` from `get_active_combatants()` at encounter start, WHEN TCS emits `hp_changed(combatant_id, new_hp, max_hp)`, THEN if `combatant_id in _party_ids` → party HP bar is updated (not enemy panel); if `combatant_id not in _party_ids` → enemy status panel HP bar is updated (not party panel). No cross-routing occurs.

---

### Group N: HUD_RESULT Exit (Rule 10 State Machine)

**AC-64: HUD_RESULT → HUD_IDLE triggered by scene_transition_started**
GIVEN HUD is in `HUD_RESULT` and result text animation has completed (hud_result_complete emitted), WHEN Scene Management emits `scene_transition_started`, THEN HUD transitions to `HUD_IDLE` and all CanvasLayer container `modulate` values reset to `Color.WHITE` on the same frame.

## Open Questions

**OQ-1: BAR_PIXEL_WIDTH and BAR_HP_WIDTH final values**
Owner: UX Designer | Target: `/ux-design hud`
Both values are tuning knobs with defaults (200px, 160px) but final values depend on the HUD layout at 320×180 native. The UX spec must confirm these before DEFERRED ACs can be tested.

**OQ-2: Block PERFECT zone hex confirmation**
Owner: UX Designer / Art Director | Target: UX spec
Candidate `#B49060` (cooler Amber Hearth). Must be validated at native resolution to ensure it reads as "distinctly cooler" without losing warmth grammar.

**OQ-3: Provisional signal confirmation (2 signals remain unresolved)**
Owner: Cross-GDD review | Target: `/review-all-gdds`
Signals 1 and 2 below are now formally documented as Required Upstream Amendments in the Dependencies section — they are not provisional assumptions but architectural gaps. Signals 3 and 4 remain unconfirmed:
1. ~~`encounter_started` — TCS~~ → **Documented as Required TCS Amendment**
2. ~~`timing_window_opened` — TCS~~ → **Documented as Required TCS Amendment**
3. `status_effect_applied/expired/tick` — Status Effects GDD formal declaration unconfirmed
4. `scan_resolved(enemy_id)` — Ability System or TCS (confirm when AS GDD is reviewed)

10 ACs are PROVISIONAL pending confirmation.

**OQ-4: MUTED HUD narrowing resolves Enemy System OQ-6**
Owner: Design review | Target: `/design-review`
This GDD's Rule 7a and Formula H3 formally specify the MUTED narrowing behavior that Enemy System OQ-6 flagged as BLOCKING. Confirm resolution during cross-GDD review.

**OQ-5: HUD_ENTERING → HUD_EXITING transition — RESOLVED**
The state machine table (States and Transitions section) now includes `HUD_ENTERING` → `HUD_EXITING` on `encounter_ended`. EC-7.1 specifies `Tween.kill()` + snap behavior. AC-46 and AC-48 test this path. No further action required.

**OQ-6: Turn strip pixel budget at max combatants**
Owner: UX Designer | Target: `/ux-design hud`
At 7 combatants (3 party + 3 enemies + 1 guest) the strip needs ~180px (32px active + 6×24px inactive + spacing). At 320px screen width this is 56% horizontal space. EC-5.1 defers final spacing and overflow rules to UX spec.

**OQ-7: APEX adaptive music transition — Audio System gap**
Owner: Audio Director | Target: Audio System GDD extension
Enemy System Section G flagged that APEX encounters require adaptive music transitions. The HUD does not own music transitions, but encounter result state (Rule 10) must coordinate with Audio System crossfade timing. **Blocked:** HUD implementation of encounter result timing is blocked on Audio System GDD defining a coordination mechanism (e.g., `encounter_result_started(result)` signal). Until then, HUD uses a fixed 1.5s timer for VICTORY text and 2.0s for DEFEAT text. If APEX encounters require different timing, the Audio System GDD must define the signal; HUD will subscribe. No HUD-side action required until Audio System GDD is extended.

**OQ-8: CanvasLayer integer registry — project-level coordination**
Owner: Technical Director | Target: Architecture or project CLAUDE.md
The HUD reserves `layer = 10` (main HUD), `layer = 11` (grade flash), and `layer = 12` (encounter result text). The Dependencies section notes that other systems must use `layer ≥ 20`. This project-level reservation is an informal convention in the GDD but must be formalized before other CanvasLayer-using systems are implemented (dialogue, pause menu, scene transitions). A project-level CanvasLayer registry should be established — either as an ADR or in `docs/architecture/`.

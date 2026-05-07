# HUD Design

> **Status**: Ready for Review
> **Author**: user + ux-designer
> **Last Updated**: 2026-05-07
> **Template**: HUD Design

---

## HUD Philosophy

The HUD is adaptive within combat and absent everywhere else. During exploration, dialogue, and cutscenes, the screen is unobstructed — the world speaks for itself. In combat, the HUD arrives only as needed: each element appears when the player must act on it and withdraws when the moment has passed. The timing bar opens with the window and closes when the grade resolves. The action menu slides in on your turn and away on theirs. The turn strip is always present once combat begins — it is the score, not the spotlight.

The design goal is transparency. A new player reads bars and numbers. An experienced player reads the encounter as a shape — where the pressure is coming from, when the finisher is available, whether this block window is wide or narrow. When the HUD is working, that transition happens without any conscious moment of learning. The information becomes spatial intuition. The interface disappears.

**Combat HUD posture: Adaptive.** Always-present elements are kept to the minimum required for continuous situational awareness (turn strip, HP bars, CC bar, enemy panels). Elements tied to player decision moments appear only during those moments. Nothing persists on screen to signal "you are playing a video game."

---

## Information Architecture

### Full Information Inventory

Pulled from HUD System GDD (Rules 1–10), Timing Combat System, Ability System, Enemy System, Status Effects GDD, and Party Composition Manager. All 13 items are combat-only — no information persists outside an active encounter.

| # | Information Item | Source GDD |
|---|-----------------|-----------|
| 1 | Turn order strip (who acts when, active chip, ×2 badge for TPR=2) | HUD / TCS |
| 2 | Action menu (abilities + CC costs, combo armed highlight) | HUD / Ability System |
| 3 | CC bar (6 pips, MAX state, "MAX" label) | HUD / TCS / Ability System |
| 4 | Combo state display (armed ability name + turns remaining) | Ability System |
| 5 | Party HP bars — slots 1–3 (name, HP value, danger threshold, MUTED badge) | HUD / TCS |
| 6 | Guest HP bar — slot 4 (present only when guest is in party) | HUD / PCM |
| 7 | Enemy status panels × up to 3 (name, condition portrait, condition badge, approx HP bar, exact HP post-Scan) | HUD / Enemy System |
| 8 | Enemy status effect icons (icon + turn count per enemy, max 4 displayed) | HUD Rule 6 / Status Effects |
| 9 | Party status effect badges (MUTED badge on HP row per affected member) | HUD Rule 7a |
| 10 | Timing window bar — Attack mode (PERFECT zone, HIT zone, depleting cursor) | HUD / TCS / ITD |
| 11 | Timing window bar — Block mode (PARTY_ALL variant; member portrait row beneath) | HUD / TCS / ITD |
| 12 | Grade flash (MISS / HIT / PERFECT text, 12 frames) | HUD / TCS |
| 13 | Encounter result screen (VICTORY / DEFEAT text + palette shift) | HUD / TCS |

### Categorization

| # | Information Item | Category | Rationale |
|---|-----------------|----------|-----------|
| 1 | Turn order strip | **Must Show** | Always-present score — knowing who acts next is continuous situational awareness |
| 2 | Party HP bars (slots 1–3) + guest slot 4 | **Must Show** | Health is always decision-relevant; guest slot conditionally present within Must Show |
| 3 | CC bar | **Must Show** | Needed to evaluate ability options at all times during combat |
| 4 | Enemy status panels | **Must Show** | Enemy condition and HP shapes every decision throughout the encounter |
| 5 | Action menu | **Contextual** | `PLAYER_ACTION` state only — slides in, then away |
| 6 | Timing window bar — Attack | **Contextual** | Open during attack timing window only |
| 7 | Timing window bar — Block | **Contextual** | Open during block timing window only |
| 8 | Grade flash | **Contextual** | 12 frames post-input; no persistence between turns |
| 9 | Combo state display | **Contextual** | Appears only when a combo is actively armed |
| 10 | Enemy status effect icons | **Contextual** | Present only when active effects exist on an enemy |
| 11 | Party status effect badges (MUTED) | **Contextual** | Present only when a party member is affected |
| 12 | Encounter result screen | **Contextual** | `ENCOUNTER_END` state only; palette shift is the primary signal, text is the legibility anchor |

**Nothing On Demand. Nothing Hidden.** The HUD is combat-only — no overworld context where an on-demand toggle makes sense in MVP scope.

**Must Show count: 4** — consistent with the adaptive minimum philosophy.

**Conflict flag — Status Effects icon cap**: The Status Effects GDD states max 8 icons per combatant; HUD System GDD Rule 6 states max 4 (clip oldest leftmost). This spec follows the HUD GDD (4) as the authoritative UI rule. Flagged as an open question for system owners to resolve before implementation.

---

## Layout Zones

At 320×180 native resolution, integer-scaled to display resolution.

```
┌──────────────────────────────────────────────────── 320px ──┐
│ ZONE 1 — TURN STRIP                              0–36px tall │
├──────────────────────────────────────┬──────────────────────┤ 36px
│ ZONE 2 — BATTLE FIELD                │ ZONE 3 — ENEMY COLUMN│
│ X: 0–216px                           │ X: 216–320px         │
│ Y: 36–136px (~100px tall)            │ Y: 36–136px          │
│ timing bar centered in this zone     │ 104px wide           │
│ grade flash overlays timing bar pos  │ 3 panels stacked     │
├──────────────────────┬───────────────┴──────────────────────┤ 136px
│ ZONE 4 — PARTY STATUS│ ZONE 5 — ACTION AREA                 │
│ X: 0–160px           │ X: 160–320px                         │
│ Y: 136–180px (44px)  │ Y: 136–180px (44px)                  │
│ HP rows 1–4          │ CC bar (always); action menu slides in│
└──────────────────────┴──────────────────────────────────────┘ 180px
```

| Zone | Position | Size | Contents |
|------|----------|------|---------|
| **1 — Turn Strip** | Top edge, full width | 320×36px | Up to 7 chips, left-aligned within zone. Active chip 32px, inactive 24px. ~2px padding top and bottom. |
| **2 — Battle Field** | Left-center, below turn strip | 216×100px | Combat sprites area. Timing window bar centered horizontally at X≈108px from zone left edge, Y≈90px from screen top. Grade flash overlays the same center position. |
| **3 — Enemy Column** | Upper-right, below turn strip | 104×100px | Vertical stack of up to 3 enemy status panels, each ~104×30px. 10px breathing room below the last panel. |
| **4 — Party Status** | Bottom-left | 160×44px | HP rows for slots 1–4 (slot 4 conditionally visible). Each row ~10px tall: character name left-aligned + HP bar + integer HP value. |
| **5 — Action Area** | Bottom-right | 160×44px | CC bar always in upper ~14px. During `PLAYER_ACTION`: action menu slides in from right edge, occupying full zone height. When inactive: lower ~30px empty (breathing room per adaptive philosophy). |

**CanvasLayer assignments** (per HUD System GDD):
- Layer 10: Zones 1–5 (all Must Show and Contextual elements)
- Layer 11: Grade flash overlay (Zone 2 position)
- Layer 12: Encounter result text (full-screen, centered)
- Layer ≥ 20: All non-HUD overlays (pause menu, dialogue, scene transitions)

**Safe zone**: Minimum 2px margin from all screen edges. All five zones remain fully visible at all supported integer scale factors (4:3 and 16:9).

---

## HUD Elements

### Must Show Elements

| Element | Zone | Category | Visual Form | Update | Animation |
|---------|------|----------|-------------|--------|-----------|
| **Turn Order Strip** | Zone 1 | Must Show | Row of portrait chips. Active: 32×32px, Amber Hearth pulse. Inactive: 24×24px, no pulse. INCAPACITATED: 24×24px, Spent Coal, 0.4 opacity, persists. ×2 badge bottom-right for TPR=2 (removed on INCAPACITATED). Max 7 chips. | `turn_order_changed` — snaps to new order in one frame, no tween. TURN_START: active chip expands 24→32px, previous contracts 32→24px, both instantaneous. | No slide or tween. All chip state changes are same-frame snaps. |
| **Party HP Bars** | Zone 4 | Must Show | 4 rows (slot 4 conditional on guest present). Each row ~10px tall: name label left-aligned + HP bar + integer HP value. Bar fills linearly with `new_hp / max_hp`. Danger Red at ≤25%. INCAPACITATED: bar → Spent Coal immediately, portrait thumbnail → Spent Coal tint at reduced opacity. | `hp_changed` — instantaneous, no drain animation. | Width update is same-frame. No bar drain tween. |
| **CC Bar** | Zone 5 top (~14px) | Must Show | 6 horizontal pip segments. Filled: Amber Hearth. Empty: Spent Coal with visible border. At MAX_CHARGE (6): all pips → Victory Gold, slow sine brightness modulate (~1.5s cycle, updated every 2 frames). "MAX" label above bar: 14–16px, Deep Linen, all-caps. | `cc_changed` — same-frame fill/drain. | CC gain: 2-frame brightness pulse (~25% white mix) on gained segment(s), settle frame 3. CC spend: segments → Spent Coal on same frame ability activates. MAX label appears/disappears same frame CC reaches/leaves 6. |
| **Enemy Status Panels** | Zone 3 | Must Show | Up to 3 panels stacked vertically, each ~104×30px. Per panel: condition portrait (left, ~20×20px) + display name label + condition badge text + HP bar (dashed border = estimated; solid border = exact post-Scan) + exact HP integer (post-Scan only). INCAPACITATED: full panel → 0.4 opacity Spent Coal, persists. | `enemy_condition_changed` (portrait + badge), `hp_changed` (HP bar), `scan_resolved` (border → solid, exact HP unlocked). | Portrait swap: same-frame. Opacity drop on INCAPACITATED: same-frame. |

### Contextual Elements

| Element | Zone | Trigger | Visual Form | Update | Animation |
|---------|------|---------|-------------|--------|-----------|
| **Action Menu** | Zone 5 | `PLAYER_ACTION` entry/exit | Vertical list of abilities for active party member. Each entry: ability name + CC cost badge (omitted if 0). Non-affordable (CC cost > current CC): 0.5 opacity, non-interactive. Combo-armed ability: distinct highlight (shape/border — not colour only). | Pre-loaded at encounter start via `AbilitySystem.get_combatant_abilities()`. Rebuilds on `ability_list_changed`. | Slides in from right edge on `PLAYER_ACTION` entry (0.15s). Slides out on exit (0.10s). |
| **Timing Bar — Attack** | Zone 2 center | `timing_window_opened` type "ATTACK" | Horizontal bar. Background rail = full available window. Depleting cursor zone shrinks right→left at `bar_width / window_frames` px/frame. PERFECT zone: Amber Hearth, fixed-width at leading edge. HIT zone: muted Deep Linen behind PERFECT. Bar width: `BAR_PIXEL_WIDTH` tuning knob (default 200px). Position: Y≈90px from screen top, centered horizontally in Zone 2 (X≈8px from zone left edge). | `timing_window_opened` — bar appears and begins depleting immediately. `grade_resolved` — bar collapses. | MISS/HIT: collapses in one frame. PERFECT: holds one frame, fills Victory Gold (frame 2 via coroutine await), collapses (frame 3). |
| **Timing Bar — Block** | Zone 2 center | `timing_window_opened` type "BLOCK" | Identical layout to Attack bar. PERFECT zone: cooler tint of Amber Hearth (~5–10° hue shift toward cyan — *exact hex TBD by art director in Art Bible*). PARTY_ALL: small living party member portrait row beneath the bar. MUTED narrowing applies (Rule 7a): PERFECT zone width reduced; 2-frame Danger Red pulse on MUTED application. | Same as Attack bar. | Same as Attack bar. PERFECT fill: Victory Gold frame 2, collapse frame 3 (1-frame delay per GDD Rule 8 to avoid grade flash overlap). |
| **Grade Flash** | Zone 2 center (Layer 11) | `grade_resolved` | Text overlay at timing bar position. MISS: "MISS", Cold Slate, 16–18px, no glow. HIT: "HIT", Deep Linen, 16–18px, thin warm outline. PERFECT: "PERFECT", Victory Gold, 18–20px, 1px warm-gold drop shadow. | `grade_resolved` signal — fires once. | Duration: 12 frames (0.2s). PERFECT persists 2 extra frames (14 frames total). Purely cosmetic — does not gate TCS state. |
| **Combo State Display** | Zone 4 — adjacent to active party member's HP row | Combo armed (Ability System combo state) | Inline indicator on the active party member's HP row: payoff ability name (abbreviated if needed) + "×[turns_remaining]" countdown. Non-interactive. Disappears when combo expires or resolves. | Event-driven: appears on combo arm, `turns_remaining` updates each turn on `turn_order_changed`, disappears on resolution or expiry. | Appears/disappears same-frame. No fade. |
| **Enemy Status Effect Icons** | Zone 3 — within each enemy panel, beneath HP bar row | Any active status effect on the enemy | One icon per active effect (`StatusEffectData.icon_id`). Duration countdown: integer `duration_remaining` in turns. Max 4 icons per enemy (clip oldest leftmost if exceeded). | `status_effect_applied`, `status_effect_expired`, `status_effect_tick`. Icon disappears same frame `status_effect_expired` fires. | No animation on appear/disappear. |
| **Party MUTED Badge** | Zone 4 — adjacent to affected party member's name label | `status_effect_applied` for MUTED on a party member | Small badge using effect's `icon_id`, 8–12px. One badge per affected party member (independent). Persists until `status_effect_expired` fires and no other party member has MUTED active. | `status_effect_applied` / `status_effect_expired` for effect_id="muted". On application (`is_refresh=false`): 2-frame Danger Red pulse on PERFECT zone (if timing bar open) or timing bar frame border (if closed). Do not update stored `modifier_delta` when `modifier_delta == 0` (refresh). | Badge appears/disappears same-frame. Danger Red pulse is 2-frame only — does not persist. |
| **Encounter Result Screen** | Full screen (Layer 12) | `encounter_ended` | VICTORY: "VICTORY" text, Deep Linen, 14–16px, parchment-style font, centered. Layers 10–11 `Node2D` container modulate tweens to warm-tinted overlay (`TRANS_SINE`, 1.5s — *exact target color TBD by art director in Art Bible*). DEFEAT: "DEFEAT" text, Cold Slate, 14–16px, same font/size. Layers 10–11 modulate tweens to desaturated cool overlay (1.5s–2.0s — *exact target color TBD by art director*). Layer 12 receives no modulate tint. | `encounter_ended("VICTORY")` or `encounter_ended("DEFEAT")`. | Text: 2s fade-in after palette settles. Palette shift begins same frame as battle scene CanvasModulate. Layers 10–11 modulate resets to `Color.WHITE` on `encounter_started` (kills any in-flight tween first). |

---

## Dynamic Behaviors

**Rule A — Encounter boundaries**
The HUD is fully absent outside an active encounter (TCS `IDLE`). On `encounter_started`: all Must Show elements slide in simultaneously (0.15–0.20s per panel, per GDD Visual/Audio requirements). On `encounter_ended`: all elements slide out in reverse order after the result screen clears.

**Rule B — Element visibility per TCS state**

| TCS State | Turn Strip | Action Menu | CC Bar | Party HP | Enemy Panels | Timing Bar | Grade Flash |
|-----------|-----------|-------------|--------|----------|-------------|------------|-------------|
| IDLE | Hidden | Hidden | Hidden | Hidden | Hidden | Hidden | Hidden |
| ENCOUNTER_START | Sliding in | Sliding in | Sliding in | Sliding in | Sliding in | Hidden | Hidden |
| ROUND_START | Visible | Hidden | Visible | Visible | Visible | Hidden | Hidden |
| PLAYER_ACTION | Visible | Visible | Visible | Visible | Visible | Hidden | Hidden |
| TIMING_WINDOW | Visible | Hidden | Visible | Visible | Visible | Visible | Hidden |
| GRADE_RESOLVED | Visible | Hidden | Visible | Visible | Visible | Collapsing | Visible |
| ENEMY_TURN | Visible | Hidden | Visible | Visible | Visible | Hidden (Visible if block window open) | Hidden |
| ENCOUNTER_END | Sliding out | Hidden | Sliding out | Sliding out | Sliding out | Hidden | Hidden |

**Rule C — Contextual element triggers within combat**
- **Action menu**: visible only during `PLAYER_ACTION`. Slide in 0.15s, slide out 0.10s.
- **Timing bar**: visible only while a timing window is open (Attack or Block). Appears on `timing_window_opened`, collapses on `grade_resolved`.
- **Grade flash**: fires once per `grade_resolved`, 12 frames (14 for PERFECT), then gone. No persistence between turns.
- **Combo state display**: visible only while a combo is armed on the active party member. Appears/disappears same-frame as state change.
- **Enemy status effect icons**: per-enemy visibility. Present when that enemy has ≥1 active effect. Disappears same frame the last effect on that enemy expires.
- **Party MUTED badge**: per-party-member visibility. Present while MUTED is active on that member. Independent per member.
- **Encounter result screen**: visible only during `ENCOUNTER_END` transition.

**Rule D — Visual Budget**
Maximum simultaneous visible elements occurs during a timing window on an enemy turn with 3 enemies, 4 party members, active MUTED effects, and active enemy status effects:
- Zone 1 (Turn Strip): ~180px of 320px width
- Zone 3 (Enemy Column): 3 panels × 30px = 90px tall with up to 4 icons per panel
- Zone 4 (Party Status): 4 HP rows × 10px = 40px tall; MUTED badges inline (no additional space)
- Zone 5 (Action Area): CC bar 14px tall; action menu absent (not PLAYER_ACTION)
- Zone 2 (Battle Field): Timing bar 200px wide, centered — clear of all other zones

**No element overlaps any other at peak density.** The timing bar sits entirely within Zone 2, which is spatially isolated from all other zones. The adaptive philosophy holds: peak density is still legible because elements occupy distinct screen regions.

---

## Platform & Input Variants

**PC (primary target — only target in MVP)**
All five zones render at 320×180 native, integer-scaled to the window size. No layout differences between keyboard/mouse and gamepad modes — the HUD layout is identical across both input methods.

**Action Menu — dual-input behavior (the only interactive HUD element)**

| Input | Navigate | Confirm | Cancel |
|-------|----------|---------|--------|
| Keyboard | Up/Down arrows | Enter | Escape |
| Mouse | Click to select; hover highlights | Click | — |
| Gamepad | D-pad Up/Down | A | B |

**Dual-focus rule** (per HUD GDD Rule 2): Mouse focus and keyboard/gamepad focus are independent. Clicking an entry does not steal keyboard focus index; pressing d-pad does not reposition the mouse cursor. Implemented via a custom input manager tracking both states separately — this is NOT Godot's built-in Control dual-focus system, which applies to Control focus rings and does not cover sprite-based or custom menu selection.

**Disabled ability entries**: non-interactive regardless of input method. Mouse hover shows no pointer change. Keyboard/gamepad navigation may either skip disabled entries or land on them without allowing confirmation — both are acceptable at Basic accessibility tier. Implementation team decides.

**No gamepad-specific layout variants.** No touch support. No console-specific safe zone adjustments required (PC only).

**Scaling**: At 1920×1080 (6× integer scale), all text and elements scale proportionally. Minimum text sizes (grade flash 16px native, CC "MAX" 14px native, HP row labels ~8–10px native) remain legible at all supported integer scale factors.

---

## Accessibility

**Tier**: Basic (per `design/accessibility-requirements.md`)

| Requirement | How the HUD Satisfies It | Status |
|---|---|---|
| No color-as-only-indicator | Turn strip: active chip uses pulse animation (shape/timing) in addition to color. CC bar: pip segments have visible borders distinguishing filled/empty independent of color. HP bars: danger threshold color shift is reinforced by combat context (low HP is legible without color). Grade flash: text label (MISS/HIT/PERFECT) carries the signal before color. Condition badges: text label alongside portrait. MUTED badge: icon shape + text, not color alone. | Specified |
| Keyboard-only navigation | Only interactive element is the Action Menu. Up/Down arrows + Enter/Escape reaches all entries. No HUD state requires mouse input. | Specified |
| Gamepad navigation | D-pad Up/Down + A/B covers all Action Menu interactions. No analog input required anywhere in the HUD. | Specified |
| No rapidly flashing elements | Slowest repeating animation: sine brightness modulate at ~1.5s cycle (CC MAX state). Fastest single pulse: 2-frame brightness snap (CC gain, MUTED application). Neither constitutes a repeating flash hazard (threshold: >3 flashes/second). | Specified |
| Readable text at 1080p | All text at 320×180 native scales to 6× at 1080p. Minimum sizes: HP row labels ~8–10px native (48–60px at 6×). Grade flash 16–20px native (96–120px at 6×). CC "MAX" label 14px native (84px at 6×). All legible at 1080p viewing distance. | Specified |
| Pause accessible from any combat state | Not a HUD concern — owned by pause menu spec (`design/ux/pause.md`). HUD has no responsibility for pause input handling. | N/A — covered elsewhere |
| Screen reader | Not required at Basic tier. Escalation to Standard tier adds AccessKit annotations to Action Menu entries and key state changes (grade resolved, HP danger threshold). | Deferred |

**Colorblind safety** (per HUD GDD VA-2.3): Color functions as a reinforcement layer, not the primary signal layer. Every state change communicates via shape, position, or text first — color confirms. Protanopia and deuteranopia players can read the timing bar (cursor zone position), grade flash (text), CC bar (pip count and "MAX" label), and turn strip (chip position and pulse timing) without relying on color distinction between hues.

---

## Open Questions

- **OQ-1 — Block timing bar PERFECT zone hex**: Color direction specified as "~5–10° hue shift toward cyan from Amber Hearth." Exact hex TBD. Owner: art director. Must be defined in the Art Bible before HUD implementation begins.

- **OQ-2 — Encounter result modulate tween target colors**: VICTORY warm overlay and DEFEAT cool desaturated overlay target colors specified by direction only. Exact hex values TBD. Owner: art director. Must be defined in the Art Bible before Encounter Result Screen story is implemented.

- **OQ-3 — Status Effects icon cap conflict**: Status Effects GDD specifies max 8 icons per combatant; HUD System GDD Rule 6 specifies max 4 (clip oldest leftmost). This spec follows HUD GDD (4) as the authoritative UI rule. System owners must align and update one of the two GDDs before the Enemy Status Effects story is written.

- **OQ-4 — Disabled ability entry navigation behavior**: When keyboard/gamepad focus lands on a non-affordable ability, Enter/A should either do nothing (focus lands, action suppressed) or be skipped entirely in navigation order. Both satisfy Basic accessibility tier. Implementation team to decide and document in the relevant story.

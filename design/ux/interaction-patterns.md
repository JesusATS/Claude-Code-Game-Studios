# Interaction Pattern Library

> **Status**: In Design
> **Author**: user + ux-designer
> **Last Updated**: 2026-05-07
> **Template**: Interaction Pattern Library

---

## Overview

This library catalogs all reusable interaction patterns in Lux Aeterna. When authoring a UX spec, reference patterns by name from this library rather than redefining them. When a spec introduces a new pattern, add it here.

**Primary language**: Spanish. **Secondary**: English. All sizing specifications use Spanish label lengths as the reference.

---

## Pattern Catalog

| Pattern | Category | Used In | Description |
|---------|----------|---------|-------------|
| Menu Button | Input / Feedback | Main Menu, Pause Menu | Interactive button with focused, hover, active, and disabled states. Used in all menu screens. |
| Title Treatment | Data Display | Main Menu | Game title typographic/logo element for top-level screens. |
| Atmospheric Background | Presentation | Main Menu | Full-screen pixel art scene with ambient animation behind menu chrome. |
| Portrait Chip Strip | Data Display | HUD (Turn Strip) | Horizontal row of character/enemy portrait thumbnails showing turn order. Active chip highlighted. |
| Resource Pip Bar | Data Display | HUD (HP bars, CC bar) | Segmented discrete-pip resource bar. Easier to read at small pixel-art sizes than a continuous fill. |
| HP Row | Data Display | HUD (Party Status) | Single party member's status row — name label + Resource Pip Bar + optional combo state indicator. |
| Enemy Panel | Data Display | HUD (Enemy Column) | Compact enemy status card — name, HP bar, status effect icons. One panel per visible enemy. |
| Timing Window Bar | Feedback | HUD (Battle Field) | Active-during-input progress bar showing Attack or Block timing zones (PERFECT / GOOD / MISS). |
| Combat Action Menu | Navigation / Input | HUD (Action Area) | In-combat ability selector with independent mouse-hover and keyboard/gamepad focus tracks. |
| Action Feedback Flash | Feedback | HUD (Grade Flash), Pause Menu (Save) | Transient label or icon overlay confirming an action result. Auto-dismisses after a fixed duration. |
| Confirmation Dialog | Modal | Pause Menu, Main Menu | Focused modal overlay with title, optional warning text, and Confirm / Cancel buttons. Traps focus. |

---

## Patterns

---

### Menu Button

**Category**: Input / Feedback
**Used In**: Main Menu (Continue, New Game, Load Game, Settings, Quit)

**Description**: The standard interactive button for all menu screens in Lux Aeterna. Supports four distinct visual states and is reachable via mouse, keyboard, and gamepad without relying on any single input method.

**Specification**:

| State | Visual Treatment | Input Trigger |
|-------|-----------------|---------------|
| Default (unfocused) | Label at normal opacity; no border or subtle border | None |
| Focused (keyboard/gamepad) | Visible focus ring or highlight border; label brightens | Tab / arrow keys / d-pad |
| Hover (mouse) | Highlight or label brightens; cursor changes to pointer | Mouse hover (secondary — never hover-only) |
| Active (pressed) | Brief highlight flash (~2–3 frames) | Mouse click / Enter / Gamepad A |
| Disabled | Label grayed out; supplementary text label explains why (e.g. "Sin guardado"); non-interactive | N/A — skipped in focus order |

- Minimum label size: 24px at 1080p
- Button width sized to longest Spanish label in the set ("Cargar partida" / "Nueva partida" ~14 chars)
- Focus indicator must use shape/border in addition to color — not color alone
- Disabled state must use text label in addition to gray color — not color alone
- No hover-only interactions — every hover action has a keyboard/gamepad equivalent

**When to Use**: Any interactive button in a menu screen where the player selects a destination or action.

**When NOT to Use**: In-game HUD elements (use HUD-specific patterns); inline text links; icon-only buttons without a text label.

---

### Title Treatment

**Category**: Data Display
**Used In**: Main Menu

**Description**: The styled game title element displayed at the top of top-level screens. Establishes identity and tone. Not interactive.

**Specification**:
- Displays "Lux Aeterna" (not translated — proper noun / title)
- Largest typographic element on the screen
- Optional subtitle or tagline in a smaller weight beneath — content TBD (narrative decision)
- Not part of the keyboard/gamepad focus order
- Must remain legible against the Atmospheric Background — use a text shadow, outline, or dedicated clear zone if needed
- Art direction: warm gold / amber palette consistent with "safety and connection" color philosophy

**When to Use**: Once per top-level screen (main menu, chapter title cards if applicable).

**When NOT to Use**: Sub-screens (Load Game, Settings) — those use a screen header pattern (not yet defined).

---

### Atmospheric Background

**Category**: Presentation
**Used In**: Main Menu

**Description**: A full-screen pixel art scene that establishes the world's tone before the player begins. Contains a visible warm light source and subtle ambient animation. Sits behind all menu chrome.

**Specification**:
- Full screen — 1920×1080 reference resolution; scales with viewport
- Must contain at least one diegetic warm light source (lantern, fire, window, magic glow) — art direction requirement
- Ambient animation required (parallax layers, particle effect, flickering light, or equivalent); must not distract from menu readability
- If a save file exists and a guest character has appeared, the most recent guest's accent color may appear subtly in the light (e.g. tinted glow). Fallback if no guest yet: default warm amber.
- A dark scrim or overlay behind the menu item zone ensures button label contrast meets WCAG 2.1 Level A — the background art must not compromise text legibility
- No flashing elements — Harding FPA compliant
- If reduced-motion is added at Standard tier, ambient animation disables; background displays as a static scene

**When to Use**: Top-level screens where world-building tone must be established (main menu, chapter select if applicable).

**When NOT to Use**: Sub-screens (Settings, Load Game) — those use a simpler background treatment.

---

### Portrait Chip Strip

**Category**: Data Display
**Used In**: HUD — Zone 1 (Turn Strip, 320×36px)

**Description**: A horizontal row of small portrait chips displaying the upcoming turn order for all combatants. The leftmost chip represents the current actor. Chips advance left as turns resolve. Provides at-a-glance read of who acts next without requiring the player to open a separate screen.

**Specification**:

| State | Visual Treatment |
|-------|-----------------|
| Active (current actor) | Chip highlighted — border ring, brightened portrait, or distinct background. Position 0 (leftmost). |
| Next (queued) | Normal opacity; no special highlight. |
| Inactive (later turns) | Slightly reduced opacity or visual weight to indicate distance in queue. |
| Enemy chip | Distinct border color or icon overlay to differentiate from party members. Not color-alone — use icon shape or border style in addition. |

- Native resolution: chips fit within 36px height; width per chip ~28–32px; strip spans full 320px width
- Turn order is derived from TCS INITIATIVE state; strip re-sorts when speed modifiers change
- When a combatant is defeated, their chip is removed; strip collapses without reordering remaining chips
- Colorblind requirement: ally vs. enemy distinction must use shape/border in addition to color

**When to Use**: Any combat scenario where turn order is a meaningful player decision input.

**When NOT to Use**: Outside active combat (strip is hidden). Not used in exploration, dialogue, or pause states.

---

### Resource Pip Bar

**Category**: Data Display
**Used In**: HUD — HP bars (Zone 4), CC bar (Zone 1)

**Description**: A segmented bar that represents a resource as a row of discrete filled/empty pips rather than a continuous fill. Optimised for pixel art at small display sizes — pip count is readable at a glance; partial fills don't blur or alias.

**Specification**:

| State | Visual Treatment |
|-------|-----------------|
| Full | All pips lit (filled color). |
| Partially filled | N pips lit, remaining pips dark/empty. |
| Empty | All pips dark. |
| Animating (damage/heal) | Pips deplete or fill over ~0.2s ease-out; depleting pips flash briefly before going dark. |
| Low (≤25% remaining) | Low-pip visual warning — subtle pulse or alternate color on remaining pips. Must not be color-only: add a supplementary icon or text indicator. |

- Each pip represents a fixed resource unit (value TBD per system: HP, CC, etc.)
- Pip count and size defined per element in `design/ux/hud.md`
- Pip depletion direction: left-to-right (rightmost pips empty first)
- Update frequency: reactive on `health_changed` / `cc_changed` signal; not polled every frame

**When to Use**: Any HUD resource that benefits from discrete readability at small sizes. HP and CC in this game.

**When NOT to Use**: Resources with very large ranges (>20 units) where pip count becomes unreadable — use a smooth bar instead.

---

### HP Row

**Category**: Data Display
**Used In**: HUD — Zone 4 (Party Status, bottom-left)

**Description**: A single party member's health display row. Combines a name label, a Resource Pip Bar, and an optional combo state indicator into one horizontal strip. Rows stack vertically for each party member. The active actor's row is highlighted.

**Specification**:

| Element | Content | Notes |
|---------|---------|-------|
| Name label | Party member short name (≤8 chars for layout) | Left-aligned; Spanish names as reference length |
| Resource Pip Bar | Current HP as pips | See Resource Pip Bar pattern |
| Combo state indicator | "COMBO ×N" badge or icon, right-aligned | Contextual — visible only when combo is armed for this member. Positioned adjacent to pip bar. |

| State | Visual Treatment |
|-------|-----------------|
| Default | Normal opacity row |
| Active (current actor's turn) | Row highlighted — brightened background or border |
| Low HP (≤25%) | Pip bar in low-warning state (see Resource Pip Bar); row itself unchanged |
| Defeated | All pips empty; name label dimmed or struck; row persists (does not disappear) |

- Zone 4 fits 4 HP rows stacked vertically within 160×44px (native resolution)
- Combo state indicator appears only while combo is armed; disappears when combo resolves or expires
- Focus order: HP rows are not interactive; not in keyboard/gamepad focus

**When to Use**: Party member status display in combat HUD.

**When NOT to Use**: Enemy status (use Enemy Panel). Non-combat screens (use Stat Screen for full party data).

---

### Enemy Panel

**Category**: Data Display
**Used In**: HUD — Zone 3 (Enemy Column, upper-right)

**Description**: A compact status card for a single enemy combatant. Shows name, HP (as a Resource Pip Bar or compact bar), and active status effect icons. One panel per visible enemy; panels stack vertically in Zone 3.

**Specification**:

| Element | Content | Notes |
|---------|---------|-------|
| Enemy name | Short label (≤10 chars for layout) | |
| HP display | Resource Pip Bar or compact fill bar | Scale to zone width (104px native) |
| Status effect icons | Up to 4 icon slots (per HUD GDD Rule 6 — clip oldest beyond 4) | Icon + number if stacked; must not be color-only identification |

| State | Visual Treatment |
|-------|-----------------|
| Default | Normal opacity |
| Targeted (player selecting target) | Highlighted border or background tint |
| Defeated | Panel remains visible but dimmed; HP bar empty |

- Maximum 4 status effect icons per panel; icon cap enforced by HUD — clip oldest when exceeded
- Status effect icons must use distinct shapes (not color alone) to differentiate effect types
- Panel height scales to content; zone fits up to 4 enemy panels stacked vertically (104×100px native)

**When to Use**: Enemy status display in combat HUD.

**When NOT to Use**: Party member status (use HP Row). Post-encounter screens.

---

### Timing Window Bar

**Category**: Feedback
**Used In**: HUD — Zone 2 (Battle Field), contextual — visible only during PLAYER_ATTACK and PLAYER_BLOCK TCS states

**Description**: A progress-bar-style element that visualises the active timing window for Attack or Block input. Contains distinct zone regions (PERFECT / GOOD / MISS for Attack; PERFECT / BLOCK / MISS for Block). A moving needle or fill indicates progress through the window. The player's job is to input at the right moment.

**Specification**:

**Attack bar zones** (left → right):

| Zone | Label | Notes |
|------|-------|-------|
| MISS (early) | No grade or MISS | Before the input window opens |
| GOOD | GOOD | Main window |
| PERFECT | PERFECT | Tight inner zone within GOOD |
| MISS (late) | No grade or MISS | After the window closes |

**Block bar zones** (left → right):

| Zone | Label | Notes |
|------|-------|-------|
| MISS | MISS | Before block window |
| BLOCK | BLOCK | Block window |
| PERFECT | PERFECT | Tight inner zone; reduces/eliminates damage |
| MISS (expired) | MISS | After window closes |

| State | Visual Treatment |
|-------|-----------------|
| Inactive | Not rendered (hidden; zone space used by Battle Field art) |
| Active — filling | Needle/fill advancing through the bar in real time |
| Active — window open | Zone highlighting indicates input is now valid |
| Result — grade shown | Bar freezes at input position; grade zone flashes briefly before bar dismisses |
| Expired (no input) | Bar fills to MISS zone; MISS grade fires; bar dismisses |

- PERFECT zone width is subject to `modifier_delta` narrowing when MUTED status is active (Rule 7a in `design/ux/hud.md`)
- Block PERFECT zone uses a distinct hue from Attack PERFECT zone — exact hex TBD by art director (see HUD OQ-1)
- Bar appears in Zone 2 (Battle Field); exact position within Zone 2 is an art direction decision
- Bar duration (window length) is defined by the TCS timing config — not hardcoded here

**When to Use**: Exclusively during TCS PLAYER_ATTACK and PLAYER_BLOCK states.

**When NOT to Use**: All other HUD states. Never shown during exploration, dialogue, menus, or enemy turns.

---

### Combat Action Menu

**Category**: Navigation / Input
**Used In**: HUD — Zone 5 (Action Area), contextual — visible during PLAYER_TURN TCS state

**Description**: The in-combat action selector displayed when it is the active party member's turn. Contains rows of ability options (Attack, equipped abilities, Item, etc.). Supports two independent focus tracks: keyboard/gamepad focus (navigated with arrow keys or d-pad) and mouse hover focus (follows cursor independently). The player commits a selection with Enter / Gamepad A / mouse click.

**Dual-focus rule**: Mouse hover and keyboard/gamepad selection are intentionally decoupled. Moving the mouse does not steal keyboard focus; navigating with d-pad does not move the cursor. This prevents accidental de-selection in a turn-based context. This is NOT Godot's built-in Control dual-focus system — it is a custom focus management implementation.

**Specification**:

| State | Visual Treatment |
|-------|-----------------|
| Default (row unfocused) | Normal opacity; subtle border or separator |
| Keyboard/Gamepad focused | Row highlighted — distinct border or background |
| Mouse hovered | Row brightened — secondary highlight style (distinct from keyboard focus) |
| Both focused on same row | Combined highlight treatment (additive or same as keyboard focus) |
| Disabled ability | Greyed label + supplementary text ("MP insuficiente", "No disponible"); skipped in keyboard/gamepad focus order; mouse hover shows tooltip |
| Selected (committed) | Brief active flash; menu closes; TCS advances |

- Ability rows display: ability name, resource cost (if any), cooldown indicator (if any)
- Disabled entries must explain why — text label required (not color-only)
- Focus wraps: pressing Down on last row focuses first row; Up on first row focuses last row
- Menu closes when a selection is committed or when the player presses B / Escape (cancels turn input if applicable per TCS rules)

**When to Use**: During the active party member's PLAYER_TURN state. Not shown at any other time.

**When NOT to Use**: Enemy turns, non-combat states, pause/menu overlays.

---

### Action Feedback Flash

**Category**: Feedback
**Used In**: HUD — Zone 2 (Grade Flash after timing input), Pause Menu (Save confirmation)

**Description**: A transient label or icon element that appears briefly to confirm an action result, then auto-dismisses. Used for two distinct feedback moments: combat grade announcement (PERFECT / GOOD / MISS / BLOCK) and save confirmation ("✓ Guardado"). Both share the same pattern but differ in duration and position.

**Specification**:

| Variant | Content | Position | Duration | Trigger |
|---------|---------|----------|----------|---------|
| Combat Grade | Grade label (PERFECT / GOOD / MISS / BLOCK) + optional icon | Zone 2 (Battle Field), above timing bar | ~0.5s total (appear ~0.1s, hold ~0.2s, fade ~0.2s) | `grade_resolved` signal from TCS |
| Save Confirmation | "✓ Guardado" label | Adjacent to Save button in Pause Menu panel | ~1.5s total (appear ~0.1s, hold ~1.0s, fade ~0.4s) | Successful save operation |

**Animation**:
- Appear: fade in (~0.1s)
- Hold: static display
- Dismiss: fade out (see durations above)
- PERFECT grade animation has an additional step: bar fills Victory Gold on first frame, then collapses on second frame, then flash appears

**Accessibility**:
- Must never be the only signal for an action result — the underlying game state changes (HP deducted, save completed) are the authoritative feedback; the flash is supplementary
- Color of the flash may vary by grade but must pair with a distinct text label (not color-only)
- "✓ Guardado" uses the checkmark symbol + text — symbol alone is not sufficient

**When to Use**: Confirming immediate action outcomes where a brief acknowledgement is the appropriate response (not a persistent indicator).

**When NOT to Use**: Error states (use a persistent error message, not an auto-dismissing flash — the player must not miss an error). Passive state changes the player didn't trigger.

---

### Confirmation Dialog

**Category**: Modal
**Used In**: Pause Menu (Return to Main Menu), Main Menu (New Game when save exists, Quit)

**Description**: A modal overlay requiring explicit player confirmation before a destructive or irreversible action completes. Contains a title question, optional warning body text (shown when there are unsaved changes), and Confirm / Cancel buttons. Traps keyboard/gamepad focus while open — the player cannot navigate to the underlying screen until the dialog is dismissed.

**Specification**:

| Element | Content | Notes |
|---------|---------|-------|
| Title | Short question ("¿Regresar al menú principal?") | ≤32 chars for layout; fits on one line at dialog width (~380px) |
| Warning text | Optional — "Los cambios no guardados se perderán" | Shown only when relevant (unsaved progress, irreversible action). Reserve space for up to 3 lines (40% expansion for other languages). |
| Confirm button | Affirmative label ("Confirmar") | Default focus position |
| Cancel button | Dismissal label ("Cancelar") | |

| State | Trigger | What Changes |
|-------|---------|-------------|
| With warning | Triggered when action has a meaningful consequence (unsaved progress) | Warning text visible |
| Without warning | Triggered when action is clean (no unsaved progress, or action is reversible) | Warning text hidden; layout compresses |

**Focus behavior**:
- Dialog opens with focus on the Confirm button (or Cancel — implementation decision; document whichever is chosen)
- Tab / D-pad navigation is trapped within Confirm / Cancel only while dialog is open
- Escape / B on gamepad always dismisses dialog (same as Cancel) — never confirms
- Parent screen items are visually dimmed and non-interactive while dialog is open

**Accessibility**:
- Focus trap is required — a player navigating by keyboard must not accidentally interact with the parent screen through the dialog
- No color-only differentiation between Confirm and Cancel — use label text as the primary differentiator
- Escape / B must always be available as a safe exit

**When to Use**: Before any action that destroys unsaved progress, exits to a significantly different context (main menu, quit), or is otherwise difficult to reverse.

**When NOT to Use**: Actions that are easily reversible, or where the cost of confirmation friction outweighs the risk (e.g., navigating between sub-screens).

---

## Animation Standards

Minimum timing reference for all UX transitions in Lux Aeterna. Art direction may refine exact curves; these are the floor values that ensure responsiveness.

| Element | Appear Duration | Hold | Dismiss Duration | Easing | Notes |
|---------|----------------|------|-----------------|--------|-------|
| Menu overlay (Pause Menu) enter | 0.15s | — | 0.10s | Linear fade | Fast — respects urgency use case |
| Confirmation dialog appear/dismiss | 0.10s | — | 0.10s | Linear fade | Snappy; parent dims simultaneously |
| Button active flash | 2–3 frames (~0.03–0.05s) | — | — | Cut | Immediate tactile feedback |
| Action Feedback Flash — Combat Grade | 0.10s | 0.20s | 0.20s | Fade in / fade out | Total ~0.5s; PERFECT has extra bar-collapse step |
| Action Feedback Flash — Save ("Guardado") | 0.10s | 1.00s | 0.40s | Fade in / fade out | Total ~1.5s |
| Resource Pip Bar update (damage/heal) | — | — | 0.20s | Ease out | Pip depletion: punchy feel |
| Timing Window Bar appear/dismiss | 0.05s | — | 0.05s | Linear fade | Near-instant; window open/close is time-critical |
| Encounter result overlay (Victory/Defeat) | 0.50s | — | — | Ease in | Tween on Node2D container; do not tween CanvasLayer directly |
| Reduced-motion override | Cut (0s) | — | Cut (0s) | None | If reduced-motion setting added at Standard tier, all fades replace with instant cuts |

**No sliding, scaling, or bouncing animations at Basic tier.** All transitions are fades. This keeps motion well below motion-sickness threshold and simplifies reduced-motion implementation.

---

## Sound Standards

Specific SFX per event are owned by the Audio Director. This table documents the pattern-level contract — the trigger event each pattern must fire, and the perceptual intent.

| Pattern | Trigger | Sound Intent | Owner |
|---------|---------|-------------|-------|
| Menu Button — focus | Button receives keyboard/gamepad focus | Short, soft navigation tone (≤100ms) | Audio Director |
| Menu Button — activate | Button confirmed | Slightly heavier click or confirm tone (≤150ms) | Audio Director |
| Menu Button — disabled hover | Cursor hovers disabled button | Muted or absent — do not reward non-interactive elements | Audio Director |
| Action Feedback Flash — PERFECT | Grade PERFECT resolved | Distinct positive tone; may have a musical component | Audio Director |
| Action Feedback Flash — GOOD | Grade GOOD resolved | Positive but lighter than PERFECT | Audio Director |
| Action Feedback Flash — MISS | Grade MISS resolved | Neutral or negative; distinct from GOOD | Audio Director |
| Action Feedback Flash — BLOCK | Grade BLOCK resolved | Defensive-feeling; distinct from MISS | Audio Director |
| Action Feedback Flash — Save | Save operation completes | Soft confirmation chime (not celebratory) | Audio Director |
| Confirmation Dialog — open | Dialog appears | Gentle alert or attention tone | Audio Director |
| Confirmation Dialog — cancel | Dialog dismissed | Soft dismiss / retreat sound | Audio Director |
| Confirmation Dialog — confirm | Destructive action confirmed | Weighty confirm; matches the gravity of the action | Audio Director |
| Combat Action Menu — navigate | Focus moves between ability rows | Soft navigation tick | Audio Director |
| Timing Window Bar — window open | Input window becomes active | Subtle cue that input is live | Audio Director |

**General rule**: UI sounds are diegetically neutral — they should not clash with the game's ambient audio. Sounds on turn-based menus are heard while music is playing; keep them short and non-competing.

---

## Gaps & Patterns Needed

Patterns known to be needed but not yet defined:

- **Screen Header** — title bar for sub-screens (Load Game, Settings, Stat Screen sub-headers); not yet specced. Needed before Settings and Load Game UX specs are authored.
- **Focus Ring** — specific visual specification for the keyboard/gamepad focus indicator shared across all interactive elements. Art direction input needed before implementation begins.
- **Status Effect Icon** — individual icon representing a single status effect (buff/debuff). Used in Enemy Panel and potentially party HP rows. Needs icon shape vocabulary defined (not just color) to satisfy colorblind requirement.
- **Scroll List** — for Load Game save slot browser and any future list-type screens. Not yet needed but likely before Polish phase.
- **Tooltip** — appears on mouse hover over disabled elements (e.g., Save disabled in combat). Used in pause.md; not yet fully specced as a standalone pattern.

---

## Open Questions

- [ ] Does the Focus Ring use a pixel-art-styled border or a clean geometric ring? Art direction input needed before implementation of any interactive element.
- [ ] Confirmation Dialog: should Confirm or Cancel be the default focused button on open? Consistency decision — must be the same across all uses (Pause Menu, Main Menu).

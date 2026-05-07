# UX Spec: Main Menu

> **Status**: In Design
> **Author**: user + ux-designer
> **Last Updated**: 2026-05-04
> **Journey Phase(s)**: Pre-game — first point of contact
> **Template**: UX Spec

---

## Purpose & Player Need

The main menu serves two player goals simultaneously:
- **New players**: establish the world's tone and mood before a single line of dialogue plays, then guide them cleanly into a new game.
- **Returning players**: get them back to where they left off as quickly as possible — one action from the title screen to resuming their session.

The player arrives at this screen wanting to *begin* or *continue the journey*. Every design decision must serve that intent. The screen is not a destination; it is a threshold.

The emotional promise of the main menu: the world of Lux Aeterna is already alive before you enter it. The menu should feel like standing at a doorway into somewhere that matters.

---

## Player Context on Arrival

**First launch**: The player has purchased or downloaded the game and is starting for the first time. They have zero story context and zero emotional investment yet. They are curious and benchmarking — comparing the opening impression to other JRPGs they know. Their emotional state: open, slightly anticipatory.

**Returning player**: The player last played sometime in the past few hours to weeks. They remember where they left off emotionally more than mechanically. Their emotional state: eager to re-enter, possibly slightly disoriented if it's been a while. The menu's job is recognition — confirming "yes, this is the world you left."

**Both cases**: The player arrives voluntarily. This is not a screen they are sent to against their will — it is where they choose to begin. The design should feel inviting, not bureaucratic.

**Player journey note**: No `design/player-journey.md` exists yet. This section assumes pre-game as the first journey phase. The journey map should be authored before HUD or in-game screen specs, as those phases are better defined.

---

## Navigation Position

The main menu is the **root of the navigation hierarchy** — it has no parent screen. It is the first screen the player sees on launch (after any engine splash / publisher logo, if applicable) and the screen they return to when exiting any other context (game over, quit from pause menu, load from a different save).

Navigation position: `[Launch] → Main Menu` (root)

All other game screens are descendants of or siblings to the main menu. The main menu does not have a "back" action — it is the terminal destination when navigating upward.

---

## Entry & Exit Points

### Entry Sources

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| Game launch | OS opens the executable | None — cold start |
| Quit from pause menu | Player selects "Return to Main Menu" during gameplay | Save state already written; session progress preserved |
| Game over | All party members incapacitated; player declines retry | Save state at last save point |

### Exit Destinations

| Exit Destination | Trigger | Notes |
|---|---|---|
| New Game (gameplay scene) | Player selects "New Game" and confirms | Irreversible if overwriting existing save — requires confirmation dialog |
| Continue (gameplay scene) | Player selects "Continue" | Resumes from last save point; one-action path for returning players |
| Load Game screen | Player selects "Load Game" | Sub-screen; player can cancel back to main menu |
| Settings screen | Player selects "Settings" | Sub-screen; player can cancel back to main menu |
| OS / Desktop | Player selects "Quit" | Confirmation dialog before exit |

---

## Layout Specification

### Information Hierarchy

Everything this screen communicates, ranked by visual priority:

1. **Game title** — "Lux Aeterna" — establishes identity immediately on every visit
2. **Continue** — returning players' primary action; first focusable item when a save exists. **Disabled state** when no save file is present: grayed out, non-interactive, label reads "No save found" (color + text both signal the state — accessibility requirement). Skipped in keyboard/gamepad focus order when disabled; focus falls to New Game instead.
3. **New Game** — first action for new players; second item for returning players
4. **Load Game** — secondary; accessible but not prominent
5. **Settings** — tertiary
6. **Quit** — present but last; never the first thing the eye lands on
7. **Version / build info** — very small corner placement; for bug reports, not general reading

**Art direction**: The title treatment and background carry the emotional weight. Menu items are a minimal list — warmth-vs-darkness visual language lives in the background/atmospheric layer, not in the menu chrome. Guest accent colors may appear subtly in the background if a save exists (color of the most recent guest character).

### Layout Zones

**Arrangement**: Centered vertical stack (classic JRPG)

| Zone | Position | Contents |
|------|----------|----------|
| **Background** | Full screen | Atmospheric pixel art scene — a moment from the world of Lux Aeterna. Warm light source visible. Subtle animation (e.g. parallax, ambient particle, flickering light). If a save exists, the most recent guest character's accent color appears subtly in the light. |
| **Title** | Upper third, horizontally centered | Game title "Lux Aeterna" — largest typographic element on screen. Subtitle or tagline optional (small, beneath title). |
| **Menu Items** | Center / center-left, vertically stacked | Continue, New Game, Load Game, Settings, Quit — in that order. |
| **Version Info** | Bottom-right corner | Version string, very small. Not part of the focus order. |

### Component Inventory

| Component | Zone | Type | Content | Interactive | Pattern |
|-----------|------|------|---------|-------------|---------|
| Background scene | Background | Pixel art scene | Atmospheric world image with ambient animation | No | New — "Atmospheric Background" |
| Title treatment | Title | Text / logo | "Lux Aeterna" styled title | No | New — "Title Treatment" |
| Continue button | Menu Items | Menu button | Label: "Continue" / "No save found" (disabled state) | Yes (when save exists) | New — "Menu Button" |
| New Game button | Menu Items | Menu button | Label: "New Game" | Yes | Uses "Menu Button" |
| Load Game button | Menu Items | Menu button | Label: "Load Game" | Yes | Uses "Menu Button" |
| Settings button | Menu Items | Menu button | Label: "Settings" | Yes | Uses "Menu Button" |
| Quit button | Menu Items | Menu button | Label: "Quit" | Yes | Uses "Menu Button" |
| Version label | Version Info | Label | Build version string | No | New — "Version Label" |

**New patterns introduced** (to be seeded into `design/ux/interaction-patterns.md`):
- **Menu Button** — interactive button with active / focused / disabled states; used throughout all menu screens
- **Title Treatment** — game title typographic/logo element; one instance per top-level screen
- **Atmospheric Background** — full-screen pixel art scene with ambient animation; used on title and chapter transition screens

### ASCII Wireframe

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│           [atmospheric pixel art background — full screen]      │
│           [warm light source visible; subtle animation]         │
│                                                                 │
│                                                                 │
│                      L U X   A E T E R N A                      │
│                     ─────────────────────                       │
│                      [tagline — optional]                       │
│                                                                 │
│                                                                 │
│                    ┌─────────────────────┐                      │
│                    │      Continue       │  ← focused (default) │
│                    ├─────────────────────┤                      │
│                    │      New Game       │                      │
│                    ├─────────────────────┤                      │
│                    │      Load Game      │                      │
│                    ├─────────────────────┤                      │
│                    │      Settings       │                      │
│                    ├─────────────────────┤                      │
│                    │        Quit         │                      │
│                    └─────────────────────┘                      │
│                                                                 │
│                                              v0.1.0  ░░░░░░░░░ │
└─────────────────────────────────────────────────────────────────┘

No-save variant: Continue → grayed out, label "No save found", focus skips to New Game
```

---

## States & Variants

| State / Variant | Trigger | What Changes |
|---|---|---|
| **Default (save exists)** | Launch with save file present | Continue is enabled and focused; all buttons active |
| **No-save (first launch)** | Launch with no save file | Continue grayed out, label "No save found", non-interactive; focus defaults to New Game |
| **New Game confirmation** | Player selects New Game when save exists | Confirmation dialog overlays the menu: "Start a new game? Your current save will be overwritten." — Confirm / Cancel. (No overlay needed on first launch.) |
| **Quit confirmation** | Player selects Quit | Confirmation dialog: "Quit to desktop?" — Yes / Cancel |
| **Post-session return** | Player returns from gameplay via pause → Return to Main Menu | Default state; save has been written; Continue is enabled |
| **Game over return** | Player returns from game over screen | Default state; save reflects last save point |

---

## Interaction Map

Input methods: Keyboard/Mouse (primary) + Gamepad (partial — d-pad navigation). No hover-only interactions.

| Component | Action | Input(s) | Immediate Feedback | Outcome |
|---|---|---|---|---|
| Continue (enabled) | Select | Mouse click / Enter / Gamepad A | Button highlight flash + confirm SFX | Load last save → gameplay scene |
| Continue (disabled) | Attempt focus | Keyboard Tab / d-pad | Focus skips this item — no interaction possible | No-op |
| New Game | Select | Mouse click / Enter / Gamepad A | Button highlight flash + confirm SFX | If save exists: open confirmation dialog. If no save: begin new game → gameplay scene |
| New Game confirmation — Confirm | Select | Mouse click / Enter / Gamepad A | Dialog closes + transition SFX | Begin new game → gameplay scene |
| New Game confirmation — Cancel | Select / Back | Mouse click / Enter / Gamepad A / Esc / Gamepad B | Dialog closes | Return focus to New Game button |
| Load Game | Select | Mouse click / Enter / Gamepad A | Button highlight flash + confirm SFX | Navigate to Load Game screen |
| Settings | Select | Mouse click / Enter / Gamepad A | Button highlight flash + confirm SFX | Navigate to Settings screen |
| Quit | Select | Mouse click / Enter / Gamepad A | Button highlight flash | Open quit confirmation dialog |
| Quit confirmation — Yes | Select | Mouse click / Enter / Gamepad A | Transition out | Exit to OS |
| Quit confirmation — Cancel | Select / Back | Mouse click / Enter / Gamepad A / Esc / Gamepad B | Dialog closes | Return focus to Quit button |
| Menu navigation | Move focus | Arrow keys / Tab / d-pad up-down | Focus indicator moves to next/prev button | — |

---

## Events Fired

| Player Action | Event Fired | Payload / Data |
|---|---|---|
| Continue selected | `scene_load_requested` (SceneManager) | save slot ID |
| New Game confirmed | `new_game_started` | none |
| Load Game selected | `load_screen_opened` | none |
| Settings selected | `settings_screen_opened` | none |
| Quit confirmed | none — OS exit call | n/a |
| Main menu entered | `main_menu_entered` | `has_save: bool` |

**State-modifying actions** (flag for architecture team): New Game confirmed overwrites save data. Irreversible. Must be gated by the confirmation dialog at the UI layer; the save system must not be called until after confirmation.

---

## Transitions & Animations

| Transition / Animation | Specification |
|---|---|
| **Screen enter (from launch)** | Fade in from black over ~0.8s. Title fades in first (~0.5s), then menu items stagger in from top to bottom (~0.1s apart). Background is already visible during fade. |
| **Screen enter (returning from gameplay)** | Fade in from black over ~0.5s. Shorter than cold launch — player is returning, not arriving for the first time. |
| **Screen exit (to gameplay / load)** | Fade to black over ~0.6s. Music fades out over the same duration or crossfades into gameplay music. |
| **Screen exit (to sub-screen)** | No full fade — sub-screens (Load Game, Settings) slide in or overlay. Main menu remains visible beneath. |
| **Button focus change** | Immediate — focus indicator moves to new button with no animation delay. Snappy navigation is required for gamepad feel. |
| **Button select feedback** | Brief highlight flash (~2–3 frames) on the selected button before the action executes. |
| **Continue disabled pulse** | No animation on the disabled Continue — static gray. Animating a disabled element draws attention to it unnecessarily. |
| **Confirmation dialog appear** | Fade in over ~0.2s. Overlay dims the background menu. |
| **Reduced-motion note** | If a reduced-motion setting is added at Standard tier, all fades collapse to instant cuts. The design must work without any transition animation. |

---

## Data Requirements

| Data | Source System | Read / Write | Notes |
|------|--------------|--------------|-------|
| Save file exists (bool) | Save System | Read | Determines Continue enabled/disabled state and New Game confirmation requirement |
| Most recent save slot ID | Save System | Read | Used by Continue to load the correct slot |
| Guest accent color (most recent guest) | Save System / StoryState | Read | Optional ambient background tint; graceful fallback if no guest has appeared yet (default warm amber) |
| Audio bus volumes | AudioSystem | Read/Write | Settings screen reads and writes; main menu music respects saved volume |
| Main menu music track | AudioSystem | Read | AudioSystem plays the designated main menu track on `main_menu_entered` |
| Game version string | Engine / build config | Read | Displayed in version label; read from a constant or project settings |

**Architecture note**: The main menu must not own any persistent state. All save-related data flows through the Save System. The menu reads and reacts — it never writes save state except through the explicit "New Game confirmed" path which delegates to the Save System.

---

## Accessibility

**Tier**: Basic (per `design/accessibility-requirements.md`)

**Mouse navigation**: All menu items are clickable directly. Mouse hover shows a hover state (highlight / cursor change) as a secondary visual aid. Hover is never the *only* way to discover or activate an option — every hover interaction has a keyboard equivalent.

**Keyboard-only navigation**: Tab / arrow keys move focus through all interactive buttons in order (skipping disabled Continue when no save exists). Enter selects. Esc cancels dialogs. No mouse required to complete any action on this screen.

**Gamepad navigation**: D-pad up/down moves focus through buttons. A (confirm) / B (cancel/back). Full menu traversal without mouse or keyboard.

**Independence**: Mouse, keyboard, and gamepad are fully independent input paths. A player can switch between them at any point without losing state.

**Focus indicators**: All focused buttons show a visible focus ring or highlight distinguishable from the unfocused state — not color alone (border or size change required alongside color).

**Continue disabled state**: Communicated via gray color + "No save found" text label — not color alone. Satisfies Basic tier color-only audit.

**Text size**: Menu button labels target 24px minimum at 1080p. Version label may be 14–16px (non-critical info).

**Contrast**: Button labels must meet WCAG 2.1 Level A contrast against the background. A subtle dark scrim behind the menu item zone ensures legibility over atmospheric pixel art.

**Screen flash**: No flashing elements on the main menu. Button highlight flash is 2–3 frames — below Harding FPA threshold.

**Pause**: The main menu is itself a resting state — no additional pause mechanism required.

---

## Localization Considerations

**Primary language**: Spanish. **Secondary**: English. All layout sizing decisions use Spanish as the reference length — English will always fit if Spanish fits.

**Spanish button labels (reference sizing)**:
| English | Spanish | Approx. length increase |
|---------|---------|------------------------|
| Continue | Continuar | +2 chars |
| New Game | Nueva partida | +7 chars |
| Load Game | Cargar partida | +8 chars |
| Settings | Ajustes | -1 chars |
| Quit | Salir | +1 char |
| No save found | Sin guardado | ~same |

**Layout-critical elements**: "Nueva partida" and "Cargar partida" are the longest button labels (~14 chars in Spanish). Button width must accommodate these without truncation at 24px. Flag these as HIGH PRIORITY for QA verification in both languages.

**Confirmation dialog**: "¿Iniciar una nueva partida? Tu guardado actual se sobreescribirá." is significantly longer than the English equivalent. The dialog box must be wide enough for this string at 24px, or allow wrapping across two lines.

**No locale-specific numbers, dates, or currencies** on this screen. Version string is not translated.

**RTL languages**: Not in scope for Episode 1.

---

## Acceptance Criteria

- [ ] Main menu opens within 3 seconds of game launch on target hardware (PC, 60fps target)
- [ ] When no save file exists: Continue button is grayed out, displays "No save found" (ES: "Sin guardado"), and cannot be selected via mouse click, keyboard Enter, or gamepad A
- [ ] When no save file exists: default keyboard/gamepad focus lands on New Game, not Continue
- [ ] When a save file exists: Continue button is enabled, focused by default, and selecting it loads the gameplay scene
- [ ] Selecting New Game when a save exists opens a confirmation dialog before any save data is modified
- [ ] Selecting New Game when no save exists begins a new game immediately with no confirmation dialog
- [ ] Selecting Quit opens a confirmation dialog; confirming exits to OS; canceling returns focus to Quit button
- [ ] All 5 interactive buttons are reachable and selectable using keyboard only (Tab / arrow keys + Enter)
- [ ] All 5 interactive buttons are reachable and selectable using mouse click only
- [ ] All 5 interactive buttons are reachable and selectable using gamepad d-pad + A only
- [ ] All focused buttons display a visible focus indicator that is not communicated by color alone
- [ ] Button labels in Spanish ("Continuar", "Nueva partida", "Cargar partida", "Ajustes", "Salir") display without truncation at 1080p
- [ ] Music begins playing when the main menu screen is entered and fades out on exit to gameplay
- [ ] The atmospheric background is visible and contains a warm light source

---

## Open Questions

- [ ] Does the main menu use a unique piece of background art, or a screenshot/composite from the opening chapter? (Art direction decision — needed before implementation)
- [ ] Is there a tagline beneath the title? If so, what is it? (Narrative decision)
- [ ] Single save slot or multiple save slots? Affects whether "Load Game" is a separate screen or a simple list. (Save System design — System 12, not yet started)
- [ ] Should the main menu play the full OST title track, or a shorter ambient loop? (Audio direction decision)
- [ ] When the guest accent color tints the background, how subtle is the effect? Needs art direction sign-off to avoid clashing with the atmospheric background.

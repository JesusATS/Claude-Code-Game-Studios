# UX Spec: Pause Menu

> **Status**: Ready for Review
> **Author**: user + ux-designer
> **Last Updated**: 2026-05-07 (rev: Stats entry added — navigation mismatch resolved)
> **Journey Phase(s)**: Mid-session — gameplay interrupted (voluntary)
> **Template**: UX Spec

---

## Purpose & Player Need

The pause menu serves three player needs that coexist without conflict:

**Urgency** — something came up in real life. The player needs to stop immediately and resume later. Every design decision must respect this: the pause menu should be reachable in one input, closeable in one input, and never force the player through a flow before they can leave.

**Review** — the player wants to check something or adjust settings before continuing. Volume, a save before a hard fight, loading a previous moment. The screen must surface these options without burying them.

**Breath** — in a story-heavy game about loss and change, players sometimes pause to sit with a decision. The design should not feel rushed. A dark, quiet overlay that doesn't fight for attention lets the player use this time as they need.

**What this screen provides**: Resume, Save (disabled in combat — auto-save only during combat), Load Game, Stats (read-only party record — always accessible), Settings, Return to Main Menu.

**What this screen does not provide**: New Game (irreversible — belongs only on Main Menu where the player has full context).

**The player arrives at this screen wanting to stay in control** — either of their real-life time, their in-game options, or their emotional pacing. The menu should feel like a trustworthy handbrake: always there, never in the way.

---

## Player Context on Arrival

The player always arrives voluntarily — they pressed Escape / Start / gamepad menu button. The game never forces them here.

**Context A — Mid-combat**: The player is in an active encounter. A timing window may have just closed (auto-closed via `force_close_window()` before the scene tree pauses), or they are between turns. Emotional state: elevated. They may be losing, replaying a mistake in their head, or simply need to stop. Save is disabled in this state — the menu communicates this clearly without making the player feel punished.

**Context B — Mid-exploration**: The player is navigating the world between encounters. Emotional state: relaxed to curious. Common reasons to pause: save before entering a dungeon, adjust volume, step away. All menu options available.

**Context C — Mid-narrative / post-story moment**: The player has just witnessed something — a guest character departure, a revelation, a tense scene. Emotional state: contemplative or raw. The "breath" use case is at its peak here. The overlay should be quiet enough to let that emotional weight sit.

**Design implication**: The menu must work across all three contexts without redesign. The visual tone should be calm and unobtrusive in every case — never triumphant, never clinical. The game world remains visible behind the overlay, dimmed but present, so the player never feels fully ejected from it.

---

## Navigation Position

The pause menu is a **gameplay-layer overlay**, not a standalone screen. It sits above the active gameplay scene at `layer ≥ 20` (per HUD System GDD — HUD owns layers 10–12; pause must not collide).

```
[Launch] → Main Menu ──────────────────────────────┐
                │                                   │
                └──► Gameplay Scene                 ▼
                           └── Pause Menu   Settings (shared screen)
                                 ├── Settings ──────►  (cancel → caller)
                                 └── Load Game (sub-screen, cancel → Pause Menu)
```

Settings is a **shared screen** reachable from both Main Menu and Pause Menu. It returns the player to whichever screen called it. Load Game is only accessible from Pause Menu during gameplay (not from Main Menu — Main Menu has its own Load Game entry).

---

## Entry & Exit Points

### Entry Sources

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| Exploration (world map / dungeon) | Escape / Start / gamepad menu button | Current map position, party state, no active timing window |
| Combat (between turns) | Escape / Start / gamepad menu button | `force_close_window()` called first if a timing window was open; combat state frozen |
| Narrative / dialogue | Escape / Start / gamepad menu button | Dialogue state frozen; current scene visible behind overlay |

### Exit Destinations

| Exit Destination | Trigger | Notes |
|---|---|---|
| Gameplay Scene (resume) | Player selects "Resume" OR presses Escape / Start again | One-button close — same input that opened the menu closes it. No confirmation needed. |
| Gameplay Scene (stay on pause) | Player selects "Save" (outside combat) | Save executes; brief "Guardado" flash appears on the Save button (in-menu feedback, ~1.5s, then fades); pause menu remains open. Not a navigation event. |
| Load Game sub-screen | Player selects "Load Game" | Cancel → returns to Pause Menu. Confirming a load → loads that save and enters gameplay scene (exits pause). |
| Stat Screen | Player selects "Stats" | Read-only overlay; "Back" / B / Escape → returns to Pause Menu. Accessible in both combat and exploration pause contexts. |
| Settings screen (shared) | Player selects "Settings" | Shared screen; "Back" → returns to Pause Menu. |
| Main Menu | Player selects "Return to Main Menu" and confirms | Inline confirmation dialog (overlay on pause menu — not a separate screen). Unsaved progress warning if no recent save. Irreversible without loading. |

---

## Layout Specification

### Information Hierarchy

1. **Resume** — most prominent; primary action for all three use cases
2. **Save** — second; disabled in combat (greyed, non-interactive, label explains state)
3. **Load Game** — accessible but secondary
4. **Stats** — reference tool; always enabled; read-only
5. **Settings** — tertiary
6. **Return to Main Menu** — present but visually de-emphasized; should never feel like the accidental choice
7. No screen title — identity comes from the visual treatment of the panel itself

### Layout Zones

Two zones:

| Zone | Role | Notes |
|------|------|-------|
| **Backdrop** | Full-screen semi-transparent dark overlay behind the panel | Dims gameplay scene; game world remains visible. Non-interactive. Clicking backdrop does NOT resume (avoids accidental dismissal). |
| **Panel** | Centered vertical card containing all menu items | Narrow (~320–380px at 1080p), tall enough to fit 6 buttons with breathing room. No decorative header — art direction through panel texture/border treatment per Art Bible. |

### Component Inventory

| Component | Type | Interactive | Pattern | Notes |
|-----------|------|-------------|---------|-------|
| Backdrop | Visual overlay | No | — | Full-screen dim; does not close menu on click |
| Panel container | Visual container | No | — | Centered card; border/texture per Art Bible pixel art style |
| Resume | Button | Yes | Menu Button | Always enabled; first in focus order |
| Save | Button | Yes (outside combat) | Menu Button | Disabled state in combat: greyed, label reads "Guardar (no disponible en combate)"; skipped in focus order when disabled |
| "Guardado" flash | Label / feedback | No | — | Appears adjacent to Save button ~1.5s after successful save, then fades; **new pattern — flag for pattern library** |
| Load Game | Button | Yes | Menu Button | Always enabled |
| Stats | Button | Yes | Menu Button | Always enabled (accessible in combat and exploration pause); opens Stat Screen as read-only overlay |
| Settings | Button | Yes | Menu Button | Always enabled; opens shared Settings screen |
| Return to Main Menu | Button | Yes | Menu Button | Always enabled; triggers inline confirmation dialog |
| Confirmation dialog | Modal overlay | Yes | — | Overlays the panel; "¿Regresar al menú principal?" with Confirm / Cancel; **new pattern — flag for pattern library** |

### ASCII Wireframe

```
━━━ STATE 1: Default (outside combat) ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

┌─────────────────────────────────────────────────────────────────────────────┐
│  · · · [gameplay scene — dimmed] · · · · · · · · · · · · · · · · · · · · · │
│                                                                             │
│                      ┌───────────────────────────┐                         │
│                      │                           │                         │
│                      │  ► Reanudar               │  ← focused              │
│                      │    Guardar                │                         │
│                      │    Cargar partida         │                         │
│                      │    Estadísticas           │                         │
│                      │    Configuración          │                         │
│                      │    Menú principal         │                         │
│                      │                           │                         │
│                      └───────────────────────────┘                         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

━━━ STATE 2: Combat (Save disabled) ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

│                      ┌───────────────────────────┐                         │
│                      │                           │                         │
│                      │  ► Reanudar               │                         │
│                      │    Guardar                │  ← greyed               │
│                      │    (no disponible)        │     skipped in focus    │
│                      │    Cargar partida         │                         │
│                      │    Estadísticas           │                         │
│                      │    Configuración          │                         │
│                      │    Menú principal         │                         │
│                      │                           │                         │
│                      └───────────────────────────┘                         │

━━━ STATE 3: Save feedback flash ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

│                      ┌───────────────────────────┐                         │
│                      │                           │                         │
│                      │    Reanudar               │                         │
│                      │  ► Guardar  ✓ Guardado    │  ← flash ~1.5s          │
│                      │    Cargar partida         │                         │
│                      │    Estadísticas           │                         │
│                      │    Configuración          │                         │
│                      │    Menú principal         │                         │
│                      │                           │                         │
│                      └───────────────────────────┘                         │

━━━ STATE 4: Return to Main Menu confirmation ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

│                      ┌───────────────────────────┐                         │
│            ┌─────────┤                           ├────────────────────┐    │
│            │         │    [panel dimmed]         │                    │    │
│            │  ¿Regresar al menú principal?               │               │    │
│            │  Los cambios no guardados se perderán       │               │    │
│            │                                            │               │    │
│            │    ► Confirmar        Cancelar              │               │    │
│            │                                     │                    │    │
│            └─────────┤                           ├────────────────────┘    │
│                      └───────────────────────────┘                         │
```

---

## States & Variants

| State / Variant | Trigger | What Changes |
|-----------------|---------|--------------|
| **Default** | Paused during exploration or narrative | All 6 buttons available and enabled. Save is interactive. |
| **Combat** | Paused during an active combat encounter | Save greyed out, labelled "no disponible", skipped in focus order. All other buttons (including Stats) active. |
| **Save feedback** | Player successfully saves | "✓ Guardado" flash appears on Save button for ~1.5s, then fades. Menu remains open. |
| **Return to Main Menu confirmation — with unsaved changes** | Player selects "Menú principal" and save state is dirty (progress since last save exists) | Confirmation dialog shows: "¿Regresar al menú principal?" + warning "Los cambios no guardados se perderán." Two buttons: Confirmar / Cancelar. |
| **Return to Main Menu confirmation — no unsaved changes** | Player selects "Menú principal" and save state is clean (just saved or no progress since last save) | Confirmation dialog shows: "¿Regresar al menú principal?" — no warning text. Two buttons: Confirmar / Cancelar. |
| **Load confirmation (in Load Game sub-screen)** | Player confirms a save slot to load | Handled by Load Game sub-screen — not a pause menu state. Pause menu is exited. |

**Save state tracking note**: The UI must receive a signal or query a flag when the save state becomes dirty (progress since last save) and clean (after a successful save). This is a data requirement — see Data Requirements section.

---

## Interaction Map

Mapping interactions for: Keyboard/Mouse (primary), Gamepad (partial). Target: PC.

| Component | Action | Keyboard/Mouse Input | Gamepad Input | Feedback | Outcome |
|-----------|--------|---------------------|---------------|----------|---------|
| Open pause | Press pause | Escape | Start / Menu button | Panel slides/fades in (see Transitions) | Pause menu opens; gameplay frozen |
| Any button | Navigate | Tab / Arrow keys | D-pad Up/Down | Focus ring moves to next/previous button | Focus shifts |
| Any button | Activate | Enter / Space / Mouse click | A (confirm) | Button active state flash (~2–3 frames) | Action triggers |
| **Resume** | Activate | Enter / Space / click / Escape | A / B / Start | Brief active flash | Menu closes; gameplay resumes |
| **Save** (enabled) | Activate | Enter / Space / click | A | Active flash → "✓ Guardado" flash on button | Saves game; menu stays open |
| **Save** (disabled, combat) | Navigate through | Tab skips; mouse hover shows tooltip | D-pad skips | No active state; disabled visual | No action; non-interactive |
| **Load Game** | Activate | Enter / Space / click | A | Active flash | Load Game sub-screen opens |
| **Stats** | Activate | Enter / Space / click | A | Active flash | Stat Screen opens (read-only overlay); B / Escape → returns to Pause Menu |
| **Settings** | Activate | Enter / Space / click | A | Active flash | Settings screen opens (shared) |
| **Return to Main Menu** | Activate | Enter / Space / click | A | Active flash | Confirmation dialog opens |
| **Confirmation — Confirm** | Activate | Enter / Space / click | A | Active flash | Scene transitions to Main Menu |
| **Confirmation — Cancel** | Activate | Enter / Space / click / Escape | A / B | Active flash | Dialog closes; focus returns to "Menú principal" button |
| **Backdrop** | Click | Mouse click | — | None | No action — does not close menu |

**Navigation notes**:
- B on gamepad acts as "back/cancel" throughout — closes dialog if open, otherwise closes pause menu (same as Resume)
- Escape on keyboard: closes dialog if open first; closes pause menu on second press (or if no dialog open)
- Disabled Save button: mouse hover shows tooltip "No disponible en combate" — text-only, no color-only signalling

---

## Events Fired

| Player Action | Event / Signal | Payload | Notes |
|---|---|---|---|
| Pause menu opens | `pause_menu_opened` | `context: StringName` (&"combat", &"exploration", &"narrative") | Allows audio system to respond (e.g. duck music slightly during pause) |
| Resume | `pause_menu_closed` | `context: StringName` | Symmetrical with opened |
| Save (confirmed) | `game_saved` | `slot: int`, `timestamp: int` | **Persistent state change** — clears the save-state dirty flag; UI listens for this to update confirmation dialog variant |
| Load Game opened | `load_screen_opened` | — | Navigation event only |
| Stats opened | `stats_screen_opened` | `caller: StringName` (&"pause") | Stat screen needs caller context to know where "Back" returns |
| Settings opened | `settings_screen_opened` | `caller: StringName` (&"pause") | Shared screen needs caller context to know where "Back" returns |
| Return to Main Menu confirmed | `return_to_main_menu_requested` | — | **Significant state change** — triggers scene transition; gameplay state torn down |
| Confirmation dialog cancelled | none | — | Local UI state only; no game-state change |
| Backdrop clicked | none | — | Intentionally fires no event |

**Dirty flag note**: The pause menu does not own or write the save-state dirty flag — it only reads it to determine which confirmation dialog variant to show. The flag is owned by the save system and updated on `game_saved` (clean) and on any gameplay state change that advances progress (dirty). Architecture team to confirm the signal contract.

---

## Transitions & Animations

| Transition | Description | Duration | Notes |
|---|---|---|---|
| **Enter** | Backdrop fades in (dark overlay dims gameplay scene) simultaneously with panel fading in | ~0.15s | Fast — respects urgency use case. No slide; fade only. |
| **Exit (Resume)** | Panel and backdrop fade out together | ~0.1s | Slightly faster than enter — resuming should feel immediate |
| **Exit (to Main Menu)** | Panel fades out; scene transition handled by scene manager | ~0.15s panel fade, then scene transition | Scene transition animation is out of scope for this spec |
| **Save feedback flash** | "✓ Guardado" label fades in quickly (~0.1s), holds for ~1.0s, fades out (~0.4s) | ~1.5s total | Warm colour (not green — colour alone cannot be the signal; label text is the primary indicator) |
| **Confirmation dialog appear** | Dialog fades in over dimmed panel | ~0.1s | Pause panel items dim slightly to indicate they are inactive |
| **Confirmation dialog dismiss** | Dialog fades out; panel items restore opacity | ~0.1s | |

**Reduced-motion note**: All transitions are fades with durations under 0.2s — below the threshold for motion sickness concern at Basic accessibility tier. No sliding, scaling, or bouncing animations. If a reduced-motion setting is added at Standard tier, these fades can be cut to instant without any layout changes.

---

## Data Requirements

| Data | Source System | Read / Write | Update Frequency | Notes |
|------|--------------|--------------|-----------------|-------|
| **Is in combat** | Timing Combat System / scene state | Read | On pause menu open | Determines Save button enabled/disabled state. Boolean. Architecture team to confirm query method (signal vs. direct query). |
| **Save state dirty flag** | Save System | Read | Reactive — listens for `game_saved` (clean) and progress-change events (dirty) | Determines confirmation dialog variant when "Return to Main Menu" is selected. Boolean. Pause menu does not own this flag. |
| **Save operation result** | Save System | Read | On save attempt | Success → trigger "Guardado" flash. Failure → see Open Questions (no error state defined yet). |
| **Settings caller context** | Pause menu itself | Write (pass to Settings screen) | On Settings opened | Passes `&"pause"` so Settings screen knows to return here on Back. |

**Architecture flag**: Two data dependencies (combat state + dirty flag) require a defined signal contract before the pause menu can be implemented. Recommend an ADR or control manifest entry for save-state event ownership before the pause menu story is written.

---

## Accessibility

**Tier**: Basic (per `design/accessibility-requirements.md`)

| Requirement | How This Screen Satisfies It | Status |
|---|---|---|
| Keyboard-only navigation | Tab / Arrow keys reach all interactive elements in order: Resume → Save (skipped when disabled) → Load Game → Stats → Settings → Return to Main Menu. Escape closes menu / cancels dialog. | Specified |
| Gamepad navigation | D-pad Up/Down navigates all buttons in the same order. A confirms. B cancels / resumes. Start toggles pause. | Specified |
| No color-as-only-indicator | Save disabled state: greyed colour + "no disponible" text label. "✓ Guardado" flash: warm colour + text label. Confirmation dialog variant: text changes (not colour change). | Specified |
| Readable text at 1080p | Minimum 24px for all button labels (per accessibility doc). Spanish labels sized as reference — "Menú principal" is the longest (~14 chars). | Specified |
| Pause in all gameplay states | Pause accessible during combat, exploration, and narrative. Save disabled in combat with explanation — player is never blocked from pausing. | Specified |
| Focus does not escape dialog | When confirmation dialog is open, Tab / D-pad navigation is trapped within the dialog (Confirm / Cancel only). Escape / B always available to cancel. | Specified |
| Accidental dismissal prevention | Backdrop click does not close menu — prevents motor-impaired players from accidentally dismissing during a pause. | Specified |
| Screen reader | Not required at Basic tier. Keyboard navigation provides structural access. Escalation to Standard tier adds AccessKit annotation. | Deferred |

---

## Localization Considerations

Spanish is the primary language. All layout sizing uses Spanish labels as the reference length.

| Text Element | Spanish | Char Count | Layout Risk | Notes |
|---|---|---|---|---|
| Resume | "Reanudar" | 8 | Low | — |
| Save | "Guardar" | 7 | Low | — |
| Save (disabled sub-label) | "no disponible en combate" | 24 | **Medium** | Fits on a second line inside button; size to wrap gracefully at ~320px panel width |
| Load Game | "Cargar partida" | 14 | Low | — |
| Settings | "Configuración" | 13 | Low | — |
| Stats | "Estadísticas del grupo" | 22 | Low | — |
| Return to Main Menu | "Menú principal" | 14 | Low | — |
| Confirm dialog title | "¿Regresar al menú principal?" | 28 | Low | Fits on one line in dialog width |
| Confirm dialog warning | "Los cambios no guardados se perderán" | 36 | **Medium** | Must wrap within dialog — do not truncate. Two lines at dialog width (~380px). |
| Save flash label | "✓ Guardado" | 10 | Low | — |

**If the game localises to other languages**: The confirmation dialog warning text (36 chars in Spanish) is the highest-risk string — German / French expansions of ~30–40% could push it to 3 lines. Reserve vertical space in the dialog for up to 3 lines before the Confirm / Cancel buttons.

---

## Acceptance Criteria

- [ ] **AC-1 (Performance)**: Pause menu is fully visible and interactive within 100ms of the player pressing Escape / Start / gamepad menu button from any gameplay state (exploration, combat, narrative).

- [ ] **AC-2 (Navigation — keyboard)**: Pressing Tab from Resume cycles focus through: Resume → Load Game → Estadísticas → Settings → Menú principal (Save is skipped when in combat). Pressing Enter on each button triggers the correct action.

- [ ] **AC-3 (Navigation — gamepad)**: D-pad Down from Resume cycles focus in the same order as AC-2. A confirms. B closes the menu from any state (dismisses dialog first if open, then closes menu).

- [ ] **AC-4 (Combat state — Save disabled)**: When the pause menu is opened during combat, the Save button is visually greyed, the sub-label "no disponible en combate" is visible, and the button cannot be activated by any input method. Hovering with the mouse shows the tooltip text.

- [ ] **AC-5 (Save feedback)**: Activating Save outside combat triggers a save, shows "✓ Guardado" adjacent to the Save button within one frame of save completion, and the label fades out within 1.5 seconds. The pause menu remains open throughout.

- [ ] **AC-6 (Confirmation dialog — dirty state)**: Selecting "Menú principal" when unsaved progress exists opens the confirmation dialog with both the title "¿Regresar al menú principal?" and the warning "Los cambios no guardados se perderán" visible.

- [ ] **AC-7 (Confirmation dialog — clean state)**: Selecting "Menú principal" immediately after a successful save opens the confirmation dialog with the title only — no warning text shown.

- [ ] **AC-8 (Focus trap)**: While the confirmation dialog is open, Tab and D-pad navigation cannot move focus outside the dialog (Confirmar / Cancelar only). Pressing Escape or B closes the dialog and returns focus to the "Menú principal" button.

- [ ] **AC-9 (Backdrop)**: Clicking the dimmed gameplay area behind the panel does not close the pause menu or trigger any action.

- [ ] **AC-10 (Layer order)**: The pause overlay renders above all HUD elements in all gameplay states — no HUD element (health bars, turn order, timing grade) appears on top of the pause panel.

- [ ] **AC-11 (Resume toggle)**: Pressing Escape / Start / gamepad menu button while the pause menu is open (and no dialog is active) closes the menu and resumes gameplay — same single input that opened it.

- [ ] **AC-12 (Stats navigation)**: Selecting "Estadísticas del grupo" opens the Stat Screen in read-only mode from both combat-pause and exploration-pause contexts. Pressing B / Escape from the Stat Screen returns to the Pause Menu with focus restored to the Stats button.

---

## Open Questions

- **OQ-1 — Save failure state**: No error state is defined for when Save fails (disk full, file permission error, etc.). Before implementation, define: does the "✓ Guardado" flash become an "✗ Error al guardar" flash? Does it persist longer? Owner: UX + architecture.

- **OQ-2 — Save-state dirty flag signal contract**: The pause menu reads but does not own the dirty flag. The signal contract (which system emits what, and when) must be established before the pause menu story is written. Owner: architecture team.

- **OQ-3 — Combat state query method**: The pause menu needs to know whether it was opened during combat to disable Save. Signal vs. direct query to scene state not yet decided. Owner: architecture team.

- **OQ-4 — Settings screen spec**: `design/ux/settings.md` does not exist yet. The pause menu references it as a shared screen — it must be specced before the pause menu story can be fully implementation-ready. Suggested content: audio volume sliders (Music/SFX/Voice), display options.

- **OQ-5 — Load Game sub-screen spec**: The Load Game sub-screen (save slot browser) is not specced. Referenced here as a destination but its layout, states, and interactions are undefined.

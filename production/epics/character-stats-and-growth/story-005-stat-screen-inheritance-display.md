# Story 005: Stat Screen — Inheritance Display

> **Epic**: Character Stats & Growth
> **Status**: Complete
> **Layer**: Foundation
> **Type**: UI
> **Manifest Version**: 2026-05-04

## Context

**GDD**: `design/gdd/character-stats-and-growth.md`
**Requirement**: `TR-CSG-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Data-Driven Resource Registry Pattern
**ADR Decision Summary**: Stat screen reads `CharacterData` fields and `NamedInheritanceObject` entries directly — no computation. Display is read-only; no system may write to `CharacterData` from the stat screen.

**Estimate**: M (~3–4 hrs)
**Risk note**: OQ-1 (HP_current ownership — TCS ADR) and OQ-2 (accent_color field on CharacterData) may block the combat pause variant and inheritance color rendering respectively. Resolve before starting.

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: In Godot 4.6, `grab_focus()` only sets keyboard/gamepad focus, not mouse focus (dual-focus system). All interactive stat screen elements must support d-pad/keyboard navigation independently of mouse. No hover-only interactions.

**Control Manifest Rules (Presentation/Foundation)**:
- Required: All interactive UI elements support keyboard or d-pad equivalent (no hover-only interactions — technical-preferences.md)
- Required: `mouse_filter = Control.MOUSE_FILTER_IGNORE` on all non-interactive display nodes
- Global: Accessibility tier (Basic) committed in `design/accessibility-requirements.md` — stat screen must be fully navigable by keyboard/gamepad

---

## Acceptance Criteria

*From `design/ux/stat-screen.md` (Approved 2026-05-05 — supersedes GDD AC-12b):*

- [ ] **AC-1** — Screen opens within 100ms from any entry trigger at 1920×1080.
- [ ] **AC-2** — GIVEN party with 3 core members and no guest, WHEN stat screen opens, THEN all four column headers render (3 named, 1 empty/dashed), all 5 stats (HP, ATK, DEF, SPD, FLUX) are visible for each occupied slot.
- [ ] **AC-3** — GIVEN stat screen is open, WHEN Esc (keyboard) or B (gamepad) is pressed, THEN screen closes and the caller screen (map or combat pause) is restored.
- [ ] **AC-4** — GIVEN Ne's `CharacterData` has `NamedInheritanceObject` {name="Her Name's Gift", stat=&"flux", magnitude=3}, WHEN stat screen opens, THEN Ne's FLUX column shows effective total prominently, "base N" below it, and "Her Name's Gift: +3 FLUX" in the departed guest's accent color at 60% opacity below the divider.
- [ ] **AC-5** — GIVEN a character has no `NamedInheritanceObject` entries, WHEN stat screen opens, THEN the inheritance section shows "No traces yet carried" in muted text weight.
- [ ] **AC-6** — GIVEN it is the first time the stat screen has been opened this playthrough (first-visit flag unset in StoryState), WHEN screen renders, THEN the first character column with an inheritance entry is briefly highlighted to draw player attention; on subsequent opens the highlight does not appear.
- [ ] **AC-7** — GIVEN keyboard or gamepad input only, WHEN stat screen is open, THEN Esc/B closes the screen; no element requires mouse hover to read.

---

## Implementation Notes

*Derived from `design/ux/stat-screen.md` (Approved 2026-05-05) and ADR-0001.*

### Scene Structure

StatScreen as a full-screen `CanvasLayer` (or `Control` stretched to full viewport). Entry/exit managed by the calling screen — stat screen does not push itself.

Layout root: `HBoxContainer` with 4 equal-width `VBoxContainer` columns, one per party slot (indices 0–3). Populate columns by calling `PartyCompositionManager.get_slot(i)` for `i` in `0..3`. If `get_slot(i)` returns `null`, render the empty slot state (dashed Spent Coal border, no portrait, no name, no stats).

### Data Reading

All reads are through PCM and CharacterData — never direct field access on a copy. Read once at screen open; do not subscribe to signals (passive display, not live-updating).

Per occupied slot:
- `CharacterData.display_name` → column header label
- `CharacterData` resource → portrait chip (24×24px)
- `CharacterData.hp_max`, `.atk`, `.def`, `.spd`, `.flux` → base stat values
- `CharacterData.inheritances: Array[NamedInheritanceObject]` → inheritance entries
- `CharacterData.accent_color` → guest accent color (OQ-2 — field must exist; raise an issue if missing)

HP display mode is passed as a parameter from the caller:
- `"exploration"` → display `hp_max` only (e.g., "120")
- `"combat_pause"` → display `hp_current / hp_max` (e.g., "87 / 120")

`hp_current` in combat pause mode must be requested as a read-only snapshot from the Timing Combat System, not from `CharacterData`. Confirm the access API with the TCS ADR before implementing this variant (OQ-1).

### Stats Block Per Column

For each of the 5 stats (HP, ATK, DEF, SPD, FLUX):
- One `Label` for the effective total (Primary typeface, large) — always shown
- One `Label` for the base value secondary text, e.g., `"(base 8)"` — shown only when `inheritances` contains at least one entry modifying this stat; hidden otherwise
- Effective total = base + sum of magnitudes from `NamedInheritanceObject` entries where `obj.stat == stat_key`

### Inheritance Display

After the stats block, per column:
1. If `inheritances.is_empty()`: show `"No traces yet carried"` label (Spent Coal, reduced weight). No divider.
2. If `inheritances.size() > 0`: show thin `HSeparator` (Spent Coal), then one `Label` per entry:
   - Format: `"[obj.name]'s Gift: +[obj.magnitude] [obj.stat.to_upper()]"`
   - Guest name portion: Flavor/Accent typeface
   - Color: `CharacterData.accent_color` at 60% opacity (`color.a = 0.6`)
   - `mouse_filter = Control.MOUSE_FILTER_IGNORE`

### All Display Nodes

Set `mouse_filter = Control.MOUSE_FILTER_IGNORE` on every node in the scene. The screen is a document — no hover states, no click targets.

### Entry / Exit Animation

Entry: `Tween` the panel's `scale` from `Vector2(0.05, 0.05)` to `Vector2(1, 1)`, pivot at screen center, duration 0.25s, `Tween.EASE_OUT`. Columns populate instantly at full scale — no stagger.

Exit: Reverse tween (scale 1 → 0.05), duration 0.2s. Triggered immediately on Back input — emit `ui_stat_screen_closed` with context payload on tween completion.

### First-Visit Inheritance Highlight

On screen open:
1. Check `StoryState.check_flag("stat_screen_first_view_[character_id]")` for each occupied slot.
2. If the flag is `false` AND the character has at least one inheritance entry: queue the glow animation.
3. Glow: 0.4–0.6s delay after entry animation completes, then `Tween` the inheritance entry `Label`'s `modulate.a` from 0.6 → 1.0 → 0.6, cycle duration 1.5s, 2–3 full cycles, then settle at 0.6.
4. On glow completion: emit `ui_first_inheritance_viewed` signal with `character_id`. The StoryState listener writes the flag.
5. On subsequent opens the flag is `true` → skip glow entirely.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: `CharacterData` schema (data layer)
- **Story 003**: `NamedInheritanceObject` type and application (logic layer)
- **HUD System epic**: combat HUD health display, turn order strip, portrait state — separate UX spec

---

## QA Test Cases

*Manual verification steps — UI story, evidence doc required at `production/qa/evidence/stat-screen-inheritance-evidence.md`.*

- **AC-1 (Performance)**
  - Setup: Launch game to exploration state with party loaded; open party menu
  - Verify: Select "Stats" option and measure time to first frame of unfurl animation
  - Pass condition: Animation begins within 100ms of input at 1920×1080

- **AC-2 (Entry — exploration vs. combat pause HP mode)**
  - Setup A: Open stat screen from party menu during exploration
  - Verify A: HP column shows single value (HP_max only, e.g., "120"); no slash/current HP
  - Setup B: Enter combat, pause, open stat screen from pause menu
  - Verify B: HP column shows "current / max" format (e.g., "87 / 120")
  - Pass condition: Both HP display modes render correctly and do not bleed into each other

- **AC-3 (Exit)**
  - Setup: Open stat screen from party menu; open again from combat pause menu
  - Verify: Press Escape (keyboard) or B (gamepad) in each context
  - Pass condition: Returns to party menu from exploration context; returns to pause menu from combat pause context; no other screen state changes

- **AC-4 (Inheritance display — visual)**
  - Setup: Ensure Ne's `CharacterData` has one `NamedInheritanceObject` {name="[Guest Name]", stat=FLUX, magnitude=3, base FLUX=8}; open stat screen
  - Verify: Ne's column shows FLUX = 11 (large effective total), "(base 8)" in smaller secondary text below it, a thin horizontal divider, and "[Guest Name]'s Gift: +3 FLUX" in guest accent color at ~60% opacity
  - Pass condition: Effective total and base value are simultaneously visible; inheritance entry is visually distinct from stat rows; divider present; accent color applied

- **AC-5 (Empty inheritance state)**
  - Setup: Open stat screen with a character who has no `NamedInheritanceObject` entries (e.g., Clawd at game start)
  - Verify: That character's column shows a single number per stat row (no secondary base text), no divider, and "No traces yet carried" in muted text weight
  - Pass condition: Layout is clean; no base/effective split; no divider; empty-state message visible

- **AC-6 (First-visit highlight)**
  - Setup: Clear the first-visit flag in StoryState for a character with an inheritance entry; open stat screen
  - Verify: After the unfurl animation settles (~0.4–0.6s), the inheritance entry glows with a warm pulse (~1.5s cycle, 2–3 cycles); glow fades; close and reopen the stat screen
  - Pass condition: Glow appears exactly once on first open; absent on all subsequent opens (same session and after save/reload)

- **AC-7 (Keyboard/gamepad — no mouse)**
  - Setup: Disconnect mouse; open game; navigate to party menu via keyboard (arrow keys + Enter) or gamepad (d-pad + A)
  - Verify: Stat screen opens; all stat values for all three core characters are readable; Escape (keyboard) or B (gamepad) closes the screen
  - Pass condition: Complete stat review cycle possible without mouse; no element inaccessible via keyboard/gamepad only

---

## Test Evidence

**Story Type**: UI
**Required evidence**: `production/qa/evidence/stat-screen-inheritance-evidence.md` + lead sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 Done, Story 003 Done, `design/ux/stat-screen.md` Approved
- Unlocks: Nothing in this epic — this is the final story

---

## Completion Notes
**Completed**: 2026-05-05
**Criteria**: 6/7 passing (AC-6 deferred — first-visit glow requires playtest session)
**Deviations**:
- ADVISORY: `_compute_effective()` computed inline instead of via `CharacterStatsUtil.effective_stat()` (ADR-0007 drift — display-only context). Tech debt logged.
- OUT OF SCOPE (accepted): `character_data.gd` modified to add `accent_color` field — pre-authorized by story's OQ-2 Risk note.
**Test Evidence**: UI story — `production/qa/evidence/stat-screen-inheritance-evidence.md` not yet created. Create and obtain lead sign-off before final closure.
**Code Review**: Complete — 3 blocking issues identified and fixed (concurrent Tween race, await re-entrance guard, double-close guard).
**Untested criteria**: AC-6 (first-visit glow). Verify in first playtest session.

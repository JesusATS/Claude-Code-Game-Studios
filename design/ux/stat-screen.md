# UX Spec: Stat Screen

> **Status**: Approved
> **Author**: user + ux-designer
> **Last Updated**: 2026-05-05
> **Journey Phase(s)**: Unknown — no player journey map yet
> **Template**: UX Spec

---

## Purpose & Player Need

The stat screen serves the player who wants to make an informed pre-combat decision — "is this party ready, and do I understand why their numbers are what they are?" The primary need is quick stat legibility: a player should be able to read all five stats for a character in under 5 seconds without hunting.

The secondary need is transparency of origin: because base stats and inherited modifications produce an effective total, the screen must make the math visible. A player who sees Ne's FLUX at 11 needs to understand *why* it's 11 without opening a separate document.

The tertiary function — emotional record-keeping of guest legacies — is served by the same display. The inheritance entries don't require a separate mode; they're present whenever the stat screen is open. The player who wants to remember what a guest left behind finds it in the same place as the player who just wants the numbers.

**What would go wrong if this screen didn't work well**: Players misread effective totals as base stats, building incorrect mental models of their party's capabilities. Or they find the inheritance entries confusing clutter when they just want the number. Both failure modes are solved by clear visual hierarchy — base → inheritance → total — rather than by hiding any layer.

---

## Player Context on Arrival

The player most commonly arrives at the stat screen from the party menu during exploration — between encounters, at a save point, or after a narrative beat. They are calm, have time to read, and are planning ahead. This is the dominant use case and the one the layout should optimise for.

The screen is introduced to the player at a meaningful moment: immediately after the first Named Inheritance Object lands — when a guest departs and a stat changes for the first time. The game directs the player to open it. This first visit is not just functional; it is the moment the mechanical legacy system becomes legible. The spec must account for this: the inheritance display must be immediately understandable on first sight, with no prior knowledge required.

A secondary use case exists: opening the screen from a combat pause to check a stat before choosing an ability. In this context the player is under mild pressure — they want to confirm a number and return. The layout must support fast scanning without requiring the player to navigate away from their current decision. They are not here to read; they are here to confirm.

**Assumed emotional state**: Deliberate during exploration (primary); task-focused during combat pause (secondary). The screen should never feel like a wall of information — both personas need to find their number quickly.

---

## Navigation Position

The stat screen is a full-screen overlay accessible from two positions in the navigation hierarchy:

**Primary path**: Exploration → Party Menu → Stat Screen
The party menu is a top-level exploration-state menu (accessible at any time outside combat). The stat screen is one destination within it, alongside inventory and abilities. It is always reachable during exploration — not context-gated.

**Secondary path**: Combat → Pause Menu → Stat Screen
During combat, the pause menu provides a read-only view of party state. The stat screen is accessible from this pause context. It is read-only in both paths — no stat can be modified from this screen.

**Navigation shorthand**: Exploration → Party Menu → **Stat Screen**
Combat (paused) → Pause Menu → **Stat Screen**

The screen has no sub-screens or child destinations. It is a terminal node — the player reads, then returns to the caller.

---

## Entry & Exit Points

**Entry Points**

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| Party Menu (exploration) | Select "Stats" option | Current party roster; no time pressure |
| Pause Menu (combat) | Select "Stats" option | Active encounter state; mild time pressure (paused, not urgent) |
| First inheritance tutorial | Game-directed prompt after first guest departure | Directed context: player was just told to open this screen |

**Exit Points**

| Exit Destination | Trigger | Notes |
|---|---|---|
| Party Menu | Cancel / Back (keyboard: Escape; gamepad: B/Circle) | Returns to exact party menu state — no data changed |
| Pause Menu | Cancel / Back (keyboard: Escape; gamepad: B/Circle) | Returns to pause menu — combat state unchanged |

No irreversible actions occur on this screen. All exits are safe. The stat screen is strictly read-only; no state is written on entry or exit.

---

## Layout Specification

### Information Hierarchy

Visual priority order, top to bottom:

1. **Effective totals** — the answer to "what is his stat right now?" Large, prominent type per stat row.
2. **Character name / identity** — which column am I reading? Name and portrait at column top.
3. **Base stats** — where the number comes from. Secondary text beneath effective total when inheritance exists; sole value when no inheritance is present.
4. **Inheritance entries** — explains the delta between base and effective. Below a divider, in guest accent color. Present but visually subordinate.
5. **Empty inheritance state** — "No traces yet carried." Muted, present, not demanding attention.

### Layout Zones

**Option A — 4-Column Character Ledger** (selected)

Each character owns a vertical column. Portrait + name anchors the column top. Stats read downward: effective total prominent per row, base value in secondary text beneath when an inheritance exists. Inheritance entries sit below a thin divider at the column bottom. All four characters visible simultaneously — cross-party comparison by scanning horizontally across a stat row.

### Component Inventory

**Zone 1 — Screen Frame**
- Full-screen parchment panel (Deep Linen surface, Spent Coal border depth)
- Ornamental guild record sheet border (art bible Section 7.1 motifs)
- Screen title label: "PARTY RECORD" — Primary typeface, centered in header band

**Zone 2 — Column Header (per character)**
- Portrait chip — 24×24px, parchment-metal frame; Amber Hearth border (core party) / guest accent border (guest) / Spent Coal at reduced opacity (empty slot)
- Character name — Primary typeface, largest size in column
- Empty slot: dashed border, no portrait, no name — signals the slot exists but is unfilled

**Zone 3 — Stats Block (per character)**
- 5 stat rows: HP_max, ATK, DEF, SPD, FLUX
- Each row: label (Primary, small) + **effective total** (Primary, large, prominent)
- If inheritance exists on this stat: base value shown in smaller secondary text directly beneath the effective total (e.g., "base 8")
- If no inheritance: effective = base; only the single number shown — no redundant split

**Zone 4 — Divider (per character)**
- Thin horizontal rule, Spent Coal color
- Appears only when at least one inheritance entry exists for this character
- Omitted entirely for characters with no inheritances

**Zone 5 — Inheritance Entries (per character)**
- One line item per Named Inheritance Object
- Format: "[Guest Name]'s Gift: +[N] [STAT]"
- Guest name in Flavor/Accent typeface (handwritten); stat and magnitude in Primary typeface
- Color: departed guest's accent color at 60% opacity — non-interactive, display-only
- Empty state (no inheritances): "No traces yet carried" — Primary typeface, Spent Coal color, reduced weight; no divider above it in this state

**Zone 6 — Navigation Hint Bar (bottom of screen)**
- Single line, small Primary typeface, Spent Coal color
- "Back  [Esc] / [B]" — keyboard and gamepad inputs shown side by side
- Active column highlighted with Amber Hearth on its header for keyboard/gamepad focus indication

### ASCII Wireframe

```
╔══════════════════════════════════════════════════════════════════════════════════╗
║                            ✦  PARTY RECORD  ✦                                   ║
╠════════════════════╤═════════════════════╤══════════════════════╤════════════════╣
║  [♦] CLAWD         │  [♦] NE             │  [♦] SETSUNA         │  [ ] ───────  ║
╠════════════════════╪═════════════════════╪══════════════════════╪════════════════╣
║                    │                     │                      │                ║
║  HP       120      │  HP        80       │  HP       100        │                ║
║  ATK       12      │  ATK       18       │  ATK       13        │                ║
║  DEF       16      │  DEF        8       │  DEF       12        │                ║
║  SPD       11      │  SPD       20       │  SPD       15        │                ║
║  FLUX      16      │  FLUX      11       │  FLUX      12        │                ║
║                    │          (base 8)   │                      │                ║
║                    │                     │                      │                ║
║  ─────────────     │  ───────────────    │                      │                ║
║  No traces yet     │  [Guest Name]'s     │  No traces yet       │                ║
║  carried.          │  Gift: +3 FLUX      │  carried.            │                ║
║                    │  ‹accent color›     │                      │                ║
║                    │                     │                      │                ║
╠════════════════════╧═════════════════════╧══════════════════════╧════════════════╣
║  Back  [Esc] / [B]                                                               ║
╚══════════════════════════════════════════════════════════════════════════════════╝
```

**Wireframe notes:**
- `[♦]` = portrait chip, Amber Hearth border; `[ ]` = empty guest slot, Spent Coal dashed outline
- Ne's column: effective FLUX 11 at full size; `(base 8)` in smaller secondary text beneath
- Clawd and Setsuna: single number per stat — no split, no divider (no inheritances)
- Ne's thin divider appears; Clawd's and Setsuna's omitted
- `[Guest Name]` = actual departed guest's name in Flavor/Accent typeface, guest accent color at 60% opacity
- Empty guest column shows slot structure only — no stats

---

## States & Variants

| State / Variant | Trigger | What Changes |
|---|---|---|
| Default — Exploration | Opened from party menu | HP shown as HP_max only (e.g., "120"). All stats at rest values. |
| Default — Combat Pause | Opened from pause menu during encounter | HP shown as HP_current / HP_max (e.g., "87 / 120"). Distinguishes live combat state from rested values. All other stats identical to exploration variant. |
| No Inheritance | Character has no Named Inheritance Objects | No divider. "No traces yet carried" in muted Spent Coal weight. Single number per stat (no base/effective split). |
| With Inheritance | Character has ≥1 Named Inheritance Object | Thin divider appears above inheritance entries. Affected stat rows show effective total + "(base N)" secondary text. Entries render in guest accent color at 60% opacity. |
| First Visit — Inheritance Highlight | Screen opened for the first time after the first inheritance lands; flag cleared after this visit | The inheritance entry receives a brief ambient glow (2–3 seconds, Amber Hearth or guest accent color pulse) drawing the player's eye on first open. Not an overlay or tooltip — just a warm light signal on the entry itself. Cleared permanently after one view. |
| Guest Slot — Empty | No guest in party | 4th column shows dashed Spent Coal border, no portrait, no name, no stats. Slot is visually present but clearly unfilled. |
| Guest Slot — Occupied | Guest character in party | 4th column renders identically to core character columns — portrait with guest accent border, name, all stats, inheritance entries if any. |

---

## Interaction Map

All display nodes set `mouse_filter = MOUSE_FILTER_IGNORE` — no hover states, no click targets. The screen is a document, not a form.

| Action | Keyboard | Gamepad | Feedback | Outcome |
|---|---|---|---|---|
| Exit screen | Escape | B / Circle | Nav hint bar briefly highlights | Returns to caller (party menu or pause menu) |

No other interactions exist on this screen. The player reads; the screen does not respond to cursor position or scrolling.

**Note for implementation**: If the stat block + inheritance entries for any character exceed the column height at 1080p, the column must be designed to fit within the fixed frame — not scroll. Content overflow is a layout constraint, not an interaction. Cap maximum inheritance entries per character at the GDD-stated maximum (one Named Inheritance Object per departing guest) and verify at design time that the worst-case content (5 stats + N inheritances) fits within the column.

---

## Events Fired

| Player Action | Event Fired | Payload |
|---|---|---|
| Exit screen (Back) | `ui_stat_screen_closed` | `{ context: "exploration" \| "combat_pause" }` |
| First inheritance highlight completes | `ui_first_inheritance_viewed` | `{ character_id: StringName }` — used to clear the first-visit flag |

No economy, save, or combat state is modified by any action on this screen.

---

## Transitions & Animations

**Screen Enter**: The parchment panel expands from center as if being laid on a surface — consistent with the art bible Section 7.1 directive ("panels slide into frame as though being laid on a surface"). Duration: ~0.25s. Easing: ease-out (starts fast, settles). The four columns populate simultaneously as the panel reaches full size — no per-column stagger.

**Screen Exit**: Reverse of entry — panel contracts back to center and disappears. Duration: ~0.2s (slightly faster than entry; the player is leaving, not arriving). Triggered immediately on Back input — no delay.

**First-Visit Inheritance Highlight**: After the screen reaches full size, a 0.4–0.6s settling pause occurs. Then the inheritance entry receives a warm ambient glow — a soft pulse in the departed guest's accent color (or Amber Hearth if the accent color is not yet defined at implementation time). Pulse cycle: ~1.5s, 2–3 cycles total, then fades. The glow does not move or animate the layout — it illuminates the entry in place.

**Reduced-motion consideration**: At Basic accessibility tier, no reduced-motion toggle is required. However, the unfurl animation (~0.25s, non-repetitive) falls well below photosensitivity thresholds. The inheritance glow pulse (1.5s cycle) should be reviewed against the Harding FPA standard — at fewer than 3 flashes per second it is safe; verify during implementation.

**No other animations**: Stat values are static — no counting-up number animations, no bar fills. The screen displays the current state instantly; visual change is reserved for the inheritance highlight only.

---

## Data Requirements

| Data | Source System | Read / Write | Notes |
|---|---|---|---|
| Character display name | `CharacterData.display_name` (via PCM) | Read | Used in column header |
| Portrait reference | `CharacterData` resource (via PCM) | Read | 24×24px chip — art asset path on CharacterData |
| Base stats (HP_max, ATK, DEF, SPD, FLUX) | `CharacterData` (via PCM `get_slot()`) | Read | Base values only; screen computes effective total display from base + inheritances |
| Named Inheritance Objects | `CharacterData.inheritances: Array[NamedInheritanceObject]` | Read | Name, stat modified, magnitude per entry |
| Guest accent color | `CharacterData` (guest entry) | Read | Accent color stored on guest's CharacterData; used for inheritance entry rendering and guest portrait border |
| HP_current (combat pause variant only) | Timing Combat System / HP tracking | Read | Only surfaced when screen is opened from combat pause context. Not available from CharacterData alone — TCS owns mutable HP. Architecture concern: PCM/CharacterData holds HP_max (static); HP_current is combat-state data owned elsewhere. |
| Context flag (exploration vs. combat_pause) | Caller (party menu / pause menu) | Read | Passed as parameter when screen is opened; determines HP display mode |
| First-visit inheritance flag | StoryState / save data | Read + Write | One boolean per character: "has player viewed this character's first inheritance entry?" Written `true` when `ui_first_inheritance_viewed` fires. Persists across sessions. |

**Architecture flag**: The `HP_current` data dependency introduces a coupling point between the stat screen and the Timing Combat System. The stat screen must not own or cache HP_current — it should request it from TCS at open time (read-only snapshot). Ownership of HP_current must be confirmed with the TCS ADR before implementation.

---

## Accessibility

**Tier**: Basic (committed in `design/accessibility-requirements.md`)

**Keyboard navigation**: The screen has one interaction — Back (Escape). No focus traversal within the screen is required (passive read, no interactive elements). Keyboard users can open and exit the screen without a mouse.

**Gamepad navigation**: D-pad and face buttons fully supported. B/Circle exits. No analog input required. Consistent with partial gamepad support commitment in `technical-preferences.md`.

**Text readability**: All stat labels and values target 24px minimum at 1080p (menu standard per accessibility requirements). "No traces yet carried" and inheritance entry text must meet this minimum — verify during implementation at 1x pixel-art render.

**Color-as-only-indicator audit**:
- Inheritance entries render in guest accent color — but the guest name and stat label are always present as text. Color distinguishes the entry visually; text communicates the content. ✓ Non-color backup present.
- No other color-coded information on this screen.

**No motion sickness risk**: The unfurl animation (~0.25s, non-repetitive) and inheritance glow pulse (1.5s cycle, 2–3 repetitions) are both within safe Harding FPA thresholds. No strobe or rapid flash.

**Out of scope at Basic tier**: Screen reader annotation (Comprehensive tier); colorblind mode (Standard tier).

---

## Localization Considerations

**Longest text elements**:
- Stat labels (HP, ATK, DEF, SPD, FLUX) — 4 characters max in English; translation to e.g. German or French may expand abbreviations. **Recommendation**: keep stat labels as fixed 4-character abbreviations across all locales rather than translating to full words — consistency with combat HUD requires matching labels everywhere.
- Inheritance entry format: "[Guest Name]'s Gift: +[N] [STAT]" — guest names are proper nouns (not translated); the possessive construction and "Gift" word will expand in some languages. Layout-critical: this text must fit on a single line within the column width. **Flag as HIGH PRIORITY** for localization engineer — 40% text expansion from English to German could push this line to two lines and break the column layout.
- "No traces yet carried" — flavor text, muted weight. Can wrap to two lines without breaking layout. Lower priority.

**Number formatting**: Stat values are integers (1–99). No locale-specific formatting required.

**Right-to-left languages**: Not in scope for Episode 1 (PC/Steam, no RTL locale targets identified). Flag for future consideration if Arabic or Hebrew localization is added.

---

## Acceptance Criteria

- [ ] **AC-1 (Performance)** — The stat screen opens within 100ms of the trigger input when accessed from the party menu during exploration. The unfurl animation begins within one frame of the input.
- [ ] **AC-2 (Navigation — entry)** — The stat screen is accessible from both the party menu (exploration state) and the pause menu (combat state). Opening from either context displays the correct HP mode: HP_max only (exploration) vs. HP_current / HP_max (combat pause).
- [ ] **AC-3 (Navigation — exit)** — Pressing Escape (keyboard) or B/Circle (gamepad) closes the stat screen and returns to the exact screen that opened it (party menu or pause menu). No other screen state changes.
- [ ] **AC-4 (Inheritance display)** — Given a `CharacterData` with one `NamedInheritanceObject` {name="[Guest Name]", stat=FLUX, magnitude=3} and base FLUX=8, the stat screen shows: FLUX effective total 11 (large), "(base 8)" in secondary text, a thin divider line, and "[Guest Name]'s Gift: +3 FLUX" in the guest accent color at approximately 60% opacity. Base and effective total are simultaneously visible.
- [ ] **AC-5 (Empty inheritance state)** — Given a `CharacterData` with no `NamedInheritanceObject` entries, the stat screen shows "No traces yet carried" in muted text weight with no divider line. A single number appears per stat row (no base/effective split).
- [ ] **AC-6 (First-visit highlight)** — On the first opening of the stat screen after a Named Inheritance Object has been applied to a character, the inheritance entry displays a warm glow pulse beginning approximately 0.5s after the screen finishes opening. The glow does not repeat on subsequent openings of the stat screen within the same session or after save/reload.
- [ ] **AC-7 (Accessibility — keyboard/gamepad)** — A QA reviewer using only keyboard or gamepad (no mouse) can open the stat screen from the party menu, read all stat values for all three core characters, and exit back to the party menu. No interaction requires mouse hover or click.

---

## Open Questions

| # | Question | Owner | Resolution |
|---|---|---|---|
| OQ-1 | Who owns HP_current during combat? The stat screen needs a read-only snapshot of HP_current for the combat pause variant, but CharacterData only holds HP_max. The Timing Combat System ADR must confirm how HP_current is accessed by non-combat systems. | Architecture / TCS ADR | Unresolved |
| OQ-2 | Where is the guest accent color stored on CharacterData? The art bible requires it for inheritance entry rendering and guest portrait borders. If CharacterData does not have an `accent_color` field, either the field must be added or the color must be resolved at display time from a separate registry. | Character Stats & Growth GDD / ADR-0001 | Unresolved |
| OQ-3 | Maximum number of Named Inheritance Objects per character — the GDD states one per departing guest. Episode 1 has one guest. If Episode 2+ adds more guests, worst-case column height must be re-verified at 1080p. Flag for layout review before each new guest is added to production. | Producer / UX review | Unresolved — defer to future episode scoping |

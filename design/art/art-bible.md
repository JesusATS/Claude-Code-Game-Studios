# Art Bible: Lux Aeterna

*Created: 2026-04-21*
*Status: Approved*
*Engine: Godot 4.6 / GDScript / 2D Pixel Art*

**AD-ART-BIBLE Sign-Off**
> Verdict: **APPROVED**
> Date: 2026-05-07
> Review mode: Lean (AD-ART-BIBLE director gate skipped per `production/review-mode.txt`)
> All 9 sections present and complete. Visual identity, mood grammar, shape language, color system, character direction, environment language, UI direction, asset standards, and reference direction are all authored and internally consistent. No blocking issues identified.

---

## 1. Visual Identity Statement

### One-Line Visual Rule

> **Every frame must answer: where is the warmth, and what is it fighting against?**

This is the resolution tool for every visual ambiguity on the project. When two designs are on the table, ask the question. The design that cannot answer it is not finished. "Frame" means any composited visual output: a scene, a screen, a UI state, a cutscene still.

### Principle 1: Light Earns Its Real Estate

Warm light sources are never decorative. Each one must have a diegetic reason — a lantern, a fire, a window, a person — that an artist can name out loud.

*Design test*: When two environment layouts are ambiguous in mood, choose the one where the warm light source has a named, in-world reason over the one where warmth is ambient fill. Ambient warmth flattens the contrast this game lives in.

*Pillar*: **Story Earns Its Emotion** — warmth signals emotional safety. Placed intentionally, the player learns to read it as earned. Placed freely, it becomes wallpaper.

### Principle 2: Silhouette Carries the Feeling

Every character sprite must communicate a distinct emotional state from its silhouette alone, at 64×64 pixels or smaller, before color or internal detail is applied.

*Design test*: When a character animation pose is ambiguous between two options — one with a clearer silhouette shape, one with richer internal detail — choose the clearer silhouette. This test applies to guest characters first: if a guest's silhouette cannot be distinguished from a core companion at thumbnail scale, the design has failed before the player has a chance to mourn their departure.

*Pillar*: **The Company Changes You** — emotional weight at a guest's departure requires that the player recognized them as a distinct presence from the moment they arrived. Legibility is the precondition for loss.

### Principle 3: The World Is Older Than the Visit

Every explorable environment must contain at least one visual element — wear patterns, remnants, layered architectural periods, displaced objects — that communicates history predating the player's arrival.

*Design test*: When a tileset or room layout is ambiguous between a clean version and a worn or layered version, choose worn. Clean reads as constructed for the player. Worn reads as discovered by the player. This principle extends to UI: menus, maps, and status screens should feel like artifacts of the world's record-keeping, not a HUD dropped over the world.

*Pillar*: **The World Has Memory** — a world that shows its age before the player arrived makes the player's choices feel consequential rather than the first marks on a blank slate.

### Binding Rule: Guest Color Persistence

Guest characters are assigned a unique accent color at introduction. That color persists in the UI — ability lists, status screens, party display — after they leave. This is not decorative polish. It is Principles 1 and 3 applied simultaneously at the interface layer: the color is a warm light source with a named diegetic reason (this person was here), and it is environmental history that predates the current moment (they are already gone). Every artist and programmer touching the UI must understand this before touching those screens.

---

## 2. Mood & Atmosphere

Each entry defines the emotional target and visual character of a distinct game state. Read each entry as a brief for a lighting artist: the adjectives are directives, not suggestions. States must be distinguishable in a thumbnail. When in doubt, return to the wall rule: identify the warmth source and identify what resists it.

### 1. World Exploration (Between Encounters)

**Primary Emotion**: Earned belonging — the player is a traveler in a world that existed before them. Not wonder at spectacle but quiet recognition.

**Lighting**: Warm dominant. Amber, ochre, late-afternoon gold. Low-to-medium contrast; diffuse light distributed across diegetic sources (lanterns, hearths, bioluminescent flora, windows). Default to golden hour / early evening.

**Atmosphere**: Lived-in, amber-breathed, quietly worn, traversable, unhurried.

**Energy**: Contemplative.

**Distinguishing element**: A mid-ground environmental light source with a visible reason for existing — a lit window where someone is home, a lantern hung at a crossroads, a fire already burning. The shadow it casts must be readable.

---

### 2. Combat — Normal Encounter

**Primary Emotion**: Tense readiness. Not fear — competence under pressure. The player has agency; the encounter is a problem to be solved with rhythm.

**Lighting**: Cool-shifted from exploration. Warm sources narrow and concentrate (one torch, one spell-glow); midtones shift toward slate and steel blue. Medium-high contrast; shadows deepen beneath combatants.

**Atmosphere**: Contracted, alert, crisp-edged, focused, pressurized.

**Energy**: Measured.

**Distinguishing element**: The combat floor. In exploration it carries ambient warmth; in normal combat it shifts to a neutral-dark that grounds all characters as silhouettes. Its temperature tells the player the rules have changed.

---

### 3. Combat — Boss / Significant Encounter

**Primary Emotion**: Warmth under siege. The threat is present, named, and pushing. The player's light is under pressure.

**Lighting**: Cold dominant. Deep blue-violet, near-black, or sickly green-black depending on antagonist color language. Warm sources reduce to a single, small, identifiable point belonging to the party. High contrast — the highest contrast setting in the game.

**Atmosphere**: Besieged, singular, cold-encroaching, weightful, clarifying.

**Energy**: Charged (escalating toward Frenetic at final phases if the game supports phase transitions).

**Distinguishing element**: A single warm light source that belongs to the party — not the environment. Held torch, guardian spell, glowing emblem. Small relative to the surrounding dark. The ratio of warmth to cold is the worst it has ever been.

---

### 4. Story Cutscene / Dialogue

**Primary Emotion**: Earned attention. Dialogue is not a pause — it is the game. The lighting must signal that something true is being said.

**Lighting**: Highly variable and scene-specific. Color temperature is determined per scene by emotional content: reconciliation → warm; betrayal → cool or desaturated; grief → muted, directionless. Medium contrast to keep character expression readable. High-contrast shadow reserved for moments of dramatic revelation within a scene.

**Atmosphere**: Intentional, still, charged-with-subtext, character-lit, honest.

**Energy**: Still (rising to Contemplative for action-adjacent scenes).

**Distinguishing element**: Scene temperature matches scene emotion. This is the only game state where the lighting brief is written per scene, not globally. Every cutscene must have a named time, place, and emotional temperature.

---

### 5. Guest Character Arrival

**Primary Emotion**: Expansion. A new color enters the warmth — not replacing what was there, but adding to it. Cautious welcome.

**Lighting**: Warm base with the guest's accent color introduced as a secondary light source. The guest's color appears in the environment before the UI — a reflection, a glow, edge-lit particles. Low-medium contrast; one of the warmest states in the game.

**Atmosphere**: Expanding, tentatively warm, color-introducing, open-spaced, cautiously bright.

**Energy**: Contemplative.

**Distinguishing element**: The moment the guest's accent color first appears in the environment — before the UI registers it. A flower, a reflection in water, light through stained glass. The world acknowledges them before the party does.

---

### 6. Guest Character Departure

**Primary Emotion**: Present absence. The guest is gone but their color is not. The feeling of a room after someone has left it, where their presence is still legible in the arrangement of things.

**Lighting**: Warm base unchanged, but the guest's environmental accent color is gone. Base palette identical to pre-arrival exploration — the difference is felt, not shown explicitly. Slightly elevated contrast from normal exploration; edges crisper, shadows a degree deeper.

**Atmosphere**: Contracted, quietly altered, warm-but-diminished, retrospective, un-erased.

**Energy**: Still.

**Distinguishing element**: The guest's accent color, now present only in the UI layer — party status, ability slots, lingering effect icons. The environment no longer carries it. The UI carries it instead.

---

### 7. Victory (Combat Won)

**Primary Emotion**: Relief before triumph. The warmth comes back — not explosively, but as a return. The party's light re-expands. The mood is exhale, not celebration.

**Lighting**: Returns to warm. The cold that dominated combat recedes visibly — a temperature shift, not a flash effect. Contrast drops from combat's medium-high to exploration's low-medium. Shadows soften.

**Atmosphere**: Exhaling, re-expanding, warmth-returning, quiet-earned, recovering.

**Energy**: Contemplative. The game does not scream victory.

**Distinguishing element**: The floor temperature shift. The same bellwether that signaled combat (the darkened floor) reverses — warm light reclaims the ground plane. The characters are standing on warmth again.

---

### 8. Defeat

**Primary Emotion**: Extinguishment, not punishment. The warm source failed — not the player, the light. Defeat is the world going dark. Solemn, not humiliating.

**Lighting**: Cold takes the frame. The last warm source fades in sequence — not all at once. The final image is near-monochrome, cool-tinted. Starts high contrast (same as boss combat), resolves to low — darkness fills the frame uniformly.

**Atmosphere**: Solemn, dimming, unhurried, non-punitive, ember-holding.

**Energy**: Still.

**Distinguishing element**: The residual ember — one warm pixel cluster that persists after all other sources have gone dark. It must be visible in the defeat screen's final state. The warmth is not destroyed; it is waiting.

---

### 9. Main Menu

**Primary Emotion**: The threshold before the story begins. Anticipatory stillness — the player is outside the world, about to enter it.

**Lighting**: Warm at distance, cool at frame edge. The composition draws the eye toward an interior warm source — a lit doorway, a campfire on a hilltop, a lantern-lit road — from a cooler vantage point. Medium contrast; detail at the warm source, suggestion at the periphery.

**Atmosphere**: Threshold-standing, distant-warm, edge-cool, invitation-lit, still-before-motion.

**Energy**: Contemplative.

**Distinguishing element**: A warm light source at optical center — humble and human-scaled. A candle in a window, a fire in a courtyard, a lantern above a door. Not a sunset, not a magical phenomenon — a made light. Someone is home.

---

### 10. Pause / Status Screen

**Primary Emotion**: Reflective inventory. The player has stepped outside the moment to take stock. Not interruption — parenthesis.

**Lighting**: Desaturated version of the current state's palette — background world visible but muted, as if seen through frosted glass. UI layer uses cool-neutral tones with warm accents from active and departed guest colors.

**Atmosphere**: Suspended, inventory-lit, guest-color-forward, still-world-behind, reckoning.

**Energy**: Still.

**Distinguishing element**: Guest accent colors in the party status display — the warmest, most saturated elements on the screen. Departed guests' colors appear at slightly reduced opacity. Present but faded. The screen is a record of who has mattered.

---

### State Contrast Summary

| State | Temperature | Contrast | Energy | Warmth Source |
|---|---|---|---|---|
| World Exploration | Warm | Low-Medium | Contemplative | Environmental (diegetic, distributed) |
| Combat — Normal | Cool-shifted | Medium-High | Measured | One source (narrowed) |
| Combat — Boss | Cold dominant | High | Charged | Party-held (single, small) |
| Story Cutscene | Scene-specific | Medium | Still | Scene-motivated |
| Guest Arrival | Warm + accent | Low-Medium | Contemplative | Base warm + guest color (pre-UI) |
| Guest Departure | Warm (contracted) | Slightly elevated | Still | Base warm only (accent withdrawn) |
| Victory | Warm returning | Low-Medium | Contemplative | Floor warmth restored |
| Defeat | Cold → dark | High-to-Low | Still | Residual ember only |
| Main Menu | Warm at distance | Medium | Contemplative | Humble made-light at center |
| Pause / Status | Desaturated world, warm UI | Low (bg) / High (UI) | Still | Guest accent colors |

---

## 3. Shape Language

Shape language in Lux Aeterna is not decoration — it is information. Silhouettes must do double work: communicate character emotional state and faction legibility at 64×64px, and communicate environmental age and cultural history at scene scale. Every shape decision derives from the one-line rule: the viewer should be able to answer "where is the warmth, and what is it fighting against?" by reading silhouettes alone before color resolves.

### 3.1 Character Silhouette System

Each character archetype occupies a distinct silhouette territory. These territories must not overlap. If two characters in the same scene share a silhouette territory, one of them needs revision.

| Archetype | Silhouette Territory | Shape Vocabulary | Emotional Read |
|---|---|---|---|
| Core party member | Compact, anchored, vertical center of gravity | Rounded shoulders, stable base, internally complex | Presence — someone who has been here before |
| Guest character | Asymmetric, one dominant accent shape | Unique element (cloak edge, wing, held object) that appears nowhere else in party | Arrival — something new has entered the frame |
| Named NPC | Wider or taller than party average, shape implies role | Occupation shapes (broad merchant, hunched elder, rigid guard) | Context — they belong here |
| Generic NPC / crowd | Simple, low-detail, no strong anchor | Soft, repetitive, receding | World texture — fills space without demanding attention |
| Enemy (Standard) | Sharp and angular; interrupts party's rounded language | Pointed, edged, visually aggressive — clear directional threat | Danger — wrong shape for this space |
| Enemy (Elite / Named) | Larger sharp mass, dominant and visually loud | Heavy, angular, hierarchically larger | Power — this one is worse |
| Boss | Overwhelming silhouette mass OR near-empty (presence through absence) | Either violation of spatial norms OR hollow/minimal | Scale mismatch — the player's categories break here |

**The black rectangle test**: Convert any sprite to solid black and verify archetype is identifiable at 64×64px. If not, internal detail is carrying work the silhouette should be doing.

#### Guest Character Silhouette Rule

Guest characters introduce a single asymmetric "anchor shape" — one element that appears nowhere else in the party's silhouette vocabulary. This anchor shape makes the guest instantly readable as "other" in party scenes and provides a visual hook for the accent color. When the guest departs, the accent withdraws from the world to UI — but the player's memory of the anchor shape creates the felt absence.

*Pillar*: **The Company Changes You** — the guest's shape briefly colonizes the party's visual grammar. After departure, the player's eye expects something that is no longer there.

### 3.2 Environment Geometry

The world of Lux Aeterna is built on **modified organic geometry** — structures with architectural origins (arches, walls, towers) worn, grown-over, settled, and repaired into something more curved and irregular than the builders intended. Not ruin — accumulation. The world has continued without stopping to be consistent.

**Primary shape vocabulary**: Irregular curves and soft angles — worn stone, root-heaved floors, settled doorframes.
**Secondary**: Rectilinear structures visible underneath (the original intent showing through).
**Forbidden in exploration**: Perfect right angles at human scale, pristine surfaces, symmetrical facades.

**Deliberate exception**: Interiors maintained by power (throne rooms, vaults, boss arenas) may use harder geometry — but only as contrast. Power maintains its angles. History softens them.

**Layering rule** — every environment must have three depth layers with distinct shape behavior:
- **Foreground**: Softest, most organic, most worn. Roots, cloth, broken edges.
- **Mid ground**: Mixed — worn surface with underlying structure visible. (Player space.)
- **Background**: Most geometric and architectural. The original intention reads clearly because it has been observed least.

*Pillar*: **The World Has Memory** — the environment's geometry is its autobiography. Every soft edge is a date.

### 3.3 UI Shape Grammar

The UI uses a **parchment and aged metal aesthetic** — richly decorated, with illustrated borders, aged paper surfaces, and ornamental accents that feel like artifacts from the world's culture. This is not generic fantasy scrollwork; every decorative element should feel like it was made by a specific craftsperson in this world, with a specific material logic.

**Shape vocabulary for UI**:
- Panel frames: Illustrated borders with controlled ornamentation — aged ink on parchment, worn metal bezels
- Buttons / primary actions: Clearest, most geometric element within the ornate frame — the functional core inside the decorative shell
- Decorative containers: Higher visual complexity; flavor and world-building through the ornamentation itself
- Scrollwork and corner accents: Present but bounded — ornament serves readability, not the reverse

**What the UI is not**: Generic JRPG scrollwork where decoration is an afterthought. Every border motif should relate to the world's visual culture — recurring symbols, architectural patterns from in-game locations, cultural iconography from the world of Lux Aeterna.

**Guest accent color in UI**: When a guest's accent color persists in the UI after departure, it inhabits a specific bounded element that echoes the guest's anchor shape — within the ornate frame, not replacing it. The accent does not flood the UI; it occupies a single, legible slot.

*Pillar*: **Story Earns Its Emotion** — the UI is a cultural artifact of this world, not a floating overlay. It earns emotional weight by belonging.

### 3.4 Hero vs. Supporting Shapes

**Hero shapes** (core party, bosses, key guests): High silhouette entropy — many directional changes in outline, visual complexity that demands the eye's attention.

**Supporting shapes** (generic NPCs, props, standard enemies): Low silhouette entropy — smooth outlines, predictable repetition, easy to look past.

**Focal hierarchy rule**: In any scene, the highest-entropy silhouette should belong to the most narratively important element. If an environment prop has higher silhouette entropy than the party member beside it, the prop needs revision.

---

## 4. Color System

Color in Lux Aeterna is a semantic system, not atmospheric decoration. Every color means something, and that meaning is consistent. The warmth/cold grammar from the visual identity statement defines the structural logic; the semantic vocabulary below defines every specific use.

### 4.1 Primary Palette

Seven named colors form the structural palette. All other colors are derived from or subordinate to these seven.

| Name | Approximate Hue | Role |
|---|---|---|
| **Amber Hearth** | Warm amber-orange | Safety, presence, earned warmth — the color the one-line rule asks "where is it?" |
| **Deep Linen** | Warm off-white, desaturated gold | Neutral warmth, world at rest, primary UI surface |
| **Spent Coal** | Very dark warm brown-black | Deep shadow with warmth's memory; never pure black |
| **Cold Slate** | Desaturated blue-grey | Ambient threat, tension not yet active |
| **Siege Blue** | Deep cold blue, near-black | Active threat, boss combat dominant, cold at full force |
| **Danger Red** | Saturated warm red | Damage, status effects, enemy-inflicted conditions, critical warnings |
| **Victory Gold** | Bright warm gold, saturated | Warmth reasserting after conflict; relief, exhale, preservation |

**Residual Ember** (defeat state): A deep, dark red-orange — distinct from Danger Red by being far less saturated and much darker. It is not a warning; it is an ember. Used only in defeat sequences for the surviving warmth element. Its darkness separates it from Danger Red's hot warning register.

**World meaning of each color:**
- Amber Hearth: *Someone tended this fire.*
- Deep Linen: *This is how the world looks when nothing remarkable is happening.*
- Spent Coal: *This place had warmth. It does not now.*
- Cold Slate: *Something here resists warmth.*
- Siege Blue: *The warmth is losing here.*
- Danger Red: *This will hurt you.*
- Victory Gold: *Something was preserved.*

### 4.2 Semantic Color Vocabulary

| Color / Family | Meaning | Forbidden Uses |
|---|---|---|
| Amber Hearth (warm amber) | Safety, inhabited space, source of warmth | Decoration, ambient fill without a named diegetic source |
| Cold Slate / Siege Blue | Threat, opposition, the cold that fights warmth | Relaxed exploration environments; anything that should feel safe |
| Danger Red | Damage, status effects, enemy conditions, critical warnings | Persistence or survival metaphors (those use deep Residual Ember) |
| Deep warm shadow (Spent Coal) | Comfortable darkness, mystery with warmth's memory | Pure flat black backgrounds |
| Deep cold shadow (Siege Blue field) | Hostile, abandoned, cold without memory | Warm exploration spaces |
| Victory Gold | Warmth reasserting after conflict | Any conflict-active moment; wealth or reward signaling |
| Residual Ember (deep dark red-orange) | Defeat with dignity; the ember that didn't go out | General danger warnings (Danger Red carries that); combat-active states |

**What red communicates**: Danger Red = damage, status conditions, enemy-inflicted harm. Saturated, hot, immediate. Distinct from the deep, dark Residual Ember of defeat.

**What blue communicates**: Cold Slate (mid) = ambient threat. Siege Blue (deep) = crisis. Blue signals what is fighting warmth.

**What gold communicates**: Amber Hearth = warmth present. Victory Gold = warmth returned. Gold does not signal wealth or reward unless those things are also emotionally warm.

**True black (`#000000`)**: Permitted only as letterbox / border / engine default. If neutral black appears in a game frame, it is an asset error. All in-game darks trend toward Spent Coal.

**True white**: Appears only as light emission — specular, candle flicker, direct spark. Non-emissive white in an asset is an error.

### 4.3 Per-Area Color Temperature Rules

Each area has a Warmth Register (dominant warm color) and a Threat Register (dominant cold), chosen from the palette. The registers define the specific hues; semantic meaning remains constant.

The one-line rule must always be answerable regardless of area: "where is the warmth, and what is it fighting against?" — even if the answer is "warmth is very far away."

| Area Type | Warmth Register | Threat Register | Environmental Character |
|---|---|---|---|
| Village / Settlement | Amber Hearth dominant | Cold Slate accent only | Warmth is winning here |
| Wilderness / Road | Deep Linen ambient | Cold Slate rising | Warmth is ambient, threat is present |
| Dungeon / Ruin | Residual Ember only | Cold Slate to Siege Blue | Warmth is a survivor, not a resident |
| Boss Arena | No environmental warmth | Siege Blue dominant | Warmth must be brought in by the player |

*Note*: Specific area names and world map structure are pending narrative design. Update this table when world areas are defined via `/design-system` or `/map-systems`.

**Biome secondary colors**: Areas may use secondary accent colors (forest green, desert ochre) but these must be subordinate to the Warmth/Threat registers. A biome accent must not compete with Amber Hearth for the warmth signal.

### 4.4 UI Palette

| Element | Color |
|---|---|
| UI surface (parchment) | Deep Linen |
| UI panel depth / shadow | Spent Coal |
| Active / player-controlled element | Amber Hearth |
| Threat indicator | Cold Slate |
| Critical / enemy turn | Siege Blue |
| Damage / danger indicator | Danger Red |
| Victory / resolution state | Victory Gold |

**What the UI does not use**: Residual Ember (reserved for defeat state only); Victory Gold during any conflict-active moment.

#### Guest Accent Color System

Guest characters bring a color outside the primary seven. Each guest accent color:
- Is unique — no two guests share an accent
- Is introduced first in the environment (a lantern color, fabric dye, material they carry) before appearing in UI
- Participates in the warmth/cold grammar — it must read as warm-adjacent or cool-adjacent, never neutral
- **May exceed the world's saturation range** — guests arrive from elsewhere and can carry a vividness the established world does not yet have
- Must not read as Amber Hearth (replaces the world's safety signal) or Siege Blue (reads as boss-level threat) or Danger Red (reads as damage)

**Persistence rule**: After departure, the accent appears in exactly one bounded UI location — the companion log slot for that guest. It does not spread. Confinement to a single space is the visual grammar of departure: present in record, absent from world.

### 4.5 Colorblind Safety

No semantic distinction may rely on color alone. Every color signal below must have at least one shape or icon backup.

| Semantic Signal | Primary Color | Shape Backup | Icon Backup | Sound Backup |
|---|---|---|---|---|
| Safety / inhabited | Amber Hearth | Circular or domed shapes near source | Flame/glow icon on diegetic sources | Ambient life (crackling, breath) |
| Active threat | Cold Slate / Siege Blue | Angular enemy silhouettes intruding frame | Enemy archetype shape | Dissonant ambient shift |
| Damage / danger | Danger Red | Screen edge flash or vignette pulse | Damage number / hit indicator | Impact/hurt sound |
| Player agency (UI) | Amber Hearth | Highest border weight element | Cursor / active marker | Selection confirm tone |
| Enemy turn (UI) | Siege Blue | Directional indicator distinct from player elements | Chevron pointing at player | Low pulse tone |
| Guest memory (UI) | Guest accent | Guest anchor shape (per guest spec) | Companion log icon | Guest thematic audio cue |
| Defeat state | Spent Coal + Residual Ember | Frame compression / vignette closing | None — structural | Music shift |
| Victory state | Victory Gold | Frame opening / vignette lifting | None — structural | Music shift |

---

## 5. Character Design Direction

### 5.1 Core Party Visual Archetype

The three core companions share a visual grammar that communicates one thing before the player reads a single line of dialogue: **these people have been somewhere together before you met them.** They are not strangers assembling; they are a formation already in progress.

**Unifying visual principles for the core trio:**

- **Compact, anchored, internally complex.** Each sprite occupies a tightly bounded silhouette with a low center of gravity. The complexity is inside the boundary, not outside it. This is the visual language of people who have learned not to take up more space than they need.
- **Worn but maintained.** Clothing and gear shows use history — faded hems, repaired stitching, softened leather — but is cared for. This distinguishes them from enemies (wear reads as damage/aggression) and from NPCs (wear reads as station). The core party's wear reads as *chosen continuity*: they know how to take care of things.
- **Warm-anchored palette.** Each core companion carries Amber Hearth as a structural element in their costume — not as an accent but as a load-bearing color. In the warmth/cold grammar, the core party *is* the warmth. Their costumes must make this legible at a glance in cool-shifted combat environments.
- **Deliberate internal differentiation.** Within the shared grammar, the three companions occupy distinct silhouette territory: one with vertical emphasis, one horizontal, one mid-range. Height, mass distribution, and primary shape vocabulary must vary enough that the trio reads as three distinct presences even as solid black silhouettes side by side.

*Pillar*: **Story Earns Its Emotion** — the companions' visual cohesion does not need dialogue to establish. The player should feel they interrupted something already in progress.

### 5.2 Distinguishing Feature Rules by Archetype

| Archetype | Costume Language | Color Rule | Detail Density | First-Glance Signal |
|---|---|---|---|---|
| Core party | Worn, maintained; functional not decorative | Amber Hearth as structural (load-bearing) element | High internal complexity, bounded silhouette | Coherence — they feel like a set |
| Guest character | One element with no analogue in the party's vocabulary | Unique accent color in anchor shape; may exceed world saturation | Distinct internal language from party — intentionally foreign | The element that doesn't match |
| Named NPC | Role-legible silhouette; costume reflects occupation/station/faction | No Amber Hearth as costume element; no guest accent colors | Medium — enough to read role, not enough to demand attention | What they do, not who they are |
| Generic NPC / crowd | Simplified, receding | Pulls from Deep Linen and neutral mid-tones; no semantic colors | Low — supporting texture, not character | Passes the eye |
| Standard enemy | Angular, aggressive, reads as intrusion | Cold Slate to Siege Blue dominant; Danger Red for active threat | Medium — threat legibility, not individual identity | Wrong shape for this space |
| Elite / named enemy | Larger, visually louder | Colder palette, higher contrast | Medium-High — distinct within faction | This one is worse |
| Boss | Overwhelming mass OR near-empty (presence through absence) | Outside established grammar | Either extreme | The player's categories break |

**The costume vocabulary rule**: An element appearing on the core party must not appear on enemies. An element on a guest must not appear on the party before the guest arrives.

**The anchor shape guarantee**: The anchor shape is a guest's only guaranteed costume element — everything else varies per character, but the anchor shape survives every sprite LOD and every silhouette test.

*Pillar*: **Rhythm Is Respect** — in combat, archetype must be readable instantly. Visual ambiguity breaks rhythm.

### 5.3 Expression and Pose Style Targets

**Default register: understated, posture-primary.**

The game's emotional register is quiet. A character showing grief does not have visible tears and an open mouth — they have a changed posture: weight shifted, shoulders slightly inward, eyes directed at a specific point that is not the thing being looked at. The grief is in the geometry, not the features.

**At game-camera distance, expression is posture.** The sprite at play resolution cannot resolve facial microexpression. Emotional state at this scale lives in:
- Silhouette change from idle (lean, reach, collapse, guard)
- Center of gravity shift
- Arm/hand position relative to body
- Directional orientation (toward vs. away)

**At portrait/close-up resolution, expression resolves into face.** Even here: one prominent signal, not a composed face. A portrait showing grief communicates through one element — brow angle, eye direction, or mouth position — not all three simultaneously. Overcrowded expression reads as performance.

**Exceptions — Overtly Expressive Characters**: Individual characters may be designated "overtly expressive" in their character design spec as a deliberate characterization choice (e.g., a comedic companion, a theatrical villain, a character whose excess is the point). These exceptions must be:
- Explicitly noted in the character's design brief
- Approved by the creative director
- Consistent across all appearances for that character (expressiveness is their register, not a random variation)

An overtly expressive character's exaggeration must feel intentional from the first encounter — not like a different art standard was applied. Their expressiveness is part of their identity, not an art error.

**Animation philosophy: held moments over fluid motion.** Combat and exploration animations prioritize the **held pose** — the apex frame — over smooth transitions. This is consistent with the game's contemplative pacing. The held posture is the art; the transition is secondary.

**Environmental cues carry more weight than character expression.** The mood system (Section 2) defines the scene's emotional state through lighting and atmosphere. Character expressions confirm rather than establish emotion.

*Pillar*: **Story Earns Its Emotion** — earned emotion is restraint that finally breaks. If the character art performs continuously and visibly, the moments of genuine weight have nowhere to land.

### 5.4 Guest Character Design Protocol

Guests are not supporting cast. Each guest is a story event with a visual presence the player will miss. Every item in this checklist is blocking — nothing is optional.

1. **Narrative brief first, visuals second.** Who is this person, what is their relationship to the party, what is the nature of their departure, and what does the player lose when they go? Visual decisions serve the brief.
2. **Define the anchor shape.** One silhouette element that appears nowhere in the existing party or NPC vocabulary. Must: survive the black rectangle test at 64×64px; have a diegetic reason to exist; house the accent color. The anchor shape is established before any other costume detail.
3. **Define the accent color.** A color not held by any existing guest or primary palette color. Must: live in the anchor shape; participate in the warmth/cold grammar (warm-adjacent or cool-adjacent, never neutral); pass adjacency tests (not Amber Hearth, Siege Blue, or Danger Red); be named; may exceed world saturation range.
4. **Introduction placement.** Coordinate with environment/level design to place the accent color in the environment before it appears in the UI — a material, light source, reflection, or object predating the guest's arrival.
5. **Silhouette test against full current roster.** Render as solid black alongside every current party member and guest. Must be immediately distinguishable from all.
6. **Emotional archetype assignment** *(proposed — pending narrative design sign-off)*:
   - *The Burden* — carrying something the player does not yet understand
   - *The Contrast* — their presence reveals something about the core party by opposition
   - *The Mirror* — their story reflects the player's trajectory
   - *The Loss Already Happened* — their departure was inevitable from the moment they arrived
7. **Departure state specification.** The environment artist who staged the introduction placement also specs the post-departure version of that scene — the element the color lived in, with the color gone. This is part of the guest's visual design, not an afterthought.
8. **UI persistence slot.** Specify the single bounded UI element where the accent color persists after departure. Must echo the anchor shape. Must not expand when occupied.

*Pillar*: **The Company Changes You** / **Scope Is Story** — this protocol exists because guests are expensive to design correctly and cheap to design incorrectly. A guest with no anchor shape and no departure spec costs production time and gives the player nothing to mourn.

### 5.5 LOD Philosophy

| Zoom Level | Primary Channel | What Must Survive | What Can Be Sacrificed |
|---|---|---|---|
| System UI icon (16–32px) | Anchor shape only | Silhouette of anchor shape; accent color block | All internal detail, face |
| Game camera (64–96px) | Silhouette + faction color signal | Archetype silhouette; primary costume colors; posture read | Facial features, decorative detail, texture |
| Portrait / close-up (128px+) | Internal detail + expression | Facial expression signal; material quality; costume storytelling; anchor shape legible | Nothing — full fidelity |

**The anchor shape is the through-line across all three levels.** If it is unreadable at 32px, it is too complex.

**LOD production rule**: Every character asset submission must include all three zoom levels as separate deliverables. Reviewing only the portrait is an audit failure.

*Pillar*: **Rhythm Is Respect** — the game-camera sprite must carry all information required for a turn decision. Anything that requires portrait scale to understand cannot be relied upon during play.

---

## 6. Environment Design Language

### 6.1 Architectural Style and World Culture

The world of Lux Aeterna is a civilization that **grew rather than replaced** — a medieval foundation into which technology was integrated over generations, not imposed in a revolution. Knights and mechanical constructs coexist not because the world forced them together but because the world never chose between them. Nature was not conquered by advancement; it was incorporated. The result is a built environment where stone archways support mechanical conduits, where root systems grow through circuit channels deliberately left open, where a city wall might be half dressed stone and half interlocking gear-plate — and both halves are equally old.

**The founding premise**: This world's architecture descends from a medieval tradition (load-bearing stone, arched openings, fortified towers, communal gathering spaces) that was expanded rather than replaced by technological development. The characteristic visual of any settlement is **layered coexistence**: the original medieval construction, the technological additions embedded into or built alongside it, and the natural reclamation that the culture welcomed rather than fought.

**Three architectural registers — all present in every major location:**

| Register | Visual Character | Material Vocabulary | Warmth Source |
|---|---|---|---|
| Medieval Foundation | Dressed and rough stone, wide arches, deep window recesses, flag-paved floors | Stone, timber, forged iron, fired clay | Open hearth, oil lantern, candle brazier |
| Technological Integration | Mechanical conduits running along walls, gear-work visible in doorframe hinges, soft-glowing panels set into stonework, construct charging alcoves | Polished metal, tempered glass, luminescent tubing, ceramic housing | Warm-toned mechanical glow (part of Amber Hearth family — this world's technology runs warm, not cold) |
| Natural Incorporation | Living vines deliberately trained along wall channels, root systems integrated as structural reinforcement, moss cultivated on specific surface zones, tree growth channeled through architectural openings | Bark, root, leaf, living moss, woven reed | Bioluminescent flora (warm, soft, ambient — a third warmth source type alongside fire and tech) |

**Visual rule**: All three registers must be legible in any major interior or exterior. A room that shows only stone reads as ruin or pre-technological. A room that shows only technology reads as hostile or alien. A room that integrates all three reads as home — as a place this civilization built over a long time and chose to keep all of.

**Technological glow as warmth**: In this world, technology runs warm. The visual system expands the definition of "Amber Hearth" to include soft mechanical glow — the light from a construct's power source, the amber illumination of a gear-panel's indicator light, the steady warmth of a charging alcove. This is not inconsistent with the visual grammar; it extends it. Technology in this world is civilization's accumulated care for itself. It produces the same warmth signal as fire because it serves the same cultural function.

**Cold technology as threat signal**: Only technology that is broken, corrupted, alien, or weaponized produces cold light. An enemy construct's light source is Siege Blue or Cold Slate — the same cold register as all other threats. The distinction is not "technology vs. nature" but "this civilization's warmth vs. whatever is fighting it."

**Prop implication for constructs and robots**: Mechanical characters (robots, constructs, automatons as NPCs or party-adjacent) are not enemies by default — their visual language must reflect whether they belong to this civilization or oppose it. A construct with warm-toned glow and organic patina (moss growth, worn gear surfaces) reads as belonging. A construct with cold-blue glow and pristine surfaces reads as threat. Same character type; visual grammar does the categorization.

*Pillar*: **The World Has Memory** — the three-layer architecture is the world's memory in physical form. The stone is oldest; the technology is mid-period; the nature-integration is ongoing. Reading a wall is reading the civilization's choices across time.

*Pillar*: **Story Earns Its Emotion** — a world that chose harmony (between medieval and technological, between built and natural) communicates its values without exposition. The player understands this culture before any NPC explains it.

### 6.2 Texture Philosophy

Lux Aeterna uses **painterly pixel art** — not photorealistic texture capture nor purely flat graphic shapes, but a style that uses pixel-level dithering and color placement to simulate material behavior. Reference: Sea of Stars and Octopath Traveler — surfaces that feel material, not schematic.

**The core technique is selective dithering**: applied where physical surfaces transition between light and shadow, where materials change, and where age has introduced variation. Clean hard edges indicate recent manufacture or power maintenance; dithered transitions indicate age, wear, or organic material.

**Material vocabulary at pixel scale** — all materials distinguishable by surface behavior, not color alone:

| Material | Surface Behavior | Pixel Technique |
|---|---|---|
| Dressed stone | Hard shadow edge; minimal dithering at lit face; specular glint on mortar lines | 1–2px hard edge with 1-color step highlight at corner |
| Rough/field stone | Irregular shadow distribution; moderate dithering; no specular | Random 1px variation in mid-tone cluster |
| Old timber / wood | Grain lines in 1px strokes; dithered highlight across grain | Parallel micro-lines 2–4px apart, broken at knots |
| Polished metal (tech) | High specular; minimal dithering at face; hard shadow; reflection suggests environment | 1px specular line; cold-hue in shadow even in warm environments |
| Mechanical conduit / tubing | Warm glow emanation; soft dithered edge at light radius; material reflects warmth source color | Additive warm pixels at tube edges near glow sources |
| Living vine / root | Soft shadow distribution; no specular; irregular edge | Wide dither band; varied pixel width along growth direction |
| Cultivated moss | Very low contrast; texture variation without highlight | Noisy mid-tone; 2px granular variation |
| Cloth / textile | Soft shadow; dithered edges; no specular | Wide dither band at shadow edge; no hard bright pixels |
| Corrupted material | Inverted logic: highlights at center, dark edges | Cold-hue specular; dark fringe; visual inversion signals wrong-material |

**Depth layering treatment**:
- Background: More impressionistic, slightly less precise dithering — architectural original intent reads most clearly (distance effect)
- Mid ground: Mixed — worn surface with structure visible beneath
- Foreground: Most pixel-crisp, most detailed; the worn surfaces closest to camera

**No uniform outlining**: Separation between planes is achieved by value contrast, color temperature shift, and selective shadow lines — not uniform 1px black borders on all tiles.

**True black surfaces**: Forbidden. All darks trend toward Spent Coal (warm areas) or Siege Blue field (hostile areas).

*Pillar*: **The World Has Memory** — dithering that represents wear is the texture-level expression of the architectural layering rule. Every soft surface transition is a date.

### 6.3 Prop Density Rules

Prop density is a narrative signal. The density of objects in a space communicates who was last in it, what they were doing, and whether they left by choice.

**Four density registers:**

| Register | Props per Room | Area Type | Narrative Signal |
|---|---|---|---|
| Inhabited | 8–14; clustering around activity centers | Villages, occupied interiors, markets | People are here now or very recently |
| Maintained but quiet | 4–8; deliberate placement, no clustering | Waypoints, traveler shelters, empty homes with a caretaker | Someone returns |
| Abandoned | 2–5; scattered, displaced from function | Ruins, emptied settlements, post-crisis areas | People left without taking things |
| Hostile / Active threat | 1–3; utilitarian, weapon-forward | Enemy positions, fortified zones | Objects are tools, not life |

**Clustering rules for Inhabited density**: Props cluster around **warmth sources** — hearths, lanterns, mechanical glow panels, bioluminescent flora stations. The cluster tells the player this is where living happened. A prop isolated from any warmth source in an Inhabited area is a deliberate visual anomaly.

**Three-register prop mix for this world**: In Inhabited and Maintained spaces, props from all three architectural registers should coexist — a stone table with a mechanical lamp and a vine-wrapped chair leg. This redundancy of prop origin reinforces the world's cultural coexistence without requiring narrative explanation.

**Abandonment displacement rules**: In Abandoned density, props are not in their functional position. One prop per scene may be in perfect, undisturbed position — the object precisely placed after everyone left, or the object someone went back for but didn't take. This is the "tell."

**The one-prop rule for narrative embedding**: Every room of any density must contain at least one prop that predates the player's arrival and implies a story that is already over.

*Pillar*: **The World Has Memory** — prop density is the most direct tool for communicating that the world existed before the player arrived.

### 6.4 Environmental Storytelling Guidelines

Environmental storytelling operates on a **legibility at distance** principle: every embedded narrative must be readable at game camera distance without stopping. Detail rewards stopping; the signal cannot require it.

**Three tiers of story embedding:**

| Tier | Legibility Requirement | Production Budget | Examples |
|---|---|---|---|
| **Tier 1 — Immediate** | Readable in motion at game camera. One clear visual statement. | Required in every room | Unlit mechanical glow panel in a warm settlement; construct in inactive stance at a doorway; barricaded gate |
| **Tier 2 — Stopped** | Requires pause and looking. Adds specificity to Tier 1. | At least one per scene | Scratch marks on a construct's chassis suggesting repeated repair; two different-era lanterns side by side on the same wall |
| **Tier 3 — Examined** | Requires approach or interaction. Deepest layer. | One per major location | A scene fully implied by prop arrangement; a construct's inactive display showing a partial message; architectural phasing that reveals the building's expansion history |

**The camera distance rule**: Tier 1 elements must be readable — describable without pixel-counting — at the game's default camera zoom.

**What environmental storytelling must not do**:
- Over-explain: the visual implies, it does not illustrate a caption
- Conflict with the color grammar: a "safe" past cannot be depicted in cold colors; a hostile event cannot use Amber Hearth
- Require an NPC to interpret it: if the story only exists in dialogue, the environment prop is decoration

**The recurring motif requirement**: Each major location establishes at least one recurring visual motif — an element that appears multiple times with variation, teaching the player to read it. Example: constructs in varying states of power (active in the entrance, dimmed in the main hall, completely dark in the innermost room).

*Pillar*: **Story Earns Its Emotion** — embedded narrative earns its place by saying something true about this world that couldn't be said faster another way.

### 6.5 Lighting Implementation in 2D Pixel Art (Godot 4.6)

This section defines how the warmth/cold lighting grammar is expressed in a flat 2D pixel art environment in Godot 4.6's Compatibility renderer.

**Primary technique: Painted lighting baked into tile art**

The dominant source of lighting impression is **pre-painted illumination in the tile assets**, not realtime computation.

- **Default light direction**: Above-left for outdoor/settlement tiles. Dungeon/ruin tiles use point-source logic (lantern below, construct glow, bioluminescent panel). Boss arena tiles are drawn with cold ambient — no directional warmth baked in.
- **Chiaroscuro effect**: Broad regions of pre-painted warm glow in the background layer, with a hard shadow band (2–4px, Spent Coal in warm areas / Siege Blue in hostile areas) at the architectural edge where warmth ends. Dithered edge on the floor side where the shadow softens.

**Secondary technique: Godot 2D PointLight2D and DirectionalLight2D**

Used for:
- **Diegetic light source halos**: Lanterns, construct power glows, bioluminescent flora each get a `PointLight2D` child (Amber Hearth color) creating a soft warm radius over surrounding tiles
- **State transition modulation**: Scene-wide `CanvasModulate` shifts toward cold during combat; a low-opacity `ColorRect` overlay adds the threat color tint
- **Guest color introduction**: Guest sprite carries a `PointLight2D` in their accent color, projecting onto surrounding tiles before any UI element shows it

**In this world, three warmth source types exist for `PointLight2D` usage:**
1. **Fire sources** (hearths, torches, candles): Amber Hearth, warm flicker animation
2. **Mechanical glow** (construct power, tech panels, conduit indicators): Amber Hearth family, steady (no flicker) — technology in this world is stable
3. **Bioluminescent flora** (cultivated natural light): Warm soft green-gold, very low intensity, ambient radius

All three produce warmth signals. Only broken, corrupted, or enemy technology produces cold light.

**Scene-level color modulation stack:**
1. Base tile art (pre-painted warmth — does not change)
2. `CanvasModulate` (scene-wide color cast — warm tint in exploration, neutral/cold shift in combat)
3. State overlay `ColorRect` (8–15% opacity threat color — tuned by technical artist)
4. Diegetic `PointLight2D` nodes (always Amber Hearth family in warm states; party's sole warm source in boss combat)

*Note*: Exact `CanvasModulate` and `PointLight2D` interaction values (blend modes, opacity, light mask layers) require technical artist confirmation in Godot 4.6. This section defines the visual outcome; implementation parameters are owned by the technical artist.

*Pillar*: **The World Has Memory** — pre-painted tile lighting encodes the area's permanent temperature. Modulation layers encode the current state. Both are legible simultaneously.

---

## 7. UI/HUD Visual Direction

### 7.1 Diegetic vs. Screen-Space HUD Philosophy

The UI occupies a **deliberate middle ground**: not fully diegetic (projected into the world), but not a generic floating overlay. The governing principle is **cultural artifact** — every UI element reads as something that could have been made by craftspeople in this world, using this world's materials.

**The framing metaphor**: The UI is a **guild record sheet** — the kind of information-keeping object that would exist in a world where knights track battle status, technicians log construct condition, and healers maintain patient records. These documents are parchment-bodied, metal-clasped, and ornamentally embossed. The HUD is not a heads-up display. It is a document the party carries.

**What this means in practice**:
- All panels use Deep Linen surface, Spent Coal shadow depth, Amber Hearth for active elements
- Borders use motifs from the three architectural registers: stone pattern repeats, gear-work segments, vine-growth corners — in proportion to the world's three-layer grammar
- Panels have physical depth: raised bezel (darker bottom edge, lighter top edge), inset parchment interior — achieved through pixel-art shading, no shader required
- **Exploration HUD**: Near-invisible. One minimal corner warmth indicator (small Amber Hearth glow icon, no frame). No HP bars. The world is the experience; UI is a tool reached for, not worn
- **Combat HUD**: The document fully opens. Panels slide into frame as though being laid on a surface

**One-line test for every UI element**: Does this look like it was made by someone who lives in this world?

### 7.2 Typography Direction

**Two-typeface system**:

| Role | Personality | Usage |
|---|---|---|
| **Primary (body/UI)** | Serif, optically balanced at small sizes, slightly condensed — manuscript-descended print | Dialogue, menu labels, stat numbers, button text, all functional UI text |
| **Flavor/Accent** | Handwritten or semi-script, warm and irregular — craftsperson's annotation | Item lore, NPC-authored notes, guest names in companion log, environmental signage |

The two typefaces must never compete. Flavor/Accent appears only where its irregularity adds meaning. When uncertain, use Primary.

**Size hierarchy** (at 1x pixel-art render, pre-upscale):

| Level | Role | Size | Treatment |
|---|---|---|---|
| Display | Section titles, screen headers | 14–16px | Primary, all-caps, moderate tracking |
| Primary | Action labels, menu items, NPC names, stat labels | 11–13px | Primary, regular weight |
| Secondary | Sub-labels, status effect names | 9–11px | Primary; may use semantic colors |
| Flavor | Item lore, companion log entries, environmental text | 9–11px | Flavor/Accent face; Deep Linen or Spent Coal only |
| Numeric | HP, damage numbers, turn counters | 11–14px | Primary tabular; Danger Red for enemy damage, Amber Hearth for healing, Deep Linen neutral |

**Damage numbers**: Sprite-rendered text objects spawning at the hit point, arcing upward before fading. Scale with magnitude (11px minor hit → 16–18px critical). Player-dealt crits add a 1px warm-gold drop shadow.

**What typography must not be**: Fantasy-coded display faces; retro SNES bitmap fonts; anything below 9px at 1x.

### 7.3 Iconography Style

**Grammar**: Outlined, hand-drawn at pixel scale, interior-filled — like instructional illustrations in a guild manual.

- **Outline**: 1px Spent Coal (threat-class icons use Siege Blue). No anti-aliasing.
- **Interior**: Flat color block with 1–2px highlight suggestion. No gradient, no dithering.
- **Sizes**: 16×16px base / 24×24px menu usage / 32×32px portrait-adjacent. Integer multiples only.
- **Silhouette test**: Every icon legible as solid black at 16px. If internal detail is required to identify it, the silhouette is wrong.

**Color rules by category**:

| Category | Primary Color | Example Forms |
|---|---|---|
| Combat actions (player) | Amber Hearth fill, Spent Coal outline | Sword-forward, shield-face, healing glow |
| Combat actions (enemy) | Cold Slate fill, Siege Blue outline | Angular, mechanically geometric |
| Status effects (enemy-inflicted) | Danger Red fill, Spent Coal outline | Downward motion implied |
| Status effects (player-inflicted) | Amber Hearth or guest accent | Upward motion implied |
| Guest-inherited skill | Guest accent fill, Spent Coal outline | Minimal echo of guest's anchor shape at 16px |
| Passive / persistent effect | Low-saturation fill | Dashed outline — "ongoing, not activated" |
| Navigation / menu chrome | Deep Linen fill, Spent Coal outline | Arrow forms, cursor marker |

**Icon vocabulary rule**: No two icons in the same category may share a silhouette form.

### 7.4 Combat UI

The combat UI answers three questions at any moment: **whose turn is it, what is threatened, and what can I do?** Every element has exactly one of these jobs.

**Turn order strip** (top of screen, fixed region):
- Each unit: 24×24px portrait chip in parchment-and-metal frame
- Party chips: Amber Hearth border. Enemy chips: Cold Slate (standard) to Siege Blue (elite) border; boss chips add 1px Danger Red inner accent. Guest chips: guest accent border
- **Current turn chip**: expands to 32×32px and pulses (2-frame brightness cycle, ~1.5s per cycle) — Amber Hearth for player turn, Cold Slate for enemy turn. Slow pulse; breathing, not alarming
- Defeated unit slots remain as Spent Coal frames at reduced opacity — acknowledging absence

**HP display**:
- Party HP: Segmented bar (not smooth gradient — segments make partial damage countable). Amber Hearth fill for current HP; Spent Coal for lost. At ≤25% HP, remaining segments shift to Danger Red
- Guest HP: Guest accent color as bar fill; same segmented logic
- **Enemy HP — condition states by default**: Not an HP bar. The enemy portrait chip in the turn strip shows a condition indicator:
  - *Unwounded* / *Pressured* / *Bloodied* / *Near-Breaking*
  - Named with in-world language, not percentages
  - **Exact HP revealed by "Scan" / "Analyze" ability** — the ability result displays as a diagnostic readout in the flavor typeface, formatted as a guild-record entry. This is the one context where an exact HP number appears for an enemy

**Action menu** (bottom-right, parchment frame):
- Vertical list of actions. Selected row: Amber Hearth background, Spent Coal text. Adjacent rows: Deep Linen background
- 16×16px icons per Section 7.3 grammar at row left
- Ability submenu: lateral extension from the action panel (not a new window). Guest-inherited abilities listed below a faint accent-colored rule line

**Turn state signals — three simultaneous per state**:

*Player turn*: chip expands + Amber Hearth pulse; action menu slides in; scene `CanvasModulate` warms slightly

*Enemy turn*: chip expands + Cold Slate pulse; action menu slides out (disabled); scene cools slightly

**Timing window indicator**:
- A 24px horizontal bar appearing over the active target — minimal, borderless pill form (deliberately breaks guild-record aesthetic for speed of read)
- Depletes left-to-right at timing window speed. No countdown numbers
- Amber Hearth fill → shifts to Victory Gold at the final 20% (the last moment of opportunity is the brightest)
- Missed window: bar collapses immediately; single Cold Slate flash on target chip
- The aesthetic break is intentional and documented. The functional signal must be instantaneous

### 7.5 Guest UI Transitions

**Arrival sequence**:
1. Guest appears in the scene — accent color already present in environment (per design protocol)
2. No immediate UI change. Guest is in the world first
3. After arrival narrative beat: party status panel extends a new slot downward (paper-draw audio cue)
4. Guest portrait fades in; slot border transitions from Deep Linen → guest accent color over 8 frames (~0.25s at 30fps)

**Departure sequence**:
1. Narrative departure beat concludes
2. Guest portrait in party panel desaturates to grayscale over 12 frames, then fades out over 8 frames
3. Slot border desaturates from accent → Spent Coal
4. **The slot does not collapse** — it remains as a Spent Coal frame. The structural gap is the visual grammar of departure
5. **Companion log persistence**: In the companion log (accessible from party panel), the departed guest's log entry border remains the accent color permanently — the single bounded location the color occupies after departure
6. Guest-inherited skills in the ability submenu: accent-colored rule line persists if skills are retained; desaturates if skills are lost on departure (design decision)

**Re-entry**: If a guest returns, the existing slot re-activates — border re-saturates to accent over 8 frames. Not a new slot; a return.

### 7.6 Animation Feel

**One rule**: UI moves like paper and metal, not software.

- No bounce or spring easing — ease-out curves that decelerate to a full stop
- No scale animations for opening — panels slide or unfold from an edge
- Duration limits: short transitions 0.10–0.15s; medium 0.20–0.30s; nothing over 0.35s for standard open/close

| Element | Open | Close | Duration |
|---|---|---|---|
| Action menu | Slides in from bottom-right | Slides out to bottom-right | 0.15s |
| Ability submenu | Extends laterally from action panel | Collapses back | 0.12s |
| Dialogue box | Rises from bottom edge; text populates at ~24 chars/sec (player-adjustable) | Drops to bottom | 0.20s panel |
| Party status panel | Slides in from left (exploration) | Slides back left | 0.15–0.20s |
| Guest arrival slot | Extends downward; border resolves after position settles | — | 0.25s + 0.25s |
| Full-screen menus | World dims 0.10s; primary panel rises 0.25s; secondary elements stagger 1–2 frames | Reverse order | 0.35–0.45s total |
| Damage number | Spawns at impact; arcs upward 8–12px; fades at arc peak | — | 0.40s |
| Timing window bar | Appears instantaneously; disappears instantaneously | — | 0 |
| Selection cursor | **Snap, not slide** — always in settled position, never mid-travel | — | Instantaneous |

**Selection feedback**:
- On change: Amber Hearth highlight row appears immediately (no fade); text inverts simultaneously
- On confirm: 1-frame brightness flash on Amber Hearth highlight. No particles, no glow ring

**Full-screen menu**: World `CanvasModulate` desaturates ~30% when menu is open; returns to full on close.

### 7.7 UX Concerns (Flagged for Resolution)

1. **Ornate borders vs. text legibility**: Illustrated borders at pixel scale compress interior surface area. Define a minimum interior-to-border ratio (suggested 70/30) and verify all panel designs at target resolution before production
2. **Snap cursor on gamepad**: Implement a minimum input window between cursor moves (80–120ms on d-pad; deadzone + repeat delay for analog stick) to prevent rapid-fire snaps reading as missed inputs
3. **Text speed as accessibility setting**: Confirm text speed adjustment is a firm requirement in the UX spec and on the story backlog — not just an art bible note
4. **Timing window aesthetic break**: Documented as intentional. Flag in production notes so QA does not raise it as an inconsistency

---

## 8. Asset Standards

*Engine: Godot 4.6 — Compatibility renderer (2D). Performance budgets: 200 draw calls (soft), 512MB memory, 60fps. Platform: PC (Steam) only.*

### 8.1 File Format Standards

| Asset Category | Source Format | Export / Import Format | Notes |
|---|---|---|---|
| Character sprites | .aseprite (preferred) or .psd | .png (RGBA, lossless) | One .png per animation strip or per frame; do not flatten layers in source |
| Tilesets | .aseprite or .psd | .png (RGBA, lossless) | All tiles in a single atlas per tileset; max 2048×2048px per atlas |
| Backgrounds | .aseprite or .psd | .png (RGBA, lossless) | Split into depth layers (foreground/mid/background) — separate .png per layer |
| UI elements | .aseprite or .psd | .png (RGBA, lossless) | 9-patch borders exported as NineSliceSprite2D-compatible; individual icon sprites on shared atlas |
| Portraits | .aseprite or .psd | .png (RGBA, lossless) | One file per character; expression variants as frames or separate files |
| SFX | .wav (source) | .wav or .ogg (Godot import) | See Section 8.6 |
| Music | .wav or .flac (source) | .ogg (Godot import, looped) | See Section 8.6 |
| Fonts | .ttf or .otf | .ttf / .otf (Godot native) | Embed font into project; do not use bitmap font unless pixel font is chosen |

### 8.2 Naming Conventions

**General rule**: `[category]_[descriptor]_[variant].[ext]` — all lowercase, underscores, no spaces.

| Asset Type | Pattern | Example |
|---|---|---|
| Character sprite | `char_[name]_[animation]_[frame].png` | `char_aria_walk_01.png` |
| Character sprite strip | `char_[name]_[animation].png` | `char_aria_idle.png` |
| Portrait | `portrait_[name]_[expression].png` | `portrait_aria_neutral.png` |
| Tileset atlas | `tiles_[area]_[register].png` | `tiles_village_stone.png` |
| Background layer | `bg_[area]_[layer].png` | `bg_village_mid.png` |
| UI panel | `ui_[element]_[variant].png` | `ui_panel_parchment_lg.png` |
| Icon | `icon_[category]_[name].png` | `icon_action_attack.png` |
| SFX | `sfx_[category]_[descriptor].wav` | `sfx_combat_hit_light.wav` |
| Music | `mus_[area]_[state].ogg` | `mus_village_explore.ogg` |

**Folder structure** (under `assets/`):
```
assets/
├── art/
│   ├── characters/     # char_ and portrait_ files
│   ├── tilesets/       # tiles_ atlases
│   ├── backgrounds/    # bg_ layer files
│   └── ui/             # ui_ panels, icon_ sprites
├── audio/
│   ├── sfx/            # sfx_ files
│   └── music/          # mus_ files
└── data/               # Non-art game data (configs, balance tables)
```

### 8.3 Sprite Resolution Tiers

All character sprites are designed at **1× base resolution** and displayed at integer scale in Godot (2× or 3× depending on target display resolution).

| Character Category | Game Camera Sprite | Portrait | System Icon | Animation Frames (idle) |
|---|---|---|---|---|
| Core party member | 48×64px | 128×128px | 32×32px | 4–6 frames |
| Guest character | 48×64px | 128×128px | 32×32px | 4–6 frames |
| Named NPC | 32×48px | 96×96px | — | 2–4 frames |
| Generic NPC / crowd | 24×32px | — | — | 2 frames (or static) |
| Standard enemy | 48×48px | — | 24×24px (turn strip) | 2–4 frames |
| Elite / named enemy | 64×64px | — | 24×24px | 4 frames |
| Boss | 96×128px or larger (per boss) | — | 32×32px | 4–8 frames |
| Constructs / robots (NPC) | Same as NPC category for type | Same rules | — | 2–4 frames |

**Scale rule**: All sprites are displayed at **nearest-neighbor upscale** (no filtering). Godot 4.6 Compatibility renderer default — confirm `Texture Filter: Nearest` on all sprite imports.

### 8.4 Animation Standards

| Animation Type | Target FPS | Min Frames | Max Frames | Notes |
|---|---|---|---|---|
| Idle | 8fps | 2 | 6 | Loop. At least one held pose ≥4 frames |
| Walk / move | 8fps | 4 | 8 | Loop |
| Combat action (attack) | 12fps | 4 | 10 | Non-loop; return to idle on last frame |
| Combat action (skill) | 12fps | 6 | 14 | Non-loop; can include anticipation frames |
| Hit reaction | 12fps | 2 | 4 | Non-loop; fast — conveys impact |
| Death / defeat | 8fps | 4 | 8 | Non-loop; hold final frame |
| Portrait expression shift | 8fps | 2 | 4 | Transition between expression variants |
| UI element animation | 30fps | — | — | UI uses Godot Tween, not sprite frames |

**Hold frame rule**: Every non-looping combat animation must end with a **held pose frame** — the apex or completion of the action. This frame is displayed for a minimum of 3 frames (at 12fps, ~0.25s) before returning to idle. The held pose is the art (Section 5.3).

**Export format**: Sprite strips (horizontal, all frames in one row) preferred for Godot `SpriteFrames` import. Individual frame files acceptable if strip would exceed 4096px width.

### 8.5 Tileset Standards

- **Tile size**: 16×16px base tile unit. All tilesets built on this grid
- **Tileset atlas size**: Max 2048×2048px per atlas. Organize by area and architectural register (one atlas per area/register combination where practical)
- **Godot 4.6 `TileSet` format**: Use `TileMapLayer` (Godot 4.x — not deprecated `TileMap`). Configure terrain sets for autotile behavior where applicable
- **Collision layers**: Defined per tile in `TileSet` editor. Layer assignments:
  - Layer 1: Solid collision (walls, impassable terrain)
  - Layer 2: Platform / one-way (if applicable)
  - Layer 3: Interaction zone (NPCs, triggers, interactable objects)
- **Depth layering**: Foreground, mid ground, and background must be separate `TileMapLayer` nodes with distinct Z-index values. Do not mix depth layers in a single TileMapLayer
- **Autotile**: Required for all ground/floor and wall tiles in exploration environments. Boss arenas and special environments may use manual placement
- **No tile bleeding**: Use `clip` mode or 1px extrusion margin on tileset atlas edges in Godot importer to prevent bleeding at camera movement

### 8.6 Audio Asset Standards

**SFX**:
- Sample rate: 44,100 Hz
- Bit depth: 16-bit
- Format: .wav (source); Godot imports as .wav with optional compression
- Length: SFX must be ≤3 seconds. Ambient loops are separate (see below)
- Headroom: Normalize to −6 dBFS peak maximum; −18 LUFS RMS target
- Naming: `sfx_[category]_[descriptor]_[variant].wav` — include variant suffix for SFX with multiple takes (e.g., `sfx_combat_hit_light_01.wav`, `_02.wav`)

**Music**:
- Source: .wav or .flac
- Export: .ogg (Godot import — looped tracks require loop points set in Godot `AudioStream` properties)
- Sample rate: 44,100 Hz
- Loop points: All exploration and combat music must have seamless loop points defined. Verify loop in Godot `AudioStreamOggVorbis` before submitting
- Stems (if adaptive audio is implemented): Separate .ogg per stem, named `mus_[area]_[state]_[stem].ogg`

**Ambient audio**:
- Treated as SFX category for format/normalization standards
- Named `sfx_ambient_[area]_[descriptor].wav`
- Must loop seamlessly; loop points required

### 8.7 Godot 4.6 Import Settings

| Asset Category | Filter Mode | Mipmaps | Compression | Notes |
|---|---|---|---|---|
| Pixel art sprites (all) | **Nearest** | Off | Lossless | `Nearest` is mandatory for pixel art — no exceptions |
| UI elements | **Nearest** | Off | Lossless | UI at pixel scale must not interpolate |
| Backgrounds | **Nearest** | Off | Lossless | If background is very large (>1024px), confirm memory budget |
| Portrait images | **Nearest** | Off | Lossless | |
| Tileset atlases | **Nearest** | Off | Lossless | Enable 1px texture margin (clip) to prevent bleeding |
| Audio (SFX) | — | — | Disabled or PCM | Short SFX: keep uncompressed for latency. Long SFX: IMA ADPCM |
| Audio (Music) | — | — | Ogg Vorbis | Loop mode: `Enabled`; set loop offset in AudioStream |

**Linear vs. sRGB**: Godot 4.6 Compatibility renderer uses sRGB by default. Ensure all pixel art source files are in sRGB color space. Do not use linear color space for 2D assets.

### 8.8 Memory Budget by Category

Total ceiling: **512MB**. Estimated budget breakdown (adjustable as the project develops):

| Category | Budget | Notes |
|---|---|---|
| Character sprites + animations | ~60MB | All party, guest, NPC, enemy, boss sprite atlases |
| Tilesets | ~80MB | Multiple areas; loaded per scene, not all at once |
| Backgrounds | ~50MB | Per-layer PNG; unloaded on scene change |
| UI elements + fonts | ~30MB | Persistent — loaded at startup |
| Audio (SFX resident) | ~40MB | Commonly used SFX preloaded; rare SFX streamed |
| Audio (Music streamed) | ~20MB | Ogg streams; not fully preloaded |
| Engine overhead + code | ~80MB | Godot 4.6 Compatibility renderer baseline |
| Scene objects + gameplay data | ~60MB | Node tree, collision shapes, game state |
| **Reserve (buffer)** | **~92MB** | Do not allocate speculatively |

**Loading strategy**: Assets are organized by scene. Each scene loads only the assets required for that area. Global assets (UI, common SFX, party sprites) are loaded at startup and remain resident. Area-specific assets (tilesets, backgrounds, area music) are loaded on scene transition and freed on exit.

### 8.9 Asset Delivery Checklist

An asset is not done until all items on this checklist are verified. Every submission requires a completed checklist.

**Sprite assets**:
- [ ] Exported at correct resolution tier (Section 8.3)
- [ ] File named per Section 8.2 conventions
- [ ] All required animation types delivered (Section 8.4)
- [ ] Hold frames present on all non-looping combat animations
- [ ] Black rectangle silhouette test passed at smallest deployment size
- [ ] Anchor shape legible at 32px (guest characters only)
- [ ] Guest accent color tested against colorblind simulation (guest characters only)
- [ ] All three LOD zoom levels delivered (core party and guest only)
- [ ] Godot import settings verified: Nearest filter, no mipmaps, lossless

**Tileset assets**:
- [ ] Tile size confirmed 16×16px
- [ ] All three depth layers delivered as separate files
- [ ] Autotile terrain set configured in TileSet
- [ ] Collision layers assigned
- [ ] No tile bleeding at atlas edges (1px margin or clip mode)

**UI assets**:
- [ ] Interior-to-border ratio ≥70/30
- [ ] 9-patch borders tested at all expected panel sizes
- [ ] All icons pass silhouette test at 16px
- [ ] Guest accent color slot confirmed per guest (companion log entry)

**Audio assets**:
- [ ] Peak ≤−6 dBFS; RMS target −18 LUFS
- [ ] Loop points verified in Godot AudioStream (music and ambient)
- [ ] File named per Section 8.2 conventions

---

## 9. Reference Direction

References are technique donors, not style targets. No single reference should be legible in the finished game — what should be legible is what was extracted from each. References must be additive: no two point in the same direction.

### 9.1 Sea of Stars (2023) — Pixel Art Lighting and Environmental Warmth Grammar

**What to draw from**: The technique of baking warm ambient illumination directly into background tile art — how warm glow radiates from architectural surfaces as a paint decision, not an engine decision. Also: depth-layering through color temperature and detail level (background layers more impressionistic and desaturated, creating readable parallax without motion).

**What NOT to take**: The uniform warmth saturation — Sea of Stars keeps every environment equally warm and safe. Lux Aeterna's warmth is earned and threatened; hostile spaces must be genuinely desaturated by contrast. Also: the character design register — expressive, cartoonically readable, high-contrast. Our characters are understated and posture-primary.

**Why it's here**: The clearest existing demonstration of the primary technique — baked painterly warmth in pixel tile art.

---

### 9.2 Octopath Traveler (2018) — Selective Dithering and Material Texture at Pixel Scale

**What to draw from**: Material differentiation through pixel-level surface behavior — stone vs. fabric vs. metal expressed through dithering density, highlight placement, and shadow edge hardness, not color alone. The dramatic chiaroscuro that keeps character sprites readable against busy tiled environments.

**What NOT to take**: The HD-2D depth-of-field bokeh effect — background layer blur produces an imitation register in a non-3D game. Also: the high saturation range (vivid greens, purples, reds as world colors). Our saturation is controlled by semantic meaning.

**Why it's here**: The clearest demonstration of material specificity through pixel technique. Sea of Stars handles warmth; Octopath handles material.

---

### 9.3 Castlevania: Symphony of the Night (1997) — Layered World as Architecture of Time

**What to draw from**: The compositional logic of environments that read as accumulations across time — how multiple architectural generations coexist within a single room. Also: how character and significant figure silhouettes remain readable in dense, visually complex environments through designed "rest zones" between points of complexity.

**What NOT to take**: The gothic horror color language — deep purples, blood reds, bone whites carry horror associations that conflict with our warmth/cold semantic system. Also: the dungeon-as-antagonist relationship — Symphony's castle is oppressive; our environments are inhabited and culturally continuous even at their most hostile.

**Why it's here**: The most technically precise pixel-art reference for environments communicating layered time. Sea of Stars shows warmth; Octopath shows material; Symphony shows historical accumulation.

---

### 9.4 Hirokazu Kore-eda (filmmaker) — Emotional Weight Through Absence and Restraint

**What to draw from**: The compositional strategy of communicating emotional states through the arrangement of objects and occupation of space rather than facial expression or dramatic gesture. Grief in *Still Walking* lives in which chair a character does not sit in. Loss in *After the Storm* lives in the room's prop arrangement — things that remain where a person left them. This is the non-game formalization of posture-primary expression (Section 5.3) and environmental storytelling (Section 6.4).

**What NOT to take**: The pacing — Kore-eda's films operate at durations games cannot sustain. Also: the domestic realism of contemporary Japanese interior life. The technique of absence and arrangement translates; the cultural specificity of his settings does not.

**Why it's here**: Every other reference is a visual-technical source. Kore-eda is the emotional register source — the realized body of work that makes "express grief through geometry, not features" concrete.

---

### 9.5 Metal Gear Solid 3: Snake Eater (2004) — Warmth as Civilization Memory

**What to draw from**: The thematic-visual equation — warmth (fire, cooked food, shelter) represents civilization and care; cold represents threat. The game makes this legible at a glance before any mechanic confirms it. More specifically: the compositional technique of color grammar reversal at a decisive emotional moment (the Boss's white uniform in the flower field — warmth surrounding a cold figure, devastating precisely because it inverts the established grammar).

**What NOT to take**: The Cold War gritty realism aesthetic — camouflage, military hardware, olive drab. Also: the expressive approach to protagonists — Snake's inscrutability is about masculine stoicism, not posture-as-emotion.

**Why it's here**: The most direct game-format precedent for the warmth/cold grammar as narrative statement, and a usable model for deliberate color grammar reversal at emotionally decisive moments.

---

### 9.6 Yoshitaka Amano (artist) — Impressionistic Character Identity Over Legible Detail

**What to draw from**: How Amano communicates character identity through a single dominant, irreducible design element — one shape or color the eye locks onto — rather than full-costume legibility. This is the concept-art precedent for the guest character anchor shape protocol: the anchor shape functions exactly as Amano's identity element. Also: his treatment of negative space within a figure — the impression of trailing fabric, the suggestion of an environment — letting the eye fill in the rest.

**What NOT to take**: The illustrative style directly — Amano's work is watercolor-adjacent and gestural. Applying his visual style to pixel art is a category error. Also: the ornamental, flowing costume complexity; his aesthetic register conflicts with this game's worn-functional character language.

**Why it's here**: The only reference that operates at the character concept stage rather than production art. It addresses how to identify what is irreducible in a design — the highest-stakes visual choice made for each guest character.

---

### 9.7 Prohibited References

The following sources carry visual associations or design philosophies that would pull the art in demonstrably wrong directions. Do not use as reference without explicit art director consultation.

**Final Fantasy VI pixel art (SNES era)**: Uniform black outlines, flat color blocking, and theatrical expression palette belong to a different register. Normalizes the uniform 1px outline on all sprites — explicitly forbidden in Section 6.2.

**Dark Souls / Elden Ring environmental atmosphere**: Cold-as-aesthetic-default communicates nihilism and the absence of civilization. Lux Aeterna's cold is an active threat to an existing warm civilization — not evidence that warmth was already lost. Importing this reference risks the wrong premise.

**Studio Ghibli visual language**: Ghibli warmth is ambient, decorative, and uniformly pleasant — every frame is warm regardless of emotional state. Artists referencing Ghibli will warm hostile environments because it "feels right," destroying the contrast that makes earned warmth meaningful.

**Undertale / Deltarune**: These games use pixel art as a deliberate regression signal — intentional low fidelity is the message. Lux Aeterna's pixel art is high craft and painterly. Artists referencing Undertale will apply too-simple shapes and too-flat color in the belief that this is the pixel art register.

**Kingdom Hearts visual design** *(Note: Kingdom Hearts 2 is a valid narrative/emotional reference — party investment, escalating stakes, guest character weight. It is NOT a valid visual reference)*: Character proportions (large expressive heads), high-key lighting across all emotional states, and ornate costume complexity for its own sake conflict with the posture-primary expression system, warmth/cold lighting grammar, and worn-functional costume language established in this bible. Reference the story; do not reference the visuals.

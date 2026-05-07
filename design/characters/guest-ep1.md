# Character Visual Profile: Kia

> **Episode**: 1 — Terna / Santuario
> **Type**: Guest Character
> **Status**: In Design
> **Author**: user + art-director
> **Last Updated**: 2026-05-07
> **Departure Type**: Death

---

## Overview

Kia is the Episode 1 guest character. She fights alongside Kakus in the Terna/Santuario segments — the parallel storyline to the core trio's events in Lumenia. She is not a traveler from the protagonists' world; she belongs to Lux Ae. Her presence gives Kakus's Terna arc a companion, a guide, and ultimately a loss that is mechanical as much as narrative. When she dies, she leaves Kakus faster than he was before.

---

## Narrative Arc

**Arrival**: Kia rescues Kakus from the ruins of Terna and guides him toward Santuario. She joins his combat party as a matter of survival — the terrain is hostile and Kakus, disoriented and unfamiliar with the world, needs her.

**Episode arc**: She is competent where Kakus is impulsive. Their dynamic is friction and dependency: she knows the world; he doesn't. She is fast and precise in combat; he is heavy and reckless. Together they work.

**Departure**: Kia dies in Episode 1 — not a farewell, not a story exit. A death in the field. The player sees it in combat or immediately after. The warm rose color leaves the world. It moves to Kakus's stat screen. He carries her SPD into every fight that follows.

**Named Inheritance Object**: *Kia's Will* — SPD +2 on Kakus.
*Display text on Kakus's stat screen*: `SPD [base] + 2 [Kia's Will]`

---

## Combat Profile

| Stat | Value | Note |
|------|-------|------|
| HP | 75 | Glass cannon — same fragility range as Ne |
| ATK | 17 | High; short sword + dagger output |
| DEF | 6 | Below Ne's 8; she avoids damage by not being hit |
| SPD | 22 | Faster than Ne (20) — speed is her identity |
| FLUX | 9 | Tight precision window; rewards the player who learns her rhythm |
| Perfect-Hit Multiplier | 1.5× | Between Ne's ceiling (1.6×) and Setsuna's floor (1.2×) |

**Combat archetype**: *Blade* — same archetype as Ne. High ATK + SPD, low HP + DEF. The distinction: Kia's SPD 22 means she often acts twice per round against slower enemies (double-action threshold at 1.5× lowest combatant SPD). She is the fastest combatant the player will have in Episode 1.

---

## Silhouette Design

**Anchor shape**: The **reverse-grip dagger, extended off-body to the left** — held low and outward in her off-hand, creating an asymmetric horizontal break on the left side of her silhouette. Combined with long hair that falls and breaks right, her outline has two directional vectors pulling opposite ways, creating the visual tension of someone always in motion.

**Silhouette territory** (per Art Bible Section 3.1): Asymmetric, one dominant accent shape. Her long hair + extended dagger means no single clean vertical edge. She reads as arrival — someone who entered the frame from elsewhere.

**Black rectangle test** (64×64px): The reverse-grip dagger extended left + hair mass right must be distinguishable from the core party at thumbnail scale. The extended dagger arm is the unique read — no core party member holds a weapon outward in that position at rest.

**Distinction from core party**:

| Character | Silhouette read at thumbnail |
|-----------|------------------------------|
| Clawd | Anchored vertical, stable base — no extended limbs at rest |
| Ne | Forward-leaning blade stance, weapon held high |
| Setsuna | Compact, katana at hip, contained |
| Kakus | Wide mass, heavy center — Kia's thinness is the contrast |
| **Kia** | Narrow, asymmetric — extended dagger left, hair right |

---

## Accent Color

**Name**: Kia's Rose
**Hex**: `#C8697C`
**Character**: Warm rose — red-shifted, not cool or blue-shifted. Clearly pink but with enough red to sit in the warm palette without clashing against the cold side. Medium saturation: readable on dark backgrounds (Spent Coal, Siege Blue) without reading as cheerful. A color that carries weight.

**Art Bible compliance**:
- Distinct from Danger Red — clearly pink, not hot urgent-red
- Distinct from Amber Hearth — warm but in a different family (rose vs. amber-orange)
- Distinct from Victory Gold — not bright or saturated in the same register
- Warm-side of the spectrum — belongs in the warmth language, not the cold language

**Arrival sequence** (Art Bible Section 2.5): The warm rose appears in the Terna environment *before* the UI registers Kia — rust-coloured mineral strata in the ruins with a rose undertone, a cracked flower pushing through stone, reflected light through a rose-tinted fissure in the rock. The world acknowledges her before the party does.

**Post-departure persistence**: After Kia dies, `#C8697C` withdraws from the world and occupies Kakus's stat screen — the *Kia's Will* Named Inheritance Object entry is rendered in her rose. The environment no longer carries it. The UI carries it instead.

---

## Physical Description

| Feature | Description |
|---------|-------------|
| Age read | Late teens to early 20s |
| Build | Thin, wiry — lean muscle, not bulk. Makes SPD 22 legible at a glance. |
| Skin | Pale |
| Hair | Long, black, loose — falls past shoulder blades. Not styled or tied. In motion it trails behind her; at rest it breaks asymmetrically to one side. |
| Eyes | Sharp, dark. Narrow at the corners. The primary emotional register for all her expressions. |
| Face | Angular rather than soft. Not severe — precise. The face of someone who makes quick decisions and trusts them. |

---

## Costume & Equipment Design

**Bodysuit**: Black, form-fitting, worn out. Torn at the edges — not decorative damage, damage from actual use in Terna. The wear should feel earned: fraying at the knees, a torn collar, abraded texture at the elbows. No clean lines. The bodysuit communicates that she has been in Terna for a while before Kakus arrives.

**No armor**: Speed over protection. No pauldrons, no chest plate, no bracers. The absence of armor is itself information — she survives by not getting hit.

**Accent color placement**: A single warm rose element — small, not dominant. One of: a rose-tinted trim edge; a wrapped cloth detail at the wrist or thigh in rose; subtle rose stitching on a visible repair to the bodysuit. It must be the *only* warm color on her. When she appears, the rose stands alone against black and pale skin.

**Short sword**: One-handed, straight blade, plain crossguard. Not ornate — functional. Worn grip wrap. Primary striking weapon. Carried at the right hip.

**Dagger**: Shorter, slightly wider at the base. Held in the left hand in reverse grip (edge outward) — this is the silhouette anchor shape. The dagger is never sheathed in combat idle; it is always in hand.

---

## Sprite Specifications

**Native resolution**: 32×48px (standing frame reference). Verify silhouette at 64×96px (2×) before finalising.

**Required animation states**:

| State | Frame Count | Notes |
|-------|-------------|-------|
| Idle | 4–6 | Subtle weight shift; dagger extended, sword at hip; hair has slow drift |
| Turn start | 3 | Step forward, eyes narrow — she's reading the enemy before moving |
| Attack — Short sword | 3–4 | Fast horizontal slash; primary hand |
| Attack — Dagger | 3 | Quick thrust with left hand, body low; short and brutal |
| Combo (with Kakus) | 5–6 | Short sword slash into dagger follow-through |
| Hit (taking damage) | 2–3 | Knock-back; hair follows delayed; minimal flinch — she absorbs without breaking composure |
| Death | 6–8 | Falls forward. Hair spreads across the floor. Dagger releases from her hand and lands beside her — the rose accent on the grip wrap is the last warm color visible before she goes still. Final frame: still, face down or side, hair covering face. |
| Portrait (chip) | 1 | Front-facing, neutral focus |

**Death animation directive**: Her death is not explosive or violent. She goes down. The weight is earned by stillness, not spectacle.

---

## Portrait Chip Specification

**Used in**: HUD — Zone 1 (Turn Strip), slot 4 (guest position)

| Element | Specification |
|---------|--------------|
| Frame size | ≤32px wide × 36px tall (native resolution) |
| Composition | Face centered; upper chest visible; sharp eyes must read at chip scale |
| Border | Warm rose `#C8697C` border ring — her accent color as the chip frame |
| Contrast read | Black hair mass (top) vs. rose border vs. pale skin — three-value contrast; readable at thumbnail |
| Expression | Neutral combat focus — not dramatic |

**Post-death chip state**: When Kia dies her chip is removed from the turn strip immediately. The rose border is gone from the HUD. It reappears only in the *Kia's Will* entry on Kakus's stat screen.

---

## Expression Range

Minimum required expressions for cutscenes and dialogue:

| Expression | Use Context | Key Visual Tells |
|------------|-------------|-----------------|
| **Combat focus** | Default in encounters | Eyes narrowed, jaw set, no tension — calm precision |
| **Defiant** | Facing a dangerous enemy | Eyes fully open, direct gaze, weight shifted forward |
| **Brief warmth** | Moment of connection with Kakus | Eyes softer at the corners; slight unguarded quality — rare; the player notices when it appears |
| **Contempt** | Kakus does something reckless | One brow; slight lip; not angry, unimpressed — she's seen worse |
| **Final** | Death — last cutscene beat | Eyes closed or half-open. Not peaceful, not in pain. Finished. |

---

## Art Direction Notes

**Her rose in the world**: At Kia's arrival, the warm rose appears in Terna's environment before combat UI — rust-coloured mineral strata with a rose undertone, a cracked flower pushing through stone, reflected light through a rose-tinted fissure. Required per Art Bible Section 2.5: the world acknowledges her before the game announces her.

**Departure moment lighting**: When Kia dies, the environmental rose accent withdraws. Terna's combat floor returns to its cold tones. Per Art Bible Section 2.6: *"The difference is felt, not shown explicitly."*

**Silhouette consistency rule**: In any scene where Kia appears beside Kakus, her silhouette must contrast his. Kakus is wide, heavy, high center of mass (giant hammer). Kia is narrow, low center of mass, extended-outward dagger. They must never be confused at thumbnail scale.

**Worn bodysuit wear guidelines**: The damage on her bodysuit is practical — knees, elbows, collar. Do not add decorative rips or styled tears. The wear pattern should suggest specific movement: crawling through rubble, dropping from height, sustained combat. Her costume shows how long she has been in Terna before Kakus arrived (Art Bible Principle 3: the world is older than the visit).

**Guest color isolation rule**: `#C8697C` must be the only warm color on Kia's sprite outside of the single accent placement. Her black bodysuit and pale skin make the rose read as signal, not decoration. If any other warm tone appears on her sprite, the rose loses its meaning.

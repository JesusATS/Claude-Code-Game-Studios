# Accessibility Requirements: Lux Aeterna

> **Status**: Committed
> **Author**: gate-check (on behalf of producer)
> **Last Updated**: 2026-05-04
> **Accessibility Tier Target**: Basic
> **Platform(s)**: PC (Steam / Epic Games Store)
> **External Standards Targeted**:
> - WCAG 2.1 Level A (text contrast baseline only)
> - AbleGamers CVAA Guidelines: Partial
> - Xbox Accessibility Guidelines (XAG): N/A — PC only at launch
> - PlayStation Accessibility (Sony Guidelines): N/A
> - Apple / Google Accessibility Guidelines: N/A
> **Accessibility Consultant**: None engaged
> **Linked Documents**: `design/gdd/systems-index.md`, `design/ux/interaction-patterns.md` (pending)

---

## Accessibility Tier Definition

### This Project's Commitment

**Target Tier**: Basic

**Rationale**: Lux Aeterna is a 2D turn-based RPG with timing-window combat. The turn-based structure eliminates most severe motor accessibility barriers common in action games — players have deliberate time to make decisions between timing windows. The timing windows themselves (InputTimingDetector) are the primary motor concern, but at Basic tier we document this as a known limitation rather than committing to adjustable timing. The game is text-heavy (dialogue system, ability descriptions, status effects), making text readability the highest-priority visual concern. PC-only launch means no platform certification requirements (XAG, Sony). The team is a solo/small-indie operation — Basic tier matches capacity while covering the most critical accessibility needs. Escalation to Standard tier (adding input remapping, colorblind modes, timing adjustment) is planned for a post-launch update if resources allow.

**Features explicitly in scope (beyond tier baseline)**:
- Independent volume controls for Music, SFX, and Voice buses (AudioSystem GDD already specifies `set_bus_volume()`)
- Pause available in all gameplay states including combat

**Features explicitly out of scope**:
- Full input remapping (Standard tier — deferred to post-launch)
- Colorblind modes (Standard tier — deferred; all gameplay-critical indicators will use shape/icon backup per Basic color-only audit)
- Timing window adjustment / extend (Standard tier — deferred; InputTimingDetector window frames are data-driven via AbilityData.timing_window_frames but no runtime multiplier is planned for v1.0)
- Subtitles with speaker identification (Standard tier — deferred)
- Screen reader support (Comprehensive tier)

---

## Visual Accessibility (Basic Tier)

| Feature | Scope | Status | Notes |
|---------|-------|--------|-------|
| No color-as-only-indicator | All UI and gameplay | Not Started | Audit during HUD implementation — every color-coded element needs shape/icon/text backup |
| Brightness/gamma controls | Global graphics settings | Not Started | Calibration image at first launch |
| Screen flash / strobe review | All VFX, combat animations | Not Started | Review against Harding FPA: max 3 flashes/sec. No photosensitivity-triggering sequences |
| Readable text at 1080p | All UI text | Not Started | Target 20px minimum for HUD, 24px for menus. Verify on 1080p monitor at arm's length |
| Subtitles on/off | All voiced content (when voice acting is implemented) | Not Started | Default: OFF. Offer prominently at first launch |

### Color-as-Only-Indicator Audit

| Location | Color Signal | Non-Color Backup | Status |
|----------|-------------|-----------------|--------|
| HP bars (HUD) | Red = low HP | Numeric value shown; bar flashes | Not Started |
| Timing grade display | Color per grade (PERFECT/GOOD/MISS) | Grade text label always shown alongside color | Not Started |
| Enemy condition state | Color change on condition thresholds | Condition name text shown on scan; icon changes shape | Not Started |
| Status effect icons | Color-coded by effect type | Icon shape differs per effect; tooltip shows name | Not Started |
| Turn order display | Active combatant highlighted | Active combatant also has animated border + name label | Not Started |

---

## Motor Accessibility (Basic Tier)

| Feature | Scope | Status | Notes |
|---------|-------|--------|-------|
| Pause anywhere | All gameplay states | Not Started | Including mid-combat, mid-dialogue |
| Keyboard + Gamepad support | All interactions | Not Started | Per technical-preferences.md: keyboard/mouse primary, gamepad partial. D-pad navigation for all menus |

**Known limitation**: Timing windows (InputTimingDetector) require pressing `timing_confirm` within a frame-counted window. No runtime timing multiplier is provided at Basic tier. The timing windows are data-driven (`AbilityData.timing_window_frames`) so a multiplier could be added at Standard tier without architectural changes.

---

## Cognitive Accessibility (Basic Tier)

| Feature | Scope | Status | Notes |
|---------|-------|--------|-------|
| Pause anywhere | All gameplay states | Not Started | Covered in Motor section — also a cognitive aid |
| Clear objective display | Quest/story flag system | Not Started | StoryState flag system enables checking current objectives; HUD should surface active objective |

---

## Auditory Accessibility (Basic Tier)

| Feature | Scope | Status | Notes |
|---------|-------|--------|-------|
| Independent volume controls | Music / SFX / Voice buses | Not Started | AudioSystem GDD specifies `set_bus_volume(bus_name, volume_db)` for all buses |
| Subtitles on/off | All voiced content | Not Started | When voice acting is implemented |

---

## Per-Feature Accessibility Matrix (MVP Systems)

| System | Visual Concerns | Motor Concerns | Cognitive Concerns | Auditory Concerns | Addressed |
|--------|----------------|---------------|-------------------|------------------|-----------|
| Timing Combat System | Grade colors | Timing windows require frame-precise input | Track turn order + enemy conditions + own resources | Combat SFX carry state info (incapacitated, condition change) | Partial (color backup planned; timing adjust deferred) |
| Input & Timing Detection | Window progress bar color | Frame-counted button press | Understand PERFECT/GOOD/MISS grading | Window tick audio | Partial (grade text labels; timing adjust deferred) |
| Ability System | Ability effect text size | Timing windows per ability | Multiple abilities to choose from | SFX per ability | Not Started |
| Status Effects | Effect icon colors | None (turn-based application) | Track multiple active effects + durations | Apply/expire SFX | Not Started (icon shape backup needed) |
| HUD System | All HUD readability | None | Information density (HP, status, turn order, abilities) | None | Not Started |
| Audio System | N/A | N/A | N/A | Volume controls required | Not Started |
| Dialogue System | Subtitle readability | None (turn-based dialogue) | Long dialogue trees | Voiced lines need subtitles | Not Started |
| Party Composition Manager | None | None | Party slot management + guest system | None | Not Started |
| Enemy System | Condition state color coding | None | Action rule complexity | Incapacitated SFX | Not Started |

---

## Known Intentional Limitations

| Feature | Tier Required | Why Not Included | Risk / Impact | Mitigation |
|---------|--------------|-----------------|--------------|------------|
| Timing window adjustment | Standard | Solo/small team; timing windows are core to combat identity. Runtime multiplier requires UI work beyond Basic scope. | Affects motor-impaired players who cannot press within frame windows. Also affects players with high input latency. | Timing windows are data-driven (AbilityData.timing_window_frames); multiplier is architecturally possible for post-launch. MISS grade still resolves the ability (reduced effect), so the game is completable without good timing. |
| Full input remapping | Standard | Requires UI for rebinding + conflict detection + persistence. Beyond Basic scope. | Affects players who cannot use default key bindings. | Gamepad support provides an alternative input method. Steam Input allows system-level remapping on PC. |
| Colorblind modes | Standard | Requires alternate palette system + shader or color swap infrastructure. | Affects ~8% of male players for red-green discrimination. | Basic tier color-only audit ensures all color-coded elements have non-color backups (icons, shapes, text). |
| Screen reader (menus) | Comprehensive | Godot 4.5+ AccessKit covers Control nodes, but integration requires accessibility node annotation on all menus. | Affects blind players navigating menus. | Keyboard/gamepad navigation provides structure; menu items are labeled. |

---

## Audit History

| Date | Auditor | Type | Scope | Findings | Status |
|------|---------|------|-------|----------|--------|
| 2026-05-04 | gate-check | Initial commitment | Tier definition + scope | Basic tier committed; 5 known limitations documented | Complete |

---

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| Should MISS grade penalties be reduced further as an accessibility assist? | game-designer | Pre-Production | Unresolved |
| Does Godot 4.6 AccessKit work with CanvasLayer Control nodes (HUD)? | lead-programmer | Before Standard tier upgrade | Unresolved |

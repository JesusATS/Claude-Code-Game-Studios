# Technical Preferences

<!-- Populated by /setup-engine. Updated as the user makes decisions throughout development. -->
<!-- All agents reference this file for project-specific standards and conventions. -->

## Engine & Language

- **Engine**: Godot 4.6
- **Language**: GDScript
- **Rendering**: Compatibility renderer (optimal for 2D pixel art on PC; Forward+ unnecessary overhead for this project)
- **Physics**: Godot 2D Physics (built-in; Jolt physics introduced in 4.6 applies to 3D only — not relevant for this 2D RPG)

## Input & Platform

<!-- Written by /setup-engine. Read by /ux-design, /ux-review, /test-setup, /team-ui, and /dev-story -->
<!-- to scope interaction specs, test helpers, and implementation to the correct input methods. -->

- **Target Platforms**: PC (Steam / Epic Games Store)
- **Input Methods**: Keyboard/Mouse, Gamepad
- **Primary Input**: Keyboard/Mouse
- **Gamepad Support**: Partial (turn-based menus and combat fully support d-pad/left-stick navigation; no analog input required)
- **Touch Support**: None
- **Platform Notes**: All UI and menu navigation must support d-pad navigation for gamepad users. No hover-only interactions. Mouse-centric interactions should always have a keyboard/gamepad equivalent.

## Naming Conventions

- **Classes**: PascalCase (e.g., `BattleManager`, `PartyMember`, `CombatState`)
- **Variables/Functions**: snake_case (e.g., `move_speed`, `take_damage()`, `get_current_hp()`)
- **Signals**: snake_case past tense (e.g., `health_changed`, `guest_departed`, `combo_triggered`)
- **Files**: snake_case matching class (e.g., `battle_manager.gd`, `party_member.gd`)
- **Scenes/Prefabs**: PascalCase matching root node (e.g., `BattleManager.tscn`, `PartyMember.tscn`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `MAX_HEALTH`, `TIMING_WINDOW_FRAMES`, `MAX_PARTY_SIZE`)

## Performance Budgets

- **Target Framerate**: 60fps
- **Frame Budget**: 16.6ms
- **Draw Calls**: 200 (soft limit for 2D; pixel art turn-based RPGs rarely approach this)
- **Memory Ceiling**: 512MB

## Testing

- **Framework**: GdUnit4 (GdUnitTestSuite — `extends GdUnitTestSuite`; runner: `tests/gdunit4_runner.gd`)
- **Minimum Coverage**: [TO BE CONFIGURED — set when first test suite is written]
- **Required Tests**: Balance formulas, combat timing system, guest ability inheritance logic, party state management

## Forbidden Patterns

<!-- Add patterns that should never appear in this project's codebase -->
- [None configured yet — add as architectural decisions are made]

## Allowed Libraries / Addons

<!-- Add approved third-party dependencies here -->
<!-- Only add a library when it is actively being integrated, not speculatively -->
- [None configured yet — add as dependencies are approved]

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
- [No ADRs yet — use /architecture-decision to create one]

## Engine Specialists

<!-- Written by /setup-engine when engine is configured. -->
<!-- Read by /code-review, /architecture-decision, /architecture-review, and team skills -->
<!-- to know which specialist to spawn for engine-specific validation. -->

- **Primary**: godot-specialist
- **Language/Code Specialist**: godot-gdscript-specialist (all .gd files)
- **Shader Specialist**: godot-shader-specialist (.gdshader files, VisualShader resources)
- **UI Specialist**: godot-specialist (no dedicated UI specialist — primary covers all UI)
- **Additional Specialists**: godot-gdextension-specialist (GDExtension / native C++ bindings only)
- **Routing Notes**: Invoke primary for architecture decisions, ADR validation, and cross-cutting code review. Invoke GDScript specialist for code quality, signal architecture, static typing enforcement, and GDScript idioms. Invoke shader specialist for material design and shader code. Invoke GDExtension specialist only when native extensions are involved.

### File Extension Routing

<!-- Skills use this table to select the right specialist per file type. -->

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| Game code (.gd files) | godot-gdscript-specialist |
| Shader / material files (.gdshader, VisualShader) | godot-shader-specialist |
| UI / screen files (Control nodes, CanvasLayer) | godot-specialist |
| Scene / prefab / level files (.tscn, .tres) | godot-specialist |
| Native extension / plugin files (.gdextension, C++) | godot-gdextension-specialist |
| General architecture review | godot-specialist |

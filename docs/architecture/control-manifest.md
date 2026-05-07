# Control Manifest

> **Engine**: Godot 4.6
> **Last Updated**: 2026-05-07
> **Manifest Version**: 2026-05-07
> **ADRs Covered**: ADR-0001, ADR-0002, ADR-0003, ADR-0004, ADR-0005, ADR-0006, ADR-0007, ADR-0008, ADR-0009, ADR-0010, ADR-0011, ADR-0014, ADR-0015, ADR-0016
> **Status**: Active — regenerate with `/create-control-manifest update` when ADRs change

`Manifest Version` is the date this manifest was generated. Story files embed
this date when created. `/story-readiness` compares a story's embedded version
to this field to detect stories written against stale rules. Always matches
`Last Updated` — they are the same date, serving different consumers.

This manifest is a programmer's quick-reference extracted from all Accepted ADRs,
technical preferences, and engine reference docs. For the reasoning behind each
rule, see the referenced ADR.

---

## Foundation Layer Rules

*Applies to: ResourceRegistry, Autoload setup, CombatEventBus, InputTimingDetector,
StoryState, SceneManager, AudioSystem, scene composition roots*

### Required Patterns

- **All game data (character stats, abilities, status effects, enemies) must be defined as Resource subclasses in standalone `.gd` files with `class_name`.** Store in `res://assets/data/[type]s/` as `.tres` files. — source: ADR-0001
- **Load all data at startup via `ResourceRegistry` Autoload. Never load `.tres` data files mid-encounter.** — source: ADR-0001
- **Reference registry entries by `StringName` ID.** Never hold a direct reference to a registry entry for mutation. Call `get_*_copy(id)` for mutable encounter copies using `resource.duplicate_deep()`. — source: ADR-0001
- **6 Autoloads in this exact load order in Project Settings:** StoryState (1), ResourceRegistry (2), DialogueManager (3), SceneManager (4), CombatEventBus (5), PartyCompositionManager (6). — source: ADR-0002
- **New Autoloads must pass all 3 qualification rules before being added:** (1) state survives scene changes, (2) accessed by 3+ unrelated systems, (3) no scene-specific node dependency. — source: ADR-0002
- **Composition roots retrieve Autoload references with `get_node("/root/AutoloadName")`** once in `_ready()` and inject them into child systems via `initialize()` or property setter. — source: ADR-0002
- **`timing_confirm` must be registered as a standalone action in InputMap**, separate from `ui_accept`. Keyboard: `Space`. Gamepad: `JOY_BUTTON_A`. — source: ADR-0003
- **`InputTimingDetector` must be a direct child of the battle scene root**, not nested under any `CanvasLayer` or HUD node, so `_input()` fires before any HUD node. — source: ADR-0003
- **`CombatEventBus` must have a relay method for every TCS, SE, or AS signal that a persistent system subscribes to.** When adding a new signal, add its relay method to `CombatEventBus` in the same changeset. — source: ADR-0004
- **BattleSceneRoot `_ready()` must connect all TCS, SE, and AS signals to their CombatEventBus relay methods.** See the Composition Root Checklist at the bottom of this manifest. — source: ADR-0004
- **All `RefCounted` subclasses that appear in typed arrays, typed dicts, or public method signatures must be declared in standalone `.gd` files** with a globally unique `class_name`. — source: ADR-0005
- **Use typed collections in all public APIs:** `Array[T]` for arrays, `Dictionary[K, V]` for dictionaries. — source: ADR-0005
- **Pre-allocate all AudioSystem nodes at `_ready()`: 5 music players + 12 SFX pool nodes.** Zero runtime node allocation. — source: ADR-0011
- **SFX pool: 4 PROTECTED slots (grade tones — never evicted) + 8 STANDARD slots (LRU eviction).** — source: ADR-0011
- **`play_sfx_delayed()` must use `get_tree().create_timer(delay).timeout`.** No custom timer class. — source: ADR-0011
- **4 audio buses: Master, Music, SFX, UI — configured in the `.tres` project resource, never in code.** — source: ADR-0011
- **AudioSystem is NOT an Autoload.** It must be injected into BattleSceneRoot via composition root. — source: ADR-0011

### Forbidden Approaches

- **Never define game data as GDScript constants, dictionaries, or inline literals.** All gameplay values must be in `.tres` files loaded by ResourceRegistry. — source: ADR-0001
- **Never store structured game data as JSON files loaded via FileAccess.** — source: ADR-0001
- **Never define a `class_name X extends Resource` schema as an inner class.** — source: ADR-0001
- **Never call `get_node("/root/AutoloadName")` inside leaf systems** (AbilitySystem, StatusEffects, TCS, etc.). Only composition roots may retrieve Autoload references. — source: ADR-0002
- **Never add a system to the Autoload list without passing the 3-rule criterion.** AudioSystem, TCS, and other encounter-scoped systems must not be Autoloads. — source: ADR-0002
- **Never alias `timing_confirm` to `ui_accept` in InputMap.** — source: ADR-0003
- **Never leave HUD input enabled during an active ITD timing window.** Call `set_process_input(false)` on `window_opened`; restore on `window_closed`. — source: ADR-0003
- **Never declare `class_name X extends RefCounted` as an inner class.** — source: ADR-0005
- **Never use untyped `Array` or `Dictionary` in any public method signature or class property.** — source: ADR-0005
- **Never call `duplicate_deep()` on `RefCounted` subclasses** — not supported. Implement explicit `duplicate() -> ClassName` if copy semantics are needed. — source: ADR-0005
- **Never allocate audio nodes at runtime (outside `_ready()`).** — source: ADR-0011
- **Never configure audio buses in code** — use the .tres resource file. — source: ADR-0011

### Performance Guardrails

- **ResourceRegistry startup load**: monitor against 500ms on target hardware. — source: ADR-0001
- **AudioSystem: maximum 12 simultaneous SFX channels.** Pool enforces this via PROTECTED/STANDARD slot separation. — source: ADR-0011

---

## Core Layer Rules

*Applies to: TimingCombatSystem FSM, InputTimingDetector FSM, CharacterStatsUtil,
StatusEffects, AbilitySystem, PartyCompositionManager, enemy condition evaluation*

### Required Patterns

- **Combat uses a 14-state signal-driven FSM (IDLE through ENCOUNTER_END).** — source: ADR-0006
- **Use `CONNECT_ONE_SHOT` when TCS waits on ITD signals.** — source: ADR-0006
- **Canonical combatant ID is `int` inside TCS:** party slots 1–4, enemies 101+. — source: ADR-0006
- **Relay boundary converts int→StringName via `str(instance_id)`.** — source: ADR-0006
- **TCS owns enemy HP during combat via `_enemy_hp: Dictionary[int, int]`.** — source: ADR-0006
- **Party HP is mutated directly on CharacterData references obtained from PCM.** — source: ADR-0006
- **`force_close_window()` on TCS must delegate to `itd.force_close_window()` (no-op in IDLE).** — source: ADR-0006
- **Enemy AI evaluation uses a fresh `encounter_state` Dictionary built per turn — never reused.** — source: ADR-0006
- **AudioSystem injected directly into TCS; TCS calls `begin_combat_layer()`/`end_combat_layer()` directly.** Other audio events go via CombatEventBus. — source: ADR-0006
- **CombatEnvironmentController owns all CanvasModulate writes.** No other node writes CanvasModulate. — source: ADR-0006
- **`cc_changed` must be emitted once per action resolution, coalesced from `_pending_cc_delta`.** — source: ADR-0006
- **All effective stat computation must go through `CharacterStatsUtil.effective_stat()`.** — source: ADR-0007
- **Stat layering order: base + inheritance_sum + status_modifier_sum, clamped to [1, 99].** — source: ADR-0007
- **Use `int(value + 0.5)` for rounding (round-half-up).** — source: ADR-0007
- **`WINDOW_SCALE_FACTOR` must be defined exactly once in `CharacterStatsUtil`.** — source: ADR-0007
- **ITD FSM uses exactly 4 states: IDLE, ACTION_WINDOW, BLOCK_WINDOW, BLOCK_FORGIVENESS.** — source: ADR-0008
- **`_input()` only sets `_input_received = true`. All ITD state transitions happen in `_physics_process()`.** — source: ADR-0008
- **Pending-open flags (`_pending_action_frames`, `_pending_block_frames`) resolve BLOCK-over-ACTION priority.** — source: ADR-0008
- **State must be reset BEFORE emitting signals in `_close_window_with_grade()` (re-entrancy safety).** — source: ADR-0008
- **`inject_input()` and `advance_frame()` are test-only seams — never callable from production code.** — source: ADR-0008
- **`ability_resolved` signal must be connected with `CONNECT_DEFAULT` (synchronous — never deferred).** — source: ADR-0009
- **SE uses `int instance_id` for all APIs; AS uses `StringName character_id`.** — source: ADR-0009
- **TCS maintains `_instance_to_char_id: Dictionary[int, StringName]` for the int→StringName boundary conversion.** — source: ADR-0009
- **`CharacterStatsUtil.effective_flux()` enforces `EFFECTIVE_FLUX_FLOOR = 8`.** TCS must call `effective_flux()` (not `effective_stat()`) for FLUX. — source: ADR-0009
- **`get_active_effects()` must return independent copies.** — source: ADR-0009
- **`MAX_PARTY_SIZE = 4` is the sole hardcoded party constant.** All downstream code references `PartyCompositionManager.MAX_PARTY_SIZE`. — source: ADR-0010
- **`get_active_combatants()` returns a shallow copy** (new Array, same object references — never deep-copy the result). — source: ADR-0010
- **`get_party_snapshot()` uses String keys ("1"–"4") for JSON round-trip safety.** Never int keys. — source: ADR-0010
- **Every PCM public method must check the `_initialized` guard and return a safe default on failure.** — source: ADR-0010
- **`_get_condition_state()` is private on TCS; derived lazily from HP ratio; never stored as a persistent field (cached previous state IS stored for transition detection).** — source: ADR-0015
- **`_check_condition_transition()` must be called after every HP mutation on an enemy — always via the `_apply_enemy_damage()` helper, never by writing `_enemy_hp` directly.** — source: ADR-0015
- **`get_exact_hp()` is gated behind `_scan_unlocked[instance_id]` — returns -1 with `push_error` if Scan not resolved.** — source: ADR-0015
- **Multi-hit: use `_pending_hits_remaining` counter; BLOCK_RESOLVE routes back to BLOCK_WINDOW for each remaining hit.** — source: ADR-0015
- **`_enemy_condition_states`, `_enemy_stinger_tiers`, `_scan_unlocked`, and `_pending_hits_remaining` must all be cleared at ENCOUNTER_END.** — source: ADR-0015

### Forbidden Approaches

- **Never use a coroutine-based FSM (`await` chain for state machine transitions).** — source: ADR-0006
- **Never compute effective stats inline in any system other than `CharacterStatsUtil`.** — source: ADR-0007
- **Never use `round()` for stat computation** — use `int(value + 0.5)`. — source: ADR-0007
- **Never define `WINDOW_SCALE_FACTOR` outside `CharacterStatsUtil`.** — source: ADR-0007
- **Never call `inject_input()` or `advance_frame()` from production code.** — source: ADR-0008
- **Never connect `ability_resolved` with `CONNECT_DEFERRED`.** — source: ADR-0009
- **SE's `_on_ability_resolved` must NOT call back into TCS** — re-entrancy risk. — source: ADR-0009
- **Never write to `_enemy_hp` directly** — always use `_apply_enemy_damage()` so `_check_condition_transition()` fires. — source: ADR-0015
- **Never call `get_exact_hp()` without verifying scan unlock state.** — source: ADR-0015

### Performance Guardrails

- **Enemy AI: build a fresh `encounter_state` Dictionary per turn.** Reusing state dictionaries causes stale reads. — source: ADR-0006
- **TCS: coalesce all CC changes per action resolution into a single `cc_changed` emission.** — source: ADR-0006

---

## Feature Layer Rules

*Applies to: AbilitySystem inherited unlock, guest departure mechanics, SaveSystem integration*

### Required Patterns

- **`unlock_inherited_ability(receiving_char_id, ability_id, source_guest_id, chapter)` must be idempotent.** Duplicate calls are no-ops with `push_warning`. — source: ADR-0016
- **Validate before unlock: `ability_id` must exist in ResourceRegistry AND have `category = &"INHERITED"`.** — source: ADR-0016
- **Buffer `ability_list_changed` when `_encounter_active = true`; flush via `on_encounter_ended()`.** — source: ADR-0016
- **Use `serialize_unlock_records()` / `deserialize_unlock_records()` for all Save System integration.** — source: ADR-0016
- **Serialized unlock records must use String keys for JSON round-trip safety.** — source: ADR-0016
- **Do not emit `ability_list_changed` at load time (HUD not yet active at deserialization).** — source: ADR-0016
- **`EnemyActionRule` and `ConditionExpr` must be standalone `class_name extends RefCounted` files** in `src/gameplay/enemy/`. — source: ADR-0005
- **TCS and SE must not know about `CombatEventBus`.** BattleSceneRoot connects TCS/SE signals to bus relay methods. — source: ADR-0004

### Forbidden Approaches

- **Never emit `ability_list_changed` during an active encounter** — buffer it; flush on `on_encounter_ended()`. — source: ADR-0016
- **Never emit `ability_list_changed` at load time.** — source: ADR-0016
- **TCS must never call `CombatEventBus.emit_signal()` or any bus method directly.** Bus wiring is exclusively the composition root's responsibility. — source: ADR-0004

---

## Presentation Layer Rules

*Applies to: HUD CanvasLayer structure, HUDInputRouter, TimingBar, AudioSystem integration,
persistent signal subscriptions*

### Required Patterns

- **3 CanvasLayers (10, 11, 12) — each must have exactly one Node2D as its direct child (container node) for modulate tweening.** — source: ADR-0014
- **All HUD elements must be children of the Node2D container — never direct children of the CanvasLayer node.** — source: ADR-0014
- **TimingBar uses `_process()` delta accumulation for ratio-driven animation — NOT ITD tick signals.** — source: ADR-0014
- **PERFECT flash uses the two-await coroutine pattern: `await get_tree().process_frame` called twice.** — source: ADR-0014
- **Use a custom `HUDInputRouter` (Node) for HUD d-pad navigation — NOT Godot Control dual-focus.** `HUDInputRouter` maintains independent `_gamepad_index` and `_mouse_hover_index` state. — source: ADR-0014
- **HUDLayer10Root and HUDLayer11Root receive modulate tween on `encounter_ended`. HUDLayer12Root does NOT.** — source: ADR-0014
- **`timing_confirm` must never be handled by HUDInputRouter.** — source: ADR-0014, ADR-0003
- **HUDSystem and AudioSystem must subscribe to `CombatEventBus` signals in `_ready()`.** Subscriptions are permanent for the session — no re-subscription per battle. — source: ADR-0004
- **All passive HUD Controls (HP bars, status icons, turn order display) must set `mouse_filter = Control.MOUSE_FILTER_IGNORE`** unless they require mouse interaction. — source: ADR-0003
- **In Godot 4.6, `grab_focus()` only sets keyboard/gamepad focus, not mouse focus.** Design interactive elements to support both independently. — source: ADR-0003

### Forbidden Approaches

- **Never place HUD elements as direct children of a CanvasLayer node** — breaks modulate tweening. — source: ADR-0014
- **Never use Timer nodes or `_process()` polling for PERFECT flash timing** — use the two `await get_tree().process_frame` pattern. — source: ADR-0014
- **Never handle `timing_confirm` in HUDInputRouter.** — source: ADR-0014
- **Persistent systems (HUDSystem, AudioSystem) must never connect directly to TCS, SE, or any battle-scoped node's signals.** Use CombatEventBus instead. — source: ADR-0004
- **Never use hover-only interactions.** All interactive elements must have a keyboard/gamepad equivalent. — source: technical-preferences.md

---

## Global Rules (All Layers)

### Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Classes | PascalCase | `BattleManager`, `StatusTracker`, `CharacterData` |
| Variables / Functions | snake_case | `move_speed`, `take_damage()`, `get_current_hp()` |
| Signals | snake_case past tense | `health_changed`, `ability_resolved`, `encounter_started` |
| Files | snake_case matching class | `battle_manager.gd`, `status_tracker.gd` |
| Scenes | PascalCase matching root node | `BattleScene.tscn`, `HUDSystem.tscn` |
| Constants | UPPER_SNAKE_CASE | `MAX_PARTY_SIZE`, `TIMING_WINDOW_FRAMES`, `EFFECTIVE_FLUX_FLOOR` |
| `StringName` IDs | snake_case prefixed with `&` | `&"char_lyra"`, `&"ability_strike"`, `&"timing_confirm"` |

Source: technical-preferences.md

### Performance Budgets

| Target | Value | Notes |
|--------|-------|-------|
| Framerate | 60fps | Hard target |
| Frame budget | 16.6ms | Total per frame |
| Draw calls | 200 | Soft limit; 2D pixel art turn-based RPG rarely approaches this |
| Memory ceiling | 512MB | All runtime assets |
| ResourceRegistry load | < 500ms | Startup only; no per-frame cost |
| SFX channels | 12 max | Pool enforced by AudioSystem |

Source: technical-preferences.md, ADR-0001, ADR-0011

### Engine & Renderer

| Setting | Value |
|---------|-------|
| Engine | Godot 4.6 |
| Language | GDScript |
| Renderer | Compatibility (optimal for 2D pixel art on PC) |
| Physics (2D) | Godot 2D Physics (Jolt is 3D only — unchanged for this 2D project) |
| Windows default backend | D3D12 (Godot 4.6 default — note for platform-specific rendering decisions) |

Source: technical-preferences.md, docs/engine-reference/godot/VERSION.md

### Cross-Cutting Constraints

- **All public methods must be unit-testable via dependency injection.** Do not hardcode dependencies — receive them via `initialize()` or property setter. — source: coding-standards.md
- **Gameplay values must never be hardcoded** (except `MAX_PARTY_SIZE = 4` per ADR-0010). All balance values live in `.tres` Resource files under `res://assets/data/`. — source: coding-standards.md + ADR-0001
- **Every system must have a corresponding ADR in `docs/architecture/`.** — source: coding-standards.md
- **Commits must reference the relevant design document or story ID.** — source: coding-standards.md
- **`StringName` (e.g., `&"ability_strike"`) must be used for all ID lookups in hot paths,** not raw `String`. `StringName` is interned — O(1) equality. — source: ADR-0001

### Forbidden APIs (Godot 4.6)

These APIs are deprecated or superseded — do not use them:

| Deprecated | Use Instead | Source |
|-----------|------------|--------|
| `TileMap` | `TileMapLayer` | deprecated-apis.md |
| `yield()` | `await signal` | deprecated-apis.md |
| `connect("signal_name", obj, "method_name")` | `signal.connect(callable)` | deprecated-apis.md |
| `instance()` / `PackedScene.instance()` | `instantiate()` / `PackedScene.instantiate()` | deprecated-apis.md |
| `OS.get_ticks_msec()` | `Time.get_ticks_msec()` | deprecated-apis.md |
| `duplicate()` on nested Resources | `duplicate_deep()` | deprecated-apis.md |
| `Skeleton3D` signal `bone_pose_updated` | `skeleton_updated` | deprecated-apis.md |
| `AnimationPlayer.method_call_mode` | `AnimationMixer.callback_mode_method` | deprecated-apis.md |
| `AnimationPlayer.playback_active` | `AnimationMixer.active` | deprecated-apis.md |
| `Texture2D` in shader parameters | `Texture` base type | deprecated-apis.md |
| `$NodePath` in `_process()` | `@onready var` cached reference | deprecated-apis.md |
| `round()` for stat computation | `int(value + 0.5)` (round-half-up) | ADR-0007 |
| Untyped `Array` or `Dictionary` in public API | `Array[T]` / `Dictionary[K, V]` | ADR-0005 |

### Forbidden Patterns (All Layers)

| Pattern | Rule | Source |
|---------|------|--------|
| String-based signal connect | Use typed signal: `signal.connect(callable)` | deprecated-apis.md |
| Hardcoded game data | Use `.tres` Resource files in `res://assets/data/` | ADR-0001 |
| JSON/FileAccess for structured schemas | Use Resource subclasses | ADR-0001 |
| Inner-class `class_name extends Resource` or `RefCounted` | Use standalone `.gd` file | ADR-0001, ADR-0005 |
| Direct Autoload name access in leaf systems | Use dependency injection | ADR-0002 |
| New Autoload without passing 3-rule criterion | Must satisfy all 3 rules | ADR-0002 |
| `timing_confirm` aliased to `ui_accept` | Separate InputMap entries | ADR-0003 |
| HUD input active during ITD timing window | Disable via `set_process_input(false)` | ADR-0003 |
| Persistent system → direct battle-scoped signal connection | Subscribe to CombatEventBus | ADR-0004 |
| TCS calling CombatEventBus directly | Bus wiring is composition root's job | ADR-0004 |
| Coroutine-based FSM (`await` chain) | Signal-driven FSM with state enum | ADR-0006 |
| Inline effective stat computation | Use `CharacterStatsUtil.effective_stat()` | ADR-0007 |
| `round()` for rounding | `int(value + 0.5)` | ADR-0007 |
| `inject_input()` / `advance_frame()` in production code | Test-only seams | ADR-0008 |
| `ability_resolved` connected with `CONNECT_DEFERRED` | Must be `CONNECT_DEFAULT` | ADR-0009 |
| Direct write to `_enemy_hp` | Always use `_apply_enemy_damage()` | ADR-0015 |
| `ability_list_changed` emitted during encounter | Buffer; flush on `on_encounter_ended()` | ADR-0016 |
| HUD elements as direct CanvasLayer children | Must be children of Node2D container | ADR-0014 |
| Timer nodes for PERFECT flash | Two-await `get_tree().process_frame` pattern | ADR-0014 |
| Hover-only UI interactions | Keyboard/gamepad equivalent required | technical-preferences.md |

---

### Composition Root Checklist (BattleSceneRoot `_ready()`)

Every battle scene root must wire these connections:

```
[ ] ITD.window_opened          → _hud_root.set_process_input(false) + set_process_unhandled_input(false)
[ ] ITD.window_closed          → _hud_root.set_process_input(true)  + set_process_unhandled_input(true)
[ ] TCS.encounter_started      → bus.relay_encounter_started
[ ] TCS.encounter_ended        → bus.relay_encounter_ended
[ ] TCS.turn_started           → bus.relay_turn_started
[ ] TCS.turn_ended             → bus.relay_turn_ended
[ ] TCS.damage_dealt           → bus.relay_damage_dealt
[ ] TCS.combatant_incapacitated → bus.relay_combatant_incapacitated
[ ] TCS.hp_danger_zone_entered → bus.relay_hp_danger_zone_entered
[ ] TCS.enemy_condition_changed → bus.relay_enemy_condition_changed
[ ] TCS.hp_changed             → bus.relay_hp_changed
[ ] TCS.cc_changed             → bus.relay_cc_changed
[ ] TCS.scan_resolved          → bus.relay_scan_resolved
[ ] SE.status_effect_applied   → bus.relay_status_effect_applied
[ ] SE.status_effect_expired   → bus.relay_status_effect_expired
[ ] SE.status_effect_tick      → bus.relay_status_effect_tick
[ ] AS.ability_list_changed    → bus.relay_ability_list_changed
```

Source: ADR-0003, ADR-0004, ADR-0015

### Smoke Tests Required Before Implementation

| Test | Why | Source |
|------|-----|--------|
| `resource.duplicate_deep()` on `Array[CharacterData]` — verify element identity | `duplicate_deep()` behavior on typed RefCounted arrays unverified in Godot 4.6 | ADR-0001 |
| `Array[StatusTracker]` compiles in strict mode | Confirm typed RefCounted arrays resolve cross-file | ADR-0005 |
| `CombatEventBus` emits nothing after TCS freed | Verify Godot auto-disconnect on node free | ADR-0004 |
| `timing_confirm` not consumed by focused HUD Control during window | Dual-focus system verification | ADR-0003 |
| `get_tree().process_frame` fires twice correctly in PERFECT flash | Two-await pattern in Godot 4.6 | ADR-0014 |
| `ability_list_changed` not emitted during `unlock_inherited_ability()` when encounter active | Buffering correctness | ADR-0016 |

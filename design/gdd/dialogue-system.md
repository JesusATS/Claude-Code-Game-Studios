# Dialogue System

> **Status**: In Design
> **Author**: Jesus Gallegos + agents
> **Last Updated**: 2026-04-29 (Revision Pass 4)
> **Implements Pillar**: Pillar 1 (Story Earns Its Emotion), Pillar 4 (The World Has Memory)

## Overview

The Dialogue System is *Lux Aeterna*'s conversation engine — the infrastructure that delivers every spoken line, manages branching based on story state, and ensures that characters remember what the player has done. It operates as a `DialogueManager` Autoload backed by `DialogueGraph` data resources: authored conversation trees where each node specifies a speaker, a line of text, optional flag conditions evaluated against StoryState, and connections to subsequent nodes. At runtime, the manager evaluates the active graph's conditions via `StoryState.check_flag()`, selects the appropriate branch, and dispatches the resolved speaker, text, and choices to the dialogue UI. For emotionally significant events, condition checks against Narrative Event flags — Dictionaries carrying agent, circumstances, and witness context — allow the system to produce fully differentiated responses: Kakus's words in the sanctuary after Kia's death are not a generic "she is gone" but reflect who killed her and who was present. The player experiences this as a world that registers what they have done: conversations that are different the second time through, NPCs who know what happened without being told, and companions whose words carry the weight of shared history. The Dialogue System is the primary vehicle for Pillar 1 (Story Earns Its Emotion) and the audible expression of Pillar 4 (The World Has Memory).

## Player Fantasy

The player feels *known* — not by the game, but by the people in it.

When Kakus speaks in the sanctuary after Kia's death, his words are not a generic grief line. They reflect who was standing there when it happened, who dealt the blow, who he had to look in the eye afterward. The player did not simply "progress the story." They were *present*, and presence has a cost — one that Kakus carries in every syllable.

This is the fantasy the Dialogue System delivers: conversations that are addressed to *you*, the specific person who made those specific choices. NPCs who know what happened without being told. Companions whose words carry the weight of shared history. Lines that can only appear once, because the circumstances that produced them will never align again.

The Dialogue System is not the vehicle for exposition. It is the vehicle for recognition.

**Authoring convention — legible recognition:** Context-sensitive lines must make their specificity legible within the line's own content. A line that is different because Clawd was present should contain language that would only make sense if Clawd was present. A player hearing the line for the first time must be able to feel it is addressed to them specifically — not by a UI label, but by what the words say. "You were there when it happened" is recognition. "She is gone" is not, even when delivered through a contextual branch. Writers must apply this test to every context-sensitive line before authoring is considered complete.

## Detailed Rules

### C.1 Data Model

The Dialogue System's authoring unit is the `DialogueGraph` — a custom `Resource` stored as a `.tres` file in `assets/data/dialogue/`.

**Implementation requirement — `class_name` and standalone files:** `DialogueGraph`, `DialogueNode`, `DialogueCondition`, `DialogueChoice`, and `DialogueFlagWrite` must each be declared in their own `.gd` file with `class_name [X] extends Resource` at the top of that file. Inner classes within another script do NOT receive globally registered type names in Godot 4 and will fail to deserialize from `.tres` — all typed property accesses would silently return `null` at load time. All serialized fields must be annotated `@export`.

Each graph contains:

- **`nodes: Array[DialogueNode]`** — ordered list of all nodes in the graph. Each node carries:
  - `id: int` — unique within the graph; used by edges to reference targets. Must be stable across graph revisions — do not use auto-assigned sequential IDs that renumber when nodes are added or removed. Assign IDs manually and treat them as permanent. **Node IDs must be non-negative integers. `-1` is a reserved sentinel meaning "no target" (used by `next` on end nodes and the `else_next` default) and must never be assigned as a node ID by the authoring tool.**
  - `type: StringName` — one of `&"line"`, `&"choice"`, `&"conditional"`, `&"end"`
  - `speaker: StringName` — references an entity ID from the entity registry (e.g. `&"kakus"`, `&"clawd"`); empty for narration
  - `text: String` — the line of dialogue or narration text. Supports RichTextLabel BBCode markup (e.g. `[b]`, `[i]`, `[color]`) for emphasis. Use `\n` for manual line breaks. Typewriter pause convention: `[pause=0.3]` tag signals a mid-line pause to the text-reveal animation (duration in seconds). Maximum 140 characters recommended (soft cap); 180 characters is the hard authoring limit enforced by the graph validator at export time.
  - `condition_mode: StringName` — one of `&"and"` (default) or `&"or"`. Controls how the `conditions` array is aggregated: `&"and"` requires all conditions to pass; `&"or"` requires any one condition to pass. **Present on all node types for schema simplicity; evaluated only on `&"conditional"` and `&"choice"` nodes.** Has no effect on `&"line"` or `&"end"` nodes at runtime. Writers must not place a non-empty `conditions` array on non-conditional nodes; the validator emits `push_error` if they do (see E.2). See C.3 for evaluation semantics.
  - `conditions: Array[DialogueCondition]` — zero or more flag conditions evaluated according to `condition_mode` (see C.3)
  - `next: int` — ID of the default successor node; `-1` for end nodes
  - `else_next: int` — ID of the else-branch node on `&"conditional"` nodes. Must be set to a valid node ID on every `&"conditional"` node; the `choices` array on a conditional node is always empty (see C.2). If the desired behavior is "no else branch, just continue normally," point `else_next` to the same node as `next`.
  - `choices: Array[DialogueChoice]` — populated only on `&"choice"` nodes (see C.5). Always empty on `&"conditional"` nodes.
  - `set_flags: Array[DialogueFlagWrite]` — zero or more flag writes that fire before the node is dispatched (see C.4 step 4). Applicable to `&"line"` and `&"choice"` nodes.
  - `is_recognition: bool` — authored field; set to `true` by the writer on nodes where the delivered line is emotionally context-specific and the player should receive the recognition visual accent. Defaults to `false`. This is an authoring judgment — the writer decides which lines carry recognition weight, not the condition operator type. Applies to `&"line"` and `&"choice"` nodes; has no effect on `&"conditional"` or `&"end"` nodes.
  - `importance: StringName` — one of `&"normal"` (default) or `&"critical"`. `&"critical"` activates the hold-to-confirm advance pattern on this node: the player must hold `ui_accept` for `HOLD_TO_REREAD_MS` to advance (rather than tap). Use `&"critical"` on one-shot lines and guest departure exchanges where a reflexive tap must not dismiss the moment. Applies to `&"line"` nodes only; has no effect on other node types.
- **`DialogueCondition`** — an inner resource with:
  - `flag_id: StringName` — the flag to check via `StoryState.check_flag()`
  - `operator: StringName` — one of `&"eq"`, `&"neq"`, `&"gt"`, `&"lt"`, `&"has_key"` (for Narrative Event Dictionary field checks)
  - `operand: Variant` — the value to compare against. **Type discipline is critical:** GDScript `String != StringName` in equality comparison (`"clawd" == &"clawd"` is `false`). For `&"eq"` / `&"neq"` on entity-type flags (where `StoryState` stores a `StringName`), author `operand` as `StringName` (prefix with `&`). For `&"eq"` / `&"neq"` on string-value flags (where `StoryState` stores a plain `String`, e.g. `CLAWD_CLASS_CHOSEN`), use `String` (no prefix). Mismatching types silently fails the condition every time with no runtime error. The GDScript type annotation for every `@export` field on all Resource subclasses must be explicit (e.g. `@export var operator: StringName`) — never `Variant` except for `operand` and `DialogueFlagWrite.value`, where multi-type support is required. **Godot inspector serialization warning:** The Godot editor inspector presents `@export var operand: Variant` fields as plain `String` entries by default. A correctly-intended `StringName` operand (e.g. `&"kakus"`) may be silently stored as a `String` when edited through the inspector, causing the condition to always fail. Reliable `StringName` operands require either (a) hand-editing the `.tres` text to include the `&` prefix tag, or (b) authoring via the OQ-3 `@tool` validator script which checks `typeof(operand)` post-deserialization against the known stored type of that `flag_id` in `StoryState`.
  - `field: StringName` — for `&"has_key"` / field-access checks on Narrative Event flags; empty for scalar flags

- **`DialogueChoice`** — an inner resource with:
  - `label: String` — text displayed on the choice button. **Maximum 60 characters (hard authoring limit enforced by the graph validator at export time).** Labels exceeding this limit will wrap inside the choice button, increasing button height unpredictably and breaking the combined dialogue + choice panel layout budget.
  - `display: StringName` — one of `&"hidden"` (default) or `&"locked"`. Controls how a choice is rendered when its conditions fail: `&"hidden"` removes the choice entirely; `&"locked"` keeps it visible but greyed out and unselectable. Use `&"locked"` for choices gated by player history (the inaccessible choice communicates consequence). Use `&"hidden"` for choices that were never contextually valid in this scene. **Authoring convention for locked labels:** The label convention for locked choices — whether to describe the precondition (transparent) or to be deliberately opaque — is a narrative direction decision. See the narrative style guide for the project-level stance. Whichever convention is chosen, the label must be consistent and intentional, not a production accident. **`display` is consulted exclusively for rendering choices whose conditions fail; when conditions pass, `display` is irrelevant to selectability — a `&"locked"` choice whose conditions pass is fully selectable (see AC-37).**
  - `condition_mode: StringName` — one of `&"and"` (default) or `&"or"`. Controls how this choice's `conditions` array is aggregated.
  - `conditions: Array[DialogueCondition]` — conditions that must pass for this choice to be fully active (selectable)
  - `next: int` — ID of the node reached when this choice is selected. Must be a valid node ID (non-negative integer pointing to an existing node in the graph). `-1` is not a valid value on `DialogueChoice.next` — the graph validator will reject any choice whose `next` is `-1` or points to a non-existent node ID.

- **`DialogueFlagWrite`** — a lightweight inner resource on `DialogueNode`:
  - `flag_id: StringName`
  - `value: Variant` — must be one of `bool`, `int`, `String`, `StringName`, or `Dictionary` (Narrative Event). No other types. `StringName` is permitted here because entity-type flags stored as `StringName` in `StoryState` must be written with a `StringName` value for the write-then-read round-trip to work (a `String` write followed by a `StringName` read produces a type mismatch on the downstream condition check). Apply the same String/StringName type discipline described under `DialogueCondition.operand`. **Runtime type validation:** `DialogueManager` checks `typeof(value)` before calling `StoryState.set_flag()`. On an unsupported type: `push_error("DialogueManager: DialogueFlagWrite on node [id] has invalid value type [typeof] — expected bool/int/String/StringName/Dictionary")`, the write is skipped, and the conversation continues normally.

Graphs are stateless: they contain no runtime data. All flag reads go through `StoryState`; all flag writes are explicit `set_flag` calls on specific nodes (see C.4).

### C.2 Node Types

| Type | Purpose | Required fields | Branching behaviour |
|------|---------|-----------------|---------------------|
| `&"line"` | Delivers a single spoken line or narration beat | `speaker`, `text`, `next` | Advances to `next` when player dismisses |
| `&"choice"` | Presents 2–4 player-selectable responses | `text` (optional prompt), `choices` | Advances to the `next` of the selected `DialogueChoice` |
| `&"conditional"` | Silent routing node — no text displayed | `conditions`, `condition_mode`, `next`, `else_next` | Evaluates `conditions` per `condition_mode`; if conditions pass, goes to `next`; otherwise goes to `else_next`. `choices` array is always empty on conditional nodes. |
| `&"end"` | Terminates the conversation | — | Emits `dialogue_ended`; `DialogueManager` unloads the graph |

**Rules:**
- A `&"line"` node with no `text` and no `speaker` is a narration beat (black screen / caption style).
- A `&"conditional"` node must always have both `next` and `else_next` set to valid node IDs. It never has entries in `choices`.
- `&"choice"` nodes must have between 2 and 4 `DialogueChoice` entries. After condition filtering, at least one choice must remain selectable (visible_count ≥ 1 is the runtime floor; visible_count < 2 is an authoring error per E.1). If filtering leaves fewer than 2 selectable choices, see Edge Cases E.1.
- **Locked choices whose conditions pass are selectable** — `display: &"locked"` only affects rendering when conditions fail (greyed, inert). When conditions pass, the choice is rendered and selectable identically to a `&"hidden"` choice that passes. Locked choices whose conditions fail do not count toward `selectable_count` (see D.2).
- Node IDs must be unique within the graph and must be stable — never auto-renumbered during graph authoring or revision. Runtime never reassigns IDs.

### C.3 Condition Evaluation

`DialogueManager` evaluates a conditions array using the node's or choice's `condition_mode`:

- **`&"and"` mode (default):** All conditions must pass. An empty conditions array (`n = 0`) always evaluates to active = true.
- **`&"or"` mode:** Any single condition must pass. An empty conditions array (`n = 0`) always evaluates to active = true.

Conditions are evaluated by calling `StoryState.check_flag(flag_id)` and comparing the result against `operand` using `operator`.

**Operator semantics:**

| Operator | Applies to flag types | Passes when |
|----------|-----------------------|-------------|
| `&"eq"` | `bool`, `int`, `String` | `check_flag(id) == operand` |
| `&"neq"` | `bool`, `int`, `String` | `check_flag(id) != operand` |
| `&"gt"` | `int` | `check_flag(id) > operand` (strict) |
| `&"lt"` | `int` | `check_flag(id) < operand` (strict) |
| `&"has_key"` | `Dictionary` (Narrative Event) | `check_flag(id)` is a Dictionary and `check_flag(id).get(field) == operand` |

**Unset flag behaviour:** If `StoryState.has_flag(flag_id)` returns `false`, `check_flag` returns `null`. Any condition operating on a null value fails silently — it does not crash; the node or choice is treated as inactive (or as "not passing" in `&"or"` mode).

**Narrative Event field access:** To branch on who killed Kia, a condition uses `operator: &"has_key"`, `flag_id: &"KIA_KILLED"`, `field: &"agent"`, `operand: "clawd"`. The system calls `StoryState.check_flag(&"KIA_KILLED").get("agent") == "clawd"`. If `KIA_KILLED` is unset or missing the `agent` key, the condition fails. **Implementation requirement:** before calling `.get(field)`, the evaluator must explicitly guard `typeof(check_flag(id)) == TYPE_DICTIONARY`. Calling `.get()` on a non-Dictionary type in GDScript is a runtime error — it does not fail silently. The `push_error` on type mismatch (E.4) only fires after this guard confirms the type is wrong; the guard itself prevents the crash. A condition with `operator: &"has_key"` on a non-Dictionary flag must fail the condition and emit `push_error`, not crash.

**Multi-flag conditions:** A node using `condition_mode: &"and"` that requires both `KIA_KILLED` to be set AND `CLAWD_PRESENT` to be true uses two `DialogueCondition` entries. Both must pass. A node using `condition_mode: &"or"` that should fire if PALADIN killed Kia OR Clawd was present uses two entries with `&"or"` mode — either passing is sufficient.

**Same-flag OR pattern:** To branch on "agent was PALADIN OR agent was CLAWD," use two `DialogueCondition` entries on the same `KIA_KILLED` flag with different `operand` values and `condition_mode: &"or"`. This is the correct idiom — two conditions checking the same flag with different values.

**Authoring guidance — AND vs OR:** Use `&"and"` (the default) when all conditions must be simultaneously true — this is the safer choice for recognition lines, where specificity is the goal. Use `&"or"` only when the line is intentionally designed to fire under any one of multiple qualifying circumstances AND the line text is valid and specific in every one of those contexts. Misusing `&"or"` where `&"and"` was intended silently produces lines that fire in more contexts than authored, undermining the recognition fantasy.

**Type mismatch:** `push_error` is emitted and the condition fails. See E.4.

### C.4 Runtime Flow

`DialogueManager` is an Autoload singleton. StoryState must be listed above DialogueManager in Godot Project Settings Autoload order. Both Autoloads must complete their `_ready()` synchronously — no `await` or `call_deferred` during initialization.

**Graph integrity validation:** Before beginning traversal, `start()` performs a validation pass on the loaded graph. **Validation runs before any state mutation** (before setting `_current_node_id = 0` or `_active = true`). This ensures a failed validation leaves the manager in a fully idle state with no partial initialization.

Validation uses a **two-tier model**: some violations halt with `assert()` in debug builds (crash-class errors that must never reach a player); others use `push_error` in all builds with a corrective fallback (recoverable authoring errors). The table below specifies which tier applies to each check:

| Check | Tier | Behavior |
|-------|------|----------|
| No two nodes share the same ID | `push_error` (all builds) + abort `start()` + emit `dialogue_ended` | Duplicate ID = silent data corruption; abort is the only safe response. Aborts in release builds too — this is crash-class. `dialogue_ended` emitted so downstream callers (Cutscene System) are not left waiting. |
| Every `next`, `else_next`, `choices[n].next` points to an existing node ID | `push_error` (all builds) + abort `start()` + emit `dialogue_ended` | Dangling reference = null crash mid-traversal in release; abort in all builds. `dialogue_ended` emitted so downstream callers are not left waiting. |
| Every `&"conditional"` node has `next` and `else_next` set to valid non-(-1) node IDs | `assert()` (debug) + `push_error` (release) | Produces wrong-branch routing, not a crash; assert catches during development. |
| Every `condition_mode` is `&"and"` or `&"or"` | `push_error` + correct to `&"and"` | Not a crash; correction allows the graph to run while flagging the error. |
| Every `DialogueChoice.display` is `&"hidden"` or `&"locked"` | `push_error` + treat unknown value as `&"hidden"` | Corrupt selectable_count without this check; non-crash. |
| No reachable cycle through non-conditional node types | `assert()` (debug) | `CONDITIONAL_STACK_DEPTH_LIMIT` catches conditional cycles at runtime; line/choice cycles have no runtime safety net. |
| `&"conditional"` node with zero conditions (`n = 0`) | `push_error` warning (non-halting) | Almost certainly an authoring error; alerts writer without aborting the conversation. |

The DFS for cycle detection uses **path-based tracking** (recursion-stack / gray-white-black coloring): the in-path set tracks only nodes on the current recursion path, not all previously visited nodes globally. A global-visited-only DFS produces false cycle positives on diamond-shaped graphs (two branches converging on a common node), which are valid in dialogue. The DFS traverses all edge types: `next`, `else_next`, and each `choices[n].next`. **The DFS catches all cycles regardless of node type — including cycles formed exclusively through `else_next` edges between `&"conditional"` nodes.** `CONDITIONAL_STACK_DEPTH_LIMIT` is a runtime safety net for non-cycle conditional chains of unusual depth (e.g., 33+ consecutive conditionals in a valid, acyclic graph), not a cycle detector. **All DFS data structures (path tracking, visited set) must be local to the `_validate_graph()` function — allocated on call, not persisted as class-level state on `DialogueManager`. This guarantees that a failed or aborted validation leaves no residual state for the next `start()` call.**

Runtime lifecycle for a single conversation:

1. **Load** — caller invokes `DialogueManager.start(graph: DialogueGraph)`. After the graph integrity validation pass (see above) succeeds: the manager stores a reference to the graph, builds `_node_map: Dictionary[int, DialogueNode]` mapping each `node.id` to its `DialogueNode` reference, sets `_current_node_id` to `0` (the root node, always ID 0 by authoring convention), sets `_active = true`, and resets the conditional depth counter to `0`. **All subsequent node lookups use `_node_map[_current_node_id]` — never `nodes[_current_node_id]` as an array index.** The `nodes: Array[DialogueNode]` exists for serialization ordering only; node IDs are not guaranteed to be contiguous (deleted nodes leave gaps), so array-index lookup silently returns the wrong node on graphs with ID gaps. `_node_map` is cleared when the conversation ends or aborts. `start()` must also be called on an idle manager only — see E.3 for the re-entry guard.

2. **Evaluate** — the manager reads the node at `_current_node_id`:
   - If the node is `&"conditional"`, evaluate conditions silently per C.3 and `condition_mode`. If conditions pass, advance `_current_node_id` to `next`. If conditions fail, advance to `else_next`. **Increment the conditional depth counter first, then compare: `if counter > CONDITIONAL_STACK_DEPTH_LIMIT`.** If the counter exceeds the limit, abort: emit `push_error("DialogueManager: conditional stack depth limit exceeded at graph [graph_id]")`, reset the conditional depth counter to `0`, emit `dialogue_ended`, clear `_current_node_id` to `-1`, and set `_active = false`. The conversation ends; downstream systems (Cutscene System) receive `dialogue_ended` and can continue their sequence. Repeat Evaluate with no UI dispatch.
   - If the node is any other type, reset the conditional depth counter to 0 and proceed to Dispatch.
   - If the node has `conditions` but is a `&"line"` node, this is an authoring error (see E.2).

3. **Flag writes** — if the node carries `set_flags: Array[DialogueFlagWrite]`, `DialogueManager` calls `StoryState.set_flag()` for each entry. Flag writes fire **before** dispatch (step 4). This means the world reacts to these flags before `dialogue_line_ready` is emitted; external systems listening to `StoryState.flag_set` will observe the change before the player sees the line. Authors must not use dialogue flag writes to trigger world-state changes that should appear simultaneous with the line delivery — those changes should be deferred to after `dialogue_line_ready`.

4. **Dispatch** — for `&"line"` and `&"choice"` nodes, emit `dialogue_line_ready(speaker: StringName, text: String, choices: Array[DialogueChoice], is_recognition: bool)`. The UI layer listens to this signal. The UI handler must declare the `choices` parameter as `Array[DialogueChoice]` explicitly in its function signature — untyped connections erase the array type and break all typed helpers. `is_recognition` is read directly from `_current_node.is_recognition` — the authored field on `DialogueNode` (see C.1). The manager does not infer `is_recognition` from condition operators; writers author it explicitly on nodes where the line is emotionally context-specific. For nodes where `is_recognition` was not explicitly set, the default is `false`. The `choices` array dispatched to the UI is always the full unfiltered array (all authored choices, regardless of conditions); UI filtering occurs after dispatch via `filter_choices()` (see C.5). **For `&"line"` nodes (no choices), `choices` is dispatched as `Array[DialogueChoice]()` — the typed empty array constructor, not `[]` (untyped literal). This preserves runtime type safety at the signal boundary in Godot 4.x.**

5. **Advance** — the UI calls `DialogueManager.advance(choice_index: int = -1)` when the player dismisses a line or selects a choice. (`advance()` is a direct method call on the Autoload singleton — not a GDScript signal emission.) **Pre-condition guards:** `advance()` checks the following conditions in order before any graph access: (a) if `_active == false` or `_current_node_id == -1`, emit `push_error` and return immediately; (b) if `_current_node.type == &"end"`, emit `push_error("DialogueManager: advance() called on &\"end\" node — end nodes are processed internally, never via external advance()")` and return immediately; (c) if `_advance_pending == true`, return immediately (single-advance-per-frame guard — see below). **Single-advance-per-frame guard:** `DialogueManager` maintains `_advance_pending: bool`, cleared at the top of `_process()`. On any `advance()` call that passes the pre-condition checks, `_advance_pending` is set to `true` before proceeding. This prevents double-advance when both `Button.pressed` and `_unhandled_input` fire for the same confirm input in Godot 4.6's dual-focus system. `advance()` then uses a three-branch guard:
   - **`choice_index == -1`**: line advance — use `next`. Valid on `&"line"` nodes. Calling `advance(-1)` on a `&"choice"` node is an authoring error (the line-advance signal was sent to a choice node) → `push_error("DialogueManager: advance(-1) called on a choice node — use a choice index")`, then treat as `advance(0)` (route to `choices[0].next`). Graph validation guarantees every `DialogueChoice.next` is a valid non-(-1) node ID, so `choices[0].next` is always a valid target — this is equivalent to the E.1/E.6 first-valid-next scan on validated graphs. Note: this is distinct from the `< -1` guard below.
   - **`choice_index < -1`** (any other negative value, e.g. -2, -100): invalid index — emit `push_error` and apply the E.1/E.6 first-valid-next fallback. GDScript's `choices[-2]` returns the second-to-last element without error — all negative values below -1 must be caught by this guard before any array access, not just -1 specifically.
   - **`choice_index >= 0`**: validate `choice_index < choices.size()` before any array access (see E.6); if out-of-range, emit `push_error` and apply the E.1/E.6 first-valid-next fallback.

   The manager updates `_current_node_id` and returns to Evaluate.

6. **End** — when the manager reaches an `&"end"` node, it emits `dialogue_ended()`, clears `_current_node_id` to `-1`, sets `_active = false`, resets the conditional depth counter to `0`, and releases the graph reference.

### C.5 Choice Presentation

When `DialogueManager` dispatches a `&"choice"` node, the UI receives the full `choices: Array[DialogueChoice]` array. The UI follows this sequence:

1. **Filter via helper** — the UI calls `DialogueManager.filter_choices(choices: Array[DialogueChoice]) -> Array[int]`. This method evaluates each choice's `conditions` array using the same C.3 logic (including `condition_mode`) and returns the original array indices of choices whose conditions pass. The UI must NOT independently re-implement C.3 operator semantics. Centralising evaluation in `DialogueManager` prevents divergence between manager and UI condition logic.

2. **Build index mapping** — the UI builds `_visible_to_original: Array[int]` from the returned indices. This mapping is required: when the player selects rendered position `i`, the UI calls `DialogueManager.advance(_visible_to_original[i])` — the original array index, not the rendered position. Passing the rendered position directly is a silent wrong-branch routing bug.

3. **Render** — the UI iterates the full original `choices` array. For each choice at index `i`:
   - If `i` is in the `filter_choices()` result (conditions pass): choice is rendered normally as a selectable button. `i` is included in `_visible_to_original`.
   - If `i` is NOT in the result AND `choices[i].display == &"locked"`: choice is rendered greyed out with no selection indicator. **`i` is NOT included in `_visible_to_original`** — locked-failing choices have no selectable position and must never be passed to `advance()`.
   - If `i` is NOT in the result AND `choices[i].display == &"hidden"` (or `display` is any other value): choice is not rendered at all. `i` is not included in `_visible_to_original`.

   The UI must NOT re-evaluate conditions to determine render state. The only condition evaluation the UI performs is calling `filter_choices()`. The hidden/locked decision for non-passing choices uses only `choices[i].display` — a field read, not condition evaluation.

   **D-pad navigation:** Focus traversal visits only selectable choices (those in `_visible_to_original`). Pressing d-pad up or down moves focus to the previous or next selectable choice, skipping locked-failing choices between them. No wrap-around: if there is no selectable choice in the pressed direction, focus does not move. Locked-failing choices receive no visual state change during navigation.

4. **Input lock** — when the choice panel first appears, a `CHOICE_INPUT_LOCK_MS` (default 150ms) input lock prevents any choice selection from registering. The lock applies to all input methods (keyboard, gamepad, mouse). **Implementation mechanism for Godot 4.6:** set `mouse_filter = MOUSE_FILTER_IGNORE` on all choice `Button` nodes when the panel first appears; restore `MOUSE_FILTER_STOP` after the lock period via a `get_tree().create_timer(CHOICE_INPUT_LOCK_MS / 1000.0, false).timeout` deferred callback. The `false` `process_always` argument means the timer freezes when the `SceneTree` is paused, which is the correct behavior — the lock correctly resumes on unpause. Additionally, maintain an `_input_locked: bool` flag and guard `_unhandled_input` handling: while `_input_locked` is true, swallow all `ui_accept` events without processing them. `Button.disabled = true` must NOT be used for the lock — it removes the keyboard focus highlight from the initially-selected choice, violating the C.5 step 5 visual contract. Godot 4.6's dual-focus system means mouse hover focus is tracked independently of keyboard/gamepad focus; `mouse_filter` + the `_input_locked` guard together cover both paths. **Critical node carry-over:** When the preceding node had `importance: &"critical"` (requiring a sustained hold to advance), the choice panel must additionally wait for `ui_accept` to return to the unpressed state before any selection registers, regardless of the `CHOICE_INPUT_LOCK_MS` timer. Implement via `if Input.is_action_pressed("ui_accept"): await Input.action_released("ui_accept")` before starting the lock timer. This prevents a released hold from the preceding critical node from registering as an immediate choice selection on the newly appeared panel.

5. **Initial selection** — when the choice panel appears, the first selectable (non-locked) visible choice is automatically highlighted. The player must consciously navigate to change selection before confirming.

6. **Select** — the player selects a choice via keyboard (arrow keys + confirm), gamepad (d-pad + confirm), or mouse click. The UI calls `DialogueManager.advance(_visible_to_original[i])` where `i` is the player's selection index within the visible list.

7. **Minimum floor** — if `filter_choices()` returns zero selectable indices (`selectable_count == 0`, all choices hidden-failing or locked-failing), `DialogueManager` emits `push_error` and follows the E.1 fallback (advance to the first `DialogueChoice` in the original array with `next != -1`, or `dialogue_ended` if none). If `filter_choices()` returns exactly one selectable index (`selectable_count == 1`), `DialogueManager` emits `push_error` and auto-advances to that one selectable choice's `next` without displaying the choice panel. Both cases are always authoring errors — the choice node must have ≥ 2 selectable choices at runtime. **Ownership of these checks:** Both the `selectable_count == 0` and `selectable_count == 1` checks are performed by `DialogueManager` in the Evaluate step (C.4), after receiving the result from `filter_choices()` — not inside `filter_choices()` itself. `filter_choices()` is a pure query helper: it returns filtered indices and has no side effects, emits no signals, and does not mutate conversation state. Placing these checks inside `filter_choices()` would make it a side-effectful helper, violating single-responsibility.

**Dialogue UI lifecycle:** The dialogue UI scene is instantiated by `DialogueManager._ready()` via `add_child(dialogue_ui_instance)` and kept in the scene tree for the full session, hidden when idle. **Parenting the dialogue UI to the `DialogueManager` Autoload is required.** Godot does not free Autoload children on `get_tree().change_scene_to_file()` calls — the UI survives all scene transitions automatically. Do NOT parent the dialogue UI to the game scene root or any non-Autoload node; it will be freed on the first scene transition and signal connections will silently become dead. The UI connects to `DialogueManager.dialogue_line_ready` and `DialogueManager.dialogue_ended` exactly once in its `_ready()` function and never disconnects. Do NOT instantiate and free a new dialogue UI node per conversation, and do NOT connect/disconnect signals on each `start()`/`dialogue_ended` cycle. In Godot 4.6, reconnecting a signal that is already connected without first disconnecting it creates a duplicate connection — every subsequent emission fires the handler twice, causing double advances on `&"line"` nodes and erratic double-selection on `&"choice"` nodes.

**Speaker portrait and name plate:** The UI resolves `speaker: StringName` to a display name and portrait via a `CharacterRegistry` lookup (see Dependencies). An empty `speaker` renders no name plate — narration only. If `speaker` is non-empty but not found in the registry, see E.8.

**No dialogue history panel** in MVP. The player cannot scroll back through previous lines. This is a scope decision (Pillar 5: Scope Is Story). Risk: players who advance past a one-shot line cannot recover it. Mitigation: the player may hold `ui_accept` to re-read the current line (without advancing); this is distinct from tapping, which advances. This hold-to-re-read behaviour must be implemented in the UI layer as a minimum mitigation.

### C.6 One-Shot Lines

A one-shot line is a line that fires exactly once per playthrough — its circumstances are unrepeatable, and replaying it would dilute the emotional weight it earns.

**Implementation pattern:**

1. Author a `&"conditional"` node upstream that checks `StoryState.has_flag(&"[SEMANTIC_FLAG_NAME]_SEEN")`.
   - If false (flag not set): route (`next`) to the one-shot `&"line"` node.
   - If true (flag already set): route (`else_next`) to the fallback node.
2. The one-shot `&"line"` node carries a `DialogueFlagWrite` that sets `&"[SEMANTIC_FLAG_NAME]_SEEN"` to `true` before dispatch (per C.4 step 3).

**Naming convention for one-shot flags — semantic, not structural:** One-shot seen-flags must be named semantically, not by node ID. Use the pattern `DIALOGUE_[SCENE]_[BEAT]_SEEN`. Example: `&"DIALOGUE_KAKUS_SANCTUARY_GRIEVES_KIA_SEEN"`. Do NOT encode node IDs (e.g., `NODE_4`) into flag names — node IDs may be renumbered during graph revision, silently breaking the one-shot tracking and causing the line to fire every time instead of once. Semantic names are stable across graph edits and interpretable without opening the graph file. These flags must be declared as constants in the `FLAGS` inner class of `StoryState`.

**Fallback quality contract:** The fallback for a one-shot line is not optional boilerplate. It must contain at minimum one contextual reference to the specific circumstances that produced the one-shot moment. A fallback that could appear regardless of who killed Kia, who was present, or what the player chose fails this contract. Writers must author the fallback with the same care as the one-shot line. Accepted test: "Could this fallback appear in a playthrough where [triggering event] never happened?" If yes, it must be revised.

**Flag rename warning:** Once a one-shot seen-flag is in a shipped `.tres` file, its `StringName` value must never change — renaming the constant in `StoryState.FLAGS` without updating every referencing `.tres` silently breaks the one-shot check: the old flag name is never set; the renamed constant is never found; the line fires every time instead of once. The graph validator script (OQ-3) is the primary safeguard. Before renaming any `DIALOGUE_*_SEEN` constant, search all `.tres` files in `assets/data/dialogue/` for the old string value and update them atomically.

**No automatic one-shot detection:** `DialogueManager` does not automatically deduplicate lines. One-shot behaviour is always an explicit authoring choice using this pattern. This keeps the system stateless and predictable.

**Guest departure conversations** are the primary use case for one-shot lines. The final exchange before a guest departs is authored as a one-shot: it can never be replayed, and the fallback route leads to a generic continuation. This is the secondary beat of the Player Fantasy (Section B): *they will never say that again*.

## Formulas

### D.1 Condition Set Evaluation

For a node or choice with `n` conditions `C₁ … Cₙ` and `condition_mode`:

**AND mode** (`&"and"`, default):
```
active = C₁.passes AND C₂.passes AND … AND Cₙ.passes
```

**OR mode** (`&"or"`):
```
active = C₁.passes OR C₂.passes OR … OR Cₙ.passes
```

Where `Cᵢ.passes` is defined per operator (C.3 table). An empty conditions array (`n = 0`) always evaluates to `active = true` in both modes.

### D.2 Visible Choice Count

Let `K` = total choices on a `&"choice"` node, `H` = choices with `display == &"hidden"` whose conditions fail, `L` = choices with `display == &"locked"` whose conditions fail:

```
hidden_count   = H
locked_count   = L
selectable_count = K - H - L
```

Valid authoring target: `selectable_count ≥ 2`. Values outside this range are authoring errors:
- `K = 0` → authoring error; E.1 crash path (no `choices[0]` exists)
- `selectable_count < 2` → Edge Case E.1 (fallback + push_error)
- `K > 4` → caught at authoring time by the validator; never reaches runtime

Locked choices (`display == &"locked"` with failing conditions) are rendered visibly but are inert. They do not count toward `selectable_count`.

## Edge Cases

**E.1 — Choice node collapses to fewer than 2 selectable choices**
Cause: flag state at runtime eliminates more selectable choices than authored fallbacks cover, or `K = 0` (no choices authored at all).

Special case `K = 0`: the choices array is empty. Behaviour: `DialogueManager` emits `push_error("DialogueManager: choice node [id] has no authored choices — authoring error")` and emits `dialogue_ended` immediately, sets `_active = false`. The conversation ends. (No attempt is made to advance via the choice node's own `next` field — that field is not required on choice nodes, its Godot default of `0` would route back to the root node and cause an infinite loop.)

`selectable_count == 1` case (`K > 0`, exactly one choice passes filtering): `DialogueManager` emits `push_error("DialogueManager: choice node [id] collapsed to 1 selectable choice — auto-advancing")` and auto-advances to that one selectable choice's `next`. The conversation continues without displaying the choice panel; the player experiences an invisible forced branch. This is always an authoring error.

`selectable_count == 0` case (`K > 0`, no choices pass filtering): `DialogueManager` emits `push_error("DialogueManager: choice node [id] collapsed to 0 selectable choices — authoring error")` and advances to the `next` of the first `DialogueChoice` in the original array where `next != -1` (a "valid next"). If no `DialogueChoice` in the array has `next != -1`, `DialogueManager` emits `dialogue_ended` and sets `_active = false` — the conversation ends. When a valid fallback is found, the conversation continues without displaying the choice panel. This is always an authoring error — the error must appear in the Godot output log during testing.

**E.2 — Condition on a `&"line"` node fails**
Cause: author placed a `conditions` array on a line node instead of routing through a `&"conditional"` node.
Behaviour: `push_error("DialogueManager: line node [id] has conditions — use a conditional node for routing")`. The manager delivers the line unconditionally and advances to `next`. Use `assert()` in a graph validation pass at `start()` for this class of authoring error.

**E.3 — `DialogueManager.start()` called while a conversation is already active**
Cause: world trigger fires while player is already in dialogue.
Behaviour: `push_error` and reject the new graph — the in-progress conversation continues uninterrupted. The triggering system is responsible for checking `DialogueManager.is_active()` before calling `start()`.

**E.4 — `StoryState.check_flag()` returns a type not matching the operator**
Example: `&"gt"` applied to a `String` flag, or `&"has_key"` applied to a non-Dictionary value.
Behaviour: condition fails (returns false). `push_error("DialogueManager: type mismatch on flag [id] — operator [op] not valid for [type]")`. Never crashes. **Implementation note:** For `&"has_key"`, the `typeof` guard in C.3 intercepts the type check before `.get()` is called — this guard is what ensures non-Dictionary types produce a `push_error` rather than a runtime crash. The `push_error` for E.4 fires from inside that `typeof` guard block.

**E.5 — Graph contains no node with ID 0**
Cause: authoring error — root node was deleted or renumbered.
Behaviour: `push_error` and abort `start()`. No conversation begins. `dialogue_ended` IS emitted so downstream systems (Cutscene System, NPC System, Guest Character System) waiting on `dialogue_ended` are not left hanging indefinitely. `_active` remains false.

**E.6 — `advance()` called with an out-of-range or invalid `choice_index`**
Cause: UI bug passing an index that does not exist in the original choices array, or a negative index.
Behaviour: `push_error` and advance to the `next` of the first `DialogueChoice` in the original array that has a valid `next` reference (same "first available" fallback as E.1). Note: `advance()` must guard `choice_index >= 0` explicitly before any array access. GDScript's `choices[-1]` returns the last element without an index-out-of-bounds error — negative indices must be caught by the guard, not by the array access.

**E.7 — Narrative Event flag missing an expected field**
Example: `KIA_KILLED` exists but was set without the `agent` key.
Behaviour: `has_key` condition fails (returns false). The branch treating that field as present is skipped. Authors must ensure Narrative Event flags are set with all required fields declared in the FLAGS inner class comment (Story State GDD C.3).

**E.8 — Speaker StringName not found in CharacterRegistry**
Cause: authoring error — `speaker` StringName in a `.tres` file does not match any key in the CharacterRegistry (or MVP hardcoded Dictionary).
Behaviour: `push_error("DialogueManager: unknown speaker id '[id]' — add to CharacterRegistry")`. The UI renders the raw StringName as the name plate text (e.g., "kakus_sanctuary_alt") as a visually distinguishable fallback — not silent narration mode, which would hide the error during testing. Portrait is absent.

## Dependencies

| System | Relationship | Contract |
|--------|-------------|----------|
| **Story State & Flag System** (GDD #15) | Required upstream | `DialogueManager` reads flags via `StoryState.check_flag()` and `StoryState.has_flag()`. Writes flags via `StoryState.set_flag()`. Listens to `StoryState.flags_restored` to note that any locally cached flag reads are stale (no caching in MVP — system is stateless; listed for completeness). StoryState must be loaded before DialogueManager in Autoload order. |
| **Character Registry** (inferred — no GDD yet) | Required upstream | `DialogueManager` resolves `speaker: StringName` to display name and portrait path. In MVP, this is a lightweight external resource (`CharacterData.tres` per character) rather than a hardcoded Dictionary in DialogueManager.gd — a hardcoded Dictionary cannot carry the per-character accent color data required by the Visual Identity Anchor (game-concept.md). OQ-1 is resolved: lightweight CharacterData resources, not code constants. |
| **Cutscene System** (GDD #16 — not yet designed) | Downstream consumer | The Cutscene System will call `DialogueManager.start()` to drive in-cutscene dialogue. `DialogueManager` must emit `dialogue_ended` reliably — including on CONDITIONAL_STACK_DEPTH_LIMIT abort — so cutscenes can sequence their next beat. |
| **NPC System** (GDD #11 — not yet designed) | Downstream consumer | NPCs call `DialogueManager.start()` on player interaction. NPCs must check `DialogueManager.is_active()` before triggering. |
| **Guest Character System** (GDD #6 — not yet designed) | Downstream consumer | Guest departure conversations are one-shot graphs (C.6). The Guest Character System triggers the farewell graph and waits for `dialogue_ended` before executing the departure mechanic. |
| **Save System** (GDD #12 — not yet designed) | Indirect — via StoryState | One-shot seen-flags (C.6) are stored in StoryState and persisted by the Save System via `StoryState.serialize()`. `DialogueManager` itself holds no persistent state. Mid-dialogue saving is not supported in MVP — if the player saves during an active conversation, the conversation does not persist and will not resume on load. |
| **HUD System** (GDD #19) | Peer — UI layer separation | HUD must be hidden or suppressed during active dialogue. `DialogueManager` emits no HUD signals — the HUD listens to `dialogue_line_ready` and `dialogue_ended` to manage its own visibility. Note: the HUD GDD must be updated to list Dialogue System as a dependency (currently omitted from its dependency list). |

## Tuning Knobs

| Knob | Default | Safe Range | Affects |
|------|---------|------------|---------|
| `MAX_CHOICES_PER_NODE` | `4` | `2–6` | Maximum `DialogueChoice` entries allowed on a `&"choice"` node. Authoring validator enforces this at export time. Raising above 4 risks UI overflow on 320px-native viewport. |
| `TEXT_ADVANCE_INPUT_ACTION` | `"ui_accept"` | Any valid InputMap action | The input action the UI listens to for dismissing a line. Configurable so keybinding remapping doesn't require code changes. |
| `DIALOGUE_FONT_SIZE` | `12px` | `10–16px` | Base font size for dialogue text in the dialogue box. Affects readability on small displays. Must remain legible at 2× pixel scaling. The authoring validator enforces the 180-character hard limit on `text` fields based on this value. |
| `SPEAKER_NAME_DISPLAY` | `true` | `true / false` | Whether the speaker name plate is shown above dialogue text. Disabling produces a pure narration aesthetic for specific scenes. |
| `CONDITIONAL_STACK_DEPTH_LIMIT` | `32` | `8–64` | Maximum number of consecutive `&"conditional"` nodes the manager will evaluate before aborting. Checked at the top of the traversal loop (before evaluating the node). On abort: `push_error` is emitted, `dialogue_ended` is emitted (so downstream systems like the Cutscene System are not left waiting), `_active` is set to false, and `_current_node_id` is cleared to `-1`. The player sees the dialogue box close; no visible error is shown. |
| `CHOICE_INPUT_LOCK_MS` | `150` | `100–300` | Milliseconds the choice panel ignores confirm input after appearing. Prevents input echo from a line-advance press triggering an unintended choice selection. |
| `HOLD_TO_REREAD_MS` | `400` | `300–600` | Milliseconds the player must hold `ui_accept` on a fully-revealed **normal** (`importance: &"normal"`) node to activate re-read mode (suppresses advance). Below this threshold, a press-and-release is a tap (advance or skip to full text). Active only when text is fully revealed; ignored during text-reveal animation. Does not govern `&"critical"` node advance — that is `CRITICAL_ADVANCE_MS`. |
| `CRITICAL_ADVANCE_MS` | `600` | `400–800` | Milliseconds the player must hold `ui_accept` on an `importance: &"critical"` node to advance. On these nodes, a tap does not advance; hold-to-confirm friction is the advance mechanism. Hold-progress indicator fills during hold and resets on early release. When the accessibility "Disable hold mechanics" toggle is active, `CRITICAL_ADVANCE_MS` is bypassed and the critical node advances on tap. Tuned independently from `HOLD_TO_REREAD_MS` — these are two distinct gestures with different feel targets. |
| `IMPORTANCE_DEFAULT` | `&"normal"` | `&"normal"` / `&"critical"` | Default value for `DialogueNode.importance` when not set by the writer. `&"critical"` activates hold-to-confirm advance governed by `CRITICAL_ADVANCE_MS`; reserve for one-shot and guest departure exchanges only. Authoring overuse risks player fatigue with hold mechanics. |

## Visual/Audio Requirements

- **Dialogue box**: A panel anchored to the bottom of the screen, approximately 320×60px at native resolution. Displays speaker name plate (top-left) and dialogue text. Style defined in the Art Bible (pixel art, high contrast text on dark background). On text overflow (line exceeds box height), the box expands upward by one line increment, capped at 320×90px native. Text is never clipped.
- **Portrait**: Speaker portrait displayed left of the text area (or absent for narration). Portraits are static sprite frames, not animated. Resolution and pixel art spec deferred to Art Bible. During choice panel display, portrait is hidden to maximise choice button width.
- **Choice panel**: Expands upward from the dialogue box when a `&"choice"` node is active. Choice buttons are vertically stacked with clear selection highlight. Minimum button height: 20px native (40px at 2× scaling). Locked choices (`display == &"locked"` with failing conditions) are rendered in a visually distinct style (greyed text, no selection indicator).
- **Recognition indicator**: Lines authored with `is_recognition: true` (see C.1) are delivered with a subtle visual accent — a brief warm glow or ambient shift on the dialogue box, consistent with the speaker's established character color (per the Visual Identity Anchor in game-concept.md: "Guest characters are introduced with their own accent color that lingers subtly in the UI after they leave"). This signal communicates to the player that the line is context-sensitive without breaking the fourth wall. Exact visual treatment deferred to Art Bible for specification. The manager communicates recognition state to the UI via the `is_recognition: bool` parameter on `dialogue_line_ready` (C.4 step 4) — `true` when the dispatched node's authored `is_recognition` field is `true` (writer-set, not inferred from condition operators). The UI triggers the visual accent when `is_recognition == true`. Each dispatch reflects only the current node's `is_recognition` value; the accent appears and disappears per node, not per conversation. **Consecutive recognition nodes:** When `dialogue_line_ready` fires with `is_recognition: true` and the prior dispatch also had `is_recognition: true`, the UI must replay the recognition accent animation (exit then re-enter) to maintain per-node signal integrity. A continuous accent spanning two consecutive recognition nodes loses its punctuating value — the player perceives ambient glow rather than a discrete recognition event. **Compatibility renderer constraint:** Post-process glow via `WorldEnvironment` does not apply to `CanvasLayer` UI nodes in any renderer (Compatibility, Mobile, or Forward+). The recognition indicator must be implemented using Compatibility-compatible techniques: an additive-blend `Sprite2D` or `ColorRect` overlaid on the dialogue box animated via `Tween` on `modulate.a`, or a per-node GLSL ES 3.0 shader on the dialogue panel. The Art Bible must select from these approaches — `WorldEnvironment.glow` is not available for this UI element.
- **Text rendering**: Pixel-perfect font rendering required. No sub-pixel antialiasing. Font must be a bitmap/pixel font consistent with the Art Bible. BBCode markup is rendered via Godot `RichTextLabel`.
- **Audio**: No voice acting in MVP. Dialogue lines are text-only. A typewriter sound effect (single tick SFX per character or per word — to be decided in Audio System) plays during text reveal if text-reveal animation is implemented (see UI Requirements). `[pause=N]` tags suppress the tick SFX for the pause duration. **`[pause=N]` is a custom tag — it is not a native Godot `RichTextLabel` BBCode feature.** Implementing it requires a custom text-reveal controller pipeline: (1) strip all `[pause=N]` occurrences from the raw `text` string before assigning to `RichTextLabel.text`; (2) build an `Array` of `(character_position: int, duration_seconds: float)` pairs from the stripped tags; (3) drive the character reveal via a `Tween`-based animation that pauses at each specified character position for the given duration; (4) during each pause, suppress the typewriter tick SFX. The `RichTextLabel.visible_characters` property drives character reveal; standard `bbcode_text` auto-animation is not used. The text-reveal controller owns this pipeline; `DialogueManager` delivers raw `text` strings including `[pause=N]` tags and the controller pre-processes them before display.
- **Music**: Dialogue does not interrupt ambient/battle music. The Audio System manages music continuity independently.

## UI Requirements

- **Text reveal**: Optional character-by-character reveal animation. Player can tap `ui_accept` to skip to full text; tapping again advances to the next node. Player can hold `ui_accept` for at least `HOLD_TO_REREAD_MS` (default 400ms) to activate hold-to-re-read mode: the line remains visible and advance is suppressed. The advance prompt changes visual state (e.g., pulses or dims) to signal that hold mode is active; on release, the line remains and normal interaction resumes. Advance fires on `ui_accept` **release** (button-up); the hold timer starts on button-down. If the player releases before `HOLD_TO_REREAD_MS` elapses, the press-and-release is treated as a tap (advance or skip). **Skip-to-full-text fires on button-down (press event), not button-up.** This prevents a ghost re-read-mode entry: if the player holds `ui_accept` during a long reveal animation and the text completes mid-hold, the skip fired on press, and the hold timer **resets to zero at the moment the text transitions to fully-revealed**. The player is in a clean "text fully revealed" state; the hold timer measures only from the transition point, not from the original button-down before the skip. Hold-to-re-read is **only active when text is fully revealed** — during text-reveal animation, `ui_accept` only skips to full text. A blinking advance prompt (arrow or icon) appears only when text is fully revealed, distinguishing the "text revealing" state from the "text complete / ready to advance" state. This visual distinction prevents the two-press sequence from being invisible. If text reveal is disabled, text is considered fully revealed at display time and the advance prompt appears immediately.
- **Input methods**: Full keyboard, gamepad (d-pad + confirm), and mouse support required for all dialogue interactions (line advance, choice selection). No hover-only interactions.
- **Input lock**: A `CHOICE_INPUT_LOCK_MS` (default 150ms) lock prevents `ui_accept` from registering as a choice selection immediately after the choice panel appears. Applies to all input methods. See C.5 and Tuning Knobs.
- **Accessibility**: Dialogue body text must achieve a minimum contrast ratio of 4.5:1 (WCAG AA) against the dialogue box background. Speaker name plate text: minimum 4.5:1. Choice button text in normal state: minimum 4.5:1. Choice button text in focused/selected state: minimum 4.5:1 (both foreground and background must be evaluated after highlight color is applied). Locked choice text: minimum 3:1 (lower floor acceptable as locked choices are intentionally de-emphasised). Font size tunable via `DIALOGUE_FONT_SIZE`. No timed prompts — the player advances at their own pace.
- **Hold-to-confirm on `&"critical"` nodes**: When `importance: &"critical"` is present on a `&"line"` node, the advance prompt shows a hold-progress indicator while `ui_accept` is held — a fill animation or expanding arc on the advance prompt icon that completes at `CRITICAL_ADVANCE_MS` (default 600ms). This gives the player clear visual feedback that a hold (not a tap) is required. **The critical-node advance prompt must communicate the required hold gesture in its idle (pre-interaction) state — before any player input occurs.** The idle prompt must be visually distinct from the normal advance prompt in its static state: a partially-filled hold-arc, a hold-label, or a pulsing idle animation that invites completion. Players must be able to understand that a hold is required without a failed-tap discovery experience. Exact visual treatment is Art Bible scope; this UX requirement is that the gesture must be legible before interaction. On release before `CRITICAL_ADVANCE_MS` elapses, the progress indicator resets.
- **Hold mechanics accessibility toggle**: An option in accessibility settings labeled "Disable hold mechanics" (Menu & Settings System scope). When disabled, this toggle suppresses **both** hold-to-re-read on normal nodes AND hold-to-confirm on `&"critical"` nodes — `ui_accept` always advances via tap, everywhere, with no hold required. Players who need this option must not be required to encounter hold mechanics at any point, including the game's most emotionally significant moments. The toggle is labeled "Disable hold mechanics" to communicate its full scope.
- **Keyboard focus indicator**: The currently focused choice must always have a clearly visible focus ring or highlight that is visible to keyboard/gamepad users with no mouse movement required to reveal it. The focus indicator must be a distinct visual treatment from the normal (unfocused) choice state. This is not optional — keyboard-only players with no visual focus state cannot use the choice system.
- **Assistive technology / screen reader scope**: MVP dialogue UI is not required to expose content to OS-level screen readers (AT). Godot 4.6 AccessKit integration is out of scope for MVP. This is a deferred accessibility decision — reassess for Episode 1 before public release.
- **HUD suppression**: The HUD layer must hide (or reduce to minimal state) while `DialogueManager.is_active()` is true. HUD listens to `dialogue_line_ready` (hide) and `dialogue_ended` (restore). See OQ-4.
- **No scroll/history**: No dialogue log or replay in MVP (C.5). Mitigated by hold-to-re-read.

## Acceptance Criteria

| AC | Description | Test Type |
|----|-------------|-----------|
| AC-1 | `DialogueManager.start(graph)` loads the graph and advances to node ID 0 | Unit |
| AC-2 | A `&"line"` node emits `dialogue_line_ready` with correct `speaker`, `text`, empty typed `choices` array (`Array[DialogueChoice]()`), and `is_recognition = false` (the default) | Unit |
| AC-3 | A `&"choice"` node emits `dialogue_line_ready` with the full **unfiltered** `choices` array (all authored entries regardless of conditions) and the correct `is_recognition` value read from the node's authored field | Unit |
| AC-4 | `advance(-1)` on a `&"line"` node advances to `next` | Unit |
| AC-5 | `advance(choice_index)` on a `&"choice"` node advances to that choice's `next` | Unit |
| AC-6 | A `&"conditional"` node with passing conditions advances to `next` without emitting `dialogue_line_ready` | Unit |
| AC-7 | A `&"conditional"` node whose conditions fail (evaluated per `condition_mode`) advances to `else_next` without emitting `dialogue_line_ready` | Unit |
| AC-8 | An `&"end"` node emits `dialogue_ended` and clears active state | Unit |
| AC-9 | `DialogueManager.is_active()` returns `true` between `start()` and `dialogue_ended`, `false` otherwise | Unit |
| AC-10 | `DialogueCondition` with `operator: &"eq"` passes when `check_flag` result equals `operand`, fails otherwise | Unit |
| AC-11 | `DialogueCondition` with `operator: &"has_key"` passes when Narrative Event flag Dictionary contains the expected `field`/`operand` pair | Unit |
| AC-12 | `DialogueCondition` on an unset flag (null return) fails silently — no crash, node treated as inactive | Unit |
| AC-13 | `DialogueFlagWrite` entries on a node cause `StoryState.set_flag()` to be called before `dialogue_line_ready` is emitted | Unit |
| AC-14 | A one-shot line (C.6 pattern) fires on first playthrough, routes to fallback on second playthrough when seen-flag is set | Integration |
| AC-15 | `start()` called while already active: rejects new graph, emits `push_error`, in-progress conversation continues | Unit |
| AC-16a | Choice node where exactly one choice passes filtering (`selectable_count == 1`): `DialogueManager` emits `push_error`, auto-advances to that one selectable choice's `next` (not `choices[0].next` — the selectable choice may not be `choices[0]`), does not display the choice panel, `is_active()` remains true | Unit |
| AC-16b | Choice node where no choices pass filtering (`selectable_count == 0`, `K > 0`): `DialogueManager` emits `push_error`, advances to the `next` of the first `DialogueChoice` in the original array where `next != -1`. If no such choice exists, emits `dialogue_ended` and `is_active()` returns false. | Unit |
| AC-17 | `advance(choice_index)` with index `< -1` (e.g. -2, -100) or index `>= choices.size()`: emits `push_error`, auto-advances to the `next` of the first `DialogueChoice` where `next != -1`. If no such choice exists, emits `dialogue_ended` and `is_active()` returns false. (Note: `advance(-1)` on a choice node is a distinct case covered by AC-46.) | Unit |
| AC-18 | Graph with no node ID 0: `start()` aborts, `push_error` emitted, `dialogue_ended` IS emitted (so downstream callers are not left waiting), `is_active()` returns false | Unit |
| AC-19a | Exactly `CONDITIONAL_STACK_DEPTH_LIMIT` consecutive `&"conditional"` nodes: depth counter reaches the limit but does not exceed it — no abort, conversation continues normally, `dialogue_ended` is NOT emitted prematurely | Unit |
| AC-19b | `CONDITIONAL_STACK_DEPTH_LIMIT + 1` consecutive `&"conditional"` nodes: the depth counter exceeds `CONDITIONAL_STACK_DEPTH_LIMIT` on the final node, triggering abort — emits `push_error`, emits `dialogue_ended`, `is_active()` returns false, `_current_node_id` is reset to `-1` | Unit |
| AC-20 | Full conversation played end-to-end using `tests/fixtures/dialogue/test_branch_fixture.tres` (a reference graph with a conditional routing to node ID 2 on pass and node ID 3 on fail; nodes 2 and 3 are `&"line"` nodes with distinct known text values; both lead to an `&"end"` node): correct branch node's `text` is emitted by `dialogue_line_ready`, `dialogue_ended` emitted on completion, `is_active()` returns false. **Prerequisite: the fixture file must be created at `tests/fixtures/dialogue/test_branch_fixture.tres` before this AC can be executed — assign fixture authoring as a story card prerequisite.** | Integration |
| AC-21 | Keyboard, gamepad (d-pad + confirm), and mouse can each advance a line, select a choice, and trigger hold-to-re-read on a fully-revealed line | Manual |
| AC-22 | HUD hides on `dialogue_line_ready` and restores on `dialogue_ended` (requires HUD System integration) — **BLOCKED: depends on HUD System re-review resolving OQ-4** | Integration |
| AC-23 | `DIALOGUE_FONT_SIZE` tuning knob changes rendered font size without code changes | Manual |
| AC-24 | `DialogueCondition` with `operator: &"neq"` passes when `check_flag` result does NOT equal `operand`; fails when it equals `operand` | Unit |
| AC-25 | `DialogueCondition` with `operator: &"gt"` passes when `check_flag` result (int) is strictly greater than `operand`; fails when equal or less | Unit |
| AC-26 | `DialogueCondition` with `operator: &"lt"` passes when `check_flag` result (int) is strictly less than `operand`; fails when equal or greater | Unit |
| AC-27 | A node with `condition_mode: &"and"` and two conditions where one passes and one fails is treated as inactive | Unit |
| AC-28 | A node with `condition_mode: &"or"` and two conditions where one passes and one fails is treated as active | Unit |
| AC-29 | Given a `&"choice"` node with 3 choices where `choices[0]` conditions fail and `choices[1]`/`choices[2]` pass: UI receives filtered indices [1, 2]; player selects the first visible entry; UI calls `advance(1)` (original index); manager advances to `choices[1].next` | Integration |
| AC-30 | A node with an empty `conditions` array (n = 0) is always treated as active in both `&"and"` and `&"or"` modes | Unit |
| AC-31 | A `&"line"` node with failing conditions: emits `push_error` **before** `dialogue_line_ready` is emitted, delivers the line unconditionally, advances to `next` normally | Unit |
| AC-32 | `DialogueCondition` with `operator: &"has_key"` where `check_flag()` returns a Dictionary that does NOT contain `field`: condition fails silently, no crash (distinct from AC-12 null case) | Unit |
| AC-33 | During text-reveal animation: first `ui_accept` tap skips to full line (animation stops, full text visible); second tap advances to next node; neither tap fires the hold-to-re-read behaviour | Manual |
| AC-34 | A `DialogueChoice` with `display: &"locked"` and failing conditions is rendered visibly in the choice panel but cannot be selected via any input method | Manual |
| AC-35 | `dialogue_line_ready` emits `is_recognition = true` for nodes where the authored `is_recognition` field is `true`; emits `is_recognition = false` for nodes where the field is `false` (the default). The value is read directly from `DialogueNode.is_recognition` — not inferred from condition operators or routing history. | Integration |
| AC-36 | A `&"conditional"` node with `condition_mode: &"or"` and two conditions where **both** fail is treated as inactive (routes to `else_next`) | Unit |
| AC-37a | `filter_choices()` includes a `DialogueChoice` with `display: &"locked"` in its result array when that choice's conditions pass | Unit |
| AC-37b | In-game, a `display: &"locked"` choice whose conditions pass renders with no greying and no lock indicator, and accepts selection identically to a normal selectable choice | Manual |
| AC-38 | For each `is_recognition: true` node in a dialogue graph, the companion notes file at `assets/data/dialogue/[graph-name]-notes.md` contains a row identifying: node ID, the specific triggering circumstances, and confirmation that the legibility test from Section B passes (line text would not appear in a playthrough where those circumstances never occurred). **Evidence artifact:** the notes file exists and is complete before the graph is marked integration-ready. A QA tester verifies by cross-referencing node IDs in the `.tres` against rows in the notes file. | Manual |
| AC-39 | Graph with two nodes sharing the same ID: `start()` emits `push_error`, aborts, `dialogue_ended` IS emitted, `is_active()` returns false | Unit |
| AC-40 | Graph with a `next`, `else_next`, or `DialogueChoice.next` pointing to a non-existent node ID: `start()` emits `push_error`, aborts, `dialogue_ended` IS emitted, `is_active()` returns false | Unit |
| AC-41 | `&"conditional"` node with `else_next == -1` or referencing a missing node ID: assertion fires in debug builds; `push_error` emitted in release builds. **Note: this AC requires two separate test runs — one under a debug build and one under a release build configuration.** | Unit |
| AC-42 | Node with `condition_mode` set to an unrecognized value (not `&"and"` or `&"or"`): `push_error` emitted, value corrected to `&"and"`, conversation continues | Unit |
| AC-43 | Graph with a non-conditional cycle (e.g., `&"line"` node A → `next` → `&"line"` node B → `next` → A): `assert()` fires in debug builds during graph validation | Unit (debug) |
| AC-44 | Graph with a valid diamond structure (two branches both routing to a shared downstream node) passes graph validation without triggering a false-positive cycle-detection assertion | Unit |
| AC-45 | Choice node with `K = 0` (no authored choices): `DialogueManager` emits `push_error`, emits `dialogue_ended`, `is_active()` returns false. Manager does NOT attempt to advance via the choice node's `next` field. | Unit |
| AC-46 | `advance(-1)` called on a `&"choice"` node: `push_error` emitted, manager routes to `choices[0].next` (treated as `advance(0)`) | Unit |
| AC-47 | D-pad navigation in a choice panel where locked-failing choices are interspersed between selectable choices: focus moves only between selectable choices; pressing d-pad past the last selectable choice in a direction does not wrap focus to the opposite end | Manual |
| AC-48 | When a choice panel first appears, the first entry in `_visible_to_original` is automatically highlighted/keyboard-focused with no player input required | Manual |
| AC-49 | During the `CHOICE_INPUT_LOCK_MS` window after a choice panel appears: `ui_accept` keypresses and mouse clicks on choice buttons are swallowed and do not register a selection; after the window expires, choice input is accepted normally | Manual |
| AC-50 | A `&"line"` node with `is_recognition: false` immediately following a `&"line"` node with `is_recognition: true` emits `is_recognition = false` on `dialogue_line_ready` — the value reflects only the current node's authored field, not the prior node's | Unit |
| AC-51 | After a conversation ends via `dialogue_ended`, a subsequent `start()` on a depth-limit-triggering graph correctly aborts again (depth counter was fully reset). **Must be verified after each of the three end paths independently:** (a) natural `&"end"` node, (b) `CONDITIONAL_STACK_DEPTH_LIMIT` abort, (c) E.1 `dialogue_ended` fallback (selectable_count == 0, no valid-next). All three paths must independently confirm the depth counter reset. | Unit |
| AC-52 | `&"line"` node with `importance: &"critical"`: a tap of `ui_accept` (press-and-release below `CRITICAL_ADVANCE_MS`) does not advance; player must hold for `CRITICAL_ADVANCE_MS` to advance. Hold-progress indicator is visually distinct from the normal advance prompt and resets on early release. | Manual |
| AC-53 | `DialogueCondition` with `operator: &"has_key"` where `check_flag()` returns a non-null, non-Dictionary value (e.g., `bool true`): condition fails, `push_error` is emitted (E.4 type mismatch), no crash — the `typeof` guard in C.3 fires before `.get()` is called | Unit |
| AC-54 | `advance(-1)` called after `dialogue_ended` (when `_active == false`): `push_error` is emitted, method returns immediately, no crash, `is_active()` remains false | Unit |
| AC-55 | `DialogueFlagWrite` with `value` of an unsupported type (e.g., `float`): `push_error` is emitted with contextual message identifying the node ID, the flag write is skipped, the conversation continues normally | Unit |
| AC-56 | A `&"line"` node with `speaker` set to empty `StringName`: `dialogue_line_ready` emits `speaker = &""`, and the UI renders no name plate (narration mode) | Unit (signal) / Manual (rendering) |
| AC-57 | Two consecutive `&"line"` nodes both with `is_recognition: true`: the recognition visual accent resets (exits and re-enters) between the two dispatches — the player perceives two distinct accent events, not one continuous accent | Manual |
| AC-58 | After `get_tree().change_scene_to_file()` to a new scene, `DialogueManager.start(graph)` successfully triggers visible dialogue UI display and `advance()` works correctly — the dialogue UI survived the scene transition because it is parented to the `DialogueManager` Autoload | Integration |
| AC-59 | When `ui_accept` is held at the moment a choice panel appears (carried over from a preceding `&"critical"` node advance), no choice selection registers until both `ui_accept` has been released AND the `CHOICE_INPUT_LOCK_MS` window has expired | Manual |
| AC-60 | `&"conditional"` node with an empty `conditions` array (`n = 0`): `push_error` warning is emitted (non-halting); the conversation continues; the node evaluates its empty conditions as active per D.1 and routes to `next` | Unit |
| AC-61 | A `DialogueChoice` with an unrecognized `display` value (not `&"hidden"` or `&"locked"`): `push_error` is emitted, the choice is treated as `&"hidden"` for render and filtering purposes, the conversation continues | Unit |
| AC-62 | With the accessibility "Disable hold mechanics" toggle active: a `&"critical"` node advances on a single tap of `ui_accept` (no hold required), and hold-to-re-read on normal nodes is also disabled | Manual |

## Open Questions

**OQ-1 — Character Registry scope — RESOLVED**
Resolved: speaker display name and portrait path are stored in per-character `CharacterData.tres` resource files (one per entity in the registry), not in a hardcoded Dictionary in `DialogueManager.gd`. This supports the per-character accent color required by the Visual Identity Anchor and keeps speaker metadata data-driven per project standards. A full CharacterRegistry system GDD is deferred to Episode 1 scope.

**OQ-2 — Text reveal animation**
UI Requirements lists text-reveal as optional. Should it be on by default, off by default, or player-toggled via accessibility settings? Impacts the typewriter SFX contract with the Audio System. Deferred to UX design session.

**OQ-3 — Dialogue graph authoring tooling — ELEVATED TO ACTIVE FOR VERTICAL SLICE**
Flag IDs in `.tres` files are raw `StringName` literals, not constants from `StoryState.FLAGS`. A writer typing `&"KIA_Killed"` (wrong case) produces a condition that silently always-fails. Before Vertical Slice authoring begins, a GDScript `@tool` editor script must be delivered that: loads every `.tres` in `assets/data/dialogue/`, checks every `DialogueCondition.flag_id` and `DialogueFlagWrite.flag_id` against declared constants in `StoryState.FLAGS`, and reports any string that does not match a known constant. This is not a full visual node editor — it is a flag validation script, estimable at one afternoon of implementation. A full visual authoring tool (node editor plugin or external tool) is deferred to post-Vertical Slice review.

**OQ-4 — HUD suppression mechanism**
The HUD System GDD does not yet define a suppression API. This AC-22 dependency requires coordination: the HUD listens to `dialogue_line_ready` (hide) and `dialogue_ended` (restore). Resolution deferred to HUD System re-review (pending). Dialogue System notes: if dialogue never occurs during active combat (only in overworld/exploration), HUD suppression may be a non-issue in MVP since the HUD is already absent outside combat. This must be confirmed during HUD re-review.

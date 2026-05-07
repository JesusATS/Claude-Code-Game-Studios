## StatScreen — full-screen party stat and inheritance display.
## UI Story 005: Stat Screen — Inheritance Display.
##
## Entry: caller invokes open(context). Exit: Esc/B triggers close(), which emits closed(context).
## Read-only: never writes to CharacterData or any game state.
##
## Layout: MarginContainer > VBoxContainer > [header, HBoxContainer(columns), nav hint].
## Columns are rebuilt on every open() call — not cached between opens.
##
## All child nodes: MOUSE_FILTER_IGNORE. Input handled via _unhandled_input (ui_cancel action).
## Root Control is also MOUSE_FILTER_IGNORE — _unhandled_input does not depend on mouse_filter.
##
## HP note: apply_inheritance() pre-bakes HP magnitude into base_hp, so base_hp IS the
## effective HP max. _compute_effective() must never be called for the &"hp" stat key.
## "(base N)" secondary text is therefore never shown for HP.
class_name StatScreen extends Control

## Emitted when the exit animation completes.
## context mirrors the value passed to open().
signal closed(context: String)

## Relay signal for CombatEventBus listeners — carries the same payload as closed().
signal ui_stat_screen_closed(context: String)

## Emitted once per character after their first-visit inheritance glow completes.
## Listener (StoryState) is responsible for writing the flag — this screen only emits.
signal ui_first_inheritance_viewed(character_id: StringName)

## Ordered stat keys matching CharacterData field names.
## HP must remain first so HP display logic can identify it by index 0.
const _STAT_KEYS: Array[StringName] = [&"hp", &"atk", &"def", &"spd", &"flux"]

## Display labels shown in the stat rows. Parallel array to _STAT_KEYS.
const _STAT_LABELS: Array[String] = ["HP", "ATK", "DEF", "SPD", "FLUX"]

## Injected by the composition root via initialize(). Never resolved via get_node.
var _pcm: PartyCompositionManager

## Typed as Node — StoryState extends Node (Autoload, TR-SSF-001) but its class_name
## may not be registered yet. Duck-type check_flag() at call site.
var _story_state: Node

## Retained across open/close to emit with the correct context in close signals.
var _context: String = ""

## Reference held so open() can clear and rebuild columns each call.
var _column_container: HBoxContainer

## Tracks the currently running open/close scale animation.
## Killed before starting a new animation to prevent concurrent tweens.
var _active_tween: Tween

## True while open() is animating. Cleared by close() to abort the post-await path.
var _is_opening: bool = false

## True while close() is animating. Guards against double-close.
var _is_closing: bool = false


## Injects runtime dependencies. Must be called once by the composition root before
## open() is called for the first time.
## pcm: authoritative party composition manager.
## story_state: flag store used to check first-visit inheritance state per character.
##
## Example:
##   stat_screen.initialize(party_composition_manager, story_state_node)
func initialize(pcm: PartyCompositionManager, story_state: Node) -> void:
	_pcm = pcm
	_story_state = story_state


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# PRESET_FULL_RECT stretches this Control to fill the viewport.
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	var header := Label.new()
	header.text = "PARTY RECORD"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(header)

	_column_container = HBoxContainer.new()
	_column_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_column_container)

	var nav_hint := Label.new()
	nav_hint.text = "Back  [Esc] / [B]"
	nav_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	nav_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(nav_hint)


## Opens the stat screen from the given context and animates it into view.
## Rebuilds all four columns fresh on every call.
## context: "exploration" — HP shown as HP_max only.
##          "combat_pause" — HP shown as hp_current / HP_max.
## Emits no signal on open; emits closed(context) on subsequent close().
##
## Example:
##   stat_screen.open("exploration")
func open(context: String) -> void:
	_is_opening = true
	_is_closing = false
	_context = context

	# Rebuild columns — discard any children from a previous open().
	for child: Node in _column_container.get_children():
		child.queue_free()

	for i: int in range(PartyCompositionManager.MAX_PARTY_SIZE):
		var slot: CharacterData = _pcm.get_slot(i + 1)
		var col: VBoxContainer = _build_column(slot, context)
		_column_container.add_child(col)

	visible = true

	# Wait one frame for the layout pass to resolve so size is non-zero
	# before computing pivot_offset. Without this, size may be Vector2.ZERO.
	# NOTE: this function suspends here. close() may be called during this gap.
	# Check _is_opening after resuming — if cleared by close(), abort silently.
	await get_tree().process_frame

	if not is_instance_valid(self) or not _is_opening:
		return

	pivot_offset = size / 2.0
	scale = Vector2(0.05, 0.05)

	if _active_tween:
		_active_tween.kill()
	_active_tween = create_tween()
	_active_tween.set_ease(Tween.EASE_OUT)
	_active_tween.set_trans(Tween.TRANS_CUBIC)
	_active_tween.tween_property(self, "scale", Vector2.ONE, 0.25)
	_active_tween.finished.connect(_on_open_animation_finished, CONNECT_ONE_SHOT)


## Closes the stat screen with an exit animation.
## On animation complete: emits closed(context) and ui_stat_screen_closed(context),
## then sets visible = false.
## Triggered by _unhandled_input on ui_cancel, or callable directly by the caller.
##
## Example:
##   stat_screen.close()
func close() -> void:
	if _is_closing:
		return
	_is_closing = true
	_is_opening = false  # abort any in-progress open() coroutine after its await

	if _active_tween:
		_active_tween.kill()
	_active_tween = create_tween()
	_active_tween.set_ease(Tween.EASE_IN)
	_active_tween.set_trans(Tween.TRANS_CUBIC)
	_active_tween.tween_property(self, "scale", Vector2(0.05, 0.05), 0.2)
	_active_tween.finished.connect(_on_close_animation_finished, CONNECT_ONE_SHOT)


## Handles ui_cancel action (Esc keyboard / B gamepad) to close the screen.
## Marks the input as handled to prevent propagation to the caller's input handler.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## Builds one column VBoxContainer for the given party slot.
## slot: CharacterData for this column. null produces an empty-slot placeholder.
## context: HP display mode — "exploration" or "combat_pause".
## Returns a fully constructed VBoxContainer ready to be parented.
func _build_column(slot: CharacterData, context: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if slot == null:
		# Empty guest slot: dashed placeholder header, no stats, no inheritance section.
		var empty_label := Label.new()
		empty_label.text = "---"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		empty_label.modulate = Color(0.4, 0.4, 0.4, 1.0)
		col.add_child(empty_label)
		return col

	# -- Column header: character name --
	var name_label := Label.new()
	name_label.text = slot.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_label)

	# -- Stats block: one row per stat --
	for idx: int in range(_STAT_KEYS.size()):
		var stat_key: StringName = _STAT_KEYS[idx]

		var base_value: int = _get_base_stat(slot, stat_key)

		# HP: base_hp already includes any HP inheritance (pre-baked by apply_inheritance).
		# All other stats: compute effective by summing matching inheritance magnitudes.
		var effective: int = base_value
		if stat_key != &"hp":
			effective = _compute_effective(base_value, stat_key, slot.inheritances)

		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var stat_name_lbl := Label.new()
		stat_name_lbl.text = _STAT_LABELS[idx]
		stat_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(stat_name_lbl)

		var stat_val_col := VBoxContainer.new()
		stat_val_col.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# HP display mode is context-driven; all other stats show the effective total.
		var effective_text: String
		if stat_key == &"hp":
			if context == "combat_pause":
				effective_text = "%d / %d" % [slot.hp_current, slot.base_hp]
			else:
				effective_text = str(slot.base_hp)
		else:
			effective_text = str(effective)

		var effective_lbl := Label.new()
		effective_lbl.text = effective_text
		effective_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stat_val_col.add_child(effective_lbl)

		# "(base N)" secondary text: shown only when an inheritance modifies this stat.
		# Never shown for HP — HP inheritances are pre-baked and have no separate base.
		if stat_key != &"hp" and effective != base_value:
			var base_lbl := Label.new()
			base_lbl.text = "(base %d)" % base_value
			base_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			base_lbl.modulate = Color(0.7, 0.7, 0.7, 1.0)
			stat_val_col.add_child(base_lbl)

		row.add_child(stat_val_col)
		col.add_child(row)

	# -- Inheritance section --
	if slot.inheritances.is_empty():
		var no_traces := Label.new()
		no_traces.text = "No traces yet carried"
		no_traces.mouse_filter = Control.MOUSE_FILTER_IGNORE
		no_traces.modulate = Color(0.5, 0.5, 0.5, 1.0)
		col.add_child(no_traces)
	else:
		var divider := HSeparator.new()
		divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(divider)

		for nio: NamedInheritanceObject in slot.inheritances:
			var entry_lbl := Label.new()
			entry_lbl.text = "%s's Gift: +%d %s" % [
				nio.name,
				nio.magnitude,
				String(nio.stat).to_upper()
			]
			entry_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			# Render in the departed guest's accent color at 60% opacity.
			var entry_color: Color = slot.accent_color
			entry_color.a = 0.6
			entry_lbl.modulate = entry_color
			# Meta flag used by _check_first_visit_flags() to locate inheritance Labels.
			entry_lbl.set_meta("inheritance_label", true)
			col.add_child(entry_lbl)

	return col


## Computes the effective stat value for a non-HP stat.
## Sums magnitude from all NamedInheritanceObjects whose stat matches stat_key.
## IMPORTANT: must NOT be called for &"hp" — HP inheritances are pre-baked into base_hp.
##
## base: the character's raw base stat value from CharacterData.
## stat_key: StringName identifying the stat (e.g. &"flux", &"atk", &"def", &"spd").
## inheritances: the character's full inheritance array from CharacterData.inheritances.
## Returns: base + sum of all matching inheritance magnitudes.
##
## Example:
##   _compute_effective(8, &"flux", inheritances)  # returns 11 if one NIO has stat=&"flux", magnitude=3
func _compute_effective(base: int, stat_key: StringName, inheritances: Array[NamedInheritanceObject]) -> int:
	var total: int = base
	for nio: NamedInheritanceObject in inheritances:
		if nio.stat == stat_key:
			total += nio.magnitude
	return total


## Returns the base stat value from CharacterData for the given stat_key.
## Pushes a warning and returns 0 for unknown keys (defensive guard, should never fire).
func _get_base_stat(slot: CharacterData, stat_key: StringName) -> int:
	match stat_key:
		&"hp":
			return slot.base_hp
		&"atk":
			return slot.base_atk
		&"def":
			return slot.base_def
		&"spd":
			return slot.base_spd
		&"flux":
			return slot.base_flux
	push_warning("StatScreen._get_base_stat: unknown stat_key '%s'" % stat_key)
	return 0


func _on_open_animation_finished() -> void:
	_check_first_visit_flags()


func _on_close_animation_finished() -> void:
	_is_closing = false
	visible = false
	closed.emit(_context)
	ui_stat_screen_closed.emit(_context)


## After the entry animation settles, checks each occupied column for a first-visit flag.
## For any column with inheritances whose flag has not been set: schedules the glow pulse.
## Does nothing if _story_state is null (e.g. in isolated test contexts).
func _check_first_visit_flags() -> void:
	if _story_state == null:
		return

	for i: int in range(PartyCompositionManager.MAX_PARTY_SIZE):
		var slot: CharacterData = _pcm.get_slot(i + 1)
		if slot == null or slot.inheritances.is_empty():
			continue

		var flag_key: String = "stat_screen_first_view_" + String(slot.id)
		# check_flag() returns true if the flag has already been set (viewed before).
		# Skip if already viewed — glow only fires once per character, ever.
		if _story_state.check_flag(flag_key):
			continue

		# Collect inheritance Labels from this column using the meta flag set in _build_column.
		var col: VBoxContainer = _column_container.get_child(i) as VBoxContainer
		if col == null:
			continue

		var inheritance_labels: Array[Label] = []
		for child: Node in col.get_children():
			if child is Label and child.has_meta("inheritance_label"):
				inheritance_labels.append(child as Label)

		if inheritance_labels.is_empty():
			continue

		# Capture loop variables for the closure — GDScript closures capture by reference.
		var captured_labels: Array[Label] = inheritance_labels
		var captured_id: StringName = slot.id

		# 0.5s settling pause after animation, then begin glow pulse (AC-6).
		var timer := get_tree().create_timer(0.5)
		timer.timeout.connect(
			func() -> void: _run_glow_pulse(captured_labels, captured_id),
			CONNECT_ONE_SHOT
		)


## Runs the first-visit inheritance glow pulse on all labels in a column simultaneously.
## Each label gets its own Tween so all entries pulse in parallel (not sequentially).
## Pulse: modulate.a 0.6 -> 1.0 -> 0.6, ~1.5s per cycle, 3 repetitions total.
## On completion, emits ui_first_inheritance_viewed(slot_id).
## The listener (StoryState) is responsible for writing the "viewed" flag.
##
## labels: the inheritance Label nodes to animate, all from the same column.
## slot_id: the CharacterData.id for the character whose inheritance is being highlighted.
func _run_glow_pulse(labels: Array[Label], slot_id: StringName) -> void:
	if labels.is_empty():
		return

	# All labels in the column pulse in parallel — one Tween per label.
	# A separate signal_tween on the same label would fight for modulate:a ownership,
	# so the signal is scheduled via a SceneTreeTimer keyed to the known total duration.
	# Total duration: 3 loops * (0.75s up + 0.75s down) = 4.5s.
	const CYCLE_DURATION: float = 1.5
	const LOOP_COUNT: int = 3

	for lbl: Label in labels:
		var tween := create_tween()
		tween.set_loops(LOOP_COUNT)
		tween.tween_property(lbl, "modulate:a", 1.0, CYCLE_DURATION * 0.5)
		tween.tween_property(lbl, "modulate:a", 0.6, CYCLE_DURATION * 0.5)

	# Emit the completion signal after the full pulse sequence has elapsed.
	# SceneTreeTimer avoids any conflict with the per-label Tweens above.
	var total_duration: float = CYCLE_DURATION * LOOP_COUNT
	var completion_timer := get_tree().create_timer(total_duration)
	completion_timer.timeout.connect(
		func() -> void: ui_first_inheritance_viewed.emit(slot_id),
		CONNECT_ONE_SHOT
	)

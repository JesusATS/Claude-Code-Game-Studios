# PROTOTYPE - NOT FOR PRODUCTION
# Question: Is the timing combat mechanic intrinsically satisfying?
#           Does it feel "musical" and rewarding when a human player
#           must press a button at the right moment during a moving window?
# Date: 2026-05-06
# Standalone — no imports from src/

extends Node2D

# ---------------------------------------------------------------------------
# CONFIG — tweak these during testing to explore feel
# ---------------------------------------------------------------------------
const CHARGE_DURATION    := 2.0   # seconds enemy charges before window opens
const WINDOW_FRAMES      := 30    # frames the timing window is open (0.5s @ 60fps)
const PERFECT_THRESHOLD  := 0.35  # cursor at 0.0–0.35 = PERFECT
const HIT_THRESHOLD      := 0.75  # cursor at 0.35–0.75 = HIT; > 0.75 = MISS
const TOTAL_ROUNDS       := 8
const FEEDBACK_DURATION  := 0.9   # seconds to show grade before next round
const BAR_X              := 100.0
const BAR_Y              := 300.0
const BAR_W              := 600.0
const BAR_H              := 50.0

# ---------------------------------------------------------------------------
# STATE
# ---------------------------------------------------------------------------
enum State { CHARGING, WINDOW_OPEN, SHOWING_FEEDBACK, SUMMARY }
var state: State = State.CHARGING

var current_round    : int     = 0
var frame_counter    : int     = 0
var charge_timer     : float   = 0.0
var feedback_timer   : float   = 0.0
var last_grade       : String  = ""
var results          : Array   = []   # Array[String]

# ---------------------------------------------------------------------------
# UI NODE REFERENCES
# ---------------------------------------------------------------------------
var round_label      : Label
var instruction_label: Label
var charge_fill      : ColorRect
var charge_bg        : ColorRect
var perfect_zone     : ColorRect
var hit_zone         : ColorRect
var miss_zone        : ColorRect
var window_bg        : ColorRect
var cursor           : ColorRect
var grade_label      : Label
var summary_label    : Label

# ---------------------------------------------------------------------------
# SETUP
# ---------------------------------------------------------------------------
func _ready() -> void:
	_build_ui()
	_start_round()


func _build_ui() -> void:
	# ---- Background ----
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.10)
	bg.size = Vector2(800, 600)
	add_child(bg)

	# ---- Round label ----
	round_label = Label.new()
	round_label.position = Vector2(20, 20)
	round_label.add_theme_font_size_override("font_size", 22)
	round_label.modulate = Color(0.85, 0.85, 0.85)
	add_child(round_label)

	# ---- Instruction label ----
	instruction_label = Label.new()
	instruction_label.position = Vector2(20, 56)
	instruction_label.add_theme_font_size_override("font_size", 18)
	instruction_label.modulate = Color(0.65, 0.65, 0.65)
	add_child(instruction_label)

	# ---- Enemy charge bar ----
	var charge_title := Label.new()
	charge_title.text = "Enemy Charging"
	charge_title.position = Vector2(BAR_X, 155)
	charge_title.add_theme_font_size_override("font_size", 16)
	charge_title.modulate = Color(0.85, 0.45, 0.25)
	add_child(charge_title)

	charge_bg = ColorRect.new()
	charge_bg.position = Vector2(BAR_X, 180)
	charge_bg.size = Vector2(BAR_W, 28)
	charge_bg.color = Color(0.18, 0.10, 0.10)
	add_child(charge_bg)

	charge_fill = ColorRect.new()
	charge_fill.position = Vector2(BAR_X, 180)
	charge_fill.size = Vector2(0.0, 28)
	charge_fill.color = Color(0.80, 0.28, 0.18)
	add_child(charge_fill)

	# ---- Timing window bar ----
	var window_title := Label.new()
	window_title.text = "Timing Window — Press SPACE when the cursor is in the gold zone"
	window_title.position = Vector2(BAR_X, 268)
	window_title.add_theme_font_size_override("font_size", 15)
	window_title.modulate = Color(0.75, 0.75, 0.75)
	add_child(window_title)

	window_bg = ColorRect.new()
	window_bg.position = Vector2(BAR_X, BAR_Y)
	window_bg.size = Vector2(BAR_W, BAR_H)
	window_bg.color = Color(0.15, 0.15, 0.15)
	window_bg.visible = false
	add_child(window_bg)

	# PERFECT zone — leftmost 35%, gold
	perfect_zone = ColorRect.new()
	perfect_zone.position = Vector2(BAR_X, BAR_Y)
	perfect_zone.size = Vector2(BAR_W * PERFECT_THRESHOLD, BAR_H)
	perfect_zone.color = Color(0.88, 0.74, 0.12, 0.55)
	perfect_zone.visible = false
	add_child(perfect_zone)

	# HIT zone — next 40%, green
	hit_zone = ColorRect.new()
	hit_zone.position = Vector2(BAR_X + BAR_W * PERFECT_THRESHOLD, BAR_Y)
	hit_zone.size = Vector2(BAR_W * (HIT_THRESHOLD - PERFECT_THRESHOLD), BAR_H)
	hit_zone.color = Color(0.20, 0.65, 0.28, 0.45)
	hit_zone.visible = false
	add_child(hit_zone)

	# MISS zone — remaining 25%, dark red
	miss_zone = ColorRect.new()
	miss_zone.position = Vector2(BAR_X + BAR_W * HIT_THRESHOLD, BAR_Y)
	miss_zone.size = Vector2(BAR_W * (1.0 - HIT_THRESHOLD), BAR_H)
	miss_zone.color = Color(0.55, 0.12, 0.12, 0.45)
	miss_zone.visible = false
	add_child(miss_zone)

	# Zone labels below bar
	_zone_label("PERFECT", BAR_X + 10,                         BAR_Y + BAR_H + 6,  Color(0.88, 0.74, 0.12))
	_zone_label("HIT",     BAR_X + BAR_W * PERFECT_THRESHOLD + 10, BAR_Y + BAR_H + 6, Color(0.20, 0.85, 0.32))
	_zone_label("MISS",    BAR_X + BAR_W * HIT_THRESHOLD + 10, BAR_Y + BAR_H + 6,  Color(0.85, 0.22, 0.22))

	# Moving cursor (white vertical bar that sweeps left→right)
	cursor = ColorRect.new()
	cursor.size = Vector2(4.0, BAR_H)
	cursor.color = Color(1.0, 1.0, 1.0, 0.95)
	cursor.visible = false
	add_child(cursor)

	# ---- Grade label (large, center-ish) ----
	grade_label = Label.new()
	grade_label.position = Vector2(280, 415)
	grade_label.add_theme_font_size_override("font_size", 72)
	grade_label.visible = false
	add_child(grade_label)

	# ---- Summary label ----
	summary_label = Label.new()
	summary_label.position = Vector2(160, 140)
	summary_label.add_theme_font_size_override("font_size", 26)
	summary_label.modulate = Color(0.90, 0.90, 0.90)
	summary_label.visible = false
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	summary_label.custom_minimum_size = Vector2(500.0, 0.0)
	add_child(summary_label)

	# ---- Controls hint ----
	var hint := Label.new()
	hint.text = "SPACE = action   R = restart"
	hint.position = Vector2(20, 572)
	hint.add_theme_font_size_override("font_size", 14)
	hint.modulate = Color(0.42, 0.42, 0.42)
	add_child(hint)


func _zone_label(text: String, x: float, y: float, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = Vector2(x, y)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.modulate = color
	add_child(lbl)

# ---------------------------------------------------------------------------
# GAME LOOP
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	match state:
		State.CHARGING:         _tick_charging(delta)
		State.WINDOW_OPEN:      _tick_window()
		State.SHOWING_FEEDBACK: _tick_feedback(delta)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_SPACE: _on_space()
		KEY_R:     _restart()


func _start_round() -> void:
	if current_round >= TOTAL_ROUNDS:
		_show_summary()
		return

	charge_timer  = 0.0
	frame_counter = 0
	last_grade    = ""

	round_label.text        = "Round  %d / %d" % [current_round + 1, TOTAL_ROUNDS]
	instruction_label.text  = "Enemy charging... get ready!"
	instruction_label.modulate = Color(0.65, 0.65, 0.65)

	charge_bg.visible   = true
	charge_fill.visible = true
	charge_fill.size.x  = 0.0

	_set_window_visible(false)
	grade_label.visible = false

	state = State.CHARGING


func _tick_charging(delta: float) -> void:
	charge_timer += delta
	charge_fill.size.x = BAR_W * minf(charge_timer / CHARGE_DURATION, 1.0)
	if charge_timer >= CHARGE_DURATION:
		_open_window()


func _open_window() -> void:
	frame_counter = 0
	state = State.WINDOW_OPEN

	charge_bg.visible   = false
	charge_fill.visible = false

	_set_window_visible(true)
	cursor.position.x = BAR_X - 2.0
	cursor.position.y = BAR_Y

	instruction_label.text     = "PRESS SPACE!"
	instruction_label.modulate = Color(1.0, 0.88, 0.10)


func _tick_window() -> void:
	frame_counter += 1
	var t: float = float(frame_counter) / float(WINDOW_FRAMES)
	cursor.position.x = BAR_X + BAR_W * t - 2.0

	if frame_counter >= WINDOW_FRAMES:
		_resolve("MISS")   # window expired without input


func _on_space() -> void:
	if state != State.WINDOW_OPEN:
		return
	var t: float = float(frame_counter) / float(WINDOW_FRAMES)
	var grade: String
	if   t <= PERFECT_THRESHOLD: grade = "PERFECT"
	elif t <= HIT_THRESHOLD:     grade = "HIT"
	else:                        grade = "MISS"
	_resolve(grade)


func _resolve(grade: String) -> void:
	last_grade = grade
	results.append(grade)
	current_round += 1

	_set_window_visible(false)
	grade_label.visible = true
	grade_label.text    = grade

	match grade:
		"PERFECT":
			grade_label.modulate       = Color(1.00, 0.88, 0.10)
			instruction_label.text     = "Perfect timing!"
			instruction_label.modulate = Color(1.00, 0.88, 0.10)
		"HIT":
			grade_label.modulate       = Color(0.28, 0.90, 0.34)
			instruction_label.text     = "Good hit!"
			instruction_label.modulate = Color(0.28, 0.90, 0.34)
		"MISS":
			grade_label.modulate       = Color(0.88, 0.22, 0.22)
			instruction_label.text     = "Too slow!"
			instruction_label.modulate = Color(0.88, 0.22, 0.22)

	feedback_timer = 0.0
	state = State.SHOWING_FEEDBACK


func _tick_feedback(delta: float) -> void:
	feedback_timer += delta
	if feedback_timer >= FEEDBACK_DURATION:
		grade_label.visible = false
		_start_round()


func _set_window_visible(v: bool) -> void:
	window_bg.visible     = v
	perfect_zone.visible  = v
	hit_zone.visible      = v
	miss_zone.visible     = v
	cursor.visible        = v


func _show_summary() -> void:
	state = State.SUMMARY

	charge_bg.visible    = false
	charge_fill.visible  = false
	round_label.visible  = false
	instruction_label.visible = false
	grade_label.visible  = false
	_set_window_visible(false)

	var p := results.count("PERFECT")
	var h := results.count("HIT")
	var m := results.count("MISS")

	var rating: String
	if   p >= 7:         rating = "MASTER"
	elif p >= 5:         rating = "EXPERT"
	elif p >= 3:         rating = "SKILLED"
	elif p + h >= 6:     rating = "COMPETENT"
	else:                rating = "NOVICE"

	summary_label.visible = true
	summary_label.text = (
		"--- COMBAT SUMMARY ---\n\n"
		+ "  PERFECT : %d\n" % p
		+ "  HIT     : %d\n" % h
		+ "  MISS    : %d\n\n" % m
		+ "  Rating  : %s\n\n" % rating
		+ "Press R to play again\n\n"
		+ "--- PLAYTEST QUESTIONS ---\n"
		+ "1. Did it feel MUSICAL? (yes / no / somewhat)\n"
		+ "2. Did PERFECT feel rewarding?\n"
		+ "3. Was the window TOO SHORT / ABOUT RIGHT / TOO LONG?\n"
		+ "4. Did you want to play another round immediately?\n"
		+ "5. One word to describe the feel:"
	)


func _restart() -> void:
	current_round = 0
	results.clear()
	summary_label.visible     = false
	round_label.visible       = true
	instruction_label.visible = true
	_start_round()

class_name LookStick
extends Control
## A thumb stick in the bottom-left corner for looking around the kitchen without touching the work: push it and
## your head turns that way (further = faster), let go near a station and you settle on it, tap it to look back at
## the station you are at. It never touches the dough, so looking and working do not fight.

var R := 54.0                  # the base's radius (larger with Bigger buttons, Settings > Controls)
var KNOB := 24.0
var world: FPWorld
var held := -2                 # the touch (or -1 for the mouse) holding the stick; -2 = none
var start := Vector2.ZERO
var knob := Vector2.ZERO       # where the knob is pushed to, relative to the centre
var moved := false

func _init(w: FPWorld) -> void:
	world = w
	if Game.s.get("big_controls", false):
		R = 70.0
		KNOB = 31.0
	custom_minimum_size = Vector2(R * 2 + 8, R * 2 + 8)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP

func _centre() -> Vector2:
	return size / 2.0

func _gui_input(e: InputEvent) -> void:
	var idx := -1
	var pos := Vector2.ZERO
	var down := false
	var drag := false
	if e is InputEventScreenTouch:
		idx = e.index
		pos = e.position
		down = e.pressed
	elif e is InputEventScreenDrag:
		idx = e.index
		pos = e.position
		drag = true
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		pos = e.position
		down = e.pressed
	elif e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		pos = e.position
		drag = true
	else:
		return
	accept_event()
	if drag:
		if held != idx: return
		knob = (pos - _centre()).limit_length(R)
		if knob.length() > 8.0: moved = true
		world.stick = knob / R
		queue_redraw()
		return
	if down:
		if held != -2 or pos.distance_to(_centre()) > R + 10.0: return
		held = idx
		start = pos
		moved = false
		knob = (pos - _centre()).limit_length(R)
		queue_redraw()
		return
	if held != idx: return
	held = -2
	knob = Vector2.ZERO
	world.stick = Vector2.ZERO
	if moved: world.settle_look()             # let go near a station: settle on it
	else: world.recentre()                    # a tap: back to where you were working
	queue_redraw()

func _draw() -> void:
	var c := _centre()
	var on := held != -2
	draw_circle(c, R, Color(0.06, 0.08, 0.07, 0.42 if on else 0.28))
	draw_arc(c, R, 0, TAU, 48, Color(0.97, 0.93, 0.85, 0.5 if on else 0.32), 2.5, true)
	# four little marks: look up, down, left, right
	for a in 4:
		var d := Vector2.from_angle(a * PI / 2.0)
		draw_line(c + d * (R - 12.0), c + d * (R - 5.0), Color(0.97, 0.93, 0.85, 0.45), 2.0, true)
	draw_circle(c + knob, KNOB, Color(0.97, 0.93, 0.85, 0.85 if on else 0.6))
	draw_circle(c + knob, KNOB * 0.55, Color(0.95, 0.77, 0.31, 0.9 if on else 0.55))

## Looking: "phone" (moving the phone turns your head and faces you to a station, as AR will; both thumbs are your
## hands) or "stick" (the stick and dragging, for a computer). "auto" (the default) is the phone on a phone.
## how you look round (Settings > Controls: Look): "phone" (move the phone: it is your head, both thumbs are your
## hands), "both" (the stick, and turning the phone helps), "stick" (the stick only), "auto" (the phone on a phone,
## the stick on a computer)
static func phone_look() -> bool:
	var m := String(Game.s.get("look", "auto"))
	return m == "phone" or (m == "auto" and OS.has_feature("mobile"))

## with the stick: turning the phone helps too
static func gyro_helps() -> bool:
	return String(Game.s.get("look", "auto")) == "both"

const LOOK_NAMES := {"auto": "automatic", "phone": "move the phone", "both": "stick + phone", "stick": "stick only"}

## the setting's words, and the next one along
static func look_name() -> String:
	return "Look: " + LOOK_NAMES.get(String(Game.s.get("look", "auto")), "automatic")

static func next_look() -> void:
	var order := ["auto", "phone", "both", "stick"]
	Game.s.look = order[(order.find(String(Game.s.get("look", "auto"))) + 1) % order.size()]

## With the phone for looking: no stick, and the station buttons go small into the top bar (tap one to face that
## station from where you stand), leaving both bottom corners to your thumbs. With the stick: the stick in a bottom
## corner (the left, or the right with "Look stick on the right"), the station buttons beside it, larger with "Bigger
## buttons". Both screens in the kitchen use this. Returns the stick, or null.
static func lay_out(parent: Control, w: FPWorld, tabs: HBoxContainer, top_bar: HBoxContainer = null) -> LookStick:
	var big: bool = Game.s.get("big_controls", false)
	if phone_look() and top_bar != null:
		for b in tabs.get_children():
			if not b is Button: continue
			b.custom_minimum_size = Vector2(0, 40 if big else 34)
			b.add_theme_font_size_override("font_size", 16 if big else 14)
		tabs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top_bar.add_child(tabs)
		top_bar.move_child(tabs, 1)
		return null
	var right: bool = Game.s.get("stick_right", false)
	var stk := LookStick.new(w)
	var side: float = stk.custom_minimum_size.x
	stk.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT if right else Control.PRESET_BOTTOM_LEFT)
	stk.offset_bottom = -10
	stk.offset_top = -10 - side
	if right:
		stk.offset_right = -10
		stk.offset_left = -10 - side
	else:
		stk.offset_left = 10
		stk.offset_right = 10 + side
	parent.add_child(stk)
	var h := 60.0 if big else 46.0
	tabs.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	tabs.offset_top = -h - 8.0
	tabs.offset_left = 10.0 if right else 20.0 + side
	for b in tabs.get_children():
		if not b is Button: continue
		b.custom_minimum_size = Vector2(b.custom_minimum_size.x * (1.2 if big else 1.0), h)
		if big: b.add_theme_font_size_override("font_size", 19)
	parent.add_child(tabs)
	return stk

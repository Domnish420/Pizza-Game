class_name LookStick
extends Control
## A thumb stick in the bottom-left corner for looking around the kitchen without touching the work: push it and
## your head turns that way (further = faster), let go near a station and you settle on it, tap it to look back at
## the station you are at. It never touches the dough, so looking and working do not fight.

const R := 54.0                # the base's radius
const KNOB := 24.0
var world: FPWorld
var held := -2                 # the touch (or -1 for the mouse) holding the stick; -2 = none
var start := Vector2.ZERO
var knob := Vector2.ZERO       # where the knob is pushed to, relative to the centre
var moved := false

func _init(w: FPWorld) -> void:
	world = w
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

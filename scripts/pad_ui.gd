class_name PadUI
extends Node
## A game controller on the game's screens (the 2D ones: the title, the hub, the phone, a job's sheet, a dialog). Each
## stick moves a ring for that hand; the trigger is a finger on the screen there (press, drag, let go: buttons,
## scrubbing, kneading, folding); A clicks under the last-moved hand's ring when nothing has the focus (in VR, before
## the sticks are used, A clicks where you look instead: VRView); the d-pad scrolls.
## In the 3D kitchen FPWorld moves the hands and comes here only when a hand points at a 2D screen; on the other
## screens this reads the controller itself. In VR the screens are on the panel: the rings move over it.
##
## The controller is read in one place (read()); tests set PadUI.test (or FPWorld.pad_test) instead.

static var test = null                  # tests: a Dictionary standing in for the controller

var rings: Array = []                   # a ring per hand on the screens
var at := [Vector2.ZERO, Vector2.ZERO]  # where each hand points on the screens (pixels), away from the kitchen
var down := [false, false]
var last := 0                           # the hand that moved last (A and the d-pad use it)
var on := false                         # the controller is in use here
var btn := {}

## the controller now: both sticks, both triggers, the stick clicks (thumbs), shoulders, Start, A, the d-pad
static func read() -> Dictionary:
	if test != null: return test
	var pads := Input.get_connected_joypads()
	if pads.is_empty(): return {}
	var d: int = pads[0]
	return {
		"l": Vector2(Input.get_joy_axis(d, JOY_AXIS_LEFT_X), Input.get_joy_axis(d, JOY_AXIS_LEFT_Y)),
		"r": Vector2(Input.get_joy_axis(d, JOY_AXIS_RIGHT_X), Input.get_joy_axis(d, JOY_AXIS_RIGHT_Y)),
		"lt": Input.get_joy_axis(d, JOY_AXIS_TRIGGER_LEFT),
		"rt": Input.get_joy_axis(d, JOY_AXIS_TRIGGER_RIGHT),
		"l3": Input.is_joy_button_pressed(d, JOY_BUTTON_LEFT_STICK),
		"r3": Input.is_joy_button_pressed(d, JOY_BUTTON_RIGHT_STICK),
		"lb": Input.is_joy_button_pressed(d, JOY_BUTTON_LEFT_SHOULDER),
		"rb": Input.is_joy_button_pressed(d, JOY_BUTTON_RIGHT_SHOULDER),
		"start": Input.is_joy_button_pressed(d, JOY_BUTTON_START),
		"a": Input.is_joy_button_pressed(d, JOY_BUTTON_A),
		"up": Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_UP),
		"down": Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_DOWN),
	}

## where the game's screens are drawn: the window, or in VR the panel's viewport
func ui_vp() -> Viewport:
	return Kit.main.vr.ui_vp if VRView.active and Kit.main.vr != null else Kit.main.get_viewport()

func _screen_size() -> Vector2:
	var vp := ui_vp()
	return Vector2(vp.size) if vp is SubViewport else vp.get_visible_rect().size

# ---------- a finger on the screens ----------
## a finger going down on (or lifting off) the screens at u ({vp, px}): the mouse there, as a touch makes it
func mouse(u: Dictionary, is_down: bool) -> void:
	if is_down:
		var mm := InputEventMouseMotion.new()
		mm.position = u.px
		mm.global_position = u.px
		u.vp.push_input(mm, true)
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = is_down
	mb.button_mask = MOUSE_BUTTON_MASK_LEFT if is_down else 0
	mb.position = u.px
	mb.global_position = u.px
	u.vp.push_input(mb, true)
	if is_down: Kit.main.pad = true

## and moving with it down (scrubbing, kneading, dragging), from `from`
func drag(u: Dictionary, from: Vector2) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = u.px
	mm.global_position = u.px
	mm.relative = u.px - from
	mm.button_mask = MOUSE_BUTTON_MASK_LEFT
	u.vp.push_input(mm, true)

## a click (down and up) at u
func click(u: Dictionary) -> void:
	mouse(u, true)
	mouse(u, false)

## scroll what is at u (the phone's pages, a long list)
func scroll(u: Dictionary, up: bool) -> void:
	for d in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
		mb.pressed = d
		mb.factor = 3.0
		mb.position = u.px
		mb.global_position = u.px
		u.vp.push_input(mb, true)

## show hand i's ring at u ({vp, px}), or hide it (u null)
func ring(i: int, u, pressed: bool) -> void:
	var host: Node = Kit.main.content.get_parent()
	while rings.size() <= i: rings.append(null)
	if rings[i] == null or not is_instance_valid(rings[i]): rings[i] = Ring.new()
	var r: Ring = rings[i]
	if r.get_parent() != host:
		if r.get_parent() != null: r.get_parent().remove_child(r)
		host.add_child(r)
	r.visible = u != null
	if u == null: return
	r.position = u.px
	r.pressed = pressed
	if r.get_index() != host.get_child_count() - 1: host.move_child(r, -1)

# ---------- the screens away from the kitchen ----------
## the 3D kitchen on screen, if there is one (it moves the hands itself)
func _kitchen() -> bool:
	var s = Kit.main.screen()
	if s == null: return false
	if s.get("world") != null: return true
	return s.get("fp") != null

func _process(dt: float) -> void:
	if Kit.main == null or _kitchen():
		return
	var p := read()
	if p.is_empty():
		if on: _off()
		return
	var sticks: Array = [p.get("r", Vector2.ZERO), p.get("l", Vector2.ZERO)]
	var trig: Array = [float(p.get("rt", 0.0)), float(p.get("lt", 0.0))]
	var size := _screen_size()
	if not on:
		for i in 2:
			if sticks[i].length() > 0.4 or trig[i] > 0.6: on = true
		if not on: return
		Kit.main.pad = true
		at = [size * Vector2(0.62, 0.55), size * Vector2(0.38, 0.55)]
	var vp := ui_vp()
	for i in 2:
		var v: Vector2 = sticks[i]
		var mag := clampf((v.length() - 0.15) / 0.85, 0.0, 1.0)
		var prev: Vector2 = at[i]
		if mag > 0.0:
			at[i] = (prev + v.normalized() * pow(mag, 1.6) * size.y * 0.95 * dt).clamp(Vector2(4, 4), size - Vector2(4, 4))
			last = i
		var want: bool = trig[i] > (0.3 if down[i] else 0.55)
		if want != down[i] and not (want and down[1 - i]):
			down[i] = want
			mouse({"vp": vp, "px": at[i]}, want)
			if want: Art.buzz(6)
		elif down[i] and at[i] != prev:
			drag({"vp": vp, "px": at[i]}, prev)
		ring(i, {"vp": vp, "px": at[i]}, down[i])
	for b in ["a", "up", "down"]:
		var pressed: bool = p.get(b, false)
		if pressed and not btn.get(b, false):
			var u := {"vp": vp, "px": at[last]}
			match b:
				"a":
					# A presses the focused button (a dialog's gold ring); otherwise it clicks under the last hand
					if vp.gui_get_focus_owner() == null: click(u)
				"up", "down":
					if not Kit.main.modal_root.visible: scroll(u, b == "up")
		btn[b] = pressed

func _off() -> void:
	on = false
	var vp := ui_vp()
	for i in 2:
		if down[i]: mouse({"vp": vp, "px": at[i]}, false)
		down[i] = false
		ring(i, null, false)

## the ring a controller's hand shows on the game's screens
class Ring extends Control:
	var pressed := false:
		set(v):
			if v != pressed:
				pressed = v
				queue_redraw()
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 100
	func _draw() -> void:
		draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 28, Color(0, 0, 0, 0.5), 5.0)
		draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 28, Kit.CHEESE if pressed else Color.WHITE, 3.0)
		draw_circle(Vector2.ZERO, 3.0, Kit.CHEESE)

class_name Bench
extends Control
## The prep bench and the cutting board (320 x 320 units): draws the pizza being worked on and reads your hands.
##
## Opening a hand-stretched base:
##   one finger    presses the dough out with your fingertips (leave the edge alone to keep a rim)
##   two fingers   spread them apart to stretch the dough along that line; twist them to turn the dough
## Rolled bases: drag one finger (or two, like two hands on the pin) to roll. Pan bases: rub the dough outward.
## On a computer the left mouse button is one finger; the right button (or Shift + left) is two fingers
## spread either side of the middle.
##
## Shaping a hand-stretched base, every technique there from the start, for anyone:
##   press         one finger on the dough: fingertips pressing it out (leave the edge for the crust)
##   stretch       two fingers spreading apart; twisting them turns it
##   slap          a quick flick outward from the crust: the Neapolitan slap, stretching it and keeping the crust
##   lift          two fingers held still on the dough a moment: it comes up onto your knuckles
##   drape         lifted, turn your two fingers round each other: it turns on your knuckles and its weight stretches it
##   toss          lifted, turn it and flick both fingers off as you let go: it flies, spinning as fast as you were
##                 turning it (no spin: it flops; far too much for how thin it is: it tears). A finger on the bench as it
##                 comes down catches it.
##
## There are no steps: the moment the dough is on the bench you can shape it, top it or take it to the oven.
##
## Each finger is a hand, and the two work independently. The hand holding something (a topping, the cheese, the
## ladle) puts it on where that finger goes; an empty hand works the dough (one presses, two stretch) or, on the
## cutting board, swipes the wheel through. So you can hold the dough still with one thumb while the other scatters
## the basil. In the 3D kitchen your left thumb is your left hand (the one that picked a thing up keeps it); in the
## flat layout, the first finger down holds it.

const S := 320.0
const C := Vector2(160, 160)     # where the pizza's centre sits

var svc: ServiceScreen
var font: Font
var touches := {}                # finger index -> last position, pizza-local
var roles := {}                  # finger index -> what that hand is doing: "tool", "cut", "dough" or ""
var fs := {}                     # finger index -> {at0 (where it went down), c0 (when, on the clock), last, t (us),
                                 #   v (velocity, units a second), mc (when it last moved), slapped, pending (its press
                                 #   not made yet)}
var clock := 0.0                 # seconds, frame by frame (what the gestures are timed by)
var pad_hand := {}               # finger index -> true while it is a game controller's hand (FPWorld): a stick cannot move a
                                 #   hand as fast as a real one, so its speed counts PAD_K times, and its press waits for the stick
const PAD_K := 2.5
var test_dt := 0.0               # tests: a fixed time for each frame and between a finger's moves (0: the real time)
var twists := []                 # [clock, radians]: how your two hands under the lifted dough turned it, lately
var line_ang = null              # the angle of the line between your two hands under it, last time (null: not yet)
var xr_hold := false             # a headset's real hands hold the lifted dough (FPWorld moves it, not the fingers here)
const LIFT_HOLD := 0.45          # two fingers held this long (seconds), still, on the dough: it comes up onto your knuckles
const TOSS_SPEED := 450.0        # letting go of the lifted dough this fast (bench units a second) throws it up
const SLAP_SPEED := 650.0        # a flick outward from the crust this fast slaps it
const SPIN_OVER := 0.3           # the spin you give it is how far your hands turned it over this long (seconds)
const PRESS_WAIT := 0.08         # a fingertip's press waits this long (seconds) to see that it is not a slap
var cuts_from := {}              # finger index -> where its swipe of the wheel started
var mouse := ""                  # "" / "one" / "two"
var mouse_at := Vector2.ZERO
var cut_from = null
var cut_to = null
var pin_at = null
var last_touch := 0
var mode := ""                   # "bench" or "board" for a fixed surface in the 3D kitchen; "" follows svc.view (2D layout)
var draw3d := false              # the 3D kitchen draws the surface and the pizza itself (Pizza3D): only draw the guides

func _init(service: ServiceScreen) -> void:
	svc = service
	set_anchors_preset(Control.PRESET_FULL_RECT)
	font = ThemeDB.fallback_font
	clip_contents = true

## which surface this is showing: the bench or the cutting board
func _v() -> String:
	return mode if mode != "" else svc.view

func _k() -> float:
	return min(size.x, size.y) / S

func _off() -> Vector2:
	return (size - Vector2(S, S) * _k()) / 2.0

func _local(pos: Vector2) -> Vector2:
	return (pos - _off()) / _k() - C

# ---------- input ----------
func _gui_input(e: InputEvent) -> void:
	if not svc.busy.is_empty():
		if e is InputEventMouseButton or e is InputEventScreenTouch:
			if e.pressed: svc.is_free()
		if e is InputEventScreenTouch and not e.pressed:
			touches.erase(e.index)                  # a hand lifted while you were busy is still lifted
			roles.erase(e.index)
			cuts_from.erase(e.index)
		return
	if e is InputEventScreenTouch:
		last_touch = Time.get_ticks_msec()
		var p := _local(e.position)
		if e.pressed:
			touches[e.index] = p
			_finger_down(e.index, p)
		elif touches.has(e.index):
			touches.erase(e.index)
			_finger_up(e.index, p)
		accept_event()
	elif e is InputEventScreenDrag:
		last_touch = Time.get_ticks_msec()
		if touches.has(e.index):
			var p := _local(e.position)
			var prev: Vector2 = touches[e.index]
			touches[e.index] = p
			_finger_move(e.index, prev, p)
		accept_event()
	elif e is InputEventMouseButton:
		if e.device == InputEvent.DEVICE_ID_EMULATION or Time.get_ticks_msec() - last_touch < 500: return
		var p := _local(e.position)
		if e.pressed:
			mouse = "two" if (e.button_index == MOUSE_BUTTON_RIGHT or e.shift_pressed) else "one"
			mouse_at = p
			if mouse == "one": _down(p)
		else:
			if mouse == "one": _up(p)
			mouse = ""
	elif e is InputEventMouseMotion and mouse != "":
		if e.device == InputEvent.DEVICE_ID_EMULATION: return
		var p := _local(e.position)
		if mouse == "one": _move(mouse_at, p)
		else: _mirror(mouse_at, p)
		mouse_at = p

## the dough on the bench, if your fingers are working it: two fingers always stretch it; one finger presses it out
## when your hand is empty (holding a topping or the ladle, one finger puts that on instead)
func _shaping(two: bool = false):
	var pz = svc.bench
	return pz if (_v() == "bench" and pz != null and pz.stage == "shape" and (two or svc.tool == "")) else null

# ---------- fingers, each its own hand ----------
## this finger is the hand holding something: in the 3D kitchen, the hand that picked it up; in the flat layout, the
## first finger down
func _holds(index: int) -> bool:
	if svc.tool == "": return false
	if mode != "": return index == svc.tool_hand
	return not roles.values().has("tool")

## another finger working the dough, if there is one
func _other_dough(index: int):
	for i in roles:
		if i != index and roles[i] == "dough" and touches.has(i): return touches[i]
	return null

func _finger_down(index: int, p: Vector2) -> void:
	var pad: bool = pad_hand.get(index, false)
	var f := {"at0": p, "c0": clock, "last": p, "t": Time.get_ticks_usec(), "v": Vector2.ZERO, "mc": clock, "slapped": false, "pending": false,
		"k": PAD_K if pad else 1.0, "wait": PRESS_WAIT * (3.0 if pad else 1.0)}
	fs[index] = f
	var role := ""
	if _holds(index):
		role = "tool"
		svc.apply_tool(p, null)
	elif _v() == "board":
		role = "cut"
		cuts_from[index] = p
		cut_from = p
		cut_to = p
	elif _shaping(true) != null:
		role = "dough"
		var b: PizzaBase = _shaping(true).base
		if b.air <= 0.0 and not b.lifted and _other_dough(index) == null:
			if b.method == "hand": f.pending = true          # (pressed in a moment, unless it is a flick: the slap)
			else: _dough_down(_shaping(true), p)
	roles[index] = role

## a fingertip's press, held back to see it was not a slap, made now
func _press_pending(index: int) -> void:
	var f = fs.get(index)
	if f == null or not f.pending: return
	f.pending = false
	var pz = _shaping()
	if pz != null and pz.base.air <= 0.0 and not pz.base.lifted: _dough_down(pz, f.at0)

## how fast each finger is moving (units a second, smoothed)
func _track(index: int, p: Vector2) -> void:
	var f = fs.get(index)
	if f == null: return
	var now := Time.get_ticks_usec()
	var dt := test_dt if test_dt > 0.0 else maxf((now - int(f.t)) / 1000000.0, 0.001)
	f.v = (f.v as Vector2).lerp((p - (f.last as Vector2)) / dt * float(f.k), 0.5)
	f.t = now
	f.last = p
	f.mc = clock

func _finger_move(index: int, prev: Vector2, p: Vector2) -> void:
	_track(index, p)
	var pz = _shaping(true)
	if roles.get(index, "") == "dough" and pz != null:
		var b: PizzaBase = pz.base
		if b.air > 0.0 or xr_hold or b.lifted: return         # (in the air, in a headset's real hands; lifted: see _process)
		if _other_dough(index) == null and _slapped(index, b): return
		var f = fs.get(index)
		if f != null and f.pending:
			# a slow stroke is pressing after all; a quick one may yet be a slap
			if (f.v as Vector2).length() > SLAP_SPEED * 0.4 and clock - float(f.c0) < float(f.wait): return
			_press_pending(index)
	match roles.get(index, ""):
		"tool": svc.apply_tool(p, prev)
		"cut":
			cut_from = cuts_from[index]
			cut_to = p
		"dough":
			if pz == null: return
			var other = _other_dough(index)
			if other != null: _two(prev, p, other)
			else: _dough_move(pz, prev, p)

## the angle of the line between your two hands on the dough (from the first finger down to the other), or null
func _hands_line():
	var ids: Array = roles.keys().filter(func(i): return roles[i] == "dough" and touches.has(i))
	ids.sort()
	if ids.size() < 2: return null
	return (touches[ids[1]] - touches[ids[0]]).angle()

## a quick flick outward from the crust: the slap (once a stroke). True if it was one (or a stroke that slapped).
func _slapped(index: int, b: PizzaBase) -> bool:
	var f = fs.get(index)
	if f == null: return false
	if f.slapped: return true                                            # (the rest of the stroke flicks off past it)
	var v: Vector2 = f.v
	var a0: Vector2 = f.at0
	if v.length() < SLAP_SPEED * 0.8: return false
	f.pending = false
	if a0.length() < b.rad_at(a0.angle()) * 0.6: return true             # (a fast stroke in the middle just skims it)
	if v.dot(a0.normalized()) < v.length() * 0.5: return true
	f.slapped = true
	b.slap(v.normalized(), clampf(v.length() / 1500.0, 0.3, 1.0))
	Art.sfx("slap", true)
	Art.buzz(14)
	svc.dirty = true
	return true

func _finger_up(index: int, p: Vector2) -> void:
	_press_pending(index)                                # (a tap: a press)
	var role: String = roles.get(index, "")
	roles.erase(index)
	var f = fs.get(index)
	fs.erase(index)
	if role == "dough" and _shaping(true) != null and not xr_hold:
		var b: PizzaBase = _shaping(true).base
		if b.lifted:
			var sp: float = (f.v as Vector2).length() if f != null and clock - float(f.mc) <= 0.2 else 0.0   # (still moving as it let go)
			if sp > TOSS_SPEED:
				tossed(b.toss(spin(), clampf(sp / 1500.0, 0.4, 1.1)))
				line_ang = null
			elif not roles.values().has("dough"):
				b.lifted = false                         # set back down on the bench
				Art.sfx("slap", true, 0.2)
	match role:
		"tool": svc.stroke_end(p)
		"cut":
			svc.cut(cuts_from[index], p)
			cuts_from.erase(index)
			cut_from = null
			cut_to = null
		"dough":
			if not roles.values().has("dough"): pin_at = null

## your hands under the lifted dough turned it by `d` radians: it turns, its weight stretches it, and it is the spin
## it goes up with if you throw it now
func twist(d: float) -> void:
	var pz = _shaping(true)
	if pz == null: return
	pz.base.drape(d)
	twists.append([clock, d])

## the spin you are giving the lifted dough: revolutions a second (+ anticlockwise), over the last moment
func spin() -> float:
	var s := 0.0
	for x in twists:
		if clock - float(x[0]) <= SPIN_OVER: s += float(x[1])
	return s / SPIN_OVER / TAU

## the time a frame took (the real one; tests can fix it)
func frame_dt(real: float) -> float:
	return test_dt if test_dt > 0.0 else real

## each frame: two fingers held still on the dough lift it onto your knuckles; a tossed base comes down
func _process(dt: float) -> void:
	dt = frame_dt(dt)
	clock += dt
	while not twists.is_empty() and clock - float(twists[0][0]) > SPIN_OVER: twists.pop_front()
	for i in fs:
		if fs[i].pending and clock - float(fs[i].c0) >= float(fs[i].wait): _press_pending(i)
	var pz = _shaping(true)
	if pz == null or pz.base.method != "hand": return
	var b: PizzaBase = pz.base
	if b.air > 0.0 or b.lifted: queue_redraw()
	# on your knuckles: turning your two hands round each other turns it, and its weight stretches it (measured once a
	# frame, when both fingers have moved: one moving before the other is not a turn)
	if b.lifted and not xr_hold and _hands_line() != null:
		var ang: float = _hands_line()
		if line_ang != null: twist(angle_difference(float(line_ang), ang))
		line_ang = ang
	else:
		line_ang = null
	if b.fly(dt):
		var caught: bool = roles.values().has("dough")
		Art.sfx("slap", true)
		Art.buzz(10)
		if caught: Kit.main.toast("Caught it")
		svc.dirty = true
	if b.lifted or b.air > 0.0 or xr_hold: return
	var still := 0
	for i in roles:
		if roles[i] != "dough" or not fs.has(i): continue
		var f: Dictionary = fs[i]
		if clock - float(f.c0) >= LIFT_HOLD and (f.last as Vector2).distance_to(f.at0) < 8.0: still += 1
	if still >= 2:
		b.lifted = true
		twists.clear()
		line_ang = _hands_line()                 # (turns are measured from here)
		Art.sfx("slap", true, 0.2)
		if not b.get_meta("lift_told", false):
			b.set_meta("lift_told", true)
			Kit.main.toast("On your knuckles: turn your fingers round to stretch it, turn and flick them off to toss it")

## how a toss went: a word, and the sound of it landing comes when it lands
func tossed(res: String) -> void:
	Art.sfx("slap", true, 0.2)
	match res:
		"stretched": Kit.main.toast("Up it goes, spinning: it opens out evenly")
		"flop": Kit.main.toast("It flopped: give it a spin as you throw it (turn your fingers round, then flick)", true)
		"tore": Kit.main.toast("It tore: too fast a spin for how thin it is", true)
	svc.dirty = true

## one finger goes down (the mouse)
func _down(p: Vector2) -> void:
	if _v() == "board":
		if svc.tool == "":
			cut_from = p
			cut_to = p
		else:
			svc.apply_tool(p, null)
		return
	var pz = _shaping()
	if pz == null: svc.apply_tool(p, null)
	else: _dough_down(pz, p)

## a hand goes down on the dough
func _dough_down(pz, p: Vector2) -> void:
	if pz.base.method == "hand":
		if pz.base.press(p): _pressed_through()
		Art.sfx("slap", true, 0.18)            # a floury pat on the marble
		Art.buzz(8)
	elif pz.base.method == "roll":
		pin_at = p

## one finger moves (the mouse)
func _move(prev: Vector2, p: Vector2) -> void:
	if _v() == "board":
		if svc.tool == "": cut_to = p
		else: svc.apply_tool(p, prev)
		return
	var pz = _shaping()
	if pz == null: svc.apply_tool(p, prev)
	else: _dough_move(pz, prev, p)

## one hand works the dough
func _dough_move(pz, prev: Vector2, p: Vector2) -> void:
	match pz.base.method:
		"hand":
			if pz.base.press(p, 16.0, (p - prev).length()): _pressed_through()
		"roll":
			if _pin(): pz.base.roll(p, p - prev)
			pin_at = p
		_: pz.base.pan(p, p - prev)

## a fingertip went right through, working one spot too long
func _pressed_through() -> void:
	Art.sfx("slap", true)
	Art.buzz(20)
	Kit.main.toast("Pressed right through: a hole. Work it out evenly from the middle, not in one spot", true)
	svc.dirty = true

## a rolled base needs the rolling pin (or the sheeter button)
var _pin_warned := false
func _pin() -> bool:
	if Equip.can_roll(): return true
	if not _pin_warned:
		_pin_warned = true
		Kit.main.toast("You have no rolling pin. Order one from %s, or press it out by hand (it will not be even)." % Equip.SHOP.name, true)
	return false

func _up(p: Vector2) -> void:
	svc.stroke_end(p)
	if cut_from != null:
		svc.cut(cut_from, p)
	cut_from = null
	cut_to = null
	pin_at = null

## one of two hands on the dough moves (other: where the other one is)
func _two(prev: Vector2, p: Vector2, other) -> void:
	var pz = _shaping(true)
	if pz == null: return
	Art.sfx("slap", true, 0.45)                # the dough slapping as it is stretched
	match pz.base.method:
		"hand":
			pz.base.stretch(prev, p)
			if other != null:
				pz.base.rotate(angle_difference((prev - other).angle(), (p - other).angle()) * 0.5)
		"roll":
			var mid: Vector2 = (p + other) / 2.0 if other != null else p
			if _pin(): pz.base.roll(mid, (p - prev) / 2.0)
			pin_at = mid
		_: pz.base.pan(p, p - prev)

## mouse stand-in for two fingers: the second finger mirrors the first through the middle of the dough
func _mirror(prev: Vector2, p: Vector2) -> void:
	var pz = _shaping(true)
	if pz == null: return
	match pz.base.method:
		"hand":
			pz.base.stretch(prev, p)
			pz.base.stretch(-prev, -p)
			if prev.length() > 12.0 and p.length() > 12.0:
				pz.base.rotate(angle_difference(prev.angle(), p.angle()))
		"roll":
			if _pin(): pz.base.roll(Vector2.ZERO, p - prev)
			pin_at = Vector2.ZERO
		_: pz.base.pan(p, p - prev)

# ---------- drawing ----------
func _text(pos: Vector2, text: String, px: int, col: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(font, pos - Vector2(w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)

func _draw() -> void:
	var k := _k()
	var off := _off()
	draw_set_transform(off, 0, Vector2(k, k))
	var on_board: bool = _v() == "board"
	var t = Art.tex("board.bg" if on_board else "bench.bg")
	if draw3d: pass
	elif t != null: draw_texture_rect(t, Rect2(0, 0, S, S), false)
	elif on_board:
		draw_rect(Rect2(0, 0, S, S), Color("6b4a2b"))
		draw_circle(C, 152, Color("c69a62"))
	else:
		draw_rect(Rect2(0, 0, S, S), Color("8a8f8a"))
	var pz = (svc.board[0] if svc.board.size() > 0 else null) if on_board else svc.bench
	if pz == null:
		_text(C + Vector2(0, -4), "Nothing on the board" if on_board else "Tap an order to start a pizza", 15, Color(0.08, 0.12, 0.1, 0.8))
		return
	var shaping: bool = pz.stage == "shape"
	if pz.base.method == "press":
		var pt = Art.tex("pan")
		if draw3d: pass                                   # the 3D pizza has its own pan
		elif pt != null: draw_texture_rect(pt, Rect2(C - Vector2.ONE * (pz.base.R + 12), Vector2.ONE * (pz.base.R + 12) * 2), false)
		else:
			draw_circle(C, pz.base.R + 10, Color("2b2b2b"))
			draw_circle(C, pz.base.R + 3, Color("3d3d3d"))
	elif shaping:
		draw_arc(C, pz.base.R, 0, TAU, 64, Color(1, 1, 1, 0.85), 2.0)
		if pz.base.crust >= 1.0: draw_arc(C, pz.base.R - pz.base.crust, 0, TAU, 64, Color(1, 1, 1, 0.3), 1.0)
	if not draw3d:
		var hgt: float = pz.base.height()                 # lifted or in the air: nearer you, its shadow on the marble
		if hgt > 0.0: draw_circle(off + C * k, pz.base.mean_r() * k, Color(0, 0, 0, 0.18))
		PizzaDraw.draw(self, pz, off + C * k, k * (1.0 + hgt * 1.5))
	draw_set_transform(off, 0, Vector2(k, k))
	if on_board and cut_from != null and cut_to != null:
		draw_dashed_line(C + cut_from, C + cut_to, Color(1, 1, 1, 0.75), 2.0, 6.0)
	if shaping and pin_at != null:
		var pin = Art.tex("pin")
		if pin != null: draw_texture_rect(pin, Rect2(C + pin_at - Vector2(75, 13), Vector2(150, 26)), false)
		else:
			draw_rect(Rect2(C.x + pin_at.x - 60, C.y + pin_at.y - 9, 120, 18), Color("b98a55"))
			draw_rect(Rect2(C.x + pin_at.x - 78, C.y + pin_at.y - 4, 156, 8), Color("8c6238"))
	# show where your fingers are, so a two-finger hold is easy to see
	if shaping:
		for i in touches: draw_circle(C + touches[i], 15, Color(1, 1, 1, 0.22))
		if mouse == "two":
			draw_circle(C + mouse_at, 15, Color(1, 1, 1, 0.22))
			draw_circle(C - mouse_at, 15, Color(1, 1, 1, 0.22))

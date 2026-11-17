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
## Topping: drag to spread sauce and cheese, tap or drag to place toppings. Cutting board: swipe to slice.

const S := 320.0
const C := Vector2(160, 160)     # where the pizza's centre sits

var svc: ServiceScreen
var font: Font
var touches := {}                # finger index -> last position, pizza-local
var mouse := ""                  # "" / "one" / "two"
var mouse_at := Vector2.ZERO
var cut_from = null
var cut_to = null
var pin_at = null
var last_touch := 0

func _init(service: ServiceScreen) -> void:
	svc = service
	set_anchors_preset(Control.PRESET_FULL_RECT)
	font = ThemeDB.fallback_font
	clip_contents = true

func _k() -> float:
	return min(size.x, size.y) / S

func _off() -> Vector2:
	return (size - Vector2(S, S) * _k()) / 2.0

func _local(pos: Vector2) -> Vector2:
	return (pos - _off()) / _k() - C

# ---------- input ----------
func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		last_touch = Time.get_ticks_msec()
		var p := _local(e.position)
		if e.pressed:
			touches[e.index] = p
			if touches.size() == 1: _down(p)
		else:
			touches.erase(e.index)
			if touches.is_empty(): _up(p)
		accept_event()
	elif e is InputEventScreenDrag:
		last_touch = Time.get_ticks_msec()
		if touches.has(e.index):
			var p := _local(e.position)
			var prev: Vector2 = touches[e.index]
			touches[e.index] = p
			if touches.size() >= 2: _two(e.index, prev, p)
			else: _move(prev, p)
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

func _shaping():
	var pz = svc.bench
	return pz if (svc.view == "bench" and pz != null and pz.stage == "shape") else null

## one finger goes down
func _down(p: Vector2) -> void:
	if svc.view == "board":
		if svc.tool == "":
			cut_from = p
			cut_to = p
		else:
			svc.apply_tool(p, null)
		return
	var pz = _shaping()
	if pz == null:
		svc.apply_tool(p, null)
	elif pz.base.method == "hand":
		pz.base.press(p)
	elif pz.base.method == "roll":
		pin_at = p

## one finger moves
func _move(prev: Vector2, p: Vector2) -> void:
	if svc.view == "board":
		if svc.tool == "": cut_to = p
		else: svc.apply_tool(p, prev)
		return
	var pz = _shaping()
	if pz == null:
		svc.apply_tool(p, prev)
		return
	match pz.base.method:
		"hand": pz.base.press(p)
		"roll":
			pz.base.roll(p, p - prev)
			pin_at = p
		_: pz.base.pan(p, p - prev)

func _up(p: Vector2) -> void:
	if cut_from != null:
		svc.cut(cut_from, p)
	cut_from = null
	cut_to = null
	pin_at = null

## one of two (or more) fingers moves
func _two(index: int, prev: Vector2, p: Vector2) -> void:
	var pz = _shaping()
	if pz == null: return
	var other = null
	for i in touches:
		if i != index: other = touches[i]
	match pz.base.method:
		"hand":
			pz.base.stretch(prev, p)
			if other != null:
				pz.base.rotate(angle_difference((prev - other).angle(), (p - other).angle()) * 0.5)
		"roll":
			var mid: Vector2 = (p + other) / 2.0 if other != null else p
			pz.base.roll(mid, (p - prev) / 2.0)
			pin_at = mid
		_: pz.base.pan(p, p - prev)

## mouse stand-in for two fingers: the second finger mirrors the first through the middle of the dough
func _mirror(prev: Vector2, p: Vector2) -> void:
	var pz = _shaping()
	if pz == null: return
	match pz.base.method:
		"hand":
			pz.base.stretch(prev, p)
			pz.base.stretch(-prev, -p)
			if prev.length() > 12.0 and p.length() > 12.0:
				pz.base.rotate(angle_difference(prev.angle(), p.angle()))
		"roll":
			pz.base.roll(Vector2.ZERO, p - prev)
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
	var on_board: bool = svc.view == "board"
	var t = Art.tex("board.bg" if on_board else "bench.bg")
	if t != null: draw_texture_rect(t, Rect2(0, 0, S, S), false)
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
		if pt != null: draw_texture_rect(pt, Rect2(C - Vector2.ONE * (pz.base.R + 12), Vector2.ONE * (pz.base.R + 12) * 2), false)
		else:
			draw_circle(C, pz.base.R + 10, Color("2b2b2b"))
			draw_circle(C, pz.base.R + 3, Color("3d3d3d"))
	elif shaping:
		draw_arc(C, pz.base.R, 0, TAU, 64, Color(1, 1, 1, 0.85), 2.0)
		if pz.base.crust >= 1.0: draw_arc(C, pz.base.R - pz.base.crust, 0, TAU, 64, Color(1, 1, 1, 0.3), 1.0)
	PizzaDraw.draw(self, pz, off + C * k, k)
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

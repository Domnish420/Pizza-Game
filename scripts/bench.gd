class_name Bench
extends Control
## Draws the pizza on the bench or the cutting board (320 x 320 game units) and reads the player's strokes:
## stretching / rolling / pressing the base, saucing, cheesing, placing toppings, slicing.
## All artwork is requested through Art.tex(key); the shapes drawn here are placeholders.

const S := 320.0
var svc: ServiceScreen
var font: Font
var prev = null
var start = null
var cur = null

func _init(service: ServiceScreen) -> void:
	svc = service
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	font = ThemeDB.fallback_font
	clip_contents = true

func _k() -> float:
	return min(size.x, size.y) / S

func _off() -> Vector2:
	return (size - Vector2(S, S) * _k()) / 2.0

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = (e.position - _off()) / _k()
		if e.pressed:
			prev = p
			start = p
			cur = p
			svc.bench_drag(p, null)
		else:
			if start != null: svc.board_cut(start, p)
			prev = null
			start = null
	elif e is InputEventMouseMotion and prev != null:
		var p: Vector2 = (e.position - _off()) / _k()
		svc.bench_drag(p, prev)
		prev = p
		cur = p

func _outline(pz: Dictionary, k: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 72:
		var a := i * TAU / 72
		pts.append(ServiceScreen.BC + Vector2.from_angle(a) * svc.rad_at(pz, a) * k)
	return pts

func _text(pos: Vector2, text: String, px: int, col: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(font, pos - Vector2(w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)

func _topping(tp: Dictionary) -> void:
	var pos := Vector2(tp.x, tp.y)
	var t = Art.tex("top." + tp.t)
	draw_set_transform(_off() + pos * _k(), tp.a, Vector2(_k(), _k()))
	if t != null:
		draw_texture_rect(t, Rect2(-12, -12, 24, 24), false)
	else:
		var i = Data.ING[tp.t]
		var col := Color(i.col)
		match i.shape:
			"disc":
				draw_circle(Vector2.ZERO, 9, col)
				draw_circle(Vector2(-3, -2), 1.5, col.darkened(0.3))
				draw_circle(Vector2(3, 3), 1.5, col.darkened(0.3))
			"leaf":
				draw_colored_polygon(PackedVector2Array([Vector2(-10, 0), Vector2(-3, -5), Vector2(6, -4), Vector2(10, 0), Vector2(6, 4), Vector2(-3, 5)]), col)
				draw_line(Vector2(-9, 0), Vector2(9, 0), col.darkened(0.3), 1.0)
			"cap":
				draw_colored_polygon(PackedVector2Array([Vector2(-8, 0), Vector2(-6, -5), Vector2(0, -8), Vector2(6, -5), Vector2(8, 0)]), col)
				draw_rect(Rect2(-2.5, 0, 5, 6), col.darkened(0.12))
			"arc": draw_arc(Vector2.ZERO, 7.5, 0.4, 4.2, 12, col, 3.5)
			"ring":
				draw_arc(Vector2.ZERO, 8, 0, TAU, 16, col, 2.0)
				draw_arc(Vector2.ZERO, 5, 0, TAU, 12, col.lightened(0.5), 1.5)
			"dot":
				draw_circle(Vector2.ZERO, 6, col)
				draw_circle(Vector2.ZERO, 2.2, Color("b9442b"))
			"square":
				draw_rect(Rect2(-7, -5.5, 14, 11), col)
				draw_rect(Rect2(-7, -5.5, 14, 11), col.darkened(0.2), false, 1.0)
			"tri": draw_colored_polygon(PackedVector2Array([Vector2(0, -7), Vector2(8, 6), Vector2(-8, 6)]), col)
			"blob":
				draw_circle(Vector2(-2, 0), 5.5, col)
				draw_circle(Vector2(3, 1), 5, col)
			"strip":
				draw_colored_polygon(PackedVector2Array([Vector2(-12, -2), Vector2(0, -5), Vector2(12, -2), Vector2(12, 3), Vector2(0, 5), Vector2(-12, 3)]), col)
	draw_set_transform(_off(), 0, Vector2(_k(), _k()))

func _draw() -> void:
	var k := _k()
	draw_set_transform(_off(), 0, Vector2(k, k))
	var on_board := svc.view == "board"
	var C := ServiceScreen.BC
	var t = Art.tex("board.bg" if on_board else "bench.bg")
	if t != null: draw_texture_rect(t, Rect2(0, 0, S, S), false)
	elif on_board:
		draw_rect(Rect2(0, 0, S, S), Color("6b4a2b"))
		draw_circle(C, 150, Color("c69a62"))
	else:
		draw_rect(Rect2(0, 0, S, S), Color("8a8f8a"))
	var pz = svc.board[0] if (on_board and svc.board.size() > 0) else (svc.bench if not on_board else null)
	if pz == null:
		_text(C + Vector2(0, -4), "Board is empty" if on_board else "Tap an order to start a pizza", 15, Color(0.08, 0.12, 0.1, 0.8))
		return
	var shaping: bool = pz.stage == "shape"
	if pz.d.shape == "press":
		var pt = Art.tex("pan")
		if pt != null: draw_texture_rect(pt, Rect2(C - Vector2(pz.R + 12, pz.R + 12), Vector2(pz.R + 12, pz.R + 12) * 2), false)
		else:
			draw_circle(C, pz.R + 10, Color("2b2b2b"))
			draw_circle(C, pz.R + 3, Color("3d3d3d"))
	elif shaping:
		draw_arc(C, pz.R, 0, TAU, 64, Color(1, 1, 1, 0.85), 2.0)
		draw_arc(C, pz.R * 0.96, 0, TAU, 64, Color(1, 1, 1, 0.25), 1.0)
	# base: crust then crumb
	var crust: float = pz.d.crust
	draw_colored_polygon(_outline(pz, 1.0), Color("d9c08c"))
	draw_colored_polygon(_outline(pz, 1.0 - crust / pz.R * (0.5 if shaping else 1.0)), Color("f1dfb6"))
	# sauce and cheese are stored as covered cells
	if pz.sauce != "":
		var sc := Color(Data.ING[pz.sauce].col)
		for i in pz.sauce_cells: draw_circle(pz.cells[i], 9.5, sc)
	for i in pz.cheese_cells:
		var cl: Vector2 = pz.cells[i]
		for j in 3:
			var h := float((i * 73 + j * 191) % 628) / 100.0
			var o := Vector2.from_angle(h * 2.3) * float((i * 31 + j * 17) % 7)
			var dir := Vector2.from_angle(h) * 6.0
			draw_line(cl + o - dir, cl + o + dir, Color("fdeeb5") if j != 1 else Color("fff6d6"), 3.6)
	for tp in pz.tops: _topping(tp)
	if on_board:
		var b: float = pz.bake
		draw_colored_polygon(_outline(pz, 1.0), Color(0.63, 0.35, 0.08, 0.28 * min(b, 1.1)))
		if b > 1.12: draw_colored_polygon(_outline(pz, 1.0), Color(0.1, 0.05, 0.02, clamp((b - 1.12) / 0.5, 0, 0.85)))
		for ct in pz.cuts: draw_line(ct.a, ct.b, Color(1, 0.98, 0.92, 0.95), 2.5)
		if start != null and cur != null: draw_dashed_line(start, cur, Color(1, 1, 1, 0.7), 2.0, 6.0)
	elif shaping and pz.d.shape == "roll" and prev != null:
		var pin = Art.tex("pin")
		if pin != null: draw_texture_rect(pin, Rect2(prev - Vector2(75, 13), Vector2(150, 26)), false)
		else:
			draw_rect(Rect2(prev.x - 60, prev.y - 9, 120, 18), Color("b98a55"))
			draw_rect(Rect2(prev.x - 78, prev.y - 4, 156, 8), Color("8c6238"))

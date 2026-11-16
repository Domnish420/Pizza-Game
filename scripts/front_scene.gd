class_name FrontScene
extends Control
## Draws the front of house (640 x 320 game units) and turns taps into actions.
## Counter venues: customers walk up to the hatch, queue, order, wait, collect.
## Dine-in venues: guests wait at the door, are seated, order at the table, eat, pay; tables need clearing.
## All artwork is requested through Art.tex(key); the shapes drawn here are placeholders.

const W := 640.0
const H := 320.0
const BUBBLE := {"order": ["ORDER", Color("f4c64f")], "food": ["FOOD UP", Color("74c47a")], "seat": ["SEAT", Color("8fb7e8")], "bill": ["BILL", Color("f7eed9")], "clear": ["CLEAR", Color("d9a37a")]}
var svc: ServiceScreen
var font: Font

func _init(service: ServiceScreen) -> void:
	svc = service
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	font = ThemeDB.fallback_font
	clip_contents = true

func _k() -> float:
	return min(size.x / W, size.y / H)

func _off() -> Vector2:
	return (size - Vector2(W, H) * _k()) / 2.0

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		svc.tap_scene((e.position - _off()) / _k())

func _text(pos: Vector2, text: String, px: int, col: Color, centre: bool = true) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(font, pos - Vector2(w / 2.0 if centre else 0.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)

func _sprite(key: String, centre: Vector2, sz: Vector2) -> bool:
	var t = Art.tex(key)
	if t == null: return false
	draw_texture_rect(t, Rect2(centre - sz / 2.0, sz), false)
	return true

func _person(pos: Vector2, p: Dictionary, k: float = 1.0) -> void:
	if not _sprite("customer.%d" % p.look, pos - Vector2(0, 26 * k), Vector2(30, 52) * k):
		var col := Color.from_hsv(p.hue, 0.45, 0.8)
		draw_rect(Rect2(pos.x - 9 * k, pos.y - 30 * k, 18 * k, 30 * k), col)
		draw_circle(pos - Vector2(0, 38 * k), 9 * k, Color("e8c39e"))
	if p.n > 1: _text(pos + Vector2(16, -8), "x%d" % p.n, 12, Kit.INK, false)

func _bubble(pos: Vector2, kind: String, frac: float) -> void:
	var b = BUBBLE[kind]
	var bob := sin(Time.get_ticks_msec() / 180.0) * 2.0
	var c := pos + Vector2(0, -58 + bob)
	if not _sprite("bubble." + kind, c, Vector2(30, 30)):
		var w := font.get_string_size(b[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 12
		draw_rect(Rect2(c.x - w / 2, c.y - 9, w, 18), b[1])
		_text(c + Vector2(0, 4), b[0], 11, Kit.DARK)
	if frac >= 0:
		draw_rect(Rect2(c.x - 14, c.y + 11, 28, 3), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(c.x - 14, c.y + 11, 28 * clamp(frac, 0, 1), 3), Kit.BASIL if frac > 0.5 else (Kit.CHEESE if frac > 0.25 else Kit.TOMATO))

func _draw() -> void:
	var k := _k()
	draw_set_transform(_off(), 0, Vector2(k, k))
	var key: String = svc.c.v.key
	var L: Dictionary = svc.L
	# background
	if not _sprite("bg." + key, Vector2(W, H) / 2.0, Vector2(W, H)):
		if L.dine:
			draw_rect(Rect2(0, 0, W, H), Color("5b4a3a"))
			draw_rect(Rect2(0, 0, 44, H), Color("2f3d35"))
			draw_rect(Rect2(44, 30, 10, 80), Color("c9b28a"))
			_text(Vector2(22, 20), "PASS", 11, Kit.MUTED)
			draw_rect(Rect2(590, 304, 60, 16), Color("2a2019"))
			_text(Vector2(612, 316), "DOOR", 10, Kit.MUTED)
		else:
			draw_rect(Rect2(0, 0, W, 200), Color("3c4a55"))
			draw_rect(Rect2(0, 200, W, 120), Color("59615c"))
			draw_rect(Rect2(20, 70, 205, 170), Color("b5412f"))
			draw_rect(Rect2(150, 100, 75, 62), Color("1b2a1f"))
			draw_rect(Rect2(146, 162, 86, 8), Color("d8d2c4"))
			if key == "van":
				draw_circle(Vector2(60, 242), 20, Color("1c1c1c"))
				draw_circle(Vector2(180, 242), 20, Color("1c1c1c"))
			_text(Vector2(120, 92), svc.c.v.name.to_upper(), 11, Kit.INK)
			_text(Vector2(188, 136), "YOU", 12, Kit.MUTED)
	# ready pizzas on the pass
	var ready := svc.tickets.filter(func(tk): return tk.state == "pass").size()
	if ready > 0:
		var wp: Vector2 = L.win + Vector2(-22, -12) if not L.dine else Vector2(22, 60)
		draw_circle(wp, 12, Color("e9cf96"))
		draw_circle(wp, 9, Color("c8321f"))
		_text(wp + Vector2(0, 26), "%d ready" % ready, 11, Kit.INK)
	# tables
	for tb in svc.tables:
		var s: float = tb.k
		var sz := Vector2(44, 34) * s
		var state := "dirty" if tb.dirty else ("food" if tb.party != null and tb.party.state in ["eat", "bill"] else "clean")
		if not _sprite("table." + state, tb.pos, sz):
			draw_rect(Rect2(tb.pos - sz / 2, sz), Color("8a6a45") if state != "dirty" else Color("6a5a48"))
			if state == "food": draw_circle(tb.pos, 8 * s, Color("e9cf96"))
			if state == "dirty": draw_circle(tb.pos, 6 * s, Color("c9c2b0"))
			_text(tb.pos + Vector2(0, sz.y / 2 - 2), str(tb.i + 1), int(9 * s) + 2, Color(1, 1, 1, 0.5))
		var p = tb.party
		if p != null and p.pos.distance_to(tb.pos) < 6:
			for i in p.n:
				var a := Vector2([-1, 1, -1, 1][i] * (sz.x / 2 + 7 * s), [-1, 1, 1, -1][i] * 8 * s)
				if not _sprite("seated.%d" % ((p.look + i) % 6), tb.pos + a, Vector2(18, 18) * s):
					draw_circle(tb.pos + a, 7 * s, Color.from_hsv(fmod(p.hue + i * 0.17, 1.0), 0.45, 0.8))
	# people on their feet, back to front
	var walkers := svc.parties.filter(func(p): return p.type != "deliv" and not (p.table >= 0 and p.pos.distance_to(svc.tables[p.table].pos) < 6))
	walkers.sort_custom(func(a, b): return a.pos.y < b.pos.y)
	for p in walkers: _person(p.pos, p, 0.85 if L.dine else 1.0)
	# what needs doing
	for a in svc.actionables():
		var frac := -1.0
		if a.has("p"): frac = a.p.pat / max(1.0, a.p.max)
		_bubble(a.pos + (Vector2(0, 30) if a.has("tb") or (a.has("p") and a.p.table >= 0) else Vector2.ZERO), a.kind, frac)
	for f in svc.floats:
		_text(f.pos + Vector2(0, -50), f.text, 14, Color(f.col, clamp(f.t, 0, 1)))
	if svc.parties.is_empty() and svc.t < 6:
		_text(Vector2(W / 2 + 60, 40), "Customers are on their way. Tap anyone with a marker over their head.", 13, Kit.INK)

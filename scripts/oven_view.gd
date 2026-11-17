class_name OvenView
extends Control
## The oven (400 x 320 units): shows the deck, the fire and every pizza, and lets you work it with a finger.
##   drag a pizza from the shelf onto a spot on the deck      -> it goes in (a tap puts it in the first free spot)
##   drag a pizza by its middle to another spot, or out front -> move it, or take it out
##   drag a pizza by its edge                                  -> spin it, to turn a different side to the heat
## Art keys: "oven.<type>" (background), "oven.fire" (flame). Pizzas are drawn by PizzaDraw.

const W := 400.0
const H := 320.0
const MOUTH_Y := 250.0     # anything dragged below this line has left the oven

var svc: ServiceScreen
var font: Font
var drag = null            # {pz, o (deck item or null), mode "move"/"turn", pos, start, last_ang}

func _init(service: ServiceScreen) -> void:
	svc = service
	set_anchors_preset(Control.PRESET_FULL_RECT)
	font = ThemeDB.fallback_font
	clip_contents = true

func _k() -> float:
	return min(size.x / W, size.y / H)

func _off() -> Vector2:
	return (size - Vector2(W, H) * _k()) / 2.0

func _local(pos: Vector2) -> Vector2:
	return (pos - _off()) / _k()

func _pizza_r(pz: Pizza) -> float:
	return svc.oven.prad * pz.base.R / 106.0

# ---------- input ----------
func _gui_input(e: InputEvent) -> void:
	if not svc.busy.is_empty():
		if e is InputEventMouseButton or e is InputEventScreenTouch:
			if e.pressed: svc.is_free()
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		var p := _local(e.position)
		if e.pressed: _down(p)
		else: _up(p)
	elif e is InputEventMouseMotion and drag != null:
		_move(_local(e.position))

func _down(p: Vector2) -> void:
	var ov: Oven = svc.oven
	for i in ov.shelf.size():
		if p.distance_to(Oven.SHELF_POS[i]) < 40.0:
			drag = {"pz": ov.shelf[i], "o": null, "mode": "move", "pos": p, "start": p}
			return
	var best = null
	for o in ov.mine():
		if o.auto: continue
		var dd: float = p.distance_to(ov.pos[o.slot])
		if dd < _pizza_r(o.pz) * 1.3 and (best == null or dd < p.distance_to(ov.pos[best.slot])): best = o
	if best == null: return
	var centre: Vector2 = ov.pos[best.slot]
	if p.distance_to(centre) < _pizza_r(best.pz) * 0.5:
		drag = {"pz": best.pz, "o": best, "mode": "move", "pos": p, "start": p}
	elif not Equip.has("turner"):
		Kit.main.toast("You need a turning peel to turn pizzas in the oven. Order one from %s." % Equip.SHOP.name, true)
	else:
		drag = {"pz": best.pz, "o": best, "mode": "turn", "pos": p, "start": p, "last_ang": (p - centre).angle()}

func _move(p: Vector2) -> void:
	drag.pos = p
	if drag.mode == "turn":
		var ang: float = (p - svc.oven.pos[drag.o.slot]).angle()
		drag.pz.turn += angle_difference(drag.last_ang, ang)
		drag.last_ang = ang

func _nearest_free(p: Vector2, except: int = -1) -> int:
	var ov: Oven = svc.oven
	var best := -1
	for i in ov.slots:
		if i != except and ov.item_in(i) != null: continue
		if p.distance_to(ov.pos[i]) < ov.prad * 1.6 and (best < 0 or p.distance_to(ov.pos[i]) < p.distance_to(ov.pos[best])): best = i
	return best

func _up(p: Vector2) -> void:
	if drag == null: return
	var dg: Dictionary = drag
	drag = null
	if dg.mode != "move": return
	var ov: Oven = svc.oven
	var tapped: bool = p.distance_to(dg.start) < 8.0
	if dg.o == null:
		var slot: int = ov.free_slot() if tapped else _nearest_free(p)
		if slot >= 0: svc.oven_load(dg.pz, slot)
		elif tapped: Kit.main.toast("The oven is full", true)
	elif p.y > MOUTH_Y:
		svc.oven_pull(dg.o)
	else:
		var slot := _nearest_free(p, dg.o.slot)
		if slot >= 0: dg.o.slot = slot

# ---------- drawing ----------
func _text(pos: Vector2, text: String, px: int, col: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(font, pos - Vector2(w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)

func _draw() -> void:
	var k := _k()
	var off := _off()
	var ov: Oven = svc.oven
	draw_set_transform(off, 0, Vector2(k, k))
	var bg = Art.tex("oven." + ov.kind)
	if bg != null:
		draw_texture_rect(bg, Rect2(0, 0, W, H), false)
	else:
		draw_rect(Rect2(0, 0, W, H), Color("2a2623"))
		if ov.def.feeds or ov.kind == "rotary":
			draw_circle(Vector2(200, 129), 190, Color("7a4a36"))
			draw_rect(Rect2(20, 10, 360, 236), Color("3b2b24"))
			draw_rect(Rect2(28, 18, 344, 222), Color("57463a"))
		else:
			draw_rect(Rect2(20, 12, 360, 232), Color("9aa0a3"))
			draw_rect(Rect2(30, 22, 340, 212), Color("4a4743"))
			if ov.kind == "gas":
				for i in 9: draw_circle(Vector2(52 + i * 37, 26), 5 + sin(Time.get_ticks_msec() / 90.0 + i) * 1.5, Color("5aa8ff"))
		draw_rect(Rect2(110, 240, 180, 12), Color("1b1715"))
		draw_rect(Rect2(60, 256, 280, 58), Color("6f6a64"))
	# the fire
	if ov.def.fire > 0.0 and ov.kind != "gas":
		var lv: float = ov.level() if ov.def.feeds else 1.0
		var ft = Art.tex("oven.fire")
		if ft != null:
			draw_texture_rect(ft, Rect2(ov.fire_pos - Vector2(40, 60) * lv, Vector2(80, 120) * lv), false)
		else:
			draw_rect(Rect2(34, 60, 48, 150), Color("2a1a12"))
			for i in 7:
				var fl := sin(Time.get_ticks_msec() / 120.0 + i * 1.7)
				draw_circle(ov.fire_pos + Vector2(fl * 5.0, -50 + i * 16), (9.0 + fl * 2.5) * lv, Color("ff8a2a") if i % 2 == 0 else Color("ffc94a"))
	# deck spots
	for i in ov.slots:
		if ov.item_in(i) == null: draw_arc(ov.pos[i], ov.prad, 0, TAU, 40, Color(1, 1, 1, 0.14), 1.5)
	# pizzas
	for o in ov.items:
		var p: Vector2 = ov.pos[o.slot]
		if o.owner == "staff":
			draw_circle(p, ov.prad * 0.92, PizzaDraw.CRUST)
			draw_circle(p, ov.prad * 0.74, Color("c8321f"))
			draw_circle(p, ov.prad * 0.92, PizzaDraw.tint(o.p))
			draw_set_transform(off, 0, Vector2(k, k))
			_text(p + Vector2(0, 4), o.tk.owner, 11, Color(1, 1, 1, 0.9))
			continue
		if drag != null and drag.o == o and drag.mode == "move": continue
		PizzaDraw.draw(self, o.pz, off + p * k, k * ov.prad / 106.0)
		draw_set_transform(off, 0, Vector2(k, k))
		var st := "your fornaio has it" if o.auto else ov.status(o)
		var col := Kit.INK
		if st == "READY": col = Kit.BASIL
		elif st == "TURN": col = Kit.CHEESE
		elif st == "BURNING" or st == "OVERDONE": col = Kit.TOMATO
		_text(p + Vector2(0, _pizza_r(o.pz) + 13), st, 12, col)
	# the shelf out front
	_text(Vector2(200, 268), "SHELF" if ov.shelf.size() > 0 or drag != null else "Pizzas you send to the oven wait here", 11, Color(1, 1, 1, 0.55))
	for i in ov.shelf.size():
		if drag != null and drag.pz == ov.shelf[i] and drag.mode == "move": continue
		PizzaDraw.draw(self, ov.shelf[i], off + Oven.SHELF_POS[i] * k, k * 0.26)
		draw_set_transform(off, 0, Vector2(k, k))
	if drag != null and drag.mode == "move":
		PizzaDraw.draw(self, drag.pz, off + drag.pos * k, k * ov.prad / 106.0)
		draw_set_transform(off, 0, Vector2(k, k))
		if drag.o != null and drag.pos.y > MOUTH_Y: _text(Vector2(200, 304), "Let go to take it out", 12, Kit.CHEESE)

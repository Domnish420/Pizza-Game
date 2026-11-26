class_name OvenView
extends Control
## The oven (400 x 320 units): shows the deck, the fire and every pizza, and lets you work it with a finger.
##   drag a pizza from the shelf onto a spot on the deck      -> it goes in (a tap puts it in the first free spot)
##   drag a pizza by its middle to another spot, or out front -> move it, or take it out
##   touch a pizza's edge (the turning peel slides under it and lifts that side), then push forward or pull back
##     -> it turns: lifting the left side, pushing turns it to the right and pulling to the left (the lifted edge goes
##        where you push it and the pizza pivots); this is how a side that has had the fire is swapped for one that
##        has not, for leopard spots all round
##   hold a pizza's middle still a moment (the turning peel under all of it): it is held up to the dome ("doming") ->
##     the top and the cheese finish fast from the dome's heat and the base stops cooking; let go to set it back down
## Art keys: "oven.<type>" (background), "oven.fire" (flame). Pizzas are drawn by PizzaDraw.

const W := 400.0
const H := 320.0
const MOUTH_Y := 250.0     # anything dragged below this line has left the oven

var svc: ServiceScreen
var font: Font
var drag = null            # {pz, o (deck item or null), mode "move"/"lift"/"dome", pos, start, last, t0 (when, on clock),
                           #   edge (lift: the lifted edge's angle on the pizza)}
var clock := 0.0           # seconds, frame by frame
const DOME_HOLD := 0.6     # a pizza's middle held still this long (seconds): it goes up to the dome
var dome_told := false
var draw3d := false        # in the 3D kitchen this lies flat on the oven's deck and the world draws the pizzas, fire and
                           # oven in 3D (FPWorld): here we only draw the empty spots and take the touches
var shelf_pos: Array = Oven.SHELF_POS   # where pizzas wait on the landing (in 3D, further out on the landing shelf)

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
		if p.distance_to(shelf_pos[i]) < 40.0:
			drag = {"pz": ov.shelf[i], "o": null, "mode": "move", "pos": p, "start": p}
			return
	var best = null
	for o in ov.mine():
		if o.auto: continue
		var dd: float = p.distance_to(o.at)
		if dd < _pizza_r(o.pz) * 1.3 and (best == null or dd < p.distance_to(best.at)): best = o
	if best == null: return
	var centre: Vector2 = best.at
	if p.distance_to(centre) < _pizza_r(best.pz) * 0.5:
		drag = {"pz": best.pz, "o": best, "mode": "move", "pos": p, "start": p, "t0": clock}
	elif not Equip.has("turner"):
		Kit.main.toast("You need a turning peel to turn pizzas in the oven. Order one from %s." % Equip.SHOP.name, true)
	else:
		# the turning peel slides under this side and lifts it
		drag = {"pz": best.pz, "o": best, "mode": "lift", "pos": p, "start": p, "last": p, "edge": (p - centre).angle() - best.pz.turn}
		best.lifted = true
		Art.sfx("tap", true, 0.2)

func _move(p: Vector2) -> void:
	if drag.mode == "dome": return                   # (held up: it stays over its spot)
	drag.pos = p
	if drag.mode == "lift": lift_push(p - drag.last)
	drag.last = p

## each frame: a pizza's middle held still long enough goes up to the dome on the turning peel
func _process(dt: float) -> void:
	clock += dt
	if drag == null or drag.mode != "move" or drag.o == null: return
	if clock - float(drag.get("t0", clock)) < DOME_HOLD or (drag.pos as Vector2).distance_to(drag.start) > 6.0: return
	if not Equip.has("turner"):
		drag.t0 = INF
		Kit.main.toast("You need a turning peel to hold a pizza up to the dome. Order one from %s." % Equip.SHOP.name, true)
		return
	dome(drag)

## the turning peel under the whole pizza, held up to the dome: the top finishes, the base stops
func dome(dg: Dictionary) -> void:
	dg.mode = "dome"
	dg.o.domed = true
	Art.sfx("tap", true, 0.2)
	if not dome_told:
		dome_told = true
		Kit.main.toast("Up to the dome: the top and the cheese finish, the base stops. Let go to set it back down")
	queue_redraw()

## the peel under the lifted side pushed (forward, away from you) or pulled back by d: the lifted edge goes with it and
## the pizza pivots by how far you push across that edge (lifted on the left, pushing turns it to the right); it slides
## a little the way you push too
func lift_push(d: Vector2) -> void:
	var o: Dictionary = drag.o
	var pz: Pizza = drag.pz
	var r: Vector2 = Vector2.from_angle(drag.edge + pz.turn) * _pizza_r(pz)
	var dth: float = (r.x * d.y - r.y * d.x) / maxf(r.length_squared(), 1.0)
	pz.turn += clampf(dth, -0.5, 0.5)
	var ov: Oven = svc.oven
	var nat: Vector2 = o.at + d * 0.05
	if ov.free_place() and ov.spot_ok(nat, o): o.at = nat

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
	if dg.mode == "lift":
		dg.o.lifted = false                          # set back down on the deck
		return
	if dg.mode == "dome":
		dg.o.domed = false                           # down from the dome, where it was
		Art.sfx("peel", true, 0.3)
		return
	if dg.mode != "move": return
	var ov: Oven = svc.oven
	var tapped: bool = p.distance_to(dg.start) < 8.0
	if dg.o == null:
		var slot: int = ov.free_slot() if tapped else _nearest_free(p)
		if ov.free_place() and not tapped:
			# a wood oven: it goes where you put it, if there is room there
			if ov.free_slot() < 0: Kit.main.toast("The oven is full", true)
			elif ov.spot_ok(p): svc.oven_load(dg.pz, ov.free_slot(), p)
			elif p.distance_to(ov.fire_pos) < 52.0 + ov.prad: Kit.main.toast("Not on the fire!", true)
			elif slot >= 0: svc.oven_load(dg.pz, slot)
			else: Kit.main.toast("No room there", true)
		elif slot >= 0: svc.oven_load(dg.pz, slot)
		elif tapped: Kit.main.toast("The oven is full", true)
	elif p.y > MOUTH_Y:
		svc.oven_pull(dg.o)
	elif ov.free_place():
		if ov.spot_ok(p, dg.o): dg.o.at = p              # slide it nearer the fire or further away
	else:
		var slot := _nearest_free(p, dg.o.slot)
		if slot >= 0:
			dg.o.slot = slot
			dg.o.at = ov.pos[slot]

# ---------- drawing ----------
## the deck's heat as a faint glow: hotter is brighter and more orange (where a pizza will cook faster)
## the deck's heat as a faint haze over the floor, warmer where it is hotter: one texel per cell of the oven's heat grid,
## stretched smoothly over the deck (so it reads as a gradient, not tiles). Hotter than the deck around it shows more.
var heat_img: Image
var heat_tex: ImageTexture

func _heat_glow(ov: Oven) -> void:
	if ov.deck.is_empty(): return
	if heat_img == null:
		heat_img = Image.create(Oven.GW, Oven.GH, false, Image.FORMAT_RGBA8)
	for i in Oven.GW * Oven.GH:
		var tv: float = ov.deck[i]
		var k: float = clamp((tv - 330.0) / 200.0, 0.0, 1.0)
		var a: float = 0.0 if not ov.on_floor(ov.cell_at(i), 0.0) else 0.03 + 0.24 * k
		if tv < 280.0: a = 0.0
		heat_img.set_pixel(i % Oven.GW, i / Oven.GW, Color(1.0, 0.3 + 0.5 * k, 0.08 + 0.3 * k, a))
	if heat_tex == null: heat_tex = ImageTexture.create_from_image(heat_img)
	else: heat_tex.update(heat_img)
	# one texel per cell, so each texel's centre lands on its cell's centre; filtered smoothly in between
	draw_texture_rect(heat_tex, Rect2(Vector2.ZERO, Vector2(Oven.GW, Oven.GH) * Oven.GC), false)

func _text(pos: Vector2, text: String, px: int, col: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(font, pos - Vector2(w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)

func _draw() -> void:
	var k := _k()
	var off := _off()
	var ov: Oven = svc.oven
	draw_set_transform(off, 0, Vector2(k, k))
	if draw3d:
		if ov.free_place():
			_heat_glow(ov)
			if drag != null and drag.mode == "move":
				var ok: bool = ov.spot_ok(drag.pos, drag.o) or drag.pos.y > MOUTH_Y
				draw_arc(drag.pos, ov.prad * 1.5, 0, TAU, 48, Color(0.5, 1, 0.5, 0.6) if ok else Color(1, 0.3, 0.2, 0.75), 3.5)
		else:
			# the empty spots, faintly, so you can see where a pizza will go
			for i in ov.slots:
				if ov.item_in(i) == null: draw_arc(ov.pos[i], ov.prad, 0, TAU, 40, Color(1, 0.85, 0.6, 0.35), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var bg = Art.tex("oven." + ov.kind)
	if bg != null:
		draw_texture_rect(bg, Rect2(0, 0, W, H), false)
	else:
		draw_rect(Rect2(0, 0, W, H), Color("2a2623"))
		if ov.def.feeds or ov.kind == "rotary":
			# the dome's round floor (Oven.on_floor keeps pizzas on it), its wall drawn as a dark rim
			draw_circle(Vector2(200, 129), 190, Color("7a4a36"))
			var pts := PackedVector2Array()
			for i in 64:
				var a := TAU * i / 64.0
				var q := Oven.FLOOR_C + Vector2(cos(a) * Oven.FLOOR_R.x, sin(a) * Oven.FLOOR_R.y)
				pts.append(Vector2(q.x, min(q.y, 246.0)))
			draw_colored_polygon(pts, Color("57463a"))
			pts.append(pts[0])
			draw_polyline(pts, Color("3b2b24"), 8.0)
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
		var p: Vector2 = o.at
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
		var st := ("%s has it" % Story.BOSS if Story.stage() == "pizzaiolo" else "your fornaio has it") if o.auto else ov.status(o)
		var col := Kit.INK
		if st == "READY": col = Kit.BASIL
		elif st == "TURN": col = Kit.CHEESE
		elif st == "BURNING" or st == "OVERDONE": col = Kit.TOMATO
		_text(p + Vector2(0, _pizza_r(o.pz) + 13), st, 12, col)
	# the shelf out front
	_text(Vector2(200, 268), "SHELF" if ov.shelf.size() > 0 or drag != null else "Pizzas you send to the oven wait here", 11, Color(1, 1, 1, 0.55))
	for i in ov.shelf.size():
		if drag != null and drag.pz == ov.shelf[i] and drag.mode == "move": continue
		PizzaDraw.draw(self, ov.shelf[i], off + shelf_pos[i] * k, k * 0.26)
		draw_set_transform(off, 0, Vector2(k, k))
	if drag != null and drag.mode == "move":
		PizzaDraw.draw(self, drag.pz, off + drag.pos * k, k * ov.prad / 106.0)
		draw_set_transform(off, 0, Vector2(k, k))
		if drag.o != null and drag.pos.y > MOUTH_Y: _text(Vector2(200, 304), "Let go to take it out", 12, Kit.CHEESE)
	if drag != null and drag.mode == "dome" and not draw3d:
		draw_arc(drag.o.at, _pizza_r(drag.pz) * 1.12, 0.0, TAU, 40, Color(1.0, 0.85, 0.5, 0.7), 3.0)
		draw_line(drag.o.at, Vector2(drag.o.at.x, MOUTH_Y + 40.0), Color("8a6a48"), 5.0)
	if drag != null and drag.mode == "dome": _text(Vector2(200, 304), "Up to the dome: the top finishes, the base stops", 12, Kit.CHEESE)
	if drag != null and drag.mode == "lift" and not draw3d:
		# the turning peel under the lifted side, its handle back out of the mouth
		var e: Vector2 = drag.o.at + Vector2.from_angle(drag.edge + drag.pz.turn) * _pizza_r(drag.pz) * 0.85
		draw_line(e, Vector2(e.x, MOUTH_Y + 40.0), Color("8a6a48"), 5.0)
		draw_circle(e, 16.0, Color(0.75, 0.78, 0.8, 0.85))
		_text(Vector2(200, 304), "Push to turn it right, pull back to turn it left", 12, Kit.CHEESE)

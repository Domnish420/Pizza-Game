class_name PizzaDraw
## Draws a Pizza on any CanvasItem, in pizza-local units around `origin`, scaled by k and turned by pizza.turn.
## This is placeholder rendering built from simple shapes. To art it up, replace one layer at a time:
## base, sauce, cheese, toppings (Art key "top.<ingredient id>"), browning, cuts.

const CRUST := Color("d9c08c")
const CRUMB := Color("f1dfb6")

## the browning overlay for a doneness value: nothing, golden, brown, black
static func tint(p: float) -> Color:
	if p <= 0.0: return Color(0.72, 0.45, 0.12, 0.0)
	if p < 1.0: return Color(0.72, 0.45, 0.12, 0.32 * p)
	if p < 1.4: return Color(0.72, 0.45, 0.12, 0.32).lerp(Color(0.25, 0.12, 0.04, 0.72), (p - 1.0) / 0.4)
	return Color(0.25, 0.12, 0.04, 0.72).lerp(Color(0.05, 0.03, 0.02, 0.93), clamp((p - 1.4) / 0.4, 0.0, 1.0))

## a filled shape that is star-shaped about (0,0): one centre colour, one colour per rim point
static func _fan(ci: CanvasItem, ring: PackedVector2Array, centre: Color, rim: PackedColorArray) -> void:
	var pts := PackedVector2Array([Vector2.ZERO])
	var cols := PackedColorArray([centre])
	pts.append_array(ring)
	cols.append_array(rim)
	var idx := PackedInt32Array()
	var n := ring.size()
	for i in n:
		idx.append(0)
		idx.append(1 + i)
		idx.append(1 + (i + 1) % n)
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols)

## a ring between two outlines with the same number of points
static func _band(ci: CanvasItem, outer: PackedVector2Array, inner: PackedVector2Array, outer_cols: PackedColorArray, inner_cols: PackedColorArray) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	pts.append_array(outer)
	pts.append_array(inner)
	cols.append_array(outer_cols)
	cols.append_array(inner_cols)
	var n := outer.size()
	var idx := PackedInt32Array()
	for i in n:
		var j := (i + 1) % n
		idx.append_array([i, j, n + i, j, n + j, n + i])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols)

static func _flat(n: int, col: Color) -> PackedColorArray:
	var a := PackedColorArray()
	a.resize(n)
	a.fill(col)
	return a

## leopard spots on the crust: dark blisters where the flames hit each side (Pizza.spots), the same spots every frame
static func _spots(ci: CanvasItem, pz: Pizza) -> void:
	if pz.spots.size() != Pizza.NSEC: return
	var b := pz.base
	var rng := RandomNumberGenerator.new()
	for j in Pizza.NSEC:
		rng.seed = pz.id * 131 + j
		var n := int(clampf(pz.spots[j], 0.0, 2.5) * 5.0)
		for s in n:
			var a: float = (j + rng.randf()) * TAU / Pizza.NSEC
			var rad: float = b.rad_at(a)
			var w: float = maxf(b.rim_at(a), 5.0)
			var at := Vector2.from_angle(a) * (rad - w * rng.randf_range(0.15, 0.75))
			ci.draw_circle(at, rng.randf_range(1.6, 3.4) * (1.3 if pz.spots[j] > 2.0 else 1.0), Color(0.08, 0.05, 0.03, 0.85))

static func bake_at(pz: Pizza, ang: float) -> float:
	var f := fposmod(ang / TAU, 1.0) * Pizza.NSEC
	var i := int(f) % Pizza.NSEC
	var k: float = f - floor(f)
	return pz.bake[i] * (1.0 - k) + pz.bake[(i + 1) % Pizza.NSEC] * k

static func draw(ci: CanvasItem, pz: Pizza, origin: Vector2, k: float) -> void:
	var rot := pz.turn
	var b := pz.base
	var baked: bool = pz.stage == "oven" or pz.stage == "board"
	ci.draw_set_transform(origin, rot, Vector2(k, k))
	# base: crust, then the flattened middle
	var ring := b.outline(1.0, 0.0, 48)
	_fan(ci, ring, CRUST, _flat(ring.size(), CRUST))
	if b.mean_rim() < b.mean_r() - 3.0:
		var inner := b.outline(1.0, 1.0, 48)
		_fan(ci, inner, CRUMB, _flat(inner.size(), CRUMB))
	_thickness(ci, b)
	# sauce: thicker where more was laid
	if pz.sauce != "":
		var sc := Color(Data.ING[pz.sauce].col)
		for i in pz.sauce_amt:
			var a: float = pz.sauce_amt[i]
			if a < 0.12: continue
			ci.draw_circle(pz.cells[i], 9.5, Color(sc.darkened(0.18) if a > 1.5 else sc, clamp(0.35 + a * 0.65, 0.0, 1.0)))
	# cheese: shreds when raw, pools once it has melted
	if pz.cheese != "":
		var cc := Color(Data.ING[pz.cheese].col)
		var melted: bool = baked and pz.bake_avg() > 0.45
		for i in pz.cheese_amt:
			var a: float = pz.cheese_amt[i]
			if a < 0.12: continue
			var cl: Vector2 = pz.cells[i]
			if melted:
				ci.draw_circle(cl, 6.0 + min(a, 2.0) * 2.4, Color(cc.lightened(0.15), 0.92))
			else:
				for j in int(clamp(round(a * 3.0), 1, 6)):
					var h := float((i * 73 + j * 191) % 628) / 100.0
					var o := Vector2.from_angle(h * 2.3) * float((i * 31 + j * 17) % 7)
					var dir := Vector2.from_angle(h) * 6.0
					ci.draw_line(cl + o - dir, cl + o + dir, cc.lightened(0.25) if j % 2 == 0 else cc.lightened(0.45), 3.4)
	for tp in pz.tops:
		ci.draw_set_transform(origin + Vector2(tp.x, tp.y).rotated(rot) * k, rot + tp.a, Vector2(k, k))
		topping(ci, tp.t)
	ci.draw_set_transform(origin, rot, Vector2(k, k))
	# browning: the crust colours by how much heat each side has had; the middle only goes golden
	if baked:
		var inner := b.outline(1.0, 1.0 if b.mean_rim() > 4.0 else 0.0, 48)
		if b.mean_rim() <= 4.0:
			for i in inner.size(): inner[i] *= 0.88
		var crust_cols := PackedColorArray()
		var mid_cols := PackedColorArray()
		for i in ring.size():
			var c := tint(bake_at(pz, i * TAU / ring.size()))
			crust_cols.append(c)
			mid_cols.append(Color(c, c.a * 0.4))
		_fan(ci, inner, Color(tint(pz.bake_avg()), tint(pz.bake_avg()).a * 0.25), mid_cols)
		_band(ci, ring, inner, crust_cols, mid_cols)
		_spots(ci, pz)
	_holes(ci, b)
	for ct in pz.cuts:
		ci.draw_line(ct.a, ct.b, Color(1, 0.98, 0.92, 0.95), 2.5)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## thin patches darker (the bench shows through), thick ones paler, across the middle
static func _thickness(ci: CanvasItem, b: PizzaBase) -> void:
	for i in PizzaBase.NS:
		for j in PizzaBase.NR:
			var v: float = b.thk[i * PizzaBase.NR + j]
			var at := b.cell_pos(i, j)
			var rad: float = b.inner_at(at.angle()) / PizzaBase.NR * 0.9 + 2.0
			if v < 0.85: ci.draw_circle(at, rad, Color(0.45, 0.36, 0.28, clampf((0.85 - v) * 0.7, 0.0, 0.4)))
			elif v > 1.2: ci.draw_circle(at, rad, Color(1.0, 0.97, 0.9, clampf((v - 1.2) * 0.5, 0.0, 0.3)))

## holes torn through the base: ragged, dark through to what is underneath, thin pale dough round them
static func _holes(ci: CanvasItem, b: PizzaBase) -> void:
	var n := 0
	for h in b.holes():
		var pts := PackedVector2Array()
		var lip := PackedVector2Array()
		for i in 14:
			var a := i * TAU / 14.0
			var rr: float = h[1] * (0.75 + 0.5 * float((n * 37 + i * 53) % 11) / 10.0)
			pts.append(h[0] + Vector2.from_angle(a) * rr)
			lip.append(h[0] + Vector2.from_angle(a) * (rr + 3.0))
		ci.draw_colored_polygon(lip, Color(1.0, 0.96, 0.86, 0.9))
		ci.draw_colored_polygon(pts, Color(0.16, 0.12, 0.09, 0.9))
		n += 1

## one piece of a topping, centred on (0,0)
static func topping(ci: CanvasItem, id: String) -> void:
	var t = Art.tex("top." + id)
	if t != null:
		ci.draw_texture_rect(t, Rect2(-12, -12, 24, 24), false)
		return
	var it: Dictionary = Data.ING[id]
	var col := Color(it.col)
	match it.shape:
		"disc":
			ci.draw_circle(Vector2.ZERO, 9, col)
			ci.draw_circle(Vector2(-3, -2), 1.5, col.darkened(0.3))
			ci.draw_circle(Vector2(3, 3), 1.5, col.darkened(0.3))
		"leaf":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-10, 0), Vector2(-3, -5), Vector2(6, -4), Vector2(10, 0), Vector2(6, 4), Vector2(-3, 5)]), col)
			ci.draw_line(Vector2(-9, 0), Vector2(9, 0), col.darkened(0.3), 1.0)
		"cap":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-8, 0), Vector2(-6, -5), Vector2(0, -8), Vector2(6, -5), Vector2(8, 0)]), col)
			ci.draw_rect(Rect2(-2.5, 0, 5, 6), col.darkened(0.12))
		"arc": ci.draw_arc(Vector2.ZERO, 7.5, 0.4, 4.2, 12, col, 3.5)
		"ring":
			ci.draw_arc(Vector2.ZERO, 8, 0, TAU, 16, col, 2.0)
			ci.draw_arc(Vector2.ZERO, 5, 0, TAU, 12, col.lightened(0.5), 1.5)
		"dot":
			ci.draw_circle(Vector2.ZERO, 6, col)
			ci.draw_circle(Vector2.ZERO, 2.2, Color("b9442b"))
		"grain":
			ci.draw_circle(Vector2(-3, -1), 2.2, col)
			ci.draw_circle(Vector2(3, 0), 2.2, col)
			ci.draw_circle(Vector2(0, 3), 2.2, col)
		"square":
			ci.draw_rect(Rect2(-7, -5.5, 14, 11), col)
			ci.draw_rect(Rect2(-7, -5.5, 14, 11), col.darkened(0.2), false, 1.0)
		"tri": ci.draw_colored_polygon(PackedVector2Array([Vector2(0, -7), Vector2(8, 6), Vector2(-8, 6)]), col)
		"blob":
			ci.draw_circle(Vector2(-2, 0), 5.5, col)
			ci.draw_circle(Vector2(3, 1), 5, col)
		_:
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-12, -2), Vector2(0, -5), Vector2(12, -2), Vector2(12, 3), Vector2(0, 5), Vector2(-12, 3)]), col)

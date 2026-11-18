class_name Pizza3D
extends Node3D
## The pizza in 3D, built live from its data, so everything you do to it shows as you do it.
##
## - The dough is a mesh round the outline in PizzaBase (r and rim per sector): a ball starts as a dome, pressing
##   flattens the middle and leaves a puffy crust (cornicione) where the rim is still unpressed.
## - Sauce and cheese are painted onto that surface from the pizza's cell grid, with height where they are laid
##   thick, and the vertex alpha says how wet and glossy each spot is (shaders/pizza.gdshader).
## - Toppings are small meshes, one MultiMesh per shape, placed piece by piece where they were put.
## - In the oven the crust browns sector by sector from Pizza.bake, gets leopard-spot char when pushed, the cheese
##   melts and blisters; on the board the cuts show and it steams.
##
## Everything here is in pizza units (the bench's 320 x 320 grid); the node is scaled by `unit` (metres per unit)
## and turned by the pizza's own turn. It only rebuilds when the pizza changes.

const SECT := 48
const IN_RINGS := [0.0, 0.12, 0.24, 0.36, 0.48, 0.59, 0.69, 0.78, 0.86, 0.93, 1.0]   # across the flat middle
const CRUST := [0.18, 0.4, 0.6, 0.78, 0.92, 1.0]                          # across the rim, from its inside edge out

const DOUGH := Color("f0dfb6")
const DOUGH_RIM := Color("ebcd97")
const GOLDEN := Color("cf8f3f")
const GOLDEN_MID := Color("e2b766")
const DARK := Color("6e3b1a")
const CHAR := Color("2f1d12")

var pz: Pizza = null
var unit := 0.6 / 320.0
var steam_on := false
var _sig := ""
var _since := 1.0
var _mi: MeshInstance3D
var _mat: ShaderMaterial
var _tops: Node3D
var _shape_mesh := {}
var _top_mat: StandardMaterial3D
var _pan: Node3D
var _steam: CPUParticles3D
var _grid := {}                 # cell grid coordinates -> cell index
var _g0 := Vector2.ZERO
var _grid_for := -1
var _gn := Vector2i.ZERO          # the size of the cell grid
var _layer_img: Image
var _layer_tex: ImageTexture

func _ready() -> void:
	scale = Vector3.ONE * unit
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/pizza.gdshader")
	_mi = MeshInstance3D.new()
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mi)
	_tops = Node3D.new()
	add_child(_tops)
	_top_mat = StandardMaterial3D.new()
	_top_mat.vertex_color_use_as_albedo = true
	_top_mat.vertex_color_is_srgb = true
	_top_mat.roughness = 0.68
	_top_mat.metallic_specular = 0.3
	_steam = CPUParticles3D.new()
	_steam.emitting = false
	_steam.amount = 14
	_steam.lifetime = 1.8
	_steam.local_coords = true
	_steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_steam.emission_sphere_radius = 55.0
	_steam.direction = Vector3.UP
	_steam.spread = 12.0
	_steam.gravity = Vector3(0, 18.0, 0)
	_steam.initial_velocity_min = 8.0
	_steam.initial_velocity_max = 16.0
	# soft wisps that fade in and out as they rise
	var puff := QuadMesh.new()
	puff.size = Vector2(26, 26)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.billboard_keep_scale = true          # else the puffs lose the pizza's scale and fill the room
	sm.vertex_color_use_as_albedo = true
	sm.albedo_texture = _wisp()
	sm.no_depth_test = false
	puff.material = sm
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.0))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	fade.add_point(0.3, Color(1, 1, 1, 0.22))
	_steam.color_ramp = fade
	_steam.scale_amount_min = 0.7
	_steam.scale_amount_max = 1.5
	_steam.mesh = puff
	_steam.position.y = 12.0
	add_child(_steam)

## show this pizza (or nothing): call every frame; it rebuilds only when something about the pizza changed
func show_pizza(p) -> void:
	_since += get_process_delta_time()
	if p == null:
		if pz != null:
			pz = null
			_sig = ""
			visible = false
			_steam.emitting = false
		return
	visible = true
	if p != pz:
		pz = p
		_sig = ""
	rotation.y = -pz.turn
	_steam.emitting = steam_on and pz.stage == "board"
	var s := _signature()
	if s != _sig and (_since > 0.035 or _sig == ""):
		_sig = s
		_since = 0.0
		_build()

func _signature() -> String:
	var b := pz.base
	var s := 0.0
	for i in PizzaBase.NS: s += b.r[i] * 1.31 + b.rim[i] * 0.71
	var sa := 0.0
	for k in pz.sauce_amt: sa += pz.sauce_amt[k]
	var ca := 0.0
	for k in pz.cheese_amt: ca += pz.cheese_amt[k]
	var bk := 0.0
	for x in pz.bake: bk += x
	return "%d|%.1f|%.2f|%.1f|%.1f|%d|%d|%.2f|%s|%s%s" % [pz.id, s, b.rot, sa, ca, pz.tops.size(), pz.cuts.size(), bk, pz.stage, pz.sauce, pz.cheese]

## a soft round puff for the steam
func _wisp() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length() / 15.5
			img.set_pixel(x, y, Color(1, 1, 1, clamp(1.0 - d, 0.0, 1.0) ** 1.6))
	return ImageTexture.create_from_image(img)

# ---------- reading the pizza ----------
func _make_grid() -> void:
	_grid.clear()
	_grid_for = pz.id
	_layer_img = null
	if pz.cells.is_empty(): return
	_g0 = Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for c in pz.cells:
		_g0 = Vector2(min(_g0.x, c.x), min(_g0.y, c.y))
		hi = Vector2(max(hi.x, c.x), max(hi.y, c.y))
	_gn = Vector2i(roundi((hi.x - _g0.x) / Pizza.CELL) + 1, roundi((hi.y - _g0.y) / Pizza.CELL) + 1)
	for i in pz.cells.size():
		var c: Vector2 = pz.cells[i]
		_grid[Vector2i(roundi((c.x - _g0.x) / Pizza.CELL), roundi((c.y - _g0.y) / Pizza.CELL))] = i
	_layer_img = Image.create(_gn.x, _gn.y, false, Image.FORMAT_RGBA8)
	_layer_tex = ImageTexture.create_from_image(_layer_img)
	_mat.set_shader_parameter("layers", _layer_tex)

## the sauce and cheese grid as a tiny picture, one pixel a cell, for the shader to draw from
func _paint_layers() -> void:
	if _layer_img == null: return
	_layer_img.fill(Color(0, 0, 0, 1))
	for key in _grid:
		var ci: int = _grid[key]
		var s: float = float(pz.sauce_amt.get(ci, 0.0)) if pz.sauce != "" else 0.0
		var c: float = float(pz.cheese_amt.get(ci, 0.0)) if pz.cheese != "" else 0.0
		if s > 0.0 or c > 0.0: _layer_img.set_pixelv(key, Color(s / Pizza.MAX_AMT, c / Pizza.MAX_AMT, 0, 1))
	_layer_tex.update(_layer_img)

## where a point on the pizza falls on that picture
func _uv(p: Vector2) -> Vector2:
	if _gn.x == 0: return Vector2.ZERO
	return ((p - _g0) / Pizza.CELL + Vector2(0.5, 0.5)) / Vector2(_gn)

## how much of a layer (sauce_amt or cheese_amt) is at a point, smoothly between the cells
func _amt(layer: Dictionary, p: Vector2) -> float:
	if layer.is_empty() or _grid.is_empty(): return 0.0
	var f := (p - _g0) / Pizza.CELL
	var i0 := Vector2i(floori(f.x), floori(f.y))
	var k := f - Vector2(i0)
	var t := 0.0
	for dy in 2:
		for dx in 2:
			var w: float = (k.x if dx == 1 else 1.0 - k.x) * (k.y if dy == 1 else 1.0 - k.y)
			var ci = _grid.get(i0 + Vector2i(dx, dy), -1)
			if ci >= 0: t += float(layer.get(ci, 0.0)) * w
	return t

func _thick() -> float:
	return clamp(pz.base.thickness_mm() / max(pz.base.cm * 10.0, 0.01), 1.6, 6.0)

func _bake_at(ang: float) -> float:
	return PizzaDraw.bake_at(pz, ang)

## browning for a doneness value: raw, golden (done is golden, a little past it deeper), then brown and black
func _brown(c: Color, b: float, golden: Color) -> Color:
	if b <= 0.0: return c
	if b < 1.0: return c.lerp(golden, b * 0.9)
	var g := c.lerp(golden, 0.9)
	if b < 1.15: return g
	if b < 1.45: return g.lerp(DARK, (b - 1.15) / 0.3)
	return DARK.lerp(CHAR, clamp((b - 1.45) / 0.35, 0.0, 1.0))

# ---------- building ----------
func _build() -> void:
	if _grid_for != pz.id: _make_grid()
	var b := pz.base
	var baked: bool = pz.stage == "oven" or pz.stage == "board"
	var mid_b: float = pz.bake_avg() * 0.75 if baked else 0.0
	var melt: float = clamp((pz.bake_avg() - 0.3) / 0.4, 0.0, 1.0) if baked else 0.0
	var melted: bool = melt > 0.5
	_paint_layers()
	_mat.set_shader_parameter("sauce_col", Color(Data.ING[pz.sauce].col) if pz.sauce != "" else Color.WHITE)
	_mat.set_shader_parameter("cheese_col", Color(Data.ING[pz.cheese].col).lerp(Color("fff8e6"), 0.55) if pz.cheese != "" else Color.WHITE)
	_mat.set_shader_parameter("melt", melt)
	_mat.set_shader_parameter("mid_b", mid_b)
	_mat.set_shader_parameter("seed", float(pz.id % 97) * 0.37)
	_mat.set_shader_parameter("max_amt", Pizza.MAX_AMT)
	var h0 := _thick()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := IN_RINGS.size() + CRUST.size()
	for i in SECT:
		var a := i * TAU / SECT
		var rad: float = b.rad_at(a)
		var w: float = clamp(b.rim_at(a), 0.0, rad)
		var r_in: float = rad - w
		var puff: float = max(w * 0.5, 1.4)
		var peak_s: float = 0.42 * clamp(r_in / max(w * 0.5, 0.001), 0.0, 1.0)
		var h_pk: float = h0 + puff
		var h_in: float = h0 + puff * (1.0 - clamp(r_in / max(w * 0.5, 0.001), 0.0, 1.0))
		var dir := Vector2.from_angle(a)
		var crust_b: float = _bake_at(a) if baked else 0.0
		for j in rings:
			var p: Vector2
			var h: float
			var col: Color
			var inner := 1.0
			var cb := 0.0
			if j < IN_RINGS.size():
				p = dir * r_in * IN_RINGS[j]
				h = h_in
				col = _brown(DOUGH, mid_b, GOLDEN_MID)
				# a little height where sauce and cheese are laid thick (the colour is drawn by the shader)
				var sa := _amt(pz.sauce_amt, p) if pz.sauce != "" else 0.0
				var ca := _amt(pz.cheese_amt, p) if pz.cheese != "" else 0.0
				h += min(sa, 2.0) * 0.55 + min(ca, 2.0) * (0.75 if melted else 1.3)
			else:
				var s: float = CRUST[j - IN_RINGS.size()]
				p = dir * (r_in + w * s)
				if s <= peak_s and peak_s > 0.0: h = h_in + (h_pk - h_in) * sin(PI * 0.5 * s / peak_s)
				else: h = h_pk * pow(cos(PI * 0.5 * (s - peak_s) / max(1.0 - peak_s, 0.001)), 0.6)
				h = max(h, 0.0)
				var top: float = sin(PI * clamp(s, 0.0, 1.0))
				col = _brown(DOUGH_RIM, crust_b * (0.9 + 0.12 * top), GOLDEN)
				inner = 0.0
				cb = crust_b * (0.6 + 0.45 * top)
			st.set_color(col)
			st.set_uv(_uv(p))
			st.set_uv2(Vector2(inner, cb))
			st.add_vertex(Vector3(p.x, h, p.y))
	for i in SECT:
		var i2 := (i + 1) % SECT
		for j in rings - 1:
			var a0 := i * rings + j
			var a1 := i * rings + j + 1
			var b0 := i2 * rings + j
			var b1 := i2 * rings + j + 1
			st.add_index(a0); st.add_index(b1); st.add_index(b0)
			st.add_index(a0); st.add_index(a1); st.add_index(b1)
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, _mat)
	_mi.mesh = mesh
	_build_toppings(h0, baked, mid_b, melted)
	_build_pan()

## the surface height at a point on the pizza (for laying toppings and cuts on it)
func _height(p: Vector2, h0: float, melted: bool) -> float:
	var b := pz.base
	var a := p.angle()
	var rad: float = b.rad_at(a)
	var w: float = clamp(b.rim_at(a), 0.0, rad)
	var r_in: float = rad - w
	var h: float = h0 + max(w * 0.5, 1.4) * (1.0 - clamp(r_in / max(w * 0.5, 0.001), 0.0, 1.0))
	if p.length() > r_in: h = h0 + max(w * 0.5, 1.4)
	var sa := _amt(pz.sauce_amt, p) if pz.sauce != "" else 0.0
	var ca := _amt(pz.cheese_amt, p) if pz.cheese != "" else 0.0
	return h + min(sa, 2.0) * 0.55 + min(ca, 2.0) * (0.75 if melted else 1.3)

func _mesh_for(shape: String) -> Mesh:
	if _shape_mesh.has(shape): return _shape_mesh[shape]
	var m: Mesh
	match shape:
		"disc":
			var c := CylinderMesh.new()
			c.top_radius = 9.0; c.bottom_radius = 9.0; c.height = 1.8; c.radial_segments = 14; c.rings = 1
			m = c
		"leaf", "blob", "grain":
			var s := SphereMesh.new()
			s.radius = 1.0; s.height = 2.0; s.radial_segments = 10; s.rings = 6
			m = s
		"cap":
			var c := CylinderMesh.new()
			c.top_radius = 1.0; c.bottom_radius = 1.0; c.height = 1.0; c.radial_segments = 12; c.rings = 1
			m = c
		"arc", "ring", "dot":
			var t := TorusMesh.new()
			t.inner_radius = {"arc": 5.5, "ring": 6.0, "dot": 2.2}[shape]
			t.outer_radius = {"arc": 8.5, "ring": 8.2, "dot": 5.5}[shape]
			t.rings = 12; t.ring_segments = 6
			m = t
		"square":
			var bx := BoxMesh.new()
			bx.size = Vector3(13, 1.8, 10)
			m = bx
		"tri":
			var pr := PrismMesh.new()
			pr.size = Vector3(14, 12, 2.2)
			m = pr
		_:
			var bx := BoxMesh.new()
			bx.size = Vector3(20, 1.2, 6)
			m = bx
	m.surface_set_material(0, _top_mat)
	_shape_mesh[shape] = m
	return m

## each topping piece where it was put: a MultiMesh per shape
func _build_toppings(h0: float, baked: bool, mid_b: float, melted: bool) -> void:
	for c in _tops.get_children(): c.queue_free()
	var by_shape := {}
	for tp in pz.tops:
		var it: Dictionary = Data.ING[tp.t]
		var shape: String = it.get("shape", "strip")
		if not by_shape.has(shape): by_shape[shape] = []
		by_shape[shape].append(tp)
	for shape in by_shape:
		var list: Array = by_shape[shape]
		var pieces := []
		for tp in list:
			var p := Vector2(tp.x, tp.y)
			var y := _height(p, h0, melted)
			var col := Color(Data.ING[tp.t].col)
			if baked and not tp.get("after", false): col = col.darkened(0.22 * clamp(mid_b, 0.0, 1.2))
			var rot := Basis(Vector3.UP, -float(tp.a))
			match shape:
				"leaf": pieces.append([Transform3D(rot * Basis.from_scale(Vector3(10, 1.1, 5)), Vector3(p.x, y + 0.8, p.y)), col])
				"blob": pieces.append([Transform3D(rot * Basis.from_scale(Vector3(6, 3.2, 5.5)), Vector3(p.x, y + 1.6, p.y)), col])
				"cap": pieces.append([Transform3D(rot * Basis.from_scale(Vector3(8, 1.6, 6)), Vector3(p.x, y + 0.8, p.y)), col])
				"grain":
					for o in [Vector2(-3, -1), Vector2(3, 0), Vector2(0, 3)]:
						var q: Vector2 = p + o.rotated(float(tp.a))
						pieces.append([Transform3D(Basis.from_scale(Vector3(2.3, 1.6, 2.3)), Vector3(q.x, y + 1.0, q.y)), col])
				"tri": pieces.append([Transform3D(rot * Basis(Vector3.RIGHT, -PI / 2.0), Vector3(p.x, y + 1.1, p.y)), col])
				"disc":
					# pepperoni and friends cup a little in the oven
					var cup: float = 1.0 + (0.25 * clamp(mid_b, 0.0, 1.0) if baked else 0.0)
					pieces.append([Transform3D(rot * Basis.from_scale(Vector3(1, cup, 1)), Vector3(p.x, y + 0.9, p.y)), col])
				_: pieces.append([Transform3D(rot, Vector3(p.x, y + 0.9, p.y)), col])
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _mesh_for(shape)
		mm.instance_count = pieces.size()
		for i in pieces.size():
			mm.set_instance_transform(i, pieces[i][0])
			mm.set_instance_color(i, pieces[i][1])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_tops.add_child(mmi)
	# the cuts: thin grooves across the top
	if not pz.cuts.is_empty():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		var bx := BoxMesh.new()
		bx.size = Vector3(1, 1, 1)
		bx.material = _top_mat
		mm.mesh = bx
		mm.instance_count = pz.cuts.size()
		for i in pz.cuts.size():
			var ct: Dictionary = pz.cuts[i]
			var lim: float = pz.base.mean_r() * 0.97                 # a cut stops at the edge of the pizza
			var a: Vector2 = ct.a.limit_length(lim)
			var b: Vector2 = ct.b.limit_length(lim)
			var mid := (a + b) / 2.0
			var y := _height(mid, h0, melted) + 0.6
			var basis := Basis(Vector3.UP, -(b - a).angle()) * Basis.from_scale(Vector3((b - a).length(), 0.8, 1.4))
			mm.set_instance_transform(i, Transform3D(basis, Vector3(mid.x, y, mid.y)))
			mm.set_instance_color(i, Color("8a5a2e"))
		var cmi := MultiMeshInstance3D.new()
		cmi.multimesh = mm
		_tops.add_child(cmi)

## a pan pizza sits in its pan
func _build_pan() -> void:
	var want: bool = pz.base.method == "press"
	if not want:
		if _pan != null:
			_pan.queue_free()
			_pan = null
		return
	if _pan != null: return
	_pan = Node3D.new()
	add_child(_pan)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("3a3e41")
	steel.roughness = 0.5
	var R: float = pz.base.R
	var floor_m := CylinderMesh.new()
	floor_m.top_radius = R + 8.0; floor_m.bottom_radius = R + 8.0; floor_m.height = 1.0; floor_m.radial_segments = 40
	floor_m.material = steel
	var f := MeshInstance3D.new()
	f.mesh = floor_m
	f.position.y = -0.6
	_pan.add_child(f)
	var wall := TorusMesh.new()
	wall.inner_radius = R + 5.0; wall.outer_radius = R + 10.0; wall.rings = 40; wall.ring_segments = 6
	wall.material = steel
	var wl := MeshInstance3D.new()
	wl.mesh = wall
	wl.scale = Vector3(1, 2.4, 1)
	wl.position.y = 3.0
	_pan.add_child(wl)

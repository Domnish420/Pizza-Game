class_name FPWorld
extends Node3D
## Service in 3D, first person: you are standing at your station, seen from a chest-mounted wide camera (a GoPro on
## your chest). Everything you work with is in the room and you touch it where it is.
##
##   Ahead          the marble-topped pizza counter: the bench you stretch and top on, the rail of gastro pans behind
##                  it, the portion ladles, the ticket rail, and beyond it the serving hatch (van, kiosk) or the pass
##                  into the dining room (shop and up), with the customers, the queue, the tables and the riders.
##   Right          the cutting board, then the oven.
##   Left           the prep station: the prep tablet (tubs, refills, prep, deliveries) and the back door.
##
## Looking around: the station buttons turn your head; drag on anything that is not a surface to look freely
## (let go near a station and you settle on it); on a phone, turning the phone turns your head (gyroscope).
##
## Touch: the bench, board, oven and prep tablet are FPSurface quads running the 2D station controls, so stretching
## with two fingers, ladling, sliding pizzas into the oven and slicing work exactly as before. Pans, ladles, tickets,
## customers, tables and delivery crates are 3D objects you tap.
##
## Art: every prop asks Art.model("fp.<key>") first and builds a placeholder shape only if there is no model.
## Units are metres. You stand at the origin facing -Z with your eyes EYE high.

const EYE := 1.62
const LOOK := 0.11                     # degrees of head turn per pixel of drag
## each station: where you lean to (from where you stand), what you look at, and how wide the view is there
const STATION_LEAN := {"front": Vector3(0, 0, 0), "bench": Vector3(0, -0.08, -0.14), "board": Vector3(0.5, -0.14, -0.26), "oven": Vector3(0.42, -0.3, 0.2), "prep": Vector3(-0.72, -0.18, -0.4), "stores": Vector3(0, -0.05, 0.15)}
const STATION_AT := {"front": Vector3(0, 1.35, -3.0), "bench": Vector3(0, 0.92, -0.62), "board": Vector3(1.16, 0.94, -0.72), "oven": Vector3(1.04, 1.1, 0.2), "prep": Vector3(-1.6, 1.42, -0.42), "stores": Vector3(-0.1, 1.15, 1.3)}
const STATION_FOV := {"front": 74.0, "bench": 70.0, "board": 64.0, "oven": 62.0, "prep": 60.0, "stores": 76.0}
var STATIONS := {}                     # station -> Vector2(yaw, pitch), worked out from the lean and the target
## between services the prep station is about the counter (tubs, sink, mixer), not the service tablet on the wall
const CLOSED_AT := {"prep": Vector3(-1.38, 0.98, -0.5)}
const CLOSED_LEAN := {"prep": Vector3(-0.55, -0.1, -0.3)}
## which jobs' labels show at which station (the rest stay hidden so the view is not cluttered)
const JOBS_AT := {"front": ["open", "checklist", "clean_foh"], "bench": ["dough_trays", "boxes", "clean_foh"], "board": ["boxes", "dough_trays"], "oven": ["boxes", "dough_trays"],
	"prep": ["prep", "wash", "dough", "clean_boh"], "stores": ["stores", "temp_fridge", "temp_freezer", "dry", "traps", "crates", "clean_boh"]}
const SNAP := 18.0                     # let go of a free look within this many degrees of a station and you settle on it

var svc: ServiceScreen                 # the day's trading, or null between services
var kitchen = null                     # the KitchenScreen between services: it runs the jobs you tap
var view_closed := "front"             # where you are looking between services
var ctrls: Dictionary
var job_labels := {}                   # job -> Label3D saying how that job stands
var job_nodes := {}                    # job -> Node3D (things that change with the state)
var job_t := 0.0
var dine := false
var ground_y := -0.6                   # the street is lower than the van floor
var head: Node3D
var cam: Camera3D
var yaw := 0.0
var pitch := -9.0
var t_yaw := 0.0
var t_pitch := -9.0
var gyro := Vector2.ZERO
var lean := Vector3.ZERO
var t_lean := Vector3.ZERO
var t_fov := 74.0
var last_view := ""
var surfaces := {}                     # station -> FPSurface
var people := {}                       # party id -> {root, figs, lbl, seated}
var table_nodes := []                  # [{root, plates, dirt}]
var pan_nodes := []                    # [{fill, ring, label, i, depth}]
var pan_sig := ""
var ladle_root: Node3D
var ladle_sig := ""
var ticket_root: Node3D
var ticket_sig := ""
var ticket_bars := []                  # [{bar, tk}]
var crates: Node3D
var mouse_node: Node3D
var float_labels := []
var hands := []                        # [{node, rest, target}]
var held: MeshInstance3D               # what is in your right hand
var marker: Node3D                     # the training-day marker bobbing over the thing to touch
var marker_on = null
var ptr := {}                          # pointer index -> what it is doing
var touch_seen := false
var _mats := {}
var time := 0.0

func _init(service: ServiceScreen, controls: Dictionary, host = null) -> void:
	svc = service
	ctrls = controls
	kitchen = host

## the station you are at (the service's view during service)
func cur_view() -> String:
	return svc.view if svc != null else view_closed

func goto(v: String) -> void:
	if svc != null: svc.set_view(v)
	else: view_closed = v

func _ready() -> void:
	dine = bool(svc.L.dine) if svc != null else Game.calc_tables() > 0
	ground_y = 0.0 if dine else -0.42
	for st in STATION_AT:
		var at: Vector3 = CLOSED_AT.get(st, STATION_AT[st]) if svc == null else STATION_AT[st]
		var ln: Vector3 = CLOSED_LEAN.get(st, STATION_LEAN[st]) if svc == null else STATION_LEAN[st]
		var d: Vector3 = at - (Vector3(0, EYE, 0) + ln)
		STATIONS[st] = Vector2(rad_to_deg(atan2(-d.x, -d.z)), rad_to_deg(atan2(d.y, Vector2(d.x, d.z).length())))
	_environment()
	_room()
	_counter()
	_board_counter()
	_oven()
	_prep()
	if dine: _dining_room()
	else: _street()
	_back_of_house()
	_camera()
	ticket_root = Node3D.new()
	add_child(ticket_root)
	ladle_root = Node3D.new()
	add_child(ladle_root)
	_look_at(cur_view(), true)

# ---------- building blocks ----------
func _mat(col: Color, rough: float = 0.75, metal: float = 0.0, unshaded: bool = false) -> StandardMaterial3D:
	var key := "%s/%.2f/%.2f/%s" % [col.to_html(), rough, metal, unshaded]
	if _mats.has(key): return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	if col.a < 1.0: m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded: m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats[key] = m
	return m

func _box(size: Vector3, pos: Vector3, col: Color, parent: Node = null, rough: float = 0.75, metal: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.material_override = _mat(col, rough, metal)
	(parent if parent != null else self).add_child(mi)
	return mi

func _cyl(r: float, h: float, pos: Vector3, col: Color, parent: Node = null, metal: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 16
	mi.mesh = c
	mi.position = pos
	mi.material_override = _mat(col, 0.5, metal)
	(parent if parent != null else self).add_child(mi)
	return mi

func _label(text: String, pos: Vector3, px: int, col: Color, parent: Node = null, billboard: bool = false, pixel: float = 0.0012) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = px
	l.pixel_size = pixel
	l.modulate = col
	l.outline_size = 0
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.outline_size = 10
		l.no_depth_test = true
	(parent if parent != null else self).add_child(l)
	return l

## something you can tap: a box collider carrying what tapping it does
func _tappable(parent: Node3D, size: Vector3, offset: Vector3, act: Dictionary) -> StaticBody3D:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = size
	cs.shape = bx
	cs.position = offset
	sb.add_child(cs)
	sb.set_meta("act", act)
	parent.add_child(sb)
	return sb

## a prop from the art pass if there is one, else the placeholder built by `make`
func _prop(key: String, pos: Vector3, make: Callable, parent: Node = null) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	(parent if parent != null else self).add_child(root)
	var m := Art.model("fp." + key)
	if m != null: root.add_child(m)
	else: make.call(root)
	return root

# ---------- the room ----------
func _environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("9cc6e8") if not dine else Color("2a2622")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("fff4e6")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 0.9 if not dine else 0.35
	add_child(sun)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 2.1, -0.4)
	lamp.omni_range = 4.5
	lamp.light_energy = 1.3
	lamp.light_color = Color("ffe2b8")
	add_child(lamp)

func _room() -> void:
	_prop("room." + ("kitchen" if dine else "van"), Vector3.ZERO, _mk_room)

func _mk_room(r: Node3D) -> void:
	var wall := Color("e9e4da") if dine else Color("dfe5e8")
	_box(Vector3(3.3, 0.1, 2.7), Vector3(0, -0.05, -0.05), Color("5b5550"), r)              # floor
	_box(Vector3(3.3, 0.06, 2.7), Vector3(0, 2.25, -0.05), Color("f2f2f2"), r)              # ceiling
	_box(Vector3(0.06, 2.3, 2.7), Vector3(1.65, 1.1, -0.05), wall, r)                      # right wall
	_box(Vector3(0.06, 2.3, 2.7), Vector3(-1.65, 1.1, -0.05), wall, r)                     # left wall
	_box(Vector3(3.3, 2.3, 0.06), Vector3(0, 1.1, 1.3), wall, r)                           # back wall
	_box(Vector3(0.05, 2.0, 0.8), Vector3(-1.62, 1.0, 0.75), Color("8d6e4f"), r)           # back door
	if dine:
		_box(Vector3(3.3, 0.28, 0.06), Vector3(0, 2.11, -1.12), wall, r)                   # the pass is open above the counter
		return
	_box(Vector3(3.3, 1.05, 0.06), Vector3(0, 0.525, -1.12), wall, r)                      # the hatch: wall below,
	_box(Vector3(3.3, 0.4, 0.06), Vector3(0, 2.05, -1.12), wall, r)                        # above,
	_box(Vector3(0.85, 0.8, 0.06), Vector3(-1.225, 1.45, -1.12), wall, r)                  # and either side
	_box(Vector3(0.85, 0.8, 0.06), Vector3(1.225, 1.45, -1.12), wall, r)
	_box(Vector3(1.7, 0.04, 0.26), Vector3(0, 1.05, -1.26), Color("b8bec2"), r, 0.4, 0.6)   # the ledge outside

## the pizza counter: marble top, the bench, the rail of pans behind it, the ticket rail above
func _counter() -> void:
	_prop("counter", Vector3.ZERO, _mk_counter)
	# what used to be buttons: the pass you send pizzas out on, the bin, the dough sheeter
	var pass_n := _prop("pass", Vector3(1.47, 0.92, -1.0), _mk_pass)
	job_nodes.pass = pass_n
	_tappable(pass_n, Vector3(0.32, 0.16, 0.24), Vector3(0, 0.06, 0), {"kind": "pass"})
	job_labels.pass = _small_label("Pass", Vector3(0, 0.2, 0), pass_n)
	var bin_n := _prop("bin", Vector3(-0.62, 0.92, -0.78), _mk_bin)
	job_nodes.bin = bin_n
	_tappable(bin_n, Vector3(0.18, 0.2, 0.18), Vector3(0, 0.08, 0), {"kind": "bin"})
	job_labels.bin = _small_label("Bin", Vector3(0, 0.22, 0), bin_n)
	if float(Game.tier("roller").auto) > 0.0:
		var sh := _prop("sheeter", Vector3(-0.62, 0.92, -0.45), _mk_sheeter)
		_tappable(sh, Vector3(0.3, 0.3, 0.3), Vector3(0, 0.12, 0), {"kind": "sheeter"})
		job_labels.sheeter = _small_label("Sheeter", Vector3(0, 0.36, 0), sh)
	if svc == null: return
	var s := FPSurface.new()
	s.setup("bench", ctrls.bench, Vector2i(640, 640), Vector2(0.6, 0.6), true, true)
	s.position = Vector3(0, 0.922, -0.62)
	s.rotation_degrees.x = -90
	add_child(s)
	surfaces.bench = s

func _mk_counter(r: Node3D) -> void:
	_box(Vector3(1.6, 0.88, 0.64), Vector3(0, 0.44, -0.78), Color("aab1b5"), r, 0.35, 0.7)       # stainless body
	_box(Vector3(1.62, 0.04, 0.66), Vector3(0, 0.9, -0.78), Color("ece9e3"), r, 0.25)             # marble top
	_box(Vector3(1.6, 0.08, 0.26), Vector3(0, 0.95, -1.0), Color("9aa3a8"), r, 0.35, 0.7)         # the chilled rail
	var glass := _box(Vector3(1.6, 0.01, 0.2), Vector3(0, 1.12, -1.0), Color(0.85, 0.95, 1.0, 0.08), r, 0.05)
	glass.rotation_degrees.x = 25                                                                   # sneeze guard
	_box(Vector3(1.7, 0.02, 0.03), Vector3(0, 1.96, -1.06), Color("8d969b"), r, 0.3, 0.8)         # ticket rail

func _small_label(text: String, at: Vector3, parent: Node3D) -> Label3D:
	var l := _label(text, at, 34, Color.WHITE, parent, true, 0.0009)
	l.fixed_size = true
	l.no_depth_test = false
	return l

func _mk_logs(r: Node3D) -> void:
	for i in 5:
		var lg := _cyl(0.035, 0.24, Vector3(-0.04 + (i % 3) * 0.04, 0.04 + (i / 3) * 0.07, 0), Color("6b4a2b"), r)
		lg.rotation_degrees.z = 90

func _mk_pass(r: Node3D) -> void:
	_box(Vector3(0.3, 0.06, 0.22), Vector3(0, 0.03, 0), Color("c3c9cc"), r, 0.25, 0.85)          # the heated pass shelf
	_box(Vector3(0.27, 0.005, 0.19), Vector3(0, 0.063, 0), Color(1.0, 0.55, 0.3), r)            # glowing top

func _mk_bin(r: Node3D) -> void:
	_cyl(0.07, 0.14, Vector3(0, 0.07, 0), Color("4a4a4a"), r)
	_cyl(0.075, 0.015, Vector3(0, 0.145, 0), Color("333333"), r)

func _mk_sheeter(r: Node3D) -> void:
	_box(Vector3(0.28, 0.16, 0.26), Vector3(0, 0.08, 0), Color("d9dcdc"), r, 0.3, 0.5)
	var roller := _cyl(0.03, 0.26, Vector3(0, 0.2, 0), Color("c3c9cc"), r, 0.8)
	roller.rotation_degrees.z = 90

func _board_counter() -> void:
	_prop("counter.side", Vector3.ZERO, _mk_side)
	if svc == null: return
	var s := FPSurface.new()
	s.setup("board", ctrls.board, Vector2i(640, 640), Vector2(0.5, 0.5), true, true)
	s.position = Vector3(1.16, 0.945, -0.72)
	s.rotation_degrees = Vector3(-90, 0, 0)
	add_child(s)
	surfaces.board = s

func _mk_side(r: Node3D) -> void:
	_box(Vector3(0.82, 0.88, 0.64), Vector3(1.22, 0.44, -0.78), Color("aab1b5"), r, 0.35, 0.7)
	_box(Vector3(0.84, 0.04, 0.66), Vector3(1.22, 0.9, -0.78), Color("c9ccce"), r, 0.3, 0.6)
	_box(Vector3(0.56, 0.02, 0.5), Vector3(1.16, 0.93, -0.72), Color("7a5634"), r)                 # the wooden board

func _oven() -> void:
	var kind: String = Game.tier("oven").type
	_prop("oven." + kind, Vector3.ZERO, _mk_oven.bind(kind))
	if Game.tier("oven").type == "wood":       # the logs, stacked beside the mouth
		var logs := _prop("logs", Vector3(1.08, 0.62, 0.74), _mk_logs)
		_tappable(logs, Vector3(0.2, 0.3, 0.26), Vector3(0, 0.15, 0), {"kind": "log"})
		job_labels.logs = _small_label("Logs", Vector3(0, 0.38, 0), logs)
	if svc == null:                         # between services: the oven door, closed
		_box(Vector3(0.02, 0.5, 0.7), Vector3(1.04, 1.1, 0.2), Color("2b2b2b"), self, 0.5, 0.6)
		_tappable(self, Vector3(0.1, 0.8, 1.2), Vector3(1.1, 1.1, 0.2), {"kind": "job", "job": "oven"})
		return
	var s := FPSurface.new()
	s.setup("oven", ctrls.oven, Vector2i(800, 640), Vector2(0.78, 0.62), false)
	s.position = Vector3(1.04, 1.1, 0.2)
	s.rotation_degrees.y = -90
	add_child(s)
	surfaces.oven = s

func _mk_oven(r: Node3D, kind: String) -> void:
	var col := Color("4a4a4a") if kind == "electric" or kind == "gas" else Color("8a4b32")
	_box(Vector3(0.6, 0.6, 1.3), Vector3(1.35, 0.3, 0.2), Color("3a3a3a"), r)                 # stand
	_box(Vector3(0.6, 1.0, 1.3), Vector3(1.35, 1.1, 0.2), col, r, 0.8)                      # body
	if kind == "wood" or kind == "rotary": _cyl(0.16, 0.6, Vector3(1.4, 1.9, 0.2), Color("555555"), r)   # flue

func _prep() -> void:
	_prop("prep", Vector3.ZERO, _mk_prep)
	if svc != null:
		var s := FPSurface.new()
		s.setup("prep", ctrls.prep, Vector2i(820, 600), Vector2(0.86, 0.63), false)
		s.position = Vector3(-1.6, 1.42, -0.42)
		s.rotation_degrees.y = 90
		add_child(s)
		surfaces.prep = s
	crates = _prop("crates", Vector3(-1.2, 0.0, 0.75), _mk_crates)
	_tappable(crates, Vector3(0.6, 0.7, 0.5), Vector3(0, 0.35, 0), {"kind": "job", "job": "crates"})
	job_labels.crates = _label("Delivery", Vector3(0, 0.8, 0), 30, Color.WHITE, crates, true, 0.0009)
	job_labels.crates.fixed_size = true

func _mk_prep(r: Node3D) -> void:
	_box(Vector3(0.62, 0.88, 1.3), Vector3(-1.32, 0.44, -0.45), Color("aab1b5"), r, 0.35, 0.7)
	_box(Vector3(0.64, 0.04, 1.32), Vector3(-1.32, 0.9, -0.45), Color("c9ccce"), r, 0.3, 0.6)
	for i in 3: _cyl(0.09, 0.2, Vector3(-1.38, 1.02, -0.9 + i * 0.22), Color("f4f4f2"), r)        # tubs
	_box(Vector3(0.5, 0.18, 0.4), Vector3(-1.32, 0.84, 0.0), Color("b8bec2"), r, 0.2, 0.8)     # sink

func _mk_crates(r: Node3D) -> void:
	_box(Vector3(0.5, 0.3, 0.38), Vector3(0, 0.15, 0), Color("9c7a4e"), r)
	_box(Vector3(0.45, 0.28, 0.35), Vector3(0.05, 0.44, 0.02), Color("8a6a40"), r)

## the van or kiosk looks out over a street
func _street() -> void:
	_prop("street", Vector3.ZERO, _mk_street)

func _mk_street(r: Node3D) -> void:
	_box(Vector3(40, 0.1, 40), Vector3(0, ground_y - 0.05, -21.2), Color("6d6f70"), r)          # road
	_box(Vector3(40, 0.06, 4.5), Vector3(0, ground_y + 0.03, -3.4), Color("a29d95"), r)         # pavement
	var cols := [Color("b5654a"), Color("d8c39a"), Color("7a8aa0"), Color("c9a27a"), Color("8a9a7a")]
	for i in 7:
		var h: float = 5.0 + (i * 37 % 5)
		_box(Vector3(5.6, h, 3.0), Vector3(-17.0 + i * 5.7, ground_y + h / 2.0, -17.0), cols[i % cols.size()], r)
	_cyl(0.06, 3.2, Vector3(2.6, ground_y + 1.6, -2.6), Color("333333"), r)

## shops and restaurants look out over the dining room from the pass
func _dining_room() -> void:
	_prop("dining", Vector3.ZERO, _mk_dining)
	for i in 3:
		var l := OmniLight3D.new()
		l.position = Vector3(-1.5 + i * 2.0, 2.7, -4.0 - i * 3.0)
		l.omni_range = 6.0
		l.light_energy = 1.1
		l.light_color = Color("ffd9a8")
		add_child(l)
	for tb in (svc.tables if svc != null else _closed_tables()):
		var root := _prop("table", _to3d(tb.pos), _mk_table)
		var plates := Node3D.new()
		root.add_child(plates)
		for k in 2: _cyl(0.15, 0.02, Vector3(-0.17 + k * 0.34, 0.78, 0), Color("f6f2ea"), plates)
		var dirt := Node3D.new()
		root.add_child(dirt)
		_cyl(0.13, 0.02, Vector3(0.1, 0.78, 0.1), Color("c9c2b0"), dirt)
		_box(Vector3(0.08, 0.02, 0.05), Vector3(-0.15, 0.79, -0.1), Color("8a7a60"), dirt)
		_tappable(root, Vector3(1.0, 0.9, 1.0), Vector3(0, 0.45, 0), {"kind": "table", "i": tb.i})
		_label("Table %d" % (tb.i + 1), Vector3(0, 1.0, 0), 34, Color(1, 1, 1, 0.6), root, true, 0.003)
		table_nodes.append({"root": root, "plates": plates, "dirt": dirt, "tb": tb})

func _mk_dining(r: Node3D) -> void:
	_box(Vector3(14, 0.1, 13), Vector3(0, -0.05, -7.6), Color("8a6a4a"), r)                     # floor
	_box(Vector3(14, 3.0, 0.1), Vector3(0, 1.5, -14.1), Color("d8cbb4"), r)                      # far wall
	_box(Vector3(0.1, 3.0, 13), Vector3(-5.2, 1.5, -7.6), Color("cfc2ab"), r)
	_box(Vector3(0.1, 3.0, 13), Vector3(4.2, 1.5, -7.6), Color("cfc2ab"), r)
	_box(Vector3(14, 0.1, 13), Vector3(0, 3.0, -7.6), Color("efe9df"), r)

func _mk_table(r: Node3D) -> void:
	_box(Vector3(0.8, 0.05, 0.8), Vector3(0, 0.74, 0), Color("7a5a3a"), r)
	_cyl(0.05, 0.72, Vector3(0, 0.36, 0), Color("333333"), r)
	for k in 4:
		var a := Vector2(0.62, 0).rotated(k * PI / 2.0)
		_box(Vector3(0.38, 0.45, 0.38), Vector3(a.x, 0.225, a.y), Color("5a4030"), r)

## the tables of the dining room when no service is running (laid out the way service lays them out)
func _closed_tables() -> Array:
	var out := []
	var n := Game.calc_tables()
	if n <= 0: return out
	var cols := int(ceil(sqrt(n * 1.9)))
	var rows := int(ceil(float(n) / cols))
	var cw := 430.0 / cols
	var ch := 235.0 / rows
	for i in n: out.append({"i": i, "pos": Vector2(195 + cw * (i % cols + 0.5), 22 + ch * (i / cols + 0.5)), "party": null, "dirty": false})
	return out

# ---------- the back of house: everything you do between services is something in the room ----------
## A job you tap: a StaticBody3D with {"kind": "job", "job": <name>} and a label above it saying how it stands.
## Between services the KitchenScreen runs the job (KitchenScreen.job); during service most of them wait.
func _job(job: String, node: Node3D, size: Vector3, offset: Vector3, label_at: Vector3) -> void:
	_tappable(node, size, offset, {"kind": "job", "job": job})
	var l := _label("", label_at, 40, Color.WHITE, node, true, 0.001)
	l.fixed_size = true                     # the same size on screen near or far
	l.no_depth_test = false
	job_labels[job] = l
	job_nodes[job] = node

func _back_of_house() -> void:
	# the fridge, with its thermometer, against the back wall
	var fr := _prop("fridge", Vector3(-0.62, 0, 0.97), _mk_fridge)
	_job("stores", fr, Vector3(0.7, 1.9, 0.7), Vector3(0, 0.95, 0), Vector3(0, 1.7, -0.36))
	var th := _prop("thermometer", Vector3(-0.45, 1.45, 0.62), _mk_thermo)
	_job("temp_fridge", th, Vector3(0.14, 0.14, 0.08), Vector3.ZERO, Vector3(0, 0.16, -0.05))
	if Stock.store_cap("freezer") > 0:
		var fz := _prop("freezer", Vector3(1.3, 0, 1.08), _mk_freezer)
		_job("temp_freezer", fz, Vector3(0.7, 0.9, 0.6), Vector3(0, 0.45, 0), Vector3(0, 1.05, 0))
	# the dry store shelves
	var dry := _prop("drystore", Vector3(0.42, 0, 1.08), _mk_dry)
	_job("dry", dry, Vector3(0.95, 1.9, 0.42), Vector3(0, 0.95, 0), Vector3(0, 1.75, -0.2))
	# cleaning: the kitchen mop and bucket by the back door; the spray for the front by the hatch
	var mop := _prop("mop", Vector3(-1.28, 0, 0.25), _mk_mop)
	_job("clean_boh", mop, Vector3(0.4, 1.3, 0.4), Vector3(0, 0.6, 0), Vector3(0, 1.35, 0))
	var spray := _prop("spray", Vector3(0.62, 0.92, -0.52), _mk_spray)
	_job("clean_foh", spray, Vector3(0.14, 0.26, 0.14), Vector3(0, 0.12, 0), Vector3(0, 0.36, 0))
	# pest control: the box of traps by the back door
	var trap := _prop("trapbox", Vector3(-1.3, 0, 1.12), _mk_trapbox)
	_job("traps", trap, Vector3(0.35, 0.3, 0.3), Vector3(0, 0.12, 0), Vector3(0, 0.45, 0))
	# pizza boxes on the shelf above the side counter: flat ones, and the folded stack
	var bx := _prop("boxes", Vector3(1.32, 1.8, -1.0), _mk_boxshelf)
	_job("boxes", bx, Vector3(0.62, 0.4, 0.4), Vector3(0, 0.15, 0), Vector3(0, 0.55, 0))
	# the sink, with the dirty tubs in it
	var sink := Node3D.new()
	sink.position = Vector3(-1.32, 0.93, 0.0)
	add_child(sink)
	_job("wash", sink, Vector3(0.55, 0.3, 0.45), Vector3.ZERO, Vector3(0, 0.4, 0))
	# the prep tubs and what is left to prep
	var tubs := Node3D.new()
	tubs.position = Vector3(-1.38, 0.92, -0.68)
	add_child(tubs)
	_job("prep", tubs, Vector3(0.3, 0.3, 0.7), Vector3(0, 0.12, 0), Vector3(0, 0.42, 0))
	# the dough: the mixer (or bowl) and the proving trays
	var mx := _prop("mixer" if int(Game.s.upg.mixer) > 0 else "bowl", Vector3(-1.38, 0.92, -1.0), _mk_mixer.bind(int(Game.s.upg.mixer) > 0))
	_job("dough", mx, Vector3(0.36, 0.55, 0.36), Vector3(0, 0.25, 0), Vector3(0, 0.66, 0))
	var trays := _prop("dough_trays", Vector3(1.45, 0.92, -0.42), _mk_trays)
	_job("dough_trays", trays, Vector3(0.36, 0.4, 0.5), Vector3(0, 0.15, 0), Vector3(0, 0.5, 0))
	# the opening checklist on its clipboard, and the sign at the hatch
	var cb := _prop("clipboard", Vector3(-0.98, 1.55, -1.08), _mk_clipboard)
	_job("checklist", cb, Vector3(0.26, 0.34, 0.06), Vector3.ZERO, Vector3(0, 0.27, 0.05))
	var sign := _prop("sign", Vector3(0.58, 1.66, -1.06), _mk_sign)
	_job("open", sign, Vector3(0.4, 0.24, 0.06), Vector3.ZERO, Vector3(0, 0.0, 0.04))
	job_labels.open.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	job_labels.open.fixed_size = false
	job_labels.open.font_size = 44
	job_labels.open.pixel_size = 0.0016
	job_labels.open.outline_size = 0

func _mk_fridge(r: Node3D) -> void:
	_box(Vector3(0.66, 1.86, 0.66), Vector3(0, 0.93, 0), Color("eef1f2"), r, 0.3, 0.2)
	_box(Vector3(0.6, 1.76, 0.02), Vector3(0, 0.95, -0.34), Color("f7f8f8"), r, 0.25, 0.1)
	_box(Vector3(0.03, 0.5, 0.04), Vector3(0.24, 1.1, -0.37), Color("9aa3a8"), r, 0.3, 0.8)

func _mk_freezer(r: Node3D) -> void:
	_box(Vector3(0.6, 0.86, 0.45), Vector3(0, 0.43, 0), Color("e3eef5"), r, 0.3, 0.2)
	_box(Vector3(0.6, 0.04, 0.45), Vector3(0, 0.88, 0), Color("cfdde6"), r)

func _mk_thermo(r: Node3D) -> void:
	var dial := _cyl(0.05, 0.02, Vector3.ZERO, Color("f2f2f2"), r)
	dial.rotation_degrees.x = 90

func _mk_dry(r: Node3D) -> void:
	var steel := Color("b8bec2")
	for y in [0.1, 0.6, 1.1, 1.6]: _box(Vector3(0.9, 0.03, 0.4), Vector3(0, y, 0), steel, r, 0.3, 0.7)
	for x in [-0.44, 0.44]: _box(Vector3(0.03, 1.8, 0.4), Vector3(x, 0.9, 0), steel, r, 0.3, 0.7)
	for i in 3: _box(Vector3(0.24, 0.32, 0.22), Vector3(-0.28 + i * 0.28, 0.28, 0), Color("e8dcc0"), r)      # flour sacks
	for i in 5: _cyl(0.05, 0.12, Vector3(-0.32 + i * 0.16, 0.68, 0), Color("c9452f"), r)                   # tins
	for i in 4: _box(Vector3(0.14, 0.2, 0.12), Vector3(-0.3 + i * 0.2, 1.21, 0), Color("6b8f3a"), r)        # jars and packets

func _mk_mop(r: Node3D) -> void:
	_cyl(0.17, 0.28, Vector3(0, 0.14, 0), Color("e8c23a"), r)
	var stick := _cyl(0.015, 1.2, Vector3(0.05, 0.75, 0), Color("8a6a40"), r)
	stick.rotation_degrees.z = -8

func _mk_spray(r: Node3D) -> void:
	_cyl(0.035, 0.16, Vector3(0, 0.08, 0), Color("4a9ad9"), r)
	_box(Vector3(0.05, 0.05, 0.04), Vector3(0.01, 0.18, 0), Color("ffffff"), r)

func _mk_trapbox(r: Node3D) -> void:
	_box(Vector3(0.3, 0.16, 0.24), Vector3(0, 0.08, 0), Color("2e2e2e"), r)

func _mk_boxshelf(r: Node3D) -> void:
	_box(Vector3(0.62, 0.02, 0.4), Vector3(0, 0, 0), Color("b8bec2"), r, 0.3, 0.7)
	var flat := _box(Vector3(0.3, 0.12, 0.34), Vector3(-0.15, 0.07, 0), Color("c9a36a"), r)
	job_nodes.boxes_flat = flat
	var folded := _box(Vector3(0.26, 0.2, 0.3), Vector3(0.17, 0.11, 0), Color("b8915a"), r)
	job_nodes.boxes_folded = folded

func _mk_mixer(r: Node3D, mixer: bool) -> void:
	if mixer:
		_box(Vector3(0.3, 0.08, 0.34), Vector3(0, 0.04, 0), Color("d9dcdc"), r, 0.3, 0.5)
		_box(Vector3(0.1, 0.45, 0.12), Vector3(0, 0.27, 0.11), Color("d9dcdc"), r, 0.3, 0.5)
		_box(Vector3(0.26, 0.1, 0.32), Vector3(0, 0.5, 0.0), Color("d9dcdc"), r, 0.3, 0.5)
		_cyl(0.12, 0.18, Vector3(0, 0.17, -0.03), Color("c3c9cc"), r, 0.8)
	else:
		_cyl(0.16, 0.12, Vector3(0, 0.06, 0), Color("c3c9cc"), r, 0.8)

func _mk_trays(r: Node3D) -> void:
	for i in 3:
		_box(Vector3(0.34, 0.07, 0.48), Vector3(0, 0.04 + i * 0.08, 0), Color(0.9, 0.92, 0.95, 0.9), r, 0.4)

func _mk_clipboard(r: Node3D) -> void:
	_box(Vector3(0.24, 0.32, 0.015), Vector3.ZERO, Color("8a6a40"), r)
	_box(Vector3(0.21, 0.27, 0.005), Vector3(0, -0.01, 0.01), Color("fbf8ef"), r)

func _mk_sign(r: Node3D) -> void:
	_box(Vector3(0.4, 0.22, 0.02), Vector3.ZERO, Color("1b2a1f"), r)

## green when it is done, amber when it is getting there, red when it needs you
func _ok_col(ok: bool, warn: bool = false) -> Color:
	return Kit.BASIL if ok else (Kit.CHEESE if warn else Kit.TOMATO)

## the labels over the jobs, and the props that show how things stand
func _sync_jobs() -> void:
	var G := Game
	var morning: bool = G.s.phase == "morning"
	var L := job_labels
	if L.has("temp_fridge"):
		var logged := Checks.logged("fridge")
		L.temp_fridge.text = "%.1f °C%s" % [Checks.temp_of("fridge"), "" if logged or svc != null else "\ntap to log it"]
		L.temp_fridge.modulate = _ok_col(logged or svc != null)
	if L.has("temp_freezer"):
		var lz := Checks.logged("freezer")
		L.temp_freezer.text = "Freezer %.0f °C%s" % [Checks.temp_of("freezer"), "" if lz or svc != null else " · log it"]
		L.temp_freezer.modulate = _ok_col(lz or svc != null)
	L.stores.text = "Fridge %d%% full" % (Stock.fill("fridge") * 100.0)
	L.dry.text = "Dry store %d%% full" % (Stock.fill("dry") * 100.0)
	L.clean_boh.text = "Kitchen %d%% clean" % Hygiene.level("boh")
	L.clean_boh.modulate = _ok_col(Hygiene.level("boh") >= 80.0, Hygiene.level("boh") >= 55.0)
	L.clean_foh.text = "%s %d%%" % ["Front" if dine else "Hatch", Hygiene.level("foh")]
	L.clean_foh.modulate = _ok_col(Hygiene.level("foh") >= 80.0, Hygiene.level("foh") >= 55.0)
	L.traps.text = "Traps %d/%d%s" % [Hygiene.laid(), Hygiene.traps_wanted(), (" · %d sprung" % Hygiene.sprung()) if Hygiene.sprung() > 0 else ""]
	L.traps.modulate = _ok_col(Hygiene.laid() >= Hygiene.traps_wanted() and Hygiene.sprung() == 0, true)
	L.boxes.text = "%d folded · %d flat" % [Stock.folded(), int(Stock.have("box"))]
	L.boxes.modulate = _ok_col(Stock.folded() >= min(Stock.boxes_needed(), Stock.fold_cap()), Stock.have("box") >= 1)
	if job_nodes.has("boxes_folded"): job_nodes.boxes_folded.scale.y = clamp(Stock.folded() / 20.0, 0.05, 1.5)
	if job_nodes.has("boxes_flat"): job_nodes.boxes_flat.scale.y = clamp(Stock.have("box") / 25.0, 0.05, 1.5)
	var dirty := Stock.dirty_tubs()
	L.wash.text = ("%d dirty tubs" % dirty) if dirty > 0 else "Sink"
	L.wash.modulate = _ok_col(dirty == 0, dirty < 6)
	var mins := 0.0
	for row in Day.prep_list(): mins += row.minutes
	L.prep.text = ("Prep: %d min to do" % ceil(mins)) if mins > 0.5 else "Prep done"
	L.prep.modulate = _ok_col(mins <= 0.5, true)
	var plan := G.dough_plan()
	var need := 0
	for st in plan: need += int(plan[st])
	var ready := 0
	for st in G.menu_doughs(G.menu_now()): ready += Stock.dough_ready(st)
	L.dough.text = ("Make dough: %d balls for tomorrow" % need) if need > 0 else "Dough"
	L.dough.modulate = _ok_col(need <= 0, not morning)
	L.dough_trays.text = "%d balls ready · %d proving" % [ready, max(0, Stock.dough_count() - ready)]
	L.crates.text = "%d deliver%s to put away" % [G.s.dock.size(), "y" if G.s.dock.size() == 1 else "ies"]
	crates.visible = G.s.dock.size() > 0
	var items := Checks.items("open" if morning else "close")
	var done := items.filter(func(x): return x.done).size()
	L.checklist.text = "%s checklist %d/%d" % ["Opening" if morning else "Closing", done, items.size()]
	L.checklist.modulate = _ok_col(done == items.size(), true)
	if svc != null: L.open.text = "OPEN"
	elif G.s.hygiene.get("closed_day", -1) == G.s.day: L.open.text = "CLOSED\ntoday"
	elif morning: L.open.text = "OPEN AT\n%s" % Data.hhmm(max(Day.now(), Day.open_time()))
	else: L.open.text = "LOCK UP"
	L.open.modulate = Color("f4c64f") if svc == null else Kit.BASIL
	if L.has("logs"): L.logs.text = "Logs (%d) · tap to feed the fire" % int(Stock.have("wood")) if svc != null else "Logs (%d)" % int(Stock.have("wood"))
	if L.has("pass"):
		var on_pass: int = svc.tickets.filter(func(tk): return tk.state == "pass").size() if svc != null else 0
		L.pass.text = ("Pass · tap to send it out" if svc != null and svc.board.size() > 0 else "Pass") + ((" · %d ready" % on_pass) if on_pass > 0 else "")
		L.pass.modulate = Kit.CHEESE if svc != null and svc.board.size() > 0 else Color.WHITE
	var here: Array = JOBS_AT.get(cur_view(), [])
	for j in L:
		if j in ["open", "pass", "bin", "sheeter", "logs"]:
			L[j].visible = svc != null or j == "open"
			continue
		if svc != null: L[j].visible = j == "crates" and G.s.dock.size() > 0       # during service only a delivery needs you
		else: L[j].visible = here.has(j) and (j != "crates" or G.s.dock.size() > 0)

func _camera() -> void:
	head = Node3D.new()
	head.position = Vector3(0, EYE, 0)
	add_child(head)
	cam = Camera3D.new()
	cam.fov = 74.0
	cam.near = 0.03
	cam.far = 80.0
	cam.current = true
	head.add_child(cam)
	# your forearms and hands, low in the frame like a chest camera sees them
	for side in [1, -1]:
		var h := _prop("hand." + ("right" if side == 1 else "left"), Vector3.ZERO, _mk_hand, cam)
		var rest := Vector3(0.22 * side, -0.27, -0.46)
		h.position = rest
		hands.append({"node": h, "rest": rest, "target": null})
	# what you are holding: a handful of the topping, or the ladle
	held = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.035
	sm.height = 0.05
	held.mesh = sm
	held.position = Vector3(0, 0.03, -0.06)
	held.visible = false
	hands[0].node.add_child(held)

func _mk_hand(r: Node3D) -> void:
	var arm := _cyl(0.04, 0.38, Vector3(0, 0, 0.19), Color("d9a77f"), r)
	arm.rotation_degrees.x = 90
	_box(Vector3(0.09, 0.03, 0.11), Vector3(0, 0, -0.03), Color("e2b58f"), r)

# ---------- where things are ----------
## a point in the 2D front-of-house layout (640 x 320) in the 3D world
func _to3d(p2: Vector2) -> Vector3:
	if dine: return Vector3((p2.y - 160.0) * 0.024, 0.0, -1.25 - max(0.35, (p2.x - 40.0) * 0.022))
	return Vector3((p2.y - 228.0) * 0.016, ground_y, -1.12 - max(0.45, (p2.x - 262.0) * 0.025))

func _look_at(v: String, snap: bool = false) -> void:
	var st: Vector2 = STATIONS.get(v, STATIONS.front)
	t_yaw = st.x
	t_pitch = st.y
	t_lean = (CLOSED_LEAN.get(v, STATION_LEAN.get(v, Vector3.ZERO)) if svc == null else STATION_LEAN.get(v, Vector3.ZERO))
	t_fov = STATION_FOV.get(v, 74.0)
	gyro = Vector2.ZERO
	if snap:
		yaw = t_yaw
		pitch = t_pitch
		lean = t_lean
	last_view = v

# ---------- every frame ----------
func _process(dt: float) -> void:
	time += dt
	if cur_view() != last_view: _look_at(cur_view())
	var g := Input.get_gyroscope()
	if g.length() > 0.02 and Game.s.get("gyro", true):
		gyro.x += rad_to_deg(g.x) * dt
		gyro.y = clamp(gyro.y + rad_to_deg(g.y) * dt * (-1.0 if DisplayServer.screen_get_orientation() == DisplayServer.SCREEN_REVERSE_LANDSCAPE else 1.0), -60.0, 60.0)
	var k := 1.0 - exp(-dt * 9.0)
	yaw = lerp_angle(deg_to_rad(yaw), deg_to_rad(t_yaw + gyro.x), k) * 180.0 / PI
	pitch = lerp(pitch, clamp(t_pitch + gyro.y, -85.0, 40.0), k)
	lean = lean.lerp(t_lean, k)
	head.position = Vector3(0, EYE, 0) + lean
	head.rotation_degrees.y = yaw
	cam.rotation_degrees.x = pitch
	cam.fov = lerp(cam.fov, t_fov, k)
	cam.position.y = sin(time * 1.7) * 0.004                                  # breathing
	_sync_pans()
	_sync_ladles()
	_sync_hands(dt)
	job_t -= dt
	if job_t <= 0.0:
		job_t = 0.4
		_sync_jobs()
	if svc == null: return
	for st in ["bench", "board", "oven"]:
		surfaces[st].control.queue_redraw()
	_sync_people(dt)
	_sync_tables()
	_sync_tickets()
	_sync_misc(dt)

func _sync_people(dt: float) -> void:
	var acts := {}
	for a in svc.actionables():
		if a.has("p"): acts[a.p.id] = a.kind
	var seen := {}
	for p in svc.parties:
		if p.type == "deliv" and p.state != "rider": continue
		seen[p.id] = true
		var seated: bool = p.table >= 0 and p.pos.distance_to(svc.tables[p.table].pos) < 6
		if not people.has(p.id): people[p.id] = _person(p)
		var e: Dictionary = people[p.id]
		var target := _to3d(p.pos)
		if seated: target = _to3d(svc.tables[p.table].pos)
		e.root.position = e.root.position.lerp(target, 1.0 - exp(-dt * 8.0))
		if seated != e.seated: _arrange(e, int(p.n), seated)
		if not seated:
			var face := Vector3(0, e.root.position.y, -1.1 if not dine else 0.0)
			if e.root.position.distance_to(face) > 0.3: e.root.look_at(face, Vector3.UP)
		var kind: String = acts.get(p.id, "")
		var lbl: Label3D = e.lbl
		if kind != "":
			var b: Array = FrontScene.BUBBLE[kind]
			var frac: float = clamp(p.pat / max(1.0, p.max), 0.0, 1.0)
			lbl.text = b[0]
			lbl.modulate = Color(b[1]).lerp(Color("e2553c"), 1.0 - frac) if frac < 0.5 else Color(b[1])
			lbl.visible = true
		else:
			lbl.visible = p.state in ["wait", "queue", "door"]
			lbl.text = "..." if p.state == "wait" else ""
			lbl.modulate = Color(1, 1, 1, 0.7)
	for id in people.keys():
		if not seen.has(id):
			people[id].root.queue_free()
			people.erase(id)

func _mk_person(r: Node3D, col: Color, app: bool) -> void:
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.2
	cap.height = 1.4
	body.mesh = cap
	body.position.y = 0.72
	body.material_override = _mat(col)
	r.add_child(body)
	var hd := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.12
	sp.height = 0.24
	hd.mesh = sp
	hd.position.y = 1.58
	hd.material_override = _mat(Color("2b2b2b") if app else Color("e8c39e"))
	r.add_child(hd)
	if app: _box(Vector3(0.36, 0.36, 0.22), Vector3(0, 1.15, 0.26), Color("4fc7a8"), r)      # the insulated bag

func _person(p: Dictionary) -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	root.position = _to3d(p.pos)
	var e := {"root": root, "figs": [], "seated": false, "lbl": null}
	var app: bool = p.get("app", false)
	for i in int(p.n) if not app else 1:
		var key := "rider" if app else "customer.%d" % ((int(p.look) + i) % 6)
		var col := Color("2fa88a") if app else Color.from_hsv(fmod(float(p.hue) + i * 0.17, 1.0), 0.45, 0.78)
		var fig := _prop(key, Vector3.ZERO, _mk_person.bind(col, app), root)
		e.figs.append(fig)
	_arrange(e, e.figs.size(), false)
	_tappable(root, Vector3(0.6 + 0.4 * (e.figs.size() - 1), 1.9, 0.6), Vector3(0, 0.95, 0), {"kind": "party", "id": p.id})
	e.lbl = _label("", Vector3(0, 2.05, 0), 64, Color.WHITE, root, true, 0.004)
	if p.has("reg") or app: _label(p.get("reg", Data.APP.name), Vector3(0, 1.86, 0), 40, Color("f4c64f") if not app else Color("4fc7a8"), root, true, 0.003)
	return e

## stand side by side, or sit round the table
func _arrange(e: Dictionary, n: int, seated: bool) -> void:
	e.seated = seated
	for i in e.figs.size():
		var f: Node3D = e.figs[i]
		if seated:
			var a := Vector2(0.62, 0).rotated(i * PI / 2.0)
			f.position = Vector3(a.x, -0.3, a.y)
		else:
			f.position = Vector3((i - (n - 1) / 2.0) * 0.45, 0, 0)

func _sync_tables() -> void:
	for e in table_nodes:
		var tb: Dictionary = e.tb
		e.plates.visible = tb.party != null and tb.party.state in ["eat", "bill"]
		e.dirt.visible = tb.dirty

func _sync_pans() -> void:
	var r := Stock.rail()
	var sig := str(r.size()) + ":" + ",".join(r.map(func(p): return p.ing))
	if sig != pan_sig:
		pan_sig = sig
		for e in pan_nodes: e.root.queue_free()
		pan_nodes = []
		var n := r.size()
		var rows := 1 if n <= 14 else 2
		var per := int(ceil(float(n) / rows))
		for i in n:
			var row := i / per
			var col := i % per
			var pw: float = 1.5 / per
			var pos := Vector3(-0.75 + pw * (col + 0.5), 0.99 + row * 0.07, -1.0 - row * 0.05)
			var id: String = r[i].ing
			var root := _prop("pan", pos, _mk_pan.bind(pw))
			var fill := _box(Vector3(pw * 0.84, 0.05, 0.17), Vector3(0, 0.0, 0), Color(Data.ING[id].col) if id != "" else Color("777777"), root)
			var ring := _box(Vector3(pw * 0.96, 0.005, 0.22), Vector3(0, 0.035, 0), Color(0.96, 0.78, 0.31), root)
			var nm: String = "" if id == "" else Data.ING[id].name
			var lb := _label(nm.left(12), Vector3(0, 0.05, 0.13), 26, Color.WHITE, root, false, min(0.0011, pw * 0.92 / (12.0 * 26.0 * 0.55)))
			lb.rotation_degrees.x = -55
			lb.outline_size = 6
			_tappable(root, Vector3(pw * 0.95, 0.12, 0.24), Vector3.ZERO, {"kind": "pan", "i": i})
			pan_nodes.append({"root": root, "fill": fill, "ring": ring, "i": i})
	for e in pan_nodes:
		var pan: Dictionary = r[e.i]
		var frac: float = 0.0 if pan.ing == "" else clamp(pan.q / max(1.0, Stock.pan_cap(pan.ing)), 0.0, 1.0)
		e.fill.scale.y = max(0.02, frac)
		e.fill.position.y = -0.025 + 0.025 * frac
		e.fill.visible = frac > 0.0
		e.ring.visible = pan.ing != "" and svc != null and svc.tool == pan.ing

## an open gastronorm pan: a base and four walls, so you can see how full it is
func _mk_pan(r: Node3D, pw: float) -> void:
	var steel := Color("c3c9cc")
	var w: float = pw * 0.92
	_box(Vector3(w, 0.006, 0.2), Vector3(0, -0.03, 0), steel, r, 0.25, 0.85)
	_box(Vector3(w, 0.06, 0.006), Vector3(0, 0, -0.1), steel, r, 0.25, 0.85)
	_box(Vector3(w, 0.06, 0.006), Vector3(0, 0, 0.1), steel, r, 0.25, 0.85)
	_box(Vector3(0.006, 0.06, 0.2), Vector3(-w / 2.0, 0, 0), steel, r, 0.25, 0.85)
	_box(Vector3(0.006, 0.06, 0.2), Vector3(w / 2.0, 0, 0), steel, r, 0.25, 0.85)

func _mk_ladle(r: Node3D, oz: int) -> void:
	_cyl(0.008, 0.26, Vector3(0, 0, 0), Color("c3c9cc"), r, 0.8)
	var bowl := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.025 + 0.006 * oz
	sp.height = sp.radius
	bowl.mesh = sp
	bowl.position = Vector3(0, -0.14, 0)
	bowl.material_override = _mat(Color("c3c9cc"), 0.3, 0.8)
	r.add_child(bowl)

func _mk_ticket(r: Node3D, spent: bool) -> void:
	var paper := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.19, 0.26)
	paper.mesh = q
	paper.material_override = _mat(Color("fbf8ef") if not spent else Color(0.85, 0.85, 0.85, 0.85), 0.9, 0.0, true)
	r.add_child(paper)

func _mk_mouse(r: Node3D) -> void:
	_box(Vector3(0.1, 0.05, 0.05), Vector3(0, 0.025, 0), Color("6d6a66"), r)

func _sync_ladles() -> void:
	var sizes := Data.LADLES.filter(func(oz): return Game.ladles(oz) > 0)
	var held: int = svc.ladle_oz if svc != null else 0
	var sig := ",".join(sizes.map(func(x): return str(x))) + "/" + str(held)
	if sig == ladle_sig: return
	ladle_sig = sig
	for c in ladle_root.get_children(): c.queue_free()
	for i in sizes.size():
		var oz: int = sizes[i]
		var on: bool = oz == held
		var root := _prop("ladle.%d" % oz, Vector3(0.9 + i * 0.11, 1.17, -1.02), _mk_ladle.bind(oz), ladle_root)
		var ll := _label("%d oz" % oz, Vector3(0, 0.17, 0), 32, Color("f4c64f") if on else Color.WHITE, root, false, 0.0012)
		ll.outline_size = 6
		_tappable(root, Vector3(0.1, 0.36, 0.1), Vector3(0, -0.05, 0), {"kind": "ladle", "oz": oz})

func _sync_tickets() -> void:
	var shown: Array = svc.tickets.slice(0, 8)
	var sig := ""
	for tk in shown: sig += "%d:%s:%s;" % [tk.id, tk.state, tk.owner]
	for e in svc.spiked: sig += "x%d:%s;" % [e.tk.id, e.why]
	if sig != ticket_sig:
		ticket_sig = sig
		for c in ticket_root.get_children(): c.queue_free()
		ticket_bars = []
		var items: Array = shown.map(func(tk): return {"tk": tk, "why": ""})
		for e in svc.spiked:
			if items.size() < 8: items.append({"tk": e.tk, "why": e.why})
		for i in items.size():
			var tk: Dictionary = items[i].tk
			var why: String = items[i].why
			var root := _prop("ticket", Vector3(-0.74 + i * 0.205, 1.82, -1.05), _mk_ticket.bind(why != ""), ticket_root)
			var ti: Dictionary = svc.ticket_info(tk)
			var head_col: Color = ti.col if why == "" else (Kit.TOMATO if why != "COLLECTED" and why != "SERVED" else Kit.BASIL)
			_box(Vector3(0.19, 0.03, 0.004), Vector3(0, 0.115, 0.002), head_col, root)
			var lines := "#%d %s\n%s\n%s" % [tk.id, tk.rec.name, ti.where, ti.kind]
			if ti.note != "": lines += "\n" + ti.note.to_upper()
			lines += "\n" + (why if why != "" else ti.status)
			var l := _label(lines, Vector3(-0.088, 0.09, 0.003), 30, Color("1b2a1f"), root, false, 0.00085)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.width = 200
			l.double_sided = false
			if why == "":
				var bar := _box(Vector3(0.18, 0.012, 0.004), Vector3(0, -0.118, 0.002), Kit.BASIL, root)
				ticket_bars.append({"bar": bar, "tk": tk})
				_tappable(root, Vector3(0.19, 0.26, 0.03), Vector3.ZERO, {"kind": "ticket", "id": tk.id})
	for e in ticket_bars:
		var p: Dictionary = e.tk.p
		var frac: float = clamp(p.pat / max(1.0, p.max), 0.0, 1.0) if p.state in ["wait", "queue", "ask", "door", "rider"] else 1.0
		e.bar.scale.x = max(0.02, frac)
		e.bar.position.x = -0.09 * (1.0 - frac)
		e.bar.material_override = _mat(Kit.BASIL if frac > 0.5 else (Kit.CHEESE if frac > 0.25 else Kit.TOMATO))

func _sync_misc(dt: float) -> void:
	crates.visible = Game.s.dock.size() > 0
	if not svc.mouse.is_empty():
		if mouse_node == null:
			mouse_node = _prop("mouse", Vector3.ZERO, _mk_mouse)
		mouse_node.position = _to3d(svc.mouse.pos)
	elif mouse_node != null:
		mouse_node.queue_free()
		mouse_node = null
	# floating words over customers: "4.5 stars  +$12.00"
	while float_labels.size() < svc.floats.size():
		float_labels.append(_label("", Vector3.ZERO, 48, Color.WHITE, null, true, 0.004))
	for i in float_labels.size():
		var l: Label3D = float_labels[i]
		if i < svc.floats.size():
			var f: Dictionary = svc.floats[i]
			l.visible = true
			l.text = f.text
			l.modulate = f.col
			l.position = _to3d(f.pos) + Vector3(0, 2.1 + (1.8 - float(f.t)) * 0.3, 0)
		else: l.visible = false

# ---------- the training-day marker ----------
## point at something (or null for nothing)
func set_highlight(node) -> void:
	marker_on = node
	if marker == null:
		marker = Node3D.new()
		add_child(marker)
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.045
		cm.bottom_radius = 0.0
		cm.height = 0.11
		cone.mesh = cm
		cone.material_override = _mat(Kit.CHEESE, 0.4, 0.0, true)
		marker.add_child(cone)
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.09
		tm.outer_radius = 0.11
		ring.mesh = tm
		ring.position.y = -0.14
		ring.material_override = _mat(Color(Kit.CHEESE, 0.8), 0.4, 0.0, true)
		marker.add_child(ring)
	marker.visible = node != null and is_instance_valid(node)

## what a training step points at: "job:<name>", "pan:<ingredient>", "ticket", "surface:<station>", "pass", "bin"
func node_for(key: String):
	if key.begins_with("job:"): return job_nodes.get(key.substr(4), null)
	if key.begins_with("surface:"): return surfaces.get(key.substr(8), null)
	if key.begins_with("pan:"):
		var r := Stock.rail()
		for e in pan_nodes:
			if e.i < r.size() and r[e.i].ing == key.substr(4): return e.root
		return null
	if key == "ticket": return ticket_root.get_child(0) if ticket_root.get_child_count() > 0 else null
	return job_nodes.get(key, null)

func _sync_marker() -> void:
	if marker == null or not marker.visible: return
	if marker_on == null or not is_instance_valid(marker_on):
		marker.visible = false
		return
	# tickets hang high on the rail, so their marker points up from underneath (above would be off the top of the view)
	var under: bool = marker_on.get_parent() == ticket_root
	var top := -0.36 if under else (0.32 if marker_on is FPSurface else 0.45)
	marker.global_position = marker_on.global_position + Vector3(0, top + sin(time * 5.0) * 0.03, 0)
	marker.rotation = Vector3(PI if under else 0.0, time * 2.0, 0.0)

func _sync_hands(dt: float) -> void:
	_sync_marker()
	var tool: String = svc.tool if svc != null else ""
	held.visible = tool != ""
	if tool != "":
		var sauce: bool = Data.ING[tool].kind == "sauce"
		held.material_override = _mat(Color(Data.ING[tool].col) if not sauce or svc.ladle_g > 0.0 else Color("c3c9cc"), 0.6, 0.8 if sauce and svc.ladle_g <= 0.0 else 0.0)
		held.scale = Vector3(1.4, 0.7, 1.4) if sauce else Vector3.ONE
	for i in hands.size():
		var h: Dictionary = hands[i]
		var goal: Vector3 = h.rest
		if h.target != null: goal = cam.to_local(h.target) + Vector3(0.02 * (1 if i == 0 else -1), 0.02, 0.12)
		h.node.position = h.node.position.lerp(goal, 1.0 - exp(-dt * 14.0))

# ---------- touch ----------
func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		touch_seen = true
		_press(e.index, e.position, e.pressed)
	elif e is InputEventScreenDrag:
		_move(e.index, e.position, e.relative)
	elif touch_seen:
		return                                             # on a touchscreen, ignore the mouse events made from touches
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_press(-1, e.position, e.pressed)
	elif e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_move(-1, e.position, e.relative)

func _ray(pos: Vector2) -> Dictionary:
	var from := cam.project_ray_origin(pos)
	var dir := cam.project_ray_normal(pos)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 40.0)
	var res := get_world_3d().direct_space_state.intersect_ray(q)
	if res.is_empty() or not res.collider.has_meta("act"): return {"from": from, "dir": dir}
	return {"act": res.collider.get_meta("act"), "point": res.position, "from": from, "dir": dir}

func _press(index: int, pos: Vector2, down: bool) -> void:
	if down:
		var hit := _ray(pos)
		var cap := {"start": pos, "moved": false, "kind": "look"}
		if hit.has("act"):
			var act: Dictionary = hit.act
			if act.kind == "surface":
				var s: FPSurface = act.surface
				if cur_view() != s.station:
					goto(s.station)                  # first touch on another station turns you to face it
					cap.kind = "none"
				else:
					var px = s.to_px(hit.from, hit.dir)
					if px != null:
						cap.kind = "surface"
						cap.s = s
						cap.px = px
						s.press(index, px, true)
						_hand(index, s.from_px(px))
			else:
				cap.kind = "tap"
				cap.act = act
		ptr[index] = cap
		return
	if not ptr.has(index): return
	var c: Dictionary = ptr[index]
	ptr.erase(index)
	match c.kind:
		"surface":
			var hit := _ray(pos)
			var px = c.s.to_px(hit.from, hit.dir)
			c.s.press(index, px if px != null else c.px, false)
			_hand(index, null)
		"tap":
			if not c.moved: _tap(c.act)
		"look":
			_settle()

func _move(index: int, pos: Vector2, rel: Vector2) -> void:
	if not ptr.has(index): return
	var c: Dictionary = ptr[index]
	if pos.distance_to(c.start) > 14.0: c.moved = true
	match c.kind:
		"surface":
			var hit := _ray(pos)
			var px = c.s.to_px(hit.from, hit.dir)
			if px == null: return
			c.s.drag(index, px, px - c.px)
			c.px = px
			_hand(index, c.s.from_px(px))
		"tap":
			if c.moved: c.kind = "look"
		"look":
			var k: float = LOOK * 720.0 / max(1.0, get_viewport().get_visible_rect().size.y)
			t_yaw -= rel.x * k
			t_pitch = clamp(t_pitch - rel.y * k, -85.0, 40.0)

## let go of a free look near a station and you settle on it
func _settle() -> void:
	var best := ""
	var bd := SNAP
	for st in STATIONS:
		var a: Vector2 = STATIONS[st]
		var d := Vector2(rad_to_deg(angle_difference(deg_to_rad(a.x), deg_to_rad(t_yaw))), a.y - t_pitch).length()
		if d < bd:
			bd = d
			best = st
	if best != "":
		if best != cur_view(): goto(best)
		else: _look_at(best)

func _hand(index: int, at) -> void:
	var i: int = 1 if index == 1 else 0
	hands[i].target = at

func _tap(act: Dictionary) -> void:
	if act.kind == "job" or svc == null:
		if kitchen != null: kitchen.job(act.get("job", act.kind), act)
		elif act.get("job", "") == "crates": svc.set_view("prep")
		elif act.get("job", "") in ["temp_fridge", "temp_freezer"]: Kit.main.toast("The %s is reading %.1f °C" % ["fridge" if act.job == "temp_fridge" else "freezer", Checks.temp_of("fridge" if act.job == "temp_fridge" else "freezer")])
		else: Kit.main.toast("That can wait until after service")
		return
	match act.kind:
		"pass":
			if svc.board.is_empty():
				Kit.main.toast("Nothing on the board to send out. Pull it from the oven and slice it first")
				return
			svc.serve()
		"bin":
			var pz = (svc.board[0] if svc.board.size() > 0 else null) if svc.view == "board" else svc.bench
			if pz == null:
				Kit.main.toast("Nothing to bin")
				return
			Kit.main.confirm("Bin it?", "The %s goes in the bin and its ticket goes back on the rail." % pz.rec.name, "Bin it", svc.bin)
		"log":
			svc.add_log()
			Art.sfx("tap")
		"sheeter":
			if svc.bench == null or svc.bench.base.method != "roll":
				Kit.main.toast("The sheeter rolls thin bases: put a Roman ball on the bench first")
				return
			svc.set_view("bench")
			svc.sheeter()
			Art.sfx("tap")
		"pan":
			if svc.view in ["front", "oven", "prep"]: svc.set_view("bench")
			svc.rail_tap(int(act.i))
		"ladle":
			if svc.ladle_g > 0.0:
				Kit.main.toast("Drop what is in the ladle first")
				return
			if svc.tool != "" and Data.ING[svc.tool].kind == "sauce" and int(act.oz) == svc.ladle_oz:
				svc.tool = ""                    # hang the ladle back up: hands free
				svc.dirty = true
				return
			svc.ladle_oz = int(act.oz)
			if svc.bench != null and svc.bench.rec.sauce != "": svc.tool = svc.bench.rec.sauce
			svc.dirty = true
		"ticket":
			for tk in svc.tickets:
				if tk.id == act.id:
					svc.claim(tk)
					if svc.bench != null and svc.bench.tk == tk: svc.set_view("bench")
		"party":
			for a in svc.actionables():
				if a.has("p") and a.p.id == act.id:
					svc.do_action(a, true)
					return
		"table":
			for a in svc.actionables():
				if (a.has("tb") and a.tb.i == act.i) or (a.has("p") and a.p.table == act.i):
					svc.do_action(a, true)
					return


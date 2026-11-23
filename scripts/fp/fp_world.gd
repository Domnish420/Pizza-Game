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
const STATION_LEAN := {"front": Vector3(0, 0, 0), "bench": Vector3(0, -0.13, -0.24), "board": Vector3(0.6, -0.17, -0.32), "oven": Vector3(0.4, -0.2, 0.2), "prep": Vector3(-0.72, -0.18, -0.4), "stores": Vector3(0, -0.05, 0.15)}
const STATION_AT := {"front": Vector3(0, 1.35, -3.0), "bench": Vector3(0, 0.92, -0.62), "board": Vector3(1.16, 0.94, -0.72), "oven": Vector3(1.28, 0.8, 0.2), "prep": Vector3(-1.6, 1.42, -0.42), "stores": Vector3(-0.1, 1.15, 1.3)}
const STATION_FOV := {"front": 74.0, "bench": 66.0, "board": 58.0, "oven": 64.0, "prep": 60.0, "stores": 76.0}
var STATIONS := {}                     # station -> Vector2(yaw, pitch), worked out from the lean and the target
## between services the prep station is about the counter (tubs, sink, mixer), not the service tablet on the wall
const CLOSED_AT := {"prep": Vector3(-1.38, 0.98, -0.5), "oven": Vector3(1.04, 1.05, 0.2)}
const CLOSED_LEAN := {"prep": Vector3(-0.55, -0.1, -0.3), "oven": Vector3(0.42, -0.3, 0.2)}
## the oven in service: its 400 x 320 deck map (OvenView) lies on the deck, 0.00235 m a unit, the map's mouth line
## at the oven's mouth; pizzas waiting sit out on the landing shelf
const OV_S := 0.00235
const OV_Z0 := -0.27
const OV_XM := 1.04
const OV_Y := 0.80
const SHELF3D := [Vector2(130, 307), Vector2(270, 307)]
## which jobs' labels show at which station (the rest stay hidden so the view is not cluttered)
const JOBS_AT := {"front": ["open", "checklist", "clean_foh"], "bench": ["dough_trays", "boxes", "clean_foh"], "board": ["boxes", "dough_trays"], "oven": [],
	"prep": ["wash", "dough", "clean_boh"], "stores": ["stores", "temp_fridge", "temp_freezer", "dry", "traps", "crates", "clean_boh"]}
## (the oven's own label shows at the oven station: see _sync_jobs)
const SNAP := 18.0                     # let go of a free look within this many degrees of a station and you settle on it

var svc: ServiceScreen                 # the day's trading, or null between services
var kitchen = null                     # the KitchenScreen between services: it runs the jobs you tap
var view_closed := "front"             # where you are looking between services
var ctrls: Dictionary
var job_labels := {}                   # job -> Label3D saying how that job stands
var job_nodes := {}                    # job -> Node3D (things that change with the state)
## the clock above the pass (the hatch in the van): you clock in and out on it; the game turns its hands
const CLOCK_AT := Vector3(0.0, 2.11, -1.087)
var clock_hands := []                  # [hour hand, minute hand], each turning about the dial's centre
var sign_text: Label3D                 # what the sign at the hatch tells the customers (OPEN, OPEN AT 11:30, CLOSED)
var job_t := 0.0
var dine := false
var retro := false                     # the Retro look: lighting per polygon corner, as 2000s consoles did
var ground_y := -0.6                   # the street is lower than the van floor
var head: Node3D
var cam: Camera3D
var yaw := 0.0
var pitch := -9.0
var t_yaw := 0.0
var t_pitch := -9.0
var gyro := Vector2.ZERO
var stick := Vector2.ZERO               # the look stick (LookStick): -1..1 each way, held = turning
var lean := Vector3.ZERO
var t_lean := Vector3.ZERO
var t_fov := 74.0
var last_view := ""
var surfaces := {}                     # station -> FPSurface
var pizza3d := {}                      # "bench" / "board" -> Pizza3D, the pizza being worked on there, in 3D
var people := {}                       # party id -> {root, figs, lbl, seated}
var table_nodes := []                  # [{root, plates, dirt}]
var pan_nodes := []                    # [{fill, ring, label, i, depth}]
var pan_sig := ""
var ladle_root: Node3D
var ladle_sig := ""
var ladle_lbls := []                    # the "2 oz" labels over the ladles
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
	retro = Game.s.get("retro", false)
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
	_staff()
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
	elif retro: m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
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

## the generated (or hand-made) model if there is one, else the placeholder built by `make`
func _prop(key: String, pos: Vector3, make: Callable, parent: Node = null) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	(parent if parent != null else self).add_child(root)
	var m := Art.model("fp." + key)
	if m != null:
		root.add_child(m)
		_shade(m)
	else: make.call(root)
	return root

## a model's materials lit per pixel, or per corner in the Retro look (they are shared, so this is quick after once)
func _shade(n: Node) -> void:
	var want := BaseMaterial3D.SHADING_MODE_PER_VERTEX if retro else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	if n is MeshInstance3D and n.mesh != null:
		for s in n.mesh.get_surface_count():
			var mt = n.get_active_material(s)
			if mt is BaseMaterial3D and mt.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED and mt.shading_mode != want:
				mt.shading_mode = want
	for c in n.get_children(): _shade(c)

# ---------- the room ----------
func _environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("9cc6e8") if not dine else Color("2a2622")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("fff0dc")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true                  # a touch richer colour: the warm, toy-like look
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.03
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 0.75 if not dine else 0.35
	sun.light_color = Color("fff1d8")
	add_child(sun)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 2.1, -0.4)
	lamp.omni_range = 4.5
	lamp.light_energy = 1.0
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
	var pass_n := _prop("pass", Vector3(1.5, 0.92, -1.02), _mk_pass)
	job_nodes.pass = pass_n
	_tappable(pass_n, Vector3(0.32, 0.16, 0.24), Vector3(0, 0.06, 0), {"kind": "pass"})
	job_labels.pass = _small_label("Pass", Vector3(0, 0.2, 0), pass_n)
	job_labels.pass.no_depth_test = true          # shown only when it is what you need next, so always readable
	var bin_n := _prop("bin", Vector3(-0.62, 0.92, -0.78), _mk_bin)
	job_nodes.bin = bin_n
	_tappable(bin_n, Vector3(0.18, 0.2, 0.18), Vector3(0, 0.08, 0), {"kind": "bin"})
	job_labels.bin = _small_label("Bin", Vector3(0, 0.22, 0), bin_n)
	job_labels.bin.no_depth_test = true          # shown only when it is what you need next, so always readable
	if float(Game.tier("roller").auto) > 0.0:
		var sh := _prop("sheeter", Vector3(-0.62, 0.92, -0.45), _mk_sheeter)
		_tappable(sh, Vector3(0.3, 0.3, 0.3), Vector3(0, 0.12, 0), {"kind": "sheeter"})
		job_labels.sheeter = _small_label("Sheeter", Vector3(0, 0.36, 0), sh)
		job_labels.sheeter.no_depth_test = true      # shown only when it is what you need next, so always readable
	if svc == null: return
	var s := FPSurface.new()
	s.setup("bench", ctrls.bench, Vector2i(640, 640), Vector2(0.6, 0.6), true, true)
	s.position = Vector3(0, 0.922, -0.62)
	s.rotation_degrees.x = -90
	add_child(s)
	surfaces.bench = s
	_pizza_on("bench", s, Vector3(0, 0.921, -0.62), 0.6 / 320.0)

func _mk_counter(r: Node3D) -> void:
	_box(Vector3(1.6, 0.88, 0.64), Vector3(0, 0.44, -0.78), Color("aab1b5"), r, 0.35, 0.7)       # stainless body
	_box(Vector3(1.62, 0.04, 0.66), Vector3(0, 0.9, -0.78), Color("ece9e3"), r, 0.25)             # marble top
	_box(Vector3(1.6, 0.08, 0.26), Vector3(0, 0.95, -1.0), Color("9aa3a8"), r, 0.35, 0.7)         # the chilled rail
	var glass := _box(Vector3(1.6, 0.01, 0.2), Vector3(0, 1.12, -1.0), Color(0.85, 0.95, 1.0, 0.08), r, 0.05)
	glass.rotation_degrees.x = 25                                                                   # sneeze guard
	_box(Vector3(1.7, 0.02, 0.03), Vector3(0, 1.96, -1.06), Color("8d969b"), r, 0.3, 0.8)         # ticket rail

## the pizza at a working surface is a real 3D pizza; the surface itself becomes a see-through overlay drawn on top
## (guides, your fingertips, the cut line), still taking the touches exactly where they were
func _pizza_on(station: String, s: FPSurface, at: Vector3, unit: float) -> void:
	s.overlay()
	s.control.draw3d = true
	var p := Pizza3D.new()
	p.unit = unit
	p.position = at
	p.steam_on = station == "board"
	add_child(p)
	pizza3d[station] = p

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
	_pizza_on("board", s, Vector3(1.16, 0.941, -0.72), 0.5 / 320.0)

func _mk_side(r: Node3D) -> void:
	_box(Vector3(0.82, 0.88, 0.64), Vector3(1.22, 0.44, -0.78), Color("aab1b5"), r, 0.35, 0.7)
	_box(Vector3(0.84, 0.04, 0.66), Vector3(1.22, 0.9, -0.78), Color("c9ccce"), r, 0.3, 0.6)
	_box(Vector3(0.56, 0.02, 0.5), Vector3(1.16, 0.93, -0.72), Color("7a5634"), r)                 # the wooden board

func _oven() -> void:
	var kind: String = Game.tier("oven").type
	_prop("oven." + kind, Vector3.ZERO, _mk_oven.bind(kind))
	if Game.tier("oven").type == "wood":       # the logs, stacked beside the mouth
		var logs := _prop("logs", Vector3(1.19, 0.6, 0.745), _mk_logs)
		_tappable(logs, Vector3(0.2, 0.3, 0.26), Vector3(0, 0.15, 0), {"kind": "log"})
		job_labels.logs = _small_label("Logs", Vector3(-0.2, 0.22, 0), logs)        # in front of the oven, above the landing, clear of the side card
		job_labels.logs.no_depth_test = true          # the oven's arch would clip it; it only shows at the oven (_sync_jobs)
	if svc == null:
		# between services: the door closes a cold oven; a wood oven lit this morning stands open with its fire going
		# (a deck oven's is stainless with a window; a dome's is a riveted iron plate with two wooden handles)
		var dome: bool = kind == "wood" or kind == "rotary"
		oven_door = _prop("oven_door." + ("iron" if dome else "steel"), Vector3.ZERO, func(r: Node3D):
			_box(Vector3(0.025, 0.66, 0.82), Vector3(1.025, 1.1, 0.2), Color("2f2d2b"), r, 0.5, 0.3)
			var hb := _cyl(0.014, 0.4, Vector3(0.995, 1.25, 0.2), Color("c3c9cc"), r, 0.3)
			hb.rotation_degrees.x = 90)
		var spot := Node3D.new()
		spot.position = Vector3(1.0, 1.1, 0.2)
		add_child(spot)
		_job("oven", spot, Vector3(0.12, 0.7, 0.9), Vector3.ZERO, Vector3(-0.04, 0.26, 0))     # its label across the arch
		if Data.OVENS[kind].feeds:
			fire_oven = Oven.new(Game.tier("oven"))
			fire_oven.start_day(120.0)
			_oven_inside(kind, fire_oven)
		return
	# in service: the deck itself is the surface you work on, lying flat inside the oven, seen through the mouth
	ctrls.oven.draw3d = true
	ctrls.oven.shelf_pos = SHELF3D
	var s := FPSurface.new()
	s.setup("oven", ctrls.oven, Vector2i(800, 640), Vector2(400.0 * OV_S, 320.0 * OV_S), false)
	s.overlay(false)
	s.basis = Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))     # the map's right is +z, its up is into the oven
	s.position = _deck3d(Vector2(200, 160), OV_Y + 0.002)
	add_child(s)
	surfaces.oven = s
	_oven_inside(kind, svc.oven)

## a point on the oven's deck map, in the room
func _deck3d(p: Vector2, y: float = OV_Y) -> Vector3:
	return Vector3(OV_XM + (OvenView.MOUTH_Y - p.y) * OV_S, y, OV_Z0 + p.x * OV_S)

var oven_nodes := {}                   # "p<pizza id>" / "s<ticket id>" -> the pizza in or at the oven, in 3D
var oven_labels := {}
var oven_light: OmniLight3D
var flames := []                       # [{node, base, ph, w, h}]
var log_nodes := []                    # the logs burning on the fire bed
var embers: MeshInstance3D
var peel: Node3D                       # the launching peel, under a pizza you are sliding in or out
var turner: Node3D                     # the turning peel
var grip_at = null                     # where your right hand holds the peel's handle (or null)
var oven_door: Node3D
var prep_screen: Label3D                 # the prep list on the tablet between services
var fire_oven: Oven                    # between services: the wood oven's fire as it is this morning

## the light of the fire or the elements inside, the flames, the logs and coals, and the peels
func _oven_inside(kind: String, ov: Oven) -> void:
	oven_light = OmniLight3D.new()
	oven_light.position = Vector3(1.38, 1.15, 0.2)
	oven_light.omni_range = 0.62
	oven_light.light_color = {"electric": Color("ff9a5a"), "gas": Color("ffc08a"), "wood": Color("ff8a3a"), "rotary": Color("ff9a4a")}.get(kind, Color("ff9a5a"))
	oven_light.light_energy = 1.4
	add_child(oven_light)
	if kind == "wood" or kind == "rotary":
		var fm := StandardMaterial3D.new()
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		fm.albedo_color = Color(1.0, 0.55, 0.15)
		var fm2: StandardMaterial3D = fm.duplicate()
		fm2.albedo_color = Color(1.0, 0.85, 0.35)
		var at := _deck3d(ov.fire_pos)
		for i in 9:
			var mi := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 1.0
			sm.height = 2.0
			sm.radial_segments = 10
			sm.rings = 6
			mi.mesh = sm
			mi.material_override = fm if i % 2 == 0 else fm2
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var off := Vector3(randf_range(-0.06, 0.06), 0, randf_range(-0.07, 0.07)) if i > 0 else Vector3.ZERO
			mi.position = at + off
			add_child(mi)
			flames.append({"node": mi, "base": at + off, "ph": randf() * TAU, "w": 0.035 if i == 0 else randf_range(0.018, 0.03), "h": 0.13 if i == 0 else randf_range(0.06, 0.11)})
		if kind == "wood":
			# the coals glowing in the fire bed, and a pool of logs to burn on them
			embers = MeshInstance3D.new()
			var em := CylinderMesh.new()
			em.top_radius = 0.12; em.bottom_radius = 0.12; em.height = 0.004; em.radial_segments = 24
			embers.mesh = em
			var emm := StandardMaterial3D.new()
			emm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			emm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			emm.albedo_color = Color(1.0, 0.35, 0.08)
			embers.material_override = emm
			embers.position = at + Vector3(0, 0.02, 0)
			add_child(embers)
			for k in 6:
				var lg := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 0.026; cm.bottom_radius = 0.03; cm.height = 0.22; cm.radial_segments = 9
				lg.mesh = cm
				var lm := StandardMaterial3D.new()
				lm.albedo_color = Color("6b4a2b")
				lm.roughness = 0.9
				lg.material_override = lm
				lg.visible = false
				add_child(lg)
				log_nodes.append(lg)
	# the peels: the launching peel under a pizza you slide, the turning peel at the edge you turn
	peel = _peel_model("peel", 0.165)
	turner = _peel_model("peel.turning", 0.1)

## a peel model (or a stand-in): its blade centred on the node, the handle back toward you along -X
func _peel_model(key: String, blade_r: float) -> Node3D:
	var n := Node3D.new()
	var m := Art.model("fp." + key)
	if m != null:
		n.add_child(m)
		_shade(m)
	else:
		_cyl(blade_r, 0.004, Vector3(0, 0.002, 0), Color("d5d9db"), n, 0.3)
		var h := _cyl(0.013, 0.9, Vector3(-blade_r - 0.45, 0.02, 0), Color("b98a55"), n)
		h.rotation_degrees.z = 90
	n.visible = false
	add_child(n)
	return n

func _oven_pizza(key: String, u: float) -> Pizza3D:
	if not oven_nodes.has(key):
		var p := Pizza3D.new()
		p.unit = u
		p.yaw_offset = -PI / 2.0          # the deck map's x runs along the room's z
		add_child(p)
		oven_nodes[key] = p
	return oven_nodes[key]

## a pizza one of your crew is baking: just a simple pizza, browning as it goes
func _staff_pizza(key: String, r: float, p: float) -> Node3D:
	if not oven_nodes.has(key):
		var n := Node3D.new()
		_cyl(r, 0.02, Vector3(0, 0.01, 0), Color("e3c48e"), n)
		_cyl(r * 0.8, 0.022, Vector3(0, 0.012, 0), Color("c8321f"), n)
		for k in 6: _cyl(r * 0.14, 0.024, Vector3(cos(k * 1.1) * r * 0.45, 0.013, sin(k * 1.1) * r * 0.45), Color("fbe7a0"), n)
		add_child(n)
		oven_nodes[key] = n
	var node: Node3D = oven_nodes[key]
	node.get_child(0).material_override = _mat(Color("e3c48e").lerp(Color("b5702e"), clamp(p, 0.0, 1.0)))
	return node

func _oven_label(key: String, at: Vector3, text: String, col: Color) -> void:
	if not oven_labels.has(key):
		var l := _label("", Vector3.ZERO, 34, Color.WHITE, null, true, 0.0009)
		l.fixed_size = true
		l.no_depth_test = true
		oven_labels[key] = l
	var lb: Label3D = oven_labels[key]
	lb.position = at + Vector3(0, 0.13, 0)
	lb.text = text
	lb.modulate = col
	lb.visible = text != ""

## everything in and at the oven, each frame: the pizzas on the deck and the landing, their states, the peels in your
## hand, the fire
func _sync_oven() -> void:
	var ov: Oven = svc.oven
	var ovv: OvenView = ctrls.oven
	var u: float = OV_S * ov.prad / 106.0
	var r_m: float = ov.prad * OV_S
	var dg = ovv.drag
	var seen := {}
	peel.visible = false
	turner.visible = false
	grip_at = null
	var ir: bool = Equip.has("ir_thermo") and ov.def.feeds
	for o in ov.items:
		var at := _deck3d(o.at)
		if o.owner == "me":
			var key := "p%d" % o.pz.id
			seen[key] = true
			var n := _oven_pizza(key, u)
			var moving: bool = dg != null and dg.pz == o.pz and dg.mode == "move"
			if moving: at = _deck3d(dg.pos, OV_Y + 0.025)
			n.position = at
			n.show_pizza(o.pz)
			var st: String = ("%s has it" % Story.BOSS if Story.stage() == "pizzaiolo" else "your fornaio has it") if o.auto else ov.status(o)
			var col := Color.WHITE
			if st == "READY": col = Kit.BASIL
			elif st == "TURN": col = Kit.CHEESE
			elif st == "BURNING" or st == "OVERDONE": col = Kit.TOMATO
			var txt := "" if st == "baking" else st
			if moving and ir: txt = "%d °C here" % ov.deck_at(dg.pos)
			_oven_label(key, at, txt, col)
			if moving: _hold(peel, at, r_m * 1.15 / 0.165, 0.0)
			elif dg != null and dg.pz == o.pz and dg.mode == "turn":
				# the turning peel under the edge you are dragging round
				var edge := _deck3d(dg.pos, OV_Y + 0.004)
				_hold(turner, edge, 0.8, 0.0)
		else:
			var key := "s%d" % o.tk.id
			seen[key] = true
			_staff_pizza(key, r_m * 0.92, o.p).position = at
			_oven_label(key, at, str(o.tk.owner), Color(1, 1, 1, 0.8))
	for i in ov.shelf.size():
		var pz: Pizza = ov.shelf[i]
		var key := "p%d" % pz.id
		seen[key] = true
		var n := _oven_pizza(key, u)
		var at := _deck3d(SHELF3D[min(i, SHELF3D.size() - 1)], 0.79)
		var txt := ""
		if dg != null and dg.pz == pz and dg.mode == "move":
			at = _deck3d(dg.pos, OV_Y + 0.025)
			_hold(peel, at, r_m * 1.15 / 0.165, 0.0)
			if ir and dg.pos.y < OvenView.MOUTH_Y: txt = "%d °C here" % ov.deck_at(dg.pos)
		n.position = at
		n.show_pizza(pz)
		_oven_label(key, at, txt, Color.WHITE)
	for key in oven_nodes.keys():
		if not seen.has(key):
			oven_nodes[key].queue_free()
			oven_nodes.erase(key)
			if oven_labels.has(key):
				oven_labels[key].queue_free()
				oven_labels.erase(key)
	_sync_fire(ov)

## a peel in your hand: blade at `at` (scaled), the handle back toward you, your right hand round its end
func _hold(pl: Node3D, at: Vector3, s: float, yaw: float) -> void:
	pl.visible = true
	pl.position = at - Vector3(0, 0.005 * s, 0)
	pl.scale = Vector3.ONE * s
	pl.rotation.y = yaw
	# your hand holds the handle as far back as it can while still in sight (a peel's handle is longer than the view)
	var vh: float = get_viewport().get_visible_rect().size.y
	var lx := -0.4
	var x := -0.45
	while x >= -1.05:
		var w: Vector3 = pl.global_transform * Vector3(x, 0.03, 0.0)
		if cam.is_position_behind(w) or cam.unproject_position(w).y > vh * 0.8: break
		lx = x
		x -= 0.05
	grip_at = pl.global_transform * Vector3(lx, 0.03, 0.0)

## the fire: the logs on it burning down (charring, shrinking), the coals glowing, flames as big as the fire is
func _sync_fire(ov: Oven) -> void:
	var fl: float = ov.flame() if ov.def.feeds else (1.0 if ov.def.fire > 0.0 else 0.0)
	var at := _deck3d(ov.fire_pos)
	for i in log_nodes.size():
		var n: MeshInstance3D = log_nodes[i]
		if i >= ov.logs.size():
			n.visible = false
			continue
		var l: Dictionary = ov.logs[i]
		n.visible = true
		# laid along the left wall on the coals, side by side, the next ones on top (as a pizzaiolo stacks them)
		var lay := i % 3
		n.position = at + Vector3(0.02 * sin(i * 2.1), 0.032 + 0.048 * (i / 3) + 0.006 * lay, 0.056 * (lay - 1) + 0.028 * (i / 3))
		n.rotation = Vector3(0, 0.12 * sin(i * 2.7), PI / 2.0)
		n.scale = Vector3.ONE * (0.6 + 0.4 * clamp(l.m, 0.0, 1.0))
		var lm: StandardMaterial3D = n.material_override
		var burnt: float = clamp(1.0 - l.m, 0.0, 1.0)
		lm.albedo_color = Color("6b4a2b").lerp(Color("231912"), burnt)
		lm.emission_enabled = true
		lm.emission = Color(1.0, 0.35, 0.08)
		lm.emission_energy_multiplier = 0.6 * clamp(l.age / 12.0, 0.0, 1.0) * burnt
	if embers != null:
		var em: StandardMaterial3D = embers.material_override
		em.albedo_color = Color(1.0, 0.35, 0.08) * clamp(0.2 + 0.8 * (ov.coals if ov.def.feeds else 1.0), 0.0, 1.0)
	for f in flames:
		var k: float = 0.75 + 0.25 * sin(time * 9.0 + f.ph) + 0.12 * sin(time * 23.0 + f.ph * 2.0)
		var h: float = f.h * clamp(fl, 0.0, 2.0) * k
		var wd: float = f.w * (0.7 + 0.35 * clamp(fl, 0.0, 2.0))
		f.node.visible = h > 0.004
		f.node.scale = Vector3(wd, max(h, 0.001), wd)
		f.node.position = f.base + Vector3(0.006 * sin(time * 7.0 + f.ph), OV_Y + 0.03 + h * 0.7 - f.base.y, 0)
	if oven_light != null:
		var flick: float = 1.0 + (0.12 * sin(time * 11.0) + 0.08 * sin(time * 27.0) if not flames.is_empty() else 0.0)
		var heat: float = clamp((ov.dome - 100.0) / 380.0, 0.0, 1.3) if ov.def.feeds else 1.0
		oven_light.light_energy = (0.3 + 1.2 * heat) * flick

## between services: a wood oven lit this morning stands open with its fire going; a cold one is shut
func _sync_closed_oven() -> void:
	if fire_oven == null: return
	var L: Dictionary = Game.s.get("oven_lit", {})
	var lit: bool = int(L.get("day", -1)) == Game.s.day and Game.s.phase == "morning"
	if Story.role() == "pizzaiolo" and Game.s.phase == "morning": lit = true
	oven_door.visible = not lit
	if job_labels.has("oven"): job_labels.oven.position = Vector3(-0.07, 0.26 if lit else 0.08, 0)      # over the door, or above the fire
	oven_light.visible = lit
	for f in flames: f.node.visible = lit
	for n in log_nodes: n.visible = false
	if embers != null: embers.visible = lit
	if not lit: return
	if fire_oven.logs.size() < 2: fire_oven.add_log(2.0)
	fire_oven.step(get_process_delta_time(), 1.0)
	fire_oven.dome = Oven.warm_dome(float(Game.s.clock) - float(L.get("at", Game.s.clock - 120)))
	_sync_fire(fire_oven)

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
	else:
		# between services the tablet shows the day's prep list (in service it is the live prep surface)
		# (top-aligned, from just inside the top of what the morning prep view takes in, so no line is cut off)
		prep_screen = _label("", Vector3(-1.597, 1.47, -0.42), 26, Color("f3efe4"), self, false, 0.001)
		prep_screen.rotation_degrees.y = 90
		prep_screen.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		prep_screen.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		prep_screen.width = 780
		prep_screen.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		prep_screen.line_spacing = 2
	crates = _prop("crates", Vector3(-1.2, 0.0, 0.75), _mk_crates)
	_tappable(crates, Vector3(0.6, 0.7, 0.5), Vector3(0, 0.35, 0), {"kind": "job", "job": "crates"})
	job_labels.crates = _label("Delivery", Vector3(0, 0.8, 0), 30, Color.WHITE, crates, true, 0.0009)
	job_labels.crates.fixed_size = true

## the prep list as the tablet shows it: what is left to prep for today (or, in the evening, for tomorrow)
func _prep_text(morning: bool) -> String:
	var rows := Day.prep_list(Game.s.day if morning else Game.s.day + 1)
	var lines := ["PREP LIST · %s" % ("today" if morning else "for tomorrow"), ""]
	var left := 0.0
	for row in rows:
		var nm: String = Data.ING[row.id].name
		if row.get("block", "") != "": lines.append("x  %s: %s" % [nm, row.block])
		elif row.raw > 0.5:
			lines.append("-  %s: %s to prep" % [nm, Stock.amount(row.id, row.raw)])
			left += row.minutes
		else: lines.append("ok  %s" % nm)
	if rows.is_empty(): lines.append("Nothing to prep.")
	elif left > 0.0: lines.append("\nAbout %d min of prep. Tap the counter to start." % int(ceil(left)))
	else: lines.append("\nAll prepped.")
	return "\n".join(lines.slice(0, 12))

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
		var tl := _label("Table %d" % (tb.i + 1), Vector3(0, 1.0, 0), 30, Color(1, 1, 1, 0.55), root, true, 0.0028)
		table_nodes.append({"root": root, "plates": plates, "dirt": dirt, "tb": tb, "lbl": tl})

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
	if not job_nodes.has("boxes_flat"):                # a model: its stacks are the parts named flat and folded
		var f = bx.find_child("flat", true, false)
		var g = bx.find_child("folded", true, false)
		if f != null: job_nodes.boxes_flat = f
		if g != null: job_nodes.boxes_folded = g
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
	var trays := _prop("dough_trays", Vector3(1.47, 0.92, -0.38), _mk_trays)
	_job("dough_trays", trays, Vector3(0.36, 0.4, 0.5), Vector3(0, 0.15, 0), Vector3(0, 0.5, 0))
	# the opening checklist on its clipboard, and the sign at the hatch
	var cb := _prop("clipboard", Vector3(-0.98, 1.55, -1.08), _mk_clipboard)
	if dine:            # a restaurant is open above the counters: the clipboard hangs from the pass's header on strings
		for x in [-0.08, 0.08]: _string(cb, Vector3(x, 0.15, -0.004), Vector3(x * 0.7, 0.42, -0.004))
	_job("checklist", cb, Vector3(0.26, 0.34, 0.06), Vector3.ZERO, Vector3(0, 0.27, 0.05))
	var sign := _prop("sign", Vector3(0.58, 1.66, -1.06), _mk_sign)
	sign_text = _label("", Vector3(0, 0.0, 0.04), 44, Color("f4c64f"), sign, false, 0.0016)
	# the clock above the pass: tap it to clock in (open up), to clock out early in service, and to clock out at night
	var clk := _prop("timeclock", CLOCK_AT, _mk_clock)
	_job("open", clk, Vector3(0.3, 0.3, 0.1), Vector3(0, 0, 0.04), Vector3(0.17, 0, 0.06))
	job_labels.open.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT       # beside the clock, clear of the marker under it
	clock_hands = [clk.find_child("hand_h", true, false), clk.find_child("hand_m", true, false)]

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

## a thin string between two points in a node's space (they share a depth): what things hang from
func _string(parent: Node3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var c := _cyl(0.0025, d.length(), (a + b) / 2.0, Color("cdbf9a"), parent)
	c.rotation.z = -atan2(d.x, d.y)

func _mk_clipboard(r: Node3D) -> void:
	_box(Vector3(0.24, 0.32, 0.015), Vector3.ZERO, Color("8a6a40"), r)
	_box(Vector3(0.21, 0.27, 0.005), Vector3(0, -0.01, 0.01), Color("fbf8ef"), r)

func _mk_clock(r: Node3D) -> void:
	var dial := _cyl(0.13, 0.04, Vector3(0, 0, 0.02), Color("e0533a"), r)
	dial.rotation_degrees.x = 90
	var face := _cyl(0.115, 0.01, Vector3(0, 0, 0.045), Color("fbf8ef"), r)
	face.rotation_degrees.x = 90
	for h in [["hand_h", 0.045, 0.012], ["hand_m", 0.075, 0.008]]:
		var n := Node3D.new()
		n.name = h[0]
		n.position = Vector3(0, 0, 0.055)
		r.add_child(n)
		_box(Vector3(h[2], h[1], 0.003), Vector3(0, h[1] / 2.0, 0), Color("33383b"), n)

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
	if prep_screen != null: prep_screen.text = _prep_text(morning)
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
	var closed_today: bool = G.s.hygiene.get("closed_day", -1) == G.s.day
	var late: bool = morning and Day.now() > Day.open_time()
	if svc != null: L.open.text = ""
	elif closed_today and morning: L.open.text = "Closed today"
	elif late: L.open.text = "Clock in · open now"
	elif morning: L.open.text = "Clock in · %s %s" % ["service at" if Story.employed() else "open at", Data.hhmm(Day.open_time())]
	else: L.open.text = "Clock out · %s" % ("go home" if Story.employed() else "lock up")
	L.open.modulate = Kit.CHEESE
	if sign_text != null:
		if svc != null: sign_text.text = "OPEN"
		elif closed_today or not morning: sign_text.text = "CLOSED" + ("\ntoday" if closed_today and morning else "")
		else: sign_text.text = "OPEN AT\n%s" % Data.hhmm(max(Day.now(), Day.open_time()))
		sign_text.modulate = Kit.BASIL if svc != null else Color("f4c64f")
	if L.has("oven"):
		var wood: bool = Data.OVENS[G.tier("oven").type].feeds
		var lt: Dictionary = G.s.get("oven_lit", {})
		var lit_today: bool = int(lt.get("day", -1)) == G.s.day
		if not wood: L.oven.text = ""
		elif Story.role() == "pizzaiolo": L.oven.text = "%s lit the oven" % Story.BOSS if morning else ""
		elif not morning: L.oven.text = ""
		elif lit_today:
			var dm := Oven.warm_dome(float(G.s.clock) - float(lt.at))
			L.oven.text = "Oven about %d °C%s" % [dm, " · ready" if dm >= 430.0 else " · heating"]
			L.oven.modulate = _ok_col(dm >= 430.0, true)
		else:
			L.oven.text = "Oven cold · tap to light it"
			L.oven.modulate = Kit.TOMATO
	if L.has("logs"): L.logs.text = "Logs (%d) · tap to feed" % int(Stock.have("wood")) if svc != null else "Logs (%d)" % int(Stock.have("wood"))
	if L.has("pass"):
		var on_pass: int = svc.tickets.filter(func(tk): return tk.state == "pass").size() if svc != null else 0
		L.pass.text = ("Pass · tap to send it out" if svc != null and svc.board.size() > 0 else "Pass") + ((" · %d ready" % on_pass) if on_pass > 0 else "")
		L.pass.modulate = Kit.CHEESE if svc != null and svc.board.size() > 0 else Color.WHITE
	var here: Array = JOBS_AT.get(cur_view(), [])
	for j in L:
		if j in ["open", "pass", "bin", "sheeter", "logs"]:
			match j:
				"open": L[j].visible = svc == null          # the clock's label; in service the clock just keeps time
				"logs": L[j].visible = svc != null and cur_view() == "oven"
				"pass": L[j].visible = svc != null and (svc.board.size() > 0 or svc.tickets.any(func(tk): return tk.state == "pass"))
				"bin": L[j].visible = svc != null and cur_view() in ["bench", "board"] and (svc.bench != null or svc.board.size() > 0)
				"sheeter": L[j].visible = svc != null and cur_view() == "bench" and svc.bench != null
			continue
		if j == "oven":
			L[j].visible = svc == null and cur_view() == "oven" and L[j].text != ""
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
	# your hands (just hands: no forearms in the way of the work), low in the frame like a chest camera sees them
	for side in [1, -1]:
		var nm := "right" if side == 1 else "left"
		var h := _prop("hand." + nm, Vector3.ZERO, _mk_hand, cam)
		var rest := Vector3(0.23 * side, -0.235, -0.44)          # low in the corners of the frame: just your hands, no arms
		h.position = rest
		# the hand's poses: open (dough), a pinch (a topping), a grip (the ladle, the peel)
		var poses := {}
		if Art.has_model("fp.hand." + nm):
			poses.open = h.get_child(0)
			for pose in ["pinch", "grip"]:
				var m := Art.model("fp.hand.%s.%s" % [nm, pose])
				if m == null: continue
				m.visible = false
				h.add_child(m)
				_shade(m)
				poses[pose] = m
		hands.append({"node": h, "rest": rest, "target": null, "poses": poses, "pose": "open"})
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
	var arm := _cyl(0.04, 0.38, Vector3(0, 0, 0.27), Color("d9a77f"), r)
	arm.rotation_degrees.x = 90
	_box(Vector3(0.09, 0.03, 0.11), Vector3(0, 0, 0.055), Color("e2b58f"), r)

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
	_sound(dt)
	if clock_hands.size() == 2 and clock_hands[0] != null and clock_hands[1] != null:
		var mins: float = svc.minute() if svc != null else Day.now()
		clock_hands[0].rotation.z = -TAU * fmod(mins, 720.0) / 720.0
		clock_hands[1].rotation.z = -TAU * fmod(mins, 60.0) / 60.0
	if cur_view() != last_view: _look_at(cur_view())
	var g := Input.get_gyroscope()
	if g.length() > 0.02 and Game.s.get("gyro", true):
		gyro.x += rad_to_deg(g.x) * dt
		gyro.y = clamp(gyro.y + rad_to_deg(g.y) * dt * (-1.0 if DisplayServer.screen_get_orientation() == DisplayServer.SCREEN_REVERSE_LANDSCAPE else 1.0), -60.0, 60.0)
	if stick != Vector2.ZERO:
		# the look stick: the further you push, the faster you turn (eased so small pushes are fine aiming)
		var sp := stick * stick.length() * look_speed()
		t_yaw -= sp.x * 120.0 * dt
		t_pitch = clamp(t_pitch - sp.y * 80.0 * dt * look_flip(), -85.0, 40.0)
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
	if not staff.is_empty(): _animate_staff(dt)
	job_t -= dt
	if job_t <= 0.0:
		job_t = 0.4
		_sync_jobs()
	if svc == null: _sync_closed_oven()
	if svc == null: return
	for st in ["bench", "board", "oven"]:
		surfaces[st].control.queue_redraw()
	if pizza3d.has("bench"): pizza3d.bench.show_pizza(svc.bench)
	if pizza3d.has("board"): pizza3d.board.show_pizza(svc.board[0] if svc.board.size() > 0 else null)
	if surfaces.has("oven") and ctrls.oven.draw3d: _sync_oven()
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
		var was: Vector3 = e.root.position
		e.root.position = was.lerp(target, 1.0 - exp(-dt * 8.0))
		var vel: Vector3 = (e.root.position - was) / max(dt, 0.001)
		vel.y = 0.0
		e.speed = lerp(float(e.get("speed", 0.0)), vel.length(), 1.0 - exp(-dt * 6.0))
		if seated != e.seated: _arrange(e, int(p.n), seated)
		if not seated:
			# walking: face the way you are going; standing: face the counter
			var face: Vector3 = e.root.position + vel.normalized() if vel.length() > 0.25 else Vector3(0, e.root.position.y, -1.1 if not dine else 0.0)
			var flat := Vector3(face.x, e.root.position.y, face.z)
			if e.root.position.distance_to(flat) > 0.05:
				var want: float = e.root.global_transform.looking_at(flat, Vector3.UP, true).basis.get_euler().y
				e.root.rotation.y = lerp_angle(e.root.rotation.y, want, 1.0 - exp(-dt * 8.0))
		var kind: String = acts.get(p.id, "")
		_animate(e, p, kind, dt)
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
	var e := {"root": root, "figs": [], "seated": false, "lbl": null, "speed": 0.0}
	var app: bool = p.get("app", false)
	var looks := []
	for i in int(p.n) if not app else 1: looks.append((int(p.look) + i) % 6)
	# customer.0 is a kid: never the one ordering at the front (a kid alone gets an adult's look)
	if looks.size() > 0 and looks[0] == 0:
		if looks.size() > 1: looks.append(looks.pop_front())
		else: looks[0] = 1 + int(p.id) % 5
	for i in looks.size():
		var key := "rider" if app else "customer.%d" % looks[i]
		var col := Color("2fa88a") if app else Color.from_hsv(fmod(float(p.hue) + i * 0.17, 1.0), 0.45, 0.78)
		var fig := _prop(key, Vector3.ZERO, _mk_person.bind(col, app), root)
		e.figs.append(fig)
	_arrange(e, e.figs.size(), false)
	_tappable(root, Vector3(0.6 + 0.4 * (e.figs.size() - 1), 2.05, 0.6), Vector3(0, 1.02, 0), {"kind": "party", "id": p.id})
	e.lbl = _label("", Vector3(0, 2.3, 0), 64, Color.WHITE, root, true, 0.004)          # above the hair (the tallest is about 2.05 m)
	if p.has("reg") or app: _label(p.get("reg", Data.APP.name), Vector3(0, 2.16, 0), 40, Color("f4c64f") if not app else Color("4fc7a8"), root, true, 0.003)
	return e

## stand side by side, or sit round the table
func _arrange(e: Dictionary, n: int, seated: bool) -> void:
	e.seated = seated
	if seated: e.root.rotation = Vector3.ZERO           # the chairs face the table, whichever way the party came in
	for i in e.figs.size():
		var f: Node3D = e.figs[i]
		# a model's legs hang from hip and knee joints: bend them to sit down
		var hips := [f.find_child("hip_l", true, false), f.find_child("hip_r", true, false)]
		var knees := [f.find_child("knee_l", true, false), f.find_child("knee_r", true, false)]
		var jointed: bool = hips[0] != null
		if seated:
			var a := Vector2(0.62, 0).rotated(i * PI / 2.0)
			# lower them until the hips sit on the seat (0.53 m: the seat top plus the seat of the trousers)
			f.position = Vector3(a.x, f.position.y, a.y)
			f.set_meta("seat_y", -(hips[0].position.y - 0.53) if jointed else -0.3)
			f.rotation.y = atan2(-a.x, -a.y)           # face the middle of the table
		else:
			f.position = Vector3((i - (n - 1) / 2.0) * 0.45, f.position.y, 0)
			f.set_meta("seat_y", 0.0)
			f.rotation.y = 0.0
		if not jointed:
			f.position.y = f.get_meta("seat_y")

# ---------- the crew ----------
## the crew at Bella Napoli, there to be seen: Marco by the pass while you are his pizzaiolo (he watches every
## pizza go out and talks you through your training day), Luca at the end of the prep counter once you are senior
var staff := []

func _staff() -> void:
	if not dine: return
	match Story.role():
		"pizzaiolo": _staff_member("staff.marco", Vector3(2.15, 0.0, -1.95), "marco")        # out past the pass, clear of the stations
		"senior": _staff_member("staff.luca", Vector3(-1.02, 0.0, 0.38), "luca")

func _staff_member(key: String, at: Vector3, who: String) -> void:
	if not Art.has_model("fp." + key): return
	var f := _prop(key, at, func(_r): pass)
	var to_you := Vector2(-at.x, -at.z)
	f.rotation.y = atan2(to_you.x, to_you.y)             # facing you
	staff.append({"node": f, "who": who, "face": f.rotation.y})

## the crew's idle life: they breathe, follow you with their eyes (the head turns toward the camera), Marco taps his
## rolling pin and waves you on while he is teaching; Luca works the prep counter
func _animate_staff(dt: float) -> void:
	var k := 1.0 - exp(-dt * 6.0)
	for e in staff:
		var f: Node3D = e.node
		var j := _joints(f)
		if j.is_empty(): continue
		var t: float = time + float(f.get_meta("ph"))
		var tg := {}
		for n in JOINTS: tg[n] = Vector3.ZERO
		# the head turns toward you (within reason) and nods now and then
		var to_cam: Vector3 = cam.global_position - f.global_position
		var yaw: float = wrapf(atan2(to_cam.x, to_cam.z) - f.rotation.y, -PI, PI)
		tg.neck = Vector3(-0.08 + 0.05 * sin(t * 0.7), clamp(yaw, -0.9, 0.9), 0.03 * sin(t * 0.5))
		if e.who == "marco":
			var teaching: bool = Tutor.running()
			tg.shoulder_r = Vector3(-0.35 - 0.12 * sin(t * 2.2), 0, -0.05)
			tg.elbow_r = Vector3(-0.9 - 0.25 * max(0.0, sin(t * 2.2)), 0, 0)          # tapping the pin
			tg.shoulder_l = Vector3(-0.15, 0, 0.08)
			if teaching:                                                               # waving you on
				tg.shoulder_l = Vector3(-1.9 + 0.25 * sin(t * 4.0), 0, 0.25)
				tg.elbow_l = Vector3(-0.5 + 0.3 * sin(t * 4.0), 0, 0)
				tg.neck.x += 0.08 * sin(t * 3.0)
		else:
			var w := sin(t * 3.4)
			tg.shoulder_l = Vector3(-0.6 + 0.12 * w, 0, 0.05)
			tg.shoulder_r = Vector3(-0.6 - 0.12 * w, 0, -0.05)
			tg.elbow_l = Vector3(-0.9, 0, 0)
			tg.elbow_r = Vector3(-0.9, 0, 0)
		for n in j: j[n].rotation = j[n].rotation.lerp(tg[n], k)
		f.position.y = 0.006 * sin(t * 1.6)                                           # breathing

# ---------- people moving ----------
const JOINTS := ["hip_l", "hip_r", "knee_l", "knee_r", "shoulder_l", "shoulder_r", "elbow_l", "elbow_r", "neck"]

## the joints of a figure (a model's hip_*, knee_*, shoulder_*, elbow_*, neck nodes), found once
func _joints(f: Node3D) -> Dictionary:
	if f.has_meta("joints"): return f.get_meta("joints")
	var j := {}
	for n in JOINTS:
		var node = f.find_child(n, true, false)
		if node != null: j[n] = node
	f.set_meta("joints", j)
	f.set_meta("ph", randf() * TAU)
	return j

## Each figure's pose, every frame, eased toward what it is doing: walking (legs and arms swing with its speed),
## sitting down at a table, ordering (nodding, a hand gesturing), waiting (looking about; arms folded and a foot
## tapping once they get impatient), eating (a hand to the mouth), or just standing and breathing.
func _animate(e: Dictionary, p: Dictionary, kind: String, dt: float) -> void:
	var k := 1.0 - exp(-dt * 10.0)
	var w: float = clamp(float(e.get("speed", 0.0)) / 0.9, 0.0, 1.0)
	var frac: float = clamp(p.pat / max(1.0, p.max), 0.0, 1.0)
	for i in e.figs.size():
		var f: Node3D = e.figs[i]
		var j := _joints(f)
		if j.is_empty(): continue
		var ph: float = f.get_meta("ph") + dt * (2.0 + 8.0 * w)
		f.set_meta("ph", ph)
		var t: float = time + i * 1.7
		var tg := {}
		for n in JOINTS: tg[n] = Vector3.ZERO
		if e.seated:
			tg.hip_l = Vector3(-PI / 2.0, 0, 0)
			tg.hip_r = Vector3(-PI / 2.0, 0, 0)
			tg.knee_l = Vector3(PI / 2.0, 0, 0)
			tg.knee_r = Vector3(PI / 2.0, 0, 0)
			if p.state == "eat":
				var bite: float = 0.5 + 0.5 * sin(t * 1.8)
				tg.shoulder_r = Vector3(-0.7 - 0.5 * bite, 0, 0)
				tg.elbow_r = Vector3(-0.5 - 1.3 * bite, 0, 0)
				tg.shoulder_l = Vector3(-0.75, 0, 0)
				tg.elbow_l = Vector3(-0.5, 0, 0)
				tg.neck = Vector3(0.15 * bite, 0, 0)
			else:
				tg.shoulder_l = Vector3(-0.7, 0, 0)
				tg.shoulder_r = Vector3(-0.7, 0, 0)
				tg.elbow_l = Vector3(-0.55, 0, 0)
				tg.elbow_r = Vector3(-0.55, 0, 0)
				tg.neck = Vector3(0.05 * sin(t * 0.7), 0.35 * sin(t * 0.4), 0)
		elif w > 0.08:
			var s := sin(ph)
			tg.hip_l = Vector3(-0.55 * s * w, 0, 0)
			tg.hip_r = Vector3(0.55 * s * w, 0, 0)
			tg.knee_l = Vector3((0.4 + 0.5 * sin(ph + 1.3)) * 0.9 * w, 0, 0)
			tg.knee_r = Vector3((0.4 - 0.5 * sin(ph + 1.3)) * 0.9 * w, 0, 0)
			tg.shoulder_l = Vector3(0.45 * s * w, 0, 0)
			tg.shoulder_r = Vector3(-0.45 * s * w, 0, 0)
			tg.elbow_l = Vector3(-0.35 * w, 0, 0)
			tg.elbow_r = Vector3(-0.35 * w, 0, 0)
		else:
			# standing: breathing, looking about
			var br := 0.04 * sin(t * 1.6)
			tg.shoulder_l = Vector3(br, 0, 0.04)
			tg.shoulder_r = Vector3(br, 0, -0.04)
			tg.elbow_l = Vector3(-0.15, 0, 0)
			tg.elbow_r = Vector3(-0.15, 0, 0)
			tg.neck = Vector3(0.03 * sin(t * 1.6), 0.3 * sin(t * 0.35 + i), 0)
			if kind != "" and frac > 0.45:
				# talking to you: nodding, one hand gesturing
				tg.neck = Vector3(0.14 * sin(t * 6.5), 0.1 * sin(t * 1.3), 0)
				tg.shoulder_r = Vector3(-0.55 - 0.25 * sin(t * 3.0), 0, 0)
				tg.elbow_r = Vector3(-0.9 - 0.3 * sin(t * 3.0 + 1.0), 0, 0)
			elif frac < 0.45 and p.state in ["wait", "queue", "door", "ask"]:
				# getting impatient: arms folded, a foot tapping, looking around for their food
				var tap: float = max(0.0, sin(t * 10.0))
				tg.shoulder_l = Vector3(-0.35, 0, 0.1)
				tg.shoulder_r = Vector3(-0.35, 0, -0.1)
				tg.elbow_l = Vector3(-1.4, -1.15, 0)          # forearms across the chest
				tg.elbow_r = Vector3(-1.4, 1.15, 0)
				tg.hip_l = Vector3(-0.12 * tap, 0, 0)
				tg.knee_l = Vector3(0.22 * tap, 0, 0)
				tg.neck = Vector3(-0.05, 0.55 * sin(t * 1.1), 0)
		for n in j:
			j[n].rotation = j[n].rotation.lerp(tg[n], k)
		# ease down into the seat (and back up)
		f.position.y = lerp(f.position.y, float(f.get_meta("seat_y", 0.0)), k)

func _sync_tables() -> void:
	for e in table_nodes:
		var tb: Dictionary = e.tb
		e.plates.visible = tb.party != null and tb.party.state in ["eat", "bill"]
		e.dirt.visible = tb.dirty
		# a table's name only when it needs you: dirty, or free while people wait at the door to be seated
		e.lbl.visible = tb.dirty or (svc != null and tb.party == null and svc.door.size() > 0)

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
			if Art.has_model("fp.pan"): root.get_child(0).scale.x = pw * 0.96 / 0.1
			var fill := _box(Vector3(pw * 0.84, 0.05, 0.17), Vector3(0, 0.0, 0), Color(Data.ING[id].col) if id != "" else Color("777777"), root)
			var ring := _box(Vector3(pw * 0.96, 0.005, 0.22), Vector3(0, 0.035, 0), Color(0.96, 0.78, 0.31), root)
			var nm: String = "" if id == "" else Data.ING[id].name
			# on a long rail every other name sits a step further forward, so each can be two pans wide
			var wide := 2.0 if per > 8 else 1.0
			var step := 0.06 if wide > 1.0 and col % 2 == 1 else 0.0
			var lb := _label(nm.left(14), Vector3(0, 0.05 - step * 0.4, 0.13 + step), 26, Color.WHITE, root, false, min(0.0011, pw * wide * 0.92 / (14.0 * 26.0 * 0.55)))
			lb.rotation_degrees.x = -55
			lb.outline_size = 6
			lb.no_depth_test = true                 # (shown only at the counter: never hidden behind the bin)
			_tappable(root, Vector3(pw * 0.95, 0.12, 0.24), Vector3.ZERO, {"kind": "pan", "i": i})
			pan_nodes.append({"root": root, "fill": fill, "ring": ring, "i": i, "lbl": lb})
	var at_bench := cur_view() == "bench"
	for e in pan_nodes:
		e.lbl.visible = at_bench                        # the pans' names only at the counter, where you pick from them
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
	_cyl(0.008, 0.26, Vector3(0, -0.13, 0), Color("c3c9cc"), r, 0.8)
	var bowl := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.025 + 0.006 * oz
	sp.height = sp.radius
	bowl.mesh = sp
	bowl.position = Vector3(0, -0.27, 0)
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
	# the sizes only matter while there is a pizza to sauce; then they are a constant size on screen, so they are never
	# huge when the rail is right beside you (at the board) and never in the way otherwise
	var want := svc != null and svc.bench != null
	for l in ladle_lbls:
		if is_instance_valid(l): l.visible = want
	var sizes := Data.LADLES.filter(func(oz): return Game.ladles(oz) > 0)
	var held: int = svc.ladle_oz if svc != null else 0
	var sig := ",".join(sizes.map(func(x): return str(x))) + "/" + str(held)
	if sig == ladle_sig: return
	ladle_sig = sig
	for c in ladle_root.get_children(): c.queue_free()
	ladle_lbls = []
	for i in sizes.size():
		var oz: int = sizes[i]
		var on: bool = oz == held
		var root := _prop("ladle.%d" % oz, Vector3(0.9 + i * 0.11, 1.3, -1.02), _mk_ladle.bind(oz), ladle_root)
		var ll := _label("%d oz" % oz, Vector3(0, 0.05, 0.01), 26, Color("f4c64f") if on else Color.WHITE, root, false, 0.0009)
		ll.fixed_size = true
		ll.outline_size = 6
		ll.visible = want
		ladle_lbls.append(ll)
		_tappable(root, Vector3(0.1, 0.36, 0.1), Vector3(0, -0.16, 0), {"kind": "ladle", "oz": oz})

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

func _sync_misc(_dt: float) -> void:
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
	# tickets hang high on the rail and the clock is high on the wall, so their marker points up from underneath
	# (above would be off the top of the view, or through the ceiling)
	var under: bool = marker_on.get_parent() == ticket_root or marker_on.global_position.y > 1.9
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
	# the right hand takes the shape of what it is doing
	var want := "open"
	if tool != "": want = "grip" if Data.ING[tool].kind == "sauce" else "pinch"
	elif grip_at != null: want = "grip"
	_pose(hands[0], want)
	for i in hands.size():
		var h: Dictionary = hands[i]
		var goal: Vector3 = h.rest
		if h.target != null: goal = cam.to_local(h.target) + Vector3(0.02 * (1 if i == 0 else -1), 0.02, 0.05)
		if i == 0 and grip_at != null: goal = cam.to_local(grip_at) + Vector3(0.0, 0.035, 0.07)      # round the peel's handle
		h.node.position = h.node.position.lerp(goal, 1.0 - exp(-dt * 14.0))

func _pose(h: Dictionary, want: String) -> void:
	if h.pose == want or not h.poses.has(want): return
	for k in h.poses: h.poses[k].visible = k == want
	h.pose = want

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
			t_yaw -= rel.x * k * look_speed()
			t_pitch = clamp(t_pitch - rel.y * k * look_speed() * look_flip(), -85.0, 40.0)

## the look stick let go: settle on a station if you are looking near one
func settle_look() -> void:
	_settle()

## the background: the kitchen's hum; a wood fire crackling (louder when you are at the oven); the dining room's
## murmur, with the customers in it (louder when you face them)
func _sound(dt: float) -> void:
	Art.loop("room", 0.16, dt)
	var fire := 0.0
	var ov: Oven = svc.oven if svc != null else fire_oven
	if ov != null and ov.def.feeds and (svc != null or (oven_door != null and not oven_door.visible)):
		fire = clamp(ov.power() / 1.3, 0.0, 1.0)
	Art.loop("fire", fire * (0.85 if cur_view() == "oven" else 0.3), dt)
	var crowd := 0.0
	if svc != null:
		var n := 0
		for p in svc.parties:
			if p.state != "leave" and p.get("pos", Vector2(-100, -100)).x > -50.0: n += int(p.n)
		crowd = clamp(n / 14.0, 0.0, 1.0)
	Art.loop("murmur", crowd * (0.6 if cur_view() == "front" else 0.3), dt)
	Art.loop("music", 0.0 if svc != null else 0.28, dt)        # quietly between services; in service, the room
## how fast the stick and a drag turn your head (Settings > Controls: Look speed)
func look_speed() -> float:
	return {"slow": 0.6, "normal": 1.0, "fast": 1.6}.get(String(Game.s.get("look_speed", "normal")), 1.0)

## -1 when up and down are swapped (Settings > Controls: Invert up and down)
func look_flip() -> float:
	return -1.0 if Game.s.get("invert_look", false) else 1.0

## the look stick tapped: look back at the station you are at
func recentre() -> void:
	_look_at(cur_view())

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
	if act.get("job", "") == "open":
		Art.sfx("punch")                  # the time card in the clock: ka-chunk
		Art.buzz(40)
		if svc != null:
			svc._ask_close()              # the clock in service: clock out early?
			return
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


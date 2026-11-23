class_name TitleScreen
extends Control
## The title screen. The owner's painting of the van (assets/ui/title.jpg) fills the screen and is brought to life:
## smoke and sparks rise from the oven's chimney, the fairy lights twinkle, the oven flickers and throws its glow on
## the cobbles, a shine runs across the sign now and then, and the whole picture drifts very slowly. Tap the sign for
## a puff from the chimney. The menu is a chalkboard: Continue, New game (the story or free play), Settings, and Quit
## on a computer. Swap the painting for another of the same framing and only the coordinates below need moving.

const ART := "res://assets/ui/title.jpg"
const ART_SIZE := Vector2(1024, 572)
# where things are in the painting, in its own pixels
const CHIMNEY := Vector2(817, 166)
const OVEN := Vector2(626, 266)
const BULBS := [Vector2(717, 232), Vector2(758, 272), Vector2(793, 281), Vector2(838, 280), Vector2(862, 275),
	Vector2(884, 255), Vector2(907, 251), Vector2(925, 236)]
const SIGN := [Vector2(560, 36), Vector2(785, 92), Vector2(777, 217), Vector2(555, 150)]
const POOL := Vector2(640, 410)          # the warm light the van throws on the cobbles

const CHALK := Color("f3efe4")
const CHALK_DIM := Color(0.95, 0.93, 0.88, 0.62)

var stage: Node2D
var t := 0.0
var intro := 0.0
var bulbs := []
var oven_glow: Sprite2D
var chimney_glow: Sprite2D
var pool: Sprite2D
var sparks: CPUParticles2D
var puff: CPUParticles2D
var shine_mat: ShaderMaterial
var shine_t := 3.0                       # seconds to the next shine across the sign
var shine_pos := -1.0
var board: PanelContainer
var list: VBoxContainer
var fade: ColorRect
var busy := false

func _ready() -> void:
	clip_contents = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_stage()
	_build_board()
	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.0, 0.9).set_trans(Tween.TRANS_SINE)
	show_page("main")

# ---------- the living picture ----------
func _build_stage() -> void:
	stage = Node2D.new()
	add_child(stage)
	var bg := Sprite2D.new()
	bg.texture = load(ART)
	bg.centered = false
	stage.add_child(bg)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var soft := _glow_tex(64)
	# the warm pool of light on the cobbles, breathing with the fire
	pool = _sprite(soft, POOL, Vector2(7.0, 3.6), Color(1.0, 0.66, 0.32, 0.1), add)
	# the oven's mouth and the chimney's opening flicker
	oven_glow = _sprite(soft, OVEN, Vector2(1.5, 1.3), Color(1.0, 0.5, 0.18, 0.4), add)
	chimney_glow = _sprite(soft, CHIMNEY + Vector2(0, 6), Vector2(1.3, 0.7), Color(1.0, 0.62, 0.25, 0.4), add)
	# smoke from the chimney: soft grey puffs rising, spreading and fading
	var smoke := CPUParticles2D.new()
	smoke.position = CHIMNEY
	smoke.texture = soft
	smoke.amount = 26
	smoke.lifetime = 5.0
	smoke.preprocess = 5.0
	smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	smoke.emission_rect_extents = Vector2(12, 3)
	smoke.direction = Vector2(0.12, -1)
	smoke.spread = 10.0
	smoke.initial_velocity_min = 20.0
	smoke.initial_velocity_max = 32.0
	smoke.gravity = Vector2(5, -4)
	smoke.angular_velocity_min = -20.0
	smoke.angular_velocity_max = 20.0
	smoke.scale_amount_min = 0.45
	smoke.scale_amount_max = 0.7
	smoke.scale_amount_curve = _curve([Vector2(0, 0.4), Vector2(1, 2.8)])
	smoke.color_ramp = _ramp([[0.0, Color(0.9, 0.86, 0.82, 0.0)], [0.15, Color(0.9, 0.86, 0.82, 0.3)], [1.0, Color(0.7, 0.7, 0.74, 0.0)]])
	stage.add_child(smoke)
	# sparks: from the chimney, and embers drifting up across the whole street
	sparks = _sparks(CHIMNEY, Vector2(10, 3), 16, 2.6, Vector2(0, -1), 28.0, 40.0, 75.0, add)
	var embers := _sparks(Vector2(512, 420), Vector2(520, 160), 14, 7.0, Vector2(0.2, -1), 40.0, 8.0, 18.0, add)
	embers.scale_amount_min = 0.05
	embers.scale_amount_max = 0.1
	puff = _sparks(CHIMNEY, Vector2(8, 2), 36, 1.8, Vector2(0, -1), 40.0, 60.0, 140.0, add)
	puff.emitting = false
	puff.one_shot = true
	puff.explosiveness = 0.85
	# the fairy lights along the awning
	for i in BULBS.size():
		var b := _sprite(soft, BULBS[i], Vector2(0.55, 0.55), Color(1.0, 0.84, 0.48, 0.6), add)
		bulbs.append({"node": b, "ph": randf() * TAU, "sp": randf_range(1.2, 2.4), "tw": 0.0})
	# the shine that runs across the sign
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array(SIGN)
	poly.uv = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	var white := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	white.fill(Color.WHITE)
	poly.texture = ImageTexture.create_from_image(white)
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
render_mode blend_add;
uniform float pos = -1.0;
void fragment() {
	float d = (UV.x + UV.y * 0.45) - pos;
	float band = exp(-d * d * 90.0) + 0.35 * exp(-(d + 0.12) * (d + 0.12) * 600.0);
	COLOR = vec4(1.0, 0.93, 0.78, band * 0.42);
}"""
	shine_mat = ShaderMaterial.new()
	shine_mat.shader = sh
	poly.material = shine_mat
	stage.add_child(poly)
	_layout()

func _sprite(tex: Texture2D, at: Vector2, sc: Vector2, col: Color, m: Material) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.position = at
	s.scale = sc
	s.modulate = col
	s.material = m
	stage.add_child(s)
	return s

func _sparks(at: Vector2, ext: Vector2, n: int, life: float, dir: Vector2, spread: float, v0: float, v1: float, m: Material) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = at
	p.texture = _glow_tex(32)
	p.material = m
	p.amount = n
	p.lifetime = life
	p.preprocess = life
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = ext
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = v0
	p.initial_velocity_max = v1
	p.gravity = Vector2(6, -8)
	p.damping_min = 4.0
	p.damping_max = 10.0
	p.scale_amount_min = 0.1
	p.scale_amount_max = 0.22
	p.color_ramp = _ramp([[0.0, Color(1.0, 0.85, 0.4, 0.0)], [0.1, Color(1.0, 0.75, 0.3, 1.0)], [0.7, Color(1.0, 0.45, 0.12, 0.7)], [1.0, Color(0.9, 0.3, 0.1, 0.0)]])
	stage.add_child(p)
	return p

func _glow_tex(px: int) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.5))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = px
	gt.height = px
	return gt

func _ramp(stops: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(stops.map(func(s): return s[0]))
	g.colors = PackedColorArray(stops.map(func(s): return s[1]))
	return g

func _curve(pts: Array) -> Curve:
	var c := Curve.new()
	c.max_value = 4.0
	for p in pts: c.add_point(p)
	return c

## the painting covers the screen, a little larger so it can drift; it eases in from a touch closer
func _layout() -> void:
	if stage == null: return
	var sz := size if size.x > 1.0 else get_viewport_rect().size
	var cover: float = max(sz.x / ART_SIZE.x, sz.y / ART_SIZE.y) * 1.05
	var k: float = cover * (1.0 + 0.07 * pow(1.0 - clamp(intro, 0.0, 1.0), 2.0))
	var drift := Vector2(sin(t * 0.11) * 9.0, sin(t * 0.083 + 1.3) * 6.0)
	stage.scale = Vector2(k, k)
	stage.position = (sz - ART_SIZE * k) / 2.0 + drift

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED: _layout()

func _process(dt: float) -> void:
	t += dt
	intro = min(1.0, intro + dt / 2.4)
	Art.loop("fire", 0.22 * intro, dt)            # the van's oven, crackling softly
	Art.loop("music", 0.5, dt)
	_layout()
	# the fire breathes: the oven, the chimney and the pool of light on the cobbles together
	var fl := 0.75 + 0.14 * sin(t * 7.3) + 0.08 * sin(t * 13.1 + 1.0) + 0.05 * sin(t * 23.0 + 2.0)
	oven_glow.modulate.a = 0.42 * fl
	chimney_glow.modulate.a = 0.4 * fl
	pool.modulate.a = 0.08 + 0.025 * fl
	for b in bulbs:
		b.tw = max(0.0, b.tw - dt * 2.5)
		if randf() < dt * 0.08: b.tw = 1.0                # now and then one twinkles
		var a: float = 0.5 + 0.18 * sin(t * b.sp + b.ph) + 0.35 * b.tw
		b.node.modulate.a = a
		b.node.scale = Vector2.ONE * (0.5 + 0.12 * b.tw)
	# a shine across the sign every few seconds
	shine_t -= dt
	if shine_t <= 0.0:
		shine_t = randf_range(5.0, 8.0)
		shine_pos = -0.6
	if shine_pos < 2.0:
		shine_pos += dt * 1.7
		shine_mat.set_shader_parameter("pos", shine_pos)

func _gui_input(e: InputEvent) -> void:
	var press: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed)
	if not press: return
	var p: Vector2 = (e.position - stage.position) / stage.scale.x
	if Geometry2D.is_point_in_polygon(p, PackedVector2Array(SIGN)) or p.distance_to(CHIMNEY) < 40.0:
		shine_pos = -0.6
		shine_t = randf_range(5.0, 8.0)
		puff.restart()
		for b in bulbs: b.tw = randf_range(0.6, 1.0)

# ---------- the chalkboard menu ----------
func _build_board() -> void:
	board = PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color("26302b")
	st.border_color = Color("8a5a32")
	st.set_border_width_all(12)
	st.set_corner_radius_all(10)
	st.shadow_color = Color(0, 0, 0, 0.45)
	st.shadow_size = 18
	st.shadow_offset = Vector2(6, 8)
	st.content_margin_left = 34
	st.content_margin_right = 34
	st.content_margin_top = 26
	st.content_margin_bottom = 30
	board.add_theme_stylebox_override("panel", st)
	board.custom_minimum_size = Vector2(380, 0)
	add_child(board)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	board.add_child(list)
	board.resized.connect(_place_board)
	resized.connect(_place_board)
	board.draw.connect(_smudges)

## faint smudges of old chalk on the board, where earlier specials were wiped off
func _smudges() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 7:
		var c := Vector2(rng.randf_range(30, board.size.x - 30), rng.randf_range(30, board.size.y - 30))
		var r := rng.randf_range(30, 80)
		board.draw_set_transform(c, rng.randf_range(-0.5, 0.5), Vector2(1.0, rng.randf_range(0.35, 0.6)))
		board.draw_circle(Vector2.ZERO, r, Color(1, 1, 1, 0.025))
		board.draw_circle(Vector2.ZERO, r * 0.6, Color(1, 1, 1, 0.02))
	board.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

var board_slide := 0.0

func _place_board() -> void:
	board.size = Vector2(board.custom_minimum_size.x, 0)
	board.reset_size()
	var x := 56.0
	board.position = Vector2(x + board_slide, (size.y - board.size.y) / 2.0 + 24.0)

## fill the board with one page of chalk writing and slide it in
func show_page(p: String) -> void:
	Kit.clear(list)
	match p:
		"main":
			_heading("Today's specials")
			if not Game.s.get("fresh", false):
				_chalk("Continue", _go_continue, _continue_note())
			_chalk("New game", func(): show_page("new"), "")
			_chalk("Settings", func(): show_page("settings"), "")
			if OS.has_feature("pc"): _chalk("Quit", func(): get_tree().quit(), "")
		"new":
			_heading("New game")
			_chalk("Story", func(): _new_game(true), "Start as a pizzaiolo at %s. Learn the job, get promoted, then go it alone with your own van." % Story.EMPLOYER)
			_chalk("Free play", func(): _new_game(false), "Skip the job: your own pizza van from day one, doing everything yourself.")
			_chalk("Back", func(): show_page("main"), "", true)
		"controls":
			_heading("Controls")
			var G := Game
			_chalk("Look speed: " + String(G.s.get("look_speed", "normal")).capitalize(), func():
				Game.s.look_speed = {"slow": "normal", "normal": "fast", "fast": "slow"}[String(Game.s.get("look_speed", "normal"))]
				Game.save_game()
				show_page("controls"), "", false, 28)
			_chalk("Invert up and down: " + ("on" if G.s.get("invert_look", false) else "off"), func(): _ctl_toggle("invert_look", false), "", false, 28)
			_chalk("Look stick on the " + ("right" if G.s.get("stick_right", false) else "left"), func(): _ctl_toggle("stick_right", false), "", false, 28)
			_chalk("Bigger buttons: " + ("on" if G.s.get("big_controls", false) else "off"), func(): _ctl_toggle("big_controls", false), "", false, 28)
			_chalk("Look by turning the phone: " + ("on" if G.s.get("gyro", true) else "off"), func(): _ctl_toggle("gyro", true), "", false, 28)
			_chalk("Back", func(): show_page("settings"), "", true)
		"settings":
			_heading("Settings")
			var G := Game
			_chalk("Kitchen in 3D: " + ("on" if G.s.get("view3d", true) else "off"), func(): _toggle("view3d", true), "", false, 28)
			_chalk("Retro look: " + ("on" if G.s.get("retro", false) else "off"), func(): _toggle("retro", false), "", false, 28)
			_chalk("Sound: " + ("off" if G.s.get("mute", false) else "on"), func(): _toggle("mute", false), "", false, 28)
			_chalk("Music: " + ("on" if G.s.get("music", true) else "off"), func(): _toggle("music", true), "", false, 28)
			_chalk("Vibration: " + ("on" if G.s.get("vibrate", true) else "off"), func(): _toggle("vibrate", true), "", false, 28)
			_chalk("Graphics: " + String(G.s.get("quality", "high")).capitalize(), func():
				Game.s.quality = {"high": "medium", "medium": "low", "low": "high"}[String(Game.s.get("quality", "high"))]
				Game.save_game()
				show_page("settings"), "", false, 28)
			_chalk("Show performance: " + ("on" if G.s.get("perf", false) else "off"), func(): _toggle("perf", false), "", false, 28)
			_chalk("Controls...", func(): show_page("controls"), "", false, 28)
			_chalk("Back", func(): show_page("main"), "", true)
	# slide the board in from the left, the lines following one after another
	board_slide = -40.0
	board.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "board_slide", 0.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(board, "modulate:a", 1.0, 0.3)
	tw.tween_method(func(_v): _place_board(), 0.0, 1.0, 0.46)
	var i := 0
	for c in list.get_children():
		c.modulate.a = 0.0
		var t2 := create_tween()
		t2.tween_interval(0.12 + 0.07 * i)
		t2.tween_property(c, "modulate:a", 1.0, 0.25)
		i += 1
	call_deferred("_place_board")

func _continue_note() -> String:
	var G := Game
	var place: String = Data.VENUES[int(G.s.get("venue", 0))].name if Data.VENUES.size() > int(G.s.get("venue", 0)) else ""
	return "Day %d%s · %s" % [int(G.s.day), (" · " + place) if place != "" else "", Kit.money(float(G.s.cash))]

func _heading(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color("f4c64f"))
	list.add_child(l)
	var line := ChalkLine.new()
	line.custom_minimum_size = Vector2(0, 10)
	list.add_child(line)

func _chalk(text: String, cb: Callable, note: String, small: bool = false, px: int = 34) -> void:
	var b := ChalkButton.new()
	b.text = text
	b.cb = cb
	b.add_theme_font_size_override("font_size", 26 if small else px)
	b.tilt = randf_range(-1.6, 1.6)
	b.pressed.connect(func(): _press(b))
	list.add_child(b)
	if note != "":
		var l := Label.new()
		l.text = note
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(310, 0)
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_color", CHALK_DIM)
		list.add_child(l)

func _press(b: ChalkButton) -> void:
	if busy: return
	# a squash, a puff of chalk dust, then do it
	var dust := CPUParticles2D.new()
	dust.position = Vector2(b.size.x * 0.25, b.size.y * 0.6)
	dust.amount = 18
	dust.lifetime = 0.7
	dust.one_shot = true
	dust.explosiveness = 0.9
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(b.size.x * 0.25, 6)
	dust.direction = Vector2(0, -1)
	dust.spread = 70.0
	dust.initial_velocity_min = 30.0
	dust.initial_velocity_max = 90.0
	dust.gravity = Vector2(0, 160)
	dust.scale_amount_min = 1.5
	dust.scale_amount_max = 3.0
	dust.color_ramp = _ramp([[0.0, Color(1, 1, 1, 0.8)], [1.0, Color(1, 1, 1, 0.0)]])
	b.add_child(dust)
	dust.emitting = true
	var tw := create_tween()
	tw.tween_property(b, "squash", 0.9, 0.06)
	tw.tween_property(b, "squash", 1.0, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(b.cb)

func _ctl_toggle(key: String, def: bool) -> void:
	Game.s[key] = not Game.s.get(key, def)
	Game.save_game()
	show_page("controls")

func _toggle(key: String, def: bool) -> void:
	Game.s[key] = not Game.s.get(key, def)
	Game.save_game()
	show_page("settings")

func _go_continue() -> void:
	_leave(func(): Kit.main.show_hub())

func _new_game(story: bool) -> void:
	var go := func():
		_leave(func():
			if story: Story.start()
			else: Game.new_game()
			Kit.main.show_hub("home"))
	if Game.s.get("fresh", false): go.call()
	else: Kit.main.confirm("Start a new game?", "This replaces your saved game (day %d, %s)." % [int(Game.s.day), Kit.money(float(Game.s.cash))], "Start again", go)

## fade to black, then go
func _leave(then: Callable) -> void:
	busy = true
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.35)
	tw.tween_callback(then)

# ---------- chalk ----------
## a menu line written in chalk: it leans a little, grows when you point at it, and gets a scribbled underline
class ChalkButton extends Button:
	var cb: Callable
	var tilt := 0.0
	var hk := 0.0
	var squash := 1.0
	var seed := randi()

	func _ready() -> void:
		flat = true
		alignment = HORIZONTAL_ALIGNMENT_LEFT
		focus_mode = Control.FOCUS_ALL
		var empty := StyleBoxEmpty.new()
		for s in ["normal", "hover", "pressed", "focus", "disabled"]: add_theme_stylebox_override(s, empty)
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			add_theme_color_override(c, Color("f3efe4"))
		add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.25))
		add_theme_constant_override("outline_size", 2)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		rotation_degrees = tilt

	func _process(dt: float) -> void:
		var want := 1.0 if (is_hovered() or has_focus()) else 0.0
		hk = move_toward(hk, want, dt * 5.0)
		pivot_offset = Vector2(0, size.y / 2.0)
		scale = Vector2.ONE * (1.0 + 0.06 * hk) * squash
		modulate = Color(1, 1, 1, 0.86 + 0.14 * hk)
		queue_redraw()

	func _draw() -> void:
		if hk <= 0.01: return
		var font := get_theme_font("font")
		var fs := get_theme_font_size("font_size")
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * hk
		var y := size.y - 6.0
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var pts := PackedVector2Array()
		var n := 14
		for i in n + 1:
			var x := w * float(i) / n
			pts.append(Vector2(x, y + rng.randf_range(-1.6, 1.6) - 2.0 * sin(float(i) / n * PI)))
		draw_polyline(pts, Color(0.96, 0.94, 0.88, 0.75), 3.0, true)

## a hand-drawn chalk rule under a heading
class ChalkLine extends Control:
	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var pts := PackedVector2Array()
		for i in 21:
			pts.append(Vector2(size.x * i / 20.0, size.y / 2.0 + rng.randf_range(-1.2, 1.2)))
		draw_polyline(pts, Color(0.95, 0.93, 0.88, 0.45), 2.0, true)

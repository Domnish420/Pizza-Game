class_name VRView
extends CanvasLayer
## Phone VR: the phone in a Cardboard-style viewer (Settings > Controls > VR viewer). The kitchen is drawn twice, once
## for each eye, side by side, each bent for the viewer's lens (shaders/lens.gdshader). Your head is the phone: its
## sensors (Godot's phone VR tracking, XRServer) turn your head straight away, with no smoothing (a lag in VR makes
## people feel sick), tilting included. The game's screens (the top bar, the recipe card, dialogs, Marco's guide) are
## drawn on a panel that floats in front of you at eye level and drifts round when you look well away; look down to
## work. A dot shows where you are looking on the panel: the viewer's button (a tap on the screen) or A clicks what is
## there, so every menu works from inside the headset. Your hands are a game controller's sticks and triggers
## (FPWorld._pad); without one, the viewer's button looking through the panel is your right hand at the middle of
## your view. Start looks at your station again; Back (or holding a finger on the screen for two seconds) leaves VR.
##
## Godot's own phone VR drawing (MobileVRInterface on the window) skips the lens correction and the 2D screens with the
## Compatibility renderer, so the eyes are drawn here instead; only its head tracking is used.

const IPD := 0.064              # metres between your eyes
const FOV := 92.0               # each eye's view, top to bottom (degrees)
const PANEL_DIST := 1.25        # the game's screen floats this far in front of you (metres)
const PANEL_W := 1.7            # and is this wide

static var active := false      # a VR viewer is on: the kitchen follows the headset (FPWorld reads this)
static var head_test = null     # tests: a Basis standing in for the phone's sensors

var ui_vp: SubViewport          # the game's screens, drawn for the panel
var eyes: Array = []            # each eye: its viewport, its camera, its picture on the screen
var void_root: Node3D           # a quiet dark room for the screens that are not the kitchen (the title, the hub)
var panel: MeshInstance3D
var panel_yaw := 0.0
var panel_pitch := 0.0
var panel_follow := false
var cursor: MeshInstance3D      # where you are looking on the panel
var gaze_px = null              # and that point in the game's screens (pixels), or null when you look past the panel
var base_t := Transform3D()     # where your eyes are this frame
var moved: Array = []           # what was moved into ui_vp, to put back
var hidden_views: Array = []    # the flat 3D views (and the look stick) switched off while the eyes draw the kitchen
var hold_t := 0.0               # how long a finger has been on the screen (two seconds leaves VR)
var holding := false
var gaze_click_down := false    # the viewer's button went down on the panel (its release belongs there too)

## where the headset is looking (the phone's sensors, or the tests' stand-in)
static func head_basis() -> Basis:
	if head_test != null: return head_test
	return XRServer.get_hmd_transform().basis

func _ready() -> void:
	layer = 80
	active = true
	var xr := XRServer.find_interface("Native mobile")
	if xr != null and not xr.is_initialized(): xr.initialize()
	var size := get_viewport().get_visible_rect().size
	# the game's screens and dialogs, drawn into a picture for the panel
	ui_vp = SubViewport.new()
	ui_vp.transparent_bg = true
	ui_vp.size = Vector2i(size)
	ui_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(ui_vp)
	for n in [Kit.main.content, Kit.main.modal_root, Kit.main.toast_box]:
		n.reparent(ui_vp, false)
		moved.append(n)
	for l in _layers(): l.custom_viewport = ui_vp
	# the quiet room
	var vv := SubViewport.new()
	vv.own_world_3d = true
	vv.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vv)
	void_root = Node3D.new()
	vv.add_child(void_root)
	var we := WorldEnvironment.new()
	we.environment = Environment.new()
	we.environment.background_mode = Environment.BG_COLOR
	we.environment.background_color = Kit.BG
	void_root.add_child(we)
	# the two eyes, side by side, each bent for its lens
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	for i in 2:
		var vp := SubViewport.new()
		vp.size = Vector2i(int(size.x / 2.0), int(size.y))
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.msaa_3d = Viewport.MSAA_2X
		add_child(vp)
		var cam := Camera3D.new()
		cam.fov = FOV
		cam.near = 0.03
		cam.far = 80.0
		vp.add_child(cam)
		cam.current = true
		var r := TextureRect.new()
		r.texture = vp.get_texture()
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_SCALE
		r.position = Vector2(size.x / 2.0 * i, 0.0)
		r.size = Vector2(size.x / 2.0, size.y)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/lens.gdshader")
		m.set_shader_parameter("aspect", size.x / 2.0 / size.y)
		r.material = m
		add_child(r)
		eyes.append({"vp": vp, "cam": cam, "rect": r})

## the other layers drawn over the game (Marco's guide, the performance numbers): onto the panel with the rest
func _layers() -> Array:
	var out: Array = Kit.main.find_children("*", "PerfOverlay", true, false)
	var tutor := get_node_or_null("/root/Tutor")
	if tutor is CanvasLayer: out.append(tutor)
	return out

## put everything back the way it was (before this is freed)
func close() -> void:
	active = false
	set_process(false)                          # (it is freed at the end of the frame: do nothing more till then)
	set_process_input(false)
	for n in moved:
		if is_instance_valid(n): n.reparent(Kit.main, false)
	moved.clear()
	for l in _layers(): l.custom_viewport = Kit.main.get_viewport()
	for v in hidden_views:
		if is_instance_valid(v): v.visible = true
	hidden_views.clear()
	if panel != null and is_instance_valid(panel): panel.queue_free()

## the kitchen on screen (the 3D kitchen between services, or service in 3D), if there is one
func world() -> FPWorld:
	var s = Kit.main.screen()
	if s == null: return null
	var w = s.get("world")
	if w == null and s.get("fp") != null: w = s.fp.world
	return w if w is FPWorld and is_instance_valid(w) and w.is_inside_tree() else null

func _process(dt: float) -> void:
	var w: FPWorld = world()
	if w != null:
		var fpv := w.get_parent().get_parent() as Control      # FPWorld -> its SubViewport -> FPView
		if fpv != null and fpv.visible:
			fpv.visible = false                                 # the eyes draw the kitchen now
			hidden_views.append(fpv)
		for stk in Kit.main.content.find_children("*", "LookStick", true, false):
			if stk.visible:
				stk.visible = false                             # your head looks round: no stick on the panel
				hidden_views.append(stk)
	var host: Node3D = w if w != null else void_root
	var w3d := host.get_world_3d()
	for e in eyes:
		if e.vp.world_3d != w3d: e.vp.world_3d = w3d
	var base: Transform3D = w.cam.global_transform if w != null else Transform3D(head_basis(), Vector3(0, 1.6, 0))
	base_t = base
	for i in eyes.size():
		eyes[i].cam.global_transform = base.translated_local(Vector3((float(i) - 0.5) * IPD, 0.0, 0.0))
	_panel(host, base, dt)
	_gaze(host, base)
	if holding:
		hold_t += dt
		if hold_t > 2.0:
			holding = false
			leave()

## the game's screen on a panel in front of you, at eye level: it stays put while you look round it, and drifts round
## to where you look once you look well away. A dialog comes to where you are looking (down at the bench, say), and so
## do the menus away from the kitchen (the title, the hub).
func _panel(host: Node3D, base: Transform3D, dt: float) -> void:
	var hy := _yaw_of(base)
	var f := -base.basis.z
	var hp := atan2(f.y, Vector2(f.x, f.z).length())
	var dialog: bool = Kit.main.modal_root.visible or host == void_root      # a dialog, or a menu: in front of you
	if panel == null or not is_instance_valid(panel) or panel.get_parent() != host:
		if panel != null and is_instance_valid(panel): panel.queue_free()
		panel = MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(PANEL_W, PANEL_W * float(ui_vp.size.y) / float(ui_vp.size.x))
		panel.mesh = q
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.no_depth_test = true                 # the counter and your hands never hide it
		m.render_priority = 10
		m.albedo_texture = ui_vp.get_texture()
		panel.material_override = m
		panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		host.add_child(panel)
		panel_yaw = hy
	# it comes round once you look well away (in a dialog or a menu, also up or down), then stays put while you look
	# round it, so you can aim at its buttons
	var want_p: float = hp if dialog else 0.0
	var off := Vector2(angle_difference(panel_yaw, hy), want_p - panel_pitch).length()
	if off > deg_to_rad(40.0 if dialog else 32.0): panel_follow = true       # (the panel itself is about 34 degrees each side)
	elif off < deg_to_rad(3.0): panel_follow = false
	if panel_follow:
		var k := 1.0 - exp(-dt * (7.0 if dialog else 3.0))
		panel_yaw = lerp_angle(panel_yaw, hy, k)
		panel_pitch = lerp(panel_pitch, want_p, k)
	var b := Basis.from_euler(Vector3(panel_pitch, panel_yaw, 0.0))
	panel.global_transform = Transform3D(b, base.origin + b * Vector3(0.0, -0.06, -PANEL_DIST))

## where you are looking on the panel: a dot there, and the point in the game's screens
func _gaze(host: Node3D, base: Transform3D) -> void:
	if cursor == null or not is_instance_valid(cursor) or cursor.get_parent() != host:
		if cursor != null and is_instance_valid(cursor): cursor.queue_free()
		cursor = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.008
		sm.height = 0.016
		cursor.mesh = sm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.no_depth_test = true
		m.render_priority = 11
		m.albedo_color = Kit.CHEESE
		cursor.material_override = m
		host.add_child(cursor)
	gaze_px = null
	cursor.visible = false
	var pt := panel.global_transform
	var d := -base.basis.z
	var n := pt.basis.z
	var den := n.dot(d)
	if absf(den) < 0.0001: return
	var t := n.dot(pt.origin - base.origin) / den
	if t <= 0.0: return
	var hit := base.origin + d * t
	var local := pt.affine_inverse() * hit
	var q: Vector2 = panel.mesh.size
	var uv := Vector2(local.x / q.x + 0.5, 0.5 - local.y / q.y)
	if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0: return
	gaze_px = uv * Vector2(ui_vp.size)
	cursor.global_position = hit
	cursor.visible = true

## the button you are looking at on the panel (in a dialog, only the dialog's), or null
func button_at(px: Vector2) -> BaseButton:
	var roots: Array = [Kit.main.modal_center] if Kit.main.modal_root.visible else [Kit.main.content, get_node_or_null("/root/Tutor")]
	var found: BaseButton = null
	for r in roots:
		if r == null: continue
		for b in r.find_children("*", "BaseButton", true, false):
			if b.is_visible_in_tree() and not b.disabled and b.get_global_rect().has_point(px): found = b
	return found

## click the button you are looking at on the panel: true if there was one
func click_gaze() -> bool:
	if gaze_px == null: return false
	var px: Vector2 = gaze_px
	if button_at(px) == null: return false
	var mm := InputEventMouseMotion.new()
	mm.position = px
	mm.global_position = px
	ui_vp.push_input(mm)
	for down in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = down
		mb.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		mb.position = px
		mb.global_position = px
		ui_vp.push_input(mb)
	Art.buzz(6)
	return true

## the way a view faces, round the room (radians)
func _yaw_of(t: Transform3D) -> float:
	var f := -t.basis.z
	return atan2(-f.x, -f.z)

func _input(e: InputEvent) -> void:
	# a controller's buttons work the game's screens on the panel (A presses the focused button)
	if e is InputEventJoypadButton or e is InputEventJoypadMotion or e is InputEventKey:
		if e is InputEventJoypadButton and e.pressed and e.button_index == JOY_BUTTON_BACK:
			leave()
			return
		# A clicks what you look at on the panel (in a dialog, A presses the button with the gold ring)
		if e is InputEventJoypadButton and e.button_index == JOY_BUTTON_A and not Kit.main.modal_root.visible:
			if e.pressed: click_gaze()
			return
		ui_vp.push_input(e)
	elif e is InputEventScreenTouch:
		# the viewer's button taps the screen: it clicks what you look at on the panel; in a dialog looking elsewhere,
		# it presses the main button; otherwise it is your right hand at the middle of your view. Holding a finger
		# down for two seconds leaves VR.
		holding = e.pressed
		hold_t = 0.0
		if e.pressed and click_gaze():
			gaze_click_down = true
			return
		if not e.pressed and gaze_click_down:
			gaze_click_down = false
			return
		if Kit.main.modal_root.visible:
			if e.pressed: _press_dialog()
			return
		var w: FPWorld = world()
		if w != null: w.gaze_press(e.pressed)

## press the dialog's focused button (or its main one)
func _press_dialog() -> void:
	var f := ui_vp.gui_get_focus_owner()
	if f is BaseButton:
		f.pressed.emit()
		return
	var bs: Array = Kit.main.modal_center.find_children("*", "Button", true, false)
	if not bs.is_empty(): bs[-1].pressed.emit()

## take the phone out of the viewer: the game on the screen again
func leave() -> void:
	Game.s.vr = false
	Game.save_game()
	Kit.main.set_vr(false)

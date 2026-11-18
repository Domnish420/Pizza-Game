class_name FPSurface
extends MeshInstance3D
## A working surface in the 3D kitchen: the marble bench, the cutting board, the mouth of the oven, the prep tablet.
## Each one shows one of the game's 2D station controls (Bench, OvenView, the prep list) rendered into a texture on a
## flat quad, so every hands-on mechanic (two-finger stretching, the ladle, sliding pizzas in the oven, slicing)
## works unchanged. Touches are projected from the camera onto the quad and fed into the control as if it were the
## screen: a finger on the dough in 3D is a finger on the dough in the Bench control.
##
## A model can replace the quad's look (a real marble slab, a modelled oven mouth) as long as the surface
## keeps mapping touches to the same place: see `to_px()`.

var station := ""           # which station this belongs to (front, bench, board, oven, prep)
var vp: SubViewport
var control: Control
var quad_size := Vector2.ONE
var touch_events := true    # the control reads touch events (Bench); false = it reads mouse events (oven, buttons)
var body: StaticBody3D

func setup(st: String, ctrl: Control, px: Vector2i, size_m: Vector2, touch: bool, lit: bool = false) -> void:
	station = st
	control = ctrl
	quad_size = size_m
	touch_events = touch
	vp = SubViewport.new()
	vp.size = px
	vp.transparent_bg = false
	vp.handle_input_locally = true
	vp.gui_disable_input = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	vp.add_child(ctrl)
	_fit()
	var q := QuadMesh.new()
	q.size = size_m
	mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = vp.get_texture()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL if lit else BaseMaterial3D.SHADING_MODE_UNSHADED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	material_override = m
	body = StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(size_m.x, size_m.y, 0.02)
	cs.shape = bx
	body.add_child(cs)
	body.set_meta("act", {"kind": "surface", "surface": self})
	add_child(body)

## see-through: only what the control draws shows, on top of what is behind it in the room (the 3D pizza). With
## on_top false it stays in the room (hidden by what stands in front of it): the oven deck, seen through the mouth.
func overlay(on_top: bool = true) -> void:
	vp.transparent_bg = true
	var m: StandardMaterial3D = material_override
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = on_top
	m.render_priority = 2 if on_top else 1
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

## the control fills the texture exactly (its own anchors would size it to the window)
func _fit() -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = Vector2.ZERO
	control.size = Vector2(vp.size)

func _process(_dt: float) -> void:
	if control != null and control.size != Vector2(vp.size): _fit()

## where a camera ray meets this surface's plane, in the control's pixels (or null if it misses the plane)
func to_px(from: Vector3, dir: Vector3):
	var n: Vector3 = global_transform.basis.z.normalized()
	var o: Vector3 = global_transform.origin
	var den := n.dot(dir)
	if abs(den) < 0.0001: return null
	var t := n.dot(o - from) / den
	if t < 0.0: return null
	var local := to_local(from + dir * t)
	var u := local.x / quad_size.x + 0.5
	var v := 0.5 - local.y / quad_size.y
	return Vector2(u * vp.size.x, v * vp.size.y)

## the 3D point on the surface for a pixel of its control (for the hands)
func from_px(px: Vector2) -> Vector3:
	var u := px.x / vp.size.x - 0.5
	var v := 0.5 - px.y / vp.size.y
	return to_global(Vector3(u * quad_size.x, v * quad_size.y, 0.0))

## pass a finger (index >= 0) or the mouse (index -1) on to the control
func press(index: int, px: Vector2, down: bool) -> void:
	if touch_events and index >= 0:
		var e := InputEventScreenTouch.new()
		e.index = index
		e.position = px
		e.pressed = down
		vp.push_input(e, true)
	if not touch_events or index < 0:
		if index > 0: return            # mouse-driven controls only follow the first finger
		var m := InputEventMouseButton.new()
		m.button_index = MOUSE_BUTTON_LEFT
		m.pressed = down
		m.position = px
		m.global_position = px
		m.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		vp.push_input(m, true)

func drag(index: int, px: Vector2, rel: Vector2) -> void:
	if touch_events and index >= 0:
		var e := InputEventScreenDrag.new()
		e.index = index
		e.position = px
		e.relative = rel
		vp.push_input(e, true)
	if not touch_events or index < 0:
		if index > 0: return
		var m := InputEventMouseMotion.new()
		m.position = px
		m.global_position = px
		m.relative = rel
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		vp.push_input(m, true)

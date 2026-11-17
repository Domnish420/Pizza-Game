class_name FPView
extends SubViewportContainer
## The 3D first-person view of service: a SubViewport holding the kitchen world (FPWorld), stretched to fill the
## screen behind the HUD. Touches on it go through to the world, which works out what you touched in 3D.

var vp: SubViewport
var world: FPWorld

func _init(svc: ServiceScreen, ctrls: Dictionary) -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.handle_input_locally = true
	vp.msaa_3d = Viewport.MSAA_2X
	add_child(vp)
	world = FPWorld.new(svc, ctrls)
	vp.add_child(world)

var dbg_gui := 0
var dbg_unh := 0
func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch or e is InputEventScreenDrag: dbg_gui += 1

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch or e is InputEventScreenDrag: dbg_unh += 1

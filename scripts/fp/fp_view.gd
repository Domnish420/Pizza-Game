class_name FPView
extends SubViewportContainer
## The 3D first-person view of service: a SubViewport holding the kitchen world (FPWorld), stretched to fill the
## screen behind the HUD. Touches on it go through to the world, which works out what you touched in 3D.

var vp: SubViewport
var world: FPWorld

func _init(svc: ServiceScreen, ctrls: Dictionary, host = null) -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.handle_input_locally = true
	vp.msaa_3d = Viewport.MSAA_2X
	add_child(vp)
	world = FPWorld.new(svc, ctrls, host)
	vp.add_child(world)
	if Game.s.get("retro", false):
		# the Retro look: half resolution, no smoothing of edges, dithered colour, lighting per corner (set by the world)
		vp.scaling_3d_scale = 0.5
		vp.msaa_3d = Viewport.MSAA_DISABLED
		var sm := ShaderMaterial.new()
		sm.shader = load("res://shaders/retro.gdshader")
		material = sm

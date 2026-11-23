class_name PerfOverlay
extends CanvasLayer
## What the phone is doing, in a corner: frames a second, how long a frame takes, draw calls and triangles this frame,
## and video memory. On when "Show performance" is on in Settings: for testing on real phones, so we know the real
## budget (see DESIGN.md, "Phone budget"). Updates twice a second.

var label: Label
var acc := 0.0
var worst := 0.0                      # the slowest frame since the last update (a stutter shows here)

func _ready() -> void:
	layer = 50
	label = Label.new()
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 5)
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	label.offset_left = -330
	label.offset_top = -40
	label.offset_right = -8
	label.offset_bottom = -6
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

func _process(dt: float) -> void:
	visible = Game.s.get("perf", false)
	worst = maxf(worst, dt)
	acc += dt
	if acc < 0.5 or not visible: return
	acc = 0.0
	label.text = text()
	worst = 0.0

## the line it shows (the tests read it too)
func text() -> String:
	var RS := RenderingServer
	var draws := RS.get_rendering_info(RS.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var tris := RS.get_rendering_info(RS.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var mem := RS.get_rendering_info(RS.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0
	return "%d fps · worst %.0f ms · %d draws · %dk triangles · %d MB" % [Engine.get_frames_per_second(), worst * 1000.0, draws, roundi(tris / 1000.0), mem]

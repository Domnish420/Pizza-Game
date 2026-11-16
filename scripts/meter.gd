class_name Meter
extends Control
## A horizontal gauge with a marked target zone. value, zone_from and zone_to are 0..1 of the bar's width.

var value := 0.0
var zone_from := 0.6
var zone_to := 0.7
var marker := false   # draw value as a thin moving marker instead of a fill

func _init(from: float = 0.6, to: float = 0.7, h: int = 26) -> void:
	zone_from = from
	zone_to = to
	custom_minimum_size = Vector2(120, h)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

func set_value(v: float) -> void:
	value = clamp(v, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Kit.BG)
	if marker:
		draw_rect(Rect2(zone_from * size.x, 0, (zone_to - zone_from) * size.x, size.y), Color(Kit.BASIL, 0.6))
		draw_rect(Rect2(value * size.x - 3, 0, 6, size.y), Kit.CHEESE)
	else:
		draw_rect(Rect2(0, 0, value * size.x, size.y), Kit.CHEESE)
		draw_rect(Rect2(zone_from * size.x, 0, (zone_to - zone_from) * size.x, size.y), Color(Kit.BASIL, 0.5))
		draw_rect(Rect2(zone_from * size.x, 0, 2, size.y), Kit.BASIL)
		draw_rect(Rect2(zone_to * size.x - 2, 0, 2, size.y), Kit.BASIL)

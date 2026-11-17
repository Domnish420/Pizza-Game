class_name RailView
extends Control
## The chilled rail of gastronorm pans along the back of the pizza counter, seen from the front, above the marble.
## Each pan shows what is in it and how full it is. Tap a pan to pick up that topping (or refill it when empty).
## Art keys: "rail" (the rail and glass sneeze guard), "pan" (an empty gastro pan), "fill.<ingredient id>" (the food in a pan).

var svc
var font: Font

func _init(service) -> void:
	svc = service
	custom_minimum_size = Vector2(0, 78)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	font = ThemeDB.fallback_font

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var n: int = Stock.rail().size()
		if n == 0: return
		var i := int(clamp(e.position.x / (size.x / n), 0, n - 1))
		if not svc.busy.is_empty():
			svc.is_free()
			return
		svc.rail_tap(i)
		accept_event()

func _draw() -> void:
	var r: Array = Stock.rail()
	var n := r.size()
	if n == 0: return
	var bg = Art.tex("rail")
	if bg != null: draw_texture_rect(bg, Rect2(Vector2.ZERO, size), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color("8e979b"))
		draw_rect(Rect2(0, 0, size.x, 6), Color(0.85, 0.95, 1.0, 0.5))
	var w := size.x / n
	for i in n:
		var pan: Dictionary = r[i]
		var rect := Rect2(i * w + 3, 10, w - 6, size.y - 14)
		var pt = Art.tex("pan")
		if pt != null: draw_texture_rect(pt, rect, false)
		else:
			draw_rect(rect, Color("c9ced1"))
			draw_rect(rect, Color("6f777b"), false, 1.5)
		if pan.ing == "": continue
		var id: String = pan.ing
		var frac: float = clamp(pan.q / max(Stock.pan_cap(id), 1.0), 0.0, 1.0)
		var fill := Rect2(rect.position.x + 3, rect.end.y - 3 - (rect.size.y - 22) * frac, rect.size.x - 6, (rect.size.y - 22) * frac)
		var ft = Art.tex("fill." + id)
		if ft != null and frac > 0: draw_texture_rect(ft, fill, false)
		elif frac > 0: draw_rect(fill, Color(Data.ING[id].col))
		var name: String = Data.ING[id].name.split(" ")[0]
		var col := Color("1b2a1f")
		draw_string(font, rect.position + Vector2(4, 13), name, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 6, 11, col)
		var grams := Data.qty(id, pan.q) if pan.q > 0.5 else "EMPTY"
		draw_string(font, Vector2(rect.position.x + 4, rect.end.y - 5), grams, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 6, 11, Color.WHITE if frac > 0.25 else Color("a0331f"))
		if svc.tool == id: draw_rect(rect.grow(1), Kit.CHEESE, false, 3.0)
		elif svc.prepping.has(id): draw_rect(rect.grow(1), Kit.BASIL, false, 2.0)

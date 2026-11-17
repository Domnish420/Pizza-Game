class_name PrepTask
extends VBoxContainer
## Prepping by hand. The ingredient's prep "mode" (data/ingredients.json) picks the gesture:
##   knife  swipe down through the food at the guide, slice after slice: even slices score well
##   grate  rub the block up and down the grater with full, steady strokes
##   pick   tap the leaves off the stalks; tapping the stalk bruises them
##   pour   hold to pour (tins, draining, seasoning) and let go at the line
##   stir   circle the pan at a steady pace: too fast splashes, too slow catches
## How well you do it (0..1) sets the yield, how good it looks on the pizza, and how long it took.
## The result goes into 2 and 4 litre tubs (Stock.prep) with a day-dot label.

signal finished

var id: String
var raw := 0.0
var p
var mode := "knife"
var pad: PrepPad
var status: Label
var done := false

class PrepPad extends Control:
	var task
	var mode := "knife"
	var col := Color.WHITE
	var font: Font
	var need := 14
	var count := 0
	var scores := []
	var progress := 0.0
	# knife
	var item_end := 520.0
	var spacing := 24.0
	var swipe_from = null
	# grate
	var last_y := 0.0
	var dir := 0
	var travel := 0.0
	var block_y := 130.0
	# pick
	var leaves := []
	var misses := 0
	# pour
	var level := 0.0
	var target := 0.6
	var pouring := false
	# stir
	var last_ang := 0.0
	var speed := 0.0
	var stir_at = null

	func _init(t, m: String, c: Color) -> void:
		task = t
		mode = m
		col = c
		custom_minimum_size = Vector2(640, 260)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		font = ThemeDB.fallback_font
		need = {"knife": 14, "grate": 20, "pick": 16, "pour": 3, "stir": 1}[mode]
		if mode == "pick":
			for i in need: leaves.append({"pos": Vector2(90 + (i % 8) * 64 + randf_range(-8, 8), 70 + (i / 8) * 110 + randf_range(-10, 10)), "on": true})
		if mode == "pour": target = randf_range(0.45, 0.8)

	func quality() -> float:
		if mode == "stir": return clamp(1.0 - float(misses) * 0.04, 0.3, 1.0)
		if mode == "pick": return clamp(float(count) / max(1.0, count + misses * 0.6), 0.0, 1.0)
		if scores.is_empty(): return 0.5
		var t := 0.0
		for x in scores: t += x
		return t / scores.size()

	func fraction() -> float:
		return clamp(progress if mode == "stir" else float(count) / need, 0.0, 1.0)

	func _process(delta: float) -> void:
		if mode == "pour" and pouring:
			level = min(1.05, level + delta * 0.45)
			queue_redraw()
		if mode == "stir":
			speed = lerp(speed, 0.0, delta * 2.0)
			if speed > 2.2 and speed < 7.0 and stir_at != null: progress = min(1.0, progress + delta / 7.0)
			queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		if count >= need and mode != "stir": return
		var down: bool = e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed
		var up: bool = e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed
		var drag: bool = e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
		match mode:
			"knife":
				if down: swipe_from = e.position
				elif up and swipe_from != null:
					var a: Vector2 = swipe_from
					var b: Vector2 = e.position
					swipe_from = null
					if abs(b.y - a.y) < 60 or min(a.y, b.y) > 120 or max(a.y, b.y) < 140: return
					var x: float = (a.x + b.x) / 2.0
					if x >= item_end or x < 60: return
					var tgt: float = item_end - spacing
					scores.append(clamp(1.0 - abs(x - tgt) / spacing, 0.0, 1.0))
					item_end = x
					count += 1
					task._tick()
			"grate":
				if down:
					last_y = e.position.y
					travel = 0.0
					dir = 0
				elif drag:
					var dy: float = e.position.y - last_y
					last_y = e.position.y
					block_y = clamp(e.position.y, 40, 220)
					var d := 1 if dy > 0 else -1
					if dir != 0 and d != dir and abs(dy) > 0.5:
						if travel > 40:
							scores.append(1.0 if travel >= 110 and travel <= 200 else 0.6)
							count += 1
							task._tick()
						travel = 0.0
					if abs(dy) > 0.5: dir = d
					travel += abs(dy)
			"pick":
				if down:
					var hit := false
					for l in leaves:
						if l.on and l.pos.distance_to(e.position) < 20:
							l.on = false
							hit = true
							count += 1
							break
					if not hit: misses += 1
					task._tick()
			"pour":
				if down:
					pouring = true
				elif up and pouring:
					pouring = false
					scores.append(clamp(1.0 - max(0.0, abs(level - target) - 0.03) * 6.0, 0.0, 1.0))
					count += 1
					level = 0.0
					target = randf_range(0.45, 0.8)
					task._tick()
			"stir":
				var c := Vector2(size.x / 2.0, size.y / 2.0)
				if down: stir_at = e.position
				elif up: stir_at = null
				elif drag and stir_at != null:
					var ang: float = (e.position - c).angle()
					var dang: float = abs(angle_difference(last_ang, ang))
					last_ang = ang
					speed = lerp(speed, dang * 60.0, 0.3)
					if speed > 9.0 and randf() < 0.05: misses += 1
					task._tick()
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("6b4a2b") if mode in ["knife", "pick"] else Color("8a8f8a"))
		match mode:
			"knife":
				draw_rect(Rect2(40, 110, 560, 120), Color("c69a62"))
				draw_rect(Rect2(60, 140, item_end - 60, 60), col)
				for i in count: draw_rect(Rect2(item_end + 10 + i * 8, 140, 6, 60), col.darkened(0.15))
				var tgt := item_end - spacing
				if count < need: draw_dashed_line(Vector2(tgt, 120), Vector2(tgt, 220), Color(1, 1, 1, 0.8), 2.0, 6.0)
				draw_string(font, Vector2(48, 30), "Swipe down through the food at the dotted line", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
			"grate":
				draw_rect(Rect2(260, 20, 120, 220), Color("b7bdc0"))
				for i in 12: draw_line(Vector2(270, 34 + i * 17), Vector2(370, 34 + i * 17), Color("7d8487"), 2.0)
				var w: float = 90.0 * (1.0 - fraction() * 0.7)
				draw_rect(Rect2(320 - w / 2.0, block_y - 30, w, 60), col)
				draw_circle(Vector2(480, 220), 20 + 40 * fraction(), col.lightened(0.2))
				draw_string(font, Vector2(20, 30), "Rub up and down the grater:\nfull, steady strokes", HORIZONTAL_ALIGNMENT_LEFT, 220, 16, Color.WHITE)
			"pick":
				for i in 2: draw_line(Vector2(70, 70 + i * 110), Vector2(600, 70 + i * 110), Color("4f6b2f"), 4.0)
				for l in leaves:
					if l.on: draw_colored_polygon(PackedVector2Array([l.pos + Vector2(-14, 0), l.pos + Vector2(0, -9), l.pos + Vector2(14, 0), l.pos + Vector2(0, 9)]), col)
				draw_string(font, Vector2(20, 250), "Tap each leaf. Tapping the stalk bruises them.", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
			"pour":
				draw_rect(Rect2(250, 40, 140, 200), Color("f4f4f4"))
				draw_rect(Rect2(250, 40 + 200 * (1.0 - level), 140, 200 * level), col)
				draw_line(Vector2(240, 40 + 200 * (1.0 - target)), Vector2(400, 40 + 200 * (1.0 - target)), Kit.TOMATO, 3.0)
				if pouring: draw_rect(Rect2(312, 0, 16, 40 + 200 * (1.0 - level)), col)
				draw_string(font, Vector2(20, 30), "Hold to pour.\nLet go at the red line.", HORIZONTAL_ALIGNMENT_LEFT, 220, 16, Color.WHITE)
			"stir":
				var c := Vector2(size.x / 2.0, size.y / 2.0)
				draw_circle(c, 112, Color("3d3d3d"))
				draw_circle(c, 100, col.darkened(0.2))
				var band := "Too slow" if speed < 2.2 else ("Too fast: it is splashing" if speed > 7.0 else "Good")
				draw_string(font, Vector2(20, 30), "Stir round and round at a steady pace", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
				draw_string(font, Vector2(20, 250), band, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Kit.BASIL if band == "Good" else Kit.CHEESE)
				draw_arc(c, 120, -PI / 2, -PI / 2 + TAU * progress, 48, Kit.BASIL, 6.0)

func _init(ingredient: String, raw_g: float) -> void:
	id = ingredient
	p = Data.ING[id].prep
	mode = p.mode
	raw = min(raw_g, Stock.have(id), Stock.max_prep_raw(id))
	add_theme_constant_override("separation", 10)

func _ready() -> void:
	var it: Dictionary = Data.ING[id]
	if raw < 5.0:
		add_child(Kit.label("Nothing to prep: no %s in stock, or no clean tubs." % it.name.to_lower(), 20, Kit.TOMATO, true))
		add_child(Kit.button("OK", func():
			Kit.main.close_modal()
			finished.emit()))
		done = true
		return
	add_child(Kit.label("%s: %s %s" % [p.task, Data.qty(id, raw), it.name.to_lower()], 26))
	var made: float = raw * float(p.yield)
	var litres: float = made / 1000.0 * float(p.vol)
	add_child(Kit.label("Makes about %s %s, %.1f litres: %s. It keeps %d day%s once prepped." % [Data.qty(id, made), p.as, litres, _tubs_text(litres), p.life, "" if p.life == 1 else "s"], 16, Kit.MUTED, true))
	pad = PrepPad.new(self, mode, Color(it.col))
	add_child(pad)
	status = Kit.label("", 18, Kit.CHEESE)
	add_child(status)
	var h := Kit.hbox(10)
	h.add_child(Kit.button("Cancel", func():
		done = true
		Kit.main.close_modal()
		finished.emit(), "ghost"))
	h.add_child(Kit.button("Stop here", _finish, "ghost"))
	add_child(h)
	_tick()

func _tubs_text(litres: float) -> String:
	var n4 := int(floor(litres / 4.0))
	var rest := litres - n4 * 4.0
	var n2 := 0
	if rest > 2.0: n4 += 1
	elif rest > 0.05: n2 = 1
	var parts := []
	if n4 > 0: parts.append("%d x 4 L tub%s" % [n4, "" if n4 == 1 else "s"])
	if n2 > 0: parts.append("a 2 L tub")
	return " and ".join(parts) if parts.size() > 0 else "a 2 L tub"

func _tick() -> void:
	if done: return
	status.text = "%d%% done · technique %d%%" % [pad.fraction() * 100, pad.quality() * 100]
	if pad.fraction() >= 1.0: _finish()

func _finish() -> void:
	if done: return
	done = true
	var frac := pad.fraction()
	var q := pad.quality()
	var use: float = raw * frac
	Kit.clear(self)
	if use < 5.0:
		Kit.main.close_modal()
		finished.emit()
		return
	var res := Stock.prep(id, use, q)
	var mins: float = ceil(Stock.prep_minutes(id, use, Day.prep_mult()) * (1.2 - 0.35 * q))
	var notes := Day.spend(mins)
	Game.save_game()
	var dot: String = Stock.DAY_DOT[Game.weekday()]
	add_child(Kit.label("%s %s in %s" % [Data.qty(id, res.made), p.as, ", ".join(res.tubs.map(func(sz): return "%d L" % sz)) + (" tubs" if res.tubs.size() > 1 else " tub")], 26))
	add_child(Kit.label("Technique %d%%: %s. Took %d minutes; it is now %s." % [q * 100, "lovely work" if q >= 0.85 else ("fine" if q >= 0.6 else "rough: you lost some to waste and it will look untidy"), mins, Data.hhmm(Day.now())], 18, Kit.INK, true))
	add_child(Kit.label("Labelled with a %s day dot. Use by %s." % [dot.to_lower(), Data.DAY_NAME[Game.weekday(Game.s.day + int(p.life))]], 16, Kit.MUTED, true))
	if res.short: add_child(Kit.label("You ran out of clean tubs. Wash up or buy more.", 17, Kit.TOMATO, true))
	if notes.size() > 0: add_child(Kit.label("\n".join(notes), 15, Kit.CHEESE, true))
	add_child(Kit.button("Done", func():
		Kit.main.close_modal()
		finished.emit()))

class_name FoldTask
extends VBoxContainer
## Folding pizza boxes by hand before service. A box comes flat; fold it in four moves, in order:
##   1. drag the front flap up onto the base
##   2. drag the left side in
##   3. drag the right side in
##   4. drag the lid over and down to close it
## Each finished box goes on the stack by the pass (Stock.fold). A practised hand folds one in about 15 seconds;
## the clock is charged Stock.FOLD_MIN per box folded.
## Art keys: "box.flat" (the flat box, 320x320), "box.folded" (a closed box, for the stack).

signal finished

const STEPS := ["front", "left", "right", "lid"]
const HINT := {"front": "Drag the front flap up", "left": "Fold the left side in", "right": "Fold the right side in", "lid": "Bring the lid over and close it"}

var pad: FoldPad
var status: Label
var made := 0
var done := false

class FoldPad extends Control:
	var task
	var step := 0
	var from = null
	var font: Font
	const BASE := Rect2(260, 110, 120, 120)
	func _init(t) -> void:
		task = t
		custom_minimum_size = Vector2(640, 320)
		font = ThemeDB.fallback_font
	func _flap(name: String) -> Rect2:
		match name:
			"front": return Rect2(260, 230, 120, 36)
			"left": return Rect2(220, 110, 40, 120)
			"right": return Rect2(380, 110, 40, 120)
			_: return Rect2(260, 10, 120, 100)
	func _dir(name: String) -> Vector2:
		return {"front": Vector2.UP, "left": Vector2.RIGHT, "right": Vector2.LEFT, "lid": Vector2.DOWN}[name]
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed: from = e.position
			elif from != null:
				var name: String = FoldTask.STEPS[step]
				var mv: Vector2 = e.position - from
				if _flap(name).grow(14).has_point(from) and mv.length() > 50.0 and mv.normalized().dot(_dir(name)) > 0.6:
					step += 1
					Art.sfx("tap")
					if step >= FoldTask.STEPS.size():
						step = 0
						task.box_done()
					task._tick()
				elif mv.length() > 20.0:
					task.hint(name)
				from = null
				queue_redraw()
	func _draw() -> void:
		var flat = Art.tex("box.flat")
		var card := Color("c9a36a")
		var edge := Color("7a5a2e")
		if flat != null and step == 0: draw_texture_rect(flat, Rect2(160, 0, 320, 320), false)
		else:
			draw_rect(BASE, card)
			for i in FoldTask.STEPS.size():
				var nm: String = FoldTask.STEPS[i]
				if i >= step:
					var r := _flap(nm)
					draw_rect(r, card.lightened(0.08))
					draw_rect(r, edge, false, 1.5)
				else:
					# folded: a raised wall along that edge of the base (or the closed lid over all of it)
					match nm:
						"front": draw_rect(Rect2(BASE.position + Vector2(0, BASE.size.y - 10), Vector2(BASE.size.x, 10)), card.darkened(0.25))
						"left": draw_rect(Rect2(BASE.position, Vector2(10, BASE.size.y)), card.darkened(0.25))
						"right": draw_rect(Rect2(BASE.position + Vector2(BASE.size.x - 10, 0), Vector2(10, BASE.size.y)), card.darkened(0.25))
						"lid": draw_rect(BASE.grow(2), card.darkened(0.1))
			draw_rect(BASE, edge, false, 2.0)
		if step < FoldTask.STEPS.size():
			var r := _flap(FoldTask.STEPS[step])
			draw_rect(r.grow(3), Color(0.96, 0.78, 0.31, 0.9), false, 3.0)
			var c := r.get_center()
			draw_line(c, c + _dir(FoldTask.STEPS[step]) * 46.0, Color(0.96, 0.78, 0.31), 4.0)
		# the stack of folded boxes
		var tex = Art.tex("box.folded")
		for i in min(Stock.folded(), 12):
			var at := Vector2(500, 290 - i * 9)
			if tex != null: draw_texture_rect(tex, Rect2(at, Vector2(110, 9)), false)
			else:
				draw_rect(Rect2(at, Vector2(110, 8)), card.darkened(0.1))
				draw_rect(Rect2(at, Vector2(110, 8)), edge, false, 1.0)
		draw_string(font, Vector2(500, 312), "%d folded" % Stock.folded(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

func _init() -> void:
	add_theme_constant_override("separation", 8)

func _ready() -> void:
	add_child(Kit.label("Fold pizza boxes", 26))
	add_child(Kit.label("Boxes come flat. Fold a stack before you open, so every takeaway goes straight into one. Today looks like about %d takeaways; %d are folded, %d flat in stock, and there is room for %d by the pass." % [Stock.boxes_needed(), Stock.folded(), int(Stock.have("box")), Stock.fold_cap()], 15, Kit.MUTED, true))
	var cc := CenterContainer.new()
	pad = FoldPad.new(self)
	cc.add_child(pad)
	add_child(cc)
	status = Kit.label("", 18, Kit.CHEESE, true)
	add_child(status)
	var db := Kit.button("Done", _finish)
	db.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_child(db)
	_tick()

func _tick() -> void:
	status.text = "%s.  Folded this time: %d  ·  %d min" % [HINT[STEPS[pad.step]], made, ceil(made * Stock.FOLD_MIN)]
	pad.queue_redraw()

func hint(name: String) -> void:
	Kit.main.toast(HINT[name])

func box_done() -> void:
	if Stock.fold(1) <= 0:
		Kit.main.toast("No room by the pass, or no flat boxes left", true)
		return
	made += 1
	_tick()

func _finish() -> void:
	if done: return
	done = true
	var notes := Day.spend(ceil(made * Stock.FOLD_MIN)) if made > 0 else []
	Game.save_game()
	Kit.main.close_modal()
	finished.emit()
	if notes.size() > 0: Kit.main.message("Meanwhile", "\n".join(notes), "OK")

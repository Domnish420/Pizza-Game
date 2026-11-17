class_name TrapTask
extends VBoxContainer
## Pest control by hand, on the floor plan of the premises (Hygiene.plan()).
## You see the rooms, the ways mice could get in (gaps under doors, drains, pipe holes, air bricks), the droppings
## where they have actually been getting in, and your traps.
##   tap the floor          lay a trap there (5 min)
##   drag a trap            move it (2 min)
##   tap a sprung trap      empty it and set it again (2 min)
##   tap a set trap         lift it and put it back in the box (1 min)
## A trap works when it is flat against a wall, close to a way in that mice use. While you drag, the trap shows
## green for a good spot, amber for so-so, grey for a waste of a trap.
## Art keys: "plan.<venue index>" (the floor plan, 640x320), "trap", "trap.sprung", "droppings".

signal finished

var pad: PlanPad
var status: Label
var minutes := 0.0
var done := false

class PlanPad extends Control:
	var task
	var font: Font
	var drag := -1             # index of the trap being dragged
	var drag_pos := Vector2.ZERO
	var press_at := Vector2.ZERO
	var moved := false
	func _init(t) -> void:
		task = t
		custom_minimum_size = Hygiene.PLAN_SIZE
		font = ThemeDB.fallback_font
	func _trap_at(p: Vector2) -> int:
		var ts := Hygiene.traps()
		for i in ts.size():
			if Vector2(ts[i].x, ts[i].y).distance_to(p) < 16.0: return i
		return -1
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				press_at = e.position
				moved = false
				drag = _trap_at(e.position)
				drag_pos = e.position
			else:
				if drag >= 0 and moved: task.moved(drag, e.position)
				elif drag >= 0: task.tapped_trap(drag)
				else: task.tapped_floor(e.position)
				drag = -1
			queue_redraw()
		elif e is InputEventMouseMotion and drag >= 0:
			drag_pos = e.position
			if drag_pos.distance_to(press_at) > 8.0: moved = true
			queue_redraw()
	func _draw() -> void:
		var pl := Hygiene.plan()
		var bg = Art.tex("plan.%d" % int(Game.s.venue))
		if bg != null: draw_texture_rect(bg, Rect2(Vector2.ZERO, Hygiene.PLAN_SIZE), false)
		else:
			draw_rect(Rect2(Vector2.ZERO, Hygiene.PLAN_SIZE), Color("2c3a30"))
			for rm in pl.rooms:
				var r: Array = rm.r
				var col: Color = {"boh": Color("d7dad6"), "dry": Color("cdb48a"), "foh": Color("a77d52")}[rm.a]
				draw_rect(Rect2(r[0], r[1], r[2], r[3]), col)
			for rm in pl.rooms:
				var r: Array = rm.r
				draw_rect(Rect2(r[0], r[1], r[2], r[3]), Color("2b2b2b"), false, 4.0)
				draw_string(font, Vector2(r[0] + 8, r[1] + 18), rm.n, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0, 0, 0, 0.55))
			for f in pl.food:
				draw_rect(Rect2(f[0] - 14, f[1] - 10, 28, 20), Color("8a6a3a"))
				draw_string(font, Vector2(f[0] - 22, f[1] + 24), f[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0, 0, 0, 0.6))
		# the ways in: you can see a door gap or a drain; droppings tell you which ones mice use
		for e in pl.entries:
			var at := Vector2(e.x, e.y)
			match e.kind:
				"drain":
					draw_circle(at, 9, Color("555555"))
					for k in 3: draw_line(at + Vector2(-6, -4 + k * 4), at + Vector2(6, -4 + k * 4), Color("222222"), 1.5)
				"pipe": draw_circle(at, 6, Color("6b6b6b"))
				"vent":
					draw_rect(Rect2(at - Vector2(9, 5), Vector2(18, 10)), Color("8d5a3b"))
					for k in 3: draw_circle(at + Vector2(-5 + k * 5, 0), 1.6, Color("2b2b2b"))
				_:      # a gap in the wall: along a side wall it runs up and down, along the top or bottom it runs across
					var side: bool = abs(e.x - 40) < 6 or abs(e.x - 600) < 6
					var half := Vector2(0, 10) if side else Vector2(10, 0)
					draw_line(at - half, at + half, Color("e8e0c8"), 5.0)
		var dt = Art.tex("droppings")
		for d in Hygiene.droppings():
			if dt != null: draw_texture_rect(dt, Rect2(d - Vector2(4, 4), Vector2(8, 8)), false)
			else: draw_circle(d, 2.2, Color("2a1d12"))
		var ts := Hygiene.traps()
		for i in ts.size():
			var p := Vector2(ts[i].x, ts[i].y)
			if i == drag and moved: p = drag_pos
			_draw_trap(p, ts[i].sprung, i == drag and moved)
		if drag >= 0 and moved:
			var v := Hygiene.spot_value(drag_pos)
			draw_arc(drag_pos, 20, 0, TAU, 32, Color("74c47a") if v >= 0.5 else (Color("f4c64f") if v >= 0.2 else Color("9a9a9a")), 3.0)
	func _draw_trap(p: Vector2, sprung: bool, ghost: bool) -> void:
		var t = Art.tex("trap.sprung" if sprung else "trap")
		if t != null:
			draw_texture_rect(t, Rect2(p - Vector2(12, 7), Vector2(24, 14)), false, Color(1, 1, 1, 0.6 if ghost else 1.0))
			return
		draw_rect(Rect2(p - Vector2(11, 6), Vector2(22, 12)), Color("b08950", 0.6 if ghost else 1.0))
		draw_rect(Rect2(p - Vector2(11, 6), Vector2(22, 12)), Color("4a3520"), false, 1.5)
		if sprung:
			draw_line(p - Vector2(8, 8), p + Vector2(8, 8), Color("e2553c"), 2.5)
			draw_line(p + Vector2(-8, 8), p + Vector2(8, -8), Color("e2553c"), 2.5)
		else:
			draw_line(p + Vector2(-6, 0), p + Vector2(6, 0), Color("c0c0c0"), 1.5)

func _init() -> void:
	add_theme_constant_override("separation", 8)

func _ready() -> void:
	add_child(Kit.label("Pest control: %s" % ("the van" if int(Game.s.venue) == 0 else Game.venue().name.to_lower()), 26))
	add_child(Kit.label("Mice get in through gaps under doors, drains, pipe holes and air bricks, then run along the walls to the food. Droppings show where they are getting in. Tap the floor to lay a trap flat against the wall, close to the way in. Drag a trap to move it, tap a sprung one to reset it, tap a set one to lift it.", 15, Kit.MUTED, true))
	var cc := CenterContainer.new()
	pad = PlanPad.new(self)
	cc.add_child(pad)
	add_child(cc)
	status = Kit.label("", 17, Kit.CHEESE, true)
	add_child(status)
	var db := Kit.button("Done", _finish)
	db.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_child(db)
	_tick()

func _tick() -> void:
	var ps := Hygiene.pest_state()
	status.text = "%s.  Traps set: %d of the %d this place needs  ·  sprung: %d  ·  in the box: %d  ·  time so far: %d min" % [ps[0], Hygiene.laid(), Hygiene.traps_wanted(), Hygiene.sprung(), int(Stock.have("traps")), minutes]
	pad.queue_redraw()

func tapped_floor(p: Vector2) -> void:
	if Hygiene.room_at(p).is_empty(): return
	if not Hygiene.lay_trap(p):
		Kit.main.toast("No traps left in the box. Order more from the packaging supplier.", true)
		return
	minutes += 5.0
	var v := Hygiene.spot_value(p)
	if v < 0.2: Kit.main.toast("Out in the open, nowhere near a way in: mice will run straight past it")
	_tick()

func tapped_trap(i: int) -> void:
	var t: Dictionary = Hygiene.traps()[i]
	if t.sprung:
		t.sprung = false
		minutes += 2.0
		Kit.main.toast("Emptied and set again")
	else:
		Hygiene.pick_up(i)
		minutes += 1.0
	_tick()

func moved(i: int, p: Vector2) -> void:
	Hygiene.move_trap(i, p)
	minutes += 2.0
	_tick()

func _finish() -> void:
	if done: return
	done = true
	var notes := Day.spend(ceil(minutes))
	Game.save_game()
	Kit.main.close_modal()
	finished.emit()
	if notes.size() > 0: Kit.main.message("Meanwhile", "\n".join(notes), "OK")

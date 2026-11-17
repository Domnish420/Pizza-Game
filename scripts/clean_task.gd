class_name CleanTask
extends VBoxContainer
## Cleaning by hand: spray, then scrub every patch of dirt away. Without chemicals it takes twice the scrubbing
## and never comes up properly clean. Time on the clock is the share of the job you actually did.

signal finished

var area: String
var level0 := 100.0
var sprayed := false
var pad: ScrubPad
var status: Label
var done := false

class ScrubPad extends Control:
	var task
	var spots := []
	var total := 0.0
	var font: Font
	var area := "boh"
	func _init(t, a: String, dirt: float) -> void:
		task = t
		area = a
		custom_minimum_size = Vector2(640, 280)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		font = ThemeDB.fallback_font
		var n := int(clamp(round(dirt / 5.0), 3, 18))
		for i in n:
			var hp := randf_range(0.7, 1.3)
			spots.append({"pos": Vector2(randf_range(60, 580), randf_range(50, 240)), "r": randf_range(18, 34), "hp": hp})
			total += hp
	func left() -> float:
		var t := 0.0
		for sp in spots: t += max(0.0, sp.hp)
		return t / max(total, 0.001)
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			var rate: float = (0.012 if task.sprayed else 0.006) * e.relative.length()
			for sp in spots:
				if sp.hp > 0 and sp.pos.distance_to(e.position) < sp.r + 14: sp.hp -= rate
			task._tick()
			queue_redraw()
	func _draw() -> void:
		var bg = Art.tex("clean." + area)
		if bg != null: draw_texture_rect(bg, Rect2(Vector2.ZERO, size), false)
		else: draw_rect(Rect2(Vector2.ZERO, size), Color("d9dcd8") if area == "boh" else Color("b48a5a"))
		for sp in spots:
			if sp.hp <= 0: continue
			draw_circle(sp.pos, sp.r * (0.5 + 0.5 * min(sp.hp, 1.0)), Color(0.35, 0.27, 0.15, clamp(sp.hp, 0.2, 0.85)))
		if task.sprayed:
			for i in 30: draw_circle(Vector2(fmod(i * 97.0, size.x), fmod(i * 53.0, size.y)), 2, Color(0.6, 0.85, 1.0, 0.5))

func _init(which: String) -> void:
	area = which
	level0 = Hygiene.level(area)
	add_theme_constant_override("separation", 10)

func _ready() -> void:
	var nm: String = "the kitchen" if area == "boh" else ("the hatch and counter" if Game.venue().tables == 0 else "the dining room")
	add_child(Kit.label("Clean %s" % nm, 26))
	add_child(Kit.label("Spray first, then scrub every patch away. %d%% clean now. A full clean takes about %d minutes." % [level0, Hygiene.clean_minutes(area)], 16, Kit.MUTED, true))
	pad = ScrubPad.new(self, area, 100.0 - level0)
	add_child(pad)
	status = Kit.label("", 18, Kit.CHEESE)
	add_child(status)
	var h := Kit.hbox(10)
	var spray := Kit.button("Spray (%s)" % Data.qty("sanitiser", Hygiene.chem_needed(area)), func():
		var want := Hygiene.chem_needed(area)
		var got := Stock.take("sanitiser", want)
		sprayed = got.got >= want * 0.5
		if not sprayed: Kit.main.toast("Not enough cleaning chemicals. Scrubbing with water only.", true)
		pad.queue_redraw()
		_tick(), "primary")
	h.add_child(spray)
	h.add_child(Kit.button("Stop here", _finish, "ghost"))
	add_child(h)
	_tick()

func _tick() -> void:
	if done: return
	status.text = "%d%% scrubbed%s" % [(1.0 - pad.left()) * 100, "" if sprayed else "  ·  not sprayed yet"]
	if pad.left() <= 0.0: _finish()

func _finish() -> void:
	if done: return
	done = true
	var did: float = 1.0 - pad.left()
	var to: float = level0 + (100.0 - level0) * did
	if not sprayed: to = min(to, 70.0)
	var kit := Equip.clean_cap(area)
	to = min(to, kit.cap)
	Game.s.clean[area] = clamp(max(level0, to), 0.0, 100.0)
	var mins: float = ceil(Hygiene.clean_minutes(area) * did)
	var notes := Day.spend(mins)
	Game.save_game()
	Kit.clear(self)
	add_child(Kit.label("%d%% clean" % Hygiene.level(area), 28, Kit.BASIL if Hygiene.level(area) >= 80 else Kit.CHEESE))
	add_child(Kit.label("Took %d minutes; it is now %s.%s" % [mins, Data.hhmm(Day.now()), ("" if sprayed else " Without chemicals it will not pass an inspection.") + ((" Held back by: " + ", ".join(kit.why) + ".") if kit.why.size() > 0 else "")], 17, Kit.MUTED, true))
	if notes.size() > 0: add_child(Kit.label("\n".join(notes), 15, Kit.CHEESE, true))
	add_child(Kit.button("Done", func():
		Kit.main.close_modal()
		finished.emit()))

class_name DoughGame
extends VBoxContainer
## Making a batch of dough: weigh every ingredient onto the scale, knead, then cut and ball.
##
## The recipe (data/doughs.json) is in baker's percentages, and the batch is judged the way a bakery
## would judge it: against the flour you actually put in. Hydration, salt, yeast, oil, sugar and the
## flour blend all have to be close, or the dough is poor, or unusable. Whatever you pour comes out of
## stock by weight, so the dough carries the quality and the cost of the flour you used.

const BATCHES := [1, 2, 3, 5, 8, 16, 32]

var style: String
var d: Dictionary
var c: Dictionary
var kg := 1                 # flour in this batch
var added := {}             # ingredient id (or "water") -> grams on the scale
var spent := {}             # ingredient id -> cost of what was poured
var gsum := 0.0             # grams x quality of what was poured
var gw := 0.0
var pouring := ""
var pour_t := 0.0
var step := 0
var rows := {}
var knead := 0.0
var knead_meter: Meter
var cut_meter: Meter
var cut_dir := 1.0
var cuts := []
var scores := {}
var speed := 0
var total_lbl: Label

class KneadPad extends Control:
	signal kneaded(dist: float)
	var wobble := 0.0
	func _init() -> void:
		custom_minimum_size = Vector2(300, 220)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT):
			wobble += e.relative.length() * 0.02
			kneaded.emit(e.relative.length())
			queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("8a8f8a"))
		var t = Art.tex("dough.blob")
		var sx := 1.0 + sin(wobble) * 0.12
		draw_set_transform(size / 2.0, 0, Vector2(sx * 1.7, (2.0 - sx) * 0.75))
		if t != null: draw_texture_rect(t, Rect2(-90, -90, 180, 180), false)
		else:
			draw_circle(Vector2(0, 6), 92, Color("dcc592"))
			draw_circle(Vector2.ZERO, 90, Color("f1dfb6"))

func _init(dough_style: String) -> void:
	style = dough_style
	d = Data.DOUGHS[style]
	c = Game.calc()
	for p in d.parts: added[p.ing] = 0.0
	add_theme_constant_override("separation", 10)

func _ready() -> void:
	_build()

func _targets() -> Dictionary:
	return Stock.dough_parts(style, kg * 1000.0)

func _started() -> bool:
	for k in added:
		if added[k] > 0: return true
	return false

func _name(ing: String) -> String:
	return "Water" if ing == "water" else Data.ING[ing].name

func _unit(ing: String) -> String:
	return "ml" if ing == "water" or Data.ING[ing].unit == "ml" else "g"

## can a batch of this many kg of flour be made from what is in stock
static func can_batch(dough: Dictionary, flour_kg: float) -> bool:
	for p in dough.parts:
		if p.flour and Stock.have(p.ing) < flour_kg * 1000.0 * p.pct / 100.0 * 0.9: return false
	return true

func _build() -> void:
	Kit.clear(self)
	rows = {}
	match step:
		0: _build_measure()
		1: _build_knead()
		2: _build_cut()
		_: pass

# ---------- 1. weigh ----------
func _build_measure() -> void:
	var head := Kit.hbox(10)
	var t := Kit.label("%s dough · 1 of 3 · Weigh it out" % d.name, 26)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(Kit.label("Flour:", 18, Kit.MUTED))
	for b in BATCHES:
		if b > c.batch: continue
		var bb := Kit.button("%d kg" % b, func():
			kg = b
			_build(), "primary" if kg == b else "ghost", 18)
		bb.disabled = _started() or not can_batch(d, b)
		head.add_child(bb)
	add_child(head)
	add_child(Kit.label("Hold a button to pour, tap it for a pinch. Stop inside the green mark. Nothing comes back out of the bowl, so the recipe is judged against the flour you actually added.", 17, Kit.MUTED, true))
	var tg := _targets()
	for p in d.parts:
		var ing: String = p.ing
		var h := Kit.hbox(10)
		var nm := Kit.label("%s  %s%%" % [_name(ing), _num(p.pct)], 19)
		nm.custom_minimum_size.x = 250
		h.add_child(nm)
		var m := Meter.new(0.645, 0.69)
		h.add_child(m)
		var val := Kit.label("", 19)
		val.custom_minimum_size.x = 200
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(val)
		var b := Kit.button("Pour", Callable(), "primary", 20)
		b.custom_minimum_size.x = 110
		b.button_down.connect(func():
			pouring = ing
			pour_t = 0.0)
		b.button_up.connect(_stop_pour)
		h.add_child(b)
		add_child(h)
		# without scales (or a jug for the water) you are judging by eye: the reading is off by a steady amount
		var tool := "jug" if ing == "water" else "scales"
		rows[ing] = {"meter": m, "val": val, "target": tg[ing], "tool": tool, "bias": 0.0 if Equip.has(tool) else randf_range(-0.09, 0.09)}
	var foot := Kit.hbox(10)
	total_lbl = Kit.label("", 19, Kit.CHEESE)
	total_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(total_lbl)
	foot.add_child(Kit.button("Cancel", _cancel, "ghost"))
	foot.add_child(Kit.button("Mix the dough", _mix))
	add_child(foot)
	_refresh_measure()

func _num(x: float) -> String:
	return str(int(x)) if abs(x - round(x)) < 0.01 else ("%.2f" % x).rstrip("0")

func _fmt(v: float, target: float) -> String:
	return ("%.1f" % v) if target < 40.0 else str(int(round(v)))

func _refresh_measure() -> void:
	var total := 0.0
	for ing in rows:
		var e: Dictionary = rows[ing]
		e.meter.set_value(added[ing] / (e.target * 1.5) * (1.0 + e.bias))
		if Equip.has(e.tool): e.val.text = "%s / %s %s" % [_fmt(added[ing], e.target), _fmt(e.target, e.target), _unit(ing)]
		else: e.val.text = "%s? (no %s)" % [Equip.weigh(added[ing] * (1.0 + e.bias), e.tool).replace(" g", " " + _unit(ing)), "scales" if e.tool == "scales" else "jug"]
	for k in added: total += added[k]
	if total_lbl: total_lbl.text = "On the scale: %s  ·  makes about %d balls of %d g" % [("%.2f kg" % (total / 1000.0)) if total >= 1000 else "%d g" % int(total), int(total / d.ball), d.ball]

func _stop_pour() -> void:
	if pouring != "" and pour_t < 0.12:
		_pour(pouring, rows[pouring].target * 0.006)     # a tap is a pinch
	pouring = ""

func _pour(ing: String, amt: float) -> void:
	amt = min(amt, rows[ing].target * 1.5 - added[ing])
	if amt <= 0: return
	if ing != "water":
		var tk := Stock.take(ing, amt)
		if tk.got <= 0:
			pouring = ""
			Kit.main.toast("You have run out of " + Data.ING[ing].name.to_lower(), true)
			return
		amt = tk.got
		spent[ing] = spent.get(ing, 0.0) + tk.cost
		gsum += tk.g * tk.got
		gw += tk.got
	added[ing] += amt
	_refresh_measure()

func _process(delta: float) -> void:
	if step == 0 and pouring != "":
		pour_t += delta
		_pour(pouring, rows[pouring].target / 2.8 * delta)
	elif step == 2 and cut_meter != null:
		var v := cut_meter.value + cut_dir * delta * 0.85
		if v >= 1.0 or v <= 0.0: cut_dir = -cut_dir
		cut_meter.set_value(v)

func _spent_total() -> float:
	var t := 0.0
	for k in spent: t += spent[k]
	return t

func _cancel() -> void:
	if step < 9:      # walked away from a part-made batch: it is waste
		for ing in spent: Stock.log_waste(ing, added[ing], spent[ing], "dough mistakes")
	Game.save_game()
	Kit.main.close_modal()
	Kit.main.show_hub("dough")

func _mix() -> void:
	var flour := 0.0
	for p in d.parts:
		if p.flour: flour += added[p.ing]
	if flour < 300:
		Kit.main.toast("Add at least 300 g of flour", true)
		return
	var want := {}
	var pct := {}
	for p in d.parts:
		want[p.ing] = float(p.pct)
		pct[p.ing] = added[p.ing] / flour * 100.0
	var dev: float = abs(pct.water - want.water)
	var ruin := ""
	if dev > 9: ruin = "Far too wet. It is batter, not dough." if pct.water > want.water else "Far too dry. It will not come together."
	elif pct.salt > 5: ruin = "So much salt it killed the yeast."
	elif pct.yeast < want.yeast * 0.25: ruin = "Barely any yeast. It will never rise."
	elif pct.yeast > want.yeast * 3.5: ruin = "So much yeast it will collapse into a boozy mess."
	if ruin != "":
		_result_ruined(ruin, pct, want)
		return
	var others := []
	for p in d.parts:
		if p.ing == "water": continue
		var rel: float = abs(pct[p.ing] - want[p.ing]) / want[p.ing]
		others.append(clamp(100.0 - max(0.0, rel - (0.04 if p.flour else 0.08)) * 160.0, 0, 100))
	var avg := 0.0
	for o in others: avg += o / others.size()
	scores.measure = clamp(100.0 - max(0.0, dev - 1.0) * 9.0, 0, 100) * 0.4 + avg * 0.6
	scores.hyd = pct.water
	var yr: float = pct.yeast / want.yeast
	speed = 1 if yr > 1.6 else (-1 if yr < 0.55 else 0)
	step = 1
	_build()

func _result_ruined(why: String, pct: Dictionary, want: Dictionary) -> void:
	for ing in spent: Stock.log_waste(ing, added[ing], spent[ing], "dough mistakes")
	step = 9
	Kit.clear(self)
	add_child(Kit.label("Unusable dough", 28, Kit.TOMATO))
	add_child(Kit.label(why, 21, Kit.INK, true))
	add_child(Kit.label("You hit %d%% hydration (recipe %d%%), %.1f%% salt (recipe %.1f%%), %.2f%% yeast (recipe %.2f%%). %s of ingredients wasted." % [pct.water, want.water, pct.salt, want.salt, pct.yeast, want.yeast, Kit.cents(_spent_total())], 18, Kit.MUTED, true))
	add_child(Kit.button("Bin it", _cancel, "danger"))

# ---------- 2. knead ----------
func _build_knead() -> void:
	add_child(Kit.label("%s dough · 2 of 3 · Knead" % d.name, 26))
	add_child(Kit.label("Rub back and forth across the dough. Stop in the green zone: smooth and springy. Past it the gluten is overworked and the base turns tough." + ("  Your mixer does most of the work." if c.knead > 1 else ""), 17, Kit.MUTED, true))
	knead_meter = Meter.new(85.0 / 120.0, 105.0 / 120.0)
	add_child(knead_meter)
	var pad := KneadPad.new()
	pad.kneaded.connect(func(dist):
		knead = min(120.0, knead + dist * c.knead / 60.0)
		knead_meter.set_value(knead / 120.0))
	add_child(pad)
	add_child(Kit.button("Dough feels right", func():
		scores.knead = (knead / 85.0 * 100.0) if knead < 85 else (100.0 if knead <= 105 else max(0.0, 100.0 - (knead - 105.0) * 5.0))
		step = 2
		_build()))

# ---------- 3. cut and ball ----------
func _build_cut() -> void:
	add_child(Kit.label("%s dough · 3 of 3 · Scale and ball" % d.name, 26))
	add_child(Kit.label("Cut the dough into %d g pieces%s. Hit Cut when the marker is in the green: three test cuts set how even your dough balls are." % [d.ball, " with your bench scraper" if Equip.has("scraper") else " (no bench scraper: you are tearing it by hand)"], 17, Kit.MUTED, true))
	cut_meter = Meter.new(0.43, 0.57, 40)
	cut_meter.marker = true
	add_child(cut_meter)
	var lbl := Kit.label("Cuts: 0 / 3", 20)
	add_child(lbl)
	add_child(Kit.button("Cut", func():
		cuts.append(clamp(100.0 - max(0.0, abs(cut_meter.value - 0.5) - 0.07) * 450.0, 0, 100))
		lbl.text = "Cuts: %d / 3" % cuts.size()
		if cuts.size() >= 3: _finish(), "primary", 26))

func _finish() -> void:
	var cut_s: float = (cuts[0] + cuts[1] + cuts[2]) / 3.0
	var q: float = clamp(scores.measure * 0.5 + scores.knead * 0.3 + cut_s * 0.2 + c.proof_q + Equip.dough_q_bonus(), 0, 100)
	var total := 0.0
	for k in added: total += added[k]
	var balls := int(total / d.ball)
	var grade: float = gsum / gw if gw > 0 else 2.0
	var per_ball: float = _spent_total() / max(1, balls)
	var tray_room := Equip.dough_room()
	var fitted := Stock.add_dough(style, balls, q, speed, grade, per_ball)
	var mins: float = ceil(15.0 + 6.0 * kg / c.knead)
	var notes := Day.spend(mins)
	if fitted < balls: Stock.log_waste("dough:" + style, balls - fitted, (balls - fitted) * per_ball, "no room for the dough")
	Game.save_game()
	Art.sfx("up")
	step = 9
	cut_meter = null
	Kit.clear(self)
	add_child(Kit.label("%d %s dough balls in the fridge" % [fitted, d.name], 28))
	add_child(Kit.label("Quality %d / 100" % int(q), 34, Kit.CHEESE))
	add_child(Kit.label("Weighing %d (hydration %d%%, recipe %d%%)  ·  Kneading %d  ·  Balling %d%s" % [scores.measure, scores.hyd, _want("water"), scores.knead, cut_s, ("  ·  proofing kit +%d" % c.proof_q) if c.proof_q > 0 else ""], 18, Kit.MUTED, true))
	add_child(Kit.label("%s grade flour. Each ball cost %s to make. It took %d minutes; it is now %s." % [Data.grade_name(grade), Kit.cents(per_ball), mins, Data.hhmm(Day.now())], 18, Kit.MUTED, true))
	if notes.size() > 0: add_child(Kit.label("\n".join(notes), 16, Kit.CHEESE, true))
	var note := "It cold-proofs overnight and is ready tomorrow."
	if speed > 0: note = "Heavy on the yeast: it will be ready tomorrow but overproofs a day early."
	elif speed < 0: note = "Light on the yeast: it needs two nights before it is ready."
	add_child(Kit.label(note, 20, Kit.INK, true))
	if fitted < balls: add_child(Kit.label(("Your proving trays were full: %d balls had nowhere to go and were binned. Order more trays from %s." % [balls - fitted, Equip.SHOP.name]) if tray_room < balls else ("The fridge was full: %d balls had nowhere to go and were binned." % (balls - fitted)), 19, Kit.TOMATO, true))
	if not Equip.has("scraper"): add_child(Kit.label("No bench scraper: the balls came out uneven (quality -8).", 16, Kit.CHEESE, true))
	add_child(Kit.button("Done", _cancel))

func _want(ing: String) -> float:
	for p in d.parts:
		if p.ing == ing: return p.pct
	return 0.0

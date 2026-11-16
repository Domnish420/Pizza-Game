class_name DoughGame
extends VBoxContainer
## Making a batch of dough: weigh every ingredient onto the scale, knead, then cut and ball.
## The recipe is judged in baker's percentages against the flour you actually added, like a real bakery:
## hydration, salt, yeast, oil and sugar all have to be right or the dough is poor, or unusable.

const BATCHES := [1, 2, 3, 5, 8, 16, 32]
const PART_NAME := {"flour": "Flour", "water": "Water", "salt": "Salt", "yeast": "Yeast", "oil": "Olive oil", "sugar": "Sugar"}

var style: String
var d: Dictionary
var c: Dictionary
var kg := 1
var added := {}
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
	for p in Data.DOUGH_PARTS: added[p] = 0.0
	add_theme_constant_override("separation", 10)

func _ready() -> void:
	_build()

func _targets() -> Dictionary:
	return Game.dough_parts(style, kg * 1000.0)

func _started() -> bool:
	for p in added:
		if added[p] > 0: return true
	return false

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
	head.add_child(Kit.label("Batch:", 18, Kit.MUTED))
	for b in BATCHES:
		if b > c.batch: continue
		var bb := Kit.button("%d kg" % b, func():
			kg = b
			_build(), "primary" if kg == b else "ghost", 18)
		bb.disabled = _started() or Game.stock(d.flour) < b * 900
		head.add_child(bb)
	add_child(head)
	add_child(Kit.label("Hold a button to pour, tap it for a pinch. Stop inside the green mark. You cannot take anything back out, so the recipe is judged against the flour you actually added.", 17, Kit.MUTED, true))
	var tg := _targets()
	for p in Data.DOUGH_PARTS:
		if tg[p] <= 0: continue
		var h := Kit.hbox(10)
		var nm := Kit.label(PART_NAME[p] if p != "flour" else Data.ING[d.flour].name, 20)
		nm.custom_minimum_size.x = 190
		h.add_child(nm)
		var m := Meter.new(0.645, 0.69)
		h.add_child(m)
		var val := Kit.label("", 19)
		val.custom_minimum_size.x = 210
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(val)
		var b := Kit.button("Pour", Callable(), "primary", 20)
		b.custom_minimum_size.x = 120
		b.button_down.connect(func():
			pouring = p
			pour_t = 0.0)
		b.button_up.connect(_stop_pour)
		h.add_child(b)
		add_child(h)
		rows[p] = {"meter": m, "val": val, "btn": b}
	var foot := Kit.hbox(10)
	total_lbl = Kit.label("", 20, Kit.CHEESE)
	total_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(total_lbl)
	foot.add_child(Kit.button("Cancel", _cancel, "ghost"))
	foot.add_child(Kit.button("Mix the dough", _mix))
	add_child(foot)
	_refresh_measure()

func _unit(p: String) -> String:
	return "ml" if p == "oil" or p == "water" else "g"

func _fmt(p: String, v: float) -> String:
	return ("%.1f" % v) if p == "yeast" or (p == "salt" and kg < 2) else str(int(round(v)))

func _refresh_measure() -> void:
	var tg := _targets()
	var total := 0.0
	for p in rows:
		rows[p].meter.set_value(added[p] / (tg[p] * 1.5))
		var have := "" if p == "water" else "   (have %s)" % Kit.qty(Game.part_ing(style, p), Game.stock(Game.part_ing(style, p)))
		rows[p].val.text = "%s / %s %s" % [_fmt(p, added[p]), _fmt(p, tg[p]), _unit(p)]
		rows[p].btn.tooltip_text = have
	for p in added: total += added[p]
	if total_lbl: total_lbl.text = "On the scale: %d g  ·  makes about %d balls of %d g" % [int(total), int(total / d.ball), d.ball]

func _stop_pour() -> void:
	if pouring != "" and pour_t < 0.12:
		_pour(pouring, _targets()[pouring] * 0.006)   # a tap is a pinch
	pouring = ""

func _pour(p: String, amt: float) -> void:
	if p != "water":
		var id := Game.part_ing(style, p)
		amt = min(amt, Game.stock(id))
		if amt <= 0:
			pouring = ""
			Kit.main.toast("You have run out of " + Data.ING[id].name, true)
			return
		Game.take(id, amt)
	added[p] = min(added[p] + amt, _targets()[p] * 1.5)
	_refresh_measure()

func _process(delta: float) -> void:
	if step == 0 and pouring != "":
		pour_t += delta
		_pour(pouring, _targets()[pouring] / 2.8 * delta)
	elif step == 2 and cut_meter != null:
		var v := cut_meter.value + cut_dir * delta * 0.85
		if v >= 1.0 or v <= 0.0: cut_dir = -cut_dir
		cut_meter.set_value(v)

func _cancel() -> void:
	Game.save_game()
	Kit.main.close_modal()
	Kit.main.show_hub("dough")

func _mix() -> void:
	var flour: float = added.flour
	if flour < 300:
		Kit.main.toast("Add at least 300 g of flour", true)
		return
	var pct := {}
	for p in Data.DOUGH_PARTS: pct[p] = added[p] / flour * 100.0
	var dev: float = abs(pct.water - d.water)
	var ruin := ""
	if dev > 9: ruin = "Far too wet. It is batter, not dough." if pct.water > d.water else "Far too dry. It will not come together."
	elif pct.salt > 5: ruin = "So much salt it killed the yeast."
	elif pct.yeast < d.yeast * 0.25: ruin = "Barely any yeast. It will never rise."
	elif pct.yeast > d.yeast * 3.5: ruin = "So much yeast it will collapse into a boozy mess."
	if ruin != "":
		_result_ruined(ruin, pct)
		return
	var hyd_s: float = clamp(100.0 - max(0.0, dev - 1.0) * 9.0, 0, 100)
	var others := []
	for p in ["salt", "yeast", "oil", "sugar"]:
		if d[p] > 0:
			var rel: float = abs(pct[p] - d[p]) / d[p]
			others.append(clamp(100.0 - max(0.0, rel - 0.08) * 160.0, 0, 100))
	var avg := 0.0
	for o in others: avg += o / others.size()
	scores.measure = hyd_s * 0.4 + avg * 0.6
	scores.hyd = pct.water
	var yr: float = pct.yeast / d.yeast
	speed = 1 if yr > 1.6 else (-1 if yr < 0.55 else 0)
	step = 1
	_build()

func _result_ruined(why: String, pct: Dictionary) -> void:
	step = 9
	Kit.clear(self)
	add_child(Kit.label("Unusable dough", 28, Kit.TOMATO))
	add_child(Kit.label(why, 21, Kit.INK, true))
	add_child(Kit.label("You hit %d%% hydration (recipe %d%%), %.1f%% salt (recipe %.1f%%), %.2f%% yeast (recipe %.2f%%). The ingredients are wasted." % [pct.water, d.water, pct.salt, d.salt, pct.yeast, d.yeast], 18, Kit.MUTED, true))
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
	add_child(Kit.label("Cut the dough into %d g pieces. Hit Cut when the marker is in the green: three test cuts set how even your dough balls are." % d.ball, 17, Kit.MUTED, true))
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
	var q: float = clamp(scores.measure * 0.5 + scores.knead * 0.3 + cut_s * 0.2 + c.proof_q, 0, 100)
	var total := 0.0
	for p in added: total += added[p]
	var balls := int(total / d.ball)
	var fitted := Game.add_dough(style, balls, q, speed)
	Game.save_game()
	Art.sfx("up")
	step = 9
	cut_meter = null
	Kit.clear(self)
	add_child(Kit.label("%d %s dough balls in the fridge" % [fitted, d.name], 28))
	add_child(Kit.label("Quality %d / 100" % int(q), 34, Kit.CHEESE))
	add_child(Kit.label("Weighing %d (hydration %d%%, recipe %d%%)  ·  Kneading %d  ·  Balling %d%s" % [scores.measure, scores.hyd, d.water, scores.knead, cut_s, ("  ·  proofing kit +%d" % c.proof_q) if c.proof_q > 0 else ""], 18, Kit.MUTED, true))
	var note := "It cold-proofs overnight and is ready tomorrow."
	if speed > 0: note = "Heavy on the yeast: it will be ready tomorrow but overproofs a day early."
	elif speed < 0: note = "Light on the yeast: it needs two nights before it is ready."
	add_child(Kit.label(note, 20, Kit.INK, true))
	if fitted < balls: add_child(Kit.label("The fridge was full: %d balls had nowhere to go and were binned." % (balls - fitted), 19, Kit.TOMATO, true))
	add_child(Kit.button("Done", _cancel))

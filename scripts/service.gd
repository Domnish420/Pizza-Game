class_name ServiceScreen
extends VBoxContainer
## One day's trading. This runs the whole simulation: customers arriving and what they think, the queue and
## the tables, tickets, your bench, the oven, and everything the staff do on their own.
## FrontScene, Bench and OvenView only draw it and pass your touches back in.
##
## A pizza's journey: ticket (new) -> claimed by you or a pizzaiolo (make) -> oven -> the pass -> handed over.
## When a party has everything it ordered it pays, tips and leaves a review (see settle()).
##
## The day runs on a clock from the venue's opening to closing time (DAY seconds at 1x). Toppings come off the
## makeline, which was prepped in the morning. When something runs out you prep more (which ties you up), a
## prep cook or pizzaiolo does it, or you 86 the pizzas that need it. Deliveries can turn up mid-shift at the
## back door. The kitchen and dining room get dirtier as you go, and if there are mice, customers may see one.

const DAY := 300.0              # seconds of trading at 1x speed

var c: Dictionary                # Game.calc() for today
var L: Dictionary                # layout of the front-of-house scene
var t := 0.0
var acc := 0.95
var speed := 1
var nid := 1
var pid := 1
var tickets := []
var parties := []
var queue := []                  # takeaway parties waiting to order
var waiters := []                # takeaway parties waiting for their food
var door := []                   # dine-in parties waiting for a table
var tables := []
var workers := []                # pizzaioli
var foh := []                    # front-of-house staff
var oven: Oven
var board := []                  # your baked pizzas waiting to be sliced
var bench: Pizza = null          # the pizza you are making
var tool := ""                   # ingredient in your hand ("" on the board = the pizza wheel)
var view := "front"              # front / bench / oven / board
var floats := []
var reviews := []
var r := {}
var dirty := true
var done := false
var pop_t := 0.0
var busy := {}                   # what you are tied up doing: {label, left, total (seconds), fn}
var eighty6 := {}                # pizza id -> true: taken off the menu for tonight
var crew := []                   # prep cooks and kitchen porters: {s, role, job, left, fn}
var prepping := {}               # ingredient id -> who is prepping it
var mouse := {}                  # a mouse running across the front: {pos, vel, t}
var mouse_until := -1.0          # minute until which customers are still talking about the mouse
var gm := 1.0                    # game minutes per second of play

# ui
var front: FrontScene
var bench_ui: Bench
var oven_ui: OvenView
var kitchen: HBoxContainer
var tick_box: VBoxContainer
var info: VBoxContainer
var palette: VBoxContainer
var mini_panel: PanelContainer
var mini_box: VBoxContainer
var btn_row: HBoxContainer
var tab_btns := {}
var top_lbl := {}
var clock: ProgressBar
var next_btn: Button
var bin_btn: Button
var auto_btn: Button
var pop: PanelContainer
var tick_bars := {}
var info_rows := []              # [[Label, Callable -> [text, colour]]] refreshed every frame
var prep_scroll: ScrollContainer
var prep_box: VBoxContainer
var busy_panel: PanelContainer
var busy_wrap: CenterContainer
var busy_lbl: Label
var busy_bar: ProgressBar
var pal_btns := []               # [[Button, ingredient id]]

func _ready() -> void:
	var G := Game
	c = G.calc()
	r = {"day": G.s.day, "served": 0, "mine": 0, "lost": 0, "sold": 0, "food": 0.0, "tips": 0.0, "drinks": 0.0, "deliv": 0.0,
		"qsum": 0.0, "xp": 0.0, "walked": 0, "gave_up": 0, "rep0": G.s.rep, "lvl0": G.s.level, "cats": {"look": 0.0, "taste": 0.0, "service": 0.0, "value": 0.0}, "n_rev": 0,
		"mice": 0, "eighty6": [], "inspect": {}, "closed": false, "boh0": Hygiene.level("boh"), "foh0": Hygiene.level("foh"), "notes": []}
	gm = (c.close - c.open) / DAY
	# opened late: the start of the day has gone
	t = clamp((float(G.s.clock) - c.open) / (c.close - c.open), 0.0, 0.9) * DAY
	G.s.phase = "service"
	oven = Oven.new(G.tier("oven"))
	if oven.def.feeds:
		var lit := Stock.take("wood", 3.0)       # lighting the oven before service
		oven.fire = 0.35 + 0.25 * lit.got
		if lit.got > 0: oven.wood_grade = lit.g
	for x in G.staff_of("pizzaiolo"): workers.append({"s": x, "job": null, "left": 0.0, "prep": "", "raw": 0.0})
	for role in ["cashier", "server", "host", "porter", "driver"]:
		for x in G.staff_of(role): foh.append({"s": x, "role": role, "cd": 1.0})
	for role in ["prep", "porter"]:
		for x in G.staff_of(role): crew.append({"s": x, "role": role, "job": "", "left": 0.0, "fn": Callable()})
	_layout()
	_build_ui()
	set_view("front")

# ---------- layout of the front-of-house scene (640 x 320 units) ----------
func _layout() -> void:
	var n: int = c.tables
	L = {"dine": n > 0}
	if n == 0:
		L.win = Vector2(232, 170)
		L.spawn = Vector2(680, 235)
		L.back = Vector2(46, 262)
	else:
		L.win = Vector2(62, 70)
		L.spawn = Vector2(625, 345)
		L.back = Vector2(24, 300)
		var cols := int(ceil(sqrt(n * 1.9)))
		var rows := int(ceil(float(n) / cols))
		var cw := 430.0 / cols
		var ch := 235.0 / rows
		for i in n:
			tables.append({"i": i, "pos": Vector2(195 + cw * (i % cols + 0.5), 22 + ch * (i / cols + 0.5)), "party": null, "dirty": false, "k": clamp(min(cw / 70.0, ch / 62.0), 0.45, 1.25)})

func q_pos(i: int) -> Vector2:
	if L.dine: return Vector2(95 + min(i, 3) * 28, 62 + max(0, i - 3) * 6)
	return Vector2(285 + min(i, 7) * 44, 228)
func w_pos(i: int) -> Vector2:
	if L.dine: return Vector2(78 + (i % 4) * 28, 292 - (i / 4) * 5)
	return Vector2(300 + (i % 8) * 42, 292)
func d_pos(i: int) -> Vector2:
	return Vector2(585 - i * 30, 296)

# ---------- ui ----------
func _build_ui() -> void:
	add_theme_constant_override("separation", 8)
	var top := Kit.hbox(12)
	add_child(top)
	top_lbl.time = Kit.label("", 20)
	top_lbl.time.custom_minimum_size.x = 120
	top.add_child(top_lbl.time)
	clock = Kit.bar(0, Kit.CHEESE, 12)
	clock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(clock)
	for k in ["count", "dough", "rep"]:
		top_lbl[k] = Kit.label("", 19, Kit.MUTED)
		top.add_child(top_lbl[k])
	top_lbl.cash = Kit.label("", 26, Kit.CHEESE)
	top.add_child(top_lbl.cash)
	top_lbl.speed = Kit.button("1x speed", _speed, "primary", 19)
	top.add_child(top_lbl.speed)
	top.add_child(Kit.button("Close up", func(): Kit.main.confirm("Close early?", "Anyone still waiting leaves unserved, and anything half-made goes in the bin.", "Close up", func(): finish(false)), "ghost", 19))

	var body := Kit.hbox(12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)
	var left := Kit.vbox(6)
	left.custom_minimum_size.x = 250
	left.add_child(Kit.label("ORDERS", 15, Kit.MUTED))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tick_box = Kit.vbox(6)
	tick_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(tick_box)
	left.add_child(sc)
	body.add_child(left)

	var mid := Kit.vbox(8)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(mid)
	var tabs := Kit.hbox(6)
	for k in ["front", "bench", "oven", "board", "prep"]:
		var b := Kit.button("", set_view.bind(k), "tab", 19)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)
		tab_btns[k] = b
	mid.add_child(tabs)
	front = FrontScene.new(self)
	mid.add_child(front)
	kitchen = Kit.hbox(10)
	kitchen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(kitchen)
	var bcol := Kit.vbox(8)
	bcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kitchen.add_child(bcol)
	var stack := Control.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bcol.add_child(stack)
	bench_ui = Bench.new(self)
	stack.add_child(bench_ui)
	oven_ui = OvenView.new(self)
	stack.add_child(oven_ui)
	prep_scroll = ScrollContainer.new()
	prep_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	prep_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	prep_box = Kit.vbox(8)
	prep_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prep_scroll.add_child(prep_box)
	stack.add_child(prep_scroll)
	busy_wrap = CenterContainer.new()
	busy_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	busy_wrap.visible = false
	busy_panel = Kit.panel(Color(0.05, 0.08, 0.06, 0.92), 18)
	var bv := Kit.vbox(8)
	busy_lbl = Kit.label("", 22, Kit.INK, true)
	busy_lbl.custom_minimum_size.x = 380
	bv.add_child(busy_lbl)
	busy_bar = Kit.bar(0, Kit.CHEESE, 14)
	bv.add_child(busy_bar)
	bv.add_child(Kit.button("Stop and leave it", stop_busy, "ghost", 18))
	busy_panel.add_child(bv)
	busy_wrap.add_child(busy_panel)
	stack.add_child(busy_wrap)
	btn_row = Kit.hbox(8)
	bin_btn = Kit.button("Bin", bin, "ghost", 22)
	btn_row.add_child(bin_btn)
	auto_btn = Kit.button("Use the sheeter", sheeter, "ghost", 22)
	btn_row.add_child(auto_btn)
	next_btn = Kit.button("", next, "primary", 24)
	next_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_child(next_btn)
	bcol.add_child(btn_row)
	var right := Kit.vbox(8)
	right.custom_minimum_size.x = 320
	kitchen.add_child(right)
	var sp := Kit.panel(Kit.PANEL, 10)
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sv := Kit.vbox(6)
	info = Kit.vbox(3)
	palette = Kit.vbox(5)
	sv.add_child(info)
	sv.add_child(palette)
	sp.add_child(sv)
	right.add_child(sp)
	mini_panel = Kit.panel(Color("3a2a22"), 10)
	mini_box = Kit.vbox(3)
	mini_panel.add_child(mini_box)
	right.add_child(mini_panel)

	pop = Kit.panel(Kit.INK, 14)
	pop.visible = false
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pop.top_level = true
	add_child(pop)

## the clock, in minutes after midnight
func minute() -> float:
	return c.open + t * gm

## seconds of play that `mins` game minutes take
func secs(mins: float) -> float:
	return mins / gm

# ---------- being tied up ----------
## true if you are free; otherwise says what you are doing and returns false
func is_free() -> bool:
	if busy.is_empty(): return true
	Kit.main.toast("You are busy: %s" % busy.label.to_lower(), true)
	return false

func start_busy(label: String, mins: float, fn: Callable) -> void:
	busy = {"label": label, "left": secs(mins), "total": secs(mins), "fn": fn}
	dirty = true

## stop what you are doing: the job is left part-done
func stop_busy() -> void:
	if busy.is_empty(): return
	var frac: float = 1.0 - busy.left / max(busy.total, 0.001)
	var fn: Callable = busy.fn
	busy = {}
	fn.call(frac)
	dirty = true

func set_view(v: String) -> void:
	view = v
	if v != "board" and v != "bench": tool = ""
	if v == "board": tool = ""
	elif v == "bench" and bench != null and bench.stage == "top" and tool == "": tool = _first_tool(bench)
	dirty = true

func _speed() -> void:
	var mx := 8 if workers.size() > 0 else 4
	speed = 1 if speed >= mx else speed * 2
	top_lbl.speed.text = "%dx speed" % speed

# ---------- customers ----------
func set_pat(p: Dictionary, secs: float) -> void:
	if p.max > 0: p.waits.append(clamp(p.pat / p.max, 0.0, 1.0))
	p.max = secs * c.patience * randf_range(0.9, 1.1)
	p.pat = p.max

func spawn_party() -> int:
	var type := "take"
	if c.delivery > 0 and randf() < float(c.delivery) / c.total: type = "deliv"
	elif tables.size() > 0 and randf() < 0.65: type = "dine"
	var n: int = [1, 1, 1, 1, 2].pick_random()
	if type == "dine": n = [1, 2, 2, 2, 3, 3, 4].pick_random()
	elif type == "deliv": n = [1, 1, 2].pick_random()
	pid += 1
	var p := {"id": pid, "type": type, "n": n, "pos": L.spawn, "target": L.spawn, "state": "", "pat": 0.0, "max": 0.0, "tks": [], "got": 0, "items": [],
		"waits": [], "table": -1, "timer": 0.0, "gone": false, "look": randi() % 6, "hue": randf(), "nobox": false}
	if type == "deliv":
		if not order(p): return n
		p.pos = Vector2(-100, -100)
	elif type == "dine" and door.size() >= 4:
		p.type = "take"
		p.n = min(n, 2)
	if p.type == "dine":
		door.append(p)
		p.state = "door"
		set_pat(p, 55)
	elif p.type == "take":
		if queue.size() >= c.queue_cap:
			r.lost += p.n
			r.walked += p.n
			return n
		queue.append(p)
		p.state = "queue"
		set_pat(p, 55)
	parties.append(p)
	return n

## what the tickets nobody has started yet have already promised away
func _pending() -> Dictionary:
	var pend := {}
	for tk in tickets:
		if tk.state == "new" and tk.owner == "":
			pend["d:" + tk.rec.base] = pend.get("d:" + tk.rec.base, 0.0) + 1.0
			for i in tk.rec.spec: pend[i] = pend.get(i, 0.0) + tk.rec.spec[i]
	return pend

func can_promise(rec: Dictionary, pend: Dictionary) -> bool:
	if eighty6.has(rec.id): return false
	if Stock.dough_ready(rec.base) - pend.get("d:" + rec.base, 0.0) < 1: return false
	for i in rec.spec:
		if Stock.potential(i) - pend.get(i, 0.0) < rec.spec[i] * 0.7: return false
	return true

## could this pizza still be sold tonight at all (dough, and the toppings in stock or on the line)
func sellable(rec: Dictionary) -> bool:
	return can_promise(rec, {})

## the party orders a pizza each. false = there was nothing left to sell them.
func order(p: Dictionary) -> bool:
	for k in p.n:
		var pend := _pending()
		var avail := Game.active_recipes().filter(func(rc): return can_promise(rc, pend))
		if avail.is_empty(): break
		nid += 1
		var tk := {"id": nid - 1, "rec": avail.pick_random(), "p": p, "state": "new", "owner": "", "gone": false, "age": 0.0}
		tickets.append(tk)
		p.tks.append(tk)
	if p.tks.is_empty():
		r.sold += p.n
		Game.s.rep += (2.5 - Game.s.rep) * max(0.003, 0.3 / (Game.s.ratings + 10))
		float_text(p.pos, "Sold out!", Kit.TOMATO)
		leave(p)
		return false
	p.n = p.tks.size()
	p.state = "wait"
	set_pat(p, {"take": 100, "dine": 120, "deliv": 135}[p.type] + 20 * (p.n - 1))
	if p.type == "take":
		queue.erase(p)
		waiters.append(p)
	Art.sfx("ding")
	dirty = true
	return true

func leave(p: Dictionary) -> void:
	p.state = "leave"
	p.gone = true
	queue.erase(p)
	waiters.erase(p)
	door.erase(p)
	if p.table >= 0:
		tables[p.table].party = null
		p.table = -1
	if p.type == "deliv": parties.erase(p)

func ready_tks(p: Dictionary) -> Array:
	return p.tks.filter(func(tk): return tk.state == "pass")

func free_table():
	for tb in tables:
		if tb.party == null and not tb.dirty: return tb
	return null

func act_seat(p: Dictionary) -> bool:
	var tb = free_table()
	if tb == null: return false
	door.erase(p)
	tb.party = p
	p.table = tb.i
	p.state = "sit"
	p.timer = 4.0
	set_pat(p, 60)
	return true

## hand over (or run to the table) every pizza of this party that is on the pass
func act_handover(p: Dictionary) -> void:
	for tk in ready_tks(p):
		tickets.erase(tk)
		tk.state = "done"
		p.got += 1
		var it: Dictionary = tk.res
		it.price = tk.rec.price
		if p.type != "dine":
			var bx := Stock.take("box", 1.0)
			if bx.got >= 1.0:
				it.cost += bx.cost
				it.spec_cost += bx.cost
				it.use["box"] = 1.0
				it.spec["box"] = 1.0
			else:
				p.nobox = true
		p.items.append(it)
	dirty = true
	if p.got < p.n: return
	if p.type == "dine":
		p.waits.append(clamp(p.pat / p.max, 0.0, 1.0))
		p.state = "eat"
		p.timer = 24.0 * c.turn
	else:
		settle(p, false)
		leave(p)

func act_bill(p: Dictionary) -> void:
	var tb = tables[p.table]
	settle(p, false)
	leave(p)
	tb.dirty = true

## The customer's verdict. They judge four things, each out of 5:
##   look     how the pizza looked: shape, spread of toppings, colour of the bake, slicing
##   taste    how well it was made, lifted or dragged down by the quality of the ingredients for the price
##   service  how long each stage kept them waiting, and whether there was a box
##   value    taste against what you charge
## The overall rating moves your reputation. Tips are more likely, and bigger, the better all of it was,
## and better ingredients raise both.
func settle(p: Dictionary, walked: bool) -> void:
	var G := Game
	var n: int = p.items.size()
	if n == 0: return
	var expect: float = [1.6, 2.4, 3.4][G.s.price]     # ingredient grade people expect at this price level
	var paid := 0.0
	var look := 0.0
	var taste := 0.0
	var grade := 0.0
	var notes := []
	for it in p.items:
		var tt: float = clamp(it.taste + (it.grade - expect) * 7.0, 0.0, 100.0)
		look += it.look / n
		taste += tt / n
		grade += it.grade / n
		if tt >= 30.0: paid += it.price * c.price_mult
		for nt in it.notes:
			if not notes.has(nt): notes.append(nt)
		Stock.log_sale(it.use, it.spec, it.cost, it.spec_cost)
		r.qsum += (it.look + tt) / 2.0
	p.waits.append(clamp(p.pat / p.max, 0.0, 1.0))
	var pf := 0.0
	for w in p.waits: pf += w / p.waits.size()
	var dine: bool = p.type == "dine"
	var service: float = 100.0 * (0.2 + 0.8 * pf) + (c.rep_bonus * 20.0 if dine else 0.0)
	if p.nobox:
		service -= 30.0
		notes.push_front("No box to take it home in")
	if walked: service -= 30.0
	var foh_clean := Hygiene.level("foh")
	if foh_clean < 60.0:
		service -= (60.0 - foh_clean) * 0.7
		notes.push_front("Sticky tables" if dine else "Grubby counter")
	if minute() < mouse_until:
		service -= 25.0
		notes.push_front("Saw a mouse!")
	Hygiene.dirty("foh", (1.5 if dine else 0.6) * 30.0 * n / max(10.0, float(c.total)))
	service = clamp(service, 0.0, 100.0)
	var value: float = clamp(55.0 + (taste - 65.0) * 0.9 + [16.0, 0.0, -16.0][G.s.price], 0.0, 100.0)
	var overall := look * 0.2 + taste * 0.4 + service * 0.25 + value * 0.15
	var stars: float = clamp(1.0 + overall / 25.0, 1.0, 5.0)
	var tip := 0.0
	if paid > 0 and not walked:
		var chance: float = clamp(0.05 + (overall - 55.0) / 70.0 + (grade - 2.0) * 0.1 + (0.12 if dine else 0.0), 0.02, 0.97)
		if randf() < chance:
			tip = paid * (0.05 + 0.03 * grade + 0.04 * look / 100.0) * c.tip * (1.4 if dine else 1.0) * (0.5 + 0.5 * pf)
	var drinks: float = c.drinks * n * (1.0 if dine else 0.35) * randf_range(0.6, 1.4)
	var deliv := 2.5 if p.type == "deliv" else 0.0
	G.s.ratings += 1
	G.s.rep = clamp(G.s.rep + (stars - G.s.rep) * max(0.02, 1.0 / (G.s.ratings + 4)), 1.0, 5.0)
	var total := paid + tip + drinks + deliv
	G.s.cash += total
	G.s.earned += total
	G.s.pizzas += n
	G.s.book.sales += paid
	r.food += paid
	r.tips += tip
	r.drinks += drinks
	r.deliv += deliv
	r.served += n
	var cats := {"look": 1.0 + look / 25.0, "taste": 1.0 + taste / 25.0, "service": 1.0 + service / 25.0, "value": 1.0 + value / 25.0}
	for k in cats: r.cats[k] += cats[k]
	r.n_rev += 1
	var rv := {"stars": stars, "tip": tip, "text": _review_text(cats, notes), "t": t}
	rv.merge(cats)
	reviews.append(rv)
	if reviews.size() > 60: reviews.pop_front()
	float_text(p.pos, "%.1f stars  %s%s" % [stars, ("+" + Kit.cents(paid)) if paid > 0 else "refunded", ("  tip " + Kit.cents(tip)) if tip > 0 else ""], Kit.CHEESE if paid > 0 else Kit.TOMATO)
	Art.sfx("cash" if paid > 0 else "bad")

func _review_text(cats: Dictionary, notes: Array) -> String:
	var worst := "look"
	var best := "look"
	for k in cats:
		if cats[k] < cats[worst]: worst = k
		if cats[k] > cats[best]: best = k
	if cats[worst] < 3.3:
		if notes.size() > 0 and (worst == "look" or worst == "taste"): return notes[0] + "."
		return {"look": "It looked a mess when I opened the box.", "taste": "Did not taste of much.", "service": "Waited far too long.", "value": "Not worth the money."}[worst]
	if cats[best] >= 4.4:
		return {"look": "Almost too pretty to eat.", "taste": "Best pizza I have had in ages.", "service": "Quick, friendly, no fuss.", "value": "Great value for what you get."}[best]
	return (notes[0] + ", but decent.") if notes.size() > 0 else "Solid pizza."

## a pizza that was made (or part-made) and will never be sold
func _waste_tk(tk: Dictionary) -> void:
	if tk.has("res"): Stock.log_binned(tk.res.use, tk.res.cost)
	elif tk.has("made"): Stock.log_binned(tk.made.use, tk.made.cost)

func _waste_pizza(pz: Pizza) -> void:
	var use: Dictionary = pz.grams.duplicate()
	use["dough:" + pz.rec.base] = 1.0
	Stock.log_binned(use, pz.cost)

func expire(p: Dictionary, why: String = "Gave up waiting") -> void:
	var G := Game
	if p.state == "bill":
		var tb = tables[p.table]
		settle(p, true)
		leave(p)
		tb.dirty = true
		return
	r.lost += p.n - p.got
	r.gave_up += p.n - p.got
	G.s.rep += (1.5 - G.s.rep) * max(0.02, 1.0 / (G.s.ratings + 6)) * 0.35
	for tk in p.tks:
		if tk.state == "done": continue
		tk.gone = true
		tickets.erase(tk)
		_waste_tk(tk)
	for w in workers:
		if w.job != null and w.job.gone: w.job = null
	oven.items = oven.items.filter(func(o): return not (o.owner == "staff" and o.tk.gone))
	var tb = tables[p.table] if p.table >= 0 else null
	float_text(p.pos, why, Kit.TOMATO)
	if p.got > 0: settle(p, true)
	leave(p)
	if tb != null and p.got > 0: tb.dirty = true
	Art.sfx("bad")
	dirty = true

func float_text(pos: Vector2, text: String, col: Color) -> void:
	if pos.x < 0: pos = L.win
	floats.append({"pos": pos, "text": text, "col": col, "t": 2.2})

## everything out front that you (or the staff) can act on right now
func actionables() -> Array:
	var out := []
	if queue.size() > 0 and queue[0].pos.distance_to(q_pos(0)) < 6: out.append({"kind": "order", "p": queue[0], "pos": queue[0].pos})
	for p in waiters:
		if ready_tks(p).size() > 0: out.append({"kind": "food", "p": p, "pos": p.pos})
	if door.size() > 0 and free_table() != null and door[0].pos.distance_to(d_pos(0)) < 6: out.append({"kind": "seat", "p": door[0], "pos": door[0].pos})
	for tb in tables:
		var p = tb.party
		if p == null:
			if tb.dirty: out.append({"kind": "clear", "tb": tb, "pos": tb.pos})
		elif p.state == "ask": out.append({"kind": "order", "p": p, "pos": tb.pos})
		elif p.state == "wait" and ready_tks(p).size() > 0: out.append({"kind": "food", "p": p, "pos": tb.pos})
		elif p.state == "bill": out.append({"kind": "bill", "p": p, "pos": tb.pos})
	return out

func do_action(a: Dictionary, by_player: bool) -> void:
	match a.kind:
		"order":
			if order(a.p) and by_player: r.xp += 1
		"food": act_handover(a.p)
		"seat": act_seat(a.p)
		"bill": act_bill(a.p)
		"clear": a.tb.dirty = false

func tap_scene(pos: Vector2) -> void:
	if L.back.distance_to(pos + Vector2(0, 14)) < 50 and Game.s.dock.size() > 0:
		set_view("prep")
		return
	if not is_free(): return
	var best = null
	for a in actionables():
		var dd: float = a.pos.distance_to(pos + Vector2(0, 14))
		if dd < 60 and (best == null or dd < best.pos.distance_to(pos + Vector2(0, 14))): best = a
	if best != null:
		do_action(best, true)
		Art.sfx("tap")

# ---------- simulation ----------
func _process(delta: float) -> void:
	if done: return
	var real: float = min(delta, 0.1)
	for i in speed:
		if not done: step(real)
	if done: return
	if pop_t > 0:
		pop_t -= real
		if pop_t <= 0: pop.visible = false
	_refresh()
	if view == "front": front.queue_redraw()
	elif view == "oven": oven_ui.queue_redraw()
	else: bench_ui.queue_redraw()

func step(dt: float) -> void:
	var G := Game
	t += dt
	var now := minute()
	if not busy.is_empty():
		busy.left -= dt
		if busy.left <= 0:
			var fn: Callable = busy.fn
			busy = {}
			fn.call(1.0)
			dirty = true
	# deliveries turning up at the back door
	if Day.next_arrival() >= 0 and Day.next_arrival() <= now:
		for nt in Day.arrivals(now): r.notes.append(nt)
		Kit.main.toast("A delivery is at the back door")
		Art.sfx("ding")
		dirty = true
	_crew_step(dt)
	# the inspector
	var at: float = G.s.hygiene.get("at", -1.0)
	if at >= 0 and at <= now and not done:
		r.inspect = Hygiene.inspect()
		var res: Dictionary = r.inspect
		Kit.main.message("Food hygiene inspection", "The inspector called in at %s and rated you %s.%s" % [Data.hhmm(now), Hygiene.rating_text(), ("\n\n" + "\n".join(res.notes)) if res.notes.size() > 0 else "\n\nNo problems found."] + ("\n\nYou are closed until you sort it out." if res.closed else ""), "OK")
		if res.closed:
			r.closed = true
			finish(false)
			return
	# mice
	if mouse.is_empty() and randf() < Hygiene.sighting_rate() * gm * dt:
		_mouse()
	if not mouse.is_empty():
		mouse.t -= dt
		mouse.pos += mouse.vel * dt
		if mouse.t <= 0: mouse = {}
	if t < DAY * 0.94:
		acc += c.total / DAY * (0.55 + 0.9 * sin(PI * t / DAY)) / 1.123 / 0.94 * dt
		while acc >= 1.0: acc -= spawn_party()
	# customers
	for i in queue.size(): queue[i].target = q_pos(i)
	for i in waiters.size(): waiters[i].target = w_pos(i)
	for i in door.size(): door[i].target = d_pos(i)
	for p in parties.duplicate():
		if p.table >= 0: p.target = tables[p.table].pos
		elif p.state == "leave": p.target = L.spawn
		p.pos = p.pos.move_toward(p.target, 170 * dt)
		match p.state:
			"leave":
				if p.pos.distance_to(L.spawn) < 4: parties.erase(p)
			"sit":
				if p.pos.distance_to(p.target) < 4:
					p.timer -= dt
					if p.timer <= 0: p.state = "ask"
			"eat":
				p.timer -= dt
				if p.timer <= 0:
					p.state = "bill"
					set_pat(p, 60)
			"queue", "door", "ask", "wait", "bill":
				p.pat -= dt
				if p.pat <= 0: expire(p)
	for f in floats.duplicate():
		f.t -= dt
		f.pos.y -= 16 * dt
		if f.t <= 0: floats.erase(f)
	# front-of-house staff
	for w in foh:
		w.cd -= dt
		if w.cd > 0: continue
		var acts := actionables()
		var want := []
		match w.role:
			"cashier": want = acts.filter(func(a): return a.has("p") and a.p.type == "take" and a.kind in ["order", "food"])
			"server":
				for kind in ["food", "order", "bill", "seat", "clear"]:
					want = acts.filter(func(a): return a.kind == kind and not (a.has("p") and a.p.type == "take"))
					if want.size() > 0: break
			"host": want = acts.filter(func(a): return a.kind == "seat")
			"porter": want = acts.filter(func(a): return a.kind == "clear")
			"driver":
				for p in parties:
					if p.type == "deliv" and p.state == "wait" and ready_tks(p).size() > 0:
						act_handover(p)
						w.cd = 1.5
						break
		if want.size() > 0:
			do_action(want[0], false)
			w.cd = {"cashier": 2.6, "server": 3.2, "host": 1.6, "porter": 4.0, "driver": 1.5}[w.role] - 0.32 * w.s.skill
	# pizzaioli
	for tk in tickets: tk.age += dt
	for w in workers:
		if w.job != null:
			w.left -= dt
			var slot := oven.free_slot()
			if w.left <= 0 and slot >= 0:
				oven.load_staff(w.job, slot)
				w.job.state = "oven"
				w.job = null
		if w.get("prep", "") != "":
			w.left -= dt
			if w.left <= 0:
				Stock.prep(w.prep, w.raw)
				prepping.erase(w.prep)
				w.prep = ""
				dirty = true
			continue
		if w.job == null:
			for tk in tickets:
				if tk.state != "new" or tk.owner != "" or tk.age <= 1.2: continue
				if G.can_make(tk.rec):
					tk.made = staff_make(w.s, tk.rec)
					tk.owner = w.s.name
					tk.state = "make"
					w.job = tk
					w.left = 10.0 * (1.25 - 0.1 * w.s.skill) / c.prep_speed
					dirty = true
					break
				# the line has run out of something: with no prep cook on, the pizzaiolo preps it
				if G.staff_of("prep").is_empty():
					var need: Array = G.needs_prepping(tk.rec).filter(func(i): return not prepping.has(i))
					if need.size() > 0:
						var id: String = need[0]
						w.prep = id
						w.raw = batch_raw(id)
						w.left = secs(Stock.prep_minutes(id, w.raw, Day.prep_mult() * (1.25 - 0.08 * w.s.skill)))
						prepping[id] = w.s.name
						dirty = true
						break
	# oven
	for o in oven.step(dt, c.bake / oven.bake_time): to_pass(o.tk, staff_result(o.tk))
	if c.fornaio:
		for o in oven.mine():
			if o.pz.bake_avg() >= 1.0: oven_pull(o)
	# the oven tender keeps the fire just right; without one, a pizzaiolo throws a log on when it gets low
	if oven.def.feeds and (oven.fire < 0.85 if c.fornaio else (oven.fire < 0.55 and workers.size() > 0)):
		var lg := Stock.take("wood", 1.0)
		if lg.got >= 1.0: oven.add_log(lg.g)
	# end of day
	var idle: bool = tickets.is_empty() and bench == null and board.is_empty() and oven.items.is_empty() and oven.shelf.is_empty()
	var anyone := parties.any(func(p): return p.state != "leave")
	if idle and not anyone and t >= DAY: finish(false)
	elif idle and t > 5 and not anyone and busy.is_empty() and not G.active_recipes().any(func(rc): return sellable(rc)): finish(true)

## a pizzaiolo takes the dough and weighs out the toppings. Less skilled cooks are heavier-handed.
func staff_make(x: Dictionary, rec: Dictionary) -> Dictionary:
	var dq := Stock.take_dough(rec.base)
	var over: float = max(0.0, 0.16 - 0.03 * x.skill - c.chef * 0.004) + randf_range(-0.02, 0.03)
	var m := {"skill": x.skill, "dough_q": dq.q, "use": {"dough:" + rec.base: 1.0}, "spec": rec.spec.duplicate(), "cost": dq.cost, "spec_cost": dq.cost, "short": 0}
	m.spec["dough:" + rec.base] = 1.0
	var gw: float = Data.DOUGHS[rec.base].ball * 0.4
	var gsum: float = dq.g * gw
	for id in rec.spec:
		var got := Stock.take_use(id, rec.spec[id] * (1.0 + over))
		m.use[id] = got.got
		m.cost += got.cost
		m.spec_cost += rec.spec[id] * (got.cost / got.got if got.got > 0 else 0.0)
		gsum += got.g * got.got
		gw += got.got
		if got.got < rec.spec[id] * 0.85: m.short += 1
	m.grade = gsum / gw
	return m

func staff_result(tk: Dictionary) -> Dictionary:
	var m: Dictionary = tk.made
	var a := {"mine": false, "notes": [], "grade": m.grade, "cost": m.cost, "spec_cost": m.spec_cost, "use": m.use, "spec": m.spec}
	a.look = clamp(46.0 + m.skill * 8.0 + c.chef * 0.6 + c.prep_q + randf_range(-7, 7), 15.0, 97.0)
	a.taste = clamp(44.0 + m.skill * 8.0 + c.chef + c.oven_q * 0.5 + c.prep_q + (m.dough_q - 60.0) * 0.15 - m.short * 12.0 + randf_range(-5, 5), 15.0, 98.0)
	if m.short > 0: a.notes.append("Something was missing from it")
	return a

func to_pass(tk: Dictionary, res: Dictionary) -> void:
	dirty = true
	Hygiene.dirty("boh", 45.0 / max(10.0, float(c.total)))
	if tk.gone:
		Stock.log_binned(res.use, res.cost)
		return
	tk.state = "pass"
	tk.res = res
	r.xp += (10.0 + (res.look + res.taste) / 16.0) if res.mine else 4.0
	if res.mine: r.mine += 1

# ---------- your bench ----------
func claim(tk: Dictionary) -> void:
	if tk.state != "new" or tk.owner != "": return
	if not is_free(): return
	if bench != null:
		Kit.main.toast("Finish the pizza on your bench first", true)
		return
	var dq := Stock.take_dough(tk.rec.base)
	if dq.is_empty():
		Kit.main.toast("No %s dough balls left" % Data.DOUGHS[tk.rec.base].name, true)
		return
	tk.owner = "me"
	tk.state = "make"
	bench = Pizza.new(tk, dq)
	tool = ""
	set_view("bench")
	Art.sfx("tap")

func _first_tool(pz: Pizza) -> String:
	for id in [pz.rec.sauce, pz.rec.cheese] + pz.rec.tops:
		if id != "" and not Data.ING[id].after and Stock.have(id) > 0: return id
	return ""

func next() -> void:
	if not is_free(): return
	if view == "board":
		serve()
		return
	if bench == null: return
	if bench.stage == "shape":
		bench.stage = "top"
		tool = _first_tool(bench)
	else:
		if c.fornaio:
			var slot := oven.free_slot()
			if slot < 0:
				Kit.main.toast("The oven is full", true)
				return
			oven.load_pizza(bench, slot, true)
			bench.tk.state = "oven"
			bench = null
			tool = ""
		else:
			if oven.shelf.size() >= Oven.SHELF:
				Kit.main.toast("The shelf is full. Put those pizzas in the oven first", true)
				return
			bench.stage = "shelf"
			oven.shelf.append(bench)
			bench = null
			set_view("oven")
	dirty = true
	Art.sfx("tap")

func bin() -> void:
	var pz: Pizza = (board.pop_front() if board.size() > 0 else null) if view == "board" else bench
	if pz == null: return
	if view != "board": bench = null
	_waste_pizza(pz)
	if not pz.tk.gone:
		pz.tk.owner = ""
		pz.tk.state = "new"
	if view == "board" and board.is_empty(): view = "bench"
	tool = ""
	dirty = true

func sheeter() -> void:
	if bench == null or bench.stage != "shape" or bench.base.method != "roll" or c.roll_auto <= 0: return
	bench.base.sheet(c.roll_auto)

## your hand with whatever is in it, at p on the pizza (prev = where it was a moment ago, or null for a tap)
func apply_tool(p: Vector2, prev) -> void:
	if not busy.is_empty(): return
	var on_board: bool = view == "board"
	var pz: Pizza = (board[0] if board.size() > 0 else null) if on_board else bench
	if pz == null or tool == "" or (not on_board and pz.stage != "top"): return
	var it: Dictionary = Data.ING[tool]
	if it.kind == "top":
		if pz.add_top(tool, p, on_board) == "out": _ran_out()
		return
	if on_board: return
	var brush: float = 17.0 + c.brush
	var from: Vector2 = p if prev == null else prev
	var dist := from.distance_to(p)
	var steps: int = max(1, int(ceil(dist / (brush * 0.6))))
	for i in steps:
		if not pz.spread(tool, from.lerp(p, float(i + 1) / steps), (dist / steps) if prev != null else brush, brush):
			_ran_out()
			break

func _ran_out() -> void:
	Kit.main.toast("You have run out of " + Data.ING[tool].name.to_lower(), true)
	tool = ""
	dirty = true

## a swipe of the pizza wheel from a to b
func cut(a: Vector2, b: Vector2) -> void:
	if view != "board" or board.is_empty() or not is_free(): return
	var pz: Pizza = board[0]
	var ln := a.distance_to(b)
	if ln < pz.base.R * 1.2: return
	var dd: float = abs(a.x * b.y - a.y * b.x) / ln
	if dd < pz.base.R * 0.35 and pz.cuts.size() < 4:
		pz.cuts.append({"a": a, "b": b, "d": dd})
		Art.sfx("tap")
	elif dd >= pz.base.R * 0.35:
		Kit.main.toast("Cut through the middle", true)

# ---------- your oven ----------
func oven_load(pz: Pizza, slot: int) -> void:
	if not is_free(): return
	oven.load_pizza(pz, slot, false)
	pz.tk.state = "oven"
	dirty = true
	Art.sfx("tap")

func oven_pull(o: Dictionary) -> void:
	oven.items.erase(o)
	o.pz.stage = "board"
	if not o.pz.tk.gone: o.pz.tk.state = "board"
	board.append(o.pz)
	if view == "oven" and oven.mine().is_empty() and oven.shelf.is_empty(): set_view("board")
	dirty = true
	Art.sfx("tap")

func add_log() -> void:
	var lg := Stock.take("wood", 1.0)
	if lg.got >= 1.0: oven.add_log(lg.g)
	else: Kit.main.toast("No firewood left", true)

func serve() -> void:
	if board.is_empty(): return
	var pz: Pizza = board[0]
	if pz.tk.gone:
		var alt = null
		for tk in tickets:
			if tk.state == "new" and tk.owner == "" and tk.rec == pz.rec: alt = tk
		if alt == null:
			board.pop_front()
			_waste_pizza(pz)
			if board.is_empty(): set_view("bench")
			Kit.main.toast("That customer left. The pizza is binned", true)
			return
		alt.owner = "me"
		pz.tk = alt
	var a := pz.assess(c)
	a.mine = true
	to_pass(pz.tk, a)
	board.pop_front()
	_show_result(pz, a)
	if board.is_empty():
		set_view("bench" if bench != null else ("oven" if oven.mine().size() + oven.shelf.size() > 0 else "front"))

func _show_result(pz: Pizza, a: Dictionary) -> void:
	Kit.clear(pop)
	var v := Kit.vbox(2)
	v.add_child(Kit.label(pz.rec.name, 24, Kit.DARK))
	v.add_child(Kit.label("Look %d   Taste %d" % [a.look, a.taste], 21, Kit.DARK))
	v.add_child(Kit.label("Base %d · Cover %d · Portions %d · Layout %d · Bake %d · Colour %d · Cut %d" % [a.shape * 100, a.cover * 100, a.portion * 100, a.layout * 100, a.bake * 100, a.colour * 100, a.cut * 100], 15, Color("5b6a58")))
	for nt in a.notes.slice(0, 3): v.add_child(Kit.label(nt, 17, Color("a0331f")))
	var over: float = a.cost - a.spec_cost
	v.add_child(Kit.label("Cost %s to make. The recipe card allows %s." % [Kit.cents(a.cost), Kit.cents(a.spec_cost)], 16, Color("a0331f") if over > a.spec_cost * 0.12 else Color("2d7a33")))
	v.add_child(Kit.label("It is on the pass. Hand it over out front.", 16, Color("5b6a58")))
	pop.add_child(v)
	pop.visible = true
	pop.reset_size()
	pop.position = kitchen.global_position + Vector2(16, 16) if kitchen.visible else front.global_position + Vector2(16, 16)
	pop_t = 4.5

# ---------- ui refresh ----------
func _refresh() -> void:
	var G := Game
	clock.value = clamp(t / DAY, 0, 1)
	top_lbl.time.text = ("Last orders " if t >= DAY else "") + Data.hhmm(min(minute(), c.close))
	top_lbl.cash.text = Kit.money(G.s.cash)
	top_lbl.rep.text = "Rating %.1f" % G.s.rep
	top_lbl.count.text = "Served %d · Lost %d" % [r.served, r.lost + r.sold]
	var dn := 0
	var styles := {}
	for rc in G.active_recipes(): styles[rc.base] = true
	for st in styles: dn += Stock.dough_ready(st)
	top_lbl.dough.text = "Dough %d" % dn
	for id in tick_bars:
		var e = tick_bars[id]
		if is_instance_valid(e.bar): e.bar.value = clamp(e.tk.p.pat / max(1.0, e.tk.p.max), 0, 1)
	var flag := ""
	for o in oven.mine():
		var st := oven.status(o)
		if st == "BURNING" or st == "OVERDONE": flag = "  BURNING!"
		elif st == "READY" and flag == "": flag = "  READY"
		elif st == "TURN" and flag == "": flag = "  TURN"
	var acts := actionables().size()
	tab_btns.front.text = "Front" + (" (%d)" % acts if acts > 0 else "")
	tab_btns.bench.text = "Bench"
	var in_oven: int = oven.mine().size() + oven.shelf.size()
	tab_btns.oven.text = "Oven" + (" (%d)" % in_oven if in_oven > 0 else "") + flag
	tab_btns.board.text = "Board (%d)" % board.size()
	var low := 0
	for id in line_items():
		if Stock.prepped(id) < per_pizza(id) * 3.0: low += 1
	tab_btns.prep.text = "Prep" + (" (%d low)" % low if low > 0 else "") + ("  DELIVERY" if Game.s.dock.size() > 0 else "")
	busy_wrap.visible = not busy.is_empty() and view != "front"
	if not busy.is_empty():
		busy_lbl.text = busy.label + "\n%d s left" % ceil(busy.left)
		busy_bar.value = 1.0 - busy.left / max(busy.total, 0.001)
	for row in info_rows:
		if not is_instance_valid(row[0]): continue
		var res: Array = row[1].call()
		row[0].text = res[0]
		row[0].add_theme_color_override("font_color", res[1])
	for e in pal_btns:
		if not is_instance_valid(e[0]): continue
		var id: String = e[1]
		var a := Stock.avail(id)
		e[0].text = "%s\n%s" % [Data.ING[id].name, Data.qty(id, a) if a > 0 or not Data.needs_prep(id) else "needs prep"]
	if not dirty: return
	dirty = false
	for k in tab_btns:
		var on: bool = view == k
		tab_btns[k].add_theme_stylebox_override("normal", Kit.box(Kit.PANEL2 if on else Kit.PANEL, 10, 8))
		tab_btns[k].add_theme_color_override("font_color", Kit.INK if on else Kit.MUTED)
	front.visible = view == "front"
	kitchen.visible = view != "front"
	bench_ui.visible = view == "bench" or view == "board"
	oven_ui.visible = view == "oven"
	prep_scroll.visible = view == "prep"
	_build_tickets()
	_build_side()
	_build_prep()

func _build_tickets() -> void:
	Kit.clear(tick_box)
	tick_bars = {}
	var shown := 0
	for tk in tickets:
		if shown >= 9: break
		shown += 1
		var status := "Tap to make it"
		var col := Kit.INK
		if tk.state == "pass":
			status = "READY: hand it over out front"
			col = Kit.BASIL
		elif tk.owner == "me":
			status = "You: " + {"oven": "in the oven", "board": "on the board, slice it"}.get(tk.state, "making it")
			col = Kit.CHEESE
		elif tk.owner != "":
			status = tk.owner + (": in the oven" if tk.state == "oven" else ": making it")
			col = Color("c9d3c4")
		var where: String = {"take": "Takeaway", "dine": "Table %d" % (tk.p.table + 1), "deliv": "Delivery"}[tk.p.type]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "#%d %s\n%s · %s\n%s" % [tk.id, tk.rec.name, where, Data.DOUGHS[tk.rec.base].name, status]
		b.add_theme_font_size_override("font_size", 16)
		for stn in ["normal", "hover", "pressed"]: b.add_theme_stylebox_override(stn, Kit.box(col, 8, 8))
		for cn in ["font_color", "font_hover_color", "font_pressed_color"]: b.add_theme_color_override(cn, Kit.DARK)
		b.pressed.connect(claim.bind(tk))
		tick_box.add_child(b)
		var bar := Kit.bar(1, Kit.BASIL, 5)
		tick_box.add_child(bar)
		tick_bars[tk.id] = {"bar": bar, "tk": tk}
	if tickets.size() > shown: tick_box.add_child(Kit.label("+%d more waiting" % (tickets.size() - shown), 16, Kit.MUTED))
	if tickets.is_empty(): tick_box.add_child(Kit.label("No orders yet. Customers order out front.", 16, Kit.MUTED, true))

func _info(fn: Callable, size: int = 17) -> void:
	var l := Kit.label("", size, Kit.INK, true)
	info.add_child(l)
	info_rows.append([l, fn])

func _gram_row(pz: Pizza, id: String) -> void:
	_info(func():
		var g: float = pz.grams.get(id, 0.0)
		var ratio := pz.portion(id)
		var col := Kit.INK if ratio < 0.85 else (Kit.BASIL if ratio <= 1.2 else Kit.TOMATO)
		return ["%s   %s of %s" % [Data.ING[id].name, Data.qty(id, g), Data.qty(id, pz.spec_of(id))], col])

func _tool_button(id: String, need: bool) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 14)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.y = 46
	var bg: Color = Color(Data.ING[id].col).darkened(0.25)
	for stn in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(stn, Kit.box(bg, 8, 3, Kit.CHEESE if tool == id else (Kit.INK if need else Color(0, 0, 0, 0)), 4 if tool == id else (1 if need else 0)))
	var fgc := Color.BLACK if bg.get_luminance() > 0.5 else Color.WHITE
	for cn in ["font_color", "font_hover_color", "font_pressed_color"]: b.add_theme_color_override(cn, fgc)
	b.pressed.connect(func():
		if Data.needs_prep(id) and Stock.prepped(id) <= 0.0:
			Kit.main.toast("No %s %s on the line. Prep some, or 86 the pizzas that need it." % [Data.ING[id].prep.as, Data.ING[id].name.to_lower()], true)
			set_view("prep")
			return
		tool = id
		dirty = true)
	pal_btns.append([b, id])
	return b

func _build_side() -> void:
	Kit.clear(info)
	Kit.clear(palette)
	Kit.clear(mini_box)
	info_rows = []
	pal_btns = []
	var pz: Pizza = null
	if view == "board" and board.size() > 0: pz = board[0]
	elif view == "bench": pz = bench
	btn_row.visible = view != "oven" and view != "prep"
	next_btn.visible = pz != null
	bin_btn.visible = pz != null
	auto_btn.visible = pz != null and view == "bench" and pz.stage == "shape" and pz.base.method == "roll" and c.roll_auto > 0
	mini_panel.visible = view != "oven" and oven.mine().size() + oven.shelf.size() > 0
	if mini_panel.visible:
		mini_box.add_child(Kit.label("IN THE OVEN", 14, Kit.MUTED))
		for o in oven.mine():
			var lb := Kit.label("", 16)
			mini_box.add_child(lb)
			info_rows.append([lb, func():
				var st := oven.status(o)
				return ["%s: %s" % [o.pz.rec.name, ("baking %d%%" % (o.pz.bake_avg() * 100)) if st == "baking" else st], Kit.BASIL if st == "READY" else (Kit.TOMATO if st in ["BURNING", "OVERDONE"] else (Kit.CHEESE if st == "TURN" else Kit.INK))]])
		if oven.shelf.size() > 0: mini_box.add_child(Kit.label("%d waiting on the shelf" % oven.shelf.size(), 16, Kit.CHEESE))
	if view == "oven":
		_side_oven()
		return
	if view == "prep":
		_side_prep()
		return
	if pz == null:
		info.add_child(Kit.label("Tap an order on the left to start it. Open the base, top it by weight, bake it, slice it, send it to the pass.", 17, Kit.MUTED, true))
		return
	info.add_child(Kit.label("#%d %s" % [pz.tk.id, pz.rec.name], 21))
	if view == "board":
		next_btn.text = "Send to the pass"
		var finishing: Array = pz.rec.tops.filter(func(id): return Data.ING[id].after)
		info.add_child(Kit.label("Swipe across the pizza to slice it: three cuts through the middle." + ("  Then add the toppings that go on after the oven." if finishing.size() > 0 else ""), 16, Kit.MUTED, true))
		_info(func(): return ["Cuts: %d of 3" % pz.cuts.size(), Kit.BASIL if pz.cuts.size() >= 3 else Kit.INK])
		for id in finishing: _gram_row(pz, id)
		if finishing.size() > 0:
			var g := Kit.grid(2, 5)
			var wheel := Kit.button("Pizza wheel", func():
				tool = ""
				dirty = true, "primary" if tool == "" else "ghost", 15)
			wheel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			g.add_child(wheel)
			for id in finishing: g.add_child(_tool_button(id, true))
			palette.add_child(g)
		return
	if pz.stage == "shape":
		next_btn.text = "Base is ready"
		var b := pz.base
		var how: String = {
			"hand": "1. Press the ball out from the middle with one finger. Stop short of the edge to leave a rim.\n2. Put two fingers on the dough and spread them to stretch it out to the ring. Twist them to turn the dough.",
			"roll": "Roll the pin back and forth across the dough with a finger. Keep changing direction or it goes oval. No rim on this one.",
			"press": "Rub the dough outward until it reaches the wall of the pan all the way round."}[b.method]
		info.add_child(Kit.label(how, 15, Kit.MUTED, true))
		if b.method == "hand" and not DisplayServer.is_touchscreen_available():
			info.add_child(Kit.label("With a mouse: left button is one finger, right button is two.", 14, Kit.MUTED, true))
		_info(func(): return ["Size %.1f cm of %d cm" % [b.diameter_cm(), pz.d.size_cm], Kit.BASIL if abs(b.diameter_cm() - pz.d.size_cm) < pz.d.size_cm * 0.06 else Kit.INK])
		_info(func(): return ["Thickness %.1f mm (aim for %.1f)" % [b.thickness_mm(), b.target_thickness_mm()], Kit.INK])
		_info(func(): return ["Rim %.1f cm (aim for %.1f)" % [b.crust_cm(), pz.d.crust_cm], Kit.BASIL if abs(b.crust_cm() - pz.d.crust_cm) < 0.6 else Kit.INK])
		_info(func(): return ["%s base: %d%%" % [pz.d.name, b.score().total * 100], Kit.CHEESE], 19)
		return
	next_btn.text = "To the oven"
	info.add_child(Kit.label("Recipe card: grams on the pizza against grams allowed.", 14, Kit.MUTED, true))
	for id in [pz.rec.sauce, pz.rec.cheese] + pz.rec.tops:
		if id == "": continue
		if Data.ING[id].after:
			info.add_child(Kit.label("%s   goes on after the oven" % Data.ING[id].name, 16, Kit.MUTED))
		else:
			_gram_row(pz, id)
	_info(func(): return ["On the pizza so far: %s" % Kit.cents(pz.cost), Kit.MUTED], 15)
	var used := {}
	for rc in Game.active_recipes():
		for i in rc.spec:
			if not Data.ING[i].after: used[i] = true
	var g := Kit.grid(2, 5)
	for id in used: g.add_child(_tool_button(id, pz.rec.spec.has(id)))
	palette.add_child(g)

func _side_oven() -> void:
	info.add_child(Kit.label(oven.tier.n, 20))
	info.add_child(Kit.label(oven.def.help, 15, Kit.MUTED, true))
	if c.fornaio: info.add_child(Kit.label("Your oven tender is loading, turning and pulling for you.", 15, Kit.BASIL, true))
	if oven.def.feeds:
		_info(func():
			var f := oven.fire
			var word := "dying" if f < 0.6 else ("low" if f < 0.85 else ("just right" if f <= 1.15 else "fierce"))
			return ["Fire: %s (%d%%)" % [word, f * 100], Kit.BASIL if f >= 0.85 and f <= 1.15 else Kit.CHEESE], 19)
		var lb := Kit.button("", add_log, "primary", 18)
		palette.add_child(lb)
		info_rows.append([lb, func(): return ["Add a log (%d left)" % int(Stock.have("wood")), Kit.DARK]])
	for o in oven.mine():
		_info(func():
			var rng: Array = o.pz.bake_range()
			return ["%s: %s, %d%% done (%d%% to %d%%)" % [o.pz.rec.name, oven.status(o), o.pz.bake_avg() * 100, rng[0] * 100, rng[1] * 100], Kit.INK])

# ---------- the makeline, prep and the back door ----------
## toppings on tonight's line that have to be prepped
func line_items() -> Array:
	var out := []
	for rc in Game.active_recipes():
		if eighty6.has(rc.id): continue
		for id in rc.spec:
			if Data.needs_prep(id) and not out.has(id): out.append(id)
	return out

## grams of a topping one pizza takes, averaged over tonight's pizzas that use it
func per_pizza(id: String) -> float:
	var t := 0.0
	var n := 0
	for rc in Game.active_recipes():
		if rc.spec.has(id):
			t += rc.spec[id]
			n += 1
	return t / n if n > 0 else 0.0

## how much raw stock to prep in one go mid-service: the rest of tonight, at least 8 pizzas' worth
func batch_raw(id: String, pizzas: int = -1) -> float:
	var y: float = float(Data.ING[id].prep.yield)
	var want: float
	if pizzas > 0:
		want = per_pizza(id) * pizzas
	else:
		var all: int = max(1, Game.active_recipes().size())
		var users := 0
		for rc in Game.active_recipes():
			if rc.spec.has(id) and not eighty6.has(rc.id): users += 1
		want = max(per_pizza(id) * users * c.total * max(0.1, 1.0 - t / DAY) * 1.1 / all - Stock.prepped(id), per_pizza(id) * 8.0)
	return min(Stock.have(id), want / y)

## you prep something: you are tied up until it is done
func prep_now(id: String, raw: float) -> void:
	if raw <= 0.0 or not is_free(): return
	var p = Data.ING[id].prep
	var mins := Stock.prep_minutes(id, raw, Day.prep_mult())
	prepping[id] = "you"
	start_busy("%s: %s %s" % [p.task, Data.qty(id, raw), Data.ING[id].name.to_lower()], mins, func(frac):
		Stock.prep(id, raw * frac)
		prepping.erase(id))

## you put a delivery away
func put_away_now(e: Dictionary, rotate: bool) -> void:
	if not is_free(): return
	e.handling = "you"
	start_busy("Putting %s's delivery away%s" % [Data.SUP[e.sup].name, "" if rotate else " (stacked in front)"], Stock.dock_minutes(e, rotate), func(frac):
		if frac < 1.0:
			e.erase("handling")
			return
		var res := Stock.put_away(e, rotate, minute())
		var txt := Day._waste_text(res)
		if txt != "": Kit.main.toast(txt.strip_edges(), true))

## prep cooks and kitchen porters: deliveries first, then the line (prep cook) or the washing up (porter)
func _crew_step(dt: float) -> void:
	for w in crew:
		if w.job != "":
			w.left -= dt
			if w.left <= 0:
				w.fn.call()
				w.job = ""
				dirty = true
			continue
		for e in Game.s.dock:
			if e.has("handling"): continue
			e.handling = w.s.name
			w.job = "delivery"
			w.left = secs(Stock.dock_minutes(e, true) * (1.2 - 0.08 * w.s.skill))
			w.fn = func():
				var res := Stock.put_away(e, true, minute())
				r.notes.append("%s put %s's delivery away and rotated the stock.%s" % [w.s.name, Data.SUP[e.sup].name, Day._waste_text(res)])
			break
		if w.job != "": continue
		if w.role == "prep":
			for id in line_items():
				if prepping.has(id) or Stock.have(id) <= 0.0: continue
				if Stock.prepped(id) >= per_pizza(id) * 6.0: continue
				var raw := batch_raw(id)
				if raw < 10.0: continue
				prepping[id] = w.s.name
				w.job = "prep"
				w.left = secs(Stock.prep_minutes(id, raw, Day.prep_mult() * (1.25 - 0.08 * w.s.skill)))
				w.fn = func():
					Stock.prep(id, raw)
					prepping.erase(id)
				break
		if w.job == "" and w.role == "porter": Hygiene.tidy("boh", 0.3 * gm * dt)
	var servers := Game.staff_of("server").size()
	if servers > 0: Hygiene.tidy("foh", 0.05 * servers * gm * dt)

## a mouse runs across the front: whoever sees it leaves, and everyone talks about it
func _mouse() -> void:
	r.mice += 1
	mouse_until = minute() + 45.0
	mouse = {"pos": Vector2(-20, 300), "vel": Vector2(240, -6), "t": 3.2}
	var near: Array = parties.filter(func(p): return p.state in ["queue", "door", "ask", "wait"])
	if near.size() > 0:
		var p: Dictionary = near.pick_random()
		expire(p, "Saw a mouse!")
		r.mouse_lost = r.get("mouse_lost", 0) + p.n
	Game.s.rep += (1.0 - Game.s.rep) * max(0.02, 1.0 / (Game.s.ratings + 6)) * 0.6
	Kit.main.toast("A customer saw a mouse!", true)

## the Prep tab: the back door, the makeline, and tonight's menu
func _build_prep() -> void:
	Kit.clear(prep_box)
	if view != "prep": return
	if Game.s.dock.size() > 0:
		prep_box.add_child(Kit.label("AT THE BACK DOOR", 15, Kit.MUTED))
		for e in Game.s.dock:
			var sup: Dictionary = Data.SUP[e.sup]
			var pc := Kit.panel(Kit.PANEL, 10)
			var v := Kit.vbox(4)
			pc.add_child(v)
			v.add_child(Kit.label("%s · arrived %s" % [sup.name, Data.hhmm(e.arrived)], 19))
			v.add_child(Kit.label(", ".join(e.lines.map(func(ln): return "%s %s" % [ln.what, ln.name])), 14, Kit.MUTED, true))
			var wl := Kit.label("", 15, Kit.INK, true)
			v.add_child(wl)
			info_rows.append([wl, func():
				var waited: float = minute() - e.arrived
				return ["Waiting %d minutes. Chilled food starts to spoil after 30, and is binned after 3 hours." % waited, Kit.TOMATO if waited > 30 else Kit.MUTED]])
			if e.has("handling"):
				v.add_child(Kit.label(("You are" if e.handling == "you" else e.handling + " is") + " putting it away.", 16, Kit.BASIL))
			else:
				var h := Kit.hbox(8)
				h.add_child(Kit.button("Put away and rotate (%d min)" % Stock.dock_minutes(e, true), put_away_now.bind(e, true), "primary", 16))
				h.add_child(Kit.button("Stack it in front (%d min)" % Stock.dock_minutes(e, false), put_away_now.bind(e, false), "ghost", 16))
				v.add_child(h)
			prep_box.add_child(pc)
	prep_box.add_child(Kit.label("THE MAKELINE", 15, Kit.MUTED))
	var ids := []
	for rc in Game.active_recipes():
		for id in rc.spec:
			if not ids.has(id): ids.append(id)
	ids.sort_custom(func(a, b): return Data.needs_prep(a) and not Data.needs_prep(b) if Data.needs_prep(a) != Data.needs_prep(b) else Data.ING[a].name < Data.ING[b].name)
	for id in ids:
		var it: Dictionary = Data.ING[id]
		var pc := Kit.panel(Kit.PANEL, 8, 10)
		var h := Kit.hbox(8)
		pc.add_child(h)
		h.add_child(Kit.swatch(id, 18))
		var v := Kit.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(Kit.label(it.name, 17))
		var st := Kit.label("", 14, Kit.MUTED, true)
		v.add_child(st)
		h.add_child(v)
		var pp := per_pizza(id)
		if not Data.needs_prep(id):
			info_rows.append([st, func():
				var a := Stock.have(id)
				return ["Ready to use · %s in stock (about %d pizzas)" % [Data.qty(id, a), a / max(pp, 0.01)], Kit.TOMATO if a < pp * 3 else Kit.MUTED]])
		else:
			info_rows.append([st, func():
				var a := Stock.prepped(id)
				var who: String = prepping.get(id, "")
				return ["%s %s on the line (about %d pizzas) · %s raw in stock%s" % [Data.qty(id, a), it.prep.as, a / max(pp, 0.01), Data.qty(id, Stock.have(id)), ("  ·  " + ("you are" if who == "you" else who + " is") + " prepping it") if who != "" else ""],
					Kit.TOMATO if a < pp * 3 else (Kit.CHEESE if a < pp * 8 else Kit.MUTED)]])
			if prepping.has(id) or Stock.have(id) <= 0.0:
				pass
			else:
				var small := batch_raw(id, 10)
				var rest := batch_raw(id)
				h.add_child(Kit.button("10 pizzas · %d min" % ceil(Stock.prep_minutes(id, small, Day.prep_mult())), prep_now.bind(id, small), "ghost", 15))
				if rest > small * 1.3:
					h.add_child(Kit.button("Rest of tonight · %d min" % ceil(Stock.prep_minutes(id, rest, Day.prep_mult())), prep_now.bind(id, rest), "primary", 15))
		prep_box.add_child(pc)
	prep_box.add_child(Kit.label("TONIGHT'S MENU", 15, Kit.MUTED))
	for rc in Game.active_recipes():
		var h := Kit.hbox(8)
		var nm := Kit.label(rc.name, 17)
		nm.custom_minimum_size.x = 210
		h.add_child(nm)
		var st := Kit.label("", 15, Kit.MUTED, true)
		h.add_child(st)
		info_rows.append([st, func():
			if eighty6.has(rc.id): return ["86'd: off the menu tonight", Kit.TOMATO]
			if Stock.dough_ready(rc.base) < 1: return ["Sold out: no %s dough left" % Data.DOUGHS[rc.base].name, Kit.TOMATO]
			if not sellable(rc): return ["Sold out: not enough left in stock", Kit.TOMATO]
			var np := Game.needs_prepping(rc)
			if np.size() > 0: return ["Customers can order it but the line is out of " + ", ".join(np.map(func(i): return Data.ING[i].name.to_lower())), Kit.CHEESE]
			return ["On", Kit.BASIL]])
		var off: bool = eighty6.has(rc.id)
		h.add_child(Kit.button("Back on" if off else "86 it", func():
			if off: eighty6.erase(rc.id)
			else: eighty6[rc.id] = true
			dirty = true, "primary" if off else "ghost", 15))
		prep_box.add_child(h)

func _side_prep() -> void:
	info.add_child(Kit.label("Prep and stock", 21))
	info.add_child(Kit.label("Toppings come off the makeline. When something runs low, prep more (you are tied up while you do), let a prep cook or pizzaiolo do it, or 86 the pizzas that need it. Deliveries that arrive mid-shift wait at the back door until someone puts them away.", 15, Kit.MUTED, true))
	for w in crew:
		_info(func(): return ["%s (%s): %s" % [w.s.name, Data.ROLES[w.s.role].name.to_lower(), {"": "keeping on top of things", "prep": "prepping", "delivery": "putting a delivery away"}[w.job]], Kit.INK], 15)
	for w in workers:
		_info(func(): return ["%s (pizzaiolo): %s" % [w.s.name, ("prepping " + Data.ING[w.prep].name.to_lower()) if w.prep != "" else ("making a pizza" if w.job != null else "waiting for tickets")], Kit.INK], 15)
	_info(func():
		var l := Hygiene.level("boh")
		return ["Kitchen %d%% clean" % l, Kit.BASIL if l >= 70 else (Kit.CHEESE if l >= 45 else Kit.TOMATO)], 16)
	_info(func():
		var l := Hygiene.level("foh")
		return ["Front of house %d%% clean" % l, Kit.BASIL if l >= 70 else (Kit.CHEESE if l >= 45 else Kit.TOMATO)], 16)

# ---------- close ----------
func finish(sold_out: bool) -> void:
	if done: return
	done = true
	var G := Game
	if not busy.is_empty(): stop_busy()
	for e in G.s.dock: e.erase("handling")
	for p in parties:
		if p.state == "eat" or p.state == "bill": settle(p, false)
		elif p.state != "leave": r.lost += p.n - p.got
	for tk in tickets: _waste_tk(tk)
	if bench != null: _waste_pizza(bench)
	for pz in board: _waste_pizza(pz)
	for pz in oven.shelf: _waste_pizza(pz)
	for o in oven.mine(): _waste_pizza(o.pz)
	var bk: Dictionary = G.s.book
	r.sold_out = sold_out
	r.rent = G.rent()
	r.rent_name = "Pitch fee" if G.pitch() != null else G.venue().rentName
	r.wages = G.wages()
	r.util = G.utilities()
	r.interest = -G.s.cash * 0.05 if G.s.cash < 0 else 0.0
	G.s.cash -= r.rent + r.wages + r.util + r.interest
	r.cost_used = bk.cost_used
	r.cost_spec = bk.cost_spec
	r.cost_waste = bk.cost_waste
	r.xp = int(round(r.xp + 20))
	r.ups = G.add_xp(r.xp)
	r.level = G.s.level
	r.rep1 = G.s.rep
	r.lost += r.sold
	r.avg_q = int(round(r.qsum / r.served)) if r.served > 0 else 0
	for k in r.cats: r.cats[k] = r.cats[k] / r.n_rev if r.n_rev > 0 else 0.0
	r.best = ""
	r.worst = ""
	if reviews.size() > 0:
		var sorted := reviews.duplicate()
		sorted.sort_custom(func(a, b): return a.stars > b.stars)
		r.best = "%.1f stars: %s" % [sorted[0].stars, sorted[0].text]
		if sorted.size() > 1 and sorted[-1].stars < sorted[0].stars - 0.25: r.worst = "%.1f stars: %s" % [sorted[-1].stars, sorted[-1].text]
	r.profit = r.food + r.tips + r.drinks + r.deliv - r.cost_used - r.cost_waste - r.rent - r.wages - r.util - r.interest
	r.eighty6 = eighty6.keys().map(func(id): return Data.REC[id].name)
	r.boh1 = Hygiene.level("boh")
	r.foh1 = Hygiene.level("foh")
	G.s.phase = "evening"
	r.notes.append_array(Day.start_evening())
	G.s.last = r
	G.save_game()
	Kit.main.show_hub("home")
	_summary()

func _summary() -> void:
	var v := Kit.vbox(8)
	v.add_child(Kit.label("%s closed%s" % [Game.date_text(r.day).get_slice(" · ", 0) + ", day %d" % r.day, ": sold out!" if r.sold_out else ""], 28))
	var g := Kit.grid(2, 30)
	var left := [["Pizzas served", "%d (%d by you)" % [r.served, r.mine]], ["Customers lost", str(r.lost)], ["Rating", "%.2f to %.2f" % [r.rep0, r.rep1]]]
	var why := []
	if r.walked > 0: why.append("%d walked off when the queue was too long" % r.walked)
	if r.gave_up > 0: why.append("%d gave up waiting" % r.gave_up)
	if r.sold > 0: why.append("%d found nothing left to sell" % r.sold)
	if r.n_rev > 0:
		left.append(["Look", "%.1f / 5" % r.cats.look])
		left.append(["Taste", "%.1f / 5" % r.cats.taste])
		left.append(["Service", "%.1f / 5" % r.cats.service])
		left.append(["Value", "%.1f / 5" % r.cats.value])
	left.append(["XP earned", "+%d" % r.xp])
	var right := [["Pizza sales", Kit.money(r.food)], ["Tips", Kit.money(r.tips)]]
	if r.drinks > 0: right.append(["Drinks", Kit.money(r.drinks)])
	if r.deliv > 0: right.append(["Delivery fees", Kit.money(r.deliv)])
	right.append(["Food that went on the pizzas", "-" + Kit.cents(r.cost_used)])
	if r.cost_waste > 0.005: right.append(["Binned", "-" + Kit.cents(r.cost_waste)])
	right.append([r.rent_name, Kit.money(-r.rent)])
	if r.wages > 0: right.append(["Wages", Kit.money(-r.wages)])
	right.append(["Gas & electric", Kit.money(-r.util)])
	if r.interest > 0: right.append(["Overdraft interest", Kit.money(-r.interest)])
	right.append(["Profit", Kit.money(r.profit)])
	for col in [left, right]:
		var cv := Kit.vbox(3)
		cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for ln in col:
			var h := Kit.hbox(8)
			var a := Kit.label(ln[0], 19, Kit.MUTED)
			a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(a)
			h.add_child(Kit.label(ln[1], 19, (Kit.BASIL if r.profit >= 0 else Kit.TOMATO) if ln[0] == "Profit" else Kit.INK))
			cv.add_child(h)
		g.add_child(cv)
	v.add_child(g)
	if r.get("mouse_lost", 0) > 0: why.append("%d left after seeing a mouse" % r.mouse_lost)
	if why.size() > 0: v.add_child(Kit.label("Lost customers: " + ", ".join(why) + ".", 17, Kit.TOMATO if r.lost > r.served * 0.2 else Kit.MUTED, true))
	if r.closed: v.add_child(Kit.label("The hygiene inspector closed you down at %s. Clean up, deal with the pests, and you can open again tomorrow." % Data.hhmm(minute()), 18, Kit.TOMATO, true))
	elif not r.inspect.is_empty(): v.add_child(Kit.label("Hygiene inspection: rated %s." % Hygiene.rating_text(), 17, Kit.CHEESE if r.inspect.rating < 4 else Kit.BASIL, true))
	var clean_line := "Kitchen %d%% clean (was %d%%), front of house %d%% (was %d%%)." % [r.boh1, r.boh0, r.foh1, r.foh0]
	if r.mice > 0: clean_line += "  Mice seen: %d." % r.mice
	if r.eighty6.size() > 0: clean_line += "  86'd: " + ", ".join(r.eighty6) + "."
	v.add_child(Kit.label(clean_line, 16, Kit.MUTED, true))
	if r.notes.size() > 0: v.add_child(Kit.label("\n".join(r.notes.slice(max(0, r.notes.size() - 4))), 14, Kit.MUTED, true))
	if r.food > 0:
		var over: float = r.cost_used - r.cost_spec
		var pct: float = r.cost_used / r.food * 100.0
		var line := "Food cost was %d%% of sales. " % pct
		if over > r.cost_spec * 0.05: line += "Heavy hands used %s more than the recipe cards allow." % Kit.cents(over)
		elif over < -r.cost_spec * 0.08: line += "Portions ran %s under the recipe cards: customers notice." % Kit.cents(-over)
		else: line += "Portions were on the recipe cards."
		v.add_child(Kit.label(line, 18, Kit.CHEESE if over > r.cost_spec * 0.05 else Kit.MUTED, true))
	if r.best != "": v.add_child(Kit.label("Best review   " + r.best, 17, Kit.BASIL, true))
	if r.worst != "": v.add_child(Kit.label("Worst review   " + r.worst, 17, Kit.TOMATO, true))
	if r.ups > 0:
		var ups := []
		for l in range(r.lvl0 + 1, r.level + 1): ups.append_array(Game.unlocks_at(l))
		v.add_child(Kit.label("Level %d!  %s" % [r.level, ("New: " + ", ".join(ups)) if ups.size() > 0 else ""], 19, Kit.CHEESE, true))
		Art.sfx("up")
	v.add_child(Kit.label("It is evening. Make tomorrow's dough and place tomorrow's orders before you lock up.", 17, Kit.MUTED, true))
	v.add_child(Kit.button("Evening jobs", Kit.main.close_modal))
	Kit.main.modal(v, 900)

class_name ServiceScreen
extends VBoxContainer
## One day's service. Runs the whole simulation: customers arriving, the queue, tables, tickets,
## the player's bench, the oven, and what the staff do on their own. FrontScene and Bench only draw it.

const DAY := 240.0          # seconds of trading at 1x
const NS := 24              # dough outline sectors
const BC := Vector2(160, 160)   # centre of the 320x320 bench

var c: Dictionary
var L: Dictionary            # scene layout for this venue
var t := 0.0
var acc := 0.95
var speed := 1
var nid := 1
var pid := 1
var tickets := []
var parties := []
var queue := []              # takeaway parties waiting to order
var waiters := []            # takeaway parties waiting for food
var door := []               # dine-in parties waiting for a table
var tables := []
var workers := []            # pizzaioli
var foh := []                # front-of-house staff timers
var oven := []
var board := []
var bench = null
var tool := ""
var view := "front"
var floats := []
var r := {}
var dirty := true
var done := false
var pop_t := 0.0

# ui
var front: FrontScene
var bench_ui: Bench
var kitchen: HBoxContainer
var tick_box: VBoxContainer
var side: VBoxContainer
var oven_box: VBoxContainer
var oven_head: Label
var tab_btns := {}
var top_lbl := {}
var clock: ProgressBar
var next_btn: Button
var bin_btn: Button
var auto_btn: Button
var pop: PanelContainer
var tick_bars := {}
var oven_bars := {}

func _ready() -> void:
	var G := Game
	c = G.calc()
	r = {"day": G.s.day, "served": 0, "mine": 0, "lost": 0, "sold": 0, "food": 0.0, "tips": 0.0, "drinks": 0.0, "deliv": 0.0, "qsum": 0.0, "xp": 0.0, "rep0": G.s.rep, "lvl0": G.s.level}
	for x in G.staff_of("pizzaiolo"): workers.append({"s": x, "job": null, "left": 0.0})
	for role in ["cashier", "server", "host", "porter", "driver"]:
		for x in G.staff_of(role): foh.append({"s": x, "role": role, "cd": 1.0})
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
	else:
		L.win = Vector2(62, 70)
		L.spawn = Vector2(625, 345)
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
	top.add_child(Kit.button("Close up", func(): Kit.main.confirm("Close early?", "Anyone still waiting leaves unserved.", "Close up", func(): finish(false)), "ghost", 19))

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
	for k in ["front", "bench", "board"]:
		var b := Kit.button("", set_view.bind(k), "tab", 20)
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
	bench_ui = Bench.new(self)
	bcol.add_child(bench_ui)
	var btns := Kit.hbox(8)
	bin_btn = Kit.button("Bin", bin, "ghost", 22)
	btns.add_child(bin_btn)
	auto_btn = Kit.button("Use the sheeter", sheeter, "ghost", 22)
	btns.add_child(auto_btn)
	next_btn = Kit.button("", next, "primary", 24)
	next_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btns.add_child(next_btn)
	bcol.add_child(btns)
	var right := Kit.vbox(8)
	right.custom_minimum_size.x = 300
	kitchen.add_child(right)
	var sp := Kit.panel(Kit.PANEL, 10)
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side = Kit.vbox(5)
	sp.add_child(side)
	right.add_child(sp)
	var op := Kit.panel(Color("3a2a22"), 10)
	var ov := Kit.vbox(5)
	oven_head = Kit.label("OVEN", 15, Kit.MUTED)
	ov.add_child(oven_head)
	oven_box = Kit.vbox(5)
	ov.add_child(oven_box)
	op.add_child(ov)
	right.add_child(op)

	pop = Kit.panel(Kit.INK, 14)
	pop.visible = false
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pop.top_level = true
	add_child(pop)

func set_view(v: String) -> void:
	view = v
	front.visible = v == "front"
	kitchen.visible = v != "front"
	dirty = true

func _speed() -> void:
	var mx := 8 if workers.size() > 0 else 4
	speed = 1 if speed >= mx else speed * 2
	top_lbl.speed.text = "%dx speed" % speed

# ---------- pizza model ----------
func new_pizza(tk: Dictionary, dq: float) -> Dictionary:
	var d = Data.DOUGHS[tk.rec.base]
	var rad := []
	for i in NS: rad.append(d.R * (0.5 if d.shape == "press" else 0.44))
	var cells := []
	var y := 6
	while y < 320:
		var x := 6
		while x < 320:
			if Vector2(x, y).distance_to(BC) < d.R * 0.84: cells.append(Vector2(x, y))
			x += 12
		y += 12
	pid += 1
	return {"id": pid, "tk": tk, "rec": tk.rec, "d": d, "R": float(d.R), "r": rad, "dough_q": dq, "stage": "shape", "sauce": "",
		"cells": cells, "sauce_cells": {}, "cheese": false, "cheese_cells": {}, "tops": [], "bake": 0.0, "cuts": []}

func rad_at(pz: Dictionary, ang: float) -> float:
	var f := fposmod(ang / TAU, 1.0) * NS
	var i := int(f)
	var k := f - i
	return pz.r[i % NS] * (1 - k) + pz.r[(i + 1) % NS] * k

func cov(pz: Dictionary, cells: Dictionary) -> float:
	return clamp(float(cells.size()) / pz.cells.size() / 0.85, 0.0, 1.0)

func shape_score(pz: Dictionary) -> float:
	var sc := 0.0
	for x in pz.r: sc += clamp(1.0 - max(0.0, abs(x - pz.R) / pz.R - 0.04) * 2.8, 0.0, 1.0)
	return sc / NS

func top_score(pz: Dictionary, id: String) -> float:
	var n := 0
	var quads := {}
	for p in pz.tops:
		if p.t == id:
			n += 1
			quads[(1 if p.x > BC.x else 0) + (2 if p.y > BC.y else 0)] = true
	return min(1.0, n / 5.0) * quads.size() / 4.0

func bake_score(p: float) -> float:
	if p < 0.6: return 0.0
	if p < 0.92: return 0.2 + (p - 0.6) / 0.32 * 0.7
	if p <= 1.12: return 1.0
	if p < 1.4: return 1.0 - (p - 1.12) / 0.28 * 0.7
	return 0.0

func cut_score(pz: Dictionary) -> float:
	var best := []
	for ct in pz.cuts: best.append(0.5 + 0.5 * (1.0 - ct.d / (pz.R * 0.35)))
	best.sort()
	best.reverse()
	var sc := 0.0
	for i in min(3, best.size()): sc += best[i]
	return sc / 3.0

func score_pizza(pz: Dictionary) -> Dictionary:
	var rec = pz.rec
	var p := {"shape": shape_score(pz), "sauce": cov(pz, pz.sauce_cells) if pz.sauce == rec.sauce else 0.0, "cheese": cov(pz, pz.cheese_cells), "bake": bake_score(pz.bake), "cut": cut_score(pz)}
	p.tops = 0.0
	for id in rec.tops: p.tops += top_score(pz, id) / rec.tops.size()
	var total: float = (p.shape * 15 + p.sauce * 15 + p.cheese * 15 + p.tops * 20 + p.bake * 25 + p.cut * 10) * 0.85 + pz.dough_q * 0.15 + c.oven_q * 0.5 + c.sup_q
	var extra := {}
	for tp in pz.tops:
		if not rec.tops.has(tp.t): extra[tp.t] = true
	total -= extra.size() * 10
	if pz.sauce != "" and pz.sauce != rec.sauce: total -= 15
	if pz.bake < 0.6 or pz.bake > 1.5: total = min(total, 30.0)
	p.total = clamp(round(total), 0, 100)
	p.note = "Raw in the middle!" if pz.bake < 0.6 else ("Burnt!" if pz.bake > 1.4 else ("Wrong toppings" if extra.size() > 0 else ("Wrong sauce" if pz.sauce != "" and pz.sauce != rec.sauce else "")))
	return p

# ---------- customers ----------
func set_pat(p: Dictionary, secs: float) -> void:
	if p.max > 0: p.waits.append(clamp(p.pat / p.max, 0.0, 1.0))
	p.max = secs * c.patience * randf_range(0.9, 1.1)
	p.pat = p.max

func spawn_party() -> int:
	var G := Game
	var type := "take"
	if c.delivery > 0 and randf() < float(c.delivery) / c.total: type = "deliv"
	elif tables.size() > 0 and randf() < 0.65: type = "dine"
	var n: int = [1, 1, 1, 1, 2].pick_random()
	if type == "dine": n = [1, 2, 2, 2, 3, 3, 4].pick_random()
	elif type == "deliv": n = [1, 1, 2].pick_random()
	pid += 1
	var p := {"id": pid, "type": type, "n": n, "pos": L.spawn, "target": L.spawn, "state": "", "pat": 0.0, "max": 0.0, "tks": [], "got": 0, "items": [],
		"waits": [], "table": -1, "timer": 0.0, "gone": false, "look": randi() % 6, "hue": randf()}
	if type == "deliv":
		if not order(p): return n
		p.pos = Vector2(-100, -100)
	elif type == "dine":
		if door.size() >= 4:
			if queue.size() >= c.queue_cap:
				r.lost += n
				return n
			p.type = "take"
			p.n = min(n, 2)
	if p.type == "dine":
		door.append(p)
		p.state = "door"
		set_pat(p, 50)
	elif p.type == "take":
		if queue.size() >= c.queue_cap:
			r.lost += n
			return n
		queue.append(p)
		p.state = "queue"
		set_pat(p, 50)
	parties.append(p)
	return n

## what the open (unstarted) tickets have already promised away
func _pending() -> Dictionary:
	var pend := {}
	for tk in tickets:
		if tk.state == "new" and tk.owner == "":
			pend["d:" + tk.rec.base] = pend.get("d:" + tk.rec.base, 0) + 1
			for i in Game.recipe_ings(tk.rec): pend[i] = pend.get(i, 0) + 1
	return pend

func can_promise(rec: Dictionary, pend: Dictionary) -> bool:
	if Game.dough_ready(rec.base) - pend.get("d:" + rec.base, 0) < 1: return false
	for i in Game.recipe_ings(rec):
		if Game.stock(i) - pend.get(i, 0) < 1: return false
	return true

## the party orders one pizza each. false = nothing left to sell them.
func order(p: Dictionary) -> bool:
	for k in p.n:
		var pend := _pending()
		var avail := Game.active_recipes().filter(func(rc): return can_promise(rc, pend))
		if avail.is_empty(): break
		nid += 1
		var tk := {"id": nid - 1, "rec": avail.pick_random(), "p": p, "state": "new", "owner": "", "score": 0.0, "mine": false, "gone": false, "age": 0.0}
		tickets.append(tk)
		p.tks.append(tk)
	if p.tks.is_empty():
		r.sold += p.n
		Game.s.rep += (2.0 - Game.s.rep) * 0.01
		float_text(p.pos, "Sold out!", Kit.TOMATO)
		leave(p)
		return false
	p.n = p.tks.size()
	p.state = "wait"
	set_pat(p, {"take": 90, "dine": 110, "deliv": 125}[p.type] + 18 * (p.n - 1))
	if p.type == "take":
		queue.erase(p)
		waiters.append(p)
	Art.sfx("ding")
	dirty = true
	return true

func leave(p: Dictionary) -> void:
	p.state = "leave"
	p.gone = true
	queue.erase(p); waiters.erase(p); door.erase(p)
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
	set_pat(p, 55)
	return true

func act_handover(p: Dictionary) -> void:
	for tk in ready_tks(p):
		tickets.erase(tk)
		tk.state = "done"
		p.got += 1
		p.items.append({"price": tk.rec.price, "score": tk.score})
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

func settle(p: Dictionary, walked: bool) -> void:
	var G := Game
	var paid := 0.0
	var avg := 0.0
	for it in p.items:
		var adj: float = it.score + [4, 0, -6][G.s.price]
		avg += adj / p.items.size()
		if adj >= 30: paid += it.price * c.price_mult
		r.qsum += it.score
	p.waits.append(clamp(p.pat / p.max, 0.0, 1.0))
	var pf := 0.0
	for w in p.waits: pf += w / p.waits.size()
	var dine: bool = p.type == "dine"
	var tip := 0.0
	if paid > 0 and not walked:
		tip = paid * max(0.0, (avg - 55.0) / 45.0) * 0.16 * (0.5 + 0.5 * pf) * c.tip * (1.5 if dine else 1.0)
	var drinks: float = c.drinks * p.items.size() * (1.0 if dine else 0.35) * randf_range(0.6, 1.4)
	var deliv := 2.5 if p.type == "deliv" else 0.0
	var st: float = clamp(1.0 + avg / 25.0 + (c.rep_bonus if dine else 0.0) - (0.5 if pf < 0.15 else 0.0) - (1.0 if walked else 0.0), 1.0, 5.0)
	G.s.ratings += 1
	G.s.rep = clamp(G.s.rep + (st - G.s.rep) * max(0.02, 1.0 / (G.s.ratings + 4)), 1.0, 5.0)
	var total := paid + tip + drinks + deliv
	G.s.cash += total
	G.s.earned += total
	G.s.pizzas += p.items.size()
	r.food += paid; r.tips += tip; r.drinks += drinks; r.deliv += deliv
	r.served += p.items.size()
	float_text(p.pos, ("+" + Kit.cents(total)) if paid > 0 else "Refunded", Kit.CHEESE if paid > 0 else Kit.TOMATO)
	Art.sfx("cash" if paid > 0 else "bad")

func expire(p: Dictionary) -> void:
	var G := Game
	if p.state == "bill":
		var tb = tables[p.table]
		settle(p, true)
		leave(p)
		tb.dirty = true
		return
	r.lost += p.n - p.got
	G.s.rep += (1.5 - G.s.rep) * max(0.02, 1.0 / (G.s.ratings + 6)) * 0.35
	for tk in p.tks:
		if tk.state == "done": continue
		tk.gone = true
		tickets.erase(tk)
	for w in workers:
		if w.job != null and w.job.gone: w.job = null
	oven = oven.filter(func(o): return not (o.owner == "staff" and o.tk.gone))
	var tb = tables[p.table] if p.table >= 0 else null
	float_text(p.pos, "Gave up waiting", Kit.TOMATO)
	if p.got > 0 and p.items.size() > 0: settle(p, true)
	leave(p)
	if tb != null and p.got > 0: tb.dirty = true
	Art.sfx("bad")
	dirty = true

func float_text(pos: Vector2, text: String, col: Color) -> void:
	if pos.x < 0: pos = L.win
	floats.append({"pos": pos, "text": text, "col": col, "t": 1.6})

## everything in the scene the player (or staff) can act on right now
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
	front.queue_redraw()
	bench_ui.queue_redraw()

func step(dt: float) -> void:
	var G := Game
	t += dt
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
		f.pos.y -= 22 * dt
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
			if w.left <= 0 and oven.size() < c.slots:
				oven.append({"owner": "staff", "tk": w.job, "q": staff_q(w.s), "p": 0.0, "bake": Data.DOUGHS[w.job.rec.base].bake})
				w.job.state = "oven"
				w.job = null
		if w.job == null:
			for tk in tickets:
				if tk.state == "new" and tk.owner == "" and tk.age > 1.2 and G.can_make(tk.rec):
					G.take_dough(tk.rec.base)
					for i in G.recipe_ings(tk.rec): G.take(i, 1)
					tk.owner = w.s.name
					tk.state = "make"
					w.job = tk
					w.left = 12.0 * (1.25 - 0.1 * w.s.skill) / c.prep_speed
					dirty = true
					break
	# oven
	for o in oven.duplicate():
		o.p += dt / (c.bake * o.bake)
		if o.owner == "staff" and o.p >= 1.0:
			oven.erase(o)
			to_pass(o.tk, o.q, false)
		elif o.owner == "me" and c.fornaio and o.p >= 1.02:
			pull(o)
	# end of day
	var idle := tickets.is_empty() and bench == null and board.is_empty() and oven.is_empty()
	var anyone := parties.any(func(p): return p.state != "leave")
	if idle and not anyone and t >= DAY: finish(false)
	elif idle and t > 5 and not anyone and not G.active_recipes().any(func(rc): return G.can_make(rc)): finish(true)

func staff_q(x: Dictionary) -> float:
	var hc := Game.staff_of("headchef")
	var b: float = (4 + hc[0].skill * 2) if hc.size() > 0 else 0.0
	return clamp(45 + x.skill * 8 + b + c.oven_q + c.prep_q + c.sup_q + randf_range(-5, 5), 20, 99)

func to_pass(tk: Dictionary, score: float, mine: bool) -> void:
	dirty = true
	if tk.gone: return
	tk.state = "pass"
	tk.score = score
	tk.mine = mine
	r.xp += (12 + score / 8.0) if mine else 4.0
	if mine: r.mine += 1

# ---------- the player's bench ----------
func claim(tk: Dictionary) -> void:
	if tk.state != "new" or tk.owner != "": return
	if bench != null:
		Kit.main.toast("Finish the pizza on your bench first", true)
		return
	var dq := Game.take_dough(tk.rec.base)
	if dq < 0:
		Kit.main.toast("No %s dough balls left" % Data.DOUGHS[tk.rec.base].name, true)
		return
	tk.owner = "me"
	tk.state = "make"
	bench = new_pizza(tk, dq)
	tool = ""
	set_view("bench")
	Art.sfx("tap")

func next() -> void:
	if view == "board":
		serve()
		return
	if bench == null: return
	if bench.stage == "shape":
		bench.stage = "top"
		tool = bench.rec.sauce if Game.stock(bench.rec.sauce) >= 1 else ""
	else:
		if oven.size() >= c.slots:
			Kit.main.toast("The oven is full", true)
			return
		oven.append({"owner": "me", "pz": bench, "p": 0.0, "bake": bench.d.bake})
		bench.tk.state = "oven"
		bench = null
		tool = ""
		if board.size() > 0: view = "board"
	dirty = true
	Art.sfx("tap")

func bin() -> void:
	var pz = board.pop_front() if view == "board" else bench
	if pz == null: return
	if view != "board": bench = null
	if not pz.tk.gone:
		pz.tk.owner = ""
		pz.tk.state = "new"
	if view == "board" and board.is_empty(): view = "bench"
	tool = ""
	dirty = true

func sheeter() -> void:
	if bench == null or bench.stage != "shape" or bench.d.shape != "roll" or c.roll_auto <= 0: return
	for i in NS: bench.r[i] = bench.R * (1.0 + randf_range(-1, 1) * (1.0 - c.roll_auto) * 0.5)
	dirty = true

func pull(o: Dictionary) -> void:
	oven.erase(o)
	o.pz.bake = o.p
	o.pz.stage = "board"
	board.append(o.pz)
	if bench == null and view != "front": view = "board"
	dirty = true
	Art.sfx("tap")

func serve() -> void:
	if board.is_empty(): return
	var pz = board[0]
	if pz.tk.gone:
		var alt = null
		for tk in tickets:
			if tk.state == "new" and tk.owner == "" and tk.rec == pz.rec: alt = tk
		if alt == null:
			board.pop_front()
			if board.is_empty(): view = "bench"
			dirty = true
			Kit.main.toast("That customer left. Pizza binned", true)
			return
		alt.owner = "me"
		pz.tk = alt
	var p := score_pizza(pz)
	to_pass(pz.tk, p.total, true)
	board.pop_front()
	if board.is_empty(): view = "bench"
	Kit.clear(pop)
	var v := Kit.vbox(2)
	v.add_child(Kit.label("%s  %d / 100" % [pz.rec.name, p.total], 24, Kit.DARK))
	v.add_child(Kit.label(p.note if p.note != "" else ("Bellissima!" if p.total >= 85 else ("Nice pizza" if p.total >= 65 else "Needs work")), 19, Kit.DARK))
	v.add_child(Kit.label("Base %d · Sauce %d · Cheese %d\nToppings %d · Bake %d · Cut %d" % [p.shape * 100, p.sauce * 100, p.cheese * 100, p.tops * 100, p.bake * 100, p.cut * 100], 16, Color("5b6a58")))
	v.add_child(Kit.label("On the pass. Hand it over out front.", 17, Color("2d7a33")))
	pop.add_child(v)
	pop.visible = true
	pop.reset_size()
	pop.position = bench_ui.global_position + Vector2(20, 20)
	pop_t = 3.2
	dirty = true

func cell_ok(pz: Dictionary, cl: Vector2) -> bool:
	var v := cl - BC
	return v.length() <= rad_at(pz, v.angle()) * 0.92

func bench_drag(p: Vector2, prev) -> void:
	var pz = bench
	if view != "bench" or pz == null: return
	var v := p - BC
	var dist := v.length()
	var ang := v.angle()
	if pz.stage == "shape":
		if prev == null: return
		var mv: Vector2 = p - prev
		var kind: String = pz.d.shape
		if kind == "hand":
			var gain: float = dist - (prev - BC).length()
			if gain <= 0: return
			for i in NS:
				var da: float = abs(angle_difference(ang, i * TAU / NS))
				if dist < pz.r[i] + 40: pz.r[i] = min(pz.r[i] + gain * (exp(-pow(da / 0.6, 2)) * 0.8 + 0.12) * (0.2 if pz.r[i] > pz.R else 1.0), pz.R * 1.15)
		elif kind == "roll":
			if dist > rad_at(pz, ang) + 30 or mv.length() < 0.5: return
			var phi := mv.angle()
			for i in NS:
				var w: float = pow(cos(i * TAU / NS - phi), 2)
				pz.r[i] = min(pz.r[i] + mv.length() * w * 0.2 * (0.2 if pz.r[i] > pz.R else 1.0), pz.R * 1.15)
		else:   # press into the pan: the pan wall stops it at R
			for i in NS:
				var da: float = abs(angle_difference(ang, i * TAU / NS))
				pz.r[i] = min(pz.r[i] + mv.length() * exp(-pow(da / 0.7, 2)) * 0.35, pz.R)
		return
	if tool == "" or dist > rad_at(pz, ang) * 0.92: return
	var kind: String = Data.ING[tool].kind
	var brush: float = 17.0 + c.brush
	if kind == "sauce":
		if pz.sauce == "":
			if Game.stock(tool) < 1: return
			Game.take(tool, 1)
			pz.sauce = tool
			dirty = true
		if pz.sauce != tool: return
		_mark(pz, pz.sauce_cells, p, brush + 3)
	elif kind == "cheese":
		if not pz.cheese:
			if Game.stock(tool) < 1: return
			Game.take(tool, 1)
			pz.cheese = true
		_mark(pz, pz.cheese_cells, p, brush + 2)
	else:
		var same := 0
		for q in pz.tops:
			if q.t == tool:
				same += 1
				if Vector2(q.x, q.y).distance_to(p) < 20: return
		if same >= 14: return
		if same == 0:
			if Game.stock(tool) < 1: return
			Game.take(tool, 1)
		pz.tops.append({"t": tool, "x": p.x, "y": p.y, "a": randf() * TAU})
		dirty = true

func _mark(pz: Dictionary, cells: Dictionary, p: Vector2, rad: float) -> void:
	for i in pz.cells.size():
		if not cells.has(i) and pz.cells[i].distance_to(p) < rad and cell_ok(pz, pz.cells[i]):
			cells[i] = true
			dirty = true

func board_cut(a: Vector2, b: Vector2) -> void:
	if view != "board" or board.is_empty(): return
	var pz = board[0]
	var ln := a.distance_to(b)
	if ln < pz.R * 1.2: return
	var dd: float = abs((b.y - a.y) * BC.x - (b.x - a.x) * BC.y + b.x * a.y - b.y * a.x) / ln
	if dd < pz.R * 0.35 and pz.cuts.size() < 4:
		pz.cuts.append({"a": a, "b": b, "d": dd})
		Art.sfx("tap")
		dirty = true
	elif dd >= pz.R * 0.35:
		Kit.main.toast("Cut through the middle", true)

# ---------- ui refresh ----------
func _refresh() -> void:
	var G := Game
	clock.value = clamp(t / DAY, 0, 1)
	top_lbl.time.text = "Last orders" if t >= DAY else ["Lunch", "Afternoon", "Dinner rush", "Late"][min(3, int(t / DAY * 4))]
	top_lbl.cash.text = Kit.money(G.s.cash)
	top_lbl.rep.text = "Rating %.1f" % G.s.rep
	top_lbl.count.text = "Served %d · Lost %d" % [r.served, r.lost + r.sold]
	var dn := 0
	var styles := {}
	for rc in G.active_recipes(): styles[rc.base] = true
	for st in styles: dn += G.dough_ready(st)
	top_lbl.dough.text = "Dough %d" % dn
	for id in tick_bars:
		var e = tick_bars[id]
		if is_instance_valid(e.bar): e.bar.value = clamp(e.tk.p.pat / max(1.0, e.tk.p.max), 0, 1)
	var hot := false
	for o in oven:
		if o.owner == "me":
			if o.p >= 0.92: hot = true
			if oven_bars.has(o.pz.id) and is_instance_valid(oven_bars[o.pz.id].bar):
				var e = oven_bars[o.pz.id]
				e.bar.value = clamp(o.p / 1.6, 0, 1)
				var stt := "Baking..." if o.p < 0.92 else ("PERFECT - pull it!" if o.p <= 1.12 else ("Overdone!" if o.p < 1.4 else "Burning!"))
				e.btn.text = "%s\n%s" % [o.pz.rec.name, stt]
				e.btn.add_theme_stylebox_override("normal", Kit.box(Color("54382b") if o.p < 0.92 else (Color("2f7a36") if o.p <= 1.12 else Color("8c2a1b")), 10, 8))
	var mine_n := oven.filter(func(o): return o.owner == "me").size()
	oven_head.text = "OVEN %d/%d" % [oven.size(), c.slots] + ("  ·  %d staff" % (oven.size() - mine_n) if oven.size() > mine_n else "")
	var acts := actionables().size()
	tab_btns.front.text = "Front of house" + (" (%d)" % acts if acts > 0 else "")
	tab_btns.bench.text = "Bench" + ("  - OVEN!" if hot else "")
	tab_btns.board.text = "Cutting board (%d)" % board.size()
	if not dirty: return
	dirty = false
	for k in tab_btns:
		var on: bool = view == k
		tab_btns[k].add_theme_stylebox_override("normal", Kit.box(Kit.PANEL2 if on else Kit.PANEL, 10, 8))
		tab_btns[k].add_theme_color_override("font_color", Kit.INK if on else Kit.MUTED)
	front.visible = view == "front"
	kitchen.visible = view != "front"
	_build_tickets()
	_build_side()
	_build_oven()

func _build_tickets() -> void:
	Kit.clear(tick_box)
	tick_bars = {}
	var shown := 0
	for tk in tickets:
		if shown >= 9: break
		shown += 1
		var status := "Tap to make it"
		var col := Kit.INK
		var fg := Kit.DARK
		if tk.state == "pass":
			status = "READY - hand over out front"
			col = Kit.BASIL
		elif tk.owner == "me":
			status = "You: " + ("in the oven" if tk.state == "oven" else "on your bench")
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
		for cn in ["font_color", "font_hover_color", "font_pressed_color"]: b.add_theme_color_override(cn, fg)
		b.pressed.connect(claim.bind(tk))
		tick_box.add_child(b)
		var bar := Kit.bar(1, Kit.BASIL, 5)
		tick_box.add_child(bar)
		tick_bars[tk.id] = {"bar": bar, "tk": tk}
	if tickets.size() > shown: tick_box.add_child(Kit.label("+%d more waiting" % (tickets.size() - shown), 16, Kit.MUTED))
	if tickets.is_empty(): tick_box.add_child(Kit.label("No orders yet. Customers order out front.", 16, Kit.MUTED, true))

func _build_side() -> void:
	Kit.clear(side)
	var pz = board[0] if (view == "board" and board.size() > 0) else (bench if view == "bench" else null)
	next_btn.visible = pz != null
	bin_btn.visible = pz != null
	auto_btn.visible = pz != null and view == "bench" and pz.stage == "shape" and pz.d.shape == "roll" and c.roll_auto > 0
	if pz == null:
		side.add_child(Kit.label("Tap an order on the left to start it. Shape the base, top it, bake it, slice it, send it to the pass.", 17, Kit.MUTED, true))
		return
	side.add_child(Kit.label("#%d %s" % [pz.tk.id, pz.rec.name], 21))
	if view == "board":
		next_btn.text = "Send to the pass"
		side.add_child(Kit.label("Swipe across the pizza to slice it. Three cuts through the middle.", 17, Kit.MUTED, true))
		side.add_child(Kit.label("Cuts: %d / 3" % pz.cuts.size(), 19))
		return
	if pz.stage == "shape":
		next_btn.text = "Base is ready"
		var how: String = {"hand": "Hand-stretched. Drag from the middle outward, all the way round, until the dough fills the dotted ring.",
			"roll": "Rolled thin. Push the rolling pin back and forth across the dough, and keep changing direction or it goes oval.",
			"press": "Deep pan. Rub the dough outward until it reaches the pan wall all the way round."}[pz.d.shape]
		side.add_child(Kit.label(how, 17, Kit.MUTED, true))
		side.add_child(Kit.label("%s base · evenness %d%%" % [pz.d.name, shape_score(pz) * 100], 18))
		return
	next_btn.text = "Into the oven"
	var rec = pz.rec
	var rows := [[rec.sauce, cov(pz, pz.sauce_cells) if pz.sauce == rec.sauce else 0.0], ["mozz", cov(pz, pz.cheese_cells)]]
	for id in rec.tops: rows.append([id, top_score(pz, id)])
	for rw in rows:
		var h := Kit.hbox(6)
		h.add_child(Kit.swatch(rw[0], 16))
		var l := Kit.label(Data.ING[rw[0]].name, 17, Kit.BASIL if rw[1] >= 0.8 else Kit.INK)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		h.add_child(Kit.label("%d%%" % (rw[1] * 100), 17, Kit.BASIL if rw[1] >= 0.8 else Kit.INK))
		side.add_child(h)
	var used := {}
	for rc in Game.active_recipes():
		for i in Game.recipe_ings(rc): used[i] = true
	var g := Kit.grid(2, 5)
	for id in used:
		var need: bool = Game.recipe_ings(rec).has(id)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.text = "%s (%d)" % [Data.ING[id].name, Game.stock(id)]
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 15)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 40
		var bg: Color = Color(Data.ING[id].col).darkened(0.25)
		for stn in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(stn, Kit.box(bg, 8, 4, Kit.CHEESE if tool == id else (Kit.INK if need else Color(0, 0, 0, 0)), 4 if tool == id else (1 if need else 0)))
		var fgc := Color.BLACK if bg.get_luminance() > 0.5 else Color.WHITE
		for cn in ["font_color", "font_hover_color", "font_pressed_color"]: b.add_theme_color_override(cn, fgc)
		b.pressed.connect(func():
			tool = id
			dirty = true)
		g.add_child(b)
	side.add_child(g)

func _build_oven() -> void:
	Kit.clear(oven_box)
	oven_bars = {}
	for o in oven:
		if o.owner != "me": continue
		var b := Kit.button(o.pz.rec.name, pull.bind(o), "ghost", 16)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		oven_box.add_child(b)
		var bar := Kit.bar(0, Kit.CHEESE, 6)
		oven_box.add_child(bar)
		oven_bars[o.pz.id] = {"btn": b, "bar": bar}

# ---------- close ----------
func finish(sold_out: bool) -> void:
	if done: return
	done = true
	var G := Game
	for p in parties:
		if p.state != "leave" and p.state != "eat" and p.state != "bill": r.lost += p.n - p.got
		elif p.state == "eat" or p.state == "bill": settle(p, false)
	r.sold_out = sold_out
	r.rent = G.venue().rent
	r.rent_name = G.venue().rentName
	r.wages = G.wages()
	r.interest = -G.s.cash * 0.05 if G.s.cash < 0 else 0.0
	G.s.cash -= r.rent + r.wages + r.interest
	r.xp = int(round(r.xp + 20))
	r.ups = G.add_xp(r.xp)
	r.level = G.s.level
	r.rep1 = G.s.rep
	r.lost += r.sold
	r.avg_q = int(round(r.qsum / r.served)) if r.served > 0 else 0
	r.profit = r.food + r.tips + r.drinks + r.deliv - r.rent - r.wages - r.interest
	G.s.last = r
	G.s.phase = "evening"
	G.save_game()
	Kit.main.show_hub("home")
	_summary()

func _summary() -> void:
	var v := Kit.vbox(8)
	v.add_child(Kit.label("Day %d closed%s" % [r.day, " - sold out!" if r.sold_out else ""], 28))
	var g := Kit.grid(2, 30)
	var left := [["Pizzas served", "%d (%d by you)" % [r.served, r.mine]], ["Customers lost", str(r.lost)], ["Average quality", str(r.avg_q)], ["Rating", "%.2f to %.2f" % [r.rep0, r.rep1]], ["XP earned", "+%d" % r.xp]]
	var right := [["Pizza sales", Kit.money(r.food)], ["Tips", Kit.money(r.tips)]]
	if r.drinks > 0: right.append(["Drinks", Kit.money(r.drinks)])
	if r.deliv > 0: right.append(["Delivery fees", Kit.money(r.deliv)])
	right.append([r.rent_name, Kit.money(-r.rent)])
	if r.wages > 0: right.append(["Wages", Kit.money(-r.wages)])
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
	if r.ups > 0:
		var ups := []
		for l in range(r.lvl0 + 1, r.level + 1): ups.append_array(Game.unlocks_at(l))
		v.add_child(Kit.label("Level %d!  %s" % [r.level, ("Unlocked: " + ", ".join(ups)) if ups.size() > 0 else ""], 20, Kit.CHEESE, true))
		Art.sfx("up")
	v.add_child(Kit.label("It is evening. Make tomorrow's dough and place your orders before you lock up.", 18, Kit.MUTED, true))
	v.add_child(Kit.button("Evening jobs", Kit.main.close_modal))
	Kit.main.modal(v, 820)

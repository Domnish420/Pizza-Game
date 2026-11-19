extends "res://tests/bot.gd"
## A whole day in the van, played by touch in the 3D kitchen: the morning jobs, a full service (shaping every base
## with one and two fingers, ladling and spreading sauce, cheese and toppings, the oven, cutting, sending, the
## phone, a complaint, paying), then the evening: ordering, making dough, locking up, and the next morning's delivery.
## `test_day_2d.gd` and `test_day_wood.gd` play the same day in the classic 2D layout and with a wood oven.

var view3d := true
var oven_tier := -1             # -1: the van's own oven; 3: a wood oven, lit in the morning

func touch(ctl: Control, idx: int, local: Vector2, pressed: bool, drag := false) -> void:
	var pos: Vector2 = ctl._off() + (local + Vector2(160, 160)) * ctl._k()
	var e: InputEvent
	if drag:
		e = InputEventScreenDrag.new()
	else:
		e = InputEventScreenTouch.new()
		e.pressed = pressed
	e.index = idx
	e.position = pos
	ctl._gui_input(e)

func shape_by_touch(svc) -> void:
	var b = svc.bench_ui
	var base = svc.bench.base
	for ring in 5:                                        # one finger: press out from the middle in rings
		for i in 12:
			var a := i * TAU / 12
			var p: Vector2 = Vector2.from_angle(a) * (ring / 5.0) * max(0.0, base.rad_at(a) - base.crust - 12.0)
			touch(b, 0, p, true)
			touch(b, 0, p, false)
	for rep in 3:                                         # two fingers: spread apart, turning a little each time
		for i in 6:
			var d := Vector2.from_angle(i * PI / 6 + rep * 0.2)
			touch(b, 0, d * 20, true)
			touch(b, 1, -d * 20, true)
			for s in 8:
				var r0: float = 20 + s * (base.R - 10) / 8.0
				touch(b, 0, d * r0, false, true)
				touch(b, 1, -d * r0, false, true)
			touch(b, 1, -d * base.R, false)
			touch(b, 0, d * base.R, false)

func top_it(svc) -> void:
	var pz = svc.bench
	if pz.rec.sauce != "":
		var oz_left := int(round(pz.rec.spec[pz.rec.sauce] / 30.0))
		svc.tool = pz.rec.sauce
		while oz_left > 0:
			svc.ladle_oz = 2 if oz_left >= 2 else 1
			oz_left -= svc.ladle_oz
			svc.scoop()
			svc.apply_tool(Vector2.ZERO, null)
		var pv := Vector2.ZERO
		for i in 300:                                     # spread it with the back of the ladle in a spiral
			var tt := float(i + 1) / 300
			var pp: Vector2 = Vector2.from_angle(tt * 7 * TAU) * tt * pz.base.R * 0.85
			svc.apply_tool(pp, pv)
			pv = pp
		svc.stroke_end(pv)
	if pz.rec.cheese != "":
		svc.tool = pz.rec.cheese
		var prev = null
		for i in 160:
			var t := float(i) / 160
			var p: Vector2 = Vector2.from_angle(t * 5 * TAU) * t * pz.base.R * 0.82
			svc.apply_tool(p, prev)
			prev = p
	for tp in pz.rec.tops:
		if D.ING[tp].after: continue
		svc.tool = tp
		var n := int(round(pz.rec.spec[tp] / D.ING[tp].piece))
		for i in n: svc.apply_tool(Vector2.from_angle(i * TAU / n + 0.4) * pz.base.R * (0.3 + 0.3 * (i % 2)), null)
	svc.dirty = true

func drag_oven(ov: Control, from: Vector2, to: Vector2) -> void:
	var k: float = ov._k()
	var off: Vector2 = ov._off()
	var e := click()
	e.position = off + from * k
	ov._gui_input(e)
	for s in 6:
		var mm := InputEventMouseMotion.new()
		mm.position = off + from.lerp(to, (s + 1) / 6.0) * k
		ov._gui_input(mm)
	var u := click()
	u.pressed = false
	u.position = off + to * k
	ov._gui_input(u)

func run() -> void:
	G.new_game()
	G.s.view3d = view3d
	G.s.upg.drinks = 1
	if oven_tier >= 0:
		G.s.upg.oven = oven_tier
		S.add("wood", 40, 2, 0.9)
		G.s.oven_lit = {"day": G.s.day, "at": G.s.clock - 120, "g": 2}
	for e in [["garlicbutter", 1000, 2], ["cola", 24, 2], ["water", 24, 1]]:
		S.add(e[0], e[1], e[2], D.ING[e[0]].g[e[2]].price)
	await open_game()
	m.show_hub("home")
	await shot("a-morning")

	# the morning: prep everything but the basil, set up the counter, lay two traps, fold boxes
	for row in Dy.prep_list():
		if row.id != "basil" and row.raw > 0: Dy.do_prep(row.id, row.raw)
	H.lay_trap()
	Dy.spend(5)
	H.lay_trap()
	Dy.spend(5)
	var counter: Dictionary = Dy.set_up_counter()
	check(counter.missing.is_empty(), "the counter is set up", counter)
	var nf: int = S.fold(S.boxes_needed() - 2)
	Dy.spend(nf * S.FOLD_MIN)
	check(S.folded() > 0, "boxes folded for the takeaways", S.folded())
	G.s.level = 3
	G.s.critic_next = 1
	G.s.regulars.append({"name": "Rosa", "fav": "pepperoni", "mods": [{"kind": "extra", "ing": "mozz"}], "mood": 0.7,
		"visits": 4, "type": "take", "look": 2, "last": 0})
	m.screen()._go_open()
	await process_frame
	var svc = m.screen()
	check(svc.get_script().get_global_name() == "ServiceScreen", "the van opens")
	await wait(2)
	await shot("b-open")

	var guard := 0
	var shots := {}
	var rang := false
	var made_bad := false
	var answered := 0
	var phone_orders := {}
	var topped_up := {}                         # tickets whose short pans the bot has already refilled once
	while is_instance_valid(svc) and not svc.done and guard < 30000:
		guard += 1
		if not svc.busy.is_empty():
			await process_frame
			continue
		if svc.phones.size() > 0:
			svc.answer_phone()
			answered += 1
			continue
		var dealt := false
		for p in svc.parties:
			if p.state == "paying":
				m.close_modal()
				svc._apply(p, p.verdict)
				svc._depart(p)
				dealt = true
				break
			if p.state == "complain":
				if not shots.has("complaint"):
					shots.complaint = true
					svc.complaint_dialog(p)
					await shot("c-complaint")
					m.close_modal()
					svc._resolve(p, p.verdict, "remake")
				else:
					svc._resolve(p, p.verdict, "drink")
				dealt = true
				break
		if dealt: continue
		for p in svc.parties:
			if p.get("phone", false): phone_orders[p.id] = true
		for a in svc.actionables():
			if a.kind != "complaint": svc.tap_scene(a.pos - Vector2(0, 14))
		if svc.t > 30 and not rang:
			rang = true
			svc.phones.append({"n": 1, "until": svc.t + 10.0})
		# short on the rail: refill from the tubs, prep more, or 86 it, once a ticket; then make it with what is there
		# (a pan that covers a standard portion does not refill on a tap, so "extra cheese" can stay short: a player
		# just carries on and taps the pan again when it runs dry)
		if svc.bench == null and svc.busy.is_empty():
			var refilled := false
			for tk in svc.tickets:
				if tk.state == "new" and tk.owner == "" and svc.sellable(tk.rec) and not topped_up.has(tk.id):
					var sh: Array = G.line_short(tk.rec)
					if sh.size() > 0:
						var id: String = sh[0]
						if S.refill_source(id) > 0.5: svc.rail_tap(S.rail_slot(id))
						elif svc.batch_raw(id) > 10.0: svc.prep_now(id, svc.batch_raw(id))
						else: svc.eighty6[tk.rec.id] = true
						refilled = true
					topped_up[tk.id] = true
					break
			if refilled:
				await process_frame
				continue
		if svc.bench == null and svc.oven.shelf.size() < 2:
			for tk in svc.tickets:
				if tk.state == "new" and tk.owner == "" and svc.sellable(tk.rec) and (G.line_short(tk.rec).is_empty() or topped_up.has(tk.id)):
					svc.claim(tk)
					break
			if svc.bench != null:
				svc.set_view("bench")
				shape_by_touch(svc)
				top_it(svc)
				if not shots.has("topped"):
					shots.topped = true
					await shot("d-topped")
				svc.next()
		var ov = svc.oven_ui
		if "FEED THE FIRE" in svc.tab_btns.oven.text: svc.add_log()
		if svc.oven.shelf.size() > 0 and svc.oven.free_slot() >= 0:
			drag_oven(ov, svc.oven.SHELF_POS[0], svc.oven.pos[svc.oven.free_slot()])
			if not shots.has("oven") and svc.oven.mine().size() > 0:
				shots.oven = true
				svc.set_view("oven")
				await shot("e-oven")
		for o in svc.oven.mine():
			if svc.oven.status(o) == "TURN": o.pz.turn += PI * 0.5
			if svc.oven.status(o) in ["READY", "BURNING"] or (not made_bad and o.pz.bake_avg() > 0.4):
				if not made_bad and svc.oven.status(o) != "READY": made_bad = true   # one comes out raw: a complaint
				drag_oven(ov, svc.oven.pos[o.slot], Vector2(200, 300))
		if svc.board.size() > 0:
			svc.set_view("board")
			svc.tool = ""
			for i in 3: svc.cut(-Vector2.from_angle(i * PI / 3) * 125, Vector2.from_angle(i * PI / 3) * 125)
			if not shots.has("board"):
				shots.board = true
				await shot("f-board")
			svc.serve()
			svc.set_view("front")
		if svc.t > 20 and svc.speed < 4: svc.speed = 4
		await process_frame

	var finished: bool = not is_instance_valid(svc) or svc.done
	if not finished:
		note("STUCK t=", svc.t, " tickets ", svc.tickets.map(func(k): return [k.id, k.state, k.owner, k.rec.key]),
			" parties ", svc.parties.map(func(p): return [p.state, p.type, p.got, p.n]))
	check(finished, "service runs to closing time", guard)
	var l: Dictionary = G.s.last
	note("served %d, lost %d, complaints %d, calls %d, food $%d, profit $%d" % [l.served, l.lost, l.complaints, l.calls, l.food, l.profit])
	check(l.served >= 4, "customers are served", l.served)
	check(l.lost == 0 and l.gave_up == 0, "nobody walks out", [l.lost, l.gave_up])
	check(answered > 0 and phone_orders.size() > 0, "the phone is answered and the order goes on the rail", [answered, phone_orders.size()])
	check(l.profit > 0, "the day makes money", int(l.profit))
	await shot("g-summary")
	m.close_modal()

	# the evening: order for tomorrow, make dough, lock up
	check(G.s.phase == "evening", "after service it is evening", G.s.phase)
	m.show_hub("jobs")
	await shot("h-evening")
	M.fill_basket("cashcarry")
	check(M.place("cashcarry") == "" and G.s.orders.size() == 1, "tomorrow's order is placed", G.s.orders.size())
	var dough0: int = S.dough_count()
	var dg = load("res://scripts/dough_game.gd").new("neapolitan")
	m.modal(dg, 1040)
	await process_frame
	for ing in dg.rows: dg._pour(ing, dg.rows[ing].target)
	dg._mix()
	dg.knead = 95
	dg.scores.knead = 100.0
	dg.step = 2
	dg._build()
	dg.cuts = [95.0, 90.0, 100.0]
	dg._finish()
	await shot("i-dough")
	dg._cancel()
	await process_frame
	check(S.dough_count() > dough0, "tomorrow's dough is made", [dough0, S.dough_count()])
	var day0: int = G.s.day
	m.screen()._do_sleep()
	await shot("j-next-morning")
	m.close_modal()
	check(G.s.day == day0 + 1 and D.hhmm(G.s.clock) == "07:00", "lock up, sleep, and it is the next morning", [G.s.day, D.hhmm(G.s.clock)])
	if Dy.next_arrival() >= 0: Dy.wait_until(Dy.next_arrival())
	check(G.s.dock.size() == 1, "the order arrives at the back door", G.s.dock.size())
	m.show_hub("jobs")
	await shot("k-delivery")

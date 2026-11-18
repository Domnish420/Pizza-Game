extends "res://tests/bot.gd"
## Story mode's first week with Marco. Day 1 (guided) you only stretch and he does the rest; day 2 you stretch and
## top; day 3 he stretches and you top and work the oven; day 4 you each make whole pizzas. Each day is busier.
## After seven good shifts Marco promotes you, and the senior's first shifts are slower before a normal day 10.

func stretch(pz) -> void:
	for j in 24:
		pz.base.r[j] = pz.base.R * (0.97 + 0.04 * sin(j * 1.3))
		pz.base.rim[j] = pz.base.crust
	pz.inside_n = -1

func run_day(n: int) -> void:
	var k = m.screen()
	var plan: Dictionary = St.plan()
	note("--- day %d: plan %s, Marco does %s, traffic %.2f, customers %d" % [n, plan, St.marco_does(), St.traffic(), G.calc().customers])
	await frames(10)
	check(T.kind != "", "day %d: Marco briefs you in the morning" % n, T.text_l.text.substr(0, 70))
	await shot("d%d-morning" % n)
	if n == 1:
		k.world.goto("bench")
		await frames(30)
	elif T.guide > 0:
		T._next()
		await frames(5)
	k._go_open()
	await frames(5)
	m.close_modal()
	await frames(3)
	var svc = m.screen()
	check(svc.helps == St.marco_does(), "day %d: Marco does %s" % [n, St.marco_does()], svc.helps)
	if n == 1:
		# the guided first ticket: claim it, stretch it, Marco takes it from there
		await frames(20)
		var tk: Array = svc.tickets.filter(func(t): return t.p.get("training", false))
		check(tk.size() > 0, "day 1: the first ticket is a training one", tk.size())
		if tk.is_empty(): return
		svc.claim(tk[0])
		await frames(10)
		stretch(svc.bench)
		await frames(10)
		await shot("d1-stretched")
		svc.set_view("oven")
		await frames(10)
		check(svc.bench == null and svc.oven.items.size() + svc.oven.shelf.size() > 0, "day 1: hand it over and Marco bakes it")
		T._next()
		await frames(5)
		check(T.kind == "" and G.s.story.get("guided_1", false), "day 1: the guide is over")
		svc.set_view("bench")
	var guard := 0
	while is_instance_valid(svc) and not svc.done and guard < 6000:
		guard += 1
		if not svc.busy.is_empty():
			await process_frame
			continue
		if svc.phones.size() > 0:                # answer the phone when it rings
			svc.answer_phone()
			continue
		# a pan running out on the rail: refill it from the tubs, or prep more
		if svc.bench == null:
			for t in svc.tickets:
				if t.state == "new" and t.owner == "" and svc.sellable(t.rec):
					var sh: Array = G.line_short(t.rec)
					if sh.size() > 0:
						if S.refill_source(sh[0]) > 0.5: svc.rail_tap(S.rail_slot(sh[0]))
						elif svc.batch_raw(sh[0]) > 10.0: svc.prep_now(sh[0], svc.batch_raw(sh[0]))
					break
		if svc.bench == null:
			for t in svc.tickets:
				if t.state == "new" and t.owner == "" and svc.sellable(t.rec) and G.line_short(t.rec).is_empty() and t.rec.get("make", "pizza") == "pizza":
					svc.claim(t)
					break
		if svc.bench != null:
			var pz = svc.bench
			if "stretch" in plan.jobs or "all" in plan.jobs: stretch(pz)
			if "top" in plan.jobs or "all" in plan.jobs: svc._marco_tops(pz)     # (the bot tops the way Marco would)
			svc.set_view("oven")                     # carries it to the oven, or hands it to Marco
			svc.set_view("front")
		if svc.oven.shelf.size() > 0 and svc.oven.free_slot() >= 0:
			svc.oven_load(svc.oven.shelf[0], svc.oven.free_slot())
		for o in svc.oven.mine():
			if not o.auto and svc.oven.status(o) == "TURN": o.pz.turn += PI
			if not o.auto and svc.oven.status(o) in ["READY", "BURNING"]: svc.oven_pull(o)
		if svc.board.size() > 0 and not "board" in svc.helps:
			svc.set_view("board")
			for i in 3: svc.cut(-Vector2.from_angle(i * PI / 3) * 125, Vector2.from_angle(i * PI / 3) * 125)
			svc.serve()
			svc.set_view("front")
		if svc.t > 15 and svc.speed < 4: svc.speed = 4
		await process_frame
	var l: Dictionary = G.s.last
	var sh: Array = G.s.story.shifts
	check(not is_instance_valid(svc) or svc.done, "day %d: service runs to closing" % n, guard)
	check(l.served > 0 and l.mine > 0, "day %d: pizzas go out, and you made them with Marco" % n, [l.served, l.mine])
	check(l.lost == 0, "day %d: nobody walks out" % n,
		"lost %d: walked %d, gave up %d, missed calls %d" % [l.lost, l.get("walked", 0), l.gave_up, l.missed])
	served.append(l.served)
	await shot("d%d-summary" % n)
	m.close_modal()
	await frames(3)
	m.close_modal()
	await frames(3)
	m.screen()._do_sleep()                     # lock up: Marco reviews the shift
	await frames(5)
	await shot("d%d-review" % n)
	check(sh.size() == n and sh[-1].score > 50, "day %d: Marco reviews the shift when you lock up" % n,
		[sh.size(), int(sh[-1].score) if sh.size() > 0 else -1])
	m.close_modal()
	await frames(3)

var served := []

func run() -> void:
	St.start()
	await open_game()
	m.show_hub("home")
	await frames(5)
	var traffic := []
	for n in [1, 2, 3, 4]:
		traffic.append(St.traffic())
		await run_day(n)
		if not is_instance_valid(m.screen()): break
	for n in [5, 6, 7]:
		traffic.append(St.traffic())
		G.s.story.shifts.append({"day": G.s.day, "stage": "pizzaiolo", "score": 72.0})
		G.s.day += 1
	note("traffic by day ", traffic, "  served days 1-4 ", served)
	# days 1-3 busier each day; day 4 (whole pizzas for the first time) starts a little slower; then busier each day
	var rising := func(a: Array) -> bool:
		for i in range(1, a.size()):
			if a[i] <= a[i - 1]: return false
		return true
	check(rising.call(traffic.slice(0, 3)) and rising.call(traffic.slice(3)) and traffic[3] < traffic[2] and traffic[-1] == traffic.max(),
		"busier each day; the first whole-pizza day starts a little slower", traffic)
	check(St.ready(), "after seven shifts Marco is ready to promote you", St.goals())
	St.promote()
	check(St.stage() == "senior" and G.s.story.training == "senior", "promoted to senior, with a training day first", [St.stage(), G.s.story.training])
	var paces: Array = St.PLAN.senior.map(func(p): return p.pace)
	check(paces[0] < paces[1] and paces[1] < 1.0 and paces[-1] == 1.0, "the senior's first shifts are slower, then a normal day", paces)

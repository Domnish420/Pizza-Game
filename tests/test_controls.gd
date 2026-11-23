extends "res://tests/bot.gd"
## The controls and the budget settings: look speed and invert, the stick on the right for a left hand, bigger
## buttons, the "put it down" button while you hold a topping, cut assist on the board, station buttons that pulse
## when they need you, the performance overlay and the graphics quality.

## turn the head with the stick held at v for n frames: how far the yaw and pitch went
func turn(w, v: Vector2, n: int) -> Vector2:
	var y0: float = w.t_yaw
	var p0: float = w.t_pitch
	w.stick = v
	await frames(n)
	w.stick = Vector2.ZERO
	return Vector2(w.t_yaw - y0, w.t_pitch - p0)

func kitchen():
	m.show_hub("home")
	await frames(10)
	return m.screen()

func run() -> void:
	G.new_game()
	await open_game()
	var k = await kitchen()
	var w = k.world

	# look speed: the same push turns further on Fast than on Slow (per frame of time)
	G.s.look_speed = "slow"
	var t0 := Time.get_ticks_msec()
	var slow: Vector2 = await turn(w, Vector2(1, 0), 20)
	var slow_ms := Time.get_ticks_msec() - t0
	G.s.look_speed = "fast"
	t0 = Time.get_ticks_msec()
	var fast: Vector2 = await turn(w, Vector2(1, 0), 20)
	var fast_ms := Time.get_ticks_msec() - t0
	check(absf(fast.x) / fast_ms > absf(slow.x) / slow_ms * 2.0, "Fast look speed turns well over twice as quick as Slow",
		[snappedf(absf(slow.x) / slow_ms * 1000.0, 0.1), snappedf(absf(fast.x) / fast_ms * 1000.0, 0.1)])
	G.s.look_speed = "normal"
	w.goto("front")
	await frames(30)
	var down: Vector2 = await turn(w, Vector2(0, 1), 10)
	G.s.invert_look = true
	w.goto("front")
	await frames(30)
	var inv: Vector2 = await turn(w, Vector2(0, 1), 10)
	G.s.invert_look = false
	check(down.y < 0.0 and inv.y > 0.0, "pulling the stick down looks down; with Invert it looks up", [snappedf(down.y, 0.1), snappedf(inv.y, 0.1)])

	# a left hand: the stick on the right, the station buttons from the left edge; bigger buttons
	G.s.stick_right = true
	G.s.big_controls = true
	k = await kitchen()
	var stk: Control = k.find_children("*", "LookStick", true, false)[0]
	var vw: float = root.get_viewport().get_visible_rect().size.x
	check(stk.get_global_rect().position.x > vw * 0.75, "the stick can go in the right-hand corner", stk.get_global_rect())
	check(stk.R > 60.0 and k.tab_btns.front.size.y >= 58.0, "bigger buttons: a bigger stick and taller station buttons", [stk.R, k.tab_btns.front.size.y])
	check(k.tab_btns.front.get_global_rect().position.x < 40.0, "the station buttons start at the left edge then", k.tab_btns.front.get_global_rect().position.x)
	await shot("left-handed")
	G.s.stick_right = false
	G.s.big_controls = false

	# in service: put it down, cut assist, the stations that need you (after the morning's prep and counter)
	for row in Dy.prep_list(): Dy.do_prep(row.id, row.raw)
	Dy.set_up_counter()
	k = await kitchen()
	k._go_open()
	await frames(5)
	m.close_modal()
	await frames(5)
	var svc = m.screen()
	svc.speed = 0
	svc.training_order("margherita")                    # a real order, the way Marco hands one over
	var tk: Dictionary = svc.tickets[-1]
	svc.claim(tk)
	await frames(5)
	svc.set_view("bench")
	svc.rail_tap(S.rail_slot("mozz"))
	svc.dirty = true
	await frames(5)
	check(svc.tool == "mozz" and svc.put_btn.visible and svc.put_btn.text == "Put down the mozzarella", "holding the cheese, a button offers to put it down", [svc.tool, svc.put_btn.visible, svc.put_btn.text])
	await shot("put-down")
	check(svc.put_btn.is_visible_in_tree() and svc.put_btn.get_global_rect().position.x > root.get_viewport().get_visible_rect().size.x * 0.6, "and it is on screen, bottom right", svc.put_btn.get_global_rect())
	svc.put_btn.pressed.emit()
	svc.dirty = true
	await frames(5)
	check(svc.tool == "" and not svc.put_btn.visible, "one tap and your hand is free", svc.tool)

	var pz = svc.bench
	svc.bench = null
	pz.bake.fill(1.0)
	svc.board.append(pz)
	svc.set_view("board")
	await frames(5)
	var R: float = pz.base.R
	svc.cut(Vector2(-R * 1.2, R * 0.08), Vector2(R * 1.2, R * 0.08))           # a little off the middle
	svc.cut(Vector2(R * 0.25, -R * 1.2), Vector2(R * 0.25, R * 1.2))           # well off it
	check(pz.cuts.size() == 2 and pz.cuts[0].d == 0.0 and pz.cuts[1].d > 0.0, "cut assist: near the middle goes through it; further off stays where you cut",
		pz.cuts.map(func(c): return snappedf(c.d, 0.1)))

	svc.set_view("front")
	var o = load("res://scripts/pizza.gd").new({"id": 91, "rec": D.REC.margherita, "gone": true, "state": "new"}, {"q": 80.0, "g": 3.0, "cost": 0.3})
	svc.oven.load_pizza(o, 0, false)
	o.bake.fill(1.6)
	o.floor = 1.6
	var tinted := false
	for i in 30:
		await process_frame
		if svc.tab_btns.oven.modulate.g < 0.8: tinted = true
	check(tinted and svc.tab_btns.front.modulate == Color.WHITE, "a burning pizza makes the Oven button pulse red while you look elsewhere", svc.tab_btns.oven.modulate)
	await shot("oven-pulse")

	# the budget: the overlay, and the quality setting
	G.s.perf = true
	await wait(0.8)
	var ov = m.find_children("*", "PerfOverlay", true, false)[0]
	check(ov.visible and ov.label.text.contains("draws") and ov.label.text.contains("fps"), "Show performance puts the numbers in the corner", ov.label.text)
	G.s.perf = false
	G.s.quality = "low"
	k = await kitchen()
	var vp: SubViewport = k.find_children("*", "FPView", true, false)[0].vp
	check(is_equal_approx(vp.scaling_3d_scale, 0.7) and vp.msaa_3d == Viewport.MSAA_DISABLED and vp.mesh_lod_threshold > 3.0, "Graphics: Low draws the kitchen at 70%, no edge smoothing, simpler far away",
		[vp.scaling_3d_scale, vp.msaa_3d, vp.mesh_lod_threshold])
	G.s.quality = "high"

extends "res://tests/bot.gd"
## Looking with the phone, and a hand on each thumb. The phone is your head: turning it turns you, and the station
## you turn to (and stay on for a moment) is where you work; a glance past one does not count. The view holds still
## while a thumb is working; the station buttons turn you to a station without turning round. Each thumb is a hand:
## the left thumb is the left hand. The hand that picked a topping up holds it (it shows in that hand, and its "put
## down" button is under that thumb); the other hand works the dough at the same time.

## turn the phone (the fake gyroscope) until you look at a (yaw, pitch), like a person turning round
func turn_to(w, a: Vector2) -> void:
	for i in 400:
		var at := Vector2(w.t_yaw + w.gyro.x, w.t_pitch + w.gyro.y)
		var d := Vector2(rad_to_deg(angle_difference(deg_to_rad(at.x), deg_to_rad(a.x))), a.y - at.y)
		if d.length() < 1.0: break
		var r := d * 4.0
		if r.length() > 120.0: r = r.normalized() * 120.0          # degrees a second: a brisk turn
		w.gyro_test = Vector3(deg_to_rad(r.y), deg_to_rad(r.x), 0.0)
		await process_frame
	w.gyro_test = Vector3.ZERO

## where you are looking (yaw, pitch)
func looking(w) -> Vector2:
	return Vector2(w.t_yaw + w.gyro.x, w.t_pitch + w.gyro.y)

## how far (degrees) where you look is from a station
func off(w, st: String) -> float:
	var a: Vector2 = w.STATIONS[st]
	var at := looking(w)
	return Vector2(rad_to_deg(angle_difference(deg_to_rad(at.x), deg_to_rad(a.x))), a.y - at.y).length()

func run() -> void:
	G.new_game()
	G.s.look = "phone"
	await open_game()
	m.show_hub("home")
	await frames(10)
	var k = m.screen()
	var w = k.world
	check(k.find_children("*", "LookStick", true, false).is_empty(), "with the phone for looking there is no look stick on screen")
	check(k.tab_btns.front.get_parent().get_parent() == k.top_bar, "the station buttons sit in the top bar, out of the thumbs' way", k.tab_btns.front.get_parent().get_parent())
	await shot("kitchen-phone")

	# turn round to the oven: you are at the oven, looking where the phone points (no snapping)
	await turn_to(w, w.STATIONS.oven + Vector2(4, 3))
	await wait(0.5)
	check(w.cur_view() == "oven", "turning the phone to the oven puts you at the oven", w.cur_view())
	check(off(w, "oven") < 7.0 and off(w, "oven") > 2.0, "and the view stays where the phone points: it does not snap", snappedf(off(w, "oven"), 0.1))
	await shot("turned-to-oven")

	# a glance does not count
	w.gyro.x += 90.0
	await wait(0.12)
	w.gyro.x -= 90.0
	await wait(0.4)
	check(w.cur_view() == "oven", "a glance at another station and back leaves you where you were", w.cur_view())

	# a station button turns you to it without turning round: the phone's direction now points there
	var g0: Vector2 = w.gyro
	k.tab_btns.prep.pressed.emit()
	await wait(0.6)
	check(w.cur_view() == "prep" and off(w, "prep") < 1.0 and w.gyro == g0, "the Prep button: you face the prep table from where the phone points", [w.cur_view(), snappedf(off(w, "prep"), 0.1)])
	await turn_to(w, w.STATIONS.stores)
	await wait(0.5)
	check(w.cur_view() == "stores", "then turning the phone round takes you on from there", w.cur_view())

	# into service
	for row in Dy.prep_list(): Dy.do_prep(row.id, row.raw)
	Dy.set_up_counter()
	k._go_open()
	await frames(5)
	m.close_modal()
	await frames(5)
	var svc = m.screen()
	svc.speed = 0
	w = svc.fp.world
	check(svc.find_children("*", "LookStick", true, false).is_empty(), "no look stick in service either")
	svc.training_order("margherita")
	svc.claim(svc.tickets[-1])
	w.face("bench")
	await wait(1.0)
	check(svc.view == "bench", "the Bench button takes you to the bench", svc.view)
	var s = w.find_children("*", "FPSurface", true, false).filter(func(x): return x.station == "bench")[0]
	var mid: Vector2 = w.cam.unproject_position(s.global_position)
	var half: float = w.get_viewport().get_visible_rect().size.x * 0.5

	# steady hands: a thumb on the dough holds the view still while the phone moves
	w._press(5, mid, true)
	check(w.ptr[5].kind == "surface", "a thumb on the bench is on the dough", w.ptr[5].kind)
	var at := looking(w)
	w.gyro_test = Vector3(0.6, 1.5, 0.0)
	await frames(20)
	w.gyro_test = Vector3.ZERO
	check(looking(w).distance_to(at) < 0.01, "while a thumb works, moving the phone does not move the view", looking(w) - at)
	w._press(5, mid, false)
	w.gyro_test = Vector3(0.0, 0.5, 0.0)
	await frames(10)
	w.gyro_test = Vector3.ZERO
	check(looking(w).distance_to(at) > 1.0, "lift it and the phone looks round again", looking(w) - at)
	w.face("bench")
	await wait(1.0)

	# two hands at once: the right holds the cheese and scatters it, the left works the dough
	var pz = svc.bench
	svc.tool_hand = 0
	svc.rail_tap(S.rail_slot("mozz"))
	svc.dirty = true
	await frames(3)
	check(svc.tool == "mozz" and w.held.get_parent() == w.hands[0].node, "the cheese is in the right hand", [svc.tool, w.held.get_parent()])
	# the dough is small on screen (about 2 bench units a pixel): the thumbs go either side of the middle of the screen,
	# on the dough
	var left := Vector2(minf(mid.x - 10.0, half - 6.0), mid.y)
	var right := Vector2(maxf(mid.x + 10.0, half + 6.0), mid.y)
	var r0: float = pz.base.mean_r()
	var c0: float = pz.grams.get("mozz", 0.0)
	w._press(3, left, true)
	check(w.ptr[3].get("hand", -1) == 1, "a thumb on the left half of the screen is the left hand", w.ptr[3].get("hand", -1))
	for i in 12:
		w._move(3, left + Vector2(-1.0 * i, 0.8 * i), Vector2(-1, 0.8))
		await process_frame
	var r1: float = pz.base.mean_r()
	var c1: float = pz.grams.get("mozz", 0.0)
	check(r1 > r0 and is_equal_approx(c1, c0), "the empty left hand presses the dough out (and puts no cheese on)", [snappedf(r0, 0.1), snappedf(r1, 0.1), c0, c1])
	w._press(4, right, true)
	check(w.ptr[4].get("hand", -1) == 0, "and one on the right half is the right hand", w.ptr[4].get("hand", -1))
	for a in 36:                                          # the dough opened out (cheese goes on the base, not the ball)
		for rr in [12.0, 26.0]: pz.base.press(Vector2.from_angle(a * TAU / 36.0) * rr)
	r1 = pz.base.mean_r()
	for i in 12:
		w._move(4, right + Vector2(1.0 * i, -0.8 * i), Vector2(1, -0.8))
		w._move(3, left + Vector2(-1.0 * (12 + i), 0.8 * (12 + i)), Vector2(-1, 0.8))
		await process_frame
	var r2: float = pz.base.mean_r()
	var c2: float = pz.grams.get("mozz", 0.0)
	var bn = s.control
	check(c2 > c1 and bn.roles.get(1, "") == "dough" and bn.roles.get(0, "") == "tool", "both at once: the right hand scatters the cheese while the left keeps working the dough",
		[snappedf(c1, 0.1), snappedf(c2, 0.1), snappedf(r2, 0.1), bn.roles])
	await shot("two-hands")
	w._press(4, right, false)
	w._press(3, left, false)

	# the left hand holding it: it shows in the left hand, and its put-down button is under the left thumb
	svc.tool_hand = 1
	svc.dirty = true
	await frames(3)
	check(w.held.get_parent() == w.hands[1].node, "picked up by the left hand, the cheese is in the left hand", w.held.get_parent())
	var vw: float = root.get_viewport().get_visible_rect().size.x
	check(svc.put_btn.visible and svc.put_btn.get_global_rect().end.x < vw * 0.4, "and the put-down button is bottom left, under that thumb", svc.put_btn.get_global_rect())
	await shot("left-hand-holding")
	svc.put_btn.pressed.emit()
	await frames(2)

	# tapping a pan with a thumb: that hand takes what is in it
	var pan_at = null
	for b in w.find_children("*", "StaticBody3D", true, false):
		var act = b.get_meta("act", {})
		if act is Dictionary and act.get("kind", "") == "pan" and int(act.i) == S.rail_slot("basil") and not w.cam.is_position_behind(b.global_position):
			pan_at = w.cam.unproject_position(b.global_position)
	check(pan_at != null, "the basil pan is in view at the bench", pan_at)
	if pan_at != null:
		w._press(8, pan_at, true)
		w._press(8, pan_at, false)
		await frames(2)
		var side := 1 if pan_at.x < half else 0
		check(svc.tool == "basil" and svc.tool_hand == side, "the thumb that tapped the basil pan holds the basil", [svc.tool, svc.tool_hand, side])

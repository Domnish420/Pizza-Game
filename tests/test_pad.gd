extends "res://tests/bot.gd"
## A game controller (a stand-in for one): the sticks are your hands, the triggers put them down, the stick clicks
## are your thumbs (they let go of what that hand holds), the shoulder buttons turn you to the next station. The
## two hands work at once: the left presses the dough while the right scatters the cheese. A hand pointing at the
## game's 2D screens is a finger there: the Phone button in the top bar, the phone, a job's sheet (scrubbing with the
## trigger held). A dialog gives its main button the focus; thumbs on the screen put the controller's hands away.
## Away from the kitchen (the title), the sticks move rings over the menu and the trigger clicks.

var w
const IDLE := {"r": Vector2.ZERO}       # the controller in your hands, nothing pressed

## put hand i's pointer at a point of the screen (the screens' pixels)
func point(i: int, at: Vector2) -> void:
	var fv = w._fpview()
	var sc: Vector2 = fv.size / Vector2(w.get_viewport().get_visible_rect().size)
	w.pad_at[i] = (at - fv.get_global_rect().position) / sc

## the first button under n whose text starts with word
func button(n: Node, word: String):
	for b in n.find_children("*", "Button", true, false):
		if b.text.begins_with(word): return b
	return null

## hold the controller like this for n frames, then let go of everything
func hold(state: Dictionary, n: int) -> void:
	w.pad_test = state
	await frames(n)
	w.pad_test = IDLE
	await frames(2)

func run() -> void:
	G.new_game()
	await open_game()
	m.show_hub("home")
	await frames(10)
	var k = m.screen()
	w = k.world
	w.pad_test = {}                      # a controller connected, untouched
	await frames(2)
	check(not w.pad_on, "a controller left alone does nothing")
	var start := Vector2.ZERO
	w.pad_test = {"r": Vector2(1, 0)}
	await frames(2)
	start = w.pad_at[0]
	await frames(15)
	w.pad_test = IDLE
	check(w.pad_on and w.pad_at[0].x > start.x + 20.0 and absf(w.pad_at[0].y - start.y) < 1.0, "pushing the right stick right moves the right hand right", [start, w.pad_at[0]])
	check(w.pad_dots[0].visible and w.hands[0].target != null, "the hand hovers over what it points at, with a dot where it would touch", w.hands[0].target)
	w.goto("front")
	await frames(3)
	await hold({"rb": true}, 2)
	var after_rb: String = w.cur_view()
	await hold({"lb": true}, 2)
	check(after_rb == "bench" and w.cur_view() == "front", "the right shoulder turns you to the next station round, the left back", [after_rb, w.cur_view()])
	m.confirm("Test", "A dialog.", "Yes please", func(): pass)
	await frames(3)
	var f = root.gui_get_focus_owner()
	check(f is Button and f.text == "Yes please", "a dialog gives its main button the focus (A presses it)", f.text if f is Button else f)
	m.close_modal()
	await frames(2)

	# the 2D screens: the Phone button up in the top bar, the phone, a job's sheet
	w.pad_test = IDLE
	await frames(2)
	point(0, k.phone_btn.get_global_rect().get_center())
	await frames(3)
	check(m.pad_ui.rings[0].visible and not w.pad_dots[0].visible, "pointing at the Phone button up in the top bar: a ring there, not a dot in the kitchen", m.pad_ui.rings[0].position)
	await hold({"rt": 1.0}, 3)
	check(k.phone.visible, "the trigger on it opens the phone", k.phone.visible)
	await shot("phone-ring")
	point(0, button(k.phone, "Put the phone away").get_global_rect().get_center())
	await hold({"rt": 1.0}, 3)
	check(not k.phone.visible, "the trigger on Put the phone away puts it away", k.phone.visible)
	k.job("clean_boh", {})
	await frames(5)
	var ct = m.modal_center.find_children("*", "CleanTask", true, false)[0]
	var l0: float = ct.pad.left()
	point(0, ct.pad.get_global_rect().position + ct.pad.spots[0].pos)
	w.pad_test = {"rt": 1.0}
	await frames(2)
	for rep in 4:
		w.pad_test = {"rt": 1.0, "r": Vector2(0.5, 0.0)}
		await frames(5)
		w.pad_test = {"rt": 1.0, "r": Vector2(-0.5, 0.0)}
		await frames(5)
	w.pad_test = IDLE
	await frames(2)
	check(ct.pad.left() < l0, "a job's sheet: scrubbing with the trigger held and the stick going back and forth cleans the dirt", [snappedf(l0, 0.01), snappedf(ct.pad.left(), 0.01)])
	await shot("scrubbing")
	m.close_modal()
	await frames(2)

	# in service
	for row in Dy.prep_list(): Dy.do_prep(row.id, row.raw)
	Dy.set_up_counter()
	k._go_open()
	await frames(5)
	m.close_modal()
	await frames(5)
	var svc = m.screen()
	svc.speed = 0
	w = svc.fp.world
	w.pad_test = IDLE
	svc.training_order("margherita")
	svc.claim(svc.tickets[-1])
	w.goto("bench")
	await wait(1.0)
	await hold({"r": Vector2(0.6, 0)}, 3)              # pick the controller up
	var s = w.find_children("*", "FPSurface", true, false).filter(func(x): return x.station == "bench")[0]
	var mid: Vector2 = w.cam.unproject_position(s.global_position)
	var pz = svc.bench

	# the right hand takes the cheese from its pan
	var pan_at = null
	for b in w.find_children("*", "StaticBody3D", true, false):
		var act = b.get_meta("act", {})
		if act is Dictionary and act.get("kind", "") == "pan" and int(act.i) == S.rail_slot("mozz"): pan_at = w.cam.unproject_position(b.global_position)
	w.pad_at[0] = pan_at
	await hold({"rt": 1.0}, 3)
	check(svc.tool == "mozz" and svc.tool_hand == 0, "the right trigger on the cheese pan: the right hand holds the cheese", [svc.tool, svc.tool_hand])

	# both hands at once
	w.pad_at[1] = mid + Vector2(-12, 0)                  # the dough is small on screen: under a bench unit a pixel
	w.pad_at[0] = mid + Vector2(14, 2)
	var r0: float = pz.base.mean_r()
	var c0: float = pz.grams.get("mozz", 0.0)
	w.pad_test = {"lt": 1.0}
	await frames(2)
	check(w.ptr.has(w.PAD + 1) and w.ptr[w.PAD + 1].kind == "surface" and w.ptr[w.PAD + 1].hand == 1, "the left trigger puts the left hand down on the dough", w.ptr.get(w.PAD + 1, {}).get("kind", ""))
	w.pad_test = {"lt": 1.0, "l": Vector2(-0.3, 0.2)}
	await frames(12)
	var r1: float = pz.base.mean_r()
	check(r1 > r0 and is_equal_approx(pz.grams.get("mozz", 0.0), c0), "moving it with the stick presses the dough out (no cheese from the empty hand)", [snappedf(r0, 0.1), snappedf(r1, 0.1)])
	for a in 36:                                          # the rest of the dough opened out (cheese goes on the base, not the ball)
		for rr in [12.0, 26.0, 38.0]: pz.base.press(Vector2.from_angle(a * TAU / 36.0) * rr)
	w.pad_test = {"lt": 1.0, "rt": 1.0}
	await frames(2)
	check(w.ptr.has(w.PAD) and w.ptr[w.PAD].kind == "surface" and w.ptr[w.PAD].hand == 0, "the right trigger puts the right hand down too", w.ptr.get(w.PAD, {}).get("kind", ""))
	var bn = w.ptr[w.PAD].s.control
	w.pad_test = {"lt": 1.0, "l": Vector2(-0.25, -0.3), "rt": 1.0, "r": Vector2(0.3, 0.25)}
	await frames(14)
	var c2: float = pz.grams.get("mozz", 0.0)
	check(c2 > c0 and bn.roles == {1: "dough", 0: "tool"}, "both triggers and both sticks: the right hand spreads the cheese while the left keeps working the dough",
		[snappedf(c2, 0.1), bn.roles])
	await shot("both-hands")
	await hold(IDLE, 2)
	check(not w.ptr.has(w.PAD) and not w.ptr.has(w.PAD + 1), "letting go of the triggers lifts both hands", w.ptr.keys())

	# the thumb lets go
	await hold({"r3": true}, 2)
	check(svc.tool == "", "clicking the right stick in (the thumb): the right hand puts the cheese down", svc.tool)

	# both triggers held still on the dough: up onto your knuckles; the sticks opposite ways turn it; let go of the
	# triggers as you turn it and it goes up spinning
	var b = pz.base
	w.pad_at[1] = mid + Vector2(-12, 0)
	w.pad_at[0] = mid + Vector2(12, 0)
	w.pad_test = {"lt": 1.0, "rt": 1.0}
	await until(func(): return b.lifted, 10.0)
	check(b.lifted, "both triggers held still on the dough: it comes up onto your knuckles", b.lifted)
	var rl: float = b.mean_r()
	var upx: float = (bn.touches[0] - bn.touches[1]).length() / 24.0          # (bench units a pixel, here)
	bn.test_dt = 1.0 / 60.0                       # (frames 1/60 s apart for the hands and the bench, however slow this machine)
	w.pad_dt = 1.0 / 60.0
	# both sticks steering the hands round the middle, half a turn apart (as you would turn a wheel)
	var st := {}
	for step in 14:
		st = {"lt": 1.0, "rt": 1.0}
		for i in 2:
			var o: Vector2 = w.pad_at[i] - mid
			st["r" if i == 0 else "l"] = Vector2(-o.y, o.x).normalized() * 0.4
		w.pad_test = st
		await process_frame
	check(b.mean_r() > rl and absf(bn.spin()) > 0.8, "the sticks steering your hands round turn it on your knuckles, stretching it", [snappedf(b.mean_r() - rl, 0.1), snappedf(bn.spin(), 0.01)])
	for step in 2:                                # then the sticks pushed hard, and the triggers let go
		for i in 2:
			var o: Vector2 = w.pad_at[i] - mid
			st["r" if i == 0 else "l"] = Vector2(-o.y, o.x).normalized()
		w.pad_test = st
		await process_frame
	st.erase("lt")
	st.erase("rt")
	w.pad_test = st
	await frames(1)
	await frames(1)
	check(b.last == "stretched" and b.air > 0.0, "push the sticks hard and let go of the triggers: it goes up, spinning", [b.last, snappedf(b.spin, 0.01)])
	w.pad_test = IDLE
	await until(func(): return b.air <= 0.0, 10.0)

	# a hand at the crust, the trigger, and the stick snapped outward: the slap
	var rs: float = b.mean_r()
	var rims: float = b.mean_rim()
	w.pad_at[0] = mid + Vector2(b.rad_at(0.0) * 0.85 / upx, 0)
	w.pad_test = {"rt": 1.0}
	await frames(2)
	w.pad_test = {"rt": 1.0, "r": Vector2(1, 0)}
	await frames(4)
	w.pad_test = IDLE
	await frames(2)
	check(b.mean_r() > rs + 1.0 and b.mean_rim() > rims * 0.9, "a hand on the crust and the stick snapped outward: the slap (the crust kept)",
		[snappedf(b.mean_r() - rs, 0.1), snappedf(b.mean_rim(), 0.1), snappedf(rims, 0.1)])
	bn.test_dt = 0.0
	w.pad_dt = 0.0

	# a dialog stops the hands; thumbs on the screen put them away
	m.confirm("Test", "A dialog.", "OK", func(): pass)
	await frames(2)
	w.pad_test = {"rt": 1.0}
	await frames(3)
	check(not w.ptr.has(w.PAD), "while a dialog is open the triggers do nothing in the kitchen", w.ptr.keys())
	w.pad_test = IDLE
	m.close_modal()
	await frames(2)
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = Vector2(20, 400)
	e.pressed = true
	w._unhandled_input(e)
	e = e.duplicate()
	e.pressed = false
	w._unhandled_input(e)
	await frames(2)
	check(not w.pad_on and not w.pad_dots[0].visible, "a thumb on the screen and the controller's hands rest", w.pad_on)

	# away from the kitchen: the title, with the rings over the menu
	m.show_start()
	await frames(10)
	var PU = load("res://scripts/pad_ui.gd")
	PU.test = {"r": Vector2(0.6, 0.0)}
	await frames(3)
	PU.test = IDLE
	await frames(2)
	var ng = button(m.content, "New game")
	m.pad_ui.at[0] = ng.get_global_rect().get_center()
	await frames(2)
	check(m.pad_ui.on and m.pad_ui.rings[0].visible, "on the title the controller's ring shows on the menu", m.pad_ui.on)
	PU.test = {"rt": 1.0}
	await frames(3)
	PU.test = IDLE
	await until(func(): return button(m.content, "Story") != null, 2.0)        # (the chalkboard slides to the next page)
	check(button(m.content, "Story") != null, "and the trigger clicks New game", button(m.content, "Story") != null)
	await shot("title-ring")
	PU.test = null

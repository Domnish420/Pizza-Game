extends "res://tests/bot.gd"
## A game controller (a stand-in for one): the sticks are your hands, the triggers put them down, the stick clicks
## are your thumbs (they let go of what that hand holds), the shoulder buttons turn you to the next station. The
## two hands work at once: the left presses the dough while the right scatters the cheese. A dialog gives its main
## button the focus; while one is open the hands rest; thumbs on the screen put the controller's hands away.

var w
const IDLE := {"r": Vector2.ZERO}       # the controller in your hands, nothing pressed

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
	w.pad_at[1] = mid + Vector2(-12, 0)                  # the dough is small on screen: about 2 bench units a pixel
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

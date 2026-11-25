extends "res://tests/bot.gd"
## The Quest, with a stand-in headset (XRRig.test): your head (turning, walking), your two real hands. A fingertip on
## the dough presses it; with the cheese in the right hand, the right fingertip spreads it while the left keeps
## pressing; a pinch at a pan takes what is in it into that hand; B lets go; a pinch on a button on the panel clicks it;
## the thumbstick turns you to the next station, the menu button looks at your station again; the controllers buzz; in
## the menus your hands point at the panel. The headset's camera is exactly the game's head.

var XR                                  # the XRRig script, loaded once the autoloads are up
var w

## a hand (all its parts) in the headset's space
func hand(tip: Vector3, aim: Transform3D, pinch: float = 0.0) -> Dictionary:
	return {"tracked": true, "tip": tip, "aim": aim, "palm": Transform3D(aim.basis, tip + aim.basis * Vector3(0, 0, 0.08)),
		"pinch": pinch, "grip": 0.0, "stick": Vector2.ZERO, "by": false, "ax": false, "menu": false}

## a kitchen point in the headset's space
func rig(p: Vector3) -> Vector3:
	return w.xr_origin().affine_inverse() * p

## a hand pointing from the kitchen point `from` at the kitchen point `at`, in the headset's space
func pointing(from: Vector3, at: Vector3) -> Transform3D:
	return w.xr_origin().affine_inverse() * Transform3D(Basis.looking_at(at - from, Vector3.UP), from)

## a hand resting low by your side (tracked, touching nothing, pointing at the floor)
func rest(side: float) -> Dictionary:
	var at: Vector3 = w.head.global_position + Vector3(0.25 * side, -0.7, 0.1)
	return hand(rig(at), pointing(at, at + Vector3(0, -1, 0)))

## the head turned to (yaw, pitch) degrees in the headset's space, standing at p (floor-level metres)
func head(yaw: float, pitch: float, p: Vector3 = Vector3(0, 1.6, 0)) -> void:
	XR.test.head = Transform3D(Basis.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0.0)), p)

func set_hands(r: Dictionary, l: Dictionary) -> void:
	XR.test.hands = [r, l]

func run() -> void:
	G.new_game()
	XR = load("res://scripts/fp/xr_rig.gd")
	XR.test = {"head": Transform3D(Basis(), Vector3(0, 1.6, 0)), "hands": [{"tracked": false}, {"tracked": false}]}
	await open_game()
	m.show_hub("home")
	await frames(10)
	var k = m.screen()
	w = k.world
	check(m.vr != null and m.vr.rig != null and XR.active and w.immersive, "a headset starts the game in VR, the headset tracking your head", [m.vr, XR.active])
	var cam0: Vector3 = w.cam.global_position
	check(m.vr.rig.head_global().origin.distance_to(w.cam.global_position) < 0.01 and m.vr.rig.head_global().basis.z.dot(w.cam.global_transform.basis.z) > 0.999,
		"the headset's camera is exactly the game's head", m.vr.rig.head_global().origin - w.cam.global_position)

	# walk half a metre forward, turn round to the oven
	head(0.0, 0.0, Vector3(0, 1.6, -0.5))
	await frames(2)
	check(w.cam.global_position.z < cam0.z - 0.45, "walk forward half a metre and you walk half a metre into the van", w.cam.global_position - cam0)
	head(0.0, 0.0)
	await frames(2)
	set_hands(rest(1.0), rest(-1.0))
	await frames(2)
	check(w.hands[0].node.global_position.distance_to(w.xr_origin() * (XR.test.hands[0].palm as Transform3D).origin) < 0.1, "your hand models are where your real hands are", w.hands[0].node.global_position)
	var r: Dictionary = rest(1.0)
	r.stick = Vector2(1, 0)
	set_hands(r, rest(-1.0))
	await frames(2)
	var after: String = w.cur_view()
	set_hands(rest(1.0), rest(-1.0))
	await frames(2)
	check(after == "bench", "the right thumbstick turns you to the next station (the counter)", after)

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
	set_hands(rest(1.0), rest(-1.0))
	svc.training_order("margherita")
	svc.claim(svc.tickets[-1])
	var bn: Vector2 = w.STATIONS.bench
	head(bn.x - w.t_yaw, bn.y)
	await until(func(): return svc.view == "bench", 2.0)
	check(svc.view == "bench", "look down at the bench and you are at the bench", svc.view)
	var pz = svc.bench
	var s = w.surfaces.bench

	# a fingertip on the dough presses it
	var r0: float = pz.base.mean_r()
	var at: Vector3 = s.global_transform * Vector3(-0.035, 0.0, 0.004)
	set_hands(hand(rig(at), pointing(at + Vector3(0, 0.1, 0.1), at)), rest(-1.0))
	await frames(2)
	check(w.ptr.has(w.XRP) and w.ptr[w.XRP].kind == "surface" and w.xr_touch[0] == s, "your right fingertip touching the marble is a finger on the dough", w.ptr.get(w.XRP, {}).get("kind", ""))
	for i in 10:
		var p: Vector3 = s.global_transform * Vector3(-0.035 - 0.003 * i, 0.003 * i, 0.004)
		set_hands(hand(rig(p), pointing(p + Vector3(0, 0.1, 0.1), p)), rest(-1.0))
		await process_frame
	check(pz.base.mean_r() > r0, "and moving it presses the dough out", [snappedf(r0, 0.1), snappedf(pz.base.mean_r(), 0.1)])
	var up: Vector3 = s.global_transform * Vector3(-0.06, 0.03, 0.06)
	set_hands(hand(rig(up), pointing(up + Vector3(0, 0.1, 0.1), up)), rest(-1.0))
	await frames(2)
	check(not w.ptr.has(w.XRP) and w.xr_touch[0] == null, "lift it off and it lets go", w.ptr.keys())

	# pinch at the cheese pan: the right hand takes it
	var pan_at = null
	for b in w.find_children("*", "StaticBody3D", true, false):
		var act = b.get_meta("act", {})
		if act is Dictionary and act.get("kind", "") == "pan" and int(act.i) == S.rail_slot("mozz"): pan_at = b.global_position
	var hp: Vector3 = w.cam.global_position + w.cam.global_transform.basis * Vector3(0.15, -0.25, -0.25)
	set_hands(hand(rig(hp), pointing(hp, pan_at), 1.0), rest(-1.0))
	await frames(2)
	check(w.xr_lasers.size() > 0 and w.xr_lasers[0].visible, "pointing at the pan, a beam shows what the hand points at", w.xr_lasers.size())
	set_hands(hand(rig(hp), pointing(hp, pan_at), 0.0), rest(-1.0))
	await frames(2)
	check(svc.tool == "mozz" and svc.tool_hand == 0, "a pinch at the cheese pan: the cheese is in your right hand", [svc.tool, svc.tool_hand])

	# both hands at once: the right fingertip spreads the cheese, the left keeps pressing
	for a in 36:
		for rr in [12.0, 26.0, 38.0]: pz.base.press(Vector2.from_angle(a * TAU / 36.0) * rr)
	var c0: float = pz.grams.get("mozz", 0.0)
	for i in 10:
		var pr: Vector3 = s.global_transform * Vector3(0.02 + 0.003 * i, -0.01, 0.004)
		var pl: Vector3 = s.global_transform * Vector3(-0.03 - 0.002 * i, 0.01, 0.004)
		set_hands(hand(rig(pr), pointing(pr + Vector3(0, 0.1, 0.1), pr)), hand(rig(pl), pointing(pl + Vector3(0, 0.1, 0.1), pl)))
		await process_frame
	var bench_ctl = s.control
	check(pz.grams.get("mozz", 0.0) > c0 and bench_ctl.roles.get(0, "") == "tool" and bench_ctl.roles.get(1, "") == "dough",
		"both hands on the dough: the right spreads the cheese while the left works the dough", [snappedf(pz.grams.get("mozz", 0.0), 0.1), bench_ctl.roles])
	await shot("two-hands-quest")
	set_hands(rest(1.0), rest(-1.0))
	await frames(2)
	var rb: Dictionary = rest(1.0)
	rb.by = true
	set_hands(rb, rest(-1.0))
	await frames(2)
	set_hands(rest(1.0), rest(-1.0))
	await frames(2)
	check(svc.tool == "", "B on the right controller: the right hand puts the cheese down", svc.tool)

	# a pinch on a button on the panel: the Oven button
	head(0.0, 0.0)
	await until(func(): return svc.view == "front", 2.0)
	await wait(0.6)
	var ob: Rect2 = svc.tab_btns.oven.get_global_rect()
	var pq: Vector2 = m.vr.panel.mesh.size
	var puv: Vector2 = ob.get_center() / Vector2(m.vr.ui_vp.size)
	var spot: Vector3 = m.vr.panel.global_transform * Vector3((puv.x - 0.5) * pq.x, (0.5 - puv.y) * pq.y, 0.0)
	hp = w.cam.global_position + w.cam.global_transform.basis * Vector3(0.15, -0.3, -0.2)
	set_hands(hand(rig(hp), pointing(hp, spot), 0.0), rest(-1.0))
	await frames(2)
	check(m.pad_ui.rings[0].visible and ob.has_point(m.pad_ui.rings[0].position), "pointing at the panel: a ring on the Oven button", m.pad_ui.rings[0].position)
	set_hands(hand(rig(hp), pointing(hp, spot), 1.0), rest(-1.0))
	await frames(2)
	set_hands(hand(rig(hp), pointing(hp, spot), 0.0), rest(-1.0))
	await frames(3)
	check(svc.view == "oven", "and a pinch clicks it: you are at the oven", svc.view)
	check(int(XR.test.get("pulses", 0)) > 0, "the controllers buzz when your hands touch and pinch", XR.test.get("pulses", 0))
	await shot("quest-panel")

	# the kitchen in your room: the headset's passthrough behind the counters, the van's walls gone
	G.s.ar = "camera"
	await frames(3)
	check(XR.test.get("passthrough", false) and w.env.background_color.a == 0.0 and w.shell.all(func(n): return not n.visible) and m.ar == null,
		"AR's 'kitchen in your room' on the headset: its passthrough shows your room, the walls are gone", [XR.test.get("passthrough", false), w.env.background_color])
	G.s.ar = "off"
	await frames(3)
	check(not XR.test.get("passthrough", true) and w.shell.all(func(n): return n.visible), "and off again: the van round you", XR.test.get("passthrough", true))

	# the menus: your hands point at the panel
	XR.test.hands = [{"tracked": false}, {"tracked": false}]
	await frames(2)
	m.show_start()
	await wait(1.0)
	var ng = null
	for b in m.content.find_children("*", "Button", true, false):
		if b.text.begins_with("New game"): ng = b
	var vr = m.vr
	var nq: Vector2 = vr.panel.mesh.size
	var nuv: Vector2 = ng.get_global_rect().get_center() / Vector2(vr.ui_vp.size)
	var nspot: Vector3 = vr.panel.global_transform * Vector3((nuv.x - 0.5) * nq.x, (0.5 - nuv.y) * nq.y, 0.0)
	var o: Transform3D = vr.rig.origin.global_transform
	var hn: Vector3 = vr.base_t.origin + Vector3(0.15, -0.3, -0.2)
	var aim := o.affine_inverse() * Transform3D(Basis.looking_at(nspot - hn, Vector3.UP), hn)
	XR.test.hands = [hand(o.affine_inverse() * hn, aim, 1.0), {"tracked": false}]
	await frames(2)
	XR.test.hands = [hand(o.affine_inverse() * hn, aim, 0.0), {"tracked": false}]
	await frames(8)
	var story := false
	for b in m.content.find_children("*", "Button", true, false):
		if b.text.begins_with("Story"): story = true
	check(story, "on the title, point at New game and pinch: it opens", story)
	await shot("quest-title")
	m.set_vr(false)
	await frames(3)
	XR.test = null

extends "res://tests/bot.gd"
## The turning peel in a wood oven, in service in 3D. Touch a pizza's edge and the peel slides under and lifts that
## side; with the left side lifted, pushing forward turns the pizza to the right and pulling back to the left (lifted on
## the right side, the other way round); lifted, the base bakes less from the deck; in 3D it tilts up on the peel. Its
## middle held still a moment, the peel takes it up to the dome: the top finishes quicker and the base stops cooking.
## Turned with the peel as it bakes, every side meets the fire: leopard spots all round the crust, and the review says so.

var svc
var ovv
var ov

## the peel under the pizza's edge at angle `side` (on the deck map), moved by `by` in steps, then let go
func peel(o: Dictionary, side: float, by: Vector2, steps: int = 10) -> void:
	var at: Vector2 = o.at + Vector2.from_angle(side) * ovv._pizza_r(o.pz) * 0.85
	ovv._down(at)
	for i in steps: ovv._move(at + by * float(i + 1) / steps)
	ovv._up(at + by)

func run() -> void:
	G.new_game()
	G.s.upg.oven = 3
	S.add("wood", 40, 2, 0.9)
	G.s.oven_lit = {"day": G.s.day, "at": G.s.clock - 120, "g": 2}
	E.add("turner", 1)
	await open_game()
	for row in Dy.prep_list(): Dy.do_prep(row.id, row.raw)
	Dy.set_up_counter()
	m.show_hub("home")
	await frames(10)
	var k = m.screen()
	k._go_open()
	await frames(5)
	m.close_modal()
	await frames(5)
	svc = m.screen()
	svc.speed = 0
	var w = svc.fp.world
	ov = svc.oven
	ovv = w.ctrls.oven
	check(ov.def.feeds and E.has("turner"), "a wood oven, and a turning peel", ov.kind)

	# a pizza, opened and topped, in the oven beside the fire
	svc.training_order("margherita")
	svc.claim(svc.tickets[-1])
	var pz = svc.bench
	for j in pz.base.NS:
		pz.base.r[j] = pz.base.R
		pz.base.rim[j] = pz.base.crust
	svc.bench = null
	pz.stage = "oven"
	svc.oven_load(pz, ov.free_slot(), Vector2(165, 129))
	var o: Dictionary = ov.items.filter(func(x): return x.owner == "me")[0]
	svc.set_view("oven")
	await wait(1.0)

	# the left side lifted: push forward and it turns right, pull back and it turns left
	var left: Vector2 = o.at + Vector2(-ovv._pizza_r(pz) * 0.85, 0)
	ovv._down(left)
	await frames(3)
	var n = w.oven_nodes["p%d" % pz.id]
	check(ovv.drag.mode == "lift" and o.get("lifted", false), "touching the edge, the turning peel lifts that side", ovv.drag.mode)
	check(n.basis.y.angle_to(Vector3.UP) > 0.1 and w.turner.visible, "in 3D the pizza tilts up on the peel", snappedf(n.basis.y.angle_to(Vector3.UP), 0.01))
	await shot("peel-lift")
	var t0: float = pz.turn
	for i in 10: ovv._move(left + Vector2(0, -2.5 * (i + 1)))
	var t1: float = pz.turn
	check(t1 > t0 + 0.2, "lifted on the left, push forward and it turns to the right", snappedf(t1 - t0, 0.01))
	for i in 20: ovv._move(left + Vector2(0, -25.0 + 2.5 * (i + 1)))
	check(pz.turn < t1 - 0.3, "pull back and it turns to the left", snappedf(pz.turn - t1, 0.01))
	ovv._up(left + Vector2(0, 25))
	await frames(2)
	check(not o.get("lifted", false) and n.basis.y.angle_to(Vector3.UP) < 0.01, "let go and it sits back on the deck", o.get("lifted", false))
	var t2: float = pz.turn
	peel(o, 0.0, Vector2(0, -25))
	check(pz.turn < t2 - 0.2, "lifted on the right instead, pushing forward turns it the other way", snappedf(pz.turn - t2, 0.01))

	# lifted, the base bakes less from the deck
	var f0: float = pz.floor
	for i in 10: ov.step(0.1, 1.0)
	var down_rate: float = pz.floor - f0
	o.lifted = true
	f0 = pz.floor
	for i in 10: ov.step(0.1, 1.0)
	o.lifted = false
	check(pz.floor - f0 < down_rate * 0.6, "held up on the peel, the base browns less from the deck", [snappedf(pz.floor - f0, 0.001), snappedf(down_rate, 0.001)])

	# its middle held still a moment: up to the dome on the peel; the top finishes quicker, the base stops
	var b0: float = pz.bake_avg()
	for i in 10: ov.step(0.1, 1.0)
	var top_rate: float = pz.bake_avg() - b0
	var y_deck: float = n.position.y
	var at0: Vector2 = o.at
	ovv._down(o.at)
	await until(func(): return ovv.drag != null and ovv.drag.mode == "dome", 5.0)
	await frames(2)
	check(o.get("domed", false) and n.position.y > y_deck + 0.1 and w.turner.visible, "the middle held still a moment: the peel takes it up to the dome", [o.get("domed", false), snappedf(n.position.y - y_deck, 0.01)])
	await shot("domed")
	b0 = pz.bake_avg()
	f0 = pz.floor
	for i in 10: ov.step(0.1, 1.0)
	check(pz.bake_avg() - b0 > top_rate * 1.5 and pz.floor == f0, "up there the top finishes quicker and the base stops cooking", [snappedf(pz.bake_avg() - b0, 0.001), snappedf(top_rate, 0.001), snappedf(pz.floor - f0, 0.001)])
	ovv._up(o.at)
	await frames(2)
	check(not o.get("domed", false) and absf(n.position.y - y_deck) < 0.01 and o.at.distance_to(at0) < 1.0, "let go and it is back down where it was", o.get("domed", false))

	# baked, turned with the peel every second: every side meets the fire
	for j in pz.bake.size():
		pz.bake[j] = 0.0
		pz.spots[j] = 0.0
	pz.floor = 0.0
	var t := 0.0
	var next := 1.0
	while pz.bake_avg() < 1.0 and t < 40.0:
		ov.step(0.1, 1.0)
		t += 0.1
		if t >= next:
			next += 1.0
			var t3: float = pz.turn
			peel(o, PI, Vector2(0, -ovv._pizza_r(pz) * PI / 2.0), 12)        # the left side lifted, pushed a quarter turn
			if pz.turn - t3 < 0.8: note("a short turn", snappedf(pz.turn - t3, 0.01))
	var lp: Dictionary = pz.leopard()
	check(lp.avg > 0.3 and lp.even > 0.6, "turned with the peel as it baked: leopard spots all round the crust", [snappedf(lp.avg, 0.01), snappedf(lp.even, 0.01)])
	await shot("leopard-in-oven")
	var a: Dictionary = pz.assess(svc.c)
	check(a.notes.has("Leopard spots all round the crust") and a.leopard > 0.4, "and the review says so", a.notes)
	# a close look on the cutting board
	svc.oven_pull(o)
	svc.set_view("board")
	await wait(1.2)
	await shot("leopard-board")

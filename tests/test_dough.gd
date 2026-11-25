extends "res://tests/bot.gd"
## Opening a base by hand, every technique there from the start, with real touches on the bench:
## press it out with a fingertip; slap it (a quick flick outward from the crust: it stretches and keeps its crust);
## hold two fingers still on it and it comes up onto your knuckles (in 3D it rises off the marble); turn your fingers
## round each other and it turns and its weight stretches it evenly; twist and flick up as you let go and it flies,
## spinning, and comes down bigger and rounder; flick with no twist and it flops; spin a thin base far too fast and it
## tears, and the review says so.

var bench
var svc

## a point on the dough (bench units, the middle at 0,0) on the bench control's screen
func px(p: Vector2) -> Vector2:
	return (p + bench.C) * bench._k() + bench._off()

func touch(i: int, p: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = px(p)
	e.pressed = down
	bench._gui_input(e)

func drag(i: int, p0: Vector2, p1: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i
	e.position = px(p1)
	e.relative = px(p1) - px(p0)
	bench._gui_input(e)

## how uneven the base is: the spread of its reach round the edge against its average
func uneven(b) -> float:
	var m: float = b.mean_r()
	var v := 0.0
	for x in b.r: v += pow(x - m, 2)
	return sqrt(v / b.r.size()) / m

## two fingers on the dough, held still until it lifts
func lift(b, a: Vector2, c: Vector2) -> void:
	touch(0, a, true)
	touch(1, c, true)
	await until(func(): return b.lifted, 30.0)

## both fingers flicked by `by` (over two frames) and off the glass
func flick(a: Vector2, c: Vector2, by: Vector2) -> void:
	for k in 2:
		drag(0, a + by * k / 2.0, a + by * (k + 1) / 2.0)
		drag(1, c + by * k / 2.0, c + by * (k + 1) / 2.0)
		await process_frame
	touch(1, c + by, false)
	touch(0, a + by, false)

## the two fingers turned round the middle by `step` radians a frame, n frames; returns where they end
func twist(a: Vector2, c: Vector2, step: float, n: int) -> Array:
	for k in n:
		var a2 := a.rotated(step)
		var c2 := c.rotated(step)
		drag(0, a, a2)
		drag(1, c, c2)
		a = a2
		c = c2
		await process_frame
	return [a, c]

func run() -> void:
	G.new_game()
	await open_game()
	for row in Dy.prep_list(): Dy.do_prep(row.id, row.raw)
	Dy.set_up_counter()
	m.show_hub("home")
	await frames(10)
	m.screen()._go_open()
	await frames(5)
	m.close_modal()
	await frames(5)
	svc = m.screen()
	svc.speed = 0
	var w = svc.fp.world
	svc.training_order("margherita")
	svc.claim(svc.tickets[-1])
	svc.set_view("bench")
	await wait(1.0)
	bench = w.surfaces.bench.control
	bench.test_dt = 1.0 / 60.0                 # (frames and finger moves 1/60 s apart, as on a phone, however slow this machine)
	var pz = svc.bench
	var b = pz.base

	# a fingertip presses it out
	var r0: float = b.mean_r()
	touch(0, Vector2(-10, 5), true)
	for k in 6:
		drag(0, Vector2(-10 - 3 * k, 5), Vector2(-13 - 3 * k, 5))
		await process_frame
	touch(0, Vector2(-28, 5), false)
	check(b.mean_r() > r0, "a fingertip presses the dough out", [snappedf(r0, 0.1), snappedf(b.mean_r(), 0.1)])

	# the slap: a quick flick outward from the crust
	var r1: float = b.mean_r()
	var rim1: float = b.mean_rim()
	var rot1: float = b.rot
	var edge := Vector2(b.rad_at(0.0) * 0.85, 0.0)
	touch(0, edge, true)
	await process_frame
	for k in 3:
		drag(0, edge + Vector2(40.0 * k, 0), edge + Vector2(40.0 * (k + 1), 0))
		await process_frame
	touch(0, edge + Vector2(120, 0), false)
	check(b.mean_r() > r1 + 2.0 and b.mean_rim() > rim1 * 0.9 and b.rot != rot1, "a flick outward from the crust slaps it: it stretches, turns a little, keeps its crust",
		[snappedf(b.mean_r() - r1, 0.1), snappedf(b.mean_rim(), 0.1), snappedf(rim1, 0.1)])

	# two fingers held still: up onto your knuckles
	var y0: float = w.pizza3d.bench.position.y
	await lift(b, Vector2(-25, 0), Vector2(25, 0))
	await frames(2)
	check(b.lifted and w.pizza3d.bench.position.y > y0 + 0.08, "two fingers held still lift it onto your knuckles (it rises off the marble)", [b.lifted, snappedf(w.pizza3d.bench.position.y - y0, 0.01)])
	await shot("lifted")

	# turned round on your knuckles: it turns and stretches, evening out
	var r2: float = b.mean_r()
	var u2 := uneven(b)
	var rot2: float = b.rot
	var at: Array = await twist(Vector2(-25, 0), Vector2(25, 0), 0.12, 12)
	check(b.mean_r() > r2 + 3.0 and uneven(b) < u2 and absf(angle_difference(rot2, b.rot)) > 0.5, "turned round on your knuckles: it turns, its weight stretches it, it evens out",
		[snappedf(b.mean_r() - r2, 0.1), snappedf(u2, 0.003), snappedf(uneven(b), 0.003)])

	# the toss: turn it, then flick both fingers off as you let go
	var r3: float = b.mean_r()
	var u3 := uneven(b)
	at = await twist(at[0], at[1], 0.35, 4)
	var sp: float = bench.spin()
	await flick(at[0], at[1], Vector2(0, -120))
	check(b.last == "stretched" and b.air > 0.0 and b.spin > 0.6, "turn it and flick off as you let go: it flies, spinning", [b.last, snappedf(b.air, 0.01), snappedf(b.spin, 0.01), snappedf(sp, 0.01)])
	var turn0: float = b.rot
	await frames(3)
	check(w.pizza3d.bench.position.y > y0 + 0.13 and b.rot != turn0, "in 3D it goes up in the air, turning", snappedf(w.pizza3d.bench.position.y - y0, 0.01))
	await shot("tossed")
	touch(0, Vector2(0, 0), true)                  # a finger ready under it
	await until(func(): return b.air <= 0.0, 30.0)
	await frames(2)
	check(b.air <= 0.0 and not b.lifted and b.mean_r() > r3 + 3.0 and uneven(b) <= u3, "it comes down bigger, and no less round", [snappedf(b.mean_r() - r3, 0.1), snappedf(u3, 0.003), snappedf(uneven(b), 0.003)])
	check(m.toast_label.text == "Caught it", "a finger on the bench as it comes down catches it", m.toast_label.text)
	touch(0, Vector2(0, 0), false)
	await frames(2)

	# a flick with no turn: it flops
	await lift(b, Vector2(-25, 0), Vector2(25, 0))
	await frames(3)
	await flick(Vector2(-25, 0), Vector2(25, 0), Vector2(0, -120))
	check(b.last == "flop", "flicked off with no spin, it just flops", [b.last, snappedf(b.spin, 0.01)])
	await until(func(): return b.air <= 0.0, 30.0)
	await frames(2)

	# lifted, let go gently: it is set back down on the bench
	await lift(b, Vector2(-25, 0), Vector2(25, 0))
	touch(1, Vector2(25, 0), false)
	touch(0, Vector2(-25, 0), false)
	check(not b.lifted and b.air <= 0.0, "let go gently and it is set back down", b.lifted)
	await frames(2)

	# a thin base spun far too fast tears
	for j in b.NS: b.r[j] = b.R * 1.08
	await lift(b, Vector2(-25, 0), Vector2(25, 0))
	await frames(2)
	at = await twist(Vector2(-25, 0), Vector2(25, 0), 0.9, 6)
	await flick(at[0], at[1], Vector2(0, -140))
	check(b.last == "tore" and b.tears.size() == 1, "a thin base spun far too fast tears", [b.last, snappedf(b.spin, 0.01), b.tears.size()])
	await until(func(): return b.air <= 0.0, 30.0)
	check(int(w.pizza3d.bench._mat.get_shader_parameter("n_holes")) == 1, "and there is a hole in it", w.pizza3d.bench._mat.get_shader_parameter("n_holes"))
	await shot("torn")
	check(pz.assess(svc.c).notes.has("A hole torn in the base"), "and the review says so", pz.assess(svc.c).notes)

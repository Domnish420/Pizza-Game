extends "res://tests/bot.gd"
## Folding pizza boxes by hand: four drags a box in the right order (front, sides, lid); a wrong drag does nothing.

func drag(pad: Control, a: Vector2, b: Vector2) -> void:
	var e := click()
	e.position = a
	pad._gui_input(e)
	var u := click()
	u.pressed = false
	u.position = b
	pad._gui_input(u)

func run() -> void:
	G.new_game()
	await open_game()
	m.show_hub("jobs")
	var t = load("res://scripts/fold_task.gd").new()
	m.modal(t, 900)
	await process_frame
	var p = t.pad
	var flat0: float = S.have("box")
	var folded0: int = S.folded()
	for box in 3:
		drag(p, Vector2(320, 248), Vector2(320, 170))      # the front up
		drag(p, Vector2(240, 170), Vector2(320, 170))      # the left side in
		drag(p, Vector2(400, 170), Vector2(320, 170))      # the right side in
		if box < 2: drag(p, Vector2(320, 60), Vector2(320, 160))   # the lid down (not on the third)
	var step: int = p.step
	drag(p, Vector2(240, 170), Vector2(320, 170))          # wrong: the lid is next
	await shot("folding")
	check(t.made == 2 and S.folded() == folded0 + 2 and S.have("box") == flat0 - 2, "two boxes folded, taken from the flat ones",
		[t.made, S.folded(), S.have("box")])
	check(p.step == step and step == 3, "a wrong drag does nothing: the lid is still next", [step, p.step])
	var c0: float = G.s.clock
	t._finish()
	await frames(4)
	check(G.s.clock > c0, "folding takes time", [D.hhmm(c0), D.hhmm(G.s.clock)])

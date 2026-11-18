extends "res://tests/bot.gd"
## Pest control on the floor plan: where you put traps matters (against the wall where mice get in beats the
## middle of the room), droppings show where they come in, and the plan screen lays a trap where you tap.

func catches(venue: int, how: String) -> Array:
	var n_caught := 0
	var cover := 0.0
	for trial in 20:
		G.new_game()
		G.s.venue = venue
		G.s.pests.traps = []
		G.s.pests.seen = {}
		S.add("traps", 20, 2, 3.5)
		for i in H.traps_wanted():
			if how == "middle": H.lay_trap(Vector2(320 + i * 20, 160))
			else: H.lay_trap(null, how == "smart")
		for night in 7:
			G.s.pests.level = 30.0
			for line in H.night():
				if line.find("caught") >= 0: n_caught += int(line.split(" ")[0])
			H.reset_traps()
		cover += H.coverage()
	return [n_caught / 20.0, cover / 20.0]

func run() -> void:
	for venue in [0, 3]:
		var mid := catches(venue, "middle")
		var doors := catches(venue, "doors")
		var smart := catches(venue, "smart")
		note("venue %d: catches a week (and coverage) middle %s, by the doors %s, smart %s" % [venue, mid, doors, smart])
		check(smart[0] > doors[0] and doors[0] > mid[0], "venue %d: traps at the entry points catch more than in the middle" % venue,
			[mid[0], doors[0], smart[0]])
		check(smart[1] > 0.6 and mid[1] < 0.1, "venue %d: coverage shows it" % venue, [mid[1], smart[1]])

	# droppings show where they get in
	G.new_game()
	S.add("traps", 4, 2, 3.5)
	G.s.pests.level = 30.0
	for i in 3: H.night()
	check(H.droppings().size() > 0, "mice leave droppings", H.droppings().size())
	check(H.spot_value(Vector2(118, 236)) > H.spot_value(Vector2(300, 160)) * 5.0, "a trap by the pipe hole is worth far more than one mid-room",
		[snappedf(H.spot_value(Vector2(118, 236)), 0.01), snappedf(H.spot_value(Vector2(300, 160)), 0.01)])

	# the floor-plan screen
	await open_game()
	m.show_hub("jobs")
	var t = load("res://scripts/trap_task.gd").new()
	m.modal(t, 900)
	await frames(6)
	var laid0: int = H.laid()
	t.tapped_floor(Vector2(118, 236))
	await frames(6)
	await shot("plan")
	check(H.laid() == laid0 + 1 and t.minutes > 0, "tapping the plan lays a trap there, and it takes time", [H.laid(), t.minutes])
	var c0: float = G.s.clock
	t._finish()
	await frames(4)
	check(G.s.clock > c0, "the time comes off the clock", [D.hhmm(c0), D.hhmm(G.s.clock)])

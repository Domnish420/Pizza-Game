extends "res://tests/bot.gd"
## The senior pizzaiolo's training day: Marco walks you through the morning and evening back-of-house jobs on the
## real game. Each job done moves the guide on; at the end the game is as it was, and you are trained.

var k                           # the kitchen screen

func step() -> int:
	return T.i

func _fridge(): k.job("temp_fridge", {})
func _freezer(): k.job("temp_freezer", {})
func _delivery():
	for e in G.s.dock.duplicate(): Dy.put_away(e, true)
func _traps(): H.reset_traps()
func _phone(): k.open_phone("stores")
func _phone_away(): k.close_phone()
func _clean(): H.clean("boh")
func _wash():
	k.job("wash", {})
	m.close_modal()
func _dough(): S.add_dough("neapolitan", 10, 80, 0, 3.0, 0.3)
func _order():
	M.fill_basket("cashcarry")
	M.place("cashcarry")
func _sheet(): St.set_sheet({"mozz": 1000.0})
func _evening_temps():
	k.job("temp_fridge", {})
	m.close_modal()

func run() -> void:
	await open_game()
	St.start()
	G.s.story.guided_1 = true                 # (day 1's guide is in test_first_week.gd)
	m.show_hub("home")
	await frames(10)
	check(T.kind == "", "a new pizzaiolo has no training day: the first shift is guided instead", T.kind)
	G.s.story.stage = "pizzaiolo"
	St.promote()
	m.show_hub("home")
	await frames(10)
	k = m.screen()
	check(T.kind != "" and T.steps.size() >= 10, "promoted: the senior's training day starts", [T.kind, T.steps.size()])
	var cash0: float = G.s.cash
	var day0: int = G.s.day

	# each job as the player would do it, in the order Marco asks (the counter step finishes by itself, since the
	# counter is already set up)
	var jobs := [
		["the fridge temperature", _fridge], ["the freezer temperature", _freezer], ["checking in the delivery", _delivery],
		["resetting the traps", _traps], ["looking at the phone", _phone], ["putting the phone away", _phone_away],
		["cleaning", _clean], ["washing the tubs", _wash], ["making the dough", _dough], ["ordering", _order],
		["the prep sheet for Luca", _sheet], ["the evening temperatures", _evening_temps],
	]
	k.world.goto("stores")
	await frames(40)
	await shot("start")
	for j in jobs:
		var before := step()
		j[1].call()
		await frames(40)
		check(step() > before or T.kind == "", "doing %s moves the guide on" % j[0], "%d/%d %s" % [step() + 1, T.steps.size(), T.text_l.text.substr(0, 50)])
	await shot("end")
	T._panel_input(click())
	await frames(10)
	check(T.kind == "" and G.s.story.get("trained_senior", false), "the training day finishes, and you are trained", [T.kind, G.s.story.get("trained_senior")])
	check(St.stage() == "senior" and G.s.phase == "morning", "it is the senior's first morning", [St.stage(), G.s.phase])
	note("cash ", cash0, " -> ", G.s.cash, ", day ", day0, " -> ", G.s.day)

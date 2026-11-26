extends "res://tests/bot.gd"
## Your hands (Skills): every technique is there from the first base, and the milestones on the way are earned by
## doing. A base opened, slapped, tossed, caught and tossed again, round and even, sent to the oven: First base, Round
## and right, Even all over, The slap, Up it goes, Twice in the air. Five good bases in a row; a crust leopard-spotted
## all round; a pizza of your own at 90 for look: Chef's hands. The rank goes up with them, a word says so, the phone's
## home page shows them all, and they are kept in the save.

var SK                                  # the Skills script, loaded once the autoloads are up

func label_starting(n: Node, text: String):
	for l in n.find_children("*", "Label", true, false):
		if l.text.begins_with(text): return l
	return null

func run() -> void:
	G.new_game()
	await open_game()
	SK = load("res://scripts/skills.gd")
	for row in Dy.prep_list(): Dy.do_prep(row.id, row.raw)
	Dy.set_up_counter()
	m.show_hub("home")
	await frames(10)
	check(label_starting(m.content, "Your hands: Beginner") != null and SK.count() == 0, "a new game: Your hands on the phone, a beginner", SK.rank())
	m.screen()._go_open()
	await frames(5)
	m.close_modal()
	await frames(5)
	var svc = m.screen()
	svc.speed = 0
	svc.set_view("bench")
	await frames(5)
	var bench = svc.fp.world.surfaces.bench.control

	# a base opened by hand: slapped, tossed, caught on the knuckles and tossed again, then round and even, to the oven
	svc.training_order("margherita")
	svc.claim(svc.tickets[-1])
	var pz = svc.bench
	var b = pz.base
	for j in b.NS:
		b.r[j] = b.R * 0.8
		b.rim[j] = b.crust
	b.slap(Vector2.RIGHT, 0.6)
	b.lifted = true
	bench.tossed(b.toss(1.5, 0.5))
	check(SK.has("toss") and not SK.has("twice"), "a clean toss: Up it goes", SK.state().done.keys())
	b.air = 0.0
	b.catches = 1
	b.lifted = true
	bench.tossed(b.toss(1.5, 0.5))
	check(SK.has("twice"), "caught on the knuckles and tossed again: Twice in the air", SK.state().done.keys())
	b.air = 0.0
	b.lifted = false
	for j in b.NS:
		b.r[j] = b.R
		b.rim[j] = b.crust
	svc._carry_to_oven(false)
	for id in ["first", "round", "even", "slap"]:
		check(SK.has(id), "to the oven: " + SK._name(id), SK.state().done.keys())
	check(SK.rank() == "Pizzaiolo" and SK.state().bases == 1, "six milestones: a pizzaiolo", [SK.rank(), SK.count()])
	svc._carry_to_oven(false)
	check(SK.state().bases == 1, "a base counts once", SK.state().bases)

	# four more good bases: five in a row; a poor one breaks a streak
	var nb = PizzaBase.new(pz.d)
	SK.based(nb)
	check(SK.state().streak == 0, "a poor base breaks the run", SK.state().streak)
	for k in 5:
		nb = PizzaBase.new(pz.d)
		for j in nb.NS:
			nb.r[j] = nb.R
			nb.rim[j] = nb.crust
		SK.based(nb)
	check(SK.has("streak") and SK.rank() == "Senior pizzaiolo", "five good bases in a row: Five in a row, a senior pizzaiolo", [SK.state().streak, SK.rank()])

	# your own pizza served: the crust leopard-spotted all round, and a chef's look
	SK.served(pz, {"notes": ["Leopard spots all round the crust"], "look": 95.0})
	check(SK.has("leopard") and SK.has("chef") and SK.rank() == "Chef's hands", "a pizza leopard-spotted all round, looking 95: Chef's hands", [SK.count(), SK.rank()])
	await wait(3.2)
	check(m.toast_label.text.begins_with("Your hands:"), "a word when you reach one", m.toast_label.text)

	# kept in the save, and on the phone
	G.save_game()
	G.s.skills = {}
	G.load_game()
	check(SK.count() == SK.MILESTONES.size(), "kept in the save", SK.count())
	m.show_hub("home")
	await frames(10)
	check(label_starting(m.content, "Your hands: Chef's hands") != null, "the phone's home page shows it", label_starting(m.content, "Your hands") != null)
	var k = m.screen()
	if k.has_method("open_phone"):
		k.open_phone("home")
		await frames(5)
		var lb = label_starting(k.phone, "Your hands")
		if lb != null:
			var sc = lb.get_parent()
			while sc != null and not sc is ScrollContainer: sc = sc.get_parent()
			if sc != null: sc.ensure_control_visible(lb)
		await frames(5)
	await shot("your-hands")

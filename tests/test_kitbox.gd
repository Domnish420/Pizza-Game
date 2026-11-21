extends "res://tests/bot.gd"
## Equipment and KitBox, the catering-supplies site: what the van starts with, prep that needs the right board or a
## knife, cloths for cleaning, checkout and the parcel arriving, and every phone page drawing without an error.

func run() -> void:
	G.new_game()
	check(E.missing().map(func(x): return x.id) == ["first_aid"], "the van starts without a first aid kit, and nothing else missing",
		E.missing().map(func(x): return x.id))
	check(E.prep_block("onion").find("brown chopping board") >= 0, "onions need a brown board", E.prep_block("onion"))
	check(E.prep_block("ham").find("yellow chopping board") >= 0, "cooked meat needs a yellow board", E.prep_block("ham"))
	check(E.prep_block("mushroom") == "", "mushrooms can be prepped with the starting kit", E.prep_block("mushroom"))

	# the basket and checkout
	var cash0: float = G.s.cash
	E.add_missing()
	E.set_qty("rotary", 1)
	var sm: Dictionary = E.summary()
	check(sm.n == 2 and sm.goods > 0, "the basket has the first aid kit and a rotary grater", sm)
	var msg: String = E.checkout()
	check(msg == "" and G.s.cash < cash0 and G.s.kit_orders.size() == 1, "checkout pays and places the order",
		[msg, cash0, G.s.cash])

	# cloths: cleaning stops short without them
	G.s.clean.boh = 40.0
	H.clean("boh")
	check(H.level("boh") >= 99.0, "cleaning with cloths gets the kitchen clean", H.level("boh"))
	G.s.equip.cloths = 0
	G.s.clean.boh = 40.0
	var said: String = H.clean("boh")
	check(H.level("boh") < 80.0 and said.find("cloths") >= 0, "out of cloths, cleaning stops short", [H.level("boh"), said])
	G.s.equip.cloths = 50

	# prep: a knife is needed, and tubs get a day-dot label
	var res: Dictionary = S.prep("mushroom", 500, 0.8)
	check(res.made > 0 and res.block == "", "slicing mushrooms with a knife", res.made)
	G.s.equip.knife = 0
	res = S.prep("mushroom", 500, 0.8)
	check(res.made == 0 and res.block.find("knife") >= 0, "no knife, no slicing", res.block)
	G.s.equip.knife = 1
	check(H.inspect().notes.has("Missing: first aid kit"), "the inspector asks for the first aid kit", H.inspect().notes)

	# the parcel comes the next day
	G.nightfall()
	Dy.wait_until(14 * 60)
	check(E.count("first_aid") == 1 and E.count("rotary") == 1 and G.s.kit_orders.is_empty(), "the parcel arrives the next day",
		[E.count("first_aid"), E.count("rotary"), G.s.kit_orders.size()])
	check(E.missing().is_empty(), "nothing is missing now", E.missing())

	# every phone page draws
	await open_game()
	for page in ["home", "jobs", "stores", "kit", "boh", "foh", "dough", "menu", "staff"]:
		m.show_hub(page)
		await shot("hub-" + page)
		if page in ["menu", "stores"]:
			var want: String = {"menu": "Allergen chart", "stores": "Waste log"}[page]
			var labels: Array = m.find_children("*", "Label", true, false).map(func(l): return l.text)
			check(labels.any(func(t): return t.begins_with(want)), "the %s page has the %s" % [page, want.to_lower()])
	check(true, "the phone pages open")

	# the story's pizzeria comes fully kitted
	St.start()
	check(E.missing().is_empty(), "Bella Napoli has all its kit", E.missing().map(func(x): return x.id))
	check(E.rail_size() == int(G.tier("prep").rail), "its rail is full", [E.rail_size(), G.tier("prep").rail])

extends "res://tests/bot.gd"
## The rules of the stores, the clock and hygiene, without the screen: bulk pricing, the morning prep list, ordering
## (minimums, delivery windows), the fridge and dry-store vents, deliveries at the back door and stock rotation,
## mice when the place is dirty, the inspector, and traps.

func run() -> void:
	G.new_game()
	check(D.hhmm(G.s.clock) == "07:00", "a new game starts at 07:00", D.hhmm(G.s.clock))
	check(D.hhmm(Dy.open_time()) == "11:30", "the van opens at 11:30", D.hhmm(Dy.open_time()))
	check(S.climate("fridge")[1] == "ok" and S.climate("dry")[1] == "ok", "the fridge and dry store start fine",
		[S.climate("fridge")[0], S.climate("dry")[0]])

	# buying: bigger packs are cheaper per unit, and flour only comes in sacks
	var cc: Dictionary = D.SUP.cashcarry
	var by := {}
	for pr in M.products(cc):
		var k := "%s:%d" % [pr.ing, pr.g]
		if not by.has(k): by[k] = []
		by[k].append([pr.units, M.unit_price(cc, pr.ing, pr.g, pr.pack)])
	var worse := []
	for k in by:
		var ps: Array = by[k]
		ps.sort()
		for i in range(1, ps.size()):
			if ps[i][1] > ps[i - 1][1] + 1e-9: worse.append(k)
	check(by.size() > 5 and worse.is_empty(), "every bigger pack costs the same or less per unit", worse)
	var flour: Array = M.products(cc).filter(func(p): return p.ing.begins_with("flour"))
	check(flour.size() > 0 and flour.all(func(p): return p.units >= 25000), "flour comes only in 25 kg sacks",
		flour.map(func(p): return p.label))

	# the morning: prep the list into tubs, on the clock
	var rows: Array = Dy.prep_list()
	check(rows.size() > 0, "there is a prep list in the morning", rows.map(func(r): return r.id))
	var c0: float = G.s.clock
	for r in rows: Dy.do_prep(r.id, r.raw)
	check(G.s.clock > c0, "prepping takes time", D.hhmm(G.s.clock))
	check(S.prepped("mozz") > 0 and S.prepped("tomato") > 0, "the mozzarella and sauce are in tubs",
		[S.prepped("mozz"), S.prepped("tomato")])

	# ordering for tomorrow
	check(M.fill_basket("cashcarry") > 0, "the par sheet fills a cash & carry basket")
	check(M.summary("cashcarry").min_ok, "it is over the minimum")
	check(M.place("cashcarry") == "", "the order goes in")
	check(G.s.orders.size() == 1 and G.s.orders[0].due == G.s.day + 1, "it comes tomorrow",
		G.s.orders.map(func(o): return [o.sup, o.due, D.hhmm(o.eta)]))
	G.s.level = 2
	M.set_qty("harbour", "mozz:2:1", 2)
	var refused: String = M.place("harbour")
	check(refused.find("minimum") >= 0, "a small order under a supplier's minimum is refused", refused)
	var hb: Dictionary = D.SUP.harbour
	check(M.window(hb, 1) != M.window(hb, 85), "delivery windows move with the season",
		[M.window(hb, 1).map(D.hhmm), M.window(hb, 85).map(D.hhmm)])

	# a warm fridge overnight costs chilled food some life
	G.s.vent.fridge = 0
	check(S.climate("fridge")[1] != "ok", "a closed fridge vent runs warm", S.climate("fridge")[0])
	G.s.phase = "evening"
	G.s.clock = 21 * 60 + 15
	var night: Dictionary = G.nightfall()
	check(night.notes.any(func(x): return x.find("fridge") >= 0), "the night report says what the fridge cost", night.notes)
	check(G.s.day == 2 and D.hhmm(G.s.clock) == "07:00", "the next morning starts at 07:00", [G.s.day, D.hhmm(G.s.clock)])

	# the delivery arrives in its window and waits at the back door
	var eta: float = Dy.next_arrival()
	check(eta > G.s.clock, "the order is on its way", D.hhmm(eta))
	Dy.wait_until(eta)
	check(G.s.dock.size() == 1, "it is waiting at the back door", G.s.dock.size())
	if G.s.dock.size() > 0:
		var r: Dictionary = Dy.put_away(G.s.dock[0], false)
		check(r.minutes > 0 and G.s.dock.is_empty(), "putting it away takes time", r.minutes)
		check(S.rotation_problems().size() > 0, "put away without rotating, new stock sits in front of old",
			S.rotation_problems().map(func(p): return p.id))

	# a wide open fridge freezes, a wide open dry store lets pests in
	G.s.vent.fridge = 4
	G.s.vent.dry = 4
	check(S.climate("fridge")[1] == "bad", "a wide open fridge vent freezes", S.climate("fridge")[0])
	check(S.climate("dry")[1] != "ok", "a wide open dry-store vent lets pests in", S.climate("dry")[0])
	var st: Dictionary = S.night()
	check(st.notes.any(func(x): return x.find("froze") >= 0), "a freezing night spoils delicate food", st.notes)

	# mice: a dirty place with open vents and no traps gets them; the inspector notices
	G.s.clean.boh = 30
	G.s.clean.foh = 30
	var p0: float = G.s.pests.level
	for i in 6: H.night()
	check(G.s.pests.level > p0 + 10.0, "dirty, vents open, no traps: mice move in", [p0, G.s.pests.level])
	check(H.pest_causes().size() >= 3, "the reasons are spelled out", H.pest_causes())
	var insp: Dictionary = H.inspect()
	check(insp.rating <= 2, "the inspector marks it down", [insp.rating, insp.notes.slice(0, 3)])

	# cleaning, closing the vents and laying traps turn it round
	H.clean("boh")
	H.clean("foh")
	check(H.level("boh") >= 99.0 and H.level("foh") >= 99.0, "cleaning makes it clean", [H.level("boh"), H.level("foh")])
	G.s.vent.dry = 2
	G.s.vent.fridge = 2
	S.add("traps", 10, 2, 3.5)
	var lv: float = G.s.pests.level
	for i in H.traps_wanted(): H.lay_trap(null, true)
	check(H.laid() >= 2, "traps are down", H.laid())
	for i in 6:
		H.night()
		H.reset_traps()
	check(G.s.pests.level < lv, "with the place clean and traps down, the mice go", [lv, G.s.pests.level])

	# the waste log knows why things were binned
	var why: Dictionary = G.s.book.get("why", {})
	check(why.has("frozen"), "food lost to a freezing fridge is logged as frozen", why)
	check(G.s.books.size() > 0 and G.s.books[-1].has("why"), "each day's books keep why things were binned")
	var log_card = load("res://scripts/stores_page.gd").waste_log()
	var said: Array = log_card.find_children("*", "Label", true, false).map(func(l): return l.text)
	check(said.any(func(t): return t.begins_with("Waste log")) and said.any(func(t): return t.find("frozen") >= 0), "the waste log shows the week, and why", said.filter(func(t): return t.length() > 30))
	log_card.free()

	# allergens, worked out from the ingredients and the dough
	check(D.ALLERGENS.size() == 14, "the 14 allergens are listed", D.ALLERGENS.size())
	var undeclared: Array = D.ING.keys().filter(func(i): return D.ING[i].cat not in ["supply"] and not D.ING[i].has("allergens") and i not in ["box", "wood", "traps", "tub2", "tub4", "sanitiser"])
	check(undeclared.is_empty(), "every food says which allergens it has (even none)", undeclared)
	check(D.allergens_of(D.REC.margherita) == ["gluten", "milk"], "a margherita: gluten (the dough) and milk (the mozzarella)", D.allergens_of(D.REC.margherita))
	check(D.allergens_of({"base": "glutenfree", "spec": {"tomato": 60, "mozz": 100}}) == ["milk"], "on the gluten-free dough there is no gluten", D.allergens_of({"base": "glutenfree", "spec": {"tomato": 60, "mozz": 100}}))
	check(D.allergens_of({"base": "neapolitan", "spec": {"tomato": 60, "seafood": 80}}) == ["gluten", "crustaceans", "fish", "molluscs"], "frutti di mare: gluten, crustaceans, fish and molluscs", D.allergens_of({"base": "neapolitan", "spec": {"seafood": 80}}))
	var tira = D.EXTRAS.filter(func(x): return x.id == "tiramisu")[0]
	check(D.allergens_of(tira) == ["gluten", "egg", "milk"], "tiramisu: gluten, eggs and milk", D.allergens_of(tira))

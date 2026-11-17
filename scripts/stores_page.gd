class_name StoresPage
extends VBoxContainer
## The stock room: how full the stores are, the par sheet, what is on order, what you owe,
## every lot in stock with its date, and stock control (what was used against what the recipe cards allow).

var hub: Hub

func _init(h: Hub) -> void:
	hub = h
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)

func _cell(g: GridContainer, text: String, col: Color = Kit.INK, right: bool = true, size: int = 16) -> void:
	var l := Kit.label(text, size, col)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if right: l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	g.add_child(l)

func _ready() -> void:
	var G := Game
	# capacity and buying standard
	var cp = Kit.card()
	var bars := Kit.hbox(16)
	for st in Data.STORES:
		var v := Kit.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cap := Stock.store_cap(st)
		var used := Stock.store_used(st)
		var full: bool = cap > 0 and used / cap > 0.9
		v.add_child(Kit.label(("%s  %d of %d litres" % [Data.STORE_NAME[st], int(ceil(used)), int(cap)]) if cap > 0 else "No freezer", 18, Kit.TOMATO if full else Kit.INK))
		v.add_child(Kit.bar(used / cap if cap > 0 else 0.0, Kit.TOMATO if full else Kit.BASIL))
		var cl := Stock.climate(st)
		v.add_child(Kit.label(cl[0], 16, {"ok": Kit.BASIL, "warn": Kit.CHEESE, "bad": Kit.TOMATO}[cl[1]], true))
		if st != "freezer":
			var vh := Kit.hbox(3)
			for i in 5:
				var b := Kit.button(["Shut", "Low", "Med", "High", "Max"][i], func():
					Game.s.vent[st] = i
					Game.save_game()
					hub.render(), "primary" if Stock.vent(st) == i else "ghost", 14)
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				vh.add_child(b)
			v.add_child(vh)
			v.add_child(Kit.label("This full, it wants the vents about %s." % Stock.VENT_NAME[int(round(Stock.vent_need(st)))].to_lower(), 13, Kit.MUTED, true))
		bars.add_child(v)
	cp[1].add_child(bars)
	cp[1].add_child(Kit.label("Airflow: a fridge with too little runs warm and food spoils early; too much and it freezes leaves and soft cheese. The fuller it is, the more air it needs, and past 90% full nothing helps. A dry store with too little gets damp and mouldy; too much lets bugs and mice in.", 14, Kit.MUTED, true))
	var bh := Kit.hbox(6)
	bh.add_child(Kit.label("Buying standard:", 17, Kit.MUTED))
	for g in range(1, 6):
		if Data.GRADE_LVL[g] > G.s.level: continue
		bh.add_child(Kit.button(Data.GRADES[g], func():
			Game.s.house_grade = g
			Game.save_game()
			hub.render(), "primary" if G.s.house_grade == g else "ghost", 16))
	cp[1].add_child(bh)
	cp[1].add_child(Kit.label("The grade the par sheet and your manager buy at.", 14, Kit.MUTED, true))
	add_child(cp[0])

	# par sheet
	var pc = Kit.card("Par sheet")
	pc[1].add_child(Kit.label("What the next two days need by recipe card (prepped toppings at their raw weight), against what you hold. Everything is ordered the day before, so tomorrow's column is the one you can still fix." + ("" if G.s.phase == "morning" else "  Today's column is tonight's dough."), 14, Kit.MUTED, true))
	var pg := Kit.grid(6, 12)
	for hd in ["", "In stock", "Need today", "Need tomorrow", "On order", "Short"]: _cell(pg, hd, Kit.MUTED, hd != "", 14)
	var short_n := 0
	for row in Market.par():
		_cell(pg, Data.ING[row.id].name, Kit.INK, false)
		_cell(pg, Data.qty(row.id, row.have))
		_cell(pg, Data.qty(row.id, row.today) if row.today > 0 else "-", Kit.TOMATO if row.short_today > 0 else Kit.INK)
		_cell(pg, Data.qty(row.id, row.tomorrow) if row.tomorrow > 0 else "-")
		_cell(pg, Data.qty(row.id, row.incoming) if row.incoming > 0 else "-", Kit.BASIL)
		var sh: float = row.short_today + row.short_tomorrow
		if sh > 0: short_n += 1
		_cell(pg, Data.qty(row.id, sh) if sh > 0 else "ok", Kit.TOMATO if sh > 0 else Kit.BASIL)
	pc[1].add_child(pg)
	if short_n > 0: pc[1].add_child(Kit.button("Go to suppliers", hub.go.bind("suppliers"), "primary", 17))
	add_child(pc[0])

	# on order and owed
	if G.s.orders.size() > 0 or G.s.payables.size() > 0:
		var oc = Kit.card("On order and owed")
		for o in G.s.orders:
			var sup: Dictionary = Data.SUP[o.sup]
			var h := Kit.hbox(8)
			var l := Kit.label("%s · arrives %s · %s%s\n%s" % [sup.name, Data.DAY_NAME[G.weekday(int(o.due))], Kit.cents(o.total), " (paid)" if o.paid else " (on invoice)",
				", ".join(o.lines.map(func(ln): return "%s %s" % [ln.what, ln.name]))], 15, Kit.INK, true)
			h.add_child(l)
			h.add_child(Kit.button("Cancel", func():
				Market.cancel(o)
				Game.save_game()
				hub.render(), "ghost", 15))
			oc[1].add_child(h)
		for p in G.s.payables:
			oc[1].add_child(Kit.label("Invoice: %s · %s · due %s (day %d)" % [Data.SUP[p.sup].name, Kit.cents(p.amount), Data.DAY_NAME[G.weekday(int(p.due))], p.due], 15, Kit.CHEESE))
		add_child(oc[0])

	# the makeline
	var prepped := []
	for id in G.s.prepped:
		if Stock.prepped(id) > 0: prepped.append(id)
	if prepped.size() > 0:
		var mc = Kit.card("On the makeline (prepped)")
		for id in prepped:
			var ls: Array = Stock.prepped_lots(id).map(func(l): return "%s, %s" % [Data.qty(id, l.q), "bin tonight" if l.x <= G.s.day + 1 else "%d days" % floor(l.x - G.s.day)])
			mc[1].add_child(Kit.label("%s %s   (%s)" % [Data.ING[id].prep.as.capitalize(), Data.ING[id].name.to_lower(), "; ".join(ls)], 16, Kit.INK, true))
		add_child(mc[0])
	var probs := Stock.rotation_problems()
	if probs.size() > 0:
		var rc = Kit.card("Needs rotating")
		rc[1].add_child(Kit.label("New stock is stacked in front of older stock of " + ", ".join(probs.map(func(p): return Data.ING[p.id].name.to_lower())) + ". It gets used first and the old stock goes off at the back.", 15, Kit.CHEESE, true))
		var rm := Stock.rotate_minutes()
		rc[1].add_child(Kit.button("Rotate the stores · %d min" % rm, func():
			Stock.rotate_all()
			var notes := Day.spend(rm)
			Game.save_game()
			if notes.size() > 0: Kit.main.message("Meanwhile", "\n".join(notes), "OK")
			hub.render(), "primary", 16))
		add_child(rc[0])
	# what is on the shelves
	for st in Data.STORES:
		var ids := []
		for id in G.s.stock:
			if Data.ING[id].store == st and Stock.have(id) > 0: ids.append(id)
		if st == "fridge" and Stock.dough_count() == 0 and ids.is_empty(): continue
		if st != "fridge" and ids.is_empty(): continue
		ids.sort_custom(func(a, b): return Data.ING[a].name < Data.ING[b].name)
		var sc = Kit.card(Data.STORE_NAME[st])
		if st == "fridge":
			for l in G.s.dough:
				if l.n <= 0: continue
				sc[1].add_child(Kit.label("%d x %s dough · %s · %s" % [l.n, Data.DOUGHS[l.style].name, Stock.dough_status(l)[1], Data.grade_name(l.get("g", 2.0))], 16))
		for id in ids:
			var h := Kit.hbox(8)
			h.add_child(Kit.swatch(id, 18))
			var lots: Array = Stock.lots(id).map(func(l): return "%s %s, %s%s" % [Data.qty(id, l.q), Data.GRADES[int(l.g)], ("bin tonight" if l.x <= G.s.day + 1 else "%d days" % floor(l.x - G.s.day)) if l.x < G.s.day + 900 else "keeps", ", in front" if l.get("f", false) else ""])
			var l := Kit.label("%s   %s   (%s)" % [Data.ING[id].name, Data.qty(id, Stock.have(id)), "; ".join(lots)], 16, Kit.TOMATO if Stock.expiring(id) > 0 else Kit.INK, true)
			h.add_child(l)
			h.add_child(Kit.label(Kit.cents(Stock.value(id)), 15, Kit.MUTED))
			h.add_child(Kit.button("Bin", func(): Kit.main.confirm("Bin the %s?" % Data.ING[id].name.to_lower(), "%s worth %s goes in the bin and counts as waste." % [Data.qty(id, Stock.have(id)), Kit.cents(Stock.value(id))], "Bin it", func():
				Stock.bin(id)
				Game.save_game()
				hub.render()), "ghost", 14))
			sc[1].add_child(h)
		add_child(sc[0])

	# stock control
	var books: Array = G.s.books.duplicate()
	books.append(G.s.book)
	var shown := 0
	for i in range(books.size() - 1, -1, -1):
		var b: Dictionary = books[i]
		if b.sold == 0 and b.cost_waste <= 0.005: continue
		if shown >= 2: break
		shown += 1
		var title := "Stock control: today" if not b.has("day") else "Stock control: day %d" % b.day
		var kc = Kit.card(title)
		var over: float = b.cost_used - b.cost_spec
		kc[1].add_child(Kit.label("%d pizzas sold for %s. They used %s of food (%d%% of sales); the recipe cards allow %s. %s  Binned: %s." % [b.sold, Kit.cents(b.sales), Kit.cents(b.cost_used), (b.cost_used / b.sales * 100.0) if b.sales > 0 else 0.0, Kit.cents(b.cost_spec),
			("Over by %s." % Kit.cents(over)) if over > 0.005 else ("Under by %s." % Kit.cents(-over)), Kit.cents(b.cost_waste)], 15, Kit.MUTED, true))
		var kg := Kit.grid(5, 12)
		for hd in ["", "Used", "Recipe says", "Difference", "Binned"]: _cell(kg, hd, Kit.MUTED, hd != "", 14)
		var ids := {}
		for id in b.used: ids[id] = true
		for id in b.spec: ids[id] = true
		for id in b.waste: ids[id] = true
		for id in ids:
			var u: float = b.used.get(id, 0.0)
			var sp: float = b.spec.get(id, 0.0)
			var diff := u - sp
			var big: bool = sp > 0 and abs(diff) > sp * 0.1
			_cell(kg, Stock.label(id), Kit.INK, false)
			_cell(kg, Stock.amount(id, u) if u > 0 else "-")
			_cell(kg, Stock.amount(id, sp) if sp > 0 else "-")
			_cell(kg, ("%s%s" % ["+" if diff > 0 else "-", Stock.amount(id, abs(diff))]) if big else "ok", (Kit.TOMATO if diff > 0 else Kit.CHEESE) if big else Kit.BASIL)
			_cell(kg, Stock.amount(id, b.waste[id]) if b.waste.get(id, 0.0) > 0 else "-", Kit.TOMATO)
		kc[1].add_child(kg)
		add_child(kc[0])

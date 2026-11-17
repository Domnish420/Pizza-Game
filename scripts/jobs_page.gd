class_name JobsPage
extends VBoxContainer
## The jobs that fill the morning before you open and the evening after you close.
## Every job takes time on the clock (Day). In the morning that time comes out of the hours before opening;
## in the evening, working past midnight means a late start tomorrow.

var hub: Hub

func _init(h: Hub) -> void:
	hub = h
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)

func _do(minutes: float, fn: Callable, done_text: String = "") -> void:
	fn.call()
	var notes := Day.spend(minutes)
	Game.save_game()
	if notes.size() > 0: Kit.main.message("Meanwhile", "\n".join(notes), "OK")
	elif done_text != "": Kit.main.toast(done_text)
	hub.render()

func _lay_quick(n: int) -> void:
	for i in n: Hygiene.lay_trap()

func _row(parent: Node, text: String, sub: String, col: Color = Kit.INK) -> HBoxContainer:
	var h := Kit.hbox(8)
	var v := Kit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(Kit.label(text, 18, col, true))
	if sub != "": v.add_child(Kit.label(sub, 14, Kit.MUTED, true))
	h.add_child(v)
	parent.add_child(h)
	return h

## when an ingredient on order is due in today, or -1
func _due(id: String) -> float:
	for o in Day.pending():
		for ln in o.lines:
			if ln.ing == id: return o.eta
	return -1.0

func _ready() -> void:
	var G := Game
	var morning: bool = G.s.phase == "morning"
	var now := Day.now()

	# the clock
	var hc = Kit.card()
	if morning:
		var left: float = Day.open_time() - now
		hc[1].add_child(Kit.label("%s. You open at %s: %s." % [Data.hhmm(now), Data.hhmm(Day.open_time()), ("%d h %02d min to go" % [int(left) / 60, int(left) % 60]) if left > 0 else "you are late opening"], 22, Kit.INK if left > 0 else Kit.TOMATO, true))
		var nxt := Day.next_arrival()
		if nxt >= 0 and nxt < Day.close_time():
			var o: Dictionary = Day.pending()[0]
			var h := Kit.hbox(8)
			h.add_child(Kit.label("Next: %s at about %s%s." % [Data.SUP[o.sup].name, Data.hhmm(nxt), " (after you open)" if nxt >= Day.open_time() else ""], 16, Kit.MUTED, true))
			if nxt > now and nxt < Day.open_time():
				h.add_child(Kit.button("Wait for it", func():
					var notes := Day.wait_until(nxt)
					Game.save_game()
					if notes.size() > 0: Kit.main.message(Data.hhmm(Day.now()), "\n".join(notes), "OK")
					hub.render(), "ghost", 16))
			hc[1].add_child(h)
	else:
		hc[1].add_child(Kit.label("%s. Closed for the night." % Data.hhmm(now), 22, Kit.INK, true))
		hc[1].add_child(Kit.label("Clean down, make tomorrow's dough, order tomorrow's stock. Work past midnight and you start late tomorrow.", 15, Kit.MUTED, true))
	if G.s.notes.size() > 0 and morning:
		hc[1].add_child(Kit.label("\n".join(G.s.notes), 15, Kit.MUTED, true))
	add_child(hc[0])

	# the checklist and the temperature log
	var kind := "open" if morning else "close"
	var lc = Kit.card(("Opening" if morning else "Closing") + " checklist" + ((" (set by %s)" % Story.BOSS) if Story.role() == "pizzaiolo" else ""))
	var items := Checks.items(kind)
	var done_n := 0
	for it in items:
		if it.done: done_n += 1
	for it in items:
		lc[1].add_child(Kit.label(("[x] " if it.done else "[ ] ") + it.text + ("" if it.done else "   ->  " + it.hint), 16, Kit.BASIL if it.done else Kit.INK, true))
	lc[1].add_child(Kit.label("%d of %d done." % [done_n, items.size()], 14, Kit.MUTED))
	if Story.role() != "pizzaiolo":
		var th := Kit.hbox(8)
		for st in Checks.stores_to_log():
			var b := Kit.button("Record %s temperature · 1 min" % Data.STORE_NAME[st].to_lower(), func():
				var t := Checks.record(st)
				var notes := Day.spend(1)
				Game.save_game()
				Kit.main.toast("%s: %.1f °C written in the log%s" % [Data.STORE_NAME[st], t, "" if st == "freezer" or (t >= 1.0 and t <= 5.0) else ". OUT OF RANGE: adjust the vents"], st == "fridge" and (t < 1.0 or t > 5.0))
				if notes.size() > 0: Kit.main.message("Meanwhile", "\n".join(notes), "OK")
				hub.render(), "ghost", 15)
			b.disabled = Checks.logged(st) or not Equip.thermo_for(st)
			if not Equip.thermo_for(st): b.text = "No thermometer in the %s" % Data.STORE_NAME[st].to_lower()
			th.add_child(b)
		lc[1].add_child(th)
		lc[1].add_child(Kit.label("Temperature log, last 7 days: %d%% of readings taken. Inspectors check it." % (Checks.log_rate(7) * 100), 14, Kit.MUTED))
	add_child(lc[0])

	# senior: tomorrow's prep list for the junior
	if Story.role() == "senior" and not morning:
		var sc = Kit.card("Tomorrow's prep list for %s" % Story.JUNIOR)
		sc[1].add_child(Kit.label("%s comes in at 7 and preps exactly this, into tubs, then sets up the counter. Too little and you are prepping in the rush; too much and it goes in the bin." % Story.JUNIOR, 14, Kit.MUTED, true))
		var sheet: Dictionary = Game.s.story.sheet if int(Game.s.story.get("sheet_day", -1)) == G.s.day + 1 else {}
		var draft: Dictionary = sheet.duplicate()
		if draft.is_empty():
			for row in Day.prep_list(G.s.day + 1): draft[row.id] = snapped(row.need, 50.0)
		for id in draft:
			var h := Kit.hbox(8)
			var nm := Kit.label(Data.ING[id].name, 17)
			nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(nm)
			var ql := Kit.label(Data.qty(id, draft[id]) + " " + Data.ING[id].prep.as, 17, Kit.CHEESE)
			ql.custom_minimum_size.x = 160
			var stp: float = 50.0 if draft[id] < 1000.0 else 250.0
			for step in [-stp, stp]:
				var bb := Kit.button(("-" if step < 0 else "+") + "%d g" % stp, func():
					draft[id] = max(0.0, draft[id] + step)
					ql.text = Data.qty(id, draft[id]) + " " + Data.ING[id].prep.as, "ghost", 14)
				if step < 0: h.add_child(bb)
				else:
					h.add_child(ql)
					h.add_child(bb)
			sc[1].add_child(h)
		sc[1].add_child(Kit.button("Leave this list for %s" % Story.JUNIOR if sheet.is_empty() else "Update the list", func():
			Story.set_sheet(draft)
			Game.save_game()
			Kit.main.toast("Prep list left on the board for %s" % Story.JUNIOR)
			hub.render(), "primary", 16))
		add_child(sc[0])

	# the back door
	if G.s.dock.size() > 0:
		var dc = Kit.card("At the back door")
		for e in G.s.dock:
			var sup: Dictionary = Data.SUP[e.sup]
			var waited: float = max(0.0, now - e.arrived)
			var h := _row(dc[1], "%s · arrived %s" % [sup.name, Data.hhmm(e.arrived)],
				", ".join(e.lines.map(func(ln): return "%s %s" % [ln.what, ln.name])) + ". Waiting %d min: chilled food spoils after 30." % waited, Kit.TOMATO if waited > 30 else Kit.INK)
			var rm := Stock.dock_minutes(e, true)
			var qm := Stock.dock_minutes(e, false)
			h.add_child(Kit.button("Unpack by hand", func():
				var t := ShelfTask.new(e)
				t.finished.connect(hub.render)
				Kit.main.modal(t, 900), "primary", 15))
			h.add_child(Kit.button("Rotate all · %d min" % rm, func():
				var res := Day.put_away(e, true)
				Game.save_game()
				var msg: String = ("\n".join(res.notes) + "\n" if res.notes.size() > 0 else "") + res.text
				if msg.strip_edges() != "": Kit.main.message("Put away", msg.strip_edges(), "OK")
				hub.render(), "ghost", 15))
			h.add_child(Kit.button("Stack in front · %d min" % qm, func():
				var res := Day.put_away(e, false)
				Game.save_game()
				Kit.main.toast("Stacked in front of the old stock. Rotate it later or the old stock will go off at the back.")
				hub.render(), "ghost", 15))
		add_child(dc[0])

	# prep
	var day: int = G.s.day if morning else G.s.day + 1
	var pc = Kit.card("Prep list" + ("" if morning else " for tomorrow"))
	pc[1].add_child(Kit.label("Toppings come off the makeline. Prep what the day needs: too little and you are prepping mid-shift; too much and it goes off (prepped food keeps 1 to 4 days)." + ("" if morning else " Prepping tonight saves time tomorrow but uses up a day of its life."), 14, Kit.MUTED, true))
	var rows := Day.prep_list(day)
	var total := 0.0
	for row in rows:
		var it: Dictionary = Data.ING[row.id]
		var sub := "%s: need %s, %s on the line, %s raw in stock" % [it.prep.task, Data.qty(row.id, row.need), Data.qty(row.id, row.have), Data.qty(row.id, row.raw_have)]
		var h := _row(pc[1], it.name, sub, Kit.BASIL if row.todo <= 0.5 else (Kit.TOMATO if row.raw_have <= 0 else Kit.INK))
		if row.todo <= 0.5:
			h.add_child(Kit.label("Done", 15, Kit.BASIL))
		elif row.block != "":
			h.add_child(Kit.label(row.block, 14, Kit.TOMATO, true))
			h.add_child(Kit.button(Equip.SHOP.name, func():
				ShopPage.cat = "need"
				hub.go("kit"), "ghost", 15))
		elif row.raw <= 0:
			var at_door := false
			for e in G.s.dock:
				for ln in e.lines:
					if ln.ing == row.id: at_door = true
			h.add_child(Kit.label("Put the delivery away first" if at_door else ("Due in at %s" % Data.hhmm(_due(row.id)) if _due(row.id) >= 0 else "Nothing to prep it from"), 15, Kit.CHEESE if at_door or _due(row.id) >= 0 else Kit.TOMATO))
		else:
			total += row.minutes * 1.25
			if Equip.count("daydots") <= 0: h.add_child(Kit.label("No day-dot labels left", 14, Kit.TOMATO))
			h.add_child(Kit.button("Prep by hand", func():
				var t := PrepTask.new(row.id, row.raw)
				t.finished.connect(hub.render)
				Kit.main.modal(t, 900), "primary", 15))
			h.add_child(Kit.button("Quick · %d min" % ceil(row.minutes * 1.25), func():
				_do(ceil(row.minutes * 1.25), func(): Stock.prep(row.id, row.raw, 0.55), "Prepped the %s" % it.name.to_lower()), "ghost", 15))
			if row.tub_short: h.add_child(Kit.label("Not enough tubs for all of it", 14, Kit.TOMATO))
	if rows.is_empty(): pc[1].add_child(Kit.label("Nothing on the menu needs prep.", 15, Kit.MUTED))
	elif total > 0:
		pc[1].add_child(Kit.button("Quick-prep everything · %d min" % ceil(total), func():
			_do(ceil(total), func():
				for row in Day.prep_list(day):
					if row.raw > 0 and row.block == "": Stock.prep(row.id, row.raw, 0.55), "Prep done"), "ghost", 16))
	pc[1].add_child(Kit.label("Clean tubs: %d x 4 L, %d x 2 L. Waiting to be washed: %d." % [Stock.clean_tubs(4), Stock.clean_tubs(2), Stock.dirty_tubs()], 14, Kit.TOMATO if Stock.clean_tubs(4) + Stock.clean_tubs(2) < 3 else Kit.MUTED))
	if Stock.dirty_tubs() > 0:
		var wb := Kit.button("Wash up the tubs · %d min" % Stock.wash_minutes(), func(): _do(Stock.wash_minutes(), func(): Stock.wash_all(), "Tubs washed"), "ghost", 15)
		wb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		pc[1].add_child(wb)
	add_child(pc[0])

	# the counter
	if morning:
		var kc0 = Kit.card("The counter")
		var rl := Stock.rail()
		var empty := 0
		for pan in rl:
			if pan.ing == "" or pan.q < Stock.pan_cap(pan.ing) * 0.5: empty += 1
		kc0[1].add_child(Kit.label("%s: %d pans on the rail. %s" % [Game.tier("prep").n, rl.size(), "Every topping comes out of a pan. Fill them from the tubs (or straight from the stores for things that need no prep) before you open." if empty > 0 else "All set up."], 15, Kit.MUTED if empty == 0 else Kit.INK, true))
		var filled := []
		for pan in rl:
			if pan.ing != "": filled.append("%s %s" % [Data.ING[pan.ing].name.to_lower(), Data.qty(pan.ing, pan.q)])
		if filled.size() > 0: kc0[1].add_child(Kit.label(", ".join(filled), 14, Kit.MUTED, true))
		if empty > 0:
			var est: float = 1.0 * rl.size()
			kc0[1].add_child(Kit.button("Set up the counter · about %d min" % est, func():
				var res := Day.set_up_counter()
				var notes := Day.spend(res.minutes)
				Game.save_game()
				var msg := "%d pans filled." % res.filled
				if res.missing.size() > 0: msg += " No pan left for: " + ", ".join(res.missing.map(func(x): return Data.ING[x].name.to_lower())) + "."
				if notes.size() > 0: msg += "\n" + "\n".join(notes)
				Kit.main.message("The counter", msg, "OK")
				hub.render(), "primary", 16))
		add_child(kc0[0])

	# pizza boxes
	var need_boxes: int = Stock.boxes_needed(G.s.day if morning else G.s.day + 1)
	var bc = Kit.card("Pizza boxes")
	var flat := int(Stock.have("box"))
	var hb := _row(bc[1], "%d folded by the pass, %d flat" % [Stock.folded(), flat], "About %d takeaways %s. Boxes come flat: fold them before you open, or every takeaway waits while somebody folds one." % [need_boxes, "today" if morning else "tomorrow"], Kit.BASIL if Stock.folded() >= need_boxes else (Kit.TOMATO if flat + Stock.folded() < need_boxes else Kit.CHEESE))
	var to_fold: int = int(min(need_boxes - Stock.folded(), min(flat, Stock.fold_cap() - Stock.folded())))
	if flat > 0 and Stock.folded() < Stock.fold_cap():
		hb.add_child(Kit.button("Fold by hand", func():
			var t := FoldTask.new()
			t.finished.connect(hub.render)
			Kit.main.modal(t, 900), "primary", 15))
		if to_fold > 0: hb.add_child(Kit.button("Quick: fold %d · %d min" % [to_fold, ceil(to_fold * Stock.FOLD_MIN * 1.4)], func(): _do(ceil(to_fold * Stock.FOLD_MIN * 1.4), func(): Stock.fold(to_fold), "Boxes folded"), "ghost", 15))
	add_child(bc[0])

	# cleaning
	var cc = Kit.card("Cleaning")
	for area in ["boh", "foh"]:
		if area == "foh" and G.venue().tables == 0 and G.s.venue == 0:
			pass
		var nm: String = "Kitchen" if area == "boh" else ("Hatch and counter" if G.venue().tables == 0 else "Dining room")
		var hs := Hygiene.state(area)
		var mins := Hygiene.clean_minutes(area)
		var h := _row(cc[1], "%s: %s (%d%%)" % [nm, hs[0].to_lower(), Hygiene.level(area)], "Uses about %s of cleaning chemicals and %d cloths%s" % [Data.qty("sanitiser", Hygiene.chem_needed(area)), Equip.cloths_needed(area), ("" if not Equip.needs_mop(area) or Equip.has(Equip.mop_for(area)) else ". NO MOP: it will not come properly clean")], {"ok": Kit.BASIL, "warn": Kit.CHEESE, "bad": Kit.TOMATO}[hs[1]])
		if Hygiene.level(area) < 99.0:
			h.add_child(Kit.button("Clean by hand", func():
				var t := CleanTask.new(area)
				t.finished.connect(hub.render)
				Kit.main.modal(t, 900), "primary", 15))
			h.add_child(Kit.button("Quick · %d min" % mins, func():
				var msg := ""
				_do(mins, func(): msg = Hygiene.clean(area))
				if msg != "": Kit.main.toast(msg, true), "ghost", 15))
	cc[1].add_child(Kit.label("Cleaning chemicals in stock: %s. Cloths: %d. Spray bottles: %d." % [Data.qty("sanitiser", Stock.have("sanitiser")), Equip.count("cloths"), Equip.count("spray")], 14, Kit.TOMATO if Stock.have("sanitiser") < Hygiene.chem_needed("boh") or Equip.count("cloths") < Equip.cloths_needed("boh") or not Equip.has("spray") else Kit.MUTED))
	add_child(cc[0])

	# pests
	var kc = Kit.card("Pest control")
	var ps := Hygiene.pest_state()
	_row(kc[1], ps[0], ("Drawing them in: " + ", ".join(Hygiene.pest_causes()) + ".") if Hygiene.pest_causes().size() > 0 else "Keep it clean, keep the traps down.", {"ok": Kit.BASIL, "warn": Kit.CHEESE, "bad": Kit.TOMATO}[ps[1]])
	var lay: int = Hygiene.laid()
	var h2 := _row(kc[1], "Traps set: %d of the %d this place needs" % [lay, Hygiene.traps_wanted()], "%s in the box. %s. Traps only work against a wall, close to where mice get in." % [Data.qty("traps", Stock.have("traps")), "Proofing: " + G.tier("pest").n], Kit.INK if lay >= Hygiene.traps_wanted() else Kit.CHEESE)
	h2.add_child(Kit.button("Floor plan", func():
		var t := TrapTask.new()
		t.finished.connect(hub.render)
		Kit.main.modal(t, 900), "primary", 15))
	var short: int = min(Hygiene.traps_wanted() - lay - Hygiene.sprung(), int(Stock.have("traps")))
	if short > 0:
		h2.add_child(Kit.button("Quick: %d by the doors · %d min" % [short, 5 * short], func(): _do(5 * short, _lay_quick.bind(short), "Traps laid by the doors"), "ghost", 15))
	if Hygiene.sprung() > 0:
		var ns: int = Hygiene.sprung()
		var h3 := _row(kc[1], "%d sprung trap%s" % [ns, "" if ns == 1 else "s"], "Empty them and set them again where they are.", Kit.CHEESE)
		h3.add_child(Kit.button("Reset · %d min" % (2 * ns), func(): _do(2 * ns, func(): Hygiene.reset_traps(), "Traps reset"), "primary", 15))
	add_child(kc[0])

	# stock rotation and the stores' climate
	var rc = Kit.card("The stores")
	var probs := Stock.rotation_problems()
	if probs.is_empty():
		_row(rc[1], "Stock is rotated: oldest at the front.", "", Kit.BASIL)
	else:
		var h4 := _row(rc[1], "New stock stacked in front of older stock", ", ".join(probs.map(func(p): return "%s (%s behind)" % [Data.ING[p.id].name.to_lower(), Data.qty(p.id, p.behind)])) + ". The old stock will go off at the back.", Kit.CHEESE)
		var rm := Stock.rotate_minutes()
		h4.add_child(Kit.button("Rotate · %d min" % rm, func(): _do(rm, func(): Stock.rotate_all(), "Stores rotated"), "primary", 15))
	for store in ["fridge", "dry"]:
		var cl := Stock.climate(store)
		var h5 := _row(rc[1], "%s: %s" % [Data.STORE_NAME[store], cl[0]], "Vents %s. %d%% full." % [Stock.VENT_NAME[Stock.vent(store)].to_lower(), Stock.fill(store) * 100], {"ok": Kit.BASIL, "warn": Kit.CHEESE, "bad": Kit.TOMATO}[cl[1]])
		h5.add_child(Kit.button("Vents", hub.go.bind("stores"), "ghost", 15))
	add_child(rc[0])

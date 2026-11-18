class_name Hub
extends VBoxContainer
## The management screens between services:
## Today, Jobs, Suppliers, KitBox (the equipment site), Stores, Dough, Menu, Kitchen, Front, Staff, Property.
## Morning (from 07:00): deliveries, prep, cleaning, then open. Evening: clean down, make tomorrow's dough,
## order tomorrow's stock, lock up. Jobs take time on the clock.

const TABS := [["home", "Today"], ["jobs", "Jobs"], ["suppliers", "Suppliers"], ["kit", "KitBox"], ["stores", "Stores"], ["dough", "Dough"], ["menu", "Menu"],
	["boh", "Kitchen"], ["foh", "Front"], ["staff", "Staff"], ["property", "Property"]]
var tab := "home"
var top: HBoxContainer
var rail: VBoxContainer
var scroll: ScrollContainer
var page: VBoxContainer

func _ready() -> void:
	add_theme_constant_override("separation", 10)
	top = Kit.hbox(10)
	add_child(top)
	var body := Kit.hbox(12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)
	rail = Kit.vbox(3)
	rail.custom_minimum_size.x = 150
	body.add_child(rail)
	scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	page = Kit.vbox(10)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(page)
	render()

func go(t: String) -> void:
	tab = t
	scroll.scroll_vertical = 0
	render()

func render() -> void:
	var G := Game
	var keep := scroll.scroll_vertical
	Kit.clear(top)
	Kit.clear(rail)
	Kit.clear(page)
	var v := G.venue()
	var name_l := Kit.label(Story.EMPLOYER if Story.employed() else v.name, 26)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.clip_text = true
	top.add_child(name_l)
	top.add_child(Kit.chip("%s · day %d" % [Data.DAY_SHORT[G.weekday()], G.s.day], Kit.PANEL, Kit.INK, 17))
	var late: bool = G.s.phase == "morning" and Day.now() > Day.open_time()
	top.add_child(Kit.chip(Data.hhmm(Day.now()) + (("  ·  opens " + Data.hhmm(Day.open_time())) if G.s.phase == "morning" else "  ·  evening"), Kit.TOMATO if late else Kit.PANEL, Color.WHITE if late else Kit.CHEESE, 17))
	top.add_child(Kit.chip("%.1f / 5" % G.s.rep, Kit.PANEL, Kit.INK, 17))
	top.add_child(Kit.chip("Level %d  (%d / %d)" % [G.s.level, G.s.xp, G.xp_need(G.s.level)], Kit.PANEL, Kit.INK, 17))
	if Story.employed(): top.add_child(Kit.label("Savings " + Kit.money(G.s.story.savings), 24, Kit.CHEESE))
	else: top.add_child(Kit.label(Kit.money(G.s.cash), 28, Kit.TOMATO if G.s.cash < 0 else Kit.CHEESE))
	if G.s.phase == "evening":
		top.add_child(Kit.button("Clock off" if Story.employed() else "Lock up & sleep", _sleep, "primary", 22))
	elif G.s.hygiene.get("closed_day", -1) == G.s.day:
		top.add_child(Kit.button("Closed today", _closed_day, "ghost", 22))
	else:
		top.add_child(Kit.button(("Start service " if Story.employed() else "Open at ") + Data.hhmm(max(Day.now(), Day.open_time())), _open, "danger", 22))
	var allowed: Array = {"pizzaiolo": ["home", "jobs", "menu"], "senior": ["home", "jobs", "suppliers", "kit", "stores", "dough", "menu"]}.get(Story.role(), [])
	for t in TABS:
		if allowed.size() > 0 and not allowed.has(t[0]): continue
		var b := Kit.button(t[1], go.bind(t[0]), "tab_on" if tab == t[0] else "tab", 20)
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		rail.add_child(b)
	call("_page_" + tab)
	await get_tree().process_frame
	if is_instance_valid(scroll): scroll.scroll_vertical = keep

# ---------- helpers ----------
func _stats(parent: Node, items: Array) -> void:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 6)
	f.add_theme_constant_override("v_separation", 6)
	for t in items: f.add_child(Kit.chip(t, Kit.BG, Kit.INK, 16))
	parent.add_child(f)

func _tag(text: String, col: Color = Kit.MUTED) -> Control:
	return Kit.chip(text, Kit.PANEL2, col, 15)

func _act(fn: Callable) -> void:
	fn.call()
	Game.save_game()
	render()

func _page_suppliers() -> void:
	page.add_child(SuppliersPage.new(self))

func _page_kit() -> void:
	page.add_child(ShopPage.new(self))

func _page_stores() -> void:
	page.add_child(StoresPage.new(self))

func _page_jobs() -> void:
	page.add_child(JobsPage.new(self))

# ---------- Today ----------
func _story_card() -> void:
	var G := Game
	var st: Dictionary = G.s.story
	var title := "Your career"
	if Story.employed(): title = "%s at %s" % ["Pizzaiolo" if Story.role() == "pizzaiolo" else "Senior pizzaiolo", Story.EMPLOYER]
	var sc = Kit.card(title)
	if G.s.notes.size() > 0 and G.s.phase == "morning":
		sc[1].add_child(Kit.label("\n".join(G.s.notes), 16, Kit.INK, true))
	var revs: Array = st.get("reviews", [])
	if revs.size() > 0 and Story.employed():
		var last: Dictionary = revs[-1]
		sc[1].add_child(Kit.label("Last shift: %d / 100. %s: \"%s\"" % [last.score, Story.BOSS, " ".join(last.lines)], 15, Kit.MUTED, true))
	sc[1].add_child(Kit.label("Next promotion:" if Story.employed() else "Goals:", 17, Kit.CHEESE))
	for gl in Story.goals():
		sc[1].add_child(Kit.label(("Done: " if gl[1] else "To do: ") + gl[0], 16, Kit.BASIL if gl[1] else Kit.INK, true))
	if Story.employed(): sc[1].add_child(Kit.label("Wage %s a shift, paid into your savings. You will need them for your own van one day." % Kit.money(Story.WAGE[Story.role()]), 14, Kit.MUTED, true))
	page.add_child(sc[0])

func _page_home() -> void:
	var G := Game
	var c := G.calc()
	var v := G.venue()
	if Story.stage() != "free": _story_card()
	var g := Kit.grid(2)
	page.add_child(g)
	var hero = Kit.card(G.date_text())
	hero[1].add_child(Kit.label(v.desc, 16, Kit.MUTED, true))
	var st := ["About %d customers today" % c.total, G.tier("oven").n, "%d staff, %s a day" % [G.s.staff.size(), Kit.money(G.wages())],
		"%s %s" % ["Pitch fee" if G.pitch() != null else v.rentName, Kit.money(G.rent())], "Gas & electric %s" % Kit.money(G.utilities())]
	if c.tables > 0: st.append("%d tables" % c.tables)
	if Market.owed() > 0: st.append("Owe suppliers %s" % Kit.money(Market.owed()))
	st.append("Hygiene rating " + (str(G.s.hygiene.rating) if G.s.hygiene.rating >= 0 else "not yet inspected"))
	_stats(hero[1], st)
	g.add_child(hero[0])

	var todo = Kit.card("Tonight's jobs" if G.s.phase == "evening" else "Before you open")
	var lines := []
	if G.s.phase == "morning":
		var recs := G.active_recipes()
		var styles := []
		for r in recs:
			if not styles.has(r.base): styles.append(r.base)
		for sty in styles:
			var n := Stock.dough_ready(sty)
			var dn: String = Data.DOUGHS[sty].name
			if n < 1: lines.append(["bad", "No %s dough is ready today." % dn])
			elif n < c.total * 0.7 / styles.size(): lines.append(["warn", "%d %s dough balls ready for about %d customers." % [n, dn, c.total]])
			else: lines.append(["ok", "%d %s dough balls ready." % [n, dn]])
		var short := []
		for row in Market.par():
			if row.short_today > 0 and Market.incoming(row.id, G.s.day) <= 0: short.append("%s (%s short)" % [Data.ING[row.id].name, Data.qty(row.id, row.short_today)])
		if short.size() > 0: lines.append(["bad", "Not enough for today: " + ", ".join(short) + ". It is too late to order for today: plan to 86 what you cannot make."])
		else: lines.append(["ok", "The stores cover today's service by recipe card."])
		var todo_prep := 0.0
		var tub_short := false
		for row in Day.prep_list():
			todo_prep += row.minutes
			if row.tub_short: tub_short = true
		if tub_short: lines.append(["bad", "Not enough clean tubs for today's prep. Wash up, and order more 4 litre tubs for tomorrow."])
		if todo_prep > 1.0: lines.append(["warn", "About %d minutes of prep to do before you open. See Jobs." % ceil(todo_prep)])
		if Stock.folded() < min(Stock.boxes_needed(), Stock.fold_cap()) * 0.5:
			lines.append(["warn" if Stock.have("box") >= 1 else "bad", ("Only %d pizza boxes folded for about %d takeaways. Fold some before you open (Jobs)." % [Stock.folded(), Stock.boxes_needed()]) if Stock.have("box") >= 1 else "No pizza boxes left. Order some."])
		if G.s.dock.size() > 0: lines.append(["bad", "%d deliver%s waiting at the back door to be put away." % [G.s.dock.size(), "y" if G.s.dock.size() == 1 else "ies"]])
		for o in Day.pending(): lines.append(["info", "%s due at about %s%s." % [Data.SUP[o.sup].name, Data.hhmm(o.eta), " (during service)" if o.eta >= Day.open_time() else ""]])
	var plan := G.dough_plan()
	for sty in plan:
		if plan[sty] > 0:
			lines.append(["warn" if G.s.phase == "evening" else "info", "Tomorrow needs about %d more %s dough balls. Dough made today is ready tomorrow." % [plan[sty], Data.DOUGHS[sty].name]])
	var short_tm := 0
	for row in Market.par():
		if row.short_tomorrow > 0: short_tm += 1
	if short_tm > 0: lines.append(["warn", "%d ingredients will be short tomorrow. Order today: everything is bought the day before." % short_tm])
	for o in G.s.orders:
		if int(o.due) == G.s.day + 1: lines.append(["info", "%s delivers tomorrow morning (%s)." % [Data.SUP[o.sup].name, Kit.cents(o.total)]])
	for p in G.s.payables:
		if p.due - G.s.day <= 2: lines.append(["warn", "%s invoice of %s is due %s." % [Data.SUP[p.sup].name, Kit.cents(p.amount), "tomorrow" if p.due - G.s.day <= 1 else "in 2 days"]])
	if G.tier("oven").type == "wood" and Stock.have("wood") < 6: lines.append(["bad", "Only %d logs left for the wood oven." % int(Stock.have("wood"))])
	for store in ["fridge", "dry"]:
		var cl := Stock.climate(store)
		if cl[1] != "ok": lines.append([cl[1], "%s: %s. Adjust the vents on the Stores page." % [Data.STORE_NAME[store], cl[0]]])
	for area in ["boh", "foh"]:
		var hs := Hygiene.state(area)
		if hs[1] != "ok" and not (area == "foh" and G.venue().tables == 0 and Hygiene.level(area) > 40): lines.append([hs[1], "%s: %s (%d%%)." % ["Kitchen" if area == "boh" else "Front of house", hs[0].to_lower(), Hygiene.level(area)]])
	var ps := Hygiene.pest_state()
	if ps[1] != "ok": lines.append([ps[1], "%s. Causes: %s." % [ps[0], ", ".join(Hygiene.pest_causes())] if Hygiene.pest_causes().size() > 0 else ps[0] + "."])
	if Hygiene.sprung() > 0: lines.append(["warn", "%d sprung trap%s to reset." % [Hygiene.sprung(), "" if Hygiene.sprung() == 1 else "s"]])
	if G.cycle_left() <= 3:
		lines.append(["warn", "The menu changes in %d day%s. %s" % [G.cycle_left(), "" if G.cycle_left() == 1 else "s", "Run your stock down." if G.s.next_menu != "" else "Book the next one on the Menu page or you fall back to House Classics."]])
	if G.s.cash < 0: lines.append(["bad", "Overdrawn: the bank charges 5% a day."])
	if int(G.s.upg.drinks) >= 3 and G.staff_of("bartender").is_empty(): lines.append(["warn", "The bar needs a bartender."])
	if int(G.s.upg.delivery) > 0 and G.staff_of("driver").is_empty(): lines.append(["warn", "Delivery needs a driver."])
	var miss := Equip.missing()
	if miss.size() > 0:
		lines.append(["bad" if miss.any(func(m): return m.have == 0) else "warn", "Kit you are short of: %s. Order from %s (next working day)." % [", ".join(miss.slice(0, 6).map(func(m): return Equip.ITEM[m.id].short)) + (" and %d more" % (miss.size() - 6) if miss.size() > 6 else ""), Equip.SHOP.name]])
	for o in G.s.get("kit_orders", []):
		if int(o.due) <= G.s.day + 1: lines.append(["info", "%s parcel arrives %s at about %s." % [Equip.SHOP.name, "today" if int(o.due) == G.s.day else "tomorrow", Data.hhmm(o.eta)]])
	if Story.role() == "pizzaiolo":       # the boss handles ordering, dough and the stores
		lines = lines.filter(func(l): return l[1].find("dough balls ready") >= 0 or l[1].find("prep") >= 0 or l[1].find("cover today") >= 0 or l[1].find("Kitchen") == 0)
	for l in lines:
		var col: Color = {"ok": Kit.BASIL, "warn": Kit.CHEESE, "bad": Kit.TOMATO, "info": Kit.MUTED}[l[0]]
		todo[1].add_child(Kit.label(l[1], 17, col, true))
	if G.s.day == 1 and G.s.phase == "morning" and Story.stage() == "free":
		todo[1].add_child(Kit.label("First day: the last owner left a tray of dough and some stock. Open up, take orders at the hatch, make each pizza to its recipe card. Tonight, make dough and order for tomorrow.", 15, Kit.MUTED, true))
	g.add_child(todo[0])

	if Story.employed():
		var kc = Kit.card("Today's checklist")
		for it in Checks.items("open" if G.s.phase == "morning" else "close"):
			kc[1].add_child(Kit.label(("Done: " if it.done else "To do: ") + it.text + ("" if it.done else "  (" + it.hint + ")"), 16, Kit.BASIL if it.done else Kit.INK, true))
		g.add_child(kc[0])
		return
	# where the van trades
	if v.has("pitches"):
		var pc = Kit.card("Today's pitch")
		for i in v.pitches.size():
			var p: Dictionary = v.pitches[i]
			var f: float = p.days[G.weekday()] * (p.season[G.season()] if p.has("season") else 1.0)
			var h := Kit.hbox(8)
			var tx := Kit.vbox(0)
			tx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tx.add_child(Kit.label("%s  ·  %s" % [p.name, Kit.money(p.fee)], 18))
			tx.add_child(Kit.label(p.desc, 14, Kit.MUTED, true))
			h.add_child(tx)
			if G.s.level < p.lvl: h.add_child(_tag("Level %d" % p.lvl))
			elif f <= 0: h.add_child(_tag("Not %ss" % Data.DAY_NAME[G.weekday()]))
			elif int(G.s.pitch) == i: h.add_child(_tag("Here today · about %d customers" % G.covers(), Kit.BASIL))
			elif G.s.phase != "morning": h.add_child(_tag("x%.1f" % f))
			else: h.add_child(Kit.button("Trade here (x%.1f)" % f, func(): _act(func(): Game.s.pitch = i), "ghost", 15))
			pc[1].add_child(h)
		g.add_child(pc[0])

	var l: Dictionary = G.s.last
	if not l.is_empty():
		var lc = Kit.card("Day %d takings" % l.day)
		_stats(lc[1], ["%d pizzas served" % l.served, "%d customers lost" % l.lost, "Profit %s" % Kit.money(l.profit)])
		if l.get("n_rev", 0) > 0:
			_stats(lc[1], ["Look %.1f" % l.cats.look, "Taste %.1f" % l.cats.taste, "Service %.1f" % l.cats.service, "Value %.1f" % l.cats.value])
		g.add_child(lc[0])
	var nc = Kit.card("Next step up")
	if G.s.venue + 1 < Data.VENUES.size():
		var nv = Data.VENUES[G.s.venue + 1]
		nc[1].add_child(Kit.label("%s  ·  %s  ·  needs level %d" % [nv.name, Kit.money(nv.cost), nv.lvl], 18))
		nc[1].add_child(Kit.bar(G.s.cash / nv.cost))
	else:
		nc[1].add_child(Kit.label("You run the best pizzeria in town. Keep the ovens hot.", 18, Kit.MUTED, true))
	nc[1].add_child(Kit.label("%d pizzas sold · %s taken all-time" % [G.s.pizzas, Kit.money(G.s.earned)], 15, Kit.MUTED))
	var vh := Kit.hbox(6)
	vh.add_child(Kit.button("Service in 3D: " + ("on" if G.s.get("view3d", true) else "off"), func(): _act(func(): Game.s.view3d = not Game.s.get("view3d", true)), "ghost", 15))
	vh.add_child(Kit.button("Look by turning the phone: " + ("on" if G.s.get("gyro", true) else "off"), func(): _act(func(): Game.s.gyro = not Game.s.get("gyro", true)), "ghost", 15))
	vh.add_child(Kit.button("Retro look: " + ("on" if G.s.get("retro", false) else "off"), func(): _act(func(): Game.s.retro = not Game.s.get("retro", false)), "ghost", 15))
	nc[1].add_child(vh)
	var reset := Kit.button("Start over", func(): Kit.main.confirm("Start over?", "This wipes your save and takes you back to the start.", "Wipe my save", func():
		Game.new_game()
		Kit.main.show_start()), "ghost", 15)
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	nc[1].add_child(reset)
	g.add_child(nc[0])

# ---------- Dough ----------
func _page_dough() -> void:
	var G := Game
	var c := G.calc()
	var trays = Kit.card("Dough in the fridge")
	if G.s.dough.is_empty():
		trays[1].add_child(Kit.label("No dough. Anything you make now is ready tomorrow.", 18, Kit.TOMATO, true))
	for l in G.s.dough:
		var stt := Stock.dough_status(l)
		var h := Kit.hbox(10)
		var a := Kit.label("%d x %s" % [l.n, Data.DOUGHS[l.style].name], 19)
		a.custom_minimum_size.x = 230
		h.add_child(a)
		h.add_child(Kit.label("Quality %d · %s flour" % [l.q, Data.grade_name(l.get("g", 2.0))], 16, Kit.MUTED))
		var sl := Kit.label(stt[1], 18, {"proof": Kit.MUTED, "ok": Kit.BASIL, "peak": Kit.BASIL, "last": Kit.CHEESE}[stt[0]])
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(sl)
		trays[1].add_child(h)
	trays[1].add_child(Kit.label("Dough made today cold-proofs overnight and is ready tomorrow. It keeps %d days, then it has overproofed and goes in the bin. Each ball takes half a fridge space." % (3 + int(G.tier("proofer").days)), 15, Kit.MUTED, true))
	var plan := G.dough_plan()
	for sty in plan:
		if plan[sty] > 0: trays[1].add_child(Kit.label("Tomorrow: about %d more %s balls needed." % [plan[sty], Data.DOUGHS[sty].name], 17, Kit.CHEESE))
	page.add_child(trays[0])

	var g := Kit.grid(2)
	page.add_child(g)
	for k in Data.DOUGHS:
		var d = Data.DOUGHS[k]
		var cd = Kit.card(d.name + " dough")
		if G.s.level < d.lvl:
			cd[1].add_child(_tag("Unlocks at level %d" % d.lvl))
			cd[0].modulate.a = 0.55
			g.add_child(cd[0])
			continue
		cd[1].add_child(Kit.label(d.desc, 15, Kit.MUTED, true))
		var parts := []
		for p in d.parts:
			parts.append("%s %s%%" % ["water" if p.ing == "water" else Data.ING[p.ing].name.to_lower(), str(p.pct).trim_suffix(".0")])
		cd[1].add_child(Kit.label("Recipe (per 100 of flour): " + ", ".join(parts), 16, Kit.INK, true))
		cd[1].add_child(Kit.label("%d g balls, about %d from a kilo of flour. %s to %d cm%s." % [d.ball, int(1000.0 / Stock.flour_per_ball(k)),
			{"hand": "Pressed out and stretched by hand", "roll": "Rolled with a pin", "press": "Pressed into a pan"}[d.shape], d.size_cm,
			(", leaving a %s cm rim" % str(d.crust_cm).trim_suffix(".0")) if d.crust_cm > 0 else ", no rim"], 15, Kit.MUTED, true))
		var can := DoughGame.can_batch(d, 0.5)
		var why := "" if can else "Not enough flour"
		if why == "" and not Equip.can_mix(): why = "No mixing bowl (%s)" % Equip.SHOP.name
		if why == "" and Equip.dough_room() <= 0: why = "Proving trays full (%s)" % Equip.SHOP.name
		var b := Kit.button("Make %s dough" % d.name if why == "" else why, func(): Kit.main.modal(DoughGame.new(k), 1040), "primary", 19)
		b.disabled = why != ""
		cd[1].add_child(b)
		g.add_child(cd[0])
	page.add_child(Kit.label("Proving trays: %d, room for %d more dough balls (%d per tray).%s%s" % [Equip.count("dough_tray"), Equip.dough_room(), int(Equip.ITEM.dough_tray.holds), "" if Equip.has("scales") else " No scales: you are weighing by eye.", "" if Equip.has("scraper") else " No bench scraper: your balls come out uneven."], 15, Kit.TOMATO if Equip.dough_room() < 12 or not Equip.has("scales") else Kit.MUTED, true))
	page.add_child(Kit.label("Mixer: %s (up to %d kg of flour per batch)." % [G.tier("mixer").n, c.batch] + ("  Your prep cook makes tomorrow's dough at close." if G.staff_of("prep").size() > 0 else ""), 15, Kit.MUTED, true))

# ---------- Menu ----------
func recipe_card(r: Dictionary) -> void:
	var G := Game
	var d: Dictionary = Data.DOUGHS[r.base]
	var rc := Market.recipe_cost(r)
	var price: float = r.price * G.calc().price_mult
	var v := Kit.vbox(6)
	v.add_child(Kit.label("%s  ·  recipe card" % r.name, 26))
	v.add_child(Kit.label("%s base: one %d g dough ball, %s to %d cm%s. Bakes %s." % [d.name, d.ball,
		{"hand": "pressed out and stretched by hand", "roll": "rolled with a pin", "press": "pressed into a pan"}[d.shape], d.size_cm,
		(" with a %s cm rim" % str(d.crust_cm).trim_suffix(".0")) if d.crust_cm > 0 else ", no rim",
		"in the standard time" if d.bake == 1 else ("%d%% %s than standard" % [abs(d.bake - 1.0) * 100, "longer" if d.bake > 1 else "quicker"])], 16, Kit.MUTED, true))
	var g := Kit.grid(3, 20)
	for ln in rc.lines:
		var is_dough: bool = ln.id.begins_with("dough:")
		var nm := Kit.label(Stock.label(ln.id) + ("  (after the oven)" if not is_dough and Data.ING[ln.id].after else ""), 18)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(nm)
		var q := Kit.label("1 ball" if is_dough else Data.qty(ln.id, ln.q), 18, Kit.CHEESE)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		g.add_child(q)
		var cst := Kit.label(Kit.cents(ln.cost), 18, Kit.MUTED)
		cst.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		g.add_child(cst)
	v.add_child(g)
	var margin: float = (price - rc.cost) / price * 100.0
	v.add_child(Kit.label("Costs %s to make to the card. Sells for %s. Food cost %d%%, margin %s." % [Kit.cents(rc.cost), Kit.cents(price), 100.0 - margin, Kit.cents(price - rc.cost)], 19, Kit.BASIL if margin >= 70 else Kit.CHEESE, true))
	v.add_child(Kit.label("Costs use what your stock actually cost you, or today's best price at your buying standard for anything you do not hold. Every gram over the card comes off that margin; go too far under and customers call you stingy.", 14, Kit.MUTED, true))
	v.add_child(Kit.button("Close", Kit.main.close_modal))
	Kit.main.modal(v, 760)

func _menu_lines(parent: Node, m: Dictionary, toggles: bool) -> void:
	var G := Game
	for id in m.items:
		var r = Data.REC[id]
		var h := Kit.hbox(6)
		var v := Kit.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var price: float = r.price * G.calc().price_mult
		v.add_child(Kit.label("%s  ·  %s" % [r.name, Kit.cents(price)], 19))
		var ing := []
		for i in r.spec: ing.append("%s %s" % [Data.qty(i, r.spec[i]), Data.ING[i].name.to_lower()])
		v.add_child(Kit.label("%s base · %s" % [Data.DOUGHS[r.base].name, ", ".join(ing)], 14, Kit.MUTED, true))
		h.add_child(v)
		if toggles:
			var cost: float = Market.recipe_cost(r).cost
			h.add_child(Kit.label("%d%%" % (cost / price * 100.0), 16, Kit.BASIL if cost / price < 0.3 else Kit.CHEESE))
			h.add_child(Kit.button("Card", recipe_card.bind(r), "ghost", 15))
			var off: bool = G.s.off.get(id, false)
			h.add_child(Kit.button("Off" if off else "On", func(): _act(func():
				if not off and Game.active_recipes().size() < 2:
					Kit.main.toast("Keep at least one pizza on", true)
				else:
					Game.s.off[id] = not off), "ghost" if off else "primary", 15))
		parent.add_child(h)

## sides, desserts and drinks: what you sell on top of the pizzas, and switching each on or off
func _extras_card() -> Control:
	var G := Game
	var xc = Kit.card("Sides, desserts and drinks")
	xc[1].add_child(Kit.label("Customers add these to their order. Baked sides and desserts are made on the bench and go through the oven like a pizza; cold ones are plated from the rail or the fridge; drinks come out of the fridge with the order, or are made at the coffee machine or the bar. At a table, dessert is ordered after the meal.", 15, Kit.MUTED, true))
	var xg := Kit.grid(2)
	for x in Data.EXTRAS:
		var h := Kit.hbox(6)
		var v := Kit.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var price: float = x.price * G.calc().price_mult
		v.add_child(Kit.label("%s  ·  %s" % [x.name, Kit.cents(price)], 17))
		var how: String = {"oven": "baked", "cold": "plated", "hand": "from the fridge", "bar": "made at the bar"}[x.make]
		var ing := []
		for i in x.spec: ing.append("%s %s" % [Data.qty(i, x.spec[i]), Data.ING[i].name.to_lower()])
		v.add_child(Kit.label("%s, %s · %s" % [x.course.capitalize(), how, ", ".join(ing)], 13, Kit.MUTED, true))
		h.add_child(v)
		var block := G.extra_block(x)
		if block != "":
			h.add_child(Kit.label(block, 13, Kit.CHEESE, true))
		else:
			var cost: float = Market.recipe_cost(x).cost
			h.add_child(Kit.label("%d%%" % (cost / price * 100.0), 15, Kit.BASIL if cost / price < 0.3 else Kit.CHEESE))
			var off: bool = G.s.get("extra_off", {}).get(x.id, false)
			h.add_child(Kit.button("Off" if off else "On", func(): _act(func():
				if not Game.s.has("extra_off"): Game.s.extra_off = {}
				Game.s.extra_off[x.id] = not off), "ghost" if off else "primary", 14))
		xg.add_child(h)
	xc[1].add_child(xg)
	return xc[0]

func _page_menu() -> void:
	var G := Game
	var m := G.menu_now()
	var g := Kit.grid(2)
	page.add_child(g)
	if Story.employed():
		var ec = Kit.card("Tonight's menu: " + m.name)
		ec[1].add_child(Kit.label("Learn the recipe cards: every gram over is the boss's money, every gram under is a customer who notices.", 15, Kit.MUTED, true))
		for id in m.items:
			var rr: Dictionary = Data.REC[id]
			var h := Kit.hbox(8)
			var nm := Kit.label("%s · %s" % [rr.name, ", ".join(rr.spec.keys().map(func(i): return "%s %s" % [Data.qty(i, rr.spec[i]), Data.ING[i].name.to_lower()]))], 17, Kit.INK, true)
			h.add_child(nm)
			h.add_child(Kit.button("Recipe card", recipe_card.bind(rr), "ghost", 15))
			ec[1].add_child(h)
		page.add_child(ec[0])
		return
	var cur = Kit.card("Now serving: " + m.name)
	cur[1].add_child(Kit.label("%d day%s left on this menu. The percentage is food cost: what the recipe costs against what it sells for." % [G.cycle_left(), "" if G.cycle_left() == 1 else "s"], 15, Kit.CHEESE if G.cycle_left() <= 3 else Kit.MUTED, true))
	_menu_lines(cur[1], m, true)
	g.add_child(cur[0])

	var pc = Kit.card("Pricing")
	var names := ["Budget", "Standard", "Premium"]
	var descs := ["15% cheaper. More customers, and they are happy with value-grade ingredients.",
		"Fair prices. Customers expect standard-grade ingredients.",
		"20% dearer. Fewer customers, and they expect quality-grade ingredients or better: anything less reads as a rip-off."]
	var ph := Kit.hbox(6)
	for i in 3:
		var b := Kit.button(names[i], func(): _act(func(): Game.s.price = i), "primary" if G.s.price == i else "ghost", 18)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ph.add_child(b)
	pc[1].add_child(ph)
	pc[1].add_child(Kit.label(descs[G.s.price], 16, Kit.MUTED, true))
	pc[1].add_child(Kit.label("Menus run for %d days. Book the next one before this one ends. Whatever the new menu does not use is dead stock, so order carefully in the last few days." % Data.MENU_DAYS, 15, Kit.MUTED, true))
	g.add_child(pc[0])

	page.add_child(_extras_card())

	page.add_child(Kit.label("Next fortnight's menu" + ("  ·  booked: " + Data.MENU[G.s.next_menu].name if G.s.next_menu != "" else "  ·  nothing booked (House Classics)"), 21))
	var og := Kit.grid(3)
	page.add_child(og)
	var offers: Array = G.s.offers.duplicate()
	if G.s.menu_id != "classics": offers.push_front("classics")
	for id in offers:
		var o = Data.MENU[id]
		var cd = Kit.card(o.name)
		cd[1].add_child(Kit.label(o.desc, 15, Kit.MUTED, true))
		_menu_lines(cd[1], o, false)
		var needs: Array = G.menu_doughs(o).map(func(dd): return Data.DOUGHS[dd].name + " dough")
		var no_freezer: bool = G.menu_stores(o).has("freezer") and Stock.store_cap("freezer") <= 0
		if G.menu_stores(o).has("freezer"): needs.append("a freezer")
		cd[1].add_child(Kit.label("Needs: " + ", ".join(needs) + (". +%d%% customers" % int(o.buzz * 100) if o.buzz > 0 else ""), 15, Kit.TOMATO if no_freezer else Kit.MUTED, true))
		var booked: bool = G.s.next_menu == id or (id == "classics" and G.s.next_menu == "")
		if booked: cd[1].add_child(_tag("Booked", Kit.BASIL))
		elif G.s.level < o.lvl: cd[1].add_child(_tag("Needs level %d" % o.lvl))
		else:
			var b := Kit.button("Book for %s" % Kit.money(o.cost) if o.cost > 0 else "Book (free)", func(): _act(func():
				Game.s.cash -= o.cost
				Game.s.next_menu = "" if id == "classics" else id), "primary", 18)
			b.disabled = G.s.cash < o.cost
			cd[1].add_child(b)
		og.add_child(cd[0])

# ---------- Upgrades ----------
func _upg_card(id: String) -> Control:
	var G := Game
	var u = Data.UPG[id]
	var cur := G.tier(id)
	var nx = G.next_tier(id)
	var cd = Kit.card("%s  %d/%d" % [u.name, int(G.s.upg[id]) + 1, u.tiers.size()])
	cd[1].add_child(Kit.label(cur.n, 19))
	cd[1].add_child(Kit.label(cur.d, 15, Kit.MUTED, true))
	if nx == null:
		cd[1].add_child(_tag("Top of the range", Kit.BASIL))
	else:
		cd[1].add_child(Kit.label("Next: " + nx.n, 17, Kit.CHEESE, true))
		cd[1].add_child(Kit.label(nx.d, 15, Kit.MUTED, true))
		if id == "prep" and nx.has("rail"):
			var pid := "gn13" if float(nx.pan) >= 2.0 else "gn16"
			cd[1].add_child(Kit.label("Takes %d %ss (%s): you own %d." % [int(nx.rail), Equip.ITEM[pid].short, Equip.SHOP.name, Equip.count(pid)], 14, Kit.TOMATO if Equip.count(pid) < int(nx.rail) else Kit.BASIL, true))
		if G.s.venue < nx.v:
			cd[1].add_child(_tag("Needs the " + Data.VENUES[int(nx.v)].name))
		else:
			var b := Kit.button("Buy " + Kit.money(nx.c), func(): _act(func():
				if Game.buy_upgrade(id):
					Art.sfx("cash")
					Kit.main.toast("Installed: " + Game.tier(id).n)), "primary", 18)
			b.disabled = G.s.cash < nx.c
			cd[1].add_child(b)
	return cd[0]

## what you own of the small equipment in some KitBox categories, and what is missing
func _kit_card(cats: Array) -> Control:
	var kc = Kit.card("Utensils and small equipment")
	var miss: Array = Equip.missing().filter(func(m): return cats.has(Equip.ITEM[m.id].cat))
	kc[1].add_child(Kit.label("Every utensil is bought from %s, one at a time or by the pack. Everyone working at once needs their own: a ladle per person saucing, a peel per person at the oven, a knife per person prepping." % Equip.SHOP.name, 15, Kit.MUTED, true))
	var have := []
	for it in Equip.ITEMS:
		if cats.has(it.cat) and Equip.count(it.id) > 0: have.append(Equip.amount(it.id, Equip.count(it.id)))
	kc[1].add_child(Kit.label("You have: " + ", ".join(have), 14, Kit.INK, true))
	for m in miss: kc[1].add_child(Kit.label("Short: %s (have %d, need %d)" % [Equip.ITEM[m.id].name, m.have, m.need], 15, Kit.TOMATO, true))
	var b := Kit.button("Shop at %s" % Equip.SHOP.name, func():
		ShopPage.cat = "need" if miss.size() > 0 else cats[0]
		go("kit"), "primary" if miss.size() > 0 else "ghost", 17)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	kc[1].add_child(b)
	return kc[0]

func _page_boh() -> void:
	var G := Game
	page.add_child(_kit_card(["pizza", "prep", "storage", "cleaning"]))
	var g := Kit.grid(3)
	page.add_child(g)
	for k in Data.UPG:
		if Data.UPG[k].area == "boh": g.add_child(_upg_card(k))

func _page_foh() -> void:
	var G := Game
	var v := G.venue()
	page.add_child(_kit_card(["foh", "safety"]))
	var g := Kit.grid(3)
	page.add_child(g)
	var cd = Kit.card("Tables  %d/%d" % [min(G.s.tables, v.tables), v.tables])
	if v.tables > 0:
		cd[1].add_child(Kit.label("Guests are seated, order at the table, eat in and ask for the bill. They tip more and buy drinks. Servers do the running for you.", 15, Kit.MUTED, true))
		cd[1].add_child(Kit.label("Places you can lay: %d (plates %d, cutlery %d, glasses %d). Nobody is seated without a place." % [Equip.seats(), Equip.count("plate"), Equip.count("cutlery"), Equip.count("glass")], 15, Kit.TOMATO if Equip.seats() < min(G.s.tables, v.tables) * 3 else Kit.INK, true))
		if G.s.tables < v.tables:
			var b := Kit.button("Add a table " + Kit.money(G.table_cost()), func(): _act(func():
				Game.s.cash -= Game.table_cost()
				Game.s.tables += 1), "primary", 18)
			b.disabled = G.s.cash < G.table_cost()
			cd[1].add_child(b)
		else:
			cd[1].add_child(_tag("Room is full", Kit.BASIL))
	else:
		cd[1].add_child(Kit.label("No room for seating here. The Takeaway Shop has window seats.", 15, Kit.MUTED, true))
	g.add_child(cd[0])
	g.add_child(_app_card())
	for k in Data.UPG:
		if Data.UPG[k].area == "foh": g.add_child(_upg_card(k))

## the delivery app: join it, pause it, leave it
func _app_card() -> Control:
	var G := Game
	var A0: Dictionary = Data.APP
	var A: Dictionary = G.s.app
	var ac = Kit.card("%s delivery app" % A0.name)
	var gm: float = (Day.close_time() - Day.open_time()) / ServiceScreen.DAY
	ac[1].add_child(Kit.label("Orders ping on a tablet during service: accept them in time or they count as missed. A rider is booked to collect each one about %d minutes later and waits up to %d. %s keeps %d%% of every order. Late, missed and cancelled orders drop your rating in the app, and a lower rating means fewer orders." % [int(round(float(A0.prep_secs) * gm / 5.0) * 5), int(round(float(A0.rider_secs) * gm / 5.0) * 5), A0.name, int(float(A0.commission) * 100)], 14, Kit.MUTED, true))
	if not A.on:
		if int(G.s.venue) < int(A0.venue): ac[1].add_child(_tag("Needs a fixed address: the " + Data.VENUES[int(A0.venue)].name))
		elif G.s.level < int(A0.lvl): ac[1].add_child(_tag("Level %d" % int(A0.lvl)))
		else:
			var b := Kit.button("Join for %s" % Kit.money(A0.join_fee), func(): _act(func():
				Game.s.cash -= float(A0.join_fee)
				Game.s.app.on = true
				Game.s.app.paused = false
				Game.s.app.rating = float(A0.start_rating)), "primary", 17)
			b.disabled = G.s.cash < float(A0.join_fee)
			ac[1].add_child(b)
		return ac[0]
	ac[1].add_child(Kit.label("Rating %.1f / 5 · %d orders so far · about %d pizzas a day from the app" % [float(A.rating), int(A.get("orders", 0)), G.app_covers() if not A.paused else 0], 16, Kit.BASIL if float(A.rating) >= 4.3 else (Kit.CHEESE if float(A.rating) >= 3.6 else Kit.TOMATO), true))
	var h := Kit.hbox(6)
	h.add_child(Kit.button("Resume orders" if A.paused else "Pause orders", func(): _act(func(): Game.s.app.paused = not Game.s.app.paused), "primary" if A.paused else "ghost", 15))
	h.add_child(Kit.button("Leave the app", func(): _act(func(): Game.s.app.on = false), "ghost", 15))
	ac[1].add_child(h)
	return ac[0]

# ---------- Staff ----------
func _person(x: Dictionary, hired: bool) -> Control:
	var G := Game
	var r = Data.ROLES[x.role]
	var cd = Kit.card("%s · %s" % [x.name, r.name])
	cd[1].add_child(Kit.label("Skill %d/5  ·  %s a day" % [x.skill, Kit.money(x.wage)], 18, Kit.CHEESE))
	cd[1].add_child(Kit.label(r.desc, 15, Kit.MUTED, true))
	var h := Kit.hbox(6)
	if hired:
		if x.skill < 5:
			var b := Kit.button("Train " + Kit.money(G.train_cost(x)), func(): _act(func():
				Game.s.cash -= Game.train_cost(x)
				x.skill += 1
				x.wage = int(round(x.wage * 1.12))), "primary", 17)
			b.disabled = G.s.cash < G.train_cost(x)
			h.add_child(b)
		else:
			h.add_child(_tag("Master", Kit.BASIL))
		h.add_child(Kit.button("Let go", func(): Kit.main.confirm("Let %s go?" % x.name, "They leave today and stop drawing a wage.", "Let go", func(): _act(func(): Game.s.staff.erase(x))), "ghost", 17))
	else:
		var blk := G.hire_block(x)
		if blk != "": h.add_child(_tag(blk))
		else: h.add_child(Kit.button("Hire", func(): _act(func():
			Game.s.cands.erase(x)
			Game.s.staff.append(x)
			Kit.main.toast(x.name + " joins the team")), "primary", 17))
	cd[1].add_child(h)
	return cd[0]

func _page_staff() -> void:
	var G := Game
	var v := G.venue()
	if G.s.level < 2:
		var cd = Kit.card("Just you for now")
		cd[1].add_child(Kit.label("Reach level 2 and you can take on a pizzaiolo or a counter assistant, even in the van.", 18, Kit.MUTED, true))
		page.add_child(cd[0])
		return
	page.add_child(Kit.label("Kitchen %d/%d  ·  Front of house %d/%d  ·  Wages %s a day" % [G.area_count("boh"), v.boh, G.area_count("foh"), v.foh, Kit.money(G.wages())], 19))
	if G.s.staff.size() > 0:
		page.add_child(Kit.label("Your team", 21))
		var g := Kit.grid(3)
		page.add_child(g)
		for x in G.s.staff: g.add_child(_person(x, true))
	page.add_child(Kit.label("Applicants today", 21))
	var g2 := Kit.grid(3)
	page.add_child(g2)
	for x in G.s.cands: g2.add_child(_person(x, false))

# ---------- Property ----------
func _page_property() -> void:
	var G := Game
	var g := Kit.grid(2)
	page.add_child(g)
	for i in Data.VENUES.size():
		var v = Data.VENUES[i]
		var cd = Kit.card(v.name)
		cd[1].add_child(Kit.label(v.desc, 15, Kit.MUTED, true))
		var st := ["%d base footfall" % v.traffic, "%s a day" % Kit.money(v.rent) if not v.has("pitches") else "pitch fees", "%d kitchen staff" % v.boh, "%d front staff" % v.foh]
		if v.tables > 0: st.append("%d tables" % v.tables)
		_stats(cd[1], st)
		if i < G.s.venue:
			cd[1].add_child(_tag("Outgrown"))
			cd[0].modulate.a = 0.55
		elif i == G.s.venue: cd[1].add_child(_tag("You are here", Kit.BASIL))
		elif i > G.s.venue + 1 or G.s.level < v.lvl: cd[1].add_child(_tag("Needs level %d · %s" % [v.lvl, Kit.money(v.cost)]))
		else:
			var b := Kit.button("Buy & move in " + Kit.money(v.cost), func(): Kit.main.confirm("Move to the %s?" % v.name, "%s. Your equipment, staff and reputation move with you. Bigger premises take bigger ovens, fridges, freezers and dry stores." % Kit.money(v.cost), "Sign the lease", func():
				Game.s.cash -= v.cost
				Hygiene.move_out()
				Game.s.venue = i
				Game.gen_cands()
				Game.save_game()
				Kit.main.show_hub("home")), "primary", 18)
			b.disabled = G.s.cash < v.cost
			cd[1].add_child(b)
		g.add_child(cd[0])

# ---------- day flow ----------
func _closed_day() -> void:
	Kit.main.confirm("Closed by the inspector", "You cannot trade today. Clean the kitchen and front of house, lay traps and sort the stores out. Rent, wages and bills are still due.", "Close up for the day", func():
		Game.s.phase = "evening"
		Game.save_game()
		Kit.main.show_hub("jobs"))

func _open() -> void:
	var G := Game
	if Tutor.running() and not Tutor.training_service():
		Kit.main.toast("Not yet: %s has more to show you" % Story.BOSS)
		return
	if Day.now() > Day.close_time() - 90.0:
		Kit.main.message("Too late to open", "It is %s. There is no point opening now." % Data.hhmm(Day.now()), "OK")
		return
	var ok := false
	var any_dough := false
	for r in G.active_recipes():
		if Stock.dough_ready(r.base) > 0: any_dough = true
		var can := Stock.dough_ready(r.base) > 0
		for i in r.spec:
			if Stock.potential(i) < r.spec[i] * 0.7: can = false
		if can: ok = true
	if not ok:
		if any_dough:
			Kit.main.toast("You are missing ingredients for every pizza on the menu", true)
			go("stores")
		else:
			Kit.main.confirm("No dough is ready", "Dough has to be made the day before. You can stay shut today (rent, wages and bills are still due) and make dough for tomorrow.", "Stay shut today", func():
				Game.s.phase = "evening"
				Game.save_game()
				Kit.main.show_hub("dough"))
		return
	var warn := []
	if G.tier("oven").type == "wood" and Stock.have("wood") < 1:
		warn.append("There is no firewood: the oven will barely get warm.")
	var unprepped := []
	for row in Day.prep_list():
		if row.have < row.need * 0.25 and row.raw > 0: unprepped.append(Data.ING[row.id].name.to_lower())
	if unprepped.size() > 0: warn.append("Not prepped: %s. You will have to prep mid-shift or 86 the pizzas that use them." % ", ".join(unprepped))
	if G.s.dock.size() > 0: warn.append("There is a delivery still waiting at the back door.")
	if warn.size() > 0:
		Kit.main.confirm("Open now?", "\n".join(warn), "Open anyway", _go_open)
		return
	_go_open()

func _go_open() -> void:
	Checks.note("open")
	var notes := Day.wait_until(Day.open_time())
	if Hygiene.level("boh") > 0: pass
	var at: float = Game.s.hygiene.get("at", -1.0)
	if at >= 0 and at <= Day.now():      # the inspector called in during the morning
		var res := Hygiene.inspect()
		Game.save_game()
		if res.closed:
			Game.s.hygiene.closed_day = Game.s.day
			Kit.main.message("Closed by the inspector", "The food hygiene inspector rated you %s.\n\n%s\n\nYou cannot open today." % [Hygiene.rating_text(), "\n".join(res.notes)], "OK", func(): render())
			return
		Kit.main.message("Food hygiene inspection", "The inspector called in this morning and rated you %s.%s" % [Hygiene.rating_text(), ("\n\n" + "\n".join(res.notes)) if res.notes.size() > 0 else ""], "Open up", func():
			Game.save_game()
			Kit.main.start_service())
		return
	Game.save_game()
	Kit.main.start_service()

func _sleep() -> void:
	var G := Game
	if Tutor.running():
		Kit.main.toast("Not yet: %s has more to show you" % Story.BOSS)
		return
	var plan := G.dough_plan()
	var short := 0
	for k in plan: short += plan[k]
	if short > 0 and G.staff_of("prep").is_empty() and Story.role() != "pizzaiolo":
		Kit.main.confirm("Go to bed without enough dough?", "Tomorrow needs about %d more dough balls. Dough must be made the day before." % short, "Sleep anyway", _do_sleep)
	else:
		_do_sleep()

func _do_sleep() -> void:
	var G := Game
	var lines := []
	Checks.note("close")
	var rev := {}
	if Story.employed() and int(G.s.last.get("day", 0)) == G.s.day:
		rev = Story.review(G.s.last)
		G.s.story.reviews.append({"day": G.s.day, "score": rev.score, "lines": rev.lines})
		while G.s.story.reviews.size() > 10: G.s.story.reviews.pop_front()
	lines.append_array(Story.evening())
	var made := G.auto_dough()
	if made > 0: lines.append("Your prep cook made %d dough balls for tomorrow." % made)
	if G.calc().manager:
		var placed := Market.auto_order()
		if placed.size() > 0: lines.append("Your manager placed orders with %s." % ", ".join(placed))
	if int(G.s.last.get("day", 0)) != G.s.day:        # stayed shut: the overheads are still due
		var due: float = G.rent() + G.wages() + G.utilities()
		G.s.cash -= due
		lines.append("You stayed shut. Rent, wages and bills came to %s." % Kit.money(due))
	var n := G.nightfall()
	G.save_game()
	lines.append_array(n.notes)
	for pd in n.paid: lines.append("Paid %s's invoice: %s." % [pd.sup, Kit.cents(pd.amount)])
	if n.binned.size() > 0:
		var cost := 0.0
		for b in n.binned: cost += b.cost
		lines.append("Out of date and binned (%s): %s." % [Kit.cents(cost), ", ".join(n.binned.map(func(b): return "%s %s" % [Data.qty(b.id, b.q), Data.ING[b.id].name.to_lower()]))])
	if n.dough_lost > 0: lines.append("%d dough balls overproofed and were binned." % n.dough_lost)
	if n.rotated: lines.append("New menu today: %s. Check your stock and dough styles." % G.menu_now().name)
	if n.pitch_reset: lines.append("Your pitch does not trade today, so you are back on the High Street.")
	lines.append_array(n.morning)
	if lines.is_empty(): lines.append("A quiet night. Nothing spoiled.")
	G.s.notes = n.morning
	G.save_game()
	Kit.main.show_hub("home")
	if not rev.is_empty():
		var txt := "%s gave your shift %d / 100.\n\n\"%s\"\n\nYou were paid %s. Savings: %s." % [Story.BOSS, rev.score, " ".join(rev.lines), Kit.money(rev.pay), Kit.money(G.s.story.savings)]
		Kit.main.message("Your shift", txt, "Next", func():
			Kit.main.message(G.date_text(), "\n".join(lines), "Good morning", func(): _maybe_promote(rev)))
	else:
		Kit.main.message(G.date_text(), "\n".join(lines), "Good morning")

func _maybe_promote(rev: Dictionary) -> void:
	if rev.get("promoted", "") == "": return
	var title := "Promoted!" if rev.promoted == "senior" else "Going solo"
	var text := Story.promote()
	Kit.main.show_hub("home")
	Kit.main.message(title, text, "Let's go")

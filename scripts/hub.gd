class_name Hub
extends VBoxContainer
## The management screens between services: Today, Market, Dough, Menu, Kitchen, Front, Staff, Property.

const TABS := [["home", "Today"], ["market", "Market"], ["dough", "Dough"], ["menu", "Menu"], ["boh", "Kitchen"], ["foh", "Front"], ["staff", "Staff"], ["property", "Property"]]
var tab := "home"
var show_all := false
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
	rail = Kit.vbox(4)
	rail.custom_minimum_size.x = 150
	body.add_child(rail)
	scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	page = Kit.vbox(10)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(page)
	render()

func go(t: String) -> void:
	tab = t
	scroll.scroll_vertical = 0
	render()

func render() -> void:
	var G := Game
	var keep := scroll.scroll_vertical
	Kit.clear(top); Kit.clear(rail); Kit.clear(page)
	var v := G.venue()
	var name_l := Kit.label(v.name, 28)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.clip_text = true
	top.add_child(name_l)
	top.add_child(Kit.chip("Day %d · %s" % [G.s.day, "Evening" if G.s.phase == "evening" else "Morning"]))
	top.add_child(Kit.chip("Rating %.1f / 5" % G.s.rep))
	top.add_child(Kit.chip("Level %d  (%d / %d XP)" % [G.s.level, G.s.xp, G.xp_need(G.s.level)]))
	top.add_child(Kit.label(Kit.money(G.s.cash), 30, Kit.TOMATO if G.s.cash < 0 else Kit.CHEESE))
	if G.s.phase == "evening":
		top.add_child(Kit.button("Lock up & sleep", _sleep, "primary", 24))
	else:
		top.add_child(Kit.button("Open for service", _open, "danger", 24))
	for t in TABS:
		var b := Kit.button(t[1], go.bind(t[0]), "tab_on" if tab == t[0] else "tab", 21)
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
	for t in items: f.add_child(Kit.chip(t, Kit.BG, Kit.INK, 17))
	parent.add_child(f)

func _tag(text: String, col: Color = Kit.MUTED) -> Control:
	return Kit.chip(text, Kit.PANEL2, col, 16)

func _act(fn: Callable) -> void:
	fn.call()
	Game.save_game()
	render()

# ---------- Today ----------
func _page_home() -> void:
	var G := Game
	var c := G.calc()
	var v := G.venue()
	var g := Kit.grid(2)
	page.add_child(g)
	var hero = Kit.card(v.name)
	hero[1].add_child(Kit.label(v.desc, 18, Kit.MUTED, true))
	var st := ["About %d customers today" % c.total, G.tier("oven").n, "%d staff · %s/day" % [G.s.staff.size(), Kit.money(G.wages())], "%s %s/day" % [v.rentName, Kit.money(v.rent)]]
	if c.tables > 0: st.append("%d tables" % c.tables)
	_stats(hero[1], st)
	g.add_child(hero[0])

	var todo = Kit.card("Tonight's jobs" if G.s.phase == "evening" else "Before you open")
	var recs := G.active_recipes()
	var lines := []
	if G.s.phase == "morning":
		var styles := []
		for r in recs:
			if not styles.has(r.base): styles.append(r.base)
		for sty in styles:
			var n := G.dough_ready(sty)
			var dn: String = Data.DOUGHS[sty].name
			if n < 1: lines.append(["bad", "No %s dough is ready today." % dn])
			elif n < c.total * 0.7 / styles.size(): lines.append(["warn", "%d %s dough balls ready for about %d customers." % [n, dn, c.total]])
			else: lines.append(["ok", "%d %s dough balls ready." % [n, dn]])
		var missing := []
		for r in recs:
			for i in G.recipe_ings(r):
				if G.stock(i) < 1 and not missing.has(Data.ING[i].name): missing.append(Data.ING[i].name)
		if missing.size() > 0: lines.append(["bad", "Out of " + ", ".join(missing) + ". Visit the Market."])
		else: lines.append(["ok", "Every pizza on the menu has toppings in stock."])
	var plan := G.dough_plan()
	for sty in plan:
		if plan[sty] > 0:
			lines.append(["warn" if G.s.phase == "evening" else "info", "Tomorrow needs about %d more %s dough balls. Dough made today is ready tomorrow." % [plan[sty], Data.DOUGHS[sty].name]])
	if G.cycle_left() <= 3:
		lines.append(["warn", "The menu changes in %d day%s. %s" % [G.cycle_left(), "" if G.cycle_left() == 1 else "s", "Run your stock down." if G.s.next_menu != "" else "Pick the next one on the Menu page or you fall back to House Classics."]])
	if G.s.cash < 0: lines.append(["bad", "Overdrawn: the bank charges 5% a day."])
	if int(G.s.upg.drinks) >= 3 and G.staff_of("bartender").is_empty(): lines.append(["warn", "The bar needs a bartender."])
	if int(G.s.upg.delivery) > 0 and G.staff_of("driver").is_empty(): lines.append(["warn", "Delivery needs a driver."])
	for l in lines:
		var col: Color = {"ok": Kit.BASIL, "warn": Kit.CHEESE, "bad": Kit.TOMATO, "info": Kit.MUTED}[l[0]]
		todo[1].add_child(Kit.label(l[1], 19, col, true))
	if G.s.day == 1 and G.s.phase == "morning":
		todo[1].add_child(Kit.label("First day: the last owner left a tray of dough. Open up, take orders at the hatch, then make each pizza on the bench. Tonight, make dough for tomorrow.", 17, Kit.MUTED, true))
	g.add_child(todo[0])

	var l: Dictionary = G.s.last
	if not l.is_empty():
		var lc = Kit.card("Day %d takings" % l.day)
		_stats(lc[1], ["%d pizzas served" % l.served, "%d customers lost" % l.lost, "Average quality %d" % l.avg_q, "Profit %s" % Kit.money(l.profit)])
		g.add_child(lc[0])
	var nc = Kit.card("Next step up")
	if G.s.venue + 1 < Data.VENUES.size():
		var nv = Data.VENUES[G.s.venue + 1]
		nc[1].add_child(Kit.label("%s  ·  %s  ·  needs level %d" % [nv.name, Kit.money(nv.cost), nv.lvl], 19))
		nc[1].add_child(Kit.bar(G.s.cash / nv.cost))
	else:
		nc[1].add_child(Kit.label("You run the best pizzeria in town. Keep the ovens hot.", 19, Kit.MUTED, true))
	nc[1].add_child(Kit.label("%d pizzas sold · %s earned all-time" % [G.s.pizzas, Kit.money(G.s.earned)], 17, Kit.MUTED))
	var reset := Kit.button("Start over", func(): Kit.main.confirm("Start over?", "This wipes your save and puts you back in the van on day 1.", "Wipe my save", func():
		Game.new_game()
		Kit.main.show_hub()), "ghost", 16)
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	nc[1].add_child(reset)
	g.add_child(nc[0])

# ---------- Market ----------
func _store_bar(parent: Node, store: String) -> void:
	var G := Game
	var v := Kit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cap := G.store_cap(store)
	var used := G.store_used(store)
	v.add_child(Kit.label("%s  %d / %d" % [Data.STORE_NAME[store], int(ceil(used)), int(cap)] if cap > 0 else "No freezer", 18, Kit.TOMATO if cap > 0 and used / cap > 0.9 else Kit.INK))
	v.add_child(Kit.bar(used / cap if cap > 0 else 0.0, Kit.TOMATO if cap > 0 and used / cap > 0.9 else Kit.BASIL))
	parent.add_child(v)

func _page_market() -> void:
	var G := Game
	var strip := Kit.panel(Kit.PANEL2)
	var sv := Kit.vbox(8)
	strip.add_child(sv)
	var bars := Kit.hbox(16)
	for st in ["fridge", "freezer", "dry"]: _store_bar(bars, st)
	sv.add_child(bars)
	var row := Kit.hbox(10)
	var info := Kit.label("One portion tops one pizza. Everything has a shelf life and is binned when it runs out. You cannot buy more than your stores hold.", 17, Kit.MUTED, true)
	row.add_child(info)
	var qc := G.quick_order_cost()
	var qb := Kit.button("Order today's par · %s" % Kit.cents(qc) if qc > 0 else "Par stock is covered", func(): _act(func():
		var r := Game.quick_order()
		Kit.main.toast("Could not finish: " + r.short if r.short != "" else "Ordered " + Kit.cents(r.spent), r.short != "")), "primary", 19)
	qb.disabled = qc <= 0
	row.add_child(qb)
	row.add_child(Kit.button("Show my menu only" if show_all else "Show everything", func():
		show_all = not show_all
		render(), "ghost", 19))
	sv.add_child(row)
	page.add_child(strip)

	var now := {}
	var nxt := {}
	for r in G.active_recipes():
		for i in G.recipe_ings(r): now[i] = true
	if G.s.next_menu != "":
		for id in Data.MENU[G.s.next_menu].items:
			for i in G.recipe_ings(Data.REC[id]): nxt[i] = true
	var dough := {}
	for k in Data.DOUGHS:
		if G.s.level >= Data.DOUGHS[k].lvl:
			dough[Data.DOUGHS[k].flour] = true
			for p in ["salt", "yeast", "oil", "sugar"]:
				if Data.DOUGHS[k][p] > 0: dough[p] = true
	var g := Kit.grid(3)
	page.add_child(g)
	for id in Data.ING:
		var i = Data.ING[id]
		var have := G.stock(id)
		if not show_all and not (now.has(id) or nxt.has(id) or dough.has(id) or have > 0): continue
		var cd = Kit.card()
		var h := Kit.hbox(8)
		h.add_child(Kit.swatch(id))
		var nm := Kit.label(i.name, 21)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.clip_text = true
		h.add_child(nm)
		h.add_child(_tag("On menu" if now.has(id) else ("Next menu" if nxt.has(id) else ("Dough" if dough.has(id) else "Not needed")), Kit.BASIL if now.has(id) or dough.has(id) else Kit.MUTED))
		cd[1].add_child(h)
		var p := G.ing_price(id)
		cd[1].add_child(Kit.label("%s per %s · %s · keeps %s" % [Kit.cents(p), i.get("packName", "portion"), Data.STORE_NAME[i.store], ("%d days" % i.life) if i.life < 900 else "forever"], 16, Kit.MUTED, true))
		var ex := G.expiring(id)
		var hl := Kit.label("Have %s" % Kit.qty(id, have) + ("  ·  %s goes off tonight" % Kit.qty(id, ex) if ex > 0 else ""), 18, Kit.TOMATO if ex > 0 or (now.has(id) and have < 1) else Kit.INK, true)
		cd[1].add_child(hl)
		var bh := Kit.hbox(6)
		for n in [1, 5, 20]:
			var b := Kit.button("+%d" % n, func(): _act(func():
				var err := Game.buy(id, n)
				if err != "": Kit.main.toast(err, true)), "primary", 19)
			b.disabled = G.s.cash < p * n
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bh.add_child(b)
		cd[1].add_child(bh)
		g.add_child(cd[0])

# ---------- Dough ----------
func _page_dough() -> void:
	var G := Game
	var c := G.calc()
	var trays = Kit.card("Dough in the fridge")
	if G.s.dough.is_empty():
		trays[1].add_child(Kit.label("No dough. Anything you make now is ready tomorrow.", 19, Kit.TOMATO, true))
	for l in G.s.dough:
		var stt := G.dough_status(l)
		var h := Kit.hbox(10)
		var a := Kit.label("%d × %s" % [l.n, Data.DOUGHS[l.style].name], 20)
		a.custom_minimum_size.x = 250
		h.add_child(a)
		h.add_child(Kit.label("Quality %d" % l.q, 18, Kit.MUTED))
		var sl := Kit.label(stt[1], 19, {"proof": Kit.MUTED, "ok": Kit.BASIL, "peak": Kit.BASIL, "last": Kit.CHEESE}[stt[0]])
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(sl)
		trays[1].add_child(h)
	trays[1].add_child(Kit.label("Dough made today cold-proofs overnight and is ready tomorrow. It keeps %d days, then it has overproofed and goes in the bin. Each ball takes half a fridge space." % (3 + int(G.tier("proofer").days)), 17, Kit.MUTED, true))
	var plan := G.dough_plan()
	for sty in plan:
		if plan[sty] > 0: trays[1].add_child(Kit.label("Tomorrow: about %d more %s balls needed." % [plan[sty], Data.DOUGHS[sty].name], 18, Kit.CHEESE))
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
		cd[1].add_child(Kit.label(d.desc, 17, Kit.MUTED, true))
		var rec := "Per 1 kg %s: %d g water, %s g salt, %s g yeast" % [Data.ING[d.flour].name, d.water * 10, _num(d.salt * 10), _num(d.yeast * 10)]
		if d.oil > 0: rec += ", %d ml oil" % (d.oil * 10)
		if d.sugar > 0: rec += ", %d g sugar" % (d.sugar * 10)
		cd[1].add_child(Kit.label(rec, 18, Kit.INK, true))
		var balls := int(1000.0 / G.flour_per_ball(k))
		cd[1].add_child(Kit.label("%d g balls · about %d per kg of flour · %s" % [d.ball, balls, {"hand": "stretched by hand", "roll": "rolled with a pin", "press": "pressed into a pan"}[d.shape]], 17, Kit.MUTED, true))
		var can := G.stock(d.flour) >= 500
		var b := Kit.button("Make %s dough" % d.name if can else "Buy %s first" % Data.ING[d.flour].name, func(): Kit.main.modal(DoughGame.new(k), 1000), "primary", 20)
		b.disabled = not can
		cd[1].add_child(b)
		g.add_child(cd[0])
	page.add_child(Kit.label("Mixer: %s (up to %d kg of flour per batch)." % [G.tier("mixer").n, c.batch] + ("  Your prep cook makes tomorrow's dough at close." if G.staff_of("prep").size() > 0 else ""), 17, Kit.MUTED, true))

func _num(x: float) -> String:
	return str(int(x)) if abs(x - round(x)) < 0.01 else "%.1f" % x

# ---------- Menu ----------
func _menu_lines(parent: Node, m: Dictionary, toggles: bool) -> void:
	var G := Game
	for id in m.items:
		var r = Data.REC[id]
		var h := Kit.hbox(8)
		var v := Kit.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(Kit.label("%s  ·  %s" % [r.name, Kit.cents(r.price * G.calc().price_mult)], 20))
		var ing := G.recipe_ings(r).map(func(i): return Data.ING[i].name)
		v.add_child(Kit.label("%s base · %s" % [Data.DOUGHS[r.base].name, ", ".join(ing)], 16, Kit.MUTED, true))
		h.add_child(v)
		if toggles:
			var off: bool = G.s.off.get(id, false)
			h.add_child(Kit.button("Off today" if off else "On", func(): _act(func():
				if not off and Game.active_recipes().size() < 2:
					Kit.main.toast("Keep at least one pizza on", true)
				else:
					Game.s.off[id] = not off), "ghost" if off else "primary", 17))
		parent.add_child(h)

func _page_menu() -> void:
	var G := Game
	var m := G.menu_now()
	var g := Kit.grid(2)
	page.add_child(g)
	var cur = Kit.card("Now serving: " + m.name)
	cur[1].add_child(Kit.label("%d day%s left on this menu." % [G.cycle_left(), "" if G.cycle_left() == 1 else "s"], 18, Kit.CHEESE if G.cycle_left() <= 3 else Kit.MUTED))
	_menu_lines(cur[1], m, true)
	g.add_child(cur[0])

	var pc = Kit.card("Pricing")
	var names := ["Budget", "Standard", "Premium"]
	var descs := ["15% cheaper. More customers, and they forgive more.", "Fair prices.", "20% dearer. Fewer customers, and they expect better."]
	var ph := Kit.hbox(6)
	for i in 3:
		var b := Kit.button(names[i], func(): _act(func(): Game.s.price = i), "primary" if G.s.price == i else "ghost", 19)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ph.add_child(b)
	pc[1].add_child(ph)
	pc[1].add_child(Kit.label(descs[G.s.price], 17, Kit.MUTED, true))
	pc[1].add_child(Kit.label("Menus run for %d days. Book the next one before this one ends. Whatever the new menu does not use is dead stock, so order carefully in the last few days." % Data.MENU_DAYS, 17, Kit.MUTED, true))
	g.add_child(pc[0])

	page.add_child(Kit.label("Next fortnight's menu" + ("  ·  booked: " + Data.MENU[G.s.next_menu].name if G.s.next_menu != "" else "  ·  nothing booked (House Classics)"), 22))
	var og := Kit.grid(3)
	page.add_child(og)
	var offers: Array = G.s.offers.duplicate()
	if G.s.menu_id != "classics": offers.push_front("classics")
	for id in offers:
		var o = Data.MENU[id]
		var cd = Kit.card(o.name)
		cd[1].add_child(Kit.label(o.desc, 16, Kit.MUTED, true))
		_menu_lines(cd[1], o, false)
		var needs := G.menu_doughs(o).map(func(d): return Data.DOUGHS[d].name + " dough")
		for st in G.menu_stores(o):
			if st == "freezer": needs.append("a freezer")
		cd[1].add_child(Kit.label("Needs: " + ", ".join(needs) + (". +%d%% customers" % int(o.buzz * 100) if o.buzz > 0 else ""), 16, Kit.TOMATO if G.menu_stores(o).has("freezer") and G.store_cap("freezer") <= 0 else Kit.MUTED, true))
		var booked: bool = G.s.next_menu == id or (id == "classics" and G.s.next_menu == "")
		if booked: cd[1].add_child(_tag("Booked", Kit.BASIL))
		elif G.s.level < o.lvl: cd[1].add_child(_tag("Needs level %d" % o.lvl))
		else:
			var b := Kit.button("Book for %s" % Kit.money(o.cost) if o.cost > 0 else "Book (free)", func(): _act(func():
				Game.s.cash -= o.cost
				Game.s.next_menu = "" if id == "classics" else id), "primary", 19)
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
	cd[1].add_child(Kit.label(cur.n, 20))
	cd[1].add_child(Kit.label(cur.d, 16, Kit.MUTED, true))
	if nx == null:
		cd[1].add_child(_tag("Top of the range", Kit.BASIL))
	else:
		cd[1].add_child(Kit.label("Next: " + nx.n, 18, Kit.CHEESE, true))
		cd[1].add_child(Kit.label(nx.d, 16, Kit.MUTED, true))
		if G.s.venue < nx.v:
			cd[1].add_child(_tag("Needs the " + Data.VENUES[int(nx.v)].name))
		else:
			var b := Kit.button("Buy " + Kit.money(nx.c), func(): _act(func():
				if Game.buy_upgrade(id):
					Art.sfx("cash")
					Kit.main.toast("Installed: " + Game.tier(id).n)), "primary", 19)
			b.disabled = G.s.cash < nx.c
			cd[1].add_child(b)
	return cd[0]

func _page_boh() -> void:
	var g := Kit.grid(3)
	page.add_child(g)
	for k in Data.UPG:
		if Data.UPG[k].area == "boh": g.add_child(_upg_card(k))

func _page_foh() -> void:
	var G := Game
	var v := G.venue()
	var g := Kit.grid(3)
	page.add_child(g)
	var cd = Kit.card("Tables  %d/%d" % [min(G.s.tables, v.tables), v.tables])
	if v.tables > 0:
		cd[1].add_child(Kit.label("Guests are seated, order at the table, eat in and ask for the bill. They tip more and buy drinks. Servers do the running for you.", 16, Kit.MUTED, true))
		if G.s.tables < v.tables:
			var b := Kit.button("Add a table " + Kit.money(G.table_cost()), func(): _act(func():
				Game.s.cash -= Game.table_cost()
				Game.s.tables += 1), "primary", 19)
			b.disabled = G.s.cash < G.table_cost()
			cd[1].add_child(b)
		else:
			cd[1].add_child(_tag("Room is full", Kit.BASIL))
	else:
		cd[1].add_child(Kit.label("No room for seating here. The Takeaway Shop has window seats.", 16, Kit.MUTED, true))
	g.add_child(cd[0])
	for k in Data.UPG:
		if Data.UPG[k].area == "foh": g.add_child(_upg_card(k))

# ---------- Staff ----------
func _person(x: Dictionary, hired: bool) -> Control:
	var G := Game
	var r = Data.ROLES[x.role]
	var cd = Kit.card("%s · %s" % [x.name, r.name])
	cd[1].add_child(Kit.label("Skill %d/5  ·  %s a day" % [x.skill, Kit.money(x.wage)], 19, Kit.CHEESE))
	cd[1].add_child(Kit.label(r.desc, 16, Kit.MUTED, true))
	var h := Kit.hbox(6)
	if hired:
		if x.skill < 5:
			var b := Kit.button("Train " + Kit.money(G.train_cost(x)), func(): _act(func():
				Game.s.cash -= Game.train_cost(x)
				x.skill += 1
				x.wage = int(round(x.wage * 1.12))), "primary", 18)
			b.disabled = G.s.cash < G.train_cost(x)
			h.add_child(b)
		else:
			h.add_child(_tag("Master", Kit.BASIL))
		h.add_child(Kit.button("Let go", func(): Kit.main.confirm("Let %s go?" % x.name, "They leave today and stop drawing a wage.", "Let go", func(): _act(func(): Game.s.staff.erase(x))), "ghost", 18))
	else:
		var blk := G.hire_block(x)
		if blk != "": h.add_child(_tag(blk))
		else: h.add_child(Kit.button("Hire", func(): _act(func():
			Game.s.cands.erase(x)
			Game.s.staff.append(x)
			Kit.main.toast(x.name + " joins the team")), "primary", 18))
	cd[1].add_child(h)
	return cd[0]

func _page_staff() -> void:
	var G := Game
	var v := G.venue()
	if G.s.level < 2:
		var cd = Kit.card("Just you for now")
		cd[1].add_child(Kit.label("Reach level 2 and you can take on a pizzaiolo or a counter assistant, even in the van.", 19, Kit.MUTED, true))
		page.add_child(cd[0])
		return
	page.add_child(Kit.label("Kitchen %d/%d  ·  Front of house %d/%d  ·  Wages %s a day" % [G.area_count("boh"), v.boh, G.area_count("foh"), v.foh, Kit.money(G.wages())], 20))
	if G.s.staff.size() > 0:
		page.add_child(Kit.label("Your team", 22))
		var g := Kit.grid(3)
		page.add_child(g)
		for x in G.s.staff: g.add_child(_person(x, true))
	page.add_child(Kit.label("Applicants today", 22))
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
		cd[1].add_child(Kit.label(v.desc, 16, Kit.MUTED, true))
		var st := ["%d base footfall" % v.traffic, "%s/day" % Kit.money(v.rent), "%d kitchen staff" % v.boh, "%d front staff" % v.foh]
		if v.tables > 0: st.append("%d tables" % v.tables)
		_stats(cd[1], st)
		if i < G.s.venue:
			cd[1].add_child(_tag("Outgrown"))
			cd[0].modulate.a = 0.55
		elif i == G.s.venue: cd[1].add_child(_tag("You are here", Kit.BASIL))
		elif i > G.s.venue + 1 or G.s.level < v.lvl: cd[1].add_child(_tag("Needs level %d · %s" % [v.lvl, Kit.money(v.cost)]))
		else:
			var b := Kit.button("Buy & move in " + Kit.money(v.cost), func(): Kit.main.confirm("Move to the %s?" % v.name, "%s. Your equipment, staff and reputation move with you. Bigger premises allow bigger ovens, fridges, freezers and dry stores." % Kit.money(v.cost), "Sign the lease", func():
				Game.s.cash -= v.cost
				Game.s.venue = i
				Game.gen_cands()
				Game.save_game()
				Kit.main.show_hub("home")), "primary", 19)
			b.disabled = G.s.cash < v.cost
			cd[1].add_child(b)
		g.add_child(cd[0])

# ---------- day flow ----------
func _open() -> void:
	var G := Game
	if G.calc().manager:
		var r := G.quick_order()
		if r.spent > 0: Kit.main.toast("Your manager ordered %s of stock" % Kit.cents(r.spent))
	var ok := false
	for r in G.active_recipes():
		if G.can_make(r): ok = true
	if not ok:
		var any_dough := false
		for r in G.active_recipes():
			if G.dough_ready(r.base) > 0: any_dough = true
		if any_dough:
			Kit.main.toast("You are missing toppings for every pizza", true)
			go("market")
		else:
			Kit.main.confirm("No dough is ready", "Dough has to be made the day before. You can stay shut today (you still pay rent and wages) and make dough for tomorrow.", "Stay shut today", func():
				Game.s.phase = "evening"
				Game.save_game()
				Kit.main.show_hub("dough"))
		return
	G.save_game()
	Kit.main.start_service()

func _sleep() -> void:
	var G := Game
	var plan := G.dough_plan()
	var short := 0
	for k in plan: short += plan[k]
	if short > 0 and G.staff_of("prep").is_empty():
		Kit.main.confirm("Go to bed without enough dough?", "Tomorrow needs about %d more dough balls. Dough must be made the day before." % short, "Sleep anyway", _do_sleep)
	else:
		_do_sleep()

func _do_sleep() -> void:
	var G := Game
	var made := G.auto_dough()
	var rent: float = 0.0
	if int(G.s.last.get("day", 0)) != G.s.day:
		rent = G.venue().rent + G.wages()   # stayed shut: overheads still due
		G.s.cash -= rent
	var n := G.nightfall()
	G.s.phase = "morning"
	G.gen_cands()
	G.save_game()
	var lines := []
	if made > 0: lines.append("Your prep cook made %d dough balls for tomorrow." % made)
	if rent > 0: lines.append("You stayed shut. Rent and wages cost %s." % Kit.money(rent))
	if n.expired > 0: lines.append("%d portions went out of date and were binned." % n.expired)
	if n.dough_lost > 0: lines.append("%d dough balls overproofed and were binned." % n.dough_lost)
	if n.rotated: lines.append("New menu today: %s. Check your stock and dough styles." % G.menu_now().name)
	if lines.is_empty(): lines.append("Nothing spoiled overnight.")
	Kit.main.show_hub("home")
	Kit.main.message("Day %d" % G.s.day, "\n".join(lines), "Good morning")

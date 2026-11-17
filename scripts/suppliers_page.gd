class_name SuppliersPage
extends HBoxContainer
## The ordering screen: pick a business on the left, fill a basket from its catalogue, place the order.
## Catalogue, prices and rules come from Market; this only shows them.

static var sel := "cashcarry"     # remembered between visits
static var whole := false         # false = only what my menus use
static var cat := ""              # category filter, "" = all

var hub: Hub
var rows: VBoxContainer
var qty_lbls := {}
var foot_lbl: Label
var warn_lbl: Label
var place_btn: Button

func _init(h: Hub) -> void:
	hub = h
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)

func _ready() -> void:
	var open := Market.open_suppliers()
	if not open.any(func(sp): return sp.id == sel): sel = open[0].id
	# who you can buy from
	var lsc := ScrollContainer.new()
	lsc.custom_minimum_size.x = 268
	lsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var lv := Kit.vbox(5)
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lsc.add_child(lv)
	add_child(lsc)
	for sp in open:
		var n: int = Market.summary(sp.id).n
		var when: String = "collect now" if sp.lead == 0 else "next delivery " + Data.DAY_SHORT[Game.weekday(Market.next_delivery(sp))]
		var b := Kit.button("%s\n%s · %s%s" % [sp.name, sp.kind, when, ("\n%d in basket" % n) if n > 0 else ""], func():
			sel = sp.id
			hub.render(), "tab_on" if sp.id == sel else "ghost", 15)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		lv.add_child(b)
	var locked := Data.SUPPLIERS.filter(func(sp): return sp.lvl > Game.s.level)
	if locked.size() > 0:
		lv.add_child(Kit.label("Opens at level %d: %s" % [locked[0].lvl, locked[0].name], 14, Kit.MUTED, true))

	var sup: Dictionary = Data.SUP[sel]
	var right := Kit.vbox(6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(right)
	var hp := Kit.panel(Kit.PANEL2, 10)
	var hv := Kit.vbox(2)
	hp.add_child(hv)
	hv.add_child(Kit.label(sup.name, 22))
	hv.add_child(Kit.label(sup.desc, 15, Kit.MUTED, true))
	hv.add_child(Kit.label(_terms(sup), 15, Kit.CHEESE, true))
	right.add_child(hp)

	var fr := Kit.hbox(6)
	fr.add_child(Kit.button("Whole catalogue" if whole else "What my menus use", func():
		whole = not whole
		hub.render(), "ghost", 16))
	var ob := OptionButton.new()
	ob.add_theme_font_size_override("font_size", 16)
	ob.add_item("All categories")
	var cats := []
	for cc in Data.CATS:
		cats.append(cc[0])
		ob.add_item(cc[1])
	ob.selected = cats.find(cat) + 1
	ob.item_selected.connect(func(i):
		cat = "" if i == 0 else cats[i - 1]
		hub.render())
	fr.add_child(ob)
	var std := Kit.label("Grades: %s to %s.  Quality costs more, tastes better and earns bigger tips." % [Data.GRADES[int(sup.grades[0])], Data.GRADES[int(min(sup.grades[1], _top_grade()))]], 14, Kit.MUTED, true)
	fr.add_child(std)
	right.add_child(fr)

	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rows = Kit.vbox(4)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(rows)
	right.add_child(sc)
	_build_rows(sup)

	var fp := Kit.panel(Kit.PANEL2, 8)
	var fv := Kit.vbox(3)
	fp.add_child(fv)
	var fh := Kit.hbox(8)
	foot_lbl = Kit.label("", 16, Kit.INK, true)
	fh.add_child(foot_lbl)
	fh.add_child(Kit.button("Add what I am short of", func():
		var n := Market.fill_basket(sel)
		Kit.main.toast("Nothing they sell is short" if n == 0 else "Added %d lines from the par sheet" % n)
		Game.save_game()
		hub.render(), "ghost", 16))
	fh.add_child(Kit.button("Empty", func():
		Game.s.baskets[sel] = {}
		hub.render(), "ghost", 16))
	place_btn = Kit.button("", _place, "primary", 18)
	fh.add_child(place_btn)
	fv.add_child(fh)
	warn_lbl = Kit.label("", 14, Kit.TOMATO, true)
	fv.add_child(warn_lbl)
	right.add_child(fp)
	_refresh_foot()

func _top_grade() -> int:
	var g := 1
	for i in range(1, 6):
		if Data.GRADE_LVL[i] <= Game.s.level: g = i
	return g

func _terms(sup: Dictionary) -> String:
	var parts := []
	if sup.lead == 0:
		parts.append("You collect it now")
		parts.append("%s fuel per trip" % Kit.money(sup.trip))
		parts.append("pay at the till")
	else:
		var days: Array = sup.days.map(func(dd): return Data.DAY_SHORT[int(dd)])
		parts.append("Delivers " + ("Mon to Sat" if days.size() == 6 else ", ".join(days)))
		parts.append("order now, arrives %s" % Data.DAY_NAME[Game.weekday(Market.next_delivery(sup))])
		if sup.min > 0: parts.append("%s minimum" % Kit.money(sup.min))
		parts.append("%s delivery, free over %s" % [Kit.money(sup.fee), Kit.money(sup.free_over)])
		parts.append("pay when you order" if sup.terms == 0 else "invoiced, %d days to pay" % sup.terms)
	return " · ".join(parts)

## ingredients the current and booked menus (and their doughs) call for
func _menu_needs() -> Dictionary:
	var need := {"box": true}
	if Game.tier("oven").type == "wood": need["wood"] = true
	var menus := [Game.menu_now()]
	if Game.s.next_menu != "": menus.append(Data.MENU[Game.s.next_menu])
	for m in menus:
		for rid in m.items:
			var rc: Dictionary = Data.REC[rid]
			for i in rc.spec: need[i] = true
			for p in Data.DOUGHS[rc.base].parts:
				if p.ing != "water": need[p.ing] = true
	return need

func _build_rows(sup: Dictionary) -> void:
	var need := _menu_needs()
	var shown := 0
	var last_ing := ""
	for pr in Market.products(sup):
		var it: Dictionary = Data.ING[pr.ing]
		if cat != "" and it.cat != cat: continue
		if not whole and not need.has(pr.ing): continue
		shown += 1
		var unit: float = Market.unit_price(sup, pr.ing, pr.g, pr.pack)
		var list: float = Market.list_price(sup, pr.ing, pr.g, pr.pack)
		var p := Kit.panel(Kit.PANEL, 6, 8)
		var h := Kit.hbox(8)
		p.add_child(h)
		h.add_child(Kit.swatch(pr.ing, 20))
		var nv := Kit.vbox(0)
		nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nm := Kit.label(pr.name, 18)
		nm.clip_text = true
		nv.add_child(nm)
		var life: int = it.g[pr.g].life
		var season := ""
		if it.season >= 0: season = " · in season" if it.season == Game.season() else (" · out of season" if (it.season + 2) % 4 == Game.season() else "")
		nv.add_child(Kit.label("%s%s · %s · %s%s" % ["" if pr.ing == last_ing else it.name + " · ", Data.GRADES[pr.g], pr.label, ("keeps %d days" % life) if life < 900 else "keeps", season], 14, Kit.MUTED))
		h.add_child(nv)
		var pv := Kit.vbox(0)
		pv.custom_minimum_size.x = 150
		var pl := Kit.label(Kit.cents(unit * pr.units), 18)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pv.add_child(pl)
		var move: float = (unit / list - 1.0) * 100.0
		var tag := "OFFER  " if Market.on_offer(sup, pr.ing) else ""
		var sub := Kit.label("%s%s%s" % [tag, Data.rate(pr.ing, unit), ("  %+d%%" % int(round(move))) if abs(move) >= 1.5 else ""], 14, Kit.BASIL if move < -1.5 else (Kit.TOMATO if move > 1.5 else Kit.MUTED))
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pv.add_child(sub)
		h.add_child(pv)
		var hv := Kit.label("have " + Data.qty(pr.ing, Stock.have(pr.ing)), 14, Kit.MUTED)
		hv.custom_minimum_size.x = 104
		hv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(hv)
		var ql := Kit.label(str(Market.qty_in(sel, pr.key)), 20, Kit.CHEESE)
		ql.custom_minimum_size.x = 34
		ql.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var minus := Kit.button("-", _bump.bind(pr.key, -1), "ghost", 20)
		minus.custom_minimum_size.x = 44
		var plus := Kit.button("+", _bump.bind(pr.key, 1), "primary", 20)
		plus.custom_minimum_size.x = 44
		h.add_child(minus)
		h.add_child(ql)
		h.add_child(plus)
		qty_lbls[pr.key] = ql
		rows.add_child(p)
		last_ing = pr.ing
	if shown == 0:
		rows.add_child(Kit.label("Nothing here for your menus. Try the whole catalogue, or another supplier." if not whole else "They do not sell anything in that category.", 17, Kit.MUTED, true))

func _bump(key: String, by: int) -> void:
	Market.set_qty(sel, key, max(0, Market.qty_in(sel, key) + by))
	qty_lbls[key].text = str(Market.qty_in(sel, key))
	_refresh_foot()

func _refresh_foot() -> void:
	var sup: Dictionary = Data.SUP[sel]
	var sm := Market.summary(sel)
	if sm.n == 0:
		foot_lbl.text = "Basket is empty."
		place_btn.text = "Collect" if sup.lead == 0 else "Place order"
		place_btn.disabled = true
		warn_lbl.text = ""
		return
	foot_lbl.text = "%d line%s · goods %s%s" % [sm.n, "" if sm.n == 1 else "s", Kit.cents(sm.goods), (" · %s %s" % ["fuel" if sup.lead == 0 else "delivery", Kit.cents(sm.fee)]) if sm.fee > 0 else ""]
	place_btn.text = ("Collect now · %s" if sup.lead == 0 else "Place order · %s") % Kit.cents(sm.total)
	var warns := []
	if not sm.min_ok: warns.append("%s short of their %s minimum." % [Kit.cents(sup.min - sm.goods), Kit.money(sup.min)])
	for st in Data.STORES:
		if sm.space[st] <= 0: continue
		var cap := Stock.store_cap(st)
		var after: float = Stock.store_used(st) + sm.space[st]
		if cap <= 0: warns.append("You have no freezer: frozen goods will be wasted.")
		elif after > cap + 0.01: warns.append("%s would be at %d of %d. %s" % [Data.STORE_NAME[st], int(ceil(after)), int(cap), "It will not fit." if sup.lead == 0 else "Whatever does not fit on delivery is wasted."])
	if (sup.lead == 0 or sup.terms == 0) and sm.total > Game.s.cash: warns.append("You cannot afford it: they want paying now.")
	warn_lbl.text = "  ".join(warns)
	place_btn.disabled = not sm.min_ok

func _place() -> void:
	var sup: Dictionary = Data.SUP[sel]
	var sm := Market.summary(sel)
	var err := Market.place(sel)
	if err != "":
		Kit.main.toast(err, true)
		return
	Art.sfx("cash")
	if sup.lead == 0: Kit.main.toast("Loaded into the van: %s" % Kit.cents(sm.total))
	else: Kit.main.toast("Ordered. Arrives %s%s" % [Data.DAY_NAME[Game.weekday(sm.due)], "" if sup.terms == 0 else ", invoice to follow"])
	Game.save_game()
	hub.render()

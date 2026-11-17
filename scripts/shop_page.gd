class_name ShopPage
extends VBoxContainer
## KitBox, the catering-supplies website: every utensil and piece of small equipment is bought here, one at a time
## or by the pack. Laid out like a shop site: a header with the basket, a category bar, product cards, and a
## "What you need" list worked out from your kitchen (Equip.missing()).
## Art keys: "kit.<item id>" for each product photo, "kit.logo" for the site's logo.

static var cat := ""        # "" = what you need (or the first category if you need nothing)

var hub: Hub

func _init(h: Hub) -> void:
	hub = h
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)

func _ready() -> void:
	var miss := Equip.missing()
	if cat == "" and miss.is_empty(): cat = Equip.CATS[0][0]
	_header()
	_categories(miss.size())
	if cat == "" or cat == "need": _need(miss)
	elif cat == "orders": _orders()
	else: _products(Equip.ITEMS.filter(func(it): return it.cat == cat))

func _redo(fn: Callable) -> void:
	fn.call()
	Game.save_game()
	hub.render()

# ---------- the site header and basket ----------
func _header() -> void:
	var S: Dictionary = Equip.SHOP
	var hd := Kit.panel(Color("f4efe4"), 12, 12)
	var h := Kit.hbox(14)
	hd.add_child(h)
	var logo = Art.tex("kit.logo")
	if logo != null:
		var tr := TextureRect.new()
		tr.texture = logo
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.custom_minimum_size = Vector2(150, 44)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h.add_child(tr)
	var tv := Kit.vbox(0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(Kit.label(S.name, 24, Color("1d3557")))
	tv.add_child(Kit.label(S.tagline, 14, Color("4a5a6a"), true))
	h.add_child(tv)
	var sm := Equip.summary()
	var bv := Kit.vbox(2)
	bv.custom_minimum_size.x = 300
	if sm.n == 0:
		bv.add_child(Kit.label("Basket empty", 18, Color("1d3557")))
		bv.add_child(Kit.label("Order today, delivered %s %s-%s" % [Data.DAY_SHORT[Game.weekday(sm.due)], Data.hhmm(Market.window(S, sm.due)[0]), Data.hhmm(Market.window(S, sm.due)[1])], 13, Color("4a5a6a")))
	else:
		bv.add_child(Kit.label("Basket: %d line%s · %s" % [sm.n, "" if sm.n == 1 else "s", Kit.cents(sm.goods)], 18, Color("1d3557")))
		var more: float = float(S.free_over) - sm.goods
		bv.add_child(Kit.label(("Delivery " + Kit.cents(sm.fee) + (" · spend %s more for free delivery" % Kit.cents(more))) if sm.fee > 0 else "Free delivery", 13, Color("b23a2a") if sm.fee > 0 else Color("2f7a3a"), true))
		bv.add_child(Kit.label("Arrives %s, %s-%s" % [Data.DAY_NAME[Game.weekday(sm.due)] if sm.due > Game.s.day + 1 else "tomorrow", Data.hhmm(Market.window(S, sm.due)[0]), Data.hhmm(Market.window(S, sm.due)[1])], 13, Color("4a5a6a")))
	h.add_child(bv)
	var bb := Kit.vbox(4)
	var co := Kit.button("Checkout %s" % Kit.cents(sm.total) if sm.n > 0 else "Checkout", func(): _redo(func():
		var err := Equip.checkout()
		if err != "": Kit.main.toast(err, true)
		else:
			Art.sfx("cash")
			Kit.main.toast("Order placed with %s. Paid by card." % S.name)), "danger", 18)
	co.disabled = sm.n == 0 or Game.s.cash < sm.total
	bb.add_child(co)
	if sm.n > 0: bb.add_child(Kit.button("Empty basket", func(): _redo(func(): Game.s.kit_basket = {}), "ghost", 14))
	h.add_child(bb)
	add_child(hd)

func _categories(n_miss: int) -> void:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	var tabs := [["need", "What you need" + (" (%d)" % n_miss if n_miss > 0 else "")]]
	tabs.append_array(Equip.CATS)
	var n_orders: int = Game.s.get("kit_orders", []).size()
	tabs.append(["orders", "Your orders" + (" (%d)" % n_orders if n_orders > 0 else "")])
	for tb in tabs:
		var on: bool = cat == tb[0] or (cat == "" and tb[0] == "need")
		var b := Kit.button(tb[1], func():
			cat = tb[0]
			hub.render(), "primary" if on else "ghost", 16)
		if tb[0] == "need" and n_miss > 0 and not on: b.add_theme_color_override("font_color", Kit.TOMATO)
		row.add_child(b)
	add_child(row)

# ---------- products ----------
func _products(items: Array) -> void:
	var g := Kit.grid(2)
	for it in items: g.add_child(_card(it, ""))
	add_child(g)

func _need(miss: Array) -> void:
	if miss.is_empty():
		var c = Kit.card("Nothing missing")
		c[1].add_child(Kit.label("Your kitchen has everything tonight's menu, your staff and the inspector need. Browse the categories for upgrades: a rocking cutter, a rotary grater, a stick blender, an infrared thermometer, serving boards.", 16, Kit.MUTED, true))
		add_child(c[0])
		return
	var top := Kit.hbox(10)
	top.add_child(Kit.label("Worked out from your counter, menu, staff and the rules the inspector checks.", 15, Kit.MUTED, true))
	top.add_child(Kit.button("Add all to basket", func(): _redo(func():
		var n := Equip.add_missing()
		Kit.main.toast("Added %d line%s to your basket" % [n, "" if n == 1 else "s"])), "primary", 16))
	add_child(top)
	var g := Kit.grid(2)
	for m in miss: g.add_child(_card(Equip.ITEM[m.id], "You have %d, you need %d" % [m.have, m.need]))
	add_child(g)

func _card(it: Dictionary, why: String) -> Control:
	var id: String = it.id
	var p := Kit.panel(Kit.PANEL, 10, 12)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := Kit.hbox(10)
	p.add_child(h)
	var t = Art.tex("kit." + id)
	if t != null:
		var tr := TextureRect.new()
		tr.texture = t
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(84, 84)
		h.add_child(tr)
	else:
		var ph := Kit.panel(Color("eae4d6"), 4, 10)
		ph.custom_minimum_size = Vector2(84, 84)
		var cl := CenterContainer.new()
		cl.add_child(Kit.label(it.name.left(1), 34, Color("8a7f6a")))
		ph.add_child(cl)
		h.add_child(ph)
	var v := Kit.vbox(3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var nm := Kit.label(it.name, 17, Kit.INK, true)
	v.add_child(nm)
	v.add_child(Kit.label(it.desc, 13, Kit.MUTED, true))
	var have := Equip.count(id)
	var need := Equip.need(id)
	var coming: int = Equip.on_order().get(id, 0)
	var st := "You have %s" % (Equip.amount(id, have) if it.unit != "" else str(have))
	if coming > 0: st += " · %d on the way" % coming
	if need > 0: st += " · need %d" % need
	v.add_child(Kit.label(why if why != "" else st, 14, Kit.TOMATO if have < need else (Kit.BASIL if need > 0 else Kit.MUTED), true))
	var row := Kit.hbox(6)
	var price := Kit.label(Kit.cents(it.price) + (" / %d" % it.pack if it.pack > 1 else ""), 18, Kit.CHEESE)
	price.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(price)
	var q := Equip.in_basket(id)
	if q == 0:
		row.add_child(Kit.button("Add to basket", func(): _redo(func(): Equip.set_qty(id, 1)), "primary", 15))
	else:
		row.add_child(Kit.button("-", func(): _redo(func(): Equip.set_qty(id, q - 1)), "ghost", 16))
		row.add_child(Kit.label(" %d " % q, 18))
		row.add_child(Kit.button("+", func(): _redo(func(): Equip.set_qty(id, q + 1)), "primary", 16))
	v.add_child(row)
	return p

# ---------- orders on the way ----------
func _orders() -> void:
	var os: Array = Game.s.get("kit_orders", [])
	if os.is_empty():
		var c = Kit.card("No orders on the way")
		c[1].add_child(Kit.label("Orders placed by the end of the day arrive the next working day (Monday to Friday) between %s and %s." % [Data.hhmm(Equip.SHOP.window[0] * 60), Data.hhmm(Equip.SHOP.window[1] * 60)], 15, Kit.MUTED, true))
		add_child(c[0])
		return
	for o in os:
		var c = Kit.card("Order #%d · %s" % [int(o.id), Kit.cents(o.total)])
		c[1].add_child(Kit.label("Arriving %s at about %s" % ["today" if int(o.due) == Game.s.day else ("tomorrow" if int(o.due) == Game.s.day + 1 else Data.DAY_NAME[Game.weekday(int(o.due))]), Data.hhmm(o.eta)], 16, Kit.CHEESE))
		var lines := []
		for id in o.lines: lines.append("%d x %s" % [int(o.lines[id]), Equip.ITEM[id].name])
		c[1].add_child(Kit.label(", ".join(lines), 14, Kit.MUTED, true))
		add_child(c[0])

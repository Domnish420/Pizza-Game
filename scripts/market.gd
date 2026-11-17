extends Node
## Autoload `Market`: the businesses you buy from.
##
## Each supplier's catalogue is generated from data/suppliers.json and data/ingredients.json:
## what they carry x the qualities they stock x the pack sizes they sell, filtered by your level.
## Prices move every day (more for fresh produce), dip in season, and each supplier runs weekly offers.
## You fill a basket per supplier and place it. A cash & carry hands the goods over now; everyone else
## delivers on their next delivery day, may want a minimum order and a delivery fee, and may invoice you later.

var _offer_cache := {}

# ---------- catalogues ----------
func open_suppliers() -> Array:
	return Data.SUPPLIERS.filter(func(sp): return sp.lvl <= Game.s.level)

func carries(sup: Dictionary, id: String) -> bool:
	if sup.get("skip", []).has(id): return false
	if sup.has("only"): return sup.only.has(id)
	return sup.cats.has(Data.ING[id].cat) or sup.get("only_extra", []).has(id)

## the ingredients a supplier can sell you today
func range_of(sup: Dictionary) -> Array:
	var out := []
	for id in Data.ING:
		var it: Dictionary = Data.ING[id]
		if it.lvl > Game.s.level or not carries(sup, id): continue
		if sup.get("seasonal", false) and it.season >= 0 and it.season != Game.season(): continue
		out.append(id)
	return out

## every product line: {key, ing, g, pack, units, label, name}
func products(sup: Dictionary) -> Array:
	var out := []
	for id in range_of(sup):
		var it: Dictionary = Data.ING[id]
		for g in it.grade_list:
			if g < sup.grades[0] or g > sup.grades[1] or Data.GRADE_LVL[g] > Game.s.level: continue
			var seen := {}
			for pi in sup.packs:
				var idx: int = min(int(pi), it.packs.size() - 1)
				if seen.has(idx): continue
				seen[idx] = true
				out.append(_product(id, g, idx))
	return out

func _product(id: String, g: int, idx: int) -> Dictionary:
	var it: Dictionary = Data.ING[id]
	return {"key": "%s:%d:%d" % [id, g, idx], "ing": id, "g": g, "pack": idx, "units": float(it.packs[idx][0]), "label": it.packs[idx][1], "name": it.g[g].name}

func product(key: String) -> Dictionary:
	var p := key.split(":")
	return _product(p[0], int(p[1]), int(p[2]))

# ---------- prices ----------
## the supplier's catalogue price per unit, before the market moves it
func list_price(sup: Dictionary, id: String, g: int, idx: int) -> float:
	return Data.ING[id].g[g].price * sup.mult * Data.PACK_DISC[min(idx, Data.PACK_DISC.size() - 1)]

## today's market level for an ingredient at a supplier (1.0 = catalogue price)
func market(sup: Dictionary, id: String, day: int = -1) -> float:
	var d: int = Game.s.day if day < 0 else day
	var it: Dictionary = Data.ING[id]
	var h: int = abs(hash(sup.id + ":" + id))
	var wave := sin(d * 0.83 + (h % 1000) * 0.00628) * 0.55 + sin(d * 0.21 + ((h / 1000) % 1000) * 0.00628) * 0.45
	var m: float = 1.0 + it.vol * sup.vol * wave
	if it.season >= 0:
		var sn := Game.season(d)
		if sn == it.season: m *= 0.86
		elif sn == (it.season + 2) % 4: m *= 1.2
	return m

func on_offer(sup: Dictionary, id: String, day: int = -1) -> bool:
	var d: int = Game.s.day if day < 0 else day
	var week: int = (d - 1) / 7
	var ck := "%s:%d:%d" % [sup.id, week, Game.s.level]
	if not _offer_cache.has(ck):
		var ids := range_of(sup)
		var picks := {}
		if ids.size() > 3:
			for j in (3 if sup.lead == 0 else 2):
				picks[ids[abs(hash("%s:%d:%d" % [sup.id, week, j])) % ids.size()]] = true
		_offer_cache[ck] = picks
	return _offer_cache[ck].has(id)

## what one unit (g, ml, box...) costs from this supplier today
func unit_price(sup: Dictionary, id: String, g: int, idx: int, day: int = -1) -> float:
	return list_price(sup, id, g, idx) * market(sup, id, day) * (0.8 if on_offer(sup, id, day) else 1.0)

func pack_price(sup: Dictionary, pr: Dictionary) -> float:
	return unit_price(sup, pr.ing, pr.g, pr.pack) * pr.units

# ---------- baskets ----------
func basket(sup_id: String) -> Dictionary:
	if not Game.s.baskets.has(sup_id): Game.s.baskets[sup_id] = {}
	return Game.s.baskets[sup_id]

func set_qty(sup_id: String, key: String, n: int) -> void:
	var b := basket(sup_id)
	if n <= 0: b.erase(key)
	else: b[key] = n

func qty_in(sup_id: String, key: String) -> int:
	return int(basket(sup_id).get(key, 0))

func lines(sup_id: String) -> Array:
	var sup: Dictionary = Data.SUP[sup_id]
	var out := []
	for key in basket(sup_id):
		var pr := product(key)
		pr.packs = int(basket(sup_id)[key])
		pr.unit = unit_price(sup, pr.ing, pr.g, pr.pack)
		pr.cost = pr.unit * pr.units * pr.packs
		out.append(pr)
	return out

func next_delivery(sup: Dictionary, from_day: int = -1) -> int:
	var d: int = (Game.s.day if from_day < 0 else from_day) + 1
	for i in 14:
		if sup.days.has(float(Game.weekday(d + i))) or sup.days.has(Game.weekday(d + i)): return d + i
	return d

func summary(sup_id: String) -> Dictionary:
	var sup: Dictionary = Data.SUP[sup_id]
	var out := {"goods": 0.0, "n": 0, "space": {"fridge": 0.0, "freezer": 0.0, "dry": 0.0}}
	for ln in lines(sup_id):
		out.goods += ln.cost
		out.n += 1
		out.space[Data.ING[ln.ing].store] += Stock.space_of(ln.ing, ln.units * ln.packs)
	out.fee = 0.0
	if out.goods > 0:
		out.fee = float(sup.get("trip", 0.0)) if sup.lead == 0 else (0.0 if out.goods >= sup.free_over else float(sup.fee))
	out.total = out.goods + out.fee
	out.min_ok = out.goods >= sup.min
	out.due = Game.s.day if sup.lead == 0 else next_delivery(sup)
	return out

## place the basket. Returns "" or why not.
func place(sup_id: String) -> String:
	var sup: Dictionary = Data.SUP[sup_id]
	var sm := summary(sup_id)
	if sm.n == 0: return "Your basket is empty"
	if not sm.min_ok: return "%s has a %s minimum order" % [sup.name, Kit.money(sup.min)]
	var pay_now: bool = sup.lead == 0 or sup.terms == 0
	if pay_now and Game.s.cash < sm.total: return "You cannot afford that. This supplier wants paying up front"
	if sup.lead == 0:
		for st in Data.STORES:
			if sm.space[st] > Stock.store_free(st) + 0.001:
				return "No room: your %s cannot take all of that" % Data.STORE_NAME[st].to_lower() if Stock.store_cap(st) > 0 else "You have no freezer"
	var order := {"id": Game.s.oid, "sup": sup_id, "placed": Game.s.day, "due": sm.due, "goods": sm.goods, "fee": sm.fee, "total": sm.total, "paid": pay_now, "lines": []}
	Game.s.oid += 1
	var uplift: float = 1.0 + sm.fee / sm.goods   # the fee is part of what the goods cost you
	for ln in lines(sup_id):
		order.lines.append({"ing": ln.ing, "g": ln.g, "q": ln.units * ln.packs, "c": ln.unit * uplift, "name": ln.name, "what": "%d x %s" % [ln.packs, ln.label]})
	if pay_now: Game.s.cash -= sm.total
	Game.s.baskets[sup_id] = {}
	if sup.lead == 0: _receive(order)
	else: Game.s.orders.append(order)
	return ""

func cancel(order: Dictionary) -> void:
	if order.paid: Game.s.cash += order.total
	Game.s.orders.erase(order)

## put an order into the stores. Anything that does not fit is wasted. Returns [{id, q}] wasted.
func _receive(order: Dictionary) -> Array:
	var wasted := []
	for ln in order.lines:
		var it: Dictionary = Data.ING[ln.ing]
		var fits: float = min(ln.q, max(0.0, Stock.store_free(it.store)) / it.space)
		if it.unit != "g" and it.unit != "ml": fits = floor(fits)
		Stock.add(ln.ing, fits, int(ln.g), ln.c)
		if ln.q - fits > ln.q * 0.005:
			wasted.append({"id": ln.ing, "q": ln.q - fits})
			Stock.log_waste(ln.ing, ln.q - fits, (ln.q - fits) * ln.c)
	return wasted

## the morning's deliveries. Returns [{sup, total, n, wasted, invoice_due}]
func deliver() -> Array:
	var notes := []
	for o in Game.s.orders.duplicate():
		if o.due > Game.s.day: continue
		Game.s.orders.erase(o)
		var sup: Dictionary = Data.SUP[o.sup]
		var note := {"sup": sup.name, "total": o.total, "n": o.lines.size(), "wasted": _receive(o), "invoice_due": 0}
		if not o.paid:
			note.invoice_due = Game.s.day + int(sup.terms)
			Game.s.payables.append({"sup": o.sup, "amount": o.total, "due": note.invoice_due})
		notes.append(note)
	return notes

## invoices that fall due today are taken from the bank. Returns [{sup, amount}]
func pay_due() -> Array:
	var paid := []
	for p in Game.s.payables.duplicate():
		if p.due > Game.s.day: continue
		Game.s.payables.erase(p)
		Game.s.cash -= p.amount
		paid.append({"sup": Data.SUP[p.sup].name, "amount": p.amount})
	return paid

func owed() -> float:
	var t := 0.0
	for p in Game.s.payables: t += p.amount
	return t

## how much of an ingredient is on order and arrives by a given day
func incoming(id: String, by_day: int) -> float:
	var t := 0.0
	for o in Game.s.orders:
		if o.due > by_day: continue
		for ln in o.lines:
			if ln.ing == id: t += ln.q
	return t

# ---------- the par sheet: what the next two days need ----------
func _merge(into: Dictionary, from: Dictionary) -> void:
	for k in from: into[k] = into.get(k, 0.0) + from[k]

## what a day's service will use, by recipe card
func need_service(day: int) -> Dictionary:
	var need := {}
	var recs := Game.recipes_on(day)
	if recs.is_empty(): return need
	var cov: float = Game.covers(day) * 1.1 + 1.0
	for r in recs:
		for id in r.spec: need[id] = need.get(id, 0.0) + r.spec[id] * cov / recs.size()
	var take_share := 1.0 if Game.calc().tables == 0 else 0.5
	need["box"] = ceil(cov * take_share)
	if Game.tier("oven").type == "wood": need["wood"] = 10.0
	return need

## what the dough made on `make_day` will use
func need_dough(make_day: int) -> Dictionary:
	var need := {}
	var plan := Game.dough_plan(make_day)
	for st in plan:
		var parts := Stock.dough_parts(st, plan[st] * Stock.flour_per_ball(st))
		for ing in parts:
			if ing != "water": need[ing] = need.get(ing, 0.0) + parts[ing]
	return need

## one row per ingredient: {id, have, today, tomorrow, incoming, short_today, short_tomorrow}
func par() -> Array:
	var day: int = Game.s.day
	var today := {}
	if Game.s.phase == "morning": _merge(today, need_service(day))
	_merge(today, need_dough(day))
	var tomorrow := {}
	_merge(tomorrow, need_service(day + 1))
	_merge(tomorrow, need_dough(day + 1))
	var ids := {}
	for id in today: ids[id] = true
	for id in tomorrow: ids[id] = true
	var rows := []
	for id in ids:
		var have := Stock.have(id)
		var t: float = today.get(id, 0.0)
		var tm: float = tomorrow.get(id, 0.0)
		var left: float = min(Stock.have(id, day + 1), max(0.0, have - t))
		var inc := incoming(id, day + 1)
		var st: float = max(0.0, t - have)
		var stm: float = max(0.0, tm - left - inc)
		rows.append({"id": id, "have": have, "today": t, "tomorrow": tm, "incoming": inc,
			"short_today": st if st > t * 0.03 else 0.0, "short_tomorrow": stm if stm > tm * 0.03 else 0.0})
	var order := {}
	for i in Data.CATS.size(): order[Data.CATS[i][0]] = i
	rows.sort_custom(func(a, b):
		var ca: int = order[Data.ING[a.id].cat]
		var cb: int = order[Data.ING[b.id].cat]
		return ca < cb if ca != cb else Data.ING[a.id].name < Data.ING[b.id].name)
	return rows

# ---------- buying helpers ----------
## the best product line at a supplier for `need` units of an ingredient, at or near a quality. {} if they do not sell it.
func choose(sup: Dictionary, id: String, need: float, grade: int) -> Dictionary:
	var best := {}
	var best_score := INF
	for pr in products(sup):
		if pr.ing != id: continue
		var packs: int = int(max(1, ceil(need / pr.units - 0.0001)))
		var cost := pack_price(sup, pr) * packs
		var score: float = abs(pr.g - grade) * 100000.0 + (500.0 if pr.g > grade else 0.0) + cost
		if score < best_score:
			best_score = score
			best = {"key": pr.key, "packs": packs, "cost": cost, "g": pr.g}
	return best

## add whatever the par sheet says is short to a supplier's basket, at your buying standard. Returns lines added.
func fill_basket(sup_id: String) -> int:
	var sup: Dictionary = Data.SUP[sup_id]
	var n := 0
	for row in par():
		var short: float = row.short_tomorrow + (row.short_today if sup.lead == 0 else 0.0)
		if short <= 0 or not carries(sup, row.id): continue
		var ch := choose(sup, row.id, short, Game.s.house_grade)
		if ch.is_empty(): continue
		set_qty(sup_id, ch.key, max(qty_in(sup_id, ch.key), ch.packs))
		n += 1
	return n

## the general manager's evening job: order tomorrow's shortfall from whoever delivers tomorrow. Returns [supplier names].
func auto_order() -> Array:
	var placed := []
	var day: int = Game.s.day
	for row in par():
		if row.short_tomorrow <= 0: continue
		var best := {}
		var best_sup := ""
		var best_score := INF
		for sup in open_suppliers():
			if sup.lead == 0 or next_delivery(sup) != day + 1 or not carries(sup, row.id): continue
			var ch := choose(sup, row.id, row.short_tomorrow, Game.s.house_grade)
			if ch.is_empty(): continue
			var score: float = abs(ch.g - Game.s.house_grade) * 100000.0 + ch.cost
			if score < best_score:
				best_score = score
				best = ch
				best_sup = sup.id
		if best_sup != "": set_qty(best_sup, best.key, max(qty_in(best_sup, best.key), best.packs))
	for sup in open_suppliers():
		if sup.lead == 0 or summary(sup.id).n == 0: continue
		if place(sup.id) == "": placed.append(sup.name)
		else: Game.s.baskets[sup.id] = {}
	return placed

## the general manager's morning job: fetch today's shortfall from the cash & carry. Returns money spent.
func auto_collect() -> float:
	var spent := 0.0
	for sup in open_suppliers():
		if sup.lead != 0: continue
		Game.s.baskets[sup.id] = {}
		for row in par():
			if row.short_today <= 0 or not carries(sup, row.id): continue
			var ch := choose(sup, row.id, row.short_today, Game.s.house_grade)
			if not ch.is_empty(): set_qty(sup.id, ch.key, ch.packs)
		var total: float = summary(sup.id).total
		if summary(sup.id).n > 0 and place(sup.id) == "": spent += total
		else: Game.s.baskets[sup.id] = {}
	return spent

## what a unit of an ingredient costs you: your stock's average, else the cheapest price at your buying standard
func ref_cost(id: String) -> float:
	if Stock.have(id) > 0: return Stock.avg_cost(id)
	var best := INF
	for sup in open_suppliers():
		var ch := choose(sup, id, 1.0, Game.s.house_grade)
		if ch.is_empty(): continue
		var pr := product(ch.key)
		best = min(best, unit_price(sup, id, pr.g, pr.pack))
	return best if best < INF else 0.0

## what a pizza costs to make exactly to its recipe card: {cost, lines: [{id, q, cost}]}
func recipe_cost(r: Dictionary) -> Dictionary:
	var out := {"cost": 0.0, "lines": []}
	var parts := Stock.dough_parts(r.base, Stock.flour_per_ball(r.base))
	var dough := 0.0
	for ing in parts:
		if ing != "water": dough += parts[ing] * ref_cost(ing)
	out.lines.append({"id": "dough:" + r.base, "q": 1.0, "cost": dough})
	out.cost += dough
	for id in r.spec:
		var c: float = r.spec[id] * ref_cost(id)
		out.lines.append({"id": id, "q": r.spec[id], "cost": c})
		out.cost += c
	return out

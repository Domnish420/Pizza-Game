extends Node
## Autoload `Equip`: the utensils and small equipment in the kitchen and front of house, and KitBox, the
## catering-supplies website they are all bought from.
##
## Everything is counted (Game.s.equip[id] = how many you own; for things sold in packs, how many items, not packs).
## What each item does in the game is its `rule` in data/equipment.json, and the questions the rest of the game asks
## are answered here: can I roll this base, which chopping board does onion go on, how many guests can I seat,
## is a pizza wheel free. Nothing here draws anything.
##
## KitBox works like a real catering-supplies site: put things in the basket, check out (paid by card, so up front),
## and the courier brings it the next working day. Free delivery over the threshold.

const FILE := "res://data/equipment.json"
var SHOP := {}
var CATS := []          # [[category id, label]]
var ITEMS := []
var ITEM := {}
var STARTERS := {}

func _init() -> void:
	var d = JSON.parse_string(FileAccess.open(FILE, FileAccess.READ).get_as_text())
	SHOP = d.shop
	CATS = d.categories
	ITEMS = d.items
	for it in ITEMS:
		it.pack = int(it.get("pack", 1))
		it.unit = it.get("unit", "")
		it.price = float(it.price)
		it.short = it.get("short", it.name.to_lower())
		ITEM[it.id] = it
	STARTERS = d.starters

# ---------- what you own ----------
func count(id: String) -> int:
	return int(Game.s.get("equip", {}).get(id, 0))

func has(id: String) -> bool:
	return count(id) > 0

func add(id: String, n: int) -> void:
	Game.s.equip[id] = count(id) + n

## use up consumables (labels, cloths) or lose breakables. Returns how many there were to use.
func use(id: String, n: int) -> int:
	var k: int = min(n, count(id))
	Game.s.equip[id] = count(id) - k
	return k

## the kit a new business starts with ("van" or "pizzeria")
func starter(kind: String) -> Dictionary:
	var out := {}
	for k in STARTERS[kind]: out[k] = int(STARTERS[kind][k])
	return out

## "2 pizza peels", "1000 labels"
func amount(id: String, n: int) -> String:
	var it: Dictionary = ITEM[id]
	if it.unit != "": return "%d %s" % [n, it.unit if n == 1 else (it.unit + ("es" if it.unit.ends_with("s") else "s"))]
	return "%s ×%d" % [it.short, n]

# ---------- ladles ----------
func ladles(oz: int) -> int:
	return count("ladle_%d" % oz)

# ---------- the pizza station ----------
## people loading and pulling pizzas at the oven: you and every pizzaiolo, or the oven tender
func oven_hands() -> int:
	return 1 + Game.staff_of("pizzaiolo").size() + Game.staff_of("fornaio").size()

## share of the people at the oven who have a peel (1.0 = everyone)
func peel_share() -> float:
	return clamp(float(count("peel")) / oven_hands(), 0.0, 1.0)

## the oven needs turning by hand (gas and wood fire from one side; electric decks heat evenly, rotating hearths turn themselves)
func turning_oven() -> bool:
	var ty: String = Game.tier("oven").type
	return ty == "gas" or ty == "wood"

## what you slice with: "rocker", "wheel", "knife" or ""
func cutter() -> String:
	for id in ["rocker", "wheel", "knife"]:
		if has(id): return id
	return ""

## the rolling pin, unless a sheeter does the job
func can_roll() -> bool:
	return float(Game.tier("roller").auto) > 0.0 or has("pin")

## deep-pan and gluten-free bases are baked in tins
func needs_tin(style: String) -> bool:
	return Data.DOUGHS[style].shape == "press"

## dough balls the proving trays hold
func tray_capacity() -> int:
	return count("dough_tray") * int(ITEM.dough_tray.get("holds", 12))

## room for more dough tonight
func dough_room() -> int:
	return max(0, tray_capacity() - Stock.dough_count())

## mixing by hand needs a bowl; a mixer has its own
func can_mix() -> bool:
	return int(Game.s.upg.mixer) > 0 or has("bowl")

## a scraper divides dough into even balls; without one they come out uneven
func dough_q_bonus() -> float:
	return 0.0 if has("scraper") else -8.0

## a weight as you can read it: exact on scales, a guess without
func weigh(g: float, tool: String = "scales") -> String:
	if has(tool): return "%d g" % round(g) if g < 1000 else "%.2f kg" % (g / 1000.0)
	var step := 5.0 if g < 40 else (25.0 if g < 500 else 100.0)
	return "about %d g" % (round(g / step) * step)

## the look and taste of a finished pizza, lifted or dragged down by the kit it was made with
func adjust(a: Dictionary, rec: Dictionary, by_staff: bool) -> void:
	var style: String = rec.base
	if Data.DOUGHS[style].shape == "roll" and not has("docker"):
		a.look -= 6.0
		a.notes.append("Big bubbles in the base")
	if Game.tier("oven").type == "wood" and not has("oven_brush"):
		a.look -= 5.0
		a.taste -= 4.0
		a.notes.append("Ash on the bottom")
	if by_staff and turning_oven() and not has("turner"):
		a.look -= 6.0
		a.notes.append("Pale on one side")
	if by_staff:
		match cutter():
			"rocker": a.look += 2.0
			"wheel": pass
			"knife":
				a.look -= 6.0
				a.notes.append("Ragged slices")
			_:
				a.look -= 12.0
				a.notes.append("Not sliced")
	a.look = clamp(a.look, 0.0, 100.0)
	a.taste = clamp(a.taste, 0.0, 100.0)

# ---------- prep ----------
## the colour-coded chopping board an ingredient is cut on
func board_for(id: String) -> String:
	var ing: Dictionary = Data.ING[id]
	if ["onion", "potato", "garlic"].has(id): return "brown"
	if id == "sausage": return "red"
	match ing.cat:
		"veg", "herb": return "green"
		"cheese": return "white"
		"meat": return "yellow"
		"fish": return "blue"
	return "white"

## the tools a prep job needs: a list of groups, any one item from each group will do
func prep_tools(id: String) -> Array:
	var p = Data.ING[id].prep
	if p == null: return []
	match p.mode:
		"knife": return [["knife"], ["board_" + board_for(id)]]
		"grate": return [["grater", "rotary"]] if id != "gorgonzola" else []
		"pour": return [] if Data.ING[id].kind == "sauce" else [["colander"]]
		"pick": return [["colander"]] if Data.ING[id].cat == "veg" else []
		"stir":
			if id == "ricotta": return [["bowl"]]
			if id == "cream": return [["saucepan"]]
			if id == "prawn" or id == "seafood": return [["colander"]]
			return [["fry_pan", "saucepan"]]
	return []

## why this prep cannot be done with the kit you have, or ""
func prep_block(id: String) -> String:
	for grp in prep_tools(id):
		if grp.any(func(t): return has(t)): continue
		var names: Array = grp.map(func(t): return ITEM[t].short)
		return "You need a %s for that. Order one from %s." % [" or a ".join(names), SHOP.name]
	return ""

## how long a prep job takes with this kit (1.0 = normal)
func prep_mult(id: String) -> float:
	var p = Data.ING[id].prep
	if p == null: return 1.0
	var m := 1.0
	if p.mode == "grate" and has("rotary"): m *= 0.6
	if Data.ING[id].kind == "sauce" and p.mode == "pour" and not has("blender"): m *= 1.6
	return m

## knife prep on tonight's menu with no board of the right colour: [ingredient names]
func board_issues() -> Array:
	var out := []
	for id in Day.line_ids():
		var p = Data.ING[id].prep
		if p == null or p.mode != "knife": continue
		if not has("board_" + board_for(id)): out.append(Data.ING[id].name.to_lower())
	return out

## the menu has cooked prep (sausage, white sauce...) that should be probed
func menu_cooks() -> bool:
	for id in Day.line_ids():
		var p = Data.ING[id].prep
		if p != null and p.mode == "stir" and id != "ricotta": return true
	return false

## allergy orders are made on the purple board with the purple knife
func allergen_kit() -> bool:
	return has("board_purple") and has("knife_purple")

# ---------- the counter rail ----------
## the gastronorm pan the counter takes, or "" for the folding table (tubs straight on the table)
func rail_pan_id() -> String:
	if int(Game.s.upg.prep) == 0: return ""
	return "gn13" if float(Game.tier("prep").pan) >= 2.0 else "gn16"

## tubs that can stand on the counter in place of pans, when you are short of pans
const TUB_SLOTS := 6

## slots on the rail: as many as the counter holds, if you own that many pans. Short of pans, you work out of
## up to TUB_SLOTS tubs on the counter instead.
func rail_size() -> int:
	var n: int = int(Game.tier("prep").rail)
	var pid := rail_pan_id()
	return n if pid == "" else min(n, max(count(pid), TUB_SLOTS))

# ---------- labels ----------
## stick a day-dot on a tub. false if you have run out of labels
func label_tub() -> bool:
	return use("daydots", 1) > 0

## tubs in the fridge with no label on them
func unlabelled() -> int:
	var n := 0
	for id in Game.s.prepped:
		for l in Game.s.prepped[id]:
			if not l.get("lab", true): n += 1
	return n

# ---------- thermometers ----------
## you need a thermometer in each fridge and freezer you log
func thermo_for(store: String) -> bool:
	return count("fridge_thermo") > Checks.stores_to_log().find(store)

# ---------- cleaning ----------
func mop_for(area: String) -> String:
	return "mop_" + area

## the mop matters on a floor you can mop: the kitchen, and a dining room (a van's hatch is wiped, not mopped)
func needs_mop(area: String) -> bool:
	return area == "boh" or Game.venue().tables > 0

## cloths one clean of an area uses
func cloths_needed(area: String) -> int:
	return int(ceil(float(Game.venue().size) * (2.0 if area == "boh" else 1.5)))

## the best a clean can reach with the kit you have, and why not higher. Takes the cloths.
func clean_cap(area: String) -> Dictionary:
	var cap := 100.0
	var why := []
	if needs_mop(area) and not has(mop_for(area)):
		cap = min(cap, 65.0)
		why.append("no %s mop" % ("kitchen" if area == "boh" else "front-of-house"))
	if not has("spray"):
		cap = min(cap, 72.0)
		why.append("no spray bottle for the chemicals")
	var want := cloths_needed(area)
	if use("cloths", want) < want:
		cap = min(cap, 70.0)
		why.append("ran out of cloths")
	return {"cap": cap, "why": why}

# ---------- front of house ----------
## guests you can lay a place for: plate, knife and fork, glass
func seats() -> int:
	return min(count("plate"), min(count("cutlery"), count("glass")))

## a dine-in party leaves: now and then something gets broken. Adds to `into` {plate: n, glass: n}
func breakage(guests: int, into: Dictionary) -> void:
	for i in guests:
		if randf() < 0.004 and use("plate", 1) > 0: into.plate = into.get("plate", 0) + 1
		if randf() < 0.008 and use("glass", 1) > 0: into.glass = into.get("glass", 0) + 1

## share of deliveries that go out in a hot bag
func bag_share() -> float:
	var drivers := Game.staff_of("driver").size()
	return 1.0 if drivers == 0 else clamp(float(count("delivery_bag")) / drivers, 0.0, 1.0)

# ---------- safety ----------
func compliance_missing() -> Array:
	var out := []
	for id in ["first_aid", "fire_blanket", "extinguisher", "handwash"]:
		if id == "handwash" and int(Game.s.venue) < 2: continue
		if not has(id): out.append(ITEM[id].short)
	return out

# ---------- what you need ----------
## how many of an item this setup should have (0 = optional here)
func need(id: String) -> int:
	var G := Game
	var it: Dictionary = ITEM[id]
	var cooks: int = 1 + G.staff_of("pizzaiolo").size()
	var recs := G.active_recipes()
	var styles := recs.map(func(r): return r.base)
	match it.rule:
		"ladle": return cooks if G.sauce_sizes().has(int(it.oz)) else 0
		"peel": return oven_hands()
		"turner": return (1 + G.staff_of("fornaio").size()) if turning_oven() else 0
		"wheel": return 0 if has("rocker") else 1
		"scraper", "jug", "scales", "spray": return 1
		"pin": return 1 if styles.any(func(s): return Data.DOUGHS[s].shape == "roll") and float(G.tier("roller").auto) <= 0.0 else 0
		"docker": return 1 if styles.any(func(s): return Data.DOUGHS[s].shape == "roll") else 0
		"pan_tin": return int(G.tier("oven").slots) if styles.any(func(s): return needs_tin(s)) else 0
		"dough_tray":
			var balls := 0
			var plan := G.dough_plan()
			for st in plan: balls += int(plan[st])
			return int(ceil(float(max(balls, Stock.dough_count())) / float(it.get("holds", 12)))) + 1
		"oven_brush": return 1 if G.tier("oven").type == "wood" else 0
		"serving_board": return 0
		"knife": return 1 + G.staff_of("prep").size()
		"board":
			if it.colour == "purple": return 0
			for i in Day.line_ids():
				var p = Data.ING[i].prep
				if p != null and p.mode == "knife" and board_for(i) == it.colour: return 1
			return 0
		"grater":
			if has("rotary"): return 0
			return 1 if Day.line_ids().any(func(i): return Data.ING[i].prep != null and Data.ING[i].prep.mode == "grate" and i != "gorgonzola") else 0
		"colander", "pan", "bowl":
			if it.rule == "bowl" and not can_mix_without_bowl(): return 1
			for i in Day.line_ids():
				for grp in prep_tools(i):
					if grp[0] == id and not grp.any(func(t): return has(t)): return 1
			return 0
		"probe": return 1 if menu_cooks() else 0
		"gn": return int(G.tier("prep").rail) if rail_pan_id() == id else 0
		"fridge_thermo": return Checks.stores_to_log().size()
		"daydots": return 100
		"mop": return 1 if needs_mop(it.area) else 0
		"cloths": return 20
		"tableware": return min(G.s.tables, G.venue().tables) * 3
		"delivery_bag": return G.staff_of("driver").size()
		"scoop": return 1 if G.s.level >= int(Data.EXTRA.gelato.lvl) and Stock.store_cap("freezer") > 0 and not G.s.get("extra_off", {}).get("gelato", false) else 0
		"dessert_plate": return G.calc_tables() * 2 if G.extras_on("dessert").size() + G.extras_on("side").size() > 0 else 0
		"cups": return G.calc_tables() * 2 if G.drinks_tier() >= 2 else 0
		"compliance": return 0 if id == "handwash" and int(G.s.venue) < 2 else 1
	return 0

func can_mix_without_bowl() -> bool:
	return int(Game.s.upg.mixer) > 0

## what you are short of: [{id, have, need, buy (packs to order), why}], most important first
func missing() -> Array:
	var out := []
	for it in ITEMS:
		var n := need(it.id)
		var have := count(it.id)
		if have >= n or n <= 0: continue
		out.append({"id": it.id, "have": have, "need": n, "buy": int(ceil(float(n - have) / it.pack)), "why": it.desc})
	return out

# ---------- the KitBox website ----------
func basket() -> Dictionary:
	if not Game.s.has("kit_basket"): Game.s.kit_basket = {}
	return Game.s.kit_basket

func in_basket(id: String) -> int:
	return int(basket().get(id, 0))

func set_qty(id: String, packs: int) -> void:
	if packs <= 0: basket().erase(id)
	else: basket()[id] = packs

func add_missing() -> int:
	var n := 0
	for m in missing():
		if in_basket(m.id) < m.buy:
			set_qty(m.id, m.buy)
			n += 1
	return n

## {goods, fee, total, n (lines), due (day), eta (minute)}
func summary() -> Dictionary:
	var goods := 0.0
	var n := 0
	for id in basket():
		goods += ITEM[id].price * int(basket()[id])
		n += 1
	var fee: float = 0.0 if goods >= float(SHOP.free_over) or goods <= 0.0 else float(SHOP.fee)
	var due := delivery_day()
	return {"goods": goods, "fee": fee, "total": goods + fee, "n": n, "due": due, "eta": Market.eta(SHOP, due)}

## the next working day a courier delivers, after `from_day`
func delivery_day(from_day: int = -1) -> int:
	var d: int = (Game.s.day if from_day < 0 else from_day) + 1
	while not SHOP.days.has(float(Game.weekday(d))) and not SHOP.days.has(Game.weekday(d)): d += 1
	return d

## pay for the basket. Returns "" or why not.
func checkout() -> String:
	var sm := summary()
	if sm.n == 0: return "Your basket is empty"
	if Game.s.cash < sm.total: return "Card declined: you cannot afford that"
	var lines := {}
	for id in basket(): lines[id] = int(basket()[id])
	Game.s.kit_orders.append({"id": Game.s.oid, "placed": Game.s.day, "due": sm.due, "eta": sm.eta, "lines": lines, "total": sm.total})
	Game.s.oid += 1
	Game.s.cash -= sm.total
	Game.s.kit_basket = {}
	return ""

## parcels that arrive by `t` today (or that were due on an earlier day). Returns notes.
func arrivals(t: float) -> Array:
	var notes := []
	for o in Game.s.kit_orders.duplicate():
		if int(o.due) > Game.s.day or (int(o.due) == Game.s.day and float(o.eta) > t): continue
		Game.s.kit_orders.erase(o)
		var what := []
		for id in o.lines:
			add(id, int(o.lines[id]) * int(ITEM[id].pack))
			what.append("%d x %s" % [int(o.lines[id]), ITEM[id].short])
		notes.append("%s parcel signed for at %s: %s." % [SHOP.name, Data.hhmm(float(o.eta) if int(o.due) == Game.s.day else Day.START), ", ".join(what)])
	return notes

## everything on order but not here yet: {id: items}
func on_order() -> Dictionary:
	var out := {}
	for o in Game.s.get("kit_orders", []):
		for id in o.lines: out[id] = out.get(id, 0) + int(o.lines[id]) * int(ITEM[id].pack)
	return out

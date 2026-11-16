extends Node
## Game state and rules: money, XP, stock (dated lots), storage limits, dough ageing, fortnightly menus, upgrades, staff.
## No drawing here. `s` is the whole save file.

const SAVE_PATH := "user://crust_empire_save.json"
var s := {}

func _ready() -> void:
	if not load_game():
		new_game()

# ---------- save ----------
func new_game() -> void:
	var upg := {}
	for k in Data.UPG:
		upg[k] = 0
	s = {
		"day": 1, "cash": 150.0, "xp": 0, "level": 1, "rep": 3.0, "ratings": 0, "venue": 0, "upg": upg, "tables": 0,
		"stock": {}, "dough": [{"style": "neapolitan", "n": 8, "q": 65, "d": 0, "speed": 0}],
		"menu_id": "classics", "next_menu": "", "offers": [], "cycle_start": 1, "off": {}, "price": 1,
		"staff": [], "cands": [], "last": {}, "sid": 1, "phase": "morning", "mute": false, "pizzas": 0, "earned": 0.0,
	}
	var start := {"flour00": 2000, "yeast": 50, "salt": 500, "tomato": 10, "mozz": 10, "basil": 5, "pepperoni": 4, "mushroom": 4}
	for id in start:
		s.stock[id] = [{"q": float(start[id]), "d": 1}]
	gen_offers()
	gen_cands()
	save_game()

func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(s))

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var d = JSON.parse_string(FileAccess.open(SAVE_PATH, FileAccess.READ).get_as_text())
	if typeof(d) != TYPE_DICTIONARY or not d.has("upg") or not d.has("dough"):
		return false
	s = d
	for k in Data.UPG:
		s.upg[k] = int(s.upg.get(k, 0))
	for k in ["day", "level", "venue", "tables", "price", "sid", "cycle_start", "ratings", "xp"]:
		s[k] = int(s[k])
	return true

# ---------- xp ----------
func xp_need(l: int) -> int:
	return int(round(100.0 * pow(l, 1.3) + 50))

func add_xp(n: float) -> int:
	s.xp += int(round(n))
	var ups := 0
	while s.xp >= xp_need(s.level):
		s.xp -= xp_need(s.level)
		s.level += 1
		ups += 1
	return ups

func unlocks_at(l: int) -> Array:
	var out := []
	for m in Data.MENUS:
		if int(m.lvl) == l and m.cost > 0: out.append(m.name + " menu")
	for k in Data.DOUGHS:
		if int(Data.DOUGHS[k].lvl) == l and l > 1: out.append(Data.DOUGHS[k].name + " dough")
	for v in Data.VENUES:
		if int(v.lvl) == l and v.cost > 0: out.append(v.name + " for sale")
	if l == 2: out.append("You can hire staff")
	return out

# ---------- shortcuts ----------
func tier(id: String) -> Dictionary:
	return Data.UPG[id].tiers[int(s.upg[id])]

func venue() -> Dictionary:
	return Data.VENUES[int(s.venue)]

func staff_of(role: String) -> Array:
	return s.staff.filter(func(x): return x.role == role)

func skill_of(role: String) -> float:
	var t := 0.0
	for x in staff_of(role): t += x.skill
	return t

# ---------- stock: dated lots, first in first out ----------
func stock(id: String) -> float:
	var t := 0.0
	for l in s.stock.get(id, []): t += l.q
	return t

func add_stock(id: String, q: float) -> void:
	if not s.stock.has(id): s.stock[id] = []
	var lots: Array = s.stock[id]
	if lots.size() > 0 and int(lots[-1].d) == s.day:
		lots[-1].q += q
	else:
		lots.append({"q": q, "d": s.day})

func take(id: String, q: float) -> void:
	var lots: Array = s.stock.get(id, [])
	while q > 0.000001 and lots.size() > 0:
		var u: float = min(lots[0].q, q)
		lots[0].q -= u
		q -= u
		if lots[0].q <= 0.000001: lots.pop_front()

## how much of an ingredient will be thrown out tonight
func expiring(id: String) -> float:
	var t := 0.0
	for l in s.stock.get(id, []):
		if s.day + 1 - l.d >= Data.ING[id].life: t += l.q
	return t

func dough_count() -> int:
	var t := 0
	for l in s.dough: t += int(l.n)
	return t

func store_used(store: String) -> float:
	var u := 0.0
	for id in Data.ING:
		var i = Data.ING[id]
		if i.store == store: u += stock(id) / i.pack * i.space
	if store == "fridge": u += dough_count() * 0.5
	return u

func store_cap(store: String) -> float:
	return tier(store).cap

func store_free(store: String) -> float:
	return store_cap(store) - store_used(store)

# ---------- dough: made today, ready tomorrow, dead after its window ----------
func dough_age(l: Dictionary, day: int = -1) -> int:
	return (s.day if day < 0 else day) - int(l.d)

func dough_window(l: Dictionary) -> Array:
	var to := 3 + int(tier("proofer").days)
	if l.speed > 0: return [1, to - 1]
	if l.speed < 0: return [2, to + 1]
	return [1, to]

func dough_usable(l: Dictionary, day: int = -1) -> bool:
	var a := dough_age(l, day)
	var w := dough_window(l)
	return a >= w[0] and a <= w[1]

func dough_ready(style: String, day: int = -1) -> int:
	var t := 0
	for l in s.dough:
		if l.style == style and dough_usable(l, day): t += int(l.n)
	return t

## [state, text]: state is proof / ok / peak / last
func dough_status(l: Dictionary) -> Array:
	var a := dough_age(l)
	var w := dough_window(l)
	if a < w[0]:
		return ["proof", "Proofing: ready tomorrow" if a + 1 >= w[0] else "Slow proof: ready in %d days" % (w[0] - a)]
	if a >= w[1]: return ["last", "Use today: overproofs tonight"]
	return ["ok", "Ready"] if a == w[0] else ["peak", "At its best"]

## take one ball of a style from the oldest usable tray; returns its quality or -1
func take_dough(style: String) -> float:
	var best = null
	for l in s.dough:
		if l.style == style and l.n > 0 and dough_usable(l) and (best == null or l.d < best.d): best = l
	if best == null: return -1.0
	best.n -= 1
	var a := dough_age(best)
	var w := dough_window(best)
	var adj := -6.0 if a >= w[1] else (4.0 if a > w[0] else 0.0)
	return clamp(best.q + adj, 0.0, 100.0)

## grams of each part for a given weight of flour
func dough_parts(style: String, flour_g: float) -> Dictionary:
	var d = Data.DOUGHS[style]
	var o := {}
	for p in Data.DOUGH_PARTS:
		o[p] = flour_g if p == "flour" else flour_g * d[p] / 100.0
	return o

## stock id for a dough part ("water" is free and has no stock id)
func part_ing(style: String, part: String) -> String:
	return Data.DOUGHS[style].flour if part == "flour" else part

func flour_per_ball(style: String) -> float:
	var p := dough_parts(style, 1000.0)
	var total := 0.0
	for k in p: total += p[k]
	return 1000.0 / (total / Data.DOUGHS[style].ball)

# ---------- menus ----------
func menu_now() -> Dictionary:
	return Data.MENU.get(s.menu_id, Data.MENU.classics)

func cycle_left() -> int:
	return Data.MENU_DAYS - (s.day - s.cycle_start)

func active_recipes() -> Array:
	var out := []
	for id in menu_now().items:
		if not s.off.get(id, false): out.append(Data.REC[id])
	return out

func tomorrow_recipes() -> Array:
	if cycle_left() <= 1:
		var m = Data.MENU[s.next_menu if s.next_menu != "" else "classics"]
		return m.items.map(func(id): return Data.REC[id])
	return active_recipes()

func recipe_ings(r: Dictionary) -> Array:
	return [r.sauce, "mozz"] + r.tops

func menu_stores(m: Dictionary) -> Array:
	var out := []
	for id in m.items:
		for i in recipe_ings(Data.REC[id]):
			if not out.has(Data.ING[i].store): out.append(Data.ING[i].store)
	return out

func menu_doughs(m: Dictionary) -> Array:
	var out := []
	for id in m.items:
		if not out.has(Data.REC[id].base): out.append(Data.REC[id].base)
	return out

func gen_offers() -> void:
	var pool := Data.MENUS.filter(func(m): return m.cost > 0 and m.id != s.menu_id and m.lvl <= s.level + 2)
	pool.sort_custom(func(a, b): return a.lvl > b.lvl)
	pool = pool.slice(0, 5)
	pool.shuffle()
	pool = pool.slice(0, 3)
	pool.sort_custom(func(a, b): return a.lvl < b.lvl)
	s.offers = pool.map(func(m): return m.id)

func rotate_menu() -> void:
	s.menu_id = s.next_menu if s.next_menu != "" else "classics"
	s.next_menu = ""
	s.cycle_start = s.day
	s.off = {}
	gen_offers()

# ---------- everything the upgrades and staff add up to ----------
func calc() -> Dictionary:
	var v := venue()
	var c := {"v": v}
	var oven := tier("oven")
	c.slots = int(oven.slots)
	c.oven_q = oven.q
	c.fornaio = staff_of("fornaio").size() > 0
	c.bake = oven.bake * (0.9 if c.fornaio else 1.0)
	c.batch = tier("mixer").batch
	c.knead = tier("mixer").knead
	c.manager = staff_of("manager").size() > 0
	c.prep_speed = 1.0 + tier("prep").speed + staff_of("prep").size() * 0.08 + (0.1 if c.manager else 0.0)
	c.prep_q = tier("prep").q
	c.brush = tier("prep").brush
	c.proof_q = tier("proofer").q
	c.roll_auto = tier("roller").auto
	c.turn = tier("dish").turn
	c.cost_mult = tier("supplier").mult
	c.sup_q = tier("supplier").q
	c.patience = 1.0 + tier("pos").pat + tier("comfort").pat
	c.queue_cap = 5 + staff_of("cashier").size() * 3 + int(s.upg.pos) * 2
	c.rep_mult = 0.4 + s.rep * 0.22
	var host := staff_of("host")
	var host_bonus: float = (0.06 + 0.02 * host[0].skill) if host.size() > 0 else 0.0
	c.traffic_mult = c.rep_mult * [1.2, 1.0, 0.82][s.price] * (1.0 + tier("sign").tr + tier("marketing").tr + tier("pos").tr + tier("comfort").tr + menu_now().buzz + host_bonus)
	c.customers = int(round(v.traffic * c.traffic_mult))
	c.tables = int(min(s.tables, v.tables))
	var dt := int(s.upg.drinks)
	if dt >= 3 and staff_of("bartender").is_empty(): dt = 2
	c.drinks = Data.UPG.drinks.tiers[dt].per * (1.0 + skill_of("bartender") * 0.06)
	c.delivery = int(round(staff_of("driver").size() * tier("delivery").per * c.rep_mult))
	c.tip = 1.0 + tier("furniture").tip + tier("ambience").tip + skill_of("server") * 0.03
	c.rep_bonus = tier("ambience").rep
	c.price_mult = [0.85, 1.0, 1.2][s.price]
	c.total = c.customers + c.delivery
	return c

func can_make(r: Dictionary) -> bool:
	if dough_ready(r.base) < 1: return false
	for i in recipe_ings(r):
		if stock(i) < 1: return false
	return true

func ing_price(id: String) -> float:
	return Data.ING[id].price * tier("supplier").mult

## buy n packs; returns "" or the reason it failed
func buy(id: String, n: int) -> String:
	var i = Data.ING[id]
	var cost := ing_price(id) * n
	if s.cash < cost: return "Not enough cash"
	if store_free(i.store) < i.space * n - 0.000001:
		return Data.STORE_NAME[i.store] + " is full" if store_cap(i.store) > 0 else "You need a freezer for that"
	s.cash -= cost
	add_stock(id, i.pack * n)
	return ""

## dough balls of each style still to make tonight for tomorrow
func dough_plan() -> Dictionary:
	var c := calc()
	var recs := tomorrow_recipes()
	var plan := {}
	if recs.is_empty(): return plan
	for r in recs:
		plan[r.base] = plan.get(r.base, 0.0) + c.total * 1.1 / recs.size()
	for st in plan:
		plan[st] = int(max(0, ceil(plan[st] + 1 - dough_ready(st, s.day + 1))))
	return plan

## what today's service and tonight's dough need, in base units
func par_stock() -> Dictionary:
	var c := calc()
	var recs := active_recipes()
	var need := {}
	var expd := int(ceil(c.total * 1.1)) + 1
	for r in recs:
		for i in recipe_ings(r):
			need[i] = need.get(i, 0.0) + float(expd) / recs.size()
	for k in need:
		need[k] = ceil(need[k] + (1 if recs.size() > 1 else 0))
	var plan := dough_plan()
	for st in plan:
		var parts := dough_parts(st, plan[st] * flour_per_ball(st))
		for p in Data.DOUGH_PARTS:
			if p != "water" and parts[p] > 0:
				var id := part_ing(st, p)
				need[id] = need.get(id, 0.0) + parts[p] * 1.05
	return {"need": need, "exp": expd}

func packs_short(id: String, need: float) -> int:
	return int(max(0, ceil((need - stock(id)) / Data.ING[id].pack - 0.000001)))

func quick_order() -> Dictionary:
	var need: Dictionary = par_stock().need
	var spent := 0.0
	var short := ""
	for id in need:
		for n in range(packs_short(id, need[id])):
			var p := ing_price(id)
			var err := buy(id, 1)
			if err != "":
				short = err
				break
			spent += p
	return {"spent": spent, "short": short}

func quick_order_cost() -> float:
	var need: Dictionary = par_stock().need
	var t := 0.0
	for id in need: t += packs_short(id, need[id]) * ing_price(id)
	return t

## put a tray of dough in the fridge; returns how many balls fitted
func add_dough(style: String, n: int, q: float, speed: int = 0) -> int:
	n = int(min(n, floor(store_free("fridge") / 0.5)))
	if n > 0:
		s.dough.append({"style": style, "n": n, "q": int(round(q)), "d": s.day, "speed": speed})
	return n

## prep cooks make tomorrow's dough at close
func auto_dough() -> int:
	var cooks := staff_of("prep")
	if cooks.is_empty(): return 0
	var plan := dough_plan()
	var sk := skill_of("prep") / cooks.size()
	var made := 0
	for st in plan:
		var balls: int = plan[st]
		if balls <= 0: continue
		var per := dough_parts(st, flour_per_ball(st))
		for p in Data.DOUGH_PARTS:
			if p != "water" and per[p] > 0: balls = int(min(balls, floor(stock(part_ing(st, p)) / per[p])))
		if balls <= 0: continue
		for p in Data.DOUGH_PARTS:
			if p != "water" and per[p] > 0: take(part_ing(st, p), per[p] * balls)
		made += add_dough(st, balls, clamp(52 + sk * 7 + tier("proofer").q, 0, 100), 0)
	return made

## end of the night: bin what is out of date, age the dough, rotate the menu
func nightfall() -> Dictionary:
	var out := {"expired": 0.0, "dough_lost": 0, "rotated": false}
	s.day += 1
	for id in s.stock:
		var keep := []
		for l in s.stock[id]:
			if s.day - l.d >= Data.ING[id].life: out.expired += l.q / Data.ING[id].pack
			else: keep.append(l)
		s.stock[id] = keep
	out.expired = int(round(out.expired))
	var keep_d := []
	for l in s.dough:
		if l.n <= 0: continue
		if dough_age(l) > dough_window(l)[1]: out.dough_lost += int(l.n)
		else: keep_d.append(l)
	s.dough = keep_d
	if cycle_left() <= 0:
		rotate_menu()
		out.rotated = true
	return out

# ---------- upgrades ----------
func next_tier(id: String):
	var t: Array = Data.UPG[id].tiers
	return t[int(s.upg[id]) + 1] if int(s.upg[id]) + 1 < t.size() else null

func buy_upgrade(id: String) -> bool:
	var t = next_tier(id)
	if t == null or s.venue < t.v or s.cash < t.c: return false
	s.cash -= t.c
	s.upg[id] += 1
	return true

func table_cost() -> int:
	return 120 + 40 * int(s.tables)

# ---------- staff ----------
func role_open(k: String) -> bool:
	var r = Data.ROLES[k]
	return s.venue >= r.v and s.level >= r.lvl

func gen_cands() -> void:
	s.cands = []
	for k in Data.ROLES:
		if not role_open(k): continue
		for i in 2:
			var skill := int(clamp(1 + floor(randf() * (2.2 + s.venue * 0.6)), 1, 4))
			s.cands.append({"id": s.sid, "role": k, "name": Data.NAMES.pick_random(), "skill": skill,
				"wage": int(round(Data.ROLES[k].wage * (0.7 + 0.15 * skill) * randf_range(0.92, 1.08)))})
			s.sid += 1

func area_count(area: String) -> int:
	return s.staff.filter(func(x): return Data.ROLES[x.role].area == area).size()

func hire_block(cd: Dictionary) -> String:
	var r = Data.ROLES[cd.role]
	if area_count(r.area) >= venue()[r.area]: return ("Kitchen" if r.area == "boh" else "Front of house") + " is full here"
	if r.max > 0 and staff_of(cd.role).size() >= r.max: return "You already have one"
	if r.needs != "" and int(s.upg[r.needs]) == 0: return "Buy a " + Data.UPG[r.needs].name + " upgrade first"
	return ""

func train_cost(x: Dictionary) -> int:
	return int(round(120.0 * x.skill * Data.ROLES[x.role].wage / 40.0))

func wages() -> float:
	var t := 0.0
	for x in s.staff: t += x.wage
	return t

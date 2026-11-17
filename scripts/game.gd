extends Node
## Autoload `Game`: the save file (`s`) and the rules of the business around it:
## the calendar, money and XP, the venue and its pitch, menus, upgrades, staff, and the nightly roll-over.
## Stock lives in `Stock`, buying lives in `Market`, a day's trading lives in `ServiceScreen`.

const SAVE_PATH := "user://crust_empire_v3.json"
var s := {}

func _ready() -> void:
	if not load_game():
		new_game()

# ---------- save ----------
func new_book() -> Dictionary:
	return {"used": {}, "spec": {}, "waste": {}, "cost_used": 0.0, "cost_spec": 0.0, "cost_waste": 0.0, "sold": 0, "binned": 0, "sales": 0.0}

func new_game() -> void:
	var upg := {}
	for k in Data.UPG: upg[k] = 0
	s = {
		"day": 1, "phase": "morning", "cash": 200.0, "xp": 0, "level": 1, "rep": 3.0, "ratings": 0,
		"venue": 0, "pitch": 0, "upg": upg, "tables": 0,
		"stock": {}, "dough": [], "baskets": {}, "orders": [], "payables": [], "house_grade": 2,
		"book": new_book(), "books": [],
		"menu_id": "classics", "next_menu": "", "offers": [], "cycle_start": 1, "off": {}, "price": 1,
		"staff": [], "cands": [], "last": {}, "sid": 1, "oid": 1, "mute": false, "pizzas": 0, "earned": 0.0,
	}
	# what the last owner left in the van
	for e in [["flour00", 2000, 2], ["yeast", 42, 2], ["salt", 750, 1], ["tomato", 800, 2], ["mozz", 1000, 2],
			["basil", 30, 2], ["pepperoni", 500, 2], ["mushroom", 250, 2], ["box", 25, 2]]:
		Stock.add(e[0], e[1], e[2], Data.ING[e[0]].g[e[2]].price)
	s.dough.append({"style": "neapolitan", "n": 8, "q": 65, "d": 0, "speed": 0, "g": 2.0, "c": 0.25})
	gen_offers()
	gen_cands()
	save_game()

func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(s))

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH): return false
	var d = JSON.parse_string(FileAccess.open(SAVE_PATH, FileAccess.READ).get_as_text())
	if typeof(d) != TYPE_DICTIONARY or not d.has("upg") or not d.has("book"): return false
	s = d
	for k in Data.UPG: s.upg[k] = int(s.upg.get(k, 0))
	for k in ["day", "level", "venue", "pitch", "tables", "price", "sid", "oid", "cycle_start", "ratings", "xp", "house_grade"]:
		s[k] = int(s[k])
	return true

# ---------- calendar ----------
func weekday(day: int = -1) -> int:
	return ((s.day if day < 0 else day) - 1) % 7

func season(day: int = -1) -> int:
	return (((s.day if day < 0 else day) - 1) / 28) % 4

func date_text(day: int = -1) -> String:
	var d: int = s.day if day < 0 else day
	return "%s · day %d · %s" % [Data.DAY_NAME[weekday(d)], d, Data.SEASON_NAME[season(d)]]

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
	for sp in Data.SUPPLIERS:
		if int(sp.lvl) == l and l > 1: out.append("%s (%s)" % [sp.name, sp.kind.to_lower()])
	for g in range(1, 6):
		if int(Data.GRADE_LVL[g]) == l and l > 1: out.append("%s grade ingredients" % Data.GRADES[g])
	for m in Data.MENUS:
		if int(m.lvl) == l and m.cost > 0: out.append(m.name + " menu")
	for k in Data.DOUGHS:
		if Data.DOUGHS[k].lvl == l and l > 1: out.append(Data.DOUGHS[k].name + " dough")
	for v in Data.VENUES:
		if int(v.lvl) == l and v.cost > 0: out.append(v.name + " for sale")
	if l == 2: out.append("you can hire staff")
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

# ---------- where the van trades ----------
## the van's pitch today, or null for premises that do not move
func pitch():
	var v := venue()
	if not v.has("pitches"): return null
	return v.pitches[int(clamp(s.pitch, 0, v.pitches.size() - 1))]

func pitch_open(p: Dictionary, day: int = -1) -> bool:
	return s.level >= p.lvl and p.days[weekday(day)] > 0

## how busy a given day is compared with an average one
func day_factor(day: int = -1) -> float:
	var p = pitch()
	if p != null:
		var f: float = p.days[weekday(day)]
		if p.has("season"): f *= p.season[season(day)]
		return f
	return Data.WEEK[weekday(day)]

func rent() -> float:
	var p = pitch()
	return p.fee if p != null else venue().rent

func utilities() -> float:
	return tier("oven").util + int(s.upg.fridge) * 1.5 + int(s.upg.freezer) * 2.0

func wages() -> float:
	var t := 0.0
	for x in s.staff: t += x.wage
	return t

# ---------- menus ----------
func menu_now() -> Dictionary:
	return Data.MENU.get(s.menu_id, Data.MENU.classics)

func menu_on(day: int) -> Dictionary:
	if day - s.cycle_start >= Data.MENU_DAYS:
		return Data.MENU[s.next_menu if s.next_menu != "" else "classics"]
	return menu_now()

func cycle_left() -> int:
	return Data.MENU_DAYS - (s.day - s.cycle_start)

## the pizzas on sale on a given day
func recipes_on(day: int = -1) -> Array:
	var d: int = s.day if day < 0 else day
	var current: bool = d - s.cycle_start < Data.MENU_DAYS
	var out := []
	for id in menu_on(d).items:
		if current and s.off.get(id, false): continue
		out.append(Data.REC[id])
	return out

func active_recipes() -> Array:
	return recipes_on(s.day)

func menu_stores(m: Dictionary) -> Array:
	var out := []
	for id in m.items:
		for i in Data.REC[id].spec:
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

## can this pizza be made right now: a dough ball of the right style and most of each ingredient
func can_make(r: Dictionary) -> bool:
	if Stock.dough_ready(r.base) < 1: return false
	for i in r.spec:
		if Stock.have(i) < r.spec[i] * 0.7: return false
	return true

# ---------- everything the upgrades and staff add up to ----------
func traffic_mult() -> float:
	var host := staff_of("host")
	var host_bonus: float = (0.06 + 0.02 * host[0].skill) if host.size() > 0 else 0.0
	return (0.4 + s.rep * 0.22) * [1.2, 1.0, 0.82][s.price] * (1.0 + tier("sign").tr + tier("marketing").tr + tier("pos").tr + tier("comfort").tr + menu_now().buzz + host_bonus)

func delivery_covers(day: int = -1) -> int:
	return int(round(staff_of("driver").size() * tier("delivery").per * (0.4 + s.rep * 0.22) * Data.WEEK[weekday(day)]))

## pizzas you can expect to sell on a given day
func covers(day: int = -1) -> int:
	return int(round(venue().traffic * traffic_mult() * day_factor(day))) + delivery_covers(day)

func calc() -> Dictionary:
	var v := venue()
	var c := {"v": v}
	var oven := tier("oven")
	c.oven = oven
	c.oven_type = oven.type
	c.slots = int(oven.slots)
	c.oven_q = oven.q
	c.fornaio = not staff_of("fornaio").is_empty()
	c.bake = oven.bake * (0.9 if c.fornaio else 1.0)
	c.batch = tier("mixer").batch
	c.knead = tier("mixer").knead
	c.manager = not staff_of("manager").is_empty()
	c.prep_speed = 1.0 + tier("prep").speed + staff_of("prep").size() * 0.08 + (0.1 if c.manager else 0.0)
	c.prep_q = tier("prep").q
	c.brush = tier("prep").brush
	c.proof_q = tier("proofer").q
	c.roll_auto = tier("roller").auto
	c.turn = tier("dish").turn
	c.patience = 1.0 + tier("pos").pat + tier("comfort").pat
	c.queue_cap = 5 + staff_of("cashier").size() * 3 + int(s.upg.pos) * 2
	c.rep_mult = 0.4 + s.rep * 0.22
	c.day_factor = day_factor()
	c.delivery = delivery_covers()
	c.customers = int(round(v.traffic * traffic_mult() * c.day_factor))
	c.total = c.customers + c.delivery
	c.tables = int(min(s.tables, v.tables))
	var dt := int(s.upg.drinks)
	if dt >= 3 and staff_of("bartender").is_empty(): dt = 2
	c.drinks = Data.UPG.drinks.tiers[dt].per * (1.0 + skill_of("bartender") * 0.06)
	var p = pitch()
	c.tip = 1.0 + tier("furniture").tip + tier("ambience").tip + skill_of("server") * 0.03 + (p.get("tip", 0.0) if p != null else 0.0)
	c.rep_bonus = tier("ambience").rep
	c.price_mult = [0.85, 1.0, 1.2][s.price]
	var hc := staff_of("headchef")
	c.chef = (4.0 + hc[0].skill * 2.0) if hc.size() > 0 else 0.0
	return c

# ---------- dough planning ----------
## balls of each style to make on `make_day` so the day after is covered
func dough_plan(make_day: int = -1) -> Dictionary:
	var d: int = s.day if make_day < 0 else make_day
	var recs := recipes_on(d + 1)
	var plan := {}
	if recs.is_empty(): return plan
	var cov := covers(d + 1)
	for r in recs: plan[r.base] = plan.get(r.base, 0.0) + cov * 1.1 / recs.size()
	for st in plan:
		plan[st] = int(max(0, ceil(plan[st] + 1 - (_dough_left_tomorrow(st) if d == s.day else 0.0))))
	return plan

## dough of a style that will still be usable tomorrow once today's service has taken its share
func _dough_left_tomorrow(style: String) -> float:
	var fresh := 0.0      # made today: untouched until tomorrow
	var keeps := 0.0      # older, still good tomorrow
	var last := 0.0       # older, overproofs tonight (used first)
	for l in s.dough:
		if l.style != style: continue
		if int(l.d) == s.day:
			if Stock.dough_usable(l, s.day + 1): fresh += l.n
		elif Stock.dough_usable(l, s.day + 1): keeps += l.n
		elif Stock.dough_usable(l): last += l.n
	var use := 0.0
	if s.phase == "morning":
		var today := recipes_on(s.day)
		for r in today:
			if r.base == style: use += float(covers(s.day)) / today.size()
	return fresh + max(0.0, keeps - max(0.0, use - last))

## prep cooks make tomorrow's dough at close. Returns balls made.
func auto_dough() -> int:
	var cooks := staff_of("prep")
	if cooks.is_empty(): return 0
	var plan := dough_plan()
	var sk := skill_of("prep") / cooks.size()
	var made := 0
	for st in plan:
		var balls: int = plan[st]
		if balls <= 0: continue
		var per := Stock.dough_parts(st, Stock.flour_per_ball(st))
		for ing in per:
			if ing != "water": balls = int(min(balls, floor(Stock.have(ing) / per[ing])))
		if balls <= 0: continue
		var cost := 0.0
		var gw := 0.0
		var w := 0.0
		for ing in per:
			if ing == "water": continue
			var t := Stock.take(ing, per[ing] * balls)
			cost += t.cost
			gw += t.g * t.got
			w += t.got
		made += Stock.add_dough(st, balls, clamp(52 + sk * 7 + tier("proofer").q, 0, 100), 0, gw / w if w > 0 else 2.0, cost / balls)
	return made

# ---------- the night ----------
func close_book() -> void:
	s.book.day = s.day
	s.books.append(s.book)
	while s.books.size() > 14: s.books.pop_front()
	s.book = new_book()

## bin what is out of date, close the books, move to tomorrow, take deliveries, pay invoices
func nightfall() -> Dictionary:
	var out := {"binned": Stock.night(), "dough_lost": Stock.dough_night(), "rotated": false, "pitch_reset": false}
	close_book()
	s.day += 1
	s.phase = "morning"
	if cycle_left() <= 0:
		rotate_menu()
		out.rotated = true
	var p = pitch()
	if p != null and not pitch_open(p):
		s.pitch = 0
		out.pitch_reset = true
	out.delivered = Market.deliver()
	out.paid = Market.pay_due()
	gen_cands()
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

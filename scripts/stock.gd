extends Node
## Autoload `Stock`: everything physical you own, and the kitchen's books.
##
## Ingredients are held as lots: {q amount (g, ml or items), x day it goes out of date, g quality 1-5, c cost per unit}.
## Lots are used oldest-date-first. Dough is held as trays: {style, n balls, q craft quality, d day made, speed, g, c cost per ball}.
## The books record, for every pizza sold, what it used against what its recipe card says it should have used.

# ---------- ingredients ----------
func lots(id: String) -> Array:
	return Game.s.stock.get(id, [])

## how much is in stock; with on_day, only what will still be in date that day
func have(id: String, on_day: int = -1) -> float:
	var t := 0.0
	for l in lots(id):
		if on_day < 0 or l.x > on_day: t += l.q
	return t

func add(id: String, q: float, grade: int, unit_cost: float, life: int = -1) -> void:
	if q <= 0: return
	var it: Dictionary = Data.ING[id]
	var lf: int = life if life >= 0 else (int(it.g[grade].life) if it.g.has(grade) else int(it.life))
	var x: int = Game.s.day + lf
	if not Game.s.stock.has(id): Game.s.stock[id] = []
	var ls: Array = Game.s.stock[id]
	for l in ls:
		if int(l.x) == x and int(l.g) == grade and abs(l.c - unit_cost) < 0.0000001:
			l.q += q
			return
	ls.append({"q": q, "x": x, "g": grade, "c": unit_cost})
	ls.sort_custom(func(a, b): return a.x < b.x)

## take up to q, oldest date first. Returns {got, g (average quality), cost}
func take(id: String, q: float) -> Dictionary:
	var out := {"got": 0.0, "g": 0.0, "cost": 0.0}
	var ls: Array = lots(id)
	var gw := 0.0
	while q > 0.00001 and ls.size() > 0:
		var u: float = min(ls[0].q, q)
		ls[0].q -= u
		q -= u
		out.got += u
		gw += u * ls[0].g
		out.cost += u * ls[0].c
		if ls[0].q <= 0.00001: ls.pop_front()
	if out.got > 0: out.g = gw / out.got
	return out

func avg_grade(id: String) -> float:
	var t := 0.0
	var w := 0.0
	for l in lots(id):
		t += l.q
		w += l.q * l.g
	return w / t if t > 0 else 0.0

func avg_cost(id: String) -> float:
	var t := 0.0
	var w := 0.0
	for l in lots(id):
		t += l.q
		w += l.q * l.c
	return w / t if t > 0 else 0.0

## how much goes in the bin tonight
func expiring(id: String) -> float:
	var t := 0.0
	for l in lots(id):
		if l.x <= Game.s.day + 1: t += l.q
	return t

func value(id: String) -> float:
	var t := 0.0
	for l in lots(id): t += l.q * l.c
	return t

## throw an ingredient away (counts as waste)
func bin(id: String) -> void:
	for l in lots(id): log_waste(id, l.q, l.q * l.c)
	Game.s.stock[id] = []

# ---------- storage ----------
func space_of(id: String, q: float) -> float:
	return q * Data.ING[id].space

func store_used(store: String) -> float:
	var u := 0.0
	for id in Game.s.stock:
		if Data.ING[id].store == store: u += have(id) * Data.ING[id].space
	if store == "fridge": u += dough_count() * 0.5
	return u

func store_cap(store: String) -> float:
	return Game.tier(store).cap

func store_free(store: String) -> float:
	return store_cap(store) - store_used(store)

# ---------- dough ----------
func dough_count() -> int:
	var t := 0
	for l in Game.s.dough: t += int(l.n)
	return t

func dough_age(l: Dictionary, day: int = -1) -> int:
	return (Game.s.day if day < 0 else day) - int(l.d)

## [first usable age, last usable age] in days
func dough_window(l: Dictionary) -> Array:
	var to := 3 + int(Game.tier("proofer").days)
	if l.speed > 0: return [1, to - 1]
	if l.speed < 0: return [2, to + 1]
	return [1, to]

func dough_usable(l: Dictionary, day: int = -1) -> bool:
	var a := dough_age(l, day)
	var w := dough_window(l)
	return a >= w[0] and a <= w[1]

func dough_ready(style: String, day: int = -1) -> int:
	var t := 0
	for l in Game.s.dough:
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

## take one ball from the oldest usable tray. Returns {} if there is none, else {q, g, cost}
func take_dough(style: String) -> Dictionary:
	var best = null
	for l in Game.s.dough:
		if l.style == style and l.n > 0 and dough_usable(l) and (best == null or l.d < best.d): best = l
	if best == null: return {}
	best.n -= 1
	var a := dough_age(best)
	var w := dough_window(best)
	var adj := -6.0 if a >= w[1] else (4.0 if a > w[0] else 0.0)
	return {"q": clamp(best.q + adj, 0.0, 100.0), "g": float(best.get("g", 2.0)), "cost": float(best.get("c", 0.0))}

## put a tray in the fridge; returns how many balls fitted
func add_dough(style: String, n: int, q: float, speed: int, grade: float, ball_cost: float) -> int:
	n = int(min(n, floor(store_free("fridge") / 0.5)))
	if n > 0:
		Game.s.dough.append({"style": style, "n": n, "q": int(round(q)), "d": Game.s.day, "speed": speed, "g": grade, "c": ball_cost})
	return n

## the weight of every part for a given weight of flour: {ingredient id or "water": grams}
func dough_parts(style: String, flour_g: float) -> Dictionary:
	var o := {}
	for p in Data.DOUGHS[style].parts: o[p.ing] = flour_g * p.pct / 100.0
	return o

func flour_per_ball(style: String) -> float:
	var total := 0.0
	for p in Data.DOUGHS[style].parts: total += p.pct
	return Data.DOUGHS[style].ball * 100.0 / total

# ---------- night ----------
## bin everything that will be out of date tomorrow. Returns [{id, q, cost}]
func night() -> Array:
	var binned := []
	for id in Game.s.stock:
		var keep := []
		for l in Game.s.stock[id]:
			if l.x <= Game.s.day + 1:
				binned.append({"id": id, "q": l.q, "cost": l.q * l.c})
				log_waste(id, l.q, l.q * l.c)
			else:
				keep.append(l)
		Game.s.stock[id] = keep
	return binned

## bin dough that will have overproofed by tomorrow. Returns balls lost.
func dough_night() -> int:
	var lost := 0
	var keep := []
	for l in Game.s.dough:
		if l.n <= 0: continue
		if dough_age(l, Game.s.day + 1) > dough_window(l)[1]:
			lost += int(l.n)
			log_waste("dough:" + l.style, l.n, l.n * float(l.get("c", 0.0)))
		else:
			keep.append(l)
	Game.s.dough = keep
	return lost

# ---------- the books ----------
## a pizza was sold: what it used, and what the recipe card says it should have
func log_sale(use: Dictionary, spec: Dictionary, cost: float, spec_cost: float) -> void:
	var b: Dictionary = Game.s.book
	for id in use: b.used[id] = b.used.get(id, 0.0) + use[id]
	for id in spec: b.spec[id] = b.spec.get(id, 0.0) + spec[id]
	b.cost_used += cost
	b.cost_spec += spec_cost
	b.sold += 1

func log_waste(id: String, q: float, cost: float) -> void:
	var b: Dictionary = Game.s.book
	b.waste[id] = b.waste.get(id, 0.0) + q
	b.cost_waste += cost

## a made (or part-made) pizza went in the bin
func log_binned(use: Dictionary, cost: float) -> void:
	var b: Dictionary = Game.s.book
	for id in use: b.waste[id] = b.waste.get(id, 0.0) + use[id]
	b.cost_waste += cost
	b.binned += 1

func label(id: String) -> String:
	if id.begins_with("dough:"): return Data.DOUGHS[id.substr(6)].name + " dough"
	return Data.ING[id].name

func amount(id: String, q: float) -> String:
	if id.begins_with("dough:"): return "%d ball%s" % [int(round(q)), "" if int(round(q)) == 1 else "s"]
	return Data.qty(id, q)

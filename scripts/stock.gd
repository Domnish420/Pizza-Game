extends Node
## Autoload `Stock`: everything physical you own, how it is stored, and the kitchen's books.
##
## Ingredients are held as lots: {q amount (g, ml or items), x day it goes out of date (can be fractional),
## g quality 1-5, c cost per unit, f true if it was stacked in front of older stock instead of being rotated}.
## Lots are used in shelf order: whatever is at the front first (f), then oldest date first. Rotating the
## stores clears the f flags so the oldest stock comes forward again.
##
## Prepped food (grated cheese, sliced mushrooms, the day's sauce) goes into 2 and 4 litre tubs, one lot per tub,
## each with a day-dot label (the day it was made) and a use-by (Game.s.prepped). The tubs live in the fridge.
## The pizza counter has a rail of gastronorm pans (Game.s.rail), filled from the tubs (or straight from stock for
## things that need no prep, like sliced pepperoni). Every topping on a pizza comes off the rail.
## Emptied tubs go to the wash-up (Game.s.washup) and are clean stock again once washed.
##
## Deliveries arrive at the back door (Game.s.dock) and are not usable until they are put away.
##
## The fridge and dry store each have a vent setting (0 closed .. 4 wide open). How much airflow they need
## depends on how full they are. Too little: the fridge runs warm and the dry store damp, and food spoils early.
## Too much: the fridge freezes delicate food, and the dry store lets bugs and mice in.

const VENT_NAME := ["Closed", "Low", "Medium", "High", "Wide open"]
const DOUGH_LITRES := 0.8      # a dough ball in its tray

# ---------- ingredients ----------
func lots(id: String) -> Array:
	return Game.s.stock.get(id, [])

func _sort(ls: Array) -> void:
	ls.sort_custom(func(a, b):
		var fa: bool = a.get("f", false)
		var fb: bool = b.get("f", false)
		if fa != fb: return fa
		return a.x < b.x)

## how much is in stock; with on_day, only what will still be in date that day
func have(id: String, on_day: int = -1) -> float:
	var t := 0.0
	for l in lots(id):
		if on_day < 0 or l.x > on_day: t += l.q
	return t

## add a lot that goes out of date on day x (default: today + its shelf life)
func add(id: String, q: float, grade: int, unit_cost: float, x: float = -1.0, front: bool = false) -> void:
	if q <= 0: return
	var it: Dictionary = Data.ING[id]
	if x < 0: x = Game.s.day + (int(it.g[grade].life) if it.g.has(grade) else int(it.life))
	if not Game.s.stock.has(id): Game.s.stock[id] = []
	var ls: Array = Game.s.stock[id]
	for l in ls:
		if abs(l.x - x) < 0.01 and int(l.g) == grade and abs(l.c - unit_cost) < 0.0000001 and l.get("f", false) == front:
			l.q += q
			return
	ls.append({"q": q, "x": x, "g": grade, "c": unit_cost, "f": front})
	_sort(ls)

## take up to q in shelf order. Returns {got, g (average quality), cost, x (earliest date taken)}
func take(id: String, q: float) -> Dictionary:
	return _take_from(lots(id), q)

func _take_from(ls: Array, q: float) -> Dictionary:
	var out := {"got": 0.0, "g": 0.0, "cost": 0.0, "x": 99999.0}
	var gw := 0.0
	while q > 0.00001 and ls.size() > 0:
		var u: float = min(ls[0].q, q)
		ls[0].q -= u
		q -= u
		out.got += u
		gw += u * ls[0].g
		out.cost += u * ls[0].c
		out.x = min(out.x, ls[0].x)
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
	for l in lots(id): log_waste(id, l.q, l.q * l.c, "binned by hand")
	Game.s.stock[id] = []

# ---------- rotation ----------
## stock stacked in front of older stock of the same thing: [{id, front, behind}] (amounts)
func rotation_problems() -> Array:
	var out := []
	for id in Game.s.stock:
		var newest_front := -1.0
		var front := 0.0
		for l in lots(id):
			if l.get("f", false):
				front += l.q
				newest_front = max(newest_front, l.x)
		if front <= 0: continue
		var behind := 0.0
		for l in lots(id):
			if not l.get("f", false) and l.x < newest_front: behind += l.q
		if behind > 0: out.append({"id": id, "front": front, "behind": behind})
	return out

## minutes it takes to rotate everything that needs it
func rotate_minutes() -> float:
	var kg := 0.0
	for p in rotation_problems(): kg += _kg(p.id, p.front + p.behind)
	return 0.0 if kg <= 0 else ceil(4.0 + kg * 0.4)

func rotate_all() -> void:
	for id in Game.s.stock:
		for l in lots(id): l.f = false
		_sort(lots(id))

## rough weight in kg, for working out how long handling takes
func _kg(id: String, q: float) -> float:
	var u: String = Data.ING[id].unit
	return q / 1000.0 if u == "g" or u == "ml" else q * 0.2

# ---------- prepped food in tubs ----------
const TUBS := [4, 2]                       # litres, biggest first
const DAY_DOT := ["Blue", "Yellow", "Red", "Green", "Brown", "Orange", "Black"]   # Monday .. Sunday
const DAY_DOT_COL := ["2f6fd0", "f2c81b", "d23a2a", "2e9a46", "7a4b2a", "f08a1c", "202020"]

func prepped_lots(id: String) -> Array:
	if not Game.s.prepped.has(id): Game.s.prepped[id] = []
	return Game.s.prepped[id]

## grams of prepped food in tubs; with on_day, only what is still in date that day
func prepped(id: String, on_day: int = -1) -> float:
	var t := 0.0
	for l in Game.s.prepped.get(id, []):
		if on_day < 0 or l.x > on_day: t += l.q
	return t

func tub_count(id: String) -> int:
	return Game.s.prepped.get(id, []).size()

## litres one kilo of this takes once it is prepped (or as it comes, for things that need no prep)
func line_vol(id: String) -> float:
	var p = Data.ING[id].prep
	return float(p.vol) if p != null else float(Data.ING[id].litres) * 0.9

func clean_tubs(size: int) -> int:
	return int(have("tub%d" % size))

func tub_litres() -> float:
	var t := 0.0
	for sz in TUBS: t += clean_tubs(sz) * sz
	return t

## the most raw stock that can be prepped into the clean tubs there are
func max_prep_raw(id: String) -> float:
	var p = Data.ING[id].prep
	return tub_litres() / float(p.vol) * 1000.0 / float(p.yield)

## minutes to prep raw_g of an ingredient. mult < 1 is faster (better kit, skilled cook)
func prep_minutes(id: String, raw_g: float, mult: float = 1.0) -> float:
	var p = Data.ING[id].prep
	if p == null: return 0.0
	return max(1.0, raw_g / 1000.0 * float(p.min_kg) * mult * Equip.prep_mult(id))

## prep raw_g of raw stock into tubs. quality 0..1 is how well it was done: it sets the yield and how good it looks.
## Returns {raw, made, tubs: [sizes used], short: true if there were not enough clean tubs}
func prep(id: String, raw_g: float, quality: float = 0.8) -> Dictionary:
	var p = Data.ING[id].prep
	var yld: float = float(p.yield) * (0.9 + 0.1 * clamp(quality, 0.0, 1.0))
	var cap_raw: float = tub_litres() / float(p.vol) * 1000.0 / yld
	var short: bool = raw_g > cap_raw + 1.0
	var block := Equip.prep_block(id)
	if block != "": return {"raw": 0.0, "made": 0.0, "tubs": [], "short": false, "block": block, "unlabelled": 0}
	var t := take(id, min(raw_g, cap_raw))
	var out := {"raw": t.got, "made": 0.0, "tubs": [], "short": short, "block": "", "unlabelled": 0}
	if t.got <= 0: return out
	var made: float = t.got * yld
	out.made = made
	var litres: float = made / 1000.0 * float(p.vol)
	var x: float = min(t.x, float(Game.s.day + int(p.life)))
	var unit_c: float = t.cost / made
	var left := made
	while left > 0.5:
		var size := 4 if (litres > 2.0 and clean_tubs(4) > 0) or clean_tubs(2) == 0 else 2
		if clean_tubs(size) == 0: break
		take("tub%d" % size, 1)
		var fit: float = min(left, size / float(p.vol) * 1000.0)
		var lab := Equip.label_tub()
		if not lab: out.unlabelled += 1
		prepped_lots(id).append({"q": fit, "x": x, "g": t.g, "c": unit_c, "size": size, "made": Game.s.day, "pq": quality, "lab": lab})
		out.tubs.append(size)
		left -= fit
		litres -= fit / 1000.0 * float(p.vol)
	prepped_lots(id).sort_custom(func(a, b): return a.x < b.x)
	if t.got - made > 0.5: log_trim(id, t.got - made)
	return out

# ---------- the rail of gastro pans on the counter ----------
## the pans on the counter: as many as the counter holds and you own gastronorm pans for (Equip.rail_size())
func rail() -> Array:
	var n: int = Equip.rail_size()
	var r: Array = Game.s.rail
	while r.size() < n: r.append({"ing": "", "q": 0.0, "x": 0.0, "g": 2.0, "c": 0.0, "pq": 0.8})
	if r.size() > n: _shrink_rail(n)
	return r

## fewer pans than slots (a new counter that takes a different size of pan): what was in the extra pans goes back
func _shrink_rail(n: int) -> void:
	var r: Array = Game.s.rail
	while r.size() > n:
		var pan: Dictionary = r.pop_back()
		if pan.ing == "" or pan.q <= 0.5: continue
		if Data.needs_prep(pan.ing): prepped_lots(pan.ing).append({"q": pan.q, "x": pan.x, "g": pan.g, "c": pan.c, "size": 4, "made": Game.s.day, "pq": pan.get("pq", 0.8), "lab": true})
		else: add(pan.ing, pan.q, int(round(pan.g)), pan.c, pan.x)

func rail_chilled() -> bool:
	return bool(Game.tier("prep").chilled)

## how many grams of this one pan holds
func pan_cap(id: String) -> float:
	return float(Game.tier("prep").pan) / line_vol(id) * 1000.0

func rail_slot(id: String) -> int:
	var r := rail()
	for i in r.size():
		if r[i].ing == id: return i
	return -1

func rail_have(id: String) -> float:
	var t := 0.0
	for pan in rail():
		if pan.ing == id: t += pan.q
	return t

## what can go on a pizza right now: whatever is in the pans on the rail
func avail(id: String) -> float:
	return rail_have(id)

## how well the food in a pan was prepped (0..1), for how the pizza looks
func rail_quality(id: String) -> float:
	var s := rail_slot(id)
	return float(rail()[s].get("pq", 0.8)) if s >= 0 else 0.8

## take something off the rail to put on a pizza
func take_use(id: String, q: float) -> Dictionary:
	var out := {"got": 0.0, "g": 0.0, "cost": 0.0, "x": 99999.0}
	for pan in rail():
		if pan.ing != id or q <= 0.00001: continue
		var u: float = min(pan.q, q)
		pan.q -= u
		q -= u
		out.g = (out.g * out.got + pan.g * u) / max(out.got + u, 0.0001)
		out.got += u
		out.cost += u * pan.c
		out.x = min(out.x, pan.x)
	return out

## everything there is of it: on the rail, in tubs, and raw stock as what it would make once prepped
func potential(id: String) -> float:
	var y: float = float(Data.ING[id].prep.yield) if Data.needs_prep(id) else 1.0
	return rail_have(id) + prepped(id) + have(id) * y

## what could fill a pan right now (tubs for prepped food, the stores for the rest)
func refill_source(id: String) -> float:
	return prepped(id) if Data.needs_prep(id) else have(id)

## fill pan i from tubs or stock. Returns {grams, minutes, tubs_emptied}
func refill(i: int) -> Dictionary:
	var pan: Dictionary = rail()[i]
	var out := {"grams": 0.0, "minutes": 1.0, "tubs_emptied": 0}
	var id: String = pan.ing
	if id == "": return out
	var room: float = pan_cap(id) - pan.q
	if room <= 0.5: return out
	var got := {}
	if Data.needs_prep(id):
		got = {"got": 0.0, "g": 0.0, "cost": 0.0, "x": 99999.0, "pq": 0.0}
		var ls := prepped_lots(id)
		while room > 0.5 and ls.size() > 0:
			var tub: Dictionary = ls[0]
			var u: float = min(tub.q, room)
			tub.q -= u
			room -= u
			got.g = (got.g * got.got + tub.g * u) / (got.got + u)
			got.pq = (got.pq * got.got + float(tub.get("pq", 0.8)) * u) / (got.got + u)
			got.got += u
			got.cost += u * tub.c
			got.x = min(got.x, tub.x)
			if tub.q <= 0.5:
				ls.pop_front()
				wash_add(int(tub.get("size", 4)))
				out.tubs_emptied += 1
	else:
		got = take(id, room)
		got.pq = 0.85
	if got.got <= 0: return out
	var total: float = pan.q + got.got
	pan.c = (pan.c * pan.q + got.cost) / total
	pan.g = (pan.g * pan.q + got.g * got.got) / total
	pan.pq = (float(pan.get("pq", 0.8)) * pan.q + got.pq * got.got) / total
	pan.x = got.x if pan.q <= 0.5 else min(pan.x, got.x)
	pan.q = total
	out.grams = got.got
	out.minutes = 1.0 + out.tubs_emptied * 0.5
	return out

## put today's toppings into pans, most used first. Pans holding something no longer needed are emptied back.
## Returns the ids that did not get a pan.
func assign_rail(ids: Array) -> Array:
	var r := rail()
	var missing := []
	for id in ids:
		if rail_slot(id) >= 0: continue
		var free := -1
		for i in r.size():
			if r[i].ing == "" or (not ids.has(r[i].ing) and r[i].q <= 0.5):
				free = i
				break
		if free < 0:
			missing.append(id)
			continue
		r[free] = {"ing": id, "q": 0.0, "x": 0.0, "g": 2.0, "c": 0.0, "pq": 0.8}
	return missing

## the counter at close: an unchilled rail has to go back into tubs (or the stores) in the fridge overnight
func close_rail() -> Array:
	var notes := []
	if rail_chilled(): return notes
	for pan in rail():
		if pan.ing == "" or pan.q <= 0.5: continue
		var id: String = pan.ing
		if Data.needs_prep(id):
			var size := 2 if pan.q / 1000.0 * line_vol(id) <= 2.0 else 4
			if clean_tubs(size) == 0: size = 6 - size
			if clean_tubs(size) == 0:
				log_waste(id, pan.q, pan.q * pan.c, "no clean tub")
				notes.append("No clean tub for the %s left on the counter: binned." % Data.ING[id].name.to_lower())
			else:
				take("tub%d" % size, 1)
				prepped_lots(id).append({"q": pan.q, "x": pan.x, "g": pan.g, "c": pan.c, "size": size, "made": Game.s.day, "pq": pan.get("pq", 0.8), "lab": Equip.label_tub()})
				prepped_lots(id).sort_custom(func(a, b): return a.x < b.x)
		else:
			add(id, pan.q, int(round(pan.g)), pan.c, pan.x)
		pan.q = 0.0
	return notes

# ---------- pizza boxes ----------
## Boxes come flat in sleeves. Before service someone folds a stack of them; a takeaway pizza goes into a folded
## box at the pass. With none folded, a box is folded on the spot, which keeps the customer waiting.
const FOLD_MIN := 0.25        # minutes to fold one box by hand

func folded() -> int:
	return int(Game.s.get("folded", 0))

## room by the pass for folded boxes
func fold_cap() -> int:
	return int(round(30.0 * float(Game.venue().size)))

## fold up to n flat boxes. Returns how many were folded.
func fold(n: int) -> int:
	n = int(min(n, min(floor(have("box")), fold_cap() - folded())))
	if n <= 0: return 0
	var t := take("box", n)
	var c0: float = float(Game.s.get("folded_c", 0.0))
	Game.s.folded_c = (c0 * folded() + t.cost) / (folded() + n)
	Game.s.folded = folded() + n
	return n

## take a folded box for a takeaway. {ok, cost, folded_now: true if it had to be folded on the spot}
func box_one() -> Dictionary:
	var now := folded() <= 0
	if now and fold(1) <= 0: return {"ok": false, "cost": 0.0, "folded_now": false}
	Game.s.folded = folded() - 1
	return {"ok": true, "cost": float(Game.s.get("folded_c", 0.0)), "folded_now": now}

## folded boxes a day like today will need
func boxes_needed(day: int = -1) -> int:
	var take_share := 1.0 if Game.calc().tables == 0 else 0.5
	return int(ceil(Game.covers(Game.s.day if day < 0 else day) * take_share))

# ---------- the wash-up ----------
func wash_add(size: int, n: int = 1) -> void:
	var k := str(size)
	Game.s.washup[k] = int(Game.s.washup.get(k, 0)) + n

func dirty_tubs() -> int:
	var t := 0
	for k in Game.s.washup: t += int(Game.s.washup[k])
	return t

func wash_minutes() -> float:
	return ceil(dirty_tubs() * 0.6)

func wash_all() -> int:
	var n := dirty_tubs()
	for k in Game.s.washup:
		var c: int = int(Game.s.washup[k])
		if c > 0: add("tub" + k, c, 2, Data.ING["tub" + k].g[2].price)
		Game.s.washup[k] = 0
	return n

# ---------- storage ----------
func space_of(id: String, q: float) -> float:
	return q * Data.ING[id].space

func store_used(store: String) -> float:
	var u := 0.0
	for id in Game.s.stock:
		if Data.ING[id].store == store: u += have(id) * Data.ING[id].space
	if store == "fridge":
		u += dough_count() * DOUGH_LITRES
		for id in Game.s.prepped:
			for l in Game.s.prepped[id]: u += float(l.get("size", 4))
	return u

func store_cap(store: String) -> float:
	return Game.tier(store).cap

func store_free(store: String) -> float:
	return store_cap(store) - store_used(store)

func fill(store: String) -> float:
	var cap := store_cap(store)
	return store_used(store) / cap if cap > 0 else 0.0

func vent(store: String) -> int:
	return int(Game.s.vent.get(store, 2))

## the vent setting this store needs right now (0..4), given how full it is
func vent_need(store: String) -> float:
	return 1.0 + (2.5 if store == "fridge" else 2.0) * min(fill(store), 1.0)

## fridge temperature in degrees C
func fridge_temp() -> float:
	var f := fill("fridge")
	return 3.5 + (vent_need("fridge") - vent("fridge")) * 2.0 + max(0.0, f - 0.9) * 30.0

## dry store relative humidity in %
func dry_humidity() -> float:
	var wet: float = [2.0, 0.0, 5.0, 7.0][Game.season()]
	return clamp(55.0 + (vent_need("dry") - vent("dry")) * 9.0 + wet, 25.0, 95.0)

## how much the dry store's vents are letting in (0 = nothing): feeds the pest model
func dry_draught() -> float:
	return max(0.0, vent("dry") - vent_need("dry") - 0.75)

## [text, state] for the fridge or dry store, state is ok / warn / bad
func climate(store: String) -> Array:
	if store == "fridge":
		var t := fridge_temp()
		if t < 0.5: return ["%.1f °C: freezing delicate food" % t, "bad"]
		if t < 1.0: return ["%.1f °C: close to freezing" % t, "warn"]
		if t > 8.0: return ["%.1f °C: far too warm, food is spoiling" % t, "bad"]
		if t > 5.0: return ["%.1f °C: too warm, food spoils early" % t, "warn"]
		return ["%.1f °C" % t, "ok"]
	if store == "dry":
		var h := dry_humidity()
		var d := dry_draught()
		if h > 76.0: return ["%d%% humidity: damp, things are going mouldy" % h, "bad"]
		if h > 68.0: return ["%d%% humidity: too damp" % h, "warn"]
		if d > 0.0: return ["%d%% humidity: vents wide enough to let pests in" % h, "warn" if d < 1.0 else "bad"]
		return ["%d%% humidity" % h, "ok"]
	return ["-18 °C", "ok"]

# ---------- the back door ----------
## put away a delivery that is waiting at the back door, at minute `now`.
## rotate = new stock behind the old (slower, correct); otherwise it is stacked in front.
## Returns {minutes, wasted [{id, q}], spoiled [{id, q}]}
func put_away(entry: Dictionary, rotate: bool, now: float) -> Dictionary:
	var each := []
	for ln in entry.lines: each.append(rotate)
	return put_away_each(entry, each, now)

## the same, choosing for each line whether it goes behind the old stock (true) or in front (false)
func put_away_each(entry: Dictionary, each: Array, now: float) -> Dictionary:
	var out := {"minutes": 2.0, "wasted": [], "spoiled": []}
	var waited: float = max(0.0, now - entry.arrived)
	for li in entry.lines.size():
		var ln: Dictionary = entry.lines[li]
		var rotate: bool = each[li]
		var it: Dictionary = Data.ING[ln.ing]
		var x: float = float(Game.s.day + int(ln.life))
		var chilled: bool = it.store != "dry"
		if chilled and waited > 30.0:
			if waited > 180.0:
				out.spoiled.append({"id": ln.ing, "q": ln.q})
				log_waste(ln.ing, ln.q, ln.q * ln.c, "left out too long")
				continue
			x -= (waited - 30.0) / 60.0 * (0.5 if it.store == "fridge" else 0.8)
		var fits: float = min(ln.q, max(0.0, store_free(it.store)) / it.space)
		if it.unit != "g" and it.unit != "ml": fits = floor(fits)
		add(ln.ing, fits, int(ln.g), ln.c, x, not rotate)
		if ln.q - fits > ln.q * 0.005:
			out.wasted.append({"id": ln.ing, "q": ln.q - fits})
			log_waste(ln.ing, ln.q - fits, (ln.q - fits) * ln.c, "no room in the stores")
		out.minutes += 1.5 + _kg(ln.ing, ln.q) * (0.45 if rotate else 0.12)
	out.minutes = ceil(out.minutes)
	Game.s.dock.erase(entry)
	return out

func dock_minutes(entry: Dictionary, rotate: bool) -> float:
	var m := 2.0
	for ln in entry.lines: m += 1.5 + _kg(ln.ing, ln.q) * (0.45 if rotate else 0.12)
	return ceil(m)

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
	n = int(min(n, floor(max(0.0, store_free("fridge")) / DOUGH_LITRES)))
	n = min(n, Equip.dough_room())
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
## What the night does to the stores: the fridge and dry store climate, then everything out of date is binned.
## Returns {binned: [{id, q, cost}], notes: [text]}
func night() -> Dictionary:
	var out := {"binned": [], "notes": []}
	var temp := fridge_temp()
	var hum := dry_humidity()
	# the fridge
	if temp > 5.0:
		var lost: float = (temp - 5.0) * 0.35
		for id in Game.s.stock:
			if Data.ING[id].store != "fridge": continue
			for l in lots(id): l.x -= lost
		for id in Game.s.prepped:
			for l in prepped_lots(id): l.x -= lost
		if rail_chilled():
			for pan in rail(): pan.x -= lost * 0.5
		out.notes.append("The fridge ran at %.1f °C overnight: chilled food lost %.1f days of life. Open the vents or take stock out." % [temp, lost])
	elif temp < 0.5:
		var hit := []
		for id in Game.s.stock:
			var it: Dictionary = Data.ING[id]
			if it.store != "fridge" or it.frost == "": continue
			for l in lots(id).duplicate():
				if it.frost == "bin":
					log_waste(id, l.q, l.q * l.c, "frozen")
					lots(id).erase(l)
				else:
					l.g = max(1, int(l.g) - 1)
					l.x -= 1.0
				if not hit.has(it.name.to_lower()): hit.append(it.name.to_lower())
		for id in Game.s.prepped:
			if Data.ING[id].frost == "bin":
				for l in prepped_lots(id):
					log_waste(id, l.q, l.q * l.c, "frozen")
					wash_add(int(l.get("size", 4)))
				Game.s.prepped[id] = []
		if hit.size() > 0:
			out.notes.append("The fridge dropped to %.1f °C and froze the %s. Leaves went black; cheese and veg lost quality. Close the vents a notch." % [temp, ", ".join(hit)])
	# the dry store
	if hum > 68.0:
		var lost: float = (hum - 68.0) * 0.12
		var mould := []
		for id in Game.s.stock:
			var it: Dictionary = Data.ING[id]
			if it.store != "dry" or not it.damp: continue
			for l in lots(id).duplicate():
				l.x -= lost
				if hum > 76.0 and randf() < (hum - 76.0) * 0.04:
					log_waste(id, l.q, l.q * l.c, "damp")
					lots(id).erase(l)
					mould.append("%s %s" % [Data.qty(id, l.q), it.name.to_lower()])
		out.notes.append("The dry store was damp (%d%% humidity)." % hum + ((" Gone mouldy and binned: " + ", ".join(mould) + ".") if mould.size() > 0 else " Flour, onions and potatoes will not keep as long. Open the vents."))
	# out of date
	for id in Game.s.stock:
		var keep := []
		for l in Game.s.stock[id]:
			if l.x <= Game.s.day + 1:
				out.binned.append({"id": id, "q": l.q, "cost": l.q * l.c})
				log_waste(id, l.q, l.q * l.c, "out of date")
			else:
				keep.append(l)
		Game.s.stock[id] = keep
	for id in Game.s.prepped:
		var keep := []
		for l in Game.s.prepped[id]:
			if l.x <= Game.s.day + 1:
				out.binned.append({"id": id, "q": l.q, "cost": l.q * l.c, "prepped": true})
				log_waste(id, l.q, l.q * l.c, "out of date")
				wash_add(int(l.get("size", 4)))
			else:
				keep.append(l)
		Game.s.prepped[id] = keep
	for pan in rail():
		if pan.ing != "" and pan.q > 0.5 and pan.x <= Game.s.day + 1:
			out.binned.append({"id": pan.ing, "q": pan.q, "cost": pan.q * pan.c, "prepped": true})
			log_waste(pan.ing, pan.q, pan.q * pan.c, "out of date")
			pan.q = 0.0
	return out

## bin dough that will have overproofed by tomorrow. Returns balls lost.
func dough_night() -> int:
	var lost := 0
	var keep := []
	for l in Game.s.dough:
		if l.n <= 0: continue
		if dough_age(l, Game.s.day + 1) > dough_window(l)[1]:
			lost += int(l.n)
			log_waste("dough:" + l.style, l.n, l.n * float(l.get("c", 0.0)), "overproofed dough")
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

## something went in the bin: what, how much, what it cost, and why (the waste log on the Stores page sorts by why)
func log_waste(id: String, q: float, cost: float, why: String = "other") -> void:
	var b: Dictionary = Game.s.book
	b.waste[id] = b.waste.get(id, 0.0) + q
	b.cost_waste += cost
	if not b.has("why"): b.why = {}
	b.why[why] = b.why.get(why, 0.0) + cost

## peelings, stalks and drained liquid from prep: not waste you could have avoided, but you paid for it
func log_trim(id: String, q: float) -> void:
	var b: Dictionary = Game.s.book
	b.trim[id] = b.trim.get(id, 0.0) + q

## a made (or part-made) pizza went in the bin
func log_binned(use: Dictionary, cost: float) -> void:
	var b: Dictionary = Game.s.book
	for id in use: b.waste[id] = b.waste.get(id, 0.0) + use[id]
	b.cost_waste += cost
	b.binned += 1
	if not b.has("why"): b.why = {}
	b.why["pizzas binned"] = b.why.get("pizzas binned", 0.0) + cost

func label(id: String) -> String:
	if id.begins_with("dough:"): return Data.DOUGHS[id.substr(6)].name + " dough"
	return Data.ING[id].name

func amount(id: String, q: float) -> String:
	if id.begins_with("dough:"): return "%d ball%s" % [int(round(q)), "" if int(round(q)) == 1 else "s"]
	return Data.qty(id, q)

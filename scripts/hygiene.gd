extends Node
## Autoload `Hygiene`: how clean the kitchen and front of house are, pests, and the food hygiene inspector.
##
## Cleanliness (0-100) of the kitchen ("boh") and front of house ("foh") drops through service and is put back
## by cleaning, which takes time and cleaning chemicals. Pests (0-100) creep up when the place is dirty, when the
## dry store vents are open too wide, in autumn and winter, and when nothing is keeping them out. Mice come in
## through particular ways in on each premises' floor plan; traps laid against the wall near them catch them, then
## need resetting. Pest proofing (an upgrade track) keeps most of them out in the first place.
## At night mice raid the dry store; during service a customer may see one.
## An inspector visits every couple of weeks and gives a 0-5 rating that customers can see. 0 or 1 closes you.

# ---------- cleanliness ----------
func level(area: String) -> float:
	return float(Game.s.clean.get(area, 100.0))

func dirty(area: String, by: float) -> void:
	Game.s.clean[area] = clamp(level(area) - by, 0.0, 100.0)

func tidy(area: String, by: float) -> void:
	Game.s.clean[area] = clamp(level(area) + by, 0.0, 100.0)

## ml of chemicals one clean of an area uses
func chem_needed(area: String) -> float:
	return (180.0 if area == "boh" else 120.0) * float(Game.venue().size)

## minutes a full clean takes (staff: pass their skill)
func clean_minutes(area: String, skill: int = 0) -> float:
	var base: float = (32.0 if area == "boh" else 20.0) * float(Game.venue().size)
	if area == "boh": base *= 0.6 + 0.4 * float(Game.tier("dish").turn)
	if skill > 0: base *= 1.15 - 0.08 * skill
	return ceil(base * (1.0 - level(area) / 100.0 * 0.6))

## clean an area properly. Returns a note on how it went
func clean(area: String) -> String:
	var want := chem_needed(area)
	var got := Stock.take("sanitiser", want)
	var k: float = got.got / want
	var grade_bonus: float = (got.g - 1.0) * 0.04 if got.got > 0 else 0.0
	var to: float = lerp(55.0, 100.0, k) * (1.0 + grade_bonus)
	var kit := Equip.clean_cap(area)
	to = min(to, kit.cap)
	Game.s.clean[area] = clamp(max(level(area), to), 0.0, 100.0)
	if k < 0.99: return "Not enough cleaning chemicals: it is only %d%% clean. Order some from the packaging supplier." % level(area)
	if kit.why.size() > 0: return "Only %d%% clean: %s. Order from %s." % [level(area), ", ".join(kit.why), Equip.SHOP.name]
	return ""

func state(area: String) -> Array:
	var l := level(area)
	if l >= 80: return ["Clean", "ok"]
	if l >= 55: return ["Needs a wipe-down", "warn"]
	if l >= 30: return ["Dirty", "bad"]
	return ["Filthy", "bad"]

# ---------- the floor plan and traps ----------
## Every premises has a floor plan (data/floorplans.json): rooms whose edges are walls, the ways mice get in
## (gaps under doors, drains, pipe holes, air bricks) and the food they are after. Mice come in through those ways
## and run along the walls. A trap catches them when it is flat against a wall, close to where they come in.
## Droppings build up where mice have been getting in, so the plan shows you where traps are needed.
const TRAP_RANGE := 110.0     # plan units: further than this from a way in, a trap catches nothing from it
const WALL_GAP := 18.0        # this close to a wall, a trap is on the mice's run
const PLAN_SIZE := Vector2(640, 320)
var PLANS := []

func _init() -> void:
	var d = JSON.parse_string(FileAccess.open("res://data/floorplans.json", FileAccess.READ).get_as_text())
	PLANS = d.plans

func plan() -> Dictionary:
	return PLANS[clamp(int(Game.s.venue), 0, PLANS.size() - 1)]

func entries() -> Array:
	return plan().entries

## how many traps the premises should have down
func traps_wanted() -> int:
	return int(ceil(2.0 * float(Game.venue().size)))

## the traps on the floor: [{x, y, sprung}]
func traps() -> Array:
	var P: Dictionary = Game.s.pests
	if not P.has("traps"):           # an older save kept only counts: put them down by the doors
		P.traps = []
		var n := int(P.get("laid", 0)) + int(P.get("sprung", 0))
		for i in n:
			var sp := _auto_spot(false)
			P.traps.append({"x": sp.x, "y": sp.y, "sprung": i < int(P.get("sprung", 0))})
		P.erase("laid")
		P.erase("sprung")
	if not P.has("seen"): P.seen = {}
	return P.traps

func laid() -> int:
	return traps().filter(func(t): return not t.sprung).size()

func sprung() -> int:
	return traps().filter(func(t): return t.sprung).size()

## the room a point is in, or {}
func room_at(p: Vector2) -> Dictionary:
	for rm in plan().rooms:
		var r: Array = rm.r
		if p.x >= r[0] + 4 and p.x <= r[0] + r[2] - 4 and p.y >= r[1] + 4 and p.y <= r[1] + r[3] - 4: return rm
	return {}

## how far a point is from the nearest wall of the room it is in
func wall_dist(p: Vector2) -> float:
	var rm := room_at(p)
	if rm.is_empty(): return 999.0
	var r: Array = rm.r
	return min(min(p.x - r[0], r[0] + r[2] - p.x), min(p.y - r[1], r[1] + r[3] - p.y))

## how well a trap at p catches mice coming in through entry e (0..1)
func trap_q(p: Vector2, e: Dictionary) -> float:
	var d := p.distance_to(Vector2(e.x, e.y))
	var prox: float = clamp(1.0 - d / TRAP_RANGE, 0.0, 1.0)
	var on_run: bool = wall_dist(p) <= WALL_GAP or (e.kind == "drain" and d < 30.0)
	return prox * (1.0 if on_run else 0.35)

## how good a spot is for a trap: the best it does against any way in (0..1)
func spot_value(p: Vector2) -> float:
	var best := 0.0
	for e in entries(): best = max(best, trap_q(p, e))
	return best

## share of the mice (by how many use each way in) that run past a well-placed trap
func coverage() -> float:
	var tot := 0.0
	var got := 0.0
	for e in entries():
		var best := 0.0
		for t in traps():
			if not t.sprung: best = max(best, trap_q(Vector2(t.x, t.y), e))
		tot += float(e.w)
		got += float(e.w) * min(1.0, best / 0.6)
	return got / tot if tot > 0 else 1.0

## where someone puts a trap without looking for droppings: by the doors and the food (smart = by every way in,
## the busiest first, as a pest controller would)
func _auto_spot(smart: bool) -> Vector2:
	var es: Array = entries().duplicate()
	var food := Vector2(plan().food[0][0], plan().food[0][1])
	if smart: es.sort_custom(func(a, b): return float(a.w) > float(b.w))
	else:
		es = es.filter(func(e): return e.kind == "door")
		es.append({"x": food.x, "y": food.y - 30.0, "kind": "food"})
	for e in es:
		var at := Vector2(e.x, e.y)
		var taken := false
		for t in Game.s.pests.get("traps", []):
			if Vector2(t.x, t.y).distance_to(at) < 45.0: taken = true
		if taken: continue
		return _onto_floor(at.move_toward(food, 20.0))
	var any: Dictionary = es.pick_random()
	return _onto_floor(Vector2(any.x, any.y).move_toward(food, 40.0))

## nudge a point inside the nearest room
func _onto_floor(p: Vector2) -> Vector2:
	if not room_at(p).is_empty(): return p
	var best := p
	var bd := 1e9
	for rm in plan().rooms:
		var r: Array = rm.r
		var q := Vector2(clamp(p.x, r[0] + 8, r[0] + r[2] - 8), clamp(p.y, r[1] + 8, r[1] + r[3] - 8))
		if q.distance_to(p) < bd:
			bd = q.distance_to(p)
			best = q
	return best

## put a trap down at p (or where someone would without looking, if p is null). Takes one from stock.
func lay_trap(p = null, smart: bool = false) -> bool:
	if Stock.have("traps") < 1: return false
	Stock.take("traps", 1)
	var at: Vector2 = _onto_floor(p) if p != null else _auto_spot(smart)
	traps().append({"x": at.x, "y": at.y, "sprung": false})
	return true

## put traps down without taking them from stock (a new business that comes with them)
func place_best(n: int) -> void:
	for i in n:
		var at := _auto_spot(true)
		traps().append({"x": at.x, "y": at.y, "sprung": false})

func move_trap(i: int, p: Vector2) -> void:
	var at := _onto_floor(p)
	traps()[i].x = at.x
	traps()[i].y = at.y

## lift a trap and put it back in the box
func pick_up(i: int) -> void:
	traps().remove_at(i)
	Stock.add("traps", 1, 2, Data.ING.traps.g[2].price)

func reset_traps() -> int:
	var n := 0
	for t in traps():
		if t.sprung:
			t.sprung = false
			n += 1
	return n

## moving to new premises: the traps come with you, in the box
func move_out() -> void:
	var n := traps().size()
	if n > 0: Stock.add("traps", n, 2, Data.ING.traps.g[2].price)
	Game.s.pests.traps = []
	Game.s.pests.seen = {}

## droppings on the floor where mice have been getting in: [Vector2]
func droppings() -> Array:
	var out := []
	traps()
	var seen: Dictionary = Game.s.pests.seen
	var food := Vector2(plan().food[0][0], plan().food[0][1])
	var es := entries()
	for i in es.size():
		var n := int(clamp(round(float(seen.get(str(i), 0.0)) * 3.0), 0, 14))
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%d:%d" % [int(Game.s.venue), i])
		var at := Vector2(es[i].x, es[i].y)
		for k in n:
			var along: Vector2 = at.move_toward(food, rng.randf_range(4.0, 70.0))
			out.append(_onto_floor(along + Vector2(rng.randf_range(-10, 10), rng.randf_range(-10, 10))))
	return out

# ---------- pests ----------
func pests() -> float:
	return float(Game.s.pests.level)

func pest_state() -> Array:
	var p := pests()
	if p < 12: return ["No sign of pests", "ok"]
	if p < 30: return ["Droppings here and there", "warn"]
	if p < 55: return ["Mice in the building", "bad"]
	return ["Infested", "bad"]

## what is drawing pests in, as short phrases
func pest_causes() -> Array:
	var out := []
	if level("boh") < 60: out.append("a dirty kitchen")
	if level("foh") < 55: out.append("a dirty front of house")
	if Stock.dry_draught() > 0: out.append("dry store vents open too wide")
	if laid() < traps_wanted(): out.append("not enough traps down")
	elif pests() >= 8.0 and coverage() < 0.5: out.append("traps not where the mice are getting in (look for droppings)")
	if sprung() > 0: out.append("sprung traps not reset")
	if Game.season() >= 2: out.append("cold weather driving mice indoors")
	return out

func _pick_entry() -> int:
	var es := entries()
	var tot := 0.0
	for e in es: tot += float(e.w)
	var r := randf() * tot
	for i in es.size():
		r -= float(es[i].w)
		if r <= 0.0: return i
	return es.size() - 1

## the night: pests come in, traps catch some, the rest go for the dry store. Returns notes.
func night() -> Array:
	var notes := []
	var P: Dictionary = Game.s.pests
	var guard: float = Game.tier("pest").guard
	var pressure: float = (100.0 - level("boh")) * 0.22 + (100.0 - level("foh")) * 0.1 + Stock.dry_draught() * 14.0 + [1.0, 0.0, 4.0, 6.0][Game.season()]
	pressure *= 1.0 - guard
	P.level = clamp(P.level + pressure * 0.2 - 1.5 - guard * 3.0, 0.0, 100.0)
	# mice come in through the ways in; the best-placed traps on their way get the first chance
	traps()
	var seen: Dictionary = P.seen
	for k in seen.keys(): seen[k] = float(seen[k]) * 0.6
	var visits := 0
	if P.level > 2.0:
		visits = int(P.level / 12.0) + (1 if randf() < fmod(P.level / 12.0, 1.0) else 0)
	var caught := 0
	var es := entries()
	for v in visits:
		var ei := _pick_entry()
		var e: Dictionary = es[ei]
		var set_traps: Array = traps().filter(func(t): return not t.sprung)
		set_traps.sort_custom(func(a, b): return trap_q(Vector2(a.x, a.y), e) > trap_q(Vector2(b.x, b.y), e))
		var got := false
		for t in set_traps.slice(0, 3):
			var q := trap_q(Vector2(t.x, t.y), e)
			if q <= 0.0: break
			if randf() < 0.6 * q:
				t.sprung = true
				caught += 1
				P.level = max(0.0, P.level - 7.0)
				got = true
				break
		if not got: seen[str(ei)] = float(seen.get(str(ei), 0.0)) + 1.0
	if caught > 0: notes.append("%d trap%s caught something overnight and need%s resetting." % [caught, "" if caught == 1 else "s", "s" if caught == 1 else ""])
	if P.level > 22.0 and randf() < (P.level - 22.0) / 90.0:
		var targets := []
		for id in Game.s.stock:
			if Data.ING[id].pests and Stock.have(id) > 0: targets.append(id)
		if targets.size() > 0:
			var id: String = targets.pick_random()
			var lost: float = Stock.have(id) * randf_range(0.15, 0.4)
			var t := Stock.take(id, lost)
			Stock.log_waste(id, t.got, t.cost)
			notes.append("Mice got into the %s in the dry store: %s chewed and binned." % [Data.ING[id].name.to_lower(), Data.qty(id, t.got)])
	if P.level > 45.0:
		dirty("boh", 15.0)
		notes.append("Droppings in the kitchen this morning. It needs cleaning before you open.")
	if P.level >= 12.0 and caught == 0:
		notes.append("Signs of mice. Look on the floor plan for droppings and put traps against the wall where they are getting in.")
	return notes

## chance per game-minute that a customer sees a mouse during service
func sighting_rate() -> float:
	var p := pests()
	if p < 30.0: return 0.0
	return (p - 30.0) / 4000.0 * (1.4 if level("foh") < 50.0 else 1.0)

# ---------- the inspector ----------
## customers walking past can see your rating: it changes footfall
func footfall() -> float:
	var r: int = int(Game.s.hygiene.rating)
	return 1.0 if r < 0 else 0.8 + 0.05 * r

## schedule the next visit after one on `day`
func plan_next(day: int, last_rating: int) -> void:
	Game.s.hygiene.next = day + (randi_range(4, 8) if last_rating >= 0 and last_rating <= 2 else randi_range(10, 20))

## the morning: is the inspector coming today, and when
func roll_visit() -> void:
	var H: Dictionary = Game.s.hygiene
	H.at = -1.0
	if Game.s.day >= int(H.next):
		H.at = float(randi_range(9 * 60, 15 * 60))

## the inspection itself. Returns {rating, notes, closed}
func inspect() -> Dictionary:
	var notes := []
	var score := 0.0
	var boh := level("boh") / 100.0
	var foh := level("foh") / 100.0
	score += boh * 1.6 + foh * 0.8
	if boh < 0.6: notes.append("Kitchen not clean enough")
	if foh < 0.55: notes.append("Dining area dirty")
	var p := pests()
	score += clamp(1.0 - p / 50.0, 0.0, 1.0) * 1.2
	if p >= 12.0: notes.append("Evidence of pests")
	var t := Stock.fridge_temp()
	if t >= 1.0 and t <= 5.0: score += 0.6
	else: notes.append("Fridge at %.1f °C (must be 1 to 5 °C)" % t)
	var rot := Stock.rotation_problems()
	if rot.is_empty(): score += 0.4
	else: notes.append("Poor stock rotation: new stock in front of old")
	if laid() >= traps_wanted() and (coverage() >= 0.5 or float(Game.tier("pest").guard) >= 0.6): score += 0.4
	elif laid() >= traps_wanted(): notes.append("Traps not placed where pests get in")
	else: notes.append("Not enough pest control in place")
	var logs := Checks.log_rate(7)
	score += 0.6 * logs
	if logs < 0.7: notes.append("Temperature records missing or incomplete")
	# the kit: labels, boards, a probe, and the safety equipment the law asks for
	var kit := 0.6
	var unl := Equip.unlabelled()
	if unl > 0:
		kit -= 0.2
		notes.append("%d tub%s of food with no date label" % [unl, "" if unl == 1 else "s"])
	var boards := Equip.board_issues()
	if boards.size() > 0:
		kit -= 0.15
		notes.append("No colour-coded board for the %s" % ", ".join(boards))
	if Equip.menu_cooks() and not Equip.has("probe"):
		kit -= 0.15
		notes.append("No probe thermometer to check cooked food")
	var safety := Equip.compliance_missing()
	if safety.size() > 0:
		kit -= 0.25 * safety.size()
		notes.append("Missing: " + ", ".join(safety))
	score += max(kit, -0.6)
	score *= 5.0 / 6.2
	var rating := int(clamp(round(score), 0, 5))
	if p >= 55.0: rating = min(rating, 1)
	elif p >= 30.0: rating = min(rating, 2)
	if boh < 0.3: rating = min(rating, 1)
	if t > 8.0: rating = min(rating, 2)
	var H: Dictionary = Game.s.hygiene
	H.rating = rating
	H.day = Game.s.day
	H.notes = notes
	H.at = -1.0
	plan_next(Game.s.day, rating)
	return {"rating": rating, "notes": notes, "closed": rating <= 1}

func rating_text() -> String:
	var r: int = int(Game.s.hygiene.rating)
	if r < 0: return "Not yet inspected"
	return "%d: %s" % [r, ["Urgent improvement necessary", "Major improvement necessary", "Improvement necessary", "Generally satisfactory", "Good", "Very good"][r]]

extends Node
## Autoload `Day`: the clock outside service, and what happens as it moves.
##
## You start at 07:00 (later if you worked past midnight). Every job in the morning and evening takes minutes:
## putting deliveries away, prep, cleaning, laying traps, rotating stock, making dough.
## Deliveries turn up at the back door at their time. Staff on shift handle some of it for you:
##   prep cook     checks in and rotates deliveries, then does the prep list (in their own time from 07:00)
##   kitchen porter puts deliveries away, cleans the kitchen and resets the traps at close
##   servers        clean the front of house at close
## Service runs from the venue's opening to closing time (see ServiceScreen).

const START := 7 * 60

func now() -> float:
	return float(Game.s.clock)

func open_time() -> float:
	return float(Game.venue().open) * 60.0

func close_time() -> float:
	return float(Game.venue().close) * 60.0

func morning() -> bool:
	return Game.s.phase == "morning"

## minutes a staff member of this role has in the morning before opening
func _staff_minutes(role: String) -> float:
	var t := 0.0
	for x in Game.staff_of(role): t += (open_time() - START) * (0.75 + 0.1 * x.skill)
	return t

## how much faster prep goes with your kit (multiplies minutes)
func prep_mult() -> float:
	return 1.0 / (1.0 + float(Game.tier("prep").speed))

# ---------- the morning ----------
## called once when a new day starts
func start_morning() -> Array:
	var notes := []
	Game.s.clock = START + int(Game.s.get("late_start", 0))
	Game.s.late_start = 0
	if Game.s.clock > START: notes.append("You worked late, so you are not in until %s." % Data.hhmm(Game.s.clock))
	Game.s.staff_left = {"prep": _staff_minutes("prep"), "porter": _staff_minutes("porter")}
	Hygiene.roll_visit()
	notes.append_array(arrivals())
	notes.append_array(staff_prep())
	notes.append_array(Story.morning())
	return notes

## spend the player's time. Returns notes about anything that happened meanwhile
func spend(minutes: float) -> Array:
	Game.s.clock = int(round(Game.s.clock + minutes))
	var notes := arrivals()
	if morning(): notes.append_array(staff_prep())
	return notes

func wait_until(minute: float) -> Array:
	return spend(max(0.0, minute - now()))

## orders due today that have not arrived yet, soonest first
func pending() -> Array:
	var out: Array = Game.s.orders.filter(func(o): return int(o.due) == Game.s.day)
	out.sort_custom(func(a, b): return a.eta < b.eta)
	return out

func next_arrival() -> float:
	var p := pending()
	return p[0].eta if p.size() > 0 else -1.0

## anything due by now arrives at the back door; staff on shift put it away. Returns notes.
func arrivals(until: float = -1.0) -> Array:
	var t: float = now() if until < 0 else until
	var notes := []
	for o in pending():
		if o.eta > t: continue
		Game.s.orders.erase(o)
		var sup: Dictionary = Data.SUP[o.sup]
		var entry := {"sup": o.sup, "arrived": o.eta, "lines": o.lines, "total": o.total}
		Game.s.dock.append(entry)
		if not o.paid:
			Game.s.payables.append({"sup": o.sup, "amount": o.total, "due": Game.s.day + int(sup.terms)})
		var who := _free_handler(Stock.dock_minutes(entry, true))
		if who != "" and morning():
			var res := Stock.put_away(entry, true, o.eta)
			notes.append("%s %s at %s. Your %s checked it in and rotated it.%s" % [sup.name, "was collected" if sup.get("collect", false) else "delivered", Data.hhmm(o.eta), "prep cook" if who == "prep" else "kitchen porter", _waste_text(res)])
		else:
			notes.append("%s %s at %s. It is waiting at the back door to be put away." % [sup.name, "order is in" if sup.get("collect", false) else "delivered", Data.hhmm(o.eta)])
	return notes

func _waste_text(res: Dictionary) -> String:
	var t := ""
	if res.wasted.size() > 0: t += " No room for " + ", ".join(res.wasted.map(func(w): return "%s %s" % [Data.qty(w.id, w.q), Data.ING[w.id].name.to_lower()])) + ": wasted."
	if res.spoiled.size() > 0: t += " Left out too long and binned: " + ", ".join(res.spoiled.map(func(w): return Data.ING[w.id].name.to_lower())) + "."
	return t

## a staff member with the time to handle a job in the morning, or ""
func _free_handler(minutes: float) -> String:
	var left: Dictionary = Game.s.get("staff_left", {})
	for role in ["porter", "prep"]:
		if left.get(role, 0.0) >= minutes:
			left[role] -= minutes
			return role
	return ""

## the player puts a delivery away
func put_away(entry: Dictionary, rotate: bool) -> Dictionary:
	var res := Stock.put_away(entry, rotate, now())
	res.notes = spend(res.minutes)
	res.text = _waste_text(res)
	return res

# ---------- prep ----------
## what today's service needs prepped: [{id, need, have, todo (prepped g), raw (g to prep), raw_have, minutes}]
func prep_list(day: int = -1) -> Array:
	var d: int = Game.s.day if day < 0 else day
	var recs := Game.recipes_on(d)
	var rows := []
	if recs.is_empty(): return rows
	var cov: float = Game.covers(d) * 1.1 + 2.0
	var need := {}
	for r in recs:
		for id in r.spec:
			if Data.needs_prep(id): need[id] = need.get(id, 0.0) + r.spec[id] * cov / recs.size()
	for id in need:
		var p = Data.ING[id].prep
		var have := Stock.prepped(id, d) + (Stock.rail_have(id) if d == Game.s.day else 0.0)
		var todo: float = max(0.0, need[id] - have)
		var raw: float = min(todo / float(p.yield), Stock.have(id))
		var tub_cap: float = Stock.max_prep_raw(id)
		rows.append({"id": id, "need": need[id], "have": have, "todo": todo, "raw": min(raw, tub_cap), "raw_have": Stock.have(id), "tub_short": raw > tub_cap + 1.0,
			"minutes": Stock.prep_minutes(id, min(raw, tub_cap), prep_mult()) if raw > 0 else 0.0})
	rows.sort_custom(func(a, b): return Data.ING[a.id].name < Data.ING[b.id].name)
	return rows

## the player preps raw_g of something
func do_prep(id: String, raw_g: float) -> Dictionary:
	var mins := Stock.prep_minutes(id, raw_g, prep_mult())
	var res := Stock.prep(id, raw_g)
	res.minutes = mins
	res.notes = spend(mins)
	return res

## prep cooks work through the prep list with the time they have left this morning. Returns notes.
func staff_prep() -> Array:
	var left: Dictionary = Game.s.get("staff_left", {})
	if left.get("prep", 0.0) <= 0.0 or Game.staff_of("prep").is_empty(): return []
	var sk: float = Game.skill_of("prep") / Game.staff_of("prep").size()
	var mult: float = prep_mult() * (1.25 - 0.08 * sk)
	var done := []
	for row in prep_list():
		if row.raw <= 0.0: continue
		var raw: float = row.raw
		var mins := Stock.prep_minutes(row.id, raw, mult)
		if mins > left.prep:
			raw *= left.prep / mins
			mins = left.prep
		if raw < 20.0: continue
		Stock.prep(row.id, raw, 0.6 + 0.1 * sk)
		left.prep -= mins
		done.append(Data.ING[row.id].name.to_lower())
		if left.prep <= 0.0: break
	var notes := []
	if done.size() > 0: notes.append("Your prep cook prepped the " + ", ".join(done) + ".")
	if left.prep > 10.0:
		var set_up := set_up_counter()
		left.prep -= set_up.minutes
		if set_up.filled > 0: notes.append("Your prep cook set up the counter: %d pans filled." % set_up.filled)
	return notes

## the toppings tonight's menu needs, most used first
func line_ids(day: int = -1) -> Array:
	var use := {}
	for r in Game.recipes_on(Game.s.day if day < 0 else day):
		for id in r.spec: use[id] = use.get(id, 0.0) + 1.0
	var ids := use.keys()
	ids.sort_custom(func(a, b): return use[a] > use[b])
	return ids

## give every topping on the menu a pan on the rail and fill them. Returns {filled, minutes, missing}
func set_up_counter() -> Dictionary:
	var out := {"filled": 0, "minutes": 0.0, "missing": Stock.assign_rail(line_ids())}
	for i in Stock.rail().size():
		var res := Stock.refill(i)
		if res.grams > 0:
			out.filled += 1
			out.minutes += res.minutes
	return out

# ---------- the evening ----------
## after service: the clock moves to closing and the staff do the close-down. Returns notes.
func start_evening() -> Array:
	var notes := []
	Game.s.clock = int(close_time()) + 15
	for e in Game.s.dock.duplicate():      # anything still at the back door gets shoved in at close
		var res := Stock.put_away(e, false, now())
		notes.append("%s's delivery was still at the back door at close. It was stacked in front of the old stock.%s" % [Data.SUP[e.sup].name, _waste_text(res)])
	notes.append_array(Stock.close_rail())
	var porters := Game.staff_of("porter")
	if porters.size() > 0:
		var washed := Stock.wash_all()
		if washed > 0: notes.append("Your kitchen porter washed %d tubs." % washed)
		var msg := Hygiene.clean("boh")
		var n := Hygiene.reset_traps()
		notes.append("Your kitchen porter deep-cleaned the kitchen%s.%s" % [(" and reset %d trap%s" % [n, "" if n == 1 else "s"]) if n > 0 else "", (" " + msg) if msg != "" else ""])
	if Game.staff_of("server").size() > 0 and Game.venue().tables > 0:
		var msg := Hygiene.clean("foh")
		notes.append("Your servers cleaned the dining room." + ((" " + msg) if msg != "" else ""))
	return notes

## going to bed: past midnight means a late start tomorrow
func sleep() -> void:
	Game.s.late_start = int(max(0.0, now() - 24.0 * 60.0))

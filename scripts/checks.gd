extends Node
## Autoload `Checks`: the opening and closing checklists, and the temperature log.
##
## Each item ticks itself off from the state of the kitchen: you do not tick a box, you do the job.
## Which items appear depends on who you are (Story.role()): a pizzaiolo only has prep, the counter and their
## station; a senior pizzaiolo or an owner has the full back-of-house list.
## Temperatures are recorded twice a day (morning and evening) per fridge and freezer. The inspector asks for them.

# ---------- the temperature log ----------
## "am" before service, "pm" after
func half() -> String:
	return "am" if Game.s.phase == "morning" else "pm"

func logged(store: String, day: int = -1, when: String = "") -> bool:
	var d: int = Game.s.day if day < 0 else day
	var w: String = half() if when == "" else when
	for e in Game.s.templog:
		if int(e.day) == d and e.when == w and e.store == store: return true
	return false

func stores_to_log() -> Array:
	return ["fridge", "freezer"] if Stock.store_cap("freezer") > 0 else ["fridge"]

func temp_of(store: String) -> float:
	return Stock.fridge_temp() if store == "fridge" else -18.0 + randf_range(-1.0, 1.0)

## write today's reading in the log (takes a minute). Returns the reading.
func record(store: String) -> float:
	if not Equip.thermo_for(store): return NAN
	var t: float = snapped(temp_of(store) + randf_range(-0.2, 0.2), 0.1)
	Game.s.templog.append({"day": Game.s.day, "when": half(), "store": store, "temp": t})
	while Game.s.templog.size() > 200: Game.s.templog.pop_front()
	return t

## share of the readings that should have been taken over the last `days` days that were
func log_rate(days: int = 7, since: int = 1) -> float:
	var want := 0
	var got := 0
	for d in range(max(since, Game.s.day - days), Game.s.day):
		for st in stores_to_log():
			for w in ["am", "pm"]:
				want += 1
				if logged(st, d, w): got += 1
	return float(got) / want if want > 0 else 1.0

# ---------- checklists ----------
## the items on today's opening ("open") or closing ("close") list: [{id, text, done, hint}]
func items(kind: String) -> Array:
	var role: String = Story.role()
	var out := []
	var boh: bool = role != "pizzaiolo"
	if kind == "open":
		if boh:
			for st in stores_to_log():
				out.append(_item("temp_" + st, "Record the %s temperature" % Data.STORE_NAME[st].to_lower(), logged(st, -1, "am"), "Jobs: temperature log"))
			out.append(_item("deliveries", "Check in today's deliveries before opening", Game.s.dock.is_empty() and not Day.pending().any(func(o): return o.eta < Day.open_time()), "Jobs: back door"))
			out.append(_item("traps", "Check and reset the traps", int(Game.s.pests.sprung) == 0 and int(Game.s.pests.laid) >= Hygiene.traps_wanted(), "Jobs: pest control"))
		var prep_done := true
		for row in Day.prep_list():
			if row.todo > row.need * 0.15 and row.raw > 0: prep_done = false
		out.append(_item("prep", "Do the prep list", prep_done, "Jobs: prep list"))
		var counter_done := true
		for id in Day.line_ids():
			var sl := Stock.rail_slot(id)
			if sl < 0 or Stock.rail()[sl].q < Stock.pan_cap(id) * 0.5:
				if Stock.refill_source(id) > 0.5 or sl < 0: counter_done = false
		out.append(_item("counter", "Set up the counter", counter_done, "Jobs: the counter"))
		if boh and Game.venue().tables > 0: out.append(_item("front", "Wipe down the dining room", Hygiene.level("foh") >= 80.0, "Jobs: cleaning"))
	else:
		if boh:
			for st in stores_to_log():
				out.append(_item("temp_" + st, "Record the %s temperature" % Data.STORE_NAME[st].to_lower(), logged(st, -1, "pm"), "Jobs: temperature log"))
		out.append(_item("kitchen", "Clean down the kitchen" if boh else "Clean your station", Hygiene.level("boh") >= (85.0 if boh else 70.0), "Jobs: cleaning"))
		out.append(_item("washup", "Wash up the tubs", Stock.dirty_tubs() == 0, "Jobs: prep list"))
		if boh:
			if Game.venue().tables > 0 or Game.s.venue > 0: out.append(_item("front", "Clean the front of house", Hygiene.level("foh") >= 85.0, "Jobs: cleaning"))
			out.append(_item("rotate", "Rotate the stores", Stock.rotation_problems().is_empty(), "Jobs: the stores"))
			var plan := Game.dough_plan()
			var short := 0
			for k in plan: short += plan[k]
			out.append(_item("dough", "Make tomorrow's dough", short == 0, "Dough"))
			var orders_ok := true
			for row in Market.par():
				if row.short_tomorrow > 0: orders_ok = false
			out.append(_item("orders", "Order tomorrow's stock", orders_ok, "Suppliers"))
		if role == "senior":
			out.append(_item("sheet", "Set tomorrow's prep list for the morning crew", int(Game.s.story.get("sheet_day", -1)) == Game.s.day + 1, "Jobs: tomorrow's prep list"))
	return out

func _item(id: String, text: String, done: bool, hint: String) -> Dictionary:
	return {"id": id, "text": text, "done": done, "hint": hint}

func rate(kind: String) -> float:
	var it := items(kind)
	if it.is_empty(): return 1.0
	var n := 0
	for x in it:
		if x.done: n += 1
	return float(n) / it.size()

## remember how much of the list got done today
func note(kind: String) -> void:
	var day: int = Game.s.day
	var rec: Dictionary = {}
	for e in Game.s.checklog:
		if int(e.day) == day: rec = e
	if rec.is_empty():
		rec = {"day": day, "open": -1.0, "close": -1.0}
		Game.s.checklog.append(rec)
		while Game.s.checklog.size() > 30: Game.s.checklog.pop_front()
	rec[kind] = rate(kind)

## average completion over the last few days
func recent(days: int = 7) -> float:
	var t := 0.0
	var n := 0
	for e in Game.s.checklog:
		if int(e.day) < Game.s.day - days: continue
		for k in ["open", "close"]:
			if e[k] >= 0:
				t += e[k]
				n += 1
	return t / n if n > 0 else 1.0

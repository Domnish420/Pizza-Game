extends Node
## Autoload `Story`: the career. Game.s.story = {stage, shifts: [scores], savings, sheet, sheet_day, ...}
##
##   free       sandbox: your own van from day one (no story)
##   pizzaiolo  employed at Bella Napoli. The boss sets the prep list, makes the dough and does the ordering.
##              You prep, set up the counter, make pizzas and clean your station. Paid a wage into your savings.
##   senior     senior pizzaiolo at Bella Napoli. You run the back of house: temperature logs, deliveries,
##              rotation, cleaning down, dough, ordering, and tomorrow's prep list, which the junior preps
##              before you get in. A hygiene inspection has to go well.
##   owner      you quit and buy the van with your savings: the sandbox, with career goals up to the flagship.
##
## Each employed shift gets a score from the boss (0-100). Enough good shifts and you are promoted.

const EMPLOYER := "Bella Napoli"
const BOSS := "Marco"
const JUNIOR := "Luca"
const WAGE := {"pizzaiolo": 95.0, "senior": 140.0}
const GOALS := {
	"pizzaiolo": {"shifts": 7, "score": 55.0, "over": 4},
	"senior": {"shifts": 7, "score": 70.0, "over": 7, "inspection": 3},
}
## The first shifts at each stage: what is yours to do, and how busy it is (a share of a normal day's customers).
## A pizzaiolo's first week: on day 1 you only stretch the bases, and Marco tops, bakes, cuts and sends them; on day 2
## you stretch and top, and he bakes and sends; on day 3 he stretches, and you top and work the oven (he cuts and
## sends); from day 4 you and Marco each make your own pizzas, slowly at first and busier every day. As senior (day 8,
## after the training day on the back of house) it is still quieter; by day 10 it is a normal restaurant service.
const STEPS := ["stretch", "top", "oven", "board"]
const PLAN := {
	"pizzaiolo": [
		{"jobs": ["stretch"], "pace": 0.22},
		{"jobs": ["stretch", "top"], "pace": 0.28},
		{"jobs": ["top", "oven"], "pace": 0.32},
		{"jobs": ["all"], "pace": 0.3},
		{"jobs": ["all"], "pace": 0.38},
		{"jobs": ["all"], "pace": 0.46},
		{"jobs": ["all"], "pace": 0.55}],
	"senior": [{"jobs": ["all"], "pace": 0.6}, {"jobs": ["all"], "pace": 0.8}, {"jobs": ["all"], "pace": 1.0}],
}

func stage() -> String:
	return String(Game.s.get("story", {}).get("stage", "free"))

## pizzaiolo / senior / owner (free play counts as owner)
func role() -> String:
	var st := stage()
	return st if st == "pizzaiolo" or st == "senior" else "owner"

func employed() -> bool:
	return role() != "owner"

## which shift this is at the current stage (the first is 1)
func shift_no() -> int:
	return stage_shifts().size() + 1 if employed() else 0

## this shift's plan: {jobs, pace} (after the planned days, the last one carries on)
func plan() -> Dictionary:
	var p: Array = PLAN.get(stage(), [])
	if p.is_empty(): return {"jobs": ["all"], "pace": 1.0}
	return p[min(stage_shifts().size(), p.size() - 1)]

## the steps of each pizza Marco does for you this shift ("stretch", "top", "oven", "board"): none once you make
## whole pizzas
func marco_does() -> Array:
	if stage() != "pizzaiolo": return []
	var j: Array = plan().jobs
	if "all" in j: return []
	return STEPS.filter(func(x): return not x in j)

## how busy employed shifts are: quiet at first, a normal day's trade by the senior's third shift
func traffic() -> float:
	return float(plan().pace) if employed() else 1.0

## what Marco says about today's shift, in the morning
func briefing() -> String:
	var n := shift_no()
	if stage() == "pizzaiolo":
		match n:
			1: return "Day one. Today you only stretch the bases. Take a ticket, open the dough out to the ring, then turn to the oven and hand it to me: I top it, bake it, cut it and send it. Luca has done the prep."
			2: return "Day two: you stretch and you top. Sauce, cheese and toppings to the recipe card, then hand it to me at the oven. I bake it and send it. Luca has done the prep again."
			3: return "Day three: I stretch the bases for you. You top them and work the oven: load them, turn them, pull them when they are ready. I cut them and send them."
			4: return "From today we each make our own pizzas, ticket to pass: stretch, top, bake, cut, send. We start slow. The prep and the counter are yours in the mornings now."
			5, 6: return "Busier today than yesterday. Keep up with the rail."
			7: return "Last day of your first week, and the busiest yet. Show me what you have learned."
		return "Another shift. Keep the rail moving."
	if stage() == "senior":
		match n:
			1: return "Your first day running the kitchen. We keep it quieter today."
			2: return "Busier today. The kitchen is yours."
			3: return "A full service today, like any other day from now on."
	return ""

## the shift Marco guides you into this morning (1: the first pizza of day 1; 2-4: a briefing), or 0
func guide_due() -> int:
	if stage() != "pizzaiolo" or Game.s.phase != "morning": return 0
	var n := shift_no()
	if n > 4 or bool(Game.s.story.get("guided_%d" % n, false)): return 0
	return n

## a line for the recipe card while Marco is doing part of every pizza
func today_short() -> String:
	var md := marco_does()
	if md.is_empty(): return ""
	var yours: Array = STEPS.filter(func(x): return not x in md)
	var words := {"stretch": "stretch", "top": "top", "oven": "bake", "board": "cut and send"}
	return "Today you %s; %s does the rest (%s)." % [" and ".join(yours.map(func(x): return words[x])), BOSS, ", ".join(md.map(func(x): return words[x]))]

## while Marco is doing part of every pizza (the first three days), Luca preps to the list and sets up the counter
## before you get in
func luca_preps() -> String:
	var done := []
	for row in Day.prep_list():
		if row.raw > 0.0 and row.get("block", "") == "":
			var res := Stock.prep(row.id, row.raw, 0.7)
			if res.made > 0: done.append(Data.ING[row.id].name.to_lower())
	var set_up := Day.set_up_counter()
	Stock.fold(Stock.boxes_needed() - Stock.folded())
	return "%s came in early: he prepped %s and set up the counter (%d pans)." % [JUNIOR, ", ".join(done) if done.size() > 0 else "what was needed", set_up.filled]

# ---------- starting out ----------
## a new career: you start as a pizzaiolo at someone else's pizzeria
func start() -> void:
	Game.new_game()
	var s: Dictionary = Game.s
	s.story = {"stage": "pizzaiolo", "shifts": [], "savings": 150.0, "sheet": {}, "sheet_day": -1, "started": s.day, "reviews": [], "training": ""}
	s.venue = 3
	s.tables = 12
	s.cash = 6000.0
	s.rep = 3.9
	s.ratings = 300
	var kit := {"oven": 2, "mixer": 3, "proofer": 2, "fridge": 4, "freezer": 3, "dry": 3, "roller": 1, "prep": 3, "dish": 2, "pest": 2,
		"pos": 2, "sign": 2, "marketing": 2, "drinks": 2, "delivery": 0, "furniture": 2, "ambience": 1, "comfort": 1}
	for k in kit: s.upg[k] = kit[k]
	Hygiene.move_out()
	Stock.take("traps", Stock.have("traps"))
	Hygiene.place_best(Hygiene.traps_wanted())
	Stock.add("tub4", 30, 2, 1.6)
	Stock.add("tub2", 16, 2, 1.1)
	Stock.add("sanitiser", 10000, 3, 0.0032)
	_crew("pizzaiolo")
	s.equip = Equip.starter("pizzeria")
	for st in ["fridge", "dry"]: s.vent[st] = int(round(Stock.vent_need(st)))
	# the boss has stocked up and made today's dough: plenty for the pizzas and the sides made from it (he does not run
	# out on his crew's first days)
	var c := Game.calc()
	var sides := 0.0
	for x in Game.extras_on():
		if x.make == "oven": sides += Game.extra_rate(x)
	s.dough = [{"style": "neapolitan", "n": int(ceil(c.total * (1.25 + sides * 1.3))) + 3, "q": 78, "d": 0, "speed": 0, "g": 3.0, "c": 0.3}]
	s.stock.erase("mozz")
	s.stock.erase("tomato")
	for e in [["flour00", 25000, 3], ["tomato", 5000, 3], ["mozz", 5000, 3], ["basil", 125, 2], ["pepperoni", 1000, 2], ["mushroom", 1000, 2], ["box", 50, 2],
			["garlicbutter", 2500, 2], ["cola", 48, 2], ["lemonade", 24, 2], ["water", 48, 1], ["coffee", 2000, 2], ["milk", 4000, 2]]:
		Stock.add(e[0], e[1], e[2], Data.ING[e[0]].g[e[2]].price)
	s.notes = ["%s: \"Morning! Welcome to %s. %s We open at %s.\"" % [BOSS, EMPLOYER, briefing(), Data.hhmm(Day.open_time())], luca_preps()]
	Game.save_game()

## the people working alongside you at each stage
func _crew(st: String) -> void:
	var s: Dictionary = Game.s
	var team := [["manager", BOSS, 4], ["pizzaiolo", JUNIOR, 2], ["server", "Sofia", 3], ["server", "Tom", 2], ["cashier", "Aisha", 3], ["porter", "Kofi", 2]]
	if st == "senior": team = [["pizzaiolo", JUNIOR, 2], ["server", "Sofia", 3], ["server", "Tom", 2], ["cashier", "Aisha", 3]]
	s.staff = []
	for t in team:
		s.staff.append({"id": s.sid, "role": t[0], "name": t[1], "skill": t[2], "wage": int(Data.ROLES[t[0]].wage)})
		s.sid += 1

# ---------- the day ----------
## the morning: as senior, the junior has done the prep to your list. Returns notes.
func morning() -> Array:
	var notes := []
	var st: Dictionary = Game.s.get("story", {})
	if stage() == "pizzaiolo":
		notes.append("%s: \"%s\"" % [BOSS, briefing()])
		if not marco_does().is_empty(): notes.append(luca_preps())
	elif stage() == "senior" and shift_no() <= 3 and Game.s.day >= int(st.get("promoted", 0)):
		notes.append("%s: \"%s\"" % [BOSS, briefing()])
	if stage() == "senior" and int(st.get("sheet_day", -1)) == Game.s.day and not st.sheet.is_empty():
		var done := []
		for id in st.sheet:
			var want: float = st.sheet[id]
			var have: float = Stock.prepped(id) + Stock.rail_have(id)
			if want <= have + 1.0: continue
			var raw: float = min((want - have) / float(Data.ING[id].prep.yield), Stock.have(id))
			if raw <= 1.0: continue
			var res := Stock.prep(id, raw, 0.7)
			if res.made > 0: done.append("%s %s" % [Data.qty(id, res.made), Data.ING[id].name.to_lower()])
		var set_up := Day.set_up_counter()
		var boxes := Stock.fold(Stock.boxes_needed() - Stock.folded())
		notes.append("%s came in early and prepped to your list: %s. %s set up the counter (%d pans)%s." % [JUNIOR, ", ".join(done) if done.size() > 0 else "nothing needed doing", JUNIOR, set_up.filled, (" and folded %d boxes" % boxes) if boxes > 0 else ""])
	elif stage() == "senior" and Game.s.day > int(st.get("promoted", 0)):
		notes.append("There was no prep list for %s this morning, so nothing was prepped before you got in." % JUNIOR)
	return notes

## the evening: the boss makes the dough while you are a pizzaiolo
func evening() -> Array:
	if stage() != "pizzaiolo": return []
	# the boss keeps the temperature log while you are learning
	for st in Checks.stores_to_log():
		for w in ["am", "pm"]:
			if not Checks.logged(st, -1, w): Game.s.templog.append({"day": Game.s.day, "when": w, "store": st, "temp": snapped(Checks.temp_of(st), 0.1)})
	var plan := Game.dough_plan()
	var made := 0
	for sty in plan:
		var balls: int = int(ceil(plan[sty] * 1.15)) + 2 if plan[sty] > 0 else 0     # (the boss keeps a little over)
		if balls <= 0: continue
		var per := Stock.dough_parts(sty, Stock.flour_per_ball(sty))
		for ing in per:
			if ing != "water": balls = int(min(balls, floor(Stock.have(ing) / per[ing])))
		balls = min(balls, Equip.dough_room())
		if balls <= 0: continue
		for ing in per:
			if ing != "water": Stock.take(ing, per[ing] * balls)
		made += Stock.add_dough(sty, balls, 78, 0, 3.0, 0.3)
	return ["%s made tomorrow's dough (%d balls) and placed the orders." % [BOSS, made]] if made > 0 else []

## set tomorrow's prep list (senior): ingredient -> grams prepped
func set_sheet(sheet: Dictionary) -> void:
	Game.s.story.sheet = sheet
	Game.s.story.sheet_day = Game.s.day + 1

# ---------- the boss's review ----------
## after the shift: score it, pay the wage, maybe promote. r = the day's report. Returns {score, lines, promoted, pay}
func review(r: Dictionary) -> Dictionary:
	if not employed(): return {}
	var st: Dictionary = Game.s.story
	var lines := []
	var parts := {}
	var open_rate: float = _checklog("open")
	var close_rate := Checks.rate("close")
	parts.checks = (max(open_rate, 0.0) + close_rate) / 2.0 * 100.0
	if stage() == "pizzaiolo":
		var mine: int = r.get("mine", 0)
		var q: float = r.get("mine_q", 0.0) / mine if mine > 0 else 0.0
		var need: float = max(2.0, round(9.0 * float(plan().pace)))       # a quiet first day needs fewer than a busy one
		parts.pizzas = q * clamp(mine / need, 0.0, 1.0)
		var over: float = (r.get("mine_cost", 0.0) - r.get("mine_spec", 0.0)) / max(r.get("mine_spec", 0.0), 0.01)
		parts.portions = clamp(100.0 - abs(over) * 250.0, 0.0, 100.0) if mine > 0 else 0.0
		var score: float = parts.pizzas * 0.45 + parts.portions * 0.2 + parts.checks * 0.35
		lines.append("You made %d pizzas, averaging %d." % [mine, q])
		if mine < need: lines.append("I need you making more pizzas. Take tickets as soon as they come in.")
		elif q < 65: lines.append("The pizzas need work: watch the stretch, the spread and the bake.")
		if over > 0.08: lines.append("Your portions were heavy, %d%% over the recipe cards. That is my margin." % (over * 100))
		elif over < -0.1: lines.append("You were stingy with the toppings. Customers notice.")
		if open_rate < 0.99: lines.append("The prep list and the counter were not finished before we opened.")
		if close_rate < 0.99: lines.append("Your station was not cleaned down properly tonight.")
		return _finish_review(score, lines, parts)
	# senior: the whole back of house
	var waste_rate: float = r.get("cost_waste", 0.0) / max(r.get("cost_used", 0.0), 1.0)
	parts.waste = clamp(100.0 - max(0.0, waste_rate - 0.03) * 600.0, 0.0, 100.0)
	var stars := 0.0
	if r.get("n_rev", 0) > 0:
		for k in r.cats: stars += r.cats[k] / 4.0
	parts.customers = clamp((stars - 1.0) / 4.0 * 100.0, 0.0, 100.0)
	var since: int = int(Game.s.story.get("promoted", 1))
	var logs := Checks.log_rate(3, since) if Game.s.day > since else (1.0 if Checks.logged("fridge", -1, "pm") else 0.5)
	parts.hygiene = (Hygiene.level("boh") * 0.6 + Hygiene.level("foh") * 0.4) * (0.6 + 0.4 * logs)
	var score: float = parts.checks * 0.35 + parts.waste * 0.2 + parts.customers * 0.25 + parts.hygiene * 0.2
	lines.append("Customers gave us %.1f today. Waste was %d%% of the food we used." % [stars, waste_rate * 100])
	if waste_rate > 0.08: lines.append("Too much went in the bin. Order closer to what we use and rotate properly.")
	if r.get("lost", 0) > r.get("served", 0) * 0.15: lines.append("We lost too many customers. Was the prep list right?")
	if logs < 0.9: lines.append("The temperature log has gaps. The inspector will ask for it.")
	if open_rate < 0.99 or close_rate < 0.99: lines.append("The checklists were not finished.")
	return _finish_review(score, lines, parts)

func _checklog(kind: String) -> float:
	for e in Game.s.checklog:
		if int(e.day) == Game.s.day: return e[kind]
	return -1.0

func _finish_review(score: float, lines: Array, parts: Dictionary) -> Dictionary:
	var st: Dictionary = Game.s.story
	score = clamp(score, 0.0, 100.0)
	if lines.size() <= 1: lines.append("Good shift. Keep it up." if score >= 70 else "We will get there.")
	var pay: float = WAGE[stage()]
	st.savings += pay
	st.shifts.append({"day": Game.s.day, "stage": stage(), "score": score})
	var out := {"score": score, "lines": lines, "pay": pay, "parts": parts, "promoted": ""}
	if ready():
		out.promoted = "senior" if stage() == "pizzaiolo" else "owner"
	return out

## shifts and their scores at the current stage
func stage_shifts() -> Array:
	return Game.s.story.shifts.filter(func(x): return x.stage == stage())

func avg_score(last: int = 5) -> float:
	var sh := stage_shifts()
	sh = sh.slice(max(0, sh.size() - last))
	var t := 0.0
	for x in sh: t += x.score
	return t / sh.size() if sh.size() > 0 else 0.0

## what is left before the next promotion: [[text, done]]
func goals() -> Array:
	if not employed(): return _owner_goals()
	var g: Dictionary = GOALS[stage()]
	var out := []
	out.append(["Work %d shifts (%d so far)" % [g.shifts, stage_shifts().size()], stage_shifts().size() >= g.shifts])
	out.append(["Average %d or more from %s over your last %d (%d)" % [g.score, BOSS, g.over, avg_score(g.over)], avg_score(g.over) >= g.score and stage_shifts().size() > 0])
	if stage() == "senior":
		var H: Dictionary = Game.s.hygiene
		var ok: bool = int(H.rating) >= g.inspection and int(H.day) >= int(Game.s.story.get("promoted", 0))
		out.append(["Pass a hygiene inspection with %d or better (%s)" % [g.inspection, Hygiene.rating_text() if int(H.day) >= int(Game.s.story.get("promoted", 0)) and int(H.rating) >= 0 else "not yet"], ok])
	return out

func ready() -> bool:
	for g in goals():
		if not g[1]: return false
	return employed()

func _owner_goals() -> Array:
	var out := []
	for i in range(1, Data.VENUES.size()):
		out.append(["Open a %s" % Data.VENUES[i].name, Game.s.venue >= i])
	return out

# ---------- promotions ----------
func promote() -> String:
	var st: Dictionary = Game.s.story
	if stage() == "pizzaiolo":
		st.stage = "senior"
		st.promoted = Game.s.day + 1
		st.training = "senior"          # a training day before the first senior shift (see Tutor)
		_crew("senior")
		Game.s.hygiene.next = Game.s.day + randi_range(3, 5)
		Game.save_game()
		return "%s: \"I am going to be away more. From tomorrow you are my senior pizzaiolo: you run the kitchen. Temperatures, deliveries, rotation, the dough, the ordering, the closing checks, and tomorrow's prep list for %s every night. Your pay goes up to %s a shift.\"" % [BOSS, JUNIOR, Kit.money(WAGE.senior)]
	if stage() == "senior":
		go_solo()
		return "%s: \"I knew this day would come. Go and do it yourself, and come back and tell me how hard it is.\"\n\nYou hand in your notice and buy a second-hand pizza van. You have %s to get started." % [BOSS, Kit.money(Game.s.cash)]
	return ""

## leave Bella Napoli: a fresh van of your own, keeping what you learned (level) and what you saved
func go_solo() -> void:
	var keep := {"level": Game.s.level, "xp": Game.s.xp, "mute": Game.s.mute, "story": Game.s.story}
	Game.new_game()
	Game.s.level = keep.level
	Game.s.xp = keep.xp
	Game.s.mute = keep.mute
	Game.s.story = keep.story
	Game.s.story.stage = "owner"
	Game.s.cash = keep.story.savings
	Game.gen_offers()
	Game.gen_cands()
	Game.s.notes = ["Day one in your own van. Nobody sets your list now: order, prep, open, clean, and do it all again tomorrow."]
	Game.save_game()

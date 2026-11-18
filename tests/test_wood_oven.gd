extends "res://tests/bot.gd"
## The wood oven's physics: the fire, the dome, the deck grid and how each pizza bakes from where it sits.

var OV: GDScript
var PZ: GDScript

func oven(lit_minutes_before: float) -> Object:
	var tier = null
	for x in D.UPG.oven.tiers:
		if x.type == "wood": tier = x; break
	var o = OV.new(tier)
	o.start_day(lit_minutes_before)
	for i in 300: o.step(0.1, 1.0)            # 30 s into service
	return o

func pizza() -> Object:
	var p = PZ.new({"rec": D.REC["margherita"], "id": 1}, {"q": 70.0, "cost": 0.5, "g": 3.0})
	for j in 24:
		p.base.r[j] = p.base.R
		p.base.rim[j] = p.base.crust
	return p

## bake one pizza at a spot until it is done on average; turn it a quarter every `turn_every` seconds (0 = never)
func bake_one(at: Vector2, turn_every: float) -> Dictionary:
	var o = oven(120)
	var p = pizza()
	var it = o.load_pizza(p, 0, false, at)
	var t := 0.0
	var next_turn := turn_every
	while t < 60.0:
		o.step(0.1, 1.0)
		t += 0.1
		if turn_every > 0.0 and t >= next_turn:
			p.turn += PI / 2.0
			next_turn += turn_every
		if p.bake_avg() >= 1.0: break
	var rg: Array = p.bake_range()
	return {"t": snappedf(t, 0.1), "spread": snappedf(rg[1] - rg[0], 0.01), "status": o.status(it)}

func run() -> void:
	OV = load("res://scripts/oven.gd")
	PZ = load("res://scripts/pizza.gd")
	var FIRE := Vector2(160, 129)
	var MID := Vector2(241, 129)
	var MOUTH := Vector2(327, 190)

	var o = oven(120)
	check(o.dome > 420 and o.fire_word() == "just right", "lit two hours before opening, it is ready", [int(o.dome), o.fire_word()])
	check(o.deck_at(Vector2(150, 130)) > o.deck_at(Vector2(241, 200)) + 50, "the deck is hottest by the fire",
		[int(o.deck_at(Vector2(150, 130))), int(o.deck_at(Vector2(241, 200)))])
	check(not o.spot_ok(Vector2(70, 129)) and o.spot_ok(FIRE), "a pizza can go next to the fire but not on it")

	var fire0 := bake_one(FIRE, 0.0)
	var fire1 := bake_one(FIRE, 2.0)
	var mouth0 := bake_one(MOUTH, 0.0)
	var mid0 := bake_one(MID, 0.0)
	note("by the fire %s, turned %s, middle %s, mouth %s" % [fire0, fire1, mid0, mouth0])
	check(fire0.t < mid0.t and mid0.t < mouth0.t, "pizzas bake faster the nearer the fire", [fire0.t, mid0.t, mouth0.t])
	check(fire0.status == "BURNING", "by the fire and never turned, one side burns", fire0.status)
	check(fire1.status == "READY" and fire1.spread < fire0.spread / 3.0, "turned often, it colours evenly", [fire1.spread, fire0.spread])
	check(mouth0.status == "READY", "by the mouth it bakes evenly even unturned", mouth0)

	# the deck cools under a pizza and recovers
	var o2 = oven(120)
	var t0: float = o2.deck_at(MID)
	var it = o2.load_pizza(pizza(), 0, false, MID)
	for i in 100: o2.step(0.1, 1.0)
	var t1: float = o2.deck_at(MID)
	o2.items.erase(it)
	for i in 200: o2.step(0.1, 1.0)
	var t2: float = o2.deck_at(MID)
	check(t1 < t0 - 30 and t2 > t1 + 30, "the deck cools under a pizza and recovers after", [int(t0), int(t1), int(t2)])

	# not fed, the fire dies and the dome cools; fed a log every 35 s, it holds
	var o3 = oven(120)
	var d30 := 0.0
	for k in 4:
		for i in 300: o3.step(0.1, 1.0)
		if k == 0: d30 = o3.dome
	check(o3.dome < d30 - 100 and o3.fire_word() == "dying", "not fed for two minutes, the fire dies", [int(d30), int(o3.dome), o3.fire_word()])
	var o4 = oven(120)
	for k in 6:
		o4.add_log(2.0)
		for i in 350: o4.step(0.1, 1.0)
	check(o4.dome > 450 and o4.fire_word() == "just right", "fed a log every 35 s, it holds", [int(o4.dome), o4.fire_word()])
	var o5 = oven(120)
	for k in 4: o5.add_log(2.0)
	for i in 300: o5.step(0.1, 1.0)
	check(o5.fire_word() == "fierce", "four logs at once roar", o5.fire_word())

	# never lit, then lit in service
	var o6 = oven(-1)
	check(o6.dome < 50 and o6.fire_word() == "out", "never lit, it is cold", [int(o6.dome), o6.fire_word()])
	for k in 3: o6.add_log(2.0)
	for i in 600: o6.step(0.1, 1.0)
	check(o6.dome > 300 and o6.deck_at(MID) > 200, "lit cold in service, it is usable in about a minute", [int(o6.dome), int(o6.deck_at(MID))])

	# the longer it was lit before opening, the hotter
	var domes := []
	for mins in [30, 60, 90, 120, 150]:
		var o7 = OV.new(o.tier)
		o7.start_day(mins)
		domes.append(int(o7.dome))
	var rising := true
	for i in range(1, domes.size()): rising = rising and domes[i] > domes[i - 1]
	check(rising and domes[0] < 300 and domes[-1] > 430, "lighting it earlier means a hotter oven at opening", domes)

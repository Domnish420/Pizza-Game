class_name Oven
extends RefCounted
## The oven: where each pizza sits on the deck, how the heat reaches it, and the fire.
##
## An electric deck is all ambient, so pizzas bake evenly. Gas has burners at the back. A rotating hearth turns the
## pizzas for you. Oven types and their numbers are in data/upgrades.json ("ovens").
##
## A wood oven is simulated (see the "wood fire" section): logs catch, flare and burn down to a bed of coals; the dome
## heats up and cools down slowly behind the fire; the deck is a grid of temperatures, hottest by the fire, cooler
## toward the mouth, and it cools under every pizza and recovers after. Each pizza bakes from where it actually sits:
## its underside from the deck under it, each edge from the dome plus the flames' radiant heat, which is strongest on
## the edge squarely facing the fire and falls off with distance. So pizzas by the fire bake fast and char on that
## side unless you turn them, pizzas by the mouth bake slower and more evenly, and the oven must be lit long before
## service (the morning job) and kept fed with logs.

const VW := 400.0          # the oven view is VW x VH units
const VH := 320.0
const SHELF := 2           # pizzas that can wait on the landing shelf
const SHELF_POS := [Vector2(140, 284), Vector2(260, 284)]
const MOUTH := 250.0       # the mouth line on the deck map (OvenView.MOUTH_Y)
## a dome oven's floor is an ellipse (the vault in tools/models/fixtures.py, VX/VZ/VRX/VRZ, in deck-map units), and the
## entrance tunnel in front of it, between the mouth's sides
const FLOOR_C := Vector2(200.0, 124.5)
const FLOOR_R := Vector2(197.9, 121.3)
const TUNNEL := Vector3(34.0, 366.0, 186.0)       # its sides (x from, x to) and where it opens into the vault (y)

var tier: Dictionary
var kind := "electric"
var def: Dictionary
var slots := 2
var bake_time := 22.0
var pos := []              # centre of each deck spot
var prad := 40.0           # radius a 30 cm pizza is drawn at
var area := Rect2()        # the part of the chamber pizzas sit in
var fire_pos := Vector2.ZERO
var far := 300.0
var fire := 1.0            # wood only: how hot the fire is. 1.0 is right, below 0.6 is dying, above 1.2 is fierce
var wood_grade := 2.0
var items := []            # on the deck: {slot, at (where it sits on the deck), owner "me"/"staff", pz, tk, q, p, mult, auto}
var shelf := []            # your pizzas waiting to go in

func _init(t: Dictionary) -> void:
	tier = t
	kind = t.type
	def = Data.OVENS[kind]
	slots = int(t.slots)
	bake_time = float(t.bake)
	if def.feeds or kind == "rotary":
		area = Rect2(112, 26, 258, 206)
		fire_pos = Vector2(58, 129)
	else:
		area = Rect2(40, 30, 320, 196)
	var cols := int(ceil(sqrt(slots * area.size.x / area.size.y)))
	var rows := int(ceil(float(slots) / cols))
	var cw := area.size.x / cols
	var ch := area.size.y / rows
	prad = min(min(cw, ch) * 0.44, 46.0)
	far = 1.0
	for i in slots:
		var p := area.position + Vector2(cw * (i % cols + 0.5), ch * (i / cols + 0.5))
		pos.append(p)
		far = max(far, p.distance_to(fire_pos))

# ---------- the deck ----------
func free_slot() -> int:
	for i in slots:
		if item_in(i) == null: return i
	return -1

func item_in(slot: int):
	for o in items:
		if o.slot == slot: return o
	return null

func mine() -> Array:
	return items.filter(func(o): return o.owner == "me")

func load_pizza(pz: Pizza, slot: int, auto: bool, at: Vector2 = Vector2.INF) -> Dictionary:
	shelf.erase(pz)
	pz.stage = "oven"
	var o := {"slot": slot, "at": pos[slot] if at == Vector2.INF else at, "owner": "me", "pz": pz, "mult": float(pz.d.bake), "auto": auto, "p": 0.0}
	items.append(o)
	return o

func load_staff(tk: Dictionary, slot: int) -> void:
	items.append({"slot": slot, "at": pos[slot], "owner": "staff", "tk": tk, "p": 0.0, "mult": float(Data.DOUGHS[tk.rec.base].bake), "auto": true})

## where a pizza can sit, on a deck you can place pizzas on freely (a wood oven): inside the chamber, off the fire,
## not on top of another pizza
func free_place() -> bool:
	return def.feeds

func spot_ok(p: Vector2, except = null) -> bool:
	if not on_floor(p, prad): return false
	if def.fire > 0.0 and kind != "gas" and p.distance_to(fire_pos) < 52.0 + prad * 0.85: return false
	for o in items:
		if o != except and p.distance_to(o.at) < prad * 1.85: return false
	return true

## a circle of radius r at p lies on the deck: inside a dome oven's elliptical floor (or the tunnel in front of it),
## or inside a deck oven's rectangle; never past the mouth
func on_floor(p: Vector2, r: float) -> bool:
	if p.x < r + 8.0 or p.x > 383.0 - r or p.y < 14.0 + r or p.y > MOUTH - r * 0.5: return false
	if not (def.feeds or kind == "rotary"): return true
	if p.y >= TUNNEL.z and p.x >= TUNNEL.x + r and p.x <= TUNNEL.y - r: return true
	var q := (p - FLOOR_C) / (FLOOR_R - Vector2(r, r) * 0.85)
	return q.length_squared() <= 1.0

# ---------- heat ----------
func level() -> float:
	return clamp((dome - 150.0) / 330.0, 0.1, 1.5) if def.feeds else 1.0

## heat reaching the edge of a pizza at `at` that faces world angle `ang` (deck ovens and the rotary hearth)
func heat(at: Vector2, ang: float) -> float:
	if def.fire <= 0.0: return def.ambient * level()
	var facing := -PI / 2.0
	var k := 1.0
	if kind != "gas":
		var v: Vector2 = fire_pos - at
		facing = v.angle()
		k = lerp(1.25, 0.8, clamp(v.length() / far, 0.0, 1.0))
	return (def.ambient + def.fire * k * (1.0 + cos(ang - facing)) / 2.0) * level()

func add_log(grade: float) -> void:
	wood_grade = grade
	if not def.feeds:
		fire = min(1.5, fire + 0.4)
		return
	logs.append({"age": 0.0, "m": 1.0, "g": grade})
	fire = power()

## move everything on by dt seconds. speed scales bake time (below 1 = faster). Returns staff pizzas that are done.
func step(dt: float, speed: float) -> Array:
	var done := []
	if def.feeds: _burn(dt)
	for o in items.duplicate():
		var t: float = bake_time * speed * o.mult
		if o.owner == "staff":
			o.p += level() * dt / t
			if o.p >= 1.0:
				items.erase(o)
				done.append(o)
			continue
		var pz: Pizza = o.pz
		if def.spin > 0.0: pz.turn += def.spin * dt
		elif o.auto and def.fire > 0.0: pz.turn += 1.3 * dt
		if def.feeds:
			_bake_wood(o, pz, dt, t)
		else:
			for j in Pizza.NSEC:
				var h := heat(o.at, j * TAU / Pizza.NSEC + pz.turn)
				pz.bake[j] += h * dt / t * (def.soft if pz.bake[j] > 1.0 else 1.0)
				_spot(pz, j, (h - def.ambient * level()) * 0.8, dt, t)          # (gas flames spot it a little; elements barely)
			pz.floor += (def.ambient + def.fire * 0.5) * level() * dt / t * (def.soft if pz.floor > 1.0 else 1.0)
		o.p = pz.bake_avg()
	return done

# ---------- the wood fire ----------
const GW := 20             # the deck as a grid of temperatures: 20 x 13 cells of 20 units (the map's 400 x 260)
const GH := 13
const GC := 20.0
const DOME_HOT := 480.0    # the dome with a good fire: two logs burning on a bed of coals
const FIRE_REACH := 90.0   # how far the flames' heat carries (deck units, about 21 cm)

var logs := []             # burning: {age (s), m (what is left, 1 to 0), g (grade)}
var coals := 0.0           # the bed of embers (1 = a good bed)
var dome := 480.0          # degrees C under the dome
var deck := PackedFloat32Array()
var lit := true            # false: a cold oven that has to be lit

## the flames: each log catches (slowly on a cold hearth), burns, and fades to nothing as it burns down
func flame() -> float:
	var f := 0.0
	for l in logs:
		var catch: float = min(1.0, l.age / (12.0 if coals > 0.25 else 30.0))
		f += catch * 0.5 * (0.85 + 0.075 * l.g) * (0.4 + 0.6 * min(1.0, l.m / 0.25))
	return f

## all the heat the fire gives: flames and coals
func power() -> float:
	return flame() + 0.45 * coals

## the heat the fire will give once every log on it has caught: whoever tends it goes by this, so they do not keep
## throwing logs on while the last one takes
func power_soon() -> float:
	var f := 0.0
	for l in logs: f += 0.5 * (0.85 + 0.075 * l.g) * (0.4 + 0.6 * min(1.0, l.m / 0.25))
	return f + 0.45 * coals

## logs that have not caught properly yet
func catching() -> int:
	return logs.filter(func(l): return l.age < (12.0 if coals > 0.25 else 30.0)).size()

func dome_target() -> float:
	var p := power()
	return 20.0 + (DOME_HOT - 20.0) * p / (0.3 + 0.7 * p) if p > 0.0 else 20.0

## the deck centre of cell i on the map
func cell_at(i: int) -> Vector2:
	return Vector2((i % GW + 0.5) * GC, (i / GW + 0.5) * GC)

## what a spot on the deck heads for under this dome: hotter near the fire and over the coals, cooler by the mouth
func deck_target(c: Vector2, d_dome: float) -> float:
	var d := c.distance_to(fire_pos)
	var near := exp(-pow(d / 150.0, 2))
	var mouth := 1.0 - 0.12 * pow(clamp(c.y / MOUTH, 0.0, 1.0), 2)
	return 20.0 + (d_dome - 20.0) * (0.9 + 0.24 * near) * mouth + coals * 90.0 * exp(-pow(d / 80.0, 2))

func deck_at(p: Vector2) -> float:
	if deck.is_empty(): return dome
	var gx := clampi(int(p.x / GC), 0, GW - 1)
	var gy := clampi(int(p.y / GC), 0, GH - 1)
	return deck[gy * GW + gx]

## the logs burn down, the coals build and fade, the dome follows the fire, the deck follows the dome and cools
## under every pizza on it
func _burn(dt: float) -> void:
	if deck.is_empty(): _fill_deck(dome)
	for l in logs:
		l.age += dt
		var life: float = 70.0 * (1.0 + 0.15 * (l.g - 2.0))
		var b: float = min(1.0, l.age / 12.0) * dt / life
		l.m -= b
		coals += b * 0.35
	logs = logs.filter(func(l): return l.m > 0.0)
	coals = clamp(coals - dt * coals / 110.0, 0.0, 1.6)
	dome += (dome_target() - dome) * (1.0 - exp(-dt / 40.0))
	var k := 1.0 - exp(-dt / 28.0)
	for i in GW * GH:
		var c := cell_at(i)
		var tv: float = deck[i]
		tv += (deck_target(c, dome) - tv) * k
		for o in items:
			if c.distance_to(o.at) < prad: tv -= 0.035 * max(0.0, tv - 150.0) * dt
		deck[i] = tv
	fire = power()
	lit = power() > 0.02 or dome > 150.0

func _fill_deck(d_dome: float) -> void:
	deck.resize(GW * GH)
	for i in GW * GH: deck[i] = deck_target(cell_at(i), d_dome)

## the day starts: the oven was lit `minutes` (game minutes) before opening and kept going, or (-1) never lit
func start_day(minutes: float, grade: float = 2.0) -> void:
	if not def.feeds: return
	wood_grade = grade
	logs = []
	if minutes < 0.0:
		dome = 20.0
		coals = 0.0
		deck.resize(GW * GH)
		deck.fill(20.0)
		lit = false
		fire = 0.0
		return
	dome = 20.0 + (DOME_HOT - 20.0) * (1.0 - exp(-minutes / 45.0))
	coals = min(1.0, minutes / 60.0)
	deck.resize(GW * GH)
	for i in GW * GH:
		var full := deck_target(cell_at(i), DOME_HOT)
		deck[i] = 20.0 + (full - 20.0) * (1.0 - exp(-minutes / 55.0))
	for k in 2: logs.append({"age": 20.0, "m": 0.8, "g": grade})          # kept fed: two logs going at opening
	lit = true
	fire = power()

## the dome's heat for a morning oven lit `minutes` ago (for the kitchen between services)
static func warm_dome(minutes: float) -> float:
	return 20.0 + (DOME_HOT - 20.0) * (1.0 - exp(-max(0.0, minutes) / 45.0))

## one pizza in the wood oven: the floor from the deck under it; each edge from the dome plus the flames, by how
## squarely it faces the fire and how far it is from it
func _bake_wood(o: Dictionary, pz: Pizza, dt: float, t: float) -> void:
	var r: float = prad * pz.base.R / 106.0
	var dr: float = clamp((dome - 200.0) / 280.0, 0.0, 1.8)
	var under: float = (deck_at(o.at) * 2.0 + deck_at(o.at + Vector2(r * 0.5, 0)) + deck_at(o.at - Vector2(r * 0.5, 0)) + deck_at(o.at + Vector2(0, r * 0.5)) + deck_at(o.at - Vector2(0, r * 0.5))) / 6.0
	var fr: float = clamp((under - 150.0) / 250.0, 0.0, 2.2)
	var fl := flame() + 0.3 * coals
	for j in Pizza.NSEC:
		var a: float = j * TAU / Pizza.NSEC + pz.turn
		var e: Vector2 = o.at + Vector2.from_angle(a) * r
		var v: Vector2 = fire_pos - e
		var facing: float = max(0.0, cos(v.angle() - a))
		var flames: float = 0.95 * fl * facing * min(3.0, pow(FIRE_REACH / max(v.length(), 40.0), 2))
		var h: float = 0.75 * dr + flames
		pz.bake[j] += h * dt / t * (def.soft if pz.bake[j] > 1.0 else 1.0)
		_spot(pz, j, flames, dt, t)
	pz.floor += fr * dt / t * (def.soft if pz.floor > 1.0 else 1.0) * (0.35 if o.get("lifted", false) else 1.0)

## leopard spots: once the crust has set, the flames' radiant heat blisters it in dark spots, more where it hits harder
## (a good spotting all round comes from turning the pizza so each side meets the fire in turn; left facing the fire, one
## side scorches)
const SPOT_HEAT := 0.4
func _spot(pz: Pizza, j: int, flames: float, dt: float, t: float) -> void:
	if pz.bake[j] < 0.4 or flames <= SPOT_HEAT: return
	pz.spots[j] += (flames - SPOT_HEAT) * dt / t * 4.0

## a word on the fire, as you would judge it by eye
func fire_word() -> String:
	var p := power()
	if p < 0.05: return "out" if dome < 150.0 else "out, just coals cooling"
	if p < 0.6: return "dying"
	if p < 0.95: return "low"
	if p <= 1.75: return "just right"
	return "fierce"

## the hottest and coolest spots pizzas can sit on
func deck_range() -> Array:
	var mn := 9999.0
	var mx := -9999.0
	for i in GW * GH:
		var c := cell_at(i)
		if not on_floor(c, prad) or c.distance_to(fire_pos) < 52.0 + prad * 0.85: continue
		mn = min(mn, deck[i])
		mx = max(mx, deck[i])
	return [mn, mx] if mx > -9000.0 else [dome, dome]

## a short word on how one of your pizzas is doing
func status(o: Dictionary) -> String:
	var pz: Pizza = o.pz
	var rng := pz.bake_range()
	var avg := pz.bake_avg()
	if rng[1] > 1.4: return "BURNING"
	var tg: float = pz.bake_target
	if avg >= 0.95 * tg and rng[0] >= 0.85 * tg: return "READY"
	if def.fire > 0.0 and def.spin <= 0.0 and not o.auto and rng[1] - rng[0] > 0.22: return "TURN"
	if avg >= 1.12 * tg: return "OVERDONE"
	return "baking"

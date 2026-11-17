class_name Oven
extends RefCounted
## The oven: where each pizza sits on the deck, how the heat reaches it, and the fire.
##
## Heat on any edge of a pizza = ambient + fire x (how squarely that edge faces the flame).
## An electric deck is all ambient, so pizzas bake evenly. Gas has burners at the back. A wood oven has a
## live fire at one side: the edge facing it browns far faster, spots nearer the fire run hotter, and the
## fire itself dies down unless it is fed. A rotating hearth turns the pizzas for you.
## Oven types and their numbers are in data/upgrades.json ("ovens").

const VW := 400.0          # the oven view is VW x VH units
const VH := 320.0
const SHELF := 2           # pizzas that can wait on the landing shelf
const SHELF_POS := [Vector2(140, 284), Vector2(260, 284)]

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
var items := []            # on the deck: {slot, owner "me"/"staff", pz, tk, q, p, mult, auto}
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

func load_pizza(pz: Pizza, slot: int, auto: bool) -> Dictionary:
	shelf.erase(pz)
	pz.stage = "oven"
	var o := {"slot": slot, "owner": "me", "pz": pz, "mult": float(pz.d.bake), "auto": auto, "p": 0.0}
	items.append(o)
	return o

func load_staff(tk: Dictionary, slot: int) -> void:
	items.append({"slot": slot, "owner": "staff", "tk": tk, "p": 0.0, "mult": float(Data.DOUGHS[tk.rec.base].bake), "auto": true})

# ---------- heat ----------
func level() -> float:
	return clamp(fire, 0.35, 1.4) if def.feeds else 1.0

## heat reaching the edge of the pizza in `slot` that faces world angle `ang`
func heat(slot: int, ang: float) -> float:
	if def.fire <= 0.0: return def.ambient * level()
	var facing := -PI / 2.0
	var k := 1.0
	if kind != "gas":
		var v: Vector2 = fire_pos - pos[slot]
		facing = v.angle()
		k = lerp(1.25, 0.8, clamp(v.length() / far, 0.0, 1.0))
	return (def.ambient + def.fire * k * (1.0 + cos(ang - facing)) / 2.0) * level()

func add_log(grade: float) -> void:
	wood_grade = grade
	fire = min(1.5, fire + 0.4)

## move everything on by dt seconds. speed scales bake time (below 1 = faster). Returns staff pizzas that are done.
func step(dt: float, speed: float) -> Array:
	var done := []
	if def.feeds: fire = max(0.2, fire - dt / (120.0 * (1.0 + 0.15 * (wood_grade - 2.0))))
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
		for j in Pizza.NSEC:
			var h := heat(o.slot, j * TAU / Pizza.NSEC + pz.turn)
			pz.bake[j] += h * dt / t * (def.soft if pz.bake[j] > 1.0 else 1.0)
		pz.floor += (def.ambient + def.fire * 0.5) * level() * dt / t * (def.soft if pz.floor > 1.0 else 1.0)
		o.p = pz.bake_avg()
	return done

## a short word on how one of your pizzas is doing
func status(o: Dictionary) -> String:
	var pz: Pizza = o.pz
	var rng := pz.bake_range()
	var avg := pz.bake_avg()
	if rng[1] > 1.4: return "BURNING"
	if avg >= 0.95 and rng[0] >= 0.85: return "READY"
	if def.fire > 0.0 and def.spin <= 0.0 and not o.auto and rng[1] - rng[0] > 0.22: return "TURN"
	if avg >= 1.12: return "OVERDONE"
	return "baking"

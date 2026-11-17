class_name Pizza
extends RefCounted
## One pizza, from dough ball to the pass.
##
## Everything that goes on it is weighed. Sauce and cheese are spread over a grid of cells (each cell
## holds an amount, 1.0 = a proper layer); toppings are placed piece by piece. Every gram comes out of
## Stock as it is applied, so a heavy hand costs real money. The recipe card (rec.spec) says how many
## grams of each thing the pizza should carry.
##
## All positions are pizza-local: the centre of the pizza is (0,0), in bench units.

const NSEC := 12          # edge sectors that brown separately in the oven
const CELL := 12.0        # spacing of the sauce / cheese grid
const MAX_AMT := 2.5      # how thick a layer can get in one spot

static var _next_id := 1

var id := 0
var tk: Dictionary         # the ticket it is for
var rec: Dictionary        # its recipe card
var d: Dictionary          # its dough recipe
var base: PizzaBase
var dough_q := 60.0        # how well the dough was made, 0-100
var stage := "shape"       # shape -> top -> shelf -> oven -> board
var sauce := ""            # which sauce is on it ("" = none)
var cheese := ""
var cells := []            # centres of the grid cells inside the topping area
var sauce_amt := {}        # cell index -> amount
var cheese_amt := {}
var tops := []             # [{t ingredient, x, y, a angle, after: placed after baking}]
var grams := {}            # ingredient id -> grams put on
var costs := {}            # ingredient id -> what those grams cost
var cost := 0.0            # total, including the dough ball
var dough_cost := 0.0
var gsum := 0.0            # grams x quality, for the average ingredient grade
var gw := 0.0
var bake := []             # doneness of each edge sector (1.0 = done)
var floor := 0.0           # doneness of the underside
var turn := 0.0            # which way it faces in the oven
var cuts := []             # [{a, b, d: distance of the cut from the centre}]
var bake_target := 1.0     # 1.15 for "well done"

func _init(ticket: Dictionary, dough: Dictionary) -> void:
	id = _next_id
	_next_id += 1
	tk = ticket
	rec = ticket.rec
	if rec.get("well", false): bake_target = 1.15
	d = Data.DOUGHS[rec.base]
	base = PizzaBase.new(d)
	dough_q = dough.q
	dough_cost = dough.cost
	cost = dough.cost
	gw = d.ball * 0.4          # the base counts for less than what is on it
	gsum = dough.g * gw
	for i in NSEC: bake.append(0.0)
	var lim: float = d.R * 0.84
	var y := -lim
	while y <= lim:
		var x := -lim
		while x <= lim:
			if Vector2(x, y).length() < lim: cells.append(Vector2(x, y))
			x += CELL
		y += CELL

# ---------- putting things on ----------
## can something be put here: on the dough and off the crust
func inside(p: Vector2) -> bool:
	var a := p.angle()
	var rad := base.rad_at(a)
	return p.length() <= min(rad * 0.94, rad - max(base.rim_at(a) * 0.8, 4.0))

## take grams of an ingredient out of stock and onto the pizza. Returns grams actually got.
func use(ing: String, g: float) -> float:
	var t := Stock.take_use(ing, g)
	if t.got <= 0.0: return 0.0
	grams[ing] = grams.get(ing, 0.0) + t.got
	costs[ing] = costs.get(ing, 0.0) + t.cost
	cost += t.cost
	gsum += t.g * t.got
	gw += t.got
	return t.got

func spec_of(ing: String) -> float:
	if rec.spec.has(ing): return rec.spec[ing]
	return Data.ING[ing].portion * d.top

## grams that one unit of amount in one cell stands for
func _g_per_amt(ing: String) -> float:
	return spec_of(ing) / (0.95 * cells.size())

## lay sauce or cheese with a brush at p. seg = how far the brush travelled (use the brush radius for a dab).
## Returns false when the ingredient has run out.
func spread(ing: String, p: Vector2, seg: float, brush: float) -> bool:
	var is_sauce: bool = Data.ING[ing].kind == "sauce"
	if is_sauce:
		if sauce == "":
			if Stock.avail(ing) <= 0.0: return false
			sauce = ing
		elif sauce != ing: return true
	else:
		if cheese == "":
			if Stock.avail(ing) <= 0.0: return false
			cheese = ing
		elif cheese != ing: return true
	var amt: Dictionary = sauce_amt if is_sauce else cheese_amt
	var dep: float = clamp(seg / (2.0 * brush), 0.04, 0.6) * 17.0 / brush     # a bigger ladle covers faster, not thicker
	var adds := []
	var want := 0.0
	for i in cells.size():
		var dd: float = cells[i].distance_to(p)
		if dd > brush or not inside(cells[i]): continue
		var add: float = min(dep * (1.0 - 0.5 * pow(dd / brush, 2)), MAX_AMT - amt.get(i, 0.0))
		if add <= 0.0: continue
		adds.append([i, add])
		want += add
	if want <= 0.0: return true
	var gpa := _g_per_amt(ing)
	var got := use(ing, want * gpa)
	if got <= 0.0: return false
	var k: float = got / (want * gpa)
	for e in adds: amt[e[0]] = amt.get(e[0], 0.0) + e[1] * k
	return k > 0.99

func count_of(ing: String) -> int:
	var n := 0
	for tp in tops:
		if tp.t == ing: n += 1
	return n

## place one piece of a topping. Returns "" if placed, "full" / "close" / "off" if not, "out" when stock has run out.
func add_top(ing: String, p: Vector2, after_bake: bool) -> String:
	if not inside(p): return "off"
	var it: Dictionary = Data.ING[ing]
	var n := 0
	for tp in tops:
		if tp.t == ing:
			n += 1
			if Vector2(tp.x, tp.y).distance_to(p) < 15.0: return "close"
	if n >= int(ceil(spec_of(ing) / it.piece * 2.2)) + 2: return "full"
	if use(ing, it.piece) < it.piece * 0.5: return "out"
	tops.append({"t": ing, "x": p.x, "y": p.y, "a": randf() * TAU, "after": after_bake})
	return ""

# ---------- reading the pizza ----------
func grade() -> float:
	return gsum / gw if gw > 0.0 else 2.0

## 0..1: how much of the topping area is covered (85% covered counts as full)
func cov(amt: Dictionary) -> float:
	var n := 0
	for i in amt:
		if amt[i] >= 0.35: n += 1
	return clamp(float(n) / cells.size() / 0.85, 0.0, 1.0)

## 0..1: how even the layer is where it has been laid
func evenness(amt: Dictionary) -> float:
	if amt.size() < 4: return 0.0
	var m := 0.0
	for i in amt: m += amt[i]
	m /= amt.size()
	var v := 0.0
	for i in amt: v += pow(amt[i] - m, 2)
	return clamp(1.0 - sqrt(v / amt.size()) / max(m, 0.1) * 0.9, 0.0, 1.0)

## grams on the pizza as a share of what the recipe card asks for
func portion(ing: String) -> float:
	return grams.get(ing, 0.0) / max(spec_of(ing), 0.01)

## 0..1 for a portion ratio: right amount scores 1, stingy drops fast, heavy-handed drops slowly
static func portion_score(ratio: float) -> float:
	if ratio < 0.85: return clamp((ratio - 0.3) / 0.55, 0.0, 1.0)
	if ratio <= 1.2: return 1.0
	return max(0.5, 1.0 - (ratio - 1.2) * 0.5)

## {ratio, spread 0..1, timing 0..1} for one topping
func top_info(ing: String) -> Dictionary:
	var it: Dictionary = Data.ING[ing]
	var quads := {}
	var n := 0
	var right := 0.0
	for tp in tops:
		if tp.t != ing: continue
		n += 1
		quads[(1 if tp.x > 0 else 0) + (2 if tp.y > 0 else 0)] = true
		right += 1.0 if tp.after == it.after else 0.5
	var want_n: int = int(max(1, round(spec_of(ing) / it.piece)))
	return {"ratio": portion(ing), "spread": float(quads.size()) / min(4, want_n) if n > 0 else 0.0, "timing": right / n if n > 0 else 1.0, "n": n}

static func done_score(p: float) -> float:
	if p < 0.6: return 0.0
	if p < 0.92: return 0.2 + (p - 0.6) / 0.32 * 0.7
	if p <= 1.12: return 1.0
	if p < 1.4: return 1.0 - (p - 1.12) / 0.28 * 0.7
	return 0.0

func bake_avg() -> float:
	var t := 0.0
	for b in bake: t += b
	return t / NSEC

func bake_range() -> Array:
	var mn: float = bake[0]
	var mx: float = bake[0]
	for b in bake:
		mn = min(mn, b)
		mx = max(mx, b)
	return [mn, mx]

func cut_score() -> float:
	var best := []
	for ct in cuts: best.append(0.5 + 0.5 * (1.0 - ct.d / (base.R * 0.35)))
	best.sort()
	best.reverse()
	var sc := 0.0
	for i in min(3, best.size()): sc += best[i]
	return sc / 3.0

## Everything a customer (and your accountant) will judge.
## Returns look and taste (0-100), the parts behind them (0..1), notes, grade, cost and what the recipe card says it should have cost.
func assess(c: Dictionary) -> Dictionary:
	var a := {"notes": []}
	var bs := base.score()
	a.shape = bs.total
	if bs.size < 0.7: a.notes.append("Lopsided base")
	elif bs.crust < 0.6: a.notes.append("Crust is all wrong" if base.crust >= 1.0 else "Base is not flat")
	var cover := []
	var even := []
	var parts := []
	if rec.sauce != "":
		var ok: bool = sauce == rec.sauce
		a.sauce = cov(sauce_amt) if ok else 0.0
		cover.append(a.sauce)
		even.append(evenness(sauce_amt))
		parts.append(portion_score(portion(rec.sauce)) if ok else 0.0)
		_portion_note(a.notes, rec.sauce)
	if rec.cheese != "":
		var ok: bool = cheese == rec.cheese
		a.cheese = cov(cheese_amt) if ok else 0.0
		cover.append(a.cheese)
		even.append(evenness(cheese_amt))
		parts.append(portion_score(portion(rec.cheese)) if ok else 0.0)
		_portion_note(a.notes, rec.cheese)
	var lay := []
	for t in rec.tops:
		var ti := top_info(t)
		parts.append(portion_score(ti.ratio) * ti.timing)
		lay.append(ti.spread * min(1.0, ti.ratio / 0.6))
		_portion_note(a.notes, t)
		if ti.n > 0 and ti.timing < 0.8:
			a.notes.append("%s should go on after the oven" % Data.ING[t].name if Data.ING[t].after else "%s went on raw" % Data.ING[t].name)
	a.cover = _avg(cover, 1.0)
	a.even = _avg(even, 1.0)
	a.portion = _avg(parts, 1.0)
	a.layout = _avg(lay, 1.0)
	if a.cover < 0.75: a.notes.append("Bare patches")
	elif a.layout < 0.7: a.notes.append("Toppings all on one side")

	# the bake: how done, and how evenly coloured
	var avg := bake_avg()
	var rng := bake_range()
	var done := 0.0
	for b in bake: done += done_score(b / bake_target) / NSEC
	a.bake = done * 0.75 + done_score(floor / bake_target) * 0.25
	a.bake_even = 1.0 - clamp((rng[1] - rng[0] - 0.1) / 0.6, 0.0, 1.0)
	a.colour = done * (0.55 + 0.45 * a.bake_even)
	a.bake_avg = avg
	var raw: bool = avg < 0.6
	var burnt: bool = rng[1] > 1.5 or avg > 1.4
	if raw: a.notes.push_front("Raw in the middle")
	elif burnt: a.notes.push_front("Burnt")
	elif a.bake_even < 0.6: a.notes.push_front("Pale one side, dark the other")
	elif avg < 0.9: a.notes.append("A bit pale")
	elif avg > 1.15: a.notes.append("Overdone")
	a.cut = cut_score()
	if a.cut < 0.5: a.notes.append("Messy slicing" if cuts.size() > 0 else "Not sliced")

	# the wrong things on it
	var wrong := 0.0
	if sauce != "" and sauce != rec.sauce:
		wrong += 0.3
		a.notes.push_front("Wrong sauce")
	if cheese != "" and cheese != rec.cheese:
		wrong += 0.2
		a.notes.push_front("Cheese was not asked for" if rec.cheese == "" else "Wrong cheese")
	var extra := {}
	for tp in tops:
		if not rec.tops.has(tp.t): extra[tp.t] = true
	if extra.size() > 0:
		wrong += 0.15 * extra.size()
		a.notes.push_front("Toppings nobody ordered")
	for ing in rec.get("no", []):
		if grams.get(ing, 0.0) > 0.0:
			wrong += 0.25
			a.notes.push_front("I asked for no %s" % Data.ING[ing].name.to_lower())
	if rec.get("allergy", "") != "" and grams.get(rec.allergy, 0.0) > 0.0:
		a.allergy = true
		a.notes.push_front("ALLERGY: it had %s on it" % Data.ING[rec.allergy].name.to_lower())
	if rec.get("well", false) and avg < 1.08: a.notes.append("I asked for it well done")
	a.right = clamp(1.0 - wrong, 0.0, 1.0)

	a.look = 100.0 * (0.26 * a.shape + 0.14 * a.cover * (0.6 + 0.4 * a.even) + 0.18 * a.layout + 0.30 * a.colour + 0.12 * a.cut) * (0.7 + 0.3 * a.right)
	a.craft = 100.0 * (0.34 * a.bake + 0.24 * a.portion + 0.14 * a.cover + 0.14 * a.right + 0.14 * a.shape)
	a.taste = a.craft * 0.8 + dough_q * 0.2 + c.oven_q * 0.5
	if raw:
		a.taste = min(a.taste, 25.0)
		a.look *= 0.6
	elif burnt:
		a.taste = min(a.taste, 30.0)
		a.look = min(a.look, 35.0)
	a.look = clamp(a.look, 0.0, 100.0)
	a.taste = clamp(a.taste, 0.0, 100.0)

	# the money: what went on it against what the recipe card says
	a.grade = grade()
	a.cost = cost
	a.spec_cost = dough_cost
	a.use = grams.duplicate()
	a.use["dough:" + rec.base] = 1.0
	a.spec = rec.spec.duplicate()
	a.spec["dough:" + rec.base] = 1.0
	for ing in rec.spec:
		var g: float = grams.get(ing, 0.0)
		var y: float = float(Data.ING[ing].prep.yield) if Data.needs_prep(ing) else 1.0
		a.spec_cost += rec.spec[ing] * (costs[ing] / g if g > 0.0 else Market.ref_cost(ing) / y)
	return a

func _portion_note(notes: Array, ing: String) -> void:
	var ratio := portion(ing)
	if ratio < 0.7: notes.append("Stingy with the %s" % Data.ING[ing].name.to_lower())
	elif ratio > 1.4: notes.append("Drowning in %s" % Data.ING[ing].name.to_lower())

func _avg(arr: Array, empty: float) -> float:
	if arr.is_empty(): return empty
	var t := 0.0
	for x in arr: t += x
	return t / arr.size()

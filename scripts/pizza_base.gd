class_name PizzaBase
extends RefCounted
## The shape of a dough base while it is being opened out on the bench.
##
## The dough is an outline of NS sectors around its centre. Each sector has:
##   r    how far the dough reaches (bench units)
##   rim  how wide the still-puffy, unpressed edge is. A ball starts all rim; pressing flattens it from the middle out.
## The dough has a fixed weight, so the bigger you open it the thinner it gets.
##
## Techniques are the methods below. Each one only edits r / rim / rot (and tears), so new ones can be added here and
## called from Bench without touching anything else. Every technique is there from the first day, for anyone: none is
## locked, none is the right one. What counts is the base you end up with (round, the right size, an even thickness,
## the crust you want, no holes), however you got there; a chef gets there quicker and better.
##   press()    fingertips, one finger: flattens where you press and pushes the gas out to the rim
##   stretch()  one hand pulling outward while the other holds: use it once per finger of a two-finger spread
##   rotate()   turning the dough on the bench
##   drape()    lifted on your knuckles and turned: gravity stretches it evenly, the thick parts most; keeps the crust
##   slap()     the Neapolitan slap: flipped over the back of your hand and slapped down further out; keeps the crust
##   toss()     thrown up spinning: it spreads out evenly; too little spin and it flops, too much for how thin it is
##              and it tears
##   roll()     a pass of the rolling pin: lengthens along the pin's travel and flattens the rim
##   pan()      pushing dough out to the wall of a pan
##   sheet()    one pass through a dough sheeter

const NS := 24

var r := []
var rim := []
var rot := 0.0
var R := 106.0          # target radius, bench units
var crust := 14.0       # target rim width, bench units
var mass := 260.0       # grams
var cm := 0.14          # real centimetres per bench unit
var method := "hand"    # hand / roll / press
var max_r := 1.15       # how far past the target it will go before it would tear
var tears: Array = []   # where it has torn through (angles): holes in the base
var lifted := false     # off the bench, on your knuckles (to drape it, or to toss it)
var air := 0.0          # seconds still in the air after a toss
var air0 := 0.0         # how long that toss is in the air in all
var spin := 0.0         # how fast it is turning, in turns a second (lifted or in the air)
var last := ""          # the last toss's verdict: "stretched", "flop", "tore" ("" none yet)

func _init(d: Dictionary) -> void:
	R = float(d.R)
	method = d.shape
	mass = float(d.ball)
	cm = float(d.size_cm) / (2.0 * R)
	crust = float(d.crust_cm) / cm
	var r0: float = R * (0.5 if method == "press" else 0.42)
	for i in NS:
		r.append(r0)
		rim.append(r0)

# ---------- reading the shape ----------
func _ang(i: int) -> float:
	return i * TAU / NS + rot

func _lerp_at(arr: Array, ang: float) -> float:
	var f := fposmod((ang - rot) / TAU, 1.0) * NS
	var i := int(f) % NS
	var k: float = f - floor(f)
	return arr[i] * (1.0 - k) + arr[(i + 1) % NS] * k

func rad_at(ang: float) -> float:
	return _lerp_at(r, ang)

func rim_at(ang: float) -> float:
	return min(_lerp_at(rim, ang), rad_at(ang))

## the outline as points around (0,0); k scales it, inset pulls it in by the rim (for the crumb inside the crust)
func outline(k: float = 1.0, inset: float = 0.0, n: int = 72) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := i * TAU / n
		var rad: float = rad_at(a)
		if inset > 0.0: rad = max(rad - max(rim_at(a), 3.0) * inset, 0.0)
		pts.append(Vector2.from_angle(a) * rad * k)
	return pts

func mean_r() -> float:
	var t := 0.0
	for x in r: t += x
	return t / NS

func mean_rim() -> float:
	var t := 0.0
	for i in NS: t += min(rim[i], r[i])
	return t / NS

func area_cm2() -> float:
	var a := 0.0
	for i in NS:
		a += 0.5 * r[i] * r[(i + 1) % NS] * sin(TAU / NS)
	return a * cm * cm

func diameter_cm() -> float:
	return 2.0 * mean_r() * cm

## average thickness in millimetres (dough is close to 1 g per cubic centimetre)
func thickness_mm() -> float:
	return mass / max(area_cm2(), 1.0) * 10.0

func crust_cm() -> float:
	return mean_rim() * cm

func target_thickness_mm() -> float:
	return mass / (PI * R * R * cm * cm) * 10.0

## 0..1 scores: size (right diameter and round), crust (rim as the recipe wants it), total
func score() -> Dictionary:
	var sz := 0.0
	var cr := 0.0
	for i in NS:
		sz += clamp(1.0 - max(0.0, abs(r[i] - R) / R - 0.04) * 2.8, 0.0, 1.0)
		var w: float = min(rim[i], r[i])
		if crust < 1.0: cr += clamp(1.0 - max(0.0, w - 3.0) / (R * 0.12), 0.0, 1.0)
		else: cr += clamp(1.0 - max(0.0, abs(w - crust) / crust - 0.3) * 1.1, 0.0, 1.0)
	sz /= NS
	cr /= NS
	var holes := clampf(tears.size() * 0.2, 0.0, 0.6)       # a hole in the base: sauce through it, a sorry pizza
	return {"size": sz, "crust": cr, "tears": tears.size(), "total": maxf(0.0, sz * 0.65 + cr * 0.35 - holes)}

# ---------- techniques ----------
## fingertip press at a point (dough-local coordinates). tip = fingertip radius.
func press(p: Vector2, tip: float = 16.0) -> void:
	var d := p.length()
	var ang := p.angle()
	if d > rad_at(ang) + tip * 0.5: return
	var span: float = PI * 1.1 if d < tip else atan(tip / d) * 1.7
	for i in NS:
		var da: float = abs(angle_difference(ang, _ang(i)))
		if da > span: continue
		var w: float = 1.0 - 0.5 * da / span
		var target: float = clamp(r[i] - (d + tip * 0.7), 0.0, rim[i])
		var flat: float = (rim[i] - target) * w
		rim[i] -= flat
		r[i] = min(r[i] + flat * 0.3, R * max_r)

## one finger pulling the dough from p0 to p1 while it is held somewhere else
func stretch(p0: Vector2, p1: Vector2) -> void:
	var gain := p1.length() - p0.length()
	if gain <= 0.0 or p0.length() > rad_at(p0.angle()) + 18.0: return
	var ang := p1.angle()
	for i in NS:
		var da: float = abs(angle_difference(ang, _ang(i)))
		var w: float = exp(-pow(da / 0.6, 2)) * 0.8 + 0.1
		r[i] = min(r[i] + gain * w * (0.2 if r[i] > R else 1.0), R * max_r)

func rotate(by: float) -> void:
	rot = fposmod(rot + by, TAU)

## how thick the dough is round the edge compared with the average, sector by sector (1 = average): where it reaches
## less, the same dough is thicker
func _thick(i: int, mr: float) -> float:
	return clampf(1.0 + (mr - r[i]) / maxf(mr, 1.0) * 2.5, 0.3, 2.0)

## lifted on your knuckles and turned by `turn` (radians): its own weight stretches it, the thicker parts most, so it
## evens out; the crust is left alone
func drape(turn: float) -> void:
	var t := absf(turn)
	if t < 0.0005 or not lifted: return
	rotate(turn)
	var mr := mean_r()
	for i in NS:
		r[i] = minf(r[i] + t * 2.2 * _thick(i, mr) * (0.25 if r[i] > R else 1.0), R * max_r)

## the Neapolitan slap: flipped over the back of your hand and slapped down further out, turning a little as it goes
## (dir: the way you slapped it; strength 0..1). It stretches along the slap and a little all round, and keeps its crust.
func slap(dir: Vector2, strength: float) -> void:
	var s := clampf(strength, 0.0, 1.0)
	if s <= 0.0: return
	var phi := dir.angle()
	for i in NS:
		var w: float = 0.35 + 0.65 * pow(cos(_ang(i) - phi), 2)
		r[i] = minf(r[i] + s * 9.0 * w * (0.25 if r[i] > R else 1.0), R * max_r)
	rotate(0.5 * s * (1.0 if dir.x >= 0.0 else -1.0))

## thrown up spinning at `turns` a second for `airtime` seconds: it spreads out evenly as it spins (faster spins and
## longer in the air, more), the thicker parts most, and the crust stays. Too little spin and it just flops, a little
## out of shape. Too fast for how thin it already is and it tears. Returns "stretched", "flop" or "tore".
func toss(turns: float, airtime: float) -> String:
	lifted = false
	spin = turns
	air = airtime
	air0 = airtime
	var sp := absf(turns)
	if sp < 0.6:
		for i in NS: r[i] = maxf(r[i] + randf_range(-3.0, 3.0), 5.0)
		last = "flop"
		return last
	var th := thickness_mm() / maxf(target_thickness_mm(), 0.1)        # 1 = as thin as the recipe wants it
	var limit := 1.6 + 2.2 * clampf(th - 0.6, 0.0, 1.5)              # the spin it takes before it tears (turns a second)
	if sp > limit:
		var a := randf() * TAU                                       # (round the dough itself: it turns with it)
		tears.append(a)
		for i in NS:
			if absf(angle_difference(a, i * TAU / NS)) < 0.6: r[i] *= 0.85   # it goes ragged where it tore
		last = "tore"
		return last
	var grow := sp * airtime * 10.0
	var mr := mean_r()
	for i in NS:
		r[i] = minf(r[i] + grow * _thick(i, mr) * (0.3 if r[i] > R else 1.0), R * max_r)
	last = "stretched"
	return last

## the holes torn in it, as [where (round the middle, as the outline), how wide (radius)], bench units
func holes() -> Array:
	var out := []
	for t in tears:
		var a: float = float(t) + rot
		out.append([Vector2.from_angle(a) * rad_at(a) * 0.55, R * 0.12])
	return out

## in the air: it comes down after its time, spinning as it goes. True on the frame it lands.
func fly(dt: float) -> bool:
	if air <= 0.0: return false
	rotate(spin * TAU * dt)
	air -= dt
	if air > 0.0: return false
	air = 0.0
	spin = 0.0
	return true

## how high it is above the bench now (metres): lifted on your knuckles, or the arc of a toss
func height() -> float:
	if air > 0.0 and air0 > 0.0:
		var u := 1.0 - air / air0
		return 0.12 + 4.0 * (0.4 * air0 * air0) * u * (1.0 - u)
	return 0.12 if lifted else 0.0

## the rolling pin, centred at p, moved by mv
func roll(p: Vector2, mv: Vector2) -> void:
	var ln := mv.length()
	if ln < 0.5 or p.length() > rad_at(p.angle()) + 30.0: return
	var phi := mv.angle()
	for i in NS:
		var w: float = pow(cos(_ang(i) - phi), 2)
		r[i] = min(r[i] + ln * w * 0.2 * (0.2 if r[i] > R else 1.0), R * max_r)
		rim[i] = max(0.0, rim[i] - ln * (0.25 + w * 0.5))

## pushing dough toward the wall of the pan; it cannot go past the wall
func pan(p: Vector2, mv: Vector2) -> void:
	var ln := mv.length()
	if ln < 0.5: return
	var ang := p.angle()
	for i in NS:
		var da: float = abs(angle_difference(ang, _ang(i)))
		var w: float = exp(-pow(da / 0.7, 2))
		r[i] = min(r[i] + ln * w * 0.35, R)
		rim[i] = max(0.0, rim[i] - ln * w * 0.6)

## through the dough sheeter: evenness 0..1 is how good the machine is
func sheet(evenness: float) -> void:
	for i in NS:
		r[i] = R * (1.0 + randf_range(-1.0, 1.0) * (1.0 - evenness) * 0.5)
		rim[i] = 0.0

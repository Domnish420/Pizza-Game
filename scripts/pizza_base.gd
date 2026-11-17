class_name PizzaBase
extends RefCounted
## The shape of a dough base while it is being opened out on the bench.
##
## The dough is an outline of NS sectors around its centre. Each sector has:
##   r    how far the dough reaches (bench units)
##   rim  how wide the still-puffy, unpressed edge is. A ball starts all rim; pressing flattens it from the middle out.
## The dough has a fixed weight, so the bigger you open it the thinner it gets.
##
## Techniques are the methods below. Each one only edits r / rim / rot, so new ones (slap, knuckle
## stretch, toss, docking...) can be added here and called from Bench without touching anything else.
##   press()    fingertips, one finger: flattens where you press and pushes the gas out to the rim
##   stretch()  one hand pulling outward while the other holds: use it once per finger of a two-finger spread
##   rotate()   turning the dough on the bench
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
	return {"size": sz, "crust": cr, "total": sz * 0.65 + cr * 0.35}

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

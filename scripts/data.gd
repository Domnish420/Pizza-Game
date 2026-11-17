extends Node
## Static game data, loaded once from the JSON files in res://data/.
## Edit those files to rebalance or extend the game; nothing here needs to change when you add
## an ingredient, a supplier, a dough recipe, a pizza, a menu, a venue, an upgrade tier or a staff role.

var ING := {}          # ingredient id -> ingredient. The loader adds: id, g{grade -> {name, price per base unit, life}}, grade_list, space per base unit
var CATS := []         # [[category id, label]]
var GRADES := []       # quality names, index 1..5
var GRADE_LVL := []    # player level at which each quality appears in catalogues
var BULK_EXP := 0.085  # bigger packs are cheaper per unit: price x (pack / smallest pack) ^ -BULK_EXP
var SUPPLIERS := []
var SUP := {}
var DOUGHS := {}       # dough style id -> recipe
var RECIPES := []      # pizzas
var REC := {}
var MENUS := []
var MENU := {}
var MENU_DAYS := 14
var VENUES := []
var WEEK := []         # how busy each weekday is, Monday first
var UPG := {}          # upgrade track id -> {area, name, tiers}
var OVENS := {}        # oven type -> how it heats
var ROLES := {}
var NAMES := []
var EXTRAS := []       # sides, desserts and drinks (data/extras.json)
var EXTRA := {}
var EXTRA_CHANCE := {} # course -> party type -> chance each person orders one
var APP := {}          # the delivery app (data/delivery_app.json)

const STORES := ["fridge", "freezer", "dry"]
const STORE_NAME := {"fridge": "Fridge", "freezer": "Freezer", "dry": "Dry store"}
const DAY_NAME := ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
const DAY_SHORT := ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
const SEASON_NAME := ["Spring", "Summer", "Autumn", "Winter"]

func _read(file: String) -> Dictionary:
	var f := FileAccess.open("res://data/%s.json" % file, FileAccess.READ)
	return JSON.parse_string(f.get_as_text())

func _init() -> void:
	var d := _read("ingredients")
	CATS = d.categories
	GRADES = d.grades
	GRADE_LVL = d.grade_lvl
	BULK_EXP = float(d.bulk_exponent)
	ING = d.items
	for id in ING:
		var it: Dictionary = ING[id]
		var per := 1000.0 if it.unit == "g" or it.unit == "ml" else 1.0   # prices and space are quoted per kg / litre
		it.id = id
		it.lvl = int(it.get("lvl", 1))
		it.after = bool(it.get("after", false))
		it.season = int(it.get("season", -1))
		it.vol = float(it.get("vol", d.volatility[it.cat]))
		it.space = float(it.litres) / per                       # litres per unit (g, ml or item)
		it.prep = it.get("prep", null)                           # what has to be done to it before service, or null
		it.frost = it.get("frost", "")                           # "bin" / "hurt": what freezing does to it
		it.damp = bool(it.get("damp", false))
		it.pests = bool(it.get("pests", false))
		it.smallest = float(it.packs[0][0])
		it.portion = float(it.get("portion", 0.0))
		it.piece = float(it.get("piece", 0.0))
		it.shape = it.get("shape", "disc")
		it.g = {}
		it.grade_list = []
		for k in it.grades:
			var e: Dictionary = it.grades[k]
			it.g[int(k)] = {"name": e.name, "price": float(e.price) / per, "life": int(e.get("life", it.life))}
			it.grade_list.append(int(k))
		it.grade_list.sort()

	SUPPLIERS = _read("suppliers").suppliers
	for sp in SUPPLIERS: SUP[sp.id] = sp

	DOUGHS = _read("doughs").doughs
	for k in DOUGHS:
		var dg: Dictionary = DOUGHS[k]
		dg.id = k
		dg.lvl = int(dg.lvl)
		for p in dg.parts: p.flour = bool(p.get("flour", false))

	RECIPES = _read("pizzas").pizzas
	for r in RECIPES:
		REC[r.id] = r
		var lvl: int = DOUGHS[r.base].lvl
		for i in r.spec: lvl = max(lvl, ING[i].lvl)
		r.lvl = lvl

	var m := _read("menus")
	MENU_DAYS = int(m.menu_days)
	MENUS = m.menus
	for mm in MENUS: MENU[mm.id] = mm

	var v := _read("venues")
	VENUES = v.venues
	WEEK = v.week
	var u := _read("upgrades")
	UPG = u.tracks
	OVENS = u.ovens
	var eq := _read("equipment")
	for it in eq.items:
		if it.rule == "ladle": LADLES.append(int(it.oz))
	var ex := _read("extras")
	EXTRAS = ex.items
	EXTRA_CHANCE = ex.chance
	for x in EXTRAS:
		x.lvl = int(x.get("lvl", 1))
		x.tier = int(x.get("tier", 0))
		x.price = float(x.price)
		x.mins = float(x.get("mins", 0.0))
		x.tool = x.get("tool", "")
		x.extra = true
		for i in x.spec: x.lvl = max(x.lvl, ING[i].lvl)
		if x.make == "oven":
			x.tops = x.get("tops", [])
			x.lvl = max(x.lvl, DOUGHS[x.base].lvl)
			REC[x.id] = x            # baked like a pizza: the bench, the oven and the staff treat it as one
		EXTRA[x.id] = x
	APP = _read("delivery_app")
	var st := _read("staff")
	ROLES = st.roles
	NAMES = st.names

# ---------- small helpers everything uses ----------
## "07:40" from minutes after midnight
func hhmm(m: float) -> String:
	var mi := int(round(m))
	return "%02d:%02d" % [(mi / 60) % 24, mi % 60]

const OZ_G := 30.0      # one fluid ounce of sauce, in grams (ml for oils)
var LADLES := []        # portion ladle sizes sold on the equipment site, in oz (see data/equipment.json)

## "2 oz" for an amount of sauce
func oz_text(g: float) -> String:
	var oz: float = g / OZ_G
	return ("%d oz" % round(oz)) if abs(oz - round(oz)) < 0.08 else ("%.1f oz" % oz)

func needs_prep(id: String) -> bool:
	return ING[id].prep != null

func grade_name(g: float) -> String:
	return GRADES[int(clamp(round(g), 1, 5))]

## an amount of an ingredient as you would say it: 350 g, 1.25 kg, 500 ml, 25 boxes
func qty(id: String, q: float) -> String:
	var u: String = ING[id].unit
	if u == "g" or u == "ml":
		if q >= 1000.0:
			var t := "%.2f" % (q / 1000.0)
			if t.ends_with("0"): t = t.left(-1)
			if t.ends_with(".0"): t = t.left(-2)
			return t + (" kg" if u == "g" else " l")
		return ("%.1f" % q if q < 10 and abs(q - round(q)) > 0.05 else str(int(round(q)))) + " " + u
	var n := int(round(q))
	if u == "box": return "%d box%s" % [n, "" if n == 1 else "es"]
	if u == "trap": return "%d trap%s" % [n, "" if n == 1 else "s"]
	return "%d %s%s" % [n, u, "" if n == 1 else "s"]

## "$7.50/kg", "$11.00/l", "$0.20 each"
func rate(id: String, per_unit: float) -> String:
	var u: String = ING[id].unit
	if u == "g": return "$%.2f/kg" % (per_unit * 1000.0)
	if u == "ml": return "$%.2f/l" % (per_unit * 1000.0)
	return "$%.2f each" % per_unit

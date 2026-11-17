class_name Orders
## What customers ask for beyond the menu: "no basil", "extra mozzarella", "add olives", "well done",
## and allergies. build() turns a menu pizza plus its notes into the recipe card for that one ticket,
## so everything downstream (the bench, the scoring, the costing, the staff) works from what was actually asked.

const EXTRA := 1.6        # an extra portion is this many times the normal one
const EXTRA_PRICE := 1.5
const ADD_PRICE := 2.0

## pick the notes a customer adds to a pizza. on_rail = toppings available tonight
static func roll(rec: Dictionary, on_rail: Array, chance: float) -> Array:
	var mods := []
	if randf() >= chance: return mods
	var tops: Array = rec.tops.duplicate()
	var kinds := ["no", "no", "extra", "extra", "add", "well"]
	var n := 1 if randf() < 0.75 else 2
	for k in n:
		var kind: String = kinds.pick_random()
		match kind:
			"no":
				if tops.size() > 0:
					var ing: String = tops.pick_random()
					tops.erase(ing)
					mods.append({"kind": "no", "ing": ing})
			"extra":
				var pool: Array = tops.duplicate()
				if rec.cheese != "": pool.append(rec.cheese)
				if rec.sauce != "" and randf() < 0.3: pool = [rec.sauce]
				if pool.size() > 0: mods.append({"kind": "extra", "ing": pool.pick_random()})
			"add":
				var extras: Array = on_rail.filter(func(i): return not rec.spec.has(i) and Data.ING[i].kind == "top")
				if extras.size() > 0: mods.append({"kind": "add", "ing": extras.pick_random()})
			"well":
				if not mods.any(func(m): return m.kind == "well"): mods.append({"kind": "well", "ing": ""})
	# now and then, an allergy to something on it
	if randf() < 0.18:
		var pool: Array = tops.duplicate()
		if rec.cheese != "" and randf() < 0.3: pool.append(rec.cheese)
		if pool.size() > 0:
			var ing: String = pool.pick_random()
			mods = mods.filter(func(m): return m.ing != ing)
			mods.append({"kind": "allergy", "ing": ing})
	return mods

## the recipe card for one ticket
static func build(rec: Dictionary, mods: Array) -> Dictionary:
	var r := rec.duplicate(true)
	r.mods = mods
	r.no = []
	r.allergy = ""
	r.well = false
	var d: Dictionary = Data.DOUGHS[rec.base]
	for m in mods:
		var ing: String = m.ing
		match m.kind:
			"no", "allergy":
				r.spec.erase(ing)
				r.tops.erase(ing)
				if r.cheese == ing: r.cheese = ""
				if r.sauce == ing: r.sauce = ""
				r.no.append(ing)
				if m.kind == "allergy": r.allergy = ing
			"extra":
				if r.spec.has(ing):
					if Data.ING[ing].kind == "sauce": r.spec[ing] += Data.OZ_G      # one more ladle
					else: r.spec[ing] = round(r.spec[ing] * EXTRA)
					r.price += EXTRA_PRICE
			"add":
				r.tops.append(ing)
				r.spec[ing] = round(Data.ING[ing].portion * float(d.top))
				r.price += ADD_PRICE
			"well":
				r.well = true
	r.key = rec.id + "|" + text(mods)
	return r

## "no basil, extra mozzarella, well done, ALLERGY: mushrooms"
static func text(mods: Array) -> String:
	var parts := []
	for m in mods:
		var nm: String = Data.ING[m.ing].name.to_lower() if m.ing != "" else ""
		match m.kind:
			"no": parts.append("no " + nm)
			"extra": parts.append("extra " + nm)
			"add": parts.append("add " + nm)
			"well": parts.append("well done")
			"allergy": parts.append("ALLERGY: " + nm)
	return ", ".join(parts)

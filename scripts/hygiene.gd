extends Node
## Autoload `Hygiene`: how clean the kitchen and front of house are, pests, and the food hygiene inspector.
##
## Cleanliness (0-100) of the kitchen ("boh") and front of house ("foh") drops through service and is put back
## by cleaning, which takes time and cleaning chemicals. Pests (0-100) creep up when the place is dirty, when the
## dry store vents are open too wide, in autumn and winter, and when nothing is keeping them out. Traps catch
## them, then need resetting. Pest proofing (an upgrade track) keeps most of them out in the first place.
## At night mice raid the dry store; during service a customer may see one.
## An inspector visits every couple of weeks and gives a 0-5 rating that customers can see. 0 or 1 closes you.

# ---------- cleanliness ----------
func level(area: String) -> float:
	return float(Game.s.clean.get(area, 100.0))

func dirty(area: String, by: float) -> void:
	Game.s.clean[area] = clamp(level(area) - by, 0.0, 100.0)

func tidy(area: String, by: float) -> void:
	Game.s.clean[area] = clamp(level(area) + by, 0.0, 100.0)

## ml of chemicals one clean of an area uses
func chem_needed(area: String) -> float:
	return (180.0 if area == "boh" else 120.0) * float(Game.venue().size)

## minutes a full clean takes (staff: pass their skill)
func clean_minutes(area: String, skill: int = 0) -> float:
	var base: float = (32.0 if area == "boh" else 20.0) * float(Game.venue().size)
	if area == "boh": base *= 0.6 + 0.4 * float(Game.tier("dish").turn)
	if skill > 0: base *= 1.15 - 0.08 * skill
	return ceil(base * (1.0 - level(area) / 100.0 * 0.6))

## clean an area properly. Returns a note on how it went
func clean(area: String) -> String:
	var want := chem_needed(area)
	var got := Stock.take("sanitiser", want)
	var k: float = got.got / want
	var grade_bonus: float = (got.g - 1.0) * 0.04 if got.got > 0 else 0.0
	var to: float = lerp(55.0, 100.0, k) * (1.0 + grade_bonus)
	var kit := Equip.clean_cap(area)
	to = min(to, kit.cap)
	Game.s.clean[area] = clamp(max(level(area), to), 0.0, 100.0)
	if k < 0.99: return "Not enough cleaning chemicals: it is only %d%% clean. Order some from the packaging supplier." % level(area)
	if kit.why.size() > 0: return "Only %d%% clean: %s. Order from %s." % [level(area), ", ".join(kit.why), Equip.SHOP.name]
	return ""

func state(area: String) -> Array:
	var l := level(area)
	if l >= 80: return ["Clean", "ok"]
	if l >= 55: return ["Needs a wipe-down", "warn"]
	if l >= 30: return ["Dirty", "bad"]
	return ["Filthy", "bad"]

# ---------- traps ----------
## how many traps the premises should have down
func traps_wanted() -> int:
	return int(ceil(2.0 * float(Game.venue().size)))

func lay_trap() -> bool:
	if Stock.have("traps") < 1: return false
	Stock.take("traps", 1)
	Game.s.pests.laid += 1
	return true

func reset_traps() -> int:
	var n: int = Game.s.pests.sprung
	Game.s.pests.laid += n
	Game.s.pests.sprung = 0
	return n

# ---------- pests ----------
func pests() -> float:
	return float(Game.s.pests.level)

func pest_state() -> Array:
	var p := pests()
	if p < 12: return ["No sign of pests", "ok"]
	if p < 30: return ["Droppings here and there", "warn"]
	if p < 55: return ["Mice in the building", "bad"]
	return ["Infested", "bad"]

## what is drawing pests in, as short phrases
func pest_causes() -> Array:
	var out := []
	if level("boh") < 60: out.append("a dirty kitchen")
	if level("foh") < 55: out.append("a dirty front of house")
	if Stock.dry_draught() > 0: out.append("dry store vents open too wide")
	if Game.s.pests.laid < traps_wanted(): out.append("not enough traps down")
	if Game.s.pests.sprung > 0: out.append("sprung traps not reset")
	if Game.season() >= 2: out.append("cold weather driving mice indoors")
	return out

## the night: pests come in, traps catch some, the rest go for the dry store. Returns notes.
func night() -> Array:
	var notes := []
	var P: Dictionary = Game.s.pests
	var guard: float = Game.tier("pest").guard
	var pressure: float = (100.0 - level("boh")) * 0.22 + (100.0 - level("foh")) * 0.1 + Stock.dry_draught() * 14.0 + [1.0, 0.0, 4.0, 6.0][Game.season()]
	pressure *= 1.0 - guard
	P.level = clamp(P.level + pressure * 0.2 - 1.5 - guard * 3.0, 0.0, 100.0)
	var caught := 0
	for i in int(P.laid):
		if P.level > 2.0 and randf() < min(0.6, P.level / 70.0):
			caught += 1
			P.level = max(0.0, P.level - 7.0)
	P.laid -= caught
	P.sprung += caught
	if caught > 0: notes.append("%d trap%s caught something overnight and need%s resetting." % [caught, "" if caught == 1 else "s", "s" if caught == 1 else ""])
	if P.level > 22.0 and randf() < (P.level - 22.0) / 90.0:
		var targets := []
		for id in Game.s.stock:
			if Data.ING[id].pests and Stock.have(id) > 0: targets.append(id)
		if targets.size() > 0:
			var id: String = targets.pick_random()
			var lost: float = Stock.have(id) * randf_range(0.15, 0.4)
			var t := Stock.take(id, lost)
			Stock.log_waste(id, t.got, t.cost)
			notes.append("Mice got into the %s in the dry store: %s chewed and binned." % [Data.ING[id].name.to_lower(), Data.qty(id, t.got)])
	if P.level > 45.0:
		dirty("boh", 15.0)
		notes.append("Droppings in the kitchen this morning. It needs cleaning before you open.")
	if P.level >= 12.0 and caught == 0 and P.laid < traps_wanted():
		notes.append("Signs of mice. Lay traps and keep the place clean.")
	return notes

## chance per game-minute that a customer sees a mouse during service
func sighting_rate() -> float:
	var p := pests()
	if p < 30.0: return 0.0
	return (p - 30.0) / 4000.0 * (1.4 if level("foh") < 50.0 else 1.0)

# ---------- the inspector ----------
## customers walking past can see your rating: it changes footfall
func footfall() -> float:
	var r: int = int(Game.s.hygiene.rating)
	return 1.0 if r < 0 else 0.8 + 0.05 * r

## schedule the next visit after one on `day`
func plan_next(day: int, last_rating: int) -> void:
	Game.s.hygiene.next = day + (randi_range(4, 8) if last_rating >= 0 and last_rating <= 2 else randi_range(10, 20))

## the morning: is the inspector coming today, and when
func roll_visit() -> void:
	var H: Dictionary = Game.s.hygiene
	H.at = -1.0
	if Game.s.day >= int(H.next):
		H.at = float(randi_range(9 * 60, 15 * 60))

## the inspection itself. Returns {rating, notes, closed}
func inspect() -> Dictionary:
	var notes := []
	var score := 0.0
	var boh := level("boh") / 100.0
	var foh := level("foh") / 100.0
	score += boh * 1.6 + foh * 0.8
	if boh < 0.6: notes.append("Kitchen not clean enough")
	if foh < 0.55: notes.append("Dining area dirty")
	var p := pests()
	score += clamp(1.0 - p / 50.0, 0.0, 1.0) * 1.2
	if p >= 12.0: notes.append("Evidence of pests")
	var t := Stock.fridge_temp()
	if t >= 1.0 and t <= 5.0: score += 0.6
	else: notes.append("Fridge at %.1f °C (must be 1 to 5 °C)" % t)
	var rot := Stock.rotation_problems()
	if rot.is_empty(): score += 0.4
	else: notes.append("Poor stock rotation: new stock in front of old")
	if Game.s.pests.laid >= traps_wanted(): score += 0.4
	else: notes.append("Not enough pest control in place")
	var logs := Checks.log_rate(7)
	score += 0.6 * logs
	if logs < 0.7: notes.append("Temperature records missing or incomplete")
	# the kit: labels, boards, a probe, and the safety equipment the law asks for
	var kit := 0.6
	var unl := Equip.unlabelled()
	if unl > 0:
		kit -= 0.2
		notes.append("%d tub%s of food with no date label" % [unl, "" if unl == 1 else "s"])
	var boards := Equip.board_issues()
	if boards.size() > 0:
		kit -= 0.15
		notes.append("No colour-coded board for the %s" % ", ".join(boards))
	if Equip.menu_cooks() and not Equip.has("probe"):
		kit -= 0.15
		notes.append("No probe thermometer to check cooked food")
	var safety := Equip.compliance_missing()
	if safety.size() > 0:
		kit -= 0.25 * safety.size()
		notes.append("Missing: " + ", ".join(safety))
	score += max(kit, -0.6)
	score *= 5.0 / 6.2
	var rating := int(clamp(round(score), 0, 5))
	if p >= 55.0: rating = min(rating, 1)
	elif p >= 30.0: rating = min(rating, 2)
	if boh < 0.3: rating = min(rating, 1)
	if t > 8.0: rating = min(rating, 2)
	var H: Dictionary = Game.s.hygiene
	H.rating = rating
	H.day = Game.s.day
	H.notes = notes
	H.at = -1.0
	plan_next(Game.s.day, rating)
	return {"rating": rating, "notes": notes, "closed": rating <= 1}

func rating_text() -> String:
	var r: int = int(Game.s.hygiene.rating)
	if r < 0: return "Not yet inspected"
	return "%d: %s" % [r, ["Urgent improvement necessary", "Major improvement necessary", "Improvement necessary", "Generally satisfactory", "Good", "Very good"][r]]

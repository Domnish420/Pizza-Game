class_name Skills
extends RefCounted
## Your hands: how you are getting on at the bench and the oven, from your first base to a chef's pizza (the owner:
## "The end progression of this is being able to fully make pizzas that a chef like me can do"). Every technique is
## there from the first base; these are milestones on the way, earned by doing it, and nothing waits behind them.
## Kept in Game.s.skills: done (milestone id -> the day), bases (how many you have opened), recent (your last bases'
## scores), streak (bases in a row at STREAK_AT or better), tosses (clean tosses).

const MILESTONES := [
	{"id": "first", "name": "First base", "how": "Open a base and send it to the oven"},
	{"id": "round", "name": "Round and right", "how": "A base the right size, and round"},
	{"id": "even", "name": "Even all over", "how": "A base an even thickness all over, with no holes"},
	{"id": "slap", "name": "The slap", "how": "Slap a base out: a quick flick outward from the crust"},
	{"id": "toss", "name": "Up it goes", "how": "Toss a base spinning, and it opens out"},
	{"id": "twice", "name": "Twice in the air", "how": "Toss it, catch it on your knuckles, toss it again"},
	{"id": "leopard", "name": "Leopard all round", "how": "A crust spotted all round: turn it with the peel by the fire"},
	{"id": "streak", "name": "Five in a row", "how": "Five of your bases in a row at 85% or better"},
	{"id": "chef", "name": "Chef's hands", "how": "A pizza of your own, opened by hand, looking 90 or better: round, even, a good crust, a good bake"},
]
const RANKS := [[0, "Beginner"], [2, "Getting the feel"], [4, "Pizzaiolo"], [7, "Senior pizzaiolo"], [9, "Chef's hands"]]
const STREAK_AT := 0.85
const KEEP := 10

static func state() -> Dictionary:
	if not Game.s.has("skills") or not Game.s.skills is Dictionary:
		Game.s.skills = {"done": {}, "bases": 0, "recent": [], "streak": 0, "tosses": 0}
	return Game.s.skills

static func has(id: String) -> bool:
	return state().done.has(id)

static func count() -> int:
	return state().done.size()

## what you are, by how many milestones you have
static func rank() -> String:
	var out: String = RANKS[0][1]
	for rk in RANKS:
		if count() >= int(rk[0]): out = rk[1]
	return out

## your last bases' average score (0..1), or -1 with none yet
static func average() -> float:
	var rc: Array = state().recent
	if rc.is_empty(): return -1.0
	var t := 0.0
	for x in rc: t += float(x)
	return t / rc.size()

static func _name(id: String) -> String:
	for ms in MILESTONES:
		if ms.id == id: return ms.name
	return id

## a milestone reached (once): said a moment later, so it does not hide what the game is telling you now
static func earn(id: String) -> void:
	var s := state()
	if s.done.has(id): return
	var before := rank()
	s.done[id] = int(Game.s.day)
	var msg := "Your hands: %s" % _name(id)
	if rank() != before: msg += ". You are now: %s" % rank()
	if Kit.main != null and Kit.main.is_inside_tree():
		Kit.main.get_tree().create_timer(2.6).timeout.connect(func():
			if is_instance_valid(Kit.main): Kit.main.toast(msg))

## a base you opened, on its way to the oven
static func based(b: PizzaBase) -> void:
	if b.recorded: return
	b.recorded = true
	var s := state()
	var sc := b.score()
	s.bases = int(s.bases) + 1
	var rc: Array = s.recent
	rc.append(snappedf(sc.total, 0.01))
	while rc.size() > KEEP: rc.pop_front()
	s.streak = int(s.streak) + 1 if sc.total >= STREAK_AT else 0
	earn("first")
	if sc.size >= 0.9: earn("round")
	if sc.even >= 0.9 and sc.tears == 0: earn("even")
	if b.used.has("slap"): earn("slap")
	if int(s.streak) >= 5: earn("streak")

## a toss, and how it went
static func tossed(b: PizzaBase, res: String) -> void:
	if res != "stretched": return
	var s := state()
	s.tosses = int(s.tosses) + 1
	earn("toss")
	if b.catches > 0: earn("twice")

## a pizza of yours served, as judged (Pizza.assess)
static func served(pz: Pizza, a: Dictionary) -> void:
	if a.notes.has("Leopard spots all round the crust"): earn("leopard")
	var sc := pz.base.score()
	if pz.base.method == "hand" and float(a.look) >= 90.0 and sc.even >= 0.85 and sc.tears == 0: earn("chef")

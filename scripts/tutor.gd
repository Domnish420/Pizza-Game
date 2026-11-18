extends CanvasLayer
## Autoload `Tutor`: the training days of story mode.
##
## Your first shift as a pizzaiolo is guided: Marco talks you through the first pizza of a real shift (you only
## stretch the bases that day; he does the rest), and briefs you on the mornings of days 2 to 4 as your part of the
## job grows (Story.PLAN). Guides count: they run on the real game. Before your first shift as senior pizzaiolo he
## gives you a training day on the back of house, which does not count: the game is snapshotted when it starts and
## put back when it ends, so the real first senior shift starts fresh.
##
## In both, he talks you through one job at a time; a marker bobs over the thing to touch; each step ticks on when
## you have actually done it (nothing to press to say you have). A training day is pending when
## Game.s.story.training is "senior" (set by the promotion); a guide when Story.guide_due() names a shift. Either
## starts as soon as you are in the 3D kitchen with nothing else on screen.
##
## Each step: {say: what Marco says, at: the thing to point at ("job:<name>", "pan:<ingredient>", "ticket",
## "surface:<station>", "pass", "hud:phone", "hud:<station>"), setup: run when the step starts, done: true when it
## is done, tap: true for a step you read and tap to go on, skip: true to leave the step out}.

var kind := ""                 # what is running: "" / "senior" (the training day) / "day1".."day4" (a guide)
var guide := 0                 # the shift a guide is for (0: not a guide)
var steps := []
var i := 0
var mark := {}                 # what a step noted when it started (to see what changed)
var wait := 0.0                # a short pause between steps
var panel: PanelContainer
var name_l: Label
var text_l: Label
var foot_l: Label
var hl: Panel                  # the box drawn round a button you should press
var game_ref = null            # the game this training day is running on

func _ready() -> void:
	layer = 40
	panel = Kit.panel(Color(0.1, 0.13, 0.11, 0.94), 14, 16)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.offset_top = 62
	panel.offset_left = -345          # clear of the recipe card and its button, top right
	panel.offset_right = 215
	panel.visible = false
	panel.gui_input.connect(_panel_input)
	var v := Kit.vbox(4)
	panel.add_child(v)
	var h := Kit.hbox(8)
	name_l = Kit.label(Story.BOSS, 18, Kit.CHEESE)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(name_l)
	var skip := Kit.button("Skip training", func(): Kit.main.confirm("Skip the training day?", "%s will let you get on with it. You can still read how everything works in the recipe card and on your phone." % Story.BOSS, "Skip it", finish), "ghost", 14)
	h.add_child(skip)
	v.add_child(h)
	text_l = Kit.label("", 18, Kit.INK, true)
	text_l.custom_minimum_size.x = 520
	v.add_child(text_l)
	foot_l = Kit.label("", 13, Kit.MUTED)
	v.add_child(foot_l)
	add_child(panel)
	hl = Panel.new()
	hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Kit.CHEESE
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(12)
	hl.add_theme_stylebox_override("panel", sb)
	hl.visible = false
	add_child(hl)

func running() -> bool:
	return kind != ""

## the service is a training service: no customers of its own, nobody else takes the tickets
func training_service() -> bool:
	return kind == "pizzaiolo"

func _screen():
	return Kit.main.screen() if Kit.main != null else null

func _is(n, cls: String) -> bool:
	return n != null and is_instance_valid(n) and n.get_script() != null and n.get_script().get_global_name() == cls

func _kitchen():
	var s = _screen()
	return s if _is(s, "KitchenScreen") else null

func _svc():
	var s = _screen()
	return s if _is(s, "ServiceScreen") else null

func _world():
	var k = _kitchen()
	if k != null: return k.world
	var s = _svc()
	if s != null and s.fp != null: return s.fp.world
	return null

# ---------- running ----------
func _process(dt: float) -> void:
	if kind == "":
		var pending: String = Game.s.get("story", {}).get("training", "")
		if _kitchen() == null or Kit.main.modal_root.visible: return
		if pending != "": start(pending)
		elif Story.guide_due() > 0: start_guide(Story.guide_due())
		return
	if not is_same(Game.s, game_ref):               # a new game was started (or loaded) under us: this training day is void
		_stop()
		return
	_point()
	if wait > 0.0:
		wait -= dt
		return
	if Kit.main.modal_root.visible: return             # a hands-on job or a message is open: let them finish it
	var st: Dictionary = steps[i]
	if st.has("done") and st.done.call(): _next()

## Marco guiding a real shift (it counts): the first pizza of day 1, a briefing on days 2 to 4
func start_guide(n: int) -> void:
	kind = "day%d" % n
	guide = n
	game_ref = Game.s
	steps = _day1() if n == 1 else [{"say": Story.briefing(), "tap": true}]
	i = 0
	panel.visible = true
	_enter()

## opening is not blocked by a guide (only by a training day that has more to show)
func may_open() -> bool:
	return kind == "" or guide > 0 or training_service()

func start(k: String) -> void:
	if k == "pizzaiolo":                                # an older save: the first shift is guided now instead
		Game.s.story.training = ""
		return
	var S: Dictionary = Game.s.story
	if S.has("train_snap"):                             # the game was closed during a training day: start it again
		Game.s = S.train_snap.duplicate(true)
		Game.normalise()
		S = Game.s.story
	kind = k
	var snap: Dictionary = Game.s.duplicate(true)
	Game.s.story.train_snap = snap
	game_ref = Game.s
	Game.s.view3d = true
	steps = _senior()
	i = 0
	panel.visible = true
	_enter()

func _enter() -> void:
	while i < steps.size() and steps[i].has("skip") and steps[i].skip.call(): i += 1
	if i >= steps.size():
		finish()
		return
	var st: Dictionary = steps[i]
	mark = {}
	if st.has("setup"): st.setup.call()
	text_l.text = st.say
	foot_l.text = ("Tap here to carry on" if st.get("tap", false) else "Step %d of %d" % [i + 1, steps.size()])
	wait = 0.6
	Art.sfx("tap")

func _next() -> void:
	i += 1
	Art.sfx("up")
	_enter()

func _panel_input(e: InputEvent) -> void:
	var press: bool = (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed)
	if press and kind != "" and i < steps.size() and steps[i].get("tap", false) and wait <= 0.0: _next()

## stop without touching the game (it was replaced: a new game, or a save loaded)
func _stop() -> void:
	kind = ""
	guide = 0
	game_ref = null
	panel.visible = false
	hl.visible = false

## the training day is over (or skipped): the game goes back to how it was, ready for the real shift
func finish() -> void:
	if kind == "": return
	if guide > 0:                                       # a guide: nothing to put back, it just ends
		Game.s.story["guided_%d" % guide] = true
		Game.save_game()
		kind = ""
		guide = 0
		game_ref = null
		panel.visible = false
		hl.visible = false
		var gw = _world()
		if gw != null: gw.set_highlight(null)
		return
	var k := kind
	kind = ""
	game_ref = null
	panel.visible = false
	hl.visible = false
	var w = _world()
	if w != null: w.set_highlight(null)
	var base: Dictionary = Game.s.story.get("train_snap", Game.s)
	Game.s = base
	Game.normalise()
	Game.s.story.erase("train_snap")
	Game.s.story.training = ""
	Game.s.story["trained_" + k] = true
	Game.save_game()
	Kit.main.close_modal()
	Kit.main.show_hub("home")
	if k == "pizzaiolo":
		Kit.main.message("Training done", "%s: \"That is the job. Tomorrow is today: your first real shift. The prep list is on the checklist, the tickets are on the rail. Shout if you need me.\"" % Story.BOSS, "Start the day")
	else:
		Kit.main.message("Training done", "%s: \"That is a senior's day. From now on the kitchen is yours: the checklist in the corner keeps you honest. I will be checking.\"" % Story.BOSS, "Start the day")

## the marker in the world, or the box round a button
func _point() -> void:
	var w = _world()
	var at: String = steps[i].get("at", "") if i < steps.size() else ""
	hl.visible = false
	if w != null: w.set_highlight(null)
	if at == "": return
	if at.begins_with("hud:"):
		var c: Control = _hud(at.substr(4))
		if c != null and c.is_visible_in_tree():
			var r := c.get_global_rect().grow(6)
			hl.position = r.position
			hl.size = r.size
			hl.modulate.a = 0.6 + 0.4 * sin(Time.get_ticks_msec() / 150.0)
			hl.visible = true
		return
	if w != null: w.set_highlight(w.node_for(at))

func _hud(what: String) -> Control:
	var k = _kitchen()
	var s = _svc()
	if what == "phone": return k.phone_btn if k != null else null
	if k != null and k.tab_btns.has(what): return k.tab_btns[what]
	if s != null and s.tab_btns.has(what): return s.tab_btns[what]
	return null

# ---------- small helpers the steps use ----------
func _view() -> String:
	var w = _world()
	return w.cur_view() if w != null else ""

func _pizza():
	var s = _svc()
	return s.bench if s != null else null

func _first_ticket():
	var s = _svc()
	if s == null: return null
	for tk in s.tickets:
		if tk.p.get("training", false): return tk
	return null

func _prepped_total() -> float:
	var t := 0.0
	for id in Game.s.prepped: t += Stock.prepped(id)
	return t

func _pans_filled() -> int:
	var n := 0
	for p in Stock.rail():
		if p.ing != "" and p.q > 0.5: n += 1
	return n

func _prep_rest() -> void:
	for row in Day.prep_list():
		if row.raw > 0 and row.get("block", "") == "": Stock.prep(row.id, row.raw, 0.7)

func _mean_r(pz) -> float:
	var t := 0.0
	for x in pz.base.r: t += x
	return t / max(1, pz.base.r.size())

# ---------- day 1: you stretch, Marco does the rest ----------
func _day1() -> Array:
	return [
		{"say": "Morning! I'm %s, and this is %s. Drag your finger across the screen to look around the kitchen." % [Story.BOSS, Story.EMPLOYER],
			"setup": func(): mark.yaw = _world().yaw,
			"done": func(): return abs(angle_difference(deg_to_rad(_world().yaw), deg_to_rad(mark.yaw))) > deg_to_rad(30.0) or _view() != "front"},
		{"say": "%s has done the prep and set up the counter. Today you do one job: you stretch the bases, and I do the rest. When you are ready, tap the sign above the pass (or the clock, top left) to open." % Story.JUNIOR, "at": "job:open",
			"done": func(): return _svc() != null},
		{"say": "Tickets hang on the rail above the counter. Here is your first: tap it to start it. The dough ball goes on the marble.", "at": "ticket",
			"setup": func(): _svc().training_order("margherita"),
			"done": func(): return _pizza() != null},
		{"say": "With an empty hand, press the dough out from the middle with one finger, working outwards. Stop short of the edge to leave a rim for the crust.", "at": "surface:bench",
			"setup": func(): mark.r = _mean_r(_pizza()) if _pizza() != null else 0.0,
			"done": func(): return _pizza() != null and _mean_r(_pizza()) > mark.r * 1.3},
		{"say": "Now two fingers on the dough: spread them apart to stretch it out to the ring, and twist them to turn it. Round, even, and out to the ring.", "at": "surface:bench",
			"done": func(): return _pizza() != null and _pizza().base.diameter_cm() >= _pizza().d.size_cm * 0.85},
		{"say": "That is a base. Turn to the Oven to hand it to me: I top it, bake it, cut it and send it.", "at": "hud:oven",
			"done": func(): return _svc() != null and _pizza() == null},
		{"say": "In it goes. That is your day: take each ticket as it comes in, stretch it, and bring it to me. I will keep up, and if a ticket waits too long I make it myself.", "tap": true},
	]

# ---------- the senior pizzaiolo's training day ----------
func _senior() -> Array:
	return [
		{"say": "Senior pizzaiolo! Today I show you the morning and the evening the way I want them done. Training again: nothing counts. Temperatures first: turn to the Stores and tap the thermometer on the fridge door.", "at": "job:temp_fridge",
			"setup": func(): _senior_setup(),
			"done": func(): return Checks.logged("fridge")},
		{"say": "And the freezer.", "at": "job:temp_freezer",
			"skip": func(): return Stock.store_cap("freezer") <= 0,
			"done": func(): return Checks.logged("freezer")},
		{"say": "A delivery is at the back door. Tap the crates: check it in and put it on the shelves, new stock behind the old so the old gets used first.", "at": "job:crates",
			"done": func(): return Game.s.dock.is_empty()},
		{"say": "One of the traps has caught something. Tap the box of traps: reset the sprung one on the floor plan, and put traps where you see droppings.", "at": "job:traps",
			"done": func(): return Hygiene.sprung() == 0},
		{"say": "Luca preps to the list you leave him the night before, and the porter folds the boxes. Check the counter is set up: turn to the Counter and tap a pan.", "at": "hud:bench",
			"setup": func(): _prep_rest(),
			"done": func(): return _pans_filled() >= 4},
		{"say": "Your phone has the stores, the ordering and the menu. Tap Phone and open the Stores page: what is in the fridge and the dry store, the vents, and anything stacked in front of older stock.", "at": "hud:phone",
			"done": func(): return _kitchen() != null and _kitchen().phone.visible and _kitchen().hub.tab == "stores"},
		{"say": "Put the phone away when you have had a look.",
			"done": func(): return _kitchen() != null and not _kitchen().phone.visible},
		{"say": "I am skipping service today: it is the evening now. Clean the kitchen down: turn to Prep and tap the mop.", "at": "job:clean_boh",
			"setup": func(): _senior_evening(),
			"done": func(): return Hygiene.level("boh") >= 80.0},
		{"say": "Wash the tubs: tap the sink.", "at": "job:wash",
			"done": func(): return Stock.dirty_tubs() == 0},
		{"say": "Make tomorrow's dough: tap the mixer. Weigh it out, knead it, ball it.", "at": "job:dough",
			"done": func(): return Game.s.dough.any(func(l): return int(l.d) == Game.s.day)},
		{"say": "Order for tomorrow on your phone: Suppliers. The par sheet shows what tomorrow needs. Fill the basket and place the order.", "at": "hud:phone",
			"setup": func(): mark.orders = Game.s.orders.size(),
			"done": func(): return Game.s.orders.size() > mark.orders},
		{"say": "Leave Luca his prep list for the morning: on your phone, Jobs, the prep sheet for tomorrow. Set it and save it.", "at": "hud:phone",
			"done": func(): return int(Game.s.story.get("sheet_day", -1)) == Game.s.day + 1},
		{"say": "Last thing: the evening temperatures. The fridge thermometer again.", "at": "job:temp_fridge",
			"done": func(): return Checks.logged("fridge", -1, "pm")},
		{"say": "That is a senior's day. The closing checklist in the corner tells you what is left. Tomorrow it is all yours.", "tap": true},
	]

## a morning with something to do in it: a delivery at the back door, a sprung trap, dirty tubs, no temperatures yet
func _senior_setup() -> void:
	var s: Dictionary = Game.s
	s.phase = "morning"
	s.clock = Day.START
	s.templog = s.templog.filter(func(e): return int(e.day) != s.day)
	if s.dock.is_empty():
		var lines := []
		for e in [["mozz", 5000.0, 3], ["tomato", 5000.0, 3], ["flour00", 25000.0, 3]]:
			var g: int = e[2] if Data.ING[e[0]].g.has(e[2]) else Data.ING[e[0]].grade_list[0]
			lines.append({"ing": e[0], "g": g, "q": e[1], "c": Data.ING[e[0]].g[g].price, "name": Data.ING[e[0]].g[g].name, "what": Data.qty(e[0], e[1]), "life": int(Data.ING[e[0]].g[g].life)})
		s.dock.append({"sup": "harbour", "arrived": Day.START, "lines": lines, "total": 80.0})
	if Hygiene.traps().size() > 0: Hygiene.traps()[0].sprung = true

func _senior_evening() -> void:
	var s: Dictionary = Game.s
	s.phase = "evening"
	s.clock = int(Day.close_time()) + 15
	s.clean.boh = 55.0
	Stock.wash_add(4, 3)
	Stock.wash_add(2, 2)

class_name ServiceScreen
extends VBoxContainer
## One day's trading. This runs the whole simulation: customers arriving and what they think, the queue and
## the tables, tickets, your bench, the oven, and everything the staff do on their own.
## FrontScene, Bench and OvenView only draw it and pass your touches back in.
##
## A pizza's journey: ticket (new) -> claimed by you or a pizzaiolo (make) -> oven -> the pass -> handed over.
## When a party has everything it ordered it pays, tips and leaves a review (see settle()).
##
## The day runs on a clock from the venue's opening to closing time (DAY seconds at 1x). Toppings come off the
## makeline, which was prepped in the morning. When something runs out you prep more (which ties you up), a
## prep cook or pizzaiolo does it, or you 86 the pizzas that need it. Deliveries can turn up mid-shift at the
## back door. The kitchen and dining room get dirtier as you go, and if there are mice, customers may see one.

const DAY := 300.0              # seconds of trading at 1x speed

var c: Dictionary                # Game.calc() for today
var L: Dictionary                # layout of the front-of-house scene
var t := 0.0
var acc := 0.95
var speed := 1
var nid := 1
var pid := 1
var tickets := []
var parties := []
var queue := []                  # takeaway parties waiting to order
var waiters := []                # takeaway parties waiting for their food
var door := []                   # dine-in parties waiting for a table
var tables := []
var workers := []                # pizzaioli
var foh := []                    # front-of-house staff
var oven: Oven
var board := []                  # your baked pizzas waiting to be sliced
var bench: Pizza = null          # the pizza you are making
var tool := ""                   # ingredient in your hand ("" on the board = the pizza wheel)
var view := "front"              # front / bench / oven / board
var floats := []
var reviews := []
var r := {}
var dirty := true
var done := false
var pop_t := 0.0
var busy := {}                   # what you are tied up doing: {label, left, total (seconds), fn}
var eighty6 := {}                # pizza id -> true: taken off the menu for tonight
var crew := []                   # prep cooks and kitchen porters: {s, role, job, left, fn}
var prepping := {}               # ingredient id -> who is prepping it
var mouse := {}                  # a mouse running across the front: {pos, vel, t}
var mouse_until := -1.0          # minute until which customers are still talking about the mouse
var gm := 1.0                    # game minutes per second of play
var ladle_oz := 2                # the ladle in your hand: 1, 2 or 4 oz
var ladle_g := 0.0               # sauce in it right now
var ladle_ing := ""
var phones := []                 # calls ringing: {n, until}
var tablet := []                 # delivery-app orders pinging on the tablet: {n, until}
var app_acc := 0.0
var training := false            # a training day: no customers of its own, nobody else takes the tickets (see Tutor)
var helps := []                  # the steps of your pizzas Marco does today (Story.marco_does): stretch, top, oven, board
var card_full := false           # the recipe card shows everything (otherwise the short version)
var stats_row: HBoxContainer
var marco_board_t := 0.0         # Marco cutting and sending what has come off the oven
var carried: Pizza = null        # the pizza you took from the bench to the oven and have not loaded yet
var spiked := []                 # tickets that have just gone (walked out, collected): {tk, why, until (msec)} - they stay on the rail a moment
var critic_at := -1.0            # when the food critic walks in today (-1: not today)
var critic_in := false

# ui
var front: FrontScene
var fp: FPView = null            # the 3D first-person kitchen (null in the classic 2D layout)
var fp_mode := false
var board_ui: Bench              # the cutting board as its own surface (3D only)
var bench_ui: Bench
var rail_ui: RailView
var oven_ui: OvenView
var kitchen: HBoxContainer
var tick_box: VBoxContainer
var info: VBoxContainer
var palette: VBoxContainer
var mini_panel: PanelContainer
var mini_box: VBoxContainer
var btn_row: HBoxContainer
var top_bar: HBoxContainer            # the strip along the top (the station buttons go here when the phone looks)
var tool_hand := 0                    # which hand holds the topping or the ladle: 0 the right, 1 the left (3D)
var put_btn: Button                   # "Put down the pepperoni": hands free in one tap (3D)
var tab_btns := {}
var top_lbl := {}
var clock: ProgressBar
var next_btn: Button
var bin_btn: Button
var auto_btn: Button
var pop: PanelContainer
var tick_bars := {}
var info_rows := []              # [[Label, Callable -> [text, colour]]] refreshed every frame
var prep_scroll: ScrollContainer
var prep_box: VBoxContainer
var busy_panel: PanelContainer
var busy_wrap: CenterContainer
var busy_lbl: Label
var busy_bar: ProgressBar
var pal_btns := []               # [[Button, ingredient id]]

func _ready() -> void:
	var G := Game
	c = G.calc()
	r = {"day": G.s.day, "served": 0, "mine": 0, "lost": 0, "sold": 0, "food": 0.0, "tips": 0.0, "drinks": 0.0, "deliv": 0.0,
		"qsum": 0.0, "xp": 0.0, "walked": 0, "gave_up": 0, "rep0": G.s.rep, "lvl0": G.s.level, "cats": {"look": 0.0, "taste": 0.0, "service": 0.0, "value": 0.0}, "n_rev": 0,
		"mice": 0, "eighty6": [], "inspect": {}, "closed": false, "boh0": Hygiene.level("boh"), "foh0": Hygiene.level("foh"), "notes": [],
		"complaints": 0, "refunds": 0.0, "comps": 0.0, "allergy": 0, "missed": 0, "calls": 0, "change_err": 0.0, "regulars": [], "critic": -1.0, "mods": 0}
	gm = (c.close - c.open) / DAY
	# opened late: the start of the day has gone
	t = clamp((float(G.s.clock) - c.open) / (c.close - c.open), 0.0, 0.9) * DAY
	G.s.phase = "service"
	training = Tutor.training_service()
	if G.s.day >= int(G.s.critic_next) and G.s.level >= 3 and not training: critic_at = randf_range(0.2, 0.7) * DAY
	oven = Oven.new(G.tier("oven"))
	if oven.def.feeds: _light_for_service()
	helps = Story.marco_does()
	if Story.stage() == "pizzaiolo":
		# Marco works the line beside you: on the first days only picking up tickets that have waited (the rest go
		# through your hands), from day 4 making his own pizzas from the rail like you
		workers.append({"s": {"name": Story.BOSS, "skill": 4, "role": "pizzaiolo"}, "job": null, "left": 0.0, "prep": "", "raw": 0.0, "backup": not helps.is_empty()})
	else:
		for x in G.staff_of("pizzaiolo"): workers.append({"s": x, "job": null, "left": 0.0, "prep": "", "raw": 0.0})
	for role in ["cashier", "server", "host", "porter", "driver"]:
		for x in G.staff_of(role): foh.append({"s": x, "role": role, "cd": 1.0})
	for role in ["prep", "porter"]:
		for x in G.staff_of(role): crew.append({"s": x, "role": role, "job": "", "left": 0.0, "fn": Callable()})
	var missing := Stock.assign_rail(Day.line_ids())
	if Equip.rail_size() < int(G.tier("prep").rail): r.notes.append("The counter takes %d gastronorm pans and you own %d, so you worked out of %d slots. Order more from %s." % [int(G.tier("prep").rail), Equip.count(Equip.rail_pan_id()), Equip.rail_size(), Equip.SHOP.name])
	if missing.size() > 0: r.notes.append("No room on the rail for: " + ", ".join(missing.map(func(i): return Data.ING[i].name.to_lower())) + ".")
	_layout()
	_build_ui()
	set_view("front")

# ---------- layout of the front-of-house scene (640 x 320 units) ----------
func _layout() -> void:
	var n: int = c.tables
	L = {"dine": n > 0}
	if n == 0:
		L.win = Vector2(232, 170)
		L.spawn = Vector2(680, 235)
		L.back = Vector2(46, 262)
	else:
		L.win = Vector2(62, 70)
		L.spawn = Vector2(625, 345)
		L.back = Vector2(24, 300)
		var cols := int(ceil(sqrt(n * 1.9)))
		var rows := int(ceil(float(n) / cols))
		var cw := 430.0 / cols
		var ch := 235.0 / rows
		for i in n:
			tables.append({"i": i, "pos": Vector2(195 + cw * (i % cols + 0.5), 22 + ch * (i / cols + 0.5)), "party": null, "dirty": false, "k": clamp(min(cw / 70.0, ch / 62.0), 0.45, 1.25)})

func q_pos(i: int) -> Vector2:
	if L.dine: return Vector2(95 + min(i, 3) * 28, 62 + max(0, i - 3) * 6)
	return Vector2(285 + min(i, 7) * 44, 228)
func w_pos(i: int) -> Vector2:
	if L.dine: return Vector2(78 + (i % 4) * 28, 292 - (i / 4) * 5)
	return Vector2(300 + (i % 8) * 42, 292)
func d_pos(i: int) -> Vector2:
	return Vector2(585 - i * 30, 296)

# ---------- ui ----------
func _build_ui() -> void:
	add_theme_constant_override("separation", 8)
	fp_mode = Game.s.get("view3d", true)
	var top := Kit.hbox(12)
	top_bar = top
	add_child(top)
	# the time. In 3D you clock out early on the clock above the pass; the 2D layout has no room, so its time is the
	# button (at closing time the day ends by itself)
	if fp_mode: top_lbl.time = Kit.label("", 20, Kit.INK)
	else:
		top_lbl.time = Kit.button("", _ask_close, "ghost", 20)
		top_lbl.time.tooltip_text = "Tap the clock to close up early"
	top_lbl.time.custom_minimum_size.x = 120
	top.add_child(top_lbl.time)
	clock = Kit.bar(0, Kit.CHEESE, 12)
	clock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(clock)
	for k in ["count", "dough", "rep"]:
		top_lbl[k] = Kit.label("", 19, Kit.MUTED)
		if not fp_mode or k == "rep": top.add_child(top_lbl[k])     # in 3D, served and dough are on the full card
	top_lbl.cash = Kit.label("", 26, Kit.CHEESE)
	top.add_child(top_lbl.cash)
	top_lbl.phone = Kit.button("Phone ringing", answer_phone, "danger", 19)
	top_lbl.phone.visible = false
	top.add_child(top_lbl.phone)
	top_lbl.tablet = Kit.button("", accept_app, "danger", 19)
	top_lbl.tablet.visible = false
	top.add_child(top_lbl.tablet)
	if Game.s.app.on and not Story.employed():
		top_lbl.app = Kit.button("", func():
			Game.s.app.paused = not Game.s.app.paused
			dirty = true, "ghost", 17)
		top.add_child(top_lbl.app)
	top_lbl.speed = Kit.button("1x", _speed, "primary", 19)
	top.add_child(top_lbl.speed)

	if fp_mode: _build_fp_body()
	else: _build_2d_body()

	pop = Kit.panel(Kit.INK, 14)
	pop.visible = false
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pop.top_level = true
	add_child(pop)

## the classic layout: tickets on the left, the station in the middle, the recipe card on the right
func _build_2d_body() -> void:
	var body := Kit.hbox(12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)
	var left := Kit.vbox(6)
	left.custom_minimum_size.x = 250
	left.add_child(Kit.label("ORDERS", 15, Kit.MUTED))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tick_box = Kit.vbox(6)
	tick_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(tick_box)
	left.add_child(sc)
	body.add_child(left)

	var mid := Kit.vbox(8)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(mid)
	var tabs := Kit.hbox(6)
	for k in ["front", "bench", "oven", "board", "prep"]:
		var b := Kit.button("", set_view.bind(k), "tab", 19)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)
		tab_btns[k] = b
	mid.add_child(tabs)
	front = FrontScene.new(self)
	mid.add_child(front)
	kitchen = Kit.hbox(10)
	kitchen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(kitchen)
	var bcol := Kit.vbox(8)
	bcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kitchen.add_child(bcol)
	rail_ui = RailView.new(self)
	bcol.add_child(rail_ui)
	var stack := Control.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bcol.add_child(stack)
	bench_ui = Bench.new(self)
	stack.add_child(bench_ui)
	oven_ui = OvenView.new(self)
	stack.add_child(oven_ui)
	prep_scroll = ScrollContainer.new()
	prep_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	prep_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	prep_box = Kit.vbox(8)
	prep_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prep_scroll.add_child(prep_box)
	stack.add_child(prep_scroll)
	busy_wrap = CenterContainer.new()
	busy_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	busy_wrap.visible = false
	busy_panel = Kit.panel(Color(0.05, 0.08, 0.06, 0.92), 18)
	var bv := Kit.vbox(8)
	busy_lbl = Kit.label("", 22, Kit.INK, true)
	busy_lbl.custom_minimum_size.x = 380
	bv.add_child(busy_lbl)
	busy_bar = Kit.bar(0, Kit.CHEESE, 14)
	bv.add_child(busy_bar)
	bv.add_child(Kit.button("Stop and leave it", stop_busy, "ghost", 18))
	busy_panel.add_child(bv)
	busy_wrap.add_child(busy_panel)
	stack.add_child(busy_wrap)
	btn_row = Kit.hbox(8)
	bin_btn = Kit.button("Bin", bin, "ghost", 22)
	btn_row.add_child(bin_btn)
	auto_btn = Kit.button("Use the sheeter", sheeter, "ghost", 22)
	btn_row.add_child(auto_btn)
	next_btn = Kit.button("", next, "primary", 24)
	next_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_child(next_btn)
	bcol.add_child(btn_row)
	var right := Kit.vbox(8)
	right.custom_minimum_size.x = 320
	kitchen.add_child(right)
	var sp := Kit.panel(Kit.PANEL, 10)
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sv := Kit.vbox(6)
	info = Kit.vbox(3)
	palette = Kit.vbox(5)
	sv.add_child(info)
	sv.add_child(palette)
	sp.add_child(sv)
	right.add_child(sp)
	mini_panel = Kit.panel(Color("3a2a22"), 10)
	mini_box = Kit.vbox(3)
	mini_panel.add_child(mini_box)
	right.add_child(mini_panel)


## the 3D first-person layout: the kitchen fills the screen and a light HUD sits over it
func _build_fp_body() -> void:
	var stack := Control.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(stack)
	front = FrontScene.new(self)           # the 3D crowd replaces its drawing; its taps and markers still come from here
	kitchen = Kit.hbox(10)
	rail_ui = RailView.new(self)
	bench_ui = Bench.new(self)
	bench_ui.mode = "bench"
	board_ui = Bench.new(self)
	board_ui.mode = "board"
	oven_ui = OvenView.new(self)
	prep_scroll = ScrollContainer.new()
	prep_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	prep_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	prep_box = Kit.vbox(8)
	prep_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prep_scroll.add_child(prep_box)
	var tablet_ui := Kit.panel(Kit.BG, 14, 0)
	tablet_ui.add_child(prep_scroll)
	fp = FPView.new(self, {"bench": bench_ui, "board": board_ui, "oven": oven_ui, "prep": tablet_ui})
	fp.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(fp)
	# the ticket list, for when you would rather read them flat (hidden: the tickets hang on the rail in 3D)
	var tl := ScrollContainer.new()
	tl.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tl.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	tl.offset_right = 250
	tl.offset_bottom = -70
	tick_box = Kit.vbox(6)
	tick_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.add_child(tick_box)
	tl.visible = false
	stack.add_child(tl)
	# looking around: the stick in the corner, and one button per station beside it (see LookStick.lay_out)
	var tabs := Kit.hbox(5)
	for k in ["front", "bench", "oven", "board", "prep"]:
		var b := Kit.button("", (func(st): fp.world.face(st)).bind(k) if LookStick.phone_look() else set_view.bind(k), "tab", 16)
		b.custom_minimum_size = Vector2(84, 46)
		tabs.add_child(b)
		tab_btns[k] = b
	var lb := Kit.button("List", func(): tl.visible = not tl.visible, "ghost", 15)
	lb.custom_minimum_size = Vector2(56, 46)
	tabs.add_child(lb)
	var stk := LookStick.lay_out(stack, fp.world, tabs, top_bar)
	btn_row = Kit.hbox(8)
	btn_row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	var lift: float = (stk.custom_minimum_size.x + 10.0) if stk != null and Game.s.get("stick_right", false) else 0.0   # clear of a right-hand stick
	btn_row.offset_top = -62 - lift
	btn_row.offset_bottom = -8 - lift
	btn_row.offset_left = -470
	btn_row.offset_right = -8
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	# holding a topping or the cheese: one tap puts it back, hands free (tapping its pan again does the same). Its own
	# corner: in 3D the row above is hidden (the pass, the bin and the sheeter are in the room)
	put_btn = Kit.button("", put_down, "primary", 18)
	put_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	put_btn.offset_left = -300
	put_btn.offset_right = -10
	put_btn.offset_top = -62 - lift
	put_btn.offset_bottom = -10 - lift
	put_btn.visible = false
	stack.add_child(put_btn)
	bin_btn = Kit.button("Bin", bin, "ghost", 20)
	btn_row.add_child(bin_btn)
	auto_btn = Kit.button("Sheeter", sheeter, "ghost", 20)
	btn_row.add_child(auto_btn)
	next_btn = Kit.button("", next, "primary", 22)
	next_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_child(next_btn)
	stack.add_child(btn_row)
	# the recipe card and what is in your hand, top right, folded away on request
	var card := Kit.panel(Color(0.1, 0.14, 0.11, 0.82), 10)
	card.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	card.offset_left = -330
	card.offset_right = -8
	card.offset_top = 8
	var sv := Kit.vbox(6)
	info = Kit.vbox(3)
	palette = Kit.vbox(5)
	stats_row = Kit.hbox(10)                   # served and dough, on the full card only
	stats_row.add_child(top_lbl.count)
	stats_row.add_child(top_lbl.dough)
	stats_row.visible = false
	sv.add_child(stats_row)
	sv.add_child(info)
	sv.add_child(palette)
	mini_panel = Kit.panel(Color("3a2a22"), 8)
	mini_box = Kit.vbox(3)
	mini_panel.add_child(mini_box)
	sv.add_child(mini_panel)
	card.add_child(sv)
	stack.add_child(card)
	# the card is short by default (the pizza, its size and grams, the one thing to do next); tap for the full card
	var cb := Kit.button("More", func(): pass, "ghost", 15)
	cb.pressed.connect(func():
		card_full = not card_full
		cb.text = "Less" if card_full else "More"
		stats_row.visible = card_full
		_build_side())
	cb.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	cb.offset_left = -400
	cb.offset_right = -338
	cb.offset_top = 8
	stack.add_child(cb)
	busy_wrap = CenterContainer.new()
	busy_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	busy_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	busy_wrap.visible = false
	busy_panel = Kit.panel(Color(0.05, 0.08, 0.06, 0.92), 18)
	var bv := Kit.vbox(8)
	busy_lbl = Kit.label("", 22, Kit.INK, true)
	busy_lbl.custom_minimum_size.x = 380
	bv.add_child(busy_lbl)
	busy_bar = Kit.bar(0, Kit.CHEESE, 14)
	bv.add_child(busy_bar)
	bv.add_child(Kit.button("Stop and leave it", stop_busy, "ghost", 18))
	busy_panel.add_child(bv)
	busy_wrap.add_child(busy_panel)
	stack.add_child(busy_wrap)

## the clock, in minutes after midnight
func minute() -> float:
	return c.open + t * gm

## seconds of play that `mins` game minutes take
func secs(mins: float) -> float:
	return mins / gm

# ---------- being tied up ----------
## true if you are free; otherwise says what you are doing and returns false
func is_free() -> bool:
	if busy.is_empty(): return true
	Kit.main.toast("You are busy: %s" % busy.label.to_lower(), true)
	return false

func start_busy(label: String, mins: float, fn: Callable) -> void:
	busy = {"label": label, "left": secs(mins), "total": secs(mins), "fn": fn}
	dirty = true

## stop what you are doing: the job is left part-done
func stop_busy() -> void:
	if busy.is_empty(): return
	var frac: float = 1.0 - busy.left / max(busy.total, 0.001)
	var fn: Callable = busy.fn
	busy = {}
	fn.call(frac)
	dirty = true

func set_view(v: String) -> void:
	# turning to the oven, the pizza on the bench comes with you on the peel; turn back without loading it and it
	# goes back on the bench
	if v == "oven" and view != "oven" and bench != null and busy.is_empty(): carried = _carry_to_oven(false)
	elif v == "bench" and view == "oven" and bench == null and carried != null and oven.shelf.has(carried):
		oven.shelf.erase(carried)
		carried.stage = "shape"
		bench = carried
		carried = null
	view = v
	if v != "board" and v != "bench": tool = ""
	if v == "board": tool = ""
	dirty = true

## the clock tapped (the one above the pass, or the 2D layout's): close up early?
func _ask_close() -> void:
	if done: return
	Kit.main.confirm("Close early?", "Anyone still waiting leaves unserved, and anything half-made goes in the bin.", "Close up", func(): finish(false))

func _speed() -> void:
	var mx := 8 if workers.size() > 0 else 4
	speed = 1 if speed >= mx else speed * 2
	top_lbl.speed.text = "%dx" % speed

# ---------- customers ----------
func set_pat(p: Dictionary, secs: float) -> void:
	if p.get("training", false):         # practice customers wait as long as you need
		p.max = 99999.0
		p.pat = p.max
		return
	if p.max > 0: p.waits.append(clamp(p.pat / p.max, 0.0, 1.0))
	p.max = secs * c.patience * randf_range(0.9, 1.1)
	p.pat = p.max

func spawn_party() -> int:
	var type := "take"
	if c.delivery > 0 and randf() < float(c.delivery) / c.total: type = "deliv"
	elif tables.size() > 0 and randf() < 0.65: type = "dine"
	var n: int = [1, 1, 1, 1, 2].pick_random()
	if type == "dine": n = [1, 2, 2, 2, 3, 3, 4].pick_random()
	elif type == "deliv": n = [1, 1, 2].pick_random()
	pid += 1
	var p := {"id": pid, "type": type, "n": n, "pos": L.spawn, "target": L.spawn, "state": "", "pat": 0.0, "max": 0.0, "tks": [], "got": 0, "items": [],
		"waits": [], "table": -1, "timer": 0.0, "gone": false, "look": randi() % 6, "hue": randf(), "nobox": false, "want_x": 0, "got_x": 0, "xitems": [], "drinks": []}
	var reg = _pick_regular()
	if reg != null:
		p.reg = reg.name
		p.n = 1
		p.look = int(reg.look)
		if reg.type == "dine" and tables.size() > 0: p.type = "dine"
		elif type != "deliv": p.type = "take"
		type = p.type
		n = 1
	elif critic_at >= 0 and not critic_in and t >= critic_at and type != "deliv":
		p.critic = true
		critic_in = true
	elif type == "take" and randf() < 0.15:
		phones.append({"n": n, "until": t + 10.0})
		r.calls += 1
		Art.sfx("ring")
		Art.buzz(220)
		dirty = true
		return n
	if type == "deliv":
		if not order(p): return n
		p.pos = Vector2(-100, -100)
	elif type == "dine" and door.size() >= 4:
		p.type = "take"
		p.n = min(n, 2)
	if p.type == "dine":
		door.append(p)
		p.state = "door"
		set_pat(p, 55)
	elif p.type == "take":
		if queue.size() >= c.queue_cap:
			r.lost += p.n
			r.walked += p.n
			return n
		queue.append(p)
		p.state = "queue"
		set_pat(p, 55)
	parties.append(p)
	return n

## what the tickets nobody has started yet have already promised away
func _pending() -> Dictionary:
	var pend := {}
	for tk in tickets:
		if tk.state == "new" and tk.owner == "":
			if tk.rec.has("base"): pend["d:" + tk.rec.base] = pend.get("d:" + tk.rec.base, 0.0) + 1.0
			for i in tk.rec.spec: pend[i] = pend.get(i, 0.0) + tk.rec.spec[i]
	return pend

func can_promise(rec: Dictionary, pend: Dictionary) -> bool:
	if eighty6.has(rec.id): return false
	if Equip.needs_tin(rec.base) and not Equip.has("pan_tin"): return false      # no tins, no deep pan
	if Stock.dough_ready(rec.base) - pend.get("d:" + rec.base, 0.0) < 1: return false
	for i in rec.spec:
		if Stock.potential(i) - pend.get(i, 0.0) < rec.spec[i] * 0.7: return false
	return true

## could this pizza still be sold tonight at all (dough, and the toppings in stock or on the line)
func sellable(rec: Dictionary) -> bool:
	if rec.get("extra", false): return extra_can(rec, {})
	return can_promise(rec, {})

# ---------- sides, desserts and drinks ----------
## could this extra be promised, given what the tickets nobody has started have already taken
func extra_can(x: Dictionary, pend: Dictionary) -> bool:
	if eighty6.has(x.id): return false
	for i in x.spec:      # what goes on from the rail needs a pan on the rail
		if (x.make == "oven" or x.make == "cold") and ["sauce", "cheese", "top"].has(Data.ING[i].kind) and Stock.rail_slot(i) < 0: return false
	if x.make == "oven": return can_promise(x, pend)
	for i in x.spec:
		if Stock.potential(i) - pend.get(i, 0.0) < float(x.spec[i]) * 0.9: return false
	return true

## each person may want a drink, a side or (not at a table) a dessert on top of their pizza. Returns how many were added.
func _order_extras(p: Dictionary, courses: Array) -> int:
	var added := 0
	for course in courses:
		var ch: float = float(Data.EXTRA_CHANCE[course][p.type])
		for k in p.n:
			if randf() >= ch: continue
			var pend := _pending()
			var opts: Array = Game.extras_on(course).filter(func(x): return extra_can(x, pend))
			if opts.is_empty(): continue
			_add_extra(p, opts.pick_random())
			added += 1
	return added

func _add_extra(p: Dictionary, x: Dictionary) -> void:
	if x.make == "hand":      # out of the fridge and handed over with the order
		var cost := 0.0
		for id in x.spec: cost += Stock.take(id, float(x.spec[id])).cost
		Stock.log_sale(x.spec.duplicate(), x.spec.duplicate(), cost, cost)
		p.drinks.append({"id": x.id, "name": x.name, "price": x.price, "cost": cost})
		r.drinks_n = r.get("drinks_n", 0) + 1
		return
	nid += 1
	var rec: Dictionary = Orders.build(x, []) if x.make == "oven" else x.duplicate(true)
	rec.key = x.id
	var tk := {"id": nid - 1, "rec": rec, "p": p, "state": "new", "owner": "", "gone": false, "age": 0.0, "x": true}
	tickets.append(tk)
	p.tks.append(tk)
	p.want_x = int(p.get("want_x", 0)) + 1

## a table that has finished eating: anyone for dessert? Returns how many were ordered.
func _order_desserts(p: Dictionary) -> int:
	return _order_extras(p, ["dessert"])

## plating something cold or making a drink: take it from the rail or the fridge. Returns the result a pizza would have.
func _plate(tk: Dictionary, skill: float, mine: bool) -> Dictionary:
	var x: Dictionary = tk.rec
	var use := {}
	var cost := 0.0
	var gsum := 0.0
	var got_all := true
	for id in x.spec:
		var want := float(x.spec[id])
		var t: Dictionary = Stock.take_use(id, want) if Stock.rail_slot(id) >= 0 else Stock.take(id, want)
		use[id] = t.got
		cost += t.cost
		gsum += float(t.g)
		if t.got < want * 0.85: got_all = false
	var grade: float = gsum / max(1, x.spec.size())
	var a := {"mine": mine, "notes": [], "grade": grade, "cost": cost, "spec_cost": cost, "use": use, "spec": x.spec.duplicate(),
		"look": clamp(55.0 + skill * 8.0 + randf_range(-6, 6), 20.0, 97.0), "taste": clamp(50.0 + grade * 9.0 + randf_range(-5, 5), 20.0, 98.0)}
	if not got_all:
		a.taste -= 25.0
		a.notes.append("The %s was a bit short" % x.name.to_lower())
	var dine: bool = tk.p.type == "dine"
	if dine and x.course != "drink" and not Equip.has("dessert_plate"):
		a.look -= 8.0
		a.notes.append("%s came on a pizza plate" % x.name)
	if dine and x.make == "bar" and x.id in ["espresso", "cappuccino"] and not Equip.has("coffee_cup"):
		a.look -= 10.0
		a.notes.append("Coffee in a glass")
	return a

## tickets in the order the kitchen should start them: an app order whose rider is due soon jumps the queue
func _by_due() -> Array:
	var out: Array = tickets.duplicate()
	var due := func(tk): return (float(tk.p.collect_t) - float(Data.APP.prep_secs) - 25.0) if tk.p.get("app", false) else (t - float(tk.age))
	out.sort_custom(func(a, b): return due.call(a) < due.call(b))
	return out

## the next drink waiting to be made at the machine or the bar
func _bar_ticket():
	for tk in tickets:
		if tk.state == "new" and tk.owner == "" and tk.rec.get("make", "") == "bar" and tk.age > 0.8: return tk
	return null

## you plate a cold side or dessert, or make a drink: you are tied up for a moment
func make_quick(tk: Dictionary) -> void:
	if not is_free(): return
	if not extra_can(tk.rec, {}):
		Kit.main.toast("Not enough left to make the %s" % tk.rec.name.to_lower(), true)
		return
	tk.owner = "me"
	tk.state = "make"
	start_busy(("Making " if tk.rec.make == "bar" else "Plating ") + tk.rec.name.to_lower(), float(tk.rec.mins), func(frac):
		if frac >= 0.99: to_pass(tk, _plate(tk, 3.0, true))
		else:
			tk.owner = ""
			tk.state = "new")
	dirty = true

## how long someone who has ordered will wait for their food (seconds of play). They can see the queue: they allow
## for every ticket ahead of theirs, at the pace this kitchen works (a pizza made by hand takes the best part of a
## minute; staff are quicker), plus the bake.
func food_patience(p: Dictionary) -> float:
	var hands: float = 1.0 + workers.size()
	var make: float = 45.0 if workers.is_empty() else 14.0
	var ahead := tickets.filter(func(tk): return tk.p != p and tk.state in ["new", "make"]).size()
	var expect: float = (float(ahead) / hands + p.n) * make + c.bake * oven_rounds(p.n)
	var base: float = {"take": 70.0, "dine": 90.0, "deliv": 100.0}.get(p.type, 80.0)
	return clamp(base + expect * 1.25, 100.0, 480.0)

## how many goes in the oven n pizzas take
func oven_rounds(n: int) -> float:
	return ceil(float(n) / max(1.0, float(oven.slots)))

## a ticket that has just gone stays on the rail a moment so you can see what happened
func spike(tk: Dictionary, why: String, secs_shown: float) -> void:
	spiked.append({"tk": tk, "why": why, "until": Time.get_ticks_msec() + int(secs_shown * 1000.0)})
	dirty = true

## a practice order for the training day: one pizza, for a table (or the hatch), that will wait as long as you need
func training_order(rec_id: String) -> void:
	pid += 1
	var p := {"id": pid, "type": "dine" if tables.size() > 0 else "take", "n": 1, "pos": L.spawn, "target": L.spawn, "state": "wait", "pat": 99999.0, "max": 99999.0,
		"tks": [], "got": 0, "items": [], "waits": [], "table": -1, "timer": 0.0, "gone": false, "look": randi() % 6, "hue": randf(), "nobox": false,
		"want_x": 0, "got_x": 0, "xitems": [], "drinks": [], "training": true, "dessert_asked": true}
	if p.type == "dine":
		var tb = free_table()
		if tb != null:
			tb.party = p
			p.table = tb.i
			p.pos = tb.pos
			p.target = tb.pos
	else:
		p.pos = w_pos(waiters.size())
		waiters.append(p)
	parties.append(p)
	nid += 1
	var tk := {"id": nid - 1, "rec": Orders.build(Data.REC[rec_id], []), "p": p, "state": "new", "owner": "", "gone": false, "age": 0.0}
	tickets.append(tk)
	p.tks.append(tk)
	Art.sfx("ding")
	dirty = true

## the party orders a pizza each. false = there was nothing left to sell them.
func order(p: Dictionary) -> bool:
	for k in p.n:
		var pend := _pending()
		var avail := Game.active_recipes().filter(func(rc): return can_promise(rc, pend))
		if avail.is_empty(): break
		nid += 1
		var rec: Dictionary = avail.pick_random()
		var mods := Orders.roll(rec, line_items(), 0.16 + 0.03 * Game.s.venue)
		var reg = _regular(p.get("reg", ""))
		if reg != null:
			for rc in avail:
				if rc.id == reg.fav: rec = rc
			mods = reg.mods if rec.id == reg.fav else []
		if mods.size() > 0: r.mods += 1
		var tk := {"id": nid - 1, "rec": Orders.build(rec, mods), "p": p, "state": "new", "owner": "", "gone": false, "age": 0.0}
		tickets.append(tk)
		p.tks.append(tk)
	if p.tks.is_empty():
		r.sold += p.n
		Game.s.rep += (2.5 - Game.s.rep) * max(0.003, 0.3 / (Game.s.ratings + 10))
		float_text(p.pos, "Sold out!", Kit.TOMATO)
		leave(p)
		return false
	p.n = p.tks.size()
	_order_extras(p, ["drink", "side"] if p.type == "dine" else ["drink", "side", "dessert"])     # at a table, dessert comes after the meal
	p.state = "wait"
	set_pat(p, food_patience(p))
	if p.type == "take":
		queue.erase(p)
		waiters.append(p)
	Art.sfx("ding")
	dirty = true
	return true

func leave(p: Dictionary) -> void:
	p.state = "leave"
	p.gone = true
	queue.erase(p)
	waiters.erase(p)
	door.erase(p)
	if p.table >= 0:
		tables[p.table].party = null
		p.table = -1
	if p.type == "deliv": parties.erase(p)

func ready_tks(p: Dictionary) -> Array:
	return p.tks.filter(func(tk): return tk.state == "pass")

func free_table():
	for tb in tables:
		if tb.party == null and not tb.dirty: return tb
	return null

## guests sitting down right now
func seated() -> int:
	var n := 0
	for tb in tables:
		if tb.party != null: n += int(tb.party.n)
	return n

## a place is a plate, a knife and fork and a glass
func places_free(n: int) -> bool:
	return seated() + n <= Equip.seats()

func act_seat(p: Dictionary) -> bool:
	var tb = free_table()
	if tb == null or not places_free(int(p.n)): return false
	door.erase(p)
	tb.party = p
	p.table = tb.i
	p.state = "sit"
	p.timer = 4.0
	set_pat(p, 60)
	return true

## hand over (or run to the table) every pizza of this party that is on the pass
func act_handover(p: Dictionary, by_player: bool = false) -> void:
	if p.get("app", false): p.late = max(0.0, t - float(p.collect_t))
	for tk in ready_tks(p):
		tickets.erase(tk)
		tk.state = "done"
		spike(tk, "COLLECTED" if p.type != "dine" else "SERVED", 2.5)
		p.got += 1
		var it: Dictionary = tk.res
		it.price = tk.rec.price
		it.rec = tk.rec
		if tk.get("x", false):
			p.got -= 1
			p.got_x = int(p.get("got_x", 0)) + 1
			p.xitems.append(it)
		else: p.items.append(it)
	dirty = true
	if p.got < p.n or int(p.get("got_x", 0)) < int(p.get("want_x", 0)): return
	if p.type == "dine":
		p.waits.append(clamp(p.pat / p.max, 0.0, 1.0))
		p.state = "eat"
		p.timer = (12.0 if p.get("dessert_asked", false) else 24.0) * c.turn
	else:
		if settle(p, false, by_player): leave(p)

func act_bill(p: Dictionary, by_player: bool = false) -> void:
	if settle(p, false, by_player): _depart(p)

## the party leaves; a table they sat at needs clearing
func _depart(p: Dictionary) -> void:
	var tb = tables[p.table] if p.table >= 0 else null
	if p.type == "dine":
		if not r.has("broken"): r.broken = {}
		Equip.breakage(int(p.n), r.broken)
	leave(p)
	if tb != null: tb.dirty = true

## The customer's verdict. They judge four things, each out of 5:
##   look     how the pizza looked: shape, spread of toppings, colour of the bake, slicing
##   taste    how well it was made, lifted or dragged down by the quality of the ingredients for the price
##   service  how long each stage kept them waiting, and whether there was a box
##   value    taste against what you charge
## The overall rating moves your reputation. Tips are more likely, and bigger, the better all of it was,
## and better ingredients raise both.
func settle(p: Dictionary, walked: bool, by_player: bool = false, force: bool = false) -> bool:
	if p.items.is_empty(): return true
	var v := _verdict(p, walked)
	if v.allergy:
		v.stars = 1.0
		v.paid = 0.0
		v.tip = 0.0
		r.allergy += 1
		Game.s.rep += (1.0 - Game.s.rep) * 0.08
		Game.s.hygiene.next = min(int(Game.s.hygiene.next), Game.s.day + 2)
		Kit.main.toast("A customer has had an allergic reaction!", true)
		_apply(p, v)
		return true
	if not walked and not force and not p.get("handled", false) and (v.stars < 2.6 or v.bad) and p.type != "deliv":
		r.complaints += 1
		p.handled = true
		if Game.calc().manager:
			_resolve(p, v, "refund" if v.stars < 1.8 else "drink")
			return false
		p.state = "complain"
		p.verdict = v
		set_pat(p, 45)
		float_text(p.pos, "Not happy!", Kit.TOMATO)
		Art.sfx("bad")
		Art.buzz(90)
		dirty = true
		return false
	if by_player and not walked and not force and p.type != "deliv" and randf() < 0.3 and not Kit.main.modal_root.visible:
		p.state = "paying"
		p.verdict = v
		_cash(p, v)
		return false
	_apply(p, v)
	return true

## what the party thinks of it all, before anything is paid
func _verdict(p: Dictionary, walked: bool) -> Dictionary:
	var G := Game
	var n: int = p.items.size()
	var expect: float = [1.6, 2.4, 3.4][G.s.price]     # ingredient grade people expect at this price level
	var v := {"n": n, "paid": 0.0, "look": 0.0, "taste": 0.0, "grade": 0.0, "notes": [], "allergy": false, "walked": walked, "bad": false}
	var cold: bool = p.type == "deliv" and not p.get("app", false) and randf() > Equip.bag_share()       # went out without a hot bag (app riders bring their own)
	var boards: bool = p.type == "dine" and randf() < float(Equip.count("serving_board")) / max(1, seated() + int(p.n))
	if cold: v.notes.append("Arrived cold")
	for it in p.items:
		var tt: float = clamp(it.taste + (it.grade - expect) * 7.0 - (15.0 if cold else 0.0), 0.0, 100.0)
		if boards: it.look = min(100.0, it.look + 4.0)
		v.look += it.look / n
		v.taste += tt / n
		v.grade += it.grade / n
		if tt >= 30.0: v.paid += it.price * c.price_mult
		else: v.bad = true
		if it.get("allergy", false): v.allergy = true
		for nt in it.notes:
			if not v.notes.has(nt): v.notes.append(nt)
		if not it.get("logged", false):
			Stock.log_sale(it.use, it.spec, it.cost, it.spec_cost)
			r.qsum += (it.look + tt) / 2.0
			it.logged = true
	p.waits.append(clamp(p.pat / max(p.max, 0.001), 0.0, 1.0))
	var pf := 0.0
	for w in p.waits: pf += w / p.waits.size()
	var dine: bool = p.type == "dine"
	if p.get("app", false):          # app customers only see whether it came on time
		pf = clamp(1.0 - float(p.get("late", 0.0)) / 30.0, 0.0, 1.0)
		if float(p.get("late", 0.0)) > 8.0: v.notes.append("The rider was kept waiting")
	var service: float = 100.0 * (0.2 + 0.8 * pf) + (c.rep_bonus * 20.0 if dine else 0.0)
	if p.nobox:
		service -= 30.0
		v.notes.push_front("No box to take it home in")
	elif int(p.get("fold_wait", 0)) > 0:
		service -= 4.0 * int(p.fold_wait)
		if int(p.fold_wait) >= 2: v.notes.append("Waited while they folded boxes")
	if walked: service -= 30.0
	var foh_clean := Hygiene.level("foh")
	if foh_clean < 60.0:
		service -= (60.0 - foh_clean) * 0.7
		v.notes.push_front("Sticky tables" if dine else "Grubby counter")
	if minute() < mouse_until:
		service -= 25.0
		v.notes.push_front("Saw a mouse!")
	if p.get("remade", false): service -= 10.0
	Hygiene.dirty("foh", (1.5 if dine else 0.6) * 30.0 * n / max(10.0, float(c.total)))
	service = clamp(service, 0.0, 100.0)
	var value: float = clamp(55.0 + (v.taste - 65.0) * 0.9 + [16.0, 0.0, -16.0][G.s.price], 0.0, 100.0)
	var overall: float = v.look * 0.2 + v.taste * 0.4 + service * 0.25 + value * 0.15
	v.service = service
	v.value = value
	v.overall = overall
	v.pf = pf
	v.stars = clamp(1.0 + overall / 25.0, 1.0, 5.0)
	for nt in v.notes:
		if nt.begins_with("I asked for no") or nt.begins_with("They ignored") or nt == "Toppings nobody ordered" or nt.begins_with("Wrong"): v.bad = true
	if v.bad: v.stars = min(v.stars, 2.0)
	v.tip = 0.0
	if v.paid > 0 and not walked:
		var chance: float = clamp(0.05 + (overall - 55.0) / 70.0 + (v.grade - 2.0) * 0.1 + (0.12 if dine else 0.0) + (0.15 if p.has("reg") else 0.0), 0.02, 0.97)
		if randf() < chance:
			v.tip = v.paid * (0.05 + 0.03 * v.grade + 0.04 * v.look / 100.0) * c.tip * (1.4 if dine else 1.0) * (0.5 + 0.5 * pf)
	v.drinks = 0.0
	for d in p.get("drinks", []): v.drinks += float(d.price) * c.price_mult
	for it in p.get("xitems", []):
		if it.rec.course == "drink":
			v.drinks += float(it.price) * c.price_mult
			if not it.get("logged", false): r.bar_n = r.get("bar_n", 0) + 1
		elif it.get("taste", 60.0) >= 30.0: v.paid += float(it.price) * c.price_mult
		if not it.get("logged", false):
			Stock.log_sale(it.use, it.spec, it.cost, it.spec_cost)
			it.logged = true
		if it.get("taste", 60.0) < 35.0 or it.get("look", 60.0) < 30.0: v.notes.append("The %s was not right" % it.rec.name.to_lower())
	v.deliv = 2.5 if p.type == "deliv" and not p.get("app", false) else 0.0
	return v

## money changes hands, the review is written, the rating moves
func _apply(p: Dictionary, v: Dictionary) -> void:
	var G := Game
	var stars: float = clamp(v.stars, 1.0, 5.0)
	G.s.ratings += 1
	var weight: float = max(0.02, 1.0 / (G.s.ratings + 4))
	if p.get("critic", false):
		weight = 0.25
		r.critic = stars
		G.s.buzz = {"until": G.s.day + 7, "mult": clamp(1.0 + (stars - 3.2) * 0.15, 0.75, 1.3)}
		G.s.critic_next = G.s.day + randi_range(14, 24)
	G.s.rep = clamp(G.s.rep + (stars - G.s.rep) * weight, 1.0, 5.0)
	var total: float = v.paid + v.tip + v.drinks + v.deliv
	if p.get("app", false):          # the app keeps its commission, and its rating of you moves with the review
		var fee: float = (v.paid + v.drinks) * float(Data.APP.commission)
		total -= fee
		r.app_fees = r.get("app_fees", 0.0) + fee
		_app_rate((stars - float(G.s.app.rating)) * 0.06)
	G.s.cash += total
	G.s.earned += total
	G.s.pizzas += v.n
	G.s.book.sales += v.paid
	r.food += v.paid
	r.tips += v.tip
	r.drinks += v.drinks
	r.deliv += v.deliv
	r.served += v.n
	var cats := {"look": 1.0 + v.look / 25.0, "taste": 1.0 + v.taste / 25.0, "service": 1.0 + v.service / 25.0, "value": 1.0 + v.value / 25.0}
	for k in cats: r.cats[k] += cats[k]
	r.n_rev += 1
	var text := _review_text(cats, v.notes)
	if v.allergy: text = "I had an allergic reaction. I told them about my allergy."
	var rv := {"stars": stars, "tip": v.tip, "text": text, "t": t}
	rv.merge(cats)
	reviews.append(rv)
	if reviews.size() > 60: reviews.pop_front()
	_regular_after(p, stars)
	float_text(p.pos, "%.1f stars  %s%s" % [stars, ("+" + Kit.cents(v.paid)) if v.paid > 0 else "refunded", ("  tip " + Kit.cents(v.tip)) if v.tip > 0 else ""], Kit.CHEESE if v.paid > 0 else Kit.TOMATO)
	Art.sfx("cash" if v.paid > 0 else "bad")
	dirty = true

## sorting out a complaint: "remake", "refund", "drink", "sorry", or "ignored"
func _resolve(p: Dictionary, v: Dictionary, choice: String) -> void:
	match choice:
		"remake":
			var worst := 0
			for k in p.items.size():
				if p.items[k].look + p.items[k].taste < p.items[worst].look + p.items[worst].taste: worst = k
			var old: Dictionary = p.items[worst]
			p.items.remove_at(worst)
			p.got -= 1
			nid += 1
			var tk := {"id": nid - 1, "rec": old.rec, "p": p, "state": "new", "owner": "", "gone": false, "age": 0.0}
			tickets.append(tk)
			p.tks.append(tk)
			p.remade = true
			p.state = "wait"
			if p.type == "take" and not waiters.has(p): waiters.append(p)
			set_pat(p, 100)
			float_text(p.pos, "Remaking it", Kit.CHEESE)
			dirty = true
			return
		"refund":
			r.refunds += v.paid
			v.paid = 0.0
			v.tip = 0.0
			v.stars = max(v.stars + 1.2, 2.8)
		"drink":
			var cost: float = 2.5 * v.n
			Game.s.cash -= cost
			r.comps += cost
			v.stars = min(v.stars + 0.7, 3.8)
			v.tip = 0.0
		"sorry":
			v.stars += 0.25
			v.tip = 0.0
		"ignored":
			v.stars = 1.0
			v.tip = 0.0
	_apply(p, v)
	_depart(p)

## a complaint at the hatch or the table: you decide what to do
func complaint_dialog(p: Dictionary) -> void:
	if Kit.main.modal_root.visible: return
	var v: Dictionary = p.verdict
	var who: String = (p.reg + ", one of your regulars,") if p.has("reg") else "A customer"
	var what: String = ", ".join(p.items.map(func(it): return it.rec.name))
	var box := Kit.vbox(10)
	box.add_child(Kit.label("Complaint", 26))
	box.add_child(Kit.label("%s is not happy with their %s.\n\"%s\"" % [who, what, (v.notes[0] if v.notes.size() > 0 else "It just was not very good") + "."], 19, Kit.INK, true))
	var h := Kit.hbox(8)
	var opts := [["remake", "Remake it"]]
	if v.paid > 0: opts.append(["refund", "Refund %s" % Kit.cents(v.paid)])
	opts.append_array([["drink", "Free drink (%s)" % Kit.cents(2.5 * v.n)], ["sorry", "Apologise"]])
	pop.visible = false
	pop_t = 0.0
	for o in opts:
		h.add_child(Kit.button(o[1], func():
			Kit.main.close_modal()
			if p.state == "complain": _resolve(p, v, o[0]), "primary" if o[0] == "remake" else "ghost", 17))
	box.add_child(h)
	box.add_child(Kit.label("Remaking costs you the ingredients and time but saves the review. A refund or a drink calms them down. An apology alone rarely does.", 14, Kit.MUTED, true))
	Kit.main.modal(box, 760)

## paying cash: count out the right change
func _cash(p: Dictionary, v: Dictionary) -> void:
	var bill: float = snapped(v.paid + v.drinks + v.deliv, 0.1)
	var tendered := 5.0
	for note in [5.0, 10.0, 20.0, 50.0]:
		tendered = note
		if note >= bill: break
	if randf() < 0.25 and tendered < 50.0: tendered *= 2.0
	var due: float = snapped(tendered - bill, 0.1)
	pop.visible = false
	pop_t = 0.0
	var given := [0.0]
	var box := Kit.vbox(10)
	box.add_child(Kit.label("Cash", 26))
	box.add_child(Kit.label("The bill is %s. They hand you a %s note." % [Kit.cents(bill), Kit.money(tendered)], 20, Kit.INK, true))
	var gl := Kit.label("Change counted out: $0.00", 22, Kit.CHEESE)
	box.add_child(gl)
	var g := Kit.grid(4, 8)
	for coin in [10.0, 5.0, 2.0, 1.0, 0.5, 0.2, 0.1]:
		g.add_child(Kit.button(Kit.cents(coin) if coin < 1 else Kit.money(coin), func():
			given[0] = snapped(given[0] + coin, 0.01)
			gl.text = "Change counted out: %s" % Kit.cents(given[0]), "ghost", 18))
	g.add_child(Kit.button("Start again", func():
		given[0] = 0.0
		gl.text = "Change counted out: $0.00", "ghost", 16))
	box.add_child(g)
	box.add_child(Kit.button("Hand it over", func():
		Kit.main.close_modal()
		var diff: float = snapped(given[0] - due, 0.01)
		if abs(diff) < 0.05:
			v.stars += 0.1
		elif diff > 0:
			Game.s.cash -= diff
			r.change_err += diff
			Kit.main.toast("You gave %s too much change" % Kit.cents(diff), true)
		else:
			v.stars -= 0.3
			Kit.main.toast("\"That's %s short.\" You hand over the rest." % Kit.cents(-diff), true)
		if p.state == "paying":
			_apply(p, v)
			_depart(p)))
	Kit.main.modal(box, 640)

# ---------- regulars ----------
func _regular(name: String):
	for rg in Game.s.regulars:
		if rg.name == name: return rg
	return null

## sometimes one of your regulars walks in
func _pick_regular():
	var regs: Array = Game.s.regulars.filter(func(rg): return int(rg.last) != Game.s.day and rg.mood >= 0.3)
	if regs.is_empty() or randf() > min(0.3, 0.05 * regs.size()): return null
	var rg = regs.pick_random()
	rg.last = Game.s.day
	return rg

## how a visit went changes a regular's mood; great visits make new regulars
func _regular_after(p: Dictionary, stars: float) -> void:
	var G := Game
	if p.has("reg"):
		var rg = _regular(p.reg)
		if rg == null: return
		rg.visits += 1
		rg.mood = clamp(rg.mood + (stars - 3.6) * 0.15, 0.0, 1.0)
		r.regulars.append("%s %.1f" % [rg.name, stars])
		if rg.mood < 0.2:
			G.s.regulars.erase(rg)
			r.notes.append("%s, a regular for %d visits, has had enough and stopped coming." % [rg.name, rg.visits])
		return
	if stars >= 4.4 and randf() < 0.12 and G.s.regulars.size() < 6 + G.s.venue * 4 and p.items.size() > 0 and not p.get("critic", false):
		var it: Dictionary = p.items[0]
		var rg := {"name": Data.NAMES.pick_random(), "fav": it.rec.id, "mods": it.rec.get("mods", []), "mood": 0.7, "visits": 1,
			"type": p.type if p.type != "deliv" else "take", "look": p.look, "last": G.s.day}
		G.s.regulars.append(rg)
		r.notes.append("%s loved their %s and says they will be back." % [rg.name, it.rec.name])

# ---------- the phone ----------
## accept the order pinging on the delivery-app tablet: the tickets print and a rider is booked for prep_mins from now
func accept_app() -> void:
	if tablet.is_empty(): return
	var o: Dictionary = tablet.pop_front()
	pid += 1
	var p := {"id": pid, "type": "deliv", "app": true, "n": o.n, "pos": Vector2(-100, -100), "target": Vector2(-100, -100), "state": "", "pat": 0.0, "max": 0.0, "tks": [], "got": 0, "items": [],
		"waits": [], "table": -1, "timer": 0.0, "gone": false, "look": randi() % 6, "hue": randf(), "nobox": false, "want_x": 0, "got_x": 0, "xitems": [], "drinks": []}
	parties.append(p)
	if not order(p):
		_app_rate(-0.05)
		return
	p.state = "app"
	p.collect_t = t + float(Data.APP.prep_secs)
	p.collect_at = c.open + p.collect_t * gm         # the time on the clock the rider is booked for
	Game.s.app.orders = int(Game.s.app.get("orders", 0)) + 1
	r.app_orders = r.get("app_orders", 0) + 1
	dirty = true

## pizzas waiting to be started per pair of hands in the kitchen
func kitchen_load() -> float:
	var waiting := tickets.filter(func(tk): return tk.state == "new" and tk.owner == "" and tk.rec.get("make", "pizza") in ["pizza", "oven"]).size()
	return float(waiting) / float(workers.size() + 1)

## the app's rating of you moves
func _app_rate(by: float) -> void:
	Game.s.app.rating = clamp(float(Game.s.app.rating) + by, 1.0, 5.0)

func answer_phone() -> void:
	if phones.is_empty() or not is_free(): return
	var ph: Dictionary = phones.pop_front()
	start_busy("On the phone taking an order", 1.0, func(frac): _phone_order(ph))

## an order taken over the phone: they come to collect it in about 20 minutes
func _phone_order(ph: Dictionary) -> void:
	pid += 1
	var p := {"id": pid, "type": "take", "n": ph.n, "pos": Vector2(-100, -100), "target": Vector2(-100, -100), "state": "", "pat": 0.0, "max": 0.0, "tks": [], "got": 0, "items": [],
		"waits": [], "table": -1, "timer": 0.0, "gone": false, "look": randi() % 6, "hue": randf(), "nobox": false, "phone": true, "want_x": 0, "got_x": 0, "xitems": [], "drinks": []}
	parties.append(p)
	if not order(p): return
	waiters.erase(p)
	p.state = "phone"
	p.arrive = minute() + 20.0
	dirty = true

func _review_text(cats: Dictionary, notes: Array) -> String:
	var worst := "look"
	var best := "look"
	for k in cats:
		if cats[k] < cats[worst]: worst = k
		if cats[k] > cats[best]: best = k
	if cats[worst] < 3.3:
		if notes.size() > 0 and (worst == "look" or worst == "taste"): return notes[0] + "."
		return {"look": "It looked a mess when I opened the box.", "taste": "Did not taste of much.", "service": "Waited far too long.", "value": "Not worth the money."}[worst]
	if cats[best] >= 4.4:
		return {"look": "Almost too pretty to eat.", "taste": "Best pizza I have had in ages.", "service": "Quick, friendly, no fuss.", "value": "Great value for what you get."}[best]
	return (notes[0] + ", but decent.") if notes.size() > 0 else "Solid pizza."

## a pizza that was made (or part-made) and will never be sold
func _waste_tk(tk: Dictionary) -> void:
	if tk.has("res"): Stock.log_binned(tk.res.use, tk.res.cost)
	elif tk.has("made"): Stock.log_binned(tk.made.use, tk.made.cost)

func _waste_pizza(pz: Pizza) -> void:
	var use: Dictionary = pz.grams.duplicate()
	use["dough:" + pz.rec.base] = 1.0
	Stock.log_binned(use, pz.cost)

func expire(p: Dictionary, why: String = "Gave up waiting") -> void:
	var G := Game
	if p.state == "complain":
		_resolve(p, p.verdict, "ignored")
		return
	if p.state == "bill":
		settle(p, true)
		_depart(p)
		return
	r.lost += p.n - p.got
	r.gave_up += p.n - p.got
	G.s.rep += (1.5 - G.s.rep) * max(0.02, 1.0 / (G.s.ratings + 6)) * 0.35
	for tk in p.tks:
		if tk.state == "done": continue
		tk.gone = true
		tickets.erase(tk)
		_waste_tk(tk)
		spike(tk, why.to_upper() if why != "Gave up waiting" else "WALKED OUT", 7.0)
	for w in workers:
		if w.job != null and w.job.gone: w.job = null
	oven.items = oven.items.filter(func(o): return not (o.owner == "staff" and o.tk.gone))
	var tb = tables[p.table] if p.table >= 0 else null
	float_text(p.pos, why, Kit.TOMATO)
	if p.got > 0: settle(p, true, false, true)
	leave(p)
	if tb != null and p.got > 0: tb.dirty = true
	Art.sfx("bad")
	Art.buzz(90)
	dirty = true

func float_text(pos: Vector2, text: String, col: Color) -> void:
	if pos.x < 0: pos = L.win
	floats.append({"pos": pos, "text": text, "col": col, "t": 2.2})

## everything out front that you (or the staff) can act on right now
func actionables() -> Array:
	var out := []
	if queue.size() > 0 and queue[0].pos.distance_to(q_pos(0)) < 6: out.append({"kind": "order", "p": queue[0], "pos": queue[0].pos})
	for p in waiters:
		if ready_tks(p).size() > 0: out.append({"kind": "food", "p": p, "pos": p.pos})
	if door.size() > 0 and free_table() != null and places_free(int(door[0].n)) and door[0].pos.distance_to(d_pos(0)) < 6: out.append({"kind": "seat", "p": door[0], "pos": door[0].pos})
	for p in parties:
		if p.state == "complain": out.append({"kind": "complaint", "p": p, "pos": tables[p.table].pos if p.table >= 0 else p.pos})
		if p.state == "rider":
			var left: Array = p.tks.filter(func(tk): return tk.state != "done")
			if left.size() > 0 and left.all(func(tk): return tk.state == "pass"): out.append({"kind": "rider", "p": p, "pos": p.pos})
	for tb in tables:
		var p = tb.party
		if p == null:
			if tb.dirty: out.append({"kind": "clear", "tb": tb, "pos": tb.pos})
		elif p.state == "ask": out.append({"kind": "order", "p": p, "pos": tb.pos})
		elif p.state == "wait" and ready_tks(p).size() > 0: out.append({"kind": "food", "p": p, "pos": tb.pos})
		elif p.state == "bill": out.append({"kind": "bill", "p": p, "pos": tb.pos})
	return out

func do_action(a: Dictionary, by_player: bool) -> void:
	match a.kind:
		"order":
			if order(a.p) and by_player: r.xp += 1
		"food", "rider": act_handover(a.p, by_player)
		"seat": act_seat(a.p)
		"bill": act_bill(a.p, by_player)
		"complaint":
			if by_player: complaint_dialog(a.p)
		"clear": a.tb.dirty = false

func tap_scene(pos: Vector2) -> void:
	if L.back.distance_to(pos + Vector2(0, 14)) < 50 and Game.s.dock.size() > 0:
		set_view("prep")
		return
	if not is_free(): return
	var best = null
	for a in actionables():
		var dd: float = a.pos.distance_to(pos + Vector2(0, 14))
		if dd < 60 and (best == null or dd < best.pos.distance_to(pos + Vector2(0, 14))): best = a
	if best != null:
		do_action(best, true)
		Art.sfx("tap")

# ---------- simulation ----------
func _process(delta: float) -> void:
	if done: return
	var real: float = min(delta, 0.1)
	for i in speed:
		if not done: step(real)
	if done: return
	if pop_t > 0:
		pop_t -= real
		if pop_t <= 0: pop.visible = false
	_refresh()
	if fp_mode: return                    # the 3D world redraws its surfaces itself
	if view == "front": front.queue_redraw()
	elif view == "oven": oven_ui.queue_redraw()
	else:
		bench_ui.queue_redraw()
		rail_ui.queue_redraw()

func step(dt: float) -> void:
	var G := Game
	t += dt
	var now := minute()
	if not busy.is_empty():
		busy.left -= dt
		if busy.left <= 0:
			var fn: Callable = busy.fn
			busy = {}
			fn.call(1.0)
			dirty = true
	# deliveries turning up at the back door
	if Day.next_arrival() >= 0 and Day.next_arrival() <= now:
		for nt in Day.arrivals(now): r.notes.append(nt)
		Kit.main.toast("A delivery is at the back door")
		Art.sfx("knock")
		dirty = true
	_crew_step(dt)
	# the inspector
	var at: float = G.s.hygiene.get("at", -1.0)
	if at >= 0 and at <= now and not done and not training:
		r.inspect = Hygiene.inspect()
		var res: Dictionary = r.inspect
		Kit.main.message("Food hygiene inspection", "The inspector called in at %s and rated you %s.%s" % [Data.hhmm(now), Hygiene.rating_text(), ("\n\n" + "\n".join(res.notes)) if res.notes.size() > 0 else "\n\nNo problems found."] + ("\n\nYou are closed until you sort it out." if res.closed else ""), "OK")
		if res.closed:
			r.closed = true
			finish(false)
			return
	# mice
	if mouse.is_empty() and not training and randf() < Hygiene.sighting_rate() * gm * dt:
		_mouse()
	if not mouse.is_empty():
		mouse.t -= dt
		mouse.pos += mouse.vel * dt
		if mouse.t <= 0: mouse = {}
	if t < DAY * 0.94 and not training:
		acc += c.total / DAY * (0.55 + 0.9 * sin(PI * t / DAY)) / 1.123 / 0.94 * dt
		while acc >= 1.0: acc -= spawn_party()
	if t < DAY * 0.9 and c.app > 0 and not Game.s.app.paused and not training:
		app_acc += c.app / 1.6 / DAY * (0.4 + 1.0 * sin(PI * t / DAY)) / 1.04 / 0.9 * dt
		while app_acc >= 1.0:
			app_acc -= 1.0
			tablet.append({"n": [1, 1, 2, 2, 3].pick_random(), "until": t + float(Data.APP.accept_secs)})
			Art.sfx("app")
			dirty = true
	for o in tablet.duplicate():
		if t > o.until:
			tablet.erase(o)
			r.app_missed = r.get("app_missed", 0) + 1
			_app_rate(-0.05)
			dirty = true
	# customers
	for i in queue.size(): queue[i].target = q_pos(i)
	for i in waiters.size(): waiters[i].target = w_pos(i)
	for i in door.size(): door[i].target = d_pos(i)
	for p in parties.duplicate():
		if p.table >= 0: p.target = tables[p.table].pos
		elif p.state == "leave": p.target = L.spawn
		p.pos = p.pos.move_toward(p.target, 170 * dt)
		match p.state:
			"leave":
				if p.pos.distance_to(L.spawn) < 4: parties.erase(p)
			"sit":
				if p.pos.distance_to(p.target) < 4:
					p.timer -= dt
					if p.timer <= 0: p.state = "ask"
			"eat":
				p.timer -= dt
				if p.timer <= 0:
					if not p.get("dessert_asked", false):
						p.dessert_asked = true
						if _order_desserts(p) > 0:
							p.state = "wait"
							set_pat(p, 90)
							Art.sfx("ding")
							dirty = true
					if p.state == "eat":
						p.state = "bill"
						set_pat(p, 60)
			"app":
				if t >= float(p.collect_t):     # the rider turns up
					p.state = "rider"
					p.pos = L.win + (Vector2(60, 10) if L.dine else Vector2(10, 95))      # by the counter, or on the pavement under the hatch
					p.target = p.pos
					set_pat(p, float(Data.APP.rider_secs) / c.patience)
					dirty = true
			"rider":
				p.pat -= dt
				if p.pat <= 0:
					_app_rate(-0.2)
					r.app_cancel = r.get("app_cancel", 0) + 1
					expire(p, "The rider left without it")
			"queue", "door", "ask", "wait", "bill", "complain":
				p.pat -= dt
				if p.pat <= 0: expire(p)
			"phone":
				if minute() >= p.arrive:
					p.state = "wait"
					p.pos = L.spawn
					waiters.append(p)
					set_pat(p, 50)
	for ph in phones.duplicate():
		if t > ph.until:
			phones.erase(ph)
			r.lost += ph.n
			r.missed += 1
			dirty = true
	for f in floats.duplicate():
		f.t -= dt
		f.pos.y -= 16 * dt
		if f.t <= 0: floats.erase(f)
	# front-of-house staff
	for w in foh:
		w.cd -= dt
		if w.cd > 0: continue
		if phones.size() > 0 and w.role in ["cashier", "host"]:
			_phone_order(phones.pop_front())
			w.cd = 3.0
			continue
		if tablet.size() > 0 and w.role in ["cashier", "host"] and kitchen_load() < 2.5:      # not when the kitchen is swamped
			accept_app()
			w.cd = 1.5
			continue
		if w.role in ["cashier", "server", "host", "driver"]:
			var rd: Array = actionables().filter(func(a): return a.kind == "rider")
			if rd.size() > 0:
				do_action(rd[0], false)
				w.cd = 1.5
				continue
		if w.role in ["bartender", "server", "cashier"]:
			var bt = _bar_ticket()
			if bt != null and extra_can(bt.rec, {}):
				bt.owner = w.s.name
				to_pass(bt, _plate(bt, w.s.skill, false))
				w.cd = secs(float(bt.rec.mins)) * (1.2 - 0.08 * w.s.skill)
				continue
		var acts := actionables()
		var want := []
		match w.role:
			"cashier": want = acts.filter(func(a): return a.has("p") and a.p.type == "take" and a.kind in ["order", "food"])
			"server":
				for kind in ["food", "order", "bill", "seat", "clear"]:
					want = acts.filter(func(a): return a.kind == kind and a.kind != "complaint" and not (a.has("p") and a.p.type == "take"))
					if want.size() > 0: break
			"host": want = acts.filter(func(a): return a.kind == "seat")
			"porter": want = acts.filter(func(a): return a.kind == "clear")
			"driver":
				for p in parties:
					if p.type == "deliv" and not p.get("app", false) and p.state == "wait" and ready_tks(p).size() > 0:
						act_handover(p)
						w.cd = 1.5
						break
		if want.size() > 0:
			do_action(want[0], false)
			w.cd = {"cashier": 2.6, "server": 3.2, "host": 1.6, "porter": 4.0, "driver": 1.5}[w.role] - 0.32 * w.s.skill
		elif w.role == "cashier" and Stock.folded() < 8 and Stock.fold(1) > 0:     # a quiet moment at the counter: fold a box
			w.cd = secs(Stock.FOLD_MIN) * 1.2
	# pizzaioli
	for tk in tickets: tk.age += dt
	for w in workers:
		if w.job != null:
			w.left -= dt
			var slot := oven.free_slot()
			if w.left <= 0 and w.job.rec.get("make", "") == "cold":
				to_pass(w.job, _plate(w.job, w.s.skill, false))
				w.job = null
			elif w.left <= 0 and slot >= 0:
				oven.load_staff(w.job, slot)
				w.job.state = "oven"
				w.job = null
		if w.get("prep", "") != "":
			w.left -= dt
			if w.left <= 0:
				line_job_done(w.prep, w.raw, 0.6 + 0.08 * w.s.skill)
				w.prep = ""
				dirty = true
			continue
		if w.job == null and not training:
			for tk in _by_due():
				if tk.state != "new" or tk.owner != "" or tk.age <= (40.0 if w.get("backup", false) else 1.2): continue
				var mk: String = tk.rec.get("make", "pizza")
				if mk == "bar": continue          # drinks are made out front
				if mk == "cold":
					if not extra_can(tk.rec, {}): continue
					tk.owner = w.s.name
					tk.state = "make"
					w.job = tk
					w.left = secs(float(tk.rec.mins)) * (1.2 - 0.08 * w.s.skill)
					dirty = true
					break
				if G.can_make(tk.rec) and tin_free(tk.rec.base):
					tk.made = staff_make(w.s, tk.rec)
					tk.owner = w.s.name
					tk.state = "make"
					w.job = tk
					w.left = 10.0 * (1.25 - 0.1 * w.s.skill) / c.prep_speed + tk.made.get("extra", 0.0) + 3.0 * (1.0 - Equip.peel_share())   # waiting for a peel
					w.ladle = tk.made.get("ladle", 0)
					w.ladle_free = w.left * 0.75
					dirty = true
					break
				# a pan has run out: refill it from the tubs, or (with no prep cook on) prep more
				var short: Array = G.line_short(tk.rec).filter(func(i): return not prepping.has(i))
				if short.size() > 0:
					var id: String = short[0]
					var job := line_job(id, G.staff_of("prep").is_empty(), Day.prep_mult() * (1.25 - 0.08 * w.s.skill))
					if job.is_empty(): continue
					w.prep = id
					w.raw = job.raw
					w.left = secs(job.minutes)
					prepping[id] = w.s.name
					dirty = true
					break
	# oven
	for o in oven.step(dt, c.bake / oven.bake_time): to_pass(o.tk, staff_result(o.tk))
	if c.fornaio or helps.has("oven"):
		for o in oven.mine():
			if o.pz.bake_avg() >= o.pz.bake_target: oven_pull(o, helps.has("oven"))
	if helps.has("board") and board.size() > 0:
		marco_board_t += dt
		if marco_board_t >= 2.5:
			marco_board_t = 0.0
			_marco_finishes(board[0])
			serve(true)
	else: marco_board_t = 0.0
	# the oven tender keeps the fire just right; without one, a pizzaiolo throws a log on when it gets low
	if oven.def.feeds and (oven.power_soon() < 0.85 if c.fornaio else (oven.power_soon() < 0.55 and workers.size() > 0)):
		var lg := Stock.take("wood", 1.0)
		if lg.got >= 1.0: oven.add_log(lg.g)
	# end of day
	var idle: bool = tickets.is_empty() and bench == null and board.is_empty() and oven.items.is_empty() and oven.shelf.is_empty()
	var anyone := parties.any(func(p): return p.state != "leave")
	if training: return                 # the training day ends when Marco says so
	if idle and not anyone and t >= DAY: finish(false)
	elif tickets.is_empty() and not anyone and t >= DAY + 20.0 and busy.is_empty(): finish(false)     # only pizzas nobody is waiting for are left: they are binned
	elif idle and t > 5 and not anyone and busy.is_empty() and not G.active_recipes().any(func(rc): return sellable(rc)): finish(true)

## how a pizzaiolo gets the sauce on: {g grams, secs extra time, oz ladle held (0 = none)}.
## The right ladle if one is free; otherwise a smaller one more than once (slower), a bigger one (too much), or a spoon.
func _staff_sauce(want_g: float) -> Dictionary:
	var want := int(round(want_g / Data.OZ_G))
	var busy_with := {}
	for w in workers:
		if w.job != null and w.get("ladle", 0) > 0 and w.left > w.get("ladle_free", 0.0): busy_with[w.ladle] = busy_with.get(w.ladle, 0) + 1
	if bench != null and tool != "" and Data.ING[tool].kind == "sauce": busy_with[ladle_oz] = busy_with.get(ladle_oz, 0) + 1
	var free := func(oz: int) -> bool: return Game.ladles(oz) - int(busy_with.get(oz, 0)) > 0
	if free.call(want): return {"g": want_g, "secs": 0.0, "oz": want}
	for oz in [3, 2, 1]:
		if oz < want and free.call(oz) and want % oz == 0: return {"g": want_g, "secs": 1.5 * (want / oz - 1), "oz": oz}
	for oz in Data.LADLES:
		if oz > want and free.call(oz): return {"g": oz * Data.OZ_G, "secs": 0.0, "oz": oz}
	if Game.ladles(want) > 0: return {"g": want_g, "secs": 2.0, "oz": 0}     # waited for a colleague's ladle
	return {"g": want_g * randf_range(0.75, 1.35), "secs": 3.0, "oz": 0}

## a pizzaiolo takes the dough and weighs out the toppings. Less skilled cooks are heavier-handed.
func staff_make(x: Dictionary, rec: Dictionary) -> Dictionary:
	var dq := Stock.take_dough(rec.base)
	var over: float = max(0.0, 0.16 - 0.03 * x.skill - c.chef * 0.004) + randf_range(-0.02, 0.03)
	var spec: Dictionary = rec.spec.duplicate()
	var ignored := false
	var slip: float = max(0.02, 0.14 - 0.03 * x.skill)
	if rec.get("allergy", "") != "" and Equip.allergen_kit(): slip *= 0.25      # made on the purple board with the purple knife
	if rec.get("mods", []).size() > 0 and randf() < slip:
		spec = Data.REC[rec.id].spec.duplicate()
		ignored = true
	var m := {"skill": x.skill, "dough_q": dq.q, "use": {"dough:" + rec.base: 1.0}, "spec": rec.spec.duplicate(), "cost": dq.cost, "spec_cost": dq.cost, "short": 0,
		"ignored": ignored, "allergy": ignored and rec.get("allergy", "") != ""}
	m.spec["dough:" + rec.base] = 1.0
	var gw: float = Data.DOUGHS[rec.base].ball * 0.4
	var gsum: float = dq.g * gw
	m.extra = 0.0
	if rec.sauce != "" and spec.has(rec.sauce):
		var sauce := _staff_sauce(spec[rec.sauce])
		spec[rec.sauce] = sauce.g
		m.extra = sauce.secs
		m.ladle = sauce.oz
	for id in spec:
		var got := Stock.take_use(id, spec[id] * (1.0 + (0.0 if Data.ING[id].kind == "sauce" else over)))
		m.use[id] = got.got
		m.cost += got.cost
		m.spec_cost += spec[id] * (got.cost / got.got if got.got > 0 else 0.0)
		gsum += got.g * got.got
		gw += got.got
		if got.got < spec[id] * 0.85: m.short += 1
	m.grade = gsum / gw
	return m

func staff_result(tk: Dictionary) -> Dictionary:
	var m: Dictionary = tk.made
	var a := {"mine": false, "notes": [], "grade": m.grade, "cost": m.cost, "spec_cost": m.spec_cost, "use": m.use, "spec": m.spec}
	a.look = clamp(46.0 + m.skill * 8.0 + c.chef * 0.6 + c.prep_q + randf_range(-7, 7), 15.0, 97.0)
	a.taste = clamp(44.0 + m.skill * 8.0 + c.chef + c.oven_q * 0.5 + c.prep_q + (m.dough_q - 60.0) * 0.15 - m.short * 12.0 + randf_range(-5, 5), 15.0, 98.0)
	if m.short > 0: a.notes.append("Something was missing from it")
	if m.ignored:
		a.notes.push_front("They ignored what I asked for")
		a.taste -= 25.0
	if m.allergy:
		a.allergy = true
		a.notes.push_front("ALLERGY: it had %s on it" % Data.ING[tk.rec.allergy].name.to_lower())
	Equip.adjust(a, tk.rec, true)
	return a

func to_pass(tk: Dictionary, res: Dictionary) -> void:
	dirty = true
	Hygiene.dirty("boh", 45.0 / max(10.0, float(c.total)))
	if tk.gone:
		Stock.log_binned(res.use, res.cost)
		return
	tk.state = "pass"
	tk.res = res
	var mk: String = tk.rec.get("make", "pizza")
	if tk.p.type != "dine" and (mk == "pizza" or mk == "oven"): _box(tk, res)
	r.xp += (10.0 + (res.look + res.taste) / 16.0) if res.mine else 4.0
	if tk.get("x", false):
		r.extras = r.get("extras", 0) + 1
		return
	if res.mine:
		r.mine += 1
		r.mine_q = r.get("mine_q", 0.0) + (res.look + res.taste) / 2.0
		r.mine_cost = r.get("mine_cost", 0.0) + res.cost
		r.mine_spec = r.get("mine_spec", 0.0) + res.spec_cost

## a takeaway goes into a box at the pass. With none folded, one is folded on the spot while the customer waits
## (and if it is your pizza, you are the one folding it).
func _box(tk: Dictionary, res: Dictionary) -> void:
	var bx := Stock.box_one()
	if not bx.ok:
		tk.p.nobox = true
		return
	res.cost += bx.cost
	res.spec_cost += bx.cost
	res.use["box"] = 1.0
	res.spec["box"] = 1.0
	if bx.folded_now:
		r.folded_live = r.get("folded_live", 0) + 1
		tk.p.fold_wait = int(tk.p.get("fold_wait", 0)) + 1
		if res.mine and busy.is_empty(): start_busy("No boxes folded: folding one", Stock.FOLD_MIN, func(_frac): pass)

## you fold boxes during service (from the Prep tab)
func fold_now(n: int) -> void:
	if not is_free(): return
	n = int(min(n, Stock.have("box")))
	if n <= 0:
		Kit.main.toast("No flat boxes left", true)
		return
	start_busy("Folding %d boxes" % n, Stock.FOLD_MIN * n, func(frac): Stock.fold(int(round(n * frac))))

## deep-pan bases go in a tin from the bench until they come out of the oven: is one free?
func tin_free(style: String) -> bool:
	if not Equip.needs_tin(style): return true
	var used := 0
	var pzs: Array = board.duplicate()
	pzs.append_array(oven.shelf)
	if bench != null: pzs.append(bench)
	for pz in pzs:
		if Equip.needs_tin(pz.rec.base): used += 1
	for o in oven.items:
		if Equip.needs_tin(o.pz.rec.base if o.owner == "me" else o.tk.rec.base): used += 1
	for w in workers:
		if w.job != null and w.job.rec.has("base") and Equip.needs_tin(w.job.rec.base): used += 1
	return used < Equip.count("pan_tin")

# ---------- your bench ----------
func claim(tk: Dictionary) -> void:
	if tk.state != "new" or tk.owner != "": return
	if not is_free(): return
	if tk.rec.get("make", "") in ["cold", "bar"]:
		make_quick(tk)
		return
	if bench != null and _carry_to_oven(true) == null: return       # the one on the bench goes to the oven first
	carried = null
	if not tin_free(tk.rec.base):
		Kit.main.toast("Every pizza tin is in use. Buy more tins from %s." % Equip.SHOP.name if Equip.has("pan_tin") else "Deep pan needs a pizza tin. Order some from %s." % Equip.SHOP.name, true)
		return
	var dq := Stock.take_dough(tk.rec.base)
	if dq.is_empty():
		Kit.main.toast("No %s dough balls left" % Data.DOUGHS[tk.rec.base].name, true)
		return
	tk.owner = "me"
	tk.state = "make"
	ladle_g = 0.0
	bench = Pizza.new(tk, dq)
	if helps.has("stretch"): _marco_stretches(bench)
	if bench.rec.sauce != "":
		var lo := Game.ladle_for(bench.rec.spec[bench.rec.sauce])
		if lo > 0: ladle_oz = lo
	tool = ""
	set_view("bench")
	Art.sfx("ticket", true)
	Art.buzz(12)

func _first_tool(pz: Pizza) -> String:
	for id in [pz.rec.sauce, pz.rec.cheese] + pz.rec.tops:
		if id != "" and not Data.ING[id].after and Stock.have(id) > 0: return id
	return ""

## the classic layout's one button: on the board it sends the pizza to the pass; on the bench it takes the pizza to
## the oven. (In 3D there is no button: you tap the pass, and you turn to the oven.)
func next() -> void:
	if not is_free(): return
	if view == "board":
		serve()
		return
	if bench == null: return
	if _carry_to_oven(true) != null and not c.fornaio: set_view("oven")

## the pizza on the bench goes to the oven: onto the shelf by the mouth (or straight in, if an oven tender is
## loading for you). Returns the pizza, or null if there was no room.
func _carry_to_oven(say: bool) -> Pizza:
	if bench == null: return null
	_drop_ladle(bench)
	var pz: Pizza = bench
	if helps.has("top"): _marco_tops(pz)
	if c.fornaio or helps.has("oven"):
		var slot := oven.free_slot()
		if slot < 0:
			if say: Kit.main.toast("The oven is full", true)
			return null
		oven.load_pizza(pz, slot, true)
		pz.tk.state = "oven"
		if helps.has("oven"): Kit.main.toast("%s takes it: %s" % [Story.BOSS, "he tops it and bakes it" if helps.has("top") else "he bakes it and sends it"])
	else:
		if oven.shelf.size() >= Oven.SHELF:
			if say: Kit.main.toast("The shelf by the oven is full. Put those pizzas in first", true)
			return null
		pz.stage = "shelf"
		oven.shelf.append(pz)
	bench = null
	tool = ""
	dirty = true
	Art.sfx("peel", true)
	return pz

# ---------- Marco's part of your pizzas (the first days of the story) ----------
## he stretches the base out to the ring, with an even rim
func _marco_stretches(pz: Pizza) -> void:
	var b := pz.base
	for j in PizzaBase.NS:
		b.r[j] = b.R * randf_range(0.97, 1.03)
		b.rim[j] = b.crust * randf_range(0.9, 1.1)
	pz.inside_n = -1
	pz.stage = "top"

## he tops it to the recipe card (adding only what is not on it yet): the sauce spread to the rim, the cheese
## scattered, the toppings laid out evenly
func _marco_tops(pz: Pizza) -> void:
	var reach: float = max(20.0, pz.base.mean_r() - pz.base.mean_rim())
	for ing in [pz.rec.sauce, pz.rec.cheese]:
		if ing == "" or not pz.rec.spec.has(ing): continue
		var k := 0
		while pz.grams.get(ing, 0.0) < pz.spec_of(ing) * 0.97 and k < 400:
			var p := Vector2.from_angle(k * 0.62) * fmod(k * 2.6, reach * 0.92)
			if not pz.spread(ing, p, 14.0, 17.0): break
			k += 1
	_marco_lays(pz, false)

## the pieces on top (before the oven, or the ones that go on after it)
func _marco_lays(pz: Pizza, after: bool) -> void:
	var reach: float = max(20.0, pz.base.mean_r() - pz.base.mean_rim())
	for ing in pz.rec.tops:
		if ing == "" or bool(Data.ING[ing].after) != after: continue
		var k := 0
		while pz.grams.get(ing, 0.0) < pz.spec_of(ing) * 0.95 and k < 60:
			var p := Vector2.from_angle(k * 2.39996) * reach * 0.82 * sqrt(fmod(k * 0.137 + 0.08, 1.0))
			var res := pz.add_top(ing, p, after)
			if res == "out" or res == "full": break
			k += 1

## off the oven: anything that goes on after baking, three cuts through the middle, onto the pass
func _marco_finishes(pz: Pizza) -> void:
	_marco_lays(pz, true)
	var R: float = pz.base.mean_r() * 1.1
	while pz.cuts.size() < 3:
		var a := pz.cuts.size() * PI / 3.0 + 0.2
		pz.cuts.append({"a": Vector2.from_angle(a) * -R, "b": Vector2.from_angle(a) * R, "d": 0.0})

func bin() -> void:
	var pz: Pizza = (board.pop_front() if board.size() > 0 else null) if view == "board" else bench
	if pz == null: return
	if view != "board": bench = null
	_waste_pizza(pz)
	if not pz.tk.gone:
		pz.tk.owner = ""
		pz.tk.state = "new"
	if view == "board" and board.is_empty(): view = "bench"
	tool = ""
	dirty = true

## a pizza left on the shelf by the oven while you start the next one is not coming back to the bench
func _forget_carried() -> void:
	carried = null

func sheeter() -> void:
	if bench == null or bench.stage != "shape" or bench.base.method != "roll" or c.roll_auto <= 0: return
	bench.base.sheet(c.roll_auto)

## your hand with whatever is in it, at p on the pizza (prev = where it was a moment ago, or null for a tap)
func apply_tool(p: Vector2, prev) -> void:
	if not busy.is_empty(): return
	var on_board: bool = view == "board"
	var pz: Pizza = (board[0] if board.size() > 0 else null) if on_board else bench
	if pz == null or tool == "": return
	var it: Dictionary = Data.ING[tool]
	if it.kind == "top":
		if pz.add_top(tool, p, on_board) == "out": _ran_out()
		else: Art.sfx("sprinkle", true, 0.12)
		return
	var g0: float = pz.grams.get(tool, 0.0)
	_apply_spread(pz, it, p, prev)
	if it.kind != "sauce" and pz.grams.get(tool, 0.0) > g0: Art.sfx("sprinkle", true, 0.25)      # cheese scattered on
	if on_board: pz.late[tool] = pz.late.get(tool, 0.0) + pz.grams.get(tool, 0.0) - g0      # sauce or cheese after the oven

## sauce from the ladle or cheese by hand, spread where your finger goes
func _apply_spread(pz: Pizza, it: Dictionary, p: Vector2, prev) -> void:
	var brush: float = 17.0 + c.brush
	if it.kind == "sauce":
		if ladle_g > 0.0:
			pz.drop_sauce(ladle_ing, ladle_g, p)
			ladle_g = 0.0
			dirty = true
			Art.sfx("plop", true)
			return
		if prev == null:
			if pz.sauce == "": Kit.main.toast("Pick a ladle and scoop the sauce first")
			return
		var a: Vector2 = prev
		var n: int = max(1, int(ceil(a.distance_to(p) / (brush * 0.4))))
		for i in n:
			var q: Vector2 = a.lerp(p, float(i + 1) / n)
			pz.smear(q, a.lerp(p, float(i) / n), brush)
		return
	var from: Vector2 = p if prev == null else prev
	var dist := from.distance_to(p)
	var steps: int = max(1, int(ceil(dist / (brush * 0.6))))
	for i in steps:
		if not pz.spread(tool, from.lerp(p, float(i + 1) / steps), (dist / steps) if prev != null else brush, brush):
			_ran_out()
			break

## take one ladle of sauce out of its pan on the rail: exactly the ladle's size, no more
## the pizza in front of you: the one on the bench, or the one on the board when you are at the board
func _target() -> Pizza:
	return (board[0] if board.size() > 0 else null) if view == "board" else bench

func scoop() -> void:
	var pz := _target()
	if pz == null or not is_free(): return
	if Game.ladles(ladle_oz) <= 0:
		var lo := Game.ladle_for(pz.spec_of(pz.rec.sauce))
		if lo == 0:
			Kit.main.toast("You have no ladles. Order some from KitBox.", true)
			return
		ladle_oz = lo
	if ladle_g > 0.0:
		Kit.main.toast("Drop what is in the ladle onto the pizza first")
		return
	var id: String = tool if tool != "" and Data.ING[tool].kind == "sauce" else pz.rec.sauce
	if id == "":
		Kit.main.toast("This pizza has no sauce")
		return
	var want: float = ladle_oz * Data.OZ_G
	if Stock.rail_have(id) < want * 0.5:
		var sl := Stock.rail_slot(id)
		if sl >= 0: rail_tap(sl)
		return
	var got := pz.use(id, want)
	if got <= 0.0:
		_ran_out()
		return
	ladle_g = got
	ladle_ing = id
	tool = id
	dirty = true
	Art.sfx("scoop", true)
	if got < want * 0.95: Kit.main.toast("The pan only had %s left. Refill it." % Data.oz_text(got), true)

## you lift your finger off the bench
func stroke_end(p: Vector2) -> void:
	if _target() != null: _target().end_stroke(p)

## anything still in the ladle goes in the middle
func _drop_ladle(into: Pizza = null) -> void:
	var pz: Pizza = into if into != null else (_target() if _target() != null else bench)
	if ladle_g > 0.0 and pz != null: pz.drop_sauce(ladle_ing, ladle_g, Vector2.ZERO)
	ladle_g = 0.0

func _ran_out() -> void:
	Kit.main.toast("You have run out of " + Data.ING[tool].name.to_lower(), true)
	tool = ""
	dirty = true

## a swipe of the pizza wheel from a to b
func cut(a: Vector2, b: Vector2) -> void:
	if view != "board" or board.is_empty() or not is_free(): return
	var pz: Pizza = board[0]
	var ln := a.distance_to(b)
	if ln < pz.base.R * 1.2: return
	var cutter := Equip.cutter()
	if cutter == "":
		Kit.main.toast("You have nothing to cut with. Order a pizza wheel from %s." % Equip.SHOP.name, true)
		return
	var dd: float = abs(a.x * b.y - a.y * b.x) / ln
	if cutter == "rocker": dd *= 0.6                 # one rock straight through the middle
	elif cutter == "knife":
		dd = min(dd + pz.base.R * 0.12, pz.base.R * 0.34)      # a knife drags and tears the cheese
		if pz.cuts.is_empty(): Kit.main.toast("No pizza wheel: cutting with a knife leaves ragged slices")
	if dd < pz.base.R * 0.35 and pz.cuts.size() < 4:
		if dd < pz.base.R * 0.12 and cutter != "knife":         # cut assist: near enough the middle goes through it
			var u := (b - a).normalized()
			a = -u * ln * 0.5
			b = u * ln * 0.5
			dd = 0.0
		pz.cuts.append({"a": a, "b": b, "d": dd})
		Art.sfx("cut", true)
		Art.buzz(10)
	elif dd >= pz.base.R * 0.35:
		Kit.main.toast("Cut through the middle", true)

## hands free: put down what you are holding (a topping, the cheese, an empty ladle)
func put_down() -> void:
	if tool == "" or (Data.ING[tool].kind == "sauce" and ladle_g > 0.0): return
	tool = ""
	Art.sfx("tap")
	dirty = true

# ---------- your oven ----------
func oven_load(pz: Pizza, slot: int, at: Vector2 = Vector2.INF) -> void:
	if not is_free(): return
	if not Equip.has("peel"):
		Kit.main.toast("You need a pizza peel to get it in the oven. Order one from %s." % Equip.SHOP.name, true)
		return
	oven.load_pizza(pz, slot, false, at)
	pz.tk.state = "oven"
	dirty = true
	Art.sfx("peel", true)

func oven_pull(o: Dictionary, by_marco: bool = false) -> void:
	if not Equip.has("peel") and not o.auto:
		Kit.main.toast("You need a pizza peel to get it out", true)
		return
	oven.items.erase(o)
	o.pz.stage = "board"
	if not o.pz.tk.gone: o.pz.tk.state = "board"
	board.append(o.pz)
	if not by_marco and view == "oven" and oven.mine().is_empty() and oven.shelf.is_empty(): set_view("board")
	dirty = true
	Art.sfx("peel", true)

## a wood oven at opening: lit this morning (the oven job), lit by the boss if you work for one, or stone cold
func _light_for_service() -> void:
	var G := Game
	var L: Dictionary = G.s.get("oven_lit", {})
	var minutes := -1.0
	if Story.role() == "pizzaiolo": minutes = 150.0                  # Marco lit it at dawn
	elif int(L.get("day", -1)) == G.s.day:
		minutes = max(0.0, float(G.s.clock) - float(L.at))
		# keeping it going all morning burns a log every half hour; if the wood ran out it went low
		var want: float = floor(minutes / 30.0)
		if want > 0.0:
			var got: float = Stock.take("wood", want).got
			if got < want: minutes *= 0.5 + 0.5 * got / want
	oven.start_day(minutes, float(L.get("g", 2.0)))
	if minutes < 0.0 and not training:
		r.notes.append("The wood oven was never lit this morning, so you opened with a cold oven.")
		Kit.main.toast("The oven is stone cold: nobody lit it this morning. Throw logs on and give it time to heat.", true)

func add_log() -> void:
	var lg := Stock.take("wood", 1.0)
	if lg.got >= 1.0:
		oven.add_log(lg.g)
		Art.sfx("log", true)
	else: Kit.main.toast("No firewood left", true)

func serve(by_marco: bool = false) -> void:
	if board.is_empty(): return
	var pz: Pizza = board[0]
	if pz.tk.gone:
		var alt = null
		for tk in tickets:
			if tk.state == "new" and tk.owner == "" and tk.rec.key == pz.rec.key: alt = tk
		if alt == null:
			board.pop_front()
			_waste_pizza(pz)
			if board.is_empty(): set_view("bench")
			Kit.main.toast("That customer left. The pizza is binned", true)
			return
		alt.owner = "me"
		pz.tk = alt
	var a := pz.assess(c)
	Equip.adjust(a, pz.rec, false)
	a.mine = true
	to_pass(pz.tk, a)
	board.pop_front()
	Art.sfx("bell")                         # the pass bell: it is going out
	Art.buzz(30)
	_show_result(pz, a)
	if board.is_empty() and not by_marco:
		set_view("bench" if bench != null else ("oven" if oven.mine().size() + oven.shelf.size() > 0 else "front"))

func _show_result(pz: Pizza, a: Dictionary) -> void:
	Kit.clear(pop)
	var v := Kit.vbox(2)
	v.add_child(Kit.label(pz.rec.name, 24, Kit.DARK))
	v.add_child(Kit.label("Look %d   Taste %d" % [a.look, a.taste], 21, Kit.DARK))
	v.add_child(Kit.label("Base %d · Cover %d · Portions %d · Layout %d · Bake %d · Colour %d · Cut %d" % [a.shape * 100, a.cover * 100, a.portion * 100, a.layout * 100, a.bake * 100, a.colour * 100, a.cut * 100], 15, Color("5b6a58")))
	for nt in a.notes.slice(0, 3): v.add_child(Kit.label(nt, 17, Color("a0331f")))
	var over: float = a.cost - a.spec_cost
	v.add_child(Kit.label("Cost %s to make. The recipe card allows %s." % [Kit.cents(a.cost), Kit.cents(a.spec_cost)], 16, Color("a0331f") if over > a.spec_cost * 0.12 else Color("2d7a33")))
	v.add_child(Kit.label("It is on the pass. Hand it over out front.", 16, Color("5b6a58")))
	pop.add_child(v)
	pop.visible = true
	pop.reset_size()
	if fp_mode: pop.position = Vector2(get_viewport_rect().size.x / 2.0 - 160.0, 70.0)
	else: pop.position = kitchen.global_position + Vector2(16, 16) if kitchen.visible else front.global_position + Vector2(16, 16)
	pop_t = 4.5

# ---------- ui refresh ----------
func _refresh() -> void:
	var G := Game
	var now_ms := Time.get_ticks_msec()
	var before := spiked.size()
	spiked = spiked.filter(func(e): return e.until > now_ms)
	if spiked.size() != before: dirty = true
	clock.value = clamp(t / DAY, 0, 1)
	top_lbl.time.text = ("Last orders " if t >= DAY else "") + Data.hhmm(min(minute(), c.close))
	top_lbl.cash.text = Kit.money(G.s.cash)
	top_lbl.phone.visible = phones.size() > 0
	if phones.size() > 0: top_lbl.phone.modulate.a = 0.6 + 0.4 * sin(Time.get_ticks_msec() / 120.0)
	top_lbl.tablet.visible = tablet.size() > 0
	if top_lbl.has("app"): top_lbl.app.text = "%s: %s" % [Data.APP.name, "paused" if Game.s.app.paused else "on"]
	if tablet.size() > 0:
		top_lbl.tablet.text = "%s: %d pizza%s · accept (%ds)" % [Data.APP.name, tablet[0].n, "" if tablet[0].n == 1 else "s", int(ceil((tablet[0].until - t) / max(1.0, float(speed))))]
		top_lbl.tablet.modulate.a = 0.6 + 0.4 * sin(Time.get_ticks_msec() / 100.0)
	top_lbl.rep.text = "Rating %.1f" % G.s.rep
	top_lbl.count.text = "Served %d · Lost %d" % [r.served, r.lost + r.sold]
	var dn := 0
	var styles := {}
	for rc in G.active_recipes(): styles[rc.base] = true
	for st in styles: dn += Stock.dough_ready(st)
	top_lbl.dough.text = "Dough %d" % dn
	for id in tick_bars:
		var e = tick_bars[id]
		if is_instance_valid(e.bar): e.bar.value = clamp(e.tk.p.pat / max(1.0, e.tk.p.max), 0, 1)
	var flag := ""
	for o in oven.mine():
		var st := oven.status(o)
		if (st == "BURNING" or st == "OVERDONE") and not o.get("warned", false):
			o.warned = true                         # the moment it starts to burn: once, so you hear it from anywhere
			Art.sfx("bad")
			Art.buzz(150)
		if st == "BURNING" or st == "OVERDONE": flag = "  BURNING!"
		elif st == "READY" and flag == "": flag = "  READY"
		elif st == "TURN" and flag == "": flag = "  TURN"
	# a wood fire you tend yourself: say so when it is burning down (an oven tender feeds it for you)
	if flag == "" and oven.def.feeds and not c.fornaio and oven.power_soon() < 0.95 and Stock.have("wood") >= 1.0: flag = "  FEED THE FIRE"
	var acts := actionables().size()
	tab_btns.front.text = "Front" + (" (%d)" % acts if acts > 0 else "")
	tab_btns.bench.text = "Bench"
	var in_oven: int = oven.mine().size() + oven.shelf.size()
	tab_btns.oven.text = "Oven" + (" (%d)" % in_oven if in_oven > 0 else "") + flag
	tab_btns.board.text = "Board (%d)" % board.size()
	var low := 0
	for id in line_items():
		if Stock.rail_have(id) < per_pizza(id) * 3.0: low += 1
	tab_btns.prep.text = "Prep" + (" (%d low)" % low if low > 0 else "") + ("  DELIVERY" if Game.s.dock.size() > 0 else "")
	# a station that needs you, while you are looking elsewhere, pulses: red for a pizza burning, gold for the rest
	var need := {"oven": Kit.TOMATO if flag == "  BURNING!" else (Kit.CHEESE if flag != "" else Color.WHITE),
		"board": Kit.CHEESE if board.size() > 0 else Color.WHITE, "front": Kit.CHEESE if acts > 0 else Color.WHITE,
		"prep": Kit.CHEESE if Game.s.dock.size() > 0 else Color.WHITE}
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 160.0)
	for k in tab_btns:
		var col: Color = need.get(k, Color.WHITE)
		tab_btns[k].modulate = Color.WHITE.lerp(col, 0.75 * pulse) if col != Color.WHITE and view != k else Color.WHITE
	busy_wrap.visible = not busy.is_empty() and (view != "front" or fp_mode)
	if not busy.is_empty():
		busy_lbl.text = busy.label + "\n%d s left" % ceil(busy.left)
		busy_bar.value = 1.0 - busy.left / max(busy.total, 0.001)
	for row in info_rows:
		if not is_instance_valid(row[0]): continue
		var res: Array = row[1].call()
		row[0].text = res[0]
		row[0].add_theme_color_override("font_color", res[1])
	for e in pal_btns:
		if not is_instance_valid(e[0]): continue
		var id: String = e[1]
		var a := Stock.avail(id)
		e[0].text = "%s\n%s" % [Data.ING[id].name, Data.qty(id, a) if a > 0 or not Data.needs_prep(id) else "needs prep"]
	if not dirty: return
	dirty = false
	for k in tab_btns:
		var on: bool = view == k
		tab_btns[k].add_theme_stylebox_override("normal", Kit.box(Kit.PANEL2 if on else Kit.PANEL, 10, 8))
		tab_btns[k].add_theme_color_override("font_color", Kit.INK if on else Kit.MUTED)
	if not fp_mode: _show_2d()
	_build_tickets()
	_build_side()
	_build_prep()

## in the classic layout, only the station you are at is on screen
func _show_2d() -> void:
	front.visible = view == "front"
	kitchen.visible = view != "front"
	bench_ui.visible = view == "bench" or view == "board"
	oven_ui.visible = view == "oven"
	prep_scroll.visible = view == "prep"
	rail_ui.visible = view == "bench" or view == "board"


## what a ticket says: {status, col, where, kind, note}. Used by the ticket list and the paper tickets in 3D.
func ticket_info(tk: Dictionary) -> Dictionary:
	var status := "Tap to make it"
	var col := Kit.INK
	if tk.state == "pass":
		status = "READY: hand it over"
		col = Kit.BASIL
	elif tk.owner == "me":
		status = "You: " + {"oven": "in the oven", "board": "on the board, slice it"}.get(tk.state, "making it")
		col = Kit.CHEESE
	elif tk.owner != "":
		status = tk.owner + (": in the oven" if tk.state == "oven" else ": making it")
		col = Color("c9d3c4")
	var where: String = {"take": "Phone order" if tk.p.get("phone", false) else "Takeaway", "dine": "Table %d" % (tk.p.table + 1), "deliv": "Delivery"}[tk.p.type]
	if tk.p.get("app", false): where = "%s · rider %s" % [Data.APP.name, Data.hhmm(tk.p.collect_at)]
	if tk.p.has("reg"): where = "%s's usual · %s" % [tk.p.reg, where]
	var note := Orders.text(tk.rec.get("mods", []))
	if tk.rec.get("allergy", "") != "": col = Color("f2a38f") if col == Kit.INK else col
	var kind_txt: String = Data.DOUGHS[tk.rec.base].name if tk.rec.has("base") else ""
	if tk.get("x", false):
		var mk: String = tk.rec.make
		kind_txt = {"side": "Side", "dessert": "Dessert", "drink": "Drink"}[tk.rec.course] + {"oven": ", baked", "cold": ", plated", "bar": ", made at the bar"}.get(mk, "")
		if tk.state == "new" and tk.owner == "" and mk != "oven": status = "Tap to %s it (%d sec)" % ["make" if mk == "bar" else "plate", int(round(float(tk.rec.mins) * 60.0))]
	return {"status": status, "col": col, "where": where, "kind": kind_txt, "note": note}

func _build_tickets() -> void:
	Kit.clear(tick_box)
	tick_bars = {}
	var shown := 0
	for tk in tickets:
		if shown >= 12: break
		shown += 1
		var ti := ticket_info(tk)
		var status: String = ti.status
		var col: Color = ti.col
		var where: String = ti.where
		var kind_txt: String = ti.kind
		if ti.note != "": status = ti.note.to_upper() + "\n" + status
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "#%d %s\n%s · %s\n%s" % [tk.id, tk.rec.name, where, kind_txt, status]
		b.add_theme_font_size_override("font_size", 16)
		for stn in ["normal", "hover", "pressed"]: b.add_theme_stylebox_override(stn, Kit.box(col, 8, 8))
		for cn in ["font_color", "font_hover_color", "font_pressed_color"]: b.add_theme_color_override(cn, Kit.DARK)
		b.pressed.connect(claim.bind(tk))
		tick_box.add_child(b)
		var bar := Kit.bar(1, Kit.BASIL, 5)
		tick_box.add_child(bar)
		tick_bars[tk.id] = {"bar": bar, "tk": tk}
	if tickets.size() > shown: tick_box.add_child(Kit.label("+%d more waiting" % (tickets.size() - shown), 16, Kit.MUTED))
	for e in spiked:
		var sb := Kit.label("#%d %s\n%s" % [e.tk.id, e.tk.rec.name, e.why], 15, Kit.TOMATO if e.why != "COLLECTED" and e.why != "SERVED" else Kit.BASIL, true)
		sb.modulate.a = 0.75
		tick_box.add_child(sb)
	if tickets.is_empty(): tick_box.add_child(Kit.label("No orders yet. Customers order out front.", 16, Kit.MUTED, true))

func _info(fn: Callable, size: int = 17) -> void:
	var l := Kit.label("", size, Kit.INK, true)
	info.add_child(l)
	info_rows.append([l, fn])

## something for the full card only (the explanations): the short card keeps to what you need right now
func _detail(c: Control) -> void:
	if card_full or not fp_mode: info.add_child(c)
	else: c.free()

func _gram_row(pz: Pizza, id: String) -> void:
	_info(func():
		var g: float = pz.grams.get(id, 0.0)
		var ratio := pz.portion(id)
		var col := Kit.INK if ratio < 0.85 else (Kit.BASIL if ratio <= 1.2 else Kit.TOMATO)
		if Data.ING[id].kind == "sauce":
			return ["%s   %s of %s (%s)" % [Data.ING[id].name, Data.oz_text(g), Data.oz_text(pz.spec_of(id)), Data.qty(id, pz.spec_of(id))], col]
		if Data.ING[id].unit == "g" and not Equip.has("scales"):      # no scales on the counter: you are judging by eye
			return ["%s   %s of %s (no scales)" % [Data.ING[id].name, Equip.weigh(g), Data.qty(id, pz.spec_of(id))], Kit.INK]
		return ["%s   %s of %s" % [Data.ING[id].name, Data.qty(id, g), Data.qty(id, pz.spec_of(id))], col])

func _tool_button(id: String, need: bool) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 14)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.y = 46
	var bg: Color = Color(Data.ING[id].col).darkened(0.25)
	for stn in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(stn, Kit.box(bg, 8, 3, Kit.CHEESE if tool == id else (Kit.INK if need else Color(0, 0, 0, 0)), 4 if tool == id else (1 if need else 0)))
	var fgc := Color.BLACK if bg.get_luminance() > 0.5 else Color.WHITE
	for cn in ["font_color", "font_hover_color", "font_pressed_color"]: b.add_theme_color_override(cn, fgc)
	b.pressed.connect(func():
		if Stock.rail_have(id) <= 0.5:
			var sl := Stock.rail_slot(id)
			if sl >= 0: rail_tap(sl)
			else: Kit.main.toast("There is no pan of %s on the rail" % Data.ING[id].name.to_lower(), true)
			return
		tool = id
		dirty = true)
	pal_btns.append([b, id])
	return b

func _build_side() -> void:
	Kit.clear(info)
	Kit.clear(palette)
	Kit.clear(mini_box)
	info_rows = []
	pal_btns = []
	var pz: Pizza = null
	if view == "board" and board.size() > 0: pz = board[0]
	elif view == "bench": pz = bench
	btn_row.visible = not fp_mode and view != "oven" and view != "prep"        # in 3D: the pass, the bin and the sheeter are in the room
	next_btn.visible = pz != null and view == "board"
	bin_btn.visible = pz != null
	if put_btn != null:
		put_btn.visible = tool != "" and not (Data.ING[tool].kind == "sauce" and ladle_g > 0.0)
		var lefty: bool = tool_hand == 1                    # under the thumb that is holding it
		put_btn.anchor_left = 0.0 if lefty else 1.0
		put_btn.anchor_right = 0.0 if lefty else 1.0
		var w := 290.0
		put_btn.offset_left = 10.0 if lefty else -10.0 - w
		put_btn.offset_right = 10.0 + w if lefty else -10.0
		if put_btn.visible: put_btn.text = "Put down the %s" % ("ladle" if Data.ING[tool].kind == "sauce" else Data.ING[tool].name.to_lower())
	auto_btn.visible = pz != null and view == "bench" and pz.base.method == "roll" and c.roll_auto > 0
	mini_panel.visible = view != "oven" and oven.mine().size() + oven.shelf.size() > 0
	if not helps.is_empty(): info.add_child(Kit.label(Story.today_short(), 15, Kit.CHEESE, true))
	if mini_panel.visible:
		mini_box.add_child(Kit.label("IN THE OVEN", 14, Kit.MUTED))
		for o in oven.mine():
			var lb := Kit.label("", 16)
			mini_box.add_child(lb)
			info_rows.append([lb, func():
				var st := oven.status(o)
				return ["%s: %s" % [o.pz.rec.name, ("baking %d%%" % (o.pz.bake_avg() * 100)) if st == "baking" else st], Kit.BASIL if st == "READY" else (Kit.TOMATO if st in ["BURNING", "OVERDONE"] else (Kit.CHEESE if st == "TURN" else Kit.INK))]])
		if oven.shelf.size() > 0: mini_box.add_child(Kit.label("%d waiting on the shelf" % oven.shelf.size(), 16, Kit.CHEESE))
	if view == "oven":
		_side_oven()
		return
	if view == "prep":
		_side_prep()
		return
	if pz == null:
		info.add_child(Kit.label("Tap a ticket on the rail above the counter to start it." if fp_mode else "Tap an order on the left to start it.", 17, Kit.MUTED, true))
		_detail(Kit.label("Open the base, top it by weight, bake it, slice it, send it to the pass.", 15, Kit.MUTED, true))
		return
	info.add_child(Kit.label("#%d %s" % [pz.tk.id, pz.rec.name], 21))
	if view == "board":
		next_btn.text = "Send to the pass"
		var finishing: Array = pz.rec.tops.filter(func(id): return Data.ING[id].after)
		_detail(Kit.label("Hand empty: swipe across the pizza to slice it, three cuts through the middle. Anything you pick up goes on wherever you put it." + ("  The finishing toppings go on now." if finishing.size() > 0 else "") + ("  Tap the pass to send it out." if fp_mode else ""), 16, Kit.MUTED, true))
		_info(func(): return ["Cuts: %d of 3" % pz.cuts.size(), Kit.BASIL if pz.cuts.size() >= 3 else Kit.INK])
		for id in finishing: _gram_row(pz, id)
		if finishing.size() > 0 and not fp_mode:
			var g := Kit.grid(2, 5)
			var wheel := Kit.button("Pizza wheel", func():
				tool = ""
				dirty = true, "primary" if tool == "" else "ghost", 15)
			wheel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			g.add_child(wheel)
			palette.add_child(g)
			palette.add_child(Kit.label("For the finishing toppings, tap their pan on the rail.", 14, Kit.MUTED, true))
		return
	# the bench: no steps. Shape it, top it, take it to the oven, in whatever order you like.
	var b := pz.base
	var how: String = {
		"hand": "Hand empty: one finger presses the dough out (leave a rim), two fingers stretch it and twist it.",
		"roll": "Hand empty: roll the pin across the dough with a finger, changing direction so it stays round.",
		"press": "Hand empty: rub the dough outward to the wall of the pan."}[b.method]
	var topping := "" if helps.has("top") else " Tap a pan to pick up a topping (tap it again to put it back); one finger then puts it on."
	_detail(Kit.label(how + topping + " %s" % ("Turn to the oven and the pizza comes with you on the peel." if fp_mode else "Go to the Oven tab and the pizza comes with you."), 14, Kit.MUTED, true))
	if b.method == "hand" and not DisplayServer.is_touchscreen_available():
		_detail(Kit.label("With a mouse: left button is one finger, right button is two.", 13, Kit.MUTED, true))
	_info(func(): return ["Size %.1f of %d cm · rim %.1f (aim %.1f) · %d%%" % [b.diameter_cm(), pz.d.size_cm, b.crust_cm(), pz.d.crust_cm, b.score().total * 100], Kit.BASIL if b.score().total >= 0.8 else Kit.CHEESE], 16)
	next_btn.text = "To the oven"
	if helps.has("top"):
		# you only stretch today: when it is out to the ring, Marco takes it
		_info(func(): return ["%s: turn to the Oven and hand it to %s. He tops it, bakes it and sends it." % ["Stretched" if b.score().size >= 0.8 else "Stretch it out to the ring, then", Story.BOSS], Kit.BASIL if b.score().size >= 0.8 else Kit.CHEESE], 16)
		return
	for id in [pz.rec.sauce, pz.rec.cheese] + pz.rec.tops:
		if id == "": continue
		if Data.ING[id].after:
			info.add_child(Kit.label("%s   goes on after the oven" % Data.ING[id].name, 16, Kit.MUTED))
		else:
			_gram_row(pz, id)
	if card_full or not fp_mode: _info(func(): return ["On the pizza so far: %s" % Kit.cents(pz.cost), Kit.MUTED], 15)
	if tool != "": info.add_child(Kit.label("In your hand: " + Data.ING[tool].name.to_lower(), 15, Kit.CHEESE, true))
	else: _detail(Kit.label("Tap a pan on the rail to pick up that topping, then spread or place it on the pizza.", 15, Kit.CHEESE, true))
	if pz.rec.sauce != "" and not fp_mode:          # in 3D the ladles hang on their rack and you tap the sauce pan to scoop
		var lh := Kit.hbox(6)
		lh.add_child(Kit.label("Ladle:", 16, Kit.MUTED))
		for oz in Data.LADLES:
			if Game.ladles(oz) <= 0: continue
			lh.add_child(Kit.button("%d oz" % oz, func():
				if ladle_g > 0.0:
					Kit.main.toast("Drop what is in the ladle first")
					return
				ladle_oz = oz
				dirty = true, "primary" if ladle_oz == oz else "ghost", 15))
		var sb := Kit.button("Scoop", scoop, "danger", 15)
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lh.add_child(sb)
		palette.add_child(lh)
	if pz.rec.sauce != "":
		_info(func():
			if ladle_g > 0.0: return ["Ladle: %s of %s. Tap the middle of the pizza to drop it." % [Data.oz_text(ladle_g), Data.ING[ladle_ing].name.to_lower()], Kit.CHEESE]
			var want_oz := int(round(pz.spec_of(pz.rec.sauce) / Data.OZ_G))
			if pz.sauce == "" and Game.ladles(want_oz) == 0: return ["You have no %d oz ladle. Use a smaller one more than once, or order one from KitBox." % want_oz, Kit.TOMATO]
			if pz.sauce == "": return ["%s %s of %s, drop it in the middle, then spread it out to the rim with the back of the ladle." % ["Tap the sauce pan to scoop" if fp_mode else "Scoop", Data.oz_text(pz.spec_of(pz.rec.sauce)), Data.ING[pz.rec.sauce].name.to_lower()], Kit.INK]
			var cov: float = pz.cov(pz.sauce_amt)
			if cov < 0.95: return ["Spread the sauce out evenly to the rim: drag the back of the ladle round in a spiral (%d%% covered)." % (cov * 100), Kit.MUTED]
			# the sauce is done: say what is still to go on, then where it goes next
			var left := []
			for id in pz.rec.spec:
				if id != pz.rec.sauce and not Data.ING[id].after and pz.grams.get(id, 0.0) < pz.spec_of(id) * 0.9: left.append(Data.ING[id].name.to_lower())
			if left.size() > 0: return ["Sauce done. Now the %s: tap the pan, then put it on where your finger goes." % " and ".join(left.slice(0, 2)), Kit.INK]
			return ["All on. Take it to the oven to bake.", Kit.BASIL], 15)

func _side_oven() -> void:
	info.add_child(Kit.label(oven.tier.n, 20))
	_detail(Kit.label(oven.def.help, 15, Kit.MUTED, true))
	if c.fornaio: info.add_child(Kit.label("Your oven tender is loading, turning and pulling for you.", 15, Kit.BASIL, true))
	if oven.def.feeds:
		_info(func():
			var word := oven.fire_word()
			var good: bool = word == "just right" and oven.dome >= 420.0
			var ct := oven.catching()
			return ["Fire: %s · %d burning log%s%s" % [word, oven.logs.size(), "" if oven.logs.size() == 1 else "s", (" (%d catching)" % ct) if ct > 0 else ""], Kit.BASIL if good else Kit.CHEESE], 19)
		_info(func():
			if not Equip.has("ir_thermo"): return ["No infrared thermometer: you are judging the heat by eye (KitBox sells them)", Kit.MUTED]
			var rg: Array = oven.deck_range()
			return ["Infrared: dome %d °C · deck %d °C (by the mouth) to %d °C (by the fire)" % [oven.dome, rg[0], rg[1]], Kit.BASIL if oven.dome >= 420.0 and rg[0] >= 360.0 else Kit.CHEESE], 16)
		if not fp_mode:                         # in 3D the logs are stacked beside the oven mouth
			var lb := Kit.button("", add_log, "primary", 18)
			palette.add_child(lb)
			info_rows.append([lb, func(): return ["Add a log (%d left)" % int(Stock.have("wood")), Kit.DARK]])
	for o in oven.mine():
		_info(func():
			var rng: Array = o.pz.bake_range()
			return ["%s: %s, %d%% done (%d%% to %d%%)" % [o.pz.rec.name, oven.status(o), o.pz.bake_avg() * 100, rng[0] * 100, rng[1] * 100], Kit.INK])

# ---------- the counter rail, prep and the back door ----------
## every topping on tonight's menu (all of them go in a pan on the rail)
func line_items() -> Array:
	var out := []
	for rc in Game.active_recipes():
		if eighty6.has(rc.id): continue
		for id in rc.spec:
			if not out.has(id): out.append(id)
	return out

## grams of a topping one pizza takes, averaged over tonight's pizzas that use it
func per_pizza(id: String) -> float:
	var t := 0.0
	var n := 0
	for rc in Game.active_recipes():
		if rc.spec.has(id):
			t += rc.spec[id]
			n += 1
	return t / n if n > 0 else 0.0

## how much raw stock to prep in one go mid-service: the rest of tonight, at least 8 pizzas' worth
func batch_raw(id: String, pizzas: int = -1) -> float:
	var y: float = float(Data.ING[id].prep.yield)
	var want: float
	if pizzas > 0:
		want = per_pizza(id) * pizzas
	else:
		var all: int = max(1, Game.active_recipes().size())
		var users := 0
		for rc in Game.active_recipes():
			if rc.spec.has(id) and not eighty6.has(rc.id): users += 1
		want = max(per_pizza(id) * users * c.total * max(0.1, 1.0 - t / DAY) * 1.1 / all - Stock.prepped(id) - Stock.rail_have(id), per_pizza(id) * 8.0)
	return min(min(Stock.have(id), Stock.max_prep_raw(id)), want / y)

## what it takes to get a topping back on the rail: {kind "refill"/"prep", raw, minutes} or {} if nothing can be done
func line_job(id: String, may_prep: bool, mult: float) -> Dictionary:
	var slot := Stock.rail_slot(id)
	if slot < 0: return {}
	if Stock.refill_source(id) > 0.5: return {"kind": "refill", "raw": 0.0, "minutes": 1.0}
	if may_prep and Data.needs_prep(id) and Stock.have(id) > 0 and Equip.prep_block(id) == "":
		var raw := batch_raw(id)
		if raw > 10.0: return {"kind": "prep", "raw": raw, "minutes": Stock.prep_minutes(id, raw, mult) + 1.0}
	return {}

## a line job is done: prep into tubs if needed, then fill the pan
func line_job_done(id: String, raw: float, quality: float) -> void:
	if raw > 0.0: Stock.prep(id, raw, quality)
	var slot := Stock.rail_slot(id)
	if slot >= 0: Stock.refill(slot)
	prepping.erase(id)

## you tap a pan on the rail
func rail_tap(i: int) -> void:
	var pan: Dictionary = Stock.rail()[i]
	if pan.ing == "":
		Kit.main.toast("That pan is not in use tonight")
		return
	var id: String = pan.ing
	var enough: bool = pan.q > max(0.5, per_pizza(id) * 0.7)
	if not enough and Stock.refill_source(id) > 0.5:
		refill_now(i)
		return
	if pan.q > 0.5:
		var it: Dictionary = Data.ING[id]
		if tool == id and it.kind != "sauce":          # tapping what you are holding puts it back: hands free
			tool = ""
			dirty = true
			return
		if it.kind == "sauce" and _target() != null:
			tool = id
			scoop()
			return
		if ladle_g > 0.0:
			_drop_ladle()
			Kit.main.toast("The sauce in the ladle went in the middle")
		tool = id                                       # whatever you pick up goes on wherever you put it, whenever
		dirty = true
		return
	if Stock.refill_source(id) > 0.5: refill_now(i)
	elif Data.needs_prep(id) and Stock.have(id) > 0:
		Kit.main.toast("No %s %s left in tubs. Prep some on the Prep tab." % [Data.ING[id].prep.as, Data.ING[id].name.to_lower()], true)
		set_view("prep")
	else:
		Kit.main.toast("You are out of %s. 86 the pizzas that need it." % Data.ING[id].name.to_lower(), true)
		set_view("prep")

## you refill a pan from the tubs (or the stores)
func refill_now(i: int) -> void:
	if not is_free(): return
	var id: String = Stock.rail()[i].ing
	start_busy("Refilling the %s pan" % Data.ING[id].name.to_lower(), 1.0, func(frac):
		if frac >= 0.99: Stock.refill(i))

## you prep something: you are tied up until it is done, then you fill the pan with it
func prep_now(id: String, raw: float) -> void:
	if raw <= 0.0 or not is_free(): return
	if Equip.prep_block(id) != "":
		Kit.main.toast(Equip.prep_block(id), true)
		return
	var p = Data.ING[id].prep
	var mins := Stock.prep_minutes(id, raw, Day.prep_mult()) + 1.0
	prepping[id] = "you"
	start_busy("%s: %s %s" % [p.task, Data.qty(id, raw), Data.ING[id].name.to_lower()], mins, func(frac):
		line_job_done(id, raw * frac, 0.7))

func wash_now() -> void:
	if not is_free() or Stock.dirty_tubs() == 0: return
	start_busy("Washing %d tubs" % Stock.dirty_tubs(), Stock.wash_minutes(), func(frac):
		if frac >= 0.99: Stock.wash_all())

## you put a delivery away
func put_away_now(e: Dictionary, rotate: bool) -> void:
	if not is_free(): return
	e.handling = "you"
	start_busy("Putting %s's delivery away%s" % [Data.SUP[e.sup].name, "" if rotate else " (stacked in front)"], Stock.dock_minutes(e, rotate), func(frac):
		if frac < 1.0:
			e.erase("handling")
			return
		var res := Stock.put_away(e, rotate, minute())
		var txt := Day._waste_text(res)
		if txt != "": Kit.main.toast(txt.strip_edges(), true))

## prep cooks and kitchen porters: deliveries first, then the rail (prep cook) or the wash-up and floor (porter)
func _crew_step(dt: float) -> void:
	for w in crew:
		if w.job != "":
			w.left -= dt
			if w.left <= 0:
				w.fn.call()
				w.job = ""
				dirty = true
			continue
		for e in Game.s.dock:
			if e.has("handling"): continue
			e.handling = w.s.name
			w.job = "delivery"
			w.left = secs(Stock.dock_minutes(e, true) * (1.2 - 0.08 * w.s.skill))
			w.fn = func():
				var res := Stock.put_away(e, true, minute())
				r.notes.append("%s put %s's delivery away and rotated the stock.%s" % [w.s.name, Data.SUP[e.sup].name, Day._waste_text(res)])
			break
		if w.job != "": continue
		if w.role == "prep":
			for id in line_items():
				if prepping.has(id) or Stock.rail_have(id) >= per_pizza(id) * 6.0: continue
				var job := line_job(id, true, Day.prep_mult() * (1.25 - 0.08 * w.s.skill))
				if job.is_empty(): continue
				prepping[id] = w.s.name
				w.job = job.kind
				w.left = secs(job.minutes)
				var raw: float = job.raw
				var q: float = 0.6 + 0.08 * w.s.skill
				w.fn = func(): line_job_done(id, raw, q)
				break
		if w.job == "" and w.role == "porter":
			if Stock.dirty_tubs() >= 3:
				w.job = "wash"
				w.left = secs(Stock.wash_minutes())
				w.fn = func(): Stock.wash_all()
			else:
				Hygiene.tidy("boh", 0.3 * gm * dt)
	var servers := Game.staff_of("server").size()
	if servers > 0: Hygiene.tidy("foh", 0.05 * servers * gm * dt)

## a mouse runs across the front: whoever sees it leaves, and everyone talks about it
func _mouse() -> void:
	r.mice += 1
	mouse_until = minute() + 45.0
	mouse = {"pos": Vector2(-20, 300), "vel": Vector2(240, -6), "t": 3.2}
	var near: Array = parties.filter(func(p): return p.state in ["queue", "door", "ask", "wait"])
	if near.size() > 0:
		var p: Dictionary = near.pick_random()
		expire(p, "Saw a mouse!")
		r.mouse_lost = r.get("mouse_lost", 0) + p.n
	Game.s.rep += (1.0 - Game.s.rep) * max(0.02, 1.0 / (Game.s.ratings + 6)) * 0.6
	Kit.main.toast("A customer saw a mouse!", true)

func _day_dot(l: Dictionary) -> String:
	return "%s dot, use by %s" % [Stock.DAY_DOT[Game.weekday(int(l.get("made", Game.s.day)))].to_lower(), Data.DAY_SHORT[Game.weekday(int(ceil(l.x)) - 1)] if l.x - Game.s.day < 7 else "next week"]

## the Prep tab: the back door, the rail and the tubs, the wash-up, and tonight's menu
func _build_prep() -> void:
	Kit.clear(prep_box)
	if view != "prep": return
	if Game.s.dock.size() > 0:
		prep_box.add_child(Kit.label("AT THE BACK DOOR", 15, Kit.MUTED))
		for e in Game.s.dock:
			var sup: Dictionary = Data.SUP[e.sup]
			var pc := Kit.panel(Kit.PANEL, 10)
			var v := Kit.vbox(4)
			pc.add_child(v)
			v.add_child(Kit.label("%s · arrived %s" % [sup.name, Data.hhmm(e.arrived)], 19))
			v.add_child(Kit.label(", ".join(e.lines.map(func(ln): return "%s %s" % [ln.what, ln.name])), 14, Kit.MUTED, true))
			var wl := Kit.label("", 15, Kit.INK, true)
			v.add_child(wl)
			info_rows.append([wl, func():
				var waited: float = minute() - e.arrived
				return ["Waiting %d minutes. Chilled food starts to spoil after 30, and is binned after 3 hours." % waited, Kit.TOMATO if waited > 30 else Kit.MUTED]])
			if e.has("handling"):
				v.add_child(Kit.label(("You are" if e.handling == "you" else e.handling + " is") + " putting it away.", 16, Kit.BASIL))
			else:
				var h := Kit.hbox(8)
				h.add_child(Kit.button("Put away and rotate (%d min)" % Stock.dock_minutes(e, true), put_away_now.bind(e, true), "primary", 16))
				h.add_child(Kit.button("Stack it in front (%d min)" % Stock.dock_minutes(e, false), put_away_now.bind(e, false), "ghost", 16))
				v.add_child(h)
			prep_box.add_child(pc)
	var th := Kit.hbox(8)
	var tl := Kit.label("", 15, Kit.MUTED, true)
	th.add_child(tl)
	info_rows.append([tl, func(): return ["THE RAIL AND THE TUBS   ·   clean tubs: %d x 4 L, %d x 2 L   ·   %d dirty" % [Stock.clean_tubs(4), Stock.clean_tubs(2), Stock.dirty_tubs()], Kit.MUTED]])
	if Stock.dirty_tubs() > 0 and Game.staff_of("porter").is_empty():
		th.add_child(Kit.button("Wash up · %d min" % Stock.wash_minutes(), wash_now, "ghost", 14))
	prep_box.add_child(th)
	var bh := Kit.hbox(8)
	var bl := Kit.label("", 15, Kit.MUTED, true)
	bh.add_child(bl)
	info_rows.append([bl, func(): return ["PIZZA BOXES   ·   %d folded by the pass   ·   %d flat" % [Stock.folded(), int(Stock.have("box"))], Kit.TOMATO if Stock.folded() < 3 and not L.dine else Kit.MUTED]])
	bh.add_child(Kit.button("Fold 10 · %d min" % ceil(Stock.FOLD_MIN * 10), fold_now.bind(10), "ghost", 14))
	prep_box.add_child(bh)
	for id in line_items():
		var it: Dictionary = Data.ING[id]
		var pc := Kit.panel(Kit.PANEL, 8, 10)
		var h := Kit.hbox(8)
		pc.add_child(h)
		h.add_child(Kit.swatch(id, 18))
		var v := Kit.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(Kit.label(it.name, 17))
		var st := Kit.label("", 14, Kit.MUTED, true)
		v.add_child(st)
		h.add_child(v)
		var pp := per_pizza(id)
		var slot := Stock.rail_slot(id)
		info_rows.append([st, func():
			if slot < 0: return ["No pan for it on the rail: the counter is full. 86 the pizzas that need it, or upgrade the counter.", Kit.TOMATO]
			var a := Stock.rail_have(id)
			var who: String = prepping.get(id, "")
			var tubs := ""
			if Data.needs_prep(id):
				var ls: Array = Stock.prepped_lots(id)
				tubs = "  ·  %d tub%s, %s%s" % [ls.size(), "" if ls.size() == 1 else "s", Data.qty(id, Stock.prepped(id)), (" (" + _day_dot(ls[0]) + ")") if ls.size() > 0 else ""]
			return ["Pan %d: %s (about %d pizzas)%s  ·  %s raw%s" % [slot + 1, Data.qty(id, a), a / max(pp, 0.01), tubs, Data.qty(id, Stock.have(id)), ("  ·  " + ("you are" if who == "you" else who + " is") + " on it") if who != "" else ""],
				Kit.TOMATO if a < pp * 2 else (Kit.CHEESE if a < pp * 6 else Kit.MUTED)]])
		if slot >= 0 and not prepping.has(id):
			if Stock.refill_source(id) > 0.5 and Stock.rail_have(id) < Stock.pan_cap(id) * 0.7:
				h.add_child(Kit.button("Refill pan · 1 min", refill_now.bind(slot), "primary", 15))
			if Data.needs_prep(id) and Stock.have(id) > 0 and Equip.prep_block(id) != "":
				h.add_child(Kit.label(Equip.prep_block(id), 14, Kit.TOMATO, true))
			elif Data.needs_prep(id) and Stock.have(id) > 0:
				var small := batch_raw(id, 10)
				var rest := batch_raw(id)
				if small > 10.0: h.add_child(Kit.button("Prep 10 pizzas · %d min" % ceil(Stock.prep_minutes(id, small, Day.prep_mult()) + 1), prep_now.bind(id, small), "ghost", 15))
				if rest > small * 1.3: h.add_child(Kit.button("Rest of tonight · %d min" % ceil(Stock.prep_minutes(id, rest, Day.prep_mult()) + 1), prep_now.bind(id, rest), "ghost", 15))
		prep_box.add_child(pc)
	prep_box.add_child(Kit.label("TONIGHT'S MENU", 15, Kit.MUTED))
	for rc in Game.active_recipes():
		var h := Kit.hbox(8)
		var nm := Kit.label(rc.name, 17)
		nm.custom_minimum_size.x = 210
		h.add_child(nm)
		var st := Kit.label("", 15, Kit.MUTED, true)
		h.add_child(st)
		info_rows.append([st, func():
			if eighty6.has(rc.id): return ["86'd: off the menu tonight", Kit.TOMATO]
			if Stock.dough_ready(rc.base) < 1: return ["Sold out: no %s dough left" % Data.DOUGHS[rc.base].name, Kit.TOMATO]
			if not sellable(rc): return ["Sold out: not enough left in stock", Kit.TOMATO]
			var np := Game.line_short(rc)
			if np.size() > 0: return ["Customers can order it but the rail is out of " + ", ".join(np.map(func(i): return Data.ING[i].name.to_lower())), Kit.CHEESE]
			return ["On", Kit.BASIL]])
		var off: bool = eighty6.has(rc.id)
		h.add_child(Kit.button("Back on" if off else "86 it", func():
			if off: eighty6.erase(rc.id)
			else: eighty6[rc.id] = true
			dirty = true, "primary" if off else "ghost", 15))
		prep_box.add_child(h)

func _side_prep() -> void:
	info.add_child(Kit.label("Prep and the rail", 21))
	_detail(Kit.label("Every topping comes out of a pan on the counter rail. Empty pans are refilled from the tubs in the fridge; when the tubs run out, prep more (you are tied up while you do), let a prep cook or pizzaiolo do it, or 86 the pizzas that need it. Deliveries that arrive mid-shift wait at the back door.", 15, Kit.MUTED, true))
	for w in crew:
		_info(func(): return ["%s (%s): %s" % [w.s.name, Data.ROLES[w.s.role].name.to_lower(), {"": "keeping on top of things", "prep": "prepping", "refill": "refilling a pan", "delivery": "putting a delivery away", "wash": "washing tubs"}[w.job]], Kit.INK], 15)
	for w in workers:
		_info(func(): return ["%s (pizzaiolo): %s" % [w.s.name, ("sorting out the " + Data.ING[w.prep].name.to_lower()) if w.prep != "" else ("making a pizza" if w.job != null else "waiting for tickets")], Kit.INK], 15)
	_info(func():
		var l := Hygiene.level("boh")
		return ["Kitchen %d%% clean" % l, Kit.BASIL if l >= 70 else (Kit.CHEESE if l >= 45 else Kit.TOMATO)], 16)
	_info(func():
		var l := Hygiene.level("foh")
		return ["Front of house %d%% clean" % l, Kit.BASIL if l >= 70 else (Kit.CHEESE if l >= 45 else Kit.TOMATO)], 16)

# ---------- close ----------
func finish(sold_out: bool) -> void:
	if done: return
	done = true
	var G := Game
	if not busy.is_empty(): stop_busy()
	for e in G.s.dock: e.erase("handling")
	for p in parties:
		if p.state == "eat" or p.state == "bill" or (p.state == "wait" and p.got >= p.n and p.got > 0): settle(p, false)
		elif p.state != "leave":
			r.lost += p.n - p.got
			if p.get("app", false): _app_rate(-0.1)
	for tk in tickets: _waste_tk(tk)
	if bench != null: _waste_pizza(bench)
	for pz in board: _waste_pizza(pz)
	for pz in oven.shelf: _waste_pizza(pz)
	for o in oven.mine(): _waste_pizza(o.pz)
	var bk: Dictionary = G.s.book
	r.sold_out = sold_out
	r.rent = G.rent()
	r.rent_name = "Pitch fee" if G.pitch() != null else G.venue().rentName
	r.wages = G.wages()
	r.util = G.utilities()
	r.interest = -G.s.cash * 0.05 if G.s.cash < 0 else 0.0
	G.s.cash -= r.rent + r.wages + r.util + r.interest
	r.cost_used = bk.cost_used
	r.cost_spec = bk.cost_spec
	r.cost_waste = bk.cost_waste
	r.xp = int(round(r.xp + 20))
	r.ups = G.add_xp(r.xp)
	r.level = G.s.level
	r.rep1 = G.s.rep
	r.lost += r.sold
	r.avg_q = int(round(r.qsum / r.served)) if r.served > 0 else 0
	for k in r.cats: r.cats[k] = r.cats[k] / r.n_rev if r.n_rev > 0 else 0.0
	r.best = ""
	r.worst = ""
	if reviews.size() > 0:
		var sorted := reviews.duplicate()
		sorted.sort_custom(func(a, b): return a.stars > b.stars)
		r.best = "%.1f stars: %s" % [sorted[0].stars, sorted[0].text]
		if sorted.size() > 1 and sorted[-1].stars < sorted[0].stars - 0.25: r.worst = "%.1f stars: %s" % [sorted[-1].stars, sorted[-1].text]
	r.profit = r.food + r.tips + r.drinks + r.deliv - r.get("app_fees", 0.0) - r.cost_used - r.cost_waste - r.rent - r.wages - r.util - r.interest
	r.eighty6 = eighty6.keys().map(func(id): return Data.REC[id].name if Data.REC.has(id) else Data.EXTRA[id].name if Data.EXTRA.has(id) else id)
	r.boh1 = Hygiene.level("boh")
	r.foh1 = Hygiene.level("foh")
	G.s.phase = "evening"
	if not r.get("broken", {}).is_empty():
		var broke := []
		for k in r.broken: broke.append("%d %s%s" % [r.broken[k], k, ("" if r.broken[k] == 1 else ("es" if k == "glass" else "s"))])
		r.notes.append("Broken in service: %s. You can lay %d places now." % [", ".join(broke), Equip.seats()])
	r.notes.append_array(Day.start_evening())
	G.s.last = r
	G.save_game()
	Kit.main.show_hub("home")
	_summary()

func _summary() -> void:
	var v := Kit.vbox(8)
	v.add_child(Kit.label("%s closed%s" % [Game.date_text(r.day).get_slice(" · ", 0) + ", day %d" % r.day, ": sold out!" if r.sold_out else ""], 28))
	var g := Kit.grid(2, 30)
	var left := [["Pizzas served", "%d (%d by you)" % [r.served, r.mine]], ["Customers lost", str(r.lost)], ["Rating", "%.2f to %.2f" % [r.rep0, r.rep1]]]
	var why := []
	if r.walked > 0: why.append("%d walked off when the queue was too long" % r.walked)
	if r.gave_up > 0: why.append("%d gave up waiting" % r.gave_up)
	if r.sold > 0: why.append("%d found nothing left to sell" % r.sold)
	if r.n_rev > 0:
		left.append(["Look", "%.1f / 5" % r.cats.look])
		left.append(["Taste", "%.1f / 5" % r.cats.taste])
		left.append(["Service", "%.1f / 5" % r.cats.service])
		left.append(["Value", "%.1f / 5" % r.cats.value])
	left.append(["XP earned", "+%d" % r.xp])
	var right := [["Food sales", Kit.money(r.food)], ["Tips", Kit.money(r.tips)]]
	if r.drinks > 0: right.append(["Drinks (%d)" % (int(r.get("drinks_n", 0)) + int(r.get("bar_n", 0))), Kit.money(r.drinks)])
	if int(r.get("extras", 0)) > 0: right.append(["Sides, desserts and made drinks", str(r.extras)])
	if r.deliv > 0: right.append(["Delivery fees", Kit.money(r.deliv)])
	if int(r.get("app_orders", 0)) + int(r.get("app_missed", 0)) > 0:
		right.append(["%s orders (%d, %d missed, %d cancelled)" % [Data.APP.name, int(r.get("app_orders", 0)), int(r.get("app_missed", 0)), int(r.get("app_cancel", 0))], "-%s commission" % Kit.money(r.get("app_fees", 0.0))])
	right.append(["Food that went on the pizzas", "-" + Kit.cents(r.cost_used)])
	if r.cost_waste > 0.005: right.append(["Binned", "-" + Kit.cents(r.cost_waste)])
	right.append([r.rent_name, Kit.money(-r.rent)])
	if r.wages > 0: right.append(["Wages", Kit.money(-r.wages)])
	right.append(["Gas & electric", Kit.money(-r.util)])
	if r.interest > 0: right.append(["Overdraft interest", Kit.money(-r.interest)])
	right.append(["Profit", Kit.money(r.profit)])
	for col in [left, right]:
		var cv := Kit.vbox(3)
		cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for ln in col:
			var h := Kit.hbox(8)
			var a := Kit.label(ln[0], 19, Kit.MUTED)
			a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(a)
			h.add_child(Kit.label(ln[1], 19, (Kit.BASIL if r.profit >= 0 else Kit.TOMATO) if ln[0] == "Profit" else Kit.INK))
			cv.add_child(h)
		g.add_child(cv)
	v.add_child(g)
	if r.get("mouse_lost", 0) > 0: why.append("%d left after seeing a mouse" % r.mouse_lost)
	if why.size() > 0: v.add_child(Kit.label("Lost customers: " + ", ".join(why) + ".", 17, Kit.TOMATO if r.lost > r.served * 0.2 else Kit.MUTED, true))
	var cust := []
	if r.mods > 0: cust.append("%d orders came with notes" % r.mods)
	if r.complaints > 0: cust.append("%d complaint%s (%s refunded, %s on free drinks)" % [r.complaints, "" if r.complaints == 1 else "s", Kit.cents(r.refunds), Kit.cents(r.comps)])
	if r.allergy > 0: cust.append("%d ALLERGIC REACTION%s: expect the inspector soon" % [r.allergy, "" if r.allergy == 1 else "S"])
	if r.calls > 0: cust.append("%d phone call%s, %d missed" % [r.calls, "" if r.calls == 1 else "s", r.missed])
	if r.change_err > 0.0: cust.append("%s lost giving too much change" % Kit.cents(r.change_err))
	if r.regulars.size() > 0: cust.append("regulars in: " + ", ".join(r.regulars))
	if cust.size() > 0: v.add_child(Kit.label("Customers: " + "; ".join(cust) + ".", 16, Kit.TOMATO if r.allergy > 0 else Kit.MUTED, true))
	if r.critic >= 0: v.add_child(Kit.label("A food critic from the Evening Post was in today, incognito. They gave you %.1f stars. %s" % [r.critic, "Expect a busier week." if r.critic >= 3.5 else "That will keep people away for a while."], 18, Kit.BASIL if r.critic >= 3.5 else Kit.TOMATO, true))
	if r.closed: v.add_child(Kit.label("The hygiene inspector closed you down at %s. Clean up, deal with the pests, and you can open again tomorrow." % Data.hhmm(minute()), 18, Kit.TOMATO, true))
	elif not r.inspect.is_empty(): v.add_child(Kit.label("Hygiene inspection: rated %s." % Hygiene.rating_text(), 17, Kit.CHEESE if r.inspect.rating < 4 else Kit.BASIL, true))
	var clean_line := "Kitchen %d%% clean (was %d%%), front of house %d%% (was %d%%)." % [r.boh1, r.boh0, r.foh1, r.foh0]
	if r.mice > 0: clean_line += "  Mice seen: %d." % r.mice
	if r.eighty6.size() > 0: clean_line += "  86'd: " + ", ".join(r.eighty6) + "."
	v.add_child(Kit.label(clean_line, 16, Kit.MUTED, true))
	if r.notes.size() > 0: v.add_child(Kit.label("\n".join(r.notes.slice(max(0, r.notes.size() - 4))), 14, Kit.MUTED, true))
	if r.food > 0:
		var over: float = r.cost_used - r.cost_spec
		var pct: float = r.cost_used / r.food * 100.0
		var line := "Food cost was %d%% of sales. " % pct
		if over > r.cost_spec * 0.05: line += "Heavy hands used %s more than the recipe cards allow." % Kit.cents(over)
		elif over < -r.cost_spec * 0.08: line += "Portions ran %s under the recipe cards: customers notice." % Kit.cents(-over)
		else: line += "Portions were on the recipe cards."
		v.add_child(Kit.label(line, 18, Kit.CHEESE if over > r.cost_spec * 0.05 else Kit.MUTED, true))
	if r.best != "": v.add_child(Kit.label("Best review   " + r.best, 17, Kit.BASIL, true))
	if r.worst != "": v.add_child(Kit.label("Worst review   " + r.worst, 17, Kit.TOMATO, true))
	if r.ups > 0:
		var ups := []
		for l in range(r.lvl0 + 1, r.level + 1): ups.append_array(Game.unlocks_at(l))
		v.add_child(Kit.label("Level %d!  %s" % [r.level, ("New: " + ", ".join(ups)) if ups.size() > 0 else ""], 19, Kit.CHEESE, true))
		Art.sfx("up")
	v.add_child(Kit.label("It is evening. Make tomorrow's dough and place tomorrow's orders before you lock up.", 17, Kit.MUTED, true))
	v.add_child(Kit.button("Evening jobs", Kit.main.close_modal))
	Kit.main.modal(v, 900)

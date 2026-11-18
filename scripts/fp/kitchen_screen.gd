class_name KitchenScreen
extends Control
## Between services, in 3D: the morning before you open and the evening after you close, in the same first-person
## kitchen (FPWorld with no service running). Every job is something in the room you walk up to and tap:
##
##   the crates by the back door      put the delivery away by hand (ShelfTask)
##   the tubs on the prep counter     the next thing on the prep list, by hand (PrepTask)
##   the sink                         wash the dirty tubs
##   the pans on the rail             set up the counter / refill a pan from the tubs
##   the mixer or bowl                make dough (DoughGame)
##   the proving trays                how much dough is ready (the Dough page)
##   the mop and bucket               clean the kitchen by hand (CleanTask)
##   the spray by the hatch           clean the hatch or the dining room (CleanTask)
##   the box of traps                 lay and reset traps on the floor plan (TrapTask)
##   the pizza boxes on the shelf     fold boxes (FoldTask)
##   the fridge thermometer           write the temperature in the log
##   the fridge, the dry store        the Stores page: stock, vents, rotation
##   the clipboard                    the checklist (the Jobs page)
##   the sign at the hatch            open for service in the morning; lock up and go home in the evening
##   the oven                         the Kitchen page (ovens and equipment)
##
## Everything else (ordering, KitBox, the menu, staff, premises) is on your phone: the Phone button opens the same
## management screens as the classic layout (Hub), in a phone held in front of you.

const PHONE_TABS := ["suppliers", "kit", "stores", "menu", "boh", "foh", "staff", "property"]

var fp: FPView
var world: FPWorld
var hub: Hub
var phone: Control
var top_l: Label
var cash_l: Label
var act_btn: Button
var phone_btn: Button
var list_box: VBoxContainer
var list_panel: PanelContainer
var tab_btns := {}
var start_tab := ""
var sig := ""
var t_ui := 0.0

func _init(tab: String = "") -> void:
	start_tab = tab
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

func _ready() -> void:
	_build()
	if PHONE_TABS.has(start_tab): open_phone(start_tab)
	elif start_tab == "dough": world.goto("prep")

## the world is rebuilt when the premises or the big kit change (a new oven, a bigger counter, more tables)
func _sig() -> String:
	return "%d/%d/%d/%d/%d/%s" % [int(Game.s.venue), int(Game.s.upg.oven), int(Game.s.upg.prep), Game.calc_tables(), int(Game.s.upg.mixer), str(Stock.store_cap("freezer") > 0)]

func _build() -> void:
	Kit.clear(self)
	sig = _sig()
	var col := Kit.vbox(4)
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(col)
	# the strip along the top: the time, the day, your money, the phone and what to do next
	var top := Kit.hbox(10)
	col.add_child(top)
	top_l = Kit.label("", 20)
	top_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_l.clip_text = true
	top.add_child(top_l)
	cash_l = Kit.label("", 24, Kit.CHEESE)
	top.add_child(cash_l)
	phone_btn = Kit.button("Phone", func(): open_phone("home"), "primary", 20)
	top.add_child(phone_btn)
	act_btn = Kit.button("", func(): job("open", {}), "danger", 20)
	top.add_child(act_btn)
	var stack := Control.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(stack)
	fp = FPView.new(null, {}, self)
	fp.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(fp)
	world = fp.world
	# where to look
	var tabs := Kit.hbox(6)
	tabs.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	tabs.offset_top = -58
	tabs.offset_left = 8
	for k in [["front", "Hatch" if Game.calc_tables() == 0 else "Pass"], ["bench", "Counter"], ["oven", "Oven"], ["prep", "Prep"], ["stores", "Stores"]]:
		var b := Kit.button(k[1], world.goto.bind(k[0]), "tab", 18)
		b.custom_minimum_size = Vector2(100, 50)
		tabs.add_child(b)
		tab_btns[k[0]] = b
	var cl := Kit.button("Checklist", func(): list_panel.visible = not list_panel.visible, "ghost", 16)
	cl.custom_minimum_size = Vector2(100, 50)
	tabs.add_child(cl)
	stack.add_child(tabs)
	# what is still to do today, in the corner
	list_panel = Kit.panel(Color(0.1, 0.14, 0.11, 0.82), 10)
	list_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	list_panel.offset_left = 8
	list_panel.offset_top = 8
	list_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list_box = Kit.vbox(2)
	list_panel.add_child(list_box)
	stack.add_child(list_panel)
	# the phone: the management screens, held in front of you
	phone = Control.new()
	phone.set_anchors_preset(Control.PRESET_FULL_RECT)
	phone.visible = false
	add_child(phone)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	phone.add_child(dim)
	var bezel := Kit.panel(Color("111111"), 14, 28)
	bezel.set_anchors_preset(Control.PRESET_FULL_RECT)
	bezel.offset_left = 26
	bezel.offset_right = -26
	bezel.offset_top = 10
	bezel.offset_bottom = -10
	phone.add_child(bezel)
	var pv := Kit.vbox(6)
	bezel.add_child(pv)
	var ph := Kit.hbox(8)
	ph.add_child(Kit.label("Phone", 16, Kit.MUTED))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ph.add_child(sp)
	ph.add_child(Kit.button("Put the phone away", close_phone, "ghost", 16))
	pv.add_child(ph)
	var screen := Kit.panel(Kit.BG, 8, 16)
	screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pv.add_child(screen)
	hub = Hub.new()
	hub.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen.add_child(hub)
	_refresh()

func open_phone(tab: String) -> void:
	phone.visible = true
	hub.go(tab)

func close_phone() -> void:
	phone.visible = false

func _process(dt: float) -> void:
	t_ui -= dt
	if t_ui > 0.0: return
	t_ui = 0.3
	if _sig() != sig:
		var was := world.cur_view()
		_build()
		world.goto(was)
		return
	_refresh()

func _refresh() -> void:
	var G := Game
	var morning: bool = G.s.phase == "morning"
	var late: bool = morning and Day.now() > Day.open_time()
	top_l.text = "%s  ·  %s%s  ·  %s  ·  Level %d" % [Story.EMPLOYER if Story.employed() else G.venue().name, Data.hhmm(Day.now()), ("  (opens %s)" % Data.hhmm(Day.open_time())) if morning else "  ·  evening", "%s day %d" % [Data.DAY_SHORT[G.weekday()], G.s.day], G.s.level]
	top_l.add_theme_color_override("font_color", Kit.TOMATO if late else Kit.INK)
	cash_l.text = ("Savings " + Kit.money(G.s.story.savings)) if Story.employed() else Kit.money(G.s.cash)
	if G.s.hygiene.get("closed_day", -1) == G.s.day and morning: act_btn.text = "Closed today"
	elif morning: act_btn.text = ("Start service " if Story.employed() else "Open at ") + Data.hhmm(max(Day.now(), Day.open_time()))
	else: act_btn.text = "Clock off" if Story.employed() else "Lock up & go home"
	for k in tab_btns:
		var on: bool = world.cur_view() == k
		tab_btns[k].add_theme_stylebox_override("normal", Kit.box(Kit.PANEL2 if on else Kit.PANEL, 10, 8))
		tab_btns[k].add_theme_color_override("font_color", Kit.INK if on else Kit.MUTED)
	Kit.clear(list_box)
	var items := Checks.items("open" if morning else "close")
	list_box.add_child(Kit.label(("Before you open" if morning else "Before you go home") + " (%d/%d)" % [items.filter(func(x): return x.done).size(), items.size()], 16, Kit.CHEESE))
	for it in items:
		if it.done: continue
		list_box.add_child(Kit.label("·  " + it.text, 14, Kit.INK))

## something in the kitchen was tapped
func job(name: String, act: Dictionary) -> void:
	if phone.visible: return
	var G := Game
	var morning: bool = G.s.phase == "morning"
	match name:
		"open" when Tutor.running() and not Tutor.training_service():
			Kit.main.toast("Not yet: %s has more to show you" % Story.BOSS)
		"open":
			if G.s.hygiene.get("closed_day", -1) == G.s.day and morning: hub._closed_day()
			elif morning: hub._open()
			else: hub._sleep()
		"crates":
			if G.s.dock.is_empty():
				Kit.main.toast("Nothing at the back door")
				return
			var e: Dictionary = G.s.dock[0]
			var t := ShelfTask.new(e)
			Kit.main.modal(t, 900)
		"prep":
			for row in Day.prep_list(G.s.day if morning else G.s.day + 1):
				if row.raw > 0 and row.get("block", "") == "":
					Kit.main.modal(PrepTask.new(row.id, row.raw), 900)
					return
			for row in Day.prep_list():
				if row.get("block", "") != "":
					Kit.main.toast(row.block, true)
					return
			Kit.main.toast("Nothing left on the prep list")
		"wash":
			var n := Stock.dirty_tubs()
			if n == 0:
				Kit.main.toast("The sink is empty")
				return
			_spend(Stock.wash_minutes(), "Washed %d tubs" % n, func(): Stock.wash_all())
		"pan":                  # setting up the counter: every pan that can be filled from the tubs or the stores is
			var res := Day.set_up_counter()
			if res.missing.size() > 0: Kit.main.toast("No room on the rail for " + ", ".join(res.missing.map(func(x): return Data.ING[x].name.to_lower())), true)
			if res.filled > 0:
				_spend(res.minutes, "Counter set up: %d pan%s filled" % [res.filled, "" if res.filled == 1 else "s"], Callable())
				return
			var i: int = int(act.get("i", -1))
			var pan: Dictionary = Stock.rail()[i] if i >= 0 and i < Stock.rail().size() else {}
			if pan.is_empty() or pan.ing == "": Kit.main.toast("That pan is not used tonight")
			elif Stock.refill_source(pan.ing) <= 0.5: Kit.main.toast(("Prep some %s first (the tubs on the prep counter)" % Data.ING[pan.ing].name.to_lower()) if Data.needs_prep(pan.ing) else ("No %s in stock" % Data.ING[pan.ing].name.to_lower()), true)
			else: Kit.main.toast("The %s pan is full" % Data.ING[pan.ing].name.to_lower())
		"dough":
			if not Equip.can_mix():
				Kit.main.toast("You need a mixing bowl. Order one from %s." % Equip.SHOP.name, true)
				return
			if Equip.dough_room() <= 0:
				Kit.main.toast("The proving trays are full. Order more from %s." % Equip.SHOP.name, true)
				return
			var plan := G.dough_plan()
			var style := ""
			for st in plan:
				if int(plan[st]) > 0 and (style == "" or int(plan[st]) > int(plan[style])): style = st
			if style == "":
				var ds := G.menu_doughs(G.menu_on(G.s.day + 1))
				style = ds[0] if ds.size() > 0 else "neapolitan"
			if not DoughGame.can_batch(Data.DOUGHS[style], 0.5):
				Kit.main.toast("Not enough flour for %s dough" % Data.DOUGHS[style].name, true)
				return
			Kit.main.modal(DoughGame.new(style), 1040)
		"dough_trays": open_phone("dough")
		"clean_boh": Kit.main.modal(CleanTask.new("boh"), 900)
		"clean_foh", "table": Kit.main.modal(CleanTask.new("foh"), 900)
		"traps": Kit.main.modal(TrapTask.new(), 900)
		"boxes": Kit.main.modal(FoldTask.new(), 900)
		"temp_fridge", "temp_freezer":
			var st := "fridge" if name == "temp_fridge" else "freezer"
			if Story.role() == "pizzaiolo":
				Kit.main.toast("%s keeps the temperature log" % Story.BOSS)
				return
			if not Equip.thermo_for(st):
				Kit.main.toast("There is no thermometer in the %s. Order one from %s." % [st, Equip.SHOP.name], true)
				return
			if Checks.logged(st):
				Kit.main.toast("Already logged: %.1f °C" % Checks.temp_of(st))
				return
			var tv := Checks.record(st)
			_spend(1, "%s: %.1f °C written in the log%s" % [Data.STORE_NAME[st], tv, "" if st == "freezer" or (tv >= 1.0 and tv <= 5.0) else ". OUT OF RANGE: adjust the vents"], Callable())
		"stores", "dry":
			if Story.role() == "pizzaiolo": Kit.main.toast("%s looks after the stores" % Story.BOSS)
			else: open_phone("stores")
		"checklist": open_phone("jobs")
		"oven": _oven_job()
		"ladle": Kit.main.toast("Ladles hang here ready for service")

## the oven: a wood oven is lit in the morning, about two hours before opening, and is then kept going; other ovens
## open the back-of-house page
func _oven_job() -> void:
	var G := Game
	if not Data.OVENS[G.tier("oven").type].feeds:
		if Story.role() == "pizzaiolo": Kit.main.toast("%s's oven. Keep it clean." % Story.BOSS)
		else: open_phone("boh")
		return
	if Story.role() == "pizzaiolo":
		Kit.main.toast("%s lit the oven at dawn. You will feed it during service." % Story.BOSS)
		return
	var L: Dictionary = G.s.get("oven_lit", {})
	if G.s.phase != "morning":
		Kit.main.toast("The fire is dying down for the night")
		return
	if int(L.get("day", -1)) == G.s.day:
		var m := float(G.s.clock) - float(L.at)
		Kit.main.toast("The oven is at about %d °C (lit at %s). It wants 450 °C by opening: about two hours from lighting." % [Oven.warm_dome(m), Data.hhmm(int(L.at))])
		return
	if Stock.have("wood") < 3.0:
		Kit.main.toast("You need at least 3 logs to light it, and you have %d. Order firewood." % int(Stock.have("wood")), true)
		return
	var lg := Stock.take("wood", 3.0)
	_spend(10, "You lay kindling and three logs in the oven and light them. It takes about two hours to come up to heat; it is kept fed until you open.", func():
		G.s.oven_lit = {"day": G.s.day, "at": G.s.clock, "g": lg.g})
func _spend(minutes: float, done_text: String, fn: Callable) -> void:
	if fn.is_valid(): fn.call()
	var notes := Day.spend(minutes)
	Game.save_game()
	if notes.size() > 0: Kit.main.message("Meanwhile", "\n".join(notes), "OK")
	elif done_text != "": Kit.main.toast(done_text)

# ---------- the same calls the classic hub answers (the game and its tests use them) ----------
func _open() -> void: hub._open()
func _go_open() -> void: hub._go_open()
func _sleep() -> void: hub._sleep()
func _do_sleep() -> void: hub._do_sleep()
func _closed_day() -> void: hub._closed_day()
func render() -> void: hub.render()
func go(t: String) -> void: open_phone(t)

class_name ShelfTask
extends VBoxContainer
## Putting a delivery away by hand, line by line. Each line shows what is already on that shelf, front to back,
## with day-dot labels and use-by dates. Put the new stock behind the old (rotating, which takes longer) or stack
## it in front (quick, but the old stock then sits at the back and goes off).

signal finished

var entry: Dictionary
var i := 0
var choices := []
var body: VBoxContainer

func _init(e: Dictionary) -> void:
	entry = e
	add_theme_constant_override("separation", 10)

func _ready() -> void:
	add_child(Kit.label("Put away: %s" % Data.SUP[entry.sup].name, 26))
	body = Kit.vbox(8)
	add_child(body)
	_show()

func _box(text: String, col: Color, fg: Color = Kit.DARK) -> Control:
	var p := Kit.panel(col, 6, 6)
	p.custom_minimum_size = Vector2(118, 64)
	p.add_child(Kit.label(text, 13, fg, true))
	return p

func _show() -> void:
	Kit.clear(body)
	if i >= entry.lines.size():
		_finish()
		return
	var ln: Dictionary = entry.lines[i]
	var it: Dictionary = Data.ING[ln.ing]
	body.add_child(Kit.label("%d of %d: %s %s  ->  %s" % [i + 1, entry.lines.size(), ln.what, ln.name, Data.STORE_NAME[it.store].to_lower()], 19))
	var shelf := Kit.hbox(6)
	shelf.add_child(Kit.label("FRONT", 13, Kit.MUTED))
	var lots: Array = Stock.lots(ln.ing)
	if lots.is_empty(): shelf.add_child(Kit.label("(the shelf is empty)", 15, Kit.MUTED))
	for l in lots.slice(0, 6):
		var days: int = int(floor(l.x - Game.s.day))
		shelf.add_child(_box("%s\n%s" % [Data.qty(ln.ing, l.q), "use today" if days <= 1 else ("%d days" % days if days < 900 else "keeps")], Kit.CHEESE if days <= 2 else Kit.INK))
	shelf.add_child(Kit.label("BACK", 13, Kit.MUTED))
	body.add_child(shelf)
	body.add_child(Kit.label("New: %s, keeps %d days. The old stock should come forward and the new go behind it." % [Data.qty(ln.ing, ln.q), ln.life], 15, Kit.MUTED, true))
	var h := Kit.hbox(10)
	var kg: float = Stock._kg(ln.ing, ln.q)
	h.add_child(Kit.button("Behind the old stock · %d min" % ceil(1.5 + kg * 0.45), func():
		choices.append(true)
		i += 1
		_show(), "primary"))
	h.add_child(Kit.button("Stack in front · %d min" % ceil(1.5 + kg * 0.12), func():
		choices.append(false)
		i += 1
		_show(), "ghost"))
	h.add_child(Kit.button("Rotate the rest", func():
		while choices.size() < entry.lines.size(): choices.append(true)
		i = entry.lines.size()
		_show(), "ghost"))
	body.add_child(h)

func _finish() -> void:
	var res := Stock.put_away_each(entry, choices, Day.now())
	var notes := Day.spend(res.minutes)
	Game.save_game()
	Kit.clear(body)
	var front := choices.count(false)
	body.add_child(Kit.label("Put away in %d minutes; it is now %s." % [res.minutes, Data.hhmm(Day.now())], 20))
	if front > 0: body.add_child(Kit.label("%d line%s stacked in front of older stock. Rotate it before the old stock goes off." % [front, "" if front == 1 else "s"], 16, Kit.CHEESE, true))
	var txt := Day._waste_text(res)
	if txt != "": body.add_child(Kit.label(txt.strip_edges(), 16, Kit.TOMATO, true))
	if notes.size() > 0: body.add_child(Kit.label("\n".join(notes), 15, Kit.CHEESE, true))
	body.add_child(Kit.button("Done", func():
		Kit.main.close_modal()
		finished.emit()))

class_name Kit
## Small UI toolkit: colours, text helpers and styled controls, so every screen looks consistent.
## Restyling the game = changing this file (or replacing these with a Godot Theme resource).

const BG := Color("1c2a22")
const PANEL := Color("26382d")
const PANEL2 := Color("304638")
const LINE := Color("3d5646")
const INK := Color("f7eed9")
const MUTED := Color("b3c2b0")
const CHEESE := Color("f4c64f")
const TOMATO := Color("e2553c")
const BASIL := Color("74c47a")
const DARK := Color("1b2a1f")

static var main  # the Main node (screen switching, modal, toast)

static func money(n: float) -> String:
	var v := int(round(abs(n)))
	var t := str(v)
	var out := ""
	while t.length() > 3:
		out = "," + t.substr(t.length() - 3) + out
		t = t.substr(0, t.length() - 3)
	return ("-$" if n < 0 else "$") + t + out

static func cents(n: float) -> String:
	return "$%.2f" % n

static func box(col: Color, radius: int = 12, pad: int = 10, border: Color = Color(0, 0, 0, 0), bw: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	return sb

static func label(text: String, size: int = 20, col: Color = INK, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size.x = 60
	return l

## kind: primary / ghost / danger / tab / tab_on
static func button(text: String, cb: Callable, kind: String = "primary", size: int = 20) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	var bg := CHEESE
	var fg := DARK
	match kind:
		"ghost": bg = PANEL2; fg = INK
		"danger": bg = TOMATO; fg = Color.WHITE
		"tab": bg = Color(0, 0, 0, 0); fg = MUTED
		"tab_on": bg = PANEL; fg = INK
	b.add_theme_stylebox_override("normal", box(bg, 10, 8))
	b.add_theme_stylebox_override("hover", box(bg.lightened(0.06), 10, 8))
	b.add_theme_stylebox_override("pressed", box(bg.darkened(0.15), 10, 8))
	b.add_theme_stylebox_override("disabled", box(Color(bg, 0.35), 10, 8))
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(st, fg)
	b.add_theme_color_override("font_disabled_color", Color(fg, 0.5))
	if cb.is_valid():
		b.pressed.connect(cb)
	return b

static func panel(col: Color = PANEL, pad: int = 12, radius: int = 14) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(col, radius, pad))
	return p

static func hbox(sep: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func vbox(sep: int = 6) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func grid(cols: int, sep: int = 10) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", sep)
	g.add_theme_constant_override("v_separation", sep)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return g

## a card: returns the VBox to fill; add card.get_parent() ... simpler: returns [panel, vbox]
static func card(title: String = "", col: Color = PANEL) -> Array:
	var p := panel(col)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := vbox(6)
	p.add_child(v)
	if title != "":
		v.add_child(label(title, 22))
	return [p, v]

static func chip(text: String, col: Color = PANEL, fg: Color = INK, size: int = 18) -> PanelContainer:
	var p := panel(col, 6, 16)
	var sb: StyleBoxFlat = p.get_theme_stylebox("panel")
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	p.add_child(label(text, size, fg))
	return p

static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c

static func bar(value: float, col: Color = CHEESE, h: int = 10) -> ProgressBar:
	var b := ProgressBar.new()
	b.min_value = 0
	b.max_value = 1
	b.value = clamp(value, 0, 1)
	b.show_percentage = false
	b.custom_minimum_size = Vector2(60, h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_stylebox_override("background", box(BG, 6, 0))
	b.add_theme_stylebox_override("fill", box(col, 6, 0))
	return b

## placeholder icon for an ingredient: a coloured dot (or its sprite if artwork exists)
static func swatch(id: String, px: int = 22) -> Control:
	var t = Art.tex("icon." + id)
	if t != null:
		var tr := TextureRect.new()
		tr.texture = t
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.custom_minimum_size = Vector2(px, px)
		return tr
	var p := Panel.new()
	p.custom_minimum_size = Vector2(px, px)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_theme_stylebox_override("panel", box(Color(Data.ING[id].col), px / 2, 0, Color(0, 0, 0, 0.35), 2))
	return p

static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()

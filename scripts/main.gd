extends Control
## Root of the game. Owns the current screen (hub or service), the modal layer and the toast.

var content: MarginContainer
var modal_root: Control
var pad := false                       # a game controller has been used: dialogs give their main button the focus
var vr: VRView = null                  # the phone in a VR viewer (Settings > Controls > VR viewer)
var pad_ui: PadUI                      # a game controller on the 2D screens (rings, clicks, drags)
var ar: ARMode = null                  # AR on an Android phone (Settings > Controls > AR)
var modal_center: CenterContainer
var toast_box: PanelContainer
var toast_label: Label
var toast_t := 0.0

func _ready() -> void:
	Kit.main = self
	add_child(PerfOverlay.new())          # (shown when "Show performance" is on in Settings)
	pad_ui = PadUI.new()
	add_child(pad_ui)
	var bg := ColorRect.new()
	bg.color = Kit.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	content = MarginContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right"]: content.add_theme_constant_override(m, 28)
	for m in ["margin_top", "margin_bottom"]: content.add_theme_constant_override(m, 12)
	add_child(content)

	modal_root = Control.new()
	modal_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_root.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.06, 0.05, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_root.add_child(dim)
	modal_center = CenterContainer.new()
	modal_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_root.add_child(modal_center)
	add_child(modal_root)

	toast_box = Kit.panel(Kit.INK, 10, 20)
	toast_label = Kit.label("", 20, Kit.DARK)
	toast_box.add_child(toast_label)
	toast_box.visible = false
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_box)
	show_start()                    # the game always opens on the title screen
	if Game.s.get("vr", false): set_vr(true)
	if ARMode.mode() != "off": set_ar(true)

## AR on or off: ARCore tracks the phone (ARMode); asks for ARCore and the camera the first time
func set_ar(on: bool) -> void:
	if on and ar == null:
		ar = ARMode.new()
		add_child(ar)
	elif not on and ar != null:
		ar.close()
		ar.queue_free()
		ar = null

## the phone in a VR viewer, or not: the kitchen drawn for two eyes, the screens on a panel in the room (VRView)
func set_vr(on: bool) -> void:
	if on and vr == null:
		vr = VRView.new()
		add_child(vr)
	elif not on and vr != null:
		vr.close()
		vr.queue_free()
		vr = null

func _process(delta: float) -> void:
	if toast_t > 0:
		toast_t -= delta
		if toast_t <= 0: toast_box.visible = false

## the 3D kitchen runs edge to edge; the screens between services keep a margin
func _margins(full: bool) -> void:
	for m in ["margin_left", "margin_right"]: content.add_theme_constant_override(m, 0 if full else 28)
	for m in ["margin_top", "margin_bottom"]: content.add_theme_constant_override(m, 6 if full else 12)

## between services: the 3D kitchen (KitchenScreen, with the management screens on your phone), or the classic hub
func show_hub(tab: String = "") -> void:
	if Game.s.get("view3d", true):
		_margins(true)
		Kit.clear(content)
		content.add_child(KitchenScreen.new(tab))
		return
	_margins(false)
	Kit.clear(content)
	var hub := Hub.new()
	if tab != "": hub.tab = tab
	content.add_child(hub)

## the title screen: the owner's painting of the van, alive, with the chalkboard menu (TitleScreen)
func show_start() -> void:
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]: content.add_theme_constant_override(m, 0)
	Kit.clear(content)
	content.add_child(TitleScreen.new())

func start_service() -> void:
	_margins(Game.s.get("view3d", true))
	Kit.clear(content)
	content.add_child(ServiceScreen.new())

func screen() -> Node:
	return content.get_child(0) if content.get_child_count() > 0 else null

## show any control in a centred sheet
func modal(node: Control, width: int = 760) -> void:
	Kit.clear(modal_center)
	var p := Kit.panel(Kit.PANEL, 22, 18)
	p.custom_minimum_size.x = width
	p.add_child(node)
	modal_center.add_child(p)
	modal_root.visible = true
	if pad or not Input.get_connected_joypads().is_empty(): _pad_focus.call_deferred(p)

## the control on the game's screens at p (in the screens' own pixels) that would take a finger there, or null:
## Marco's guide on top, then a dialog, then the screen (the phone, a sheet, a button). The 3D view counts too (the
## caller tells it apart). For a game controller's hands and the VR panel: they work the screens wherever a finger would.
func ui_at(p: Vector2) -> Control:
	for r in [get_node_or_null("/root/Tutor"), modal_root, content]:
		if r == null: continue
		var c := _hit(r, p)
		if c != null: return c
	return null

func _hit(n: Node, p: Vector2) -> Control:
	if n is CanvasItem and not n.visible: return null
	for i in range(n.get_child_count() - 1, -1, -1):
		var ch := n.get_child(i)
		if ch is Viewport: continue                 # another viewport's controls are not on these screens
		var c := _hit(ch, p)
		if c != null: return c
	if n is Control and n.mouse_filter == Control.MOUSE_FILTER_STOP and n.get_global_rect().has_point(p): return n
	return null

## with a game controller, the dialog's main button (the last one) has the focus: A presses it, the d-pad moves on
func _pad_focus(p: Control) -> void:
	if not is_instance_valid(p): return
	var ring := StyleBoxFlat.new()                 # the focused button wears a gold ring
	ring.draw_center = false
	ring.set_border_width_all(4)
	ring.border_color = Kit.CHEESE
	ring.set_corner_radius_all(12)
	ring.set_expand_margin_all(3)
	var bs := p.find_children("*", "Button", true, false)
	for b in bs:
		b.focus_mode = Control.FOCUS_ALL
		b.add_theme_stylebox_override("focus", ring)
	if not bs.is_empty(): bs[-1].grab_focus()

func close_modal() -> void:
	modal_root.visible = false
	Kit.clear(modal_center)

func message(title: String, body: String, ok: String = "OK", cb: Callable = Callable()) -> void:
	var v := Kit.vbox(12)
	v.add_child(Kit.label(title, 28))
	v.add_child(Kit.label(body, 20, Kit.MUTED, true))
	v.add_child(Kit.button(ok, func():
		close_modal()
		if cb.is_valid(): cb.call()))
	modal(v, 640)

func confirm(title: String, body: String, yes: String, cb: Callable) -> void:
	var v := Kit.vbox(12)
	v.add_child(Kit.label(title, 28))
	v.add_child(Kit.label(body, 20, Kit.MUTED, true))
	var h := Kit.hbox(10)
	h.alignment = BoxContainer.ALIGNMENT_END
	h.add_child(Kit.button("Cancel", close_modal, "ghost"))
	h.add_child(Kit.button(yes, func():
		close_modal()
		cb.call()))
	v.add_child(h)
	modal(v, 640)

func toast(msg: String, bad: bool = false) -> void:
	toast_label.text = msg
	toast_label.add_theme_color_override("font_color", Color.WHITE if bad else Kit.DARK)
	toast_box.add_theme_stylebox_override("panel", Kit.box(Kit.TOMATO if bad else Kit.INK, 20, 10))
	toast_box.visible = true
	toast_box.reset_size()
	await get_tree().process_frame
	toast_box.position = Vector2((size.x - toast_box.size.x) / 2.0, size.y - toast_box.size.y - 24)
	toast_t = 2.4

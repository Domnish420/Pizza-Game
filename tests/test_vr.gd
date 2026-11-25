extends "res://tests/bot.gd"
## Phone VR (a Cardboard-style viewer), with a stand-in for the phone's sensors: the kitchen drawn for two eyes side
## by side; the game's screens on a panel in the room; the head turning the view at once (tilt included), turning to a
## station puts you there; the game moving you on does not turn you round, but Start and the shoulder buttons do; the
## controller's hands and the viewer's button work; leaving VR puts the screen back.

var VR                                   # the VRView script, loaded once the game's autoloads are up

## the headset turned to (yaw, pitch, roll) in degrees
func head(yaw: float, pitch: float = 0.0, roll: float = 0.0) -> void:
	VR.head_test = Basis.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(yaw), deg_to_rad(roll)))

## where you are looking, round the room (degrees)
func looking(w) -> float:
	return w.t_yaw + w.gyro.x

func near(a: float, b: float) -> bool:
	return absf(angle_difference(deg_to_rad(a), deg_to_rad(b))) < 0.02

func run() -> void:
	G.new_game()
	VR = load("res://scripts/fp/vr_view.gd")
	head(0.0)
	await open_game()
	m.show_hub("home")
	await frames(10)
	G.s.vr = true
	m.set_vr(true)
	await frames(10)
	var k = m.screen()
	var w = k.world
	var vr = m.vr
	check(VR.active and vr.eyes.size() == 2 and vr.eyes[0].vp.world_3d == w.get_world_3d(), "VR on: two eyes, both looking into the kitchen", vr.eyes.size())
	var gap: float = vr.eyes[0].cam.global_position.distance_to(vr.eyes[1].cam.global_position)
	check(absf(gap - VR.IPD) < 0.001, "the eyes are an eye's width apart", snappedf(gap, 0.001))
	check(m.content.get_viewport() == vr.ui_vp and not k.fp.visible, "the game's screens are drawn for the panel; the flat view is off", m.content.get_viewport())
	check(vr.panel != null and vr.panel.get_parent() == w and vr.panel.material_override.albedo_texture == vr.ui_vp.get_texture(), "the panel floats in the kitchen, showing the game's screens", vr.panel.get_parent())
	await shot("kitchen-vr")

	# the controller's hand on the panel: the Phone button
	w.pad_test = {"r": Vector2(0.5, 0.0)}
	await frames(2)
	w.pad_test = {"r": Vector2.ZERO}
	await wait(0.4)
	var pr: Rect2 = k.phone_btn.get_global_rect()
	var pq: Vector2 = vr.panel.mesh.size
	var puv: Vector2 = pr.get_center() / Vector2(vr.ui_vp.size)
	w.pad_at[0] = w.cam.unproject_position(vr.panel.global_transform * Vector3((puv.x - 0.5) * pq.x, (0.5 - puv.y) * pq.y, 0.0))
	await frames(3)
	check(w.pad_over[0] != null and pr.has_point(w.pad_over[0].px), "the controller's hand pointing at the panel: its ring is on the Phone button", w.pad_over[0])
	w.pad_test = {"rt": 1.0}
	await frames(3)
	w.pad_test = {"r": Vector2.ZERO}
	await frames(3)
	check(k.phone.visible, "and the trigger opens the phone, in VR", k.phone.visible)
	await shot("phone-vr")
	k.close_phone()
	w.pad_test = null
	await frames(2)

	# the head turns the view at once
	w.goto("front")
	await frames(3)
	var y0: float = w.head.rotation_degrees.y
	head(-30.0, -10.0, 8.0)
	await frames(1)
	var turned: float = angle_difference(deg_to_rad(y0), w.head.rotation.y)
	check(absf(rad_to_deg(turned) + 30.0) < 1.0 and absf(w.cam.rotation_degrees.x + 10.0) < 1.0 and absf(w.cam.rotation_degrees.z - 8.0) < 1.0,
		"turning, nodding and tilting your head moves the view straight away", [snappedf(rad_to_deg(turned), 0.1), snappedf(w.cam.rotation_degrees.x, 0.1), snappedf(w.cam.rotation_degrees.z, 0.1)])
	# turn to the oven
	var ov: Vector2 = w.STATIONS.oven
	head(ov.x - w.t_yaw, ov.y)
	await until(func(): return w.cur_view() == "oven", 2.0)
	check(w.cur_view() == "oven", "turn your head to the oven and you are at the oven", w.cur_view())
	await shot("oven-vr")
	# the game moving you on does not swing you round; the shoulder buttons and Start do
	var ty: float = w.t_yaw
	w.goto("prep")
	await frames(3)
	check(is_equal_approx(w.t_yaw, ty), "the game moving you to the prep table does not turn you round", [ty, w.t_yaw])
	w.goto("oven")
	await frames(3)
	w.pad_test = {"rb": true}
	await frames(2)
	w.pad_test = {}
	await frames(2)
	var stv: Vector2 = w.STATIONS.stores
	check(w.cur_view() == "stores" and near(looking(w), stv.x), "the right shoulder turns you round to the next station (the stores)", [w.cur_view(), snappedf(looking(w), 0.1), stv.x])
	head(w.gyro.x + 12.0, w.gyro.y)                    # look a little off it
	await frames(3)
	w.pad_test = {"start": true}
	await frames(2)
	w.pad_test = {}
	await frames(2)
	check(w.cur_view() == "stores" and near(looking(w), stv.x), "Start: where you look now becomes your station again", [snappedf(looking(w), 0.1), stv.x])

	# service
	for row in Dy.prep_list(): Dy.do_prep(row.id, row.raw)
	Dy.set_up_counter()
	k._go_open()
	await frames(5)
	m.close_modal()
	await frames(5)
	var svc = m.screen()
	svc.speed = 0
	w = svc.fp.world
	await frames(3)
	check(vr.eyes[0].vp.world_3d == w.get_world_3d() and vr.panel.get_parent() == w and not svc.fp.visible, "into service: the eyes and the panel move with you", vr.panel.get_parent())
	svc.training_order("margherita")
	svc.claim(svc.tickets[-1])
	var bn: Vector2 = w.STATIONS.bench
	head(bn.x - w.t_yaw, bn.y)
	await until(func(): return svc.view == "bench", 2.0)
	check(svc.view == "bench", "look down at the bench and you are at the bench", svc.view)
	await shot("bench-vr")
	# the viewer's button: the right hand at the middle of your view
	var e := InputEventScreenTouch.new()
	e.pressed = true
	e.position = Vector2(640, 360)
	vr._input(e)
	await frames(2)
	check(w.ptr.has(w.PAD) and w.ptr[w.PAD].kind == "surface", "the viewer's button puts your right hand down where you look", w.ptr.get(w.PAD, {}).get("kind", ""))
	e = e.duplicate()
	e.pressed = false
	vr._input(e)
	await frames(2)
	# a dialog shows on the panel, and the viewer's button answers it
	var answered := [false]
	m.confirm("Test", "A dialog in VR.", "Yes", func(): answered[0] = true)
	await wait(0.8)
	var to_panel: Vector3 = (vr.panel.global_position - w.cam.global_position).normalized()
	check(to_panel.dot(-w.cam.global_transform.basis.z) > 0.97, "a dialog comes to where you are looking (down at the bench)", snappedf(to_panel.dot(-w.cam.global_transform.basis.z), 0.01))
	await shot("dialog-vr")
	e = e.duplicate()
	e.pressed = true
	vr._input(e)
	await frames(2)
	check(answered[0] and not m.modal_root.visible, "the viewer's button presses the dialog's main button", answered[0])
	e = e.duplicate()
	e.pressed = false
	vr._input(e)

	# out of VR
	G.s.vr = false
	m.set_vr(false)
	await frames(5)
	check(not VR.active and m.content.get_parent() == m and svc.fp.visible and m.vr == null, "VR off: the game is on the screen again", [VR.active, m.content.get_parent(), svc.fp.visible, m.vr])
	await shot("after-vr")

	# the title in VR: the screens on the panel in a quiet dark room
	G.s.vr = true
	m.set_vr(true)
	m.show_start()
	await wait(1.0)
	vr = m.vr
	check(vr.world() == null and vr.eyes[0].vp.world_3d == vr.void_root.get_world_3d() and vr.panel.get_parent() == vr.void_root, "the title screen in VR: on the panel, in a quiet room", vr.panel.get_parent())
	# look at "New game" on the panel and press the viewer's button
	var ng = null
	for b in m.content.find_children("*", "BaseButton", true, false):
		if b is Button and b.text.begins_with("New game"): ng = b
	var r: Rect2 = ng.get_global_rect()
	var q: Vector2 = vr.panel.mesh.size
	var uv: Vector2 = r.get_center() / Vector2(vr.ui_vp.size)
	for aim in 3:                                       # aim, and again once the panel has settled
		var spot: Vector3 = vr.panel.global_transform * Vector3((uv.x - 0.5) * q.x, (0.5 - uv.y) * q.y, 0.0)
		var dv: Vector3 = spot - vr.base_t.origin
		head(rad_to_deg(atan2(-dv.x, -dv.z)), rad_to_deg(atan2(dv.y, Vector2(dv.x, dv.z).length())))
		await wait(0.4)
	check(vr.gaze_px != null and vr.cursor.visible and r.has_point(vr.gaze_px), "a dot shows where you look on the panel", [vr.gaze_px, r])
	await shot("title-gaze")
	e = InputEventScreenTouch.new()
	e.pressed = true
	vr._input(e)
	e = e.duplicate()
	e.pressed = false
	vr._input(e)
	await frames(10)
	var story := false
	for b in m.content.find_children("*", "BaseButton", true, false):
		if b is Button and b.text.begins_with("Story"): story = true
	check(story, "the viewer's button clicks it: the New game page opens", story)
	await shot("title-new-game")
	G.s.vr = false
	m.set_vr(false)
	VR.head_test = null

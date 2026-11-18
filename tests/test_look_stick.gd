extends "res://tests/bot.gd"
## The look stick turns your head and settles on a station when you let go, a tap looks back at your station, and
## the clock opens the van in the morning and asks before closing early in service.

func push(stk: Control, v: Vector2, secs: float) -> void:
	var e := click()
	e.position = stk.size / 2.0
	stk._gui_input(e)
	var mv := InputEventMouseMotion.new()
	mv.button_mask = MOUSE_BUTTON_MASK_LEFT
	mv.position = stk.size / 2.0 + v * 50.0
	stk._gui_input(mv)
	await wait(secs)

## hold the stick and steer it each frame until the head points at `target` (yaw, pitch), as a thumb would
func steer(stk: Control, w, target: Vector2) -> void:
	var e := click()
	e.position = stk.size / 2.0
	stk._gui_input(e)
	for i in 600:
		var d := Vector2(rad_to_deg(angle_difference(deg_to_rad(w.t_yaw), deg_to_rad(target.x))), target.y - w.t_pitch)
		if d.length() < 4.0: break
		var mv := InputEventMouseMotion.new()
		mv.button_mask = MOUSE_BUTTON_MASK_LEFT
		mv.position = stk.size / 2.0 + Vector2(-d.x / 120.0, -d.y / 80.0).normalized() * 30.0
		stk._gui_input(mv)
		await process_frame

func release(stk: Control) -> void:
	var e := click()
	e.pressed = false
	e.position = stk.size / 2.0
	stk._gui_input(e)

func on_station(w) -> bool:
	return absf(angle_difference(deg_to_rad(w.yaw), deg_to_rad(w.STATIONS[w.cur_view()].x))) < deg_to_rad(2.0)

func run() -> void:
	G.new_game()
	await open_game()
	m.show_hub("home")
	await frames(10)
	var k = m.screen()
	var w = k.world
	var stk: Control = k.find_children("*", "LookStick", true, false)[0]
	check(k.act_btn.text.ends_with("open at 11:30"), "in the morning the clock says when you open", k.act_btn.text)
	var yaw0: float = w.yaw

	await push(stk, Vector2(1, 0), 0.4)
	check(w.stick.x > 0.9 and absf(w.yaw - yaw0) > 5.0, "pushing the stick right turns the head", [w.stick, int(yaw0), int(w.yaw)])
	await shot("turning")
	release(stk)
	await frames(10)
	check(w.stick == Vector2.ZERO, "let go, the stick springs back", w.stick)

	# steer to the oven and let go: you settle on it
	var oven: Vector2 = w.STATIONS.oven
	await steer(stk, w, oven)
	release(stk)
	await frames(60)
	check(w.cur_view() == "oven" and on_station(w), "let go near a station and you settle on it", [w.cur_view(), int(w.yaw), int(oven.x)])

	# let go far from any station: the view stays where you left it
	await steer(stk, w, Vector2(-135, 10))
	release(stk)
	await frames(30)
	check(w.cur_view() == "oven" and absf(angle_difference(deg_to_rad(w.t_yaw), deg_to_rad(-135))) < deg_to_rad(8.0),
		"let go away from the stations and the look stays put", [w.cur_view(), int(w.t_yaw)])

	var e := click()                                        # a tap, no push: look back at the station
	e.position = stk.size / 2.0
	stk._gui_input(e)
	release(stk)
	await frames(40)
	check(w.cur_view() == "oven" and on_station(w), "a tap looks back at your station", [w.cur_view(), int(w.yaw)])

	# the clock is the control
	k.act_btn.pressed.emit()
	await frames(5)
	check(m.modal_root.visible, "tapping the clock in the morning asks to open (the prep is not done)")
	await shot("open-ask")
	m.close_modal()
	await frames(3)
	k._go_open()
	await frames(5)
	m.close_modal()
	await frames(5)
	var svc = m.screen()
	var in_service: bool = svc.get_script().get_global_name() == "ServiceScreen"
	check(in_service and svc.top_lbl.time.text.contains(":"), "open: service runs and the clock shows the time",
		svc.top_lbl.time.text if in_service else svc)
	await shot("service")
	svc.top_lbl.time.pressed.emit()
	await frames(5)
	check(m.modal_root.visible and press_modal("Cancel"), "tapping the clock in service asks before closing early")
	await frames(3)
	check(is_instance_valid(svc) and not svc.done, "cancel keeps the van open")

extends "res://tests/bot.gd"
## AR with a stand-in for the phone ARCore tracks (on a computer there is no ARCore): walking moves you through the
## kitchen, crouching lowers you, turning to a station puts you there, Start puts you back where you stood facing
## your station; the camera mode shows the camera's picture behind the kitchen without its walls; AR in a VR viewer
## moves both eyes; turning AR off puts it all back.

var AR                                  # the ARMode script, loaded once the autoloads are up

## the phone in the room: where it is (metres) and which way it faces (yaw, pitch in degrees)
func phone(at: Vector3, yaw: float = 0.0, pitch: float = 0.0) -> void:
	AR.test_pose = Transform3D(Basis.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0.0)), at)

func run() -> void:
	G.new_game()
	AR = load("res://scripts/fp/ar_mode.gd")
	await open_game()
	m.show_hub("home")
	await frames(10)
	var k = m.screen()
	var w = k.world
	var eye0: Vector3 = w.head.global_position
	phone(Vector3(0.3, 1.4, 0.2))                        # wherever the phone happens to be in your room
	G.s.ar = "move"
	m.set_ar(true)
	await frames(5)
	check(AR.active and w.immersive and w.ar_ref != null, "AR on: the phone's real position and turn drive your head", w.immersive)
	check(w.head.global_position.distance_to(eye0) < 0.02, "you start where you stood, facing your station", w.head.global_position - eye0)

	# step forward half a metre (the way you face), and crouch
	phone(Vector3(0.3, 1.4, -0.3))
	await frames(3)
	var moved: Vector3 = w.head.global_position - eye0
	check(moved.z < -0.45 and absf(moved.x) < 0.05, "walk forward half a metre and you walk into the van half a metre", moved)
	phone(Vector3(0.3, 1.1, -0.3))
	await frames(3)
	check(w.head.global_position.y < eye0.y - 0.25, "crouch and you are lower", w.head.global_position.y - eye0.y)
	await shot("ar-stepped")

	# turn to the oven and you are at the oven
	var ov: Vector2 = w.STATIONS.oven
	phone(Vector3(0.3, 1.4, -0.3), ov.x - w.t_yaw, ov.y)
	await until(func(): return w.cur_view() == "oven", 2.0)
	check(w.cur_view() == "oven", "turn to the oven and you are at the oven", w.cur_view())
	# Start: back where you stood, facing the station you are at
	w.pad_test = {"start": true}
	await frames(2)
	w.pad_test = null
	await frames(3)
	check(w.head.global_position.distance_to(eye0) < 0.05, "Start puts you back where you stood", w.head.global_position - eye0)

	# the camera mode: the camera's picture behind the kitchen, the walls gone
	CameraServer.set_monitoring_feeds(true)
	var feed := CameraFeed.new()
	CameraServer.add_feed(feed)
	AR.test_feed = feed.get_id()
	G.s.ar = "camera"
	await frames(3)
	check(w.env.background_mode == Environment.BG_CAMERA_FEED and w.env.background_camera_feed_id == feed.get_id(), "the camera mode shows the camera's picture behind the kitchen", w.env.background_mode)
	check(w.shell.size() >= 2 and w.shell.all(func(n): return not n.visible), "and the van's walls and the street are gone (the counters and the oven stay)", w.shell.map(func(n): return n.visible))
	await shot("ar-camera")
	G.s.ar = "move"
	await frames(3)
	check(w.env.background_mode == Environment.BG_COLOR and w.shell.all(func(n): return n.visible), "back to walking round the kitchen: the walls are back", w.env.background_mode)
	CameraServer.remove_feed(feed)
	AR.test_feed = -1

	# AR in a VR viewer: both eyes move with you
	G.s.vr = true
	m.set_vr(true)
	await frames(5)
	var e0: Vector3 = m.vr.eyes[0].cam.global_position
	phone(Vector3(0.3, 1.4, -0.8), w.gyro.x, 0.0)
	await frames(3)
	check(m.vr.eyes[0].cam.global_position.distance_to(e0) > 0.3, "in a VR viewer too, walking moves both eyes", m.vr.eyes[0].cam.global_position - e0)
	G.s.vr = false
	m.set_vr(false)
	await frames(3)

	# AR off
	G.s.ar = "off"
	m.set_ar(false)
	AR.test_pose = null
	await frames(5)
	check(not AR.active and not w.immersive and w.ar_pos == Vector3.ZERO and m.ar == null, "AR off: back to the screen as before", [AR.active, w.immersive, w.ar_pos])
	await shot("ar-off")

extends "res://tests/bot.gd"
## Sound and feel: every sound the code asks for (Art.sfx / Art.loop) has a file that loads; the loops are long enough to
## loop; the fire crackles by a lit wood oven and the room hums, and they stop when you leave the kitchen; muting
## silences everything; the music plays on the title and between services, not in service; vibration follows its
## setting; a pizza starting to burn is announced once. (Sounds are made by
## tools/sfx/make_sfx.py.)

var A

func _scripts(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	for f in d.get_files():
		if f.ends_with(".gd"): out.append(dir.path_join(f))
	for sub in d.get_directories(): _scripts(dir.path_join(sub), out)

func run() -> void:
	A = root.get_node("Art")
	# every name in the code
	var re := RegEx.new()
	re.compile("Art\\.(sfx|loop)\\(\"([a-z_]+)\"")
	var asked := {}
	var files := []
	_scripts("res://scripts", files)
	for f in files:
		for hit in re.search_all(FileAccess.get_file_as_string(f)): asked[hit.get_string(2)] = hit.get_string(1)
	var missing := []
	for nm in asked:
		var st = A.sound_stream(nm)
		if st == null or st.get_length() <= 0.0: missing.append(nm)
	check(asked.size() >= 15 and missing.is_empty(), "every sound the game asks for exists (%d of them)" % asked.size(), missing)
	var loops := asked.keys().filter(func(k): return asked[k] == "loop")
	check(loops.all(func(k): return A.sound_stream(k).get_length() >= 3.0), "the background loops and the music are long enough to loop", loops)

	# a lit wood oven in the morning: the fire crackles and the room hums; leaving the kitchen stops them
	G.new_game()
	G.s.upg.oven = 3
	S.add("wood", 40, 2, 0.9)
	G.s.oven_lit = {"day": G.s.day, "at": G.s.clock - 120, "g": 2}
	await open_game()
	m.show_hub("home")
	await frames(10)
	m.screen().world.goto("oven")
	await frames(90)
	var fire = A._loops.get("fire", null)
	var hum = A._loops.get("room", null)
	check(fire != null and fire.playing and fire.volume_db > -30.0, "by the lit wood oven the fire crackles", fire.volume_db if fire != null else null)
	check(hum != null and hum.playing, "the kitchen hums")
	var music = A._loops.get("music", null)
	check(music != null and music.playing, "the music plays quietly between services")
	m.show_start()
	await wait(1.5)
	check(not hum.playing, "leaving the kitchen fades the hum away")
	check(music.playing and music.volume_db > -12.0, "on the title screen the music carries on, a little louder", music.volume_db)

	# muted: nothing plays
	G.s.mute = true
	A.sfx("bell")
	var bell = A._players.get("bell", null)
	check(bell == null or not bell.playing, "muted, a sound does not play")
	G.s.mute = false
	A.sfx("bell")
	bell = A._players.get("bell", null)
	check(bell != null and bell.playing, "unmuted, it does")

	# vibration: felt when it is on, not when it is off
	var b0: int = A.buzzes
	A.buzz(10)
	check(A.buzzes == b0 + 1, "with Vibration on, a buzz is felt")
	G.s.vibrate = false
	A.buzz(10)
	check(A.buzzes == b0 + 1, "with it off, it is not")
	G.s.vibrate = true

	# a pizza starting to burn is announced once, wherever you are looking
	G.new_game()
	m.show_hub("home")
	await frames(5)
	m.screen()._go_open()
	await frames(5)
	m.close_modal()
	await frames(5)
	var svc = m.screen()
	svc.speed = 0
	await wait(2.5)
	check(not A._loops.music.playing, "in service the music fades out: the room is the soundtrack")
	var pz = load("res://scripts/pizza.gd").new({"id": 90, "rec": D.REC.margherita, "gone": true, "state": "new"}, {"q": 80.0, "g": 3.0, "cost": 0.3})
	svc.oven.load_pizza(pz, 0, false)
	pz.bake.fill(1.6)
	pz.floor = 1.6
	svc.set_view("front")
	var b1: int = A.buzzes
	await frames(20)
	var o = svc.oven.mine()[0] if svc.oven.mine().size() > 0 else {}
	check(o.get("warned", false) and A.buzzes == b1 + 1, "a pizza starting to burn is announced once (a sound and a buzz)", [svc.oven.status(o) if not o.is_empty() else "-", A.buzzes - b1])

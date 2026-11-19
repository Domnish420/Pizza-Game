extends "res://tests/bot.gd"
## Sound: every sound the code asks for (Art.sfx / Art.loop) has a file that loads; the loops are long enough to
## loop; the fire crackles by a lit wood oven and the room hums, and they stop when you leave the kitchen; muting
## silences everything. (Made by tools/sfx/make_sfx.py.)

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
		var path: String = "res://assets/sfx/%s.wav" % nm
		var st = load(path) if ResourceLoader.exists(path) else null
		if st == null or st.get_length() <= 0.0: missing.append(nm)
	check(asked.size() >= 15 and missing.is_empty(), "every sound the game asks for exists (%d of them)" % asked.size(), missing)
	var loops := asked.keys().filter(func(k): return asked[k] == "loop")
	check(loops.all(func(k): return load("res://assets/sfx/%s.wav" % k).get_length() >= 3.0), "the background loops are long enough to loop", loops)

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
	m.show_start()
	await frames(10)
	check(not hum.playing, "leaving the kitchen stops the hum")

	# muted: nothing plays
	G.s.mute = true
	A.sfx("bell")
	var bell = A._players.get("bell", null)
	check(bell == null or not bell.playing, "muted, a sound does not play")
	G.s.mute = false
	A.sfx("bell")
	bell = A._players.get("bell", null)
	check(bell != null and bell.playing, "unmuted, it does")

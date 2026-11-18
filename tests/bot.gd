extends SceneTree
## The base for every test bot. A test extends this file, overrides `run()`, and calls `check()` for each thing that
## must hold. At the end it prints PASS or FAIL and exits 0 or 1. `tests/run.sh` runs them; see `tests/README.md`.
##
## Bots play the real game: they load the autoloads and the main scene, and call the same methods a touch would.

var out := ""                   # the folder for screenshots (tests/out/<name>/); "" = no screenshots
var checks := 0
var fails := 0
var G                           # the autoloads, by their usual short names (untyped, so calls go to the game's methods)
var S
var D
var Dy
var H
var M
var E
var St
var T
var m                           # the main scene, once `open_game()` has loaded it

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else ""
	if out != "": DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	G = root.get_node("Game"); S = root.get_node("Stock"); D = root.get_node("Data"); Dy = root.get_node("Day")
	H = root.get_node("Hygiene"); M = root.get_node("Market"); E = root.get_node("Equip"); St = root.get_node("Story")
	T = root.get_node("Tutor")
	await run()
	print("%s: %d checks, %d failed" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)

## override this
func run() -> void:
	pass

## one thing that must hold; `got` is printed beside it so a failure says what happened
func check(ok: bool, what: String, got: Variant = null) -> void:
	checks += 1
	if not ok: fails += 1
	print("  %s  %s%s" % ["ok  " if ok else "FAIL", what, "" if got == null else "  (%s)" % str(got)])

## a line for the log (not a check)
func note(a: Variant = "", b: Variant = "", c: Variant = "", d: Variant = "", e: Variant = "", f: Variant = "",
		g: Variant = "", h: Variant = "", i: Variant = "", j: Variant = "") -> void:
	print("    ", a, b, c, d, e, f, g, h, i, j)

func open_game() -> void:
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await process_frame

func frames(n: int) -> void:
	for i in n: await process_frame

## real seconds (the game runs on real time, sped up by the speed buttons)
func wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < sec * 1000.0: await process_frame

func shot(name: String, settle := 4) -> void:
	for i in settle: await process_frame
	if out == "": return
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))

## tap the first button in the open dialog whose text starts with `word`
func press_modal(word: String) -> bool:
	for b in m.modal_center.find_children("*", "Button", true, false):
		if b.text.begins_with(word):
			b.emit_signal("pressed")
			return true
	return false

func click() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	return e

extends "res://tests/bot.gd"
## The clock above the hatch (the pass in a restaurant) is how you clock in and out: tap it in the morning to open,
## in service to close early, at night to lock up. Its hands keep the game's time, the sign at the hatch tells the
## customers, and the time on the screen is only a readout. Tapped the way a finger does: at its spot on the screen.

var w

## a tap on the clock where it shows on screen (the same ray a finger's tap casts)
func tap_clock() -> void:
	var px: Vector2 = w.cam.unproject_position(w.job_nodes.open.global_position)
	w._press(0, px, true)
	w._press(0, px, false)

## [hour hand, minute hand] in degrees clockwise from 12, and what they should read at `mins` after midnight
func hands() -> Array:
	return w.clock_hands.map(func(h): return fposmod(-rad_to_deg(h.rotation.z), 360.0))

func reads(mins: float) -> bool:
	var want := [fposmod(mins, 720.0) / 2.0, fposmod(mins, 60.0) * 6.0]
	var got := hands()
	return absf(angle_difference(deg_to_rad(got[0]), deg_to_rad(want[0]))) < 0.01 \
		and absf(angle_difference(deg_to_rad(got[1]), deg_to_rad(want[1]))) < 0.01

func run() -> void:
	G.new_game()
	await open_game()
	m.show_hub("home")
	await frames(10)
	var k = m.screen()
	w = k.world
	check(w.clock_hands.size() == 2 and w.clock_hands.all(func(h): return h != null), "the clock above the hatch has its hands")
	check(reads(Dy.now()), "they show the time (%s)" % D.hhmm(Dy.now()), hands())
	check(not (k.clock_l is Button) and k.clock_l.text.ends_with("open at 11:30"), "the time on the screen is only a readout", k.clock_l.text)
	check(w.job_labels.open.visible and w.job_labels.open.text == "Clock in · open at 11:30", "the clock says what tapping it does",
		w.job_labels.open.text)
	check(w.sign_text.text == "OPEN AT\n11:30", "the sign tells the customers when you open", w.sign_text.text)
	await shot("morning")

	# clock in
	tap_clock()
	await frames(5)
	check(m.modal_root.visible, "tapping the clock asks to open (the prep is not done)")
	await shot("open-ask")
	check(press_modal("Open anyway"), "open anyway")
	await frames(10)
	var svc = m.screen()
	var in_service: bool = svc.get_script().get_global_name() == "ServiceScreen"
	check(in_service, "clocked in: the van is open")
	if not in_service: return
	w = svc.fp.world
	await frames(10)
	check(not (svc.top_lbl.time is Button) and svc.top_lbl.time.text.contains(":"), "in service the time on screen is a readout", svc.top_lbl.time.text)
	check(reads(svc.minute()), "the hands keep the service's time (%s)" % D.hhmm(svc.minute()), hands())
	check(w.sign_text.text == "OPEN" and not w.job_labels.open.visible, "the sign says OPEN; the clock just keeps time",
		[w.sign_text.text, w.job_labels.open.visible])
	await shot("service")

	# clock out early: it asks first
	tap_clock()
	await frames(5)
	check(m.modal_root.visible, "tapping the clock in service asks before closing early")
	await shot("close-ask")
	check(press_modal("Cancel"), "cancel")
	await frames(5)
	check(is_instance_valid(svc) and not svc.done, "cancel keeps the van open")
	tap_clock()
	await frames(5)
	check(press_modal("Close up"), "tap it again and close up")
	await frames(10)
	check((not is_instance_valid(svc) or svc.done) and G.s.phase == "evening", "closed early: it is the evening", G.s.phase)
	m.close_modal()
	await frames(5)

	# clock out: lock up and go home
	m.show_hub("home")
	await frames(10)
	k = m.screen()
	w = k.world
	check(w.job_labels.open.text == "Clock out · lock up" and w.sign_text.text == "CLOSED", "at night the clock says clock out; the sign says CLOSED",
		[w.job_labels.open.text, w.sign_text.text])
	await shot("evening")
	var day0: int = G.s.day
	tap_clock()
	await frames(10)
	press_modal("Sleep anyway")                # (no dough made for tomorrow in this test)
	await frames(10)
	check(G.s.day == day0 + 1 and G.s.phase == "morning", "clocking out locks up: the next morning", [G.s.day, G.s.phase])

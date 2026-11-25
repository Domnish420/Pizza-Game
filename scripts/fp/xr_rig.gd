class_name XRRig
extends Node3D
## A real VR headset (the Quest, through OpenXR): your head, your two hands (tracked hands or the Touch controllers)
## and their buttons. The game is drawn by OpenXR from the window (use_xr) through the XRCamera3D here, placed (by the
## origin, XROrigin3D) so that it is exactly where FPWorld puts your head: your real head turns and walks, and the
## stations' turns (Start, the thumbstick) move the origin. VRView puts the game's screens on a panel in front of you.
##
## Everything about the headset is read here, in the headset's own space (metres, floor level): head(), hand(i). Tests
## set XRRig.test instead (see the bottom of this file), so the whole game can be played with a stand-in headset.

static var active := false              # a headset drives the game (OpenXR running, or the tests' stand-in)
static var test = null                  # tests: {"head": Transform3D, "hands": [right, left]} (see hand())

var origin: XROrigin3D
var camera: XRCamera3D

## an OpenXR headset is running (on a computer or a phone: never)
static func running() -> bool:
	if test != null: return true
	var xr := XRServer.find_interface("OpenXR")
	return xr != null and xr.is_initialized()

## your head in the headset's space (the floor is y = 0)
static func head() -> Transform3D:
	if test != null: return test.get("head", Transform3D(Basis(), Vector3(0, 1.6, 0)))
	return XRServer.get_hmd_transform()

## a hand (0 the right, 1 the left) in the headset's space:
##   tracked  the hand (or its controller) is being tracked
##   aim      where it points (-Z forward): the ray you pinch with
##   tip      the index fingertip (or the tip of the controller): what touches the dough
##   palm     the middle of the hand (-Z towards the fingers, +Y out of the back of the hand)
##   pinch    0..1: pinching (or the trigger)
##   grip     0..1: making a fist (or the grip)
##   stick    the thumbstick
##   by, ax, menu   the buttons (B or Y, A or X, the menu button)
static func hand(i: int) -> Dictionary:
	if test != null:
		var hs: Array = test.get("hands", [])
		return hs[i] if i < hs.size() else {"tracked": false}
	var side := "right" if i == 0 else "left"
	var out := {"tracked": false, "pinch": 0.0, "grip": 0.0, "stick": Vector2.ZERO, "by": false, "ax": false, "menu": false}
	var ct = XRServer.get_tracker(side + "_hand")
	if ct is XRPositionalTracker:
		var aim: XRPose = ct.get_pose("aim")
		if aim != null and aim.has_tracking_data:
			out.tracked = true
			out.aim = aim.transform
			out.tip = aim.transform.origin + aim.transform.basis * Vector3(0, 0, -0.03)
			out.palm = aim.transform
		var grip: XRPose = ct.get_pose("grip")
		if grip != null and grip.has_tracking_data: out.palm = grip.transform
		out.pinch = _num(ct.get_input("trigger"))
		out.grip = _num(ct.get_input("grip"))
		var st = ct.get_input("primary")
		if st is Vector2: out.stick = st
		out.by = bool(ct.get_input("by_button"))
		out.ax = bool(ct.get_input("ax_button"))
		out.menu = bool(ct.get_input("menu_button"))
	# tracked hands: the real fingertip, the real palm, and a pinch measured between thumb and finger
	var ht = XRServer.get_tracker("/user/hand_tracker/" + side)
	if ht is XRHandTracker and ht.has_tracking_data:
		out.tracked = true
		out.hand = true
		var tip: Transform3D = ht.get_hand_joint_transform(XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP)
		var thumb: Transform3D = ht.get_hand_joint_transform(XRHandTracker.HAND_JOINT_THUMB_TIP)
		out.tip = tip.origin
		out.palm = ht.get_hand_joint_transform(XRHandTracker.HAND_JOINT_PALM)
		if not out.has("aim"): out.aim = out.palm
		var gap := tip.origin.distance_to(thumb.origin)
		out.pinch = maxf(float(out.pinch), clampf((0.045 - gap) / 0.03, 0.0, 1.0))
	return out

static func _num(v) -> float:
	if v is float or v is int: return float(v)
	if v is bool: return 1.0 if v else 0.0
	return 0.0

## the headset's own cameras behind the kitchen (Meta's passthrough): your real room shows wherever the game draws
## nothing. True if it is on.
func passthrough(on: bool) -> bool:
	if test != null:
		test["passthrough"] = on
		return on
	var xr := XRServer.find_interface("OpenXR")
	if xr == null or not xr.is_initialized(): return false
	var want := XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND if on else XRInterface.XR_ENV_BLEND_MODE_OPAQUE
	if on and not want in xr.get_supported_environment_blend_modes(): return false
	xr.environment_blend_mode = want
	get_viewport().transparent_bg = on
	return on

## a buzz in a controller (on the hand, i: 0 the right, 1 the left)
static func pulse(i: int, strength: float = 0.5, sec: float = 0.04) -> void:
	if test != null:
		test["pulses"] = int(test.get("pulses", 0)) + 1
		return
	var xr := XRServer.find_interface("OpenXR")
	if xr != null and xr.is_initialized():
		xr.trigger_haptic_pulse("haptic", "right_hand" if i == 0 else "left_hand", 0.0, strength, sec, 0.0)

func _ready() -> void:
	active = true
	origin = XROrigin3D.new()
	add_child(origin)
	camera = XRCamera3D.new()
	camera.near = 0.03
	camera.far = 80.0
	origin.add_child(camera)
	if test == null:
		# OpenXR draws the window; the headset sets the pace (no v-sync of our own)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		get_viewport().use_xr = true
		camera.current = true

func _exit_tree() -> void:
	active = false
	if test == null and is_inside_tree(): get_viewport().use_xr = false

## where the headset's space sits in the kitchen (FPWorld works it out from your station and where you started)
func place(t: Transform3D) -> void:
	origin.global_transform = t

## the head in the kitchen
func head_global() -> Transform3D:
	return origin.global_transform * head()

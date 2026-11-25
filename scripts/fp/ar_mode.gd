class_name ARMode
extends Node
## AR on an Android phone (ARCore, through the ARCore plugin in addons/ARCorePlugin). The phone's camera works out
## where the phone is in your room, so walking, leaning and crouching move you in the kitchen, on the screen or with
## the phone in a VR viewer (Settings > Controls > AR):
##   "move"    the kitchen all round you as usual; your real steps move you through it
##   "camera"  the kitchen in your room: the camera's picture behind the counters, the oven and the people, without
##             the van's or the restaurant's walls
## The first time AR is turned on, the phone asks to install ARCore (Google Play Services for AR) if it is missing, and
## for the camera. Without ARCore (a computer, a phone that cannot run it) the setting says so and changes nothing.
##
## The game draws the kitchen itself (FPWorld, VRView): from ARCore it takes only where the phone is (the "head"
## tracker), its camera's field of view, and its camera picture (a CameraFeed, shown as the 3D background).

const PLUGIN := "ARCorePlugin"          # the Android plugin's singleton (the Java side: install, permission)

static var active := false              # tracking from ARCore is in use: FPWorld reads pose()
static var test_pose = null             # tests: a Transform3D standing in for the tracked phone
static var test_feed := -1              # tests: a camera feed id standing in for ARCore's

var iface: XRInterface = null
var status := "off":                    # where AR stands: "tracking", "starting", "install", "camera", ...
	set(v):
		if v != status and Kit.main != null and SAY.has(v): Kit.main.toast(SAY[v], v in ["failed", "unsupported"])
		status = v
const SAY := {
	"starting": "AR: starting",
	"install": "AR: install Google Play Services for AR when your phone asks",
	"camera": "AR: allow the camera, so the phone can see where it is",
	"looking": "AR: move the phone slowly round the room so it can find its way",
	"tracking": "AR: tracking. Start puts you back at your station",
}
var _t := 0.0

## the setting: "off", "move" or "camera"
static func mode() -> String:
	return String(Game.s.get("ar", "off"))

## ARCore can run here (the plugin is in this build, on Android)
static func supported() -> bool:
	return ClassDB.class_exists("ARCoreInterface") and Engine.has_singleton(PLUGIN)

const MODE_NAMES := {"off": "off", "move": "walk round the kitchen", "camera": "the kitchen in your room"}

static func mode_name() -> String:
	return "AR: " + MODE_NAMES.get(mode(), "off")

static func next_mode() -> void:
	var order := ["off", "move", "camera"]
	Game.s.ar = order[(order.find(mode()) + 1) % order.size()]

## where the phone is in the room (metres; gravity down; the room's own axes, set when AR started), or null when AR is
## not tracking
static func pose():
	if test_pose != null: return test_pose
	if not active: return null
	var tr := XRServer.get_tracker("head")
	if tr == null or not tr is XRPositionalTracker: return null
	var p: XRPose = tr.get_pose("default")
	if p == null or not p.has_tracking_data: return null
	return p.transform

## the camera picture to show behind the kitchen ("camera" mode), as a CameraServer feed id, or -1
static func feed_id() -> int:
	if test_feed >= 0: return test_feed
	if not active: return -1
	for i in CameraServer.get_feed_count():
		var f := CameraServer.get_feed(i)
		if f != null and f.get_name() == "ARCore": return f.get_id()
	return -1

func _ready() -> void:
	if test_pose != null:
		active = true
		status = "tracking"
		return
	if not supported():
		status = "unsupported"
		Kit.main.toast("AR needs ARCore, on an Android phone that supports it", true)
		return
	CameraServer.set_monitoring_feeds(true)               # (ARCore's camera picture is one of its feeds)
	var plugin := Engine.get_singleton(PLUGIN)
	plugin.requestAR()                                   # install ARCore and allow the camera, if not yet
	status = "starting"

func _process(dt: float) -> void:
	if test_pose != null or not supported(): return
	_t -= dt
	if _t > 0.0: return
	_t = 0.5
	var plugin := Engine.get_singleton(PLUGIN)
	var st := String(plugin.arStatus())
	if st != "ready":
		status = st                                      # "install", "camera" or "unsupported": waiting on the player
		return
	if iface == null:
		plugin.initializeEnvironment()
		iface = ClassDB.instantiate("ARCoreInterface")
		XRServer.add_interface(iface)
		if not iface.initialize():
			status = "failed"
			Kit.main.toast("AR could not start on this phone", true)
			XRServer.remove_interface(iface)
			iface = null
			set_process(false)
			return
		if iface.has_method("enable_horizontal_plane_detection"): iface.enable_horizontal_plane_detection(true)
		active = true
	var tracking := iface.get_tracking_status() == XRInterface.XR_NORMAL_TRACKING
	status = "tracking" if tracking else "looking"           # (ARCore needs a moment, and something to look at)

## the phone camera's field of view top to bottom (degrees), so the kitchen lines up with the camera's picture
func fov(aspect: float) -> float:
	if iface == null: return 0.0
	var pr := iface.get_projection_for_view(0, aspect, 0.05, 100.0)
	if pr.y.y <= 0.0: return 0.0
	return rad_to_deg(2.0 * atan(1.0 / pr.y.y))

## turn AR off: hand the camera back, stop ARCore
func close() -> void:
	active = false
	set_process(false)
	if iface != null:
		iface.uninitialize()
		XRServer.remove_interface(iface)
		iface = null
		if Engine.has_singleton(PLUGIN): Engine.get_singleton(PLUGIN).uninitializeEnvironment()

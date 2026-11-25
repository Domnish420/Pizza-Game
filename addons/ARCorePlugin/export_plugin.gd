@tool
extends EditorPlugin
## Adds the ARCore plugin (its Android library and ARCore itself) to the phone's Android build (not the Quest's: a
## headset has no ARCore). The game starts ARCore itself (scripts/fp/ar_mode.gd), so unlike the plugin's demo this adds
## no autoload: on a computer, where there is no ARCore, nothing refers to it.

var export_plugin: AndroidExportPlugin

func _enter_tree() -> void:
	export_plugin = AndroidExportPlugin.new()
	add_export_plugin(export_plugin)

func _exit_tree() -> void:
	remove_export_plugin(export_plugin)
	export_plugin = null

class AndroidExportPlugin extends EditorExportPlugin:
	const NAME := "ARCorePlugin"

	func _supports_platform(platform) -> bool:
		return platform is EditorExportPlatformAndroid and not _quest()

	## the Quest build (its preset has the "quest" feature)
	func _quest() -> bool:
		var p := get_export_preset()
		if p == null: return false
		for f in String(p.get_custom_features()).split(",", false):
			if f.strip_edges() == "quest": return true
		return false

	func _get_android_libraries(_platform, debug: bool) -> PackedStringArray:
		if debug: return PackedStringArray([NAME + "/bin/debug/" + NAME + "-debug.aar"])
		return PackedStringArray([NAME + "/bin/release/" + NAME + "-release.aar"])

	func _get_android_dependencies(_platform, _debug: bool) -> PackedStringArray:
		return PackedStringArray(["com.google.ar:core:1.44.0", "androidx.appcompat:appcompat:1.4.0"])

	func _get_name() -> String:
		return NAME

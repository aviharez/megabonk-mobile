@tool
extends EditorPlugin
# Local patch (see docs/PLUGINS.md), over GodotPlayGameServices 3.4.0:
# - no "GodotPlayGameServices" autoload: the game talks to the native
#   singleton itself (scripts/play_games/gpgs_backend.gd), and adding /
#   removing the autoload on every editor start rewrote project.godot;
# - an export whose game id is empty leaves the plugin out of the APK
#   (no AAR, no SDK, no APP_ID meta-data). Upstream exported it anyway and the
#   Gradle build failed on the missing string, or the SDK hit a fatal
#   developer error on a bad id. Without it the game falls back to its inert
#   (release) or fake (debug) Play Games backend.

var _export_plugin: AndroidExportPlugin

func _enter_tree() -> void:
	_export_plugin = AndroidExportPlugin.new()
	add_export_plugin(_export_plugin)

func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null

class AndroidExportPlugin extends EditorExportPlugin:
	var _plugin_name = &"GodotPlayGameServices"

	func _supports_platform(platform):
		if platform is EditorExportPlatformAndroid:
			return true
		return false

	func _game_id() -> String:
		var id = get_option("godot_play_game_services/game_id")
		return str(id).strip_edges() if id != null else ""

	func _export_begin(features: PackedStringArray, is_debug: bool, path: String, flags: int) -> void:
		var id := _game_id()
		if id == "":
			print("[%s] No game id in the export preset: Play Games is left out of this build." % _plugin_name)
			return

		var file := FileAccess.open("android/build/res/values/strings.xml", FileAccess.WRITE)
		file.store_string("<?xml version=\"1.0\" encoding=\"utf-8\"?><resources><string translatable=\"false\" name=\"game_services_project_id\">%s</string></resources>" % id)

		print("[{plugin_name}] added game-id {id} to [values/strings.xml]".format({"plugin_name": _plugin_name, "id": id}))

	func _get_android_libraries(platform, debug):
		if _game_id() == "":
			return PackedStringArray()
		if debug:
			return PackedStringArray([_plugin_name + "/bin/debug/" + _plugin_name + "-debug.aar"])
		else:
			return PackedStringArray([_plugin_name + "/bin/release/" + _plugin_name + "-release.aar"])

	func _get_android_dependencies(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		if not _supports_platform(platform) or _game_id() == "":
			return PackedStringArray()

		return PackedStringArray([
			"com.google.code.gson:gson:2.11.0",
			"com.google.android.gms:play-services-games-v2:21.0.0"
			])

	func _get_android_manifest_application_element_contents(platform: EditorExportPlatform, debug: bool) -> String:
		if not _supports_platform(platform) or _game_id() == "":
			return ""

		return "<meta-data android:name=\"com.google.android.gms.games.APP_ID\" android:value=\"@string/game_services_project_id\"/>"

	func _get_name():
		return _plugin_name

	func _get_export_options(platform: EditorExportPlatform) -> Array[Dictionary]:
		var options: Array[Dictionary] = []

		if platform.get_os_name() != "Android":
			return options

		# exposes game id within game's export settings.
		options.append({
			"option": {
				"name": "godot_play_game_services/game_id",
				"type": TYPE_STRING,
				"hint": "",
				"hint_string": "google play services game id."
			},
			"default_value": ""
		})
		return options

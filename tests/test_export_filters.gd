extends RefCounted
## Nothing the exported game loads may be cut by an export preset's
## exclude_filter. (Phase 5: excluding addons/admob/internal/* dropped
## plugin_version.gd, which AdRequest preloads, and every AdMob class failed
## to compile on the phone while desktop tests stayed green.)
##
## Checks every .gd that is exported (not matched by the filter) for
## preload("res://...") / load("res://...") targets that are excluded.
## Editor plugins only run in the editor, so they may load anything.

## Loads that only run in the editor (guarded by OS.has_feature("editor")).
const EDITOR_ONLY_LOADS := [
	"res://addons/admob/internal/mock/mock_admob_factory.gd",
]


func test_exported_scripts_load_nothing_excluded(t) -> void:
	var cfg := ConfigFile.new()
	t.check(cfg.load("res://export_presets.cfg") == OK, "export_presets.cfg loads")
	var scripts := _gd_files("res://")
	t.check(scripts.size() > 50, "found the project's scripts (%d)" % scripts.size())
	var re := RegEx.new()
	re.compile("(?:preload|load)\\(\\s*\"(res://[^\"]+)\"")
	for section in cfg.get_sections():
		if not section.begins_with("preset.") or section.ends_with(".options"):
			continue
		var name: String = cfg.get_value(section, "name", section)
		var excludes := []
		for f: String in String(cfg.get_value(section, "exclude_filter", "")).split(",", false):
			excludes.append(f.strip_edges())
		var bad := []
		for path: String in scripts:
			if _excluded(path, excludes):
				continue
			var src := FileAccess.get_file_as_string(path)
			if src.contains("extends EditorPlugin") or src.contains("extends EditorExportPlugin"):
				continue
			for m in re.search_all(src):
				var target := m.get_string(1)
				if target in EDITOR_ONLY_LOADS:
					continue
				if _excluded(target, excludes):
					bad.append("%s -> %s" % [path, target])
		t.check(bad.is_empty(), "%s: exported scripts load excluded files:\n%s" % [name, "\n".join(bad)])


func _excluded(path: String, excludes: Array) -> bool:
	var rel := path.trim_prefix("res://")
	for pattern: String in excludes:
		if rel.match(pattern):
			return true
	return false


func _gd_files(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		if d.begins_with(".") or d in ["android", "build"]:
			continue
		out.append_array(_gd_files(dir.path_join(d)))
	return out

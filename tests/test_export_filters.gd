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


## Raw files the game reads with FileAccess (sheet sidecars, the UI kit's
## 9-slice metadata) aren't resources: an export only ships them if the
## preset's include_filter names them. (Phase 8: assets/ui/ui_kit.json was
## missing, so phones drew the plain fallback boxes instead of the UI kit.)
func test_every_asset_json_is_in_the_include_filter(t) -> void:
	var cfg := ConfigFile.new()
	cfg.load("res://export_presets.cfg")
	var jsons := _files_with("res://assets", ".json")
	t.check(jsons.size() > 5, "found the asset sidecars (%d)" % jsons.size())
	for section in cfg.get_sections():
		if not section.begins_with("preset.") or section.ends_with(".options"):
			continue
		var name: String = cfg.get_value(section, "name", section)
		var includes := []
		for f: String in String(cfg.get_value(section, "include_filter", "")).split(",", false):
			includes.append(f.strip_edges())
		var missing := []
		for path: String in jsons:
			if not _excluded(path, includes):  # "excluded" = matches a pattern
				missing.append(path)
		t.check(missing.is_empty(), "%s: include_filter misses %s" % [name, ", ".join(missing)])


## PixelTitle reads glyphs from the imported font (the raw .fnt isn't in an
## export, so every title drew blank on phones). Same metrics as the .fnt.
func test_pixel_title_glyphs_match_the_fnt(t) -> void:
	var text := FileAccess.get_file_as_string("res://assets/fonts/bonk.fnt")
	var checked := 0
	var bad := []
	for line in text.split("\n"):
		if not line.begins_with("char "):
			continue
		var d := {}
		for part in line.split(" ", false):
			var kv := part.split("=")
			if kv.size() == 2:
				d[kv[0]] = int(kv[1])
		var g := PixelTitle.glyph(d.id)
		var want := [Rect2(d.x, d.y, d.width, d.height), Vector2(d.xoffset, d.yoffset), float(d.xadvance)]
		if g[0] != want[0] or g[1] != want[1] or float(g[2]) != want[2]:
			bad.append("%d: %s vs %s" % [d.id, g, want])
		checked += 1
	t.check(checked > 60, "checked the font's glyphs (%d)" % checked)
	t.check(bad.is_empty(), "glyphs differ from the .fnt: %s" % ", ".join(bad.slice(0, 5)))
	t.check(PixelTitle.measure("MOBBED!") == 46, "the logo measures 46 font px")


func _files_with(dir: String, ext: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(ext):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_files_with(dir.path_join(d), ext))
	return out

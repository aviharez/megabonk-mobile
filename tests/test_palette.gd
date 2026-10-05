extends RefCounted
## Palette is 32 unique colors, and every PNG under assets/ uses only those
## colors (fully transparent pixels are ignored).


func test_palette_has_32_unique_colors(t) -> void:
	var cols := Palette.colors()
	t.check(cols.size() == 32, "32 colors, got %d" % cols.size())
	var seen := {}
	for c in cols:
		seen[c.to_rgba32()] = true
	t.check(seen.size() == cols.size(), "all unique")


func test_assets_are_on_palette(t) -> void:
	var allowed := {}
	for c in Palette.colors():
		allowed[c.to_rgba32()] = true
	for p in _pngs("res://assets"):
		var img := Image.load_from_file(ProjectSettings.globalize_path(p))
		if img == null:
			t.check(false, "can't read " + p)
			continue
		img.convert(Image.FORMAT_RGBA8)
		var bad := 0
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a8 == 0:
					continue
				if c.a8 != 255 or not allowed.has(c.to_rgba32()):
					bad += 1
		t.check(bad == 0, "%s has %d off-palette pixels" % [p, bad])


func _pngs(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".png"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_pngs(dir.path_join(d)))
	return out

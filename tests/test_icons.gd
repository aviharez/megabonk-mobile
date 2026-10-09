extends RefCounted
## Content icons (Icons, ContentIcon): every weapon and item has its 16x16
## art, every tome builds one from the book and its data, characters with
## sheets get a head icon, locked icons are INK silhouettes, and everything
## stays on the palette.

var db := GameData.load_from(GameData.ROOT)


func _on_palette(img: Image) -> bool:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0 and (c.a < 1.0 or not Palette.has(c) or c.to_rgba32() == Palette.color(Palette.ENEMY_SHOT).to_rgba32()):
				return false
	return true


func _opaque(img: Image) -> int:
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			n += int(img.get_pixel(x, y).a > 0.0)
	return n


func test_every_content_has_an_icon(t) -> void:
	Icons.clear()
	for kind: String in ["weapons", "items", "tomes", "characters"]:
		for e: Dictionary in db.all(kind):
			var img := Icons.image(db, kind, e.id)
			t.check(img != null, "%s/%s has an icon" % [kind, e.id])
			if img == null:
				continue
			t.check(img.get_size() == Vector2i(Icons.SIZE, Icons.SIZE), "%s/%s is 16x16 (%s)" % [kind, e.id, img.get_size()])
			t.check(_on_palette(img), "%s/%s only uses palette colors, binary alpha" % [kind, e.id])
			t.check(_opaque(img) > 40, "%s/%s isn't empty" % [kind, e.id])


func test_tome_icon_from_data(t) -> void:
	var icon := {"cover": ["RED", "WINE"], "symbol_color": "BUTTER", "symbol": ["X...X"]}
	var img := Icons.tome(icon)
	var book: Image = load(Icons.BOOK)
	t.check(img != null and book != null, "book and tome icon load")
	var mist := Palette.color(Palette.MIST).to_rgba32()
	var seen_red := false
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			t.check(c.a == 0.0 or c.to_rgba32() != mist, "no MIST left at %d,%d" % [x, y])
			seen_red = seen_red or (c.a > 0.0 and c.to_rgba32() == Palette.color(Palette.RED).to_rgba32())
	t.check(seen_red, "the cover is RED")
	var at := Icons.SYMBOL_AT
	t.check(img.get_pixelv(at) == Palette.color(Palette.BUTTER) and img.get_pixelv(at + Vector2i(4, 0)) == Palette.color(Palette.BUTTER), "symbol drawn")
	t.check(img.get_pixelv(at + Vector2i(1, 0)) == Palette.color(Palette.RED), "symbol gaps show the cover")
	t.check(Icons.tome({}) == null, "no icon data, no icon")
	# Two tomes with different covers get different icons.
	var a := Icons.image(db, "tomes", "think_big")
	var b := Icons.image(db, "tomes", "cursed_diary")
	t.check(a.get_data() != b.get_data(), "tome icons differ")


func test_locked_is_an_ink_silhouette(t) -> void:
	Icons.clear()
	var img := Icons.image(db, "weapons", "baguette")
	var sil := Icons.silhouette(img)
	t.check(_opaque(sil) == _opaque(img), "same shape")
	var ink := Palette.color(Palette.INK)
	var all_ink := true
	for y in sil.get_height():
		for x in sil.get_width():
			var c := sil.get_pixel(x, y)
			all_ink = all_ink and (c.a == 0.0 or c == ink)
	t.check(all_ink, "every opaque pixel is INK")
	var tex := Icons.texture(db, "weapons", "baguette", true)
	t.check(tex != null and tex != Icons.texture(db, "weapons", "baguette"), "locked texture is its own")
	t.check(Icons.texture(db, "weapons", "baguette") == Icons.texture(db, "weapons", "baguette"), "textures are cached")
	t.check(Icons.texture(db, "weapons", "no_such_weapon") == null, "unknown content: no art")


func test_content_icon_uses_art(t) -> void:
	var ci := ContentIcon.new("items", false, "hot_sauce", db)
	t.check(ci.art != null and ci.size == Vector2(18, 18), "art + 18x18 frame")
	var placeholder := ContentIcon.new("items", true)
	t.check(placeholder.art == null, "no id: placeholder glyph")
	ci.free()
	placeholder.free()


func test_card_text_fits_with_the_icon_above(t) -> void:
	# Level-up cards are 160 px wide with the icon above the text (art_above),
	# so every line gets the full width minus the outline and a margin.
	var theme: Theme = load("res://assets/ui/theme.tres")
	var widest := 0.0
	var line_max := ""
	for kind: String in ["weapon", "tome"]:
		for e: Dictionary in db.all(kind + "s"):
			var n: int = e.levels.size() if kind == "weapon" else int(db.get_entry("rules", "run").max_level)
			for lv in range(1, n + 1):
				for is_new: bool in [true, false]:
					for line in LevelUpCards.describe({"kind": kind, "id": e.id, "level": lv, "is_new": is_new, "def": e}):
						var w := theme.default_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, theme.default_font_size).x
						if w > widest:
							widest = w
							line_max = line
	t.check(widest <= 160 - 6, "widest card line '%s' is %d px" % [line_max, widest])

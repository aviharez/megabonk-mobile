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


func test_map_house_sprite_and_roof_colors(t) -> void:
	var map_def := db.get_entry("maps", "suburbia")
	var ml := MapLayout.new()
	ml.setup(map_def)
	var red := ml._sprite_for({"kind": "house", "color": "RED"})
	var blue := ml._sprite_for({"kind": "house", "color": "BLUE"})
	t.check(red != null and red.get_size() == Vector2i(34, 34), "house sprite loads (34x34)")
	var counts := func(img: Image, idx: int) -> int:
		var n := 0
		for y in img.get_height():
			for x in img.get_width():
				n += int(img.get_pixel(x, y).a > 0.0 and img.get_pixel(x, y) == Palette.color(idx))
		return n
	t.check(counts.call(red, Palette.RED) > 20, "red roof drawn as is")
	t.check(counts.call(blue, Palette.RED) == 0 and counts.call(blue, Palette.SALMON) == 0, "blue house has no red roof left")
	t.check(counts.call(blue, Palette.BLUE) == counts.call(red, Palette.RED), "every RED roof pixel became BLUE")
	t.check(ml._sprite_for({"kind": "house", "color": "BLUE"}) == blue, "recolors are cached")
	t.check(_on_palette(blue), "recolored house stays on the palette")
	# A house sprite stands on its rect: bottom centre on bottom centre.
	var r := Rect2(100, 50, 30, 26)
	t.check(MapLayout._sprite_pos(r, red) == Vector2i(98, 42), "sprite position %s" % MapLayout._sprite_pos(r, red))
	# Variants: a GREEN tree is the pine, a plain one the round tree.
	var plain := ml._sprite_for({"kind": "tree"})
	var pine := ml._sprite_for({"kind": "tree", "color": "GREEN"})
	t.check(pine != plain and pine.get_size() != plain.get_size(), "GREEN tree uses the pine sprite")
	for kind: String in ["tree", "bush", "shed", "car", "bench", "swing"]:
		t.check(ml._art.has(kind), "%s has prop art" % kind)
	ml.free()


func test_map_ground_textures_and_altar_sprite(t) -> void:
	var map_def := db.get_entry("maps", "suburbia")
	for kind: String in map_def.get("ground_textures", {}):
		var img: Image = load(map_def.ground_textures[kind])
		t.check(img != null and _on_palette(img), "%s texture loads and is on the palette" % kind)
	var ml := MapLayout.new()
	var t0 := Time.get_ticks_msec()
	ml.setup(map_def)
	var ms := Time.get_ticks_msec() - t0
	t.check(ms < 3000, "map builds in %d ms" % ms)
	# A sidewalk pixel comes from the paving texture, not the flat code color.
	var paving: Image = load(map_def.ground_textures.sidewalk)
	var sw: Array = map_def.props.filter(func(p: Dictionary) -> bool: return p.kind == "sidewalk")[0].rect
	var at := Vector2i(int(sw[0]) + 3, int(sw[1]) + 3)
	t.check(ml._img.get_pixelv(at) == paving.get_pixel(at.x % paving.get_width(), at.y % paving.get_height()), "sidewalk is textured")
	ml.free()
	var altar := db.get_entry("interactables", "boss_altar")
	var tex := Interactables.sprite_of(altar)
	t.check(tex != null and tex.get_size() == Vector2(24, 22), "boss altar uses its sprite (%s)" % (tex.get_size() if tex else null))
	t.check(Interactables.sprite_of({"shape": "altar", "color": "BLOOD"}) != null, "no sprite: placeholder shape")


func test_map_pool_slice_and_pond_decor(t) -> void:
	var map_def := db.get_entry("maps", "suburbia")
	var ml := MapLayout.new()
	ml.setup(map_def)
	var pool := MapLayout._load_image(map_def.prop_art.pool.sprite)
	var sl: Array = map_def.prop_art.pool.slice
	t.check(_on_palette(pool) and pool.get_width() > sl[0] + sl[2] and pool.get_height() > sl[1] + sl[3], "pool template on the palette, bigger than its slice")
	var pools: Array = map_def.props.filter(func(p: Dictionary) -> bool: return p.kind == "pool")
	var big: Dictionary = pools.reduce(func(a: Dictionary, p: Dictionary) -> Dictionary: return p if p.rect[2] > a.rect[2] else a)
	var r: Array = big.rect
	var corner := Vector2i(int(r[0]) + 2, int(r[1]) + 2)
	t.check(ml._img.get_pixelv(corner) == pool.get_pixel(2, 2), "pool corner drawn from the template")
	var br := Vector2i(int(r[0] + r[2]) - 3, int(r[1] + r[3]) - 3)
	t.check(ml._img.get_pixelv(br) == pool.get_pixel(pool.get_width() - 3, pool.get_height() - 3), "far corner too (%s)" % [r])
	t.check(ml._img.get_pixel(int(r[0] + r[2] / 2), int(r[1] + r[3] / 2)) == Palette.color(Palette.BLUE), "middle is water")
	t.check(ml._decor.get("pond", {}).size() == 2, "pond decor (lily pads, reeds) loaded")
	var pond: Array = map_def.props.filter(func(p: Dictionary) -> bool: return p.kind == "pond")[0].rect
	var lip := ml._img.get_pixel(int(pond[0] + pond[2] / 2), int(pond[1] + pond[3]) + 3)
	t.check(lip == Palette.color(Palette.BARK), "pond shore has the dark lip at the bottom")
	ml.free()

class_name MapLayout
extends Node2D
## The map from data/maps/: lawn, boundary fence and props ("props": [{"kind",
## "rect": [x, y, w, h], optional "color" (palette name: roof, car...),
## "shape": "ellipse", "lines": true (road center dashes)}]). Solid props
## fill a grid of CELL-pixel cells that the player and walking enemies can't
## enter (fliers and ghosts ignore it). Movement slides along walls one axis
## at a time, which is cheap enough for 300 enemies.
##
## The whole map is baked once into one texture (one sprite to draw each
## frame instead of thousands of rects). Ground props go down first, then
## dithered shadows, then the solid props. Palette colors only, whole pixels.
## Kinds named in the map's "prop_art" are drawn from a sprite instead (see
## _sprite_for); every other kind is drawn in code.

const CELL := 8
## Prop kinds the code can draw. true = solid (blocks walkers).
const KINDS := {
	"yard": false, "field": false, "garden": false, "path": false, "sand": false,
	"sidewalk": false, "driveway": false, "road": false, "crosswalk": false,
	"house": true, "fence": true, "hedge": true, "pond": true, "tree": true,
	"car": true, "swing": true,
	# Sheds and backyard pools are walk-through too: with houses, fences and
	# cars they left too little room to kite the horde.
	"shed": false, "pool": false,
	# Street furniture is walk-past decoration: solid posts along every
	# sidewalk snagged the player and boxed fights into corridors.
	# Same for bushes; trees block only their trunk cell (see _block).
	"bench": false, "mailbox": false, "lamp": false, "bush": false, "planter": false,
}
## Ground kinds in draw order (later ones cover earlier ones). Every other
## kind, solid or not, is drawn on top of the ground.
## Fields go after paths and sand, so a pitch can sit inside a running track.
const GROUND := ["yard", "garden", "path", "sand", "field", "sidewalk", "driveway", "road", "crosswalk"]
## Solid kinds that cast a shadow.
const SHADOWED := ["house", "shed", "tree", "bush", "car", "hedge", "bench", "swing", "lamp", "mailbox", "planter"]
## Darker and lighter palette neighbours for roofs, cars and the like.
const SHADE_OF := {"RED": "BLOOD", "BLUE": "OCEAN", "PURPLE": "PLUM", "WOOD": "BARK", "TEAL": "OCEAN", "GREEN": "LEAF",
	"SKY": "BLUE", "ORANGE": "RUST", "CRUST": "WOOD", "GRAY": "SHADE", "PINK": "PURPLE", "GOLD": "RUST", "PAPER": "MIST", "MIST": "GRAY", "LEAF": "DEEP_GREEN"}
const LIGHT_OF := {"RED": "SALMON", "BLUE": "SKY", "PURPLE": "PINK", "WOOD": "CRUST", "TEAL": "SKY", "GREEN": "LIME",
	"SKY": "WHITE", "ORANGE": "GOLD", "CRUST": "DOUGH", "GRAY": "MIST", "PINK": "SALMON", "GOLD": "BUTTER", "PAPER": "WHITE", "MIST": "PAPER", "LEAF": "GREEN"}

var bounds := Rect2()
var props: Array = []
var cols := 0
var rows := 0
var blocked := PackedByteArray()
## 1 = a solid cell within 2 cells of this one. Far from walls, separation
## can skip wall checks (its pushes add up to well under 2 cells a frame).
var near_wall := PackedByteArray()
var _lawn_colors := [Palette.LEAF, Palette.DEEP_GREEN, Palette.GREEN]
var _img: Image
var _rng := RandomNumberGenerator.new()
## kind -> {"image": Image, "ramp": [palette indices], "colors": {name: [indices]},
## "variants": {name: Image}}
var _art := {}
## Ground kind -> texture path (map "ground_textures"); "lawn" is the base.
var _ground_textures := {}


func setup(map_def: Dictionary) -> void:
	bounds = Rect2(Vector2.ZERO, Vector2(map_def.size[0], map_def.size[1]))
	props = map_def.get("props", [])
	var cols_def: Array = map_def.get("ground_colors", ["LEAF", "DEEP_GREEN", "GREEN"])
	_lawn_colors = cols_def.map(func(c: String) -> int: return Palette.index_of(c))
	_art = {}
	_ground_textures = map_def.get("ground_textures", {})
	var art_def: Dictionary = map_def.get("prop_art", {})
	for kind: String in art_def:
		var a: Dictionary = art_def[kind]
		var img := _load_image(a.get("sprite", ""))
		if img == null:
			push_error("MapLayout: prop_art sprite for \"%s\" not found" % kind)
			continue
		var to_idx := func(names: Array) -> Array: return names.map(func(n: String) -> int: return Palette.index_of(n))
		var colors := {}
		for c: String in a.get("colors", {}):
			colors[c] = to_idx.call(a.colors[c])
		var variants := {}
		for c: String in a.get("variants", {}):
			var v := _load_image(a.variants[c])
			if v == null:
				push_error("MapLayout: prop_art variant \"%s\" of \"%s\" not found" % [c, kind])
			else:
				variants[c] = v
		_art[kind] = {"image": img, "ramp": to_idx.call(a.get("ramp", [])), "colors": colors, "variants": variants,
			"repeat": a.get("repeat", false)}
	cols = int(ceil(bounds.size.x / CELL))
	rows = int(ceil(bounds.size.y / CELL))
	blocked.resize(cols * rows)
	blocked.fill(0)
	for p: Dictionary in props:
		if KINDS.get(p.kind, false):
			_block(p)
	near_wall.resize(cols * rows)
	near_wall.fill(0)
	for c in cols * rows:
		if blocked[c] == 1:
			var cx := c % cols
			var cy := c / cols
			for ny in range(maxi(cy - 2, 0), mini(cy + 3, rows)):
				for nx in range(maxi(cx - 2, 0), mini(cx + 3, cols)):
					near_wall[ny * cols + nx] = 1
	# Boundary fence under the baked map, so only a border shows.
	var fence := Node2D.new()
	fence.show_behind_parent = true
	fence.draw.connect(func() -> void:
		fence.draw_rect(bounds.grow(5), Palette.color(Palette.CRUST))
		fence.draw_rect(bounds.grow(1), Palette.color(Palette.INK)))
	add_child(fence)
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = ImageTexture.create_from_image(bake())
	add_child(sprite)


func is_blocked(p: Vector2) -> bool:
	var cx := int(p.x / CELL)
	var cy := int(p.y / CELL)
	if cx < 0 or cy < 0 or cx >= cols or cy >= rows:
		return false
	return blocked[cy * cols + cx] == 1


## True if a box of half-size r around p touches a solid cell.
func is_blocked_circle(p: Vector2, r: float) -> bool:
	return is_blocked(p) or is_blocked(p + Vector2(r, r)) or is_blocked(p + Vector2(-r, r)) \
		or is_blocked(p + Vector2(r, -r)) or is_blocked(p + Vector2(-r, -r))


## True if no solid cell touches the box of half-size r around p (checks
## every cell under it; for placing things, not per-frame movement).
func is_area_free(p: Vector2, r: float) -> bool:
	for cy in range(maxi(0, int((p.y - r) / CELL)), mini(rows, int((p.y + r) / CELL) + 1)):
		for cx in range(maxi(0, int((p.x - r) / CELL)), mini(cols, int((p.x + r) / CELL) + 1)):
			if blocked[cy * cols + cx] == 1:
				return false
	return true


## Moves from p by step, sliding along solid cells, kept inside the map.
func move(p: Vector2, step: Vector2, r: float) -> Vector2:
	var lo := bounds.position + Vector2(r, r)
	var hi := bounds.end - Vector2(r, r)
	var nx := clampf(p.x + step.x, lo.x, hi.x)
	if not is_blocked_circle(Vector2(nx, p.y), r):
		p.x = nx
	var ny := clampf(p.y + step.y, lo.y, hi.y)
	if not is_blocked_circle(Vector2(p.x, ny), r):
		p.y = ny
	return p


## A random point inside the map, `margin` away from solid cells and the
## edge, at least `min_dist` from every point in `avoid` and at least
## `from_start_min` from `start`. Gives up after many tries and returns the
## best spot it saw (furthest from the others).
func random_free_point(rng: RandomNumberGenerator, margin: float, avoid: Array, min_dist: float, start: Vector2, from_start_min: float) -> Vector2:
	var area := bounds.grow(-margin - CELL)
	var best := area.get_center()
	var best_score := -INF
	for i in 400:
		var p := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y)).round()
		if not is_area_free(p, margin):
			continue
		var score := p.distance_to(start) - from_start_min
		for a: Vector2 in avoid:
			score = minf(score, p.distance_to(a) - min_dist)
		if score >= 0.0:
			return p
		if score > best_score:
			best_score = score
			best = p
	return best


static func rect_of(p: Dictionary) -> Rect2:
	return Rect2(p.rect[0], p.rect[1], p.rect[2], p.rect[3])


func _block(p: Dictionary) -> void:
	var r := rect_of(p)
	if p.kind == "tree":
		# Only the trunk: one cell. Dozens of 2x2 blocks snagged every fight.
		var t := Vector2(r.get_center().x, r.end.y - 3)
		blocked[clampi(int(t.y / CELL), 0, rows - 1) * cols + clampi(int(t.x / CELL), 0, cols - 1)] = 1
		return
	var ellipse: bool = p.kind == "pond" or p.get("shape", "") == "ellipse"
	for cy in range(maxi(0, int(r.position.y / CELL)), mini(rows, int(ceil(r.end.y / CELL)))):
		for cx in range(maxi(0, int(r.position.x / CELL)), mini(cols, int(ceil(r.end.x / CELL)))):
			var c := Vector2((cx + 0.5) * CELL, (cy + 0.5) * CELL)
			var cell := Rect2(cx * CELL, cy * CELL, CELL, CELL)
			if ellipse:
				var d := (c - r.get_center()) / (r.size / 2.0)
				if d.length_squared() > 1.0:
					continue
			elif not cell.intersects(r):
				continue
			blocked[cy * cols + cx] = 1


# --- Baking (placeholder art) ----------------------------------------------

## Draws the whole map into one image: lawn, ground props, shadows, props.
func bake() -> Image:
	_img = Image.create_empty(int(bounds.size.x), int(bounds.size.y), false, Image.FORMAT_RGBA8)
	var lawn := _lawn()
	for y in range(0, int(bounds.size.y), lawn.get_height()):
		for x in range(0, int(bounds.size.x), lawn.get_width()):
			_img.blit_rect(lawn, Rect2i(Vector2i.ZERO, lawn.get_size()), Vector2i(x, y))
	for kind: String in GROUND:
		for p: Dictionary in props:
			if p.kind == kind:
				_draw_prop(p)
	for p: Dictionary in props:
		if p.kind in SHADOWED:
			_shadow(p)
	for p: Dictionary in props:
		if not p.kind in GROUND:
			_draw_prop(p)
	return _img


func _draw_prop(p: Dictionary) -> void:
	var r := rect_of(p)
	_rng.seed = int(r.position.x * 131.0 + r.position.y * 7.0)
	if _art.has(p.kind):
		var img := _sprite_for(p)
		for at in _sprite_spots(p, r, img):
			_img.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), at)
		return
	match p.kind:
		"yard": _yard(r)
		"field": _field(r)
		"garden": _garden(r)
		"path": _path(r, p.get("shape", "") == "ellipse")
		"sand": _sand(r)
		"sidewalk": _sidewalk(r)
		"driveway": _driveway(r)
		"road": _road(r, p.get("shape", "") == "ellipse", p.get("lines", false))
		"crosswalk": _crosswalk(r)
		"house": _house(r, p.get("color", "RED"))
		"shed": _shed(r, p.get("color", "WOOD"))
		"fence": _fence(r)
		"hedge": _hedge(r)
		"pond": _pond(r)
		"tree": _tree(r, p.get("color", "LEAF"))
		"bush": _bush(r, p.get("color", "PINK"))
		"pool": _pool(r)
		"car": _car(r, p.get("color", "RED"))
		"bench": _bench(r)
		"swing": _swing(r)
		"mailbox": _mailbox(r, p.get("color", "BLUE"))
		"lamp": _lamp(r)
		"planter": _bush(r, p.get("color", "PINK"))


## The kind's sprite for this prop. A "color" listed in the art's "variants"
## picks that sprite (a pine for a GREEN tree); one listed in "colors" swaps
## the sprite's "ramp" colors for that color's ramp (a blue roof from the red
## house). Cached per kind and color.
func _sprite_for(p: Dictionary) -> Image:
	var a: Dictionary = _art[p.kind]
	var col: String = p.get("color", "")
	if a.variants.has(col):
		return a.variants[col]
	if not a.colors.has(col):
		return a.image
	var key := "_img_" + col
	if not a.has(key):
		var img := (a.image as Image).duplicate() as Image
		var swap := {}
		for i in mini(a.ramp.size(), a.colors[col].size()):
			swap[Palette.color(a.ramp[i]).to_rgba32()] = Palette.color(a.colors[col][i])
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a > 0.0 and swap.has(c.to_rgba32()):
					img.set_pixel(x, y, swap[c.to_rgba32()])
		a[key] = img
	return a[key]


## Where the prop's sprite goes: once, or with the art's "repeat": true as
## many copies side by side as fit the rect's width (a hedge row), centred.
func _sprite_spots(p: Dictionary, r: Rect2, img: Image) -> Array:
	if not _art[p.kind].get("repeat", false) or r.size.x <= img.get_width():
		return [_sprite_pos(r, img)]
	var n := int(r.size.x) / img.get_width()
	var x0 := int(floorf(r.get_center().x)) - n * img.get_width() / 2
	var out := []
	for i in n:
		out.append(Vector2i(x0 + i * img.get_width(), int(r.end.y) - img.get_height()))
	return out


## Sprites stand on the prop: bottom centre of the sprite on the bottom
## centre of the rect (the rect stays the solid footprint).
static func _sprite_pos(r: Rect2, img: Image) -> Vector2i:
	return Vector2i(int(floorf(r.get_center().x)) - img.get_width() / 2, int(r.end.y) - img.get_height())


static func _load_image(path: String) -> Image:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var res = load(path)
	var img: Image = res if res is Image else (res.get_image() if res is Texture2D else null)
	if img == null:
		return null
	img = img.duplicate() as Image
	img.convert(Image.FORMAT_RGBA8)
	return img


## The map's texture for a ground kind (map "ground_textures"), or null.
func _tex(kind: String) -> Image:
	if not _ground_textures.has(kind):
		return null
	var key := "_tex_" + kind
	if not _art.has(key):
		_art[key] = _load_image(_ground_textures[kind])
	return _art[key]


## Fills a rect (or the ellipse in it) with a tiling texture, aligned to the
## map so neighbouring props of one kind join seamlessly.
func _fill_tex(r: Rect2, tex: Image, ellipse := false) -> void:
	var tw := tex.get_width()
	var th := tex.get_height()
	if not ellipse:
		# Whole texture rows and columns at once (blit), clipped to the rect.
		var area := Rect2i(r.position.floor(), Vector2i(r.end.ceil()) - Vector2i(r.position.floor())).intersection(Rect2i(Vector2i.ZERO, _img.get_size()))
		var y := area.position.y
		while y < area.end.y:
			var sy := y % th
			var h := mini(th - sy, area.end.y - y)
			var x := area.position.x
			while x < area.end.x:
				var sx := x % tw
				var w := mini(tw - sx, area.end.x - x)
				_img.blit_rect(tex, Rect2i(sx, sy, w, h), Vector2i(x, y))
				x += w
			y += h
		return
	var c := r.get_center()
	for y in range(maxi(0, int(r.position.y)), mini(_img.get_height(), int(ceil(r.end.y)))):
		for x in range(maxi(0, int(r.position.x)), mini(_img.get_width(), int(ceil(r.end.x)))):
			if ellipse:
				var d := (Vector2(x + 0.5, y + 0.5) - c) / (r.size / 2.0)
				if d.length_squared() > 1.0:
					continue
			_img.set_pixel(x, y, tex.get_pixel(x % tw, y % th))


# Pixel helpers. All clip to the map.

func _c(name_or_index: Variant) -> Color:
	if name_or_index is String:
		return Palette.color(Palette.index_of(name_or_index))
	return Palette.color(name_or_index)


func _rect(r: Rect2, col: Variant) -> void:
	var ri := Rect2i(Vector2i(r.position.round()), Vector2i(r.size.round())).intersection(Rect2i(Vector2i.ZERO, _img.get_size()))
	if ri.size.x > 0 and ri.size.y > 0:
		_img.fill_rect(ri, _c(col))


func _px(x: float, y: float, col: Variant) -> void:
	var xi := int(x)
	var yi := int(y)
	if xi >= 0 and yi >= 0 and xi < _img.get_width() and yi < _img.get_height():
		_img.set_pixel(xi, yi, _c(col))


func _pixel_at(x: float, y: float) -> Color:
	return _img.get_pixel(clampi(int(x), 0, _img.get_width() - 1), clampi(int(y), 0, _img.get_height() - 1))


## Filled pixel ellipse, one row at a time.
func _ellipse(r: Rect2, col: Variant) -> void:
	var cy := r.get_center().y
	var rx := r.size.x / 2.0
	var ry := r.size.y / 2.0
	for y in range(int(r.position.y), int(r.end.y)):
		var dy := (y + 0.5 - cy) / ry
		if absf(dy) > 1.0:
			continue
		var half := roundf(rx * sqrt(1.0 - dy * dy))
		_rect(Rect2(roundf(r.get_center().x - half), y, half * 2.0, 1), col)


## Ellipse with a 1px INK outline.
func _ellipse_outlined(r: Rect2, col: Variant) -> void:
	_ellipse(r.grow(1), Palette.INK)
	_ellipse(r, col)


## Checkerboard dither of `col` over a rect (shadows, texture).
func _dither(r: Rect2, col: Variant, every := 2) -> void:
	var c := _c(col)
	for y in range(int(r.position.y), int(r.end.y)):
		for x in range(int(r.position.x) + (y % every), int(r.end.x), every):
			if x >= 0 and y >= 0 and x < _img.get_width() and y < _img.get_height():
				_img.set_pixel(x, y, c)


func _boxed(r: Rect2, fill: Variant) -> void:
	_rect(r.grow(1), Palette.INK)
	_rect(r, fill)


func _shade(col: String) -> String:
	return SHADE_OF.get(col, "SHADE")


func _light(col: String) -> String:
	return LIGHT_OF.get(col, "PAPER")


## Shadow down and to the right, as a dither (no alpha).
func _shadow(p: Dictionary) -> void:
	var r := rect_of(p)
	if _art.has(p.kind):
		# The sprite's own outline, 3 px down-right, dithered.
		var img := _sprite_for(p)
		var ink := Palette.color(Palette.INK)
		for spot in _sprite_spots(p, r, img):
			var at: Vector2i = spot + Vector2i(3, 3)
			for y in img.get_height():
				for x in img.get_width():
					var m := at + Vector2i(x, y)
					if (m.x + m.y) % 2 == 0 and img.get_pixel(x, y).a > 0.0 and Rect2i(Vector2i.ZERO, _img.get_size()).has_point(m):
						_img.set_pixelv(m, ink)
		return
	match p.kind:
		"tree":
			var canopy := _canopy_rect(r)
			_dither_ellipse(Rect2(canopy.position + Vector2(4, canopy.size.y * 0.4), canopy.size * Vector2(1.0, 0.8)))
		"bush":
			_dither_ellipse(Rect2(r.position + Vector2(2, 3), r.size))
		"lamp":
			_dither(Rect2(r.position + Vector2(1, 1), Vector2(6, 2)), Palette.INK)
		_:
			var off := Vector2(3, 3) if r.size.y > 8 else Vector2(1, 2)
			_dither(Rect2(r.position + off, r.size), Palette.INK)


func _dither_ellipse(r: Rect2) -> void:
	var c := _c(Palette.INK)
	var cy := r.get_center().y
	for y in range(int(r.position.y), int(r.end.y)):
		var dy := (y + 0.5 - cy) / (r.size.y / 2.0)
		if absf(dy) > 1.0:
			continue
		var half := int(roundf(r.size.x / 2.0 * sqrt(1.0 - dy * dy)))
		var x0 := int(r.get_center().x) - half
		for x in range(x0 + (y % 2), x0 + half * 2, 2):
			if x >= 0 and y >= 0 and x < _img.get_width() and y < _img.get_height():
				_img.set_pixel(x, y, c)


# Ground.

func _yard(r: Rect2) -> void:
	if _tex("lawn") != null:
		return  # the textured lawn needs no stripes
	# Mowed stripes: every other 8px band gets a light dither.
	for y in range(int(r.position.y), int(r.end.y), 16):
		_dither(Rect2(r.position.x, y, r.size.x, mini(8, int(r.end.y) - y)), _lawn_colors[2], 4)


func _field(r: Rect2) -> void:
	_yard(r)
	var line := Palette.PAPER
	_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), line)
	_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), line)
	_rect(Rect2(r.position.x, r.position.y, 1, r.size.y), line)
	_rect(Rect2(r.end.x - 1, r.position.y, 1, r.size.y), line)
	var mid := floorf(r.get_center().x)
	_rect(Rect2(mid, r.position.y, 1, r.size.y), line)
	# Center circle, goal boxes and goals.
	var rad := minf(18.0, r.size.y / 4.0)
	for i in 56:
		var a := TAU * i / 56.0
		_px(mid + roundf(cos(a) * rad), r.get_center().y + roundf(sin(a) * rad), line)
	for left in [true, false]:
		var bx: float = r.position.x if left else r.end.x - 16.0
		var box := Rect2(bx, r.get_center().y - 16, 16, 32)
		_rect(Rect2(box.position, Vector2(box.size.x, 1)), line)
		_rect(Rect2(box.position.x, box.end.y - 1, box.size.x, 1), line)
		_rect(Rect2(box.end.x - 1 if left else box.position.x, box.position.y, 1, box.size.y), line)
		var g := Rect2(r.position.x - 4 if left else r.end.x, r.get_center().y - 8, 4, 16)
		_boxed(g, Palette.PAPER)
		_dither(g.grow(-1), Palette.GRAY)


func _garden(r: Rect2) -> void:
	var soil := _tex("garden")
	if soil != null:
		_rect(r.grow(2), Palette.INK)
		_rect(r.grow(1), Palette.WOOD)
		_rect(Rect2(r.position.x - 1, r.position.y - 1, r.size.x + 2, 1), Palette.CRUST)
		_fill_tex(r, soil)
		return
	_rect(r.grow(1), Palette.WOOD)
	_rect(r, Palette.BARK)
	var flowers := [Palette.PINK, Palette.BUTTER, Palette.SALMON, Palette.PAPER, Palette.SKY]
	# Rows of plants, some flowering.
	for y in range(int(r.position.y) + 2, int(r.end.y) - 1, 4):
		for x in range(int(r.position.x) + 1 + (y % 3), int(r.end.x) - 1, 3):
			_px(x, y, Palette.LEAF)
			_px(x, y + 1, Palette.DEEP_GREEN)
			if _rng.randf() < 0.45:
				_px(x, y - 1, flowers[_rng.randi_range(0, flowers.size() - 1)])


func _path(r: Rect2, ellipse: bool) -> void:
	var sand := _tex("path")
	if sand != null:
		_fill_tex(r, sand, ellipse)
		if ellipse:
			# A ring: the middle is lawn again (whatever covers it, e.g. a pond).
			_fill_tex(r.grow(-10), _lawn(), true)
		return
	var dough := _c(Palette.DOUGH)
	if ellipse:
		_ellipse(r, Palette.DOUGH)
		# A ring: the middle is lawn again (whatever covers it, e.g. a pond).
		_ellipse(r.grow(-10), _lawn_colors[0])
	else:
		_rect(r, Palette.DOUGH)
	for i in int(r.get_area() / 30.0):
		var x := _rng.randf_range(r.position.x, r.end.x)
		var y := _rng.randf_range(r.position.y, r.end.y)
		if _pixel_at(x, y) == dough:
			_px(x, y, Palette.CRUST)


func _sand(r: Rect2) -> void:
	_rect(r.grow(2), Palette.WOOD)
	_rect(r.grow(1), Palette.BARK)
	if _tex("sand") != null:
		_fill_tex(r, _tex("sand"))
		return
	_rect(r, Palette.BUTTER)
	for i in int(r.get_area() / 14.0):
		_px(_rng.randf_range(r.position.x, r.end.x), _rng.randf_range(r.position.y, r.end.y), Palette.DOUGH)


func _sidewalk(r: Rect2) -> void:
	if _tex("sidewalk") != null:
		_fill_tex(r, _tex("sidewalk"))
		return
	_rect(r, Palette.MIST)
	if r.size.x >= r.size.y:
		for x in range(int(r.position.x) + 7, int(r.end.x), 8):
			_rect(Rect2(x, r.position.y, 1, r.size.y), Palette.GRAY)
	else:
		for y in range(int(r.position.y) + 7, int(r.end.y), 8):
			_rect(Rect2(r.position.x, y, r.size.x, 1), Palette.GRAY)


func _driveway(r: Rect2) -> void:
	if _tex("driveway") != null:
		_rect(r.grow(1), Palette.GRAY)
		_fill_tex(r, _tex("driveway"))
		return
	_rect(r, Palette.GRAY)
	for i in int(r.get_area() / 40.0):
		_px(_rng.randf_range(r.position.x, r.end.x), _rng.randf_range(r.position.y, r.end.y), Palette.MIST)


func _road(r: Rect2, ellipse: bool, lines: bool) -> void:
	var asphalt := _c(Palette.SHADE)
	if _tex("road") != null:
		_fill_tex(r, _tex("road"), ellipse)
	elif ellipse:
		_ellipse(r, Palette.SHADE)
	else:
		_rect(r, Palette.SHADE)
	for i in int(r.get_area() / 25.0) if _tex("road") == null else 0:
		var x := _rng.randf_range(r.position.x, r.end.x)
		var y := _rng.randf_range(r.position.y, r.end.y)
		if _pixel_at(x, y) == asphalt:
			_px(x, y, Palette.NIGHT if i % 3 else Palette.GRAY)
	if not lines or ellipse:
		return
	if r.size.x > r.size.y:
		var y := floorf(r.get_center().y)
		for x in range(int(r.position.x) + 4, int(r.end.x), 16):
			_rect(Rect2(x, y - 1, 8, 2), Palette.GOLD)
	else:
		var x := floorf(r.get_center().x)
		for y in range(int(r.position.y) + 4, int(r.end.y), 16):
			_rect(Rect2(x - 1, y, 2, 8), Palette.GOLD)


func _crosswalk(r: Rect2) -> void:
	# Bars span the short side, stacked along the long side.
	if r.size.y >= r.size.x:
		for y in range(int(r.position.y) + 1, int(r.end.y) - 1, 5):
			_rect(Rect2(r.position.x, y, r.size.x, 3), Palette.PAPER)
	else:
		for x in range(int(r.position.x) + 1, int(r.end.x) - 1, 5):
			_rect(Rect2(x, r.position.y, 3, r.size.y), Palette.PAPER)


# Solid props.

func _house(r: Rect2, roof: String) -> void:
	var roof_h := floorf(r.size.y * 0.55)
	_rect(r, Palette.INK)
	# Walls with a darker base line.
	var wall := Rect2(r.position.x + 1, r.position.y + roof_h, r.size.x - 2, r.size.y - roof_h - 1)
	_rect(wall, Palette.PAPER)
	_rect(Rect2(wall.position.x, wall.end.y - 2, wall.size.x, 2), Palette.MIST)
	# Gabled roof: lit upper half, shaded lower half, tile rows, a ridge.
	var rr := Rect2(r.position.x + 1, r.position.y + 1, r.size.x - 2, roof_h - 1)
	_rect(rr, roof)
	var half := floorf(rr.size.y / 2.0)
	_rect(Rect2(rr.position.x, rr.position.y + half, rr.size.x, rr.size.y - half), _shade(roof))
	for y in range(int(rr.position.y) + 3, int(rr.end.y) - 1, 3):
		for x in range(int(rr.position.x) + (y % 6), int(rr.end.x), 6):
			_rect(Rect2(x, y, 3, 1), _shade(roof) if y < rr.position.y + half else Palette.INK)
	_rect(Rect2(rr.position.x, rr.position.y, rr.size.x, 1), _light(roof))
	_rect(Rect2(rr.position.x, rr.position.y + half, rr.size.x, 1), _light(roof))
	_rect(Rect2(rr.position.x, rr.end.y - 1, rr.size.x, 1), Palette.INK)
	# Chimney.
	var ch := Rect2(rr.end.x - 12, r.position.y - 4, 5, 8)
	_boxed(ch, Palette.RUST)
	_rect(Rect2(ch.position.x, ch.position.y, ch.size.x, 1), Palette.SHADE)
	# Door (with step and knob) in the middle, windows either side.
	var door := Rect2(floorf(r.get_center().x) - 3, r.end.y - 11, 7, 10)
	_boxed(door, Palette.WOOD)
	_rect(Rect2(door.position.x + 1, door.position.y + 1, door.size.x - 2, 1), Palette.CRUST)
	_px(door.end.x - 2, door.position.y + 5, Palette.GOLD)
	_rect(Rect2(door.position.x - 1, r.end.y, door.size.x + 2, 2), Palette.GRAY)
	if wall.size.y < 12:
		return
	for wx in [r.position.x + 5, r.end.x - 15]:
		var win := Rect2(wx, wall.position.y + 3, 10, 7)
		_boxed(win, Palette.SKY)
		_rect(Rect2(win.position.x + floorf(win.size.x / 2.0), win.position.y, 1, win.size.y), Palette.INK)
		_rect(Rect2(win.position.x, win.position.y, 3, 2), Palette.WHITE)
		# Flower box under each window.
		_rect(Rect2(win.position.x, win.end.y + 1, win.size.x, 2), Palette.WOOD)
		for fx in range(int(win.position.x), int(win.end.x), 2):
			_px(fx, win.end.y, Palette.PINK if fx % 4 else Palette.BUTTER)


func _shed(r: Rect2, roof: String) -> void:
	_rect(r, Palette.INK)
	var roof_h := floorf(r.size.y * 0.45)
	var walls := Rect2(r.position.x + 1, r.position.y + roof_h, r.size.x - 2, r.size.y - roof_h - 1)
	_rect(walls, Palette.WOOD)
	for x in range(int(walls.position.x) + 3, int(walls.end.x), 4):
		_rect(Rect2(x, walls.position.y, 1, walls.size.y), Palette.BARK)
	var rr := Rect2(r.position.x + 1, r.position.y + 1, r.size.x - 2, roof_h - 1)
	_rect(rr, roof)
	_rect(Rect2(rr.position.x, rr.position.y, rr.size.x, 1), _light(roof))
	_rect(Rect2(rr.position.x, rr.end.y - 1, rr.size.x, 1), _shade(roof))
	if roof == "SKY":
		# Greenhouse: glass panes with plants inside.
		for x in range(int(walls.position.x) + 1, int(walls.end.x) - 1, 5):
			_rect(Rect2(x, walls.position.y + 1, 4, walls.size.y - 2), Palette.SKY)
			_px(x + 1, walls.end.y - 3, Palette.LEAF)
			_px(x + 2, walls.end.y - 2, Palette.LEAF)
		return
	var door := Rect2(floorf(r.get_center().x) - 3, walls.position.y + 2, 6, walls.size.y - 2)
	_boxed(door, Palette.BARK)
	_px(door.end.x - 2, door.position.y + 4, Palette.GOLD)


func _fence(r: Rect2) -> void:
	if r.size.x >= r.size.y:
		_rect(Rect2(r.position.x, r.position.y, r.size.x, 2), Palette.INK)
		_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), Palette.PAPER)
		for x in range(int(r.position.x), int(r.end.x), 3):
			_rect(Rect2(x, r.position.y - 3, 2, 5), Palette.INK)
			_rect(Rect2(x, r.position.y - 3, 1, 4), Palette.PAPER)
	else:
		_rect(Rect2(r.position.x, r.position.y, 2, r.size.y), Palette.INK)
		_rect(Rect2(r.position.x, r.position.y, 1, r.size.y), Palette.PAPER)
		for y in range(int(r.position.y), int(r.end.y), 3):
			_rect(Rect2(r.position.x - 1, y, 4, 2), Palette.INK)
			_rect(Rect2(r.position.x - 1, y, 3, 1), Palette.PAPER)


func _hedge(r: Rect2) -> void:
	_rect(r.grow(1), Palette.INK)
	_rect(r, Palette.DEEP_GREEN)
	_dither(r, Palette.LEAF, 2)
	_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), Palette.GREEN)
	for i in int(r.get_area() / 20.0):
		_px(_rng.randf_range(r.position.x, r.end.x), _rng.randf_range(r.position.y + 1, r.end.y), Palette.GREEN)


func _pond(r: Rect2) -> void:
	_ellipse(r.grow(5), Palette.DOUGH)  # sandy shore
	for i in 50:
		var a := _rng.randf() * TAU
		var p := r.get_center() + Vector2(cos(a) * (r.size.x / 2.0 + 3.0), sin(a) * (r.size.y / 2.0 + 3.0))
		_px(p.x, p.y, Palette.CRUST)
	_ellipse_outlined(r, Palette.OCEAN)
	_ellipse(Rect2(r.position + r.size * 0.06, r.size * 0.88), Palette.BLUE)
	_ellipse(Rect2(r.position + r.size * Vector2(0.32, 0.3), r.size * 0.36), Palette.OCEAN)
	for i in 10:
		var at := r.position + Vector2(r.size.x * _rng.randf_range(0.2, 0.8), r.size.y * _rng.randf_range(0.2, 0.8))
		_rect(Rect2(at.round(), Vector2(_rng.randi_range(3, 6), 1)), Palette.SKY)
	# Lily pads, some with a flower.
	for i in 6:
		var at := r.position + Vector2(r.size.x * _rng.randf_range(0.15, 0.8), r.size.y * _rng.randf_range(0.2, 0.75))
		_ellipse(Rect2(at.round(), Vector2(7, 4)), Palette.LEAF)
		_px(at.x + 4, at.y + 2, Palette.DEEP_GREEN)
		if i % 2 == 0:
			_px(at.x + 2, at.y + 1, Palette.PINK)
	# Reeds and cattails along the shore.
	for i in 18:
		var a := _rng.randf() * TAU
		var p := r.get_center() + Vector2(cos(a) * (r.size.x / 2.0 - 3.0), sin(a) * (r.size.y / 2.0 - 3.0))
		for k in 3:
			_rect(Rect2(p.x + k * 2, p.y - 4 + k % 2, 1, 4), Palette.DEEP_GREEN if k != 1 else Palette.LEAF)
		_rect(Rect2(p.x + 2, p.y - 6, 1, 2), Palette.BARK)


func _canopy_rect(r: Rect2) -> Rect2:
	return Rect2(r.position + Vector2(-7, -16), r.size + Vector2(14, 12))


func _tree(r: Rect2, leaf: String) -> void:
	var trunk := Rect2(floorf(r.get_center().x) - 2, r.end.y - 7, 4, 8)
	_boxed(trunk, Palette.WOOD)
	_rect(Rect2(trunk.position.x, trunk.position.y, 1, trunk.size.y), Palette.CRUST)
	var canopy := _canopy_rect(r)
	_ellipse_outlined(canopy, _shade(leaf))
	var mid := Rect2(canopy.position + Vector2(1, 1), canopy.size - Vector2(4, 5))
	_ellipse(mid, leaf)
	_ellipse(Rect2(canopy.position + Vector2(4, 2), canopy.size * 0.45), _light(leaf))
	for i in 12:
		_px(_rng.randf_range(mid.position.x + 3, mid.end.x - 3), _rng.randf_range(mid.position.y + 3, mid.end.y - 2), _shade(leaf))
	if leaf == "LEAF" and int(r.position.x) % 3 == 0:
		# Some trees have apples.
		for i in 3:
			_px(_rng.randf_range(mid.position.x + 4, mid.end.x - 4), _rng.randf_range(mid.position.y + 4, mid.end.y - 3), Palette.RED)


func _bush(r: Rect2, flower: String) -> void:
	_ellipse_outlined(r, Palette.DEEP_GREEN)
	_ellipse(Rect2(r.position + Vector2(1, 1), r.size * 0.7), Palette.LEAF)
	for i in int(r.get_area() / 12.0) + 2:
		_px(_rng.randf_range(r.position.x + 2, r.end.x - 2), _rng.randf_range(r.position.y + 2, r.end.y - 2), flower)


func _pool(r: Rect2) -> void:
	_boxed(r, Palette.PAPER)
	for x in range(int(r.position.x) + 3, int(r.end.x), 4):
		_px(x, r.position.y, Palette.MIST)
		_px(x, r.end.y - 1, Palette.MIST)
	var water := r.grow(-3)
	_rect(water.grow(1), Palette.INK)
	_rect(water, Palette.BLUE)
	for y in range(int(water.position.y) + 2, int(water.end.y), 4):
		for x in range(int(water.position.x) + 1 + (y % 8) / 2, int(water.end.x) - 2, 8):
			_rect(Rect2(x, y, 3, 1), Palette.SKY)
	var lx := water.end.x - 6
	_rect(Rect2(lx, water.position.y - 2, 1, 5), Palette.GRAY)
	_rect(Rect2(lx + 3, water.position.y - 2, 1, 5), Palette.GRAY)
	_rect(Rect2(lx, water.position.y + 1, 4, 1), Palette.GRAY)


func _car(r: Rect2, col: String) -> void:
	if r.size.x >= r.size.y:
		for w in [Vector2(r.position.x + 2, r.position.y - 1), Vector2(r.end.x - 6, r.position.y - 1), Vector2(r.position.x + 2, r.end.y - 1), Vector2(r.end.x - 6, r.end.y - 1)]:
			_rect(Rect2(w, Vector2(4, 2)), Palette.INK)
		_boxed(r, col)
		_rect(Rect2(r.position, Vector2(r.size.x, 1)), _light(col))
		var cab := Rect2(r.position.x + floorf(r.size.x * 0.3), r.position.y + 1, floorf(r.size.x * 0.4), r.size.y - 2)
		_rect(cab, _shade(col))
		_rect(Rect2(cab.end.x, cab.position.y, 2, cab.size.y), Palette.SKY)
		_rect(Rect2(cab.position.x - 2, cab.position.y, 2, cab.size.y), Palette.SKY)
		_px(r.end.x - 1, r.position.y + 1, Palette.BUTTER)
		_px(r.end.x - 1, r.end.y - 2, Palette.BUTTER)
	else:
		for w in [Vector2(r.position.x - 1, r.position.y + 2), Vector2(r.end.x - 1, r.position.y + 2), Vector2(r.position.x - 1, r.end.y - 6), Vector2(r.end.x - 1, r.end.y - 6)]:
			_rect(Rect2(w, Vector2(2, 4)), Palette.INK)
		_boxed(r, col)
		_rect(Rect2(r.position, Vector2(r.size.x, 1)), _light(col))
		var cab := Rect2(r.position.x + 1, r.position.y + floorf(r.size.y * 0.3), r.size.x - 2, floorf(r.size.y * 0.4))
		_rect(cab, _shade(col))
		_rect(Rect2(cab.position.x, cab.position.y - 2, cab.size.x, 2), Palette.SKY)
		_rect(Rect2(cab.position.x, cab.end.y, cab.size.x, 2), Palette.SKY)
		_px(r.position.x + 1, r.end.y - 1, Palette.BUTTER)
		_px(r.end.x - 2, r.end.y - 1, Palette.BUTTER)


func _bench(r: Rect2) -> void:
	_boxed(r, Palette.WOOD)
	for y in range(int(r.position.y) + 1, int(r.end.y), 2):
		_rect(Rect2(r.position.x, y, r.size.x, 1), Palette.CRUST)
	_rect(Rect2(r.position.x + 1, r.end.y + 1, 1, 2), Palette.INK)
	_rect(Rect2(r.end.x - 2, r.end.y + 1, 1, 2), Palette.INK)


func _swing(r: Rect2) -> void:
	# Posts at each end, a bar on top, two seats on chains.
	_boxed(Rect2(r.position.x, r.position.y, r.size.x, 2), Palette.RED)
	for x in [r.position.x, r.end.x - 2]:
		_boxed(Rect2(x, r.position.y, 2, r.size.y), Palette.RED)
	for i in 2:
		var sx := floorf(r.position.x + r.size.x * (0.25 + 0.35 * i))
		_rect(Rect2(sx, r.position.y + 2, 1, r.size.y - 5), Palette.GRAY)
		_rect(Rect2(sx + 4, r.position.y + 2, 1, r.size.y - 5), Palette.GRAY)
		_boxed(Rect2(sx, r.end.y - 4, 5, 2), Palette.BUTTER)


func _mailbox(r: Rect2, col: String) -> void:
	_boxed(Rect2(floorf(r.get_center().x), r.position.y + 3, 1, r.size.y - 3), Palette.WOOD)
	_boxed(Rect2(r.position.x, r.position.y, r.size.x, 3), col)
	_px(r.end.x, r.position.y - 1, Palette.RED)


func _lamp(r: Rect2) -> void:
	var x := floorf(r.get_center().x)
	_boxed(Rect2(x, r.position.y - 8, 1, r.size.y + 8), Palette.SHADE)
	_boxed(Rect2(x - 1, r.position.y - 11, 3, 3), Palette.BUTTER)
	_px(x, r.position.y - 10, Palette.WHITE)


## Lawn texture (64x64, tiles seamlessly): base color plus scattered tufts in
## a darker and a lighter shade and a few tiny flowers, from a fixed seed.
func _lawn() -> Image:
	var tex := _load_image(_ground_textures.get("lawn", ""))
	if tex != null:
		return tex
	var img := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Palette.color(_lawn_colors[0]))
	var r := RandomNumberGenerator.new()
	r.seed = 7
	for i in 18:
		var t := Vector2i(r.randi_range(0, 61), r.randi_range(1, 63))
		var col := Palette.color(_lawn_colors[1] if i % 3 != 0 else _lawn_colors[2])
		img.set_pixelv(t, col)
		img.set_pixelv(t + Vector2i(1, -1), col)
		img.set_pixelv(t + Vector2i(2, 0), col)
	for i in 3:
		img.set_pixelv(Vector2i(r.randi_range(0, 63), r.randi_range(0, 63)), Palette.color(Palette.BUTTER if i % 2 else Palette.PAPER))
	return img

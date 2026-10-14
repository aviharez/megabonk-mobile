class_name HomeScene
extends Control
## The home screen's backdrop (Phase 9, after the SpriteCook home concept): a
## night street with lit houses, a street lamp and an empty stone plinth
## (assets/ui/home/backdrop.png, 1 art px = 1 UI px, cut by
## tools/art/home_art.py), the picked hero standing on the plinth (no name:
## the art has no sign or plate), and round critters peeking in at the edges. Sprites are
## 2x, like the concept. The menu places it: `plinth_at` is where the plinth's
## top centre goes, `critters` where each critter's feet go.

const DIR := "res://assets/ui/home/"
const K := 1  # critter scale (kit v2: small critters round the hero)
## Critter art: blue and purple face right (left edge), green and red left.
const CRITTERS := ["critter_blue", "critter_green", "critter_purple", "critter_red"]

## UI position of the plinth's top centre (the hero's feet).
var plinth_at := Vector2(77, 171):
	set(v):
		plinth_at = v.floor()
		queue_redraw()
## Feet position of each critter in CRITTERS order.
var critters: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]:
	set(v):
		critters = v
		queue_redraw()
var hero_id := "sir_loaf"
## The hero and critters (Home); menu screens show the street only.
var show_hero := true
## Hero scale on the plinth (kit v2: heroes 3x on stages).
const HERO_K := 3

var _backdrop: Texture2D
var _anchor := Vector2i(88, 267)  # plinth top centre in the backdrop
var _critter_tex: Array[Texture2D] = []
var _hero := {}
var _t := 0.0
var _frame := 0


func _init() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE


func _ready() -> void:
	if not show_hero:
		plinth_at = Vector2(floorf(size.x / 2.0), floorf(size.y * 0.55))
		resized.connect(func() -> void: plinth_at = Vector2(floorf(size.x / 2.0), floorf(size.y * 0.55)))
	_backdrop = _tex(DIR + "backdrop_night.png")
	var meta = JSON.parse_string(FileAccess.get_file_as_string(DIR + "backdrop.json"))
	if meta is Dictionary:
		_anchor = Vector2i(int(meta.plinth[0]), int(meta.plinth[1]))
	for c: String in CRITTERS:
		_critter_tex.append(_tex(DIR + c + ".png"))
	set_hero(hero_id)


static func _tex(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var res = load(path)
	return ImageTexture.create_from_image(res) if res is Image else res


## Shows this hero's idle sheet on the plinth.
func set_hero(id: String) -> void:
	hero_id = id
	var c := GameData.shared().get_entry("characters", id)
	var sheets: Dictionary = c.get("sheets", {})
	_hero = EnemySystem.load_sheet({"sheet": sheets.get("idle", sheets.get("walk", ""))})
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	var fps: float = _hero.get("fps", 8.0) if not _hero.is_empty() else 8.0
	var f := int(_t * fps) % maxi(1, int(_hero.get("frames", 1)))
	if f != _frame:
		_frame = f
		queue_redraw()
	# Critters hop on their own beat (whole pixels, so redraw only on change).
	if int(_t * 10.0) != int((_t - delta) * 10.0):
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.color(Palette.BG))
	if _backdrop != null:
		var at := plinth_at - Vector2(_anchor)
		# Sky above the art in its own top colour; the art's foot is BG already.
		draw_rect(Rect2(0, 0, size.x, at.y), Palette.color(Palette.SURFACE))
		draw_texture(_backdrop, at)
	if not show_hero:
		return
	# Critters: a short hop every couple of seconds, each on its own phase.
	for i in mini(_critter_tex.size(), critters.size()):
		var tex := _critter_tex[i]
		if tex == null or critters[i].x < -50.0:
			continue
		var ph := fmod(_t + i * 0.7, 2.6)
		var hop := -2.0 if ph < 0.15 else (-1.0 if ph < 0.3 else 0.0)
		var s := tex.get_size() * K
		draw_texture_rect(tex, Rect2((critters[i] - Vector2(s.x / 2.0, s.y - hop)).floor(), s), false)
	if not _hero.is_empty():
		var tex: Texture2D = _hero.texture
		var fw := tex.get_width() / int(_hero.frames)
		var fh := tex.get_height()
		var origin: Vector2 = _hero.get("origin", Vector2(fw / 2.0, fh))
		draw_texture_rect_region(tex, Rect2(plinth_at - origin.floor() * HERO_K, Vector2(fw, fh) * HERO_K),
				Rect2(_frame * fw, 0, fw, fh))

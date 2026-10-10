class_name TitleScene
extends Control
## The main menu's living backdrop: a night sky (stars that twinkle, a moon),
## and a strip of town at 2x where the picked hero runs on the spot while the
## swarm chases them and the houses, trees and grass scroll past (parallax).
## Everything is existing run art (props, ground tile, hero and creature
## sheets) drawn in whole pixels; colours are palette only.

const K := 2  # pixel scale of the town strip
const STRIP_H := 48  # strip height in strip pixels (96 UI px)
const PROPS := ["house", "tree", "lamp", "pine", "mailbox", "house", "bush", "tree", "car", "shed", "pine", "bench"]
const SWARM := ["blob", "skitter", "blob", "chomper", "blob", "skitter"]

## UI y where the strip's top (the horizon) sits.
var horizon := 160.0:
	set(v):
		horizon = v
		queue_redraw()
var hero_id := "sir_loaf"

var _t := 0.0
var _stars: Array = []  # [Vector2, phase]
var _props: Array = []  # [Texture2D, x (strip px)]
var _grass: Texture2D
var _hero := {}
var _swarm: Array = []  # [sheet, x, phase]
var _gems: Array = []  # [Texture2D, x, y, vy, life]
var _gem_tex: Array[Texture2D] = []
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE


func _ready() -> void:
	_rng.seed = 7
	for i in 60:
		_stars.append([Vector2(_rng.randi_range(0, 400), _rng.randi_range(0, 400)), _rng.randf() * TAU, _rng.randi_range(0, 3)])
	var x := 0.0
	for id: String in PROPS:
		var path := "res://assets/props/%s.png" % id
		if ResourceLoader.exists(path):
			var tex := _tex(path)
			_props.append([tex, x])
			x += tex.get_width() + _rng.randi_range(4, 14)
	_props_span = x
	if ResourceLoader.exists("res://assets/tiles/grass.png"):
		_grass = _tex("res://assets/tiles/grass.png")
	set_hero(hero_id)
	var db := GameData.shared()
	for i in SWARM.size():
		var sheet := EnemySystem.load_sheet(db.get_entry("enemies", SWARM[i]))
		if not sheet.is_empty():
			_swarm.append([sheet, 4.0 + i * 9.0, _rng.randf() * TAU])
	for g in ["gem_small", "gem_mid", "gem_big"]:
		var p := "res://assets/gems/%s.png" % g
		if ResourceLoader.exists(p):
			_gem_tex.append(_tex(p))


var _props_span := 1.0


## Some art is imported as Image (map props): a texture either way.
static func _tex(path: String) -> Texture2D:
	var res = load(path)
	if res is Image:
		return ImageTexture.create_from_image(res)
	return res


## Shows this hero's walk sheet (falls back to idle).
func set_hero(id: String) -> void:
	hero_id = id
	var c := GameData.shared().get_entry("characters", id)
	var sheets: Dictionary = c.get("sheets", {})
	_hero = EnemySystem.load_sheet({"sheet": sheets.get("walk", sheets.get("idle", ""))})
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	# A gem now and then pops out of the swarm and bounces away.
	if _gem_tex.size() > 0 and _rng.randf() < delta * 1.2:
		_gems.append([_gem_tex[_rng.randi_range(0, _gem_tex.size() - 1)], _rng.randf_range(8.0, 40.0), 38.0, -_rng.randf_range(28.0, 40.0), 1.2])
	for g: Array in _gems:
		g[3] += 90.0 * delta
		g[2] = minf(g[2] + g[3] * delta, 40.0)
		g[1] -= 30.0 * delta
		g[4] -= delta
	_gems = _gems.filter(func(g: Array) -> bool: return g[4] > 0.0)
	queue_redraw()


func _draw() -> void:
	var w := size.x
	_draw_sky(w)
	draw_set_transform(Vector2(0, floorf(horizon)), 0.0, Vector2(K, K))
	_draw_strip(ceilf(w / K))
	draw_set_transform(Vector2.ZERO)


func _draw_sky(w: float) -> void:
	draw_rect(Rect2(0, 0, w, size.y), Palette.color(Palette.NIGHT))
	# Toward the horizon the sky goes DEEP_BLUE in dithered bands.
	var band := 6.0
	for i in 4:
		var y := horizon - band * (4 - i) - 2.0
		draw_texture_rect(DitherDim.pattern(Palette.DEEP_BLUE, 4 + i * 3), Rect2(0, y, w, band), true)
	# Stars: single pixels, a few twinkle between MIST and PAPER, some blink off.
	for s: Array in _stars:
		var p: Vector2 = s[0]
		if p.x >= w or p.y >= horizon - 30.0:
			continue
		var tw := sin(_t * 2.0 + s[1])
		if s[2] == 0 and tw < -0.6:
			continue
		draw_rect(Rect2(p, Vector2.ONE), Palette.color(Palette.PAPER if tw > 0.3 else Palette.GRAY))
		if s[2] == 1 and tw > 0.85:
			for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
				draw_rect(Rect2(p + o, Vector2.ONE), Palette.color(Palette.MIST))
	# The moon: a round cookie with bites of shade.
	var mc := Vector2(w - 34.0, horizon * 0.42).floor()
	var r := 11
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var d := x * x + y * y
			if d <= r * r:
				var c := Palette.BUTTER
				if d > (r - 1) * (r - 1):
					c = Palette.GOLD
				elif (x - 3) * (x - 3) + (y + 2) * (y + 2) <= 5 or (x + 4) * (x + 4) + (y - 4) * (y - 4) <= 3 or (x + 1) * (x + 1) + (y + 5) * (y + 5) <= 2:
					c = Palette.GOLD
				draw_rect(Rect2(mc + Vector2(x, y), Vector2.ONE), Palette.color(c))


func _draw_strip(sw: float) -> void:
	# Far row: props along the horizon, scrolling slowly.
	var base := 20.0
	var scroll := fmod(_t * 6.0, _props_span)
	for rep in 2:
		for p: Array in _props:
			var tex: Texture2D = p[0]
			var x := floorf(p[1] - scroll + rep * _props_span)
			if x > sw or x + tex.get_width() < 0:
				continue
			draw_texture(tex, Vector2(x, base - tex.get_height() + 6))
	# Ground: the grass tile, scrolling faster, with a dark lip at the top.
	var gy := base + 4.0
	if _grass != null:
		var gw := float(_grass.get_width())
		var gs := fmod(_t * 24.0, gw)
		draw_texture_rect(_grass, Rect2(-floorf(gs), gy, sw + gw, STRIP_H - gy), true)
	else:
		draw_rect(Rect2(0, gy, sw, STRIP_H - gy), Palette.color(Palette.LEAF))
	draw_rect(Rect2(0, gy, sw, 1), Palette.color(Palette.DEEP_GREEN))
	# Bottom edge fades into the night in dithered steps.
	for i in 3:
		draw_texture_rect(DitherDim.pattern(Palette.NIGHT, 4 + i * 5), Rect2(0, STRIP_H - 6 + i * 2, sw, 2), true)
	draw_rect(Rect2(0, STRIP_H, sw, 400), Palette.color(Palette.NIGHT))
	# The swarm, bobbing and drifting back and forth behind the hero.
	var feet := 40.0
	var hx := floorf(sw * 0.62)
	for g: Array in _gems:
		draw_texture(g[0], Vector2(floorf(g[1]), floorf(g[2]) - g[0].get_height()))
	for m: Array in _swarm:
		var sh: Dictionary = m[0]
		var x := floorf(m[1] + sin(_t * 1.3 + m[2]) * 4.0 + (hx - 66.0))
		var hop := floorf(absf(sin(_t * 7.0 + m[2])) * 2.0)
		_sheet(sh, Vector2(x, feet - hop), _t + m[2])
	if not _hero.is_empty():
		_shadow(Vector2(hx, feet))
		_sheet(_hero, Vector2(hx, feet), _t * 1.5)
		# Sweat drops fly off the hero now and then (goofy panic).
		var ph := fmod(_t, 1.6)
		if ph < 0.5:
			var o := Vector2(-4 - ph * 14.0, -20 - ph * 8.0 + ph * ph * 30.0).floor()
			draw_rect(Rect2(Vector2(hx, feet) + o, Vector2(1, 2)), Palette.color(Palette.SKY))
			draw_rect(Rect2(Vector2(hx, feet) + o + Vector2(0, -1), Vector2(1, 1)), Palette.color(Palette.WHITE))


func _shadow(at: Vector2) -> void:
	draw_rect(Rect2(at + Vector2(-6, -1), Vector2(12, 2)), Palette.color(Palette.DEEP_GREEN))


## One frame of an animated sheet with its feet (origin) at `at`.
func _sheet(sh: Dictionary, at: Vector2, t: float) -> void:
	var tex: Texture2D = sh.texture
	var frames := int(sh.frames)
	var start := 0
	var fps := float(sh.fps)
	if sh.has("clips") and sh.clips.has("walk"):
		start = int(sh.clips.walk.start)
		frames = int(sh.clips.walk.frames)
	var fw := tex.get_width() / int(sh.frames)
	var fh := tex.get_height()
	var f := start + int(t * fps) % frames
	var origin: Vector2 = sh.get("origin", Vector2(fw / 2.0, fh))
	draw_texture_rect_region(tex, Rect2((at - origin).floor(), Vector2(fw, fh)), Rect2(f * fw, 0, fw, fh))

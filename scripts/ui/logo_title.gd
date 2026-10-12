class_name LogoTitle
extends Control
## The "Mobbed!" logo (Phase 9, after the SpriteCook home concept): one Titan
## One label per letter in the LOGO style (GOLD, thick NIGHT outline, INK
## drop) plus an outer SHADE rim (a stacked outline, the concept's light edge
## that keeps the word off the night sky), letters overlapping, tilted and
## bobbing. A small shader turns the
## fill's top rows BUTTER and its bottom rows ORANGE (the concept's lit top and
## shaded foot; it only touches fill pixels, so outline and drop stay as they
## are). Leaves and a radish critter (SpriteCook art, assets/ui/home/) sit on
## top of the letters at 1x (the concept's size; at 2x they cover the top bar).
## Lays itself out centred in its own width.

const DECO_DIR := "res://assets/ui/home/"
const TILT := [-5.0, 3.0, -3.0, 4.0, -3.0, 3.0, 7.0]
const BOB := [2.0, -1.0, 1.0, -2.0, 1.0, -1.0, 0.0]
## [art, letter index it sits on, offset of its bottom centre from that letter's top centre]
const DECO := [
	["leaf_a", 1, Vector2(0, 11)],
	["leaf_c", 4, Vector2(-5, 11)],
	["leaf_b", 5, Vector2(3, 11)],
	["radish", 4, Vector2(2, 10)],
]
const DECO_K := 1
## Outer rim around the outline: [px, colour].
const RIM := [2, Palette.SHADE]
const SHADER := """
shader_type canvas_item;
uniform vec4 fill_color;
uniform vec4 top_color;
uniform vec4 foot_color;
uniform float top_y;
uniform float foot_y;
varying float local_y;
void vertex() { local_y = VERTEX.y; }
void fragment() {
	if (distance(COLOR.rgb, fill_color.rgb) < 0.02) {
		if (local_y < top_y) { COLOR.rgb = top_color.rgb; }
		else if (local_y > foot_y) { COLOR.rgb = foot_color.rgb; }
	}
}
"""
## Gap between letters (negative: they overlap their outlines).
const TRACK := -3.0
## The concept's lettering is condensed and tall; Titan One isn't, so each
## letter is stretched (text still rasterises at device resolution).
const STRETCH := Vector2(0.92, 1.3)

var text := "Mobbed!"
## Bob the letters (off in tests and still renders).
var animate := true

var _letters: Array[Label] = []
var _widths: Array[float] = []
var _deco: Array[TextureRect] = []
var _t := 0.0
static var _material: ShaderMaterial


func _init(t := "Mobbed!") -> void:
	text = t
	mouse_filter = MOUSE_FILTER_IGNORE


func _ready() -> void:
	var s := Fonts.style("LOGO").duplicate() as LabelSettings
	s.add_stacked_outline()
	s.set_stacked_outline_size(0, RIM[0])
	s.set_stacked_outline_color(0, Palette.color(RIM[1]))
	for ch in text:
		var l := Fonts.label(ch, "LOGO")
		l.label_settings = s
		l.material = _mat()
		add_child(l)
		_letters.append(l)
		_widths.append(Fonts.width(ch, "LOGO"))
	for d: Array in DECO:
		var tr := TextureRect.new()
		tr.texture = HomeScene._tex(DECO_DIR + d[0] + ".png")
		tr.mouse_filter = MOUSE_FILTER_IGNORE
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		add_child(tr)
		_deco.append(tr)
	resized.connect(_place)
	_place()


## Width of the whole word, letters overlapped.
func word_width() -> float:
	var w := 0.0
	for x in _widths:
		w += x * STRETCH.x + TRACK
	return w - TRACK


static func _mat() -> ShaderMaterial:
	if _material == null:
		var sh := Shader.new()
		sh.code = SHADER
		_material = ShaderMaterial.new()
		_material.shader = sh
		var f := Fonts.TITLE_FONT
		var fs: int = Fonts.STYLES.LOGO[1]
		# Titan One's caps reach about 0.72 em above the baseline: the top band
		# is the caps' top fifth, the foot band the last sixth above the baseline.
		var base := f.get_ascent(fs)
		var cap := fs * 0.72
		_material.set_shader_parameter("fill_color", Palette.color(Fonts.STYLES.LOGO[2]))
		_material.set_shader_parameter("top_color", Palette.color(Palette.BUTTER))
		_material.set_shader_parameter("foot_color", Palette.color(Palette.ORANGE))
		_material.set_shader_parameter("top_y", base - cap + cap * 0.14)
		_material.set_shader_parameter("foot_y", base - cap * 0.24)
	return _material


func _process(delta: float) -> void:
	if not animate:
		return
	_t += delta
	_place()


func _place() -> void:
	var x := floorf((size.x - word_width()) / 2.0)
	var fs: int = Fonts.STYLES.LOGO[1]
	var asc := Fonts.TITLE_FONT.get_ascent(fs)
	var cap := fs * 0.72
	for i in _letters.size():
		var l := _letters[i]
		# Each letter bobs a pixel on its own beat.
		var bob: float = BOB[i % BOB.size()]
		if animate and fmod(_t * 1.6 + i * 0.45, 3.0) < 0.25:
			bob -= 1.0
		var pivot := Vector2(_widths[i] / 2.0 + Fonts.STYLES.LOGO[3], asc - cap / 2.0)
		# Scaled about the pivot: place the pivot at the letter's centre.
		var centre := Vector2(x + _widths[i] * STRETCH.x / 2.0, bob + 2.0 + cap * STRETCH.y / 2.0)
		l.pivot_offset = pivot
		l.scale = STRETCH
		l.position = (centre - pivot).floor()
		l.rotation_degrees = TILT[i % TILT.size()]
		x += _widths[i] * STRETCH.x + TRACK
	for j in _deco.size():
		var d: Array = DECO[j]
		var tr := _deco[j]
		var li: int = d[1]
		if li >= _letters.size() or tr.texture == null:
			continue
		var l := _letters[li]
		# The letter's cap top (outline included) after the stretch.
		var top := l.position + l.pivot_offset - Vector2(0, (cap / 2.0 + Fonts.STYLES.LOGO[3]) * STRETCH.y)
		var sz := tr.texture.get_size() * DECO_K
		var at: Vector2 = top + d[2] - Vector2(sz.x / 2.0, sz.y)
		tr.position = at.floor()
		tr.size = sz

class_name Fonts
extends RefCounted
## Phase 9 type: Titan One (TITLE_FONT) for titles, buttons, names and numbers,
## Inter at weight 900 (body()) for body text, never under 7 px. Both import
## with antialiasing off, no hinting and subpixel positioning (see their
## .import files): the root viewport draws UI text at device resolution, so
## text is smooth and every pixel stays a palette colour.
##
## Text is styled by name, never by number: style("NAME") is a cached
## LabelSettings from STYLES. Custom _draw() code uses draw(), which draws the
## same drop, outline and fill. fit() shrinks a label until its text fits.
##
## BOLD / SMALL / bold() / fitting() are the old names, kept while code moves
## to the styles: BOLD is now Titan One and SMALL Inter 900 (both at SIZE).

const TITLE_FONT := preload("res://assets/fonts/titan_one/TitanOne-Regular.ttf")
## Inter at weight 900 (a FontVariation of the variable font); also the
## theme's default font (assets/ui/theme.tres) at 7 px.
const BODY_FONT := preload("res://assets/fonts/inter/inter_900.tres")

## name: [font ("T" Titan / "I" Inter), size, colour, outline px, outline colour, drop px]
const STYLES := {
	"LOGO": ["T", 34, Palette.GOLD, 5, Palette.NIGHT, 3],
	"BIG_BUTTON": ["T", 26, Palette.INK, 0, Palette.INK, 0],
	"TITLE": ["T", 15, Palette.INK, 0, Palette.INK, 0],
	"BANNER": ["T", 14, Palette.RED, 4, Palette.INK, 2],
	"NAME": ["T", 10, Palette.PAPER, 0, Palette.INK, 0],
	"NUM": ["T", 10, Palette.WHITE, 0, Palette.INK, 0],
	"NUM_WORLD": ["T", 9, Palette.WHITE, 3, Palette.INK, 0],
	"BAR_NUM": ["T", 7, Palette.WHITE, 3, Palette.INK, 0],
	"RIBBON": ["T", 8, Palette.PAPER, 3, Palette.WINE, 0],
	"NAV": ["T", 7, Palette.PAPER, 0, Palette.INK, 0],
	"TAG": ["T", 7, Palette.WHITE, 0, Palette.INK, 0],
	"BODY": ["I", 7, Palette.MIST, 0, Palette.INK, 0],
	"CHANGE": ["I", 8, Palette.LIME, 0, Palette.INK, 0],
	"HIT": ["I", 7, Palette.WHITE, 3, Palette.INK, 0],
	"CRIT": ["T", 12, Palette.BUTTER, 4, Palette.RED, 2],
	"SPLASH": ["T", 22, Palette.GOLD, 4, Palette.INK, 2],
}
## Smallest sizes fit() may shrink to.
const MIN_TITLE := 6
const MIN_BODY := 7

const BOLD := TITLE_FONT
const SMALL := BODY_FONT
const SIZE := 8

static var _styles := {}


## Inter at weight 900.
static func body() -> Font:
	return BODY_FONT


static func font_of(style_name: String) -> Font:
	return TITLE_FONT if STYLES[style_name][0] == "T" else body()


## The named style (shared, don't edit it), optionally in another colour or size.
static func style(style_name: String, color := -1, size := -1) -> LabelSettings:
	var key := "%s/%d/%d" % [style_name, color, size]
	if _styles.has(key):
		return _styles[key]
	var d: Array = STYLES[style_name]
	var s := LabelSettings.new()
	s.font = font_of(style_name)
	s.font_size = d[1] if size < 0 else size
	s.font_color = Palette.color(d[2] if color < 0 else color)
	s.line_spacing = -1
	if d[3] > 0:
		s.outline_size = d[3]
		s.outline_color = Palette.color(d[4])
	if d[5] > 0:
		s.shadow_size = maxi(d[3], 1)
		s.shadow_color = Palette.color(Palette.INK)
		s.shadow_offset = Vector2(0, d[5])
	s.set_meta("style", style_name)
	s.set_meta("color", color)
	_styles[key] = s
	return s


## A label in a named style (mouse-transparent, sized to its text).
static func label(text: String, style_name: String, color := -1) -> Label:
	var l := Label.new()
	l.text = text
	l.label_settings = style(style_name, color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Width of `text` in a style (or at `size`), outline not included.
static func width(text: String, style_name: String, size := -1) -> float:
	var fs: int = STYLES[style_name][1] if size < 0 else size
	return font_of(style_name).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


## Line height of a style (or at `size`).
static func height(style_name: String, size := -1) -> float:
	var fs: int = STYLES[style_name][1] if size < 0 else size
	return font_of(style_name).get_height(fs)


## Shrinks `l`'s style one size at a time until its text fits `max_width`
## (outline included), down to the font's minimum; past that it wraps, never
## clips. Returns the size used.
static func fit(l: Label, max_width: float, min_size := -1) -> int:
	var s := l.label_settings
	var sname: String = s.get_meta("style", "BODY") if s != null else "BODY"
	var color: int = s.get_meta("color", -1) if s != null else -1
	var fs: int = STYLES[sname][1]
	var floor_size := min_size if min_size > 0 else (MIN_TITLE if STYLES[sname][0] == "T" else MIN_BODY)
	var pad: float = STYLES[sname][3] * 2
	while fs > floor_size and width(l.text, sname, fs) + pad > max_width:
		fs -= 1
	l.label_settings = style(sname, color, fs)
	if width(l.text, sname, fs) + pad > max_width:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = max_width
		l.size.x = max_width
	return fs


## Draws `text` in a style for _draw() code, top-left at `pos` like a Label:
## drop shadow, outline, then fill. `width` > 0 with `align` centres or
## right-aligns inside that width.
static func draw(ci: CanvasItem, text: String, pos: Vector2, style_name: String, color := -1,
		max_width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT, size := -1) -> void:
	var d: Array = STYLES[style_name]
	var f := font_of(style_name)
	var fs: int = d[1] if size < 0 else size
	var base := Vector2(pos.x, pos.y + f.get_ascent(fs)).round()
	var outline: int = d[3]
	if d[5] > 0:
		var sp: Vector2 = base + Vector2(0, d[5])
		if outline > 0:
			ci.draw_string_outline(f, sp, text, align, max_width, fs, outline, Palette.color(Palette.INK))
		ci.draw_string(f, sp, text, align, max_width, fs, Palette.color(Palette.INK))
	if outline > 0:
		ci.draw_string_outline(f, base, text, align, max_width, fs, outline, Palette.color(d[4]))
	ci.draw_string(f, base, text, align, max_width, fs, Palette.color(d[2] if color < 0 else color))


## Puts a label in Titan One (NAME size).
static func bold(l: Control) -> Control:
	l.add_theme_font_override("font", TITLE_FONT)
	l.add_theme_font_size_override("font_size", 9)
	return l


## BOLD (Titan) if `text` fits in `width` px at SIZE, else SMALL (Inter).
static func fitting(text: String, width_px: float) -> Font:
	if BOLD.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x <= width_px:
		return BOLD
	return SMALL

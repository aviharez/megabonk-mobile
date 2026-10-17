class_name Fonts
extends RefCounted
## Kit v2 type (docs/BRIEF.md "Update 1"): Lilita One (TITLE_FONT, "D" in
## STYLES) for titles, names, numbers and button labels, outlined in INK (no
## drop); Inter at weight 800 (body()) for body text, never outlined,
## never under 6 px. Sizes in game px: hero names 20, screen titles 14, names
## and buttons 9, numbers 10, body 7, small 6. Both fonts import with
## antialiasing off, no hinting and subpixel positioning (their .import
## files): the root viewport draws UI text at device resolution, so text is
## smooth and every pixel stays a palette colour.
##
## Text is styled by name, never by number: style("NAME") is a cached
## LabelSettings from STYLES. Custom _draw() code uses draw(), which draws the
## same drop, outline and fill. fit() shrinks a label until its text fits.
##
## BOLD / SMALL / bold() / fitting() are the old names: BOLD is Lilita One,
## SMALL Inter 800.

const TITLE_FONT := preload("res://assets/fonts/lilita_one/LilitaOne-Regular.ttf")
## Inter at weight 800 (a FontVariation of the variable font); also the
## theme's default font (assets/ui/theme.tres) at 7 px.
const BODY_FONT := preload("res://assets/fonts/inter/inter_800.tres")
## Outline thickness per game px of outline (LabelSettings / draw_string
## outline sizes count both sides of the stroke).
const OUTLINE_K := 6

## name: [font ("D" Lilita / "I" Inter), size, colour, outline px, outline colour, drop px]
## Display text is outlined in INK (1 game px). Kit v2.2: no drops (drop px 0
## everywhere; the column stays for a style that ever needs one back).
const STYLES := {
	"LOGO": ["D", 34, Palette.GOLD, 3, Palette.INK, 0],
	## Hero names on stages and result titles ("Swarmed!", "Unlocked!").
	"HERO": ["D", 20, Palette.PAPER, 1, Palette.INK, 0],
	## Result titles over the world (Swarmed!, Unlocked!).
	"RESULT": ["D", 24, Palette.GOLD, 1, Palette.INK, 0],
	## The big primary button (Play, Resume, Play Again, Nice!).
	"BIG_BUTTON": ["D", 16, Palette.PAPER, 1, Palette.INK, 0],
	## Screen titles and title plates.
	"TITLE": ["D", 14, Palette.PAPER, 1, Palette.INK, 0],
	"BANNER": ["D", 14, Palette.RED, 1, Palette.INK, 0],
	"NAME": ["D", 9, Palette.PAPER, 1, Palette.INK, 0],
	"BUTTON": ["D", 9, Palette.PAPER, 1, Palette.INK, 0],
	## Names on popup cards (level-up, bonus, merchant, pause details).
	"CARD_NAME": ["D", 9, Palette.PAPER, 1, Palette.INK, 0],
	"CARD_BODY": ["I", 7, Palette.PAPER, 0, Palette.INK, 0],
	"NUM": ["D", 10, Palette.PAPER, 1, Palette.INK, 0],
	"NUM_WORLD": ["D", 9, Palette.WHITE, 1, Palette.INK, 0],
	## Words and gold popping out of the world ("+5", "Shield!").
	"POP": ["D", 8, Palette.WHITE, 1, Palette.INK, 0],
	"BAR_NUM": ["D", 7, Palette.PAPER, 1, Palette.INK, 0],
	"RIBBON": ["D", 9, Palette.PAPER, 1, Palette.INK, 0],
	## The active bottom-nav tile's word.
	"NAV": ["D", 8, Palette.PAPER, 1, Palette.INK, 0],
	## INK words on a lamp plate (the current Play step), no outline.
	"ON_LAMP": ["D", 9, Palette.INK, 0, Palette.INK, 0],
	## Stickers and badges (New, AD, level and stack counts): INK on a light plate.
	"TAG": ["D", 7, Palette.INK, 0, Palette.INK, 0],
	"BODY": ["I", 7, Palette.PAPER, 0, Palette.INK, 0],
	## Muted secondary lines (kind lines, captions, timers).
	"SMALL": ["I", 6, Palette.MUTED, 0, Palette.INK, 0],
	"CHANGE": ["I", 7, Palette.LIME, 0, Palette.INK, 0],
	"HIT": ["I", 6, Palette.WHITE, 1, Palette.INK, 0],
	"CRIT": ["D", 9, Palette.BUTTER, 1, Palette.RED, 0],
	"SPLASH": ["D", 22, Palette.GOLD, 2, Palette.INK, 0],
}
## Cap height per font, in ems (OS/2 sCapHeight): centring on the caps lines
## text up with what's beside it (the ascent includes room above the letters).
const CAP := {"D": 0.68, "I": 0.7275}
## Smallest sizes fit() may shrink to.
const MIN_TITLE := 7
const MIN_BODY := 6

const BOLD := TITLE_FONT
const SMALL := BODY_FONT
const SIZE := 8

static var _styles := {}
## Tests (test_text_fit's big numbers): while true, every draw() is logged in
## `trace` as {ci, text, rect (the ink box in the item's local px), cut (the
## text is wider than its max_width, so draw_string cut it)}.
static var tracing := false
static var trace: Array = []


## Inter at weight 800.
static func body() -> Font:
	return BODY_FONT


static func font_of(style_name: String) -> Font:
	return TITLE_FONT if STYLES[style_name][0] == "D" else body()


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
		s.outline_size = d[3] * OUTLINE_K
		s.outline_color = Palette.color(d[4])
	if d[5] > 0:
		s.shadow_size = maxi(d[3] * OUTLINE_K, 1)
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


## The y to draw `style_name` at (Label / draw() top) so its capitals sit
## centred in a box from `box_y`, `box_h` tall (lowercase sits on the same line).
static func cap_y(style_name: String, box_y: float, box_h: float, size := -1) -> float:
	var d: Array = STYLES[style_name]
	var fs: int = d[1] if size < 0 else size
	var cap: float = CAP[d[0]] * fs
	return roundf(box_y + (box_h - cap) / 2.0 - (font_of(style_name).get_ascent(fs) - cap))


## Shrinks `l`'s style one size at a time until its text fits `max_width`
## (outline included), down to the font's minimum; past that it wraps, never
## clips. Returns the size used.
static func fit(l: Label, max_width: float, min_size := -1) -> int:
	var s := l.label_settings
	var sname: String = s.get_meta("style", "BODY") if s != null else "BODY"
	var color: int = s.get_meta("color", -1) if s != null else -1
	var fs: int = STYLES[sname][1]
	var floor_size := min_size if min_size > 0 else (MIN_TITLE if STYLES[sname][0] == "D" else MIN_BODY)
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
	if tracing:
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var x := pos.x
		if max_width > 0.0 and align == HORIZONTAL_ALIGNMENT_CENTER:
			x += floorf((max_width - tw) / 2.0)
		elif max_width > 0.0 and align == HORIZONTAL_ALIGNMENT_RIGHT:
			x += max_width - tw
		var cap := ceilf(fs * float(CAP[d[0]]))
		trace.append({"ci": ci, "text": text, "rect": Rect2(x, base.y - cap, tw, cap),
			"cut": max_width > 0.0 and tw > max_width + 0.5})
	var outline: int = d[3] * OUTLINE_K
	if d[5] > 0:
		var sp: Vector2 = base + Vector2(0, d[5])
		if outline > 0:
			ci.draw_string_outline(f, sp, text, align, max_width, fs, outline, Palette.color(Palette.INK))
		ci.draw_string(f, sp, text, align, max_width, fs, Palette.color(Palette.INK))
	if outline > 0:
		ci.draw_string_outline(f, base, text, align, max_width, fs, outline, Palette.color(d[4]))
	ci.draw_string(f, base, text, align, max_width, fs, Palette.color(d[2] if color < 0 else color))


## Puts a label in Lilita One (NAME size).
static func bold(l: Control) -> Control:
	l.add_theme_font_override("font", TITLE_FONT)
	l.add_theme_font_size_override("font_size", 9)
	return l


## BOLD (Lilita) if `text` fits in `width` px at SIZE, else SMALL (Inter).
static func fitting(text: String, width_px: float) -> Font:
	if BOLD.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x <= width_px:
		return BOLD
	return SMALL

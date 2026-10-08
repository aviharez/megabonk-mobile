class_name ChallengeRow
extends Control
## One challenge with its progress: the challenge text, a pixel progress bar,
## then what it unlocks and the progress numbers. Used on the game-over
## screen and the unlocks screen. 26 px tall.

const HEIGHT := 26

var text := ""
var reward := ""
var progress := ""
var frac := 0.0
var bar_color := Palette.LIME
var reward_color := Palette.MIST


func _init() -> void:
	custom_minimum_size = Vector2(156, HEIGHT)
	mouse_filter = MOUSE_FILTER_IGNORE


## ch: challenge entry; p: Meta.progress(); reward_text: what it unlocks.
func setup(ch: Dictionary, p: Dictionary, reward_text: String) -> ChallengeRow:
	text = ch.desc
	reward = reward_text
	progress = Meta.progress_text(ch, p)
	frac = p.frac
	bar_color = Palette.LIME if p.done else Palette.GOLD
	queue_redraw()
	return self


func _draw() -> void:
	var font := get_theme_default_font()
	var fs := get_theme_default_font_size()
	var w := int(size.x)
	var asc := font.get_ascent(fs)
	draw_string(font, Vector2(0, asc), text, HORIZONTAL_ALIGNMENT_LEFT, w, fs, Palette.color(Palette.PAPER))
	# Bar: INK frame, SHADE track, filled part in whole pixels.
	draw_rect(Rect2i(0, 10, w, 6), Palette.color(Palette.INK))
	draw_rect(Rect2i(1, 11, w - 2, 4), Palette.color(Palette.SHADE))
	var fill := floori((w - 2) * clampf(frac, 0.0, 1.0))
	if fill > 0:
		draw_rect(Rect2i(1, 11, fill, 4), Palette.color(bar_color))
	draw_string(font, Vector2(0, 17 + asc), reward, HORIZONTAL_ALIGNMENT_LEFT, w, fs, Palette.color(reward_color))
	var pw := font.get_string_size(progress, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(w - pw, 17 + asc), progress, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.color(Palette.MIST))

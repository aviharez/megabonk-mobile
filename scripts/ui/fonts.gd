class_name Fonts
extends RefCounted
## The two pixel fonts. BOLD ("Bonk", tools/fonts/make_bonk.py, our own) for
## titles, buttons, headings and HUD numbers; SMALL (the 5x7 theme font) for
## longer text. Both are 8px with a 10px line, so they swap without relayout.

const BOLD := preload("res://assets/fonts/bonk.fnt")
const SMALL := preload("res://assets/fonts/pixel.fnt")
const SIZE := 8


## Puts a label in the bold font.
static func bold(l: Control) -> Control:
	l.add_theme_font_override("font", BOLD)
	return l


## BOLD if `text` fits in `width` px, else SMALL.
static func fitting(text: String, width: float) -> Font:
	if BOLD.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x <= width:
		return BOLD
	return SMALL

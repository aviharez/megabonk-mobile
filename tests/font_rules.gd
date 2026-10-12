extends RefCounted
## Phase 9 text rules shared by the data tests (not a test file itself): every
## character is in the font the string is drawn with (names and titles in
## Titan One, body text in Inter), and a string fits its box by measured width
## in at most `max_lines` lines (LevelCard's word wrap). Titan One has no
## → ♥ ★ ✓, so title strings must not use them.

## The level-up card's text column: 132 px card, 36 px icon frame.
const CARD_TEXT_W := 81.0


## Characters of `s` missing from the style's font ("" when all are there).
static func missing(s: String, style_name: String) -> String:
	var f := Fonts.font_of(style_name)
	var out := ""
	for ch in s:
		if ch != " " and not f.has_char(ch.unicode_at(0)) and not out.contains(ch):
			out += ch
	return out


## Lines `s` wraps to in a style (at `size`) within `width`.
static func lines(s: String, style_name: String, width: float, size := -1) -> int:
	var n := LevelCard._wrap(s, width, style_name, size).size()
	# A single word wider than the box still counts as too wide.
	for word in s.split(" ", false):
		if Fonts.width(word, style_name, size) > width:
			return 99
	return n


## Problems with one shown string: [] when it is in the font and fits.
static func problems(id: String, s: String, style_name: String, width: float, max_lines := 2, size := -1) -> Array:
	var out := []
	var miss := missing(s, style_name)
	if miss != "":
		out.append("%s: '%s' has %s (not in %s's font)" % [id, s, miss, style_name])
	var n := lines(s, style_name, width, size)
	if n > max_lines:
		out.append("%s: '%s' needs %d lines of %s in %d px" % [id, s, n, style_name, width])
	return out

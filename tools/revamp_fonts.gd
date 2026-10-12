extends RefCounted
## Phase 9 font candidates, set up for the game's look: antialiasing off (every
## pixel stays a palette colour), no hinting, subpixel positioning with
## rounding remainders kept (even spacing down to 8px; with AA off the offsets
## only move solid glyphs). Used by tools/font_preview.gd and tools/ui_mockups.gd.

const TITAN := "res://assets/fonts/titan_one/TitanOne-Regular.ttf"
const INTER := "res://assets/fonts/inter/Inter-Variable.ttf"
const LILITA := "res://assets/fonts/lilita_one/LilitaOne-Regular.ttf"


static func file(path: String, aa := false) -> FontFile:
	var f := FontFile.new()
	f.load_dynamic_font(path)
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY if aa else TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	f.keep_rounding_remainders = true
	f.generate_mipmaps = false
	return f


## Titles, buttons, names, big numbers.
static func title() -> Font:
	return file(TITAN)


## Body text: Inter at a weight (variable font, 100-900).
static func body(weight := 900) -> Font:
	var v := FontVariation.new()
	v.base_font = file(INTER)
	v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return v

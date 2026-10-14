class_name LevelCard
extends PixelButton
## A pick-one card (level-up, beacon bonus, merchant), kit v2
## (docs/ui/level-up.png, merchant.png): a raised card with the icon 2x in a
## slot (a rarity ring for merchant wares), a muted kind line ("New weapon",
## "Manual", "Rare"), the name (CARD_NAME), one body line (what it does, or
## "Damage 10 > 14" on a level-up), and for weapons and manuals the level pips
## with the new one ringed. New cards wear the "New" sticker on the top-right
## corner. Beacon bonuses show their value big on the right; merchant wares a
## price button (disabled with the price in red when too dear) or a stamp
## (Sold).
##   show_card(card, icon, top_level)  a level-up card (LevelUpCards)
##   show_option({"title", "tag", "desc", "value", "price", "afford", "stamp",
##                "stamp_color", "color", "art"})    any other choice

const KIND := {
	"weapon": ["Weapon", Palette.MUTED],
	"tome": ["Manual", Palette.MUTED],
	"fallback": ["Bonus", Palette.MUTED],
}
## Name colour per card colour (the lighter shade of the card's ramp).
const NAME_COLOR := {Palette.RED: Palette.SALMON, Palette.BLUE: Palette.SKY, Palette.ORANGE: Palette.BUTTER,
	Palette.GOLD: Palette.BUTTER, Palette.GREEN: Palette.LIME, Palette.PURPLE: Palette.PINK, Palette.GRAY: Palette.MIST}
## Text column, from the card's left edge.
const TEXT_X := 42
const PIP_STEP := 7
## Icons are drawn 2x from this size (16 px art shrunk a little, so the
## frame's rim shows round them).
const ICON_PX := 14
const CHANGE_SIZE := 7

var card := {}
var option := {}
var max_level := 5
var _t := 0.0
var _icon: Texture2D
static var _shadows := {}  # texture RID -> INK silhouette texture
static var _smalls := {}  # "texture RID id/px" -> shrunk copy


func _init() -> void:
	_own_label = true


func _ready() -> void:
	super._ready()
	ink = Palette.PAPER


func show_card(c: Dictionary, icon: Texture2D, top_level: int) -> void:
	card = c
	option = {}
	art = null
	_icon = icon
	max_level = top_level
	badge = ""
	queue_redraw()


func show_option(o: Dictionary) -> void:
	option = o
	card = {}
	art = null
	_icon = o.get("art")
	badge = ""
	queue_redraw()


func _process(delta: float) -> void:
	if (not card.is_empty() or not option.is_empty()) and is_visible_in_tree():
		var before := int(_t * 3.0)
		_t += delta
		if int(_t * 3.0) != before:
			queue_redraw()


## The card's colour: the kind's for level-ups, the option's otherwise.
func accent() -> int:
	if disabled:
		return Palette.GRAY
	if not card.is_empty():
		return KIND.get(card.get("kind", ""), KIND.fallback)[1]
	return int(option.get("color", Palette.ORANGE))


func _draw() -> void:
	if card.is_empty() and option.is_empty():
		return
	var mode := get_draw_mode()
	var sunk := mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED
	var y := 1.0 if sunk else 0.0
	var w := floorf(size.x)
	var h := floorf(size.y) - UiArt.DROP_CARD
	var off := disabled
	UiArt.card(self, Rect2(0, y, w, h), 0 if sunk else UiArt.DROP_CARD)
	var frame := Rect2(7, y + 7, 38, 38)
	UiArt.slot(self, frame, _ring(), 0)
	_draw_icon(frame.get_center())

	var tx := frame.end.x + 7.0
	var room := w - tx - 6.0
	var value: String = option.get("value", "")
	var value_w := 0.0
	if value != "":
		value_w = Fonts.width(value, "NAME", 12) + 6.0
		Fonts.draw(self, value, Vector2(w - value_w, Fonts.cap_y("NAME", y, h, 12)), "NAME",
				Palette.MUTED if off else accent(), -1, HORIZONTAL_ALIGNMENT_LEFT, 12)
	var price_w := 42.0 if option.has("price") or option.get("stamp", "") != "" else 0.0
	var name_room := room - value_w - price_w
	Fonts.draw(self, kind_line(), Vector2(tx, y + 7), "SMALL", Palette.MUTED if off else kind_color(), name_room)
	var title := _title()
	var nfs: int = Fonts.STYLES.CARD_NAME[1]
	while nfs > 7 and Fonts.width(title, "CARD_NAME", nfs) + 2 > name_room:
		nfs -= 1
	Fonts.draw(self, title, Vector2(tx, y + 14), "CARD_NAME", Palette.MUTED if off else -1, -1, HORIZONTAL_ALIGNMENT_LEFT, nfs)
	var lines := _wrap(body_line(), name_room, "BODY")
	var pips: bool = card.get("kind", "") in ["weapon", "tome"]
	for k in mini(lines.size(), 1 if pips else 2):
		Fonts.draw(self, lines[k], Vector2(tx, y + 26 + k * 9), "BODY", Palette.MUTED if off else (Palette.MUTED if option.has("price") else Palette.PAPER))
	if pips:
		var lvl := int(card.get("level", 0))
		UiArt.pips(self, Vector2(tx, y + 39), clampi(max_level, 1, 6), lvl - 1, lvl - 1)
	_draw_price(y, w, h)
	if card.get("is_new", false):
		UiArt.sticker(self, "New", Vector2(w - 22, y - 5))


## The muted line over the name: "New weapon", "Manual", a rarity, "Bonus".
func kind_line() -> String:
	if not card.is_empty():
		var kind: String = KIND.get(card.get("kind", ""), KIND.fallback)[0]
		return ("New " + kind.to_lower()) if card.get("is_new", false) else kind
	return option.get("tag", "")


## The kind line's colour: muted, or a ware's rarity colour.
func kind_color() -> int:
	if not card.is_empty() or not option.has("color"):
		return Palette.MUTED
	var c := int(option.color)
	return c if c in [Palette.R_COMMON, Palette.BLUE, Palette.PURPLE, Palette.GOLD] else Palette.MUTED


## What it does, or the level change ("Damage 10 > 14") on a level-up.
func body_line() -> String:
	if not card.is_empty() and not card.get("is_new", false):
		var st := stat_line(true)
		if st != "":
			return st
	return _desc()


## The slot ring: a ware's rarity, else the plain slot.
func _ring() -> String:
	if not option.is_empty() and option.has("color"):
		return Hud._ring_for_color(int(option.color))
	return ""


## Splits `text` into lines that fit `room` px in a style (word wrap).
static func _wrap(text: String, room: float, style_name := "BODY", size := -1) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for word in text.split(" ", false):
		var t := word if line == "" else line + " " + word
		if line != "" and Fonts.width(t, style_name, size) > room:
			out.append(line)
			line = word
		else:
			line = t
	if line != "":
		out.append(line)
	return out


## The icon (2x up to 16 px, shrunk to ICON_PX first) with an INK drop,
## centred on `c`; a coin when there's none.
func _draw_icon(c: Vector2) -> void:
	var tex := _icon if _icon != null else UiArt.texture("coin_big")
	if tex == null:
		return
	if tex.get_width() > ICON_PX and tex.get_width() <= 16:
		tex = _small(tex)
	var k := 2.0 if tex.get_width() <= 16 else 1.0
	var sz := Vector2(tex.get_size()) * k
	var at := (c - sz / 2.0).floor()
	draw_texture_rect(tex, Rect2(at, sz), false)


## A ware's price button (coin + number; disabled with the number in red
## when too dear) at the card's right, or a stamp (Sold) in its place.
func _draw_price(y: float, w: float, h: float) -> void:
	var r := Rect2(w - 41, y + floorf((h - 23) / 2.0), 35, 20)
	var stamp: String = option.get("stamp", "")
	if stamp != "":
		UiArt.button(self, r, "disabled")
		Fonts.draw(self, stamp, Vector2(r.position.x, Fonts.cap_y("BUTTON", r.position.y, r.size.y - 1)), "BUTTON",
				Palette.MUTED, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		return
	if not option.has("price"):
		return
	var ok: bool = option.get("afford", true)
	UiArt.button(self, r, "secondary" if ok else "disabled")
	var txt := str(int(option.price))
	var tw := ceilf(Fonts.width(txt, "BUTTON"))
	var x := r.position.x + floorf((r.size.x - tw - 12) / 2.0)
	var face_h := r.size.y - (3.0 if ok else 1.0)
	UiArt.sprite(self, "hud_coin", Vector2(x, r.position.y + floorf((face_h - 10) / 2.0)))
	Fonts.draw(self, txt, Vector2(x + 12, Fonts.cap_y("BUTTON", r.position.y, face_h)), "BUTTON", Palette.PAPER if ok else Palette.SALMON)


## `tex` shrunk to `px` (Icons.shrink: palette colours only, cached).
static func _small(tex: Texture2D, px := ICON_PX) -> Texture2D:
	var key := "%d/%d" % [tex.get_rid().get_id(), px]
	if not _smalls.has(key):
		var img := tex.get_image()
		if img != null:
			img.convert(Image.FORMAT_RGBA8)
		_smalls[key] = ImageTexture.create_from_image(Icons.shrink(img, px)) if img != null else tex
	return _smalls[key]


## An all-INK copy of `tex` for the drop under the icon (cached).
static func _shadow(tex: Texture2D) -> Texture2D:
	var key := tex.get_rid()
	if not _shadows.has(key):
		var img := tex.get_image()
		_shadows[key] = ImageTexture.create_from_image(Icons.silhouette(img)) if img != null else null
	return _shadows[key]


## The darker neighbour of palette colour `face` (UiArt.RAMPS), for stripes.
static func _dark(face: int) -> int:
	for r: Array in UiArt.RAMPS:
		var i := r.find(face)
		if i > 0:
			return r[i - 1]
	return Palette.INK if face != Palette.INK else Palette.NIGHT


func _title() -> String:
	if not card.is_empty():
		return card.get("def", {}).get("name", "")
	return option.get("title", "")


## Kept for the shop and tests: the old tag chip text (not drawn any more).
func _tag() -> String:
	if not card.is_empty():
		var kind: Array = KIND.get(card.get("kind", ""), KIND.fallback)
		var lvl := int(card.get("level", 0))
		if card.get("is_new", false):
			return "New " + kind[0]
		return kind[0] + ("  Lv %d" % lvl if lvl > 0 else "")
	return option.get("tag", "")


## Weapon level keys worth showing on a card, with their short names.
const STAT_NAMES := [["damage", "Dmg", "Damage"], ["cooldown", "CD", "Cooldown"], ["radius", "Area", "Area"],
	["count", "Count", "Count"], ["projectiles", "Shots", "Shots"], ["swings", "Swings", "Swings"],
	["bounces", "Bounce", "Bounces"], ["pierce", "Pierce", "Pierce"], ["duration", "Time", "Time"],
	["jumps", "Jumps", "Jumps"], ["range", "Range", "Range"]]


## "Dmg 14 > 16  CD 1.2 > 1.1" for a weapon level-up (the first two keys that
## change), "Dmg 10  CD 1.3" for a new weapon, "+10% > +20%" for a tome.
func stat_line(long_names := false) -> String:
	var def: Dictionary = card.get("def", {})
	var lvl := int(card.get("level", 0))
	match card.get("kind", ""):
		"weapon":
			var levels: Array = def.get("levels", [])
			if lvl < 1 or lvl > levels.size():
				return ""
			var now: Dictionary = levels[lvl - 1]
			var parts := []
			if lvl == 1:
				for kn: Array in STAT_NAMES:
					if now.has(kn[0]) and parts.size() < (1 if long_names else 2):
						parts.append("%s %s" % [kn[2 if long_names else 1], _num(now[kn[0]])])
			else:
				var was: Dictionary = levels[lvl - 2]
				for kn: Array in STAT_NAMES:
					if now.has(kn[0]) and was.has(kn[0]) and not is_equal_approx(float(now[kn[0]]), float(was[kn[0]])) and parts.size() < (1 if long_names else 2):
						parts.append(("%s %s > %s" if long_names else "%s %s>%s") % [kn[2 if long_names else 1], _num(was[kn[0]]), _num(now[kn[0]])])
			return "  ".join(parts)
		"tome":
			var re := RegEx.new()
			re.compile("\\d+(\\.\\d+)?")
			var desc: String = def.get("desc", "")
			var m := re.search(desc)
			if m == null or lvl < 1:
				return ""
			var per := float(m.get_string())
			var sign := desc.substr(m.get_start() - 1, 1) if m.get_start() > 0 else ""
			var unit := "%" if desc.substr(m.get_end(), 1) == "%" else ""
			if lvl == 1:
				return "Now %s%s%s" % [sign, _num(per), unit]
			return "Now %s%s%s > %s%s%s" % [sign, _num(per * (lvl - 1)), unit, sign, _num(per * lvl), unit]
	return ""


## The CHANGE line: "3 → 4" (level before and after) for weapons and tomes,
## "New" cards show their first level as "0 → 1". Titan One has no →, so the
## CHANGE style is Inter.
func change_line() -> String:
	if not card.is_empty():
		var lvl := int(card.get("level", 0))
		if card.get("kind", "") in ["weapon", "tome"] and lvl > 0:
			return "%d → %d" % [lvl - 1, lvl]
		return ""
	return ""


static func _num(v: Variant) -> String:
	var f := float(v)
	return str(int(f)) if is_equal_approx(f, roundf(f)) else ("%.2f" % f).rstrip("0").rstrip(".")


func _desc() -> String:
	if card.is_empty():
		return option.get("desc", "")
	var def: Dictionary = card.get("def", {})
	match card.get("kind", ""):
		"weapon":
			if card.get("is_new", false):
				return def.get("desc", "")
			var levels: Array = def.get("levels", [])
			var i := int(card.level) - 1
			return levels[i].get("desc", "") if i >= 0 and i < levels.size() else ""
	return def.get("desc", "")

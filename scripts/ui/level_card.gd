class_name LevelCard
extends PixelButton
## A pick-one card (level-up, shrine bonus, merchant), Phase 9 kit 3b look
## (docs/phase9/8_kit3_levelup_concept.png): the `lv_card` plate in the
## card's colour (GOLD while pressed), a `lv_frame` icon frame in the same
## colour with the icon at 2x, the name in the NAME style (the colour's light
## shade), one BODY line, and for weapons and tomes the CHANGE line ("3 → 4")
## with the kit's level pips on the right. New cards wear a purple "New"
## sticker on the top-right corner. Kind, rarity and New are colour and
## stickers, not words. Shrine bonuses show their value big on the right;
## merchant items their price (or a stamp: SOLD...).
##   show_card(card, icon, top_level)  a level-up card (LevelUpCards)
##   show_option({"title", "tag", "desc", "value", "price", "afford", "stamp",
##                "stamp_color", "color", "art"})    any other choice

const KIND := {
	"weapon": ["WEAPON", Palette.RED],
	"tome": ["MANUAL", Palette.BLUE],
	"fallback": ["BONUS", Palette.ORANGE],
}
## Name colour per card colour (the lighter shade of the card's ramp).
const NAME_COLOR := {Palette.RED: Palette.SALMON, Palette.BLUE: Palette.SKY, Palette.ORANGE: Palette.BUTTER,
	Palette.GOLD: Palette.BUTTER, Palette.GREEN: Palette.LIME, Palette.PURPLE: Palette.PINK, Palette.GRAY: Palette.MIST}
## Text column, from the card's left edge.
const TEXT_X := 42
const PIP_STEP := 7

var card := {}
var option := {}
var max_level := 5
var _t := 0.0
var _icon: Texture2D
static var _shadows := {}  # texture RID -> INK silhouette texture


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
	var y := SHADOW if sunk else 0
	var w := floorf(size.x)
	var h := floorf(size.y) - SHADOW
	var off := disabled
	var acc := accent()
	UiArt.draw(self, "lv_card", Rect2(0, y, w, h), Palette.GOLD if sunk else acc, -1, 0 if sunk else SHADOW)
	# Icon frame: square, 2 px border round a 2x 16 px icon (36 px on a 42 px card).
	var fs := minf(36.0, h - 6.0)
	var frame := Rect2(4, y + floorf((h - fs) / 2.0) - 1.0, fs, fs)
	UiArt.draw(self, "lv_frame", frame, acc)
	_draw_icon(frame.get_center() + Vector2(0, -1))

	var tx := frame.end.x + 5.0
	var room := w - tx - 6.0
	var name_c: int = Palette.SHADE if off else NAME_COLOR.get(acc, Palette.PAPER)
	var value: String = option.get("value", "")
	var value_w := 0.0
	if value != "":
		value_w = Fonts.width(value, "NAME", 16) + 6.0
		Fonts.draw(self, value, Vector2(w - 6 - value_w + 6, y + floorf((h - 20) / 2.0)), "NAME",
				Palette.SHADE if off else acc, -1, HORIZONTAL_ALIGNMENT_LEFT, 16)
	# Name: NAME, shrunk down to 8; a longer one wraps to two lines at 8
	# ("Grandma's Soup Recipes"), which moves the BODY line down.
	var title := _title()
	var name_room := room - value_w
	# The New sticker sits over the card's top-right corner: names keep clear.
	var title_room := name_room - (8.0 if card.get("is_new", false) else 0.0)
	var nfs: int = Fonts.STYLES.NAME[1]
	while nfs > 8 and Fonts.width(title, "NAME", nfs) > title_room:
		nfs -= 1
	var name_lines := PackedStringArray([title])
	if Fonts.width(title, "NAME", nfs) > title_room:
		name_lines = _wrap(title, title_room, "NAME", nfs)
	# One BODY line; a longer one wraps to two (then the name moves up 2 px),
	# never into the change line at the foot. A two-line name keeps one.
	var desc := _desc()
	var body_c := Palette.SHADE if off else Palette.PAPER
	var lines := _wrap(desc, name_room)
	var name_y := 4.0
	var by := y + 17.0
	if name_lines.size() > 1:
		name_y = 1.0
		by = y + 20.0
		lines = lines.slice(0, 1)
	elif lines.size() > 1:
		name_y = 2.0
		by = y + 13.0
	for k in mini(name_lines.size(), 2):
		Fonts.draw(self, name_lines[k], Vector2(tx, y + name_y + k * 9), "NAME", name_c,
				-1, HORIZONTAL_ALIGNMENT_LEFT, nfs)
	for k in mini(lines.size(), 2):
		Fonts.draw(self, lines[k], Vector2(tx, by + k * 8.0), "BODY", body_c)
	var change := change_line()
	var foot := y + h - 12.0
	if change != "":
		Fonts.draw(self, change, Vector2(tx, foot), "CHANGE", Palette.SHADE if off else -1)
	if card.get("kind", "") in ["weapon", "tome"]:
		_draw_pips(Vector2(w - 6 - clampi(max_level, 1, 6) * PIP_STEP, y + h - 12))
	_draw_price(y, w, h)
	if card.get("is_new", false):
		var hop := 1.0 if int(_t * 3.0) % 2 == 0 else 0.0
		var sr := Rect2(w - 20, y - 6 - hop, 21, 12)
		UiArt.draw(self, "lv_sticker", sr)
		Fonts.draw(self, "New", Vector2(sr.position.x, sr.position.y + 1), "TAG", -1, sr.size.x, HORIZONTAL_ALIGNMENT_CENTER)


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


## The icon (2x up to 16 px) with an INK drop, centred on `c`; a coin when there's none.
func _draw_icon(c: Vector2) -> void:
	var tex := _icon if _icon != null else UiArt.texture("coin_big")
	if tex == null:
		return
	var k := 2.0 if tex.get_width() <= 16 else 1.0
	var sz := Vector2(tex.get_size()) * k
	var at := (c - sz / 2.0).floor()
	var shadow := _shadow(tex)
	if shadow != null:
		draw_texture_rect(shadow, Rect2(at + Vector2(1, 2), sz), false)
	draw_texture_rect(tex, Rect2(at, sz), false)


## Level pips: owned levels lit, the new one blinking.
func _draw_pips(at: Vector2) -> void:
	var lvl := int(card.get("level", 0))
	var n := clampi(max_level, 1, 6)
	for i in n:
		var on := i < lvl - 1 or (i == lvl - 1 and int(_t * 3.0) % 2 == 0)
		UiArt.sprite(self, "lv_pip_on" if on else "lv_pip_off", at + Vector2(i * PIP_STEP, 0))


## Merchant price (coin + number) at the bottom-right, or a stamp (SOLD...).
func _draw_price(y: float, w: float, h: float) -> void:
	var stamp: String = option.get("stamp", "")
	if stamp != "":
		var sw := Fonts.width(stamp, "TAG") + 8.0
		var r := Rect2(w - sw - 6, y + h - 16, sw, 12)
		UiArt.draw(self, "lv_sticker", r, int(option.get("stamp_color", Palette.RED)))
		Fonts.draw(self, stamp, Vector2(r.position.x, r.position.y + 1), "TAG", -1, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		return
	if not option.has("price"):
		return
	var txt := str(int(option.price))
	var ok: bool = option.get("afford", true)
	var tw := Fonts.width(txt, "NUM")
	var at := Vector2(w - tw - 8, y + h - 15)
	UiArt.sprite(self, "hud_coin", at - Vector2(12, -1))
	Fonts.draw(self, txt, at, "NUM", Palette.GOLD if ok else Palette.SALMON)


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
			return "NEW " + kind[0]
		return kind[0] + ("  LV %d" % lvl if lvl > 0 else "")
	return option.get("tag", "")


## Weapon level keys worth showing on a card, with their short names.
const STAT_NAMES := [["damage", "DMG"], ["cooldown", "CD"], ["radius", "AREA"], ["count", "COUNT"],
	["projectiles", "SHOTS"], ["swings", "SWINGS"], ["bounces", "BOUNCE"], ["pierce", "PIERCE"],
	["duration", "TIME"], ["jumps", "JUMPS"], ["range", "RANGE"]]


## "DMG 14 > 16  CD 1.2 > 1.1" for a weapon level-up (the first two keys that
## change), "DMG 10  CD 1.3" for a new weapon, "+10% > +20%" for a tome.
func stat_line() -> String:
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
					if now.has(kn[0]) and parts.size() < 2:
						parts.append("%s %s" % [kn[1], _num(now[kn[0]])])
			else:
				var was: Dictionary = levels[lvl - 2]
				for kn: Array in STAT_NAMES:
					if now.has(kn[0]) and was.has(kn[0]) and not is_equal_approx(float(now[kn[0]]), float(was[kn[0]])) and parts.size() < 2:
						parts.append("%s %s>%s" % [kn[1], _num(was[kn[0]]), _num(now[kn[0]])])
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
				return "NOW %s%s%s" % [sign, _num(per), unit]
			return "NOW %s%s%s > %s%s%s" % [sign, _num(per * (lvl - 1)), unit, sign, _num(per * lvl), unit]
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

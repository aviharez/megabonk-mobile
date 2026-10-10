class_name LevelCard
extends PixelButton
## A pick-one card (level-up, shrine bonus, merchant): a striped badge on the
## left in the card's colour with the icon at 2x (and, for weapons and tomes,
## level pips under it: the new level blinks), then the bold name, a tag chip
## (NEW WEAPON / TOME LV 2 / SHRINE BONUS / RARE), the description, and a
## LIME line with the numbers that change. Shrine bonuses show their value
## big on the right; merchant items their price (or SOLD). NEW cards wear a
## purple sticker over the top edge.
##   show_card(card, icon, top_level)  a level-up card (LevelUpCards)
##   show_option({"title", "tag", "desc", "value", "price", "afford", "stamp",
##                "stamp_color", "color", "art"})    any other choice

const KIND := {
	"weapon": ["WEAPON", Palette.RED],
	"tome": ["MANUAL", Palette.BLUE],
	"fallback": ["BONUS", Palette.ORANGE],
}
## Left badge width (the icon at 2x, centred).
const BADGE_W := 38
const TEXT_X := 43

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
	var w := int(size.x)
	var h := int(size.y) - SHADOW
	var off := disabled
	var acc := accent()
	var dark := _dark(acc)
	# Body: hard shadow, notched INK outline, a 1px rim in the card's colour
	# (white while pressed), NIGHT inside with a lighter top line.
	if not sunk:
		_box(Rect2i(0, SHADOW, w, h), Palette.color(Palette.INK), Palette.color(Palette.INK))
	_box(Rect2i(0, y, w, h), Palette.color(Palette.INK), Palette.color(Palette.WHITE if sunk else acc))
	draw_rect(Rect2i(2, y + 2, w - 4, h - 4), Palette.color(Palette.NIGHT))
	draw_rect(Rect2i(BADGE_W + 1, y + 2, w - BADGE_W - 3, 1), Palette.color(Palette.SHADE))
	# Badge: diagonal stripes, then an INK line between it and the text.
	var b := Rect2i(2, y + 2, BADGE_W - 2, h - 4)
	draw_rect(b, Palette.color(acc))
	var stripe := Palette.color(dark)
	for py in b.size.y:
		# 3 px of every 8 along each row, one step over per row: diagonal bands.
		var px := -((py) % 8)
		while px < b.size.x:
			var x0 := maxi(px, 0)
			var x1 := mini(px + 3, b.size.x)
			if x1 > x0:
				draw_rect(Rect2i(b.position.x + x0, b.position.y + py, x1 - x0, 1), stripe)
			px += 8
	draw_rect(Rect2i(BADGE_W, y + 2, 1, h - 4), Palette.color(Palette.INK))
	var leveled: bool = card.get("kind", "") in ["weapon", "tome"]
	var icon_y := y + (6 if leveled else floori((h - 32) / 2.0))
	_draw_icon(Vector2i(2 + (BADGE_W - 2 - 32) / 2, icon_y))
	if leveled:
		_draw_pips(y + h - 12)

	var text_c := Palette.color(Palette.SHADE if off else Palette.PAPER)
	var room := w - TEXT_X - 5
	# Name, bold when it fits, with an INK drop.
	var title := _title()
	var sticker := "NEW!" if card.get("is_new", false) else ""
	var nf := Fonts.fitting(title, room)
	draw_string(nf, Vector2(TEXT_X, y + 13), title, HORIZONTAL_ALIGNMENT_LEFT, room, 8, Palette.color(Palette.INK))
	draw_string(nf, Vector2(TEXT_X, y + 12), title, HORIZONTAL_ALIGNMENT_LEFT, room, 8, Palette.color(Palette.SHADE if off else Palette.BUTTER))
	# Tag chip in the card's colour.
	var tag := _tag()
	var tw := int(Fonts.SMALL.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)
	var chip := Rect2i(TEXT_X - 1, y + 16, tw + 5, 10)
	_box(chip, Palette.color(Palette.INK), Palette.color(acc))
	draw_string(Fonts.SMALL, Vector2(chip.position.x + 3, chip.position.y + 8), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
		Palette.color(Palette.INK if acc in [Palette.GOLD, Palette.BUTTER, Palette.LIME, Palette.SKY, Palette.MIST, Palette.ORANGE] else Palette.PAPER))
	# Big value on the right (shrine bonuses).
	var value: String = option.get("value", "")
	var value_w := 0
	if value != "":
		value_w = int(Fonts.BOLD.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x) * 2
		var vx := w - 6 - value_w
		draw_set_transform(Vector2(vx, y + 20), 0.0, Vector2(2, 2))
		draw_string(Fonts.BOLD, Vector2(0, 8), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(Palette.INK))
		draw_string(Fonts.BOLD, Vector2(0, 7), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(Palette.SHADE if off else acc))
		draw_set_transform(Vector2.ZERO)
	# Description, wrapped (beside the value, if there is one).
	var desc := _desc()
	var desc_y := y + 35 if value == "" else y + 47
	draw_multiline_string(Fonts.SMALL, Vector2(TEXT_X, desc_y), desc, HORIZONTAL_ALIGNMENT_LEFT, room, 8, 2, text_c)
	# The numbers that change, in LIME at the foot.
	var nums := stat_line()
	if nums != "":
		draw_string(Fonts.SMALL, Vector2(TEXT_X, y + h - 5), nums, HORIZONTAL_ALIGNMENT_LEFT, room, 8, Palette.color(Palette.SHADE if off else Palette.LIME))
	_draw_price(y, w, h)
	if sticker != "" and UiArt.has("new_badge"):
		var bw := int(Fonts.SMALL.get_string_size(sticker, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x) + 6
		var hop := 1 if int(_t * 3.0) % 2 == 0 else 0
		var bx := w - bw - 4
		# Up on the top edge, clear of the name line.
		UiArt.draw(self, "new_badge", Rect2(bx, y - 6 - hop, bw, 10))
		draw_string(Fonts.SMALL, Vector2(bx + 3, y + 2 - hop), sticker, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(Palette.PAPER))


## The icon at 2x with an INK drop under it, or a coin when there's none.
func _draw_icon(at: Vector2i) -> void:
	if _icon == null:
		draw_set_transform(Vector2(at + Vector2i(9, 9)), 0.0, Vector2(2, 2))
		Glyphs.draw(self, "coin", Vector2.ZERO)
		draw_set_transform(Vector2.ZERO)
		return
	var sz := Vector2(_icon.get_size()) * 2.0
	var shadow := _shadow(_icon)
	if shadow != null:
		draw_texture_rect(shadow, Rect2(Vector2(at) + Vector2(1, 2), sz), false)
	draw_texture_rect(_icon, Rect2(Vector2(at), sz), false)


## Level pips under the icon: owned levels gold, the new one blinking.
func _draw_pips(py: int) -> void:
	var lvl := int(card.get("level", 0))
	var n := clampi(max_level, 1, 6)
	var pw := 5
	var x0 := 2 + (BADGE_W - 2 - (n * (pw + 1) + 1)) / 2
	draw_rect(Rect2i(x0, py, n * (pw + 1) + 1, 6), Palette.color(Palette.INK))
	for i in n:
		var c := Palette.SHADE
		if i < lvl - 1:
			c = Palette.GOLD
		elif i == lvl - 1:
			c = Palette.LIME if int(_t * 3.0) % 2 == 0 else Palette.WHITE
		draw_rect(Rect2i(x0 + 1 + i * (pw + 1), py + 1, pw, 4), Palette.color(c))


## Merchant price chip at the bottom-right, or a stamp (SOLD, HAVE ONE).
func _draw_price(y: int, w: int, h: int) -> void:
	var stamp: String = option.get("stamp", "")
	if stamp != "":
		var s := stamp
		var sw := int(Fonts.BOLD.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x) + 8
		var r := Rect2i(w - sw - 6, y + h - 16, sw, 12)
		_box(r, Palette.color(Palette.INK), Palette.color(int(option.get("stamp_color", Palette.RED))))
		draw_string(Fonts.BOLD, Vector2(r.position.x + 4, r.position.y + 10), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(Palette.PAPER))
		return
	if not option.has("price"):
		return
	var txt := str(int(option.price))
	var tw := int(Fonts.BOLD.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)
	var r := Rect2i(w - tw - 19, y + h - 16, tw + 14, 12)
	var ok: bool = option.get("afford", true)
	_box(r, Palette.color(Palette.INK), Palette.color(Palette.DEEP_BLUE))
	Glyphs.draw(self, "coin", Vector2(r.position.x + 2, r.position.y + 2))
	draw_string(Fonts.BOLD, Vector2(r.position.x + 11, r.position.y + 10), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(Palette.GOLD if ok else Palette.SALMON))


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

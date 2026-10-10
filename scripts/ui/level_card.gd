class_name LevelCard
extends PixelButton
## A level-up card: a small kind tag (WEAPON / TOME / BONUS) in the kind's
## colour, the icon in a frame, the bold name, level pips (the level this card
## gives blinks), and the description wrapped under them. NEW cards wear the
## purple badge. Set with `show_card()`.

const KIND := {
	"weapon": ["WEAPON", Palette.RED],
	"tome": ["TOME", Palette.BLUE],
	"fallback": ["BONUS", Palette.ORANGE],
}

var card := {}
var max_level := 5
var _t := 0.0


func _init() -> void:
	_own_label = true


func _ready() -> void:
	super._ready()
	frame = "card"
	pressed_frame = "card_gold"
	ink = Palette.PAPER


func show_card(c: Dictionary, icon: Texture2D, top_level: int) -> void:
	card = c
	art = null
	_icon = icon
	max_level = top_level
	badge = "NEW!" if c.get("is_new", false) else ""
	queue_redraw()


var _icon: Texture2D


func _process(delta: float) -> void:
	if not card.is_empty() and is_visible_in_tree():
		var before := int(_t * 3.0)
		_t += delta
		if int(_t * 3.0) != before:
			queue_redraw()


func _draw() -> void:
	super._draw()
	if card.is_empty():
		return
	var mode := get_draw_mode()
	var y := SHADOW if mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED else 0
	var def: Dictionary = card.get("def", {})
	var kind: Array = KIND.get(card.get("kind", ""), KIND.fallback)
	var off := disabled
	var text_c := Palette.color(Palette.SHADE if off else ink)
	y += 3
	# Icon in a frame tinted by kind, left.
	var ix := 6
	var iy := y + 6
	draw_rect(Rect2(ix, iy, 20, 20), Palette.color(Palette.INK))
	draw_rect(Rect2(ix + 1, iy + 1, 18, 18), Palette.color(kind[1] if not off else Palette.GRAY))
	draw_rect(Rect2(ix + 2, iy + 2, 16, 16), Palette.color(Palette.NIGHT))
	if _icon != null:
		draw_texture(_icon, Vector2(ix + 2, iy + 2))
	else:
		Glyphs.draw(self, "coin", Vector2(ix + 6, iy + 6))
	# Name, bold when it fits.
	var x := 31
	var room := size.x - x - 6
	var name_s: String = def.get("name", "")
	var nf := Fonts.fitting(name_s, room - (34 if badge != "" else 0))
	draw_string(nf, Vector2(x, y + 12), name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(Palette.INK))
	draw_string(nf, Vector2(x, y + 11), name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(Palette.BUTTER) if not off else text_c)
	# Level pips (owned levels lit, the new one blinking), then kind and level.
	var lvl := int(card.get("level", 0))
	var tx := x
	if card.get("kind", "") in ["weapon", "tome"]:
		for i in max_level:
			var px := x + i * 7
			var lit := i < lvl - 1
			var fresh := i == lvl - 1
			draw_rect(Rect2(px, y + 15, 6, 5), Palette.color(Palette.INK))
			var c := Palette.SHADE
			if lit:
				c = Palette.GOLD
			elif fresh:
				c = Palette.LIME if int(_t * 3.0) % 2 == 0 else Palette.WHITE
			draw_rect(Rect2(px + 1, y + 16, 4, 3), Palette.color(c))
		tx = x + max_level * 7 + 3
	var tag: String = kind[0] + ("  LV %d" % lvl if lvl > 0 else "")
	var tag_c := Palette.SKY if kind[1] == Palette.BLUE else (Palette.SALMON if kind[1] == Palette.RED else Palette.GOLD)
	draw_string(Fonts.SMALL, Vector2(tx, y + 21), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(Palette.SHADE if off else tag_c))
	# Description, wrapped.
	var desc := _desc()
	draw_multiline_string(Fonts.SMALL, Vector2(x, y + 33), desc, HORIZONTAL_ALIGNMENT_LEFT, room, 8, 2, text_c)
	# The numbers that change, in LIME at the foot of the card.
	var nums := stat_line()
	if nums != "":
		draw_string(Fonts.SMALL, Vector2(x, y + 54), nums, HORIZONTAL_ALIGNMENT_LEFT, room, 8, Palette.color(Palette.SHADE if off else Palette.LIME))


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
	var def: Dictionary = card.get("def", {})
	match card.get("kind", ""):
		"weapon":
			if card.get("is_new", false):
				return def.get("desc", "")
			var levels: Array = def.get("levels", [])
			var i := int(card.level) - 1
			return levels[i].get("desc", "") if i >= 0 and i < levels.size() else ""
	return def.get("desc", "")

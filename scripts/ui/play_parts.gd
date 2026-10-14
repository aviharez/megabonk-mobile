class_name PlayParts
extends RefCounted
## Parts shared by Play's two steps and the Characters tab, kit v2
## (docs/ui/pick-district.png, pick-hero.png, characters.png,
## characters-locked.png, critters.png): the step indicator, stat tiles in
## wells, chips with an icon (role, Locked), info cards (signature weapon,
## passive), the hero and critter stats they show, and the stage (a hero or
## critter standing on the backdrop's plinth).

## The 8 hero stats on the Characters tab (Pick a Hero shows the first 4).
const HERO_STATS := [["max_hp", "HP"], ["damage", "Damage"], ["move_speed", "Speed"], ["pickup_range", "Magnet"],
	["armor", "Armor"], ["regen", "Regen"], ["area", "Area"], ["cooldown", "Cooldown"]]
## Stats shown as a multiplier ("x1.0").
const MULT_STATS := ["damage", "area", "cooldown"]
const GEM := "res://assets/gems/gem_mid.png"
## Role chip words for enemies without a "tag" (by role).
const ROLE_WORDS := {"chaser": "Slow chaser", "pack": "Fast pack", "shooter": "Shooter", "exploder": "Exploder",
	"charger": "Charger", "swarm": "Swarm", "ghost": "Ghost", "boss": "Boss"}
const TILE_H := 22
const CHIP_H := 12

static var _gem: Texture2D


## Step indicator, "1 District - 2 Hero", centred in a 180-wide control: the
## current step on a lamp plate, the other on a frame plate, each number in
## an INK-lined well, a short well between them.
static func steps(ci: CanvasItem, current: int) -> void:
	var names := ["District", "Hero"]
	var widths: Array[float] = []
	for n: String in names:
		widths.append(17.0 + ceilf(Fonts.width(n, "NAME")) + 5.0)
	var gap := 15.0
	var x := floorf((180.0 - widths[0] - gap - widths[1]) / 2.0)
	for i in names.size():
		var on := i + 1 == current
		var r := Rect2(x, 0, widths[i], 13)
		UiArt.draw(ci, UiArt.KIT + ("plate_lamp" if on else "plate_frame"), r, -1, -1, UiArt.DROP_CARD)
		var nb := Rect2(x + 3, 2, 9, 8)
		UiArt.well(ci, nb, true)
		Fonts.draw(ci, str(i + 1), Vector2(nb.position.x, Fonts.cap_y("NAME", nb.position.y, nb.size.y)), "NAME",
				Palette.PAPER if on else Palette.MUTED, nb.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		if on:
			Fonts.draw(ci, names[i], Vector2(x + 15, Fonts.cap_y("ON_LAMP", 0, 11)), "ON_LAMP")
		else:
			Fonts.draw(ci, names[i], Vector2(x + 15, Fonts.cap_y("NAME", 0, 11)), "NAME", Palette.MUTED)
		x += widths[i]
		if i == 0:
			UiArt.well(ci, Rect2(x + 3, 5, gap - 6, 3), true)
			x += gap


## A stat tile over `r` in a well (like Game Over's): the icon and the value
## (NUM) centred on top, the caption (SMALL) centred under them. `dim`: a
## locked hero ("?", the icon in LINE).
static func stat_tile(ci: CanvasItem, r: Rect2, icon: Texture2D, value: String, caption: String, dim := false) -> void:
	UiArt.well(ci, r)
	var vw := ceilf(Fonts.width(value, "NUM"))
	var iw := float(icon.get_width()) + 2.0 if icon != null else 0.0
	var x := r.position.x + floorf((r.size.x - iw - vw) / 2.0)
	if icon != null:
		var tex := IconTile._recolored(icon, Palette.LINE) if dim else icon
		ci.draw_texture(tex, Vector2(x, r.position.y + 1 + floorf((11 - icon.get_height()) / 2.0)))
	Fonts.draw(ci, value, Vector2(x + iw, Fonts.cap_y("NUM", r.position.y + 1, 11)), "NUM", Palette.MUTED if dim else -1)
	Fonts.draw(ci, caption, Vector2(r.position.x, r.position.y + 13), "SMALL", Palette.LINE if dim else -1,
			r.size.x, HORIZONTAL_ALIGNMENT_CENTER)


## A row of `tiles` ([icon, value, caption]) across `width` from `at`,
## `cols` to a row (more rows under it). `dim` as stat_tile().
static func stat_tiles(ci: CanvasItem, at: Vector2, width: float, tiles: Array, cols := 4, dim := false) -> void:
	var gap := 3.0
	var w := floorf((width - gap * (cols - 1)) / cols)
	for i in tiles.size():
		var r := Rect2(at + Vector2((i % cols) * (w + gap), floorf(i / float(cols)) * (TILE_H + gap)), Vector2(w, TILE_H))
		stat_tile(ci, r, tiles[i][0], tiles[i][1], tiles[i][2], dim)


## Height of stat_tiles() for `n` tiles.
static func tiles_h(n: int, cols := 4) -> float:
	var rows := ceili(n / float(cols))
	return rows * TILE_H + (rows - 1) * 3.0


## The icon of a stat: the heart for HP, the gem for XP, else the icon of
## the manual that raises it (12 px).
static func stat_icon(db: GameData, stat: String) -> Texture2D:
	match stat:
		"max_hp", "hp":
			return UiArt.texture("hud_heart")
		"xp":
			if _gem == null:
				_gem = HomeScene._tex(GEM)
			return _gem
	for t: Dictionary in db.all("tomes"):
		for m: Dictionary in t.get("modifiers_per_level", []):
			if m.get("stat", "") == stat:
				return Icons.small(db, "tomes", t.id, 12)
	return null


static func stat_value(stat: String, v: float) -> String:
	if stat in MULT_STATS:
		return "x%.1f" % v
	return str(roundi(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v


## [icon, value, caption] tiles for the first `n` HERO_STATS of character
## `c` (its base stats; StatBlock defaults for the ones it leaves out).
## `hidden`: a locked hero, every value "?".
static func hero_tiles(db: GameData, c: Dictionary, n := 8, hidden := false) -> Array:
	var out := []
	for i in mini(n, HERO_STATS.size()):
		var stat: String = HERO_STATS[i][0]
		var v := float(c.get("stats", {}).get(stat, StatBlock.DEFAULTS.get(stat, 0.0)))
		out.append([stat_icon(db, stat), "?" if hidden else stat_value(stat, v), HERO_STATS[i][1]])
	return out


## [icon, value, caption] tiles for an enemy: HP, Damage (a share of your HP
## for the Overdue Bill), Speed, XP. `hidden`: not seen yet ("?").
static func critter_tiles(db: GameData, e: Dictionary, hidden := false) -> Array:
	var dmg := stat_value("damage_flat", float(e.get("damage", 0.0)))
	if e.has("damage_pct_max_hp"):
		dmg = "%d%%" % roundi(float(e.damage_pct_max_hp) * 100.0)
	var vals := [stat_value("hp", float(e.get("hp", 0.0))), dmg, stat_value("speed", float(e.get("speed", 0.0))),
		stat_value("xp", float(e.get("xp", 0.0)))]
	var icons := [stat_icon(db, "max_hp"), stat_icon(db, "damage"), stat_icon(db, "move_speed"), stat_icon(db, "xp")]
	var caps := ["HP", "Damage", "Speed", "XP"]
	var out := []
	for i in 4:
		out.append([icons[i], "?" if hidden else vals[i], caps[i]])
	return out


## An enemy's role chip word: its "tag", else its role's.
static func role_word(e: Dictionary) -> String:
	return String(e.get("tag", ROLE_WORDS.get(e.get("role", ""), "")))


## A chip (kit "chip", CHIP_H tall) at `at` with an optional icon before its
## BODY text. Returns its rect.
static func chip(ci: CanvasItem, at: Vector2, text: String, icon: Texture2D = null) -> Rect2:
	var iw := float(icon.get_width()) + 3.0 if icon != null else 0.0
	var r := Rect2(at.floor(), Vector2(ceilf(Fonts.width(text, "BODY")) + iw + 9.0, CHIP_H))
	UiArt.draw(ci, UiArt.KIT + "chip", r, -1, -1, UiArt.DROP_CARD)
	if icon != null:
		ci.draw_texture(icon, r.position + Vector2(4, floorf((CHIP_H - 1 - icon.get_height()) / 2.0)))
	Fonts.draw(ci, text, Vector2(r.position.x + 4 + iw, Fonts.cap_y("BODY", r.position.y, CHIP_H - 1)), "BODY")
	return r


## A Control holding a chip (for screens built from nodes).
static func chip_node(text: String, icon: Texture2D = null) -> Control:
	var c := Control.new()
	c.name = "Chip"
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size = Vector2(ceilf(Fonts.width(text, "BODY")) + 9.0 + (icon.get_width() + 3.0 if icon != null else 0.0), CHIP_H + 2)
	c.draw.connect(func() -> void: chip(c, Vector2.ZERO, text, icon))
	return c


## An info card over `rect` in `parent` (signature weapon, passive): the icon
## in a slot on its left, the name (NAME) with its kind after it (SMALL), and
## what it does (BODY, muted; shrinks, then wraps).
static func info_card(parent: Control, rect: Rect2, icon: Texture2D, title: String, kind: String, desc: String,
		node_name := "Card") -> Control:
	var c := Control.new()
	c.name = node_name
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.position = rect.position
	c.size = rect.size
	var slot := Rect2(3, 2, rect.size.y - 4, rect.size.y - 4)
	var tw := ceilf(Fonts.width(title, "NAME"))
	c.draw.connect(func() -> void:
		UiArt.card(c, Rect2(Vector2.ZERO, rect.size))
		UiArt.slot(c, slot, "", 0)
		if icon != null:
			var inner := UiArt.slot_inner(slot)
			var s := Vector2(icon.get_size())
			c.draw_texture(icon, (inner.position + (inner.size - s) / 2.0).floor())
		Fonts.draw(c, title, Vector2(slot.end.x + 5, Fonts.cap_y("NAME", 3, 10)), "NAME")
		if kind != "":
			Fonts.draw(c, kind, Vector2(slot.end.x + 5 + tw + 4, Fonts.cap_y("SMALL", 3, 10)), "SMALL"))
	parent.add_child(c)
	var l := Fonts.label(desc, "BODY", Palette.MUTED)
	l.name = "Desc"
	l.position = Vector2(slot.end.x + 5, 14)
	var w := rect.size.x - slot.end.x - 9
	l.size.x = w
	Fonts.fit(l, w)
	c.add_child(l)
	return c


## A slot button for a roster (hero faces, critters): a kit slot with the
## picture at 1x (shrunk to fit), a lamp ring when selected, an optional
## other ring (ready, epic) and marks: a padlock (locked), "?" (unknown).
class Slot extends BaseButton:
	var picture: Texture2D
	var selected := false
	var ring := ""
	var locked := false
	var unknown := false
	var dot := false

	func _init() -> void:
		focus_mode = Control.FOCUS_NONE

	func _pressed() -> void:
		UiArt.click(self, "click")

	func _draw() -> void:
		var sunk := get_draw_mode() == DRAW_PRESSED or get_draw_mode() == DRAW_HOVER_PRESSED
		var r := Rect2(0, 1 if sunk else 0, size.x, size.y - UiArt.DROP_CARD)
		var rg := "sel" if selected else ring
		UiArt.slot(self, r, rg, 0 if sunk else UiArt.DROP_CARD)
		var inner := UiArt.slot_inner(r, rg)
		if picture != null:
			var s := Vector2(picture.get_size())
			draw_texture(picture, (inner.position + (inner.size - s) / 2.0).floor())
		if unknown:
			Fonts.draw(self, "?", Vector2(r.position.x, Fonts.cap_y("TITLE", r.position.y, r.size.y)), "TITLE",
					Palette.FRAME_HI, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		if locked:
			var ls := Vector2(UiArt.sprite_size("kit/lock"))
			UiArt.sprite(self, "kit/lock", r.end - ls - Vector2(4, 4))
		if dot:
			UiArt.dot(self, Vector2(size.x - 6, r.position.y - 3))


## `img` as a texture, shrunk to fit `px` (roster slots).
static func fitted(img: Image, px: int) -> Texture2D:
	return ImageTexture.create_from_image(Icons.fit_in(img, px)) if img != null else null


## A stage: draws `img` at `k`x with its feet (bottom centre) at `feet`; as
## an INK silhouette when `dark`, with a big "?" over it when `mark`.
static func stage_sprite(ci: CanvasItem, img_tex: Texture2D, feet: Vector2, k: int, mark := false) -> void:
	if img_tex == null:
		return
	var s := Vector2(img_tex.get_size()) * k
	var r := Rect2((feet - Vector2(s.x / 2.0, s.y)).floor(), s)
	ci.draw_texture_rect(img_tex, r, false)
	if mark:
		Fonts.draw(ci, "?", Vector2(r.position.x, Fonts.cap_y("HERO", r.position.y, r.size.y * 0.8)), "HERO",
				Palette.FRAME_HI, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)

class_name GoodsCard
extends IconTile
## A coin shop good, kit v2 (docs/ui/shop.png): a raised card with the icon 2x
## on a wooden shelf in a well, the name (NAME), level pips, and a price
## button ("Buy": coin + price; too expensive = disabled with the price in
## alert red), "Max" (disabled) when maxed, or a padlock and how far away it
## is while closed. `pressed` (the card) selects it; Buy buys it.

signal buy

const CARD := Vector2(51, 90)
const BUTTON := Rect2(6, 64, 39, 20)

var title := ""
var price := -1
var affordable := true
## Closed entries: "After 5 runs" and the like.
var why := ""
var _buy_btn: PixelButton


func _ready() -> void:
	super._ready()
	custom_minimum_size = CARD + Vector2(0, UiArt.DROP_CARD)
	_buy_btn = PixelButton.new()
	_buy_btn.name = "Buy"
	_buy_btn.position = BUTTON.position
	_buy_btn.size = BUTTON.size + Vector2(0, PixelButton.SHADOW)
	_buy_btn.custom_minimum_size = _buy_btn.size
	_buy_btn.face = Palette.FRAME
	_buy_btn.art = UiArt.texture("hud_coin")
	_buy_btn.art_plain = true
	_buy_btn.pressed.connect(func() -> void: buy.emit())
	add_child(_buy_btn)
	_sync()


func _sync() -> void:
	if _buy_btn == null:
		return
	_buy_btn.visible = state != "locked" and price >= 0
	_buy_btn.label = str(price)
	_buy_btn.disabled = not affordable
	_buy_btn.ink = Palette.PAPER
	_buy_btn.disabled_ink = Palette.SALMON


func _draw() -> void:
	_sync()
	var r := Rect2(Vector2.ZERO, CARD)
	UiArt.card(self, r)
	# The shelf well: INK-lined WELL with a wooden shelf the icon stands on.
	var well := Rect2(6, 6, 39, 34)
	UiArt.well(self, well, true)
	var shelf_y := well.end.y - 5
	draw_rect(Rect2(well.position.x + 3, shelf_y, well.size.x - 6, 2), Palette.color(Palette.WOOD))
	draw_rect(Rect2(well.position.x + 3, shelf_y + 2, well.size.x - 6, 1), Palette.color(Palette.BARK))
	if picture != null:
		var pic := LevelCard._small(picture) if picture.get_width() == Icons.SIZE else picture
		var s := Vector2(pic.get_size()) * K
		draw_texture_rect(pic, Rect2(Vector2(floorf((CARD.x - s.x) / 2.0), shelf_y - s.y), s), false)
	Fonts.draw(self, title, Vector2(0, 44), "NAME", -1, CARD.x, HORIZONTAL_ALIGNMENT_CENTER, _name_fit())
	if pips_max > 0:
		var pw := pips_max * 7 - 1
		UiArt.pips(self, Vector2(floorf((CARD.x - pw) / 2.0), 56), pips_max, pips)
	if state == "maxed" or price < 0 and state != "locked":
		UiArt.button(self, BUTTON, "disabled")
		Fonts.draw(self, "Max", Vector2(BUTTON.position.x, Fonts.cap_y("BUTTON", BUTTON.position.y, BUTTON.size.y - 1)),
				"BUTTON", Palette.MUTED, BUTTON.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	elif state == "locked":
		UiArt.button(self, BUTTON, "disabled")
		var ls := Vector2(UiArt.sprite_size("kit/lock"))
		UiArt.sprite(self, "kit/lock", Vector2(BUTTON.position.x + 4, BUTTON.position.y + floorf((BUTTON.size.y - ls.y) / 2.0)))
		Fonts.draw(self, why, Vector2(BUTTON.position.x + 12, Fonts.cap_y("SMALL", BUTTON.position.y, BUTTON.size.y - 1)),
				"SMALL", Palette.MUTED, BUTTON.size.x - 14, HORIZONTAL_ALIGNMENT_CENTER)
	if tag == "!":
		UiArt.dot(self, Vector2(CARD.x - 6, -3))


func _name_fit() -> int:
	var fs: int = Fonts.STYLES.NAME[1]
	while fs > Fonts.MIN_TITLE and Fonts.width(title, "NAME", fs) + 4 > CARD.x:
		fs -= 1
	return fs

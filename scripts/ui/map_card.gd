class_name MapCard
extends PixelButton
## A map on the map select screen: a kit 3b `lv_card` in `face` (gold when
## selected) with the thumbnail (data "thumb", 1x), then the name (NAME) and
## the boss (BODY). A locked map is a short disabled card with the padlock and
## one line (the unlock hint), so the screen stays compact.

const THUMB := Vector2i(164, 52)
const HEIGHT := 84
const LOCKED_HEIGHT := 22

var thumb: Texture2D:
	set(v):
		thumb = v
		queue_redraw()
var lines := PackedStringArray():
	set(v):
		lines = v
		queue_redraw()


func _init() -> void:
	_own_label = true
	frame = "lv_card"


func _ready() -> void:
	super._ready()
	custom_minimum_size = Vector2(MenuScreen.W, LOCKED_HEIGHT if disabled else HEIGHT)


func _draw() -> void:
	super._draw()
	var mode := get_draw_mode()
	var y := SHADOW if mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED else 0
	var h := size.y - SHADOW
	if disabled:
		# One line: the padlock and the hint (the "???" name says nothing).
		var ls := Vector2(UiArt.sprite_size(UiArt.PADLOCK))
		UiArt.sprite(self, UiArt.PADLOCK, Vector2(6, y + floorf((h - ls.y) / 2.0)))
		var hint := lines[lines.size() - 1] if lines.size() > 0 else ""
		var asc := Fonts.BODY_FONT.get_ascent(Fonts.STYLES.BODY[1])
		Fonts.draw(self, hint, Vector2(ls.x + 8, y + floorf((h - 1 - asc) / 2.0)), "BODY", Palette.GRAY,
				size.x - ls.x - 16, HORIZONTAL_ALIGNMENT_CENTER)
		return
	var at := Vector2i(floori((size.x - THUMB.x) / 2.0), y + 4)
	if thumb != null:
		draw_texture(thumb, Vector2(at))
	var ty := at.y + THUMB.y + 2
	for i in lines.size():
		var st := "NAME" if i == 0 else "BODY"
		var fs := 9 if i == 0 else -1
		Fonts.draw(self, lines[i], Vector2(0, ty), st, Palette.BUTTER if i == 0 and face == Palette.GOLD else -1,
				size.x, HORIZONTAL_ALIGNMENT_CENTER, fs)
		ty += Fonts.height(st, fs)

@tool
class_name PixelButton
extends Button
## Kit v2 block button (docs/BRIEF.md "Update 1"): INK outline, top and
## bottom bevels, a 2x2 shine and a 3 px INK drop, sinking 2 px when pressed.
## The look comes from `face`: GOLD (or ORANGE / BUTTER) = the lamp primary,
## GREEN / LIME = go (AD x2 rewards only), anything else = the blue secondary;
## disabled = the flat disabled block. Draws its own label so the text moves
## with the face: the first line in Lilita One (BUTTON, white with an INK
## outline, shrunk to fit), further lines in Inter (BODY). Set `label`, not `text`.

const SHADOW := 3
## Titan size of a button's first line before it shrinks to fit.
const BUTTON_SIZE := 9

@export var label := "Button":
	set(v):
		label = v
		queue_redraw()
## Palette index of the button face.
@export var face := Palette.GOLD:
	set(v):
		face = v
		queue_redraw()
## Palette index of the label (INK, the old default, draws PAPER: kit v2
## button labels are white with an INK outline).
@export var ink := Palette.PAPER:
	set(v):
		ink = v
		queue_redraw()
## Palette index of the label while disabled (alert red on a price you
## can't pay yet).
var disabled_ink := Palette.MUTED:
	set(v):
		disabled_ink = v
		queue_redraw()
## Optional 16x16 picture (Icons) on the left, in an 18x18 frame; the label is
## then centered in the space to its right. (Not Button.icon, which Button
## would draw itself.)
var art: Texture2D:
	set(v):
		art = v
		queue_redraw()
## Draw `art` small and frameless, centered together with the label (price tags).
var art_plain := false:
	set(v):
		art_plain = v
		queue_redraw()
## Draw `art` centered above the label instead of on its left (tall buttons
## with long lines, like the level-up cards).
var art_above := false:
	set(v):
		art_above = v
		queue_redraw()
## Pixels on the left kept free of the label (a picture added as a child).
var label_left := 0:
	set(v):
		label_left = v
		queue_redraw()
## A toggle switch (UiArt.toggle) on the right: -1 none,
## 0 off, 1 on. The label is then centered in the space to its left.
var toggle := -1:
	set(v):
		toggle = v
		queue_redraw()
## The UI kit frame: "button" (the kit 3b frame recoloured to `face`) or
## another 9-slice part, also in `face` ("lv_card"); `pressed_frame`
## replaces it while pressed.
var frame := "button":
	set(v):
		frame = v
		queue_redraw()
var pressed_frame := "":
	set(v):
		pressed_frame = v
		queue_redraw()
## Text on a small purple sticker (UiArt "lv_sticker") at the top-right, "" none.
var badge := "":
	set(v):
		badge = v
		queue_redraw()
## The first line in BIG_BUTTON (Play, Resume, Play Again, Nice!).
var big := false:
	set(v):
		big = v
		queue_redraw()
## Every line in BODY (dense buttons).
var small_text := false:
	set(v):
		small_text = v
		queue_redraw()
## Lines after the first are always BODY (kept for callers; no effect now).
var small_rest := false:
	set(v):
		small_rest = v
		queue_redraw()
## Subclasses that draw their own label (AdButton) set this.
var _own_label := false
## Sound played on press (data/rules/audio.json id; "" = none).
var sound := "click"


func _ready() -> void:
	flat = true
	text = ""
	focus_mode = Control.FOCUS_NONE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(96, 18)


func _pressed() -> void:
	UiArt.click(self, sound)


## The kit v2 block for this button: "primary", "secondary", "go" or "disabled".
func kind() -> String:
	if disabled:
		return "disabled"
	if face in [Palette.GOLD, Palette.ORANGE, Palette.BUTTER]:
		return "primary"
	if face in [Palette.GREEN, Palette.LIME, Palette.LEAF]:
		return "go"
	return "secondary"


func _draw() -> void:
	var mode := get_draw_mode()
	var sunk := mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED
	var off := disabled
	var w := int(size.x)
	var h := int(size.y) - SHADOW
	var y := 2 if sunk and not off else 0

	match frame:
		"button":
			UiArt.button(self, Rect2(0, 0, w, h), kind(), sunk)
		"lv_card", "card":
			UiArt.card(self, Rect2(0, y, w, h), UiArt.DROP_CARD if not sunk else 0)
		_:
			var f := pressed_frame if sunk and pressed_frame != "" else frame
			UiArt.draw(self, f, Rect2(0, y, w, h), -1, -1, 0 if sunk else UiArt.DROP_CARD)

	var left := label_left
	var plain_right := 0
	var text_top := y
	var text_h := h
	if art != null and art_plain:
		# A small icon with no frame, centered together with the label.
		var asz := Vector2i(art.get_size())
		var lw := int(ceilf(Fonts.width(label, "BUTTON", _name_size(label, w - asz.x - 10))))
		var ax := (w - asz.x - 3 - lw) / 2
		draw_texture(art, Vector2(ax, y + (h - 2 - asz.y) / 2))
		# The label's centering span is exactly its width, right after the icon.
		left = ax + asz.x + 3
		plain_right = w - left - lw
	elif art != null:
		var at := Vector2i(5, y + (h - ContentIcon.SIZE) / 2)
		if art_above:
			at = Vector2i((w - ContentIcon.SIZE) / 2, y + 4)
		UiArt.slot(self, Rect2(at, Vector2(ContentIcon.SIZE, ContentIcon.SIZE)), "", 0)
		var pic := LevelCard._small(art, ContentIcon.ICON_PX) if art.get_width() == Icons.SIZE else art
		draw_texture(pic, (Vector2(at) + Vector2(ContentIcon.SIZE, ContentIcon.SIZE) / 2.0 + Vector2(0, -1) - pic.get_size() / 2.0).floor())
		if art_above:
			text_top = at.y + ContentIcon.SIZE
			text_h = y + h - text_top
		else:
			left = at.x + ContentIcon.SIZE + 1

	if badge != "":
		UiArt.sticker(self, badge, Vector2(w - ceilf(Fonts.width(badge, "TAG")) - 4, y - 5))
	var right := plain_right
	if toggle >= 0:
		var ts := UiArt.TOGGLE_SIZE
		UiArt.toggle(self, Vector2(w - 5 - ts.x, y + floorf((h - ts.y) / 2.0)), toggle == 1)
		right = int(ts.x) + 6
	if _own_label:
		return
	# One centred line per "\n"-separated part of the label: the first in
	# Lilita One (BUTTON, shrunk to fit), the rest in Inter (BODY).
	var lines := label.split("\n")
	var room := w - right - left - (0 if plain_right > 0 else 8)
	var c := disabled_ink if off else (Palette.PAPER if ink == Palette.INK else ink)
	var sizes := []
	var styles := []
	var total := 0.0
	for i in lines.size():
		var body := small_text or i > 0
		var st := "BODY" if body else ("BIG_BUTTON" if big and i == 0 else "BUTTON")
		var fs: int = Fonts.STYLES.BODY[1] if body else (Fonts.STYLES.BIG_BUTTON[1] if st == "BIG_BUTTON" else _name_size(lines[i], room))
		styles.append(st)
		sizes.append(fs)
		total += _line_h(st, fs)
	# Centre on the face above the bottom bevel (3 px) when it's one line.
	var ty := text_top + floorf((text_h - 3 - total) / 2.0) + 1
	for i in lines.size():
		Fonts.draw(self, lines[i], Vector2(left, ty), styles[i], c, w - right - left, HORIZONTAL_ALIGNMENT_CENTER, sizes[i])
		ty += _line_h(styles[i], sizes[i])


## The BUTTON size (9 down to the display minimum) at which `text` fits `room`.
func _name_size(text: String, room: float) -> int:
	var fs := BUTTON_SIZE
	while fs > Fonts.MIN_TITLE and Fonts.width(text, "BUTTON", fs) + 2 > room:
		fs -= 1
	return fs


static func _line_h(style_name: String, size: int) -> float:
	return size + 2.0 if style_name in ["BUTTON", "BIG_BUTTON"] else size + 1.0

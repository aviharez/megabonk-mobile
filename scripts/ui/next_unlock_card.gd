class_name NextUnlockCard
extends KitButton
## The home screen's "next unlock" card (kit 3 `panel_dark`): its title on top
## (`label`), the reward in an `icon_button` slot (a mystery silhouette, or the
## real icon once it's ready to buy), the star and the three-segment bar
## (`seg_track` filled with `fill_gold`), and the progress text under it.

## Segment insides of seg_track (x from, x to) and their rows.
const SEGS := [[2, 11], [14, 24], [27, 37]]
const SEG_Y := 2
const SEG_H := 5

## 0..1
var frac := 0.0:
	set(v):
		frac = clampf(v, 0.0, 1.0)
		queue_redraw()
var progress := "":
	set(v):
		progress = v
		queue_redraw()
var progress_color := Palette.PAPER:
	set(v):
		progress_color = v
		queue_redraw()
## The reward's icon (shown at 1x up to 16 px, else as is); null: mystery.
var reward: Texture2D:
	set(v):
		reward = v
		queue_redraw()


func _init() -> void:
	part = "panel_dark"
	style_name = "NAV"
	art = null


func _draw() -> void:
	var r := face_rect()
	text_box = Rect2(2, 2, r.size.x - 4, 9)
	super()
	var cx := r.position.x + floorf(r.size.x / 2.0)
	var slot := Rect2(cx - 17, r.position.y + 13, 34, 25)
	UiArt.draw(self, "icon_button", slot)
	var icon := reward if reward != null else UiArt.texture("home/icon_mystery")
	if icon != null:
		var k := 2 if icon.get_width() <= 16 else 1
		var s := icon.get_size() * k
		draw_texture_rect(icon, Rect2((slot.get_center() - s / 2.0).floor(), s), false)
	var bar_at := Vector2(cx - 21 + 6, r.position.y + 41)
	UiArt.sprite(self, "star", Vector2(bar_at.x - 8, bar_at.y))
	UiArt.sprite(self, "seg_track", bar_at)
	for i in SEGS.size():
		var seg: Array = SEGS[i]
		var full: float = seg[1] - seg[0] + 1
		var w := floorf(full * clampf(frac * SEGS.size() - i, 0.0, 1.0))
		if w >= 5.0:
			UiArt.draw(self, "fill_gold", Rect2(bar_at.x + seg[0], bar_at.y + SEG_Y, w, SEG_H))
	if progress != "":
		var fs: int = Fonts.STYLES.NUM[1] - 1
		while fs > Fonts.MIN_TITLE and Fonts.width(progress, "NUM", fs) > r.size.x - 6:
			fs -= 1
		Fonts.draw(self, progress, Vector2(r.position.x + 2, r.position.y + 50), "NUM",
				progress_color, r.size.x - 4, HORIZONTAL_ALIGNMENT_CENTER, fs)

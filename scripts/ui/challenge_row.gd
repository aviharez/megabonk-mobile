class_name ChallengeRow
extends Control
## One challenge with its progress, kit v2 (docs/ui/game-over.png "Almost
## there"): the reward's icon in a slot, the challenge text (BODY), the
## numbers on the right (muted) and a bar under them (lamp, go when done).
## 30 px tall.

const HEIGHT := 30

var text := ""
var reward := ""
var progress := ""
var frac := 0.0
var done := false
var art: Texture2D:
	set(v):
		art = v
		queue_redraw()
var reward_color := Palette.MUTED


func _init() -> void:
	custom_minimum_size = Vector2(150, HEIGHT)
	mouse_filter = MOUSE_FILTER_IGNORE


## ch: challenge entry; p: Meta.progress(); reward_text: what it unlocks.
func setup(ch: Dictionary, p: Dictionary, reward_text: String) -> ChallengeRow:
	text = ch.desc
	reward = reward_text
	progress = Meta.progress_text(ch, p)
	frac = p.frac
	done = p.done
	queue_redraw()
	return self


func _draw() -> void:
	var w := floorf(size.x)
	var sr := Rect2(0, 0, 26, 26)
	UiArt.slot(self, sr, "", 0)
	if art != null:
		var sm := LevelCard._small(art, 12) if art.get_width() > 12 else art
		draw_texture(sm, (sr.get_center() - sm.get_size() / 2.0).floor())
	var pw := ceilf(Fonts.width(progress, "BODY"))
	Fonts.draw(self, progress, Vector2(w - pw, 3), "BODY", Palette.MUTED)
	Fonts.draw(self, text, Vector2(31, 3), "BODY", -1, w - 31 - pw - 4)
	UiArt.bar2(self, Rect2(30, 14, w - 30, 8), 1.0 if done else frac, "go" if done else "lamp")

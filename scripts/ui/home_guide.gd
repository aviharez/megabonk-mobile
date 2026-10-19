class_name HomeGuide
extends Control
## The Home guide after the tutorial (phase 16; data/rules/tutorial.json
## "home_steps", rules in Tutorial): one TutorialTip line at a time with a
## lamp pointer on the button to tap. Each step lists "targets" in order
## ({"at", "text"}); the first one on screen now gets the pointer and its
## line (no target on screen: the step's own "text", no pointer). Targets:
##   home:quests      Home's Quests rail (no screen open)
##   quests:claim     the first Claim on the Quests screen
##   nav:collection   the Collection tile of the bottom nav
##   collection:tile  the step's "content" in the Collection grid (not picked)
##   collection:buy   its Buy button (picked)
## The host (Home) finds them: guide_target(at, content) -> Control, and says
## where the line may sit: guide_floor() -> the y it stays above.
## The guide doesn't block anything; it ends when its last step is done (or
## can't be done), or when a run starts, and then frees itself.

signal finished

var host: Node
var save: Node
var db: GameData
var tip: TutorialTip
var step_id := ""
var target_at := ""


func _init(menu: Node, save_node: Node) -> void:
	host = menu
	save = save_node
	db = GameData.shared()
	name = "HomeGuide"
	mouse_filter = MOUSE_FILTER_IGNORE
	tip = TutorialTip.new()
	tip.hide()
	add_child(tip)


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_update()


func _process(_delta: float) -> void:
	_update()


func _update() -> void:
	var step := Tutorial.guide_step(db, save.data)
	var id := str(step.get("id", ""))
	if id != step_id:
		step_id = id
		save.save_game()
	if step.is_empty():
		tip.say("")
		finished.emit()
		queue_free()
		set_process(false)
		return
	var text := str(step.get("text", ""))
	var target: Control = null
	target_at = ""
	for t: Dictionary in step.get("targets", []):
		var c: Control = host.guide_target(str(t.get("at", "")), str(step.get("content", "")))
		if c != null and c.is_visible_in_tree():
			target = c
			target_at = str(t.at)
			text = str(t.get("text", text))
			break
	# Beside a small target at the left edge (the Quests rail), narrower.
	var vs := get_viewport_rect().size
	var side := target != null and _beside(target.get_global_rect(), vs)
	tip.width = minf(TutorialTip.W, vs.x - target.get_global_rect().end.x - 18.0) if side else float(TutorialTip.W)
	tip.say(text)
	_place(target)


static func _beside(r: Rect2, vs: Vector2) -> bool:
	return r.size.x < 60.0 and r.end.x < vs.x * 0.3


## Beside a small target near a side (the Quests rail), else just above the
## host's floor (Play, the nav or the bottom edge), centred. The pointer hops
## at the target's nearest edge.
func _place(target: Control) -> void:
	var vs := get_viewport_rect().size
	var top := float(SafeArea.top(get_viewport()))
	var floor_y: float = host.guide_floor()
	if floor_y < 0.0:
		tip.say("")
		return
	var at := Vector2(floorf((vs.x - tip.size.x) / 2.0), floorf(floor_y - tip.size.y - 4.0))
	if target == null:
		tip.position = at
		tip.point_at = Vector2.INF
		return
	var r := target.get_global_rect()
	if _beside(r, vs):
		at = Vector2(r.end.x + 14.0, floorf(r.get_center().y - tip.size.y / 2.0))
		tip.point_at = Vector2(r.end.x + 1.0, floorf(r.get_center().y))
	else:
		var above := r.get_center().y > at.y
		tip.point_at = Vector2(floorf(r.get_center().x), r.position.y - 1.0 if above else r.end.y + 1.0)
	at.y = clampf(at.y, top + 2.0, vs.y - tip.size.y - 2.0)
	at.x = clampf(at.x, 2.0, vs.x - tip.size.x - 2.0)
	tip.position = at.floor()

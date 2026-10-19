class_name TutorialFlow
extends RefCounted
## The tutorial run's steps (phase 16; data/rules/tutorial.json "steps"): one
## short line at a time on a TutorialTip, each step moving on once the player
## has done it. Run owns it (options.tutorial) and calls update() every tick.
##
## A step: {"id", "text", "done": {count: n}, optional "start_at_sec" (no
## line before this run time), "spawn" (an interactable put down
## "spawn_dist" [min, max] px from the hero when the step starts: the chest,
## the beacon), "pulse" (the interactable whose edge arrow pulses: the
## altar, the portal), "ghost_stick" (the ghost joystick shows: the old
## first-run stick hint), "card_text" (the Level Up panel's line while the
## step isn't done)}.
## Counts (since the run started): moved_sec, kills, gems, level_ups (cards
## taken), chests, beacons, boss_summoned, boss_defeated, escaped.
## A step already done when its turn comes is passed over at once; one done
## while it shows stays up at least "min_step_sec", so lines never flash by.

var run: Node
var cfg: Dictionary
var steps: Array = []
var index := -1
## Run time the current step's line went up (-1: not up yet).
var shown_at := -1.0
var counts := {"moved_sec": 0.0, "kills": 0, "gems": 0, "level_ups": 0, "chests": 0, "beacons": 0,
	"boss_summoned": 0, "boss_defeated": 0, "escaped": 0}
## The interactable the current step points at ({} = none).
var target: Dictionary = {}
var revives_left := 0
var tip: TutorialTip
var _spawned := false


func _init(owner_run: Node, rules: Dictionary) -> void:
	run = owner_run
	cfg = rules
	steps = rules.get("steps", [])
	revives_left = int(rules.get("free_revives", 0))


func current() -> Dictionary:
	return steps[index] if index >= 0 and index < steps.size() else {}


## The id of the step showing ("" before the first and after the last).
func step_id() -> String:
	return str(current().get("id", ""))


func done(s: Dictionary) -> bool:
	# The step's own object used up counts too (a chest that rolled no item
	# records no "chests_opened").
	if s.has("spawn") and is_same(s, current()) and _spawned and target_pos().x == -INF:
		return true
	var need: Dictionary = s.get("done", {})
	for k: String in need:
		if float(counts.get(k, 0.0)) < float(need[k]):
			return false
	return true


func _started(s: Dictionary) -> bool:
	return run.elapsed >= float(s.get("start_at_sec", 0.0))


## The line the tip shows now ("" = none: between steps, before a timed one).
func line() -> String:
	var s := current()
	return str(s.get("text", "")) if not s.is_empty() and shown_at >= 0.0 else ""


## The Level Up panel's line while a step with "card_text" isn't done yet.
func card_hint() -> String:
	for s: Dictionary in steps:
		if s.has("card_text") and not done(s):
			return str(s.card_text)
	return ""


## Where the bot walks for this step (Vector2(-INF, -INF): nowhere).
func target_pos() -> Vector2:
	if not target.is_empty() and not target.get("used", false) and run.interactables.list.any(func(o: Dictionary) -> bool: return is_same(o, target)):
		return target.pos
	return Vector2(-INF, -INF)


func update(delta: float) -> void:
	if run._moving:
		counts.moved_sec += delta
	counts.kills = run.kills
	counts.gems = run.gems.collected
	counts.level_ups = run.level - 1 - run.pending_levels
	counts.chests = int(run.run_stats.get("chests_opened", 0.0))
	counts.beacons = int(run.run_stats.get("shrines_activated", 0.0))
	counts.boss_summoned = 1 if run.boss_summoned else 0
	counts.boss_defeated = 1 if run.boss_defeated else 0
	if index < 0:
		_go(0)
	var s := current()
	while not s.is_empty():
		if shown_at < 0.0:
			if done(s):
				_go(index + 1)
				s = current()
				continue
			if not _started(s):
				break
			_enter(s)
		if done(s) and run.elapsed - shown_at >= float(cfg.get("min_step_sec", 2.5)):
			_go(index + 1)
			s = current()
			continue
		break
	_refresh_target()
	if tip != null:
		tip.say(line() if run.state == "live" else "")


func _go(i: int) -> void:
	index = i
	shown_at = -1.0
	target = {}
	_spawned = false
	run._joystick.hint = false
	run.interactables.pulse_target = {}


## The step's line goes up: put down its object, light its arrow.
func _enter(s: Dictionary) -> void:
	shown_at = run.elapsed
	if s.get("ghost_stick", false):
		run._joystick.hint = true
	if s.has("spawn"):
		var dist: Array = s.get("spawn_dist", [50, 70])
		var at: Vector2 = run.player_pos() + Vector2.from_angle(run.rng.randf() * TAU) * run.rng.randf_range(float(dist[0]), float(dist[1]))
		at = at.clamp(run.bounds.position + Vector2(16, 16), run.bounds.end - Vector2(16, 16))
		target = run.interactables.add(str(s.spawn), run.free_spot_near(at))
		_spawned = not target.is_empty()
	_refresh_target()


## A "pulse" step points at that object once it's on the map (the portal
## only appears when the boss is down).
func _refresh_target() -> void:
	var s := current()
	if s.has("pulse") and shown_at >= 0.0 and (target.is_empty() or target.get("used", false)):
		target = run.interactables.find(str(s.pulse))
	run.interactables.pulse_target = target if not target.is_empty() and not target.get("used", false) else {}

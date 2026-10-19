class_name Tutorial
extends RefCounted
## The first session (docs/BRIEF.md "Update 1", Phase 16) over the save's
## "tutorial" block; the numbers, lines and counting rules are in
## data/rules/tutorial.json. Pure functions on a Dictionary, like Meta, so the
## splash, the run, Home, the sims and the tests share them.
##
## - Who plays it: a save with no runs played whose tutorial isn't done or
##   skipped (should_start). The splash sends it straight into the run; a
##   save with runs played never sees it.
## - The run: the rules' hero, map and danger (run_options); the run reads
##   the rest itself (scripts/run/tutorial_flow.gd and Run).
## - What counts: everything a run commits, minus the "not_counted" stats
##   (strip_stats), with "leaderboards": true the leaderboard scores
##   (counts_scores), and with "map_progress": true the map cleared and the
##   next Danger level (counts_map_progress).
## - The Home guide: starts when the tutorial ends (finish). Its steps
##   ("home_steps") go in order; a step that is done or can't be done is
##   passed over (guide_step). It ends after the last step, or when the player
##   starts a run from Home (end_guide).
## - Ads stay away while the tutorial runs and while the guide is up
##   (ads_quiet).
##
## Save block "tutorial" (save_manager.gd default_data()):
## - "state": "" (not started), "running" (the tutorial run is on: closing the
##   app mid-run starts it again), "done" or "skipped".
## - "guide": the Home guide step showing ("" = no guide).


static func rules(db: GameData) -> Dictionary:
	return db.get_entry("rules", "tutorial")


static func _block(data: Dictionary) -> Dictionary:
	if not data.get("tutorial") is Dictionary:
		data.tutorial = {"state": "", "guide": ""}
	return data.tutorial


static func state(data: Dictionary) -> String:
	var b: Variant = data.get("tutorial", {})
	return str(b.get("state", "")) if b is Dictionary else ""


## True for a fresh save: no runs played, tutorial not done or skipped.
static func should_start(db: GameData, data: Dictionary) -> bool:
	return not rules(db).is_empty() and int(data.get("runs_played", 0)) == 0 and state(data) in ["", "running"]


## The tutorial run is starting.
static func begin(data: Dictionary) -> void:
	_block(data).state = "running"


## Run.next_options for the tutorial run.
static func run_options(db: GameData) -> Dictionary:
	var r := rules(db)
	return {"tutorial": true, "character": str(r.get("character", "sir_loaf")), "map": str(r.get("map", "suburbia")),
		"danger": int(r.get("danger", 1))}


## A run's stats without the ones the tutorial doesn't count (a stat and
## every weapon / character narrowed key of it).
static func strip_stats(db: GameData, stats: Dictionary) -> Dictionary:
	var out := stats.duplicate()
	var drop: Array = rules(db).get("not_counted", {}).get("stats", [])
	for key: String in stats:
		if Meta.base_stat(key) in drop:
			out.erase(key)
	return out


## Whether the tutorial's boss win opens map progress (the map cleared,
## the next Danger level): not with "not_counted" "map_progress" true (owner,
## 2026-10-19: Danger 2 opens on the first real Danger 1 win, so Danger 3
## doesn't come early).
static func counts_map_progress(db: GameData) -> bool:
	return not bool(rules(db).get("not_counted", {}).get("map_progress", false))


## Whether the tutorial run's scores go to the leaderboards.
static func counts_scores(db: GameData) -> bool:
	return not bool(rules(db).get("not_counted", {}).get("leaderboards", false))


## The tutorial run ended: `how` is "done" (played to the end, won or lost)
## or "skipped". The Home guide starts on its first step.
static func finish(db: GameData, data: Dictionary, how: String) -> void:
	var b := _block(data)
	b.state = how
	var steps: Array = rules(db).get("home_steps", [])
	b.guide = str(steps[0].id) if not steps.is_empty() else ""


static func end_guide(data: Dictionary) -> void:
	if data.get("tutorial") is Dictionary:
		data.tutorial.guide = ""


static func guide_on(data: Dictionary) -> bool:
	var b: Variant = data.get("tutorial", {})
	return b is Dictionary and str(b.get("guide", "")) != ""


## The Home guide step to show now, or {} when the guide is over. Passes over
## steps that are done or can't be done (this writes the save block; the
## caller saves when the step changed).
static func guide_step(db: GameData, data: Dictionary) -> Dictionary:
	if not guide_on(data):
		return {}
	var steps: Array = rules(db).get("home_steps", [])
	var i := -1
	for k in steps.size():
		if str(steps[k].id) == str(data.tutorial.guide):
			i = k
	if i >= 0:
		while i < steps.size():
			var s: Dictionary = steps[i]
			if not step_done(db, data, s) and step_doable(db, data, s):
				data.tutorial.guide = str(s.id)
				return s
			i += 1
	end_guide(data)
	return {}


## Whether a Home guide step is done: "claim_quest" once anything was claimed
## on the Quests screen, "buy_unlock" once its "content" is owned.
static func step_done(db: GameData, data: Dictionary, s: Dictionary) -> bool:
	match str(s.get("kind", "")):
		"claim_quest":
			return not Quests.state(data).get("claimed", {}).is_empty()
		"buy_unlock":
			return Meta.is_owned(db, data, str(s.get("content", "")))
	return true


## Whether a Home guide step can be done now: a quest reward to claim; the
## content ready to buy and the coins for it.
static func step_doable(db: GameData, data: Dictionary, s: Dictionary) -> bool:
	match str(s.get("kind", "")):
		"claim_quest":
			return Quests.total_ready(db, data) > 0
		"buy_unlock":
			var id := str(s.get("content", ""))
			var ch := Meta.challenge_for(db, id)
			return not ch.is_empty() and Meta.state(db, data, id) == "available" and int(data.get("coins", 0)) >= int(ch.price)
	return false


## No ads of any kind while the tutorial runs or the Home guide is up.
static func ads_quiet(data: Dictionary) -> bool:
	return state(data) == "running" or guide_on(data)

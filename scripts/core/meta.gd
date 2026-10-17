class_name Meta
extends RefCounted
## Meta progression rules over the save data (Save.data): the stat tracker
## totals, unlock challenges and the two-step unlock, the coin shop, level-up
## action charges and the Toggler. Pure functions on a Dictionary, so tests
## and the run use them without a scene.
##
## Save keys (all in save_manager.gd default_data()):
## - "playtime": seconds spent in runs, all runs together (commit_run).
## - "stats": cumulative tracker totals, {key: number}. A key is a stat name,
##   optionally narrowed to a weapon (".<weapon id>") and/or a character
##   ("@<character id>"): "kills", "kills.hot_coffee", "kills@sir_loaf",
##   "shots.stapler@gary". Every run stat is added both plain and under the
##   character that played the run.
## - "challenges": per challenge id, the best single-run value ("run" scope),
##   or the count since its prerequisite was owned ("total" scope with
##   "requires"; see own_counter).
## - "unlocks": content id -> "available" (challenge done) or "owned" (bought).
## - "seen": content ids whose "NEW" badge was seen on the unlocks screen.
## - "shop": shop entry id -> level bought.
## - "toggled_off": content ids the Toggler keeps out of the pool.
## - "character": the character picked last.
## - "map": the map picked last.
## - "maps_cleared": map id -> true once its boss was defeated (opens the
##   maps whose "unlock_after" names it).
## - "danger": the danger level picked last.
## - "dangers_beaten": map id -> the highest danger level its boss was beaten
##   on (Danger n + 1 opens then). A save from before danger levels has only
##   "maps_cleared": a cleared map counts as Danger 1 beaten.
## - "play_seen": map id -> the highest danger level Pick a District has
##   shown there (a map in it has been shown): no New! sticker after that.
## - "district_goals": map id -> {"escape": true} once a run there took the
##   portal (the other two goals come from "best_times" and "maps_cleared").
## - "bestiary": enemy id -> {"first_seen": run seconds when one was first on
##   screen, "bonked": how many the player has bonked}. Seen = has
##   "first_seen".
##
## - "quests": daily / weekly draws, quest progress and claims (see
##   scripts/core/quests.gd).
##
## Challenges (data/challenges/): {"stat", optional "weapon" / "character"
## filter, "scope": "run" | "total", "target", optional "goal": "at_most"
## (default "at_least"), optional "requires" (content id that must be owned),
## "reward" (content id with status "unlock"), "price", "tier", "coins" (paid
## once done, claimed on the Quests screen)}.

const CONTENT := ["characters", "weapons", "tomes", "items"]
const TIERS := ["early", "mid", "hard"]
## Stats the run records (Run.record and _end). Data may only name these.
const STATS := [
	"runs_finished", "kills", "shots", "gems_collected", "level", "damage_taken",
	"pots_broken", "shrines_activated", "challenges_won", "chests_opened", "epic_from_paid_chest",
	"items_bought", "max_item_copies", "elites_killed", "keys_found", "pigeon_cage_opened",
	"boss_summoned", "boss_defeated", "boss_defeated_at", "boss_defeated_hp_frac",
	"boss_defeated_in_final_swarm", "swarms_started", "swarm_survived_no_damage",
	"final_swarm_reached", "final_swarm_seconds", "escaped",
]
## One value per run, not a count: never summed into the totals, so only
## "run" scope challenges can use them.
const VALUE_STATS := ["level", "max_item_copies", "final_swarm_seconds", "boss_defeated_at", "boss_defeated_hp_frac"]
## Stats that can be narrowed to a weapon (the run records "<stat>.<weapon>").
const WEAPON_STATS := ["kills", "shots"]
const SHOP_KINDS := ["action", "toggler", "stat"]
const ACTIONS := ["reroll", "skip", "banish"]
const SHOP_NEEDS := ["runs", "unlocks"]


static func stat_key(stat: String, weapon := "", character := "") -> String:
	var k := stat
	if weapon != "":
		k += "." + weapon
	if character != "":
		k += "@" + character
	return k


## The part of a key before any weapon/character filter.
static func base_stat(key: String) -> String:
	return key.get_slice("@", 0).get_slice(".", 0)


# --- Content and unlock state --------------------------------------------------

## The entry for a content id (character, weapon, tome or item), or {}.
static func content(db: GameData, id: String) -> Dictionary:
	for c: String in CONTENT:
		var e := db.get_entry(c, id)
		if not e.is_empty():
			return e
	return {}


static func category_of(db: GameData, id: String) -> String:
	for c: String in CONTENT:
		if not db.get_entry(c, id).is_empty():
			return c
	return ""


## "owned", "available" or "locked". Start content is always owned; a
## signature weapon follows its character.
static func state(db: GameData, data: Dictionary, id: String) -> String:
	var def := content(db, id)
	match def.get("status", ""):
		"start":
			return "owned"
		"signature":
			return "owned" if is_owned(db, data, def.get("character", "")) else "locked"
	var s: String = data.get("unlocks", {}).get(id, "")
	return s if s in ["available", "owned"] else "locked"


static func is_owned(db: GameData, data: Dictionary, id: String) -> bool:
	return state(db, data, id) == "owned"


## Characters the player can pick, in data order (start ones first).
static func owned_characters(db: GameData, data: Dictionary) -> Array:
	var out := []
	for c: Dictionary in db.all("characters"):
		if is_owned(db, data, c.id):
			out.append(c)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.get("status", "") == "start" and b.get("status", "") != "start")
	return out


## Every character in roster order: start ones first, then in the order of
## their unlock challenges (tier, then file name).
static func roster(db: GameData) -> Array:
	var order := challenges(db).map(func(ch: Dictionary) -> String: return ch.reward)
	var list := db.all("characters")
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa: bool = a.get("status", "") == "start"
		var sb: bool = b.get("status", "") == "start"
		if sa != sb:
			return sa
		var ia := order.find(a.id)
		var ib := order.find(b.id)
		return ia < ib or (ia == ib and a.id < b.id))
	return list


## Who plays when nobody picks: the save's last pick if still owned, else
## the first owned character (start ones come first). Names no character.
static func picked_character(db: GameData, data: Dictionary) -> String:
	var last: String = data.get("character", "")
	if last != "" and not db.get_entry("characters", last).is_empty() and is_owned(db, data, last):
		return last
	var owned := owned_characters(db, data)
	return owned[0].id if not owned.is_empty() else ""


## Maps in unlock order: each one after the map whose boss opens it.
static func maps(db: GameData) -> Array:
	var out := []
	var depth := {}
	for m: Dictionary in db.all("maps"):
		var d := 0
		var at: Dictionary = m
		while at.has("unlock_after") and d < 99:
			at = db.get_entry("maps", at.unlock_after)
			d += 1
		depth[m.id] = d
		out.append(m)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return depth[a.id] < depth[b.id] or (depth[a.id] == depth[b.id] and a.id < b.id))
	return out


## "open" (playable), "locked" (boss of the map before not defeated yet) or
## "soon" (a planned map whose turn has come: not playable yet).
static func map_state(db: GameData, data: Dictionary, id: String) -> String:
	var m := db.get_entry("maps", id)
	var status: String = m.get("status", "start")
	var prev_done: bool = data.get("maps_cleared", {}).has(m.get("unlock_after", ""))
	if status == "planned":
		return "soon" if prev_done else "locked"
	return "open" if status == "start" or prev_done else "locked"


## Boss summoned on the map (its altar's "boss"), by name; "" if none.
static func map_boss_name(db: GameData, id: String) -> String:
	var boss := map_boss_id(db, id)
	return db.get_entry("enemies", boss).get("name", "") if boss != "" else ""


## The enemy id of the boss a map's altar summons ("" when it has none).
static func map_boss_id(db: GameData, id: String) -> String:
	for it: Dictionary in db.get_entry("maps", id).get("interactables", []):
		var boss: String = db.get_entry("interactables", it.get("id", "")).get("boss", "")
		if boss != "":
			return boss
	return ""


## What a locked map card says.
static func map_hint(db: GameData, data: Dictionary, id: String) -> String:
	match map_state(db, data, id):
		"soon":
			return "Coming soon"
		"locked":
			var prev: String = db.get_entry("maps", id).get("unlock_after", "")
			var boss := map_boss_name(db, prev)
			if map_state(db, data, prev) == "open" and boss != "":
				return "Beat %s on Danger 1" % boss
			var name := district_title(db, data, prev)
			return "Clear the " + name if name != "???" else "Clear the district before"
	return ""


## A district's name where the play flow shows it: known once it's open (or
## coming soon) or next in line (the map before it is open), else "???".
static func district_title(db: GameData, data: Dictionary, id: String) -> String:
	var m := db.get_entry("maps", id)
	var prev: String = m.get("unlock_after", "")
	if map_state(db, data, id) != "locked" or prev == "" or map_state(db, data, prev) == "open":
		return String(m.get("name", "???"))
	return "???"


## Playable districts, in unlock order.
static func open_maps(db: GameData, data: Dictionary) -> Array:
	return maps(db).filter(func(m: Dictionary) -> bool: return map_state(db, data, m.id) == "open")


## The district card's three goals as [[text, done], ...]: survive the
## timer (best time), beat the boss (map cleared; only on a map with a boss)
## and escape through the portal.
static func district_goals(db: GameData, data: Dictionary, id: String) -> Array:
	var sec := int(db.get_entry("rules", "run").get("run_length_sec", 480))
	var best := float(data.get("best_times", {}).get(id, 0.0))
	var out := [["Survive %d:%02d" % [sec / 60, sec % 60], best >= sec]]
	var boss := map_boss_name(db, id)
	if boss != "":
		out.append(["Beat " + boss, data.get("maps_cleared", {}).has(id)])
	out.append(["Escape through the portal", bool(data.get("district_goals", {}).get(id, {}).get("escape", false))])
	return out


# --- Danger levels (data/danger/) ---------------------------------------------

## Danger levels in order (1, 2, 3...). Data with none plays as one level
## without modifiers.
static func dangers(db: GameData) -> Array:
	var list := db.all("danger")
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.level < b.level)
	return list


static func danger_count(db: GameData) -> int:
	return maxi(1, db.all("danger").size())


## The entry for danger `level`, or {} (no modifiers, coins x1).
static func danger_def(db: GameData, level: int) -> Dictionary:
	for d: Dictionary in db.all("danger"):
		if int(d.level) == level:
			return d
	return {}


## The one-line rule under the Danger row: "Elites every ~75 s, coins x1.5"
## (the middle of the elite interval: the map's when the level doesn't set it).
static func danger_rule(db: GameData, level: int, map_id := "suburbia") -> String:
	var d := danger_def(db, level)
	var every: Array = d.get("modifiers", {}).get("elite_every_sec", db.get_entry("maps", map_id).get("elites", {}).get("every_sec", [60, 90]))
	var mid := roundi((float(every[0]) + float(every[1])) / 2.0)
	return "Elites every ~%d s, coins x%.1f" % [mid, float(d.get("coin_mult", 1.0))]


## The highest danger level whose boss was beaten on map `id` (0: none).
static func danger_beaten(data: Dictionary, id: String) -> int:
	var n := int(data.get("dangers_beaten", {}).get(id, 0))
	if n == 0 and data.get("maps_cleared", {}).has(id):
		return 1
	return n


## How many danger levels are open on map `id` (0 when the map isn't): Danger
## 1, and Danger n + 1 once its boss is beaten on Danger n.
static func open_dangers(db: GameData, data: Dictionary, id: String) -> int:
	if map_state(db, data, id) != "open":
		return 0
	return mini(danger_count(db), danger_beaten(data, id) + 1)


static func danger_open(db: GameData, data: Dictionary, id: String, level: int) -> bool:
	return level >= 1 and level <= open_dangers(db, data, id)


## The danger picked last if it's open on `map_id`, else the highest open one.
static func picked_danger(db: GameData, data: Dictionary, map_id: String) -> int:
	return clampi(int(data.get("danger", 1)), 1, maxi(1, open_dangers(db, data, map_id)))


## Pick a District is skipped while there is nothing to pick: one district
## open, with only Danger 1.
static func skip_district_step(db: GameData, data: Dictionary) -> bool:
	var open := open_maps(db, data)
	return open.size() <= 1 and (open.is_empty() or open_dangers(db, data, open[0].id) <= 1)


## New! on the district step: an open district it hasn't shown yet (never
## the start district) ...
static func district_is_new(db: GameData, data: Dictionary, id: String) -> bool:
	return map_state(db, data, id) == "open" and db.get_entry("maps", id).get("status", "start") != "start" \
			and not data.get("play_seen", {}).has(id)


## ... or a danger level above 1 that opened since it last showed that map.
static func danger_is_new(db: GameData, data: Dictionary, id: String, level: int) -> bool:
	return level > 1 and danger_open(db, data, id, level) and int(data.get("play_seen", {}).get(id, 1)) < level


## The district step showed every open district and danger level.
static func mark_play_seen(db: GameData, data: Dictionary) -> void:
	if not data.has("play_seen"):
		data.play_seen = {}
	for m: Dictionary in open_maps(db, data):
		data.play_seen[m.id] = maxi(int(data.play_seen.get(m.id, 1)), open_dangers(db, data, m.id))


# --- Bestiary -----------------------------------------------------------------

## Every enemy, in bestiary order ("dex", then id).
static func bestiary(db: GameData) -> Array:
	var list := db.all("enemies")
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da := float(a.get("dex", 999))
		var dbx := float(b.get("dex", 999))
		return da < dbx or (da == dbx and a.id < b.id))
	return list


static func critter_seen(data: Dictionary, id: String) -> bool:
	return data.get("bestiary", {}).get(id, {}).has("first_seen")


static func critters_seen(db: GameData, data: Dictionary) -> int:
	return bestiary(db).filter(func(e: Dictionary) -> bool: return critter_seen(data, e.id)).size()


## Adds a run's sightings and bonks to the bestiary: `seen` {enemy id: run
## seconds when one was first on screen}, `bonked` {enemy id: count}. The
## first sighting ever stays.
static func commit_bestiary(data: Dictionary, seen: Dictionary, bonked: Dictionary) -> void:
	if not data.has("bestiary"):
		data.bestiary = {}
	for id: String in seen:
		var e: Dictionary = data.bestiary.get(id, {})
		if not e.has("first_seen"):
			e.first_seen = float(seen[id])
		data.bestiary[id] = e
	for id: String in bonked:
		var e: Dictionary = data.bestiary.get(id, {})
		e.bonked = int(e.get("bonked", 0)) + int(bonked[id])
		data.bestiary[id] = e


## The save's last map if still open, else the first open map.
static func picked_map(db: GameData, data: Dictionary) -> String:
	var last: String = data.get("map", "")
	if last != "" and not db.get_entry("maps", last).is_empty() and map_state(db, data, last) == "open":
		return last
	for m: Dictionary in maps(db):
		if map_state(db, data, m.id) == "open":
			return m.id
	return ""


## Bought unlocks (for the Toggler's "after 12 unlocks").
static func owned_unlock_count(data: Dictionary) -> int:
	var n := 0
	for id: String in data.get("unlocks", {}):
		if data.unlocks[id] == "owned":
			n += 1
	return n


## Challenges in tier order (early, mid, hard), then by file name.
static func challenges(db: GameData) -> Array:
	var list := db.all("challenges")
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ta := TIERS.find(a.tier)
		var tb := TIERS.find(b.tier)
		return ta < tb or (ta == tb and a.id < b.id))
	return list


## The challenge that unlocks content `id`, or {}.
static func challenge_for(db: GameData, id: String) -> Dictionary:
	for ch: Dictionary in db.all("challenges"):
		if ch.reward == id:
			return ch
	return {}


static func requirement_met(db: GameData, data: Dictionary, ch: Dictionary) -> bool:
	var req: String = ch.get("requires", "")
	return req == "" or is_owned(db, data, req)


static func is_done(db: GameData, data: Dictionary, ch: Dictionary) -> bool:
	return state(db, data, ch.reward) != "locked"


## Progress of a challenge: {"value", "has_value", "frac" (0..1), "done",
## "blocked" (its requirement isn't owned yet)}. "run" scope shows the best
## single run so far; "total" the sum over every run (with a prerequisite:
## every run since it was owned).
static func progress(db: GameData, data: Dictionary, ch: Dictionary) -> Dictionary:
	var done := is_done(db, data, ch)
	var has := false
	var v := 0.0
	if ch.scope == "total" and not own_counter(ch):
		var stats: Dictionary = data.get("stats", {})
		var key := stat_key(ch.stat, ch.get("weapon", ""), ch.get("character", ""))
		has = stats.has(key)
		v = float(stats.get(key, 0.0))
	else:
		has = data.get("challenges", {}).has(ch.id)
		v = float(data.get("challenges", {}).get(ch.id, 0.0))
	var target := float(ch.target)
	var frac := 0.0
	if done:
		frac = 1.0
	elif _at_most(ch):
		# "Defeat the boss before minute 4": closer as the best time drops.
		frac = clampf(target / v, 0.0, 0.99) if has and v > 0.0 else 0.0
	else:
		frac = clampf(v / target, 0.0, 0.99) if target > 0.0 else 0.0
	return {"value": v, "has_value": has, "frac": frac, "done": done, "blocked": not requirement_met(db, data, ch)}


## Progress text, e.g. "1234/3000", "Best 5:12 / 4:00", "Best 31% / 20%".
static func progress_text(ch: Dictionary, p: Dictionary) -> String:
	if p.done:
		return "Done"
	var fmt := func(x: float) -> String: return format_stat(ch.stat, x)
	if _at_most(ch):
		return "Best %s / %s" % [fmt.call(p.value) if p.has_value else "-", fmt.call(float(ch.target))]
	return "%s/%s" % [fmt.call(minf(p.value, float(ch.target))), fmt.call(float(ch.target))]


## A stat value as the player reads it: times as m:ss, HP fractions as %,
## counts as whole numbers.
static func format_stat(stat: String, x: float) -> String:
	match stat:
		"boss_defeated_at", "final_swarm_seconds":
			return "%d:%02d" % [int(x) / 60, int(x) % 60]
		"boss_defeated_hp_frac":
			return "%d%%" % roundi(x * 100.0)
	return Num.full(floori(x))


## A "total" challenge with a prerequisite keeps its own count in "challenges",
## so only runs played once the prerequisite is owned add to it (the shared
## "stats" totals also hold the runs before).
static func own_counter(ch: Dictionary) -> bool:
	return ch.scope == "total" and ch.get("requires", "") != ""


static func _at_most(ch: Dictionary) -> bool:
	return ch.get("goal", "at_least") == "at_most"


static func _meets(ch: Dictionary, v: float) -> bool:
	return v <= float(ch.target) if _at_most(ch) else v >= float(ch.target)


## The 2-3 unfinished challenges closest to done (requirement owned), for the
## game-over screen.
static func closest(db: GameData, data: Dictionary, n := 3) -> Array:
	var list := []
	for ch: Dictionary in challenges(db):
		var p := progress(db, data, ch)
		if not p.done and not p.blocked:
			list.append({"challenge": ch, "progress": p})
	# Stable: equal progress keeps tier order (early first).
	var order := range(list.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		var fa: float = list[a].progress.frac
		var fb: float = list[b].progress.frac
		return fa > fb or (fa == fb and a < b))
	return order.slice(0, n).map(func(i: int) -> Dictionary: return list[i])


## Content ids whose challenge is done but that aren't bought yet.
static func ready_to_buy(db: GameData, data: Dictionary) -> Array:
	var out := []
	for ch: Dictionary in challenges(db):
		if state(db, data, ch.reward) == "available":
			out.append(ch.reward)
	return out


## True when something is available that the unlocks screen hasn't shown
## yet (the main menu's notification dot).
static func has_news(db: GameData, data: Dictionary) -> bool:
	for id: String in ready_to_buy(db, data):
		if not data.get("seen", {}).has(id):
			return true
	return false


static func mark_seen(db: GameData, data: Dictionary) -> void:
	for id: String in ready_to_buy(db, data):
		data.seen[id] = true


## Step two of an unlock: spend coins on available content. Returns true if
## bought. A character also brings its signature weapon into the pool
## (ContentPool follows character ownership).
static func buy(db: GameData, data: Dictionary, id: String) -> bool:
	var ch := challenge_for(db, id)
	if ch.is_empty() or state(db, data, id) != "available":
		return false
	var price := int(ch.price)
	if int(data.coins) < price:
		return false
	data.coins = int(data.coins) - price
	data.unlocks[id] = "owned"
	return true


# --- Committing a run ---------------------------------------------------------

## Adds a finished run to the save: coins, runs played, the tracker totals,
## best run values, the map's boss cleared (`map`) on `danger` (opens the
## next level), its best time (`seconds` survived) and goals, and newly completed
## challenges (their rewards become "available"). `run_stats` is Run.result.stats. Returns the ids of the
## challenges completed by this run. Doesn't write the file.
static func commit_run(db: GameData, data: Dictionary, run_stats: Dictionary, character: String, coins: int, map := "",
		seconds := -1.0, danger := 1) -> Array:
	data.runs_played = int(data.runs_played) + 1
	if seconds > 0.0:
		data.playtime = float(data.get("playtime", 0.0)) + seconds
	if map != "" and seconds >= 0.0:
		if not data.has("best_times"):
			data.best_times = {}
		data.best_times[map] = maxf(float(data.best_times.get(map, 0.0)), seconds)
	if map != "" and float(run_stats.get("boss_defeated", 0.0)) > 0.0:
		data.maps_cleared[map] = true
		if not data.has("dangers_beaten"):
			data.dangers_beaten = {}
		data.dangers_beaten[map] = maxi(danger_beaten(data, map), danger)
	if map != "" and float(run_stats.get("escaped", 0.0)) > 0.0:
		if not data.has("district_goals"):
			data.district_goals = {}
		var g: Dictionary = data.district_goals.get(map, {})
		g.escape = true
		data.district_goals[map] = g
	data.coins = int(data.coins) + coins
	var totals: Dictionary = data.stats
	for key: String in run_stats:
		if base_stat(key) in VALUE_STATS:
			continue
		var v := float(run_stats[key])
		totals[key] = float(totals.get(key, 0.0)) + v
		var ck := key + "@" + character
		totals[ck] = float(totals.get(ck, 0.0)) + v
	var completed := []
	for ch: Dictionary in challenges(db):
		# A run played before the prerequisite was owned doesn't count for it
		# (prerequisites are bought in the menu, so this is the run's state).
		if not requirement_met(db, data, ch):
			continue
		if ch.scope == "run":
			_update_best(data, ch, run_stats, character)
		elif own_counter(ch):
			_add_count(data, ch, run_stats, character)
		if is_done(db, data, ch):
			continue
		var p := progress(db, data, ch)
		if p.has_value and _meets(ch, p.value):
			data.unlocks[ch.reward] = "available"
			completed.append(ch.id)
	return completed


## The run's value for a challenge (its weapon and character filters
## applied), or null if the run didn't record it.
static func _run_value(ch: Dictionary, run_stats: Dictionary, character: String) -> Variant:
	var who: String = ch.get("character", "")
	if who != "" and who != character:
		return null
	var key := stat_key(ch.stat, ch.get("weapon", ""))
	return float(run_stats[key]) if run_stats.has(key) else null


## The run's value for a run-scope challenge, kept if it beats the best.
static func _update_best(data: Dictionary, ch: Dictionary, run_stats: Dictionary, character: String) -> void:
	var rv: Variant = _run_value(ch, run_stats, character)
	if rv == null:
		return
	var v: float = rv
	var best: Dictionary = data.challenges
	if not best.has(ch.id):
		best[ch.id] = v
	elif _at_most(ch):
		best[ch.id] = minf(float(best[ch.id]), v)
	else:
		best[ch.id] = maxf(float(best[ch.id]), v)


## Adds the run's value to a challenge's own count (see own_counter).
static func _add_count(data: Dictionary, ch: Dictionary, run_stats: Dictionary, character: String) -> void:
	var rv: Variant = _run_value(ch, run_stats, character)
	if rv != null:
		data.challenges[ch.id] = float(data.challenges.get(ch.id, 0.0)) + float(rv)


# --- Coin shop ----------------------------------------------------------------

static func shop_level(data: Dictionary, id: String) -> int:
	return int(data.get("shop", {}).get(id, 0))


## Whether the entry can be bought yet ("needs": {"runs": n} / {"unlocks": n}).
static func shop_open(data: Dictionary, entry: Dictionary) -> bool:
	var needs: Dictionary = entry.get("needs", {})
	return int(data.runs_played) >= int(needs.get("runs", 0)) and owned_unlock_count(data) >= int(needs.get("unlocks", 0))


## Price of the next level, or -1 when maxed.
static func shop_price(data: Dictionary, entry: Dictionary) -> int:
	var lvl := shop_level(data, entry.id)
	return int(entry.prices[lvl]) if lvl < entry.prices.size() else -1


## Buys the next level of a shop entry (not one that moved into a Town
## building: Town.build levels those).
static func buy_shop(db: GameData, data: Dictionary, id: String) -> bool:
	var entry := db.get_entry("shop", id)
	if entry.is_empty() or not shop_open(data, entry) or Town.shop_owner(db).has(id):
		return false
	var price := shop_price(data, entry)
	if price < 0 or int(data.coins) < price:
		return false
	data.coins = int(data.coins) - price
	data.shop[id] = shop_level(data, id) + 1
	return true


## Charges per run of a level-up action ("reroll", "skip", "banish").
static func charges(db: GameData, data: Dictionary, action: String) -> int:
	for e: Dictionary in db.all("shop"):
		if e.kind == "action" and e.get("action", "") == action:
			var lvl := shop_level(data, e.id)
			return int(e.charges[lvl - 1]) if lvl > 0 else 0
	return 0


## The shop entry for a level-up action ({} if none).
static func action_entry(db: GameData, action: String) -> Dictionary:
	for e: Dictionary in db.all("shop"):
		if e.kind == "action" and e.get("action", "") == action:
			return e
	return {}


## How many things the Toggler may keep out of the pool (0 = not bought).
static func toggler_slots(db: GameData, data: Dictionary) -> int:
	for e: Dictionary in db.all("shop"):
		if e.kind == "toggler":
			var lvl := shop_level(data, e.id)
			return int(e.charges[lvl - 1]) if lvl > 0 else 0
	return 0


## Permanent stat upgrades as [[source, modifiers_per_level, level], ...].
## Upgrades that moved into a Town building (its "shop") come from
## Town.stat_bonuses instead.
static func stat_bonuses(db: GameData, data: Dictionary) -> Array:
	var out := []
	var moved := Town.shop_owner(db)
	for e: Dictionary in db.all("shop"):
		if e.kind == "stat" and shop_level(data, e.id) > 0 and not moved.has(e.id):
			out.append(["shop:" + e.id, e.modifiers_per_level, shop_level(data, e.id)])
	return out


## Weapons, tomes and items the Toggler can switch: owned, in the pool.
static func toggleable(db: GameData, data: Dictionary) -> Array:
	var out := []
	for c: String in ["weapons", "tomes", "items"]:
		for e: Dictionary in db.all(c):
			if is_owned(db, data, e.id):
				out.append(e)
	return out


## Turns content off (or back on). Off needs a free Toggler slot.
static func toggle(db: GameData, data: Dictionary, id: String) -> bool:
	var off: Dictionary = data.toggled_off
	if off.has(id):
		off.erase(id)
		return true
	if off.size() >= toggler_slots(db, data) or not toggleable(db, data).any(func(e: Dictionary) -> bool: return e.id == id):
		return false
	off[id] = true
	return true


## Short name of a content kind for silhouettes: "Hero", "Weapon", "Manual", "Item".
static func kind_name(db: GameData, id: String) -> String:
	return {"characters": "Hero", "weapons": "Weapon", "tomes": "Manual", "items": "Item"}.get(category_of(db, id), "?")

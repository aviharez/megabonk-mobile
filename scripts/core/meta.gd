class_name Meta
extends RefCounted
## Meta progression rules over the save data (Save.data): the stat tracker
## totals, unlock challenges and the two-step unlock, the coin shop, level-up
## action charges and the Toggler. Pure functions on a Dictionary, so tests
## and the run use them without a scene.
##
## Save keys (all in save_manager.gd default_data()):
## - "stats": cumulative tracker totals, {key: number}. A key is a stat name,
##   optionally narrowed to a weapon (".<weapon id>") and/or a character
##   ("@<character id>"): "kills", "kills.hot_coffee", "kills@sir_loaf",
##   "shots.stapler@gary". Every run stat is added both plain and under the
##   character that played the run.
## - "challenges": best single-run value per run-scope challenge id.
## - "unlocks": content id -> "available" (challenge done) or "owned" (bought).
## - "seen": content ids whose "NEW" badge was seen on the unlocks screen.
## - "shop": shop entry id -> level bought.
## - "toggled_off": content ids the Toggler keeps out of the pool.
## - "character": the character picked last.
##
## Challenges (data/challenges/): {"stat", optional "weapon" / "character"
## filter, "scope": "run" | "total", "target", optional "goal": "at_most"
## (default "at_least"), optional "requires" (content id that must be owned),
## "reward" (content id with status "unlock"), "price", "tier"}.

const CONTENT := ["characters", "weapons", "tomes", "items"]
const TIERS := ["early", "mid", "hard"]
## Stats the run records (Run.record and _end). Data may only name these.
const STATS := [
	"runs_finished", "kills", "shots", "gems_collected", "level", "damage_taken",
	"pots_broken", "shrines_activated", "challenges_won", "chests_opened", "epic_from_paid_chest",
	"items_bought", "max_item_copies", "elites_killed", "keys_found", "pigeon_cage_opened",
	"boss_summoned", "boss_defeated", "boss_defeated_at", "boss_defeated_hp_frac",
	"boss_defeated_in_final_swarm", "swarms_started", "swarm_survived_no_damage",
	"final_swarm_reached", "final_swarm_seconds",
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
## single run so far; "total" the sum over every run.
static func progress(db: GameData, data: Dictionary, ch: Dictionary) -> Dictionary:
	var done := is_done(db, data, ch)
	var has := false
	var v := 0.0
	if ch.scope == "total":
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


## Progress text, e.g. "1234/3000", "BEST 5:12 / 4:00", "BEST 31% / 20%".
static func progress_text(ch: Dictionary, p: Dictionary) -> String:
	if p.done:
		return "DONE"
	var fmt := func(x: float) -> String:
		match ch.stat:
			"boss_defeated_at", "final_swarm_seconds":
				return "%d:%02d" % [int(x) / 60, int(x) % 60]
			"boss_defeated_hp_frac":
				return "%d%%" % roundi(x * 100.0)
		return str(floori(x))
	if _at_most(ch):
		return "BEST %s / %s" % [fmt.call(p.value) if p.has_value else "-", fmt.call(float(ch.target))]
	return "%s/%s" % [fmt.call(minf(p.value, float(ch.target))), fmt.call(float(ch.target))]


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
## best run values, and newly completed challenges (their rewards become
## "available"). `run_stats` is Run.result.stats. Returns the ids of the
## challenges completed by this run. Doesn't write the file.
static func commit_run(db: GameData, data: Dictionary, run_stats: Dictionary, character: String, coins: int) -> Array:
	data.runs_played = int(data.runs_played) + 1
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
		if ch.scope == "run":
			_update_best(data, ch, run_stats, character)
		if is_done(db, data, ch) or not requirement_met(db, data, ch):
			continue
		var p := progress(db, data, ch)
		if p.has_value and _meets(ch, p.value):
			data.unlocks[ch.reward] = "available"
			completed.append(ch.id)
	return completed


## The run's value for a run-scope challenge, kept if it beats the best.
static func _update_best(data: Dictionary, ch: Dictionary, run_stats: Dictionary, character: String) -> void:
	var who: String = ch.get("character", "")
	if who != "" and who != character:
		return
	var key := stat_key(ch.stat, ch.get("weapon", ""))
	if not run_stats.has(key):
		return
	var v := float(run_stats[key])
	var best: Dictionary = data.challenges
	if not best.has(ch.id):
		best[ch.id] = v
	elif _at_most(ch):
		best[ch.id] = minf(float(best[ch.id]), v)
	else:
		best[ch.id] = maxf(float(best[ch.id]), v)


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


static func buy_shop(db: GameData, data: Dictionary, id: String) -> bool:
	var entry := db.get_entry("shop", id)
	if entry.is_empty() or not shop_open(data, entry):
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
static func stat_bonuses(db: GameData, data: Dictionary) -> Array:
	var out := []
	for e: Dictionary in db.all("shop"):
		if e.kind == "stat" and shop_level(data, e.id) > 0:
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


## Short name of a content kind for silhouettes: "HERO", "WEAPON", "TOME", "ITEM".
static func kind_name(db: GameData, id: String) -> String:
	return {"characters": "HERO", "weapons": "WEAPON", "tomes": "TOME", "items": "ITEM"}.get(category_of(db, id), "?")

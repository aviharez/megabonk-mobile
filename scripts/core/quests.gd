class_name Quests
extends RefCounted
## Quests (docs/BRIEF.md "Update 1", Quests) over the save's "quests" block.
## Pure functions on a Dictionary, like Meta, so tests, the run and the
## Quests screen share them.
##
## Quest files (data/quests/) use the challenge schema ("stat", optional
## "weapon" / "character" filters, "scope" run or total, "target", optional
## "goal": "at_most", "requires") plus "kind" (daily, weekly, milestone),
## "reward": {"coins", "points"} and "repeat" (true: the quest comes back in
## a later draw and can be done again; dailies and weeklies are, milestones
## aren't). Optional "danger": the run must be on this danger level or higher.
## Optional "icon": an Icons.ref path (else data/rules/quests.json "icons"
## by stat).
##
## - Daily: rules "daily_count" drawn from the daily pool at local midnight.
##   A claim adds its "points"; the points chests (rules "chests") open at
##   their points. Points and chests start over each day.
## - Weekly: rules "weekly_count" drawn on Monday at local midnight.
## - Milestones: permanent. A "total" milestone without a "danger" filter
##   reads the lifetime totals (Meta "stats"), so play from before quests
##   counts; any other keeps its own value from runs played since. Each chain
##   (same stat, filters and scope) shows its lowest unclaimed tier.
## - The 19 unlock challenges also pay their "coins" once done, claimed in
##   the Milestones tab ("challenge:<id>").
## - Daily and weekly progress counts from the draw: "total" sums the runs,
##   "run" keeps the best single run. Progress is added when a run ends.
## - One claim a day can be paid again through a rewarded ad (double_last()).
##
## Save block "quests" (save_manager.gd default_data()):
## - "day" / "week": the local day and Monday-based week of the current draw
##   (-1: never drawn); "daily" / "weekly": the drawn quest ids.
## - "progress": quest id -> value (daily / weekly since the draw; milestones
##   that keep their own value).
## - "claimed": quest id or "challenge:<id>" -> true (daily / weekly ones are
##   cleared at the next draw).
## - "points": daily points today; "chests": indices of today's opened chests.
## - "last_claim": {"id", "coins", "day"}: the claim AD x2 would pay again;
##   "doubled_day": the day AD x2 was used.
## - "earned": coins paid by quests, chests, challenges and AD x2 (balance).

const KINDS := ["daily", "weekly", "milestone"]
const DAY := 86400
## Day 0 (1970-01-01) was a Thursday: 3 days after the Monday that starts week 0.
const WEEK_OFFSET := 3
const CHALLENGE := "challenge:"

## Local time now, as seconds since 1970-01-01 00:00 local time (so whole
## days fall on local midnight). Tests swap in a fake clock.
static var clock: Callable = system_clock


static func system_clock() -> int:
	return Time.get_unix_time_from_datetime_dict(Time.get_datetime_dict_from_system(false))


static func now() -> int:
	return int(clock.call())


static func day_of(t: int) -> int:
	return floori(t / float(DAY))


## Weeks start on Monday at local midnight.
static func week_of(t: int) -> int:
	return floori((day_of(t) + WEEK_OFFSET) / 7.0)


## Seconds until the dailies roll (next local midnight).
static func until_daily(t: int) -> int:
	return (day_of(t) + 1) * DAY - t


## Seconds until the weeklies roll (next Monday, local midnight).
static func until_weekly(t: int) -> int:
	return ((week_of(t) + 1) * 7 - WEEK_OFFSET) * DAY - t


## "7h 12m", "3d 4h", "12m".
static func countdown(sec: int) -> String:
	var m := maxi(0, sec) / 60
	var h := m / 60
	if h >= 24:
		return "%dd %dh" % [h / 24, h % 24]
	if h > 0:
		return "%dh %dm" % [h, m % 60]
	return "%dm" % maxi(1, m)


static func rules(db: GameData) -> Dictionary:
	return db.get_entry("rules", "quests")


static func state(data: Dictionary) -> Dictionary:
	if not data.has("quests") or not data.quests is Dictionary:
		data.quests = {}
	var q: Dictionary = data.quests
	for k: String in ["progress", "claimed", "last_claim"]:
		if not q.get(k) is Dictionary:
			q[k] = {}
	for k: String in ["daily", "weekly", "chests"]:
		if not q.get(k) is Array:
			q[k] = []
	return q


## Quests of a kind, by id.
static func of_kind(db: GameData, kind: String) -> Array:
	return db.all("quests").filter(func(e: Dictionary) -> bool: return e.kind == kind)


# --- Draws -------------------------------------------------------------------

## Draws new dailies at local midnight and weeklies on Monday (if due).
## Returns true if anything was drawn.
static func roll(db: GameData, data: Dictionary, t := -1) -> bool:
	if t < 0:
		t = now()
	var q := state(data)
	var r := rules(db)
	var changed := false
	var d := day_of(t)
	if int(q.get("day", -1)) != d:
		q.daily = _redraw(db, data, "daily", q.daily, int(r.get("daily_count", 3)), d)
		q.day = d
		q.points = 0
		q.chests = []
		changed = true
	var w := week_of(t)
	if int(q.get("week", -1)) != w:
		q.weekly = _redraw(db, data, "weekly", q.weekly, int(r.get("weekly_count", 5)), w)
		q.week = w
		changed = true
	return changed


## Forgets the old draw's progress and claims, then draws `n` eligible quests
## of `kind` (seeded by the period, so a day's draw is the same on a replay),
## avoiding the last draw while the pool has enough others.
static func _redraw(db: GameData, data: Dictionary, kind: String, old: Array, n: int, period: int) -> Array:
	var q := state(data)
	for id: String in old:
		q.progress.erase(id)
		q.claimed.erase(id)
	var pool := of_kind(db, kind).filter(func(e: Dictionary) -> bool: return eligible(db, data, e)).map(
			func(e: Dictionary) -> String: return e.id)
	var fresh := pool.filter(func(id: String) -> bool: return not id in old)
	if fresh.size() >= n:
		pool = fresh
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d" % [kind, period])
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: String = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var out := pool.slice(0, n)
	for id: String in out:
		q.progress.erase(id)
		q.claimed.erase(id)
	return out


## A quest can be drawn / counts: its prerequisite, hero and weapon are owned.
static func eligible(db: GameData, data: Dictionary, e: Dictionary) -> bool:
	for k: String in ["requires", "character", "weapon"]:
		var id: String = e.get(k, "")
		if id != "" and not Meta.is_owned(db, data, id):
			return false
	return true


## The quests on the board now: today's dailies, this week's weeklies, or
## every milestone.
static func active(db: GameData, data: Dictionary, kind: String) -> Array:
	if kind == "milestone":
		return of_kind(db, kind)
	var q := state(data)
	var ids: Array = q.daily if kind == "daily" else q.weekly
	var out := []
	for id: String in ids:
		var e := db.get_entry("quests", id)
		if not e.is_empty():
			out.append(e)
	return out


static func is_active(db: GameData, data: Dictionary, e: Dictionary) -> bool:
	if e.kind == "milestone":
		return true
	return e.id in (state(data).daily if e.kind == "daily" else state(data).weekly)


# --- Progress ----------------------------------------------------------------

## Reads the lifetime totals (only a lifetime "total" milestone does).
static func uses_totals(e: Dictionary) -> bool:
	return e.kind == "milestone" and e.scope == "total" and not e.has("danger")


static func value(data: Dictionary, e: Dictionary) -> float:
	if uses_totals(e):
		return float(data.get("stats", {}).get(Meta.stat_key(e.stat, e.get("weapon", ""), e.get("character", "")), 0.0))
	return float(state(data).progress.get(e.id, 0.0))


static func has_value(data: Dictionary, e: Dictionary) -> bool:
	if uses_totals(e):
		return true
	return state(data).progress.has(e.id)


static func is_done(data: Dictionary, e: Dictionary) -> bool:
	if not has_value(data, e):
		return false
	var v := value(data, e)
	if e.get("goal", "at_least") == "at_most":
		return v <= float(e.target)
	return v >= float(e.target)


static func frac(data: Dictionary, e: Dictionary) -> float:
	if is_done(data, e):
		return 1.0
	var v := value(data, e)
	if e.get("goal", "at_least") == "at_most":
		return clampf(float(e.target) / v, 0.0, 0.99) if has_value(data, e) and v > 0.0 else 0.0
	return clampf(v / float(e.target), 0.0, 0.99)


## "1/3", "0:45/1:00" (time stats), "10/10".
static func progress_text(data: Dictionary, e: Dictionary) -> String:
	var v := value(data, e)
	var target := float(e.target)
	if e.get("goal", "at_least") != "at_most":
		v = minf(v, target)
	return "%s/%s" % [Meta.format_stat(e.stat, v), Meta.format_stat(e.stat, target)]


static func is_claimed(data: Dictionary, id: String) -> bool:
	return state(data).claimed.has(id)


static func can_claim(db: GameData, data: Dictionary, e: Dictionary) -> bool:
	return is_active(db, data, e) and eligible(db, data, e) and not is_claimed(data, e.id) and is_done(data, e)


## Adds a finished run to the quests on the board (drawing first if a day or
## week turned during the run): daily and weekly quests, and milestones that
## keep their own value. Call it after Meta.commit_run (lifetime milestones
## read the totals that adds the run to). `run_stats` is Run.result.stats.
## Returns the ids the run completed.
static func commit_run(db: GameData, data: Dictionary, run_stats: Dictionary, character: String, danger := 1,
		t := -1) -> Array:
	roll(db, data, t)
	var q := state(data)
	var done := []
	for kind: String in KINDS:
		for e: Dictionary in active(db, data, kind):
			if is_claimed(data, e.id) or not eligible(db, data, e):
				continue
			var was := is_done(data, e)
			if uses_totals(e):
				# The totals hold this run already: done before it?
				var rv0: Variant = _run_value(e, run_stats, character, danger)
				var before := value(data, e) - (float(rv0) if rv0 != null else 0.0)
				was = before >= float(e.target)
			else:
				var rv: Variant = _run_value(e, run_stats, character, danger)
				if rv != null:
					var v: float = rv
					if e.scope == "total":
						q.progress[e.id] = float(q.progress.get(e.id, 0.0)) + v
					elif not q.progress.has(e.id):
						q.progress[e.id] = v
					elif e.get("goal", "at_least") == "at_most":
						q.progress[e.id] = minf(float(q.progress[e.id]), v)
					else:
						q.progress[e.id] = maxf(float(q.progress[e.id]), v)
			if not was and is_done(data, e):
				done.append(e.id)
	return done


## The run's value for a quest (filters applied), or null if it doesn't count.
static func _run_value(e: Dictionary, run_stats: Dictionary, character: String, danger: int) -> Variant:
	var who: String = e.get("character", "")
	if who != "" and who != character:
		return null
	if danger < int(e.get("danger", 1)):
		return null
	var key := Meta.stat_key(e.stat, e.get("weapon", ""))
	return float(run_stats[key]) if run_stats.has(key) else null


# --- Claims ------------------------------------------------------------------

## Pays a done quest's coins (and a daily's points) once. Returns the coins
## paid (0: nothing to claim).
static func claim(db: GameData, data: Dictionary, id: String, t := -1) -> int:
	if t < 0:
		t = now()
	roll(db, data, t)
	if id.begins_with(CHALLENGE):
		return _claim_challenge(db, data, id, t)
	var e := db.get_entry("quests", id)
	if e.is_empty() or not can_claim(db, data, e):
		return 0
	var q := state(data)
	q.claimed[id] = true
	var reward: Dictionary = e.reward
	if e.kind == "daily":
		q.points = int(q.get("points", 0)) + int(reward.get("points", 0))
	return _pay(data, id, int(reward.get("coins", 0)), t)


static func _pay(data: Dictionary, id: String, coins: int, t: int) -> int:
	var q := state(data)
	data.coins = int(data.coins) + coins
	q.earned = int(q.get("earned", 0)) + coins
	q.last_claim = {"id": id, "coins": coins, "day": day_of(t)}
	return coins


## The daily points chests: [{"points", "coins"}] from rules.
static func chests(db: GameData) -> Array:
	return rules(db).get("chests", [])


static func points(data: Dictionary) -> int:
	return int(state(data).get("points", 0))


static func chest_open(data: Dictionary, i: int) -> bool:
	return float(i) in state(data).chests or i in state(data).chests


static func can_open_chest(db: GameData, data: Dictionary, i: int) -> bool:
	var list := chests(db)
	return i >= 0 and i < list.size() and not chest_open(data, i) and points(data) >= int(list[i].points)


## Opens today's points chest `i` once. Returns the coins paid.
static func open_chest(db: GameData, data: Dictionary, i: int, t := -1) -> int:
	if t < 0:
		t = now()
	roll(db, data, t)
	if not can_open_chest(db, data, i):
		return 0
	state(data).chests.append(i)
	return _pay(data, "chest:%d" % i, int(chests(db)[i].coins), t)


## Unlock challenges done but whose coins aren't claimed yet.
static func challenge_ready(db: GameData, data: Dictionary, ch: Dictionary) -> bool:
	return int(ch.get("coins", 0)) > 0 and Meta.is_done(db, data, ch) and not is_claimed(data, CHALLENGE + ch.id)


static func _claim_challenge(db: GameData, data: Dictionary, id: String, t: int) -> int:
	var ch := db.get_entry("challenges", id.trim_prefix(CHALLENGE))
	if ch.is_empty() or not challenge_ready(db, data, ch):
		return 0
	state(data).claimed[id] = true
	return _pay(data, id, int(ch.coins), t)


## AD x2: today's last claim can be paid again, once a day.
static func can_double(data: Dictionary, t := -1) -> bool:
	if t < 0:
		t = now()
	var q := state(data)
	var last: Dictionary = q.last_claim
	return int(last.get("coins", 0)) > 0 and int(last.get("day", -1)) == day_of(t) \
			and int(q.get("doubled_day", -1)) != day_of(t)


## Pays today's last claim again (call only after the ad's reward callback).
## Returns the coins paid.
static func double_last(data: Dictionary, t := -1) -> int:
	if t < 0:
		t = now()
	if not can_double(data, t):
		return 0
	var q := state(data)
	var coins := int(q.last_claim.coins)
	data.coins = int(data.coins) + coins
	q.earned = int(q.get("earned", 0)) + coins
	q.doubled_day = day_of(t)
	return coins


# --- The board ---------------------------------------------------------------

## Things to claim on a tab ("daily" counts the points chests too).
static func ready_count(db: GameData, data: Dictionary, kind: String) -> int:
	var n := 0
	for e: Dictionary in active(db, data, kind):
		if can_claim(db, data, e):
			n += 1
	if kind == "daily":
		for i in chests(db).size():
			if can_open_chest(db, data, i):
				n += 1
	if kind == "milestone":
		for ch: Dictionary in db.all("challenges"):
			if challenge_ready(db, data, ch):
				n += 1
	return n


## Everything to claim (Home's Quests count dot). Draws first if due.
static func total_ready(db: GameData, data: Dictionary, t := -1) -> int:
	roll(db, data, t)
	var n := 0
	for kind: String in KINDS:
		n += ready_count(db, data, kind)
	return n


## The cards of a tab, in order: claimable, in progress, blocked, claimed.
## Each: {"id", "desc", "icon" (Icons.ref path), "coins", "frac", "text",
## "done", "claimed", "blocked" (a prerequisite isn't owned: its name)}.
## Milestones show the lowest unclaimed tier of each chain (the top tier once
## the chain is all claimed), then the unlock challenges' coins.
static func cards(db: GameData, data: Dictionary, kind: String) -> Array:
	var list := []
	if kind == "milestone":
		var heads := {}
		for e: Dictionary in of_kind(db, kind):
			var key := chain_key(e)
			if not heads.has(key):
				heads[key] = []
			heads[key].append(e)
		for key: String in heads:
			var tiers: Array = heads[key]
			tiers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _tier_lt(a, b))
			var pick: Dictionary = tiers.back()
			for e: Dictionary in tiers:
				if not is_claimed(data, e.id):
					pick = e
					break
			list.append(_card(db, data, pick))
		for ch: Dictionary in Meta.challenges(db):
			if int(ch.get("coins", 0)) > 0 and (Meta.is_done(db, data, ch)):
				list.append(_challenge_card(db, data, ch))
	else:
		for e: Dictionary in active(db, data, kind):
			list.append(_card(db, data, e))
	var order := range(list.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		var ra := _rank(list[a])
		var rb := _rank(list[b])
		return ra < rb or (ra == rb and a < b))
	return order.map(func(i: int) -> Dictionary: return list[i])


static func _rank(c: Dictionary) -> int:
	if c.claimed:
		return 3
	if c.done:
		return 0
	return 2 if c.blocked != "" else 1


## Tiers of one milestone chain share stat, filters and scope.
static func chain_key(e: Dictionary) -> String:
	return "%s|%s|%s|%s" % [e.stat, e.get("weapon", ""), e.get("character", ""), e.scope]


static func _tier_lt(a: Dictionary, b: Dictionary) -> bool:
	var da := int(a.get("danger", 1))
	var dbn := int(b.get("danger", 1))
	if da != dbn:
		return da < dbn
	if a.get("goal", "at_least") == "at_most":
		return float(a.target) > float(b.target)
	return float(a.target) < float(b.target) or (float(a.target) == float(b.target) and a.id < b.id)


static func icon_of(db: GameData, e: Dictionary) -> String:
	if e.has("icon"):
		return e.icon
	if e.get("weapon", "") != "":
		return "weapons/" + e.weapon
	if e.get("character", "") != "":
		return "characters/" + e.character
	return String(rules(db).get("icons", {}).get(e.stat, ""))


static func _card(db: GameData, data: Dictionary, e: Dictionary) -> Dictionary:
	var blocked := ""
	for k: String in ["requires", "character", "weapon"]:
		var id: String = e.get(k, "")
		if id != "" and not Meta.is_owned(db, data, id):
			blocked = String(Meta.content(db, id).get("name", id))
			break
	var claimed := is_claimed(data, e.id)
	return {"id": e.id, "desc": e.desc, "icon": icon_of(db, e), "coins": int(e.reward.get("coins", 0)),
		"frac": 1.0 if claimed else frac(data, e), "text": progress_text(data, e),
		"done": claimed or is_done(data, e), "claimed": claimed, "blocked": blocked}


static func _challenge_card(db: GameData, data: Dictionary, ch: Dictionary) -> Dictionary:
	var id: String = CHALLENGE + ch.id
	return {"id": id, "desc": String(ch.desc).trim_suffix("."), "icon": Meta.category_of(db, ch.reward) + "/" + ch.reward,
		"coins": int(ch.coins), "frac": 1.0, "text": "Unlocked", "done": true, "claimed": is_claimed(data, id),
		"blocked": ""}

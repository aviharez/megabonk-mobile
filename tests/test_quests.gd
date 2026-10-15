extends RefCounted
## Phase 12 (docs/BRIEF.md "Update 1", Quests): quests as data on the
## challenge schema (daily, weekly, milestone), dailies drawn at local
## midnight and weeklies on Monday (a fake clock), progress from runs, claims
## that pay once, the daily points chests, the once-a-day AD x2, the unlock
## challenges' coins, the Quests screen and Home's Quests rail with its
## count.

const SaveManager := preload("res://scripts/autoload/save_manager.gd")
const PATH := "user://test_quests.json"
const MENU := "res://scenes/main_menu.tscn"
const RUN_SCENE := preload("res://scenes/run.tscn")
const BAD := "user://test_quests_data"
const DAY := 86400

var db := GameData.load_from(GameData.ROOT)


func cleanup() -> void:
	Quests.clock = Quests.system_clock
	for p in [PATH, PATH + ".bak", PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	_wipe(BAD)


## Local time as Quests counts it (seconds since 1970-01-01 00:00 local).
func _at(y: int, mo: int, d: int, h := 12, mi := 0, s := 0) -> int:
	return Time.get_unix_time_from_datetime_dict({"year": y, "month": mo, "day": d, "hour": h, "minute": mi, "second": s})


func _data() -> Dictionary:
	return SaveManager.default_data()


## A run committed like Run does: the totals (Meta), then the quests.
func _run(data: Dictionary, stats: Dictionary, hero := "sir_loaf", danger := 1, t := -1) -> Array:
	Meta.commit_run(db, data, stats, hero, 0, "suburbia", 60.0, danger)
	return Quests.commit_run(db, data, stats, hero, danger, t)


## A board with these dailies today (the draw already done for `t`).
func _board(data: Dictionary, t: int, daily: Array, weekly := []) -> void:
	Quests.roll(db, data, t)
	data.quests.daily = daily
	if not weekly.is_empty():
		data.quests.weekly = weekly


# --- Data ---------------------------------------------------------------------

func test_quests_are_data(t) -> void:
	t.check(db.errors.is_empty(), "data loads (%s)" % [db.errors])
	var daily := Quests.of_kind(db, "daily")
	var weekly := Quests.of_kind(db, "weekly")
	var ms := Quests.of_kind(db, "milestone")
	t.check(daily.size() >= 15, "a pool of 15+ dailies (%d)" % daily.size())
	t.check(weekly.size() >= 15, "a pool of 15+ weeklies (%d)" % weekly.size())
	t.check(ms.size() >= 100, "100+ milestones (%d)" % ms.size())
	var r := Quests.rules(db)
	t.check(int(r.daily_count) == 3 and int(r.weekly_count) == 5, "3 dailies, 5 weeklies a draw")
	t.check(Quests.chests(db).map(func(c: Dictionary) -> int: return int(c.points)) == [20, 40, 60], "chests at 20 / 40 / 60 points")
	for e: Dictionary in daily:
		t.check(int(e.reward.get("points", 0)) == 20, "%s gives 20 points" % e.id)
	for e: Dictionary in db.all("quests"):
		t.check(e.repeat == (e.kind != "milestone"), "%s: repeat follows its kind" % e.id)
		t.check(int(e.reward.coins) > 0, "%s pays coins" % e.id)
		t.check(Quests.icon_of(db, e) != "", "%s has an icon" % e.id)
	# The brief's examples.
	for id: String in ["ms_bonk_1000", "ms_bonk_10000", "ms_bonk_100000", "ms_chests_10", "ms_chests_100"]:
		t.check(not db.get_entry("quests", id).is_empty(), "milestone %s" % id)
	for w: Dictionary in db.all("weapons"):
		var found := ms.any(func(e: Dictionary) -> bool: return e.stat == "kills" and e.get("weapon", "") == w.id and int(e.target) == 500)
		t.check(found, "500 bonks with %s" % w.id)
	for c: Dictionary in db.all("characters"):
		for d: Dictionary in Meta.dangers(db):
			var found := ms.any(func(e: Dictionary) -> bool:
				return e.stat == "boss_defeated" and e.get("character", "") == c.id and int(e.get("danger", 1)) == int(d.level))
			t.check(found, "%s beats the boss on Danger %d" % [c.id, d.level])
	# The unlock challenges stay and also pay coins.
	t.check(Meta.challenges(db).size() == 19, "19 unlock challenges")
	for ch: Dictionary in Meta.challenges(db):
		t.check(int(ch.get("coins", 0)) > 0, "%s pays coins" % ch.id)


## Quest text fits two lines of a card.
func test_quest_text_fits_a_card(t) -> void:
	var tw := MenuScreen.W - (8 + QuestsScreen.ICON_SLOT + 6) - QuestsScreen.RIGHT_W - 6
	for e: Dictionary in db.all("quests"):
		var words: PackedStringArray = String(e.desc).split(" ")
		var lines := 1
		var line := ""
		for w in words:
			var next := w if line == "" else line + " " + w
			if Fonts.width(next, "BODY") > tw:
				lines += 1
				line = w
			else:
				line = next
		t.check(lines <= 2, "%s: \"%s\" fits 2 lines of %d px" % [e.id, e.desc, tw])


func test_bad_quest_data_is_caught(t) -> void:
	var cases := [
		["quests/daily_pots_10.json", func(d: Dictionary) -> void: d.kind = "monthly", "unknown kind \"monthly\""],
		["quests/daily_pots_10.json", func(d: Dictionary) -> void: d.stat = "pots", "unknown stat \"pots\""],
		["quests/daily_pots_10.json", func(d: Dictionary) -> void: d.repeat = false, "\"repeat\" must be true for a daily quest"],
		["quests/daily_pots_10.json", func(d: Dictionary) -> void: d.reward = {"points": 20}, "\"reward\" needs whole \"coins\""],
		["quests/daily_pots_10.json", func(d: Dictionary) -> void: d.reward.gems = 3, "unknown reward \"gems\""],
		["quests/daily_pots_10.json", func(d: Dictionary) -> void: d.erase("repeat"), "missing \"repeat\""],
		["quests/weekly_pots_60.json", func(d: Dictionary) -> void: d.reward.points = 20, "only daily quests give points"],
		["quests/ms_level_10.json", func(d: Dictionary) -> void: d.scope = "total", "\"level\" is one value per run"],
		["quests/ms_bonk_100.json", func(d: Dictionary) -> void: d.repeat = true, "\"repeat\" must be false for a milestone"],
		["quests/ms_bonk_baguette_500.json", func(d: Dictionary) -> void: d.weapon = "bagel", "unknown weapon \"bagel\""],
		["quests/ms_beat_gary_d3.json", func(d: Dictionary) -> void: d.danger = 9, "no danger level 9"],
		["quests/ms_beat_gary_d3.json", func(d: Dictionary) -> void: d.character = "garry", "unknown character \"garry\""],
		["quests/ms_pots_25.json", func(d: Dictionary) -> void: d.icon = "ui/nope", "names no UI kit sprite"],
		["rules/quests.json", func(d: Dictionary) -> void: d.daily_count = 16, "can't fill a draw of 16"],
		["rules/quests.json", func(d: Dictionary) -> void: d.chests = [{"points": 40, "coins": 5}, {"points": 20, "coins": 5}], "\"points\" (rising)"],
		["challenges/pinata.json", func(d: Dictionary) -> void: d.coins = 2.5, "\"coins\" must be a whole number"],
	]
	for c: Array in cases:
		_wipe(BAD)
		_copy_tree(GameData.ROOT, BAD)
		var path := BAD.path_join(c[0])
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		c[1].call(d)
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify(d))
		f.close()
		var all := "\n".join(GameData.load_from(BAD).errors)
		t.check(all.contains(c[2]), "%s: expected an error with '%s', got:\n%s" % [c[0], c[2], all])


# --- The clock and the draws --------------------------------------------------

func test_clock_days_and_weeks(t) -> void:
	# 2026-10-12 is a Monday.
	var mon := _at(2026, 10, 12, 0, 0, 0)
	t.check(Quests.day_of(mon) == Quests.day_of(mon + DAY - 1) and Quests.day_of(mon + DAY) == Quests.day_of(mon) + 1,
		"a day runs from local midnight to midnight")
	t.check(Quests.week_of(mon - 1) == Quests.week_of(mon) - 1, "Sunday 23:59:59 is the week before Monday")
	t.check(Quests.week_of(mon) == Quests.week_of(mon + 7 * DAY - 1), "Monday to Sunday is one week")
	t.check(Quests.until_daily(_at(2026, 10, 14, 16, 48, 0)) == 7 * 3600 + 12 * 60, "Wednesday 16:48 resets in 7h 12m")
	t.check(Quests.until_weekly(_at(2026, 10, 18, 23, 59, 59)) == 1, "Sunday 23:59:59 is a second from the weekly reset")
	t.check(Quests.until_weekly(mon) == 7 * DAY, "Monday 00:00 starts a full week")
	t.check(Quests.countdown(7 * 3600 + 12 * 60) == "7h 12m" and Quests.countdown(2 * DAY + 4 * 3600) == "2d 4h"
		and Quests.countdown(30) == "1m", "countdown text")
	# The real clock is local time: its day is today's local date.
	var now := Quests.system_clock()
	t.check(Time.get_date_string_from_unix_time(now) == Time.get_date_string_from_system(false), "the system clock counts local days")


func test_dailies_roll_at_local_midnight(t) -> void:
	var clock := [_at(2026, 10, 14, 23, 59, 59)]
	Quests.clock = func() -> int: return clock[0]
	var data := _data()
	t.check(Quests.roll(db, data), "first draw")
	var first: Array = data.quests.daily.duplicate()
	t.check(first.size() == 3, "3 dailies drawn (%s)" % [first])
	t.check(first.all(func(id: String) -> bool: return db.get_entry("quests", id).kind == "daily"), "from the daily pool")
	var weekly: Array = data.quests.weekly.duplicate()
	t.check(weekly.size() == 5, "5 weeklies drawn")
	# Same day: nothing changes, progress and claims stay.
	data.quests.progress[first[0]] = 5.0
	data.quests.claimed[first[1]] = true
	data.quests.points = 20
	data.quests.chests = [0]
	clock[0] = _at(2026, 10, 14, 8, 0, 0)
	t.check(not Quests.roll(db, data) and data.quests.daily == first, "earlier the same day: same dailies")
	clock[0] = _at(2026, 10, 14, 23, 59, 59)
	t.check(not Quests.roll(db, data) and data.quests.progress.has(first[0]) and data.quests.claimed.has(first[1]),
		"a second before midnight: still today's")
	# Local midnight: new dailies, fresh progress, points and chests.
	clock[0] = _at(2026, 10, 15, 0, 0, 0)
	t.check(Quests.roll(db, data), "midnight draws again")
	var second: Array = data.quests.daily
	t.check(second.size() == 3 and not second.any(func(id: String) -> bool: return id in first), "three new dailies (%s -> %s)" % [first, second])
	t.check(not data.quests.progress.has(first[0]) and not data.quests.claimed.has(first[1]), "yesterday's progress and claims are gone")
	t.check(int(data.quests.points) == 0 and data.quests.chests.is_empty(), "points and chests start over")
	t.check(data.quests.weekly == weekly, "Thursday keeps the week's quests")
	# The draw is seeded by the day: two fresh saves get the same dailies.
	var a := _data()
	var b := _data()
	Quests.roll(db, a)
	Quests.roll(db, b)
	t.check(a.quests.daily == b.quests.daily, "a day's first draw is the same on any save")
	# Through a save file (JSON numbers come back as floats): still today's.
	var s: Node = SaveManager.new()
	s.path = PATH
	s.data = data
	s.save_game()
	s.load_game()
	t.check(not Quests.roll(db, s.data) and s.data.quests.daily == second, "reloaded save keeps today's draw")
	s.free()
	cleanup()


func test_weeklies_roll_on_monday(t) -> void:
	var data := _data()
	Quests.roll(db, data, _at(2026, 10, 14))  # Wednesday
	var w1: Array = data.quests.weekly.duplicate()
	data.quests.progress[w1[0]] = 3.0
	for day in [15, 16, 17, 18]:
		Quests.roll(db, data, _at(2026, 10, day, 12))
		t.check(data.quests.weekly == w1, "same weeklies on Oct %d" % day)
	Quests.roll(db, data, _at(2026, 10, 18, 23, 59, 59))
	t.check(data.quests.weekly == w1 and data.quests.progress.has(w1[0]), "Sunday 23:59:59: still this week's")
	Quests.roll(db, data, _at(2026, 10, 19, 0, 0, 0))
	var w2: Array = data.quests.weekly
	t.check(w2.size() == 5 and w2 != w1, "Monday 00:00: new weeklies (%s -> %s)" % [w1, w2])
	t.check(not data.quests.progress.has(w1[0]), "last week's progress is gone")
	t.check(w2.all(func(id: String) -> bool: return db.get_entry("quests", id).kind == "weekly"), "from the weekly pool")


func test_draws_only_owned_content(t) -> void:
	# A pool quest naming locked content is never drawn until it's owned.
	var data := _data()
	var e: Dictionary = db.get_entry("quests", "daily_pots_10").duplicate(true)
	e.requires = "gary"
	t.check(not Quests.eligible(db, data, e), "needs Gary: not drawn")
	data.unlocks["gary"] = "owned"
	t.check(Quests.eligible(db, data, e), "Gary hired: drawn")
	var by_weapon := {"id": "x", "requires": "", "weapon": "fireworks"}
	t.check(not Quests.eligible(db, _data(), by_weapon), "a locked weapon's quest isn't drawn")


# --- Progress -----------------------------------------------------------------

func test_runs_fill_the_board(t) -> void:
	var day := _at(2026, 10, 14)
	var data := _data()
	_board(data, day, ["daily_kills_300", "daily_level_15", "daily_runs_3"])
	var done := _run(data, {"kills": 200.0, "level": 12.0, "runs_finished": 1.0}, "sir_loaf", 1, day)
	t.check(not done.any(func(id: String) -> bool: return id.begins_with("daily_")), "no daily done after one run (%s)" % [done])
	t.check("ms_level_10" in done and "ms_runs_1" in done, "but milestones are")
	t.check(Quests.value(data, db.get_entry("quests", "daily_kills_300")) == 200.0, "kills add up (200)")
	done = _run(data, {"kills": 150.0, "level": 9.0, "runs_finished": 1.0}, "sir_loaf", 1, day)
	t.check("daily_kills_300" in done, "300 kills over two runs: done (%s)" % [done])
	t.check(Quests.value(data, db.get_entry("quests", "daily_level_15")) == 12.0, "\"run\" scope keeps the best run (12), not the sum")
	t.check(Quests.progress_text(data, db.get_entry("quests", "daily_runs_3")) == "2/3", "x/y text")
	# Lifetime milestones read the totals, from before quests existed too.
	var old := _data()
	old.stats["kills"] = 1200.0
	t.check(Quests.is_done(old, db.get_entry("quests", "ms_bonk_1000")), "1,200 old kills: Bonk 1,000 is done")
	t.check(not Quests.is_done(old, db.get_entry("quests", "ms_bonk_2500")), "but not 2,500")
	t.check(Quests.progress_text(old, db.get_entry("quests", "ms_bonk_2500")) == "1,200/2,500", "grouped digits")
	# Hero and danger filters.
	var d := _data()
	d.unlocks["gary"] = "owned"
	_run(d, {"boss_defeated": 1.0}, "sir_loaf", 1, day)
	t.check(Quests.is_done(d, db.get_entry("quests", "ms_beat_sir_loaf_d1")), "Sir Loaf beat the boss on Danger 1")
	t.check(not Quests.is_done(d, db.get_entry("quests", "ms_beat_sir_loaf_d2")), "not on Danger 2")
	t.check(not Quests.is_done(d, db.get_entry("quests", "ms_beat_gary_d1")), "and not as Gary")
	_run(d, {"boss_defeated": 1.0}, "sir_loaf", 3, day)
	t.check(Quests.is_done(d, db.get_entry("quests", "ms_beat_sir_loaf_d3")), "Danger 3 counts")
	t.check(Quests.is_done(d, db.get_entry("quests", "ms_beat_sir_loaf_d2")), "and a lower level too")
	# A run that ends after midnight counts for the new day's draw.
	var late := _data()
	_board(late, day, ["daily_kills_300"])
	_run(late, {"kills": 999.0}, "sir_loaf", 1, day + DAY)
	t.check(not "daily_kills_300" in late.quests.daily or Quests.value(late, db.get_entry("quests", "daily_kills_300")) == 999.0,
		"the draw rolls before the run is added")


func test_a_finished_run_commits_quests(t) -> void:
	var clock := [_at(2026, 10, 14, 12)]
	Quests.clock = func() -> int: return clock[0]
	var s: Node = SaveManager.new()
	s.path = PATH
	s.data = _data()
	_board(s.data, clock[0], ["daily_chests_3", "daily_runs_3", "daily_pots_10"])
	Run.next_options = {"auto_cards": true, "seed": 3, "no_spawns": true, "invincible": true, "save": s}
	var run: Run = RUN_SCENE.instantiate()
	t.root.add_child(run)
	await t.process_frame
	run.record("chests_opened", 3.0)
	run.call("_end", "died")
	t.check(int(run.result.coins) >= 0 and "daily_chests_3" in run.result.quests_done, "the run's 3 chests finish the daily (%s)" % [run.result.quests_done])
	t.check(Quests.value(s.data, db.get_entry("quests", "daily_runs_3")) == 1.0, "and count a finished run")
	var on_disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	t.check(on_disk.quests.progress.has("daily_chests_3"), "saved with the run")
	run.queue_free()
	t.paused = false
	await t.process_frame
	s.free()
	cleanup()


# --- Claims -------------------------------------------------------------------

func test_claims_pay_once(t) -> void:
	var day := _at(2026, 10, 14)
	var data := _data()
	_board(data, day, ["daily_kills_300", "daily_pots_10", "daily_runs_3"], ["weekly_pots_60", "weekly_runs_10", "weekly_kills_5000", "weekly_chests_20", "weekly_elites_15"])
	t.check(Quests.claim(db, data, "daily_kills_300", day) == 0 and int(data.coins) == 0, "not done: nothing to claim")
	_run(data, {"kills": 400.0, "pots_broken": 70.0}, "sir_loaf", 1, day)
	var pay := int(db.get_entry("quests", "daily_kills_300").reward.coins)
	t.check(Quests.claim(db, data, "daily_kills_300", day) == pay and int(data.coins) == pay, "claim pays %d" % pay)
	t.check(Quests.points(data) == 20, "and 20 points")
	t.check(Quests.claim(db, data, "daily_kills_300", day) == 0 and int(data.coins) == pay, "a second claim pays nothing")
	t.check(Quests.points(data) == 20, "nor points")
	var wpay := int(db.get_entry("quests", "weekly_pots_60").reward.coins)
	t.check(Quests.claim(db, data, "weekly_pots_60", day) == wpay, "weekly claim pays")
	t.check(Quests.claim(db, data, "weekly_pots_60", day + DAY) == 0, "once for the week, even the next day")
	t.check(Quests.claim(db, data, "daily_gems_1000", day) == 0, "a daily not on today's board can't be claimed")
	# A done daily left unclaimed is gone at midnight.
	t.check(Quests.claim(db, data, "daily_pots_10", day + DAY) == 0, "yesterday's done quest can't be claimed after midnight")
	# Milestones: once, ever.
	var m := _data()
	m.stats["kills"] = 150.0
	var mpay := int(db.get_entry("quests", "ms_bonk_100").reward.coins)
	t.check(Quests.claim(db, m, "ms_bonk_100", day) == mpay, "milestone pays")
	t.check(Quests.claim(db, m, "ms_bonk_100", day + 9 * DAY) == 0, "and never again")
	t.check(Quests.claim(db, m, "ms_bonk_500", day) == 0, "the next tier isn't done")
	# Unlock challenges pay their coins once, when done.
	var ch := db.get_entry("challenges", "alarm_clock")
	t.check(Quests.claim(db, m, "challenge:alarm_clock", day) == 0, "challenge not done: nothing")
	m.unlocks["alarm_clock"] = "available"
	t.check(Quests.claim(db, m, "challenge:alarm_clock", day) == int(ch.coins), "challenge done: its coins")
	t.check(Quests.claim(db, m, "challenge:alarm_clock", day) == 0, "once")
	t.check(int(m.quests.earned) == mpay + int(ch.coins), "quest coins are tallied")


func test_points_chests(t) -> void:
	var day := _at(2026, 10, 14)
	var data := _data()
	_board(data, day, ["daily_kills_300", "daily_pots_10", "daily_runs_3"])
	t.check(not Quests.can_open_chest(db, data, 0) and Quests.open_chest(db, data, 0, day) == 0, "no points: no chest")
	_run(data, {"kills": 400.0, "pots_broken": 10.0, "runs_finished": 3.0}, "sir_loaf", 1, day)
	Quests.claim(db, data, "daily_kills_300", day)
	var c := Quests.chests(db)
	t.check(Quests.can_open_chest(db, data, 0) and not Quests.can_open_chest(db, data, 1), "20 points: the first chest")
	var before := int(data.coins)
	t.check(Quests.open_chest(db, data, 0, day) == int(c[0].coins) and int(data.coins) == before + int(c[0].coins), "it pays")
	t.check(Quests.open_chest(db, data, 0, day) == 0, "once")
	Quests.claim(db, data, "daily_pots_10", day)
	Quests.claim(db, data, "daily_runs_3", day)
	t.check(Quests.points(data) == 60, "three dailies: 60 points")
	t.check(Quests.open_chest(db, data, 2, day) == int(c[2].coins) and Quests.open_chest(db, data, 1, day) == int(c[1].coins), "the other two open")
	t.check(Quests.ready_count(db, data, "daily") == 0, "nothing left to claim today")
	# Opened chests survive a save round trip (JSON floats) and reset at midnight.
	var s: Node = SaveManager.new()
	s.path = PATH
	s.data = data
	s.save_game()
	s.load_game()
	t.check(Quests.chest_open(s.data, 0) and Quests.open_chest(db, s.data, 0, day) == 0, "still opened after a reload")
	Quests.roll(db, s.data, day + DAY)
	t.check(not Quests.chest_open(s.data, 0) and Quests.points(s.data) == 0, "new day: chests closed, no points")
	s.free()
	cleanup()


func test_ad_doubles_one_claim_a_day(t) -> void:
	var day := _at(2026, 10, 14)
	var data := _data()
	_board(data, day, ["daily_kills_300", "daily_pots_10", "daily_runs_3"])
	t.check(not Quests.can_double(data, day), "nothing claimed: nothing to double")
	_run(data, {"kills": 400.0, "pots_broken": 10.0, "runs_finished": 3.0}, "sir_loaf", 1, day)
	var pay := Quests.claim(db, data, "daily_kills_300", day)
	t.check(Quests.can_double(data, day), "a claim can be doubled")
	var before := int(data.coins)
	t.check(Quests.double_last(data, day) == pay and int(data.coins) == before + pay, "AD x2 pays the claim again")
	Quests.claim(db, data, "daily_pots_10", day)
	t.check(not Quests.can_double(data, day) and Quests.double_last(data, day) == 0, "once a day")
	var next := day + DAY
	Quests.roll(db, data, next)
	t.check(not Quests.can_double(data, next), "yesterday's claim can't be doubled today")
	data.stats["kills"] = 150.0
	Quests.claim(db, data, "ms_bonk_100", next)
	t.check(Quests.can_double(data, next), "a new day, a new double")
	# The placement is a once-a-day rewarded ad.
	t.check(int(db.get_entry("rules", "ads").rewarded.quest_double.per_day) == 1, "quest_double: 1 per day in rules/ads.json")


func test_cards(t) -> void:
	var day := _at(2026, 10, 14)
	var data := _data()
	data.stats["kills"] = 150.0
	_board(data, day, ["daily_kills_300", "daily_pots_10", "daily_runs_3"])
	var ms := Quests.cards(db, data, "milestone")
	var ids := ms.map(func(c: Dictionary) -> String: return c.id)
	t.check(ids[0] == "ms_bonk_100" and ms[0].done and not ms[0].claimed, "a claimable milestone comes first (%s)" % ids[0])
	t.check(not "ms_bonk_500" in ids, "one tier per chain")
	var gary: Array = ms.filter(func(c: Dictionary) -> bool: return c.id == "ms_bonk_gary_1000")
	t.check(gary.size() == 1 and gary[0].blocked == "Gary the Intern", "a locked hero's milestone says who it needs")
	t.check(ids.find("ms_bonk_gary_1000") > ids.find("ms_runs_1"), "blocked ones after the ones in progress")
	Quests.claim(db, data, "ms_bonk_100", day)
	ids = Quests.cards(db, data, "milestone").map(func(c: Dictionary) -> String: return c.id)
	t.check("ms_bonk_500" in ids and not "ms_bonk_100" in ids, "claimed: the next tier shows")
	# Daily cards: claimable first, claimed last (faded).
	_run(data, {"kills": 400.0, "pots_broken": 10.0}, "sir_loaf", 1, day)
	Quests.claim(db, data, "daily_kills_300", day)
	var dc := Quests.cards(db, data, "daily")
	t.check(dc.map(func(c: Dictionary) -> String: return c.id) == ["daily_pots_10", "daily_runs_3", "daily_kills_300"],
		"claimable, in progress, claimed (%s)" % [dc.map(func(c: Dictionary) -> String: return c.id)])
	t.check(dc[2].claimed and dc[2].text == "300/300", "claimed card keeps x/y")
	# Unlock challenges show once done.
	t.check(not Quests.cards(db, data, "milestone").any(func(c: Dictionary) -> bool: return c.id == "challenge:pinata"), "not done: no card")
	data.unlocks["pinata"] = "owned"
	var pc: Array = Quests.cards(db, data, "milestone").filter(func(c: Dictionary) -> bool: return c.id == "challenge:pinata")
	t.check(pc.size() == 1 and pc[0].done and not pc[0].claimed and pc[0].icon == "items/pinata", "done: a claimable card with its icon")


# --- Screens ------------------------------------------------------------------

## The menu over the real Save autoload, pointed at a test file with `data`.
func _menu(t, data: Dictionary) -> Control:
	var save: Node = t.root.get_node("Save")
	save.set_meta("old", [save.path, save.data])
	save.path = PATH
	save.data = data
	var menu: Control = load(MENU).instantiate()
	t.root.add_child(menu)
	await t.process_frame
	return menu


func _menu_done(t, menu: Control) -> void:
	menu.queue_free()
	await t.process_frame
	var save: Node = t.root.get_node("Save")
	var old: Array = save.get_meta("old")
	save.path = old[0]
	save.data = old[1]
	save.remove_meta("old")


func _until(t, cond: Callable, sec := 3.0) -> bool:
	var end := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await t.process_frame
	return cond.call()


func test_home_rail_and_quests_screen(t) -> void:
	var clock := [_at(2026, 10, 14, 12)]
	Quests.clock = func() -> int: return clock[0]
	var data := _data()
	data.stats["kills"] = 150.0  # Bonk 100 is done
	_board(data, clock[0], ["daily_kills_300", "daily_pots_10", "daily_runs_3"])
	data.quests.progress["daily_pots_10"] = 10.0
	var menu := await _menu(t, data)
	var rail: KitButton = menu.find_child("Quests", true, false)
	t.check(rail != null and rail.visible, "Home has the Quests rail")
	var n := Quests.total_ready(db, data)
	t.check(n == 2 and rail.sticker == "count" and rail.count == n, "its count dot shows %d to claim (%s %d)" % [n, rail.sticker, rail.count])
	rail.pressed.emit()
	await t.process_frame
	var qs: QuestsScreen = menu.find_children("*", "QuestsScreen", true, false).front()
	t.check(qs != null and qs.tab == 0, "the rail opens Quests on Daily")
	var nav: BottomNav = menu.find_children("*", "BottomNav", true, false).front()
	t.check(not nav.visible, "a sub-screen: no nav")
	var card := qs.list.get_node_or_null("daily_pots_10")
	var claim: KitButton = card.find_child("Claim", true, false) if card != null else null
	t.check(claim != null, "a done quest has Claim")
	t.check(qs.list.get_node("daily_kills_300").find_child("Claim", true, false) == null, "one in progress doesn't")
	var before := int(data.coins)
	claim.pressed.emit()
	await t.process_frame
	var pay := int(db.get_entry("quests", "daily_pots_10").reward.coins)
	t.check(int(data.coins) == before + pay and Quests.is_claimed(data, "daily_pots_10"), "Claim pays %d" % pay)
	var on_disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	t.check(on_disk.quests.claimed.has("daily_pots_10"), "and saves")
	t.check(qs.list.get_node("daily_pots_10").find_child("Claim", true, false) == null, "the card turns claimed")
	# Points chest 20 is ready now.
	var chest: BaseButton = qs.find_child("Chest0", true, false)
	t.check(chest != null and chest.can_open, "the 20-point chest is ready")
	chest.pressed.emit()
	await t.process_frame
	t.check(Quests.chest_open(data, 0), "tap opens it")
	# AD x2 once an ad is ready (the fake backend in debug builds).
	var ads: Node = t.root.get_node_or_null("Ads")
	var dbl: AdButton = qs.find_child("Double", true, false)
	if ads != null and await _until(t, func() -> bool: return ads.can_offer("quest_double")):
		qs.call("_refresh_double")
		t.check(dbl.visible, "AD x2 shows once there's a claim today and an ad is ready")
		var c0 := int(data.coins)
		var last := int(data.quests.last_claim.coins)
		dbl.pressed.emit()
		await _until(t, func() -> bool: return int(data.coins) > c0)
		t.check(int(data.coins) == c0 + last, "the ad pays the last claim again (+%d)" % last)
		await _until(t, func() -> bool: return not ads.is_showing())
		t.check(not dbl.visible and not ads.can_offer("quest_double"), "then it's gone for the day")
		t.check(not t.paused, "the game resumes after the ad")
	else:
		t.check(false, "no rewarded ad became ready for quest_double")
	# Milestones tab: Bonk 100 to claim.
	qs.show_tab(2)
	await t.process_frame
	t.check(qs.list.get_child(0).name == "ms_bonk_100", "Milestones lists the claimable one first")
	# Coming from Daily (whose list fits) the longer list still scrolls: the
	# range used to stay at Daily's 0, so it wouldn't drag (owner, 2026-10-15).
	var sb := qs._scroll.get_v_scroll_bar()
	var grows := await _until(t, func() -> bool: return sb.max_value >= qs.list.size.y and qs.list.size.y > qs._scroll.size.y, 1.0)
	t.check(grows, "after Daily, the Milestones list has its scroll range (%d of %d)" % [sb.max_value, qs.list.size.y])
	qs._scroll.scroll_vertical = 40
	t.check(qs._scroll.scroll_vertical == 40, "and moves (%d)" % qs._scroll.scroll_vertical)
	qs.close()
	await t.process_frame
	t.check(rail.sticker == "count" and rail.count == Quests.total_ready(db, data), "back on Home the count follows (%d)" % rail.count)
	# Midnight while Home is up: the new board counts.
	clock[0] = _at(2026, 10, 15, 0, 0, 1)
	menu.call("_refresh_quests")
	t.check(int(data.quests.day) == Quests.day_of(clock[0]), "the new day's quests are drawn")
	await _menu_done(t, menu)
	cleanup()


# --- Helpers ------------------------------------------------------------------

func _wipe(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_wipe(dir.path_join(d))
	DirAccess.remove_absolute(dir)


func _copy_tree(src: String, dst: String) -> void:
	DirAccess.make_dir_recursive_absolute(dst)
	for f in DirAccess.get_files_at(src):
		if f.ends_with(".json"):
			DirAccess.copy_absolute(src.path_join(f), dst.path_join(f))
	for d in DirAccess.get_directories_at(src):
		_copy_tree(src.path_join(d), dst.path_join(d))

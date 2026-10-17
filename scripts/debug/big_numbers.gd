class_name BigNumbers
extends RefCounted
## The largest numbers each screen should hold (phase 14), for
## tests/test_text_fit.gd and tools/shoot_screens.gd --big: coins 9,999,999,
## run gold and KO 999,999, level 999, item stacks 99, damage 999,999, and
## the quest chains at their largest target in data.

const COINS := 9999999
const RUN := 999999
const LEVEL := 999
const STACKS := 99
const DAMAGE := 999999


## A save holding the big numbers (menus): the wallet, critters bonked,
## and every milestone chain on its top tier, one short of it.
static func fill_save(db: GameData, data: Dictionary) -> void:
	data.coins = COINS
	data.runs_played = maxi(int(data.get("runs_played", 0)), RUN)
	for id: String in data.get("bestiary", {}):
		data.bestiary[id].bonked = RUN
	var q := Quests.state(data)
	var heads := {}
	for e: Dictionary in Quests.of_kind(db, "milestone"):
		var key := Quests.chain_key(e)
		if not heads.has(key) or Quests._tier_lt(heads[key], e):
			heads[key] = e
	for e: Dictionary in Quests.of_kind(db, "milestone"):
		if heads[Quests.chain_key(e)] != e:
			q.claimed[e.id] = true
	for key: String in heads:
		var top: Dictionary = heads[key]
		if top.scope == "total" and top.get("weapon", "") == "" and top.get("character", "") == "" and float(top.target) > 1.0:
			data.stats[top.stat] = maxf(float(data.stats.get(top.stat, 0.0)), float(top.target) - 1.0)
	for id: String in q.daily + q.weekly:
		var e := db.get_entry("quests", id)
		if not q.claimed.has(id):
			q.progress[id] = maxf(0.0, float(e.target) - 1.0)


## A run holding the big numbers (HUD, pause, merchant): gold, KO, level and
## one item stacked 99 times (the pickup card shows it).
static func fill_run(run: Run) -> void:
	run.gold = RUN
	run.kills = RUN
	run.level = LEVEL
	for i in STACKS - int(run.items.stacks.get("band_aid", 0)):
		run.give_item("band_aid")
	run.show_item_card("band_aid")


## The Game Over screen with the big numbers (after Run._end).
static func fill_result(run: Run) -> void:
	run.gold = RUN
	run.kills = RUN
	run.level = LEVEL
	run.result.coins = RUN
	run.result.kills = RUN
	run.call("_sync_over_coins", false)
	run._over_coins.count_to(RUN, RUN, 0.01)  # stops a roll-up already under way
	run._over_text.text = run.call("_over_lines")
	for n in run.find_children("*", "Control", true, false):
		(n as Control).queue_redraw()


## Damage numbers of 99,999-999,999 on the enemies round the hero, a few
## crits among them.
static func hit_crowd(run: Run) -> void:
	var i := 0
	for s in run.enemies.pool.active:
		if run.enemies.pos[s].distance_to(run.player_pos()) < 90.0:
			run.numbers.show_number(run.enemies.pos[s], DAMAGE - i * 7919 % 900000, i % 5 == 0)
			i += 1
			if i >= 30:
				break

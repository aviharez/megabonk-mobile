extends RefCounted
## Phase 4 meta progression: the challenge data against the brief, the
## two-step unlock, only owned content in the pool, characters bringing their
## signature weapon, persistence through the save file, the coin shop and
## level-up actions, the Toggler, Turbo Pigeon's and Gary's passives, the
## game-over progress and the stat tracker.

const SaveManager := preload("res://scripts/autoload/save_manager.gd")
const RUN_SCENE := preload("res://scenes/run.tscn")
const PATH := "user://test_meta_save.json"
const DT := 1.0 / 30.0

var db := GameData.shared()


func cleanup() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)


func _fresh_save() -> Node:
	cleanup()
	var s: Node = SaveManager.new()
	s.path = PATH
	s.load_game()
	return s


func _blank() -> Dictionary:
	return SaveManager.default_data()


func _start(t, opts: Dictionary) -> Run:
	var o := {"auto_cards": true, "seed": 3, "no_spawns": true, "invincible": true, "no_save": true}
	o.merge(opts, true)
	Run.next_options = o
	var run: Run = RUN_SCENE.instantiate()
	t.root.add_child(run)
	return run


func _done(t, run: Run) -> void:
	run.free()
	t.paused = false


# --- Data against the brief --------------------------------------------------------

## Brief, "Unlock challenges": reward -> [tier, stat, scope, target, requires].
const BRIEF := {
	"alarm_clock": ["early", "runs_finished", "total", 3, ""],
	"fridge_magnets": ["early", "gems_collected", "total", 3000, ""],
	"pinata": ["early", "pots_broken", "run", 20, ""],
	"tin_foil_hat_theories": ["early", "shrines_activated", "total", 5, ""],
	"fireworks": ["early", "boss_defeated", "total", 1, ""],
	"turbo_pigeon": ["mid", "pigeon_cage_opened", "total", 1, ""],
	"leaf_blower": ["mid", "swarm_survived_no_damage", "total", 1, ""],
	"faulty_toaster": ["mid", "kills", "total", 1000, ""],
	"self_help_book": ["mid", "level", "run", 20, ""],
	"bubble_wrap_crafts": ["mid", "kills", "total", 2000, ""],
	"lottery_tips": ["mid", "epic_from_paid_chest", "total", 1, "golden_toilet"],  # owner, 2026-10-08: Epics are all unlocks
	"golden_toilet": ["mid", "elites_killed", "run", 10, ""],
	"gary": ["hard", "final_swarm_seconds", "run", 60, ""],
	"copy_machine_manual": ["hard", "shots", "total", 3000, "gary"],
	"static_sweater": ["hard", "kills", "total", 300, "faulty_toaster"],
	"angry_neighbor": ["hard", "boss_defeated_hp_frac", "run", 0.2, ""],
	"clone_machine": ["hard", "max_item_copies", "run", 3, ""],
	"cursed_diary": ["hard", "boss_defeated_at", "run", 240, ""],
	"microwave_meltdown": ["hard", "boss_defeated_in_final_swarm", "total", 1, ""],
}


func test_challenges_match_the_brief(t) -> void:
	var by_reward := {}
	for ch: Dictionary in db.all("challenges"):
		by_reward[ch.reward] = ch
	t.check(by_reward.size() == 19 and BRIEF.keys().all(func(k: String) -> bool: return by_reward.has(k)), "19 challenges, one per brief reward")
	for r: String in BRIEF:
		var ch: Dictionary = by_reward.get(r, {})
		var b: Array = BRIEF[r]
		var got := [ch.get("tier"), ch.get("stat"), ch.get("scope"), ch.get("target"), ch.get("requires")]
		t.check(got[0] == b[0] and got[1] == b[1] and got[2] == b[2] and is_equal_approx(float(got[3]), float(b[3])) and got[4] == b[4], "%s: %s vs brief %s" % [r, got, b])
	t.check(by_reward.faulty_toaster.get("weapon") == "hot_coffee", "Faulty Toaster: kills with Hot Coffee")
	t.check(by_reward.bubble_wrap_crafts.get("character") == "sir_loaf", "Bubble Wrap: kills as Sir Loaf")
	t.check(by_reward.copy_machine_manual.get("weapon") == "stapler" and by_reward.copy_machine_manual.get("character") == "gary", "Copy Machine: staples as Gary")
	t.check(by_reward.static_sweater.get("weapon") == "faulty_toaster", "Static Sweater: kills with Faulty Toaster")
	for r in ["angry_neighbor", "cursed_diary"]:
		t.check(by_reward[r].get("goal") == "at_most", "%s: at most the target" % r)


func test_prices_scale_by_tier_and_characters_cost_more(t) -> void:
	var avg := {}
	for tier: String in Meta.TIERS:
		var items := db.all("challenges").filter(func(c: Dictionary) -> bool: return c.tier == tier and Meta.category_of(db, c.reward) != "characters")
		avg[tier] = items.reduce(func(a: float, c: Dictionary) -> float: return a + float(c.price), 0.0) / maxf(1.0, items.size())
	t.check(avg.early < avg.mid and avg.mid < avg.hard, "early < mid < hard: %s" % avg)
	for c in ["turbo_pigeon", "gary"]:
		var ch := Meta.challenge_for(db, c)
		t.check(float(ch.price) > avg[ch.tier], "%s costs more than the %s items (%s > %s)" % [c, ch.tier, ch.price, avg[ch.tier]])


func test_texts_fit_the_pixel_font(t) -> void:
	var allowed := " !\"#%'()+,-./0123456789:<=>?ABCDEFGHIJKLMNOPQRSTUVWXYZ_"
	var bad := []
	var texts := []
	for ch: Dictionary in db.all("challenges"):
		texts.append([ch.id, ch.desc, 26])  # a 156 px ChallengeRow
	for e: Dictionary in db.all("shop"):
		texts.append([e.id, e.name, 14])
		texts.append([e.id, e.desc, 27])
	for c: Dictionary in db.all("characters"):
		texts.append([c.id, c.name, 28])
		texts.append([c.id, c.passive.name, 28])
		texts.append([c.id, c.passive.desc, 28])
	for x: Array in texts:
		var s: String = x[1]
		if s.length() > x[2]:
			bad.append("%s: '%s' longer than %d" % x)
		for ch in s:
			if not allowed.contains(ch):
				bad.append("%s: '%s' has '%s'" % [x[0], s, ch])
				break
	t.check(bad.is_empty(), "text problems: %s" % [bad])


func test_characters(t) -> void:
	var p := db.get_entry("characters", "turbo_pigeon")
	var g := db.get_entry("characters", "gary")
	t.check(p.status == "unlock" and p.signature_weapon == "sharp_feathers" and p.passive.id == "speed_damage", "Turbo Pigeon: unlock, Sharp Feathers, speed damage")
	t.check(g.status == "unlock" and g.signature_weapon == "stapler" and g.passive.id == "overtime", "Gary: unlock, Stapler, Overtime")
	t.check(db.get_entry("characters", "sir_loaf").status == "start", "Sir Loaf from the start")
	t.check(p.stats.move_speed > db.get_entry("characters", "sir_loaf").stats.move_speed, "the pigeon is the fast one")


# --- Two-step unlock and the pool ----------------------------------------------------

func test_two_step_unlock(t) -> void:
	var d := _blank()
	t.check(Meta.state(db, d, "alarm_clock") == "locked", "locked at first")
	t.check(not Meta.buy(db, d, "alarm_clock"), "can't buy while locked")
	var done := Meta.commit_run(db, d, {"runs_finished": 1.0}, "sir_loaf", 0)
	done += Meta.commit_run(db, d, {"runs_finished": 1.0}, "sir_loaf", 0)
	t.check(done.is_empty() and Meta.state(db, d, "alarm_clock") == "locked", "2 of 3 runs: still locked")
	done = Meta.commit_run(db, d, {"runs_finished": 1.0}, "sir_loaf", 10)
	t.check(done == ["alarm_clock"] and Meta.state(db, d, "alarm_clock") == "available", "third run: available")
	t.check(not ContentPool.from_save(db, d).has(db.get_entry("items", "alarm_clock")), "available is not in the pool yet")
	var price := int(db.get_entry("challenges", "alarm_clock").price)
	t.check(not Meta.buy(db, d, "alarm_clock"), "10 coins: can't afford %d" % price)
	d.coins = price + 5
	t.check(Meta.buy(db, d, "alarm_clock") and d.coins == 5 and Meta.state(db, d, "alarm_clock") == "owned", "bought: owned, coins spent")
	t.check(ContentPool.from_save(db, d).has(db.get_entry("items", "alarm_clock")), "owned: in the pool")
	t.check(not Meta.buy(db, d, "alarm_clock"), "can't buy twice")
	# A completed challenge never expires: more runs don't change it.
	Meta.commit_run(db, d, {"runs_finished": 1.0}, "sir_loaf", 0)
	t.check(Meta.state(db, d, "alarm_clock") == "owned", "still owned")


func test_only_owned_content_enters_the_pool(t) -> void:
	var d := _blank()
	for ch: Dictionary in db.all("challenges"):
		d.unlocks[ch.reward] = "available"  # every challenge done, nothing bought
	var pool := ContentPool.from_save(db, d)
	var leaked := []
	for c: String in ["weapons", "tomes", "items"]:
		for e: Dictionary in db.all(c):
			if pool.has(e) != (e.status == "start" or (e.status == "signature" and e.character == "sir_loaf")):
				leaked.append(e.id)
	t.check(leaked.is_empty(), "only start content and Sir Loaf's weapon: %s" % [leaked])
	# Many level-ups and chests with that save: nothing unowned shows up.
	var rng := RandomNumberGenerator.new()
	var rules := db.get_entry("rules", "run")
	var seen := {}
	for i in 300:
		for card: Dictionary in LevelUpCards.pick(rng, db, {"baguette": 1}, {}, rules, pool):
			seen[card.id] = card.get("def", {}).get("status", "")
		var item := Loot.roll(rng, db, ["paid", "elite", "boss"][i % 3], 0.0, {}, pool)
		if item != "":
			seen[item] = db.get_entry("items", item).status
	t.check(not seen.values().has("unlock") and not seen.has("sharp_feathers") and not seen.has("stapler"), "no unowned card or chest item in 300 rolls: %s" % [seen.keys()])
	# Character select: only owned characters.
	t.check(Meta.owned_characters(db, d).map(func(c: Dictionary) -> String: return c.id) == ["sir_loaf"], "only Sir Loaf to pick")


func test_buying_a_character_adds_his_weapon_to_the_pool(t) -> void:
	var d := _blank()
	d.unlocks.gary = "available"
	d.coins = 10000
	var stapler := db.get_entry("weapons", "stapler")
	t.check(not ContentPool.from_save(db, d).has(stapler), "Stapler not in the pool before")
	t.check(Meta.buy(db, d, "gary"), "bought Gary")
	t.check(ContentPool.from_save(db, d).has(stapler), "Stapler in the pool after")
	t.check(Meta.owned_characters(db, d).size() == 2, "Gary on the character select")
	# In a real run as Sir Loaf, the Stapler can now be offered as a new card.
	var save := _fresh_save()
	save.data.merge(d, true)
	var run := _start(t, {"save": save, "character": "sir_loaf"})
	var offered := false
	for i in 200:
		for card: Dictionary in LevelUpCards.pick(run.rng, db, run.owned_weapons, run.owned_tomes, run.rules, run.pool):
			offered = offered or card.id == "stapler"
	t.check(offered and run.weapons[0].def.id == "baguette", "Sir Loaf's run offers the Stapler")
	_done(t, run)
	save.free()


# --- Persistence ----------------------------------------------------------------

func test_progress_survives_closing_the_app(t) -> void:
	var save := _fresh_save()
	save.data.shop.reroll = 2
	save.data.unlocks.fireworks = "owned"
	var run := _start(t, {"save": save})
	for i in 25:
		var p := run.interactables.find("pot")
		run.teleport(p.pos + Vector2(80, 0))
		run.tick(DT)
		run.teleport(p.pos)
		run.tick(DT)
	run.hp = -1.0e9
	run.tick(DT)
	var coins := int(save.data.coins)
	_done(t, run)
	save.free()  # the app is gone
	var again: Node = SaveManager.new()
	again.path = PATH
	again.load_game()
	var d: Dictionary = again.data
	t.check(int(d.runs_played) == 1 and int(d.coins) == coins, "runs and coins on disk")
	t.check(Meta.state(db, d, "pinata") == "available", "a run-scope challenge stays done (Pinata)")
	t.check(float(d.challenges.get("pinata", 0.0)) >= 20.0, "best run kept (%s)" % d.challenges.get("pinata"))
	t.check(float(d.stats.get("pots_broken", 0.0)) >= 20.0 and float(d.stats.get("pots_broken@sir_loaf", 0.0)) >= 20.0, "tracker totals kept, plain and per character")
	t.check(Meta.state(db, d, "fireworks") == "owned" and Meta.shop_level(d, "reroll") == 2, "owned unlocks and shop levels kept")
	t.check(Meta.charges(db, d, "reroll") == int(db.get_entry("shop", "reroll").charges[1]), "shop level reads back as an int")
	# Buying on the menu screen writes the file too.
	d.coins = 1000
	var screen := UnlocksScreen.new(again)
	screen._buy("pinata")
	screen.free()
	again.free()
	var third: Node = SaveManager.new()
	third.path = PATH
	third.load_game()
	t.check(Meta.state(db, third.data, "pinata") == "owned", "a purchase is on disk")
	third.free()


func test_older_saves_still_load(t) -> void:
	# The phase 0-3 save: version 1 with empty meta dictionaries. Loading it
	# must keep everything and add the new keys (no breaking change).
	cleanup()
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string('{"version": 1, "coins": 321, "runs_played": 9, "settings": {"music": false}, "stats": {}, "unlocks": {}, "shop": {}, "ads": {}}')
	f.close()
	var s: Node = SaveManager.new()
	s.path = PATH
	s.load_game()
	t.check(not s.read_only and s.data.version == SaveManager.SAVE_VERSION, "loads as the current version")
	t.check(s.data.coins == 321 and s.data.runs_played == 9 and s.data.settings.music == false, "old values kept")
	t.check(s.data.challenges is Dictionary and s.data.seen is Dictionary and s.data.toggled_off is Dictionary and s.data.character == "sir_loaf", "new keys filled")
	t.check(Meta.closest(db, s.data, 3).size() == 3, "meta works on it")
	s.free()


# --- Tracker -------------------------------------------------------------------

func test_tracker_keys(t) -> void:
	var run := _start(t, {"character": "sir_loaf"})
	run.weapons.clear()
	for i in 4:
		var s := run.spawn_enemy("blob", run.player_pos() + Vector2(60, 0))
		run.hit_enemy(s, 99.0, Vector2.ZERO, "hot_coffee")
	run.fire_shot({"pos": run.player_pos(), "vel": Vector2(100, 0), "damage": 1.0, "radius": 2.0, "life": 0.1, "pierce": 0, "knockback": 0.0, "shape": "staple", "color": Palette.MIST, "source": "stapler"})
	t.check(run.run_stats.get("kills.hot_coffee", 0.0) == 4.0 and run.run_stats.get("shots.stapler", 0.0) == 1.0, "kills and shots per weapon: %s" % run.run_stats)
	_done(t, run)
	var d := _blank()
	Meta.commit_run(db, d, {"kills": 5.0, "kills.hot_coffee": 4.0, "level": 12.0, "max_item_copies": 2.0}, "gary", 0)
	Meta.commit_run(db, d, {"kills": 1.0, "level": 7.0}, "sir_loaf", 0)
	t.check(d.stats.kills == 6.0 and d.stats["kills@gary"] == 5.0 and d.stats["kills@sir_loaf"] == 1.0 and d.stats["kills.hot_coffee@gary"] == 4.0, "totals plain and per character: %s" % d.stats)
	t.check(not d.stats.has("level") and not d.stats.has("max_item_copies"), "one-per-run values are not summed")
	t.check(d.challenges.self_help_book == 12.0, "best level kept (12, not 7)")


func test_at_most_keeps_the_lowest(t) -> void:
	var d := _blank()
	var ch := db.get_entry("challenges", "cursed_diary")
	Meta.commit_run(db, d, {"boss_defeated": 1.0, "boss_defeated_at": 400.0}, "sir_loaf", 0)
	Meta.commit_run(db, d, {"boss_defeated": 1.0, "boss_defeated_at": 300.0}, "sir_loaf", 0)
	Meta.commit_run(db, d, {}, "sir_loaf", 0)  # no boss: no value
	var p := Meta.progress(db, d, ch)
	t.check(p.value == 300.0 and not p.done and is_equal_approx(p.frac, 240.0 / 300.0), "best 300 s, 80%% there: %s" % p)
	t.check(Meta.progress_text(ch, p) == "BEST 5:00 / 4:00", Meta.progress_text(ch, p))
	Meta.commit_run(db, d, {"boss_defeated": 1.0, "boss_defeated_at": 200.0}, "sir_loaf", 0)
	t.check(Meta.state(db, d, "cursed_diary") == "available", "200 s: done")


# --- Game over, menu dot ------------------------------------------------------

func test_closest_challenges_and_ready_to_buy(t) -> void:
	var d := _blank()
	d.stats.gems_collected = 2700.0  # 90%
	d.stats.shrines_activated = 1.0  # 20%
	d.challenges.pinata = 15.0  # 75%
	d.unlocks.fireworks = "available"
	var c := Meta.closest(db, d, 3).map(func(x: Dictionary) -> String: return x.challenge.id)
	t.check(c == ["fridge_magnets", "pinata", "tin_foil_hat_theories"], "closest first: %s" % [c])
	t.check(not c.has("fireworks") and not c.has("copy_machine_manual"), "not done ones, not blocked ones")
	t.check(Meta.ready_to_buy(db, d) == ["fireworks"], "ready to buy")
	t.check(Meta.has_news(db, d), "menu dot on")
	Meta.mark_seen(db, d)
	t.check(not Meta.has_news(db, d), "dot off once seen")
	var run := _start(t, {"save": _fresh_save()})
	run.meta.merge(d, true)
	run._end("died")
	var rows := run.find_children("*", "ChallengeRow", true, false)
	var texts := run._over_list.get_children().filter(func(n: Node) -> bool: return n is Label).map(func(l: Label) -> String: return l.text)
	t.check(rows.size() == 3, "game over shows 3 closest (%d)" % rows.size())
	t.check(texts.has("READY TO BUY") and texts.any(func(s: String) -> bool: return s.contains("FIREWORKS")), "and what's ready to buy: %s" % [texts])
	var save: Node = run._save
	_done(t, run)
	save.free()


# --- Coin shop and level-up actions ---------------------------------------------------

func test_shop_rules(t) -> void:
	var d := _blank()
	d.coins = 10000
	t.check(Meta.charges(db, d, "reroll") == 0 and Meta.charges(db, d, "skip") == 0, "no charges before buying")
	t.check(Meta.buy_shop(db, d, "reroll") and Meta.charges(db, d, "reroll") == int(db.get_entry("shop", "reroll").charges[0]), "Reroll from the start")
	t.check(Meta.buy_shop(db, d, "reroll") and Meta.charges(db, d, "reroll") > int(db.get_entry("shop", "reroll").charges[0]), "upgrades add charges")
	t.check(Meta.buy_shop(db, d, "skip"), "Skip from the start")
	t.check(not Meta.buy_shop(db, d, "banish"), "Banish needs a few runs")
	d.runs_played = int(db.get_entry("shop", "banish").needs.runs)
	t.check(Meta.buy_shop(db, d, "banish"), "Banish after %d runs" % d.runs_played)
	t.check(not Meta.buy_shop(db, d, "toggler"), "Toggler needs 12 unlocks")
	var ids := Meta.challenges(db).map(func(c: Dictionary) -> String: return c.reward)
	for i in 11:
		d.unlocks[ids[i]] = "owned"
	t.check(not Meta.buy_shop(db, d, "toggler"), "not after 11")
	d.unlocks[ids[11]] = "owned"
	t.check(Meta.buy_shop(db, d, "toggler") and Meta.toggler_slots(db, d) > 0, "Toggler after 12 unlocks")
	var top: int = db.get_entry("shop", "might").prices.size()
	for i in top:
		Meta.buy_shop(db, d, "might")
	t.check(Meta.shop_level(d, "might") == top and Meta.shop_price(d, db.get_entry("shop", "might")) == -1 and not Meta.buy_shop(db, d, "might"), "maxed at %d" % top)
	var poor := _blank()
	t.check(not Meta.buy_shop(db, poor, "reroll") and poor.coins == 0, "no coins, no sale")
	# Permanent stat upgrades are small.
	var run := _start(t, {"save": _fresh_save()})
	var base := run.stat("damage")
	var save: Node = run._save
	_done(t, run)
	save.data.shop.might = top
	run = _start(t, {"save": save})
	var maxed := run.stat("damage")
	t.check(maxed > base and maxed <= base * 1.2, "max Might is a small bonus (%s -> %s)" % [base, maxed])
	_done(t, run)
	save.free()


func _level_up_run(t, charges: Dictionary) -> Run:
	var run := _start(t, {"auto_cards": false, "charges": charges, "seed": 11})
	run.add_xp(Run.xp_needed(run.rules.xp_curve, 1))
	run.tick(DT)
	return run


func test_reroll(t) -> void:
	var run := _level_up_run(t, {"reroll": 2})
	t.check(run.state == "level_up", "level-up open")
	var before := run._cards.map(func(c: Dictionary) -> String: return c.id)
	var changed := false
	for i in 2:
		t.check(run.reroll_cards(), "reroll %d" % (i + 1))
		changed = changed or run._cards.map(func(c: Dictionary) -> String: return c.id) != before
	t.check(changed and run.charges.reroll == 0, "new cards, charges used")
	t.check(not run.reroll_cards(), "no charges left")
	var ab: ActionButton = run._action_buttons.reroll
	t.check(ab.ad and ab.disabled, "out of charges: ad icon, disabled until ads (phase 5)")
	_done(t, run)


func test_skip(t) -> void:
	var run := _level_up_run(t, {"skip": 1})
	var gold := run.gold
	var lvl_weapons := run.owned_weapons.duplicate()
	t.check(run.skip_level(), "skipped")
	t.check(run.state == "live" and run.gold > gold and run.owned_weapons == lvl_weapons and run.owned_tomes.is_empty(), "back to play, gold given, nothing taken")
	t.check(not run.get_tree().paused, "unpaused")
	_done(t, run)


func test_banish(t) -> void:
	var run := _level_up_run(t, {"banish": 1})
	var i := -1
	for k in run._cards.size():
		if run._cards[k].is_new and run._cards[k].kind in ["weapon", "tome"]:
			i = k
			break
	t.check(i >= 0, "a new card to banish")
	var gone: String = run._cards[i].id
	t.check(run.banish_card(i) and run.charges.banish == 0, "banished, charge used")
	t.check(run._cards.size() == 3 and not run._cards.any(func(c: Dictionary) -> bool: return c.id == gone), "replaced with another card")
	var seen := false
	for n in 300:
		for c: Dictionary in LevelUpCards.pick(run.rng, db, run.owned_weapons, run.owned_tomes, run.rules, run.pool):
			seen = seen or c.id == gone
	t.check(not seen, "%s never offered again this run" % gone)
	# Upgrades can't be banished.
	var up := {"kind": "weapon", "id": "baguette", "is_new": false, "level": 2, "def": db.get_entry("weapons", "baguette")}
	t.check(not run._can_banish(up), "upgrade cards can't be banished")
	_done(t, run)


func test_actions_come_from_the_shop(t) -> void:
	var save := _fresh_save()
	save.data.shop.reroll = 1
	save.data.shop.skip = 2
	var run := _start(t, {"save": save})
	t.check(run.charges.reroll == int(db.get_entry("shop", "reroll").charges[0]) and run.charges.skip == int(db.get_entry("shop", "skip").charges[1]) and run.charges.banish == 0, "charges per run from shop levels: %s" % run.charges)
	_done(t, run)
	save.free()


# --- Toggler -------------------------------------------------------------------

func test_toggler(t) -> void:
	var d := _blank()
	t.check(not Meta.toggle(db, d, "rubber_duck"), "no Toggler, no toggling")
	d.shop.toggler = 1
	var slots := Meta.toggler_slots(db, d)
	t.check(slots > 0, "%d slots" % slots)
	t.check(not Meta.toggle(db, d, "fireworks"), "can't toggle content you don't own")
	var ids := ["rubber_duck", "eye_exercises", "protein_bar", "hot_sauce", "band_aid", "lucky_penny", "magnet_keychain", "energy_drink", "rubber_boots"]
	var off := 0
	for id: String in ids:
		if Meta.toggle(db, d, id):
			off += 1
	t.check(off == slots and d.toggled_off.size() == slots, "at most %d off" % slots)
	t.check(Meta.toggle(db, d, "rubber_duck") and not d.toggled_off.has("rubber_duck"), "back on")
	Meta.toggle(db, d, "rubber_duck")
	var pool := ContentPool.from_save(db, d)
	t.check(not pool.has(db.get_entry("weapons", "rubber_duck")) and not pool.has(db.get_entry("tomes", "eye_exercises")), "off content not in the pool")
	var rng := RandomNumberGenerator.new()
	var got := {}
	for i in 300:
		got[Loot.roll(rng, db, "paid", 0.0, {}, pool)] = true
	t.check(not got.has("protein_bar"), "off items never drop")


# --- Passives ------------------------------------------------------------------

func test_turbo_pigeon_damage_scales_with_speed(t) -> void:
	var run := _start(t, {"character": "turbo_pigeon"})
	var p: Dictionary = run.char_def.passive
	var d0 := run.stat("damage")
	var want := 1.0 + (run.stat("move_speed") - float(p.from_speed)) * float(p.damage_per_speed)
	t.check(is_equal_approx(d0, want), "damage %s from speed %s (want %s)" % [d0, run.stat("move_speed"), want])
	t.check(run.weapons[0].def.id == "sharp_feathers", "starts with Sharp Feathers")
	run.apply_card({"kind": "tome", "id": "cardio_is_life", "level": 3, "is_new": true, "def": db.get_entry("tomes", "cardio_is_life")})
	run.tick(DT)
	t.check(run.stat("damage") > d0, "faster -> more damage (%s -> %s)" % [d0, run.stat("damage")])
	_done(t, run)


func test_gary_overtime(t) -> void:
	var run := _start(t, {"character": "gary", "start_at": 290.0})
	var p: Dictionary = run.char_def.passive
	var before := {"damage": run.stat("damage"), "max_hp": run.stat("max_hp"), "move_speed": run.stat("move_speed"), "cooldown": run.stat("cooldown")}
	t.check(run.weapons[0].def.id == "stapler", "starts with the Stapler")
	for i in int(5.0 / DT):
		run.tick(DT)
	t.check(run.stat("damage") == before.damage, "no change before minute 5")
	for i in int(6.0 / DT):
		run.tick(DT)
	t.check(run.stat("damage") > before.damage and run.stat("max_hp") > before.max_hp and run.stat("move_speed") > before.move_speed and run.stat("cooldown") < before.cooldown, "all stats rise after 5:00")
	var one := run.stat("damage")
	run.elapsed = 60.0 * 30.0
	run.tick(DT)
	var capped := run.stat("damage")
	var per_step := 0.0
	for m: Dictionary in p.modifiers_per_step:
		if m.stat == "damage":
			per_step += float(m.get("pct", 0.0))
	t.check(capped > one and is_equal_approx(capped, before.damage * (1.0 + float(p.max_steps) * per_step)), "keeps rising, capped at %d steps (%s)" % [p.max_steps, capped])
	_done(t, run)

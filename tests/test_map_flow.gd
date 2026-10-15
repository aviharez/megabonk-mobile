extends RefCounted
## Phase 3 in a real run: the map and its solid props, enemy roles, elites
## and their traits, every map object, the altar and Mega Mole, the portal,
## the shared damage path, SWARM INCOMING, and the Final Swarm ending
## through Overdue Bills.

const RUN_SCENE := preload("res://scenes/run.tscn")
const DT := 1.0 / 30.0


## A run where the player stands still (no bot) and nothing spawns unless asked.
func _start(t, opts := {}) -> Run:
	var o := {"auto_cards": true, "no_save": true, "seed": 7, "no_spawns": true, "invincible": true}
	o.merge(opts, true)
	Run.next_options = o
	var run: Run = RUN_SCENE.instantiate()
	t.root.add_child(run)
	return run


func _step(run: Run, seconds: float, dt := DT) -> void:
	for i in int(seconds / dt):
		run.tick(dt)
		if run.state != "live":
			return


func _done(t, run: Run) -> void:
	run.free()
	t.paused = false


func _spawn(run: Run, id: String, at: Vector2, speed := 1.0) -> int:
	return run.enemies.spawn(run.enemies.type_index[id], at, 1.0, 1.0, speed, true)


## Steps onto a map object (from outside its circle, so it counts as a touch).
func _touch(run: Run, o: Dictionary) -> void:
	run.teleport(o.pos + Vector2(80, 0))
	run.tick(DT)
	run.teleport(o.pos)
	run.tick(DT)


func test_map_objects_are_placed_on_free_ground(t) -> void:
	var run := _start(t)
	var map_def: Dictionary = run.map_def
	for entry: Dictionary in map_def.interactables:
		t.check(run.interactables.count_of(entry.id) == int(entry.count), "%d %s placed (%d)" % [entry.count, entry.id, run.interactables.count_of(entry.id)])
	var bad := 0
	for o in run.interactables.list:
		if run.map.is_blocked_circle(o.pos, 3.0) or not run.bounds.has_point(o.pos):
			bad += 1
	t.check(bad == 0, "%d objects on solid ground or off the map" % bad)
	var altar := run.interactables.find("boss_altar")
	t.check(altar.pos.distance_to(run.player_pos()) >= 220.0, "the altar is away from the start")
	t.check(not run.map.is_blocked_circle(run.player_pos(), run.player_radius()), "the start is clear")
	_done(t, run)


func test_houses_block_walkers_not_ghosts(t) -> void:
	var run := _start(t)
	run.weapons.clear()
	# A house from the map with open ground above and below it: the Blob
	# starts above, the player waits below.
	var house := Rect2()
	var above := Vector2.ZERO
	var below := Vector2.ZERO
	for p: Dictionary in run.map_def.props:
		if p.kind != "house":
			continue
		var r := MapLayout.rect_of(p)
		var a := Vector2(r.get_center().x, r.position.y - 12)
		var b := Vector2(r.get_center().x, r.end.y + 14)
		if run.map.is_area_free(a, 6.0) and run.map.is_area_free(b, 6.0):
			house = r
			above = a
			below = b
			break
	t.check(house.size.x > 0.0, "found a house with open ground on both sides")
	var blob := _spawn(run, "blob", above)
	var bill := _spawn(run, "overdue_bill", above)
	var blob_inside := false
	var bill_crossed := false
	for i in int(4.0 / DT):
		run.teleport(below)
		run.tick(DT)
		blob_inside = blob_inside or house.grow(-2.0).has_point(run.enemies.pos[blob])
		bill_crossed = bill_crossed or house.grow(-2.0).has_point(run.enemies.pos[bill])
	t.check(not blob_inside, "the Blob never walks into the house")
	t.check(bill_crossed, "the Overdue Bill passes through it")
	# The player can't walk in either.
	var p := run.map.move(below, Vector2(0, -30), run.player_radius())
	t.check(p.y - run.player_radius() >= house.end.y - 1.0, "the player stops at the wall (y %s, wall %s)" % [p.y, house.end.y])
	_done(t, run)


func test_plants_never_block(t) -> void:
	# Trees and hedges are walk-through: a map of nothing but plants has no
	# solid cell, and the player walks straight across a hedge.
	var hedge := {"kind": "hedge", "rect": [40, 40, 48, 8]}
	var ml := MapLayout.new()
	ml.setup({"size": [160, 160], "props": [hedge, {"kind": "tree", "rect": [100, 90, 20, 24]},
		{"kind": "bush", "rect": [20, 100, 12, 10]}, {"kind": "planter", "rect": [60, 120, 16, 8]}]})
	t.check(ml.blocked.count(1) == 0, "no plant cell blocks (%d blocked)" % ml.blocked.count(1))
	var p := Vector2(64, 60)
	for i in 30:
		p = ml.move(p, Vector2(0, -1), 4.0)
	t.check(p.is_equal_approx(Vector2(64, 30)), "the player walks through the hedge (%s)" % p)
	ml.free()


func test_enemy_roles(t) -> void:
	var run := _start(t)
	run.weapons.clear()
	var me := run.player_pos()
	var spitter := _spawn(run, "spitter", me + Vector2(30, 0))
	var chomper := _spawn(run, "chomper", me + Vector2(-70, 0))
	var bloater := _spawn(run, "bloater", me + Vector2(0, 14))
	var fastest := 0.0
	var shots := 0
	for i in int(4.0 / DT):
		var before := run.enemies.pos[chomper] if run.enemies.pool.is_alive(chomper) else Vector2.ZERO
		run.tick(DT)
		if run.enemies.pool.is_alive(chomper):
			fastest = maxf(fastest, run.enemies.pos[chomper].distance_to(before) / DT)
		shots = maxi(shots, run.enemy_shots.count())
	var d := run.enemies.pos[spitter].distance_to(run.player_pos())
	t.check(d >= 50.0, "the Spitter backs off to its distance (%d px)" % d)
	t.check(shots > 0, "the Spitter shoots")
	t.check(fastest > 100.0, "the Chomper charges (%d px/s, walks at %d)" % [fastest, run.enemies.types[run.enemies.type_of[chomper]].speed])
	t.check(not run.enemies.pool.is_alive(bloater) and run.kills == 0, "the Bloater exploded by itself (no kill)")
	_done(t, run)


func test_elite_traits(t) -> void:
	var run := _start(t)
	run.weapons.clear()
	var e := run.enemies
	var rules: Dictionary = run.elite_rules
	var at := run.player_pos() + Vector2(100, 0)
	for tr: String in ["fast", "shielded", "splitting", "vicious"]:
		var s := _spawn(run, "skitter", at, 0.0)
		var base_hp := e.hp[s]
		var base_dmg := e.damage[s]
		var base_r := e.radius[s]
		e.make_elite(s, tr, rules)
		var td: Dictionary = rules.traits[tr]
		t.check(is_equal_approx(e.hp[s], base_hp * rules.hp_mult), "%s: HP x%d" % [tr, rules.hp_mult])
		t.check(e.radius[s] == base_r * rules.scale and e.outline[s] == Palette.index_of(td.color), "%s: bigger, with an outline" % tr)
		t.check(is_equal_approx(e.damage[s], base_dmg * rules.damage_mult * td.get("damage_mult", 1.0)), "%s: damage" % tr)
		t.check(e.elites.has(s), "%s: listed for arrows" % tr)
		e.remove(s)
	# Fast moves faster.
	var a := _spawn(run, "skitter", at)
	var b := _spawn(run, "skitter", at + Vector2(0, 30))
	e.make_elite(b, "fast", rules)
	t.check(is_equal_approx(e.speed[b], e.speed[a] * rules.traits.fast.speed_mult) and e.speed[b] > e.speed[a], "Fast is faster (x%s)" % rules.traits.fast.speed_mult)
	e.remove(a)
	e.remove(b)
	# Shielded: the shield takes hits first.
	var sh := _spawn(run, "skitter", at)
	e.make_elite(sh, "shielded", rules)
	var hp0 := e.hp[sh]
	run.hit_enemy(sh, 5.0, Vector2.ZERO, "test", false)
	t.check(e.hp[sh] == hp0 and e.shield[sh] > 0.0, "Shielded: HP untouched while the shield holds")
	e.remove(sh)
	# Splitting: becomes three on death; drops an elite chest; on_kill says elite.
	var kills := []
	run.on_kill.connect(func(_s: int, id: String, _src: String, elite: bool) -> void: kills.append([id, elite]))
	run.give_item("golden_toilet")
	var sp := _spawn(run, "skitter", at)
	e.make_elite(sp, "splitting", rules)
	var chests := run.interactables.count_of("elite_chest")
	run.hit_enemy(sp, 1.0e6, Vector2.ZERO, "test")
	var skitters := 0
	for s in e.pool.active:
		if e.types[e.type_of[s]].id == "skitter":
			skitters += 1
	t.check(skitters == 3, "Splitting became 3 (%d)" % skitters)
	t.check(run.interactables.count_of("elite_chest") == chests + 1, "an elite chest dropped")
	t.check(kills.size() == 1 and kills[0][1], "on_kill reports the elite")
	t.check(run.items.fired.get("golden_toilet", 0) == 1, "Golden Toilet triggered on the elite kill")
	t.check(run.run_stats.get("elites_killed", 0.0) == 1.0, "elite kill recorded")
	# Opening the elite chest goes through open_chest("elite").
	var opened := []
	run.on_chest_opened.connect(func(kind: String, _id: String) -> void: opened.append(kind))
	_touch(run, run.interactables.find("elite_chest"))
	t.check(opened == ["elite"], "the elite chest opens as an elite chest (%s)" % [opened])
	_done(t, run)


func test_elites_spawn_during_a_run(t) -> void:
	var run := _start(t, {"no_spawns": false, "start_at": 55.0})
	_step(run, 8.0)
	var seen: int = run.enemies.elites.size() + int(run.run_stats.get("elites_killed", 0.0))
	t.check(run.director.elites_spawned == 1 and seen == 1, "an elite at 1:00 (spawned %d, seen %d)" % [run.director.elites_spawned, seen])
	_done(t, run)


func test_key_opens_the_pigeon_cage(t) -> void:
	var run := _start(t)
	run.weapons.clear()
	var events := []
	run.stat_event.connect(func(n: String, _a: float) -> void: events.append(n))
	var cage := run.interactables.find("pigeon_cage")
	_touch(run, cage)
	t.check(not cage.used, "no key, no entry")
	var n := 0
	while run.interactables.count_of("cage_key") == 0 and n < 10:
		var s := _spawn(run, "blob", run.player_pos() + Vector2(100, 0), 0.0)
		run.enemies.make_elite(s, "vicious", run.elite_rules)
		run.hit_enemy(s, 1.0e6, Vector2.ZERO, "test")
		n += 1
	t.check(n >= 1 and n <= int(run.elite_rules.key.pity), "an elite drops the key within %d elites (%d)" % [run.elite_rules.key.pity, n])
	_touch(run, run.interactables.find("cage_key"))
	t.check(run.interactables.has_key, "picked up the key")
	_touch(run, cage)
	t.check(cage.used and not run.interactables.has_key, "the cage opens with the key")
	t.check(events.has("pigeon_cage_opened") and run.run_stats.get("pigeon_cage_opened", 0.0) == 1.0, "recorded as a stat event")
	# No second key while the cage is open.
	var s2 := _spawn(run, "blob", run.player_pos() + Vector2(100, 0), 0.0)
	run.enemies.make_elite(s2, "vicious", run.elite_rules)
	for i in 5:
		run.hit_enemy(s2, 1.0e6, Vector2.ZERO, "test")
	t.check(run.interactables.count_of("cage_key") == 0, "no more keys after the cage is open")
	_done(t, run)


func test_paid_chest_costs_gold_and_gets_dearer(t) -> void:
	var run := _start(t)
	var opened := []
	run.on_chest_opened.connect(func(kind: String, _id: String) -> void: opened.append(kind))
	var chests := run.interactables.count_of("paid_chest")
	var c := run.interactables.find("paid_chest")
	var price := run.interactables.paid_price(c.def)
	run.gold = price - 1.0
	_touch(run, c)
	t.check(run.interactables.count_of("paid_chest") == chests and opened.is_empty(), "too little gold: stays shut")
	run.gold = 100.0
	_touch(run, c)
	t.check(run.interactables.count_of("paid_chest") == chests - 1 and opened == ["paid"], "opens as a paid chest")
	t.check(run.gold == 100.0 - price, "spent %d gold (left %s)" % [price, run.gold])
	t.check(run.interactables.paid_price(c.def) > price, "the next one costs more (%d)" % run.interactables.paid_price(c.def))
	_done(t, run)


func test_pot_drops_gold(t) -> void:
	var run := _start(t)
	var pots := run.interactables.count_of("pot")
	_touch(run, run.interactables.find("pot"))
	t.check(run.gold > 0.0 and run.interactables.count_of("pot") == pots - 1, "a pot broke for %s gold" % run.gold)
	t.check(run.run_stats.get("pots_broken", 0.0) == 1.0, "recorded")
	_done(t, run)


func test_charge_shrine_gives_a_stat(t) -> void:
	var run := _start(t)
	var s := run.interactables.find("charge_shrine")
	var before := {}
	for c: Dictionary in s.def.choices:
		before[c.stat] = run.stat(c.stat)
	var fired := []
	run.on_shrine_activated.connect(func(id: String) -> void: fired.append(id))
	run.teleport(s.pos)
	_step(run, 1.0)
	t.check(fired.is_empty(), "not yet after 1 s")
	_step(run, float(s.def.charge_time))
	var changed := 0
	for k: String in before:
		if not is_equal_approx(before[k], run.stat(k)):
			changed += 1
	t.check(fired == ["charge_shrine"] and changed == 1, "one stat bonus after standing in it (%s, %d changed)" % [fired, changed])
	t.check(run.run_stats.get("shrines_activated", 0.0) == 1.0, "recorded")
	_done(t, run)


func test_risk_shrine_raises_risk_then_rewards(t) -> void:
	var run := _start(t)
	var s := run.interactables.find("risk_shrine")
	var chests := run.interactables.count_of("elite_chest")
	run.teleport(s.pos)
	_step(run, float(s.def.charge_time) + 0.2)
	t.check(run.stat("enemy_hp") > 1.0 and run.stat("xp_gain") > 1.0, "foes tougher, rewards bigger")
	_step(run, float(s.def.duration) + 0.5)
	t.check(is_equal_approx(run.stat("enemy_hp"), 1.0) and is_equal_approx(run.stat("xp_gain"), 1.0), "back to normal")
	t.check(run.interactables.count_of("elite_chest") == chests + 1, "a reward chest")
	_done(t, run)


func test_challenge_shrine(t) -> void:
	var run := _start(t)
	run.weapons.clear()
	var s := run.interactables.find("challenge_shrine")
	run.teleport(s.pos)
	_step(run, float(s.def.charge_time) + 0.2)
	t.check(not run.interactables.challenge_status().is_empty(), "the challenge runs")
	for i in int(s.def.kills):
		var b := _spawn(run, "blob", run.player_pos() + Vector2(100, 0), 0.0)
		run.hit_enemy(b, 1.0, Vector2.ZERO, "test")
	var chests := run.interactables.count_of("elite_chest")
	run.tick(DT)
	t.check(run.interactables.challenge_status().is_empty() and run.interactables.count_of("elite_chest") == chests + 1, "won: a reward chest")
	t.check(run.run_stats.get("challenges_won", 0.0) == 1.0, "recorded")
	_done(t, run)


func test_merchant_sells_items_for_gold(t) -> void:
	var first: float = GameData.shared().get_entry("maps", "suburbia").merchant.first_sec
	var run := _start(t, {"start_at": first - 1.0, "all_content": true})
	_step(run, 1.5)
	var m := run.interactables.find("merchant")
	t.check(not m.is_empty(), "the merchant shows up at %d s" % first)
	if m.is_empty():
		_done(t, run)
		return
	run.gold = 1000.0
	var held: int = run.items.stacks.size()
	_touch(run, m)
	t.check(run.items.stacks.size() > held and run.gold < 1000.0, "bought items with gold (%d gold left)" % run.gold)
	t.check(run.run_stats.get("items_bought", 0.0) >= 1.0, "recorded")
	_step(run, float(m.def.stay_sec) + 1.0)
	t.check(run.interactables.count_of("merchant") == 0, "the merchant leaves")
	_done(t, run)


func test_boss_summon_patterns_defeat_and_portal(t) -> void:
	var run := _start(t, {"invincible": true})
	run.weapons.clear()
	var altar := run.interactables.find("boss_altar")
	run.teleport(altar.pos)
	_step(run, 1.0)
	t.check(run.boss == null, "not after 1 s on the altar")
	_step(run, float(altar.def.charge_time))
	t.check(run.boss != null and run.boss.alive() and run.boss_summoned, "standing on the altar summons Mega Mole")
	if run.boss == null:
		_done(t, run)
		return
	var hidden := false
	var rocks := 0
	var blobs := 0
	for i in int(16.0 / DT):
		run.tick(DT)
		hidden = hidden or run.enemies.is_hidden(run.boss.slot)
		rocks = maxi(rocks, run.enemy_shots.count())
		var n := 0
		for s in run.enemies.pool.active:
			if run.enemies.types[run.enemies.type_of[s]].id == "blob":
				n += 1
		blobs = maxi(blobs, n)
	t.check(hidden, "it burrows")
	t.check(rocks >= 10, "it throws a ring of rocks (%d)" % rocks)
	t.check(blobs >= 4, "it summons Blobs (%d)" % blobs)
	# Rage below half HP.
	var slot := run.boss.slot
	run.enemies.set_hidden(slot, false)
	run.enemies.hp[slot] = run.enemies.max_hp[slot] * 0.45
	run.tick(DT)
	t.check(run.boss.rage, "below 50%% HP it speeds up")
	# Defeat: boss chest + portal.
	var opened := []
	run.on_chest_opened.connect(func(kind: String, _id: String) -> void: opened.append(kind))
	run.enemies.set_hidden(slot, false)
	run.hit_enemy(slot, 1.0e9, Vector2.ZERO, "test")
	t.check(run.boss_defeated and run.run_stats.get("boss_defeated", 0.0) == 1.0, "defeated and recorded")
	t.check(run.interactables.count_of("boss_chest") == 1 and run.interactables.count_of("portal") == 1, "boss chest and portal appear")
	_touch(run, run.interactables.find("boss_chest"))
	t.check(opened == ["boss"], "the boss chest opens as a boss chest (%s)" % [opened])
	var ended := []
	run.run_ended.connect(func(r: Dictionary) -> void: ended.append(r))
	_touch(run, run.interactables.find("portal"))
	t.check(run.state == "over" and ended.size() == 1 and ended[0].reason == "portal" and ended[0].won and ended[0].escaped, "the portal ends the run as an escape")
	_done(t, run)


func test_every_damage_source_goes_through_on_damaged(t) -> void:
	var run := _start(t, {"invincible": false})
	run.weapons.clear()
	run.stats.set_modifier("max_hp", "test", 100000.0)
	run.hp = run.stat("max_hp")
	run.give_item("whoopee_cushion")
	var sources := {}
	run.on_damaged.connect(func(_a: float) -> void: sources[run.last_damage_source] = sources.get(run.last_damage_source, 0) + 1)
	var me := run.player_pos()
	# Contact.
	var b := _spawn(run, "blob", me)
	run.tick(DT)
	run.enemies.remove(b)
	_step(run, 0.6)
	# Spitter shot (from range, so not contact).
	var sp := _spawn(run, "spitter", me + Vector2(70, 0))
	for i in int(6.0 / DT):
		run.tick(DT)
		if sources.has("spitter"):
			break
	run.enemies.remove(sp)
	run.enemy_shots.clear()
	_step(run, 0.6)
	# Bloater explosion.
	var bl := _spawn(run, "bloater", me + Vector2(0, 12), 0.0)
	_step(run, 1.6)
	if run.enemies.pool.is_alive(bl):
		run.enemies.remove(bl)
	_step(run, 0.6)
	# Mega Mole (burrow pop-up or rocks).
	run.summon_boss("mega_mole", me + Vector2(0, 30))
	for i in int(20.0 / DT):
		run.tick(DT)
		if sources.has("mega_mole"):
			break
	run.enemies.remove(run.boss.slot)
	run.boss = null
	run.enemy_shots.clear()
	for s in run.enemies.pool.active.duplicate():
		run.enemies.remove(s)
	_step(run, 0.6)
	# Overdue Bill.
	_spawn(run, "overdue_bill", me)
	_step(run, 0.2)
	for src in ["blob", "spitter", "bloater", "mega_mole", "overdue_bill"]:
		t.check(sources.has(src), "%s damage fires on_damaged (%s)" % [src, sources])
	var total := 0
	for k: String in sources:
		total += sources[k]
	t.check(run.items.fired.get("whoopee_cushion", 0) == total, "Whoopee Cushion fired on every hit (%d of %d)" % [run.items.fired.get("whoopee_cushion", 0), total])
	_done(t, run)


func test_bills_ignore_armor_and_shield(t) -> void:
	var run := _start(t, {"invincible": false})
	run.weapons.clear()
	run.stats.set_modifier("armor", "test", 10000.0)
	run.stats.set_modifier("shield", "test", 10000.0)
	run.shield = run.stat("shield")
	var hp0 := run.hp
	var b := _spawn(run, "blob", run.player_pos())
	run.tick(DT)
	t.check(run.hp == hp0, "armor and shield stop a Blob")
	run.enemies.remove(b)
	_step(run, 0.6)
	_spawn(run, "overdue_bill", run.player_pos())
	run.tick(DT)
	t.check(run.hp < hp0, "but not an Overdue Bill (%s -> %s)" % [hp0, run.hp])
	_done(t, run)


func test_final_swarm_always_ends_through_bills(t) -> void:
	# A build regular enemies can't really hurt (huge armor, regen) still dies
	# to Overdue Bills: the Final Swarm always ends.
	for seed in [1, 2]:
		var run := _start(t, {"invincible": false, "no_spawns": false, "seed": seed, "start_at": 470.0})
		run.stats.set_modifier("armor", "test", 10000.0)
		run.stats.set_modifier("regen", "test", 30.0)
		run.stats.set_modifier("max_hp", "test", 400.0)
		run.hp = run.stat("max_hp")
		var minutes := 0.0
		for i in int(15.0 * 60.0 / 0.05):
			run.tick(0.05)
			if run.state != "live":
				break
		minutes = (run.elapsed - 480.0) / 60.0
		t.check(run.state == "over" and run.end_reason == "bills", "seed %d: ended by Overdue Bills (%s, %s)" % [seed, run.state, run.end_reason])
		t.check(run.result.get("won", false) and run.final_swarm(), "seed %d: counts as surviving the timer" % seed)
		t.check(minutes > 2.0 and minutes < 10.0, "seed %d: bills ended it %.1f min into the Final Swarm" % [seed, minutes])
		t.check(run.result.get("coin_mult", 1.0) > 1.0, "seed %d: coin multiplier rose (x%s)" % [seed, run.result.get("coin_mult")])
		_done(t, run)


func test_swarm_without_damage_is_recorded(t) -> void:
	for get_hit in [false, true]:
		var run := _start(t, {"no_spawns": false, "start_at": 170.0})
		var hit_once := false
		for i in int(40.0 / 0.05):
			# Clear the horde every tick, except one hit when asked.
			for s in run.enemies.pool.active.duplicate():
				run.enemies.remove(s)
			if get_hit and not hit_once and run.director.swarm_active():
				run.damage_player(5.0, "blob", true)
				hit_once = true
			run.tick(0.05)
		var n: float = run.run_stats.get("swarm_survived_no_damage", 0.0)
		t.check(n == (0.0 if get_hit else 1.0), "hit=%s: swarm_survived_no_damage=%s" % [get_hit, n])
		_done(t, run)


func test_first_run_altar_hint(t) -> void:
	for first in [true, false]:
		var run := _start(t, {"start_at": 299.0, "first_run": first})
		_step(run, 1.5)
		var pulse: bool = run._arrow_targets().any(func(a: Dictionary) -> bool: return a.pulse)
		t.check(run.interactables.altar_pulse == first and pulse == first, "first_run=%s: altar arrow pulses=%s" % [first, pulse])
		_done(t, run)


## Brief: the altar has an indicator arrow; chests, shrines, elites and the
## altar get arrows when out of view. Checked by position, for several seeds.
func test_arrows_point_at_offscreen_targets(t) -> void:
	for seed in [1, 2, 3, 7]:
		var run := _start(t, {"seed": seed})
		var view := run.view_rect().grow(-2.0)
		var arrows := run._arrow_targets()
		var at: Array = arrows.map(func(a: Dictionary) -> Vector2: return a.pos)
		var altar := run.interactables.find("boss_altar")
		t.check(at.has(altar.pos), "seed %d: the altar has an arrow" % seed)
		t.check(not arrows.any(func(a: Dictionary) -> bool: return view.has_point(a.pos)), "seed %d: nothing on screen gets an arrow" % seed)
		t.check(arrows.size() <= Interactables.MAX_ARROWS + run.enemies.elites.size() + 1, "seed %d: capped" % seed)
		# An object in view loses its arrow; out of view it gets one back.
		var chest := run.interactables.find("paid_chest")
		var far: Vector2 = chest.pos
		chest.pos = run.player_pos() + Vector2(20, 0)
		t.check(not run._arrow_targets().any(func(a: Dictionary) -> bool: return a.pos == chest.pos), "seed %d: a chest in view has no arrow" % seed)
		chest.pos = far
		# Elites and the boss, by position.
		var s := _spawn(run, "blob", run.player_pos() + Vector2(300, 0), 0.0)
		run.enemies.make_elite(s, "fast", run.elite_rules)
		var near := _spawn(run, "blob", run.player_pos() + Vector2(30, 0), 0.0)
		run.enemies.make_elite(near, "fast", run.elite_rules)
		arrows = run._arrow_targets()
		at = arrows.map(func(a: Dictionary) -> Vector2: return a.pos)
		t.check(at.has(run.enemies.pos[s]) and not at.has(run.enemies.pos[near]), "seed %d: the far elite has an arrow, the one in view doesn't" % seed)
		_done(t, run)


func test_big_enemies_separate(t) -> void:
	var run := _start(t)
	run.weapons.clear()
	var e := run.enemies
	var at := run.player_pos() + Vector2(0, -150)
	var a := _spawn(run, "chomper", at, 0.0)
	var b := _spawn(run, "chomper", at + Vector2(1, 0), 0.0)
	e.make_elite(a, "vicious", run.elite_rules)
	e.make_elite(b, "vicious", run.elite_rules)
	var mole := _spawn(run, "mega_mole", at + Vector2(80, 0), 0.0)
	var c := _spawn(run, "chomper", at + Vector2(82, 1), 0.0)
	e.make_elite(c, "fast", run.elite_rules)
	var small := []
	for i in 12:
		small.append(_spawn(run, "blob", at + Vector2(80, 0) + Vector2.from_angle(i) * 3.0, 0.0))
	var mole_at := e.pos[mole]
	_step(run, 1.0)
	var ab := e.pos[a].distance_to(e.pos[b])
	t.check(ab >= e.radius[a] + e.radius[b] - 1.0, "two elites (r %d) pushed apart: %.1f" % [e.radius[a], ab])
	var mc := e.pos[mole].distance_to(e.pos[c])
	t.check(mc >= e.radius[mole] + e.radius[c] - 1.0, "elite pushed off the boss: %.1f of %.1f" % [mc, e.radius[mole] + e.radius[c]])
	var inside := 0
	for s in small:
		if e.pos[s].distance_to(e.pos[mole]) < e.radius[mole] + e.radius[s] - 1.0:
			inside += 1
	t.check(inside == 0, "%d Blobs still inside the boss" % inside)
	t.check(e.pos[mole] == mole_at, "the boss isn't pushed around")
	_done(t, run)


# --- Review fixes ------------------------------------------------------------

func test_dying_on_the_portal_ends_the_run_once(t) -> void:
	var run := _start(t, {"invincible": false})
	run.weapons.clear()
	var ends := []
	run.run_ended.connect(func(r: Dictionary) -> void: ends.append(r.reason))
	var portal := run.interactables.add("portal", run.player_pos() + Vector2(60, 0))
	run.hp = 1.0
	_spawn(run, "blob", portal.pos)
	run.teleport(portal.pos)
	run.tick(DT)
	run.tick(DT)
	t.check(ends == ["died"], "one end, the death (%s)" % [ends])
	_done(t, run)


func test_dying_as_a_shop_opens_leaves_no_live_panel(t) -> void:
	var run := _start(t, {"invincible": false, "auto_cards": false})
	run.weapons.clear()
	var ends := []
	run.run_ended.connect(func(r: Dictionary) -> void: ends.append(r.reason))
	var m := run.interactables.add("merchant", run.player_pos() + Vector2(60, 0))
	run.gold = 1000.0
	run.hp = 1.0
	_spawn(run, "blob", m.pos)
	run.teleport(m.pos + Vector2(80, 0))
	run.tick(DT)
	run.teleport(m.pos)
	run.tick(DT)
	t.check(run.state == "over" and not run._choice_panel.visible, "game over with the shop closed (state %s)" % run.state)
	run._close_choice()  # what LEAVE would do
	run.tick(DT)
	t.check(run.state == "over" and ends.size() == 1, "LEAVE can't bring the run back (state %s, ends %s)" % [run.state, ends])
	_done(t, run)


func test_end_guards_each_hold_on_their_own(t) -> void:
	var run := _start(t, {"auto_cards": false})
	var ends := []
	run.run_ended.connect(func(r: Dictionary) -> void: ends.append(r.reason))
	# A shop open when the run ends: _end closes it.
	var m := run.interactables.add("merchant", run.player_pos() + Vector2(60, 0))
	run.open_merchant(m)
	t.check(run.state == "choice" and run._choice_panel.visible, "the shop is open")
	run._end("died")
	t.check(not run._choice_panel.visible, "_end hides the shop")
	run._end("portal")
	t.check(ends == ["died"], "_end runs once (%s)" % [ends])
	run._close_choice()
	t.check(run.state == "over", "LEAVE after game over does nothing (state %s)" % run.state)
	_done(t, run)


func test_result_screen_music(t) -> void:
	var lost := _start(t)
	if lost.juice.audio == null or not lost.juice.audio.has_method("play_music"):
		t.check(true, "no audio manager in this test run: result music not checked")
		_done(t, lost)
		return
	lost._end("died")
	lost._reveal_over()
	t.check(lost.juice.audio.music_id == "game_over", "a lost run plays the game over music (%s)" % lost.juice.audio.music_id)
	_done(t, lost)
	var won := _start(t)
	won._end("portal")
	won._reveal_over()
	t.check(won.juice.audio.music_id == "victory", "an escape plays the victory music (%s)" % won.juice.audio.music_id)
	_done(t, won)
	# Owner (2026-10-15): "Survived!" (down in the Final Swarm) gets the victory music too.
	var held := _start(t)
	held.director.final_started = true  # no spawns here, so the director never ticks into it
	held._end("died")
	held._reveal_over()
	t.check(held.final_swarm() and held.juice.audio.music_id == "victory", "Survived! plays the victory music (%s)" % held.juice.audio.music_id)
	_done(t, held)
	# Owner (2026-10-15): Overdue! and Gave Up get the game over music, even in the Final Swarm.
	for reason in ["bills", "gave_up"]:
		var late := _start(t)
		late.director.final_started = true
		late._end(reason)
		late._reveal_over()
		t.check(late.won and late.juice.audio.music_id == "game_over", "%s in the Final Swarm plays the game over music (%s)" % [reason, late.juice.audio.music_id])
		_done(t, late)



func test_shop_purchase_rechecks_the_legendary_limit(t) -> void:
	var run := _start(t, {"all_content": true})
	run.give_item("microwave_meltdown")
	t.check(not run._can_hold("microwave_meltdown"), "a held legendary can't be held again")
	t.check(run._can_hold("protein_bar"), "a common can")
	# Even pressing the (disabled) shop option doesn't sell it.
	var m := run.interactables.add("merchant", run.player_pos() + Vector2(60, 0))
	m.stock = [{"item": "microwave_meltdown", "price": 10, "sold": false}]
	run.gold = 100.0
	run.options.auto_cards = false
	run.open_merchant(m)
	run._choice.on_pick.call(0)
	t.check(run.items.count("microwave_meltdown") == 1 and run.gold == 100.0, "the purchase itself re-checks the limit")
	run._close_choice()
	_done(t, run)


func test_explosions_skip_a_reused_slot(t) -> void:
	var run := _start(t)
	run.weapons.clear()
	var e := run.enemies
	var me := run.player_pos()
	var a := _spawn(run, "bloater", me + Vector2(4, 0), 0.0)
	var b := _spawn(run, "bloater", me + Vector2(-4, 0), 0.0)
	for s in [a, b]:
		e.state[s] = EnemySystem.ST_WINDUP
		e.timer[s] = 0.0
	# When A goes off, B dies and a Skitter takes B's slot (the pool hands
	# back the slot freed last), as a Whoopee blast + a Splitting elite would.
	var events := []
	var real := e.event_fn
	e.event_fn = func(kind: int, slot: int, dir: Vector2) -> void:
		if kind == EnemySystem.EV_EXPLODE:
			events.append(e.types[e.type_of[slot]].id)
			if slot == a:
				e.remove(b)
				_spawn(run, "skitter", me + Vector2(40, 0), 0.0)
		real.call(kind, slot, dir)
	e.update(DT, me)
	t.check(events == ["bloater"], "only the real Bloater exploded (%s)" % [events])
	_done(t, run)


func test_crowds_dont_push_walkers_into_houses(t) -> void:
	var run := _start(t)
	run.weapons.clear()
	var target := Vector2(164, 70)  # behind a row of houses on Maple Court
	for i in 120:
		_spawn(run, "blob", Vector2(140 + (i % 12) * 4, 186 + (i / 12) * 2))
	var worst := 0
	for k in int(6.0 / DT):
		run.teleport(target)
		run.tick(DT)
		var n := 0
		for s in run.enemies.pool.active:
			if run.map.is_blocked(run.enemies.pos[s]):
				n += 1
		worst = maxi(worst, n)
	t.check(worst == 0, "walkers inside solid cells, peak %d of 120" % worst)
	_done(t, run)


func test_walkers_dont_wedge_in_corners(t) -> void:
	var run := _start(t)
	run.weapons.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var slots := []
	for i in 120:
		slots.append(_spawn(run, "blob", run.map.random_free_point(rng, 6.0, [], 0.0, run.player_pos(), 70.0)))
	var marks := {}
	for k in int(40.0 / DT):
		run.tick(DT)
		if k == int(35.0 / DT):
			for s in slots:
				marks[s] = run.enemies.pos[s]
	# Off screen, a wedged walker is moved back into play; in view, a couple
	# may queue against a wall behind the horde around the player.
	var view := run.view_rect()
	var off_screen := 0
	var in_view := 0
	for s in slots:
		var p: Vector2 = run.enemies.pos[s]
		if p.distance_to(run.player_pos()) > 60.0 and p.distance_to(marks[s]) < 3.0:
			if view.has_point(p):
				in_view += 1
			else:
				off_screen += 1
	t.check(off_screen == 0, "%d of 120 walkers stuck off screen" % off_screen)
	t.check(in_view <= 2, "%d of 120 walkers stuck in view" % in_view)
	_done(t, run)


func test_wedged_walkers_off_screen_are_moved_back(t) -> void:
	var run := _start(t)
	run.weapons.clear()
	var e := run.enemies
	var off := _spawn(run, "blob", run.player_pos() + Vector2(0, run._half_view().y + 30.0), 0.0)
	var on := _spawn(run, "blob", run.player_pos() + Vector2(40, 0), 0.0)
	var off_at := e.pos[off]
	var on_at := e.pos[on]
	e.stalled[off] = Run.STALL_SEC + 1.0
	e.stalled[on] = Run.STALL_SEC + 1.0
	_step(run, Run.RECYCLE_EVERY + DT)
	t.check(e.pos[off].distance_to(off_at) > 20.0 and e.stalled[off] == 0.0, "a wedged walker off screen is moved back into play")
	t.check(e.pos[on].distance_to(on_at) < 2.0, "one in view doesn't jump")
	_done(t, run)


func test_altar_works_again_after_a_full_pool(t) -> void:
	var run := _start(t)
	run.weapons.clear()
	var e := run.enemies
	var filler := []
	while true:
		var s := _spawn(run, "blob", run.player_pos() + Vector2(150, 0), 0.0)
		if s < 0:
			break
		filler.append(s)
	var altar := run.interactables.find("boss_altar")
	run.teleport(altar.pos)
	_step(run, float(altar.def.charge_time) + 0.3)
	t.check(not run.boss_summoned and not altar.used, "a full pool: no boss, the altar stays usable")
	for s in filler:
		e.remove(s)
	run.teleport(altar.pos)
	_step(run, float(altar.def.charge_time) + 0.3)
	t.check(run.boss_summoned and altar.used, "then it summons the boss")
	_done(t, run)


func test_bills_that_cant_spawn_are_not_counted(t) -> void:
	var run := _start(t, {"no_spawns": false, "start_at": 480.0 + 125.0})
	run.weapons.clear()
	# Fill every slot, reserve included.
	while _spawn(run, "blob", run.player_pos() + Vector2(150, 0), 0.0) >= 0:
		pass
	_step(run, 3.0)
	t.check(run.director.bills_spawned == run.enemies.ghosts.size(), "bills counted = bills alive (%d vs %d)" % [run.director.bills_spawned, run.enemies.ghosts.size()])
	_done(t, run)


func test_two_risk_shrines_both_wear_off(t) -> void:
	var run := _start(t)
	var a := run.interactables.find("risk_shrine")
	# The second one a short walk away, on the map's side of the first.
	var dy := 60.0 if a.pos.y < run.bounds.get_center().y else -60.0
	var b := run.interactables.add("risk_shrine", run.free_spot_near(a.pos + Vector2(0, dy)))
	run.teleport(a.pos)
	_step(run, float(a.def.charge_time) + 0.2)
	run.teleport(b.pos)
	_step(run, float(b.def.charge_time) + 0.2)
	t.check(run.interactables.risks.size() == 2 and run.stat("enemy_hp") > 1.5, "both risks stack (enemy HP x%s)" % run.stat("enemy_hp"))
	_step(run, float(a.def.duration) + 3.0)
	t.check(is_equal_approx(run.stat("enemy_hp"), 1.0) and run.interactables.risks.is_empty(), "both wore off (enemy HP x%s)" % run.stat("enemy_hp"))
	_done(t, run)


func test_merchant_wont_sell_a_second_legendary(t) -> void:
	var run := _start(t, {"all_content": true})
	run.give_item("microwave_meltdown")
	var m := run.interactables.add("merchant", run.player_pos() + Vector2(60, 0))
	m.stock = [{"item": "microwave_meltdown", "price": 10, "sold": false}, {"item": "protein_bar", "price": 10, "sold": false}]
	run.gold = 100.0
	_touch(run, m)
	t.check(run.items.count("microwave_meltdown") == 1, "still one legendary (%d)" % run.items.count("microwave_meltdown"))
	t.check(run.items.count("protein_bar") == 1 and run.gold == 90.0, "the other item sold (gold %s)" % run.gold)
	_done(t, run)


func test_exploding_elite_still_drops_and_splits(t) -> void:
	var run := _start(t)
	run.weapons.clear()
	var e := run.enemies
	var chests := run.interactables.count_of("elite_chest")
	var s := _spawn(run, "bloater", run.player_pos() + Vector2(10, 0), 0.0)
	e.make_elite(s, "splitting", run.elite_rules)
	_step(run, 3.0)
	var bloaters := 0
	for o in e.pool.active:
		if e.types[e.type_of[o]].id == "bloater":
			bloaters += 1
	t.check(not e.pool.is_alive(s) or e.elite[s] == 0, "the elite blew up")
	t.check(run.interactables.count_of("elite_chest") == chests + 1, "it still dropped its chest")
	t.check(bloaters >= 1 or run.run_stats.get("elites_killed", 0.0) == 0.0, "it split (%d Bloaters)" % bloaters)
	t.check(run.run_stats.get("elites_killed", 0.0) == 0.0 and run.kills == 0, "not counted as a defeat")
	_done(t, run)



## Every spot where the player fits can be reached from the start: no sealed
## pocket (a map edit that closes a gap shows up here).
func test_open_ground_is_all_reachable(t) -> void:
	var run := _start(t)
	var map := run.map
	var r := run.player_radius() + 1.0
	var fits := PackedByteArray()
	fits.resize(map.cols * map.rows)
	for c in map.cols * map.rows:
		var center := Vector2((c % map.cols + 0.5) * MapLayout.CELL, (c / map.cols + 0.5) * MapLayout.CELL)
		fits[c] = 1 if map.bounds.grow(-r).has_point(center) and map.is_area_free(center, r) else 0
	var start := int(run.player_pos().y / MapLayout.CELL) * map.cols + int(run.player_pos().x / MapLayout.CELL)
	var seen := PackedByteArray()
	seen.resize(fits.size())
	seen[start] = 1
	var queue := PackedInt32Array([start])
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx := c % map.cols + d.x
			var ny := c / map.cols + d.y
			if nx < 0 or ny < 0 or nx >= map.cols or ny >= map.rows:
				continue
			var n := ny * map.cols + nx
			if fits[n] == 1 and seen[n] == 0:
				seen[n] = 1
				queue.append(n)
	var cut := []
	var total := 0
	for c in fits.size():
		if fits[c] == 1:
			total += 1
			if seen[c] == 0:
				cut.append(Vector2((c % map.cols + 0.5) * MapLayout.CELL, (c / map.cols + 0.5) * MapLayout.CELL))
	t.check(cut.is_empty(), "%d of %d open cells can't be reached, e.g. %s" % [cut.size(), total, cut.slice(0, 5)])
	_done(t, run)


func test_world_view_is_wider_than_the_ui(t) -> void:
	var run := _start(t)
	var vp: SubViewport = run.world_viewport
	t.check(vp != null and run.map.get_parent() == vp and run._camera.get_parent() == vp, "the world draws in its own view")
	var want: float = float(run.rules.get("world_view_scale", 1.0))
	t.check(run.world_scale == clampi(roundi(run.ui_scale / want), 1, run.ui_scale), "world scale %d for UI scale %d" % [run.world_scale, run.ui_scale])
	var ui := run.get_viewport_rect().size
	t.check(absf(Vector2(vp.size).x - ui.x * run.ui_scale / run.world_scale) < 1.0, "world view %s for UI %s" % [vp.size, ui])
	t.check(run.view_rect().size == Vector2(vp.size), "view_rect is the world view")
	if run.ui_scale >= 2:
		t.check(Vector2(vp.size).x > ui.x * 1.2, "the world shows more than the UI frame")
	_done(t, run)

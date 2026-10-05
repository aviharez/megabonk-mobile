extends RefCounted
## Pools never grow, hand out every slot once, and recycle correctly.


func test_slot_pool_capacity_and_reuse(t) -> void:
	var p := SlotPool.new(4)
	var got := []
	for i in 4:
		got.append(p.acquire())
	t.check(got == [0, 1, 2, 3], "hands out 0..3, got %s" % [got])
	t.check(p.acquire() == -1 and p.is_full(), "-1 when full")
	p.release(1)
	t.check(p.count() == 3 and not p.is_alive(1), "released")
	t.check(p.acquire() == 1, "reuses the freed slot")
	p.release(1)
	p.release(1)
	t.check(p.count() == 3, "double release is ignored")


func test_slot_pool_active_list_stays_consistent(t) -> void:
	var p := SlotPool.new(64)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var alive := {}
	for step in 2000:
		if rng.randf() < 0.55:
			var s := p.acquire()
			if s >= 0:
				alive[s] = true
		elif p.count() > 0:
			var s := p.active[rng.randi_range(0, p.count() - 1)]
			p.release(s)
			alive.erase(s)
	var listed := {}
	for s in p.active:
		listed[s] = true
	t.check(listed.size() == p.count() and listed.keys().size() == alive.size(), "no duplicates in active")
	var same := true
	for s in alive:
		same = same and listed.has(s) and p.is_alive(s)
	t.check(same, "active matches the live set")


func test_node_pool_round_robin(t) -> void:
	var parent := Node.new()
	var made := [0]
	var pool := NodePool.new(parent, 3, func() -> Node:
		made[0] += 1
		return Node.new())
	var seen := []
	for i in 7:
		seen.append(pool.take())
	t.check(made[0] == 3 and parent.get_child_count() == 3, "only 3 nodes ever made")
	t.check(seen[0] == seen[3] and seen[1] == seen[4], "oldest reused")
	parent.free()


func test_gem_pool_merges_when_full(t) -> void:
	var g := GemSystem.new()
	var rules: Dictionary = GameData.shared().get_entry("rules", "run").duplicate(true)
	rules.gem_cap = 5
	g.setup(rules)
	for i in 8:
		g.drop(Vector2(i * 10, 0), 1.0)
	var total := 0.0
	for s in g.pool.active:
		total += g.value[s]
	t.check(g.count() == 5, "gem count capped at 5, got %d" % g.count())
	t.check(is_equal_approx(total, 8.0), "no XP lost, got %s" % total)
	t.check(g.merges == 3, "3 merges")
	# Magnet: a gem inside pickup range is pulled in and collected.
	var got := 0.0
	for i in 120:
		got += g.update(1.0 / 60.0, Vector2(0, 0), 25.0)
	t.check(got >= 3.0, "gems within range collected, got %s" % got)
	g.free()


func test_projectile_pool_drops_when_full(t) -> void:
	var p := ProjectileSystem.new()
	p.setup(2)
	t.check(p.fire({"pos": Vector2.ZERO, "vel": Vector2.RIGHT, "damage": 1.0}) >= 0, "first")
	t.check(p.fire({"pos": Vector2.ZERO, "vel": Vector2.RIGHT, "damage": 1.0}) >= 0, "second")
	t.check(p.fire({"pos": Vector2.ZERO, "vel": Vector2.RIGHT, "damage": 1.0}) == -1, "third dropped")
	p.free()


func test_enemy_pool_cap(t) -> void:
	var e := EnemySystem.new()
	e.setup(GameData.shared().all("enemies"), 10, Rect2(0, 0, 200, 200))
	var ok := 0
	for i in 15:
		if e.spawn(0, Vector2(100, 100), 1, 1, 1) >= 0:
			ok += 1
	t.check(ok == 10 and e.count() == 10, "enemy pool holds 10, got %d" % ok)
	e.free()


func test_query_reaches_big_enemies(t) -> void:
	# A big enemy (elite/boss size) must be found by a small query touching its edge.
	var defs: Array = GameData.shared().all("enemies").duplicate(true)
	var big: Dictionary = defs[0].duplicate(true)
	big.id = "big"
	big.radius = 30.0
	defs.append(big)
	var e := EnemySystem.new()
	e.setup(defs, 10, Rect2(0, 0, 400, 400))
	var s := e.spawn(defs.size() - 1, Vector2(200, 200), 1, 1, 1)
	e.update(0.0, Vector2(200, 200))
	var out := PackedInt32Array()
	e.query_circle(Vector2(233, 200), 4.0, out)
	t.check(out.has(s), "edge of a radius-30 enemy is hit")
	e.free()

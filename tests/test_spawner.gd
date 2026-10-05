extends RefCounted
## Spawn schedule, the enemy cap, and escalation past the cap.


func _map(per_sec: Array) -> Dictionary:
	return {"spawns": [{"enemy": "blob", "from_min": 0, "to_min": 8, "per_sec": per_sec}],
		"escalation_per_blocked_spawn": 0.01, "escalation_speed_cap": 1.5}


func _count(reqs: Array) -> int:
	var n := 0
	for r in reqs:
		n += r.count
	return n


func test_rate_follows_schedule(t) -> void:
	var sp := Spawner.new(_map([2.0, 2.0]), 300)
	var rng := RandomNumberGenerator.new()
	var n := 0
	for i in 600:  # 10 s at 60 fps
		n += _count(sp.tick(1.0 / 60.0, 0.5, 0, {}, rng))
	t.check(n >= 19 and n <= 20, "2/s for 10 s gives ~20, got %d" % n)


func test_never_exceeds_cap(t) -> void:
	var sp := Spawner.new(_map([500.0, 500.0]), 300)
	var rng := RandomNumberGenerator.new()
	var alive := 0
	for i in 120:
		alive += _count(sp.tick(1.0 / 60.0, 1.0, alive, {}, rng))
		if alive > 300:
			t.check(false, "alive %d over cap" % alive)
	t.check(alive == 300, "fills to exactly the cap, got %d" % alive)
	t.check(sp.blocked_total > 0, "spawns were blocked")
	t.check(sp.escalation > 0.0 and sp.hp_mult() > 1.0 and sp.damage_mult() > 1.0, "escalation raises hp and damage")
	t.check(sp.speed_mult() <= 1.5, "speed escalation capped")


func test_packs_spawn_grouped_and_respect_cap(t) -> void:
	var sp := Spawner.new(_map([1.0, 1.0]), 3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var reqs := sp.tick(1.0, 0.0, 0, {"blob": [5, 5]}, rng)
	t.check(reqs.size() == 1 and reqs[0].grouped and reqs[0].count == 3, "pack of 5 trimmed to 3, got %s" % [reqs])
	t.check(sp.blocked_total == 2, "2 blocked")


func test_window(t) -> void:
	var m := _map([10.0, 10.0])
	m.spawns[0].from_min = 2
	var sp := Spawner.new(m, 300)
	var rng := RandomNumberGenerator.new()
	t.check(_count(sp.tick(1.0, 1.0, 0, {}, rng)) == 0, "nothing before from_min")
	t.check(_count(sp.tick(1.0, 2.5, 0, {}, rng)) == 10, "spawns inside the window")


func test_edge_point_is_off_screen(t) -> void:
	var rng := RandomNumberGenerator.new()
	var bounds := Rect2(0, 0, 720, 720)
	var half := Vector2(100, 170)
	var bad := 0
	for c in [Vector2(360, 360), Vector2(20, 360), Vector2(700, 700)]:
		var view := Rect2(c - half, half * 2.0).grow(-2.0)
		for i in 200:
			var p := Spawner.edge_point(rng, c, half, bounds)
			if view.has_point(p) or not bounds.grow(0.01).has_point(p):
				bad += 1
	t.check(bad == 0, "%d spawn points on screen or outside the map" % bad)

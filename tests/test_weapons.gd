extends RefCounted
## Every weapon in data/weapons/, at level 1 and level 5, in a real run:
## it attacks (on_attack) and hits something (on_hit with its id as source).
## Plus one check per pattern that its level-up does what the brief says.

const RUN_SCENE := preload("res://scenes/run.tscn")
const DT := 1.0 / 30.0
## Rings of tough, still enemies around the player: [distance, count].
const RINGS := [[14.0, 6], [22.0, 8], [30.0, 10], [40.0, 12]]


func _start(t, weapon: String, level: int, cap: int, extra := {}) -> Run:
	var o := {
		"bot": true, "auto_cards": true, "no_save": true, "invincible": true, "seed": 5,
		"all_content": true, "loadout": {"weapons": {weapon: level}},
		# The cap = the enemies the test places, so the spawner adds none.
		"rules": {"enemy_cap": cap},
	}
	o.merge(extra, true)
	Run.next_options = o
	var run: Run = RUN_SCENE.instantiate()
	t.root.add_child(run)
	return run


func _weapon(run: Run, id: String) -> Weapon:
	for w in run.weapons:
		if w.id() == id:
			return w
	return null


## Offsets from the player for the ring layout.
func _ring_offsets() -> Array:
	var out := []
	for r: Array in RINGS:
		for k in int(r[1]):
			out.append(Vector2.from_angle(k * TAU / r[1] + r[0] * 0.1) * r[0])
	return out


## Ring layout plus a grid over the whole screen (for screen-wide weapons).
func _all_offsets(run: Run) -> Array:
	var out := _ring_offsets()
	var half := run.view_rect().size / 2.0
	var y := -half.y + 12.0
	while y < half.y - 8.0:
		var x := -half.x + 12.0
		while x < half.x - 8.0:
			if Vector2(x, y).length() > 48.0:
				out.append(Vector2(x, y))
			x += 24.0
		y += 24.0
	return out


## Places tough skitters that don't move at the given offsets from the player.
func _place(run: Run, offsets: Array) -> Array:
	var slots := []
	var skitter: int = run.enemies.type_index["skitter"]
	for off: Vector2 in offsets:
		slots.append(run.enemies.spawn(skitter, run.player_pos() + off, 1000.0, 1.0, 0.0))
	return slots


## Ticks `seconds`, moving each enemy back to its offset from the player.
func _hold(run: Run, slots: Array, offsets: Array, seconds: float) -> void:
	for i in int(seconds / DT):
		for k in slots.size():
			if run.enemies.pool.is_alive(slots[k]):
				run.enemies.move_to(slots[k], run.player_pos() + offsets[k])
		run.tick(DT)


## Runs `id` at `level` for `seconds` with enemies held around the player.
## Returns {hits, slots: {slot: hit count}, attacks, run, weapon, times}.
func _trial(t, id: String, level: int, seconds := 4.0, offsets: Array = []) -> Dictionary:
	var probe := _start(t, id, level, 1)
	var offs: Array = offsets if not offsets.is_empty() else _all_offsets(probe)
	probe.free()
	var run := _start(t, id, level, offs.size())
	var rec := {"hits": 0, "slots": {}, "attacks": 0, "times": {}, "far": 0.0}
	run.on_hit.connect(func(slot: int, _a: float, _c: bool, source: String) -> void:
		if source != id:
			return
		rec.hits += 1
		rec.slots[slot] = rec.slots.get(slot, 0) + 1
		if not rec.times.has(slot):
			rec.times[slot] = []
		rec.times[slot].append(run.elapsed)
		rec.far = maxf(rec.far, run.enemies.pos[slot].distance_to(run.player_pos())))
	run.on_attack.connect(func(w: String) -> void:
		if w == id:
			rec.attacks += 1)
	var slots := _place(run, offs)
	_hold(run, slots, offs, seconds)
	rec.run = run
	rec.weapon = _weapon(run, id)
	return rec


func test_every_weapon_attacks_and_hits_at_level_1_and_5(t) -> void:
	var ids := []
	for w: Dictionary in GameData.shared().all("weapons"):
		ids.append(w.id)
	t.check(ids.size() == 10, "10 weapons in data, got %d: %s" % [ids.size(), ids])
	for id: String in ids:
		for level in [1, 5]:
			var r := _trial(t, id, level)
			var w: Weapon = r.weapon
			t.check(w != null and w.level == level, "%s is owned at level %d" % [id, level])
			t.check(r.attacks > 0, "%s L%d fired on_attack (%d)" % [id, level, r.attacks])
			t.check(r.hits > 0, "%s L%d hit something (%d hits)" % [id, level, r.hits])
			r.run.free()


func test_weapon_data_rules(t) -> void:
	var allowed := " !\"#%'()+,-./0123456789:<=>?ABCDEFGHIJKLMNOPQRSTUVWXYZ_"
	for w: Dictionary in GameData.shared().all("weapons"):
		t.check(w.levels.size() == 5, "%s has 5 levels" % w.id)
		t.check(w.name.length() <= 20, "%s name fits" % w.id)
		var texts: Array = [w.name, w.desc]
		for lv: Dictionary in w.levels:
			texts.append(lv.desc)
		for s: String in texts:
			var ok := true
			for ch in s:
				ok = ok and allowed.contains(ch)
			t.check(ok, "%s: only pixel-font characters in '%s'" % [w.id, s])
		for s: String in texts.slice(1):
			t.check(s.length() <= 26, "%s: '%s' fits a card (%d)" % [w.id, s, s.length()])


func test_feathers_home_and_grow(t) -> void:
	var counts := []
	for level in [1, 5]:
		var run := _start(t, "sharp_feathers", level, 4)
		var shots := []
		run.on_projectile.connect(func(shot: Dictionary) -> void:
			if shot.source == "sharp_feathers":
				shots.append(shot))
		var offs := [Vector2(60, 0), Vector2(-60, 0), Vector2(0, 60), Vector2(0, -60)]
		var slots := _place(run, offs)
		_hold(run, slots, offs, 0.5)
		t.check(not shots.is_empty() and shots[0].homing > 0.0, "feathers home (L%d)" % level)
		counts.append(shots.size())
		run.free()
	t.check(counts[1] > counts[0], "L5 fires more feathers per volley: %s" % [counts])


func test_stapler_fires_straight_and_fast(t) -> void:
	var r1 := _trial(t, "stapler", 1, 3.0)
	var r5 := _trial(t, "stapler", 5, 3.0)
	t.check(r1.attacks >= 6, "rapid fire: %d shots in 3 s at L1" % r1.attacks)
	t.check(r5.hits > r1.hits, "L5 hits more: %d vs %d" % [r5.hits, r1.hits])
	var homing := false
	var run: Run = r1.run
	for s in run.projectiles.pool.active:
		homing = homing or run.projectiles.homing[s] > 0.0
	t.check(not homing, "staples don't home")
	r1.run.free()
	r5.run.free()


func test_duck_bounces_to_more_enemies_when_upgraded(t) -> void:
	# A loose line of enemies, each within bounce range of the next.
	var offs := []
	for k in 10:
		offs.append(Vector2(40 + k * 22, (k % 2) * 12 - 6))
	var distinct := []
	for level in [1, 5]:
		var run := _start(t, "rubber_duck", level, offs.size())
		var hit_order := []
		run.on_hit.connect(func(slot: int, _a: float, _c: bool, source: String) -> void:
			if source == "rubber_duck":
				hit_order.append(slot))
		var slots := _place(run, offs)
		# One throw: the first fires at 0.4 s, the next at 0.4 + cooldown.
		_hold(run, slots, offs, 1.6)
		var seen := {}
		for s in hit_order:
			seen[s] = true
		distinct.append(seen.size())
		var no_pingpong := true
		for i in range(2, hit_order.size()):
			no_pingpong = no_pingpong and hit_order[i] != hit_order[i - 2]
		t.check(no_pingpong, "L%d duck doesn't bounce straight back: %s" % [level, hit_order])
		run.free()
	t.check(distinct[0] >= 2, "L1 duck bounces at least once (%d enemies)" % distinct[0])
	t.check(distinct[1] > distinct[0], "L5 duck reaches more enemies: %s" % [distinct])


func test_coffee_puddle_scalds_over_time_and_grows(t) -> void:
	var radii := []
	for level in [1, 5]:
		var r := _trial(t, "hot_coffee", level, 3.0, _ring_offsets())
		var w = r.weapon
		radii.append(w.puddle_radius())
		var repeat := 0
		for s in r.slots:
			repeat = maxi(repeat, r.slots[s])
		t.check(repeat >= 2, "L%d puddle hits the same enemy on several ticks (%d)" % [level, repeat])
		r.run.free()
	t.check(radii[1] > radii[0], "L5 puddle is bigger: %s" % [radii])


func test_socks_radius_grows(t) -> void:
	var r1 := _trial(t, "stinky_socks", 1, 2.0, _ring_offsets())
	var r5 := _trial(t, "stinky_socks", 5, 2.0, _ring_offsets())
	t.check(r5.weapon.radius() > r1.weapon.radius(), "radius %s -> %s" % [r1.weapon.radius(), r5.weapon.radius()])
	t.check(r5.slots.size() > r1.slots.size(), "L5 reaches more enemies: %d vs %d" % [r5.slots.size(), r1.slots.size()])
	r1.run.free()
	r5.run.free()


func test_gnomes_grow_and_respect_hit_cooldown(t) -> void:
	var r1 := _trial(t, "garden_gnomes", 1, 3.0, _ring_offsets())
	var r5 := _trial(t, "garden_gnomes", 5, 3.0, _ring_offsets())
	t.check(r5.weapon.gnome_count() > r1.weapon.gnome_count(), "gnomes %d -> %d" % [r1.weapon.gnome_count(), r5.weapon.gnome_count()])
	for r: Dictionary in [r1, r5]:
		var wait: float = r.weapon.cooldown(r.run)
		var min_gap := INF
		for s in r.times:
			var ts: Array = r.times[s]
			for i in range(1, ts.size()):
				min_gap = minf(min_gap, ts[i] - ts[i - 1])
		t.check(min_gap >= wait - 0.04, "no enemy hit twice within %.2f s (min gap %.3f)" % [wait, min_gap])
	t.check(r5.hits > r1.hits, "more gnomes, more hits: %d vs %d" % [r5.hits, r1.hits])
	r1.run.free()
	r5.run.free()


func test_leaf_blower_cone_widens_and_pushes_harder(t) -> void:
	var moved := []
	var halves := []
	for level in [1, 5]:
		# No bot: the player stands still, so the cone direction is known.
		var run := _start(t, "leaf_blower", level, 2, {"bot": false})
		var front := run.player_pos() + Vector2(34, 0)
		var behind := run.player_pos() + Vector2(-38, 0)
		var f := _place(run, [Vector2(34, 0), Vector2(-38, 0)])
		var hit := {}
		run.on_hit.connect(func(slot: int, _a: float, _c: bool, source: String) -> void:
			if source == "leaf_blower":
				hit[slot] = true)
		# Enemies don't walk (speed 0). One blast at 0.5 s.
		for i in int(0.9 / DT):
			run.tick(DT)
		halves.append(run.weapons[1].cone().x)
		moved.append(run.enemies.pos[f[0]].distance_to(front))
		if level == 1:
			t.check(hit.has(f[0]) and not hit.has(f[1]), "L1 cone hits only the enemy in front: %s" % [hit])
			t.check(run.enemies.pos[f[1]].distance_to(behind) < 1.0, "the enemy behind isn't pushed")
		run.free()
	t.check(halves[1] > halves[0], "cone widens: %s" % [halves])
	t.check(moved[1] > moved[0] and moved[0] > 8.0, "pushed back hard, more at L5: %s px" % [moved])


func test_toaster_chains_further_when_upgraded(t) -> void:
	var r1 := _trial(t, "faulty_toaster", 1, 1.0, _ring_offsets())
	var r5 := _trial(t, "faulty_toaster", 5, 1.0, _ring_offsets())
	t.check(r1.weapon.last_hits == 3, "L1 zaps 3 enemies (%d)" % r1.weapon.last_hits)
	t.check(r5.weapon.last_hits > r1.weapon.last_hits, "L5 chains further: %d" % r5.weapon.last_hits)
	r1.run.free()
	r5.run.free()


func test_fireworks_more_rockets_across_the_screen(t) -> void:
	var r1 := _trial(t, "fireworks", 1, 1.0)
	var r5 := _trial(t, "fireworks", 5, 1.0)
	t.check(r1.weapon.launched == 2 and r5.weapon.launched == 7, "rockets per volley: %d -> %d" % [r1.weapon.launched, r5.weapon.launched])
	r1.run.free()
	r5.run.free()
	var r := _trial(t, "fireworks", 5, 4.0)
	t.check(r.far > 50.0, "blasts land away from the player (farthest hit %.0f px)" % r.far)
	r.run.free()

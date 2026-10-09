class_name MegaMole
extends RefCounted
## Mega Mole, the Suburbia boss. Its body is a normal enemy slot (role
## "boss"), so weapons hit it like anything else; this controller moves it
## and runs its patterns. Numbers come from data/enemies/mega_mole.json "boss":
##
##   burrow  digs down ("dig_time", still visible and hittable; the burrow
##           clip), then can't be hit while its shadow chases the player, stops
##           with a red warning zone, then it pops up there and hurts the
##           player if they're still inside
##   rocks   rings of rocks (enemy shots) with a gap to slip through
##   summon  calls Blobs around itself
##
## Below "rage_below" of its HP every timer runs faster ("rage_speedup" is
## the time scale) and its shadow and rocks move faster.
##
## Sheet clips (assets/bosses/mega_mole.json): walk loops; burrow plays when
## it digs and backwards when it pops up; attack on rocks and summons; hit
## when damaged (at most every "hit_anim_gap" s, only between attacks).

var run: Node
var slot := -1
var cfg := {}
var phase := "rest"
var t := 1.5
var rage := false
var shadow := Vector2.ZERO
var _next := 0
var _rings_left := 0
var _last_hit_anim := -INF


func _init(owner_run: Node, boss_slot: int) -> void:
	run = owner_run
	slot = boss_slot
	cfg = run.enemies.types[run.enemies.type_of[slot]].get("boss", {})
	t = _rest_time()


func alive() -> bool:
	return slot >= 0 and run.enemies.pool.is_alive(slot)


func hp_frac() -> float:
	if not alive():
		return 0.0
	return clampf(run.enemies.hp[slot] / run.enemies.max_hp[slot], 0.0, 1.0)


func burrowed() -> bool:
	return phase == "burrow_chase" or phase == "burrow_warn"


func update(delta: float) -> void:
	if not alive():
		return
	var e: EnemySystem = run.enemies
	if not rage and hp_frac() < float(cfg.get("rage_below", 0.5)):
		rage = true
		run.toast("MEGA MOLE IS ANGRY!", "RED")
	var fast := 1.0 / float(cfg.get("rage_speedup", 0.65)) if rage else 1.0
	var dt := delta * fast
	var player: Vector2 = run.player_pos()
	match phase:
		"rest":
			var to := player - e.pos[slot]
			if to.length() > 1.0:
				e.pos[slot] += to.normalized() * e.speed[slot] * fast * delta
			t -= dt
			if t <= 0.0:
				_start_next()
		"burrow_dig":
			t -= dt
			if t <= 0.0:
				phase = "burrow_chase"
				t = float(cfg.burrow.chase_time)
				shadow = e.pos[slot]
				e.set_hidden(slot, true)
		"burrow_chase":
			var b: Dictionary = cfg.burrow
			var to := player - shadow
			var step := float(b.chase_speed) * fast * delta
			shadow += to.normalized() * minf(step, to.length()) if to.length() > 0.5 else Vector2.ZERO
			shadow = shadow.clamp(e.bounds.position, e.bounds.end)
			e.pos[slot] = shadow
			t -= dt
			if t <= 0.0:
				phase = "burrow_warn"
				t = float(b.warn)
				run.danger.disc(shadow, float(b.radius), Palette.RED, t / fast)
				run.danger.ring(shadow, float(b.radius), Palette.RED, t / fast)
		"burrow_warn":
			t -= dt
			if t <= 0.0:
				var b: Dictionary = cfg.burrow
				e.set_hidden(slot, false)
				e.pos[slot] = shadow
				e.play(slot, "burrow", true)
				run.fx.ring(shadow, float(b.radius), Palette.CRUST)
				if player.distance_to(shadow) <= float(b.radius) + run.player_radius():
					run.damage_player(float(b.damage) * e.damage[slot] / float(run.enemies.types[e.type_of[slot]].damage), "mega_mole")
				phase = "rest"
				t = float(b.get("up_time", 0.4)) + _rest_time()
		"rocks":
			t -= dt
			if t <= 0.0:
				_ring(fast)
				run.enemies.play(slot, "attack")
				_rings_left -= 1
				if _rings_left > 0:
					t = float(cfg.rocks.get("ring_delay", 0.6))
				else:
					phase = "rest"
					t = _rest_time()


func _start_next() -> void:
	var patterns: Array = cfg.get("patterns", ["burrow", "rocks", "summon"])
	var p: String = patterns[_next % patterns.size()]
	_next += 1
	match p:
		"burrow":
			phase = "burrow_dig"
			t = float(cfg.burrow.get("dig_time", 0.0))
			run.enemies.play(slot, "burrow")
			run.fx.ring(run.enemies.pos[slot], run.enemies.radius[slot], Palette.CRUST)
		"rocks":
			phase = "rocks"
			t = 0.0
			_rings_left = int(cfg.rocks.get("rings", 1))
		"summon":
			var sm: Dictionary = cfg.summon
			var n := int(sm.count)
			for i in n:
				var at: Vector2 = run.enemies.pos[slot] + Vector2.from_angle(TAU * i / n) * float(sm.distance)
				run.spawn_enemy(sm.enemy, at)
			run.fx.ring(run.enemies.pos[slot], float(sm.distance), Palette.PURPLE)
			run.enemies.play(slot, "attack")
			phase = "rest"
			t = _rest_time()


## Flinch when hit: only while resting (attacks keep their clip) and at most
## every "hit_anim_gap" seconds, since weapons hit it many times a second.
func on_hit() -> void:
	if phase != "rest" or not alive() or run.enemies.clip_of(slot) != "walk":
		return
	if run.elapsed - _last_hit_anim < float(cfg.get("hit_anim_gap", 1.5)):
		return
	_last_hit_anim = run.elapsed
	run.enemies.play(slot, "hit")


## One ring of rocks around the mole with `gap` neighbouring rocks left out
## (at a random spot) so the player can slip through.
func _ring(fast: float) -> void:
	var r: Dictionary = cfg.rocks
	var n := int(r.count)
	var gap := int(r.gap)
	var skip: int = run.rng.randi_range(0, n - 1)
	var at: Vector2 = run.enemies.pos[slot]
	for i in n:
		if (i - skip + n) % n < gap:
			continue
		var dir := Vector2.from_angle(TAU * i / n + 0.1)
		run.enemy_shots.fire(at + dir * run.enemies.radius[slot], dir * float(r.speed) * fast, float(r.damage), float(r.radius), float(r.life), r.get("sprite", "rock"), "mega_mole")


func _rest_time() -> float:
	var r: Array = cfg.get("rest", [1.2, 2.0])
	return run.rng.randf_range(float(r[0]), float(r[1]))


## The shadow while burrowed: a dithered dark ellipse on whole pixels.
func draw(canvas: CanvasItem) -> void:
	if not alive() or not burrowed():
		return
	var c := Palette.color(Palette.INK)
	var at := shadow.round()
	for y in range(-4, 5):
		var half := int(round(12.0 * sqrt(1.0 - (y / 5.0) * (y / 5.0))))
		for x in range(-half, half + 1):
			if (x + y) % 2 == 0:
				canvas.draw_rect(Rect2(at + Vector2(x, y), Vector2.ONE), c)

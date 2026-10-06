class_name Run
extends Node2D
## One run: player, map, weapons, enemies, gems, level-ups, the spawn
## director, map objects, the boss, the Final Swarm, and game over.
## All game logic advances in tick(delta), so headless tests and the bot
## simulation can step a run without real time passing.
##
## Run flow (data/maps/<map>.json): the Director spawns the schedule, SWARM
## INCOMING waves and elites. The player can summon the boss at the altar any
## time; beating it drops a boss chest and opens the exit portal. When the
## timer runs out the Final Swarm starts: escalation never stops and Overdue
## Bills arrive a little later to end the run. Taking the portal ends it too.
##
## Event hooks: every event is a signal below (for the stat tracker in phase 4
## and anything else that listens), and is also passed to ItemSystem.emit(),
## which runs the item triggers from data. `source` is the weapon id, or
## "item:<id>" for item effects. stat_event carries run facts for unlock
## challenges (pots_broken, elites_killed, boss_defeated...); they are also
## summed in `run_stats` and copied into the result.

signal on_hit(enemy_slot: int, amount: float, crit: bool, source: String)
signal on_kill(enemy_slot: int, enemy_id: String, source: String, elite: bool)
signal on_damaged(amount: float)
signal on_level_up(new_level: int)
signal on_chest_opened(kind: String, item_id: String)
signal on_shrine_activated(shrine_id: String)
signal on_attack(weapon_id: String)
signal on_projectile(shot: Dictionary)
signal stat_event(name: String, amount: float)
signal run_ended(result: Dictionary)

const MENU_SCENE := "res://scenes/main_menu.tscn"
## Spawns appear this far outside the visible area.
const SPAWN_MARGIN := Vector2(10, 10)
const RECYCLE_EVERY := 0.25
const PARTICLES := 16

## Options for the next run, set before switching to the run scene (bots,
## stress test). Copied into `options` and cleared on _ready.
static var next_options := {}

## bot: steer automatically. auto_cards: take the first card (and the first
## shrine bonus, the first affordable merchant item) without pausing.
## invincible: ignore damage. no_save: don't write the result to the save.
## stress: keep the enemy count at the cap, spawned on screen.
## stress_final: stress at Final Swarm density (all roles, bills, elites).
## rules: overrides for data/rules/run.json keys. seed: RNG seed.
## all_content: every weapon, tome and item is in the pool (tests, debug).
## chest_every: open a paid chest every N seconds (sims).
## loadout: start with {"weapons": {id: level}, "tomes": {id: level},
##   "items": {id: stacks}} on top of the signature weapon (tests, stress).
## start_at: start the clock at this many seconds (tests, stress).
## first_run: force the first-run altar hint on or off.
## bot_goals: the bot walks to map objects (chests, pots, keys...).
## bot_boss_min: the bot walks to the altar from this minute (-1 = never).
## bot_portal: the bot takes the portal once it's open.
## no_spawns: the director spawns nothing (tests).
var options := {}
var db: GameData
var rules: Dictionary
var map_def: Dictionary
var char_def: Dictionary
var elite_rules: Dictionary
var rng := RandomNumberGenerator.new()
var stats: StatBlock
var director: Director
var bounds := Rect2()

var hp := 0.0
var shield := 0.0
var gold := 0.0
var level := 1
var xp := 0.0
var kills := 0
var elapsed := 0.0
## "live", "level_up", "choice", "paused" or "over".
var state := "live"
var won := false
var weapons: Array[Weapon] = []
var owned_weapons := {}  # id -> level
var owned_tomes := {}  # id -> level
var items: ItemSystem
var pool: ContentPool
var pending_levels := 0
var result := {}
## Facts for unlock challenges, summed per run (see stat_event).
var run_stats := {}
## What last hurt the player (enemy id), and why the run ended.
var last_damage_source := ""
var end_reason := ""
var boss: MegaMole
var boss_summoned := false
var boss_defeated := false
## Time the last _process (logic + render prep) took, for the stress test.
var last_frame_usec := 0
## With options.profile: microseconds per section of the last frame.
var profile_frame := {}
var _profiling := false
var _prof_t := 0

var map: MapLayout
var enemies: EnemySystem
var enemy_shots: EnemyShots
var gems: GemSystem
var projectiles: ProjectileSystem
var interactables: Interactables
var numbers: DamageNumbers
var fx: Fx
## Enemy telegraphs (red zones, charge lines). Never turned off.
var danger: Fx

var _pos := Vector2.ZERO
var _facing := Vector2.RIGHT
var _iframes := 0.0
var _shield_idle := 0.0
var _burn_t := 0.0
var _chest_t := 0.0
var _recycle_t := 0.0
## Run time (seconds) when the merchant next shows up.
var _merchant_at := INF
var _hint_done := false
var _swarm_hit := false
var _elites_since_key := 0
var _keys_dropped := 0
var _shrine_n := 0
var _pack_sizes := {}
var _hits := PackedInt32Array()
var _zap_hits := PackedInt32Array()
var _player_view: Node2D
var _weapon_view: Node2D
var _boss_view: Node2D
var _camera: Camera2D
var _particles: NodePool
var _reduce_fx := false
var _hud: Hud
var _joystick: ThumbStick
var _cards_panel: Control
var _card_buttons: Array[PixelButton] = []
var _cards: Array = []
var _choice_panel: Control
var _choice_title: Label
var _choice_buttons: Array[PixelButton] = []
var _choice_leave: PixelButton
var _choice := {}
var _over_panel: Control
var _over_text: Label
var _over_title: Label
var _pause_panel: Control


func _ready() -> void:
	options = next_options.duplicate(true)
	next_options = {}
	db = GameData.shared()
	rules = db.get_entry("rules", "run").duplicate(true)
	rules.merge(options.get("rules", {}), true)
	map_def = db.get_entry("maps", options.get("map", "suburbia"))
	char_def = db.get_entry("characters", options.get("character", "sir_loaf"))
	elite_rules = db.get_entry("rules", "elites")
	if options.has("seed"):
		rng.seed = int(options.seed)
	else:
		rng.randomize()

	bounds = Rect2(Vector2.ZERO, Vector2(map_def.size[0], map_def.size[1]))
	_pos = bounds.get_center()
	stats = StatBlock.new(char_def.stats)
	hp = stat("max_hp")
	shield = stat("shield")
	items = ItemSystem.new(self, db)
	if options.get("all_content", false):
		pool = ContentPool.new(db, {}, true)
	else:
		pool = ContentPool.from_save(db, get_node_or_null("/root/Save"))
	director = Director.new(map_def, int(rules.enemy_cap), float(rules.run_length_sec), rng, db.get_entry("rules", "bills"))
	for e: Dictionary in db.all("enemies"):
		if e.has("pack_size"):
			_pack_sizes[e.id] = e.pack_size
	_reduce_fx = _setting("reduce_effects", false)
	_profiling = options.get("profile", false)
	elapsed = float(options.get("start_at", 0.0))
	var m: Dictionary = map_def.get("merchant", {})
	if not m.is_empty():
		_merchant_at = float(m.get("first_sec", 120.0))

	_build_world()
	_build_ui()
	_give_weapon(char_def.signature_weapon)
	_apply_loadout(options.get("loadout", {}))
	_render()


func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	tick(delta)
	_render()
	_mark("render")
	last_frame_usec = Time.get_ticks_usec() - t0


## Profiling: time since the last mark goes to `section`.
func _mark(section: String) -> void:
	if not _profiling:
		return
	var now := Time.get_ticks_usec()
	profile_frame[section] = profile_frame.get(section, 0) + now - _prof_t
	_prof_t = now


## Advances the run by `delta` seconds (clamped to rules.max_dt).
func tick(delta: float) -> void:
	if state != "live":
		return
	delta = minf(delta, rules.max_dt)
	elapsed += delta
	var minute := elapsed / 60.0
	if _profiling:
		profile_frame.clear()
		_prof_t = Time.get_ticks_usec()

	if not options.get("no_spawns", false):
		for req: Dictionary in director.tick(delta, elapsed, enemies.count(), _pack_sizes, rng, stat("enemy_spawn_rate")):
			_spawn_group(req)
		_director_events()
	if options.get("stress", false):
		_stress_fill()
	_mark("spawn")

	var dir: Vector2 = _joystick.read()
	if options.get("stress", false):
		dir = Vector2.from_angle(elapsed * 0.8) * 0.4  # slow circle, keeps the horde on screen
	elif options.get("bot", false):
		dir = _bot_dir()
	if dir.length_squared() > 0.01:
		_facing = dir.normalized()
	_pos = map.move(_pos, dir * stat("move_speed") * delta, player_radius())
	hp = minf(hp + stat("regen") * delta, stat("max_hp"))
	_update_shield(delta)
	items.update(delta)
	_mark("player")

	enemies.ghost_speed_mult = director.bill_speed_mult()
	enemies.update(delta, _pos)
	_mark("enemies")
	if boss != null:
		boss.update(delta)
	_recycle_t -= delta
	if _recycle_t <= 0.0:
		_recycle_t = RECYCLE_EVERY
		_recycle_far_enemies()
	_mark("recycle")
	for w in weapons:
		w.update(delta, self)
	_mark("weapons")
	projectiles.update(delta, enemies)
	_mark("projectiles")
	enemy_shots.update(delta, _pos, player_radius(), _on_shot_hit)
	_tick_burns(delta)
	_contact_damage(delta)
	_mark("damage")
	if hp <= 0.0:
		# Before map objects run: a portal or merchant touched in the same
		# frame must not act on a dead player.
		_end("bills" if is_bill(last_damage_source) else "died")
		return

	var got := gems.update(delta, _pos, stat("pickup_range"))
	if got > 0.0:
		add_xp(got)
	_mark("gems")
	interactables.update(delta)
	_tick_merchant()
	_tick_hint(minute)
	_mark("map_objects")
	numbers.update(delta)
	fx.update(delta)
	danger.update(delta)
	_mark("fx")
	var every: float = options.get("chest_every", 0.0)
	if every > 0.0:
		_chest_t += delta
		if _chest_t >= every:
			_chest_t -= every
			open_chest("paid")

	if hp <= 0.0:
		_end("bills" if is_bill(last_damage_source) else "died")
	elif pending_levels > 0 and state == "live":
		_open_level_up()


func stat(name: String) -> float:
	return stats.get_value(name)


func player_pos() -> Vector2:
	return _pos


## Moves the player (tests, debug). Map objects see it on the next tick.
func teleport(at: Vector2) -> void:
	_pos = at


func player_radius() -> float:
	return char_def.radius


func facing_angle() -> float:
	return _facing.angle()


## Seconds left on the run timer; negative = time spent in the Final Swarm.
func seconds_left() -> float:
	return rules.run_length_sec - elapsed


func final_swarm() -> bool:
	return director.final_started


func is_bill(enemy_id: String) -> bool:
	return db.get_entry("enemies", enemy_id).get("role", "") == "ghost"


## XP needed to go from `lvl` to `lvl + 1`.
static func xp_needed(curve: Dictionary, lvl: int) -> float:
	return floorf(curve.base + curve.growth * (pow(lvl, curve.exponent) - 1.0))


func add_xp(amount: float) -> void:
	xp += amount * stat("xp_gain")
	var need := xp_needed(rules.xp_curve, level)
	while xp >= need:
		xp -= need
		level += 1
		pending_levels += 1
		on_level_up.emit(level)
		if items.listens("on_level_up"):
			items.emit("on_level_up", {"level": level, "pos": _pos})
		need = xp_needed(rules.xp_curve, level)


## Records a run fact for unlock challenges (phase 4 reads these).
func record(name: String, amount := 1.0) -> void:
	run_stats[name] = run_stats.get(name, 0.0) + amount
	stat_event.emit(name, amount)


## Damages an enemy. Weapons call this with their damage (player damage
## stat already applied) and their id as `source`. Rolls crits (or uses an
## Alarm Clock charge) and fires on_hit, then handles the kill.
## procs = false: item effect damage, which never crits and never fires
## on_hit (so effects can't trigger each other in a loop).
func hit_enemy(slot: int, amount: float, push: Vector2, source := "", procs := true) -> void:
	if not enemies.pool.is_alive(slot):
		return
	var crit := false
	if procs:
		crit = items.take_crit_charge() or rng.randf() < stat("crit_chance")
		if crit:
			amount *= stat("crit_damage")
	numbers.show_number(enemies.pos[slot], amount, crit)
	var died := enemies.hurt(slot, amount, push)
	if procs:
		on_hit.emit(slot, amount, crit, source)
		if items.listens("on_hit"):
			items.emit("on_hit", {"slot": slot, "pos": enemies.pos[slot], "elite": enemies.elite[slot] == 1, "source": source, "crit": crit})
	# An on_hit effect may already have killed it.
	if died and enemies.pool.is_alive(slot):
		_kill(slot, source)


## The one way the player takes damage: enemy contact, enemy shots,
## explosions, boss attacks, Overdue Bills. Applies i-frames, evasion, the
## character passive, armor and shield, then fires on_damaged (Whoopee
## Cushion and other items). contact = from touching an enemy (Rubber Boots).
## pierce = armor and shield don't help (Overdue Bills: the guaranteed end).
## Returns true if the hit landed.
func damage_player(amount: float, source: String, contact := false, pierce := false) -> bool:
	if state != "live" or _iframes > 0.0:
		return false
	_iframes = rules.player_iframes
	if rng.randf() < stat("evasion"):
		numbers.show_text(_pos, "MISS")
		return false
	var dmg := amount * Passives.damage_taken_mult(char_def.passive, elapsed / 60.0)
	if contact:
		dmg *= stat("contact_damage_taken")
	if not pierce:
		dmg = maxf(1.0, dmg - stat("armor"))
	_shield_idle = 0.0
	_swarm_hit = true
	last_damage_source = source
	if options.get("invincible", false):
		return true
	var absorbed := 0.0 if pierce else minf(shield, dmg)
	shield -= absorbed
	hp -= dmg - absorbed
	record("damage_taken", dmg - absorbed)
	on_damaged.emit(dmg - absorbed)
	if items.listens("on_damaged"):
		items.emit("on_damaged", {"amount": dmg - absorbed, "pos": _pos, "source": source})
	return true


## Sets an enemy burning (refreshes duration, keeps the stronger burn).
func burn_enemy(slot: int, dps: float, duration: float) -> void:
	if not enemies.pool.is_alive(slot):
		return
	enemies.burn_dps[slot] = maxf(enemies.burn_dps[slot], dps)
	enemies.burn_left[slot] = maxf(enemies.burn_left[slot], duration)


## Damage and push in a circle. For item effects and blast weapons.
func blast(at: Vector2, r: float, dmg: float, knockback: float, source: String, color := "PAPER", procs := false) -> void:
	enemies.query_circle(at, r, _hits)
	var hit := _hits.duplicate()
	for e in hit:
		var off := enemies.pos[e] - at
		hit_enemy(e, dmg, off / maxf(off.length(), 0.01) * knockback, source, procs)
	var c := Palette.index_of(color)
	fx.ring(at, r, c)
	if r >= 60.0:
		fx.disc(at, r, c)


## Lightning that jumps from `from` to the nearest enemy, then on to the
## nearest not yet hit, `jumps` times in total. `skip` = a slot to leave out
## of the first jump (the enemy that triggered it). Returns enemies hit.
func chain_zap(from: Vector2, dmg: float, jumps: int, reach: float, source: String, skip := -1, procs := false, color := "SKY") -> int:
	var hit := {}
	if skip >= 0:
		hit[skip] = true
	var at := from
	var n := 0
	var c := Palette.index_of(color)
	for j in jumps:
		var e := _nearest_not_in(at, reach, hit)
		if e < 0:
			break
		hit[e] = true
		var to := enemies.pos[e]
		fx.bolt(at, to, c)
		hit_enemy(e, dmg, Vector2.ZERO, source, procs)
		at = to
		n += 1
	return n


func _nearest_not_in(at: Vector2, reach: float, skip: Dictionary) -> int:
	enemies.query_circle(at, reach, _zap_hits)
	var best := -1
	var best_d := INF
	for e in _zap_hits:
		if skip.has(e) or not enemies.pool.is_alive(e):
			continue
		var d := at.distance_squared_to(enemies.pos[e])
		if d < best_d:
			best_d = d
			best = e
	return best


## Fires a projectile through the item hooks (Clone Machine). See
## ProjectileSystem for the shot keys. Returns the slot or -1.
func fire_shot(shot: Dictionary) -> int:
	var s := projectiles.fire(shot)
	if s >= 0:
		on_projectile.emit(shot)
		if items.listens("on_projectile"):
			items.emit("on_projectile", {"shot": shot, "pos": shot.pos})
	return s


## A copy of a shot, turned by up to `spread` radians. Doesn't fire hooks.
func duplicate_shot(shot: Dictionary, spread: float) -> void:
	var copy := shot.duplicate()
	copy.vel = Vector2(shot.vel).rotated(rng.randf_range(-spread, spread))
	projectiles.fire(copy)


## Weapons call this once per attack (via Weapon.attacked()).
func weapon_attacked(weapon_id: String) -> void:
	on_attack.emit(weapon_id)
	if items.listens("on_attack"):
		items.emit("on_attack", {"weapon": weapon_id, "pos": _pos})


func add_gold(amount: float) -> void:
	gold += amount * stat("gold_gain")


func spend_gold(amount: float) -> void:
	gold = maxf(0.0, gold - amount)


func heal(amount: float) -> void:
	hp = minf(hp + amount, stat("max_hp"))


## Short message on the HUD (item pickups, boosts).
func toast(text: String, color := "PAPER", seconds := 1.6) -> void:
	_hud.toast(text, Palette.index_of(color), seconds)


## Adds one stack of an item (chest, merchant, tests).
func give_item(id: String) -> void:
	var before := stat("max_hp")
	var shield_before := stat("shield")
	items.add(id)
	hp += maxf(0.0, stat("max_hp") - before)
	shield += maxf(0.0, stat("shield") - shield_before)
	if items.count(id) >= 3:
		run_stats["max_item_copies"] = maxf(run_stats.get("max_item_copies", 0.0), items.count(id))


## Opens a chest of `kind` ("paid", "elite", "boss"): rolls an item with
## the player's luck and gives it. Returns the item id ("" = nothing left
## to give; the chest pays out gold instead). Map chests, elite drops and the
## boss chest all come through here.
func open_chest(kind: String) -> String:
	var id := Loot.roll(rng, db, kind, stat("luck"), items.stacks, pool)
	if id == "":
		add_gold(db.get_entry("rules", "loot").get("empty_chest_gold", 0.0))
		toast("+GOLD", "GOLD")
	else:
		give_item(id)
		var def := db.get_entry("items", id)
		var loot := db.get_entry("rules", "loot")
		toast(def.name, loot.rarity_colors[def.rarity])
		record("chests_opened")
		if kind == "paid" and def.rarity == "epic":
			record("epic_from_paid_chest")
	on_chest_opened.emit(kind, id)
	if items.listens("on_chest_opened"):
		items.emit("on_chest_opened", {"kind": kind, "item": id, "pos": _pos})
	return id


## Shrines call this when they activate.
func shrine_activated(shrine_id: String) -> void:
	record("shrines_activated")
	on_shrine_activated.emit(shrine_id)
	if items.listens("on_shrine_activated"):
		items.emit("on_shrine_activated", {"shrine": shrine_id, "pos": _pos})


func enemies_on_screen() -> int:
	var view := view_rect()
	var n := 0
	for s in enemies.pool.active:
		if view.has_point(enemies.pos[s]):
			n += 1
	return n


func apply_card(card: Dictionary) -> void:
	match card.kind:
		"weapon":
			if card.is_new:
				_give_weapon(card.id)
			else:
				for w in weapons:
					if w.def.id == card.id:
						w.level = card.level
				owned_weapons[card.id] = card.level
		"tome":
			var before := stat("max_hp")
			var shield_before := stat("shield")
			owned_tomes[card.id] = card.level
			stats.apply_modifiers("tome:" + card.id, card.def.modifiers_per_level, card.level)
			hp += maxf(0.0, stat("max_hp") - before)
			shield += maxf(0.0, stat("shield") - shield_before)
		"fallback":
			hp = minf(hp + card.def.get("heal", 0.0), stat("max_hp"))


## Spawns one enemy by id at `at` (boss summons, splits). Uses the reserve
## slots above the cap, so it works even with a full horde. Returns the slot.
func spawn_enemy(id: String, at: Vector2) -> int:
	var type_id: int = enemies.type_index[id]
	var def: Dictionary = enemies.types[type_id]
	var growth: float = 1.0 + def.get("hp_growth_per_minute", 0.0) * minf(elapsed, rules.run_length_sec) / 60.0
	return enemies.spawn(type_id, at.clamp(bounds.position, bounds.end), growth * director.hp_mult() * stat("enemy_hp"), director.damage_mult() * stat("enemy_damage"), director.speed_mult(), true)


## The altar calls this: Mega Mole appears next to it. Returns false if it
## couldn't (no free enemy slot), so the altar can be used again.
func summon_boss(id: String, at: Vector2) -> bool:
	if boss_summoned:
		return false
	var slot := spawn_enemy(id, at + Vector2(0, -24))
	if slot < 0:
		toast("THE ALTAR FIZZLES. TRY AGAIN", "RED")
		return false
	boss_summoned = true
	boss = MegaMole.new(self, slot)
	interactables.altar_pulse = false
	record("boss_summoned")
	_hud.banner(String(enemies.types[enemies.type_of[slot]].name) + "!", Palette.RED)
	fx.ring(at, 30.0, Palette.RED)
	return true


## The portal calls this: the run ends as an escape.
func escape() -> void:
	if state == "live":
		_end("portal")


## A free (not solid) point near `at`, for drops and rewards.
func free_spot_near(at: Vector2) -> Vector2:
	for i in 24:
		var p := (at + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 8.0 + i * 2.0)).clamp(bounds.position + Vector2(8, 8), bounds.end - Vector2(8, 8))
		if map.is_area_free(p, 6.0):
			return p.round()
	return at.clamp(bounds.position + Vector2(8, 8), bounds.end - Vector2(8, 8)).round()


# --- Run flow -------------------------------------------------------------

func _give_weapon(id: String) -> void:
	var def := db.get_entry("weapons", id)
	if def.is_empty():
		push_error("Run: weapon '%s' not found" % id)
		return
	weapons.append(Weapon.create(def))
	owned_weapons[id] = 1


func _apply_loadout(lo: Dictionary) -> void:
	var w: Dictionary = lo.get("weapons", {})
	for id: String in w:
		if not owned_weapons.has(id):
			_give_weapon(id)
		apply_card({"kind": "weapon", "id": id, "level": int(w[id]), "is_new": false, "def": db.get_entry("weapons", id)})
	var t: Dictionary = lo.get("tomes", {})
	for id: String in t:
		apply_card({"kind": "tome", "id": id, "level": int(t[id]), "is_new": false, "def": db.get_entry("tomes", id)})
	var it: Dictionary = lo.get("items", {})
	for id: String in it:
		for k in int(it[id]):
			give_item(id)


func _spawn_group(req: Dictionary) -> void:
	var type_id: int = enemies.type_index[req.enemy]
	var def: Dictionary = enemies.types[type_id]
	var growth: float = 1.0 + def.get("hp_growth_per_minute", 0.0) * minf(elapsed, rules.run_length_sec) / 60.0
	var fly: bool = def.get("flying", false)
	var base := _spawn_point(fly)
	var spread: float = def.get("pack_spread", 0.0)
	for i in req.count:
		var at := base
		if req.grouped:
			at += Vector2(rng.randf_range(-spread, spread), rng.randf_range(-spread, spread))
		var s := enemies.spawn(type_id, at.clamp(bounds.position, bounds.end), growth * director.hp_mult() * stat("enemy_hp"), director.damage_mult() * stat("enemy_damage"), director.speed_mult(), req.reserve)
		if s >= 0 and req.elite != "":
			enemies.make_elite(s, req.elite, elite_rules)
		elif s < 0 and is_bill(req.enemy):
			director.refund_bill()


## An off-screen spawn point. Walking enemies don't start inside a house.
func _spawn_point(fly: bool) -> Vector2:
	var p := Spawner.edge_point(rng, _pos, _half_view() + SPAWN_MARGIN, bounds)
	if fly:
		return p
	for i in 6:
		if not map.is_blocked_circle(p, 4.0):
			return p
		p = Spawner.edge_point(rng, _pos, _half_view() + SPAWN_MARGIN, bounds)
	return p


func _director_events() -> void:
	for ev in director.events:
		match ev:
			"swarm_warning":
				_hud.banner("SWARM INCOMING!", Palette.RED)
			"swarm_start":
				_swarm_hit = false
				record("swarms_started")
			"swarm_end":
				if not _swarm_hit and hp > 0.0:
					record("swarm_survived_no_damage")
				toast("SWARM OVER", "LIME")
			"final_start":
				_hud.banner("FINAL SWARM!", Palette.PINK)
				record("final_swarm_reached")
			"bills_start":
				_hud.banner("BILLS ARE DUE!", Palette.PAPER)
			"bills_faster":
				toast("THE BILLS GROW IMPATIENT", "PAPER")


## Stress test: keep the enemy count at the cap and every enemy on screen.
## New and stray enemies are placed inside the view, away from the player.
## With stress_final the mix is the Final Swarm's.
func _stress_fill() -> void:
	var view := view_rect().intersection(bounds).grow(-4.0)
	for s in enemies.pool.active:
		if not view.has_point(enemies.pos[s]) and s != _boss_slot():
			enemies.move_to(s, _stress_point(view))
	var mix := []
	for e: Dictionary in enemies.types:
		if not e.role in ["ghost", "boss"]:
			mix.append(enemies.type_index[e.id])
	var i := 0
	while enemies.count() < int(rules.enemy_cap):
		var s := enemies.spawn(mix[i % mix.size()], _stress_point(view), director.hp_mult(), director.damage_mult(), director.speed_mult())
		i += 1
		if s < 0:
			break


func _stress_point(view: Rect2) -> Vector2:
	while true:
		var at := Vector2(rng.randf_range(view.position.x, view.end.x), rng.randf_range(view.position.y, view.end.y))
		if at.distance_squared_to(_pos) >= 40.0 * 40.0:
			return at
	return view.position


func _boss_slot() -> int:
	return boss.slot if boss != null and boss.alive() else -1


## Enemies left far behind are moved back near the player instead of being
## culled, so the horde keeps up and the count stays meaningful. So are
## walkers wedged in a pocket of the map (no progress for STALL_SEC), as long
## as the player can't see the jump.
const STALL_SEC := 3.0


func _recycle_far_enemies() -> void:
	var far: float = map_def.get("despawn_distance", 260.0)
	var far2 := far * far
	var b := _boss_slot()
	var view := view_rect().grow(8.0)
	for s in enemies.pool.active:
		if s == b:
			continue
		var wedged := enemies.stalled[s] > STALL_SEC and not view.has_point(enemies.pos[s])
		if wedged or enemies.pos[s].distance_squared_to(_pos) > far2:
			enemies.move_to(s, _spawn_point(enemies.flags[s] & (EnemySystem.F_FLY | EnemySystem.F_GHOST) != 0))


## Half the visible area in world pixels. The view is at least 180x320 and
## grows on taller or wider screens (stretch aspect "expand").
func _half_view() -> Vector2:
	return get_viewport_rect().size / 2.0


## The visible area in world pixels (centered on the player).
func view_rect() -> Rect2:
	return Rect2(_pos - _half_view(), _half_view() * 2.0)


## Touching enemies hurts: the worst one touching counts (one hit per
## i-frame window). Ghosts aren't in the grid, so they're checked by list.
func _contact_damage(delta: float) -> void:
	if _iframes > 0.0:
		_iframes -= delta
		return
	var r := player_radius()
	enemies.query_circle(_pos, r, _hits)
	var worst := 0.0
	var src := ""
	var pierce := false
	for s in _hits:
		# The grid is from this frame's update; a weapon may have killed it since.
		if not enemies.pool.is_alive(s):
			continue
		if enemies.damage[s] > worst:
			worst = enemies.damage[s]
			src = enemies.types[enemies.type_of[s]].id
	for s in enemies.ghosts:
		var rr := r + enemies.radius[s]
		if enemies.pos[s].distance_squared_to(_pos) <= rr * rr:
			var def: Dictionary = enemies.types[enemies.type_of[s]]
			var bill := stat("max_hp") * float(def.get("damage_pct_max_hp", 0.0)) * director.bill_damage_mult() + enemies.damage[s]
			if bill > worst:
				worst = bill
				src = def.id
				pierce = def.get("ignores_defense", false)
	if src != "":
		damage_player(worst, src, true, pierce)


func _on_shot_hit(dmg: float, source: String) -> void:
	damage_player(dmg, source)


func _on_enemy_event(kind: int, slot: int, dir: Vector2) -> void:
	var def: Dictionary = enemies.types[enemies.type_of[slot]]
	var at := enemies.pos[slot]
	var power := enemies.damage[slot] / maxf(float(def.damage), 0.01)
	match kind:
		EnemySystem.EV_SHOOT:
			var sh: Dictionary = def.shot
			enemy_shots.fire(at + dir * enemies.radius[slot], dir * float(sh.speed), float(sh.damage) * power, float(sh.radius), float(sh.life), "bullet", def.id)
		EnemySystem.EV_SWELL:
			var ex: Dictionary = def.explode
			danger.disc(at, float(ex.radius), Palette.RED, float(ex.fuse))
			danger.ring(at, float(ex.radius), Palette.RED, float(ex.fuse))
		EnemySystem.EV_EXPLODE:
			var ex: Dictionary = def.explode
			fx.ring(at, float(ex.radius), Palette.ORANGE)
			fx.disc(at, float(ex.radius), Palette.ORANGE)
			var was_elite := enemies.elite[slot] == 1
			var splits := enemies.split[slot]
			enemies.remove(slot)
			if was_elite:
				# Not a kill, but the elite still drops its chest and splits.
				_elite_killed(def.id, at, splits, false)
			if at.distance_to(_pos) <= float(ex.radius) + player_radius():
				damage_player(float(ex.damage) * power, def.id)
		EnemySystem.EV_WINDUP:
			var c: Dictionary = def.charge
			var reach := float(c.speed) * float(c.time)
			danger.line(at, at + dir * reach, Palette.RED, float(c.windup))


## Shield (Tin Foil Hat): refills after rules.shield.delay seconds without
## being hit, at refill_per_sec of the max per second.
func _update_shield(delta: float) -> void:
	var top := stat("shield")
	if shield > top:
		shield = top
	if top <= 0.0:
		return
	_shield_idle += delta
	if _shield_idle >= rules.shield.delay:
		shield = minf(top, shield + top * rules.shield.refill_per_sec * delta)


## Burning enemies take their damage every rules.burn_tick seconds.
func _tick_burns(delta: float) -> void:
	_burn_t += delta
	var step: float = rules.burn_tick
	if _burn_t < step:
		return
	_burn_t -= step
	var i := enemies.pool.active.size() - 1
	while i >= 0:
		var s := enemies.pool.active[i]
		i -= 1
		if enemies.burn_left[s] > 0.0:
			var t := minf(step, enemies.burn_left[s])
			enemies.burn_left[s] -= step
			hit_enemy(s, enemies.burn_dps[s] * t, Vector2.ZERO, "burn", false)
			if enemies.pool.is_alive(s) and enemies.burn_left[s] <= 0.0:
				enemies.burn_dps[s] = 0.0


func _kill(slot: int, source := "") -> void:
	var type_id := enemies.type_of[slot]
	var def: Dictionary = enemies.types[type_id]
	var at := enemies.pos[slot]
	var elite := enemies.elite[slot] == 1
	var is_boss := boss != null and slot == boss.slot
	var xp_val: float = def.xp * (float(elite_rules.get("xp_mult", 1.0)) if elite else 1.0)
	if xp_val > 0.0:
		gems.drop(at, xp_val)
	if rng.randf() < rules.gold.kill_chance:
		add_gold(rules.gold.kill_amount)
	if not _reduce_fx:
		var p: CPUParticles2D = _particles.take()
		p.position = at.round()
		var tex := PlaceholderArt.texture("dot", Palette.index_of(def.color))
		if p.texture != tex:
			p.texture = tex
		p.restart()
	kills += 1
	var splits := enemies.split[slot]
	on_kill.emit(slot, def.id, source, elite)
	if items.listens("on_kill"):
		items.emit("on_kill", {"slot": slot, "pos": at, "elite": elite, "source": source, "enemy": def.id})
	enemies.remove(slot)
	if elite:
		_elite_killed(def.id, at, splits)
	if is_boss:
		_boss_killed(at)


## defeated = false: it blew itself up (an elite Bloater). It still drops its
## chest (and maybe the key) and splits, but doesn't count as a defeat.
func _elite_killed(id: String, at: Vector2, splits: int, defeated := true) -> void:
	if defeated:
		record("elites_killed")
	interactables.add(elite_rules.get("chest", "elite_chest"), free_spot_near(at))
	var walker: bool = not enemies.types[enemies.type_index[id]].get("flying", false)
	for i in splits:
		var to := at + Vector2.from_angle(TAU * i / splits) * 6.0
		# Walking copies never start inside a wall.
		spawn_enemy(id, free_spot_near(to) if walker and not map.is_area_free(to, 3.0) else to)
	# The cage key: a chance per elite, guaranteed after `pity` elites without
	# one. One key at a time, and only while the map has a closed cage.
	var key: Dictionary = elite_rules.get("key", {})
	if key.is_empty():
		return
	var cage := interactables.find("pigeon_cage")
	if cage.is_empty() or cage.used or interactables.has_key or interactables.count_of(key.drop) > 0:
		return
	_elites_since_key += 1
	if rng.randf() < float(key.chance) or _elites_since_key >= int(key.pity):
		_elites_since_key = 0
		_keys_dropped += 1
		interactables.add(key.drop, free_spot_near(at + Vector2(8, 0)))
		toast("AN ELITE DROPPED A KEY!", "GOLD")


func _boss_killed(at: Vector2) -> void:
	boss_defeated = true
	var frac := hp / stat("max_hp")
	record("boss_defeated")
	run_stats["boss_defeated_at"] = elapsed
	run_stats["boss_defeated_hp_frac"] = frac
	if final_swarm():
		record("boss_defeated_in_final_swarm")
	interactables.add("boss_chest", free_spot_near(at))
	interactables.add("portal", free_spot_near(at + Vector2(0, 20)))
	enemy_shots.clear()
	_hud.banner("PORTAL OPEN!", Palette.PURPLE)
	boss = null


func _tick_merchant() -> void:
	if elapsed < _merchant_at:
		return
	var m: Dictionary = map_def.merchant
	_merchant_at = elapsed + float(m.get("every_sec", 150.0))
	if interactables.count_of(m.id) > 0:
		return
	var at := _pos
	for i in 30:
		var p := _pos + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(60.0, 110.0)
		if bounds.grow(-12.0).has_point(p) and map.is_area_free(p, 10.0):
			at = p
			break
	interactables.add(m.id, at)
	toast("A MERCHANT APPEARED!", "BUTTER", 2.5)


## First run: if the boss isn't summoned by the map's hint minute, the
## altar arrow pulses and a short hint shows.
func _tick_hint(minute: float) -> void:
	if _hint_done or boss_summoned:
		return
	var at: float = map_def.get("boss", {}).get("hint_at_min", 5.0)
	if minute < at:
		return
	_hint_done = true
	var first: bool = options.get("first_run", _first_run())
	if first:
		interactables.altar_pulse = true
		toast("STAND ON THE ALTAR TO CALL THE BOSS", "RED", 4.0)


func _first_run() -> bool:
	var save := get_node_or_null("/root/Save")
	return save != null and int(save.data.get("runs_played", 0)) == 0


func _open_level_up() -> void:
	_cards = LevelUpCards.pick(rng, db, owned_weapons, owned_tomes, rules, pool)
	if options.get("auto_cards", false):
		pending_levels -= 1
		if not _cards.is_empty():
			apply_card(_cards[0])
		return
	state = "level_up"
	_joystick.release()
	get_tree().paused = true
	for i in _card_buttons.size():
		var b := _card_buttons[i]
		b.visible = i < _cards.size()
		if b.visible:
			var card: Dictionary = _cards[i]
			b.label = "\n".join(LevelUpCards.describe(card))
			b.face = {"weapon": Palette.GOLD, "tome": Palette.SKY}.get(card.kind, Palette.MIST)
	_cards_panel.show()


func _on_card(i: int) -> void:
	if state != "level_up" or i >= _cards.size():
		return
	apply_card(_cards[i])
	pending_levels -= 1
	_cards_panel.hide()
	if pending_levels > 0:
		_open_level_up()
		return
	state = "live"
	get_tree().paused = false


# --- Shrine and merchant choices --------------------------------------------

## Charge shrine: pick one of `offer` stat bonuses from the shrine's data.
func open_shrine_choice(def: Dictionary) -> void:
	var choices: Array = def.choices.duplicate()
	var offer := []
	for i in mini(int(def.get("offer", 3)), choices.size()):
		offer.append(choices.pop_at(rng.randi_range(0, choices.size() - 1)))
	_shrine_n += 1
	var src := "shrine:%d" % _shrine_n
	var opts := []
	for c: Dictionary in offer:
		opts.append({"label": c.desc, "face": Palette.SKY, "enabled": true})
	_show_choice("PICK A BONUS", opts, "", func(i: int) -> bool:
		var c: Dictionary = offer[i]
		var before := stat("max_hp")
		stats.set_modifier(c.stat, src, float(c.get("flat", 0.0)), float(c.get("pct", 0.0)))
		heal(maxf(0.0, stat("max_hp") - before))
		toast(c.desc, "SKY")
		return true)


## Merchant: buy items for gold, then leave. Touch it again to come back.
func open_merchant(o: Dictionary) -> void:
	var loot := db.get_entry("rules", "loot")
	var refresh := func() -> Array:
		var opts := []
		for st: Dictionary in o.stock:
			var item := db.get_entry("items", st.item)
			var label := "%s\n%s\n%s" % [item.name, loot.rarity_names[item.rarity], "SOLD" if st.sold else "G %d" % st.price]
			var ok := _can_hold(st.item)
			if not st.sold and not ok:
				label = "%s\n%s\nYOU HAVE ONE" % [item.name, loot.rarity_names[item.rarity]]
			opts.append({"label": label, "face": Palette.index_of(loot.rarity_colors[item.rarity]), "enabled": not st.sold and ok and gold >= st.price})
		return opts
	_show_choice("MERCHANT", refresh.call(), "LEAVE", func(i: int) -> bool:
		var st: Dictionary = o.stock[i]
		if st.sold or gold < st.price or not _can_hold(st.item):
			return false
		spend_gold(st.price)
		st.sold = true
		give_item(st.item)
		record("items_bought")
		toast(db.get_entry("items", st.item).name, loot.rarity_colors[db.get_entry("items", st.item).rarity])
		_set_choice_options(refresh.call())
		return false)


## Shows the choice panel. on_pick(i) returns true to close the panel.
## leave = label of a close button ("" = none). Bots pick automatically.
func _show_choice(title: String, opts: Array, leave: String, on_pick: Callable) -> void:
	_choice = {"opts": opts, "on_pick": on_pick, "leave": leave}
	if options.get("auto_cards", false):
		# Take the first enabled option; at a shop, buy all it can afford.
		for i in opts.size():
			if _choice.opts[i].enabled and on_pick.call(i):
				break
			if leave == "" and _choice.opts[i].enabled:
				break
		_choice = {}
		return
	state = "choice"
	_joystick.release()
	get_tree().paused = true
	_choice_title.text = title
	_set_choice_options(opts)
	_choice_leave.visible = leave != ""
	_choice_leave.label = leave
	_choice_panel.show()


func _set_choice_options(opts: Array) -> void:
	_choice.opts = opts
	for i in _choice_buttons.size():
		var b := _choice_buttons[i]
		b.visible = i < opts.size()
		if b.visible:
			b.label = opts[i].label
			b.face = opts[i].face if opts[i].enabled else Palette.GRAY
			b.disabled = not opts[i].enabled


func _on_choice(i: int) -> void:
	if state != "choice" or i >= _choice.opts.size():
		return
	if _choice.on_pick.call(i):
		_close_choice()


func _close_choice() -> void:
	if state != "choice":
		return
	_choice_panel.hide()
	_choice = {}
	state = "live"
	get_tree().paused = false


## True if the item can still be given: unique items (legendaries) and the
## legendary-per-run limit, as for chests (Loot.available).
func _can_hold(id: String) -> bool:
	var def := db.get_entry("items", id)
	return Loot.available(db, items.stacks, pool).get(def.get("rarity", ""), []).has(id)


## reason: "died", "bills" (Overdue Bills, Final Swarm), "portal", "gave_up".
func _end(reason: String) -> void:
	if state == "over":
		return  # one end per run: never two results, never two saves
	state = "over"
	_choice = {}
	_choice_panel.hide()
	_cards_panel.hide()
	_pause_panel.hide()
	end_reason = reason
	var reached_final := final_swarm()
	won = reason == "portal" or reached_final
	gems.pull_all()
	if reached_final:
		run_stats["final_swarm_seconds"] = director.final_time
	var c: Dictionary = rules.coins
	var mult := (1.0 if won else float(c.death_multiplier)) * director.coin_mult()
	var played := minf(elapsed, rules.run_length_sec) + director.final_time
	var coins := floori((c.per_minute * played / 60.0 + c.per_kill * kills) * mult)
	result = {"won": won, "reason": reason, "escaped": reason == "portal", "time": elapsed, "level": level,
		"kills": kills, "coins": coins, "coin_mult": snappedf(director.coin_mult(), 0.01), "gold": floori(gold),
		"final_swarm_seconds": director.final_time, "boss_defeated": boss_defeated, "stats": run_stats.duplicate()}
	if not options.get("no_save", false):
		var save := get_node_or_null("/root/Save")
		if save != null:
			save.data.runs_played += 1
			save.data.coins += coins
			save.save_game()
	run_ended.emit(result)
	if options.get("bot", false) and options.get("auto_cards", false):
		return  # headless sims read `result`; no screen to show
	_joystick.release()
	get_tree().paused = true
	var title := "TOASTED!"
	var color := Palette.RED
	match reason:
		"portal":
			title = "ESCAPED!"
			color = Palette.BUTTER
		"bills":
			title = "OVERDUE!"
			color = Palette.PINK
		"gave_up":
			title = "GAVE UP"
		_:
			if reached_final:
				title = "SWARMED!"
				color = Palette.PINK
	_over_title.text = title
	_over_title.add_theme_color_override("font_color", Palette.color(color))
	var sec := int(minf(elapsed, rules.run_length_sec))
	var lines := "TIME  %d:%02d\nLEVEL  %d\nKO  %d" % [sec / 60, sec % 60, level, kills]
	if reached_final:
		var f := int(director.final_time)
		lines += "\nFINAL SWARM  +%d:%02d" % [f / 60, f % 60]
	lines += "\nCOINS  +%d" % coins
	if mult > 1.0:
		lines += "  X%.1f" % director.coin_mult()
	_over_text.text = lines
	_over_panel.show()


func _pause(on: bool) -> void:
	if on and state == "live":
		state = "paused"
		_joystick.release()
		get_tree().paused = true
		_pause_panel.show()
	elif not on and state == "paused":
		state = "live"
		get_tree().paused = false
		_pause_panel.hide()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if state == "over":
				_to_menu.call_deferred()
			else:
				_pause(state == "live")
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if not options.get("bot", false):
				_pause(true)
		NOTIFICATION_EXIT_TREE:
			# Never leave the tree paused for the next scene.
			if is_inside_tree():
				get_tree().paused = false


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and event is InputEventKey and (event.physical_keycode == KEY_ESCAPE or event.physical_keycode == KEY_P):
		_pause(state == "live")


## Simple bot: dodge enemies that get closer than the swing reach, and with
## bot_goals walk to a goal otherwise: the altar (from bot_boss_min), the portal (bot_portal),
## chests it can open, keys, the cage with a key, nearby pots, then the map
## center. Used for sims and tests, not balance truth.
func _bot_dir() -> Vector2:
	var away := Vector2.ZERO
	enemies.query_circle(_pos, 22.0, _hits)
	for s in _hits:
		var off := _pos - enemies.pos[s]
		away += off / maxf(off.length_squared(), 1.0)
	for s in enemies.ghosts:
		var off := _pos - enemies.pos[s]
		if off.length_squared() < 40.0 * 40.0:
			away += off / maxf(off.length_squared(), 1.0) * 2.0
	# Step sideways out of the path of incoming shots.
	for s in enemy_shots.pool.active:
		var off := _pos - enemy_shots.pos[s]
		if off.length_squared() < 30.0 * 30.0 and off.dot(enemy_shots.vel[s]) > 0.0:
			var side := enemy_shots.vel[s].orthogonal().normalized()
			away += side * signf(side.dot(off) + 0.01) / maxf(off.length(), 4.0)
	var goal := _bot_goal() if options.get("bot_goals", false) else Vector2(-INF, -INF)
	var pull := Vector2.ZERO
	if goal.x > -INF:
		pull = _route_dir(goal) * 0.08
	else:
		pull = (bounds.get_center() - _pos) * 0.0004
	var wander := Vector2.from_angle(elapsed * 0.35) * 0.02
	var d := away * 8.0 + pull + wander
	if d.length() <= 0.01:
		return Vector2.ZERO
	return _bot_walkable(d.normalized())


## Of 16 directions, the one closest to `want` that the bot can really walk
## (not into a wall or the map edge), so it slides out of corners instead of
## pressing into them.
func _bot_walkable(want: Vector2) -> Vector2:
	var step := stat("move_speed") * 0.25
	var best := want
	var best_score := -INF
	for i in 16:
		var dir := Vector2.from_angle(TAU * i / 16.0)
		var moved := map.move(_pos, dir * step, player_radius()).distance_to(_pos) / step
		if moved < 0.6:
			continue
		var score := dir.dot(want) + moved * 0.2
		if score > best_score:
			best_score = score
			best = dir
	return best


## Bot routing: a breadth-first distance field over the map's solid-cell grid
## from the goal, rebuilt when the goal moves or every 2 s. The bot steps to
## the neighbouring cell closest to the goal, so it walks round houses.
var _route := PackedInt32Array()
var _route_goal := -1
var _route_t := 0.0
## Cells the player's whole box fits in (built once): routing through a
## gap narrower than the player got the bot stuck between a house and a car.
var _clear := PackedByteArray()


func _route_dir(goal: Vector2) -> Vector2:
	var cols := map.cols
	var rows := map.rows
	if _clear.is_empty():
		_clear.resize(cols * rows)
		for c in cols * rows:
			var center := Vector2((c % cols + 0.5) * MapLayout.CELL, (c / cols + 0.5) * MapLayout.CELL)
			_clear[c] = 1 if map.is_area_free(center, player_radius() + 1.0) else 0
	var gc := clampi(int(goal.y / MapLayout.CELL), 0, rows - 1) * cols + clampi(int(goal.x / MapLayout.CELL), 0, cols - 1)
	if gc != _route_goal or elapsed - _route_t > 2.0:
		_route_goal = gc
		_route_t = elapsed
		_route.resize(cols * rows)
		_route.fill(-1)
		_route[gc] = 0
		var queue := PackedInt32Array([gc])
		var head := 0
		while head < queue.size():
			var c := queue[head]
			head += 1
			var cx := c % cols
			var cy := c / cols
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := cx + d.x
				var ny := cy + d.y
				if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
					continue
				var n := ny * cols + nx
				if _route[n] < 0 and _clear[n] == 1:
					_route[n] = _route[c] + 1
					queue.append(n)
	var px := clampi(int(_pos.x / MapLayout.CELL), 0, cols - 1)
	var py := clampi(int(_pos.y / MapLayout.CELL), 0, rows - 1)
	var here := _route[py * cols + px]
	if here <= 0:
		var to := goal - _pos
		return to.normalized() if to.length() > 1.0 else Vector2.ZERO
	var best := Vector2.ZERO
	var best_d := here
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var nx := px + dx
			var ny := py + dy
			if (dx == 0 and dy == 0) or nx < 0 or ny < 0 or nx >= cols or ny >= rows:
				continue
			# Diagonal steps only when both side cells are open (no corner cutting).
			if dx != 0 and dy != 0 and (_clear[py * cols + nx] == 0 or _clear[ny * cols + px] == 0):
				continue
			var v := _route[ny * cols + nx]
			if v >= 0 and v < best_d:
				best_d = v
				best = (Vector2(nx + 0.5, ny + 0.5) * MapLayout.CELL - _pos).normalized()
	return best


func _bot_goal() -> Vector2:
	var best := Vector2(-INF, -INF)
	var best_d := INF
	var boss_min: float = options.get("bot_boss_min", -1.0)
	for o in interactables.list:
		if o.used:
			continue
		var want := false
		match o.def.behavior:
			"altar": want = boss_min >= 0.0 and elapsed / 60.0 >= boss_min
			"portal": want = options.get("bot_portal", false)
			"free_chest", "key": want = true
			"cage": want = interactables.has_key
			"paid_chest": want = gold >= interactables.paid_price(o.def)
			"pot": want = o.pos.distance_to(_pos) < 90.0
			"charge_shrine": want = o.pos.distance_to(_pos) < 120.0
		if not want:
			continue
		var d: float = o.pos.distance_squared_to(_pos)
		# The altar and portal come first.
		if o.def.behavior in ["altar", "portal"]:
			d *= 0.01
		if d < best_d:
			best_d = d
			best = o.pos
	return best


func _setting(key: String, fallback: Variant) -> Variant:
	var save := get_node_or_null("/root/Save")
	return save.get_setting(key) if save != null else fallback


# --- Drawing --------------------------------------------------------------

func _render() -> void:
	enemies.render()
	gems.render()
	projectiles.render()
	enemy_shots.render()
	_player_view.position = _pos.round()
	_player_view.queue_redraw()
	_weapon_view.queue_redraw()
	if boss != null or _boss_view.visible:
		_boss_view.queue_redraw()
	_camera.position = _pos.round()
	_hud.hp = hp
	_hud.hp_max = stat("max_hp")
	_hud.shield = shield
	_hud.gold = floori(gold)
	_hud.xp = xp
	_hud.xp_need = xp_needed(rules.xp_curve, level)
	_hud.boss_frac = boss.hp_frac() if boss != null and boss.alive() else -1.0
	_hud.boss_name = "MEGA MOLE" if boss == null else String(enemies.types[enemies.type_of[boss.slot]].name)
	_hud.coin_mult = director.coin_mult()
	_hud.challenge = interactables.challenge_status()
	_hud.has_key = interactables.has_key
	_hud.view_center = _pos.round()
	_hud.arrows = _arrow_targets()
	_hud.set_values(level, seconds_left(), kills)


func _arrow_targets() -> Array:
	var view := view_rect().grow(-2.0)
	var out := interactables.arrow_targets(view)
	for s in enemies.elites:
		if view.has_point(enemies.pos[s]):
			continue
		out.append({"pos": enemies.pos[s], "color": enemies.outline[s], "pulse": false})
	if boss != null and boss.alive():
		out.append({"pos": enemies.pos[boss.slot], "color": Palette.RED, "pulse": true})
	return out


func _build_world() -> void:
	map = MapLayout.new()
	map.setup(map_def)
	add_child(map)
	interactables = Interactables.new()
	interactables.setup(self, db)
	add_child(interactables)
	_boss_view = Node2D.new()
	_boss_view.draw.connect(func() -> void:
		if boss != null:
			boss.draw(_boss_view))
	add_child(_boss_view)

	gems = GemSystem.new()
	gems.setup(rules)
	add_child(gems)
	enemies = EnemySystem.new()
	enemies.setup(db.all("enemies"), int(rules.enemy_cap), bounds, int(rules.get("enemy_reserve", 48)))
	enemies.map = map
	enemies.event_fn = _on_enemy_event
	enemies.rng.seed = rng.seed ^ 0x5eed
	add_child(enemies)
	projectiles = ProjectileSystem.new()
	projectiles.setup(256)
	projectiles.hit_fn = hit_enemy
	add_child(projectiles)
	enemy_shots = EnemyShots.new()
	enemy_shots.setup(int(rules.get("enemy_shots", 160)))
	add_child(enemy_shots)

	_player_view = Node2D.new()
	_player_view.draw.connect(_draw_player)
	add_child(_player_view)
	_weapon_view = Node2D.new()
	_weapon_view.draw.connect(func() -> void:
		for w in weapons:
			w.draw(_weapon_view, _pos))
	add_child(_weapon_view)

	var particle_root := Node2D.new()
	add_child(particle_root)
	_particles = NodePool.new(particle_root, PARTICLES, _make_particles)
	fx = Fx.new()
	fx.enabled = not _reduce_fx
	add_child(fx)
	danger = Fx.new()
	add_child(danger)
	numbers = DamageNumbers.new()
	numbers.enabled = _setting("damage_numbers", true)
	add_child(numbers)

	interactables.place_from_map(map_def, map, rng, _pos)

	_camera = Camera2D.new()
	_camera.limit_left = int(bounds.position.x) - 8
	_camera.limit_top = int(bounds.position.y) - 8
	_camera.limit_right = int(bounds.end.x) + 8
	_camera.limit_bottom = int(bounds.end.y) + 8
	add_child(_camera)
	_camera.make_current()


func _make_particles() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = 6
	p.lifetime = 0.3
	p.explosiveness = 1.0
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 45.0
	p.damping_min = 60.0
	p.damping_max = 80.0
	p.local_coords = false
	return p


func _draw_player() -> void:
	var v := _player_view
	# Blink during i-frames.
	if _iframes > 0.0 and int(_iframes * 20.0) % 2 == 0:
		return
	var ink := Palette.color(Palette.INK)
	var flip := _facing.x < 0.0
	# Loaf body 11x8 with a crust top, helmet 7x4 on top, visor slit.
	v.draw_rect(Rect2(-6, -3, 12, 8), ink)
	v.draw_rect(Rect2(-5, -2, 10, 6), Palette.color(Palette.DOUGH))
	v.draw_rect(Rect2(-5, -2, 10, 2), Palette.color(Palette.CRUST))
	v.draw_rect(Rect2(-4, -8, 8, 6), ink)
	v.draw_rect(Rect2(-3, -7, 6, 4), Palette.color(Palette.MIST))
	v.draw_rect(Rect2(1 if not flip else -3, -6, 2, 1), ink)
	v.draw_rect(Rect2(-1, -10, 2, 2), Palette.color(Palette.RED))  # plume


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 10
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui)
	_joystick = ThumbStick.new()
	ui.add_child(_joystick)
	_hud = Hud.new()
	ui.add_child(_hud)

	# Level-up cards.
	_cards_panel = _panel(ui, Rect2(4, 50, 172, 236), Palette.NIGHT)
	_title(_cards_panel, "LEVEL UP!", Palette.BUTTER, 8)
	for i in 3:
		var b := PixelButton.new()
		b.position = Vector2(6, 34 + i * 64)
		b.custom_minimum_size = Vector2(160, 58)
		b.size = b.custom_minimum_size
		b.pressed.connect(_on_card.bind(i))
		_cards_panel.add_child(b)
		_card_buttons.append(b)

	# Shrine bonus / merchant choices: up to 3 options and a leave button.
	_choice_panel = _panel(ui, Rect2(4, 40, 172, 262), Palette.NIGHT)
	_choice_title = _title(_choice_panel, "", Palette.BUTTER, 8)
	for i in 3:
		var b := PixelButton.new()
		b.position = Vector2(6, 34 + i * 64)
		b.custom_minimum_size = Vector2(160, 58)
		b.size = b.custom_minimum_size
		b.pressed.connect(_on_choice.bind(i))
		_choice_panel.add_child(b)
		_choice_buttons.append(b)
	_choice_leave = PixelButton.new()
	_choice_leave.position = Vector2(36, 230)
	_choice_leave.custom_minimum_size = Vector2(100, 20)
	_choice_leave.size = _choice_leave.custom_minimum_size
	_choice_leave.face = Palette.MIST
	_choice_leave.pressed.connect(_close_choice)
	_choice_panel.add_child(_choice_leave)

	# Game over.
	_over_panel = _panel(ui, Rect2(14, 64, 152, 186), Palette.NIGHT)
	_over_title = _title(_over_panel, "", Palette.BUTTER, 10)
	_over_text = Label.new()
	_over_text.position = Vector2(0, 36)
	_over_text.size = Vector2(152, 100)
	_over_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_over_panel.add_child(_over_text)
	var menu_btn := PixelButton.new()
	menu_btn.label = "BACK TO MENU"
	menu_btn.position = Vector2(20, 148)
	menu_btn.custom_minimum_size = Vector2(112, 20)
	menu_btn.size = menu_btn.custom_minimum_size
	menu_btn.pressed.connect(_to_menu)
	_over_panel.add_child(menu_btn)

	# Pause.
	_pause_panel = _panel(ui, Rect2(24, 110, 132, 100), Palette.NIGHT)
	_title(_pause_panel, "PAUSED", Palette.PAPER, 10)
	var resume := PixelButton.new()
	resume.label = "RESUME"
	resume.face = Palette.GREEN
	resume.position = Vector2(14, 34)
	resume.custom_minimum_size = Vector2(104, 20)
	resume.size = resume.custom_minimum_size
	resume.pressed.connect(_pause.bind(false))
	_pause_panel.add_child(resume)
	var quit := PixelButton.new()
	quit.label = "GIVE UP"
	quit.face = Palette.RED
	quit.position = Vector2(14, 62)
	quit.custom_minimum_size = Vector2(104, 20)
	quit.size = quit.custom_minimum_size
	quit.pressed.connect(func() -> void:
		_pause_panel.hide()
		get_tree().paused = false
		state = "live"
		_end("gave_up"))
	_pause_panel.add_child(quit)


## A hidden panel. `rect` is in the 180x320 design frame; the panel is
## anchored to the screen center so it stays centered on taller screens.
func _panel(parent: Node, rect: Rect2, fill: int) -> PixelPanel:
	var p := PixelPanel.new()
	p.fill = fill
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 0.5
	p.anchor_bottom = 0.5
	p.offset_left = rect.position.x - 90.0
	p.offset_top = rect.position.y - 160.0
	p.offset_right = p.offset_left + rect.size.x
	p.offset_bottom = p.offset_top + rect.size.y
	p.hide()
	parent.add_child(p)
	return p


func _title(parent: Control, text: String, color: int, y: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = Vector2(0, y)
	l.size = Vector2(parent.size.x / 2.0, 10)
	l.scale = Vector2(2, 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Palette.color(color))
	l.add_theme_color_override("font_shadow_color", Palette.color(Palette.INK))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(l)
	return l


func _to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)

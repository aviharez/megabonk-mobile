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
##
## Meta progression (Meta): the run reads the save for the character, the
## pool (owned unlocks, Toggler), permanent shop upgrades and level-up action
## charges. At the end it commits `run_stats` to the save (the stat tracker
## totals and unlock challenges), plus kills and shots per weapon
## ("kills.<weapon>", "shots.<weapon>"), gems collected, the level reached and
## whether the run was finished.

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
const RUN_SCENE := "res://scenes/run.tscn"
const SaveManager := preload("res://scripts/autoload/save_manager.gd")
## Spawns appear this far outside the visible area.
const SPAWN_MARGIN := Vector2(10, 10)
const RECYCLE_EVERY := 0.25
const DITHER_FADE := preload("res://assets/shaders/dither_fade.gdshader")

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
## pin_hp: hold HP at this fraction of max (stress: low-HP effects on).
## character: who plays (default: the save's last pick, if owned).
## save: a save node to read meta progress from and commit the result to
##   (tests). Without it the Save autoload is used, or, with no_save, a blank
##   save that is never written (tests and bots don't depend on progress).
## charges: overrides for the level-up action charges {"reroll": n, ...}.
## ads: an Ads service node (tests). Without it the Ads autoload is used
##   when the run uses the Save autoload (the real game), never in bot runs.
## audio: an audio node with play(id) / play_music(id) (tests). Without it
##   the Audio autoload is used (if there is one).
var options := {}
var db: GameData
var rules: Dictionary
var map_def: Dictionary
var char_def: Dictionary
var elite_rules: Dictionary
var rng := RandomNumberGenerator.new()
var stats: StatBlock
## Save data the meta progression is read from (Save.data or a blank save).
var meta: Dictionary
## Level-up action charges left this run: {"reroll", "skip", "banish"}.
var charges := {}
## Rewarded ads (scripts/autoload/ads.gd): revive on death, 2x coins at game
## over, a level-up action when its charges run out. null = no ads.
var ads: Node
var ad_rules: Dictionary
var revived := false
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
var _pause_btn: SpriteButton
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
## Sounds, shake, hit-stop, vignette, Final Swarm tint, level-up burst.
var juice: Juice
var fx_rules: Dictionary
## Enemy telegraphs (red zones, charge lines). Never turned off.
var danger: Fx

var _pos := Vector2.ZERO
var _facing := Vector2.RIGHT
var _iframes := 0.0
## Character sheets by clip (idle, walk, hit) from char_def.sheets; empty =
## the code-drawn fallback. _hit_at: elapsed time of the last hit taken.
var _sprites := {}
var _moving := false
var _hit_at := -INF
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
var _save: Node
var _passive_state := {}
## Cached tracker keys per source ("kills.<id>", "shots.<id>"): no string
## building per kill.
var _kill_keys := {}
var _shot_keys := {}
var _banish_mode := false
var _cards_title: Label
var _action_buttons := {}  # action -> ActionButton
var _over_list: VBoxContainer
var _hits := PackedInt32Array()
var _zap_hits := PackedInt32Array()
var _player_view: Node2D
var _weapon_view: Node2D
var _boss_view: Node2D
var _camera: Camera2D
## The world's own view (see _build_world) and the rect that shows it.
var world_viewport: SubViewport
var _world_rect: TextureRect
## Screen pixels per world pixel / per UI pixel (whole numbers).
var world_scale := 1
var ui_scale := 1
var _particles: NodePool
var _reduce_fx := false
## Per hit source (weapon id): {"fx": hit_fx, "sfx": hit sound, "attack":
## attack sound, "at": run time of its last hit effect}.
var _hit_style := {}
## Things to do a little later in run time: [[at, Callable], ...].
var _later := []
var _particle_tex := {}
var _hud: Hud
var _joystick: ThumbStick
var _cards_panel: Control
var _card_buttons: Array[LevelCard] = []
var _dim: DitherDim
var _flash: DitherDim
var _pause_facts: Label
var _pause_build: BuildView
var _pause_stats: Control
var _pause_info: Control
var _weapon_under: Node2D
var _pause_resume: PixelButton
## [kind, id] shown in the pause info box.
var _pause_pick: Array = []
var _pause_toggles := {}
var _give_up: PixelButton
var _give_up_armed := false
var _over_reason: Label
var _over_hero: Control
var _over_tiles: Control
var _over_coins: CoinPlate
var _over_mult: Label
var _over_scroll: ScrollContainer
var _again_btn: PixelButton
var _cards: Array = []
var _choice_panel: Control
var _choice_title: Label
var _choice_buttons: Array[LevelCard] = []
var _choice_sub: Label
var _cards_sub: Label
## Pick-one cards (level-up, shrine, merchant): where they sit in their panel.
const CARD_X := 6
const CARD_Y := 40
const CARD_W := 160
const CARD_H := 66
const CARD_STEP := 70
var _choice_leave: PixelButton
var _choice := {}
var _over_panel: Control
var _over_text: Label
var _over_title: Label
var _pause_panel: Control
var _revive_panel: Control
var _revive_btn: AdButton
var _double_btn: AdButton
var _menu_btn: PixelButton
var _leaving := false


func _ready() -> void:
	options = next_options.duplicate(true)
	next_options = {}
	db = GameData.shared()
	rules = db.get_entry("rules", "run").duplicate(true)
	rules.merge(options.get("rules", {}), true)
	map_def = db.get_entry("maps", options.get("map", "suburbia"))
	_save = options.get("save")
	if _save == null and not options.get("no_save", false):
		_save = get_node_or_null("/root/Save")
	meta = _save.data if _save != null else SaveManager.default_data()
	var who: String = options.get("character", Meta.picked_character(db, meta))
	char_def = db.get_entry("characters", who)
	if char_def.is_empty():
		push_error("Run: character '%s' not found" % who)
		char_def = db.get_entry("characters", Meta.picked_character(db, meta))
	for clip: String in char_def.get("sheets", {}):
		var sh := EnemySystem.load_sheet({"sheet": char_def.sheets[clip]})
		if not sh.is_empty():
			_sprites[clip] = sh
	elite_rules = db.get_entry("rules", "elites")
	ad_rules = db.get_entry("rules", "ads")
	ads = options.get("ads")
	# The Ads autoload goes with the real save: runs on a test save, blank
	# save (no_save) or a bot never see ads unless a test passes "ads".
	if ads == null and not options.get("bot", false) and _save != null and _save == get_node_or_null("/root/Save"):
		ads = get_node_or_null("/root/Ads")
	if options.has("seed"):
		rng.seed = int(options.seed)
	else:
		rng.randomize()

	bounds = Rect2(Vector2.ZERO, Vector2(map_def.size[0], map_def.size[1]))
	_pos = bounds.get_center()
	stats = StatBlock.new(char_def.stats)
	for b: Array in Meta.stat_bonuses(db, meta):
		stats.apply_modifiers(b[0], b[1], b[2])
	Passives.update(char_def.passive, stats, 0.0, _passive_state)
	hp = stat("max_hp")
	shield = stat("shield")
	items = ItemSystem.new(self, db)
	if options.get("all_content", false):
		pool = ContentPool.new(db, {}, true)
	else:
		pool = ContentPool.from_save(db, meta)
	for a: String in Meta.ACTIONS:
		charges[a] = Meta.charges(db, meta, a)
	charges.merge(options.get("charges", {}), true)
	director = Director.new(map_def, int(rules.enemy_cap), float(rules.run_length_sec), rng, db.get_entry("rules", "bills"))
	for e: Dictionary in db.all("enemies"):
		if e.has("pack_size"):
			_pack_sizes[e.id] = e.pack_size
	_reduce_fx = _setting("reduce_effects", false)
	fx_rules = db.get_entry("rules", "fx")
	juice = Juice.new()
	juice.setup(fx_rules, options.get("audio", get_node_or_null("/root/Audio")), _setting("screen_shake", true), _reduce_fx)
	add_child(juice)
	_profiling = options.get("profile", false)
	elapsed = float(options.get("start_at", 0.0))
	var m: Dictionary = map_def.get("merchant", {})
	if not m.is_empty():
		_merchant_at = float(m.get("first_sec", 120.0))

	_build_world()
	_build_ui()
	_give_weapon(char_def.signature_weapon)
	_apply_loadout(options.get("loadout", {}))
	if ads != null:
		ads.begin_run()
		ads.set_banner(false)  # never during gameplay
		ads.ready_changed.connect(_refresh_ad_buttons)
	_music("gameplay")
	_render()
	if not options.get("bot", false) and not options.get("stress", false):
		_hud.banner("SURVIVE!", Palette.BUTTER, 1.5)
		_joystick.hint = int(meta.get("runs_played", 0)) < 2


func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	# Hit-stop: the game holds still for a moment, the picture keeps drawing.
	if not juice.hold(delta):
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
	_moving = dir.length_squared() > 0.01
	if _moving:
		_facing = dir.normalized()
	_pos = map.move(_pos, dir * stat("move_speed") * delta, player_radius())
	_update_passive(minute)
	hp = minf(hp + stat("regen") * delta, stat("max_hp"))
	_update_shield(delta)
	if options.has("pin_hp"):
		hp = stat("max_hp") * float(options.pin_hp)
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
		_die()
		return

	var got := gems.update(delta, _pos, stat("pickup_range"))  # counts gems.collected
	if got > 0.0:
		juice.sfx("gem")
		add_xp(got)
	_mark("gems")
	interactables.update(delta)
	_tick_merchant()
	_tick_hint(minute)
	_mark("map_objects")
	numbers.update(delta)
	fx.update(delta)
	danger.update(delta)
	juice.update(delta, hp / maxf(1.0, stat("max_hp")))
	_tick_later()
	_mark("fx")
	var every: float = options.get("chest_every", 0.0)
	if every > 0.0:
		_chest_t += delta
		if _chest_t >= every:
			_chest_t -= every
			open_chest("paid")

	if hp <= 0.0:
		_die()
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
		juice.sfx("level_up")
		UiFx.buzz(self, 25)
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
	_hit_feedback(slot, amount, crit, source)
	var died := enemies.hurt(slot, amount, push)
	if not died and boss != null and slot == boss.slot:
		boss.on_hit()
		juice.boss_hit(elapsed)
	if procs:
		on_hit.emit(slot, amount, crit, source)
		if items.listens("on_hit"):
			items.emit("on_hit", {"slot": slot, "pos": enemies.pos[slot], "elite": enemies.elite[slot] == 1, "source": source, "crit": crit})
	# An on_hit effect may already have killed it.
	if died and enemies.pool.is_alive(slot):
		_kill(slot, source)


## Sound and effect of a hit (before it lands, so max HP is the enemy's):
## the weapon's "hit_fx" and hit sound (data/weapons/*.json "sfx": {"hit"}),
## at most one effect per weapon every fx.json "hit_fx_gap" seconds; a crit
## sound, and a hit-stop for a big crit.
func _hit_feedback(slot: int, amount: float, crit: bool, source: String) -> void:
	if not _hit_style.has(source):
		_hit_feedback_style(source)
	var st: Dictionary = _hit_style[source]
	if crit:
		juice.sfx("crit")
		juice.crit(amount, enemies.max_hp[slot], enemies.elite[slot] == 1)
	else:
		juice.sfx(st.sfx)
	var hf: Dictionary = st.fx
	if hf.is_empty() or elapsed - float(st.at) < float(fx_rules.get("hit_fx_gap", 0.05)):
		return
	st.at = elapsed
	var at := enemies.pos[slot]
	var c := Palette.index_of(hf.get("color", "PAPER"))
	var r := float(hf.get("r", 3.0))
	match hf.get("kind", ""):
		"puff": fx.puff(at, r, c)
		"star": fx.star(at, r, c)
		"sparks": fx.sparks(at, r, c, 0.25)


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
		juice.sfx("dodge")
		fx.star(_pos, 4.0, Palette.WHITE)
		return false
	_hit_at = elapsed
	var dmg := amount * Passives.damage_taken_mult(char_def.passive, elapsed / 60.0)
	if contact:
		dmg *= stat("contact_damage_taken")
	if not pierce:
		dmg = maxf(1.0, dmg - stat("armor"))
	_shield_idle = 0.0
	_swarm_hit = true
	last_damage_source = source
	var absorbed := 0.0 if pierce else minf(shield, dmg)
	# Feedback first: an invincible test hero still flinches and shakes.
	juice.sfx("hurt")
	juice.shake("hurt")
	UiFx.buzz(self, 35)
	fx.puff(_pos, 6.0, Palette.RED if absorbed < dmg else Palette.SKY)
	if options.get("invincible", false):
		return true
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
	juice.sfx("boom")


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
	juice.sfx("zap")
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
		var src: String = shot.get("source", "")
		var k: String = _shot_keys.get(src, "")
		if k == "":
			k = Meta.stat_key("shots", src)
			_shot_keys[src] = k
		run_stats[k] = run_stats.get(k, 0.0) + 1.0
		on_projectile.emit(shot)
		if items.listens("on_projectile"):
			items.emit("on_projectile", {"shot": shot, "pos": shot.pos})
	return s


## A copy of a shot, turned by up to `spread` radians. Doesn't fire hooks.
func duplicate_shot(shot: Dictionary, spread: float) -> void:
	var copy := shot.duplicate()
	copy.vel = Vector2(shot.vel).rotated(rng.randf_range(-spread, spread))
	projectiles.fire(copy)


## Cached per hit source: the weapon's "hit_fx" and "sfx" {"hit", "attack"}.
## Burns and item effects make no hit sound of their own (a blast booms, a
## zap crackles).
func _hit_feedback_style(source: String) -> void:
	var w := db.get_entry("weapons", source)
	var hit: String = w.get("sfx", {}).get("hit", "hit")
	if source == "burn" or source.begins_with("item:"):
		hit = ""
	_hit_style[source] = {"fx": w.get("hit_fx", {}), "sfx": hit, "attack": w.get("sfx", {}).get("attack", ""), "at": -INF}


## Weapons call this once per attack (via Weapon.attacked()).
func weapon_attacked(weapon_id: String) -> void:
	if not _hit_style.has(weapon_id):
		_hit_feedback_style(weapon_id)
	juice.sfx(_hit_style[weapon_id].attack)
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


## The pickup card for an item just gained: icon, rarity, name, what it does
## (and how many stacks when it's more than one).
func show_item_card(id: String) -> void:
	var def := db.get_entry("items", id)
	var loot := db.get_entry("rules", "loot")
	var n := items.count(id)
	var tag := "%s ITEM" % String(loot.rarity_names.get(def.rarity, ""))
	if n > 1:
		tag += "  X%d" % n
	_hud.pickup_card(Icons.texture(db, "items", id), def.name, tag, def.get("desc", ""), Palette.index_of(loot.rarity_colors[def.rarity]))


## Opens a chest of `kind` ("paid", "elite", "boss"): rolls an item with
## the player's luck and gives it. Returns the item id ("" = nothing left
## to give; the chest pays out gold instead). Map chests, elite drops and the
## boss chest all come through here. `at` = where the chest stood (default:
## the player): a beam in the item's rarity color rises there first, then
## the chest pops and the item's name shows (the item is given at once).
func open_chest(kind: String, at := Vector2.INF) -> String:
	if at == Vector2.INF:
		at = _pos
	var id := Loot.roll(rng, db, kind, stat("luck"), items.stacks, pool)
	var cb: Dictionary = fx_rules.get("chest_beam", {})
	var wait := float(cb.get("time", 0.5))
	var color := "GOLD"
	var text := "+GOLD"
	if id == "":
		add_gold(db.get_entry("rules", "loot").get("empty_chest_gold", 0.0))
	else:
		give_item(id)
		var def := db.get_entry("items", id)
		var loot := db.get_entry("rules", "loot")
		color = loot.rarity_colors[def.rarity]
		text = def.name
		record("chests_opened")
		if kind == "paid" and def.rarity == "epic":
			record("epic_from_paid_chest")
	var ci := Palette.index_of(color)
	fx.beam(at, float(cb.get("height", 44.0)), ci, wait)
	juice.sfx("beam")
	later(wait, func() -> void:
		fx.sparks(at, 14.0, ci, 0.45)
		fx.ring(at, 10.0, ci)
		fx.ring(at, 18.0, ci, 0.4)
		juice.sfx("chest")
		if id == "":
			toast(text, color)
		else:
			show_item_card(id))
	on_chest_opened.emit(kind, id)
	if items.listens("on_chest_opened"):
		items.emit("on_chest_opened", {"kind": kind, "item": id, "pos": _pos})
	return id


## Shrines call this when they activate.
func shrine_activated(shrine_id: String) -> void:
	record("shrines_activated")
	juice.sfx("shrine")
	fx.ring(_pos, 16.0, Palette.SKY, 0.4)
	fx.sparks(_pos, 12.0, Palette.SKY)
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
	fx.sparks(at + Vector2(0, -24), 20.0, Palette.CRUST, 0.5)
	juice.sfx("boss_roar")
	UiFx.buzz(self, 80)
	juice.shake("boss_slam")
	_music("boss")
	return true


## The portal calls this: the run ends as an escape.
func escape() -> void:
	if state == "live":
		juice.sfx("escape")
		fx.ring(_pos, 20.0, Palette.PURPLE, 0.4)
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
			juice.sfx("elite")
			fx.ring(enemies.pos[s], 12.0, enemies.outline[s], 0.4)
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
				juice.sfx("alarm")
			"swarm_start":
				_swarm_hit = false
				record("swarms_started")
			"swarm_end":
				if not _swarm_hit and hp > 0.0:
					record("swarm_survived_no_damage")
				toast("SWARM OVER", "LIME")
				juice.sfx("shrine")
				fx.ring(_pos, 24.0, Palette.LIME, 0.4)
			"final_start":
				_hud.banner("FINAL SWARM!", Palette.PINK)
				record("final_swarm_reached")
				juice.sfx("final")
				juice.shake("boss_slam")
				juice.start_final_tint()
				_music("boss")
			"bills_start":
				_hud.banner("BILLS ARE DUE!", Palette.PAPER)
				juice.sfx("bills")
			"bills_faster":
				toast("THE BILLS GROW IMPATIENT", "PAPER")
				juice.sfx("bills")


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
	# Never closer than the view's corners (plus a margin): a wide or tall
	# screen must not see enemies vanish.
	var far: float = maxf(map_def.get("despawn_distance", 260.0), _half_view().length() + SPAWN_MARGIN.length() * 2.0)
	var far2 := far * far
	var b := _boss_slot()
	var view := view_rect().grow(8.0)
	for s in enemies.pool.active:
		if s == b:
			continue
		var wedged := enemies.stalled[s] > STALL_SEC and not view.has_point(enemies.pos[s])
		if wedged or enemies.pos[s].distance_squared_to(_pos) > far2:
			enemies.move_to(s, _spawn_point(enemies.flags[s] & (EnemySystem.F_FLY | EnemySystem.F_GHOST) != 0))


## Half the visible area in world pixels: the world view (see
## _fit_world_view), at least 180x320 times "world_view_scale", and bigger on
## taller or wider screens (stretch aspect "expand").
func _half_view() -> Vector2:
	return Vector2(world_viewport.size) / 2.0 if world_viewport != null else get_viewport_rect().size / 2.0


## Sizes the world view. The UI is drawn at the screen's whole-number scale
## (ui_scale, from the 180x320 base); the world at a smaller whole number,
## about ui_scale / "world_view_scale" (7x UI -> 5x world on a 1280 px wide
## phone), so every world pixel is still a square block of screen pixels.
func _fit_world_view() -> void:
	var base := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"), ProjectSettings.get_setting("display/window/size/viewport_height"))
	var win := Vector2(get_window().size)
	ui_scale = maxi(1, floori(minf(win.x / base.x, win.y / base.y)))
	var want: float = float(rules.get("world_view_scale", 1.0))
	world_scale = clampi(roundi(ui_scale / want), 1, ui_scale)
	var screen := get_viewport_rect().size * ui_scale
	world_viewport.size = Vector2i(ceili(screen.x / world_scale), ceili(screen.y / world_scale))
	_world_rect.size = Vector2(world_viewport.size)
	# In UI pixels: one world pixel is world_scale / ui_scale of a UI pixel.
	_world_rect.scale = Vector2.ONE * float(world_scale) / float(ui_scale)
	if _hud != null:
		_hud.world_zoom = float(world_scale) / float(ui_scale)
	if juice != null:
		juice.resize(Vector2(world_viewport.size))


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
			juice.sfx(_enemy_sfx(def, "shoot"))
			fx.puff(at + dir * enemies.radius[slot], 2.0, Palette.index_of(def.color), 0.15)
			var sh: Dictionary = def.shot
			enemy_shots.fire(at + dir * enemies.radius[slot], dir * float(sh.speed), float(sh.damage) * power, float(sh.radius), float(sh.life), sh.get("sprite", "bullet"), def.id)
		EnemySystem.EV_SWELL:
			var ex: Dictionary = def.explode
			juice.sfx(_enemy_sfx(def, "swell"))
			danger.disc(at, float(ex.radius), Palette.RED, float(ex.fuse))
			danger.ring(at, float(ex.radius), Palette.RED, float(ex.fuse))
		EnemySystem.EV_EXPLODE:
			var ex: Dictionary = def.explode
			fx.ring(at, float(ex.radius), Palette.ORANGE)
			fx.disc(at, float(ex.radius), Palette.ORANGE)
			fx.sparks(at, float(ex.radius), Palette.LIME)
			juice.sfx(_enemy_sfx(def, "explode"))
			if at.distance_to(_pos) <= float(ex.radius) * 3.0:
				juice.shake("explode")
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
			juice.sfx(_enemy_sfx(def, "windup"))


## An enemy's sound for `event` (enemy data "sfx": {"shoot", "swell",
## "explode", "windup", "death"}); "" = none.
func _enemy_sfx(def: Dictionary, event: String) -> String:
	return def.get("sfx", {}).get(event, "")


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
		numbers.show_text(at + Vector2(0, -4), "+G", Palette.GOLD)
		juice.sfx("gold")
	_death_particles(at, Palette.index_of(def.color))
	juice.sfx(_enemy_sfx(def, "death") if def.get("sfx", {}).has("death") else "kill")
	if elite:
		fx.sparks(at, 16.0, enemies.outline[slot], 0.5)
		juice.sfx("pop")
	kills += 1
	if source != "":
		var k: String = _kill_keys.get(source, "")
		if k == "":
			k = Meta.stat_key("kills", source)
			_kill_keys[source] = k
		run_stats[k] = run_stats.get(k, 0.0) + 1.0
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
	var portal := free_spot_near(at + Vector2(0, 20))
	interactables.add("portal", portal)
	enemy_shots.clear()
	_hud.banner("PORTAL OPEN!", Palette.PURPLE)
	boss = null
	var h: Dictionary = fx_rules.get("hitstop", {})
	juice.hitstop(float(h.get("boss_down", 0.12)))
	juice.shake("boss_down")
	juice.sfx("boss_down")
	UiFx.buzz(self, 120)
	fx.sparks(at, 26.0, Palette.CRUST, 0.7)
	fx.sparks(at, 18.0, Palette.BUTTER, 0.6)
	fx.ring(at, 40.0, Palette.BUTTER, 0.5)
	later(0.8, func() -> void:
		juice.sfx("portal")
		fx.ring(portal, 14.0, Palette.PURPLE, 0.5))
	if not final_swarm():
		_music("gameplay")


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
	juice.sfx("merchant")
	fx.puff(at, 8.0, Palette.MIST, 0.4)
	fx.sparks(at, 10.0, Palette.BUTTER)


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
	return int(meta.get("runs_played", 0)) == 0


## Character passives that change stats (Turbo Pigeon, Gary). A higher max HP
## heals the difference, like a tome.
func _update_passive(minute: float) -> void:
	var before := stat("max_hp")
	var msg := Passives.update(char_def.passive, stats, minute, _passive_state)
	heal(maxf(0.0, stat("max_hp") - before))
	if msg != "":
		toast(msg, "BUTTER", 2.0)


func _open_level_up() -> void:
	_cards = LevelUpCards.pick(rng, db, owned_weapons, owned_tomes, rules, pool)
	if options.get("auto_cards", false):
		pending_levels -= 1
		if not _cards.is_empty():
			apply_card(_cards[0])
		return
	var chained := state == "level_up"
	state = "level_up"
	_banish_mode = false
	_joystick.release()
	get_tree().paused = true
	_show_cards()
	if chained:
		# Several levels at once: the next cards straight away, no second burst.
		_cards_panel.show()
		return
	# The light burst plays over the frozen world first, then the cards show.
	juice.level_burst(_screen_pos(_pos), func() -> void:
		if state == "level_up":
			_cards_panel.show())


## A world point in UI pixels (where it is on screen).
func _screen_pos(world: Vector2) -> Vector2:
	var center := _camera.get_screen_center_position() if _camera.is_inside_tree() else _pos
	return (world - center) * float(world_scale) / float(ui_scale) + get_viewport_rect().size / 2.0


func _show_cards() -> void:
	_cards_title.text = "BANISH WHICH?" if _banish_mode else "LEVEL UP!"
	_cards_sub.text = "TAP A NEW ONE TO BANISH IT" if _banish_mode else ("LEVEL %d  -  PICK ONE" % level if pending_levels <= 1 else "LEVEL %d  -  PICK ONE  (+%d MORE)" % [level, pending_levels - 1])
	var fresh := not _cards_panel.visible
	for i in _card_buttons.size():
		var b := _card_buttons[i]
		b.visible = i < _cards.size()
		if b.visible:
			var card: Dictionary = _cards[i]
			# The plain text stays on the button for tests and bots.
			b.label = "\n".join(Array(LevelUpCards.describe(card)).map(func(l: String) -> String: return l.replace("  NEW!", "")))
			var top := int(rules.max_level)
			if card.kind == "weapon":
				top = mini(top, card.def.levels.size())
			b.show_card(card, Icons.texture(db, card.kind + "s", card.id) if card.kind in ["weapon", "tome"] else null, top)
			b.disabled = _banish_mode and not _can_banish(card)
			b.ink = Palette.SALMON if _banish_mode and not b.disabled else Palette.PAPER
			if fresh:
				b.position.x = CARD_X
				UiFx.slide_in(b, Vector2(180, 0), 0.25, 0.06 * i)
	for a: String in _action_buttons:
		var ab: ActionButton = _action_buttons[a]
		ab.charges = charges.get(a, 0)
		# Out of charges: the AD tag, shown only while a rewarded ad can pay
		# for one more (once per action per run, see Ads).
		ab.ad = ab.charges <= 0
		ab.visible = ab.charges > 0 or _ad_offer(a)
		ab.disabled = _ad_busy()
		ab.active = a == "banish" and _banish_mode


func _on_card(i: int) -> void:
	if state != "level_up" or i >= _cards.size() or _ad_busy():
		return
	if _banish_mode:
		banish_card(i)
		return
	juice.sfx("card")
	apply_card(_cards[i])
	_level_done()


## One level-up is resolved (card taken or skipped): next one or back to play.
func _level_done() -> void:
	pending_levels -= 1
	_cards_panel.hide()
	if pending_levels > 0:
		_open_level_up()
		return
	state = "live"
	get_tree().paused = false


func _on_action(action: String) -> void:
	if state != "level_up" or _ad_busy():
		return
	if charges.get(action, 0) <= 0:
		_action_by_ad(action)
		return
	match action:
		"reroll":
			reroll_cards()
		"skip":
			skip_level()
		"banish":
			# First tap picks banish mode, then a card; tapping again cancels.
			_banish_mode = not _banish_mode and charges.get("banish", 0) > 0
			_show_cards()


## Out of charges: a rewarded ad buys one charge of `action`, used at once
## (Banish enters banish mode). Nothing happens unless the ad pays out.
func _action_by_ad(action: String) -> void:
	if not _ad_offer(action):
		return
	ads.show_rewarded(action, _on_action_ad.bind(action))
	_show_cards()


func _on_action_ad(granted: bool, action: String) -> void:
	if not granted or state != "level_up":
		_refresh_ad_buttons()
		return
	charges[action] = charges.get(action, 0) + 1
	match action:
		"reroll":
			reroll_cards()
		"skip":
			skip_level()
		"banish":
			_banish_mode = true
			_show_cards()


## True when a rewarded ad can pay for `placement` now. Banish only while a
## card on screen can be banished.
func _ad_offer(placement: String) -> bool:
	if ads == null or not ads.can_offer(placement):
		return false
	if placement == "banish":
		return _cards.any(_can_banish)
	return true


## A full-screen ad is up: ignore taps underneath it.
func _ad_busy() -> bool:
	return ads != null and ads.is_showing()


## Ad readiness changed: show or hide the rewarded buttons on screen.
func _refresh_ad_buttons() -> void:
	match state:
		"level_up":
			_show_cards()
		"dying":
			_revive_btn.visible = _ad_offer("revive")
		"over":
			_double_btn.visible = _can_double()


# --- Revive (rewarded ad) -----------------------------------------------------

## The player's HP hit 0. A death that isn't the Final Swarm's bills can be
## undone once per run by a rewarded ad: the run waits on the revive offer.
func _die() -> void:
	juice.sfx("death")
	juice.shake("death")
	UiFx.buzz(self, 150)
	fx.sparks(_pos, 20.0, Palette.RED, 0.6)
	var reason := "bills" if is_bill(last_damage_source) else "died"
	if reason == "died" and _ad_offer("revive"):
		state = "dying"
		_choice = {}
		_choice_panel.hide()
		_cards_panel.hide()
		_pause_panel.hide()
		_joystick.release()
		get_tree().paused = true
		_revive_btn.visible = true
		_revive_panel.show()
		return
	_end(reason)


func _on_revive_pressed() -> void:
	if state != "dying" or _ad_busy() or not _ad_offer("revive"):
		return
	ads.show_rewarded("revive", func(granted: bool) -> void:
		if state != "dying":
			return
		if granted:
			revive()
		else:
			# No reward (failed, skipped): back to the offer, still paused.
			_refresh_ad_buttons())


func _decline_revive() -> void:
	if state == "dying" and not _ad_busy():
		_revive_panel.hide()
		_end("died")


## Back on your feet: part of max HP, a few seconds of i-frames, and the
## enemies close by pushed out to the clear radius (shots in the air vanish).
func revive() -> void:
	var rv: Dictionary = ad_rules.get("revive", {})
	revived = true
	hp = stat("max_hp") * float(rv.get("hp_frac", 0.5))
	_iframes = float(rv.get("iframes", 2.0))
	var r := float(rv.get("clear_radius", 48.0))
	enemies.query_circle(_pos, r, _hits)
	var boss_slot := _boss_slot()
	for slot in _hits:
		if slot == boss_slot:
			continue
		var away := enemies.pos[slot] - _pos
		if away.length_squared() < 0.25:
			away = Vector2.RIGHT.rotated(rng.randf() * TAU)
		enemies.move_to(slot, _pos + away.normalized() * (r + enemies.radius[slot]))
	enemy_shots.clear()
	_revive_panel.hide()
	state = "live"
	get_tree().paused = false
	toast("BACK FOR SECONDS!", "LIME")
	juice.sfx("revive")
	fx.ring(_pos, r, Palette.LIME, 0.4)
	fx.sparks(_pos, 16.0, Palette.LIME)


## Level-up actions (coin shop charges). Each returns true if it did
## something; a charge is only spent then.
func reroll_cards() -> bool:
	if state != "level_up" or charges.get("reroll", 0) <= 0:
		return false
	charges.reroll -= 1
	_banish_mode = false
	_cards = LevelUpCards.pick(rng, db, owned_weapons, owned_tomes, rules, pool)
	_show_cards()
	return true


## Skips this level-up for the Skip entry's "gold".
func skip_level() -> bool:
	if state != "level_up" or charges.get("skip", 0) <= 0:
		return false
	charges.skip -= 1
	add_gold(float(Meta.action_entry(db, "skip").get("gold", 0.0)))
	toast("SKIPPED", "GOLD")
	_level_done()
	return true


## Only new weapons and tomes can be banished (an option from the pool).
func _can_banish(card: Dictionary) -> bool:
	return card.kind in ["weapon", "tome"] and card.is_new


## Removes card i's weapon or tome from the pool for the rest of the run and
## puts a different card in its place.
func banish_card(i: int) -> bool:
	if state != "level_up" or charges.get("banish", 0) <= 0 or i >= _cards.size() or not _can_banish(_cards[i]):
		return false
	charges.banish -= 1
	_banish_mode = false
	pool.banish(_cards[i].id)
	toast("BANISHED " + String(_cards[i].def.name), "SALMON")
	var shown := {}
	for c: Dictionary in _cards:
		shown[c.kind + ":" + c.id] = true
	# Enough candidates to find one that isn't on screen yet.
	var r := rules.duplicate()
	r.card_count = int(rules.card_count) + _cards.size()
	var fresh := LevelUpCards.pick(rng, db, owned_weapons, owned_tomes, r, pool)
	var repl: Dictionary = {}
	for c: Dictionary in fresh:
		if not shown.has(c.kind + ":" + c.id) and (c.kind != "fallback" or repl.is_empty()):
			repl = c
			if c.kind != "fallback":
				break
	if repl.is_empty():
		_cards.remove_at(i)
	else:
		_cards[i] = repl
	_show_cards()
	return true


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
	var faces := [Palette.SKY, Palette.LIME, Palette.BUTTER]
	for c: Dictionary in offer:
		# "AREA +8%": the name, and the value shown big.
		var desc: String = c.desc
		var cut := desc.rfind(" ")
		var value := desc.substr(cut + 1) if cut > 0 else ""
		opts.append({"label": desc, "face": faces[opts.size() % faces.size()], "enabled": true, "art": _stat_icon(c.stat),
			"title": desc.substr(0, cut) if cut > 0 else desc, "value": value,
			"tag": "BEACON", "desc": _bonus_preview(c, value.ends_with("%"))})
	_show_choice("PICK A BONUS", opts, "", func(i: int) -> bool:
		var c: Dictionary = offer[i]
		var before := stat("max_hp")
		stats.set_modifier(c.stat, src, float(c.get("flat", 0.0)), float(c.get("pct", 0.0)))
		heal(maxf(0.0, stat("max_hp") - before))
		_hud.pickup_card(_stat_icon(c.stat), c.desc, "BEACON BONUS", "LASTS THE WHOLE RUN", Palette.SKY)
		return true)


## "NOW 150 > 165": the stat now and with shrine bonus `c` (tried on and
## taken off again). Percent bonuses on small stats (multipliers, chances)
## read as percents.
func _bonus_preview(c: Dictionary, pct: bool) -> String:
	var before := stat(c.stat)
	stats.set_modifier(c.stat, "shrine:preview", float(c.get("flat", 0.0)), float(c.get("pct", 0.0)))
	var after := stat(c.stat)
	stats.remove_modifier(c.stat, "shrine:preview")
	var as_pct: bool = (pct or c.stat in ["crit_chance", "luck", "evasion"]) and absf(before) < 5.0 and absf(after) < 5.0
	var f := func(v: float) -> String:
		if as_pct:
			return "%d%%" % roundi(v * 100.0)
		return LevelCard._num(snappedf(v, 0.1)) if absf(v) < 10.0 else str(roundi(v))
	return "NOW %s > %s" % [f.call(before), f.call(after)]


## The icon of a tome that raises `stat` (shrine bonuses borrow it), or null.
func _stat_icon(stat_id: String) -> Texture2D:
	for t: Dictionary in db.all("tomes"):
		for m: Dictionary in t.get("modifiers_per_level", []):
			if m.get("stat", "") == stat_id:
				return Icons.texture(db, "tomes", t.id)
	return null


## Merchant: buy items for gold, then leave. Touch it again to come back.
func open_merchant(o: Dictionary) -> void:
	var loot := db.get_entry("rules", "loot")
	var refresh := func() -> Array:
		var opts := []
		for st: Dictionary in o.stock:
			var item := db.get_entry("items", st.item)
			var price_text := "SOLD" if st.sold else "G %d" % st.price
			var ok := _can_hold(st.item)
			if not st.sold and not ok:
				price_text = "YOU HAVE ONE"
			var label := "%s\n%s\n%s  %s" % [item.name, item.get("desc", ""), loot.rarity_names[item.rarity], price_text]
			var opt := {"label": label, "face": Palette.index_of(loot.rarity_colors[item.rarity]), "enabled": not st.sold and ok and gold >= st.price,
				"art": Icons.texture(db, "items", st.item), "title": item.name, "tag": loot.rarity_names[item.rarity] + " ITEM",
				"desc": item.get("desc", ""), "price": st.price, "afford": gold >= st.price}
			if st.sold:
				opt.stamp = "SOLD"
			elif not ok:
				opt.stamp = "HAVE ONE"
				opt.stamp_color = Palette.SHADE
			opts.append(opt)
		return opts
	_show_choice("MERCHANT", refresh.call(), "LEAVE", func(i: int) -> bool:
		var st: Dictionary = o.stock[i]
		if st.sold or gold < st.price or not _can_hold(st.item):
			return false
		spend_gold(st.price)
		st.sold = true
		give_item(st.item)
		record("items_bought")
		juice.sfx("buy")
		fx.sparks(_pos, 10.0, Palette.GOLD)
		show_item_card(st.item)
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
	var fresh := not _choice_panel.visible
	_choice.opts = opts
	for i in _choice_buttons.size():
		var b := _choice_buttons[i]
		b.visible = i < opts.size()
		if b.visible:
			var o: Dictionary = opts[i].duplicate()
			o.color = o.face
			# The plain text stays on the card for tests and bots.
			b.label = o.label
			b.disabled = not o.enabled
			b.show_option(o)
			if fresh:
				b.position.x = CARD_X
				UiFx.slide_in(b, Vector2(180, 0), 0.25, 0.06 * i)
	# The merchant shows your gold (it changes as you buy); shrines just ask.
	_choice_sub.text = ("YOUR GOLD  %d" % gold) if _choice.get("leave", "") != "" else "PICK ONE"


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
	_revive_panel.hide()
	end_reason = reason
	var reached_final := final_swarm()
	won = reason == "portal" or reached_final
	gems.pull_all()
	if reached_final:
		run_stats["final_swarm_seconds"] = director.final_time
	run_stats["kills"] = float(kills)
	run_stats["level"] = float(level)
	run_stats["gems_collected"] = float(gems.collected)
	# Giving up doesn't count as finishing a run.
	if reason != "gave_up":
		run_stats["runs_finished"] = 1.0
	var c: Dictionary = rules.coins
	var mult := (1.0 if won else float(c.death_multiplier)) * director.coin_mult()
	var played := minf(elapsed, rules.run_length_sec) + director.final_time
	var coins := floori((c.per_minute * played / 60.0 + c.per_kill * kills) * mult)
	result = {"won": won, "reason": reason, "escaped": reason == "portal", "time": elapsed, "level": level,
		"kills": kills, "coins": coins, "coin_mult": snappedf(director.coin_mult(), 0.01), "gold": floori(gold),
		"final_swarm_seconds": director.final_time, "boss_defeated": boss_defeated, "stats": run_stats.duplicate(),
		"character": char_def.id, "completed": []}
	if _save != null:
		result.completed = Meta.commit_run(db, meta, result.stats, char_def.id, coins, map_def.id)
		_save.save_game()
	if ads != null:
		ads.end_run()
	run_ended.emit(result)
	if options.get("bot", false) and options.get("auto_cards", false):
		return  # headless sims read `result`; no screen to show
	_joystick.release()
	get_tree().paused = true
	var title := "TOASTED!"
	var color := Palette.PAPER  # titles sit on the red ribbon
	match reason:
		"portal":
			title = "ESCAPED!"
			color = Palette.BUTTER
		"bills":
			title = "OVERDUE!"
			color = Palette.PAPER
		"gave_up":
			title = "GAVE UP"
		_:
			if reached_final:
				title = "SWARMED!"
				color = Palette.PAPER
	_over_title.text = title
	_over_title.add_theme_color_override("font_color", Palette.color(color))
	(_over_title.get_meta("big") as PixelTitle).color = color
	_over_text.text = _over_lines()
	_over_reason.text = {
		"portal": "YOU GOT OUT. THE TOWN THANKS YOU.",
		"bills": "THE BILLS CAUGHT UP WITH YOU.",
		"gave_up": "EVEN HEROES NEED A NAP.",
	}.get(reason, "THE SWARM WAS TOO MUCH." if not reached_final else "YOU HELD ON TO THE VERY END!")
	_show_over_hero(won)
	_over_tiles.queue_redraw()
	_sync_over_coins(false)
	_double_btn.visible = _can_double()
	_fill_over_progress()
	_hud.hide()
	_pause_btn.hide()
	# Death beat: the frozen moment flashes red, then the result slides in.
	var beat := 0.0 if won or reason == "gave_up" or DisplayServer.get_name() == "headless" else 0.7
	if beat > 0.0:
		_flash.level = 6
		_flash.fade_to(0, beat)
		get_tree().create_timer(beat, true).timeout.connect(_reveal_over)
	else:
		_reveal_over()


func _reveal_over() -> void:
	if state != "over":
		return
	_over_panel.show()
	UiFx.slide_in(_over_panel, Vector2(0, 60), 0.3)
	var earned := int(result.coins) * (2 if result.get("coins_doubled", false) else 1)
	_over_coins.count_to(earned, 0, 0.9)


## The hero on the result screen: idle sheet after a win, hit sheet after a loss.
func _show_over_hero(won_run: bool) -> void:
	for c in _over_hero.get_children():
		c.queue_free()
	var sheets: Dictionary = char_def.get("sheets", {})
	var sh := EnemySystem.load_sheet({"sheet": sheets.get("idle" if won_run else "hit", sheets.get("idle", ""))})
	if sh.is_empty():
		return
	var sv := SheetView.new(sh)
	sv.scale = Vector2(2, 2)
	var fs := sv.frame_size()
	sv.position = Vector2(floorf(28 - fs.x), 48 - fs.y * 2)
	_over_hero.add_child(sv)


## Coins on the result screen (and the multiplier line under them).
func _sync_over_coins(roll: bool) -> void:
	var earned := int(result.coins) * (2 if result.get("coins_doubled", false) else 1)
	var mult := ""
	if result.get("coins_doubled", false):
		mult = "DOUBLED!"
	elif director.coin_mult() > 1.0:
		mult = "FINAL SWARM X%.1f" % director.coin_mult()
	# Only what this run earned: the wallet total is the menu's business.
	_over_mult.text = mult
	if roll:
		_over_coins.count_to(earned, int(result.coins), 0.6)
	else:
		_over_coins.value = earned


func _over_lines() -> String:
	var sec := int(minf(elapsed, rules.run_length_sec))
	var lines := "TIME %d:%02d   LEVEL %d\nKO %d" % [sec / 60, sec % 60, level, kills]
	if final_swarm():
		var f := int(director.final_time)
		lines += "\nFINAL SWARM +%d:%02d" % [f / 60, f % 60]
	lines += "\nCOINS +%d" % (result.coins * (2 if result.get("coins_doubled", false) else 1))
	if result.get("coins_doubled", false):
		lines += "  X2"
	elif director.coin_mult() > 1.0:
		lines += "  X%.1f" % director.coin_mult()
	if _save != null:
		lines += "  (%d)" % int(meta.coins)
	return lines


# --- 2x coins (rewarded ad) ---------------------------------------------------

func _can_double() -> bool:
	return state == "over" and _save != null and int(result.get("coins", 0)) > 0 \
		and not result.get("coins_doubled", false) and _ad_offer("double_coins")


func _on_double_pressed() -> void:
	if not _can_double() or _ad_busy():
		return
	ads.show_rewarded("double_coins", func(granted: bool) -> void:
		if granted and state == "over" and not result.get("coins_doubled", false):
			# The run's coins once more, on top of what commit_run added.
			meta.coins = int(meta.coins) + int(result.coins)
			result.coins_doubled = true
			_save.save_game()
			_over_text.text = _over_lines()
			_sync_over_coins(true)
			toast("COINS X2!", "GOLD")
		_double_btn.visible = _can_double())


## Game over: progress toward the closest unlocks, and what's ready to buy
## (just unlocked ones marked NEW).
func _fill_over_progress() -> void:
	for c in _over_list.get_children():
		c.queue_free()
	# The build you ended with (tap a slot: nothing to see here, so no hint).
	var bv := BuildView.new()
	bv.name = "OverBuild"
	bv.size = Vector2(156, 0)
	bv.mouse_filter = Control.MOUSE_FILTER_PASS
	bv.setup(db, owned_weapons, owned_tomes, items.stacks, int(rules.weapon_slots), int(rules.tome_slots))
	_over_list.add_child(bv)
	var next := Meta.closest(db, meta, 3)
	if not next.is_empty():
		_over_list.add_child(_small_label("NEXT UNLOCKS", Palette.BUTTER))
		for n: Dictionary in next:
			var row := ChallengeRow.new().setup(n.challenge, n.progress, Meta.kind_name(db, n.challenge.reward))
			_over_list.add_child(row)
	var ready := Meta.ready_to_buy(db, meta)
	if not ready.is_empty():
		_over_list.add_child(_small_label("READY TO BUY", Palette.LIME))
		var just := {}
		for id: String in result.get("completed", []):
			just[db.get_entry("challenges", id).reward] = true
		for i in mini(ready.size(), 3):
			var id: String = ready[i]
			var price := int(Meta.challenge_for(db, id).price)
			var tag := "NEW! " if just.has(id) else ""
			_over_list.add_child(_small_label("%s%s  C %d" % [tag, Meta.content(db, id).name, price], Palette.LIME if just.has(id) else Palette.PAPER))
		if ready.size() > 3:
			_over_list.add_child(_small_label("+%d MORE IN UNLOCKS" % (ready.size() - 3), Palette.MIST))


func _small_label(text: String, color: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Palette.color(color))
	return l


func _pause(on: bool) -> void:
	if on and state == "live":
		state = "paused"
		_joystick.release()
		get_tree().paused = true
		_disarm_give_up()
		_sync_pause()
		_pause_panel.show()
		UiFx.slide_in(_pause_panel, Vector2(0, 30), 0.2)
	elif not on and state == "paused":
		state = "live"
		get_tree().paused = false
		_pause_panel.hide()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			# Like the pause button (never closes the game): pause, or resume
			# from the pause; leave the merchant; level-up and shrine cards
			# wait for a pick. Nothing while an ad is up.
			if _ad_busy():
				return
			if state == "over":
				_to_menu.call_deferred()
			elif state == "dying":
				_decline_revive()
			elif state == "choice":
				if _choice.get("leave", "") != "":
					_close_choice()
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


## Runs `fn` after `sec` seconds of run time (pauses with the run).
func later(sec: float, fn: Callable) -> void:
	_later.append([elapsed + sec, fn])


func _tick_later() -> void:
	if _later.is_empty():
		return
	var due := []
	for e: Array in _later:
		if elapsed >= e[0]:
			due.append(e)
	for e: Array in due:
		_later.erase(e)
		e[1].call()


func _music(id: String) -> void:
	if juice.audio != null and juice.audio.has_method("play_music"):
		juice.audio.play_music(id)


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
	_weapon_under.queue_redraw()
	if boss != null or _boss_view.visible:
		_boss_view.queue_redraw()
	_camera.position = _pos.round()
	_camera.offset = juice.offset
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
	_hud.set_build(owned_weapons, owned_tomes, int(rules.weapon_slots), int(rules.tome_slots))
	_hud.set_items(items.stacks)


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
	# The world draws into its own pixel view at a smaller whole-number scale
	# than the UI, so the player sees more of the map while menus, HUD and
	# cards keep their size (rules "world_view_scale"; see _fit_world_view).
	world_viewport = SubViewport.new()
	world_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	world_viewport.snap_2d_transforms_to_pixel = true
	world_viewport.snap_2d_vertices_to_pixel = true
	world_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(world_viewport)
	var layer := CanvasLayer.new()
	layer.layer = -1
	add_child(layer)
	_world_rect = TextureRect.new()
	_world_rect.texture = world_viewport.get_texture()
	_world_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_world_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_world_rect)
	_fit_world_view()
	get_viewport().size_changed.connect(_fit_world_view)

	map = MapLayout.new()
	map.setup(map_def)
	world_viewport.add_child(map)
	interactables = Interactables.new()
	interactables.setup(self, db)
	world_viewport.add_child(interactables)
	_boss_view = Node2D.new()
	_boss_view.draw.connect(func() -> void:
		if boss != null:
			boss.draw(_boss_view))
	world_viewport.add_child(_boss_view)

	gems = GemSystem.new()
	gems.setup(rules)
	gems.setup_effects(fx_rules, not _reduce_fx)
	world_viewport.add_child(gems)
	enemies = EnemySystem.new()
	enemies.setup(db.all("enemies"), int(rules.enemy_cap), bounds, int(rules.get("enemy_reserve", 48)))
	enemies.map = map
	enemies.event_fn = _on_enemy_event
	enemies.rng.seed = rng.seed ^ 0x5eed
	world_viewport.add_child(enemies)
	projectiles = ProjectileSystem.new()
	projectiles.setup(256)
	projectiles.default_sprite = rules.get("default_shot_sprite", "")
	projectiles.hit_fn = hit_enemy
	projectiles.trails = not _reduce_fx
	for w: Dictionary in db.all("weapons"):
		if w.has("trail"):
			projectiles.trail_colors[w.id] = Palette.index_of(w.trail)
	world_viewport.add_child(projectiles)
	enemy_shots = EnemyShots.new()
	enemy_shots.setup(int(rules.get("enemy_shots", 160)))
	world_viewport.add_child(enemy_shots)

	_weapon_under = Node2D.new()
	_weapon_under.draw.connect(func() -> void:
		for w in weapons:
			w.draw_under(_weapon_under, _pos))
	world_viewport.add_child(_weapon_under)
	_player_view = Node2D.new()
	_player_view.draw.connect(_draw_player)
	world_viewport.add_child(_player_view)
	_weapon_view = Node2D.new()
	_weapon_view.draw.connect(func() -> void:
		for w in weapons:
			w.draw(_weapon_view, _pos))
	world_viewport.add_child(_weapon_view)

	var particle_root := Node2D.new()
	world_viewport.add_child(particle_root)
	_particles = NodePool.new(particle_root, int(fx_rules.get("death_particles", 24)), _make_particles)
	fx = Fx.new()
	fx.reduced = _reduce_fx
	world_viewport.add_child(fx)
	danger = Fx.new()
	world_viewport.add_child(danger)
	numbers = DamageNumbers.new()
	numbers.enabled = _setting("damage_numbers", true)
	world_viewport.add_child(numbers)

	juice.build_overlays(world_viewport)
	interactables.place_from_map(map_def, map, rng, _pos)

	_camera = Camera2D.new()
	_camera.limit_left = int(bounds.position.x) - 8
	_camera.limit_top = int(bounds.position.y) - 8
	_camera.limit_right = int(bounds.end.x) + 8
	_camera.limit_bottom = int(bounds.end.y) + 8
	world_viewport.add_child(_camera)
	_camera.make_current()


## Enemy death: a pooled burst of palette pixels in the enemy's color that
## fades by dithering (assets/shaders/dither_fade.gdshader). Fewer pixels
## with "reduce effects".
func _make_particles() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = 4 if _reduce_fx else 8
	p.lifetime = 0.4
	p.explosiveness = 1.0
	p.spread = 180.0
	p.gravity = Vector2(0, 60)
	p.initial_velocity_min = 25.0
	p.initial_velocity_max = 55.0
	p.damping_min = 60.0
	p.damping_max = 90.0
	p.local_coords = false
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	var m := ShaderMaterial.new()
	m.shader = DITHER_FADE
	p.material = m
	return p


func _death_particles(at: Vector2, color: int) -> void:
	var p: CPUParticles2D = _particles.take()
	p.position = at.round()
	var tex: Texture2D = _particle_tex.get(color)
	if tex == null:
		tex = PlaceholderArt.texture("dot", color)
		_particle_tex[color] = tex
	if p.texture != tex:
		p.texture = tex
	p.restart()


func _draw_player() -> void:
	var v := _player_view
	_draw_player_hp_bar(v)
	# Blink during i-frames.
	if _iframes > 0.0 and int(_iframes * 20.0) % 2 == 0:
		return
	var flip := _facing.x < 0.0
	if not _sprites.is_empty():
		_draw_player_sprite(v, flip)
		return
	# Code-drawn fallback for characters without sheets yet.
	var ink := Palette.color(Palette.INK)
	# Loaf body 11x8 with a crust top, helmet 7x4 on top, visor slit.
	v.draw_rect(Rect2(-6, -3, 12, 8), ink)
	v.draw_rect(Rect2(-5, -2, 10, 6), Palette.color(Palette.DOUGH))
	v.draw_rect(Rect2(-5, -2, 10, 2), Palette.color(Palette.CRUST))
	v.draw_rect(Rect2(-4, -8, 8, 6), ink)
	v.draw_rect(Rect2(-3, -7, 6, 4), Palette.color(Palette.MIST))
	v.draw_rect(Rect2(1 if not flip else -3, -6, 2, 1), ink)
	v.draw_rect(Rect2(-1, -10, 2, 2), Palette.color(Palette.RED))  # plume


## Small HP bar under the hero's feet, in world pixels (rules "player_hp_bar":
## width, height, gap below the feet): INK outline, BLOOD track, GREEN fill
## (RED under 30%), shield as a SKY line on top. Drawn while blinking too.
func _draw_player_hp_bar(v: Node2D) -> void:
	var cfg: Dictionary = rules.get("player_hp_bar", {})
	if cfg.is_empty():
		return
	var w := int(cfg.get("width", 16))
	var h := int(cfg.get("height", 4))
	var top := Vector2(-w / 2, ceilf(player_radius()) + int(cfg.get("gap", 2)))
	var f := clampf(hp / stat("max_hp"), 0.0, 1.0)
	v.draw_rect(Rect2(top, Vector2(w, h)), Palette.color(Palette.INK))
	v.draw_rect(Rect2(top + Vector2.ONE, Vector2(w - 2, h - 2)), Palette.color(Palette.BLOOD))
	var fw := floorf((w - 2) * f)
	if fw > 0.0:
		v.draw_rect(Rect2(top + Vector2.ONE, Vector2(fw, h - 2)), Palette.color(Palette.RED if f < 0.3 else Palette.GREEN))
	if shield > 0.0:
		var sw := floorf((w - 2) * clampf(shield / stat("max_hp"), 0.0, 1.0))
		v.draw_rect(Rect2(top + Vector2.ONE, Vector2(sw, 1)), Palette.color(Palette.SKY))


## The clip the player sprite shows now: hit once after a hit, then walk
## while moving, else idle; "" without sheets.
func player_clip() -> String:
	if _sprites.has("hit") and elapsed - _hit_at < _sprites.hit.frames / _sprites.hit.fps:
		return "hit"
	if _moving and _sprites.has("walk"):
		return "walk"
	return "idle" if _sprites.has("idle") else ""


## Draws the frame of player_clip(). Sheets face right; the feet (sidecar origin) stand on the bottom of the
## collision circle.
func _draw_player_sprite(v: Node2D, flip: bool) -> void:
	var clip := player_clip()
	var t := elapsed - _hit_at if clip == "hit" else elapsed
	var sh: Dictionary = _sprites[clip]
	var tex: Texture2D = sh.texture
	var fw := int(tex.get_width() / sh.frames)
	var fh := tex.get_height()
	var frame := int(t * sh.fps) % int(sh.frames)
	var origin: Vector2 = sh.get("origin", Vector2(fw / 2, fh - 2))
	v.draw_set_transform(Vector2(0, player_radius()), 0.0, Vector2(-1 if flip else 1, 1))
	v.draw_texture_rect_region(tex, Rect2(-origin, Vector2(fw, fh)), Rect2(frame * fw, 0, fw, fh))
	v.draw_set_transform(Vector2.ZERO)


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 10
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui)
	_joystick = ThumbStick.new()
	ui.add_child(_joystick)
	_hud = Hud.new()
	_hud.db = db
	_hud.world_zoom = float(world_scale) / float(ui_scale)
	ui.add_child(_hud)
	juice.build_burst(ui)
	# Pause on screen (iOS has no back key), top right under the HUD rows.
	_pause_btn = SpriteButton.new()
	_pause_btn.name = "PauseButton"
	_pause_btn.part = "pause"
	_pause_btn.anchor_left = 1.0
	_pause_btn.anchor_right = 1.0
	_pause_btn.offset_left = -21
	_pause_btn.offset_right = -2
	_pause_btn.pressed.connect(_pause.bind(true))
	ui.add_child(_pause_btn)
	# Every modal panel sits over a dithered dim of the frozen world.
	_dim = DitherDim.new()
	_dim.hide()
	ui.add_child(_dim)
	_flash = DitherDim.new(true)
	_flash.color = Palette.RED
	ui.add_child(_flash)

	# Level-up cards in a panel, with the Reroll / Skip / Banish actions under them.
	_cards_panel = _panel(ui, Rect2(4, 14, 172, 296), Palette.NIGHT)
	_cards_title = _title(_cards_panel, "LEVEL UP!", Palette.BUTTER, 4)
	_cards_sub = _subtitle(_cards_panel, 27)
	for i in 3:
		var b := LevelCard.new()
		b.position = Vector2(CARD_X, CARD_Y + i * CARD_STEP)
		b.custom_minimum_size = Vector2(CARD_W, CARD_H)
		b.size = b.custom_minimum_size
		b.sound = ""  # _on_card plays "card"
		b.pressed.connect(_on_card.bind(i))
		_cards_panel.add_child(b)
		_card_buttons.append(b)
	var actions := Meta.ACTIONS
	for i in actions.size():
		var ab := ActionButton.new()
		ab.glyph = actions[i]
		ab.position = Vector2(CARD_X + i * 55, CARD_Y + 3 * CARD_STEP + 3)
		ab.custom_minimum_size = Vector2(50, 33)
		ab.size = ab.custom_minimum_size
		ab.pressed.connect(_on_action.bind(actions[i]))
		_cards_panel.add_child(ab)
		_action_buttons[actions[i]] = ab

	# Shrine bonus / merchant choices: the same cards, up to 3, and a leave button.
	_choice_panel = _panel(ui, Rect2(4, 14, 172, 296), Palette.NIGHT)
	_choice_title = _title(_choice_panel, "", Palette.BUTTER, 4)
	_choice_sub = _subtitle(_choice_panel, 27)
	for i in 3:
		var b := LevelCard.new()
		b.position = Vector2(CARD_X, CARD_Y + i * CARD_STEP)
		b.custom_minimum_size = Vector2(CARD_W, CARD_H)
		b.size = b.custom_minimum_size
		b.pressed.connect(_on_choice.bind(i))
		_choice_panel.add_child(b)
		_choice_buttons.append(b)
	_choice_leave = PixelButton.new()
	_choice_leave.position = Vector2(36, CARD_Y + 3 * CARD_STEP + 4)
	_choice_leave.custom_minimum_size = Vector2(100, 24)
	_choice_leave.size = _choice_leave.custom_minimum_size
	_choice_leave.face = Palette.MIST
	_choice_leave.pressed.connect(_close_choice)
	_choice_panel.add_child(_choice_leave)

	_build_over(ui)

	# Revive offer (rewarded ad) after a death.
	_revive_panel = _panel(ui, Rect2(16, 84, 148, 150), Palette.NIGHT)
	_title(_revive_panel, "TOASTED?", Palette.PAPER, 6)  # on the red ribbon
	var hit := EnemySystem.load_sheet({"sheet": char_def.get("sheets", {}).get("hit", char_def.get("sheets", {}).get("idle", ""))})
	if not hit.is_empty():
		var sv := SheetView.new(hit)
		sv.scale = Vector2(2, 2)
		sv.position = Vector2(74 - sv.frame_size().x, 30)
		_revive_panel.add_child(sv)
	var why := Label.new()
	why.text = "WATCH AN AD TO\nGET BACK UP!"
	why.position = Vector2(0, 80)
	why.size = Vector2(148, 20)
	why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	why.add_theme_color_override("font_color", Palette.color(Palette.MIST))
	_revive_panel.add_child(why)
	_revive_btn = AdButton.new()
	_revive_btn.label = "REVIVE"
	_revive_btn.face = Palette.LIME
	_revive_btn.position = Vector2(14, 102)
	_revive_btn.custom_minimum_size = Vector2(120, 22)
	_revive_btn.size = _revive_btn.custom_minimum_size
	_revive_btn.pressed.connect(_on_revive_pressed)
	_revive_panel.add_child(_revive_btn)
	var no := PixelButton.new()
	no.label = "NO THANKS"
	no.face = Palette.MIST
	no.small_text = true
	no.position = Vector2(34, 126)
	no.custom_minimum_size = Vector2(80, 16)
	no.size = no.custom_minimum_size
	no.pressed.connect(_decline_revive)
	_revive_panel.add_child(no)

	_build_pause(ui)
	_dim.watch = [_cards_panel, _choice_panel, _over_panel, _revive_panel, _pause_panel]
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)


## Pause: run facts, the build so far (tap a slot to see what it is and how
## it's doing), stats, sound toggles, RESUME and GIVE UP (asks for a second
## tap). The panel is as tall as the safe area; the buttons sit at its foot.
func _build_pause(ui: CanvasLayer) -> void:
	_pause_panel = _panel(ui, Rect2(6, 26, 168, 270), Palette.NIGHT)
	_pause_panel.anchor_top = 0.0
	_pause_panel.anchor_bottom = 1.0
	_title(_pause_panel, "PAUSED", Palette.PAPER, 6)
	_pause_facts = Label.new()
	_pause_facts.position = Vector2(0, 31)
	_pause_facts.size = Vector2(168, 10)
	_pause_facts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.bold(_pause_facts)
	_pause_facts.add_theme_color_override("font_color", Palette.color(Palette.BUTTER))
	_pause_panel.add_child(_pause_facts)
	_pause_build = BuildView.new()
	_pause_build.position = Vector2(12, 46)
	_pause_build.size = Vector2(144, 120)
	_pause_build.picked.connect(func(kind: String, id: String) -> void:
		_pause_pick = [kind, id]
		_pause_info.queue_redraw())
	_pause_panel.add_child(_pause_build)
	_pause_build.hint = "TAP TO SEE"
	_pause_info = Control.new()
	_pause_info.size = Vector2(152, 46)
	_pause_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_info.draw.connect(_draw_pause_info)
	_pause_panel.add_child(_pause_info)
	_pause_stats = Control.new()
	_pause_stats.position = Vector2(12, 120)
	_pause_stats.size = Vector2(144, 40)
	_pause_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_stats.draw.connect(_draw_pause_stats)
	_pause_panel.add_child(_pause_stats)
	for i in 2:
		var key: String = ["music", "sfx"][i]
		var t := PixelButton.new()
		t.name = "Toggle_" + key
		t.label = ["MUSIC", "SOUND"][i]
		t.face = Palette.MIST
		t.small_text = true
		t.position = Vector2(10 + i * 76, 182)
		t.custom_minimum_size = Vector2(72, 18)
		t.size = t.custom_minimum_size
		t.pressed.connect(func() -> void:
			if _save != null:
				_save.set_setting(key, not _save.get_setting(key))
			_sync_pause())
		_pause_panel.add_child(t)
		_pause_toggles[key] = t
	var resume := PixelButton.new()
	resume.label = "RESUME"
	resume.face = Palette.GREEN
	resume.position = Vector2(10, 204)
	resume.custom_minimum_size = Vector2(148, 28)
	resume.size = resume.custom_minimum_size
	resume.pressed.connect(_pause.bind(false))
	_pause_panel.add_child(resume)
	_pause_resume = resume
	_give_up = PixelButton.new()
	_give_up.label = "GIVE UP"
	_give_up.face = Palette.SALMON
	_give_up.position = Vector2(30, 238)
	_give_up.custom_minimum_size = Vector2(108, 20)
	_give_up.size = _give_up.custom_minimum_size
	_give_up.pressed.connect(func() -> void:
		if not _give_up_armed:
			_give_up_armed = true
			_give_up.label = "REALLY? TAP AGAIN"
			_give_up.face = Palette.RED
			get_tree().create_timer(2.5, true).timeout.connect(_disarm_give_up)
			return
		_disarm_give_up()
		_pause_panel.hide()
		get_tree().paused = false
		state = "live"
		_end("gave_up"))
	_pause_panel.add_child(_give_up)


## Pause layout for the panel's height `h`: build, hint, info box and stats
## from the top; toggles, RESUME and GIVE UP from the bottom.
func _layout_pause(h: float) -> void:
	var y := 44.0 + _pause_build.needed_height()
	_pause_info.position = Vector2(8, y)
	y += _pause_info.size.y + 3
	_pause_stats.position.y = y
	var bottom := h - 2.0
	_give_up.position.y = bottom - 5 - 18
	_give_up.size.y = 18
	_pause_resume.position.y = _give_up.position.y - 3 - 26
	_pause_resume.size.y = 26
	for key: String in _pause_toggles:
		_pause_toggles[key].position.y = _pause_resume.position.y - 3 - 16
		_pause_toggles[key].size.y = 16
	_pause_stats.visible = _pause_stats.position.y + 36 <= _pause_resume.position.y - 19


func _disarm_give_up() -> void:
	_give_up_armed = false
	_give_up.label = "GIVE UP"
	_give_up.face = Palette.SALMON


## Fills the pause panel with the run so far.
func _sync_pause() -> void:
	var sec := int(minf(elapsed, rules.run_length_sec))
	_pause_facts.text = "%d:%02d   LV %d   KO %d" % [sec / 60, sec % 60, level, kills]
	_pause_build.setup(db, owned_weapons, owned_tomes, items.stacks, int(rules.weapon_slots), int(rules.tome_slots))
	if _pause_pick.is_empty() or not _pause_has(_pause_pick):
		_pause_pick = ["weapons", owned_weapons.keys()[0]] if not owned_weapons.is_empty() else []
	_pause_build.selected = "" if _pause_pick.is_empty() else "%s/%s" % _pause_pick
	_layout_pause(_pause_panel.size.y)
	_pause_info.queue_redraw()
	_pause_stats.queue_redraw()
	for key: String in _pause_toggles:
		var on: bool = _save.get_setting(key) if _save != null else true
		_pause_toggles[key].toggle = int(on)


## Game over: title and reason, the hero, stat tiles, coins (rolling up),
## 2X COINS, closest unlocks, then PLAY AGAIN and MENU. Fills the screen
## inside the safe area.
func _build_over(ui: CanvasLayer) -> void:
	var p := PixelPanel.new()
	p.fill = Palette.NIGHT
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_bottom = 1.0
	p.offset_left = -86
	p.offset_right = 86
	p.hide()
	ui.add_child(p)
	_over_panel = p
	_over_title = _title(p, "", Palette.BUTTER, 6)
	_over_title.size.x = 86
	_over_reason = Label.new()
	_over_reason.position = Vector2(0, 30)
	_over_reason.size = Vector2(172, 10)
	_over_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_over_reason.add_theme_color_override("font_color", Palette.color(Palette.MIST))
	p.add_child(_over_reason)
	_over_hero = Control.new()
	_over_hero.position = Vector2(8, 42)
	_over_hero.size = Vector2(56, 52)
	_over_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(_over_hero)
	_over_tiles = Control.new()
	_over_tiles.position = Vector2(66, 42)
	_over_tiles.size = Vector2(100, 52)
	_over_tiles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over_tiles.draw.connect(_draw_over_tiles)
	p.add_child(_over_tiles)
	# The old one-block summary, kept for tests and screen readers of the result.
	_over_text = Label.new()
	_over_text.visible = false
	p.add_child(_over_text)
	var coins_cap := Label.new()
	coins_cap.text = "COINS EARNED"
	coins_cap.position = Vector2(10, 101)
	Fonts.bold(coins_cap)
	coins_cap.add_theme_color_override("font_color", Palette.color(Palette.GOLD))
	p.add_child(coins_cap)
	_over_coins = CoinPlate.new()
	_over_coins.position = Vector2(100, 98)
	_over_coins.size = Vector2(66, CoinPlate.H)
	p.add_child(_over_coins)
	_over_mult = Label.new()
	_over_mult.position = Vector2(10, 112)
	_over_mult.size = Vector2(152, 10)
	_over_mult.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_over_mult.add_theme_color_override("font_color", Palette.color(Palette.PINK))
	p.add_child(_over_mult)
	# 2x coins (rewarded ad), right under the coins it doubles.
	_double_btn = AdButton.new()
	_double_btn.label = "2X COINS"
	_double_btn.face = Palette.GOLD
	_double_btn.position = Vector2(26, 122)
	_double_btn.custom_minimum_size = Vector2(120, 20)
	_double_btn.size = _double_btn.custom_minimum_size
	_double_btn.pressed.connect(_on_double_pressed)
	_double_btn.hide()
	p.add_child(_double_btn)
	var scroll := DragScroll.new()
	scroll.position = Vector2(8, 146)
	scroll.size = Vector2(156, 100)
	p.add_child(scroll)
	_over_scroll = scroll
	var bar := scroll.make_bar()
	bar.position = Vector2(165, 146)
	bar.size = Vector2(2, 100)
	p.add_child(bar)
	scroll.resized.connect(func() -> void:
		bar.position = scroll.position + Vector2(scroll.size.x + 1, 0)
		bar.size = Vector2(2, scroll.size.y))
	_over_list = VBoxContainer.new()
	_over_list.custom_minimum_size = Vector2(156, 0)
	_over_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_over_list)
	_again_btn = PixelButton.new()
	_again_btn.name = "PlayAgain"
	_again_btn.label = "PLAY AGAIN"
	_again_btn.face = Palette.GREEN
	_again_btn.pressed.connect(_play_again)
	p.add_child(_again_btn)
	_menu_btn = PixelButton.new()
	_menu_btn.name = "Menu"
	_menu_btn.label = "MENU"
	_menu_btn.face = Palette.MIST
	_menu_btn.pressed.connect(_to_menu)
	p.add_child(_menu_btn)


## Run panels and the pause button keep clear of the cutout and gesture bar.
func _apply_safe_area() -> void:
	var top := SafeArea.top(get_viewport())
	var bottom := SafeArea.bottom(get_viewport())
	_hud.safe_top = top
	_hud.safe_bottom = bottom
	_pause_btn.offset_top = Hud.PAUSE_Y + top
	_pause_btn.offset_bottom = Hud.PAUSE_Y + top + 21
	_pause_panel.offset_top = top + 6
	_pause_panel.offset_bottom = -(bottom + 6)
	_layout_pause(get_viewport().get_visible_rect().size.y - top - bottom - 12)
	_over_panel.offset_top = top + 4
	_over_panel.offset_bottom = -(bottom + 4)
	var h := get_viewport().get_visible_rect().size.y - top - bottom - 8
	_over_scroll.size.y = maxf(40.0, h - 2 - 146 - 40)
	for b: PixelButton in [_again_btn, _menu_btn]:
		b.position.y = h - 2 - 34
		b.custom_minimum_size.y = 26
		b.size.y = 26
	_again_btn.position.x = 8
	_again_btn.custom_minimum_size.x = 100
	_again_btn.size.x = 100
	_menu_btn.position.x = 112
	_menu_btn.custom_minimum_size.x = 52
	_menu_btn.size.x = 52


func _pause_has(pick: Array) -> bool:
	match pick[0]:
		"weapons":
			return owned_weapons.has(pick[1])
		"tomes":
			return owned_tomes.has(pick[1])
		"items":
			return items.stacks.has(pick[1])
	return false


## The picked slot: icon, name, kind and level, what it does now, and for a
## weapon how hard it hits and how many it has knocked out this run.
func _draw_pause_info() -> void:
	var ci := _pause_info
	var r := Rect2(Vector2.ZERO, ci.size)
	ci.draw_rect(r, Palette.color(Palette.INK))
	ci.draw_rect(r.grow(-1), Palette.color(Palette.DEEP_BLUE))
	ci.draw_rect(Rect2(2, 1, r.size.x - 4, 1), Palette.color(Palette.OCEAN))
	if _pause_pick.is_empty():
		return
	var kind: String = _pause_pick[0]
	var id: String = _pause_pick[1]
	var def := db.get_entry(kind, id)
	var tex := Icons.texture(db, kind, id)
	ci.draw_rect(Rect2(4, 4, 18, 18), Palette.color(Palette.INK))
	ci.draw_rect(Rect2(5, 5, 16, 16), Palette.color(Palette.NIGHT))
	if tex != null:
		ci.draw_texture(tex, Vector2(5, 5))
	var name_t: String = def.get("name", id)
	var nf := Fonts.fitting(name_t, r.size.x - 30)
	ci.draw_string(nf, Vector2(26, 12), name_t, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(Palette.INK))
	ci.draw_string(nf, Vector2(26, 11), name_t, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(Palette.BUTTER))
	var sub := ""
	var desc: String = def.get("desc", "")
	var extra := ""
	var sub_c := Palette.MIST
	match kind:
		"weapons":
			var lvl := int(owned_weapons[id])
			sub = "WEAPON  LV %d/%d" % [lvl, def.levels.size()]
			sub_c = Palette.SALMON
			var ld: Dictionary = def.levels[lvl - 1]
			if ld.has("damage"):
				extra = "DMG %d   " % roundi(float(ld.damage) * stat("damage"))
			extra += "KO %d" % int(run_stats.get("kills." + id, 0.0))
		"tomes":
			var lvl := int(owned_tomes[id])
			sub = "MANUAL  LV %d/%d" % [lvl, int(rules.get("max_level", 5))]
			sub_c = Palette.SKY
			extra = "EACH LEVEL: " + desc
			desc = _tome_total(def, lvl)
		"items":
			var loot := db.get_entry("rules", "loot")
			sub = "%s ITEM" % String(loot.rarity_names.get(def.rarity, ""))
			sub_c = Palette.index_of(loot.rarity_colors.get(def.rarity, "MIST"))
			if int(items.stacks[id]) > 1:
				sub += "  X%d" % int(items.stacks[id])
	ci.draw_string(Fonts.SMALL, Vector2(26, 20), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(sub_c))
	ci.draw_string(Fonts.SMALL, Vector2(5, 32), desc, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, 8, Palette.color(Palette.PAPER))
	ci.draw_string(Fonts.SMALL, Vector2(5, 42), extra, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, 8, Palette.color(Palette.LIME))


## What a tome gives in total at `lvl`: the first number in its per-level
## description times the level ("+10% DAMAGE" at LV 3 -> "NOW +30% DAMAGE").
func _tome_total(def: Dictionary, lvl: int) -> String:
	var desc: String = def.get("desc", "")
	var re := RegEx.new()
	re.compile("\\d+(\\.\\d+)?")
	var m := re.search(desc)
	if m == null:
		return desc
	var v := float(m.get_string()) * lvl
	var num := str(int(v)) if v == floorf(v) else "%.1f" % v
	return "NOW " + desc.substr(0, m.get_start()) + num + desc.substr(m.get_end())


func _draw_pause_stats() -> void:
	var ci := _pause_stats
	var rows := [
		["DMG", "X%.2f" % stat("damage")], ["ARMOR", "%d" % int(stat("armor"))],
		["SPEED", "%d" % int(stat("move_speed"))], ["REGEN", "%.1f" % stat("regen")],
		["CRIT", "%d%%" % roundi(stat("crit_chance") * 100.0)], ["LUCK", "%d%%" % roundi(stat("luck") * 100.0)],
	]
	ci.draw_string(Fonts.BOLD, Vector2(0, 8), "STATS", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(Palette.MIST))
	ci.draw_rect(Rect2(38, 4, ci.size.x - 38, 1), Palette.color(Palette.SHADE))
	for i in rows.size():
		var at := Vector2((i % 2) * 74, 18 + (i / 2) * 9)
		ci.draw_string(Fonts.SMALL, at, rows[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(Palette.GRAY))
		var v: String = rows[i][1]
		var vw := Fonts.BOLD.get_string_size(v, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		ci.draw_string(Fonts.BOLD, at + Vector2(68 - vw, 0), v, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(Palette.PAPER))


func _draw_over_tiles() -> void:
	var ci := _over_tiles
	var sec := int(minf(elapsed, rules.run_length_sec))
	var tiles := [
		["clock", "%d:%02d" % [sec / 60, sec % 60], "TIME"],
		["star", str(level), "LEVEL"],
		["skull", str(kills), "KO"],
		["coin", str(floori(gold)), "GOLD"],
	]
	for i in 4:
		var at := Vector2((i % 2) * 51, (i / 2) * 27)
		var r := Rect2(at, Vector2(49, 25))
		ci.draw_rect(r, Palette.color(Palette.INK))
		ci.draw_rect(r.grow(-1), Palette.color(Palette.DEEP_BLUE))
		ci.draw_rect(Rect2(r.position + Vector2(2, 1), Vector2(r.size.x - 4, 1)), Palette.color(Palette.OCEAN))
		Glyphs.draw(ci, tiles[i][0], at + Vector2(4, 4))
		ci.draw_string(Fonts.SMALL, at + Vector2(14, 10), tiles[i][2], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(Palette.MIST))
		ci.draw_string(Fonts.BOLD, at + Vector2(5, 22), tiles[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(Palette.INK))
		ci.draw_string(Fonts.BOLD, at + Vector2(5, 21), tiles[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(Palette.PAPER))


## A hidden panel. `rect` is in a 180x320 design frame; the panel is
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


## A small centred line under a panel title ("PICK ONE"), MIST.
func _subtitle(parent: Control, y: int) -> Label:
	var l := Label.new()
	l.position = Vector2(0, y)
	l.size = Vector2(parent.size.x, 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Palette.color(Palette.PAPER))
	l.add_theme_color_override("font_shadow_color", Palette.color(Palette.INK))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(l)
	return l


## A 2x bold title on the red ribbon. Returns the Label that holds the text
## (hidden: a PixelTitle draws it, following the label's text).
func _title(parent: Control, text: String, color: int, y: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = Vector2(0, y)
	l.size = Vector2(parent.size.x / 2.0, 10)
	l.scale = Vector2(2, 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Palette.color(color))
	l.self_modulate = Color(1, 1, 1, 0)
	parent.add_child(l)
	UiArt.ribbon_behind(l)
	var big := PixelTitle.new(text, 2, color)
	big.top_color = Palette.WHITE if color in [Palette.BUTTER, Palette.GOLD] else -1
	big.position = Vector2(0, y - 1)
	big.size = Vector2(parent.size.x, 22)
	parent.add_child(big)
	# Follow the label: its text and colour can change (game over titles).
	l.draw.connect(func() -> void:
		big.text = l.text
		big.size.x = l.size.x * 2.0)
	l.set_meta("big", big)
	return l


## Again with the same hero and map. A break like the way to the menu, so
## an interstitial may show first (Ads decides).
func _play_again() -> void:
	if _leaving or _ad_busy():
		return
	_leaving = true
	Run.next_options = {"character": char_def.id, "map": map_def.id}
	var go := func(_shown := false) -> void:
		get_tree().paused = false
		var tr := get_node_or_null("/root/Transition")
		if tr != null:
			tr.change_scene(RUN_SCENE)
		else:
			get_tree().change_scene_to_file(RUN_SCENE)
	if ads != null and state == "over":
		ads.at_break(go)
	else:
		go.call()


## Back to the menu. After a game over this is the one break where an
## interstitial may show (Ads decides); the menu loads once it's gone.
func _to_menu() -> void:
	if _leaving or _ad_busy():
		return
	_leaving = true
	_menu_btn.disabled = true
	if ads != null and state == "over":
		ads.at_break(func(_shown: bool) -> void: _go_to_menu())
	else:
		_go_to_menu()


func _go_to_menu() -> void:
	get_tree().paused = false
	var tr := get_node_or_null("/root/Transition")
	if tr != null:
		tr.change_scene(MENU_SCENE)
	else:
		get_tree().change_scene_to_file(MENU_SCENE)

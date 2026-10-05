class_name Run
extends Node2D
## One run: player, weapons, enemies, gems, level-ups, timer, game over.
## All game logic advances in tick(delta), so headless tests and the bot
## simulation can step a run without real time passing.
##
## Event hooks for items (phase 2) and the stat tracker (phase 4) are the
## signals below; nothing listens to them yet in phase 1.

signal on_hit(enemy_slot: int, amount: float)
signal on_kill(enemy_slot: int, enemy_id: String)
signal on_damaged(amount: float)
signal on_level_up(new_level: int)
signal run_ended(result: Dictionary)

const MENU_SCENE := "res://scenes/main_menu.tscn"
## Spawns appear this far outside the visible area.
const SPAWN_MARGIN := Vector2(10, 10)
const RECYCLE_EVERY := 0.25
const PARTICLES := 16

## Options for the next run, set before switching to the run scene (bots,
## stress test). Copied into `options` and cleared on _ready.
static var next_options := {}

## bot: steer automatically. auto_cards: take the first card without pausing.
## invincible: ignore damage. no_save: don't write the result to the save.
## stress: keep the enemy count at the cap, spawned on screen.
## rules: overrides for data/rules/run.json keys. seed: RNG seed.
var options := {}
var db: GameData
var rules: Dictionary
var map_def: Dictionary
var char_def: Dictionary
var rng := RandomNumberGenerator.new()
var stats: StatBlock
var spawner: Spawner
var bounds := Rect2()

var hp := 0.0
var level := 1
var xp := 0.0
var kills := 0
var elapsed := 0.0
## "live", "level_up", "paused" or "over".
var state := "live"
var won := false
var weapons: Array[Weapon] = []
var owned_weapons := {}  # id -> level
var owned_tomes := {}  # id -> level
var pending_levels := 0
var result := {}
## Time the last _process (logic + render prep) took, for the stress test.
var last_frame_usec := 0

var enemies: EnemySystem
var gems: GemSystem
var projectiles: ProjectileSystem
var numbers: DamageNumbers

var _pos := Vector2.ZERO
var _facing := Vector2.RIGHT
var _iframes := 0.0
var _recycle_t := 0.0
var _pack_sizes := {}
var _hits := PackedInt32Array()
var _player_view: Node2D
var _weapon_view: Node2D
var _camera: Camera2D
var _particles: NodePool
var _reduce_fx := false
var _hud: Hud
var _joystick: ThumbStick
var _cards_panel: Control
var _card_buttons: Array[PixelButton] = []
var _cards: Array = []
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
	if options.has("seed"):
		rng.seed = int(options.seed)
	else:
		rng.randomize()

	bounds = Rect2(Vector2.ZERO, Vector2(map_def.size[0], map_def.size[1]))
	_pos = bounds.get_center()
	stats = StatBlock.new(char_def.stats)
	hp = stat("max_hp")
	spawner = Spawner.new(map_def, int(rules.enemy_cap))
	for e: Dictionary in db.all("enemies"):
		if e.has("pack_size"):
			_pack_sizes[e.id] = e.pack_size
	_reduce_fx = _setting("reduce_effects", false)

	_build_world()
	_build_ui()
	_give_weapon(char_def.signature_weapon)
	_render()


func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	tick(delta)
	_render()
	last_frame_usec = Time.get_ticks_usec() - t0


## Advances the run by `delta` seconds (clamped to rules.max_dt).
func tick(delta: float) -> void:
	if state != "live":
		return
	delta = minf(delta, rules.max_dt)
	elapsed += delta
	var minute := elapsed / 60.0

	if options.get("stress", false):
		_stress_fill()
	else:
		for req: Dictionary in spawner.tick(delta, minute, enemies.count(), _pack_sizes, rng):
			_spawn_group(req)

	var dir: Vector2 = _joystick.read()
	if options.get("stress", false):
		dir = Vector2.from_angle(elapsed * 0.8) * 0.4  # slow circle, keeps the horde on screen
	elif options.get("bot", false):
		dir = _bot_dir()
	if dir.length_squared() > 0.01:
		_facing = dir.normalized()
	var r: float = char_def.radius
	_pos = (_pos + dir * stat("move_speed") * delta).clamp(bounds.position + Vector2(r, r), bounds.end - Vector2(r, r))
	hp = minf(hp + stat("regen") * delta, stat("max_hp"))

	enemies.update(delta, _pos)
	_recycle_t -= delta
	if _recycle_t <= 0.0:
		_recycle_t = RECYCLE_EVERY
		_recycle_far_enemies()
	for w in weapons:
		w.update(delta, self)
	projectiles.update(delta, enemies)
	_contact_damage(delta, minute)

	var got := gems.update(delta, _pos, stat("pickup_range"))
	if got > 0.0:
		add_xp(got)
	numbers.update(delta)

	if hp <= 0.0:
		_end(false)
	elif elapsed >= rules.run_length_sec:
		_end(true)
	elif pending_levels > 0:
		_open_level_up()


func stat(name: String) -> float:
	return stats.get_value(name)


func player_pos() -> Vector2:
	return _pos


func facing_angle() -> float:
	return _facing.angle()


func seconds_left() -> float:
	return maxf(0.0, rules.run_length_sec - elapsed)


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
		need = xp_needed(rules.xp_curve, level)


## Damages an enemy (from any weapon). Handles the kill.
func hit_enemy(slot: int, amount: float, push: Vector2) -> void:
	if not enemies.pool.is_alive(slot):
		return
	on_hit.emit(slot, amount)
	numbers.show_number(enemies.pos[slot], amount)
	if enemies.hurt(slot, amount, push):
		_kill(slot)


func enemies_on_screen() -> int:
	var view := _view_rect()
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
			owned_tomes[card.id] = card.level
			for m: Dictionary in card.def.modifiers_per_level:
				stats.set_modifier(m.stat, "tome:" + card.id, m.get("flat", 0.0) * card.level, m.get("pct", 0.0) * card.level)
			hp += maxf(0.0, stat("max_hp") - before)
		"fallback":
			hp = minf(hp + card.def.get("heal", 0.0), stat("max_hp"))


# --- Run flow -------------------------------------------------------------

func _give_weapon(id: String) -> void:
	var def := db.get_entry("weapons", id)
	if def.is_empty():
		push_error("Run: weapon '%s' not found" % id)
		return
	weapons.append(Weapon.create(def))
	owned_weapons[id] = 1


func _spawn_group(req: Dictionary) -> void:
	var type_id: int = enemies.type_index[req.enemy]
	var def: Dictionary = enemies.types[type_id]
	var minute := elapsed / 60.0
	var growth: float = 1.0 + def.get("hp_growth_per_minute", 0.0) * minute
	var base := Spawner.edge_point(rng, _pos, _half_view() + SPAWN_MARGIN, bounds)
	var spread: float = def.get("pack_spread", 0.0)
	for i in req.count:
		var at := base
		if req.grouped:
			at += Vector2(rng.randf_range(-spread, spread), rng.randf_range(-spread, spread))
		enemies.spawn(type_id, at.clamp(bounds.position, bounds.end), growth * spawner.hp_mult(), spawner.damage_mult(), spawner.speed_mult())


## Stress test: keep the enemy count at the cap and every enemy on screen.
## New and stray enemies are placed inside the view, away from the player.
func _stress_fill() -> void:
	var view := _view_rect().intersection(bounds).grow(-4.0)
	var n := enemies.types.size()
	for s in enemies.pool.active:
		if not view.has_point(enemies.pos[s]):
			enemies.move_to(s, _stress_point(view))
	while enemies.count() < int(rules.enemy_cap):
		enemies.spawn(enemies.count() % n, _stress_point(view), 1.0, 1.0, 1.0)


func _stress_point(view: Rect2) -> Vector2:
	while true:
		var at := Vector2(rng.randf_range(view.position.x, view.end.x), rng.randf_range(view.position.y, view.end.y))
		if at.distance_squared_to(_pos) >= 40.0 * 40.0:
			return at
	return view.position


## Enemies left far behind are moved back near the player instead of being
## culled, so the horde keeps up and the count stays meaningful.
func _recycle_far_enemies() -> void:
	var far: float = map_def.get("despawn_distance", 260.0)
	var far2 := far * far
	for s in enemies.pool.active:
		if enemies.pos[s].distance_squared_to(_pos) > far2:
			enemies.move_to(s, Spawner.edge_point(rng, _pos, _half_view() + SPAWN_MARGIN, bounds))


## Half the visible area in world pixels. The view is at least 180x320 and
## grows on taller or wider screens (stretch aspect "expand").
func _half_view() -> Vector2:
	return get_viewport_rect().size / 2.0


func _view_rect() -> Rect2:
	return Rect2(_pos - _half_view(), _half_view() * 2.0)


func _contact_damage(delta: float, minute: float) -> void:
	if _iframes > 0.0:
		_iframes -= delta
		return
	enemies.query_circle(_pos, char_def.radius, _hits)
	if _hits.is_empty():
		return
	var worst := 0.0
	for s in _hits:
		worst = maxf(worst, enemies.damage[s])
	var dmg := worst * Passives.damage_taken_mult(char_def.passive, minute)
	dmg = maxf(1.0, dmg - stat("armor"))
	_iframes = rules.player_iframes
	if options.get("invincible", false):
		return
	hp -= dmg
	on_damaged.emit(dmg)


func _kill(slot: int) -> void:
	var type_id := enemies.type_of[slot]
	var def: Dictionary = enemies.types[type_id]
	var at := enemies.pos[slot]
	gems.drop(at, def.xp)
	if not _reduce_fx:
		var p: CPUParticles2D = _particles.take()
		p.position = at.round()
		p.texture = PlaceholderArt.texture("dot", Palette.index_of(def.color))
		p.restart()
	kills += 1
	on_kill.emit(slot, def.id)
	enemies.remove(slot)


func _open_level_up() -> void:
	_cards = LevelUpCards.pick(rng, db, owned_weapons, owned_tomes, rules)
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


func _end(survived: bool) -> void:
	state = "over"
	won = survived
	gems.pull_all()
	var c: Dictionary = rules.coins
	var coins := floori((c.per_minute * elapsed / 60.0 + c.per_kill * kills) * (1.0 if won else c.death_multiplier))
	result = {"won": won, "time": elapsed, "level": level, "kills": kills, "coins": coins}
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
	_over_title.text = "SURVIVED!" if won else "TOASTED!"
	_over_title.add_theme_color_override("font_color", Palette.color(Palette.BUTTER if won else Palette.RED))
	var sec := int(elapsed)
	_over_text.text = "TIME  %d:%02d\nLEVEL  %d\nKO  %d\nCOINS  +%d" % [sec / 60, sec % 60, level, kills, coins]
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


## Simple bot: dodge enemies that get closer than the swing reach, drift
## toward the map center otherwise. Used for sims and tests, not balance truth.
func _bot_dir() -> Vector2:
	var away := Vector2.ZERO
	enemies.query_circle(_pos, 22.0, _hits)
	for s in _hits:
		var off := _pos - enemies.pos[s]
		away += off / maxf(off.length_squared(), 1.0)
	var home := (bounds.get_center() - _pos) * 0.0004
	var wander := Vector2.from_angle(elapsed * 0.35) * 0.02
	var d := away * 8.0 + home + wander
	return d.normalized() if d.length() > 0.01 else Vector2.ZERO


func _setting(key: String, fallback: Variant) -> Variant:
	var save := get_node_or_null("/root/Save")
	return save.get_setting(key) if save != null else fallback


# --- Drawing --------------------------------------------------------------

func _render() -> void:
	enemies.render()
	gems.render()
	projectiles.render()
	_player_view.position = _pos.round()
	_player_view.queue_redraw()
	_weapon_view.queue_redraw()
	_camera.position = _pos.round()
	_hud.hp = hp
	_hud.hp_max = stat("max_hp")
	_hud.xp = xp
	_hud.xp_need = xp_needed(rules.xp_curve, level)
	_hud.set_values(level, seconds_left(), kills)


func _build_world() -> void:
	# Fence: filled rects under the ground sprite, so only a border shows.
	var fence := Node2D.new()
	fence.draw.connect(func() -> void:
		fence.draw_rect(bounds.grow(5), Palette.color(Palette.CRUST))
		fence.draw_rect(bounds.grow(1), Palette.color(Palette.INK)))
	add_child(fence)
	var ground := Sprite2D.new()
	var cols: Array = map_def.get("ground_colors", ["LEAF", "DEEP_GREEN", "GREEN"])
	ground.texture = _lawn(Palette.index_of(cols[0]), Palette.index_of(cols[1]), Palette.index_of(cols[2]))
	ground.centered = false
	ground.region_enabled = true
	ground.region_rect = bounds
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_child(ground)

	gems = GemSystem.new()
	gems.setup(rules)
	add_child(gems)
	enemies = EnemySystem.new()
	enemies.setup(db.all("enemies"), int(rules.enemy_cap), bounds)
	add_child(enemies)
	projectiles = ProjectileSystem.new()
	projectiles.setup(128)
	projectiles.hit_fn = hit_enemy
	add_child(projectiles)

	_player_view = Node2D.new()
	_player_view.draw.connect(_draw_player)
	add_child(_player_view)
	_weapon_view = Node2D.new()
	_weapon_view.draw.connect(func() -> void:
		for w in weapons:
			w.draw(_weapon_view, _pos))
	add_child(_weapon_view)

	var fx := Node2D.new()
	add_child(fx)
	_particles = NodePool.new(fx, PARTICLES, _make_particles)
	numbers = DamageNumbers.new()
	numbers.enabled = _setting("damage_numbers", true)
	add_child(numbers)

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


## Lawn texture (64x64, tiles seamlessly): base color plus scattered tufts in
## a darker and a lighter shade, placed from a fixed seed.
func _lawn(base: int, dark: int, light: int) -> ImageTexture:
	var img := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Palette.color(base))
	var r := RandomNumberGenerator.new()
	r.seed = 7
	for i in 18:
		var t := Vector2i(r.randi_range(0, 61), r.randi_range(1, 63))
		var col := Palette.color(dark if i % 3 != 0 else light)
		img.set_pixelv(t, col)
		img.set_pixelv(t + Vector2i(1, -1), col)
		img.set_pixelv(t + Vector2i(2, 0), col)
	return ImageTexture.create_from_image(img)


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

	# Game over.
	_over_panel = _panel(ui, Rect2(14, 70, 152, 170), Palette.NIGHT)
	_over_title = _title(_over_panel, "", Palette.BUTTER, 10)
	_over_text = Label.new()
	_over_text.position = Vector2(0, 40)
	_over_text.size = Vector2(152, 60)
	_over_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_over_panel.add_child(_over_text)
	var menu_btn := PixelButton.new()
	menu_btn.label = "BACK TO MENU"
	menu_btn.position = Vector2(20, 130)
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
		_end(false))
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

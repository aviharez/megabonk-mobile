extends RefCounted
## Phase 7: audio and VFX. Every audio file loads; the Audio manager caps its
## voices and respects priorities and settings; every key run event makes a
## sound (Juice.cues) and a visible effect; settings turn off damage
## numbers, screen shake and the cosmetic effects; hit-stop, the level-up
## burst, the chest beam, the low-HP vignette and the Final Swarm tint work.

const RUN_SCENE := preload("res://scenes/run.tscn")
const AUDIO := preload("res://scripts/autoload/audio.gd")
const DT := 1.0 / 30.0


func _start(t, opts: Dictionary) -> Run:
	var o := {"bot": true, "auto_cards": true, "no_save": true, "seed": 9, "no_spawns": true, "invincible": true}
	o.merge(opts, true)
	Run.next_options = o
	var run: Run = RUN_SCENE.instantiate()
	t.root.add_child(run)
	return run


func _done(t, run: Run) -> void:
	t.paused = false
	run.free()


func _fx_total(run: Run) -> int:
	var n := 0
	for f: Fx in [run.fx, run.danger]:
		for k in f.added:
			n += int(f.added[k])
	return n


## An enemy of `id` next to the player (not touching it).
func _enemy(run: Run, id: String, off := Vector2(30, 0)) -> int:
	return run.spawn_enemy(id, run.player_pos() + off)


func test_audio_files_load(t) -> void:
	var rules := GameData.shared().get_entry("rules", "audio")
	var bad := []
	for id: String in rules.sfx:
		var s: AudioStream = load(rules.sfx[id].file)
		if s == null or s.get_length() <= 0.0 or s.get_length() > 3.0:
			bad.append(id)
	t.check(bad.is_empty(), "every sound loads and is under 3 s (bad: %s)" % [bad])
	for id: String in GameData.MUSIC_TRACKS:
		var m: AudioStream = load(rules.music[id])
		t.check(m is AudioStreamOggVorbis and m.get_length() >= 20.0, "music %s is an OGG loop of 20 s or more" % id)
	# The generator's recipe list and the game's list name the same sounds.
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/audio/sfx.json"))
	var made: Array = spec.sounds.map(func(s: Dictionary) -> String: return s.id)
	made.sort()
	var listed: Array = rules.sfx.keys()
	listed.sort()
	t.check(made == listed, "tools/audio/sfx.json and data/rules/audio.json list the same sounds")


func test_voice_cap_and_priority(t) -> void:
	var a: Node = AUDIO.new()
	t.root.add_child(a)
	var cap: int = a.voice_cap()
	t.check(cap == int(GameData.shared().get_entry("rules", "audio").voices), "voices from data (%d)" % cap)
	# Many different long sounds at once: never more than the cap.
	var long := ["boss_roar", "final", "boss_down", "death", "alarm", "portal", "escape", "fuse", "boss_slam",
		"level_up", "shrine", "revive", "boss_dig", "boom", "pop", "chest", "beam", "merchant"]
	for id: String in long:
		a.play(id)
	t.check(a.voices_busy() <= cap, "busy voices %d <= cap %d" % [a.voices_busy(), cap])
	t.check(a.voices_busy() == cap, "the pool filled up")
	# Full of high-priority sounds: a priority-0 hit is dropped.
	var before: int = a.dropped
	t.check(not a.play("hit") and a.dropped == before + 1, "a low-priority hit can't steal a voice from a roar")
	# The same sound twice inside its gap: the second is skipped.
	var b: Node = AUDIO.new()
	t.root.add_child(b)
	t.check(b.play("kill") and not b.play("kill"), "a sound inside its gap is skipped")
	a.free()
	b.free()


func test_audio_follows_settings(t) -> void:
	var save: Node = t.root.get_node_or_null("Save")
	var audio: Node = t.root.get_node_or_null("Audio")
	t.check(save != null and audio != null, "Save and Audio autoloads")
	if save == null or audio == null:
		return
	var old_sfx: bool = save.get_setting("sfx")
	var old_music: bool = save.get_setting("music")
	var old_path: String = save.path
	save.path = "user://test_audio_save.json"
	save.set_setting("sfx", false)
	save.set_setting("music", false)
	t.check(not audio.sfx_enabled() and not audio.music_enabled(), "sounds and music off -> buses muted")
	save.set_setting("sfx", true)
	save.set_setting("music", true)
	t.check(audio.sfx_enabled() and audio.music_enabled(), "back on -> unmuted")
	save.data.settings.sfx = old_sfx
	save.data.settings.music = old_music
	audio.apply_settings()
	DirAccess.remove_absolute(save.path)
	DirAccess.remove_absolute(save.path + ".bak")
	save.path = old_path


## Every key event: [label, cue id, trigger(run) -> void, effect seen(run, fx_before) -> bool].
func test_every_key_event_has_a_sound_and_an_effect(t) -> void:
	var run := _start(t, {})
	run.stats.set_modifier("crit_chance", "test", -1.0)
	var events := [
		["weapon hit", "hit", func(r: Run) -> void: r.hit_enemy(_enemy(r, "chomper"), 1.0, Vector2.ZERO, "baguette"),
			func(r: Run, n: int) -> bool: return r.fx.added.get(Fx.PUFF, 0) > 0 and _fx_total(r) > n],
		["weapon attack", "swing", func(r: Run) -> void:
			r.weapons[0]._cooldown = 0.0
			r.weapons[0].update(DT, r),
			func(r: Run, _n: int) -> bool: return r.weapons[0]._swinging],  # the drawn swing
		["enemy killed", "kill", func(r: Run) -> void: r.hit_enemy(_enemy(r, "blob"), 9999.0, Vector2.ZERO, "baguette"),
			func(r: Run, _n: int) -> bool: return r._particles.nodes.any(func(p: CPUParticles2D) -> bool: return p.emitting)],
		["player hurt", "hurt", func(r: Run) -> void:
			r._iframes = 0.0
			r.damage_player(5.0, "blob"),
			func(r: Run, n: int) -> bool:
				r.juice.update(DT, 1.0)
				return _fx_total(r) > n and r.juice.offset != Vector2.ZERO],
		["dodge", "dodge", func(r: Run) -> void:
			r._iframes = 0.0
			r.stats.set_modifier("evasion", "test", 1.0)
			r.damage_player(5.0, "blob")
			r.stats.remove_modifier("evasion", "test"),
			func(r: Run, n: int) -> bool: return r.fx.added.get(Fx.STAR, 0) > 0 and _fx_total(r) > n],
		["gem picked up", "gem", func(r: Run) -> void:
			r.gems.drop(r.player_pos() + Vector2(6, 0), 1.0)
			for i in 10: r.tick(DT),
			func(r: Run, _n: int) -> bool: return r.gems.collected > 0 and r.gems.effects],
		["chest", "beam", func(r: Run) -> void: r.open_chest("paid", r.player_pos() + Vector2(10, 0)),
			func(r: Run, n: int) -> bool: return r.fx.live_of(Fx.BEAM) == 1 and _fx_total(r) > n],
		["chest pops after the beam", "chest", func(r: Run) -> void:
			for i in 20: r.tick(DT),
			func(r: Run, _n: int) -> bool: return r.fx.added.get(Fx.SPARKS, 0) > 0],
		["shrine", "shrine", func(r: Run) -> void: r.shrine_activated("charge_shrine"),
			func(r: Run, n: int) -> bool: return _fx_total(r) > n],
		["pot", "pot", func(r: Run) -> void:
			# Something that appears underfoot waits for the player to step on it.
			r.interactables.add("pot", r.player_pos()).inside = false
			r.tick(DT),
			func(r: Run, n: int) -> bool: return _fx_total(r) > n],
		["key", "key", func(r: Run) -> void:
			# Something that appears underfoot waits for the player to step on it.
			r.interactables.add("cage_key", r.player_pos()).inside = false
			r.tick(DT),
			func(r: Run, n: int) -> bool: return r.interactables.has_key and _fx_total(r) > n],
		["merchant", "merchant", func(r: Run) -> void:
			r._merchant_at = 0.0
			r.tick(DT),
			func(r: Run, n: int) -> bool: return _fx_total(r) > n],
		["blast (fireworks, items)", "boom", func(r: Run) -> void: r.blast(r.player_pos() + Vector2(20, 0), 12.0, 1.0, 0.0, "item:test"),
			func(r: Run, n: int) -> bool: return _fx_total(r) > n],
		["lightning (toaster, items)", "zap", func(r: Run) -> void:
			_enemy(r, "chomper", Vector2(0, 30))
			r.chain_zap(r.player_pos(), 1.0, 2, 80.0, "faulty_toaster", -1, true),
			func(r: Run, _n: int) -> bool: return r.fx.added.get(Fx.BOLT, 0) > 0],
		["spitter shoots", "spit", func(r: Run) -> void: r._on_enemy_event(EnemySystem.EV_SHOOT, _enemy(r, "spitter", Vector2(60, 0)), Vector2.LEFT),
			func(r: Run, _n: int) -> bool: return r.enemy_shots.count() > 0],
		["bloater swells", "fuse", func(r: Run) -> void: r._on_enemy_event(EnemySystem.EV_SWELL, _enemy(r, "bloater", Vector2(-60, 0)), Vector2.RIGHT),
			func(r: Run, _n: int) -> bool: return r.danger.live_count() > 0],
		["bloater bursts", "pop", func(r: Run) -> void: r._on_enemy_event(EnemySystem.EV_EXPLODE, _enemy(r, "bloater", Vector2(-60, 0)), Vector2.RIGHT),
			func(r: Run, _n: int) -> bool: return r.fx.added.get(Fx.DISC, 0) > 0],
		["charger winds up", "windup", func(r: Run) -> void: r._on_enemy_event(EnemySystem.EV_WINDUP, _enemy(r, "chomper", Vector2(0, -60)), Vector2.DOWN),
			func(r: Run, _n: int) -> bool: return r.danger.added.get(Fx.LINE, 0) > 0],
		["elite appears", "elite", func(r: Run) -> void:
			var traits: Dictionary = r.elite_rules.traits
			r._spawn_group({"enemy": "blob", "count": 1, "grouped": false, "elite": traits.keys()[0], "reserve": true}),
			func(r: Run, _n: int) -> bool: return not r.enemies.elites.is_empty()],
		["swarm warning", "alarm", func(r: Run) -> void:
			r.director.events = ["swarm_warning"]
			r._director_events(),
			func(r: Run, _n: int) -> bool: return r._hud._banner.text == "SWARM INCOMING!"],
		["boss summoned", "boss_roar", func(r: Run) -> void: r.summon_boss("mega_mole", r.player_pos() + Vector2(0, -60)),
			func(r: Run, n: int) -> bool: return _fx_total(r) > n and r.juice._trauma > 0.0],
		["boss defeated", "boss_down", func(r: Run) -> void: r.hit_enemy(r.boss.slot, 1.0e9, Vector2.ZERO, "baguette"),
			func(r: Run, _n: int) -> bool: return r.juice.hitstop_left > 0.0 and r.fx.added.get(Fx.SPARKS, 0) > 0],
		["final swarm", "final", func(r: Run) -> void:
			r.director.events = ["final_start"]
			r._director_events()
			r.juice.update(0.5, 1.0),
			func(r: Run, _n: int) -> bool: return r.juice.tint > 0.0],
		["bills due", "bills", func(r: Run) -> void:
			r.director.events = ["bills_start"]
			r._director_events(),
			func(r: Run, _n: int) -> bool: return r._hud._banner.text == "BILLS ARE DUE!"],
		["low HP", "heartbeat", func(r: Run) -> void:
			r.hp = r.stat("max_hp") * 0.1
			r.juice.update(DT, 0.1),
			func(r: Run, _n: int) -> bool: return r.juice.vignette_strength > 0.0],
		["revive", "revive", func(r: Run) -> void: r.revive(),
			func(r: Run, n: int) -> bool: return _fx_total(r) > n],
		["level up", "level_up", func(r: Run) -> void:
			r.options.auto_cards = false
			r.add_xp(Run.xp_needed(r.rules.xp_curve, r.level))
			r.tick(DT),
			func(r: Run, _n: int) -> bool: return r.state == "level_up" and r.juice.burst_playing()],
		["card taken", "card", func(r: Run) -> void: r._on_card(0),
			func(r: Run, _n: int) -> bool: return r.state == "live"],
		["death", "death", func(r: Run) -> void: r._die(),
			func(r: Run, n: int) -> bool: return _fx_total(r) > n],
	]
	for e: Array in events:
		var before := int(run.juice.cues.get(e[1], 0))
		var fx_before := _fx_total(run)
		e[2].call(run)
		t.check(int(run.juice.cues.get(e[1], 0)) > before, "%s: sound \"%s\"" % [e[0], e[1]])
		t.check(e[3].call(run, fx_before), "%s: effect" % e[0])
	# The run ended (death): the escape cue on a fresh run.
	_done(t, run)
	run = _start(t, {})
	run.escape()
	t.check(run.juice.cues.get("escape", 0) == 1 and run.state == "over", "escape: sound and the run ends")
	_done(t, run)


func test_every_weapon_has_a_signature(t) -> void:
	# Every weapon has its own hit effect, attack sound, or its own drawing
	# for the effect named in the brief (steam, sock aura, lightning, fireworks).
	var drawn := ["hot_coffee", "stinky_socks", "faulty_toaster", "fireworks", "leaf_blower"]
	for w: Dictionary in GameData.shared().all("weapons"):
		var has: bool = not w.get("hit_fx", {}).is_empty() or w.id in drawn
		t.check(has, "%s has a signature effect" % w.id)
		t.check(not w.get("sfx", {}).is_empty() or w.id == "faulty_toaster", "%s has its own sound (toaster: zap)" % w.id)


func test_settings_turn_effects_off(t) -> void:
	var run := _start(t, {})
	run.juice.shake_on = false
	run.juice.shake("boss_down")
	run.juice.update(DT, 1.0)
	t.check(run.juice.offset == Vector2.ZERO, "screen shake off: the camera stays put")
	run.numbers.enabled = false
	run.numbers.show_number(run.player_pos(), 5.0)
	t.check(run.numbers.live_count() == 0, "damage numbers off: none shown")
	_done(t, run)
	# Reduce effects (read from the setting at run start).
	var save: Node = t.root.get_node_or_null("Save")
	if save == null:
		return
	var old: bool = save.get_setting("reduce_effects")
	save.data.settings.reduce_effects = true
	run = _start(t, {})
	t.check(run.fx.reduced and not run.gems.effects and run.juice.reduced, "reduce effects: fx reduced, gem effects off")
	run.fx.sparks(run.player_pos(), 10.0, Palette.RED)
	run.fx.ring(run.player_pos(), 10.0, Palette.RED)
	t.check(run.fx.live_of(Fx.SPARKS) == 0 and run.fx.live_of(Fx.RING) == 1, "cosmetic sparks skipped, rings (where damage lands) kept")
	run.juice.hitstop(0.1)
	t.check(run.juice.hitstop_left == 0.0, "no hit-stop with reduce effects")
	save.data.settings.reduce_effects = old
	_done(t, run)


func test_hitstop_on_big_crits_and_boss_hits(t) -> void:
	var run := _start(t, {})
	var j := run.juice
	j.crit(1.0, 100.0, false)
	t.check(j.hitstop_left == 0.0, "a small crit: no hit-stop")
	j.crit(60.0, 100.0, false)
	t.check(j.hitstop_left > 0.0, "a crit for half the enemy's HP: hit-stop")
	var frozen_at := run.elapsed
	run._process(DT)
	t.check(run.elapsed == frozen_at, "the game holds still during hit-stop")
	j.hitstop_left = 0.0
	j.boss_hit(10.0)
	var first := j.hitstop_left
	j.hitstop_left = 0.0
	j.boss_hit(10.1)
	t.check(first > 0.0 and j.hitstop_left == 0.0, "boss hits stop the game at most every boss_gap")
	t.check(j.hitstop_left <= float(run.fx_rules.hitstop.max), "hit-stop is capped")
	_done(t, run)


func test_level_up_burst_then_cards(t) -> void:
	var run := _start(t, {"auto_cards": false})
	run.add_xp(Run.xp_needed(run.rules.xp_curve, 1))
	run.tick(DT)
	t.check(run.state == "level_up" and t.paused, "level-up: game paused at once")
	t.check(run.juice.burst_playing() and not run._cards_panel.visible, "the light burst plays before the cards")
	await t.create_timer(float(run.fx_rules.level_up_burst) + 0.2, true).timeout
	t.check(not run.juice.burst_playing() and run._cards_panel.visible, "then the cards show")
	_done(t, run)


func test_final_tint_stays_on_palette(t) -> void:
	var run := _start(t, {})
	var lut: ImageTexture = run.juice._tint_lut()
	var img := lut.get_image()
	var ok := true
	for x in img.get_width():
		var c := img.get_pixel(x, 0)
		if not Palette.has(c) or (x != Palette.ENEMY_SHOT and c.to_rgba32() == Palette.color(Palette.ENEMY_SHOT).to_rgba32()):
			ok = false
	t.check(ok, "every shifted color is a palette color, and only enemy shots stay magenta")
	t.check(img.get_pixel(Palette.ENEMY_SHOT, 0) == Palette.color(Palette.ENEMY_SHOT), "enemy shots keep their color")
	t.check(img.get_pixel(Palette.GREEN, 0) != Palette.color(Palette.GREEN), "grass greens shift")
	_done(t, run)


func test_gem_trails_and_dither(t) -> void:
	# Dithered fades: full alpha keeps every pixel of a 4x4 block, zero keeps none.
	var full := 0
	var half := 0
	var none := 0
	for y in 4:
		for x in 4:
			full += 1 if Fx.dither(Vector2(x, y), 1.0) else 0
			half += 1 if Fx.dither(Vector2(x, y), 0.5) else 0
			none += 1 if Fx.dither(Vector2(x, y), 0.0) else 0
	t.check(full == 16 and half == 8 and none == 0, "Bayer dither: 16 / 8 / 0 pixels (%d %d %d)" % [full, half, none])
	var run := _start(t, {})
	run.gems.drop(run.player_pos() + Vector2(20, 0), 1.0)
	run.tick(DT)
	t.check(run.gems.pulled[run.gems.pool.active[0]] == 1, "a gem in range is pulled (and trails)")
	_done(t, run)

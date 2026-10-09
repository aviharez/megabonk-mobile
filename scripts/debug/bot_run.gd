extends Node
## Bot-driven runs for measuring and checking the game without a player.
##
## Stress test (300 enemies on screen, invincible bot, reports fps):
##   godot --path . res://scenes/debug/bot_run.tscn -- --mode=stress [--seconds=20] [--uncapped] [--then_uncapped]
## On a phone: export the "Android Stress" preset; it boots here (feature tag
## "stress") and runs 30 s with vsync, then 30 s uncapped. Read the RESULT
## lines with: adb logcat -s godot
## Full-run simulation (bot plays until death or the timer; use headless +
## fixed fps so it runs faster than real time):
##   godot --headless --fixed-fps 30 --path . res://scenes/debug/bot_run.tscn -- --mode=sim [--invincible]
## --build=full starts with a maxed late-run build (4 weapons and 4 tomes at
## level 5, every item stacked) to measure the cost of all effects together.
## --chests=S opens a paid chest every S seconds (sim). Common: --seed=N. --shot=S saves a screenshot to user://bot_run_shot.png
## after S seconds (windowed only). --cards stops auto-picking level-up cards.
## --joy drives the player with a simulated thumb drag instead of the bot.
## --die_at=S sets HP to 0 after S seconds (to see the game-over screen).
## --final (stress) measures at Final Swarm density: the clock starts inside
## the Final Swarm with Overdue Bills out, every role in the horde, elites.
## --boss=M (sim) walks to the altar from minute M; --portal takes the portal.
## --start=S starts the clock at S seconds. --map=ID plays another map.
## --character=ID plays another character (sims use a blank save, so nothing
## else from meta progression applies).
## --low_hp (stress) holds the hero at 20% HP, so the low-HP vignette and
## heartbeat run too (with --final the Final Swarm tint is on as well: every
## effect at once). The RESULT line reports which effects were active.
## --profile (stress) times each part of the frame and reports where the
## slow frames (over 2x the median logic time) spend it. Results print as one JSON line starting with "RESULT "
## and are written to user://bot_run_<mode>.json.

const RUN_SCENE := preload("res://scenes/run.tscn")

var _args := {}
var _run: Run
var _mode := "stress"
var _warmup := 3.0
var _measure := 20.0
var _t := 0.0
var _frames := 0
var _frame_ms := PackedFloat32Array()
var _logic_ms := 0.0
var _on_screen := 0
var _on_screen_min := 1 << 30
var _last_usec := 0
var _logic := PackedFloat32Array()
var _prof_total := {}
var _prof_spike := {}
var _prof_frames := []
var _wall_start := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	if OS.has_feature("stress"):
		_args.merge({"mode": "stress", "seconds": "30", "then_uncapped": "true", "build": "full", "final": "true", "low_hp": "true"})
	_mode = _args.get("mode", "stress")
	_measure = float(_args.get("seconds", "20"))
	_warmup = float(_args.get("warmup", "3"))
	if _args.has("uncapped"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	process_mode = Node.PROCESS_MODE_ALWAYS
	var opts := {"bot": not _args.has("joy"), "auto_cards": not _args.has("cards"), "no_save": true, "seed": int(_args.get("seed", "1"))}
	if _mode == "stress":
		opts.stress = true
		opts.invincible = true
		if _args.has("final"):
			# 2:30 into the Final Swarm: bills are out and speeding up.
			opts.start_at = 480.0 + 150.0
		else:
			opts.rules = {"run_length_sec": 1.0e9}
			opts.no_spawns = true
	elif _args.has("invincible"):
		opts.invincible = true
	if _mode == "sim":
		opts.bot_goals = true
	if _args.has("map"):
		opts.map = _args.map
	if _args.has("start"):
		opts.start_at = float(_args.start)
	if _args.has("boss"):
		opts.bot_boss_min = float(_args.boss)
	if _args.has("portal"):
		opts.bot_portal = true
	if _args.has("character"):
		opts.character = _args.character
	if _args.has("profile"):
		opts.profile = true
	if _args.has("low_hp"):
		opts.pin_hp = 0.2
	if _args.has("chests"):
		opts.chest_every = float(_args.chests)
	if _args.get("build", "") == "full":
		opts.all_content = true
		var items := {}
		for it: Dictionary in GameData.shared().all("items"):
			items[it.id] = 1 if it.rarity == "legendary" else 3
		opts.loadout = {
			"weapons": {"baguette": 5, "garden_gnomes": 5, "stinky_socks": 5, "fireworks": 5},
			"tomes": {"copy_machine_manual": 5, "think_big": 5, "speed_reading": 5, "muscle_magazine": 5},
			"items": items,
		}
	Run.next_options = opts
	_run = RUN_SCENE.instantiate()
	add_child(_run)
	_wall_start = Time.get_ticks_msec()
	if _args.has("joy"):
		_thumb.call_deferred()
	print("bot_run: mode=%s seed=%d" % [_mode, opts.seed])


func _process(delta: float) -> void:
	if _args.has("shot") and Time.get_ticks_msec() - _wall_start >= float(_args.shot) * 1000.0:
		get_viewport().get_texture().get_image().save_png("user://bot_run_shot.png")
		print("bot_run: screenshot saved, state=%s t=%.1f alive=%d on_screen=%d" % [_run.state, _run.elapsed, _run.enemies.count(), _run.enemies_on_screen()])
		_args.erase("shot")
		if _args.has("quit_after_shot"):
			get_tree().quit()
	if _args.has("die_at") and _run.elapsed >= float(_args.die_at):
		_args.erase("die_at")
		_run.hp = 0.0
	if _mode == "stress":
		_stress_frame(delta)
	elif _run.state == "over" and not _args.has("shot"):
		var r := _run.result.duplicate()
		r.merge({
			"mode": "sim", "invincible": _args.has("invincible"),
			"escalation": snappedf(_run.director.escalation(), 0.001),
			"blocked_spawns": _run.director.blocked_total(),
			"last_damage_source": _run.last_damage_source,
			"death_pos": [roundi(_run.player_pos().x), roundi(_run.player_pos().y)],
			"enemies_alive_at_end": _run.enemies.count(),
			"weapon_level": _run.owned_weapons, "tomes": _run.owned_tomes,
			"wall_seconds": (Time.get_ticks_msec() - _wall_start) / 1000.0,
		})
		_finish(r)
	elif int(_run.elapsed) % 60 == 0 and int(_run.elapsed) != int(_run.elapsed - delta):
		var mix := {}
		for sl in _run.enemies.pool.active:
			var id: String = _run.enemies.types[_run.enemies.type_of[sl]].id
			mix[id] = mix.get(id, 0) + 1
		print("  minute %d: enemies %d (+%d reserved), level %d, hp %d, kills %d, gold %d, elites %d, boss %s, swarm %s, final %s %s" % [int(_run.elapsed) / 60, _run.enemies.count(), _run.enemies.pool.count() - _run.enemies.count(), _run.level, _run.hp, _run.kills, _run.gold, _run.enemies.elites.size(), "dead" if _run.boss_defeated else ("up" if _run.boss_summoned else "-"), _run.director.swarm_active(), _run.final_swarm(), mix])


func _stress_frame(delta: float) -> void:
	if _args.has("trace") and int(_t + delta) != int(_t):
		print("  t=%d elapsed=%.1f final=%s final_t=%.1f bills=%d spawned=%d pool=%d state=%s vsync=%d" % [_t, _run.elapsed, _run.director.final_started, _run.director.final_time, _run.enemies.ghosts.size(), _run.director.bills_spawned, _run.enemies.pool.count(), _run.state, DisplayServer.window_get_vsync_mode()])
	_t += delta
	var now := Time.get_ticks_usec()
	if _t < _warmup:
		_last_usec = now
		return
	_frames += 1
	_frame_ms.append((now - _last_usec) / 1000.0)
	_last_usec = now
	_logic_ms += _run.last_frame_usec / 1000.0
	_logic.append(_run.last_frame_usec / 1000.0)
	if _args.has("profile"):
		_prof_frames.append([_run.last_frame_usec, _run.profile_frame.duplicate()])
	var n := _run.enemies_on_screen()
	_on_screen += n
	_on_screen_min = mini(_on_screen_min, n)
	if _t >= _warmup + _measure:
		var total := 0.0
		for f in _frame_ms:
			total += f
		var sorted := _frame_ms.duplicate()
		sorted.sort()
		var p99: float = sorted[int(sorted.size() * 0.99)]
		var lsorted := _logic.duplicate()
		lsorted.sort()
		var prof := {}
		if _args.has("profile"):
			var median: float = lsorted[lsorted.size() / 2] * 1000.0
			var spikes := 0
			for f: Array in _prof_frames:
				for k: String in f[1]:
					_prof_total[k] = _prof_total.get(k, 0) + f[1][k]
				if f[0] > 2.0 * median:
					spikes += 1
					for k: String in f[1]:
						_prof_spike[k] = _prof_spike.get(k, 0) + f[1][k]
			for k: String in _prof_total:
				_prof_total[k] = snappedf(_prof_total[k] / 1000.0 / _prof_frames.size(), 0.001)
			for k: String in _prof_spike:
				_prof_spike[k] = snappedf(_prof_spike[k] / 1000.0 / maxi(spikes, 1), 0.001)
			prof = {"avg_ms": _prof_total, "spike_frames": spikes, "spike_avg_ms": _prof_spike, "median_logic_ms": snappedf(median / 1000.0, 0.001)}
		# A frame that really missed a vsync takes ~2 refresh intervals; one
		# that only looks slow next to its neighbours is timing jitter.
		var interval := 1000.0 / maxf(DisplayServer.screen_get_refresh_rate(), 1.0)
		var missed := 0
		for f in _frame_ms:
			if f > interval * 1.5:
				missed += 1
		_finish({
			"missed_vsync_frames": missed,
			"missed_vsync_pct": snappedf(100.0 * missed / maxf(_frame_ms.size(), 1.0), 0.01),
			"frame_max_ms": snappedf(sorted[sorted.size() - 1], 0.01),
			"logic_p99_ms": snappedf(lsorted[int(lsorted.size() * 0.99)], 0.01),
			"logic_max_ms": snappedf(lsorted[lsorted.size() - 1], 0.01),
			"profile": prof,
			"mode": "stress",
			"device": OS.get_model_name(),
			"refresh_hz": DisplayServer.screen_get_refresh_rate(),
			"renderer": RenderingServer.get_current_rendering_method(),
			"gpu": RenderingServer.get_video_adapter_name(),
			"vsync": DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED,
			"seconds": snappedf(total / 1000.0, 0.01),
			"frames": _frames,
			"avg_fps": snappedf(_frames / (total / 1000.0), 0.1),
			"p99_frame_ms": snappedf(p99, 0.01),
			"fps_1pct_low": snappedf(1000.0 / p99, 0.1),
			"avg_logic_ms": snappedf(_logic_ms / _frames, 0.001),
			"avg_enemies_on_screen": snappedf(float(_on_screen) / _frames, 0.1),
			"min_enemies_on_screen": _on_screen_min,
			"kills": _run.kills,
			"gems_alive": _run.gems.count(),
			"gem_merges": _run.gems.merges,
			"enemies_total": _run.enemies.pool.count(),
			"bills": _run.enemies.ghosts.size(),
			"bills_spawned": _run.director.bills_spawned,
			"enemy_shots": _run.enemy_shots.count(),
			"final": _args.has("final"),
			"build": _args.get("build", "starter"),
			"fx": _fx_report(),
		})


## Which effects were on during the measurement (all should be, for the
## "all effects on" number).
func _fx_report() -> Dictionary:
	var j: Juice = _run.juice
	var added := 0
	for k in _run.fx.added:
		added += int(_run.fx.added[k])
	var cues := 0
	for k in j.cues:
		cues += int(j.cues[k])
	var audio := get_node_or_null("/root/Audio")
	return {
		"reduce_effects": _run.fx.reduced, "damage_numbers": _run.numbers.enabled, "screen_shake": j.shake_on,
		"final_tint": j.tint, "vignette": j.vignette_strength, "gem_effects": _run.gems.effects,
		"fx_added": added, "sfx_cues": cues, "audio_voices": audio.voice_cap() if audio != null else 0,
		"audio_dropped": audio.dropped if audio != null else 0,
	}


func _finish(r: Dictionary) -> void:
	var line := JSON.stringify(r)
	print("RESULT " + line)
	if _args.has("then_uncapped"):
		# Second measurement with vsync off, same run, same horde.
		_args.erase("then_uncapped")
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		_t = 0.0
		_frames = 0
		_frame_ms.clear()
		_logic.clear()
		_prof_frames.clear()
		_prof_total.clear()
		_prof_spike.clear()
		_logic_ms = 0.0
		_on_screen = 0
		_on_screen_min = 1 << 30
		return
	var f := FileAccess.open("user://bot_run_%s.json" % r.mode, FileAccess.WRITE)
	if f:
		f.store_string(line)
	get_tree().paused = false
	get_tree().quit()


func _thumb() -> void:
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = Vector2(90, 250)
	Input.parse_input_event(press)
	var drag := InputEventScreenDrag.new()
	drag.position = Vector2(104, 238)
	Input.parse_input_event(drag)

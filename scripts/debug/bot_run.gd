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
## Common: --seed=N. --shot=S saves a screenshot to user://bot_run_shot.png
## after S seconds (windowed only). --cards stops auto-picking level-up cards.
## --joy drives the player with a simulated thumb drag instead of the bot.
## --die_at=S sets HP to 0 after S seconds (to see the game-over screen). Results print as one JSON line starting with "RESULT "
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
var _wall_start := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	if OS.has_feature("stress"):
		_args.merge({"mode": "stress", "seconds": "30", "then_uncapped": "true"})
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
		opts.rules = {"run_length_sec": 1.0e9}
	elif _args.has("invincible"):
		opts.invincible = true
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
			"escalation": snappedf(_run.spawner.escalation, 0.001),
			"blocked_spawns": _run.spawner.blocked_total,
			"enemies_alive_at_end": _run.enemies.count(),
			"weapon_level": _run.owned_weapons, "tomes": _run.owned_tomes,
			"wall_seconds": (Time.get_ticks_msec() - _wall_start) / 1000.0,
		})
		_finish(r)
	elif int(_run.elapsed) % 60 == 0 and int(_run.elapsed) != int(_run.elapsed - delta):
		print("  minute %d: enemies %d, level %d, hp %d, kills %d" % [int(_run.elapsed) / 60, _run.enemies.count(), _run.level, _run.hp, _run.kills])


func _stress_frame(delta: float) -> void:
	_t += delta
	var now := Time.get_ticks_usec()
	if _t < _warmup:
		_last_usec = now
		return
	_frames += 1
	_frame_ms.append((now - _last_usec) / 1000.0)
	_last_usec = now
	_logic_ms += _run.last_frame_usec / 1000.0
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
		_finish({
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
		})


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

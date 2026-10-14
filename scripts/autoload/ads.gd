extends Node
## Ads service (autoload "Ads"): placements, limits and pausing on top of an
## AdBackend (AdMob on a device, FakeAdBackend on desktop and in tests).
## Rules from docs/BRIEF.md "Monetization", numbers in data/rules/ads.json.
##
## Rewarded placements ("revive", "double_coins", "reroll", "skip",
## "banish", "daily", "quest_double": AD x2 on a quest claim) have a per-run or per-day limit. can_offer() is true
## only while a rewarded ad is loaded and the limit isn't reached: buttons
## show only then. show_rewarded() calls back with true only after the SDK's
## reward callback; a use counts only then. A failed or skipped ad costs
## nothing and the button can be tried again.
##
## Interstitial: only at the game over -> menu break, at most once every
## 2-3 runs ("runs_between"), never in the first day after the first launch,
## never right after a rewarded ad (any rewarded ad since the last break),
## never with Remove Ads.
##
## Banner: bottom of the menu, shop and unlocks screens (set_banner), never
## during a run, never with Remove Ads. `banner_inset` is its height in game
## pixels so the menu can keep its buttons above it.
##
## While a full-screen ad is up the tree is paused and the master bus muted;
## both go back to what they were when it closes, fails to show, or the SDK
## never answers (watchdog, `show_timeout_sec`).

signal ready_changed
signal ad_started(format: String)
signal ad_finished(format: String, earned: bool)
signal banner_inset_changed(inset: int)

const SaveManager := preload("res://scripts/autoload/save_manager.gd")

var config: Dictionary = {}
var backend: AdBackend
var save: Node
var started := false
## Clock hooks (tests move time).
var now_unix := func() -> int: return int(Time.get_unix_time_from_system())
## The local date, on the quests clock (Quests.clock: one fake clock moves both).
var today := func() -> String: return Time.get_date_string_from_unix_time(Quests.now())
var rng := RandomNumberGenerator.new()
## Game pixels the bottom banner covers (0 when none is shown).
var banner_inset := 0

var _state := {"rewarded": "idle", "interstitial": "idle"}  # idle, loading, ready, showing
var _fails := {"rewarded": 0, "interstitial": 0, "banner": 0}
var _run_used := {}  # placement -> uses this run
var _show := {}  # the full-screen ad on screen now (see _begin)
var _token := 0
var _banner_wanted := false
var _banner_requested := false
var _fallback_data: Dictionary = SaveManager.default_data().ads


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	# The autoload starts itself; tests make their own instance and call start().
	if get_parent() == get_tree().root and name == "Ads":
		_autostart.call_deferred()


func _autostart() -> void:
	if started:
		return
	start(get_node_or_null("/root/Save"), _make_backend())
	var store := get_node_or_null("/root/Store")
	if store != null:
		store.changed.connect(refresh)


## Which AdBackend a build gets: "sdk" (AdMob) where its native plugin
## exists; otherwise "fake" only in debug builds (editor, tests, debug APKs),
## since the fake pays out rewards for nothing. A release build without the
## plugin gets "none": the inert base AdBackend, so nothing ever loads and no
## ad button, banner or interstitial shows.
static func backend_kind(has_plugin: bool, debug_build: bool) -> String:
	if has_plugin:
		return "sdk"
	return "fake" if debug_build else "none"


func _make_backend() -> AdBackend:
	match backend_kind(Engine.has_singleton("PoingGodotAdMob"), OS.is_debug_build()):
		"sdk":
			return load("res://scripts/ads/admob_backend.gd").new()
		"fake":
			var fake := FakeAdBackend.new()
			fake.visual = DisplayServer.get_name() != "headless"
			fake.step_sec = 0.3
			return fake
	push_warning("Ads: no ad SDK in this release build, ads are off")
	return AdBackend.new()


func start(save_node: Node, backend_node: AdBackend, cfg := {}) -> void:
	save = save_node
	config = cfg if not cfg.is_empty() else GameData.shared().get_entry("rules", "ads")
	backend = backend_node
	add_child(backend)
	backend.loaded.connect(_on_loaded)
	backend.load_failed.connect(_on_load_failed)
	backend.showed.connect(_on_showed)
	backend.show_failed.connect(_on_show_failed)
	backend.earned.connect(_on_earned)
	backend.dismissed.connect(_on_dismissed)
	backend.banner_loaded.connect(_on_banner_loaded)
	backend.banner_failed.connect(_on_banner_failed)
	var units: Dictionary = config.get("units", {})
	backend.setup(units.get("ios" if OS.get_name() == "iOS" else "android", {}))
	var d := data()
	if int(d.get("first_seen", 0)) <= 0:
		d.first_seen = now_unix.call()  # kept in memory, written with the next save
	started = true
	_load("rewarded")
	_load("interstitial")
	_update_banner()


## The save's "ads" block.
func data() -> Dictionary:
	if save == null:
		return _fallback_data
	return save.data.ads


func removed() -> bool:
	return bool(data().get("removed", false))


func is_showing() -> bool:
	return not _show.is_empty()


func rewarded_ready() -> bool:
	return started and _state.rewarded == "ready"


## Re-reads Remove Ads (after a purchase or restore): drops banners and
## interstitials at once.
func refresh() -> void:
	if not started:
		return
	_update_banner()
	if not removed():
		_load("interstitial")
	ready_changed.emit()


# --- Rewarded -----------------------------------------------------------------

## True when a rewarded button for `placement` should be on screen.
func can_offer(placement: String) -> bool:
	return rewarded_ready() and not is_showing() and uses_left(placement) > 0


## Uses left for a rewarded placement this run (per_run) or today (per_day).
func uses_left(placement: String) -> int:
	var rule: Dictionary = config.get("rewarded", {}).get(placement, {})
	if rule.has("per_run"):
		return int(rule.per_run) - int(_run_used.get(placement, 0))
	if rule.has("per_day"):
		var day: Dictionary = data().per_day.get(placement, {})
		var used := int(day.get("count", 0)) if day.get("date", "") == today.call() else 0
		return int(rule.per_day) - used
	push_error("Ads: unknown rewarded placement \"%s\"" % placement)
	return 0


## Shows a rewarded ad for `placement`. on_done(granted: bool) runs once the
## ad is gone and the game is resumed; granted only after the reward callback.
## Returns false (and never calls on_done) if it can't be offered now.
func show_rewarded(placement: String, on_done: Callable) -> bool:
	if not can_offer(placement):
		return false
	_begin("rewarded", placement, on_done)
	return true


## A new run: per-run limits start over.
func begin_run() -> void:
	_run_used.clear()


## A run ended (any reason): counts toward the interstitial gap.
func end_run() -> void:
	var d := data()
	d.runs_since_interstitial = int(d.get("runs_since_interstitial", 0)) + 1
	_save()


# --- Interstitial ------------------------------------------------------------

## Why no interstitial would show at the break now ("" = it would).
func interstitial_block_reason() -> String:
	var d := data()
	var ic: Dictionary = config.get("interstitial", {})
	if removed():
		return "removed"
	if int(d.get("first_seen", 0)) <= 0:
		d.first_seen = now_unix.call()  # a fresh or reset save: day one starts now
	if now_unix.call() - int(d.first_seen) < float(ic.get("first_day_hours", 24.0)) * 3600.0:
		return "day_one"
	if int(d.get("interstitial_gap", 0)) <= 0:
		d.interstitial_gap = _draw_gap()
	if int(d.get("runs_since_interstitial", 0)) < int(d.interstitial_gap):
		return "too_soon"
	if bool(d.get("rewarded_since_break", false)):
		return "after_rewarded"
	if _state.interstitial != "ready" or is_showing():
		return "not_loaded"
	return ""


## The game over -> menu break. Shows an interstitial if the rules allow,
## then on_done(shown: bool) once it's gone; otherwise calls on_done(false)
## on the next frame. Either way this break uses up "just watched a rewarded".
func at_break(on_done: Callable) -> void:
	var why := interstitial_block_reason()
	data().rewarded_since_break = false
	if why != "":
		_save()
		on_done.call_deferred(false)
		return
	_begin("interstitial", "break", on_done)


func _draw_gap() -> int:
	var r: Array = config.get("interstitial", {}).get("runs_between", [2, 3])
	return rng.randi_range(int(r[0]), int(r[1]))


# --- Banner ------------------------------------------------------------------

## The current screen wants the bottom banner (menu, shop, unlocks) or not.
func set_banner(wanted: bool) -> void:
	_banner_wanted = wanted
	_update_banner()


## True if `screen` is one of data/rules/ads.json banner "screens".
func banner_screen(screen: String) -> bool:
	return screen in config.get("banner", {}).get("screens", [])


func _update_banner() -> void:
	if backend == null:
		return
	if removed():
		if _banner_requested:
			backend.banner_destroy()
			_banner_requested = false
		_set_inset(0)
		return
	if _banner_wanted:
		if not _banner_requested:
			_banner_requested = true
			backend.banner_load()
		backend.banner_show()
		_set_inset(_game_px(backend.banner_height_px()))
	else:
		backend.banner_hide()
		_set_inset(0)


func _on_banner_loaded() -> void:
	_fails.banner = 0
	_update_banner()


func _on_banner_failed(error: String) -> void:
	push_warning("Ads: banner failed to load (%s)" % error)
	_banner_requested = false
	_set_inset(0)
	_retry_later("banner", _update_banner)


func _set_inset(v: int) -> void:
	if v != banner_inset:
		banner_inset = v
		banner_inset_changed.emit(v)


## Screen pixels -> game pixels (integer scale, rounded up).
func _game_px(screen_px: int) -> int:
	if screen_px <= 0 or not is_inside_tree():
		return 0
	var view := get_tree().root.get_visible_rect().size
	var win := Vector2(DisplayServer.window_get_size())
	var scale := maxf(1.0, floorf(win.y / maxf(1.0, view.y)))
	return ceili(screen_px / scale)


# --- Full-screen flow --------------------------------------------------------

func _begin(format: String, placement: String, on_done: Callable) -> void:
	_token += 1
	_show = {"format": format, "placement": placement, "on_done": on_done, "token": _token,
		"showed": false, "earned": false, "dismissed": false}
	_state[format] = "showing"
	_pause_for_ad(_show)
	ad_started.emit(format)
	ready_changed.emit()
	backend.show_ad(format)
	var token := _token
	get_tree().create_timer(float(config.get("show_timeout_sec", 8.0)), true).timeout.connect(func() -> void:
		if _show.get("token") == token and not _show.showed:
			push_warning("Ads: %s ad never showed, resuming" % format)
			_finish())


func _on_showed(format: String) -> void:
	if _show.get("format") == format:
		_show.showed = true
		return
	# It showed after the watchdog gave up: pause again until it closes. No
	# reward can come from it.
	if _show.is_empty():
		_token += 1
		_show = {"format": format, "placement": "", "on_done": func(_g: bool) -> void: pass,
			"token": _token, "showed": true, "earned": false, "dismissed": false}
		_pause_for_ad(_show)


func _on_earned(format: String) -> void:
	if _show.get("format") != format or _show.placement == "":
		return
	_show.earned = true
	if _show.dismissed:
		_finish()


func _on_dismissed(format: String) -> void:
	if _show.get("format") != format:
		return
	_show.dismissed = true
	if format == "rewarded" and not _show.earned and _show.placement != "":
		# Some SDKs send the reward just after the close: wait a moment.
		var token: int = _show.token
		get_tree().create_timer(float(config.get("reward_grace_sec", 1.0)), true).timeout.connect(func() -> void:
			if _show.get("token") == token:
				_finish())
		return
	_finish()


func _on_show_failed(format: String, error: String) -> void:
	if _show.get("format") != format:
		return
	push_warning("Ads: %s ad failed to show (%s)" % [format, error])
	_finish()


func _finish() -> void:
	var s := _show
	_show = {}
	if _state[s.format] == "showing":
		_state[s.format] = "idle"
	_resume_after_ad(s)
	var d := data()
	if s.earned:
		_count(s.placement)
		d.rewarded_since_break = true
	if s.format == "interstitial" and s.showed:
		d.runs_since_interstitial = 0
		d.interstitial_gap = _draw_gap()
	_save()
	ad_finished.emit(s.format, s.earned)
	_load(s.format)
	ready_changed.emit()
	s.on_done.call(s.earned if s.format == "rewarded" else s.showed)


func _count(placement: String) -> void:
	var rule: Dictionary = config.get("rewarded", {}).get(placement, {})
	if rule.has("per_run"):
		_run_used[placement] = int(_run_used.get(placement, 0)) + 1
	elif rule.has("per_day"):
		var d := data()
		var day: Dictionary = d.per_day.get(placement, {})
		var date: String = today.call()
		var n := int(day.get("count", 0)) if day.get("date", "") == date else 0
		d.per_day[placement] = {"date": date, "count": n + 1}


func _pause_for_ad(s: Dictionary) -> void:
	s.was_paused = get_tree().paused
	s.was_muted = AudioServer.is_bus_mute(0)
	get_tree().paused = true
	AudioServer.set_bus_mute(0, true)


func _resume_after_ad(s: Dictionary) -> void:
	get_tree().paused = s.was_paused
	AudioServer.set_bus_mute(0, s.was_muted)


# --- Loading -----------------------------------------------------------------

func _load(format: String) -> void:
	if not started or _state[format] != "idle":
		return
	if format == "interstitial" and removed():
		return
	_state[format] = "loading"
	backend.load_ad(format)


func _on_loaded(format: String) -> void:
	if _state.get(format) != "loading":
		return
	_state[format] = "ready"
	_fails[format] = 0
	ready_changed.emit()


func _on_load_failed(format: String, error: String) -> void:
	if _state.get(format) != "loading":
		return
	push_warning("Ads: %s ad failed to load (%s)" % [format, error])
	_state[format] = "idle"
	_retry_later(format, _load.bind(format))


## Exponential backoff between `retry_sec` [first, max].
func _retry_later(key: String, fn: Callable) -> void:
	_fails[key] = int(_fails[key]) + 1
	var r: Array = config.get("retry_sec", [2.0, 60.0])
	var wait := minf(float(r[0]) * pow(2.0, _fails[key] - 1), float(r[1]))
	get_tree().create_timer(wait, true).timeout.connect(fn)


func _save() -> void:
	if save != null and save.has_method("save_game"):
		save.save_game()

extends RefCounted
## Ads and Remove Ads (docs/BRIEF.md "Monetization"), with FakeAdBackend and
## FakeStoreBackend standing in for AdMob and Play Billing:
## - rewarded: offered only when loaded, granted only after the reward
##   callback (also when it comes after the close), per-run and per-day
##   limits, failed / skipped / never-answering ads cost nothing;
## - pause and mute while an ad is up, restored on close, failure, timeout;
## - interstitial: never on day one, every 2-3 runs, not after a rewarded ad,
##   not with Remove Ads;
## - banner: on request, inset reported, gone with Remove Ads;
## - in a real run: revive, level-up actions by ad, 2x coins.

const SaveManager := preload("res://scripts/autoload/save_manager.gd")
const AdsScript := preload("res://scripts/autoload/ads.gd")
const StoreScript := preload("res://scripts/autoload/store.gd")
const RUN_SCENE := preload("res://scenes/run.tscn")
const TEST_SAVE := "user://test_ads_save.json"
const DT := 1.0 / 30.0
const DAY := 86400

var _nodes: Array[Node] = []


func _save(t) -> Node:
	var s: Node = SaveManager.new()
	s.path = TEST_SAVE
	t.root.add_child(s)
	s.reset()
	_nodes.append(s)
	return s


func _cfg() -> Dictionary:
	var c: Dictionary = GameData.shared().get_entry("rules", "ads").duplicate(true)
	c.show_timeout_sec = 0.3
	c.reward_grace_sec = 0.15
	c.retry_sec = [0.05, 0.1]
	return c


## An Ads service on a fake backend, started as if installed `age_sec` ago.
func _ads(t, save: Node, fake: FakeAdBackend = null, age_sec := 2 * DAY) -> Node:
	if fake == null:
		fake = FakeAdBackend.new()
	var ads: Node = AdsScript.new()
	t.root.add_child(ads)
	ads.rng.seed = 7
	var clock := [1_000_000_000]
	ads.set_meta("clock", clock)
	ads.now_unix = func() -> int: return clock[0]
	save.data.ads.first_seen = clock[0] - age_sec
	ads.start(save, fake, _cfg())
	_nodes.append(ads)
	return ads


func _frames(t, n := 3) -> void:
	for i in n:
		await t.process_frame


## Waits (real time) until cond() or `sec` passes.
func _until(t, cond: Callable, sec := 2.0) -> bool:
	var end := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await t.process_frame
	return cond.call()


## Shows a rewarded ad for `placement` and waits for the result:
## {"called": bool, "granted": bool, "paused_during": bool}.
func _watch(t, ads: Node, placement: String) -> Dictionary:
	var out := {"called": false, "granted": false, "paused_during": false}
	var ok: bool = ads.show_rewarded(placement, func(g: bool) -> void:
		out.called = true
		out.granted = g)
	out.paused_during = t.paused
	if ok:
		await _until(t, func() -> bool: return out.called)
	return out


func cleanup() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
	for p in [TEST_SAVE, TEST_SAVE + ".bak", TEST_SAVE + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _done(t) -> void:
	cleanup()
	t.paused = false
	AudioServer.set_bus_mute(0, false)


# --- Rewarded -----------------------------------------------------------------

func test_rewarded_only_offered_when_loaded(t) -> void:
	var save := _save(t)
	var fake := FakeAdBackend.new()
	fake.fill = false
	var ads := _ads(t, save, fake)
	await _frames(t)
	t.check(not ads.rewarded_ready() and not ads.can_offer("revive"), "no fill: no rewarded button")
	t.check(not ads.show_rewarded("revive", func(_g: bool) -> void: pass), "show refused without an ad")
	fake.fill = true
	t.check(await _until(t, func() -> bool: return ads.can_offer("revive")), "a retry loads it: button shows")
	t.check(fake.calls.count("load:rewarded") >= 2, "load retried (%s)" % [fake.calls])
	_done(t)


func test_reward_only_after_reward_callback(t) -> void:
	var save := _save(t)
	var fake := FakeAdBackend.new()
	var ads := _ads(t, save, fake)
	await _until(t, func() -> bool: return ads.rewarded_ready())
	var seen := []
	fake.showed.connect(func(_f: String) -> void: seen.append("showed"))
	fake.earned.connect(func(_f: String) -> void: seen.append("earned"))
	var granted_at := []
	ads.show_rewarded("revive", func(g: bool) -> void: granted_at.append([g, seen.duplicate()]))
	t.check(granted_at.is_empty(), "nothing granted when the button is tapped")
	await _until(t, func() -> bool: return not granted_at.is_empty())
	t.check(granted_at.size() == 1 and granted_at[0][0] and "earned" in granted_at[0][1], "granted once, after the reward callback (%s)" % [granted_at])

	for outcome: String in ["close_early", "fail_show"]:
		fake.outcome = outcome
		await _until(t, func() -> bool: return ads.can_offer("double_coins"))
		var r := await _watch(t, ads, "double_coins")
		t.check(r.called and not r.granted, "%s: no reward" % outcome)
		t.check(ads.uses_left("double_coins") == 1, "%s: the use isn't spent" % outcome)
	fake.outcome = "late_reward"
	await _until(t, func() -> bool: return ads.can_offer("double_coins"))
	var late := await _watch(t, ads, "double_coins")
	t.check(late.granted, "reward callback just after the close still counts")
	t.check(ads.uses_left("double_coins") == 0, "and spends the use")
	_done(t)


func test_per_run_limits(t) -> void:
	var save := _save(t)
	var ads := _ads(t, save)
	for p: String in ["revive", "double_coins", "reroll", "skip", "banish"]:
		await _until(t, func() -> bool: return ads.can_offer(p))
		var r := await _watch(t, ads, p)
		t.check(r.granted, "%s granted" % p)
		await _until(t, func() -> bool: return ads.rewarded_ready())
		t.check(not ads.can_offer(p), "%s: 1 per run" % p)
		t.check(not ads.show_rewarded(p, func(_g: bool) -> void: pass), "%s: second show refused" % p)
	t.check(ads.can_offer("daily"), "per-run uses don't touch the daily reward")
	ads.begin_run()
	for p: String in ["revive", "double_coins", "reroll", "skip", "banish"]:
		t.check(ads.can_offer(p), "%s back next run" % p)
	_done(t)


func test_daily_once_per_day_and_saved(t) -> void:
	var save := _save(t)
	var ads := _ads(t, save)
	var day := ["2026-10-08"]
	ads.today = func() -> String: return day[0]
	await _until(t, func() -> bool: return ads.can_offer("daily"))
	t.check((await _watch(t, ads, "daily")).granted, "daily granted")
	await _until(t, func() -> bool: return ads.rewarded_ready())
	t.check(not ads.can_offer("daily"), "once per day")
	ads.begin_run()
	t.check(not ads.can_offer("daily"), "a new run doesn't reset it")
	# Restart the game the same day: the count is in the save on disk.
	var again: Node = SaveManager.new()
	again.path = TEST_SAVE
	t.root.add_child(again)
	again.load_game()
	_nodes.append(again)
	var ads2 := _ads(t, again)
	ads2.today = func() -> String: return day[0]
	await _until(t, func() -> bool: return ads2.rewarded_ready())
	t.check(not ads2.can_offer("daily"), "still used after a restart")
	day[0] = "2026-10-09"
	t.check(ads2.can_offer("daily"), "available again the next day")
	_done(t)


# --- Pause and resume -----------------------------------------------------------

func test_pause_and_resume_every_outcome(t) -> void:
	var save := _save(t)
	var fake := FakeAdBackend.new()
	var ads := _ads(t, save, fake)
	for outcome: String in ["complete", "close_early", "fail_show", "late_reward", "silent"]:
		for was_paused: bool in [false, true]:
			fake.outcome = outcome
			ads.begin_run()
			await _until(t, func() -> bool: return ads.can_offer("reroll"))
			t.paused = was_paused
			AudioServer.set_bus_mute(0, false)
			var muted_during := [false]
			ads.ad_started.connect(func(_f: String) -> void: muted_during[0] = AudioServer.is_bus_mute(0), CONNECT_ONE_SHOT)
			var r := await _watch(t, ads, "reroll")
			t.check(r.paused_during and muted_during[0], "%s: paused and muted while the ad is up" % outcome)
			t.check(r.called, "%s: the game always gets an answer (watchdog for silent)" % outcome)
			t.check(t.paused == was_paused and not AudioServer.is_bus_mute(0), "%s: pause restored to %s, sound back" % [outcome, was_paused])
			t.check(not ads.is_showing(), "%s: nothing left on screen" % outcome)
	t.paused = false
	_done(t)


func test_ad_that_shows_after_the_watchdog_pauses_again(t) -> void:
	var save := _save(t)
	var fake := FakeAdBackend.new()
	fake.outcome = "silent"
	var ads := _ads(t, save, fake)
	await _until(t, func() -> bool: return ads.can_offer("revive"))
	var r := await _watch(t, ads, "revive")
	t.check(r.called and not r.granted and not t.paused, "watchdog resumed")
	fake.showed.emit("rewarded")
	t.check(t.paused, "a late ad on screen pauses again")
	fake.earned.emit("rewarded")
	fake.dismissed.emit("rewarded")
	t.check(not t.paused, "and resumes when it closes")
	t.check(ads.uses_left("revive") == 1, "no reward from it")
	_done(t)


# --- Interstitial ---------------------------------------------------------------

func _break(t, ads: Node) -> bool:
	var out := [null]
	ads.at_break(func(shown: bool) -> void: out[0] = shown)
	await _until(t, func() -> bool: return out[0] != null)
	return out[0]


func test_interstitial_pacing(t) -> void:
	var save := _save(t)
	var fake := FakeAdBackend.new()
	var ads := _ads(t, save, fake, 3600)  # installed an hour ago
	await _until(t, func() -> bool: return ads.interstitial_block_reason() != "not_loaded")
	for i in 5:
		ads.end_run()
	t.check(ads.interstitial_block_reason() == "day_one", "never on day one (%s)" % ads.interstitial_block_reason())
	t.check(not await _break(t, ads), "no ad at the break on day one")
	ads.get_meta("clock")[0] += DAY

	# Every 2-3 runs: count the runs between interstitials over many breaks.
	save.data.ads.runs_since_interstitial = 0
	var gaps := []
	var since := 0
	for run in 30:
		ads.end_run()
		since += 1
		await _until(t, func() -> bool: return ads.interstitial_block_reason() != "not_loaded")
		if await _break(t, ads):
			gaps.append(since)
			since = 0
	t.check(not gaps.is_empty() and gaps.all(func(g: int) -> bool: return g >= 2 and g <= 3), "gaps between interstitials are 2-3 runs (%s)" % [gaps])
	t.check(gaps.has(2) and gaps.has(3), "both 2 and 3 happen (%s)" % [gaps])

	# Just watched a rewarded ad (in the run or on its game over): skipped.
	save.data.ads.runs_since_interstitial = 5
	await _until(t, func() -> bool: return ads.can_offer("double_coins"))
	await _watch(t, ads, "double_coins")
	await _until(t, func() -> bool: return ads.interstitial_block_reason() != "not_loaded")
	t.check(ads.interstitial_block_reason() == "after_rewarded", "skipped right after a rewarded ad")
	t.check(not await _break(t, ads), "no interstitial at that break")
	t.check(await _break(t, ads), "the next break may show one again")
	_done(t)


func test_interstitial_failure_still_reaches_the_menu(t) -> void:
	var save := _save(t)
	var fake := FakeAdBackend.new()
	var ads := _ads(t, save, fake)
	for outcome: String in ["fail_show", "silent"]:
		fake.outcome = outcome
		save.data.ads.runs_since_interstitial = 9
		await _until(t, func() -> bool: return ads.interstitial_block_reason() == "")
		t.paused = true  # game over screen
		var shown := await _break(t, ads)
		t.check(not shown and t.paused and not ads.is_showing(), "%s: break ends, game-over pause intact" % outcome)
		t.check(int(save.data.ads.runs_since_interstitial) == 9, "%s: a failed ad doesn't reset the gap" % outcome)
	t.paused = false
	_done(t)


# --- Banner and Remove Ads ---------------------------------------------------------

func test_banner_on_request_with_inset(t) -> void:
	var save := _save(t)
	var fake := FakeAdBackend.new()
	var ads := _ads(t, save, fake)
	t.check(ads.banner_screen("menu") and ads.banner_screen("shop") and ads.banner_screen("unlocks"), "banner screens from data")
	t.check(not ads.banner_screen("hero") and not ads.banner_screen("run"), "not on other screens")
	ads.set_banner(true)
	await _until(t, func() -> bool: return ads.banner_inset > 0)
	t.check(fake.banner_visible and ads.banner_inset > 0, "banner shown, inset %d" % ads.banner_inset)
	ads.set_banner(false)
	t.check(not fake.banner_visible and ads.banner_inset == 0, "hidden off the menu screens")
	_done(t)


func _store(t, save: Node, fake: FakeStoreBackend) -> Node:
	var store: Node = StoreScript.new()
	t.root.add_child(store)
	store.start(save, fake)
	_nodes.append(store)
	return store


func test_remove_ads_removes_interstitials_and_banners(t) -> void:
	var save := _save(t)
	var fake_ads := FakeAdBackend.new()
	var ads := _ads(t, save, fake_ads)
	var fake_store := FakeStoreBackend.new()
	var store := _store(t, save, fake_store)
	store.changed.connect(ads.refresh)
	ads.set_banner(true)
	save.data.ads.runs_since_interstitial = 9
	await _until(t, func() -> bool: return ads.banner_inset > 0 and ads.interstitial_block_reason() == "")
	t.check(store.state("remove_ads") == "buyable" and store.price_text("remove_ads") == "USD 1.99", "Remove Ads for sale (%s)" % store.state("remove_ads"))

	fake_store.outcome = "canceled"
	store.buy("remove_ads")
	await _until(t, func() -> bool: return store.state("remove_ads") != "busy")
	t.check(not store.owns("remove_ads") and ads.banner_inset > 0, "canceled: nothing changes")
	fake_store.outcome = "pending"
	store.buy("remove_ads")
	await _until(t, func() -> bool: return store.state("remove_ads") != "busy")
	t.check(store.state("remove_ads") == "pending" and not ads.removed(), "pending: not granted yet")

	fake_store.outcome = "owned"
	store.buy("remove_ads")  # refused while pending
	t.check(fake_store.calls.count("buy:remove_ads") == 2, "no second flow while a payment is pending")
	fake_store.owned_ids = ["remove_ads"]
	store.restore()  # the pending payment went through
	await _until(t, func() -> bool: return store.owns("remove_ads"))
	t.check(ads.removed() and bool(save.data.ads.removed), "owned: written to the save")
	t.check(not fake_ads.banner_visible and ads.banner_inset == 0 and "banner_destroy" in fake_ads.calls, "banner gone at once")
	ads.set_banner(true)
	t.check(not fake_ads.banner_visible and ads.banner_inset == 0, "and never comes back")
	t.check(ads.interstitial_block_reason() == "removed" and not await _break(t, ads), "no interstitials")
	ads.begin_run()
	await _until(t, func() -> bool: return ads.rewarded_ready())
	t.check(ads.can_offer("revive") and ads.can_offer("daily"), "rewarded ads stay available")
	t.check(store.state("remove_ads") == "owned", "shop shows OWNED")
	_done(t)


func test_store_list_wins(t) -> void:
	var save := _save(t)
	var fake := FakeStoreBackend.new()
	var store := _store(t, save, fake)
	await _frames(t)
	fake.owned_changed.emit(["remove_ads"], true)
	t.check(store.owns("remove_ads"), "restored from the store (new install)")
	fake.owned_changed.emit([], false)
	t.check(store.owns("remove_ads"), "an incomplete list doesn't take it away")
	fake.owned_changed.emit([], true)
	t.check(not store.owns("remove_ads"), "the store's full list without it (refund) takes it away")
	_done(t)


# --- In a run --------------------------------------------------------------------

func _run(t, ads: Node, opts := {}) -> Run:
	var o := {"bot": true, "no_save": true, "seed": 5, "ads": ads, "no_spawns": true}
	o.merge(opts, true)
	Run.next_options = o
	var run: Run = RUN_SCENE.instantiate()
	t.root.add_child(run)
	_nodes.append(run)
	return run


func test_revive(t) -> void:
	var save := _save(t)
	var fake := FakeAdBackend.new()
	var ads := _ads(t, save, fake)
	await _until(t, func() -> bool: return ads.rewarded_ready())
	var run := _run(t, ads)
	for i in 6:
		run.enemies.spawn(run.enemies.type_index["blob"], run.player_pos() + Vector2(8, 0).rotated(i), 1, 1, 1)
	run.enemy_shots.fire(run.player_pos() + Vector2(20, 0), Vector2(-10, 0), 1.0, 2.0, 5.0)
	run.hp = 0.0
	run.tick(DT)
	t.check(run.state == "dying" and t.paused, "death with an ad ready: revive offer, game paused")
	t.check(run._revive_panel.visible and run._revive_btn.visible, "revive button shows")

	fake.outcome = "fail_show"
	run._on_revive_pressed()
	await _until(t, func() -> bool: return not ads.is_showing())
	await _frames(t)
	t.check(run.state == "dying" and t.paused and run._revive_panel.visible, "ad failed: back to the offer, still paused")

	fake.outcome = "complete"
	await _until(t, func() -> bool: return ads.can_offer("revive"))
	run._on_revive_pressed()
	await _until(t, func() -> bool: return run.state != "dying")
	t.check(run.state == "live" and not t.paused and run.revived, "revived: playing again, unpaused")
	t.check(run.hp > 0.0 and run._iframes > 0.0, "HP back (%.0f) with i-frames" % run.hp)
	var close := PackedInt32Array()
	run.enemies.query_circle(run.player_pos(), 40.0, close)
	t.check(close.is_empty() and run.enemy_shots.count() == 0, "room to breathe: enemies pushed out, shots gone")

	run.hp = 0.0
	run.tick(DT)
	t.check(run.state == "over" and not run.won, "second death: 1 revive per run, game over")
	_done(t)


func test_no_revive_offer_without_ad_or_from_bills(t) -> void:
	var save := _save(t)
	var fake := FakeAdBackend.new()
	fake.fill = false
	var ads := _ads(t, save, fake)
	await _frames(t)
	var run := _run(t, ads)
	run.hp = 0.0
	run.tick(DT)
	t.check(run.state == "over", "no ad loaded: straight to game over")
	_done(t)

	save = _save(t)
	ads = _ads(t, save)
	await _until(t, func() -> bool: return ads.rewarded_ready())
	run = _run(t, ads)
	run.last_damage_source = String(run.db.get_entry("rules", "bills").enemy)
	run.hp = 0.0
	run.tick(DT)
	t.check(run.state == "over" and run.end_reason == "bills", "Overdue Bills end the run: no revive (%s)" % run.end_reason)
	_done(t)

	save = _save(t)
	ads = _ads(t, save)
	await _until(t, func() -> bool: return ads.rewarded_ready())
	run = _run(t, ads)
	run.hp = 0.0
	run.tick(DT)
	run._decline_revive()
	t.check(run.state == "over" and run.end_reason == "died", "NO THANKS: game over")
	_done(t)


func test_level_up_actions_by_ad(t) -> void:
	var save := _save(t)
	var fake := FakeAdBackend.new()
	var ads := _ads(t, save, fake)
	await _until(t, func() -> bool: return ads.rewarded_ready())
	var run := _run(t, ads, {"charges": {"reroll": 0, "skip": 0, "banish": 0}, "all_content": true})
	run.add_xp(1000.0)
	run.tick(DT)
	t.check(run.state == "level_up", "level-up open")
	run._show_cards()
	for a: String in ["reroll", "skip"]:
		t.check(run._action_buttons[a].visible and run._action_buttons[a].ad, "%s: AD button shows with an ad ready" % a)

	var before := run._cards.map(func(c: Dictionary) -> String: return c.id)
	run._on_action("reroll")
	t.check(run._cards.map(func(c: Dictionary) -> String: return c.id) == before, "tap alone rerolls nothing")
	await _until(t, func() -> bool: return not ads.is_showing())
	await _frames(t)
	t.check(run.charges.reroll == 0 and run.state == "level_up" and t.paused, "rerolled by ad, charge used, still on the cards")
	await _until(t, func() -> bool: return ads.rewarded_ready())
	run._show_cards()
	t.check(not run._action_buttons.reroll.visible, "reroll ad used for this run: button gone")

	fake.outcome = "close_early"
	var levels := run.pending_levels
	run._on_action("skip")
	await _until(t, func() -> bool: return not ads.is_showing())
	await _frames(t)
	t.check(run.pending_levels == levels and run.state == "level_up", "skipped ad: no skip")
	fake.outcome = "complete"
	await _until(t, func() -> bool: return ads.can_offer("skip"))
	run._show_cards()
	t.check(run._action_buttons.skip.visible, "skip still offered after a skipped ad")
	if run._cards.any(run._can_banish):
		run._on_action("banish")
		await _until(t, func() -> bool: return not ads.is_showing())
		await _frames(t)
		t.check(run._banish_mode and run.charges.banish == 1, "banish by ad: banish mode with the paid charge")
	_done(t)


func test_double_coins(t) -> void:
	var save := _save(t)
	var fake := FakeAdBackend.new()
	var ads := _ads(t, save, fake)
	await _until(t, func() -> bool: return ads.rewarded_ready())
	var run_save := _save(t)
	var run := _run(t, ads, {"no_save": false, "save": run_save, "start_at": 300.0})
	run.hp = 0.0
	run.tick(DT)
	run._decline_revive()
	var coins: int = run.result.coins
	var wallet := int(run_save.data.coins)
	t.check(run.state == "over" and coins > 0 and wallet == coins, "game over with %d coins" % coins)
	t.check(run._double_btn.visible, "2X COINS shows on the game over screen")
	run._on_double_pressed()
	await _until(t, func() -> bool: return not ads.is_showing())
	await _frames(t)
	t.check(int(run_save.data.coins) == wallet + coins and run.result.coins_doubled, "coins doubled in the save (%d)" % run_save.data.coins)
	t.check(not run._double_btn.visible, "once per run")
	run._on_double_pressed()
	await _frames(t)
	t.check(int(run_save.data.coins) == wallet + coins, "can't double twice")
	t.check(int(save.data.ads.runs_since_interstitial) == 1, "the run counted toward the interstitial gap")
	_done(t)


# --- Backends -------------------------------------------------------------------

## Stands in for the AdMob AdView native plugin (AdView._plugin), so the real
## admob_backend.gd can run without a device: each AdView is a uid, and loads
## answer only when the test emits on_ad_loaded / on_ad_failed_to_load.
class FakeAdViewPlugin extends RefCounted:
	signal on_ad_clicked(uid: int)
	signal on_ad_closed(uid: int)
	signal on_ad_failed_to_load(uid: int, error: Dictionary)
	signal on_ad_impression(uid: int)
	signal on_ad_loaded(uid: int)
	signal on_ad_opened(uid: int)
	signal on_ad_view_paid(uid: int, value: Dictionary)
	var created := 0
	var alive := {}  # uid -> true until destroyed
	var loads: Array[int] = []

	func create(_d: Dictionary) -> int:
		created += 1
		alive[created] = true
		return created

	func load_ad(uid: int, _r: Dictionary, _k: Array) -> void:
		loads.append(uid)

	func destroy(uid: int) -> void:
		alive.erase(uid)

	func hide(_uid: int) -> void:
		pass

	func show(_uid: int) -> void:
		pass

	func get_height_in_pixels(_uid: int) -> int:
		return 150


const NO_FILL := {"code": 3, "domain": "com.google.android.gms.ads", "message": "No fill.", "cause": {}, "response_info": {}}


## AdMob doesn't retry a banner whose first load failed: the backend must drop
## that AdView so the Ads service's retry makes a new one.
func test_admob_banner_reloads_after_a_failed_load(t) -> void:
	var plugin := FakeAdViewPlugin.new()
	var real: Variant = AdView._plugin
	AdView._plugin = plugin
	var backend: AdBackend = load("res://scripts/ads/admob_backend.gd").new()
	t.root.add_child(backend)
	_nodes.append(backend)
	backend._initialized = true  # as after MobileAds.initialize
	backend._units = {"banner": "test-unit"}
	var failed := []
	var loaded := []
	backend.banner_failed.connect(func(e: String) -> void: failed.append(e))
	backend.banner_loaded.connect(func() -> void: loaded.append(true))
	backend.banner_show()
	backend.banner_load()
	plugin.on_ad_failed_to_load.emit(1, NO_FILL)
	await _until(t, func() -> bool: return not failed.is_empty())
	t.check(failed.size() == 1 and backend.banner_height_px() == 0, "failure reported, no height")
	t.check(not plugin.alive.has(1), "the failed AdView is destroyed")
	backend.banner_load()  # what the Ads retry does
	t.check(plugin.created == 2 and plugin.loads == [1, 2], "the retry makes and loads a new banner (created %d, loads %s)" % [plugin.created, plugin.loads])
	plugin.on_ad_loaded.emit(2)
	await _until(t, func() -> bool: return not loaded.is_empty())
	t.check(backend.banner_height_px() == 150, "the new banner loads (height %d)" % backend.banner_height_px())
	AdView._plugin = real
	_done(t)


func test_banner_retries_until_it_loads(t) -> void:
	var save := _save(t)
	var fake := FakeAdBackend.new()
	fake.fill = false
	var ads := _ads(t, save, fake)
	ads.set_banner(true)
	t.check(await _until(t, func() -> bool: return fake.calls.count("banner_load") >= 3), "failed banner loads are retried (%s)" % [fake.calls])
	t.check(ads.banner_inset == 0, "no inset while nothing loaded")
	fake.fill = true
	t.check(await _until(t, func() -> bool: return ads.banner_inset > 0), "a retry loads it")
	t.check(int(ads._fails.banner) == 0, "a load resets the backoff (%d)" % ads._fails.banner)
	_done(t)


## Fakes pay out for nothing: only debug builds (editor, tests, debug APKs)
## get them. A release build without the plugin gets the inert base backend.
func test_fake_backends_only_in_debug_builds(t) -> void:
	t.check(AdsScript.backend_kind(true, false) == "sdk" and AdsScript.backend_kind(true, true) == "sdk", "ads: the SDK whenever its plugin is there")
	t.check(AdsScript.backend_kind(false, true) == "fake", "ads: fake in a debug build")
	t.check(AdsScript.backend_kind(false, false) == "none", "ads: nothing in a release build without the plugin")
	t.check(StoreScript.backend_kind(true, false) == "sdk" and StoreScript.backend_kind(true, true) == "sdk", "store: Play Billing whenever its plugin is there")
	t.check(StoreScript.backend_kind(false, true) == "fake", "store: fake in a debug build")
	t.check(StoreScript.backend_kind(false, false) == "none", "store: nothing in a release build without the plugin")

	var save := _save(t)
	var store: Node = StoreScript.new()
	t.root.add_child(store)
	_nodes.append(store)
	store.start(save, StoreBackend.new())
	await _frames(t)
	t.check(store.state("remove_ads") == "unavailable" and not store.buy("remove_ads") and not store.owns("remove_ads"), "no store: STORE OFFLINE, nothing to buy (%s)" % store.state("remove_ads"))

	var ads: Node = AdsScript.new()
	t.root.add_child(ads)
	_nodes.append(ads)
	save.data.ads.first_seen = 1
	save.data.ads.runs_since_interstitial = 9
	ads.start(save, AdBackend.new(), _cfg())
	ads.set_banner(true)
	await _frames(t)
	t.check(not ads.can_offer("revive") and not ads.can_offer("daily"), "no SDK: no rewarded buttons")
	t.check(ads.interstitial_block_reason() == "not_loaded" and ads.banner_inset == 0, "no SDK: no interstitial, no banner gap")
	_done(t)

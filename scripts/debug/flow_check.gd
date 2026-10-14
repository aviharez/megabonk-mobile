extends Node
## End-to-end check of the screens: menu -> Play -> Pick a Hero (a new save
## skips Pick a District) -> Start -> run -> death -> game over (with unlock
## progress) -> Menu -> the Quests rail counts the run's milestone, Claim
## pays -> Collection, Shop and Characters open and close ->
## with Mega Mole beaten and Turbo Pigeon owned, Play opens Pick a District
## (New! on Danger 2), Danger 2 > Next > Turbo Pigeon > Start runs him there
## on Danger 2, and Play Again starts the same run with no Pick steps.
## Ads (FakeAdBackend / FakeStoreBackend, the desktop stand-ins): banner on
## the menu and never in the run, daily reward, revive, 2x coins, the
## interstitial on the way back to the menu, Remove Ads from the shop.
## Uses a throwaway save file. Prints "FLOW OK" or "FLOW FAIL".
##   godot --headless --path . res://scenes/debug/flow_check.tscn

const TEST_SAVE := "user://flow_check_save.json"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_check.call_deferred()


func _check() -> void:
	reparent(get_tree().root)
	var save := get_node("/root/Save")
	var real_path: String = save.path
	save.path = TEST_SAVE
	save.reset()
	var tree := get_tree()
	var fails := []
	# Step out of the current scene so changing scenes doesn't free this node.
	var stand_in := Node.new()
	tree.root.add_child(stand_in)
	tree.current_scene = stand_in

	var ads := get_node("/root/Ads")
	var fake: FakeAdBackend = ads.backend
	tree.change_scene_to_file("res://scenes/main_menu.tscn")
	await _frames(3)
	await _ads_on_menu(tree, ads, save, fails)
	await _play(tree.current_scene)
	var run := tree.current_scene as Run
	if run == null:
		fails.append("Play > Start did not open the run")
	else:
		await _frames(30)
		if run.elapsed <= 0.0:
			fails.append("run time does not advance")
		if fake.banner_visible or ads.banner_inset != 0:
			fails.append("banner visible during gameplay")
		await _ads_revive(tree, run, ads, fails)
		run.elapsed = 120.0  # enough play time to earn coins for 2X COINS
		run.hp = 0.0
		await _frames(2)
		if run.state != "over" or not tree.paused:
			fails.append("death did not end and pause the run (state=%s)" % run.state)
		if save.data.runs_played != 1:
			fails.append("runs_played not recorded (%s)" % save.data.runs_played)
		var back: PixelButton = null
		for n in run.find_children("*", "PixelButton", true, false):
			if n.name == "Menu":
				back = n
		if not run.find_children("*", "ChallengeRow", true, false).size() in [2, 3]:
			fails.append("game over doesn't show 2-3 closest unlocks")
		await _ads_double(run, ads, save, fails)
		# Old enough install, enough runs: the break shows an interstitial.
		save.data.ads.first_seen = int(Time.get_unix_time_from_system()) - 2 * 86400
		save.data.ads.runs_since_interstitial = 9
		await _until(func() -> bool: return ads.interstitial_block_reason() != "not_loaded", 5.0)
		# This run had rewarded ads (revive, 2x coins), so the break skips it...
		if ads.interstitial_block_reason() != "after_rewarded":
			fails.append("interstitial not skipped after rewarded ads (%s)" % ads.interstitial_block_reason())
		# ...as if it hadn't, the break shows one.
		save.data.ads.rewarded_since_break = false
		await _until(func() -> bool: return ads.interstitial_block_reason() == "", 5.0)
		var shows := fake.calls.count("show:interstitial")
		back.pressed.emit()
		await _until(func() -> bool: return tree.current_scene != null and tree.current_scene.name == "MainMenu", 5.0)
		await _frames(3)
		if fake.calls.count("show:interstitial") != shows + 1:
			fails.append("no interstitial at the game over -> menu break")
		if tree.current_scene == null or tree.current_scene.name != "MainMenu" or tree.paused:
			fails.append("MENU did not return to an unpaused menu")
		else:
			await _ads_remove(tree, ads, fake, save, fails)
			await _menu_screens(tree, save, fails)

	save.reset()
	DirAccess.remove_absolute(TEST_SAVE)
	DirAccess.remove_absolute(TEST_SAVE + ".bak")
	save.path = real_path
	save.load_game()
	print("FLOW OK" if fails.is_empty() else "FLOW FAIL: " + "; ".join(fails))
	tree.quit(0 if fails.is_empty() else 1)


## A new save: Play opens Pick a Hero (no district step), Start runs.
func _play(menu: Node) -> void:
	menu.get_node("Frame/Buttons/Play").pressed.emit()
	await _frames(2)
	if not menu.find_children("*", "PickDistrictScreen", true, false).is_empty():
		return
	var start := menu.find_child("Start", true, false)
	if start != null:
		start.pressed.emit()
	await _frames(3)


## The Collection, Shop and Characters tabs open and close; with Mega Mole
## beaten Play opens Pick a District (New! on Danger 2), Next Pick a Hero,
## and Start runs the picked hero on the picked danger; Play Again repeats it.
func _menu_screens(tree: SceneTree, save: Node, fails: Array) -> void:
	var menu := tree.current_scene
	# Quests: the first run finished a milestone; the rail counts it, opens
	# Quests (no nav), Claim pays, back on Home the count drops.
	var rail: KitButton = menu.get_node("Frame/Buttons/Quests")
	var count := rail.count
	if rail.sticker != "count" or count < 1:
		fails.append("the Quests rail shows nothing to claim after a run (%s %d)" % [rail.sticker, count])
	else:
		rail.pressed.emit()
		await _frames(2)
		var qs: QuestsScreen = null
		for c in menu.get_children():
			if c is QuestsScreen:
				qs = c
		if qs == null:
			fails.append("the Quests rail did not open Quests")
		else:
			var claim: KitButton = qs.find_child("Claim", true, false)
			var coins := int(save.data.coins)
			if claim == null:
				fails.append("Quests has no Claim button")
			else:
				claim.pressed.emit()
				await _frames(2)
				if int(save.data.coins) <= coins:
					fails.append("Claim did not pay")
			qs.close()
			await _frames(2)
			if rail.count >= count and rail.sticker == "count":
				fails.append("the Quests count did not drop after a claim (%d -> %d)" % [count, rail.count])
	for b: Array in [["Collection", "UnlocksScreen"], ["Shop", "ShopScreen"], ["Characters", "CharactersScreen"]]:
		menu.get_node("Nav/" + b[0]).pressed.emit()
		await _frames(2)
		var screens := menu.get_children().filter(func(c: Node) -> bool: return c is MenuScreen)
		if screens.size() != 1 or screens[0].get_script().get_global_name() != b[1]:
			fails.append("%s did not open %s" % [b[0], b[1]])
			continue
		screens[0].close()
		await _frames(2)
	save.data.unlocks["turbo_pigeon"] = "owned"
	Meta.commit_run(GameData.shared(), save.data, {"boss_defeated": 1.0}, "sir_loaf", 0, "suburbia", 300.0, 1)
	menu.get_node("Frame/Buttons/Play").pressed.emit()
	await _frames(2)
	var district: PickDistrictScreen = null
	for c in menu.get_children():
		if c is PickDistrictScreen:
			district = c
	if district == null:
		fails.append("after Mega Mole, Play did not open Pick a District")
		return
	var two: PickDistrictScreen.DangerTile = district.find_child("Danger2", true, false)
	if two == null or not two.is_new or two.locked:
		fails.append("Danger 2 is not open with New!")
		return
	two.pressed.emit()
	await _frames(2)
	district.find_child("Next", true, false).pressed.emit()
	await _frames(2)
	var hero: PickHeroScreen = null
	for c in district.get_children():
		if c is PickHeroScreen:
			hero = c
	if hero == null:
		fails.append("Next did not open Pick a Hero")
		return
	hero.select("turbo_pigeon")
	await _frames(2)
	hero.find_child("Start", true, false).pressed.emit()
	await _frames(3)
	var run := tree.current_scene as Run
	if run == null or run.char_def.id != "turbo_pigeon" or run.weapons[0].def.id != "sharp_feathers":
		fails.append("picking Turbo Pigeon did not start his run with Sharp Feathers")
		tree.paused = false
		return
	if save.data.character != "turbo_pigeon" or save.data.map != "suburbia" or int(save.data.danger) != 2 or run.danger_level != 2:
		fails.append("the picks were not remembered / the danger was not played")
	# Play Again: the same hero, district and danger, straight into a new run.
	await _frames(10)
	run.hp = 0.0
	await _frames(2)
	var again: PixelButton = run.find_child("PlayAgain", true, false)
	if again == null:
		fails.append("no Play Again button")
		tree.paused = false
		return
	again.pressed.emit()
	# A break like the way to the menu: the fake interstitial may show first.
	# (The old run is freed by then: compare ids, not the node.)
	var old_id := run.get_instance_id()
	await _until(func() -> bool: return tree.current_scene is Run and tree.current_scene.get_instance_id() != old_id, 5.0)
	var run2 := tree.current_scene as Run
	if run2 == null or run2.get_instance_id() == old_id:
		fails.append("Play Again did not start a new run")
	elif run2.char_def.id != "turbo_pigeon" or run2.danger_level != 2 or run2.map_def.id != "suburbia":
		fails.append("Play Again changed the run (%s, %s, danger %d)" % [run2.char_def.id, run2.map_def.id, run2.danger_level])
	tree.paused = false


## The menu has the banner (menu stays above it) and the daily reward.
func _ads_on_menu(tree: SceneTree, ads: Node, save: Node, fails: Array) -> void:
	var menu := tree.current_scene
	if not await _until(func() -> bool: return ads.banner_inset > 0, 5.0):
		fails.append("no banner on the menu")
	elif menu.offset_bottom != -ads.banner_inset:
		fails.append("menu doesn't keep clear of the banner")
	var daily: KitButton = menu.get_node("Frame/Buttons/Daily")
	if not await _until(func() -> bool: return daily.visible and not daily.disabled, 5.0):
		fails.append("daily reward button never shows")
		return
	var coins := int(save.data.coins)
	daily.pressed.emit()
	if not tree.paused:
		fails.append("menu not paused while the daily ad plays")
	await _until(func() -> bool: return not ads.is_showing(), 5.0)
	await _frames(2)
	var want := coins + int(ads.config.daily.coins)
	# Kit v2: the Daily rail button stays, greyed out (no AD sticker) once used.
	if int(save.data.coins) != want or not daily.disabled or daily.sticker != "" or tree.paused:
		fails.append("daily reward: coins %d (want %d), button off %s, paused %s" % [save.data.coins, want, daily.disabled, tree.paused])


## Death -> revive offer -> REVIVE -> playing again.
func _ads_revive(tree: SceneTree, run: Run, ads: Node, fails: Array) -> void:
	await _until(func() -> bool: return ads.can_offer("revive"), 5.0)
	run.hp = 0.0
	await _frames(2)
	if run.state != "dying" or not tree.paused:
		fails.append("death with an ad ready didn't offer a revive (state=%s)" % run.state)
		return
	run._revive_btn.pressed.emit()
	await _until(func() -> bool: return run.state != "dying", 5.0)
	await _frames(2)
	if run.state != "live" or tree.paused or run.hp <= 0.0:
		fails.append("revive didn't resume the run (state=%s paused=%s)" % [run.state, tree.paused])


## Game over -> 2X COINS -> the run's coins once more.
func _ads_double(run: Run, ads: Node, save: Node, fails: Array) -> void:
	await _until(func() -> bool: return run._double_btn.visible, 5.0)
	if run.result.coins <= 0 or not run._double_btn.visible:
		fails.append("no 2X COINS button on the game over screen")
		return
	var coins := int(save.data.coins)
	run._double_btn.pressed.emit()
	await _until(func() -> bool: return not ads.is_showing(), 5.0)
	await _frames(2)
	if int(save.data.coins) != coins + int(run.result.coins):
		fails.append("2X COINS didn't add the run's coins again")


## SHOP -> NO ADS -> bought: the banner is gone.
func _ads_remove(tree: SceneTree, ads: Node, fake: FakeAdBackend, save: Node, fails: Array) -> void:
	var menu := tree.current_scene
	menu.get_node("Nav/Shop").pressed.emit()
	await _frames(3)
	var shop := menu.find_children("*", "ShopScreen", true, false)
	if not shop.is_empty():
		shop[0].show_offers()
		await _frames(2)
	var store := get_node("/root/Store")
	if not await _until(func() -> bool: return store.state("remove_ads") == "buyable" and ads.banner_inset > 0, 5.0):
		fails.append("shop: no banner or Remove Ads not for sale (%s)" % store.state("remove_ads"))
		return
	var buy: PixelButton = null
	for b in menu.find_children("*", "PixelButton", true, false):
		if b.label == store.price_text("remove_ads"):
			buy = b
	if buy == null:
		fails.append("shop: no Remove Ads price button")
		return
	buy.pressed.emit()
	await _until(func() -> bool: return store.owns("remove_ads"), 5.0)
	await _frames(2)
	if not save.data.ads.removed or fake.banner_visible or ads.banner_inset != 0 or menu.offset_bottom != 0:
		fails.append("Remove Ads bought but the banner stayed")
	if ads.interstitial_block_reason() != "removed":
		fails.append("Remove Ads bought but interstitials still allowed")
	for s in menu.get_children():
		if s is MenuScreen:
			s.close()
	await _frames(2)


func _until(cond: Callable, sec: float) -> bool:
	var end := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

extends Node
## End-to-end check of the screens: menu -> PLAY -> hero select -> map
## select -> run -> death -> game over (with unlock progress) -> MENU
## -> UNLOCKS and SHOP open and close -> with Turbo Pigeon owned, picking him
## and the map starts his run there.
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
		fails.append("PLAY > NEXT > GO! did not open the run")
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


## PLAY, then NEXT on the hero select and GO! on the map select.
func _play(menu: Node) -> void:
	menu.get_node("Frame/Buttons/Play").pressed.emit()
	await _frames(2)
	var next := menu.find_child("Next", true, false)
	if next == null:
		return
	next.pressed.emit()
	await _frames(2)
	var go := menu.find_child("Go", true, false)
	if go != null:
		go.pressed.emit()
	await _frames(3)


## UNLOCKS and SHOP open and close; PLAY opens the hero select, NEXT the
## map select, and GO! starts the picked hero's run on the picked map.
func _menu_screens(tree: SceneTree, save: Node, fails: Array) -> void:
	var menu := tree.current_scene
	for b: Array in [["Unlocks", "UnlocksScreen"], ["Shop", "ShopScreen"]]:
		menu.get_node("Frame/Buttons/" + b[0]).pressed.emit()
		await _frames(2)
		var screens := menu.get_children().filter(func(c: Node) -> bool: return c is MenuScreen)
		if screens.size() != 1 or screens[0].get_script().get_global_name() != b[1]:
			fails.append("%s did not open %s" % [b[0], b[1]])
			continue
		screens[0].close()
		await _frames(2)
	save.data.unlocks["turbo_pigeon"] = "owned"
	menu.get_node("Frame/Buttons/Play").pressed.emit()
	await _frames(2)
	var hero: HeroScreen = null
	for c in menu.get_children():
		if c is HeroScreen:
			hero = c
	if hero == null:
		fails.append("PLAY did not open the hero select")
		return
	hero.select("turbo_pigeon")
	await _frames(2)
	hero.find_child("Next", true, false).pressed.emit()
	await _frames(2)
	var maps: MapScreen = null
	for c in hero.get_children():
		if c is MapScreen:
			maps = c
	if maps == null:
		fails.append("NEXT did not open the map select")
		return
	maps.find_child("Go", true, false).pressed.emit()
	await _frames(3)
	var run := tree.current_scene as Run
	if run == null or run.char_def.id != "turbo_pigeon" or run.weapons[0].def.id != "sharp_feathers":
		fails.append("picking Turbo Pigeon did not start his run with Sharp Feathers")
	elif save.data.character != "turbo_pigeon" or save.data.map != "suburbia" or run.map_def.id != "suburbia":
		fails.append("the picks were not remembered / the map was not used")
	tree.paused = false


## The menu has the banner (menu stays above it) and the daily reward.
func _ads_on_menu(tree: SceneTree, ads: Node, save: Node, fails: Array) -> void:
	var menu := tree.current_scene
	if not await _until(func() -> bool: return ads.banner_inset > 0, 5.0):
		fails.append("no banner on the menu")
	elif menu.offset_bottom != -ads.banner_inset:
		fails.append("menu doesn't keep clear of the banner")
	var daily: AdButton = menu.get_node("Frame/Buttons/Daily")
	if not await _until(func() -> bool: return daily.visible, 5.0):
		fails.append("daily reward button never shows")
		return
	var coins := int(save.data.coins)
	daily.pressed.emit()
	if not tree.paused:
		fails.append("menu not paused while the daily ad plays")
	await _until(func() -> bool: return not ads.is_showing(), 5.0)
	await _frames(2)
	var want := coins + int(ads.config.daily.coins)
	if int(save.data.coins) != want or daily.visible or tree.paused:
		fails.append("daily reward: coins %d (want %d), button %s, paused %s" % [save.data.coins, want, daily.visible, tree.paused])


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
	menu.get_node("Frame/Buttons/Shop").pressed.emit()
	await _frames(3)
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

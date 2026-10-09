extends AdBackend
## AdBackend on the Poing AdMob plugin (addons/admob, Google Mobile Ads
## Next-Gen SDK). Only loaded on a device that has the native plugin
## (Ads._make_backend), so desktop runs and tests never touch the SDK classes.
## No class_name on purpose: naming the plugin's classes here makes them load.
##
## The Next-Gen SDK throws (and the app crashes) if an ad loads before
## MobileAds.initialize has finished, so loads and the banner wait in
## `_queued` until the init callback.

var _units := {}
var _ready_ads := {}  # format -> RewardedAd / InterstitialAd
var _banner: AdView
var _banner_loaded := false
var _banner_visible := false
var _initialized := false
var _queued: Array[Callable] = []


func setup(units: Dictionary) -> void:
	_units = units
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = func(_status: InitializationStatus) -> void:
		print("Ads: AdMob initialized")
		_initialized = true
		var q := _queued.duplicate()
		_queued.clear()
		for c: Callable in q:
			c.call()
	MobileAds.initialize(listener)


func load_ad(format: String) -> void:
	if not _initialized:
		_queued.append(load_ad.bind(format))
		return
	var unit: String = _units.get(format, "")
	match format:
		"rewarded":
			var cb := RewardedAdLoadCallback.new()
			cb.on_ad_loaded = func(ad: RewardedAd) -> void: _on_loaded(format, ad)
			cb.on_ad_failed_to_load = func(err: LoadAdError) -> void: load_failed.emit(format, err.message)
			RewardedAdLoader.new().load(unit, AdRequest.new(), cb)
		"interstitial":
			var cb := InterstitialAdLoadCallback.new()
			cb.on_ad_loaded = func(ad: InterstitialAd) -> void: _on_loaded(format, ad)
			cb.on_ad_failed_to_load = func(err: LoadAdError) -> void: load_failed.emit(format, err.message)
			InterstitialAdLoader.new().load(unit, AdRequest.new(), cb)


func _on_loaded(format: String, ad: Variant) -> void:
	var fsc := FullScreenContentCallback.new()
	fsc.on_ad_showed_full_screen_content = func() -> void: showed.emit(format)
	fsc.on_ad_failed_to_show_full_screen_content = func(err: AdError) -> void:
		_drop(format)
		show_failed.emit(format, err.message)
	fsc.on_ad_dismissed_full_screen_content = func() -> void:
		_drop(format)
		dismissed.emit(format)
	ad.full_screen_content_callback = fsc
	_ready_ads[format] = ad
	loaded.emit(format)


func show_ad(format: String) -> void:
	var ad: Variant = _ready_ads.get(format)
	if ad == null:
		show_failed.emit.call_deferred(format, "no ad loaded")
		return
	if format == "rewarded":
		var listener := OnUserEarnedRewardListener.new()
		listener.on_user_earned_reward = func(_item: RewardedItem) -> void: earned.emit(format)
		ad.show(listener)
	else:
		ad.show()


## A full-screen ad is single use: free it once it's done.
func _drop(format: String) -> void:
	var ad: Variant = _ready_ads.get(format)
	_ready_ads.erase(format)
	if ad != null:
		ad.destroy()


func banner_load() -> void:
	if not _initialized:
		_queued.append(banner_load)
		return
	if _banner != null:
		return
	var size := AdSize.get_current_orientation_anchored_adaptive_banner_ad_size(AdSize.FULL_WIDTH)
	_banner = AdView.new(_units.get("banner", ""), size, AdPosition.BOTTOM)
	var l := AdListener.new()
	l.on_ad_loaded = func() -> void:
		_banner_loaded = true
		if not _banner_visible:
			_banner.hide()
		banner_loaded.emit()
	l.on_ad_failed_to_load = func(err: LoadAdError) -> void:
		# AdMob doesn't retry an AdView whose load failed: drop it so the
		# next banner_load (the Ads retry) makes a new one.
		_banner_loaded = false
		if _banner != null:
			_banner.destroy()
			_banner = null
		banner_failed.emit(err.message)
	_banner.ad_listener = l
	_banner.load_ad(AdRequest.new())
	if not _banner_visible:
		_banner.hide()


func banner_show() -> void:
	_banner_visible = true
	if _banner != null:
		_banner.show()


func banner_hide() -> void:
	_banner_visible = false
	if _banner != null:
		_banner.hide()


func banner_destroy() -> void:
	_banner_visible = false
	_banner_loaded = false
	if _banner != null:
		_banner.destroy()
		_banner = null


func banner_height_px() -> int:
	if _banner == null or not _banner_loaded:
		return 0
	return maxi(0, _banner.get_height_in_pixels())

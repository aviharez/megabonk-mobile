class_name AdBackend
extends Node
## What the Ads service needs from an ad SDK. Formats: "rewarded" and
## "interstitial" (full screen), plus one bottom banner. Implementations:
## AdMobBackend (the Poing AdMob plugin, on Android/iOS) and FakeAdBackend
## (desktop, editor and tests). Every callback arrives on the main thread.
##
## Full-screen order from the SDK: showed -> (earned, rewarded only) ->
## dismissed, or show_failed instead of showed. `earned` may also come just
## after `dismissed`; the Ads service waits a moment for it.

signal loaded(format: String)
signal load_failed(format: String, error: String)
signal showed(format: String)
signal show_failed(format: String, error: String)
signal earned(format: String)
signal dismissed(format: String)
signal banner_loaded
signal banner_failed(error: String)


## Ad unit ids per format for this platform (data/rules/ads.json "units").
func setup(_units: Dictionary) -> void:
	pass


func load_ad(_format: String) -> void:
	pass


func show_ad(_format: String) -> void:
	pass


## Creates and loads the bottom banner (hidden until banner_show()).
func banner_load() -> void:
	pass


func banner_show() -> void:
	pass


func banner_hide() -> void:
	pass


func banner_destroy() -> void:
	pass


## Banner height in screen (window) pixels, 0 if none is loaded.
func banner_height_px() -> int:
	return 0

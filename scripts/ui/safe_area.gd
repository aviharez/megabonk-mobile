class_name SafeArea
extends RefCounted
## The phone's safe area (camera cutout, rounded corners, gesture bar) in UI
## pixels. The Android export runs in immersive mode, so the game draws under
## the cutout: anything that must stay readable or tappable keeps `top()` px
## clear at the top and `bottom()` px clear at the bottom. Backgrounds still
## fill the whole screen.

## Fake insets in UI pixels for desktop checks (tools/shoot_screens.gd --notch).
static var debug_top := 0
static var debug_bottom := 0


## Pixels hidden at the top of `vp` (0 on desktop).
static func top(vp: Viewport) -> int:
	return maxi(debug_top, _insets(vp).x)


## Pixels hidden at the bottom of `vp` (gesture bar).
static func bottom(vp: Viewport) -> int:
	return maxi(debug_bottom, _insets(vp).y)


## Top and bottom insets in UI pixels, rounded up so nothing peeks under.
static func _insets(vp: Viewport) -> Vector2i:
	if vp == null or OS.get_name() not in ["Android", "iOS"]:
		return Vector2i.ZERO
	var safe := DisplayServer.get_display_safe_area()
	var win_pos := DisplayServer.window_get_position()
	var win_size := DisplayServer.window_get_size()
	if safe.size.x <= 0 or safe.size.y <= 0 or win_size.y <= 0:
		return Vector2i.ZERO
	var xf := vp.get_final_transform()
	var scale := xf.get_scale().y
	if scale <= 0.0:
		return Vector2i.ZERO
	# Black bars from integer scaling already sit outside the view.
	var bar := xf.origin.y
	var top_px := float(safe.position.y - win_pos.y) - bar
	var bottom_px := float(win_pos.y + win_size.y - safe.end.y) - bar
	return Vector2i(maxi(0, ceili(top_px / scale)), maxi(0, ceili(bottom_px / scale)))

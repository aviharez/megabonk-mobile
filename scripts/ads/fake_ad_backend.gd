class_name FakeAdBackend
extends AdBackend
## Stand-in for the ad SDK on desktop, in the editor and in tests.
##
## Scripted (tests): `outcome` decides what a shown ad does:
##   "complete"    showed -> earned -> dismissed
##   "close_early" showed -> dismissed (no reward)
##   "fail_show"   show_failed
##   "silent"      nothing at all (the Ads watchdog must recover)
##   "late_reward" showed -> dismissed -> earned (SDK order quirk)
## `fill` false makes every load fail. `step_sec` 0 = each callback one
## deferred call later (no real time needed).
##
## Visual (desktop runs): a pixel "TEST AD" screen on top of everything with
## SKIP (closes early) and, after a short countdown, GET REWARD, plus a fake
## bottom banner, so pausing and the banner inset can be checked by eye.

var fill := true
var outcome := "complete"
var step_sec := 0.0
var visual := false
var watch_sec := 3.0
var banner_dp := 50

## For tests: every call, in order ("load:rewarded", "show:interstitial", ...).
var calls: Array[String] = []
var banner_visible := false
var banner_ready := false

var _layer: CanvasLayer
var _banner: ColorRect


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func load_ad(format: String) -> void:
	calls.append("load:" + format)
	if fill:
		_after(step_sec, func() -> void: loaded.emit(format))
	else:
		_after(step_sec, func() -> void: load_failed.emit(format, "no fill (fake)"))


func show_ad(format: String) -> void:
	calls.append("show:" + format)
	if visual:
		_show_visual(format)
		return
	match outcome:
		"complete":
			_after(step_sec, func() -> void:
				showed.emit(format)
				_after(step_sec, func() -> void:
					if format == "rewarded":
						earned.emit(format)
					dismissed.emit(format)))
		"close_early":
			_after(step_sec, func() -> void:
				showed.emit(format)
				_after(step_sec, func() -> void: dismissed.emit(format)))
		"fail_show":
			_after(step_sec, func() -> void: show_failed.emit(format, "failed to show (fake)"))
		"late_reward":
			_after(step_sec, func() -> void:
				showed.emit(format)
				_after(step_sec, func() -> void:
					dismissed.emit(format)
					_after(step_sec, func() -> void: earned.emit(format))))
		"silent":
			pass


func banner_load() -> void:
	calls.append("banner_load")
	_after(step_sec, func() -> void:
		if fill:
			banner_ready = true
			banner_loaded.emit()
		else:
			banner_failed.emit("no fill (fake)"))


func banner_show() -> void:
	calls.append("banner_show")
	banner_visible = true
	if visual:
		_banner_node().show()


func banner_hide() -> void:
	calls.append("banner_hide")
	banner_visible = false
	if _banner != null:
		_banner.hide()


func banner_destroy() -> void:
	calls.append("banner_destroy")
	banner_visible = false
	banner_ready = false
	if _banner != null:
		_banner.queue_free()
		_banner = null


func banner_height_px() -> int:
	if not banner_ready:
		return 0
	return int(round(banner_dp * DisplayServer.screen_get_scale()))


func _after(sec: float, fn: Callable) -> void:
	if sec <= 0.0:
		fn.call_deferred()
	else:
		get_tree().create_timer(sec, true).timeout.connect(fn)


# --- Visual mode -------------------------------------------------------------

func _canvas() -> CanvasLayer:
	if _layer == null:
		_layer = CanvasLayer.new()
		_layer.layer = 100
		add_child(_layer)
	return _layer


func _banner_node() -> ColorRect:
	if _banner == null:
		_banner = ColorRect.new()
		_banner.color = Palette.color(Palette.PAPER)
		_banner.anchor_left = 0.0
		_banner.anchor_right = 1.0
		_banner.anchor_top = 1.0
		_banner.anchor_bottom = 1.0
		_banner.mouse_filter = Control.MOUSE_FILTER_STOP
		var l := Label.new()
		l.text = "TEST BANNER"
		l.add_theme_color_override("font_color", Palette.color(Palette.INK))
		l.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_banner.add_child(l)
		_canvas().add_child(_banner)
	# Same height in game pixels the Ads service reserves for it.
	var view := get_tree().root.get_visible_rect().size
	var scale := maxf(1.0, floorf(DisplayServer.window_get_size().y / maxf(1.0, view.y)))
	_banner.offset_top = -ceilf(banner_height_px() / scale)
	_banner.offset_bottom = 0
	return _banner


func _show_visual(format: String) -> void:
	var screen := ColorRect.new()
	screen.color = Palette.color(Palette.INK)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas().add_child(screen)
	var title := Label.new()
	title.text = "TEST AD\n" + format.to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Palette.color(Palette.BUTTER))
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	title.position.y -= 40
	screen.add_child(title)
	var timer_label := Label.new()
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_color_override("font_color", Palette.color(Palette.MIST))
	timer_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	screen.add_child(timer_label)
	var skip := PixelButton.new()
	skip.label = "SKIP"
	skip.face = Palette.MIST
	skip.name = "Skip"
	skip.custom_minimum_size = Vector2(72, 18)
	skip.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	skip.position += Vector2(-76, 30)
	screen.add_child(skip)
	var done := PixelButton.new()
	done.label = "GET REWARD" if format == "rewarded" else "CLOSE"
	done.face = Palette.LIME
	done.custom_minimum_size = Vector2(72, 18)
	done.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	done.position += Vector2(4, 30)
	done.disabled = true
	screen.add_child(done)
	showed.emit.call_deferred(format)
	var left := [watch_sec]
	var tick := Timer.new()
	tick.wait_time = 0.25
	tick.autostart = true
	tick.process_mode = Node.PROCESS_MODE_ALWAYS
	tick.timeout.connect(func() -> void:
		left[0] = maxf(0.0, left[0] - tick.wait_time)
		timer_label.text = "%d" % ceili(left[0]) if left[0] > 0.0 else ""
		done.disabled = left[0] > 0.0)
	screen.add_child(tick)
	timer_label.text = "%d" % ceili(watch_sec)
	skip.pressed.connect(func() -> void:
		screen.queue_free()
		dismissed.emit(format))
	done.pressed.connect(func() -> void:
		screen.queue_free()
		if format == "rewarded":
			earned.emit(format)
		dismissed.emit(format))

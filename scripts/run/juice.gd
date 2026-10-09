class_name Juice
extends Node
## Run-wide feedback that isn't tied to one effect: sound cues, screen shake,
## hit-stop, the low-HP vignette, the Final Swarm palette shift and the
## level-up light burst. Numbers come from data/rules/fx.json.
##
## Settings: "screen_shake" off = no shake; "reduce_effects" on = no hit-stop
## (the level-up burst, vignette and tint stay: they carry information).
## Sounds go through the Audio autoload (none in some tests); `cues` counts
## every cue by id either way, so tests can check an event made its sound.

const VIGNETTE := preload("res://assets/shaders/vignette.gdshader")
const PALETTE_SHIFT := preload("res://assets/shaders/palette_shift.gdshader")

var rules: Dictionary
var audio: Node
var shake_on := true
var reduced := false
## Sound cues asked for, by id (tests).
var cues := {}
## Camera offset in whole world pixels (Run applies it).
var offset := Vector2.ZERO
var hitstop_left := 0.0
## 0..1: how far the Final Swarm palette shift has come in.
var tint := 0.0
var vignette_strength := 0.0

var _trauma := 0.0
var _boss_stop_at := -INF
var _tint_on := false
var _beat_t := 0.0
var _clock := 0.0
var _layer: CanvasLayer
var _tint_rect: ColorRect
var _vignette: ColorRect
var _burst: LevelBurst


func setup(fx_rules: Dictionary, audio_node: Node, shake: bool, reduce: bool) -> void:
	rules = fx_rules
	audio = audio_node
	shake_on = shake
	reduced = reduce


## Overlays drawn over the world view (inside its viewport, so their pixels
## are world pixels): the palette shift, then the vignette on top.
func build_overlays(world: SubViewport) -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 1
	world.add_child(_layer)
	_tint_rect = ColorRect.new()
	_tint_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tm := ShaderMaterial.new()
	tm.shader = PALETTE_SHIFT
	tm.set_shader_parameter("palette", Palette.texture())
	tm.set_shader_parameter("lut", _tint_lut())
	tm.set_shader_parameter("colors", Palette.colors().size())
	_tint_rect.material = tm
	_tint_rect.visible = false
	_layer.add_child(_tint_rect)
	_vignette = ColorRect.new()
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vm := ShaderMaterial.new()
	vm.shader = VIGNETTE
	vm.set_shader_parameter("inner", Palette.color(Palette.RED))
	vm.set_shader_parameter("outer", Palette.color(Palette.BLOOD))
	vm.set_shader_parameter("band", float(rules.get("low_hp", {}).get("band", 16.0)))
	_vignette.material = vm
	_vignette.visible = false
	_layer.add_child(_vignette)
	resize(Vector2(world.size))


func resize(size: Vector2) -> void:
	if _layer == null:
		return
	_tint_rect.size = size
	_vignette.size = size
	_vignette.material.set_shader_parameter("size", size)


## The level-up burst lives in the UI layer and keeps playing while the run
## is paused for the cards.
func build_burst(ui: CanvasLayer) -> void:
	_burst = LevelBurst.new()
	ui.add_child(_burst)


## 32x1 texture: palette entry i -> its Final Swarm color.
func _tint_lut() -> ImageTexture:
	var cols := Palette.colors()
	var img := Image.create_empty(cols.size(), 1, false, Image.FORMAT_RGBA8)
	for i in cols.size():
		img.set_pixel(i, 0, cols[i])
	var m: Dictionary = rules.get("final_tint", {}).get("map", {})
	for from: String in m:
		var a := Palette.index_of(from)
		var b := Palette.index_of(m[from])
		if a >= 0 and b >= 0:
			img.set_pixel(a, 0, cols[b])
	return ImageTexture.create_from_image(img)


## Plays sound `id` (if there is an Audio node) and counts the cue.
func sfx(id: String) -> void:
	if id == "":
		return
	cues[id] = int(cues.get(id, 0)) + 1
	if audio != null:
		audio.play(id)


## Adds screen shake by a named amount from rules "shake" (or a number).
func shake(kind: Variant) -> void:
	var s: Dictionary = rules.get("shake", {})
	var amount: float = float(s.get(kind, 0.0)) if kind is String else float(kind)
	if not shake_on or amount <= 0.0:
		return
	_trauma = minf(float(s.get("max", 5.0)), _trauma + amount)


## Freezes the game for `sec` seconds (only the picture keeps drawing).
func hitstop(sec: float) -> void:
	if reduced or sec <= 0.0:
		return
	hitstop_left = minf(float(rules.get("hitstop", {}).get("max", 0.12)), maxf(hitstop_left, sec))


## A crit: hit-stop if it was a big one (rules hitstop "big_crit_frac" of the
## enemy's max HP, or any crit on an elite).
func crit(amount: float, max_hp: float, elite: bool) -> void:
	var h: Dictionary = rules.get("hitstop", {})
	if elite or amount >= max_hp * float(h.get("big_crit_frac", 0.5)):
		hitstop(float(h.get("big_crit", 0.05)))


## A hit on the boss: a short stop, at most every "boss_gap" seconds.
func boss_hit(now: float) -> void:
	var h: Dictionary = rules.get("hitstop", {})
	if now - _boss_stop_at >= float(h.get("boss_gap", 0.35)):
		_boss_stop_at = now
		hitstop(float(h.get("boss_hit", 0.03)))


## Real-time step of the hit-stop. True while the game should stay frozen.
func hold(delta: float) -> bool:
	if hitstop_left <= 0.0:
		return false
	hitstop_left -= delta
	return true


## Per frame (game time): shake decay, vignette, heartbeat, tint fade.
func update(delta: float, hp_frac: float) -> void:
	_clock += delta
	var s: Dictionary = rules.get("shake", {})
	_trauma = maxf(0.0, _trauma - float(s.get("decay", 9.0)) * delta)
	if _trauma > 0.0:
		var k := int(_clock * 60.0)
		var r := ceilf(_trauma)
		offset = Vector2(float(((k * 7) % 3) - 1), float(((k * 5 + 1) % 3) - 1)) * r
	else:
		offset = Vector2.ZERO
	var lh: Dictionary = rules.get("low_hp", {})
	var below := float(lh.get("below", 0.3))
	if hp_frac < below and hp_frac > 0.0:
		var beat := float(lh.get("beat_sec", 0.85))
		_beat_t -= delta
		if _beat_t <= 0.0:
			_beat_t = beat
			sfx("heartbeat")
		# Deeper the lower the HP, and a thump on every beat.
		var base := 0.45 + 0.55 * (1.0 - hp_frac / below)
		var thump := 0.25 if _beat_t > beat - 0.15 else 0.0
		vignette_strength = minf(1.0, base + thump)
	else:
		vignette_strength = 0.0
		_beat_t = 0.0
	if _vignette != null:
		_vignette.visible = vignette_strength > 0.0
		if _vignette.visible:
			_vignette.material.set_shader_parameter("strength", vignette_strength)
	if _tint_on and tint < 1.0:
		tint = minf(1.0, tint + delta / maxf(0.01, float(rules.get("final_tint", {}).get("fade_sec", 1.2))))
	if _tint_rect != null:
		_tint_rect.visible = tint > 0.0
		if _tint_rect.visible:
			_tint_rect.material.set_shader_parameter("amount", tint)


## The Final Swarm started: shift the world's palette.
func start_final_tint() -> void:
	_tint_on = true


## The light burst at `screen_pos` (UI pixels); `done` runs when it ends.
func level_burst(screen_pos: Vector2, done: Callable) -> void:
	if _burst == null:
		done.call()
		return
	_burst.play(screen_pos, float(rules.get("level_up_burst", 0.4)), done)


func burst_playing() -> bool:
	return _burst != null and _burst.playing()

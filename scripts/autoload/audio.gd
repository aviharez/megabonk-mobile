extends Node
## Audio manager (autoload "Audio"). Every sound and track is listed in
## data/rules/audio.json; nothing else loads audio. Swapping a sound means
## overwriting its file with the same name.
##
## SFX: a fixed pool of `voices` players on the "SFX" bus. Each play gets a
## small random pitch change ("pitch"), and a sound is skipped when it played
## less than "gap" seconds ago or already has "max" voices going. When every
## voice is busy, the new sound takes over the oldest voice whose priority is
## not higher than its own; otherwise it is dropped. So a horde of hits can
## never drown out the level-up or a boss roar. A voice counts as busy until
## its sound's length (at its pitch) has passed, so the cap works the same
## with any audio driver.
##
## Music: two players on the "Music" bus that crossfade ("music_fade" s).
## OGG tracks loop. Music and SFX each follow their setting (Save "music",
## "sfx"); the Ads autoload mutes the master bus while an ad plays.
##
## Headless (tests, sims): all the bookkeeping runs, but nothing is sent to
## the dummy driver, which never mixes and so never lets go of a playback.
##
## Keeps playing while the tree is paused (menus, level-up cards).

const RULES := "audio"

var rules: Dictionary = {}
## Plays per sound id since start (tests and the event coverage check).
var played := {}
## Plays skipped by gap / max / a full pool (tests, stress report).
var dropped := 0
var music_id := ""
## Send nothing to the audio driver (headless).
var silent := false

var _streams := {}
var _voices: Array[AudioStreamPlayer] = []
var _voice_id := PackedStringArray()
var _voice_pri := PackedInt32Array()
var _voice_start := PackedInt64Array()
var _voice_end := PackedInt64Array()
var _last := {}  # id -> ticks msec of the last play
var _music: Array[AudioStreamPlayer] = []
var _music_on := 0
var _tween: Tween
var _sfx_bus := 0
var _music_bus := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	silent = DisplayServer.get_name() == "headless"
	rules = GameData.shared().get_entry("rules", RULES)
	_sfx_bus = _bus("SFX")
	_music_bus = _bus("Music")
	for i in int(rules.get("voices", 12)):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_voices.append(p)
	_voice_id.resize(_voices.size())
	_voice_pri.resize(_voices.size())
	_voice_start.resize(_voices.size())
	_voice_end.resize(_voices.size())
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = "Music"
		m.volume_db = -80.0
		add_child(m)
		_music.append(m)
	apply_settings()
	var save := get_node_or_null("/root/Save")
	if save != null:
		save.saved.connect(apply_settings)


## Let go of every stream on the way out.
func _exit_tree() -> void:
	if _tween != null:
		_tween.kill()
	for p: AudioStreamPlayer in _voices + _music:
		p.stop()
		p.stream = null
	_streams.clear()


func _bus(bus_name: String) -> int:
	var i := AudioServer.get_bus_index(bus_name)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bus_name)
		AudioServer.set_bus_send(i, "Master")
	return i


## Mutes the buses whose setting is off.
func apply_settings() -> void:
	var save := get_node_or_null("/root/Save")
	var sfx_on: bool = save.get_setting("sfx") if save != null else true
	var music_on: bool = save.get_setting("music") if save != null else true
	AudioServer.set_bus_mute(_sfx_bus, not sfx_on)
	AudioServer.set_bus_mute(_music_bus, not music_on)


func sfx_enabled() -> bool:
	return not AudioServer.is_bus_mute(_sfx_bus)


func music_enabled() -> bool:
	return not AudioServer.is_bus_mute(_music_bus)


func has_sound(id: String) -> bool:
	return rules.get("sfx", {}).has(id)


## Plays sound `id`. Returns true if a voice took it.
func play(id: String) -> bool:
	var def: Dictionary = rules.get("sfx", {}).get(id, {})
	if def.is_empty():
		push_warning("Audio: no sound \"%s\" in data/rules/audio.json" % id)
		return false
	var now := Time.get_ticks_msec()
	if now - int(_last.get(id, -100000)) < int(float(def.get("gap", 0.0)) * 1000.0):
		dropped += 1
		return false
	var same := 0
	var free := -1
	var oldest := -1
	var pri := int(def.get("priority", 0))
	for i in _voices.size():
		if now >= _voice_end[i]:
			if free < 0:
				free = i
			continue
		if _voice_id[i] == id:
			same += 1
		if _voice_pri[i] <= pri and (oldest < 0 or _voice_start[i] < _voice_start[oldest]):
			oldest = i
	if same >= int(def.get("max", 2)):
		dropped += 1
		return false
	var v := free if free >= 0 else oldest
	if v < 0:
		dropped += 1
		return false
	var stream := _stream(def.file)
	if stream == null:
		return false
	var p := _voices[v]
	var j := float(def.get("pitch", 0.0))
	var pitch := 1.0 + randf_range(-j, j)
	if not silent:
		p.stream = stream
		p.volume_db = float(def.get("db", 0.0))
		p.pitch_scale = pitch
		p.play()
	_voice_id[v] = id
	_voice_pri[v] = pri
	_voice_start[v] = now
	_voice_end[v] = now + maxi(1, int(stream.get_length() / pitch * 1000.0))
	_last[id] = now
	played[id] = int(played.get(id, 0)) + 1
	return true


## Voices sounding right now (never more than voice_cap()).
func voices_busy() -> int:
	var now := Time.get_ticks_msec()
	var n := 0
	for e in _voice_end:
		if now < e:
			n += 1
	return n


func voice_cap() -> int:
	return _voices.size()


## Crossfades to track `id` ("" = fade out). Same track again: nothing.
func play_music(id: String) -> void:
	if id == music_id:
		return
	music_id = id
	if silent:
		return
	var fade := float(rules.get("music_fade", 0.5))
	var old := _music[_music_on]
	_music_on = 1 - _music_on
	var new := _music[_music_on]
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(old, "volume_db", -80.0, fade)
	var path: String = rules.get("music", {}).get(id, "")
	var stream := _stream(path) if id != "" else null
	if stream != null:
		if stream is AudioStreamOggVorbis:
			stream.loop = true
		new.stream = stream
		new.volume_db = -40.0
		new.play()
		_tween.tween_property(new, "volume_db", float(rules.get("music_db", -8.0)), fade)
	_tween.chain().tween_callback(old.stop)


func _stream(path: String) -> AudioStream:
	if not _streams.has(path):
		var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
		if s == null:
			push_warning("Audio: can't load %s" % path)
		_streams[path] = s
	return _streams[path]

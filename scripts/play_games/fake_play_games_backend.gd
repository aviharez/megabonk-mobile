class_name FakePlayGamesBackend
extends PlayGamesBackend
## Stand-in Play Games in debug builds without the plugin (desktop, editor,
## tests). One pretend player and a pretend cloud: saved games, unlocked
## achievements and best scores, kept in memory, and in `path` too when it is
## set (the autoload uses user://fake_cloud.json, so a cloud round trip can be
## tried on desktop: sign in, play, reset the save, launch again).
##
## The silent check at start signs in only after an interactive sign-in once
## (as on a phone). Tests steer it: `sign_in_ok`, `load_ok`, `save_ok`, and
## `respond` false never answers (the service's timeouts take over).

var sign_in_ok := true
var load_ok := true
var save_ok := true
var respond := true
var step_sec := 0.0
var path := ""
## Every call, in order ("sign_in", "save:<name>", "unlock:<id>",
## "score:<id>=<n>", "show_achievements", ...).
var calls: Array[String] = []
## The pretend account: {"signed_in": bool, "saves": {name: {"content": base64,
## "progress": int}}, "achievements": [id], "scores": {id: [n]}}.
var cloud := {"signed_in": false, "saves": {}, "achievements": [], "scores": {}}


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	available = true


func setup() -> void:
	_read()
	calls.append("setup")
	_after(func() -> void: signed_in_changed.emit(bool(cloud.signed_in)))


func sign_in() -> void:
	calls.append("sign_in")
	_after(func() -> void:
		if sign_in_ok:
			cloud.signed_in = true
			_write()
		signed_in_changed.emit(sign_in_ok))


func load_cloud(save_name: String) -> void:
	calls.append("load:" + save_name)
	_after(func() -> void:
		if not load_ok:
			cloud_loaded.emit(false, false, PackedByteArray())
			return
		var s: Dictionary = cloud.saves.get(save_name, {})
		if s.is_empty():
			cloud_loaded.emit(true, false, PackedByteArray())
		else:
			cloud_loaded.emit(true, true, Marshalls.base64_to_raw(s.content)))


func save_cloud(save_name: String, _description: String, content: PackedByteArray, _played_ms: int, progress: int) -> void:
	calls.append("save:" + save_name)
	_after(func() -> void:
		if save_ok:
			cloud.saves[save_name] = {"content": Marshalls.raw_to_base64(content), "progress": progress}
			_write()
		cloud_saved.emit(save_ok))


func unlock(id: String) -> void:
	calls.append("unlock:" + id)
	_after(func() -> void:
		if not id in cloud.achievements:
			cloud.achievements.append(id)
			_write()
		achievement_done.emit(id, true))


func submit_score(id: String, score: int) -> void:
	calls.append("score:%s=%d" % [id, score])
	var list: Array = cloud.scores.get(id, [])
	list.append(score)
	cloud.scores[id] = list
	_write()


func show_achievements() -> void:
	calls.append("show_achievements")
	print("FakePlayGames: achievements screen (unlocked: %s)" % [cloud.achievements])


func show_leaderboards() -> void:
	calls.append("show_leaderboards")
	print("FakePlayGames: leaderboards screen (scores: %s)" % [cloud.scores])


## The cloud save's content as JSON text ("" when there is none).
func cloud_text(save_name: String) -> String:
	var s: Dictionary = cloud.saves.get(save_name, {})
	return Marshalls.base64_to_raw(s.content).get_string_from_utf8() if not s.is_empty() else ""


func _after(fn: Callable) -> void:
	if not respond:
		return
	if step_sec <= 0.0:
		fn.call_deferred()
	else:
		get_tree().create_timer(step_sec, true).timeout.connect(fn)


func _read() -> void:
	if path == "" or not FileAccess.file_exists(path):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if d is Dictionary:
		cloud.merge(d, true)


func _write() -> void:
	if path == "":
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(cloud, "\t"))

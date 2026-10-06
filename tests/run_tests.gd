extends SceneTree
## Minimal headless test runner. Runs every tests/test_*.gd; each test is a
## method named test_* that returns nothing and calls check() via `t`.
## A test may `await t.process_frame` (e.g. after adding a scene to t.root).
##   godot --headless --path . -s res://tests/run_tests.gd

var _failures := 0
var _checks := 0
var _current := ""


func _initialize() -> void:
	# Let the root finish setting up so tests can add scenes (their _ready runs).
	await process_frame
	var files := DirAccess.get_files_at("res://tests")
	files.sort()
	# Optional filter: -- --only=test_map_flow (file name prefix).
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.trim_prefix("--only=")
	for f in files:
		if f.begins_with("test_") and f.ends_with(".gd") and f.begins_with(only):
			var script: GDScript = load("res://tests/" + f)
			if script == null or not script.can_instantiate():
				_checks += 1
				_failures += 1
				printerr("FAIL %s: script does not compile" % f)
				continue
			var suite: Object = script.new()
			for m in suite.get_method_list():
				if String(m.name).begins_with("test_"):
					_current = "%s::%s" % [f, m.name]
					if only != "":
						print("  running " + _current)
					await suite.call(m.name, self)
			if suite.has_method("cleanup"):
				suite.cleanup()
	if _checks == 0:
		# A filter that matches nothing must not look like a pass.
		_checks += 1
		_failures += 1
		printerr("FAIL: no checks ran (--only=%s matched no test file?)" % only)
	print("\n%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL %s: %s" % [_current, msg])

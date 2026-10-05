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
	for f in files:
		if f.begins_with("test_") and f.ends_with(".gd"):
			var suite: Object = load("res://tests/" + f).new()
			for m in suite.get_method_list():
				if String(m.name).begins_with("test_"):
					_current = "%s::%s" % [f, m.name]
					await suite.call(m.name, self)
			if suite.has_method("cleanup"):
				suite.cleanup()
	print("\n%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL %s: %s" % [_current, msg])

extends RefCounted
## Stat = (base + flat) * (1 + pct), modifiers keyed by source.


func test_base_flat_pct(t) -> void:
	var s := Stat.new(100.0)
	t.check(s.value() == 100.0, "base")
	s.set_modifier("tome:a", 20.0)
	s.set_modifier("item:b", 0.0, 0.5)
	t.check(is_equal_approx(s.value(), 180.0), "(100+20)*1.5 = 180, got %s" % s.value())


func test_same_source_replaces(t) -> void:
	var s := Stat.new(10.0)
	s.set_modifier("tome:a", 0.0, 0.1)
	s.set_modifier("tome:a", 0.0, 0.3)
	t.check(is_equal_approx(s.value(), 13.0), "level-up replaces, got %s" % s.value())
	s.remove_modifier("tome:a")
	t.check(s.value() == 10.0, "removed")


func test_clamped(t) -> void:
	var s := Stat.new(1.0, 0.2)
	s.set_modifier("x", 0.0, -0.95)
	t.check(is_equal_approx(s.value(), 0.2), "floor holds, got %s" % s.value())


func test_stat_block(t) -> void:
	var b := StatBlock.new({"damage": 1.0, "area": 1.0})
	t.check(b.set_modifier("damage", "tome:m", 0.0, 0.2), "known stat")
	t.check(is_equal_approx(b.get_value("damage"), 1.2), "damage 1.2")
	b.remove_source("tome:m")
	t.check(b.get_value("damage") == 1.0, "source removed")
	t.check(not b.has("dmg"), "unknown stat not present")

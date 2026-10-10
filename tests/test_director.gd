extends RefCounted
## The spawn director against the real Suburbia data: the run timeline from
## the brief (minute 0-2 Blobs and Skitters, 2-4 Spitters and Bloaters, first
## SWARM INCOMING around 3, 4-6 Chompers, second swarm around 5, Final Swarm
## at 8, then Overdue Bills), elites every 60-90 s, escalation that never
## stops in the Final Swarm.

const DT := 0.1


## Steps a director over `minutes` with nothing alive (every spawn allowed)
## and returns {first: {enemy: first second}, events: [[event, second]],
## gnat_times: [seconds], elites: [[second, enemy, trait]]}.
func _timeline(minutes: float, seed := 1) -> Dictionary:
	var db := GameData.shared()
	var map := db.get_entry("maps", "suburbia")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var d := Director.new(map, 300, 480.0, rng, db.get_entry("rules", "bills"))
	var packs := {}
	for e: Dictionary in db.all("enemies"):
		if e.has("pack_size"):
			packs[e.id] = e.pack_size
	var out := {"first": {}, "events": [], "gnat_times": [], "elites": [], "director": d, "bills": 0}
	var t := 0.0
	while t < minutes * 60.0:
		t += DT
		for r: Dictionary in d.tick(DT, t, 0, packs, rng):
			if not out.first.has(r.enemy):
				out.first[r.enemy] = t
			if r.enemy == "gnat":
				out.gnat_times.append(t)
			if r.elite != "":
				out.elites.append([t, r.enemy, r.elite])
			if r.enemy == "overdue_bill":
				out.bills += 1
		for ev in d.events:
			out.events.append([ev, t])
	return out


func _event_times(tl: Dictionary, name: String) -> Array:
	return tl.events.filter(func(e: Array) -> bool: return e[0] == name).map(func(e: Array) -> float: return e[1])


func test_timeline_follows_the_brief(t) -> void:
	var tl := _timeline(13.0)
	var f: Dictionary = tl.first
	t.check(f.get("blob", 99.0) < 2.0, "Blobs from minute 0 (%s s)" % f.get("blob"))
	t.check(f.get("skitter", 999.0) < 60.0, "Skitters in minute 0-2 (%s s)" % f.get("skitter"))
	for id in ["spitter", "bloater"]:
		t.check(f.get(id, 0.0) >= 120.0 and f.get(id, 999.0) < 150.0, "%s joins at minute 2 (%s s)" % [id, f.get(id)])
	t.check(f.get("chomper", 0.0) >= 240.0 and f.get("chomper", 999.0) < 270.0, "Chompers join at minute 4 (%s s)" % f.get("chomper"))

	var starts := _event_times(tl, "swarm_start")
	var warns := _event_times(tl, "swarm_warning")
	var ends := _event_times(tl, "swarm_end")
	t.check(starts.size() == 2, "two SWARM INCOMING waves before the Final Swarm (%s)" % [starts])
	if starts.size() == 2:
		t.check(absf(starts[0] - 180.0) < 1.0 and absf(starts[1] - 300.0) < 1.0, "waves at minute 3 and 5: %s" % [starts])
		t.check(warns.size() == 2 and warns[0] < starts[0] and warns[1] < starts[1], "a warning comes before each wave")
		for i in 2:
			var len: float = ends[i] - starts[i]
			t.check(len >= 20.0 - DT and len <= 30.0 + DT, "wave %d lasts 20-30 s (%s)" % [i + 1, len])
	# Gnats only during the waves.
	var outside := 0
	for g: float in tl.gnat_times:
		var inside := false
		for i in mini(starts.size(), ends.size()):
			inside = inside or (g >= starts[i] - DT and g <= ends[i] + DT)
		if not inside:
			outside += 1
	t.check(not tl.gnat_times.is_empty() and outside == 0, "Gnats only in SWARM INCOMING (%d of %d outside)" % [outside, tl.gnat_times.size()])
	t.check(tl.gnat_times.size() > 400, "huge numbers of Gnats (%d)" % tl.gnat_times.size())

	var final := _event_times(tl, "final_start")
	t.check(final.size() == 1 and absf(final[0] - 480.0) < 1.0, "Final Swarm at 8:00 (%s)" % [final])
	var bills := _event_times(tl, "bills_start")
	t.check(bills.size() == 1 and bills[0] > final[0], "Overdue Bills come after the Final Swarm starts (%s)" % [bills])
	t.check(tl.bills > 0, "bills spawn (%d)" % tl.bills)
	t.check(_event_times(tl, "bills_faster").size() >= 2, "bills speed up every minute")


func test_elites_every_60_to_90_seconds(t) -> void:
	var tl := _timeline(8.0, 3)
	var times: Array = tl.elites.map(func(e: Array) -> float: return e[0])
	t.check(times.size() >= 5, "5+ elites in 8 minutes (%d)" % times.size())
	var ok := not times.is_empty() and absf(times[0] - 60.0) < 1.0
	for i in range(1, times.size()):
		var gap: float = times[i] - times[i - 1]
		ok = ok and gap >= 60.0 - DT and gap <= 90.0 + DT
	t.check(ok, "first at 1:00, then every 60-90 s: %s" % [times])
	var traits := {}
	for e: Array in tl.elites:
		traits[e[2]] = true
	var early_chomper: bool = tl.elites.any(func(e: Array) -> bool: return e[1] == "chomper" and e[0] < 240.0)
	t.check(not early_chomper, "no elite Chomper before Chompers join")
	var many := _timeline(40.0, 4)
	var all_traits := {}
	for e: Array in many.elites:
		all_traits[e[2]] = true
	t.check(all_traits.size() == 4, "all 4 traits show up: %s" % [all_traits.keys()])


func test_final_swarm_escalation_never_stops(t) -> void:
	var tl := _timeline(12.0)
	var d: Director = tl.director
	t.check(d.final_started and d.escalation() > 1.0, "escalation keeps rising in the Final Swarm (%s)" % d.escalation())
	var rate: float = d.final_cfg.coin_mult_per_min
	t.check(rate > 0.0 and is_equal_approx(d.coin_mult(), 1.0 + rate * d.final_time / 60.0) and d.coin_mult() > 1.5,
		"coin multiplier rises with Final Swarm minutes (%s)" % d.coin_mult())
	t.check(d.bill_speed_mult() > 1.5 and d.bill_damage_mult() > 2.0, "bills get faster and hit harder")


func test_swarm_respects_the_cap(t) -> void:
	var db := GameData.shared()
	var rng := RandomNumberGenerator.new()
	var d := Director.new(db.get_entry("maps", "suburbia"), 300, 480.0, rng, db.get_entry("rules", "bills"))
	var alive := 0
	var reserve := 0
	var peak := 0
	var tt := 170.0
	while tt < 215.0:
		tt += DT
		for r: Dictionary in d.tick(DT, tt, alive, {}, rng):
			if r.reserve:
				reserve += r.count
			else:
				alive += r.count
		peak = maxi(peak, alive)
	t.check(peak <= 300, "never over the cap (peak %d)" % peak)
	t.check(alive == 300, "the swarm fills to the cap (%d)" % alive)
	t.check(d.escalation() > 0.0, "blocked swarm spawns escalate")

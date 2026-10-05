class_name ItemSystem
extends RefCounted
## Items held in a run and what they do. Everything an item does comes from
## its data file (data/items/), in three parts:
##
##   "modifiers":  [{"stat", "flat", "pct"}]  stat modifiers per stack.
##   "triggers":   [{"event", "chance", "effect", ...effect params}]
##                 When `event` happens, roll `chance` (default 1), then run
##                 `effect`. Event "every" fires each "interval" seconds.
##                 "elite_only": true limits on_kill to elite kills.
##   "conditions": [{"if", "value", "stat", "flat", "pct"}]
##                 A modifier that is on only while the condition holds.
##
## Stacking (Common to Epic): modifiers, effect amounts and condition
## modifiers scale linearly with stacks; chances stack with diminishing
## returns: 1 - (1 - chance)^stacks. Intervals don't change with stacks.
##
## EFFECTS lists each effect with its required params. Effect damage never
## crits and never fires on_hit again (no proc loops); its kills do count.

const EVENTS := ["on_hit", "on_kill", "on_damaged", "on_level_up", "on_chest_opened", "on_shrine_activated", "on_attack", "on_projectile", "every"]
const EFFECTS := {
	"burn": ["dps", "duration"],  # the hit enemy takes dps for duration seconds
	"blast": ["radius", "damage"],  # + "knockback", "at": "player" (default) or "target"
	"zap": ["damage", "jumps", "range"],  # lightning from the event position, chains
	"gold": ["amount"],  # in-run gold (gold_gain applies)
	"crit_next": ["count"],  # the next `count` hits are guaranteed crits
	"stat_boost": ["choices"],  # permanent for the run: one random {"stat","flat","pct"}
	"duplicate": [],  # copies the fired projectile; + "spread" (radians)
	"heal": ["amount"],
}
const CONDITIONS := ["hp_below"]  # value = fraction of max HP
## Nested events (an effect's kill firing on_kill...) stop at this depth.
const MAX_DEPTH := 3

var stacks := {}  # item id -> stacks held
## Guaranteed crits waiting to be used (Alarm Clock).
var crit_charges := 0
## Times each item's effects ran, for tests and the stat tracker.
var fired := {}

var _run: Node
var _db: GameData
var _by_event := {}  # event -> [[item id, trigger]]
var _timers := {}  # "id:index" -> seconds left
var _cond_on := {}  # "id:index" -> stacks the modifier was applied with
var _boosts := {}  # item id -> {stat: [flat, pct]}
var _depth := 0


func _init(run: Node, db: GameData) -> void:
	_run = run
	_db = db


func count(id: String) -> int:
	return stacks.get(id, 0)


## Adds one stack of an item and applies it.
func add(id: String) -> void:
	var def := _db.get_entry("items", id)
	if def.is_empty():
		push_error("ItemSystem: item '%s' not found" % id)
		return
	stacks[id] = count(id) + 1
	_run.stats.apply_modifiers("item:" + id, def.get("modifiers", []), stacks[id])
	_rebuild()
	# Conditions re-apply with the new stack count on the next update.
	for k: String in _cond_on.keys():
		if k.begins_with(id + ":"):
			_cond_on[k] = -1


## Chance after stacking, with diminishing returns.
static func stacked_chance(chance: float, n: int) -> float:
	return 1.0 - pow(1.0 - clampf(chance, 0.0, 1.0), n)


## Runs every trigger listening to `event`. `ctx` carries what happened:
## on_hit/on_kill: slot, pos, elite, source; on_damaged: amount;
## on_attack: weapon, pos; on_projectile: shot (fire params).
func emit(event: String, ctx: Dictionary) -> void:
	var list: Array = _by_event.get(event, [])
	if list.is_empty() or _depth >= MAX_DEPTH:
		return
	_depth += 1
	for pair: Array in list:
		var trig: Dictionary = pair[1]
		if trig.get("elite_only", false) and not ctx.get("elite", false):
			continue
		var n := count(pair[0])
		var chance: float = trig.get("chance", 1.0)
		if chance < 1.0 and _run.rng.randf() >= stacked_chance(chance, n):
			continue
		_do(pair[0], trig, n, ctx)
	_depth -= 1


## Timers ("every") and conditions. Called once per tick.
func update(delta: float) -> void:
	for pair: Array in _by_event.get("every", []):
		var key: String = "%s:%d" % [pair[0], pair[2]]
		var left: float = _timers.get(key, pair[1].interval) - delta
		if left <= 0.0:
			left += pair[1].interval
			_depth += 1
			_do(pair[0], pair[1], count(pair[0]), {"pos": _run.player_pos()})
			_depth -= 1
		_timers[key] = left
	for id: String in stacks:
		var conds: Array = _db.get_entry("items", id).get("conditions", [])
		for i in conds.size():
			var c: Dictionary = conds[i]
			var key := "%s:%d" % [id, i]
			var on := _holds(c)
			var want: int = stacks[id] if on else 0
			if _cond_on.get(key, 0) == want:
				continue
			_cond_on[key] = want
			var src := "cond:" + key
			if want > 0:
				_run.stats.set_modifier(c.stat, src, float(c.get("flat", 0.0)) * want, float(c.get("pct", 0.0)) * want)
			else:
				_run.stats.remove_modifier(c.stat, src)


func is_condition_on(id: String, index: int = 0) -> bool:
	return _cond_on.get("%s:%d" % [id, index], 0) > 0


## Uses one guaranteed crit if there is one.
func take_crit_charge() -> bool:
	if crit_charges > 0:
		crit_charges -= 1
		return true
	return false


func _holds(c: Dictionary) -> bool:
	match c.get("if", ""):
		"hp_below":
			return _run.hp < _run.stat("max_hp") * float(c.value)
	return false


func _rebuild() -> void:
	_by_event.clear()
	for id: String in stacks:
		var trigs: Array = _db.get_entry("items", id).get("triggers", [])
		for i in trigs.size():
			var t: Dictionary = trigs[i]
			if not _by_event.has(t.event):
				_by_event[t.event] = []
			_by_event[t.event].append([id, t, i])


func _do(id: String, t: Dictionary, n: int, ctx: Dictionary) -> void:
	fired[id] = fired.get(id, 0) + 1
	var src := "item:" + id
	match t.effect:
		"burn":
			if ctx.has("slot"):
				_run.burn_enemy(ctx.slot, float(t.dps) * n, float(t.duration))
		"blast":
			var at: Vector2 = ctx.get("pos", _run.player_pos()) if t.get("at", "player") == "target" else _run.player_pos()
			_run.blast(at, float(t.radius), float(t.damage) * n, float(t.get("knockback", 0.0)), src, t.get("color", "PAPER"))
		"zap":
			_run.chain_zap(ctx.get("pos", _run.player_pos()), float(t.damage) * n, int(t.jumps), float(t.range), src, ctx.get("slot", -1))
		"gold":
			_run.add_gold(float(t.amount) * n)
		"crit_next":
			# Refills, doesn't pile up: unused charges don't carry past the next trigger.
			crit_charges = maxi(crit_charges, int(t.count) * n)
		"stat_boost":
			var choices: Array = t.choices
			var c: Dictionary = choices[_run.rng.randi_range(0, choices.size() - 1)]
			var mine: Dictionary = _boosts.get(id, {})
			var cur: Array = mine.get(c.stat, [0.0, 0.0])
			cur = [cur[0] + float(c.get("flat", 0.0)) * n, cur[1] + float(c.get("pct", 0.0)) * n]
			mine[c.stat] = cur
			_boosts[id] = mine
			var before: float = _run.stat("max_hp")
			_run.stats.set_modifier(c.stat, "boost:" + id, cur[0], cur[1])
			_run.heal(maxf(0.0, _run.stat("max_hp") - before))
			_run.toast("%s UP!" % String(c.stat).replace("_", " ").to_upper(), "GOLD")
		"duplicate":
			if ctx.has("shot"):
				_run.duplicate_shot(ctx.shot, float(t.get("spread", 0.25)))
		"heal":
			_run.heal(float(t.amount) * n)

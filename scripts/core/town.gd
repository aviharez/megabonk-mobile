class_name Town
extends RefCounted
## The Town (docs/BRIEF.md "Update 1", Town) over the save's "town" block:
## buildings, their levels, Patrol coins and the Town level. Pure functions
## on a Dictionary, like Meta, so tests, the run and the Town tab share them.
##
## Buildings (data/buildings/): {"name" (pin), "title" (window), "order",
## "district", "sprite" (one picture; ruined = the same drawn darker with
## boards over it, ruin_image()), "interactable" (the in-run object on its
## lot), "effect_desc" (what that object does, "{heal}" / "{uses}" / "{pct}" /
## "{seconds}" filled from the level's effect), "levels": [{"price" (not on
## level 1 of a building with "unlocks": that's its challenge's price),
## "patrol" (coins per hour), "effect"}]} and one of:
## - "unlocks": [content ids]: the building wraps unlock content. The first
##   one decides: ruined while its challenge isn't done, buildable once it is
##   ("available"), built once it's owned. Rebuilding it is buying it (Meta.buy),
##   so the Collection's Buy and the Town's Rebuild are one action, and a save
##   that owns the content shows the building as built.
## - "shop": [shop "stat" entry ids]: the building's level is those
##   upgrades' level (they leave the Shop). Buildable from the start.
## Optional "icon" (Icons.ref) for the window's slot; else the first unlock's.
##
## An effect: "heal" (HP), "buff": {"seconds", "modifiers": [{"stat", "pct" /
## "flat"}]}, "pull_gems" (every XP gem on the map flies to the player),
## "uses" (per run, default 1) and "recharge_sec" (between uses).
##
## Map data: a prop {"kind": "building", "building": id} is where the building
## stands (solid, like a house); props and interactables with "requires": id
## are only there while that building is built (resolve_map()).
##
## Save block "town" (save_manager.gd default_data()):
## - "levels": building id -> level (a building with "unlocks" is level 1
##   while owned and not upgraded, so it needs no entry).
## - "patrol": {"since": unix time Patrol last settled (0 = not started),
##   "banked": coins earned before the last settle, not collected yet}.

## Unix time now (real seconds; Patrol counts real hours). Tests swap in a
## fake clock.
static var clock: Callable = system_clock


static func system_clock() -> int:
	return int(Time.get_unix_time_from_system())


static func now() -> int:
	return int(clock.call())


static func rules(db: GameData) -> Dictionary:
	return db.get_entry("rules", "town")


## Buildings in Town order ("order", then id).
static func buildings(db: GameData) -> Array:
	var list := db.all("buildings")
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var oa := float(a.get("order", 99))
		var ob := float(b.get("order", 99))
		return oa < ob or (oa == ob and a.id < b.id))
	return list


static func building(db: GameData, id: String) -> Dictionary:
	return db.get_entry("buildings", id)


## The building that wraps content `id` (its "unlocks"), or {}.
static func of_content(db: GameData, id: String) -> Dictionary:
	for b: Dictionary in db.all("buildings"):
		if id in b.get("unlocks", []):
			return b
	return {}


## Shop entry id -> building id, for upgrades that moved into a building.
static func shop_owner(db: GameData) -> Dictionary:
	var out := {}
	for b: Dictionary in db.all("buildings"):
		for s: String in b.get("shop", []):
			out[s] = b.id
	return out


static func max_level(b: Dictionary) -> int:
	return b.get("levels", []).size()


static func _block(data: Dictionary) -> Dictionary:
	if not data.has("town") or not data.town is Dictionary:
		data.town = {}
	var t: Dictionary = data.town
	if not t.get("levels") is Dictionary:
		t.levels = {}
	if not t.get("patrol") is Dictionary:
		t.patrol = {"since": 0, "banked": 0.0}
	return t


## 0 = not built.
static func level(db: GameData, data: Dictionary, id: String) -> int:
	var b := building(db, id)
	if b.is_empty():
		return 0
	var stored := int(data.get("town", {}).get("levels", {}).get(id, 0))
	if b.has("unlocks"):
		if not Meta.is_owned(db, data, b.unlocks[0]):
			return 0
		return clampi(stored, 1, max_level(b))
	return clampi(stored, 0, max_level(b))


## "built", "buildable" (can be rebuilt now, coins aside) or "ruined".
static func state(db: GameData, data: Dictionary, id: String) -> String:
	if level(db, data, id) > 0:
		return "built"
	var b := building(db, id)
	if b.has("unlocks"):
		return "buildable" if Meta.state(db, data, b.unlocks[0]) == "available" else "ruined"
	return "buildable"


static func is_built(db: GameData, data: Dictionary, id: String) -> bool:
	return level(db, data, id) > 0


## The unlock challenge a ruined building waits on ({} for a "shop" building).
static func challenge(db: GameData, b: Dictionary) -> Dictionary:
	return Meta.challenge_for(db, b.unlocks[0]) if b.has("unlocks") else {}


## Price of the next level (rebuilding is level 1), or -1 at the top.
static func price(db: GameData, data: Dictionary, id: String) -> int:
	var b := building(db, id)
	var lvl := level(db, data, id)
	if b.is_empty() or lvl >= max_level(b):
		return -1
	if lvl == 0 and b.has("unlocks"):
		var ch := challenge(db, b)
		return int(ch.get("price", -1))
	return int(b.levels[lvl].get("price", 0))


## Rebuilds (level 0 -> 1) or upgrades a building with coins. Returns true if
## it went up a level. Patrol is settled first, so hours already walked pay
## at the old rate.
static func build(db: GameData, data: Dictionary, id: String, t := -1) -> bool:
	var b := building(db, id)
	if b.is_empty():
		return false
	var lvl := level(db, data, id)
	var cost := price(db, data, id)
	if cost < 0 or int(data.coins) < cost or (lvl == 0 and state(db, data, id) != "buildable"):
		return false
	settle_patrol(db, data, t)
	var tb := _block(data)
	if lvl == 0 and b.has("unlocks"):
		if not Meta.buy(db, data, b.unlocks[0]):
			return false
		tb.levels.erase(id)
	else:
		data.coins = int(data.coins) - cost
		tb.levels[id] = lvl + 1
	return true


## The level's entry ({} when not built).
static func level_def(db: GameData, data: Dictionary, id: String) -> Dictionary:
	var lvl := level(db, data, id)
	return building(db, id).levels[lvl - 1] if lvl > 0 else {}


## The in-run effect at `lvl` (1-based; the top level if higher).
static func effect_at(b: Dictionary, lvl: int) -> Dictionary:
	if b.get("levels", []).is_empty():
		return {}
	return b.levels[clampi(lvl, 1, max_level(b)) - 1].get("effect", {})


## "a bread stall heals 30 HP once per run." for level `lvl`.
static func effect_text(b: Dictionary, lvl: int) -> String:
	var e := effect_at(b, lvl)
	var vals := {"heal": int(e.get("heal", 0)), "uses": int(e.get("uses", 1))}
	var buff: Dictionary = e.get("buff", {})
	vals.seconds = int(buff.get("seconds", 0))
	var mods: Array = buff.get("modifiers", [])
	if not mods.is_empty():
		var m: Dictionary = mods[0]
		vals.pct = roundi(absf(float(m.get("pct", 0.0))) * 100.0) if m.has("pct") else roundi(absf(float(m.get("flat", 0.0))))
	return String(b.get("effect_desc", "")).format(vals)


## Sum of every building's level: the Town level (the account level on Home).
static func town_level(db: GameData, data: Dictionary) -> int:
	var n := 0
	for b: Dictionary in db.all("buildings"):
		n += level(db, data, b.id)
	return n


## The highest Town level the data allows (every building at the top).
static func max_town_level(db: GameData) -> int:
	var n := 0
	for b: Dictionary in db.all("buildings"):
		n += max_level(b)
	return n


static func built_count(db: GameData, data: Dictionary) -> int:
	return db.all("buildings").filter(func(b: Dictionary) -> bool: return is_built(db, data, b.id)).size()


## Buildings that can be rebuilt now (the Town tab's dot).
static func buildable(db: GameData, data: Dictionary) -> Array:
	return buildings(db).filter(func(b: Dictionary) -> bool: return state(db, data, b.id) == "buildable")


## Buildings the player can rebuild or upgrade right now, coins included
## (the Town tab's dot on the nav).
static func affordable(db: GameData, data: Dictionary) -> Array:
	return buildings(db).filter(func(b: Dictionary) -> bool:
		var cost := price(db, data, b.id)
		return cost >= 0 and int(data.coins) >= cost and state(db, data, b.id) != "ruined")


## Stat upgrades driven by building levels, as [[source, modifiers_per_level,
## level], ...] like Meta.stat_bonuses (same "shop:<id>" sources).
static func stat_bonuses(db: GameData, data: Dictionary) -> Array:
	var out := []
	for b: Dictionary in db.all("buildings"):
		var lvl := level(db, data, b.id)
		if lvl <= 0:
			continue
		for s: String in b.get("shop", []):
			var e := db.get_entry("shop", s)
			if not e.is_empty():
				out.append(["shop:" + s, e.modifiers_per_level, lvl])
	return out


# --- Patrol -----------------------------------------------------------------

## Coins per hour from every built building.
static func patrol_rate(db: GameData, data: Dictionary) -> float:
	var r := 0.0
	for b: Dictionary in db.all("buildings"):
		r += float(level_def(db, data, b.id).get("patrol", 0.0))
	return r


static func cap_hours(db: GameData) -> float:
	return float(rules(db).get("patrol_cap_hours", 8.0))


## The most Patrol holds before it stops earning (cap hours at today's rate).
static func patrol_cap(db: GameData, data: Dictionary) -> int:
	return floori(patrol_rate(db, data) * cap_hours(db))


## Coins earned and not collected, fraction included. Hours count from the
## last settle, at most the cap; a clock set back counts as no time.
static func _pending(db: GameData, data: Dictionary, t: int) -> float:
	var p: Dictionary = data.get("town", {}).get("patrol", {})
	var since := int(p.get("since", 0))
	var banked := float(p.get("banked", 0.0))
	var hours := 0.0
	if since > 0 and t > since:
		hours = minf((t - since) / 3600.0, cap_hours(db))
	return minf(banked + patrol_rate(db, data) * hours, patrol_rate(db, data) * cap_hours(db))


## Whole coins waiting to be collected.
static func patrol_pending(db: GameData, data: Dictionary, t := -1) -> int:
	return floori(_pending(db, data, now() if t < 0 else t))


## Seconds until Patrol is full (0 when it is, or earns nothing).
static func patrol_full_in(db: GameData, data: Dictionary, t := -1) -> int:
	t = now() if t < 0 else t
	var rate := patrol_rate(db, data)
	if rate <= 0.0:
		return 0
	var left := rate * cap_hours(db) - _pending(db, data, t)
	return maxi(0, ceili(left / rate * 3600.0))


## Banks what was earned so far and restarts the hours from `t` (before the
## rate changes, and when Patrol starts: the first building or an old save).
static func settle_patrol(db: GameData, data: Dictionary, t := -1) -> void:
	t = now() if t < 0 else t
	var p: Dictionary = _block(data).patrol
	p.banked = _pending(db, data, t)
	p.since = t


## Pays what Patrol holds (x `mult` for AD x2) and starts it again. Returns
## the coins paid.
static func collect(db: GameData, data: Dictionary, mult := 1, t := -1) -> int:
	t = now() if t < 0 else t
	var got := _pending(db, data, t)
	var coins := floori(got)
	var p: Dictionary = _block(data).patrol
	p.banked = got - coins
	p.since = t
	data.coins = int(data.coins) + coins * mult
	return coins * mult


## Patrol starts counting the first time the Town or Home looks at it.
static func start_patrol(db: GameData, data: Dictionary, t := -1) -> void:
	var p: Dictionary = _block(data).patrol
	if int(p.get("since", 0)) <= 0:
		settle_patrol(db, data, t)


# --- Map --------------------------------------------------------------------

## The map as a run on this save sees it: props and interactables with
## "requires" only while that building is built, and each building prop
## carrying its "sprite" and whether it's "ruined" (MapLayout draws it).
static func resolve_map(db: GameData, data: Dictionary, map_def: Dictionary) -> Dictionary:
	var m := map_def.duplicate()
	var props := []
	for p: Dictionary in map_def.get("props", []):
		var req: String = p.get("requires", "")
		if req != "" and not is_built(db, data, req):
			continue
		if p.get("kind", "") == "building":
			var q := p.duplicate()
			q.sprite = building(db, p.building).get("sprite", "")
			q.ruined = not is_built(db, data, p.building)
			props.append(q)
		else:
			props.append(p)
	m.props = props
	var its := []
	# A lot left empty is still kept clear of chests and pots ("reserved").
	var reserved := []
	for it: Dictionary in map_def.get("interactables", []):
		var req: String = it.get("requires", "")
		if req == "" or is_built(db, data, req):
			its.append(it)
		elif it.has("at"):
			reserved.append(it.at)
	m.interactables = its
	m.reserved = reserved
	return m


## The building props of a map: building id -> its rect.
static func lots(map_def: Dictionary) -> Dictionary:
	var out := {}
	for p: Dictionary in map_def.get("props", []):
		if p.get("kind", "") == "building":
			out[p.building] = MapLayout.rect_of(p)
	return out


# --- Art --------------------------------------------------------------------

## One step darker, by palette name (ruins and night).
const DARKER := {
	"WHITE": "MIST", "PAPER": "MIST", "MIST": "GRAY", "GRAY": "SHADE", "SHADE": "NIGHT", "NIGHT": "INK",
	"SALMON": "RED", "RED": "BLOOD", "BLOOD": "WINE", "WINE": "NIGHT", "BUTTER": "GOLD", "GOLD": "RUST",
	"ORANGE": "RUST", "RUST": "BARK", "LIME": "GREEN", "GREEN": "LEAF", "LEAF": "DEEP_GREEN",
	"DEEP_GREEN": "NIGHT", "SKY": "BLUE", "BLUE": "OCEAN", "OCEAN": "DEEP_BLUE", "DEEP_BLUE": "NIGHT",
	"TEAL": "OCEAN", "PINK": "PURPLE", "PURPLE": "PLUM", "PLUM": "NIGHT", "DOUGH": "CRUST",
	"CRUST": "WOOD", "WOOD": "BARK", "BARK": "SHADE",
}
## The map at night (the Town tab): every daytime colour onto the kit's night
## blues, lamplight (GOLD, BUTTER, ORANGE) kept, like the Home backdrop.
const NIGHT := {
	"WHITE": "MUTED", "PAPER": "MUTED", "MIST": "FRAME_HI", "GRAY": "FRAME", "SHADE": "FRAME_LO",
	"NIGHT": "SURFACE", "INK": "BG", "SALMON": "FRAME_HI", "RED": "FRAME", "BLOOD": "FRAME_LO",
	"WINE": "SURFACE_2", "RUST": "FRAME_LO", "LIME": "FRAME", "GREEN": "LINE", "LEAF": "FRAME_LO",
	"DEEP_GREEN": "RAISED", "SKY": "FRAME_HI", "BLUE": "FRAME", "OCEAN": "FRAME_LO", "DEEP_BLUE": "RAISED",
	"TEAL": "FRAME", "PINK": "FRAME_HI", "PURPLE": "FRAME", "PLUM": "SURFACE_2", "DOUGH": "MUTED",
	"CRUST": "LINE", "WOOD": "FRAME_LO", "BARK": "RAISED",
}


## A copy of `img` with each palette colour swapped by `names` (name -> name);
## colours not in it stay.
static func recolor(img: Image, names: Dictionary) -> Image:
	var swap := {}
	for from: String in names:
		swap[Palette.color(Palette.index_of(from)).to_rgba32()] = Palette.color(Palette.index_of(names[from]))
	var out := img.duplicate() as Image
	out.convert(Image.FORMAT_RGBA8)
	for y in out.get_height():
		for x in out.get_width():
			var c := out.get_pixel(x, y)
			if c.a > 0.0:
				var k := c.to_rgba32()
				if swap.has(k):
					out.set_pixel(x, y, swap[k])
	return out


static var _ruins := {}


## A ruined building: the sprite two steps darker (its windows go dark too),
## with two boards nailed across its lower half. The one code overlay, so a
## building needs one sprite.
static func ruin_image(img: Image, key := "") -> Image:
	if key != "" and _ruins.has(key):
		return _ruins[key]
	var out := recolor(recolor(img, DARKER), DARKER)
	var w := out.get_width()
	var h := out.get_height()
	# Where the sprite has pixels, per row (boards stay on the building).
	var ink := Palette.color(Palette.INK)
	var wood := Palette.color(Palette.WOOD)
	var bark := Palette.color(Palette.BARK)
	var crust := Palette.color(Palette.CRUST)
	var nail := Palette.color(Palette.MIST)
	for k in 2:
		# Two planks, the first rising to the right, the second falling.
		var y0 := int(h * (0.52 + 0.2 * k))
		var x0 := int(w * 0.18)
		var x1 := int(w * 0.82)
		for x in range(x0 - 1, x1 + 2):
			var step := (x - x0) / 6
			var yy := y0 - step if k == 0 else y0 - 2 + step
			for dy in range(-1, 4):
				var y := yy + dy
				if y < 0 or y >= h or x < 0 or x >= w:
					continue
				if out.get_pixel(x, y).a == 0.0 and (dy == -1 or dy == 3 or x == x0 - 1 or x == x1 + 1):
					continue  # outline only over the building
				var c := wood
				if dy == -1 or dy == 3 or x == x0 - 1 or x == x1 + 1:
					c = ink
				elif dy == 0:
					c = crust
				elif dy == 2:
					c = bark
				out.set_pixel(x, y, c)
			if (x == x0 + 1 or x == x1 - 1) and yy + 1 >= 0 and yy + 1 < h:
				out.set_pixel(x, yy + 1, nail)
	if key != "":
		_ruins[key] = out
	return out


static var _sprites := {}


## A building's sprite as an Image (null when the file is missing).
static func sprite_image(path: String) -> Image:
	if not _sprites.has(path):
		var img: Image = null
		if path != "" and ResourceLoader.exists(path):
			var res = load(path)
			img = res if res is Image else (res.get_image() if res is Texture2D else null)
			if img != null:
				img = img.duplicate() as Image
				img.convert(Image.FORMAT_RGBA8)
		_sprites[path] = img
	return _sprites[path]

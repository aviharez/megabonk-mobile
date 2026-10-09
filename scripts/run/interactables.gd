class_name Interactables
extends Node2D
## Map objects: chests, shrines, pots, the merchant, the pigeon cage and its
## key, the boss altar and the exit portal. Every one is used by touching it
## or standing in its circle (no buttons). What each does is its "behavior"
## (written once here); its numbers, looks and arrow color come from
## data/interactables/. Where they stand comes from the map's "interactables"
## list (random free spots) or from events (elite chests, the portal...).
##
## Behaviors: paid_chest, free_chest, pot, charge_shrine, risk_shrine,
## challenge_shrine, merchant, cage, key, altar, portal.

const BEHAVIORS := ["paid_chest", "free_chest", "pot", "charge_shrine", "risk_shrine", "challenge_shrine", "merchant", "cage", "key", "altar", "portal"]
## Behaviors you stand in for "charge_time" seconds.
const STAND := ["charge_shrine", "risk_shrine", "challenge_shrine", "altar"]
const FONT := preload("res://assets/fonts/pixel.fnt")
const MAX_ARROWS := 6

var run: Node
var db: GameData
## Live objects: {"id", "def", "pos", "inside", "progress", "used", ...}.
var list: Array[Dictionary] = []
var has_key := false
var paid_opened := 0
## Running shrine effects, any number at once (a map may have several
## shrines): risks [{"left", "src", "def"}] and challenges [{"left", "need",
## "start_kills", "def"}].
var risks: Array[Dictionary] = []
var challenges: Array[Dictionary] = []
## Set by Run on a first run when the boss wasn't summoned in time.
var altar_pulse := false
static var _sprites := {}  # sprite path -> ImageTexture (null when missing)
var _time := 0.0
var _risk_n := 0


func setup(owner_run: Node, data: GameData) -> void:
	run = owner_run
	db = data


## Places the map's objects: at a fixed "at": [x, y] from the map, or on
## random free spots (seeded by the run).
func place_from_map(map_def: Dictionary, layout: MapLayout, rng: RandomNumberGenerator, start: Vector2) -> void:
	var taken: Array = []
	var clear: float = map_def.get("start_clear_radius", 60.0)
	for entry: Dictionary in map_def.get("interactables", []):
		var def := db.get_entry("interactables", entry.id)
		if entry.has("at"):
			# A fixed spot from the map (the altar on the sports field...).
			var fixed := Vector2(entry.at[0], entry.at[1])
			taken.append(fixed)
			add(entry.id, fixed)
			continue
		for i in int(entry.get("count", 1)):
			var gap := 48.0 if def.behavior != "pot" else 24.0
			var at := layout.random_free_point(rng, float(def.radius) + 4.0, taken, gap, start, maxf(clear, float(entry.get("min_distance_from_start", 0.0))))
			taken.append(at)
			add(entry.id, at)


## Adds one object. Returns it (a Dictionary that stays live until used).
func add(id: String, at: Vector2) -> Dictionary:
	var def := db.get_entry("interactables", id)
	if def.is_empty():
		push_error("Interactables: '%s' not found" % id)
		return {}
	# Something that appears under the player (a reward chest, the portal)
	# waits for them to step out and back in: no accidental use.
	var inside: bool = run.player_pos().distance_to(at) <= float(def.radius) + run.player_radius()
	var o := {"id": id, "def": def, "pos": at.round(), "inside": inside, "progress": 0.0, "used": false}
	if def.behavior == "merchant":
		o.left = float(def.get("stay_sec", 45.0))
		o.stock = _roll_stock(def)
	list.append(o)
	return o


func remove(o: Dictionary) -> void:
	list.erase(o)


func find(id: String) -> Dictionary:
	for o in list:
		if o.id == id:
			return o
	return {}


func count_of(id: String) -> int:
	var n := 0
	for o in list:
		if o.id == id:
			n += 1
	return n


## Price of the next paid chest (rises with every one opened).
func paid_price(def: Dictionary) -> int:
	return ceili(float(def.price) * pow(float(def.get("price_growth", 1.0)), paid_opened))


func update(delta: float) -> void:
	_time += delta
	var p: Vector2 = run.player_pos()
	var pr: float = run.player_radius()
	for o in list.duplicate():
		if not list.has(o):
			continue
		var def: Dictionary = o.def
		if def.behavior == "merchant":
			o.left -= delta
			if o.left <= 0.0:
				run.toast("THE MERCHANT LEFT", "MIST")
				run.fx.puff(o.pos, 8.0, Palette.MIST, 0.4)
				remove(o)
				continue
		if o.used:
			continue
		var inside: bool = p.distance_to(o.pos) <= float(def.radius) + pr
		var entered: bool = inside and not o.inside
		o.inside = inside
		if def.behavior in STAND:
			if inside:
				o.progress += delta
				if o.progress >= float(def.get("charge_time", 2.0)):
					_activate(o)
			else:
				o.progress = maxf(0.0, o.progress - delta * 2.0)
		elif entered:
			_touch(o)
	_update_effects(delta)
	queue_redraw()


func _touch(o: Dictionary) -> void:
	var def: Dictionary = o.def
	match def.behavior:
		"paid_chest":
			var price := paid_price(def)
			if run.gold >= price:
				run.spend_gold(price)
				paid_opened += 1
				remove(o)
				run.open_chest(def.chest, o.pos)
			else:
				run.toast("NEED G %d" % price, "GOLD")
		"free_chest":
			remove(o)
			run.open_chest(def.chest, o.pos)
		"pot":
			var g: Array = def.get("gold", [1, 3])
			var amount: int = run.rng.randi_range(int(g[0]), int(g[1]))
			run.add_gold(amount)
			run.numbers.show_text(o.pos, "+%dG" % amount, Palette.GOLD)
			run.fx.ring(o.pos, 6.0, Palette.CRUST)
			run.fx.puff(o.pos, 6.0, Palette.CRUST, 0.3)
			run.juice.sfx("pot")
			run.record("pots_broken")
			remove(o)
		"merchant":
			run.open_merchant(o)
		"cage":
			if has_key:
				has_key = false
				o.used = true
				run.record(def.get("stat_event", "pigeon_cage_opened"))
				run.toast("PIGEON FREED!", "BUTTER")
				run.fx.ring(o.pos, 14.0, Palette.BUTTER)
				run.fx.sparks(o.pos, 14.0, Palette.BUTTER)
				run.juice.sfx("cage")
			else:
				run.toast("THE CAGE NEEDS A KEY", "MIST")
		"key":
			has_key = true
			remove(o)
			run.record("keys_found")
			run.toast("GOT A KEY!", "GOLD")
			run.fx.star(o.pos, 5.0, Palette.GOLD, 0.3)
			run.juice.sfx("key")
		"portal":
			run.escape()


func _activate(o: Dictionary) -> void:
	var def: Dictionary = o.def
	o.progress = 0.0
	if def.behavior == "altar":
		# Used up only if the boss really appeared (the enemy pool can be full).
		o.used = run.summon_boss(def.boss, o.pos)
		return  # summoning a boss isn't a shrine
	o.used = true
	match def.behavior:
		"charge_shrine":
			run.open_shrine_choice(def)
		"risk_shrine":
			_risk_n += 1
			var src := "risk:%d" % _risk_n
			for m: Dictionary in def.get("modifiers", []):
				run.stats.set_modifier(m.stat, src, float(m.get("flat", 0.0)), float(m.get("pct", 0.0)))
			risks.append({"left": float(def.duration), "src": src, "def": def})
			run.toast("RISK! FOES +, LOOT +", "RED")
			run.juice.shake("explode")
		"challenge_shrine":
			challenges.append({"left": float(def.time), "need": int(def.kills), "start_kills": run.kills, "def": def})
			run.toast("KILL %d IN %dS!" % [int(def.kills), int(def.time)], "GOLD")
	remove(o)
	run.shrine_activated(def.id)


func _update_effects(delta: float) -> void:
	for r in risks.duplicate():
		r.left -= delta
		if r.left > 0.0:
			continue
		for m: Dictionary in r.def.get("modifiers", []):
			run.stats.remove_modifier(m.stat, r.src)
		var chest: String = r.def.get("reward_chest", "")
		if chest != "":
			add(chest + "_chest", _reward_spot())
		run.toast("RISK OVER: REWARD!", "GOLD")
		risks.erase(r)
	for c in challenges.duplicate():
		c.left -= delta
		var got: int = run.kills - c.start_kills
		if got >= c.need:
			var chest: String = c.def.get("reward_chest", "")
			if chest != "":
				add(chest + "_chest", _reward_spot())
			run.record("challenges_won")
			run.toast("CHALLENGE DONE!", "GOLD")
			challenges.erase(c)
		elif c.left <= 0.0:
			run.toast("CHALLENGE FAILED", "MIST")
			challenges.erase(c)


## A free spot a short walk from the player, for reward chests.
func _reward_spot() -> Vector2:
	return run.free_spot_near(run.player_pos() + Vector2.from_angle(run.rng.randf() * TAU) * 24.0)


## Kills left and seconds left of the running challenge that ends first, or
## [] if none.
func challenge_status() -> Array:
	if challenges.is_empty():
		return []
	var c: Dictionary = challenges[0]
	for o in challenges:
		if o.left < c.left:
			c = o
	return [maxi(0, c.need - (run.kills - c.start_kills)), ceili(c.left)]


func _roll_stock(def: Dictionary) -> Array:
	var stock := []
	var held: Dictionary = run.items.stacks.duplicate()
	for i in int(def.get("stock", 3)):
		var id := Loot.roll(run.rng, db, def.get("chest", "paid"), run.stat("luck"), held, run.pool)
		if id == "":
			break
		var item := db.get_entry("items", id)
		stock.append({"item": id, "price": int(def.prices.get(item.rarity, 50)), "sold": false})
		held[id] = held.get(id, 0) + 1
	return stock


## Arrow targets for the HUD: [{"pos", "color", "pulse"}] for objects
## outside `view`, at most MAX_ARROWS. On-screen objects are left out before
## the cut, so they never use up a slot. The altar (until the boss comes) and
## the portal always get theirs; the rest are nearest first.
func arrow_targets(view: Rect2) -> Array:
	var keep := []
	var rest := []
	var p: Vector2 = run.player_pos()
	for o in list:
		var c: String = o.def.get("arrow", "")
		if c == "" or o.used or view.has_point(o.pos):
			continue
		var t := {"pos": o.pos, "color": Palette.index_of(c), "pulse": altar_pulse and o.def.behavior == "altar", "d": p.distance_squared_to(o.pos)}
		if o.def.behavior in ["altar", "portal"]:
			keep.append(t)
		else:
			rest.append(t)
	rest.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.d < b.d)
	return keep + rest.slice(0, maxi(0, MAX_ARROWS - keep.size()))


# --- Drawing --------------------------------------------------------------

func _draw() -> void:
	for o in list:
		var def: Dictionary = o.def
		var tex := sprite_of(def)
		var at: Vector2 = o.pos
		if def.behavior in STAND:
			_draw_circle(at, float(def.radius), Palette.index_of(def.color), o.progress / float(def.get("charge_time", 2.0)), o.used)
		var bob := 0.0
		if def.behavior in ["key", "portal", "free_chest"]:
			bob = float(int(_time * 3.0) % 2)
		draw_texture(tex, (at - Vector2(floorf(tex.get_width() / 2.0), floorf(tex.get_height() / 2.0) + bob)).round())
		if def.behavior == "paid_chest" and run.player_pos().distance_to(at) < 50.0:
			_label(at + Vector2(0, -10), "G %d" % paid_price(def), Palette.GOLD)
		elif def.behavior == "merchant":
			_label(at + Vector2(0, -12), "SHOP %d" % ceili(o.left), Palette.BUTTER)
	if not risks.is_empty():
		var left := 0.0
		for r in risks:
			left = maxf(left, r.left)
		_label(run.player_pos() + Vector2(0, -16), "RISK %d" % ceili(left), Palette.RED)


## The object's picture: its "sprite" (an Image-imported PNG) if it has one,
## else its placeholder "shape" in its color.
static func sprite_of(def: Dictionary) -> Texture2D:
	var path: String = def.get("sprite", "")
	if path != "":
		if not _sprites.has(path):
			var img = load(path) if ResourceLoader.exists(path) else null
			_sprites[path] = ImageTexture.create_from_image(img) if img is Image else null
		if _sprites[path] != null:
			return _sprites[path]
	return PlaceholderArt.texture(def.shape, Palette.index_of(def.color))


## Dotted circle with the charge progress drawn solid over it.
func _draw_circle(at: Vector2, r: float, color: int, progress: float, used: bool) -> void:
	var c := Palette.color(Palette.GRAY if used else color)
	var steps := maxi(16, int(TAU * r / 3.0))
	for i in steps:
		var a := TAU * i / steps - PI / 2.0
		if float(i) / steps < progress or i % 2 == 0:
			draw_rect(Rect2((at + Vector2.from_angle(a) * r).round(), Vector2.ONE), c)


func _label(at: Vector2, text: String, color: int) -> void:
	var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var p := (at - Vector2(floorf(w / 2.0), 0)).round()
	draw_string(FONT, p + Vector2(0, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(Palette.INK))
	draw_string(FONT, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(color))

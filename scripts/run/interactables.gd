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
				run.toast("The merchant left.", "MIST")
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
				var before: float = o.progress
				o.progress += delta
				_charge_blip(before, o.progress, float(def.get("charge_time", 2.0)))
				if o.progress >= float(def.get("charge_time", 2.0)):
					_activate(o)
			else:
				o.progress = maxf(0.0, o.progress - delta * 2.0)
		elif entered:
			_touch(o)
	_update_effects(delta)
	queue_redraw()


## Standing in a shrine or the altar: a blip for each step of the charge
## (the first as soon as you step in), each higher than the last, so you can
## hear it fill. Steps and rise from the "charge" sound in rules/audio.json.
func _charge_blip(before: float, now: float, charge_time: float) -> void:
	var c: Dictionary = db.get_entry("rules", "audio").get("sfx", {}).get("charge", {})
	var steps := maxi(1, int(c.get("steps", 10)))
	var was := -1 if before <= 0.0 else floori(before / charge_time * steps)
	var step := floori(now / charge_time * steps)
	if step > was and step < steps:
		run.juice.sfx("charge", 1.0 + float(c.get("rise", 1.0)) * step / float(steps - 1 if steps > 1 else 1))


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
				run.toast("Need G %d" % price, "GOLD")
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
				run.toast("Pigeon freed!", "BUTTER")
				run.fx.ring(o.pos, 14.0, Palette.BUTTER)
				run.fx.sparks(o.pos, 14.0, Palette.BUTTER)
				run.juice.sfx("cage")
			else:
				run.toast("The cage needs a key.", "MIST")
		"key":
			has_key = true
			remove(o)
			run.record("keys_found")
			run.toast("Got a key!", "GOLD")
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
			run.toast("Risk! Foes +, loot +", "RED")
			run.juice.shake("explode")
		"challenge_shrine":
			challenges.append({"left": float(def.time), "need": int(def.kills), "start_kills": run.kills, "def": def})
			run.toast("Kill %d in %ds!" % [int(def.kills), int(def.time)], "GOLD")
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
		run.toast("Risk over: reward!", "GOLD")
		risks.erase(r)
	for c in challenges.duplicate():
		c.left -= delta
		var got: int = run.kills - c.start_kills
		if got >= c.need:
			var chest: String = c.def.get("reward_chest", "")
			if chest != "":
				add(chest + "_chest", _reward_spot())
			run.record("challenges_won")
			run.toast("Challenge done!", "GOLD")
			challenges.erase(c)
		elif c.left <= 0.0:
			run.toast("Challenge failed", "MIST")
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
	# Pass 1: light under everything (glow on the ground, pillars of light),
	# so chests and shrines read from across the screen.
	# (Pillars carry information, so they stay with "reduce effects" on.)
	var view: Rect2 = run.view_rect().grow(16.0) if run.has_method("view_rect") else Rect2(-1e9, -1e9, 2e9, 2e9)
	for o in list:
		if o.used:
			continue
		var beam: Dictionary = o.def.get("beam", {})
		if beam.is_empty() or not view.grow_individual(0, float(beam.height), 0, 0).has_point(o.pos):
			continue
		var c := Palette.index_of(beam.color)
		_draw_glow(o.pos, c, int(o.pos.x * 3.0 + o.pos.y))
		_draw_pillar(o.pos, c, float(beam.height), int(o.pos.x + o.pos.y * 7.0))
	for o in list:
		var def: Dictionary = o.def
		var at: Vector2 = o.pos
		if not view.has_point(at):
			continue
		var tex := sprite_of(def)
		if def.behavior in STAND:
			_draw_circle(at, float(def.radius), Palette.index_of(def.color), o.progress / float(def.get("charge_time", 2.0)), o.used)
		var bob := 0.0
		if def.behavior in ["key", "portal", "free_chest", "paid_chest"] and not o.used:
			bob = float(int(_time * 3.0 + at.x * 0.1) % 2)
		var tp := (at - Vector2(floorf(tex.get_width() / 2.0), floorf(tex.get_height() / 2.0) + bob)).round()
		draw_texture(tex, tp)
		if not o.used and (def.has("beam") or def.has("twinkle")):
			var tc := Palette.index_of(def.beam.color if def.has("beam") else def.twinkle)
			_draw_twinkles(at, Vector2(tex.get_size()), tc, int(at.x * 5.0 + at.y), 1 if def.has("beam") else 0)
		if def.behavior == "paid_chest":
			var price := paid_price(def)
			var can: bool = run.gold >= price
			_price_tag(at + Vector2(0, -floorf(tex.get_height() / 2.0) - 9 - bob), price, can)
		elif def.behavior == "merchant":
			_label(at + Vector2(0, -12), "Shop %d" % ceili(o.left), Palette.BUTTER)
	if not risks.is_empty():
		var left := 0.0
		for r in risks:
			left = maxf(left, r.left)
		_label(run.player_pos() + Vector2(0, -16), "Risk %d" % ceili(left), Palette.RED)


## Cached pillar textures: "color|height|phase" -> ImageTexture. A column of
## light: a white core, solid colour round it, dithered edges that thin out
## toward the top. Two phases swap so it shimmers.
static var _pillars := {}


static func pillar_texture(color: int, height: int, phase: int) -> Texture2D:
	var key := "%d|%d|%d" % [color, height, phase]
	if _pillars.has(key):
		return _pillars[key]
	var w := 11
	var img := Image.create_empty(w, height, false, Image.FORMAT_RGBA8)
	var c := Palette.color(color)
	var white := Palette.color(Palette.WHITE)
	for y in height:
		var f := float(y) / float(height)  # 0 top, 1 foot
		for x in w:
			var dx := absf(x - 5)
			var a := (1.0 - dx / 6.0) * (0.3 + 0.7 * f)
			if dx == 0 and Fx.dither(Vector2(x, y + phase * 2), 0.25 + f):
				img.set_pixel(x, y, white)
			elif (dx <= 1 and Fx.dither(Vector2(x, y + phase), 0.4 + f)) or Fx.dither(Vector2(x + phase, y + phase * 2), a):
				img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_pillars[key] = tex
	return tex


func _draw_pillar(at: Vector2, color: int, height: float, seed_i: int) -> void:
	var h := int(height)
	var phase := int(_time * 5.0 + seed_i) % 2
	draw_texture(pillar_texture(color, h, phase), (at - Vector2(5, h - 2)).round())
	# Motes rising up the column.
	var white := Palette.color(Palette.WHITE)
	var c := Palette.color(color)
	for k in 3:
		var t := fposmod(_time * 0.5 + k * 0.33 + seed_i * 0.13, 1.0)
		var p := (at + Vector2(((seed_i >> k) % 5) - 2, -2.0 - t * height)).round()
		if Fx.dither(p, 1.0 - t):
			draw_rect(Rect2(p, Vector2.ONE), white if k == 0 else c)


## A flat pulsing oval of light on the ground under the object: four cached
## sizes per colour, stepped with the pulse.
static var _glows := {}


static func glow_texture(color: int, step: int) -> Texture2D:
	var key := "%d|%d" % [color, step]
	if _glows.has(key):
		return _glows[key]
	var rx := 9.0 + step
	var ry := rx * 0.45
	var w := int(rx) * 2 + 1
	var h := int(ry) * 2 + 1
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var c := Palette.color(color)
	for y in h:
		for x in w:
			var d := Vector2((x - int(rx)) / rx, (y - int(ry)) / ry).length()
			if d <= 1.0 and Fx.dither(Vector2(x, y), 0.25 + (1.0 - d) * 0.75):
				img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_glows[key] = tex
	return tex


func _draw_glow(at: Vector2, color: int, seed_i: int) -> void:
	var step := clampi(int((0.5 + 0.5 * sin(_time * 3.0 + seed_i * 0.1)) * 4.0), 0, 3)
	var tex := glow_texture(color, step)
	draw_texture(tex, (at + Vector2(0, 4) - Vector2(tex.get_size() / 2).floor()).round())


## Plus-shaped twinkles popping round the sprite in turn.
func _draw_twinkles(at: Vector2, sprite_size: Vector2, color: int, seed_i: int, extra := 1) -> void:
	var c := Palette.color(color)
	var white := Palette.color(Palette.WHITE)
	for k in 1 + extra:
		var cycle := _time * 1.3 + k * 0.5 + seed_i * 0.07
		var t := fposmod(cycle, 1.0)
		var n := int(cycle) * 7 + k * 3 + seed_i
		var off := Vector2(((n * 37) % 15) - 7, ((n * 53) % 13) - 9) * Vector2(sprite_size.x / 14.0, sprite_size.y / 14.0)
		var p := (at + off).round()
		var arm := roundf(2.0 * (1.0 - absf(t * 2.0 - 1.0)))
		if arm < 1.0:
			continue
		draw_rect(Rect2(p.x - arm, p.y, arm * 2.0 + 1.0, 1), c)
		draw_rect(Rect2(p.x, p.y - arm, 1, arm * 2.0 + 1.0), c)
		draw_rect(Rect2(p, Vector2.ONE), white)


## The chest's price on a small dark plate: coin + number, GOLD when the
## player can pay, SALMON when not.
func _price_tag(at: Vector2, price: int, can: bool) -> void:
	var text := str(price)
	var tw := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var w := tw + 9
	var r := Rect2((at - Vector2(floorf(w / 2.0), 0)).round(), Vector2(w, 9))
	draw_rect(r, Palette.color(Palette.INK))
	draw_rect(r.grow(-1), Palette.color(Palette.NIGHT))
	# A tiny coin: 4x4 gold with a dark middle.
	draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(4, 5)), Palette.color(Palette.GOLD))
	draw_rect(Rect2(r.position + Vector2(3, 3), Vector2(2, 3)), Palette.color(Palette.ORANGE))
	draw_string(FONT, r.position + Vector2(8, 8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(Palette.GOLD if can else Palette.SALMON))


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


## The stand-in circle: a dashed ring that turns slowly, a faint dither
## inside, and the charge progress as a thick solid ring filling clockwise.
func _draw_circle(at: Vector2, r: float, color: int, progress: float, used: bool) -> void:
	var c := Palette.color(Palette.GRAY if used else color)
	var steps := maxi(16, int(TAU * r / 3.0))
	var spin := 0.0 if used else _time * 0.6
	for i in steps:
		var a := TAU * i / steps - PI / 2.0
		if i % 3 != 2:
			draw_rect(Rect2((at + Vector2.from_angle(a + spin) * r).round(), Vector2.ONE), c)
	if used:
		return
	if progress > 0.0:
		# Inside lights up as it charges.
		var ri := int(r) - 2
		for y in range(-ri, ri + 1, 2):
			for x in range(-ri + (y / 2) % 2, ri + 1, 2):
				var p := at + Vector2(x, y)
				if x * x + y * y <= ri * ri and Fx.dither(p, progress * 0.5):
					draw_rect(Rect2(p.round(), Vector2.ONE), c)
		var white := Palette.color(Palette.WHITE)
		var n := int(steps * 1.5)
		for i in n:
			var f := float(i) / n
			if f > progress:
				break
			var a := TAU * f - PI / 2.0
			var p := (at + Vector2.from_angle(a) * r).round()
			draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), white if f > progress - 0.05 else c)


func _label(at: Vector2, text: String, color: int) -> void:
	var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var p := (at - Vector2(floorf(w / 2.0), 0)).round()
	draw_string(FONT, p + Vector2(0, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(Palette.INK))
	draw_string(FONT, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(color))

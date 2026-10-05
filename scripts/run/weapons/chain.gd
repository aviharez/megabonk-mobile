extends Weapon
## "chain" pattern (Faulty Toaster): every cooldown, electricity jumps from
## the player to the nearest enemy within "range", then on to the nearest
## enemy not yet hit, "jumps" times in total (Run.chain_zap). Weapon hits,
## so they can crit and fire on_hit.
## Level keys: damage, cooldown, jumps, range. Player stats: damage, area
## (range), cooldown, and projectiles (each extra projectile is one more
## jump).

const LEVEL_KEYS := ["damage", "cooldown", "jumps", "range"]
const SPARK_TIME := 0.15

var _cooldown := 0.6
var _spark := 0.0
## Enemies hit by the last zap (tests).
var last_hits := 0


func update(delta: float, run: Node) -> void:
	if _spark > 0.0:
		_spark -= delta
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var reach := area(run, "range")
	# Hold the charge until something is in reach, so zaps aren't wasted.
	if run.enemies.nearest(run.player_pos(), reach) < 0:
		_cooldown = 0.1
		return
	_cooldown = cooldown(run)
	attacked(run)
	_spark = SPARK_TIME
	last_hits = run.chain_zap(run.player_pos(), dmg(run), amount(run, "jumps"), reach, id(), -1, true, "SKY")


func draw(canvas: CanvasItem, origin: Vector2) -> void:
	if _spark <= 0.0:
		return
	# A few sparks crackling off the player as the toaster fires.
	var o := origin.round()
	var sky := Palette.color(Palette.SKY)
	var white := Palette.color(Palette.WHITE)
	var k := int(_spark * 60.0)
	for i in 4:
		var a := float(i) * TAU / 4.0 + float(k) * 0.7
		canvas.draw_rect(Rect2((o + Vector2.from_angle(a) * 7.0).round(), Vector2.ONE), sky if i % 2 == 0 else white)

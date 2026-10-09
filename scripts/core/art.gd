class_name Art
extends RefCounted
## Sprites named by path in data ("sprite", "shot_sprite", ...), loaded once
## and cached. Accepts Image-imported PNGs, Texture-imported PNGs and plain
## PNG files that aren't imported (tests, mods). Returns null for "" or a
## missing file, so callers can fall back to their PlaceholderArt shape.

static var _cache := {}  # path -> Texture2D (null when missing)


static func texture(path: String) -> Texture2D:
	if path == "":
		return null
	if not _cache.has(path):
		var res = load(path) if ResourceLoader.exists(path) else null
		if res == null and FileAccess.file_exists(path):
			res = Image.load_from_file(path)
		if res is Image:
			res = ImageTexture.create_from_image(res)
		_cache[path] = res as Texture2D
	return _cache[path]


## Index of the frame in a strip of `turns` frames (frame k points at angle
## k * TAU / turns) closest to the direction `dir`.
static func turn_frame(dir: Vector2, turns: int) -> int:
	if turns <= 1 or dir == Vector2.ZERO:
		return 0
	return posmod(roundi(dir.angle() / TAU * turns), turns)

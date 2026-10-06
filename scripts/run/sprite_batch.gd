class_name SpriteBatch
extends MultiMeshInstance2D
## Draws many copies of one pixel sprite in a single draw call (MultiMesh).
## Each frame: begin(), push() per visible copy, commit(). Positions are
## rounded to whole pixels; the quad is offset so odd-sized sprites stay on
## the pixel grid.
##
## Animated sheets: the texture is a horizontal strip of `frames` frames of
## equal width; each copy picks its own frame. Per copy, the four custom data
## floats carry flash, mirror, frame index and outline color (see the shader,
## assets/shaders/batch_flash.gdshader). Copies can be scaled by a whole
## number (elites), which keeps every texel on the pixel grid.

const FLOATS := 12  # 8 for the 2D transform + 4 custom data
const FLASH_SHADER := preload("res://assets/shaders/batch_flash.gdshader")

var frames := 1
var _buf := PackedFloat32Array()
var _n := 0
var _last_n := -1
var _cap := 0


func setup(tex: Texture2D, capacity: int, frame_count := 1) -> void:
	texture = tex
	_cap = capacity
	frames = maxi(1, frame_count)
	var w := tex.get_width() / frames
	var h := tex.get_height()
	var x0 := -floorf(w / 2.0)
	var y0 := -floorf(h / 2.0)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([
		Vector2(x0, y0), Vector2(x0 + w, y0), Vector2(x0 + w, y0 + h), Vector2(x0, y0 + h)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
		Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = capacity
	mm.visible_instance_count = 0
	# Fixed huge bounds so the batch is never culled by stale auto bounds.
	mm.custom_aabb = AABB(Vector3(-1.0e5, -1.0e5, -1.0), Vector3(2.0e5, 2.0e5, 2.0))
	multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = FLASH_SHADER
	mat.set_shader_parameter("frames", frames)
	mat.set_shader_parameter("palette", Palette.texture())
	material = mat
	_buf.resize(capacity * FLOATS)
	_buf.fill(0.0)


func begin() -> void:
	_n = 0


## One copy at `pos`. frame: index into the strip (wraps). outline: palette
## index of the outline color, -1 for none. scale: whole-number size.
func push(pos: Vector2, flash: bool = false, flip: bool = false, frame := 0, outline := -1, scale := 1.0) -> void:
	if _n >= _cap:
		return
	var o := _n * FLOATS
	_buf[o] = scale
	_buf[o + 3] = roundf(pos.x)
	_buf[o + 5] = scale
	_buf[o + 7] = roundf(pos.y)
	_buf[o + 8] = 1.0 if flash else 0.0
	_buf[o + 9] = 1.0 if flip else 0.0
	_buf[o + 10] = float(frame % frames)
	_buf[o + 11] = float(outline + 1)
	_n += 1


func commit() -> void:
	# An empty batch that was already empty needs no upload.
	if _n == 0 and _last_n == 0:
		return
	_last_n = _n
	# Count first: the buffer setter recomputes bounds over visible instances.
	multimesh.visible_instance_count = _n
	multimesh.buffer = _buf


func visible_count() -> int:
	return _n

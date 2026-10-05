class_name SlotPool
extends RefCounted
## Fixed-capacity pool of integer slots for struct-of-arrays systems (enemies,
## gems, projectiles). Nothing is allocated after setup: acquire() hands out a
## free index, release() returns it. `active` lists live slots (unordered,
## swap-remove), so systems loop over it instead of the whole capacity.

var capacity: int
var active := PackedInt32Array()
var _free := PackedInt32Array()
## Position of each live slot inside `active`, -1 when free.
var _where := PackedInt32Array()


func _init(cap: int) -> void:
	capacity = cap
	_where.resize(cap)
	_where.fill(-1)
	_free.resize(cap)
	for i in cap:
		_free[i] = cap - 1 - i  # pop from the end hands out 0, 1, 2...


func count() -> int:
	return active.size()


func is_full() -> bool:
	return _free.is_empty()


func is_alive(slot: int) -> bool:
	return _where[slot] >= 0


## Returns a free slot, or -1 when the pool is full.
func acquire() -> int:
	if _free.is_empty():
		return -1
	var slot := _free[_free.size() - 1]
	_free.resize(_free.size() - 1)
	_where[slot] = active.size()
	active.append(slot)
	return slot


func release(slot: int) -> void:
	var at := _where[slot]
	if at < 0:
		return
	var last := active[active.size() - 1]
	active[at] = last
	_where[last] = at
	active.resize(active.size() - 1)
	_where[slot] = -1
	_free.append(slot)


func clear() -> void:
	for i in range(active.size() - 1, -1, -1):
		release(active[i])

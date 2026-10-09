class_name FakeStoreBackend
extends StoreBackend
## Stand-in store on desktop, in the editor and in tests. Every product costs
## `price`. `outcome` decides what buy() does: "owned", "pending",
## "canceled" or "failed". Ownership lives in the Store's save flag, so
## restore() reports `owned_ids` (empty unless a test sets it) as incomplete.

var price := "USD 1.99"
var outcome := "owned"
var step_sec := 0.0
var owned_ids: Array = []
var calls: Array[String] = []
var _ids: Array = []


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(store_ids: Array) -> void:
	_ids = store_ids
	_after(func() -> void:
		is_ready = true
		var prices := {}
		for id: String in _ids:
			prices[id] = price
		prices_changed.emit(prices)
		owned_changed.emit(owned_ids.duplicate(), false))


func buy(store_id: String) -> void:
	calls.append("buy:" + store_id)
	_after(func() -> void:
		if outcome == "owned" and not store_id in owned_ids:
			owned_ids.append(store_id)
		purchase_done.emit(store_id, outcome))


func restore() -> void:
	calls.append("restore")
	_after(func() -> void: owned_changed.emit(owned_ids.duplicate(), false))


func _after(fn: Callable) -> void:
	if step_sec <= 0.0:
		fn.call_deferred()
	else:
		get_tree().create_timer(step_sec, true).timeout.connect(fn)

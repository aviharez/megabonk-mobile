extends Node
## In-app purchases (autoload "Store"): Remove Ads, from data/rules/store.json.
## Products are keyed by our id ("remove_ads"); each has the store's id per
## platform. Owning one is written to the save ("remove_ads" ->
## save ads.removed), so it works offline and on desktop; the store's own
## list wins whenever it answers (restores on a new install, drops refunds).

signal changed
## A purchase flow ended: "owned", "pending", "canceled" or "failed".
signal purchase_finished(key: String, status: String)

var config: Dictionary = {}
var backend: StoreBackend
var save: Node
var started := false
var _prices := {}  # store id -> text
var _pending := {}  # key -> true while the store says the payment is pending
var _busy := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if get_parent() == get_tree().root and name == "Store":
		_autostart.call_deferred()


func _autostart() -> void:
	if not started:
		start(get_node_or_null("/root/Save"), _make_backend())


## Which StoreBackend a build gets: "sdk" (Play Billing) where its native
## plugin exists; otherwise "fake" only in debug builds (the fake sells
## everything for free). A release build without the plugin gets "none": the
## inert base StoreBackend, never ready, so the shop shows STORE OFFLINE.
static func backend_kind(has_plugin: bool, debug_build: bool) -> String:
	if has_plugin:
		return "sdk"
	return "fake" if debug_build else "none"


func _make_backend() -> StoreBackend:
	match backend_kind(Engine.has_singleton("GodotGooglePlayBilling"), OS.is_debug_build()):
		"sdk":
			return load("res://scripts/store/play_store_backend.gd").new()
		"fake":
			var fake := FakeStoreBackend.new()
			fake.step_sec = 0.5
			return fake
	push_warning("Store: no billing SDK in this release build, the store is off")
	return StoreBackend.new()


func start(save_node: Node, backend_node: StoreBackend, cfg := {}) -> void:
	save = save_node
	config = cfg if not cfg.is_empty() else GameData.shared().get_entry("rules", "store")
	backend = backend_node
	add_child(backend)
	backend.prices_changed.connect(_on_prices)
	backend.owned_changed.connect(_on_owned)
	backend.purchase_done.connect(_on_purchase_done)
	started = true
	var ids := []
	for key: String in products():
		ids.append(store_id(key))
	backend.setup(ids)


func products() -> Dictionary:
	return config.get("products", {})


func store_id(key: String) -> String:
	var p: Dictionary = products().get(key, {})
	return p.get("ios" if OS.get_name() == "iOS" else "android", "")


func _key_of(id: String) -> String:
	for key: String in products():
		if store_id(key) == id:
			return key
	return ""


func owns(key: String) -> bool:
	match key:
		"remove_ads":
			return save != null and bool(save.data.ads.get("removed", false))
	return false


## "owned", "busy" (flow running), "pending" (payment pending),
## "buyable", or "unavailable" (store not connected / product unknown).
func state(key: String) -> String:
	if owns(key):
		return "owned"
	if _busy == key:
		return "busy"
	if _pending.has(key):
		return "pending"
	if backend != null and backend.is_ready and _prices.has(store_id(key)):
		return "buyable"
	return "unavailable"


func price_text(key: String) -> String:
	return _prices.get(store_id(key), "")


## Starts the store's purchase flow (no-op unless state is "buyable").
func buy(key: String) -> bool:
	if state(key) != "buyable":
		return false
	_busy = key
	backend.buy(store_id(key))
	changed.emit()
	return true


func restore() -> void:
	if backend != null:
		backend.restore()


func _on_prices(prices: Dictionary) -> void:
	_prices.merge(prices, true)
	changed.emit()


func _on_owned(ids: Array, complete: bool) -> void:
	for key: String in products():
		var has := store_id(key) in ids
		if has:
			_pending.erase(key)
			_grant(key, true)
		elif complete and owns(key):
			# The store's full list doesn't have it any more (refund).
			_grant(key, false)
	changed.emit()


func _on_purchase_done(id: String, status: String) -> void:
	var key := _key_of(id)
	if key == "":
		key = _busy
	_busy = ""
	match status:
		"owned":
			_pending.erase(key)
			_grant(key, true)
		"pending":
			_pending[key] = true
	changed.emit()
	purchase_finished.emit(key, status)


func _grant(key: String, on: bool) -> void:
	if save == null or owns(key) == on:
		return
	match key:
		"remove_ads":
			save.data.ads.removed = on
	if save.has_method("save_game"):
		save.save_game()

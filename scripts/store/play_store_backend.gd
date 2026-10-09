extends StoreBackend
## StoreBackend on GodotGooglePlayBilling (addons/GodotGooglePlayBilling,
## Play Billing Library 8). One-time products only. Every PURCHASED product
## is acknowledged (Play refunds unacknowledged ones after 3 days).
## Loaded only where the native plugin exists (Store._make_backend).

const OK_CODE := BillingClient.BillingResponseCode.OK

var _client: BillingClient
var _ids: Array = []
var _buying := ""
var _retry := 0


func setup(store_ids: Array) -> void:
	_ids = store_ids
	_client = BillingClient.new()
	add_child(_client)
	_client.connected.connect(_on_connected)
	_client.disconnected.connect(_on_disconnected)
	_client.connect_error.connect(_on_connect_error)
	_client.query_product_details_response.connect(_on_details)
	_client.query_purchases_response.connect(_on_purchases)
	_client.on_purchase_updated.connect(_on_purchase_updated)
	_client.acknowledge_purchase_response.connect(_on_acknowledged)
	_client.start_connection()


func buy(store_id: String) -> void:
	if not is_ready:
		purchase_done.emit.call_deferred(store_id, "failed")
		return
	_buying = store_id
	var r: Dictionary = _client.purchase(store_id)
	if int(r.get("response_code", -1)) != OK_CODE:
		push_warning("Store: purchase flow didn't start (%s)" % r.get("debug_message", ""))
		_buying = ""
		purchase_done.emit.call_deferred(store_id, "failed")


func restore() -> void:
	if is_ready:
		_client.query_purchases(BillingClient.ProductType.INAPP)


func _on_connected() -> void:
	is_ready = true
	_retry = 0
	_client.query_product_details(PackedStringArray(_ids), BillingClient.ProductType.INAPP)
	restore()


func _on_disconnected() -> void:
	is_ready = false
	_reconnect_later()


func _on_connect_error(code: int, message: String) -> void:
	push_warning("Store: billing connect error %d (%s)" % [code, message])
	is_ready = false
	_reconnect_later()


func _reconnect_later() -> void:
	_retry += 1
	get_tree().create_timer(minf(2.0 * pow(2.0, _retry - 1), 120.0), true).timeout.connect(func() -> void:
		if not is_ready:
			_client.start_connection())


func _on_details(r: Dictionary) -> void:
	if int(r.get("response_code", -1)) != OK_CODE:
		push_warning("Store: product details failed (%s)" % r.get("debug_message", ""))
		return
	var prices := {}
	for d: Dictionary in r.get("product_details", []):
		var offers = d.get("one_time_purchase_offer_details_list")
		if offers is Array and not offers.is_empty():
			var o: Dictionary = offers[0]
			prices[d.product_id] = "%s %.2f" % [o.price_currency_code, float(o.price_amount_micros) / 1000000.0]
	prices_changed.emit(prices)


func _on_purchases(r: Dictionary) -> void:
	if int(r.get("response_code", -1)) != OK_CODE:
		push_warning("Store: purchase query failed (%s)" % r.get("debug_message", ""))
		return
	var owned := []
	for p: Dictionary in r.get("purchases", []):
		if int(p.purchase_state) == BillingClient.PurchaseState.PURCHASED:
			_acknowledge(p)
			owned.append_array(Array(p.product_ids))
	owned_changed.emit(owned, true)


func _on_purchase_updated(r: Dictionary) -> void:
	var code := int(r.get("response_code", -1))
	var id := _buying
	_buying = ""
	match code:
		OK_CODE:
			for p: Dictionary in r.get("purchases", []):
				for pid: String in p.product_ids:
					match int(p.purchase_state):
						BillingClient.PurchaseState.PURCHASED:
							_acknowledge(p)
							purchase_done.emit(pid, "owned")
						BillingClient.PurchaseState.PENDING:
							purchase_done.emit(pid, "pending")
		BillingClient.BillingResponseCode.USER_CANCELED:
			purchase_done.emit(id, "canceled")
		BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED:
			restore()
		_:
			push_warning("Store: purchase failed %d (%s)" % [code, r.get("debug_message", "")])
			purchase_done.emit(id, "failed")


func _acknowledge(p: Dictionary) -> void:
	if not bool(p.get("is_acknowledged", false)):
		_client.acknowledge_purchase(p.purchase_token)


func _on_acknowledged(r: Dictionary) -> void:
	if int(r.get("response_code", -1)) != OK_CODE:
		# Not fatal: the next restore() acknowledges it again.
		push_warning("Store: acknowledge failed (%s)" % r.get("debug_message", ""))

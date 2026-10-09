class_name StoreBackend
extends Node
## What the Store service needs from a billing SDK. Implementations:
## PlayStoreBackend (GodotGooglePlayBilling, Android) and FakeStoreBackend
## (desktop, editor, tests). Product ids here are the store's ids.

## Prices became known: store id -> display text ("USD 1.99", ASCII only so
## the pixel font can draw it).
signal prices_changed(prices: Dictionary)
## What the account owns. complete: true when this is the store's full,
## authoritative list (a refunded product is missing from it).
signal owned_changed(store_ids: Array, complete: bool)
## A purchase flow ended: "owned", "pending", "canceled" or "failed".
signal purchase_done(store_id: String, status: String)

## Connected and able to sell.
var is_ready := false


func setup(_store_ids: Array) -> void:
	pass


func buy(_store_id: String) -> void:
	pass


## Asks the store for everything the account owns (emits owned_changed).
func restore() -> void:
	pass

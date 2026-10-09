class_name ShopScreen
extends MenuScreen
## The permanent coin shop (data/shop/): level-up actions (Reroll, Skip,
## Banish: charges per run), the Toggler (how much content it can switch
## off) and small permanent stat upgrades. Entries with "needs" stay locked
## until enough runs are played or unlocks are bought.
## On top: the real-money products (Store, data/rules/store.json): Remove Ads.

var _store: Node
var _notice := {}  # product key -> "FAILED, TRY AGAIN" etc. after a purchase flow


func _init(save_node: Node) -> void:
	super(save_node, "SHOP")


func _ready() -> void:
	_store = get_node_or_null("/root/Store")
	if _store != null:
		_store.changed.connect(refresh)
		_store.purchase_finished.connect(_on_purchase_finished)
	super._ready()


func _fill() -> void:
	if _store != null and not _store.products().is_empty():
		heading("IN-APP PURCHASES")
		for key: String in _store.products():
			_product_row(key)
	var groups := [["action", "LEVEL-UP ACTIONS"], ["toggler", "TOGGLER"], ["stat", "UPGRADES"]]
	for g: Array in groups:
		var entries := db.all("shop").filter(func(e: Dictionary) -> bool: return e.kind == g[0])
		if entries.is_empty():
			continue
		heading(g[1])
		for e: Dictionary in entries:
			_entry_row(e)


func _entry_row(e: Dictionary) -> void:
	var data: Dictionary = save.data
	var lvl := Meta.shop_level(data, e.id)
	var top: int = e.prices.size()
	var r := row(40)
	label(r, "%s  %d/%d" % [e.name, lvl, top], Vector2(6, 4), Palette.BUTTER if lvl > 0 else Palette.PAPER)
	label(r, e.desc, Vector2(6, 14), Palette.MIST)
	var note := ""
	if e.kind in ["action", "toggler"] and lvl > 0:
		note = ("%d PER RUN" if e.kind == "action" else "%d OFF AT ONCE") % int(e.charges[lvl - 1])
	label(r, note, Vector2(6, 26), Palette.LIME)
	var price := Meta.shop_price(data, e)
	if not Meta.shop_open(data, e):
		var needs: Dictionary = e.needs
		var why := ""
		if needs.has("runs") and int(data.runs_played) < int(needs.runs):
			why = "AFTER %d RUNS" % int(needs.runs)
		else:
			why = "AFTER %d UNLOCKS" % int(needs.unlocks)
		label(r, why, Vector2(W - 100, 26), Palette.SALMON, HORIZONTAL_ALIGNMENT_RIGHT, 94)
	elif price < 0:
		label(r, "MAX", Vector2(W - 40, 26), Palette.LIME, HORIZONTAL_ALIGNMENT_RIGHT, 34)
	else:
		var can := int(data.coins) >= price
		button(r, "C %d" % price, Rect2(W - 52, 23, 48, 14), Palette.LIME if can else Palette.GRAY, _buy.bind(e.id), can)


## A real-money product: name, what it does, and the store price or its state.
func _product_row(key: String) -> void:
	var p: Dictionary = _store.products()[key]
	var st: String = _store.state(key)
	var r := row(40)
	label(r, p.get("name", key), Vector2(6, 4), Palette.BUTTER if st == "owned" else Palette.PAPER)
	label(r, p.get("desc", ""), Vector2(6, 14), Palette.MIST)
	match st:
		"owned":
			label(r, "OWNED", Vector2(W - 60, 26), Palette.LIME, HORIZONTAL_ALIGNMENT_RIGHT, 54)
		"buyable":
			label(r, _notice.get(key, ""), Vector2(6, 26), Palette.SALMON)
			button(r, _store.price_text(key), Rect2(W - 62, 23, 58, 14), Palette.LIME, _buy_product.bind(key))
		"busy":
			label(r, "WAIT...", Vector2(W - 60, 26), Palette.MIST, HORIZONTAL_ALIGNMENT_RIGHT, 54)
		"pending":
			label(r, "PAYMENT PENDING", Vector2(W - 110, 26), Palette.SALMON, HORIZONTAL_ALIGNMENT_RIGHT, 104)
		_:
			label(r, "STORE OFFLINE", Vector2(W - 110, 26), Palette.GRAY, HORIZONTAL_ALIGNMENT_RIGHT, 104)


func _buy_product(key: String) -> void:
	_store.buy(key)


func _on_purchase_finished(key: String, status: String) -> void:
	_notice[key] = {"failed": "FAILED, TRY AGAIN", "canceled": "CANCELED"}.get(status, "")
	refresh()


func _buy(id: String) -> void:
	if Meta.buy_shop(db, save.data, id):
		save.save_game()
		refresh()

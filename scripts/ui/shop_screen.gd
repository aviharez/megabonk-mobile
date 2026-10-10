class_name ShopScreen
extends MenuScreen
## The permanent coin shop (data/shop/) as a grid of icon tiles with level
## pips, grouped (LEVEL-UP ACTIONS, UPGRADES, TOGGLER), and a fixed detail
## panel on top for the selected entry: icon, name, what it does, what the
## current level gives, and the price button (or MAX / why it's locked).
## Entries with "needs" stay locked until enough runs are played or unlocks
## are bought. Each entry's tile picture is its "icon" in data.
## Above the grid: the real-money products (Store, data/rules/store.json):
## Remove Ads, as a purple banner with its store price.

const COLUMNS := 4
const PANEL_H := 64

var selected := ""
var _store: Node
var _notice := {}  # product key -> "FAILED, TRY AGAIN" etc. after a purchase flow


func _init(save_node: Node) -> void:
	super(save_node, "SHOP")
	# Start on the cheapest thing you can buy now, else the first entry.
	var best := INF
	for e: Dictionary in db.all("shop"):
		var price := Meta.shop_price(save.data, e)
		if selected == "":
			selected = e.id
		if Meta.shop_open(save.data, e) and price >= 0 and price <= int(save.data.coins) and price < best:
			best = price
			selected = e.id


func _ready() -> void:
	_store = get_node_or_null("/root/Store")
	if _store != null:
		_store.changed.connect(refresh)
		_store.purchase_finished.connect(_on_purchase_finished)
	super._ready()


func _fill() -> void:
	_panel()
	if _store != null and not _store.products().is_empty():
		for key: String in _store.products():
			_product_row(key)
	var groups := [["action", "LEVEL-UP ACTIONS", Palette.SKY], ["stat", "UPGRADES", Palette.LIME], ["toggler", "TOGGLER", Palette.PURPLE]]
	for g: Array in groups:
		var entries := db.all("shop").filter(func(e: Dictionary) -> bool: return e.kind == g[0])
		if entries.is_empty():
			continue
		heading(g[1], g[2])
		var grid := GridContainer.new()
		grid.columns = COLUMNS
		grid.add_theme_constant_override("h_separation", (W - COLUMNS * IconTile.SIZE) / (COLUMNS - 1))
		grid.add_theme_constant_override("v_separation", 2)
		list.add_child(grid)
		for e: Dictionary in entries:
			grid.add_child(_tile(e))


func _tile(e: Dictionary) -> IconTile:
	var data: Dictionary = save.data
	var lvl := Meta.shop_level(data, e.id)
	var t := IconTile.new()
	t.name = e.id
	t.picture = Icons.ref(db, e.get("icon", ""))
	t.pips = lvl
	t.pips_max = e.prices.size()
	t.selected = e.id == selected
	var price := Meta.shop_price(data, e)
	if not Meta.shop_open(data, e):
		t.state = "locked"
		t.picture = _dark(t.picture)
	elif price < 0:
		t.state = "maxed"
		t.tag = "MAX"
	elif price <= int(data.coins):
		t.state = "available"
		t.tag = "!"
	else:
		t.state = "owned" if lvl > 0 else "locked_open"
	t.pressed.connect(select.bind(e.id))
	return t


## A UI sprite or icon as an INK silhouette (closed shop entries).
func _dark(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return tex
	img.convert(Image.FORMAT_RGBA8)
	return ImageTexture.create_from_image(Icons.silhouette(img))


func select(id: String) -> void:
	selected = id
	var keep := _scroll.scroll_vertical
	refresh()
	_scroll.set_deferred("scroll_vertical", keep)


func _panel() -> void:
	var p := top_panel(PANEL_H)
	for c in p.get_children():
		p.remove_child(c)
		c.queue_free()
	var e := db.get_entry("shop", selected)
	if e.is_empty():
		return
	var data: Dictionary = save.data
	var lvl := Meta.shop_level(data, e.id)
	var top: int = e.prices.size()
	var open := Meta.shop_open(data, e)
	var frame := IconTile.new()
	frame.picture = Icons.ref(db, e.get("icon", ""))
	frame.state = "owned" if lvl > 0 else ("locked" if not open else "locked_open")
	if not open:
		frame.picture = _dark(frame.picture)
	frame.pips = lvl
	frame.pips_max = top
	frame.disabled = true
	frame.mouse_filter = MOUSE_FILTER_IGNORE
	frame.position = Vector2(6, 6)
	p.add_child(frame)
	var x := 6 + IconTile.SIZE + 5
	var tw := W + 4 - x - 6
	bold_label(p, e.name, Vector2(x, 6), Palette.BUTTER if lvl > 0 else Palette.PAPER)
	label(p, "LV %d/%d" % [lvl, top], Vector2(x, 6), Palette.MIST, HORIZONTAL_ALIGNMENT_RIGHT, tw)
	var dl := label(p, e.desc, Vector2(x, 17), Palette.PAPER)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD
	dl.size = Vector2(tw, 20)
	dl.custom_minimum_size.x = tw
	var note := ""
	if e.kind in ["action", "toggler"]:
		var next_lvl := mini(lvl + 1, top)
		var per := "%d PER RUN" if e.kind == "action" else "%d OFF AT ONCE"
		note = ("NOW " + per % int(e.charges[lvl - 1])) if lvl > 0 else ("GET " + per % int(e.charges[next_lvl - 1]))
	label(p, note, Vector2(6, 48), Palette.LIME)
	var price := Meta.shop_price(data, e)
	var br := Rect2(W - 58, 38, 58, 22)
	if not open:
		var needs: Dictionary = e.needs
		var why := ""
		if needs.has("runs") and int(data.runs_played) < int(needs.runs):
			why = "AFTER %d RUNS" % int(needs.runs)
		else:
			why = "AFTER %d UNLOCKS" % int(needs.unlocks)
		label(p, why, Vector2(br.position.x - 40, 48), Palette.SALMON, HORIZONTAL_ALIGNMENT_RIGHT, br.size.x + 40)
	elif price < 0:
		bold_label(p, "MAX!", Vector2(br.position.x, 46), Palette.LIME, HORIZONTAL_ALIGNMENT_CENTER, br.size.x)
	else:
		var b := price_button(p, price, br, _buy.bind(e.id))
		b.name = "Buy"


## A real-money product: a purple banner with the store price or its state.
func _product_row(key: String) -> void:
	var pr: Dictionary = _store.products()[key]
	var st: String = _store.state(key)
	var r := row(40, Palette.PLUM)
	r.name = "Product_" + key
	bold_label(r, pr.get("name", key), Vector2(6, 5), Palette.BUTTER if st == "owned" else Palette.PAPER)
	var notice: String = _notice.get(key, "")
	var dl := label(r, notice if notice != "" else pr.get("desc", ""), Vector2(6, 16), Palette.SALMON if notice != "" else Palette.MIST)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD
	dl.custom_minimum_size.x = W - 74
	dl.size = Vector2(W - 74, 20)
	match st:
		"owned":
			bold_label(r, "OWNED", Vector2(W - 60, 15), Palette.LIME, HORIZONTAL_ALIGNMENT_RIGHT, 54)
		"buyable":
			button(r, _store.price_text(key), Rect2(W - 64, 9, 60, 22), Palette.LIME, _buy_product.bind(key))
		"busy":
			label(r, "WAIT...", Vector2(W - 60, 11), Palette.MIST, HORIZONTAL_ALIGNMENT_RIGHT, 54)
		"pending":
			label(r, "PENDING", Vector2(W - 60, 11), Palette.SALMON, HORIZONTAL_ALIGNMENT_RIGHT, 54)
		_:
			label(r, "OFFLINE", Vector2(W - 60, 11), Palette.GRAY, HORIZONTAL_ALIGNMENT_RIGHT, 54)


func _buy_product(key: String) -> void:
	_store.buy(key)


func _on_purchase_finished(key: String, status: String) -> void:
	_notice[key] = {"failed": "FAILED, TRY AGAIN", "canceled": "CANCELED"}.get(status, "")
	refresh()


func _buy(id: String) -> void:
	if Meta.buy_shop(db, save.data, id):
		save.save_game()
		select(id)
		UiFx.hop(_top_panel, 2.0)

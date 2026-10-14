class_name ShopScreen
extends MenuScreen
## The coin shop, kit v2 (docs/ui/shop.png), a tab of the bottom nav: tabs
## Upgrades (stat entries in data/shop/), Actions (level-up actions and the
## Switchboard) and Offers (real-money products, Store / data/rules/store.json);
## goods as a 3-column grid of GoodsCards (icon on a shelf, name, level pips,
## price button or Max). Entries with "needs" stay closed until enough runs
## are played or unlocks are bought. Under the Upgrades grid, and on Offers,
## the No Ads offer window (lamp price button with the store's price).

const COLUMNS := 3
const TABS := [["stat", "Upgrades"], ["actions", "Actions"], ["offers", "Offers"]]

var tab := 0
var selected := ""
var _store: Node
var _tabs: PixelTabs
var _notice := {}  # product key -> "Failed, try again." etc. after a purchase flow


func _init(save_node: Node) -> void:
	super(save_node, "Shop")


func _ready() -> void:
	_store = get_node_or_null("/root/Store")
	if _store != null:
		_store.changed.connect(refresh)
		_store.purchase_finished.connect(_on_purchase_finished)
	var p := top_panel(PixelTabs.H + 8)
	p.part = ""
	_tabs = PixelTabs.new()
	_tabs.name = "Tabs"
	_tabs.position = Vector2(2, 2)
	_tabs.size = Vector2(W, PixelTabs.H + 2)
	_tabs.tabs = TABS.map(func(t: Array) -> Dictionary: return {"name": t[1]})
	_tabs.picked.connect(func(i: int) -> void:
		tab = i
		refresh())
	p.add_child(_tabs)
	super._ready()


## Opens the Offers tab (Home's No Ads button).
func show_offers() -> void:
	tab = 2
	if _tabs != null:
		_tabs.current = 2
	refresh()


func _fill() -> void:
	var kind: String = TABS[tab][0]
	if kind == "offers":
		_offers()
		return
	var entries := db.all("shop").filter(func(e: Dictionary) -> bool:
		return e.kind == kind or (kind == "actions" and e.kind in ["action", "toggler"]))
	var grid := GridContainer.new()
	grid.name = "Goods"
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", floori((W - COLUMNS * GoodsCard.CARD.x) / (COLUMNS - 1)))
	grid.add_theme_constant_override("v_separation", 4)
	list.add_child(grid)
	for e: Dictionary in entries:
		grid.add_child(_card(e))
	if kind == "stat":
		_offers()


func _card(e: Dictionary) -> GoodsCard:
	var data: Dictionary = save.data
	var lvl := Meta.shop_level(data, e.id)
	var c := GoodsCard.new()
	c.name = e.id
	c.title = e.name
	c.picture = Icons.ref(db, e.get("icon", ""))
	c.pips = lvl
	c.pips_max = e.prices.size()
	c.price = Meta.shop_price(data, e)
	c.affordable = c.price >= 0 and c.price <= int(data.coins)
	c.selected = e.id == selected
	if not Meta.shop_open(data, e):
		c.state = "locked"
		c.picture = _dark(c.picture)
		var needs: Dictionary = e.needs
		if needs.has("runs") and int(data.runs_played) < int(needs.runs):
			c.why = "%d runs" % int(needs.runs)
		else:
			c.why = "%d unlocks" % int(needs.get("unlocks", 0))
	elif c.price < 0:
		c.state = "maxed"
	else:
		c.state = "available" if c.affordable else ("owned" if lvl > 0 else "locked_open")
	c.pressed.connect(select.bind(e.id))
	c.buy.connect(_buy.bind(e.id))
	return c


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


func _offers() -> void:
	if _store == null:
		return
	for key: String in _store.products():
		_product(key)


## A real-money product: a window with the "Offer" sticker, its icon in a
## slot, name, one line, and the lamp price button (or its state).
func _product(key: String) -> void:
	var pr: Dictionary = _store.products()[key]
	var st: String = _store.state(key)
	var h := 70
	var holder := Control.new()
	holder.name = "Product_" + key
	holder.custom_minimum_size = Vector2(W, h + 8)
	list.add_child(holder)
	var win := PixelPanel.new()
	win.part = "window"
	win.position = Vector2(0, 6)
	win.size = Vector2(W, h)
	holder.add_child(win)
	var notice: String = _notice.get(key, "")
	var tag := Control.new()
	tag.mouse_filter = MOUSE_FILTER_IGNORE
	tag.draw.connect(func() -> void: UiArt.sticker(tag, "Offer", Vector2(9, 0), -1, 11, 3))
	holder.add_child.call_deferred(tag)
	var slot := Control.new()
	slot.position = Vector2(9, 13)
	slot.size = Vector2(37, 38)
	slot.mouse_filter = MOUSE_FILTER_IGNORE
	slot.draw.connect(func() -> void:
		UiArt.slot(slot, Rect2(Vector2.ZERO, slot.size))
		var tex := UiArt.texture("kit/no_ads")
		slot.draw_texture(tex, ((slot.size - tex.get_size()) / 2.0).floor()))
	win.add_child(slot)
	var name_l := Fonts.label(pr.get("name", key), "NAME", Palette.BUTTER if st == "owned" else -1)
	name_l.position = Vector2(53, 9)
	win.add_child(name_l)
	var dl := Fonts.label(notice if notice != "" else pr.get("desc", ""), "BODY", Palette.SALMON if notice != "" else Palette.MUTED)
	dl.position = Vector2(53, 21)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.size = Vector2(W - 62, 18)
	dl.custom_minimum_size.x = W - 62
	win.add_child(dl)
	var at := Rect2(53, 41, 46, 20)
	match st:
		"owned":
			win.add_child(_note("Owned", at, Palette.LIME))
		"buyable":
			var b := button(win, _store.price_text(key), Rect2(at.position, at.size + Vector2(0, PixelButton.SHADOW)), Palette.GOLD, _buy_product.bind(key))
			b.name = "BuyProduct"
		"busy":
			win.add_child(_note("Wait...", at, Palette.MUTED))
		"pending":
			win.add_child(_note("Pending", at, Palette.SALMON))
		_:
			win.add_child(_note("Offline", at, Palette.MUTED))


func _note(text: String, at: Rect2, color: int) -> Label:
	var l := Fonts.label(text, "NAME", color)
	l.position = Vector2(at.position.x, at.position.y + 4)
	return l


func _buy_product(key: String) -> void:
	_store.buy(key)


func _on_purchase_finished(key: String, status: String) -> void:
	_notice[key] = {"failed": "Failed, try again.", "canceled": "Canceled."}.get(status, "")
	refresh()


func _buy(id: String) -> void:
	if Meta.buy_shop(db, save.data, id):
		save.save_game()
		select(id)
		var c := list.find_child(id, true, false)
		if c != null:
			UiFx.hop(c, 2.0)

class_name UnlocksScreen
extends MenuScreen
## Every unlock challenge with its reward, in tier order. Locked rewards are
## silhouettes ("??? ITEM") with the challenge and its progress; available
## ones show their name, price, a NEW badge and a BUY button; owned ones say
## OWNED. Opening the screen marks the NEW badges as seen.

var _new := {}  # content ids that were unseen when the screen opened


func _init(save_node: Node) -> void:
	super(save_node, "UNLOCKS")
	for id: String in Meta.ready_to_buy(db, save.data):
		if not save.data.seen.has(id):
			_new[id] = true
	Meta.mark_seen(db, save.data)
	save.save_game()


func _fill() -> void:
	var tier := ""
	for ch: Dictionary in Meta.challenges(db):
		if ch.tier != tier:
			tier = ch.tier
			heading(tier.to_upper())
		_challenge_row(ch)


func _challenge_row(ch: Dictionary) -> void:
	var id: String = ch.reward
	var st := Meta.state(db, save.data, id)
	var def := Meta.content(db, id)
	var r := row(48, Palette.DEEP_BLUE if st == "locked" else Palette.OCEAN)
	r.add_child(ContentIcon.new(Meta.category_of(db, id), st == "locked"))
	r.get_child(0).position = Vector2(4, 4)
	var name_text: String = def.name if st != "locked" else "??? " + Meta.kind_name(db, id)
	label(r, name_text, Vector2(22, 6), Palette.PAPER if st != "locked" else Palette.MIST)
	var p := Meta.progress(db, save.data, ch)
	var cr := ChallengeRow.new().setup(ch, p, "")
	cr.position = Vector2(6, 20)
	cr.size = Vector2(W - 12, ChallengeRow.HEIGHT)
	r.add_child(cr)
	match st:
		"owned":
			cr.reward = "OWNED"
			cr.reward_color = Palette.LIME
		"available":
			var price := int(ch.price)
			var can := int(save.data.coins) >= price
			button(r, "BUY C %d" % price, Rect2(W - 62, 3, 58, 14), Palette.LIME if can else Palette.GRAY, _buy.bind(id), can)
			if _new.has(id):
				cr.reward = "NEW!"
				cr.reward_color = Palette.LIME
			else:
				cr.reward = "READY TO BUY"
				cr.reward_color = Palette.BUTTER
		"locked":
			if p.blocked:
				cr.reward = "NEEDS " + String(Meta.content(db, ch.requires).name)
				cr.reward_color = Palette.SALMON
			else:
				cr.reward = "C %d" % int(ch.price)
				cr.reward_color = Palette.GOLD


func _buy(id: String) -> void:
	if Meta.buy(db, save.data, id):
		save.save_game()
		refresh()

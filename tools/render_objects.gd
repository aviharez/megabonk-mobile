extends SceneTree
## Renders the in-run object art in the real window (540x960: world 2x) for
## review: every map object around the player, the three XP gem tiers among
## a few enemies, every weapon firing, and both enemy shots. Saves a few
## frames so the swing, shots and gnomes are caught mid-flight. Needs a
## window (not --headless):
##   godot --path . -s res://tools/render_objects.gd -- [--out=user://objects]

const OBJECTS := ["paid_chest", "elite_chest", "boss_chest", "pot", "charge_shrine", "risk_shrine",
	"challenge_shrine", "pigeon_cage", "cage_key", "portal", "merchant"]


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	var out: String = args.get("out", "user://objects")
	DirAccess.make_dir_recursive_absolute(out)
	Run.next_options = {"no_spawns": true, "no_save": true, "invincible": true, "seed": 3,
		"character": "sir_loaf", "loadout": {"weapons": {"sharp_feathers": 1, "stapler": 1,
		"rubber_duck": 1, "hot_coffee": 1, "fireworks": 1, "garden_gnomes": 1}}}
	var run: Run = load("res://scenes/run.tscn").instantiate()
	root.add_child(run)
	for i in 3:
		await process_frame
	var c := run.player_pos()
	# Map objects on two rows above and below the player.
	for i in OBJECTS.size():
		var row := 0 if i < 6 else 1
		var col := i if row == 0 else i - 6
		var at := c + Vector2(-100 + col * 40, -150 if row == 0 else 130)
		run.interactables.add(OBJECTS[i], at)
	# Gems: a row of each tier, out of pickup range.
	for k in 3:
		for j in 6:
			run.gems.drop(c + Vector2(-110 + j * 16, -90 + k * 16), [1.0, 5.0, 20.0][k])
	# Some enemies to aim at, and to see the gems among.
	for i in 8:
		run.spawn_enemy(["blob", "skitter", "chomper", "spitter"][i % 4], c + Vector2(40 + (i % 4) * 22, -100 + (i / 4) * 30))
	var frame := 0
	for t in 40:
		await process_frame
		if t % 6 == 0:
			# Enemy shots drifting past on the right.
			run.enemy_shots.fire(c + Vector2(60, 40 + (t % 12) * 3), Vector2(10, 0), 0.0, 2.0, 3.0, "res://assets/shots/enemy/bullet.png", "spitter")
			run.enemy_shots.fire(c + Vector2(60, 80 + (t % 12) * 3), Vector2(10, 0), 0.0, 3.0, 3.0, "res://assets/shots/enemy/rock.png", "mega_mole")
		if t >= 22 and t % 6 == 4:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("%s/objects_%d.png" % [out, frame])
			frame += 1
	print("render_objects: saved %d frames to %s" % [frame, ProjectSettings.globalize_path(out)])
	quit()

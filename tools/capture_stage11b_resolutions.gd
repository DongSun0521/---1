extends SceneTree

var failed: bool = false


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var game_state = root.get_node("/root/GameState")
	for viewport_size: Vector2i in [Vector2i(1920, 1080), Vector2i(1600, 900), Vector2i(1280, 720)]:
		root.size = viewport_size
		game_state.start_new_game()
		game_state.start_battle(&"forest_slime_pair")
		var battle_view = load("res://features/battle/battle_view.tscn").instantiate()
		root.add_child(battle_view)
		await process_frame
		await process_frame
		battle_view.play_presentation_event({
			"action_type": &"attack",
			"source_id": &"hunter",
			"target_ids": [&"forest_slime_01"],
			"damage_values": [5],
			"healing_values": [],
			"defeated_ids": [],
		})
		await create_timer(0.72).timeout
		var image := root.get_texture().get_image()
		var output := "user://stage11b_%dx%d.png" % [viewport_size.x, viewport_size.y]
		var error := image.save_png(output)
		if error != OK or image.is_empty():
			failed = true
			push_error("Failed to capture 11B resolution %s" % viewport_size)
		else:
			print("Captured ", ProjectSettings.globalize_path(output), " size=", image.get_size())
		await create_timer(0.8).timeout
		battle_view.play_presentation_event({
			"action_type": &"medicine",
			"source_id": &"hunter",
			"target_ids": [&"guard"],
			"damage_values": [],
			"healing_values": [5],
			"defeated_ids": [],
		})
		await create_timer(0.25).timeout
		image = root.get_texture().get_image()
		output = "user://stage11b_heal_%dx%d.png" % [viewport_size.x, viewport_size.y]
		error = image.save_png(output)
		if error != OK or image.is_empty():
			failed = true
			push_error("Failed to capture 11B heal resolution %s" % viewport_size)
		else:
			print("Captured ", ProjectSettings.globalize_path(output), " size=", image.get_size())
		await create_timer(0.65).timeout
		battle_view.effect_player.clear_all_effects()
		battle_view.queue_free()
		await process_frame
	if failed:
		quit(1)
		return
	print("stage11b resolution capture ok")
	quit()

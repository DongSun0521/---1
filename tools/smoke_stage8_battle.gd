extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var game_state = root.get_node("/root/GameState")
	var battle_view: Node = load("res://features/battle/battle_view.tscn").instantiate()
	root.add_child(battle_view)
	await process_frame

	game_state.start_new_game()
	await run_encounter_smoke(battle_view, &"forest_slime_pair")
	game_state.start_new_game()
	await run_encounter_smoke(battle_view, &"ruins_guard")

	print("stage8 battle smoke ok")
	quit()


func run_encounter_smoke(battle_view: Node, encounter_id: StringName) -> void:
	var game_state = root.get_node("/root/GameState")
	game_state.start_battle(encounter_id)
	await process_frame
	await process_frame

	var active_unit: Dictionary = game_state.get_active_battle_unit()
	if active_unit.is_empty():
		push_error("No active unit after battle start: %s" % String(encounter_id))
		quit(1)
		return

	var enemies: Array = game_state.get_battle_enemy_states()
	if enemies.is_empty():
		push_error("No enemies after battle start: %s" % String(encounter_id))
		quit(1)
		return

	if bool(active_unit.get("is_player_unit", false)):
		battle_view.start_action(&"basic_attack", enemies[0]["unit_id"])
		await create_timer(1.4).timeout

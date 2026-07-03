extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var game_state = root.get_node("/root/GameState")
	game_state.start_new_game()

	assert_new_game_state(game_state)
	assert_expedition_ration_recipe(game_state)
	assert_hearty_stew_recipe(game_state)
	assert_hunter_roast_recipe(game_state)
	assert_recipe_guards(game_state)
	assert_expedition_rations(game_state)
	assert_expedition_food_workshop_progress(game_state)
	assert_hearty_stew_effect(game_state)
	assert_hunter_roast_effect(game_state)
	assert_expedition_failure_loses_rations(game_state)
	assert_new_game_reset(game_state)
	assert_twenty_day_loop(game_state)

	print("stage10c food workshop smoke ok")
	quit()


func assert_new_game_state(game_state) -> void:
	require(game_state.get_resource_amount("food") == 20, "new game should keep initial food")
	require(game_state.get_item_count(&"expedition_ration") == 6, "new game should start with 6 expedition rations")
	require(game_state.get_item_count(&"hearty_stew") == 0, "new game should start with 0 hearty stew")
	require(game_state.get_item_count(&"hunter_roast") == 0, "new game should start with 0 hunter roast")
	require(not bool(game_state.get_food_production_state().get("is_active", true)), "food workshop should start idle")
	require(game_state.get_active_expedition_meal() == &"", "new game should have no active meal")


func assert_expedition_ration_recipe(game_state) -> void:
	game_state.start_new_game()
	var food_before: int = game_state.get_resource_amount("food")
	var ration_before: int = game_state.get_item_count(&"expedition_ration")
	require(game_state.start_food_recipe(&"expedition_ration_recipe"), "ration recipe should start")
	require(game_state.get_resource_amount("food") == food_before - 3, "ration recipe should spend food immediately")
	require(game_state.get_item_count(&"expedition_ration") == ration_before, "ration output should not be granted immediately")
	require(int(game_state.get_food_production_state()["progress_days"]) == 0, "ration progress should start at 0")
	var report: Dictionary = game_state.advance_day("ration_day")
	require(game_state.get_item_count(&"expedition_ration") == ration_before + 3, "ration recipe should output +3 after 1 day")
	require(not bool(game_state.get_food_production_state().get("is_active", false)), "food workshop should idle after ration completion")
	require(bool(report.get("food_workshop_report", {}).get("food_workshop_completed", false)), "daily report should record ration completion")
	game_state.advance_day("no_duplicate")
	require(game_state.get_item_count(&"expedition_ration") == ration_before + 3, "completed ration should only grant output once")


func assert_hearty_stew_recipe(game_state) -> void:
	game_state.start_new_game()
	var food_before: int = game_state.get_resource_amount("food")
	require(game_state.start_food_recipe(&"hearty_stew_recipe"), "hearty stew recipe should start")
	require(game_state.get_resource_amount("food") == food_before - 4, "stew should spend food immediately")
	game_state.advance_day("stew_1")
	require(game_state.get_item_count(&"hearty_stew") == 0, "stew should not output after 1 day")
	require(int(game_state.get_food_production_state()["progress_days"]) == 1, "stew should progress to 1/2")
	game_state.advance_day("stew_2")
	require(game_state.get_item_count(&"hearty_stew") == 1, "stew should output after 2 days")


func assert_hunter_roast_recipe(game_state) -> void:
	game_state.start_new_game()
	var food_before: int = game_state.get_resource_amount("food")
	require(game_state.start_food_recipe(&"hunter_roast_recipe"), "hunter roast recipe should start")
	require(game_state.get_resource_amount("food") == food_before - 4, "roast should spend food immediately")
	game_state.advance_day("roast_1")
	require(game_state.get_item_count(&"hunter_roast") == 0, "roast should not output after 1 day")
	game_state.advance_day("roast_2")
	require(game_state.get_item_count(&"hunter_roast") == 1, "roast should output after 2 days")


func assert_recipe_guards(game_state) -> void:
	game_state.start_new_game()
	game_state.resources["food"] = 2
	require(not game_state.can_start_food_recipe(&"expedition_ration_recipe"), "ration recipe should be blocked when food is low")
	require(not game_state.start_food_recipe(&"expedition_ration_recipe"), "blocked ration recipe should not start")
	require(game_state.get_resource_amount("food") == 2, "blocked recipe should not spend food")
	game_state.resources["food"] = 20
	require(game_state.start_food_recipe(&"hearty_stew_recipe"), "first recipe should start")
	require(not game_state.start_food_recipe(&"hunter_roast_recipe"), "busy workshop should block second recipe")
	require(int(game_state.get_food_production_state()["progress_days"]) == 0, "busy block should not reset progress")


func assert_expedition_rations(game_state) -> void:
	game_state.start_new_game()
	var food_before: int = game_state.get_resource_amount("food")
	require(game_state.start_expedition(4, 0), "expedition should start with 4 rations")
	require(game_state.get_item_count(&"expedition_ration") == 2, "village rations should be deducted on departure")
	require(game_state.get_resource_amount("food") == food_before, "departure should not spend village food")
	require(int(game_state.get_expedition_state()["carried_rations"]) == 4, "expedition backpack should carry 4 rations")
	require(game_state.move_to_next_expedition_node(), "move should consume one day ration")
	require(int(game_state.get_expedition_state()["carried_rations"]) == 3, "one day action should consume 1 ration")
	game_state.battle_state = game_state.battle_system.create_initial_state()
	require(int(game_state.get_expedition_state()["carried_rations"]) == 3, "clearing battle state should not consume ration")
	require(game_state.return_from_expedition(), "return should succeed")
	require(game_state.get_item_count(&"expedition_ration") == 5, "remaining rations should return to village")
	require(game_state.get_resource_amount("food") == food_before - 2, "only village daily food consumption should affect food")


func assert_expedition_food_workshop_progress(game_state) -> void:
	game_state.start_new_game()
	require(game_state.start_food_recipe(&"hearty_stew_recipe"), "stew should start before expedition")
	require(game_state.start_expedition(2, 0), "expedition should start")
	require(game_state.move_to_next_expedition_node(), "first expedition day should progress workshop")
	game_state.battle_state = game_state.battle_system.create_initial_state()
	var state: Dictionary = game_state.expedition_state
	var cleared_nodes: Array = state.get("cleared_battle_node_ids", [])
	cleared_nodes.append(&"forest_edge")
	state["cleared_battle_node_ids"] = cleared_nodes
	game_state.expedition_state = state
	require(game_state.move_to_next_expedition_node(), "second expedition day should progress workshop")
	require(game_state.get_item_count(&"hearty_stew") == 1, "stew should complete into village warehouse during expedition")
	require(int(game_state.get_expedition_state().get("carried_rations", 0)) == 0, "completed meal should not join current expedition")


func assert_hearty_stew_effect(game_state) -> void:
	game_state.start_new_game()
	game_state.add_item(&"hearty_stew", 1)
	var character_id: StringName = game_state.get_character_ids()[0]
	var before_stats: Dictionary = game_state.get_final_combat_stats(character_id)
	var before_runtime: Dictionary = game_state.get_character_runtime_state(character_id)
	require(game_state.start_expedition(1, 0, &"hearty_stew"), "expedition should start with hearty stew")
	var after_stats: Dictionary = game_state.get_final_combat_stats(character_id)
	var after_runtime: Dictionary = game_state.get_character_runtime_state(character_id)
	require(game_state.get_item_count(&"hearty_stew") == 0, "hearty stew should be consumed on departure")
	require(game_state.get_active_expedition_meal() == &"hearty_stew", "active meal should be hearty stew")
	require(int(after_stats["max_hp"]) == int(before_stats["max_hp"]) + 4, "hearty stew should add max hp")
	require(int(after_runtime["current_hp"]) == int(before_runtime["current_hp"]) + 4, "hearty stew should add current hp")
	require(game_state.start_battle(&"forest_slime_pair"), "battle should start with meal bonus")
	require(int(game_state.get_battle_party_states()[0]["max_hp"]) == int(before_stats["max_hp"]) + 4, "battle should use meal max hp")
	game_state.battle_state = game_state.battle_system.create_initial_state()
	require(game_state.return_from_expedition(), "return should clear meal")
	require(game_state.get_active_expedition_meal() == &"", "meal should clear on return")
	require(int(game_state.get_final_combat_stats(character_id)["max_hp"]) == int(before_stats["max_hp"]), "max hp bonus should not persist")


func assert_hunter_roast_effect(game_state) -> void:
	game_state.start_new_game()
	game_state.add_item(&"hunter_roast", 1)
	var character_id: StringName = game_state.get_character_ids()[1]
	var before_stats: Dictionary = game_state.get_final_combat_stats(character_id)
	require(game_state.start_expedition(1, 0, &"hunter_roast"), "expedition should start with hunter roast")
	var after_stats: Dictionary = game_state.get_final_combat_stats(character_id)
	require(game_state.get_item_count(&"hunter_roast") == 0, "hunter roast should be consumed on departure")
	require(int(after_stats["attack"]) == int(before_stats["attack"]) + 1, "hunter roast should add attack")
	require(game_state.start_battle(&"forest_slime_pair"), "battle should start with attack meal")
	require(int(game_state.get_battle_party_states()[1]["attack"]) == int(before_stats["attack"]) + 1, "battle should use meal attack")
	game_state.battle_state = game_state.battle_system.create_initial_state()
	require(game_state.return_from_expedition(), "return should clear roast")
	require(int(game_state.get_final_combat_stats(character_id)["attack"]) == int(before_stats["attack"]), "attack bonus should not persist")


func assert_expedition_failure_loses_rations(game_state) -> void:
	game_state.start_new_game()
	require(game_state.start_expedition(4, 0), "failure test expedition should start")
	require(game_state.get_item_count(&"expedition_ration") == 2, "departure should deduct rations")
	var report: Dictionary = game_state.expedition_system.apply_battle_failure(game_state, {})
	require(not report.is_empty(), "failure report should be generated")
	require(game_state.get_item_count(&"expedition_ration") == 2, "failure should not return remaining rations")
	require(int(game_state.get_expedition_state()["carried_rations"]) == 0, "failure should clear backpack")


func assert_new_game_reset(game_state) -> void:
	game_state.start_new_game()
	game_state.add_item(&"hearty_stew", 2)
	game_state.start_food_recipe(&"hunter_roast_recipe")
	game_state.start_expedition(1, 0)
	game_state.start_new_game()
	assert_new_game_state(game_state)
	require(int(game_state.get_expedition_state()["carried_rations"]) == 0, "new game should clear expedition rations")


func assert_twenty_day_loop(game_state) -> void:
	game_state.start_new_game()
	var ration_makes := 0
	for day in range(20):
		if not bool(game_state.get_food_production_state().get("is_active", false)):
			if game_state.get_resource_amount("food") >= 3:
				require(game_state.start_food_recipe(&"expedition_ration_recipe"), "loop should start ration recipe when idle")
				ration_makes += 1
		game_state.advance_day("food_loop_%02d" % day)
	require(ration_makes > 0, "20 day loop should start at least one food recipe")
	require(game_state.get_item_count(&"expedition_ration") >= 6, "20 day loop should not lose rations")
	require(game_state.get_resource_amount("food") >= 0, "20 day loop should not make food negative")
	require(not bool(game_state.get_food_production_state().get("is_active", false)) or int(game_state.get_food_production_state().get("progress_days", 0)) >= 0, "loop should keep a valid food workshop state")


func require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

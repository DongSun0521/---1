extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var game_state = root.get_node("/root/GameState")
	require(load("res://features/village/village_view.gd") != null, "village view script should parse")
	require(load("res://features/expedition/expedition_view.gd") != null, "expedition view script should parse")

	assert_rest_day_daily_report(game_state)
	assert_farm_no_duplicate_output(game_state)
	assert_food_workshop_report(game_state)
	assert_hospital_report(game_state)
	assert_treatment_sync(game_state)
	assert_expedition_backend_messages(game_state)
	assert_readiness_soft_warnings(game_state)
	assert_treatment_blocks_departure(game_state)
	assert_zero_ration_blocks_day_action(game_state)
	assert_query_calls_do_not_settle(game_state)
	assert_normal_return_integration(game_state)
	assert_failure_return_integration(game_state)
	assert_boss_return_integration(game_state)
	assert_new_game_resets_logistics(game_state)
	assert_30_day_pressure(game_state)

	print("stage10e logistics smoke ok")
	quit()


func assert_rest_day_daily_report(game_state) -> void:
	game_state.start_new_game()
	var day_before: int = game_state.current_day
	var food_before: int = game_state.get_resource_amount("food")
	var report: Dictionary = game_state.advance_day("village_rest")
	require(game_state.current_day == day_before + 1, "rest day should advance exactly one day")
	require(report.has("daily_summary_lines"), "daily report should include structured summary lines")
	require(int(report.get("food_consumed", 0)) == 2, "village food consumption should process once")
	require(game_state.get_resource_amount("food") == food_before - 2, "resource change should match village consumption")
	require(not report.get("hospital_events", []).size() > 0, "idle hospital should not emit noisy report events")


func assert_farm_no_duplicate_output(game_state) -> void:
	game_state.start_new_game()
	var food_before: int = game_state.get_resource_amount("food")
	var report1: Dictionary = game_state.advance_day("farm_day_1")
	require(int(report1.get("farm_food_produced", 0)) == 0, "first wheat day should only grow")
	var report2: Dictionary = game_state.advance_day("farm_day_2")
	require(int(report2.get("farm_food_produced", 0)) == 9, "three wheat plots should produce 9 food")
	require(game_state.get_resource_amount("food") == food_before - 4 + 9, "farm output should not include old fixed +4 food")
	require(report2.get("farm_events", []).size() == 1, "wheat harvest should be merged into one event")


func assert_food_workshop_report(game_state) -> void:
	game_state.start_new_game()
	var rations_before: int = game_state.get_item_count(&"expedition_ration")
	require(game_state.start_food_recipe(&"expedition_ration_recipe"), "ration recipe should start")
	var report: Dictionary = game_state.advance_day("food_workshop")
	require(game_state.get_item_count(&"expedition_ration") == rations_before + 3, "ration recipe should output 3 rations")
	require(report.get("food_workshop_events", []).size() == 1, "food workshop completion should be structured")
	require(int(report.get("resource_changes", {}).get(&"expedition_ration", 0)) == 3, "resource changes should include ration output")


func assert_hospital_report(game_state) -> void:
	game_state.start_new_game()
	game_state.resources["herb"] = 2
	var medicine_before: int = game_state.get_resource_amount("medicine")
	require(game_state.start_medicine_production(), "medicine production should start")
	var report: Dictionary = game_state.advance_day("hospital_medicine")
	require(game_state.get_resource_amount("medicine") == medicine_before + 1, "hospital medicine should complete once")
	require(report.get("hospital_events", []).size() == 1, "hospital completion should be structured")
	require(int(report.get("resource_changes", {}).get(&"medicine", 0)) == 1, "resource changes should include medicine")
	var after: int = game_state.get_resource_amount("medicine")
	game_state.advance_day("hospital_no_duplicate")
	require(game_state.get_resource_amount("medicine") == after, "hospital project completion should not repeat")


func assert_treatment_sync(game_state) -> void:
	game_state.start_new_game()
	game_state.resources["herb"] = 1
	var character_id: StringName = game_state.get_character_ids()[0]
	game_state.hospital_system.set_character_injury_state(game_state, character_id, &"injured")
	require(game_state.start_treatment(character_id), "treatment should start")
	var report: Dictionary = game_state.advance_day("hospital_treatment")
	require(not game_state.is_character_injured(character_id), "treatment should clear injury")
	require(not game_state.is_character_being_treated(character_id), "treatment target should clear")
	require(bool(report.get("treatment_completed", false)), "daily report should mark treatment completed")


func assert_expedition_backend_messages(game_state) -> void:
	game_state.start_new_game()
	game_state.resources["herb"] = 2
	game_state.resources["ore"] = 4
	game_state.advance_day("prepare_farm")
	require(game_state.start_food_recipe(&"expedition_ration_recipe"), "food project should start before expedition")
	require(game_state.start_medicine_production(), "hospital project should start before expedition")
	require(game_state.start_forge_recipe(&"craft_iron_sword"), "forge project should start before expedition")
	game_state.forge_state.progress_days = max(0, int(game_state.forge_state.required_days) - 1)
	var medicine_before: int = game_state.get_resource_amount("medicine")
	var ration_before: int = game_state.get_item_count(&"expedition_ration")
	require(game_state.start_expedition(1, 0), "expedition should start with backend projects")
	require(game_state.move_to_next_expedition_node(), "expedition move should use unified day advance")
	var action_report: Dictionary = game_state.get_last_expedition_action_report()
	require(action_report.has("daily_summary_lines"), "expedition action should carry backend summary")
	require(game_state.get_resource_amount("medicine") == medicine_before + 1, "medicine completed behind the front should enter village")
	require(game_state.get_item_count(&"expedition_ration") == ration_before - 1 + 3, "ration output and expedition consumption should both apply")
	require(int(game_state.get_expedition_state().get("carried_medicine", 0)) == 0, "backend medicine should not enter expedition backpack")


func assert_readiness_soft_warnings(game_state) -> void:
	game_state.start_new_game()
	var character_id: StringName = game_state.get_character_ids()[1]
	game_state.hospital_system.set_character_injury_state(game_state, character_id, &"injured")
	require(game_state.start_food_recipe(&"hearty_stew_recipe"), "stew recipe should start for readiness warning")
	game_state.food_production_state.progress_days = max(0, int(game_state.food_production_state.required_days) - 1)
	var report: Dictionary = game_state.get_expedition_readiness_report(1, 0, &"")
	require(bool(report.get("can_depart", false)), "injured character should not hard-block departure")
	require(report.get("warnings", []).size() >= 3, "readiness should include injury, no medicine, and completing project warnings")


func assert_treatment_blocks_departure(game_state) -> void:
	game_state.start_new_game()
	game_state.resources["herb"] = 1
	var character_id: StringName = game_state.get_character_ids()[2]
	game_state.hospital_system.set_character_injury_state(game_state, character_id, &"injured")
	require(game_state.start_treatment(character_id), "treatment should start")
	var report: Dictionary = game_state.get_expedition_readiness_report(1, 0, &"")
	require(not bool(report.get("can_depart", true)), "treatment should hard-block departure")
	require(not game_state.start_expedition(1, 0), "start expedition should fail while treating")


func assert_zero_ration_blocks_day_action(game_state) -> void:
	game_state.start_new_game()
	require(game_state.start_expedition(1, 0), "single-ration expedition should start")
	game_state.advance_day("consume_last_ration")
	var day_before: int = game_state.current_day
	require(not game_state.move_to_next_expedition_node(), "zero carried ration should block another day action")
	require(game_state.current_day == day_before, "blocked day action should not advance time")
	require(game_state.return_from_expedition(), "return should remain allowed")


func assert_query_calls_do_not_settle(game_state) -> void:
	game_state.start_new_game()
	game_state.resources["herb"] = 2
	require(game_state.start_food_recipe(&"expedition_ration_recipe"), "food project should start")
	require(game_state.start_medicine_production(), "hospital project should start")
	var day_before: int = game_state.current_day
	var food_state: Dictionary = game_state.get_food_production_state()
	var hospital_state: Dictionary = game_state.get_hospital_project_state()
	for index in range(10):
		game_state.get_logistics_overview()
		game_state.get_expedition_readiness_report(1, 0, &"")
	require(game_state.current_day == day_before, "query calls should not advance time")
	require(game_state.get_food_production_state().get("progress_days", -1) == food_state.get("progress_days", -2), "query calls should not advance food workshop")
	require(game_state.get_hospital_project_state().get("progress_days", -1) == hospital_state.get("progress_days", -2), "query calls should not advance hospital")


func assert_normal_return_integration(game_state) -> void:
	game_state.start_new_game()
	var stock_before: int = game_state.get_item_count(&"expedition_ration")
	require(game_state.start_expedition(6, 0), "normal return expedition should start")
	for index in range(4):
		game_state.advance_day("expedition_return_%d" % index)
	require(game_state.return_from_expedition(), "normal return should succeed")
	require(game_state.get_item_count(&"expedition_ration") == stock_before - 4, "two remaining rations should be returned")
	require(StringName(game_state.get_active_expedition_meal()) == &"", "active meal should clear on return")
	require(game_state.get_last_expedition_report().get("character_injury_results", []).size() == 4, "normal return should include injury results")


func assert_failure_return_integration(game_state) -> void:
	game_state.start_new_game()
	require(game_state.start_expedition(2, 0), "failure expedition should start")
	game_state.process_battle_result({"outcome": "defeat"})
	require(bool(game_state.get_last_expedition_report().get("is_failure", false)), "failure report should be marked")
	for character_id: StringName in game_state.get_character_ids():
		require(game_state.is_character_injured(character_id), "failure should injure all characters")
	require(StringName(game_state.get_active_expedition_meal()) == &"", "active meal should clear on failure")


func assert_boss_return_integration(game_state) -> void:
	game_state.start_new_game()
	require(game_state.start_expedition(1, 0), "boss victory expedition should start")
	game_state.expedition_state["current_node_id"] = &"ruins_entrance"
	game_state.process_battle_result({"outcome": "victory", "node_id": &"ruins_entrance", "reward_ore": 0, "reward_herb": 0, "reward_core": 1, "is_boss": true})
	require(game_state.return_from_expedition(), "boss victory return should succeed")
	require(bool(game_state.boss_defeated), "boss should be marked defeated")
	require(game_state.get_resource_amount("boss_core") == 1, "boss core should be awarded once")
	var core_after: int = game_state.get_resource_amount("boss_core")
	require(not game_state.return_from_expedition(), "return should not run twice after boss victory")
	require(game_state.get_resource_amount("boss_core") == core_after, "boss reward should not duplicate")


func assert_new_game_resets_logistics(game_state) -> void:
	game_state.start_new_game()
	game_state.resources["herb"] = 3
	game_state.resources["ore"] = 4
	var character_id: StringName = game_state.get_character_ids()[0]
	game_state.hospital_system.set_character_injury_state(game_state, character_id, &"injured")
	game_state.start_treatment(character_id)
	game_state.start_food_recipe(&"expedition_ration_recipe")
	game_state.start_forge_recipe(&"craft_iron_sword")
	game_state.start_expedition(1, 0)
	game_state.advance_day("make_old_report")
	game_state.start_new_game()
	require(not bool(game_state.get_hospital_project_state().get("is_active", true)), "new game should clear hospital project")
	require(not bool(game_state.get_food_production_state().get("is_active", true)), "new game should clear food project")
	require(not bool(game_state.get_forge_state().get("is_active", true)), "new game should clear forge project")
	require(not game_state.is_expedition_active(), "new game should clear expedition")
	require(game_state.get_last_daily_report().is_empty(), "new game should clear old daily report")
	for party_id: StringName in game_state.get_character_ids():
		require(not game_state.is_character_injured(party_id), "new game should reset injuries")


func assert_30_day_pressure(game_state) -> void:
	game_state.start_new_game()
	game_state.resources["herb"] = 6
	game_state.resources["ore"] = 8
	for day in range(30):
		if day == 2:
			game_state.assign_farm_crop(1, &"herb", true)
		if day == 3 and not bool(game_state.get_food_production_state().get("is_active", false)):
			game_state.start_food_recipe(&"expedition_ration_recipe")
		if day == 5 and not game_state.is_hospital_busy() and game_state.get_resource_amount("herb") >= 2:
			game_state.start_medicine_production()
		if day == 6 and not bool(game_state.get_forge_state().get("is_active", false)):
			game_state.start_forge_recipe(&"craft_iron_sword")
		if day == 8 and not game_state.is_expedition_active() and game_state.get_item_count(&"expedition_ration") > 0:
			game_state.start_expedition(1, 0)
		elif day == 9 and game_state.is_expedition_active():
			game_state.move_to_next_expedition_node()
			if game_state.is_battle_active():
				game_state.process_battle_result({"outcome": "victory", "node_id": game_state.get_expedition_state().get("current_node_id", &""), "reward_ore": 0, "reward_herb": 0, "reward_core": 0})
			game_state.return_from_expedition()
		elif day == 12:
			var character_id: StringName = game_state.get_character_ids()[0]
			game_state.hospital_system.set_character_injury_state(game_state, character_id, &"injured")
			if not game_state.is_hospital_busy() and game_state.get_resource_amount("herb") >= 1:
				game_state.start_treatment(character_id)
			game_state.advance_day("pressure_%d" % day)
		else:
			game_state.advance_day("pressure_%d" % day)
		require(game_state.get_resource_amount("food") >= 0, "food should never be negative")
		require(game_state.get_resource_amount("herb") >= 0, "herb should never be negative")
		require(game_state.get_resource_amount("medicine") >= 0, "medicine should never be negative")
		require(game_state.get_item_count(&"expedition_ration") >= 0, "rations should never be negative")


func require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

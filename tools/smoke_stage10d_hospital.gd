extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var game_state = root.get_node("/root/GameState")
	game_state.start_new_game()

	assert_old_auto_medicine_stopped(game_state)
	assert_medicine_production(game_state)
	assert_medicine_resource_guard(game_state)
	assert_busy_slot(game_state)
	assert_normal_return_injuries(game_state)
	assert_failure_injuries(game_state)
	assert_injury_stats_and_no_stack(game_state)
	assert_treatment_flow(game_state)
	assert_hearty_stew_after_injury(game_state)
	assert_crafting_during_expedition(game_state)
	assert_new_game_reset(game_state)

	print("stage10d hospital smoke ok")
	quit()


func assert_old_auto_medicine_stopped(game_state) -> void:
	game_state.start_new_game()
	var before: int = game_state.get_resource_amount("medicine")
	for index in range(4):
		game_state.advance_day("no_auto_medicine_%d" % index)
	require(game_state.get_resource_amount("medicine") == before, "hospital should not auto-produce medicine without a project")
	require(not bool(game_state.get_hospital_project_state().get("is_active", false)), "hospital should remain idle without an active project")


func assert_medicine_production(game_state) -> void:
	game_state.start_new_game()
	game_state.resources["herb"] = 4
	var medicine_before: int = game_state.get_resource_amount("medicine")
	require(game_state.start_medicine_production(), "medicine production should start with herbs")
	require(game_state.get_resource_amount("herb") == 2, "medicine production should spend herbs immediately")
	require(game_state.get_resource_amount("medicine") == medicine_before, "medicine output should not be immediate")
	require(int(game_state.get_hospital_project_state().get("progress_days", -1)) == 0, "hospital project should start at 0 progress")
	var report: Dictionary = game_state.advance_day("medicine_project")
	require(game_state.get_resource_amount("medicine") == medicine_before + 1, "medicine production should output after one day")
	require(not bool(game_state.get_hospital_project_state().get("is_active", true)), "hospital should idle after medicine completion")
	require(int(report.get("medicine_produced", 0)) == 1, "daily report should include medicine output")
	game_state.advance_day("medicine_no_duplicate")
	require(game_state.get_resource_amount("medicine") == medicine_before + 1, "medicine production should only complete once")


func assert_medicine_resource_guard(game_state) -> void:
	game_state.start_new_game()
	game_state.resources["herb"] = 1
	var medicine_before: int = game_state.get_resource_amount("medicine")
	require(not game_state.can_start_medicine_production(), "medicine production should be blocked when herbs are low")
	require(not game_state.start_medicine_production(), "blocked medicine production should not start")
	require(game_state.get_resource_amount("herb") == 1, "blocked medicine production should not spend herbs")
	require(game_state.get_resource_amount("medicine") == medicine_before, "blocked medicine production should not create medicine")


func assert_busy_slot(game_state) -> void:
	game_state.start_new_game()
	game_state.resources["herb"] = 5
	var character_id: StringName = game_state.get_character_ids()[0]
	game_state.hospital_system.set_character_injury_state(game_state, character_id, &"injured")
	require(game_state.start_medicine_production(), "medicine production should start")
	require(not game_state.start_treatment(character_id), "treatment should be blocked while crafting")
	require(game_state.get_resource_amount("herb") == 3, "blocked treatment should not spend herbs")
	game_state.start_new_game()
	game_state.resources["herb"] = 5
	game_state.hospital_system.set_character_injury_state(game_state, character_id, &"injured")
	require(game_state.start_treatment(character_id), "treatment should start")
	require(not game_state.start_medicine_production(), "crafting should be blocked while treating")
	require(game_state.get_resource_amount("herb") == 4, "blocked crafting should not spend herbs")


func assert_normal_return_injuries(game_state) -> void:
	game_state.start_new_game()
	require(game_state.start_expedition(1, 0), "expedition should start for injury return test")
	var party: Array = game_state.adventurers.duplicate(true)
	party[0]["current_hp"] = int(floor(float(party[0]["max_hp"]) * 0.75))
	party[1]["current_hp"] = int(floor(float(party[1]["max_hp"]) * 0.5))
	party[2]["current_hp"] = int(floor(float(party[2]["max_hp"]) * 0.5)) + 1
	party[3]["current_hp"] = 0
	game_state.adventurers = party
	require(game_state.return_from_expedition(), "expedition should return")
	require(not game_state.is_character_injured(game_state.get_character_ids()[0]), "75 percent hp should stay healthy")
	require(game_state.is_character_injured(game_state.get_character_ids()[1]), "50 percent hp should become injured")
	require(not game_state.is_character_injured(game_state.get_character_ids()[2]), "above 50 percent hp should stay healthy")
	require(game_state.is_character_injured(game_state.get_character_ids()[3]), "0 hp should become injured")
	require(game_state.get_last_expedition_report().get("character_injury_results", []).size() == 4, "return report should include injury results")


func assert_failure_injuries(game_state) -> void:
	game_state.start_new_game()
	require(game_state.start_expedition(1, 0), "expedition should start for failure injury test")
	game_state.process_battle_result({"outcome": "defeat"})
	for character_id: StringName in game_state.get_character_ids():
		require(game_state.is_character_injured(character_id), "expedition failure should injure every party member")
	require(bool(game_state.get_last_expedition_report().get("is_failure", false)), "failure report should stay marked as failure")


func assert_injury_stats_and_no_stack(game_state) -> void:
	game_state.start_new_game()
	var character_id: StringName = game_state.get_character_ids()[0]
	var healthy_max: int = int(game_state.get_final_combat_stats(character_id).get("max_hp", 0))
	game_state.hospital_system.set_character_injury_state(game_state, character_id, &"injured")
	game_state.restore_character_runtime_state_full(character_id)
	var injured_max: int = int(game_state.get_final_combat_stats(character_id).get("max_hp", 0))
	require(injured_max == max(1, int(floor(float(healthy_max) * 0.8))), "injured max hp should be floor(pre-injury max hp * 0.8)")
	game_state.hospital_system.set_character_injury_state(game_state, character_id, &"injured")
	require(int(game_state.get_final_combat_stats(character_id).get("max_hp", 0)) == injured_max, "injury should not stack")
	require(int(game_state.get_character_definition(character_id).get("base_combat_stats", {}).get("max_hp", healthy_max)) == healthy_max, "injury should not modify base stats")


func assert_treatment_flow(game_state) -> void:
	game_state.start_new_game()
	game_state.resources["herb"] = 3
	var character_id: StringName = game_state.get_character_ids()[1]
	game_state.hospital_system.set_character_injury_state(game_state, character_id, &"injured")
	var injured_max: int = int(game_state.get_final_combat_stats(character_id).get("max_hp", 0))
	require(game_state.start_treatment(character_id), "treatment should start for injured character")
	require(game_state.get_resource_amount("herb") == 2, "treatment should spend one herb immediately")
	require(game_state.is_character_being_treated(character_id), "treated character should be marked by active hospital project")
	require(not game_state.start_expedition(1, 0), "treatment should block fixed-party expedition")
	game_state.advance_day("finish_treatment")
	require(not game_state.is_character_injured(character_id), "treatment completion should clear injury")
	require(not game_state.is_character_being_treated(character_id), "treatment completion should clear active target")
	require(int(game_state.get_final_combat_stats(character_id).get("max_hp", 0)) > injured_max, "treatment should restore max hp")
	require(int(game_state.get_character_runtime_state(character_id).get("current_hp", 0)) == int(game_state.get_final_combat_stats(character_id).get("max_hp", 0)), "treatment should restore current hp to max")


func assert_hearty_stew_after_injury(game_state) -> void:
	game_state.start_new_game()
	var character_id: StringName = game_state.get_character_ids()[0]
	var healthy_max: int = int(game_state.get_final_combat_stats(character_id).get("max_hp", 0))
	game_state.hospital_system.set_character_injury_state(game_state, character_id, &"injured")
	game_state.restore_character_runtime_state_full(character_id)
	var injured_max: int = int(game_state.get_final_combat_stats(character_id).get("max_hp", 0))
	game_state.add_item(&"hearty_stew", 1)
	require(game_state.start_expedition(1, 0, &"hearty_stew"), "injured character should still be allowed to depart")
	require(int(game_state.get_final_combat_stats(character_id).get("max_hp", 0)) == injured_max + 4, "hearty stew should add after injury penalty")
	require(game_state.return_from_expedition(), "return should clear meal after injury test")
	require(game_state.is_character_injured(character_id), "return should keep existing injury without hospital treatment")
	require(int(game_state.get_final_combat_stats(character_id).get("max_hp", 0)) == injured_max, "meal should clear back to injured max hp")
	game_state.resources["herb"] = 1
	require(game_state.start_treatment(character_id), "injured character should be treatable after meal return")
	game_state.advance_day("treat_after_meal")
	require(int(game_state.get_final_combat_stats(character_id).get("max_hp", 0)) == healthy_max, "treatment should restore healthy max hp")


func assert_crafting_during_expedition(game_state) -> void:
	game_state.start_new_game()
	game_state.resources["herb"] = 2
	var medicine_before: int = game_state.get_resource_amount("medicine")
	require(game_state.start_medicine_production(), "medicine crafting should start before expedition")
	require(game_state.start_expedition(1, 0), "expedition should be allowed while hospital crafts medicine")
	require(game_state.move_to_next_expedition_node(), "expedition day should advance hospital project")
	require(game_state.get_resource_amount("medicine") == medicine_before + 1, "medicine completed during expedition should enter village stock")
	require(int(game_state.get_expedition_state().get("carried_medicine", 0)) == 0, "medicine completed behind the front should not enter expedition backpack")


func assert_new_game_reset(game_state) -> void:
	game_state.start_new_game()
	game_state.resources["herb"] = 3
	var character_id: StringName = game_state.get_character_ids()[0]
	game_state.hospital_system.set_character_injury_state(game_state, character_id, &"injured")
	game_state.start_treatment(character_id)
	game_state.start_new_game()
	require(not bool(game_state.get_hospital_project_state().get("is_active", true)), "new game should clear hospital project")
	for party_id: StringName in game_state.get_character_ids():
		require(not game_state.is_character_injured(party_id), "new game should reset all injuries")
		require(not game_state.is_character_being_treated(party_id), "new game should clear treatment target")


func require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

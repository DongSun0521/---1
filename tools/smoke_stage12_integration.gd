extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var game_state = root.get_node("/root/GameState")
	game_state.start_new_game()
	game_state.resources["food"] = 100
	game_state.resources["herb"] = 20

	require(game_state.set_party_members([&"guard", &"mage"]), "integrated party setup failed")
	require(
		game_state.assign_life_character_to_job(&"life_ahe", &"farm", &"farmer"),
		"integrated farm job setup failed"
	)
	var candidate: Dictionary = game_state.get_life_recruitment_candidates()[0]
	var recruited_id := StringName(candidate.get("candidate_id", &""))
	var recruited_portrait: String = game_state.get_candidate_portrait_path(candidate)
	require(game_state.recruit_life_candidate(recruited_id), "integrated recruit failed")
	require(
		game_state.assign_life_character_to_job(
			recruited_id, &"research_lab", &"researcher"
		),
		"integrated recruited job assignment failed"
	)

	game_state.advance_day("stage12_integration_farm_1", false)
	game_state.advance_day("stage12_integration_farm_2", false)
	var farm_experience := int(
		game_state.get_roster_character(&"life_ahe").get("experience", -1)
	)
	require(farm_experience > 0, "integrated production growth missing")
	require(
		not game_state.get_recent_life_work_feedback(&"farm").is_empty(),
		"integrated work feedback missing"
	)

	game_state.process_battle_result({
		"outcome": "victory",
		"node_id": &"forest_crossroads",
		"is_boss": false,
		"party_states": [
			{"character_id": &"guard"},
			{"character_id": &"mage"},
		],
	})
	var combat_experience := int(
		game_state.get_roster_character(&"guard").get("experience", -1)
	)
	require(combat_experience == 40, "integrated battle growth mismatch")
	require(
		game_state.get_last_battle_result().get("experience_results", []).size() == 2,
		"integrated battle feedback missing"
	)

	var save_data: Dictionary = game_state.create_save_data()
	require(int(save_data.get("save_version", 0)) == 6, "integrated save is not v6")
	var json_data = JSON.parse_string(JSON.stringify(save_data))
	require(json_data is Dictionary, "integrated save JSON conversion failed")
	game_state.start_new_game()
	require(game_state.load_save_data(json_data), game_state.get_save_error())
	require(game_state.get_character_ids() == [&"guard", &"mage"], "party did not survive integration save")
	require(
		int(game_state.get_roster_character(&"guard").get("experience", -1))
			== combat_experience,
		"combat growth did not survive integration save"
	)
	require(
		int(game_state.get_roster_character(&"life_ahe").get("experience", -1))
			== farm_experience,
		"life growth did not survive integration save"
	)
	require(game_state.has_roster_character(recruited_id), "recruited character did not survive save")
	require(
		game_state.get_character_portrait_path(recruited_id) == recruited_portrait,
		"recruited portrait did not survive save"
	)
	require(
		StringName(game_state.get_roster_character(recruited_id).get(
			"life_data", {}
		).get("assigned_building_id", &"")) == &"research_lab",
		"recruited job did not survive save"
	)
	require(
		StringName(game_state.get_building_jobs(&"farm")[0].get("character_id", &""))
			== &"life_ahe",
		"farm job runtime did not survive save"
	)
	require(
		not game_state.get_recent_life_work_feedback(&"farm").is_empty(),
		"work feedback did not survive save"
	)
	require(game_state.food_production_state != null, "food production state lost")
	require(game_state.forge_state != null, "forge state lost")
	require(game_state.hospital_project_state != null, "hospital state lost")
	require(game_state.expedition_state is Dictionary, "expedition state lost")
	require(game_state.battle_state is Dictionary, "battle state lost")
	print("stage12 total integration smoke ok")
	quit()


func require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

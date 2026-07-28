extends SceneTree

const CharacterEnumsScript := preload("res://scripts/data/character_enums.gd")


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var game_state = root.get_node("/root/GameState")
	assert_unstaffed_and_staffed_farm_output(game_state)
	assert_multi_job_average_and_stat_cap(game_state)
	assert_job_slot_expansion_and_safe_reduction(game_state)
	assert_valid_work_experience_and_invalid_cycle(game_state)
	assert_life_level_growth(game_state)
	assert_food_forge_and_hospital_completion(game_state)
	assert_v4_round_trip_and_v3_migration(game_state)
	await assert_stage12d_ui(game_state)
	print("stage12d life production growth smoke ok")
	quit()


func assert_unstaffed_and_staffed_farm_output(game_state: Node) -> void:
	game_state.start_new_game()
	require(
		is_equal_approx(game_state.get_building_final_production_multiplier(&"farm"), 1.0),
		"unstaffed building must preserve the 100 percent base multiplier"
	)
	game_state.advance_day("unstaffed_farm_day_1", false)
	var base_report: Dictionary = game_state.advance_day("unstaffed_farm_day_2", false)
	require(
		int(base_report.get("farm_food_produced", -1)) == 9,
		"unstaffed farm should preserve the historical three-plot output"
	)

	game_state.start_new_game()
	require(
		game_state.assign_life_character_to_job(&"life_ahe", &"farm", &"farmer"),
		"farmer assignment failed"
	)
	var preview: Dictionary = game_state.get_life_job_efficiency(
		&"life_ahe", &"farm", &"farmer"
	)
	require(
		is_equal_approx(float(preview.get("efficiency_percent", 0.0)), 151.0),
		"farm trait should affect the shared efficiency calculation"
	)
	require(
		is_equal_approx(float(preview.get("production_bonus_percent", 0.0)), 5.0),
		"optional production trait bonus is missing"
	)
	require(
		is_equal_approx(game_state.get_building_final_production_multiplier(&"farm"), 1.5855),
		"final production multiplier should combine personnel efficiency and production bonus"
	)
	game_state.advance_day("staffed_farm_day_1", false)
	var staffed_report: Dictionary = game_state.advance_day("staffed_farm_day_2", false)
	require(
		int(staffed_report.get("farm_food_produced", -1)) == 15,
		"round-half-up should turn each base-3 harvest into 5"
	)
	var ahe: Dictionary = game_state.get_roster_character(&"life_ahe")
	require(
		int(ahe.get("experience", -1)) == 12,
		"farm completion should grant trait-adjusted work experience"
	)


func assert_multi_job_average_and_stat_cap(game_state: Node) -> void:
	game_state.start_new_game()
	require(game_state.set_building_level(&"farm", 2), "farm level 2 setup failed")
	require(game_state.get_building_jobs(&"farm").size() == 2, "level 2 should expose two jobs")
	require(
		game_state.assign_life_character_to_job(&"life_ahe", &"farm", &"farmer"),
		"first farm slot assignment failed"
	)
	require(
		game_state.assign_life_character_to_job(&"life_atie", &"farm", &"farmer_2"),
		"second farm slot assignment failed"
	)
	var personnel: Dictionary = game_state.get_building_personnel_efficiency(&"farm")
	require(int(personnel.get("assigned_count", 0)) == 2, "two workers should be counted")
	require(
		is_equal_approx(float(personnel.get("personnel_efficiency_percent", 0.0)), 131.5),
		"multiple worker efficiency must use the arithmetic mean"
	)
	require(
		not is_equal_approx(
			float(personnel.get("personnel_efficiency_multiplier", 1.0)),
			1.51 * 1.12
		),
		"worker multipliers must not be multiplied together"
	)

	var ahe_record = game_state.character_roster.get_character(&"life_ahe")
	ahe_record.life_data.life_stats.farming = 150
	var capped: Dictionary = game_state.get_life_job_efficiency(
		&"life_ahe", &"farm", &"farmer"
	)
	require(
		int(capped.get("applied_attribute_value", 0)) == 100,
		"efficiency calculation should cap the applied stat at 100"
	)
	require(
		is_equal_approx(float(capped.get("efficiency_percent", 0.0)), 160.0),
		"capped stat plus trait efficiency is incorrect"
	)


func assert_job_slot_expansion_and_safe_reduction(game_state: Node) -> void:
	game_state.start_new_game()
	for building_id: StringName in [
		&"farm",
		&"food_workshop",
		&"weapon_forge",
		&"resource_collection",
		&"research_lab",
		&"hospital",
	]:
		require(
			game_state.set_building_level(building_id, 4),
			"%s level 4 setup failed" % String(building_id)
		)
		require(
			game_state.get_building_jobs(building_id).size() == 4,
			"%s should use the configured four level-4 slots" % String(building_id)
		)
	require(
		game_state.get_building_jobs(&"residence").is_empty(),
		"residence should keep its configured zero-slot override"
	)

	game_state.start_new_game()
	require(
		game_state.assign_life_character_to_job(&"life_ahe", &"research_lab", &"researcher"),
		"first research assignment failed"
	)
	require(game_state.set_building_level(&"research_lab", 3), "research level 3 failed")
	var expanded_jobs: Array = game_state.get_building_jobs(&"research_lab")
	require(expanded_jobs.size() == 3, "level 3 should expose three configured slots")
	require(
		StringName(expanded_jobs[0].get("character_id", &"")) == &"life_ahe",
		"job expansion should preserve the first worker"
	)
	require(
		game_state.assign_life_character_to_job(
			&"life_atie", &"research_lab", &"researcher_2"
		),
		"second research assignment failed"
	)
	require(
		game_state.assign_life_character_to_job(
			&"life_xiaoyao", &"research_lab", &"researcher_3"
		),
		"third research assignment failed"
	)
	require(game_state.set_building_level(&"research_lab", 1), "research reduction failed")
	var reduced_jobs: Array = game_state.get_building_jobs(&"research_lab")
	require(reduced_jobs.size() == 1, "level 1 should retain one job")
	require(
		StringName(reduced_jobs[0].get("character_id", &"")) == &"life_ahe",
		"job reduction should keep the earliest valid slot"
	)
	assert_life_assignment(
		game_state,
		&"life_ahe",
		&"research_lab",
		&"researcher",
		CharacterEnumsScript.WorkState.WORKING
	)
	assert_life_assignment(
		game_state,
		&"life_atie",
		&"",
		&"",
		CharacterEnumsScript.WorkState.IDLE
	)
	assert_life_assignment(
		game_state,
		&"life_xiaoyao",
		&"",
		&"",
		CharacterEnumsScript.WorkState.IDLE
	)
	var slot_config: Dictionary = game_state.get_building_job_slot_count_config(&"research_lab")
	require(
		int(slot_config.get(1, 0)) == 1
			and int(slot_config.get(2, 0)) == 2
			and int(slot_config.get(3, 0)) == 3
			and int(slot_config.get(4, 0)) == 4,
		"job counts should come from the configured 1/2/3/4 curve"
	)


func assert_valid_work_experience_and_invalid_cycle(game_state: Node) -> void:
	game_state.start_new_game()
	require(
		game_state.assign_life_character_to_job(&"life_ahe", &"farm", &"farmer"),
		"work experience farm assignment failed"
	)
	var invalid_report: Dictionary = game_state.advance_day("growth_without_harvest", false)
	require(
		invalid_report.get("farm_harvests", []).is_empty(),
		"first farm day should not complete a production cycle"
	)
	require(
		int(game_state.get_roster_character(&"life_ahe").get("experience", -1)) == 0,
		"an incomplete production cycle must not grant experience"
	)
	game_state.advance_day("growth_with_harvest", false)
	require(
		int(game_state.get_roster_character(&"life_ahe").get("experience", -1)) == 12,
		"a valid production cycle should grant work experience"
	)
	var duplicate: Array = game_state.settle_life_job_work_experience(
		&"farm", StringName("farm_day_2")
	)
	require(duplicate.is_empty(), "the same production cycle must settle only once")
	require(
		int(game_state.get_roster_character(&"life_ahe").get("experience", -1)) == 12,
		"duplicate settlement changed experience"
	)

	game_state.start_new_game()
	require(game_state.set_building_level(&"farm", 2), "two-worker farm setup failed")
	require(game_state.assign_life_character_to_job(&"life_ahe", &"farm", &"farmer"), "Ahe assignment failed")
	require(game_state.assign_life_character_to_job(&"life_atie", &"farm", &"farmer_2"), "Atie assignment failed")
	game_state.advance_day("all_workers_day_1", false)
	game_state.advance_day("all_workers_day_2", false)
	require(
		int(game_state.get_roster_character(&"life_ahe").get("experience", -1)) == 12,
		"first valid worker missed experience"
	)
	require(
		int(game_state.get_roster_character(&"life_atie").get("experience", -1)) == 10,
		"second valid worker missed base experience"
	)


func assert_life_level_growth(game_state: Node) -> void:
	game_state.start_new_game()
	var result: Dictionary = game_state.add_life_character_experience(&"life_ahe", 270)
	require(bool(result.get("success", false)), "life experience grant failed")
	require(int(result.get("levels_gained", 0)) == 2, "life character should level twice")
	require(int(result.get("experience", -1)) == 20, "remaining experience should be preserved")
	var ahe: Dictionary = game_state.get_roster_character(&"life_ahe")
	require(int(ahe.get("level", 0)) == 3, "life level did not advance")
	require(
		int(ahe.get("life_data", {}).get("life_stats", {}).get("farming", 0)) == 86,
		"idle character should grow its highest stat for both levels"
	)
	require(
		game_state.get_life_character_upgrade_requirement(&"life_ahe") == 200,
		"level 3 upgrade requirement should be 200"
	)

	game_state.start_new_game()
	var atie_record = game_state.character_roster.get_character(&"life_atie")
	atie_record.life_data.life_stats.set_core_stat(&"crafting", 99)
	require(
		game_state.assign_life_character_to_job(
			&"life_atie", &"food_workshop", &"food_crafter"
		),
		"crafting growth assignment failed"
	)
	var cap_result: Dictionary = game_state.add_life_character_experience(&"life_atie", 100)
	require(int(cap_result.get("levels_gained", 0)) == 1, "assigned worker should level")
	require(
		int(game_state.get_roster_character(&"life_atie").get(
			"life_data", {}
		).get("life_stats", {}).get("crafting", 0)) == 100,
		"life stat growth should respect the 100 cap"
	)

	game_state.start_new_game()
	var tie_record = game_state.character_roster.get_character(&"life_xiaoyao")
	for stat_id: StringName in [&"farming", &"crafting", &"gathering", &"research", &"medical"]:
		tie_record.life_data.life_stats.set_core_stat(stat_id, 50)
	game_state.add_life_character_experience(&"life_xiaoyao", 100)
	var tie_stats: Dictionary = game_state.get_roster_character(
		&"life_xiaoyao"
	).get("life_data", {}).get("life_stats", {})
	require(
		int(tie_stats.get("farming", 0)) == 52,
		"idle stat ties should use the fixed farming-first rule"
	)


func assert_food_forge_and_hospital_completion(game_state: Node) -> void:
	game_state.start_new_game()
	require(
		game_state.assign_life_character_to_job(
			&"life_atie", &"food_workshop", &"food_crafter"
		),
		"food crafter assignment failed"
	)
	require(game_state.start_food_recipe(&"expedition_ration_recipe"), "food recipe start failed")
	var food_report: Dictionary = game_state.advance_day("food_completion", false)
	require(
		int(food_report.get("food_workshop_output_amount", 0)) == 5,
		"food workshop should apply crafting efficiency to base output"
	)
	require(game_state.get_item_count(&"expedition_ration") == 11, "food output inventory mismatch")
	require(
		int(game_state.get_roster_character(&"life_atie").get("experience", -1)) == 11,
		"crafting experience trait should grant 11 experience"
	)

	game_state.start_new_game()
	game_state.resources["herb"] = 10
	require(
		game_state.assign_life_character_to_job(&"life_xiaoyao", &"hospital", &"medic"),
		"hospital worker assignment failed"
	)
	require(game_state.start_medicine_production(), "medicine project start failed")
	var hospital_report: Dictionary = game_state.advance_day("hospital_completion", false)
	require(
		int(hospital_report.get("medicine_produced", 0)) == 2,
		"hospital should apply medical efficiency to medicine output"
	)
	require(
		int(game_state.get_roster_character(&"life_xiaoyao").get("experience", -1)) == 12,
		"hospital completion should grant trait-adjusted experience"
	)

	game_state.start_new_game()
	game_state.resources["herb"] = 10
	require(
		game_state.assign_life_character_to_job(&"life_xiaoyao", &"hospital", &"medic"),
		"hospital treatment worker assignment failed"
	)
	game_state.hospital_system.set_character_injury_state(game_state, &"guard", &"injured")
	require(game_state.start_treatment(&"guard"), "hospital treatment start failed")
	var treatment_report: Dictionary = game_state.advance_day("treatment_completion", false)
	require(
		bool(treatment_report.get("treatment_completed", false)),
		"hospital treatment should complete as valid work"
	)
	require(
		int(game_state.get_roster_character(&"life_xiaoyao").get("experience", -1)) == 12,
		"completed treatment should grant work experience exactly once"
	)

	game_state.start_new_game()
	game_state.resources["ore"] = 10
	require(
		game_state.assign_life_character_to_job(
			&"life_atie", &"weapon_forge", &"weapon_crafter"
		),
		"forge worker assignment failed"
	)
	var equipment_before: int = game_state.get_equipment_inventory().size()
	require(game_state.start_forge_recipe(&"craft_iron_sword"), "forge recipe start failed")
	game_state.advance_day("forge_progress", false)
	var forge_report: Dictionary = game_state.advance_day("forge_completion", false)
	require(
		int(forge_report.get("forge_report", {}).get("output_amount", 0)) == 2,
		"forge should apply crafting efficiency to its integer output"
	)
	require(
		game_state.get_equipment_inventory().size() == equipment_before + 2,
		"forge output instances were not both added"
	)
	require(
		int(game_state.get_roster_character(&"life_atie").get("experience", -1)) == 11,
		"forge completion should grant work experience once"
	)


func assert_v4_round_trip_and_v3_migration(game_state: Node) -> void:
	game_state.start_new_game()
	require(game_state.set_building_level(&"farm", 3), "save setup farm level failed")
	require(game_state.assign_life_character_to_job(&"life_ahe", &"farm", &"farmer"), "save setup assignment failed")
	game_state.add_life_character_experience(&"life_ahe", 120)
	game_state.life_work_settlement_keys[&"farm"] = &"farm_day_77"
	var save_data: Dictionary = game_state.create_save_data()
	require(int(save_data.get("save_version", 0)) == 6, "Stage 12F save version should be 6")
	require(
		save_data.get("buildings", {}).get("farm", {}).get("jobs", []).size() == 3,
		"v4 save should persist level-derived job runtime slots"
	)
	var serialized_save := JSON.stringify(save_data)
	var parsed_save = JSON.parse_string(serialized_save)
	require(parsed_save is Dictionary, "v4 save should survive JSON serialization")

	game_state.start_new_game()
	require(game_state.load_save_data(parsed_save), game_state.get_save_error())
	var loaded: Dictionary = game_state.get_roster_character(&"life_ahe")
	require(int(loaded.get("level", 0)) == 2, "life level did not round trip")
	require(int(loaded.get("experience", -1)) == 20, "life experience did not round trip")
	require(
		int(loaded.get("life_data", {}).get("life_stats", {}).get("farming", 0)) == 84,
		"grown life stat did not round trip"
	)
	require(
		loaded.get("life_data", {}).get("life_trait_ids", []).has(&"seasoned_farmer"),
		"life trait id did not round trip"
	)
	require(game_state.get_building_jobs(&"farm").size() == 3, "v4 job count did not round trip")
	assert_life_assignment(
		game_state,
		&"life_ahe",
		&"farm",
		&"farmer",
		CharacterEnumsScript.WorkState.WORKING
	)
	require(
		StringName(game_state.life_work_settlement_keys.get(&"farm", &"")) == &"farm_day_77",
		"production settlement state did not round trip"
	)

	game_state.start_new_game()
	var version_three: Dictionary = game_state.create_save_data()
	version_three["save_version"] = 3
	version_three.erase("life_work_settlement_keys")
	version_three["buildings"]["farm"]["level"] = 2
	version_three["buildings"]["farm"]["jobs"] = [
		version_three["buildings"]["farm"]["jobs"][0].duplicate(true)
	]
	for character: Dictionary in version_three.get("character_roster", {}).get("characters", []):
		if StringName(character.get("character_id", &"")) != &"life_ahe":
			continue
		character.erase("level")
		character.erase("experience")
		character.erase("experience_to_next_level")
		character["life_data"]["work_experience"] = 57
		character["life_data"]["life_trait_ids"] = []
		character["life_data"]["life_stats"]["farming"] = 150
	require(game_state.load_save_data(version_three), game_state.get_save_error())
	var migrated: Dictionary = game_state.get_roster_character(&"life_ahe")
	require(int(migrated.get("level", 0)) == 1, "v3 missing level should default safely")
	require(int(migrated.get("experience", -1)) == 57, "v3 work experience should migrate")
	require(
		int(migrated.get("life_data", {}).get("work_experience", -1)) == 57,
		"legacy work experience mirror should remain compatible"
	)
	require(
		int(migrated.get("life_data", {}).get("life_stats", {}).get("farming", 0)) == 100,
		"migrated life stats should be capped at 100"
	)
	require(
		migrated.get("life_data", {}).get("life_trait_ids", []).has(&"seasoned_farmer"),
		"v3 default life trait should be restored"
	)
	require(
		game_state.get_building_jobs(&"farm").size() == 2,
		"v3 building jobs should expand to match the saved level"
	)
	require(game_state.life_work_settlement_keys.is_empty(), "old saves should receive empty settlement state")


func assert_stage12d_ui(game_state: Node) -> void:
	game_state.start_new_game()
	require(game_state.set_building_level(&"farm", 2), "UI job expansion setup failed")
	require(game_state.assign_life_character_to_job(&"life_ahe", &"farm", &"farmer"), "UI assignment failed")
	var main_scene: PackedScene = load("res://features/main/main.tscn")
	var main_view := main_scene.instantiate()
	root.add_child(main_view)
	await process_frame
	await process_frame
	var village_view = main_view.find_child("VillageView", true, false)
	require(village_view != null, "VillageView not found")
	village_view.show_life_character_page()
	await process_frame
	require(
		String(village_view.life_character_basic_label.text).contains("0 / 100"),
		"life UI should show current and required experience"
	)
	require(
		String(village_view.life_character_trait_label.text).contains("农耕能手"),
		"life UI should show configured trait details"
	)
	require(
		String(village_view.life_character_efficiency_label.text).contains("特性10.0%"),
		"life UI should explain the trait efficiency component"
	)
	village_view.hide_life_character_page()
	village_view.select_building(&"farm")
	await process_frame
	require(
		village_view.building_job_list_box.get_child_count() == 2,
		"building UI should show level-derived job count"
	)
	require(
		String(village_view.building_jobs_summary_label.text).contains("最终生产倍率"),
		"building UI should show final production multiplier"
	)
	main_view.queue_free()


func assert_life_assignment(
	game_state: Node,
	character_id: StringName,
	building_id: StringName,
	job_id: StringName,
	work_state: int
) -> void:
	var life_data: Dictionary = game_state.get_roster_character(character_id).get("life_data", {})
	require(
		StringName(life_data.get("assigned_building_id", &"")) == building_id,
		"%s assigned building mismatch" % String(character_id)
	)
	require(
		StringName(life_data.get("assigned_job_id", &"")) == job_id,
		"%s assigned job mismatch" % String(character_id)
	)
	require(
		int(life_data.get("work_state", -1)) == work_state,
		"%s work state mismatch" % String(character_id)
	)


func require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

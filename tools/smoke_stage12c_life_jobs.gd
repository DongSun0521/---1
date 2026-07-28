extends SceneTree

const CharacterEnumsScript := preload("res://scripts/data/character_enums.gd")


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var game_state = root.get_node("/root/GameState")
	game_state.start_new_game()
	assert_default_life_roster_and_jobs(game_state)
	assert_assignment_rules(game_state)
	assert_efficiency_preview(game_state)
	assert_save_round_trip(game_state)
	assert_legacy_and_corrupt_save_migration(game_state)
	await assert_life_character_ui(game_state)
	print("stage12c life jobs smoke ok")
	quit()


func assert_default_life_roster_and_jobs(game_state: Node) -> void:
	var life_characters: Array = game_state.get_all_life_characters()
	require(life_characters.size() == 3, "Stage 12C should retain exactly three default life characters")
	var life_ids: Array[StringName] = []
	for snapshot: Dictionary in life_characters:
		require(
			StringName(snapshot.get("character_type_name", &"")) == &"life",
			"life roster query leaked a combat character"
		)
		life_ids.append(StringName(snapshot.get("character_id", &"")))
	require(life_ids == [&"life_ahe", &"life_atie", &"life_xiaoyao"], "default life roster order changed")
	require(not life_ids.has(&"guard"), "combat character leaked into life roster")
	require(game_state.get_idle_life_characters().size() == 3, "default life characters should be idle")

	var expected_job_types := {
		&"farm": &"farming",
		&"food_workshop": &"crafting",
		&"weapon_forge": &"crafting",
		&"resource_collection": &"gathering",
		&"research_lab": &"research",
		&"hospital": &"medical",
	}
	for building_id: StringName in expected_job_types.keys():
		var jobs: Array = game_state.get_building_jobs(building_id)
		require(jobs.size() == 1, "%s should expose one initial job slot" % String(building_id))
		require(
			StringName(jobs[0].get("job_type", &"")) == expected_job_types[building_id],
			"%s job type mismatch" % String(building_id)
		)
		require(StringName(jobs[0].get("character_id", &"")) == &"", "default job should be empty")
		var runtime_state: Dictionary = game_state.get_building_state(building_id)
		require(int(runtime_state.get("job_count", -1)) == 1, "building runtime should expose job count")
	require(game_state.get_building_jobs(&"residence").is_empty(), "residence should have no Stage 12C job")
	require(game_state.get_building_jobs(&"missing_building").is_empty(), "invalid building id should be safe")


func assert_assignment_rules(game_state: Node) -> void:
	require(
		not game_state.assign_life_character_to_job(&"missing", &"farm", &"farmer"),
		"invalid character id should be rejected"
	)
	require(
		not game_state.assign_life_character_to_job(&"guard", &"farm", &"farmer"),
		"combat character should not enter a life job"
	)
	require(
		not game_state.assign_life_character_to_job(&"life_ahe", &"missing", &"farmer"),
		"invalid building id should be rejected"
	)
	require(
		not game_state.assign_life_character_to_job(&"life_ahe", &"farm", &"missing"),
		"invalid job id should be rejected"
	)

	require(
		game_state.set_life_character_assignment(
			&"life_xiaoyao", &"", &"", CharacterEnumsScript.WorkState.UNAVAILABLE
		),
		"life character should support an unavailable state"
	)
	require(
		not game_state.assign_life_character_to_job(&"life_xiaoyao", &"hospital", &"medic"),
		"unavailable life character should not be assignable"
	)
	require(
		game_state.set_life_character_assignment(
			&"life_xiaoyao", &"", &"", CharacterEnumsScript.WorkState.IDLE
		),
		"unavailable test character should return to idle"
	)

	require(
		game_state.assign_life_character_to_job(&"life_ahe", &"farm", &"farmer"),
		"idle farmer assignment should succeed"
	)
	assert_character_assignment(
		game_state, &"life_ahe", &"farm", &"farmer", CharacterEnumsScript.WorkState.WORKING
	)
	require(
		not game_state.assign_life_character_to_job(&"life_ahe", &"research_lab", &"researcher"),
		"one character must not enter multiple jobs"
	)
	require(
		game_state.assign_life_character_to_job(&"life_atie", &"weapon_forge", &"weapon_crafter"),
		"second idle life character assignment should succeed"
	)
	require(
		game_state.replace_life_character_in_job(&"farm", &"farmer", &"life_xiaoyao"),
		"occupied job replacement should succeed"
	)
	assert_character_assignment(
		game_state, &"life_ahe", &"", &"", CharacterEnumsScript.WorkState.IDLE
	)
	assert_character_assignment(
		game_state, &"life_xiaoyao", &"farm", &"farmer", CharacterEnumsScript.WorkState.WORKING
	)
	require(
		StringName(game_state.get_building_jobs(&"farm")[0].get("character_id", &"")) == &"life_xiaoyao",
		"replacement did not update the building slot"
	)
	var assigned_characters: Array = game_state.get_building_assigned_characters(&"farm")
	require(assigned_characters.size() == 1, "building assigned-character query should return its occupant")
	require(
		StringName(assigned_characters[0].get("character_id", &"")) == &"life_xiaoyao",
		"building assigned-character query returned the wrong character"
	)
	require(
		game_state.unassign_building_job(&"farm", &"farmer"),
		"occupied building job should support removal"
	)
	assert_character_assignment(
		game_state, &"life_xiaoyao", &"", &"", CharacterEnumsScript.WorkState.IDLE
	)
	require(
		StringName(game_state.get_building_jobs(&"farm")[0].get("character_id", &"")) == &"",
		"unassign did not clear building slot"
	)
	require(
		game_state.assign_life_character_to_job(&"life_ahe", &"farm", &"farmer"),
		"farmer should be assignable again after removal"
	)
	require(game_state.unassign_life_character(&"life_ahe"), "role-side removal should clear its building job")
	require(
		game_state.assign_life_character_to_job(&"life_ahe", &"farm", &"farmer"),
		"farmer should be assignable after role-side removal"
	)
	require(
		game_state.set_life_character_work_experience(&"life_atie", 57),
		"work experience update should accept life characters"
	)


func assert_efficiency_preview(game_state: Node) -> void:
	var preview: Dictionary = game_state.get_life_job_efficiency_preview(
		&"life_ahe", &"farm", &"farmer"
	)
	require(bool(preview.get("success", false)), "valid job efficiency preview failed")
	require(StringName(preview.get("attribute_id", &"")) == &"farming", "farm should read farming")
	require(int(preview.get("attribute_value", 0)) == 82, "farmer farming stat mismatch")
	require(
		is_equal_approx(float(preview.get("efficiency_percent", 0.0)), 151.0),
		"life trait and balanced 0.5 percent stat multiplier should share one calculation"
	)
	require(
		not bool(game_state.get_life_job_efficiency_preview(
			&"guard", &"farm", &"farmer"
		).get("success", true)),
		"combat character efficiency preview should fail safely"
	)


func assert_save_round_trip(game_state: Node) -> void:
	game_state.resources["food"] = 91
	game_state.buildings["farm"]["level"] = 2
	require(game_state.equip_item(&"guard", &"iron_sword_01"), "historical equipment setup failed")
	var save_data: Dictionary = game_state.create_save_data()
	require(int(save_data.get("save_version", 0)) == 6, "Stage 12F save version should be 6")
	require(
		StringName(save_data.get("buildings", {}).get("farm", {}).get("jobs", [])[0].get(
			"character_id", &""
		)) == &"life_ahe",
		"save should store the job character id in existing building data"
	)

	game_state.start_new_game()
	require(game_state.load_save_data(save_data), game_state.get_save_error())
	assert_character_assignment(
		game_state, &"life_ahe", &"farm", &"farmer", CharacterEnumsScript.WorkState.WORKING
	)
	assert_character_assignment(
		game_state,
		&"life_atie",
		&"weapon_forge",
		&"weapon_crafter",
		CharacterEnumsScript.WorkState.WORKING
	)
	require(
		int(game_state.get_roster_character(&"life_atie").get("life_data", {}).get(
			"work_experience", -1
		)) == 57,
		"work experience did not round trip"
	)
	require(int(game_state.resources.get("food", 0)) == 91, "resource data was overwritten")
	require(int(game_state.buildings.get("farm", {}).get("level", 0)) == 2, "building level was overwritten")
	require(
		game_state.get_equipped_equipment_instance_id(&"guard", &"weapon") == &"iron_sword_01",
		"equipment binding was overwritten"
	)


func assert_legacy_and_corrupt_save_migration(game_state: Node) -> void:
	game_state.start_new_game()
	var version_two: Dictionary = game_state.create_save_data()
	version_two["save_version"] = 2
	for state_key in version_two.get("buildings", {}).keys():
		version_two["buildings"][state_key].erase("jobs")
	set_saved_life_assignment(
		version_two,
		&"life_ahe",
		&"farm",
		&"farmer",
		CharacterEnumsScript.WorkState.WORKING
	)
	require(game_state.load_save_data(version_two), game_state.get_save_error())
	assert_character_assignment(
		game_state, &"life_ahe", &"farm", &"farmer", CharacterEnumsScript.WorkState.WORKING
	)
	require(
		StringName(game_state.get_building_jobs(&"farm")[0].get("character_id", &"")) == &"life_ahe",
		"v2 role-only assignment should migrate into the default building slot"
	)

	game_state.start_new_game()
	var corrupt: Dictionary = game_state.create_save_data()
	set_saved_job_character(corrupt, "research_lab", &"researcher", &"life_ahe")
	set_saved_job_character(corrupt, "farm", &"farmer", &"life_ahe")
	set_saved_job_character(corrupt, "clinic", &"medic", &"missing_life_id")
	set_saved_life_assignment(
		corrupt, &"life_ahe", &"", &"", CharacterEnumsScript.WorkState.IDLE
	)
	require(game_state.load_save_data(corrupt), game_state.get_save_error())
	var references: Array = game_state.building_system.get_character_job_references(
		game_state, &"life_ahe"
	)
	require(references.size() == 1, "duplicate building references should keep exactly one valid job")
	var repaired: Dictionary = game_state.get_roster_character(&"life_ahe").get("life_data", {})
	require(
		StringName(repaired.get("assigned_building_id", &""))
			== StringName(references[0].get("building_id", &"")),
		"building-side assignment should repair the role-side building id"
	)
	require(
		StringName(repaired.get("assigned_job_id", &""))
			== StringName(references[0].get("job_id", &"")),
		"building-side assignment should repair the role-side job id"
	)
	require(
		int(repaired.get("work_state", -1)) == CharacterEnumsScript.WorkState.WORKING,
		"building-side assignment should repair work state"
	)
	require(
		StringName(game_state.get_building_jobs(&"hospital")[0].get("character_id", &"")) == &"",
		"missing character id should be cleared from a building job"
	)

	var old_buildings: Dictionary = game_state.buildings.duplicate(true)
	for state_key in old_buildings.keys():
		old_buildings[state_key].erase("jobs")
	var version_zero := {
		"save_version": 0,
		"current_day": 8,
		"resources": {"food": 64, "medicine": 2, "ore": 3, "herb": 1, "boss_core": 0},
		"buildings": old_buildings,
	}
	require(game_state.load_save_data(version_zero), game_state.get_save_error())
	require(game_state.get_all_life_characters().size() == 3, "v0 save should receive default life roster")
	require(game_state.get_building_jobs(&"farm").size() == 1, "v0 save should receive default jobs")
	require(int(game_state.resources.get("food", 0)) == 64, "v0 resource migration regressed")


func assert_life_character_ui(game_state: Node) -> void:
	game_state.start_new_game()
	var main_scene: PackedScene = load("res://features/main/main.tscn")
	var main_view := main_scene.instantiate()
	root.add_child(main_view)
	await process_frame
	await process_frame
	var village_view = main_view.find_child("VillageView", true, false)
	require(village_view != null, "VillageView not found")
	require(
		village_view.find_child("LifeRosterHotspot", true, false) != null,
		"village life-character entry is missing"
	)
	village_view.show_life_character_page()
	await process_frame
	require(village_view.life_character_buttons.size() == 3, "life page should list three life characters")
	require(not village_view.life_character_buttons.has(&"guard"), "combat character leaked into life page")
	require(
		String(village_view.life_character_stats_label.text).contains("farming"),
		"life detail should show five life-stat identifiers"
	)
	require(
		not String(village_view.life_character_trait_label.text).is_empty(),
		"life detail should show life traits"
	)
	require(
		village_view.life_job_options_box.get_child_count() == 6,
		"life detail should show all six initial job choices"
	)
	village_view.hide_life_character_page()
	village_view.select_building(&"farm")
	await process_frame
	require(village_view.building_jobs_section.visible, "building detail should show its job section")
	require(village_view.building_job_list_box.get_child_count() == 1, "farm should show one job card")
	main_view.queue_free()


func assert_character_assignment(
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


func set_saved_life_assignment(
	save_data: Dictionary,
	character_id: StringName,
	building_id: StringName,
	job_id: StringName,
	work_state: int
) -> void:
	for character: Dictionary in save_data.get("character_roster", {}).get("characters", []):
		if StringName(character.get("character_id", &"")) != character_id:
			continue
		character["life_data"]["assigned_building_id"] = building_id
		character["life_data"]["assigned_job_id"] = job_id
		character["life_data"]["work_state"] = work_state
		return


func set_saved_job_character(
	save_data: Dictionary,
	state_key: String,
	job_id: StringName,
	character_id: StringName
) -> void:
	for job: Dictionary in save_data.get("buildings", {}).get(state_key, {}).get("jobs", []):
		if StringName(job.get("job_id", &"")) == job_id:
			job["character_id"] = character_id
			return


func require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

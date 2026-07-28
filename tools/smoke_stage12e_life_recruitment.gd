extends SceneTree

const CharacterEnumsScript := preload("res://scripts/data/character_enums.gd")


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var game_state = root.get_node("/root/GameState")
	assert_initial_candidates_and_generation(game_state)
	assert_recruitment_and_resource_guards(game_state)
	assert_candidate_lock_and_refresh(game_state)
	assert_capacity_and_residence_growth(game_state)
	assert_recruited_assignment_and_dismissal(game_state)
	assert_filter_and_sort(game_state)
	assert_v5_round_trip_and_candidate_repair(game_state)
	assert_v0_to_v4_migrations(game_state)
	await assert_stage12e_ui(game_state)
	print("stage12e life recruitment smoke ok")
	quit()


func assert_initial_candidates_and_generation(game_state: Node) -> void:
	game_state.start_new_game()
	var candidates: Array = game_state.get_life_recruitment_candidates()
	require(candidates.size() == 3, "new games should receive three life candidates")
	var all_ids: Dictionary = {}
	for formal: Dictionary in game_state.get_all_life_characters():
		all_ids[StringName(formal.get("character_id", &""))] = true
	for candidate: Dictionary in candidates:
		var candidate_id := StringName(candidate.get("candidate_id", &""))
		var character: Dictionary = candidate.get("character", {})
		require(candidate_id != &"", "candidate id must not be empty")
		require(not all_ids.has(candidate_id), "candidate id conflicts with the formal roster")
		all_ids[candidate_id] = true
		require(
			int(character.get("character_type", -1)) == CharacterEnumsScript.CharacterType.LIFE,
			"candidate type must be LIFE"
		)
		require(character.get("combat_data", {}).is_empty(), "life candidate carried combat data")
		require(
			int(character.get("life_data", {}).get("work_state", -1))
				== CharacterEnumsScript.WorkState.IDLE,
			"candidate should start idle"
		)
		require(not String(candidate.get("display_name", "")).is_empty(), "candidate name missing")
		require(not candidate.get("life_trait_ids", []).is_empty(), "candidate trait missing")

	require(
		game_state.get_life_recruitment_quality_for_roll(0)
			== CharacterEnumsScript.Quality.COMMON,
		"quality roll lower common boundary failed"
	)
	require(
		game_state.get_life_recruitment_quality_for_roll(64)
			== CharacterEnumsScript.Quality.COMMON,
		"quality roll upper common boundary failed"
	)
	require(
		game_state.get_life_recruitment_quality_for_roll(65)
			== CharacterEnumsScript.Quality.RARE,
		"quality roll lower rare boundary failed"
	)
	require(
		game_state.get_life_recruitment_quality_for_roll(92)
			== CharacterEnumsScript.Quality.RARE,
		"quality roll upper rare boundary failed"
	)
	require(
		game_state.get_life_recruitment_quality_for_roll(93)
			== CharacterEnumsScript.Quality.EPIC,
		"quality roll lower epic boundary failed"
	)
	require(
		game_state.get_life_recruitment_quality_for_roll(99)
			== CharacterEnumsScript.Quality.EPIC,
		"quality roll upper epic boundary failed"
	)

	var config: Dictionary = game_state.get_life_recruitment_generation_config()
	var ranges_by_quality: Dictionary = config.get("quality_attribute_ranges", {})
	for quality: int in [
		CharacterEnumsScript.Quality.COMMON,
		CharacterEnumsScript.Quality.RARE,
		CharacterEnumsScript.Quality.EPIC,
		CharacterEnumsScript.Quality.LEGENDARY,
	]:
		var generated: Dictionary = game_state.generate_life_character_candidate(quality)
		var stats: Dictionary = generated.get("life_stats", {})
		var primary_id := StringName(generated.get("specialty_stat_id", &""))
		var ranges: Dictionary = ranges_by_quality.get(quality, {})
		var primary_value := int(stats.get(String(primary_id), -1))
		require(
			primary_value >= int(ranges.get("primary_min", 0))
				and primary_value <= int(ranges.get("primary_max", 0)),
			"generated primary stat is outside its quality range"
		)
		var highest_other := -1
		for stat_id: StringName in [&"farming", &"crafting", &"gathering", &"research", &"medical"]:
			if stat_id == primary_id:
				continue
			var value := int(stats.get(String(stat_id), -1))
			require(
				value >= int(ranges.get("other_min", 0))
					and value <= int(ranges.get("other_max", 0)),
				"generated secondary stat is outside its quality range"
			)
			highest_other = maxi(highest_other, value)
		require(primary_value >= highest_other + 10, "candidate lacks a clear specialty")
		var trait_count: int = generated.get("life_trait_ids", []).size()
		if quality == CharacterEnumsScript.Quality.COMMON:
			require(trait_count == 1, "common candidates should have one trait")
		elif quality >= CharacterEnumsScript.Quality.EPIC:
			require(trait_count == 2, "epic and legendary candidates should have two traits")
		else:
			require(trait_count >= 1 and trait_count <= 2, "rare trait count is invalid")


func assert_recruitment_and_resource_guards(game_state: Node) -> void:
	game_state.start_new_game()
	game_state.resources["food"] = 100
	var candidate: Dictionary = game_state.get_life_recruitment_candidates()[0]
	var candidate_id := StringName(candidate.get("candidate_id", &""))
	var cost := int(candidate.get("recruitment_cost", 0))
	var count_before: int = game_state.get_all_life_characters().size()
	require(game_state.recruit_life_candidate(candidate_id), "candidate recruitment failed")
	require(game_state.has_roster_character(candidate_id), "recruit did not enter CharacterRoster")
	require(
		game_state.get_all_life_characters().size() == count_before + 1,
		"formal life roster count did not increase"
	)
	require(game_state.get_resource_amount("food") == 100 - cost, "recruit cost mismatch")
	require(
		game_state.get_life_recruitment_candidates().size() == 3,
		"recruited slot should refill immediately"
	)
	for replacement: Dictionary in game_state.get_life_recruitment_candidates():
		require(
			StringName(replacement.get("candidate_id", &"")) != candidate_id,
			"recruited character remained in the candidate pool"
		)

	game_state.start_new_game()
	game_state.resources["food"] = 0
	var blocked_candidate: Dictionary = game_state.get_life_recruitment_candidates()[0]
	var blocked_id := StringName(blocked_candidate.get("candidate_id", &""))
	var pool_before := JSON.stringify(game_state.get_life_recruitment_state_for_save())
	var roster_before: int = game_state.get_all_life_characters().size()
	require(not game_state.recruit_life_candidate(blocked_id), "insufficient resources allowed recruit")
	require(not game_state.refresh_life_recruitment_candidates(), "insufficient resources allowed refresh")
	require(
		JSON.stringify(game_state.get_life_recruitment_state_for_save()) == pool_before,
		"failed recruit or refresh changed the candidate pool"
	)
	require(
		game_state.get_all_life_characters().size() == roster_before,
		"failed recruit changed CharacterRoster"
	)


func assert_candidate_lock_and_refresh(game_state: Node) -> void:
	game_state.start_new_game()
	game_state.resources["food"] = 20
	var before: Array = game_state.get_life_recruitment_candidates()
	var locked_id := StringName(before[0].get("candidate_id", &""))
	var replaced_ids: Array[StringName] = [
		StringName(before[1].get("candidate_id", &"")),
		StringName(before[2].get("candidate_id", &"")),
	]
	require(
		game_state.set_life_recruitment_candidate_locked(locked_id, true),
		"candidate lock failed"
	)
	require(game_state.refresh_life_recruitment_candidates(), "candidate refresh failed")
	require(game_state.get_resource_amount("food") == 18, "refresh cost should be two food")
	var after: Array = game_state.get_life_recruitment_candidates()
	var locked_after: Dictionary = game_state.get_life_recruitment_candidate(locked_id)
	require(not locked_after.is_empty(), "locked candidate was replaced")
	require(bool(locked_after.get("is_locked", false)), "candidate lock state was lost")
	for replaced_id: StringName in replaced_ids:
		var still_present := false
		for candidate: Dictionary in after:
			if StringName(candidate.get("candidate_id", &"")) == replaced_id:
				still_present = true
		require(not still_present, "unlocked candidate survived refresh")


func assert_capacity_and_residence_growth(game_state: Node) -> void:
	game_state.start_new_game()
	game_state.resources["food"] = 200
	require(game_state.get_life_character_capacity() == 5, "level-1 residence capacity should be five")
	while game_state.get_all_life_characters().size() < game_state.get_life_character_capacity():
		var candidate_id := StringName(
			game_state.get_life_recruitment_candidates()[0].get("candidate_id", &"")
		)
		require(game_state.recruit_life_candidate(candidate_id), "capacity fill recruit failed")
	var blocked_id := StringName(
		game_state.get_life_recruitment_candidates()[0].get("candidate_id", &"")
	)
	require(not game_state.recruit_life_candidate(blocked_id), "full capacity allowed another recruit")
	require(game_state.set_building_level(&"residence", 2), "residence upgrade failed")
	require(game_state.get_life_character_capacity() == 7, "residence level 2 should add two capacity")
	require(game_state.recruit_life_candidate(blocked_id), "expanded capacity did not allow recruit")


func assert_recruited_assignment_and_dismissal(game_state: Node) -> void:
	game_state.start_new_game()
	game_state.resources["food"] = 100
	var candidate: Dictionary = game_state.get_life_recruitment_candidates()[0]
	var character_id := StringName(candidate.get("candidate_id", &""))
	var specialty := StringName(candidate.get("specialty_stat_id", &""))
	require(game_state.recruit_life_candidate(character_id), "dismissal setup recruit failed")
	var job_target: Dictionary = get_job_target_for_stat(specialty)
	require(
		game_state.assign_life_character_to_job(
			character_id,
			StringName(job_target.get("building_id", &"")),
			StringName(job_target.get("job_id", &""))
		),
		"recruited character should enter the existing job system immediately"
	)
	require(game_state.set_life_character_locked(character_id, true), "formal lock failed")
	require(not game_state.dismiss_life_character(character_id), "locked formal character was dismissed")
	require(game_state.set_life_character_locked(character_id, false), "formal unlock failed")
	require(game_state.dismiss_life_character(character_id, true), "working character dismissal failed")
	require(not game_state.has_roster_character(character_id), "dismissed character remained in roster")
	var jobs: Array = game_state.get_building_jobs(StringName(job_target.get("building_id", &"")))
	require(
		StringName(jobs[0].get("character_id", &"")) == &"",
		"dismissal left a stale building job reference"
	)
	require(not game_state.dismiss_life_character(&"guard"), "combat character dismissal was allowed")

	game_state.start_new_game()
	require(
		game_state.dismiss_life_character(&"life_xiaoyao"),
		"default test life characters should follow the same dismissal rule"
	)
	require(not game_state.has_roster_character(&"life_xiaoyao"), "default life dismissal failed")


func assert_filter_and_sort(game_state: Node) -> void:
	game_state.start_new_game()
	require(
		game_state.assign_life_character_to_job(&"life_ahe", &"farm", &"farmer"),
		"filter setup assignment failed"
	)
	require(
		game_state.get_filtered_sorted_life_characters(&"working", &"created").size() == 1,
		"working filter failed"
	)
	require(
		game_state.get_filtered_sorted_life_characters(&"idle", &"created").size() == 2,
		"idle filter failed"
	)
	var farming: Array = game_state.get_filtered_sorted_life_characters(&"farming", &"created")
	require(
		farming.size() == 1
			and StringName(farming[0].get("character_id", &"")) == &"life_ahe",
		"primary-stat filter failed"
	)
	var medical_sorted: Array = game_state.get_filtered_sorted_life_characters(&"all", &"medical")
	require(
		StringName(medical_sorted[0].get("character_id", &"")) == &"life_xiaoyao",
		"medical sort failed"
	)
	var created_sorted: Array = game_state.get_filtered_sorted_life_characters(&"all", &"created")
	require(
		StringName(created_sorted[0].get("character_id", &"")) == &"life_ahe",
		"created-order sort failed"
	)
	game_state.character_roster.get_character(&"life_atie").quality = CharacterEnumsScript.Quality.EPIC
	var quality_sorted: Array = game_state.get_filtered_sorted_life_characters(&"all", &"quality")
	require(
		StringName(quality_sorted[0].get("character_id", &"")) == &"life_atie",
		"quality sort failed"
	)


func assert_v5_round_trip_and_candidate_repair(game_state: Node) -> void:
	game_state.start_new_game()
	game_state.resources["food"] = 100
	var initial: Array = game_state.get_life_recruitment_candidates()
	var locked_candidate_id := StringName(initial[0].get("candidate_id", &""))
	require(
		game_state.set_life_recruitment_candidate_locked(locked_candidate_id, true),
		"save setup candidate lock failed"
	)
	require(game_state.refresh_life_recruitment_candidates(), "save setup refresh failed")
	var recruit_target: Dictionary = game_state.get_life_recruitment_candidates()[1]
	var recruited_id := StringName(recruit_target.get("candidate_id", &""))
	var recruit_cost := int(recruit_target.get("recruitment_cost", 0))
	require(game_state.recruit_life_candidate(recruited_id), "save setup recruit failed")
	require(game_state.set_life_character_locked(recruited_id, true), "save setup formal lock failed")
	game_state.add_life_character_experience(recruited_id, 120)
	var expected_food := 98 - recruit_cost
	var expected_candidate_ids := get_candidate_ids(game_state.get_life_recruitment_candidates())
	var save_data: Dictionary = game_state.create_save_data()
	require(int(save_data.get("save_version", 0)) == 6, "Stage 12F save version should be six")
	require(save_data.has("life_recruitment_state"), "candidate pool missing from v5 save")
	require(
		save_data.get("life_recruitment_state", {}).get("random_state") is String,
		"64-bit recruitment RNG state should be serialized losslessly"
	)
	var parsed = JSON.parse_string(JSON.stringify(save_data))
	require(parsed is Dictionary, "v5 save did not survive JSON serialization")
	game_state.start_new_game()
	require(game_state.load_save_data(parsed), game_state.get_save_error())
	require(game_state.get_resource_amount("food") == expected_food, "v5 resources did not round trip")
	var recruited: Dictionary = game_state.get_roster_character(recruited_id)
	require(not recruited.is_empty(), "recruited formal character did not round trip")
	require(bool(recruited.get("is_locked", false)), "formal lock did not round trip")
	require(int(recruited.get("level", 0)) == 2, "recruited level did not round trip")
	require(int(recruited.get("experience", -1)) == 20, "recruited experience did not round trip")
	require(
		get_candidate_ids(game_state.get_life_recruitment_candidates()) == expected_candidate_ids,
		"candidate ids did not round trip"
	)
	require(
		bool(game_state.get_life_recruitment_candidate(locked_candidate_id).get("is_locked", false)),
		"candidate lock did not round trip"
	)
	require(
		int(game_state.life_recruitment_state.get("refresh_sequence", 0)) == 1,
		"candidate refresh sequence did not round trip"
	)

	var corrupt := save_data.duplicate(true)
	corrupt["life_recruitment_state"]["candidates"][0]["character"]["character_id"] = &"life_ahe"
	corrupt["life_recruitment_state"]["candidates"][1]["character"]["character_id"] = &"life_ahe"
	require(game_state.load_save_data(corrupt), game_state.get_save_error())
	var repaired_ids := get_candidate_ids(game_state.get_life_recruitment_candidates())
	require(repaired_ids.size() == 3, "corrupt candidate pool was not refilled")
	var seen: Dictionary = {}
	for candidate_id: StringName in repaired_ids:
		require(not seen.has(candidate_id), "duplicate candidate id survived load repair")
		require(not game_state.has_roster_character(candidate_id), "candidate/formal id conflict survived repair")
		seen[candidate_id] = true


func assert_v0_to_v4_migrations(game_state: Node) -> void:
	for version: int in range(5):
		game_state.start_new_game()
		game_state.resources["food"] = 70 + version
		if version == 4:
			game_state.add_life_character_experience(&"life_ahe", 120)
		var old_save: Dictionary = game_state.create_save_data()
		old_save["save_version"] = version
		old_save.erase("life_recruitment_state")
		if version == 0:
			old_save.erase("character_roster")
		require(game_state.load_save_data(old_save), "v%d migration failed" % version)
		require(
			game_state.get_life_recruitment_candidates().size() == 3,
			"v%d migration did not create three candidates" % version
		)
		require(
			game_state.get_resource_amount("food") == 70 + version,
			"v%d migration overwrote resources" % version
		)
		if version == 4:
			var migrated: Dictionary = game_state.get_roster_character(&"life_ahe")
			require(int(migrated.get("level", 0)) == 2, "v4 life level was not preserved")
			require(int(migrated.get("experience", -1)) == 20, "v4 life experience was not preserved")
		var seen: Dictionary = {}
		for candidate: Dictionary in game_state.get_life_recruitment_candidates():
			var candidate_id := StringName(candidate.get("candidate_id", &""))
			require(not seen.has(candidate_id), "v%d migration produced duplicate candidates" % version)
			require(not game_state.has_roster_character(candidate_id), "v%d migration produced id conflict" % version)
			seen[candidate_id] = true


func assert_stage12e_ui(game_state: Node) -> void:
	game_state.start_new_game()
	var main_scene: PackedScene = load("res://features/main/main.tscn")
	var main_view := main_scene.instantiate()
	root.add_child(main_view)
	await process_frame
	await process_frame
	var village_view = main_view.find_child("VillageView", true, false)
	require(village_view != null, "VillageView not found")
	village_view.show_life_character_page()
	await process_frame
	require(village_view.life_filter_option.item_count == 8, "life filter UI options missing")
	require(village_view.life_sort_option.item_count == 8, "life sort UI options missing")
	require(String(village_view.life_capacity_label.text).contains("3 / 5"), "capacity UI missing")
	require(village_view.life_lock_button != null, "formal lock UI missing")
	require(village_view.life_dismiss_button != null, "dismiss UI missing")
	require(village_view.life_dismiss_confirm_dialog != null, "dismiss confirmation missing")
	village_view.show_life_recruitment_page()
	await process_frame
	require(
		village_view.life_recruitment_candidate_box.get_child_count() == 3,
		"recruitment page should show three candidate cards"
	)
	require(
		village_view.find_child("RefreshLifeCandidatesButton", true, false) != null,
		"candidate refresh UI missing"
	)
	var first_candidate: Dictionary = game_state.get_life_recruitment_candidates()[0]
	require(
		village_view.find_child(
			"%sRecruitButton" % String(first_candidate.get("candidate_id", &"")).to_pascal_case(),
			true,
			false
		) != null,
		"candidate recruit button missing"
	)
	main_view.queue_free()


func get_job_target_for_stat(stat_id: StringName) -> Dictionary:
	match stat_id:
		&"farming":
			return {"building_id": &"farm", "job_id": &"farmer"}
		&"crafting":
			return {"building_id": &"food_workshop", "job_id": &"food_crafter"}
		&"gathering":
			return {"building_id": &"resource_collection", "job_id": &"gatherer"}
		&"research":
			return {"building_id": &"research_lab", "job_id": &"researcher"}
		&"medical":
			return {"building_id": &"hospital", "job_id": &"medic"}
	return {}


func get_candidate_ids(candidates: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for candidate: Dictionary in candidates:
		result.append(StringName(candidate.get("candidate_id", &"")))
	return result


func require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

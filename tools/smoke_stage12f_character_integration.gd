extends SceneTree

const BattleViewScript := preload("res://features/battle/battle_view.gd")
const CharacterEnumsScript := preload("res://scripts/data/character_enums.gd")
const Stage12Config := preload("res://scripts/data/stage12_balance_config.gd")


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var game_state = root.get_node("/root/GameState")
	assert_central_config_and_boundaries(game_state)
	assert_battle_growth_feedback_and_idempotency(game_state)
	assert_life_growth_feedback_and_idempotency(game_state)
	assert_portraits_recruitment_and_operation_feedback(game_state)
	assert_v6_round_trip_and_v0_to_v5_migrations(game_state)
	await assert_stage12f_ui_and_session_state(game_state)
	print("stage12f character integration smoke ok")
	quit()


func assert_central_config_and_boundaries(game_state: Node) -> void:
	game_state.start_new_game()
	var config: Dictionary = game_state.get_stage12_balance_config()
	require(int(config.get("config_version", 0)) == 1, "Stage 12 config version missing")
	require(int(config.get("combat_max_level", 0)) == 50, "combat max level config mismatch")
	require(int(config.get("life_max_level", 0)) == 50, "life max level config mismatch")
	require(int(config.get("max_party_size", 0)) == 4, "party max size is not centralized")
	require(int(config.get("refresh_cost", 0)) == 2, "refresh cost is not centralized")
	require(config.get("life_trait_config", {}).size() >= 5, "life trait values missing")
	require(config.get("job_config_by_building", {}).has(&"farm"), "job config missing")
	require(config.get("life_portrait_paths", []).size() >= 5, "portrait pool missing")
	for portrait_path: String in config.get("life_portrait_paths", []):
		require(ResourceLoader.exists(portrait_path), "configured portrait does not exist")

	require(not game_state.set_party_members([]), "empty party should be rejected")
	require(
		not game_state.set_party_members([&"guard", &"hunter", &"mage", &"doctor", &"guard"]),
		"party larger than four should be rejected"
	)
	require(
		not game_state.set_party_members([&"guard", &"guard"]),
		"duplicate party member should be rejected"
	)
	require(game_state.set_party_members([&"guard", &"mage"]), "valid party was rejected")
	require(game_state.get_character_ids().size() == 2, "valid party size mismatch")
	game_state.expedition_state = {"is_active": true}
	require(
		not game_state.set_party_members([&"guard"]),
		"active expedition allowed party editing"
	)
	require(
		String(game_state.get_last_operation_feedback().get("message", "")).contains("远征"),
		"active-expedition party error feedback missing"
	)
	game_state.expedition_state = {}

	var guard_record = game_state.character_roster.get_character(&"guard")
	guard_record.combat_data.base_combat_stats.crit_rate = 5.0
	guard_record.combat_data.base_combat_stats.crit_damage = 9.0
	guard_record.combat_data.current_hp = 999999
	game_state.clamp_character_runtime_hp_to_final_max(&"guard")
	var guard_stats: Dictionary = game_state.get_final_combat_stats(&"guard")
	require(float(guard_stats.get("crit_rate", -1.0)) <= 1.0, "crit rate exceeded 100 percent")
	require(float(guard_stats.get("crit_damage", -1.0)) <= 5.0, "crit damage exceeded configured cap")
	require(
		int(game_state.get_character_runtime_state(&"guard").get("current_hp", 0))
			<= int(guard_stats.get("max_hp", 0)),
		"current hp exceeded final max hp"
	)
	require(
		game_state.character_roster.set_character_progression(&"guard", 50, 999999, 999999),
		"combat max-level setup failed"
	)
	var capped_combat: Dictionary = game_state.grant_character_experience(&"guard", 999999)
	require(int(capped_combat.get("new_level", 0)) == 50, "combat level exceeded cap")
	require(int(capped_combat.get("levels_gained", -1)) == 0, "max combat character leveled")
	require(int(capped_combat.get("experience", -1)) == 0, "max combat experience rule mismatch")
	require(
		int(capped_combat.get("discarded_experience", 0)) == 999999,
		"max combat overflow was not discarded"
	)
	require(
		game_state.character_roster.get_experience_to_next_level(50) == 0,
		"max combat requirement must be zero"
	)

	var life_record = game_state.character_roster.get_character(&"life_ahe")
	life_record.life_data.life_stats.set_core_stat(&"farming", 99)
	require(
		game_state.character_roster.set_character_progression(&"life_ahe", 49, 0, 0),
		"life max-level setup failed"
	)
	var capped_life: Dictionary = game_state.add_life_character_experience(&"life_ahe", 2500)
	require(int(capped_life.get("new_level", 0)) == 50, "life level did not reach cap")
	require(
		int(game_state.get_roster_character(&"life_ahe").get(
			"life_data", {}
		).get("life_stats", {}).get("farming", 0)) == 100,
		"life stat did not respect the 100 cap"
	)
	require(game_state.get_life_character_upgrade_requirement(&"life_ahe") == 0, "max life requirement must be zero")
	var life_overflow: Dictionary = game_state.add_life_character_experience(&"life_ahe", 500)
	require(int(life_overflow.get("levels_gained", -1)) == 0, "max life character leveled")
	require(int(life_overflow.get("experience", -1)) == 0, "max life experience rule mismatch")

	var generated_ids: Dictionary = {}
	for _index: int in range(100):
		var generated_id: StringName = game_state.generate_character_id("life")
		require(not generated_ids.has(generated_id), "generated character id repeated")
		require(not game_state.has_roster_character(generated_id), "generated id conflicts with roster")
		generated_ids[generated_id] = true


func assert_battle_growth_feedback_and_idempotency(game_state: Node) -> void:
	game_state.start_new_game()
	require(
		game_state.character_roster.set_character_progression(&"guard", 1, 90, 100),
		"battle feedback progression setup failed"
	)
	var victory_result := {
		"outcome": "victory",
		"node_id": &"forest_crossroads",
		"is_boss": false,
		"party_states": [
			{"character_id": &"guard"},
			{"character_id": &"mage"},
			{"character_id": &"guard"},
		],
	}
	game_state.process_battle_result(victory_result)
	var completed: Dictionary = game_state.get_last_battle_result()
	require(int(completed.get("experience_reward", 0)) == 40, "normal victory reward mismatch")
	require(completed.get("experience_results", []).size() == 2, "deployed result list was not deduplicated")
	var guard_result := find_result(completed.get("experience_results", []), &"guard")
	require(int(guard_result.get("old_level", 0)) == 1, "battle old level missing")
	require(int(guard_result.get("new_level", 0)) == 2, "battle new level missing")
	require(int(guard_result.get("levels_gained", 0)) == 1, "battle upgrade count missing")
	require(not guard_result.get("stat_changes", {}).is_empty(), "battle major stat changes missing")
	require(
		int(game_state.get_roster_character(&"doctor").get("experience", -1)) == 0,
		"standby character received battle experience"
	)
	var guard_experience_after := int(
		game_state.get_roster_character(&"guard").get("experience", -1)
	)
	game_state.process_battle_result(completed)
	require(
		int(game_state.get_roster_character(&"guard").get("experience", -1))
			== guard_experience_after,
		"showing or reprocessing the result awarded experience twice"
	)

	var battle_view = BattleViewScript.new()
	battle_view.game_state = game_state
	var formatted := battle_view.format_battle_experience_result(completed)
	require(formatted.contains("经验 +40"), "battle result UI text lacks experience")
	require(formatted.contains("Lv.1 → Lv.2"), "battle result UI text lacks before/after level")
	require(formatted.contains("升级 ×1"), "battle result UI text lacks consecutive upgrade count")
	require(formatted.contains("主要属性"), "battle result UI text lacks stat growth")
	require(formatted.contains("待命角色未出战"), "standby explanation missing")
	battle_view.free()

	game_state.start_new_game()
	game_state.process_battle_result({
		"outcome": "victory",
		"node_id": &"ruins_core",
		"is_boss": true,
		"party_states": [{"character_id": &"guard"}],
	})
	require(
		int(game_state.get_last_battle_result().get("experience_reward", 0)) == 100,
		"boss victory reward mismatch"
	)

	game_state.start_new_game()
	game_state.process_battle_result({
		"outcome": "defeat",
		"node_id": &"forest_crossroads",
		"is_boss": false,
		"party_states": [{"character_id": &"guard"}],
	})
	var defeat_result: Dictionary = game_state.get_last_battle_result()
	require(int(defeat_result.get("experience_reward", 0)) == 10, "defeat reward must remain ten")
	require(
		int(find_result(defeat_result.get("experience_results", []), &"guard").get(
			"experience_gained", 0
		)) == 10,
		"defeat feedback did not expose ten experience"
	)

	game_state.start_new_game()
	var multi_level: Dictionary = game_state.grant_character_experience(&"guard", 800)
	require(int(multi_level.get("levels_gained", 0)) >= 3, "continuous level-up feedback missing")
	require(not multi_level.get("stat_changes", {}).is_empty(), "continuous growth details missing")


func assert_life_growth_feedback_and_idempotency(game_state: Node) -> void:
	game_state.start_new_game()
	require(
		game_state.assign_life_character_to_job(&"life_ahe", &"farm", &"farmer"),
		"life feedback assignment failed"
	)
	game_state.advance_day("stage12f_farm_day_1", false)
	var report: Dictionary = game_state.advance_day("stage12f_farm_day_2", false)
	require(not report.get("farm_harvests", []).is_empty(), "farm did not complete valid work")
	var feedback: Dictionary = game_state.get_recent_life_work_feedback(&"farm")
	require(not feedback.is_empty(), "building recent work feedback missing")
	require(feedback.get("work_experience_results", []).size() == 1, "work participant missing")
	var worker_result: Dictionary = feedback.get("work_experience_results", [])[0]
	require(StringName(worker_result.get("character_id", &"")) == &"life_ahe", "wrong work participant")
	require(int(worker_result.get("experience_gained", 0)) == 12, "work experience feedback mismatch")
	require(float(feedback.get("final_production_multiplier", 0.0)) > 1.0, "final multiplier missing")
	require(int(feedback.get("output_amount", 0)) >= int(feedback.get("base_output_amount", 0)), "output feedback invalid")
	require(not game_state.get_gameplay_notifications().is_empty(), "work notification missing")
	var experience_after := int(game_state.get_roster_character(&"life_ahe").get("experience", -1))
	require(
		game_state.settle_life_job_work_experience(&"farm", &"farm_day_2").is_empty(),
		"duplicate life settlement was accepted"
	)
	require(
		int(game_state.get_roster_character(&"life_ahe").get("experience", -1))
			== experience_after,
		"duplicate work settlement changed experience"
	)

	game_state.start_new_game()
	require(
		game_state.character_roster.set_character_progression(&"life_ahe", 1, 90, 100),
		"life upgrade feedback setup failed"
	)
	var upgrade: Dictionary = game_state.add_life_character_experience(&"life_ahe", 280)
	require(int(upgrade.get("levels_gained", 0)) == 2, "life consecutive upgrade count mismatch")
	require(not upgrade.get("growth_by_stat", {}).is_empty(), "life grown stat feedback missing")


func assert_portraits_recruitment_and_operation_feedback(game_state: Node) -> void:
	game_state.start_new_game()
	var candidates: Array = game_state.get_life_recruitment_candidates()
	require(candidates.size() == Stage12Config.CANDIDATE_COUNT, "candidate pool size mismatch")
	for candidate: Dictionary in candidates:
		var portrait_path: String = game_state.get_candidate_portrait_path(candidate)
		require(ResourceLoader.exists(portrait_path), "candidate portrait missing")
	var duplicate_portrait_candidate: Dictionary = game_state.generate_life_character_candidate(
		CharacterEnumsScript.Quality.COMMON
	)
	require(
		ResourceLoader.exists(game_state.get_candidate_portrait_path(duplicate_portrait_candidate)),
		"portrait selection blocked candidate generation"
	)
	require(
		game_state.get_candidate_portrait_path({
			"character": {"portrait_path": "res://missing/stage12f_portrait.png"}
		}) == Stage12Config.DEFAULT_LIFE_PORTRAIT_PATH,
		"missing candidate portrait did not use fallback"
	)

	game_state.resources["food"] = 100
	var candidate: Dictionary = candidates[0]
	var candidate_id := StringName(candidate.get("candidate_id", &""))
	var portrait_before: String = game_state.get_candidate_portrait_path(candidate)
	var cost := int(candidate.get("recruitment_cost", 0))
	require(game_state.recruit_life_candidate(candidate_id), "candidate recruitment failed")
	require(
		game_state.get_character_portrait_path(candidate_id) == portrait_before,
		"portrait changed after formal recruitment"
	)
	var food_after_recruit: int = game_state.get_resource_amount("food")
	require(food_after_recruit == 100 - cost, "recruit cost mismatch")
	require(not game_state.recruit_life_candidate(candidate_id), "duplicate recruit succeeded")
	require(
		game_state.get_resource_amount("food") == food_after_recruit,
		"duplicate recruit deducted resources"
	)
	require(
		not String(game_state.get_last_operation_feedback().get("message", "")).is_empty(),
		"duplicate recruit failure reason missing"
	)

	var new_candidate: Dictionary = game_state.get_life_recruitment_candidates()[0]
	var locked_candidate_id := StringName(new_candidate.get("candidate_id", &""))
	require(
		game_state.set_life_recruitment_candidate_locked(locked_candidate_id, true),
		"candidate lock failed"
	)
	require(game_state.refresh_life_recruitment_candidates(), "candidate refresh failed")
	require(
		not game_state.get_life_recruitment_candidate(locked_candidate_id).is_empty(),
		"refresh removed locked candidate"
	)
	require(
		String(game_state.get_last_operation_feedback().get("message", "")).contains("刷新成功"),
		"refresh success feedback missing"
	)

	require(
		game_state.assign_life_character_to_job(candidate_id, &"research_lab", &"researcher"),
		"recruited worker assignment failed"
	)
	require(not game_state.dismiss_life_character(candidate_id, false), "working dismiss skipped confirmation guard")
	require(game_state.dismiss_life_character(candidate_id, true), "confirmed working dismiss failed")
	require(not game_state.has_roster_character(candidate_id), "dismissed character remained in roster")
	require(
		StringName(game_state.get_building_jobs(&"research_lab")[0].get("character_id", &"")) == &"",
		"dismissed worker left a job reference"
	)
	require(
		String(game_state.get_last_operation_feedback().get("message", "")).contains("解雇成功"),
		"dismiss success feedback missing"
	)

	game_state.start_new_game()
	game_state.resources["food"] = 0
	var blocked_id := StringName(
		game_state.get_life_recruitment_candidates()[0].get("candidate_id", &"")
	)
	require(not game_state.recruit_life_candidate(blocked_id), "insufficient food allowed recruit")
	require(
		String(game_state.get_last_operation_feedback().get("message", "")).contains("粮食"),
		"insufficient-food feedback missing"
	)

	require(game_state.set_party_members([&"guard"]), "status party setup failed")
	var guard_status := " ".join(game_state.get_character_status_labels(&"guard"))
	var hunter_status := " ".join(game_state.get_character_status_labels(&"hunter"))
	var life_status := " ".join(game_state.get_character_status_labels(&"life_ahe"))
	require(guard_status.contains("出战"), "deployed text status missing")
	require(hunter_status.contains("待命"), "standby text status missing")
	require(life_status.contains("空闲"), "idle text status missing")
	require(game_state.set_life_character_locked(&"life_ahe", true), "formal lock setup failed")
	require(
		" ".join(game_state.get_character_status_labels(&"life_ahe")).contains("已锁定"),
		"locked text status missing"
	)


func assert_v6_round_trip_and_v0_to_v5_migrations(game_state: Node) -> void:
	game_state.start_new_game()
	game_state.resources["food"] = 100
	var target: Dictionary = game_state.get_life_recruitment_candidates()[0]
	var target_id := StringName(target.get("candidate_id", &""))
	var expected_portrait: String = game_state.get_candidate_portrait_path(target)
	require(game_state.recruit_life_candidate(target_id), "v6 portrait setup recruit failed")
	require(
		game_state.assign_life_character_to_job(target_id, &"research_lab", &"researcher"),
		"v6 job setup failed"
	)
	var manual_feedback: Dictionary = game_state.record_life_work_feedback(&"research_lab", {
		"work_experience_results": [{
			"success": true,
			"character_id": target_id,
			"experience_gained": 10,
			"levels_gained": 0,
			"growth_by_stat": {},
		}],
		"production_details": {"final_production_multiplier": 1.25},
		"base_output_amount": 1,
		"output_amount": 1,
	})
	require(not manual_feedback.is_empty(), "v6 work feedback setup failed")
	var save_data: Dictionary = game_state.create_save_data()
	require(int(save_data.get("save_version", 0)) == 6, "save version is not v6")
	require(save_data.has("gameplay_notifications"), "notifications missing from v6 save")
	require(save_data.has("recent_life_work_results_by_building"), "work feedback missing from v6 save")
	var parsed = JSON.parse_string(JSON.stringify(save_data))
	require(parsed is Dictionary, "v6 data failed JSON round trip")
	game_state.start_new_game()
	require(game_state.load_save_data(parsed), game_state.get_save_error())
	require(game_state.get_character_portrait_path(target_id) == expected_portrait, "portrait did not round trip")
	require(not game_state.get_recent_life_work_feedback(&"research_lab").is_empty(), "work feedback did not round trip")
	require(not game_state.get_gameplay_notifications().is_empty(), "notifications did not round trip")
	require(
		StringName(game_state.get_roster_character(target_id).get(
			"life_data", {}
		).get("assigned_building_id", &"")) == &"research_lab",
		"job assignment did not round trip"
	)

	for version: int in range(6):
		game_state.start_new_game()
		game_state.resources["food"] = 60 + version
		var old_save: Dictionary = game_state.create_save_data()
		old_save["save_version"] = version
		old_save.erase("stage12_config_version")
		old_save.erase("gameplay_notifications")
		old_save.erase("recent_life_work_results_by_building")
		old_save.erase("next_gameplay_notification_sequence")
		if version == 0:
			old_save.erase("character_roster")
		else:
			for raw_character in old_save.get("character_roster", {}).get("characters", []):
				if not raw_character is Dictionary:
					continue
				var character: Dictionary = raw_character
				if StringName(character.get("character_id", &"")) != &"life_ahe":
					continue
				character["portrait_path"] = "res://missing/old_portrait.png"
				character["level"] = 99
				character["experience"] = 999999
				character["life_data"]["life_stats"]["farming"] = 150
		require(game_state.load_save_data(old_save), "v%d migration failed" % version)
		require(game_state.get_resource_amount("food") == 60 + version, "migration changed resources")
		require(game_state.get_life_recruitment_candidates().size() == 3, "migration candidate repair failed")
		if version > 0:
			var migrated: Dictionary = game_state.get_roster_character(&"life_ahe")
			require(int(migrated.get("level", 0)) == 50, "migration did not clamp level")
			require(int(migrated.get("experience", -1)) == 0, "migration did not clear max-level exp")
			require(
				int(migrated.get("life_data", {}).get("life_stats", {}).get("farming", 0)) == 100,
				"migration did not clamp life stat"
			)
			require(
				game_state.get_character_portrait_path(&"life_ahe")
					== Stage12Config.DEFAULT_LIFE_PORTRAIT_PATH,
				"migration did not repair missing portrait"
			)
		require(game_state.get_gameplay_notifications().is_empty(), "old save created corrupt notifications")


func assert_stage12f_ui_and_session_state(game_state: Node) -> void:
	game_state.start_new_game()
	var main_scene: PackedScene = load("res://features/main/main.tscn")
	var main_view := main_scene.instantiate()
	root.add_child(main_view)
	await process_frame
	await process_frame
	var village_view = main_view.find_child("VillageView", true, false)
	var battle_view = main_view.find_child("BattleView", true, false)
	require(village_view != null, "VillageView missing")
	require(battle_view != null, "BattleView missing")
	var combat_entry = village_view.find_child(
		"OpenCombatCharactersButton", true, false
	)
	var life_entry = village_view.find_child(
		"OpenLifeCharactersButton", true, false
	)
	require(village_view.function_dock != null, "main function dock missing")
	require(combat_entry is Button, "combat character dock button missing")
	require(life_entry is Button, "life character dock button missing")
	combat_entry.pressed.emit()
	require(village_view.character_page.visible, "combat dock button did not open its page")
	village_view.hide_character_page()
	life_entry.pressed.emit()
	require(village_view.life_character_page.visible, "life dock button did not open its page")
	village_view.hide_life_character_page()

	village_view.refresh_daily_report({
		"day_before": 7,
		"food_produced": 1,
		"project_report": null,
		"forge_report": "damaged",
		"farm_harvests": null,
		"farm_plot_updates": ["damaged"],
		"daily_summary_lines": null,
	})
	require(
		String(village_view.daily_report_label.text).contains("第 7 天结算"),
		"partial legacy daily report did not use the fallback day"
	)
	require(
		String(village_view.daily_report_label.text).contains("农田生产粮食：+1"),
		"partial legacy daily report lost valid fields"
	)

	village_view.show_character_page()
	await process_frame
	require(village_view.character_experience_bar != null, "combat experience bar missing")
	require(String(village_view.character_basic_label.text).contains("Lv."), "combat hierarchy lacks level")
	require(String(village_view.character_party_label.text).contains("出战"), "combat text status missing")

	village_view.show_life_character_page()
	await process_frame
	require(village_view.life_character_portrait.texture != null, "life portrait UI missing")
	require(village_view.life_character_experience_bar != null, "life experience bar missing")
	require(String(village_view.life_character_basic_label.text).contains("品质"), "life hierarchy lacks quality")
	require(String(village_view.life_character_basic_label.text).contains("状态"), "life work status missing")
	village_view.life_filter_id = &"medical"
	village_view.life_sort_id = &"medical"
	village_view.rebuild_life_character_buttons()
	village_view.refresh_life_character_page()
	var roster_order_before: Array[StringName] = game_state.get_roster_character_ids()
	village_view.hide_life_character_page()
	village_view.show_life_character_page()
	require(village_view.life_filter_id == &"medical", "filter did not persist in session")
	require(village_view.life_sort_id == &"medical", "sort did not persist in session")
	require(game_state.get_roster_character_ids() == roster_order_before, "UI sort mutated roster order")

	var dismissed_selection: StringName = village_view.selected_life_character_id
	require(game_state.dismiss_life_character(dismissed_selection), "selected-dismiss UI setup failed")
	await process_frame
	village_view.rebuild_life_character_buttons()
	village_view.refresh_life_character_page()
	require(
		village_view.selected_life_character_id != dismissed_selection,
		"dismissed selection was not replaced"
	)
	require(
		village_view.selected_life_character_id == &""
			or game_state.has_roster_character(village_view.selected_life_character_id),
		"replacement selection is invalid"
	)

	game_state.start_new_game()
	game_state.life_recruitment_state["candidates"][0]["character"]["quality"] = (
		CharacterEnumsScript.Quality.EPIC
	)
	village_view.show_life_recruitment_page()
	await process_frame
	require(village_view.life_refresh_confirm_dialog != null, "high-quality refresh confirmation missing")
	village_view.refresh_life_candidates()
	require(village_view.pending_life_refresh_confirmation, "high-quality refresh skipped confirmation")
	village_view.cancel_refresh_life_candidates()
	require(not village_view.pending_life_refresh_confirmation, "refresh confirmation cancel failed")
	require(village_view.life_dismiss_confirm_dialog != null, "dismiss confirmation missing")

	var result_for_ui := {
		"experience_reward": 10,
		"experience_results": [{
			"character_id": &"guard",
			"display_name": "守卫",
			"experience_gained": 10,
			"old_level": 1,
			"new_level": 1,
			"levels_gained": 0,
			"stat_changes": {},
		}],
	}
	require(
		String(battle_view.format_battle_experience_result(result_for_ui)).contains("经验 +10"),
		"battle result detail formatter is not wired"
	)
	main_view.queue_free()


func find_result(results: Array, character_id: StringName) -> Dictionary:
	for result: Dictionary in results:
		if StringName(result.get("character_id", &"")) == character_id:
			return result
	return {}


func require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

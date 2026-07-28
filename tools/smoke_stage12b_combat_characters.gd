extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var game_state = root.get_node("/root/GameState")
	game_state.start_new_game()
	assert_party_formation(game_state)
	assert_experience_and_growth(game_state)
	assert_equipment_and_save(game_state)
	await assert_combat_character_page(game_state)
	print("stage12b combat characters smoke ok")
	quit()


func assert_party_formation(game_state: Node) -> void:
	require(game_state.set_party_members([&"guard", &"mage"]), "party setup should succeed")
	require(game_state.get_character_ids() == [&"guard", &"mage"], "party ids should follow roster slots")
	require(game_state.adventurers.size() == 2, "legacy adventurer snapshot should follow party size")
	require(StringName(game_state.adventurers[0].get("character_id", &"")) == &"guard", "legacy snapshot order mismatch")
	require(game_state.move_party_character(&"mage", 0), "party reorder should succeed")
	require(game_state.get_character_ids() == [&"mage", &"guard"], "party reorder did not persist")
	require(game_state.set_character_party_status(&"mage", false), "party member should be removable")
	require(game_state.get_character_ids() == [&"guard"], "standby state mismatch")
	require(not game_state.set_character_party_status(&"guard", false), "party must retain one member")
	require(game_state.set_party_members([&"guard", &"mage"]), "party restore should succeed")
	require(game_state.start_battle(&"forest_slime_pair"), "formed party should enter the existing battle system")
	var battle_party: Array = game_state.get_battle_party_states()
	require(battle_party.size() == 2, "battle should use the formed party size")
	require(StringName(battle_party[0].get("character_id", &"")) == &"guard", "battle party first slot mismatch")
	require(StringName(battle_party[1].get("character_id", &"")) == &"mage", "battle party second slot mismatch")
	game_state.battle_state = game_state.battle_system.create_initial_state()


func assert_experience_and_growth(game_state: Node) -> void:
	var doctor_before: Dictionary = game_state.get_roster_character(&"doctor")
	game_state.process_battle_result({
		"outcome": "victory",
		"node_id": &"forest_crossroads",
		"is_boss": false,
		"party_states": [
			{"character_id": &"guard"},
			{"character_id": &"mage"},
		],
	})
	require(int(game_state.get_roster_character(&"guard").get("experience", 0)) == 40, "deployed guard should gain battle experience")
	require(int(game_state.get_roster_character(&"mage").get("experience", 0)) == 40, "deployed mage should gain battle experience")
	require(int(game_state.get_roster_character(&"doctor").get("experience", -1)) == int(doctor_before.get("experience", 0)), "standby doctor must not gain experience")

	var old_stats: Dictionary = game_state.get_final_combat_stats(&"guard")
	var runtime = game_state.character_runtime_states[&"guard"]
	runtime.current_hp = maxi(1, int(old_stats.get("max_hp", 1)) - 5)
	var old_hp: int = runtime.current_hp
	var growth_result: Dictionary = game_state.grant_character_experience(&"guard", 800)
	require(int(growth_result.get("levels_gained", 0)) >= 3, "one reward should support multiple levels")
	var new_stats: Dictionary = game_state.get_final_combat_stats(&"guard")
	require(int(new_stats.get("max_hp", 0)) > int(old_stats.get("max_hp", 0)), "level should grow max hp")
	require(int(new_stats.get("attack", 0)) > int(old_stats.get("attack", 0)), "level should grow attack")
	require(int(game_state.get_character_runtime_state(&"guard").get("current_hp", 0)) == old_hp + int(new_stats.get("max_hp", 0)) - int(old_stats.get("max_hp", 0)), "level-up hp should gain the max-hp delta")


func assert_equipment_and_save(game_state: Node) -> void:
	var attack_before: int = int(game_state.get_final_combat_stats(&"guard").get("attack", 0))
	require(game_state.equip_item(&"guard", &"iron_sword_01"), "existing equipment should equip by character id")
	require(int(game_state.get_final_combat_stats(&"guard").get("attack", 0)) > attack_before, "equipment should immediately affect final stats")
	require(game_state.set_party_members([&"mage", &"guard"]), "saved party order setup failed")
	var save_data: Dictionary = game_state.create_save_data()
	require(int(save_data.get("save_version", 0)) == 6, "current save version should include Stage 12F integration")
	var expected_guard: Dictionary = game_state.get_roster_character(&"guard")

	game_state.start_new_game()
	require(game_state.load_save_data(save_data), game_state.get_save_error())
	require(game_state.get_character_ids() == [&"mage", &"guard"], "party order did not round trip")
	var loaded_guard: Dictionary = game_state.get_roster_character(&"guard")
	require(int(loaded_guard.get("level", 0)) == int(expected_guard.get("level", -1)), "level did not round trip")
	require(int(loaded_guard.get("experience", -1)) == int(expected_guard.get("experience", -2)), "experience did not round trip")
	require(game_state.get_equipped_equipment_instance_id(&"guard", &"weapon") == &"iron_sword_01", "equipment did not round trip")

	var version_one: Dictionary = save_data.duplicate(true)
	version_one["save_version"] = 1
	for character: Dictionary in version_one.get("character_roster", {}).get("characters", []):
		if StringName(character.get("character_id", &"")) == &"guard":
			character["combat_data"]["level_growth_stats"] = {}
	require(game_state.load_save_data(version_one), game_state.get_save_error())
	var migrated_growth: Dictionary = game_state.get_roster_character(&"guard").get("combat_data", {}).get("level_growth_stats", {})
	require(int(migrated_growth.get("max_hp", 0)) == 8, "v1 roster should receive Stage 12B growth defaults")


func assert_combat_character_page(game_state: Node) -> void:
	var main_scene: PackedScene = load("res://features/main/main.tscn")
	var main_view := main_scene.instantiate()
	root.add_child(main_view)
	await process_frame
	await process_frame
	var village_view = main_view.find_child("VillageView", true, false)
	require(village_view != null, "VillageView not found")
	village_view.show_character_page()
	await process_frame
	require(village_view.character_buttons.size() == 4, "combat page should list exactly four fixed combat characters")
	require(not village_view.character_buttons.has(&"life_ahe"), "life character leaked into combat page")
	require(String(village_view.character_basic_label.text).contains("经验"), "character detail should show experience")
	require(String(village_view.character_combat_label.text).contains("暴击率"), "character detail should show crit rate")
	require(not String(village_view.character_skill_label.text).is_empty(), "character detail should show skills")
	require(String(village_view.character_party_label.text).contains("出战顺序"), "character detail should show party position")
	main_view.queue_free()


func require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

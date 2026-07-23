extends SceneTree

const CharacterEnumsScript := preload("res://scripts/data/character_enums.gd")

const TEST_SAVE_PATH := "user://stage12a_character_roster_test.json"


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var game_state = root.get_node("/root/GameState")
	game_state.start_new_game()
	assert_default_roster(game_state)
	assert_manager_operations(game_state)
	assert_save_round_trip(game_state)
	assert_legacy_save_migration(game_state)
	assert_battle_compatibility(game_state)
	game_state.print_character_roster_debug()
	_cleanup_test_save()
	print("stage12a character roster smoke ok")
	quit()


func assert_default_roster(game_state: Node) -> void:
	var combat: Array = game_state.get_all_combat_characters()
	var life: Array = game_state.get_all_life_characters()
	require(combat.size() == 4, "default combat roster should contain four characters")
	require(life.size() == 3, "default life roster should contain three characters")
	require(game_state.get_character_ids() == [&"guard", &"hunter", &"mage", &"doctor"], "existing party order changed")
	var seen_ids: Dictionary = {}
	for character: Dictionary in combat + life:
		var character_id := StringName(character.get("character_id", &""))
		require(character_id != &"", "character id must not be empty")
		require(not seen_ids.has(character_id), "character ids must be unique")
		seen_ids[character_id] = true
		require(int(character.get("level", 0)) == 1, "default level should be one")
		require(int(character.get("experience_to_next_level", 0)) > 0, "experience requirement must be positive")
	if not life.is_empty():
		var stats: Dictionary = life[0].get("life_data", {}).get("life_stats", {})
		for stat_id: String in ["farming", "crafting", "gathering", "research", "medical"]:
			require(stats.has(stat_id), "missing life stat: %s" % stat_id)
	require(String(game_state.get_roster_character(&"life_ahe").get("display_name", "")) == "阿禾", "default farmer missing")
	require(String(game_state.get_roster_character(&"life_atie").get("display_name", "")) == "阿铁", "default crafter missing")
	require(String(game_state.get_roster_character(&"life_xiaoyao").get("display_name", "")) == "小药", "default medic missing")


func assert_manager_operations(game_state: Node) -> void:
	var generated_id: StringName = game_state.generate_character_id("life")
	require(not game_state.has_roster_character(generated_id), "generated id should be unused")
	var temporary_life := {
		"character_id": generated_id,
		"character_type": CharacterEnumsScript.CharacterType.LIFE,
		"display_name": "临时测试员",
		"level": 1,
		"created_sequence": 999,
		"life_data": {
			"life_stats": {"farming": 10, "crafting": 10, "gathering": 10, "research": 10, "medical": 10},
			"work_state": CharacterEnumsScript.WorkState.IDLE,
		},
	}
	require(game_state.add_roster_character(temporary_life), "manager should add a valid life character")
	require(game_state.has_roster_character(generated_id), "added character lookup failed")
	require(game_state.remove_roster_character(generated_id), "manager should remove an unlocked character")
	require(not game_state.remove_roster_character(&"guard"), "locked default combat character should not be removed")


func assert_save_round_trip(game_state: Node) -> void:
	require(game_state.set_character_progression(&"hunter", 3, 45, 180), "combat progression update failed")
	require(game_state.set_life_character_assignment(
		&"life_ahe", &"farm", &"farmer", CharacterEnumsScript.WorkState.WORKING
	), "life assignment update failed")
	require(game_state.equip_item(&"hunter", &"hunter_bow_01"), "existing equipment should equip before save")
	game_state.resources["food"] = 73
	var merged: Dictionary = game_state.create_save_data({"future_field": {"preserve_me": true}})
	require(bool(merged.get("future_field", {}).get("preserve_me", false)), "save merge discarded unknown data")
	require(int(merged.get("save_version", 0)) == 2, "save version missing")
	require(game_state.save_game(TEST_SAVE_PATH, {"external_marker": "kept"}), game_state.get_save_error())

	game_state.start_new_game()
	require(game_state.load_game(TEST_SAVE_PATH), game_state.get_save_error())
	require(int(game_state.resources.get("food", 0)) == 73, "resource state did not round trip")
	var hunter: Dictionary = game_state.get_roster_character(&"hunter")
	require(int(hunter.get("level", 0)) == 3, "level did not round trip")
	require(int(hunter.get("experience", 0)) == 45, "experience did not round trip")
	require(int(hunter.get("experience_to_next_level", 0)) == 180, "experience requirement did not round trip")
	var hunter_combat: Dictionary = hunter.get("combat_data", {})
	require(StringName(hunter_combat.get("equipped_weapon_instance_id", &"")) == &"hunter_bow_01", "equipment binding did not round trip")
	var life: Dictionary = game_state.get_roster_character(&"life_ahe").get("life_data", {})
	require(StringName(life.get("assigned_building_id", &"")) == &"farm", "life building assignment did not round trip")
	require(StringName(life.get("assigned_job_id", &"")) == &"farmer", "life job assignment did not round trip")
	require(int(life.get("work_state", -1)) == CharacterEnumsScript.WorkState.WORKING, "life work state did not round trip")
	require(game_state.get_equipped_equipment_instance_id(&"hunter", &"weapon") == &"hunter_bow_01", "Stage 9 equipment adapter lost binding")


func assert_legacy_save_migration(game_state: Node) -> void:
	game_state.start_new_game()
	var legacy_buildings: Dictionary = game_state.buildings.duplicate(true)
	legacy_buildings["farm"]["level"] = 2
	var legacy_battle_state: Dictionary = game_state.battle_system.create_initial_state()
	legacy_battle_state["round_number"] = 7
	var legacy_save := {
		"save_version": 0,
		"current_day": 9,
		"resources": {"food": 66, "medicine": 4, "ore": 8, "herb": 3, "boss_core": 1},
		"buildings": legacy_buildings,
		"battle_state": legacy_battle_state,
		"character_runtime_states": {
			"guard": {"character_id": "guard", "current_hp": 17, "injury_state": "injured"},
			"hunter": {
				"character_id": "hunter",
				"current_hp": 21,
				"equipped_weapon_instance_id": "hunter_bow_01",
				"equipped_weapon_id": "hunter_bow_01",
			},
		},
		"unrelated_old_progress": {"must_survive": 12},
	}
	require(game_state.load_save_data(legacy_save), game_state.get_save_error())
	require(game_state.get_all_combat_characters().size() == 4, "legacy save should receive default combat characters")
	require(game_state.get_all_life_characters().size() == 3, "legacy save should receive default life characters")
	require(int(game_state.current_day) == 9, "legacy day was overwritten")
	require(int(game_state.resources.get("food", 0)) == 66, "legacy resources were overwritten")
	require(int(game_state.buildings.get("farm", {}).get("level", 0)) == 2, "legacy building level was overwritten")
	require(int(game_state.battle_state.get("round_number", 0)) == 7, "legacy battle progress was overwritten")
	require(int(game_state.get_character_runtime_state(&"guard").get("current_hp", 0)) == 17, "legacy character hp was not migrated")
	require(StringName(game_state.get_character_runtime_state(&"guard").get("injury_state", &"")) == &"injured", "legacy injury was not migrated")
	require(game_state.get_equipped_equipment_instance_id(&"hunter", &"weapon") == &"hunter_bow_01", "legacy equipment binding was not migrated")
	var merged_again: Dictionary = game_state.create_save_data(legacy_save)
	require(int(merged_again.get("unrelated_old_progress", {}).get("must_survive", 0)) == 12, "unknown legacy field was discarded")


func assert_battle_compatibility(game_state: Node) -> void:
	game_state.start_new_game()
	require(game_state.start_battle(&"forest_slime_pair"), "existing battle should start from roster adapter")
	var party: Array = game_state.get_battle_party_states()
	require(party.size() == 4, "battle party should still contain four fixed characters")
	for character_id: StringName in [&"guard", &"hunter", &"mage", &"doctor"]:
		require(not find_unit(party, character_id).is_empty(), "battle party missing %s" % String(character_id))
	game_state.battle_state = game_state.battle_system.create_initial_state()


func find_unit(units: Array, character_id: StringName) -> Dictionary:
	for unit: Dictionary in units:
		if StringName(unit.get("character_id", unit.get("unit_id", &""))) == character_id:
			return unit
	return {}


func _cleanup_test_save() -> void:
	var absolute_path: String = ProjectSettings.globalize_path(TEST_SAVE_PATH)
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(absolute_path)


func require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_cleanup_test_save()
	quit(1)

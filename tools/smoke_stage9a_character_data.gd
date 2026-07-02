extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var game_state = root.get_node("/root/GameState")

	game_state.start_new_game()
	assert_initial_character_data(game_state)
	assert_weapon_upgrade(game_state)
	assert_repeated_battle_does_not_stack(game_state)

	game_state.start_new_game()
	assert_armor_upgrade_current_hp_rule(game_state)

	game_state.start_new_game()
	assert_new_game_reset(game_state)

	print("stage9a character data smoke ok")
	quit()


func assert_initial_character_data(game_state) -> void:
	var expected := {
		&"guard": {"max_hp": 40, "attack": 6, "defense": 5, "speed": 3, "name": "阿盾"},
		&"hunter": {"max_hp": 26, "attack": 8, "defense": 2, "speed": 7, "name": "林羽"},
		&"mage": {"max_hp": 22, "attack": 7, "defense": 1, "speed": 5, "name": "米娅"},
		&"doctor": {"max_hp": 24, "attack": 4, "defense": 2, "speed": 6, "name": "露娜"},
	}
	for character_id: StringName in game_state.get_character_ids():
		var detail: Dictionary = game_state.get_character_detail(character_id)
		var definition: Dictionary = detail["definition"]
		var stats: Dictionary = game_state.get_final_combat_stats(character_id)
		var expected_stats: Dictionary = expected[character_id]
		require(String(definition["display_name"]) == String(expected_stats["name"]), "display name mismatch: %s" % String(character_id))
		for stat_id: String in ["max_hp", "attack", "defense", "speed"]:
			require(int(stats[stat_id]) == int(expected_stats[stat_id]), "%s %s mismatch" % [String(character_id), stat_id])
		require(not detail.get("traits", []).is_empty(), "missing trait: %s" % String(character_id))
		require(not detail.get("skills", []).is_empty(), "missing skill: %s" % String(character_id))


func assert_weapon_upgrade(game_state) -> void:
	game_state.resources["ore"] = 4
	require(game_state.start_project(&"weapon_upgrade"), "weapon project should start")
	for index in range(3):
		game_state.advance_day("test_weapon_%d" % index)
	var hunter_stats: Dictionary = game_state.get_final_combat_stat_details(&"hunter")
	require(int(hunter_stats["attack"]["base"]) == 8, "hunter base attack changed")
	require(int(hunter_stats["attack"]["village_bonus"]) == 2, "weapon bonus missing")
	require(int(hunter_stats["attack"]["equipment_bonus"]) == 0, "equipment bonus should be zero")
	require(int(hunter_stats["attack"]["final"]) == 10, "hunter final attack mismatch")
	require(int(game_state.adventurers[1]["attack"]) == 10, "adventurer attack not rebuilt")


func assert_repeated_battle_does_not_stack(game_state) -> void:
	for index in range(3):
		require(game_state.start_battle(&"forest_slime_pair"), "battle should start")
		var party: Array = game_state.get_battle_party_states()
		require(int(party[1]["attack"]) == 10, "battle attack stacked on entry %d" % index)
		game_state.battle_state["is_active"] = false
		game_state.battle_state["party_states"] = []
		game_state.battle_state["enemy_states"] = []
	require(int(game_state.get_final_combat_stats(&"hunter")["attack"]) == 10, "final attack stacked after repeated battles")


func assert_armor_upgrade_current_hp_rule(game_state) -> void:
	game_state.character_runtime_states[&"guard"].current_hp = 10
	game_state.character_runtime_states[&"doctor"].current_hp = 0
	game_state.resources["ore"] = 3
	game_state.resources["herb"] = 1
	require(game_state.start_project(&"armor_upgrade"), "armor project should start")
	for index in range(3):
		game_state.advance_day("test_armor_%d" % index)
	var guard_runtime: Dictionary = game_state.get_character_runtime_state(&"guard")
	var doctor_runtime: Dictionary = game_state.get_character_runtime_state(&"doctor")
	require(int(game_state.get_final_combat_stats(&"guard")["max_hp"]) == 46, "armor max hp missing")
	require(int(guard_runtime["current_hp"]) == 16, "surviving guard current hp should increase")
	require(int(doctor_runtime["current_hp"]) == 0, "defeated doctor should not revive")


func assert_new_game_reset(game_state) -> void:
	require(int(game_state.party_attack_bonus) == 0, "attack bonus did not reset")
	require(int(game_state.party_max_hp_bonus) == 0, "hp bonus did not reset")
	require(int(game_state.get_final_combat_stats(&"guard")["max_hp"]) == 40, "guard max hp did not reset")
	require(int(game_state.get_character_runtime_state(&"doctor")["current_hp"]) == 24, "doctor hp did not reset")
	require(StringName(game_state.get_character_runtime_state(&"guard")["equipped_weapon_id"]) == &"", "weapon slot did not reset")
	require(StringName(game_state.get_character_runtime_state(&"guard")["equipped_armor_id"]) == &"", "armor slot did not reset")


func require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

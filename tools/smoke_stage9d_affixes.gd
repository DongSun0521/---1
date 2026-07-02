extends SceneTree

var failed: bool = false


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var game_state = root.get_node("/root/GameState")
	assert_shield_bash_boost(game_state)
	assert_power_shot_boost(game_state)
	assert_quick_reload(game_state)
	assert_arcane_spread(game_state)
	assert_gentle_healing(game_state)
	assert_defensive_stance(game_state)
	assert_light_leather_first_hit(game_state)
	assert_light_leather_with_defend(game_state)
	assert_group_hit_independent_leather(game_state)
	assert_forge_to_affix_loop(game_state)
	assert_new_game_reset(game_state)

	if failed:
		quit(1)
		return
	print("stage9d affix smoke ok")
	quit()


func assert_shield_bash_boost(game_state) -> void:
	game_state.start_new_game()
	require(game_state.equip_item(&"guard", &"iron_sword_01"), "guard should equip iron sword")
	require(game_state.start_battle(&"forest_slime_pair"), "battle should start")
	force_player_turn(game_state, &"guard")
	require(game_state.execute_battle_action(&"skill", &"forest_slime_01"), "shield bash should execute")
	var event: Dictionary = game_state.get_last_battle_presentation_events()[0]
	require(int(event["damage_values"][0]) == 11, "shield bash boost damage should be 11")
	require(event.get("triggered_affix_ids", []).has(&"shield_bash_damage_boost"), "shield bash affix should trigger")

	game_state.battle_state = game_state.battle_system.create_initial_state()
	require(game_state.start_battle(&"forest_slime_pair"), "battle should restart")
	force_player_turn(game_state, &"guard")
	require(game_state.execute_battle_action(&"basic_attack", &"forest_slime_01"), "basic attack should execute")
	event = game_state.get_last_battle_presentation_events()[0]
	require(int(event["damage_values"][0]) == 8, "iron sword should not boost basic attack")


func assert_power_shot_boost(game_state) -> void:
	game_state.start_new_game()
	require(game_state.equip_item(&"hunter", &"hunter_bow_01"), "hunter should equip hunter bow")
	require(game_state.start_battle(&"forest_slime_pair"), "battle should start")
	force_player_turn(game_state, &"hunter")
	require(game_state.execute_battle_action(&"skill", &"forest_slime_01"), "power shot should execute")
	var event: Dictionary = game_state.get_last_battle_presentation_events()[0]
	require(int(event["damage_values"][0]) == 21, "power shot boost damage should be 21")
	require(event.get("triggered_affix_ids", []).has(&"power_shot_damage_boost"), "power shot affix should trigger")

	game_state.battle_state = game_state.battle_system.create_initial_state()
	require(game_state.start_battle(&"forest_slime_pair"), "battle should restart")
	force_player_turn(game_state, &"hunter")
	require(game_state.execute_battle_action(&"basic_attack", &"forest_slime_01"), "hunter basic attack should execute")
	event = game_state.get_last_battle_presentation_events()[0]
	require(int(event["damage_values"][0]) == 10, "hunter bow should not boost basic attack")


func assert_quick_reload(game_state) -> void:
	game_state.start_new_game()
	require(game_state.equip_item(&"hunter", &"repeater_crossbow_01"), "hunter should equip crossbow")
	require(game_state.start_battle(&"forest_slime_pair"), "battle should start")
	var hunter: Dictionary = find_unit(game_state.get_battle_party_states(), &"hunter")
	require(int(hunter["effective_skill_cooldown_duration"]) == 1, "crossbow effective cooldown should be 1")
	force_player_turn(game_state, &"hunter")
	require(game_state.execute_battle_action(&"skill", &"forest_slime_01"), "crossbow power shot should execute")
	var event: Dictionary = game_state.get_last_battle_presentation_events()[0]
	require(int(event.get("skill_cooldown_applied", 0)) == 1, "power shot cooldown should be set to effective value 1")
	require(int(game_state.character_database.get_skill_data(&"power_shot")["skill_cooldown_duration"]) == 2, "static cooldown should remain 2")
	hunter = find_unit(game_state.get_battle_party_states(), &"hunter")
	require(int(hunter["skill_cooldown"]) == 1, "quick reload power shot should remain on cooldown next hunter turn")
	require(not game_state.execute_battle_action(&"skill", &"forest_slime_02"), "power shot should not execute while cooling down")
	require(game_state.execute_battle_action(&"basic_attack", &"forest_slime_02"), "basic attack should execute while power shot cools down")
	hunter = find_unit(game_state.get_battle_party_states(), &"hunter")
	require(int(hunter["skill_cooldown"]) == 0, "power shot cooldown should tick down after a non-skill action")


func assert_arcane_spread(game_state) -> void:
	game_state.start_new_game()
	require(game_state.equip_item(&"mage", &"arcane_staff_01"), "mage should equip arcane staff")
	require(game_state.start_battle(&"forest_slime_pair"), "battle should start")
	force_player_turn(game_state, &"mage")
	require(game_state.execute_battle_action(&"skill"), "arcane blast should execute")
	var event: Dictionary = game_state.get_last_battle_presentation_events()[0]
	require(event.get("target_ids", []).size() == 2, "arcane blast should hit two enemies")
	require(int(event["damage_values"][0]) == 8 and int(event["damage_values"][1]) == 8, "arcane spread should add 1 damage to each enemy")
	require(event.get("triggered_affix_ids", []).has(&"arcane_blast_flat_damage"), "arcane spread affix should trigger")


func assert_gentle_healing(game_state) -> void:
	game_state.start_new_game()
	require(game_state.equip_item(&"doctor", &"healing_staff_01"), "doctor should equip healing staff")
	require(game_state.start_battle(&"forest_slime_pair"), "battle should start")
	var party: Array = game_state.battle_state["party_states"]
	for index in range(party.size()):
		if party[index]["unit_id"] == &"guard":
			party[index]["current_hp"] = 35
	game_state.battle_state["party_states"] = party
	force_player_turn(game_state, &"doctor")
	require(game_state.execute_battle_action(&"skill", &"guard"), "healing art should execute")
	var event: Dictionary = game_state.get_last_battle_presentation_events()[0]
	require(int(event["healing_values"][0]) == 5, "actual heal should be capped by missing hp")
	require(int(event["healing_after_affixes"][0]) == 13, "healing staff should make healing amount 13")
	require(event.get("triggered_affix_ids", []).has(&"healing_skill_flat_bonus"), "healing affix should trigger")


func assert_defensive_stance(game_state) -> void:
	game_state.start_new_game()
	require(game_state.equip_item(&"guard", &"guardian_hammer_01"), "guard should equip guardian hammer")
	game_state.character_runtime_states[&"guard"].current_hp = 35
	require(game_state.start_battle(&"forest_slime_pair"), "battle should start")
	force_player_turn(game_state, &"guard")
	require(game_state.execute_battle_action(&"defend"), "defend should execute")
	var guard: Dictionary = find_unit(game_state.get_battle_party_states(), &"guard")
	var event: Dictionary = game_state.get_last_battle_presentation_events()[0]
	require(bool(guard["is_defending"]), "guard should be defending")
	require(int(guard["current_hp"]) == 37, "guardian hammer should heal 2 hp")
	require(int(event["healing_values"][0]) == 2, "defend event should carry heal value")
	require(event.get("triggered_affix_ids", []).has(&"defend_self_heal"), "defend heal affix should trigger")


func assert_light_leather_first_hit(game_state) -> void:
	game_state.start_new_game()
	require(game_state.equip_item(&"guard", &"light_leather_armor_01"), "guard should equip light leather armor")
	require(game_state.start_battle(&"ruins_guard"), "boss battle should start")
	set_party_stat(game_state, &"guard", "defense", 3)
	var hp_before: int = int(find_unit(game_state.get_battle_party_states(), &"guard")["current_hp"])
	var boss := find_unit(game_state.get_battle_enemy_states(), &"ruins_guard")
	game_state.battle_state["presentation_events"] = []
	game_state.battle_system.execute_enemy_turn(game_state, boss)
	var guard: Dictionary = find_unit(game_state.get_battle_party_states(), &"guard")
	var event: Dictionary = game_state.battle_state["presentation_events"][0]
	require(int(event["damage_values"][0]) == 5, "first leather hit should reduce 7 to 5")
	require(int(guard["current_hp"]) == hp_before - 5, "guard hp should lose 5 on first hit")
	require(guard.get("used_once_affix_ids", []).has(&"first_hit_damage_reduction"), "leather affix should be marked used")

	hp_before = int(guard["current_hp"])
	boss = find_unit(game_state.get_battle_enemy_states(), &"ruins_guard")
	game_state.battle_state["presentation_events"] = []
	game_state.battle_system.execute_enemy_turn(game_state, boss)
	guard = find_unit(game_state.get_battle_party_states(), &"guard")
	event = game_state.battle_state["presentation_events"][0]
	require(int(event["damage_values"][0]) == 7, "second leather hit should not reduce damage")
	require(int(guard["current_hp"]) == hp_before - 7, "guard hp should lose full 7 on second hit")


func assert_light_leather_with_defend(game_state) -> void:
	game_state.start_new_game()
	require(game_state.equip_item(&"guard", &"light_leather_armor_01"), "guard should equip light leather armor")
	require(game_state.start_battle(&"ruins_guard"), "boss battle should start")
	set_party_stat(game_state, &"guard", "defense", 3)
	set_party_stat(game_state, &"guard", "is_defending", true)
	var boss := find_unit(game_state.get_battle_enemy_states(), &"ruins_guard")
	game_state.battle_state["presentation_events"] = []
	game_state.battle_system.execute_enemy_turn(game_state, boss)
	var event: Dictionary = game_state.battle_state["presentation_events"][0]
	require(int(event["damage_values"][0]) == 1, "defend should apply before leather and minimum damage should be 1")


func assert_group_hit_independent_leather(game_state) -> void:
	game_state.start_new_game()
	var second_armor: StringName = game_state.equipment_system.add_equipment(game_state, &"light_leather_armor")
	require(game_state.equip_item(&"guard", &"light_leather_armor_01"), "guard should equip leather")
	require(game_state.equip_item(&"hunter", second_armor), "hunter should equip second leather")
	require(game_state.start_battle(&"ruins_guard"), "boss battle should start")
	set_party_stat(game_state, &"guard", "defense", 3)
	set_party_stat(game_state, &"hunter", "defense", 3)
	var boss := find_unit(game_state.get_battle_enemy_states(), &"ruins_guard")
	boss["action_count"] = 2
	set_enemy_unit(game_state, boss)
	game_state.battle_state["presentation_events"] = []
	game_state.battle_system.execute_enemy_turn(game_state, boss)
	var event: Dictionary = game_state.battle_state["presentation_events"][0]
	var guard_index: int = event["target_ids"].find(&"guard")
	var hunter_index: int = event["target_ids"].find(&"hunter")
	require(guard_index >= 0 and hunter_index >= 0, "boss group attack should hit guard and hunter")
	require(int(event["damage_values"][guard_index]) == 5, "guard leather should reduce group damage")
	require(int(event["damage_values"][hunter_index]) == 5, "hunter leather should reduce group damage independently")
	require(find_unit(game_state.get_battle_party_states(), &"guard").get("used_once_affix_ids", []).has(&"first_hit_damage_reduction"), "guard leather marker missing")
	require(find_unit(game_state.get_battle_party_states(), &"hunter").get("used_once_affix_ids", []).has(&"first_hit_damage_reduction"), "hunter leather marker missing")


func assert_forge_to_affix_loop(game_state) -> void:
	game_state.start_new_game()
	game_state.resources["ore"] = 3
	game_state.resources["herb"] = 1
	require(game_state.start_forge_recipe(&"craft_hunter_bow"), "hunter bow craft should start")
	game_state.advance_day("forge_1")
	game_state.advance_day("forge_2")
	require(game_state.equip_item(&"hunter", &"hunter_bow_02"), "crafted hunter bow should equip")
	require(game_state.start_battle(&"forest_slime_pair"), "battle should start")
	force_player_turn(game_state, &"hunter")
	require(game_state.execute_battle_action(&"skill", &"forest_slime_01"), "crafted bow power shot should execute")
	var event: Dictionary = game_state.get_last_battle_presentation_events()[0]
	require(int(event["damage_values"][0]) == 21, "crafted hunter bow affix should work")


func assert_new_game_reset(game_state) -> void:
	game_state.start_new_game()
	require(game_state.equip_item(&"guard", &"light_leather_armor_01"), "guard should equip leather")
	require(game_state.start_battle(&"ruins_guard"), "boss battle should start")
	set_party_stat(game_state, &"guard", "defense", 3)
	var boss := find_unit(game_state.get_battle_enemy_states(), &"ruins_guard")
	game_state.battle_system.execute_enemy_turn(game_state, boss)
	require(find_unit(game_state.get_battle_party_states(), &"guard").get("used_once_affix_ids", []).has(&"first_hit_damage_reduction"), "leather should be used before reset")
	game_state.start_new_game()
	require(StringName(game_state.get_character_runtime_state(&"guard")["equipped_armor_instance_id"]) == &"", "new game should clear equipment")
	require(game_state.get_battle_state().get("party_states", []).is_empty(), "new game should clear battle snapshot")


func force_player_turn(game_state, unit_id: StringName) -> void:
	game_state.battle_state["turn_order"] = [{"unit_id": unit_id, "is_player_unit": true, "speed": 99, "source_index": 0}]
	game_state.battle_state["current_turn_index"] = 0


func set_party_stat(game_state, unit_id: StringName, key: String, value) -> void:
	var party: Array = game_state.battle_state["party_states"]
	for index in range(party.size()):
		if party[index]["unit_id"] == unit_id:
			party[index][key] = value
			party[index]["current_hp"] = int(party[index].get("current_hp", party[index].get("max_hp", 1)))
			break
	game_state.battle_state["party_states"] = party


func set_enemy_unit(game_state, unit: Dictionary) -> void:
	var enemies: Array = game_state.battle_state["enemy_states"]
	for index in range(enemies.size()):
		if enemies[index]["unit_id"] == unit["unit_id"]:
			enemies[index] = unit
			break
	game_state.battle_state["enemy_states"] = enemies


func find_unit(units: Array, unit_id: StringName) -> Dictionary:
	for unit: Dictionary in units:
		if unit["unit_id"] == unit_id:
			return unit
	return {}


func require(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)

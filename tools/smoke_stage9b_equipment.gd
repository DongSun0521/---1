extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var game_state = root.get_node("/root/GameState")
	game_state.start_new_game()

	assert_initial_inventory(game_state)
	assert_equip_and_profession_rules(game_state)
	assert_replace_and_armor_stats(game_state)
	assert_battle_stats_and_hunter_affix(game_state)
	assert_healer_affix(game_state)
	assert_new_game_reset(game_state)

	print("stage9b equipment smoke ok")
	quit()


func assert_initial_inventory(game_state) -> void:
	var inventory: Array = game_state.get_equipment_inventory()
	require(inventory.size() == 8, "initial equipment inventory should contain 8 items")
	for item: Dictionary in inventory:
		require(not item.get("definition", {}).is_empty(), "equipment definition missing")
		require(StringName(item.get("equipped_by", &"")) == &"", "initial equipment should be unequipped")


func assert_equip_and_profession_rules(game_state) -> void:
	require(not game_state.can_equip_item(&"guard", &"arcane_staff_01"), "guard should not equip arcane staff")
	require(not game_state.equip_item(&"guard", &"arcane_staff_01"), "invalid profession equip should fail")

	require(game_state.equip_item(&"hunter", &"hunter_bow_01"), "hunter should equip hunter bow")
	var runtime: Dictionary = game_state.get_character_runtime_state(&"hunter")
	require(StringName(runtime["equipped_weapon_instance_id"]) == &"hunter_bow_01", "hunter weapon slot not set")
	require(int(game_state.get_final_combat_stats(&"hunter")["attack"]) == 11, "hunter bow attack bonus missing")
	require(not game_state.can_equip_item(&"guard", &"hunter_bow_01"), "equipped item should not be available to another character")


func assert_replace_and_armor_stats(game_state) -> void:
	require(game_state.equip_item(&"hunter", &"repeater_crossbow_01"), "hunter should replace bow with crossbow")
	require(StringName(game_state.get_character_runtime_state(&"hunter")["equipped_weapon_instance_id"]) == &"repeater_crossbow_01", "replacement weapon missing")
	require(StringName(game_state.get_equipment_instance_data(&"hunter_bow_01").get("equipped_by", &"")) == &"", "old bow should return to inventory tracking")
	require(int(game_state.get_final_combat_stats(&"hunter")["attack"]) == 10, "crossbow attack bonus mismatch")

	require(game_state.equip_item(&"mage", &"iron_armor_01"), "mage should equip iron armor")
	var mage_stats: Dictionary = game_state.get_final_combat_stats(&"mage")
	require(int(mage_stats["max_hp"]) == 26, "iron armor max hp bonus missing")
	require(int(mage_stats["defense"]) == 3, "iron armor defense bonus missing")

	var comparison: Dictionary = game_state.get_equipment_comparison(&"mage", &"light_leather_armor_01")
	require(int(comparison["defense"]) == -1, "armor comparison defense should decrease by 1")
	require(int(comparison["max_hp"]) == -2, "armor comparison max hp should decrease by 2")


func assert_battle_stats_and_hunter_affix(game_state) -> void:
	require(game_state.equip_item(&"hunter", &"hunter_bow_01"), "hunter should re-equip hunter bow")
	require(game_state.start_battle(&"forest_slime_pair"), "battle should start")
	var party: Array = game_state.get_battle_party_states()
	var hunter := find_unit(party, &"hunter")
	var mage := find_unit(party, &"mage")
	require(int(hunter["attack"]) == 11, "battle hunter attack should include bow")
	require(int(mage["max_hp"]) == 26, "battle mage max hp should include armor")
	require(int(mage["defense"]) == 3, "battle mage defense should include armor")
	require(game_state.execute_battle_action(&"skill", &"forest_slime_01"), "hunter skill should execute")
	var events: Array = game_state.get_last_battle_presentation_events()
	require(not events.is_empty(), "hunter skill event missing")
	var damage_values: Array = events[0].get("damage_values", [])
	require(not damage_values.is_empty(), "hunter damage value missing")
	require(int(damage_values[0]) == 21, "hunter bow affix damage mismatch")
	game_state.battle_state = game_state.battle_system.create_initial_state()


func assert_healer_affix(game_state) -> void:
	require(game_state.equip_item(&"doctor", &"healing_staff_01"), "doctor should equip healing staff")
	require(game_state.start_battle(&"forest_slime_pair"), "battle should start for heal test")
	var party: Array = game_state.battle_state["party_states"]
	for index in range(party.size()):
		if party[index]["unit_id"] == &"guard":
			party[index]["current_hp"] = 20
	game_state.battle_state["party_states"] = party
	game_state.battle_state["turn_order"] = [{"unit_id": &"doctor", "is_player_unit": true, "speed": 6, "source_index": 3}]
	game_state.battle_state["current_turn_index"] = 0
	require(game_state.execute_battle_action(&"skill", &"guard"), "doctor heal should execute")
	var events: Array = game_state.get_last_battle_presentation_events()
	require(not events.is_empty(), "heal event missing")
	var healing_values: Array = events[0].get("healing_values", [])
	require(not healing_values.is_empty(), "heal value missing")
	require(int(healing_values[0]) == 13, "healing staff affix heal mismatch")
	game_state.battle_state = game_state.battle_system.create_initial_state()


func assert_new_game_reset(game_state) -> void:
	game_state.start_new_game()
	require(game_state.get_equipment_inventory().size() == 8, "new game should reset equipment inventory")
	require(StringName(game_state.get_character_runtime_state(&"hunter")["equipped_weapon_instance_id"]) == &"", "hunter weapon should reset")
	require(int(game_state.get_final_combat_stats(&"hunter")["attack"]) == 8, "hunter attack should reset")


func find_unit(units: Array, unit_id: StringName) -> Dictionary:
	for unit: Dictionary in units:
		if unit["unit_id"] == unit_id:
			return unit
	return {}


func require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

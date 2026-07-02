extends SceneTree

const VillageViewScene := preload("res://features/village/village_view.tscn")


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var game_state = root.get_node("/root/GameState")
	game_state.start_new_game()

	assert_recipes(game_state)
	assert_material_gate_and_crafting(game_state)
	assert_crafted_equipment_loop(game_state)
	assert_ui_builds(game_state)
	assert_new_game_reset(game_state)

	print("stage9c forge smoke ok")
	quit()


func assert_recipes(game_state) -> void:
	var recipes: Array = game_state.get_all_forge_recipe_data()
	require(recipes.size() == 8, "forge should expose 8 recipes")
	for recipe: Dictionary in recipes:
		require(not recipe.get("equipment_definition", {}).is_empty(), "recipe equipment definition missing")


func assert_material_gate_and_crafting(game_state) -> void:
	require(not game_state.can_start_forge_recipe(&"craft_hunter_bow"), "hunter bow should need resources")
	require(not game_state.start_forge_recipe(&"craft_hunter_bow"), "craft should fail without resources")
	require(game_state.get_resource_amount("ore") == 0, "failed craft should not spend ore")

	game_state.resources["ore"] = 3
	game_state.resources["herb"] = 1
	require(game_state.start_forge_recipe(&"craft_hunter_bow"), "hunter bow craft should start")
	require(game_state.get_resource_amount("ore") == 0, "ore cost should be spent immediately")
	require(game_state.get_resource_amount("herb") == 0, "herb cost should be spent immediately")
	require(not game_state.start_forge_recipe(&"craft_iron_sword"), "second forge project should be blocked")

	game_state.advance_day("forge_day_1")
	var forge_state: Dictionary = game_state.get_forge_state()
	require(bool(forge_state["is_active"]), "forge should still be active after 1 day")
	require(int(forge_state["progress_days"]) == 1, "forge progress should be 1/2")
	require(game_state.get_equipment_inventory().size() == 8, "unfinished craft should not create equipment")

	require(game_state.start_battle(&"forest_slime_pair"), "battle should start")
	forge_state = game_state.get_forge_state()
	require(int(forge_state["progress_days"]) == 1, "starting battle should not advance forge progress")
	game_state.battle_state = game_state.battle_system.create_initial_state()

	game_state.advance_day("forge_day_2")
	forge_state = game_state.get_forge_state()
	require(not bool(forge_state["is_active"]), "forge should clear after completion")
	require(game_state.get_equipment_inventory().size() == 9, "completed craft should add equipment")
	require(not game_state.get_equipment_instance_data(&"hunter_bow_02").is_empty(), "crafted hunter bow instance missing")
	game_state.advance_day("forge_extra_day")
	require(game_state.get_equipment_inventory().size() == 9, "completed craft should not duplicate")


func assert_crafted_equipment_loop(game_state) -> void:
	require(game_state.equip_item(&"hunter", &"hunter_bow_02"), "crafted bow should be equippable")
	require(int(game_state.get_final_combat_stats(&"hunter")["attack"]) == 11, "crafted bow stat bonus missing")
	require(game_state.start_battle(&"forest_slime_pair"), "battle should start for crafted bow")
	require(game_state.execute_battle_action(&"skill", &"forest_slime_01"), "hunter skill should execute")
	var events: Array = game_state.get_last_battle_presentation_events()
	require(not events.is_empty(), "crafted bow skill event missing")
	var damage_values: Array = events[0].get("damage_values", [])
	require(not damage_values.is_empty(), "crafted bow damage value missing")
	require(int(damage_values[0]) == 21, "crafted bow affix damage mismatch")
	game_state.battle_state = game_state.battle_system.create_initial_state()


func assert_ui_builds(game_state) -> void:
	var village_view = VillageViewScene.instantiate()
	root.add_child(village_view)
	await process_frame
	require(village_view.has_method("show_forge_page"), "forge page entry missing")
	village_view.show_forge_page()
	await process_frame
	require(village_view.forge_page.visible, "forge page should be visible")
	require(village_view.forge_recipe_list_box.get_child_count() == 8, "forge recipe list should render 8 items")
	village_view.hide_forge_page()
	village_view.queue_free()


func assert_new_game_reset(game_state) -> void:
	game_state.resources["ore"] = 4
	require(game_state.start_forge_recipe(&"craft_iron_sword"), "forge should start before reset")
	require(bool(game_state.get_forge_state()["is_active"]), "forge should be active before reset")
	game_state.start_new_game()
	require(not bool(game_state.get_forge_state()["is_active"]), "new game should clear forge state")
	require(game_state.get_equipment_inventory().size() == 8, "new game should restore initial equipment only")
	require(game_state.get_equipment_instance_data(&"hunter_bow_02").is_empty(), "new game should remove crafted duplicate")


func require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

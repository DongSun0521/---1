extends SceneTree

const VillageViewScene := preload("res://features/village/village_view.tscn")

const EXPECTED_SHEETS := {
	&"research_lab": "res://assets/art/buildings/KeYanSuo_sheet.png",
	&"residence": "res://assets/art/buildings/MinJun_sheet.png",
	&"farm": "res://assets/art/buildings/NongTian_sheet.png",
	&"food_workshop": "res://assets/art/buildings/ShiWu_sheet.png",
	&"weapon_forge": "res://assets/art/buildings/WuQi_sheet.png",
	&"hospital": "res://assets/art/buildings/YiYuan_sheet.png",
	&"resource_collection": "res://assets/art/buildings/ZiYuanShoujiSuo_sheet.png",
}


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var game_state = root.get_node("/root/GameState")
	game_state.start_new_game()

	assert_building_data(game_state)
	assert_level_switching(game_state)
	await assert_village_ui(game_state)
	await assert_window_layouts(game_state)
	assert_existing_state_adapters(game_state)

	print("stage10a buildings smoke ok")
	quit()


func assert_building_data(game_state) -> void:
	var ids: Array[StringName] = game_state.get_building_ids()
	require(ids.size() == 7, "should expose 7 village buildings")
	for building_id: StringName in ids:
		var data = game_state.get_building_data(building_id)
		require(data != null, "building data missing: %s" % building_id)
		require(data.sheet_path == EXPECTED_SHEETS[building_id], "wrong sheet path: %s" % building_id)
		require(data.level_regions.size() == 4, "level regions missing: %s" % building_id)
		for index: int in range(4):
			require(data.level_regions[index] == Rect2(index * 512, 0, 512, 512), "bad region %d for %s" % [index + 1, building_id])
		var state: Dictionary = game_state.get_building_state(building_id)
		require(int(state.get("level", 0)) == 1, "new game level should be 1: %s" % building_id)


func assert_level_switching(game_state) -> void:
	for building_id: StringName in game_state.get_building_ids():
		for level: int in [1, 2, 3, 4]:
			var before_level := int(game_state.get_building_state(building_id).get("level", 1))
			var changed: bool = game_state.set_building_level(building_id, level)
			require(changed == (level != before_level), "level setter should be stable")
			require(int(game_state.get_building_state(building_id).get("level", 0)) == level, "level did not change")
		for bad_level: int in [0, 5, -1, 99]:
			require(not game_state.set_building_level(building_id, bad_level), "invalid level accepted")
			require(int(game_state.get_building_state(building_id).get("level", 0)) == 4, "invalid level should not mutate")
	game_state.start_new_game()
	for building_id: StringName in game_state.get_building_ids():
		require(int(game_state.get_building_state(building_id).get("level", 0)) == 1, "new game should reset building level")


func assert_village_ui(game_state) -> void:
	var village_view = VillageViewScene.instantiate()
	root.add_child(village_view)
	await process_frame
	require(village_view.building_views.size() == 7, "village should render 7 building views")
	for building_id: StringName in game_state.get_building_ids():
		require(village_view.building_views.has(building_id), "building view missing: %s" % building_id)
		village_view.select_building(building_id)
		await process_frame
		require(village_view.detail_title_label.text.contains(String(game_state.get_building_data(building_id).display_name)), "panel title mismatch")
		require(village_view.workshop_art_rect.texture != null, "panel preview missing")
		require(village_view.workshop_art_rect.texture is AtlasTexture, "panel preview should be atlas")
	village_view.select_building(&"weapon_forge")
	village_view.show_forge_page()
	await process_frame
	require(village_view.forge_page.visible, "forge page should still open from unified panel")
	require(village_view.forge_recipe_list_box.get_child_count() == 8, "forge recipes should still render")
	village_view.queue_free()


func assert_window_layouts(game_state) -> void:
	for viewport_size: Vector2 in [Vector2(1920, 1080), Vector2(1600, 900), Vector2(1280, 720)]:
		root.size = viewport_size
		var village_view = VillageViewScene.instantiate()
		village_view.set_anchors_preset(Control.PRESET_TOP_LEFT)
		village_view.size = viewport_size
		root.add_child(village_view)
		await process_frame
		village_view.layout_building_views()
		for building_id: StringName in game_state.get_building_ids():
			var view: Control = village_view.building_views[building_id]
			var center: Vector2 = view.position + view.size * 0.5
			require(center.x >= 0.0 and center.x <= viewport_size.x, "building x out of viewport")
			require(center.y >= 0.0 and center.y <= viewport_size.y, "building y out of viewport")
		village_view.select_building(&"weapon_forge")
		await process_frame
		require(village_view.forge_entry_button.visible, "forge action hidden at viewport")
		village_view.queue_free()


func assert_existing_state_adapters(game_state) -> void:
	require(game_state.get_building_state(&"hospital").get("state_key", "") == "clinic", "hospital should adapt clinic state")
	require(game_state.get_building_state(&"weapon_forge").get("state_key", "") == "workshop", "weapon forge should adapt workshop state")
	var farm_before: int = game_state.get_resource_amount("food")
	game_state.advance_day("stage10a_adapter_check")
	require(game_state.get_resource_amount("food") >= farm_before, "farm production should still run")
	var clinic_state: Dictionary = game_state.buildings.get("clinic", {})
	require(int(clinic_state.get("medicine_progress", -1)) >= 0, "clinic medicine progress should still run")


func require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

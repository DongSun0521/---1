extends SceneTree

const VillageViewScene := preload("res://features/village/village_view.tscn")


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var game_state = root.get_node("/root/GameState")
	game_state.start_new_game()

	assert_new_game_farm(game_state)
	assert_daily_growth_and_harvest(game_state)
	assert_crop_assignment(game_state)
	assert_level_unlock_and_downgrade_guard(game_state)
	assert_expedition_farm_report(game_state)
	assert_new_game_reset(game_state)
	assert_thirty_day_formula(game_state)
	await assert_farm_ui(game_state)

	print("stage10b farm smoke ok")
	quit()


func assert_new_game_farm(game_state) -> void:
	require(int(game_state.get_building_state(&"farm").get("level", 0)) == 1, "farm should start at level 1")
	var plots: Array = game_state.get_farm_plot_states()
	require(plots.size() == 6, "farm should keep 6 plot states")
	for index in range(6):
		var plot: Dictionary = plots[index]
		if index < 3:
			require(bool(plot["is_unlocked"]), "initial plot should be unlocked")
			require(plot["crop_id"] == &"wheat", "initial plot should grow wheat")
			require(bool(plot["is_active"]), "initial wheat plot should be active")
			require(int(plot["progress_days"]) == 0, "initial wheat progress should be 0")
			require(int(plot["growth_days"]) == 2, "wheat should require 2 days")
		else:
			require(not bool(plot["is_unlocked"]), "extra plot should be locked")
			require(plot["crop_id"] == &"", "locked plot should be empty")
	var summary: Dictionary = game_state.get_farm_summary()
	require(int(summary["active_plot_count"]) == 3, "farm should have 3 active plots")
	require(int(summary["next_harvest_days"]) == 2, "new wheat should harvest in 2 days")


func assert_daily_growth_and_harvest(game_state) -> void:
	game_state.start_new_game()
	var report_day_1: Dictionary = game_state.advance_day("farm_day_1")
	require(int(report_day_1["farm_food_produced"]) == 0, "first day should not harvest wheat")
	require(int(report_day_1["food_produced"]) == 0, "old fixed farm food should be disabled")
	require(game_state.get_resource_amount("food") == 18, "first day should only consume village food")
	for plot: Dictionary in game_state.get_farm_plot_states().slice(0, 3):
		require(int(plot["progress_days"]) == 1, "wheat should progress to 1/2")

	var report_day_2: Dictionary = game_state.advance_day("farm_day_2")
	require(int(report_day_2["farm_food_produced"]) == 9, "three wheat plots should produce 9 food")
	require(report_day_2.get("farm_harvests", []).size() == 3, "three wheat plots should harvest")
	require(game_state.get_resource_amount("food") == 25, "second day should harvest before village consumption")
	for plot: Dictionary in game_state.get_farm_plot_states().slice(0, 3):
		require(plot["crop_id"] == &"wheat", "wheat should auto repeat after harvest")
		require(int(plot["progress_days"]) == 0, "harvested wheat should reset progress")

	game_state.advance_day("farm_loop_1")
	game_state.advance_day("farm_loop_2")
	require(game_state.get_resource_amount("food") == 30, "two more days should harvest once more and consume 4 food")


func assert_crop_assignment(game_state) -> void:
	game_state.start_new_game()
	require(game_state.assign_farm_crop(3, &"herb"), "plot 3 should switch to herb at 0 progress")
	var plot_3: Dictionary = get_plot(game_state, 3)
	require(plot_3["crop_id"] == &"herb", "plot 3 crop should be herb")
	require(int(plot_3["progress_days"]) == 0, "new herb should start at 0")

	game_state.advance_day("mixed_1")
	game_state.advance_day("mixed_2")
	var report_day_3: Dictionary = game_state.advance_day("mixed_3")
	require(int(report_day_3["farm_herb_produced"]) == 2, "herb should harvest after 3 days")
	require(get_plot(game_state, 3)["crop_id"] == &"herb", "herb should auto repeat")
	require(int(get_plot(game_state, 3)["progress_days"]) == 0, "harvested herb should reset")

	game_state.start_new_game()
	game_state.advance_day("replace_progress")
	require(not game_state.assign_farm_crop(1, &"herb"), "replace with progress should require confirmation")
	require(get_plot(game_state, 1)["crop_id"] == &"wheat", "cancelled replace should keep wheat")
	require(game_state.assign_farm_crop(1, &"herb", true), "forced replace should succeed")
	require(get_plot(game_state, 1)["crop_id"] == &"herb", "forced replace should set herb")
	require(int(get_plot(game_state, 1)["progress_days"]) == 0, "forced replace should reset progress")


func assert_level_unlock_and_downgrade_guard(game_state) -> void:
	game_state.start_new_game()
	require(game_state.set_building_level(&"farm", 2), "farm level 2 should be settable")
	require(bool(get_plot(game_state, 4)["is_unlocked"]), "plot 4 should unlock at level 2")
	require(get_plot(game_state, 4)["crop_id"] == &"", "newly unlocked plot should be empty")
	require(game_state.assign_farm_crop(4, &"wheat"), "plot 4 should accept crop")
	require(not game_state.set_building_level(&"farm", 1), "downgrade should be blocked while plot 4 has crop")
	require(get_plot(game_state, 4)["crop_id"] == &"wheat", "blocked downgrade should keep crop")
	require(game_state.farm_system.clear_plot(game_state, 4, true), "test should clear plot 4")
	require(game_state.set_building_level(&"farm", 1), "downgrade should pass after extra plot is empty")
	require(not bool(get_plot(game_state, 4)["is_unlocked"]), "plot 4 should lock after downgrade")


func assert_expedition_farm_report(game_state) -> void:
	game_state.start_new_game()
	require(game_state.start_expedition(4, 0), "expedition should start")
	require(game_state.move_to_next_expedition_node(), "first expedition move should advance day")
	var first_report: Dictionary = game_state.get_last_expedition_action_report()
	require(int(first_report["farm_food_produced"]) == 0, "first expedition day should not harvest")
	game_state.battle_state = game_state.battle_system.create_initial_state()
	var expedition_state: Dictionary = game_state.expedition_state
	var cleared_nodes: Array = expedition_state.get("cleared_battle_node_ids", [])
	cleared_nodes.append(&"forest_edge")
	expedition_state["cleared_battle_node_ids"] = cleared_nodes
	game_state.expedition_state = expedition_state
	require(game_state.move_to_next_expedition_node(), "second expedition move should advance day")
	var second_report: Dictionary = game_state.get_last_expedition_action_report()
	require(int(second_report["farm_food_produced"]) == 9, "farm should harvest during expedition")
	require(second_report.get("farm_harvests", []).size() == 3, "expedition report should include farm harvest details")


func assert_new_game_reset(game_state) -> void:
	game_state.start_new_game()
	require(game_state.set_building_level(&"farm", 2), "farm should upgrade before reset")
	require(game_state.assign_farm_crop(4, &"herb"), "extra plot should be planted before reset")
	game_state.advance_day("dirty_farm_state")
	game_state.start_new_game()
	require(int(game_state.get_building_state(&"farm").get("level", 0)) == 1, "new game should reset farm level")
	assert_new_game_farm(game_state)


func assert_thirty_day_formula(game_state) -> void:
	game_state.start_new_game()
	for day in range(30):
		game_state.advance_day("farm_30_day_%02d" % [day + 1])
	require(game_state.get_resource_amount("food") == 95, "30 days should be 20 + 15*9 - 30*2 = 95 food")
	for plot: Dictionary in game_state.get_farm_plot_states().slice(0, 3):
		require(int(plot["progress_days"]) == 0, "30 days should end on wheat harvest boundary")


func assert_farm_ui(game_state) -> void:
	game_state.start_new_game()
	var village_view = VillageViewScene.instantiate()
	root.add_child(village_view)
	await process_frame
	village_view.select_building(&"farm")
	await process_frame
	require(village_view.farm_section.visible, "farm should use unified building panel function content")
	require(village_view.farm_plot_list_box.get_child_count() == 6, "farm panel should render 6 plot cards")
	village_view.queue_free()


func get_plot(game_state, plot_id: int) -> Dictionary:
	for plot: Dictionary in game_state.get_farm_plot_states():
		if int(plot["plot_id"]) == plot_id:
			return plot
	return {}


func require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

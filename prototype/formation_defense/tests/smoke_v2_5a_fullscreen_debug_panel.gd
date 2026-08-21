extends SceneTree

const SCENE_PATH := "res://prototype/formation_defense/scenes/formation_defense_prototype.tscn"
const CONFIG := preload("res://prototype/formation_defense/data/formation_defense_config.gd")
const STEP := 0.1
const EXPECTED_CHECKS := 18

var failures: Array[String] = []
var check_count := 0


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	var controller = packed.instantiate()
	root.add_child(controller)
	await process_frame
	await process_frame
	controller.set_automatic_simulation(false)

	var initial_layout: Dictionary = controller.get_layout_snapshot()
	check(
		not controller.debug_panel_open
			and not controller.debug_drawer.visible
			and bool(initial_layout.compact_hud_visible),
		"1 debug drawer starts closed with compact HUD visible"
	)
	check(
		initial_layout.logical_battlefield_size == Vector2(1802.0, 414.0)
			and initial_layout.battlefield_size == Vector2(1920.0, 1080.0),
		"2 fullscreen battlefield preserves the frozen logical canvas"
	)
	var mapping_scale: Vector2 = initial_layout.position_mapping_scale
	var round_trip_logic := Vector2(901.0, 207.0)
	check(
		not is_equal_approx(mapping_scale.x, mapping_scale.y)
			and controller.screen_to_logic_position(
				controller.logic_to_screen_position(round_trip_logic)
			).is_equal_approx(round_trip_logic),
		"2a position mapping may be anisotropic and remains invertible"
	)
	check(
		is_uniform_scale(initial_layout.route_visual_global_scale)
			and is_uniform_scale(initial_layout.formation_visual_global_scale)
			and is_uniform_scale(initial_layout.caption_visual_global_scale)
			and is_uniform_scale(initial_layout.village_visual_global_scale),
		"2b routes, outlines, labels and village visuals cancel anisotropic scale"
	)
	var first_slot: Control = controller.deployment_slots.values()[0]
	var slot_axis_scale: Vector2 = controller.get_global_axis_scale(first_slot)
	var slot_screen_size: Vector2 = first_slot.size * slot_axis_scale
	check(
		is_uniform_scale(slot_axis_scale)
			and is_equal_approx(slot_screen_size.x, slot_screen_size.y),
		"2c deployment markers retain square screen bounds"
	)

	controller._input(make_debug_button_click(controller))
	var opened_layout: Dictionary = controller.get_layout_snapshot()
	controller._input(make_debug_button_click(controller))
	var closed_layout: Dictionary = controller.get_layout_snapshot()
	check(
		bool(opened_layout.debug_panel_open)
			and not bool(closed_layout.debug_panel_open)
			and opened_layout.battlefield_size == closed_layout.battlefield_size
			and opened_layout.display_scale == closed_layout.display_scale,
		"3 repeated drawer toggle never reflows the battlefield"
	)
	var first_character_card: Button = controller.character_cards.values()[0]
	check(
		controller.debug_drawer.mouse_filter == Control.MOUSE_FILTER_STOP
			and controller.debug_drawer.z_index > controller.battlefield.z_index
			and controller.battlefield.get_index() < controller.debug_drawer.get_index()
			and controller.debug_toggle_button.z_index > controller.debug_drawer.z_index
			and controller.debug_toggle_button.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and controller.debug_toggle_button.get_parent() == controller
			and controller.debug_content.is_ancestor_of(controller.start_button)
			and controller.debug_content.is_ancestor_of(controller.scenario_option)
			and controller.debug_content.is_ancestor_of(first_character_card)
			and not controller.scenario_option.disabled
			and not first_character_card.disabled,
		"4 drawer intercepts input and contains the original controls"
	)

	controller.select_scenario(&"command_demo")
	controller.apply_recommended_deployment()
	controller.set_debug_panel_open(true)
	controller.start_button.pressed.emit()
	check(
		controller.battle_state == controller.BattleState.RUNNING
			and not controller.debug_panel_open,
		"5 start closes the drawer without blocking battle startup"
	)
	var enemy = controller.active_enemies.values()[0]
	var enemy_position_before: Vector2 = enemy.position
	controller.set_debug_panel_open(true)
	controller.simulate_step(STEP)
	check(
		is_equal_approx(controller.battle_elapsed, STEP)
			and enemy.position != enemy_position_before,
		"6 open drawer does not pause or slow simulation"
	)
	var units_uniform := is_uniform_scale(controller.get_global_axis_scale(enemy))
	for character in controller.character_nodes.values():
		units_uniform = units_uniform \
			and is_uniform_scale(controller.get_global_axis_scale(character))
	check(units_uniform, "6a every enemy and character visual root remains uniform")
	var mapping_before_toggle: Vector2 = controller.position_mapping_scale
	var enemy_screen_before: Vector2 = controller.logic_to_screen_position(enemy.position)
	controller.set_debug_panel_open(false)
	controller.set_debug_panel_open(true)
	check(
		controller.position_mapping_scale == mapping_before_toggle
			and controller.logic_to_screen_position(enemy.position) == enemy_screen_before,
		"6b drawer toggles preserve mapping parameters and unit screen positions"
	)

	controller.command_controller.issue_command(enemy.runtime_id)
	var command_id: int = controller.command_controller.get_active_command_snapshot().command_id
	check(
		controller.handle_escape_action() == &"CLOSED_DEBUG_PANEL"
			and controller.command_controller.get_active_command_snapshot().command_id == command_id
			and controller.handle_escape_action() == &"CANCELED_COMMAND"
			and controller.command_controller.get_active_command_snapshot().is_empty(),
		"7 Escape closes drawer first, then cancels command"
	)
	enemy.set_debug_world_position(Vector2(600.0, 200.0))
	controller.set_debug_panel_open(true)
	controller.handle_battlefield_pointer(enemy.position, MOUSE_BUTTON_LEFT)
	check(
		controller.command_controller.get_target_runtime_id() == enemy.runtime_id,
		"8 battlefield outside the drawer still accepts focus clicks"
	)
	var five_route_picks_ok := true
	for route_id: StringName in CONFIG.FORMATION_COMPATIBLE_ROUTE_IDS:
		var route_enemy = controller.spawn_enemy_for_route(
			route_id,
			&"charge",
			{"max_health": 999, "leak_damage": 0}
		)
		var route_point: Vector2 = controller.get_route_points(route_id)[0]
		route_enemy.set_debug_world_position(route_point)
		var mapped_point: Vector2 = controller.logic_to_screen_position(route_point)
		var recovered_point: Vector2 = controller.screen_to_logic_position(mapped_point)
		five_route_picks_ok = five_route_picks_ok \
			and controller.pick_enemy_at(recovered_point) == route_enemy
	check(five_route_picks_ok, "8a inverse mapping selects enemies on all five lanes")

	controller.spawn_attack_visual({
		"type": &"attack",
		"source_id": &"hunter",
		"target_id": enemy.runtime_id,
		"attack_sequence_id": 99,
		"origin_position": Vector2(500.0, 200.0),
		"target_position": enemy.position,
		"role_id": &"hunter",
	})
	var projectile_snapshot: Dictionary = controller.get_attack_visual_snapshots()[-1]
	check(
		is_uniform_scale(projectile_snapshot.global_axis_scale)
			and is_uniform_scale(controller.get_global_axis_scale(
				controller.projectile_visual_layer
			)),
		"8b projectile visuals remain uniformly scaled"
	)
	controller.set_debug_panel_open(true)
	controller.restart_button.pressed.emit()
	check(
		not controller.debug_panel_open
			and controller.command_controller.get_active_command_snapshot().is_empty()
			and controller.get_attack_visual_snapshots().is_empty()
			and controller.active_enemies.is_empty(),
		"9 restart closes drawer and clears command, units and visuals"
	)

	var resolutions_ok := true
	for resolution: Vector2 in [
		Vector2(1920.0, 1080.0),
		Vector2(1600.0, 900.0),
		Vector2(1366.0, 768.0),
	]:
		var preview: Dictionary = controller.get_resolution_layout_preview(resolution)
		resolutions_ok = resolutions_ok \
			and preview.battlefield_screen_rect.size == resolution \
			and float(preview.drawer_screen_width) >= 300.0 \
			and float(preview.drawer_screen_height) == resolution.y \
			and preview.logical_battlefield_size == Vector2(1802.0, 414.0) \
			and is_equal_approx(float(preview.visual_aspect_ratio), 1.0)
	check(resolutions_ok, "10 three target resolutions keep a usable fullscreen layout")

	controller.select_scenario(&"command_demo")
	controller.apply_recommended_deployment()
	controller.start_battle()
	var steps := 0
	while controller.battle_state == controller.BattleState.RUNNING and steps < 600:
		controller.simulate_step(STEP)
		steps += 1
	var battle_snapshot: Dictionary = controller.get_battle_snapshot()
	var formation_stats: Dictionary = battle_snapshot.formation_stats
	check(
		battle_snapshot.state == "VICTORY"
			and is_equal_approx(float(battle_snapshot.battle_elapsed), 41.2)
			and int(formation_stats.completed_a_count) == 6
			and int(formation_stats.completed_b_count) == 2
			and int(formation_stats.interrupted_count) == 6
			and int(formation_stats.downgrade_count) == 2,
		"11 V2-4 deterministic combat baseline is unchanged"
	)

	controller.queue_free()
	await process_frame
	if check_count != EXPECTED_CHECKS:
		failures.append("coverage count %d != %d" % [check_count, EXPECTED_CHECKS])
	if failures.is_empty():
		print("v2-5a fullscreen debug panel smoke ok: 18 requirements")
		quit(0)
	else:
		push_error("v2-5a fullscreen debug panel smoke failed: %s" % "; ".join(failures))
		quit(1)


func check(condition: bool, label: String) -> void:
	check_count += 1
	if condition:
		return
	failures.append(label)
	push_error(label)


func is_uniform_scale(axis_scale: Vector2) -> bool:
	return is_equal_approx(axis_scale.x, axis_scale.y)


func make_debug_button_click(controller) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = controller.debug_toggle_button.get_global_rect().get_center()
	event.global_position = event.position
	return event

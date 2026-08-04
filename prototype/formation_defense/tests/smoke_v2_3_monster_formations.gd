extends SceneTree

const PROTOTYPE_ROOT := "res://prototype/formation_defense/"
const PROTOTYPE_SCENE_PATH := (
	PROTOTYPE_ROOT + "scenes/formation_defense_prototype.tscn"
)
const PrototypeConfig := preload(
	"res://prototype/formation_defense/data/formation_defense_config.gd"
)
const DEFAULT_SAVE_PATH := "user://adventure_village_save.json"
const FORMAL_MAIN_SCENE_PATH := "res://features/main/main.tscn"
const SIMULATION_STEP := 0.1
const MAX_SIMULATION_STEPS := 900

const RUNTIME_PATHS: Array[String] = [
	PROTOTYPE_SCENE_PATH,
	PROTOTYPE_ROOT + "scripts/formation_defense_prototype.gd",
	PROTOTYPE_ROOT + "scripts/formation_defense_character.gd",
	PROTOTYPE_ROOT + "scripts/formation_defense_deployment_slot.gd",
	PROTOTYPE_ROOT + "scripts/formation_defense_enemy.gd",
	PROTOTYPE_ROOT + "scripts/formation_defense_formation_group.gd",
	PROTOTYPE_ROOT + "scripts/formation_defense_formation_manager.gd",
	PROTOTYPE_ROOT + "scripts/formation_defense_command_controller.gd",
	PROTOTYPE_ROOT + "scripts/formation_defense_projectile_visual.gd",
	PROTOTYPE_ROOT + "scripts/formation_defense_route_view.gd",
	PROTOTYPE_ROOT + "data/formation_defense_config.gd",
]
const FORBIDDEN_RUNTIME_TOKENS: Array[String] = [
	"/root/GameState",
	"CharacterRoster",
	"SaveSystem",
	"res://autoload/",
	"res://features/",
	"res://systems/",
	"res://scripts/",
	"user://",
]

var failures: Array[String] = []
var finished_outcomes: Array[StringName] = []
var demo_results: Array[Dictionary] = []


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var game_state := root.get_node_or_null("/root/GameState")
	require(game_state != null, "formal GameState autoload is unavailable")
	if game_state == null:
		quit(1)
		return
	var game_state_before := snapshot_script_variables(game_state)
	var save_file_before := snapshot_file(DEFAULT_SAVE_PATH)

	assert_project_settings_are_unchanged()
	assert_runtime_files_are_isolated()
	assert_monster_and_formation_config()

	var packed_scene := load(PROTOTYPE_SCENE_PATH) as PackedScene
	require(packed_scene != null, "V2-3 entry scene could not be loaded")
	if packed_scene == null:
		quit(1)
		return
	var controller = packed_scene.instantiate()
	require(controller != null, "V2-3 entry scene could not be instantiated")
	if controller == null:
		quit(1)
		return
	root.add_child(controller)
	await process_frame
	await process_frame
	controller.set_automatic_simulation(false)
	controller.battle_finished.connect(on_battle_finished)

	assert_required_nodes(controller)
	await assert_zone_and_route_rules(controller)
	await assert_cross_route_ellipse_and_atomic_locks(controller)
	await assert_neighbor_route_span_and_anchor_rules(controller)
	await assert_a_formation_rules(controller)
	await assert_invalid_and_deterministic_candidates(controller)
	await assert_b_formation_rules(controller)
	await assert_slot_completion_and_timeout(controller)
	await assert_member_and_control_interruptions(controller)
	await assert_charge_control_resistance(controller)
	await assert_shield_damage_effects(controller)
	await assert_dissolve_and_downgrade(controller)
	await assert_formation_members_block_independently(controller)
	await assert_formation_settlement_is_idempotent(controller)

	finished_outcomes.clear()
	await assert_two_actual_demo_runs(controller)

	controller.restart_battle()
	await process_frame
	assert_clean_ready_state(controller)
	require(
		snapshot_script_variables(game_state) == game_state_before,
		"V2-3 prototype changed GameState"
	)
	require(
		snapshot_file(DEFAULT_SAVE_PATH) == save_file_before,
		"V2-3 prototype changed the formal save file"
	)

	controller.queue_free()
	await process_frame
	require(
		snapshot_script_variables(game_state) == game_state_before,
		"V2-3 prototype cleanup changed GameState"
	)
	require(
		snapshot_file(DEFAULT_SAVE_PATH) == save_file_before,
		"V2-3 prototype cleanup changed the formal save file"
	)

	if failures.is_empty():
		for result: Dictionary in demo_results:
			print(
				(
					"v2-3 %s: state=%s durability=%d killed=%d leaked=%d"
					+ " A=%d B=%d interrupted=%d downgraded=%d duration=%.1fs"
					+ " spans=%s pairs=%s cross=%d Aobs=%s Bobs=%s"
				)
				% [
					String(result.get("name", "")),
					String(result.get("state", "")),
					int(result.get("durability", 0)),
					int(result.get("killed", 0)),
					int(result.get("leaked", 0)),
					int(result.get("a_completed", 0)),
					int(result.get("b_completed", 0)),
					int(result.get("interrupted", 0)),
					int(result.get("downgraded", 0)),
					float(result.get("duration", 0.0)),
					str(result.get("route_spans", {})),
					str(result.get("pair_modes", {})),
					int(result.get("cross_route_a", 0)),
					str(result.get("a_observations", [])),
					str(result.get("b_observations", [])),
				]
			)
		print("v2-3 monster formations smoke ok")
		quit(0)
		return
	quit(1)


func assert_required_nodes(controller: Node) -> void:
	for node_path: String in [
		"Battlefield/BattlefieldDisplayRoot/BattlefieldContent/FormationLayer",
		"Battlefield/BattlefieldDisplayRoot/BattlefieldContent/EnemyLayer",
		"DebugDrawer/DrawerMargin/DrawerRows/DebugScroll/DebugContent/FormationStatusPanel/FormationStatsLabel",
		"DebugDrawer/DrawerMargin/DrawerRows/DebugScroll/DebugContent/ControlPanel/ControlRow/ScenarioOption",
	]:
		require(
			controller.get_node_or_null(node_path) != null,
			"required V2-3 node is missing: %s" % node_path
		)


func assert_monster_and_formation_config() -> void:
	var monster_ids := PrototypeConfig.get_monster_type_ids()
	require(
		monster_ids == [&"charge", &"shield"],
		"V2-3 must expose charge and shield monster configurations"
	)
	for monster_type: StringName in monster_ids:
		var definition := PrototypeConfig.get_monster_definition(monster_type)
		require(
			not definition.is_empty()
				and int(definition.get("max_health", 0)) > 0
				and float(definition.get("move_speed", 0.0)) > 0.0,
			"%s monster configuration is incomplete" % String(monster_type)
		)
	require(
		is_equal_approx(PrototypeConfig.FORMATION_A_DURATION, 1.5)
			and is_equal_approx(PrototypeConfig.FORMATION_B_DURATION, 2.5),
		"formation durations are not the required 1.5s and 2.5s"
	)
	require(
		is_equal_approx(PrototypeConfig.CHARGE_A_SPEED_MULTIPLIER, 1.25)
			and is_equal_approx(
				PrototypeConfig.CHARGE_B_SPEED_MULTIPLIER, 1.50
			),
		"charge formation speed multipliers are incorrect"
	)
	require(
		is_equal_approx(PrototypeConfig.SHIELD_A_RANGED_REDUCTION, 0.35)
			and is_equal_approx(
				PrototypeConfig.SHIELD_B_RANGED_REDUCTION, 0.60
			)
			and is_equal_approx(
				PrototypeConfig.SHIELD_B_ALLY_RANGED_REDUCTION, 0.30
			),
		"shield formation ranged reductions are incorrect"
	)
	require(
		PrototypeConfig.FORMATION_ZONES.size() == 5
			and PrototypeConfig.get_spawn_points().size() >= 5,
		"formation zone or multi-spawn configuration is incomplete"
	)
	require(
		PrototypeConfig.A_PAIR_RADIUS_X > 0.0
			and PrototypeConfig.A_PAIR_RADIUS_Y > 0.0
			and PrototypeConfig.B_PAIR_RADIUS_X > 0.0
			and PrototypeConfig.B_PAIR_RADIUS_Y > 0.0
			and PrototypeConfig.FORMATION_SLOT_MOVE_SPEED > 0.0
			and PrototypeConfig.FORMATION_SLOT_TOLERANCE > 0.0
			and PrototypeConfig.FORMATION_MEET_TIMEOUT
				> PrototypeConfig.FORMATION_B_DURATION,
		"ellipse or formation steering configuration is incomplete"
	)
	require(
		PrototypeConfig.FORMATION_COMPATIBLE_ROUTE_IDS.size() == 5
			and is_equal_approx(
				PrototypeConfig.FORMATION_ROUTE_SPACING_Y,
				80.0
			)
			and PrototypeConfig.A_PAIR_NEIGHBOR_ROUTE_SPAN == 2
			and PrototypeConfig.B_PAIR_NEIGHBOR_ROUTE_SPAN == 2,
		"five-route spacing or default neighbor spans are incorrect"
	)
	var configured_route_indices: Dictionary = {}
	var previous_spawn_y := -INF
	for route_id: StringName in PrototypeConfig.FORMATION_COMPATIBLE_ROUTE_IDS:
		var route_data := PrototypeConfig.get_route_runtime_data(route_id)
		var route_index := int(route_data.get("formation_route_index", -1))
		require(
			not configured_route_indices.has(route_index),
			"compatible formation route indices are not unique"
		)
		configured_route_indices[route_index] = route_id
		var points := PrototypeConfig.get_route_points(
			route_id,
			PrototypeConfig.DEFAULT_BATTLEFIELD_SIZE
		)
		require(
			points.size() >= 2
				and (
					previous_spawn_y == -INF
					or is_equal_approx(
						points[0].y - previous_spawn_y,
						PrototypeConfig.FORMATION_ROUTE_SPACING_Y
					)
				),
			"compatible formation route spacing is not centralized or even"
		)
		previous_spawn_y = points[0].y
	var tie_first := PrototypeConfig.get_route_points(
		&"formation_upper_outer",
		PrototypeConfig.DEFAULT_BATTLEFIELD_SIZE
	)[2]
	var tie_second := PrototypeConfig.get_route_points(
		&"formation_upper",
		PrototypeConfig.DEFAULT_BATTLEFIELD_SIZE
	)[2]
	require(
		PrototypeConfig.get_nearest_formation_route_index(
			(tie_first + tie_second) * 0.5,
			PrototypeConfig.ROUTE_GROUP_FORMATION,
			PrototypeConfig.DEFAULT_BATTLEFIELD_SIZE
		) == 0,
		"equal-distance formation anchor tie did not prefer the smaller index"
	)
	var scenario := PrototypeConfig.get_scenario(&"formation_demo")
	require(
		bool(scenario.get("formations_enabled", false)),
		"formation demo does not enable formations"
	)
	var entries := PrototypeConfig.get_scenario_spawn_entries(&"formation_demo")
	require(
		scenario.get("active_spawn_point_ids", []).size() == 5
			and scenario.get("spawn_sequence", []).size() == entries.size()
			and float(scenario.get("spawn_interval", 0.0)) > 0.0,
		"formation demo is missing active spawn, interval, or sequence data"
	)
	var routes: Dictionary = {}
	var types: Dictionary = {}
	var spawn_points: Dictionary = {}
	for entry: Dictionary in entries:
		routes[StringName(entry.get("route_id", &""))] = true
		types[StringName(entry.get("monster_type", &""))] = true
		spawn_points[StringName(entry.get("spawn_point_id", &""))] = true
	require(
		routes.has(&"formation_upper_outer")
			and routes.has(&"formation_upper")
			and routes.has(&"formation_center")
			and routes.has(&"formation_lower")
			and routes.has(&"formation_lower_outer"),
		"formation demo does not cover all five compatible routes"
	)
	require(
		types.has(&"charge") and types.has(&"shield"),
		"formation demo does not include both monster types"
	)
	require(
		spawn_points.has(&"spawn_upper_outer")
			and spawn_points.has(&"spawn_upper")
			and spawn_points.has(&"spawn_center")
			and spawn_points.has(&"spawn_lower")
			and spawn_points.has(&"spawn_lower_outer"),
		"formation demo does not use five deterministic compatible spawn points"
	)
	var delayed_entry_count := 0
	for entry: Dictionary in entries:
		if float(entry.get("delay_after", 0.0)) > 0.0:
			delayed_entry_count += 1
	require(
		delayed_entry_count > 0,
		"formation demo has no deterministic per-entry longitudinal spacing"
	)


func assert_zone_and_route_rules(controller: Node) -> void:
	for zone_type: StringName in [
		PrototypeConfig.FORMATION_ZONE_SINGLE,
		PrototypeConfig.FORMATION_ZONE_A_DISPLAY,
		PrototypeConfig.FORMATION_ZONE_B,
		PrototypeConfig.FORMATION_ZONE_DEFENSE,
	]:
		await prepare_manual_run(controller)
		var center: Vector2 = controller.get_formation_zone_center(zone_type)
		spawn_test_enemies(
			controller,
			&"charge",
			[
				{
					"route_id": &"formation_upper",
					"position": center + Vector2(-18.0, -12.0),
				},
				{
					"route_id": &"formation_center",
					"position": center + Vector2(18.0, 12.0),
				},
			]
		)
		var manager = controller.get_formation_manager()
		manager.update_formations(0.0, controller.active_enemies)
		require(
			manager.get_groups_snapshot().is_empty(),
			"%s incorrectly allowed singles to start A formation"
				% String(zone_type)
		)

	await prepare_manual_run(controller)
	var a_center: Vector2 = controller.get_formation_zone_center(
		PrototypeConfig.FORMATION_ZONE_A
	)
	spawn_test_enemies(
		controller,
		&"charge",
		[
			{
				"route_id": &"formation_upper",
				"position": a_center + Vector2(-20.0, -18.0),
			},
			{
				"route_id": &"formation_center",
				"position": a_center + Vector2(20.0, 18.0),
			},
		]
	)
	var manager = controller.get_formation_manager()
	manager.update_formations(0.0, controller.active_enemies)
	require(
		manager.get_groups_snapshot().size() == 1,
		"A formation zone did not allow a legal pair"
	)

	await prepare_manual_run(controller)
	var a_members := build_complete_a(
		controller,
		&"charge",
		&"formation_upper",
		&"formation_center"
	)
	manager = controller.get_formation_manager()
	var display_center: Vector2 = controller.get_formation_zone_center(
		PrototypeConfig.FORMATION_ZONE_A_DISPLAY
	)
	for index in range(a_members.size()):
		a_members[index].set_debug_world_position(
			display_center + Vector2(0.0, -18.0 + index * 36.0)
		)
	manager.update_formations(0.0, controller.active_enemies)
	var groups: Array = manager.get_groups_snapshot()
	require(
		groups.size() == 1
			and StringName(groups[0].get("formation_level", &""))
				== PrototypeConfig.FORMATION_LEVEL_A,
		"A display zone started B formation or removed the complete A"
	)


func assert_cross_route_ellipse_and_atomic_locks(controller: Node) -> void:
	await prepare_manual_run(controller)
	var a_center: Vector2 = controller.get_formation_zone_center(
		PrototypeConfig.FORMATION_ZONE_A
	)
	var cross_route := spawn_test_enemies(
		controller,
		&"charge",
		[
			{
				"route_id": &"formation_upper",
				"position": a_center + Vector2(-12.0, -24.0),
			},
			{
				"route_id": &"formation_center",
				"position": a_center + Vector2(12.0, 24.0),
			},
		]
	)
	var manager = controller.get_formation_manager()
	manager.update_formations(0.0, controller.active_enemies)
	var groups: Array = manager.get_groups_snapshot()
	require(
		groups.size() == 1
			and cross_route[0].route_id != cross_route[1].route_id,
		"compatible route group did not allow cross-route A pairing"
	)
	require(
		StringName(groups[0].get("formation_state", &""))
			== PrototypeConfig.FORMATION_STATE_FORMING_A_LOCKED,
		"A candidate did not enter its explicit locked state"
	)

	await prepare_manual_run(controller)
	spawn_test_enemies(
		controller,
		&"charge",
		[
			{
				"route_id": &"formation_upper",
				"route_group_id": PrototypeConfig.ROUTE_GROUP_FORMATION,
				"position": a_center + Vector2(-10.0, 0.0),
			},
			{
				"route_id": &"formation_upper_outer",
				"route_group_id": PrototypeConfig.ROUTE_GROUP_ISOLATED,
				"position": a_center + Vector2(10.0, 0.0),
			},
		]
	)
	manager = controller.get_formation_manager()
	manager.update_formations(0.0, controller.active_enemies)
	require(
		manager.get_groups_snapshot().is_empty(),
		"incompatible route groups formed despite explicit compatibility rules"
	)

	for offset: Vector2 in [
		Vector2(PrototypeConfig.A_PAIR_RADIUS_X + 8.0, 0.0),
		Vector2(0.0, PrototypeConfig.A_PAIR_RADIUS_Y + 8.0),
	]:
		await prepare_manual_run(controller)
		spawn_test_enemies(
			controller,
			&"charge",
			[
				{
					"route_id": &"formation_upper",
					"position": a_center - offset * 0.5,
				},
				{
					"route_id": &"formation_center",
					"position": a_center + offset * 0.5,
				},
			]
		)
		manager = controller.get_formation_manager()
		manager.update_formations(0.0, controller.active_enemies)
		require(
			manager.get_groups_snapshot().is_empty(),
			"pair outside the configured ellipse was accepted"
		)

	await prepare_manual_run(controller)
	var candidates := spawn_test_enemies(
		controller,
		&"charge",
		[
			{
				"route_id": &"formation_upper",
				"position": a_center,
			},
			{
				"route_id": &"formation_upper",
				"position": a_center + Vector2(24.0, 0.0),
			},
			{
				"route_id": &"formation_center",
				"position": a_center + Vector2(-24.0, 0.0),
			},
		]
	)
	manager = controller.get_formation_manager()
	manager.update_formations(0.0, controller.active_enemies)
	groups = manager.get_groups_snapshot()
	require(groups.size() == 1, "three singles created multiple A locks")
	if not groups.is_empty():
		var locked_members: Array = groups[0].get("member_ids", [])
		require(
			locked_members.has(candidates[0].runtime_id)
				and locked_members.has(candidates[1].runtime_id)
				and not locked_members.has(candidates[2].runtime_id),
			"equal-distance candidate tie did not use stable spawn order"
		)
		require(
			groups[0].get("slot_assignments", {}).size() == 2,
			"A lock did not atomically assign both fixed slots"
		)
	manager.update_formations(0.0, controller.active_enemies)
	require(
		manager.get_groups_snapshot().size() == 1
			and candidates[2].formation_id == &"",
		"third monster stole or joined an already locked pair"
	)


func assert_neighbor_route_span_and_anchor_rules(controller: Node) -> void:
	var a_center: Vector2 = controller.get_formation_zone_center(
		PrototypeConfig.FORMATION_ZONE_A
	)
	for case: Dictionary in [
		{
			"span": 0,
			"first_route": &"formation_center",
			"second_route": &"formation_center",
			"expected": true,
			"label": "span 0 same route",
		},
		{
			"span": 0,
			"first_route": &"formation_upper",
			"second_route": &"formation_center",
			"expected": false,
			"label": "span 0 adjacent route",
		},
		{
			"span": 1,
			"first_route": &"formation_upper",
			"second_route": &"formation_center",
			"expected": true,
			"label": "span 1 adjacent route",
		},
		{
			"span": 1,
			"first_route": &"formation_upper_outer",
			"second_route": &"formation_center",
			"expected": false,
			"label": "span 1 two-route gap",
		},
		{
			"span": 2,
			"first_route": &"formation_upper",
			"second_route": &"formation_center",
			"expected": true,
			"label": "span 2 adjacent route",
		},
		{
			"span": 2,
			"first_route": &"formation_upper_outer",
			"second_route": &"formation_center",
			"expected": true,
			"label": "span 2 two-route gap",
		},
	]:
		await prepare_manual_run(controller)
		var manager = controller.get_formation_manager()
		manager.set_neighbor_route_spans(int(case.get("span", 0)), 2)
		spawn_test_enemies(
			controller,
			&"charge",
			[
				{
					"route_id": StringName(case.get("first_route", &"")),
					"position": a_center + Vector2(-18.0, -22.0),
				},
				{
					"route_id": StringName(case.get("second_route", &"")),
					"position": a_center + Vector2(18.0, 22.0),
				},
			]
		)
		manager.update_formations(0.0, controller.active_enemies)
		require(
			(manager.get_groups_snapshot().size() == 1)
				== bool(case.get("expected", false)),
			"%s produced the wrong A candidate result" % String(case.get("label", ""))
		)

	await prepare_manual_run(controller)
	var manager = controller.get_formation_manager()
	manager.set_neighbor_route_spans(2, 2)
	spawn_test_enemies(
		controller,
		&"charge",
		[
			{
				"route_id": &"formation_center",
				"formation_route_index": 2,
				"route_group_id": PrototypeConfig.ROUTE_GROUP_FORMATION,
				"position": a_center + Vector2(-16.0, 0.0),
			},
			{
				"route_id": &"formation_isolated",
				"formation_route_index": 2,
				"route_group_id": PrototypeConfig.ROUTE_GROUP_ISOLATED,
				"position": a_center + Vector2(16.0, 0.0),
			},
		]
	)
	manager.update_formations(0.0, controller.active_enemies)
	require(
		manager.get_groups_snapshot().is_empty(),
		"matching route indices bypassed incompatible route groups"
	)

	await prepare_manual_run(controller)
	manager = controller.get_formation_manager()
	manager.set_neighbor_route_spans(2, 1)
	var first_route_center := get_route_point_in_zone(
		controller,
		&"formation_upper_outer",
		PrototypeConfig.FORMATION_ZONE_A
	)
	var second_route_center := get_route_point_in_zone(
		controller,
		&"formation_center",
		PrototypeConfig.FORMATION_ZONE_A
	)
	var first_members := spawn_test_enemies(
		controller,
		&"charge",
		[
			{
				"route_id": &"formation_upper_outer",
				"position": first_route_center + Vector2(-24.0, 0.0),
			},
			{
				"route_id": &"formation_upper_outer",
				"position": first_route_center + Vector2(24.0, 0.0),
			},
		]
	)
	manager.update_formations(0.0, controller.active_enemies)
	advance_manager(
		manager,
		controller.active_enemies,
		PrototypeConfig.FORMATION_A_DURATION + 0.2
	)
	var first_a = manager.get_member_group(first_members[0].runtime_id)
	require(
		first_a != null and first_a.formation_anchor_route_index == 0,
		"first complete A did not resolve its configured route-0 anchor"
	)
	var stable_anchor: int = (
		first_a.formation_anchor_route_index if first_a != null else -1
	)
	for enemy in first_members:
		enemy.set_debug_world_position(
			second_route_center + Vector2(0.0, -24.0 if enemy == first_members[0] else 24.0)
		)
	manager.update_formations(0.0, controller.active_enemies)
	require(
		first_a != null
			and first_a.formation_anchor_route_index == stable_anchor,
		"complete A anchor changed after member steering"
	)

	var second_members := spawn_test_enemies(
		controller,
		&"charge",
		[
			{
				"route_id": &"formation_center",
				"position": second_route_center + Vector2(-24.0, 0.0),
			},
			{
				"route_id": &"formation_center",
				"position": second_route_center + Vector2(24.0, 0.0),
			},
		]
	)
	manager.update_formations(0.0, controller.active_enemies)
	advance_manager(
		manager,
		controller.active_enemies,
		PrototypeConfig.FORMATION_A_DURATION + 0.2
	)
	var second_a = manager.get_member_group(second_members[0].runtime_id)
	require(
		second_a != null and second_a.formation_anchor_route_index == 2,
		"second complete A did not resolve its configured route-2 anchor"
	)
	var b_center: Vector2 = controller.get_formation_zone_center(
		PrototypeConfig.FORMATION_ZONE_B
	)
	for member_index in range(first_members.size()):
		first_members[member_index].set_debug_world_position(
			b_center + Vector2(
				-26.0,
				-28.0 if member_index == 0 else 28.0
			)
		)
	for member_index in range(second_members.size()):
		second_members[member_index].set_debug_world_position(
			b_center + Vector2(
				26.0,
				-28.0 if member_index == 0 else 28.0
			)
		)
	manager.update_formations(0.0, controller.active_enemies)
	require(
		get_groups_by_state(
			manager.get_groups_snapshot(),
			PrototypeConfig.FORMATION_STATE_FORMING_B
		).is_empty(),
		"B span 1 ignored stable source anchors separated by two routes"
	)
	manager.set_neighbor_route_spans(2, 2)
	manager.update_formations(0.0, controller.active_enemies)
	var forming_b_groups := get_groups_by_state(
		manager.get_groups_snapshot(),
		PrototypeConfig.FORMATION_STATE_FORMING_B
	)
	require(
		forming_b_groups.size() == 1
			and forming_b_groups[0].get(
				"source_a_anchor_route_indices",
				[]
			) == [0, 2],
		"B span 2 did not use the two stable A anchor indices"
	)


func assert_a_formation_rules(controller: Node) -> void:
	await prepare_manual_run(controller)
	var a_center: Vector2 = controller.get_formation_zone_center(
		PrototypeConfig.FORMATION_ZONE_A
	)
	var enemies := spawn_test_enemies(
		controller,
		&"charge",
		[
			{
				"route_id": &"formation_upper",
				"position": a_center + Vector2(-32.0, 0.0),
			},
			{
				"route_id": &"formation_upper",
				"position": a_center + Vector2(32.0, 0.0),
			},
		]
	)
	var manager = controller.get_formation_manager()
	manager.update_formations(0.0, controller.active_enemies)
	var groups: Array = manager.get_groups_snapshot()
	require(groups.size() == 1, "two legal singles did not enter FORMING_A")
	if groups.is_empty():
		return
	require(
		StringName(groups[0].get("formation_state", &""))
			== PrototypeConfig.FORMATION_STATE_FORMING_A_LOCKED,
		"legal A candidate has the wrong state"
	)
	require(
		unique_member_count(groups[0]) == 2,
		"A candidate does not contain two unique members"
	)
	manager.update_formations(0.5, controller.active_enemies)
	var progress_before_damage := float(
		manager.get_groups_snapshot()[0].get("formation_progress", 0.0)
	)
	enemies[0].take_damage(1, PrototypeConfig.DAMAGE_SOURCE_RANGED)
	var progress_after_damage := float(
		manager.get_groups_snapshot()[0].get("formation_progress", 0.0)
	)
	require(
		is_equal_approx(progress_before_damage, progress_after_damage),
		"ordinary damage reset A formation progress"
	)
	manager.update_formations(0.99, controller.active_enemies)
	var before_complete: Dictionary = manager.get_groups_snapshot()[0]
	require(
		StringName(before_complete.get("formation_state", &""))
			== PrototypeConfig.FORMATION_STATE_FORMING_A_LOCKED
			and float(before_complete.get("formation_progress", 1.0)) < 1.0,
		"A formation completed before 1.5 seconds"
	)
	manager.update_formations(0.02, controller.active_enemies)
	var completed: Dictionary = manager.get_groups_snapshot()[0]
	require(
		StringName(completed.get("formation_state", &""))
			== PrototypeConfig.FORMATION_STATE_COMPLETE
			and StringName(completed.get("formation_level", &""))
				== PrototypeConfig.FORMATION_LEVEL_A,
		"A formation did not complete after 1.5 seconds"
	)
	for enemy in enemies:
		require(
			is_equal_approx(
				float(enemy.formation_speed_multiplier),
				PrototypeConfig.CHARGE_A_SPEED_MULTIPLIER
			),
			"charge A member did not receive the 25% speed bonus"
		)
	require(
		enemies[0].position.distance_to(enemies[1].position)
			>= PrototypeConfig.A_SLOT_GAP_Y
				- PrototypeConfig.FORMATION_SLOT_TOLERANCE * 2.0,
		"A members overlapped instead of occupying two vertical slots"
	)

	await prepare_manual_run(controller)
	var crossing_members := spawn_test_enemies(
		controller,
		&"charge",
		[
			{
				"route_id": &"formation_upper",
				"position": a_center + Vector2(-30.0, -10.0),
			},
			{
				"route_id": &"formation_center",
				"position": a_center + Vector2(30.0, 10.0),
			},
		]
	)
	manager = controller.get_formation_manager()
	manager.update_formations(0.0, controller.active_enemies)
	var display_center: Vector2 = controller.get_formation_zone_center(
		PrototypeConfig.FORMATION_ZONE_A_DISPLAY
	)
	crossing_members[0].set_debug_world_position(
		display_center + Vector2(-25.0, -15.0)
	)
	crossing_members[1].set_debug_world_position(
		display_center + Vector2(25.0, 15.0)
	)
	advance_manager(
		manager,
		controller.active_enemies,
		PrototypeConfig.FORMATION_A_DURATION + 0.4
	)
	var crossing_groups: Array = manager.get_groups_snapshot()
	require(
		crossing_groups.size() == 1
			and StringName(crossing_groups[0].get("formation_state", &""))
				== PrototypeConfig.FORMATION_STATE_COMPLETE,
		"locked A pair was cancelled after crossing its zone boundary"
	)


func assert_invalid_and_deterministic_candidates(controller: Node) -> void:
	await prepare_manual_run(controller)
	var a_center: Vector2 = controller.get_formation_zone_center(
		PrototypeConfig.FORMATION_ZONE_A
	)
	spawn_test_enemies(controller, &"charge", [{
		"route_id": &"formation_upper",
		"position": a_center + Vector2(-10.0, 0.0),
	}])
	spawn_test_enemies(controller, &"shield", [{
		"route_id": &"formation_upper",
		"position": a_center + Vector2(10.0, 0.0),
	}])
	var manager = controller.get_formation_manager()
	manager.update_formations(0.0, controller.active_enemies)
	require(
		manager.get_groups_snapshot().is_empty(),
		"different monster types produced a formation"
	)

	var pair_specs := [
		{
			"name": &"front_back",
			"positions": [
				a_center + Vector2(-36.0, 0.0),
				a_center + Vector2(36.0, 0.0),
			],
		},
		{
			"name": &"vertical",
			"positions": [
				a_center + Vector2(0.0, -34.0),
				a_center + Vector2(0.0, 34.0),
			],
		},
		{
			"name": &"diagonal",
			"positions": [
				a_center + Vector2(-30.0, -28.0),
				a_center + Vector2(30.0, 28.0),
			],
		},
	]
	for pair_spec: Dictionary in pair_specs:
		await prepare_manual_run(controller)
		var pair_positions: Array = pair_spec.get("positions", [])
		spawn_test_enemies(
			controller,
			&"charge",
			[
				{
					"route_id": &"formation_upper",
					"position": pair_positions[0],
				},
				{
					"route_id": (
						&"formation_upper"
						if StringName(pair_spec.get("name", &""))
							== &"front_back"
						else &"formation_center"
					),
					"position": pair_positions[1],
				},
			]
		)
		manager = controller.get_formation_manager()
		manager.update_formations(0.0, controller.active_enemies)
		advance_manager(
			manager,
			controller.active_enemies,
			PrototypeConfig.FORMATION_A_DURATION + 0.5
		)
		var groups: Array = manager.get_groups_snapshot()
		require(
			groups.size() == 1
				and StringName(groups[0].get("pair_mode", &""))
					== StringName(pair_spec.get("name", &"")),
			"%s A pair was not deterministically classified or completed"
				% String(pair_spec.get("name", &""))
		)
		var all_assigned: Dictionary = {}
		for group: Dictionary in groups:
			for member_id: StringName in group.get("member_ids", []):
				require(
					not all_assigned.has(member_id),
					"one monster entered multiple candidate groups"
				)
				all_assigned[member_id] = true


func assert_b_formation_rules(controller: Node) -> void:
	await prepare_manual_run(controller)
	var enemies := build_complete_b(
		controller,
		&"charge",
		&"top",
		Vector2(700.0, 120.0),
		false
	)
	var manager = controller.get_formation_manager()
	var forming_groups: Array = manager.get_groups_snapshot()
	require(
		forming_groups.size() == 1
			and StringName(forming_groups[0].get("formation_state", &""))
				== PrototypeConfig.FORMATION_STATE_FORMING_B,
		"two complete A formations did not enter FORMING_B"
	)
	require(
		unique_member_count(forming_groups[0]) == 4,
		"forming B does not contain four unique members"
	)
	for enemy in enemies:
		require(
			is_equal_approx(
				float(enemy.formation_speed_multiplier),
				PrototypeConfig.CHARGE_A_SPEED_MULTIPLIER
			),
			"FORMING_B did not preserve the complete source A effect"
		)
	var b_progress_before_damage := float(
		forming_groups[0].get("formation_progress", 0.0)
	)
	enemies[0].take_damage(1, PrototypeConfig.DAMAGE_SOURCE_RANGED)
	require(
		is_equal_approx(
			b_progress_before_damage,
			float(
				manager.get_groups_snapshot()[0].get(
					"formation_progress", 0.0
				)
			)
		),
		"ordinary damage interrupted or reset FORMING_B"
	)
	manager.update_formations(2.49, controller.active_enemies)
	var before_complete: Dictionary = manager.get_groups_snapshot()[0]
	require(
		StringName(before_complete.get("formation_state", &""))
			== PrototypeConfig.FORMATION_STATE_FORMING_B,
		"B formation completed before 2.5 seconds"
	)
	manager.update_formations(0.02, controller.active_enemies)
	var completed: Dictionary = manager.get_groups_snapshot()[0]
	require(
		StringName(completed.get("formation_state", &""))
			== PrototypeConfig.FORMATION_STATE_COMPLETE
			and StringName(completed.get("formation_level", &""))
				== PrototypeConfig.FORMATION_LEVEL_B
			and unique_member_count(completed) == 4,
		"B formation did not complete with four unique members"
	)
	for enemy in enemies:
		require(
			is_equal_approx(
				float(enemy.formation_speed_multiplier),
				PrototypeConfig.CHARGE_B_SPEED_MULTIPLIER
			),
			"charge B member did not receive the 50% speed bonus"
		)

	await prepare_manual_run(controller)
	enemies = build_complete_b(
		controller,
		&"charge",
		&"top",
		Vector2(700.0, 120.0),
		false
	)
	manager = controller.get_formation_manager()
	var break_result: Dictionary = controller.interrupt_enemy_formation(
		enemies[0].runtime_id,
		PrototypeConfig.INTERRUPTION_FORMATION_BREAK
	)
	var restored_a_groups := get_groups_by_level(
		manager.get_groups_snapshot(),
		PrototypeConfig.FORMATION_LEVEL_A
	)
	require(
		bool(break_result.get("interrupted", false))
			and restored_a_groups.size() == 2,
		"FORMING_B interruption did not restore both complete source A formations"
	)


func assert_slot_completion_and_timeout(controller: Node) -> void:
	await prepare_manual_run(controller)
	var a_center: Vector2 = controller.get_formation_zone_center(
		PrototypeConfig.FORMATION_ZONE_A
	)
	var wide_members := spawn_test_enemies(
		controller,
		&"charge",
		[
			{
				"route_id": &"formation_upper",
				"position": a_center + Vector2(-70.0, 0.0),
			},
			{
				"route_id": &"formation_upper",
				"position": a_center + Vector2(70.0, 0.0),
			},
		]
	)
	var manager = controller.get_formation_manager()
	manager.update_formations(0.0, controller.active_enemies)
	manager.update_formations(
		PrototypeConfig.FORMATION_A_DURATION + 0.01,
		controller.active_enemies
	)
	var groups: Array = manager.get_groups_snapshot()
	require(
		groups.size() == 1
			and StringName(groups[0].get("formation_state", &""))
				== PrototypeConfig.FORMATION_STATE_FORMING_A_LOCKED
			and float(groups[0].get("time_progress", 0.0)) >= 1.0
			and float(groups[0].get("position_progress", 1.0)) < 1.0,
		"A formation completed on time before entering slot tolerance"
	)
	advance_manager(manager, controller.active_enemies, 2.0)
	groups = manager.get_groups_snapshot()
	require(
		groups.size() == 1
			and StringName(groups[0].get("formation_state", &""))
				== PrototypeConfig.FORMATION_STATE_COMPLETE,
		"A formation did not complete after both time and slot conditions"
	)
	require(
		wide_members[0].position.distance_to(wide_members[1].position)
			> PrototypeConfig.FORMATION_SLOT_TOLERANCE * 2.0,
		"A slot convergence overlapped the two independent members"
	)

	await prepare_manual_run(controller)
	var timeout_members := spawn_test_enemies(
		controller,
		&"charge",
		[
			{
				"route_id": &"formation_upper",
				"position": a_center + Vector2(-20.0, 0.0),
			},
			{
				"route_id": &"formation_upper",
				"position": a_center + Vector2(20.0, 0.0),
			},
		]
	)
	manager = controller.get_formation_manager()
	manager.update_formations(0.0, controller.active_enemies)
	var timeout_group = manager.get_group(timeout_members[0].formation_id)
	if timeout_group != null:
		timeout_group.slot_assignments[timeout_members[0].runtime_id] = Vector2(
			0.0,
			-1800.0
		)
		timeout_group.slot_assignments[timeout_members[1].runtime_id] = Vector2(
			0.0,
			1800.0
		)
	advance_manager(
		manager,
		controller.active_enemies,
		PrototypeConfig.FORMATION_MEET_TIMEOUT + 0.2
	)
	var timeout_stats: Dictionary = manager.get_stats_snapshot(
		controller.active_enemies
	)
	require(
		manager.get_groups_snapshot().is_empty()
			and timeout_members[0].formation_id == &""
			and timeout_members[1].formation_id == &""
			and int(timeout_stats.get("meet_timeout_count", 0)) == 1,
		"meeting timeout did not safely release both candidate locks"
	)

	await prepare_manual_run(controller)
	var b_members := build_complete_b(
		controller,
		&"charge",
		&"middle",
		Vector2.ZERO,
		true
	)
	manager = controller.get_formation_manager()
	var b_group = manager.find_complete_group(
		&"charge",
		PrototypeConfig.FORMATION_LEVEL_B
	)
	require(b_group != null, "B slot test could not complete a formation")
	if b_group != null:
		var unique_slots: Dictionary = {}
		var unique_x: Dictionary = {}
		var unique_y: Dictionary = {}
		for member_id: StringName in b_group.member_ids:
			var slot: Vector2 = b_group.slot_assignments.get(
				member_id,
				Vector2.ZERO
			)
			unique_slots[slot] = true
			unique_x[snappedf(slot.x, 0.01)] = true
			unique_y[snappedf(slot.y, 0.01)] = true
		require(
			b_members.size() == 4
				and unique_slots.size() == 4
				and unique_x.size() == 2
				and unique_y.size() == 2,
			"B formation did not retain four unique 2x2 slot assignments"
		)


func assert_member_and_control_interruptions(controller: Node) -> void:
	await prepare_manual_run(controller)
	var death_members := spawn_cluster(
		controller,
		&"charge",
		&"top",
		[Vector2(800.0, 100.0), Vector2(825.0, 100.0)]
	)
	var manager = controller.get_formation_manager()
	manager.update_formations(0.4, controller.active_enemies)
	death_members[0].take_damage(9999)
	require(
		manager.get_groups_snapshot().is_empty()
			and death_members[1].formation_id == &"",
		"member death did not interrupt unfinished A formation"
	)

	await prepare_manual_run(controller)
	var leak_members := spawn_cluster(
		controller,
		&"charge",
		&"top",
		[Vector2(800.0, 100.0), Vector2(825.0, 100.0)]
	)
	manager = controller.get_formation_manager()
	manager.update_formations(0.4, controller.active_enemies)
	controller.handle_enemy_arrival(
		leak_members[0].runtime_id,
		&"top",
		1
	)
	require(
		manager.get_groups_snapshot().is_empty()
			and leak_members[1].formation_id == &"",
		"member leak did not interrupt unfinished A formation"
	)

	await prepare_manual_run(controller)
	var forming_b_members := build_complete_b(
		controller,
		&"shield",
		&"middle",
		Vector2(700.0, 200.0),
		false
	)
	manager = controller.get_formation_manager()
	forming_b_members[0].take_damage(9999)
	var surviving_source_groups := get_groups_by_level(
		manager.get_groups_snapshot(),
		PrototypeConfig.FORMATION_LEVEL_A
	)
	require(
		surviving_source_groups.size() == 1
			and unique_member_count(surviving_source_groups[0]) == 2,
		"FORMING_B member death did not preserve the intact source A formation"
	)

	for reason: StringName in [
		PrototypeConfig.INTERRUPTION_STUN,
		PrototypeConfig.INTERRUPTION_KNOCKBACK,
		PrototypeConfig.INTERRUPTION_FORMATION_BREAK,
	]:
		await prepare_manual_run(controller)
		var members := spawn_cluster(
			controller,
			&"charge",
			&"top",
			[Vector2(800.0, 100.0), Vector2(825.0, 100.0)]
		)
		manager = controller.get_formation_manager()
		manager.update_formations(0.4, controller.active_enemies)
		var result: Dictionary = controller.interrupt_enemy_formation(
			members[0].runtime_id,
			reason
		)
		require(
			bool(result.get("interrupted", false))
				and not bool(result.get("resisted", false))
				and manager.get_groups_snapshot().is_empty(),
			"%s did not interrupt unfinished formation" % String(reason)
		)


func assert_charge_control_resistance(controller: Node) -> void:
	await prepare_manual_run(controller)
	var members := build_complete_b(
		controller,
		&"charge",
		&"top",
		Vector2(700.0, 100.0),
		true
	)
	var manager = controller.get_formation_manager()
	var first_result: Dictionary = controller.interrupt_enemy_formation(
		members[0].runtime_id,
		PrototypeConfig.INTERRUPTION_STUN
	)
	require(
		bool(first_result.get("resisted", false))
			and not bool(first_result.get("interrupted", false))
			and manager.find_complete_group(
				&"charge", PrototypeConfig.FORMATION_LEVEL_B
			) != null,
		"charge B did not absorb its first control interruption"
	)
	var second_result: Dictionary = controller.interrupt_enemy_formation(
		members[1].runtime_id,
		PrototypeConfig.INTERRUPTION_KNOCKBACK
	)
	require(
		not bool(second_result.get("resisted", false))
			and bool(second_result.get("interrupted", false))
			and manager.find_complete_group(
				&"charge", PrototypeConfig.FORMATION_LEVEL_B
			) == null,
		"charge B resisted a second control interruption"
	)

	await prepare_manual_run(controller)
	members = build_complete_b(
		controller,
		&"charge",
		&"top",
		Vector2(700.0, 100.0),
		true
	)
	manager = controller.get_formation_manager()
	members[3].take_damage(9999)
	var stats: Dictionary = manager.get_stats_snapshot(controller.active_enemies)
	require(
		int(stats.get("control_resistance_consumed_count", -1)) == 0
			and manager.find_complete_group(
				&"charge", PrototypeConfig.FORMATION_LEVEL_B
			) == null,
		"charge B incorrectly resisted member death"
	)

	await prepare_manual_run(controller)
	members = build_complete_b(
		controller,
		&"charge",
		&"top",
		Vector2(700.0, 100.0),
		true
	)
	manager = controller.get_formation_manager()
	controller.handle_enemy_arrival(members[3].runtime_id, &"top", 1)
	stats = manager.get_stats_snapshot(controller.active_enemies)
	require(
		int(stats.get("control_resistance_consumed_count", -1)) == 0
			and manager.find_complete_group(
				&"charge", PrototypeConfig.FORMATION_LEVEL_B
			) == null,
		"charge B incorrectly resisted member leak"
	)


func assert_shield_damage_effects(controller: Node) -> void:
	await prepare_manual_run(controller)
	var a_members := spawn_cluster(
		controller,
		&"shield",
		&"middle",
		[Vector2(800.0, 200.0), Vector2(825.0, 200.0)]
	)
	var manager = controller.get_formation_manager()
	manager.update_formations(0.0, controller.active_enemies)
	manager.update_formations(1.51, controller.active_enemies)
	require(
		is_equal_approx(
			a_members[0].get_effective_ranged_reduction(),
			PrototypeConfig.SHIELD_A_RANGED_REDUCTION
		),
		"shield A did not receive 35% ranged reduction"
	)
	var ranged_a := int(
		a_members[0].take_damage(20, PrototypeConfig.DAMAGE_SOURCE_RANGED)
	)
	var melee_a := int(
		a_members[0].take_damage(20, PrototypeConfig.DAMAGE_SOURCE_MELEE)
	)
	require(ranged_a == 13, "shield A ranged reduction applied wrong damage")
	require(melee_a == 20, "shield A reduced guard melee damage")

	await prepare_manual_run(controller)
	var first_b := build_complete_b(
		controller,
		&"shield",
		&"middle",
		Vector2.ZERO,
		true
	)
	var second_b := build_complete_b(
		controller,
		&"shield",
		&"middle",
		Vector2.ZERO,
		true
	)
	var b_center: Vector2 = controller.get_formation_zone_center(
		PrototypeConfig.FORMATION_ZONE_B
	)
	var protected: Variant = spawn_test_enemies(
		controller,
		&"charge",
		[{
			"route_id": &"formation_center",
			"position": b_center + Vector2(0.0, 82.0),
		}]
	)[0]
	manager = controller.get_formation_manager()
	manager.update_formations(0.0, controller.active_enemies)
	var b_groups := get_groups_by_level(
		manager.get_groups_snapshot(),
		PrototypeConfig.FORMATION_LEVEL_B
	)
	require(b_groups.size() == 2, "shield setup did not produce two B formations")
	require(
		is_equal_approx(
			first_b[0].get_effective_ranged_reduction(),
			PrototypeConfig.SHIELD_B_RANGED_REDUCTION
		),
		"shield B member did not receive 60% ranged reduction"
	)
	require(
		is_equal_approx(
			protected.get_effective_ranged_reduction(),
			PrototypeConfig.SHIELD_B_ALLY_RANGED_REDUCTION
		),
		"nearby ally did not receive exactly one 30% shield protection"
	)
	protected.set_protection_ranged_reduction(0.1)
	require(
		is_equal_approx(
			protected.get_effective_ranged_reduction(),
			PrototypeConfig.SHIELD_B_ALLY_RANGED_REDUCTION
		),
		"multiple shield protection writes stacked instead of using the maximum"
	)
	var ranged_b := int(
		first_b[0].take_damage(20, PrototypeConfig.DAMAGE_SOURCE_RANGED)
	)
	var protected_ranged := int(
		protected.take_damage(20, PrototypeConfig.DAMAGE_SOURCE_RANGED)
	)
	var melee_b := int(
		second_b[0].take_damage(20, PrototypeConfig.DAMAGE_SOURCE_MELEE)
	)
	require(ranged_b == 8, "shield B ranged reduction applied wrong damage")
	require(
		protected_ranged == 14,
		"shield B nearby protection applied wrong damage or stacked"
	)
	require(melee_b == 20, "shield B reduced guard melee damage")


func assert_dissolve_and_downgrade(controller: Node) -> void:
	await prepare_manual_run(controller)
	var a_members := spawn_cluster(
		controller,
		&"shield",
		&"middle",
		[Vector2(800.0, 200.0), Vector2(825.0, 200.0)]
	)
	var manager = controller.get_formation_manager()
	manager.update_formations(0.0, controller.active_enemies)
	manager.update_formations(1.51, controller.active_enemies)
	a_members[0].take_damage(9999)
	require(
		a_members[1].formation_id == &""
			and a_members[1].formation_level
				== PrototypeConfig.FORMATION_LEVEL_SINGLE
			and manager.get_groups_snapshot().is_empty(),
		"A formation did not dissolve to a single survivor"
	)

	await prepare_manual_run(controller)
	var b_members := build_complete_b(
		controller,
		&"shield",
		&"middle",
		Vector2(700.0, 200.0),
		true
	)
	manager = controller.get_formation_manager()
	b_members[3].take_damage(9999)
	var groups: Array = manager.get_groups_snapshot()
	require(
		groups.size() == 1
			and StringName(groups[0].get("formation_level", &""))
				== PrototypeConfig.FORMATION_LEVEL_A
			and unique_member_count(groups[0]) == 2,
		"B member loss did not immediately downgrade to one A formation"
	)
	var remaining := [b_members[0], b_members[1], b_members[2]]
	remaining.sort_custom(func(first, second):
		return int(first.spawn_sequence) < int(second.spawn_sequence)
	)
	require(
		remaining[0].formation_id != &""
			and remaining[0].formation_id == remaining[1].formation_id
			and remaining[2].formation_id == &"",
		"B downgrade did not choose the first two stable survivors"
	)
	var stats: Dictionary = manager.get_stats_snapshot(controller.active_enemies)
	require(
		int(stats.get("downgrade_count", 0)) == 1,
		"B downgrade statistic was not incremented once"
	)


func assert_formation_members_block_independently(controller: Node) -> void:
	await prepare_manual_run(controller, &"guard")
	var guard = controller.get_character_node(&"guard")
	var members := build_complete_b(
		controller,
		&"charge",
		&"middle",
		guard.position,
		true,
		0.0
	)
	controller.update_enemy_blocking()
	var blocked_count := 0
	for enemy in members:
		if enemy.blocked_by_character_id == &"guard":
			blocked_count += 1
	require(
		blocked_count == 2 and guard.blocked_enemy_ids.size() == 2,
		"formation was treated as one block unit instead of four members"
	)


func assert_formation_settlement_is_idempotent(controller: Node) -> void:
	await prepare_manual_run(controller)
	var members := spawn_cluster(
		controller,
		&"charge",
		&"top",
		[Vector2(800.0, 100.0), Vector2(825.0, 100.0)]
	)
	var manager = controller.get_formation_manager()
	manager.update_formations(0.0, controller.active_enemies)
	var dead_id := StringName(members[0].runtime_id)
	members[0].take_damage(9999)
	members[0].take_damage(9999)
	controller.handle_enemy_arrival(dead_id, &"top", 1)
	var leaked_id := StringName(members[1].runtime_id)
	controller.handle_enemy_arrival(leaked_id, &"top", 1)
	members[1].take_damage(9999)
	controller.handle_enemy_death(leaked_id)
	var snapshot: Dictionary = controller.get_battle_snapshot()
	require(
		int(snapshot.get("killed_enemy_count", -1)) == 1
			and int(snapshot.get("leaked_enemy_count", -1)) == 1
			and int(snapshot.get("resolved_enemy_count", -1)) == 2,
		"formation member death or leak settled more than once"
	)
	require(
		int(snapshot.get("resolved_enemy_count", -1))
			== int(snapshot.get("killed_enemy_count", 0))
				+ int(snapshot.get("leaked_enemy_count", 0)),
		"formation settlement totals diverged"
	)
	require(
		manager.get_groups_snapshot().is_empty(),
		"settled formation members left a ghost group"
	)


func assert_two_actual_demo_runs(controller: Node) -> void:
	controller.restart_battle()
	await process_frame
	controller.clear_deployment()
	require(
		controller.select_scenario(&"formation_demo"),
		"formation demo scenario selection failed"
	)
	require(
		controller.apply_recommended_deployment(),
		"formation demo could not apply recommended deployment"
	)
	require(controller.start_battle(), "first formation demo could not start")
	var first_duration := run_until_finished(controller)
	var first_snapshot: Dictionary = controller.get_battle_snapshot()
	assert_actual_demo_snapshot(first_snapshot, "first")
	record_demo_result("demo-1", first_snapshot, first_duration)

	controller.restart_battle()
	await process_frame
	var ready_stats: Dictionary = controller.get_formation_stats_snapshot()
	require(
		int(ready_stats.get("active_group_count", -1)) == 0
			and int(ready_stats.get("member_assignment_count", -1)) == 0
			and int(ready_stats.get("completed_a_count", -1)) == 0
			and int(ready_stats.get("completed_b_count", -1)) == 0,
		"restart retained formation groups, candidates, members, or statistics"
	)
	require(
		controller.get_battle_snapshot().get("deployment", {}).size() == 4,
		"restart did not preserve recommended deployment"
	)
	require(controller.start_battle(), "second formation demo could not start")
	var second_duration := run_until_finished(controller)
	var second_snapshot: Dictionary = controller.get_battle_snapshot()
	assert_actual_demo_snapshot(second_snapshot, "second")
	record_demo_result("demo-2", second_snapshot, second_duration)
	require(
		String(first_snapshot.get("state", ""))
			== String(second_snapshot.get("state", "")),
		"two deterministic formation demos produced different outcomes"
	)
	require(
		build_demo_signature(first_snapshot)
			== build_demo_signature(second_snapshot),
		"two deterministic formation demos changed pairing or completion order"
	)
	require(
		finished_outcomes.size() == 2,
		"formation demo emitted missing or duplicate finish signals"
	)
	require(
		int(second_snapshot.get("battle_finish_count", -1)) == 2,
		"formation demo finish handling was not once per run"
	)


func assert_actual_demo_snapshot(snapshot: Dictionary, run_name: String) -> void:
	var stats: Dictionary = snapshot.get("formation_stats", {})
	var completed_a: Dictionary = stats.get("completed_a_by_type", {})
	var completed_b: Dictionary = stats.get("completed_b_by_type", {})
	require(
		int(completed_a.get(&"charge", 0)) > 0
			and int(completed_a.get(&"shield", 0)) > 0,
		"%s demo did not complete A formations for both monster types" % run_name
	)
	require(
		int(completed_b.get(&"charge", 0)) > 0
			and int(completed_b.get(&"shield", 0)) > 0,
		"%s demo did not complete B formations for both monster types" % run_name
	)
	require(
		int(snapshot.get("speed_effect_observed_count", 0)) > 0,
		"%s demo did not observe a charge speed effect" % run_name
	)
	require(
		bool(snapshot.get("demo_control_resistance_triggered", false))
			and int(stats.get("control_resistance_consumed_count", 0)) > 0,
		"%s demo did not consume charge B control resistance" % run_name
	)
	require(
		int(snapshot.get("formation_damage_reduction_event_count", 0)) > 0,
		"%s demo did not apply shield ranged reduction" % run_name
	)
	require(
		int(stats.get("max_protected_target_count", 0)) > 0,
		"%s demo did not apply shield B nearby protection" % run_name
	)
	require(
		int(stats.get("interrupted_count", 0)) > 0
			and int(stats.get("downgrade_count", 0)) > 0,
		"%s demo did not downgrade or dissolve a formation after member loss"
			% run_name
	)
	require(
		int(snapshot.get("resolved_enemy_count", -1))
			== int(snapshot.get("killed_enemy_count", 0))
				+ int(snapshot.get("leaked_enemy_count", 0)),
		"%s demo settlement totals diverged" % run_name
	)
	require(
		int(snapshot.get("active_enemy_count", -1)) == 0
			and int(stats.get("active_group_count", -1)) == 0
			and int(stats.get("member_assignment_count", -1)) == 0,
		"%s demo ended with active enemies or ghost formation members" % run_name
	)
	var route_counts: Dictionary = snapshot.get("generated_by_route", {})
	for route_id: StringName in PrototypeConfig.FORMATION_COMPATIBLE_ROUTE_IDS:
		require(
			int(route_counts.get(route_id, 0)) > 0,
			"%s demo generated no %s enemies" % [run_name, String(route_id)]
		)
	var spawn_counts: Dictionary = snapshot.get("generated_by_spawn_point", {})
	for spawn_point_id: StringName in [
		&"spawn_upper_outer",
		&"spawn_upper",
		&"spawn_center",
		&"spawn_lower",
		&"spawn_lower_outer",
	]:
		require(
			int(spawn_counts.get(spawn_point_id, 0)) > 0,
			"%s demo did not use %s" % [run_name, String(spawn_point_id)]
		)
	var type_counts: Dictionary = snapshot.get("generated_by_monster_type", {})
	require(
		int(type_counts.get(&"charge", 0)) > 0
			and int(type_counts.get(&"shield", 0)) > 0,
		"%s demo did not generate both monster types" % run_name
	)
	var pair_modes: Dictionary = stats.get("completed_a_pair_modes", {})
	var route_spans: Dictionary = stats.get("completed_a_route_spans", {})
	require(
		int(pair_modes.get(&"front_back", 0)) > 0
			and int(pair_modes.get(&"vertical", 0)) > 0
			and int(pair_modes.get(&"diagonal", 0)) > 0
			and int(route_spans.get(0, 0)) > 0
			and int(route_spans.get(1, 0)) > 0
			and int(route_spans.get(2, 0)) > 0
			and int(stats.get("cross_route_a_count", 0)) > 0,
		"%s demo did not cover pair modes and route spans 0/1/2"
			% run_name
	)
	var a_observations: Array = stats.get("completed_a_observations", [])
	require(
		a_observations.size() >= 6,
		"%s demo did not record all A lock-to-complete observations" % run_name
	)
	for observation: Dictionary in a_observations:
		require(
			float(observation.get("initial_slot_error", 0.0))
				> PrototypeConfig.FORMATION_SLOT_TOLERANCE
				and float(observation.get("lock_to_complete_duration", 0.0))
					>= PrototypeConfig.FORMATION_A_DURATION,
			"%s demo A formation locked too close or completed too early"
				% run_name
		)
	var battlefield_width := PrototypeConfig.DEFAULT_BATTLEFIELD_SIZE.x
	var observations: Array = stats.get("completed_b_observations", [])
	require(
		observations.size() >= 2,
		"%s demo did not record both monster B completions" % run_name
	)
	for observation: Dictionary in observations:
		var center: Vector2 = observation.get("center", Vector2.ZERO)
		require(
			center.x <= battlefield_width * 0.52
				and float(observation.get("elapsed", 0.0)) >= 10.0,
			"%s demo formed B too close to the spawn ports or too early"
				% run_name
		)
		require(
			float(observation.get("initial_slot_error", 0.0))
				> PrototypeConfig.FORMATION_SLOT_TOLERANCE
				and float(observation.get("lock_to_complete_duration", 0.0))
					>= PrototypeConfig.FORMATION_B_DURATION,
			"%s demo B formation locked at its slots or completed too early"
				% run_name
		)
	var elapsed := float(snapshot.get("battle_elapsed", 0.0))
	require(
		elapsed >= 30.0 and elapsed <= 45.0,
		"%s demo duration %.1fs is outside the observable prototype window"
			% [run_name, elapsed]
	)


func assert_clean_ready_state(controller: Node) -> void:
	var snapshot: Dictionary = controller.get_battle_snapshot()
	var stats: Dictionary = snapshot.get("formation_stats", {})
	require(String(snapshot.get("state", "")) == "READY", "restart did not restore READY")
	require(
		int(snapshot.get("active_enemy_count", -1)) == 0
			and snapshot.get("formation_groups", []).is_empty()
			and int(stats.get("active_group_count", -1)) == 0
			and int(stats.get("member_assignment_count", -1)) == 0,
		"restart retained enemies, formation groups, or member mappings"
	)
	require(
		int(stats.get("completed_a_count", -1)) == 0
			and int(stats.get("completed_b_count", -1)) == 0
			and int(stats.get("interrupted_count", -1)) == 0
			and int(stats.get("downgrade_count", -1)) == 0
			and int(stats.get("candidate_lock_count", -1)) == 0
			and int(stats.get("meet_timeout_count", -1)) == 0
			and float(stats.get("runtime_elapsed", -1.0)) == 0.0,
		"restart retained formation statistics"
	)
	for character: Dictionary in snapshot.get("characters", []):
		require(
			int(character.get("current_health", -1))
				== int(character.get("max_health", -2))
				and character.get("blocked_enemy_ids", []).is_empty(),
			"restart retained character health or blocking state"
		)
	var formation_layer := controller.get_node(
		"Battlefield/BattlefieldDisplayRoot/BattlefieldContent/FormationLayer"
	)
	require(
		formation_layer.get_child_count() == 0,
		"restart left formation view children or ghost labels"
	)


func prepare_manual_run(
	controller: Node,
	deployment_mode: StringName = &""
) -> void:
	controller.restart_battle()
	await process_frame
	controller.clear_deployment()
	if deployment_mode == &"guard":
		require(
			controller.deploy_character(&"guard", &"middle_c4"),
			"manual formation test could not deploy guard"
		)
	require(
		controller.select_scenario(&"formation_demo"),
		"manual formation test could not select scenario"
	)
	require(controller.start_battle(), "manual formation test could not start")
	controller.clear_active_enemies()
	await process_frame


func spawn_test_enemies(
	controller: Node,
	monster_type: StringName,
	specs: Array
) -> Array:
	var enemies: Array = []
	for spec: Dictionary in specs:
		var route_id := StringName(spec.get("route_id", &"formation_center"))
		var route_data := PrototypeConfig.get_route_runtime_data(route_id)
		var overrides := {
			"spawn_point_id": StringName(spec.get("spawn_point_id", &"")),
			"route_group_id": StringName(spec.get(
				"route_group_id",
				route_data.get(
					"route_group_id",
					PrototypeConfig.ROUTE_GROUP_FORMATION
				)
			)),
			"blocking_lane_id": StringName(spec.get(
				"blocking_lane_id",
				route_data.get("blocking_lane_id", &"middle")
			)),
			"formation_route_index": int(spec.get(
				"formation_route_index",
				route_data.get("formation_route_index", 0)
			)),
			"move_speed": float(spec.get("move_speed", 0.0)),
			"max_health": int(spec.get("max_health", 5000)),
			"leak_damage": int(spec.get("leak_damage", 1)),
		}
		var enemy = controller.spawn_enemy_for_route(
			route_id,
			monster_type,
			overrides
		)
		require(
			enemy != null,
			"could not spawn %s formation test enemy" % String(monster_type)
		)
		if enemy == null:
			continue
		enemy.set_debug_world_position(
			spec.get("position", enemy.position)
		)
		enemies.append(enemy)
	return enemies


func route_for_blocking_lane(lane_id: StringName) -> StringName:
	match lane_id:
		&"top":
			return &"formation_upper"
		&"bottom":
			return &"formation_lower"
		_:
			return &"formation_center"


func get_route_point_in_zone(
	controller: Node,
	route_id: StringName,
	zone_type: StringName
) -> Vector2:
	var zone: Dictionary = controller.get_formation_zone(zone_type)
	var rect: Rect2 = zone.get("rect", Rect2())
	for point: Vector2 in controller.get_route_points(route_id):
		if rect.has_point(point):
			return point
	return rect.get_center()


func advance_manager(
	manager,
	active_enemies: Dictionary,
	duration: float,
	step := 0.1
) -> void:
	var remaining := maxf(0.0, duration)
	while remaining > 0.0001:
		var delta := minf(step, remaining)
		manager.update_formations(delta, active_enemies)
		remaining -= delta


func build_complete_a(
	controller: Node,
	monster_type: StringName,
	first_route_id: StringName,
	second_route_id: StringName
) -> Array:
	var center: Vector2 = controller.get_formation_zone_center(
		PrototypeConfig.FORMATION_ZONE_A
	)
	var members := spawn_test_enemies(
		controller,
		monster_type,
		[
			{
				"route_id": first_route_id,
				"position": center + Vector2(-28.0, -18.0),
			},
			{
				"route_id": second_route_id,
				"position": center + Vector2(28.0, 18.0),
			},
		]
	)
	var manager = controller.get_formation_manager()
	manager.update_formations(0.0, controller.active_enemies)
	advance_manager(
		manager,
		controller.active_enemies,
		PrototypeConfig.FORMATION_A_DURATION + 0.5
	)
	return members


func spawn_cluster(
	controller: Node,
	monster_type: StringName,
	lane_id: StringName,
	positions: Array
) -> Array:
	var route_id := route_for_blocking_lane(lane_id)
	var a_center: Vector2 = controller.get_formation_zone_center(
		PrototypeConfig.FORMATION_ZONE_A
	)
	var source_center := Vector2.ZERO
	for source_position: Vector2 in positions:
		source_center += source_position
	if not positions.is_empty():
		source_center /= float(positions.size())
	var specs: Array = []
	for source_position: Vector2 in positions:
		specs.append({
			"route_id": route_id,
			"blocking_lane_id": lane_id,
			"position": a_center + (source_position - source_center),
		})
	return spawn_test_enemies(controller, monster_type, specs)


func build_complete_b(
	controller: Node,
	monster_type: StringName,
	lane_id: StringName,
	origin: Vector2,
	finish_b: bool,
	spacing: float = 24.0
) -> Array:
	var a_center: Vector2 = controller.get_formation_zone_center(
		PrototypeConfig.FORMATION_ZONE_A
	)
	var route_a := route_for_blocking_lane(lane_id)
	var route_b := (
		&"formation_center"
		if route_a != &"formation_center" else &"formation_lower"
	)
	var pair_spacing := maxf(24.0, spacing)
	var enemies := spawn_test_enemies(
		controller,
		monster_type,
		[
			{
				"route_id": route_a,
				"blocking_lane_id": lane_id,
				"position": a_center + Vector2(-70.0, -pair_spacing),
			},
			{
				"route_id": route_a,
				"blocking_lane_id": lane_id,
				"position": a_center + Vector2(-40.0, -pair_spacing),
			},
			{
				"route_id": route_b,
				"blocking_lane_id": lane_id,
				"position": a_center + Vector2(40.0, pair_spacing),
			},
			{
				"route_id": route_b,
				"blocking_lane_id": lane_id,
				"position": a_center + Vector2(70.0, pair_spacing),
			},
		]
	)
	var manager = controller.get_formation_manager()
	manager.update_formations(0.0, controller.active_enemies)
	advance_manager(
		manager,
		controller.active_enemies,
		PrototypeConfig.FORMATION_A_DURATION + 0.5
	)
	var source_groups := get_groups_by_level(
		manager.get_groups_snapshot(),
		PrototypeConfig.FORMATION_LEVEL_A
	)
	require(source_groups.size() == 2, "B helper did not create two source A groups")
	var b_center: Vector2 = controller.get_formation_zone_center(
		PrototypeConfig.FORMATION_ZONE_B
	)
	for source_index in range(source_groups.size()):
		var source: Dictionary = source_groups[source_index]
		var source_center: Vector2 = b_center + Vector2(
			-62.0 if source_index == 0 else 62.0,
			0.0
		)
		var member_ids: Array = source.get("member_ids", [])
		for member_index in range(member_ids.size()):
			var enemy = controller.active_enemies.get(member_ids[member_index])
			if is_instance_valid(enemy):
				enemy.set_debug_world_position(
					source_center + Vector2(
						0.0,
						-19.0 if member_index == 0 else 19.0
					)
				)
	manager.update_formations(0.0, controller.active_enemies)
	if finish_b:
		advance_manager(
			manager,
			controller.active_enemies,
			PrototypeConfig.FORMATION_B_DURATION + 0.6
		)
		if origin != Vector2.ZERO:
			var completed_b = manager.find_complete_group(
				monster_type,
				PrototypeConfig.FORMATION_LEVEL_B
			)
			if completed_b != null:
				for member_id: StringName in completed_b.member_ids:
					var enemy = controller.active_enemies.get(member_id)
					if not is_instance_valid(enemy):
						continue
					var slot: Vector2 = completed_b.slot_assignments.get(
						member_id,
						Vector2.ZERO
					)
					enemy.set_debug_world_position(origin + slot)
				manager.update_formations(0.0, controller.active_enemies)
	return enemies


func get_groups_by_level(groups: Array, level: StringName) -> Array:
	var result: Array = []
	for group: Dictionary in groups:
		if (
			StringName(group.get("formation_level", &"")) == level
			and StringName(group.get("formation_state", &""))
				== PrototypeConfig.FORMATION_STATE_COMPLETE
		):
			result.append(group)
	return result


func get_groups_by_state(groups: Array, state: StringName) -> Array:
	var result: Array = []
	for group: Dictionary in groups:
		if StringName(group.get("formation_state", &"")) == state:
			result.append(group)
	return result


func unique_member_count(group: Dictionary) -> int:
	var unique: Dictionary = {}
	for member_id: StringName in group.get("member_ids", []):
		unique[member_id] = true
	return unique.size()


func run_until_finished(controller: Node) -> float:
	for step in range(MAX_SIMULATION_STEPS):
		if String(controller.get_battle_snapshot().get("state", "")) != "RUNNING":
			return float(step) * SIMULATION_STEP
		controller.simulate_step(SIMULATION_STEP)
	require(false, "formation demo did not reach a terminal state")
	return float(MAX_SIMULATION_STEPS) * SIMULATION_STEP


func build_demo_signature(snapshot: Dictionary) -> Dictionary:
	var stats: Dictionary = snapshot.get("formation_stats", {})
	var a_signature: Array = []
	for observation: Dictionary in stats.get("completed_a_observations", []):
		a_signature.append({
			"monster_type": observation.get("monster_type", &""),
			"pair_mode": observation.get("pair_mode", &""),
			"route_span": observation.get("route_span", -1),
			"anchor": observation.get("formation_anchor_route_index", -1),
			"initial_slot_error": snappedf(
				float(observation.get("initial_slot_error", 0.0)),
				0.01
			),
			"lock_runtime_elapsed": snappedf(
				float(observation.get("lock_runtime_elapsed", 0.0)),
				0.01
			),
			"completion_runtime_elapsed": snappedf(
				float(observation.get("completion_runtime_elapsed", 0.0)),
				0.01
			),
		})
	var b_signature: Array = []
	for observation: Dictionary in stats.get("completed_b_observations", []):
		b_signature.append({
			"monster_type": observation.get("monster_type", &""),
			"anchor": observation.get("formation_anchor_route_index", -1),
			"source_anchor_route_indices":
				observation.get("source_anchor_route_indices", []).duplicate(),
			"initial_slot_error": snappedf(
				float(observation.get("initial_slot_error", 0.0)),
				0.01
			),
			"elapsed": snappedf(
				float(observation.get("elapsed", 0.0)),
				0.01
			),
		})
	return {
		"state": snapshot.get("state", ""),
		"durability": snapshot.get("village_durability", 0),
		"killed": snapshot.get("killed_enemy_count", 0),
		"leaked": snapshot.get("leaked_enemy_count", 0),
		"generated_by_route":
			snapshot.get("generated_by_route", {}).duplicate(true),
		"completed_a_by_type":
			stats.get("completed_a_by_type", {}).duplicate(true),
		"completed_b_by_type":
			stats.get("completed_b_by_type", {}).duplicate(true),
		"route_spans": stats.get("completed_a_route_spans", {}).duplicate(true),
		"pair_modes": stats.get("completed_a_pair_modes", {}).duplicate(true),
		"a_observations": a_signature,
		"b_observations": b_signature,
	}


func record_demo_result(
	run_name: String,
	snapshot: Dictionary,
	duration: float
) -> void:
	var stats: Dictionary = snapshot.get("formation_stats", {})
	demo_results.append({
		"name": run_name,
		"state": snapshot.get("state", ""),
		"durability": snapshot.get("village_durability", 0),
		"killed": snapshot.get("killed_enemy_count", 0),
		"leaked": snapshot.get("leaked_enemy_count", 0),
		"a_completed": stats.get("completed_a_count", 0),
		"b_completed": stats.get("completed_b_count", 0),
		"interrupted": stats.get("interrupted_count", 0),
		"downgraded": stats.get("downgrade_count", 0),
		"duration": duration,
		"pair_modes": stats.get("completed_a_pair_modes", {}).duplicate(true),
		"route_spans": stats.get("completed_a_route_spans", {}).duplicate(true),
		"a_observations": stats.get(
			"completed_a_observations",
			[]
		).duplicate(true),
		"cross_route_a": stats.get("cross_route_a_count", 0),
		"b_observations": stats.get(
			"completed_b_observations",
			[]
		).duplicate(true),
	})


func on_battle_finished(outcome: StringName) -> void:
	finished_outcomes.append(outcome)


func assert_project_settings_are_unchanged() -> void:
	require(
		String(ProjectSettings.get_setting("application/run/main_scene", ""))
			== FORMAL_MAIN_SCENE_PATH,
		"formal default main scene changed"
	)
	require(
		String(ProjectSettings.get_setting("autoload/GameState", ""))
			== "*res://autoload/game_state.gd",
		"formal GameState autoload changed"
	)
	for property: Dictionary in ProjectSettings.get_property_list():
		var property_name := String(property.get("name", ""))
		if not property_name.begins_with("autoload/"):
			continue
		var autoload_path := String(ProjectSettings.get_setting(property_name, ""))
		require(
			not autoload_path.contains(PROTOTYPE_ROOT),
			"prototype registered a global autoload"
		)


func assert_runtime_files_are_isolated() -> void:
	for runtime_path: String in RUNTIME_PATHS:
		require(FileAccess.file_exists(runtime_path), "%s is missing" % runtime_path)
		var source := FileAccess.get_file_as_string(runtime_path)
		for token: String in FORBIDDEN_RUNTIME_TOKENS:
			require(
				not source.contains(token),
				"%s references forbidden formal runtime token %s"
					% [runtime_path, token]
			)
	var dependencies := ResourceLoader.get_dependencies(PROTOTYPE_SCENE_PATH)
	for dependency: String in dependencies:
		var dependency_path := dependency.get_slice(
			"::", dependency.get_slice_count("::") - 1
		)
		require(
			dependency_path.begins_with(PROTOTYPE_ROOT),
			"V2-3 scene has an external dependency: %s" % dependency_path
		)


func snapshot_script_variables(target: Object) -> Dictionary:
	var snapshot: Dictionary = {}
	for property: Dictionary in target.get_property_list():
		var usage := int(property.get("usage", 0))
		if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var property_name := StringName(property.get("name", &""))
		snapshot[property_name] = normalize_for_snapshot(target.get(property_name))
	return snapshot


func normalize_for_snapshot(value: Variant) -> Variant:
	match typeof(value):
		TYPE_ARRAY:
			var normalized_array: Array = []
			for item: Variant in value:
				normalized_array.append(normalize_for_snapshot(item))
			return normalized_array
		TYPE_DICTIONARY:
			var normalized_dictionary: Dictionary = {}
			for key: Variant in value.keys():
				normalized_dictionary[key] = normalize_for_snapshot(value[key])
			return normalized_dictionary
		TYPE_OBJECT:
			if value == null:
				return null
			if value.has_method("to_dictionary"):
				return normalize_for_snapshot(value.to_dictionary())
			return {
				"class": value.get_class(),
				"instance_id": value.get_instance_id(),
			}
		_:
			return value


func snapshot_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"exists": false}
	var content := FileAccess.get_file_as_bytes(path)
	return {
		"exists": true,
		"length": content.size(),
		"hash": hash(content),
		"modified_time": FileAccess.get_modified_time(path),
	}


func require(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)

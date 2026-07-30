extends SceneTree

const PROTOTYPE_ROOT := "res://prototype/formation_defense/"
const PROTOTYPE_SCENE_PATH := (
	PROTOTYPE_ROOT + "scenes/formation_defense_prototype.tscn"
)
const DEFAULT_SAVE_PATH := "user://adventure_village_save.json"
const FORMAL_MAIN_SCENE_PATH := "res://features/main/main.tscn"
const SIMULATION_STEP := 0.1
const MAX_SIMULATION_STEPS := 600

const RUNTIME_PATHS: Array[String] = [
	PROTOTYPE_SCENE_PATH,
	PROTOTYPE_ROOT + "scripts/formation_defense_prototype.gd",
	PROTOTYPE_ROOT + "scripts/formation_defense_character.gd",
	PROTOTYPE_ROOT + "scripts/formation_defense_deployment_slot.gd",
	PROTOTYPE_ROOT + "scripts/formation_defense_enemy.gd",
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

	var packed_scene := load(PROTOTYPE_SCENE_PATH) as PackedScene
	require(packed_scene != null, "V2-1 entry scene could not be loaded")
	if packed_scene == null:
		quit(1)
		return
	var controller = packed_scene.instantiate()
	require(controller != null, "V2-1 entry scene could not be instantiated")
	if controller == null:
		quit(1)
		return
	root.add_child(controller)
	await process_frame
	await process_frame
	controller.set_automatic_simulation(false)

	assert_required_nodes(controller)
	assert_three_routes(controller)
	assert_enemy_actual_movement(controller)
	controller.restart_battle()
	await process_frame

	controller.battle_finished.connect(on_battle_finished)
	assert_survival_victory(controller)
	controller.restart_battle()
	await process_frame
	assert_ready_reset(controller, 1)

	assert_defeat_loop(controller)
	controller.restart_battle()
	await process_frame
	assert_ready_reset(controller, 2)

	assert_third_run_after_restart(controller)
	require(
		finished_outcomes == [&"victory", &"defeat", &"victory"],
		"continuous runs emitted missing or duplicate battle-finished signals"
	)
	require(
		int(controller.get_battle_snapshot().get("battle_finish_count", -1)) == 3,
		"battle finish handling was not exactly once per completed run"
	)

	controller.restart_battle()
	await process_frame
	assert_ready_reset(controller, 3)
	require(
		snapshot_script_variables(game_state) == game_state_before,
		"V2-1 prototype changed GameState"
	)
	require(
		snapshot_file(DEFAULT_SAVE_PATH) == save_file_before,
		"V2-1 prototype changed the formal save file"
	)

	controller.queue_free()
	await process_frame
	require(
		snapshot_script_variables(game_state) == game_state_before,
		"V2-1 prototype cleanup changed GameState"
	)
	require(
		snapshot_file(DEFAULT_SAVE_PATH) == save_file_before,
		"V2-1 prototype cleanup changed the formal save file"
	)

	if failures.is_empty():
		print("v2-1 formation defense basic loop smoke ok")
		quit(0)
		return
	quit(1)


func assert_required_nodes(controller: Node) -> void:
	for node_path: String in [
		"RootMargin/Content/Battlefield",
		"RootMargin/Content/Battlefield/BattlefieldContent/RouteView",
		"RootMargin/Content/Battlefield/BattlefieldContent/EnemyLayer",
		"RootMargin/Content/Battlefield/BattlefieldContent/SpawnPortTop",
		"RootMargin/Content/Battlefield/BattlefieldContent/SpawnPortMiddle",
		"RootMargin/Content/Battlefield/BattlefieldContent/SpawnPortBottom",
		"RootMargin/Content/Battlefield/BattlefieldContent/VillageEntrance",
		"RootMargin/Content/ControlPanel/ControlRow/ScenarioOption",
		"RootMargin/Content/ControlPanel/ControlRow/StartButton",
		"RootMargin/Content/ControlPanel/ControlRow/RestartButton",
		"RootMargin/Content/Notice/ResultLabel",
	]:
		require(
			controller.get_node_or_null(node_path) != null,
			"required V2-1 node is missing: %s" % node_path
		)
	var battlefield := controller.get_node(
		"RootMargin/Content/Battlefield"
	) as Control
	var top_port := controller.get_node(
		"RootMargin/Content/Battlefield/BattlefieldContent/SpawnPortTop"
	) as Control
	var middle_port := controller.get_node(
		"RootMargin/Content/Battlefield/BattlefieldContent/SpawnPortMiddle"
	) as Control
	var bottom_port := controller.get_node(
		"RootMargin/Content/Battlefield/BattlefieldContent/SpawnPortBottom"
	) as Control
	var village := controller.get_node(
		"RootMargin/Content/Battlefield/BattlefieldContent/VillageEntrance"
	) as Control
	require(
		battlefield.size.x > 1000.0 and battlefield.size.y > 400.0,
		"battlefield did not receive a usable layout size"
	)
	require(
		top_port.global_position.x > village.global_position.x
			and middle_port.global_position.x > village.global_position.x
			and bottom_port.global_position.x > village.global_position.x,
		"spawn ports are not on the right side of the village"
	)
	require(
		top_port.global_position.y < middle_port.global_position.y
			and middle_port.global_position.y < bottom_port.global_position.y,
		"top, middle, and bottom spawn ports are not vertically ordered"
	)


func assert_three_routes(controller: Node) -> void:
	var route_ids: Array[StringName] = controller.get_route_ids()
	require(route_ids.size() == 3, "V2-1 must expose exactly three routes")
	var unique_route_ids: Dictionary = {}
	var shared_entrance: Vector2 = controller.get_village_entrance_point()
	for route_id: StringName in route_ids:
		require(not unique_route_ids.has(route_id), "route IDs are not unique")
		unique_route_ids[route_id] = true
		var points: PackedVector2Array = controller.get_route_points(route_id)
		require(points.size() >= 2, "%s route has too few points" % String(route_id))
		if not points.is_empty():
			require(
				points[0].x > points[points.size() - 1].x,
				"%s route does not travel from right to left" % String(route_id)
			)
			require(
				points[points.size() - 1].is_equal_approx(shared_entrance),
				"%s route does not end at the shared village entrance"
					% String(route_id)
			)
	require(
		unique_route_ids.has(&"top")
			and unique_route_ids.has(&"middle")
			and unique_route_ids.has(&"bottom"),
		"top, middle, and bottom route IDs are required"
	)


func assert_enemy_actual_movement(controller: Node) -> void:
	require(controller.select_scenario(&"survival"), "movement test scenario selection failed")
	require(controller.start_battle(), "movement test could not start")
	require(
		not controller.start_battle(),
		"running battle accepted a duplicate start request"
	)
	var active_enemies: Array = controller.get_active_enemy_nodes()
	require(active_enemies.size() == 1, "first enemy did not spawn immediately")
	if active_enemies.is_empty():
		return
	var enemy = active_enemies[0]
	var start_position: Vector2 = enemy.position
	var start_progress := float(enemy.route_progress)
	controller.simulate_step(0.5)
	require(
		enemy.position.distance_to(start_position) > 1.0,
		"enemy did not produce actual movement"
	)
	require(
		float(enemy.route_progress) > start_progress,
		"enemy route progress did not increase"
	)
	require(
		StringName(enemy.route_id) == &"top",
		"deterministic movement test did not start on the top route"
	)


func assert_survival_victory(controller: Node) -> void:
	require(controller.select_scenario(&"survival"), "survival scenario selection failed")
	require(controller.start_battle(), "survival scenario could not start")
	var first_enemies: Array = controller.get_active_enemy_nodes()
	require(not first_enemies.is_empty(), "survival scenario spawned no first enemy")
	var first_enemy_id := (
		StringName(first_enemies[0].runtime_id) if not first_enemies.is_empty() else &""
	)
	run_until_resolved_count(controller, 1)
	var after_first_leak: Dictionary = controller.get_battle_snapshot()
	require(
		int(after_first_leak.get("village_durability", -1)) == 9,
		"first leak did not deal exactly one damage"
	)
	controller.handle_enemy_arrival(first_enemy_id, &"top", 1)
	var after_duplicate: Dictionary = controller.get_battle_snapshot()
	require(
		int(after_duplicate.get("village_durability", -1)) == 9,
		"one enemy deducted village durability more than once"
	)
	require(
		int(after_duplicate.get("resolved_enemy_count", -1)) == 1,
		"duplicate arrival incremented resolved enemy count"
	)
	run_until_finished(controller)
	var snapshot: Dictionary = controller.get_battle_snapshot()
	require(String(snapshot.get("state", "")) == "VICTORY", "survival did not win")
	require(
		int(snapshot.get("village_durability", -1)) == 4,
		"survival should leave exactly four durability"
	)
	require(
		int(snapshot.get("generated_enemy_count", -1)) == 6,
		"survival did not generate exactly six enemies"
	)
	require(
		int(snapshot.get("active_enemy_count", -1)) == 0,
		"survival victory retained active enemies"
	)
	require(
		int(snapshot.get("resolved_enemy_count", -1)) == 6,
		"survival did not resolve all six enemies"
	)
	assert_route_counts(snapshot, 2)
	var settled_snapshot: Dictionary = snapshot.duplicate(true)
	controller.simulate_step(20.0)
	require(
		controller.get_battle_snapshot() == settled_snapshot,
		"victory state changed after settlement"
	)


func assert_defeat_loop(controller: Node) -> void:
	require(controller.select_scenario(&"defeat"), "defeat scenario selection failed")
	require(controller.start_battle(), "defeat scenario could not start")
	require(
		not controller.start_battle(),
		"defeat run accepted a duplicate start request"
	)
	run_until_finished(controller)
	var snapshot: Dictionary = controller.get_battle_snapshot()
	require(String(snapshot.get("state", "")) == "DEFEAT", "defeat scenario did not fail")
	require(
		int(snapshot.get("village_durability", -1)) == 0,
		"defeat durability was not clamped to zero"
	)
	require(
		int(snapshot.get("generated_enemy_count", -1)) == 12,
		"defeat scenario did not deterministically generate twelve enemies"
	)
	require(
		int(snapshot.get("active_enemy_count", -1)) == 0,
		"defeat did not clear remaining active enemies"
	)
	require(
		int(snapshot.get("resolved_enemy_count", -1)) == 10,
		"defeat should stop leak settlement when durability reaches zero"
	)
	assert_route_counts(snapshot, 4)
	var failed_snapshot: Dictionary = snapshot.duplicate(true)
	controller.simulate_step(100.0)
	require(
		controller.get_battle_snapshot() == failed_snapshot,
		"defeat continued spawning, leaking, or changed to victory"
	)


func assert_third_run_after_restart(controller: Node) -> void:
	require(controller.select_scenario(&"survival"), "third-run scenario selection failed")
	require(controller.start_battle(), "third run could not start")
	run_until_finished(controller)
	var snapshot: Dictionary = controller.get_battle_snapshot()
	require(
		String(snapshot.get("state", "")) == "VICTORY",
		"third run after repeated restart did not finish normally"
	)
	require(
		int(snapshot.get("village_durability", -1)) == 4,
		"third run inherited stale durability"
	)


func assert_ready_reset(controller: Node, expected_finish_count: int) -> void:
	var snapshot: Dictionary = controller.get_battle_snapshot()
	require(String(snapshot.get("state", "")) == "READY", "restart did not restore READY")
	require(
		int(snapshot.get("village_durability", -1)) == 10,
		"restart did not restore village durability"
	)
	require(
		int(snapshot.get("generated_enemy_count", -1)) == 0,
		"restart did not reset generated count"
	)
	require(
		int(snapshot.get("resolved_enemy_count", -1)) == 0,
		"restart did not reset resolved count"
	)
	require(
		int(snapshot.get("active_enemy_count", -1)) == 0,
		"restart retained active enemies"
	)
	require(int(snapshot.get("spawn_index", -1)) == 0, "restart did not reset spawn index")
	require(
		is_zero_approx(float(snapshot.get("spawn_elapsed", -1.0))),
		"restart did not reset spawn timing"
	)
	require(
		int(snapshot.get("battle_finish_count", -1)) == expected_finish_count,
		"restart duplicated or erased completed-run accounting"
	)
	var enemy_layer := controller.get_node(
		"RootMargin/Content/Battlefield/BattlefieldContent/EnemyLayer"
	)
	require(
		enemy_layer.get_child_count() == 0,
		"restart left enemy nodes in the scene tree"
	)
	var result_label := controller.get_node(
		"RootMargin/Content/Notice/ResultLabel"
	) as Label
	require(
		result_label != null and result_label.text.contains("准备就绪"),
		"restart did not clear the victory or defeat prompt"
	)


func assert_route_counts(snapshot: Dictionary, expected_per_route: int) -> void:
	var counts: Dictionary = snapshot.get("generated_by_route", {})
	for route_id: StringName in [&"top", &"middle", &"bottom"]:
		require(
			int(counts.get(route_id, -1)) == expected_per_route,
			"%s route generated an unexpected enemy count" % String(route_id)
		)


func run_until_resolved_count(controller: Node, target_count: int) -> void:
	for _step in range(MAX_SIMULATION_STEPS):
		if int(controller.get_battle_snapshot().get("resolved_enemy_count", 0)) >= target_count:
			return
		controller.simulate_step(SIMULATION_STEP)
	require(false, "simulation did not reach the expected resolved count")


func run_until_finished(controller: Node) -> void:
	for _step in range(MAX_SIMULATION_STEPS):
		if String(controller.get_battle_snapshot().get("state", "")) != "RUNNING":
			return
		controller.simulate_step(SIMULATION_STEP)
	require(false, "simulation did not reach a terminal state")


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
		var dependency_path := dependency.get_slice("::", dependency.get_slice_count("::") - 1)
		require(
			dependency_path.begins_with(PROTOTYPE_ROOT),
			"V2-1 scene has an external dependency: %s" % dependency_path
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

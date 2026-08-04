extends SceneTree

const PROTOTYPE_ROOT := "res://prototype/formation_defense/"
const PROTOTYPE_SCENE_PATH := (
	PROTOTYPE_ROOT + "scenes/formation_defense_prototype.tscn"
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
	PROTOTYPE_ROOT + "scripts/formation_defense_wave_director.gd",
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
const CHARACTER_IDS: Array[StringName] = [
	&"guard", &"hunter", &"mage", &"doctor",
]
const ROUTE_IDS: Array[StringName] = [&"top", &"middle", &"bottom"]

var failures: Array[String] = []
var finished_outcomes: Array[StringName] = []
var auto_run_results: Array[Dictionary] = []


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
	require(packed_scene != null, "V2-2 entry scene could not be loaded")
	if packed_scene == null:
		quit(1)
		return
	var controller = packed_scene.instantiate()
	require(controller != null, "V2-2 entry scene could not be instantiated")
	if controller == null:
		quit(1)
		return
	root.add_child(controller)
	await process_frame
	await process_frame
	controller.set_automatic_simulation(false)
	controller.battle_finished.connect(on_battle_finished)

	assert_required_nodes(controller)
	assert_deployment_data(controller)
	assert_character_roster(controller)
	assert_ready_deployment_rules(controller)

	controller.restart_battle()
	await process_frame
	controller.clear_deployment()
	assert_non_guard_does_not_block(controller)

	controller.restart_battle()
	await process_frame
	controller.clear_deployment()
	assert_guard_blocking_and_release(controller)

	controller.restart_battle()
	await process_frame
	controller.clear_deployment()
	assert_target_selection_and_healing(controller)

	controller.restart_battle()
	await process_frame
	controller.clear_deployment()
	assert_enemy_settlement_is_idempotent(controller)

	controller.restart_battle()
	await process_frame
	finished_outcomes.clear()
	assert_continuous_auto_battle_runs(controller)

	controller.restart_battle()
	await process_frame
	assert_clean_ready_state(controller)

	require(
		snapshot_script_variables(game_state) == game_state_before,
		"V2-2 prototype changed GameState"
	)
	require(
		snapshot_file(DEFAULT_SAVE_PATH) == save_file_before,
		"V2-2 prototype changed the formal save file"
	)

	controller.queue_free()
	await process_frame
	require(
		snapshot_script_variables(game_state) == game_state_before,
		"V2-2 prototype cleanup changed GameState"
	)
	require(
		snapshot_file(DEFAULT_SAVE_PATH) == save_file_before,
		"V2-2 prototype cleanup changed the formal save file"
	)

	if failures.is_empty():
		for result: Dictionary in auto_run_results:
			print(
				"v2-2 %s: state=%s durability=%d killed=%d leaked=%d duration=%.1fs"
				% [
					String(result.get("name", "")),
					String(result.get("state", "")),
					int(result.get("durability", 0)),
					int(result.get("killed", 0)),
					int(result.get("leaked", 0)),
					float(result.get("duration", 0.0)),
				]
			)
		print("v2-2 formation defense auto combat smoke ok")
		quit(0)
		return
	quit(1)


func assert_required_nodes(controller: Node) -> void:
	for node_path: String in [
		"Battlefield/BattlefieldDisplayRoot/BattlefieldContent/DeploymentLayer",
		"Battlefield/BattlefieldDisplayRoot/BattlefieldContent/CharacterLayer",
		"Battlefield/BattlefieldDisplayRoot/BattlefieldContent/EnemyLayer",
		"DebugDrawer/DrawerMargin/DrawerRows/DebugScroll/DebugContent/DeploymentPanel/DeploymentContent/CharacterCardRow",
		"DebugDrawer/DrawerMargin/DrawerRows/DebugScroll/DebugContent/DeploymentPanel/DeploymentContent/DeploymentHeader/RecommendButton",
		"DebugDrawer/DrawerMargin/DrawerRows/DebugScroll/DebugContent/DeploymentPanel/DeploymentContent/DeploymentHeader/ClearDeploymentButton",
		"DebugDrawer/DrawerMargin/DrawerRows/DebugScroll/DebugContent/DeploymentPanel/DeploymentContent/DeploymentHeader/UndeployButton",
		"DebugDrawer/DrawerMargin/DrawerRows/DebugScroll/DebugContent/StatusPanel/StatusRow/KilledLabel",
		"DebugDrawer/DrawerMargin/DrawerRows/DebugScroll/DebugContent/StatusPanel/StatusRow/LeakedLabel",
		"DebugDrawer/DrawerMargin/DrawerRows/DebugScroll/DebugContent/StatusPanel/StatusRow/ResolvedLabel",
	]:
		require(
			controller.get_node_or_null(node_path) != null,
			"required V2-2 node is missing: %s" % node_path
		)


func assert_deployment_data(controller: Node) -> void:
	var slots: Array = controller.get_deployment_slots_snapshot()
	require(slots.size() == 12, "V2-2 must expose exactly twelve deployment slots")
	var unique_ids: Dictionary = {}
	var lane_counts := {&"top": 0, &"middle": 0, &"bottom": 0}
	var lane_columns := {&"top": {}, &"middle": {}, &"bottom": {}}
	for slot: Dictionary in slots:
		var slot_id := StringName(slot.get("slot_id", &""))
		var lane_id := StringName(slot.get("lane_id", &""))
		var column_id := int(slot.get("column_id", 0))
		var normalized_position: Vector2 = slot.get(
			"normalized_position", Vector2(-1.0, -1.0)
		)
		require(slot_id != &"", "deployment slot has no slot_id")
		require(not unique_ids.has(slot_id), "deployment slot IDs are not unique")
		unique_ids[slot_id] = true
		require(lane_counts.has(lane_id), "deployment slot has an invalid lane_id")
		if lane_counts.has(lane_id):
			lane_counts[lane_id] = int(lane_counts[lane_id]) + 1
			require(
				not lane_columns[lane_id].has(column_id),
				"deployment column IDs repeat within one lane"
			)
			lane_columns[lane_id][column_id] = true
		require(
			normalized_position.x > 0.0
				and normalized_position.x < 1.0
				and normalized_position.y > 0.0
				and normalized_position.y < 1.0,
			"deployment slot does not use a normalized battlefield position"
		)
		require(
			StringName(slot.get("deployed_character_id", &"")) == &"",
			"new prototype instance has an occupied deployment slot"
		)
	for lane_id: StringName in ROUTE_IDS:
		require(
			int(lane_counts.get(lane_id, 0)) == 4,
			"%s lane does not have exactly four deployment slots"
				% String(lane_id)
		)


func assert_character_roster(controller: Node) -> void:
	var snapshots: Array = controller.get_character_snapshots()
	require(snapshots.size() == 4, "V2-2 must expose exactly four characters")
	var unique_ids: Dictionary = {}
	for character: Dictionary in snapshots:
		var character_id := StringName(character.get("character_id", &""))
		require(character_id != &"", "prototype character has no character_id")
		require(not unique_ids.has(character_id), "character IDs are not unique")
		unique_ids[character_id] = true
		require(
			int(character.get("max_health", 0)) > 0,
			"%s has no maximum health" % String(character_id)
		)
		require(
			float(character.get("action_interval", 0.0)) > 0.0,
			"%s has no action interval" % String(character_id)
		)
		require(
			float(character.get("action_range", 0.0)) > 0.0,
			"%s has no action range" % String(character_id)
		)
	for character_id: StringName in CHARACTER_IDS:
		require(
			unique_ids.has(character_id),
			"fixed prototype character is missing: %s" % String(character_id)
		)
	var guard = controller.get_character_node(&"guard")
	var doctor = controller.get_character_node(&"doctor")
	require(
		guard != null and int(guard.block_capacity) == 2,
		"guard block capacity must be two"
	)
	require(
		doctor != null
			and int(doctor.attack_damage) == 0
			and int(doctor.heal_amount) > 0,
		"doctor must heal instead of attacking"
	)


func assert_ready_deployment_rules(controller: Node) -> void:
	require(
		controller.deploy_character(&"guard", &"top_c1"),
		"READY state could not deploy guard"
	)
	require(
		controller.deploy_character(&"guard", &"top_c2"),
		"READY state could not move an already deployed guard"
	)
	var guard = controller.get_character_node(&"guard")
	require(
		StringName(guard.deployed_slot_id) == &"top_c2",
		"guard did not move to the second slot"
	)
	require(
		StringName(
			controller.get_deployment_slot_node(&"top_c1").deployed_character_id
		) == &"",
		"moving guard left a duplicate deployment behind"
	)
	require(
		not controller.deploy_character(&"hunter", &"top_c2"),
		"occupied slot accepted a second character"
	)
	require(
		controller.undeploy_character(&"guard"),
		"READY state could not undeploy guard"
	)
	require(not guard.is_deployed(), "undeployed guard remained active")
	require(
		controller.apply_recommended_deployment(),
		"recommended deployment could not be applied"
	)
	var deployment: Dictionary = controller.get_battle_snapshot().get("deployment", {})
	require(deployment.size() == 4, "recommended deployment did not place four characters")
	require(
		controller.select_scenario(&"auto_battle"),
		"auto-battle scenario selection failed"
	)
	require(controller.start_battle(), "deployment lock test could not start")
	require(
		not controller.deploy_character(&"guard", &"top_c1")
			and not controller.undeploy_character(&"guard")
			and not controller.clear_deployment()
			and not controller.apply_recommended_deployment(),
		"RUNNING state allowed deployment changes"
	)


func assert_non_guard_does_not_block(controller: Node) -> void:
	require(
		controller.deploy_character(&"hunter", &"middle_c4"),
		"non-guard blocking test could not deploy hunter"
	)
	require(controller.select_scenario(&"survival"), "scenario selection failed")
	require(controller.start_battle(), "non-guard blocking test could not start")
	var hunter = controller.get_character_node(&"hunter")
	var enemy = controller.spawn_enemy_for_route(&"middle")
	require(enemy != null, "non-guard blocking test could not spawn enemy")
	if enemy == null:
		return
	enemy.position = hunter.position
	controller.update_enemy_blocking()
	require(
		StringName(enemy.blocked_by_character_id) == &"",
		"non-guard character blocked an enemy"
	)


func assert_guard_blocking_and_release(controller: Node) -> void:
	require(
		controller.deploy_character(&"guard", &"middle_c4"),
		"guard blocking test could not deploy guard"
	)
	require(controller.select_scenario(&"survival"), "scenario selection failed")
	require(controller.start_battle(), "guard blocking test could not start")
	var guard = controller.get_character_node(&"guard")
	var initial_enemy: Array = controller.get_active_enemy_nodes()
	require(not initial_enemy.is_empty(), "guard test has no initial route enemy")
	if not initial_enemy.is_empty():
		initial_enemy[0].position = guard.position
	var middle_enemies: Array = []
	for _index in range(3):
		var enemy = controller.spawn_enemy_for_route(&"middle")
		require(enemy != null, "guard blocking test could not spawn middle enemy")
		if enemy != null:
			enemy.position = guard.position
			middle_enemies.append(enemy)
	controller.update_enemy_blocking()
	if not initial_enemy.is_empty():
		require(
			StringName(initial_enemy[0].blocked_by_character_id) == &"",
			"guard blocked an enemy from another lane"
		)
	require(
		guard.blocked_enemy_ids.size() == 2,
		"guard did not stop at its two-enemy block capacity"
	)
	if middle_enemies.size() < 3:
		return
	require(
		StringName(middle_enemies[0].blocked_by_character_id) == &"guard"
			and StringName(middle_enemies[1].blocked_by_character_id) == &"guard",
		"first two same-lane enemies were not blocked"
	)
	require(
		StringName(middle_enemies[2].blocked_by_character_id) == &"",
		"enemy beyond guard capacity was blocked"
	)
	var blocked_position: Vector2 = middle_enemies[0].position
	var overflow_position: Vector2 = middle_enemies[2].position
	var guard_health_before := int(guard.current_health)
	controller.simulate_step(1.1)
	require(
		middle_enemies[0].position.is_equal_approx(blocked_position),
		"blocked enemy continued moving"
	)
	require(
		middle_enemies[2].position.distance_to(overflow_position) > 1.0,
		"enemy beyond block capacity did not continue moving"
	)
	require(
		int(guard.current_health) < guard_health_before
			and int(controller.enemy_attack_event_count) > 0,
		"blocked enemy did not attack guard"
	)
	var released_positions: Array[Vector2] = [
		middle_enemies[0].position,
		middle_enemies[1].position,
	]
	guard.take_damage(9999)
	require(
		not guard.is_alive and int(guard.current_health) == 0,
		"guard death did not clamp health or mark the character dead"
	)
	require(
		guard.blocked_enemy_ids.is_empty()
			and StringName(middle_enemies[0].blocked_by_character_id) == &""
			and StringName(middle_enemies[1].blocked_by_character_id) == &"",
		"guard death did not release all blocking relationships"
	)
	controller.simulate_step(0.5)
	require(
		middle_enemies[0].position.distance_to(released_positions[0]) > 1.0
			and middle_enemies[1].position.distance_to(released_positions[1]) > 1.0,
		"released enemies did not resume route movement"
	)


func assert_target_selection_and_healing(controller: Node) -> void:
	require(
		controller.apply_recommended_deployment(),
		"target-selection test could not apply recommended deployment"
	)
	require(controller.select_scenario(&"survival"), "scenario selection failed")
	require(controller.start_battle(), "target-selection test could not start")
	var hunter = controller.get_character_node(&"hunter")
	var mage = controller.get_character_node(&"mage")
	var doctor = controller.get_character_node(&"doctor")
	var guard = controller.get_character_node(&"guard")
	var candidate_a = controller.spawn_enemy_for_route(&"top")
	var candidate_b = controller.spawn_enemy_for_route(&"bottom")
	var out_of_range = controller.spawn_enemy_for_route(&"middle")
	require(
		candidate_a != null and candidate_b != null and out_of_range != null,
		"target-selection test could not spawn candidates"
	)
	if candidate_a == null or candidate_b == null or out_of_range == null:
		return
	var shared_position: Vector2 = hunter.position.lerp(mage.position, 0.5)
	candidate_a.position = shared_position
	candidate_b.position = shared_position
	candidate_a.route_progress = 0.55
	candidate_b.route_progress = 0.55
	candidate_a.spawn_sequence = 20
	candidate_b.spawn_sequence = 10
	out_of_range.position = Vector2(-10000.0, -10000.0)
	out_of_range.route_progress = 0.99
	require(
		hunter.choose_enemy_target([candidate_a, out_of_range, candidate_b])
			== candidate_b,
		"hunter target selection was not legal and deterministic"
	)
	require(
		mage.choose_enemy_target([candidate_a, candidate_b, out_of_range])
			== candidate_b,
		"mage target selection was not legal and deterministic"
	)
	require(
		hunter.choose_enemy_target([candidate_b, candidate_a]) == candidate_b,
		"hunter target changed when candidate iteration order changed"
	)
	require(
		doctor.choose_heal_target(controller.character_nodes.values()) == null,
		"doctor selected a target when no deployed ally was injured"
	)
	guard.take_damage(40)
	hunter.take_damage(24)
	require(
		doctor.choose_heal_target(controller.character_nodes.values()) == guard,
		"doctor did not use health ratio and fixed ID tie-breaking"
	)
	guard.take_damage(9999)
	require(
		doctor.choose_heal_target(controller.character_nodes.values()) == hunter,
		"doctor selected a dead ally or ignored a living injured ally"
	)
	var hunter_health_before := int(hunter.current_health)
	var action: Dictionary = doctor.simulate_action(
		1.0, controller.get_active_enemy_nodes(), controller.character_nodes.values()
	)
	require(
		StringName(action.get("type", &"")) == &"heal"
			and int(hunter.current_health) > hunter_health_before,
		"doctor did not perform effective healing on an injured living ally"
	)


func assert_enemy_settlement_is_idempotent(controller: Node) -> void:
	require(controller.select_scenario(&"survival"), "scenario selection failed")
	require(controller.start_battle(), "settlement test could not start")
	var first_enemies: Array = controller.get_active_enemy_nodes()
	require(not first_enemies.is_empty(), "settlement test spawned no first enemy")
	if first_enemies.is_empty():
		return
	var dead_enemy = first_enemies[0]
	var dead_enemy_id := StringName(dead_enemy.runtime_id)
	var durability_before := int(controller.village_durability)
	require(
		int(dead_enemy.take_damage(9999)) > 0,
		"enemy did not take lethal damage"
	)
	require(
		int(dead_enemy.current_health) == 0
			and dead_enemy.is_dead
			and dead_enemy.death_settlement_completed,
		"enemy death state was incomplete or health went below zero"
	)
	dead_enemy.take_damage(9999)
	controller.handle_enemy_arrival(dead_enemy_id, &"top", 1)
	require(
		int(controller.killed_enemy_count) == 1
			and int(controller.leaked_enemy_count) == 0
			and int(controller.resolved_enemy_count) == 1,
		"enemy death was counted more than once or also counted as a leak"
	)
	require(
		int(controller.village_durability) == durability_before,
		"dead enemy later damaged the village"
	)
	var leaked_enemy = controller.spawn_enemy_for_route(&"middle")
	require(leaked_enemy != null, "settlement test could not spawn leak enemy")
	if leaked_enemy == null:
		return
	var leaked_enemy_id := StringName(leaked_enemy.runtime_id)
	controller.handle_enemy_arrival(leaked_enemy_id, &"middle", 1)
	leaked_enemy.take_damage(9999)
	controller.handle_enemy_death(leaked_enemy_id)
	require(
		int(controller.killed_enemy_count) == 1
			and int(controller.leaked_enemy_count) == 1
			and int(controller.resolved_enemy_count) == 2,
		"leaked enemy was later killed or settlement totals diverged"
	)
	require(
		int(controller.resolved_enemy_count)
			== int(controller.killed_enemy_count)
				+ int(controller.leaked_enemy_count),
		"resolved total is not killed plus leaked"
	)


func assert_continuous_auto_battle_runs(controller: Node) -> void:
	require(
		controller.select_scenario(&"auto_battle"),
		"continuous test could not select auto-battle scenario"
	)
	controller.clear_deployment()
	require(
		controller.apply_recommended_deployment(),
		"continuous test could not apply recommended deployment"
	)
	require(controller.start_battle(), "first recommended run could not start")
	var first_duration := run_until_finished(controller)
	var first_victory: Dictionary = controller.get_battle_snapshot()
	assert_recommended_victory(first_victory, "first")
	record_auto_result("recommended-1", first_victory, first_duration)

	controller.restart_battle()
	require(
		controller.get_battle_snapshot().get("deployment", {}).size() == 4,
		"restart did not preserve the deployment"
	)
	require(
		controller.clear_deployment(),
		"continuous test could not clear deployment after restart"
	)
	require(controller.start_battle(), "empty-deployment run could not start")
	var defeat_duration := run_until_finished(controller)
	var defeat: Dictionary = controller.get_battle_snapshot()
	record_auto_result("empty", defeat, defeat_duration)
	require(
		String(defeat.get("state", "")) == "DEFEAT",
		"empty-deployment auto-battle run did not end in DEFEAT"
	)
	require(
		int(defeat.get("village_durability", -1)) == 0
			and int(defeat.get("killed_enemy_count", -1)) == 0,
		"empty-deployment defeat did not come from ten leaks"
	)
	require(
		int(defeat.get("active_enemy_count", -1)) == 0,
		"defeat retained active enemies"
	)
	var failed_snapshot := defeat.duplicate(true)
	controller.simulate_step(20.0)
	require(
		controller.get_battle_snapshot() == failed_snapshot,
		"defeat continued combat or changed to victory"
	)

	controller.restart_battle()
	require(
		controller.apply_recommended_deployment(),
		"continuous test could not restore recommended deployment"
	)
	require(controller.start_battle(), "second recommended run could not start")
	var second_duration := run_until_finished(controller)
	var second_victory: Dictionary = controller.get_battle_snapshot()
	assert_recommended_victory(second_victory, "second")
	record_auto_result("recommended-2", second_victory, second_duration)

	require(
		finished_outcomes == [&"victory", &"defeat", &"victory"],
		"continuous runs emitted missing, duplicate, or stale finish signals"
	)
	require(
		int(second_victory.get("battle_finish_count", -1)) == 3,
		"battle finish handling was not exactly once per completed run"
	)


func assert_recommended_victory(snapshot: Dictionary, run_name: String) -> void:
	require(
		String(snapshot.get("state", "")) == "VICTORY",
		"%s recommended run did not end in VICTORY" % run_name
	)
	require(
		int(snapshot.get("village_durability", 0)) > 0,
		"%s recommended victory did not preserve village durability" % run_name
	)
	require(
		int(snapshot.get("active_enemy_count", -1)) == 0,
		"%s recommended victory retained active enemies" % run_name
	)
	require(
		int(snapshot.get("killed_enemy_count", 0)) > 0
			and int(snapshot.get("leaked_enemy_count", 0))
				< int(snapshot.get("planned_enemy_count", 0)),
		"%s recommended victory relied on every enemy leaking" % run_name
	)
	require(
		int(snapshot.get("resolved_enemy_count", -1))
			== int(snapshot.get("killed_enemy_count", 0))
				+ int(snapshot.get("leaked_enemy_count", 0)),
		"%s recommended settlement totals diverged" % run_name
	)
	require(
		int(snapshot.get("block_event_count", 0)) > 0,
		"%s recommended run produced no guard block" % run_name
	)
	require(
		int(snapshot.get("enemy_attack_event_count", 0)) > 0,
		"%s recommended run produced no enemy counterattack" % run_name
	)
	require(
		int(snapshot.get("healing_event_count", 0)) > 0,
		"%s recommended run produced no effective healing" % run_name
	)
	var character_stats := index_character_snapshots(
		snapshot.get("characters", [])
	)
	for character_id: StringName in CHARACTER_IDS:
		require(
			character_stats.has(character_id),
			"%s recommended run is missing %s stats"
				% [run_name, String(character_id)]
		)
		if character_stats.has(character_id):
			require(
				int(character_stats[character_id].get("action_count", 0)) > 0,
				"%s did not perform an effective action in %s recommended run"
					% [String(character_id), run_name]
			)
	require(
		StringName(character_stats.get(&"doctor", {}).get("last_action_type", &""))
			== &"heal",
		"doctor did not perform healing in %s recommended run" % run_name
	)
	for attacker_id: StringName in [&"guard", &"hunter", &"mage"]:
		require(
			StringName(
				character_stats.get(attacker_id, {}).get("last_action_type", &"")
			) == &"attack",
			"%s did not perform an attack in %s recommended run"
				% [String(attacker_id), run_name]
		)


func assert_clean_ready_state(controller: Node) -> void:
	var snapshot: Dictionary = controller.get_battle_snapshot()
	require(String(snapshot.get("state", "")) == "READY", "restart did not restore READY")
	require(
		int(snapshot.get("village_durability", -1)) == 10,
		"restart did not restore village durability"
	)
	for counter_name: String in [
		"generated_enemy_count",
		"active_enemy_count",
		"killed_enemy_count",
		"leaked_enemy_count",
		"resolved_enemy_count",
		"block_event_count",
		"enemy_attack_event_count",
		"character_attack_event_count",
		"healing_event_count",
	]:
		require(
			int(snapshot.get(counter_name, -1)) == 0,
			"restart did not reset %s" % counter_name
		)
	for character: Dictionary in snapshot.get("characters", []):
		require(
			int(character.get("current_health", -1))
				== int(character.get("max_health", -2)),
			"restart did not restore character health"
		)
		require(
			int(character.get("action_count", -1)) == 0
				and int(character.get("total_effect_amount", -1)) == 0
				and StringName(character.get("current_target_id", &"")) == &""
				and character.get("blocked_enemy_ids", []).is_empty(),
			"restart retained character combat state"
		)
	var enemy_layer := controller.get_node(
		"Battlefield/BattlefieldDisplayRoot/BattlefieldContent/EnemyLayer"
	)
	require(
		enemy_layer.get_child_count() == 0,
		"restart left enemy nodes or delayed callbacks in the scene tree"
	)


func index_character_snapshots(snapshots: Array) -> Dictionary:
	var indexed: Dictionary = {}
	for snapshot: Dictionary in snapshots:
		indexed[StringName(snapshot.get("character_id", &""))] = snapshot
	return indexed


func record_auto_result(
	run_name: String,
	snapshot: Dictionary,
	duration: float
) -> void:
	auto_run_results.append({
		"name": run_name,
		"state": snapshot.get("state", ""),
		"durability": snapshot.get("village_durability", 0),
		"killed": snapshot.get("killed_enemy_count", 0),
		"leaked": snapshot.get("leaked_enemy_count", 0),
		"duration": duration,
	})


func run_until_finished(controller: Node) -> float:
	for step in range(MAX_SIMULATION_STEPS):
		if String(controller.get_battle_snapshot().get("state", "")) != "RUNNING":
			return float(step) * SIMULATION_STEP
		controller.simulate_step(SIMULATION_STEP)
	require(false, "simulation did not reach a terminal state")
	return float(MAX_SIMULATION_STEPS) * SIMULATION_STEP


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
			"V2-2 scene has an external dependency: %s" % dependency_path
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

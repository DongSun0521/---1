extends SceneTree

const SCENE_PATH := "res://prototype/formation_defense/scenes/formation_defense_prototype.tscn"
const CONFIG := preload("res://prototype/formation_defense/data/formation_defense_config.gd")
const SAVE_PATH := "user://adventure_village_save.json"
const STEP := 0.1
const EXPECTED_CHECKS := 47

var failures: Array[String] = []
var check_count := 0
var interaction_stats: Dictionary = {}


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var game_state := root.get_node_or_null("/root/GameState")
	var game_state_before := snapshot_script_variables(game_state)
	var save_before := snapshot_file(SAVE_PATH)
	var packed := load(SCENE_PATH) as PackedScene
	check(packed != null, "1 entry scene loads")
	var controller = packed.instantiate()
	root.add_child(controller)
	await process_frame
	await process_frame
	controller.set_automatic_simulation(false)
	var commands = controller.command_controller
	check(is_instance_valid(commands), "2 unique command controller exists")
	check(commands.has_method("issue_command") and commands.has_method("cancel_command"), "3 command interfaces exist")

	await prepare_run(controller)
	var first = first_enemy(controller)
	controller.handle_battlefield_pointer(first.position, MOUSE_BUTTON_LEFT)
	check(commands.get_target_runtime_id() == first.runtime_id, "4 battlefield GUI click creates command")
	var first_command: Dictionary = commands.get_active_command_snapshot()
	check(first_command.target_runtime_id == first.runtime_id and first_command.context == &"FOCUS", "5 single focus context")
	var command_id := int(first_command.command_id)
	commands.issue_command(first.runtime_id)
	check(int(commands.get_active_command_snapshot().command_id) == command_id and int(commands.get_stats_snapshot().issued_count) == 1, "6 repeated click is idempotent")
	var second = controller.spawn_enemy_for_route(&"middle", &"shield", {"max_health": 400, "leak_damage": 0})
	commands.issue_command(second.runtime_id)
	check(commands.get_active_command_snapshot().target_runtime_id == second.runtime_id and int(commands.get_stats_snapshot().replaced_count) == 1, "7 second target replaces first")
	commands.cancel_command(&"PLAYER_CANCEL")
	check(commands.get_active_command_snapshot().is_empty(), "8 right-click cancellation interface clears")
	commands.issue_command(first.runtime_id)
	commands.cancel_command(&"PLAYER_CANCEL")
	check(commands.get_active_command_snapshot().is_empty(), "9 Escape cancellation interface clears")
	commands.issue_command(first.runtime_id)
	var before_blank: Dictionary = commands.get_active_command_snapshot().duplicate(true)
	controller.pick_enemy_at(Vector2(-1000.0, -1000.0))
	check(commands.get_active_command_snapshot().command_id == before_blank.command_id, "10 empty left click preserves command")
	var source := FileAccess.get_file_as_string("res://prototype/formation_defense/scripts/formation_defense_prototype.gd")
	check(
		source.contains("battlefield.gui_input.connect")
			and source.contains("func on_battlefield_gui_input"),
		"11 battlefield GUI input prevents HUD click-through"
	)

	first.set_debug_world_position(Vector2(500.0, 200.0))
	second.set_debug_world_position(Vector2(500.0, 200.0))
	var first_original_id: StringName = first.runtime_id
	var second_original_id: StringName = second.runtime_id
	first.spawn_sequence = 2
	second.spawn_sequence = 1
	check(controller.pick_enemy_at(Vector2(500.0, 200.0)) == second, "12 overlap tie uses spawn sequence")
	first.spawn_sequence = 1
	second.spawn_sequence = 1
	first.runtime_id = &"runtime_b"
	second.runtime_id = &"runtime_a"
	check(controller.pick_enemy_at(Vector2(500.0, 200.0)) == second, "13 overlap tie uses runtime id")
	# Restore dictionary-consistent IDs before lifecycle checks.
	first.runtime_id = first_original_id
	second.runtime_id = second_original_id

	var hunter = controller.get_character_node(&"hunter")
	hunter.deploy_to(&"test", &"top", Vector2(500.0, 200.0))
	first.set_debug_world_position(Vector2(510.0, 200.0))
	second.set_debug_world_position(Vector2(515.0, 200.0))
	first.route_progress = 0.9
	second.route_progress = 0.2
	commands.issue_command(second.runtime_id)
	var mage = controller.get_character_node(&"mage")
	mage.deploy_to(&"test_mage", &"top", Vector2(500.0, 200.0))
	check(
		hunter.choose_enemy_target([first, second], commands) == second
			and mage.choose_enemy_target([first, second], commands) == second,
		"14 legal command target has priority"
	)
	second.set_debug_world_position(Vector2(900.0, 400.0))
	check(hunter.choose_enemy_target([first, second], commands) == first, "15 out-of-range target falls back")
	second.set_debug_world_position(Vector2(520.0, 200.0))
	check(hunter.choose_enemy_target([first, second], commands) == second, "16 entering range gains next selection")
	var guard = controller.get_character_node(&"guard")
	guard.deploy_to(&"test_guard", &"top", Vector2(500.0, 200.0))
	guard.add_blocked_enemy(first.runtime_id)
	first.set_blocker(guard.character_id)
	check(guard.choose_enemy_target([first, second], commands) == first, "17 guard cannot bypass blocker")
	var doctor = controller.get_character_node(&"doctor")
	doctor.deploy_to(&"test_doctor", &"top", Vector2(500.0, 200.0))
	check(doctor.simulate_action(10.0, [first, second], [doctor], commands).is_empty(), "18 doctor never attacks command target")
	hunter.current_cooldown = 0.73
	commands.issue_command(first.runtime_id)
	check(is_equal_approx(hunter.current_cooldown, 0.73), "19 command does not reset cooldown")
	check(not source.contains("projectile") or not source.contains("retarget_projectile"), "20 no in-flight projectile retarget path")

	first.apply_formation_state(&"forming", &"A", &"FORMING_A", 0.4, {})
	commands.issue_command(first.runtime_id)
	check(commands.get_active_command_snapshot().context == &"PREVENT_FORMATION", "21 forming member uses prevent context")
	var locked_id: StringName = commands.get_active_command_snapshot().target_runtime_id
	first.apply_formation_state(&"complete_a", &"A", &"COMPLETE", 1.0, {})
	commands.process_command(0.0)
	check(commands.get_active_command_snapshot().target_runtime_id == locked_id and commands.get_active_command_snapshot().context == &"DISMANTLE_A", "22 forming-to-A keeps runtime target")
	first.apply_formation_state(&"forming_b", &"B", &"FORMING_B", 0.5, {})
	commands.process_command(0.0)
	first.apply_formation_state(&"complete_b", &"B", &"COMPLETE", 1.0, {})
	commands.process_command(0.0)
	check(commands.get_active_command_snapshot().target_runtime_id == locked_id and commands.get_active_command_snapshot().context == &"DISMANTLE_B", "23 A-to-B keeps runtime target")
	check(commands.get_active_command_snapshot().highest_complete_level == 2, "24 highest complete level records B")
	var health_before: int = first.current_health
	commands.issue_command(first.runtime_id)
	check(first.current_health == health_before and first.formation_state == &"COMPLETE", "25 command adds no damage or debuff")
	first.apply_formation_state(&"remaining_a", &"A", &"COMPLETE", 1.0, {})
	commands.process_command(0.0)
	check(commands.get_active_command_snapshot().is_empty() and int(commands.get_stats_snapshot().b_dismantled_count) == 1, "26 B downgrade completes once")
	commands.process_command(0.0)
	check(int(commands.get_stats_snapshot().b_dismantled_count) == 1, "27 B success is idempotent")
	check(first.formation_state == &"COMPLETE" and first.formation_level == &"A", "28 B downgrade does not auto-dismantle A")
	commands.issue_command(first.runtime_id)
	first.reset_formation_state()
	commands.process_command(0.0)
	check(commands.get_active_command_snapshot().is_empty() and int(commands.get_stats_snapshot().a_dismantled_count) == 1, "29 reissued A command can dismantle A")
	check(first.route_id != &"" and first.blocking_lane_id != &"", "30 command preserves routing identity")

	commands.issue_command(second.runtime_id)
	commands.handle_enemy_removed(second.runtime_id, &"KILLED")
	check(commands.get_active_command_snapshot().is_empty(), "31 target death safely cleans command")
	commands.issue_command(first.runtime_id)
	controller.finish_victory()
	interaction_stats = commands.get_stats_snapshot()
	check(commands.get_active_command_snapshot().is_empty(), "32 battle end clears command and visuals")
	controller.restart_battle()
	check(commands.get_active_command_snapshot().is_empty() and int(commands.get_stats_snapshot().issued_count) == 0 and commands.get_target_runtime_id() == &"", "33 restart clears IDs and stats")
	check(is_equal_approx(CONFIG.FORMATION_SLOT_MOVE_SPEED, 80.0) and source_is_converge_only(), "34 slot speed only drives forming steering")
	await assert_attack_visuals(controller)

	controller.select_scenario(&"command_demo")
	controller.apply_recommended_deployment()
	controller.start_battle()
	print("v2-4 smoke: starting deterministic command demo")
	var steps := 0
	while controller.battle_state == controller.BattleState.RUNNING and steps < 600:
		controller.simulate_step(STEP)
		steps += 1
	print("v2-4 smoke: command demo finished after %d steps" % steps)
	check(controller.get_state_name() == "VICTORY" and controller.battle_elapsed >= 30.0 and controller.battle_elapsed <= 50.0, "46 no-input command demo completes in 30-50 seconds")
	print("v2-4 smoke: checking isolation fingerprints")
	check(snapshot_script_variables(game_state) == game_state_before and snapshot_file(SAVE_PATH) == save_before, "47 GameState and save fingerprint unchanged")

	var demo_elapsed: float = controller.battle_elapsed
	controller.queue_free()
	await process_frame
	if check_count != EXPECTED_CHECKS:
		failures.append("coverage count %d != %d" % [check_count, EXPECTED_CHECKS])
	if failures.is_empty():
		print(
			"v2-4 interaction stats: issued=%d replaced=%d priority=%d fallback=%d participants=%d B=%d A=%d" % [
				int(interaction_stats.get("issued_count", 0)),
				int(interaction_stats.get("replaced_count", 0)),
				int(interaction_stats.get("priority_attack_count", 0)),
				int(interaction_stats.get("fallback_count", 0)),
				int(interaction_stats.get("participant_count", 0)),
				int(interaction_stats.get("b_dismantled_count", 0)),
				int(interaction_stats.get("a_dismantled_count", 0)),
			]
		)
		print("v2-4 focus command smoke ok: 47 requirements, demo=%.1fs" % demo_elapsed)
		quit(0)
	else:
		push_error("v2-4 focus command smoke failed: %s" % "; ".join(failures))
		quit(1)


func prepare_run(controller) -> void:
	controller.restart_battle()
	await process_frame
	controller.select_scenario(&"command_demo")
	controller.start_battle()


func assert_attack_visuals(controller) -> void:
	await prepare_run(controller)
	for character in controller.character_nodes.values():
		character.undeploy()
	var commands = controller.command_controller
	var hunter = controller.get_character_node(&"hunter")
	var mage = controller.get_character_node(&"mage")
	var guard = controller.get_character_node(&"guard")
	var doctor = controller.get_character_node(&"doctor")
	var first = first_enemy(controller)
	hunter.deploy_to(&"visual_hunter", &"top", Vector2(500.0, 200.0))
	first.set_debug_world_position(Vector2(540.0, 200.0))
	first.route_progress = 0.9
	var health_before: int = first.current_health
	var attacks_before: int = hunter.action_count
	controller.simulate_character_actions(0.0)
	var visuals: Array[Dictionary] = controller.get_attack_visual_snapshots()
	check(
		visuals.size() == 1
			and visuals[0].attacker_runtime_id == hunter.character_id
			and visuals[0].target_runtime_id == hunter.current_target_id,
		"35 one real ranged attack creates one matching visual"
	)
	check(
		first.current_health == health_before - hunter.attack_damage
			and hunter.action_count == attacks_before + 1
			and is_equal_approx(hunter.current_cooldown, hunter.action_interval),
		"36 visual does not alter damage attack count or cooldown"
	)
	var first_visual_target: StringName = visuals[0].target_runtime_id
	var second = controller.spawn_enemy_for_route(
		&"middle", &"shield", {"max_health": 400, "leak_damage": 0}
	)
	second.set_debug_world_position(Vector2(545.0, 200.0))
	second.route_progress = 0.1
	commands.issue_command(second.runtime_id)
	hunter.current_cooldown = 0.0
	controller.simulate_character_actions(0.0)
	visuals = controller.get_attack_visual_snapshots()
	check(
		visuals.size() == 2
			and visuals[-1].target_runtime_id == second.runtime_id
			and hunter.current_target_id == second.runtime_id,
		"37 legal focus target drives the subsequent visual"
	)
	commands.issue_command(first.runtime_id)
	check(
		visuals[-1].target_runtime_id == second.runtime_id
			and first_visual_target == visuals[0].target_runtime_id,
		"38 launched visuals keep immutable target IDs"
	)
	second.set_debug_world_position(Vector2(1000.0, 400.0))
	commands.issue_command(second.runtime_id)
	hunter.current_cooldown = 0.0
	controller.simulate_character_actions(0.0)
	visuals = controller.get_attack_visual_snapshots()
	check(
		visuals[-1].target_runtime_id == first.runtime_id
			and hunter.current_target_id == first.runtime_id,
		"39 illegal focus target visual follows automatic fallback"
	)

	hunter.undeploy()
	doctor.deploy_to(&"visual_doctor", &"top", Vector2(500.0, 200.0))
	var visual_count_before_doctor := visuals.size()
	controller.simulate_character_actions(10.0)
	check(
		controller.get_attack_visual_snapshots().size() == visual_count_before_doctor,
		"40 doctor creates no attack visual"
	)
	doctor.undeploy()
	mage.deploy_to(&"visual_mage", &"top", Vector2(500.0, 200.0))
	mage.current_cooldown = 0.0
	commands.issue_command(first.runtime_id)
	controller.simulate_character_actions(0.0)
	visuals = controller.get_attack_visual_snapshots()
	check(visuals[-1].visual_kind == &"MAGIC_ORB", "41 mage uses magic orb visual")
	mage.undeploy()
	guard.deploy_to(&"visual_guard", &"top", Vector2(500.0, 200.0))
	guard.add_blocked_enemy(first.runtime_id)
	first.set_blocker(guard.character_id)
	guard.current_cooldown = 0.0
	controller.simulate_character_actions(0.0)
	visuals = controller.get_attack_visual_snapshots()
	check(visuals[-1].visual_kind == &"MELEE_SLASH", "42 guard uses melee slash visual")
	check(
		float(visuals[0].duration) >= 0.15
			and float(visuals[0].duration) <= 0.35
			and is_equal_approx(float(visuals[-1].duration), 0.10),
		"43 visual durations stay in their presentation-only bounds"
	)
	controller.finish_victory()
	check(controller.get_attack_visual_snapshots().is_empty(), "44 victory clears all visuals")

	var two_runs_clean := true
	for run_index in range(2):
		await prepare_run(controller)
		for character in controller.character_nodes.values():
			character.undeploy()
		hunter.deploy_to(&"visual_hunter_%d" % run_index, &"top", Vector2(500.0, 200.0))
		first = first_enemy(controller)
		first.set_debug_world_position(Vector2(540.0, 200.0))
		controller.simulate_character_actions(0.0)
		two_runs_clean = two_runs_clean \
			and controller.get_attack_visual_snapshots().size() == 1
		controller.restart_battle()
		two_runs_clean = two_runs_clean \
			and controller.get_attack_visual_snapshots().is_empty() \
			and controller.attack_visual_spawn_count == 0
	check(two_runs_clean, "45 two runs and restarts leave no visual debug state")


func first_enemy(controller):
	return controller.active_enemies.values()[0]


func source_is_converge_only() -> bool:
	var manager_source := FileAccess.get_file_as_string("res://prototype/formation_defense/scripts/formation_defense_formation_manager.gd")
	return manager_source.count("FORMATION_SLOT_MOVE_SPEED") == 1 \
		and manager_source.contains("if is_forming") \
		and manager_source.contains("COMPLETE_FORMATION_SLOT_MAINTENANCE_SPEED")


func snapshot_script_variables(target: Object) -> Dictionary:
	var snapshot: Dictionary = {}
	if not is_instance_valid(target):
		return snapshot
	for property: Dictionary in target.get_property_list():
		if (int(property.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var property_name := StringName(property.get("name", &""))
		snapshot[property_name] = normalize(target.get(property_name))
	return snapshot


func normalize(value: Variant) -> Variant:
	if typeof(value) == TYPE_ARRAY:
		var result: Array = []
		for item in value:
			result.append(normalize(item))
		return result
	if typeof(value) == TYPE_DICTIONARY:
		var result: Dictionary = {}
		for key in value:
			result[key] = normalize(value[key])
		return result
	if typeof(value) == TYPE_OBJECT:
		return null if value == null else {"class": value.get_class(), "id": value.get_instance_id()}
	return value


func snapshot_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"exists": false}
	var content := FileAccess.get_file_as_bytes(path)
	return {"exists": true, "length": content.size(), "hash": hash(content), "modified": FileAccess.get_modified_time(path)}


func check(condition: bool, label: String) -> void:
	check_count += 1
	if condition:
		return
	failures.append(label)
	push_error(label)

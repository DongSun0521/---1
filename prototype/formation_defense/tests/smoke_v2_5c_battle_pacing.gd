extends SceneTree

const SCENE_PATH := "res://prototype/formation_defense/scenes/formation_defense_prototype.tscn"
const CONFIG := preload("res://prototype/formation_defense/data/formation_defense_config.gd")
const WaveDirector := preload("res://prototype/formation_defense/scripts/formation_defense_wave_director.gd")
const STEP := 0.25
const EXPECTED_WAVE_COUNTS := [4, 5, 6, 7, 9, 13]
const EXPECTED_CHECKS := 37

var failures: Array[String] = []
var check_count := 0


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var config := CONFIG.get_wave_battle_config(&"v2_5c_pacing")
	var validation := WaveDirector.validate_battle_config(
		config,
		CONFIG.get_monster_type_ids(),
		CONFIG.get_spawn_point_lane_map(),
		CONFIG.get_visual_route_ids()
	)
	check(validation.is_empty(), "1 V2-5C configuration loads and validates")
	var waves: Array = config.get("waves", [])
	var counts: Array[int] = []
	for wave: Dictionary in waves:
		counts.append(WaveDirector.count_wave_enemies(wave))
	check(waves.size() == 6 and counts == EXPECTED_WAVE_COUNTS, "2 six-wave plans are correct")
	check(is_equal_approx(float(config.inter_wave_delay), 4.0), "2a inter-wave countdown is four seconds")
	var pacing_charge: Dictionary = config.enemy_profile_overrides[&"charge"]
	check(
		int(pacing_charge.max_health) == 91
			and is_equal_approx(float(pacing_charge.move_speed), 42.0)
			and is_equal_approx(float(config.formation_approach_speed), 52.0)
			and is_equal_approx(float(config.formation_completion_tolerance), 12.0),
		"2b V2-5C owns independent health and movement tuning"
	)

	var controller = (load(SCENE_PATH) as PackedScene).instantiate()
	root.add_child(controller)
	await process_frame
	await process_frame
	controller.set_automatic_simulation(false)
	controller.select_scenario(&"pacing_validation")
	controller.apply_recommended_deployment()
	controller.start_battle()
	var first := run_battle(controller, false)
	check(first.wave_order == [0, 1, 2, 3, 4, 5], "3 all six waves enter in strict order")
	check(first.generated == 44 and first.resolved == 44, "4 every planned enemy is generated and resolved")
	check(first.routes.size() == 5, "5 the battle covers all five formation lanes")
	check(first.spawn_points.size() >= 3, "6 mid/late battle uses multiple spawn points")
	check(not first.early_victory, "7 victory never occurs before the final wave cleanup")
	check(first.state == "VICTORY" and first.wave_state == "COMPLETED", "8 final cleanup is the only victory point")
	check(first.state == "VICTORY", "9 recommended unattended deployment wins")
	check(first.duration >= 180.0 and first.duration <= 240.0, "10 duration is within 180-240 seconds")
	check(first.late_peak > first.early_peak, "11 final third pressure peak exceeds the opening third")
	check(first.has_relief, "12 the pressure samples contain a perceptible relief interval")
	check(first.longest_empty <= 10.0, "13 non-countdown empty-field time stays bounded")
	check(max_single_enemy_tail(first.records) <= 10.0, "13a no wave ends with one slow enemy for too long")
	check(first.max_spawn_burst <= 3, "14 no frame emits an abnormal enemy burst")
	check(first.midlate_a > 0 and first.midlate_b > 0, "15 A and B formations emerge naturally in mid/late waves")
	check(first.durability > 0 and first.durability <= 10, "16 village durability and totals remain valid")
	check(first.durability < 10, "16a unattended combat no longer clears without village damage")
	check(formation_approach_is_observable(first.formation_stats), "16b A and B approach durations are recorded and observable")
	check(completions_respect_tolerance(first.formation_stats, 12.0), "16c completed formations are inside the configured slot tolerance")
	check(formal_visual_states_are_valid(first.group_visual_audit), "16d formal formation visuals appear only after completion")
	check(
		completion_events_are_unique(first.formation_stats, "completed_a_observations", "completed_a_count"),
		"16e every FORMED_A transition contributes exactly one historical completion event"
	)
	check(
		completion_events_are_unique(first.formation_stats, "completed_b_observations", "completed_b_count"),
		"16f every FORMED_B transition contributes exactly one historical completion event"
	)
	check(
		b_sources_preserve_a_history(first.formation_stats),
		"16g converting completed A formations into B never removes their A completion history"
	)
	check(
		wave_totals_match_global(first) and first.total_a == 20 and first.total_b == 4,
		"16h per-wave A/B completion sums equal the global historical completion totals"
	)

	var direct = WaveDirector.new()
	direct.configure(config, CONFIG.get_monster_type_ids(), CONFIG.get_spawn_point_lane_map(), CONFIG.get_visual_route_ids())
	direct.start()
	direct.advance(3.0)
	var trace_after_failure: int = direct.get_snapshot().spawn_trace.size()
	direct.stop()
	direct.advance(30.0)
	check(
		direct.get_state_name() == "STOPPED"
			and direct.get_snapshot().spawn_trace.size() == trace_after_failure,
		"17 defeat immediately stops remaining generation"
	)

	direct.start()
	direct.advance(9.1)
	var restart_trace := sanitize_trace(direct.get_snapshot().spawn_trace)
	check(restart_trace == first.trace.slice(0, restart_trace.size()), "18 mid-battle restart restores the fixed initial trace")
	controller.restart_battle()
	await process_frame
	var reset_snapshot: Dictionary = controller.get_battle_snapshot()
	var reset_stats: Dictionary = reset_snapshot.get("formation_stats", {})
	var reset_wave: Dictionary = reset_snapshot.get("wave", {})
	var reset_records: Array = Dictionary(reset_wave.get("pacing", {})).get("wave_records", [])
	check(
		int(reset_stats.get("completed_a_count", -1)) == 0
			and int(reset_stats.get("completed_b_count", -1)) == 0
			and Array(reset_stats.get("completed_a_observations", [])).is_empty()
			and Array(reset_stats.get("completed_b_observations", [])).is_empty()
			and sum_record_stat(reset_records, 0, reset_records.size(), "completed_a") == 0
			and sum_record_stat(reset_records, 0, reset_records.size(), "completed_b") == 0
			and Array(reset_wave.get("spawn_trace", [])).is_empty(),
		"18a restart clears global, per-wave and event-level formation history"
	)
	controller.queue_free()
	await process_frame

	var controller2 = (load(SCENE_PATH) as PackedScene).instantiate()
	root.add_child(controller2)
	await process_frame
	await process_frame
	controller2.set_automatic_simulation(false)
	controller2.select_scenario(&"pacing_validation")
	controller2.apply_recommended_deployment()
	controller2.start_battle()
	controller2.set_debug_panel_open(true)
	controller2.set_debug_panel_open(false)
	var second := run_battle(controller2, false)
	check(first.trace == second.trace, "19 debug drawer toggles do not change the spawn timeline")
	check(
		first.trace == second.trace
			and first.records == second.records
			and first.formation_stats == second.formation_stats
			and first.state == second.state
			and is_equal_approx(first.duration, second.duration),
		"20 two fixed-seed unattended runs are fully deterministic"
	)
	var commanded_first := await run_commanded_pacing_scene()
	var commanded_second := await run_commanded_pacing_scene()
	print("v2-5c commanded: state=%s duration=%.1f killed=%d leaked=%d durability=%d global_A/B=%d/%d commands=%s" % [
		commanded_first.state, commanded_first.duration,
		commanded_first.killed, commanded_first.leaked, commanded_first.durability,
		commanded_first.total_a, commanded_first.total_b,
		str(commanded_first.commanded_waves),
	])
	for record: Dictionary in commanded_first.records:
		print_wave_record(record)
	check(
		commanded_first.state == "VICTORY"
			and commanded_first.durability >= first.durability + 3
			and commanded_first.command_count >= 3,
		"20a deterministic focus commands materially improve village durability"
	)
	check(
		commanded_first == commanded_second,
		"20b two commanded runs reproduce result, commands and formation statistics"
	)
	check(
		wave_totals_match_global(commanded_first),
		"20c commanded per-wave A/B completion sums equal global historical totals"
	)

	var baseline_b = await run_baseline_scene(&"wave_validation", true, 0.1)
	check(
		baseline_b.state == "VICTORY"
			and baseline_b.generated == 12
			and absf(float(baseline_b.duration) - 67.0) <= 0.11,
		"21 V2-5B high-health baseline remains 12 enemies and about 67.0 seconds"
	)
	var baseline_v4 = await run_baseline_scene(&"command_demo", true, 0.1)
	check(
		baseline_v4.state == "VICTORY"
			and absf(float(baseline_v4.duration) - 41.2) <= 0.11,
		"22 V2-4 deterministic baseline remains about 41.2 seconds"
	)

	print_run("first", first)
	print_run("second", second)
	controller2.queue_free()
	direct.queue_free()
	await process_frame
	if check_count != EXPECTED_CHECKS:
		failures.append("coverage count %d != %d" % [check_count, EXPECTED_CHECKS])
	if failures.is_empty():
		print("v2-5c battle pacing smoke ok: %d requirements" % EXPECTED_CHECKS)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func run_battle(controller, toggle_debug: bool, issue_basic_commands := false) -> Dictionary:
	var wave_order: Array[int] = []
	var routes: Dictionary = {}
	var spawn_points: Dictionary = {}
	var previous_generated := 0
	var max_spawn_burst := 0
	var early_victory := false
	var commanded_waves: Dictionary = {}
	var group_visual_audit := {"forming_formal": 0, "complete_without_formal": 0}
	var steps := 0
	while controller.battle_state == controller.BattleState.RUNNING and steps < 1200:
		if toggle_debug and steps % 97 == 0:
			controller.set_debug_panel_open(not controller.debug_panel_open)
		controller.simulate_step(STEP)
		var wave: Dictionary = controller.get_wave_snapshot()
		var wave_index := int(wave.get("current_wave_index", -1))
		for group: Dictionary in controller.get_formation_groups_snapshot():
			if StringName(group.get("formation_state", &"")) == &"COMPLETE":
				if not bool(group.get("formal_visual_visible", false)):
					group_visual_audit.complete_without_formal += 1
			elif bool(group.get("formal_visual_visible", false)):
				group_visual_audit.forming_formal += 1
		var command_limit := 2 if wave_index >= 4 else 1
		if (
			issue_basic_commands
			and wave_index >= 2
			and int(commanded_waves.get(wave_index, 0)) < command_limit
			and controller.command_controller.active_command.is_empty()
		):
			var target_id := find_tactical_command_target(controller, wave_index >= 4)
			if target_id != &"":
				controller.interrupt_enemy_formation(
					target_id,
					CONFIG.INTERRUPTION_FORMATION_BREAK
				)
				if controller.command_controller.issue_command(target_id):
					commanded_waves[wave_index] = int(commanded_waves.get(wave_index, 0)) + 1
		if wave_index >= 0 and (wave_order.is_empty() or wave_order[-1] != wave_index):
			wave_order.append(wave_index)
		var generated := int(wave.get("total_generated", 0))
		max_spawn_burst = maxi(max_spawn_burst, generated - previous_generated)
		previous_generated = generated
		for event: Dictionary in wave.get("spawn_trace", []):
			routes[StringName(event.get("route_id", &""))] = true
			spawn_points[StringName(event.get("spawn_point_id", &""))] = true
		if controller.get_state_name() == "VICTORY" and wave_index < 5:
			early_victory = true
		steps += 1
	var battle: Dictionary = controller.get_battle_snapshot()
	var wave: Dictionary = battle.get("wave", {})
	var pacing: Dictionary = wave.get("pacing", {})
	var records: Array = pacing.get("wave_records", [])
	var early_peak := max_record_peak(records, 0, 2)
	var late_peak := max_record_peak(records, 4, 6)
	var midlate_a := sum_record_stat(records, 2, 6, "completed_a")
	var midlate_b := sum_record_stat(records, 2, 6, "completed_b")
	var formation_stats: Dictionary = battle.get("formation_stats", {}).duplicate(true)
	return {
		"state": String(battle.get("state", "")),
		"wave_state": String(wave.get("state", "")),
		"duration": float(battle.get("battle_elapsed", 0.0)),
		"generated": int(wave.get("total_generated", 0)),
		"resolved": int(wave.get("total_resolved", 0)),
		"killed": int(battle.get("killed_enemy_count", 0)),
		"leaked": int(battle.get("leaked_enemy_count", 0)),
		"durability": int(battle.get("village_durability", 0)),
		"wave_order": wave_order,
		"routes": routes,
		"spawn_points": spawn_points,
		"early_victory": early_victory,
		"max_spawn_burst": max_spawn_burst,
		"trace": sanitize_trace(wave.get("spawn_trace", [])),
		"formation_stats": formation_stats,
		"total_a": int(formation_stats.get("completed_a_count", 0)),
		"total_b": int(formation_stats.get("completed_b_count", 0)),
		"records": records.duplicate(true),
		"samples": pacing.get("pressure_samples", []).duplicate(true),
		"early_peak": early_peak,
		"late_peak": late_peak,
		"has_relief": has_relief_interval(pacing.get("pressure_samples", [])),
		"longest_empty": float(pacing.get("longest_non_countdown_empty_time", 0.0)),
		"midlate_a": midlate_a,
		"midlate_b": midlate_b,
		"command_count": sum_dictionary_int_values(commanded_waves),
		"commanded_waves": commanded_waves.duplicate(true),
		"group_visual_audit": group_visual_audit,
	}


func run_commanded_pacing_scene() -> Dictionary:
	var controller = (load(SCENE_PATH) as PackedScene).instantiate()
	root.add_child(controller)
	await process_frame
	await process_frame
	controller.set_automatic_simulation(false)
	controller.select_scenario(&"pacing_validation")
	controller.apply_recommended_deployment()
	controller.start_battle()
	var run := run_battle(controller, false, true)
	var result := {
		"state": run.state,
		"duration": run.duration,
		"generated": run.generated,
		"resolved": run.resolved,
		"killed": run.killed,
		"leaked": run.leaked,
		"durability": run.durability,
		"total_a": run.total_a,
		"total_b": run.total_b,
		"command_count": run.command_count,
		"commanded_waves": run.commanded_waves,
		"trace": run.trace,
		"formation_stats": run.formation_stats,
		"records": run.records,
	}
	controller.queue_free()
	await process_frame
	return result


func find_tactical_command_target(controller, require_b: bool) -> StringName:
	var candidates: Array = controller.active_enemies.values()
	candidates.sort_custom(func(a, b): return String(a.runtime_id) < String(b.runtime_id))
	for desired_level: StringName in ([&"B"] if require_b else [&"A", &"B"]):
		for enemy in candidates:
			if enemy.formation_state == &"COMPLETE" and enemy.formation_level == desired_level:
				return StringName(enemy.runtime_id)
	return &""


func formation_approach_is_observable(stats: Dictionary) -> bool:
	var saw_a := false
	var saw_b := false
	for observation: Dictionary in stats.get("completed_a_observations", []):
		saw_a = saw_a or float(observation.get("lock_to_complete_duration", 0.0)) >= 1.0
	for observation: Dictionary in stats.get("completed_b_observations", []):
		saw_b = saw_b or float(observation.get("lock_to_complete_duration", 0.0)) >= 1.0
	return saw_a and saw_b


func completions_respect_tolerance(stats: Dictionary, tolerance: float) -> bool:
	for key: String in ["completed_a_observations", "completed_b_observations"]:
		for observation: Dictionary in stats.get(key, []):
			if float(observation.get("completion_slot_error", INF)) > tolerance + 0.01:
				return false
	return true


func formal_visual_states_are_valid(audit: Dictionary) -> bool:
	return int(audit.forming_formal) == 0 and int(audit.complete_without_formal) == 0


func completion_events_are_unique(stats: Dictionary, observations_key: String, count_key: String) -> bool:
	var observations: Array = stats.get(observations_key, [])
	var unique_ids: Dictionary = {}
	for observation: Dictionary in observations:
		var formation_id := StringName(observation.get("formation_id", &""))
		if formation_id == &"" or unique_ids.has(formation_id):
			return false
		unique_ids[formation_id] = true
	return unique_ids.size() == int(stats.get(count_key, -1))


func b_sources_preserve_a_history(stats: Dictionary) -> bool:
	var completed_a_ids: Dictionary = {}
	for observation: Dictionary in stats.get("completed_a_observations", []):
		completed_a_ids[StringName(observation.get("formation_id", &""))] = true
	for observation: Dictionary in stats.get("completed_b_observations", []):
		var source_ids: Array = observation.get("source_a_ids", [])
		if source_ids.size() != 2:
			return false
		for source_id: StringName in source_ids:
			if not completed_a_ids.has(source_id):
				return false
	return true


func wave_totals_match_global(result: Dictionary) -> bool:
	return (
		sum_record_stat(result.records, 0, result.records.size(), "completed_a") == result.total_a
		and sum_record_stat(result.records, 0, result.records.size(), "completed_b") == result.total_b
	)


func sum_dictionary_int_values(values: Dictionary) -> int:
	var total := 0
	for value in values.values():
		total += int(value)
	return total


func run_baseline_scene(scenario_id: StringName, deploy: bool, step: float) -> Dictionary:
	var controller = (load(SCENE_PATH) as PackedScene).instantiate()
	root.add_child(controller)
	await process_frame
	await process_frame
	controller.set_automatic_simulation(false)
	controller.select_scenario(scenario_id)
	if deploy:
		controller.apply_recommended_deployment()
	controller.start_battle()
	var steps := 0
	while controller.battle_state == controller.BattleState.RUNNING and steps < 2000:
		controller.simulate_step(step)
		steps += 1
	var snapshot: Dictionary = controller.get_battle_snapshot()
	var result := {
		"state": String(snapshot.get("state", "")),
		"duration": float(snapshot.get("battle_elapsed", 0.0)),
		"generated": int(snapshot.get("generated_enemy_count", 0)),
	}
	controller.queue_free()
	await process_frame
	return result


func sanitize_trace(raw_trace: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Dictionary in raw_trace:
		result.append({
			"wave_index": int(event.get("wave_index", -1)),
			"subwave_index": int(event.get("subwave_index", -1)),
			"group_index": int(event.get("group_index", -1)),
			"item_index": int(event.get("item_index", -1)),
			"due_time": float(event.get("due_time", 0.0)),
			"enemy_profile_id": StringName(event.get("enemy_profile_id", &"")),
			"spawn_point_id": StringName(event.get("spawn_point_id", &"")),
			"route_id": StringName(event.get("route_id", &"")),
		})
	return result


func max_record_peak(records: Array, from_index: int, to_index: int) -> int:
	var result := 0
	for index in range(from_index, mini(to_index, records.size())):
		result = maxi(result, int(Dictionary(records[index]).get("peak_active", 0)))
	return result


func sum_record_stat(records: Array, from_index: int, to_index: int, key: String) -> int:
	var result := 0
	for index in range(from_index, mini(to_index, records.size())):
		result += int(Dictionary(records[index]).get(key, 0))
	return result


func max_single_enemy_tail(records: Array) -> float:
	var result := 0.0
	for record: Dictionary in records:
		result = maxf(result, float(record.get("single_enemy_tail_time", 0.0)))
	return result


func has_relief_interval(samples: Array) -> bool:
	for index in range(1, samples.size() - 1):
		var before := int(Dictionary(samples[index - 1]).get("active", 0))
		var current := int(Dictionary(samples[index]).get("active", 0))
		var after := int(Dictionary(samples[index + 1]).get("active", 0))
		if before >= current + 2 and after >= current + 2:
			return true
	return false


func print_run(label: String, result: Dictionary) -> void:
	var a_range := observation_duration_range(result.formation_stats.get("completed_a_observations", []))
	var b_range := observation_duration_range(result.formation_stats.get("completed_b_observations", []))
	print("v2-5c %s: state=%s duration=%.1f generated=%d killed=%d leaked=%d durability=%d early/late=%d/%d empty=%.1f global_A/B=%d/%d midlate_A/B=%d/%d" % [
		label, result.state, result.duration, result.generated, result.killed, result.leaked, result.durability,
		result.early_peak, result.late_peak, result.longest_empty,
		result.total_a, result.total_b,
		result.midlate_a, result.midlate_b,
	])
	print("  approach duration A=%.2f..%.2fs B=%.2f..%.2fs" % [a_range.x, a_range.y, b_range.x, b_range.y])
	for record: Dictionary in result.records:
		print_wave_record(record)


func print_wave_record(record: Dictionary) -> void:
	print("  wave%d duration=%.1f plan=%d killed=%d leaked=%d peak=%d A=%d B=%d interrupt=%d downgrade=%d tail=%.1f" % [
		int(record.wave_index) + 1, float(record.duration), int(record.planned),
		int(record.killed), int(record.leaked), int(record.peak_active),
		int(record.completed_a), int(record.completed_b), int(record.interrupted),
		int(record.downgraded), float(record.cleanup_tail),
	])


func check(condition: bool, message: String) -> void:
	check_count += 1
	if not condition:
		failures.append(message)


func observation_duration_range(observations: Array) -> Vector2:
	if observations.is_empty():
		return Vector2.ZERO
	var minimum := INF
	var maximum := 0.0
	for observation: Dictionary in observations:
		var duration := float(observation.get("lock_to_complete_duration", 0.0))
		minimum = minf(minimum, duration)
		maximum = maxf(maximum, duration)
	return Vector2(minimum, maximum)

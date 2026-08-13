extends SceneTree

const SCENE_PATH := "res://prototype/formation_defense/scenes/formation_defense_prototype.tscn"
const CONFIG := preload("res://prototype/formation_defense/data/formation_defense_config.gd")
const WaveDirector := preload("res://prototype/formation_defense/scripts/formation_defense_wave_director.gd")
const SAVE_PATH := "user://adventure_village_save.json"
const STEP := 0.1
const EXPECTED_CHECKS := 20

var failures: Array[String] = []
var check_count := 0


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var game_state := root.get_node_or_null("/root/GameState")
	var game_state_before := snapshot_script_variables(game_state)
	var save_before := snapshot_file(SAVE_PATH)
	var config := CONFIG.get_wave_battle_config(&"v2_5b_validation")
	var point_to_lane := CONFIG.get_spawn_point_lane_map()
	var validation := WaveDirector.validate_battle_config(
		config,
		CONFIG.get_monster_type_ids(),
		point_to_lane,
		CONFIG.get_visual_route_ids()
	)
	check(validation.is_empty(), "1 wave configuration loads and validates")
	check_invalid_config_rejection(config, point_to_lane)

	var due_events: Array[Dictionary] = []
	var direct = WaveDirector.new()
	direct.spawn_requested.connect(func(event: Dictionary) -> void:
		due_events.append(event.duplicate(true))
	)
	direct.configure(
		config,
		CONFIG.get_monster_type_ids(),
		point_to_lane,
		CONFIG.get_visual_route_ids()
	)
	direct.start()
	direct.advance(1.4)
	check(
		due_events.is_empty() and direct.get_state_name() == "COUNTDOWN",
		"2 first wave waits for its countdown"
	)
	direct.advance(0.1)
	check(
		due_events.size() == 1 and is_equal_approx(due_events[0].due_time, 0.0),
		"3 first subwave starts at its configured offset"
	)
	direct.advance(0.69)
	var before_interval_count := due_events.size()
	direct.advance(0.01)
	check(
		before_interval_count == 1 and due_events.size() == 2,
		"4 spawn_interval gates consecutive events"
	)

	var large_delta_events: Array[Dictionary] = []
	var catch_up = WaveDirector.new()
	catch_up.spawn_requested.connect(func(event: Dictionary) -> void:
		large_delta_events.append(event.duplicate(true))
	)
	catch_up.configure(
		config,
		CONFIG.get_monster_type_ids(),
		point_to_lane,
		CONFIG.get_visual_route_ids()
	)
	catch_up.start()
	catch_up.advance(10.0)
	check(
		large_delta_events.size() == 2
			and catch_up.get_state_name() == "CLEANUP",
		"5 a large delta emits every due event without loss"
	)

	var packed := load(SCENE_PATH) as PackedScene
	var controller = packed.instantiate()
	root.add_child(controller)
	await process_frame
	await process_frame
	controller.set_automatic_simulation(false)
	controller.select_scenario(&"wave_validation")
	controller.apply_recommended_deployment()
	controller.start_battle()
	controller.simulate_step(1.5)
	controller.simulate_step(0.7)
	var cleanup_snapshot: Dictionary = controller.get_wave_snapshot()
	var configured_health_applied: bool = not controller.active_enemies.is_empty()
	for enemy in controller.active_enemies.values():
		configured_health_applied = configured_health_applied and enemy.max_health == 100
	check(
		configured_health_applied,
		"6a wave group max_health reaches the existing enemy spawn configuration"
	)
	check(
		cleanup_snapshot.state == "CLEANUP"
			and int(cleanup_snapshot.current_wave_generated) == 2
			and controller.battle_state == controller.BattleState.RUNNING,
		"6 an uncleared wave blocks the next wave and early victory"
	)

	controller.restart_battle()
	var first_run := run_full_battle(controller, false)
	check(
		first_run.final_state == "VICTORY"
			and int(first_run.wave.total_waves) == 3
			and int(first_run.wave.total_generated) == 12
			and int(first_run.wave.total_resolved) == 12,
		"7 three configured waves finish only after final cleanup"
	)
	check(
		first_run.states.has("COUNTDOWN")
			and first_run.states.has("SPAWNING")
			and first_run.states.has("CLEANUP")
			and first_run.wave.state == "COMPLETED",
		"8 director exposes the complete state flow"
	)
	check(
		int(first_run.formation_stats.get("completed_a_count", 0)) > 0,
		"8a increased wave health leaves an observable formation window"
	)
	check_trace_offsets_and_overlap(first_run.trace)
	check_trace_constraints(first_run.trace, point_to_lane)
	check(
		first_run.hud_countdown
			and first_run.hud_spawning
			and first_run.hud_cleanup
			and "全部波次完成" in String(first_run.final_hud),
		"11 compact HUD covers countdown, spawning, cleanup and completion"
	)

	controller.restart_battle()
	var reset_snapshot: Dictionary = controller.get_wave_snapshot()
	check(
		reset_snapshot.state == "COUNTDOWN"
			and int(reset_snapshot.total_generated) == 0
			and Array(reset_snapshot.spawn_trace).is_empty()
			and controller.active_enemies.is_empty()
			and controller.get_attack_visual_snapshots().is_empty(),
		"12 restart resets runtime, statistics, HUD sources and visuals"
	)
	var second_run := run_full_battle(controller, true)
	check(
		first_run.trace == second_run.trace
			and is_equal_approx(float(first_run.duration), float(second_run.duration))
			and second_run.final_state == "VICTORY",
		"13 fixed seed reproduces the exact trace while toggling debug UI"
	)

	controller.restart_battle()
	controller.simulate_step(1.5)
	var failure_enemy = controller.active_enemies.values()[0]
	controller.village_durability = 1
	controller.handle_enemy_arrival(
		failure_enemy.runtime_id,
		failure_enemy.route_id,
		1
	)
	var trace_size_after_failure: int = controller.get_wave_snapshot().spawn_trace.size()
	controller.simulate_step(20.0)
	check(
		controller.get_state_name() == "DEFEAT"
			and controller.get_wave_snapshot().state == "STOPPED"
			and controller.get_wave_snapshot().spawn_trace.size()
				== trace_size_after_failure
			and controller.active_enemies.is_empty(),
		"14 defeat cancels pending events and prevents delayed spawning"
	)

	controller.restart_battle()
	var clean_restart: Dictionary = controller.get_wave_snapshot()
	check(
		int(clean_restart.pending_event_count) == 0
			and int(clean_restart.tracked_enemy_count) == 0
			and controller.wave_director.find_children("*", "Timer", true, false).is_empty(),
		"15 restart leaves no Timer, delayed callback or previous-run event"
	)
	check(
		first_run.duration > 0.0 and first_run.duration < 120.0,
		"16 validation battle remains a short structural demonstration"
	)
	check(
		snapshot_script_variables(game_state) == game_state_before
			and snapshot_file(SAVE_PATH) == save_before,
		"17 wave runs do not change GameState or the formal save"
	)

	print(
		"v2-5b run: state=%s duration=%.1fs generated=%d trace_equal=%s" % [
			first_run.final_state,
			float(first_run.duration),
			int(first_run.wave.total_generated),
			str(first_run.trace == second_run.trace),
		]
	)
	controller.queue_free()
	direct.queue_free()
	catch_up.queue_free()
	await process_frame
	if check_count != EXPECTED_CHECKS:
		failures.append("coverage count %d != %d" % [check_count, EXPECTED_CHECKS])
	if failures.is_empty():
		print("v2-5b wave schedule smoke ok: 20 requirements")
		quit(0)
	else:
		push_error("v2-5b wave schedule smoke failed: %s" % "; ".join(failures))
		quit(1)


func run_full_battle(controller, toggle_debug: bool) -> Dictionary:
	var states: Dictionary = {}
	var hud_countdown := false
	var hud_spawning := false
	var hud_cleanup := false
	var steps := 0
	while controller.battle_state == controller.BattleState.RUNNING and steps < 1200:
		var wave: Dictionary = controller.get_wave_snapshot()
		states[String(wave.get("state", ""))] = true
		var hud := String(controller.compact_wave_label.text)
		hud_countdown = hud_countdown or "下一波" in hud
		hud_spawning = hud_spawning or "本波生成中" in hud
		hud_cleanup = hud_cleanup or "清理剩余敌人" in hud
		if toggle_debug and steps % 13 == 0:
			controller.set_debug_panel_open(not controller.debug_panel_open)
		controller.simulate_step(STEP)
		steps += 1
	var final_wave: Dictionary = controller.get_wave_snapshot()
	var battle_snapshot: Dictionary = controller.get_battle_snapshot()
	states[String(final_wave.get("state", ""))] = true
	return {
		"final_state": controller.get_state_name(),
		"duration": controller.battle_elapsed,
		"wave": final_wave,
		"formation_stats": battle_snapshot.get("formation_stats", {}).duplicate(true),
		"trace": sanitize_trace(final_wave.get("spawn_trace", [])),
		"states": states,
		"hud_countdown": hud_countdown,
		"hud_spawning": hud_spawning,
		"hud_cleanup": hud_cleanup,
		"final_hud": controller.compact_wave_label.text,
	}


func sanitize_trace(raw_trace: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_entry: Dictionary in raw_trace:
		result.append({
			"wave_index": int(raw_entry.get("wave_index", -1)),
			"subwave_index": int(raw_entry.get("subwave_index", -1)),
			"group_index": int(raw_entry.get("group_index", -1)),
			"item_index": int(raw_entry.get("item_index", -1)),
			"due_time": float(raw_entry.get("due_time", -1.0)),
			"enemy_profile_id": StringName(raw_entry.get("enemy_profile_id", &"")),
			"max_health": int(raw_entry.get("max_health", 0)),
			"spawn_point_id": StringName(raw_entry.get("spawn_point_id", &"")),
			"route_id": StringName(raw_entry.get("route_id", &"")),
			"allowed_spawn_points": raw_entry.get("allowed_spawn_points", []).duplicate(),
			"allowed_lanes": raw_entry.get("allowed_lanes", []).duplicate(),
		})
	return result


func check_invalid_config_rejection(
	valid_config: Dictionary,
	point_to_lane: Dictionary
) -> void:
	var invalid := valid_config.duplicate(true)
	invalid.waves[1].wave_id = invalid.waves[0].wave_id
	invalid.waves[0].subwaves[0].spawn_groups[0].count = 0
	invalid.waves[1].subwaves[0].spawn_groups[0].max_health = 0
	invalid.waves[0].subwaves[0].start_offset = -1.0
	invalid.waves[0].subwaves[0].spawn_groups[0].spawn_interval = -0.5
	invalid.waves[0].subwaves[0].spawn_groups[0].enemy_profile_id = &"missing"
	invalid.waves[0].subwaves[0].spawn_groups[0].allowed_spawn_points = [&"missing"]
	invalid.waves[0].subwaves[0].spawn_groups[0].allowed_lanes = [&"missing"]
	invalid.waves[2].subwaves = []
	var errors := WaveDirector.validate_battle_config(
		invalid,
		CONFIG.get_monster_type_ids(),
		point_to_lane,
		CONFIG.get_visual_route_ids()
	)
	check(errors.size() >= 9, "1b invalid wave definitions fail early with detailed errors")


func check_trace_offsets_and_overlap(trace: Array[Dictionary]) -> void:
	var wave_two_subwaves: Dictionary = {}
	var overlap_pair_ok := false
	for index in range(trace.size()):
		var event: Dictionary = trace[index]
		if int(event.wave_index) == 1:
			wave_two_subwaves[int(event.subwave_index)] = true
		if index + 1 < trace.size():
			var next: Dictionary = trace[index + 1]
			overlap_pair_ok = overlap_pair_ok or (
				int(event.wave_index) == 2
				and int(next.wave_index) == 2
				and is_equal_approx(float(event.due_time), float(next.due_time))
				and int(event.group_index) < int(next.group_index)
			)
	check(
		wave_two_subwaves.size() == 2 and overlap_pair_ok,
		"9 offset subwaves and overlapping groups use stable event ordering"
	)


func check_trace_constraints(
	trace: Array[Dictionary],
	point_to_lane: Dictionary
) -> void:
	var valid := true
	for event: Dictionary in trace:
		var point_id := StringName(event.spawn_point_id)
		var lane_id := StringName(event.route_id)
		var allowed_points: Array = event.allowed_spawn_points
		var allowed_lanes: Array = event.allowed_lanes
		valid = valid \
			and point_to_lane.has(point_id) \
			and StringName(point_to_lane[point_id]) == lane_id \
			and (allowed_points.is_empty() or allowed_points.has(point_id)) \
			and (allowed_lanes.is_empty() or allowed_lanes.has(lane_id)) \
			and CONFIG.get_monster_type_ids().has(
				StringName(event.enemy_profile_id)
			)
	check(valid, "10 every event respects configured profiles, spawn points and lanes")


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
		return null if value == null else {
			"class": value.get_class(),
			"id": value.get_instance_id(),
		}
	return value


func snapshot_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"exists": false}
	var content := FileAccess.get_file_as_bytes(path)
	return {
		"exists": true,
		"length": content.size(),
		"hash": hash(content),
		"modified": FileAccess.get_modified_time(path),
	}


func check(condition: bool, label: String) -> void:
	check_count += 1
	if condition:
		return
	failures.append(label)
	push_error(label)

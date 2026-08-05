extends Node

signal spawn_requested(spawn_event: Dictionary)

enum State {
	IDLE,
	COUNTDOWN,
	SPAWNING,
	CLEANUP,
	COMPLETED,
	STOPPED,
}

const STATE_NAMES := {
	State.IDLE: "IDLE",
	State.COUNTDOWN: "COUNTDOWN",
	State.SPAWNING: "SPAWNING",
	State.CLEANUP: "CLEANUP",
	State.COMPLETED: "COMPLETED",
	State.STOPPED: "STOPPED",
}
const PRESSURE_SAMPLE_INTERVAL := 5.0

var state: State = State.IDLE
var battle_config: Dictionary = {}
var validation_errors: PackedStringArray = []
var valid_enemy_profile_ids: Array[StringName] = []
var spawn_point_to_lane: Dictionary = {}
var valid_lane_ids: Array[StringName] = []
var rng := RandomNumberGenerator.new()

var battle_time := 0.0
var state_elapsed := 0.0
var wave_elapsed := 0.0
var countdown_remaining := 0.0
var current_wave_index := -1
var pending_wave_index := 0
var scheduled_events: Array[Dictionary] = []
var next_event_index := 0
var triggered_subwaves: Dictionary = {}
var runtime_enemy_wave: Dictionary = {}
var spawn_trace: Array[Dictionary] = []

var total_planned := 0
var total_generated := 0
var total_resolved := 0
var total_killed := 0
var total_leaked := 0
var current_wave_planned := 0
var current_wave_generated := 0
var current_wave_resolved := 0
var current_wave_killed := 0
var current_wave_leaked := 0
var wave_records: Array[Dictionary] = []
var pressure_samples: Array[Dictionary] = []
var max_active_enemy_count := 0
var longest_non_countdown_empty_time := 0.0
var current_non_countdown_empty_time := 0.0
var next_pressure_sample_time := PRESSURE_SAMPLE_INTERVAL
var telemetry_wave_index := -1
var telemetry_formation_baseline: Dictionary = {}
var final_village_durability := -1


func configure(
	new_battle_config: Dictionary,
	new_valid_enemy_profile_ids: Array[StringName],
	new_spawn_point_to_lane: Dictionary,
	new_valid_lane_ids: Array[StringName]
) -> bool:
	battle_config = new_battle_config.duplicate(true)
	valid_enemy_profile_ids = new_valid_enemy_profile_ids.duplicate()
	spawn_point_to_lane = new_spawn_point_to_lane.duplicate(true)
	valid_lane_ids = new_valid_lane_ids.duplicate()
	validation_errors = validate_battle_config(
		battle_config,
		valid_enemy_profile_ids,
		spawn_point_to_lane,
		valid_lane_ids
	)
	reset_runtime()
	return validation_errors.is_empty()


func clear_configuration() -> void:
	battle_config.clear()
	validation_errors = PackedStringArray()
	reset_runtime()


func reset_runtime() -> void:
	state = State.IDLE
	battle_time = 0.0
	state_elapsed = 0.0
	wave_elapsed = 0.0
	countdown_remaining = 0.0
	current_wave_index = -1
	pending_wave_index = 0
	scheduled_events.clear()
	next_event_index = 0
	triggered_subwaves.clear()
	runtime_enemy_wave.clear()
	spawn_trace.clear()
	total_planned = count_planned_enemies(battle_config)
	total_generated = 0
	total_resolved = 0
	total_killed = 0
	total_leaked = 0
	reset_current_wave_stats()
	wave_records = build_wave_records(battle_config)
	pressure_samples.clear()
	max_active_enemy_count = 0
	longest_non_countdown_empty_time = 0.0
	current_non_countdown_empty_time = 0.0
	next_pressure_sample_time = PRESSURE_SAMPLE_INTERVAL
	telemetry_wave_index = -1
	telemetry_formation_baseline.clear()
	final_village_durability = -1
	rng.seed = int(battle_config.get("random_seed", 1))


func start() -> bool:
	if not validation_errors.is_empty() or battle_config.is_empty():
		return false
	reset_runtime()
	pending_wave_index = 0
	begin_countdown(maxf(0.0, float(battle_config.get("initial_countdown", 0.0))))
	resolve_zero_countdown()
	return true


func stop() -> void:
	state = State.STOPPED
	state_elapsed = 0.0
	scheduled_events.clear()
	next_event_index = 0
	triggered_subwaves.clear()
	runtime_enemy_wave.clear()


func advance(delta: float) -> void:
	if state in [State.IDLE, State.COMPLETED, State.STOPPED]:
		return
	var remaining := maxf(0.0, delta)
	battle_time += remaining
	while remaining > 0.000001:
		if state == State.COUNTDOWN:
			var consumed := minf(remaining, countdown_remaining)
			countdown_remaining = maxf(0.0, countdown_remaining - consumed)
			state_elapsed += consumed
			remaining -= consumed
			if countdown_remaining <= 0.000001:
				start_wave(pending_wave_index)
				process_due_spawn_events()
				continue
			break
		if state == State.SPAWNING:
			wave_elapsed += remaining
			state_elapsed += remaining
			remaining = 0.0
			process_due_spawn_events()
			break
		if state == State.CLEANUP:
			state_elapsed += remaining
			remaining = 0.0
			break
		break


func begin_countdown(duration: float) -> void:
	state = State.COUNTDOWN
	state_elapsed = 0.0
	countdown_remaining = maxf(0.0, duration)
	triggered_subwaves.clear()
	if pending_wave_index != current_wave_index:
		reset_current_wave_stats()
		var waves: Array = battle_config.get("waves", [])
		if pending_wave_index >= 0 and pending_wave_index < waves.size():
			current_wave_planned = count_wave_enemies(waves[pending_wave_index])


func resolve_zero_countdown() -> void:
	if state == State.COUNTDOWN and countdown_remaining <= 0.000001:
		start_wave(pending_wave_index)
		process_due_spawn_events()


func start_wave(wave_index: int) -> void:
	var waves: Array = battle_config.get("waves", [])
	if wave_index < 0 or wave_index >= waves.size():
		state = State.COMPLETED
		return
	current_wave_index = wave_index
	wave_elapsed = 0.0
	state_elapsed = 0.0
	triggered_subwaves.clear()
	next_event_index = 0
	reset_current_wave_stats()
	scheduled_events = build_wave_events(waves[wave_index], wave_index)
	current_wave_planned = scheduled_events.size()
	var record := get_wave_record(wave_index)
	if not record.is_empty():
		record["start_time"] = battle_time
		record["planned"] = current_wave_planned
	state = State.SPAWNING


func process_due_spawn_events() -> void:
	while (
		state == State.SPAWNING
		and next_event_index < scheduled_events.size()
		and float(scheduled_events[next_event_index].get("due_time", INF))
			<= wave_elapsed + 0.000001
	):
		var event := scheduled_events[next_event_index].duplicate(true)
		next_event_index += 1
		resolve_spawn_selection(event)
		triggered_subwaves[int(event.get("subwave_index", -1))] = true
		total_generated += 1
		current_wave_generated += 1
		var record := get_wave_record(int(event.get("wave_index", current_wave_index)))
		if not record.is_empty():
			record["generated"] = int(record.get("generated", 0)) + 1
			record["last_spawn_time"] = battle_time
		var trace_entry := event.duplicate(true)
		trace_entry["global_spawn_sequence"] = total_generated
		trace_entry["emitted_battle_time"] = battle_time
		spawn_trace.append(trace_entry)
		spawn_requested.emit(event)
	if state == State.SPAWNING and next_event_index >= scheduled_events.size():
		state = State.CLEANUP
		state_elapsed = 0.0
		complete_current_wave_if_ready()


func register_spawned_enemy(runtime_id: StringName, spawn_event: Dictionary) -> void:
	if runtime_id == &"":
		return
	runtime_enemy_wave[runtime_id] = int(
		spawn_event.get("wave_index", current_wave_index)
	)


func notify_enemy_resolved(runtime_id: StringName, outcome: StringName) -> void:
	if not runtime_enemy_wave.has(runtime_id):
		return
	var wave_index := int(runtime_enemy_wave[runtime_id])
	runtime_enemy_wave.erase(runtime_id)
	total_resolved += 1
	if outcome == &"KILLED":
		total_killed += 1
	else:
		total_leaked += 1
	if wave_index == current_wave_index:
		current_wave_resolved += 1
		if outcome == &"KILLED":
			current_wave_killed += 1
		else:
			current_wave_leaked += 1
	var record := get_wave_record(wave_index)
	if not record.is_empty():
		record["resolved"] = int(record.get("resolved", 0)) + 1
		if outcome == &"KILLED":
			record["killed"] = int(record.get("killed", 0)) + 1
		else:
			record["leaked"] = int(record.get("leaked", 0)) + 1
	complete_current_wave_if_ready()


func complete_current_wave_if_ready() -> void:
	if state != State.CLEANUP:
		return
	if current_wave_generated < current_wave_planned:
		return
	if current_wave_resolved < current_wave_planned:
		return
	var record := get_wave_record(current_wave_index)
	if not record.is_empty():
		record["end_time"] = battle_time
		record["duration"] = battle_time - float(record.get("start_time", battle_time))
		var last_spawn_time := float(record.get("last_spawn_time", battle_time))
		record["cleanup_tail"] = maxf(0.0, battle_time - last_spawn_time)
	var waves: Array = battle_config.get("waves", [])
	if current_wave_index >= waves.size() - 1:
		state = State.COMPLETED
		state_elapsed = 0.0
		return
	pending_wave_index = current_wave_index + 1
	begin_countdown(maxf(0.0, float(battle_config.get("inter_wave_delay", 0.0))))
	resolve_zero_countdown()


func record_battle_telemetry(
	delta: float,
	active_enemy_count: int,
	formation_stats: Dictionary,
	village_durability: int
) -> void:
	final_village_durability = village_durability
	max_active_enemy_count = maxi(max_active_enemy_count, active_enemy_count)
	if state in [State.SPAWNING, State.CLEANUP] and active_enemy_count == 0:
		current_non_countdown_empty_time += maxf(0.0, delta)
		longest_non_countdown_empty_time = maxf(
			longest_non_countdown_empty_time,
			current_non_countdown_empty_time
		)
	else:
		current_non_countdown_empty_time = 0.0
	while battle_time + 0.000001 >= next_pressure_sample_time:
		pressure_samples.append({
			"time": next_pressure_sample_time,
			"active": active_enemy_count,
			"wave_index": current_wave_index,
		})
		next_pressure_sample_time += PRESSURE_SAMPLE_INTERVAL
	if current_wave_index < 0:
		return
	if telemetry_wave_index != current_wave_index:
		telemetry_wave_index = current_wave_index
		telemetry_formation_baseline = extract_formation_totals(formation_stats)
	var record := get_wave_record(current_wave_index)
	if record.is_empty():
		return
	record["peak_active"] = maxi(int(record.get("peak_active", 0)), active_enemy_count)
	if state == State.CLEANUP and active_enemy_count == 1:
		record["single_enemy_tail_time"] = float(
			record.get("single_enemy_tail_time", 0.0)
		) + maxf(0.0, delta)
	elif active_enemy_count > 1:
		record["single_enemy_tail_time"] = 0.0
	var totals := extract_formation_totals(formation_stats)
	for key: StringName in [&"completed_a", &"completed_b", &"interrupted", &"downgraded"]:
		record[key] = maxi(
			0,
			int(totals.get(key, 0)) - int(telemetry_formation_baseline.get(key, 0))
		)


func get_pacing_snapshot() -> Dictionary:
	return {
		"battle_time": battle_time,
		"wave_records": wave_records.duplicate(true),
		"pressure_samples": pressure_samples.duplicate(true),
		"max_active_enemy_count": max_active_enemy_count,
		"longest_non_countdown_empty_time": longest_non_countdown_empty_time,
		"recent_pressure_sample": (
			pressure_samples[-1].duplicate(true) if not pressure_samples.is_empty() else {}
		),
		"final_village_durability": final_village_durability,
	}


func build_wave_events(wave: Dictionary, wave_index: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var stable_order := 0
	var subwaves: Array = wave.get("subwaves", [])
	for subwave_index in range(subwaves.size()):
		var subwave: Dictionary = subwaves[subwave_index]
		var start_offset := float(subwave.get("start_offset", 0.0))
		var groups: Array = subwave.get("spawn_groups", [])
		for group_index in range(groups.size()):
			var group: Dictionary = groups[group_index]
			var profile_id := StringName(group.get("enemy_profile_id", &""))
			var profile_overrides: Dictionary = Dictionary(
				battle_config.get("enemy_profile_overrides", {})
			).get(profile_id, {})
			var count := int(group.get("count", 0))
			var interval := float(group.get("spawn_interval", 0.0))
			for item_index in range(count):
				events.append({
					"wave_index": wave_index,
					"wave_id": StringName(wave.get("wave_id", &"")),
					"subwave_index": subwave_index,
					"group_index": group_index,
					"item_index": item_index,
					"stable_order": stable_order,
					"due_time": start_offset + interval * float(item_index),
					"enemy_profile_id": profile_id,
					"max_health": int(group.get("max_health", profile_overrides.get("max_health", 0))),
					"move_speed": float(group.get("move_speed", profile_overrides.get("move_speed", 0.0))),
					"allowed_spawn_points": group.get("allowed_spawn_points", []).duplicate(),
					"allowed_lanes": group.get("allowed_lanes", []).duplicate(),
					"selection_mode": StringName(group.get("selection_mode", &"random")),
				})
				stable_order += 1
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var time_a := float(a.get("due_time", 0.0))
		var time_b := float(b.get("due_time", 0.0))
		if not is_equal_approx(time_a, time_b):
			return time_a < time_b
		return int(a.get("stable_order", 0)) < int(b.get("stable_order", 0))
	)
	return events


func resolve_spawn_selection(event: Dictionary) -> void:
	var candidates := get_spawn_candidates(event)
	if candidates.is_empty():
		event["spawn_point_id"] = &""
		event["route_id"] = &""
		return
	var selection_mode := StringName(event.get("selection_mode", &"random"))
	var selected_index := 0
	if selection_mode == &"random":
		selected_index = rng.randi_range(0, candidates.size() - 1)
	elif selection_mode == &"round_robin":
		selected_index = int(event.get("item_index", 0)) % candidates.size()
	var selected: Dictionary = candidates[selected_index]
	event["spawn_point_id"] = StringName(selected.get("spawn_point_id", &""))
	event["route_id"] = StringName(selected.get("route_id", &""))


func get_spawn_candidates(event: Dictionary) -> Array[Dictionary]:
	var allowed_points: Array = event.get("allowed_spawn_points", [])
	var allowed_lanes: Array = event.get("allowed_lanes", [])
	var point_ids: Array[StringName] = []
	if allowed_points.is_empty():
		for point_id in spawn_point_to_lane.keys():
			point_ids.append(StringName(point_id))
	else:
		for point_id in allowed_points:
			point_ids.append(StringName(point_id))
	point_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b)
	)
	var result: Array[Dictionary] = []
	for point_id: StringName in point_ids:
		var lane_id := StringName(spawn_point_to_lane.get(point_id, &""))
		if lane_id == &"":
			continue
		if not allowed_lanes.is_empty() and not allowed_lanes.has(lane_id):
			continue
		result.append({"spawn_point_id": point_id, "route_id": lane_id})
	return result


func get_snapshot() -> Dictionary:
	var waves: Array = battle_config.get("waves", [])
	var next_event_time := -1.0
	if state == State.COUNTDOWN:
		next_event_time = countdown_remaining
	elif state == State.SPAWNING and next_event_index < scheduled_events.size():
		next_event_time = maxf(
			0.0,
			float(scheduled_events[next_event_index].get("due_time", 0.0)) - wave_elapsed
		)
	return {
		"state": get_state_name(),
		"battle_id": StringName(battle_config.get("battle_id", &"")),
		"battle_time": battle_time,
		"state_elapsed": state_elapsed,
		"wave_elapsed": wave_elapsed,
		"countdown_remaining": countdown_remaining,
		"current_wave_index": current_wave_index,
		"display_wave_number": (
			pending_wave_index + 1 if state == State.COUNTDOWN else current_wave_index + 1
		),
		"total_waves": waves.size(),
		"triggered_subwave_count": triggered_subwaves.size(),
		"total_subwaves_current": get_current_subwave_count(),
		"next_event_time": next_event_time,
		"current_wave_planned": current_wave_planned,
		"current_wave_generated": current_wave_generated,
		"current_wave_active": maxi(0, current_wave_generated - current_wave_resolved),
		"current_wave_resolved": current_wave_resolved,
		"current_wave_killed": current_wave_killed,
		"current_wave_leaked": current_wave_leaked,
		"total_planned": total_planned,
		"total_generated": total_generated,
		"total_resolved": total_resolved,
		"total_killed": total_killed,
		"total_leaked": total_leaked,
		"pending_event_count": maxi(0, scheduled_events.size() - next_event_index),
		"tracked_enemy_count": runtime_enemy_wave.size(),
		"spawn_trace": spawn_trace.duplicate(true),
		"validation_errors": validation_errors.duplicate(),
		"current_wave_display_name": get_wave_display_name(
			pending_wave_index if state == State.COUNTDOWN else current_wave_index
		),
		"pacing": get_pacing_snapshot(),
	}


func get_hud_text() -> String:
	var snapshot := get_snapshot()
	var wave_text := "波次：%d/%d" % [
		int(snapshot.display_wave_number),
		int(snapshot.total_waves),
	]
	var wave_name := get_wave_display_name(
		pending_wave_index if state == State.COUNTDOWN else current_wave_index
	)
	if not wave_name.is_empty():
		wave_text += "　%s" % wave_name
	match state:
		State.COUNTDOWN:
			return "%s｜下一波：%.1f秒" % [wave_text, countdown_remaining]
		State.SPAWNING:
			return "%s｜本波生成中" % wave_text
		State.CLEANUP:
			return "%s｜清理剩余敌人：%d" % [
				wave_text,
				maxi(0, current_wave_generated - current_wave_resolved),
			]
		State.COMPLETED:
			return "全部波次完成"
		State.STOPPED:
			return "波次调度已停止"
	return "波次：等待开始"


func get_state_name() -> String:
	return String(STATE_NAMES.get(state, "UNKNOWN"))


func get_current_subwave_count() -> int:
	var waves: Array = battle_config.get("waves", [])
	var index := current_wave_index
	if state == State.COUNTDOWN:
		index = pending_wave_index
	if index < 0 or index >= waves.size():
		return 0
	return Array(waves[index].get("subwaves", [])).size()


func reset_current_wave_stats() -> void:
	current_wave_planned = 0
	current_wave_generated = 0
	current_wave_resolved = 0
	current_wave_killed = 0
	current_wave_leaked = 0


func get_wave_display_name(wave_index: int) -> String:
	var waves: Array = battle_config.get("waves", [])
	if wave_index < 0 or wave_index >= waves.size():
		return ""
	return String(Dictionary(waves[wave_index]).get("display_name", ""))


func get_wave_record(wave_index: int) -> Dictionary:
	if wave_index < 0 or wave_index >= wave_records.size():
		return {}
	return wave_records[wave_index]


static func build_wave_records(config: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var waves: Array = config.get("waves", [])
	for wave_index in range(waves.size()):
		var wave: Dictionary = waves[wave_index]
		result.append({
			"wave_index": wave_index,
			"wave_id": StringName(wave.get("wave_id", &"")),
			"display_name": String(wave.get("display_name", "")),
			"planned": count_wave_enemies(wave),
			"generated": 0,
			"resolved": 0,
			"killed": 0,
			"leaked": 0,
			"peak_active": 0,
			"completed_a": 0,
			"completed_b": 0,
			"interrupted": 0,
			"downgraded": 0,
			"start_time": -1.0,
			"last_spawn_time": -1.0,
			"end_time": -1.0,
			"duration": 0.0,
			"cleanup_tail": 0.0,
			"single_enemy_tail_time": 0.0,
		})
	return result


static func extract_formation_totals(stats: Dictionary) -> Dictionary:
	return {
		"completed_a": int(stats.get("completed_a_count", 0)),
		"completed_b": int(stats.get("completed_b_count", 0)),
		"interrupted": int(stats.get("interrupted_count", 0)),
		"downgraded": int(stats.get("downgrade_count", 0)),
	}


static func count_planned_enemies(config: Dictionary) -> int:
	var total := 0
	for wave: Dictionary in config.get("waves", []):
		total += count_wave_enemies(wave)
	return total


static func count_wave_enemies(wave: Dictionary) -> int:
	var total := 0
	for subwave: Dictionary in wave.get("subwaves", []):
		for group: Dictionary in subwave.get("spawn_groups", []):
			total += maxi(0, int(group.get("count", 0)))
	return total


static func validate_battle_config(
	config: Dictionary,
	valid_profiles: Array[StringName],
	point_to_lane: Dictionary,
	valid_lanes: Array[StringName]
) -> PackedStringArray:
	var errors := PackedStringArray()
	if StringName(config.get("battle_id", &"")) == &"":
		errors.append("battle_id is required")
	if float(config.get("initial_countdown", 0.0)) < 0.0:
		errors.append("initial_countdown must be non-negative")
	if float(config.get("inter_wave_delay", 0.0)) < 0.0:
		errors.append("inter_wave_delay must be non-negative")
	if config.has("formation_approach_speed") and float(config.formation_approach_speed) <= 0.0:
		errors.append("formation_approach_speed must be greater than zero")
	if config.has("formation_completion_tolerance") and float(config.formation_completion_tolerance) <= 0.0:
		errors.append("formation_completion_tolerance must be greater than zero")
	if config.has("formation_duration_multiplier") and float(config.formation_duration_multiplier) < 0.0:
		errors.append("formation_duration_multiplier must be non-negative")
	for raw_profile_id in Dictionary(config.get("enemy_profile_overrides", {})).keys():
		var profile_id := StringName(raw_profile_id)
		var profile: Dictionary = config.enemy_profile_overrides[raw_profile_id]
		if not valid_profiles.has(profile_id):
			errors.append("enemy_profile_overrides references unknown profile %s" % profile_id)
		if profile.has("max_health") and int(profile.max_health) <= 0:
			errors.append("profile %s max_health must be greater than zero" % profile_id)
		if profile.has("move_speed") and float(profile.move_speed) <= 0.0:
			errors.append("profile %s move_speed must be greater than zero" % profile_id)
	var waves: Array = config.get("waves", [])
	if waves.is_empty():
		errors.append("battle must contain at least one wave")
	var wave_ids: Dictionary = {}
	for wave_index in range(waves.size()):
		var wave: Dictionary = waves[wave_index]
		var wave_id := StringName(wave.get("wave_id", &""))
		if wave_id == &"":
			errors.append("wave %d has no wave_id" % wave_index)
		elif wave_ids.has(wave_id):
			errors.append("duplicate wave_id: %s" % String(wave_id))
		else:
			wave_ids[wave_id] = true
		var subwaves: Array = wave.get("subwaves", [])
		if subwaves.is_empty():
			errors.append("wave %s has no subwaves" % String(wave_id))
		for subwave_index in range(subwaves.size()):
			var subwave: Dictionary = subwaves[subwave_index]
			if float(subwave.get("start_offset", 0.0)) < 0.0:
				errors.append("wave %s subwave %d has negative start_offset" % [wave_id, subwave_index])
			var groups: Array = subwave.get("spawn_groups", [])
			if groups.is_empty():
				errors.append("wave %s subwave %d has no spawn_groups" % [wave_id, subwave_index])
			for group_index in range(groups.size()):
				var group: Dictionary = groups[group_index]
				var prefix := "wave %s subwave %d group %d" % [wave_id, subwave_index, group_index]
				if int(group.get("count", 0)) <= 0:
					errors.append("%s count must be greater than zero" % prefix)
				if float(group.get("spawn_interval", 0.0)) < 0.0:
					errors.append("%s spawn_interval must be non-negative" % prefix)
				if group.has("max_health") and int(group.get("max_health", 0)) <= 0:
					errors.append("%s max_health must be greater than zero" % prefix)
				var profile_id := StringName(group.get("enemy_profile_id", &""))
				if not valid_profiles.has(profile_id):
					errors.append("%s references unknown enemy_profile_id %s" % [prefix, profile_id])
				var allowed_points: Array = group.get("allowed_spawn_points", [])
				for point_id in allowed_points:
					if not point_to_lane.has(StringName(point_id)):
						errors.append("%s references unknown spawn point %s" % [prefix, point_id])
				var allowed_group_lanes: Array = group.get("allowed_lanes", [])
				for lane_id in allowed_group_lanes:
					if not valid_lanes.has(StringName(lane_id)):
						errors.append("%s references unknown lane %s" % [prefix, lane_id])
				if not has_eligible_spawn_candidate(group, point_to_lane):
					errors.append("%s cannot resolve any spawn candidate" % prefix)
	return errors


static func has_eligible_spawn_candidate(
	group: Dictionary,
	point_to_lane: Dictionary
) -> bool:
	var allowed_points: Array = group.get("allowed_spawn_points", [])
	var allowed_lanes: Array = group.get("allowed_lanes", [])
	for raw_point_id in point_to_lane.keys():
		var point_id := StringName(raw_point_id)
		var lane_id := StringName(point_to_lane[raw_point_id])
		if not allowed_points.is_empty() and not allowed_points.has(point_id):
			continue
		if not allowed_lanes.is_empty() and not allowed_lanes.has(lane_id):
			continue
		return true
	return false

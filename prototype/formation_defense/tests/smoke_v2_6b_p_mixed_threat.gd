extends SceneTree

const SCENE_PATH := "res://prototype/formation_defense/scenes/formation_defense_prototype.tscn"
const CONFIG := preload("res://prototype/formation_defense/data/formation_defense_config.gd")
const WaveDirector := preload("res://prototype/formation_defense/scripts/formation_defense_wave_director.gd")
const STEP := 0.1
const RUSH_REACTION_DELAY := 0.4
const FORMATION_REACTION_DELAY := 0.5
const MAX_STEPS := 2600

const MODE_UNATTENDED: StringName = &"UNATTENDED"
const MODE_RUSH_ONLY: StringName = &"RUSH_ONLY"
const MODE_FORMATION_ONLY: StringName = &"FORMATION_ONLY"
const MODE_DYNAMIC: StringName = &"DYNAMIC"

const STANDARD_DEPLOYMENT := {
	&"guard": &"middle_c1",
	&"hunter": &"top_c1",
	&"mage": &"bottom_c1",
	&"doctor": &"middle_c2",
}
const FRONT_DEPLOYMENT := {
	&"guard": &"middle_c4",
	&"hunter": &"top_c4",
	&"mage": &"bottom_c4",
	&"doctor": &"middle_c3",
}

var failures: Array[String] = []
var check_count := 0


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var config := CONFIG.get_wave_battle_config(&"v2_6b_mixed_threat_validation")
	var validation := WaveDirector.validate_battle_config(
		config,
		CONFIG.get_monster_type_ids(),
		CONFIG.get_spawn_point_lane_map(),
		CONFIG.get_visual_route_ids()
	)
	check(validation.is_empty(), "V2-6B-P mixed battle configuration validates")
	check(
		StringName(config.get("battle_id", &"")) == &"v2_6b_mixed_threat_validation"
			and int(config.get("random_seed", 0)) == 2603,
		"mixed validation owns an independent battle ID and fixed seed"
	)
	var wave_counts: Array[int] = []
	for wave: Dictionary in config.get("waves", []):
		wave_counts.append(WaveDirector.count_wave_enemies(wave))
	check(wave_counts == [2, 1, 7, 13], "four mixed waves plan 2, 1, 7 and 13 enemies")
	check(
		count_profile_in_battle(config, &"formation_guard") == 16
			and count_profile_in_battle(config, &"rush_raider") == 7
			and battle_uses_only_expected_profiles(config),
		"mixed battle contains exactly the two existing tactical profiles"
	)
	check(
		is_equal_approx(float(config.get("formation_approach_speed", 0.0)), 52.0)
			and is_equal_approx(float(config.get("formation_completion_tolerance", 0.0)), 12.0)
			and is_equal_approx(float(config.get("b_formation_prepare_duration", 0.0)), 3.0),
		"mixed battle reuses the locked V2-6A-P formation tuning"
	)
	var guard_definition := CONFIG.get_monster_definition(&"formation_guard")
	var rush_definition := CONFIG.get_monster_definition(&"rush_raider")
	check(
		int(guard_definition.get("max_health", 0)) == 91
			and is_equal_approx(float(guard_definition.get("move_speed", 0.0)), 42.0)
			and int(rush_definition.get("max_health", 0)) == 91
			and is_equal_approx(float(rush_definition.get("move_speed", 0.0)), 42.0),
		"both enemy profiles retain their accepted health and movement values"
	)
	check(
		bool(rush_definition.get("rush_enabled", false))
			and is_equal_approx(float(rush_definition.get("rush_trigger_progress", 0.0)), 0.48)
			and is_equal_approx(float(rush_definition.get("rush_prepare_duration", 0.0)), 1.25)
			and is_equal_approx(float(rush_definition.get("rush_duration", 0.0)), 3.25)
			and is_equal_approx(float(rush_definition.get("rush_speed_multiplier", 0.0)), 4.0)
			and not bool(rush_definition.get("formation_can_participate", true)),
		"rush profile parameters and formation exclusion remain unchanged"
	)
	check(
		CONFIG.get_recommended_deployment(&"mixed_threat_validation") == STANDARD_DEPLOYMENT,
		"mixed validation uses the established standard reference deployment"
	)
	check(
		&"mixed_threat_validation" in CONFIG.get_scenario_ids()
			and StringName(
				CONFIG.get_scenario(&"mixed_threat_validation").get("wave_battle_id", &"")
			) == &"v2_6b_mixed_threat_validation",
		"existing scenario selector exposes the mixed validation battle"
	)
	check(independent_validation_configs_unchanged(), "V2-6A-P and V2-6B-R configs remain independent and unchanged")

	var unattended_first := await run_validation(MODE_UNATTENDED, false)
	var unattended_second := await run_validation(MODE_UNATTENDED, false)
	var rush_first := await run_validation(MODE_RUSH_ONLY, false)
	var rush_second := await run_validation(MODE_RUSH_ONLY, false)
	var formation_first := await run_validation(MODE_FORMATION_ONLY, false)
	var formation_second := await run_validation(MODE_FORMATION_ONLY, false)
	var dynamic_first := await run_validation(MODE_DYNAMIC, false)
	var dynamic_second := await run_validation(MODE_DYNAMIC, false)
	var front_unattended_first := await run_validation(MODE_UNATTENDED, true)
	var front_unattended_second := await run_validation(MODE_UNATTENDED, true)
	var front_dynamic_first := await run_validation(MODE_DYNAMIC, true)
	var front_dynamic_second := await run_validation(MODE_DYNAMIC, true)

	check(unattended_first == unattended_second, "standard unattended runs are deterministic")
	check(rush_first == rush_second, "standard rush-only runs are deterministic")
	check(formation_first == formation_second, "standard formation-only runs are deterministic")
	check(dynamic_first == dynamic_second, "standard dynamic runs are deterministic")
	check(front_unattended_first == front_unattended_second, "front unattended runs are deterministic")
	check(front_dynamic_first == front_dynamic_second, "front dynamic runs are deterministic")
	check(
		all_traces_match([
			unattended_first, rush_first, formation_first, dynamic_first,
			front_unattended_first, front_dynamic_first,
		]),
		"all strategy and deployment modes share one seed and spawn trace"
	)
	check(
		unattended_first.deployment == STANDARD_DEPLOYMENT
			and dynamic_first.deployment == STANDARD_DEPLOYMENT
			and front_unattended_first.deployment == FRONT_DEPLOYMENT,
		"standard and front deployment signatures match their public slot assignments"
	)
	check(
		unattended_first.generated == 23
			and unattended_first.rush_prepared >= 1
			and unattended_first.rush_rushed >= 1
			and unattended_first.completed_a >= 1
			and unattended_first.completed_b >= 1,
		"unattended mixed battle exercises both real tactical mechanisms"
	)
	check(
		unattended_first.state == "VICTORY"
			and absf(float(unattended_first.duration) - 124.7) <= 0.15
			and unattended_first.killed == 17
			and unattended_first.leaked == 6
			and unattended_first.durability == 4
			and unattended_first.completed_a == 8
			and unattended_first.completed_b == 2
			and unattended_first.rush_leaked == 1
			and unattended_first.guard_leaked == 5,
		"standard unattended outcome is locked to the measured mixed baseline"
	)
	check(
		unattended_first.overlap_windows.size() >= 2
			and unattended_first.overlap_wave_count >= 2,
		"at least two distinct waves contain real formation/rush overlap windows"
	)
	check(
		unattended_first.rush_visual_valid
			and unattended_first.guard_visual_valid
			and unattended_first.saw_simultaneous_visuals,
		"rush warnings and formation feedback remain valid and simultaneously observable"
	)
	check(
		unattended_first.rush_formation_exclusion_valid
			and rush_first.rush_formation_exclusion_valid
			and dynamic_first.rush_formation_exclusion_valid,
		"rush raiders never join A/B groups in the mixed battle"
	)
	check(
		rush_first.rush_focus_calls >= 1
			and rush_first.formation_focus_calls == 0
			and formation_first.formation_focus_calls >= 1
			and formation_first.rush_focus_calls == 0,
		"single-priority strategies issue only their intended public focus commands"
	)
	check(
		rush_first.state == "VICTORY"
			and rush_first.killed == 17
			and rush_first.leaked == 6
			and rush_first.durability == 4
			and rush_first.completed_b == 2
			and rush_first.rush_leaked == 2
			and rush_first.guard_leaked == 4,
		"rush-only focus preserves the measured formation-side opportunity cost"
	)
	check(
		formation_first.state == "VICTORY"
			and formation_first.killed == 18
			and formation_first.leaked == 5
			and formation_first.durability == 5
			and formation_first.completed_b == 0
			and formation_first.rush_leaked == 4
			and formation_first.guard_leaked == 1,
		"formation-only focus preserves the measured rush-side opportunity cost"
	)
	check(
		dynamic_first.rush_focus_calls >= 1
			and dynamic_first.formation_focus_calls >= 2
			and dynamic_first.command_switch_count >= 2
			and has_profile_subsequence(
				dynamic_first.command_profiles,
				["formation_guard", "rush_raider", "formation_guard"]
			),
		"dynamic strategy performs formation/rush/formation target switching"
	)
	check(
		dynamic_first.state == "VICTORY"
			and dynamic_first.killed == 18
			and dynamic_first.leaked == 5
			and dynamic_first.durability == 5
			and dynamic_first.completed_b == 1
			and dynamic_first.rush_leaked == 3
			and dynamic_first.guard_leaked == 2,
		"dynamic switching preserves its measured two-sided compromise"
	)
	check(
		rush_first.public_pointer_only
			and formation_first.public_pointer_only
			and dynamic_first.public_pointer_only
			and strategy_source_has_no_shortcuts(),
		"every strategy uses the real battlefield mouse entry without combat shortcuts"
	)
	check(
		all_rush_reactions_valid(rush_first.command_log)
			and all_rush_reactions_valid(dynamic_first.command_log)
			and all_rush_reactions_valid(front_dynamic_first.command_log),
		"every issued rush focus waits the configured 0.4-second warning reaction"
	)
	check(
		rush_first.command_visual_switch_valid
			and formation_first.command_visual_switch_valid
			and dynamic_first.command_visual_switch_valid,
		"rapid target switching leaves exactly one current reticle target"
	)
	var unattended_rush_leaks := get_leaked_rush_sequences(unattended_first.records)
	check(not unattended_rush_leaks.is_empty(), "unattended mixed battle creates a real rush leak candidate")
	check(
		any_sequence_saved(unattended_rush_leaks, rush_first.records),
		"rush-only 0.4-second focus saves an unattended rush leak target"
	)
	check(
		formation_first.completed_b < rush_first.completed_b
			or formation_first.b_complete_group_seconds + 0.001 < rush_first.b_complete_group_seconds,
		"formation-only focus lowers B-formation pressure relative to rush-only focus"
	)
	check(
		formation_first.rush_leaked >= rush_first.rush_leaked
			or formation_first.rush_completed >= rush_first.rush_completed,
		"ignoring rush warnings preserves a measurable rush-side cost"
	)
	check(
		dynamic_first.completed_b <= rush_first.completed_b
			and dynamic_first.b_complete_group_seconds <= rush_first.b_complete_group_seconds + 0.001,
		"dynamic switching improves formation pressure relative to rush-only focus"
	)
	check(
		dynamic_first.rush_leaked <= formation_first.rush_leaked
			and dynamic_first.rush_completed <= formation_first.rush_completed,
		"dynamic switching improves rush pressure relative to formation-only focus"
	)
	check(
		dynamic_first.leaked < unattended_first.leaked
			or dynamic_first.durability > unattended_first.durability,
		"dynamic switching improves village outcome over unattended play"
	)
	check(
		unattended_first.restart_clean
			and rush_first.restart_clean
			and formation_first.restart_clean
			and dynamic_first.restart_clean
			and front_dynamic_first.restart_clean,
		"battle restart clears formations, rush visuals, commands and attack visuals"
	)
	check(
		front_unattended_first.rush_prepared <= unattended_first.rush_prepared,
		"front deployment can naturally suppress rush preparation before it begins"
	)
	check(
		front_unattended_first.state == "VICTORY"
			and front_unattended_first.killed == 20
			and front_unattended_first.leaked == 3
			and front_unattended_first.durability == 7
			and front_unattended_first.completed_a == 5
			and front_unattended_first.completed_b == 0
			and front_unattended_first.rush_prepared == 3,
		"front unattended result records strong early suppression without erasing both threats"
	)
	check(
		front_dynamic_first.state == "VICTORY"
			and front_dynamic_first.killed == 19
			and front_dynamic_first.leaked == 4
			and front_dynamic_first.durability == 6
			and front_dynamic_first.rush_focus_calls == 3,
		"front dynamic result remains deterministic and uses visible rush warnings"
	)

	print_result("standard-unattended", unattended_first)
	print_result("standard-unattended-2", unattended_second)
	print_result("standard-rush-only", rush_first)
	print_result("standard-rush-only-2", rush_second)
	print_result("standard-formation-only", formation_first)
	print_result("standard-formation-only-2", formation_second)
	print_result("standard-dynamic", dynamic_first)
	print_result("standard-dynamic-2", dynamic_second)
	print_result("front-unattended", front_unattended_first)
	print_result("front-unattended-2", front_unattended_second)
	print_result("front-dynamic", front_dynamic_first)
	print_result("front-dynamic-2", front_dynamic_second)
	print("v2-6b-p overlap timeline=%s" % str(unattended_first.overlap_windows))
	print("v2-6b-p key events=%s" % str(unattended_first.timeline))
	if failures.is_empty():
		print("v2-6b-p mixed threat smoke ok: %d requirements" % check_count)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func run_validation(mode: StringName, front_deployment: bool) -> Dictionary:
	var controller = (load(SCENE_PATH) as PackedScene).instantiate()
	root.add_child(controller)
	await process_frame
	await process_frame
	controller.set_automatic_simulation(false)
	controller.select_scenario(&"mixed_threat_validation")
	if front_deployment:
		apply_public_deployment(controller, FRONT_DEPLOYMENT)
	else:
		controller.apply_recommended_deployment()
	controller.start_battle()

	var profile_by_id: Dictionary = {}
	var sequence_by_id: Dictionary = {}
	var rush_records: Dictionary = {}
	var last_rush_state: Dictionary = {}
	var last_group_state: Dictionary = {}
	var settled_seen: Dictionary = {}
	var handled_rush_ids: Dictionary = {}
	var handled_formation_ids: Dictionary = {}
	var command_log: Array[Dictionary] = []
	var timeline: Array[Dictionary] = []
	var overlap_windows: Array[Dictionary] = []
	var overlap_active := false
	var overlap_started_at := -1.0
	var overlap_wave := -1
	var overlap_waves: Dictionary = {}
	var rush_visual_valid := true
	var guard_visual_valid := true
	var rush_formation_exclusion_valid := true
	var saw_simultaneous_visuals := false
	var command_visual_switch_valid := true
	var b_complete_group_seconds := 0.0
	var steps := 0

	while controller.battle_state == controller.BattleState.RUNNING and steps < MAX_STEPS:
		var simulation_step := get_next_strategy_step(controller, mode, handled_rush_ids)
		controller.simulate_step(simulation_step)
		var wave: Dictionary = controller.get_wave_snapshot()
		var wave_index := int(wave.get("current_wave_index", -1))
		var rush_preparing := false
		var guard_critical := false
		var guard_visual_active := false

		for enemy in controller.active_enemies.values():
			if not is_instance_valid(enemy):
				continue
			var enemy_id := StringName(enemy.runtime_id)
			var profile_id := StringName(enemy.monster_type)
			profile_by_id[enemy_id] = profile_id
			sequence_by_id[enemy_id] = int(enemy.spawn_sequence)
			var snapshot: Dictionary = enemy.get_runtime_snapshot()
			if profile_id == &"rush_raider":
				if not rush_records.has(int(enemy.spawn_sequence)):
					rush_records[int(enemy.spawn_sequence)] = create_rush_record(enemy, wave_index)
				var record: Dictionary = rush_records[int(enemy.spawn_sequence)]
				var state := StringName(snapshot.get("rush_state", &""))
				if StringName(last_rush_state.get(enemy_id, &"")) != state:
					timeline.append(make_event(controller.battle_elapsed, wave_index, &"rush_state", {
						"sequence": int(enemy.spawn_sequence),
						"state": String(state),
					}))
					last_rush_state[enemy_id] = state
				if state == CONFIG.RUSH_STATE_PREPARING:
					rush_preparing = true
					if float(record.prepare_at) < 0.0:
						record.prepare_at = float(controller.battle_elapsed) - float(enemy.rush_prepare_elapsed)
				elif state == CONFIG.RUSH_STATE_RUSHING and float(record.rush_at) < 0.0:
					record.rush_at = float(controller.battle_elapsed) - float(enemy.rush_elapsed)
				rush_visual_valid = rush_visual_valid and (
					bool(snapshot.get("rush_warning_visible", false))
						== (state == CONFIG.RUSH_STATE_PREPARING)
					and bool(snapshot.get("rush_trail_visible", false))
						== (state == CONFIG.RUSH_STATE_RUSHING)
				)
				rush_formation_exclusion_valid = rush_formation_exclusion_valid and (
					not enemy.formation_can_participate
					and enemy.formation_id == &""
					and enemy.formation_level == CONFIG.FORMATION_LEVEL_SINGLE
					and enemy.formation_state == CONFIG.FORMATION_STATE_NONE
				)
			elif profile_id == &"formation_guard":
				guard_visual_valid = guard_visual_valid and (
					not bool(snapshot.get("rush_warning_visible", false))
					and not bool(snapshot.get("rush_trail_visible", false))
				)
				guard_visual_active = guard_visual_active or (
					int(enemy.get_formation_shield_visual_strength()) > 0
				)

		var groups: Array = controller.get_formation_groups_snapshot()
		var current_group_ids: Dictionary = {}
		for group: Dictionary in groups:
			var group_id := StringName(group.get("formation_id", &""))
			var profile_id := StringName(group.get("monster_type", &""))
			var level := StringName(group.get("formation_level", &""))
			var state := StringName(group.get("formation_state", &""))
			current_group_ids[group_id] = true
			if profile_id == &"formation_guard":
				guard_critical = guard_critical or is_guard_critical_state(level, state)
				guard_visual_active = guard_visual_active or (
					bool(group.get("forming_b_warning_visible", false))
					or bool(group.get("preparing_b_visual_visible", false))
					or (level == CONFIG.FORMATION_LEVEL_B and state == CONFIG.FORMATION_STATE_COMPLETE)
				)
				if level == CONFIG.FORMATION_LEVEL_B and state == CONFIG.FORMATION_STATE_COMPLETE:
					b_complete_group_seconds += simulation_step
			if StringName(last_group_state.get(group_id, &"")) != state:
				timeline.append(make_event(controller.battle_elapsed, wave_index, &"formation_state", {
					"formation_id": String(group_id),
					"profile": String(profile_id),
					"level": String(level),
					"state": String(state),
				}))
				last_group_state[group_id] = state
			for member_id in group.get("member_ids", []):
				if StringName(profile_by_id.get(StringName(member_id), &"")) == &"rush_raider":
					rush_formation_exclusion_valid = false
		for known_group_id in last_group_state.keys():
			if not current_group_ids.has(known_group_id):
				last_group_state.erase(known_group_id)

		var overlap_now := rush_preparing and guard_critical
		if overlap_now and not overlap_active:
			overlap_active = true
			overlap_started_at = float(controller.battle_elapsed)
			overlap_wave = wave_index
			overlap_waves[wave_index] = true
		elif not overlap_now and overlap_active:
			overlap_windows.append({
				"wave_index": overlap_wave,
				"start": snappedf(overlap_started_at, 0.001),
				"end": snappedf(float(controller.battle_elapsed), 0.001),
			})
			overlap_active = false
		saw_simultaneous_visuals = saw_simultaneous_visuals or (
			rush_preparing and guard_visual_active
		)

		capture_settlements(
			controller,
			rush_records,
			profile_by_id,
			sequence_by_id,
			settled_seen,
			timeline,
			wave_index
		)
		var command_result := run_strategy(
			controller,
			mode,
			handled_rush_ids,
			handled_formation_ids
		)
		if not command_result.is_empty():
			command_result["time"] = snappedf(float(controller.battle_elapsed), 0.001)
			command_result["wave_index"] = wave_index
			command_log.append(command_result)
			timeline.append(make_event(
				controller.battle_elapsed, wave_index, &"focus", command_result
			))
			command_visual_switch_valid = command_visual_switch_valid and (
				count_command_target_visuals(controller) == 1
				and is_current_command_visual_target(controller)
			)
		steps += 1

	if overlap_active:
		overlap_windows.append({
			"wave_index": overlap_wave,
			"start": snappedf(overlap_started_at, 0.001),
			"end": snappedf(float(controller.battle_elapsed), 0.001),
		})
	capture_settlements(
		controller,
		rush_records,
		profile_by_id,
		sequence_by_id,
		settled_seen,
		timeline,
		int(controller.get_wave_snapshot().get("current_wave_index", -1))
	)
	var battle: Dictionary = controller.get_battle_snapshot()
	var formation_stats: Dictionary = battle.get("formation_stats", {})
	var outcomes := build_outcome_counts(controller, profile_by_id)
	var records := sanitize_rush_records(rush_records)
	var command_profiles: Array[String] = []
	var rush_focus_calls := 0
	var formation_focus_calls := 0
	for command: Dictionary in command_log:
		var profile := String(command.get("profile", ""))
		command_profiles.append(profile)
		if profile == "rush_raider":
			rush_focus_calls += 1
		elif profile == "formation_guard":
			formation_focus_calls += 1
	var result := {
		"state": String(battle.get("state", "")),
		"duration": snappedf(float(battle.get("battle_elapsed", 0.0)), 0.001),
		"generated": int(battle.get("generated_enemy_count", 0)),
		"killed": int(battle.get("killed_enemy_count", 0)),
		"leaked": int(battle.get("leaked_enemy_count", 0)),
		"durability": int(battle.get("village_durability", 0)),
		"completed_a": int(formation_stats.get("completed_a_count", 0)),
		"completed_b": int(formation_stats.get("completed_b_count", 0)),
		"interrupted": int(formation_stats.get("interrupted_count", 0)),
		"downgraded": int(formation_stats.get("downgrade_count", 0)),
		"b_complete_group_seconds": snappedf(b_complete_group_seconds, 0.001),
		"rush_prepared": count_record_field(records, "prepare_at"),
		"rush_rushed": count_record_field(records, "rush_at"),
		"rush_completed": count_completed_rushes(records),
		"rush_killed": int(outcomes.killed.get(&"rush_raider", 0)),
		"rush_leaked": int(outcomes.leaked.get(&"rush_raider", 0)),
		"guard_killed": int(outcomes.killed.get(&"formation_guard", 0)),
		"guard_leaked": int(outcomes.leaked.get(&"formation_guard", 0)),
		"records": records,
		"trace": sanitize_trace(Dictionary(battle.get("wave", {})).get("spawn_trace", [])),
		"wave_records": sanitize_wave_records(
			Dictionary(Dictionary(battle.get("wave", {})).get("pacing", {})).get("wave_records", [])
		),
		"timeline": sanitize_timeline(timeline),
		"overlap_windows": overlap_windows,
		"overlap_wave_count": overlap_waves.size(),
		"rush_visual_valid": rush_visual_valid,
		"guard_visual_valid": guard_visual_valid,
		"saw_simultaneous_visuals": saw_simultaneous_visuals,
		"rush_formation_exclusion_valid": rush_formation_exclusion_valid,
		"command_count": command_log.size(),
		"rush_focus_calls": rush_focus_calls,
		"formation_focus_calls": formation_focus_calls,
		"command_profiles": command_profiles,
		"command_log": command_log.duplicate(true),
		"command_switch_count": count_profile_switches(command_profiles),
		"public_pointer_only": command_log.size() == rush_focus_calls + formation_focus_calls,
		"command_visual_switch_valid": command_visual_switch_valid,
		"deployment": Dictionary(battle.get("deployment", {})).duplicate(true),
	}
	controller.restart_battle()
	await process_frame
	var reset: Dictionary = controller.get_battle_snapshot()
	var reset_stats: Dictionary = reset.get("formation_stats", {})
	result["restart_clean"] = (
		controller.active_enemies.is_empty()
		and controller.get_formation_groups_snapshot().is_empty()
		and Dictionary(reset.get("command", {})).is_empty()
		and Array(reset.get("attack_visuals", [])).is_empty()
		and int(reset_stats.get("active_group_count", -1)) == 0
		and int(reset_stats.get("member_assignment_count", -1)) == 0
	)
	controller.queue_free()
	await process_frame
	return result


func run_strategy(
	controller,
	mode: StringName,
	handled_rush_ids: Dictionary,
	handled_formation_ids: Dictionary
) -> Dictionary:
	if mode == MODE_UNATTENDED:
		return {}
	if mode in [MODE_RUSH_ONLY, MODE_DYNAMIC]:
		var rush_target = find_ready_rush_target(controller, handled_rush_ids)
		if is_instance_valid(rush_target):
			var target_id := StringName(rush_target.runtime_id)
			if issue_focus_via_player_pointer(controller, rush_target):
				handled_rush_ids[target_id] = true
				return {
					"profile": "rush_raider",
					"target_id": String(target_id),
					"sequence": int(rush_target.spawn_sequence),
					"reaction": snappedf(float(rush_target.rush_prepare_elapsed), 0.001),
				}
	if mode == MODE_RUSH_ONLY:
		return {}
	var active_command: Dictionary = controller.command_controller.get_active_command_snapshot()
	var active_target_id := StringName(active_command.get("target_runtime_id", &""))
	if active_target_id != &"" and controller.active_enemies.has(active_target_id):
		return {}
	var guard_selection := find_guard_focus_target(controller, handled_formation_ids)
	if guard_selection.is_empty():
		return {}
	var guard_target = controller.active_enemies.get(StringName(guard_selection.target_id))
	if not is_instance_valid(guard_target):
		return {}
	if issue_focus_via_player_pointer(controller, guard_target):
		handled_formation_ids[StringName(guard_selection.formation_id)] = true
		return {
			"profile": "formation_guard",
			"target_id": String(guard_target.runtime_id),
			"sequence": int(guard_target.spawn_sequence),
			"formation_id": String(guard_selection.formation_id),
			"formation_level": String(guard_selection.formation_level),
			"formation_state": String(guard_selection.formation_state),
		}
	return {}


func get_next_strategy_step(
	controller,
	mode: StringName,
	handled_rush_ids: Dictionary
) -> float:
	if mode not in [MODE_RUSH_ONLY, MODE_DYNAMIC]:
		return STEP
	for enemy in controller.active_enemies.values():
		if (
			is_instance_valid(enemy)
			and enemy.monster_type == &"rush_raider"
			and enemy.rush_state == CONFIG.RUSH_STATE_PREPARING
			and not handled_rush_ids.has(StringName(enemy.runtime_id))
		):
			var remaining := maxf(
				0.0,
				RUSH_REACTION_DELAY - float(enemy.rush_prepare_elapsed)
			)
			if remaining > 0.000001:
				return minf(STEP, remaining)
	return STEP


func find_ready_rush_target(controller, handled_rush_ids: Dictionary):
	var candidates: Array = []
	for enemy in controller.active_enemies.values():
		if (
			is_instance_valid(enemy)
			and enemy.monster_type == &"rush_raider"
			and enemy.rush_state == CONFIG.RUSH_STATE_PREPARING
			and float(enemy.rush_prepare_elapsed) + 0.0001 >= RUSH_REACTION_DELAY
			and not handled_rush_ids.has(StringName(enemy.runtime_id))
		):
			candidates.append(enemy)
	candidates.sort_custom(func(first, second): return int(first.spawn_sequence) < int(second.spawn_sequence))
	return candidates[0] if not candidates.is_empty() else null


func find_guard_focus_target(controller, handled_formation_ids: Dictionary) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for group: Dictionary in controller.get_formation_groups_snapshot():
		var group_id := StringName(group.get("formation_id", &""))
		var profile_id := StringName(group.get("monster_type", &""))
		var level := StringName(group.get("formation_level", &""))
		var state := StringName(group.get("formation_state", &""))
		if profile_id != &"formation_guard" or handled_formation_ids.has(group_id):
			continue
		var priority := get_guard_focus_priority(level, state)
		if priority >= 99:
			continue
		if state == CONFIG.FORMATION_STATE_PREPARING_B and (
			float(group.get("prepare_elapsed", 0.0)) + 0.0001 < FORMATION_REACTION_DELAY
		):
			continue
		var target_id := select_stable_member(controller, group.get("member_ids", []))
		if target_id == &"":
			continue
		candidates.append({
			"priority": priority,
			"formation_id": group_id,
			"formation_level": level,
			"formation_state": state,
			"target_id": target_id,
		})
	candidates.sort_custom(func(first: Dictionary, second: Dictionary):
		if int(first.priority) != int(second.priority):
			return int(first.priority) < int(second.priority)
		return String(first.formation_id) < String(second.formation_id)
	)
	return candidates[0] if not candidates.is_empty() else {}


func get_guard_focus_priority(level: StringName, state: StringName) -> int:
	if level == CONFIG.FORMATION_LEVEL_B and state == CONFIG.FORMATION_STATE_PREPARING_B:
		return 0
	if level == CONFIG.FORMATION_LEVEL_B and state == CONFIG.FORMATION_STATE_FORMING_B:
		return 1
	if level == CONFIG.FORMATION_LEVEL_B and state == CONFIG.FORMATION_STATE_COMPLETE:
		return 2
	if level == CONFIG.FORMATION_LEVEL_A and state == CONFIG.FORMATION_STATE_COMPLETE:
		return 3
	return 99


func is_guard_critical_state(level: StringName, state: StringName) -> bool:
	return (
		(level == CONFIG.FORMATION_LEVEL_A and state == CONFIG.FORMATION_STATE_COMPLETE)
		or (
			level == CONFIG.FORMATION_LEVEL_B
			and state in [
				CONFIG.FORMATION_STATE_FORMING_B,
				CONFIG.FORMATION_STATE_PREPARING_B,
				CONFIG.FORMATION_STATE_COMPLETE,
			]
		)
	)


func select_stable_member(controller, member_ids: Array) -> StringName:
	var selected_id: StringName = &""
	var selected_sequence := 1_000_000
	for member_id in member_ids:
		var enemy = controller.active_enemies.get(StringName(member_id))
		if not is_instance_valid(enemy) or enemy.monster_type != &"formation_guard":
			continue
		if int(enemy.spawn_sequence) < selected_sequence:
			selected_sequence = int(enemy.spawn_sequence)
			selected_id = StringName(enemy.runtime_id)
	return selected_id


func issue_focus_via_player_pointer(controller, target) -> bool:
	if not is_instance_valid(target):
		return false
	var accepted: bool = controller.handle_battlefield_pointer(
		target.position,
		MOUSE_BUTTON_LEFT
	)
	var command: Dictionary = controller.command_controller.get_active_command_snapshot()
	return accepted and StringName(command.get("target_runtime_id", &"")) == target.runtime_id


func apply_public_deployment(controller, deployment: Dictionary) -> bool:
	controller.clear_deployment()
	for character_id: StringName in CONFIG.get_character_ids():
		if not controller.deploy_character(
			character_id,
			StringName(deployment.get(character_id, &""))
		):
			return false
	return true


func capture_settlements(
	controller,
	rush_records: Dictionary,
	profile_by_id: Dictionary,
	sequence_by_id: Dictionary,
	settled_seen: Dictionary,
	timeline: Array[Dictionary],
	wave_index: int
) -> void:
	for enemy_id in controller.settled_enemy_ids.keys():
		var stable_id := StringName(enemy_id)
		if settled_seen.has(stable_id):
			continue
		settled_seen[stable_id] = true
		var profile_id := StringName(profile_by_id.get(stable_id, &"unknown"))
		var sequence := int(sequence_by_id.get(stable_id, -1))
		var outcome := String(controller.settled_enemy_ids[stable_id])
		timeline.append(make_event(controller.battle_elapsed, wave_index, &"settled", {
			"profile": String(profile_id),
			"sequence": sequence,
			"outcome": outcome,
		}))
		if profile_id == &"rush_raider" and rush_records.has(sequence):
			var record: Dictionary = rush_records[sequence]
			record.outcome = outcome
			record.settled_at = float(controller.battle_elapsed)


func build_outcome_counts(controller, profile_by_id: Dictionary) -> Dictionary:
	var killed: Dictionary = {}
	var leaked: Dictionary = {}
	for enemy_id in controller.settled_enemy_ids.keys():
		var profile_id := StringName(profile_by_id.get(StringName(enemy_id), &"unknown"))
		var outcome := StringName(controller.settled_enemy_ids[enemy_id])
		if outcome == &"killed":
			killed[profile_id] = int(killed.get(profile_id, 0)) + 1
		elif outcome == &"leaked":
			leaked[profile_id] = int(leaked.get(profile_id, 0)) + 1
	return {"killed": killed, "leaked": leaked}


func create_rush_record(enemy, wave_index: int) -> Dictionary:
	return {
		"sequence": int(enemy.spawn_sequence),
		"wave_index": wave_index,
		"spawn_point_id": String(enemy.spawn_point_id),
		"route_id": String(enemy.route_id),
		"prepare_at": -1.0,
		"rush_at": -1.0,
		"outcome": "",
		"settled_at": -1.0,
	}


func sanitize_rush_records(records: Dictionary) -> Array[Dictionary]:
	var sequences: Array[int] = []
	for sequence in records.keys():
		sequences.append(int(sequence))
	sequences.sort()
	var result: Array[Dictionary] = []
	for sequence: int in sequences:
		var source: Dictionary = records[sequence]
		result.append({
			"sequence": sequence,
			"wave_index": int(source.wave_index),
			"spawn_point_id": String(source.spawn_point_id),
			"route_id": String(source.route_id),
			"prepare_at": snap_optional(float(source.prepare_at)),
			"rush_at": snap_optional(float(source.rush_at)),
			"outcome": String(source.outcome),
			"settled_at": snap_optional(float(source.settled_at)),
		})
	return result


func sanitize_trace(raw_trace: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Dictionary in raw_trace:
		result.append({
			"wave_index": int(event.get("wave_index", -1)),
			"subwave_index": int(event.get("subwave_index", -1)),
			"group_index": int(event.get("group_index", -1)),
			"item_index": int(event.get("item_index", -1)),
			"due_time": snappedf(float(event.get("due_time", 0.0)), 0.001),
			"enemy_profile_id": String(event.get("enemy_profile_id", "")),
			"spawn_point_id": String(event.get("spawn_point_id", "")),
			"route_id": String(event.get("route_id", "")),
		})
	return result


func sanitize_wave_records(raw_records: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record: Dictionary in raw_records:
		result.append({
			"wave_index": int(record.get("wave_index", -1)),
			"planned": int(record.get("planned", 0)),
			"killed": int(record.get("killed", 0)),
			"leaked": int(record.get("leaked", 0)),
			"completed_a": int(record.get("completed_a", 0)),
			"completed_b": int(record.get("completed_b", 0)),
			"start_time": snap_optional(float(record.get("start_time", -1.0))),
			"end_time": snap_optional(float(record.get("end_time", -1.0))),
			"duration": snappedf(float(record.get("duration", 0.0)), 0.001),
			"peak_active": int(record.get("peak_active", 0)),
		})
	return result


func sanitize_timeline(raw_timeline: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Dictionary in raw_timeline:
		if StringName(event.get("kind", &"")) in [&"formation_state", &"rush_state", &"focus"]:
			result.append(event.duplicate(true))
	return result


func make_event(time: float, wave_index: int, kind: StringName, details: Dictionary) -> Dictionary:
	var result := {
		"time": snappedf(time, 0.001),
		"wave_index": wave_index,
		"kind": String(kind),
	}
	for key in details.keys():
		result[key] = details[key]
	return result


func count_record_field(records: Array, field: String) -> int:
	var result := 0
	for record: Dictionary in records:
		if float(record.get(field, -1.0)) >= 0.0:
			result += 1
	return result


func count_completed_rushes(records: Array) -> int:
	var result := 0
	for record: Dictionary in records:
		if float(record.get("rush_at", -1.0)) >= 0.0 \
				and float(record.get("settled_at", -1.0)) - float(record.get("rush_at", -1.0)) >= 3.25:
			result += 1
	return result


func get_leaked_rush_sequences(records: Array) -> Array[int]:
	var result: Array[int] = []
	for record: Dictionary in records:
		if String(record.get("outcome", "")) == "leaked":
			result.append(int(record.get("sequence", -1)))
	return result


func any_sequence_saved(leaked_sequences: Array[int], focused_records: Array) -> bool:
	for sequence: int in leaked_sequences:
		for record: Dictionary in focused_records:
			if int(record.get("sequence", -1)) == sequence \
					and String(record.get("outcome", "")) == "killed":
				return true
	return false


func count_profile_switches(profiles: Array[String]) -> int:
	var result := 0
	for index in range(1, profiles.size()):
		if profiles[index] != profiles[index - 1]:
			result += 1
	return result


func has_profile_subsequence(profiles: Array, expected: Array) -> bool:
	var expected_index := 0
	for profile in profiles:
		if expected_index < expected.size() and String(profile) == String(expected[expected_index]):
			expected_index += 1
	return expected_index == expected.size()


func all_rush_reactions_valid(command_log: Array) -> bool:
	for command: Dictionary in command_log:
		if String(command.get("profile", "")) != "rush_raider":
			continue
		if absf(float(command.get("reaction", -1.0)) - RUSH_REACTION_DELAY) > STEP + 0.001:
			return false
	return true


func count_command_target_visuals(controller) -> int:
	var result := 0
	for enemy in controller.active_enemies.values():
		if is_instance_valid(enemy) and bool(enemy.command_is_target):
			result += 1
	return result


func is_current_command_visual_target(controller) -> bool:
	var command: Dictionary = controller.command_controller.get_active_command_snapshot()
	var target_id := StringName(command.get("target_runtime_id", &""))
	var target = controller.active_enemies.get(target_id)
	return is_instance_valid(target) and bool(target.command_is_target)


func all_traces_match(results: Array) -> bool:
	if results.is_empty():
		return true
	var expected: Array = Dictionary(results[0]).get("trace", [])
	for result: Dictionary in results:
		if Array(result.get("trace", [])) != expected:
			return false
	return true


func count_profile_in_battle(config: Dictionary, profile_id: StringName) -> int:
	var result := 0
	for wave: Dictionary in config.get("waves", []):
		for subwave: Dictionary in wave.get("subwaves", []):
			for group: Dictionary in subwave.get("spawn_groups", []):
				if StringName(group.get("enemy_profile_id", &"")) == profile_id:
					result += int(group.get("count", 0))
	return result


func battle_uses_only_expected_profiles(config: Dictionary) -> bool:
	for wave: Dictionary in config.get("waves", []):
		for subwave: Dictionary in wave.get("subwaves", []):
			for group: Dictionary in subwave.get("spawn_groups", []):
				if StringName(group.get("enemy_profile_id", &"")) not in [
					&"formation_guard", &"rush_raider",
				]:
					return false
	return true


func independent_validation_configs_unchanged() -> bool:
	var guard_config := CONFIG.get_wave_battle_config(&"v2_6a_formation_guard_validation")
	var rush_config := CONFIG.get_wave_battle_config(&"v2_6b_rush_raider_validation")
	var guard_counts: Array[int] = []
	for wave: Dictionary in guard_config.get("waves", []):
		guard_counts.append(WaveDirector.count_wave_enemies(wave))
	var rush_counts: Array[int] = []
	for wave: Dictionary in rush_config.get("waves", []):
		rush_counts.append(WaveDirector.count_wave_enemies(wave))
	return (
		int(guard_config.get("random_seed", 0)) == 2601
		and guard_counts == [2, 4, 16]
		and int(rush_config.get("random_seed", 0)) == 2602
		and rush_counts == [1, 2, 5]
	)


func strategy_source_has_no_shortcuts() -> bool:
	var source_file := FileAccess.open(
		"res://prototype/formation_defense/tests/smoke_v2_6b_p_mixed_threat.gd",
		FileAccess.READ
	)
	if source_file == null:
		return false
	var source := source_file.get_as_text()
	var start := source.find("func run_validation")
	var finish := source.find("\nfunc get_next_strategy_step", start)
	if start < 0 or finish <= start:
		return false
	var strategy_source := source.substr(start, finish - start)
	var forbidden_tokens := [
		".take_" + "damage(",
		".current_health = ",
		".route_progress = ",
		".traveled_distance = ",
		".formation_state = ",
		"interrupt_enemy_" + "formation(",
		"interrupt_member(",
		"formation_manager.",
	]
	for token: String in forbidden_tokens:
		if strategy_source.find(token) >= 0:
			return false
	return (
		strategy_source.find("issue_focus_via_player_pointer(") >= 0
		and source.find("controller.handle_battlefield_pointer(") >= 0
	)


func snap_optional(value: float) -> float:
	return snappedf(value, 0.001) if value >= 0.0 else -1.0


func print_result(label: String, result: Dictionary) -> void:
	print("v2-6b-p %s: state=%s duration=%.1f generated=%d killed=%d leaked=%d durability=%d A/B=%d/%d rush prepared/rushed/completed/killed/leaked=%d/%d/%d/%d/%d guard killed/leaked=%d/%d B_seconds=%.1f commands=%s overlaps=%s" % [
		label,
		result.state,
		result.duration,
		result.generated,
		result.killed,
		result.leaked,
		result.durability,
		result.completed_a,
		result.completed_b,
		result.rush_prepared,
		result.rush_rushed,
		result.rush_completed,
		result.rush_killed,
		result.rush_leaked,
		result.guard_killed,
		result.guard_leaked,
		result.b_complete_group_seconds,
		str(result.command_profiles),
		str(result.overlap_windows),
	])
	print("v2-6b-p %s rush_records=%s" % [label, str(result.records)])


func check(condition: bool, message: String) -> void:
	check_count += 1
	if not condition:
		failures.append(message)

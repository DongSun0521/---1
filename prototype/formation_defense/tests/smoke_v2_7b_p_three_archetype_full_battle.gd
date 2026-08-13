extends SceneTree

const SCENE_PATH := "res://prototype/formation_defense/scenes/formation_defense_prototype.tscn"
const CONFIG := preload("res://prototype/formation_defense/data/formation_defense_config.gd")
const WaveDirector := preload("res://prototype/formation_defense/scripts/formation_defense_wave_director.gd")
const SCENARIO_ID: StringName = &"three_archetype_full_battle"
const BATTLE_ID: StringName = &"v2_7b_three_archetype_full_battle"
const STEP := 0.1
const MAX_STEPS := 7000
const PROFILE_IDS: Array[StringName] = [&"formation_guard", &"charge", &"rush_raider"]

var failures: Array[String] = []
var check_count := 0


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var config := CONFIG.get_wave_battle_config(BATTLE_ID)
	var validation := WaveDirector.validate_battle_config(
		config,
		CONFIG.get_monster_type_ids(),
		CONFIG.get_spawn_point_lane_map(),
		CONFIG.get_visual_route_ids()
	)
	check(validation.is_empty(), "V2-7B battle configuration validates")
	check(
		StringName(config.get("battle_id", &"")) == BATTLE_ID
			and int(config.get("random_seed", 0)) == 2703,
		"battle ID and random seed are isolated"
	)
	check(
		is_equal_approx(float(config.get("initial_countdown", 0.0)), 4.0)
			and is_equal_approx(float(config.get("inter_wave_delay", 0.0)), 6.0),
		"countdown values match the full-battle contract"
	)
	check(config.get("waves", []).size() == 5, "battle contains five waves")
	check(count_planned_enemies(config) == 60, "battle plans sixty enemies")
	var planned := count_profiles(config)
	for profile_id: StringName in PROFILE_IDS:
		check(int(planned.get(profile_id, 0)) == 20, "%s plans twenty enemies" % profile_id)
	check(wave_profile_counts_match(config), "all five waves match the requested archetype counts")
	check(mixed_wave_groups_overlap(config, 3), "wave four uses three staggered overlapping groups")
	check(mixed_wave_groups_overlap(config, 4), "wave five uses two staggered mixed rounds")
	check(
		not bool(config.get("character_contact_combat_enabled", false))
			and bool(config.get("character_ultimate_enabled", false))
			and bool(config.get("character_role_labels_enabled", false)),
		"contact remains default-off while ultimates and role labels are battle-enabled"
	)
	check(profile_overrides_match(config), "profile health, speed, names and vector markers match the contract")
	check(final_character_ranges_match(config), "hunter and mage use the finalized config ranges")
	check(position_ultimate_cast_area_matches(config), "position ultimates use the configured full combat area")
	check(formation_overrides_match(config), "battle-local A/B formation spacing scales match the contract")
	check(historical_defaults_unchanged(), "historical profile, battle and formation defaults remain unchanged")
	check(
		CONFIG.get_recommended_deployment(SCENARIO_ID)
			== CONFIG.THREE_ARCHETYPE_FULL_BATTLE_DEPLOYMENT,
		"full battle exposes its own tactical observation deployment"
	)
	check(smoke_uses_only_formal_input(), "fixed operation contains no direct state or damage shortcuts")

	var visual := await run_visual_and_restart_checks()
	for key in visual.keys():
		check(bool(visual[key]), "visual/restart contract: %s" % key)

	var unattended_first := await run_battle(false)
	var unattended_second := await run_battle(false)
	var commanded_first := await run_battle(true)
	var commanded_second := await run_battle(true)
	print_result("unattended-1", unattended_first)
	print_result("unattended-2", unattended_second)
	print_result("commanded-1", commanded_first)
	print_result("commanded-2", commanded_second)
	check(unattended_first == unattended_second, "unattended full battle repeats exactly")
	check(commanded_first == commanded_second, "fixed-input full battle repeats exactly")
	check(
		int(unattended_first.generated) == 60,
		"unattended run generates all sixty configured enemies"
	)
	check(
		int(commanded_first.generated) == 60,
		"fixed-input run generates all sixty configured enemies"
	)
	check(settlement_accounting_is_exact(unattended_first), "unattended settlement and STOPPED cleanup accounting is exact")
	check(settlement_accounting_is_exact(commanded_first), "fixed-input settlement and STOPPED cleanup accounting is exact")
	check(
		unattended_first.state in ["VICTORY", "DEFEAT"],
		"unattended run reaches a terminal battle state"
	)
	check(
		commanded_first.state in ["VICTORY", "DEFEAT"],
		"fixed-input run reaches a terminal battle state"
	)
	check(unattended_first.spawn_trace == unattended_second.spawn_trace, "fixed seed repeats the spawn trace")
	check(commanded_first.spawn_trace == commanded_second.spawn_trace, "fixed input repeats the spawn trace")
	check(unattended_first.wave_records == unattended_second.wave_records, "per-wave timing repeats unattended")
	check(commanded_first.wave_records == commanded_second.wave_records, "per-wave timing repeats with input")
	for profile_id: StringName in PROFILE_IDS:
		var unattended_profile: Dictionary = unattended_first.archetypes.get(profile_id, {})
		check(int(unattended_profile.get("generated", 0)) == 20, "%s actually generates twenty enemies" % profile_id)
		check(profile_accounting_is_exact(unattended_profile), "%s accounting includes STOPPED cleanup" % profile_id)
	check(
		all_formation_capable_profiles_enter_a(unattended_first),
		"formation-capable archetypes enter the A zone alive"
	)
	check(
		unfocused_majority_enters_a(unattended_first),
		"most uncommanded formation-capable enemies reach the A zone"
	)
	check(
		formation_types_complete_a(unattended_first),
		"guard and acceleration archetypes each complete at least one A formation"
	)
	check(
		formation_types_have_b_opportunity(unattended_first),
		"formation-capable archetypes create real A-pair material and at least one B formation"
	)
	check(
		int(unattended_first.archetypes.rush_raider.rush_prepare_count) > 0
			and int(unattended_first.archetypes.rush_raider.rush_started_count) > 0,
		"rush enemies enter preparation and rushing states"
	)
	check(
		int(unattended_first.speed_effect_observed) > 0,
		"acceleration formation speed is observed in real movement"
	)
	check(
		int(unattended_first.guard_damage_prevented) > 0,
		"formation guards prevent player damage after completing formations"
	)
	check(
		int(commanded_first.command_clicks) > 0 and int(commanded_first.ultimate_releases) > 0,
		"fixed operation uses real focus clicks and real ultimate releases"
	)
	check(
		int(commanded_first.focus_kills_before_a) > 0,
		"fixed focus input kills at least one designated target before the A zone"
	)
	check(operation_has_benefit(unattended_first, commanded_first), "fixed operation improves a required outcome")
	check(
		int(unattended_first.duplicate_ultimate_settlements) == 0
			and int(commanded_first.duplicate_ultimate_settlements) == 0,
		"ultimate effects do not duplicate damage or settlement"
	)
	check(
		int(unattended_first.formation_member_overlap_count) == 0
			and int(commanded_first.formation_member_overlap_count) == 0,
		"compact formations never fully overlap member bodies"
	)
	check(
		unattended_first.marker_by_profile == expected_marker_map(),
		"three archetypes expose shield, boot and rocket markers"
	)
	check(
		unattended_first.role_labels == expected_role_label_map(),
		"four role labels come from character definitions"
	)
	check(
		bool(unattended_first.down_role_labels_gray)
			and bool(commanded_first.down_role_labels_gray),
		"incapacitated role labels remain visible and switch to the configured gray"
	)
	check(
		int(unattended_first.wave_state_anomaly_count) == 0
			and int(commanded_first.wave_state_anomaly_count) == 0,
		"wave schedule has no stall, early completion or missing spawn"
	)

	if failures.is_empty():
		print("v2-7b-p three archetype full battle smoke ok: %d requirements" % check_count)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func run_visual_and_restart_checks() -> Dictionary:
	var controller = await create_ready_controller()
	controller.apply_recommended_deployment()
	var role_labels_match := true
	var runtime_ranges_match := true
	var range_overrides: Dictionary = CONFIG.get_wave_battle_config(BATTLE_ID).get(
		"character_action_range_overrides",
		{}
	)
	for character_id: StringName in CONFIG.get_character_ids():
		var character = controller.character_nodes.get(character_id)
		var definition := CONFIG.get_character_definition(character_id)
		role_labels_match = role_labels_match \
			and is_instance_valid(character) \
			and character.role_label_visible \
			and character.display_name == String(definition.get("display_name", ""))
		var expected_range := float(range_overrides.get(
			character_id,
			definition.get("action_range", 0.0)
		))
		runtime_ranges_match = runtime_ranges_match \
			and is_equal_approx(character.action_range, expected_range)
	controller.select_scenario(&"player_ultimate_validation")
	var historical_ranges_restored := true
	for character_id: StringName in CONFIG.get_character_ids():
		var character = controller.character_nodes.get(character_id)
		var definition := CONFIG.get_character_definition(character_id)
		historical_ranges_restored = historical_ranges_restored \
			and is_equal_approx(
				character.action_range,
				float(definition.get("action_range", 0.0))
			)
	var historical_position_cast_rect: Rect2 = controller.get_ultimate_cast_rect(
		controller.character_nodes[&"guard"]
	)
	var historical_position_cast_preserved: bool = not historical_position_cast_rect.is_equal_approx(
		Rect2(
			CONFIG.FULL_COMBAT_AREA_NORMALIZED_RECT.position * controller.LOGICAL_BATTLEFIELD_SIZE,
			CONFIG.FULL_COMBAT_AREA_NORMALIZED_RECT.size * controller.LOGICAL_BATTLEFIELD_SIZE
		)
	)
	controller.select_scenario(SCENARIO_ID)
	var expected_position_cast_rect := Rect2(
		CONFIG.FULL_COMBAT_AREA_NORMALIZED_RECT.position * controller.LOGICAL_BATTLEFIELD_SIZE,
		CONFIG.FULL_COMBAT_AREA_NORMALIZED_RECT.size * controller.LOGICAL_BATTLEFIELD_SIZE
	)
	var position_cast_area_match := true
	var defense_center := normalized_to_logic(Vector2(0.20, 0.50), controller)
	var b_formation_center := normalized_to_logic(Vector2(0.40, 0.50), controller)
	var outside_combat_area := normalized_to_logic(Vector2(0.04, 0.50), controller)
	for character_id: StringName in [&"guard", &"mage", &"doctor"]:
		var character = controller.character_nodes[character_id]
		var cast_rect: Rect2 = controller.get_ultimate_cast_rect(character)
		var preview: Dictionary = controller.build_ultimate_preview(
			character,
			b_formation_center,
			true
		)
		position_cast_area_match = position_cast_area_match \
			and cast_rect.is_equal_approx(expected_position_cast_rect) \
			and controller.is_position_ultimate_target_legal(character, defense_center) \
			and controller.is_position_ultimate_target_legal(character, b_formation_center) \
			and not controller.is_position_ultimate_target_legal(character, outside_combat_area) \
			and screen_polygon_matches_rect(
				PackedVector2Array(preview.get("cast_polygon", PackedVector2Array())),
				expected_position_cast_rect,
				controller
			)
	var resolution_safe := true
	var range_boundaries_exact := true
	var battlefield_size_stable := true
	for resolution in [Vector2(1920, 1080), Vector2(1600, 900), Vector2(1366, 768)]:
		controller.apply_fullscreen_layout(resolution)
		var before_size: Vector2 = controller.battlefield_content.size
		for character in controller.character_nodes.values():
			var global_scale: Vector2 = character.get_global_transform().get_scale()
			resolution_safe = resolution_safe \
				and is_equal_approx(global_scale.x, global_scale.y) \
				and Rect2(character.ROLE_LABEL_RECT).position.y > 20.0
		for character_id: StringName in [&"hunter", &"mage"]:
			var ranged_character = controller.character_nodes[character_id]
			var boundary_position: Vector2 = ranged_character.position \
				+ Vector2(ranged_character.action_range, 0.0)
			var outside_position: Vector2 = boundary_position + Vector2(0.1, 0.0)
			range_boundaries_exact = range_boundaries_exact \
				and ranged_character.is_position_in_action_range(boundary_position) \
				and not ranged_character.is_position_in_action_range(outside_position)
		controller.set_debug_panel_open(true)
		controller.set_debug_panel_open(false)
		battlefield_size_stable = battlefield_size_stable \
			and controller.battlefield_content.size.is_equal_approx(before_size)
	controller.apply_fullscreen_layout(Vector2(1920, 1080))
	controller.start_battle()
	for _step in range(55):
		controller.simulate_step(STEP)
	var guard_marker_seen := false
	var marker_has_no_children := true
	for enemy in controller.active_enemies.values():
		if is_instance_valid(enemy):
			guard_marker_seen = guard_marker_seen or enemy.type_marker == &"guard_shield"
			marker_has_no_children = marker_has_no_children and enemy.get_child_count() == 0
	controller.restart_battle()
	var restart_snapshot: Dictionary = controller.get_battle_snapshot()
	var restart_clean: bool = controller.active_enemies.is_empty() \
		and int(restart_snapshot.get("generated_enemy_count", -1)) == 0 \
		and int(restart_snapshot.get("ultimate_release_sequence", -1)) == 0 \
		and Dictionary(restart_snapshot.get("enemy_archetype_records", {1: 1})).is_empty() \
		and int(Dictionary(restart_snapshot.get("ultimate_overlay", {})).get("effect_count", -1)) == 0
	var spacing_snapshot: Dictionary = controller.get_formation_stats_snapshot()
	var runtime_spacing: bool = is_equal_approx(float(spacing_snapshot.get("formation_a_spacing_scale", 0.0)), 0.75) \
		and is_equal_approx(float(spacing_snapshot.get("formation_b_spacing_scale", 0.0)), 0.68)
	controller.queue_free()
	await process_frame
	await process_frame
	return {
		"role_labels_match_config": role_labels_match,
		"runtime_attack_ranges_use_final_battle_config": runtime_ranges_match,
		"historical_scenario_restores_default_attack_ranges": historical_ranges_restored,
		"position_ultimates_cover_defense_and_b_formation_zones": position_cast_area_match,
		"historical_position_ultimate_cast_area_is_preserved": historical_position_cast_preserved,
		"three_resolutions_use_uniform_visual_scale": resolution_safe,
		"logical_attack_range_boundaries_ignore_viewport_stretch": range_boundaries_exact,
		"debug_panel_does_not_resize_battlefield": battlefield_size_stable,
		"guard_marker_is_programmatic_and_noninteractive": guard_marker_seen and marker_has_no_children,
		"restart_clears_runtime_visual_and_combat_state": restart_clean,
		"runtime_spacing_uses_battle_overrides": runtime_spacing,
	}


func screen_polygon_matches_rect(
	points: PackedVector2Array,
	logic_rect: Rect2,
	controller
) -> bool:
	if points.size() != 5:
		return false
	var expected := PackedVector2Array([
		controller.logic_to_screen_position(logic_rect.position),
		controller.logic_to_screen_position(Vector2(logic_rect.end.x, logic_rect.position.y)),
		controller.logic_to_screen_position(logic_rect.end),
		controller.logic_to_screen_position(Vector2(logic_rect.position.x, logic_rect.end.y)),
		controller.logic_to_screen_position(logic_rect.position),
	])
	for index in range(expected.size()):
		if not points[index].is_equal_approx(expected[index]):
			return false
	return true


func run_battle(commanded: bool) -> Dictionary:
	var controller = await create_ready_controller()
	controller.apply_recommended_deployment()
	controller.start_battle()
	var command_clicks := 0
	var last_command_time := -10.0
	var marker_by_profile: Dictionary = {}
	var role_labels := collect_role_labels(controller)
	var formation_member_overlap_count := 0
	var wave_state_anomaly_count := 0
	var steps := 0
	while controller.battle_state == controller.BattleState.RUNNING and steps < MAX_STEPS:
		controller.simulate_step(STEP)
		collect_markers(controller, marker_by_profile)
		formation_member_overlap_count += count_complete_group_overlaps(controller)
		if commanded:
			if float(controller.battle_elapsed) - last_command_time >= 3.0:
				var focus_target = choose_focus_target(controller)
				if is_instance_valid(focus_target) and controller.handle_battlefield_pointer(
					focus_target.position, MOUSE_BUTTON_LEFT
				):
					command_clicks += 1
					last_command_time = float(controller.battle_elapsed)
			issue_ready_ultimates(controller)
		steps += 1
	if steps >= MAX_STEPS:
		wave_state_anomaly_count += 1
	var snapshot: Dictionary = controller.get_battle_snapshot()
	var wave: Dictionary = snapshot.get("wave", {})
	if int(snapshot.get("generated_enemy_count", 0)) != 60:
		wave_state_anomaly_count += 1
	var result := summarize_battle(
		snapshot,
		command_clicks,
		marker_by_profile,
		role_labels,
		formation_member_overlap_count,
		wave_state_anomaly_count
	)
	controller.queue_free()
	await process_frame
	await process_frame
	return result


func create_ready_controller():
	var controller = (load(SCENE_PATH) as PackedScene).instantiate()
	root.add_child(controller)
	await process_frame
	await process_frame
	controller.set_automatic_simulation(false)
	controller.select_scenario(SCENARIO_ID)
	return controller


func choose_focus_target(controller):
	var candidates: Array = []
	for enemy in controller.active_enemies.values():
		if is_instance_valid(enemy) and not enemy.is_dead and not enemy.settlement_completed:
			candidates.append(enemy)
	if candidates.is_empty():
		return null
	candidates.sort_custom(func(left, right):
		var left_priority := focus_priority(left)
		var right_priority := focus_priority(right)
		if left_priority != right_priority:
			return left_priority < right_priority
		if absf(float(left.route_progress) - float(right.route_progress)) > 0.0001:
			return float(left.route_progress) > float(right.route_progress)
		return String(left.runtime_id) < String(right.runtime_id)
	)
	return candidates[0]


func focus_priority(enemy) -> int:
	if enemy.monster_type == &"rush_raider" and enemy.rush_state == CONFIG.RUSH_STATE_PREPARING:
		return 0
	if enemy.monster_type == &"rush_raider" and enemy.rush_state == CONFIG.RUSH_STATE_RUSHING:
		return 1
	if enemy.formation_level == CONFIG.FORMATION_LEVEL_B:
		return 2
	if enemy.monster_type == &"formation_guard" and enemy.formation_level == CONFIG.FORMATION_LEVEL_A:
		return 3
	if enemy.monster_type == &"charge" and enemy.formation_level == CONFIG.FORMATION_LEVEL_A:
		return 4
	if enemy.monster_type == &"rush_raider":
		return 5
	if enemy.monster_type == &"formation_guard":
		return 6
	return 7


func issue_ready_ultimates(controller) -> void:
	for character_id: StringName in CONFIG.get_character_ids():
		var character = controller.character_nodes.get(character_id)
		if (
			not is_instance_valid(character)
			or not character.is_alive
			or not character.ultimate_ready
			or controller.ultimate_targeting_character_id != &""
		):
			continue
		var target := choose_ultimate_target(controller, character)
		if not bool(target.get("valid", false)):
			continue
		if controller.begin_ultimate_targeting(character_id):
			var screen_position: Vector2 = controller.logic_to_screen_position(target.position)
			controller.update_ultimate_targeting_from_screen(screen_position)
			controller.release_ultimate_targeting_from_screen(screen_position)


func choose_ultimate_target(controller, character) -> Dictionary:
	if character.role_id == &"doctor":
		var best_character = null
		var best_missing := 0
		for candidate_id: StringName in CONFIG.get_character_ids():
			var candidate = controller.character_nodes.get(candidate_id)
			if not is_instance_valid(candidate) or not candidate.is_alive:
				continue
			var missing := int(candidate.max_health) - int(candidate.current_health)
			if missing > best_missing:
				best_missing = missing
				best_character = candidate
		return {
			"valid": is_instance_valid(best_character),
			"position": best_character.position if is_instance_valid(best_character) else Vector2.ZERO,
		}
	var candidates: Array = []
	var cast_range := float(character.ultimate_definition.get("cast_range", 0.0))
	for enemy in controller.active_enemies.values():
		if (
			is_instance_valid(enemy)
			and not enemy.is_dead
			and not enemy.settlement_completed
			and character.position.distance_to(enemy.position) <= cast_range + 0.0001
		):
			candidates.append(enemy)
	if candidates.is_empty():
		return {"valid": false, "position": Vector2.ZERO}
	if character.role_id == &"hunter":
		candidates.sort_custom(func(left, right):
			var left_priority := focus_priority(left)
			var right_priority := focus_priority(right)
			if left_priority != right_priority:
				return left_priority < right_priority
			return String(left.runtime_id) < String(right.runtime_id)
		)
		return {"valid": true, "position": candidates[0].position}
	var radius := float(character.ultimate_definition.get("effect_radius", 0.0))
	var best_enemy = candidates[0]
	var best_count := -1
	for candidate in candidates:
		var count := 0
		for other in controller.active_enemies.values():
			if is_instance_valid(other) and candidate.position.distance_to(other.position) <= radius:
				count += 1
		if count > best_count or (count == best_count and String(candidate.runtime_id) < String(best_enemy.runtime_id)):
			best_enemy = candidate
			best_count = count
	return {"valid": true, "position": best_enemy.position}


func summarize_battle(
	snapshot: Dictionary,
	command_clicks: int,
	marker_by_profile: Dictionary,
	role_labels: Dictionary,
	formation_member_overlap_count: int,
	wave_state_anomaly_count: int
) -> Dictionary:
	var formation: Dictionary = snapshot.get("formation_stats", {})
	var wave: Dictionary = snapshot.get("wave", {})
	var archetypes: Dictionary = snapshot.get("archetype_stats_by_profile", {})
	var focus_kills_before_a := 0
	for stats: Dictionary in archetypes.values():
		focus_kills_before_a += int(stats.get("focus_killed_before_a", 0))
	return {
		"state": String(snapshot.get("state", "")),
		"duration": snappedf(float(snapshot.get("battle_elapsed", 0.0)), 0.1),
		"generated": int(snapshot.get("generated_enemy_count", 0)),
		"killed": int(snapshot.get("killed_enemy_count", 0)),
		"leaked": int(snapshot.get("leaked_enemy_count", 0)),
		"resolved": int(snapshot.get("resolved_enemy_count", 0)),
		"durability": int(snapshot.get("village_durability", 0)),
		"down": count_incapacitated(snapshot.get("characters", [])),
		"total_health": sum_current_health(snapshot.get("characters", [])),
		"character_ultimates": summarize_character_ultimates(snapshot.get("characters", [])),
		"ultimate_releases": int(snapshot.get("ultimate_release_sequence", 0)),
		"duplicate_ultimate_settlements": int(snapshot.get("ultimate_duplicate_settlement_count", 0)),
		"command_clicks": command_clicks,
		"focus_kills_before_a": focus_kills_before_a,
		"archetypes": sanitize_archetypes(archetypes),
		"completed_a_by_type": Dictionary(formation.get("completed_a_by_type", {})).duplicate(true),
		"completed_b_by_type": Dictionary(formation.get("completed_b_by_type", {})).duplicate(true),
		"completed_a": int(formation.get("completed_a_count", 0)),
		"completed_b": int(formation.get("completed_b_count", 0)),
		"interrupted": int(formation.get("interrupted_count", 0)),
		"downgraded": int(formation.get("downgrade_count", 0)),
		"speed_effect_observed": int(snapshot.get("speed_effect_observed_count", 0)),
		"guard_damage_prevented": int(snapshot.get("formation_damage_prevented_total", 0)),
		"spawn_trace": sanitize_spawn_trace(wave.get("spawn_trace", [])),
		"wave_records": sanitize_wave_records(Dictionary(wave.get("pacing", {})).get("wave_records", [])),
		"marker_by_profile": marker_by_profile.duplicate(true),
		"role_labels": role_labels.duplicate(true),
		"down_role_labels_gray": down_role_labels_are_gray(snapshot.get("characters", [])),
		"formation_member_overlap_count": formation_member_overlap_count,
		"wave_state_anomaly_count": wave_state_anomaly_count,
	}


func summarize_character_ultimates(characters: Array) -> Dictionary:
	var result: Dictionary = {}
	for character: Dictionary in characters:
		var role_id := StringName(character.get("role_id", &""))
		result[role_id] = {
			"energy": snappedf(float(character.get("ultimate_energy", 0.0)), 0.1),
			"releases": int(character.get("ultimate_release_count", 0)),
			"health": int(character.get("current_health", 0)),
			"down": bool(character.get("is_incapacitated", false)),
		}
	return result


func sanitize_archetypes(raw: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for profile_id: StringName in PROFILE_IDS:
		var stats: Dictionary = raw.get(profile_id, {})
		result[profile_id] = {
			"generated": int(stats.get("generated", 0)),
			"entered_a_alive": int(stats.get("entered_a_alive", 0)),
			"entered_a_unfocused": int(stats.get("entered_a_unfocused", 0)),
			"killed_before_a": int(stats.get("killed_before_a", 0)),
			"focus_killed_before_a": int(stats.get("focus_killed_before_a", 0)),
			"killed": int(stats.get("killed", 0)),
			"leaked": int(stats.get("leaked", 0)),
			"focus_commands_received": int(stats.get("focus_commands_received", 0)),
			"rush_prepare_count": int(stats.get("rush_prepare_count", 0)),
			"rush_started_count": int(stats.get("rush_started_count", 0)),
			"cleared_on_stop": maxi(
				0,
				int(stats.get("generated", 0))
					- int(stats.get("killed", 0))
					- int(stats.get("leaked", 0))
			),
		}
	return result


func sanitize_spawn_trace(raw: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in raw:
		result.append({
			"time": snappedf(float(entry.get("time", 0.0)), 0.001),
			"wave": int(entry.get("wave_index", -1)),
			"profile": StringName(entry.get("enemy_profile_id", &"")),
			"spawn": StringName(entry.get("spawn_point_id", &"")),
			"route": StringName(entry.get("route_id", &"")),
		})
	return result


func sanitize_wave_records(raw: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record: Dictionary in raw:
		result.append({
			"wave": int(record.get("wave_index", -1)),
			"start": snappedf(float(record.get("start_time", 0.0)), 0.1),
			"end": snappedf(float(record.get("end_time", 0.0)), 0.1),
			"planned": int(record.get("planned", 0)),
			"generated": int(record.get("generated", 0)),
			"killed": int(record.get("killed", 0)),
			"leaked": int(record.get("leaked", 0)),
			"peak": int(record.get("peak_active", 0)),
		})
	return result


func collect_markers(controller, result: Dictionary) -> void:
	for enemy in controller.active_enemies.values():
		if is_instance_valid(enemy):
			result[StringName(enemy.monster_type)] = StringName(enemy.type_marker)


func collect_role_labels(controller) -> Dictionary:
	var result: Dictionary = {}
	for character_id: StringName in CONFIG.get_character_ids():
		var character = controller.character_nodes.get(character_id)
		if is_instance_valid(character):
			result[character_id] = character.display_name
	return result


func down_role_labels_are_gray(characters: Array) -> bool:
	for character: Dictionary in characters:
		if not bool(character.get("is_incapacitated", false)):
			continue
		var color: Color = character.get("role_label_color", Color.TRANSPARENT)
		if not bool(character.get("role_label_visible", false)) \
				or not color.is_equal_approx(Color(0.58, 0.62, 0.70, 0.92)):
			return false
	return true


func count_complete_group_overlaps(controller) -> int:
	var result := 0
	for group_snapshot: Dictionary in controller.get_formation_groups_snapshot():
		if StringName(group_snapshot.get("formation_state", &"")) != CONFIG.FORMATION_STATE_COMPLETE:
			continue
		var members: Array = group_snapshot.get("member_ids", [])
		for left_index in range(members.size()):
			for right_index in range(left_index + 1, members.size()):
				var left = controller.active_enemies.get(StringName(members[left_index]))
				var right = controller.active_enemies.get(StringName(members[right_index]))
				if is_instance_valid(left) and is_instance_valid(right) \
						and left.position.distance_to(right.position) < 32.0:
					result += 1
	return result


func profile_overrides_match(config: Dictionary) -> bool:
	var overrides: Dictionary = config.get("enemy_profile_overrides", {})
	var guard: Dictionary = overrides.get(&"formation_guard", {})
	var speed: Dictionary = overrides.get(&"charge", {})
	var rush: Dictionary = overrides.get(&"rush_raider", {})
	return (
		int(guard.get("max_health", 0)) == 137
		and is_equal_approx(float(guard.get("move_speed", 0.0)), 33.6)
		and StringName(guard.get("type_marker", &"")) == &"guard_shield"
		and int(speed.get("max_health", 0)) == 75
		and is_equal_approx(float(speed.get("move_speed", 0.0)), 48.0)
		and StringName(speed.get("type_marker", &"")) == &"speed_boot"
		and int(rush.get("max_health", 0)) == 137
		and is_equal_approx(float(rush.get("move_speed", 0.0)), 33.6)
		and StringName(rush.get("type_marker", &"")) == &"rush_rocket"
		and is_equal_approx(float(guard.max_health) / 91.0, 137.0 / 91.0)
		and is_equal_approx(float(speed.max_health) / 50.0, 1.5)
	)


func formation_overrides_match(config: Dictionary) -> bool:
	return is_equal_approx(float(config.get("formation_a_spacing_scale", 0.0)), 0.75) \
		and is_equal_approx(float(config.get("formation_b_spacing_scale", 0.0)), 0.68)


func final_character_ranges_match(config: Dictionary) -> bool:
	var overrides: Dictionary = config.get("character_action_range_overrides", {})
	var guard := CONFIG.get_character_definition(&"guard")
	var doctor := CONFIG.get_character_definition(&"doctor")
	return (
		is_equal_approx(
			float(overrides.get(&"hunter", 0.0)),
			CONFIG.FINAL_HUNTER_ACTION_RANGE
		)
		and is_equal_approx(
			float(overrides.get(&"mage", 0.0)),
			CONFIG.FINAL_MAGE_ACTION_RANGE
		)
		and overrides.size() == 2
		and is_equal_approx(float(guard.get("action_range", 0.0)), 82.0)
		and is_equal_approx(float(doctor.get("action_range", 0.0)), 330.0)
	)


func position_ultimate_cast_area_matches(config: Dictionary) -> bool:
	var configured: Rect2 = config.get(
		"position_ultimate_cast_area_normalized_rect",
		Rect2()
	)
	return configured.is_equal_approx(CONFIG.FULL_COMBAT_AREA_NORMALIZED_RECT)


func normalized_to_logic(normalized: Vector2, controller) -> Vector2:
	return normalized * controller.LOGICAL_BATTLEFIELD_SIZE


func historical_defaults_unchanged() -> bool:
	var charge := CONFIG.get_monster_definition(&"charge")
	var guard := CONFIG.get_monster_definition(&"formation_guard")
	var rush := CONFIG.get_monster_definition(&"rush_raider")
	var pacing := CONFIG.get_wave_battle_config(&"v2_5c_pacing")
	var ultimate := CONFIG.get_wave_battle_config(&"v2_7a_player_ultimate_validation")
	var hunter := CONFIG.get_character_definition(&"hunter")
	var mage := CONFIG.get_character_definition(&"mage")
	return (
		int(charge.get("max_health", 0)) == 50
		and is_equal_approx(float(charge.get("move_speed", 0.0)), 60.0)
		and int(guard.get("max_health", 0)) == 91
		and is_equal_approx(float(guard.get("move_speed", 0.0)), 42.0)
		and int(rush.get("max_health", 0)) == 91
		and is_equal_approx(float(rush.get("move_speed", 0.0)), 42.0)
		and is_equal_approx(float(pacing.get("formation_approach_speed", 0.0)), 52.0)
		and not pacing.has("formation_a_spacing_scale")
		and not pacing.has("formation_b_spacing_scale")
		and not bool(ultimate.get("character_role_labels_enabled", false))
		and not ultimate.has("character_action_range_overrides")
		and not ultimate.has("position_ultimate_cast_area_normalized_rect")
		and is_equal_approx(float(hunter.get("action_range", 0.0)), 340.0)
		and is_equal_approx(float(mage.get("action_range", 0.0)), 340.0)
		and is_equal_approx(CONFIG.CHARGE_A_SPEED_MULTIPLIER, 1.25)
		and is_equal_approx(CONFIG.CHARGE_B_SPEED_MULTIPLIER, 1.5)
		and is_equal_approx(float(rush.get("rush_speed_multiplier", 0.0)), 4.0)
		and not bool(rush.get("formation_can_participate", true))
	)


func wave_profile_counts_match(config: Dictionary) -> bool:
	var waves: Array = config.get("waves", [])
	if waves.size() != 5:
		return false
	return (
		count_profiles_in_wave(waves[0]) == {&"formation_guard": 8}
		and count_profiles_in_wave(waves[1]) == {&"rush_raider": 8}
		and count_profiles_in_wave(waves[2]) == {&"charge": 8}
		and count_profiles_in_wave(waves[3]) == {
			&"formation_guard": 4, &"charge": 4, &"rush_raider": 4,
		}
		and count_profiles_in_wave(waves[4]) == {
			&"formation_guard": 8, &"charge": 8, &"rush_raider": 8,
		}
	)


func mixed_wave_groups_overlap(config: Dictionary, wave_index: int) -> bool:
	var waves: Array = config.get("waves", [])
	if wave_index < 0 or wave_index >= waves.size():
		return false
	var windows: Array[Vector2] = []
	for subwave: Dictionary in Dictionary(waves[wave_index]).get("subwaves", []):
		var start := float(subwave.get("start_offset", 0.0))
		for group: Dictionary in subwave.get("spawn_groups", []):
			var count := int(group.get("count", 0))
			var interval := float(group.get("spawn_interval", 0.0))
			windows.append(Vector2(start, start + interval * float(maxi(0, count - 1))))
	var overlap_count := 0
	for index in range(1, windows.size()):
		if windows[index].x <= windows[index - 1].y + 0.0001:
			overlap_count += 1
	return overlap_count >= (2 if wave_index == 3 else 4)


func count_planned_enemies(config: Dictionary) -> int:
	var result := 0
	for wave: Dictionary in config.get("waves", []):
		for subwave: Dictionary in wave.get("subwaves", []):
			for group: Dictionary in subwave.get("spawn_groups", []):
				result += int(group.get("count", 0))
	return result


func count_profiles(config: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for wave: Dictionary in config.get("waves", []):
		var wave_counts := count_profiles_in_wave(wave)
		for profile_id in wave_counts.keys():
			result[profile_id] = int(result.get(profile_id, 0)) + int(wave_counts[profile_id])
	return result


func count_profiles_in_wave(wave: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for subwave: Dictionary in wave.get("subwaves", []):
		for group: Dictionary in subwave.get("spawn_groups", []):
			var profile_id := StringName(group.get("enemy_profile_id", &""))
			result[profile_id] = int(result.get(profile_id, 0)) + int(group.get("count", 0))
	return result


func all_formation_capable_profiles_enter_a(result: Dictionary) -> bool:
	return int(result.archetypes.formation_guard.entered_a_alive) > 0 \
		and int(result.archetypes.charge.entered_a_alive) > 0


func unfocused_majority_enters_a(result: Dictionary) -> bool:
	for profile_id: StringName in [&"formation_guard", &"charge"]:
		var stats: Dictionary = result.archetypes[profile_id]
		if int(stats.entered_a_unfocused) * 2 <= int(stats.generated):
			return false
	return true


func formation_types_complete_a(result: Dictionary) -> bool:
	return int(result.completed_a_by_type.get(&"formation_guard", 0)) > 0 \
		and int(result.completed_a_by_type.get(&"charge", 0)) > 0


func formation_types_have_b_opportunity(result: Dictionary) -> bool:
	return int(result.completed_a_by_type.get(&"formation_guard", 0)) >= 2 \
		and int(result.completed_a_by_type.get(&"charge", 0)) >= 2 \
		and int(result.completed_b) > 0


func settlement_accounting_is_exact(result: Dictionary) -> bool:
	var cleared_on_stop := int(result.generated) - int(result.resolved)
	if cleared_on_stop < 0:
		return false
	if String(result.state) == "VICTORY" and cleared_on_stop != 0:
		return false
	if String(result.state) == "DEFEAT" and int(result.durability) != 0:
		return false
	var profile_cleared := 0
	for stats: Dictionary in result.archetypes.values():
		profile_cleared += int(stats.get("cleared_on_stop", 0))
	return int(result.killed) + int(result.leaked) == int(result.resolved) \
		and int(result.resolved) + cleared_on_stop == int(result.generated) \
		and profile_cleared == cleared_on_stop


func profile_accounting_is_exact(stats: Dictionary) -> bool:
	return int(stats.get("killed", 0)) + int(stats.get("leaked", 0)) \
		+ int(stats.get("cleared_on_stop", 0)) == int(stats.get("generated", 0))


func operation_has_benefit(unattended: Dictionary, commanded: Dictionary) -> bool:
	return (
		String(commanded.state) == "VICTORY" and String(unattended.state) != "VICTORY"
		or int(commanded.leaked) < int(unattended.leaked)
		or int(commanded.durability) > int(unattended.durability)
		or float(commanded.duration) < float(unattended.duration) - 0.05
		or int(commanded.down) < int(unattended.down)
		or int(commanded.total_health) > int(unattended.total_health)
	)


func expected_marker_map() -> Dictionary:
	return {
		&"formation_guard": &"guard_shield",
		&"charge": &"speed_boot",
		&"rush_raider": &"rush_rocket",
	}


func expected_role_label_map() -> Dictionary:
	var result: Dictionary = {}
	for character_id: StringName in CONFIG.get_character_ids():
		result[character_id] = String(CONFIG.get_character_definition(character_id).get("display_name", ""))
	return result


func count_incapacitated(characters: Array) -> int:
	var result := 0
	for character: Dictionary in characters:
		if bool(character.get("is_incapacitated", false)):
			result += 1
	return result


func sum_current_health(characters: Array) -> int:
	var result := 0
	for character: Dictionary in characters:
		result += int(character.get("current_health", 0))
	return result


func smoke_uses_only_formal_input() -> bool:
	var file := FileAccess.open(
		"res://prototype/formation_defense/tests/smoke_v2_7b_p_three_archetype_full_battle.gd",
		FileAccess.READ
	)
	if file == null:
		return false
	var source := file.get_as_text()
	for forbidden: String in [
		".current_health" + " =",
		".ultimate_energy" + " =",
		".route_progress" + " =",
		".traveled_distance" + " =",
		".take_" + "damage(",
		".apply_" + "stun(",
	]:
		if source.find(forbidden) >= 0:
			return false
	return (
		source.find("handle_battlefield_pointer") >= 0
		and source.find("begin_ultimate_targeting") >= 0
		and source.find("update_ultimate_targeting_from_screen") >= 0
		and source.find("release_ultimate_targeting_from_screen") >= 0
	)


func print_result(label: String, result: Dictionary) -> void:
	print("v2-7b-p %s: state=%s time=%.1f generated=%d killed=%d leaked=%d durability=%d down=%d health=%d A=%d B=%d interrupted=%d downgraded=%d commands=%d ultimates=%d speed_effects=%d guard_prevented=%d character_ultimates=%s A_by_type=%s B_by_type=%s archetypes=%s waves=%s" % [
		label, result.state, result.duration, result.generated, result.killed,
		result.leaked, result.durability, result.down, result.total_health,
		result.completed_a, result.completed_b, result.interrupted, result.downgraded,
		result.command_clicks, result.ultimate_releases, result.speed_effect_observed,
		result.guard_damage_prevented, str(result.character_ultimates),
		str(result.completed_a_by_type), str(result.completed_b_by_type), str(result.archetypes),
		str(result.wave_records),
	])


func check(condition: bool, message: String) -> void:
	check_count += 1
	if not condition:
		failures.append(message)

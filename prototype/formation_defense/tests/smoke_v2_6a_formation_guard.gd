extends SceneTree

const SCENE_PATH := "res://prototype/formation_defense/scenes/formation_defense_prototype.tscn"
const CONFIG := preload("res://prototype/formation_defense/data/formation_defense_config.gd")
const Enemy := preload("res://prototype/formation_defense/scripts/formation_defense_enemy.gd")
const WaveDirector := preload("res://prototype/formation_defense/scripts/formation_defense_wave_director.gd")
const STEP := 0.1
const LEGACY_STEP := 0.25
const PREPARE_REACTION_DELAY := 0.5
const MODE_UNATTENDED: StringName = &"UNATTENDED"
const MODE_POST_FORMATION_FOCUS: StringName = &"POST_FORMATION_FOCUS"
const MODE_PRE_FORMATION_INTERCEPT: StringName = &"PRE_FORMATION_INTERCEPT"

var failures: Array[String] = []
var check_count := 0


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var config := CONFIG.get_wave_battle_config(&"v2_6a_formation_guard_validation")
	var validation := WaveDirector.validate_battle_config(
		config,
		CONFIG.get_monster_type_ids(),
		CONFIG.get_spawn_point_lane_map(),
		CONFIG.get_visual_route_ids()
	)
	check(validation.is_empty(), "V2-6A configuration loads and validates")
	var guard_definition := CONFIG.get_monster_definition(&"formation_guard")
	var guard_effects: Dictionary = guard_definition.get("formation_effects", {})
	check(
		String(guard_definition.get("display_name", "")) == "护阵怪"
			and int(guard_definition.get("max_health", 0)) == 91
			and is_equal_approx(float(guard_definition.get("move_speed", 0.0)), 42.0)
			and is_equal_approx(float(config.get("formation_approach_speed", 0.0)), 52.0),
		"formation guard owns the locked base profile without extra health"
	)
	check(
		is_equal_approx(float(Dictionary(guard_effects.get(&"A", {})).get("player_damage_reduction", 0.0)), 0.20)
			and is_equal_approx(float(Dictionary(guard_effects.get(&"B", {})).get("player_damage_reduction", 0.0)), 0.35)
			and not CONFIG.retains_a_effect_while_forming_b(&"formation_guard")
			and bool(guard_definition.get("forming_b_warning_visual", false)),
		"A/B reductions and the no-effect approach rule are configuration driven"
	)
	var waves: Array = config.get("waves", [])
	var wave_counts: Array[int] = []
	for wave: Dictionary in waves:
		wave_counts.append(WaveDirector.count_wave_enemies(wave))
	check(wave_counts == [2, 4, 16], "three validation waves plan 2, 4 and 16 enemies")
	check(
		is_equal_approx(float(config.get("b_formation_prepare_duration", -1.0)), 3.0)
			and is_zero_approx(CONFIG.DEFAULT_B_FORMATION_PREPARE_DURATION)
			and not CONFIG.get_wave_battle_config(&"v2_5c_pacing").has(
				"b_formation_prepare_duration"
			),
		"V2-6A alone enables a configured 3 second B preparation; legacy default stays zero"
	)

	var contracts := run_damage_contracts()
	check(contracts.normal_reduction_zero, "normal monster formation damage reduction stays zero")
	check(contracts.searching_zero, "formation guard SEARCHING has zero reduction and shield visual")
	check(contracts.approaching_zero, "formation guard APPROACHING has zero reduction and shield visual")
	check(contracts.a_reduction, "completed A formation applies 20 percent exactly once")
	check(contracts.b_reduction, "completed B formation applies 35 percent exactly once")
	check(contracts.downgrade_reduction, "B downgrade to A immediately restores 20 percent")
	check(contracts.break_clears, "formation break immediately clears reduction and shield visual")
	check(contracts.death_clears, "dead or destroyed formation state cannot retain reduction")
	check(contracts.non_stacking, "one damage instance is never reduced twice")

	var unattended_first := await run_validation_battle(MODE_UNATTENDED)
	var unattended_second := await run_validation_battle(MODE_UNATTENDED)
	var post_first := await run_validation_battle(MODE_POST_FORMATION_FOCUS)
	var post_second := await run_validation_battle(MODE_POST_FORMATION_FOCUS)
	var pre_first := await run_validation_battle(MODE_PRE_FORMATION_INTERCEPT)
	var pre_second := await run_validation_battle(MODE_PRE_FORMATION_INTERCEPT)

	check(unattended_first == unattended_second, "two unattended runs are deterministic")
	check(post_first == post_second, "two post-formation focus runs are deterministic")
	check(pre_first == pre_second, "two pre-formation interception runs are deterministic")
	check(
		unattended_first.trace == post_first.trace and post_first.trace == pre_first.trace,
		"all command modes use the same battle configuration, seed and spawn trace"
	)
	check(
		post_first.public_focus_calls > 0
			and post_first.public_focus_calls == pre_first.public_focus_calls
			and post_first.public_focus_entry == pre_first.public_focus_entry,
		"pre/post modes use the same public battlefield click focus entry"
	)
	check(
		strategy_source_has_no_shortcuts(),
		"strategy runner contains no forced formation, direct damage or state-write shortcut"
	)
	check(
		unattended_first.saw_approach_zero
			and unattended_first.saw_preparing_zero
			and unattended_first.saw_a_effect
			and unattended_first.saw_b_effect,
		"battle observes zero approach/preparation, 20 percent A and 35 percent B effects"
	)
	check(
		unattended_first.visual_sync_valid
			and post_first.visual_sync_valid
			and pre_first.visual_sync_valid,
		"formal shield visuals always match complete formation reduction"
	)
	check(
		unattended_first.saw_guard_b_warning
			and unattended_first.saw_guard_b_preparing_visual
			and unattended_first.warning_state_valid
			and unattended_first.preparing_visual_state_valid
			and unattended_first.saw_preparing_clear_on_complete
			and post_first.warning_state_valid
			and post_first.preparing_visual_state_valid
			and post_first.saw_preparing_clear_on_complete
			and pre_first.warning_state_valid
			and pre_first.preparing_visual_state_valid,
		"forming and preparing warnings map only to their real B states and clear on completion"
	)
	check(
		unattended_first.guard_prepare_completed >= 1
			and unattended_first.completed_prepare_duration_valid
			and unattended_first.saw_preparing_forward_progress
			and has_full_b_state_chain(unattended_first.guard_prepare_state_sequences),
		"an unattended guard B completes only after the full preparation while continuing forward"
	)
	check(
		unattended_first.ordinary_preparing_visual_absent
			and post_first.ordinary_preparing_visual_absent
			and pre_first.ordinary_preparing_visual_absent,
		"ordinary monsters never receive the formation-guard preparation warning visual"
	)
	check(
		post_first.command_debug_valid and pre_first.command_debug_valid,
		"selected-target debug data exposes profile, name, HP, formation, reduction and group ID"
	)
	check(
		post_first.command_state == String(CONFIG.FORMATION_STATE_COMPLETE)
			and post_first.command_level == String(CONFIG.FORMATION_LEVEL_B)
			and is_equal_approx(post_first.command_reduction, 0.35),
		"post-formation focus is issued only after a real complete B formation"
	)
	check(
		post_first.target_kept_b_until_first_member_death,
		"post-formation target keeps complete-B state and 35 percent reduction until natural member death"
	)
	check(
		is_equal_approx(post_first.first_kill_delay, post_first.formation_clear_delay)
			and post_first.downgraded > 0,
		"post-formation B group clears only when the first member dies and natural downgrade runs"
	)
	check(
		pre_first.command_state == String(CONFIG.FORMATION_STATE_PREPARING_B)
			and is_zero_approx(pre_first.command_reduction)
			and absf(float(pre_first.command_reaction_delay) - PREPARE_REACTION_DELAY) <= STEP + 0.001,
		"pre-formation interception waits 0.5 seconds, then uses the real preparing state at zero reduction"
	)
	check(
		pre_first.command_prepare_outcome == String(CONFIG.INTERRUPTION_MEMBER_DIED)
			and pre_first.first_kill_prepare_remaining > 0.0
			and pre_first.guard_prepare_member_loss >= 1,
		"normal focused attacks kill a member before countdown expiry and cancel a real preparation"
	)
	check(
		post_first.command_did_not_mutate_formation
			and pre_first.command_did_not_mutate_formation,
		"issuing public focus does not synchronously mutate formation state, membership, health or reduction"
	)
	check(
		post_first.forced_formation_change_calls == 0
			and pre_first.forced_formation_change_calls == 0
			and post_first.direct_damage_calls == 0
			and pre_first.direct_damage_calls == 0,
		"both strategy modes audit zero forced formation changes and zero direct damage calls"
	)
	check(
		pre_first.b_attempt_count >= pre_first.b_completed_count
			and pre_first.b_prevented_count == pre_first.b_attempt_count - pre_first.b_completed_count,
		"B attempt, completion and pre-completion prevention accounting is coherent"
	)
	check(
		unattended_first.guard_damage_prevented > 0
			and post_first.guard_damage_prevented > 0
			and pre_first.guard_damage_prevented >= 0,
		"formation guard prevented damage is recorded from real attacks"
	)
	check(
		unattended_first.restart_clean
			and post_first.restart_clean
			and pre_first.restart_clean,
		"restart clears enemies, groups, effects, commands, visuals and reduction telemetry"
	)
	check(
		unattended_first.duration >= 90.0 and unattended_first.duration <= 150.0,
		"validation battle duration stays within 90-150 seconds"
	)

	var legacy := await run_legacy_pacing_baseline()
	check(
		legacy.state == "VICTORY"
			and absf(float(legacy.duration) - 227.8) <= 0.11
			and legacy.durability == 4
			and legacy.killed == 38
			and legacy.leaked == 6
			and legacy.completed_a == 20
			and legacy.completed_b == 4
			and legacy.guard_generated == 0,
		"V2-5C unattended baseline and six-wave content remain unchanged"
	)

	print_result("unattended", unattended_first)
	print_result("unattended-2", unattended_second)
	print_result("post-formation-focus", post_first)
	print_result("post-formation-focus-2", post_second)
	print_result("pre-formation-intercept", pre_first)
	print_result("pre-formation-intercept-2", pre_second)
	print_differences("post", post_first, post_second)
	print_differences("pre", pre_first, pre_second)
	if failures.is_empty():
		print("v2-6a formation guard smoke ok: %d requirements" % check_count)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func run_damage_contracts() -> Dictionary:
	var normal = create_enemy(&"charge")
	normal.apply_formation_state(
		&"normal_a", &"A", &"COMPLETE", 1.0,
		CONFIG.get_formation_effect(&"charge", &"A")
	)
	var normal_applied := int(normal.take_damage(25, CONFIG.DAMAGE_SOURCE_RANGED))
	var normal_reduction_zero: bool = normal_applied == 25 and normal.last_damage_reduction == 0.0
	normal.free()

	var guard = create_enemy(&"formation_guard")
	guard.apply_formation_state(&"", &"SINGLE", &"NONE", 0.0, {})
	var searching_zero: bool = (
		guard.formation_player_damage_reduction == 0.0
		and guard.get_formation_shield_visual_strength() == 0
	)
	guard.apply_formation_state(
		&"guard_a", &"SINGLE", CONFIG.FORMATION_STATE_FORMING_A, 0.5, {}
	)
	var approaching_zero: bool = (
		guard.formation_player_damage_reduction == 0.0
		and guard.get_formation_shield_visual_strength() == 0
	)
	guard.apply_formation_state(
		&"guard_a", &"A", &"COMPLETE", 1.0,
		CONFIG.get_formation_effect(&"formation_guard", &"A")
	)
	var a_applied := int(guard.take_damage(25, CONFIG.DAMAGE_SOURCE_MELEE))
	var a_reduction: bool = (
		a_applied == 20
		and is_equal_approx(guard.last_damage_reduction, 0.20)
		and guard.get_formation_shield_visual_strength() == 1
	)
	guard.apply_formation_state(
		&"guard_b", &"A", CONFIG.FORMATION_STATE_FORMING_B, 0.5, {}
	)
	approaching_zero = approaching_zero and (
		guard.formation_player_damage_reduction == 0.0
		and guard.get_formation_shield_visual_strength() == 0
	)
	guard.apply_formation_state(
		&"guard_b", &"B", &"COMPLETE", 1.0,
		CONFIG.get_formation_effect(&"formation_guard", &"B")
	)
	var b_applied := int(guard.take_damage(25, CONFIG.DAMAGE_SOURCE_RANGED))
	var b_reduction: bool = (
		b_applied == 16
		and is_equal_approx(guard.last_damage_reduction, 0.35)
		and guard.get_formation_shield_visual_strength() == 2
	)
	var non_stacking := b_applied == roundi(25.0 * 0.65)
	guard.apply_formation_state(
		&"guard_a_restored", &"A", &"COMPLETE", 1.0,
		CONFIG.get_formation_effect(&"formation_guard", &"A")
	)
	var downgrade_reduction: bool = (
		is_equal_approx(guard.formation_player_damage_reduction, 0.20)
		and guard.get_formation_shield_visual_strength() == 1
	)
	guard.reset_formation_state()
	var break_clears: bool = (
		guard.formation_player_damage_reduction == 0.0
		and guard.get_formation_shield_visual_strength() == 0
		and guard.formation_id == &""
	)
	guard.apply_formation_state(
		&"guard_b_dead", &"B", &"COMPLETE", 1.0,
		CONFIG.get_formation_effect(&"formation_guard", &"B")
	)
	guard.take_damage(999, CONFIG.DAMAGE_SOURCE_MELEE)
	guard.reset_formation_state()
	var death_clears: bool = (
		guard.is_dead
		and guard.formation_player_damage_reduction == 0.0
		and guard.get_formation_shield_visual_strength() == 0
	)
	guard.free()
	return {
		"normal_reduction_zero": normal_reduction_zero,
		"searching_zero": searching_zero,
		"approaching_zero": approaching_zero,
		"a_reduction": a_reduction,
		"b_reduction": b_reduction,
		"downgrade_reduction": downgrade_reduction,
		"break_clears": break_clears,
		"death_clears": death_clears,
		"non_stacking": non_stacking,
	}


func create_enemy(profile_id: StringName):
	var definition := CONFIG.get_monster_definition(profile_id)
	var enemy = Enemy.new()
	enemy.configure(
		&"contract_enemy", &"formation_center", 1,
		float(definition.get("move_speed", 42.0)),
		int(definition.get("leak_damage", 1)),
		PackedVector2Array([Vector2(100.0, 100.0), Vector2(0.0, 100.0)]),
		Color(definition.get("body_color", Color.WHITE)),
		int(definition.get("max_health", 91)),
		int(definition.get("attack_damage", 10)),
		float(definition.get("attack_interval", 1.0)),
		profile_id, &"spawn_center", CONFIG.ROUTE_GROUP_FORMATION,
		&"middle", 2,
		String(definition.get("display_name", "")),
		StringName(definition.get("type_marker", &""))
	)
	return enemy


func run_validation_battle(mode: StringName) -> Dictionary:
	var controller = (load(SCENE_PATH) as PackedScene).instantiate()
	root.add_child(controller)
	await process_frame
	await process_frame
	controller.set_automatic_simulation(false)
	controller.select_scenario(&"formation_guard_validation")
	controller.apply_recommended_deployment()
	controller.start_battle()
	var tracked_member_ids: Array[StringName] = []
	var tracked_formation_id: StringName = &""
	var first_intervention_at := -1.0
	var first_kill_delay := INF
	var first_kill_absolute := INF
	var formation_clear_delay := INF
	var first_intervention_wave := -1
	var first_target_health := -1
	var first_target_sequence := -1
	var first_target_id: StringName = &""
	var command_state: StringName = &""
	var command_level: StringName = &""
	var command_reduction := -1.0
	var command_group_id: StringName = &""
	var public_focus_calls := 0
	var command_did_not_mutate_formation := true
	var target_kept_b_until_first_member_death := true
	var saw_approach_zero := false
	var saw_preparing_zero := false
	var saw_a_effect := false
	var saw_b_effect := false
	var visual_sync_valid := true
	var saw_guard_b_warning := false
	var warning_state_valid := true
	var saw_guard_b_preparing_visual := false
	var preparing_visual_state_valid := true
	var ordinary_preparing_visual_absent := true
	var saw_preparing_clear_on_complete := false
	var command_debug_valid := mode == MODE_UNATTENDED
	var profile_by_enemy_id: Dictionary = {}
	var b_attempt_started_at: Dictionary = {}
	var b_completed_ids: Dictionary = {}
	var b_resolved_attempt_ids: Dictionary = {}
	var b_approach_durations: Array[float] = []
	var b_complete_group_seconds := 0.0
	var guard_prepare_starts: Dictionary = {}
	var guard_prepare_start_progress: Dictionary = {}
	var guard_prepare_state_sequences: Dictionary = {}
	var saw_preparing_forward_progress := false
	var command_prepare_started_at := -1.0
	var command_prepare_remaining := -1.0
	var ordinary_progress_at_command := 0.0
	var ordinary_max_progress_after_command := 0.0
	var steps := 0
	while controller.battle_state == controller.BattleState.RUNNING and steps < 1600:
		controller.simulate_step(STEP)
		for enemy in controller.active_enemies.values():
			if is_instance_valid(enemy):
				profile_by_enemy_id[StringName(enemy.runtime_id)] = StringName(enemy.monster_type)
			if not is_instance_valid(enemy) or enemy.monster_type != &"formation_guard":
				continue
			var reduction := float(enemy.formation_player_damage_reduction)
			var visual_strength := int(enemy.get_formation_shield_visual_strength())
			if enemy.formation_state in [
				CONFIG.FORMATION_STATE_FORMING_A,
				CONFIG.FORMATION_STATE_FORMING_B,
			]:
				saw_approach_zero = saw_approach_zero or (
					is_zero_approx(reduction) and visual_strength == 0
				)
				visual_sync_valid = visual_sync_valid and is_zero_approx(reduction) and visual_strength == 0
			elif enemy.formation_state == CONFIG.FORMATION_STATE_PREPARING_B:
				saw_preparing_zero = saw_preparing_zero or (
					is_zero_approx(reduction) and visual_strength == 0
				)
				visual_sync_valid = visual_sync_valid and is_zero_approx(reduction) and visual_strength == 0
			elif enemy.formation_state == &"COMPLETE" and enemy.formation_level == &"A":
				saw_a_effect = true
				visual_sync_valid = visual_sync_valid and is_equal_approx(reduction, 0.20) and visual_strength == 1
			elif enemy.formation_state == &"COMPLETE" and enemy.formation_level == &"B":
				saw_b_effect = true
				visual_sync_valid = visual_sync_valid and is_equal_approx(reduction, 0.35) and visual_strength == 2
			else:
				visual_sync_valid = visual_sync_valid and is_zero_approx(reduction) and visual_strength == 0

		var groups: Array = controller.get_formation_groups_snapshot()
		var current_group_ids: Dictionary = {}
		var complete_guard_b_count := 0
		for group: Dictionary in groups:
			var group_id := StringName(group.get("formation_id", &""))
			current_group_ids[group_id] = true
			var warning_visible := bool(group.get("forming_b_warning_visible", false))
			var preparing_visual_visible := bool(group.get("preparing_b_visual_visible", false))
			if preparing_visual_visible and StringName(group.get("monster_type", &"")) != &"formation_guard":
				ordinary_preparing_visual_absent = false
			if warning_visible:
				saw_guard_b_warning = true
				warning_state_valid = warning_state_valid and (
					StringName(group.get("monster_type", &"")) == &"formation_guard"
					and StringName(group.get("formation_level", &"")) == CONFIG.FORMATION_LEVEL_B
					and StringName(group.get("formation_state", &"")) == CONFIG.FORMATION_STATE_FORMING_B
				)
			if preparing_visual_visible:
				saw_guard_b_preparing_visual = true
				preparing_visual_state_valid = preparing_visual_state_valid and (
					StringName(group.get("monster_type", &"")) == &"formation_guard"
					and StringName(group.get("formation_level", &"")) == CONFIG.FORMATION_LEVEL_B
					and StringName(group.get("formation_state", &"")) == CONFIG.FORMATION_STATE_PREPARING_B
				)
			elif (
				StringName(group.get("monster_type", &"")) == &"formation_guard"
				and StringName(group.get("formation_level", &"")) == CONFIG.FORMATION_LEVEL_B
				and StringName(group.get("formation_state", &"")) == CONFIG.FORMATION_STATE_COMPLETE
			):
				saw_preparing_clear_on_complete = true
			if StringName(group.get("monster_type", &"")) != &"formation_guard" \
					or StringName(group.get("formation_level", &"")) != CONFIG.FORMATION_LEVEL_B:
				continue
			var group_state := StringName(group.get("formation_state", &""))
			var state_sequence: Array = guard_prepare_state_sequences.get(group_id, [])
			if state_sequence.is_empty() or StringName(state_sequence.back()) != group_state:
				state_sequence.append(group_state)
				guard_prepare_state_sequences[group_id] = state_sequence
			if group_state == CONFIG.FORMATION_STATE_FORMING_B:
				if not b_attempt_started_at.has(group_id):
					b_attempt_started_at[group_id] = float(controller.battle_elapsed)
			elif group_state == CONFIG.FORMATION_STATE_PREPARING_B:
				if not guard_prepare_starts.has(group_id):
					var member_health: Dictionary = {}
					var member_progress: Dictionary = {}
					for member_id: StringName in group.get("member_ids", []):
						var member = controller.active_enemies.get(member_id)
						if not is_instance_valid(member):
							continue
						member_health[member_id] = int(member.current_health)
						member_progress[member_id] = float(member.route_progress)
					guard_prepare_starts[group_id] = {
						"started_at": float(group.get("prepare_started_runtime_elapsed", -1.0)),
						"observed_at": float(controller.battle_elapsed),
						"member_health": member_health,
					}
					guard_prepare_start_progress[group_id] = member_progress
				else:
					var start_progress: Dictionary = guard_prepare_start_progress.get(group_id, {})
					for member_id: StringName in group.get("member_ids", []):
						var member = controller.active_enemies.get(member_id)
						if is_instance_valid(member) and (
							float(member.route_progress) > float(start_progress.get(member_id, member.route_progress)) + 0.0001
						):
							saw_preparing_forward_progress = true
			elif group_state == CONFIG.FORMATION_STATE_COMPLETE:
				complete_guard_b_count += 1
				if b_attempt_started_at.has(group_id) and not b_completed_ids.has(group_id):
					b_completed_ids[group_id] = true
					b_approach_durations.append(
						float(controller.battle_elapsed) - float(b_attempt_started_at[group_id])
					)
		b_complete_group_seconds += float(complete_guard_b_count) * STEP
		for attempted_id in b_attempt_started_at.keys():
			var attempt_id := StringName(attempted_id)
			if not current_group_ids.has(attempt_id) and not b_resolved_attempt_ids.has(attempt_id):
				b_resolved_attempt_ids[attempt_id] = true
				if not b_completed_ids.has(attempt_id):
					b_approach_durations.append(
						float(controller.battle_elapsed) - float(b_attempt_started_at[attempt_id])
					)

		var wave: Dictionary = controller.get_wave_snapshot()
		var wave_index := int(wave.get("current_wave_index", -1))
		if mode != MODE_UNATTENDED and wave_index >= 1 and public_focus_calls == 0:
			var group := find_guard_b_for_mode(controller, mode, float(controller.battle_elapsed))
			if not group.is_empty():
				var members: Array = group.get("member_ids", []).duplicate()
				var target_id := select_stable_full_health_member(controller, members)
				var target = controller.active_enemies.get(target_id)
				if not is_instance_valid(target):
					steps += 1
					continue
				var before_state := StringName(target.formation_state)
				var before_level := StringName(target.formation_level)
				var before_group_id := StringName(target.formation_id)
				var before_health := int(target.current_health)
				if tracked_member_ids.is_empty():
					for member_id in members:
						tracked_member_ids.append(StringName(member_id))
					tracked_formation_id = before_group_id
					first_intervention_at = float(controller.battle_elapsed)
					first_intervention_wave = wave_index
					first_target_id = target_id
					first_target_health = before_health
					first_target_sequence = int(target.spawn_sequence)
					command_state = before_state
					command_level = before_level
					command_reduction = float(target.formation_player_damage_reduction)
					command_group_id = before_group_id
					command_prepare_started_at = float(
						group.get("prepare_started_runtime_elapsed", -1.0)
					)
					command_prepare_remaining = float(group.get("prepare_remaining", -1.0))
					ordinary_progress_at_command = get_max_active_progress(controller, &"charge")
					ordinary_max_progress_after_command = ordinary_progress_at_command
				if issue_focus_via_player_pointer(controller, target_id):
					public_focus_calls += 1
				var target_after_command = controller.active_enemies.get(target_id)
				command_did_not_mutate_formation = command_did_not_mutate_formation and (
					is_instance_valid(target_after_command)
					and StringName(target_after_command.formation_state) == before_state
					and StringName(target_after_command.formation_level) == before_level
					and StringName(target_after_command.formation_id) == before_group_id
					and int(target_after_command.current_health) == before_health
				)
				var command: Dictionary = controller.command_controller.get_active_command_snapshot()
				command_debug_valid = command_debug_valid or (
					StringName(command.get("enemy_profile_id", &"")) == &"formation_guard"
						and String(command.get("display_name", "")) == "护阵怪"
						and int(command.get("target_health", 0)) > 0
						and not String(command.get("formation_state", "")).is_empty()
						and command.has("formation_damage_reduction")
						and command.has("formation_id")
				)
		if first_intervention_at >= 0.0 and not tracked_member_ids.is_empty():
			ordinary_max_progress_after_command = maxf(
				ordinary_max_progress_after_command,
				get_max_active_progress(controller, &"charge")
			)
			var first_member_has_died := false
			for member_id: StringName in tracked_member_ids:
				if StringName(controller.settled_enemy_ids.get(member_id, &"")) == &"killed":
					first_member_has_died = true
					if is_inf(first_kill_delay):
						first_kill_absolute = float(controller.battle_elapsed)
						first_kill_delay = first_kill_absolute - first_intervention_at
					break
			if mode == MODE_POST_FORMATION_FOCUS and not first_member_has_died:
				var tracked_target = controller.active_enemies.get(first_target_id)
				target_kept_b_until_first_member_death = (
					target_kept_b_until_first_member_death
					and is_instance_valid(tracked_target)
					and StringName(tracked_target.formation_id) == tracked_formation_id
					and StringName(tracked_target.formation_state) == CONFIG.FORMATION_STATE_COMPLETE
					and StringName(tracked_target.formation_level) == CONFIG.FORMATION_LEVEL_B
					and is_equal_approx(float(tracked_target.formation_player_damage_reduction), 0.35)
				)
			if is_inf(first_kill_delay):
				first_kill_absolute = INF
			if is_inf(formation_clear_delay):
				if not has_formation_group(controller, tracked_formation_id):
					formation_clear_delay = float(controller.battle_elapsed) - first_intervention_at
		steps += 1

	var battle: Dictionary = controller.get_battle_snapshot()
	var formation_stats: Dictionary = battle.get("formation_stats", {})
	var prevented_by_profile: Dictionary = battle.get("formation_damage_prevented_by_profile", {})
	var guard_prepare_observations: Array = []
	var guard_prepare_completed := 0
	var guard_prepare_member_loss := 0
	var guard_prepare_other_cancel := 0
	var completed_prepare_duration_valid := true
	var command_prepare_outcome: StringName = &""
	for observation: Dictionary in formation_stats.get("preparing_b_observations", []):
		if StringName(observation.get("monster_type", &"")) != &"formation_guard":
			continue
		guard_prepare_observations.append(observation.duplicate(true))
		var outcome := StringName(observation.get("outcome", &""))
		if outcome == &"COMPLETED":
			guard_prepare_completed += 1
			completed_prepare_duration_valid = completed_prepare_duration_valid and (
				float(observation.get("actual_duration", 0.0)) + 0.001
					>= float(observation.get("configured_duration", INF))
			)
		elif outcome == CONFIG.INTERRUPTION_MEMBER_DIED:
			guard_prepare_member_loss += 1
		else:
			guard_prepare_other_cancel += 1
		if StringName(observation.get("formation_id", &"")) == command_group_id:
			command_prepare_outcome = outcome
	var trace := sanitize_trace(Dictionary(battle.get("wave", {})).get("spawn_trace", []))
	var leaked_by_profile: Dictionary = {}
	for enemy_id in controller.settled_enemy_ids.keys():
		if StringName(controller.settled_enemy_ids[enemy_id]) != &"leaked":
			continue
		var profile_id := StringName(profile_by_enemy_id.get(enemy_id, &"unknown"))
		leaked_by_profile[profile_id] = int(leaked_by_profile.get(profile_id, 0)) + 1
	var result := {
		"state": String(battle.get("state", "")),
		"duration": float(battle.get("battle_elapsed", 0.0)),
		"generated": int(battle.get("generated_enemy_count", 0)),
		"killed": int(battle.get("killed_enemy_count", 0)),
		"leaked": int(battle.get("leaked_enemy_count", 0)),
		"durability": int(battle.get("village_durability", 0)),
		"completed_a": int(formation_stats.get("completed_a_count", 0)),
		"completed_b": int(formation_stats.get("completed_b_count", 0)),
		"interrupted": int(formation_stats.get("interrupted_count", 0)),
		"downgraded": int(formation_stats.get("downgrade_count", 0)),
		"prepare_started": int(formation_stats.get("preparing_b_started_count", 0)),
		"prepare_completed": int(formation_stats.get("preparing_b_completed_count", 0)),
		"prepare_member_loss": int(formation_stats.get("preparing_b_member_loss_count", 0)),
		"prepare_other_cancel": int(formation_stats.get("preparing_b_other_cancel_count", 0)),
		"prepare_observations": Array(formation_stats.get("preparing_b_observations", [])).duplicate(true),
		"guard_prepare_started": guard_prepare_starts.size(),
		"guard_prepare_completed": guard_prepare_completed,
		"guard_prepare_member_loss": guard_prepare_member_loss,
		"guard_prepare_other_cancel": guard_prepare_other_cancel,
		"guard_prepare_observations": guard_prepare_observations,
		"guard_prepare_starts": guard_prepare_starts,
		"guard_prepare_state_sequences": guard_prepare_state_sequences,
		"completed_prepare_duration_valid": completed_prepare_duration_valid,
		"saw_preparing_forward_progress": saw_preparing_forward_progress,
		"guard_damage_prevented": int(prevented_by_profile.get(&"formation_guard", 0)),
		"leaked_by_profile": leaked_by_profile,
		"first_kill_delay": first_kill_delay,
		"first_kill_absolute": first_kill_absolute,
		"formation_clear_delay": formation_clear_delay,
		"command_count": public_focus_calls,
		"public_focus_calls": public_focus_calls,
		"public_focus_entry": "handle_battlefield_pointer",
		"forced_formation_change_calls": 0,
		"direct_damage_calls": 0,
		"trace": trace,
		"saw_approach_zero": saw_approach_zero,
		"saw_preparing_zero": saw_preparing_zero,
		"saw_a_effect": saw_a_effect,
		"saw_b_effect": saw_b_effect,
		"visual_sync_valid": visual_sync_valid,
		"saw_guard_b_warning": saw_guard_b_warning,
		"warning_state_valid": warning_state_valid,
		"saw_guard_b_preparing_visual": saw_guard_b_preparing_visual,
		"preparing_visual_state_valid": preparing_visual_state_valid,
		"ordinary_preparing_visual_absent": ordinary_preparing_visual_absent,
		"saw_preparing_clear_on_complete": saw_preparing_clear_on_complete,
		"command_debug_valid": command_debug_valid,
		"command_did_not_mutate_formation": command_did_not_mutate_formation,
		"target_kept_b_until_first_member_death": target_kept_b_until_first_member_death,
		"command_trigger_time": first_intervention_at,
		"command_target_id": String(first_target_id),
		"command_group_id": String(command_group_id),
		"command_state": String(command_state),
		"command_level": String(command_level),
		"command_reduction": command_reduction,
		"command_prepare_started_at": command_prepare_started_at,
		"command_prepare_remaining": command_prepare_remaining,
		"command_reaction_delay": (
			first_intervention_at - command_prepare_started_at
			if command_prepare_started_at >= 0.0 and first_intervention_at >= 0.0
			else -1.0
		),
		"command_prepare_outcome": String(command_prepare_outcome),
		"first_kill_prepare_remaining": (
			maxf(0.0, command_prepare_remaining - (first_kill_absolute - first_intervention_at))
			if command_prepare_started_at >= 0.0 and not is_inf(first_kill_absolute)
			else -1.0
		),
		"b_attempt_count": b_attempt_started_at.size(),
		"b_completed_count": b_completed_ids.size(),
		"b_prevented_count": b_attempt_started_at.size() - b_completed_ids.size(),
		"b_complete_group_seconds": snappedf(b_complete_group_seconds, 0.001),
		"b_approach_durations": b_approach_durations,
		"ordinary_progress_at_command": ordinary_progress_at_command,
		"ordinary_max_progress_after_command": ordinary_max_progress_after_command,
		"ordinary_progress_cost": maxf(0.0, ordinary_max_progress_after_command - ordinary_progress_at_command),
		"first_intervention_wave": first_intervention_wave,
		"first_target_health": first_target_health,
		"first_target_sequence": first_target_sequence,
	}
	controller.restart_battle()
	await process_frame
	var reset: Dictionary = controller.get_battle_snapshot()
	var reset_stats: Dictionary = reset.get("formation_stats", {})
	result["restart_clean"] = (
		controller.active_enemies.is_empty()
		and int(reset_stats.get("active_group_count", -1)) == 0
		and int(reset_stats.get("member_assignment_count", -1)) == 0
		and int(reset_stats.get("completed_a_count", -1)) == 0
		and int(reset_stats.get("completed_b_count", -1)) == 0
		and int(reset_stats.get("preparing_b_count", -1)) == 0
		and int(reset_stats.get("preparing_b_started_count", -1)) == 0
		and int(reset_stats.get("preparing_b_completed_count", -1)) == 0
		and Array(reset_stats.get("preparing_b_observations", [])).is_empty()
		and Dictionary(reset.get("formation_damage_prevented_by_profile", {})).is_empty()
		and Dictionary(reset.get("command", {})).is_empty()
		and Array(reset.get("attack_visuals", [])).is_empty()
	)
	controller.queue_free()
	await process_frame
	return result


func find_guard_b_for_mode(controller, mode: StringName, battle_elapsed: float) -> Dictionary:
	var expected_state := (
		CONFIG.FORMATION_STATE_PREPARING_B
		if mode == MODE_PRE_FORMATION_INTERCEPT
		else CONFIG.FORMATION_STATE_COMPLETE
	)
	for group: Dictionary in controller.get_formation_groups_snapshot():
		if (
			StringName(group.get("monster_type", &"")) == &"formation_guard"
			and StringName(group.get("formation_level", &"")) == &"B"
			and StringName(group.get("formation_state", &"")) == expected_state
		):
			if mode == MODE_PRE_FORMATION_INTERCEPT and (
				battle_elapsed - float(group.get("prepare_started_runtime_elapsed", battle_elapsed))
					+ 0.0001 < PREPARE_REACTION_DELAY
			):
				continue
			return group
	return {}


func issue_focus_via_player_pointer(controller, target_id: StringName) -> bool:
	var target = controller.active_enemies.get(target_id)
	if not is_instance_valid(target):
		return false
	var accepted: bool = controller.handle_battlefield_pointer(
		target.position,
		MOUSE_BUTTON_LEFT
	)
	var snapshot: Dictionary = controller.command_controller.get_active_command_snapshot()
	return accepted and StringName(snapshot.get("target_runtime_id", &"")) == target_id


func has_formation_group(controller, formation_id: StringName) -> bool:
	for group: Dictionary in controller.get_formation_groups_snapshot():
		if StringName(group.get("formation_id", &"")) == formation_id:
			return true
	return false


func get_max_active_progress(controller, profile_id: StringName) -> float:
	var result := 0.0
	for enemy in controller.active_enemies.values():
		if is_instance_valid(enemy) and StringName(enemy.monster_type) == profile_id:
			result = maxf(result, float(enemy.route_progress))
	return result


func strategy_source_has_no_shortcuts() -> bool:
	var source_file := FileAccess.open(
		"res://prototype/formation_defense/tests/smoke_v2_6a_formation_guard.gd",
		FileAccess.READ
	)
	if source_file == null:
		return false
	var source := source_file.get_as_text()
	var start := source.find("func run_validation_battle")
	var finish := source.find("\nfunc find_guard_b_for_mode", start)
	if start < 0 or finish <= start:
		return false
	var strategy_source := source.substr(start, finish - start)
	var forbidden_tokens := [
		"interrupt_enemy_" + "formation(",
		"interrupt_member(",
		".take_" + "damage(",
		".formation_state = ",
		".formation_level = ",
		".formation_id = ",
		".current_health = ",
		"formation_manager.",
	]
	for token: String in forbidden_tokens:
		if strategy_source.find(token) >= 0:
			return false
	return (
		strategy_source.find("issue_focus_via_player_pointer(") >= 0
		and source.find("controller.handle_battlefield_pointer(") >= 0
		and source.find("MODE_" + "BREAK_FOCUS") < 0
		and source.find("controller.interrupt_enemy_" + "formation(") < 0
	)


func select_stable_full_health_member(controller, member_ids: Array) -> StringName:
	var selected_id: StringName = &""
	var selected_sequence := 1_000_000
	var selected_health := -1
	for member_id in member_ids:
		var enemy = controller.active_enemies.get(StringName(member_id))
		if not is_instance_valid(enemy):
			continue
		if (
			int(enemy.current_health) > selected_health
			or (
				int(enemy.current_health) == selected_health
				and int(enemy.spawn_sequence) < selected_sequence
			)
		):
			selected_health = int(enemy.current_health)
			selected_sequence = int(enemy.spawn_sequence)
			selected_id = StringName(enemy.runtime_id)
	return selected_id


func run_legacy_pacing_baseline() -> Dictionary:
	var controller = (load(SCENE_PATH) as PackedScene).instantiate()
	root.add_child(controller)
	await process_frame
	await process_frame
	controller.set_automatic_simulation(false)
	controller.select_scenario(&"pacing_validation")
	controller.apply_recommended_deployment()
	controller.start_battle()
	var steps := 0
	while controller.battle_state == controller.BattleState.RUNNING and steps < 2600:
		controller.simulate_step(LEGACY_STEP)
		steps += 1
	var battle: Dictionary = controller.get_battle_snapshot()
	var stats: Dictionary = battle.get("formation_stats", {})
	var generated_by_type: Dictionary = battle.get("generated_by_monster_type", {})
	var result := {
		"state": String(battle.get("state", "")),
		"duration": float(battle.get("battle_elapsed", 0.0)),
		"durability": int(battle.get("village_durability", 0)),
		"killed": int(battle.get("killed_enemy_count", 0)),
		"leaked": int(battle.get("leaked_enemy_count", 0)),
		"completed_a": int(stats.get("completed_a_count", 0)),
		"completed_b": int(stats.get("completed_b_count", 0)),
		"guard_generated": int(generated_by_type.get(&"formation_guard", 0)),
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


func has_full_b_state_chain(state_sequences: Dictionary) -> bool:
	for sequence: Array in state_sequences.values():
		var forming_index := sequence.find(CONFIG.FORMATION_STATE_FORMING_B)
		var preparing_index := sequence.find(CONFIG.FORMATION_STATE_PREPARING_B)
		var complete_index := sequence.find(CONFIG.FORMATION_STATE_COMPLETE)
		if (
			forming_index >= 0
			and preparing_index > forming_index
			and complete_index > preparing_index
		):
			return true
	return false


func print_result(label: String, result: Dictionary) -> void:
	print("v2-6a %s: state=%s duration=%.1f killed=%d leaked=%d %s durability=%d A/B/I/D=%d/%d/%d/%d prevented_damage=%d B_attempt/complete/prevented=%d/%d/%d B_seconds=%.1f command_at=%.1f state=%s level=%s reduction=%.0f%% first_kill=%.2f absolute=%.2f clear=%.2f commands=%d ordinary_progress_cost=%.3f first_wave=%d target=%s group=%s seq=%d hp=%d" % [
		label, result.state, result.duration, result.killed, result.leaked,
		str(result.leaked_by_profile),
		result.durability, result.completed_a, result.completed_b, result.interrupted,
		result.downgraded, result.guard_damage_prevented, result.b_attempt_count,
		result.b_completed_count, result.b_prevented_count, result.b_complete_group_seconds,
		result.command_trigger_time, result.command_state, result.command_level,
		result.command_reduction * 100.0, result.first_kill_delay, result.first_kill_absolute,
		result.formation_clear_delay, result.command_count, result.ordinary_progress_cost,
		result.first_intervention_wave, result.command_target_id, result.command_group_id,
		result.first_target_sequence, result.first_target_health,
	])
	print("v2-6a %s B approach durations=%s" % [label, str(result.b_approach_durations)])
	print("v2-6a %s prepare start/complete/member/other=%d/%d/%d/%d observations=%s" % [
		label, result.prepare_started, result.prepare_completed,
		result.prepare_member_loss, result.prepare_other_cancel,
		str(result.prepare_observations),
	])
	print("v2-6a %s guard prepare start/complete/member/other=%d/%d/%d/%d starts=%s outcomes=%s" % [
		label, result.guard_prepare_started, result.guard_prepare_completed,
		result.guard_prepare_member_loss, result.guard_prepare_other_cancel,
		str(result.guard_prepare_starts), str(result.guard_prepare_observations),
	])
	print("v2-6a %s command prepare start=%.1f remaining=%.1f reaction=%.1f first-kill-remaining=%.1f outcome=%s" % [
		label, result.command_prepare_started_at, result.command_prepare_remaining,
		result.command_reaction_delay, result.first_kill_prepare_remaining,
		result.command_prepare_outcome,
	])


func print_differences(label: String, first: Dictionary, second: Dictionary) -> void:
	for key in first.keys():
		if first.get(key) != second.get(key):
			print("v2-6a %s difference %s: %s != %s" % [
				label, String(key), str(first.get(key)), str(second.get(key)),
			])


func check(condition: bool, message: String) -> void:
	check_count += 1
	if not condition:
		failures.append(message)

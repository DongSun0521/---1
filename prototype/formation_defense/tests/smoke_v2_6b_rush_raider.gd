extends SceneTree

const SCENE_PATH := "res://prototype/formation_defense/scenes/formation_defense_prototype.tscn"
const CONFIG := preload("res://prototype/formation_defense/data/formation_defense_config.gd")
const Enemy := preload("res://prototype/formation_defense/scripts/formation_defense_enemy.gd")
const WaveDirector := preload("res://prototype/formation_defense/scripts/formation_defense_wave_director.gd")
const STEP := 0.1
const REACTION_DELAY := 0.4
const MAX_STEPS := 1800
const MODE_UNATTENDED: StringName = &"UNATTENDED"
const MODE_PREPARE_FOCUS: StringName = &"PREPARE_FOCUS"

var failures: Array[String] = []
var check_count := 0


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var battle_config := CONFIG.get_wave_battle_config(
		&"v2_6b_rush_raider_validation"
	)
	var validation := WaveDirector.validate_battle_config(
		battle_config,
		CONFIG.get_monster_type_ids(),
		CONFIG.get_spawn_point_lane_map(),
		CONFIG.get_visual_route_ids()
	)
	check(validation.is_empty(), "V2-6B-R battle configuration validates")
	var definition := CONFIG.get_monster_definition(&"rush_raider")
	check(
		String(definition.get("display_name", "")) == "突袭怪"
			and int(definition.get("max_health", 0)) == 91
			and is_equal_approx(float(definition.get("move_speed", 0.0)), 42.0)
			and int(definition.get("leak_damage", 0)) == 1,
		"rush raider owns the intended base identity without hidden durability"
	)
	check(
		bool(definition.get("rush_enabled", false))
			and is_equal_approx(float(definition.get("rush_trigger_progress", 0.0)), 0.48)
			and is_equal_approx(float(definition.get("rush_prepare_duration", 0.0)), 1.25)
			and is_equal_approx(float(definition.get("rush_duration", 0.0)), 3.25)
			and is_equal_approx(float(definition.get("rush_speed_multiplier", 0.0)), 4.00)
			and bool(definition.get("rush_once", false)),
		"all rush timing and movement values come from the enemy profile"
	)
	check(
		not bool(definition.get("formation_can_participate", true))
			and not definition.has("formation_effects"),
		"rush raider is configured outside A/B formations and owns no reduction"
	)
	var wave_counts: Array[int] = []
	for wave: Dictionary in battle_config.get("waves", []):
		wave_counts.append(WaveDirector.count_wave_enemies(wave))
	check(
		int(battle_config.get("random_seed", 0)) == 2602
			and wave_counts == [1, 2, 5],
		"validation battle is the fixed-seed three-wave 1/2/5 plan"
	)
	check(
		battle_contains_only_rush_raiders(battle_config),
		"independent validation battle contains no formation guards or mixed priority case"
	)

	var contracts := run_enemy_contracts()
	check(contracts.disabled_old_motion, "rush-disabled enemies retain the old movement behavior")
	check(contracts.legacy_defaults, "ordinary and formation-guard profiles keep rush disabled")
	check(contracts.full_chain, "rush state follows APPROACH/PREPARING/RUSHING/APPROACH")
	check(contracts.only_once, "one enemy can consume its rush only once")
	check(contracts.large_delta, "large delta preserves and fully consumes PREPARING_RUSH")
	check(contracts.prepare_duration, "preparation duration matches configuration")
	check(contracts.prepare_motion, "preparation continues at normal movement speed")
	check(contracts.prepare_damage, "preparation has zero reduction and normal death handling")
	check(contracts.rush_motion, "rushing uses the configured multiplier and duration")
	check(contracts.rush_damage, "rushing has zero reduction and normal death handling")
	check(contracts.prepare_leak, "arrival during preparation leaks once and clears warning")
	check(contracts.rush_leak, "arrival during rushing leaks once and clears trail")
	check(contracts.independent_instances, "multiple rush instances keep independent state")
	check(contracts.blocked_timeline, "blocking does not create delayed callbacks or teleport movement")
	check(contracts.pause_resume, "rush state changes only while normal simulation advances")
	check(contracts.no_timer_or_await, "rush core uses no Timer, SceneTreeTimer or await callback")

	var pointer_contract := await run_pointer_contract()
	check(
		pointer_contract.loaded
			and pointer_contract.preparing_selected
			and pointer_contract.rushing_selected,
		"real battlefield mouse entry selects preparing and rushing targets"
	)
	check(
		pointer_contract.click_did_not_mutate_enemy,
		"mouse focus does not synchronously alter health, progress or rush state"
	)
	check(
		pointer_contract.command_cleared_after_settlement
			and pointer_contract.restart_clean,
		"settlement and restart clear rush command, warning/trail and attack visuals"
	)

	var unattended_first := await run_validation_battle(MODE_UNATTENDED, -1)
	var unattended_second := await run_validation_battle(MODE_UNATTENDED, -1)
	var rescue_sequence := find_first_leaked_rush_sequence(unattended_first.records)
	check(rescue_sequence > 0, "unattended run creates a real rush leak candidate")
	var focus_first := await run_validation_battle(MODE_PREPARE_FOCUS, rescue_sequence)
	var focus_second := await run_validation_battle(MODE_PREPARE_FOCUS, rescue_sequence)

	check(unattended_first == unattended_second, "two unattended runs are deterministic")
	check(focus_first == focus_second, "two 0.4-second focus runs are deterministic")
	check(
		unattended_first.trace == focus_first.trace,
		"both strategy modes share the same config, seed and spawn trace"
	)
	check(
		unattended_first.generated == 8
			and unattended_first.prepared_count >= 1
			and unattended_first.rushed_count >= 1
			and unattended_first.completed_rush_count >= 1,
		"unattended battle observes real warning, rushing and completed rush states"
	)
	check(
		unattended_first.rush_leaked >= 1
			and unattended_first.durability < int(CONFIG.VILLAGE_MAX_DURABILITY),
		"unattended rushing creates measurable village pressure"
	)
	check(
		unattended_first.formation_exclusion_valid
			and focus_first.formation_exclusion_valid,
		"rush raiders never enter an A/B formation or formation group"
	)
	check(
		unattended_first.visual_state_valid
			and focus_first.visual_state_valid
			and unattended_first.damage_reduction_zero,
		"warning/trail visuals match states and rush damage reduction remains zero"
	)
	check(
		focus_first.public_focus_calls == 1
			and focus_first.public_focus_entry == "handle_battlefield_pointer"
			and focus_first.command_target_sequence == rescue_sequence
			and absf(float(focus_first.command_reaction_delay) - REACTION_DELAY) <= STEP + 0.001,
		"strategy waits 0.4 seconds then uses only the real battlefield mouse entry"
	)
	check(
		focus_first.command_did_not_mutate_enemy
			and focus_first.command_cleared_after_target_settlement
			and strategy_source_has_no_shortcuts(),
		"strategy target clears normally and uses no direct/internal shortcut"
	)
	check(
		get_record_outcome(unattended_first.records, rescue_sequence) == "leaked"
			and get_record_outcome(focus_first.records, rescue_sequence) == "killed"
			and focus_first.leaked <= unattended_first.leaked
			and focus_first.durability >= unattended_first.durability,
		"0.4-second warning focus prevents at least one otherwise real rush leak"
	)
	check(
		unattended_first.max_completed_rush_distance > 0.0
			and absf(
				float(unattended_first.max_completed_rush_distance)
					- float(definition.get("move_speed", 0.0))
						* float(definition.get("rush_speed_multiplier", 0.0))
						* float(definition.get("rush_duration", 0.0))
			) <= 0.2,
		"a completed rush advances the configured physical distance"
	)
	check(
		unattended_first.restart_clean and focus_first.restart_clean,
		"both strategy modes leave no old rush state after restart"
	)

	print_result("unattended", unattended_first)
	print_result("unattended-2", unattended_second)
	print_result("prepare-focus", focus_first)
	print_result("prepare-focus-2", focus_second)
	print("v2-6b-r rescue spawn sequence=%d" % rescue_sequence)
	if failures.is_empty():
		print("v2-6b-r rush raider smoke ok: %d requirements" % check_count)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func run_enemy_contracts() -> Dictionary:
	var normal = create_contract_enemy(&"charge", {}, 2000.0, 100.0, 100)
	normal.advance(2.0)
	var disabled_old_motion: bool = (
		not normal.rush_enabled
		and is_equal_approx(float(normal.traveled_distance), 200.0)
		and normal.rush_state == CONFIG.RUSH_STATE_APPROACH
		and normal.rush_state_history == [CONFIG.RUSH_STATE_APPROACH]
	)
	normal.free()

	var ordinary_definition := CONFIG.get_monster_definition(&"charge")
	var guard_definition := CONFIG.get_monster_definition(&"formation_guard")
	var legacy_defaults := (
		not ordinary_definition.has("rush_enabled")
		and not guard_definition.has("rush_enabled")
		and bool(ordinary_definition.get("formation_can_participate", true))
		and bool(guard_definition.get("formation_can_participate", true))
	)
	var legacy_guard = create_contract_enemy(
		&"formation_guard", {}, 2000.0, 100.0, 100
	)
	legacy_guard.advance(3.0)
	var legacy_guard_snapshot: Dictionary = legacy_guard.get_runtime_snapshot()
	legacy_defaults = legacy_defaults and (
		not legacy_guard.rush_enabled
		and not bool(legacy_guard_snapshot.get("rush_warning_visible", false))
		and not bool(legacy_guard_snapshot.get("rush_trail_visible", false))
	)
	legacy_guard.free()

	var exact_config := {
		"rush_enabled": true,
		"rush_trigger_progress": 0.25,
		"rush_prepare_duration": 1.25,
		"rush_duration": 1.50,
		"rush_speed_multiplier": 2.75,
		"rush_once": true,
	}
	var exact = create_contract_enemy(&"rush_raider", exact_config, 2000.0, 100.0, 100)
	exact.advance(5.0)
	var prepare_start_distance := float(exact.traveled_distance)
	var entered_prepare: bool = exact.rush_state == CONFIG.RUSH_STATE_PREPARING
	exact.advance(1.25)
	var prepare_end_distance := float(exact.traveled_distance)
	var entered_rush: bool = exact.rush_state == CONFIG.RUSH_STATE_RUSHING
	exact.advance(1.50)
	var rush_end_distance := float(exact.traveled_distance)
	var full_chain: bool = (
		entered_prepare
		and entered_rush
		and exact.rush_state == CONFIG.RUSH_STATE_APPROACH
		and exact.rush_state_history == [
			CONFIG.RUSH_STATE_APPROACH,
			CONFIG.RUSH_STATE_PREPARING,
			CONFIG.RUSH_STATE_RUSHING,
			CONFIG.RUSH_STATE_APPROACH,
		]
		and exact.rush_consumed
	)
	var prepare_duration := transition_duration(
		exact.rush_transition_records,
		CONFIG.RUSH_STATE_PREPARING,
		CONFIG.RUSH_STATE_RUSHING
	)
	var prepare_motion := absf(
		(prepare_end_distance - prepare_start_distance) - 125.0
	) <= 0.01
	var rush_duration := transition_duration(
		exact.rush_transition_records,
		CONFIG.RUSH_STATE_RUSHING,
		CONFIG.RUSH_STATE_APPROACH
	)
	var rush_motion := (
		absf(rush_duration - 1.50) <= 0.001
		and absf((rush_end_distance - prepare_end_distance) - 412.5) <= 0.01
	)
	exact.advance(3.0)
	var only_once: bool = (
		exact.rush_state_history.count(CONFIG.RUSH_STATE_PREPARING) == 1
		and exact.rush_state_history.count(CONFIG.RUSH_STATE_RUSHING) == 1
		and is_equal_approx(exact.get_rush_move_multiplier(), 1.0)
	)
	exact.free()

	var large_delta = create_contract_enemy(
		&"rush_raider", exact_config, 2000.0, 100.0, 100
	)
	large_delta.advance(7.0)
	var large_delta_valid: bool = (
		large_delta.rush_state == CONFIG.RUSH_STATE_RUSHING
		and large_delta.rush_state_history.has(CONFIG.RUSH_STATE_PREPARING)
		and large_delta.rush_state_history.has(CONFIG.RUSH_STATE_RUSHING)
		and absf(float(large_delta.rush_prepare_elapsed) - 1.25) <= 0.001
		and absf(float(large_delta.traveled_distance) - 831.25) <= 0.02
	)
	large_delta.free()

	var prepare_damage_enemy = create_contract_enemy(
		&"rush_raider",
		make_immediate_rush_config(1.25, 1.50, 2.75),
		2000.0,
		100.0,
		100
	)
	prepare_damage_enemy.advance(0.4)
	var prepare_applied := int(prepare_damage_enemy.take_damage(25, CONFIG.DAMAGE_SOURCE_RANGED))
	var prepare_damage: bool = (
		prepare_damage_enemy.rush_state == CONFIG.RUSH_STATE_PREPARING
		and prepare_applied == 25
		and is_zero_approx(prepare_damage_enemy.last_damage_reduction)
	)
	prepare_damage_enemy.take_damage(999, CONFIG.DAMAGE_SOURCE_MELEE)
	prepare_damage = prepare_damage and (
		prepare_damage_enemy.is_dead
		and prepare_damage_enemy.rush_state == CONFIG.RUSH_STATE_APPROACH
		and not bool(prepare_damage_enemy.get_runtime_snapshot().rush_warning_visible)
	)
	prepare_damage_enemy.free()

	var rush_damage_enemy = create_contract_enemy(
		&"rush_raider",
		make_immediate_rush_config(0.0, 2.0, 3.0),
		2000.0,
		100.0,
		100
	)
	rush_damage_enemy.advance(0.2)
	var rush_applied := int(rush_damage_enemy.take_damage(25, CONFIG.DAMAGE_SOURCE_RANGED))
	var rush_damage: bool = (
		rush_damage_enemy.rush_state == CONFIG.RUSH_STATE_RUSHING
		and rush_applied == 25
		and is_zero_approx(rush_damage_enemy.last_damage_reduction)
	)
	rush_damage_enemy.take_damage(999, CONFIG.DAMAGE_SOURCE_MELEE)
	rush_damage = rush_damage and (
		rush_damage_enemy.is_dead
		and rush_damage_enemy.rush_state == CONFIG.RUSH_STATE_APPROACH
		and not bool(rush_damage_enemy.get_runtime_snapshot().rush_trail_visible)
	)
	rush_damage_enemy.free()

	var prepare_arrivals: Array = []
	var prepare_leaker = create_contract_enemy(
		&"rush_raider",
		make_immediate_rush_config(10.0, 1.0, 2.0),
		100.0,
		100.0,
		100
	)
	prepare_leaker.reached_entrance.connect(
		func(enemy_id, route_id, damage): prepare_arrivals.append([enemy_id, route_id, damage])
	)
	prepare_leaker.advance(2.0)
	var prepare_leak: bool = (
		prepare_arrivals.size() == 1
		and prepare_leaker.settlement_completed
		and prepare_leaker.rush_state == CONFIG.RUSH_STATE_APPROACH
		and not bool(prepare_leaker.get_runtime_snapshot().rush_warning_visible)
	)
	prepare_leaker.free()

	var rush_arrivals: Array = []
	var rush_leaker = create_contract_enemy(
		&"rush_raider",
		make_immediate_rush_config(0.1, 10.0, 3.0),
		100.0,
		100.0,
		100
	)
	rush_leaker.reached_entrance.connect(
		func(enemy_id, route_id, damage): rush_arrivals.append([enemy_id, route_id, damage])
	)
	rush_leaker.advance(1.0)
	var rush_leak: bool = (
		rush_arrivals.size() == 1
		and rush_leaker.rush_state_history.has(CONFIG.RUSH_STATE_RUSHING)
		and rush_leaker.settlement_completed
		and not bool(rush_leaker.get_runtime_snapshot().rush_trail_visible)
	)
	rush_leaker.free()

	var first = create_contract_enemy(
		&"rush_raider", exact_config, 2000.0, 100.0, 100
	)
	var second = create_contract_enemy(
		&"rush_raider", exact_config, 2000.0, 100.0, 100
	)
	first.advance(5.5)
	second.advance(1.0)
	var independent_instances: bool = (
		first.rush_state == CONFIG.RUSH_STATE_PREPARING
		and second.rush_state == CONFIG.RUSH_STATE_APPROACH
		and first.rush_prepare_elapsed > 0.0
		and is_zero_approx(second.rush_prepare_elapsed)
	)
	first.free()
	second.free()

	var blocked = create_contract_enemy(
		&"rush_raider",
		make_immediate_rush_config(1.0, 1.0, 3.0),
		2000.0,
		100.0,
		100
	)
	blocked.set_blocker(&"guard")
	blocked.advance_blocked_combat(2.5)
	var blocked_timeline: bool = (
		is_zero_approx(blocked.traveled_distance)
		and blocked.rush_consumed
		and blocked.rush_state == CONFIG.RUSH_STATE_APPROACH
	)
	blocked.free()

	var paused = create_contract_enemy(
		&"rush_raider",
		make_immediate_rush_config(1.25, 1.5, 2.75),
		2000.0,
		100.0,
		100
	)
	paused.advance(0.4)
	var paused_snapshot: Dictionary = paused.get_runtime_snapshot()
	var paused_again: Dictionary = paused.get_runtime_snapshot()
	paused.advance(0.2)
	var pause_resume := (
		paused_snapshot == paused_again
		and float(paused.rush_prepare_elapsed)
			> float(paused_snapshot.get("rush_prepare_elapsed", 0.0))
	)
	paused.free()

	return {
		"disabled_old_motion": disabled_old_motion,
		"legacy_defaults": legacy_defaults,
		"full_chain": full_chain,
		"only_once": only_once,
		"large_delta": large_delta_valid,
		"prepare_duration": absf(prepare_duration - 1.25) <= 0.001,
		"prepare_motion": prepare_motion,
		"prepare_damage": prepare_damage,
		"rush_motion": rush_motion,
		"rush_damage": rush_damage,
		"prepare_leak": prepare_leak,
		"rush_leak": rush_leak,
		"independent_instances": independent_instances,
		"blocked_timeline": blocked_timeline,
		"pause_resume": pause_resume,
		"no_timer_or_await": rush_source_has_no_delayed_core(),
	}


func create_contract_enemy(
	profile_id: StringName,
	rush_config: Dictionary,
	route_length: float,
	move_speed: float,
	health: int
):
	var definition := CONFIG.get_monster_definition(profile_id)
	var effective_rush_config := definition if rush_config.is_empty() else rush_config
	var enemy = Enemy.new()
	enemy.configure(
		StringName("contract_%s" % String(profile_id)),
		&"formation_center",
		1,
		move_speed,
		int(definition.get("leak_damage", 1)),
		PackedVector2Array([Vector2(route_length, 0.0), Vector2.ZERO]),
		Color(definition.get("body_color", Color.WHITE)),
		health,
		int(definition.get("attack_damage", 10)),
		float(definition.get("attack_interval", 1.0)),
		profile_id,
		&"spawn_center",
		CONFIG.ROUTE_GROUP_FORMATION,
		&"middle",
		2,
		String(definition.get("display_name", String(profile_id))),
		StringName(definition.get("type_marker", &"")),
		bool(definition.get("formation_can_participate", true)),
		effective_rush_config
	)
	return enemy


func make_immediate_rush_config(
	prepare_duration: float,
	duration: float,
	multiplier: float
) -> Dictionary:
	return {
		"rush_enabled": true,
		"rush_trigger_progress": 0.0,
		"rush_prepare_duration": prepare_duration,
		"rush_duration": duration,
		"rush_speed_multiplier": multiplier,
		"rush_once": true,
	}


func transition_duration(
	records: Array,
	start_state: StringName,
	end_state: StringName
) -> float:
	var start_time := -1.0
	for record: Dictionary in records:
		var state := StringName(record.get("state", &""))
		if state == start_state and start_time < 0.0:
			start_time = float(record.get("runtime_elapsed", 0.0))
		elif state == end_state and start_time >= 0.0:
			return float(record.get("runtime_elapsed", 0.0)) - start_time
	return -1.0


func run_pointer_contract() -> Dictionary:
	var controller = (load(SCENE_PATH) as PackedScene).instantiate()
	root.add_child(controller)
	await process_frame
	await process_frame
	controller.set_automatic_simulation(false)
	controller.select_scenario(&"rush_raider_validation")
	controller.clear_deployment()
	controller.start_battle()
	var loaded: bool = controller.battle_state == controller.BattleState.RUNNING
	var preparing_selected := false
	var rushing_selected := false
	var click_did_not_mutate_enemy := true
	var selected_target_id: StringName = &""
	var command_cleared_after_settlement := false
	var steps := 0
	while controller.battle_state == controller.BattleState.RUNNING and steps < 700:
		controller.simulate_step(STEP)
		for enemy in controller.active_enemies.values():
			if not is_instance_valid(enemy) or enemy.monster_type != &"rush_raider":
				continue
			if enemy.rush_state == CONFIG.RUSH_STATE_PREPARING and not preparing_selected:
				var before := capture_click_state(enemy)
				preparing_selected = issue_focus_via_player_pointer(controller, enemy)
				if preparing_selected:
					selected_target_id = StringName(enemy.runtime_id)
				click_did_not_mutate_enemy = click_did_not_mutate_enemy and (
					before == capture_click_state(enemy)
				)
			elif enemy.rush_state == CONFIG.RUSH_STATE_RUSHING and not rushing_selected:
				var before := capture_click_state(enemy)
				rushing_selected = issue_focus_via_player_pointer(controller, enemy)
				click_did_not_mutate_enemy = click_did_not_mutate_enemy and (
					before == capture_click_state(enemy)
				)
		if (
			preparing_selected
			and rushing_selected
			and selected_target_id != &""
			and controller.settled_enemy_ids.has(selected_target_id)
		):
			var command: Dictionary = (
				controller.command_controller.get_active_command_snapshot()
			)
			command_cleared_after_settlement = (
				StringName(command.get("target_runtime_id", &"")) != selected_target_id
			)
			break
		steps += 1
	controller.restart_battle()
	await process_frame
	var reset: Dictionary = controller.get_battle_snapshot()
	var restart_clean: bool = (
		controller.active_enemies.is_empty()
		and Dictionary(reset.get("command", {})).is_empty()
		and Array(reset.get("attack_visuals", [])).is_empty()
		and controller.get_formation_groups_snapshot().is_empty()
	)
	controller.queue_free()
	await process_frame
	return {
		"loaded": loaded,
		"preparing_selected": preparing_selected,
		"rushing_selected": rushing_selected,
		"click_did_not_mutate_enemy": click_did_not_mutate_enemy,
		"command_cleared_after_settlement": command_cleared_after_settlement,
		"restart_clean": restart_clean,
	}


func run_validation_battle(
	mode: StringName,
	target_sequence: int
) -> Dictionary:
	var controller = (load(SCENE_PATH) as PackedScene).instantiate()
	root.add_child(controller)
	await process_frame
	await process_frame
	controller.set_automatic_simulation(false)
	controller.select_scenario(&"rush_raider_validation")
	controller.apply_recommended_deployment()
	controller.start_battle()
	var records: Dictionary = {}
	var enemy_sequence_by_id: Dictionary = {}
	var profile_by_id: Dictionary = {}
	var last_state_by_id: Dictionary = {}
	var settled_seen: Dictionary = {}
	var public_focus_calls := 0
	var command_target_sequence := -1
	var command_time := -1.0
	var command_health := -1
	var command_reaction_delay := -1.0
	var command_did_not_mutate_enemy := true
	var command_cleared_after_target_settlement := false
	var visual_state_valid := true
	var damage_reduction_zero := true
	var formation_exclusion_valid := true
	var steps := 0
	while (
		controller.battle_state == controller.BattleState.RUNNING
		and steps < MAX_STEPS
	):
		var simulation_step := get_next_strategy_step(
			controller,
			mode,
			target_sequence,
			public_focus_calls
		)
		controller.simulate_step(simulation_step)
		for enemy in controller.active_enemies.values():
			if not is_instance_valid(enemy):
				continue
			var enemy_id := StringName(enemy.runtime_id)
			var sequence := int(enemy.spawn_sequence)
			enemy_sequence_by_id[enemy_id] = sequence
			profile_by_id[enemy_id] = StringName(enemy.monster_type)
			if enemy.monster_type != &"rush_raider":
				continue
			if not records.has(sequence):
				records[sequence] = create_rush_record(enemy, controller)
			var record: Dictionary = records[sequence]
			var snapshot: Dictionary = enemy.get_runtime_snapshot()
			var state := StringName(snapshot.get("rush_state", &""))
			if StringName(last_state_by_id.get(enemy_id, &"")) != state:
				record.states.append(String(state))
				last_state_by_id[enemy_id] = state
			if state == CONFIG.RUSH_STATE_PREPARING:
				if float(record.prepare_at) < 0.0:
					record.prepare_at = float(controller.battle_elapsed) - float(enemy.rush_prepare_elapsed)
					record.prepare_progress = float(enemy.rush_prepare_start_distance) / maxf(1.0, float(enemy.total_route_length))
					record.prepare_health = int(enemy.current_health)
				record.prepare_distance = float(enemy.rush_prepare_start_distance)
			elif state == CONFIG.RUSH_STATE_RUSHING:
				if float(record.rush_at) < 0.0:
					record.rush_at = float(controller.battle_elapsed) - float(enemy.rush_elapsed)
					record.rush_progress = float(enemy.rush_start_distance) / maxf(1.0, float(enemy.total_route_length))
					record.rush_health = int(enemy.current_health)
					record.rush_start_distance = float(enemy.rush_start_distance)
				record.max_multiplier = maxf(
					float(record.max_multiplier),
					float(enemy.get_rush_move_multiplier())
				)
			elif enemy.rush_consumed and float(enemy.rush_end_distance) >= 0.0:
				if float(record.rush_end_distance) < 0.0:
					record.rush_end_distance = float(enemy.rush_end_distance)
					record.rush_end_at = float(controller.battle_elapsed)
			visual_state_valid = visual_state_valid and (
				bool(snapshot.get("rush_warning_visible", false))
					== (state == CONFIG.RUSH_STATE_PREPARING)
				and bool(snapshot.get("rush_trail_visible", false))
					== (state == CONFIG.RUSH_STATE_RUSHING)
			)
			damage_reduction_zero = damage_reduction_zero and (
				is_zero_approx(float(enemy.formation_player_damage_reduction))
				and is_zero_approx(float(enemy.get_effective_player_damage_reduction(
					CONFIG.DAMAGE_SOURCE_MELEE
				)))
				and is_zero_approx(float(enemy.get_effective_player_damage_reduction(
					CONFIG.DAMAGE_SOURCE_RANGED
				)))
			)
			formation_exclusion_valid = formation_exclusion_valid and (
				not enemy.formation_can_participate
				and enemy.formation_id == &""
				and enemy.formation_level == CONFIG.FORMATION_LEVEL_SINGLE
				and enemy.formation_state == CONFIG.FORMATION_STATE_NONE
			)
			if (
				mode == MODE_PREPARE_FOCUS
				and public_focus_calls == 0
				and sequence == target_sequence
				and state == CONFIG.RUSH_STATE_PREPARING
				and float(enemy.rush_prepare_elapsed) + 0.0001 >= REACTION_DELAY
			):
				var before := capture_click_state(enemy)
				var accepted := issue_focus_via_player_pointer(controller, enemy)
				public_focus_calls += 1 if accepted else 0
				command_target_sequence = sequence if accepted else -1
				command_time = float(controller.battle_elapsed)
				command_health = int(enemy.current_health)
				command_reaction_delay = float(enemy.rush_prepare_elapsed)
				command_did_not_mutate_enemy = (
					accepted and before == capture_click_state(enemy)
				)
		for group: Dictionary in controller.get_formation_groups_snapshot():
			for member_id in group.get("member_ids", []):
				formation_exclusion_valid = formation_exclusion_valid and (
					StringName(profile_by_id.get(StringName(member_id), &"")) != &"rush_raider"
				)
		capture_settlements(
			controller, records, enemy_sequence_by_id, profile_by_id, settled_seen
		)
		if mode == MODE_PREPARE_FOCUS and public_focus_calls > 0:
			var target_id := find_runtime_id_for_sequence(
				enemy_sequence_by_id,
				target_sequence
			)
			if target_id != &"" and controller.settled_enemy_ids.has(target_id):
				var active_command: Dictionary = (
					controller.command_controller.get_active_command_snapshot()
				)
				command_cleared_after_target_settlement = (
					StringName(active_command.get("target_runtime_id", &"")) != target_id
				)
		steps += 1

	capture_settlements(
		controller, records, enemy_sequence_by_id, profile_by_id, settled_seen
	)
	var battle: Dictionary = controller.get_battle_snapshot()
	var sanitized_records := sanitize_records(records)
	var prepared_count := 0
	var rushed_count := 0
	var completed_rush_count := 0
	var rush_killed := 0
	var rush_leaked := 0
	var max_completed_rush_distance := 0.0
	for record: Dictionary in sanitized_records:
		if float(record.prepare_at) >= 0.0:
			prepared_count += 1
		if float(record.rush_at) >= 0.0:
			rushed_count += 1
		if float(record.rush_end_distance) >= 0.0:
			completed_rush_count += 1
			max_completed_rush_distance = maxf(
				max_completed_rush_distance,
				float(record.rush_end_distance) - float(record.rush_start_distance)
			)
		if String(record.outcome) == "killed":
			rush_killed += 1
		elif String(record.outcome) == "leaked":
			rush_leaked += 1
	var result := {
		"state": String(battle.get("state", "")),
		"duration": snappedf(float(battle.get("battle_elapsed", 0.0)), 0.001),
		"generated": int(battle.get("generated_enemy_count", 0)),
		"killed": int(battle.get("killed_enemy_count", 0)),
		"leaked": int(battle.get("leaked_enemy_count", 0)),
		"durability": int(battle.get("village_durability", 0)),
		"rush_killed": rush_killed,
		"rush_leaked": rush_leaked,
		"prepared_count": prepared_count,
		"rushed_count": rushed_count,
		"completed_rush_count": completed_rush_count,
		"max_completed_rush_distance": snappedf(max_completed_rush_distance, 0.001),
		"records": sanitized_records,
		"trace": sanitize_trace(Dictionary(battle.get("wave", {})).get("spawn_trace", [])),
		"public_focus_calls": public_focus_calls,
		"public_focus_entry": "handle_battlefield_pointer",
		"command_target_sequence": command_target_sequence,
		"command_time": snappedf(command_time, 0.001),
		"command_health": command_health,
		"command_reaction_delay": snappedf(command_reaction_delay, 0.001),
		"command_did_not_mutate_enemy": command_did_not_mutate_enemy,
		"command_cleared_after_target_settlement":
			command_cleared_after_target_settlement,
		"visual_state_valid": visual_state_valid,
		"damage_reduction_zero": damage_reduction_zero,
		"formation_exclusion_valid": formation_exclusion_valid,
	}
	controller.restart_battle()
	await process_frame
	var reset: Dictionary = controller.get_battle_snapshot()
	result["restart_clean"] = (
		controller.active_enemies.is_empty()
		and Dictionary(reset.get("command", {})).is_empty()
		and Array(reset.get("attack_visuals", [])).is_empty()
		and controller.get_formation_groups_snapshot().is_empty()
		and int(reset.get("generated_enemy_count", -1)) == 0
		and int(reset.get("resolved_enemy_count", -1)) == 0
	)
	controller.queue_free()
	await process_frame
	return result


func get_next_strategy_step(
	controller,
	mode: StringName,
	target_sequence: int,
	public_focus_calls: int
) -> float:
	if mode != MODE_PREPARE_FOCUS or public_focus_calls > 0:
		return STEP
	for enemy in controller.active_enemies.values():
		if (
			is_instance_valid(enemy)
			and enemy.monster_type == &"rush_raider"
			and int(enemy.spawn_sequence) == target_sequence
			and enemy.rush_state == CONFIG.RUSH_STATE_PREPARING
		):
			var reaction_remaining := maxf(
				0.0,
				REACTION_DELAY - float(enemy.rush_prepare_elapsed)
			)
			if reaction_remaining > 0.000001:
				return minf(STEP, reaction_remaining)
	return STEP


func create_rush_record(enemy, controller) -> Dictionary:
	var wave: Dictionary = controller.get_wave_snapshot()
	return {
		"sequence": int(enemy.spawn_sequence),
		"runtime_id": String(enemy.runtime_id),
		"wave_index": int(wave.get("current_wave_index", -1)),
		"spawn_point_id": String(enemy.spawn_point_id),
		"route_id": String(enemy.route_id),
		"states": [String(enemy.rush_state)],
		"prepare_at": -1.0,
		"prepare_progress": -1.0,
		"prepare_health": -1,
		"prepare_distance": -1.0,
		"rush_at": -1.0,
		"rush_progress": -1.0,
		"rush_health": -1,
		"rush_start_distance": -1.0,
		"rush_end_at": -1.0,
		"rush_end_distance": -1.0,
		"max_multiplier": 1.0,
		"settled_at": -1.0,
		"outcome": "",
	}


func capture_settlements(
	controller,
	records: Dictionary,
	enemy_sequence_by_id: Dictionary,
	profile_by_id: Dictionary,
	settled_seen: Dictionary
) -> void:
	for enemy_id in controller.settled_enemy_ids.keys():
		var stable_id := StringName(enemy_id)
		if settled_seen.has(stable_id):
			continue
		settled_seen[stable_id] = true
		if StringName(profile_by_id.get(stable_id, &"")) != &"rush_raider":
			continue
		var sequence := int(enemy_sequence_by_id.get(stable_id, -1))
		if not records.has(sequence):
			continue
		var record: Dictionary = records[sequence]
		record.outcome = String(controller.settled_enemy_ids[stable_id])
		record.settled_at = float(controller.battle_elapsed)


func find_runtime_id_for_sequence(
	enemy_sequence_by_id: Dictionary,
	target_sequence: int
) -> StringName:
	for enemy_id in enemy_sequence_by_id.keys():
		if int(enemy_sequence_by_id[enemy_id]) == target_sequence:
			return StringName(enemy_id)
	return &""


func sanitize_records(records: Dictionary) -> Array[Dictionary]:
	var sequences: Array[int] = []
	for sequence in records.keys():
		sequences.append(int(sequence))
	sequences.sort()
	var result: Array[Dictionary] = []
	for sequence: int in sequences:
		var source: Dictionary = records[sequence]
		result.append({
			"sequence": sequence,
			"runtime_id": String(source.runtime_id),
			"wave_index": int(source.wave_index),
			"spawn_point_id": String(source.spawn_point_id),
			"route_id": String(source.route_id),
			"states": Array(source.states).duplicate(),
			"prepare_at": snap_optional(float(source.prepare_at)),
			"prepare_progress": snap_optional(float(source.prepare_progress)),
			"prepare_health": int(source.prepare_health),
			"prepare_distance": snap_optional(float(source.prepare_distance)),
			"rush_at": snap_optional(float(source.rush_at)),
			"rush_progress": snap_optional(float(source.rush_progress)),
			"rush_health": int(source.rush_health),
			"rush_start_distance": snap_optional(float(source.rush_start_distance)),
			"rush_end_at": snap_optional(float(source.rush_end_at)),
			"rush_end_distance": snap_optional(float(source.rush_end_distance)),
			"max_multiplier": snappedf(float(source.max_multiplier), 0.001),
			"settled_at": snap_optional(float(source.settled_at)),
			"outcome": String(source.outcome),
		})
	return result


func snap_optional(value: float) -> float:
	return snappedf(value, 0.001) if value >= 0.0 else -1.0


func find_first_leaked_rush_sequence(records: Array) -> int:
	for record: Dictionary in records:
		if String(record.get("outcome", "")) == "leaked" \
				and float(record.get("prepare_at", -1.0)) >= 0.0:
			return int(record.get("sequence", -1))
	return -1


func get_record_outcome(records: Array, sequence: int) -> String:
	for record: Dictionary in records:
		if int(record.get("sequence", -1)) == sequence:
			return String(record.get("outcome", ""))
	return ""


func issue_focus_via_player_pointer(controller, enemy) -> bool:
	if not is_instance_valid(enemy):
		return false
	var accepted: bool = controller.handle_battlefield_pointer(
		enemy.position,
		MOUSE_BUTTON_LEFT
	)
	var command: Dictionary = controller.command_controller.get_active_command_snapshot()
	return accepted and StringName(command.get("target_runtime_id", &"")) == enemy.runtime_id


func capture_click_state(enemy) -> Dictionary:
	return {
		"health": int(enemy.current_health),
		"route_progress": float(enemy.route_progress),
		"traveled_distance": float(enemy.traveled_distance),
		"rush_state": StringName(enemy.rush_state),
		"rush_prepare_elapsed": float(enemy.rush_prepare_elapsed),
		"rush_elapsed": float(enemy.rush_elapsed),
	}


func battle_contains_only_rush_raiders(battle_config: Dictionary) -> bool:
	for wave: Dictionary in battle_config.get("waves", []):
		for subwave: Dictionary in wave.get("subwaves", []):
			for group: Dictionary in subwave.get("spawn_groups", []):
				if StringName(group.get("enemy_profile_id", &"")) != &"rush_raider":
					return false
	return true


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


func rush_source_has_no_delayed_core() -> bool:
	var source_file := FileAccess.open(
		"res://prototype/formation_defense/scripts/formation_defense_enemy.gd",
		FileAccess.READ
	)
	if source_file == null:
		return false
	var source := source_file.get_as_text()
	return (
		source.find("SceneTree" + "Timer") < 0
		and source.find("Timer" + ".new") < 0
		and source.find("await ") < 0
		and source.find("route_progress +=") < 0
		and source.find("route_progress = rush") < 0
	)


func strategy_source_has_no_shortcuts() -> bool:
	var source_file := FileAccess.open(
		"res://prototype/formation_defense/tests/smoke_v2_6b_rush_raider.gd",
		FileAccess.READ
	)
	if source_file == null:
		return false
	var source := source_file.get_as_text()
	var start := source.find("func run_validation_battle")
	var finish := source.find("\nfunc create_rush_record", start)
	if start < 0 or finish <= start:
		return false
	var strategy_source := source.substr(start, finish - start)
	var forbidden_tokens := [
		".take_" + "damage(",
		".current_health = ",
		".route_progress = ",
		".traveled_distance = ",
		".rush_state = ",
		"issue_" + "command(",
		"interrupt_enemy_" + "formation(",
		"formation_manager.",
	]
	for token: String in forbidden_tokens:
		if strategy_source.find(token) >= 0:
			return false
	return (
		source.find("controller.handle_battlefield_pointer(") >= 0
		and strategy_source.find("issue_focus_via_player_pointer(") >= 0
	)


func print_result(label: String, result: Dictionary) -> void:
	print("v2-6b-r %s: state=%s duration=%.1f generated=%d killed=%d leaked=%d durability=%d prepared/rushed/completed=%d/%d/%d max_rush_distance=%.2f command_at=%.1f reaction=%.1f command_hp=%d target_seq=%d" % [
		label,
		result.state,
		result.duration,
		result.generated,
		result.killed,
		result.leaked,
		result.durability,
		result.prepared_count,
		result.rushed_count,
		result.completed_rush_count,
		result.max_completed_rush_distance,
		result.command_time,
		result.command_reaction_delay,
		result.command_health,
		result.command_target_sequence,
	])
	print("v2-6b-r %s records=%s" % [label, str(result.records)])


func check(condition: bool, message: String) -> void:
	check_count += 1
	if not condition:
		failures.append(message)

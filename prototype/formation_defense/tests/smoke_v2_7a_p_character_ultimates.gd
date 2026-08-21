extends SceneTree

const SCENE_PATH := "res://prototype/formation_defense/scenes/formation_defense_prototype.tscn"
const CONFIG := preload("res://prototype/formation_defense/data/formation_defense_config.gd")
const WaveDirector := preload("res://prototype/formation_defense/scripts/formation_defense_wave_director.gd")
const SCENARIO_ID: StringName = &"player_ultimate_validation"
const BATTLE_ID: StringName = &"v2_7a_player_ultimate_validation"
const STEP := 0.1
const MAX_STEPS := 2600

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
	check(validation.is_empty(), "ultimate validation battle configuration validates")
	check(
		StringName(config.get("battle_id", &"")) == BATTLE_ID
			and int(config.get("random_seed", 0)) == 2702,
		"V2-7A-P owns the requested battle ID and fixed seed"
	)
	check(
		not CONFIG.DEFAULT_CHARACTER_ULTIMATE_ENABLED
			and bool(config.get("character_ultimate_enabled", false)),
		"character ultimates default off and validation explicitly enables them"
	)
	check(
		historical_battles_keep_ultimates_disabled(),
		"all historical wave battles keep ultimates disabled"
	)
	check(
		count_planned_enemies(config) == 18 and battle_uses_only_charge(config),
		"three validation segments plan eighteen ordinary charge enemies only"
	)
	check(ultimate_definitions_match_spec(), "four role ultimate definitions match prototype parameters")
	check(
		CONFIG.get_recommended_deployment(SCENARIO_ID)
			== CONFIG.ULTIMATE_VALIDATION_DEPLOYMENT,
		"validation exposes the protected reference deployment"
	)

	var historical_state := await run_historical_disabled_check()
	check(
		not historical_state.enabled
			and not historical_state.ui_exists
			and historical_state.runtime_disabled,
		"historical battles create neither ultimate UI nor active runtime state"
	)
	check(await run_pause_energy_check(), "paused scene processing does not grow energy")
	var passive := await run_passive_rate_check()
	check(passive.exact, "four roles use the configured differentiated passive rates")
	check(passive.no_events, "passive-only opening time creates no event energy")
	check(passive.bounded, "passive energy remains bounded by the shared maximum")
	var geometry := await run_geometry_checks()
	check(geometry.rectangles_configured, "three position ultimates use forward rectangles")
	check(geometry.rectangles_clipped, "forward rectangles are clipped to the logical battlefield")
	check(geometry.preview_matches_legality, "rectangle preview and target legality share one geometry")
	check(geometry.circles_round, "all position-effect previews remain screen-round at three resolutions")
	check(geometry.hunter_single_target, "hunter keeps its single-target line without a cast rectangle")
	check(geometry.mapping_valid, "three resolutions round-trip X/Y mapped ultimate coordinates")
	var invalid := await run_invalid_input_checks()
	check(invalid.independent_initialized, "each deployed role starts with independent zero energy")
	check(invalid.ready_energy_stopped, "energy does not grow before battle start")
	check(invalid.ui_complete, "enabled battle creates four visible UI buttons and energy bars")
	check(invalid.energy_capped, "independent energy never exceeds one hundred")
	check(invalid.unready_rejected, "unfilled energy cannot begin targeting")
	check(invalid.escape_kept_energy, "Esc cancels targeting without consuming energy")
	check(invalid.right_click_kept_energy, "right click cancels without consuming energy")
	check(invalid.out_of_range_kept_energy, "out-of-range release is invalid and free")
	check(invalid.hunter_no_snap_kept_energy, "hunter release without a snapped enemy is free")
	check(invalid.doctor_no_heal_kept_energy, "doctor release without an injured target is free")
	check(invalid.single_targeting_state, "starting another ready role replaces the only targeting state")
	check(invalid.debug_canceled_targeting, "opening debug cancels targeting without spending energy")
	check(invalid.debug_blocks_start, "open debug drawer prevents starting an ultimate drag")
	check(invalid.command_was_canceled, "starting ultimate targeting cancels focus command")
	check(invalid.legal_release_once, "one legal release consumes energy and settles exactly once")
	check(invalid.effect_hits_match_circle, "actual area hits exactly match the visible round effect")
	check(invalid.ultimate_granted_no_energy, "ultimate damage and kills grant no event energy")
	check(invalid.restart_clean, "restart clears energy, targeting, preview and skill effects")
	check(invalid.restart_energy_audit_clean, "restart clears energy source and throttle audit state")

	var down_cancel := await run_natural_incapacitation_cancel()
	check(
		down_cancel.began and down_cancel.incapacitated and down_cancel.canceled
			and down_cancel.energy_preserved and down_cancel.energy_stopped
			and down_cancel.release_rejected and down_cancel.throttle_clean,
		"natural incapacitation cancels aiming without an extra energy spend"
	)
	var finish_cancel := await run_battle_finish_cancel()
	check(finish_cancel, "battle settlement cancels aiming, clears effects and stops energy")
	var doctor_safety := await run_doctor_no_revive_check()
	check(
		doctor_safety.released and doctor_safety.down_stayed_down
			and doctor_safety.health_capped,
		"group heal uses living targets only, caps health and never revives"
	)
	var unattended_first := await run_battle(false)
	var unattended_second := await run_battle(false)
	var commanded_first := await run_battle(true)
	var commanded_second := await run_battle(true)
	check(unattended_first == unattended_second, "unattended baseline repeats exactly")
	check(commanded_first == commanded_second, "fixed ultimate operation repeats exactly")
	check(
		unattended_first.state == "VICTORY"
			and is_equal_approx(float(unattended_first.duration), 112.6)
			and int(unattended_first.killed) == 11
			and int(unattended_first.leaked) == 7
			and int(unattended_first.durability) == 3
			and int(unattended_first.healing_events) == 49
			and int(unattended_first.down) == 4,
		"unattended combat result remains on the protected V2-7A-P baseline"
	)
	check(
		unattended_first.release_count == 0
			and unattended_first.duplicate_settlements == 0,
		"unattended battle never releases or duplicate-settles an ultimate"
	)
	check(
		count_roles_released(commanded_first) >= 3,
		"fixed operation naturally releases at least three role ultimates through the UI-facing path"
	)
	check(
		commanded_first.hunter.damage > 0 and commanded_first.hunter.hits > 0,
		"precision snipe resolves deterministic single-target damage"
	)
	check(
		commanded_first.mage.damage > 0 and commanded_first.mage.hits > 0,
		"arcane blast resolves stable area damage once per enemy"
	)
	check(
		commanded_first.doctor.healing > 0 and commanded_first.doctor.healed > 0,
		"group heal restores living injured characters through the shared heal entry"
	)
	check(
		int(commanded_first.guard.kills) + int(commanded_first.hunter.kills)
			+ int(commanded_first.mage.kills) > 0,
		"ultimate kills enter the existing death and kill statistics"
	)
	check(commanded_first.duplicate_settlements == 0, "skill effects never duplicate settlement")
	check(
		commanded_first.release_accounting_exact
			and commanded_first.target_ids_unique,
		"release events, energy spends and per-target settlements have one-to-one accounting"
	)
	check(commanded_first.targeting_clean, "battle finish clears targeting and preview state")
	check(commanded_first.post_finish_stable, "finished battles stop energy and clear transient effects")
	check(
		commanded_first.invalid_releases == 0,
		"fixed operation only releases at legal visible targets"
	)
	check(
		operation_has_benefit(unattended_first, commanded_first),
		"using at least three ultimates improves a required battle outcome"
	)
	check(
		unattended_energy_sources_match_rules(unattended_first),
		"unattended energy audit records role-specific formal event sources"
	)
	check(
		commanded_energy_sources_match_rules(commanded_first),
		"fixed operation records hit, kill and heal energy without cross-role leakage"
	)
	check(
		first_ready_times_are_differentiated(unattended_first),
		"role energy rules no longer make all first-ready times identical"
	)
	check(
		int(unattended_first.characters.guard.event_throttled) > 0,
		"guard damage energy throttle rejects clustered damage events"
	)
	check(all_character_energies_bounded(commanded_first), "commanded energy stays within zero to one hundred")
	check(smoke_uses_no_runtime_shortcuts(), "Smoke uses public input-facing release without state writes")

	print_result("unattended-1", unattended_first)
	print_result("unattended-2", unattended_second)
	print_result("commanded-1", commanded_first)
	print_result("commanded-2", commanded_second)
	print("v2-7a-p invalid=%s" % str(invalid))
	print("v2-7a-p down-cancel=%s" % str(down_cancel))
	if failures.is_empty():
		print("v2-7a-p character ultimates smoke ok: %d requirements" % check_count)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func run_battle(use_ultimates: bool) -> Dictionary:
	var controller = await create_controller(SCENARIO_ID, true)
	var previous_enemy_state: Dictionary = {}
	var stun_expired_ids: Dictionary = {}
	var stun_observed := false
	var stun_resumed := false
	var steps := 0
	while controller.battle_state == controller.BattleState.RUNNING and steps < MAX_STEPS:
		previous_enemy_state.clear()
		for enemy in controller.active_enemies.values():
			if is_instance_valid(enemy):
				previous_enemy_state[enemy.runtime_id] = {
					"distance": float(enemy.traveled_distance),
					"stun": float(enemy.stun_remaining),
					"attacks": int(enemy.contact_attack_count),
				}
		controller.simulate_step(STEP)
		for enemy in controller.active_enemies.values():
			if not is_instance_valid(enemy) or not previous_enemy_state.has(enemy.runtime_id):
				continue
			var previous: Dictionary = previous_enemy_state[enemy.runtime_id]
			var distance_delta := float(enemy.traveled_distance) - float(previous.distance)
			var attack_delta := int(enemy.contact_attack_count) - int(previous.attacks)
			if float(previous.stun) > 0.0001:
				stun_observed = stun_observed and true \
					if stun_observed else absf(distance_delta) <= 0.0001 and attack_delta == 0
			if float(previous.stun) > 0.0 and enemy.stun_remaining <= 0.0:
				stun_expired_ids[enemy.runtime_id] = true
			if stun_expired_ids.has(enemy.runtime_id) \
					and (distance_delta > 0.0001 or attack_delta > 0):
				stun_resumed = true
		if use_ultimates:
			issue_ready_ultimates(controller)
		steps += 1
	var snapshot: Dictionary = controller.get_battle_snapshot()
	var result := summarize_battle(snapshot, stun_observed, stun_resumed)
	var final_energies := collect_character_energies(snapshot.get("characters", []))
	controller.simulate_step(2.0)
	var post_finish: Dictionary = controller.get_battle_snapshot()
	result["post_finish_stable"] = (
		collect_character_energies(post_finish.get("characters", [])) == final_energies
		and int(post_finish.get("ultimate_release_sequence", -1))
			== int(snapshot.get("ultimate_release_sequence", -2))
		and not bool(Dictionary(post_finish.get("ultimate_overlay", {})).get(
			"preview_visible", true
		))
		and int(Dictionary(post_finish.get("ultimate_overlay", {})).get(
			"effect_count", -1
		)) == 0
	)
	controller.queue_free()
	await process_frame
	await process_frame
	return result


func issue_ready_ultimates(controller) -> void:
	for character_id: StringName in CONFIG.get_character_ids():
		var character = controller.character_nodes.get(character_id)
		var release_limit := 1 if character_id == &"doctor" else 4
		if (
			not is_instance_valid(character)
			or not character.is_alive
			or not character.ultimate_ready
			or character.ultimate_release_count >= release_limit
			or controller.ultimate_targeting_character_id != &""
		):
			continue
		var target := choose_release_target(controller, character)
		if not bool(target.get("valid", false)):
			continue
		if controller.begin_ultimate_targeting(character_id):
			var screen_position: Vector2 = controller.logic_to_screen_position(
				target.position
			)
			controller.update_ultimate_targeting_from_screen(screen_position)
			controller.release_ultimate_targeting_from_screen(screen_position)


func choose_release_target(controller, character) -> Dictionary:
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
	if character.role_id == &"mage":
		var guard_threats: Array = []
		for candidate in candidates:
			if (
				StringName(candidate.blocked_by_character_id) == &"guard"
				or StringName(candidate.contact_target_id) == &"guard"
			):
				guard_threats.append(candidate)
		guard_threats.sort_custom(func(left, right):
			return String(left.runtime_id) < String(right.runtime_id)
		)
		if not guard_threats.is_empty():
			return {"valid": true, "position": guard_threats[0].position}
	if character.role_id == &"hunter":
		candidates.sort_custom(func(left, right):
			if absf(float(left.route_progress) - float(right.route_progress)) > 0.0001:
				return float(left.route_progress) > float(right.route_progress)
			return String(left.runtime_id) < String(right.runtime_id)
		)
		return {"valid": true, "position": candidates[0].position}
	var radius := float(character.ultimate_definition.get("effect_radius", 0.0))
	var best_enemy = null
	var best_count := -1
	for candidate in candidates:
		var count := 0
		for other in controller.active_enemies.values():
			if is_instance_valid(other) and candidate.position.distance_to(other.position) <= radius:
				count += 1
		if count > best_count or (
			count == best_count
			and is_instance_valid(best_enemy)
			and String(candidate.runtime_id) < String(best_enemy.runtime_id)
		):
			best_enemy = candidate
			best_count = count
	return {"valid": true, "position": best_enemy.position}


func run_historical_disabled_check() -> Dictionary:
	var controller = await create_controller(&"character_contact_validation", false)
	var runtime_disabled := true
	for character: Dictionary in controller.get_character_snapshots():
		runtime_disabled = runtime_disabled and (
			not bool(character.get("ultimate_enabled", false))
			and is_zero_approx(float(character.get("ultimate_energy", 0.0)))
		)
	var result := {
		"enabled": controller.is_character_ultimate_enabled(),
		"ui_exists": is_instance_valid(controller.ultimate_bar),
		"runtime_disabled": runtime_disabled,
	}
	controller.queue_free()
	await process_frame
	await process_frame
	return result


func run_pause_energy_check() -> bool:
	var controller = await create_controller(SCENARIO_ID, true)
	controller.set_automatic_simulation(true)
	var energy_before: Dictionary = collect_character_energies(
		controller.get_character_snapshots()
	)
	paused = true
	for _frame in range(4):
		await process_frame
	paused = false
	controller.set_automatic_simulation(false)
	var energy_after: Dictionary = collect_character_energies(
		controller.get_character_snapshots()
	)
	controller.queue_free()
	await process_frame
	await process_frame
	return energy_after == energy_before


func run_passive_rate_check() -> Dictionary:
	var controller = await create_ready_controller(SCENARIO_ID)
	controller.apply_recommended_deployment()
	controller.start_battle()
	controller.simulate_step(1.0)
	var expected := {
		&"guard": 1.5,
		&"hunter": 1.8,
		&"mage": 2.2,
		&"doctor": 1.3,
	}
	var exact := true
	var no_events := true
	var bounded := true
	for character: Dictionary in controller.get_character_snapshots():
		var character_id := StringName(character.get("character_id", &""))
		var expected_energy := float(expected.get(character_id, -1.0))
		exact = exact \
			and is_equal_approx(float(character.get("ultimate_energy", -1.0)), expected_energy) \
			and is_equal_approx(
				float(character.get("ultimate_passive_energy_gained", -1.0)),
				expected_energy
			)
		no_events = no_events \
			and is_zero_approx(float(character.get("ultimate_event_energy_gained", -1.0))) \
			and int(character.get("ultimate_event_trigger_count", -1)) == 0
		bounded = bounded \
			and float(character.get("ultimate_energy", -1.0)) >= 0.0 \
			and float(character.get("ultimate_energy", -1.0)) <= 100.0
	controller.queue_free()
	await process_frame
	await process_frame
	return {"exact": exact, "no_events": no_events, "bounded": bounded}


func run_geometry_checks() -> Dictionary:
	var controller = await create_ready_controller(SCENARIO_ID)
	controller.apply_recommended_deployment()
	var rectangles_configured := true
	var rectangles_clipped := true
	var preview_matches_legality := true
	var circles_round := true
	var mapping_valid := true
	var hunter_single_target := true
	var logical_size: Vector2 = controller.LOGICAL_BATTLEFIELD_SIZE
	var battlefield_rect := Rect2(Vector2.ZERO, logical_size)
	for resolution in [Vector2(1920, 1080), Vector2(1600, 900), Vector2(1366, 768)]:
		controller.apply_fullscreen_layout(resolution)
		for character_id: StringName in [&"guard", &"mage", &"doctor"]:
			var character = controller.character_nodes[character_id]
			var definition: Dictionary = character.ultimate_definition
			var cast_rect: Rect2 = controller.get_ultimate_cast_rect(character)
			var unclipped_width: float = logical_size.x * 0.5
			rectangles_configured = rectangles_configured \
				and StringName(definition.get("cast_area_shape", &"")) \
					== CONFIG.ULTIMATE_CAST_AREA_FORWARD_RECT \
				and is_equal_approx(float(definition.get("cast_rect_width_ratio", 0.0)), 0.5) \
				and StringName(definition.get("cast_rect_direction", &"")) \
					== CONFIG.ULTIMATE_CAST_DIRECTION_TOWARD_SPAWN
			rectangles_clipped = rectangles_clipped \
				and battlefield_rect.encloses(cast_rect) \
				and is_equal_approx(cast_rect.position.y, 0.0) \
				and is_equal_approx(cast_rect.size.y, logical_size.y) \
				and cast_rect.size.x <= unclipped_width + 0.0001
			var inside := cast_rect.get_center()
			var outside := Vector2(maxf(0.0, cast_rect.position.x - 1.0), inside.y)
			var preview: Dictionary = controller.build_ultimate_preview(character, inside, true)
			preview_matches_legality = preview_matches_legality \
				and controller.is_position_ultimate_target_legal(character, inside) \
				and (
					cast_rect.position.x <= 0.0
					or not controller.is_position_ultimate_target_legal(character, outside)
				) \
				and screen_polygon_matches_rect(
					PackedVector2Array(preview.get("cast_polygon", PackedVector2Array())),
					cast_rect,
					controller
				)
			var circle_points := PackedVector2Array(preview.get(
				"area_points", PackedVector2Array()
			))
			circles_round = circles_round \
				and circle_width_height_error(circle_points) <= 2.0
		var hunter = controller.character_nodes[&"hunter"]
		var hunter_preview: Dictionary = controller.build_ultimate_preview(
			hunter,
			hunter.position,
			false
		)
		hunter_single_target = hunter_single_target \
			and PackedVector2Array(hunter_preview.get(
				"cast_polygon", PackedVector2Array()
			)).is_empty() \
			and PackedVector2Array(hunter_preview.get(
				"area_points", PackedVector2Array()
			)).is_empty() \
			and bool(hunter_preview.get("draw_line", false))
		var logic_point := Vector2(925.0, 217.0)
		var screen_point: Vector2 = controller.logic_to_screen_position(logic_point)
		mapping_valid = mapping_valid \
			and controller.screen_to_logic_position(screen_point).is_equal_approx(logic_point)
	controller.apply_fullscreen_layout(Vector2(1920, 1080))
	controller.queue_free()
	await process_frame
	await process_frame
	return {
		"rectangles_configured": rectangles_configured,
		"rectangles_clipped": rectangles_clipped,
		"preview_matches_legality": preview_matches_legality,
		"circles_round": circles_round,
		"hunter_single_target": hunter_single_target,
		"mapping_valid": mapping_valid,
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


func circle_width_height_error(points: PackedVector2Array) -> float:
	if points.size() < 4:
		return INF
	var minimum := points[0]
	var maximum := points[0]
	for point: Vector2 in points:
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.y)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.y)
	var size := maximum - minimum
	return absf(size.x - size.y)


func run_invalid_input_checks() -> Dictionary:
	var controller = await create_ready_controller(SCENARIO_ID)
	controller.apply_recommended_deployment()
	controller.simulate_step(5.0)
	var ready_energy_stopped := true
	for character in controller.character_nodes.values():
		ready_energy_stopped = ready_energy_stopped \
			and is_zero_approx(float(character.ultimate_energy))
	controller.start_battle()
	var guard = controller.character_nodes[&"guard"]
	var hunter = controller.character_nodes[&"hunter"]
	var mage = controller.character_nodes[&"mage"]
	var doctor = controller.character_nodes[&"doctor"]
	var independent_initialized := true
	for character in controller.character_nodes.values():
		independent_initialized = independent_initialized \
			and is_zero_approx(float(character.ultimate_energy)) \
			and not character.ultimate_ready
	var ui_complete: bool = is_instance_valid(controller.ultimate_bar) \
		and controller.ultimate_buttons.size() == 4 \
		and controller.ultimate_energy_bars.size() == 4
	var unready_rejected: bool = not controller.begin_ultimate_targeting(&"guard")
	await advance_until_character_ready(controller, &"mage")
	var mage_ready_energy := float(mage.ultimate_energy)
	var mage_began: bool = controller.begin_ultimate_targeting(&"mage")
	var escape_result: StringName = controller.handle_escape_action()
	var escape_kept: bool = mage_began \
		and escape_result == &"CANCELED_ULTIMATE" \
		and is_equal_approx(mage.ultimate_energy, mage_ready_energy)
	controller.begin_ultimate_targeting(&"mage")
	var right_event := InputEventMouseButton.new()
	right_event.button_index = MOUSE_BUTTON_RIGHT
	right_event.pressed = true
	controller._unhandled_input(right_event)
	var right_kept: bool = is_equal_approx(mage.ultimate_energy, mage_ready_energy) \
		and controller.ultimate_targeting_character_id == &""
	controller.begin_ultimate_targeting(&"mage")
	var mage_rect: Rect2 = controller.get_ultimate_cast_rect(mage)
	var outside_logic := Vector2(maxf(0.0, mage_rect.position.x - 1.0), mage_rect.get_center().y)
	var outside_screen: Vector2 = controller.logic_to_screen_position(outside_logic)
	var outside_result: bool = controller.release_ultimate_targeting_from_screen(outside_screen)
	var outside_kept: bool = not outside_result \
		and is_equal_approx(mage.ultimate_energy, mage_ready_energy)
	await advance_until_character_ready(controller, &"hunter")
	controller.begin_ultimate_targeting(&"hunter")
	var empty_screen: Vector2 = controller.logic_to_screen_position(Vector2(30.0, 25.0))
	var no_snap_result: bool = controller.release_ultimate_targeting_from_screen(empty_screen)
	var hunter_kept: bool = not no_snap_result \
		and is_equal_approx(hunter.ultimate_energy, 100.0)
	controller.begin_ultimate_targeting(&"mage")
	var replacement_started: bool = controller.begin_ultimate_targeting(&"hunter")
	var targeting_count := 0
	for character in controller.character_nodes.values():
		if character.is_ultimate_targeting:
			targeting_count += 1
	var single_targeting_state: bool = replacement_started \
		and controller.ultimate_targeting_character_id == &"hunter" \
		and targeting_count == 1 \
		and not mage.is_ultimate_targeting \
		and is_equal_approx(mage.ultimate_energy, mage_ready_energy) \
		and is_equal_approx(hunter.ultimate_energy, 100.0)
	controller.cancel_ultimate_targeting(&"TEST_REPLACEMENT", true)
	controller.begin_ultimate_targeting(&"mage")
	controller.set_debug_panel_open(true)
	var debug_canceled_targeting: bool = controller.ultimate_targeting_character_id == &"" \
		and not mage.is_ultimate_targeting \
		and is_equal_approx(mage.ultimate_energy, mage_ready_energy) \
		and not bool(controller.ultimate_overlay.get_debug_snapshot().preview_visible)
	var debug_blocks: bool = not controller.begin_ultimate_targeting(&"mage")
	controller.set_debug_panel_open(false)
	var command_was_canceled := false
	var command_enemy = first_active_enemy(controller)
	if is_instance_valid(command_enemy):
		controller.handle_battlefield_pointer(command_enemy.position, MOUSE_BUTTON_LEFT)
		var had_command: bool = not controller.command_controller.get_active_command_snapshot().is_empty()
		controller.begin_ultimate_targeting(&"mage")
		command_was_canceled = had_command \
			and controller.command_controller.get_active_command_snapshot().is_empty()
		controller.cancel_ultimate_targeting(&"TEST_CANCEL", true)
	await advance_until_character_ready(controller, &"doctor")
	var doctor_rect: Rect2 = controller.get_ultimate_cast_rect(doctor)
	var empty_heal_logic := Vector2(doctor_rect.end.x - 2.0, 2.0)
	var doctor_energy_before := float(doctor.ultimate_energy)
	var doctor_began: bool = controller.begin_ultimate_targeting(&"doctor")
	var doctor_screen: Vector2 = controller.logic_to_screen_position(empty_heal_logic)
	var doctor_result: bool = controller.release_ultimate_targeting_from_screen(doctor_screen)
	var doctor_kept: bool = doctor_began and not doctor_result \
		and is_equal_approx(doctor.ultimate_energy, doctor_energy_before)
	var legal_release_once := false
	var effect_hits_match_circle := false
	var ultimate_granted_no_energy := false
	var mage_target := choose_release_target(controller, mage)
	if bool(mage_target.get("valid", false)):
		var before_sequence := int(controller.ultimate_release_sequence)
		var expected_ids := independent_effect_target_ids(
			controller,
			mage_target.position,
			float(mage.ultimate_definition.get("effect_radius", 0.0))
		)
		var passive_before := float(mage.ultimate_passive_energy_gained)
		var event_before := float(mage.ultimate_event_energy_gained)
		var trigger_before := int(mage.ultimate_event_trigger_count)
		var screen_position: Vector2 = controller.logic_to_screen_position(
			mage_target.position
		)
		var began: bool = controller.begin_ultimate_targeting(&"mage")
		controller.update_ultimate_targeting_from_screen(screen_position)
		var released: bool = controller.release_ultimate_targeting_from_screen(
			screen_position
		)
		var duplicate_release: bool = controller.release_ultimate_targeting_from_screen(
			screen_position
		)
		legal_release_once = began and released and not duplicate_release \
			and is_zero_approx(mage.ultimate_energy) \
			and mage.ultimate_release_count == 1 \
			and int(controller.ultimate_release_sequence) == before_sequence + 1 \
			and is_equal_approx(hunter.ultimate_energy, 100.0) \
			and is_equal_approx(doctor.ultimate_energy, doctor_energy_before)
		ultimate_granted_no_energy = is_equal_approx(
			float(mage.ultimate_passive_energy_gained), passive_before
		) and is_equal_approx(
			float(mage.ultimate_event_energy_gained), event_before
		) and int(mage.ultimate_event_trigger_count) == trigger_before
		var released_ids := latest_released_target_ids(controller)
		effect_hits_match_circle = released_ids == expected_ids
	var energy_capped := true
	for character in controller.character_nodes.values():
		energy_capped = energy_capped \
			and float(character.ultimate_energy) >= 0.0 \
			and float(character.ultimate_energy) <= 100.0
	controller.begin_ultimate_targeting(&"hunter")
	controller.restart_battle()
	var restart_clean: bool = controller.ultimate_targeting_character_id == &"" \
		and not bool(controller.ultimate_overlay.get_debug_snapshot().preview_visible)
	var restart_energy_audit_clean := true
	for character in controller.character_nodes.values():
		restart_clean = restart_clean and is_zero_approx(character.ultimate_energy)
		restart_energy_audit_clean = restart_energy_audit_clean \
			and is_zero_approx(character.ultimate_passive_energy_gained) \
			and is_zero_approx(character.ultimate_event_energy_gained) \
			and character.ultimate_event_trigger_count == 0 \
			and character.ultimate_event_trigger_counts.is_empty() \
			and character.ultimate_event_throttled_count == 0 \
			and character.ultimate_last_event_trigger_time < 0.0
	controller.queue_free()
	await process_frame
	await process_frame
	return {
		"independent_initialized": independent_initialized,
		"ready_energy_stopped": ready_energy_stopped,
		"ui_complete": ui_complete,
		"energy_capped": energy_capped,
		"unready_rejected": unready_rejected,
		"escape_kept_energy": escape_kept,
		"right_click_kept_energy": right_kept,
		"out_of_range_kept_energy": outside_kept,
		"hunter_no_snap_kept_energy": hunter_kept,
		"doctor_no_heal_kept_energy": doctor_kept,
		"single_targeting_state": single_targeting_state,
		"debug_canceled_targeting": debug_canceled_targeting,
		"debug_blocks_start": debug_blocks,
		"command_was_canceled": command_was_canceled,
		"legal_release_once": legal_release_once,
		"effect_hits_match_circle": effect_hits_match_circle,
		"ultimate_granted_no_energy": ultimate_granted_no_energy,
		"restart_clean": restart_clean,
		"restart_energy_audit_clean": restart_energy_audit_clean,
	}


func advance_until_character_ready(controller, character_id: StringName) -> bool:
	var character = controller.character_nodes.get(character_id)
	var steps := 0
	while (
		controller.battle_state == controller.BattleState.RUNNING
		and is_instance_valid(character)
		and character.is_alive
		and not character.ultimate_ready
		and steps < MAX_STEPS
	):
		controller.simulate_step(STEP)
		steps += 1
	return is_instance_valid(character) and character.is_alive and character.ultimate_ready


func independent_effect_target_ids(
	controller,
	center_logic: Vector2,
	radius: float
) -> Array[StringName]:
	var result: Array[StringName] = []
	var center_screen: Vector2 = controller.logic_to_screen_position(center_logic)
	var screen_radius := radius * float(controller.uniform_visual_scale)
	for enemy in controller.active_enemies.values():
		if (
			is_instance_valid(enemy)
			and not enemy.is_dead
			and not enemy.settlement_completed
			and center_screen.distance_to(
				controller.logic_to_screen_position(enemy.position)
			) <= screen_radius + 0.0001
		):
			result.append(StringName(enemy.runtime_id))
	result.sort()
	return result


func latest_released_target_ids(controller) -> Array[StringName]:
	var events: Array = controller.ultimate_release_events
	for index in range(events.size() - 1, -1, -1):
		var event: Dictionary = events[index]
		if StringName(event.get("kind", &"")) != &"RELEASED":
			continue
		var result: Array[StringName] = []
		for raw_id in event.get("target_ids", []):
			result.append(StringName(raw_id))
		result.sort()
		return result
	return []


func run_natural_incapacitation_cancel() -> Dictionary:
	var controller = await create_ready_controller(SCENARIO_ID)
	controller.apply_recommended_deployment()
	controller.start_battle()
	var mage = controller.character_nodes[&"mage"]
	var steps := 0
	while mage.is_alive and not mage.ultimate_ready and steps < MAX_STEPS:
		controller.simulate_step(STEP)
		steps += 1
	var began: bool = controller.begin_ultimate_targeting(&"mage")
	var energy_before := float(mage.ultimate_energy)
	while mage.is_alive and controller.battle_state == controller.BattleState.RUNNING \
			and steps < MAX_STEPS:
		controller.simulate_step(STEP)
		steps += 1
	var energy_after_down := float(mage.ultimate_energy)
	controller.simulate_step(2.0)
	var result := {
		"began": began,
		"incapacitated": mage.is_incapacitated,
		"canceled": controller.ultimate_targeting_character_id == &""
			and not mage.is_ultimate_targeting,
		"energy_preserved": is_equal_approx(float(mage.ultimate_energy), energy_before),
		"energy_stopped": is_equal_approx(float(mage.ultimate_energy), energy_after_down),
		"release_rejected": not controller.begin_ultimate_targeting(&"mage"),
		"throttle_clean": mage.ultimate_last_event_trigger_time < 0.0,
	}
	controller.queue_free()
	await process_frame
	await process_frame
	return result


func run_battle_finish_cancel() -> bool:
	var controller = await create_controller(SCENARIO_ID, true)
	var hunter = controller.character_nodes[&"hunter"]
	var steps := 0
	while controller.battle_state == controller.BattleState.RUNNING \
			and hunter.is_alive and not hunter.ultimate_ready and steps < MAX_STEPS:
		controller.simulate_step(STEP)
		steps += 1
	var began: bool = controller.begin_ultimate_targeting(&"hunter")
	var energy_before := float(hunter.ultimate_energy)
	while controller.battle_state == controller.BattleState.RUNNING and steps < MAX_STEPS:
		controller.simulate_step(STEP)
		steps += 1
	var settled_snapshot: Dictionary = controller.get_battle_snapshot()
	controller.simulate_step(2.0)
	var result: bool = began \
		and controller.battle_state != controller.BattleState.RUNNING \
		and controller.ultimate_targeting_character_id == &"" \
		and not hunter.is_ultimate_targeting \
		and is_equal_approx(float(hunter.ultimate_energy), energy_before) \
		and not bool(Dictionary(settled_snapshot.ultimate_overlay).get(
			"preview_visible", true
		)) \
		and int(Dictionary(settled_snapshot.ultimate_overlay).get(
			"effect_count", -1
		)) == 0 \
		and all_character_throttles_clear(controller)
	controller.queue_free()
	await process_frame
	await process_frame
	return result


func all_character_throttles_clear(controller) -> bool:
	for character in controller.character_nodes.values():
		if is_instance_valid(character) \
				and character.ultimate_last_event_trigger_time >= 0.0:
			return false
	return true


func run_doctor_no_revive_check() -> Dictionary:
	var controller = await create_controller(SCENARIO_ID, true)
	var doctor = controller.character_nodes[&"doctor"]
	var down_ids: Array[StringName] = []
	var heal_target = null
	var steps := 0
	while controller.battle_state == controller.BattleState.RUNNING and steps < MAX_STEPS:
		controller.simulate_step(STEP)
		steps += 1
		down_ids.clear()
		heal_target = null
		for character_id: StringName in CONFIG.get_character_ids():
			var character = controller.character_nodes.get(character_id)
			if not is_instance_valid(character):
				continue
			if character.is_incapacitated:
				down_ids.append(character_id)
			elif character.is_alive and character.current_health < character.max_health:
				if doctor.position.distance_to(character.position) <= 600.0:
					heal_target = character
		if not down_ids.is_empty() and is_instance_valid(heal_target) \
				and doctor.is_alive and doctor.ultimate_ready:
			break
	var released := false
	if not down_ids.is_empty() and is_instance_valid(heal_target) \
			and doctor.is_alive and doctor.ultimate_ready:
		var screen_position: Vector2 = controller.logic_to_screen_position(
			heal_target.position
		)
		released = controller.begin_ultimate_targeting(&"doctor")
		controller.update_ultimate_targeting_from_screen(screen_position)
		released = controller.release_ultimate_targeting_from_screen(
			screen_position
		) and released
	var down_stayed_down := not down_ids.is_empty()
	var health_capped := true
	for character_id: StringName in CONFIG.get_character_ids():
		var character = controller.character_nodes.get(character_id)
		if not is_instance_valid(character):
			continue
		health_capped = health_capped and character.current_health <= character.max_health
		if character_id in down_ids:
			down_stayed_down = down_stayed_down \
				and character.is_incapacitated \
				and is_zero_approx(float(character.current_health))
	var result := {
		"released": released,
		"down_stayed_down": down_stayed_down,
		"health_capped": health_capped,
	}
	controller.queue_free()
	await process_frame
	await process_frame
	return result


func create_controller(scenario_id: StringName, recommended: bool):
	var controller = await create_ready_controller(scenario_id)
	if recommended:
		controller.apply_recommended_deployment()
	controller.start_battle()
	return controller


func create_ready_controller(scenario_id: StringName):
	var controller = (load(SCENE_PATH) as PackedScene).instantiate()
	root.add_child(controller)
	await process_frame
	await process_frame
	controller.set_automatic_simulation(false)
	controller.select_scenario(scenario_id)
	return controller


func summarize_battle(snapshot: Dictionary, stun_observed: bool, stun_resumed: bool) -> Dictionary:
	var stats: Dictionary = snapshot.get("ultimate_stats_by_character", {})
	var events := sanitize_release_events(snapshot.get("ultimate_release_events", []))
	var role_release_total := 0
	for character_id: StringName in CONFIG.get_character_ids():
		role_release_total += int(Dictionary(stats.get(character_id, {})).get(
			"release_count", 0
		))
	var release_sequence := int(snapshot.get("ultimate_release_sequence", 0))
	return {
		"state": String(snapshot.get("state", "")),
		"duration": snappedf(float(snapshot.get("battle_elapsed", 0.0)), 0.1),
		"generated": int(snapshot.get("generated_enemy_count", 0)),
		"killed": int(snapshot.get("killed_enemy_count", 0)),
		"leaked": int(snapshot.get("leaked_enemy_count", 0)),
		"durability": int(snapshot.get("village_durability", 0)),
		"down": count_incapacitated(snapshot.get("characters", [])),
		"total_health": sum_current_health(snapshot.get("characters", [])),
		"healing_events": int(snapshot.get("healing_event_count", 0)),
		"release_count": release_sequence,
		"invalid_releases": int(snapshot.get("ultimate_invalid_release_count", 0)),
		"duplicate_settlements": int(snapshot.get("ultimate_duplicate_settlement_count", 0)),
		"targeting_clean": StringName(snapshot.get("ultimate_targeting_character_id", &"")) == &""
			and not bool(Dictionary(snapshot.get("ultimate_overlay", {})).get("preview_visible", false)),
		"stun_observed": stun_observed,
		"stun_resumed": stun_resumed,
		"release_accounting_exact": release_sequence == events.size() \
			and release_sequence == role_release_total,
		"target_ids_unique": release_events_have_unique_targets(events),
		"characters": summarize_characters(snapshot.get("characters", [])),
		"guard": summarize_ultimate(stats.get(&"guard", {})),
		"hunter": summarize_ultimate(stats.get(&"hunter", {})),
		"mage": summarize_ultimate(stats.get(&"mage", {})),
		"doctor": summarize_ultimate(stats.get(&"doctor", {})),
		"events": events,
	}


func summarize_ultimate(raw: Dictionary) -> Dictionary:
	return {
		"releases": int(raw.get("release_count", 0)),
		"hits": int(raw.get("hit_count", 0)),
		"damage": int(raw.get("damage", 0)),
		"kills": int(raw.get("kill_count", 0)),
		"stuns": int(raw.get("stun_count", 0)),
		"healed": int(raw.get("healed_character_count", 0)),
		"healing": int(raw.get("healing", 0)),
	}


func summarize_characters(raw: Array) -> Dictionary:
	var result: Dictionary = {}
	for character: Dictionary in raw:
		result[StringName(character.character_id)] = {
			"health": int(character.current_health),
			"max_health": int(character.max_health),
			"damage": int(character.total_damage_taken),
			"down": bool(character.is_incapacitated),
			"energy": snappedf(float(character.ultimate_energy), 0.1),
			"releases": int(character.ultimate_release_count),
			"first_ready": snappedf(
				float(character.ultimate_first_ready_time),
				0.1
			),
			"passive_energy": snappedf(
				float(character.ultimate_passive_energy_gained),
				0.001
			),
			"event_energy": snappedf(
				float(character.ultimate_event_energy_gained),
				0.001
			),
			"event_triggers": int(character.ultimate_event_trigger_count),
			"event_trigger_counts": Dictionary(
				character.ultimate_event_trigger_counts
			).duplicate(true),
			"event_throttled": int(character.ultimate_event_throttled_count),
		}
	return result


func sanitize_release_events(raw: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Dictionary in raw:
		if StringName(event.get("kind", &"")) != &"RELEASED":
			continue
		result.append({
			"time": float(event.get("time", 0.0)),
			"character_id": StringName(event.get("character_id", &"")),
			"ultimate_id": StringName(event.get("ultimate_id", &"")),
			"target_ids": Array(event.get("target_ids", [])).duplicate(),
			"damage": int(event.get("damage", 0)),
			"healing": int(event.get("healing", 0)),
		})
	return result


func release_events_have_unique_targets(events: Array[Dictionary]) -> bool:
	for event: Dictionary in events:
		var seen: Dictionary = {}
		for target_id in event.get("target_ids", []):
			var stable_id := StringName(target_id)
			if seen.has(stable_id):
				return false
			seen[stable_id] = true
	return true


func collect_character_energies(characters: Array) -> Dictionary:
	var result: Dictionary = {}
	for character: Dictionary in characters:
		result[StringName(character.get("character_id", &""))] = snappedf(
			float(character.get("ultimate_energy", 0.0)),
			0.001
		)
	return result


func first_active_enemy(controller):
	var enemies: Array = controller.active_enemies.values()
	enemies.sort_custom(func(left, right): return String(left.runtime_id) < String(right.runtime_id))
	return enemies[0] if not enemies.is_empty() else null


func check_resolution_mapping(controller) -> bool:
	for resolution in [Vector2(1920, 1080), Vector2(1600, 900), Vector2(1366, 768)]:
		controller.apply_fullscreen_layout(resolution)
		var logic_point := Vector2(925.0, 217.0)
		var screen_point: Vector2 = controller.logic_to_screen_position(logic_point)
		if not controller.screen_to_logic_position(screen_point).is_equal_approx(logic_point):
			return false
		if not is_equal_approx(controller.ultimate_bar.scale.x, controller.ultimate_bar.scale.y):
			return false
	controller.apply_fullscreen_layout(Vector2(1920, 1080))
	return true


func count_roles_released(result: Dictionary) -> int:
	var count := 0
	for role_id: StringName in CONFIG.get_character_ids():
		if int(Dictionary(result.get(role_id, {})).get("releases", 0)) > 0:
			count += 1
	return count


func unattended_energy_sources_match_rules(result: Dictionary) -> bool:
	var guard: Dictionary = result.characters.guard
	var hunter: Dictionary = result.characters.hunter
	var mage: Dictionary = result.characters.mage
	var doctor: Dictionary = result.characters.doctor
	return (
		Dictionary(guard.event_trigger_counts).keys() == [&"DAMAGE_TAKEN"]
		and int(guard.event_triggers) == 11
		and is_equal_approx(float(guard.event_energy), 33.0)
		and Dictionary(hunter.event_trigger_counts).keys() == [&"NORMAL_ATTACK_HIT"]
		and is_equal_approx(
			float(hunter.event_energy),
			float(Dictionary(hunter.event_trigger_counts).get(&"NORMAL_ATTACK_HIT", 0))
		)
		and Dictionary(mage.event_trigger_counts).keys() == [&"NORMAL_ATTACK_HIT"]
		and is_equal_approx(
			float(mage.event_energy),
			float(Dictionary(mage.event_trigger_counts).get(&"NORMAL_ATTACK_HIT", 0)) * 2.0
		)
		and Dictionary(doctor.event_trigger_counts).keys() == [&"AUTO_HEAL"]
		and float(doctor.event_energy) > 0.0
		and float(doctor.event_energy)
			<= float(Dictionary(doctor.event_trigger_counts).get(&"AUTO_HEAL", 0)) * 4.0
	)


func commanded_energy_sources_match_rules(result: Dictionary) -> bool:
	var hunter: Dictionary = result.characters.hunter
	var mage: Dictionary = result.characters.mage
	var doctor: Dictionary = result.characters.doctor
	var hunter_counts := Dictionary(hunter.event_trigger_counts)
	var mage_counts := Dictionary(mage.event_trigger_counts)
	var doctor_counts := Dictionary(doctor.event_trigger_counts)
	return (
		int(hunter_counts.get(&"NORMAL_ATTACK_HIT", 0)) > 0
		and int(hunter_counts.get(&"NORMAL_ATTACK_KILL", 0)) > 0
		and is_equal_approx(
			float(hunter.event_energy),
			float(hunter_counts.get(&"NORMAL_ATTACK_HIT", 0))
				+ float(hunter_counts.get(&"NORMAL_ATTACK_KILL", 0)) * 5.0
		)
		and int(mage_counts.get(&"NORMAL_ATTACK_HIT", 0)) > 0
		and is_equal_approx(
			float(mage.event_energy),
			float(mage_counts.get(&"NORMAL_ATTACK_HIT", 0)) * 2.0
		)
		and int(doctor_counts.get(&"AUTO_HEAL", 0)) > 0
		and float(doctor.event_energy)
			<= float(doctor_counts.get(&"AUTO_HEAL", 0)) * 4.0
		and hunter_counts.size() == 2
		and mage_counts.size() == 1
		and doctor_counts.size() == 1
	)


func first_ready_times_are_differentiated(result: Dictionary) -> bool:
	var ready_times: Array[float] = []
	for role_id: StringName in CONFIG.get_character_ids():
		var ready_time := float(Dictionary(result.characters.get(role_id, {})).get(
			"first_ready", -1.0
		))
		if ready_time >= 0.0:
			ready_times.append(ready_time)
	if ready_times.size() < 3:
		return false
	for left_index in range(ready_times.size()):
		for right_index in range(left_index + 1, ready_times.size()):
			if is_equal_approx(ready_times[left_index], ready_times[right_index]):
				return false
	return true


func all_character_energies_bounded(result: Dictionary) -> bool:
	for character: Dictionary in result.characters.values():
		var energy := float(character.get("energy", -1.0))
		if energy < 0.0 or energy > 100.0:
			return false
	return true


func operation_has_benefit(unattended: Dictionary, commanded: Dictionary) -> bool:
	return (
		float(commanded.duration) < float(unattended.duration) - 0.05
		or int(commanded.leaked) < int(unattended.leaked)
		or int(commanded.durability) > int(unattended.durability)
		or int(commanded.down) < int(unattended.down)
		or int(commanded.total_health) > int(unattended.total_health)
	)


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


func count_planned_enemies(config: Dictionary) -> int:
	var result := 0
	for wave: Dictionary in config.get("waves", []):
		for subwave: Dictionary in wave.get("subwaves", []):
			for group: Dictionary in subwave.get("spawn_groups", []):
				result += int(group.get("count", 0))
	return result


func battle_uses_only_charge(config: Dictionary) -> bool:
	for wave: Dictionary in config.get("waves", []):
		for subwave: Dictionary in wave.get("subwaves", []):
			for group: Dictionary in subwave.get("spawn_groups", []):
				if StringName(group.get("enemy_profile_id", &"")) != &"charge":
					return false
	return true


func historical_battles_keep_ultimates_disabled() -> bool:
	for battle_id: StringName in [
		&"v2_5b_validation", &"v2_5c_pacing_validation",
		&"v2_6a_formation_guard_validation", &"v2_6b_rush_raider_validation",
		&"v2_6b_mixed_threat_validation", &"v2_7a_character_contact_validation",
	]:
		if bool(CONFIG.get_wave_battle_config(battle_id).get(
			"character_ultimate_enabled",
			CONFIG.DEFAULT_CHARACTER_ULTIMATE_ENABLED
		)):
			return false
	return true


func ultimate_definitions_match_spec() -> bool:
	var guard := CONFIG.get_character_ultimate_definition(&"guard")
	var hunter := CONFIG.get_character_ultimate_definition(&"hunter")
	var mage := CONFIG.get_character_ultimate_definition(&"mage")
	var doctor := CONFIG.get_character_ultimate_definition(&"doctor")
	return (
		int(guard.get("damage", 0)) == 35
		and is_equal_approx(float(guard.get("cast_range", 0.0)), 320.0)
		and is_equal_approx(float(guard.get("effect_radius", 0.0)), 140.0)
		and is_equal_approx(float(guard.get("stun_duration", 0.0)), 1.5)
		and is_equal_approx(float(guard.get("energy_regen_per_second", 0.0)), 1.5)
		and is_equal_approx(float(Dictionary(guard.get("event_energy", {})).get(
			&"DAMAGE_TAKEN", 0.0
		)), 3.0)
		and is_equal_approx(float(guard.get("event_trigger_interval", 0.0)), 0.75)
		and int(hunter.get("damage", 0)) == 140
		and is_equal_approx(float(hunter.get("cast_range", 0.0)), 900.0)
		and is_equal_approx(float(hunter.get("snap_radius", 0.0)), 70.0)
		and is_equal_approx(float(hunter.get("energy_regen_per_second", 0.0)), 1.8)
		and is_equal_approx(float(Dictionary(hunter.get("event_energy", {})).get(
			&"NORMAL_ATTACK_HIT", 0.0
		)), 1.0)
		and is_equal_approx(float(Dictionary(hunter.get("event_energy", {})).get(
			&"NORMAL_ATTACK_KILL", 0.0
		)), 5.0)
		and int(mage.get("damage", 0)) == 70
		and is_equal_approx(float(mage.get("effect_radius", 0.0)), 180.0)
		and is_equal_approx(float(mage.get("energy_regen_per_second", 0.0)), 2.2)
		and is_equal_approx(float(Dictionary(mage.get("event_energy", {})).get(
			&"NORMAL_ATTACK_HIT", 0.0
		)), 2.0)
		and int(doctor.get("healing", 0)) == 90
		and is_equal_approx(float(doctor.get("effect_radius", 0.0)), 200.0)
		and is_equal_approx(float(doctor.get("energy_regen_per_second", 0.0)), 1.3)
		and is_equal_approx(float(Dictionary(doctor.get("event_energy", {})).get(
			&"AUTO_HEAL", 0.0
		)), 4.0)
		and StringName(guard.get("cast_area_shape", &"")) \
			== CONFIG.ULTIMATE_CAST_AREA_FORWARD_RECT
		and StringName(mage.get("cast_area_shape", &"")) \
			== CONFIG.ULTIMATE_CAST_AREA_FORWARD_RECT
		and StringName(doctor.get("cast_area_shape", &"")) \
			== CONFIG.ULTIMATE_CAST_AREA_FORWARD_RECT
		and is_equal_approx(float(guard.get("cast_rect_width_ratio", 0.0)), 0.5)
		and is_equal_approx(float(mage.get("cast_rect_width_ratio", 0.0)), 0.5)
		and is_equal_approx(float(doctor.get("cast_rect_width_ratio", 0.0)), 0.5)
		and not hunter.has("cast_area_shape")
		and is_equal_approx(float(guard.get("energy_cost", 0.0)), 100.0)
		and is_equal_approx(float(hunter.get("energy_cost", 0.0)), 100.0)
		and is_equal_approx(float(mage.get("energy_cost", 0.0)), 100.0)
		and is_equal_approx(float(doctor.get("energy_cost", 0.0)), 100.0)
	)


func smoke_uses_no_runtime_shortcuts() -> bool:
	var file := FileAccess.open(
		"res://prototype/formation_defense/tests/smoke_v2_7a_p_character_ultimates.gd",
		FileAccess.READ
	)
	if file == null:
		return false
	var source := file.get_as_text()
	for forbidden: String in [
		".ultimate_energy" + " =",
		".current_health" + " =",
		".take_" + "damage(",
		".receive_" + "healing(",
		".apply_" + "stun(",
		".route_progress" + " =",
		".traveled_distance" + " =",
	]:
		if source.find(forbidden) >= 0:
			return false
	return (
		source.find("begin_ultimate_targeting") >= 0
		and source.find("update_ultimate_targeting_from_screen") >= 0
		and source.find("release_ultimate_targeting_from_screen") >= 0
	)


func print_result(label: String, result: Dictionary) -> void:
	print("v2-7a-p %s: state=%s duration=%.1f generated=%d killed=%d leaked=%d durability=%d down=%d health=%d releases=%d auto_heals=%d guard=%s hunter=%s mage=%s doctor=%s characters=%s" % [
		label, result.state, result.duration, result.generated, result.killed,
		result.leaked, result.durability, result.down, result.total_health,
		result.release_count, result.healing_events, str(result.guard), str(result.hunter),
		str(result.mage), str(result.doctor), str(result.characters),
	])


func check(condition: bool, message: String) -> void:
	check_count += 1
	if not condition:
		failures.append(message)

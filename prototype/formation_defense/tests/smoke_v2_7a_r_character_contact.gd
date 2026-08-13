extends SceneTree

const SCENE_PATH := "res://prototype/formation_defense/scenes/formation_defense_prototype.tscn"
const CONFIG := preload("res://prototype/formation_defense/data/formation_defense_config.gd")
const WaveDirector := preload("res://prototype/formation_defense/scripts/formation_defense_wave_director.gd")
const STEP := 0.1
const MAX_STEPS := 2200

const PROTECTED_DEPLOYMENT := {
	&"guard": &"top_c4",
	&"hunter": &"top_c2",
	&"mage": &"bottom_c2",
	&"doctor": &"middle_c2",
}
const FRONT_DEPLOYMENT := {
	&"guard": &"middle_c4",
	&"hunter": &"top_c4",
	&"mage": &"bottom_c4",
	&"doctor": &"middle_c3",
}
const FRAGILE_FRONT_DEPLOYMENT := {
	&"guard": &"middle_c2",
	&"hunter": &"top_c2",
	&"mage": &"middle_c4",
	&"doctor": &"bottom_c2",
}

var failures: Array[String] = []
var check_count := 0


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var config := CONFIG.get_wave_battle_config(
		&"v2_7a_character_contact_validation"
	)
	var validation := WaveDirector.validate_battle_config(
		config,
		CONFIG.get_monster_type_ids(),
		CONFIG.get_spawn_point_lane_map(),
		CONFIG.get_visual_route_ids()
	)
	check(validation.is_empty(), "V2-7A-R battle configuration validates")
	check(
		StringName(config.get("battle_id", &""))
			== &"v2_7a_character_contact_validation"
			and int(config.get("random_seed", 0)) == 2701,
		"contact validation owns the requested battle ID and fixed seed"
	)
	check(
		not CONFIG.DEFAULT_CHARACTER_CONTACT_COMBAT_ENABLED
			and bool(config.get("character_contact_combat_enabled", false)),
		"character contact defaults off and is enabled only by the validation battle"
	)
	check(
		historical_battles_keep_contact_disabled(),
		"all historical wave battles keep character contact disabled"
	)
	check(
		count_planned_enemies(config) == 12 and battle_uses_only_charge(config),
		"three validation segments plan twelve ordinary enemies only"
	)
	check(
		CONFIG.get_recommended_deployment(&"character_contact_validation")
			== PROTECTED_DEPLOYMENT,
		"scenario selector exposes the protected reference deployment"
	)
	var contact_config: Dictionary = config.get("character_contact_combat", {})
	check(
		contact_config.get("eligible_enemy_profile_ids", []) == [&"charge"]
			and is_equal_approx(float(contact_config.get("acquisition_range", 0.0)), 300.0)
			and is_equal_approx(float(contact_config.get("attack_range", 0.0)), 160.0)
			and int(contact_config.get("attack_damage", 0)) == 20
			and is_equal_approx(float(contact_config.get("attack_interval", 0.0)), 0.8),
		"contact distance, damage and cooldown come from prototype battle configuration"
	)
	check(character_runtime_health_is_local(), "prototype role health remains local and differentiated")

	var protected_first := await run_deployment(PROTECTED_DEPLOYMENT)
	var protected_second := await run_deployment(PROTECTED_DEPLOYMENT)
	var front_first := await run_deployment(FRONT_DEPLOYMENT)
	var front_second := await run_deployment(FRONT_DEPLOYMENT)
	var fragile_first := await run_deployment(FRAGILE_FRONT_DEPLOYMENT)
	var fragile_second := await run_deployment(FRAGILE_FRONT_DEPLOYMENT)
	var no_target := await run_deployment({})
	var restart_result := await run_restart_check()
	var historical_mixed := await run_historical_mixed_baseline()

	check(protected_first == protected_second, "protected deployment repeats deterministically")
	check(front_first == front_second, "all-front deployment repeats deterministically")
	check(fragile_first == fragile_second, "fragile-front deployment repeats deterministically")
	for result: Dictionary in [protected_first, front_first, fragile_first]:
		check(int(result.contact_acquisitions) > 0, "%s enters contact" % result.label)
		check(int(result.contact_attacking) > 0, "%s reaches attacking state" % result.label)
		check(int(result.enemy_attacks) > 0, "%s resolves enemy attacks" % result.label)
		check(bool(result.stopped_while_attacking), "%s enemies stop while attacking" % result.label)
		check(bool(result.moved_while_engaging), "%s enemies approach before attacking" % result.label)
		check(bool(result.cooldowns_valid), "%s attacks respect configured cooldown" % result.label)
		check(bool(result.first_attack_delays_valid), "%s first attacks wait for cooldown" % result.label)
		check(bool(result.target_history_valid), "%s target history has no live-target jitter" % result.label)
		check(int(result.wrong_lane_attacks) == 0, "%s has no cross-lane attack" % result.label)
		check(int(result.total_damage_taken) > 0, "%s records runtime character damage" % result.label)
		check(bool(result.incapacitations_unique), "%s characters incapacitate at most once" % result.label)
		check(bool(result.downed_actions_stopped), "%s incapacitated characters stop acting" % result.label)
		check(bool(result.post_finish_stable), "%s contact timers stop after battle finish" % result.label)
		check(bool(result.transient_visuals_cleared), "%s clears hit flashes at battle finish" % result.label)

	check(
		int(protected_first.characters.guard.damage_taken)
			> int(protected_first.characters.hunter.damage_taken),
		"front guard absorbs more damage than the protected same-lane hunter"
	)
	check(
		front_character_protects_rear(
			protected_first.events,
			&"guard",
			&"hunter",
			&"top"
		),
		"top-lane enemies cannot bypass the front guard to attack the hunter"
	)
	check(
		front_exposes_fragile_roles(protected_first, front_first),
		"moving fragile roles forward produces an observable health or incapacitation cost"
	)
	check(
		not front_is_strictly_better(protected_first, front_first),
		"all-front deployment is not simultaneously better on all four acceptance axes"
	)
	check(
		first_target_for_lane(fragile_first.events, &"middle") == &"mage",
		"fragile middle-lane front target is hit before the rear guard"
	)
	check(
		int(fragile_first.characters.mage.incapacitations) >= 1,
		"incorrect fragile-front placement causes a clear incapacitation cost"
	)
	check(
		int(protected_first.resume_count) >= 1
			or int(front_first.resume_count) >= 1
			or int(fragile_first.resume_count) >= 1,
		"at least one enemy clears an incapacitated target and resumes advance"
	)
	check(
		no_target.contact_acquisitions == 0
			and no_target.enemy_attacks == 0
			and no_target.leaked == 10
			and no_target.durability == 0
			and no_target.state == "DEFEAT",
		"without legal targets enemies continue and settle leak damage once"
	)
	check(
		uncontacted_health_bars_are_hidden(no_target.characters),
		"contact health bars remain hidden when no character was engaged"
	)
	check(bool(restart_result.valid), "restart restores health and clears contact runtime state")
	check(
		historical_mixed.state == "VICTORY"
			and absf(float(historical_mixed.duration) - 124.7) <= 0.15
			and historical_mixed.killed == 17
			and historical_mixed.leaked == 6
			and historical_mixed.durability == 4
			and historical_mixed.completed_a == 8
			and historical_mixed.completed_b == 2
			and historical_mixed.contact_events == 0,
		"V2-6B-P unattended baseline is unchanged while contact is disabled"
	)
	check(smoke_has_no_runtime_shortcuts(), "Smoke observes public runtime logic without health or target writes")

	print_result(protected_first)
	print_result(front_first)
	print_result(fragile_first)
	print_result(no_target)
	print("v2-7a-r restart=%s" % str(restart_result))
	print("v2-7a-r historical-mixed=%s" % str(historical_mixed))
	if failures.is_empty():
		print("v2-7a-r character contact smoke ok: %d requirements" % check_count)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func run_deployment(deployment: Dictionary) -> Dictionary:
	var controller = (load(SCENE_PATH) as PackedScene).instantiate()
	root.add_child(controller)
	await process_frame
	await process_frame
	controller.set_automatic_simulation(false)
	controller.select_scenario(&"character_contact_validation")
	apply_public_deployment(controller, deployment)
	controller.start_battle()
	var stopped_while_attacking := true
	var moved_while_engaging := false
	var previous_distance: Dictionary = {}
	var previous_state: Dictionary = {}
	var previous_target: Dictionary = {}
	var down_action_counts: Dictionary = {}
	var downed_actions_stopped := true
	var steps := 0
	while controller.battle_state == controller.BattleState.RUNNING and steps < MAX_STEPS:
		for enemy in controller.active_enemies.values():
			if is_instance_valid(enemy):
				previous_distance[enemy.runtime_id] = float(enemy.traveled_distance)
				previous_state[enemy.runtime_id] = StringName(enemy.contact_state)
				previous_target[enemy.runtime_id] = StringName(enemy.contact_target_id)
		controller.simulate_step(STEP)
		for enemy in controller.active_enemies.values():
			if not is_instance_valid(enemy) or not previous_distance.has(enemy.runtime_id):
				continue
			var distance_delta := float(enemy.traveled_distance) - float(
				previous_distance[enemy.runtime_id]
			)
			if (
				StringName(previous_state.get(enemy.runtime_id, &""))
					== enemy.CONTACT_STATE_ATTACKING
				and StringName(previous_target.get(enemy.runtime_id, &""))
					== StringName(enemy.contact_target_id)
				and StringName(enemy.contact_state) == enemy.CONTACT_STATE_ATTACKING
			):
				stopped_while_attacking = stopped_while_attacking and absf(distance_delta) <= 0.0001
			if StringName(previous_state.get(enemy.runtime_id, &"")) \
					== enemy.CONTACT_STATE_ENGAGING and distance_delta > 0.0001:
				moved_while_engaging = true
		for character in controller.character_nodes.values():
			if not is_instance_valid(character) or character.is_alive:
				continue
			if not down_action_counts.has(character.character_id):
				down_action_counts[character.character_id] = int(character.action_count)
			else:
				downed_actions_stopped = downed_actions_stopped and (
					int(character.action_count)
						== int(down_action_counts[character.character_id])
					and character.current_target_id == &""
				)
		steps += 1
	var snapshot: Dictionary = controller.get_battle_snapshot()
	var events: Array = snapshot.get("character_contact_events", [])
	var finish_attack_count := int(snapshot.get("enemy_attack_event_count", 0))
	var finish_event_count := events.size()
	controller.simulate_step(2.0)
	var post_finish_snapshot: Dictionary = controller.get_battle_snapshot()
	var result := {
		"label": deployment_label(deployment),
		"state": String(snapshot.get("state", "")),
		"duration": snappedf(float(snapshot.get("battle_elapsed", 0.0)), 0.1),
		"generated": int(snapshot.get("generated_enemy_count", 0)),
		"killed": int(snapshot.get("killed_enemy_count", 0)),
		"leaked": int(snapshot.get("leaked_enemy_count", 0)),
		"durability": int(snapshot.get("village_durability", 0)),
		"contact_acquisitions": int(snapshot.get("character_contact_acquisition_count", 0)),
		"contact_attacking": int(snapshot.get("character_contact_attack_state_count", 0)),
		"enemy_attacks": int(snapshot.get("enemy_attack_event_count", 0)),
		"resume_count": int(snapshot.get("character_contact_resume_count", 0)),
		"wrong_lane_attacks": int(snapshot.get("character_contact_wrong_lane_attack_count", 0)),
		"target_switches": int(snapshot.get("character_contact_target_switch_count", 0)),
		"characters": summarize_characters(snapshot.get("characters", [])),
		"total_damage_taken": sum_character_damage(snapshot.get("characters", [])),
		"incapacitated_count": count_incapacitated(snapshot.get("characters", [])),
		"stopped_while_attacking": stopped_while_attacking,
		"moved_while_engaging": moved_while_engaging,
		"cooldowns_valid": attack_cooldowns_are_valid(events, 0.8),
		"first_attack_delays_valid": first_attack_delays_are_valid(events, 0.8),
		"target_history_valid": target_history_is_valid(events),
		"incapacitations_unique": incapacitations_are_unique(snapshot.get("characters", [])),
		"downed_actions_stopped": downed_actions_stopped,
		"post_finish_stable": (
			int(post_finish_snapshot.get("enemy_attack_event_count", 0))
				== finish_attack_count
			and Array(post_finish_snapshot.get("character_contact_events", [])).size()
				== finish_event_count
		),
		"transient_visuals_cleared": transient_visuals_are_cleared(
			snapshot.get("characters", [])
		),
		"events": sanitize_events(events),
	}
	controller.queue_free()
	await process_frame
	await process_frame
	return result


func run_restart_check() -> Dictionary:
	var controller = (load(SCENE_PATH) as PackedScene).instantiate()
	root.add_child(controller)
	await process_frame
	await process_frame
	controller.set_automatic_simulation(false)
	controller.select_scenario(&"character_contact_validation")
	apply_public_deployment(controller, FRONT_DEPLOYMENT)
	controller.start_battle()
	var steps := 0
	while controller.enemy_attack_event_count == 0 and steps < MAX_STEPS:
		controller.simulate_step(STEP)
		steps += 1
	var had_damage := sum_character_damage(controller.get_character_snapshots()) > 0
	controller.restart_battle()
	var characters_reset := true
	for character: Dictionary in controller.get_character_snapshots():
		characters_reset = characters_reset and (
			int(character.current_health) == int(character.max_health)
			and bool(character.is_alive)
			and not bool(character.is_incapacitated)
			and int(character.total_damage_taken) == 0
			and int(character.incapacitation_count) == 0
			and float(character.hit_flash_remaining) == 0.0
		)
	var no_targets := true
	for enemy in controller.active_enemies.values():
		if is_instance_valid(enemy):
			no_targets = no_targets and enemy.contact_target_id == &""
	var valid: bool = (
		had_damage
		and characters_reset
		and no_targets
		and controller.character_contact_events.is_empty()
		and controller.enemy_attack_event_count == 0
	)
	var result := {
		"valid": valid,
		"had_damage": had_damage,
		"characters_reset": characters_reset,
		"no_targets": no_targets,
	}
	controller.queue_free()
	await process_frame
	await process_frame
	return result


func run_historical_mixed_baseline() -> Dictionary:
	var controller = (load(SCENE_PATH) as PackedScene).instantiate()
	root.add_child(controller)
	await process_frame
	await process_frame
	controller.set_automatic_simulation(false)
	controller.select_scenario(&"mixed_threat_validation")
	controller.apply_recommended_deployment()
	controller.start_battle()
	var steps := 0
	while controller.battle_state == controller.BattleState.RUNNING and steps < 3000:
		controller.simulate_step(STEP)
		steps += 1
	var snapshot: Dictionary = controller.get_battle_snapshot()
	var stats: Dictionary = snapshot.get("formation_stats", {})
	var result := {
		"state": String(snapshot.get("state", "")),
		"duration": snappedf(float(snapshot.get("battle_elapsed", 0.0)), 0.1),
		"killed": int(snapshot.get("killed_enemy_count", 0)),
		"leaked": int(snapshot.get("leaked_enemy_count", 0)),
		"durability": int(snapshot.get("village_durability", 0)),
		"completed_a": int(stats.get("completed_a_count", 0)),
		"completed_b": int(stats.get("completed_b_count", 0)),
		"contact_events": int(snapshot.get("character_contact_acquisition_count", 0)),
	}
	controller.queue_free()
	await process_frame
	await process_frame
	return result


func apply_public_deployment(controller, deployment: Dictionary) -> bool:
	controller.clear_deployment()
	for character_id: StringName in CONFIG.get_character_ids():
		var slot_id := StringName(deployment.get(character_id, &""))
		if slot_id == &"":
			continue
		if not controller.deploy_character(character_id, slot_id):
			return false
	return true


func summarize_characters(raw_characters: Array) -> Dictionary:
	var result: Dictionary = {}
	for character: Dictionary in raw_characters:
		result[StringName(character.character_id)] = {
			"max_health": int(character.max_health),
			"health": int(character.current_health),
			"damage_taken": int(character.total_damage_taken),
			"incapacitated": bool(character.is_incapacitated),
			"incapacitations": int(character.incapacitation_count),
			"actions": int(character.action_count),
			"current_target_id": String(character.current_target_id),
			"contacted": bool(character.has_been_contacted),
			"health_bar_visible": bool(character.health_bar_visible),
			"hit_flash_remaining": float(character.hit_flash_remaining),
		}
	return result


func sum_character_damage(raw_characters: Array) -> int:
	var result := 0
	for character: Dictionary in raw_characters:
		result += int(character.get("total_damage_taken", 0))
	return result


func count_incapacitated(raw_characters: Array) -> int:
	var result := 0
	for character: Dictionary in raw_characters:
		if bool(character.get("is_incapacitated", false)):
			result += 1
	return result


func attack_cooldowns_are_valid(events: Array, expected_interval: float) -> bool:
	var last_attack_time: Dictionary = {}
	for event: Dictionary in events:
		if StringName(event.get("kind", &"")) != &"ATTACK_RESOLVED":
			continue
		var sequence := int(event.get("enemy_sequence", -1))
		var time := float(event.get("time", 0.0))
		if last_attack_time.has(sequence) \
				and time - float(last_attack_time[sequence]) < expected_interval - STEP - 0.001:
			return false
		last_attack_time[sequence] = time
	return true


func first_attack_delays_are_valid(events: Array, expected_interval: float) -> bool:
	var pending_start: Dictionary = {}
	for event: Dictionary in events:
		var kind := StringName(event.get("kind", &""))
		var sequence := int(event.get("enemy_sequence", -1))
		if kind == &"ATTACKING_STARTED":
			pending_start[sequence] = float(event.get("time", 0.0))
		elif kind == &"ATTACK_RESOLVED" and pending_start.has(sequence):
			if (
				float(event.get("time", 0.0)) - float(pending_start[sequence])
					< expected_interval - STEP - 0.001
			):
				return false
			pending_start.erase(sequence)
	return true


func incapacitations_are_unique(raw_characters: Array) -> bool:
	for character: Dictionary in raw_characters:
		if int(character.get("incapacitation_count", 0)) > 1:
			return false
		if bool(character.get("is_incapacitated", false)) and (
			bool(character.get("is_alive", true))
			or StringName(character.get("current_target_id", &"")) != &""
		):
			return false
	return true


func transient_visuals_are_cleared(raw_characters: Array) -> bool:
	for character: Dictionary in raw_characters:
		if float(character.get("hit_flash_remaining", 0.0)) > 0.0:
			return false
	return true


func uncontacted_health_bars_are_hidden(characters: Dictionary) -> bool:
	for character: Dictionary in characters.values():
		if bool(character.contacted) or bool(character.health_bar_visible):
			return false
	return true


func target_history_is_valid(events: Array) -> bool:
	var last_target: Dictionary = {}
	var incapacitated_targets: Dictionary = {}
	for event: Dictionary in events:
		var kind := StringName(event.get("kind", &""))
		var sequence := int(event.get("enemy_sequence", -1))
		var target := StringName(event.get("target_id", &""))
		if kind == &"CHARACTER_INCAPACITATED":
			incapacitated_targets[target] = true
		elif kind == &"TARGET_ACQUIRED":
			if last_target.has(sequence) \
					and StringName(last_target[sequence]) != target \
					and not incapacitated_targets.has(StringName(last_target[sequence])):
				return false
			last_target[sequence] = target
	return true


func front_character_protects_rear(
	events: Array,
	front_id: StringName,
	rear_id: StringName,
	lane_id: StringName
) -> bool:
	var front_was_targeted := false
	var front_is_down := false
	for event: Dictionary in events:
		if StringName(event.get("lane_id", &"")) != lane_id:
			continue
		var kind := StringName(event.get("kind", &""))
		var target_id := StringName(event.get("target_id", &""))
		if kind == &"TARGET_ACQUIRED" and target_id == front_id:
			front_was_targeted = true
		elif kind == &"CHARACTER_INCAPACITATED" and target_id == front_id:
			front_is_down = true
		elif kind == &"TARGET_ACQUIRED" and target_id == rear_id and not front_is_down:
			return false
	return front_was_targeted


func first_target_for_lane(events: Array, lane_id: StringName) -> StringName:
	for event: Dictionary in events:
		if (
			StringName(event.get("kind", &"")) == &"TARGET_ACQUIRED"
			and StringName(event.get("lane_id", &"")) == lane_id
		):
			return StringName(event.get("target_id", &""))
	return &""


func sanitize_events(events: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Dictionary in events:
		result.append({
			"time": snappedf(float(event.get("time", 0.0)), 0.1),
			"kind": String(event.get("kind", "")),
			"enemy_sequence": int(event.get("enemy_sequence", -1)),
			"target_id": String(event.get("target_id", "")),
			"target_slot_id": String(event.get("target_slot_id", "")),
			"lane_id": String(event.get("lane_id", "")),
			"target_lane_id": String(event.get("target_lane_id", "")),
			"applied_damage": int(event.get("applied_damage", 0)),
			"remaining_health": int(event.get("remaining_health", -1)),
		})
	return result


func front_exposes_fragile_roles(protected: Dictionary, front: Dictionary) -> bool:
	for character_id: StringName in [&"hunter", &"mage", &"doctor"]:
		var protected_character: Dictionary = protected.characters[character_id]
		var front_character: Dictionary = front.characters[character_id]
		if (
			int(front_character.damage_taken) > int(protected_character.damage_taken)
			or (
				bool(front_character.incapacitated)
				and not bool(protected_character.incapacitated)
			)
		):
			return true
	return false


func front_is_strictly_better(protected: Dictionary, front: Dictionary) -> bool:
	var front_health := total_remaining_health(front.characters)
	var protected_health := total_remaining_health(protected.characters)
	return (
		float(front.duration) <= float(protected.duration)
		and int(front.durability) >= int(protected.durability)
		and front_health >= protected_health
		and int(front.incapacitated_count) <= int(protected.incapacitated_count)
	)


func total_remaining_health(characters: Dictionary) -> int:
	var result := 0
	for character: Dictionary in characters.values():
		result += int(character.health)
	return result


func deployment_label(deployment: Dictionary) -> String:
	if deployment.is_empty():
		return "no-target"
	if deployment == PROTECTED_DEPLOYMENT:
		return "protected"
	if deployment == FRONT_DEPLOYMENT:
		return "all-front"
	return "fragile-front"


func count_planned_enemies(config: Dictionary) -> int:
	var result := 0
	for wave: Dictionary in config.get("waves", []):
		result += WaveDirector.count_wave_enemies(wave)
	return result


func battle_uses_only_charge(config: Dictionary) -> bool:
	for wave: Dictionary in config.get("waves", []):
		for subwave: Dictionary in wave.get("subwaves", []):
			for group: Dictionary in subwave.get("spawn_groups", []):
				if StringName(group.get("enemy_profile_id", &"")) != &"charge":
					return false
	return true


func historical_battles_keep_contact_disabled() -> bool:
	for battle_id: StringName in [
		&"v2_5b_validation",
		&"v2_5c_pacing",
		&"v2_6a_formation_guard_validation",
		&"v2_6b_rush_raider_validation",
		&"v2_6b_mixed_threat_validation",
	]:
		if bool(CONFIG.get_wave_battle_config(battle_id).get(
			"character_contact_combat_enabled",
			CONFIG.DEFAULT_CHARACTER_CONTACT_COMBAT_ENABLED
		)):
			return false
	return true


func character_runtime_health_is_local() -> bool:
	return (
		int(CONFIG.get_character_definition(&"guard").get("max_health", 0)) == 150
		and int(CONFIG.get_character_definition(&"hunter").get("max_health", 0)) == 90
		and int(CONFIG.get_character_definition(&"mage").get("max_health", 0)) == 80
		and int(CONFIG.get_character_definition(&"doctor").get("max_health", 0)) == 100
	)


func smoke_has_no_runtime_shortcuts() -> bool:
	var file := FileAccess.open(
		"res://prototype/formation_defense/tests/smoke_v2_7a_r_character_contact.gd",
		FileAccess.READ
	)
	if file == null:
		return false
	var source := file.get_as_text()
	var start := source.find("func run_deployment")
	var finish := source.find("\nfunc run_restart_check", start)
	if start < 0 or finish <= start:
		return false
	var runtime_source := source.substr(start, finish - start)
	for forbidden: String in [
		".take_" + "damage(",
		".current_health = ",
		".contact_target_id = ",
		".contact_state = ",
		".route_progress = ",
		".traveled_distance = ",
		".is_incapacitated = ",
	]:
		if runtime_source.find(forbidden) >= 0:
			return false
	return runtime_source.find("controller.simulate_step(STEP)") >= 0


func print_result(result: Dictionary) -> void:
	print("v2-7a-r %s: state=%s duration=%.1f generated=%d killed=%d leaked=%d durability=%d contact/attacking/attacks/resume=%d/%d/%d/%d damage=%d down=%d characters=%s" % [
		result.label,
		result.state,
		result.duration,
		result.generated,
		result.killed,
		result.leaked,
		result.durability,
		result.contact_acquisitions,
		result.contact_attacking,
		result.enemy_attacks,
		result.resume_count,
		result.total_damage_taken,
		result.incapacitated_count,
		str(result.characters),
	])


func check(condition: bool, message: String) -> void:
	check_count += 1
	if not condition:
		failures.append(message)

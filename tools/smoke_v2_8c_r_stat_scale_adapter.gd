extends SceneTree

const BattleContract := preload(
	"res://scripts/data/formation_defense_battle_contract.gd"
)
const FormalPartySource := preload(
	"res://systems/formation_defense_formal_party_source.gd"
)
const ProfessionCompatibility := preload(
	"res://systems/formation_defense_profession_compatibility.gd"
)
const StatScaleAdapter := preload(
	"res://systems/formation_defense_stat_scale_adapter.gd"
)
const Stage12Config := preload(
	"res://scripts/data/stage12_balance_config.gd"
)
const PreviewRequestBuilder := preload(
	"res://systems/formation_defense_preview_request_builder.gd"
)
const PreviewHostScene := preload(
	"res://features/battle/formation_defense_preview_host.tscn"
)

const FORMAL_SAVE_PATH := "user://adventure_village_save.json"
const STEP := 0.1
const MAX_STEPS := 9000
const PROFESSIONS: Array[StringName] = [
	&"guard", &"ranger", &"mage", &"healer",
]
const FORMAL_CHARACTER_BY_PROFESSION := {
	&"guard": &"guard",
	&"ranger": &"hunter",
	&"mage": &"mage",
	&"healer": &"doctor",
}

var failures: Array[String] = []
var check_count := 0


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var game_state := root.get_node_or_null("/root/GameState")
	check(game_state != null, "formal GameState is available")
	if game_state == null:
		finish()
		return
	check_scale_formula()
	check_dynamic_party_mapping()
	var formal_before := snapshot_formal_sources(game_state)
	var save_before := snapshot_file(FORMAL_SAVE_PATH)
	var party_creation := FormalPartySource.build_party_snapshots(game_state)
	check(bool(party_creation.get("ok", false)), "current formal party creates scaled snapshots")
	check_current_formal_party(party_creation.get("value", []))

	var unattended_first := await run_formal_battle(game_state, false, "unattended-1")
	var unattended_second := await run_formal_battle(game_state, false, "unattended-2")
	var commanded_first := await run_formal_battle(game_state, true, "commanded-1")
	var commanded_second := await run_formal_battle(game_state, true, "commanded-2")
	print_run("unattended-1", unattended_first)
	print_run("unattended-2", unattended_second)
	print_run("commanded-1", commanded_first)
	print_run("commanded-2", commanded_second)
	check(comparable_run(unattended_first) == comparable_run(unattended_second), "unattended formal run repeats exactly")
	check(comparable_run(commanded_first) == comparable_run(commanded_second), "fixed-input formal run repeats exactly")
	check(String(unattended_first.outcome) == BattleContract.OUTCOME_DEFEAT, "scaled default formal party is defeated without input")
	check(int(unattended_first.generated) == 60, "unattended scaled run generates all sixty enemies")
	check(int(commanded_first.generated) == 60, "commanded scaled run generates all sixty enemies")
	check(int(commanded_first.command_clicks) > 0, "fixed operation uses real focus clicks")
	check(int(commanded_first.ultimate_releases) > 0, "fixed operation uses real ultimate input")
	check(operation_has_benefit(unattended_first, commanded_first), "fixed operation clearly improves the scaled battle result")
	check(run_has_complete_party_results(unattended_first), "unattended result has one fact row per formal stable ID")
	check(run_has_complete_party_results(commanded_first), "commanded result has one fact row per formal stable ID")
	check(snapshot_formal_sources(game_state) == formal_before, "all real runs leave CharacterRoster and GameState unchanged")
	check(snapshot_file(FORMAL_SAVE_PATH) == save_before, "all real runs leave the formal save unchanged")
	await check_terminal_zero_writes(game_state, formal_before, save_before)
	check(smoke_uses_only_formal_input(), "fixed operation uses only formal input paths")
	finish()


func check_scale_formula() -> void:
	var expected_ranges := [82.0, 500.0, 450.0, 330.0]
	for index: int in range(PROFESSIONS.size()):
		var profession_id := PROFESSIONS[index]
		var compatibility := ProfessionCompatibility.get_compatibility(profession_id)
		var role_id := StringName(compatibility.get("v2_role_id", &""))
		var reference := StatScaleAdapter.get_formal_reference(profession_id)
		var baseline := StatScaleAdapter.get_v2_baseline(role_id)
		var formal_stats := make_final_stats(reference)
		var source_before := formal_stats.duplicate(true)
		var creation := StatScaleAdapter.adapt_final_stats(
			StringName("reference_%s" % String(profession_id)),
			profession_id,
			role_id,
			formal_stats,
			expected_ranges[index]
		)
		check(bool(creation.get("ok", false)), "%s reference stats scale successfully" % profession_id)
		var value: Dictionary = creation.get("value", {})
		var runtime: Dictionary = value.get("report", {}).get("v2_runtime_stats", {})
		check(int(runtime.get("max_health", 0)) == roundi(float(baseline.max_health)), "%s reference HP returns to frozen V2 HP" % profession_id)
		check(int(runtime.get("attack_or_heal", 0)) == roundi(float(baseline.attack_or_heal)), "%s reference effect returns to frozen V2 attack/heal" % profession_id)
		check(is_equal_approx(float(runtime.get("action_interval", 0.0)), float(baseline.action_interval)), "%s reference speed returns to frozen V2 interval" % profession_id)
		check(is_equal_approx(float(runtime.get("action_range", 0.0)), expected_ranges[index]), "%s keeps its frozen V2 action range" % profession_id)
		check(formal_stats == source_before, "%s scaling does not mutate input" % profession_id)
		var repeat := StatScaleAdapter.adapt_final_stats(
			StringName("reference_%s" % String(profession_id)), profession_id,
			role_id, formal_stats, expected_ranges[index]
		)
		check(creation == repeat, "%s scaling is deterministic" % profession_id)
		var enhanced_stats := formal_stats.duplicate(true)
		enhanced_stats.max_hp = float(reference.max_hp) * 1.2
		enhanced_stats.attack = float(reference.attack) * 1.2
		enhanced_stats.attack_speed = float(reference.attack_speed) * 1.2
		var enhanced_creation: Dictionary = StatScaleAdapter.adapt_final_stats(
			&"enhanced", profession_id, role_id, enhanced_stats,
			expected_ranges[index]
		)
		var enhanced: Dictionary = enhanced_creation.value.report.v2_runtime_stats
		check(int(enhanced.max_health) == roundi(float(baseline.max_health) * 1.2), "%s +20%% formal HP gives +20%% V2 HP" % profession_id)
		check(int(enhanced.attack_or_heal) == roundi(float(baseline.attack_or_heal) * 1.2), "%s +20%% formal attack gives +20%% V2 effect" % profession_id)
		var enhanced_frequency := StatScaleAdapter.map_action_frequency(
			float(enhanced_stats.attack_speed),
			float(reference.attack_speed),
			float(baseline.action_interval)
		)
		check(is_equal_approx(
			float(enhanced.action_interval),
			float(enhanced_frequency.value.final_action_interval)
		), "%s +20%% formal speed uses the hardened frequency curve" % profession_id)
		var high_stats := formal_stats.duplicate(true)
		high_stats.max_hp = float(reference.max_hp) * 5.0
		high_stats.attack = float(reference.attack) * 5.0
		high_stats.attack_speed = float(reference.attack_speed) * 5.0
		var high := StatScaleAdapter.adapt_final_stats(
			&"high_level", profession_id, role_id, high_stats,
			expected_ranges[index]
		)
		check(bool(high.get("ok", false)), "%s high growth sample stays finite under diminishing returns" % profession_id)
		var formal_character_id: StringName = FORMAL_CHARACTER_BY_PROFESSION[profession_id]
		var level_growth: Dictionary = Stage12Config.COMBAT_LEVEL_GROWTH_BY_CHARACTER[formal_character_id]
		var level_span := float(Stage12Config.COMBAT_MAX_LEVEL - 1)
		var max_level_stats := formal_stats.duplicate(true)
		max_level_stats.max_hp = float(reference.max_hp) \
			+ float(level_growth.get("max_hp", 0)) * level_span
		max_level_stats.attack = float(reference.attack) \
			+ float(level_growth.get("attack", 0)) * level_span
		max_level_stats.attack_speed = float(reference.attack_speed) \
			+ float(level_growth.get("speed", 0)) * level_span
		var max_level := StatScaleAdapter.adapt_final_stats(
			&"formal_max_level", profession_id, role_id, max_level_stats,
			expected_ranges[index]
		)
		check(bool(max_level.get("ok", false)), "%s formal level-50 base growth sample stays finite" % profession_id)
		if bool(max_level.get("ok", false)):
			var max_level_runtime: Dictionary = max_level.value.report.v2_runtime_stats
			var max_frequency := StatScaleAdapter.map_action_frequency(
				float(max_level_stats.attack_speed),
				float(reference.attack_speed),
				float(baseline.action_interval)
			)
			check(is_equal_approx(
				float(max_level_runtime.action_interval),
				float(max_frequency.value.final_action_interval)
			), "%s formal level-50 speed uses the hardened frequency curve" % profession_id)
		if profession_id == &"ranger":
			check(not is_equal_approx(float(runtime.action_interval), 1.0 / float(reference.attack_speed)), "raw formal attack_speed reciprocal is not used as the V2 interval")
		if profession_id == &"healer":
			var ready: Dictionary = value.get("final_stats", {})
			check(int(ready.get("attack", 0)) == int(baseline.attack_or_heal), "healer formal attack scales the V2 healing basis")

	var invalid_cases := [
		[&"unsupported", &"guard", make_final_stats(StatScaleAdapter.get_formal_reference(&"guard"))],
		[&"guard", &"guard", make_invalid_stats("max_hp", 0.0)],
		[&"guard", &"guard", make_invalid_stats("attack_speed", 0.0)],
		[&"guard", &"guard", make_invalid_stats("attack_speed", NAN)],
		[&"guard", &"guard", make_invalid_stats("max_hp", INF)],
	]
	for invalid: Array in invalid_cases:
		var result := StatScaleAdapter.adapt_final_stats(
			&"invalid", invalid[0], invalid[1], invalid[2], 82.0
		)
		check(not bool(result.get("ok", false)), "invalid or unsupported scale input is rejected")


func check_dynamic_party_mapping() -> void:
	for party_size: int in range(1, 5):
		var creation := FormalPartySource.build_party_snapshots_from_records(
			make_reference_records(party_size)
		)
		check(bool(creation.get("ok", false)), "%d-person scaled party is valid" % party_size)
		var party: Array = creation.get("value", [])
		check(party.size() == party_size, "%d-person scaled party is not padded" % party_size)
		var runtime := ProfessionCompatibility.build_runtime_party(party)
		check(bool(runtime.get("ok", false)) and runtime.get("value", []).size() == party_size, "%d-person scaled party creates exactly its requested runtime members" % party_size)
		for index: int in range(party.size()):
			check(String(party[index].character_id) == "scaled_%d" % (index + 1), "%d-person scaled party preserves stable IDs and slots" % party_size)


func check_current_formal_party(party: Array) -> void:
	check(party.size() == 4, "current default formal party contains four members")
	for member: Dictionary in party:
		var report: Dictionary = member.get("stat_scale_report", {})
		var ratios: Dictionary = report.get("ratios", {})
		var runtime: Dictionary = report.get("v2_runtime_stats", {})
		check(not report.is_empty(), "current formal member exposes a scale report")
		check(is_equal_approx(float(ratios.get("max_hp", 0.0)), 1.0), "current default formal HP equals its profession reference")
		check(is_equal_approx(float(ratios.get("attack", 0.0)), 1.0), "current default formal attack equals its profession reference")
		check(is_equal_approx(float(ratios.get("attack_speed", 0.0)), 1.0), "current default formal speed equals its profession reference")
		check(int(member.final_stats.max_hp) == int(runtime.max_health), "V2-ready contract HP matches the scale report")
		check(is_equal_approx(
			1.0 / float(member.final_stats.attack_speed),
			float(runtime.action_interval)
		), "V2-ready contract rate matches the scale report interval")


func run_formal_battle(
	game_state: Node,
	commanded: bool,
	session_id: String
) -> Dictionary:
	var party_creation := FormalPartySource.build_party_snapshots(game_state)
	var request_creation := PreviewRequestBuilder.build_preview_request(session_id, {
		"encounter_id": &"development:formation_defense_preview",
		"encounter_node_id": "",
		"source_mode": &"MAIN_DEVELOPMENT_PREVIEW",
		"party_snapshots": party_creation.get("value", []).duplicate(true),
	})
	var request: Dictionary = request_creation.get("value", {})
	var host = PreviewHostScene.instantiate()
	root.add_child(host)
	await process_frame
	var results: Array[Dictionary] = []
	host.preview_finished.connect(func(result: Dictionary) -> void:
		results.append(result.duplicate(true))
	)
	var started: Dictionary = host.start_preview(request)
	var controller = host.get_active_prototype()
	var command_clicks := 0
	var last_command_time := -10.0
	var steps := 0
	while results.is_empty() and steps < MAX_STEPS:
		host.advance_for_test(STEP)
		if commanded and is_instance_valid(controller):
			if float(controller.battle_elapsed) - last_command_time >= 3.0:
				var focus_target = choose_focus_target(controller)
				if is_instance_valid(focus_target) and controller.handle_battlefield_pointer(
					focus_target.position, MOUSE_BUTTON_LEFT
				):
					command_clicks += 1
					last_command_time = float(controller.battle_elapsed)
			issue_ready_ultimates(controller)
		steps += 1
	var result: Dictionary = results[0] if not results.is_empty() else {}
	var snapshot: Dictionary = host.get_last_terminal_debug_snapshot()
	var summary := summarize_run(
		bool(started.get("ok", false)), request, result, snapshot,
		command_clicks, steps
	)
	host.queue_free()
	await process_frame
	return summary


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
	if enemy.monster_type == &"rush_raider" and enemy.rush_state == &"PREPARING_RUSH":
		return 0
	if enemy.monster_type == &"rush_raider" and enemy.rush_state == &"RUSHING":
		return 1
	if int(enemy.formation_level) == 2:
		return 2
	if enemy.monster_type == &"formation_guard" and int(enemy.formation_level) == 1:
		return 3
	if enemy.monster_type == &"charge" and int(enemy.formation_level) == 1:
		return 4
	if enemy.monster_type == &"rush_raider":
		return 5
	if enemy.monster_type == &"formation_guard":
		return 6
	return 7


func issue_ready_ultimates(controller) -> void:
	for character in controller.character_nodes.values():
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
		if controller.begin_ultimate_targeting(character.character_id):
			var screen_position: Vector2 = controller.logic_to_screen_position(target.position)
			controller.update_ultimate_targeting_from_screen(screen_position)
			controller.release_ultimate_targeting_from_screen(screen_position)


func choose_ultimate_target(controller, character) -> Dictionary:
	if character.role_id == &"doctor":
		var best_character = null
		var best_missing := 0
		for candidate in controller.character_nodes.values():
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
		if count > best_count or (
			count == best_count
			and String(candidate.runtime_id) < String(best_enemy.runtime_id)
		):
			best_enemy = candidate
			best_count = count
	return {"valid": true, "position": best_enemy.position}


func summarize_run(
	started: bool,
	request: Dictionary,
	result: Dictionary,
	snapshot: Dictionary,
	command_clicks: int,
	steps: int
) -> Dictionary:
	var stats: Dictionary = result.get("battle_statistics", {})
	var durability: Dictionary = result.get("village_durability", {})
	var formation: Dictionary = snapshot.get("formation_stats", {})
	return {
		"started": started,
		"outcome": String(result.get("outcome", "TIMEOUT")),
		"duration": snappedf(float(result.get("duration_seconds", steps * STEP)), 0.1),
		"generated": int(stats.get("generated_enemies", 0)),
		"killed": int(stats.get("defeated_enemies", 0)),
		"leaked": int(stats.get("leaked_enemies", 0)),
		"durability": int(durability.get("remaining", -1)),
		"command_clicks": command_clicks,
		"ultimate_releases": int(snapshot.get("ultimate_release_sequence", 0)),
		"completed_a": int(formation.get("completed_a_count", 0)),
		"completed_b": int(formation.get("completed_b_count", 0)),
		"party_results": sorted_party_results(result.get("party_results", [])),
		"request_ids": sorted_request_ids(request),
		"character_runtime": summarize_character_runtime(snapshot.get("characters", [])),
		"archetypes": sanitize_archetypes(snapshot.get("archetype_stats_by_profile", {})),
	}


func sorted_party_results(raw: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in raw:
		result.append(entry.duplicate(true))
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left.character_id) < String(right.character_id)
	)
	return result


func sorted_request_ids(request: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for member: Dictionary in request.get("party", []):
		ids.append(String(member.character_id))
	ids.sort()
	return ids


func summarize_character_runtime(raw: Array) -> Dictionary:
	var result: Dictionary = {}
	for character: Dictionary in raw:
		result[String(character.character_id)] = {
			"max_health": int(character.get("max_health", 0)),
			"action_interval": snappedf(float(character.get("action_interval", 0.0)), 0.000001),
			"attack_damage": int(character.get("attack_damage", 0)),
			"heal_amount": int(character.get("heal_amount", 0)),
			"damage_or_healing": int(character.get("total_effect_amount", 0)),
			"ultimate_releases": int(character.get("ultimate_release_count", 0)),
			"down": bool(character.get("is_incapacitated", false)),
			"remaining_health": int(character.get("current_health", 0)),
		}
	return result


func sanitize_archetypes(raw: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for profile_id: StringName in [&"formation_guard", &"charge", &"rush_raider"]:
		var stats: Dictionary = raw.get(profile_id, {})
		result[String(profile_id)] = {
			"generated": int(stats.get("generated", 0)),
			"killed": int(stats.get("killed", 0)),
			"leaked": int(stats.get("leaked", 0)),
			"entered_a_alive": int(stats.get("entered_a_alive", 0)),
			"rush_prepare_count": int(stats.get("rush_prepare_count", 0)),
			"rush_started_count": int(stats.get("rush_started_count", 0)),
		}
	return result


func comparable_run(run_result: Dictionary) -> Dictionary:
	var result := run_result.duplicate(true)
	return result


func operation_has_benefit(unattended: Dictionary, commanded: Dictionary) -> bool:
	return (
		String(commanded.outcome) == BattleContract.OUTCOME_VICTORY
			and String(unattended.outcome) != BattleContract.OUTCOME_VICTORY
		or int(commanded.leaked) < int(unattended.leaked)
		or int(commanded.durability) > int(unattended.durability)
		or float(commanded.duration) < float(unattended.duration) - 0.05
	)


func run_has_complete_party_results(run_result: Dictionary) -> bool:
	var result_ids: Array[String] = []
	for entry: Dictionary in run_result.get("party_results", []):
		result_ids.append(String(entry.character_id))
	result_ids.sort()
	return result_ids == run_result.get("request_ids", [])


func check_terminal_zero_writes(
	game_state: Node,
	formal_before: Dictionary,
	save_before: Dictionary
) -> void:
	for terminal: StringName in [&"victory", &"defeat", &"abort"]:
		var party: Array = FormalPartySource.build_party_snapshots(game_state).get("value", [])
		var request: Dictionary = PreviewRequestBuilder.build_preview_request(
			"scale-zero-%s" % terminal,
			{
				"encounter_id": &"development:formation_defense_preview",
				"source_mode": &"MAIN_DEVELOPMENT_PREVIEW",
				"party_snapshots": party,
			}
		).get("value", {})
		var host = PreviewHostScene.instantiate()
		root.add_child(host)
		await process_frame
		var results: Array[Dictionary] = []
		host.preview_finished.connect(func(result: Dictionary) -> void:
			results.append(result.duplicate(true))
		)
		host.start_preview(request)
		match terminal:
			&"victory":
				host.force_victory_for_test()
			&"defeat":
				host.force_defeat_for_test()
			_:
				host.abort_preview()
		check(results.size() == 1, "%s scaled terminal emits one result" % terminal)
		check(snapshot_formal_sources(game_state) == formal_before, "%s scaled terminal writes no formal data" % terminal)
		check(snapshot_file(FORMAL_SAVE_PATH) == save_before, "%s scaled terminal writes no save data" % terminal)
		host.queue_free()
		await process_frame


func make_reference_records(count: int) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for index: int in range(count):
		var profession_id := PROFESSIONS[index]
		records.append({
			"character_id": StringName("scaled_%d" % (index + 1)),
			"character_type": 0,
			"display_name": "尺度角色%d" % (index + 1),
			"profession_id": profession_id,
			"role_display_name": String(profession_id),
			"party_slot": index,
			"is_in_party": true,
			"final_stats": make_final_stats(
				StatScaleAdapter.get_formal_reference(profession_id)
			),
			"equipped_skill_ids": [],
			"battle_visual_id": StringName("scaled_visual_%d" % (index + 1)),
			"injury_state": &"healthy",
		})
	return records


func make_final_stats(reference: Dictionary) -> Dictionary:
	return {
		"max_hp": reference.get("max_hp", 0.0),
		"attack": reference.get("attack", 0.0),
		"defense": 2,
		"speed": roundi(float(reference.get("attack_speed", 0.0))),
		"attack_speed": reference.get("attack_speed", 0.0),
		"crit_rate": 0.05,
		"crit_damage": 1.5,
	}


func make_invalid_stats(stat_id: String, value: float) -> Dictionary:
	var result := make_final_stats(
		StatScaleAdapter.get_formal_reference(&"guard")
	)
	result[stat_id] = value
	return result


func snapshot_formal_sources(game_state: Node) -> Dictionary:
	return {
		"roster": game_state.character_roster.to_dictionary(),
		"resources": game_state.resources.duplicate(true),
		"statistics": game_state.statistics.duplicate(true),
		"expedition_state": game_state.expedition_state.duplicate(true),
		"battle_state": game_state.battle_state.duplicate(true),
		"pending_battle_result": game_state.pending_battle_result.duplicate(true),
		"last_battle_result": game_state.last_battle_result.duplicate(true),
		"save_last_error": String(game_state.save_system.last_error),
	}


func snapshot_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"exists": false, "bytes": PackedByteArray()}
	var file := FileAccess.open(path, FileAccess.READ)
	return {
		"exists": true,
		"bytes": file.get_buffer(file.get_length()) if file != null else PackedByteArray(),
	}


func smoke_uses_only_formal_input() -> bool:
	var source := FileAccess.get_file_as_string(
		"res://tools/smoke_v2_8c_r_stat_scale_adapter.gd"
	)
	for forbidden: String in [
		".current_health" + " =",
		".ultimate_energy" + " =",
		".route_progress" + " =",
		".traveled_distance" + " =",
		".take_" + "damage(",
	]:
		if source.contains(forbidden):
			return false
	return source.contains("handle_battlefield_pointer") \
		and source.contains("begin_ultimate_targeting") \
		and source.contains("release_ultimate_targeting_from_screen")


func print_run(label: String, result: Dictionary) -> void:
	print("v2-8c-r %s: outcome=%s time=%.1f generated=%d killed=%d leaked=%d durability=%d A=%d B=%d commands=%d ultimates=%d party=%s archetypes=%s" % [
		label, result.outcome, result.duration, result.generated, result.killed,
		result.leaked, result.durability, result.completed_a, result.completed_b,
		result.command_clicks, result.ultimate_releases,
		JSON.stringify(result.character_runtime),
		JSON.stringify(result.archetypes),
	])


func check(condition: bool, message: String) -> void:
	check_count += 1
	if not condition:
		failures.append(message)


func finish() -> void:
	if failures.is_empty():
		print("v2-8c-r formal stat scale smoke ok (%d checks)" % check_count)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

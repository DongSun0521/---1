extends SceneTree

const StatScaleAdapter := preload(
	"res://systems/formation_defense_stat_scale_adapter.gd"
)
const FormalPartySource := preload(
	"res://systems/formation_defense_formal_party_source.gd"
)
const ProfessionCompatibility := preload(
	"res://systems/formation_defense_profession_compatibility.gd"
)
const PreviewRequestBuilder := preload(
	"res://systems/formation_defense_preview_request_builder.gd"
)
const PreviewHostScene := preload(
	"res://features/battle/formation_defense_preview_host.tscn"
)
const Stage12Config := preload(
	"res://scripts/data/stage12_balance_config.gd"
)
const EquipmentStatBonuses := preload(
	"res://scripts/data/equipment_stat_bonuses.gd"
)
const CharacterScript := preload(
	"res://prototype/formation_defense/scripts/formation_defense_character.gd"
)
const Coordinator := preload(
	"res://features/main/formation_defense_preview_coordinator.gd"
)
const IntegrationPolicy := preload(
	"res://systems/formation_defense_integration_policy.gd"
)

const PROFESSIONS: Array[StringName] = [
	&"guard", &"ranger", &"mage", &"healer",
]
const CHARACTER_BY_PROFESSION := {
	&"guard": &"guard",
	&"ranger": &"hunter",
	&"mage": &"mage",
	&"healer": &"doctor",
}
const EXPECTED_BASELINE_INTERVAL := {
	&"guard": 0.8,
	&"ranger": 0.65,
	&"mage": 1.1,
	&"healer": 0.75,
}
const STEP := 0.1
const MAX_STEPS := 4000
const FORMAL_SAVE_PATH := "user://adventure_village_save.json"

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
	check_v1_and_formal_source_semantics(game_state)
	check_reference_and_curve_contract()
	check_formal_growth_boundaries(game_state)
	check_dynamic_max_level_parties()
	check_invalid_inputs()
	await check_doctor_actual_frequency()
	await check_debug_level_validation_entry(game_state)
	var formal_before := snapshot_formal_sources(game_state)
	var save_before := snapshot_file(FORMAL_SAVE_PATH)
	var first := await run_max_level_pressure("v2-8g-pressure-1")
	var second := await run_max_level_pressure("v2-8g-pressure-2")
	print("v2-8g pressure-1: %s" % JSON.stringify(first))
	print("v2-8g pressure-2: %s" % JSON.stringify(second))
	check(first == second, "fixed max-level pressure run repeats exactly")
	check(bool(first.get("started", false)), "max-level pressure host starts")
	check(String(first.get("outcome", "")) in ["VICTORY", "DEFEAT"], "max-level pressure run reaches one terminal outcome")
	check(int(first.get("terminal_count", 0)) == 1, "max-level pressure run emits one terminal result")
	check(int(first.get("generated", 0)) == 60, "max-level pressure run schedules all enemies")
	check(int(first.get("peak_projectiles", 999)) <= 32, "high frequency does not create an unbounded projectile population")
	check(int(first.get("remaining_projectiles", -1)) == 0, "terminal cleanup removes all projectile visuals")
	check(bool(first.get("action_counts_safe", false)), "actual action counts remain bounded by the 0.20 second safety interval")
	check(bool(first.get("runtime_intervals_match", false)), "actual runtime intervals match the hardened adapter")
	check(bool(first.get("stable_ids_and_slots", false)), "max-level party keeps stable IDs and formal slots")
	check(snapshot_formal_sources(game_state) == formal_before, "pressure runs do not mutate CharacterRoster or formal state")
	check(snapshot_file(FORMAL_SAVE_PATH) == save_before, "pressure runs do not write the formal save")
	finish()


func check_v1_and_formal_source_semantics(game_state: Node) -> void:
	var battle_source := FileAccess.get_file_as_string("res://systems/battle_system.gd")
	check(not battle_source.contains("attack_speed"), "V1 BattleSystem does not consume attack_speed")
	check(battle_source.contains('"speed": int(unit["speed"])'), "V1 turn entries use speed for ordering")
	var equipment: Dictionary = EquipmentStatBonuses.new().setup(
		1, 2, 3, 4
	).to_dictionary()
	check(not equipment.has("attack_speed"), "formal equipment bonuses do not expose attack_speed")
	check(not equipment.has("crit_rate"), "equipment stat container remains the existing four-stat contract")
	for character_id: StringName in CHARACTER_BY_PROFESSION.values():
		var record = game_state.character_roster.get_character(character_id)
		check(record != null, "%s formal roster record exists" % character_id)
		if record == null:
			continue
		var details: Dictionary = record.combat_data.calculate_final_stat_details(
			Stage12Config.COMBAT_MAX_LEVEL,
			game_state.get_character_equipment_bonuses(character_id),
			{},
			{
				"attack": game_state.party_attack_bonus + game_state.get_expedition_meal_attack_bonus(),
				"max_hp": game_state.party_max_hp_bonus,
			},
			{"max_hp": game_state.get_expedition_meal_max_hp_bonus()}
		)
		var speed_detail: Dictionary = details.get("attack_speed", {})
		check(is_equal_approx(float(speed_detail.get("equipment_bonus", -1.0)), 0.0), "%s equipment does not alter formal attack_speed" % character_id)
		check(is_equal_approx(float(speed_detail.get("village_bonus", -1.0)), 0.0), "%s village bonuses do not alter formal attack_speed" % character_id)
		check(is_equal_approx(float(speed_detail.get("trait_bonus", -1.0)), 0.0), "%s traits do not alter formal attack_speed" % character_id)
		check(is_equal_approx(float(speed_detail.get("temporary_bonus", -1.0)), 0.0), "%s meals do not alter formal attack_speed" % character_id)
		check(is_equal_approx(float(speed_detail.get("injury_multiplier", 0.0)), 1.0), "%s injury does not alter formal attack_speed" % character_id)


func check_reference_and_curve_contract() -> void:
	for profession_id: StringName in PROFESSIONS:
		var reference := StatScaleAdapter.get_formal_reference(profession_id)
		var role_id := ProfessionCompatibility.get_v2_role_id(profession_id)
		var baseline := StatScaleAdapter.get_v2_baseline(role_id)
		var baseline_interval := float(baseline.get("action_interval", 0.0))
		check(is_equal_approx(baseline_interval, float(EXPECTED_BASELINE_INTERVAL[profession_id])), "%s frozen V2 baseline interval is unchanged" % profession_id)
		var reference_mapping := StatScaleAdapter.map_action_frequency(
			float(reference.attack_speed), float(reference.attack_speed), baseline_interval
		)
		check(bool(reference_mapping.get("ok", false)), "%s reference frequency maps successfully" % profession_id)
		var reference_value: Dictionary = reference_mapping.get("value", {})
		check(is_equal_approx(float(reference_value.raw_ratio), 1.0), "%s reference raw ratio is exactly one" % profession_id)
		check(is_equal_approx(float(reference_value.curved_frequency_multiplier), 1.0), "%s reference curved multiplier is exactly one" % profession_id)
		check(is_equal_approx(float(reference_value.final_action_interval), baseline_interval), "%s reference action interval is exactly unchanged" % profession_id)
		check(not bool(reference_value.safety_floor_applied), "%s reference does not trigger the safety floor" % profession_id)

		var previous_interval := INF
		for ratio: float in [0.25, 0.5, 0.9, 0.99, 1.0, 1.01, 1.1, 1.5, 2.0, 4.0, 8.0, 20.0]:
			var mapping := StatScaleAdapter.map_action_frequency(
				float(reference.attack_speed) * ratio,
				float(reference.attack_speed),
				baseline_interval
			)
			check(bool(mapping.get("ok", false)), "%s ratio %.2f maps successfully" % [profession_id, ratio])
			var interval := float(mapping.value.final_action_interval)
			check(interval <= previous_interval + 0.000001, "%s interval is monotonic at ratio %.2f" % [profession_id, ratio])
			check(interval >= StatScaleAdapter.ACTION_INTERVAL_SAFETY_FLOOR_SECONDS, "%s ratio %.2f respects the absolute interval floor" % [profession_id, ratio])
			previous_interval = interval

		var below: Dictionary = StatScaleAdapter.map_action_frequency(
			float(reference.attack_speed) * 0.999999,
			float(reference.attack_speed), baseline_interval
		).value
		var above: Dictionary = StatScaleAdapter.map_action_frequency(
			float(reference.attack_speed) * 1.000001,
			float(reference.attack_speed), baseline_interval
		).value
		check(absf(float(below.final_action_interval) - float(above.final_action_interval)) < 0.00001, "%s curve is continuous around the reference point" % profession_id)
		var at_two: Dictionary = StatScaleAdapter.map_action_frequency(
			float(reference.attack_speed) * 2.0,
			float(reference.attack_speed), baseline_interval
		).value
		var at_four: Dictionary = StatScaleAdapter.map_action_frequency(
			float(reference.attack_speed) * 4.0,
			float(reference.attack_speed), baseline_interval
		).value
		check(float(at_four.curved_frequency_multiplier) - float(at_two.curved_frequency_multiplier) < float(at_two.curved_frequency_multiplier) - 1.0, "%s high-ratio frequency gains diminish" % profession_id)
		check(float(at_four.curved_frequency_multiplier) < 4.0, "%s high-ratio curve is slower than the old linear multiplier" % profession_id)

	var floor_mapping := StatScaleAdapter.map_action_frequency(1000000.0, 1.0, 0.5)
	check(bool(floor_mapping.get("ok", false)), "extreme finite input remains safe")
	check(bool(floor_mapping.value.safety_floor_applied), "absolute interval floor can activate as a runtime safety net")
	check(is_equal_approx(float(floor_mapping.value.final_action_interval), 0.20), "absolute interval floor is exactly 0.20 seconds")


func check_formal_growth_boundaries(game_state: Node) -> void:
	for profession_id: StringName in PROFESSIONS:
		var character_id: StringName = CHARACTER_BY_PROFESSION[profession_id]
		var reference := StatScaleAdapter.get_formal_reference(profession_id)
		var role_id := ProfessionCompatibility.get_v2_role_id(profession_id)
		var baseline := StatScaleAdapter.get_v2_baseline(role_id)
		var growth: Dictionary = Stage12Config.COMBAT_LEVEL_GROWTH_BY_CHARACTER[character_id]
		var level_one_speed := float(reference.attack_speed)
		var level_fifty_speed := level_one_speed + float(growth.get("speed", 0)) * 49.0
		var level_one: Dictionary = StatScaleAdapter.map_action_frequency(
			level_one_speed, level_one_speed, float(baseline.action_interval)
		).value
		var level_fifty: Dictionary = StatScaleAdapter.map_action_frequency(
			level_fifty_speed, level_one_speed, float(baseline.action_interval)
		).value
		check(is_equal_approx(float(level_one.final_action_interval), float(baseline.action_interval)), "%s Lv.1 keeps the frozen baseline" % profession_id)
		check(float(level_fifty.final_action_interval) >= 0.20, "%s Lv.50 legal maximum stays above the global safety floor" % profession_id)
		if profession_id in [&"ranger", &"healer"]:
			check(float(level_fifty.final_action_interval) >= 0.25, "%s Lv.50 base growth stays at or above 0.25 seconds" % profession_id)
		var record = game_state.character_roster.get_character(character_id)
		var legal_details: Dictionary = record.combat_data.calculate_final_stat_details(
			Stage12Config.COMBAT_MAX_LEVEL,
			game_state.get_character_equipment_bonuses(character_id), {},
			{"attack": game_state.party_attack_bonus, "max_hp": game_state.party_max_hp_bonus},
			{"max_hp": game_state.get_expedition_meal_max_hp_bonus()}
		)
		check(is_equal_approx(float(legal_details.attack_speed.final), level_fifty_speed), "%s highest current legal modifier combination does not exceed level growth speed" % profession_id)


func check_invalid_inputs() -> void:
	for values: Array in [
		[0.0, 1.0, 1.0], [-1.0, 1.0, 1.0], [NAN, 1.0, 1.0],
		[INF, 1.0, 1.0], [1.0, 0.0, 1.0], [1.0, NAN, 1.0],
		[1.0, 1.0, 0.0], [1.0, 1.0, INF],
	]:
		var mapping := StatScaleAdapter.map_action_frequency(values[0], values[1], values[2])
		check(not bool(mapping.get("ok", false)), "invalid or non-finite frequency input is rejected")
	var missing_stats := make_level_final_stats(&"guard", 1)
	missing_stats.erase("attack_speed")
	var rejected := StatScaleAdapter.adapt_final_stats(
		&"missing_speed", &"guard", &"guard", missing_stats, 82.0
	)
	check(not bool(rejected.get("ok", false)), "missing formal attack_speed is rejected")


func check_dynamic_max_level_parties() -> void:
	var all_records := make_level_records(Stage12Config.COMBAT_MAX_LEVEL)
	for party_size: int in range(1, 5):
		var records: Array[Dictionary] = []
		for index: int in range(party_size):
			records.append(all_records[index].duplicate(true))
		var snapshots := FormalPartySource.build_party_snapshots_from_records(records)
		check(bool(snapshots.get("ok", false)), "%d-person max-level formal snapshot is valid" % party_size)
		var runtime := ProfessionCompatibility.build_runtime_party(
			snapshots.get("value", [])
		)
		var definitions: Array = runtime.get("value", [])
		check(bool(runtime.get("ok", false)), "%d-person max-level runtime party is valid" % party_size)
		check(definitions.size() == party_size, "%d-person max-level runtime creates no padding" % party_size)
		for index: int in range(definitions.size()):
			check(StringName(definitions[index].character_id) == StringName(records[index].character_id), "%d-person party preserves stable ID at slot %d" % [party_size, index])
			check(int(definitions[index].party_slot) == index, "%d-person party preserves formal slot %d" % [party_size, index])


func check_doctor_actual_frequency() -> void:
	var snapshots := FormalPartySource.build_debug_level_party_snapshots()
	var runtime := ProfessionCompatibility.build_runtime_party(
		snapshots.get("value", [])
	)
	var definitions: Array = runtime.get("value", [])
	var guard_definition: Dictionary = definitions[0]
	var doctor_definition: Dictionary = definitions[3]
	var guard = CharacterScript.new()
	var doctor = CharacterScript.new()
	root.add_child(guard)
	root.add_child(doctor)
	guard.configure(&"guard", guard_definition)
	doctor.configure(&"doctor", doctor_definition)
	guard.deploy_to(&"middle_c1", &"middle", Vector2.ZERO)
	doctor.deploy_to(&"middle_c2", &"middle", Vector2(10.0, 0.0))
	guard.take_damage(1000)
	var delta := 1.0 / 120.0
	var step_count := 600
	var heal_actions := 0
	for _step: int in range(step_count):
		var action: Dictionary = doctor.simulate_action(
			delta, [], [guard, doctor]
		)
		if not action.is_empty():
			heal_actions += 1
			guard.take_damage(int(action.get("amount", 0)))
	var cooldown_frames := ceili(float(doctor.action_interval) / delta)
	var expected_actions := 1 + floori(float(step_count - 1) / float(cooldown_frames))
	check(is_equal_approx(float(doctor.action_interval), 0.287735849056604), "Lv.50 doctor runtime uses the hardened 0.288 second interval")
	check(heal_actions == expected_actions, "Lv.50 doctor actual healing count follows the adapted interval")
	check(int(doctor.action_count) == heal_actions, "doctor action counter records each real heal exactly once")
	check(heal_actions <= ceili(5.0 / StatScaleAdapter.ACTION_INTERVAL_SAFETY_FLOOR_SECONDS) + 1, "doctor cannot exceed the global frequency safety bound")
	doctor.queue_free()
	guard.queue_free()
	await process_frame


func run_max_level_pressure(session_id: String) -> Dictionary:
	var party_creation := FormalPartySource.build_debug_level_party_snapshots()
	var party: Array = party_creation.get("value", [])
	var expected_intervals := {}
	for member: Dictionary in party:
		expected_intervals[String(member.character_id)] = float(
			member.stat_scale_report.v2_runtime_stats.action_interval
		)
	var request_creation := PreviewRequestBuilder.build_preview_request(session_id, {
		"encounter_id": &"development:formation_defense_preview",
		"encounter_node_id": "",
		"source_mode": &"MAIN_DEVELOPMENT_PREVIEW",
		"party_snapshots": party,
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
	var peak_projectiles := 0
	var steps := 0
	while results.is_empty() and steps < MAX_STEPS:
		host.advance_for_test(STEP)
		var controller = host.get_active_prototype()
		if is_instance_valid(controller):
			# advance_for_test drives combat time without SceneTree frame time. Advance
			# the visual-only projectiles by the same delta so the pressure sample
			# measures the live population that normal runtime frames would retain.
			for visual in controller.projectile_visual_layer.get_children():
				if is_instance_valid(visual) and not bool(visual.get("completed")):
					visual._process(STEP)
			var live_projectiles := 0
			for visual_snapshot: Dictionary in controller.get_attack_visual_snapshots():
				if not bool(visual_snapshot.get("completed", false)):
					live_projectiles += 1
			peak_projectiles = maxi(
				peak_projectiles,
				live_projectiles
			)
		steps += 1
	var result: Dictionary = results[0] if not results.is_empty() else {}
	var snapshot: Dictionary = host.get_last_terminal_debug_snapshot()
	host.abort_preview()
	var characters: Array = snapshot.get("characters", [])
	var runtime_intervals_match := characters.size() == 4
	var stable_ids_and_slots := characters.size() == 4
	var action_counts_safe := true
	for character: Dictionary in characters:
		var character_id := String(character.get("character_id", ""))
		var interval := float(character.get("action_interval", 0.0))
		runtime_intervals_match = runtime_intervals_match and is_equal_approx(
			interval, float(expected_intervals.get(character_id, -1.0))
		)
		var duration := float(result.get("duration_seconds", steps * STEP))
		var maximum_actions := ceili(duration / StatScaleAdapter.ACTION_INTERVAL_SAFETY_FLOOR_SECONDS) + 2
		action_counts_safe = action_counts_safe and int(character.get("action_count", 0)) <= maximum_actions
		stable_ids_and_slots = stable_ids_and_slots and character_id in [
			"v2_8g_lv50_guard", "v2_8g_lv50_ranger",
			"v2_8g_lv50_mage", "v2_8g_lv50_healer",
		]
	var stats: Dictionary = result.get("battle_statistics", {})
	var summary := {
		"started": bool(started.get("ok", false)),
		"outcome": String(result.get("outcome", "TIMEOUT")),
		"duration": snappedf(float(result.get("duration_seconds", steps * STEP)), 0.1),
		"generated": int(stats.get("generated_enemies", 0)),
		"killed": int(stats.get("defeated_enemies", 0)),
		"leaked": int(stats.get("leaked_enemies", 0)),
		"terminal_count": results.size(),
		"peak_projectiles": peak_projectiles,
		"remaining_projectiles": snapshot.get("attack_visuals", []).size(),
		"action_counts_safe": action_counts_safe,
		"runtime_intervals_match": runtime_intervals_match,
		"stable_ids_and_slots": stable_ids_and_slots,
		"characters": summarize_characters(characters),
	}
	host.queue_free()
	await process_frame
	return summary


func check_debug_level_validation_entry(game_state: Node) -> void:
	var formal_before := snapshot_formal_sources(game_state)
	var save_before := snapshot_file(FORMAL_SAVE_PATH)
	var debug_fixture := create_coordinator_fixture(
		game_state,
		IntegrationPolicy.new({"debug_tools_visible": true})
	)
	var coordinator = debug_fixture.coordinator
	var option: OptionButton = coordinator.battle_route_option
	check(option != null, "Debug policy creates the battle route selector")
	var validation_index := -1
	if option != null:
		for index: int in range(option.item_count):
			if option.get_item_text(index) == Coordinator.DEBUG_HIGH_LEVEL_ENTRY_NAME:
				validation_index = index
				break
	check(validation_index >= 0, "Debug exposes the named V2-8G level-50 validation entry")
	if validation_index >= 0:
		option.select(validation_index)
		coordinator.on_battle_route_selected(validation_index)
		coordinator.on_battle_route_start_pressed()
	check(is_instance_valid(coordinator.v2_preview_host), "V2-8G Debug entry starts the shared Preview Host")
	var request: Dictionary = coordinator._last_preview_request
	check(StringName(request.get("battle_config_ref", {}).get("wave_config_id", &"")) == PreviewRequestBuilder.PREVIEW_WAVE_CONFIG_ID, "V2-8G entry runs the frozen V2 comprehensive battle")
	check(int(request.get("random_seed", -1)) == 2703, "V2-8G entry preserves the frozen battle seed")
	check(StringName(request.get("encounter_context", {}).get("source_mode", &"")) == Coordinator.DEBUG_HIGH_LEVEL_SOURCE_MODE, "V2-8G request has an explicit no-settlement debug source")
	var party: Array = request.get("party", [])
	check(party.size() == 4, "V2-8G entry creates the four-role level-50 party")
	var ids := PackedStringArray()
	for member: Dictionary in party:
		ids.append(String(member.get("character_id", "")))
	var source_creation := FormalPartySource.build_debug_level_party_snapshots()
	check(bool(source_creation.get("ok", false)), "shared formal-data chain rebuilds the validation party")
	var intervals := {}
	for member: Dictionary in source_creation.get("value", []):
		var report: Dictionary = member.get("stat_scale_report", {})
		var frequency: Dictionary = report.get("action_frequency_mapping", {})
		intervals[String(member.get("profession_id", ""))] = float(
			frequency.get("final_action_interval", -1.0)
		)
		check(report.has("formal_final_stats"), "validation member uses the shared formal stat report")
	check(ids == PackedStringArray([
		"v2_8g_lv50_guard", "v2_8g_lv50_ranger",
		"v2_8g_lv50_mage", "v2_8g_lv50_healer",
	]), "validation IDs are stable and detached from CharacterRoster IDs")
	check(is_equal_approx(float(intervals.get("ranger", 0.0)), 0.2543478260869565), "Debug ranger interval is approximately 0.254 seconds")
	check(is_equal_approx(float(intervals.get("healer", 0.0)), 0.2877358490566038), "Debug healer interval is approximately 0.288 seconds")
	check(coordinator.last_v2_party_debug_text.contains("正式 HP") and coordinator.last_v2_party_debug_text.contains("曲线") and coordinator.last_v2_party_debug_text.contains("安全下限"), "Debug diagnostics expose formal speed mapping and safety-floor state")
	check(int(coordinator.settlement_service.get_snapshot().get("session_count", 0)) == 0, "V2-8G preview opens no Settlement Service session")
	if is_instance_valid(coordinator.v2_preview_host):
		var prototype = coordinator.v2_preview_host.get_active_prototype()
		if is_instance_valid(prototype):
			prototype.restart_battle()
			var restart_snapshot: Dictionary = prototype.get_battle_snapshot()
			check(restart_snapshot.get("characters", []).size() == 4, "in-battle restart rebuilds exactly four validation characters")
			check(restart_snapshot.get("attack_visuals", []).is_empty(), "in-battle restart clears projectile visuals")
		check(coordinator.v2_preview_host.abort_preview(), "V2-8G entry aborts through the shared Host")
	await process_frame
	check(coordinator._last_preview_request.is_empty(), "abort releases the V2-8G request")
	check(not coordinator.battle_router.has_active_preview_session(), "abort closes the Router preview session")
	check(int(coordinator.settlement_service.get_snapshot().get("settlement_count", 0)) == 0, "abort consumes no settlement ID")

	for outcome: String in ["victory", "defeat"]:
		option.select(validation_index)
		coordinator.on_battle_route_selected(validation_index)
		coordinator.on_battle_route_start_pressed()
		check(is_instance_valid(coordinator.v2_preview_host), "%s re-entry creates one fresh Host" % outcome)
		if is_instance_valid(coordinator.v2_preview_host):
			var host = coordinator.v2_preview_host
			var ended := bool(host.force_victory_for_test()) \
				if outcome == "victory" else bool(host.force_defeat_for_test())
			check(ended, "%s terminal path completes through the preview Host" % outcome)
		await process_frame
		check(not is_instance_valid(coordinator.v2_preview_host), "%s clears the Host and runtime nodes" % outcome)
		check(not coordinator.battle_router.has_active_preview_session(), "%s leaves no Router session" % outcome)
		check(int(coordinator.settlement_service.get_snapshot().get("settlement_count", 0)) == 0, "%s performs no formal settlement" % outcome)
	check(snapshot_formal_sources(game_state) == formal_before, "abort, victory and defeat leave formal data unchanged")
	check(snapshot_file(FORMAL_SAVE_PATH) == save_before, "abort, victory and defeat leave formal save bytes unchanged")
	debug_fixture.root.queue_free()
	await process_frame

	var release_fixture := create_coordinator_fixture(
		game_state,
		IntegrationPolicy.new({"debug_tools_visible": false})
	)
	check(release_fixture.navigation.get_node_or_null("BattleRouteDebug") == null, "Release policy creates no development route container")
	check(release_fixture.coordinator.battle_route_option == null, "Release policy creates no V2-8G option or placeholder")
	check(not tree_contains_text(release_fixture.root, Coordinator.DEBUG_HIGH_LEVEL_ENTRY_NAME), "Release tree contains no V2-8G validation text")
	release_fixture.root.queue_free()
	await process_frame


func create_coordinator_fixture(game_state: Node, policy) -> Dictionary:
	var fixture_root := Control.new()
	var navigation := HBoxContainer.new()
	var overlay := Control.new()
	fixture_root.add_child(navigation)
	fixture_root.add_child(overlay)
	root.add_child(fixture_root)
	var coordinator = Coordinator.new()
	fixture_root.add_child(coordinator)
	coordinator.setup(game_state, navigation, overlay, policy)
	return {
		"root": fixture_root,
		"navigation": navigation,
		"coordinator": coordinator,
	}


func tree_contains_text(node: Node, text_value: String) -> bool:
	if node is Label and node.text.contains(text_value):
		return true
	if node is Button and node.text.contains(text_value):
		return true
	if node is OptionButton:
		for index: int in range(node.item_count):
			if node.get_item_text(index).contains(text_value):
				return true
	for child: Node in node.get_children():
		if tree_contains_text(child, text_value):
			return true
	return false


func make_level_records(level: int) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for party_slot: int in range(PROFESSIONS.size()):
		var profession_id := PROFESSIONS[party_slot]
		var character_id: StringName = CHARACTER_BY_PROFESSION[profession_id]
		records.append({
			"character_id": character_id,
			"character_type": 0,
			"display_name": String(character_id),
			"profession_id": profession_id,
			"role_display_name": String(profession_id),
			"party_slot": party_slot,
			"is_in_party": true,
			"final_stats": make_level_final_stats(profession_id, level),
			"equipped_skill_ids": [],
			"battle_visual_id": StringName("v2_8g_%s" % character_id),
			"injury_state": &"healthy",
		})
	return records


func make_level_final_stats(profession_id: StringName, level: int) -> Dictionary:
	var character_id: StringName = CHARACTER_BY_PROFESSION[profession_id]
	var reference := StatScaleAdapter.get_formal_reference(profession_id)
	var growth: Dictionary = Stage12Config.COMBAT_LEVEL_GROWTH_BY_CHARACTER[character_id]
	var span := float(maxi(0, level - 1))
	return {
		"max_hp": float(reference.max_hp) + float(growth.get("max_hp", 0)) * span,
		"attack": float(reference.attack) + float(growth.get("attack", 0)) * span,
		"defense": 2.0 + float(growth.get("defense", 0)) * span,
		"speed": float(reference.attack_speed) + float(growth.get("speed", 0)) * span,
		"attack_speed": float(reference.attack_speed) + float(growth.get("speed", 0)) * span,
		"crit_rate": 0.05,
		"crit_damage": 1.5,
	}


func summarize_characters(characters: Array) -> Dictionary:
	var result := {}
	for character: Dictionary in characters:
		result[String(character.character_id)] = {
			"interval": snappedf(float(character.action_interval), 0.000001),
			"actions": int(character.action_count),
			"effect": int(character.total_effect_amount),
			"down": bool(character.is_incapacitated),
		}
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
	}


func snapshot_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"exists": false, "bytes": PackedByteArray()}
	var file := FileAccess.open(path, FileAccess.READ)
	return {
		"exists": true,
		"bytes": file.get_buffer(file.get_length()) if file != null else PackedByteArray(),
	}


func check(condition: bool, message: String) -> void:
	check_count += 1
	if not condition:
		failures.append(message)


func finish() -> void:
	if failures.is_empty():
		print("v2-8g action frequency hardening smoke ok (%d checks)" % check_count)
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)

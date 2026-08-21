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
const PreviewRequestBuilder := preload(
	"res://systems/formation_defense_preview_request_builder.gd"
)
const PreviewHostScene := preload(
	"res://features/battle/formation_defense_preview_host.tscn"
)
const MainScene := preload("res://features/main/main.tscn")
const PrototypeScene := preload(
	"res://prototype/formation_defense/scenes/formation_defense_prototype.tscn"
)

const FORMAL_SAVE_PATH := "user://adventure_village_save.json"
const STEP := 0.1
const MAX_STEPS := 9000
const PROFESSIONS: Array[StringName] = [
	&"guard", &"ranger", &"mage", &"healer",
]

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
	var formal_before := snapshot_formal_sources(game_state)
	var save_before := snapshot_file(FORMAL_SAVE_PATH)

	check_party_construction_and_validation()
	await check_dynamic_party_runtime()
	await check_formal_main_entry(game_state)
	var actual_run := await run_actual_formal_party(game_state)
	check(bool(actual_run.get("started", false)), "formal default party starts through the real Host")
	check(bool(actual_run.get("terminal", false)), "formal default party reaches a terminal result")
	var actual_result: Dictionary = actual_run.get("result", {})
	check(BattleContract.validate_result(actual_result).is_empty(), "formal real run output satisfies the V2 contract")
	check(
		party_result_ids(actual_result) == request_party_ids(actual_run.get("request", {})),
		"formal real run output IDs match the request exactly"
	)
	var repeated_run := await run_actual_formal_party(game_state)
	check(bool(repeated_run.get("terminal", false)), "repeated formal default run reaches a terminal result")
	check(
		comparable_result_facts(repeated_run.get("result", {}))
			== comparable_result_facts(actual_result),
		"same formal snapshot and fixed seed reproduce identical battle facts"
	)
	print("v2-8c formal actual run: outcome=%s time=%.1f generated=%d defeated=%d leaked=%d durability=%d/%d party=%s" % [
		String(actual_result.get("outcome", "")),
		float(actual_result.get("duration_seconds", 0.0)),
		int(actual_result.get("battle_statistics", {}).get("generated_enemies", 0)),
		int(actual_result.get("battle_statistics", {}).get("defeated_enemies", 0)),
		int(actual_result.get("battle_statistics", {}).get("leaked_enemies", 0)),
		int(actual_result.get("village_durability", {}).get("remaining", 0)),
		int(actual_result.get("village_durability", {}).get("maximum", 0)),
		JSON.stringify(actual_run.get("party_runtime", [])),
	])

	await check_terminal_zero_writes(game_state, formal_before, save_before)
	check(snapshot_formal_sources(game_state) == formal_before, "complete V2-8C smoke leaves formal sources unchanged")
	check(snapshot_file(FORMAL_SAVE_PATH) == save_before, "complete V2-8C smoke leaves the save file unchanged")
	check(preview_runtime_boundary_is_pure(), "Router, Host and V2 runtime contain no formal singleton or SaveSystem access")
	finish()


func check_party_construction_and_validation() -> void:
	for party_size: int in range(1, 5):
		var records := make_formal_records(party_size)
		records.reverse()
		var creation := FormalPartySource.build_party_snapshots_from_records(records)
		check(bool(creation.get("ok", false)), "%d-person formal party is accepted" % party_size)
		var party: Array = creation.get("value", [])
		check(party.size() == party_size, "%d-person formal party is not padded" % party_size)
		check(party_slots_are_sorted(party), "%d-person formal party is sorted by formal slot" % party_size)
		check(not party_contains_prototype_id(party), "%d-person formal party contains no prototype IDs" % party_size)
		var request_creation := make_request("party-size-%d" % party_size, party)
		check(bool(request_creation.get("ok", false)), "%d-person request satisfies V2-8A" % party_size)

	var source_records := make_formal_records(2)
	var detached := FormalPartySource.build_party_snapshots_from_records(source_records)
	var detached_party: Array = detached.get("value", [])
	var original_formal_hp := int(detached_party[0].formal_final_stats.max_hp)
	var original_runtime_hp := int(detached_party[0].final_stats.max_hp)
	source_records[0].final_stats.max_hp = original_formal_hp + 999
	source_records[0].equipped_skill_ids.append(&"mutated_skill")
	check(int(detached_party[0].formal_final_stats.max_hp) == original_formal_hp, "party snapshot deep-copies formal final stats")
	check(not detached_party[0].equipped_skill_ids.has("mutated_skill"), "party snapshot deep-copies skill IDs")
	var old_request: Dictionary = make_request("old-snapshot", detached_party).get("value", {})
	var changed_creation := FormalPartySource.build_party_snapshots_from_records(source_records)
	var new_request: Dictionary = make_request("new-snapshot", changed_creation.get("value", [])).get("value", {})
	check(int(old_request.party[0].final_stats.max_hp) == original_runtime_hp, "old request stays detached from later formal changes")
	check(
		int(changed_creation.value[0].formal_final_stats.max_hp) == original_formal_hp + 999
			and int(new_request.party[0].final_stats.max_hp) > original_runtime_hp,
		"new snapshot observes formal changes and the new request reflects the growth ratio"
	)

	var runtime_creation := ProfessionCompatibility.build_runtime_party(
		FormalPartySource.build_party_snapshots_from_records(
			make_formal_records(4)
		).get("value", [])
	)
	check(bool(runtime_creation.get("ok", false)), "all four formal professions have V2 compatibility")
	var runtime_party: Array = runtime_creation.get("value", [])
	var expected_ranges := [82.0, 500.0, 450.0, 330.0]
	for index: int in range(runtime_party.size()):
		check(
			is_equal_approx(float(runtime_party[index].action_range), expected_ranges[index]),
			"profession %s keeps the frozen V2 action range" % PROFESSIONS[index]
		)
		var report: Dictionary = FormalPartySource.build_party_snapshots_from_records(
			make_formal_records(4)
		).value[index].stat_scale_report
		check(is_equal_approx(
			float(runtime_party[index].action_interval),
			float(report.v2_runtime_stats.action_interval)
		), "profession %s consumes one V2-ready scaled interval" % PROFESSIONS[index])
	check(int(runtime_party[3].attack_damage) == 0, "healer does not create an attack")
	check(int(runtime_party[3].heal_amount) == 52, "healer maps the formal attack ratio once onto V2 healing")
	check(int(runtime_party[0].attack_damage) == 30, "damage role maps the formal attack ratio once onto V2 damage")

	var empty := FormalPartySource.build_party_snapshots_from_records([])
	check(not bool(empty.get("ok", false)), "empty formal party is rejected")
	var duplicate := make_formal_records(2)
	duplicate[1].character_id = duplicate[0].character_id
	check(not bool(FormalPartySource.build_party_snapshots_from_records(duplicate).get("ok", false)), "duplicate formal IDs are rejected")
	var empty_id := make_formal_records(1)
	empty_id[0].character_id = &""
	check(not bool(FormalPartySource.build_party_snapshots_from_records(empty_id).get("ok", false)), "empty formal ID is rejected")
	var life := make_formal_records(1)
	life[0].character_type = 1
	check(not bool(FormalPartySource.build_party_snapshots_from_records(life).get("ok", false)), "life character is rejected")
	var unsupported := make_formal_records(1)
	unsupported[0].profession_id = &"unsupported"
	check(not bool(FormalPartySource.build_party_snapshots_from_records(unsupported).get("ok", false)), "unsupported profession is rejected")
	var duplicate_slot := make_formal_records(2)
	duplicate_slot[1].party_slot = 0
	check(not bool(FormalPartySource.build_party_snapshots_from_records(duplicate_slot).get("ok", false)), "duplicate formal slots are rejected")
	var invalid_hp := make_formal_records(1)
	invalid_hp[0].final_stats.max_hp = 0
	check(not bool(FormalPartySource.build_party_snapshots_from_records(invalid_hp).get("ok", false)), "non-positive max HP is rejected")
	var invalid_speed := make_formal_records(1)
	invalid_speed[0].final_stats.attack_speed = 0.0
	check(not bool(FormalPartySource.build_party_snapshots_from_records(invalid_speed).get("ok", false)), "zero attack speed is rejected")
	var invalid_nan := make_formal_records(1)
	invalid_nan[0].final_stats.attack_speed = NAN
	check(not bool(FormalPartySource.build_party_snapshots_from_records(invalid_nan).get("ok", false)), "NaN final stat is rejected")
	check(
		not bool(PreviewRequestBuilder.build_preview_request("no-party", {}).get("ok", false)),
		"request builder never backfills prototype characters"
	)


func check_dynamic_party_runtime() -> void:
	for party_size: int in range(1, 5):
		var request: Dictionary = make_request(
			"dynamic-%d" % party_size,
			FormalPartySource.build_party_snapshots_from_records(
				make_formal_records(party_size)
			).get("value", [])
		).get("value", {})
		var run := await start_host(request)
		check(bool(run.get("started", false)), "%d-person dynamic Host starts" % party_size)
		var host = run.get("host")
		var prototype = host.get_active_prototype()
		var snapshot: Dictionary = prototype.get_battle_snapshot()
		check(snapshot.get("characters", []).size() == party_size, "%d-person request creates exactly %d runtime nodes" % [party_size, party_size])
		check(prototype.get_runtime_character_ids().size() == party_size, "%d-person runtime has no empty placeholders" % party_size)
		check(bool(prototype.is_integration_party_mode()), "%d-person runtime is marked as integration mode" % party_size)
		check(snapshot.get("deployment", {}).size() == party_size, "%d-person runtime deploys every requested member" % party_size)
		check(runtime_ids_match_request(snapshot, request), "%d-person runtime nodes carry formal stable IDs" % party_size)
		for character: Dictionary in snapshot.get("characters", []):
			check(
				int(character.get("current_health", 0)) == int(character.get("max_health", -1)),
				"%d-person preview starts each detached runtime at final max HP" % party_size
			)
		prototype.restart_battle()
		check(prototype.get_battle_snapshot().get("characters", []).size() == party_size, "%d-person restart creates no duplicate character" % party_size)
		var terminal_results: Array = run.get("results")
		host.abort_preview()
		check(terminal_results.size() == 1, "%d-person abort emits one result" % party_size)
		check(party_result_ids(terminal_results[0]) == request_party_ids(request), "%d-person abort output matches formal IDs" % party_size)
		host.queue_free()
		await process_frame

	var two_records := make_formal_records(2)
	two_records[1].profession_id = &"healer"
	two_records[1].role_display_name = "治疗者"
	var two_party: Array = FormalPartySource.build_party_snapshots_from_records(two_records).get("value", [])
	var healing_run := await start_host(make_request("healing", two_party).get("value", {}))
	var healing_host = healing_run.host
	var healing_prototype = healing_host.get_active_prototype()
	var guard = healing_prototype.character_nodes[&"formal_1"]
	var healer = healing_prototype.character_nodes[&"formal_2"]
	guard.take_damage(8)
	var heal_action: Dictionary = healer.simulate_action(
		1.0,
		[],
		healing_prototype.character_nodes.values(),
		null
	)
	check(StringName(heal_action.get("type", &"")) == &"heal", "dynamic healer finds a real injured teammate")
	check(int(heal_action.get("amount", 0)) > 0, "dynamic healer applies mapped formal healing")
	healing_host.abort_preview()
	healing_host.queue_free()
	await process_frame

	var solo_party: Array = FormalPartySource.build_party_snapshots_from_records(make_formal_records(1)).get("value", [])
	var solo_run := await start_host(make_request("solo-down", solo_party).get("value", {}))
	var solo_host = solo_run.host
	var solo_prototype = solo_host.get_active_prototype()
	var solo_character = solo_prototype.character_nodes[&"formal_1"]
	solo_character.take_damage(99999)
	check(not solo_character.is_alive, "single remaining character can enter the down state")
	check(solo_prototype.character_nodes.size() == 1, "all-down handling creates no ghost party member")
	solo_host.abort_preview()
	check(bool(solo_run.results[0].party_results[0].is_down), "abort output reports the formal character down fact")
	solo_host.queue_free()
	await process_frame

	var standalone = PrototypeScene.instantiate()
	root.add_child(standalone)
	await process_frame
	check(not standalone.is_integration_party_mode(), "independent prototype remains outside integration mode")
	check(standalone.get_runtime_character_ids() == [&"guard", &"hunter", &"mage", &"doctor"], "independent prototype keeps its frozen four characters")
	standalone.queue_free()
	await process_frame


func check_formal_main_entry(game_state: Node) -> void:
	var formal_party := FormalPartySource.build_party_snapshots(game_state)
	check(bool(formal_party.get("ok", false)), "formal default CharacterRoster party builds successfully")
	var expected_ids: Array[String] = []
	for member: Dictionary in formal_party.get("value", []):
		expected_ids.append(String(member.character_id))
		check(
			member.formal_final_stats == game_state.get_final_combat_stats(
				StringName(member.character_id)
			)
			and not Dictionary(member.get("stat_scale_report", {})).is_empty(),
			"formal snapshot retains the final-stat API output once and records its scale report for %s"
			% String(member.character_id)
		)
	expected_ids.sort()
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	var coordinator = main.battle_preview_coordinator
	coordinator.battle_route_option.select(1)
	coordinator.on_battle_route_selected(1)
	coordinator.on_battle_route_start_pressed()
	check(is_instance_valid(coordinator.v2_preview_host), "formal main launches the V2-8C Host")
	var active_request: Dictionary = coordinator.battle_router.active_request
	check(request_party_ids(active_request) == expected_ids, "formal main request matches CharacterRoster party order and IDs")
	check(not party_contains_prototype_id(active_request.get("party", [])), "formal main request has no prototype fallback")
	check(
		coordinator.last_v2_party_debug_text.contains("V2-8C不结算预览")
			and coordinator.v2_preview_host.get_party_debug_text().contains("正式 HP"),
		"formal main and the running Host expose the party scale debug details"
	)
	coordinator.v2_preview_host.abort_preview()
	check(coordinator.last_v2_preview_summary_text.contains("V2-8C正式队伍预览未执行正式结算"), "formal main summary states exact no-settlement message")
	for character_id: String in expected_ids:
		check(coordinator.last_v2_preview_summary_text.contains(character_id), "summary identifies formal character %s" % character_id)
	check(coordinator._last_preview_request.is_empty(), "return releases the formal request snapshot")
	main.queue_free()
	await process_frame


func run_actual_formal_party(game_state: Node) -> Dictionary:
	var party_creation := FormalPartySource.build_party_snapshots(game_state)
	var request_creation := make_request("formal-actual", party_creation.get("value", []))
	var request: Dictionary = request_creation.get("value", {})
	var run := await start_host(request)
	var host = run.host
	var results: Array = run.results
	var step_count := 0
	while results.is_empty() and step_count < MAX_STEPS:
		host.advance_for_test(STEP)
		step_count += 1
	var party_runtime: Array = []
	if not results.is_empty():
		for member: Dictionary in request.get("party", []):
			var compatibility := ProfessionCompatibility.get_compatibility(
				StringName(member.profession_id)
			)
			party_runtime.append({
				"id": member.character_id,
				"name": member.display_name,
				"profession": member.profession_id,
				"max_hp": member.final_stats.max_hp,
				"attack": member.final_stats.attack,
				"attack_speed": member.final_stats.attack_speed,
				"action_interval": ProfessionCompatibility.v2_attack_rate_to_action_interval(
					float(member.final_stats.attack_speed)
				),
				"range": compatibility.get("action_range", 0.0),
			})
	var result: Dictionary = results[0] if not results.is_empty() else {}
	host.queue_free()
	await process_frame
	return {
		"started": bool(run.get("started", false)),
		"terminal": not results.is_empty(),
		"result": result,
		"request": request,
		"party_runtime": party_runtime,
		"steps": step_count,
	}


func check_terminal_zero_writes(
	game_state: Node,
	formal_before: Dictionary,
	save_before: Dictionary
) -> void:
	for terminal: StringName in [&"victory", &"defeat", &"abort"]:
		var party: Array = FormalPartySource.build_party_snapshots(game_state).get("value", [])
		var request: Dictionary = make_request("zero-write-%s" % terminal, party).get("value", {})
		var run := await start_host(request)
		var host = run.host
		match terminal:
			&"victory":
				host.force_victory_for_test()
			&"defeat":
				host.force_defeat_for_test()
			_:
				host.abort_preview()
		check(run.results.size() == 1, "%s emits one terminal fact result" % terminal)
		if run.results.size() == 1:
			var expected_outcome: String = String({
				&"victory": BattleContract.OUTCOME_VICTORY,
				&"defeat": BattleContract.OUTCOME_DEFEAT,
				&"abort": BattleContract.OUTCOME_ABORTED,
			}[terminal])
			check(
				String(run.results[0].get("outcome", "")) == expected_outcome,
				"%s reports the expected output outcome" % terminal
			)
			check(
				BattleContract.validate_result(run.results[0]).is_empty(),
				"%s output remains contract-valid" % terminal
			)
		check(snapshot_formal_sources(game_state) == formal_before, "%s writes no CharacterRoster or GameState data" % terminal)
		check(snapshot_file(FORMAL_SAVE_PATH) == save_before, "%s does not call SaveSystem" % terminal)
		host.queue_free()
		await process_frame


func start_host(request: Dictionary) -> Dictionary:
	var host = PreviewHostScene.instantiate()
	root.add_child(host)
	await process_frame
	var results: Array[Dictionary] = []
	host.preview_finished.connect(func(result: Dictionary) -> void:
		results.append(result.duplicate(true))
	)
	var start_result: Dictionary = host.start_preview(request)
	return {
		"host": host,
		"results": results,
		"started": bool(start_result.get("ok", false)),
	}


func make_request(session_id: String, party: Array) -> Dictionary:
	return PreviewRequestBuilder.build_preview_request(session_id, {
		"encounter_id": &"development:formation_defense_preview",
		"encounter_node_id": "",
		"source_mode": &"MAIN_DEVELOPMENT_PREVIEW",
		"party_snapshots": party.duplicate(true),
	})


func make_formal_records(count: int) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for index: int in range(count):
		var profession_id := PROFESSIONS[index]
		records.append({
			"character_id": StringName("formal_%d" % (index + 1)),
			"character_type": 0,
			"display_name": "正式角色%d" % (index + 1),
			"profession_id": profession_id,
			"role_display_name": String(profession_id),
			"party_slot": index,
			"is_in_party": true,
			"final_stats": {
				"max_hp": 40 + index,
				"attack": 10 + index,
				"defense": 2 + index,
				"speed": 3 + index,
				"attack_speed": float(3 + index),
				"crit_rate": 0.05,
				"crit_damage": 1.5,
			},
			"equipped_skill_ids": [StringName("skill_%d" % (index + 1))],
			"battle_visual_id": StringName("visual_%d" % (index + 1)),
			"injury_state": &"healthy",
		})
	return records


func party_slots_are_sorted(party: Array) -> bool:
	for index: int in range(party.size()):
		if int(party[index].get("party_slot", -1)) != index:
			return false
	return true


func party_contains_prototype_id(party: Array) -> bool:
	for member: Dictionary in party:
		if String(member.get("character_id", "")).begins_with("prototype:"):
			return true
	return false


func request_party_ids(request: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for member: Dictionary in request.get("party", []):
		ids.append(String(member.get("character_id", "")))
	ids.sort()
	return ids


func party_result_ids(result: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for member: Dictionary in result.get("party_results", []):
		ids.append(String(member.get("character_id", "")))
	ids.sort()
	return ids


func comparable_result_facts(result: Dictionary) -> Dictionary:
	var facts := result.duplicate(true)
	facts.erase("battle_session_id")
	facts.erase("settlement_id")
	return facts


func runtime_ids_match_request(snapshot: Dictionary, request: Dictionary) -> bool:
	var runtime_ids: Array[String] = []
	for character: Dictionary in snapshot.get("characters", []):
		runtime_ids.append(String(character.get("character_id", "")))
	runtime_ids.sort()
	return runtime_ids == request_party_ids(request)


func preview_runtime_boundary_is_pure() -> bool:
	for path: String in [
		"res://systems/formation_defense_preview_request_builder.gd",
		"res://systems/formation_defense_battle_router.gd",
		"res://features/battle/formation_defense_preview_host.gd",
		"res://prototype/formation_defense/scripts/formation_defense_prototype.gd",
	]:
		var source := FileAccess.get_file_as_string(path)
		for forbidden: String in [
			"/root/GameState",
			"CharacterRoster",
			"SaveSystem",
			"save_game(",
			"process_battle_result(",
			"finish_battle(",
		]:
			if source.contains(forbidden):
				return false
	return true


func snapshot_formal_sources(game_state: Node) -> Dictionary:
	return {
		"roster": game_state.character_roster.to_dictionary(),
		"resources": game_state.resources.duplicate(true),
		"statistics": game_state.statistics.duplicate(true),
		"expedition_state": game_state.expedition_state.duplicate(true),
		"battle_state": game_state.battle_state.duplicate(true),
		"pending_battle_result": game_state.pending_battle_result.duplicate(true),
		"last_battle_result": game_state.last_battle_result.duplicate(true),
		"temporary_cargo": {
			"ore": int(game_state.expedition_state.get("cargo_ore", 0)),
			"herb": int(game_state.expedition_state.get("cargo_herb", 0)),
		},
		"save_last_error": String(game_state.save_system.last_error),
	}


func snapshot_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"exists": false}
	return {
		"exists": true,
		"size": FileAccess.get_file_as_bytes(path).size(),
		"modified": FileAccess.get_modified_time(path),
	}


func check(condition: bool, message: String) -> void:
	check_count += 1
	if not condition:
		failures.append(message)


func finish() -> void:
	if failures.is_empty():
		print("v2-8c formal party mapping smoke ok (%d checks)" % check_count)
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)

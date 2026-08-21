extends SceneTree

const BattleContract := preload(
	"res://scripts/data/formation_defense_battle_contract.gd"
)
const BattleRouter := preload(
	"res://systems/formation_defense_battle_router.gd"
)
const FormalPartySource := preload(
	"res://systems/formation_defense_formal_party_source.gd"
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

var failures: Array[String] = []
var check_count := 0


class FakeFormalBattleGateway:
	extends RefCounted

	var start_count := 0
	var last_encounter_id: StringName = &""
	var should_start := true

	func start_battle(encounter_id: StringName) -> bool:
		start_count += 1
		last_encounter_id = encounter_id
		return should_start


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var game_state := root.get_node_or_null("/root/GameState")
	check(game_state != null, "formal GameState remains available")
	if game_state == null:
		finish()
		return
	var formal_before := snapshot_formal_sources(game_state)
	var save_before := snapshot_file(FORMAL_SAVE_PATH)

	var fresh_router = BattleRouter.new()
	check(fresh_router.current_mode == BattleRouter.MODE_V1, "new router defaults to V1")
	fresh_router.set_mode(BattleRouter.MODE_V2_INTEGRATION_PREVIEW)
	var restarted_router = BattleRouter.new()
	check(restarted_router.current_mode == BattleRouter.MODE_V1, "new startup forgets the previous V2 selection")
	check(not restarted_router.set_mode(&"INVALID_MODE"), "invalid mode is rejected")
	check(restarted_router.current_mode == BattleRouter.MODE_V1, "invalid mode safely falls back to V1")

	var gateway := FakeFormalBattleGateway.new()
	var v1_result: Dictionary = restarted_router.route_selected_battle(
		gateway,
		{"encounter_id": &"forest_slime_pair"}
	)
	check(bool(v1_result.get("ok", false)), "V1 route starts through the supplied formal gateway")
	check(gateway.start_count == 1, "V1 calls the formal start entry exactly once")
	check(gateway.last_encounter_id == &"forest_slime_pair", "V1 preserves the encounter ID")
	check(not restarted_router.has_active_preview_session(), "V1 creates no V2 session")
	check(v1_result.get("request", {}).is_empty(), "V1 generates no V2 request or result")

	var router = BattleRouter.new()
	router.set_session_id_factory_for_tests(
		func(sequence: int) -> String: return "v2-8b-test-session-%02d" % sequence
	)
	check(router.set_mode(BattleRouter.MODE_V2_INTEGRATION_PREVIEW), "V2 requires an explicit mode selection")
	var context := make_preview_context(game_state)
	var first_route: Dictionary = router.route_selected_battle(null, context)
	check(bool(first_route.get("ok", false)), "explicit V2 selection creates a preview request")
	var first_request: Dictionary = first_route.get("request", {})
	check(BattleContract.validate_request(first_request).is_empty(), "V2 input contract is valid")
	check(first_request.battle_session_id == "v2-8b-test-session-01", "test session factory is deterministic")
	check(first_request.random_seed == 2703, "frozen V2 random seed crosses the route")
	check(
		first_request.battle_config_ref.wave_config_id
			== "v2_7b_three_archetype_full_battle",
		"frozen V2 battle ID crosses the route"
	)
	check(first_request.battle_id == "forest_slime_pair", "formal source encounter ID is preserved")
	check(all_party_ids_are_formal(first_request.party), "preview party uses formal stable IDs")
	var duplicate_start: Dictionary = router.route_selected_battle(null, context)
	check(not bool(duplicate_start.get("ok", false)), "consecutive clicks cannot create a second V2 session")
	check(router.get_active_session_id() == first_request.battle_session_id, "duplicate start preserves the active session")

	var actual_run := await run_actual_preview(first_request)
	check(bool(actual_run.get("started", false)), "real V2 scene accepts the validated request")
	check(bool(actual_run.get("terminal", false)), "real V2 simulation reaches a terminal state")
	check(int(actual_run.get("scene_count_after", -1)) == 0, "terminal output removes the V2 scene")
	var first_result: Dictionary = actual_run.get("result", {})
	print("v2-8b actual lifecycle: outcome=%s time=%.1f generated=%d defeated=%d leaked=%d durability=%d/%d" % [
		String(first_result.get("outcome", "")),
		float(first_result.get("duration_seconds", 0.0)),
		int(first_result.get("battle_statistics", {}).get("generated_enemies", 0)),
		int(first_result.get("battle_statistics", {}).get("defeated_enemies", 0)),
		int(first_result.get("battle_statistics", {}).get("leaked_enemies", 0)),
		int(first_result.get("village_durability", {}).get("remaining", 0)),
		int(first_result.get("village_durability", {}).get("maximum", 0)),
	])
	check(BattleContract.validate_result(first_result).is_empty(), "real V2 run creates a valid output contract")
	check(first_result.battle_session_id == first_request.battle_session_id, "real output matches the input session")
	check(
		first_result.settlement_id
			== "formation-defense:v1:%s" % first_request.battle_session_id,
		"settlement ID follows contract v1 format"
	)
	check(first_result.outcome in ["VICTORY", "DEFEAT"], "real run reports an actual victory or defeat")
	check(int(first_result.battle_statistics.generated_enemies) > 0, "real run uses the Wave Director and spawns enemies")
	check(all_party_result_ids_are_formal(first_result.party_results), "output preserves formal stable IDs")
	check(snapshot_formal_sources(game_state) == formal_before, "real V2 terminal result writes no formal data")
	check(snapshot_file(FORMAL_SAVE_PATH) == save_before, "real V2 run does not touch the save file")
	var first_acceptance: Dictionary = router.accept_preview_result(first_result)
	check(bool(first_acceptance.get("ok", false)), "router accepts the matching terminal output once")
	check(not router.has_active_preview_session(), "accepted terminal output clears the active session")
	check(not bool(router.accept_preview_result(first_result).get("ok", false)), "duplicate terminal output is rejected")

	var abort_route: Dictionary = router.route_selected_battle(null, context)
	var abort_request: Dictionary = abort_route.get("request", {})
	check(abort_request.battle_session_id != first_request.battle_session_id, "next preview receives a new session ID")
	check(not bool(router.accept_preview_result(first_result).get("ok", false)), "old session result is rejected during a new session")
	check(router.get_active_session_id() == abort_request.battle_session_id, "stale output cannot close the new session")
	var abort_case := await run_controlled_terminal(abort_request, &"abort")
	var abort_result: Dictionary = abort_case.get("result", {})
	check(abort_result.get("outcome", "") == BattleContract.OUTCOME_ABORTED, "explicit exit produces ABORTED")
	check(int(abort_case.get("emission_count", 0)) == 1, "abort emits exactly one terminal output")
	check(bool(router.accept_preview_result(abort_result).get("ok", false)), "router accepts the abort result")
	check(snapshot_formal_sources(game_state) == formal_before, "abort writes no formal data")

	var defeat_route: Dictionary = router.route_selected_battle(null, context)
	var defeat_case := await run_controlled_terminal(defeat_route.request, &"defeat")
	var defeat_result: Dictionary = defeat_case.get("result", {})
	check(defeat_result.get("outcome", "") == BattleContract.OUTCOME_DEFEAT, "V2 failure returns safely")
	check(bool(router.accept_preview_result(defeat_result).get("ok", false)), "router accepts one V2 failure")
	check(snapshot_formal_sources(game_state) == formal_before, "failure writes no formal data")

	var victory_route: Dictionary = router.route_selected_battle(null, context)
	var victory_case := await run_controlled_terminal(victory_route.request, &"victory")
	var victory_result: Dictionary = victory_case.get("result", {})
	check(victory_result.get("outcome", "") == BattleContract.OUTCOME_VICTORY, "V2 victory returns safely")
	check(bool(router.accept_preview_result(victory_result).get("ok", false)), "router accepts one V2 victory")
	check(snapshot_formal_sources(game_state) == formal_before, "victory writes no formal data")

	var invalid_host_route: Dictionary = router.route_selected_battle(null, context)
	var invalid_host = PreviewHostScene.instantiate()
	root.add_child(invalid_host)
	await process_frame
	invalid_host.preview_scene_path = "res://missing/v2_preview_scene.tscn"
	var invalid_start: Dictionary = invalid_host.start_preview(invalid_host_route.request)
	check(not bool(invalid_start.get("ok", false)), "scene load failure is diagnosed")
	check(int(invalid_host.get_snapshot().prototype_scene_count) == 0, "load failure creates no partial V2 scene")
	router.fail_active_preview("controlled scene load failure")
	check(not router.has_active_preview_session(), "load failure clears the route safely")
	invalid_host.queue_free()
	await process_frame

	var recovery_route: Dictionary = router.route_selected_battle(null, context)
	check(bool(recovery_route.get("ok", false)), "a legal preview can start after a load failure")
	var recovery_case := await run_controlled_terminal(recovery_route.request, &"abort")
	check(bool(router.accept_preview_result(recovery_case.result).get("ok", false)), "post-error preview can return normally")
	check(snapshot_formal_sources(game_state) == formal_before, "all preview outcomes preserve CharacterRoster and GameState")
	check(snapshot_file(FORMAL_SAVE_PATH) == save_before, "all preview outcomes preserve SaveSystem content")

	var standalone = PrototypeScene.instantiate()
	root.add_child(standalone)
	await process_frame
	check(standalone.get_state_name() == "READY", "prototype still starts independently in its original debug mode")
	check(standalone.scenario_option.visible, "independent prototype keeps its scenario selector")
	standalone.queue_free()
	await process_frame

	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	var coordinator = main.battle_preview_coordinator
	check(coordinator.battle_router.current_mode == BattleRouter.MODE_V1, "formal main UI starts with V1 selected")
	check(coordinator.battle_route_option.get_item_text(0) == "V1正式战斗（默认）", "main UI labels the formal default clearly")
	check(coordinator.battle_route_option.get_item_text(1) == "V2接入预览（不结算）", "main UI labels V2 as a no-settlement preview")
	check(not is_instance_valid(coordinator.v2_preview_host), "formal main does not preload a V2 scene")
	coordinator.battle_route_option.select(1)
	coordinator.on_battle_route_selected(1)
	coordinator.on_battle_route_start_pressed()
	check(is_instance_valid(coordinator.v2_preview_host), "formal main UI explicitly launches the V2 host")
	check(not main.village_view.visible and not main.expedition_view.visible, "V2 preview temporarily covers the formal safe view")
	check(coordinator.v2_preview_host.abort_preview(), "main UI preview can be safely aborted")
	check(not coordinator.battle_router.has_active_preview_session(), "main UI abort clears its route session")
	check(coordinator.v2_preview_summary_panel.visible, "main UI abort returns with a debug summary")
	check(main.village_view.visible, "main UI abort restores the startup safe view")
	check(coordinator.last_v2_preview_summary_text.contains("ABORTED"), "main UI summary reports the abort outcome")
	check(coordinator.last_v2_preview_summary_text.contains("无正式遭遇上下文"), "safe development entry identifies missing formal context")
	coordinator.close_v2_preview_summary()
	check(not coordinator.v2_preview_summary_panel.visible, "summary closes without changing formal state")
	var summary: String = coordinator.format_v2_preview_summary(first_result, first_request)
	check(summary.contains("V2-8C正式队伍预览未执行正式结算"), "debug summary states that settlement did not run")
	check(summary.contains(first_result.battle_session_id), "debug summary comes from the accepted output contract")
	check(summary.contains("forest_slime_pair"), "debug summary identifies the formal source encounter")
	check(main.find_child("RewardButton", true, false) == null, "preview summary exposes no reward action")
	check(snapshot_formal_sources(game_state) == formal_before, "formal main UI preview is also zero-write")
	main.queue_free()
	await process_frame

	check(preview_boundary_has_no_formal_writes(), "V2 boundary contains no formal singleton or save access")
	check(snapshot_formal_sources(game_state) == formal_before, "main/host lifecycle leaves every formal snapshot unchanged")
	check(snapshot_file(FORMAL_SAVE_PATH) == save_before, "save version and persisted file remain unchanged")
	finish()


func run_actual_preview(request: Dictionary) -> Dictionary:
	var host = PreviewHostScene.instantiate()
	root.add_child(host)
	await process_frame
	var results: Array[Dictionary] = []
	host.preview_finished.connect(func(result: Dictionary) -> void:
		results.append(result.duplicate(true))
	)
	var start_result: Dictionary = host.start_preview(request)
	var step_count := 0
	while results.is_empty() and step_count < MAX_STEPS:
		host.advance_for_test(STEP)
		step_count += 1
	var host_snapshot: Dictionary = host.get_snapshot()
	var result: Dictionary = results[0] if not results.is_empty() else {}
	host.queue_free()
	await process_frame
	return {
		"started": bool(start_result.get("ok", false)),
		"terminal": not results.is_empty(),
		"result": result,
		"steps": step_count,
		"scene_count_after": int(host_snapshot.get("prototype_scene_count", -1)),
	}


func run_controlled_terminal(
	request: Dictionary,
	terminal: StringName
) -> Dictionary:
	var host = PreviewHostScene.instantiate()
	root.add_child(host)
	await process_frame
	var results: Array[Dictionary] = []
	host.preview_finished.connect(func(result: Dictionary) -> void:
		results.append(result.duplicate(true))
	)
	var start_result: Dictionary = host.start_preview(request)
	if bool(start_result.get("ok", false)):
		match terminal:
			&"victory":
				host.force_victory_for_test()
			&"defeat":
				host.force_defeat_for_test()
			_:
				host.abort_preview()
	var result: Dictionary = results[0] if not results.is_empty() else {}
	var emission_count := results.size()
	var scene_count_after := int(host.get_snapshot().prototype_scene_count)
	host.queue_free()
	await process_frame
	return {
		"started": bool(start_result.get("ok", false)),
		"result": result,
		"emission_count": emission_count,
		"scene_count_after": scene_count_after,
	}


func make_preview_context(game_state: Node) -> Dictionary:
	var party_creation := FormalPartySource.build_party_snapshots(game_state)
	return {
		"encounter_id": &"forest_slime_pair",
		"encounter_node_id": "forest_depths",
		"source_mode": &"FORMAL_EXPEDITION_CONTEXT",
		"party_snapshots": party_creation.get("value", []).duplicate(true),
	}


func all_party_ids_are_formal(party: Array) -> bool:
	if party.size() != 4:
		return false
	for member: Dictionary in party:
		if String(member.get("character_id", "")).begins_with("prototype:"):
			return false
	return true


func all_party_result_ids_are_formal(party_results: Array) -> bool:
	if party_results.size() != 4:
		return false
	for member: Dictionary in party_results:
		if String(member.get("character_id", "")).begins_with("prototype:"):
			return false
	return true


func preview_boundary_has_no_formal_writes() -> bool:
	for path: String in [
		"res://systems/formation_defense_preview_request_builder.gd",
		"res://systems/formation_defense_battle_router.gd",
		"res://features/battle/formation_defense_preview_host.gd",
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
		print("v2-8b dual battle entry smoke ok (%d checks)" % check_count)
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)

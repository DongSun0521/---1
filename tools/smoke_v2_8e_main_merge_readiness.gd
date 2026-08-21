extends SceneTree

const BattleContract := preload(
	"res://scripts/data/formation_defense_battle_contract.gd"
)
const BattleSystem := preload("res://systems/battle_system.gd")
const BattleRouter := preload(
	"res://systems/formation_defense_battle_router.gd"
)
const FormalPartySource := preload(
	"res://systems/formation_defense_formal_party_source.gd"
)
const IntegrationPolicy := preload(
	"res://systems/formation_defense_integration_policy.gd"
)
const RequestBuilder := preload(
	"res://systems/formation_defense_preview_request_builder.gd"
)
const SettlementService := preload(
	"res://systems/formation_defense_settlement_service.gd"
)
const Coordinator := preload(
	"res://features/main/formation_defense_preview_coordinator.gd"
)
const MainScene := preload("res://features/main/main.tscn")
const SaveSystem := preload("res://systems/save_system.gd")

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
	check_default_policy_and_matrix()
	await check_debug_release_ui(game_state)
	await check_release_formal_entry(game_state)
	check_request_and_router_guards(game_state)
	check_formal_victory(game_state)
	check_formal_failure(game_state)
	check_formal_abort(game_state)
	await check_release_main_scene()
	check_merge_safety_files()
	finish()


func check_default_policy_and_matrix() -> void:
	var release_policy = IntegrationPolicy.new({"debug_tools_visible": false})
	check(not release_policy.formation_defense_rollout_enabled, "clean policy starts with V2 formal rollout disabled")
	check(not release_policy.debug_tools_visible, "release visibility can be injected without an export build")
	var forest_off := release_policy.resolve_formal_route(&"forest_slime_pair")
	check(bool(forest_off.get("ok", false)), "supported forest route resolves while rollout is disabled")
	check(StringName(forest_off.get("route", &"")) == IntegrationPolicy.IMPLEMENTATION_V1, "rollout disabled explicitly routes supported forest encounter to V1")
	var boss_off := release_policy.resolve_formal_route(&"ruins_guard")
	check(StringName(boss_off.get("route", &"")) == IntegrationPolicy.IMPLEMENTATION_V1, "Boss is explicitly routed to V1")
	var unconfigured := release_policy.resolve_formal_route(&"future_encounter")
	check(bool(unconfigured.get("ok", false)), "unconfigured encounter has a safe explicit result")
	check(StringName(unconfigured.get("route", &"")) == IntegrationPolicy.IMPLEMENTATION_V1, "unconfigured encounter explicitly uses V1")
	check(StringName(unconfigured.get("entry", {}).get("support_status", &"")) == IntegrationPolicy.STATUS_UNCONFIGURED, "unconfigured route is not described as a runtime fallback")

	var enabled_policy = IntegrationPolicy.new({
		"debug_tools_visible": true,
		"formation_defense_rollout_enabled": true,
	})
	var forest_on := enabled_policy.resolve_formal_route(&"forest_slime_pair")
	check(bool(forest_on.get("ok", false)), "enabled supported forest route resolves")
	check(StringName(forest_on.get("route", &"")) == IntegrationPolicy.IMPLEMENTATION_V2, "enabled supported forest route selects V2")
	check(StringName(forest_on.get("entry", {}).get("battle_id", &"")) == &"v2_7b_three_archetype_full_battle", "forest route uses the frozen validated V2 battle")
	var boss_on := enabled_policy.resolve_formal_route(&"ruins_guard")
	check(StringName(boss_on.get("route", &"")) == IntegrationPolicy.IMPLEMENTATION_V1, "enabling rollout does not route unsupported Boss to V2")
	check(not IntegrationPolicy.new({"debug_tools_visible": false}).formation_defense_rollout_enabled, "a fresh process policy resets rollout to false")
	var matrix := enabled_policy.get_support_matrix()
	check(matrix.size() == BattleSystem.ENCOUNTERS.size(), "support matrix covers every current formal encounter")
	var matrix_ids: Array[StringName] = []
	for entry: Dictionary in matrix:
		matrix_ids.append(StringName(entry.get("encounter_id", &"")))
	check(matrix_ids.has(&"forest_slime_pair") and matrix_ids.has(&"ruins_guard"), "support matrix contains forest and Boss encounter IDs")
	check(StringName(matrix[0].get("encounter_id", &"")) != StringName(matrix[1].get("encounter_id", &"")), "support matrix encounter IDs are unique")

	var invalid_table := IntegrationPolicy.FORMAL_ROUTE_TABLE.duplicate(true)
	invalid_table[&"forest_slime_pair"]["battle_id"] = &"missing_v2_battle"
	var invalid_policy = IntegrationPolicy.new({
		"debug_tools_visible": false,
		"formation_defense_rollout_enabled": true,
		"route_table": invalid_table,
	})
	var invalid := invalid_policy.resolve_formal_route(&"forest_slime_pair")
	check(not bool(invalid.get("ok", false)), "explicit V2 route with missing battle config is rejected")
	check(StringName(invalid.get("route", &"")) == &"", "invalid explicit V2 route does not silently fall back to V1")


func check_debug_release_ui(game_state: Node) -> void:
	var debug_fixture := create_coordinator_fixture(
		game_state,
		IntegrationPolicy.new({"debug_tools_visible": true})
	)
	var debug_coordinator = debug_fixture.coordinator
	check(debug_fixture.navigation.get_node_or_null("BattleRouteDebug") != null, "Debug creates the development battle controls")
	check(debug_coordinator.battle_route_option != null, "Debug creates a route selector")
	check(debug_coordinator.battle_route_option.item_count == 3, "Debug keeps exactly the three established development modes")
	check(debug_coordinator.battle_route_option.get_item_metadata(0) == BattleRouter.MODE_V1, "Debug selector defaults to V1")
	check(debug_coordinator.settlement_confirmation_dialog != null, "Debug creates the settlement validation warning")
	check(debug_fixture.navigation.get_child_count() == 2, "Debug owns only its spacer and route box")
	debug_fixture.root.queue_free()
	await process_frame

	var release_policy = IntegrationPolicy.new({"debug_tools_visible": false})
	var release_fixture := create_coordinator_fixture(game_state, release_policy)
	var release_coordinator = release_fixture.coordinator
	check(release_fixture.navigation.get_node_or_null("BattleRouteDebug") == null, "Release does not create the development route box")
	check(release_fixture.navigation.get_node_or_null("BattleRouteSpacer") == null, "Release leaves no development layout spacer")
	check(release_fixture.navigation.get_child_count() == 0, "Release leaves no hidden or clickable navigation child")
	check(release_coordinator.battle_route_option == null, "Release creates no hidden route selector")
	check(release_coordinator.battle_route_start_button == null, "Release creates no hidden start button")
	check(release_coordinator.settlement_confirmation_dialog == null, "Release creates no debug settlement dialog")
	check(release_coordinator.v2_preview_summary_panel != null, "Release retains the player-facing formal result panel")
	var receipt := make_receipt()
	var formal_text: String = release_coordinator.format_v2_settlement_receipt(receipt, false)
	check(formal_text.contains("结果：胜利"), "Release formal result shows the player outcome")
	check(formal_text.contains("经验 +40") and formal_text.contains("矿石 +1"), "Release formal result shows experience and rewards")
	for forbidden: String in ["battle_session_id", "settlement_id", "V2原始", "计划指纹", "原始统计", "未自动保存"]:
		check(not formal_text.contains(forbidden), "Release formal result hides technical field %s" % forbidden)
	var debug_text: String = release_coordinator.format_v2_settlement_receipt(
		receipt,
		true,
		{"battle_statistics": {"generated_enemies": 1}},
		{"battle_config_ref": {"wave_config_id": "debug-battle"}},
		{"settlement_id": "debug-plan"}
	)
	check(debug_text.contains("battle_session_id") and debug_text.contains("settlement_id"), "Debug result retains session and settlement diagnostics")
	check(debug_text.contains("计划指纹") and debug_text.contains("原始统计"), "Debug result retains plan and raw statistics diagnostics")
	var release_abort: String = release_coordinator.format_v2_aborted_summary({"battle_session_id": "secret"}, false)
	check(not release_abort.contains("secret") and release_abort.contains("结果：已中止"), "Release aborted result hides the session but keeps player semantics")
	release_fixture.root.queue_free()
	await process_frame


func check_request_and_router_guards(game_state: Node) -> void:
	setup_forest_encounter(game_state)
	var party := FormalPartySource.build_party_snapshots(game_state)
	check(bool(party.get("ok", false)), "formal party snapshot is available for V2 formal routing")
	var expedition: Dictionary = game_state.get_expedition_state()
	var source_context := {
		"encounter_id": &"forest_slime_pair",
		"encounter_node_id": String(expedition.get("current_node_id", "")),
		"party_snapshots": party.get("value", []),
		"v2_battle_id": &"v2_7b_three_archetype_full_battle",
	}
	var router = BattleRouter.new()
	check(router.current_mode == BattleRouter.MODE_V1, "BattleRouter itself remains V1 by default")
	check(router.set_mode(BattleRouter.MODE_V2_FORMAL), "formal V2 is an explicit internal router mode")
	router.set_session_id_factory_for_tests(func(_sequence: int) -> String:
		return "v2-8e-router"
	)
	var route := router.route_selected_battle(game_state, source_context)
	check(bool(route.get("ok", false)), "formal router builds the supported encounter request")
	check(StringName(route.get("route", &"")) == BattleRouter.MODE_V2_FORMAL, "formal router returns V2_FORMAL rather than a debug mode")
	var request: Dictionary = route.get("request", {})
	check(String(request.get("encounter_context", {}).get("source_mode", "")) == RequestBuilder.FORMAL_ROUTE_SOURCE_MODE, "formal request has a distinct production source mode")
	check(StringName(request.get("battle_id", &"")) == &"forest_slime_pair", "formal request preserves the real encounter ID")
	check(StringName(request.get("battle_config_ref", {}).get("wave_config_id", &"")) == &"v2_7b_three_archetype_full_battle", "formal request references the resolved V2 battle ID")
	var missing := source_context.duplicate(true)
	missing["v2_battle_id"] = &"missing_v2_battle"
	var missing_router = BattleRouter.new()
	missing_router.set_mode(BattleRouter.MODE_V2_FORMAL)
	var missing_route := missing_router.route_selected_battle(game_state, missing)
	check(not bool(missing_route.get("ok", false)), "formal router rejects a missing battle config")
	check(not game_state.is_battle_active(), "rejected formal V2 request does not start a V1 battle")
	check(SettlementService.VALID_SOURCE_MODES.has(RequestBuilder.FORMAL_ROUTE_SOURCE_MODE), "settlement service explicitly accepts the formal route source")


func check_release_formal_entry(game_state: Node) -> void:
	setup_forest_encounter(game_state)
	var policy = IntegrationPolicy.new({
		"debug_tools_visible": false,
		"formation_defense_rollout_enabled": true,
	})
	var fixture := create_coordinator_fixture(game_state, policy)
	var coordinator = fixture.coordinator
	check(coordinator.route_formal_encounter(&"forest_slime_pair"), "Release supported encounter enters the shared formal route")
	check(is_instance_valid(coordinator.v2_preview_host), "Release formal route creates the shared V2 host")
	check(coordinator._active_v2_mode == BattleRouter.MODE_V2_FORMAL, "Release formal route is distinct from Debug settlement validation")
	check(coordinator.settlement_confirmation_dialog == null, "Release formal route shows no test-save confirmation warning")
	if is_instance_valid(coordinator.v2_preview_host):
		var status_label = coordinator.v2_preview_host.find_child(
			"PreviewStatusLabel",
			true,
			false
		)
		check(status_label != null, "Release formal host has a player status label")
		if status_label != null:
			check(not status_label.text.contains("Session"), "Release formal host hides the session ID")
			check(not status_label.text.contains("测试") and not status_label.text.contains("验证"), "Release formal host contains no test terminology")
			check(status_label.tooltip_text.is_empty(), "Release formal host exposes no attribute mapping tooltip")
		check(coordinator.v2_preview_host.abort_preview(), "Release formal battle aborts through the public player entry")
	await process_frame
	check(coordinator.v2_preview_summary_panel.visible, "Release formal abort displays a player result panel")
	check(coordinator.v2_preview_summary_title.text == "战斗已中止", "Release formal abort uses a player-facing title")
	check(not coordinator.last_v2_preview_summary_text.contains("battle_session_id"), "Release formal abort hides debug identifiers")
	check(not game_state.is_current_battle_node_cleared(), "Release formal abort keeps the node unresolved")
	fixture.root.queue_free()
	await process_frame


func check_formal_victory(game_state: Node) -> void:
	setup_forest_encounter(game_state)
	var request := build_formal_request(game_state, "v2-8e-victory")
	var router = BattleRouter.new()
	router.set_mode(BattleRouter.MODE_V2_FORMAL)
	router.set_session_id_factory_for_tests(func(_sequence: int) -> String:
		return "v2-8e-victory"
	)
	var route := router.route_selected_battle(game_state, make_formal_source(game_state))
	check(bool(route.get("ok", false)), "rollout formal victory route opens")
	request = route.get("request", {})
	var service = SettlementService.new()
	check(bool(service.open_session(game_state, request).get("ok", false)), "formal victory settlement session opens")
	var result := make_terminal_result(request, BattleContract.OUTCOME_VICTORY)
	check(bool(router.accept_settlement_result(result).get("ok", false)), "formal victory result passes the router contract")
	var preparation := service.prepare_settlement(game_state, request, result)
	check(bool(preparation.get("ok", false)), "formal victory prepares a settlement plan")
	var application := service.apply_settlement(game_state, preparation.get("value", {}))
	check(bool(application.get("ok", false)), "formal victory applies through the V1 semantic owner")
	check(game_state.is_current_battle_node_cleared(), "formal V2 victory clears the exact forest node")
	check(game_state.is_expedition_active(), "formal V2 normal victory continues the expedition")
	check(not bool(service.apply_settlement(game_state, preparation.get("value", {})).get("ok", false)), "formal V2 duplicate settlement remains rejected")


func check_formal_failure(game_state: Node) -> void:
	setup_forest_encounter(game_state)
	var request := build_formal_request(game_state, "v2-8e-failure")
	var service = SettlementService.new()
	check(bool(service.open_session(game_state, request).get("ok", false)), "formal failure settlement session opens")
	var result := make_terminal_result(request, BattleContract.OUTCOME_DEFEAT)
	var preparation := service.prepare_settlement(game_state, request, result)
	check(bool(preparation.get("ok", false)), "formal failure prepares a settlement plan")
	var application := service.apply_settlement(game_state, preparation.get("value", {}))
	check(bool(application.get("ok", false)), "formal failure applies")
	check(not game_state.is_expedition_active(), "formal V2 failure ends the expedition")
	check(not bool(application.get("value", {}).get("node_completed", true)), "formal V2 failure does not clear the node")
	check(String(application.get("value", {}).get("return_view", "")) == "village", "formal V2 failure returns to village")


func check_formal_abort(game_state: Node) -> void:
	setup_forest_encounter(game_state)
	var request := build_formal_request(game_state, "v2-8e-abort")
	var service = SettlementService.new()
	check(bool(service.open_session(game_state, request).get("ok", false)), "formal abort settlement session opens")
	var result := make_terminal_result(request, BattleContract.OUTCOME_ABORTED)
	var preparation := service.prepare_settlement(game_state, request, result)
	check(bool(preparation.get("ok", false)) and preparation.get("value", {}).is_empty(), "formal abort has no write plan")
	check(bool(service.close_aborted_session(request, result).get("ok", false)), "formal abort closes without settlement")
	check(game_state.is_expedition_active(), "formal abort keeps the expedition active")
	check(not game_state.is_current_battle_node_cleared(), "formal abort keeps the encounter unresolved")
	check(not game_state.can_move_to_next_expedition_node(), "formal abort cannot bypass the unresolved node")
	check(int(service.get_snapshot().get("settlement_count", -1)) == 0, "formal abort consumes no settlement")


func check_release_main_scene() -> void:
	var main = MainScene.instantiate()
	var policy = IntegrationPolicy.new({"debug_tools_visible": false})
	main.call("set_formation_defense_integration_policy_for_test", policy)
	root.add_child(main)
	await process_frame
	check(main.get_node_or_null("Root/Navigation/BattleRouteDebug") == null, "Release-policy formal main scene starts without development controls")
	var coordinator = main.get_node_or_null("FormationDefensePreviewCoordinator")
	check(coordinator != null, "Release main keeps the non-Autoload formal route coordinator")
	if coordinator != null:
		check(not coordinator.integration_policy.debug_tools_visible, "Release main uses the injected visibility policy")
		check(not coordinator.integration_policy.formation_defense_rollout_enabled, "Release main still starts with rollout disabled")
	main.queue_free()
	await process_frame


func check_merge_safety_files() -> void:
	check(SaveSystem.CURRENT_SAVE_VERSION == 6, "V2-8E keeps save version v6")
	var game_state := root.get_node_or_null("/root/GameState")
	var save_data: Dictionary = game_state.create_save_data() if game_state != null else {}
	check(not save_data.has("formation_defense_rollout_enabled"), "rollout switch is absent from formal save data")
	var project_text := FileAccess.get_file_as_string("res://project.godot")
	check(project_text.contains("run/main_scene=\"res://features/main/main.tscn\""), "project keeps the formal main scene unchanged")
	check(not project_text.contains("FormationDefenseIntegrationPolicy"), "integration policy adds no Autoload")
	var coordinator_text := FileAccess.get_file_as_string(
		"res://features/main/formation_defense_preview_coordinator.gd"
	)
	check(not coordinator_text.contains("func _input"), "Release has no coordinator keyboard shortcut bypass")
	var policy_text := FileAccess.get_file_as_string(
		"res://systems/formation_defense_integration_policy.gd"
	)
	check(policy_text.contains("formation_defense_rollout_enabled := false"), "rollout false is explicit in the centralized policy")
	check(not policy_text.contains("SaveSystem") and not policy_text.contains("GameState"), "rollout policy is not persisted through formal state systems")
	var readiness := FileAccess.get_file_as_string(
		"res://docs/combat_v2_main_merge_readiness.md"
	)
	for phrase: String in ["约0.08秒", "Boss", "默认关闭", "正式美术", "回滚"]:
		check(readiness.contains(phrase), "merge readiness records blocker/rollback phrase %s" % phrase)


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
		"overlay": overlay,
		"coordinator": coordinator,
	}


func setup_forest_encounter(game_state: Node) -> void:
	game_state.start_new_game()
	check(game_state.start_expedition(3, 0), "fixture starts a formal expedition")
	var routed: Array[StringName] = []
	check(game_state.move_to_next_expedition_node(
		func(encounter_id: StringName) -> void:
			routed.append(encounter_id)
	), "fixture reaches the formal forest node through the expedition API")
	check(routed == [&"forest_slime_pair"], "fixture exposes the exact forest encounter")
	check(not game_state.is_battle_active(), "fixture callback prevents implicit V1 start")


func make_formal_source(game_state: Node) -> Dictionary:
	return {
		"encounter_id": game_state.get_current_node_encounter_id(),
		"encounter_node_id": String(
			game_state.get_expedition_state().get("current_node_id", "")
		),
		"party_snapshots": FormalPartySource.build_party_snapshots(
			game_state
		).get("value", []),
		"v2_battle_id": &"v2_7b_three_archetype_full_battle",
	}


func build_formal_request(game_state: Node, session_id: String) -> Dictionary:
	var source := make_formal_source(game_state)
	var creation := RequestBuilder.build_formal_route_request(
		session_id,
		source,
		StringName(source.get("v2_battle_id", &""))
	)
	check(bool(creation.get("ok", false)), "%s formal request is valid" % session_id)
	return creation.get("value", {})


func make_terminal_result(request: Dictionary, outcome: String) -> Dictionary:
	var party_results: Array = []
	for member: Dictionary in request.get("party", []):
		party_results.append({
			"character_id": String(member.get("character_id", "")),
			"is_down": outcome == BattleContract.OUTCOME_DEFEAT,
			"remaining_hp": (
				0 if outcome == BattleContract.OUTCOME_DEFEAT
				else int(member.get("final_stats", {}).get("max_hp", 1))
			),
			"statistics": {
				"damage_dealt": 0,
				"damage_taken": 0,
				"healing_done": 0,
				"kills": 0,
				"ultimate_casts": 0,
			},
		})
	return BattleContract.create_result({
		"contract_version": BattleContract.CONTRACT_VERSION,
		"battle_session_id": String(request.get("battle_session_id", "")),
		"battle_id": String(request.get("battle_id", "")),
		"settlement_id": BattleContract.make_settlement_id(
			String(request.get("battle_session_id", ""))
		),
		"outcome": outcome,
		"duration_seconds": 1.0,
		"village_durability": {
			"remaining": 0 if outcome == BattleContract.OUTCOME_DEFEAT else 1,
			"maximum": 10,
		},
		"party_results": party_results,
		"battle_statistics": {
			"generated_enemies": 1,
			"defeated_enemies": 1 if outcome == BattleContract.OUTCOME_VICTORY else 0,
			"leaked_enemies": 1 if outcome == BattleContract.OUTCOME_DEFEAT else 0,
			"waves_completed": 1 if outcome == BattleContract.OUTCOME_VICTORY else 0,
		},
	}).get("value", {})


func make_receipt() -> Dictionary:
	return {
		"settlement_id": "formation-defense:v1:test",
		"battle_session_id": "test",
		"outcome": "victory",
		"v2_outcome": BattleContract.OUTCOME_VICTORY,
		"village_durability": {"remaining": 2, "maximum": 10},
		"downed_participant_count": 0,
		"experience_results": [{
			"display_name": "测试角色",
			"character_id": "test_character",
			"experience_gained": 40,
			"levels_gained": 0,
			"new_level": 1,
		}],
		"reward_ore": 1,
		"reward_herb": 0,
		"reward_core": 0,
		"character_injury_results": [],
		"node_completed": true,
		"expedition_continues": true,
		"return_view": "expedition",
		"message": "V2-8D正式结算已应用，未自动保存",
	}


func check(condition: bool, message: String) -> void:
	check_count += 1
	if condition:
		return
	failures.append(message)
	push_error("v2-8e: %s" % message)


func finish() -> void:
	if failures.is_empty():
		print("v2-8e main merge readiness smoke ok (%d checks)" % check_count)
		quit(0)
		return
	push_error("v2-8e main merge readiness smoke failed: %s" % "; ".join(failures))
	quit(1)

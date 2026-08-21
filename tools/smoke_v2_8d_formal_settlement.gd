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
const RequestBuilder := preload(
	"res://systems/formation_defense_preview_request_builder.gd"
)
const SettlementService := preload(
	"res://systems/formation_defense_settlement_service.gd"
)
const PreviewHostScene := preload(
	"res://features/battle/formation_defense_preview_host.tscn"
)
const MainScene := preload("res://features/main/main.tscn")
const SaveSystem := preload("res://systems/save_system.gd")

const FORMAL_SAVE_PATH := "user://adventure_village_save.json"
const STEP := 0.1
const MAX_STEPS := 3000

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
	check_mode_and_context_guards(game_state)
	await check_actual_failure(game_state)
	await check_actual_victory(game_state)
	await check_actual_abort(game_state)
	check_boss_and_participant_rules(game_state)
	check_invalid_and_conflicting_results(game_state)
	await check_formal_ui_entry(game_state)
	await check_formal_ui_failure(game_state)
	finish()


func check_mode_and_context_guards(game_state: Node) -> void:
	var router = BattleRouter.new()
	check(router.current_mode == BattleRouter.MODE_V1, "V1 remains the default mode")
	check(router.set_mode(BattleRouter.MODE_V2_SETTLEMENT_VALIDATION), "settlement validation mode is explicit and valid")
	check(router.current_mode == BattleRouter.MODE_V2_SETTLEMENT_VALIDATION, "router keeps the selected settlement validation mode")
	game_state.start_new_game()
	var party := FormalPartySource.build_party_snapshots(game_state)
	var missing_context := RequestBuilder.build_settlement_request(
		"v2-8d-missing-context",
		{"party_snapshots": party.get("value", [])}
	)
	check(not bool(missing_context.get("ok", false)), "settlement validation refuses missing formal encounter context")
	var preview_request := RequestBuilder.build_preview_request(
		"v2-8d-preview-source",
		{
			"encounter_id": &"forest_slime_pair",
			"encounter_node_id": "forest_edge",
			"source_mode": &"FORMAL_EXPEDITION_CONTEXT",
			"party_snapshots": party.get("value", []),
		}
	)
	var service = SettlementService.new()
	check(not bool(service.open_session(game_state, preview_request.get("value", {})).get("ok", false)), "preview request cannot enter formal settlement service")
	check(SettlementService.SOURCE_MODE == "FORMAL_SETTLEMENT_VALIDATION", "settlement source mode is explicit")
	check(BattleContract.make_settlement_id("abc") == "formation-defense:v1:abc", "settlement ID uses the contract version and session")
	check(SaveSystem.CURRENT_SAVE_VERSION == 6, "V2-8D does not change save version v6")
	var orphan_result := make_terminal_result(
		preview_request.get("value", {}),
		BattleContract.OUTCOME_VICTORY
	)
	check(not bool(SettlementService.new().prepare_settlement(game_state, preview_request.get("value", {}), orphan_result).get("ok", false)), "result without an opened settlement session is rejected")


func check_actual_failure(game_state: Node) -> void:
	setup_forest_encounter(game_state)
	var save_before := snapshot_file(FORMAL_SAVE_PATH)
	var formal_before := snapshot_formal_state(game_state)
	var request := build_settlement_request(game_state, "v2-8d-real-failure")
	var service = SettlementService.new()
	check(bool(service.open_session(game_state, request).get("ok", false)), "real failure settlement session opens")
	var host_run := await run_host(request, false, false)
	var result: Dictionary = host_run.result
	check(String(result.get("outcome", "")) == BattleContract.OUTCOME_DEFEAT, "unattended real V2 run reaches defeat")
	check(int(result.get("battle_statistics", {}).get("defeated_enemies", 0)) == 45, "unattended real V2 defeat keeps frozen kill count")
	check(int(result.get("battle_statistics", {}).get("leaked_enemies", 0)) == 10, "unattended real V2 defeat keeps frozen leak count")
	check(not result.has("experience") and not result.has("rewards") and not result.has("resources"), "V2 fact result contains no formal reward fields")
	var preparation := service.prepare_settlement(game_state, request, result)
	check(bool(preparation.get("ok", false)), "real V2 defeat prepares a formal plan")
	var plan: Dictionary = preparation.get("value", {})
	check(int(plan.get("experience_per_character", 0)) == 10, "failure plan uses the V1 failure experience")
	check(plan.get("rewards", {}) == {"ore": 0, "herb": 0, "core": 0}, "failure plan has no victory rewards")
	check(plan.get("injury_changes", []).size() == request.get("party", []).size(), "failure plan includes every actual participant injury")
	var application := service.apply_settlement(game_state, plan)
	check(bool(application.get("ok", false)), "real V2 defeat applies exactly once")
	var receipt: Dictionary = application.get("value", {})
	check(String(receipt.get("message", "")) == "V2-8D正式结算已应用，未自动保存", "failure receipt states applied without automatic save")
	check(String(receipt.get("v2_outcome", "")) == BattleContract.OUTCOME_DEFEAT, "failure receipt preserves the original V2 outcome")
	check(int(receipt.get("village_durability", {}).get("remaining", -1)) == 0, "failure receipt preserves zero village durability")
	check(not game_state.is_expedition_active(), "formal failure ends the expedition")
	check(String(receipt.get("return_view", "")) == "village", "formal failure returns to village")
	check(not bool(receipt.get("node_completed", true)), "formal failure does not clear the encounter node")
	for member: Dictionary in request.get("party", []):
		var character_id := StringName(member.get("character_id", &""))
		check(character_experience(game_state, character_id) == int(formal_before.experience[character_id]) + 10, "%s receives failure experience" % character_id)
		check(game_state.is_character_injured(character_id), "%s is injured by the V1 failure rule" % character_id)
	check(snapshot_file(FORMAL_SAVE_PATH) == save_before, "real failure does not write the save file")
	check(String(game_state.save_system.last_error) == String(formal_before.save_error), "real failure does not call or alter SaveSystem")
	var after_first := snapshot_formal_state(game_state)
	check(not bool(service.apply_settlement(game_state, plan).get("ok", false)), "duplicate failure application is rejected")
	check(snapshot_formal_state(game_state) == after_first, "duplicate failure cannot mutate formal state")
	var delayed_victory := result.duplicate(true)
	delayed_victory["outcome"] = BattleContract.OUTCOME_VICTORY
	check(not bool(service.prepare_settlement(game_state, request, delayed_victory).get("ok", false)), "victory after applied failure is rejected")
	check(snapshot_formal_state(game_state) == after_first, "victory after failure cannot mutate formal state")
	check(int(service.get_snapshot().get("applied_count", 0)) == 1, "failure settlement ledger applies once in this process")
	print("v2-8d real failure diff: %s" % JSON.stringify(diff_summary(formal_before, after_first)))


func check_actual_victory(game_state: Node) -> void:
	setup_forest_encounter(game_state)
	var save_before := snapshot_file(FORMAL_SAVE_PATH)
	var formal_before := snapshot_formal_state(game_state)
	var request := build_settlement_request(game_state, "v2-8d-real-victory")
	var service = SettlementService.new()
	check(bool(service.open_session(game_state, request).get("ok", false)), "real victory settlement session opens")
	var host_run := await run_host(request, true, false)
	var result: Dictionary = host_run.result
	check(String(result.get("outcome", "")) == BattleContract.OUTCOME_VICTORY, "fixed formal input turns the real V2 run into victory")
	check(int(host_run.command_clicks) > 0, "real victory uses battlefield focus input")
	check(int(host_run.ultimate_releases) > 0, "real victory uses ultimate targeting input")
	check(int(result.get("battle_statistics", {}).get("defeated_enemies", 0)) == 52, "fixed operation real V2 victory records 52 kills")
	check(int(result.get("battle_statistics", {}).get("leaked_enemies", 0)) == 8, "fixed operation real V2 victory records 8 leaks")
	var preparation := service.prepare_settlement(game_state, request, result)
	check(bool(preparation.get("ok", false)), "real V2 victory prepares a formal plan")
	var plan: Dictionary = preparation.get("value", {})
	check(int(plan.get("experience_per_character", 0)) == 40, "normal victory plan uses V1 normal victory experience")
	check(plan.get("rewards", {}) == {"ore": 1, "herb": 0, "core": 0}, "normal victory plan uses the formal encounter reward")
	check(plan.get("injury_changes", []).is_empty(), "victory plan does not create immediate failure injuries")
	var application := service.apply_settlement(game_state, plan)
	check(bool(application.get("ok", false)), "real V2 victory applies exactly once")
	var receipt: Dictionary = application.get("value", {})
	var expedition: Dictionary = game_state.get_expedition_state()
	check(String(receipt.get("v2_outcome", "")) == BattleContract.OUTCOME_VICTORY, "victory receipt preserves the original V2 outcome")
	check(int(receipt.get("village_durability", {}).get("remaining", 0)) > 0, "victory receipt preserves surviving village durability")
	check(game_state.is_expedition_active(), "normal victory continues the expedition")
	check(expedition.get("cleared_battle_node_ids", []).has(&"forest_edge"), "normal victory clears the exact encounter node")
	check(int(expedition.get("cargo_ore", 0)) == 1, "normal victory adds reward to temporary expedition cargo")
	check(String(receipt.get("return_view", "")) == "expedition", "normal victory returns to expedition")
	check(bool(receipt.get("node_completed", false)), "normal victory receipt marks the node completed")
	for member: Dictionary in request.get("party", []):
		var character_id := StringName(member.get("character_id", &""))
		check(character_experience(game_state, character_id) == int(formal_before.experience[character_id]) + 40, "%s receives normal victory experience" % character_id)
		check(not game_state.is_character_injured(character_id), "%s receives no failure injury on victory" % character_id)
	check(snapshot_file(FORMAL_SAVE_PATH) == save_before, "real victory does not write the save file")
	check(String(game_state.save_system.last_error) == String(formal_before.save_error), "real victory does not call or alter SaveSystem")
	check(int(service.get_snapshot().get("applied_count", 0)) == 1, "victory settlement ledger applies once in this process")
	print("v2-8d real victory diff: %s" % JSON.stringify(diff_summary(formal_before, snapshot_formal_state(game_state))))


func check_actual_abort(game_state: Node) -> void:
	setup_forest_encounter(game_state)
	var save_before := snapshot_file(FORMAL_SAVE_PATH)
	var formal_before := snapshot_formal_state(game_state)
	var request := build_settlement_request(game_state, "v2-8d-real-abort")
	var service = SettlementService.new()
	check(bool(service.open_session(game_state, request).get("ok", false)), "real abort settlement session opens")
	var host_run := await run_host(request, false, true)
	var result: Dictionary = host_run.result
	check(String(result.get("outcome", "")) == BattleContract.OUTCOME_ABORTED, "real host emits ABORTED")
	var preparation := service.prepare_settlement(game_state, request, result)
	check(bool(preparation.get("ok", false)) and preparation.get("value", {}).is_empty(), "ABORTED creates no formal write plan")
	var closing := service.close_aborted_session(request, result)
	check(bool(closing.get("ok", false)), "ABORTED closes the active settlement session")
	check(snapshot_formal_state(game_state) == formal_before, "ABORTED leaves all formal data unchanged")
	check(snapshot_file(FORMAL_SAVE_PATH) == save_before, "ABORTED does not write the save file")
	check(game_state.is_expedition_active(), "ABORTED keeps the expedition active")
	check(not game_state.is_current_battle_node_cleared(), "ABORTED leaves the encounter unresolved")
	check(not game_state.can_move_to_next_expedition_node(), "ABORTED unresolved encounter blocks the next node")
	check(not game_state.move_to_next_expedition_node(), "ABORTED cannot bypass the unresolved encounter")
	check(int(service.get_snapshot().get("settlement_count", 0)) == 0, "ABORTED does not consume a formal settlement")
	var delayed := result.duplicate(true)
	delayed["outcome"] = BattleContract.OUTCOME_VICTORY
	check(not bool(service.prepare_settlement(game_state, request, delayed).get("ok", false)), "delayed victory after abort is rejected")
	check(snapshot_formal_state(game_state) == formal_before, "delayed result after abort cannot mutate formal state")


func check_boss_and_participant_rules(game_state: Node) -> void:
	setup_encounter_fixture(game_state, &"ruins_entrance")
	var all_party: Array = FormalPartySource.build_party_snapshots(game_state).get("value", [])
	var selected_party: Array = [all_party[0].duplicate(true), all_party[1].duplicate(true)]
	var request := build_settlement_request(
		game_state,
		"v2-8d-boss",
		selected_party
	)
	var result := make_terminal_result(request, BattleContract.OUTCOME_VICTORY)
	var service = SettlementService.new()
	var before := snapshot_formal_state(game_state)
	check(bool(service.open_session(game_state, request).get("ok", false)), "Boss settlement session opens")
	var preparation := service.prepare_settlement(game_state, request, result)
	check(bool(preparation.get("ok", false)), "Boss victory plan prepares")
	var plan: Dictionary = preparation.get("value", {})
	check(int(plan.get("experience_per_character", 0)) == 100, "Boss victory uses V1 Boss experience")
	check(plan.get("rewards", {}) == {"ore": 5, "herb": 3, "core": 1}, "Boss victory uses the formal Boss rewards")
	check(plan.get("participant_ids", []).size() == 2, "settlement participants come from the request snapshot")
	var application := service.apply_settlement(game_state, plan)
	check(bool(application.get("ok", false)), "Boss victory applies")
	var receipt: Dictionary = application.get("value", {})
	check(receipt.get("experience_results", []).size() == 2, "Boss receipt contains only requested participants")
	for experience_result: Dictionary in receipt.get("experience_results", []):
		check(int(experience_result.get("experience_gained", 0)) == 100, "Boss participant receives the configured 100 experience")
	check(bool(game_state.boss_defeated), "Boss victory updates the formal Boss flag")
	var expedition: Dictionary = game_state.get_expedition_state()
	check(int(expedition.get("cargo_ore", 0)) == 5, "Boss ore remains temporary cargo")
	check(int(expedition.get("cargo_herb", 0)) == 3, "Boss herb remains temporary cargo")
	check(int(expedition.get("cargo_core", 0)) == 1, "Boss core remains temporary cargo")
	for index: int in range(all_party.size()):
		var character_id := StringName(all_party[index].get("character_id", &""))
		if index < 2:
			check(character_level(game_state, character_id) == int(before.levels[character_id]) + 1, "%s Boss experience levels the requested participant" % character_id)
		else:
			check(character_level(game_state, character_id) == int(before.levels[character_id]), "%s standby level remains unchanged" % character_id)
			check(character_experience(game_state, character_id) == int(before.experience[character_id]), "%s standby experience remains unchanged" % character_id)


func check_invalid_and_conflicting_results(game_state: Node) -> void:
	setup_forest_encounter(game_state)
	var request := build_settlement_request(game_state, "v2-8d-conflict")
	var result := make_terminal_result(request, BattleContract.OUTCOME_VICTORY)
	var service = SettlementService.new()
	check(bool(service.open_session(game_state, request).get("ok", false)), "conflict test session opens")
	var before := snapshot_formal_state(game_state)
	var wrong_settlement := result.duplicate(true)
	wrong_settlement["settlement_id"] = "formation-defense:v1:different-session"
	check(not bool(service.prepare_settlement(game_state, request, wrong_settlement).get("ok", false)), "same session with a different settlement ID is rejected")
	check(snapshot_formal_state(game_state) == before, "wrong settlement ID produces no partial writes")
	var wrong_party := result.duplicate(true)
	wrong_party["party_results"].remove_at(0)
	check(not bool(service.prepare_settlement(game_state, request, wrong_party).get("ok", false)), "result with a mismatched participant list is rejected")
	check(snapshot_formal_state(game_state) == before, "mismatched participant result produces no partial writes")
	var zero_durability_victory := result.duplicate(true)
	zero_durability_victory["village_durability"]["remaining"] = 0
	check(not bool(service.prepare_settlement(game_state, request, zero_durability_victory).get("ok", false)), "victory with zero village durability is rejected")
	var positive_durability_defeat := result.duplicate(true)
	positive_durability_defeat["outcome"] = BattleContract.OUTCOME_DEFEAT
	positive_durability_defeat["village_durability"]["remaining"] = 1
	check(not bool(service.prepare_settlement(game_state, request, positive_durability_defeat).get("ok", false)), "defeat with positive village durability is rejected")
	check(snapshot_formal_state(game_state) == before, "outcome and durability conflicts produce no formal write")
	var valid_preparation := service.prepare_settlement(game_state, request, result)
	check(bool(valid_preparation.get("ok", false)), "valid result can still prepare after non-mutating rejection")
	var invalid_hp_plan: Dictionary = valid_preparation.get("value", {}).duplicate(true)
	invalid_hp_plan["runtime_hp_updates"][0]["current_hp"] = -1
	check(
		not game_state.validate_formation_defense_settlement_plan(invalid_hp_plan).is_empty(),
		"formal state validation rejects an out-of-range runtime HP update"
	)
	var inconsistent_down_plan: Dictionary = valid_preparation.get("value", {}).duplicate(true)
	inconsistent_down_plan["runtime_hp_updates"][0]["current_hp"] = 1
	inconsistent_down_plan["runtime_hp_updates"][0]["is_down"] = true
	check(
		not game_state.validate_formation_defense_settlement_plan(inconsistent_down_plan).is_empty(),
		"formal state validation rejects a down fact that disagrees with runtime HP"
	)
	check(snapshot_formal_state(game_state) == before, "invalid runtime HP facts produce no formal write")
	var tampered_plan: Dictionary = valid_preparation.get("value", {}).duplicate(true)
	tampered_plan["experience_per_character"] = 999
	check(not bool(service.apply_settlement(game_state, tampered_plan).get("ok", false)), "tampered prepared plan is rejected")
	check(snapshot_formal_state(game_state) == before, "tampered plan produces no formal write")
	check(bool(service.apply_settlement(game_state, valid_preparation.get("value", {})).get("ok", false)), "original validated plan can apply")
	var after := snapshot_formal_state(game_state)
	var conflicting_result := result.duplicate(true)
	conflicting_result["outcome"] = BattleContract.OUTCOME_DEFEAT
	check(not bool(service.prepare_settlement(game_state, request, conflicting_result).get("ok", false)), "failure after applied victory is rejected")
	check(snapshot_formal_state(game_state) == after, "conflicting terminal result cannot double settle")

	setup_forest_encounter(game_state)
	var new_request := build_settlement_request(game_state, "v2-8d-new-session")
	var new_service = SettlementService.new()
	check(bool(new_service.open_session(game_state, new_request).get("ok", false)), "a new session can open after an earlier session")
	var new_result := make_terminal_result(new_request, BattleContract.OUTCOME_VICTORY)
	var new_plan := new_service.prepare_settlement(game_state, new_request, new_result)
	check(bool(new_plan.get("ok", false)), "a new session can prepare normally")
	check(bool(new_service.apply_settlement(game_state, new_plan.get("value", {})).get("ok", false)), "a new session can settle normally")


func check_formal_ui_entry(game_state: Node) -> void:
	setup_forest_encounter(game_state)
	var before := snapshot_formal_state(game_state)
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	var coordinator = main.battle_preview_coordinator
	check(coordinator != null, "formal main scene owns the V2 route coordinator")
	check(coordinator.battle_router.current_mode == BattleRouter.MODE_V1, "fresh formal main scene still defaults to V1")
	check(coordinator.route_formal_encounter(&"forest_slime_pair"), "default formal encounter routes through V1")
	check(game_state.is_battle_active(), "default formal route starts the unchanged V1 battle")
	setup_forest_encounter(game_state)
	before = snapshot_formal_state(game_state)
	coordinator.battle_router.set_mode(BattleRouter.MODE_V2_SETTLEMENT_VALIDATION)
	check(coordinator.route_formal_encounter(&"forest_slime_pair"), "real unresolved encounter reaches the selected V2 settlement route")
	check(coordinator.settlement_confirmation_dialog.visible, "formal settlement route shows a warning before start")
	coordinator.confirm_settlement_route_start()
	await process_frame
	check(is_instance_valid(coordinator.v2_preview_host), "confirmed formal encounter creates the shared V2 host")
	check(coordinator.battle_router.active_session_mode == BattleRouter.MODE_V2_SETTLEMENT_VALIDATION, "formal UI route records the settlement session mode")
	check(coordinator.v2_preview_host.abort_preview(), "formal UI validation can be aborted through the public host control")
	await process_frame
	await process_frame
	check(coordinator.v2_preview_summary_panel.visible, "formal UI shows an abort summary")
	check(coordinator.last_v2_preview_summary_text.contains("未执行正式结算"), "formal UI abort summary states that no settlement ran")
	check(not game_state.can_move_to_next_expedition_node(), "formal UI abort cannot advance past its unresolved encounter")
	check(snapshot_formal_state(game_state) == before, "formal UI abort route preserves all formal data")
	coordinator.last_v2_preview_summary_text = "结果：胜利（旧回执）"
	coordinator.v2_preview_summary_label.text = coordinator.last_v2_preview_summary_text
	coordinator._handle_settlement_failure({"errors": ["受控结算拒绝"]})
	check(
		coordinator.v2_preview_summary_panel.visible,
		"settlement rejection displays a dedicated summary"
	)
	check(
		coordinator.last_v2_preview_summary_text.contains("结果：未执行正式结算") \
			and not coordinator.last_v2_preview_summary_text.contains("结果：胜利"),
		"settlement rejection cannot leave a stale victory summary"
	)
	main.queue_free()
	await process_frame


func check_formal_ui_failure(game_state: Node) -> void:
	setup_forest_encounter(game_state)
	var save_before := snapshot_file(FORMAL_SAVE_PATH)
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	var coordinator = main.battle_preview_coordinator
	coordinator.last_v2_preview_summary_text = "结果：胜利（旧回执）"
	coordinator.v2_preview_summary_label.text = coordinator.last_v2_preview_summary_text
	coordinator.v2_preview_summary_panel.visible = true
	coordinator.battle_router.set_mode(BattleRouter.MODE_V2_SETTLEMENT_VALIDATION)
	check(
		coordinator.route_formal_encounter(&"forest_slime_pair"),
		"real main route accepts the unattended failure fixture"
	)
	coordinator.confirm_settlement_route_start()
	await process_frame
	check(not coordinator.v2_preview_summary_panel.visible, "new formal battle hides the previous receipt")
	check(coordinator.last_v2_preview_summary_text.is_empty(), "new formal battle clears previous victory receipt text")
	check(
		is_instance_valid(coordinator.v2_preview_host),
		"real main failure route creates the shared V2 host"
	)
	var steps := 0
	while is_instance_valid(coordinator.v2_preview_host) \
			and not coordinator.v2_preview_summary_panel.visible \
			and steps < MAX_STEPS:
		coordinator.v2_preview_host.advance_for_test(STEP)
		steps += 1
	await process_frame
	check(
		coordinator.v2_preview_summary_panel.visible,
		"real main failure route displays a formal receipt"
	)
	check(
		coordinator.last_v2_preview_summary_text.contains("结果：失败"),
		"real main failure receipt displays failure rather than victory"
	)
	check(
		coordinator.last_v2_preview_summary_text.contains("V2原始判定：DEFEAT｜村庄耐久：0/10"),
		"real main failure receipt exposes the original outcome and durability"
	)
	check(
		coordinator.last_v2_preview_summary_text.contains("远征节点：未完成｜远征：已结束｜返回：村庄"),
		"real main failure receipt reports the unresolved node and ended expedition"
	)
	check(
		not game_state.is_expedition_active(),
		"real main failure prevents continuing to the next expedition node"
	)
	check(
		game_state.get_expedition_state().get("cleared_battle_node_ids", []).is_empty(),
		"real main failure does not clear the encounter node"
	)
	check(
		not game_state.move_to_next_expedition_node(),
		"real main failure cannot advance to another node"
	)
	check(
		snapshot_file(FORMAL_SAVE_PATH) == save_before,
		"real main failure still does not auto-save"
	)
	main.queue_free()
	await process_frame


func setup_forest_encounter(game_state: Node) -> void:
	game_state.start_new_game()
	check(game_state.start_expedition(3, 0), "fixture starts a formal expedition")
	var routed_encounters: Array[StringName] = []
	check(game_state.move_to_next_expedition_node(
		func(encounter_id: StringName) -> void:
			routed_encounters.append(encounter_id)
	), "fixture moves through the formal expedition API")
	check(routed_encounters == [&"forest_slime_pair"], "formal movement exposes the exact unresolved encounter to the router")
	check(not game_state.is_battle_active(), "fixture callback prevents an implicit V1 battle")
	check(game_state.get_current_node_encounter_id() == &"forest_slime_pair", "fixture is at the real forest encounter")


func setup_encounter_fixture(game_state: Node, node_id: StringName) -> void:
	game_state.start_new_game()
	check(game_state.start_expedition(3, 0), "isolated encounter fixture starts an expedition")
	var state: Dictionary = game_state.get_expedition_state()
	state["current_node_id"] = node_id
	state["furthest_node_id"] = node_id
	game_state.expedition_state = state


func build_settlement_request(
	game_state: Node,
	session_id: String,
	party_override: Array = []
) -> Dictionary:
	var party: Array = party_override.duplicate(true)
	if party.is_empty():
		party = FormalPartySource.build_party_snapshots(game_state).get("value", []).duplicate(true)
	var expedition: Dictionary = game_state.get_expedition_state()
	var creation := RequestBuilder.build_settlement_request(session_id, {
		"encounter_id": game_state.get_current_node_encounter_id(),
		"encounter_node_id": String(expedition.get("current_node_id", "")),
		"party_snapshots": party,
	})
	check(bool(creation.get("ok", false)), "%s request is valid" % session_id)
	return creation.get("value", {})


func make_terminal_result(request: Dictionary, outcome: String) -> Dictionary:
	var party_results: Array = []
	for member: Dictionary in request.get("party", []):
		party_results.append({
			"character_id": String(member.get("character_id", "")),
			"is_down": outcome == BattleContract.OUTCOME_DEFEAT,
			"remaining_hp": 0 if outcome == BattleContract.OUTCOME_DEFEAT else int(member.get("final_stats", {}).get("max_hp", 1)),
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
		"settlement_id": BattleContract.make_settlement_id(String(request.get("battle_session_id", ""))),
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


func run_host(request: Dictionary, commanded: bool, abort_immediately: bool) -> Dictionary:
	var host = PreviewHostScene.instantiate()
	root.add_child(host)
	await process_frame
	var results: Array[Dictionary] = []
	host.preview_finished.connect(func(result: Dictionary) -> void:
		results.append(result.duplicate(true))
	)
	var start_result: Dictionary = host.start_preview(request)
	check(bool(start_result.get("ok", false)), "real V2 settlement host starts")
	var command_clicks := 0
	if abort_immediately:
		check(host.abort_preview(), "real V2 settlement host aborts through its public entry")
	else:
		var controller = host.get_active_prototype()
		var last_command_time := -10.0
		var steps := 0
		while results.is_empty() and steps < MAX_STEPS:
			host.advance_for_test(STEP)
			if commanded and is_instance_valid(controller):
				if float(controller.battle_elapsed) - last_command_time >= 3.0:
					var target = choose_focus_target(controller)
					if is_instance_valid(target) and controller.handle_battlefield_pointer(
						target.position,
						MOUSE_BUTTON_LEFT
					):
						command_clicks += 1
						last_command_time = float(controller.battle_elapsed)
				issue_ready_ultimates(controller)
			steps += 1
	check(not results.is_empty(), "real V2 settlement host emits one terminal result")
	var result: Dictionary = results[0] if not results.is_empty() else {}
	var snapshot: Dictionary = host.get_last_terminal_debug_snapshot()
	var summary := {
		"result": result,
		"command_clicks": command_clicks,
		"ultimate_releases": int(snapshot.get("ultimate_release_sequence", 0)),
	}
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
	candidates.sort_custom(func(left, right) -> bool:
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
		if not is_instance_valid(character) or not character.is_alive \
				or not character.ultimate_ready \
				or controller.ultimate_targeting_character_id != &"":
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
		if is_instance_valid(enemy) and not enemy.is_dead \
				and not enemy.settlement_completed \
				and character.position.distance_to(enemy.position) <= cast_range + 0.0001:
			candidates.append(enemy)
	if candidates.is_empty():
		return {"valid": false, "position": Vector2.ZERO}
	if character.role_id == &"hunter":
		candidates.sort_custom(func(left, right) -> bool:
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
			if is_instance_valid(other) \
					and candidate.position.distance_to(other.position) <= radius:
				count += 1
		if count > best_count or (count == best_count and String(candidate.runtime_id) < String(best_enemy.runtime_id)):
			best_enemy = candidate
			best_count = count
	return {"valid": true, "position": best_enemy.position}


func snapshot_formal_state(game_state: Node) -> Dictionary:
	var experience: Dictionary = {}
	var levels: Dictionary = {}
	var injuries: Dictionary = {}
	var runtime_hp: Dictionary = {}
	for record: Dictionary in game_state.get_all_combat_characters():
		var character_id := StringName(record.get("character_id", &""))
		experience[character_id] = int(record.get("experience", 0))
		levels[character_id] = int(record.get("level", 1))
		injuries[character_id] = (
			"injured" if game_state.is_character_injured(character_id) else "healthy"
		)
		runtime_hp[character_id] = int(record.get("current_hp", 0))
	return {
		"experience": experience,
		"levels": levels,
		"injuries": injuries,
		"runtime_hp": runtime_hp,
		"resources": game_state.resources.duplicate(true),
		"items": game_state.stackable_item_inventory.duplicate(true),
		"equipment": game_state.equipment_inventory.duplicate(true),
		"expedition": game_state.get_expedition_state(),
		"statistics": game_state.statistics.duplicate(true),
		"pending_battle_result": game_state.pending_battle_result.duplicate(true),
		"last_battle_result": game_state.last_battle_result.duplicate(true),
		"boss_defeated": bool(game_state.boss_defeated),
		"save_error": String(game_state.save_system.last_error),
	}


func diff_summary(before: Dictionary, after: Dictionary) -> Dictionary:
	return {
		"experience_before": before.experience,
		"experience_after": after.experience,
		"injuries_before": before.injuries,
		"injuries_after": after.injuries,
		"expedition_before": before.expedition,
		"expedition_after": after.expedition,
		"resources_before": before.resources,
		"resources_after": after.resources,
	}


func character_experience(game_state: Node, character_id: StringName) -> int:
	for record: Dictionary in game_state.get_all_combat_characters():
		if StringName(record.get("character_id", &"")) == character_id:
			return int(record.get("experience", 0))
	return -1


func character_level(game_state: Node, character_id: StringName) -> int:
	for record: Dictionary in game_state.get_all_combat_characters():
		if StringName(record.get("character_id", &"")) == character_id:
			return int(record.get("level", 1))
	return -1


func snapshot_file(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_buffer(file.get_length()) if file != null else PackedByteArray()


func check(condition: bool, message: String) -> void:
	check_count += 1
	if condition:
		return
	failures.append(message)
	push_error("v2-8d: %s" % message)


func finish() -> void:
	if failures.is_empty():
		print("v2-8d formal settlement smoke ok (%d checks)" % check_count)
		quit(0)
		return
	push_error("v2-8d formal settlement smoke failed: %s" % "; ".join(failures))
	quit(1)

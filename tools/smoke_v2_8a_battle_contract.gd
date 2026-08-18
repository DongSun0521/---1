extends SceneTree

const BattleContract := preload("res://scripts/data/formation_defense_battle_contract.gd")
const BattleAdapter := preload("res://systems/formation_defense_battle_adapter.gd")
const PrototypeConfig := preload("res://prototype/formation_defense/data/formation_defense_config.gd")

const FORMAL_MAIN_SCENE := "res://features/main/main.tscn"
const FORMAL_BATTLE_SCENE := "res://features/battle/battle_view.tscn"
const PROTOTYPE_SCENE := "res://prototype/formation_defense/scenes/formation_defense_prototype.tscn"
const FORMAL_SAVE_PATH := "user://adventure_village_save.json"

var failures: Array[String] = []
var check_count := 0


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var game_state := root.get_node_or_null("/root/GameState")
	check(game_state != null, "formal GameState autoload remains available")
	if game_state == null:
		finish()
		return
	var formal_before := snapshot_formal_sources(game_state)
	var save_before := snapshot_file(FORMAL_SAVE_PATH)

	var source := make_formal_source()
	var creation := BattleAdapter.build_battle_request_snapshot(source)
	check(bool(creation.get("ok", false)), "legal formal snapshot creates a request")
	var request: Dictionary = creation.get("value", {})
	check(BattleContract.validate_request(request).is_empty(), "normalized request validates")
	check(request.contract_version == 1, "request exposes contract version 1")
	check(request.battle_session_id == "session-v2-8a-001", "request preserves the battle session ID")
	check(request.battle_id == "forest_slime_pair", "request preserves the formal encounter ID")
	check(request.random_seed == 2801, "request preserves the deterministic seed")
	check(request.party.size() == 2, "request accepts the current formal party size")
	check(request.party[0].character_id == "guard" and request.party[1].character_id == "mage", "party normalizes by formal slot")
	check(request.party[0].final_stats.max_hp == 150, "request contains resolved final combat stats")
	check(request.party[0].equipped_skill_ids == ["power_strike"], "request contains equipped skill IDs")
	check(request.party[0].ultimate_id == "ground_shock", "request contains the selected ultimate ID")

	var canonical_second := BattleAdapter.build_battle_request_snapshot(source)
	check(canonical_second.value == request, "identical input normalizes identically")
	var source_stats: Dictionary = source.party_snapshots[0].final_stats
	source_stats.max_hp = 999
	check(request.party[0].final_stats.max_hp == 150, "request is detached from later source mutation")
	request.party[0].final_stats.attack = 999
	check(source.party_snapshots[0].final_stats.attack == 18, "request mutation cannot affect source data")
	request = canonical_second.value

	var missing := make_formal_source()
	missing.erase("battle_session_id")
	check(not BattleAdapter.build_battle_request_snapshot(missing).ok, "missing session ID is rejected")
	var empty_party := make_formal_source()
	empty_party.party_snapshots = []
	check(not BattleAdapter.build_battle_request_snapshot(empty_party).ok, "empty party is rejected")
	var oversized_party := make_formal_source()
	oversized_party.party_snapshots.append(make_party_member("doctor", 2))
	oversized_party.party_snapshots.append(make_party_member("hunter", 3))
	oversized_party.party_snapshots.append(make_party_member("extra", 4))
	check(not BattleAdapter.build_battle_request_snapshot(oversized_party).ok, "party larger than the formal maximum is rejected")
	var duplicate_id := make_formal_source()
	duplicate_id.party_snapshots[1].character_id = "guard"
	check(not BattleAdapter.build_battle_request_snapshot(duplicate_id).ok, "duplicate character IDs are rejected")
	var empty_id := make_formal_source()
	empty_id.party_snapshots[0].character_id = ""
	check(not BattleAdapter.build_battle_request_snapshot(empty_id).ok, "empty character IDs are rejected")
	var invalid_nested_type := make_formal_source()
	invalid_nested_type.party_snapshots[0].final_stats = "not-a-dictionary"
	check(not BattleAdapter.build_battle_request_snapshot(invalid_nested_type).ok, "invalid nested types return validation errors")

	var node_source := make_formal_source()
	node_source["runtime_node"] = Node.new()
	check(not BattleAdapter.build_battle_request_snapshot(node_source).ok, "Node references are rejected before snapshotting")
	node_source.runtime_node.free()
	var callable_source := make_formal_source()
	callable_source["callback"] = Callable(self, "finish")
	check(not BattleAdapter.build_battle_request_snapshot(callable_source).ok, "Callable references are rejected before snapshotting")
	check(BattleContract.validate_pure_data(request).is_empty(), "normalized request contains pure deep-copyable data only")

	for outcome: String in BattleContract.VALID_OUTCOMES:
		var outcome_creation := BattleContract.create_result(make_result(outcome))
		check(bool(outcome_creation.ok), "%s result validates" % outcome)
	var result_creation := BattleContract.create_result(make_result(BattleContract.OUTCOME_VICTORY))
	var result: Dictionary = result_creation.value
	check(result.settlement_id == "formation-defense:v1:session-v2-8a-001", "result receives a deterministic settlement ID")
	check(BattleContract.validate_pure_data(result).is_empty(), "normalized result contains facts as pure data only")

	var reversed_result := make_result(BattleContract.OUTCOME_VICTORY)
	reversed_result.party_results.reverse()
	var settlement := BattleAdapter.build_settlement_input(request, reversed_result)
	check(bool(settlement.ok), "valid result crosses the settlement boundary")
	check(settlement.value.party_results_by_character_id.has("guard"), "settlement associates characters by stable ID")
	check(settlement.value.party_results_by_character_id.guard.remaining_hp == 80, "stable-ID association is independent of array order")
	check(not settlement.value.has("reward_ore") and not settlement.value.has("experience_reward"), "settlement input contains facts, not rewards or experience")

	var wrong_session := make_result(BattleContract.OUTCOME_VICTORY)
	wrong_session.battle_session_id = "other-session"
	check(not BattleAdapter.build_settlement_input(request, wrong_session).ok, "mismatched session IDs cannot settle")
	var wrong_character := make_result(BattleContract.OUTCOME_VICTORY)
	wrong_character.party_results[1].character_id = "hunter"
	check(not BattleAdapter.build_settlement_input(request, wrong_character).ok, "result character IDs must match the request")
	var reward_result := make_result(BattleContract.OUTCOME_VICTORY)
	reward_result["reward_ore"] = 99
	check(not BattleContract.create_result(reward_result).ok, "reward fields are outside the battle fact contract")
	var duplicate_result := make_result(BattleContract.OUTCOME_VICTORY)
	duplicate_result.party_results[1].character_id = "guard"
	check(not BattleContract.create_result(duplicate_result).ok, "duplicate result character IDs are rejected")
	var non_integer_durability := make_result(BattleContract.OUTCOME_VICTORY)
	non_integer_durability.village_durability.remaining = 7.0
	check(not BattleContract.create_result(non_integer_durability).ok, "durability requires exact integer facts")

	check(load(FORMAL_MAIN_SCENE) is PackedScene, "formal main scene still loads")
	check(load(FORMAL_BATTLE_SCENE) is PackedScene, "formal V1 battle scene still loads")
	check(load(PROTOTYPE_SCENE) is PackedScene, "formation defense scene still loads independently")
	var v2_config := PrototypeConfig.get_wave_battle_config(&"v2_7b_three_archetype_full_battle")
	check(int(v2_config.get("random_seed", 0)) == 2703, "frozen V2-7B seed is unchanged")
	check(is_equal_approx(PrototypeConfig.FINAL_HUNTER_ACTION_RANGE, 500.0), "frozen hunter range remains 500")
	check(is_equal_approx(PrototypeConfig.FINAL_MAGE_ACTION_RANGE, 450.0), "frozen mage range remains 450")
	check(adapter_sources_have_no_formal_runtime_access(), "contract and adapter do not access formal singletons")

	check(snapshot_formal_sources(game_state) == formal_before, "CharacterRoster and GameState remain unchanged")
	check(snapshot_file(FORMAL_SAVE_PATH) == save_before, "SaveSystem output file remains unchanged")
	finish()


func make_formal_source() -> Dictionary:
	return {
		"battle_session_id": "session-v2-8a-001",
		"encounter_id": "forest_slime_pair",
		"random_seed": 2801,
		"party_snapshots": [
			make_party_member("guard", 0),
			make_party_member("mage", 1),
		],
		"battle_config_ref": {
			"wave_config_id": "v2_7b_three_archetype_full_battle",
			"enemy_profile_ids": ["formation_guard", "charge", "rush_raider"],
		},
		"encounter_context": {
			"source_mode": "EXPEDITION",
			"encounter_node_id": "forest_edge",
		},
	}


func make_party_member(character_id: String, party_slot: int) -> Dictionary:
	var profession_id := "guard" if character_id == "guard" else "mage"
	return {
		"character_id": character_id,
		"display_name": "战士" if character_id == "guard" else "法师",
		"profession_id": profession_id,
		"role_display_name": "战士" if character_id == "guard" else "法师",
		"party_slot": party_slot,
		"final_stats": {
			"max_hp": 150 if character_id == "guard" else 80,
			"attack": 18 if character_id == "guard" else 28,
			"defense": 8 if character_id == "guard" else 2,
			"speed": 4,
			"attack_speed": 4.0,
			"crit_rate": 0.0,
			"crit_damage": 1.5,
		},
		"equipped_skill_ids": ["power_strike"] if character_id == "guard" else ["fireball"],
		"ultimate_id": "ground_shock" if character_id == "guard" else "arcane_blast",
		"battle_visual_id": character_id,
		"injury_state": "healthy",
	}


func make_result(outcome: String) -> Dictionary:
	return {
		"contract_version": BattleContract.CONTRACT_VERSION,
		"battle_session_id": "session-v2-8a-001",
		"battle_id": "forest_slime_pair",
		"outcome": outcome,
		"duration_seconds": 123.4,
		"village_durability": {"remaining": 7, "maximum": 10},
		"party_results": [
			make_party_result("guard", false, 80),
			make_party_result("mage", true, 0),
		],
		"battle_statistics": {
			"generated_enemies": 12,
			"defeated_enemies": 10,
			"leaked_enemies": 2,
			"waves_completed": 3,
		},
	}


func make_party_result(character_id: String, is_down: bool, remaining_hp: int) -> Dictionary:
	return {
		"character_id": character_id,
		"is_down": is_down,
		"remaining_hp": remaining_hp,
		"statistics": {
			"damage_dealt": 100,
			"damage_taken": 20,
			"healing_done": 0,
			"kills": 2,
			"ultimate_casts": 1,
		},
	}


func adapter_sources_have_no_formal_runtime_access() -> bool:
	for path: String in [
		"res://scripts/data/formation_defense_battle_contract.gd",
		"res://systems/formation_defense_battle_adapter.gd",
	]:
		var source := FileAccess.get_file_as_string(path)
		for token: String in [
			"/root/GameState",
			".character_roster",
			"save_game(",
			"load_game(",
			"SaveSystemScript",
		]:
			if source.contains(token):
				return false
	return true


func snapshot_formal_sources(game_state: Node) -> Dictionary:
	return {
		"roster": game_state.character_roster.to_dictionary(),
		"resources": game_state.resources.duplicate(true),
		"expedition_state": game_state.expedition_state.duplicate(true),
		"battle_state": game_state.battle_state.duplicate(true),
		"pending_battle_result": game_state.pending_battle_result.duplicate(true),
		"last_battle_result": game_state.last_battle_result.duplicate(true),
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
		print("v2-8a battle contract smoke ok (%d checks)" % check_count)
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)

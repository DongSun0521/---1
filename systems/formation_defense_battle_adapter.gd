class_name FormationDefenseBattleAdapter
extends RefCounted

const BattleContract := preload("res://scripts/data/formation_defense_battle_contract.gd")


## Pure boundary: the caller resolves CharacterRoster, equipment, traits, growth and
## village bonuses before calling this function. This adapter never reads a singleton.
static func build_battle_request_snapshot(formal_source: Dictionary) -> Dictionary:
	var purity_errors := BattleContract.validate_pure_data(formal_source, "formal_source")
	if not purity_errors.is_empty():
		return _failure(purity_errors)
	var party: Array = []
	var source_party = formal_source.get("party_snapshots", [])
	if source_party is Array:
		for raw_member: Variant in source_party:
			if not raw_member is Dictionary:
				party.append(raw_member)
				continue
			party.append({
				"character_id": raw_member.get("character_id", ""),
				"display_name": raw_member.get("display_name", ""),
				"profession_id": raw_member.get("profession_id", ""),
				"role_display_name": raw_member.get("role_display_name", ""),
				"party_slot": raw_member.get("party_slot", -1),
				"final_stats": _copy_container(raw_member.get("final_stats", {})),
				"equipped_skill_ids": _copy_container(raw_member.get("equipped_skill_ids", [])),
				"ultimate_id": raw_member.get("ultimate_id", ""),
				"battle_visual_id": raw_member.get("battle_visual_id", ""),
				"injury_state": raw_member.get("injury_state", ""),
			})
	var request_source := {
		"contract_version": BattleContract.CONTRACT_VERSION,
		"battle_session_id": formal_source.get("battle_session_id", ""),
		"battle_id": formal_source.get("encounter_id", ""),
		"random_seed": formal_source.get("random_seed", 0),
		"party": party,
		"battle_config_ref": _copy_container(formal_source.get("battle_config_ref", {})),
		"encounter_context": _copy_container(formal_source.get("encounter_context", {})),
	}
	return BattleContract.create_request(request_source)


## Pure boundary: this creates settlement input facts only. Reward, experience,
## progression and save writes remain the responsibility of formal systems.
static func build_settlement_input(request: Dictionary, result: Dictionary) -> Dictionary:
	var request_creation := BattleContract.create_request(request)
	if not bool(request_creation.get("ok", false)):
		return request_creation
	var result_creation := BattleContract.create_result(result)
	if not bool(result_creation.get("ok", false)):
		return result_creation

	var normalized_request: Dictionary = request_creation["value"]
	var normalized_result: Dictionary = result_creation["value"]
	var errors := PackedStringArray()
	if normalized_request["battle_session_id"] != normalized_result["battle_session_id"]:
		errors.append("request and result battle_session_id values do not match")
	if normalized_request["battle_id"] != normalized_result["battle_id"]:
		errors.append("request and result battle_id values do not match")

	var requested_ids: Array[String] = []
	for member: Dictionary in normalized_request["party"]:
		requested_ids.append(String(member["character_id"]))
	requested_ids.sort()
	var result_ids: Array[String] = []
	for member_result: Dictionary in normalized_result["party_results"]:
		result_ids.append(String(member_result["character_id"]))
	result_ids.sort()
	if requested_ids != result_ids:
		errors.append("result party character IDs must exactly match the request party")
	if not errors.is_empty():
		return _failure(errors)

	var party_results_by_character_id: Dictionary = {}
	for member_result: Dictionary in normalized_result["party_results"]:
		party_results_by_character_id[member_result["character_id"]] = member_result.duplicate(true)
	return {
		"ok": true,
		"errors": PackedStringArray(),
		"value": {
			"contract_version": BattleContract.CONTRACT_VERSION,
			"settlement_id": normalized_result["settlement_id"],
			"battle_session_id": normalized_result["battle_session_id"],
			"battle_id": normalized_result["battle_id"],
			"outcome": normalized_result["outcome"],
			"duration_seconds": normalized_result["duration_seconds"],
			"village_durability": normalized_result["village_durability"].duplicate(true),
			"party_results_by_character_id": party_results_by_character_id,
			"battle_statistics": normalized_result["battle_statistics"].duplicate(true),
			"encounter_context": normalized_request["encounter_context"].duplicate(true),
		},
	}


static func _failure(errors: PackedStringArray) -> Dictionary:
	return {
		"ok": false,
		"errors": errors,
		"value": {},
	}


static func _copy_container(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value

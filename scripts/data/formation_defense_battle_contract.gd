class_name FormationDefenseBattleContract
extends RefCounted

const Stage12Config := preload("res://scripts/data/stage12_balance_config.gd")

const CONTRACT_VERSION := 1
const MAX_PARTY_SIZE := Stage12Config.MAX_PARTY_SIZE

const OUTCOME_VICTORY := "VICTORY"
const OUTCOME_DEFEAT := "DEFEAT"
const OUTCOME_ABORTED := "ABORTED"
const VALID_OUTCOMES: Array[String] = [
	OUTCOME_VICTORY,
	OUTCOME_DEFEAT,
	OUTCOME_ABORTED,
]

const REQUEST_KEYS: Array[String] = [
	"contract_version",
	"battle_session_id",
	"battle_id",
	"random_seed",
	"party",
	"battle_config_ref",
	"encounter_context",
]
const PARTY_MEMBER_KEYS: Array[String] = [
	"character_id",
	"display_name",
	"profession_id",
	"role_display_name",
	"party_slot",
	"final_stats",
	"equipped_skill_ids",
	"ultimate_id",
	"battle_visual_id",
	"injury_state",
]
const FINAL_STAT_KEYS: Array[String] = [
	"max_hp",
	"attack",
	"defense",
	"speed",
	"attack_speed",
	"crit_rate",
	"crit_damage",
]
const BATTLE_CONFIG_REF_KEYS: Array[String] = [
	"wave_config_id",
	"enemy_profile_ids",
]
const ENCOUNTER_CONTEXT_KEYS: Array[String] = [
	"source_mode",
	"encounter_node_id",
]

const RESULT_KEYS: Array[String] = [
	"contract_version",
	"battle_session_id",
	"battle_id",
	"settlement_id",
	"outcome",
	"duration_seconds",
	"village_durability",
	"party_results",
	"battle_statistics",
]
const DURABILITY_KEYS: Array[String] = ["remaining", "maximum"]
const PARTY_RESULT_KEYS: Array[String] = [
	"character_id",
	"is_down",
	"remaining_hp",
	"statistics",
]
const CHARACTER_STATISTIC_KEYS: Array[String] = [
	"damage_dealt",
	"damage_taken",
	"healing_done",
	"kills",
	"ultimate_casts",
]
const BATTLE_STATISTIC_KEYS: Array[String] = [
	"generated_enemies",
	"defeated_enemies",
	"leaked_enemies",
	"waves_completed",
]


static func create_request(source: Dictionary) -> Dictionary:
	var errors := validate_request(source)
	if not errors.is_empty():
		return _failure(errors)
	return {
		"ok": true,
		"errors": PackedStringArray(),
		"value": _normalize_request_unchecked(source),
	}


static func validate_request(request: Dictionary) -> PackedStringArray:
	var errors := validate_pure_data(request)
	_validate_exact_keys(request, REQUEST_KEYS, "request", errors)
	if not errors.is_empty():
		return errors

	if typeof(request.get("contract_version")) != TYPE_INT \
			or int(request.get("contract_version", -1)) != CONTRACT_VERSION:
		errors.append("request.contract_version must be %d" % CONTRACT_VERSION)
	_validate_nonempty_identifier(request.get("battle_session_id"), "request.battle_session_id", errors)
	_validate_nonempty_identifier(request.get("battle_id"), "request.battle_id", errors)
	if typeof(request.get("random_seed")) != TYPE_INT:
		errors.append("request.random_seed must be an integer")

	var party = request.get("party")
	if not party is Array:
		errors.append("request.party must be an array")
	else:
		_validate_party(party, errors)

	var config_ref = request.get("battle_config_ref")
	if not config_ref is Dictionary:
		errors.append("request.battle_config_ref must be a dictionary")
	else:
		_validate_battle_config_ref(config_ref, errors)

	var context = request.get("encounter_context")
	if not context is Dictionary:
		errors.append("request.encounter_context must be a dictionary")
	else:
		_validate_exact_keys(context, ENCOUNTER_CONTEXT_KEYS, "request.encounter_context", errors)
		_validate_nonempty_identifier(context.get("source_mode"), "request.encounter_context.source_mode", errors)
		if not _is_identifier(context.get("encounter_node_id")):
			errors.append("request.encounter_context.encounter_node_id must be a string")
	return errors


static func create_result(source: Dictionary) -> Dictionary:
	var prepared := source.duplicate(true)
	if not prepared.has("settlement_id") and _is_nonempty_identifier(prepared.get("battle_session_id")):
		prepared["settlement_id"] = make_settlement_id(String(prepared["battle_session_id"]))
	var errors := validate_result(prepared)
	if not errors.is_empty():
		return _failure(errors)
	return {
		"ok": true,
		"errors": PackedStringArray(),
		"value": _normalize_result_unchecked(prepared),
	}


static func validate_result(result: Dictionary) -> PackedStringArray:
	var errors := validate_pure_data(result)
	_validate_exact_keys(result, RESULT_KEYS, "result", errors)
	if not errors.is_empty():
		return errors

	if typeof(result.get("contract_version")) != TYPE_INT \
			or int(result.get("contract_version", -1)) != CONTRACT_VERSION:
		errors.append("result.contract_version must be %d" % CONTRACT_VERSION)
	_validate_nonempty_identifier(result.get("battle_session_id"), "result.battle_session_id", errors)
	_validate_nonempty_identifier(result.get("battle_id"), "result.battle_id", errors)
	_validate_nonempty_identifier(result.get("settlement_id"), "result.settlement_id", errors)
	if String(result.get("outcome", "")) not in VALID_OUTCOMES:
		errors.append("result.outcome must be VICTORY, DEFEAT, or ABORTED")
	if not _is_number(result.get("duration_seconds")) or float(result.get("duration_seconds", -1.0)) < 0.0:
		errors.append("result.duration_seconds must be a non-negative number")

	var durability = result.get("village_durability")
	if not durability is Dictionary:
		errors.append("result.village_durability must be a dictionary")
	else:
		_validate_exact_keys(durability, DURABILITY_KEYS, "result.village_durability", errors)
		var remaining := int(durability.get("remaining", -1))
		var maximum := int(durability.get("maximum", 0))
		if typeof(durability.get("remaining")) != TYPE_INT \
				or typeof(durability.get("maximum")) != TYPE_INT \
				or maximum <= 0 \
				or remaining < 0 \
				or remaining > maximum:
			errors.append("result.village_durability must satisfy 0 <= remaining <= maximum")

	var party_results = result.get("party_results")
	if not party_results is Array:
		errors.append("result.party_results must be an array")
	else:
		_validate_party_results(party_results, errors)

	var statistics = result.get("battle_statistics")
	if not statistics is Dictionary:
		errors.append("result.battle_statistics must be a dictionary")
	else:
		_validate_nonnegative_integer_dictionary(
			statistics,
			BATTLE_STATISTIC_KEYS,
			"result.battle_statistics",
			errors
		)
	return errors


static func validate_pure_data(value: Variant, path: String = "value") -> PackedStringArray:
	var errors := PackedStringArray()
	_collect_pure_data_errors(value, path, errors)
	return errors


static func make_settlement_id(battle_session_id: String) -> String:
	return "formation-defense:v%d:%s" % [CONTRACT_VERSION, battle_session_id]


static func _normalize_request_unchecked(source: Dictionary) -> Dictionary:
	var party: Array = []
	for raw_member: Dictionary in source["party"]:
		party.append({
			"character_id": String(raw_member["character_id"]),
			"display_name": String(raw_member["display_name"]),
			"profession_id": String(raw_member["profession_id"]),
			"role_display_name": String(raw_member["role_display_name"]),
			"party_slot": int(raw_member["party_slot"]),
			"final_stats": _normalize_final_stats(raw_member["final_stats"]),
			"equipped_skill_ids": _normalize_identifier_array(raw_member["equipped_skill_ids"]),
			"ultimate_id": String(raw_member["ultimate_id"]),
			"battle_visual_id": String(raw_member["battle_visual_id"]),
			"injury_state": String(raw_member["injury_state"]),
		})
	party.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["party_slot"]) == int(b["party_slot"]):
			return String(a["character_id"]) < String(b["character_id"])
		return int(a["party_slot"]) < int(b["party_slot"])
	)
	var config_ref: Dictionary = source["battle_config_ref"]
	var context: Dictionary = source["encounter_context"]
	return {
		"contract_version": CONTRACT_VERSION,
		"battle_session_id": String(source["battle_session_id"]),
		"battle_id": String(source["battle_id"]),
		"random_seed": int(source["random_seed"]),
		"party": party,
		"battle_config_ref": {
			"wave_config_id": String(config_ref["wave_config_id"]),
			"enemy_profile_ids": _normalize_identifier_array(config_ref["enemy_profile_ids"]),
		},
		"encounter_context": {
			"source_mode": String(context["source_mode"]),
			"encounter_node_id": String(context["encounter_node_id"]),
		},
	}


static func _normalize_result_unchecked(source: Dictionary) -> Dictionary:
	var party_results: Array = []
	for raw_result: Dictionary in source["party_results"]:
		var raw_statistics: Dictionary = raw_result["statistics"]
		party_results.append({
			"character_id": String(raw_result["character_id"]),
			"is_down": bool(raw_result["is_down"]),
			"remaining_hp": int(raw_result["remaining_hp"]),
			"statistics": _copy_integer_fields(raw_statistics, CHARACTER_STATISTIC_KEYS),
		})
	party_results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["character_id"]) < String(b["character_id"])
	)
	var durability: Dictionary = source["village_durability"]
	var battle_statistics: Dictionary = source["battle_statistics"]
	return {
		"contract_version": CONTRACT_VERSION,
		"battle_session_id": String(source["battle_session_id"]),
		"battle_id": String(source["battle_id"]),
		"settlement_id": String(source["settlement_id"]),
		"outcome": String(source["outcome"]),
		"duration_seconds": float(source["duration_seconds"]),
		"village_durability": {
			"remaining": int(durability["remaining"]),
			"maximum": int(durability["maximum"]),
		},
		"party_results": party_results,
		"battle_statistics": _copy_integer_fields(battle_statistics, BATTLE_STATISTIC_KEYS),
	}


static func _validate_party(party: Array, errors: PackedStringArray) -> void:
	if party.is_empty() or party.size() > MAX_PARTY_SIZE:
		errors.append("request.party must contain 1 to %d members" % MAX_PARTY_SIZE)
	var character_ids: Array[String] = []
	var party_slots: Array[int] = []
	for index: int in range(party.size()):
		var member = party[index]
		var path := "request.party[%d]" % index
		if not member is Dictionary:
			errors.append("%s must be a dictionary" % path)
			continue
		_validate_exact_keys(member, PARTY_MEMBER_KEYS, path, errors)
		_validate_nonempty_identifier(member.get("character_id"), path + ".character_id", errors)
		_validate_nonempty_identifier(member.get("display_name"), path + ".display_name", errors)
		_validate_nonempty_identifier(member.get("profession_id"), path + ".profession_id", errors)
		_validate_nonempty_identifier(member.get("role_display_name"), path + ".role_display_name", errors)
		var character_id := String(member.get("character_id", ""))
		if not character_id.is_empty() and character_id in character_ids:
			errors.append("request.party character_id values must be unique")
		character_ids.append(character_id)
		if typeof(member.get("party_slot")) != TYPE_INT:
			errors.append("%s.party_slot must be an integer" % path)
		else:
			var party_slot := int(member["party_slot"])
			if party_slot < 0 or party_slot >= MAX_PARTY_SIZE:
				errors.append("%s.party_slot is outside the formal party range" % path)
			elif party_slot in party_slots:
				errors.append("request.party party_slot values must be unique")
			party_slots.append(party_slot)
		_validate_final_stats(member.get("final_stats"), path + ".final_stats", errors)
		_validate_identifier_array(member.get("equipped_skill_ids"), path + ".equipped_skill_ids", errors, true)
		if not _is_identifier(member.get("ultimate_id")):
			errors.append("%s.ultimate_id must be a string" % path)
		if not _is_identifier(member.get("battle_visual_id")):
			errors.append("%s.battle_visual_id must be a string" % path)
		_validate_nonempty_identifier(member.get("injury_state"), path + ".injury_state", errors)


static func _validate_final_stats(value: Variant, path: String, errors: PackedStringArray) -> void:
	if not value is Dictionary:
		errors.append("%s must be a dictionary" % path)
		return
	_validate_exact_keys(value, FINAL_STAT_KEYS, path, errors)
	for stat_id: String in FINAL_STAT_KEYS:
		if not _is_number(value.get(stat_id)):
			errors.append("%s.%s must be numeric" % [path, stat_id])
	if _is_number(value.get("max_hp")) and int(value.get("max_hp", 0)) <= 0:
		errors.append("%s.max_hp must be positive" % path)
	for stat_id: String in ["attack", "defense", "speed", "attack_speed"]:
		if _is_number(value.get(stat_id)) and float(value.get(stat_id, -1.0)) < 0.0:
			errors.append("%s.%s must be non-negative" % [path, stat_id])
	if _is_number(value.get("crit_rate")):
		var crit_rate := float(value["crit_rate"])
		if crit_rate < 0.0 or crit_rate > 1.0:
			errors.append("%s.crit_rate must be between 0 and 1" % path)
	if _is_number(value.get("crit_damage")) and float(value["crit_damage"]) < 0.0:
		errors.append("%s.crit_damage must be non-negative" % path)


static func _validate_battle_config_ref(value: Dictionary, errors: PackedStringArray) -> void:
	_validate_exact_keys(value, BATTLE_CONFIG_REF_KEYS, "request.battle_config_ref", errors)
	_validate_nonempty_identifier(value.get("wave_config_id"), "request.battle_config_ref.wave_config_id", errors)
	_validate_identifier_array(
		value.get("enemy_profile_ids"),
		"request.battle_config_ref.enemy_profile_ids",
		errors,
		false
	)


static func _validate_party_results(party_results: Array, errors: PackedStringArray) -> void:
	if party_results.is_empty() or party_results.size() > MAX_PARTY_SIZE:
		errors.append("result.party_results must contain 1 to %d members" % MAX_PARTY_SIZE)
	var character_ids: Array[String] = []
	for index: int in range(party_results.size()):
		var character_result = party_results[index]
		var path := "result.party_results[%d]" % index
		if not character_result is Dictionary:
			errors.append("%s must be a dictionary" % path)
			continue
		_validate_exact_keys(character_result, PARTY_RESULT_KEYS, path, errors)
		_validate_nonempty_identifier(character_result.get("character_id"), path + ".character_id", errors)
		var character_id := String(character_result.get("character_id", ""))
		if not character_id.is_empty() and character_id in character_ids:
			errors.append("result.party_results character_id values must be unique")
		character_ids.append(character_id)
		if typeof(character_result.get("is_down")) != TYPE_BOOL:
			errors.append("%s.is_down must be a boolean" % path)
		if typeof(character_result.get("remaining_hp")) != TYPE_INT \
				or int(character_result.get("remaining_hp", -1)) < 0:
			errors.append("%s.remaining_hp must be a non-negative integer" % path)
		var statistics = character_result.get("statistics")
		if not statistics is Dictionary:
			errors.append("%s.statistics must be a dictionary" % path)
		else:
			_validate_nonnegative_integer_dictionary(
				statistics,
				CHARACTER_STATISTIC_KEYS,
				path + ".statistics",
				errors
			)


static func _validate_nonnegative_integer_dictionary(
	value: Dictionary,
	keys: Array[String],
	path: String,
	errors: PackedStringArray
) -> void:
	_validate_exact_keys(value, keys, path, errors)
	for key: String in keys:
		if typeof(value.get(key)) != TYPE_INT or int(value.get(key, -1)) < 0:
			errors.append("%s.%s must be a non-negative integer" % [path, key])


static func _validate_identifier_array(
	value: Variant,
	path: String,
	errors: PackedStringArray,
	allow_empty: bool
) -> void:
	if not value is Array:
		errors.append("%s must be an array" % path)
		return
	if not allow_empty and value.is_empty():
		errors.append("%s must not be empty" % path)
	var identifiers: Array[String] = []
	for index: int in range(value.size()):
		var identifier = value[index]
		_validate_nonempty_identifier(identifier, "%s[%d]" % [path, index], errors)
		var normalized := String(identifier)
		if not normalized.is_empty() and normalized in identifiers:
			errors.append("%s values must be unique" % path)
		identifiers.append(normalized)


static func _validate_exact_keys(
	value: Dictionary,
	expected_keys: Array[String],
	path: String,
	errors: PackedStringArray
) -> void:
	for expected_key: String in expected_keys:
		if not value.has(expected_key):
			errors.append("%s.%s is required" % [path, expected_key])
	for raw_key: Variant in value.keys():
		var key := String(raw_key)
		if key not in expected_keys:
			errors.append("%s.%s is not part of contract v%d" % [path, key, CONTRACT_VERSION])


static func _validate_nonempty_identifier(
	value: Variant,
	path: String,
	errors: PackedStringArray
) -> void:
	if not _is_nonempty_identifier(value):
		errors.append("%s must be a non-empty string" % path)


static func _collect_pure_data_errors(
	value: Variant,
	path: String,
	errors: PackedStringArray
) -> void:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME:
			return
		TYPE_ARRAY:
			for index: int in range(value.size()):
				_collect_pure_data_errors(value[index], "%s[%d]" % [path, index], errors)
		TYPE_DICTIONARY:
			for key: Variant in value.keys():
				if not _is_identifier(key):
					errors.append("%s contains a non-string dictionary key" % path)
					continue
				_collect_pure_data_errors(value[key], "%s.%s" % [path, String(key)], errors)
		TYPE_CALLABLE:
			errors.append("%s contains a Callable" % path)
		TYPE_SIGNAL:
			errors.append("%s contains a Signal" % path)
		TYPE_OBJECT:
			errors.append("%s contains a runtime Object or Node reference" % path)
		_:
			errors.append("%s contains unsupported non-data type %s" % [path, type_string(typeof(value))])


static func _normalize_final_stats(value: Dictionary) -> Dictionary:
	return {
		"max_hp": int(value["max_hp"]),
		"attack": int(value["attack"]),
		"defense": int(value["defense"]),
		"speed": int(value["speed"]),
		"attack_speed": float(value["attack_speed"]),
		"crit_rate": float(value["crit_rate"]),
		"crit_damage": float(value["crit_damage"]),
	}


static func _normalize_identifier_array(value: Array) -> Array:
	var normalized: Array = []
	for identifier: Variant in value:
		normalized.append(String(identifier))
	return normalized


static func _copy_integer_fields(value: Dictionary, keys: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	for key: String in keys:
		result[key] = int(value[key])
	return result


static func _is_identifier(value: Variant) -> bool:
	return typeof(value) in [TYPE_STRING, TYPE_STRING_NAME]


static func _is_nonempty_identifier(value: Variant) -> bool:
	return _is_identifier(value) and not String(value).strip_edges().is_empty()


static func _is_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT]


static func _failure(errors: PackedStringArray) -> Dictionary:
	return {
		"ok": false,
		"errors": errors,
		"value": {},
	}

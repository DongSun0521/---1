class_name FormationDefenseFormalPartySource
extends RefCounted

const CharacterEnums := preload("res://scripts/data/character_enums.gd")
const ProfessionCompatibility := preload(
	"res://systems/formation_defense_profession_compatibility.gd"
)
const StatScaleAdapter := preload(
	"res://systems/formation_defense_stat_scale_adapter.gd"
)


## Formal-side read boundary. Only this method reads CharacterRoster-backed GameState
## APIs; every downstream layer receives a detached pure-data copy.
static func build_party_snapshots(formal_game_state: Object) -> Dictionary:
	if formal_game_state == null:
		return _failure("GameState不可用，无法读取正式战斗队伍")
	for method_name: StringName in [
		&"get_character_ids",
		&"get_roster_character",
		&"get_final_combat_stats",
		&"get_profession_display_name",
	]:
		if not formal_game_state.has_method(method_name):
			return _failure("正式队伍读取API缺失：%s" % String(method_name))
	var party_ids: Array = formal_game_state.call("get_character_ids")
	if party_ids.is_empty():
		return _failure("正式战斗队伍为空，V2预览未启动")
	var records: Array[Dictionary] = []
	for raw_character_id: Variant in party_ids:
		var character_id := StringName(raw_character_id)
		var roster_record: Dictionary = formal_game_state.call(
			"get_roster_character", character_id
		)
		var combat_data = roster_record.get("combat_data", {})
		if not combat_data is Dictionary:
			combat_data = {}
		records.append({
			"character_id": character_id,
			"character_type": int(roster_record.get("character_type", -1)),
			"display_name": String(roster_record.get("display_name", "")),
			"profession_id": StringName(combat_data.get("profession_id", &"")),
			"role_display_name": String(formal_game_state.call(
				"get_profession_display_name",
				StringName(combat_data.get("profession_id", &""))
			)),
			"party_slot": int(combat_data.get("party_slot", -1)),
			"is_in_party": bool(combat_data.get("is_in_party", false)),
			"final_stats": formal_game_state.call(
				"get_final_combat_stats", character_id
			).duplicate(true),
			"equipped_skill_ids": combat_data.get("skill_ids", []).duplicate(true),
			"battle_visual_id": StringName(combat_data.get("battle_visual_id", &"")),
			"injury_state": StringName(combat_data.get("injury_state", &"healthy")),
		})
	return build_party_snapshots_from_records(records)


static func build_party_snapshots_from_records(records: Array) -> Dictionary:
	if records.is_empty() or records.size() > 4:
		return _failure("正式战斗队伍必须包含1～4名角色")
	var members: Array[Dictionary] = []
	var character_ids: Dictionary = {}
	var party_slots: Dictionary = {}
	for raw_record: Variant in records:
		if not raw_record is Dictionary:
			return _failure("正式队伍记录必须是字典")
		var record: Dictionary = raw_record
		var character_id := StringName(record.get("character_id", &""))
		var party_slot := int(record.get("party_slot", -1))
		var profession_id := StringName(record.get("profession_id", &""))
		if character_id == &"":
			return _failure("正式队伍包含空角色ID")
		if character_ids.has(character_id):
			return _failure("正式队伍包含重复角色ID：%s" % String(character_id))
		if int(record.get("character_type", -1)) \
				!= CharacterEnums.CharacterType.COMBAT:
			return _failure("生活角色不能进入V2战斗队伍：%s" % String(character_id))
		if not bool(record.get("is_in_party", false)):
			return _failure("非出战角色不能进入V2战斗队伍：%s" % String(character_id))
		if party_slot < 0 or party_slot >= 4 or party_slots.has(party_slot):
			return _failure("正式队伍槽位非法或重复")
		var compatibility := ProfessionCompatibility.get_compatibility(profession_id)
		if compatibility.is_empty():
			return _failure("V2不支持正式职业：%s" % String(profession_id))
		var final_stats = record.get("final_stats", {})
		if not final_stats is Dictionary:
			return _failure("正式最终属性缺失：%s" % String(character_id))
		var scale_creation := StatScaleAdapter.adapt_final_stats(
			character_id,
			profession_id,
			StringName(compatibility.get("v2_role_id", &"")),
			final_stats,
			float(compatibility.get("action_range", 0.0))
		)
		if not bool(scale_creation.get("ok", false)):
			return scale_creation
		var scale_value: Dictionary = scale_creation.get("value", {})
		var member := {
			"character_id": character_id,
			"display_name": String(record.get("display_name", "")),
			"profession_id": profession_id,
			"party_slot": party_slot,
			"final_stats": scale_value.get("final_stats", {}).duplicate(true),
			"equipped_skill_ids": record.get("equipped_skill_ids", []).duplicate(true),
			"ultimate_id": compatibility.get("ultimate_id", &""),
			"battle_visual_id": record.get("battle_visual_id", &""),
		}
		var runtime_check := ProfessionCompatibility.build_runtime_party([member])
		if not bool(runtime_check.get("ok", false)):
			return runtime_check
		members.append({
			"character_id": String(character_id),
			"display_name": String(record.get("display_name", "")),
			"profession_id": String(profession_id),
			"role_display_name": String(record.get("role_display_name", profession_id)),
			"party_slot": party_slot,
			# final_stats is the V2-ready contract value. The formal final values and
			# conversion report stay outside the V2-8A contract for debug only.
			"final_stats": scale_value.get("final_stats", {}).duplicate(true),
			"formal_final_stats": final_stats.duplicate(true),
			"stat_scale_report": scale_value.get("report", {}).duplicate(true),
			"equipped_skill_ids": record.get("equipped_skill_ids", []).duplicate(true),
			"ultimate_id": String(compatibility.get("ultimate_id", &"")),
			"battle_visual_id": String(record.get("battle_visual_id", &"")),
			"injury_state": String(record.get("injury_state", &"healthy")),
		})
		character_ids[character_id] = true
		party_slots[party_slot] = true
	members.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left["party_slot"]) < int(right["party_slot"])
	)
	return {
		"ok": true,
		"errors": PackedStringArray(),
		"value": members.duplicate(true),
	}


static func _failure(message: String) -> Dictionary:
	return {
		"ok": false,
		"errors": PackedStringArray([message]),
		"value": [],
	}

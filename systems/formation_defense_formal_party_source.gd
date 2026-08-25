class_name FormationDefenseFormalPartySource
extends RefCounted

const CharacterEnums := preload("res://scripts/data/character_enums.gd")
const ProfessionCompatibility := preload(
	"res://systems/formation_defense_profession_compatibility.gd"
)
const StatScaleAdapter := preload(
	"res://systems/formation_defense_stat_scale_adapter.gd"
)
const CharacterDatabaseScript := preload(
	"res://scripts/data/character_database.gd"
)
const CharacterRosterScript := preload(
	"res://systems/character_roster.gd"
)
const Stage12Config := preload(
	"res://scripts/data/stage12_balance_config.gd"
)

const DEBUG_LEVEL_CHARACTER_ID_BY_FORMAL_ID := {
	&"guard": &"v2_8g_lv50_guard",
	&"hunter": &"v2_8g_lv50_ranger",
	&"mage": &"v2_8g_lv50_mage",
	&"doctor": &"v2_8g_lv50_healer",
}


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


## Debug-only pure-data fixture. It deliberately creates a detached CharacterRoster
## so the level growth and final-stat calculation follow the same formal data chain
## without reading or impersonating the player's live CharacterRoster.
static func build_debug_level_party_snapshots(
	level: int = Stage12Config.COMBAT_MAX_LEVEL
) -> Dictionary:
	if level < 1 or level > Stage12Config.COMBAT_MAX_LEVEL:
		return _failure("Debug验证队伍等级超出正式成长范围")
	var database = CharacterDatabaseScript.new()
	var detached_roster = CharacterRosterScript.new()
	detached_roster.initialize_defaults(database)
	var records: Array[Dictionary] = []
	var formal_ids: Array[StringName] = database.get_party_order()
	for party_slot: int in range(formal_ids.size()):
		var formal_character_id := formal_ids[party_slot]
		var definition = database.get_character_definition(formal_character_id)
		var detached_record = detached_roster.get_character(formal_character_id)
		if definition == null or detached_record == null:
			return _failure("Debug验证队伍缺少正式角色定义")
		var details: Dictionary = detached_record.combat_data.calculate_final_stat_details(
			level,
			{},
			{},
			{},
			{}
		)
		var final_stats: Dictionary = {}
		for stat_id: String in details.keys():
			final_stats[stat_id] = details[stat_id].get("final", 0)
		records.append({
			"character_id": DEBUG_LEVEL_CHARACTER_ID_BY_FORMAL_ID[formal_character_id],
			"character_type": CharacterEnums.CharacterType.COMBAT,
			"display_name": "Lv.%d %s" % [level, String(definition.display_name)],
			"profession_id": definition.profession_id,
			"role_display_name": database.get_profession_display_name(
				definition.profession_id
			),
			"party_slot": party_slot,
			"is_in_party": true,
			"final_stats": final_stats,
			"equipped_skill_ids": definition.skill_ids.duplicate(),
			"battle_visual_id": definition.battle_visual_id,
			"injury_state": &"healthy",
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

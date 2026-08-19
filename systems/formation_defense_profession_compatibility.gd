class_name FormationDefenseProfessionCompatibility
extends RefCounted

const COMPATIBILITY_SOURCE := "V2职业兼容能力（非正式技能效果接入）"
const DEPLOYMENT_SLOTS_BY_PARTY_SLOT: Array[StringName] = [
	&"middle_c4",
	&"top_c4",
	&"bottom_c2",
	&"middle_c2",
]

const PROFESSION_COMPATIBILITY := {
	&"guard": {
		"v2_role_id": &"guard",
		"damage_source_type": &"MELEE",
		"ultimate_id": &"ground_shock",
		"action_range": 82.0,
		"block_capacity": 2,
		"body_color": Color(0.35, 0.68, 1.0, 1.0),
	},
	&"ranger": {
		"v2_role_id": &"hunter",
		"damage_source_type": &"RANGED",
		"ultimate_id": &"precision_snipe",
		"action_range": 500.0,
		"block_capacity": 0,
		"body_color": Color(0.45, 0.90, 0.55, 1.0),
	},
	&"mage": {
		"v2_role_id": &"mage",
		"damage_source_type": &"RANGED",
		"ultimate_id": &"arcane_blast",
		"action_range": 450.0,
		"block_capacity": 0,
		"body_color": Color(0.76, 0.52, 1.0, 1.0),
	},
	&"healer": {
		"v2_role_id": &"doctor",
		"damage_source_type": &"UNSPECIFIED",
		"ultimate_id": &"group_heal",
		"action_range": 330.0,
		"block_capacity": 0,
		"body_color": Color(0.40, 0.94, 0.86, 1.0),
	},
}


static func has_profession(profession_id: StringName) -> bool:
	return PROFESSION_COMPATIBILITY.has(profession_id)


static func get_compatibility(profession_id: StringName) -> Dictionary:
	return PROFESSION_COMPATIBILITY.get(profession_id, {}).duplicate(true)


static func get_v2_role_id(profession_id: StringName) -> StringName:
	return StringName(
		PROFESSION_COMPATIBILITY.get(profession_id, {}).get("v2_role_id", &"")
	)


static func get_action_range(profession_id: StringName) -> float:
	return float(
		PROFESSION_COMPATIBILITY.get(profession_id, {}).get("action_range", 0.0)
	)


static func get_deployment_slot(party_slot: int) -> StringName:
	if party_slot < 0 or party_slot >= DEPLOYMENT_SLOTS_BY_PARTY_SLOT.size():
		return &""
	return DEPLOYMENT_SLOTS_BY_PARTY_SLOT[party_slot]


## The contract carries a V2-ready attack rate after formal-to-V2 scale
## adaptation. It is not the raw V1 attack_speed attribute.
static func v2_attack_rate_to_action_interval(attack_rate: float) -> float:
	if is_nan(attack_rate) or is_inf(attack_rate) or attack_rate <= 0.0:
		return -1.0
	return 1.0 / attack_rate


static func build_runtime_party(party: Array) -> Dictionary:
	if party.is_empty() or party.size() > DEPLOYMENT_SLOTS_BY_PARTY_SLOT.size():
		return _failure("正式V2队伍必须包含1～4名角色")
	var definitions: Array[Dictionary] = []
	var character_ids: Dictionary = {}
	var party_slots: Dictionary = {}
	for raw_member: Variant in party:
		if not raw_member is Dictionary:
			return _failure("正式V2队伍成员必须是纯数据字典")
		var member: Dictionary = raw_member
		var character_id := StringName(member.get("character_id", &""))
		var profession_id := StringName(member.get("profession_id", &""))
		var party_slot := int(member.get("party_slot", -1))
		if character_id == &"" or character_ids.has(character_id):
			return _failure("正式V2角色ID为空或重复")
		if party_slot < 0 or party_slot >= DEPLOYMENT_SLOTS_BY_PARTY_SLOT.size() \
				or party_slots.has(party_slot):
			return _failure("正式V2队伍槽位非法或重复")
		var compatibility := get_compatibility(profession_id)
		if compatibility.is_empty():
			return _failure("V2不支持正式职业：%s" % String(profession_id))
		if StringName(member.get("ultimate_id", &"")) != StringName(
			compatibility.get("ultimate_id", &"")
		):
			return _failure("正式角色的大招兼容映射不一致：%s" % String(character_id))
		var final_stats = member.get("final_stats", {})
		if not final_stats is Dictionary:
			return _failure("正式角色最终属性不是字典：%s" % String(character_id))
		var numeric_error := _validate_final_stats(final_stats, character_id)
		if not numeric_error.is_empty():
			return _failure(numeric_error)
		var action_interval := v2_attack_rate_to_action_interval(
			float(final_stats.get("attack_speed", 0.0))
		)
		if action_interval <= 0.0:
			return _failure("正式角色攻速无法转换为有效攻击间隔：%s" % String(character_id))
		var v2_role_id := StringName(compatibility["v2_role_id"])
		var final_attack := int(final_stats.get("attack", 0))
		definitions.append({
			"character_id": character_id,
			"display_name": String(member.get("display_name", character_id)),
			"role_id": v2_role_id,
			"formal_profession_id": profession_id,
			"party_slot": party_slot,
			"deployment_slot_id": get_deployment_slot(party_slot),
			"max_health": int(final_stats.get("max_hp", 1)),
			"action_interval": action_interval,
			"action_range": float(compatibility["action_range"]),
			"attack_damage": 0 if v2_role_id == &"doctor" else final_attack,
			"heal_amount": final_attack if v2_role_id == &"doctor" else 0,
			"block_capacity": int(compatibility["block_capacity"]),
			"damage_source_type": StringName(compatibility["damage_source_type"]),
			"body_color": compatibility["body_color"],
			"battle_visual_id": StringName(member.get("battle_visual_id", &"")),
			"equipped_skill_ids": member.get("equipped_skill_ids", []).duplicate(true),
			"ultimate_id": StringName(member.get("ultimate_id", &"")),
			"compatibility_source": COMPATIBILITY_SOURCE,
		})
		character_ids[character_id] = true
		party_slots[party_slot] = true
	definitions.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left["party_slot"]) < int(right["party_slot"])
	)
	return {
		"ok": true,
		"errors": PackedStringArray(),
		"value": definitions,
	}


static func _validate_final_stats(final_stats: Dictionary, character_id: StringName) -> String:
	for stat_id: String in [
		"max_hp", "attack", "defense", "speed", "attack_speed",
		"crit_rate", "crit_damage",
	]:
		var value = final_stats.get(stat_id)
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
			return "正式角色最终属性缺失或非数值：%s.%s" % [character_id, stat_id]
		var numeric := float(value)
		if is_nan(numeric) or is_inf(numeric):
			return "正式角色最终属性不是有限数值：%s.%s" % [character_id, stat_id]
	if int(final_stats.get("max_hp", 0)) <= 0:
		return "正式角色最大生命必须为正数：%s" % String(character_id)
	if int(final_stats.get("attack", -1)) < 0:
		return "正式角色攻击/治疗基础值不得为负：%s" % String(character_id)
	if float(final_stats.get("attack_speed", 0.0)) <= 0.0:
		return "正式角色攻速必须为正数：%s" % String(character_id)
	return ""


static func _failure(message: String) -> Dictionary:
	return {
		"ok": false,
		"errors": PackedStringArray([message]),
		"value": [],
	}

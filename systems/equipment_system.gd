class_name EquipmentSystem
extends RefCounted

const EquipmentDefinitionScript := preload("res://scripts/data/equipment_definition.gd")
const EquipmentStatBonusesScript := preload("res://scripts/data/equipment_stat_bonuses.gd")
const EquipmentAffixDefinitionScript := preload("res://scripts/data/equipment_affix_definition.gd")
const EquipmentInstanceScript := preload("res://scripts/data/equipment_instance.gd")

const EMPTY_ID := &""
const SLOT_WEAPON := &"weapon"
const SLOT_ARMOR := &"armor"

const INITIAL_EQUIPMENT_IDS: Array[StringName] = [
	&"iron_sword",
	&"guardian_hammer",
	&"hunter_bow",
	&"repeater_crossbow",
	&"arcane_staff",
	&"healing_staff",
	&"iron_armor",
	&"light_leather_armor",
]

var equipment_definitions: Dictionary = {}


func _init() -> void:
	_build_equipment_definitions()


func create_initial_inventory_state() -> Dictionary:
	var instances := {}
	for equipment_id: StringName in INITIAL_EQUIPMENT_IDS:
		var instance_id := StringName("%s_01" % String(equipment_id))
		instances[instance_id] = EquipmentInstanceScript.new().setup(instance_id, equipment_id)
	return {
		"equipment_instances": instances,
	}


func get_equipment_definition(equipment_id: StringName):
	return equipment_definitions.get(equipment_id, null)


func get_equipment_definition_data(equipment_id: StringName) -> Dictionary:
	var definition = get_equipment_definition(equipment_id)
	return definition.to_dictionary() if definition != null else {}


func get_equipment_instance(game_state: Node, instance_id: StringName):
	return game_state.equipment_inventory.get("equipment_instances", {}).get(instance_id, null)


func get_equipment_instance_data(game_state: Node, instance_id: StringName) -> Dictionary:
	var instance = get_equipment_instance(game_state, instance_id)
	if instance == null:
		return {}
	var data: Dictionary = instance.to_dictionary()
	data["definition"] = get_equipment_definition_data(instance.equipment_id)
	data["equipped_by"] = get_equipped_character_id(game_state, instance_id)
	return data


func get_all_equipment_instance_data(game_state: Node) -> Array:
	var items: Array = []
	var instances: Dictionary = game_state.equipment_inventory.get("equipment_instances", {})
	for instance_id: StringName in instances.keys():
		items.append(get_equipment_instance_data(game_state, instance_id))
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_def: Dictionary = a.get("definition", {})
		var b_def: Dictionary = b.get("definition", {})
		if String(a_def.get("slot_type", "")) != String(b_def.get("slot_type", "")):
			return String(a_def.get("slot_type", "")) > String(b_def.get("slot_type", ""))
		return String(a_def.get("display_name", "")) < String(b_def.get("display_name", ""))
	)
	return items


func add_equipment(game_state: Node, equipment_id: StringName) -> StringName:
	if get_equipment_definition(equipment_id) == null:
		return EMPTY_ID
	var instances: Dictionary = game_state.equipment_inventory.get("equipment_instances", {})
	var base_id := String(equipment_id)
	var index := 1
	var instance_id := StringName("%s_%02d" % [base_id, index])
	while instances.has(instance_id):
		index += 1
		instance_id = StringName("%s_%02d" % [base_id, index])
	instances[instance_id] = EquipmentInstanceScript.new().setup(instance_id, equipment_id)
	game_state.equipment_inventory["equipment_instances"] = instances
	return instance_id


func remove_equipment(game_state: Node, instance_id: StringName) -> bool:
	if is_equipment_equipped(game_state, instance_id):
		return false
	var instances: Dictionary = game_state.equipment_inventory.get("equipment_instances", {})
	if not instances.has(instance_id):
		return false
	instances.erase(instance_id)
	game_state.equipment_inventory["equipment_instances"] = instances
	return true


func can_equip(game_state: Node, character_id: StringName, instance_id: StringName) -> bool:
	return get_equip_error(game_state, character_id, instance_id).is_empty()


func get_equip_error(game_state: Node, character_id: StringName, instance_id: StringName) -> String:
	if not game_state.character_runtime_states.has(character_id):
		return "未知角色"
	var instance = get_equipment_instance(game_state, instance_id)
	if instance == null:
		return "未知装备"
	var equipped_by := get_equipped_character_id(game_state, instance_id)
	if equipped_by != EMPTY_ID and equipped_by != character_id:
		return "该装备已被%s装备" % String(game_state.get_character_definition(equipped_by).get("display_name", equipped_by))
	var definition = get_equipment_definition(instance.equipment_id)
	if definition == null:
		return "装备数据缺失"
	var character_definition: Dictionary = game_state.get_character_definition(character_id)
	var profession_id: StringName = StringName(character_definition.get("profession_id", EMPTY_ID))
	if not is_profession_allowed(definition, profession_id):
		return "职业不符合"
	return ""


func equip(game_state: Node, character_id: StringName, instance_id: StringName) -> Dictionary:
	var error := get_equip_error(game_state, character_id, instance_id)
	if not error.is_empty():
		return {"success": false, "error": error}
	var instance = get_equipment_instance(game_state, instance_id)
	var definition = get_equipment_definition(instance.equipment_id)
	var runtime_state = game_state.character_runtime_states[character_id]
	if definition.slot_type == SLOT_WEAPON:
		runtime_state.equipped_weapon_instance_id = instance_id
		runtime_state.equipped_weapon_id = instance_id
	elif definition.slot_type == SLOT_ARMOR:
		runtime_state.equipped_armor_instance_id = instance_id
		runtime_state.equipped_armor_id = instance_id
	else:
		return {"success": false, "error": "未知装备槽位"}
	game_state.character_runtime_states[character_id] = runtime_state
	return {"success": true, "slot_type": definition.slot_type, "instance_id": instance_id}


func unequip(game_state: Node, character_id: StringName, slot_type: StringName) -> Dictionary:
	if not game_state.character_runtime_states.has(character_id):
		return {"success": false, "error": "未知角色"}
	var runtime_state = game_state.character_runtime_states[character_id]
	match slot_type:
		SLOT_WEAPON:
			runtime_state.equipped_weapon_instance_id = EMPTY_ID
			runtime_state.equipped_weapon_id = EMPTY_ID
		SLOT_ARMOR:
			runtime_state.equipped_armor_instance_id = EMPTY_ID
			runtime_state.equipped_armor_id = EMPTY_ID
		_:
			return {"success": false, "error": "未知装备槽位"}
	game_state.character_runtime_states[character_id] = runtime_state
	return {"success": true, "slot_type": slot_type}


func get_equipped_instance_id(game_state: Node, character_id: StringName, slot_type: StringName) -> StringName:
	var runtime_state = game_state.character_runtime_states.get(character_id, null)
	if runtime_state == null:
		return EMPTY_ID
	match slot_type:
		SLOT_WEAPON:
			return StringName(runtime_state.equipped_weapon_instance_id)
		SLOT_ARMOR:
			return StringName(runtime_state.equipped_armor_instance_id)
	return EMPTY_ID


func get_equipped_character_id(game_state: Node, instance_id: StringName) -> StringName:
	for character_id: StringName in game_state.character_runtime_states.keys():
		var runtime_state = game_state.character_runtime_states[character_id]
		if StringName(runtime_state.equipped_weapon_instance_id) == instance_id:
			return character_id
		if StringName(runtime_state.equipped_armor_instance_id) == instance_id:
			return character_id
	return EMPTY_ID


func is_equipment_equipped(game_state: Node, instance_id: StringName) -> bool:
	return get_equipped_character_id(game_state, instance_id) != EMPTY_ID


func get_character_equipment_bonuses(game_state: Node, character_id: StringName) -> Dictionary:
	var bonuses := {
		"attack": 0,
		"defense": 0,
		"max_hp": 0,
		"speed": 0,
	}
	for slot_type: StringName in [SLOT_WEAPON, SLOT_ARMOR]:
		var instance_id := get_equipped_instance_id(game_state, character_id, slot_type)
		var instance = get_equipment_instance(game_state, instance_id)
		if instance == null:
			continue
		var definition = get_equipment_definition(instance.equipment_id)
		if definition == null or definition.stat_bonuses == null:
			continue
		var stat_bonuses: Dictionary = definition.stat_bonuses.to_dictionary()
		for stat_id: String in bonuses.keys():
			bonuses[stat_id] = int(bonuses[stat_id]) + int(stat_bonuses.get(stat_id, 0))
	return bonuses


func get_character_affixes(game_state: Node, character_id: StringName) -> Array:
	var affixes: Array = []
	for slot_type: StringName in [SLOT_WEAPON, SLOT_ARMOR]:
		var instance_id := get_equipped_instance_id(game_state, character_id, slot_type)
		var instance = get_equipment_instance(game_state, instance_id)
		if instance == null:
			continue
		var definition = get_equipment_definition(instance.equipment_id)
		if definition == null:
			continue
		for affix in definition.affixes:
			if affix != null:
				affixes.append(affix.to_dictionary())
	return affixes


func create_battle_equipment_snapshot(game_state: Node, character_id: StringName) -> Dictionary:
	var snapshot := {
		"equipped_weapon_instance_id": EMPTY_ID,
		"equipped_armor_instance_id": EMPTY_ID,
		"equipped_weapon_id": EMPTY_ID,
		"equipped_armor_id": EMPTY_ID,
		"active_affixes": [],
	}
	for slot_type: StringName in [SLOT_WEAPON, SLOT_ARMOR]:
		var instance_id := get_equipped_instance_id(game_state, character_id, slot_type)
		var instance = get_equipment_instance(game_state, instance_id)
		if instance == null:
			continue
		var definition = get_equipment_definition(instance.equipment_id)
		if definition == null:
			continue
		var key := "equipped_weapon" if slot_type == SLOT_WEAPON else "equipped_armor"
		snapshot["%s_instance_id" % key] = instance_id
		snapshot["%s_id" % key] = definition.equipment_id
		for affix in definition.affixes:
			if affix == null:
				continue
			var affix_data: Dictionary = affix.to_dictionary()
			affix_data["equipment_id"] = definition.equipment_id
			affix_data["equipment_display_name"] = definition.display_name
			affix_data["slot_type"] = definition.slot_type
			affix_data["instance_id"] = instance_id
			snapshot["active_affixes"].append(affix_data)
	return snapshot


func apply_battle_equipment_snapshot(unit: Dictionary, snapshot: Dictionary) -> Dictionary:
	unit["equipped_weapon_instance_id"] = snapshot.get("equipped_weapon_instance_id", EMPTY_ID)
	unit["equipped_armor_instance_id"] = snapshot.get("equipped_armor_instance_id", EMPTY_ID)
	unit["equipped_weapon_id"] = snapshot.get("equipped_weapon_id", EMPTY_ID)
	unit["equipped_armor_id"] = snapshot.get("equipped_armor_id", EMPTY_ID)
	unit["active_affixes"] = snapshot.get("active_affixes", []).duplicate(true)
	unit["used_once_affix_ids"] = []
	unit["base_skill_cooldown_duration"] = int(unit.get("skill_cooldown_duration", 0))
	unit["effective_skill_cooldown_duration"] = get_effective_skill_cooldown(
		unit,
		StringName(unit.get("skill_id", EMPTY_ID)),
		int(unit.get("skill_cooldown_duration", 0))
	)
	return unit


func modify_skill_raw_damage(source: Dictionary, skill_id: StringName, raw_damage: int) -> Dictionary:
	var result := make_affix_modification_result(raw_damage)
	for affix: Dictionary in get_battle_affixes(source):
		if StringName(affix.get("effect_id", EMPTY_ID)) != &"skill_raw_damage_multiplier":
			continue
		var parameters: Dictionary = affix.get("effect_parameters", {})
		if StringName(parameters.get("skill_id", EMPTY_ID)) != skill_id:
			continue
		var multiplier_bonus := float(parameters.get("multiplier_bonus", 0.0))
		result["final_value"] = int(floor(float(result["final_value"]) * (1.0 + multiplier_bonus)))
		result["triggered_affix_ids"].append(StringName(affix.get("affix_id", EMPTY_ID)))
		result["messages"].append("%s：%s生效，%s威力提高%d%%。" % [
			String(affix.get("equipment_display_name", "")),
			String(affix.get("display_name", "")),
			String(get_skill_display_name(skill_id)),
			int(round(multiplier_bonus * 100.0)),
		])
	return result


func modify_skill_final_damage(source: Dictionary, target: Dictionary, skill_id: StringName, final_damage: int) -> Dictionary:
	var result := make_affix_modification_result(final_damage)
	for affix: Dictionary in get_battle_affixes(source):
		if StringName(affix.get("effect_id", EMPTY_ID)) != &"skill_final_damage_bonus":
			continue
		var parameters: Dictionary = affix.get("effect_parameters", {})
		if StringName(parameters.get("skill_id", EMPTY_ID)) != skill_id:
			continue
		var bonus := int(parameters.get("damage_bonus", 0))
		result["final_value"] = int(result["final_value"]) + bonus
		result["triggered_affix_ids"].append(StringName(affix.get("affix_id", EMPTY_ID)))
		result["messages"].append("%s：%s对%s额外造成%d点伤害。" % [
			String(affix.get("equipment_display_name", "")),
			String(affix.get("display_name", "")),
			String(target.get("display_name", "")),
			bonus,
		])
	return result


func modify_healing(source: Dictionary, skill_id: StringName, healing: int) -> Dictionary:
	var result := make_affix_modification_result(healing)
	for affix: Dictionary in get_battle_affixes(source):
		if StringName(affix.get("effect_id", EMPTY_ID)) != &"skill_healing_bonus":
			continue
		var parameters: Dictionary = affix.get("effect_parameters", {})
		if StringName(parameters.get("skill_id", EMPTY_ID)) != skill_id:
			continue
		var bonus := int(parameters.get("heal_bonus", 0))
		result["final_value"] = int(result["final_value"]) + bonus
		result["triggered_affix_ids"].append(StringName(affix.get("affix_id", EMPTY_ID)))
		result["messages"].append("%s：%s额外恢复%d点生命。" % [
			String(affix.get("equipment_display_name", "")),
			String(affix.get("display_name", "")),
			bonus,
		])
	return result


func get_effective_skill_cooldown(source: Dictionary, skill_id: StringName, base_cooldown: int) -> int:
	var cooldown := base_cooldown
	for affix: Dictionary in get_battle_affixes(source):
		if StringName(affix.get("effect_id", EMPTY_ID)) != &"skill_cooldown_delta":
			continue
		var parameters: Dictionary = affix.get("effect_parameters", {})
		if StringName(parameters.get("skill_id", EMPTY_ID)) != skill_id:
			continue
		cooldown += int(parameters.get("cooldown_delta", 0))
	return max(1, cooldown) if base_cooldown > 0 else 0


func get_skill_cooldown_messages(source: Dictionary, skill_id: StringName, base_cooldown: int) -> Array:
	var messages: Array = []
	var effective := get_effective_skill_cooldown(source, skill_id, base_cooldown)
	if effective >= base_cooldown:
		return messages
	for affix: Dictionary in get_battle_affixes(source):
		if StringName(affix.get("effect_id", EMPTY_ID)) != &"skill_cooldown_delta":
			continue
		var parameters: Dictionary = affix.get("effect_parameters", {})
		if StringName(parameters.get("skill_id", EMPTY_ID)) != skill_id:
			continue
		messages.append("%s：%s使%s冷却减少%d回合。" % [
			String(affix.get("equipment_display_name", "")),
			String(affix.get("display_name", "")),
			String(get_skill_display_name(skill_id)),
			base_cooldown - effective,
		])
	return messages


func process_after_defend(source: Dictionary) -> Dictionary:
	var result := {
		"heal_amount": 0,
		"triggered_affix_ids": [],
		"messages": [],
	}
	for affix: Dictionary in get_battle_affixes(source):
		if StringName(affix.get("effect_id", EMPTY_ID)) != &"after_defend_self_heal":
			continue
		var parameters: Dictionary = affix.get("effect_parameters", {})
		var heal := int(parameters.get("heal", 0))
		result["heal_amount"] = int(result["heal_amount"]) + heal
		result["triggered_affix_ids"].append(StringName(affix.get("affix_id", EMPTY_ID)))
		result["messages"].append("%s：%s恢复%d点生命。" % [
			String(affix.get("equipment_display_name", "")),
			String(affix.get("display_name", "")),
			heal,
		])
	return result


func process_before_receive_damage(target: Dictionary, incoming_damage: int) -> Dictionary:
	var result := make_affix_modification_result(incoming_damage)
	var used_once_affix_ids: Array = target.get("used_once_affix_ids", [])
	for affix: Dictionary in get_battle_affixes(target):
		if StringName(affix.get("effect_id", EMPTY_ID)) != &"first_hit_damage_reduction":
			continue
		var affix_id := StringName(affix.get("affix_id", EMPTY_ID))
		if used_once_affix_ids.has(affix_id):
			continue
		var parameters: Dictionary = affix.get("effect_parameters", {})
		var reduction := int(parameters.get("damage_reduction", 0))
		result["final_value"] = max(1, int(result["final_value"]) - reduction)
		result["triggered_affix_ids"].append(affix_id)
		result["messages"].append("%s：%s生效，受到的伤害减少%d点。" % [
			String(affix.get("equipment_display_name", "")),
			String(affix.get("display_name", "")),
			reduction,
		])
		used_once_affix_ids.append(affix_id)
		break
	result["used_once_affix_ids"] = used_once_affix_ids
	return result


func make_affix_modification_result(original_value: int) -> Dictionary:
	return {
		"original_value": original_value,
		"final_value": original_value,
		"triggered_affix_ids": [],
		"messages": [],
	}


func get_battle_affixes(source: Dictionary) -> Array:
	return source.get("active_affixes", [])


func get_skill_display_name(skill_id: StringName) -> String:
	match skill_id:
		&"shield_bash":
			return "盾击"
		&"power_shot":
			return "强力射击"
		&"arcane_blast":
			return "奥术冲击"
		&"healing_art":
			return "治疗术"
	return String(skill_id)


func get_skill_damage_multiplier_bonus(game_state: Node, character_id: StringName, skill_id: StringName) -> float:
	var bonus := 0.0
	for affix: Dictionary in get_character_affixes(game_state, character_id):
		var effect_id := StringName(affix.get("effect_id", EMPTY_ID))
		if not [&"skill_damage_multiplier", &"skill_raw_damage_multiplier"].has(effect_id):
			continue
		var parameters: Dictionary = affix.get("effect_parameters", {})
		if StringName(parameters.get("skill_id", EMPTY_ID)) == skill_id:
			bonus += float(parameters.get("multiplier_bonus", 0.0))
	return bonus


func get_skill_heal_bonus(game_state: Node, character_id: StringName, skill_id: StringName) -> int:
	var bonus := 0
	for affix: Dictionary in get_character_affixes(game_state, character_id):
		var effect_id := StringName(affix.get("effect_id", EMPTY_ID))
		if not [&"skill_heal_bonus", &"skill_healing_bonus"].has(effect_id):
			continue
		var parameters: Dictionary = affix.get("effect_parameters", {})
		if StringName(parameters.get("skill_id", EMPTY_ID)) == skill_id:
			bonus += int(parameters.get("heal_bonus", 0))
	return bonus


func get_equipment_comparison(game_state: Node, character_id: StringName, instance_id: StringName) -> Dictionary:
	var instance = get_equipment_instance(game_state, instance_id)
	if instance == null:
		return {}
	var definition = get_equipment_definition(instance.equipment_id)
	if definition == null:
		return {}
	var current_instance_id := get_equipped_instance_id(game_state, character_id, definition.slot_type)
	var current_bonuses := get_character_equipment_bonuses(game_state, character_id)
	var next_bonuses := current_bonuses.duplicate(true)
	var current_instance = get_equipment_instance(game_state, current_instance_id)
	if current_instance != null:
		var current_definition = get_equipment_definition(current_instance.equipment_id)
		if current_definition != null and current_definition.stat_bonuses != null:
			var old_stats: Dictionary = current_definition.stat_bonuses.to_dictionary()
			for stat_id: String in next_bonuses.keys():
				next_bonuses[stat_id] = int(next_bonuses[stat_id]) - int(old_stats.get(stat_id, 0))
	if definition.stat_bonuses != null:
		var new_stats: Dictionary = definition.stat_bonuses.to_dictionary()
		for stat_id: String in next_bonuses.keys():
			next_bonuses[stat_id] = int(next_bonuses[stat_id]) + int(new_stats.get(stat_id, 0))
	var diff := {}
	for stat_id: String in next_bonuses.keys():
		diff[stat_id] = int(next_bonuses[stat_id]) - int(current_bonuses[stat_id])
	return diff


func is_profession_allowed(definition, profession_id: StringName) -> bool:
	if definition.allowed_professions.is_empty():
		return true
	return definition.allowed_professions.has(profession_id)


func get_slot_display_name(slot_type: StringName) -> String:
	match slot_type:
		SLOT_WEAPON:
			return "武器"
		SLOT_ARMOR:
			return "护甲"
	return String(slot_type)


func get_allowed_profession_text(definition) -> String:
	if definition == null or definition.allowed_professions.is_empty():
		return "全职业"
	var names := PackedStringArray()
	for profession_id: StringName in definition.allowed_professions:
		names.append(String(profession_id))
	return " / ".join(names)


func _build_equipment_definitions() -> void:
	equipment_definitions[&"iron_sword"] = EquipmentDefinitionScript.new().setup(
		&"iron_sword",
		"铁制长剑",
		"打磨得很朴素的长剑，适合守卫进行稳定突击。",
		SLOT_WEAPON,
		[&"guard"],
		&"magic",
		EquipmentStatBonusesScript.new().setup(3, 0, 0, 0),
		[_affix(&"shield_bash_damage_boost", "盾击强化", "盾击伤害提高25%。", &"skill_raw_damage_multiplier", {"skill_id": &"shield_bash", "multiplier_bonus": 0.25})],
		"寒铁不语，只记得每一次正面交锋的重量。",
		90,
		18
	)
	equipment_definitions[&"guardian_hammer"] = EquipmentDefinitionScript.new().setup(
		&"guardian_hammer",
		"守护战锤",
		"锤头厚重，攻守兼备。",
		SLOT_WEAPON,
		[&"guard"],
		&"rare",
		EquipmentStatBonusesScript.new().setup(2, 1, 0, 0),
		[_affix(&"defend_self_heal", "防守姿态", "使用防御后，恢复2点生命。", &"after_defend_self_heal", {"heal": 2})],
		"老守卫说，挡下来的每一下都算一次胜利。",
		130,
		22
	)
	equipment_definitions[&"hunter_bow"] = EquipmentDefinitionScript.new().setup(
		&"hunter_bow",
		"猎人短弓",
		"轻便短弓，适合林间游侠快速开弦。",
		SLOT_WEAPON,
		[&"ranger"],
		&"magic",
		EquipmentStatBonusesScript.new().setup(3, 0, 0, 0),
		[_affix(&"power_shot_damage_boost", "精准射击", "强力射击伤害提高20%。", &"skill_raw_damage_multiplier", {"skill_id": &"power_shot", "multiplier_bonus": 0.20})],
		"许多人都说这只是一件普通短弓，但真正的猎手知道它在风中的分量。",
		100,
		18
	)
	equipment_definitions[&"repeater_crossbow"] = EquipmentDefinitionScript.new().setup(
		&"repeater_crossbow",
		"连射弩",
		"带有简易连发结构的弩机。",
		SLOT_WEAPON,
		[&"ranger"],
		&"rare",
		EquipmentStatBonusesScript.new().setup(2, 0, 0, 0),
		[_affix(&"power_shot_cooldown_reduction", "快速装填", "强力射击冷却减少1回合。", &"skill_cooldown_delta", {"skill_id": &"power_shot", "cooldown_delta": -1})],
		"弦声短促，像雨点落在旧木窗上。",
		140,
		20
	)
	equipment_definitions[&"arcane_staff"] = EquipmentDefinitionScript.new().setup(
		&"arcane_staff",
		"奥术法杖",
		"杖芯镶着微光水晶，能稳定引导奥术。",
		SLOT_WEAPON,
		[&"mage"],
		&"rare",
		EquipmentStatBonusesScript.new().setup(3, 0, 0, 0),
		[_affix(&"arcane_blast_flat_damage", "魔力扩散", "奥术冲击对每个敌人额外造成1点伤害。", &"skill_final_damage_bonus", {"skill_id": &"arcane_blast", "damage_bonus": 1})],
		"光在杖端凝结，然后散成看不见的涟漪。",
		150,
		24
	)
	equipment_definitions[&"healing_staff"] = EquipmentDefinitionScript.new().setup(
		&"healing_staff",
		"治愈木杖",
		"由柔韧树枝制成的短杖，带着淡淡药草气味。",
		SLOT_WEAPON,
		[&"healer"],
		&"magic",
		EquipmentStatBonusesScript.new().setup(1, 0, 0, 0),
		[_affix(&"healing_skill_flat_bonus", "温和治疗", "治疗术额外恢复3点生命。", &"skill_healing_bonus", {"skill_id": &"healing_art", "heal_bonus": 3})],
		"握住它时，掌心会想起春天的温度。",
		95,
		14
	)
	equipment_definitions[&"iron_armor"] = EquipmentDefinitionScript.new().setup(
		&"iron_armor",
		"铁制护甲",
		"结实可靠的基础护甲。",
		SLOT_ARMOR,
		[],
		&"common",
		EquipmentStatBonusesScript.new().setup(0, 2, 4, 0),
		[],
		"没有传奇故事，只有活着回来的人。",
		80,
		20
	)
	equipment_definitions[&"light_leather_armor"] = EquipmentDefinitionScript.new().setup(
		&"light_leather_armor",
		"轻便皮甲",
		"轻巧且不妨碍行动的皮甲。",
		SLOT_ARMOR,
		[],
		&"rare",
		EquipmentStatBonusesScript.new().setup(0, 1, 2, 0),
		[_affix(&"first_hit_damage_reduction", "灵活", "本场战斗第一次受到伤害时，伤害减少2点。", &"first_hit_damage_reduction", {"damage_reduction": 2})],
		"它挡不住所有危险，但能让你更早离开危险。",
		120,
		18
	)


func _affix(
	affix_id: StringName,
	display_name: String,
	description: String,
	effect_id: StringName,
	effect_parameters: Dictionary,
	affix_category: StringName = &"special"
):
	return EquipmentAffixDefinitionScript.new().setup(
		affix_id,
		display_name,
		description,
		effect_id,
		effect_parameters,
		affix_category
	)

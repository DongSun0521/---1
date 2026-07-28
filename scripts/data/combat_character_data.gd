class_name CombatCharacterData
extends RefCounted

const CharacterEnumsScript := preload("res://scripts/data/character_enums.gd")
const CombatStatsScript := preload("res://scripts/data/combat_stats.gd")
const Stage12Config := preload("res://scripts/data/stage12_balance_config.gd")

var combat_class: int = CharacterEnumsScript.CombatClass.WARRIOR
var profession_id: StringName = &"guard"
var base_combat_stats: CombatStats
var level_growth_stats: CombatStats
var current_hp: int = 0
var equipped_weapon_id: StringName = &""
var equipped_armor_id: StringName = &""
var equipped_weapon_instance_id: StringName = &""
var equipped_armor_instance_id: StringName = &""
var skill_ids: Array[StringName] = []
var combat_trait_ids: Array[StringName] = []
var is_in_party: bool = false
var party_slot: int = -1
var injury_state: StringName = &"healthy"
var battle_visual_id: StringName = &""
var status_data: Dictionary = {}


func setup(
	p_combat_class: int,
	p_profession_id: StringName,
	p_base_combat_stats: CombatStats,
	p_current_hp: int,
	p_skill_ids: Array[StringName],
	p_combat_trait_ids: Array[StringName],
	p_is_in_party: bool,
	p_party_slot: int,
	p_battle_visual_id: StringName
) -> CombatCharacterData:
	combat_class = p_combat_class
	profession_id = p_profession_id
	base_combat_stats = p_base_combat_stats
	level_growth_stats = CombatStatsScript.new().setup(0, 0, 0, 0, 0.0, 0.0, 0.0)
	current_hp = max(0, p_current_hp)
	skill_ids = p_skill_ids.duplicate()
	combat_trait_ids = p_combat_trait_ids.duplicate()
	is_in_party = p_is_in_party
	party_slot = p_party_slot
	battle_visual_id = p_battle_visual_id
	return self


func get_equipment_slots() -> Dictionary:
	return {
		"weapon": equipped_weapon_instance_id,
		"armor": equipped_armor_instance_id,
	}


func calculate_final_stat_details(
	level: int,
	equipment_bonuses: Dictionary = {},
	trait_bonuses: Dictionary = {},
	village_bonuses: Dictionary = {},
	temporary_bonuses: Dictionary = {}
) -> Dictionary:
	if base_combat_stats == null:
		return {}
	var base: Dictionary = base_combat_stats.to_dictionary()
	var growth: Dictionary = level_growth_stats.to_dictionary() if level_growth_stats != null else {}
	var result: Dictionary = {}
	for stat_id: String in ["max_hp", "attack", "defense", "speed", "attack_speed", "crit_rate", "crit_damage"]:
		var base_value: float = float(base.get(stat_id, 0.0))
		var growth_value: float = float(growth.get(stat_id, 0.0)) * float(max(0, level - 1))
		var village_value: float = float(village_bonuses.get(stat_id, 0.0))
		var equipment_value: float = float(equipment_bonuses.get(stat_id, 0.0))
		var trait_value: float = float(trait_bonuses.get(stat_id, 0.0))
		var before_injury: float = base_value + growth_value + village_value + equipment_value + trait_value
		var after_injury: float = before_injury
		var injury_multiplier := 1.0
		if stat_id == "max_hp" and injury_state == &"injured":
			injury_multiplier = 0.8
			after_injury = maxf(1.0, floor(before_injury * injury_multiplier))
		var temporary_value: float = float(temporary_bonuses.get(stat_id, 0.0))
		var final_value: float = after_injury + temporary_value
		match stat_id:
			"max_hp":
				final_value = maxf(1.0, final_value)
			"attack", "defense", "speed", "attack_speed":
				final_value = maxf(0.0, final_value)
			"crit_rate":
				final_value = clampf(
					final_value,
					Stage12Config.COMBAT_CRIT_RATE_MIN,
					Stage12Config.COMBAT_CRIT_RATE_MAX
				)
			"crit_damage":
				final_value = clampf(
					final_value,
					Stage12Config.COMBAT_CRIT_DAMAGE_MIN,
					Stage12Config.COMBAT_CRIT_DAMAGE_MAX
				)
		var use_float := stat_id in ["attack_speed", "crit_rate", "crit_damage"]
		result[stat_id] = {
			"base": base_value if use_float else int(base_value),
			"level_growth_bonus": growth_value if use_float else int(growth_value),
			"village_bonus": village_value if use_float else int(village_value),
			"trait_bonus": trait_value if use_float else int(trait_value),
			"equipment_bonus": equipment_value if use_float else int(equipment_value),
			"injury_state": injury_state,
			"injury_multiplier": injury_multiplier,
			"injury_penalty": (after_injury - before_injury) if use_float else int(after_injury - before_injury),
			"temporary_bonus": temporary_value if use_float else int(temporary_value),
			"final": final_value if use_float else int(final_value),
		}
	return result


func to_dictionary() -> Dictionary:
	return {
		"combat_class": combat_class,
		"profession_id": profession_id,
		"base_combat_stats": base_combat_stats.to_dictionary() if base_combat_stats != null else {},
		"level_growth_stats": level_growth_stats.to_dictionary() if level_growth_stats != null else {},
		"current_hp": current_hp,
		"equipment_slots": get_equipment_slots(),
		# Legacy slot fields remain serialized so Stage 9 equipment saves migrate losslessly.
		"equipped_weapon_id": equipped_weapon_id,
		"equipped_armor_id": equipped_armor_id,
		"equipped_weapon_instance_id": equipped_weapon_instance_id,
		"equipped_armor_instance_id": equipped_armor_instance_id,
		"skill_ids": skill_ids.duplicate(),
		"combat_trait_ids": combat_trait_ids.duplicate(),
		"is_in_party": is_in_party,
		"party_slot": party_slot,
		"injury_state": injury_state,
		"battle_visual_id": battle_visual_id,
		"status_data": status_data.duplicate(true),
	}


func apply_dictionary(data: Dictionary) -> CombatCharacterData:
	combat_class = int(data.get("combat_class", CharacterEnumsScript.CombatClass.WARRIOR))
	profession_id = StringName(data.get("profession_id", &"guard"))
	base_combat_stats = CombatStatsScript.from_dictionary(data.get("base_combat_stats", {}))
	level_growth_stats = CombatStatsScript.from_dictionary(data.get("level_growth_stats", {}))
	current_hp = max(0, int(data.get("current_hp", base_combat_stats.max_hp)))
	var slots: Dictionary = data.get("equipment_slots", {})
	equipped_weapon_instance_id = StringName(data.get("equipped_weapon_instance_id", slots.get("weapon", &"")))
	equipped_armor_instance_id = StringName(data.get("equipped_armor_instance_id", slots.get("armor", &"")))
	equipped_weapon_id = StringName(data.get("equipped_weapon_id", equipped_weapon_instance_id))
	equipped_armor_id = StringName(data.get("equipped_armor_id", equipped_armor_instance_id))
	skill_ids = _to_string_name_array(data.get("skill_ids", []))
	combat_trait_ids = _to_string_name_array(data.get("combat_trait_ids", []))
	is_in_party = bool(data.get("is_in_party", false))
	party_slot = int(data.get("party_slot", -1))
	injury_state = StringName(data.get("injury_state", &"healthy"))
	battle_visual_id = StringName(data.get("battle_visual_id", &""))
	status_data = data.get("status_data", {}).duplicate(true)
	return self


static func from_dictionary(data: Dictionary) -> CombatCharacterData:
	return CombatCharacterData.new().apply_dictionary(data)


static func _to_string_name_array(values: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for value in values:
		result.append(StringName(value))
	return result

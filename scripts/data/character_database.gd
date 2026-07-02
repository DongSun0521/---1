class_name CharacterDatabase
extends RefCounted

const CombatStatsScript := preload("res://scripts/data/combat_stats.gd")
const LifeStatsScript := preload("res://scripts/data/life_stats.gd")
const CharacterDefinitionScript := preload("res://scripts/data/character_definition.gd")
const CharacterRuntimeStateScript := preload("res://scripts/data/character_runtime_state.gd")
const TraitDefinitionScript := preload("res://scripts/data/trait_definition.gd")

const PARTY_ORDER: Array[StringName] = [&"guard", &"hunter", &"mage", &"doctor"]
const EMPTY_ID := &""

const PROFESSIONS := {
	&"guard": "守卫",
	&"ranger": "游侠",
	&"mage": "法师",
	&"healer": "治疗者",
}

const SKILLS := {
	&"shield_bash": {
		"skill_name": "盾击",
		"skill_cooldown_duration": 2,
		"skill_type": "single_damage",
		"skill_multiplier": 1.2,
	},
	&"power_shot": {
		"skill_name": "强力射击",
		"skill_cooldown_duration": 2,
		"skill_type": "single_damage",
		"skill_multiplier": 1.8,
	},
	&"arcane_blast": {
		"skill_name": "奥术冲击",
		"skill_cooldown_duration": 3,
		"skill_type": "aoe_damage",
		"skill_multiplier": 0.8,
	},
	&"healing_art": {
		"skill_name": "治疗术",
		"skill_cooldown_duration": 2,
		"skill_type": "heal",
		"skill_heal_amount": 10,
	},
}

var character_definitions: Dictionary = {}
var trait_definitions: Dictionary = {}


func _init() -> void:
	_build_traits()
	_build_characters()


func get_party_order() -> Array[StringName]:
	return PARTY_ORDER.duplicate()


func get_profession_display_name(profession_id: StringName) -> String:
	return String(PROFESSIONS.get(profession_id, String(profession_id)))


func get_character_definition(character_id: StringName):
	return character_definitions.get(character_id, null)


func get_trait_definition(trait_id: StringName):
	return trait_definitions.get(trait_id, null)


func get_skill_data(skill_id: StringName) -> Dictionary:
	return SKILLS.get(skill_id, {}).duplicate(true)


func create_initial_runtime_states() -> Dictionary:
	var states := {}
	for character_id: StringName in PARTY_ORDER:
		var definition = get_character_definition(character_id)
		states[character_id] = CharacterRuntimeStateScript.new().setup(
			character_id,
			definition.base_combat_stats.max_hp
		)
	return states


func get_final_combat_stat_details(
	character_id: StringName,
	party_attack_bonus: int,
	party_max_hp_bonus: int,
	equipment_bonuses: Dictionary = {}
) -> Dictionary:
	var definition = get_character_definition(character_id)
	if definition == null or definition.base_combat_stats == null:
		return {}

	var base: Dictionary = definition.base_combat_stats.to_dictionary()
	return {
		"max_hp": _make_stat_detail(
			int(base.get("max_hp", 0)),
			party_max_hp_bonus,
			0,
			int(equipment_bonuses.get("max_hp", 0))
		),
		"attack": _make_stat_detail(
			int(base.get("attack", 0)),
			party_attack_bonus,
			0,
			int(equipment_bonuses.get("attack", 0))
		),
		"defense": _make_stat_detail(
			int(base.get("defense", 0)),
			0,
			0,
			int(equipment_bonuses.get("defense", 0))
		),
		"speed": _make_stat_detail(
			int(base.get("speed", 0)),
			0,
			0,
			int(equipment_bonuses.get("speed", 0))
		),
	}


func get_final_combat_stats(
	character_id: StringName,
	party_attack_bonus: int,
	party_max_hp_bonus: int,
	equipment_bonuses: Dictionary = {}
) -> Dictionary:
	var details := get_final_combat_stat_details(character_id, party_attack_bonus, party_max_hp_bonus, equipment_bonuses)
	var stats := {}
	for stat_id: String in details.keys():
		stats[stat_id] = int(details[stat_id].get("final", 0))
	return stats


func create_party_unit_state(
	character_id: StringName,
	runtime_state,
	final_stat_details: Dictionary
) -> Dictionary:
	var definition = get_character_definition(character_id)
	if definition == null:
		return {}
	var skill_id: StringName = definition.skill_ids[0] if not definition.skill_ids.is_empty() else EMPTY_ID
	var skill := get_skill_data(skill_id)
	var final_stats := {}
	for stat_id: String in final_stat_details.keys():
		final_stats[stat_id] = int(final_stat_details[stat_id].get("final", 0))
	var max_hp: int = int(final_stats.get("max_hp", 1))
	var current_hp: int = clampi(runtime_state.current_hp if runtime_state != null else max_hp, 0, max_hp)
	return {
		"unit_id": character_id,
		"character_id": character_id,
		"display_name": definition.display_name,
		"role": get_profession_display_name(definition.profession_id),
		"profession_id": definition.profession_id,
		"is_player_unit": true,
		"base_max_hp": int(definition.base_combat_stats.max_hp),
		"base_attack": int(definition.base_combat_stats.attack),
		"max_hp": max_hp,
		"current_hp": current_hp,
		"attack": int(final_stats.get("attack", 0)),
		"defense": int(final_stats.get("defense", 0)),
		"speed": int(final_stats.get("speed", 0)),
		"skill_id": skill_id,
		"skill_name": String(skill.get("skill_name", "")),
		"skill_type": String(skill.get("skill_type", "")),
		"skill_multiplier": float(skill.get("skill_multiplier", 0.0)),
		"skill_heal_amount": int(skill.get("skill_heal_amount", 0)),
		"skill_cooldown_duration": int(skill.get("skill_cooldown_duration", 0)),
		"skill_cooldown": 0,
		"is_defending": false,
		"battle_visual_id": definition.battle_visual_id,
	}


func get_character_detail(
	character_id: StringName,
	runtime_state,
	final_stat_details: Dictionary
) -> Dictionary:
	var definition = get_character_definition(character_id)
	if definition == null:
		return {}
	var traits: Array = []
	for trait_id: StringName in definition.trait_ids:
		var trait_definition = get_trait_definition(trait_id)
		if trait_definition != null:
			traits.append(trait_definition.to_dictionary())
	var skills: Array = []
	for skill_id: StringName in definition.skill_ids:
		var skill := get_skill_data(skill_id)
		skill["skill_id"] = skill_id
		skills.append(skill)
	return {
		"definition": definition.to_dictionary(),
		"profession_display_name": get_profession_display_name(definition.profession_id),
		"runtime_state": runtime_state.to_dictionary() if runtime_state != null else {},
		"final_stat_details": final_stat_details.duplicate(true),
		"traits": traits,
		"skills": skills,
	}


func _build_traits() -> void:
	trait_definitions[&"sturdy_body"] = TraitDefinitionScript.new().setup(
		&"sturdy_body",
		"坚韧体魄",
		"经历长期训练，拥有优秀的正面承伤能力。",
		&"reserved_noop"
	)
	trait_definitions[&"keen_sense"] = TraitDefinitionScript.new().setup(
		&"keen_sense",
		"敏锐感知",
		"能够快速发现敌人的行动与弱点。",
		&"reserved_noop"
	)
	trait_definitions[&"arcane_focus"] = TraitDefinitionScript.new().setup(
		&"arcane_focus",
		"奥术专注",
		"擅长集中精神控制魔法能量。",
		&"reserved_noop"
	)
	trait_definitions[&"herbal_knowledge"] = TraitDefinitionScript.new().setup(
		&"herbal_knowledge",
		"草药知识",
		"熟悉药物、草药和伤势处理。",
		&"reserved_noop"
	)


func _build_characters() -> void:
	character_definitions[&"guard"] = CharacterDefinitionScript.new().setup(
		&"guard",
		"阿盾",
		&"guard",
		"守卫出身的前排战士，负责保护冒险队阵线。",
		CombatStatsScript.new().setup(40, 6, 5, 3),
		LifeStatsScript.new().setup(10, 25, 5, 5, 5, 20),
		[&"sturdy_body"],
		[&"shield_bash"],
		&"guard"
	)
	character_definitions[&"hunter"] = CharacterDefinitionScript.new().setup(
		&"hunter",
		"林羽",
		&"ranger",
		"擅长观察和远程射击的游侠，负责快速压低敌人生命。",
		CombatStatsScript.new().setup(26, 8, 2, 7),
		LifeStatsScript.new().setup(15, 5, 10, 10, 10, 30),
		[&"keen_sense"],
		[&"power_shot"],
		&"hunter"
	)
	character_definitions[&"mage"] = CharacterDefinitionScript.new().setup(
		&"mage",
		"米娅",
		&"mage",
		"研究奥术的法师，擅长对多个敌人造成稳定伤害。",
		CombatStatsScript.new().setup(22, 7, 1, 5),
		LifeStatsScript.new().setup(5, 5, 5, 15, 35, 10),
		[&"arcane_focus"],
		[&"arcane_blast"],
		&"mage"
	)
	character_definitions[&"doctor"] = CharacterDefinitionScript.new().setup(
		&"doctor",
		"露娜",
		&"healer",
		"随队治疗者，负责药品管理和战斗中的伤势恢复。",
		CombatStatsScript.new().setup(24, 4, 2, 6),
		LifeStatsScript.new().setup(20, 5, 20, 35, 15, 15),
		[&"herbal_knowledge"],
		[&"healing_art"],
		&"doctor"
	)


func _make_stat_detail(base: int, village_bonus: int, trait_bonus: int, equipment_bonus: int) -> Dictionary:
	return {
		"base": base,
		"village_bonus": village_bonus,
		"trait_bonus": trait_bonus,
		"equipment_bonus": equipment_bonus,
		"final": base + village_bonus + trait_bonus + equipment_bonus,
	}

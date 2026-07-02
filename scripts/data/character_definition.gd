class_name CharacterDefinition
extends Resource

@export var character_id: StringName
@export var display_name: String
@export var profession_id: StringName
@export var description: String
@export var base_combat_stats: Resource
@export var life_stats: Resource
@export var trait_ids: Array[StringName] = []
@export var skill_ids: Array[StringName] = []
@export var battle_visual_id: StringName


func setup(
	p_character_id: StringName,
	p_display_name: String,
	p_profession_id: StringName,
	p_description: String,
	p_base_combat_stats: Resource,
	p_life_stats: Resource,
	p_trait_ids: Array[StringName],
	p_skill_ids: Array[StringName],
	p_battle_visual_id: StringName
):
	character_id = p_character_id
	display_name = p_display_name
	profession_id = p_profession_id
	description = p_description
	base_combat_stats = p_base_combat_stats
	life_stats = p_life_stats
	trait_ids = p_trait_ids.duplicate()
	skill_ids = p_skill_ids.duplicate()
	battle_visual_id = p_battle_visual_id
	return self


func to_dictionary() -> Dictionary:
	return {
		"character_id": character_id,
		"display_name": display_name,
		"profession_id": profession_id,
		"description": description,
		"base_combat_stats": base_combat_stats.to_dictionary() if base_combat_stats != null else {},
		"life_stats": life_stats.to_dictionary() if life_stats != null else {},
		"trait_ids": trait_ids.duplicate(),
		"skill_ids": skill_ids.duplicate(),
		"battle_visual_id": battle_visual_id,
	}

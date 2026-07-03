class_name ExpeditionMealData
extends Resource

@export var meal_id: StringName
@export var display_name: String
@export_multiline var description: String
@export var max_hp_bonus: int = 0
@export var attack_bonus: int = 0
@export var icon: Texture2D


func setup(
	p_meal_id: StringName,
	p_display_name: String,
	p_description: String,
	p_max_hp_bonus: int = 0,
	p_attack_bonus: int = 0,
	p_icon: Texture2D = null
):
	meal_id = p_meal_id
	display_name = p_display_name
	description = p_description
	max_hp_bonus = p_max_hp_bonus
	attack_bonus = p_attack_bonus
	icon = p_icon
	return self


func to_dictionary() -> Dictionary:
	return {
		"meal_id": meal_id,
		"display_name": display_name,
		"description": description,
		"max_hp_bonus": max_hp_bonus,
		"attack_bonus": attack_bonus,
		"icon": icon,
	}

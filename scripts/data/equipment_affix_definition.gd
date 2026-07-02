class_name EquipmentAffixDefinition
extends Resource

@export var affix_id: StringName
@export var display_name: String
@export var description: String
@export var effect_id: StringName
@export var effect_parameters: Dictionary = {}
@export var affix_category: StringName = &"primary"


func setup(
	p_affix_id: StringName,
	p_display_name: String,
	p_description: String,
	p_effect_id: StringName = &"",
	p_effect_parameters: Dictionary = {},
	p_affix_category: StringName = &"primary"
):
	affix_id = p_affix_id
	display_name = p_display_name
	description = p_description
	effect_id = p_effect_id
	effect_parameters = p_effect_parameters.duplicate(true)
	affix_category = p_affix_category
	return self


func to_dictionary() -> Dictionary:
	return {
		"affix_id": affix_id,
		"display_name": display_name,
		"description": description,
		"effect_id": effect_id,
		"effect_parameters": effect_parameters.duplicate(true),
		"affix_category": affix_category,
	}

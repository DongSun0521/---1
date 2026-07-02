class_name TraitDefinition
extends Resource

@export var trait_id: StringName
@export var display_name: String
@export var description: String
@export var effect_id: StringName
@export var effect_parameters: Dictionary = {}


func setup(
	p_trait_id: StringName,
	p_display_name: String,
	p_description: String,
	p_effect_id: StringName = &"",
	p_effect_parameters: Dictionary = {}
):
	trait_id = p_trait_id
	display_name = p_display_name
	description = p_description
	effect_id = p_effect_id
	effect_parameters = p_effect_parameters.duplicate(true)
	return self


func to_dictionary() -> Dictionary:
	return {
		"trait_id": trait_id,
		"display_name": display_name,
		"description": description,
		"effect_id": effect_id,
		"effect_parameters": effect_parameters.duplicate(true),
	}

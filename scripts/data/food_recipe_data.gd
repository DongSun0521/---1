class_name FoodRecipeData
extends Resource

@export var recipe_id: StringName
@export var display_name: String
@export_multiline var description: String
@export var duration_days: int = 1
@export var ingredient_costs: Dictionary = {}
@export var output_item_id: StringName
@export var output_amount: int = 1
@export var recipe_category: StringName = &"ration"
@export var icon: Texture2D


func setup(
	p_recipe_id: StringName,
	p_display_name: String,
	p_description: String,
	p_duration_days: int,
	p_ingredient_costs: Dictionary,
	p_output_item_id: StringName,
	p_output_amount: int,
	p_recipe_category: StringName = &"ration",
	p_icon: Texture2D = null
):
	recipe_id = p_recipe_id
	display_name = p_display_name
	description = p_description
	duration_days = p_duration_days
	ingredient_costs = p_ingredient_costs.duplicate(true)
	output_item_id = p_output_item_id
	output_amount = p_output_amount
	recipe_category = p_recipe_category
	icon = p_icon
	return self


func to_dictionary() -> Dictionary:
	return {
		"recipe_id": recipe_id,
		"display_name": display_name,
		"description": description,
		"duration_days": duration_days,
		"ingredient_costs": ingredient_costs.duplicate(true),
		"output_item_id": output_item_id,
		"output_amount": output_amount,
		"recipe_category": recipe_category,
		"icon": icon,
	}

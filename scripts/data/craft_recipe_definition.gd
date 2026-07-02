class_name CraftRecipeDefinition
extends Resource

@export var recipe_id: StringName
@export var result_equipment_id: StringName
@export var display_name: String
@export var description: String
@export var forge_building_id: StringName = &"weapon_forge"
@export var craft_time_days: int = 1
@export var ore_cost: int = 0
@export var herb_cost: int = 0
@export var food_cost: int = 0
@export var medicine_cost: int = 0


func setup(
	p_recipe_id: StringName,
	p_result_equipment_id: StringName,
	p_display_name: String,
	p_description: String,
	p_craft_time_days: int,
	p_ore_cost: int = 0,
	p_herb_cost: int = 0,
	p_food_cost: int = 0,
	p_medicine_cost: int = 0,
	p_forge_building_id: StringName = &"weapon_forge"
):
	recipe_id = p_recipe_id
	result_equipment_id = p_result_equipment_id
	display_name = p_display_name
	description = p_description
	craft_time_days = p_craft_time_days
	ore_cost = p_ore_cost
	herb_cost = p_herb_cost
	food_cost = p_food_cost
	medicine_cost = p_medicine_cost
	forge_building_id = p_forge_building_id
	return self


func to_dictionary() -> Dictionary:
	return {
		"recipe_id": recipe_id,
		"result_equipment_id": result_equipment_id,
		"display_name": display_name,
		"description": description,
		"forge_building_id": forge_building_id,
		"craft_time_days": craft_time_days,
		"ore_cost": ore_cost,
		"herb_cost": herb_cost,
		"food_cost": food_cost,
		"medicine_cost": medicine_cost,
	}

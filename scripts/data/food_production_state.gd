class_name FoodProductionState
extends RefCounted

var recipe_id: StringName = &""
var progress_days: int = 0
var required_days: int = 0
var started_day: int = 0
var is_active: bool = false


func setup(
	p_recipe_id: StringName = &"",
	p_progress_days: int = 0,
	p_required_days: int = 0,
	p_started_day: int = 0,
	p_is_active: bool = false
):
	recipe_id = p_recipe_id
	progress_days = p_progress_days
	required_days = p_required_days
	started_day = p_started_day
	is_active = p_is_active
	return self


func clear() -> void:
	recipe_id = &""
	progress_days = 0
	required_days = 0
	started_day = 0
	is_active = false


func to_dictionary() -> Dictionary:
	return {
		"recipe_id": recipe_id,
		"progress_days": progress_days,
		"required_days": required_days,
		"started_day": started_day,
		"is_active": is_active,
	}

class_name ForgeCraftState
extends RefCounted

var active_recipe_id: StringName = &""
var result_equipment_id: StringName = &""
var progress_days: int = 0
var required_days: int = 0
var started_day: int = 0
var is_active: bool = false
var is_completed: bool = false


func setup(
	p_active_recipe_id: StringName = &"",
	p_result_equipment_id: StringName = &"",
	p_progress_days: int = 0,
	p_required_days: int = 0,
	p_started_day: int = 0,
	p_is_active: bool = false,
	p_is_completed: bool = false
):
	active_recipe_id = p_active_recipe_id
	result_equipment_id = p_result_equipment_id
	progress_days = p_progress_days
	required_days = p_required_days
	started_day = p_started_day
	is_active = p_is_active
	is_completed = p_is_completed
	return self


func clear() -> void:
	active_recipe_id = &""
	result_equipment_id = &""
	progress_days = 0
	required_days = 0
	started_day = 0
	is_active = false
	is_completed = false


func to_dictionary() -> Dictionary:
	return {
		"active_recipe_id": active_recipe_id,
		"result_equipment_id": result_equipment_id,
		"progress_days": progress_days,
		"required_days": required_days,
		"started_day": started_day,
		"is_active": is_active,
		"is_completed": is_completed,
	}

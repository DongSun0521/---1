class_name FarmPlotState
extends RefCounted

var plot_id: int = 0
var is_unlocked: bool = false
var crop_id: StringName = &""
var progress_days: int = 0
var is_active: bool = false


func setup(p_plot_id: int, p_is_unlocked: bool, p_crop_id: StringName, p_progress_days: int, p_is_active: bool) -> FarmPlotState:
	plot_id = p_plot_id
	is_unlocked = p_is_unlocked
	crop_id = p_crop_id
	progress_days = max(0, p_progress_days)
	is_active = p_is_active
	return self


func to_dictionary() -> Dictionary:
	return {
		"plot_id": plot_id,
		"is_unlocked": is_unlocked,
		"crop_id": crop_id,
		"progress_days": progress_days,
		"is_active": is_active,
		"status": get_status(),
	}


func get_status() -> StringName:
	if not is_unlocked:
		return &"locked"
	if not is_active or crop_id == &"":
		return &"empty"
	return &"growing"

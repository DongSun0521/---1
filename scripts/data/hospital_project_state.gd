class_name HospitalProjectState
extends RefCounted

var project_id: StringName = &""
var project_type: StringName = &""
var progress_days: int = 0
var required_days: int = 0
var target_character_id: StringName = &""
var is_active: bool = false
var result_processed: bool = false


func setup(
	p_project_id: StringName = &"",
	p_project_type: StringName = &"",
	p_required_days: int = 0,
	p_target_character_id: StringName = &""
):
	project_id = p_project_id
	project_type = p_project_type
	progress_days = 0
	required_days = p_required_days
	target_character_id = p_target_character_id
	is_active = project_type != &""
	result_processed = false
	return self


func clear() -> void:
	project_id = &""
	project_type = &""
	progress_days = 0
	required_days = 0
	target_character_id = &""
	is_active = false
	result_processed = false


func to_dictionary() -> Dictionary:
	return {
		"project_id": project_id,
		"project_type": project_type,
		"progress_days": progress_days,
		"required_days": required_days,
		"target_character_id": target_character_id,
		"is_active": is_active,
		"result_processed": result_processed,
	}

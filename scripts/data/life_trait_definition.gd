class_name LifeTraitDefinition
extends Resource

@export var trait_id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var applicable_job_types: Array[StringName] = []
@export var efficiency_bonus_percent: float = 0.0
@export var work_experience_bonus_percent: float = 0.0
@export var production_bonus_percent: float = 0.0


func setup(
	p_trait_id: StringName,
	p_display_name: String,
	p_description: String,
	p_applicable_job_types: Array[StringName],
	p_efficiency_bonus_percent: float = 0.0,
	p_work_experience_bonus_percent: float = 0.0,
	p_production_bonus_percent: float = 0.0
) -> LifeTraitDefinition:
	trait_id = p_trait_id
	display_name = p_display_name
	description = p_description
	applicable_job_types = p_applicable_job_types.duplicate()
	efficiency_bonus_percent = p_efficiency_bonus_percent
	work_experience_bonus_percent = p_work_experience_bonus_percent
	production_bonus_percent = p_production_bonus_percent
	return self


func applies_to_job(job_type: StringName) -> bool:
	return applicable_job_types.is_empty() or applicable_job_types.has(job_type)


func to_dictionary() -> Dictionary:
	return {
		"trait_id": trait_id,
		"display_name": display_name,
		"description": description,
		"applicable_job_types": applicable_job_types.duplicate(),
		"efficiency_bonus_percent": efficiency_bonus_percent,
		"work_experience_bonus_percent": work_experience_bonus_percent,
		"production_bonus_percent": production_bonus_percent,
	}

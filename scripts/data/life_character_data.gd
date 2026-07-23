class_name LifeCharacterData
extends RefCounted

const CharacterEnumsScript := preload("res://scripts/data/character_enums.gd")
const LifeStatsScript := preload("res://scripts/data/life_stats.gd")

var life_stats: LifeStats
var life_trait_ids: Array[StringName] = []
var assigned_building_id: StringName = &""
var assigned_job_id: StringName = &""
var work_state: int = CharacterEnumsScript.WorkState.IDLE
var work_experience: int = 0


func setup(p_life_stats: LifeStats, p_life_trait_ids: Array[StringName] = []) -> LifeCharacterData:
	life_stats = p_life_stats
	life_trait_ids = p_life_trait_ids.duplicate()
	return self


func to_dictionary() -> Dictionary:
	return {
		"life_stats": life_stats.to_core_dictionary() if life_stats != null else {},
		"life_trait_ids": life_trait_ids.duplicate(),
		"assigned_building_id": assigned_building_id,
		"assigned_job_id": assigned_job_id,
		"work_state": work_state,
		"work_state_name": CharacterEnumsScript.work_state_name(work_state),
		"work_experience": work_experience,
	}


func apply_dictionary(data: Dictionary) -> LifeCharacterData:
	life_stats = LifeStatsScript.from_dictionary(data.get("life_stats", {}))
	life_trait_ids = _to_string_name_array(data.get("life_trait_ids", []))
	assigned_building_id = StringName(data.get("assigned_building_id", &""))
	assigned_job_id = StringName(data.get("assigned_job_id", &""))
	work_state = clampi(int(data.get("work_state", CharacterEnumsScript.WorkState.IDLE)), CharacterEnumsScript.WorkState.IDLE, CharacterEnumsScript.WorkState.UNAVAILABLE)
	work_experience = max(0, int(data.get("work_experience", 0)))
	return self


static func from_dictionary(data: Dictionary) -> LifeCharacterData:
	return LifeCharacterData.new().apply_dictionary(data)


static func _to_string_name_array(values: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for value in values:
		result.append(StringName(value))
	return result

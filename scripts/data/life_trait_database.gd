class_name LifeTraitDatabase
extends RefCounted

const LifeTraitDefinitionScript := preload("res://scripts/data/life_trait_definition.gd")
const Stage12Config := preload("res://scripts/data/stage12_balance_config.gd")

var definitions: Dictionary = {}


func _init() -> void:
	for raw_trait_id in Stage12Config.LIFE_TRAIT_CONFIG.keys():
		var trait_id := StringName(raw_trait_id)
		var config: Dictionary = Stage12Config.LIFE_TRAIT_CONFIG[raw_trait_id]
		var applicable_job_types: Array[StringName] = []
		for raw_job_type in config.get("applicable_job_types", []):
			applicable_job_types.append(StringName(raw_job_type))
		_add(
			LifeTraitDefinitionScript.new().setup(
				trait_id,
				String(config.get("display_name", trait_id)),
				String(config.get("description", "")),
				applicable_job_types,
				float(config.get("efficiency_bonus_percent", 0.0)),
				float(config.get("work_experience_bonus_percent", 0.0)),
				float(config.get("production_bonus_percent", 0.0))
			)
		)


func get_definition(trait_id: StringName):
	return definitions.get(trait_id, null)


func get_definition_data(trait_id: StringName) -> Dictionary:
	var definition = get_definition(trait_id)
	return definition.to_dictionary() if definition != null else {}


func get_all_trait_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for raw_trait_id in definitions.keys():
		result.append(StringName(raw_trait_id))
	result.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b)
	)
	return result


func get_all_definition_data() -> Array:
	var result: Array = []
	for trait_id: StringName in get_all_trait_ids():
		result.append(get_definition_data(trait_id))
	return result


func get_bonus_totals(trait_ids: Array[StringName], job_type: StringName) -> Dictionary:
	var result := {
		"efficiency_bonus_percent": 0.0,
		"work_experience_bonus_percent": 0.0,
		"production_bonus_percent": 0.0,
		"applied_trait_ids": [],
	}
	for trait_id: StringName in trait_ids:
		var definition = get_definition(trait_id)
		if definition == null or not definition.applies_to_job(job_type):
			continue
		result["efficiency_bonus_percent"] += float(definition.efficiency_bonus_percent)
		result["work_experience_bonus_percent"] += float(definition.work_experience_bonus_percent)
		result["production_bonus_percent"] += float(definition.production_bonus_percent)
		result["applied_trait_ids"].append(trait_id)
	return result


func _add(definition) -> void:
	if definition == null or definition.trait_id == &"":
		return
	definitions[definition.trait_id] = definition

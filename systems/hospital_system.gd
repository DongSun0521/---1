class_name HospitalSystem
extends RefCounted

const HospitalProjectStateScript := preload("res://scripts/data/hospital_project_state.gd")

const PROJECT_TYPE_CRAFT_MEDICINE := &"craft_medicine"
const PROJECT_TYPE_TREAT_CHARACTER := &"treat_character"
const RECIPE_BASIC_MEDICINE := &"basic_medicine_recipe"
const INJURY_HEALTHY := &"healthy"
const INJURY_INJURED := &"injured"

const MEDICINE_RECIPE := {
	"project_id": RECIPE_BASIC_MEDICINE,
	"display_name": "Basic medicine",
	"description": "Craft medicine from stored herbs.",
	"project_type": PROJECT_TYPE_CRAFT_MEDICINE,
	"herb_cost": 2,
	"required_days": 1,
	"medicine_output": 1,
}


func create_initial_state():
	return HospitalProjectStateScript.new()


func get_medicine_recipe_data(game_state) -> Dictionary:
	var data: Dictionary = MEDICINE_RECIPE.duplicate(true)
	data["start_error"] = get_medicine_disabled_reason(game_state)
	return data


func is_hospital_busy(game_state) -> bool:
	return game_state.hospital_project_state != null and bool(game_state.hospital_project_state.is_active)


func get_active_project_type(game_state) -> StringName:
	if not is_hospital_busy(game_state):
		return &""
	return StringName(game_state.hospital_project_state.project_type)


func get_active_target_character_id(game_state) -> StringName:
	if not is_hospital_busy(game_state):
		return &""
	return StringName(game_state.hospital_project_state.target_character_id)


func is_character_injured(game_state, character_id: StringName) -> bool:
	var runtime_state = game_state.character_runtime_states.get(character_id, null)
	return runtime_state != null and StringName(runtime_state.injury_state) == INJURY_INJURED


func is_character_being_treated(game_state, character_id: StringName) -> bool:
	return is_hospital_busy(game_state) \
		and get_active_project_type(game_state) == PROJECT_TYPE_TREAT_CHARACTER \
		and get_active_target_character_id(game_state) == character_id


func can_start_medicine_production(game_state) -> bool:
	return get_medicine_disabled_reason(game_state).is_empty()


func get_medicine_disabled_reason(game_state) -> String:
	if is_hospital_busy(game_state):
		return "鍖婚櫌姝ｅ湪宸ヤ綔"
	if game_state.get_resource_amount("herb") < int(MEDICINE_RECIPE["herb_cost"]):
		return "鑽夎嵂涓嶈冻"
	return ""


func start_medicine_production(game_state) -> Dictionary:
	var error := get_medicine_disabled_reason(game_state)
	if not error.is_empty():
		return {"success": false, "error": error}

	var resources: Dictionary = game_state.resources
	resources["herb"] = int(resources["herb"]) - int(MEDICINE_RECIPE["herb_cost"])
	game_state.resources = resources
	game_state.hospital_project_state = HospitalProjectStateScript.new().setup(
		RECIPE_BASIC_MEDICINE,
		PROJECT_TYPE_CRAFT_MEDICINE,
		int(MEDICINE_RECIPE["required_days"]),
		&""
	)
	return {
		"success": true,
		"project_type": PROJECT_TYPE_CRAFT_MEDICINE,
		"project_id": RECIPE_BASIC_MEDICINE,
	}


func can_treat_character(game_state, character_id: StringName) -> bool:
	return get_treatment_disabled_reason(game_state, character_id).is_empty()


func get_treatment_disabled_reason(game_state, character_id: StringName) -> String:
	if is_hospital_busy(game_state):
		if is_character_being_treated(game_state, character_id):
			return "Already being treated"
		if get_active_project_type(game_state) == PROJECT_TYPE_CRAFT_MEDICINE:
			return "Hospital is crafting medicine"
		return "Hospital is treating another character"
	if not game_state.character_runtime_states.has(character_id):
		return "Unknown character"
	if not is_character_injured(game_state, character_id):
		return "No treatment needed"
	if game_state.get_resource_amount("herb") < 1:
		return "Not enough herbs"
	return ""

func start_treatment(game_state, character_id: StringName) -> Dictionary:
	var error := get_treatment_disabled_reason(game_state, character_id)
	if not error.is_empty():
		return {"success": false, "error": error, "character_id": character_id}

	var resources: Dictionary = game_state.resources
	resources["herb"] = int(resources["herb"]) - 1
	game_state.resources = resources
	game_state.hospital_project_state = HospitalProjectStateScript.new().setup(
		&"treat_%s" % String(character_id),
		PROJECT_TYPE_TREAT_CHARACTER,
		1,
		character_id
	)
	return {
		"success": true,
		"project_type": PROJECT_TYPE_TREAT_CHARACTER,
		"target_character_id": character_id,
	}


func process_daily_hospital(game_state) -> Dictionary:
	var report := _empty_daily_report()
	if not is_hospital_busy(game_state):
		return report

	var state = game_state.hospital_project_state
	report["had_active_hospital"] = true
	report["hospital_project_type"] = state.project_type
	report["hospital_project_id"] = state.project_id
	report["treated_character_id"] = state.target_character_id
	report["hospital_progress_before"] = int(state.progress_days)
	report["hospital_required_days"] = int(state.required_days)

	state.progress_days += 1
	report["hospital_progress_after"] = int(state.progress_days)

	if int(state.progress_days) >= int(state.required_days) and not bool(state.result_processed):
		state.result_processed = true
		report["hospital_project_completed"] = true
		if StringName(state.project_type) == PROJECT_TYPE_CRAFT_MEDICINE:
			var base_amount := int(MEDICINE_RECIPE["medicine_output"])
			var amount: int = game_state.calculate_building_production_output(
				&"hospital", base_amount
			)
			var resources: Dictionary = game_state.resources
			resources["medicine"] = int(resources["medicine"]) + amount
			game_state.resources = resources
			report["base_medicine_output"] = base_amount
			report["medicine_produced"] = amount
		elif StringName(state.project_type) == PROJECT_TYPE_TREAT_CHARACTER:
			complete_character_treatment(game_state, StringName(state.target_character_id))
			report["treatment_completed"] = true
		report["production_details"] = game_state.get_building_production_details(&"hospital")
		report["work_experience_results"] = game_state.settle_life_job_work_experience(
			&"hospital",
			StringName("hospital_%s_day_%d" % [
				String(report.get("hospital_project_id", &"")),
				int(game_state.current_day),
			])
		)
		game_state.record_life_work_feedback(&"hospital", report)
		state.clear()

	game_state.hospital_project_state = state
	return report


func process_expedition_injuries(game_state, failure: bool, snapshots: Array = []) -> Array:
	return process_expedition_injuries_for_characters(
		game_state,
		failure,
		game_state.get_character_ids(),
		snapshots
	)


func process_expedition_injuries_for_characters(
	game_state,
	failure: bool,
	character_ids: Array,
	snapshots: Array = []
) -> Array:
	var results: Array = []
	if failure:
		for raw_character_id in character_ids:
			var character_id := StringName(raw_character_id)
			results.append(_apply_injury_result(game_state, character_id, 0, max(1, int(game_state.get_final_combat_stats(character_id).get("max_hp", 1))), &"expedition_failed", true))
		return results

	for snapshot: Dictionary in snapshots:
		var character_id: StringName = StringName(snapshot.get("character_id", &""))
		if character_id == &"":
			continue
		var hp: int = int(snapshot.get("return_hp", 0))
		var max_hp: int = max(1, int(snapshot.get("return_max_hp", 1)))
		var should_injure: bool = hp <= 0 or (float(hp) / float(max_hp)) <= 0.5
		var reason: StringName = &"low_hp" if should_injure else &"none"
		results.append(_apply_injury_result(game_state, character_id, hp, max_hp, reason, should_injure))
	return results


func complete_character_treatment(game_state, character_id: StringName) -> void:
	set_character_injury_state(game_state, character_id, INJURY_HEALTHY)
	game_state.restore_character_runtime_state_full(character_id)


func set_character_injury_state(game_state, character_id: StringName, injury_state: StringName) -> bool:
	if not game_state.character_runtime_states.has(character_id):
		return false
	var runtime_state = game_state.character_runtime_states[character_id]
	if StringName(runtime_state.injury_state) == injury_state:
		return false
	runtime_state.injury_state = injury_state
	game_state.character_runtime_states[character_id] = runtime_state
	return true


func get_active_summary(game_state) -> String:
	if not is_hospital_busy(game_state):
		return "Idle"
	var state: RefCounted = game_state.hospital_project_state
	var remaining: int = max(0, int(state.required_days) - int(state.progress_days))
	if StringName(state.project_type) == PROJECT_TYPE_CRAFT_MEDICINE:
		return "Crafting medicine\n%d day(s) remaining" % remaining
	var name: String = game_state.get_character_display_name(StringName(state.target_character_id))
	return "Treating: %s\n%d day(s) remaining" % [name, remaining]

func get_project_state(game_state) -> Dictionary:
	if game_state.hospital_project_state == null:
		return {}
	var data: Dictionary = game_state.hospital_project_state.to_dictionary()
	if not bool(data.get("is_active", false)):
		return data
	if StringName(data.get("project_type", &"")) == PROJECT_TYPE_CRAFT_MEDICINE:
		data["display_name"] = String(MEDICINE_RECIPE["display_name"])
	elif StringName(data.get("project_type", &"")) == PROJECT_TYPE_TREAT_CHARACTER:
		data["display_name"] = "娌荤枟%s" % game_state.get_character_display_name(StringName(data.get("target_character_id", &"")))
	return data


func _apply_injury_result(game_state, character_id: StringName, hp: int, max_hp: int, reason: StringName, should_injure: bool) -> Dictionary:
	var previous := INJURY_HEALTHY
	var runtime_state = game_state.character_runtime_states.get(character_id, null)
	if runtime_state != null:
		previous = StringName(runtime_state.injury_state)
	if should_injure:
		set_character_injury_state(game_state, character_id, INJURY_INJURED)
	var new_state := previous
	runtime_state = game_state.character_runtime_states.get(character_id, null)
	if runtime_state != null:
		new_state = StringName(runtime_state.injury_state)
	game_state.restore_character_runtime_state_full(character_id)
	return {
		"character_id": character_id,
		"previous_injury_state": previous,
		"new_injury_state": new_state,
		"return_hp": hp,
		"return_max_hp": max_hp,
		"return_hp_ratio": float(hp) / float(max_hp),
		"injury_reason": reason,
	}


func _empty_daily_report() -> Dictionary:
	return {
		"had_active_hospital": false,
		"hospital_project_type": &"",
		"hospital_project_id": &"",
		"hospital_progress_before": 0,
		"hospital_progress_after": 0,
		"hospital_required_days": 0,
		"hospital_project_completed": false,
		"base_medicine_output": 0,
		"medicine_produced": 0,
		"treated_character_id": &"",
		"treatment_completed": false,
		"production_details": {},
		"work_experience_results": [],
	}

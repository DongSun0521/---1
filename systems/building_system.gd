class_name BuildingSystem
extends RefCounted

const BuildingDataScript := preload("res://scripts/data/building_data.gd")
const Stage12Config := preload("res://scripts/data/stage12_balance_config.gd")

const BUILDING_IDS: Array[StringName] = [
	&"research_lab",
	&"residence",
	&"farm",
	&"food_workshop",
	&"weapon_forge",
	&"hospital",
	&"resource_collection",
]

const STATE_KEY_BY_ID := {
	&"research_lab": "research_lab",
	&"residence": "residence",
	&"farm": "farm",
	&"food_workshop": "food_workshop",
	&"weapon_forge": "workshop",
	&"hospital": "clinic",
	&"resource_collection": "resource_collection",
}

const DEFAULT_JOB_SLOT_COUNT_BY_LEVEL := Stage12Config.DEFAULT_JOB_SLOT_COUNT_BY_LEVEL
const JOB_SLOT_COUNT_OVERRIDE_BY_BUILDING := Stage12Config.JOB_SLOT_COUNT_OVERRIDE_BY_BUILDING
const JOB_CONFIG_BY_BUILDING := Stage12Config.JOB_CONFIG_BY_BUILDING

var building_data_by_id: Dictionary = {}


func _init() -> void:
	_build_data()


func get_building_ids() -> Array[StringName]:
	return BUILDING_IDS.duplicate()


func get_building_data(building_id: StringName):
	return building_data_by_id.get(building_id, null)


func get_job_slot_count_for_level(building_id: StringName, level: int) -> int:
	if not JOB_CONFIG_BY_BUILDING.has(building_id):
		return 0
	var count_config: Dictionary = JOB_SLOT_COUNT_OVERRIDE_BY_BUILDING.get(
		building_id, DEFAULT_JOB_SLOT_COUNT_BY_LEVEL
	)
	return max(0, int(count_config.get(clampi(level, 1, 4), 0)))


func get_job_slot_count_config(building_id: StringName) -> Dictionary:
	if not JOB_CONFIG_BY_BUILDING.has(building_id):
		return {}
	return JOB_SLOT_COUNT_OVERRIDE_BY_BUILDING.get(
		building_id, DEFAULT_JOB_SLOT_COUNT_BY_LEVEL
	).duplicate(true)


func get_all_building_data() -> Array:
	var result: Array = []
	for building_id: StringName in BUILDING_IDS:
		result.append(get_building_data(building_id))
	return result


func get_building_jobs(game_state: Node, building_id: StringName) -> Array:
	if get_building_data(building_id) == null:
		return []
	ensure_initial_runtime_state(game_state)
	var state_key := _get_state_key(building_id)
	var state: Dictionary = game_state.buildings.get(state_key, {})
	return state.get("jobs", []).duplicate(true)


func get_building_job(game_state: Node, building_id: StringName, job_id: StringName) -> Dictionary:
	for job: Dictionary in get_building_jobs(game_state, building_id):
		if StringName(job.get("job_id", &"")) == job_id:
			return job
	return {}


func set_job_character_id(
	game_state: Node,
	building_id: StringName,
	job_id: StringName,
	character_id: StringName
) -> bool:
	if get_building_data(building_id) == null:
		return false
	ensure_initial_runtime_state(game_state)
	var state_key := _get_state_key(building_id)
	var state: Dictionary = game_state.buildings.get(state_key, {})
	var jobs: Array = state.get("jobs", []).duplicate(true)
	for index: int in range(jobs.size()):
		var job: Dictionary = jobs[index]
		if StringName(job.get("job_id", &"")) != job_id:
			continue
		job["character_id"] = character_id
		jobs[index] = job
		state["jobs"] = jobs
		game_state.buildings[state_key] = state
		return true
	return false


func get_character_job_references(game_state: Node, character_id: StringName) -> Array:
	var result: Array = []
	if character_id == &"":
		return result
	for building_id: StringName in BUILDING_IDS:
		for job: Dictionary in get_building_jobs(game_state, building_id):
			if StringName(job.get("character_id", &"")) != character_id:
				continue
			result.append({
				"building_id": building_id,
				"job_id": StringName(job.get("job_id", &"")),
				"job_type": StringName(job.get("job_type", &"")),
			})
	return result


func clear_character_job_references(game_state: Node, character_id: StringName) -> Array[StringName]:
	var changed_buildings: Array[StringName] = []
	for reference: Dictionary in get_character_job_references(game_state, character_id):
		var building_id := StringName(reference.get("building_id", &""))
		var job_id := StringName(reference.get("job_id", &""))
		if set_job_character_id(game_state, building_id, job_id, &"") and not changed_buildings.has(building_id):
			changed_buildings.append(building_id)
	return changed_buildings


func ensure_initial_runtime_state(game_state: Node) -> void:
	for building_id: StringName in BUILDING_IDS:
		var data = get_building_data(building_id)
		var state_key := _get_state_key(building_id)
		if game_state.buildings.has(state_key):
			var existing_state: Dictionary = game_state.buildings[state_key]
			existing_state["level"] = clampi(int(existing_state.get("level", 1)), 1, int(data.max_level))
			existing_state["jobs"] = _normalize_runtime_jobs(
				building_id,
				existing_state.get("jobs", []),
				int(existing_state["level"])
			)
			game_state.buildings[state_key] = existing_state
			continue
		game_state.buildings[state_key] = {
			"display_name": data.display_name,
			"level": 1,
			"status": _default_status(building_id),
			"jobs": _normalize_runtime_jobs(building_id, [], 1),
		}


func get_runtime_state(game_state: Node, building_id: StringName) -> Dictionary:
	var data = get_building_data(building_id)
	if data == null:
		return {}

	var state_key := _get_state_key(building_id)
	var raw_state: Dictionary = game_state.buildings.get(state_key, {}).duplicate(true)
	var level := clampi(int(raw_state.get("level", 1)), 1, int(data.max_level))
	var work_state := _get_work_state(game_state, building_id, raw_state)
	var project := _get_project_state(game_state, building_id)
	var jobs: Array = raw_state.get("jobs", []).duplicate(true)
	var filled_job_count := 0
	for job: Dictionary in jobs:
		if StringName(job.get("character_id", &"")) != &"":
			filled_job_count += 1
	return {
		"building_id": building_id,
		"state_key": state_key,
		"display_name": data.display_name,
		"level": level,
		"is_unlocked": true,
		"work_state": work_state,
		"status": _get_status_text(game_state, building_id, raw_state, work_state),
		"active_project_id": StringName(project.get("project_id", &"")),
		"project_display_name": String(project.get("display_name", "")),
		"project_progress_days": int(project.get("progress_days", 0)),
		"project_required_days": int(project.get("required_days", 0)),
		"has_completed_output": bool(project.get("completed", false)),
		"jobs": jobs,
		"job_count": jobs.size(),
		"filled_job_count": filled_job_count,
	}


func set_building_level(game_state: Node, building_id: StringName, level: int) -> bool:
	var data = get_building_data(building_id)
	if data == null:
		return false
	if level < 1 or level > int(data.max_level):
		return false
	if building_id == &"farm" and not game_state.farm_system.can_set_farm_level(game_state, level):
		return false
	var state_key := _get_state_key(building_id)
	if not game_state.buildings.has(state_key):
		ensure_initial_runtime_state(game_state)
	var state: Dictionary = game_state.buildings.get(state_key, {})
	if int(state.get("level", 1)) == level:
		return false
	state["level"] = level
	game_state.buildings[state_key] = state
	return true


func sync_runtime_jobs_for_building(game_state: Node, building_id: StringName) -> Dictionary:
	var data = get_building_data(building_id)
	if data == null:
		return {"success": false}
	var state_key := _get_state_key(building_id)
	if not game_state.buildings.has(state_key):
		ensure_initial_runtime_state(game_state)
	var state: Dictionary = game_state.buildings.get(state_key, {})
	var level := clampi(int(state.get("level", 1)), 1, int(data.max_level))
	var old_jobs: Array = state.get("jobs", []).duplicate(true)
	var new_jobs: Array = _normalize_runtime_jobs(building_id, old_jobs, level)
	state["level"] = level
	state["jobs"] = new_jobs
	game_state.buildings[state_key] = state

	var retained_character_ids: Array[StringName] = []
	for job: Dictionary in new_jobs:
		var retained_id := StringName(job.get("character_id", &""))
		if retained_id != &"" and not retained_character_ids.has(retained_id):
			retained_character_ids.append(retained_id)
	var removed_character_ids: Array[StringName] = []
	for job: Dictionary in old_jobs:
		var removed_id := StringName(job.get("character_id", &""))
		if removed_id == &"" \
				or retained_character_ids.has(removed_id) \
				or removed_character_ids.has(removed_id):
			continue
		removed_character_ids.append(removed_id)
	return {
		"success": true,
		"building_id": building_id,
		"level": level,
		"old_job_count": old_jobs.size(),
		"new_job_count": new_jobs.size(),
		"job_count_changed": old_jobs.size() != new_jobs.size(),
		"removed_character_ids": removed_character_ids,
	}


func _get_state_key(building_id: StringName) -> String:
	return String(STATE_KEY_BY_ID.get(building_id, String(building_id)))


func _normalize_runtime_jobs(building_id: StringName, saved_jobs, level: int) -> Array:
	var saved_character_by_job: Dictionary = {}
	if saved_jobs is Array:
		for saved_job in saved_jobs:
			if not saved_job is Dictionary:
				continue
			var saved_job_id := StringName(saved_job.get("job_id", &""))
			if saved_job_id == &"" or saved_character_by_job.has(saved_job_id):
				continue
			saved_character_by_job[saved_job_id] = StringName(saved_job.get("character_id", &""))
	var result: Array = []
	var templates: Array = JOB_CONFIG_BY_BUILDING.get(building_id, [])
	if templates.is_empty():
		return result
	var slot_count := get_job_slot_count_for_level(building_id, level)
	for slot_index: int in range(slot_count):
		var config: Dictionary = templates[mini(slot_index, templates.size() - 1)]
		var base_job_id := StringName(config.get("job_id", &""))
		var job_id := base_job_id if slot_index == 0 else StringName(
			"%s_%d" % [String(base_job_id), slot_index + 1]
		)
		var display_name := String(config.get("display_name", String(base_job_id)))
		if slot_index > 0:
			display_name = "%s %d" % [display_name, slot_index + 1]
		result.append({
			"job_id": job_id,
			"job_type": StringName(config.get("job_type", &"")),
			"display_name": display_name,
			"slot_index": slot_index,
			"character_id": StringName(saved_character_by_job.get(job_id, &"")),
		})
	return result


func _get_work_state(game_state: Node, building_id: StringName, _raw_state: Dictionary) -> StringName:
	match building_id:
		&"farm":
			return game_state.farm_system.get_work_state(game_state)
		&"weapon_forge":
			var forge_state: Dictionary = game_state.get_forge_state()
			if bool(forge_state.get("is_active", false)):
				return &"working"
			if bool(game_state.get_last_forge_report().get("forge_completed", false)):
				return &"completed"
			return &"idle"
		&"hospital":
			return &"working" if game_state.is_hospital_busy() else &"idle"
		&"food_workshop":
			var food_state: Dictionary = game_state.get_food_production_state()
			if bool(food_state.get("is_active", false)):
				return &"working"
			return &"idle"
		&"research_lab", &"residence", &"resource_collection":
			return &"unavailable"
	return &"idle"


func _get_status_text(game_state: Node, building_id: StringName, raw_state: Dictionary, work_state: StringName) -> String:
	match building_id:
		&"farm":
			return game_state.farm_system.get_status_text(game_state)
		&"weapon_forge":
			return game_state.get_active_forge_summary()
		&"hospital":
			return "正常运行"
		&"food_workshop":
			return "功能准备中"
		_:
			if work_state == &"unavailable":
				return "暂未开放"
	return String(raw_state.get("status", _default_status(building_id)))


func _get_project_state(game_state: Node, building_id: StringName) -> Dictionary:
	if building_id == &"hospital":
		var hospital_state: Dictionary = game_state.get_hospital_project_state()
		if not bool(hospital_state.get("is_active", false)):
			return {}
		return {
			"project_id": StringName(hospital_state.get("project_id", &"")),
			"display_name": String(hospital_state.get("display_name", "Hospital project")),
			"progress_days": int(hospital_state.get("progress_days", 0)),
			"required_days": int(hospital_state.get("required_days", 0)),
			"completed": false,
		}
	if building_id == &"food_workshop":
		var food_state: Dictionary = game_state.get_food_production_state()
		if not bool(food_state.get("is_active", false)):
			return {}
		var recipe_id: StringName = StringName(food_state.get("recipe_id", &""))
		var recipe: Dictionary = game_state.get_food_recipe_data(recipe_id)
		return {
			"project_id": recipe_id,
			"display_name": String(recipe.get("display_name", "食物制造")),
			"progress_days": int(food_state.get("progress_days", 0)),
			"required_days": int(food_state.get("required_days", 0)),
			"completed": false,
		}
	if building_id != &"weapon_forge":
		return {}
	var forge_state: Dictionary = game_state.get_forge_state()
	if not bool(forge_state.get("is_active", false)):
		var last_report: Dictionary = game_state.get_last_forge_report()
		if not bool(last_report.get("forge_completed", false)):
			return {}
		return {
			"project_id": StringName(last_report.get("recipe_id", &"")),
			"display_name": String(last_report.get("display_name", "装备打造")),
			"progress_days": int(last_report.get("required_days", 0)),
			"required_days": int(last_report.get("required_days", 0)),
			"completed": true,
		}
	var recipe_id: StringName = StringName(forge_state.get("active_recipe_id", &""))
	var recipe: Dictionary = game_state.get_forge_recipe_data(recipe_id)
	return {
		"project_id": recipe_id,
		"display_name": String(recipe.get("display_name", "装备打造")),
		"progress_days": int(forge_state.get("progress_days", 0)),
		"required_days": int(forge_state.get("required_days", 0)),
		"completed": false,
	}


func _default_status(building_id: StringName) -> String:
	match building_id:
		&"farm":
			return "正常生产"
		&"hospital":
			return "正常运行"
		&"weapon_forge":
			return "等待打造"
		&"food_workshop":
			return "功能准备中"
	return "暂未开放"


func _build_data() -> void:
	building_data_by_id[&"research_lab"] = BuildingDataScript.new().setup(
		&"research_lab",
		"科研所",
		"后续用于研究科技、解锁建筑能力、解锁配方和分析野外遗物。",
		"res://assets/art/buildings/KeYanSuo_sheet.png",
		Vector2(0.51, 0.38),
		Vector2(0.34, 0.34),
		Vector2.ZERO,
		Vector2(0, -112),
		Vector2(180, 130),
		Vector2(0, 12),
		&"info",
		false
	)
	building_data_by_id[&"residence"] = BuildingDataScript.new().setup(
		&"residence",
		"民居",
		"后续用于提高人口上限、管理居民和查看生活角色。",
		"res://assets/art/buildings/MinJun_sheet.png",
		Vector2(0.54, 0.75),
		Vector2(0.32, 0.32),
		Vector2.ZERO,
		Vector2(0, -104),
		Vector2(170, 128),
		Vector2(0, 14),
		&"info",
		false
	)
	building_data_by_id[&"farm"] = BuildingDataScript.new().setup(
		&"farm",
		"农田",
		"按现有规则生产粮食。种植与作物选择将在10B阶段开放。",
		"res://assets/art/buildings/NongTian_sheet.png",
		Vector2(0.25, 0.37),
		Vector2(0.42, 0.42),
		Vector2.ZERO,
		Vector2(0, -118),
		Vector2(235, 140),
		Vector2(0, 20),
		&"farm",
		true
	)
	building_data_by_id[&"food_workshop"] = BuildingDataScript.new().setup(
		&"food_workshop",
		"食物制造所",
		"料理、远征口粮和特殊食物将在10C阶段开放。",
		"res://assets/art/buildings/ShiWu_sheet.png",
		Vector2(0.80, 0.65),
		Vector2(0.32, 0.32),
		Vector2.ZERO,
		Vector2(0, -108),
		Vector2(190, 132),
		Vector2(0, 12),
		&"info",
		false
	)
	building_data_by_id[&"weapon_forge"] = BuildingDataScript.new().setup(
		&"weapon_forge",
		"武器制造所",
		"消耗资源打造固定装备，继续使用第9阶段已经完成的装备制造系统。",
		"res://assets/art/buildings/WuQi_sheet.png",
		Vector2(0.66, 0.10),
		Vector2(0.34, 0.34),
		Vector2.ZERO,
		Vector2(0, -116),
		Vector2(185, 132),
		Vector2(0, 12),
		&"weapon_forge",
		true
	)
	building_data_by_id[&"hospital"] = BuildingDataScript.new().setup(
		&"hospital",
		"医院",
		"保留现有药品生产逻辑。主动制作药品和伤员治疗将在10D阶段开放。",
		"res://assets/art/buildings/YiYuan_sheet.png",
		Vector2(0.84, 0.26),
		Vector2(0.34, 0.34),
		Vector2.ZERO,
		Vector2(0, -116),
		Vector2(185, 132),
		Vector2(0, 12),
		&"hospital",
		true
	)
	building_data_by_id[&"resource_collection"] = BuildingDataScript.new().setup(
		&"resource_collection",
		"资源收集所",
		"后续用于安排资源采集、开发已探索区域并获得矿石、木材和其他资源。",
		"res://assets/art/buildings/ZiYuanShoujiSuo_sheet.png",
		Vector2(0.22, 0.74),
		Vector2(0.34, 0.34),
		Vector2.ZERO,
		Vector2(0, -112),
		Vector2(190, 132),
		Vector2(0, 12),
		&"info",
		false
	)

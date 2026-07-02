class_name ProjectSystem
extends RefCounted

const NO_ACTIVE_PROJECT: StringName = &""

const PROJECTS: Dictionary = {
	&"farm_expansion": {
		"display_name": "农田扩建",
		"required_days": 2,
		"ore_cost": 3,
		"herb_cost": 1,
		"description": "完成后农田升到2级，每日粮食产量变为6。"
	},
	&"hospital_expansion": {
		"display_name": "医院扩建",
		"required_days": 2,
		"ore_cost": 0,
		"herb_cost": 3,
		"description": "完成后医院升到2级，每天制作1药品。"
	},
	&"weapon_upgrade": {
		"display_name": "武器强化",
		"required_days": 3,
		"ore_cost": 4,
		"herb_cost": 0,
		"description": "完成后固定冒险队攻击力+2。"
	},
	&"armor_upgrade": {
		"display_name": "护甲强化",
		"required_days": 3,
		"ore_cost": 3,
		"herb_cost": 1,
		"description": "完成后固定冒险队最大生命+6，存活成员当前生命+6。"
	}
}


func create_initial_state() -> Dictionary:
	return {
		"active_project_id": NO_ACTIVE_PROJECT,
		"active_project_progress": 0,
		"completed_project_ids": []
	}


func get_project_config(project_id: StringName) -> Dictionary:
	return PROJECTS.get(project_id, {})


func get_all_project_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for project_id: StringName in PROJECTS.keys():
		ids.append(project_id)
	return ids


func can_start_project(game_state: Node, project_id: StringName) -> bool:
	return get_start_error(game_state, project_id).is_empty()


func get_start_error(game_state: Node, project_id: StringName) -> String:
	var project_config: Dictionary = get_project_config(project_id)
	if project_config.is_empty():
		return "未知项目"
	if game_state.project_state.get("active_project_id", NO_ACTIVE_PROJECT) != NO_ACTIVE_PROJECT:
		return "已有进行中的项目"
	if game_state.project_state.get("completed_project_ids", []).has(project_id):
		return "项目已完成"
	if int(game_state.resources.get("ore", 0)) < int(project_config.get("ore_cost", 0)):
		return "矿石不足"
	if int(game_state.resources.get("herb", 0)) < int(project_config.get("herb_cost", 0)):
		return "草药不足"
	return ""


func start_project(game_state: Node, project_id: StringName) -> Dictionary:
	var error_message: String = get_start_error(game_state, project_id)
	if not error_message.is_empty():
		return {
			"success": false,
			"project_id": project_id,
			"error": error_message
		}

	var project_config: Dictionary = get_project_config(project_id)
	game_state.resources["ore"] = int(game_state.resources.get("ore", 0)) - int(project_config.get("ore_cost", 0))
	game_state.resources["herb"] = int(game_state.resources.get("herb", 0)) - int(project_config.get("herb_cost", 0))
	game_state.project_state["active_project_id"] = project_id
	game_state.project_state["active_project_progress"] = 0

	return {
		"success": true,
		"project_id": project_id,
		"display_name": String(project_config.get("display_name", "")),
		"required_days": int(project_config.get("required_days", 0)),
		"ore_cost": int(project_config.get("ore_cost", 0)),
		"herb_cost": int(project_config.get("herb_cost", 0))
	}


func process_daily_project(game_state: Node) -> Dictionary:
	var active_project_id: StringName = game_state.project_state.get("active_project_id", NO_ACTIVE_PROJECT)
	if active_project_id == NO_ACTIVE_PROJECT:
		return {
			"had_active_project": false,
			"project_completed": false
		}

	var project_config: Dictionary = get_project_config(active_project_id)
	var required_days: int = int(project_config.get("required_days", 0))
	var progress_before: int = int(game_state.project_state.get("active_project_progress", 0))
	var progress_after: int = progress_before + 1
	var completed: bool = progress_after >= required_days

	game_state.project_state["active_project_progress"] = progress_after

	var report: Dictionary = {
		"had_active_project": true,
		"project_completed": completed,
		"project_id": active_project_id,
		"display_name": String(project_config.get("display_name", "")),
		"progress_before": progress_before,
		"progress_after": min(progress_after, required_days),
		"required_days": required_days,
		"effect_text": ""
	}

	if completed:
		report["effect_text"] = _apply_project_completion(game_state, active_project_id)
		var completed_ids: Array = game_state.project_state.get("completed_project_ids", [])
		if not completed_ids.has(active_project_id):
			completed_ids.append(active_project_id)
		game_state.project_state["completed_project_ids"] = completed_ids
		game_state.project_state["active_project_id"] = NO_ACTIVE_PROJECT
		game_state.project_state["active_project_progress"] = 0
		game_state.statistics["total_projects_completed"] = int(game_state.statistics.get("total_projects_completed", 0)) + 1

	return report


func get_active_project_summary(game_state: Node) -> String:
	var active_project_id: StringName = game_state.project_state.get("active_project_id", NO_ACTIVE_PROJECT)
	if active_project_id == NO_ACTIVE_PROJECT:
		return "当前没有进行中的项目"

	var project_config: Dictionary = get_project_config(active_project_id)
	var progress: int = int(game_state.project_state.get("active_project_progress", 0))
	var required_days: int = int(project_config.get("required_days", 0))
	return "%s：%d/%d天" % [String(project_config.get("display_name", "")), progress, required_days]


func _apply_project_completion(game_state: Node, project_id: StringName) -> String:
	match project_id:
		&"farm_expansion":
			var farm: Dictionary = game_state.buildings.get("farm", {})
			farm["level"] = 2
			farm["daily_food_production"] = 6
			game_state.buildings["farm"] = farm
			return "农田升到2级，每日粮食产量变为6。"
		&"hospital_expansion":
			var clinic: Dictionary = game_state.buildings.get("clinic", {})
			clinic["level"] = 2
			clinic["medicine_progress"] = 0
			clinic["medicine_progress_required"] = 1
			clinic["medicine_output"] = 1
			game_state.buildings["clinic"] = clinic
			return "医院升到2级，每天制作1药品。"
		&"weapon_upgrade":
			game_state.apply_party_attack_bonus(2)
			return "固定冒险队攻击力+2。"
		&"armor_upgrade":
			game_state.apply_party_max_hp_bonus(6)
			return "固定冒险队最大生命+6，存活成员当前生命+6。"
		_:
			return ""

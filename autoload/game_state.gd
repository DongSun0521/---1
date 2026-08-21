extends Node

signal state_changed
signal resources_changed
signal day_changed(current_day: int)
signal day_advanced(new_day: int)
signal building_state_changed(building_id: StringName)
signal building_level_changed(building_id: StringName, new_level: int)
signal building_selected(building_id: StringName)
signal building_project_changed(building_id: StringName)
signal building_visual_refresh_requested(building_id: StringName)
signal farm_state_changed
signal farm_plot_changed(plot_id: int)
signal crop_assigned(plot_id: int, crop_id: StringName)
signal crop_harvested(plot_id: int, crop_id: StringName, resource_id: StringName, amount: int)
signal daily_report_generated(report: Dictionary)
signal expedition_started
signal expedition_state_changed
signal expedition_action_completed(action_report: Dictionary)
signal expedition_ended(report: Dictionary)
signal current_node_changed(node_id: StringName)
signal supplies_changed
signal battle_started(encounter_id: StringName)
signal battle_state_changed
signal active_unit_changed(unit_id: StringName)
signal battle_finished(result: Dictionary)
signal project_started(report: Dictionary)
signal project_progress_changed(report: Dictionary)
signal project_completed(report: Dictionary)
signal village_upgrades_changed
signal party_upgrades_changed
signal boss_defeated_changed
signal mvp_completed(summary: Dictionary)
signal character_data_changed(character_id: StringName)
signal character_runtime_state_changed(character_id: StringName)
signal character_final_stats_changed(character_id: StringName)
signal equipment_inventory_changed
signal character_equipment_changed(character_id: StringName)
signal forge_project_started(report: Dictionary)
signal forge_progress_changed(report: Dictionary)
signal forge_project_completed(report: Dictionary)
signal forge_state_changed
signal food_workshop_state_changed
signal food_recipe_started(recipe_id: StringName)
signal food_recipe_completed(recipe_id: StringName, output_item_id: StringName, amount: int)
signal stackable_item_count_changed(item_id: StringName, new_count: int)
signal expedition_meal_changed(meal_id: StringName)
signal hospital_state_changed
signal hospital_project_started(project_type: StringName, target_character_id: StringName)
signal medicine_production_completed(amount: int)
signal character_injury_changed(character_id: StringName, injury_state: StringName)
signal character_treatment_started(character_id: StringName)
signal character_treatment_completed(character_id: StringName)
signal character_roster_changed
signal life_job_assignments_changed(building_id: StringName)
signal life_character_experience_changed(character_id: StringName, experience: int, required: int)
signal life_character_leveled_up(character_id: StringName, new_level: int, growth_by_stat: Dictionary)
signal life_work_settled(building_id: StringName, results: Array)
signal life_recruitment_candidates_changed
signal life_character_recruited(character_id: StringName)
signal life_character_dismissed(character_id: StringName)
signal life_character_lock_changed(character_id: StringName, is_locked: bool)
signal life_character_capacity_changed(current_count: int, capacity: int)
signal gameplay_notification_added(notification: Dictionary)
signal life_work_feedback_changed(building_id: StringName, feedback: Dictionary)

const VillageSystemScript := preload("res://systems/village_system.gd")
const ExpeditionSystemScript := preload("res://systems/expedition_system.gd")
const BattleSystemScript := preload("res://systems/battle_system.gd")
const ProjectSystemScript := preload("res://systems/project_system.gd")
const BuildingSystemScript := preload("res://systems/building_system.gd")
const FarmSystemScript := preload("res://systems/farm_system.gd")
const CharacterDatabaseScript := preload("res://scripts/data/character_database.gd")
const EquipmentSystemScript := preload("res://systems/equipment_system.gd")
const ForgeSystemScript := preload("res://systems/forge_system.gd")
const FoodWorkshopSystemScript := preload("res://systems/food_workshop_system.gd")
const HospitalSystemScript := preload("res://systems/hospital_system.gd")
const DailyReportScript := preload("res://scripts/data/daily_report.gd")
const CharacterRosterScript := preload("res://systems/character_roster.gd")
const SaveSystemScript := preload("res://systems/save_system.gd")
const CharacterEnumsScript := preload("res://scripts/data/character_enums.gd")
const LifeTraitDatabaseScript := preload("res://scripts/data/life_trait_database.gd")
const LifeStatsScript := preload("res://scripts/data/life_stats.gd")
const LifeRecruitmentSystemScript := preload("res://systems/life_recruitment_system.gd")
const Stage12Config := preload("res://scripts/data/stage12_balance_config.gd")

const INITIAL_DAY := 1
const BATTLE_EXPERIENCE_NORMAL := Stage12Config.BATTLE_EXPERIENCE_REWARDS["normal_victory"]
const BATTLE_EXPERIENCE_BOSS := Stage12Config.BATTLE_EXPERIENCE_REWARDS["boss_victory"]
const BATTLE_EXPERIENCE_DEFEAT := Stage12Config.BATTLE_EXPERIENCE_REWARDS["defeat"]
const LIFE_JOB_STAT_BONUS_PER_POINT := Stage12Config.LIFE_JOB_STAT_BONUS_PER_POINT
const LIFE_JOB_PREVIEW_STAT_CAP := LifeStatsScript.CORE_STAT_CAP
const LIFE_WORK_BASE_EXPERIENCE := Stage12Config.LIFE_WORK_BASE_EXPERIENCE
const INITIAL_RESOURCES := {
	"food": 20,
	"medicine": 3,
	"ore": 0,
	"herb": 0,
	"boss_core": 0,
}
const INITIAL_STACKABLE_ITEMS := {
	&"expedition_ration": 6,
	&"hearty_stew": 0,
	&"hunter_roast": 0,
}
const STACKABLE_ITEM_LABELS := {
	&"expedition_ration": "远征口粮",
	&"hearty_stew": "丰盛炖汤",
	&"hunter_roast": "猎手烤肉",
}
const RESOURCE_LABELS := {
	"food": "粮食",
	"medicine": "药品",
	"ore": "矿石",
	"herb": "草药",
	"boss_core": "Boss核心",
}
const INITIAL_ADVENTURERS := [
	{
		"name": "鎴樺＋",
		"max_hp": 30,
		"current_hp": 30,
		"attack": 5,
		"defense": 3,
	},
	{
		"name": "鐚庝汉",
		"max_hp": 22,
		"current_hp": 22,
		"attack": 7,
		"defense": 1,
	},
	{
		"name": "娉曞笀",
		"max_hp": 18,
		"current_hp": 18,
		"attack": 8,
		"defense": 1,
	},
	{
		"name": "鍖诲笀",
		"max_hp": 20,
		"current_hp": 20,
		"attack": 3,
		"defense": 2,
	},
]
const INITIAL_BUILDINGS := {
	"farm": {
		"display_name": "鍐滅敯",
		"level": 1,
		"status": "姝ｅ父鐢熶骇",
		"daily_food_production": 4,
	},
	"clinic": {
		"display_name": "鍖婚櫌",
		"level": 1,
		"status": "鍒朵綔鑽搧",
		"medicine_progress": 0,
		"medicine_progress_required": 2,
		"medicine_output": 1,
	},
	"workshop": {
		"display_name": "宸ュ潑",
		"level": 1,
		"status": "绛夊緟椤圭洰",
		"current_project": "",
	},
}

var current_day: int = INITIAL_DAY
var resources: Dictionary = {}
var adventurers: Array = []
var buildings: Dictionary = {}
var last_daily_report: Dictionary = {}
var village_system: RefCounted = VillageSystemScript.new()
var expedition_system: RefCounted = ExpeditionSystemScript.new()
var battle_system: RefCounted = BattleSystemScript.new()
var project_system: RefCounted = ProjectSystemScript.new()
var building_system: RefCounted = BuildingSystemScript.new()
var farm_system: RefCounted = FarmSystemScript.new()
var character_database: RefCounted = CharacterDatabaseScript.new()
var equipment_system: RefCounted = EquipmentSystemScript.new()
var forge_system: RefCounted = ForgeSystemScript.new()
var food_workshop_system: RefCounted = FoodWorkshopSystemScript.new()
var hospital_system: RefCounted = HospitalSystemScript.new()
var character_roster: CharacterRoster = CharacterRosterScript.new()
var life_trait_database: RefCounted = LifeTraitDatabaseScript.new()
var life_recruitment_system: RefCounted = LifeRecruitmentSystemScript.new()
var save_system: SaveSystem = SaveSystemScript.new()
var expedition_state: Dictionary = {}
var last_expedition_action_report: Dictionary = {}
var last_expedition_report: Dictionary = {}
var battle_state: Dictionary = {}
var last_battle_result: Dictionary = {}
var last_battle_presentation_events: Array = []
var pending_battle_result: Dictionary = {}
var project_state: Dictionary = {}
var character_runtime_states: Dictionary = {}
var equipment_inventory: Dictionary = {}
var forge_state
var food_production_state
var hospital_project_state
var stackable_item_inventory: Dictionary = {}
var last_forge_report: Dictionary = {}
var last_food_workshop_report: Dictionary = {}
var party_attack_bonus: int = 0
var party_max_hp_bonus: int = 0
var boss_defeated: bool = false
var core_material: int = 0
var mvp_has_completed: bool = false
var statistics: Dictionary = {}
var farm_plot_states: Array = []
var life_work_settlement_keys: Dictionary = {}
var life_recruitment_state: Dictionary = {}
var gameplay_notifications: Array = []
var recent_life_work_results_by_building: Dictionary = {}
var next_gameplay_notification_sequence: int = 1
var last_operation_feedback: Dictionary = {}


func _ready() -> void:
	start_new_game()


func start_new_game() -> void:
	current_day = INITIAL_DAY
	resources = INITIAL_RESOURCES.duplicate(true)
	buildings = INITIAL_BUILDINGS.duplicate(true)
	building_system.ensure_initial_runtime_state(self)
	farm_plot_states = farm_system.create_initial_plot_states(int(buildings.get("farm", {}).get("level", 1)))
	project_state = project_system.create_initial_state()
	character_roster.initialize_defaults(character_database)
	life_recruitment_system.initialize_new_game(self)
	character_runtime_states = character_roster.create_combat_runtime_adapter()
	equipment_inventory = equipment_system.create_initial_inventory_state()
	forge_state = forge_system.create_initial_state()
	food_production_state = food_workshop_system.create_initial_state()
	hospital_project_state = hospital_system.create_initial_state()
	life_work_settlement_keys = {}
	gameplay_notifications = []
	recent_life_work_results_by_building = {}
	next_gameplay_notification_sequence = 1
	last_operation_feedback = {}
	stackable_item_inventory = INITIAL_STACKABLE_ITEMS.duplicate(true)
	last_forge_report = {}
	last_food_workshop_report = {}
	party_attack_bonus = 0
	party_max_hp_bonus = 0
	boss_defeated = false
	core_material = 0
	mvp_has_completed = false
	statistics = {
		"total_expeditions_started": 0,
		"total_failed_expeditions": 0,
		"total_battles_won": 0,
		"total_projects_completed": 0,
	}
	rebuild_adventurers_from_character_data(false)
	last_daily_report = {}
	expedition_state = expedition_system.create_initial_state()
	last_expedition_action_report = {}
	last_expedition_report = {}
	battle_state = battle_system.create_initial_state()
	last_battle_result = {}
	last_battle_presentation_events = []
	pending_battle_result = {}
	emit_all_building_state_changed()
	emit_day_changed()
	emit_resources_changed()
	current_node_changed.emit(expedition_state["current_node_id"])
	supplies_changed.emit()
	expedition_state_changed.emit()
	battle_state_changed.emit()
	project_progress_changed.emit({})
	village_upgrades_changed.emit()
	party_upgrades_changed.emit()
	boss_defeated_changed.emit()
	emit_all_character_data_changed()
	emit_all_character_runtime_state_changed()
	emit_all_character_final_stats_changed()
	equipment_inventory_changed.emit()
	forge_state_changed.emit()
	food_workshop_state_changed.emit()
	hospital_state_changed.emit()
	emit_all_stackable_item_count_changed()
	character_roster_changed.emit()
	life_recruitment_candidates_changed.emit()
	_emit_life_character_capacity_changed()
	expedition_meal_changed.emit(&"")
	daily_report_generated.emit(last_daily_report.duplicate(true))
	state_changed.emit()


func advance_day(reason: String = "manual_test", emit_signals: bool = true) -> Dictionary:
	var settled_day: int = current_day
	last_daily_report = village_system.process_daily_village(self)
	var food_workshop_daily_report: Dictionary = food_workshop_system.process_daily_production(self)
	var hospital_daily_report: Dictionary = hospital_system.process_daily_hospital(self)
	last_daily_report["hospital_report"] = hospital_daily_report.duplicate(true)
	last_daily_report["medicine_produced"] = int(hospital_daily_report.get("medicine_produced", 0))
	last_daily_report["medicine_after"] = get_resource_amount("medicine")
	last_daily_report["medicine_net"] = int(last_daily_report["medicine_after"]) - int(last_daily_report["medicine_before"])
	var expedition_daily_report: Dictionary = expedition_system.process_daily_consumption(self, last_daily_report)
	var project_daily_report: Dictionary = project_system.process_daily_project(self)
	var forge_daily_report: Dictionary = forge_system.process_daily_forge(self)
	current_day = settled_day + 1
	last_daily_report["reason"] = reason
	last_daily_report["settled_day"] = settled_day
	last_daily_report["new_day"] = current_day
	last_daily_report["expedition_food_consumed"] = int(expedition_daily_report["expedition_food_consumed"])
	last_daily_report["expedition_rations_consumed"] = int(expedition_daily_report.get("expedition_rations_consumed", expedition_daily_report["expedition_food_consumed"]))
	last_daily_report["expedition_day_count"] = int(expedition_daily_report["expedition_day_count"])
	last_daily_report["carried_food_after"] = int(expedition_daily_report.get("carried_food_after", 0))
	last_daily_report["carried_rations_after"] = int(expedition_daily_report.get("carried_rations_after", last_daily_report["carried_food_after"]))
	last_daily_report["food_workshop_report"] = food_workshop_daily_report.duplicate(true)
	last_daily_report["food_workshop_progress_updates"] = food_workshop_daily_report.get("food_workshop_progress_updates", []).duplicate(true)
	last_daily_report["food_workshop_completed_recipe_id"] = StringName(food_workshop_daily_report.get("recipe_id", &"")) if bool(food_workshop_daily_report.get("food_workshop_completed", false)) else &""
	last_daily_report["food_workshop_output_item_id"] = StringName(food_workshop_daily_report.get("output_item_id", &""))
	last_daily_report["food_workshop_output_amount"] = int(food_workshop_daily_report.get("output_amount", 0))
	last_daily_report["hospital_report"] = hospital_daily_report.duplicate(true)
	last_daily_report["hospital_project_type"] = StringName(hospital_daily_report.get("hospital_project_type", &""))
	last_daily_report["hospital_progress_before"] = int(hospital_daily_report.get("hospital_progress_before", 0))
	last_daily_report["hospital_progress_after"] = int(hospital_daily_report.get("hospital_progress_after", 0))
	last_daily_report["hospital_required_days"] = int(hospital_daily_report.get("hospital_required_days", 0))
	last_daily_report["hospital_project_completed"] = bool(hospital_daily_report.get("hospital_project_completed", false))
	last_daily_report["medicine_produced"] = int(hospital_daily_report.get("medicine_produced", 0))
	last_daily_report["medicine_after"] = get_resource_amount("medicine")
	last_daily_report["medicine_net"] = int(last_daily_report["medicine_after"]) - int(last_daily_report["medicine_before"])
	last_daily_report["treated_character_id"] = StringName(hospital_daily_report.get("treated_character_id", &""))
	last_daily_report["treatment_completed"] = bool(hospital_daily_report.get("treatment_completed", false))
	last_daily_report["project_report"] = project_daily_report.duplicate(true)
	last_daily_report["forge_report"] = forge_daily_report.duplicate(true)
	last_forge_report = forge_daily_report.duplicate(true)
	last_food_workshop_report = food_workshop_daily_report.duplicate(true)
	build_structured_daily_report(last_daily_report)

	if emit_signals:
		emit_farm_harvest_signals(last_daily_report)
		emit_after_day_advanced()

	return last_daily_report.duplicate(true)


func get_resource_amount(resource_id: String) -> int:
	if not resources.has(resource_id):
		return 0
	return int(resources[resource_id])


func add_resource(resource_id: String, amount: int) -> void:
	if not resources.has(resource_id):
		push_error("Unknown resource id: %s" % resource_id)
		return

	resources[resource_id] = max(0, int(resources[resource_id]) + amount)
	emit_resources_changed()
	state_changed.emit()


func get_resource_display_name(resource_id: String) -> String:
	return String(RESOURCE_LABELS.get(resource_id, resource_id))


func get_stage12_balance_config() -> Dictionary:
	return {
		"config_version": Stage12Config.CONFIG_VERSION,
		"min_party_size": Stage12Config.MIN_PARTY_SIZE,
		"max_party_size": Stage12Config.MAX_PARTY_SIZE,
		"combat_max_level": Stage12Config.COMBAT_MAX_LEVEL,
		"life_max_level": Stage12Config.LIFE_MAX_LEVEL,
		"battle_experience_rewards": Stage12Config.BATTLE_EXPERIENCE_REWARDS.duplicate(true),
		"combat_experience_base": Stage12Config.COMBAT_EXPERIENCE_BASE,
		"combat_experience_step": Stage12Config.COMBAT_EXPERIENCE_STEP,
		"combat_level_growth_by_character":
			Stage12Config.COMBAT_LEVEL_GROWTH_BY_CHARACTER.duplicate(true),
		"life_experience_base": Stage12Config.LIFE_EXPERIENCE_BASE,
		"life_experience_step": Stage12Config.LIFE_EXPERIENCE_STEP,
		"life_work_base_experience": Stage12Config.LIFE_WORK_BASE_EXPERIENCE,
		"life_stat_growth_per_level": Stage12Config.LIFE_STAT_GROWTH_PER_LEVEL,
		"life_stat_min": Stage12Config.LIFE_STAT_MIN,
		"life_stat_cap": Stage12Config.LIFE_STAT_MAX,
		"life_job_stat_bonus_per_point": Stage12Config.LIFE_JOB_STAT_BONUS_PER_POINT,
		"crit_rate_min": Stage12Config.COMBAT_CRIT_RATE_MIN,
		"crit_rate_max": Stage12Config.COMBAT_CRIT_RATE_MAX,
		"crit_damage_min": Stage12Config.COMBAT_CRIT_DAMAGE_MIN,
		"crit_damage_max": Stage12Config.COMBAT_CRIT_DAMAGE_MAX,
		"candidate_count": Stage12Config.CANDIDATE_COUNT,
		"quality_probabilities": Stage12Config.QUALITY_PROBABILITIES.duplicate(true),
		"quality_attribute_ranges": Stage12Config.QUALITY_ATTRIBUTE_RANGES.duplicate(true),
		"recruit_cost_by_quality": Stage12Config.RECRUIT_COST_BY_QUALITY.duplicate(true),
		"refresh_cost": Stage12Config.RECRUITMENT_REFRESH_COST,
		"base_life_capacity": Stage12Config.BASE_LIFE_CAPACITY,
		"capacity_per_residence_level": Stage12Config.CAPACITY_PER_RESIDENCE_LEVEL,
		"job_slot_count_by_level":
			Stage12Config.DEFAULT_JOB_SLOT_COUNT_BY_LEVEL.duplicate(true),
		"job_config_by_building": Stage12Config.JOB_CONFIG_BY_BUILDING.duplicate(true),
		"life_trait_config": Stage12Config.LIFE_TRAIT_CONFIG.duplicate(true),
		"default_life_portrait_path": Stage12Config.DEFAULT_LIFE_PORTRAIT_PATH,
		"life_portrait_paths": Stage12Config.LIFE_PORTRAIT_PATHS.duplicate(),
	}


func push_gameplay_notification(
	message: String,
	category: StringName = &"info",
	context: Dictionary = {}
) -> Dictionary:
	var normalized_message := message.strip_edges()
	if normalized_message.is_empty():
		return {}
	var notification := {
		"notification_id": next_gameplay_notification_sequence,
		"day": current_day,
		"category": category,
		"message": normalized_message,
		"context": context.duplicate(true),
	}
	next_gameplay_notification_sequence += 1
	gameplay_notifications.append(notification)
	while gameplay_notifications.size() > Stage12Config.MAX_GAMEPLAY_NOTIFICATIONS:
		gameplay_notifications.pop_front()
	last_operation_feedback = notification.duplicate(true)
	gameplay_notification_added.emit(notification.duplicate(true))
	return notification


func get_gameplay_notifications(limit: int = Stage12Config.MAX_GAMEPLAY_NOTIFICATIONS) -> Array:
	var result: Array = []
	var start_index := maxi(0, gameplay_notifications.size() - maxi(0, limit))
	for index: int in range(start_index, gameplay_notifications.size()):
		result.append(gameplay_notifications[index].duplicate(true))
	return result


func get_last_operation_feedback() -> Dictionary:
	return last_operation_feedback.duplicate(true)


func normalize_stage12f_feedback_state(
	raw_notifications,
	raw_work_results,
	raw_next_sequence
) -> void:
	gameplay_notifications = []
	recent_life_work_results_by_building = {}
	var highest_sequence := 0
	if raw_notifications is Array:
		for raw_notification in raw_notifications:
			if not raw_notification is Dictionary:
				continue
			var message := String(raw_notification.get("message", "")).strip_edges()
			if message.is_empty():
				continue
			var sequence := maxi(1, int(raw_notification.get(
				"notification_id", highest_sequence + 1
			)))
			highest_sequence = maxi(highest_sequence, sequence)
			gameplay_notifications.append({
				"notification_id": sequence,
				"day": maxi(1, int(raw_notification.get("day", current_day))),
				"category": StringName(raw_notification.get("category", &"info")),
				"message": message,
				"context": raw_notification.get("context", {}).duplicate(true)
					if raw_notification.get("context", {}) is Dictionary else {},
			})
			if gameplay_notifications.size() >= Stage12Config.MAX_GAMEPLAY_NOTIFICATIONS:
				break
	if raw_work_results is Dictionary:
		for raw_building_id in raw_work_results.keys():
			var building_id := StringName(raw_building_id)
			var feedback = raw_work_results[raw_building_id]
			if get_building_data(building_id) == null or not feedback is Dictionary:
				continue
			var results = feedback.get("work_experience_results", [])
			if not results is Array:
				continue
			var normalized_feedback: Dictionary = feedback.duplicate(true)
			normalized_feedback["building_id"] = building_id
			normalized_feedback["work_experience_results"] = results.duplicate(true)
			recent_life_work_results_by_building[building_id] = normalized_feedback
	next_gameplay_notification_sequence = maxi(
		highest_sequence + 1, maxi(1, int(raw_next_sequence))
	)
	last_operation_feedback = (
		gameplay_notifications.back().duplicate(true)
		if not gameplay_notifications.is_empty() else {}
	)


func record_life_work_feedback(building_id: StringName, report: Dictionary) -> Dictionary:
	var results = report.get(
		"work_experience_results",
		report.get("farm_work_experience_results", [])
	)
	if not results is Array or results.is_empty():
		return {}
	var production_details: Dictionary = report.get(
		"production_details",
		report.get("farm_production_details", get_building_production_details(building_id))
	)
	var participant_results: Array = []
	for raw_result in results:
		if not raw_result is Dictionary:
			continue
		var result: Dictionary = raw_result.duplicate(true)
		var character_id := StringName(result.get("character_id", &""))
		result["display_name"] = get_character_display_name(character_id)
		participant_results.append(result)
	var base_output := int(report.get("base_output_amount", 0))
	var output_amount := int(report.get(
		"output_amount",
		report.get("medicine_produced", report.get("farm_food_produced", 0))
	))
	if building_id == &"farm":
		base_output = 0
		output_amount = 0
		for harvest in report.get("farm_harvests", []):
			if not harvest is Dictionary:
				continue
			base_output += int(harvest.get("base_output_amount", 0))
			output_amount += int(harvest.get("output_amount", 0))
	var building_data = get_building_data(building_id)
	var feedback := {
		"building_id": building_id,
		"building_display_name": String(building_data.display_name)
			if building_data != null else String(building_id),
		"day": current_day,
		"work_experience_results": participant_results,
		"final_production_multiplier": float(
			production_details.get("final_production_multiplier", 1.0)
		),
		"base_output_amount": base_output,
		"output_amount": output_amount,
		"extra_output_amount": maxi(0, output_amount - base_output),
		"treatment_completed": bool(report.get("treatment_completed", false)),
		"effect_text": String(report.get("effect_text", "")),
	}
	recent_life_work_results_by_building[building_id] = feedback
	var participant_names := PackedStringArray()
	for result: Dictionary in participant_results:
		participant_names.append(String(result.get("display_name", "")))
	var summary := "%s工作完成：%s获得成长反馈。" % [
		String(feedback["building_display_name"]),
		"、".join(participant_names),
	]
	push_gameplay_notification(summary, &"work", {
		"building_id": building_id,
		"character_ids": participant_results.map(
			func(result: Dictionary): return result.get("character_id", &"")
		),
	})
	life_work_feedback_changed.emit(building_id, feedback.duplicate(true))
	return feedback.duplicate(true)


func get_recent_life_work_feedback(building_id: StringName) -> Dictionary:
	return recent_life_work_results_by_building.get(building_id, {}).duplicate(true)


func get_character_portrait_path(character_id: StringName) -> String:
	var snapshot := get_roster_character(character_id)
	if snapshot.is_empty():
		return Stage12Config.DEFAULT_LIFE_PORTRAIT_PATH
	if StringName(snapshot.get("character_type_name", &"")) == &"life":
		return Stage12Config.resolve_life_portrait_path(
			String(snapshot.get("portrait_path", ""))
		)
	return String(snapshot.get("portrait_path", ""))


func get_candidate_portrait_path(candidate: Dictionary) -> String:
	var character: Dictionary = candidate.get("character", {})
	return Stage12Config.resolve_life_portrait_path(
		String(character.get("portrait_path", candidate.get("portrait_path", "")))
	)


func get_item_display_name(item_id: StringName) -> String:
	return String(STACKABLE_ITEM_LABELS.get(item_id, String(item_id)))


func get_item_count(item_id: StringName) -> int:
	return max(0, int(stackable_item_inventory.get(item_id, 0)))


func add_item(item_id: StringName, amount: int, emit_signals: bool = true) -> void:
	if amount <= 0:
		return
	stackable_item_inventory[item_id] = get_item_count(item_id) + amount
	if emit_signals:
		stackable_item_count_changed.emit(item_id, get_item_count(item_id))
		emit_resources_changed()
		state_changed.emit()


func can_remove_item(item_id: StringName, amount: int) -> bool:
	if amount < 0:
		return false
	return get_item_count(item_id) >= amount


func remove_item(item_id: StringName, amount: int, emit_signals: bool = true) -> bool:
	if amount < 0 or not can_remove_item(item_id, amount):
		return false
	stackable_item_inventory[item_id] = max(0, get_item_count(item_id) - amount)
	if emit_signals:
		stackable_item_count_changed.emit(item_id, get_item_count(item_id))
		emit_resources_changed()
		state_changed.emit()
	return true


func get_stackable_item_inventory() -> Dictionary:
	return stackable_item_inventory.duplicate(true)


func get_project_ids() -> Array[StringName]:
	return project_system.get_all_project_ids()


func get_project_config(project_id: StringName) -> Dictionary:
	return project_system.get_project_config(project_id).duplicate(true)


func get_project_state() -> Dictionary:
	return project_state.duplicate(true)


func get_active_project_summary() -> String:
	return project_system.get_active_project_summary(self)


func can_start_project(project_id: StringName) -> bool:
	return project_system.can_start_project(self, project_id)


func get_project_start_error(project_id: StringName) -> String:
	return project_system.get_start_error(self, project_id)


func start_project(project_id: StringName) -> bool:
	var report: Dictionary = project_system.start_project(self, project_id)
	if not bool(report.get("success", false)):
		project_started.emit(report.duplicate(true))
		return false

	emit_resources_changed()
	project_started.emit(report.duplicate(true))
	project_progress_changed.emit(report.duplicate(true))
	state_changed.emit()
	return true


func get_forge_recipe_ids() -> Array[StringName]:
	return forge_system.get_all_recipe_ids()


func get_forge_recipe_data(recipe_id: StringName) -> Dictionary:
	return forge_system.get_recipe_data(self, recipe_id).duplicate(true)


func get_all_forge_recipe_data() -> Array:
	return forge_system.get_all_recipe_data(self)


func get_forge_state() -> Dictionary:
	return forge_state.to_dictionary() if forge_state != null else {}


func get_active_forge_summary() -> String:
	return forge_system.get_active_summary(self)


func get_last_forge_report() -> Dictionary:
	return last_forge_report.duplicate(true)


func can_start_forge_recipe(recipe_id: StringName) -> bool:
	return forge_system.can_start_recipe(self, recipe_id)


func get_forge_start_error(recipe_id: StringName) -> String:
	return forge_system.get_start_error(self, recipe_id)


func start_forge_recipe(recipe_id: StringName) -> bool:
	var report: Dictionary = forge_system.start_recipe(self, recipe_id)
	if not bool(report.get("success", false)):
		forge_project_started.emit(report.duplicate(true))
		return false

	last_forge_report = report.duplicate(true)
	emit_resources_changed()
	forge_project_started.emit(report.duplicate(true))
	forge_progress_changed.emit(report.duplicate(true))
	forge_state_changed.emit()
	building_project_changed.emit(&"weapon_forge")
	building_state_changed.emit(&"weapon_forge")
	state_changed.emit()
	return true


func get_food_recipe_ids() -> Array[StringName]:
	return food_workshop_system.get_all_recipe_ids()


func get_food_recipe_data(recipe_id: StringName) -> Dictionary:
	return food_workshop_system.get_recipe_data(self, recipe_id).duplicate(true)


func get_all_food_recipe_data() -> Array:
	return food_workshop_system.get_all_recipe_data(self)


func get_food_meal_data(meal_id: StringName) -> Dictionary:
	return food_workshop_system.get_meal_data(meal_id).duplicate(true)


func get_all_food_meal_data() -> Array:
	return food_workshop_system.get_all_meal_data()


func get_food_production_state() -> Dictionary:
	return food_production_state.to_dictionary() if food_production_state != null else {}


func get_active_food_workshop_summary() -> String:
	return food_workshop_system.get_active_summary(self)


func get_last_food_workshop_report() -> Dictionary:
	return last_food_workshop_report.duplicate(true)


func can_start_food_recipe(recipe_id: StringName) -> bool:
	return food_workshop_system.can_start_recipe(self, recipe_id)


func get_food_recipe_start_error(recipe_id: StringName) -> String:
	return food_workshop_system.get_start_error(self, recipe_id)


func start_food_recipe(recipe_id: StringName) -> bool:
	var report: Dictionary = food_workshop_system.start_recipe(self, recipe_id)
	if not bool(report.get("success", false)):
		return false

	last_food_workshop_report = report.duplicate(true)
	emit_resources_changed()
	food_recipe_started.emit(recipe_id)
	food_workshop_state_changed.emit()
	building_project_changed.emit(&"food_workshop")
	building_state_changed.emit(&"food_workshop")
	state_changed.emit()
	return true


func get_hospital_project_state() -> Dictionary:
	return hospital_system.get_project_state(self)


func get_hospital_medicine_recipe_data() -> Dictionary:
	return hospital_system.get_medicine_recipe_data(self)


func get_active_hospital_summary() -> String:
	return hospital_system.get_active_summary(self)


func is_hospital_busy() -> bool:
	return hospital_system.is_hospital_busy(self)


func get_active_hospital_project_type() -> StringName:
	return hospital_system.get_active_project_type(self)


func get_active_hospital_target_character_id() -> StringName:
	return hospital_system.get_active_target_character_id(self)


func can_start_medicine_production() -> bool:
	return hospital_system.can_start_medicine_production(self)


func get_medicine_disabled_reason() -> String:
	return hospital_system.get_medicine_disabled_reason(self)


func start_medicine_production() -> bool:
	var report: Dictionary = hospital_system.start_medicine_production(self)
	if not bool(report.get("success", false)):
		return false
	emit_resources_changed()
	hospital_project_started.emit(StringName(report.get("project_type", &"")), &"")
	hospital_state_changed.emit()
	building_project_changed.emit(&"hospital")
	building_state_changed.emit(&"hospital")
	state_changed.emit()
	return true


func can_treat_character(character_id: StringName) -> bool:
	return hospital_system.can_treat_character(self, character_id)


func get_treatment_disabled_reason(character_id: StringName) -> String:
	return hospital_system.get_treatment_disabled_reason(self, character_id)


func start_treatment(character_id: StringName) -> bool:
	var report: Dictionary = hospital_system.start_treatment(self, character_id)
	if not bool(report.get("success", false)):
		return false
	emit_resources_changed()
	hospital_project_started.emit(StringName(report.get("project_type", &"")), character_id)
	character_treatment_started.emit(character_id)
	hospital_state_changed.emit()
	building_project_changed.emit(&"hospital")
	building_state_changed.emit(&"hospital")
	state_changed.emit()
	return true


func is_character_injured(character_id: StringName) -> bool:
	return hospital_system.is_character_injured(self, character_id)


func is_character_being_treated(character_id: StringName) -> bool:
	return hospital_system.is_character_being_treated(self, character_id)


func get_building_state(building_id: StringName) -> Dictionary:
	if building_system != null and building_system.get_building_data(building_id) != null:
		return building_system.get_runtime_state(self, building_id)
	var key := String(building_id)
	if not buildings.has(key):
		return {}
	return buildings[key].duplicate(true)


func get_building_ids() -> Array[StringName]:
	return building_system.get_building_ids()


func get_building_data(building_id: StringName):
	return building_system.get_building_data(building_id)


func get_all_building_data() -> Array:
	return building_system.get_all_building_data()


func set_building_level(building_id: StringName, level: int) -> bool:
	if not building_system.set_building_level(self, building_id, level):
		return false
	var sync_result := sync_building_jobs_to_level(building_id, false)
	if building_id == &"farm":
		farm_system.apply_farm_level(self, level)
		farm_state_changed.emit()
	for raw_character_id in sync_result.get("repaired_character_ids", []):
		character_data_changed.emit(StringName(raw_character_id))
	if not sync_result.get("repaired_character_ids", []).is_empty():
		character_roster_changed.emit()
	life_job_assignments_changed.emit(building_id)
	building_level_changed.emit(building_id, level)
	building_state_changed.emit(building_id)
	building_visual_refresh_requested.emit(building_id)
	if building_id == &"residence":
		_emit_life_character_capacity_changed()
	state_changed.emit()
	return true


func select_building(building_id: StringName) -> void:
	building_selected.emit(building_id)


func get_last_daily_report() -> Dictionary:
	return last_daily_report.duplicate(true)


func build_structured_daily_report(report: Dictionary) -> void:
	var daily_report = DailyReportScript.new().setup(
		int(report.get("settled_day", current_day)),
		int(report.get("new_day", current_day)),
		StringName(report.get("reason", &""))
	)
	_collect_farm_daily_events(daily_report, report)
	_collect_food_workshop_daily_events(daily_report, report)
	_collect_hospital_daily_events(daily_report, report)
	_collect_forge_daily_events(daily_report, report)
	_collect_construction_daily_events(daily_report, report)
	_collect_consumption_daily_events(daily_report, report)

	var structured: Dictionary = daily_report.to_dictionary()
	for key in structured.keys():
		report[key] = structured[key]
	report["daily_summary_lines"] = format_daily_summary_lines(report)


func _collect_farm_daily_events(daily_report, report: Dictionary) -> void:
	var harvests: Array = report.get("farm_harvests", [])
	var wheat_count := 0
	var herb_count := 0
	for harvest: Dictionary in harvests:
		match StringName(harvest.get("crop_id", &"")):
			&"wheat":
				wheat_count += 1
			&"herb":
				herb_count += 1
	if wheat_count > 0:
		var amount := int(report.get("farm_food_produced", 0))
		daily_report.add_event(&"farm", {
			"type": &"harvest",
			"crop_id": &"wheat",
			"count": wheat_count,
			"resource_id": &"food",
			"amount": amount,
			"text": "小麦成熟x%d，粮食+%d" % [wheat_count, amount],
		})
		daily_report.add_resource_change(&"food", amount, "农田：小麦成熟x%d" % wheat_count)
	if herb_count > 0:
		var amount := int(report.get("farm_herb_produced", 0))
		daily_report.add_event(&"farm", {
			"type": &"harvest",
			"crop_id": &"herb",
			"count": herb_count,
			"resource_id": &"herb",
			"amount": amount,
			"text": "药草成熟x%d，草药+%d" % [herb_count, amount],
		})
		daily_report.add_resource_change(&"herb", amount, "农田：药草成熟x%d" % herb_count)
	if harvests.is_empty() and not report.get("farm_plot_updates", []).is_empty():
		daily_report.add_event(&"farm", {
			"type": &"growth",
			"count": report.get("farm_plot_updates", []).size(),
			"text": "作物生长推进%d块" % report.get("farm_plot_updates", []).size(),
		})


func _collect_food_workshop_daily_events(daily_report, report: Dictionary) -> void:
	var food_report: Dictionary = report.get("food_workshop_report", {})
	if not bool(food_report.get("had_active_food_workshop", false)):
		return
	if bool(food_report.get("food_workshop_completed", false)):
		var item_id := StringName(food_report.get("output_item_id", &""))
		var amount := int(food_report.get("output_amount", 0))
		daily_report.add_event(&"food_workshop", {
			"type": &"completed",
			"recipe_id": StringName(food_report.get("recipe_id", &"")),
			"item_id": item_id,
			"amount": amount,
			"text": "%s制作完成，%s+%d" % [
				String(food_report.get("display_name", "食物")),
				get_item_display_name(item_id),
				amount,
			],
		})
		daily_report.add_resource_change(item_id, amount, "食物制造所：%s" % String(food_report.get("display_name", "食物")))
	else:
		daily_report.add_event(&"food_workshop", {
			"type": &"progress",
			"recipe_id": StringName(food_report.get("recipe_id", &"")),
			"progress_after": int(food_report.get("progress_after", 0)),
			"required_days": int(food_report.get("required_days", 0)),
			"text": "%s制作进度 %d/%d" % [
				String(food_report.get("display_name", "食物")),
				int(food_report.get("progress_after", 0)),
				int(food_report.get("required_days", 0)),
			],
		})


func _collect_hospital_daily_events(daily_report, report: Dictionary) -> void:
	var hospital_report: Dictionary = report.get("hospital_report", {})
	if not bool(hospital_report.get("had_active_hospital", false)):
		return
	if bool(hospital_report.get("hospital_project_completed", false)):
		if int(hospital_report.get("medicine_produced", 0)) > 0:
			var amount := int(hospital_report.get("medicine_produced", 0))
			daily_report.add_event(&"hospital", {
				"type": &"medicine_completed",
				"amount": amount,
				"text": "基础药品制作完成，药品+%d" % amount,
			})
			daily_report.add_resource_change(&"medicine", amount, "医院：基础药品制作完成")
		elif bool(hospital_report.get("treatment_completed", false)):
			var character_id := StringName(hospital_report.get("treated_character_id", &""))
			daily_report.add_event(&"hospital", {
				"type": &"treatment_completed",
				"character_id": character_id,
				"text": "%s治疗完成，状态恢复健康" % get_character_display_name(character_id),
			})
	else:
		var text := "医院项目进度 %d/%d" % [
			int(hospital_report.get("hospital_progress_after", 0)),
			int(hospital_report.get("hospital_required_days", 0)),
		]
		if StringName(hospital_report.get("hospital_project_type", &"")) == &"treat_character":
			text = "%s治疗进度 %d/%d" % [
				get_character_display_name(StringName(hospital_report.get("treated_character_id", &""))),
				int(hospital_report.get("hospital_progress_after", 0)),
				int(hospital_report.get("hospital_required_days", 0)),
			]
		daily_report.add_event(&"hospital", {
			"type": &"progress",
			"project_type": StringName(hospital_report.get("hospital_project_type", &"")),
			"text": text,
		})


func _collect_forge_daily_events(daily_report, report: Dictionary) -> void:
	var forge_report: Dictionary = report.get("forge_report", {})
	if not bool(forge_report.get("had_active_forge", false)):
		return
	if bool(forge_report.get("forge_completed", false)):
		daily_report.add_event(&"weapon_forge", {
			"type": &"completed",
			"recipe_id": StringName(forge_report.get("recipe_id", &"")),
			"equipment_instance_id": StringName(forge_report.get("equipment_instance_id", &"")),
			"text": "%s制作完成" % String(forge_report.get("result_display_name", forge_report.get("display_name", "装备"))),
		})
	else:
		daily_report.add_event(&"weapon_forge", {
			"type": &"progress",
			"recipe_id": StringName(forge_report.get("recipe_id", &"")),
			"text": "%s制作进度 %d/%d" % [
				String(forge_report.get("display_name", "装备")),
				int(forge_report.get("progress_after", 0)),
				int(forge_report.get("required_days", 0)),
			],
		})


func _collect_construction_daily_events(daily_report, report: Dictionary) -> void:
	var project_report: Dictionary = report.get("project_report", {})
	if not bool(project_report.get("had_active_project", false)):
		return
	if bool(project_report.get("project_completed", false)):
		daily_report.add_event(&"construction", {
			"type": &"completed",
			"project_id": StringName(project_report.get("project_id", &"")),
			"text": "%s完成" % String(project_report.get("display_name", "建设项目")),
		})
	else:
		daily_report.add_event(&"construction", {
			"type": &"progress",
			"project_id": StringName(project_report.get("project_id", &"")),
			"text": "%s进度 %d/%d" % [
				String(project_report.get("display_name", "建设项目")),
				int(project_report.get("progress_after", 0)),
				int(project_report.get("required_days", 0)),
			],
		})


func _collect_consumption_daily_events(daily_report, report: Dictionary) -> void:
	var village_food := int(report.get("food_consumed", 0))
	if village_food > 0:
		daily_report.add_event(&"village_consumption", {
			"type": &"food",
			"amount": village_food,
			"text": "居民消耗粮食-%d" % village_food,
		})
		daily_report.add_resource_change(&"food", -village_food, "村庄：居民消耗")
	var expedition_rations := int(report.get("expedition_rations_consumed", report.get("expedition_food_consumed", 0)))
	if expedition_rations > 0:
		daily_report.add_event(&"expedition_consumption", {
			"type": &"ration",
			"amount": expedition_rations,
			"text": "远征口粮-%d" % expedition_rations,
		})
		daily_report.add_resource_change(&"expedition_ration", -expedition_rations, "远征：每日口粮")


func format_daily_summary_lines(report: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	lines.append("第%d天 -> 第%d天" % [int(report.get("settled_day", report.get("day_before", current_day))), int(report.get("new_day", report.get("day_after", current_day)))])
	_append_event_section(lines, "农田", report.get("farm_events", []))
	_append_event_section(lines, "村庄", report.get("village_consumption_events", []))
	_append_event_section(lines, "食物制造所", report.get("food_workshop_events", []))
	_append_event_section(lines, "医院", report.get("hospital_events", []))
	_append_event_section(lines, "远征", report.get("expedition_consumption_events", []))
	_append_event_section(lines, "建设", report.get("construction_events", []))
	_append_event_section(lines, "武器制造所", report.get("weapon_forge_events", []))
	var change_lines := format_resource_change_lines(report.get("resource_changes", {}))
	if not change_lines.is_empty():
		lines.append("")
		lines.append("资源变化：")
		lines.append_array(change_lines)
	return lines


func _append_event_section(lines: Array[String], title: String, events: Array) -> void:
	if events.is_empty():
		return
	lines.append("")
	lines.append("%s：" % title)
	for event: Dictionary in events:
		lines.append(String(event.get("text", "")))


func format_resource_change_lines(changes: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	for resource_id in changes.keys():
		var amount := int(changes[resource_id])
		if amount == 0:
			continue
		var name := get_item_display_name(StringName(resource_id)) if stackable_item_inventory.has(StringName(resource_id)) else get_resource_display_name(String(resource_id))
		lines.append("%s %s" % [name, format_signed_amount(amount)])
	return lines


func format_signed_amount(amount: int) -> String:
	if amount > 0:
		return "+%d" % amount
	return "%d" % amount


func get_projects_completing_in_days(days: int) -> Array:
	var results: Array = []
	if food_production_state != null and bool(food_production_state.is_active):
		var remaining: int = max(0, int(food_production_state.required_days) - int(food_production_state.progress_days))
		if remaining <= days:
			var recipe: Dictionary = get_food_recipe_data(StringName(food_production_state.recipe_id))
			results.append({
				"system": &"food_workshop",
				"display_name": String(recipe.get("display_name", "食物")),
				"remaining_days": remaining,
				"text": "食物制造所：%s" % String(recipe.get("display_name", "食物")),
			})
	if hospital_project_state != null and bool(hospital_project_state.is_active):
		var remaining: int = max(0, int(hospital_project_state.required_days) - int(hospital_project_state.progress_days))
		if remaining <= days:
			var text := "医院：基础药品"
			if StringName(hospital_project_state.project_type) == &"treat_character":
				text = "医院：%s治疗完成" % get_character_display_name(StringName(hospital_project_state.target_character_id))
			results.append({
				"system": &"hospital",
				"display_name": text,
				"remaining_days": remaining,
				"text": text,
			})
	if forge_state != null and bool(forge_state.is_active):
		var remaining: int = max(0, int(forge_state.required_days) - int(forge_state.progress_days))
		if remaining <= days:
			results.append({
				"system": &"weapon_forge",
				"display_name": get_active_forge_summary(),
				"remaining_days": remaining,
				"text": "武器制造所：%s" % get_active_forge_summary(),
			})
	var active_project_id: StringName = StringName(project_state.get("active_project_id", &""))
	if active_project_id != &"":
		var project_config: Dictionary = get_project_config(active_project_id)
		var remaining: int = max(0, int(project_config.get("required_days", 0)) - int(project_state.get("active_project_progress", 0)))
		if remaining <= days:
			results.append({
				"system": &"construction",
				"display_name": String(project_config.get("display_name", "建设项目")),
				"remaining_days": remaining,
				"text": "建设：%s" % String(project_config.get("display_name", "建设项目")),
			})
	return results


func get_logistics_overview() -> Dictionary:
	var farm_summary := get_farm_summary()
	var injured_names: Array[String] = []
	for character_id: StringName in get_character_ids():
		if is_character_injured(character_id):
			injured_names.append(get_character_display_name(character_id))
	return {
		"resources": {
			&"food": get_resource_amount("food"),
			&"herb": get_resource_amount("herb"),
			&"expedition_ration": get_item_count(&"expedition_ration"),
			&"medicine": get_resource_amount("medicine"),
			&"hearty_stew": get_item_count(&"hearty_stew"),
			&"hunter_roast": get_item_count(&"hunter_roast"),
		},
		"farm": farm_summary,
		"food_workshop_summary": get_active_food_workshop_summary(),
		"hospital_summary": get_active_hospital_summary(),
		"injured_names": injured_names,
		"forge_summary": get_active_forge_summary(),
		"construction_summary": get_active_project_summary(),
		"completing_tomorrow": get_projects_completing_in_days(1),
	}


func get_expedition_readiness_report(carried_food: int, carried_medicine: int, selected_meal_id: StringName = &"") -> Dictionary:
	var blocking: Array[String] = []
	var warnings: Array[String] = []
	var start_error := get_expedition_start_error(carried_food, carried_medicine, selected_meal_id)
	if not start_error.is_empty():
		blocking.append(start_error)
	for character_id: StringName in get_character_ids():
		if is_character_being_treated(character_id):
			var text := "%s正在医院接受治疗" % get_character_display_name(character_id)
			if not blocking.has(text):
				blocking.append(text)
		elif is_character_injured(character_id):
			warnings.append("%s处于受伤状态，最大生命降低20%%" % get_character_display_name(character_id))
	if carried_medicine <= 0:
		warnings.append("当前未携带药品")
	if carried_food <= 1:
		warnings.append("本次携带远征口粮较少")
	if get_item_count(&"expedition_ration") <= 2:
		warnings.append("村庄远征口粮库存较少")
	if not is_hospital_busy():
		for character_id: StringName in get_character_ids():
			if is_character_injured(character_id):
				warnings.append("医院空闲，仍有受伤角色可治疗")
				break
	var completing := get_projects_completing_in_days(1)
	for item: Dictionary in completing:
		warnings.append("明天将完成：%s" % String(item.get("text", "")))
	return {
		"can_depart": blocking.is_empty(),
		"blocking": blocking,
		"warnings": warnings,
		"completing_soon": completing,
	}


func get_crop_ids() -> Array[StringName]:
	return farm_system.get_crop_ids()


func get_crop_data(crop_id: StringName):
	var data = farm_system.get_crop_data(crop_id)
	return data


func get_all_crop_data() -> Array:
	return farm_system.get_all_crop_data()


func get_farm_plot_states() -> Array:
	return farm_system.get_plot_state_dictionaries(self)


func get_farm_summary() -> Dictionary:
	return farm_system.get_summary(self)


func get_farm_last_error() -> String:
	return farm_system.get_last_error()


func assign_farm_crop(plot_id: int, crop_id: StringName, force_replace: bool = false) -> bool:
	if not farm_system.assign_crop(self, plot_id, crop_id, force_replace):
		return false
	farm_plot_changed.emit(plot_id)
	crop_assigned.emit(plot_id, crop_id)
	building_state_changed.emit(&"farm")
	farm_state_changed.emit()
	state_changed.emit()
	return true


func is_expedition_active() -> bool:
	if expedition_state.is_empty():
		return false
	return bool(expedition_state["is_active"])


func can_start_expedition(carried_food: int, carried_medicine: int, selected_meal_id: StringName = &"") -> bool:
	return get_expedition_start_error(carried_food, carried_medicine, selected_meal_id).is_empty()


func get_expedition_start_error(carried_food: int, carried_medicine: int, selected_meal_id: StringName = &"") -> String:
	for character_id: StringName in get_character_ids():
		if is_character_being_treated(character_id):
			return "%s is being treated in the hospital." % get_character_display_name(character_id)
	return expedition_system.get_start_error(self, carried_food, carried_medicine, selected_meal_id)


func start_expedition(carried_food: int, carried_medicine: int, selected_meal_id: StringName = &"") -> bool:
	if not get_expedition_start_error(carried_food, carried_medicine, selected_meal_id).is_empty():
		return false
	if not expedition_system.start_expedition(self, carried_food, carried_medicine, selected_meal_id):
		return false

	statistics["total_expeditions_started"] = int(statistics.get("total_expeditions_started", 0)) + 1
	emit_resources_changed()
	if selected_meal_id != &"":
		apply_expedition_meal_bonus(selected_meal_id)
	expedition_meal_changed.emit(get_active_expedition_meal())
	supplies_changed.emit()
	expedition_state_changed.emit()
	current_node_changed.emit(expedition_state["current_node_id"])
	expedition_started.emit()
	state_changed.emit()
	return true


func move_to_next_expedition_node(
	battle_start_router: Callable = Callable()
) -> bool:
	var action_report: Dictionary = expedition_system.move_to_next_node(self)
	if action_report.is_empty():
		return false

	emit_after_day_advanced()
	expedition_action_completed.emit(action_report.duplicate(true))
	if bool(action_report.get("starts_battle", false)):
		if battle_start_router.is_valid():
			battle_start_router.call(StringName(action_report["encounter_id"]))
		else:
			start_battle(action_report["encounter_id"])
	return true


func gather_current_expedition_node() -> bool:
	var action_report: Dictionary = expedition_system.gather_current_node(self)
	if action_report.is_empty():
		return false

	emit_after_day_advanced()
	expedition_action_completed.emit(action_report.duplicate(true))
	return true


func return_from_expedition() -> bool:
	if is_battle_active():
		return false
	var injury_snapshots := create_expedition_injury_snapshots()
	var report: Dictionary = expedition_system.return_to_village(self)
	if report.is_empty():
		return false

	var should_complete_mvp: bool = int(report.get("core_gained", 0)) > 0 and not mvp_has_completed
	var injury_results: Array = hospital_system.process_expedition_injuries(self, false, injury_snapshots)
	report["character_injury_results"] = injury_results.duplicate(true)
	report["team_injury_summary"] = get_team_injury_summary()
	last_expedition_report = report.duplicate(true)
	emit_injury_result_signals(injury_results)
	clear_expedition_meal_bonus()
	restore_character_runtime_states_full()
	rebuild_adventurers_from_character_data(false)
	emit_resources_changed()
	supplies_changed.emit()
	expedition_state_changed.emit()
	battle_state_changed.emit()
	current_node_changed.emit(expedition_state["current_node_id"])
	expedition_ended.emit(report.duplicate(true))
	if should_complete_mvp:
		mvp_has_completed = true
		mvp_completed.emit(get_mvp_summary())
	state_changed.emit()
	return true


func get_expedition_state() -> Dictionary:
	return expedition_state.duplicate(true)


func get_current_expedition_node() -> Dictionary:
	return expedition_system.get_node_data(expedition_state["current_node_id"])


func get_current_expedition_node_name() -> String:
	return expedition_system.get_node_display_name(expedition_state["current_node_id"])


func get_next_expedition_node_name() -> String:
	return expedition_system.get_next_node_display_name(expedition_state["current_node_id"])


func get_expedition_gather_label() -> String:
	return expedition_system.get_gather_label(expedition_state["current_node_id"])


func can_move_to_next_expedition_node() -> bool:
	return expedition_system.can_move_to_next_node(self)


func can_gather_current_expedition_node() -> bool:
	return expedition_system.can_gather_current_node(self)


func has_collected_current_expedition_node() -> bool:
	return expedition_system.has_collected_current_node(self)


func get_expedition_node_name(node_id: StringName) -> String:
	return expedition_system.get_node_display_name(node_id)


func get_last_expedition_action_report() -> Dictionary:
	return last_expedition_action_report.duplicate(true)


func get_last_expedition_report() -> Dictionary:
	return last_expedition_report.duplicate(true)


func is_battle_active() -> bool:
	if battle_state.is_empty():
		return false
	return bool(battle_state["is_active"])


func start_battle(encounter_id: StringName) -> bool:
	if not battle_system.start_battle(self, encounter_id):
		return false

	last_battle_presentation_events = []
	pending_battle_result = {}
	battle_started.emit(encounter_id)
	battle_state_changed.emit()
	active_unit_changed.emit(battle_system.get_active_unit_id(battle_state))
	state_changed.emit()
	return true


func execute_battle_action(action_id: StringName, target_id: StringName = &"") -> bool:
	var action_result: Dictionary = battle_system.execute_player_action(self, action_id, target_id)
	last_battle_presentation_events = battle_state.get("presentation_events", []).duplicate(true)
	if not bool(action_result.get("success", false)):
		battle_state_changed.emit()
		state_changed.emit()
		return false

	if bool(action_result.get("finished", false)):
		pending_battle_result = action_result["result"].duplicate(true)
		battle_state_changed.emit()
		state_changed.emit()
	else:
		battle_state_changed.emit()
		active_unit_changed.emit(battle_system.get_active_unit_id(battle_state))
		state_changed.emit()
	return true


func has_pending_battle_result() -> bool:
	return not pending_battle_result.is_empty()


func complete_pending_battle_result() -> bool:
	if pending_battle_result.is_empty():
		return false
	var result := pending_battle_result.duplicate(true)
	pending_battle_result = {}
	process_battle_result(result)
	return true


func get_formal_battle_settlement_profile(encounter_id: StringName) -> Dictionary:
	var profile: Dictionary = battle_system.get_encounter_settlement_profile(
		encounter_id
	)
	if profile.is_empty():
		return {}
	profile["experience_victory"] = (
		BATTLE_EXPERIENCE_BOSS
		if bool(profile.get("is_boss", false))
		else BATTLE_EXPERIENCE_NORMAL
	)
	profile["experience_defeat"] = BATTLE_EXPERIENCE_DEFEAT
	return profile


func validate_formation_defense_settlement_plan(
	plan: Dictionary
) -> PackedStringArray:
	var errors := PackedStringArray()
	var outcome := String(plan.get("outcome", ""))
	if outcome not in ["victory", "failure"]:
		errors.append("formal settlement outcome must be victory or failure")
	var v2_outcome := String(plan.get("v2_outcome", ""))
	var expected_v2_outcome := (
		"VICTORY" if outcome == "victory" else "DEFEAT"
	)
	if v2_outcome != expected_v2_outcome:
		errors.append("formal settlement V2 outcome does not match")
	var village_durability = plan.get("village_durability", {})
	if not village_durability is Dictionary:
		errors.append("formal settlement village durability must be a dictionary")
	else:
		var durability_remaining := int(village_durability.get("remaining", -1))
		var durability_maximum := int(village_durability.get("maximum", 0))
		if durability_maximum <= 0 or durability_remaining < 0 \
				or durability_remaining > durability_maximum:
			errors.append("formal settlement village durability is outside range")
		elif outcome == "victory" and durability_remaining <= 0:
			errors.append("formal settlement victory requires surviving village durability")
		elif outcome == "failure" and durability_remaining != 0:
			errors.append("formal settlement failure requires zero village durability")
	var encounter_id := StringName(plan.get("encounter_id", &""))
	var node_id := StringName(plan.get("node_id", &""))
	var profile := get_formal_battle_settlement_profile(encounter_id)
	if profile.is_empty():
		errors.append("formal settlement encounter does not exist")
	else:
		if StringName(profile.get("node_id", &"")) != node_id:
			errors.append("formal settlement encounter node does not match")
		if bool(profile.get("is_boss", false)) != bool(plan.get("is_boss", false)):
			errors.append("formal settlement boss flag does not match")
		var rewards: Dictionary = plan.get("rewards", {})
		for reward_id: String in ["ore", "herb", "core"]:
			var expected_reward := (
				int(profile.get("reward_%s" % reward_id, 0))
				if outcome == "victory"
				else 0
			)
			if int(rewards.get(reward_id, -1)) != int(
				expected_reward
			):
				errors.append("formal settlement %s reward does not match" % reward_id)
		var expected_experience := int(profile.get(
			"experience_victory" if outcome == "victory" else "experience_defeat",
			-1
		))
		if int(plan.get("experience_per_character", -1)) != expected_experience:
			errors.append("formal settlement experience does not match")
	if not is_expedition_active():
		errors.append("formal settlement requires an active expedition")
	else:
		if StringName(expedition_state.get("current_node_id", &"")) != node_id:
			errors.append("formal settlement current expedition node does not match")
		if get_current_node_encounter_id() != encounter_id:
			errors.append("formal settlement current encounter does not match")
		if is_current_battle_node_cleared():
			errors.append("formal settlement encounter is already cleared")
	var participant_ids = plan.get("participant_ids", [])
	if not participant_ids is Array or participant_ids.is_empty() \
			or participant_ids.size() > Stage12Config.MAX_PARTY_SIZE:
		errors.append("formal settlement participant IDs must contain 1 to 4 members")
	else:
		var seen_ids: Array[StringName] = []
		for raw_character_id in participant_ids:
			var character_id := StringName(raw_character_id)
			var record = character_roster.get_character(character_id)
			if character_id == &"" or seen_ids.has(character_id):
				errors.append("formal settlement participant IDs must be unique")
			elif record == null or not record.is_combat_character():
				errors.append("formal settlement participant is not a combat character")
			seen_ids.append(character_id)
	var runtime_updates = plan.get("runtime_hp_updates", [])
	if not runtime_updates is Array \
			or runtime_updates.size() != participant_ids.size():
		errors.append("formal settlement runtime HP updates must match participants")
	else:
		var update_ids: Array[StringName] = []
		var downed_count := 0
		for raw_update in runtime_updates:
			if not raw_update is Dictionary:
				errors.append("formal settlement runtime HP update must be a dictionary")
				continue
			var character_id := StringName(raw_update.get("character_id", &""))
			var max_hp := int(get_final_combat_stats(character_id).get("max_hp", 0))
			var current_hp := int(raw_update.get("current_hp", -1))
			if character_id not in participant_ids or update_ids.has(character_id):
				errors.append("formal settlement runtime HP update ID does not match")
			if max_hp <= 0 or current_hp < 0 or current_hp > max_hp:
				errors.append("formal settlement runtime HP update is outside range")
			if bool(raw_update.get("is_down", false)) != (current_hp <= 0):
				errors.append("formal settlement down state does not match HP")
			if bool(raw_update.get("is_down", false)):
				downed_count += 1
			update_ids.append(character_id)
		if int(plan.get("downed_participant_count", -1)) != downed_count:
			errors.append("formal settlement downed participant count does not match")
	return errors


func apply_formation_defense_settlement_plan(plan: Dictionary) -> Dictionary:
	var errors := validate_formation_defense_settlement_plan(plan)
	if not errors.is_empty():
		return {"ok": false, "errors": errors, "value": {}}
	for update: Dictionary in plan.get("runtime_hp_updates", []):
		var character_id := StringName(update.get("character_id", &""))
		var runtime_state = character_runtime_states.get(character_id, null)
		runtime_state.current_hp = int(update.get("current_hp", 0))
		character_runtime_states[character_id] = runtime_state
		character_runtime_state_changed.emit(character_id)
	rebuild_adventurers_from_character_data(false)

	var participant_ids: Array = plan.get("participant_ids", []).duplicate()
	var experience_reward := int(plan.get("experience_per_character", 0))
	var experience_results := _grant_battle_experience_to_character_ids(
		participant_ids,
		experience_reward
	)
	_emit_battle_experience_results(experience_results)
	var rewards: Dictionary = plan.get("rewards", {})
	var result := {
		"outcome": String(plan.get("outcome", "")),
		"encounter_id": StringName(plan.get("encounter_id", &"")),
		"node_id": StringName(plan.get("node_id", &"")),
		"party_states": [],
		"reward_ore": int(rewards.get("ore", 0)),
		"reward_herb": int(rewards.get("herb", 0)),
		"reward_core": int(rewards.get("core", 0)),
		"is_boss": bool(plan.get("is_boss", false)),
		"experience_reward": experience_reward,
		"experience_results": experience_results,
		"experience_processed": true,
		"stage12f_result_processed": true,
	}
	var outcome_report := _apply_formal_battle_outcome(
		result,
		participant_ids
	)
	result["character_injury_results"] = outcome_report.get(
		"character_injury_results",
		[]
	).duplicate(true)
	result["expedition_report"] = outcome_report.get(
		"expedition_report",
		{}
	).duplicate(true)
	result["settlement_id"] = String(plan.get("settlement_id", ""))
	result["battle_session_id"] = String(plan.get("battle_session_id", ""))
	result["battle_id"] = String(plan.get("battle_id", ""))
	result["v2_outcome"] = String(plan.get("v2_outcome", ""))
	result["village_durability"] = plan.get(
		"village_durability",
		{}
	).duplicate(true)
	result["downed_participant_count"] = int(
		plan.get("downed_participant_count", 0)
	)
	result["node_completed"] = String(result["outcome"]) == "victory"
	result["expedition_continues"] = is_expedition_active()
	result["return_view"] = "expedition" if is_expedition_active() else "village"
	result["message"] = "V2-8D正式结算已应用，未自动保存"
	last_battle_result = result.duplicate(true)
	battle_state_changed.emit()
	battle_finished.emit(result.duplicate(true))
	state_changed.emit()
	return {"ok": true, "errors": PackedStringArray(), "value": result}


func process_battle_result(result: Dictionary) -> void:
	if bool(result.get("stage12f_result_processed", false)):
		last_battle_result = result.duplicate(true)
		return
	_grant_battle_result_experience(result)
	last_battle_result = result.duplicate(true)
	_apply_formal_battle_outcome(result)

	battle_state_changed.emit()
	result["stage12f_result_processed"] = true
	last_battle_result = result.duplicate(true)
	battle_finished.emit(result.duplicate(true))
	state_changed.emit()


func get_battle_state() -> Dictionary:
	return battle_state.duplicate(true)


func get_last_battle_result() -> Dictionary:
	return last_battle_result.duplicate(true)


func get_last_battle_presentation_events() -> Array:
	return last_battle_presentation_events.duplicate(true)


func get_active_battle_unit() -> Dictionary:
	return battle_system.get_active_unit(battle_state).duplicate(true)


func get_battle_party_states() -> Array:
	if battle_state.is_empty() or not battle_state.has("party_states") or not bool(battle_state.get("is_active", false)):
		return adventurers.duplicate(true)
	return battle_state["party_states"].duplicate(true)


func get_battle_enemy_states() -> Array:
	if battle_state.is_empty() or not battle_state.has("enemy_states"):
		return []
	return battle_state["enemy_states"].duplicate(true)


func get_character_ids() -> Array[StringName]:
	return character_roster.get_party_character_ids()


func can_edit_party() -> bool:
	return not is_expedition_active() and not is_battle_active()


func set_party_members(character_ids: Array) -> bool:
	if not can_edit_party():
		push_gameplay_notification("远征或战斗期间不能调整队伍。", &"error")
		return false
	var typed_ids: Array[StringName] = []
	for raw_id in character_ids:
		typed_ids.append(StringName(raw_id))
	if not character_roster.set_party_members(typed_ids):
		push_gameplay_notification("队伍调整失败：队伍必须保持1～4名且角色不能重复。", &"error")
		return false
	_after_party_changed()
	push_gameplay_notification("队伍编成已更新。", &"party")
	return true


func set_character_party_status(character_id: StringName, is_in_party: bool) -> bool:
	if not can_edit_party():
		push_gameplay_notification("远征或战斗期间不能调整队伍。", &"error")
		return false
	if not character_roster.set_character_party_status(character_id, is_in_party):
		push_gameplay_notification(
			"编队失败：队伍必须保持1～4名且不能重复加入。",
			&"error",
			{"character_id": character_id}
		)
		return false
	_after_party_changed()
	push_gameplay_notification(
		"%s已%s。" % [
			get_character_display_name(character_id),
			"加入出战" if is_in_party else "设为待命",
		],
		&"party",
		{"character_id": character_id}
	)
	return true


func move_party_character(character_id: StringName, target_slot: int) -> bool:
	if not can_edit_party():
		push_gameplay_notification("远征或战斗期间不能调整队伍。", &"error")
		return false
	if not character_roster.move_party_character(character_id, target_slot):
		push_gameplay_notification("队伍位置调整失败：目标位置无效。", &"error")
		return false
	_after_party_changed()
	push_gameplay_notification("队伍顺序已调整。", &"party")
	return true


func get_roster_character_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for snapshot: Dictionary in character_roster.get_all_character_snapshots():
		ids.append(StringName(snapshot.get("character_id", &"")))
	return ids


func get_all_combat_characters() -> Array:
	return character_roster.get_combat_character_snapshots()


func get_all_life_characters() -> Array:
	return character_roster.get_life_character_snapshots()


func get_filtered_sorted_life_characters(
	filter_id: StringName = &"all",
	sort_id: StringName = &"created"
) -> Array:
	var filtered: Array = []
	for snapshot: Dictionary in get_all_life_characters():
		if _life_character_matches_filter(snapshot, filter_id):
			filtered.append(snapshot)
	filtered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_value = _get_life_character_sort_value(a, sort_id)
		var b_value = _get_life_character_sort_value(b, sort_id)
		if a_value == b_value:
			return int(a.get("created_sequence", 0)) < int(b.get("created_sequence", 0))
		if sort_id == &"created":
			return int(a_value) < int(b_value)
		return int(a_value) > int(b_value)
	)
	return filtered


func get_life_character_filter_options() -> Array:
	return [
		{"filter_id": &"all", "display_name": "全部"},
		{"filter_id": &"idle", "display_name": "空闲"},
		{"filter_id": &"working", "display_name": "工作中"},
		{"filter_id": &"farming", "display_name": "擅长农业"},
		{"filter_id": &"crafting", "display_name": "擅长制造"},
		{"filter_id": &"gathering", "display_name": "擅长采集"},
		{"filter_id": &"research", "display_name": "擅长研究"},
		{"filter_id": &"medical", "display_name": "擅长医疗"},
	]


func get_life_character_sort_options() -> Array:
	return [
		{"sort_id": &"created", "display_name": "创建顺序"},
		{"sort_id": &"level", "display_name": "等级"},
		{"sort_id": &"quality", "display_name": "品质"},
		{"sort_id": &"farming", "display_name": "农业"},
		{"sort_id": &"crafting", "display_name": "制造"},
		{"sort_id": &"gathering", "display_name": "采集"},
		{"sort_id": &"research", "display_name": "研究"},
		{"sort_id": &"medical", "display_name": "医疗"},
	]


func get_idle_life_characters() -> Array:
	var result: Array = []
	for snapshot: Dictionary in get_all_life_characters():
		var life_data: Dictionary = snapshot.get("life_data", {})
		if int(life_data.get("work_state", CharacterEnumsScript.WorkState.IDLE)) != CharacterEnumsScript.WorkState.IDLE:
			continue
		if StringName(life_data.get("assigned_building_id", &"")) != &"":
			continue
		if StringName(life_data.get("assigned_job_id", &"")) != &"":
			continue
		result.append(snapshot)
	return result


func get_building_jobs(building_id: StringName) -> Array:
	return building_system.get_building_jobs(self, building_id)


func get_building_job_slot_count_config(building_id: StringName) -> Dictionary:
	return building_system.get_job_slot_count_config(building_id)


func sync_building_jobs_to_level(
	building_id: StringName,
	emit_signals: bool = true
) -> Dictionary:
	var sync_result: Dictionary = building_system.sync_runtime_jobs_for_building(
		self, building_id
	)
	if not bool(sync_result.get("success", false)):
		return sync_result
	var reconciliation := reconcile_life_job_assignments(false)
	var repaired_character_ids: Array = reconciliation.get(
		"repaired_character_ids", []
	).duplicate()
	for raw_character_id in sync_result.get("removed_character_ids", []):
		var character_id := StringName(raw_character_id)
		if character_id != &"" and not repaired_character_ids.has(character_id):
			repaired_character_ids.append(character_id)
	sync_result["repaired_character_ids"] = repaired_character_ids
	sync_result["cleared_job_count"] = int(reconciliation.get("cleared_job_count", 0))
	if emit_signals and (
		bool(sync_result.get("job_count_changed", false))
		or not repaired_character_ids.is_empty()
	):
		_emit_life_job_changes(repaired_character_ids, [building_id])
	return sync_result


func sync_all_building_jobs_to_levels(emit_signals: bool = true) -> Dictionary:
	var changed_building_ids: Array[StringName] = []
	var removed_character_ids: Array[StringName] = []
	for building_id: StringName in get_building_ids():
		var sync_result: Dictionary = building_system.sync_runtime_jobs_for_building(
			self, building_id
		)
		if bool(sync_result.get("job_count_changed", false)):
			changed_building_ids.append(building_id)
		for raw_character_id in sync_result.get("removed_character_ids", []):
			var character_id := StringName(raw_character_id)
			if character_id != &"" and not removed_character_ids.has(character_id):
				removed_character_ids.append(character_id)
	var reconciliation := reconcile_life_job_assignments(false)
	var repaired_character_ids: Array = reconciliation.get(
		"repaired_character_ids", []
	).duplicate()
	for character_id: StringName in removed_character_ids:
		if not repaired_character_ids.has(character_id):
			repaired_character_ids.append(character_id)
	for raw_building_id in reconciliation.get("changed_building_ids", []):
		var repaired_building_id := StringName(raw_building_id)
		if not changed_building_ids.has(repaired_building_id):
			changed_building_ids.append(repaired_building_id)
	if emit_signals and (
		not changed_building_ids.is_empty()
		or not repaired_character_ids.is_empty()
	):
		_emit_life_job_changes(repaired_character_ids, changed_building_ids)
	return {
		"changed_building_ids": changed_building_ids,
		"repaired_character_ids": repaired_character_ids,
		"cleared_job_count": int(reconciliation.get("cleared_job_count", 0)),
	}


func get_building_assigned_characters(building_id: StringName) -> Array:
	var result: Array = []
	for job: Dictionary in get_building_jobs(building_id):
		var character_id := StringName(job.get("character_id", &""))
		if character_id == &"":
			continue
		var entry := job.duplicate(true)
		entry["character"] = get_roster_character(character_id)
		result.append(entry)
	return result


func assign_life_character_to_job(character_id: StringName, building_id: StringName, job_id: StringName) -> bool:
	var record = character_roster.get_character(character_id)
	var job: Dictionary = building_system.get_building_job(self, building_id, job_id)
	if record == null or not record.is_life_character() or job.is_empty():
		push_gameplay_notification("岗位分配失败：角色或岗位不存在。", &"error")
		return false
	if record.life_data.work_state == CharacterEnumsScript.WorkState.UNAVAILABLE:
		push_gameplay_notification("岗位分配失败：角色当前不可用。", &"error")
		return false
	var existing_references: Array = building_system.get_character_job_references(self, character_id)
	if not existing_references.is_empty():
		var existing: Dictionary = existing_references[0]
		if existing_references.size() == 1 \
				and StringName(existing.get("building_id", &"")) == building_id \
				and StringName(existing.get("job_id", &"")) == job_id:
			character_roster.set_life_assignment(
				character_id, building_id, job_id, CharacterEnumsScript.WorkState.WORKING
			)
			_emit_life_job_changes([character_id], [building_id])
			push_gameplay_notification(
				"%s已在该岗位工作，无需重复分配。" % get_character_display_name(character_id),
				&"job",
				{"character_id": character_id, "building_id": building_id, "job_id": job_id}
			)
			return true
		push_gameplay_notification("岗位分配失败：角色已在其他岗位工作。", &"error")
		return false
	if record.life_data.assigned_building_id != &"" \
			or record.life_data.assigned_job_id != &"" \
			or record.life_data.work_state == CharacterEnumsScript.WorkState.WORKING:
		push_gameplay_notification(
			"岗位分配失败：角色岗位状态不一致，请先执行撤下。",
			&"error"
		)
		return false
	if StringName(job.get("character_id", &"")) != &"":
		push_gameplay_notification("岗位分配失败：岗位已有角色，请使用替换。", &"error")
		return false
	if not building_system.set_job_character_id(self, building_id, job_id, character_id):
		push_gameplay_notification("岗位分配失败：岗位状态已变化。", &"error")
		return false
	if not character_roster.set_life_assignment(
		character_id, building_id, job_id, CharacterEnumsScript.WorkState.WORKING
	):
		building_system.set_job_character_id(self, building_id, job_id, &"")
		push_gameplay_notification("岗位分配失败：角色状态已变化。", &"error")
		return false
	_emit_life_job_changes([character_id], [building_id])
	push_gameplay_notification(
		"%s岗位分配成功。" % get_character_display_name(character_id),
		&"job",
		{"character_id": character_id, "building_id": building_id, "job_id": job_id}
	)
	return true


func unassign_life_character(character_id: StringName) -> bool:
	var record = character_roster.get_character(character_id)
	if record == null or not record.is_life_character():
		push_gameplay_notification("撤下失败：生活角色不存在。", &"error")
		return false
	var changed_buildings: Array[StringName] = building_system.clear_character_job_references(self, character_id)
	var recorded_building_id: StringName = record.life_data.assigned_building_id
	if recorded_building_id != &"" and not changed_buildings.has(recorded_building_id):
		changed_buildings.append(recorded_building_id)
	if not character_roster.set_life_assignment(
		character_id, &"", &"", CharacterEnumsScript.WorkState.IDLE
	):
		return false
	_emit_life_job_changes([character_id], changed_buildings)
	push_gameplay_notification(
		"%s已从岗位撤下。" % get_character_display_name(character_id),
		&"job",
		{"character_id": character_id}
	)
	return true


func unassign_building_job(building_id: StringName, job_id: StringName) -> bool:
	var job: Dictionary = building_system.get_building_job(self, building_id, job_id)
	if job.is_empty():
		push_gameplay_notification("撤下失败：岗位不存在。", &"error")
		return false
	var character_id := StringName(job.get("character_id", &""))
	if character_id == &"":
		push_gameplay_notification("撤下失败：岗位当前没有角色。", &"error")
		return false
	return unassign_life_character(character_id)


func replace_life_character_in_job(
	building_id: StringName,
	job_id: StringName,
	new_character_id: StringName
) -> bool:
	var job: Dictionary = building_system.get_building_job(self, building_id, job_id)
	var new_record = character_roster.get_character(new_character_id)
	if job.is_empty() or new_record == null or not new_record.is_life_character():
		push_gameplay_notification("岗位替换失败：角色或岗位不存在。", &"error")
		return false
	if new_record.life_data.work_state == CharacterEnumsScript.WorkState.UNAVAILABLE:
		push_gameplay_notification("岗位替换失败：新角色当前不可用。", &"error")
		return false
	var old_character_id := StringName(job.get("character_id", &""))
	if old_character_id == &"":
		return assign_life_character_to_job(new_character_id, building_id, job_id)
	if old_character_id == new_character_id:
		push_gameplay_notification(
			"%s已在该岗位工作，无需替换。" % get_character_display_name(new_character_id),
			&"job"
		)
		return true
	if not building_system.get_character_job_references(self, new_character_id).is_empty():
		push_gameplay_notification("岗位替换失败：新角色已在其他岗位工作。", &"error")
		return false
	if new_record.life_data.assigned_building_id != &"" \
			or new_record.life_data.assigned_job_id != &"" \
			or new_record.life_data.work_state == CharacterEnumsScript.WorkState.WORKING:
		push_gameplay_notification(
			"岗位替换失败：新角色岗位状态不一致，请先执行撤下。",
			&"error"
		)
		return false
	if not building_system.set_job_character_id(self, building_id, job_id, new_character_id):
		push_gameplay_notification("岗位替换失败：岗位状态已变化。", &"error")
		return false
	var old_record = character_roster.get_character(old_character_id)
	if old_record != null and old_record.is_life_character():
		character_roster.set_life_assignment(
			old_character_id, &"", &"", CharacterEnumsScript.WorkState.IDLE
		)
	if not character_roster.set_life_assignment(
		new_character_id, building_id, job_id, CharacterEnumsScript.WorkState.WORKING
	):
		building_system.set_job_character_id(self, building_id, job_id, old_character_id)
		if old_record != null and old_record.is_life_character():
			character_roster.set_life_assignment(
				old_character_id, building_id, job_id, CharacterEnumsScript.WorkState.WORKING
			)
		push_gameplay_notification("岗位替换失败：角色状态已变化。", &"error")
		return false
	_emit_life_job_changes([old_character_id, new_character_id], [building_id])
	push_gameplay_notification(
		"岗位已由%s替换为%s。" % [
			get_character_display_name(old_character_id),
			get_character_display_name(new_character_id),
		],
		&"job",
		{
			"old_character_id": old_character_id,
			"character_id": new_character_id,
			"building_id": building_id,
			"job_id": job_id,
		}
	)
	return true


func get_life_job_efficiency_preview(
	character_id: StringName,
	building_id: StringName,
	job_id: StringName
) -> Dictionary:
	return get_life_job_efficiency(character_id, building_id, job_id)


func get_life_job_efficiency(
	character_id: StringName,
	building_id: StringName,
	job_id: StringName
) -> Dictionary:
	var record = character_roster.get_character(character_id)
	var job: Dictionary = building_system.get_building_job(self, building_id, job_id)
	if record == null or not record.is_life_character() or job.is_empty() or record.life_data.life_stats == null:
		return {"success": false}
	var job_type := StringName(job.get("job_type", &""))
	var stat_data: Dictionary = record.life_data.life_stats.to_core_dictionary()
	var raw_stat_value: int = max(0, int(stat_data.get(String(job_type), 0)))
	var applied_stat_value: int = mini(raw_stat_value, LIFE_JOB_PREVIEW_STAT_CAP)
	var stat_bonus_percent := float(applied_stat_value) * LIFE_JOB_STAT_BONUS_PER_POINT
	var trait_bonuses: Dictionary = life_trait_database.get_bonus_totals(
		record.life_data.life_trait_ids, job_type
	)
	var trait_bonus_percent := float(trait_bonuses.get("efficiency_bonus_percent", 0.0))
	var efficiency_percent := 100.0 + stat_bonus_percent + trait_bonus_percent
	return {
		"success": true,
		"character_id": character_id,
		"building_id": building_id,
		"job_id": job_id,
		"job_type": job_type,
		"attribute_id": job_type,
		"attribute_value": raw_stat_value,
		"applied_attribute_value": applied_stat_value,
		"base_percent": 100.0,
		"attribute_bonus_percent": stat_bonus_percent,
		"trait_bonus_percent": trait_bonus_percent,
		"work_experience_bonus_percent": float(
			trait_bonuses.get("work_experience_bonus_percent", 0.0)
		),
		"production_bonus_percent": float(
			trait_bonuses.get("production_bonus_percent", 0.0)
		),
		"applied_trait_ids": trait_bonuses.get("applied_trait_ids", []).duplicate(),
		"efficiency_percent": efficiency_percent,
		"efficiency_multiplier": efficiency_percent / 100.0,
	}


func get_building_personnel_efficiency(building_id: StringName) -> Dictionary:
	var efficiency_total := 0.0
	var production_bonus_total := 0.0
	var assigned_count := 0
	var character_efficiencies: Array = []
	for job: Dictionary in get_building_jobs(building_id):
		var character_id := StringName(job.get("character_id", &""))
		if character_id == &"":
			continue
		var record = character_roster.get_character(character_id)
		var job_id := StringName(job.get("job_id", &""))
		if record == null \
				or not record.is_life_character() \
				or record.life_data.work_state != CharacterEnumsScript.WorkState.WORKING \
				or record.life_data.assigned_building_id != building_id \
				or record.life_data.assigned_job_id != job_id:
			continue
		var efficiency := get_life_job_efficiency(
			character_id,
			building_id,
			job_id
		)
		if not bool(efficiency.get("success", false)):
			continue
		assigned_count += 1
		efficiency_total += float(efficiency.get("efficiency_percent", 100.0))
		production_bonus_total += float(efficiency.get("production_bonus_percent", 0.0))
		character_efficiencies.append(efficiency)
	var personnel_efficiency_percent := 100.0
	var production_bonus_percent := 0.0
	if assigned_count > 0:
		personnel_efficiency_percent = efficiency_total / float(assigned_count)
		production_bonus_percent = production_bonus_total / float(assigned_count)
	return {
		"building_id": building_id,
		"assigned_count": assigned_count,
		"personnel_efficiency_percent": personnel_efficiency_percent,
		"personnel_efficiency_multiplier": personnel_efficiency_percent / 100.0,
		"production_bonus_percent": production_bonus_percent,
		"character_efficiencies": character_efficiencies,
	}


func get_building_final_production_multiplier(building_id: StringName) -> float:
	var details := get_building_personnel_efficiency(building_id)
	return float(details.get("personnel_efficiency_multiplier", 1.0)) * (
		1.0 + float(details.get("production_bonus_percent", 0.0)) / 100.0
	)


func get_building_production_details(building_id: StringName) -> Dictionary:
	var details := get_building_personnel_efficiency(building_id)
	var final_multiplier := get_building_final_production_multiplier(building_id)
	details["final_production_multiplier"] = final_multiplier
	details["final_production_percent"] = final_multiplier * 100.0
	details["integer_rounding_rule"] = "round_half_up"
	return details


func calculate_building_production_output(building_id: StringName, base_amount: int) -> int:
	if base_amount <= 0:
		return 0
	return int(floor(float(base_amount) * get_building_final_production_multiplier(
		building_id
	) + 0.5))


func get_life_trait_details(character_id: StringName) -> Array:
	var record = character_roster.get_character(character_id)
	var result: Array = []
	if record == null or not record.is_life_character():
		return result
	for trait_id: StringName in record.life_data.life_trait_ids:
		var definition: Dictionary = life_trait_database.get_definition_data(trait_id)
		if definition.is_empty():
			definition = {
				"trait_id": trait_id,
				"display_name": String(trait_id),
				"description": "尚未配置说明。",
				"applicable_job_types": [],
				"efficiency_bonus_percent": 0.0,
				"work_experience_bonus_percent": 0.0,
				"production_bonus_percent": 0.0,
			}
		result.append(definition)
	return result


func get_life_experience_to_next_level(level: int) -> int:
	return character_roster.get_life_experience_to_next_level(level)


func get_combat_max_level() -> int:
	return Stage12Config.COMBAT_MAX_LEVEL


func get_life_max_level() -> int:
	return Stage12Config.LIFE_MAX_LEVEL


func is_character_at_max_level(character_id: StringName) -> bool:
	var snapshot := get_roster_character(character_id)
	if snapshot.is_empty():
		return false
	var max_level := (
		Stage12Config.LIFE_MAX_LEVEL
		if StringName(snapshot.get("character_type_name", &"")) == &"life"
		else Stage12Config.COMBAT_MAX_LEVEL
	)
	return int(snapshot.get("level", 1)) >= max_level


func get_character_status_labels(character_id: StringName) -> Array[String]:
	var snapshot := get_roster_character(character_id)
	var result: Array[String] = []
	if snapshot.is_empty():
		return result
	if StringName(snapshot.get("character_type_name", &"")) == &"combat":
		var combat_data: Dictionary = snapshot.get("combat_data", {})
		result.append(
			"◆ 出战" if bool(combat_data.get("is_in_party", false)) else "◇ 待命"
		)
		if StringName(combat_data.get("injury_state", &"healthy")) == &"injured":
			result.append("✚ 受伤")
	else:
		var work_state := int(snapshot.get("life_data", {}).get(
			"work_state", CharacterEnumsScript.WorkState.IDLE
		))
		match work_state:
			CharacterEnumsScript.WorkState.WORKING:
				result.append("● 工作中")
			CharacterEnumsScript.WorkState.UNAVAILABLE:
				result.append("× 不可用")
			_:
				result.append("○ 空闲")
	if bool(snapshot.get("is_locked", false)):
		result.append("■ 已锁定")
	return result


func get_life_character_upgrade_requirement(character_id: StringName) -> int:
	var record = character_roster.get_character(character_id)
	if record == null or not record.is_life_character():
		return 0
	return character_roster.get_life_experience_to_next_level(record.level)


func add_life_character_experience(
	character_id: StringName,
	amount: int,
	emit_signals: bool = true
) -> Dictionary:
	var record = character_roster.get_character(character_id)
	if record == null or not record.is_life_character():
		return {"success": false, "character_id": character_id, "levels_gained": 0}
	var preferred_stat_id := &""
	if record.life_data.assigned_building_id != &"" and record.life_data.assigned_job_id != &"":
		var job: Dictionary = building_system.get_building_job(
			self,
			record.life_data.assigned_building_id,
			record.life_data.assigned_job_id
		)
		preferred_stat_id = StringName(job.get("job_type", &""))
	var result := character_roster.grant_life_experience(
		character_id, amount, preferred_stat_id
	)
	if not bool(result.get("success", false)) or not emit_signals:
		return result
	character_data_changed.emit(character_id)
	character_roster_changed.emit()
	life_character_experience_changed.emit(
		character_id,
		int(result.get("experience", 0)),
		int(result.get("experience_to_next_level", 0))
	)
	if int(result.get("levels_gained", 0)) > 0:
		life_character_leveled_up.emit(
			character_id,
			int(result.get("new_level", 1)),
			result.get("growth_by_stat", {}).duplicate(true)
		)
		push_gameplay_notification(
			"%s升级至Lv.%d。" % [
				get_character_display_name(character_id),
				int(result.get("new_level", 1)),
			],
			&"level_up",
			{
				"character_id": character_id,
				"levels_gained": int(result.get("levels_gained", 0)),
				"growth_by_stat": result.get("growth_by_stat", {}).duplicate(true),
			}
		)
	state_changed.emit()
	return result


func settle_life_job_work_experience(
	building_id: StringName,
	settlement_key: StringName
) -> Array:
	if settlement_key == &"" or get_building_data(building_id) == null:
		return []
	if StringName(life_work_settlement_keys.get(building_id, &"")) == settlement_key:
		return []
	# Mark the completed cycle even when no one is assigned, so assigning after
	# completion cannot retroactively collect experience.
	life_work_settlement_keys[building_id] = settlement_key
	var results: Array = []
	var production_details := get_building_production_details(building_id)
	for job: Dictionary in get_building_jobs(building_id):
		var character_id := StringName(job.get("character_id", &""))
		if character_id == &"":
			continue
		var record = character_roster.get_character(character_id)
		var job_id := StringName(job.get("job_id", &""))
		if record == null \
				or not record.is_life_character() \
				or record.life_data.work_state != CharacterEnumsScript.WorkState.WORKING \
				or record.life_data.assigned_building_id != building_id \
				or record.life_data.assigned_job_id != job_id:
			continue
		var efficiency := get_life_job_efficiency(character_id, building_id, job_id)
		if not bool(efficiency.get("success", false)):
			continue
		var experience_bonus_percent := float(
			efficiency.get("work_experience_bonus_percent", 0.0)
		)
		var experience_amount := int(floor(
			float(LIFE_WORK_BASE_EXPERIENCE)
				* (1.0 + experience_bonus_percent / 100.0)
				+ 0.5
		))
		var result := add_life_character_experience(character_id, experience_amount)
		if bool(result.get("success", false)):
			result["job_id"] = job_id
			result["job_type"] = StringName(job.get("job_type", &""))
			result["base_experience"] = LIFE_WORK_BASE_EXPERIENCE
			result["experience_bonus_percent"] = experience_bonus_percent
			result["final_production_multiplier"] = float(
				production_details.get("final_production_multiplier", 1.0)
			)
			results.append(result)
	life_work_settled.emit(building_id, results.duplicate(true))
	return results


func get_life_work_state_display_name(work_state: int) -> String:
	match work_state:
		CharacterEnumsScript.WorkState.WORKING:
			return "工作中"
		CharacterEnumsScript.WorkState.UNAVAILABLE:
			return "不可用"
	return "空闲"


func generate_life_character_candidate(forced_quality: int = -1) -> Dictionary:
	return life_recruitment_system.generate_candidate(self, forced_quality)


func get_life_recruitment_candidates() -> Array:
	return life_recruitment_system.get_candidates(self)


func get_life_recruitment_candidate(candidate_id: StringName) -> Dictionary:
	return life_recruitment_system.get_candidate(self, candidate_id)


func refresh_life_recruitment_candidates() -> bool:
	var result: Dictionary = life_recruitment_system.refresh_candidates(self)
	if not bool(result.get("success", false)):
		push_gameplay_notification(get_life_recruitment_last_error(), &"error")
		return false
	life_recruitment_candidates_changed.emit()
	state_changed.emit()
	push_gameplay_notification("候选刷新成功，已保留锁定候选。", &"recruitment")
	return true


func set_life_recruitment_candidate_locked(
	candidate_id: StringName,
	is_locked: bool
) -> bool:
	if not life_recruitment_system.set_candidate_locked(
		self, candidate_id, is_locked
	):
		push_gameplay_notification(get_life_recruitment_last_error(), &"error")
		return false
	life_recruitment_candidates_changed.emit()
	state_changed.emit()
	push_gameplay_notification(
		"候选已%s。" % ("锁定" if is_locked else "取消锁定"),
		&"recruitment",
		{"candidate_id": candidate_id, "is_locked": is_locked}
	)
	return true


func recruit_life_candidate(candidate_id: StringName) -> bool:
	var result: Dictionary = life_recruitment_system.recruit_candidate(
		self, candidate_id
	)
	if not bool(result.get("success", false)):
		push_gameplay_notification(get_life_recruitment_last_error(), &"error")
		return false
	character_roster_changed.emit()
	character_data_changed.emit(candidate_id)
	life_recruitment_candidates_changed.emit()
	life_character_recruited.emit(candidate_id)
	_emit_life_character_capacity_changed()
	state_changed.emit()
	push_gameplay_notification(
		"招募成功：%s已加入生活角色名册。" % get_character_display_name(candidate_id),
		&"recruitment",
		{"character_id": candidate_id}
	)
	return true


func get_life_character_capacity() -> int:
	return life_recruitment_system.get_life_character_capacity(self)


func get_life_character_capacity_details() -> Dictionary:
	return life_recruitment_system.get_capacity_details(self)


func get_life_recruitment_costs() -> Dictionary:
	return life_recruitment_system.get_cost_config()


func get_life_recruitment_generation_config() -> Dictionary:
	return life_recruitment_system.get_generation_config()


func get_life_recruitment_quality_for_roll(roll: int) -> int:
	return life_recruitment_system.get_quality_for_roll(roll)


func get_life_quality_display_name(quality: int) -> String:
	return life_recruitment_system.get_quality_display_name(quality)


func get_life_recruitment_last_error() -> String:
	return life_recruitment_system.last_error


func get_life_recruitment_state_for_save() -> Dictionary:
	var saved_state := life_recruitment_state.duplicate(true)
	# RNG state is a 64-bit integer. Store it as text so JSON round trips do not
	# lose precision through floating-point number parsing.
	saved_state["random_seed"] = str(
		int(life_recruitment_state.get("random_seed", 0))
	)
	saved_state["random_state"] = str(
		int(life_recruitment_state.get("random_state", 0))
	)
	return saved_state


func normalize_life_recruitment_state(raw_state: Dictionary) -> Dictionary:
	return life_recruitment_system.normalize_loaded_state(self, raw_state)


func set_life_character_locked(character_id: StringName, is_locked: bool) -> bool:
	var record = character_roster.get_character(character_id)
	if record == null or not record.is_life_character():
		push_gameplay_notification("角色锁定状态修改失败：生活角色不存在。", &"error")
		return false
	if record.is_locked == is_locked:
		return true
	if not character_roster.set_character_locked(character_id, is_locked):
		return false
	character_data_changed.emit(character_id)
	character_roster_changed.emit()
	life_character_lock_changed.emit(character_id, is_locked)
	state_changed.emit()
	push_gameplay_notification(
		"%s已%s。" % [
			get_character_display_name(character_id),
			"锁定" if is_locked else "取消锁定",
		],
		&"character",
		{"character_id": character_id, "is_locked": is_locked}
	)
	return true


func dismiss_life_character(
	character_id: StringName,
	auto_unassign: bool = true
) -> bool:
	var record = character_roster.get_character(character_id)
	if record == null or not record.is_life_character() or record.is_locked:
		push_gameplay_notification("解雇失败：角色不存在、类型无效或已锁定。", &"error")
		return false
	var is_assigned: bool = record.life_data.assigned_building_id != &"" \
		or record.life_data.assigned_job_id != &"" \
		or record.life_data.work_state == CharacterEnumsScript.WorkState.WORKING
	if is_assigned and not auto_unassign:
		push_gameplay_notification("解雇失败：工作中角色需要先确认自动撤岗。", &"error")
		return false
	var display_name := String(record.display_name)
	if not remove_roster_character(character_id):
		push_gameplay_notification("解雇失败：角色或岗位状态已变化。", &"error")
		return false
	life_character_dismissed.emit(character_id)
	state_changed.emit()
	push_gameplay_notification(
		"解雇成功：%s已离开名册。" % display_name,
		&"dismissal",
		{"character_id": character_id}
	)
	return true


func get_character_roster_data() -> Dictionary:
	return character_roster.to_dictionary()


func get_roster_character(character_id: StringName) -> Dictionary:
	return character_roster.get_character_snapshot(character_id)


func has_roster_character(character_id: StringName) -> bool:
	return character_roster.has_character(character_id)


func generate_character_id(prefix: String = "character") -> StringName:
	return character_roster.generate_unique_id(prefix)


func add_roster_character(
	character_data: Dictionary,
	emit_signals: bool = true
) -> bool:
	if not character_roster.add_character_from_dictionary(character_data):
		return false
	character_runtime_states = character_roster.create_combat_runtime_adapter()
	if not emit_signals:
		return true
	character_roster_changed.emit()
	character_data_changed.emit(StringName(character_data.get("character_id", &"")))
	if int(character_data.get("character_type", CharacterEnumsScript.CharacterType.COMBAT)) \
			== CharacterEnumsScript.CharacterType.LIFE:
		_emit_life_character_capacity_changed()
	state_changed.emit()
	return true


func remove_roster_character(character_id: StringName) -> bool:
	var snapshot: Dictionary = get_roster_character(character_id)
	if snapshot.is_empty() or bool(snapshot.get("is_locked", false)):
		return false
	if StringName(snapshot.get("character_type_name", &"")) == &"life":
		unassign_life_character(character_id)
	if not character_roster.remove_character(character_id):
		return false
	character_runtime_states = character_roster.create_combat_runtime_adapter()
	rebuild_adventurers_from_character_data(false)
	character_roster_changed.emit()
	if StringName(snapshot.get("character_type_name", &"")) == &"life":
		_emit_life_character_capacity_changed()
	state_changed.emit()
	return true


func set_life_character_assignment(character_id: StringName, building_id: StringName, job_id: StringName, work_state: int) -> bool:
	if work_state == CharacterEnumsScript.WorkState.WORKING:
		return assign_life_character_to_job(character_id, building_id, job_id)
	if building_id != &"" or job_id != &"":
		return false
	if work_state == CharacterEnumsScript.WorkState.IDLE:
		return unassign_life_character(character_id)
	if work_state != CharacterEnumsScript.WorkState.UNAVAILABLE:
		return false
	var record = character_roster.get_character(character_id)
	if record == null or not record.is_life_character():
		return false
	var changed_buildings: Array[StringName] = building_system.clear_character_job_references(self, character_id)
	if record.life_data.assigned_building_id != &"" and not changed_buildings.has(record.life_data.assigned_building_id):
		changed_buildings.append(record.life_data.assigned_building_id)
	if not character_roster.set_life_assignment(
		character_id, &"", &"", CharacterEnumsScript.WorkState.UNAVAILABLE
	):
		return false
	_emit_life_job_changes([character_id], changed_buildings)
	return true


func set_life_character_work_experience(character_id: StringName, work_experience: int) -> bool:
	if not character_roster.set_life_work_experience(character_id, work_experience):
		return false
	character_roster_changed.emit()
	character_data_changed.emit(character_id)
	state_changed.emit()
	return true


func reconcile_life_job_assignments(emit_signals: bool = false) -> Dictionary:
	building_system.ensure_initial_runtime_state(self)
	var seen_characters: Dictionary = {}
	var changed_buildings: Array[StringName] = []
	var repaired_characters: Array[StringName] = []
	var cleared_job_count := 0
	for building_id: StringName in get_building_ids():
		for job: Dictionary in get_building_jobs(building_id):
			var job_id := StringName(job.get("job_id", &""))
			var character_id := StringName(job.get("character_id", &""))
			if character_id == &"":
				continue
			var record = character_roster.get_character(character_id)
			var should_clear: bool = record == null \
				or not record.is_life_character() \
				or record.life_data.work_state == CharacterEnumsScript.WorkState.UNAVAILABLE \
				or seen_characters.has(character_id)
			if should_clear:
				building_system.set_job_character_id(self, building_id, job_id, &"")
				if not changed_buildings.has(building_id):
					changed_buildings.append(building_id)
				cleared_job_count += 1
				continue
			seen_characters[character_id] = {"building_id": building_id, "job_id": job_id}
			if record.life_data.assigned_building_id != building_id \
					or record.life_data.assigned_job_id != job_id \
					or record.life_data.work_state != CharacterEnumsScript.WorkState.WORKING:
				character_roster.set_life_assignment(
					character_id, building_id, job_id, CharacterEnumsScript.WorkState.WORKING
				)
				if not repaired_characters.has(character_id):
					repaired_characters.append(character_id)

	for record in character_roster.get_all_life_characters():
		var character_id: StringName = record.character_id
		if seen_characters.has(character_id):
			continue
		if record.life_data.work_state == CharacterEnumsScript.WorkState.UNAVAILABLE:
			if record.life_data.assigned_building_id != &"" or record.life_data.assigned_job_id != &"":
				character_roster.set_life_assignment(
					character_id, &"", &"", CharacterEnumsScript.WorkState.UNAVAILABLE
				)
				repaired_characters.append(character_id)
			continue
		var recorded_building_id: StringName = record.life_data.assigned_building_id
		var recorded_job_id: StringName = record.life_data.assigned_job_id
		var recorded_job: Dictionary = building_system.get_building_job(
			self, recorded_building_id, recorded_job_id
		)
		if recorded_building_id != &"" \
				and recorded_job_id != &"" \
				and not recorded_job.is_empty() \
				and StringName(recorded_job.get("character_id", &"")) == &"":
			building_system.set_job_character_id(
				self, recorded_building_id, recorded_job_id, character_id
			)
			character_roster.set_life_assignment(
				character_id,
				recorded_building_id,
				recorded_job_id,
				CharacterEnumsScript.WorkState.WORKING
			)
			seen_characters[character_id] = {
				"building_id": recorded_building_id,
				"job_id": recorded_job_id,
			}
			if not changed_buildings.has(recorded_building_id):
				changed_buildings.append(recorded_building_id)
			repaired_characters.append(character_id)
			continue
		if record.life_data.assigned_building_id != &"" \
				or record.life_data.assigned_job_id != &"" \
				or record.life_data.work_state == CharacterEnumsScript.WorkState.WORKING:
			character_roster.set_life_assignment(
				character_id, &"", &"", CharacterEnumsScript.WorkState.IDLE
			)
			repaired_characters.append(character_id)

	if emit_signals and (not changed_buildings.is_empty() or not repaired_characters.is_empty()):
		_emit_life_job_changes(repaired_characters, changed_buildings)
	return {
		"repaired_character_ids": repaired_characters,
		"changed_building_ids": changed_buildings,
		"cleared_job_count": cleared_job_count,
	}


func _emit_life_job_changes(character_ids: Array, building_ids: Array) -> void:
	var emitted_characters: Array[StringName] = []
	for raw_character_id in character_ids:
		var character_id := StringName(raw_character_id)
		if character_id == &"" or emitted_characters.has(character_id):
			continue
		emitted_characters.append(character_id)
		character_data_changed.emit(character_id)
	character_roster_changed.emit()
	var emitted_buildings: Array[StringName] = []
	for raw_building_id in building_ids:
		var building_id := StringName(raw_building_id)
		if building_id == &"" or emitted_buildings.has(building_id):
			continue
		emitted_buildings.append(building_id)
		life_job_assignments_changed.emit(building_id)
		building_state_changed.emit(building_id)
	state_changed.emit()


func set_character_progression(character_id: StringName, level: int, experience: int, experience_to_next_level: int) -> bool:
	if not character_roster.set_character_progression(character_id, level, experience, experience_to_next_level):
		return false
	if character_runtime_states.has(character_id):
		clamp_character_runtime_hp_to_final_max(character_id)
		rebuild_adventurers_from_character_data(false)
	character_roster_changed.emit()
	character_data_changed.emit(character_id)
	character_final_stats_changed.emit(character_id)
	state_changed.emit()
	return true


func grant_character_experience(character_id: StringName, amount: int, emit_signals: bool = true) -> Dictionary:
	var record = character_roster.get_character(character_id)
	if record == null or not record.is_combat_character():
		return {"success": false, "character_id": character_id, "levels_gained": 0}
	var old_stats := get_final_combat_stats(character_id)
	var old_max_hp := int(old_stats.get("max_hp", 1))
	var result: Dictionary = character_roster.grant_experience(character_id, amount)
	if not bool(result.get("success", false)):
		return result
	var new_stats := get_final_combat_stats(character_id)
	var new_max_hp := int(new_stats.get("max_hp", old_max_hp))
	if int(record.combat_data.current_hp) > 0:
		record.combat_data.current_hp = clampi(
			int(record.combat_data.current_hp) + maxi(0, new_max_hp - old_max_hp),
			1,
			new_max_hp
		)
	result["old_max_hp"] = old_max_hp
	result["new_max_hp"] = new_max_hp
	result["current_hp"] = int(record.combat_data.current_hp)
	result["display_name"] = String(record.display_name)
	var stat_changes: Dictionary = {}
	for stat_id: String in ["max_hp", "attack", "defense", "speed"]:
		var old_value := int(old_stats.get(stat_id, 0))
		var new_value := int(new_stats.get(stat_id, old_value))
		if new_value != old_value:
			stat_changes[stat_id] = {
				"before": old_value,
				"after": new_value,
				"delta": new_value - old_value,
			}
	result["stat_changes"] = stat_changes
	if int(result.get("levels_gained", 0)) > 0:
		push_gameplay_notification(
			"%s升级至Lv.%d。" % [
				String(record.display_name),
				int(result.get("new_level", record.level)),
			],
			&"level_up",
			{
				"character_id": character_id,
				"levels_gained": int(result.get("levels_gained", 0)),
				"stat_changes": stat_changes.duplicate(true),
			}
		)
	if emit_signals:
		rebuild_adventurers_from_character_data(false)
		character_roster_changed.emit()
		character_data_changed.emit(character_id)
		character_runtime_state_changed.emit(character_id)
		character_final_stats_changed.emit(character_id)
		state_changed.emit()
	return result


func _grant_battle_result_experience(result: Dictionary) -> void:
	if bool(result.get("experience_processed", false)):
		return
	var experience_reward := BATTLE_EXPERIENCE_DEFEAT
	if String(result.get("outcome", "")) == "victory":
		experience_reward = BATTLE_EXPERIENCE_BOSS if bool(result.get("is_boss", false)) else BATTLE_EXPERIENCE_NORMAL
	var awarded_ids: Array[StringName] = []
	for party_unit: Dictionary in result.get("party_states", []):
		var character_id := StringName(party_unit.get("character_id", party_unit.get("unit_id", &"")))
		if character_id == &"" or awarded_ids.has(character_id):
			continue
		awarded_ids.append(character_id)
	var experience_results := _grant_battle_experience_to_character_ids(
		awarded_ids,
		experience_reward
	)
	result["experience_reward"] = experience_reward
	result["experience_results"] = experience_results
	result["experience_processed"] = true
	_emit_battle_experience_results(experience_results)


func _grant_battle_experience_to_character_ids(
	character_ids: Array,
	experience_reward: int
) -> Array:
	var experience_results: Array = []
	var awarded_ids: Array[StringName] = []
	for raw_character_id in character_ids:
		var character_id := StringName(raw_character_id)
		if character_id == &"" or awarded_ids.has(character_id):
			continue
		awarded_ids.append(character_id)
		var experience_result := grant_character_experience(
			character_id,
			experience_reward,
			false
		)
		if bool(experience_result.get("success", false)):
			experience_results.append(experience_result)
	return experience_results


func _emit_battle_experience_results(experience_results: Array) -> void:
	if experience_results.is_empty():
		return
	rebuild_adventurers_from_character_data(false)
	character_roster_changed.emit()
	for experience_result: Dictionary in experience_results:
		var character_id := StringName(experience_result.get("character_id", &""))
		character_data_changed.emit(character_id)
		character_runtime_state_changed.emit(character_id)
		character_final_stats_changed.emit(character_id)


func _apply_formal_battle_outcome(
	result: Dictionary,
	injury_character_ids: Array = []
) -> Dictionary:
	if String(result.get("outcome", "")) == "victory":
		statistics["total_battles_won"] = int(
			statistics.get("total_battles_won", 0)
		) + 1
		expedition_system.apply_battle_victory(self, result)
		if bool(result.get("is_boss", false)):
			boss_defeated = true
			boss_defeated_changed.emit()
		supplies_changed.emit()
		expedition_state_changed.emit()
		return {
			"character_injury_results": [],
			"expedition_report": {},
		}
	var report: Dictionary = expedition_system.apply_battle_failure(self, result)
	statistics["total_failed_expeditions"] = int(
		statistics.get("total_failed_expeditions", 0)
	) + 1
	var injury_results: Array = (
		hospital_system.process_expedition_injuries(self, true)
		if injury_character_ids.is_empty()
		else hospital_system.process_expedition_injuries_for_characters(
			self,
			true,
			injury_character_ids
		)
	)
	report["character_injury_results"] = injury_results.duplicate(true)
	report["team_injury_summary"] = get_team_injury_summary()
	last_expedition_report = report.duplicate(true)
	emit_injury_result_signals(injury_results)
	clear_expedition_meal_bonus()
	restore_character_runtime_states_full()
	rebuild_adventurers_from_character_data(false)
	emit_resources_changed()
	supplies_changed.emit()
	expedition_state_changed.emit()
	expedition_ended.emit(report.duplicate(true))
	return {
		"character_injury_results": injury_results,
		"expedition_report": report,
	}


func _after_party_changed() -> void:
	rebuild_adventurers_from_character_data(false)
	character_roster_changed.emit()
	for snapshot: Dictionary in get_all_combat_characters():
		character_data_changed.emit(StringName(snapshot.get("character_id", &"")))
	state_changed.emit()


func get_character_roster_debug_summary() -> String:
	return character_roster.get_debug_summary()


func get_character_display_name(character_id: StringName) -> String:
	var record = character_roster.get_character(character_id)
	if record != null:
		return String(record.display_name)
	var definition = character_database.get_character_definition(character_id)
	if definition == null:
		return String(character_id)
	return String(definition.display_name)


func create_expedition_injury_snapshots() -> Array:
	var snapshots: Array = []
	for unit: Dictionary in get_battle_party_states():
		var character_id := StringName(unit.get("character_id", unit.get("unit_id", &"")))
		if character_id == &"":
			continue
		snapshots.append({
			"character_id": character_id,
			"return_hp": int(unit.get("current_hp", 0)),
			"return_max_hp": int(unit.get("max_hp", 1)),
		})
	return snapshots


func get_team_injury_summary() -> Array:
	var results: Array = []
	for character_id: StringName in get_character_ids():
		var runtime_state = character_runtime_states.get(character_id, null)
		results.append({
			"character_id": character_id,
			"display_name": get_character_display_name(character_id),
			"injury_state": runtime_state.injury_state if runtime_state != null else &"healthy",
			"is_being_treated": is_character_being_treated(character_id),
		})
	return results


func get_character_definition(character_id: StringName) -> Dictionary:
	var definition = character_database.get_character_definition(character_id)
	var data: Dictionary = definition.to_dictionary() if definition != null else {}
	var record = character_roster.get_character(character_id)
	if record == null:
		return data
	var snapshot: Dictionary = record.to_dictionary()
	for key: String in ["character_id", "character_type", "character_type_name", "display_name", "portrait_path", "quality", "quality_name", "level", "experience", "experience_to_next_level", "traits", "is_locked", "created_sequence", "metadata"]:
		data[key] = snapshot.get(key)
	if record.is_combat_character():
		data["profession_id"] = record.combat_data.profession_id
		data["base_combat_stats"] = record.combat_data.base_combat_stats.to_dictionary()
		data["skill_ids"] = record.combat_data.skill_ids.duplicate()
		data["battle_visual_id"] = record.combat_data.battle_visual_id
	return data


func get_character_runtime_state(character_id: StringName) -> Dictionary:
	var runtime_state = character_runtime_states.get(character_id, null)
	if runtime_state == null:
		return {}
	return runtime_state.to_dictionary()


func get_character_trait_definition(trait_id: StringName) -> Dictionary:
	var trait_definition = character_database.get_trait_definition(trait_id)
	if trait_definition == null:
		return {}
	return trait_definition.to_dictionary()


func get_profession_display_name(profession_id: StringName) -> String:
	return character_database.get_profession_display_name(profession_id)


func get_final_combat_stat_details(character_id: StringName) -> Dictionary:
	var record = character_roster.get_character(character_id)
	if record == null or not record.is_combat_character():
		return {}
	return record.combat_data.calculate_final_stat_details(
		record.level,
		get_character_equipment_bonuses(character_id),
		{},
		{
			"attack": party_attack_bonus + get_expedition_meal_attack_bonus(),
			"max_hp": party_max_hp_bonus,
		},
		{"max_hp": get_expedition_meal_max_hp_bonus()}
	)


func get_final_combat_stats(character_id: StringName) -> Dictionary:
	var details := get_final_combat_stat_details(character_id)
	var stats: Dictionary = {}
	for stat_id: String in details.keys():
		stats[stat_id] = details[stat_id].get("final", 0)
	return stats


func get_character_detail(character_id: StringName) -> Dictionary:
	var detail: Dictionary = character_database.get_character_detail(
		character_id,
		character_runtime_states.get(character_id, null),
		get_final_combat_stat_details(character_id)
	)
	if detail.is_empty():
		return {"roster_record": get_roster_character(character_id)}
	detail["definition"] = get_character_definition(character_id)
	detail["roster_record"] = get_roster_character(character_id)
	return detail


func get_all_character_details() -> Array:
	var details: Array = []
	for character_id: StringName in get_character_ids():
		details.append(get_character_detail(character_id))
	return details


func get_character_equipment_bonuses(_character_id: StringName) -> Dictionary:
	return equipment_system.get_character_equipment_bonuses(self, _character_id)


func get_equipment_inventory() -> Array:
	return equipment_system.get_all_equipment_instance_data(self)


func get_equipment_instance_data(instance_id: StringName) -> Dictionary:
	return equipment_system.get_equipment_instance_data(self, instance_id)


func get_equipped_equipment_instance_id(character_id: StringName, slot_type: StringName) -> StringName:
	return equipment_system.get_equipped_instance_id(self, character_id, slot_type)


func get_character_equipped_item_data(character_id: StringName, slot_type: StringName) -> Dictionary:
	var instance_id: StringName = get_equipped_equipment_instance_id(character_id, slot_type)
	if instance_id == &"":
		return {}
	return get_equipment_instance_data(instance_id)


func can_equip_item(character_id: StringName, instance_id: StringName) -> bool:
	return equipment_system.can_equip(self, character_id, instance_id)


func get_equip_item_error(character_id: StringName, instance_id: StringName) -> String:
	return equipment_system.get_equip_error(self, character_id, instance_id)


func equip_item(character_id: StringName, instance_id: StringName) -> bool:
	var result: Dictionary = equipment_system.equip(self, character_id, instance_id)
	if not bool(result.get("success", false)):
		return false
	clamp_character_runtime_hp_to_final_max(character_id)
	rebuild_adventurers_from_character_data(false)
	character_equipment_changed.emit(character_id)
	character_runtime_state_changed.emit(character_id)
	character_final_stats_changed.emit(character_id)
	equipment_inventory_changed.emit()
	state_changed.emit()
	return true


func unequip_item(character_id: StringName, slot_type: StringName) -> bool:
	var result: Dictionary = equipment_system.unequip(self, character_id, slot_type)
	if not bool(result.get("success", false)):
		return false
	clamp_character_runtime_hp_to_final_max(character_id)
	rebuild_adventurers_from_character_data(false)
	character_equipment_changed.emit(character_id)
	character_runtime_state_changed.emit(character_id)
	character_final_stats_changed.emit(character_id)
	equipment_inventory_changed.emit()
	state_changed.emit()
	return true


func get_equipment_comparison(character_id: StringName, instance_id: StringName) -> Dictionary:
	return equipment_system.get_equipment_comparison(self, character_id, instance_id)


func get_character_equipment_affixes(character_id: StringName) -> Array:
	return equipment_system.get_character_affixes(self, character_id)


func get_skill_damage_multiplier_bonus(character_id: StringName, skill_id: StringName) -> float:
	return equipment_system.get_skill_damage_multiplier_bonus(self, character_id, skill_id)


func get_skill_heal_bonus(character_id: StringName, skill_id: StringName) -> int:
	return equipment_system.get_skill_heal_bonus(self, character_id, skill_id)


func clamp_character_runtime_hp_to_final_max(character_id: StringName) -> void:
	var runtime_state = character_runtime_states.get(character_id, null)
	if runtime_state == null:
		return
	var final_stats: Dictionary = get_final_combat_stats(character_id)
	runtime_state.current_hp = clampi(int(runtime_state.current_hp), 0, int(final_stats.get("max_hp", runtime_state.current_hp)))
	character_runtime_states[character_id] = runtime_state


func rebuild_adventurers_from_character_data(emit_signals: bool = true) -> void:
	var rebuilt: Array = []
	for character_id: StringName in get_character_ids():
		var unit: Dictionary = character_roster.create_party_unit_state(
			character_id,
			character_database,
			get_final_combat_stat_details(character_id)
		)
		if not unit.is_empty():
			rebuilt.append(unit)
	adventurers = rebuilt
	if emit_signals:
		emit_all_character_final_stats_changed()
		state_changed.emit()


func update_character_runtime_states_from_party(party_states: Array) -> void:
	for party_unit: Dictionary in party_states:
		var character_id: StringName = StringName(party_unit.get("character_id", party_unit.get("unit_id", &"")))
		if not character_runtime_states.has(character_id):
			continue
		var runtime_state = character_runtime_states[character_id]
		runtime_state.current_hp = clampi(
			int(party_unit.get("current_hp", runtime_state.current_hp)),
			0,
			int(party_unit.get("max_hp", runtime_state.current_hp))
		)
		character_runtime_states[character_id] = runtime_state
		character_runtime_state_changed.emit(character_id)
	rebuild_adventurers_from_character_data(false)


func restore_character_runtime_states_full() -> void:
	for character_id: StringName in get_character_ids():
		restore_character_runtime_state_full(character_id)


func restore_character_runtime_state_full(character_id: StringName) -> void:
	var runtime_state = character_runtime_states.get(character_id, null)
	if runtime_state == null:
		return
	var final_stats: Dictionary = get_final_combat_stats(character_id)
	runtime_state.current_hp = int(final_stats.get("max_hp", runtime_state.current_hp))
	character_runtime_states[character_id] = runtime_state
	character_runtime_state_changed.emit(character_id)


func apply_party_attack_bonus(amount: int) -> void:
	party_attack_bonus += amount
	rebuild_adventurers_from_character_data(false)
	emit_all_character_final_stats_changed()


func apply_party_max_hp_bonus(amount: int) -> void:
	party_max_hp_bonus += amount
	for character_id: StringName in get_character_ids():
		var runtime_state = character_runtime_states.get(character_id, null)
		if runtime_state == null:
			continue
		if int(runtime_state.current_hp) > 0:
			runtime_state.current_hp += amount
			character_runtime_states[character_id] = runtime_state
			character_runtime_state_changed.emit(character_id)
	rebuild_adventurers_from_character_data(false)
	emit_all_character_final_stats_changed()


func get_active_expedition_meal() -> StringName:
	return StringName(expedition_state.get("active_meal_id", &""))


func get_active_expedition_meal_data() -> Dictionary:
	return get_food_meal_data(get_active_expedition_meal())


func get_expedition_meal_attack_bonus() -> int:
	var meal: Dictionary = get_active_expedition_meal_data()
	return int(meal.get("attack_bonus", 0))


func get_expedition_meal_max_hp_bonus() -> int:
	var meal: Dictionary = get_active_expedition_meal_data()
	return int(meal.get("max_hp_bonus", 0))


func apply_expedition_meal_bonus(meal_id: StringName) -> void:
	var meal: Dictionary = get_food_meal_data(meal_id)
	if meal.is_empty():
		return
	var max_hp_bonus := int(meal.get("max_hp_bonus", 0))
	if max_hp_bonus > 0:
		for character_id: StringName in get_character_ids():
			var runtime_state = character_runtime_states.get(character_id, null)
			if runtime_state == null:
				continue
			if int(runtime_state.current_hp) > 0:
				runtime_state.current_hp += max_hp_bonus
				character_runtime_states[character_id] = runtime_state
				character_runtime_state_changed.emit(character_id)
	rebuild_adventurers_from_character_data(false)
	emit_all_character_final_stats_changed()


func clear_expedition_meal_bonus() -> void:
	var previous_meal_id := get_active_expedition_meal()
	if previous_meal_id == &"":
		return
	var state: Dictionary = expedition_state
	state["active_meal_id"] = &""
	expedition_state = state
	for character_id: StringName in get_character_ids():
		clamp_character_runtime_hp_to_final_max(character_id)
	rebuild_adventurers_from_character_data(false)
	emit_all_character_final_stats_changed()
	expedition_meal_changed.emit(&"")


func get_current_node_encounter_id() -> StringName:
	return expedition_system.get_node_encounter_id(expedition_state["current_node_id"])


func is_current_battle_node_cleared() -> bool:
	return expedition_system.is_battle_node_cleared(self, expedition_state["current_node_id"])


func get_resource_summary() -> String:
	return "第 %d 天 | 粮食 %d | 远征口粮 %d | 药品 %d | 矿石 %d | 草药 %d | Boss核心 %d" % [
		current_day,
		get_resource_amount("food"),
		get_item_count(&"expedition_ration"),
		get_resource_amount("medicine"),
		get_resource_amount("ore"),
		get_resource_amount("herb"),
		get_resource_amount("boss_core"),
	]

func get_adventurer_summary() -> String:
	var lines := PackedStringArray()
	for adventurer: Dictionary in adventurers:
		var character_id := StringName(adventurer.get("character_id", adventurer.get("unit_id", &"")))
		var state_text := "健康"
		if StringName(adventurer.get("injury_state", &"healthy")) == &"injured":
			state_text = "受伤"
		if is_character_being_treated(character_id):
			state_text = "治疗中"
		lines.append("%s：生命 %d/%d | 攻击 %d | 防御 %d | %s" % [
			String(adventurer.get("display_name", adventurer.get("name", ""))),
			int(adventurer["current_hp"]),
			int(adventurer["max_hp"]),
			int(adventurer["attack"]),
			int(adventurer["defense"]),
			state_text,
		])
	return "\n".join(lines)

func get_growth_summary() -> Dictionary:
	var farm_summary := get_farm_summary()
	return {
		"farm_level": int(buildings.get("farm", {}).get("level", 1)),
		"farm_daily_food": 0,
		"farm_active_plots": int(farm_summary.get("active_plot_count", 0)),
		"farm_unlocked_plots": int(farm_summary.get("unlocked_plot_count", 0)),
		"farm_next_harvest_days": int(farm_summary.get("next_harvest_days", 0)),
		"clinic_level": int(buildings.get("clinic", {}).get("level", 1)),
		"clinic_progress_required": int(buildings.get("clinic", {}).get("medicine_progress_required", 2)),
		"party_attack_bonus": party_attack_bonus,
		"party_max_hp_bonus": party_max_hp_bonus,
		"active_project": get_active_project_summary(),
		"active_forge": get_active_forge_summary(),
		"completed_projects": project_state.get("completed_project_ids", []).duplicate(true),
	}


func get_mvp_summary() -> Dictionary:
	return {
		"current_day": current_day,
		"core_material": core_material,
		"boss_defeated": boss_defeated,
		"statistics": statistics.duplicate(true),
		"growth": get_growth_summary(),
	}


func create_save_data(base_data: Dictionary = {}) -> Dictionary:
	return save_system.create_save_data(self, base_data)


func load_save_data(data: Dictionary) -> bool:
	return save_system.load_save_data(self, data)


func save_game(path: String = SaveSystemScript.DEFAULT_SAVE_PATH, base_data: Dictionary = {}) -> bool:
	return save_system.save_to_file(self, path, base_data)


func load_game(path: String = SaveSystemScript.DEFAULT_SAVE_PATH) -> bool:
	return save_system.load_from_file(self, path)


func get_save_error() -> String:
	return save_system.last_error


func print_character_roster_debug() -> void:
	print(get_character_roster_debug_summary())


func emit_full_state_refresh_after_load() -> void:
	emit_all_building_state_changed()
	emit_day_changed()
	emit_resources_changed()
	farm_state_changed.emit()
	current_node_changed.emit(expedition_state.get("current_node_id", &"village_exit"))
	supplies_changed.emit()
	expedition_state_changed.emit()
	battle_state_changed.emit()
	project_progress_changed.emit(project_state.duplicate(true))
	village_upgrades_changed.emit()
	party_upgrades_changed.emit()
	boss_defeated_changed.emit()
	emit_all_character_data_changed()
	emit_all_character_runtime_state_changed()
	emit_all_character_final_stats_changed()
	character_roster_changed.emit()
	equipment_inventory_changed.emit()
	forge_state_changed.emit()
	food_workshop_state_changed.emit()
	hospital_state_changed.emit()
	emit_all_stackable_item_count_changed()
	life_recruitment_candidates_changed.emit()
	_emit_life_character_capacity_changed()
	state_changed.emit()


func emit_resources_changed() -> void:
	resources_changed.emit()


func emit_day_changed() -> void:
	day_changed.emit(current_day)


func emit_all_building_state_changed() -> void:
	for building_id: StringName in get_building_ids():
		building_state_changed.emit(building_id)


func emit_farm_harvest_signals(report: Dictionary) -> void:
	for harvest: Dictionary in report.get("farm_harvests", []):
		crop_harvested.emit(
			int(harvest.get("plot_id", 0)),
			StringName(harvest.get("crop_id", &"")),
			StringName(harvest.get("output_resource_id", &"")),
			int(harvest.get("output_amount", 0))
		)


func emit_after_day_advanced() -> void:
	emit_resources_changed()
	farm_state_changed.emit()
	emit_all_building_state_changed()
	emit_day_changed()
	day_advanced.emit(current_day)
	daily_report_generated.emit(last_daily_report.duplicate(true))
	var project_report: Dictionary = last_daily_report.get("project_report", {})
	if bool(project_report.get("had_active_project", false)):
		project_progress_changed.emit(project_report.duplicate(true))
	if bool(project_report.get("project_completed", false)):
		project_completed.emit(project_report.duplicate(true))
		village_upgrades_changed.emit()
		party_upgrades_changed.emit()
		emit_all_character_final_stats_changed()
	var forge_report: Dictionary = last_daily_report.get("forge_report", {})
	if bool(forge_report.get("had_active_forge", false)):
		forge_progress_changed.emit(forge_report.duplicate(true))
		forge_state_changed.emit()
		building_project_changed.emit(&"weapon_forge")
		building_state_changed.emit(&"weapon_forge")
	if bool(forge_report.get("forge_completed", false)):
		forge_project_completed.emit(forge_report.duplicate(true))
		equipment_inventory_changed.emit()
	var food_workshop_report: Dictionary = last_daily_report.get("food_workshop_report", {})
	if bool(food_workshop_report.get("had_active_food_workshop", false)):
		food_workshop_state_changed.emit()
		building_project_changed.emit(&"food_workshop")
		building_state_changed.emit(&"food_workshop")
	if bool(food_workshop_report.get("food_workshop_completed", false)):
		food_recipe_completed.emit(
			StringName(food_workshop_report.get("recipe_id", &"")),
			StringName(food_workshop_report.get("output_item_id", &"")),
			int(food_workshop_report.get("output_amount", 0))
		)
		stackable_item_count_changed.emit(
			StringName(food_workshop_report.get("output_item_id", &"")),
			get_item_count(StringName(food_workshop_report.get("output_item_id", &"")))
		)
	var hospital_report: Dictionary = last_daily_report.get("hospital_report", {})
	if bool(hospital_report.get("had_active_hospital", false)):
		hospital_state_changed.emit()
		building_project_changed.emit(&"hospital")
		building_state_changed.emit(&"hospital")
	if bool(hospital_report.get("hospital_project_completed", false)):
		if int(hospital_report.get("medicine_produced", 0)) > 0:
			medicine_production_completed.emit(int(hospital_report.get("medicine_produced", 0)))
		if bool(hospital_report.get("treatment_completed", false)):
			var treated_id := StringName(hospital_report.get("treated_character_id", &""))
			character_treatment_completed.emit(treated_id)
			character_injury_changed.emit(treated_id, &"healthy")
			character_runtime_state_changed.emit(treated_id)
			character_final_stats_changed.emit(treated_id)
	if is_expedition_active():
		supplies_changed.emit()
		expedition_state_changed.emit()
		current_node_changed.emit(expedition_state["current_node_id"])
	state_changed.emit()


func emit_all_character_data_changed() -> void:
	for character_id: StringName in get_roster_character_ids():
		character_data_changed.emit(character_id)


func emit_all_character_runtime_state_changed() -> void:
	for character_id: StringName in get_character_ids():
		character_runtime_state_changed.emit(character_id)


func emit_all_character_final_stats_changed() -> void:
	for character_id: StringName in get_character_ids():
		character_final_stats_changed.emit(character_id)


func emit_injury_result_signals(injury_results: Array) -> void:
	for result: Dictionary in injury_results:
		var character_id := StringName(result.get("character_id", &""))
		if character_id == &"":
			continue
		character_injury_changed.emit(character_id, StringName(result.get("new_injury_state", &"healthy")))
		character_runtime_state_changed.emit(character_id)
		character_final_stats_changed.emit(character_id)


func emit_all_stackable_item_count_changed() -> void:
	for raw_item_id in stackable_item_inventory.keys():
		var item_id := StringName(raw_item_id)
		stackable_item_count_changed.emit(item_id, get_item_count(item_id))


func _life_character_matches_filter(
	snapshot: Dictionary,
	filter_id: StringName
) -> bool:
	if filter_id == &"all":
		return true
	var life_data: Dictionary = snapshot.get("life_data", {})
	var work_state := int(
		life_data.get("work_state", CharacterEnumsScript.WorkState.IDLE)
	)
	if filter_id == &"idle":
		return work_state == CharacterEnumsScript.WorkState.IDLE \
			and StringName(life_data.get("assigned_building_id", &"")) == &""
	if filter_id == &"working":
		return work_state == CharacterEnumsScript.WorkState.WORKING \
			and StringName(life_data.get("assigned_building_id", &"")) != &""
	if filter_id in LifeStatsScript.CORE_STAT_IDS:
		return _get_life_character_primary_stat_id(snapshot) == filter_id
	return true


func _get_life_character_sort_value(
	snapshot: Dictionary,
	sort_id: StringName
):
	if sort_id == &"level":
		return int(snapshot.get("level", 1))
	if sort_id == &"quality":
		return int(snapshot.get("quality", CharacterEnumsScript.Quality.COMMON))
	if sort_id in LifeStatsScript.CORE_STAT_IDS:
		var life_data: Dictionary = snapshot.get("life_data", {})
		var stats: Dictionary = life_data.get("life_stats", {})
		return int(stats.get(String(sort_id), 0))
	return int(snapshot.get("created_sequence", 0))


func _get_life_character_primary_stat_id(snapshot: Dictionary) -> StringName:
	var life_data: Dictionary = snapshot.get("life_data", {})
	var stats: Dictionary = life_data.get("life_stats", {})
	var selected_stat_id := LifeStatsScript.CORE_STAT_IDS[0]
	var selected_value := -1
	for stat_id: StringName in LifeStatsScript.CORE_STAT_IDS:
		var value := int(stats.get(String(stat_id), 0))
		if value > selected_value:
			selected_stat_id = stat_id
			selected_value = value
	return selected_stat_id


func _emit_life_character_capacity_changed() -> void:
	var details := get_life_character_capacity_details()
	life_character_capacity_changed.emit(
		int(details.get("current_count", 0)),
		int(details.get("capacity", 0))
	)

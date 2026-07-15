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

const INITIAL_DAY := 1
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


func _ready() -> void:
	start_new_game()


func start_new_game() -> void:
	current_day = INITIAL_DAY
	resources = INITIAL_RESOURCES.duplicate(true)
	buildings = INITIAL_BUILDINGS.duplicate(true)
	building_system.ensure_initial_runtime_state(self)
	farm_plot_states = farm_system.create_initial_plot_states(int(buildings.get("farm", {}).get("level", 1)))
	project_state = project_system.create_initial_state()
	character_runtime_states = character_database.create_initial_runtime_states()
	equipment_inventory = equipment_system.create_initial_inventory_state()
	forge_state = forge_system.create_initial_state()
	food_production_state = food_workshop_system.create_initial_state()
	hospital_project_state = hospital_system.create_initial_state()
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
	if building_id == &"farm":
		farm_system.apply_farm_level(self, level)
		farm_state_changed.emit()
	building_level_changed.emit(building_id, level)
	building_state_changed.emit(building_id)
	building_visual_refresh_requested.emit(building_id)
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


func move_to_next_expedition_node() -> bool:
	var action_report: Dictionary = expedition_system.move_to_next_node(self)
	if action_report.is_empty():
		return false

	emit_after_day_advanced()
	expedition_action_completed.emit(action_report.duplicate(true))
	if bool(action_report.get("starts_battle", false)):
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


func process_battle_result(result: Dictionary) -> void:
	last_battle_result = result.duplicate(true)
	if String(result["outcome"]) == "victory":
		statistics["total_battles_won"] = int(statistics.get("total_battles_won", 0)) + 1
		expedition_system.apply_battle_victory(self, result)
		if bool(result.get("is_boss", false)):
			boss_defeated = true
			boss_defeated_changed.emit()
		supplies_changed.emit()
		expedition_state_changed.emit()
	else:
		var report: Dictionary = expedition_system.apply_battle_failure(self, result)
		statistics["total_failed_expeditions"] = int(statistics.get("total_failed_expeditions", 0)) + 1
		var injury_results: Array = hospital_system.process_expedition_injuries(self, true)
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

	battle_state_changed.emit()
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
	return character_database.get_party_order()


func get_character_display_name(character_id: StringName) -> String:
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
	if definition == null:
		return {}
	return definition.to_dictionary()


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
	var runtime_state = character_runtime_states.get(character_id, null)
	var injury_state: StringName = runtime_state.injury_state if runtime_state != null else &"healthy"
	return character_database.get_final_combat_stat_details(
		character_id,
		party_attack_bonus + get_expedition_meal_attack_bonus(),
		party_max_hp_bonus,
		get_character_equipment_bonuses(character_id),
		injury_state,
		get_expedition_meal_max_hp_bonus()
	)


func get_final_combat_stats(character_id: StringName) -> Dictionary:
	var runtime_state = character_runtime_states.get(character_id, null)
	var injury_state: StringName = runtime_state.injury_state if runtime_state != null else &"healthy"
	return character_database.get_final_combat_stats(
		character_id,
		party_attack_bonus + get_expedition_meal_attack_bonus(),
		party_max_hp_bonus,
		get_character_equipment_bonuses(character_id),
		injury_state,
		get_expedition_meal_max_hp_bonus()
	)


func get_character_detail(character_id: StringName) -> Dictionary:
	return character_database.get_character_detail(
		character_id,
		character_runtime_states.get(character_id, null),
		get_final_combat_stat_details(character_id)
	)


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
	for character_id: StringName in character_database.get_party_order():
		var unit: Dictionary = character_database.create_party_unit_state(
			character_id,
			character_runtime_states.get(character_id, null),
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
	for character_id: StringName in character_database.get_party_order():
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
	for character_id: StringName in character_database.get_party_order():
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
		for character_id: StringName in character_database.get_party_order():
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
	for character_id: StringName in character_database.get_party_order():
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
	for character_id: StringName in character_database.get_party_order():
		character_data_changed.emit(character_id)


func emit_all_character_runtime_state_changed() -> void:
	for character_id: StringName in character_database.get_party_order():
		character_runtime_state_changed.emit(character_id)


func emit_all_character_final_stats_changed() -> void:
	for character_id: StringName in character_database.get_party_order():
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

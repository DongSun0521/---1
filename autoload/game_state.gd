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

const VillageSystemScript := preload("res://systems/village_system.gd")
const ExpeditionSystemScript := preload("res://systems/expedition_system.gd")
const BattleSystemScript := preload("res://systems/battle_system.gd")
const ProjectSystemScript := preload("res://systems/project_system.gd")
const BuildingSystemScript := preload("res://systems/building_system.gd")
const CharacterDatabaseScript := preload("res://scripts/data/character_database.gd")
const EquipmentSystemScript := preload("res://systems/equipment_system.gd")
const ForgeSystemScript := preload("res://systems/forge_system.gd")

const INITIAL_DAY := 1
const INITIAL_RESOURCES := {
	"food": 20,
	"medicine": 3,
	"ore": 0,
	"herb": 0,
	"boss_core": 0,
}
const RESOURCE_LABELS := {
	"food": "粮食",
	"medicine": "药品",
	"ore": "矿石",
	"herb": "草药",
	"boss_core": "Boss 核心",
}
const INITIAL_ADVENTURERS := [
	{
		"name": "战士",
		"max_hp": 30,
		"current_hp": 30,
		"attack": 5,
		"defense": 3,
	},
	{
		"name": "猎人",
		"max_hp": 22,
		"current_hp": 22,
		"attack": 7,
		"defense": 1,
	},
	{
		"name": "法师",
		"max_hp": 18,
		"current_hp": 18,
		"attack": 8,
		"defense": 1,
	},
	{
		"name": "医师",
		"max_hp": 20,
		"current_hp": 20,
		"attack": 3,
		"defense": 2,
	},
]
const INITIAL_BUILDINGS := {
	"farm": {
		"display_name": "农田",
		"level": 1,
		"status": "正常生产",
		"daily_food_production": 4,
	},
	"clinic": {
		"display_name": "医院",
		"level": 1,
		"status": "制作药品",
		"medicine_progress": 0,
		"medicine_progress_required": 2,
		"medicine_output": 1,
	},
	"workshop": {
		"display_name": "工坊",
		"level": 1,
		"status": "等待项目",
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
var character_database: RefCounted = CharacterDatabaseScript.new()
var equipment_system: RefCounted = EquipmentSystemScript.new()
var forge_system: RefCounted = ForgeSystemScript.new()
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
var last_forge_report: Dictionary = {}
var party_attack_bonus: int = 0
var party_max_hp_bonus: int = 0
var boss_defeated: bool = false
var core_material: int = 0
var mvp_has_completed: bool = false
var statistics: Dictionary = {}


func _ready() -> void:
	start_new_game()


func start_new_game() -> void:
	current_day = INITIAL_DAY
	resources = INITIAL_RESOURCES.duplicate(true)
	buildings = INITIAL_BUILDINGS.duplicate(true)
	building_system.ensure_initial_runtime_state(self)
	project_state = project_system.create_initial_state()
	character_runtime_states = character_database.create_initial_runtime_states()
	equipment_inventory = equipment_system.create_initial_inventory_state()
	forge_state = forge_system.create_initial_state()
	last_forge_report = {}
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
	daily_report_generated.emit(last_daily_report.duplicate(true))
	state_changed.emit()


func advance_day(reason: String = "manual_test", emit_signals: bool = true) -> Dictionary:
	var settled_day: int = current_day
	last_daily_report = village_system.process_daily_village(self)
	var expedition_daily_report: Dictionary = expedition_system.process_daily_consumption(self, last_daily_report)
	var project_daily_report: Dictionary = project_system.process_daily_project(self)
	var forge_daily_report: Dictionary = forge_system.process_daily_forge(self)
	current_day = settled_day + 1
	last_daily_report["reason"] = reason
	last_daily_report["settled_day"] = settled_day
	last_daily_report["new_day"] = current_day
	last_daily_report["expedition_food_consumed"] = int(expedition_daily_report["expedition_food_consumed"])
	last_daily_report["expedition_day_count"] = int(expedition_daily_report["expedition_day_count"])
	last_daily_report["carried_food_after"] = int(expedition_daily_report.get("carried_food_after", 0))
	last_daily_report["project_report"] = project_daily_report.duplicate(true)
	last_daily_report["forge_report"] = forge_daily_report.duplicate(true)
	last_forge_report = forge_daily_report.duplicate(true)

	if emit_signals:
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
	building_level_changed.emit(building_id, level)
	building_state_changed.emit(building_id)
	building_visual_refresh_requested.emit(building_id)
	state_changed.emit()
	return true


func select_building(building_id: StringName) -> void:
	building_selected.emit(building_id)


func get_last_daily_report() -> Dictionary:
	return last_daily_report.duplicate(true)


func is_expedition_active() -> bool:
	if expedition_state.is_empty():
		return false
	return bool(expedition_state["is_active"])


func can_start_expedition(carried_food: int, carried_medicine: int) -> bool:
	return expedition_system.can_start_expedition(self, carried_food, carried_medicine)


func get_expedition_start_error(carried_food: int, carried_medicine: int) -> String:
	return expedition_system.get_start_error(self, carried_food, carried_medicine)


func start_expedition(carried_food: int, carried_medicine: int) -> bool:
	if not expedition_system.start_expedition(self, carried_food, carried_medicine):
		return false

	statistics["total_expeditions_started"] = int(statistics.get("total_expeditions_started", 0)) + 1
	emit_resources_changed()
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
	var report: Dictionary = expedition_system.return_to_village(self)
	if report.is_empty():
		return false

	var should_complete_mvp: bool = int(report.get("core_gained", 0)) > 0 and not mvp_has_completed
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
	return character_database.get_final_combat_stat_details(
		character_id,
		party_attack_bonus,
		party_max_hp_bonus,
		get_character_equipment_bonuses(character_id)
	)


func get_final_combat_stats(character_id: StringName) -> Dictionary:
	return character_database.get_final_combat_stats(
		character_id,
		party_attack_bonus,
		party_max_hp_bonus,
		get_character_equipment_bonuses(character_id)
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
		var runtime_state = character_runtime_states.get(character_id, null)
		if runtime_state == null:
			continue
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


func get_current_node_encounter_id() -> StringName:
	return expedition_system.get_node_encounter_id(expedition_state["current_node_id"])


func is_current_battle_node_cleared() -> bool:
	return expedition_system.is_battle_node_cleared(self, expedition_state["current_node_id"])


func get_resource_summary() -> String:
	return "第 %d 天 | 粮食 %d | 药品 %d | 矿石 %d | 草药 %d | 核心 %d" % [
		current_day,
		get_resource_amount("food"),
		get_resource_amount("medicine"),
		get_resource_amount("ore"),
		get_resource_amount("herb"),
		get_resource_amount("boss_core"),
	]


func get_adventurer_summary() -> String:
	var lines := PackedStringArray()
	for adventurer: Dictionary in adventurers:
		lines.append("%s：生命 %d/%d | 攻击 %d | 防御 %d" % [
			String(adventurer.get("display_name", adventurer.get("name", ""))),
			int(adventurer["current_hp"]),
			int(adventurer["max_hp"]),
			int(adventurer["attack"]),
			int(adventurer["defense"]),
		])
	return "\n".join(lines)


func get_growth_summary() -> Dictionary:
	return {
		"farm_level": int(buildings.get("farm", {}).get("level", 1)),
		"farm_daily_food": int(buildings.get("farm", {}).get("daily_food_production", 4)),
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


func emit_after_day_advanced() -> void:
	emit_resources_changed()
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

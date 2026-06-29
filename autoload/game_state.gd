extends Node

signal state_changed
signal resources_changed
signal day_changed(current_day: int)
signal day_advanced(new_day: int)
signal building_state_changed(building_id: StringName)
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

const VillageSystemScript := preload("res://scripts/systems/village_system.gd")
const ExpeditionSystemScript := preload("res://scripts/systems/expedition_system.gd")
const BattleSystemScript := preload("res://scripts/systems/battle_system.gd")

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
var expedition_state: Dictionary = {}
var last_expedition_action_report: Dictionary = {}
var last_expedition_report: Dictionary = {}
var battle_state: Dictionary = {}
var last_battle_result: Dictionary = {}


func _ready() -> void:
	start_new_game()


func start_new_game() -> void:
	current_day = INITIAL_DAY
	resources = INITIAL_RESOURCES.duplicate(true)
	adventurers = battle_system.create_initial_party_states()
	buildings = INITIAL_BUILDINGS.duplicate(true)
	last_daily_report = {}
	expedition_state = expedition_system.create_initial_state()
	last_expedition_action_report = {}
	last_expedition_report = {}
	battle_state = battle_system.create_initial_state()
	last_battle_result = {}
	emit_all_building_state_changed()
	emit_day_changed()
	emit_resources_changed()
	current_node_changed.emit(expedition_state["current_node_id"])
	supplies_changed.emit()
	expedition_state_changed.emit()
	battle_state_changed.emit()
	daily_report_generated.emit(last_daily_report.duplicate(true))
	state_changed.emit()


func advance_day(reason: String = "manual_test", emit_signals: bool = true) -> Dictionary:
	var settled_day: int = current_day
	last_daily_report = village_system.process_daily_village(self)
	var expedition_daily_report: Dictionary = expedition_system.process_daily_consumption(self, last_daily_report)
	current_day = settled_day + 1
	last_daily_report["reason"] = reason
	last_daily_report["settled_day"] = settled_day
	last_daily_report["new_day"] = current_day
	last_daily_report["expedition_food_consumed"] = int(expedition_daily_report["expedition_food_consumed"])
	last_daily_report["expedition_day_count"] = int(expedition_daily_report["expedition_day_count"])
	last_daily_report["carried_food_after"] = int(expedition_daily_report.get("carried_food_after", 0))

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


func get_building_state(building_id: StringName) -> Dictionary:
	var key := String(building_id)
	if not buildings.has(key):
		return {}
	return buildings[key].duplicate(true)


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

	adventurers = battle_system.restore_party_full(adventurers)
	emit_resources_changed()
	supplies_changed.emit()
	expedition_state_changed.emit()
	battle_state_changed.emit()
	current_node_changed.emit(expedition_state["current_node_id"])
	expedition_ended.emit(report.duplicate(true))
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

	battle_started.emit(encounter_id)
	battle_state_changed.emit()
	active_unit_changed.emit(battle_system.get_active_unit_id(battle_state))
	state_changed.emit()
	return true


func execute_battle_action(action_id: StringName, target_id: StringName = &"") -> bool:
	var action_result: Dictionary = battle_system.execute_player_action(self, action_id, target_id)
	if not bool(action_result.get("success", false)):
		battle_state_changed.emit()
		state_changed.emit()
		return false

	if bool(action_result.get("finished", false)):
		var result: Dictionary = action_result["result"]
		process_battle_result(result)
	else:
		battle_state_changed.emit()
		active_unit_changed.emit(battle_system.get_active_unit_id(battle_state))
		state_changed.emit()
	return true


func process_battle_result(result: Dictionary) -> void:
	last_battle_result = result.duplicate(true)
	if String(result["outcome"]) == "victory":
		expedition_system.apply_battle_victory(self, result)
		supplies_changed.emit()
		expedition_state_changed.emit()
	else:
		var report: Dictionary = expedition_system.apply_battle_failure(self, result)
		adventurers = battle_system.restore_party_full(adventurers)
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


func get_current_node_encounter_id() -> StringName:
	return expedition_system.get_node_encounter_id(expedition_state["current_node_id"])


func is_current_battle_node_cleared() -> bool:
	return expedition_system.is_battle_node_cleared(self, expedition_state["current_node_id"])


func get_resource_summary() -> String:
	return "第 %d 天 | 粮食 %d | 药品 %d | 矿石 %d | 草药 %d" % [
		current_day,
		get_resource_amount("food"),
		get_resource_amount("medicine"),
		get_resource_amount("ore"),
		get_resource_amount("herb"),
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


func emit_resources_changed() -> void:
	resources_changed.emit()


func emit_day_changed() -> void:
	day_changed.emit(current_day)


func emit_all_building_state_changed() -> void:
	for building_id: String in buildings.keys():
		building_state_changed.emit(StringName(building_id))


func emit_after_day_advanced() -> void:
	emit_resources_changed()
	emit_all_building_state_changed()
	emit_day_changed()
	day_advanced.emit(current_day)
	daily_report_generated.emit(last_daily_report.duplicate(true))
	if is_expedition_active():
		supplies_changed.emit()
		expedition_state_changed.emit()
		current_node_changed.emit(expedition_state["current_node_id"])
	state_changed.emit()

class_name SaveSystem
extends RefCounted

const CURRENT_SAVE_VERSION := 2
const DEFAULT_SAVE_PATH := "user://adventure_village_save.json"

const EquipmentInstanceScript := preload("res://scripts/data/equipment_instance.gd")
const FarmPlotStateScript := preload("res://scripts/data/farm_plot_state.gd")
const FoodProductionStateScript := preload("res://scripts/data/food_production_state.gd")
const ForgeCraftStateScript := preload("res://scripts/data/forge_craft_state.gd")
const HospitalProjectStateScript := preload("res://scripts/data/hospital_project_state.gd")

var last_error: String = ""


func create_save_data(game_state: Node, base_data: Dictionary = {}) -> Dictionary:
	# Merge into a caller-provided envelope so future migrations do not discard unknown fields.
	var data := base_data.duplicate(true)
	data["save_version"] = CURRENT_SAVE_VERSION
	data["current_day"] = game_state.current_day
	data["resources"] = game_state.resources.duplicate(true)
	data["stackable_item_inventory"] = game_state.stackable_item_inventory.duplicate(true)
	data["buildings"] = game_state.buildings.duplicate(true)
	data["project_state"] = game_state.project_state.duplicate(true)
	data["party_attack_bonus"] = game_state.party_attack_bonus
	data["party_max_hp_bonus"] = game_state.party_max_hp_bonus
	data["boss_defeated"] = game_state.boss_defeated
	data["core_material"] = game_state.core_material
	data["mvp_has_completed"] = game_state.mvp_has_completed
	data["statistics"] = game_state.statistics.duplicate(true)
	data["expedition_state"] = game_state.expedition_state.duplicate(true)
	data["battle_state"] = game_state.battle_state.duplicate(true)
	data["pending_battle_result"] = game_state.pending_battle_result.duplicate(true)
	data["last_battle_result"] = game_state.last_battle_result.duplicate(true)
	data["character_roster"] = game_state.character_roster.to_dictionary()
	data["character_runtime_states"] = _serialize_legacy_runtime_states(game_state)
	data["equipment_inventory"] = _serialize_equipment_inventory(game_state)
	data["farm_plot_states"] = _serialize_objects(game_state.farm_plot_states)
	data["food_production_state"] = game_state.food_production_state.to_dictionary() if game_state.food_production_state != null else {}
	data["forge_state"] = game_state.forge_state.to_dictionary() if game_state.forge_state != null else {}
	data["hospital_project_state"] = game_state.hospital_project_state.to_dictionary() if game_state.hospital_project_state != null else {}
	return data


func load_save_data(game_state: Node, data: Dictionary) -> bool:
	last_error = ""
	if data.is_empty():
		last_error = "存档数据为空"
		return false
	var previous_save_version: int = maxi(0, int(data.get("save_version", 0)))
	var had_roster := data.has("character_roster") and data.get("character_roster") is Dictionary
	if had_roster:
		if not game_state.character_roster.load_from_dictionary(data.get("character_roster", {})):
			game_state.character_roster.initialize_defaults(game_state.character_database)
	else:
		# Version-0 saves had no roster. Defaults are additive to the new system only.
		game_state.character_roster.initialize_defaults(game_state.character_database)
		if data.has("character_runtime_states") and data.get("character_runtime_states") is Dictionary:
			game_state.character_roster.apply_legacy_runtime_states(data.get("character_runtime_states", {}))
	# Version 2 adds deterministic growth configuration and normalized party slots.
	game_state.character_roster.ensure_stage12b_defaults(previous_save_version)
	game_state.character_runtime_states = game_state.character_roster.create_combat_runtime_adapter()

	_apply_dictionary_field(game_state, "resources", data)
	_apply_dictionary_field(game_state, "stackable_item_inventory", data)
	_apply_dictionary_field(game_state, "buildings", data)
	_apply_dictionary_field(game_state, "project_state", data)
	_apply_dictionary_field(game_state, "statistics", data)
	_apply_dictionary_field(game_state, "expedition_state", data)
	_apply_dictionary_field(game_state, "battle_state", data)
	_apply_dictionary_field(game_state, "pending_battle_result", data)
	_apply_dictionary_field(game_state, "last_battle_result", data)
	if data.has("current_day"):
		game_state.current_day = max(1, int(data.get("current_day", 1)))
	if data.has("party_attack_bonus"):
		game_state.party_attack_bonus = int(data.get("party_attack_bonus", 0))
	if data.has("party_max_hp_bonus"):
		game_state.party_max_hp_bonus = int(data.get("party_max_hp_bonus", 0))
	if data.has("boss_defeated"):
		game_state.boss_defeated = bool(data.get("boss_defeated", false))
	if data.has("core_material"):
		game_state.core_material = int(data.get("core_material", 0))
	if data.has("mvp_has_completed"):
		game_state.mvp_has_completed = bool(data.get("mvp_has_completed", false))
	if data.has("equipment_inventory"):
		game_state.equipment_inventory = _restore_equipment_inventory(data.get("equipment_inventory", {}))
	if data.has("farm_plot_states"):
		game_state.farm_plot_states = _restore_farm_plots(data.get("farm_plot_states", []))
	if data.has("food_production_state"):
		game_state.food_production_state = _restore_food_state(data.get("food_production_state", {}))
	if data.has("forge_state"):
		game_state.forge_state = _restore_forge_state(data.get("forge_state", {}))
	if data.has("hospital_project_state"):
		game_state.hospital_project_state = _restore_hospital_state(data.get("hospital_project_state", {}))

	game_state.building_system.ensure_initial_runtime_state(game_state)
	game_state.rebuild_adventurers_from_character_data(false)
	game_state.emit_full_state_refresh_after_load()
	return true


func save_to_file(game_state: Node, path: String = DEFAULT_SAVE_PATH, base_data: Dictionary = {}) -> bool:
	last_error = ""
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		last_error = "无法写入存档：%s" % path
		return false
	file.store_string(JSON.stringify(create_save_data(game_state, base_data), "\t"))
	file.close()
	return true


func load_from_file(game_state: Node, path: String = DEFAULT_SAVE_PATH) -> bool:
	last_error = ""
	if not FileAccess.file_exists(path):
		last_error = "存档不存在：%s" % path
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		last_error = "无法读取存档：%s" % path
		return false
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	file.close()
	if parse_error != OK or not json.data is Dictionary:
		last_error = "存档格式无效：%s" % json.get_error_message()
		return false
	return load_save_data(game_state, json.data)


func _serialize_legacy_runtime_states(game_state: Node) -> Dictionary:
	var result: Dictionary = {}
	for character_id: StringName in game_state.character_runtime_states.keys():
		var state = game_state.character_runtime_states[character_id]
		if state != null and state.has_method("to_dictionary"):
			result[character_id] = state.to_dictionary()
	return result


func _serialize_equipment_inventory(game_state: Node) -> Dictionary:
	var result: Dictionary = {"equipment_instances": {}}
	var instances: Dictionary = game_state.equipment_inventory.get("equipment_instances", {})
	for raw_instance_id in instances.keys():
		var instance = instances[raw_instance_id]
		if instance != null and instance.has_method("to_dictionary"):
			result["equipment_instances"][raw_instance_id] = instance.to_dictionary()
	return result


func _restore_equipment_inventory(data: Dictionary) -> Dictionary:
	var result: Dictionary = {"equipment_instances": {}}
	var serialized = data.get("equipment_instances", {})
	if serialized is Array:
		for entry in serialized:
			if entry is Dictionary:
				var instance = EquipmentInstanceScript.from_dictionary(entry)
				if instance.instance_id != &"":
					result["equipment_instances"][instance.instance_id] = instance
	elif serialized is Dictionary:
		for raw_instance_id in serialized.keys():
			var entry: Dictionary = serialized[raw_instance_id].duplicate(true)
			if not entry.has("instance_id"):
				entry["instance_id"] = raw_instance_id
			var instance = EquipmentInstanceScript.from_dictionary(entry)
			if instance.instance_id != &"":
				result["equipment_instances"][instance.instance_id] = instance
	return result


func _serialize_objects(values: Array) -> Array:
	var result: Array = []
	for value in values:
		if value != null and value.has_method("to_dictionary"):
			result.append(value.to_dictionary())
	return result


func _restore_farm_plots(values: Array) -> Array:
	var result: Array = []
	for entry in values:
		if not entry is Dictionary:
			continue
		result.append(FarmPlotStateScript.new().setup(
			int(entry.get("plot_id", result.size())),
			bool(entry.get("is_unlocked", false)),
			StringName(entry.get("crop_id", &"")),
			max(0, int(entry.get("progress_days", 0))),
			bool(entry.get("is_active", false))
		))
	return result


func _restore_food_state(data: Dictionary):
	return FoodProductionStateScript.new().setup(
		StringName(data.get("recipe_id", &"")),
		max(0, int(data.get("progress_days", 0))),
		max(0, int(data.get("required_days", 0))),
		max(0, int(data.get("started_day", 0))),
		bool(data.get("is_active", false))
	)


func _restore_forge_state(data: Dictionary):
	return ForgeCraftStateScript.new().setup(
		StringName(data.get("active_recipe_id", &"")),
		StringName(data.get("result_equipment_id", &"")),
		max(0, int(data.get("progress_days", 0))),
		max(0, int(data.get("required_days", 0))),
		max(0, int(data.get("started_day", 0))),
		bool(data.get("is_active", false)),
		bool(data.get("is_completed", false))
	)


func _restore_hospital_state(data: Dictionary):
	var state = HospitalProjectStateScript.new()
	state.project_id = StringName(data.get("project_id", &""))
	state.project_type = StringName(data.get("project_type", &""))
	state.progress_days = max(0, int(data.get("progress_days", 0)))
	state.required_days = max(0, int(data.get("required_days", 0)))
	state.target_character_id = StringName(data.get("target_character_id", &""))
	state.is_active = bool(data.get("is_active", false))
	state.result_processed = bool(data.get("result_processed", false))
	return state


func _apply_dictionary_field(game_state: Node, property_name: String, data: Dictionary) -> void:
	if not data.has(property_name) or not data[property_name] is Dictionary:
		return
	game_state.set(property_name, data[property_name].duplicate(true))

extends RefCounted

const START_NODE_ID := &"village_exit"
const EMPTY_NODE_ID := &""
const MAX_CARRY_FOOD := 10
const MAX_CARRY_MEDICINE := 5
const EXPEDITION_DAILY_FOOD_CONSUMPTION := 1

const NODE_ORDER := [
	&"village_exit",
	&"forest_edge",
	&"ore_site",
	&"herb_hill",
	&"ruins_entrance",
]
const MAP_NODES := {
	&"village_exit": {
		"display_name": "村庄出口",
		"description": "远征开始位置。",
		"next_node_id": &"forest_edge",
		"encounter_id": &"",
		"gather_resource": "",
		"gather_amount": 0,
		"gather_label": "",
	},
	&"forest_edge": {
		"display_name": "森林边缘",
		"description": "林地边缘出现了两只森林史莱姆。",
		"next_node_id": &"ore_site",
		"encounter_id": &"forest_slime_pair",
		"gather_resource": "",
		"gather_amount": 0,
		"gather_label": "",
	},
	&"ore_site": {
		"display_name": "废弃矿点",
		"description": "旧矿洞外还有可搬运的矿石。",
		"next_node_id": &"herb_hill",
		"encounter_id": &"",
		"gather_resource": "ore",
		"gather_amount": 3,
		"gather_label": "采集矿石",
	},
	&"herb_hill": {
		"display_name": "药草坡地",
		"description": "坡地上能找到可用的草药。",
		"next_node_id": &"ruins_entrance",
		"encounter_id": &"",
		"gather_resource": "herb",
		"gather_amount": 2,
		"gather_label": "采集草药",
	},
	&"ruins_entrance": {
		"display_name": "遗迹入口",
		"description": "前方区域暂未开放。\n下一阶段将加入战斗与敌人。",
		"next_node_id": &"",
		"encounter_id": &"",
		"gather_resource": "",
		"gather_amount": 0,
		"gather_label": "",
	},
}


func create_initial_state() -> Dictionary:
	return {
		"is_active": false,
		"current_node_id": START_NODE_ID,
		"furthest_node_id": START_NODE_ID,
		"expedition_day_count": 0,
		"food_departed": 0,
		"medicine_departed": 0,
		"food_consumed": 0,
		"medicine_consumed": 0,
		"carried_food": 0,
		"carried_medicine": 0,
		"cargo_ore": 0,
		"cargo_herb": 0,
		"collected_node_ids": [],
		"cleared_battle_node_ids": [],
		"battle_count": 0,
		"village_food_produced": 0,
		"village_food_consumed": 0,
		"village_medicine_produced": 0,
	}


func get_start_error(game_state, carried_food: int, carried_medicine: int) -> String:
	if bool(game_state.expedition_state["is_active"]):
		return "已有远征正在进行。"
	if carried_food < 1:
		return "至少需要携带1份粮食。"
	if carried_food > MAX_CARRY_FOOD:
		return "最多携带%d份粮食。" % MAX_CARRY_FOOD
	if carried_food > game_state.get_resource_amount("food"):
		return "村庄粮食不足。"
	if carried_medicine < 0:
		return "药品携带数量不能为负。"
	if carried_medicine > MAX_CARRY_MEDICINE:
		return "最多携带%d份药品。" % MAX_CARRY_MEDICINE
	if carried_medicine > game_state.get_resource_amount("medicine"):
		return "村庄药品不足。"
	return ""


func can_start_expedition(game_state, carried_food: int, carried_medicine: int) -> bool:
	return get_start_error(game_state, carried_food, carried_medicine).is_empty()


func start_expedition(game_state, carried_food: int, carried_medicine: int) -> bool:
	if not can_start_expedition(game_state, carried_food, carried_medicine):
		return false

	var resources: Dictionary = game_state.resources
	resources["food"] = int(resources["food"]) - carried_food
	resources["medicine"] = int(resources["medicine"]) - carried_medicine
	game_state.resources = resources

	var state := create_initial_state()
	state["is_active"] = true
	state["food_departed"] = carried_food
	state["medicine_departed"] = carried_medicine
	state["carried_food"] = carried_food
	state["carried_medicine"] = carried_medicine
	game_state.expedition_state = state
	game_state.last_expedition_action_report = {}
	game_state.last_expedition_report = {}
	return true


func process_daily_consumption(game_state, village_report: Dictionary) -> Dictionary:
	var state: Dictionary = game_state.expedition_state
	if not bool(state["is_active"]):
		return {
			"expedition_food_consumed": 0,
			"expedition_day_count": 0,
		}

	var food_consumed := 0
	if int(state["carried_food"]) > 0:
		food_consumed = EXPEDITION_DAILY_FOOD_CONSUMPTION
		state["carried_food"] = max(0, int(state["carried_food"]) - food_consumed)
		state["food_consumed"] = int(state["food_consumed"]) + food_consumed

	state["expedition_day_count"] = int(state["expedition_day_count"]) + 1
	state["village_food_produced"] = int(state["village_food_produced"]) + int(village_report["food_produced"])
	state["village_food_consumed"] = int(state["village_food_consumed"]) + int(village_report["food_consumed"])
	state["village_medicine_produced"] = int(state["village_medicine_produced"]) + int(village_report["medicine_produced"])
	game_state.expedition_state = state

	return {
		"expedition_food_consumed": food_consumed,
		"expedition_day_count": int(state["expedition_day_count"]),
		"carried_food_after": int(state["carried_food"]),
	}


func move_to_next_node(game_state) -> Dictionary:
	if not can_move_to_next_node(game_state):
		return {}

	var state: Dictionary = game_state.expedition_state
	var current_node_id: StringName = state["current_node_id"]
	var next_node_id: StringName = get_next_node_id(current_node_id)
	var daily_report: Dictionary = game_state.advance_day("expedition_move", false)

	state = game_state.expedition_state
	state["current_node_id"] = next_node_id
	state["furthest_node_id"] = get_furthest_node_id(state["furthest_node_id"], next_node_id)
	game_state.expedition_state = state

	var action_report := create_action_report(daily_report, state)
	action_report["action_type"] = "move"
	action_report["action_text"] = "冒险队前往%s" % get_node_display_name(next_node_id)
	action_report["node_id"] = next_node_id
	action_report["node_name"] = get_node_display_name(next_node_id)
	var encounter_id := get_node_encounter_id(next_node_id)
	action_report["starts_battle"] = encounter_id != EMPTY_NODE_ID and not is_battle_node_cleared(game_state, next_node_id)
	action_report["encounter_id"] = encounter_id
	game_state.last_expedition_action_report = action_report
	return action_report


func gather_current_node(game_state) -> Dictionary:
	if not can_gather_current_node(game_state):
		return {}

	var state: Dictionary = game_state.expedition_state
	var current_node_id: StringName = state["current_node_id"]
	var node: Dictionary = get_node_data(current_node_id)
	var gather_resource := String(node["gather_resource"])
	var gather_amount := int(node["gather_amount"])
	var daily_report: Dictionary = game_state.advance_day("expedition_gather", false)

	state = game_state.expedition_state
	if gather_resource == "ore":
		state["cargo_ore"] = int(state["cargo_ore"]) + gather_amount
	elif gather_resource == "herb":
		state["cargo_herb"] = int(state["cargo_herb"]) + gather_amount

	var collected_node_ids: Array = state["collected_node_ids"]
	collected_node_ids.append(current_node_id)
	state["collected_node_ids"] = collected_node_ids
	state["furthest_node_id"] = get_furthest_node_id(state["furthest_node_id"], current_node_id)
	game_state.expedition_state = state

	var action_report := create_action_report(daily_report, state)
	action_report["action_type"] = "gather"
	action_report["action_text"] = "冒险队在%s%s" % [
		get_node_display_name(current_node_id),
		String(node["gather_label"]),
	]
	action_report["node_id"] = current_node_id
	action_report["node_name"] = get_node_display_name(current_node_id)
	action_report["gather_resource"] = gather_resource
	action_report["gather_amount"] = gather_amount
	game_state.last_expedition_action_report = action_report
	return action_report


func return_to_village(game_state) -> Dictionary:
	var state: Dictionary = game_state.expedition_state
	if not bool(state["is_active"]):
		return {}

	state["is_active"] = false
	var food_returned := int(state["carried_food"])
	var medicine_returned := int(state["carried_medicine"])
	var ore_gained := int(state["cargo_ore"])
	var herb_gained := int(state["cargo_herb"])
	var report := {
		"duration_days": int(state["expedition_day_count"]),
		"furthest_node_id": state["furthest_node_id"],
		"furthest_node_name": get_node_display_name(state["furthest_node_id"]),
		"food_departed": int(state["food_departed"]),
		"food_consumed": int(state["food_consumed"]),
		"food_returned": food_returned,
		"medicine_departed": int(state["medicine_departed"]),
		"medicine_consumed": int(state["medicine_consumed"]),
		"medicine_returned": medicine_returned,
		"ore_gained": ore_gained,
		"herb_gained": herb_gained,
		"village_food_produced": int(state["village_food_produced"]),
		"village_food_consumed": int(state["village_food_consumed"]),
		"village_medicine_produced": int(state["village_medicine_produced"]),
	}

	var resources: Dictionary = game_state.resources
	resources["food"] = int(resources["food"]) + food_returned
	resources["medicine"] = int(resources["medicine"]) + medicine_returned
	resources["ore"] = int(resources["ore"]) + ore_gained
	resources["herb"] = int(resources["herb"]) + herb_gained
	game_state.resources = resources
	game_state.last_expedition_report = report
	game_state.last_expedition_action_report = {}
	game_state.expedition_state = create_initial_state()
	return report


func apply_battle_victory(game_state, result: Dictionary) -> void:
	var state: Dictionary = game_state.expedition_state
	if not bool(state["is_active"]):
		return
	var node_id: StringName = result["node_id"]
	var cleared_battle_node_ids: Array = state["cleared_battle_node_ids"]
	if not cleared_battle_node_ids.has(node_id):
		cleared_battle_node_ids.append(node_id)
		state["cargo_ore"] = int(state["cargo_ore"]) + int(result["reward_ore"])
		state["battle_count"] = int(state["battle_count"]) + 1
	state["cleared_battle_node_ids"] = cleared_battle_node_ids
	game_state.expedition_state = state


func apply_battle_failure(game_state, _result: Dictionary) -> Dictionary:
	var state: Dictionary = game_state.expedition_state
	if not bool(state["is_active"]):
		return {}

	state["is_active"] = false
	var ore_gained := int(floor(float(state["cargo_ore"]) * 0.5))
	var herb_gained := int(floor(float(state["cargo_herb"]) * 0.5))
	var report := {
		"duration_days": int(state["expedition_day_count"]),
		"furthest_node_id": state["furthest_node_id"],
		"furthest_node_name": get_node_display_name(state["furthest_node_id"]),
		"food_departed": int(state["food_departed"]),
		"food_consumed": int(state["food_consumed"]),
		"food_returned": 0,
		"medicine_departed": int(state["medicine_departed"]),
		"medicine_consumed": int(state["medicine_consumed"]),
		"medicine_returned": 0,
		"ore_gained": ore_gained,
		"herb_gained": herb_gained,
		"village_food_produced": int(state["village_food_produced"]),
		"village_food_consumed": int(state["village_food_consumed"]),
		"village_medicine_produced": int(state["village_medicine_produced"]),
		"is_failure": true,
	}

	var resources: Dictionary = game_state.resources
	resources["ore"] = int(resources["ore"]) + ore_gained
	resources["herb"] = int(resources["herb"]) + herb_gained
	game_state.resources = resources
	game_state.last_expedition_report = report
	game_state.last_expedition_action_report = {}
	game_state.expedition_state = create_initial_state()
	return report


func can_move_to_next_node(game_state) -> bool:
	var state: Dictionary = game_state.expedition_state
	if not bool(state["is_active"]):
		return false
	if game_state.is_battle_active():
		return false
	if int(state["carried_food"]) < 1:
		return false
	return get_next_node_id(state["current_node_id"]) != EMPTY_NODE_ID


func can_gather_current_node(game_state) -> bool:
	var state: Dictionary = game_state.expedition_state
	if not bool(state["is_active"]):
		return false
	if game_state.is_battle_active():
		return false
	if int(state["carried_food"]) < 1:
		return false
	var current_node_id: StringName = state["current_node_id"]
	var node: Dictionary = get_node_data(current_node_id)
	if String(node["gather_resource"]).is_empty():
		return false
	return not has_collected_current_node(game_state)


func has_collected_current_node(game_state) -> bool:
	var state: Dictionary = game_state.expedition_state
	var current_node_id: StringName = state["current_node_id"]
	var collected_node_ids: Array = state["collected_node_ids"]
	return collected_node_ids.has(current_node_id)


func get_node_data(node_id: StringName) -> Dictionary:
	if MAP_NODES.has(node_id):
		return MAP_NODES[node_id].duplicate(true)
	return MAP_NODES[START_NODE_ID].duplicate(true)


func get_node_display_name(node_id: StringName) -> String:
	return String(get_node_data(node_id)["display_name"])


func get_next_node_id(node_id: StringName) -> StringName:
	return get_node_data(node_id)["next_node_id"]


func get_next_node_display_name(node_id: StringName) -> String:
	var next_node_id := get_next_node_id(node_id)
	if next_node_id == EMPTY_NODE_ID:
		return ""
	return get_node_display_name(next_node_id)


func get_gather_label(node_id: StringName) -> String:
	return String(get_node_data(node_id)["gather_label"])


func get_node_encounter_id(node_id: StringName) -> StringName:
	return get_node_data(node_id)["encounter_id"]


func is_battle_node_cleared(game_state, node_id: StringName) -> bool:
	var state: Dictionary = game_state.expedition_state
	var cleared_battle_node_ids: Array = state.get("cleared_battle_node_ids", [])
	return cleared_battle_node_ids.has(node_id)


func get_furthest_node_id(current_furthest, candidate: StringName) -> StringName:
	var current_index := NODE_ORDER.find(current_furthest)
	var candidate_index := NODE_ORDER.find(candidate)
	if candidate_index > current_index:
		return candidate
	return current_furthest


func create_action_report(daily_report: Dictionary, state: Dictionary) -> Dictionary:
	return {
		"settled_day": int(daily_report["settled_day"]),
		"new_day": int(daily_report["new_day"]),
		"food_produced": int(daily_report["food_produced"]),
		"village_food_consumed": int(daily_report["food_consumed"]),
		"medicine_produced": int(daily_report["medicine_produced"]),
		"medicine_progress": int(daily_report["medicine_progress"]),
		"medicine_progress_required": int(daily_report["medicine_progress_required"]),
		"expedition_food_consumed": int(daily_report["expedition_food_consumed"]),
		"carried_food": int(state["carried_food"]),
		"carried_medicine": int(state["carried_medicine"]),
		"cargo_ore": int(state["cargo_ore"]),
		"cargo_herb": int(state["cargo_herb"]),
	}

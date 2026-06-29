extends RefCounted

const EMPTY_ID := &""
const PLAYER_ACTION_BASIC_ATTACK := &"basic_attack"
const PLAYER_ACTION_SKILL := &"skill"
const PLAYER_ACTION_DEFEND := &"defend"
const PLAYER_ACTION_MEDICINE := &"medicine"

const PARTY_CONFIGS := [
	{
		"unit_id": &"guard",
		"display_name": "阿盾",
		"role": "守卫",
		"max_hp": 40,
		"attack": 6,
		"defense": 5,
		"speed": 3,
		"skill_name": "盾击",
		"skill_cooldown_duration": 2,
		"skill_type": "single_damage",
		"skill_multiplier": 1.2,
	},
	{
		"unit_id": &"hunter",
		"display_name": "林羽",
		"role": "猎人",
		"max_hp": 26,
		"attack": 8,
		"defense": 2,
		"speed": 7,
		"skill_name": "强力射击",
		"skill_cooldown_duration": 2,
		"skill_type": "single_damage",
		"skill_multiplier": 1.8,
	},
	{
		"unit_id": &"mage",
		"display_name": "米娅",
		"role": "法师",
		"max_hp": 22,
		"attack": 7,
		"defense": 1,
		"speed": 5,
		"skill_name": "奥术冲击",
		"skill_cooldown_duration": 3,
		"skill_type": "aoe_damage",
		"skill_multiplier": 0.8,
	},
	{
		"unit_id": &"doctor",
		"display_name": "露娜",
		"role": "医师",
		"max_hp": 24,
		"attack": 4,
		"defense": 2,
		"speed": 6,
		"skill_name": "治疗术",
		"skill_cooldown_duration": 2,
		"skill_type": "heal",
		"skill_heal_amount": 10,
	},
]
const ENCOUNTERS := {
	&"forest_slime_pair": {
		"display_name": "森林边缘",
		"node_id": &"forest_edge",
		"reward_ore": 1,
		"enemies": [
			{
				"unit_id": &"forest_slime_01",
				"display_name": "森林史莱姆A",
				"max_hp": 14,
				"attack": 5,
				"defense": 1,
				"speed": 2,
			},
			{
				"unit_id": &"forest_slime_02",
				"display_name": "森林史莱姆B",
				"max_hp": 14,
				"attack": 5,
				"defense": 1,
				"speed": 2,
			},
		],
	},
}


func create_initial_party_states() -> Array:
	var party_states: Array = []
	for config: Dictionary in PARTY_CONFIGS:
		party_states.append(create_party_unit_state(config))
	return party_states


func create_initial_state() -> Dictionary:
	return {
		"is_active": false,
		"encounter_id": EMPTY_ID,
		"encounter_node_id": EMPTY_ID,
		"round_number": 1,
		"current_turn_index": 0,
		"turn_order": [],
		"party_states": [],
		"enemy_states": [],
		"battle_log": [],
		"selected_action": EMPTY_ID,
		"selected_target_id": EMPTY_ID,
		"reward_granted": false,
		"result_processed": false,
		"last_result": {},
	}


func start_battle(game_state, encounter_id: StringName) -> bool:
	if bool(game_state.battle_state.get("is_active", false)):
		return false
	if not ENCOUNTERS.has(encounter_id):
		return false

	var encounter: Dictionary = ENCOUNTERS[encounter_id]
	var party_states: Array = game_state.adventurers.duplicate(true)
	for party_unit: Dictionary in party_states:
		party_unit["is_defending"] = false

	var enemy_states := create_enemy_states(encounter)
	var battle_state := create_initial_state()
	battle_state["is_active"] = true
	battle_state["encounter_id"] = encounter_id
	battle_state["encounter_node_id"] = encounter["node_id"]
	battle_state["party_states"] = party_states
	battle_state["enemy_states"] = enemy_states
	battle_state["battle_log"] = [
		"冒险队遭遇%s。" % String(encounter["display_name"]),
	]
	game_state.battle_state = battle_state
	start_next_round(game_state)
	return true


func execute_player_action(game_state, action_id: StringName, target_id: StringName = EMPTY_ID) -> Dictionary:
	var battle_state: Dictionary = game_state.battle_state
	if not bool(battle_state["is_active"]):
		return {"success": false}
	var active_unit: Dictionary = get_active_unit(battle_state)
	if active_unit.is_empty() or not bool(active_unit["is_player_unit"]):
		return {"success": false}

	var action_success := false
	match action_id:
		PLAYER_ACTION_BASIC_ATTACK:
			action_success = execute_basic_attack(battle_state, active_unit, target_id)
		PLAYER_ACTION_SKILL:
			action_success = execute_skill(battle_state, active_unit, target_id)
		PLAYER_ACTION_DEFEND:
			action_success = execute_defend(battle_state, active_unit)
		PLAYER_ACTION_MEDICINE:
			action_success = execute_medicine(game_state, battle_state, active_unit, target_id)

	if not action_success:
		game_state.battle_state = battle_state
		return {"success": false}

	game_state.battle_state = battle_state
	return finish_action_and_advance(game_state)


func get_active_unit(battle_state: Dictionary) -> Dictionary:
	if not bool(battle_state["is_active"]):
		return {}
	var turn_order: Array = battle_state["turn_order"]
	if turn_order.is_empty():
		return {}
	var current_turn_index := int(battle_state["current_turn_index"])
	if current_turn_index < 0 or current_turn_index >= turn_order.size():
		return {}
	var entry: Dictionary = turn_order[current_turn_index]
	if bool(entry["is_player_unit"]):
		return get_unit_by_id(battle_state["party_states"], entry["unit_id"])
	return get_unit_by_id(battle_state["enemy_states"], entry["unit_id"])


func get_active_unit_id(battle_state: Dictionary) -> StringName:
	var active_unit := get_active_unit(battle_state)
	if active_unit.is_empty():
		return EMPTY_ID
	return active_unit["unit_id"]


func restore_party_full(party_states: Array) -> Array:
	var restored: Array = party_states.duplicate(true)
	for unit: Dictionary in restored:
		unit["current_hp"] = int(unit["max_hp"])
		unit["skill_cooldown"] = 0
		unit["is_defending"] = false
	return restored


func create_party_unit_state(config: Dictionary) -> Dictionary:
	return {
		"unit_id": config["unit_id"],
		"display_name": config["display_name"],
		"role": config["role"],
		"is_player_unit": true,
		"max_hp": int(config["max_hp"]),
		"current_hp": int(config["max_hp"]),
		"attack": int(config["attack"]),
		"defense": int(config["defense"]),
		"speed": int(config["speed"]),
		"skill_name": config["skill_name"],
		"skill_type": config["skill_type"],
		"skill_multiplier": float(config.get("skill_multiplier", 0.0)),
		"skill_heal_amount": int(config.get("skill_heal_amount", 0)),
		"skill_cooldown_duration": int(config["skill_cooldown_duration"]),
		"skill_cooldown": 0,
		"is_defending": false,
	}


func create_enemy_states(encounter: Dictionary) -> Array:
	var enemy_states: Array = []
	for enemy_config: Dictionary in encounter["enemies"]:
		enemy_states.append({
			"unit_id": enemy_config["unit_id"],
			"display_name": enemy_config["display_name"],
			"is_player_unit": false,
			"max_hp": int(enemy_config["max_hp"]),
			"current_hp": int(enemy_config["max_hp"]),
			"attack": int(enemy_config["attack"]),
			"defense": int(enemy_config["defense"]),
			"speed": int(enemy_config["speed"]),
			"skill_cooldown": 0,
			"is_defending": false,
		})
	return enemy_states


func execute_basic_attack(battle_state: Dictionary, attacker: Dictionary, target_id: StringName) -> bool:
	var target := get_unit_by_id(battle_state["enemy_states"], target_id)
	if target.is_empty() or is_unit_defeated(target):
		return false

	var damage := calculate_damage(int(attacker["attack"]), int(target["defense"]), bool(target.get("is_defending", false)))
	apply_damage(target, damage)
	set_unit_by_id(battle_state["enemy_states"], target)
	append_log(battle_state, "%s普通攻击%s，造成%d点伤害。" % [
		String(attacker["display_name"]),
		String(target["display_name"]),
		damage,
	])
	return true


func execute_skill(battle_state: Dictionary, attacker: Dictionary, target_id: StringName) -> bool:
	if int(attacker["skill_cooldown"]) > 0:
		return false

	var skill_type := String(attacker["skill_type"])
	if skill_type == "single_damage":
		var target := get_unit_by_id(battle_state["enemy_states"], target_id)
		if target.is_empty() or is_unit_defeated(target):
			return false
		var skill_attack := int(floor(float(attacker["attack"]) * float(attacker["skill_multiplier"])))
		var damage := calculate_damage(skill_attack, int(target["defense"]), bool(target.get("is_defending", false)))
		apply_damage(target, damage)
		set_unit_by_id(battle_state["enemy_states"], target)
		append_log(battle_state, "%s使用%s，对%s造成%d点伤害。" % [
			String(attacker["display_name"]),
			String(attacker["skill_name"]),
			String(target["display_name"]),
			damage,
		])
	elif skill_type == "aoe_damage":
		var total_hits := 0
		var skill_attack := int(floor(float(attacker["attack"]) * float(attacker["skill_multiplier"])))
		var enemies: Array = battle_state["enemy_states"]
		for index in range(enemies.size()):
			var enemy: Dictionary = enemies[index]
			if is_unit_defeated(enemy):
				continue
			var damage := calculate_damage(skill_attack, int(enemy["defense"]), bool(enemy.get("is_defending", false)))
			apply_damage(enemy, damage)
			enemies[index] = enemy
			total_hits += 1
			append_log(battle_state, "%s使用%s，对%s造成%d点伤害。" % [
				String(attacker["display_name"]),
				String(attacker["skill_name"]),
				String(enemy["display_name"]),
				damage,
			])
		if total_hits == 0:
			return false
		battle_state["enemy_states"] = enemies
	elif skill_type == "heal":
		var target := get_unit_by_id(battle_state["party_states"], target_id)
		if target.is_empty() or is_unit_defeated(target) or int(target["current_hp"]) >= int(target["max_hp"]):
			return false
		var healed := apply_heal(target, int(attacker["skill_heal_amount"]))
		set_unit_by_id(battle_state["party_states"], target)
		append_log(battle_state, "%s使用%s，为%s恢复%d点生命。" % [
			String(attacker["display_name"]),
			String(attacker["skill_name"]),
			String(target["display_name"]),
			healed,
		])
	else:
		return false

	attacker["skill_cooldown"] = int(attacker["skill_cooldown_duration"])
	set_unit_by_id(battle_state["party_states"], attacker)
	return true


func execute_defend(battle_state: Dictionary, unit: Dictionary) -> bool:
	unit["is_defending"] = true
	set_unit_by_id(battle_state["party_states"], unit)
	append_log(battle_state, "%s进入防御状态。" % String(unit["display_name"]))
	return true


func execute_medicine(game_state, battle_state: Dictionary, unit: Dictionary, target_id: StringName) -> bool:
	var expedition_state: Dictionary = game_state.expedition_state
	if int(expedition_state["carried_medicine"]) <= 0:
		return false
	var target := get_unit_by_id(battle_state["party_states"], target_id)
	if target.is_empty() or is_unit_defeated(target) or int(target["current_hp"]) >= int(target["max_hp"]):
		return false

	expedition_state["carried_medicine"] = max(0, int(expedition_state["carried_medicine"]) - 1)
	expedition_state["medicine_consumed"] = int(expedition_state["medicine_consumed"]) + 1
	game_state.expedition_state = expedition_state

	var healed := apply_heal(target, 12)
	set_unit_by_id(battle_state["party_states"], target)
	append_log(battle_state, "%s使用药品，为%s恢复%d点生命。" % [
		String(unit["display_name"]),
		String(target["display_name"]),
		healed,
	])
	return true


func finish_action_and_advance(game_state) -> Dictionary:
	var battle_state: Dictionary = game_state.battle_state
	if are_all_enemies_defeated(battle_state):
		return finish_battle(game_state, "victory")
	if are_all_party_members_defeated(battle_state):
		return finish_battle(game_state, "failure")

	battle_state["current_turn_index"] = int(battle_state["current_turn_index"]) + 1
	game_state.battle_state = battle_state
	return advance_until_player_turn_or_finish(game_state)


func advance_until_player_turn_or_finish(game_state) -> Dictionary:
	var safety := 0
	while safety < 100:
		safety += 1
		var battle_state: Dictionary = game_state.battle_state
		if not bool(battle_state["is_active"]):
			return {"success": true}

		var turn_order: Array = battle_state["turn_order"]
		if turn_order.is_empty() or int(battle_state["current_turn_index"]) >= turn_order.size():
			battle_state["round_number"] = int(battle_state["round_number"]) + 1
			game_state.battle_state = battle_state
			start_next_round(game_state)
			battle_state = game_state.battle_state

		var active_unit := get_active_unit(battle_state)
		if active_unit.is_empty() or is_unit_defeated(active_unit):
			battle_state["current_turn_index"] = int(battle_state["current_turn_index"]) + 1
			game_state.battle_state = battle_state
			continue

		if bool(active_unit["is_player_unit"]):
			prepare_player_turn(game_state, active_unit)
			return {"success": true}

		execute_enemy_turn(game_state, active_unit)
		battle_state = game_state.battle_state
		if are_all_party_members_defeated(battle_state):
			return finish_battle(game_state, "failure")
		battle_state["current_turn_index"] = int(battle_state["current_turn_index"]) + 1
		game_state.battle_state = battle_state

	return {"success": false}


func start_next_round(game_state) -> void:
	var battle_state: Dictionary = game_state.battle_state
	battle_state["turn_order"] = generate_turn_order(battle_state)
	battle_state["current_turn_index"] = 0
	game_state.battle_state = battle_state
	advance_until_player_turn_or_finish(game_state)


func prepare_player_turn(game_state, unit: Dictionary) -> void:
	var battle_state: Dictionary = game_state.battle_state
	if int(unit["skill_cooldown"]) > 0:
		unit["skill_cooldown"] = int(unit["skill_cooldown"]) - 1
	unit["is_defending"] = false
	set_unit_by_id(battle_state["party_states"], unit)
	game_state.battle_state = battle_state


func execute_enemy_turn(game_state, enemy: Dictionary) -> void:
	var battle_state: Dictionary = game_state.battle_state
	var target := get_first_alive_party_unit(battle_state)
	if target.is_empty():
		return
	var damage := calculate_damage(int(enemy["attack"]), int(target["defense"]), bool(target.get("is_defending", false)))
	apply_damage(target, damage)
	set_unit_by_id(battle_state["party_states"], target)
	append_log(battle_state, "%s攻击%s，造成%d点伤害。" % [
		String(enemy["display_name"]),
		String(target["display_name"]),
		damage,
	])
	game_state.battle_state = battle_state


func finish_battle(game_state, outcome: String) -> Dictionary:
	var battle_state: Dictionary = game_state.battle_state
	if bool(battle_state["result_processed"]):
		return {
			"success": true,
			"finished": true,
			"result": battle_state["last_result"].duplicate(true),
		}

	battle_state["result_processed"] = true
	battle_state["is_active"] = false
	for index in range(battle_state["party_states"].size()):
		var party_unit: Dictionary = battle_state["party_states"][index]
		party_unit["is_defending"] = false
		battle_state["party_states"][index] = party_unit
	game_state.adventurers = battle_state["party_states"].duplicate(true)

	var result := {
		"outcome": outcome,
		"encounter_id": battle_state["encounter_id"],
		"node_id": battle_state["encounter_node_id"],
		"round_number": int(battle_state["round_number"]),
		"party_states": battle_state["party_states"].duplicate(true),
		"enemy_states": battle_state["enemy_states"].duplicate(true),
		"reward_ore": 0,
	}
	if outcome == "victory":
		var encounter: Dictionary = ENCOUNTERS[battle_state["encounter_id"]]
		result["reward_ore"] = int(encounter["reward_ore"])
		battle_state["reward_granted"] = true
		append_log(battle_state, "战斗胜利，获得临时矿石 +%d。" % int(result["reward_ore"]))
	else:
		append_log(battle_state, "冒险队全员倒下，远征失败。")

	battle_state["last_result"] = result.duplicate(true)
	game_state.battle_state = battle_state
	return {
		"success": true,
		"finished": true,
		"result": result,
	}


func generate_turn_order(battle_state: Dictionary) -> Array:
	var entries: Array = []
	append_turn_entries(entries, battle_state["party_states"], true)
	append_turn_entries(entries, battle_state["enemy_states"], false)
	sort_turn_entries(entries)
	return entries


func append_turn_entries(entries: Array, units: Array, is_player_unit: bool) -> void:
	for index in range(units.size()):
		var unit: Dictionary = units[index]
		if is_unit_defeated(unit):
			continue
		}
		entries.append({
			"unit_id": unit["unit_id"],
			"is_player_unit": is_player_unit,
			"speed": int(unit["speed"]),
			"source_index": index,
		})


func sort_turn_entries(entries: Array) -> void:
	for index in range(1, entries.size()):
		var current: Dictionary = entries[index]
		var previous_index := index - 1
		while previous_index >= 0 and should_entry_come_before(current, entries[previous_index]):
			entries[previous_index + 1] = entries[previous_index]
			previous_index -= 1
		entries[previous_index + 1] = current


func should_entry_come_before(a: Dictionary, b: Dictionary) -> bool:
	if int(a["speed"]) != int(b["speed"]):
		return int(a["speed"]) > int(b["speed"])
	if bool(a["is_player_unit"]) != bool(b["is_player_unit"]):
		return bool(a["is_player_unit"])
	return int(a["source_index"]) < int(b["source_index"])


func calculate_damage(attack_value: int, defense_value: int, is_defending: bool) -> int:
	var damage: int = max(1, attack_value - defense_value)
	if is_defending:
		damage = max(1, int(floor(float(damage) * 0.5)))
	return damage


func apply_damage(unit: Dictionary, damage: int) -> void:
	unit["current_hp"] = max(0, int(unit["current_hp"]) - damage)


func apply_heal(unit: Dictionary, heal_amount: int) -> int:
	var before: int = int(unit["current_hp"])
	unit["current_hp"] = min(int(unit["max_hp"]), before + heal_amount)
	return int(unit["current_hp"]) - before


func get_first_alive_party_unit(battle_state: Dictionary) -> Dictionary:
	for unit: Dictionary in battle_state["party_states"]:
		if not is_unit_defeated(unit):
			return unit
	return {}


func get_unit_by_id(units: Array, unit_id: StringName) -> Dictionary:
	for unit: Dictionary in units:
		if unit["unit_id"] == unit_id:
			return unit
	return {}


func set_unit_by_id(units: Array, updated_unit: Dictionary) -> void:
	for index in range(units.size()):
		if units[index]["unit_id"] == updated_unit["unit_id"]:
			units[index] = updated_unit
			return


func is_unit_defeated(unit: Dictionary) -> bool:
	return int(unit["current_hp"]) <= 0


func are_all_enemies_defeated(battle_state: Dictionary) -> bool:
	for enemy: Dictionary in battle_state["enemy_states"]:
		if not is_unit_defeated(enemy):
			return false
	return true


func are_all_party_members_defeated(battle_state: Dictionary) -> bool:
	for party_unit: Dictionary in battle_state["party_states"]:
		if not is_unit_defeated(party_unit):
			return false
	return true


func append_log(battle_state: Dictionary, message: String) -> void:
	var battle_log: Array = battle_state["battle_log"]
	battle_log.append(message)
	while battle_log.size() > 12:
		battle_log.pop_front()
	battle_state["battle_log"] = battle_log

extends Node2D

signal character_died(character_id: StringName)

const BODY_RADIUS := 17.0
const HEALTH_BAR_WIDTH := 44.0

var character_id: StringName = &""
var role_id: StringName = &""
var display_name := ""
var deployed_slot_id: StringName = &""
var lane_id: StringName = &""
var max_health := 1
var current_health := 1
var action_interval := 1.0
var action_range := 0.0
var current_cooldown := 0.0
var current_target_id: StringName = &""
var is_alive := true
var action_count := 0
var total_effect_amount := 0
var attack_damage := 0
var heal_amount := 0
var block_capacity := 0
var damage_source_type: StringName = &"UNSPECIFIED"
var blocked_enemy_ids: Array[StringName] = []
var body_color := Color.WHITE
var show_action_range := false
var last_action_type: StringName = &""


func configure(new_character_id: StringName, definition: Dictionary) -> void:
	character_id = new_character_id
	role_id = StringName(definition.get("role_id", new_character_id))
	display_name = String(definition.get("display_name", new_character_id))
	max_health = maxi(1, int(definition.get("max_health", 1)))
	action_interval = maxf(0.05, float(definition.get("action_interval", 1.0)))
	action_range = maxf(0.0, float(definition.get("action_range", 0.0)))
	attack_damage = maxi(0, int(definition.get("attack_damage", 0)))
	heal_amount = maxi(0, int(definition.get("heal_amount", 0)))
	block_capacity = maxi(0, int(definition.get("block_capacity", 0)))
	damage_source_type = StringName(
		definition.get("damage_source_type", &"UNSPECIFIED")
	)
	body_color = definition.get("body_color", Color.WHITE)
	name = "PrototypeCharacter_%s" % String(character_id)
	reset_combat_state()
	visible = false


func deploy_to(
	slot_id: StringName,
	new_lane_id: StringName,
	world_position: Vector2
) -> void:
	deployed_slot_id = slot_id
	lane_id = new_lane_id
	position = world_position
	visible = true
	queue_redraw()


func undeploy() -> void:
	deployed_slot_id = &""
	lane_id = &""
	current_target_id = &""
	blocked_enemy_ids.clear()
	visible = false
	queue_redraw()


func is_deployed() -> bool:
	return deployed_slot_id != &""


func reset_combat_state() -> void:
	current_health = max_health
	current_cooldown = 0.0
	current_target_id = &""
	is_alive = true
	action_count = 0
	total_effect_amount = 0
	blocked_enemy_ids.clear()
	last_action_type = &""
	queue_redraw()


func set_selected(selected: bool) -> void:
	show_action_range = selected and is_deployed()
	queue_redraw()


func add_blocked_enemy(enemy_id: StringName) -> bool:
	if role_id != &"guard" or not is_alive:
		return false
	if blocked_enemy_ids.has(enemy_id):
		return true
	if blocked_enemy_ids.size() >= block_capacity:
		return false
	blocked_enemy_ids.append(enemy_id)
	return true


func remove_blocked_enemy(enemy_id: StringName) -> void:
	blocked_enemy_ids.erase(enemy_id)


func clear_blocked_enemies() -> void:
	blocked_enemy_ids.clear()


func has_block_capacity() -> bool:
	return (
		role_id == &"guard"
		and is_alive
		and blocked_enemy_ids.size() < block_capacity
	)


func take_damage(amount: int) -> int:
	if not is_alive or amount <= 0:
		return 0
	var previous_health := current_health
	current_health = maxi(0, current_health - amount)
	var applied := previous_health - current_health
	if current_health <= 0:
		is_alive = false
		current_target_id = &""
		character_died.emit(character_id)
	queue_redraw()
	return applied


func receive_healing(amount: int) -> int:
	if not is_alive or amount <= 0 or current_health >= max_health:
		return 0
	var previous_health := current_health
	current_health = mini(max_health, current_health + amount)
	var applied := current_health - previous_health
	queue_redraw()
	return applied


func simulate_action(
	delta: float,
	active_enemies: Array,
	all_characters: Array,
	command_controller = null
) -> Dictionary:
	if not is_deployed() or not is_alive:
		return {}
	current_cooldown = maxf(0.0, current_cooldown - maxf(0.0, delta))
	if current_cooldown > 0.0:
		return {}
	if role_id == &"doctor":
		var heal_target = choose_heal_target(all_characters)
		if heal_target == null:
			current_target_id = &""
			return {}
		current_target_id = heal_target.character_id
		var healed := int(heal_target.receive_healing(heal_amount))
		if healed <= 0:
			return {}
		current_cooldown = action_interval
		action_count += 1
		total_effect_amount += healed
		last_action_type = &"heal"
		queue_redraw()
		return {
			"type": &"heal",
			"source_id": character_id,
			"target_id": current_target_id,
			"amount": healed,
		}
	var attack_target = choose_enemy_target(active_enemies, command_controller)
	if attack_target == null:
		current_target_id = &""
		return {}
	current_target_id = attack_target.runtime_id
	var resolved_target_id: StringName = attack_target.runtime_id
	var attack_origin_position: Vector2 = position
	var attack_target_position: Vector2 = attack_target.position
	var dealt := int(
		attack_target.take_damage(attack_damage, damage_source_type)
	)
	if dealt <= 0:
		return {}
	current_cooldown = action_interval
	action_count += 1
	total_effect_amount += dealt
	last_action_type = &"attack"
	queue_redraw()
	return {
		"type": &"attack",
		"source_id": character_id,
		"target_id": resolved_target_id,
		"amount": dealt,
		"attack_sequence_id": action_count,
		"origin_position": attack_origin_position,
		"target_position": attack_target_position,
		"role_id": role_id,
		"damage_source_type": damage_source_type,
	}


func choose_enemy_target(active_enemies: Array, command_controller = null):
	var legal_candidates := get_legal_enemy_candidates(active_enemies)
	if is_instance_valid(command_controller) \
			and command_controller.has_method("get_priority_target_for"):
		return command_controller.get_priority_target_for(self, legal_candidates)
	return legal_candidates[0] if not legal_candidates.is_empty() else null


func get_legal_enemy_candidates(active_enemies: Array) -> Array:
	var candidates: Array = []
	for enemy in active_enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.is_dead or enemy.settlement_completed:
			continue
		if role_id == &"guard":
			if (
				StringName(enemy.blocked_by_character_id) != character_id
				or not blocked_enemy_ids.has(StringName(enemy.runtime_id))
			):
				continue
		elif position.distance_to(enemy.position) > action_range:
			continue
		candidates.append(enemy)
	candidates.sort_custom(func(left, right): return is_better_enemy_target(left, right))
	return candidates


func is_better_enemy_target(candidate, current_best) -> bool:
	if current_best == null:
		return true
	var progress_difference := float(candidate.route_progress) - float(
		current_best.route_progress
	)
	if absf(progress_difference) > 0.00001:
		return progress_difference > 0.0
	var candidate_sequence := int(candidate.spawn_sequence)
	var best_sequence := int(current_best.spawn_sequence)
	if candidate_sequence != best_sequence:
		return candidate_sequence < best_sequence
	return String(candidate.runtime_id) < String(current_best.runtime_id)


func choose_heal_target(all_characters: Array):
	var best_character = null
	for character in all_characters:
		if not is_instance_valid(character):
			continue
		if (
			not character.is_deployed()
			or not character.is_alive
			or character.current_health >= character.max_health
		):
			continue
		if position.distance_to(character.position) > action_range:
			continue
		if is_better_heal_target(character, best_character):
			best_character = character
	return best_character


func is_better_heal_target(candidate, current_best) -> bool:
	if current_best == null:
		return true
	var candidate_ratio := float(candidate.current_health) / float(candidate.max_health)
	var best_ratio := float(current_best.current_health) / float(
		current_best.max_health
	)
	if absf(candidate_ratio - best_ratio) > 0.00001:
		return candidate_ratio < best_ratio
	return String(candidate.character_id) < String(current_best.character_id)


func get_runtime_snapshot() -> Dictionary:
	return {
		"character_id": character_id,
		"role_id": role_id,
		"display_name": display_name,
		"deployed_slot_id": deployed_slot_id,
		"lane_id": lane_id,
		"max_health": max_health,
		"current_health": current_health,
		"action_interval": action_interval,
		"action_range": action_range,
		"current_cooldown": current_cooldown,
		"current_target_id": current_target_id,
		"is_alive": is_alive,
		"action_count": action_count,
		"total_effect_amount": total_effect_amount,
		"attack_damage": attack_damage,
		"heal_amount": heal_amount,
		"block_capacity": block_capacity,
		"damage_source_type": damage_source_type,
		"blocked_enemy_ids": blocked_enemy_ids.duplicate(),
		"last_action_type": last_action_type,
	}


func _draw() -> void:
	if show_action_range:
		var range_color := (
			Color(0.36, 1.0, 0.78, 0.08)
			if role_id == &"doctor"
			else Color(body_color, 0.08)
		)
		var range_line_color := (
			Color(0.42, 1.0, 0.82, 0.58)
			if role_id == &"doctor"
			else Color(body_color, 0.58)
		)
		draw_circle(Vector2.ZERO, action_range, range_color)
		draw_arc(
			Vector2.ZERO,
			action_range,
			0.0,
			TAU,
			64,
			range_line_color,
			2.0,
			true
		)
	var visible_color := body_color if is_alive else Color(0.28, 0.30, 0.34, 1.0)
	draw_circle(Vector2.ZERO, BODY_RADIUS + 3.0, Color(0.02, 0.03, 0.05, 0.9))
	draw_circle(Vector2.ZERO, BODY_RADIUS, visible_color)
	draw_circle(Vector2(-5.0, -5.0), 3.5, Color(1.0, 1.0, 1.0, 0.8))
	var health_ratio := clampf(float(current_health) / float(max_health), 0.0, 1.0)
	var health_origin := Vector2(-HEALTH_BAR_WIDTH * 0.5, -27.0)
	draw_rect(
		Rect2(health_origin, Vector2(HEALTH_BAR_WIDTH, 6.0)),
		Color(0.08, 0.10, 0.13, 0.95)
	)
	draw_rect(
		Rect2(health_origin, Vector2(HEALTH_BAR_WIDTH * health_ratio, 6.0)),
		Color(0.36, 0.94, 0.55, 1.0)
	)

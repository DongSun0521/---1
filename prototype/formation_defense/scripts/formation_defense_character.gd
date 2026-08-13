extends Node2D

signal character_died(character_id: StringName)

const BODY_RADIUS := 17.0
const HEALTH_BAR_WIDTH := 44.0
const ROLE_LABEL_RECT := Rect2(-30.0, 25.0, 60.0, 18.0)

var character_id: StringName = &""
var role_id: StringName = &""
var display_name := ""
var role_label_visible := false
var deployed_slot_id: StringName = &""
var lane_id: StringName = &""
var max_health := 1
var current_health := 1
var action_interval := 1.0
var action_range := 0.0
var current_cooldown := 0.0
var current_target_id: StringName = &""
var is_alive := true
var is_incapacitated := false
var action_count := 0
var total_effect_amount := 0
var total_damage_taken := 0
var incapacitation_count := 0
var attack_damage := 0
var heal_amount := 0
var block_capacity := 0
var damage_source_type: StringName = &"UNSPECIFIED"
var blocked_enemy_ids: Array[StringName] = []
var body_color := Color.WHITE
var show_action_range := false
var last_action_type: StringName = &""
var contact_combat_enabled := false
var has_been_contacted := false
var hit_flash_remaining := 0.0
var hit_reaction_elapsed := 0.0
var heal_flash_remaining := 0.0
var ultimate_enabled := false
var ultimate_energy := 0.0
var ultimate_energy_max := 100.0
var ultimate_energy_cost := 100.0
var ultimate_energy_regen_per_second := 0.0
var ultimate_ready := false
var is_ultimate_targeting := false
var ultimate_definition: Dictionary = {}
var ultimate_release_count := 0
var ultimate_first_ready_time := -1.0
var ultimate_passive_energy_gained := 0.0
var ultimate_event_energy_gained := 0.0
var ultimate_event_trigger_count := 0
var ultimate_event_trigger_counts: Dictionary = {}
var ultimate_event_throttled_count := 0
var ultimate_last_event_trigger_time := -1.0


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
	is_incapacitated = false
	action_count = 0
	total_effect_amount = 0
	total_damage_taken = 0
	incapacitation_count = 0
	blocked_enemy_ids.clear()
	last_action_type = &""
	has_been_contacted = false
	hit_flash_remaining = 0.0
	hit_reaction_elapsed = 0.0
	heal_flash_remaining = 0.0
	reset_ultimate_runtime()
	queue_redraw()


func set_contact_combat_enabled(enabled: bool) -> void:
	contact_combat_enabled = enabled
	if not enabled:
		has_been_contacted = false
		hit_flash_remaining = 0.0
		hit_reaction_elapsed = 0.0
	queue_redraw()


func mark_contacted() -> void:
	if not contact_combat_enabled:
		return
	has_been_contacted = true
	queue_redraw()


func tick_contact_visual(delta: float) -> void:
	if not contact_combat_enabled and not ultimate_enabled:
		return
	var safe_delta := maxf(0.0, delta)
	var needs_redraw := false
	if hit_flash_remaining > 0.0:
		hit_flash_remaining = maxf(0.0, hit_flash_remaining - safe_delta)
		hit_reaction_elapsed += safe_delta
		needs_redraw = true
	if heal_flash_remaining > 0.0:
		heal_flash_remaining = maxf(0.0, heal_flash_remaining - safe_delta)
		needs_redraw = true
	if needs_redraw:
		queue_redraw()


func clear_contact_transient_visuals() -> void:
	hit_flash_remaining = 0.0
	hit_reaction_elapsed = 0.0
	heal_flash_remaining = 0.0
	queue_redraw()


func configure_ultimate(enabled: bool, definition: Dictionary = {}) -> void:
	ultimate_enabled = enabled
	ultimate_definition = definition.duplicate(true) if enabled else {}
	ultimate_energy_max = maxf(
		1.0,
		float(ultimate_definition.get("energy_max", 100.0))
	)
	ultimate_energy_cost = clampf(
		float(ultimate_definition.get("energy_cost", ultimate_energy_max)),
		0.0001,
		ultimate_energy_max
	)
	ultimate_energy_regen_per_second = maxf(
		0.0,
		float(ultimate_definition.get("energy_regen_per_second", 0.0))
	)
	reset_ultimate_runtime()


func reset_ultimate_runtime() -> void:
	ultimate_energy = 0.0
	ultimate_ready = false
	is_ultimate_targeting = false
	ultimate_release_count = 0
	ultimate_first_ready_time = -1.0
	ultimate_passive_energy_gained = 0.0
	ultimate_event_energy_gained = 0.0
	ultimate_event_trigger_count = 0
	ultimate_event_trigger_counts.clear()
	ultimate_event_throttled_count = 0
	ultimate_last_event_trigger_time = -1.0
	queue_redraw()


func clear_ultimate_event_throttle() -> void:
	ultimate_last_event_trigger_time = -1.0


func advance_ultimate_energy(
	delta: float,
	battle_running: bool,
	battle_time: float
) -> void:
	if (
		not ultimate_enabled
		or not battle_running
		or not is_deployed()
		or not is_alive
		or ultimate_ready
	):
		return
	var applied := add_ultimate_energy(
		maxf(0.0, delta) * ultimate_energy_regen_per_second,
		battle_time
	)
	ultimate_passive_energy_gained += applied


func grant_ultimate_event_energy(
	event_type: StringName,
	battle_time: float,
	battle_running: bool
) -> float:
	if (
		not ultimate_enabled
		or not battle_running
		or not is_deployed()
		or not is_alive
		or ultimate_ready
	):
		return 0.0
	var event_energy: Dictionary = ultimate_definition.get("event_energy", {})
	var configured_amount := maxf(0.0, float(event_energy.get(event_type, 0.0)))
	if configured_amount <= 0.0:
		return 0.0
	var trigger_interval := maxf(
		0.0,
		float(ultimate_definition.get("event_trigger_interval", 0.0))
	)
	if (
		trigger_interval > 0.0
		and ultimate_last_event_trigger_time >= 0.0
		and battle_time - ultimate_last_event_trigger_time
			< trigger_interval - 0.0001
	):
		ultimate_event_throttled_count += 1
		return 0.0
	var applied := add_ultimate_energy(configured_amount, battle_time)
	if applied <= 0.0:
		return 0.0
	ultimate_last_event_trigger_time = battle_time
	ultimate_event_energy_gained += applied
	ultimate_event_trigger_count += 1
	ultimate_event_trigger_counts[event_type] = int(
		ultimate_event_trigger_counts.get(event_type, 0)
	) + 1
	return applied


func add_ultimate_energy(amount: float, battle_time: float) -> float:
	if amount <= 0.0 or ultimate_ready:
		return 0.0
	var previous_energy := ultimate_energy
	ultimate_energy = minf(ultimate_energy_max, ultimate_energy + amount)
	var applied := ultimate_energy - previous_energy
	ultimate_ready = ultimate_energy >= ultimate_energy_cost - 0.0001
	if ultimate_ready and ultimate_first_ready_time < 0.0:
		ultimate_first_ready_time = battle_time
	return applied


func can_begin_ultimate_targeting() -> bool:
	return (
		ultimate_enabled
		and is_deployed()
		and is_alive
		and ultimate_ready
		and not is_ultimate_targeting
	)


func begin_ultimate_targeting() -> bool:
	if not can_begin_ultimate_targeting():
		return false
	is_ultimate_targeting = true
	return true


func cancel_ultimate_targeting() -> bool:
	var was_targeting := is_ultimate_targeting
	is_ultimate_targeting = false
	return was_targeting


func consume_ultimate_energy() -> bool:
	if not ultimate_enabled or not ultimate_ready or not is_alive:
		return false
	ultimate_energy = maxf(0.0, ultimate_energy - ultimate_energy_cost)
	ultimate_ready = ultimate_energy >= ultimate_energy_cost - 0.0001
	is_ultimate_targeting = false
	ultimate_release_count += 1
	return true


func is_health_bar_visible() -> bool:
	return (
		not contact_combat_enabled
		or has_been_contacted
		or current_health < max_health
		or is_incapacitated
	)


func set_selected(selected: bool) -> void:
	show_action_range = selected and is_deployed()
	queue_redraw()


func set_action_range(new_action_range: float) -> void:
	action_range = maxf(0.0, new_action_range)
	queue_redraw()


func set_role_label_visible(visible: bool) -> void:
	role_label_visible = visible
	queue_redraw()


func get_role_label_color() -> Color:
	return (
		Color(0.58, 0.62, 0.70, 0.92)
		if not is_alive else Color(0.94, 0.97, 1.0, 1.0)
	)


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
	mark_contacted()
	var previous_health := current_health
	current_health = maxi(0, current_health - amount)
	var applied := previous_health - current_health
	total_damage_taken += applied
	hit_flash_remaining = 0.14
	hit_reaction_elapsed = 0.0
	if current_health <= 0:
		is_alive = false
		is_incapacitated = true
		incapacitation_count += 1
		current_target_id = &""
		clear_ultimate_event_throttle()
		character_died.emit(character_id)
	queue_redraw()
	return applied


func receive_healing(amount: int) -> int:
	if not is_alive or amount <= 0 or current_health >= max_health:
		return 0
	var previous_health := current_health
	current_health = mini(max_health, current_health + amount)
	var applied := current_health - previous_health
	if applied > 0 and ultimate_enabled:
		heal_flash_remaining = 0.18
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
	var completed_kill := bool(attack_target.is_dead)
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
		"completed_kill": completed_kill,
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


func is_position_in_action_range(target_position: Vector2) -> bool:
	return position.distance_to(target_position) <= action_range + 0.0001


func get_legal_enemy_candidates(active_enemies: Array) -> Array:
	var candidates: Array = []
	for enemy in active_enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.is_dead or enemy.settlement_completed:
			continue
		if role_id == &"guard":
			if bool(enemy.character_contact_combat_enabled):
				if StringName(enemy.contact_target_id) != character_id:
					continue
			elif (
				StringName(enemy.blocked_by_character_id) != character_id
				or not blocked_enemy_ids.has(StringName(enemy.runtime_id))
			):
				continue
		elif not is_position_in_action_range(enemy.position):
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
		"role_label_visible": role_label_visible,
		"role_label_rect": ROLE_LABEL_RECT,
		"role_label_color": get_role_label_color(),
		"deployed_slot_id": deployed_slot_id,
		"lane_id": lane_id,
		"max_health": max_health,
		"current_health": current_health,
		"action_interval": action_interval,
		"action_range": action_range,
		"current_cooldown": current_cooldown,
		"current_target_id": current_target_id,
		"is_alive": is_alive,
		"is_incapacitated": is_incapacitated,
		"action_count": action_count,
		"total_effect_amount": total_effect_amount,
		"total_damage_taken": total_damage_taken,
		"incapacitation_count": incapacitation_count,
		"attack_damage": attack_damage,
		"heal_amount": heal_amount,
		"block_capacity": block_capacity,
		"damage_source_type": damage_source_type,
		"blocked_enemy_ids": blocked_enemy_ids.duplicate(),
		"last_action_type": last_action_type,
		"contact_combat_enabled": contact_combat_enabled,
		"has_been_contacted": has_been_contacted,
		"hit_flash_remaining": hit_flash_remaining,
		"health_bar_visible": is_health_bar_visible(),
		"ultimate_enabled": ultimate_enabled,
		"ultimate_energy": ultimate_energy,
		"ultimate_energy_max": ultimate_energy_max,
		"ultimate_energy_cost": ultimate_energy_cost,
		"ultimate_ready": ultimate_ready,
		"is_ultimate_targeting": is_ultimate_targeting,
		"ultimate_release_count": ultimate_release_count,
		"ultimate_id": StringName(ultimate_definition.get("ultimate_id", &"")),
		"ultimate_first_ready_time": ultimate_first_ready_time,
		"ultimate_passive_energy_gained": ultimate_passive_energy_gained,
		"ultimate_event_energy_gained": ultimate_event_energy_gained,
		"ultimate_event_trigger_count": ultimate_event_trigger_count,
		"ultimate_event_trigger_counts": ultimate_event_trigger_counts.duplicate(true),
		"ultimate_event_throttled_count": ultimate_event_throttled_count,
		"ultimate_last_event_trigger_time": ultimate_last_event_trigger_time,
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
	var body_offset := Vector2.ZERO
	if contact_combat_enabled and hit_flash_remaining > 0.0:
		body_offset.x = sin(hit_reaction_elapsed * 90.0) * 2.5
	var visible_color := body_color if is_alive else Color(0.28, 0.30, 0.34, 1.0)
	if contact_combat_enabled and hit_flash_remaining > 0.0 and is_alive:
		visible_color = Color.WHITE
	elif ultimate_enabled and heal_flash_remaining > 0.0 and is_alive:
		visible_color = Color(0.52, 1.0, 0.72, 1.0)
	if contact_combat_enabled and is_incapacitated:
		visible_color.a = 0.46
	draw_circle(body_offset, BODY_RADIUS + 3.0, Color(0.02, 0.03, 0.05, 0.9))
	draw_circle(body_offset, BODY_RADIUS, visible_color)
	draw_circle(body_offset + Vector2(-5.0, -5.0), 3.5, Color(1.0, 1.0, 1.0, 0.8))
	var health_ratio := clampf(float(current_health) / float(max_health), 0.0, 1.0)
	var health_origin := Vector2(-HEALTH_BAR_WIDTH * 0.5, -27.0)
	if is_health_bar_visible():
		draw_rect(
			Rect2(health_origin, Vector2(HEALTH_BAR_WIDTH, 6.0)),
			Color(0.08, 0.10, 0.13, 0.95)
		)
		draw_rect(
			Rect2(health_origin, Vector2(HEALTH_BAR_WIDTH * health_ratio, 6.0)),
			Color(0.36, 0.94, 0.55, 1.0)
		)
	if role_label_visible:
		var role_label_color := get_role_label_color()
		var role_label_position := Vector2(ROLE_LABEL_RECT.position.x, 39.0)
		draw_string_outline(
			ThemeDB.fallback_font,
			role_label_position,
			display_name,
			HORIZONTAL_ALIGNMENT_CENTER,
			ROLE_LABEL_RECT.size.x,
			13,
			3,
			Color(0.02, 0.04, 0.07, 0.96)
		)
		draw_string(
			ThemeDB.fallback_font,
			role_label_position,
			display_name,
			HORIZONTAL_ALIGNMENT_CENTER,
			ROLE_LABEL_RECT.size.x,
			13,
			role_label_color
		)
	if contact_combat_enabled and is_incapacitated:
		draw_string(
			ThemeDB.fallback_font,
			Vector2(-22.0, 56.0 if role_label_visible else 38.0),
			"倒下",
			HORIZONTAL_ALIGNMENT_CENTER,
			44.0,
			12,
			Color(0.92, 0.94, 1.0, 0.92)
		)

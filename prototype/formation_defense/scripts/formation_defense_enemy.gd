extends Node2D

signal reached_entrance(
	enemy_id: StringName,
	route_id: StringName,
	leak_damage: int
)
signal enemy_died(enemy_id: StringName)
signal attacked_blocker(
	enemy_id: StringName,
	character_id: StringName,
	damage: int
)
signal damage_resolved(
	enemy_id: StringName,
	raw_damage: int,
	applied_damage: int,
	damage_source_type: StringName,
	damage_reduction: float
)

const BODY_RADIUS := 13.0
const HEALTH_BAR_WIDTH := 34.0

var runtime_id: StringName = &""
var route_id: StringName = &""
var spawn_point_id: StringName = &""
var route_group_id: StringName = &""
var formation_route_index := 0
var blocking_lane_id: StringName = &""
var spawn_sequence := 0
var monster_type: StringName = &"charge"
var display_name := ""
var type_marker: StringName = &""
var move_speed := 0.0
var leak_damage := 0
var route_progress := 0.0
var settlement_completed := false

var max_health := 1
var current_health := 1
var attack_damage := 0
var attack_interval := 1.0
var current_attack_cooldown := 0.0
var blocked_by_character_id: StringName = &""
var is_dead := false
var death_settlement_completed := false

var route_points := PackedVector2Array()
var segment_lengths := PackedFloat32Array()
var total_route_length := 0.0
var traveled_distance := 0.0
var base_route_position := Vector2.ZERO
var body_color := Color.WHITE
var hit_flash_remaining := 0.0

var formation_id: StringName = &""
var formation_level: StringName = &"SINGLE"
var formation_state: StringName = &"NONE"
var formation_progress := 0.0
var current_formation_effect: Dictionary = {}
var formation_speed_multiplier := 1.0
var formation_ranged_reduction := 0.0
var formation_player_damage_reduction := 0.0
var protection_ranged_reduction := 0.0
var formation_can_participate := true
var formation_zone_id: StringName = &""
var formation_zone_type: StringName = &""
var formation_slot_target := Vector2.ZERO
var formation_slot_active := false
var formation_steering_offset := Vector2.ZERO
var formation_temporary_speed_multiplier := 1.0
var last_damage_source_type: StringName = &"UNSPECIFIED"
var last_raw_damage := 0
var last_applied_damage := 0
var last_ranged_reduction := 0.0
var last_damage_reduction := 0.0
var last_damage_prevented := 0
var total_damage_prevented := 0
var command_is_target := false
var command_is_related := false
var command_is_hovered := false


func configure(
	new_runtime_id: StringName,
	new_route_id: StringName,
	new_spawn_sequence: int,
	new_move_speed: float,
	new_leak_damage: int,
	new_route_points: PackedVector2Array,
	new_body_color: Color,
	new_max_health: int,
	new_attack_damage: int,
	new_attack_interval: float,
	new_monster_type: StringName = &"charge",
	new_spawn_point_id: StringName = &"",
	new_route_group_id: StringName = &"",
	new_blocking_lane_id: StringName = &"",
	new_formation_route_index: int = 0,
	new_display_name: String = "",
	new_type_marker: StringName = &""
) -> void:
	runtime_id = new_runtime_id
	route_id = new_route_id
	spawn_point_id = new_spawn_point_id
	route_group_id = new_route_group_id
	formation_route_index = new_formation_route_index
	blocking_lane_id = (
		new_blocking_lane_id
		if new_blocking_lane_id != &"" else new_route_id
	)
	spawn_sequence = new_spawn_sequence
	monster_type = new_monster_type
	display_name = new_display_name if not new_display_name.is_empty() else String(monster_type)
	type_marker = new_type_marker
	move_speed = maxf(0.0, new_move_speed)
	leak_damage = maxi(0, new_leak_damage)
	body_color = new_body_color
	max_health = maxi(1, new_max_health)
	current_health = max_health
	attack_damage = maxi(0, new_attack_damage)
	attack_interval = maxf(0.05, new_attack_interval)
	current_attack_cooldown = 0.0
	blocked_by_character_id = &""
	is_dead = false
	death_settlement_completed = false
	settlement_completed = false
	route_progress = 0.0
	traveled_distance = 0.0
	hit_flash_remaining = 0.0
	formation_can_participate = true
	last_damage_source_type = &"UNSPECIFIED"
	last_raw_damage = 0
	last_applied_damage = 0
	last_ranged_reduction = 0.0
	last_damage_reduction = 0.0
	last_damage_prevented = 0
	total_damage_prevented = 0
	formation_steering_offset = Vector2.ZERO
	formation_slot_target = Vector2.ZERO
	formation_slot_active = false
	formation_temporary_speed_multiplier = 1.0
	formation_zone_id = &""
	formation_zone_type = &""
	reset_formation_state()
	set_command_visual(false, false, false)
	set_route_points(new_route_points, false)
	queue_redraw()


func set_route_points(
	new_route_points: PackedVector2Array,
	preserve_progress := true
) -> void:
	var previous_progress := route_progress if preserve_progress else 0.0
	route_points = new_route_points.duplicate()
	segment_lengths = PackedFloat32Array()
	total_route_length = 0.0
	for index in range(maxi(0, route_points.size() - 1)):
		var segment_length := route_points[index].distance_to(route_points[index + 1])
		segment_lengths.append(segment_length)
		total_route_length += segment_length
	traveled_distance = total_route_length * clampf(previous_progress, 0.0, 1.0)
	route_progress = (
		traveled_distance / total_route_length
		if total_route_length > 0.0 else 0.0
	)
	base_route_position = get_position_at_distance(traveled_distance)
	position = base_route_position + formation_steering_offset


func advance(delta: float) -> void:
	tick_visual(delta)
	if (
		settlement_completed
		or is_dead
		or blocked_by_character_id != &""
		or total_route_length <= 0.0
	):
		return
	traveled_distance = minf(
		total_route_length,
		traveled_distance + get_effective_move_speed() * maxf(0.0, delta)
	)
	route_progress = traveled_distance / total_route_length
	base_route_position = get_position_at_distance(traveled_distance)
	if not formation_slot_active:
		formation_steering_offset = formation_steering_offset.move_toward(
			Vector2.ZERO,
			65.0 * maxf(0.0, delta)
		)
	position = base_route_position + formation_steering_offset
	if traveled_distance < total_route_length:
		return
	settlement_completed = true
	reached_entrance.emit(runtime_id, route_id, leak_damage)


func advance_blocked_combat(delta: float) -> void:
	tick_visual(delta)
	if (
		settlement_completed
		or is_dead
		or blocked_by_character_id == &""
	):
		return
	current_attack_cooldown = maxf(
		0.0,
		current_attack_cooldown - maxf(0.0, delta)
	)
	if current_attack_cooldown > 0.0:
		return
	current_attack_cooldown = attack_interval
	attacked_blocker.emit(
		runtime_id,
		blocked_by_character_id,
		attack_damage
	)


func set_blocker(character_id: StringName) -> bool:
	if settlement_completed or is_dead or character_id == &"":
		return false
	if blocked_by_character_id == character_id:
		return true
	if blocked_by_character_id != &"":
		return false
	blocked_by_character_id = character_id
	current_attack_cooldown = attack_interval
	queue_redraw()
	return true


func clear_blocker(character_id: StringName = &"") -> void:
	if character_id != &"" and blocked_by_character_id != character_id:
		return
	blocked_by_character_id = &""
	current_attack_cooldown = 0.0
	queue_redraw()


func take_damage(
	amount: int,
	damage_source_type: StringName = &"UNSPECIFIED"
) -> int:
	if settlement_completed or is_dead or amount <= 0:
		return 0
	var reduction := get_effective_player_damage_reduction(damage_source_type)
	var reduced_amount := maxi(
		1,
		roundi(float(amount) * (1.0 - clampf(reduction, 0.0, 0.95)))
	)
	var previous_health := current_health
	current_health = maxi(0, current_health - reduced_amount)
	var applied := previous_health - current_health
	last_damage_source_type = damage_source_type
	last_raw_damage = amount
	last_applied_damage = applied
	last_ranged_reduction = reduction if damage_source_type == &"RANGED" else 0.0
	last_damage_reduction = reduction
	last_damage_prevented = maxi(0, mini(previous_health, amount) - applied)
	total_damage_prevented += last_damage_prevented
	hit_flash_remaining = 0.12
	queue_redraw()
	damage_resolved.emit(
		runtime_id,
		amount,
		applied,
		damage_source_type,
		reduction
	)
	if current_health <= 0:
		is_dead = true
		settlement_completed = true
		enemy_died.emit(runtime_id)
	return applied


func mark_death_settled() -> void:
	death_settlement_completed = true


func cancel() -> void:
	settlement_completed = true
	blocked_by_character_id = &""
	current_attack_cooldown = 0.0
	reset_formation_state()


func apply_formation_state(
	new_formation_id: StringName,
	new_formation_level: StringName,
	new_formation_state: StringName,
	new_formation_progress: float,
	effect: Dictionary
) -> void:
	formation_id = new_formation_id
	formation_level = new_formation_level
	formation_state = new_formation_state
	formation_progress = clampf(new_formation_progress, 0.0, 1.0)
	current_formation_effect = effect.duplicate(true)
	formation_speed_multiplier = maxf(
		0.0,
		float(current_formation_effect.get("move_speed_multiplier", 1.0))
	)
	formation_ranged_reduction = clampf(
		float(current_formation_effect.get("ranged_damage_reduction", 0.0)),
		0.0,
		0.95
	)
	formation_player_damage_reduction = clampf(
		float(current_formation_effect.get("player_damage_reduction", 0.0)),
		0.0,
		0.95
	)
	queue_redraw()


func reset_formation_state() -> void:
	formation_id = &""
	formation_level = &"SINGLE"
	formation_state = &"NONE"
	formation_progress = 0.0
	current_formation_effect.clear()
	formation_speed_multiplier = 1.0
	formation_ranged_reduction = 0.0
	formation_player_damage_reduction = 0.0
	protection_ranged_reduction = 0.0
	clear_formation_slot_target()
	queue_redraw()


func set_formation_zone(
	new_zone_id: StringName,
	new_zone_type: StringName
) -> void:
	formation_zone_id = new_zone_id
	formation_zone_type = new_zone_type


func apply_formation_slot_target(
	target_position: Vector2,
	delta: float,
	slot_move_speed: float,
	temporary_speed_multiplier: float
) -> float:
	formation_slot_active = true
	formation_slot_target = target_position
	formation_temporary_speed_multiplier = maxf(
		0.0,
		temporary_speed_multiplier
	)
	var target_offset := target_position - base_route_position
	var offset_delta := target_offset - formation_steering_offset
	var safe_delta := maxf(0.0, delta)
	var safe_speed := maxf(0.0, slot_move_speed)
	var x_speed := safe_speed if offset_delta.x <= 0.0 else safe_speed * 0.20
	formation_steering_offset.x = move_toward(
		formation_steering_offset.x,
		target_offset.x,
		x_speed * safe_delta
	)
	formation_steering_offset.y = move_toward(
		formation_steering_offset.y,
		target_offset.y,
		safe_speed * safe_delta
	)
	position = base_route_position + formation_steering_offset
	queue_redraw()
	return position.distance_to(target_position)


func clear_formation_slot_target() -> void:
	formation_slot_target = Vector2.ZERO
	formation_slot_active = false
	formation_temporary_speed_multiplier = 1.0


func set_debug_world_position(new_position: Vector2) -> void:
	base_route_position = get_position_at_distance(traveled_distance)
	formation_steering_offset = new_position - base_route_position
	position = new_position


func set_command_visual(is_target: bool, is_related: bool, is_hovered: bool) -> void:
	if command_is_target == is_target \
			and command_is_related == is_related \
			and command_is_hovered == is_hovered:
		return
	command_is_target = is_target
	command_is_related = is_related
	command_is_hovered = is_hovered
	queue_redraw()


func set_protection_ranged_reduction(reduction: float) -> void:
	protection_ranged_reduction = maxf(
		protection_ranged_reduction,
		clampf(reduction, 0.0, 0.95)
	) if reduction > 0.0 else 0.0
	queue_redraw()


func get_effective_move_speed() -> float:
	return (
		move_speed
		* formation_speed_multiplier
		* formation_temporary_speed_multiplier
	)


func get_effective_ranged_reduction() -> float:
	return maxf(formation_ranged_reduction, protection_ranged_reduction)


func get_effective_player_damage_reduction(damage_source_type: StringName) -> float:
	if damage_source_type not in [&"MELEE", &"RANGED"]:
		return 0.0
	var reduction := formation_player_damage_reduction
	if damage_source_type == &"RANGED":
		reduction = maxf(reduction, get_effective_ranged_reduction())
	return clampf(reduction, 0.0, 0.95)


func get_formation_shield_visual_strength() -> int:
	if formation_state != &"COMPLETE":
		return 0
	return maxi(0, int(current_formation_effect.get("shield_visual_strength", 0)))


func tick_visual(delta: float) -> void:
	if hit_flash_remaining <= 0.0:
		return
	hit_flash_remaining = maxf(0.0, hit_flash_remaining - maxf(0.0, delta))
	queue_redraw()


func get_position_at_distance(distance: float) -> Vector2:
	if route_points.is_empty():
		return Vector2.ZERO
	if route_points.size() == 1 or total_route_length <= 0.0:
		return route_points[0]
	var remaining := clampf(distance, 0.0, total_route_length)
	for index in range(segment_lengths.size()):
		var segment_length := segment_lengths[index]
		if remaining <= segment_length or index == segment_lengths.size() - 1:
			var segment_progress := (
				remaining / segment_length if segment_length > 0.0 else 1.0
			)
			return route_points[index].lerp(route_points[index + 1], segment_progress)
		remaining -= segment_length
	return route_points[route_points.size() - 1]


func get_runtime_snapshot() -> Dictionary:
	return {
		"runtime_id": runtime_id,
		"route_id": route_id,
		"spawn_point_id": spawn_point_id,
		"route_group_id": route_group_id,
		"formation_route_index": formation_route_index,
		"blocking_lane_id": blocking_lane_id,
		"spawn_sequence": spawn_sequence,
		"monster_type": monster_type,
		"enemy_profile_id": monster_type,
		"display_name": display_name,
		"type_marker": type_marker,
		"move_speed": move_speed,
		"effective_move_speed": get_effective_move_speed(),
		"leak_damage": leak_damage,
		"route_progress": route_progress,
		"settlement_completed": settlement_completed,
		"max_health": max_health,
		"current_health": current_health,
		"attack_damage": attack_damage,
		"attack_interval": attack_interval,
		"current_attack_cooldown": current_attack_cooldown,
		"blocked_by_character_id": blocked_by_character_id,
		"is_dead": is_dead,
		"death_settlement_completed": death_settlement_completed,
		"formation_id": formation_id,
		"formation_level": formation_level,
		"formation_state": formation_state,
		"formation_progress": formation_progress,
		"current_formation_effect": current_formation_effect.duplicate(true),
		"formation_speed_multiplier": formation_speed_multiplier,
		"formation_ranged_reduction": formation_ranged_reduction,
		"formation_player_damage_reduction": formation_player_damage_reduction,
		"protection_ranged_reduction": protection_ranged_reduction,
		"effective_ranged_reduction": get_effective_ranged_reduction(),
		"effective_melee_reduction": get_effective_player_damage_reduction(&"MELEE"),
		"effective_player_ranged_reduction": get_effective_player_damage_reduction(&"RANGED"),
		"formation_shield_visual_strength": get_formation_shield_visual_strength(),
		"formation_can_participate": formation_can_participate,
		"formation_zone_id": formation_zone_id,
		"formation_zone_type": formation_zone_type,
		"formation_slot_target": formation_slot_target,
		"formation_slot_active": formation_slot_active,
		"formation_steering_offset": formation_steering_offset,
		"formation_temporary_speed_multiplier":
			formation_temporary_speed_multiplier,
		"base_route_position": base_route_position,
		"last_damage_source_type": last_damage_source_type,
		"last_raw_damage": last_raw_damage,
		"last_applied_damage": last_applied_damage,
		"last_ranged_reduction": last_ranged_reduction,
		"last_damage_reduction": last_damage_reduction,
		"last_damage_prevented": last_damage_prevented,
		"total_damage_prevented": total_damage_prevented,
		"position": position,
		"command_is_target": command_is_target,
		"command_is_related": command_is_related,
		"command_is_hovered": command_is_hovered,
	}


func _draw() -> void:
	var shield_visual_strength := get_formation_shield_visual_strength()
	if shield_visual_strength > 0:
		var shield_color := Color(0.48, 0.82, 1.0, 0.72)
		draw_arc(Vector2.ZERO, BODY_RADIUS + 5.0, 0.0, TAU, 32, shield_color, 2.0, true)
		if shield_visual_strength >= 2:
			draw_arc(Vector2.ZERO, BODY_RADIUS + 8.0, 0.0, TAU, 32, Color(shield_color, 0.56), 2.0, true)
	if command_is_related:
		draw_arc(Vector2.ZERO, BODY_RADIUS + 10.0, 0.0, TAU, 32, Color(1.0, 0.68, 0.20, 0.72), 2.0, true)
	if command_is_target:
		draw_arc(Vector2.ZERO, BODY_RADIUS + 12.0, 0.0, TAU, 32, Color(1.0, 0.16, 0.18, 1.0), 3.0, true)
		draw_line(Vector2(-20.0, 0.0), Vector2(-8.0, 0.0), Color(1.0, 0.16, 0.18), 2.0)
		draw_line(Vector2(8.0, 0.0), Vector2(20.0, 0.0), Color(1.0, 0.16, 0.18), 2.0)
		draw_line(Vector2(0.0, -20.0), Vector2(0.0, -8.0), Color(1.0, 0.16, 0.18), 2.0)
		draw_line(Vector2(0.0, 8.0), Vector2(0.0, 20.0), Color(1.0, 0.16, 0.18), 2.0)
	if command_is_hovered:
		draw_arc(Vector2.ZERO, BODY_RADIUS + 6.0, 0.0, TAU, 32, Color(1.0, 0.96, 0.58, 0.95), 2.0, true)
	var visible_color := (
		Color.WHITE
		if hit_flash_remaining > 0.0
		else body_color
	)
	draw_circle(Vector2.ZERO, BODY_RADIUS + 3.0, Color(0.03, 0.05, 0.08, 0.85))
	draw_circle(Vector2.ZERO, BODY_RADIUS, visible_color)
	if type_marker == &"guard_shield":
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(-6.0, -34.0), Vector2(6.0, -34.0),
				Vector2(7.0, -29.0), Vector2(0.0, -23.0), Vector2(-7.0, -29.0),
			]),
			Color(0.72, 0.88, 1.0, 0.96)
		)
		draw_polyline(
			PackedVector2Array([
				Vector2(-6.0, -34.0), Vector2(6.0, -34.0),
				Vector2(7.0, -29.0), Vector2(0.0, -23.0),
				Vector2(-7.0, -29.0), Vector2(-6.0, -34.0),
			]),
			Color(0.18, 0.34, 0.50, 1.0),
			1.5,
			true
		)
	elif monster_type == &"charge":
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(-2.0, -8.0),
				Vector2(10.0, 0.0),
				Vector2(-2.0, 8.0),
			]),
			Color(1.0, 0.84, 0.52, 0.92)
		)
	else:
		draw_rect(
			Rect2(Vector2(-7.0, -8.0), Vector2(14.0, 16.0)),
			Color(0.72, 0.91, 1.0, 0.9),
			false,
			2.0
		)
	draw_circle(Vector2(-4.0, -4.0), 3.0, Color(1.0, 1.0, 1.0, 0.78))
	if blocked_by_character_id != &"":
		draw_arc(
			Vector2.ZERO,
			BODY_RADIUS + 6.0,
			0.0,
			TAU,
			24,
			Color(1.0, 0.72, 0.26, 0.9),
			2.0,
			true
		)
	var health_ratio := clampf(float(current_health) / float(max_health), 0.0, 1.0)
	var health_origin := Vector2(-HEALTH_BAR_WIDTH * 0.5, -22.0)
	draw_rect(
		Rect2(health_origin, Vector2(HEALTH_BAR_WIDTH, 5.0)),
		Color(0.08, 0.10, 0.13, 0.95)
	)
	draw_rect(
		Rect2(health_origin, Vector2(HEALTH_BAR_WIDTH * health_ratio, 5.0)),
		Color(0.94, 0.34, 0.38, 1.0)
	)
	if formation_state != &"NONE":
		var formation_text := (
			"%s %d%%" % [String(formation_level), int(round(formation_progress * 100.0))]
			if formation_state != &"COMPLETE"
			else String(formation_level)
		)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(-22.0, 34.0),
			formation_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			44.0,
			12,
			Color(1.0, 0.92, 0.62, 0.92)
		)

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

const BODY_RADIUS := 13.0
const HEALTH_BAR_WIDTH := 34.0

var runtime_id: StringName = &""
var route_id: StringName = &""
var spawn_sequence := 0
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
var body_color := Color.WHITE
var hit_flash_remaining := 0.0


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
	new_attack_interval: float
) -> void:
	runtime_id = new_runtime_id
	route_id = new_route_id
	spawn_sequence = new_spawn_sequence
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
	position = get_position_at_distance(traveled_distance)


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
		traveled_distance + move_speed * maxf(0.0, delta)
	)
	route_progress = traveled_distance / total_route_length
	position = get_position_at_distance(traveled_distance)
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


func take_damage(amount: int) -> int:
	if settlement_completed or is_dead or amount <= 0:
		return 0
	var previous_health := current_health
	current_health = maxi(0, current_health - amount)
	var applied := previous_health - current_health
	hit_flash_remaining = 0.12
	queue_redraw()
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
		"spawn_sequence": spawn_sequence,
		"move_speed": move_speed,
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
		"position": position,
	}


func _draw() -> void:
	var visible_color := (
		Color.WHITE
		if hit_flash_remaining > 0.0
		else body_color
	)
	draw_circle(Vector2.ZERO, BODY_RADIUS + 3.0, Color(0.03, 0.05, 0.08, 0.85))
	draw_circle(Vector2.ZERO, BODY_RADIUS, visible_color)
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

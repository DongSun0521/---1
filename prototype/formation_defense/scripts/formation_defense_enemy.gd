extends Node2D

signal reached_entrance(
	enemy_id: StringName,
	route_id: StringName,
	leak_damage: int
)

const BODY_RADIUS := 13.0

var runtime_id: StringName = &""
var route_id: StringName = &""
var move_speed := 0.0
var leak_damage := 0
var route_progress := 0.0
var settlement_completed := false

var route_points := PackedVector2Array()
var segment_lengths := PackedFloat32Array()
var total_route_length := 0.0
var traveled_distance := 0.0
var body_color := Color.WHITE


func configure(
	new_runtime_id: StringName,
	new_route_id: StringName,
	new_move_speed: float,
	new_leak_damage: int,
	new_route_points: PackedVector2Array,
	new_body_color: Color
) -> void:
	runtime_id = new_runtime_id
	route_id = new_route_id
	move_speed = maxf(0.0, new_move_speed)
	leak_damage = maxi(0, new_leak_damage)
	body_color = new_body_color
	settlement_completed = false
	route_progress = 0.0
	traveled_distance = 0.0
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
	if settlement_completed or total_route_length <= 0.0:
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


func cancel() -> void:
	settlement_completed = true


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
		"move_speed": move_speed,
		"leak_damage": leak_damage,
		"route_progress": route_progress,
		"settlement_completed": settlement_completed,
		"position": position,
	}


func _draw() -> void:
	draw_circle(Vector2.ZERO, BODY_RADIUS + 3.0, Color(0.03, 0.05, 0.08, 0.85))
	draw_circle(Vector2.ZERO, BODY_RADIUS, body_color)
	draw_circle(Vector2(-4.0, -4.0), 3.0, Color(1.0, 1.0, 1.0, 0.78))

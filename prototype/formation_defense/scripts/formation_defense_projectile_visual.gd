extends Node2D

const KIND_MELEE := &"MELEE_SLASH"
const KIND_ARROW := &"RANGED_ARROW"
const KIND_MAGIC := &"MAGIC_ORB"

var attacker_runtime_id: StringName = &""
var target_runtime_id: StringName = &""
var attack_sequence_id := 0
var visual_kind: StringName = KIND_ARROW
var start_position := Vector2.ZERO
var end_position := Vector2.ZERO
var elapsed := 0.0
var duration := 0.2
var completed := false


func configure(
	new_attacker_runtime_id: StringName,
	new_target_runtime_id: StringName,
	new_attack_sequence_id: int,
	new_visual_kind: StringName,
	new_start_position: Vector2,
	new_end_position: Vector2,
	logic_travel_distance := -1.0
) -> void:
	attacker_runtime_id = new_attacker_runtime_id
	target_runtime_id = new_target_runtime_id
	attack_sequence_id = new_attack_sequence_id
	visual_kind = new_visual_kind
	start_position = new_start_position
	end_position = new_end_position
	elapsed = 0.0
	completed = false
	if visual_kind == KIND_MELEE:
		duration = 0.10
		position = Vector2.ZERO
	else:
		var travel_distance := (
			logic_travel_distance
			if logic_travel_distance >= 0.0
			else start_position.distance_to(end_position)
		)
		duration = clampf(travel_distance / 900.0, 0.15, 0.35)
		position = start_position
		rotation = (end_position - start_position).angle()
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if completed:
		return
	elapsed += maxf(0.0, delta)
	var progress := clampf(elapsed / maxf(duration, 0.001), 0.0, 1.0)
	if visual_kind != KIND_MELEE:
		position = start_position.lerp(end_position, ease(progress, -0.35))
	queue_redraw()
	if elapsed >= duration:
		completed = true
		set_process(false)
		queue_free()


func get_debug_snapshot() -> Dictionary:
	return {
		"attacker_runtime_id": attacker_runtime_id,
		"target_runtime_id": target_runtime_id,
		"attack_sequence_id": attack_sequence_id,
		"visual_kind": visual_kind,
		"start_position": start_position,
		"end_position": end_position,
		"duration": duration,
		"elapsed": elapsed,
		"completed": completed,
	}


func _draw() -> void:
	var remaining_alpha := clampf(1.0 - elapsed / maxf(duration, 0.001), 0.0, 1.0)
	if visual_kind == KIND_MELEE:
		var direction := (end_position - start_position).normalized()
		var perpendicular := direction.orthogonal()
		var slash_start := start_position + direction * 10.0 - perpendicular * 9.0
		var slash_end := end_position - direction * 7.0 + perpendicular * 9.0
		draw_line(slash_start, slash_end, Color(1.0, 0.80, 0.78, remaining_alpha), 4.0, true)
		draw_line(slash_start, slash_end, Color(1.0, 1.0, 1.0, remaining_alpha), 1.5, true)
		return
	if visual_kind == KIND_MAGIC:
		draw_line(Vector2(-18.0, 0.0), Vector2(-4.0, 0.0), Color(0.40, 0.35, 1.0, remaining_alpha * 0.65), 5.0, true)
		draw_circle(Vector2.ZERO, 6.0, Color(0.42, 0.48, 1.0, remaining_alpha))
		draw_circle(Vector2(-1.5, -1.5), 2.5, Color(0.88, 0.90, 1.0, remaining_alpha))
		return
	draw_line(Vector2(-20.0, 0.0), Vector2(-5.0, 0.0), Color(1.0, 0.48, 0.12, remaining_alpha * 0.72), 3.0, true)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-6.0, -2.2),
			Vector2(8.0, 0.0),
			Vector2(-6.0, 2.2),
		]),
		Color(1.0, 0.94, 0.66, remaining_alpha)
	)

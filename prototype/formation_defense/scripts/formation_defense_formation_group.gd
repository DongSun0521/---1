extends RefCounted

var formation_id: StringName = &""
var monster_type: StringName = &""
var lane_id: StringName = &""
var route_group_id: StringName = &""
var formation_zone_id: StringName = &""
var formation_zone_type: StringName = &""
var formation_level: StringName = &"SINGLE"
var formation_state: StringName = &"NONE"
var member_ids: Array[StringName] = []
var source_a_ids: Array[StringName] = []
var source_a_member_sets: Array = []
var source_a_anchor_route_indices: Array[int] = []
var slot_assignments: Dictionary = {}
var meeting_center := Vector2.ZERO
var locked_center := Vector2.ZERO
var pair_mode: StringName = &""
var formation_anchor_route_index := -1
var initial_slot_error := 0.0
var lock_runtime_elapsed := 0.0
var completion_elapsed := 0.0
var elapsed := 0.0
var required_duration := 0.0
var meet_timeout := 0.0
var time_progress := 0.0
var position_progress := 0.0
var formation_progress := 0.0
var current_effect: Dictionary = {}
var is_valid := true
var is_locked := false
var control_resistance_available := false
var control_resistance_consumed := false
var feedback_text := ""
var feedback_remaining := 0.0


func configure(
	new_formation_id: StringName,
	new_monster_type: StringName,
	new_lane_id: StringName,
	new_formation_level: StringName,
	new_formation_state: StringName,
	new_member_ids: Array[StringName],
	new_required_duration: float,
	new_effect: Dictionary = {}
) -> void:
	formation_id = new_formation_id
	monster_type = new_monster_type
	lane_id = new_lane_id
	formation_level = new_formation_level
	formation_state = new_formation_state
	member_ids = new_member_ids.duplicate()
	required_duration = maxf(0.0, new_required_duration)
	current_effect = new_effect.duplicate(true)
	elapsed = 0.0
	completion_elapsed = 0.0
	initial_slot_error = 0.0
	lock_runtime_elapsed = 0.0
	formation_anchor_route_index = -1
	source_a_anchor_route_indices.clear()
	formation_progress = (
		1.0 if formation_state == &"COMPLETE" else 0.0
	)
	time_progress = formation_progress
	position_progress = formation_progress
	is_valid = true
	is_locked = formation_state != &"COMPLETE"
	control_resistance_available = false
	control_resistance_consumed = false
	feedback_text = ""
	feedback_remaining = 0.0


func set_source_a_groups(
	first_id: StringName,
	first_members: Array[StringName],
	second_id: StringName,
	second_members: Array[StringName],
	first_anchor_route_index: int = -1,
	second_anchor_route_index: int = -1
) -> void:
	source_a_ids = [first_id, second_id]
	source_a_member_sets = [
		first_members.duplicate(),
		second_members.duplicate(),
	]
	source_a_anchor_route_indices = [
		first_anchor_route_index,
		second_anchor_route_index,
	]


func configure_lock(
	new_route_group_id: StringName,
	new_zone_id: StringName,
	new_zone_type: StringName,
	new_center: Vector2,
	new_slot_assignments: Dictionary,
	new_meet_timeout: float,
	new_pair_mode: StringName = &""
) -> void:
	route_group_id = new_route_group_id
	formation_zone_id = new_zone_id
	formation_zone_type = new_zone_type
	meeting_center = new_center
	locked_center = new_center
	slot_assignments = new_slot_assignments.duplicate(true)
	meet_timeout = maxf(required_duration, new_meet_timeout)
	pair_mode = new_pair_mode
	is_locked = true


func advance_progress(delta: float, new_position_progress := 1.0) -> bool:
	if not is_valid or formation_state == &"COMPLETE":
		return false
	elapsed += maxf(0.0, delta)
	time_progress = (
		clampf(elapsed / required_duration, 0.0, 1.0)
		if required_duration > 0.0 else 1.0
	)
	position_progress = clampf(new_position_progress, 0.0, 1.0)
	formation_progress = minf(time_progress, position_progress)
	return time_progress >= 1.0 and position_progress >= 1.0


func has_timed_out() -> bool:
	return (
		is_valid
		and formation_state != &"COMPLETE"
		and meet_timeout > 0.0
		and elapsed >= meet_timeout
	)


func complete(new_effect: Dictionary) -> void:
	formation_state = &"COMPLETE"
	completion_elapsed = elapsed
	time_progress = 1.0
	position_progress = 1.0
	formation_progress = 1.0
	current_effect = new_effect.duplicate(true)
	is_locked = false


func show_feedback(text: String, duration: float) -> void:
	feedback_text = text
	feedback_remaining = maxf(0.0, duration)


func tick_feedback(delta: float) -> void:
	if feedback_remaining <= 0.0:
		return
	feedback_remaining = maxf(0.0, feedback_remaining - maxf(0.0, delta))
	if feedback_remaining <= 0.0:
		feedback_text = ""


func invalidate() -> void:
	is_valid = false
	is_locked = false
	slot_assignments.clear()
	feedback_text = ""
	feedback_remaining = 0.0


func get_snapshot() -> Dictionary:
	var display_state: StringName = &"SEARCHING"
	if formation_state in [&"FORMING_A_LOCKED", &"FORMING_B_LOCKED"]:
		display_state = &"APPROACHING"
	elif formation_state == &"COMPLETE":
		display_state = &"FORMED_B" if formation_level == &"B" else &"FORMED_A"
	var copied_source_members: Array = []
	for source_members: Array in source_a_member_sets:
		copied_source_members.append(source_members.duplicate())
	return {
		"formation_id": formation_id,
		"monster_type": monster_type,
		"lane_id": lane_id,
		"route_group_id": route_group_id,
		"formation_zone_id": formation_zone_id,
		"formation_zone_type": formation_zone_type,
		"formation_level": formation_level,
		"formation_state": formation_state,
		"display_state": display_state,
		"formal_visual_visible": formation_state == &"COMPLETE",
		"member_ids": member_ids.duplicate(),
		"source_a_ids": source_a_ids.duplicate(),
		"source_a_member_sets": copied_source_members,
		"source_a_anchor_route_indices":
			source_a_anchor_route_indices.duplicate(),
		"elapsed": elapsed,
		"completion_elapsed": completion_elapsed,
		"required_duration": required_duration,
		"meet_timeout": meet_timeout,
		"time_progress": time_progress,
		"position_progress": position_progress,
		"formation_progress": formation_progress,
		"slot_assignments": slot_assignments.duplicate(true),
		"meeting_center": meeting_center,
		"locked_center": locked_center,
		"pair_mode": pair_mode,
		"formation_anchor_route_index": formation_anchor_route_index,
		"initial_slot_error": initial_slot_error,
		"lock_runtime_elapsed": lock_runtime_elapsed,
		"current_effect": current_effect.duplicate(true),
		"is_valid": is_valid,
		"is_locked": is_locked,
		"control_resistance_available": control_resistance_available,
		"control_resistance_consumed": control_resistance_consumed,
		"feedback_text": feedback_text,
		"feedback_remaining": feedback_remaining,
	}

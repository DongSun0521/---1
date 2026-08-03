extends Node2D

const PrototypeConfig := preload(
	"res://prototype/formation_defense/data/formation_defense_config.gd"
)
const PrototypeFormationGroup := preload(
	"res://prototype/formation_defense/scripts/formation_defense_formation_group.gd"
)

var formations_enabled := false
var groups: Dictionary = {}
var member_to_group: Dictionary = {}
var next_formation_sequence := 1
var run_sequence := 0
var runtime_elapsed := 0.0
var last_active_enemies: Dictionary = {}
var a_pair_neighbor_route_span := PrototypeConfig.A_PAIR_NEIGHBOR_ROUTE_SPAN
var b_pair_neighbor_route_span := PrototypeConfig.B_PAIR_NEIGHBOR_ROUTE_SPAN

var completed_a_count := 0
var completed_b_count := 0
var interrupted_count := 0
var downgrade_count := 0
var control_resistance_consumed_count := 0
var completed_a_by_type: Dictionary = {}
var completed_b_by_type: Dictionary = {}
var protected_target_ids_seen: Dictionary = {}
var current_protected_target_count := 0
var max_protected_target_count := 0
var meet_timeout_count := 0
var candidate_lock_count := 0
var cross_route_a_count := 0
var completed_a_route_spans: Dictionary = {}
var completed_a_pair_modes: Dictionary = {}
var completed_a_observations: Array[Dictionary] = []
var completed_b_observations: Array[Dictionary] = []


func _ready() -> void:
	z_index = 4
	queue_redraw()


func reset_runtime(enabled: bool, new_run_sequence := 0) -> void:
	clear_all_formations(last_active_enemies)
	formations_enabled = enabled
	run_sequence = new_run_sequence
	next_formation_sequence = 1
	runtime_elapsed = 0.0
	a_pair_neighbor_route_span = maxi(
		0,
		PrototypeConfig.A_PAIR_NEIGHBOR_ROUTE_SPAN
	)
	b_pair_neighbor_route_span = maxi(
		0,
		PrototypeConfig.B_PAIR_NEIGHBOR_ROUTE_SPAN
	)
	completed_a_count = 0
	completed_b_count = 0
	interrupted_count = 0
	downgrade_count = 0
	control_resistance_consumed_count = 0
	completed_a_by_type.clear()
	completed_b_by_type.clear()
	protected_target_ids_seen.clear()
	current_protected_target_count = 0
	max_protected_target_count = 0
	meet_timeout_count = 0
	candidate_lock_count = 0
	cross_route_a_count = 0
	completed_a_route_spans.clear()
	completed_a_pair_modes.clear()
	completed_a_observations.clear()
	completed_b_observations.clear()
	queue_redraw()


func set_neighbor_route_spans(a_span: int, b_span: int) -> void:
	a_pair_neighbor_route_span = maxi(0, a_span)
	b_pair_neighbor_route_span = maxi(0, b_span)


func update_formations(delta: float, active_enemies: Dictionary) -> void:
	last_active_enemies = active_enemies
	if not formations_enabled:
		clear_enemy_zone_states(active_enemies)
		reset_protection_effects(active_enemies)
		queue_redraw()
		return
	var safe_delta := maxf(0.0, delta)
	runtime_elapsed += safe_delta
	refresh_enemy_zone_states(active_enemies)
	var group_ids := get_sorted_group_ids()
	for formation_id: StringName in group_ids:
		var group = groups.get(formation_id)
		if group == null or not group.is_valid:
			continue
		group.tick_feedback(safe_delta)
		if group.formation_state == PrototypeConfig.FORMATION_STATE_FORMING_A:
			update_forming_a(group, safe_delta, active_enemies)
		elif group.formation_state == PrototypeConfig.FORMATION_STATE_FORMING_B:
			update_forming_b(group, safe_delta, active_enemies)
		elif group.formation_state == PrototypeConfig.FORMATION_STATE_COMPLETE:
			maintain_complete_group_slots(group, safe_delta, active_enemies)
	start_b_candidates(active_enemies)
	start_a_candidates(active_enemies)
	refresh_group_member_states(active_enemies)
	refresh_shield_protection(active_enemies)
	queue_redraw()


func update_forming_a(group, delta: float, active_enemies: Dictionary) -> void:
	if not is_group_membership_valid(group, active_enemies, 2):
		cancel_group_to_singles(group, active_enemies, true)
		return
	var first = active_enemies[group.member_ids[0]]
	var second = active_enemies[group.member_ids[1]]
	if (
		first.monster_type != second.monster_type
		or not PrototypeConfig.are_route_groups_compatible(
			first.route_group_id,
			second.route_group_id
		)
	):
		cancel_group_to_singles(group, active_enemies, true)
		return
	var position_progress := apply_group_steering(
		group,
		delta,
		active_enemies,
		true
	)
	if group.advance_progress(delta, position_progress):
		complete_a_group(group, active_enemies, true)
	elif group.has_timed_out():
		meet_timeout_count += 1
		cancel_group_to_singles(group, active_enemies, true)


func update_forming_b(group, delta: float, active_enemies: Dictionary) -> void:
	if not is_group_membership_valid(group, active_enemies, 4):
		cancel_forming_b(group, active_enemies, true)
		return
	if group.source_a_member_sets.size() != 2:
		cancel_forming_b(group, active_enemies, true)
		return
	var position_progress := apply_group_steering(
		group,
		delta,
		active_enemies,
		true
	)
	if group.advance_progress(delta, position_progress):
		complete_b_group(group, active_enemies)
	elif group.has_timed_out():
		meet_timeout_count += 1
		cancel_forming_b(group, active_enemies, true)


func start_a_candidates(active_enemies: Dictionary) -> void:
	var singles := get_sorted_single_enemies(active_enemies)
	var claimed: Dictionary = {}
	for enemy in singles:
		if (
			claimed.has(enemy.runtime_id)
			or enemy.formation_id != &""
			or enemy.formation_zone_type != PrototypeConfig.FORMATION_ZONE_A
		):
			continue
		var best_candidate = null
		var best_distance_score := INF
		for candidate in singles:
			if candidate == enemy:
				continue
			if (
				claimed.has(candidate.runtime_id)
				or candidate.formation_id != &""
				or candidate.monster_type != enemy.monster_type
				or candidate.formation_zone_id != enemy.formation_zone_id
				or candidate.formation_zone_type
					!= PrototypeConfig.FORMATION_ZONE_A
				or not PrototypeConfig.are_route_groups_compatible(
					enemy.route_group_id,
					candidate.route_group_id
				)
				or not PrototypeConfig.is_neighbor_route_span_allowed(
					enemy.formation_route_index,
					candidate.formation_route_index,
					a_pair_neighbor_route_span
				)
			):
				continue
			var distance_score := PrototypeConfig.normalized_ellipse_distance(
				enemy.position,
				candidate.position,
				PrototypeConfig.A_PAIR_RADIUS_X,
				PrototypeConfig.A_PAIR_RADIUS_Y
			)
			if distance_score > 1.0:
				continue
			if (
				best_candidate == null
				or distance_score < best_distance_score - 0.0001
				or (
					is_equal_approx(distance_score, best_distance_score)
					and enemy_node_less(candidate, best_candidate)
				)
			):
				best_candidate = candidate
				best_distance_score = distance_score
		if best_candidate == null:
			continue
		claimed[enemy.runtime_id] = true
		claimed[best_candidate.runtime_id] = true
		create_forming_a(enemy, best_candidate, active_enemies)


func start_b_candidates(active_enemies: Dictionary) -> void:
	var a_groups := get_sorted_complete_a_groups(active_enemies)
	var claimed: Dictionary = {}
	for group in a_groups:
		if claimed.has(group.formation_id) or not groups.has(group.formation_id):
			continue
		var group_center: Variant = get_group_center(group, active_enemies)
		if group_center == null:
			continue
		var group_zone := get_zone_for_position(
			group_center,
			group.route_group_id
		)
		if (
			StringName(group_zone.get("zone_type", &""))
				!= PrototypeConfig.FORMATION_ZONE_B
		):
			continue
		var best_candidate = null
		var best_distance_score := INF
		for candidate in a_groups:
			if candidate == group:
				continue
			if (
				claimed.has(candidate.formation_id)
				or not groups.has(candidate.formation_id)
				or candidate.monster_type != group.monster_type
				or group.formation_anchor_route_index < 0
				or candidate.formation_anchor_route_index < 0
				or not PrototypeConfig.are_route_groups_compatible(
					group.route_group_id,
					candidate.route_group_id
				)
				or not PrototypeConfig.is_neighbor_route_span_allowed(
					group.formation_anchor_route_index,
					candidate.formation_anchor_route_index,
					b_pair_neighbor_route_span
				)
			):
				continue
			var candidate_center: Variant = get_group_center(
				candidate,
				active_enemies
			)
			if candidate_center == null:
				continue
			var candidate_zone := get_zone_for_position(
				candidate_center,
				candidate.route_group_id
			)
			if (
				StringName(candidate_zone.get("zone_id", &""))
					!= StringName(group_zone.get("zone_id", &""))
				or StringName(candidate_zone.get("zone_type", &""))
					!= PrototypeConfig.FORMATION_ZONE_B
			):
				continue
			var distance_score := PrototypeConfig.normalized_ellipse_distance(
				group_center,
				candidate_center,
				PrototypeConfig.B_PAIR_RADIUS_X,
				PrototypeConfig.B_PAIR_RADIUS_Y
			)
			if distance_score > 1.0:
				continue
			if (
				best_candidate == null
				or distance_score < best_distance_score - 0.0001
				or (
					is_equal_approx(distance_score, best_distance_score)
					and formation_group_less(candidate, best_candidate, active_enemies)
				)
			):
				best_candidate = candidate
				best_distance_score = distance_score
		if best_candidate == null:
			continue
		claimed[group.formation_id] = true
		claimed[best_candidate.formation_id] = true
		create_forming_b(group, best_candidate, active_enemies)


func create_forming_a(first, second, active_enemies: Dictionary):
	var members: Array[StringName] = [
		StringName(first.runtime_id),
		StringName(second.runtime_id),
	]
	members = sort_members_for_a_slots(members, active_enemies)
	var center: Vector2 = (
		(first.position + second.position) * 0.5
	)
	var slot_assignments := {
		members[0]: Vector2(0.0, -PrototypeConfig.A_SLOT_GAP_Y * 0.5),
		members[1]: Vector2(0.0, PrototypeConfig.A_SLOT_GAP_Y * 0.5),
	}
	var group = PrototypeFormationGroup.new()
	group.configure(
		make_formation_id(&"A"),
		StringName(first.monster_type),
		StringName(first.blocking_lane_id),
		PrototypeConfig.FORMATION_LEVEL_A,
		PrototypeConfig.FORMATION_STATE_FORMING_A,
		members,
		PrototypeConfig.FORMATION_A_DURATION
	)
	group.configure_lock(
		StringName(first.route_group_id),
		StringName(first.formation_zone_id),
		StringName(first.formation_zone_type),
		center,
		slot_assignments,
		PrototypeConfig.FORMATION_MEET_TIMEOUT,
		classify_a_pair(first.position, second.position)
	)
	group.initial_slot_error = get_maximum_slot_error(
		center,
		slot_assignments,
		active_enemies
	)
	group.lock_runtime_elapsed = runtime_elapsed
	register_group(group, active_enemies)
	candidate_lock_count += 1
	return group


func create_forming_b(first_a, second_a, active_enemies: Dictionary):
	var first_members: Array[StringName] = first_a.member_ids.duplicate()
	var second_members: Array[StringName] = second_a.member_ids.duplicate()
	var all_members: Array[StringName] = []
	all_members.append_array(first_members)
	all_members.append_array(second_members)
	all_members = sort_members_for_b_slots(all_members, active_enemies)
	var first_id := StringName(first_a.formation_id)
	var second_id := StringName(second_a.formation_id)
	var first_anchor_route_index := int(
		first_a.formation_anchor_route_index
	)
	var second_anchor_route_index := int(
		second_a.formation_anchor_route_index
	)
	var center: Variant = get_members_center(all_members, active_enemies)
	if center == null:
		return null
	var half_x := PrototypeConfig.B_SLOT_GAP_X * 0.5
	var half_y := PrototypeConfig.B_SLOT_GAP_Y * 0.5
	var slot_assignments := {
		all_members[0]: Vector2(-half_x, -half_y),
		all_members[1]: Vector2(half_x, -half_y),
		all_members[2]: Vector2(-half_x, half_y),
		all_members[3]: Vector2(half_x, half_y),
	}
	var zone := get_zone_for_position(center, first_a.route_group_id)
	unregister_group(first_a, false, active_enemies)
	unregister_group(second_a, false, active_enemies)
	var group = PrototypeFormationGroup.new()
	group.configure(
		make_formation_id(&"B"),
		StringName(first_a.monster_type),
		StringName(first_a.lane_id),
		PrototypeConfig.FORMATION_LEVEL_B,
		PrototypeConfig.FORMATION_STATE_FORMING_B,
		all_members,
		PrototypeConfig.FORMATION_B_DURATION,
		PrototypeConfig.get_formation_effect(
			StringName(first_a.monster_type),
			PrototypeConfig.FORMATION_LEVEL_A
		)
	)
	group.configure_lock(
		StringName(first_a.route_group_id),
		StringName(zone.get("zone_id", &"")),
		StringName(zone.get("zone_type", &"")),
		center,
		slot_assignments,
		PrototypeConfig.FORMATION_MEET_TIMEOUT
	)
	group.initial_slot_error = get_maximum_slot_error(
		center,
		slot_assignments,
		active_enemies
	)
	group.lock_runtime_elapsed = runtime_elapsed
	group.set_source_a_groups(
		first_id,
		first_members,
		second_id,
		second_members,
		first_anchor_route_index,
		second_anchor_route_index
	)
	register_group(group, active_enemies)
	candidate_lock_count += 1
	return group


func complete_a_group(group, active_enemies: Dictionary, count_completion: bool) -> void:
	group.complete(
		PrototypeConfig.get_formation_effect(
			group.monster_type,
			PrototypeConfig.FORMATION_LEVEL_A
		)
	)
	var center: Variant = get_group_center(group, active_enemies)
	if group.formation_anchor_route_index < 0 and center != null:
		group.formation_anchor_route_index = (
			PrototypeConfig.get_nearest_formation_route_index(
				center,
				group.route_group_id,
				get_battlefield_size()
			)
		)
	if count_completion:
		completed_a_count += 1
		completed_a_pair_modes[group.pair_mode] = int(
			completed_a_pair_modes.get(group.pair_mode, 0)
		) + 1
		var route_span := 0
		if group.member_ids.size() == 2:
			var first = active_enemies.get(group.member_ids[0])
			var second = active_enemies.get(group.member_ids[1])
			if is_valid_enemy(first) and is_valid_enemy(second):
				route_span = abs(
					int(first.formation_route_index)
						- int(second.formation_route_index)
				)
			if (
				is_valid_enemy(first)
				and is_valid_enemy(second)
				and first.route_id != second.route_id
			):
				cross_route_a_count += 1
		completed_a_route_spans[route_span] = int(
			completed_a_route_spans.get(route_span, 0)
		) + 1
		completed_a_observations.append({
			"formation_id": group.formation_id,
			"monster_type": group.monster_type,
			"pair_mode": group.pair_mode,
			"route_span": route_span,
			"formation_anchor_route_index":
				group.formation_anchor_route_index,
			"initial_slot_error": group.initial_slot_error,
			"lock_runtime_elapsed": group.lock_runtime_elapsed,
			"completion_runtime_elapsed": runtime_elapsed,
			"lock_to_complete_duration": group.completion_elapsed,
			"center": center if center != null else Vector2.ZERO,
		})
		completed_a_by_type[group.monster_type] = int(
			completed_a_by_type.get(group.monster_type, 0)
		) + 1
	sync_group_to_members(group, active_enemies)


func complete_b_group(group, active_enemies: Dictionary) -> void:
	group.complete(
		PrototypeConfig.get_formation_effect(
			group.monster_type,
			PrototypeConfig.FORMATION_LEVEL_B
		)
	)
	var center: Variant = get_group_center(group, active_enemies)
	if group.formation_anchor_route_index < 0 and center != null:
		group.formation_anchor_route_index = (
			PrototypeConfig.get_nearest_formation_route_index(
				center,
				group.route_group_id,
				get_battlefield_size()
			)
		)
	if group.monster_type == &"charge":
		group.control_resistance_available = true
		group.control_resistance_consumed = false
	completed_b_count += 1
	completed_b_by_type[group.monster_type] = int(
		completed_b_by_type.get(group.monster_type, 0)
	) + 1
	var source_anchor_span := 0
	if group.source_a_anchor_route_indices.size() == 2:
		source_anchor_span = abs(
			group.source_a_anchor_route_indices[0]
				- group.source_a_anchor_route_indices[1]
		)
	completed_b_observations.append({
		"formation_id": group.formation_id,
		"monster_type": group.monster_type,
		"center": center if center != null else Vector2.ZERO,
		"elapsed": runtime_elapsed,
		"formation_anchor_route_index": group.formation_anchor_route_index,
		"source_anchor_route_indices":
			group.source_a_anchor_route_indices.duplicate(),
		"source_anchor_span": source_anchor_span,
		"initial_slot_error": group.initial_slot_error,
		"lock_runtime_elapsed": group.lock_runtime_elapsed,
		"lock_to_complete_duration": group.completion_elapsed,
	})
	sync_group_to_members(group, active_enemies)


func create_complete_a_from_members(
	monster_type: StringName,
	lane_id: StringName,
	members: Array[StringName],
	active_enemies: Dictionary,
	preferred_id: StringName = &"",
	preferred_anchor_route_index: int = -1
):
	if members.size() != 2:
		return null
	var group = PrototypeFormationGroup.new()
	var formation_id := (
		preferred_id if preferred_id != &"" else make_formation_id(&"A")
	)
	group.configure(
		formation_id,
		monster_type,
		lane_id,
		PrototypeConfig.FORMATION_LEVEL_A,
		PrototypeConfig.FORMATION_STATE_COMPLETE,
		sort_member_ids(members, active_enemies),
		PrototypeConfig.FORMATION_A_DURATION,
		PrototypeConfig.get_formation_effect(
			monster_type,
			PrototypeConfig.FORMATION_LEVEL_A
		)
	)
	var center: Variant = get_members_center(group.member_ids, active_enemies)
	if center != null:
		var slots := create_a_slot_assignments(group.member_ids, active_enemies)
		group.configure_lock(
			StringName(
				active_enemies[group.member_ids[0]].route_group_id
			),
			&"",
			&"",
			center,
			slots,
			PrototypeConfig.FORMATION_MEET_TIMEOUT,
			&"downgraded"
		)
		group.formation_anchor_route_index = (
			preferred_anchor_route_index
			if preferred_anchor_route_index >= 0
			else PrototypeConfig.get_nearest_formation_route_index(
				center,
				group.route_group_id,
				get_battlefield_size()
			)
		)
		group.complete(
			PrototypeConfig.get_formation_effect(
				monster_type,
				PrototypeConfig.FORMATION_LEVEL_A
			)
		)
	register_group(group, active_enemies)
	return group


func handle_member_removed(
	member_id: StringName,
	reason: StringName,
	active_enemies: Dictionary
) -> void:
	last_active_enemies = active_enemies
	var group_id := StringName(member_to_group.get(member_id, &""))
	if group_id == &"" or not groups.has(group_id):
		var removed_enemy = active_enemies.get(member_id)
		if is_instance_valid(removed_enemy):
			removed_enemy.reset_formation_state()
		return
	var group = groups[group_id]
	if group.formation_state == PrototypeConfig.FORMATION_STATE_FORMING_B:
		cancel_forming_b(group, active_enemies, true, member_id)
		return
	if (
		group.formation_level == PrototypeConfig.FORMATION_LEVEL_B
		and group.formation_state == PrototypeConfig.FORMATION_STATE_COMPLETE
	):
		downgrade_b_after_member_loss(group, member_id, active_enemies)
		return
	interrupted_count += 1
	unregister_group(group, true, active_enemies, member_id)
	queue_redraw()


func interrupt_member(
	member_id: StringName,
	reason: StringName,
	active_enemies: Dictionary
) -> Dictionary:
	if not PrototypeConfig.CONTROL_INTERRUPTION_REASONS.has(reason):
		return {"resisted": false, "interrupted": false}
	var group_id := StringName(member_to_group.get(member_id, &""))
	if group_id == &"" or not groups.has(group_id):
		return {"resisted": false, "interrupted": false}
	var group = groups[group_id]
	if (
		group.monster_type == &"charge"
		and group.formation_level == PrototypeConfig.FORMATION_LEVEL_B
		and group.formation_state == PrototypeConfig.FORMATION_STATE_COMPLETE
		and group.control_resistance_available
	):
		group.control_resistance_available = false
		group.control_resistance_consumed = true
		control_resistance_consumed_count += 1
		group.show_feedback(
			"首次控制抵抗",
			PrototypeConfig.FORMATION_FEEDBACK_DURATION
		)
		queue_redraw()
		return {"resisted": true, "interrupted": false}
	interrupted_count += 1
	if group.formation_state == PrototypeConfig.FORMATION_STATE_FORMING_B:
		cancel_forming_b(group, active_enemies, false)
	elif (
		group.formation_level == PrototypeConfig.FORMATION_LEVEL_B
		and group.formation_state == PrototypeConfig.FORMATION_STATE_COMPLETE
	):
		downgrade_complete_b(group, active_enemies)
	else:
		cancel_group_to_singles(group, active_enemies, false)
	queue_redraw()
	return {"resisted": false, "interrupted": true}


func downgrade_b_after_member_loss(
	group,
	removed_member_id: StringName,
	active_enemies: Dictionary
) -> void:
	interrupted_count += 1
	downgrade_count += 1
	var remaining: Array[StringName] = []
	for member_id: StringName in group.member_ids:
		if (
			member_id != removed_member_id
			and is_valid_enemy(active_enemies.get(member_id))
		):
			remaining.append(member_id)
	unregister_group(group, true, active_enemies, removed_member_id)
	remaining = sort_member_ids(remaining, active_enemies)
	if remaining.size() >= 2:
		var a_members: Array[StringName] = [remaining[0], remaining[1]]
		var first = active_enemies.get(a_members[0])
		if is_valid_enemy(first):
			create_complete_a_from_members(
				StringName(first.monster_type),
				StringName(first.blocking_lane_id),
				a_members,
				active_enemies
			)
	queue_redraw()


func downgrade_complete_b(group, active_enemies: Dictionary) -> void:
	downgrade_count += 1
	var remaining := get_valid_member_ids(group.member_ids, active_enemies)
	unregister_group(group, true, active_enemies)
	remaining = sort_member_ids(remaining, active_enemies)
	if remaining.size() >= 2:
		var a_members: Array[StringName] = [remaining[0], remaining[1]]
		var first = active_enemies.get(a_members[0])
		if is_valid_enemy(first):
			create_complete_a_from_members(
				StringName(first.monster_type),
				StringName(first.blocking_lane_id),
				a_members,
				active_enemies
			)


func cancel_forming_b(
	group,
	active_enemies: Dictionary,
	count_interruption: bool,
	excluded_member_id: StringName = &""
) -> void:
	if count_interruption:
		interrupted_count += 1
	var source_ids: Array[StringName] = group.source_a_ids.duplicate()
	var source_sets: Array = group.source_a_member_sets.duplicate(true)
	var source_anchor_indices: Array[int] = (
		group.source_a_anchor_route_indices.duplicate()
	)
	unregister_group(group, true, active_enemies, excluded_member_id)
	for source_index in range(source_sets.size()):
		var original_members: Array = source_sets[source_index]
		var valid_members: Array[StringName] = []
		for member_id: StringName in original_members:
			if (
				member_id != excluded_member_id
				and is_valid_enemy(active_enemies.get(member_id))
			):
				valid_members.append(member_id)
		if valid_members.size() == original_members.size() and valid_members.size() == 2:
			var first = active_enemies.get(valid_members[0])
			if is_valid_enemy(first):
				var preferred_id := (
					source_ids[source_index]
					if source_index < source_ids.size() else &""
				)
				var preferred_anchor_route_index := (
					source_anchor_indices[source_index]
					if source_index < source_anchor_indices.size() else -1
				)
				create_complete_a_from_members(
					StringName(first.monster_type),
					StringName(first.blocking_lane_id),
					valid_members,
					active_enemies,
					preferred_id,
					preferred_anchor_route_index
				)
	queue_redraw()


func cancel_group_to_singles(
	group,
	active_enemies: Dictionary,
	count_interruption: bool
) -> void:
	if count_interruption:
		interrupted_count += 1
	unregister_group(group, true, active_enemies)
	queue_redraw()


func clear_all_formations(active_enemies: Dictionary) -> void:
	for enemy in active_enemies.values():
		if is_instance_valid(enemy) and enemy.has_method("reset_formation_state"):
			enemy.reset_formation_state()
	for group in groups.values():
		group.invalidate()
	groups.clear()
	member_to_group.clear()
	clear_enemy_zone_states(active_enemies)
	reset_protection_effects(active_enemies)
	last_active_enemies = active_enemies
	queue_redraw()


func register_group(group, active_enemies: Dictionary) -> void:
	groups[group.formation_id] = group
	for member_id: StringName in group.member_ids:
		member_to_group[member_id] = group.formation_id
	sync_group_to_members(group, active_enemies)


func unregister_group(
	group,
	reset_members: bool,
	active_enemies: Dictionary,
	excluded_member_id: StringName = &""
) -> void:
	groups.erase(group.formation_id)
	for member_id: StringName in group.member_ids:
		if StringName(member_to_group.get(member_id, &"")) == group.formation_id:
			member_to_group.erase(member_id)
		if not reset_members:
			continue
		var enemy = active_enemies.get(member_id)
		if is_instance_valid(enemy):
			enemy.reset_formation_state()
	group.invalidate()
	if excluded_member_id != &"":
		var excluded_enemy = active_enemies.get(excluded_member_id)
		if is_instance_valid(excluded_enemy):
			excluded_enemy.reset_formation_state()


func refresh_group_member_states(active_enemies: Dictionary) -> void:
	for formation_id: StringName in get_sorted_group_ids():
		var group = groups.get(formation_id)
		if group != null and group.is_valid:
			sync_group_to_members(group, active_enemies)


func sync_group_to_members(group, active_enemies: Dictionary) -> void:
	var effective_level: StringName = StringName(group.formation_level)
	var effect: Dictionary = group.current_effect
	if group.formation_state == PrototypeConfig.FORMATION_STATE_FORMING_A:
		effective_level = PrototypeConfig.FORMATION_LEVEL_SINGLE
		effect = {}
	elif group.formation_state == PrototypeConfig.FORMATION_STATE_FORMING_B:
		effective_level = PrototypeConfig.FORMATION_LEVEL_A
		effect = PrototypeConfig.get_formation_effect(
			group.monster_type,
			PrototypeConfig.FORMATION_LEVEL_A
		)
	for member_id: StringName in group.member_ids:
		var enemy = active_enemies.get(member_id)
		if not is_valid_enemy(enemy):
			continue
		enemy.apply_formation_state(
			group.formation_id,
			effective_level,
			group.formation_state,
			group.formation_progress,
			effect
		)


func refresh_shield_protection(active_enemies: Dictionary) -> void:
	reset_protection_effects(active_enemies)
	var protected_this_update: Dictionary = {}
	for group in groups.values():
		if (
			not group.is_valid
			or group.monster_type != &"shield"
			or group.formation_level != PrototypeConfig.FORMATION_LEVEL_B
			or group.formation_state != PrototypeConfig.FORMATION_STATE_COMPLETE
		):
			continue
		var center: Variant = get_group_center(group, active_enemies)
		if center == null:
			continue
		for enemy in active_enemies.values():
			if (
				not is_valid_enemy(enemy)
				or group.member_ids.has(enemy.runtime_id)
				or not PrototypeConfig.are_route_groups_compatible(
					group.route_group_id,
					enemy.route_group_id
				)
				or center.distance_to(enemy.position)
					> PrototypeConfig.SHIELD_B_PROTECTION_RADIUS
			):
				continue
			enemy.set_protection_ranged_reduction(
				PrototypeConfig.SHIELD_B_ALLY_RANGED_REDUCTION
			)
			protected_this_update[enemy.runtime_id] = true
			protected_target_ids_seen[enemy.runtime_id] = true
	current_protected_target_count = protected_this_update.size()
	max_protected_target_count = maxi(
		max_protected_target_count,
		current_protected_target_count
	)


func reset_protection_effects(active_enemies: Dictionary) -> void:
	for enemy in active_enemies.values():
		if is_instance_valid(enemy) \
				and enemy.has_method("set_protection_ranged_reduction"):
			enemy.set_protection_ranged_reduction(0.0)
	current_protected_target_count = 0


func get_battlefield_size() -> Vector2:
	var parent_control := get_parent() as Control
	if is_instance_valid(parent_control) and parent_control.size.x > 0.0:
		return parent_control.size
	return PrototypeConfig.DEFAULT_BATTLEFIELD_SIZE


func refresh_enemy_zone_states(active_enemies: Dictionary) -> void:
	var battlefield_size := get_battlefield_size()
	for enemy in active_enemies.values():
		if not is_valid_enemy(enemy):
			continue
		var zone := PrototypeConfig.get_formation_zone_at_position(
			enemy.position,
			enemy.route_group_id,
			battlefield_size
		)
		enemy.set_formation_zone(
			StringName(zone.get("zone_id", &"")),
			StringName(zone.get("zone_type", &""))
		)


func clear_enemy_zone_states(active_enemies: Dictionary) -> void:
	for enemy in active_enemies.values():
		if is_instance_valid(enemy) and enemy.has_method("set_formation_zone"):
			enemy.set_formation_zone(&"", &"")


func get_zone_for_position(
	world_position: Vector2,
	route_group_id: StringName
) -> Dictionary:
	return PrototypeConfig.get_formation_zone_at_position(
		world_position,
		route_group_id,
		get_battlefield_size()
	)


func maintain_complete_group_slots(
	group,
	delta: float,
	active_enemies: Dictionary
) -> void:
	if not is_group_membership_valid(
		group,
		active_enemies,
		2 if group.formation_level == PrototypeConfig.FORMATION_LEVEL_A else 4
	):
		return
	apply_group_steering(group, delta, active_enemies, false)


func apply_group_steering(
	group,
	delta: float,
	active_enemies: Dictionary,
	is_forming: bool
) -> float:
	var center: Variant = get_group_center(group, active_enemies)
	if center == null:
		return 0.0
	group.meeting_center = center
	var maximum_error := 0.0
	for member_id: StringName in group.member_ids:
		var enemy = active_enemies.get(member_id)
		if not is_valid_enemy(enemy):
			return 0.0
		var slot_offset: Vector2 = group.slot_assignments.get(
			member_id,
			Vector2.ZERO
		)
		var target_position: Vector2 = center + slot_offset
		var temporary_multiplier := 1.0
		if is_forming:
			temporary_multiplier = PrototypeConfig.FORMING_FORWARD_SPEED_MULTIPLIER
			if enemy.position.x > target_position.x \
					+ PrototypeConfig.FORMATION_SLOT_TOLERANCE:
				temporary_multiplier = 1.12
			elif enemy.position.x < target_position.x \
					- PrototypeConfig.FORMATION_SLOT_TOLERANCE:
				temporary_multiplier = 0.62
		var error: float = enemy.apply_formation_slot_target(
			target_position,
			delta,
			PrototypeConfig.FORMATION_SLOT_MOVE_SPEED
				if is_forming
				else PrototypeConfig.COMPLETE_FORMATION_SLOT_MAINTENANCE_SPEED,
			temporary_multiplier
		)
		maximum_error = maxf(maximum_error, error)
	var updated_center: Variant = get_group_center(group, active_enemies)
	if updated_center != null:
		group.meeting_center = updated_center
	if maximum_error <= PrototypeConfig.FORMATION_SLOT_TOLERANCE:
		return 1.0
	var reference_distance := (
		maxf(PrototypeConfig.A_PAIR_RADIUS_X, PrototypeConfig.A_PAIR_RADIUS_Y)
		if group.formation_level == PrototypeConfig.FORMATION_LEVEL_A
		else maxf(PrototypeConfig.B_PAIR_RADIUS_X, PrototypeConfig.B_PAIR_RADIUS_Y)
	)
	return clampf(
		1.0
			- (
				maximum_error - PrototypeConfig.FORMATION_SLOT_TOLERANCE
			) / reference_distance,
		0.0,
		0.999
	)


func get_maximum_slot_error(
	center: Vector2,
	slot_assignments: Dictionary,
	active_enemies: Dictionary
) -> float:
	var maximum_error := 0.0
	for member_id: StringName in slot_assignments.keys():
		var enemy = active_enemies.get(member_id)
		if not is_valid_enemy(enemy):
			continue
		var target_position: Vector2 = (
			center + Vector2(slot_assignments.get(member_id, Vector2.ZERO))
		)
		maximum_error = maxf(
			maximum_error,
			enemy.position.distance_to(target_position)
		)
	return maximum_error


func create_a_slot_assignments(
	member_ids: Array[StringName],
	active_enemies: Dictionary
) -> Dictionary:
	var members := sort_members_for_a_slots(member_ids, active_enemies)
	if members.size() != 2:
		return {}
	return {
		members[0]: Vector2(0.0, -PrototypeConfig.A_SLOT_GAP_Y * 0.5),
		members[1]: Vector2(0.0, PrototypeConfig.A_SLOT_GAP_Y * 0.5),
	}


func sort_members_for_a_slots(
	member_ids: Array[StringName],
	active_enemies: Dictionary
) -> Array[StringName]:
	var result: Array[StringName] = member_ids.duplicate()
	result.sort_custom(
		func(first_id: StringName, second_id: StringName):
			var first = active_enemies.get(first_id)
			var second = active_enemies.get(second_id)
			if is_valid_enemy(first) and is_valid_enemy(second):
				if not is_equal_approx(first.position.y, second.position.y):
					return first.position.y < second.position.y
				return enemy_node_less(first, second)
			return String(first_id) < String(second_id)
	)
	return result


func sort_members_for_b_slots(
	member_ids: Array[StringName],
	active_enemies: Dictionary
) -> Array[StringName]:
	var result: Array[StringName] = member_ids.duplicate()
	result.sort_custom(
		func(first_id: StringName, second_id: StringName):
			var first = active_enemies.get(first_id)
			var second = active_enemies.get(second_id)
			if is_valid_enemy(first) and is_valid_enemy(second):
				if not is_equal_approx(first.position.y, second.position.y):
					return first.position.y < second.position.y
				if not is_equal_approx(first.position.x, second.position.x):
					return first.position.x < second.position.x
				return enemy_node_less(first, second)
			return String(first_id) < String(second_id)
	)
	return result


func classify_a_pair(
	first_position: Vector2,
	second_position: Vector2
) -> StringName:
	var difference := (second_position - first_position).abs()
	var axis_threshold := PrototypeConfig.FORMATION_SLOT_TOLERANCE * 1.5
	if difference.y <= axis_threshold and difference.x > axis_threshold:
		return &"front_back"
	if difference.x <= axis_threshold and difference.y > axis_threshold:
		return &"vertical"
	return &"diagonal"


func is_group_membership_valid(
	group,
	active_enemies: Dictionary,
	expected_count: int
) -> bool:
	if group.member_ids.size() != expected_count:
		return false
	var unique_members: Dictionary = {}
	for member_id: StringName in group.member_ids:
		if unique_members.has(member_id):
			return false
		unique_members[member_id] = true
		var enemy = active_enemies.get(member_id)
		if (
			not is_valid_enemy(enemy)
			or StringName(member_to_group.get(member_id, &""))
				!= group.formation_id
			or enemy.monster_type != group.monster_type
			or not PrototypeConfig.are_route_groups_compatible(
				group.route_group_id,
				enemy.route_group_id
			)
		):
			return false
	return true


func get_sorted_single_enemies(active_enemies: Dictionary) -> Array:
	var enemies: Array = []
	for enemy in active_enemies.values():
		if (
			is_valid_enemy(enemy)
			and enemy.formation_id == &""
			and enemy.formation_can_participate
		):
			enemies.append(enemy)
	enemies.sort_custom(enemy_node_less)
	return enemies


func get_sorted_complete_a_groups(active_enemies: Dictionary) -> Array:
	var result: Array = []
	for group in groups.values():
		if (
			group.is_valid
			and group.formation_level == PrototypeConfig.FORMATION_LEVEL_A
			and group.formation_state == PrototypeConfig.FORMATION_STATE_COMPLETE
			and is_group_membership_valid(group, active_enemies, 2)
		):
			result.append(group)
	result.sort_custom(
		func(first, second):
			return formation_group_less(first, second, active_enemies)
	)
	return result


func enemy_node_less(first, second) -> bool:
	if int(first.spawn_sequence) != int(second.spawn_sequence):
		return int(first.spawn_sequence) < int(second.spawn_sequence)
	return String(first.runtime_id) < String(second.runtime_id)


func formation_group_less(
	first,
	second,
	active_enemies: Dictionary
) -> bool:
	var first_members := sort_member_ids(first.member_ids, active_enemies)
	var second_members := sort_member_ids(second.member_ids, active_enemies)
	if first_members.is_empty():
		return not second_members.is_empty()
	if second_members.is_empty():
		return false
	var first_enemy = active_enemies.get(first_members[0])
	var second_enemy = active_enemies.get(second_members[0])
	if is_valid_enemy(first_enemy) and is_valid_enemy(second_enemy):
		return enemy_node_less(first_enemy, second_enemy)
	return String(first.formation_id) < String(second.formation_id)


func sort_member_ids(
	member_ids: Array[StringName],
	active_enemies: Dictionary
) -> Array[StringName]:
	var sorted_members: Array[StringName] = member_ids.duplicate()
	sorted_members.sort_custom(
		func(first_id: StringName, second_id: StringName):
			var first = active_enemies.get(first_id)
			var second = active_enemies.get(second_id)
			if is_valid_enemy(first) and is_valid_enemy(second):
				return enemy_node_less(first, second)
			return String(first_id) < String(second_id)
	)
	return sorted_members


func get_valid_member_ids(
	member_ids: Array[StringName],
	active_enemies: Dictionary
) -> Array[StringName]:
	var result: Array[StringName] = []
	for member_id: StringName in member_ids:
		if is_valid_enemy(active_enemies.get(member_id)):
			result.append(member_id)
	return result


func is_valid_enemy(enemy) -> bool:
	return (
		is_instance_valid(enemy)
		and not enemy.is_dead
		and not enemy.settlement_completed
	)


func get_group_center(group, active_enemies: Dictionary) -> Variant:
	return get_members_center(group.member_ids, active_enemies)


func get_members_center(
	member_ids: Array,
	active_enemies: Dictionary
) -> Variant:
	var total := Vector2.ZERO
	var count := 0
	for member_id: StringName in member_ids:
		var enemy = active_enemies.get(member_id)
		if not is_valid_enemy(enemy):
			return null
		total += enemy.position
		count += 1
	return total / float(count) if count > 0 else null


func make_formation_id(level: StringName) -> StringName:
	var formation_id := StringName(
		"run_%d_formation_%s_%d"
			% [run_sequence, String(level), next_formation_sequence]
	)
	next_formation_sequence += 1
	return formation_id


func get_sorted_group_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for formation_id: StringName in groups.keys():
		ids.append(formation_id)
	ids.sort_custom(func(first: StringName, second: StringName):
		return String(first) < String(second)
	)
	return ids


func get_groups_snapshot() -> Array:
	var snapshots: Array = []
	for formation_id: StringName in get_sorted_group_ids():
		var group = groups.get(formation_id)
		if group != null and group.is_valid:
			snapshots.append(group.get_snapshot())
	return snapshots


func get_group(formation_id: StringName):
	return groups.get(formation_id)


func get_member_group(member_id: StringName):
	var formation_id := StringName(member_to_group.get(member_id, &""))
	return groups.get(formation_id)


func find_complete_group(monster_type: StringName, level: StringName):
	for formation_id: StringName in get_sorted_group_ids():
		var group = groups[formation_id]
		if (
			group.is_valid
			and group.monster_type == monster_type
			and group.formation_level == level
			and group.formation_state == PrototypeConfig.FORMATION_STATE_COMPLETE
		):
			return group
	return null


func get_stats_snapshot(active_enemies: Dictionary) -> Dictionary:
	var single_count := 0
	for enemy in active_enemies.values():
		if (
			is_valid_enemy(enemy)
			and enemy.formation_level == PrototypeConfig.FORMATION_LEVEL_SINGLE
		):
			single_count += 1
	var forming_a_count := 0
	var a_count := 0
	var forming_b_count := 0
	var b_count := 0
	var active_zone_counts: Dictionary = {}
	for enemy in active_enemies.values():
		if not is_valid_enemy(enemy):
			continue
		active_zone_counts[enemy.formation_zone_type] = int(
			active_zone_counts.get(enemy.formation_zone_type, 0)
		) + 1
	for group in groups.values():
		if not group.is_valid:
			continue
		if group.formation_state == PrototypeConfig.FORMATION_STATE_FORMING_A:
			forming_a_count += 1
		elif group.formation_state == PrototypeConfig.FORMATION_STATE_FORMING_B:
			forming_b_count += 1
		elif group.formation_level == PrototypeConfig.FORMATION_LEVEL_A:
			a_count += 1
		elif group.formation_level == PrototypeConfig.FORMATION_LEVEL_B:
			b_count += 1
	return {
		"enabled": formations_enabled,
		"single_count": single_count,
		"forming_a_count": forming_a_count,
		"a_count": a_count,
		"forming_b_count": forming_b_count,
		"b_count": b_count,
		"completed_a_count": completed_a_count,
		"completed_b_count": completed_b_count,
		"interrupted_count": interrupted_count,
		"downgrade_count": downgrade_count,
		"control_resistance_consumed_count": control_resistance_consumed_count,
		"completed_a_by_type": completed_a_by_type.duplicate(true),
		"completed_b_by_type": completed_b_by_type.duplicate(true),
		"current_protected_target_count": current_protected_target_count,
		"max_protected_target_count": max_protected_target_count,
		"protected_target_ids_seen": protected_target_ids_seen.duplicate(true),
		"meet_timeout_count": meet_timeout_count,
		"candidate_lock_count": candidate_lock_count,
		"a_pair_neighbor_route_span": a_pair_neighbor_route_span,
		"b_pair_neighbor_route_span": b_pair_neighbor_route_span,
		"cross_route_a_count": cross_route_a_count,
		"completed_a_route_spans": completed_a_route_spans.duplicate(true),
		"completed_a_pair_modes": completed_a_pair_modes.duplicate(true),
		"completed_a_observations": completed_a_observations.duplicate(true),
		"completed_b_observations": completed_b_observations.duplicate(true),
		"active_zone_counts": active_zone_counts,
		"runtime_elapsed": runtime_elapsed,
		"active_group_count": groups.size(),
		"member_assignment_count": member_to_group.size(),
	}


func _draw() -> void:
	if not formations_enabled:
		return
	for formation_id: StringName in get_sorted_group_ids():
		var group = groups.get(formation_id)
		if group == null or not group.is_valid:
			continue
		draw_formation_group(group)


func draw_formation_group(group) -> void:
	var positions: Array[Vector2] = []
	for member_id: StringName in group.member_ids:
		var enemy = last_active_enemies.get(member_id)
		if is_valid_enemy(enemy):
			positions.append(enemy.position)
	if positions.size() < 2:
		return
	var color := PrototypeConfig.get_formation_color(group.monster_type)
	var center := Vector2.ZERO
	for point: Vector2 in positions:
		center += point
	center /= float(positions.size())
	if group.formation_state == PrototypeConfig.FORMATION_STATE_FORMING_A:
		draw_line(positions[0], positions[1], Color(color, 0.62), 1.5, true)
		draw_slot_targets(group, center, color)
		draw_formation_label(
			center,
			"A锁定靠拢 %d%%" % int(round(group.formation_progress * 100.0)),
			color
		)
	elif group.formation_state == PrototypeConfig.FORMATION_STATE_FORMING_B:
		var first_center: Variant = get_members_center(
			group.source_a_member_sets[0], last_active_enemies
		)
		var second_center: Variant = get_members_center(
			group.source_a_member_sets[1], last_active_enemies
		)
		if first_center != null and second_center != null:
			draw_line(first_center, second_center, Color(color, 0.75), 2.0, true)
		draw_slot_targets(group, center, color)
		draw_formation_label(
			center,
			"B锁定靠拢 %d%%" % int(round(group.formation_progress * 100.0)),
			color
		)
	elif group.formation_level == PrototypeConfig.FORMATION_LEVEL_A:
		draw_line(positions[0], positions[1], color, 3.0, true)
		draw_formation_label(
			center,
			"A｜%s" % String(group.current_effect.get("effect_text", "")),
			color
		)
	else:
		var radius := 26.0
		for point: Vector2 in positions:
			radius = maxf(radius, center.distance_to(point) + 18.0)
			draw_line(center, point, Color(color, 0.72), 2.0, true)
		draw_arc(center, radius, 0.0, TAU, 48, color, 3.0, true)
		draw_formation_label(
			center,
			"B｜%s" % String(group.current_effect.get("effect_text", "")),
			color
		)
	if group.feedback_remaining > 0.0 and not group.feedback_text.is_empty():
		draw_formation_label(
			center + Vector2(0.0, -30.0),
			group.feedback_text,
			Color(1.0, 0.92, 0.42, 1.0)
		)


func draw_slot_targets(group, center: Vector2, color: Color) -> void:
	for slot_offset: Vector2 in group.slot_assignments.values():
		var target := center + slot_offset
		draw_circle(target, 4.0, Color(color, 0.28))
		draw_arc(target, 7.0, 0.0, TAU, 16, Color(color, 0.72), 1.0, true)


func draw_formation_label(position: Vector2, text: String, color: Color) -> void:
	draw_string(
		ThemeDB.fallback_font,
		position + Vector2(-90.0, -18.0),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		180.0,
		14,
		color
	)

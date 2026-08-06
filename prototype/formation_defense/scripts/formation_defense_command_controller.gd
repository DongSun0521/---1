extends Node

signal command_changed(snapshot: Dictionary)
signal command_feedback(message: String)

const CONTEXT_FOCUS := &"FOCUS"
const CONTEXT_PREVENT_FORMATION := &"PREVENT_FORMATION"
const CONTEXT_DISMANTLE_A := &"DISMANTLE_A"
const CONTEXT_DISMANTLE_B := &"DISMANTLE_B"

var runtime = null
var active_command: Dictionary = {}
var next_command_id := 1
var elapsed_time := 0.0
var feedback_message := ""
var last_command_result: Dictionary = {}
var hover_target_id: StringName = &""
var stats := create_empty_stats()


func bind_runtime(new_runtime) -> void:
	runtime = new_runtime


func process_command(delta: float) -> void:
	elapsed_time += maxf(0.0, delta)
	if active_command.is_empty():
		return
	var target = resolve_enemy(get_target_runtime_id())
	if not is_instance_valid(target):
		cancel_command(&"INVALID_TARGET")
		stats["invalid_cleanup_count"] += 1
		return
	refresh_command_context(target)
	var current_level := get_effective_complete_level(target)
	var highest_level := int(active_command.get("highest_complete_level", 0))
	if highest_level > current_level:
		complete_dismantle(highest_level)


func issue_command(target_runtime_id: StringName) -> bool:
	var target = resolve_enemy(target_runtime_id)
	if not is_selectable_enemy(target):
		return false
	if get_target_runtime_id() == target_runtime_id:
		refresh_command_context(target)
		return true
	if not active_command.is_empty():
		stats["replaced_count"] += 1
		clear_active_command(&"REPLACED", false)
		feedback_message = "集火目标已更换"
	active_command = {
		"command_id": next_command_id,
		"target_runtime_id": target_runtime_id,
		"issued_at": elapsed_time,
		"initial_context": get_context_for(target),
		"context": get_context_for(target),
		"formation_id_at_issue": StringName(target.formation_id),
		"formation_state_at_issue": StringName(target.formation_state),
		"highest_complete_level": get_effective_complete_level(target),
		"last_complete_level": get_effective_complete_level(target),
		"cancel_reason": &"",
		"completion_reason": &"",
	}
	next_command_id += 1
	stats["issued_count"] += 1
	feedback_message = "已下达指挥：%s" % get_context_display_name(
		StringName(active_command.context)
	) if feedback_message != "集火目标已更换" else feedback_message
	refresh_enemy_visuals()
	command_feedback.emit(feedback_message)
	command_changed.emit(get_active_command_snapshot())
	return true


func cancel_command(reason: StringName = &"PLAYER_CANCEL") -> bool:
	if active_command.is_empty():
		return false
	stats["canceled_count"] += 1
	if reason == &"TARGET_DIED":
		stats["death_cleanup_count"] += 1
	clear_active_command(reason, true)
	return true


func get_priority_target_for(attacker, legal_candidates: Array):
	if active_command.is_empty() or not is_instance_valid(attacker):
		return legal_candidates[0] if not legal_candidates.is_empty() else null
	var target_id := get_target_runtime_id()
	for candidate in legal_candidates:
		if is_instance_valid(candidate) \
				and StringName(candidate.runtime_id) == target_id:
			if legal_candidates[0] != candidate:
				stats["priority_attack_count"] += 1
				stats["participant_ids"][StringName(attacker.character_id)] = true
			return candidate
	stats["fallback_count"] += 1
	return legal_candidates[0] if not legal_candidates.is_empty() else null


func get_active_command_snapshot() -> Dictionary:
	if active_command.is_empty():
		return {}
	var snapshot := active_command.duplicate(true)
	var target = resolve_enemy(get_target_runtime_id())
	if is_instance_valid(target):
		snapshot["target_health"] = int(target.current_health)
		snapshot["target_max_health"] = int(target.max_health)
		snapshot["monster_type"] = StringName(target.monster_type)
		snapshot["enemy_profile_id"] = StringName(target.monster_type)
		snapshot["display_name"] = String(target.display_name)
		snapshot["route_id"] = StringName(target.route_id)
		snapshot["formation_id"] = StringName(target.formation_id)
		snapshot["formation_state"] = StringName(target.formation_state)
		snapshot["formation_level"] = StringName(target.formation_level)
		snapshot["formation_damage_reduction"] = float(
			target.formation_player_damage_reduction
		)
	return snapshot


func reset_for_restart() -> void:
	clear_active_command(&"RESTART", false)
	hover_target_id = &""
	feedback_message = ""
	last_command_result.clear()
	elapsed_time = 0.0
	next_command_id = 1
	stats = create_empty_stats()
	refresh_enemy_visuals()


func handle_enemy_removed(enemy_id: StringName, reason: StringName) -> void:
	if active_command.is_empty():
		return
	var target_id := get_target_runtime_id()
	var highest_level := int(active_command.get("highest_complete_level", 0))
	if enemy_id == target_id:
		if highest_level > 0 and reason == &"KILLED":
			complete_dismantle(highest_level)
		else:
			cancel_command(&"TARGET_DIED" if reason == &"KILLED" else reason)
		return
	var target = resolve_enemy(target_id)
	if is_instance_valid(target) \
			and highest_level > get_effective_complete_level(target):
		complete_dismantle(highest_level)


func handle_battle_end(reason: StringName) -> void:
	if not active_command.is_empty():
		clear_active_command(reason, false)


func set_hover_target(enemy_id: StringName) -> void:
	if hover_target_id == enemy_id:
		return
	hover_target_id = enemy_id
	refresh_enemy_visuals()


func get_target_runtime_id() -> StringName:
	return StringName(active_command.get("target_runtime_id", &""))


func get_stats_snapshot() -> Dictionary:
	var snapshot := stats.duplicate(true)
	snapshot["participant_count"] = Dictionary(
		stats.get("participant_ids", {})
	).size()
	return snapshot


func refresh_command_context(target) -> void:
	var level := get_effective_complete_level(target)
	active_command["highest_complete_level"] = maxi(
		int(active_command.get("highest_complete_level", 0)), level
	)
	active_command["last_complete_level"] = level
	active_command["context"] = get_context_for(target)
	refresh_enemy_visuals()


func complete_dismantle(level: int) -> void:
	if active_command.is_empty():
		return
	var reason := &"DISMANTLED_B" if level >= 2 else &"DISMANTLED_A"
	if level >= 2:
		stats["b_dismantled_count"] += 1
		feedback_message = "成员击杀后B阵已破"
	else:
		stats["a_dismantled_count"] += 1
		feedback_message = "成员击杀后A阵已破"
	active_command["completion_reason"] = reason
	command_feedback.emit(feedback_message)
	clear_active_command(reason, false)


func clear_active_command(reason: StringName, show_feedback: bool) -> void:
	if active_command.is_empty():
		return
	active_command["cancel_reason"] = reason
	last_command_result = active_command.duplicate(true)
	active_command.clear()
	if show_feedback:
		feedback_message = get_reason_display_name(reason)
		command_feedback.emit(feedback_message)
	refresh_enemy_visuals()
	command_changed.emit({})


func resolve_enemy(enemy_id: StringName):
	if not is_instance_valid(runtime) or enemy_id == &"":
		return null
	return runtime.active_enemies.get(enemy_id)


func is_selectable_enemy(enemy) -> bool:
	return (
		is_instance_valid(enemy)
		and not enemy.is_dead
		and not enemy.settlement_completed
	)


func get_effective_complete_level(enemy) -> int:
	if not is_instance_valid(enemy):
		return 0
	if StringName(enemy.formation_state) in [&"FORMING_B", &"FORMING_B_LOCKED"]:
		return 1
	if StringName(enemy.formation_state) != &"COMPLETE":
		return 0
	if StringName(enemy.formation_level) == &"B":
		return 2
	if StringName(enemy.formation_level) == &"A":
		return 1
	return 0


func get_context_for(enemy) -> StringName:
	var state := StringName(enemy.formation_state)
	if state in [&"FORMING_A", &"FORMING_A_LOCKED", &"FORMING_B", &"FORMING_B_LOCKED"]:
		return CONTEXT_PREVENT_FORMATION
	var level := get_effective_complete_level(enemy)
	if level >= 2:
		return CONTEXT_DISMANTLE_B
	if level == 1:
		return CONTEXT_DISMANTLE_A
	return CONTEXT_FOCUS


func refresh_enemy_visuals() -> void:
	if not is_instance_valid(runtime):
		return
	var target = resolve_enemy(get_target_runtime_id())
	var related_ids: Dictionary = {}
	if is_instance_valid(target) and StringName(target.formation_id) != &"":
		for enemy in runtime.active_enemies.values():
			if is_instance_valid(enemy) \
					and StringName(enemy.formation_id) == StringName(target.formation_id):
				related_ids[StringName(enemy.runtime_id)] = true
	for enemy in runtime.active_enemies.values():
		if not is_instance_valid(enemy) or not enemy.has_method("set_command_visual"):
			continue
		var enemy_id := StringName(enemy.runtime_id)
		enemy.set_command_visual(
			enemy_id == get_target_runtime_id(),
			related_ids.has(enemy_id) and enemy_id != get_target_runtime_id(),
			enemy_id == hover_target_id
		)


func get_context_display_name(context: StringName) -> String:
	return {
		CONTEXT_FOCUS: "集火目标",
		CONTEXT_PREVENT_FORMATION: "成阵前拦截",
		CONTEXT_DISMANTLE_A: "集火A阵成员",
		CONTEXT_DISMANTLE_B: "集火B阵成员",
	}.get(context, "集火目标")


func get_reason_display_name(reason: StringName) -> String:
	return {
		&"PLAYER_CANCEL": "已取消指挥",
		&"TARGET_DIED": "目标已消灭，指挥结束",
		&"LEAKED": "目标已漏入，指挥结束",
		&"INVALID_TARGET": "目标失效，指挥已清理",
	}.get(reason, "指挥结束")


func create_empty_stats() -> Dictionary:
	return {
		"issued_count": 0,
		"replaced_count": 0,
		"canceled_count": 0,
		"priority_attack_count": 0,
		"fallback_count": 0,
		"participant_ids": {},
		"b_dismantled_count": 0,
		"a_dismantled_count": 0,
		"death_cleanup_count": 0,
		"invalid_cleanup_count": 0,
	}

extends Control

signal battle_finished(outcome: StringName)

const PrototypeConfig := preload(
	"res://prototype/formation_defense/data/formation_defense_config.gd"
)
const PrototypeEnemy := preload(
	"res://prototype/formation_defense/scripts/formation_defense_enemy.gd"
)
const PrototypeCharacter := preload(
	"res://prototype/formation_defense/scripts/formation_defense_character.gd"
)
const PrototypeDeploymentSlot := preload(
	"res://prototype/formation_defense/scripts/formation_defense_deployment_slot.gd"
)

enum BattleState {
	READY,
	RUNNING,
	VICTORY,
	DEFEAT,
}

const STATE_NAMES := {
	BattleState.READY: "READY",
	BattleState.RUNNING: "RUNNING",
	BattleState.VICTORY: "VICTORY",
	BattleState.DEFEAT: "DEFEAT",
}

@onready var battlefield_content: Control = %BattlefieldContent
@onready var route_view: Control = %RouteView
@onready var deployment_layer: Control = %DeploymentLayer
@onready var formation_manager: Node2D = %FormationLayer
@onready var enemy_layer: Node2D = %EnemyLayer
@onready var character_layer: Node2D = %CharacterLayer
@onready var durability_label: Label = %DurabilityLabel
@onready var state_label: Label = %StateLabel
@onready var generated_label: Label = %GeneratedLabel
@onready var active_label: Label = %ActiveLabel
@onready var killed_label: Label = %KilledLabel
@onready var leaked_label: Label = %LeakedLabel
@onready var resolved_label: Label = %ResolvedLabel
@onready var scenario_label: Label = %ScenarioLabel
@onready var formation_stats_label: Label = %FormationStatsLabel
@onready var scenario_option: OptionButton = %ScenarioOption
@onready var start_button: Button = %StartButton
@onready var restart_button: Button = %RestartButton
@onready var character_card_row: HBoxContainer = %CharacterCardRow
@onready var selected_character_label: Label = %SelectedCharacterLabel
@onready var recommend_button: Button = %RecommendButton
@onready var clear_deployment_button: Button = %ClearDeploymentButton
@onready var undeploy_button: Button = %UndeployButton
@onready var result_label: Label = %ResultLabel

var battle_state: BattleState = BattleState.READY
var selected_scenario_id: StringName = &"survival"
var selected_character_id: StringName = &"guard"
var village_durability := PrototypeConfig.VILLAGE_MAX_DURABILITY
var spawn_plan: Array[StringName] = []
var spawn_entries: Array[Dictionary] = []
var spawn_index := 0
var spawn_elapsed := 0.0
var generated_enemy_count := 0
var killed_enemy_count := 0
var leaked_enemy_count := 0
var resolved_enemy_count := 0
var active_enemies: Dictionary = {}
var settled_enemy_ids: Dictionary = {}
var generated_by_route: Dictionary = {}
var generated_by_spawn_point: Dictionary = {}
var generated_by_monster_type: Dictionary = {}
var active_spawn_point_ids: Array[StringName] = []
var deployment_slots: Dictionary = {}
var character_nodes: Dictionary = {}
var character_cards: Dictionary = {}
var deployment_by_character: Dictionary = {}
var run_sequence := 0
var next_enemy_sequence := 1
var automatic_simulation := true
var battle_finish_count := 0
var block_event_count := 0
var enemy_attack_event_count := 0
var character_attack_event_count := 0
var healing_event_count := 0
var formation_damage_reduction_event_count := 0
var formation_damage_prevented_total := 0
var speed_effect_observed_ids: Dictionary = {}
var demo_control_resistance_triggered := false
var battle_elapsed := 0.0


func _ready() -> void:
	setup_scenario_options()
	setup_deployment_slots()
	setup_character_roster()
	start_button.pressed.connect(start_battle)
	restart_button.pressed.connect(restart_battle)
	scenario_option.item_selected.connect(on_scenario_selected)
	recommend_button.pressed.connect(apply_recommended_deployment)
	clear_deployment_button.pressed.connect(clear_deployment)
	undeploy_button.pressed.connect(undeploy_selected_character)
	battlefield_content.resized.connect(on_battlefield_resized)
	restart_battle()


func _process(delta: float) -> void:
	if automatic_simulation:
		simulate_step(delta)


func setup_scenario_options() -> void:
	scenario_option.clear()
	for scenario_id: StringName in PrototypeConfig.get_scenario_ids():
		var scenario := PrototypeConfig.get_scenario(scenario_id)
		scenario_option.add_item(String(scenario.get("display_name", scenario_id)))
		var item_index := scenario_option.item_count - 1
		scenario_option.set_item_metadata(item_index, scenario_id)
	var default_index := find_scenario_option(selected_scenario_id)
	scenario_option.select(maxi(0, default_index))


func setup_deployment_slots() -> void:
	for slot_data: Dictionary in PrototypeConfig.get_deployment_slots():
		var slot_id := StringName(slot_data.get("slot_id", &""))
		var lane_id := StringName(slot_data.get("lane_id", &""))
		var slot = PrototypeDeploymentSlot.new()
		slot.configure(slot_data, PrototypeConfig.get_route_color(lane_id))
		slot.pressed.connect(on_deployment_slot_pressed.bind(slot_id))
		deployment_layer.add_child(slot)
		deployment_slots[slot_id] = slot
	update_deployment_positions()


func setup_character_roster() -> void:
	for character_id: StringName in PrototypeConfig.get_character_ids():
		var definition := PrototypeConfig.get_character_definition(character_id)
		var character = PrototypeCharacter.new()
		character.configure(character_id, definition)
		character.character_died.connect(handle_character_death)
		character_layer.add_child(character)
		character_nodes[character_id] = character

		var card := Button.new()
		card.name = "CharacterCard_%s" % String(character_id)
		card.custom_minimum_size = Vector2(190.0, 44.0)
		card.focus_mode = Control.FOCUS_NONE
		card.add_theme_font_size_override("font_size", 15)
		card.pressed.connect(select_character.bind(character_id))
		character_card_row.add_child(card)
		character_cards[character_id] = card
	select_character(selected_character_id)


func on_scenario_selected(option_index: int) -> void:
	if battle_state != BattleState.READY:
		return
	var scenario_id := StringName(scenario_option.get_item_metadata(option_index))
	select_scenario(scenario_id)


func select_scenario(scenario_id: StringName) -> bool:
	if battle_state != BattleState.READY:
		return false
	if not PrototypeConfig.SCENARIOS.has(scenario_id):
		return false
	selected_scenario_id = scenario_id
	var option_index := find_scenario_option(scenario_id)
	if option_index >= 0 and scenario_option.selected != option_index:
		scenario_option.select(option_index)
	rebuild_spawn_plan()
	active_spawn_point_ids = PrototypeConfig.get_active_spawn_point_ids(
		selected_scenario_id
	)
	refresh_route_view_spawn_points()
	update_ui()
	return true


func find_scenario_option(scenario_id: StringName) -> int:
	for option_index in range(scenario_option.item_count):
		if StringName(scenario_option.get_item_metadata(option_index)) == scenario_id:
			return option_index
	return -1


func select_character(character_id: StringName) -> bool:
	if not character_nodes.has(character_id):
		return false
	selected_character_id = character_id
	refresh_deployment_visuals()
	return true


func on_deployment_slot_pressed(slot_id: StringName) -> void:
	if battle_state != BattleState.READY or not deployment_slots.has(slot_id):
		return
	var slot = deployment_slots[slot_id]
	if slot.deployed_character_id != &"":
		select_character(slot.deployed_character_id)
		return
	if selected_character_id == &"":
		return
	deploy_character(selected_character_id, slot_id)


func deploy_character(character_id: StringName, slot_id: StringName) -> bool:
	if battle_state != BattleState.READY:
		return false
	if not character_nodes.has(character_id) or not deployment_slots.has(slot_id):
		return false
	var target_slot = deployment_slots[slot_id]
	if (
		target_slot.deployed_character_id != &""
		and target_slot.deployed_character_id != character_id
	):
		return false
	var previous_slot_id := StringName(deployment_by_character.get(character_id, &""))
	if previous_slot_id != &"" and previous_slot_id != slot_id:
		var previous_slot = deployment_slots.get(previous_slot_id)
		if is_instance_valid(previous_slot):
			previous_slot.set_deployed_character(&"", "")
	if target_slot.deployed_character_id == character_id and previous_slot_id == slot_id:
		select_character(character_id)
		return true
	deployment_by_character[character_id] = slot_id
	var character = character_nodes[character_id]
	var definition := PrototypeConfig.get_character_definition(character_id)
	target_slot.set_deployed_character(
		character_id,
		String(definition.get("display_name", character_id))
	)
	character.deploy_to(
		slot_id,
		target_slot.lane_id,
		PrototypeConfig.get_deployment_position(slot_id, battlefield_content.size)
	)
	character.reset_combat_state()
	select_character(character_id)
	refresh_deployment_visuals()
	return true


func undeploy_character(character_id: StringName) -> bool:
	if battle_state != BattleState.READY or not character_nodes.has(character_id):
		return false
	var slot_id := StringName(deployment_by_character.get(character_id, &""))
	if slot_id == &"":
		return false
	var slot = deployment_slots.get(slot_id)
	if is_instance_valid(slot):
		slot.set_deployed_character(&"", "")
	deployment_by_character.erase(character_id)
	var character = character_nodes[character_id]
	character.undeploy()
	character.reset_combat_state()
	refresh_deployment_visuals()
	return true


func undeploy_selected_character() -> bool:
	return undeploy_character(selected_character_id)


func clear_deployment() -> bool:
	if battle_state != BattleState.READY:
		return false
	for character_id: StringName in PrototypeConfig.get_character_ids():
		var slot_id := StringName(deployment_by_character.get(character_id, &""))
		if slot_id != &"":
			var slot = deployment_slots.get(slot_id)
			if is_instance_valid(slot):
				slot.set_deployed_character(&"", "")
		var character = character_nodes.get(character_id)
		if is_instance_valid(character):
			character.undeploy()
			character.reset_combat_state()
	deployment_by_character.clear()
	refresh_deployment_visuals()
	return true


func apply_recommended_deployment() -> bool:
	if battle_state != BattleState.READY:
		return false
	clear_deployment()
	var recommended := PrototypeConfig.get_recommended_deployment(
		selected_scenario_id
	)
	for character_id: StringName in PrototypeConfig.get_character_ids():
		var slot_id := StringName(
			recommended.get(character_id, &"")
		)
		if slot_id == &"" or not deploy_character(character_id, slot_id):
			return false
	select_character(&"guard")
	refresh_deployment_visuals()
	return true


func start_battle() -> bool:
	if battle_state != BattleState.READY:
		return false
	clear_active_enemies()
	reset_character_combat_states()
	village_durability = PrototypeConfig.VILLAGE_MAX_DURABILITY
	rebuild_spawn_plan()
	spawn_index = 0
	spawn_elapsed = 0.0
	generated_enemy_count = 0
	killed_enemy_count = 0
	leaked_enemy_count = 0
	resolved_enemy_count = 0
	settled_enemy_ids.clear()
	generated_by_route = create_empty_route_counts()
	generated_by_spawn_point.clear()
	generated_by_monster_type = create_empty_monster_type_counts()
	active_spawn_point_ids = PrototypeConfig.get_active_spawn_point_ids(
		selected_scenario_id
	)
	refresh_route_view_spawn_points()
	next_enemy_sequence = 1
	block_event_count = 0
	enemy_attack_event_count = 0
	character_attack_event_count = 0
	healing_event_count = 0
	formation_damage_reduction_event_count = 0
	formation_damage_prevented_total = 0
	speed_effect_observed_ids.clear()
	demo_control_resistance_triggered = false
	battle_elapsed = 0.0
	formation_manager.reset_runtime(
		is_formation_scenario_enabled(),
		run_sequence
	)
	battle_state = BattleState.RUNNING
	spawn_next_enemy()
	update_ui()
	return true


func restart_battle() -> void:
	run_sequence += 1
	clear_active_enemies()
	reset_character_combat_states()
	battle_state = BattleState.READY
	village_durability = PrototypeConfig.VILLAGE_MAX_DURABILITY
	rebuild_spawn_plan()
	spawn_index = 0
	spawn_elapsed = 0.0
	generated_enemy_count = 0
	killed_enemy_count = 0
	leaked_enemy_count = 0
	resolved_enemy_count = 0
	settled_enemy_ids.clear()
	generated_by_route = create_empty_route_counts()
	generated_by_spawn_point.clear()
	generated_by_monster_type = create_empty_monster_type_counts()
	active_spawn_point_ids = PrototypeConfig.get_active_spawn_point_ids(
		selected_scenario_id
	)
	refresh_route_view_spawn_points()
	next_enemy_sequence = 1
	block_event_count = 0
	enemy_attack_event_count = 0
	character_attack_event_count = 0
	healing_event_count = 0
	formation_damage_reduction_event_count = 0
	formation_damage_prevented_total = 0
	speed_effect_observed_ids.clear()
	demo_control_resistance_triggered = false
	battle_elapsed = 0.0
	formation_manager.reset_runtime(
		is_formation_scenario_enabled(),
		run_sequence
	)
	update_ui()


func set_automatic_simulation(enabled: bool) -> void:
	automatic_simulation = enabled
	set_process(enabled)


func simulate_step(delta: float) -> void:
	if battle_state != BattleState.RUNNING:
		return
	var safe_delta := maxf(0.0, delta)
	battle_elapsed += safe_delta
	process_spawning(safe_delta)
	update_enemy_blocking()
	var enemies_this_step: Array = active_enemies.values()
	var progress_before_move: Dictionary = {}
	for enemy in enemies_this_step:
		if battle_state != BattleState.RUNNING:
			break
		if not is_instance_valid(enemy) or not active_enemies.has(enemy.runtime_id):
			continue
		progress_before_move[enemy.runtime_id] = enemy.route_progress
		if enemy.blocked_by_character_id != &"":
			enemy.advance_blocked_combat(safe_delta)
		else:
			enemy.advance(safe_delta)
		if (
			active_enemies.has(enemy.runtime_id)
			and enemy.formation_speed_multiplier > 1.0
			and float(enemy.route_progress)
				> float(progress_before_move.get(enemy.runtime_id, enemy.route_progress))
		):
			speed_effect_observed_ids[enemy.runtime_id] = true
	if battle_state == BattleState.RUNNING:
		formation_manager.update_formations(safe_delta, active_enemies)
		run_formation_demo_control_resistance()
	update_enemy_blocking()
	if battle_state == BattleState.RUNNING:
		simulate_character_actions(safe_delta)
		formation_manager.update_formations(0.0, active_enemies)
		update_enemy_blocking()
	evaluate_victory()
	update_ui()


func process_spawning(delta: float) -> void:
	if spawn_index >= spawn_plan.size():
		return
	spawn_elapsed += delta
	while (
		battle_state == BattleState.RUNNING
		and spawn_index < spawn_plan.size()
	):
		var required_delay := get_next_spawn_delay()
		if spawn_elapsed < required_delay:
			break
		spawn_elapsed -= required_delay
		spawn_next_enemy()


func get_current_spawn_interval() -> float:
	var scenario := PrototypeConfig.get_scenario(selected_scenario_id)
	return maxf(
		0.05,
		float(scenario.get("spawn_interval", PrototypeConfig.SPAWN_INTERVAL_SECONDS))
	)


func get_next_spawn_delay() -> float:
	var delay := get_current_spawn_interval()
	if spawn_index <= 0 or spawn_index > spawn_entries.size():
		return delay
	var previous_entry: Dictionary = spawn_entries[spawn_index - 1]
	return delay + maxf(0.0, float(previous_entry.get("delay_after", 0.0)))


func spawn_next_enemy() -> void:
	if battle_state != BattleState.RUNNING or spawn_index >= spawn_plan.size():
		return
	var entry: Dictionary = (
		spawn_entries[spawn_index]
		if spawn_index < spawn_entries.size()
		else {
			"route_id": spawn_plan[spawn_index],
			"monster_type": &"charge",
		}
	)
	spawn_enemy_for_route(
		StringName(entry.get("route_id", spawn_plan[spawn_index])),
		StringName(entry.get("monster_type", &"charge")),
		entry
	)
	spawn_index += 1


func spawn_enemy_for_route(
	route_id: StringName,
	monster_type: StringName = &"charge",
	overrides: Dictionary = {}
):
	if battle_state != BattleState.RUNNING:
		return null
	var spawn_point_id := StringName(overrides.get("spawn_point_id", &""))
	var spawn_point := PrototypeConfig.get_spawn_point(spawn_point_id)
	var resolved_route_id := route_id
	if resolved_route_id == &"" and not spawn_point.is_empty():
		resolved_route_id = StringName(spawn_point.get("route_id", &""))
	var route_data := PrototypeConfig.get_route_runtime_data(resolved_route_id)
	var route_group_id := StringName(overrides.get(
		"route_group_id",
		spawn_point.get(
			"route_group_id",
			route_data.get("route_group_id", &"")
		)
	))
	var blocking_lane_id := StringName(overrides.get(
		"blocking_lane_id",
		spawn_point.get(
			"blocking_lane_id",
			route_data.get("blocking_lane_id", resolved_route_id)
		)
	))
	var formation_route_index := int(overrides.get(
		"formation_route_index",
		spawn_point.get(
			"formation_route_index",
			route_data.get("formation_route_index", 0)
		)
	))
	var route_points := get_route_points(resolved_route_id)
	if route_points.size() < 2:
		push_error(
			"Prototype route %s has fewer than two points"
				% String(resolved_route_id)
		)
		return null
	var enemy = PrototypeEnemy.new()
	var sequence := next_enemy_sequence
	var enemy_id := StringName("run_%d_enemy_%d" % [run_sequence, sequence])
	next_enemy_sequence += 1
	var monster_definition := PrototypeConfig.get_monster_definition(monster_type)
	var enemy_color: Color = (
		monster_definition.get("body_color", Color.WHITE)
		if is_formation_scenario_enabled()
		else PrototypeConfig.get_route_color(resolved_route_id)
	)
	enemy.name = String(enemy_id)
	enemy.configure(
		enemy_id,
		resolved_route_id,
		sequence,
		float(overrides.get(
			"move_speed",
			monster_definition.get("move_speed", PrototypeConfig.ENEMY_MOVE_SPEED)
		)),
		int(overrides.get(
			"leak_damage",
			monster_definition.get("leak_damage", PrototypeConfig.ENEMY_LEAK_DAMAGE)
		)),
		route_points,
		enemy_color,
		int(overrides.get(
			"max_health",
			monster_definition.get("max_health", PrototypeConfig.ENEMY_MAX_HEALTH)
		)),
		int(overrides.get(
			"attack_damage",
			monster_definition.get(
				"attack_damage",
				PrototypeConfig.ENEMY_ATTACK_DAMAGE
			)
		)),
		float(overrides.get(
			"attack_interval",
			monster_definition.get(
				"attack_interval",
				PrototypeConfig.ENEMY_ATTACK_INTERVAL
			)
		)),
		monster_type,
		spawn_point_id,
		route_group_id,
		blocking_lane_id,
		formation_route_index
	)
	enemy.reached_entrance.connect(handle_enemy_arrival)
	enemy.enemy_died.connect(handle_enemy_death)
	enemy.attacked_blocker.connect(handle_enemy_attack)
	enemy.damage_resolved.connect(handle_enemy_damage_resolved)
	enemy_layer.add_child(enemy)
	active_enemies[enemy_id] = enemy
	generated_enemy_count += 1
	generated_by_route[resolved_route_id] = int(
		generated_by_route.get(resolved_route_id, 0)
	) + 1
	if spawn_point_id != &"":
		generated_by_spawn_point[spawn_point_id] = int(
			generated_by_spawn_point.get(spawn_point_id, 0)
		) + 1
	generated_by_monster_type[monster_type] = int(
		generated_by_monster_type.get(monster_type, 0)
	) + 1
	return enemy


func update_enemy_blocking() -> void:
	if battle_state != BattleState.RUNNING:
		return
	for enemy in active_enemies.values():
		if not is_instance_valid(enemy):
			continue
		if enemy.blocked_by_character_id == &"":
			continue
		var blocker = character_nodes.get(enemy.blocked_by_character_id)
		if not can_character_block_enemy(blocker, enemy):
			release_enemy_blocker(enemy)
	for enemy in active_enemies.values():
		if not is_instance_valid(enemy):
			continue
		if (
			enemy.blocked_by_character_id != &""
			or enemy.is_dead
			or enemy.settlement_completed
		):
			continue
		for character_id: StringName in PrototypeConfig.get_character_ids():
			var character = character_nodes[character_id]
			if not can_character_block_enemy(character, enemy):
				continue
			if character.add_blocked_enemy(enemy.runtime_id) \
					and enemy.set_blocker(character.character_id):
				block_event_count += 1
				break
			character.remove_blocked_enemy(enemy.runtime_id)


func can_character_block_enemy(character, enemy) -> bool:
	if not is_instance_valid(character) or not is_instance_valid(enemy):
		return false
	if (
		battle_state != BattleState.RUNNING
		or character.role_id != &"guard"
		or not character.is_deployed()
		or not character.is_alive
		or enemy.is_dead
		or enemy.settlement_completed
		or character.lane_id != enemy.blocking_lane_id
	):
		return false
	var already_blocking: bool = character.blocked_enemy_ids.has(enemy.runtime_id)
	if not already_blocking and not character.has_block_capacity():
		return false
	return character.position.distance_to(enemy.position) <= character.action_range


func release_enemy_blocker(enemy) -> void:
	if not is_instance_valid(enemy):
		return
	var blocker_id := StringName(enemy.blocked_by_character_id)
	if blocker_id == &"":
		return
	var blocker = character_nodes.get(blocker_id)
	if is_instance_valid(blocker):
		blocker.remove_blocked_enemy(enemy.runtime_id)
	enemy.clear_blocker(blocker_id)


func simulate_character_actions(delta: float) -> void:
	var enemies: Array = active_enemies.values()
	var allies: Array = character_nodes.values()
	for character_id: StringName in PrototypeConfig.get_character_ids():
		if battle_state != BattleState.RUNNING:
			break
		var character = character_nodes[character_id]
		var action: Dictionary = character.simulate_action(delta, enemies, allies)
		if action.is_empty():
			continue
		if StringName(action.get("type", &"")) == &"heal":
			healing_event_count += 1
		else:
			character_attack_event_count += 1


func handle_enemy_damage_resolved(
	enemy_id: StringName,
	raw_damage: int,
	applied_damage: int,
	damage_source_type: StringName,
	ranged_reduction: float
) -> void:
	if not active_enemies.has(enemy_id):
		return
	if (
		damage_source_type == PrototypeConfig.DAMAGE_SOURCE_RANGED
		and ranged_reduction > 0.0
		and applied_damage > 0
	):
		formation_damage_reduction_event_count += 1
		formation_damage_prevented_total += maxi(
			0,
			raw_damage - applied_damage
		)


func handle_enemy_attack(
	enemy_id: StringName,
	character_id: StringName,
	damage: int
) -> void:
	if battle_state != BattleState.RUNNING or not active_enemies.has(enemy_id):
		return
	var enemy = active_enemies[enemy_id]
	var character = character_nodes.get(character_id)
	if (
		not is_instance_valid(enemy)
		or not is_instance_valid(character)
		or enemy.is_dead
		or enemy.blocked_by_character_id != character_id
		or not character.is_alive
	):
		return
	var applied := int(character.take_damage(maxi(0, damage)))
	if applied > 0:
		enemy_attack_event_count += 1


func handle_character_death(character_id: StringName) -> void:
	var character = character_nodes.get(character_id)
	if not is_instance_valid(character):
		return
	var blocked_ids: Array[StringName] = character.blocked_enemy_ids.duplicate()
	for enemy_id: StringName in blocked_ids:
		var enemy = active_enemies.get(enemy_id)
		if is_instance_valid(enemy):
			enemy.clear_blocker(character_id)
	character.clear_blocked_enemies()
	update_ui()


func handle_enemy_death(enemy_id: StringName) -> void:
	if settled_enemy_ids.has(enemy_id) or not active_enemies.has(enemy_id):
		return
	var enemy = active_enemies[enemy_id]
	if not is_instance_valid(enemy) or not enemy.is_dead:
		return
	formation_manager.handle_member_removed(
		enemy_id,
		PrototypeConfig.INTERRUPTION_MEMBER_DIED,
		active_enemies
	)
	settled_enemy_ids[enemy_id] = &"killed"
	enemy.mark_death_settled()
	killed_enemy_count += 1
	resolved_enemy_count = killed_enemy_count + leaked_enemy_count
	remove_enemy(enemy_id)
	evaluate_victory()
	update_ui()


func handle_enemy_arrival(
	enemy_id: StringName,
	_route_id: StringName,
	leak_damage: int
) -> void:
	if settled_enemy_ids.has(enemy_id):
		return
	if battle_state != BattleState.RUNNING:
		remove_enemy(enemy_id)
		return
	if not active_enemies.has(enemy_id):
		return
	var enemy = active_enemies[enemy_id]
	if is_instance_valid(enemy) and enemy.is_dead:
		return
	formation_manager.handle_member_removed(
		enemy_id,
		PrototypeConfig.INTERRUPTION_MEMBER_LEAKED,
		active_enemies
	)
	settled_enemy_ids[enemy_id] = &"leaked"
	leaked_enemy_count += 1
	resolved_enemy_count = killed_enemy_count + leaked_enemy_count
	village_durability = maxi(0, village_durability - maxi(0, leak_damage))
	remove_enemy(enemy_id)
	if village_durability <= 0:
		finish_defeat()
		return
	evaluate_victory()
	update_ui()


func remove_enemy(enemy_id: StringName) -> void:
	var enemy = active_enemies.get(enemy_id)
	active_enemies.erase(enemy_id)
	if is_instance_valid(enemy):
		release_enemy_blocker(enemy)
		enemy.cancel()
		enemy.queue_free()


func clear_active_enemies() -> void:
	if is_instance_valid(formation_manager):
		formation_manager.clear_all_formations(active_enemies)
	for enemy in active_enemies.values():
		if not is_instance_valid(enemy):
			continue
		release_enemy_blocker(enemy)
		enemy.cancel()
		enemy.queue_free()
	active_enemies.clear()
	for character in character_nodes.values():
		if is_instance_valid(character):
			character.clear_blocked_enemies()


func reset_character_combat_states() -> void:
	for character in character_nodes.values():
		if is_instance_valid(character):
			character.reset_combat_state()


func evaluate_victory() -> void:
	if battle_state != BattleState.RUNNING:
		return
	var all_enemies_generated := spawn_index >= spawn_plan.size()
	if (
		all_enemies_generated
		and active_enemies.is_empty()
		and village_durability > 0
		and resolved_enemy_count == spawn_plan.size()
	):
		finish_victory()


func finish_victory() -> void:
	if battle_state != BattleState.RUNNING or village_durability <= 0:
		return
	battle_state = BattleState.VICTORY
	battle_finish_count += 1
	update_ui()
	battle_finished.emit(&"victory")


func finish_defeat() -> void:
	if battle_state != BattleState.RUNNING:
		return
	battle_state = BattleState.DEFEAT
	village_durability = 0
	battle_finish_count += 1
	clear_active_enemies()
	update_ui()
	battle_finished.emit(&"defeat")


func on_battlefield_resized() -> void:
	route_view.queue_redraw()
	formation_manager.queue_redraw()
	update_deployment_positions()
	for enemy in active_enemies.values():
		if is_instance_valid(enemy):
			enemy.set_route_points(get_route_points(enemy.route_id), true)


func update_deployment_positions() -> void:
	if not is_instance_valid(battlefield_content):
		return
	for slot_id in deployment_slots.keys():
		var slot = deployment_slots[slot_id]
		slot.update_battlefield_position(battlefield_content.size)
	for character_id in deployment_by_character.keys():
		var slot_id := StringName(deployment_by_character[character_id])
		var character = character_nodes.get(character_id)
		var slot = deployment_slots.get(slot_id)
		if is_instance_valid(character) and is_instance_valid(slot):
			character.deploy_to(
				slot_id,
				slot.lane_id,
				PrototypeConfig.get_deployment_position(
					slot_id,
					battlefield_content.size
				)
			)


func get_route_ids() -> Array[StringName]:
	return PrototypeConfig.get_route_ids()


func get_route_points(route_id: StringName) -> PackedVector2Array:
	return PrototypeConfig.get_route_points(route_id, battlefield_content.size)


func get_village_entrance_point() -> Vector2:
	return PrototypeConfig.get_village_entrance_point(battlefield_content.size)


func get_formation_zone(zone_type: StringName) -> Dictionary:
	return PrototypeConfig.get_formation_zone_by_type(
		zone_type,
		battlefield_content.size
	)


func get_formation_zone_center(zone_type: StringName) -> Vector2:
	var zone := get_formation_zone(zone_type)
	var rect: Rect2 = zone.get("rect", Rect2())
	return rect.get_center()


func get_spawn_point_position(spawn_point_id: StringName) -> Vector2:
	return PrototypeConfig.get_spawn_point_position(
		spawn_point_id,
		battlefield_content.size
	)


func refresh_route_view_spawn_points() -> void:
	if is_instance_valid(route_view) \
			and route_view.has_method("set_active_spawn_point_ids"):
		route_view.set_active_spawn_point_ids(active_spawn_point_ids)


func get_active_enemy_nodes() -> Array:
	return active_enemies.values()


func get_formation_manager():
	return formation_manager


func get_formation_groups_snapshot() -> Array:
	return formation_manager.get_groups_snapshot()


func get_formation_stats_snapshot() -> Dictionary:
	return formation_manager.get_stats_snapshot(active_enemies)


func interrupt_enemy_formation(
	enemy_id: StringName,
	reason: StringName
) -> Dictionary:
	if battle_state != BattleState.RUNNING or not active_enemies.has(enemy_id):
		return {"resisted": false, "interrupted": false}
	return formation_manager.interrupt_member(
		enemy_id,
		reason,
		active_enemies
	)


func get_character_node(character_id: StringName):
	return character_nodes.get(character_id)


func get_deployment_slot_node(slot_id: StringName):
	return deployment_slots.get(slot_id)


func get_deployment_slots_snapshot() -> Array:
	var snapshots: Array = []
	for slot_data: Dictionary in PrototypeConfig.get_deployment_slots():
		var slot_id := StringName(slot_data.get("slot_id", &""))
		var slot = deployment_slots.get(slot_id)
		if is_instance_valid(slot):
			snapshots.append(slot.get_slot_snapshot())
	return snapshots


func get_character_snapshots() -> Array:
	var snapshots: Array = []
	for character_id: StringName in PrototypeConfig.get_character_ids():
		var character = character_nodes.get(character_id)
		if is_instance_valid(character):
			snapshots.append(character.get_runtime_snapshot())
	return snapshots


func get_selected_route_sequence() -> Array[StringName]:
	var sequence: Array[StringName] = []
	for entry: Dictionary in PrototypeConfig.get_scenario_spawn_entries(
		selected_scenario_id
	):
		sequence.append(StringName(entry.get("route_id", &"top")))
	return sequence


func rebuild_spawn_plan() -> void:
	spawn_entries = PrototypeConfig.get_scenario_spawn_entries(
		selected_scenario_id
	)
	spawn_plan.clear()
	for entry: Dictionary in spawn_entries:
		spawn_plan.append(StringName(entry.get("route_id", &"top")))


func is_formation_scenario_enabled() -> bool:
	var scenario := PrototypeConfig.get_scenario(selected_scenario_id)
	return bool(scenario.get("formations_enabled", false))


func run_formation_demo_control_resistance() -> void:
	if (
		selected_scenario_id != &"formation_demo"
		or demo_control_resistance_triggered
	):
		return
	var scenario := PrototypeConfig.get_scenario(selected_scenario_id)
	if not bool(scenario.get("auto_demo_control_resistance", false)):
		return
	var charge_b = formation_manager.find_complete_group(
		&"charge",
		PrototypeConfig.FORMATION_LEVEL_B
	)
	if charge_b == null or charge_b.member_ids.is_empty():
		return
	var result: Dictionary = formation_manager.interrupt_member(
		charge_b.member_ids[0],
		PrototypeConfig.INTERRUPTION_STUN,
		active_enemies
	)
	if bool(result.get("resisted", false)):
		demo_control_resistance_triggered = true


func create_empty_route_counts() -> Dictionary:
	var counts: Dictionary = {}
	for route_id: StringName in PrototypeConfig.get_route_ids():
		counts[route_id] = 0
	return counts


func create_empty_monster_type_counts() -> Dictionary:
	var counts: Dictionary = {}
	for monster_type: StringName in PrototypeConfig.get_monster_type_ids():
		counts[monster_type] = 0
	return counts


func get_state_name() -> String:
	return String(STATE_NAMES.get(battle_state, "UNKNOWN"))


func get_battle_snapshot() -> Dictionary:
	return {
		"state": get_state_name(),
		"scenario_id": selected_scenario_id,
		"village_durability": village_durability,
		"max_durability": PrototypeConfig.VILLAGE_MAX_DURABILITY,
		"planned_enemy_count": spawn_plan.size(),
		"generated_enemy_count": generated_enemy_count,
		"active_enemy_count": active_enemies.size(),
		"killed_enemy_count": killed_enemy_count,
		"leaked_enemy_count": leaked_enemy_count,
		"resolved_enemy_count": resolved_enemy_count,
		"spawn_index": spawn_index,
		"spawn_elapsed": spawn_elapsed,
		"generated_by_route": generated_by_route.duplicate(true),
		"generated_by_spawn_point": generated_by_spawn_point.duplicate(true),
		"generated_by_monster_type": generated_by_monster_type.duplicate(true),
		"active_spawn_point_ids": active_spawn_point_ids.duplicate(),
		"battle_elapsed": battle_elapsed,
		"battle_finish_count": battle_finish_count,
		"run_sequence": run_sequence,
		"block_event_count": block_event_count,
		"enemy_attack_event_count": enemy_attack_event_count,
		"character_attack_event_count": character_attack_event_count,
		"healing_event_count": healing_event_count,
		"formation_damage_reduction_event_count":
			formation_damage_reduction_event_count,
		"formation_damage_prevented_total": formation_damage_prevented_total,
		"speed_effect_observed_count": speed_effect_observed_ids.size(),
		"speed_effect_observed_ids": speed_effect_observed_ids.duplicate(true),
		"demo_control_resistance_triggered":
			demo_control_resistance_triggered,
		"formation_stats": get_formation_stats_snapshot(),
		"formation_groups": get_formation_groups_snapshot(),
		"deployment": deployment_by_character.duplicate(true),
		"characters": get_character_snapshots(),
	}


func refresh_deployment_visuals() -> void:
	if not is_node_ready():
		return
	for character_id: StringName in PrototypeConfig.get_character_ids():
		var character = character_nodes[character_id]
		var definition := PrototypeConfig.get_character_definition(character_id)
		var card: Button = character_cards[character_id]
		var slot_id := StringName(deployment_by_character.get(character_id, &""))
		var selected_prefix := "▶ " if selected_character_id == character_id else ""
		card.text = "%s%s｜HP%d｜范围%d%s" % [
			selected_prefix,
			String(definition.get("display_name", character_id)),
			int(definition.get("max_health", 0)),
			int(definition.get("action_range", 0)),
			"\n%s" % String(slot_id) if slot_id != &"" else "\n未部署",
		]
		character.set_selected(selected_character_id == character_id)
	for slot in deployment_slots.values():
		slot.set_deployment_locked(battle_state != BattleState.READY)
	var selected = character_nodes.get(selected_character_id)
	if is_instance_valid(selected):
		selected_character_label.text = "当前选择：%s｜%s｜范围 %.0f" % [
			selected.display_name,
			String(selected.role_id),
			selected.action_range,
		]
	recommend_button.disabled = battle_state != BattleState.READY
	clear_deployment_button.disabled = battle_state != BattleState.READY
	undeploy_button.disabled = (
		battle_state != BattleState.READY
		or not deployment_by_character.has(selected_character_id)
	)


func update_ui() -> void:
	if not is_node_ready():
		return
	var scenario := PrototypeConfig.get_scenario(selected_scenario_id)
	var scenario_name := String(scenario.get("display_name", selected_scenario_id))
	var planned_count := spawn_plan.size()
	durability_label.text = "村庄耐久：%d/%d" % [
		village_durability,
		PrototypeConfig.VILLAGE_MAX_DURABILITY,
	]
	state_label.text = "当前状态：%s" % get_state_name()
	generated_label.text = "已生成：%d/%d" % [generated_enemy_count, planned_count]
	active_label.text = "场上活动：%d" % active_enemies.size()
	killed_label.text = "已击杀：%d" % killed_enemy_count
	leaked_label.text = "已漏怪：%d" % leaked_enemy_count
	resolved_label.text = "已结算：%d" % resolved_enemy_count
	scenario_label.text = "当前方案：%s" % scenario_name
	var formation_stats := get_formation_stats_snapshot()
	var route_spans: Dictionary = formation_stats.get(
		"completed_a_route_spans",
		{}
	)
	formation_stats_label.text = (
		"单体 %d｜FORMING_A %d｜A阵 %d｜FORMING_B %d｜B阵 %d"
		+ "｜A完成 %d｜B完成 %d｜中断 %d｜降级 %d"
		+ "\n邻轨跨度 A/B=%d/%d｜A完成跨度 0/1/2=%d/%d/%d"
	) % [
		int(formation_stats.get("single_count", 0)),
		int(formation_stats.get("forming_a_count", 0)),
		int(formation_stats.get("a_count", 0)),
		int(formation_stats.get("forming_b_count", 0)),
		int(formation_stats.get("b_count", 0)),
		int(formation_stats.get("completed_a_count", 0)),
		int(formation_stats.get("completed_b_count", 0)),
		int(formation_stats.get("interrupted_count", 0)),
		int(formation_stats.get("downgrade_count", 0)),
		int(formation_stats.get("a_pair_neighbor_route_span", 0)),
		int(formation_stats.get("b_pair_neighbor_route_span", 0)),
		int(route_spans.get(0, 0)),
		int(route_spans.get(1, 0)),
		int(route_spans.get(2, 0)),
	]
	start_button.disabled = battle_state != BattleState.READY
	scenario_option.disabled = battle_state != BattleState.READY
	refresh_deployment_visuals()
	match battle_state:
		BattleState.READY:
			result_label.text = "准备就绪：可部署0～4名角色后开始"
			result_label.add_theme_color_override(
				"font_color", Color(0.72, 0.80, 0.90)
			)
		BattleState.RUNNING:
			result_label.text = "自动战斗进行中：部署已锁定"
			result_label.add_theme_color_override(
				"font_color", Color(0.66, 0.82, 1.0)
			)
		BattleState.VICTORY:
			result_label.text = "胜利：全部敌人已击杀或漏怪结算"
			result_label.add_theme_color_override(
				"font_color", Color(0.45, 1.0, 0.66)
			)
		BattleState.DEFEAT:
			result_label.text = "失败：村庄入口耐久归零"
			result_label.add_theme_color_override(
				"font_color", Color(1.0, 0.45, 0.48)
			)

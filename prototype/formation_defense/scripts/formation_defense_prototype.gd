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
const PrototypeProjectileVisual := preload(
	"res://prototype/formation_defense/scripts/formation_defense_projectile_visual.gd"
)
const PrototypeWaveDirector := preload(
	"res://prototype/formation_defense/scripts/formation_defense_wave_director.gd"
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
const LOGICAL_BATTLEFIELD_SIZE := Vector2(1802.0, 414.0)

@onready var battlefield_content: Control = %BattlefieldContent
@onready var battlefield: PanelContainer = %Battlefield
@onready var stage_label: Label = %StageLabel
@onready var route_view: Control = %RouteView
@onready var deployment_layer: Control = %DeploymentLayer
@onready var formation_manager: Node2D = %FormationLayer
@onready var command_controller: Node = %CommandController
@onready var enemy_layer: Node2D = %EnemyLayer
@onready var character_layer: Node2D = %CharacterLayer
@onready var projectile_visual_layer: Node2D = %ProjectileVisualLayer
@onready var battlefield_caption: Label = $RootMargin/Content/Battlefield/BattlefieldContent/BattlefieldCaption
@onready var village_entrance: PanelContainer = %VillageEntrance
@onready var spawn_port_top: PanelContainer = %SpawnPortTop
@onready var spawn_port_middle: PanelContainer = %SpawnPortMiddle
@onready var spawn_port_bottom: PanelContainer = %SpawnPortBottom
@onready var durability_label: Label = %DurabilityLabel
@onready var state_label: Label = %StateLabel
@onready var generated_label: Label = %GeneratedLabel
@onready var active_label: Label = %ActiveLabel
@onready var killed_label: Label = %KilledLabel
@onready var leaked_label: Label = %LeakedLabel
@onready var resolved_label: Label = %ResolvedLabel
@onready var scenario_label: Label = %ScenarioLabel
@onready var formation_stats_label: Label = %FormationStatsLabel
@onready var wave_debug_label: Label = %WaveDebugLabel
@onready var command_status_label: Label = %CommandStatusLabel
@onready var scenario_option: OptionButton = %ScenarioOption
@onready var start_button: Button = %StartButton
@onready var restart_button: Button = %RestartButton
@onready var character_card_row: HBoxContainer = %CharacterCardRow
@onready var selected_character_label: Label = %SelectedCharacterLabel
@onready var recommend_button: Button = %RecommendButton
@onready var clear_deployment_button: Button = %ClearDeploymentButton
@onready var undeploy_button: Button = %UndeployButton
@onready var result_label: Label = %ResultLabel
@onready var root_margin: MarginContainer = $RootMargin
@onready var compact_durability_label: Label = %CompactDurabilityLabel
@onready var compact_state_label: Label = %CompactStateLabel
@onready var compact_wave_label: Label = %CompactWaveLabel
@onready var compact_command_label: Label = %CompactCommandLabel
@onready var debug_toggle_button: Button = %DebugToggleButton
@onready var debug_close_button: Button = %DebugCloseButton
@onready var debug_drawer: PanelContainer = %DebugDrawer
@onready var debug_content: VBoxContainer = %DebugContent

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
var formation_damage_reduction_events_by_profile: Dictionary = {}
var formation_damage_prevented_by_profile: Dictionary = {}
var speed_effect_observed_ids: Dictionary = {}
var demo_control_resistance_triggered := false
var battle_elapsed := 0.0
var attack_visual_spawn_count := 0
var battlefield_display_root: Node2D = null
var debug_panel_open := false
var layout_viewport_size := Vector2.ZERO
var position_mapping_scale := Vector2.ONE
var uniform_visual_scale := 1.0
var wave_director: Node = null


func _ready() -> void:
	command_controller.bind_runtime(self)
	wave_director = PrototypeWaveDirector.new()
	wave_director.name = "WaveDirector"
	add_child(wave_director)
	wave_director.spawn_requested.connect(handle_wave_spawn_requested)
	stage_label.text = "V2-5A 战场全屏化与折叠调试面板"
	setup_fullscreen_layout()
	setup_scenario_options()
	setup_deployment_slots()
	setup_character_roster()
	start_button.pressed.connect(start_battle)
	restart_button.pressed.connect(restart_battle)
	scenario_option.item_selected.connect(on_scenario_selected)
	recommend_button.pressed.connect(apply_recommended_deployment)
	clear_deployment_button.pressed.connect(clear_deployment)
	undeploy_button.pressed.connect(undeploy_selected_character)
	debug_close_button.pressed.connect(set_debug_panel_open.bind(false))
	battlefield.gui_input.connect(on_battlefield_gui_input)
	battlefield_content.resized.connect(on_battlefield_resized)
	resized.connect(on_viewport_resized)
	restart_battle()


func setup_fullscreen_layout() -> void:
	var original_content := battlefield.get_parent()
	battlefield.reparent(self)
	move_child(battlefield, $Background.get_index() + 1)
	battlefield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	battlefield.z_index = 0
	battlefield.mouse_filter = Control.MOUSE_FILTER_STOP

	battlefield_display_root = Node2D.new()
	battlefield_display_root.name = "BattlefieldDisplayRoot"
	battlefield.add_child(battlefield_display_root)
	battlefield_content.reparent(battlefield_display_root)
	battlefield_content.set_anchors_preset(Control.PRESET_TOP_LEFT)
	battlefield_content.position = Vector2.ZERO
	battlefield_content.size = LOGICAL_BATTLEFIELD_SIZE

	for child in original_content.get_children():
		if child != battlefield:
			child.reparent(debug_content)
	root_margin.visible = false

	scenario_option.custom_minimum_size.x = 150.0
	start_button.custom_minimum_size.x = 100.0
	restart_button.custom_minimum_size.x = 100.0
	selected_character_label.custom_minimum_size.x = 120.0
	recommend_button.custom_minimum_size.x = 88.0
	clear_deployment_button.custom_minimum_size.x = 88.0
	undeploy_button.custom_minimum_size.x = 88.0
	set_debug_panel_open(false)
	apply_fullscreen_layout(size)


func on_viewport_resized() -> void:
	apply_fullscreen_layout(size)


func apply_fullscreen_layout(viewport_size: Vector2) -> void:
	if not is_instance_valid(battlefield_display_root):
		return
	var safe_size := Vector2(
		maxf(1.0, viewport_size.x),
		maxf(1.0, viewport_size.y)
	)
	layout_viewport_size = safe_size
	position_mapping_scale = Vector2(
		safe_size.x / LOGICAL_BATTLEFIELD_SIZE.x,
		safe_size.y / LOGICAL_BATTLEFIELD_SIZE.y
	)
	uniform_visual_scale = maxf(
		0.01,
		minf(safe_size.x / 1920.0, safe_size.y / 1080.0)
	)
	battlefield_display_root.position = Vector2.ZERO
	battlefield_display_root.scale = position_mapping_scale
	apply_visual_mapping()
	var drawer_width := clampf(safe_size.x * 0.30, 440.0, 520.0)
	debug_drawer.offset_left = -drawer_width
	debug_content.custom_minimum_size.x = maxf(416.0, drawer_width - 36.0)
	route_view.queue_redraw()
	formation_manager.queue_redraw()


func logic_to_screen_position(logic_position: Vector2) -> Vector2:
	return logic_position * position_mapping_scale


func screen_to_logic_position(screen_position: Vector2) -> Vector2:
	return Vector2(
		screen_position.x / maxf(position_mapping_scale.x, 0.0001),
		screen_position.y / maxf(position_mapping_scale.y, 0.0001)
	)


func logic_to_visual_layer_position(logic_position: Vector2) -> Vector2:
	return logic_to_screen_position(logic_position) / uniform_visual_scale


func get_visual_compensation_scale() -> Vector2:
	return Vector2(
		uniform_visual_scale / maxf(position_mapping_scale.x, 0.0001),
		uniform_visual_scale / maxf(position_mapping_scale.y, 0.0001)
	)


func apply_visual_mapping() -> void:
	var compensation := get_visual_compensation_scale()
	for visual_node in [
		battlefield_caption,
		village_entrance,
		spawn_port_top,
		spawn_port_middle,
		spawn_port_bottom,
	]:
		apply_control_visual_compensation(visual_node, compensation)
	for slot in deployment_slots.values():
		apply_control_visual_compensation(slot, compensation)
	for character in character_nodes.values():
		character.scale = compensation
	for enemy in active_enemies.values():
		if is_instance_valid(enemy):
			enemy.scale = compensation
	projectile_visual_layer.scale = compensation
	route_view.scale = compensation
	route_view.set_anchors_preset(Control.PRESET_TOP_LEFT)
	route_view.position = Vector2.ZERO
	route_view.size = layout_viewport_size / uniform_visual_scale
	route_view.configure_display_mapping(
		LOGICAL_BATTLEFIELD_SIZE,
		position_mapping_scale / uniform_visual_scale,
		uniform_visual_scale
	)
	formation_manager.scale = compensation
	formation_manager.configure_display_mapping(
		position_mapping_scale / uniform_visual_scale,
		uniform_visual_scale
	)


func apply_control_visual_compensation(
	control: Control,
	compensation: Vector2
) -> void:
	control.pivot_offset = control.size * 0.5
	control.scale = compensation


func get_resolution_layout_preview(window_size: Vector2) -> Dictionary:
	var safe_window := Vector2(maxf(1.0, window_size.x), maxf(1.0, window_size.y))
	var design_size := Vector2(1920.0, 1080.0)
	var window_scale := Vector2(
		safe_window.x / design_size.x,
		safe_window.y / design_size.y
	)
	var drawer_design_width := clampf(design_size.x * 0.30, 440.0, 520.0)
	var design_position_scale := design_size / LOGICAL_BATTLEFIELD_SIZE
	var window_visual_scale := minf(window_scale.x, window_scale.y)
	return {
		"window_size": safe_window,
		"battlefield_screen_rect": Rect2(Vector2.ZERO, safe_window),
		"drawer_screen_width": drawer_design_width * window_scale.x,
		"drawer_screen_height": safe_window.y,
		"logical_battlefield_size": LOGICAL_BATTLEFIELD_SIZE,
		"design_to_window_scale": window_scale,
		"position_mapping_scale": design_position_scale * window_scale,
		"uniform_visual_scale": window_visual_scale,
		"visual_aspect_ratio": 1.0,
	}


func get_layout_snapshot() -> Dictionary:
	var enemy_positions: Dictionary = {}
	for enemy_id in active_enemies.keys():
		var enemy = active_enemies[enemy_id]
		if is_instance_valid(enemy):
			enemy_positions[enemy_id] = enemy.position
	return {
		"viewport_size": layout_viewport_size,
		"battlefield_size": battlefield.size,
		"logical_battlefield_size": battlefield_content.size,
		"display_scale": battlefield_display_root.scale,
		"position_mapping_scale": position_mapping_scale,
		"uniform_visual_scale": uniform_visual_scale,
		"visual_compensation_scale": get_visual_compensation_scale(),
		"route_visual_global_scale": get_global_axis_scale(route_view),
		"formation_visual_global_scale": get_global_axis_scale(formation_manager),
		"projectile_visual_global_scale": get_global_axis_scale(projectile_visual_layer),
		"caption_visual_global_scale": get_global_axis_scale(battlefield_caption),
		"village_visual_global_scale": get_global_axis_scale(village_entrance),
		"debug_panel_open": debug_panel_open,
		"debug_drawer_width": -debug_drawer.offset_left,
		"debug_drawer_mouse_filter": debug_drawer.mouse_filter,
		"compact_hud_visible": %CompactHud.visible,
		"enemy_positions": enemy_positions,
	}


func get_global_axis_scale(canvas_item: CanvasItem) -> Vector2:
	var transform := canvas_item.get_global_transform_with_canvas()
	return Vector2(transform.x.length(), transform.y.length())


func set_debug_panel_open(open: bool) -> void:
	debug_panel_open = open
	debug_drawer.visible = open
	debug_toggle_button.text = "收起调试" if open else "调试"


func toggle_debug_panel() -> void:
	set_debug_panel_open(not debug_panel_open)


func handle_escape_action() -> StringName:
	if debug_panel_open:
		set_debug_panel_open(false)
		return &"CLOSED_DEBUG_PANEL"
	command_controller.cancel_command(&"PLAYER_CANCEL")
	update_ui()
	return &"CANCELED_COMMAND"


func _process(delta: float) -> void:
	update_hover_target()
	if automatic_simulation:
		simulate_step(delta)


func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not debug_toggle_button.is_visible_in_tree():
		return
	if not debug_toggle_button.get_global_rect().has_point(mouse_event.position):
		return
	toggle_debug_panel()
	get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	if is_instance_valid(command_controller):
		command_controller.handle_battle_end(&"SCENE_EXIT")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		handle_escape_action()
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		command_controller.cancel_command(&"PLAYER_CANCEL")
		update_ui()
		get_viewport().set_input_as_handled()


func on_battlefield_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	var local_position := screen_to_logic_position(event.position)
	if handle_battlefield_pointer(local_position, event.button_index):
		battlefield.accept_event()


func handle_battlefield_pointer(
	local_position: Vector2,
	button_index: MouseButton
) -> bool:
	if button_index == MOUSE_BUTTON_RIGHT:
		command_controller.cancel_command(&"PLAYER_CANCEL")
		update_ui()
		return true
	if button_index != MOUSE_BUTTON_LEFT \
			or battle_state != BattleState.RUNNING:
		return false
	var enemy = pick_enemy_at(local_position)
	if is_instance_valid(enemy):
		command_controller.issue_command(StringName(enemy.runtime_id))
		update_ui()
		return true
	return false


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
		apply_control_visual_compensation(
			slot,
			get_visual_compensation_scale()
		)
		deployment_slots[slot_id] = slot
	update_deployment_positions()


func setup_character_roster() -> void:
	for character_id: StringName in PrototypeConfig.get_character_ids():
		var definition := PrototypeConfig.get_character_definition(character_id)
		var character = PrototypeCharacter.new()
		character.configure(character_id, definition)
		character.character_died.connect(handle_character_death)
		character_layer.add_child(character)
		character.scale = get_visual_compensation_scale()
		character_nodes[character_id] = character

		var card := Button.new()
		card.name = "CharacterCard_%s" % String(character_id)
		card.custom_minimum_size = Vector2(100.0, 44.0)
		card.focus_mode = Control.FOCUS_NONE
		card.add_theme_font_size_override("font_size", 13)
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


func is_wave_scenario_enabled() -> bool:
	var scenario := PrototypeConfig.get_scenario(selected_scenario_id)
	return StringName(scenario.get("wave_battle_id", &"")) != &""


func configure_wave_director() -> bool:
	if not is_instance_valid(wave_director):
		return false
	if not is_wave_scenario_enabled():
		wave_director.clear_configuration()
		return true
	var scenario := PrototypeConfig.get_scenario(selected_scenario_id)
	var battle_id := StringName(scenario.get("wave_battle_id", &""))
	var configured: bool = wave_director.configure(
		PrototypeConfig.get_wave_battle_config(battle_id),
		PrototypeConfig.get_monster_type_ids(),
		PrototypeConfig.get_spawn_point_lane_map(),
		PrototypeConfig.get_visual_route_ids()
	)
	if not configured:
		push_error(
			"Invalid Combat V2 wave config %s: %s" % [
				String(battle_id),
				"; ".join(wave_director.validation_errors),
			]
		)
	return configured


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
	formation_damage_reduction_events_by_profile.clear()
	formation_damage_prevented_by_profile.clear()
	speed_effect_observed_ids.clear()
	demo_control_resistance_triggered = false
	battle_elapsed = 0.0
	attack_visual_spawn_count = 0
	formation_manager.reset_runtime(
		is_formation_scenario_enabled(),
		run_sequence
	)
	apply_formation_runtime_tuning()
	command_controller.reset_for_restart()
	battle_state = BattleState.RUNNING
	if is_wave_scenario_enabled():
		if not wave_director.start():
			battle_state = BattleState.READY
			update_ui()
			return false
	else:
		spawn_next_enemy()
	set_debug_panel_open(false)
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
	formation_damage_reduction_events_by_profile.clear()
	formation_damage_prevented_by_profile.clear()
	speed_effect_observed_ids.clear()
	demo_control_resistance_triggered = false
	battle_elapsed = 0.0
	attack_visual_spawn_count = 0
	formation_manager.reset_runtime(
		is_formation_scenario_enabled(),
		run_sequence
	)
	apply_formation_runtime_tuning()
	command_controller.reset_for_restart()
	if is_wave_scenario_enabled():
		battle_state = BattleState.RUNNING
		wave_director.start()
	set_debug_panel_open(false)
	update_ui()


func set_automatic_simulation(enabled: bool) -> void:
	automatic_simulation = enabled
	set_process(enabled)


func simulate_step(delta: float) -> void:
	if battle_state != BattleState.RUNNING:
		return
	var safe_delta := maxf(0.0, delta)
	battle_elapsed += safe_delta
	if is_wave_scenario_enabled():
		wave_director.advance(safe_delta)
	else:
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
		command_controller.process_command(safe_delta)
	update_enemy_blocking()
	if battle_state == BattleState.RUNNING:
		simulate_character_actions(safe_delta)
		formation_manager.update_formations(0.0, active_enemies)
		update_enemy_blocking()
	if is_wave_scenario_enabled():
		wave_director.record_battle_telemetry(
			safe_delta,
			active_enemies.size(),
			get_formation_stats_snapshot(),
			village_durability
		)
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


func handle_wave_spawn_requested(spawn_event: Dictionary) -> void:
	if battle_state != BattleState.RUNNING or not is_wave_scenario_enabled():
		return
	var spawn_overrides := {
		"spawn_point_id": StringName(spawn_event.get("spawn_point_id", &"")),
	}
	var configured_max_health := int(spawn_event.get("max_health", 0))
	if configured_max_health > 0:
		spawn_overrides["max_health"] = configured_max_health
	var configured_move_speed := float(spawn_event.get("move_speed", 0.0))
	if configured_move_speed > 0.0:
		spawn_overrides["move_speed"] = configured_move_speed
	var enemy = spawn_enemy_for_route(
		StringName(spawn_event.get("route_id", &"")),
		StringName(spawn_event.get("enemy_profile_id", &"charge")),
		spawn_overrides
	)
	if is_instance_valid(enemy):
		wave_director.register_spawned_enemy(enemy.runtime_id, spawn_event)
		spawn_index = generated_enemy_count


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
		formation_route_index,
		String(monster_definition.get("display_name", String(monster_type))),
		StringName(monster_definition.get("type_marker", &""))
	)
	enemy.reached_entrance.connect(handle_enemy_arrival)
	enemy.enemy_died.connect(handle_enemy_death)
	enemy.attacked_blocker.connect(handle_enemy_attack)
	enemy.damage_resolved.connect(handle_enemy_damage_resolved)
	enemy_layer.add_child(enemy)
	enemy.scale = get_visual_compensation_scale()
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
		var action: Dictionary = character.simulate_action(
			delta, enemies, allies, command_controller
		)
		if action.is_empty():
			continue
		if StringName(action.get("type", &"")) == &"heal":
			healing_event_count += 1
		else:
			character_attack_event_count += 1
			spawn_attack_visual(action)
			if battle_state != BattleState.RUNNING:
				clear_attack_visuals()


func spawn_attack_visual(action: Dictionary) -> Node2D:
	if StringName(action.get("type", &"")) != &"attack":
		return null
	var role_id := StringName(action.get("role_id", &""))
	if role_id == &"doctor":
		return null
	var origin: Vector2 = action.get("origin_position", Vector2.ZERO)
	var target: Vector2 = action.get("target_position", origin)
	var direction := (target - origin).normalized()
	var visual_start := origin + direction * 18.0
	var visual_kind := PrototypeProjectileVisual.KIND_ARROW
	if role_id == &"guard":
		visual_kind = PrototypeProjectileVisual.KIND_MELEE
	elif role_id == &"mage":
		visual_kind = PrototypeProjectileVisual.KIND_MAGIC
	var visual = PrototypeProjectileVisual.new()
	var logic_distance := visual_start.distance_to(target)
	visual.configure(
		StringName(action.get("source_id", &"")),
		StringName(action.get("target_id", &"")),
		int(action.get("attack_sequence_id", 0)),
		visual_kind,
		logic_to_visual_layer_position(visual_start),
		logic_to_visual_layer_position(target),
		logic_distance
	)
	projectile_visual_layer.add_child(visual)
	attack_visual_spawn_count += 1
	return visual


func clear_attack_visuals() -> void:
	if not is_instance_valid(projectile_visual_layer):
		return
	for visual in projectile_visual_layer.get_children():
		projectile_visual_layer.remove_child(visual)
		visual.queue_free()


func get_attack_visual_snapshots() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	if not is_instance_valid(projectile_visual_layer):
		return snapshots
	for visual in projectile_visual_layer.get_children():
		if is_instance_valid(visual) and visual.has_method("get_debug_snapshot"):
			var snapshot: Dictionary = visual.get_debug_snapshot()
			snapshot["global_axis_scale"] = get_global_axis_scale(visual)
			snapshots.append(snapshot)
	return snapshots


func handle_enemy_damage_resolved(
	enemy_id: StringName,
	raw_damage: int,
	applied_damage: int,
	damage_source_type: StringName,
	damage_reduction: float
) -> void:
	if not active_enemies.has(enemy_id):
		return
	if damage_reduction > 0.0 and applied_damage > 0:
		formation_damage_reduction_event_count += 1
		var enemy = active_enemies.get(enemy_id)
		if is_instance_valid(enemy):
			var prevented := maxi(0, int(enemy.last_damage_prevented))
			formation_damage_prevented_total += prevented
			var profile_id := StringName(enemy.monster_type)
			formation_damage_reduction_events_by_profile[profile_id] = int(
				formation_damage_reduction_events_by_profile.get(profile_id, 0)
			) + 1
			formation_damage_prevented_by_profile[profile_id] = int(
				formation_damage_prevented_by_profile.get(profile_id, 0)
			) + prevented


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
	command_controller.handle_enemy_removed(enemy_id, &"KILLED")
	settled_enemy_ids[enemy_id] = &"killed"
	enemy.mark_death_settled()
	killed_enemy_count += 1
	resolved_enemy_count = killed_enemy_count + leaked_enemy_count
	if is_wave_scenario_enabled():
		wave_director.notify_enemy_resolved(enemy_id, &"KILLED")
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
	command_controller.handle_enemy_removed(enemy_id, &"LEAKED")
	settled_enemy_ids[enemy_id] = &"leaked"
	leaked_enemy_count += 1
	resolved_enemy_count = killed_enemy_count + leaked_enemy_count
	if is_wave_scenario_enabled():
		wave_director.notify_enemy_resolved(enemy_id, &"LEAKED")
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
	clear_attack_visuals()
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
	if is_wave_scenario_enabled():
		var wave_snapshot: Dictionary = wave_director.get_snapshot()
		if (
			String(wave_snapshot.get("state", "")) == "COMPLETED"
			and active_enemies.is_empty()
			and village_durability > 0
			and int(wave_snapshot.get("total_resolved", 0))
				== int(wave_snapshot.get("total_planned", -1))
		):
			finish_victory()
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
	clear_attack_visuals()
	command_controller.handle_battle_end(&"BATTLE_END")
	battle_finish_count += 1
	update_ui()
	battle_finished.emit(&"victory")


func finish_defeat() -> void:
	if battle_state != BattleState.RUNNING:
		return
	battle_state = BattleState.DEFEAT
	if is_instance_valid(wave_director):
		wave_director.stop()
	command_controller.handle_battle_end(&"BATTLE_END")
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
	var result: Dictionary = formation_manager.interrupt_member(
		enemy_id,
		reason,
		active_enemies
	)
	command_controller.process_command(0.0)
	return result


func pick_enemy_at(local_position: Vector2):
	var best_enemy = null
	var best_distance := INF
	for enemy in active_enemies.values():
		if not is_instance_valid(enemy) or enemy.is_dead or enemy.settlement_completed:
			continue
		var distance: float = enemy.position.distance_to(local_position)
		if distance > 24.0:
			continue
		if distance < best_distance - 0.0001:
			best_enemy = enemy
			best_distance = distance
		elif absf(distance - best_distance) <= 0.0001 \
				and is_enemy_pick_before(enemy, best_enemy):
			best_enemy = enemy
	return best_enemy


func is_enemy_pick_before(candidate, current_best) -> bool:
	if not is_instance_valid(current_best):
		return true
	if int(candidate.spawn_sequence) != int(current_best.spawn_sequence):
		return int(candidate.spawn_sequence) < int(current_best.spawn_sequence)
	return String(candidate.runtime_id) < String(current_best.runtime_id)


func update_hover_target() -> void:
	if not is_node_ready() or battle_state != BattleState.RUNNING:
		command_controller.set_hover_target(&"")
		return
	var mouse_position := get_viewport().get_mouse_position()
	if not battlefield_content.get_global_rect().has_point(mouse_position):
		command_controller.set_hover_target(&"")
		return
	var local_position := screen_to_logic_position(mouse_position)
	var enemy = pick_enemy_at(local_position)
	command_controller.set_hover_target(
		StringName(enemy.runtime_id) if is_instance_valid(enemy) else &""
	)


func is_command_target_waiting_for_range() -> bool:
	var target = active_enemies.get(command_controller.get_target_runtime_id())
	if not is_instance_valid(target):
		return false
	for character in character_nodes.values():
		if not is_instance_valid(character) or character.role_id == &"doctor":
			continue
		if not character.get_legal_enemy_candidates([target]).is_empty():
			return false
	return true


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
	if is_wave_scenario_enabled():
		spawn_entries.clear()
		spawn_plan.clear()
		configure_wave_director()
		return
	spawn_entries = PrototypeConfig.get_scenario_spawn_entries(
		selected_scenario_id
	)
	spawn_plan.clear()
	for entry: Dictionary in spawn_entries:
		spawn_plan.append(StringName(entry.get("route_id", &"top")))
	configure_wave_director()


func is_formation_scenario_enabled() -> bool:
	var scenario := PrototypeConfig.get_scenario(selected_scenario_id)
	return bool(scenario.get("formations_enabled", false))


func apply_formation_runtime_tuning() -> void:
	var tuning: Dictionary = {}
	if is_wave_scenario_enabled():
		var scenario := PrototypeConfig.get_scenario(selected_scenario_id)
		tuning = PrototypeConfig.get_wave_battle_config(
			StringName(scenario.get("wave_battle_id", &""))
		)
	formation_manager.set_runtime_formation_tuning(
		float(tuning.get("formation_approach_speed", PrototypeConfig.FORMATION_SLOT_MOVE_SPEED)),
		float(tuning.get("formation_completion_tolerance", PrototypeConfig.FORMATION_SLOT_TOLERANCE)),
		float(tuning.get("formation_duration_multiplier", 1.0)),
		float(tuning.get(
			"b_formation_prepare_duration",
			PrototypeConfig.DEFAULT_B_FORMATION_PREPARE_DURATION
		))
	)


func run_formation_demo_control_resistance() -> void:
	if demo_control_resistance_triggered:
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


func get_planned_enemy_count() -> int:
	if is_wave_scenario_enabled() and is_instance_valid(wave_director):
		return int(wave_director.get_snapshot().get("total_planned", 0))
	return spawn_plan.size()


func get_wave_snapshot() -> Dictionary:
	if not is_wave_scenario_enabled() or not is_instance_valid(wave_director):
		return {}
	return wave_director.get_snapshot()


func get_battle_snapshot() -> Dictionary:
	return {
		"state": get_state_name(),
		"scenario_id": selected_scenario_id,
		"village_durability": village_durability,
		"max_durability": PrototypeConfig.VILLAGE_MAX_DURABILITY,
		"planned_enemy_count": get_planned_enemy_count(),
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
		"formation_damage_reduction_events_by_profile":
			formation_damage_reduction_events_by_profile.duplicate(true),
		"formation_damage_prevented_by_profile":
			formation_damage_prevented_by_profile.duplicate(true),
		"speed_effect_observed_count": speed_effect_observed_ids.size(),
		"speed_effect_observed_ids": speed_effect_observed_ids.duplicate(true),
		"demo_control_resistance_triggered":
			demo_control_resistance_triggered,
		"formation_stats": get_formation_stats_snapshot(),
		"formation_groups": get_formation_groups_snapshot(),
		"command": command_controller.get_active_command_snapshot(),
		"command_stats": command_controller.get_stats_snapshot(),
		"attack_visual_spawn_count": attack_visual_spawn_count,
		"attack_visuals": get_attack_visual_snapshots(),
		"deployment": deployment_by_character.duplicate(true),
		"characters": get_character_snapshots(),
		"wave": get_wave_snapshot(),
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
	var planned_count := get_planned_enemy_count()
	durability_label.text = "村庄耐久：%d/%d" % [
		village_durability,
		PrototypeConfig.VILLAGE_MAX_DURABILITY,
	]
	state_label.text = "当前状态：%s" % get_state_name()
	compact_durability_label.text = durability_label.text
	compact_state_label.text = "状态：%s" % get_state_name()
	if is_wave_scenario_enabled():
		var wave_snapshot: Dictionary = wave_director.get_snapshot()
		var pacing: Dictionary = wave_snapshot.get("pacing", {})
		var pacing_records: Array = pacing.get("wave_records", [])
		var pacing_index := int(wave_snapshot.get("current_wave_index", -1))
		var pacing_record: Dictionary = (
			pacing_records[pacing_index]
			if pacing_index >= 0 and pacing_index < pacing_records.size()
			else {}
		)
		var recent_pressure: Dictionary = pacing.get("recent_pressure_sample", {})
		var current_wave_duration := float(pacing_record.get("duration", 0.0))
		if float(pacing_record.get("end_time", -1.0)) < 0.0:
			current_wave_duration = maxf(
				0.0,
				float(pacing.get("battle_time", 0.0))
					- float(pacing_record.get("start_time", pacing.get("battle_time", 0.0)))
			)
		compact_wave_label.text = wave_director.get_hud_text()
		wave_debug_label.text = (
			"波次 %d/%d｜状态 %s｜子波次 %d/%d｜下一事件 %.1f秒"
			+ "\n本波 计划%d / 已生成%d / 活动%d / 击杀%d / 漏怪%d"
			+ "｜全场 计划%d / 已生成%d / 已结算%d / 击杀%d / 漏怪%d"
			+ "\n节奏 累计%.1f秒 / 本波%.1f秒｜峰值%d｜A/B %d/%d｜耐久%d"
			+ "｜最长空场%.1f秒｜最近采样 %.1f秒:%d"
		) % [
			int(wave_snapshot.get("display_wave_number", 0)),
			int(wave_snapshot.get("total_waves", 0)),
			String(wave_snapshot.get("state", "IDLE")),
			int(wave_snapshot.get("triggered_subwave_count", 0)),
			int(wave_snapshot.get("total_subwaves_current", 0)),
			float(wave_snapshot.get("next_event_time", -1.0)),
			int(wave_snapshot.get("current_wave_planned", 0)),
			int(wave_snapshot.get("current_wave_generated", 0)),
			int(wave_snapshot.get("current_wave_active", 0)),
			int(wave_snapshot.get("current_wave_killed", 0)),
			int(wave_snapshot.get("current_wave_leaked", 0)),
			int(wave_snapshot.get("total_planned", 0)),
			int(wave_snapshot.get("total_generated", 0)),
			int(wave_snapshot.get("total_resolved", 0)),
			int(wave_snapshot.get("total_killed", 0)),
			int(wave_snapshot.get("total_leaked", 0)),
			float(pacing.get("battle_time", 0.0)),
			current_wave_duration,
			int(pacing_record.get("peak_active", 0)),
			int(pacing_record.get("completed_a", 0)),
			int(pacing_record.get("completed_b", 0)),
			village_durability,
			float(pacing.get("longest_non_countdown_empty_time", 0.0)),
			float(recent_pressure.get("time", 0.0)),
			int(recent_pressure.get("active", 0)),
		]
	else:
		compact_wave_label.text = "波次：V2-5旧测试方案"
		wave_debug_label.text = "波次调度：旧测试方案（未启用）"
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
	var command: Dictionary = command_controller.get_active_command_snapshot()
	if command.is_empty():
		command_status_label.text = (
			"指挥：%s" % command_controller.feedback_message
			if not command_controller.feedback_message.is_empty()
			else "指挥：未指定目标｜左键选敌，右键或 Esc 取消"
		)
	else:
		var context_name: String = command_controller.get_context_display_name(
			StringName(command.get("context", &"FOCUS"))
		)
		var waiting := "｜等待进入射程" if is_command_target_waiting_for_range() else ""
		command_status_label.text = "%s｜%s｜ID %s｜%s｜HP %d/%d｜阵型 %s/%s｜减伤 %d%%｜阵型ID %s｜路线 %s%s" % [
			context_name,
			String(command.get("target_runtime_id", &"")),
			String(command.get("enemy_profile_id", command.get("monster_type", &""))),
			String(command.get("display_name", "")),
			int(command.get("target_health", 0)),
			int(command.get("target_max_health", 0)),
			String(command.get("formation_level", &"SINGLE")),
			String(command.get("formation_state", &"NONE")),
			int(round(float(command.get("formation_damage_reduction", 0.0)) * 100.0)),
			String(command.get("formation_id", &"")),
			String(command.get("route_id", &"")),
			waiting,
		]
	if command.is_empty():
		compact_command_label.text = command_status_label.text
	else:
		var compact_waiting := "｜等待进入射程" if is_command_target_waiting_for_range() else ""
		compact_command_label.text = "%s｜%s｜HP %d/%d｜阵型 %s/%s｜减伤 %d%%%s" % [
			command_controller.get_context_display_name(
				StringName(command.get("context", &"FOCUS"))
			),
			String(command.get("target_runtime_id", &"")),
			int(command.get("target_health", 0)),
			int(command.get("target_max_health", 0)),
			String(command.get("formation_level", &"SINGLE")),
			String(command.get("formation_state", &"NONE")),
			int(round(float(command.get("formation_damage_reduction", 0.0)) * 100.0)),
			compact_waiting,
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

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
const PrototypeUltimateOverlay := preload(
	"res://prototype/formation_defense/scripts/formation_defense_ultimate_overlay.gd"
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
var character_contact_acquisition_count := 0
var character_contact_attack_state_count := 0
var character_contact_resume_count := 0
var character_contact_wrong_lane_attack_count := 0
var character_contact_target_switch_count := 0
var character_contact_events: Array[Dictionary] = []
var formation_damage_reduction_event_count := 0
var formation_damage_prevented_total := 0
var formation_damage_reduction_events_by_profile: Dictionary = {}
var formation_damage_prevented_by_profile: Dictionary = {}
var speed_effect_observed_ids: Dictionary = {}
var enemy_archetype_records: Dictionary = {}
var archetype_stats_by_profile: Dictionary = {}
var demo_control_resistance_triggered := false
var battle_elapsed := 0.0
var attack_visual_spawn_count := 0
var battlefield_display_root: Node2D = null
var debug_panel_open := false
var layout_viewport_size := Vector2.ZERO
var position_mapping_scale := Vector2.ONE
var uniform_visual_scale := 1.0
var wave_director: Node = null
var ultimate_overlay: Control = null
var ultimate_bar: PanelContainer = null
var ultimate_button_row: HBoxContainer = null
var ultimate_debug_label: Label = null
var ultimate_buttons: Dictionary = {}
var ultimate_energy_bars: Dictionary = {}
var ultimate_targeting_character_id: StringName = &""
var ultimate_target_enemy_id: StringName = &""
var ultimate_pointer_logic := Vector2.ZERO
var ultimate_preview_valid := false
var ultimate_release_sequence := 0
var ultimate_release_events: Array[Dictionary] = []
var ultimate_stats_by_character: Dictionary = {}
var ultimate_cancel_count := 0
var ultimate_invalid_release_count := 0
var ultimate_rejected_start_count := 0
var ultimate_duplicate_settlement_count := 0


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
	apply_character_ultimate_runtime_state()
	apply_character_role_label_runtime_state()
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
	if open and ultimate_targeting_character_id != &"":
		cancel_ultimate_targeting(&"DEBUG_PANEL_OPENED", true)
	debug_panel_open = open
	debug_drawer.visible = open
	debug_toggle_button.text = "收起调试" if open else "调试"


func toggle_debug_panel() -> void:
	set_debug_panel_open(not debug_panel_open)


func handle_escape_action() -> StringName:
	if ultimate_targeting_character_id != &"":
		cancel_ultimate_targeting(&"PLAYER_CANCEL", true)
		return &"CANCELED_ULTIMATE"
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
	if ultimate_targeting_character_id != &"":
		if event is InputEventMouseMotion:
			update_ultimate_targeting_from_screen(event.position)
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton:
			var targeting_button := event as InputEventMouseButton
			if targeting_button.button_index == MOUSE_BUTTON_RIGHT \
					and targeting_button.pressed:
				cancel_ultimate_targeting(&"PLAYER_CANCEL", true)
				get_viewport().set_input_as_handled()
				return
			if targeting_button.button_index == MOUSE_BUTTON_LEFT \
					and not targeting_button.pressed:
				release_ultimate_targeting_from_screen(targeting_button.position)
				get_viewport().set_input_as_handled()
				return
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
	cancel_ultimate_targeting(&"SCENE_EXIT", false)
	if is_instance_valid(command_controller):
		command_controller.handle_battle_end(&"SCENE_EXIT")


func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_WM_MOUSE_EXIT]:
		cancel_ultimate_targeting(&"INPUT_FOCUS_LOST", true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		handle_escape_action()
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if ultimate_targeting_character_id != &"":
			cancel_ultimate_targeting(&"PLAYER_CANCEL", true)
		else:
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
		if ultimate_targeting_character_id != &"":
			cancel_ultimate_targeting(&"PLAYER_CANCEL", true)
		else:
			command_controller.cancel_command(&"PLAYER_CANCEL")
		update_ui()
		return true
	if button_index != MOUSE_BUTTON_LEFT \
			or battle_state != BattleState.RUNNING:
		return false
	var enemy = pick_enemy_at(local_position)
	if is_instance_valid(enemy):
		cancel_ultimate_targeting(&"FOCUS_COMMAND", false)
		if command_controller.issue_command(StringName(enemy.runtime_id)):
			mark_enemy_focus_commanded(StringName(enemy.runtime_id))
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
	apply_character_contact_runtime_state()
	apply_character_ultimate_runtime_state()
	apply_character_action_range_runtime_state()
	apply_character_role_label_runtime_state()
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


func get_selected_wave_battle_config() -> Dictionary:
	if not is_wave_scenario_enabled():
		return {}
	var scenario := PrototypeConfig.get_scenario(selected_scenario_id)
	return PrototypeConfig.get_wave_battle_config(
		StringName(scenario.get("wave_battle_id", &""))
	)


func is_character_contact_combat_enabled() -> bool:
	return bool(
		get_selected_wave_battle_config().get(
			"character_contact_combat_enabled",
			PrototypeConfig.DEFAULT_CHARACTER_CONTACT_COMBAT_ENABLED
		)
	)


func get_character_contact_runtime_config(
	enemy_profile_id: StringName = &""
) -> Dictionary:
	if not is_character_contact_combat_enabled():
		return {"enabled": false}
	var battle_config := get_selected_wave_battle_config()
	var contact_config: Dictionary = battle_config.get(
		"character_contact_combat",
		{}
	).duplicate(true)
	var eligible_profiles: Array = contact_config.get(
		"eligible_enemy_profile_ids",
		[]
	)
	if (
		enemy_profile_id != &""
		and not eligible_profiles.is_empty()
		and enemy_profile_id not in eligible_profiles
	):
		return {"enabled": false}
	contact_config["enabled"] = true
	return contact_config


func apply_character_contact_runtime_state() -> void:
	var enabled := is_character_contact_combat_enabled()
	for character in character_nodes.values():
		if is_instance_valid(character):
			character.set_contact_combat_enabled(enabled)


func reset_character_contact_statistics() -> void:
	character_contact_acquisition_count = 0
	character_contact_attack_state_count = 0
	character_contact_resume_count = 0
	character_contact_wrong_lane_attack_count = 0
	character_contact_target_switch_count = 0
	character_contact_events.clear()


func is_character_ultimate_enabled() -> bool:
	return bool(
		get_selected_wave_battle_config().get(
			"character_ultimate_enabled",
			PrototypeConfig.DEFAULT_CHARACTER_ULTIMATE_ENABLED
		)
	)


func apply_character_ultimate_runtime_state() -> void:
	var enabled := is_character_ultimate_enabled()
	for character_id: StringName in PrototypeConfig.get_character_ids():
		var character = character_nodes.get(character_id)
		if not is_instance_valid(character):
			continue
		character.configure_ultimate(
			enabled,
			PrototypeConfig.get_character_ultimate_definition(character.role_id)
		)
	if enabled:
		ensure_ultimate_ui()
	else:
		destroy_ultimate_ui()


func apply_character_action_range_runtime_state() -> void:
	var overrides: Dictionary = get_selected_wave_battle_config().get(
		"character_action_range_overrides",
		{}
	)
	for character_id: StringName in PrototypeConfig.get_character_ids():
		var character = character_nodes.get(character_id)
		if not is_instance_valid(character):
			continue
		var definition := PrototypeConfig.get_character_definition(character_id)
		character.set_action_range(float(
			overrides.get(character_id, definition.get("action_range", 0.0))
		))


func are_character_role_labels_enabled() -> bool:
	return bool(
		get_selected_wave_battle_config().get(
			"character_role_labels_enabled",
			PrototypeConfig.DEFAULT_CHARACTER_ROLE_LABELS_ENABLED
		)
	)


func apply_character_role_label_runtime_state() -> void:
	var enabled := are_character_role_labels_enabled()
	for character in character_nodes.values():
		if is_instance_valid(character):
			character.set_role_label_visible(enabled)


func reset_ultimate_statistics() -> void:
	ultimate_release_sequence = 0
	ultimate_release_events.clear()
	ultimate_stats_by_character.clear()
	for character_id: StringName in PrototypeConfig.get_character_ids():
		ultimate_stats_by_character[character_id] = {
			"release_count": 0,
			"hit_count": 0,
			"damage": 0,
			"kill_count": 0,
			"stun_count": 0,
			"healed_character_count": 0,
			"healing": 0,
		}
	ultimate_cancel_count = 0
	ultimate_invalid_release_count = 0
	ultimate_rejected_start_count = 0
	ultimate_duplicate_settlement_count = 0


func ensure_ultimate_ui() -> void:
	if is_instance_valid(ultimate_bar) and is_instance_valid(ultimate_overlay):
		return
	ultimate_overlay = PrototypeUltimateOverlay.new()
	ultimate_overlay.name = "UltimateOverlay"
	ultimate_overlay.z_index = 20
	add_child(ultimate_overlay)
	ultimate_bar = PanelContainer.new()
	ultimate_bar.name = "UltimateBar"
	ultimate_bar.z_index = 25
	ultimate_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	ultimate_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	ultimate_bar.offset_left = -452.0
	ultimate_bar.offset_top = -152.0
	ultimate_bar.offset_right = 452.0
	ultimate_bar.offset_bottom = -82.0
	add_child(ultimate_bar)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	ultimate_bar.add_child(margin)
	ultimate_button_row = HBoxContainer.new()
	ultimate_button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	ultimate_button_row.add_theme_constant_override("separation", 6)
	margin.add_child(ultimate_button_row)
	ultimate_buttons.clear()
	ultimate_energy_bars.clear()
	for character_id: StringName in PrototypeConfig.get_character_ids():
		var button := Button.new()
		button.name = "UltimateButton_%s" % String(character_id)
		button.custom_minimum_size = Vector2(214.0, 58.0)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 13)
		button.gui_input.connect(on_ultimate_button_gui_input.bind(character_id, button))
		ultimate_button_row.add_child(button)
		ultimate_buttons[character_id] = button
		var energy_bar := ProgressBar.new()
		energy_bar.name = "EnergyProgress"
		energy_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		energy_bar.show_percentage = false
		energy_bar.min_value = 0.0
		energy_bar.max_value = 100.0
		energy_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		energy_bar.offset_left = 8.0
		energy_bar.offset_top = -8.0
		energy_bar.offset_right = -8.0
		energy_bar.offset_bottom = -3.0
		button.add_child(energy_bar)
		ultimate_energy_bars[character_id] = energy_bar
	ultimate_debug_label = Label.new()
	ultimate_debug_label.name = "UltimateDebugLabel"
	ultimate_debug_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ultimate_debug_label.add_theme_font_size_override("font_size", 13)
	debug_content.add_child(ultimate_debug_label)
	update_ultimate_ui()


func destroy_ultimate_ui() -> void:
	cancel_ultimate_targeting(&"FEATURE_DISABLED", false)
	if is_instance_valid(ultimate_overlay):
		ultimate_overlay.queue_free()
	if is_instance_valid(ultimate_bar):
		ultimate_bar.queue_free()
	if is_instance_valid(ultimate_debug_label):
		ultimate_debug_label.queue_free()
	ultimate_overlay = null
	ultimate_bar = null
	ultimate_button_row = null
	ultimate_debug_label = null
	ultimate_buttons.clear()
	ultimate_energy_bars.clear()


func on_ultimate_button_gui_input(
	event: InputEvent,
	character_id: StringName,
	button: Button
) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		if begin_ultimate_targeting(character_id):
			button.accept_event()


func update_ultimate_ui() -> void:
	if not is_character_ultimate_enabled() or not is_instance_valid(ultimate_bar):
		return
	ultimate_bar.visible = true
	var energy_parts: Array[String] = []
	for character_id: StringName in PrototypeConfig.get_character_ids():
		var character = character_nodes.get(character_id)
		var button: Button = ultimate_buttons.get(character_id)
		var energy_bar: ProgressBar = ultimate_energy_bars.get(character_id)
		if not is_instance_valid(character) or not is_instance_valid(button):
			continue
		button.visible = character.is_deployed()
		if is_instance_valid(energy_bar):
			energy_bar.value = character.ultimate_energy
			energy_bar.modulate = (
				character.ultimate_definition.get("color", Color.WHITE)
				if character.is_alive else Color(0.45, 0.45, 0.48, 0.7)
			)
		if not character.is_deployed():
			continue
		var definition: Dictionary = character.ultimate_definition
		var state_text := "积攒中"
		if not character.is_alive:
			state_text = "已倒下"
		elif character.is_ultimate_targeting:
			state_text = "瞄准中"
		elif character.ultimate_ready:
			state_text = "可释放"
		button.disabled = (
			battle_state != BattleState.RUNNING
			or not character.is_alive
			or not character.ultimate_ready
		)
		button.text = "%s｜%s\n能量 %d/%d｜%s" % [
			character.display_name,
			String(definition.get("display_name", "大招")),
			floori(character.ultimate_energy + 0.0001),
			floori(character.ultimate_energy_max),
			state_text,
		]
		button.modulate = (
			Color(0.48, 0.50, 0.56, 0.78)
			if not character.is_alive
			else Color(1.12, 1.08, 0.72, 1.0)
			if character.ultimate_ready
			else Color.WHITE
		)
		energy_parts.append("%s %d%%" % [
			character.display_name,
			roundi(character.ultimate_energy / character.ultimate_energy_max * 100.0),
		])
	if is_instance_valid(ultimate_debug_label):
		ultimate_debug_label.text = "大招：%s\n释放事件 %d｜取消 %d｜非法 %d｜%s" % [
			String(ultimate_targeting_character_id)
				if ultimate_targeting_character_id != &"" else "未瞄准",
			ultimate_release_events.size(),
			ultimate_cancel_count,
			ultimate_invalid_release_count,
			" / ".join(energy_parts),
		]


func begin_ultimate_targeting(character_id: StringName) -> bool:
	if (
		not is_character_ultimate_enabled()
		or battle_state != BattleState.RUNNING
		or debug_panel_open
	):
		ultimate_rejected_start_count += 1
		return false
	if ultimate_targeting_character_id != &"":
		cancel_ultimate_targeting(&"REPLACED", true)
	var character = character_nodes.get(character_id)
	if not is_instance_valid(character) or not character.begin_ultimate_targeting():
		ultimate_rejected_start_count += 1
		return false
	command_controller.cancel_command(&"ULTIMATE_TARGETING")
	ultimate_targeting_character_id = character_id
	ultimate_target_enemy_id = &""
	ultimate_pointer_logic = character.position
	ultimate_preview_valid = false
	refresh_ultimate_preview(logic_to_screen_position(character.position), true)
	update_ui()
	return true


func update_ultimate_targeting_from_screen(screen_position: Vector2) -> bool:
	return refresh_ultimate_preview(screen_position, true)


func refresh_ultimate_preview(
	screen_position: Vector2,
	allow_hunter_retarget: bool
) -> bool:
	if ultimate_targeting_character_id == &"":
		return false
	var character = character_nodes.get(ultimate_targeting_character_id)
	if (
		not is_instance_valid(character)
		or not character.is_alive
		or not character.is_ultimate_targeting
	):
		cancel_ultimate_targeting(&"CHARACTER_INVALID", true)
		return false
	ultimate_pointer_logic = screen_to_logic_position(screen_position)
	var definition: Dictionary = character.ultimate_definition
	var target_type := StringName(definition.get("target_type", &"POSITION"))
	var target_logic := ultimate_pointer_logic
	ultimate_preview_valid = false
	if target_type == &"ENEMY":
		var target = null
		if allow_hunter_retarget:
			target = pick_ultimate_enemy_target(character, ultimate_pointer_logic)
			ultimate_target_enemy_id = (
				StringName(target.runtime_id) if is_instance_valid(target) else &""
			)
		else:
			target = active_enemies.get(ultimate_target_enemy_id)
			if not is_ultimate_enemy_target_legal(
				character,
				target,
				ultimate_pointer_logic
			):
				target = null
		if is_instance_valid(target):
			target_logic = target.position
			ultimate_preview_valid = true
	else:
		ultimate_target_enemy_id = &""
		ultimate_preview_valid = is_position_ultimate_target_legal(
			character,
			target_logic
		)
		if character.role_id == &"doctor" and ultimate_preview_valid:
			ultimate_preview_valid = not get_ultimate_heal_targets(
				target_logic,
				float(definition.get("effect_radius", 0.0))
			).is_empty()
	if is_instance_valid(ultimate_overlay):
		ultimate_overlay.set_preview(build_ultimate_preview(
			character,
			target_logic,
			ultimate_preview_valid
		))
	return ultimate_preview_valid


func release_ultimate_targeting_from_screen(screen_position: Vector2) -> bool:
	if ultimate_targeting_character_id == &"":
		return false
	refresh_ultimate_preview(screen_position, false)
	var character = character_nodes.get(ultimate_targeting_character_id)
	if not ultimate_preview_valid or not is_instance_valid(character):
		ultimate_invalid_release_count += 1
		cancel_ultimate_targeting(&"INVALID_RELEASE", true)
		return false
	var target_logic := ultimate_pointer_logic
	if StringName(character.ultimate_definition.get("target_type", &"POSITION")) \
			== &"ENEMY":
		var enemy = active_enemies.get(ultimate_target_enemy_id)
		if not is_instance_valid(enemy):
			ultimate_invalid_release_count += 1
			cancel_ultimate_targeting(&"TARGET_GONE", true)
			return false
		target_logic = enemy.position
	if not character.consume_ultimate_energy():
		cancel_ultimate_targeting(&"ENERGY_INVALID", true)
		return false
	ultimate_release_sequence += 1
	var release_result := apply_character_ultimate(character, target_logic)
	record_ultimate_release(character, target_logic, release_result)
	clear_ultimate_targeting_state()
	update_ui()
	return true


func cancel_ultimate_targeting(
	reason: StringName = &"PLAYER_CANCEL",
	count_cancel := true
) -> bool:
	if ultimate_targeting_character_id == &"":
		return false
	var character = character_nodes.get(ultimate_targeting_character_id)
	if is_instance_valid(character):
		character.cancel_ultimate_targeting()
	if count_cancel:
		ultimate_cancel_count += 1
		ultimate_release_events.append({
			"time": snappedf(battle_elapsed, 0.001),
			"kind": &"CANCELED",
			"character_id": ultimate_targeting_character_id,
			"reason": reason,
		})
	clear_ultimate_targeting_state()
	update_ui()
	return true


func clear_ultimate_targeting_state() -> void:
	ultimate_targeting_character_id = &""
	ultimate_target_enemy_id = &""
	ultimate_pointer_logic = Vector2.ZERO
	ultimate_preview_valid = false
	if is_instance_valid(ultimate_overlay):
		ultimate_overlay.clear_preview()


func is_position_ultimate_target_legal(character, target: Vector2) -> bool:
	var battlefield_rect := Rect2(Vector2.ZERO, LOGICAL_BATTLEFIELD_SIZE)
	if not battlefield_rect.has_point(target):
		return false
	var configured_cast_rect := get_configured_position_ultimate_cast_rect()
	if configured_cast_rect.size.x > 0.0 and configured_cast_rect.size.y > 0.0:
		return configured_cast_rect.has_point(target)
	if StringName(character.ultimate_definition.get("cast_area_shape", &"")) \
			== PrototypeConfig.ULTIMATE_CAST_AREA_FORWARD_RECT:
		return get_ultimate_cast_rect(character).has_point(target)
	return character.position.distance_to(target) <= float(
		character.ultimate_definition.get("cast_range", 0.0)
	) + 0.0001


func get_ultimate_cast_rect(character) -> Rect2:
	var battlefield_rect := Rect2(Vector2.ZERO, LOGICAL_BATTLEFIELD_SIZE)
	if not is_instance_valid(character):
		return Rect2()
	var definition: Dictionary = character.ultimate_definition
	if StringName(definition.get("target_type", &"POSITION")) == &"POSITION":
		var configured_cast_rect := get_configured_position_ultimate_cast_rect()
		if configured_cast_rect.size.x > 0.0 and configured_cast_rect.size.y > 0.0:
			return configured_cast_rect
	if StringName(definition.get("cast_area_shape", &"")) \
			!= PrototypeConfig.ULTIMATE_CAST_AREA_FORWARD_RECT:
		return Rect2()
	var width := LOGICAL_BATTLEFIELD_SIZE.x * clampf(
		float(definition.get("cast_rect_width_ratio", 0.0)),
		0.0,
		1.0
	)
	var forward_sign := get_ultimate_forward_x_sign(
		StringName(definition.get("cast_rect_direction", &""))
	)
	var left: float = character.position.x if forward_sign > 0.0 \
		else character.position.x - width
	return Rect2(
		Vector2(left, 0.0),
		Vector2(width, LOGICAL_BATTLEFIELD_SIZE.y)
	).intersection(battlefield_rect)


func get_configured_position_ultimate_cast_rect() -> Rect2:
	var battle_config := get_selected_wave_battle_config()
	if not battle_config.has("position_ultimate_cast_area_normalized_rect"):
		return Rect2()
	var normalized_rect: Rect2 = battle_config.get(
		"position_ultimate_cast_area_normalized_rect",
		Rect2()
	)
	if normalized_rect.size.x <= 0.0 or normalized_rect.size.y <= 0.0:
		return Rect2()
	var logical_rect := Rect2(
		normalized_rect.position * LOGICAL_BATTLEFIELD_SIZE,
		normalized_rect.size * LOGICAL_BATTLEFIELD_SIZE
	)
	return logical_rect.intersection(Rect2(Vector2.ZERO, LOGICAL_BATTLEFIELD_SIZE))


func get_ultimate_forward_x_sign(direction: StringName) -> float:
	if direction == PrototypeConfig.ULTIMATE_CAST_DIRECTION_TOWARD_SPAWN:
		var route_points := PrototypeConfig.get_route_points(
			&"formation_center",
			LOGICAL_BATTLEFIELD_SIZE
		)
		if route_points.size() >= 2:
			var spawn_delta: float = float(route_points[0].x) \
				- float(route_points[route_points.size() - 1].x)
			if absf(spawn_delta) > 0.0001:
				return signf(spawn_delta)
	return 1.0


func is_ultimate_enemy_target_legal(
	character,
	enemy,
	pointer_logic: Vector2
) -> bool:
	if (
		not is_instance_valid(enemy)
		or enemy.is_dead
		or enemy.settlement_completed
	):
		return false
	var definition: Dictionary = character.ultimate_definition
	return (
		character.position.distance_to(enemy.position)
			<= float(definition.get("cast_range", 0.0)) + 0.0001
		and pointer_logic.distance_to(enemy.position)
			<= float(definition.get("snap_radius", 0.0)) + 0.0001
	)


func pick_ultimate_enemy_target(character, pointer_logic: Vector2):
	var candidates: Array = []
	for enemy in active_enemies.values():
		if is_ultimate_enemy_target_legal(character, enemy, pointer_logic):
			candidates.append(enemy)
	candidates.sort_custom(func(left, right):
		var left_distance: float = left.position.distance_squared_to(pointer_logic)
		var right_distance: float = right.position.distance_squared_to(pointer_logic)
		if absf(left_distance - right_distance) > 0.0001:
			return left_distance < right_distance
		return String(left.runtime_id) < String(right.runtime_id)
	)
	return candidates[0] if not candidates.is_empty() else null


func get_ultimate_damage_targets(center: Vector2, radius: float) -> Array:
	var targets: Array = []
	for enemy in active_enemies.values():
		if (
			is_instance_valid(enemy)
			and not enemy.is_dead
			and not enemy.settlement_completed
			and get_ultimate_effect_distance(center, enemy.position)
				<= radius + 0.0001
		):
			targets.append(enemy)
	targets.sort_custom(func(left, right):
		return String(left.runtime_id) < String(right.runtime_id)
	)
	return targets


func get_ultimate_heal_targets(center: Vector2, radius: float) -> Array:
	var targets: Array = []
	for character_id: StringName in PrototypeConfig.get_character_ids():
		var character = character_nodes.get(character_id)
		if (
			is_instance_valid(character)
			and character.is_deployed()
			and character.is_alive
			and character.current_health < character.max_health
			and get_ultimate_effect_distance(center, character.position)
				<= radius + 0.0001
		):
			targets.append(character)
	return targets


func build_ultimate_preview(
	character,
	target_logic: Vector2,
	valid: bool
) -> Dictionary:
	var definition: Dictionary = character.ultimate_definition
	var effect_radius := float(definition.get(
		"effect_radius",
		definition.get("snap_radius", 0.0)
	))
	var target_type := StringName(definition.get("target_type", &"POSITION"))
	var cast_polygon := PackedVector2Array()
	var area_points := PackedVector2Array()
	if target_type == &"POSITION":
		cast_polygon = get_screen_rect_points(get_ultimate_cast_rect(character))
		area_points = get_mapped_circle_points(target_logic, effect_radius)
	return {
		"character_id": StringName(character.character_id),
		"ultimate_id": StringName(definition.get("ultimate_id", &"")),
		"valid": valid,
		"color": definition.get("color", Color.WHITE),
		"origin": logic_to_screen_position(character.position),
		"target": logic_to_screen_position(target_logic),
		"cast_points": PackedVector2Array(),
		"cast_polygon": cast_polygon,
		"cast_rect_logic": get_ultimate_cast_rect(character),
		"area_points": area_points,
		"draw_line": character.role_id == &"hunter",
		"target_enemy_id": ultimate_target_enemy_id,
	}


func get_mapped_circle_points(
	logic_center: Vector2,
	logic_radius: float,
	segments := 64
) -> PackedVector2Array:
	var points := PackedVector2Array()
	if logic_radius <= 0.0:
		return points
	var screen_center := logic_to_screen_position(logic_center)
	var screen_radius := logic_radius * uniform_visual_scale
	for index in range(segments + 1):
		var angle := TAU * float(index) / float(segments)
		points.append(
			screen_center
				+ Vector2(cos(angle), sin(angle)) * screen_radius
		)
	return points


func get_screen_rect_points(logic_rect: Rect2) -> PackedVector2Array:
	var points := PackedVector2Array()
	if logic_rect.size.x <= 0.0 or logic_rect.size.y <= 0.0:
		return points
	for corner in [
		logic_rect.position,
		Vector2(logic_rect.end.x, logic_rect.position.y),
		logic_rect.end,
		Vector2(logic_rect.position.x, logic_rect.end.y),
		logic_rect.position,
	]:
		points.append(logic_to_screen_position(corner))
	return points


func get_ultimate_effect_distance(first: Vector2, second: Vector2) -> float:
	var safe_visual_scale := maxf(uniform_visual_scale, 0.0001)
	return logic_to_screen_position(first).distance_to(
		logic_to_screen_position(second)
	) / safe_visual_scale


func apply_character_ultimate(character, target_logic: Vector2) -> Dictionary:
	var definition: Dictionary = character.ultimate_definition
	var role_id: StringName = character.role_id
	var result := {
		"hit_count": 0,
		"damage": 0,
		"kill_count": 0,
		"stun_count": 0,
		"healed_character_count": 0,
		"healing": 0,
		"target_ids": [],
	}
	var processed_ids: Dictionary = {}
	if role_id == &"hunter":
		var enemy = active_enemies.get(ultimate_target_enemy_id)
		if is_instance_valid(enemy):
			apply_ultimate_damage_to_enemy(
				enemy,
				int(definition.get("damage", 0)),
				StringName(definition.get("damage_source_type", &"RANGED")),
				result,
				processed_ids
			)
	elif role_id in [&"guard", &"mage"]:
		var radius := float(definition.get("effect_radius", 0.0))
		for enemy in get_ultimate_damage_targets(target_logic, radius):
			apply_ultimate_damage_to_enemy(
				enemy,
				int(definition.get("damage", 0)),
				StringName(definition.get("damage_source_type", &"UNSPECIFIED")),
				result,
				processed_ids
			)
			if (
				role_id == &"guard"
				and is_instance_valid(enemy)
				and not enemy.is_dead
				and enemy.apply_stun(float(definition.get("stun_duration", 0.0))) > 0.0
			):
				result.stun_count += 1
	elif role_id == &"doctor":
		var heal_targets := get_ultimate_heal_targets(
			target_logic,
			float(definition.get("effect_radius", 0.0))
		)
		for target_character in heal_targets:
			var healed := int(target_character.receive_healing(
				int(definition.get("healing", 0))
			))
			if healed <= 0:
				continue
			result.healed_character_count += 1
			result.healing += healed
			result.target_ids.append(StringName(target_character.character_id))
	spawn_ultimate_effect_visual(character, target_logic)
	return result


func apply_ultimate_damage_to_enemy(
	enemy,
	damage: int,
	damage_source_type: StringName,
	result: Dictionary,
	processed_ids: Dictionary
) -> void:
	if not is_instance_valid(enemy):
		return
	var enemy_id := StringName(enemy.runtime_id)
	if processed_ids.has(enemy_id):
		ultimate_duplicate_settlement_count += 1
		return
	processed_ids[enemy_id] = true
	var was_alive: bool = not enemy.is_dead and not enemy.settlement_completed
	var applied := int(enemy.take_damage(maxi(0, damage), damage_source_type))
	if applied <= 0:
		return
	result.hit_count += 1
	result.damage += applied
	result.target_ids.append(enemy_id)
	if was_alive and enemy.is_dead:
		result.kill_count += 1


func spawn_ultimate_effect_visual(character, target_logic: Vector2) -> void:
	if not is_instance_valid(ultimate_overlay):
		return
	var definition: Dictionary = character.ultimate_definition
	if character.role_id == &"hunter":
		spawn_attack_visual({
			"type": &"attack",
			"source_id": StringName(character.character_id),
			"target_id": ultimate_target_enemy_id,
			"attack_sequence_id": 100000 + ultimate_release_sequence,
			"origin_position": character.position,
			"target_position": target_logic,
			"role_id": &"hunter",
			"damage_source_type": &"RANGED",
		})
	var radius := float(definition.get(
		"effect_radius",
		definition.get("snap_radius", 24.0)
	))
	ultimate_overlay.spawn_effect(
		StringName(definition.get("ultimate_id", &"")),
		logic_to_screen_position(target_logic),
		get_mapped_circle_points(target_logic, radius),
		definition.get("color", Color.WHITE),
		0.32 if character.role_id == &"hunter" else 0.48
	)


func record_ultimate_release(
	character,
	target_logic: Vector2,
	result: Dictionary
) -> void:
	var character_id := StringName(character.character_id)
	var stats: Dictionary = ultimate_stats_by_character.get(character_id, {}).duplicate(true)
	for key in [
		"hit_count", "damage", "kill_count", "stun_count",
		"healed_character_count", "healing",
	]:
		stats[key] = int(stats.get(key, 0)) + int(result.get(key, 0))
	stats["release_count"] = int(stats.get("release_count", 0)) + 1
	ultimate_stats_by_character[character_id] = stats
	ultimate_release_events.append({
		"time": snappedf(battle_elapsed, 0.001),
		"kind": &"RELEASED",
		"release_sequence": ultimate_release_sequence,
		"character_id": character_id,
		"ultimate_id": StringName(character.ultimate_definition.get(
			"ultimate_id", &""
		)),
		"target_position": target_logic,
		"target_ids": Array(result.get("target_ids", [])).duplicate(),
		"hit_count": int(result.get("hit_count", 0)),
		"damage": int(result.get("damage", 0)),
		"kill_count": int(result.get("kill_count", 0)),
		"stun_count": int(result.get("stun_count", 0)),
		"healed_character_count": int(result.get("healed_character_count", 0)),
		"healing": int(result.get("healing", 0)),
	})


func advance_ultimate_runtime(delta: float) -> void:
	if not is_character_ultimate_enabled():
		return
	for character in character_nodes.values():
		if is_instance_valid(character):
			character.advance_ultimate_energy(
				delta,
				battle_state == BattleState.RUNNING,
				battle_elapsed
			)
	if is_instance_valid(ultimate_overlay):
		ultimate_overlay.advance(delta)


func grant_character_ultimate_event(
	character_id: StringName,
	event_type: StringName
) -> float:
	if not is_character_ultimate_enabled() or battle_state != BattleState.RUNNING:
		return 0.0
	var character = character_nodes.get(character_id)
	if not is_instance_valid(character):
		return 0.0
	return float(character.grant_ultimate_event_energy(
		event_type,
		battle_elapsed,
		true
	))


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
	apply_character_contact_runtime_state()
	apply_character_ultimate_runtime_state()
	apply_character_role_label_runtime_state()
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
	reset_character_contact_statistics()
	reset_ultimate_statistics()
	formation_damage_reduction_event_count = 0
	formation_damage_prevented_total = 0
	formation_damage_reduction_events_by_profile.clear()
	formation_damage_prevented_by_profile.clear()
	speed_effect_observed_ids.clear()
	reset_archetype_statistics()
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
	cancel_ultimate_targeting(&"RESTART", false)
	clear_active_enemies()
	reset_character_combat_states()
	apply_character_contact_runtime_state()
	apply_character_ultimate_runtime_state()
	apply_character_role_label_runtime_state()
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
	reset_character_contact_statistics()
	reset_ultimate_statistics()
	formation_damage_reduction_event_count = 0
	formation_damage_prevented_total = 0
	formation_damage_reduction_events_by_profile.clear()
	formation_damage_prevented_by_profile.clear()
	speed_effect_observed_ids.clear()
	reset_archetype_statistics()
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
	advance_ultimate_runtime(safe_delta)
	for character in character_nodes.values():
		if is_instance_valid(character):
			character.tick_contact_visual(safe_delta)
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
		record_archetype_zone_entries()
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
	var configured_display_name := String(spawn_event.get("display_name", ""))
	if not configured_display_name.is_empty():
		spawn_overrides["display_name"] = configured_display_name
	var configured_type_marker := StringName(spawn_event.get("type_marker", &""))
	if configured_type_marker != &"":
		spawn_overrides["type_marker"] = configured_type_marker
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
	var contact_config := get_character_contact_runtime_config(monster_type)
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
		String(overrides.get(
			"display_name",
			monster_definition.get("display_name", String(monster_type))
		)),
		StringName(overrides.get(
			"type_marker",
			monster_definition.get("type_marker", &"")
		)),
		bool(monster_definition.get("formation_can_participate", true)),
		monster_definition,
		contact_config
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
	record_archetype_spawn(enemy)
	return enemy


func update_enemy_blocking() -> void:
	if battle_state != BattleState.RUNNING:
		return
	if is_character_contact_combat_enabled():
		update_enemy_character_contacts()
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


func update_enemy_character_contacts() -> void:
	var enemies: Array = active_enemies.values()
	enemies.sort_custom(func(left, right):
		if int(left.spawn_sequence) != int(right.spawn_sequence):
			return int(left.spawn_sequence) < int(right.spawn_sequence)
		return String(left.runtime_id) < String(right.runtime_id)
	)
	for enemy in enemies:
		if (
			not is_instance_valid(enemy)
			or not bool(enemy.character_contact_combat_enabled)
			or enemy.is_dead
			or enemy.settlement_completed
		):
			continue
		var target = character_nodes.get(enemy.contact_target_id)
		if enemy.contact_target_id != &"" and not is_contact_target_still_valid(
			target,
			enemy
		):
			release_enemy_character_contact(enemy, &"TARGET_INVALID", true)
			target = null
		if enemy.contact_target_id == &"":
			target = choose_character_contact_target(enemy)
			if is_instance_valid(target):
				var previous_history_size: int = enemy.contact_target_history.size()
				if enemy.set_character_contact_target(target.character_id):
					if previous_history_size > 0:
						character_contact_target_switch_count += 1
					character_contact_acquisition_count += 1
					target.mark_contacted()
					record_character_contact_event(
						&"TARGET_ACQUIRED",
						enemy,
						target
					)
		if not is_instance_valid(target):
			continue
		var target_distance: float = enemy.position.distance_to(target.position)
		if target_distance <= float(enemy.contact_attack_range) + 0.0001:
			if enemy.set_character_contact_attacking():
				character_contact_attack_state_count += 1
				record_character_contact_event(
					&"ATTACKING_STARTED",
					enemy,
					target
				)
		else:
			enemy.set_character_contact_engaging()


func choose_character_contact_target(enemy):
	var candidates: Array = []
	for character_id: StringName in PrototypeConfig.get_character_ids():
		var character = character_nodes.get(character_id)
		if is_character_in_contact_acquisition(character, enemy):
			candidates.append(character)
	if candidates.is_empty():
		return null
	candidates.sort_custom(func(left, right):
		return is_better_character_contact_target(left, right, enemy)
	)
	return candidates[0]


func is_contact_target_still_valid(character, enemy) -> bool:
	return (
		is_instance_valid(character)
		and is_instance_valid(enemy)
		and character.is_deployed()
		and character.is_alive
		and StringName(character.lane_id) == StringName(enemy.blocking_lane_id)
	)


func is_character_in_contact_acquisition(character, enemy) -> bool:
	if not is_contact_target_still_valid(character, enemy):
		return false
	var offset: Vector2 = character.position - enemy.position
	var forward: Vector2 = enemy.get_route_forward_direction()
	var forward_distance := offset.dot(forward)
	var lateral_distance := absf(offset.cross(forward))
	return (
		forward_distance >= -float(enemy.contact_backtrack_tolerance)
		and forward_distance <= float(enemy.contact_acquisition_range)
		and lateral_distance <= float(enemy.contact_lane_tolerance)
		and offset.length() <= float(enemy.contact_acquisition_range)
	)


func is_better_character_contact_target(candidate, current_best, enemy) -> bool:
	var forward: Vector2 = enemy.get_route_forward_direction()
	var candidate_offset: Vector2 = candidate.position - enemy.position
	var best_offset: Vector2 = current_best.position - enemy.position
	var candidate_forward := candidate_offset.dot(forward)
	var best_forward := best_offset.dot(forward)
	if absf(candidate_forward - best_forward) > 0.0001:
		return candidate_forward < best_forward
	var candidate_distance := candidate_offset.length_squared()
	var best_distance := best_offset.length_squared()
	if absf(candidate_distance - best_distance) > 0.0001:
		return candidate_distance < best_distance
	var candidate_slot := String(candidate.deployed_slot_id)
	var best_slot := String(current_best.deployed_slot_id)
	if candidate_slot != best_slot:
		return candidate_slot < best_slot
	return String(candidate.character_id) < String(current_best.character_id)


func release_enemy_character_contact(
	enemy,
	reason: StringName,
	count_resume: bool
) -> void:
	if not is_instance_valid(enemy) or enemy.contact_target_id == &"":
		return
	var target = character_nodes.get(enemy.contact_target_id)
	var previous_target_id: StringName = enemy.clear_character_contact()
	if count_resume:
		character_contact_resume_count += 1
	character_contact_events.append({
		"time": snappedf(battle_elapsed, 0.001),
		"kind": &"RESUMED_ADVANCE",
		"enemy_id": StringName(enemy.runtime_id),
		"enemy_sequence": int(enemy.spawn_sequence),
		"target_id": previous_target_id,
		"reason": reason,
		"route_id": StringName(enemy.route_id),
		"lane_id": StringName(enemy.blocking_lane_id),
		"target_valid": is_instance_valid(target),
	})


func record_character_contact_event(
	kind: StringName,
	enemy,
	character,
	extra: Dictionary = {}
) -> void:
	var event := {
		"time": snappedf(battle_elapsed, 0.001),
		"kind": kind,
		"enemy_id": StringName(enemy.runtime_id),
		"enemy_sequence": int(enemy.spawn_sequence),
		"target_id": StringName(character.character_id),
		"target_slot_id": StringName(character.deployed_slot_id),
		"route_id": StringName(enemy.route_id),
		"lane_id": StringName(enemy.blocking_lane_id),
		"target_lane_id": StringName(character.lane_id),
		"enemy_position": enemy.position,
		"target_position": character.position,
	}
	for key in extra.keys():
		event[key] = extra[key]
	character_contact_events.append(event)


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
			grant_character_ultimate_event(
				StringName(action.get("source_id", &"")),
				&"AUTO_HEAL"
			)
		else:
			character_attack_event_count += 1
			grant_character_ultimate_event(
				StringName(action.get("source_id", &"")),
				&"NORMAL_ATTACK_HIT"
			)
			if bool(action.get("completed_kill", false)):
				grant_character_ultimate_event(
					StringName(action.get("source_id", &"")),
					&"NORMAL_ATTACK_KILL"
				)
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
	if not is_instance_valid(enemy) or not is_instance_valid(character):
		return
	var contact_attack_valid := (
		bool(enemy.character_contact_combat_enabled)
		and StringName(enemy.contact_target_id) == character_id
		and StringName(enemy.contact_state)
			== PrototypeEnemy.CONTACT_STATE_ATTACKING
	)
	if (
		enemy.is_dead
		or enemy.blocked_by_character_id != character_id
		or not character.is_alive
		or (
			bool(enemy.character_contact_combat_enabled)
			and not contact_attack_valid
		)
	):
		return
	if contact_attack_valid and character.lane_id != enemy.blocking_lane_id:
		character_contact_wrong_lane_attack_count += 1
	var applied := int(character.take_damage(maxi(0, damage)))
	if applied > 0:
		enemy_attack_event_count += 1
		grant_character_ultimate_event(character_id, &"DAMAGE_TAKEN")
		if contact_attack_valid:
			record_character_contact_event(
				&"ATTACK_RESOLVED",
				enemy,
				character,
				{
					"raw_damage": maxi(0, damage),
					"applied_damage": applied,
					"remaining_health": int(character.current_health),
					"incapacitated": bool(character.is_incapacitated),
				}
			)


func handle_character_death(character_id: StringName) -> void:
	var character = character_nodes.get(character_id)
	if not is_instance_valid(character):
		return
	if ultimate_targeting_character_id == character_id:
		cancel_ultimate_targeting(&"CHARACTER_INCAPACITATED", true)
	var blocked_ids: Array[StringName] = character.blocked_enemy_ids.duplicate()
	for enemy_id: StringName in blocked_ids:
		var enemy = active_enemies.get(enemy_id)
		if is_instance_valid(enemy):
			enemy.clear_blocker(character_id)
	character.clear_blocked_enemies()
	var contact_enemies: Array = active_enemies.values()
	contact_enemies.sort_custom(func(left, right):
		return int(left.spawn_sequence) < int(right.spawn_sequence)
	)
	for enemy in contact_enemies:
		if (
			is_instance_valid(enemy)
			and StringName(enemy.contact_target_id) == character_id
		):
			record_character_contact_event(
				&"CHARACTER_INCAPACITATED",
				enemy,
				character
			)
			release_enemy_character_contact(
				enemy,
				&"TARGET_INCAPACITATED",
				true
			)
	update_ui()


func reset_archetype_statistics() -> void:
	enemy_archetype_records.clear()
	archetype_stats_by_profile.clear()
	for profile_id: StringName in PrototypeConfig.get_monster_type_ids():
		archetype_stats_by_profile[profile_id] = create_empty_archetype_stats()


func create_empty_archetype_stats() -> Dictionary:
	return {
		"generated": 0,
		"entered_a_alive": 0,
		"entered_a_unfocused": 0,
		"killed_before_a": 0,
		"focus_killed_before_a": 0,
		"killed": 0,
		"leaked": 0,
		"focus_commands_received": 0,
		"rush_prepare_count": 0,
		"rush_started_count": 0,
	}


func get_archetype_stats(profile_id: StringName) -> Dictionary:
	if not archetype_stats_by_profile.has(profile_id):
		archetype_stats_by_profile[profile_id] = create_empty_archetype_stats()
	return archetype_stats_by_profile[profile_id]


func record_archetype_spawn(enemy) -> void:
	if not is_instance_valid(enemy):
		return
	var enemy_id := StringName(enemy.runtime_id)
	var profile_id := StringName(enemy.monster_type)
	enemy_archetype_records[enemy_id] = {
		"profile_id": profile_id,
		"entered_a_alive": false,
		"focus_command_count": 0,
		"rush_prepare_observed": false,
		"rush_started_observed": false,
		"settlement": &"",
	}
	var stats := get_archetype_stats(profile_id)
	stats.generated = int(stats.get("generated", 0)) + 1


func mark_enemy_focus_commanded(enemy_id: StringName) -> void:
	if not enemy_archetype_records.has(enemy_id):
		return
	var record: Dictionary = enemy_archetype_records[enemy_id]
	record.focus_command_count = int(record.get("focus_command_count", 0)) + 1
	var stats := get_archetype_stats(StringName(record.get("profile_id", &"")))
	stats.focus_commands_received = int(stats.get("focus_commands_received", 0)) + 1


func record_archetype_zone_entries() -> void:
	for enemy_id: StringName in active_enemies.keys():
		var enemy = active_enemies.get(enemy_id)
		if (
			not is_instance_valid(enemy)
			or enemy.is_dead
			or enemy.settlement_completed
			or not enemy_archetype_records.has(enemy_id)
		):
			continue
		var record: Dictionary = enemy_archetype_records[enemy_id]
		var stats := get_archetype_stats(StringName(record.get("profile_id", &"")))
		var rush_history: Array = enemy.rush_state_history
		if (
			not bool(record.get("rush_prepare_observed", false))
			and PrototypeConfig.RUSH_STATE_PREPARING in rush_history
		):
			record.rush_prepare_observed = true
			stats.rush_prepare_count = int(stats.get("rush_prepare_count", 0)) + 1
		if (
			not bool(record.get("rush_started_observed", false))
			and PrototypeConfig.RUSH_STATE_RUSHING in rush_history
		):
			record.rush_started_observed = true
			stats.rush_started_count = int(stats.get("rush_started_count", 0)) + 1
		if bool(record.get("entered_a_alive", false)):
			continue
		if StringName(enemy.formation_zone_type) != PrototypeConfig.FORMATION_ZONE_A:
			continue
		record.entered_a_alive = true
		record.a_entry_time = battle_elapsed
		stats.entered_a_alive = int(stats.get("entered_a_alive", 0)) + 1
		if int(record.get("focus_command_count", 0)) <= 0:
			stats.entered_a_unfocused = int(stats.get("entered_a_unfocused", 0)) + 1


func record_archetype_settlement(enemy_id: StringName, outcome: StringName) -> void:
	if not enemy_archetype_records.has(enemy_id):
		return
	var record: Dictionary = enemy_archetype_records[enemy_id]
	if StringName(record.get("settlement", &"")) != &"":
		return
	record.settlement = outcome
	record.settlement_time = battle_elapsed
	var profile_id := StringName(record.get("profile_id", &""))
	var stats := get_archetype_stats(profile_id)
	if outcome == &"KILLED":
		stats.killed = int(stats.get("killed", 0)) + 1
		if not bool(record.get("entered_a_alive", false)):
			stats.killed_before_a = int(stats.get("killed_before_a", 0)) + 1
			if int(record.get("focus_command_count", 0)) > 0:
				stats.focus_killed_before_a = int(
					stats.get("focus_killed_before_a", 0)
				) + 1
	elif outcome == &"LEAKED":
		stats.leaked = int(stats.get("leaked", 0)) + 1


func get_archetype_stats_snapshot() -> Dictionary:
	var result := archetype_stats_by_profile.duplicate(true)
	for profile_id in result.keys():
		var stats: Dictionary = result[profile_id]
		var generated := maxi(0, int(stats.get("generated", 0)))
		stats["entered_a_ratio"] = (
			float(stats.get("entered_a_alive", 0)) / float(generated)
			if generated > 0 else 0.0
		)
		stats["unfocused_entered_a_ratio"] = (
			float(stats.get("entered_a_unfocused", 0)) / float(generated)
			if generated > 0 else 0.0
		)
	return result


func handle_enemy_death(enemy_id: StringName) -> void:
	if settled_enemy_ids.has(enemy_id) or not active_enemies.has(enemy_id):
		return
	var enemy = active_enemies[enemy_id]
	if not is_instance_valid(enemy) or not enemy.is_dead:
		return
	record_archetype_settlement(enemy_id, &"KILLED")
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
	record_archetype_settlement(enemy_id, &"LEAKED")
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
	if is_instance_valid(ultimate_overlay):
		ultimate_overlay.clear_all()
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


func clear_character_contact_transient_visuals() -> void:
	for character in character_nodes.values():
		if is_instance_valid(character):
			character.clear_contact_transient_visuals()


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
	clear_character_ultimate_event_throttles()
	cancel_ultimate_targeting(&"BATTLE_END", false)
	clear_attack_visuals()
	if is_instance_valid(ultimate_overlay):
		ultimate_overlay.clear_all()
	clear_character_contact_transient_visuals()
	command_controller.handle_battle_end(&"BATTLE_END")
	battle_finish_count += 1
	update_ui()
	battle_finished.emit(&"victory")


func finish_defeat() -> void:
	if battle_state != BattleState.RUNNING:
		return
	battle_state = BattleState.DEFEAT
	clear_character_ultimate_event_throttles()
	cancel_ultimate_targeting(&"BATTLE_END", false)
	if is_instance_valid(wave_director):
		wave_director.stop()
	command_controller.handle_battle_end(&"BATTLE_END")
	village_durability = 0
	battle_finish_count += 1
	clear_active_enemies()
	if is_instance_valid(ultimate_overlay):
		ultimate_overlay.clear_all()
	clear_character_contact_transient_visuals()
	update_ui()
	battle_finished.emit(&"defeat")


func clear_character_ultimate_event_throttles() -> void:
	if not is_character_ultimate_enabled():
		return
	for character in character_nodes.values():
		if is_instance_valid(character):
			character.clear_ultimate_event_throttle()


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
	if (
		not is_node_ready()
		or battle_state != BattleState.RUNNING
		or ultimate_targeting_character_id != &""
	):
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
		)),
		float(tuning.get("formation_a_spacing_scale", 1.0)),
		float(tuning.get("formation_b_spacing_scale", 1.0))
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
		"character_contact_combat_enabled":
			is_character_contact_combat_enabled(),
		"character_contact_acquisition_count":
			character_contact_acquisition_count,
		"character_contact_attack_state_count":
			character_contact_attack_state_count,
		"character_contact_resume_count": character_contact_resume_count,
		"character_contact_wrong_lane_attack_count":
			character_contact_wrong_lane_attack_count,
		"character_contact_target_switch_count":
			character_contact_target_switch_count,
		"character_contact_events": character_contact_events.duplicate(true),
		"character_ultimate_enabled": is_character_ultimate_enabled(),
		"ultimate_targeting_character_id": ultimate_targeting_character_id,
		"ultimate_target_enemy_id": ultimate_target_enemy_id,
		"ultimate_preview_valid": ultimate_preview_valid,
		"ultimate_release_sequence": ultimate_release_sequence,
		"ultimate_release_events": ultimate_release_events.duplicate(true),
		"ultimate_stats_by_character": ultimate_stats_by_character.duplicate(true),
		"ultimate_cancel_count": ultimate_cancel_count,
		"ultimate_invalid_release_count": ultimate_invalid_release_count,
		"ultimate_rejected_start_count": ultimate_rejected_start_count,
		"ultimate_duplicate_settlement_count": ultimate_duplicate_settlement_count,
		"ultimate_ui_exists": is_instance_valid(ultimate_bar),
		"ultimate_overlay": (
			ultimate_overlay.get_debug_snapshot()
			if is_instance_valid(ultimate_overlay) else {}
		),
		"formation_damage_reduction_event_count":
			formation_damage_reduction_event_count,
		"formation_damage_prevented_total": formation_damage_prevented_total,
		"formation_damage_reduction_events_by_profile":
			formation_damage_reduction_events_by_profile.duplicate(true),
		"formation_damage_prevented_by_profile":
			formation_damage_prevented_by_profile.duplicate(true),
		"speed_effect_observed_count": speed_effect_observed_ids.size(),
		"speed_effect_observed_ids": speed_effect_observed_ids.duplicate(true),
		"archetype_stats_by_profile": get_archetype_stats_snapshot(),
		"enemy_archetype_records": enemy_archetype_records.duplicate(true),
		"character_role_labels_enabled": are_character_role_labels_enabled(),
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
		var card: Button = character_cards[character_id]
		var slot_id := StringName(deployment_by_character.get(character_id, &""))
		var selected_prefix := "▶ " if selected_character_id == character_id else ""
		card.text = "%s%s｜HP%d｜范围%d%s" % [
			selected_prefix,
			character.display_name,
			character.max_health,
			int(character.action_range),
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
	if ultimate_targeting_character_id != &"":
		var targeting_character = character_nodes.get(ultimate_targeting_character_id)
		if is_instance_valid(targeting_character):
			compact_command_label.text = "大招瞄准：%s｜%s｜松开释放，右键或 Esc 取消" % [
				targeting_character.display_name,
				"合法目标" if ultimate_preview_valid else "当前位置无效",
			]
	update_ultimate_ui()
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

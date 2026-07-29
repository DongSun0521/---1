extends Control

const VILLAGE_BACKGROUND_PATH := "res://assets/art/village/village_main.png"
const FOREST_RACE_ART_PATH := "res://assets/art/characters/forest_race_sheet.png"
const BattleVisualRegistryScript := preload("res://scripts/data/battle_visual_registry.gd")
const VillageBuildingViewScript := preload("res://features/village/village_building_view.gd")
const CharacterEnumsScript := preload("res://scripts/data/character_enums.gd")
const COMBAT_PAGE_CHARACTER_IDS: Array[StringName] = [&"guard", &"hunter", &"mage", &"doctor"]

var game_state
var visual_registry: RefCounted = BattleVisualRegistryScript.new()
var selected_panel_id: StringName = &"farm"
var selected_character_id: StringName = &"guard"
var selected_life_character_id: StringName = &"life_ahe"
var selected_equipment_instance_id: StringName = &""
var selected_forge_recipe_id: StringName = &"craft_iron_sword"
var building_views: Dictionary = {}

var resource_label: Label
var adventurer_label: Label
var logistics_overview_label: Label
var function_dock: PanelContainer
var function_dock_button_row: HBoxContainer
var detail_panel: PanelContainer
var detail_title_label: Label
var detail_body_label: Label
var workshop_art_rect: TextureRect
var forge_entry_button: Button
var project_section: VBoxContainer
var prep_section: VBoxContainer
var daily_report_label: Label
var growth_label: Label
var project_status_label: Label
var project_feedback_label: Label
var food_spin_box: SpinBox
var medicine_spin_box: SpinBox
var expected_days_label: Label
var prep_status_label: Label
var readiness_label: Label
var start_expedition_button: Button
var advance_day_button: Button
var character_page: PanelContainer
var character_buttons: Dictionary = {}
var character_selector_box: HBoxContainer
var character_art_area: Control
var character_sprite: AnimatedSprite2D
var character_basic_label: Label
var character_combat_label: Label
var character_skill_label: Label
var character_trait_label: Label
var character_equipment_label: Label
var character_party_label: Label
var character_party_toggle_button: Button
var character_party_up_button: Button
var character_party_down_button: Button
var character_experience_bar: ProgressBar
var character_party_feedback_label: Label
var equipment_list_box: VBoxContainer
var equipment_status_label: Label
var equipment_action_hint_label: Label
var equip_button: Button
var unequip_weapon_button: Button
var unequip_armor_button: Button
var equipment_tip_panel: PanelContainer
var equipment_tip_status_label: Label
var equipment_tip_name_label: Label
var equipment_tip_meta_label: Label
var equipment_tip_power_label: Label
var equipment_tip_primary_label: Label
var equipment_tip_special_label: Label
var equipment_tip_set_label: Label
var equipment_tip_flavor_label: Label
var equipment_tip_bottom_label: Label
var equipment_tip_compare_label: RichTextLabel
var equipment_buttons: Dictionary = {}
var project_buttons: Dictionary = {}
var building_level_test_section: VBoxContainer
var building_level_buttons: Dictionary = {}
var building_level_test_feedback_label: Label
var farm_section: VBoxContainer
var farm_summary_label: Label
var farm_plot_list_box: VBoxContainer
var food_workshop_section: VBoxContainer
var food_workshop_inventory_label: Label
var food_workshop_project_label: Label
var food_recipe_list_box: VBoxContainer
var food_workshop_feedback_label: Label
var hospital_section: VBoxContainer
var hospital_inventory_label: Label
var hospital_project_label: Label
var hospital_recipe_box: VBoxContainer
var hospital_character_list_box: VBoxContainer
var hospital_feedback_label: Label
var selected_meal_id: StringName = &""
var meal_option_buttons: Dictionary = {}
var farm_assign_confirm_dialog: ConfirmationDialog
var pending_farm_plot_id: int = 0
var pending_farm_crop_id: StringName = &""
var forge_page: PanelContainer
var forge_recipe_list_box: VBoxContainer
var forge_recipe_buttons: Dictionary = {}
var forge_status_label: Label
var forge_feedback_label: Label
var forge_recipe_title_label: Label
var forge_recipe_meta_label: Label
var forge_recipe_power_label: Label
var forge_recipe_art_rect: TextureRect
var forge_recipe_description_label: Label
var forge_recipe_stats_label: Label
var forge_recipe_affixes_label: Label
var forge_recipe_bottom_label: Label
var forge_material_label: RichTextLabel
var forge_time_label: Label
var forge_start_button: Button
var life_character_page: PanelContainer
var life_character_buttons: Dictionary = {}
var life_character_selector_box: VBoxContainer
var life_character_basic_label: Label
var life_character_portrait: TextureRect
var life_character_experience_bar: ProgressBar
var life_character_stats_label: Label
var life_character_trait_label: Label
var life_character_assignment_label: Label
var life_character_efficiency_label: Label
var life_job_options_box: VBoxContainer
var life_unassign_button: Button
var life_current_building_button: Button
var life_lock_button: Button
var life_dismiss_button: Button
var life_capacity_label: Label
var life_filter_option: OptionButton
var life_sort_option: OptionButton
var life_filter_id: StringName = &"all"
var life_sort_id: StringName = &"created"
var life_dismiss_confirm_dialog: ConfirmationDialog
var pending_life_dismiss_id: StringName = &""
var life_assignment_feedback_label: Label
var life_recruitment_page: PanelContainer
var life_recruitment_candidate_box: HBoxContainer
var life_recruitment_summary_label: Label
var life_recruitment_feedback_label: Label
var life_recruitment_refresh_button: Button
var life_refresh_confirm_dialog: ConfirmationDialog
var pending_life_refresh_confirmation: bool = false
var building_jobs_section: VBoxContainer
var building_jobs_summary_label: Label
var building_job_list_box: VBoxContainer
var building_job_feedback_label: Label
var building_recent_work_label: Label
var notification_label: Label
var ui_action_guard_until_msec: Dictionary = {}


func _ready() -> void:
	game_state = get_node("/root/GameState")
	build_visual_layout()
	game_state.state_changed.connect(refresh)
	game_state.daily_report_generated.connect(refresh_daily_report)
	game_state.character_runtime_state_changed.connect(on_character_data_changed)
	game_state.character_final_stats_changed.connect(on_character_data_changed)
	game_state.character_roster_changed.connect(on_character_roster_changed)
	game_state.life_job_assignments_changed.connect(on_life_job_assignments_changed)
	game_state.life_recruitment_candidates_changed.connect(on_life_recruitment_changed)
	game_state.life_character_capacity_changed.connect(on_life_character_capacity_changed)
	game_state.gameplay_notification_added.connect(on_gameplay_notification_added)
	game_state.life_work_feedback_changed.connect(on_life_work_feedback_changed)
	game_state.equipment_inventory_changed.connect(on_equipment_data_changed)
	game_state.character_equipment_changed.connect(on_character_data_changed)
	game_state.forge_state_changed.connect(on_forge_data_changed)
	game_state.forge_project_started.connect(on_forge_report)
	game_state.forge_progress_changed.connect(on_forge_report)
	game_state.forge_project_completed.connect(on_forge_report)
	game_state.food_workshop_state_changed.connect(on_food_workshop_data_changed)
	game_state.food_recipe_started.connect(on_food_recipe_report)
	game_state.food_recipe_completed.connect(on_food_recipe_completed)
	game_state.stackable_item_count_changed.connect(on_stackable_item_changed)
	game_state.hospital_state_changed.connect(on_hospital_data_changed)
	game_state.hospital_project_started.connect(on_hospital_project_started)
	game_state.medicine_production_completed.connect(on_medicine_production_completed)
	game_state.character_treatment_started.connect(on_character_treatment_started)
	game_state.character_treatment_completed.connect(on_character_treatment_completed)
	game_state.character_injury_changed.connect(on_character_injury_changed)
	game_state.building_state_changed.connect(on_building_state_changed)
	advance_day_button.pressed.connect(advance_day)
	food_spin_box.value_changed.connect(on_supply_value_changed)
	medicine_spin_box.value_changed.connect(on_supply_value_changed)
	start_expedition_button.pressed.connect(start_expedition)
	refresh()


func _exit_tree() -> void:
	if game_state != null and game_state.state_changed.is_connected(refresh):
		game_state.state_changed.disconnect(refresh)
	if game_state != null and game_state.daily_report_generated.is_connected(refresh_daily_report):
		game_state.daily_report_generated.disconnect(refresh_daily_report)
	if game_state != null and game_state.character_runtime_state_changed.is_connected(on_character_data_changed):
		game_state.character_runtime_state_changed.disconnect(on_character_data_changed)
	if game_state != null and game_state.character_final_stats_changed.is_connected(on_character_data_changed):
		game_state.character_final_stats_changed.disconnect(on_character_data_changed)
	if game_state != null and game_state.character_roster_changed.is_connected(on_character_roster_changed):
		game_state.character_roster_changed.disconnect(on_character_roster_changed)
	if game_state != null and game_state.life_job_assignments_changed.is_connected(on_life_job_assignments_changed):
		game_state.life_job_assignments_changed.disconnect(on_life_job_assignments_changed)
	if game_state != null and game_state.life_recruitment_candidates_changed.is_connected(on_life_recruitment_changed):
		game_state.life_recruitment_candidates_changed.disconnect(on_life_recruitment_changed)
	if game_state != null and game_state.life_character_capacity_changed.is_connected(on_life_character_capacity_changed):
		game_state.life_character_capacity_changed.disconnect(on_life_character_capacity_changed)
	if game_state != null and game_state.gameplay_notification_added.is_connected(on_gameplay_notification_added):
		game_state.gameplay_notification_added.disconnect(on_gameplay_notification_added)
	if game_state != null and game_state.life_work_feedback_changed.is_connected(on_life_work_feedback_changed):
		game_state.life_work_feedback_changed.disconnect(on_life_work_feedback_changed)
	if game_state != null and game_state.equipment_inventory_changed.is_connected(on_equipment_data_changed):
		game_state.equipment_inventory_changed.disconnect(on_equipment_data_changed)
	if game_state != null and game_state.character_equipment_changed.is_connected(on_character_data_changed):
		game_state.character_equipment_changed.disconnect(on_character_data_changed)
	if game_state != null and game_state.forge_state_changed.is_connected(on_forge_data_changed):
		game_state.forge_state_changed.disconnect(on_forge_data_changed)
	if game_state != null and game_state.forge_project_started.is_connected(on_forge_report):
		game_state.forge_project_started.disconnect(on_forge_report)
	if game_state != null and game_state.forge_progress_changed.is_connected(on_forge_report):
		game_state.forge_progress_changed.disconnect(on_forge_report)
	if game_state != null and game_state.forge_project_completed.is_connected(on_forge_report):
		game_state.forge_project_completed.disconnect(on_forge_report)
	if game_state != null and game_state.food_workshop_state_changed.is_connected(on_food_workshop_data_changed):
		game_state.food_workshop_state_changed.disconnect(on_food_workshop_data_changed)
	if game_state != null and game_state.food_recipe_started.is_connected(on_food_recipe_report):
		game_state.food_recipe_started.disconnect(on_food_recipe_report)
	if game_state != null and game_state.food_recipe_completed.is_connected(on_food_recipe_completed):
		game_state.food_recipe_completed.disconnect(on_food_recipe_completed)
	if game_state != null and game_state.stackable_item_count_changed.is_connected(on_stackable_item_changed):
		game_state.stackable_item_count_changed.disconnect(on_stackable_item_changed)
	if game_state != null and game_state.hospital_state_changed.is_connected(on_hospital_data_changed):
		game_state.hospital_state_changed.disconnect(on_hospital_data_changed)
	if game_state != null and game_state.hospital_project_started.is_connected(on_hospital_project_started):
		game_state.hospital_project_started.disconnect(on_hospital_project_started)
	if game_state != null and game_state.medicine_production_completed.is_connected(on_medicine_production_completed):
		game_state.medicine_production_completed.disconnect(on_medicine_production_completed)
	if game_state != null and game_state.character_treatment_started.is_connected(on_character_treatment_started):
		game_state.character_treatment_started.disconnect(on_character_treatment_started)
	if game_state != null and game_state.character_treatment_completed.is_connected(on_character_treatment_completed):
		game_state.character_treatment_completed.disconnect(on_character_treatment_completed)
	if game_state != null and game_state.character_injury_changed.is_connected(on_character_injury_changed):
		game_state.character_injury_changed.disconnect(on_character_injury_changed)
	if game_state != null and game_state.building_state_changed.is_connected(on_building_state_changed):
		game_state.building_state_changed.disconnect(on_building_state_changed)


func build_visual_layout() -> void:
	var background := TextureRect.new()
	background.name = "VillageBackground"
	background.z_index = 0
	background.texture = load_texture_from_file(VILLAGE_BACKGROUND_PATH)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var shade := ColorRect.new()
	shade.name = "ReadabilityShade"
	shade.z_index = 1
	shade.color = Color(0.0, 0.0, 0.0, 0.12)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	build_building_views()
	add_hotspot(&"prep", "开始远征", Rect2(0.78, 0.05, 0.18, 0.10))

	build_overview_panel()
	build_function_dock()
	build_detail_panel()
	build_character_page()
	build_life_character_page()
	build_life_recruitment_page()
	build_forge_page()


func build_building_views() -> void:
	for data in game_state.get_all_building_data():
		if data == null:
			continue
		var building_id: StringName = data.building_id
		var view: Control = VillageBuildingViewScript.new()
		view.setup(data, game_state.get_building_state(building_id))
		view.building_pressed.connect(select_building)
		view.z_index = 20
		add_child(view)
		building_views[building_id] = view
	layout_building_views()
	resized.connect(layout_building_views)


func layout_building_views() -> void:
	for raw_id in building_views.keys():
		var building_id := StringName(raw_id)
		var view: Control = building_views[building_id]
		var data = game_state.get_building_data(building_id)
		if data == null:
			continue
		view.size = view.custom_minimum_size
		view.position = Vector2(size.x * data.village_position.x, size.y * data.village_position.y) - view.size * 0.5
		view.z_index = 20 + int(data.village_position.y * 10.0)


func refresh_building_views() -> void:
	for raw_id in building_views.keys():
		var building_id := StringName(raw_id)
		var view: Control = building_views[building_id]
		view.refresh(game_state.get_building_state(building_id))


func build_overview_panel() -> void:
	var panel := create_panel("VillageOverviewPanel", 0.9)
	panel.z_index = 100
	set_anchor_rect(panel, Rect2(0.02, 0.03, 0.32, 0.34))
	add_child(panel)

	var margin := create_margin(14)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	margin.add_child(content)

	var title := create_label("村庄总览", 28, Color(1.0, 0.92, 0.67), HORIZONTAL_ALIGNMENT_LEFT)
	content.add_child(title)

	resource_label = create_label("", 19, Color(0.96, 0.95, 0.86), HORIZONTAL_ALIGNMENT_LEFT)
	content.add_child(resource_label)

	var goal_label := create_label("目标：准备远征，推进工坊项目，最终击败遗迹守卫。", 20, Color(0.86, 0.92, 0.80), HORIZONTAL_ALIGNMENT_LEFT)
	content.add_child(goal_label)

	adventurer_label = create_label("", 16, Color(0.90, 0.90, 0.84), HORIZONTAL_ALIGNMENT_LEFT)
	content.add_child(adventurer_label)

	logistics_overview_label = create_label("", 15, Color(0.91, 0.93, 0.84), HORIZONTAL_ALIGNMENT_LEFT)
	content.add_child(logistics_overview_label)
	notification_label = create_label("", 15, Color(1.0, 0.82, 0.46), HORIZONTAL_ALIGNMENT_LEFT)
	notification_label.name = "LatestGameplayNotification"
	notification_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(notification_label)

	var logistics_button_row := HBoxContainer.new()
	logistics_button_row.add_theme_constant_override("separation", 6)
	content.add_child(logistics_button_row)
	var logistics_buttons := {
		&"farm": "农田",
		&"food_workshop": "食物",
		&"hospital": "医院",
		&"weapon_forge": "锻造",
	}
	for building_id: StringName in logistics_buttons.keys():
		var button := Button.new()
		button.text = String(logistics_buttons[building_id])
		button.custom_minimum_size = Vector2(70, 30)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		apply_button_style(button, false)
		button.pressed.connect(select_building.bind(building_id))
		logistics_button_row.add_child(button)


func build_function_dock() -> void:
	function_dock = create_panel("VillageFunctionDock", 0.92)
	function_dock.z_index = 110
	function_dock.mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchor_rect(function_dock, Rect2(0.31, 0.90, 0.38, 0.085))
	add_child(function_dock)

	var margin := create_margin(8)
	function_dock.add_child(margin)
	function_dock_button_row = HBoxContainer.new()
	function_dock_button_row.name = "VillageFunctionButtons"
	function_dock_button_row.add_theme_constant_override("separation", 10)
	margin.add_child(function_dock_button_row)

	add_function_dock_button(
		"OpenCombatCharactersButton",
		"战斗角色",
		"查看战斗角色、装备、技能与编队",
		show_character_page
	)
	add_function_dock_button(
		"OpenLifeCharactersButton",
		"生活角色",
		"查看生活角色、岗位与招募入口",
		show_life_character_page
	)


func add_function_dock_button(
	button_name: String,
	button_text: String,
	tooltip: String,
	callback: Callable
) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = button_text
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(170, 46)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 20)
	apply_button_style(button, true)
	button.pressed.connect(callback)
	function_dock_button_row.add_child(button)
	return button


func build_detail_panel() -> void:
	detail_panel = create_panel("BuildingOperationPanel", 0.94)
	detail_panel.visible = false
	detail_panel.z_index = 110
	set_anchor_rect(detail_panel, Rect2(0.24, 0.17, 0.52, 0.72))
	add_child(detail_panel)

	var margin := create_margin(18)
	detail_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)

	detail_title_label = create_label("", 28, Color(1.0, 0.92, 0.66), HORIZONTAL_ALIGNMENT_LEFT)
	detail_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(detail_title_label)

	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(110, 42)
	apply_button_style(close_button, true)
	close_button.pressed.connect(hide_detail_panel)
	header.add_child(close_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)

	workshop_art_rect = TextureRect.new()
	workshop_art_rect.custom_minimum_size = Vector2(0, 180)
	workshop_art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	workshop_art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	workshop_art_rect.texture = get_building_level_texture(&"weapon_forge")
	content.add_child(workshop_art_rect)

	build_level_test_section(content)

	detail_body_label = create_label("", 20, Color(0.96, 0.95, 0.88), HORIZONTAL_ALIGNMENT_LEFT)
	content.add_child(detail_body_label)

	build_building_jobs_section(content)

	forge_entry_button = Button.new()
	forge_entry_button.text = "进入装备制造"
	forge_entry_button.custom_minimum_size = Vector2(0, 48)
	forge_entry_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply_button_style(forge_entry_button, true)
	forge_entry_button.pressed.connect(show_forge_page)
	content.add_child(forge_entry_button)

	build_farm_section(content)
	build_food_workshop_section(content)
	build_hospital_section(content)
	build_project_section(content)
	build_prep_section(content)
	build_daily_report_section(content)
	build_farm_assign_confirm_dialog()


func build_level_test_section(parent: Control) -> void:
	building_level_test_section = VBoxContainer.new()
	building_level_test_section.add_theme_constant_override("separation", 8)
	parent.add_child(building_level_test_section)

	var title := create_label("建筑等级测试", 20, Color(0.98, 0.86, 0.58), HORIZONTAL_ALIGNMENT_LEFT)
	building_level_test_section.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	building_level_test_section.add_child(row)

	for level in range(1, 5):
		var button := Button.new()
		button.text = "Lv.%d" % level
		button.custom_minimum_size = Vector2(92, 40)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		apply_button_style(button, false)
		button.pressed.connect(set_selected_building_level.bind(level))
		row.add_child(button)
		building_level_buttons[level] = button

	building_level_test_feedback_label = create_label("", 16, Color(0.94, 0.74, 0.50), HORIZONTAL_ALIGNMENT_LEFT)
	building_level_test_section.add_child(building_level_test_feedback_label)


func build_farm_section(parent: Control) -> void:
	farm_section = VBoxContainer.new()
	farm_section.add_theme_constant_override("separation", 10)
	parent.add_child(farm_section)

	var title := create_label("农田种植", 24, Color(0.98, 0.86, 0.58), HORIZONTAL_ALIGNMENT_LEFT)
	farm_section.add_child(title)

	farm_summary_label = create_label("", 18, Color(0.92, 0.93, 0.86), HORIZONTAL_ALIGNMENT_LEFT)
	farm_section.add_child(farm_summary_label)

	farm_plot_list_box = VBoxContainer.new()
	farm_plot_list_box.add_theme_constant_override("separation", 8)
	farm_section.add_child(farm_plot_list_box)


func build_farm_assign_confirm_dialog() -> void:
	farm_assign_confirm_dialog = ConfirmationDialog.new()
	farm_assign_confirm_dialog.title = "确认改种"
	farm_assign_confirm_dialog.dialog_text = ""
	farm_assign_confirm_dialog.confirmed.connect(confirm_pending_farm_crop_assignment)
	add_child(farm_assign_confirm_dialog)


func build_food_workshop_section(parent: Control) -> void:
	food_workshop_section = VBoxContainer.new()
	food_workshop_section.add_theme_constant_override("separation", 10)
	parent.add_child(food_workshop_section)

	var title := create_label("食物制造", 24, Color(0.98, 0.86, 0.58), HORIZONTAL_ALIGNMENT_LEFT)
	food_workshop_section.add_child(title)

	food_workshop_inventory_label = create_label("", 18, Color(0.92, 0.93, 0.86), HORIZONTAL_ALIGNMENT_LEFT)
	food_workshop_section.add_child(food_workshop_inventory_label)

	food_workshop_project_label = create_label("", 18, Color(0.92, 0.93, 0.86), HORIZONTAL_ALIGNMENT_LEFT)
	food_workshop_section.add_child(food_workshop_project_label)

	food_recipe_list_box = VBoxContainer.new()
	food_recipe_list_box.add_theme_constant_override("separation", 8)
	food_workshop_section.add_child(food_recipe_list_box)

	food_workshop_feedback_label = create_label("", 17, Color(0.94, 0.84, 0.58), HORIZONTAL_ALIGNMENT_LEFT)
	food_workshop_section.add_child(food_workshop_feedback_label)


func build_hospital_section(parent: Control) -> void:
	hospital_section = VBoxContainer.new()
	hospital_section.add_theme_constant_override("separation", 10)
	parent.add_child(hospital_section)

	var title := create_label("医院", 24, Color(0.98, 0.86, 0.58), HORIZONTAL_ALIGNMENT_LEFT)
	hospital_section.add_child(title)

	hospital_inventory_label = create_label("", 18, Color(0.92, 0.93, 0.86), HORIZONTAL_ALIGNMENT_LEFT)
	hospital_section.add_child(hospital_inventory_label)

	hospital_project_label = create_label("", 18, Color(0.92, 0.93, 0.86), HORIZONTAL_ALIGNMENT_LEFT)
	hospital_section.add_child(hospital_project_label)

	hospital_recipe_box = VBoxContainer.new()
	hospital_recipe_box.add_theme_constant_override("separation", 8)
	hospital_section.add_child(hospital_recipe_box)

	var wounded_title := create_label("伤员", 20, Color(0.98, 0.86, 0.58), HORIZONTAL_ALIGNMENT_LEFT)
	hospital_section.add_child(wounded_title)

	hospital_character_list_box = VBoxContainer.new()
	hospital_character_list_box.add_theme_constant_override("separation", 8)
	hospital_section.add_child(hospital_character_list_box)

	hospital_feedback_label = create_label("", 17, Color(0.94, 0.84, 0.58), HORIZONTAL_ALIGNMENT_LEFT)
	hospital_section.add_child(hospital_feedback_label)


func build_project_section(parent: Control) -> void:
	project_section = VBoxContainer.new()
	project_section.add_theme_constant_override("separation", 10)
	parent.add_child(project_section)

	var section_title := create_label("可进行项目", 24, Color(0.98, 0.86, 0.58), HORIZONTAL_ALIGNMENT_LEFT)
	project_section.add_child(section_title)

	growth_label = create_label("", 19, Color(0.92, 0.93, 0.86), HORIZONTAL_ALIGNMENT_LEFT)
	project_section.add_child(growth_label)

	project_status_label = create_label("", 19, Color(0.92, 0.93, 0.86), HORIZONTAL_ALIGNMENT_LEFT)
	project_section.add_child(project_status_label)

	var button_grid := GridContainer.new()
	button_grid.columns = 1
	button_grid.add_theme_constant_override("v_separation", 8)
	project_section.add_child(button_grid)

	for project_id: StringName in game_state.get_project_ids():
		var project_button := Button.new()
		project_button.custom_minimum_size = Vector2(0, 46)
		project_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		project_button.clip_text = true
		apply_button_style(project_button, false)
		project_button.pressed.connect(start_growth_project.bind(project_id))
		button_grid.add_child(project_button)
		project_buttons[project_id] = project_button

	project_feedback_label = create_label("", 19, Color(0.94, 0.84, 0.58), HORIZONTAL_ALIGNMENT_LEFT)
	project_section.add_child(project_feedback_label)


func build_prep_section(parent: Control) -> void:
	prep_section = VBoxContainer.new()
	prep_section.add_theme_constant_override("separation", 10)
	parent.add_child(prep_section)

	var section_title := create_label("远征准备", 24, Color(0.98, 0.86, 0.58), HORIZONTAL_ALIGNMENT_LEFT)
	prep_section.add_child(section_title)

	food_spin_box = create_supply_spin_box(1, 10, 5)
	prep_section.add_child(create_spin_row("携带粮食", food_spin_box))

	medicine_spin_box = create_supply_spin_box(0, 5, 1)
	prep_section.add_child(create_spin_row("携带药品", medicine_spin_box))

	var meal_title := create_label("特殊料理", 20, Color(0.98, 0.86, 0.58), HORIZONTAL_ALIGNMENT_LEFT)
	prep_section.add_child(meal_title)
	var meal_options := VBoxContainer.new()
	meal_options.add_theme_constant_override("separation", 6)
	prep_section.add_child(meal_options)
	for meal_id: StringName in [&"", &"hearty_stew", &"hunter_roast"]:
		var button := Button.new()
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0, 38)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		apply_button_style(button, false)
		button.pressed.connect(select_expedition_meal.bind(meal_id))
		meal_options.add_child(button)
		meal_option_buttons[meal_id] = button

	expected_days_label = create_label("", 20, Color(0.93, 0.94, 0.86), HORIZONTAL_ALIGNMENT_LEFT)
	prep_section.add_child(expected_days_label)

	prep_status_label = create_label("", 19, Color(0.92, 0.88, 0.72), HORIZONTAL_ALIGNMENT_LEFT)
	prep_section.add_child(prep_status_label)

	readiness_label = create_label("", 17, Color(0.90, 0.91, 0.84), HORIZONTAL_ALIGNMENT_LEFT)
	prep_section.add_child(readiness_label)

	start_expedition_button = Button.new()
	start_expedition_button.text = "确认出发"
	start_expedition_button.custom_minimum_size = Vector2(0, 52)
	apply_button_style(start_expedition_button, true)
	prep_section.add_child(start_expedition_button)

	advance_day_button = Button.new()
	advance_day_button.text = "休整一天"
	advance_day_button.custom_minimum_size = Vector2(0, 46)
	apply_button_style(advance_day_button, false)
	prep_section.add_child(advance_day_button)


func build_daily_report_section(parent: Control) -> void:
	var title := create_label("上一日结算", 24, Color(0.98, 0.86, 0.58), HORIZONTAL_ALIGNMENT_LEFT)
	parent.add_child(title)

	daily_report_label = create_label("", 18, Color(0.90, 0.91, 0.84), HORIZONTAL_ALIGNMENT_LEFT)
	parent.add_child(daily_report_label)


func build_character_page() -> void:
	character_page = create_panel("CharacterDetailPage", 0.97)
	character_page.visible = false
	character_page.mouse_filter = Control.MOUSE_FILTER_STOP
	character_page.z_index = 120
	set_anchor_rect(character_page, Rect2(0.02, -0.14, 0.96, 1.10))
	add_child(character_page)

	var margin := create_margin(16)
	character_page.add_child(margin)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 10)
	margin.add_child(root_box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root_box.add_child(header)

	var title := create_label("战斗角色", 32, Color(1.0, 0.92, 0.66), HORIZONTAL_ALIGNMENT_LEFT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(130, 50)
	apply_button_style(close_button, true)
	close_button.pressed.connect(hide_character_page)
	header.add_child(close_button)

	character_selector_box = HBoxContainer.new()
	character_selector_box.name = "CombatCharacterList"
	character_selector_box.add_theme_constant_override("separation", 10)
	root_box.add_child(character_selector_box)
	rebuild_character_buttons()

	var body := HBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	root_box.add_child(body)

	character_art_area = Control.new()
	character_art_area.custom_minimum_size = Vector2(280, 470)
	character_art_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_art_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	character_art_area.resized.connect(layout_character_sprite)
	body.add_child(character_art_area)

	var art_background := TextureRect.new()
	art_background.texture = load_texture_from_file(FOREST_RACE_ART_PATH)
	art_background.modulate = Color(1, 1, 1, 0.18)
	art_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	character_art_area.add_child(art_background)

	character_sprite = AnimatedSprite2D.new()
	character_sprite.centered = true
	character_art_area.add_child(character_sprite)

	var info_scroll := ScrollContainer.new()
	info_scroll.custom_minimum_size = Vector2(410, 0)
	info_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(info_scroll)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 12)
	info_scroll.add_child(info)

	var party_panel := create_panel("PartyFormationPanel", 0.78)
	party_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(party_panel)
	var party_margin := create_margin(12)
	party_panel.add_child(party_margin)
	var party_box := VBoxContainer.new()
	party_box.add_theme_constant_override("separation", 6)
	party_margin.add_child(party_box)
	party_box.add_child(create_label("队伍编成", 22, Color(1.0, 0.86, 0.48), HORIZONTAL_ALIGNMENT_LEFT))
	character_party_label = create_label("", 17, Color(0.94, 0.94, 0.86), HORIZONTAL_ALIGNMENT_LEFT)
	party_box.add_child(character_party_label)
	var party_actions := HBoxContainer.new()
	party_actions.add_theme_constant_override("separation", 8)
	party_box.add_child(party_actions)
	character_party_toggle_button = Button.new()
	character_party_toggle_button.custom_minimum_size = Vector2(112, 40)
	apply_button_style(character_party_toggle_button, true)
	character_party_toggle_button.pressed.connect(toggle_selected_character_party)
	party_actions.add_child(character_party_toggle_button)
	character_party_up_button = Button.new()
	character_party_up_button.text = "前移"
	character_party_up_button.custom_minimum_size = Vector2(88, 40)
	apply_button_style(character_party_up_button, false)
	character_party_up_button.pressed.connect(move_selected_character_in_party.bind(-1))
	party_actions.add_child(character_party_up_button)
	character_party_down_button = Button.new()
	character_party_down_button.text = "后移"
	character_party_down_button.custom_minimum_size = Vector2(88, 40)
	apply_button_style(character_party_down_button, false)
	character_party_down_button.pressed.connect(move_selected_character_in_party.bind(1))
	party_actions.add_child(character_party_down_button)
	character_party_feedback_label = create_label(
		"",
		16,
		Color(0.98, 0.78, 0.46),
		HORIZONTAL_ALIGNMENT_LEFT
	)
	party_box.add_child(character_party_feedback_label)

	character_basic_label = add_character_section(info, "基础信息")
	character_experience_bar = create_experience_bar()
	info.add_child(character_experience_bar)
	character_combat_label = add_character_section(info, "战斗属性")
	character_skill_label = add_character_section(info, "技能")
	character_trait_label = add_character_section(info, "特性")
	character_equipment_label = add_character_section(info, "装备")

	build_equipment_panel(body)


func build_life_character_page() -> void:
	life_character_page = create_panel("LifeCharacterPage", 0.97)
	life_character_page.visible = false
	life_character_page.mouse_filter = Control.MOUSE_FILTER_STOP
	life_character_page.z_index = 121
	set_anchor_rect(life_character_page, Rect2(0.06, 0.04, 0.88, 0.92))
	add_child(life_character_page)

	var margin := create_margin(18)
	life_character_page.add_child(margin)
	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 12)
	margin.add_child(root_box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root_box.add_child(header)
	var title := create_label("生活角色", 32, Color(1.0, 0.92, 0.66), HORIZONTAL_ALIGNMENT_LEFT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	life_capacity_label = create_label("", 18, Color(0.94, 0.88, 0.70), HORIZONTAL_ALIGNMENT_RIGHT)
	life_capacity_label.custom_minimum_size = Vector2(170, 46)
	header.add_child(life_capacity_label)
	var recruitment_button := Button.new()
	recruitment_button.name = "OpenLifeRecruitmentButton"
	recruitment_button.text = "招募"
	recruitment_button.custom_minimum_size = Vector2(120, 46)
	apply_button_style(recruitment_button, true)
	recruitment_button.pressed.connect(show_life_recruitment_page)
	header.add_child(recruitment_button)
	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(120, 46)
	apply_button_style(close_button, true)
	close_button.pressed.connect(hide_life_character_page)
	header.add_child(close_button)

	var list_controls := HBoxContainer.new()
	list_controls.add_theme_constant_override("separation", 10)
	root_box.add_child(list_controls)
	list_controls.add_child(create_label("筛选", 17, Color(0.94, 0.92, 0.82), HORIZONTAL_ALIGNMENT_LEFT))
	life_filter_option = OptionButton.new()
	life_filter_option.name = "LifeCharacterFilter"
	life_filter_option.custom_minimum_size = Vector2(160, 40)
	for option: Dictionary in game_state.get_life_character_filter_options():
		life_filter_option.add_item(String(option.get("display_name", "")))
		life_filter_option.set_item_metadata(
			life_filter_option.item_count - 1,
			StringName(option.get("filter_id", &"all"))
		)
	life_filter_option.item_selected.connect(on_life_filter_selected)
	list_controls.add_child(life_filter_option)
	list_controls.add_child(create_label("排序", 17, Color(0.94, 0.92, 0.82), HORIZONTAL_ALIGNMENT_LEFT))
	life_sort_option = OptionButton.new()
	life_sort_option.name = "LifeCharacterSort"
	life_sort_option.custom_minimum_size = Vector2(160, 40)
	for option: Dictionary in game_state.get_life_character_sort_options():
		life_sort_option.add_item(String(option.get("display_name", "")))
		life_sort_option.set_item_metadata(
			life_sort_option.item_count - 1,
			StringName(option.get("sort_id", &"created"))
		)
	life_sort_option.item_selected.connect(on_life_sort_selected)
	list_controls.add_child(life_sort_option)

	var body := HBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	root_box.add_child(body)

	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(430, 0)
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(list_scroll)
	life_character_selector_box = VBoxContainer.new()
	life_character_selector_box.name = "LifeCharacterList"
	life_character_selector_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	life_character_selector_box.add_theme_constant_override("separation", 8)
	list_scroll.add_child(life_character_selector_box)

	var detail_scroll := ScrollContainer.new()
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(detail_scroll)
	var detail_box := VBoxContainer.new()
	detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_box.add_theme_constant_override("separation", 12)
	detail_scroll.add_child(detail_box)

	life_character_portrait = TextureRect.new()
	life_character_portrait.name = "LifeCharacterPortrait"
	life_character_portrait.custom_minimum_size = Vector2(0, 150)
	life_character_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	life_character_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_box.add_child(life_character_portrait)
	life_character_basic_label = add_character_section(detail_box, "基础信息")
	life_character_experience_bar = create_experience_bar()
	detail_box.add_child(life_character_experience_bar)
	life_character_stats_label = add_character_section(detail_box, "生活属性")
	life_character_trait_label = add_character_section(detail_box, "生活特性")
	life_character_assignment_label = add_character_section(detail_box, "当前分配")
	life_character_efficiency_label = add_character_section(detail_box, "岗位效率预览")

	var current_actions := HBoxContainer.new()
	current_actions.add_theme_constant_override("separation", 8)
	detail_box.add_child(current_actions)
	life_unassign_button = Button.new()
	life_unassign_button.text = "撤下当前岗位"
	life_unassign_button.custom_minimum_size = Vector2(180, 42)
	apply_button_style(life_unassign_button, true)
	life_unassign_button.pressed.connect(unassign_selected_life_character)
	current_actions.add_child(life_unassign_button)
	life_current_building_button = Button.new()
	life_current_building_button.text = "查看当前建筑"
	life_current_building_button.custom_minimum_size = Vector2(180, 42)
	apply_button_style(life_current_building_button, false)
	life_current_building_button.pressed.connect(open_selected_life_building)
	current_actions.add_child(life_current_building_button)
	life_lock_button = Button.new()
	life_lock_button.custom_minimum_size = Vector2(128, 42)
	apply_button_style(life_lock_button, false)
	life_lock_button.pressed.connect(toggle_selected_life_character_lock)
	current_actions.add_child(life_lock_button)
	life_dismiss_button = Button.new()
	life_dismiss_button.text = "解雇"
	life_dismiss_button.custom_minimum_size = Vector2(108, 42)
	apply_button_style(life_dismiss_button, false)
	life_dismiss_button.pressed.connect(request_dismiss_selected_life_character)
	current_actions.add_child(life_dismiss_button)

	detail_box.add_child(create_label("岗位选择", 24, Color(0.98, 0.86, 0.58), HORIZONTAL_ALIGNMENT_LEFT))
	life_job_options_box = VBoxContainer.new()
	life_job_options_box.add_theme_constant_override("separation", 8)
	detail_box.add_child(life_job_options_box)
	life_assignment_feedback_label = create_label("", 17, Color(0.94, 0.80, 0.52), HORIZONTAL_ALIGNMENT_LEFT)
	detail_box.add_child(life_assignment_feedback_label)

	life_dismiss_confirm_dialog = ConfirmationDialog.new()
	life_dismiss_confirm_dialog.name = "LifeDismissConfirmation"
	life_dismiss_confirm_dialog.title = "确认解雇"
	life_dismiss_confirm_dialog.confirmed.connect(confirm_dismiss_life_character)
	add_child(life_dismiss_confirm_dialog)

	rebuild_life_character_buttons()


func build_life_recruitment_page() -> void:
	life_recruitment_page = create_panel("LifeRecruitmentPage", 0.98)
	life_recruitment_page.visible = false
	life_recruitment_page.mouse_filter = Control.MOUSE_FILTER_STOP
	life_recruitment_page.z_index = 123
	set_anchor_rect(life_recruitment_page, Rect2(0.04, 0.06, 0.92, 0.88))
	add_child(life_recruitment_page)

	var margin := create_margin(18)
	life_recruitment_page.add_child(margin)
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	root.add_child(header)
	var title := create_label("生活角色招募", 30, Color(1.0, 0.90, 0.60), HORIZONTAL_ALIGNMENT_LEFT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	life_recruitment_refresh_button = Button.new()
	life_recruitment_refresh_button.name = "RefreshLifeCandidatesButton"
	life_recruitment_refresh_button.custom_minimum_size = Vector2(170, 44)
	apply_button_style(life_recruitment_refresh_button, true)
	life_recruitment_refresh_button.pressed.connect(refresh_life_candidates)
	header.add_child(life_recruitment_refresh_button)
	var close_button := Button.new()
	close_button.text = "返回"
	close_button.custom_minimum_size = Vector2(110, 44)
	apply_button_style(close_button, false)
	close_button.pressed.connect(hide_life_recruitment_page)
	header.add_child(close_button)

	life_recruitment_summary_label = create_label(
		"", 18, Color(0.94, 0.92, 0.82), HORIZONTAL_ALIGNMENT_LEFT
	)
	root.add_child(life_recruitment_summary_label)
	var candidates_scroll := ScrollContainer.new()
	candidates_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	candidates_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(candidates_scroll)
	life_recruitment_candidate_box = HBoxContainer.new()
	life_recruitment_candidate_box.name = "LifeRecruitmentCandidates"
	life_recruitment_candidate_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	life_recruitment_candidate_box.add_theme_constant_override("separation", 12)
	candidates_scroll.add_child(life_recruitment_candidate_box)
	life_recruitment_feedback_label = create_label(
		"", 17, Color(0.98, 0.76, 0.44), HORIZONTAL_ALIGNMENT_LEFT
	)
	root.add_child(life_recruitment_feedback_label)
	life_refresh_confirm_dialog = ConfirmationDialog.new()
	life_refresh_confirm_dialog.name = "LifeRefreshHighQualityConfirmation"
	life_refresh_confirm_dialog.title = "确认刷新高品质候选"
	life_refresh_confirm_dialog.confirmed.connect(confirm_refresh_life_candidates)
	life_refresh_confirm_dialog.canceled.connect(cancel_refresh_life_candidates)
	add_child(life_refresh_confirm_dialog)


func build_building_jobs_section(parent: Control) -> void:
	building_jobs_section = VBoxContainer.new()
	building_jobs_section.add_theme_constant_override("separation", 8)
	parent.add_child(building_jobs_section)
	building_jobs_section.add_child(create_label("建筑岗位", 24, Color(0.98, 0.86, 0.58), HORIZONTAL_ALIGNMENT_LEFT))
	building_jobs_summary_label = create_label("", 17, Color(0.90, 0.92, 0.84), HORIZONTAL_ALIGNMENT_LEFT)
	building_jobs_section.add_child(building_jobs_summary_label)
	building_recent_work_label = create_label(
		"",
		16,
		Color(0.88, 0.92, 0.72),
		HORIZONTAL_ALIGNMENT_LEFT
	)
	building_recent_work_label.name = "BuildingRecentWorkResult"
	building_recent_work_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	building_jobs_section.add_child(building_recent_work_label)
	building_job_list_box = VBoxContainer.new()
	building_job_list_box.add_theme_constant_override("separation", 8)
	building_jobs_section.add_child(building_job_list_box)
	building_job_feedback_label = create_label("", 16, Color(0.94, 0.80, 0.52), HORIZONTAL_ALIGNMENT_LEFT)
	building_jobs_section.add_child(building_job_feedback_label)


func build_forge_page() -> void:
	forge_page = create_panel("WeaponForgePage", 0.98)
	forge_page.visible = false
	forge_page.mouse_filter = Control.MOUSE_FILTER_STOP
	forge_page.z_index = 130
	set_anchor_rect(forge_page, Rect2(0.03, -0.10, 0.94, 1.04))
	add_child(forge_page)

	var margin := create_margin(18)
	forge_page.add_child(margin)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)

	var title := create_label("武器制造所", 32, Color(1.0, 0.88, 0.56), HORIZONTAL_ALIGNMENT_LEFT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var inventory_button := Button.new()
	inventory_button.text = "打开装备仓库"
	inventory_button.custom_minimum_size = Vector2(170, 48)
	apply_button_style(inventory_button, false)
	inventory_button.pressed.connect(open_character_page_from_forge)
	header.add_child(inventory_button)

	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(120, 48)
	apply_button_style(close_button, true)
	close_button.pressed.connect(hide_forge_page)
	header.add_child(close_button)

	forge_status_label = create_label("", 19, Color(0.92, 0.88, 0.72), HORIZONTAL_ALIGNMENT_LEFT)
	root.add_child(forge_status_label)

	var content := HBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	root.add_child(content)

	var list_panel := create_dark_panel("ForgeRecipeListPanel", 0.96)
	list_panel.custom_minimum_size = Vector2(330, 0)
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(list_panel)

	var list_margin := create_margin(14)
	list_panel.add_child(list_margin)
	var list_root := VBoxContainer.new()
	list_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_root.add_theme_constant_override("separation", 10)
	list_margin.add_child(list_root)
	list_root.add_child(create_label("配方列表", 24, Color(1.0, 0.86, 0.48), HORIZONTAL_ALIGNMENT_LEFT))

	var recipe_scroll := ScrollContainer.new()
	recipe_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_root.add_child(recipe_scroll)

	forge_recipe_list_box = VBoxContainer.new()
	forge_recipe_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	forge_recipe_list_box.add_theme_constant_override("separation", 8)
	recipe_scroll.add_child(forge_recipe_list_box)

	var display_panel := create_dark_panel("ForgeDisplayPanel", 0.92)
	display_panel.custom_minimum_size = Vector2(360, 0)
	display_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	display_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(display_panel)

	var display_margin := create_margin(16)
	display_panel.add_child(display_margin)
	var display_root := VBoxContainer.new()
	display_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	display_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	display_root.add_theme_constant_override("separation", 12)
	display_margin.add_child(display_root)

	forge_recipe_art_rect = TextureRect.new()
	forge_recipe_art_rect.custom_minimum_size = Vector2(0, 230)
	forge_recipe_art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	forge_recipe_art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	forge_recipe_art_rect.texture = get_building_level_texture(&"weapon_forge")
	display_root.add_child(forge_recipe_art_rect)

	forge_recipe_title_label = create_label("", 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	display_root.add_child(forge_recipe_title_label)

	forge_recipe_meta_label = create_label("", 18, Color(0.84, 0.80, 0.68), HORIZONTAL_ALIGNMENT_CENTER)
	display_root.add_child(forge_recipe_meta_label)

	forge_recipe_power_label = create_label("", 36, Color(1.0, 0.95, 0.76), HORIZONTAL_ALIGNMENT_CENTER)
	display_root.add_child(forge_recipe_power_label)

	forge_recipe_description_label = create_label("", 18, Color(0.90, 0.88, 0.78), HORIZONTAL_ALIGNMENT_LEFT)
	display_root.add_child(forge_recipe_description_label)

	var info_panel := create_dark_panel("ForgeInfoPanel", 0.97)
	info_panel.custom_minimum_size = Vector2(430, 0)
	info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(info_panel)

	var info_margin := create_margin(16)
	info_panel.add_child(info_margin)
	var info_root := VBoxContainer.new()
	info_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_root.add_theme_constant_override("separation", 10)
	info_margin.add_child(info_root)

	info_root.add_child(create_label("装备说明", 24, Color(1.0, 0.86, 0.48), HORIZONTAL_ALIGNMENT_LEFT))
	forge_recipe_stats_label = create_label("", 18, Color(0.94, 0.92, 0.84), HORIZONTAL_ALIGNMENT_LEFT)
	info_root.add_child(forge_recipe_stats_label)
	info_root.add_child(create_tip_separator())
	forge_recipe_affixes_label = create_label("", 18, Color(0.76, 0.88, 1.0), HORIZONTAL_ALIGNMENT_LEFT)
	info_root.add_child(forge_recipe_affixes_label)
	info_root.add_child(create_tip_separator())
	forge_recipe_bottom_label = create_label("", 16, Color(0.78, 0.76, 0.68), HORIZONTAL_ALIGNMENT_LEFT)
	info_root.add_child(forge_recipe_bottom_label)

	var craft_panel := create_dark_panel("ForgeCraftPanel", 0.96)
	craft_panel.custom_minimum_size = Vector2(0, 150)
	craft_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(craft_panel)

	var craft_margin := create_margin(14)
	craft_panel.add_child(craft_margin)
	var craft_row := HBoxContainer.new()
	craft_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	craft_row.add_theme_constant_override("separation", 18)
	craft_margin.add_child(craft_row)

	forge_material_label = RichTextLabel.new()
	forge_material_label.bbcode_enabled = true
	forge_material_label.fit_content = true
	forge_material_label.scroll_active = false
	forge_material_label.custom_minimum_size = Vector2(380, 0)
	forge_material_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	forge_material_label.add_theme_font_size_override("normal_font_size", 18)
	craft_row.add_child(forge_material_label)

	forge_time_label = create_label("", 20, Color(0.94, 0.91, 0.78), HORIZONTAL_ALIGNMENT_LEFT)
	forge_time_label.custom_minimum_size = Vector2(260, 0)
	craft_row.add_child(forge_time_label)

	var action_box := VBoxContainer.new()
	action_box.custom_minimum_size = Vector2(260, 0)
	action_box.add_theme_constant_override("separation", 8)
	craft_row.add_child(action_box)

	forge_start_button = Button.new()
	forge_start_button.text = "开始打造"
	forge_start_button.custom_minimum_size = Vector2(0, 52)
	forge_start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply_button_style(forge_start_button, true)
	forge_start_button.pressed.connect(start_selected_forge_recipe)
	action_box.add_child(forge_start_button)

	forge_feedback_label = create_label("", 18, Color(0.92, 0.84, 0.58), HORIZONTAL_ALIGNMENT_LEFT)
	action_box.add_child(forge_feedback_label)


func build_equipment_panel(parent: Control) -> void:
	var equipment_panel := create_dark_panel("EquipmentWarehousePanel", 0.96)
	equipment_panel.custom_minimum_size = Vector2(480, 0)
	equipment_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipment_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(equipment_panel)

	var margin := create_margin(14)
	equipment_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	root.add_child(create_label("装备仓库", 24, Color(1.0, 0.88, 0.54), HORIZONTAL_ALIGNMENT_LEFT))

	equipment_status_label = create_label("", 16, Color(0.84, 0.82, 0.74), HORIZONTAL_ALIGNMENT_LEFT)
	root.add_child(equipment_status_label)

	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(0, 150)
	list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(list_scroll)

	equipment_list_box = VBoxContainer.new()
	equipment_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipment_list_box.add_theme_constant_override("separation", 6)
	list_scroll.add_child(equipment_list_box)

	equipment_action_hint_label = create_label("", 16, Color(0.92, 0.84, 0.64), HORIZONTAL_ALIGNMENT_LEFT)
	root.add_child(equipment_action_hint_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	root.add_child(actions)

	equip_button = Button.new()
	equip_button.text = "穿戴"
	equip_button.custom_minimum_size = Vector2(120, 44)
	equip_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply_button_style(equip_button, true)
	equip_button.pressed.connect(equip_selected_item)
	actions.add_child(equip_button)

	unequip_weapon_button = Button.new()
	unequip_weapon_button.text = "卸下武器"
	unequip_weapon_button.custom_minimum_size = Vector2(120, 44)
	unequip_weapon_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply_button_style(unequip_weapon_button, false)
	unequip_weapon_button.pressed.connect(unequip_character_slot.bind(&"weapon"))
	actions.add_child(unequip_weapon_button)

	unequip_armor_button = Button.new()
	unequip_armor_button.text = "卸下护甲"
	unequip_armor_button.custom_minimum_size = Vector2(120, 44)
	unequip_armor_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply_button_style(unequip_armor_button, false)
	unequip_armor_button.pressed.connect(unequip_character_slot.bind(&"armor"))
	actions.add_child(unequip_armor_button)

	equipment_tip_panel = create_equipment_tip_panel()
	equipment_tip_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipment_tip_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(equipment_tip_panel)


func create_equipment_tip_panel() -> PanelContainer:
	var panel := create_dark_panel("EquipmentTipPanel", 0.98)
	var margin := create_margin(14)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 7)
	margin.add_child(content)

	equipment_tip_status_label = create_label("", 15, Color(0.68, 0.66, 0.60), HORIZONTAL_ALIGNMENT_LEFT)
	content.add_child(equipment_tip_status_label)

	equipment_tip_name_label = create_label("", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	content.add_child(equipment_tip_name_label)

	equipment_tip_meta_label = create_label("", 16, Color(0.82, 0.78, 0.68), HORIZONTAL_ALIGNMENT_LEFT)
	content.add_child(equipment_tip_meta_label)

	equipment_tip_power_label = create_label("", 34, Color(1.0, 0.96, 0.82), HORIZONTAL_ALIGNMENT_LEFT)
	content.add_child(equipment_tip_power_label)

	content.add_child(create_tip_separator())
	equipment_tip_primary_label = create_label("", 17, Color(0.94, 0.92, 0.84), HORIZONTAL_ALIGNMENT_LEFT)
	content.add_child(equipment_tip_primary_label)

	content.add_child(create_tip_separator())
	equipment_tip_special_label = create_label("", 17, Color(0.78, 0.88, 1.0), HORIZONTAL_ALIGNMENT_LEFT)
	content.add_child(equipment_tip_special_label)

	equipment_tip_set_label = create_label("", 15, Color(0.58, 0.74, 0.58), HORIZONTAL_ALIGNMENT_LEFT)
	content.add_child(equipment_tip_set_label)

	equipment_tip_flavor_label = create_label("", 15, Color(0.70, 0.68, 0.62), HORIZONTAL_ALIGNMENT_LEFT)
	content.add_child(equipment_tip_flavor_label)

	content.add_child(create_tip_separator())
	equipment_tip_bottom_label = create_label("", 15, Color(0.78, 0.76, 0.68), HORIZONTAL_ALIGNMENT_LEFT)
	content.add_child(equipment_tip_bottom_label)

	equipment_tip_compare_label = RichTextLabel.new()
	equipment_tip_compare_label.bbcode_enabled = true
	equipment_tip_compare_label.fit_content = true
	equipment_tip_compare_label.scroll_active = false
	equipment_tip_compare_label.add_theme_font_size_override("normal_font_size", 15)
	content.add_child(equipment_tip_compare_label)

	return panel


func create_tip_separator() -> ColorRect:
	var separator := ColorRect.new()
	separator.color = Color(0.72, 0.55, 0.32, 0.34)
	separator.custom_minimum_size = Vector2(0, 1)
	return separator


func add_hotspot(panel_id: StringName, text: String, rect: Rect2) -> void:
	var button := Button.new()
	button.name = "%sHotspot" % String(panel_id).to_pascal_case()
	button.z_index = 90
	button.text = text
	button.custom_minimum_size = Vector2(96, 38)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = text
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color(1.0, 0.96, 0.82))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.90))
	button.add_theme_color_override("font_pressed_color", Color(0.10, 0.08, 0.04))
	button.add_theme_stylebox_override("normal", make_hotspot_style(Color(0.05, 0.11, 0.07, 0.34), Color(0.95, 0.78, 0.34, 0.72)))
	button.add_theme_stylebox_override("hover", make_hotspot_style(Color(0.19, 0.33, 0.14, 0.62), Color(1.0, 0.92, 0.45, 0.94)))
	button.add_theme_stylebox_override("pressed", make_hotspot_style(Color(0.95, 0.76, 0.26, 0.78), Color(1.0, 0.98, 0.82, 1.0)))
	set_anchor_rect(button, get_compact_hotspot_rect(panel_id, rect))
	add_child(button)

	match panel_id:
		&"codex":
			button.pressed.connect(show_character_page)
		&"life_roster":
			button.pressed.connect(show_life_character_page)
		_:
			button.pressed.connect(select_panel.bind(panel_id))


func get_compact_hotspot_rect(panel_id: StringName, fallback_rect: Rect2) -> Rect2:
	match panel_id:
		&"prep":
			return Rect2(0.80, 0.08, 0.14, 0.07)
		&"codex":
			return Rect2(0.03, 0.35, 0.13, 0.07)
		&"life_roster":
			return Rect2(0.03, 0.44, 0.13, 0.07)
	return fallback_rect


func select_panel(panel_id: StringName) -> void:
	selected_panel_id = panel_id
	show_detail_panel()
	refresh_detail_panel()


func select_building(building_id: StringName) -> void:
	game_state.select_building(building_id)
	selected_panel_id = building_id
	show_detail_panel()
	refresh_detail_panel()


func show_detail_panel() -> void:
	if detail_panel != null:
		detail_panel.visible = true


func hide_detail_panel() -> void:
	if detail_panel != null:
		detail_panel.visible = false


func show_character_page() -> void:
	character_page.visible = true
	rebuild_character_buttons()
	select_preferred_equipment_for_character(selected_character_id)
	refresh_character_page()


func hide_character_page() -> void:
	character_page.visible = false


func show_life_character_page() -> void:
	life_character_page.visible = true
	rebuild_life_character_buttons()
	refresh_life_character_page()


func hide_life_character_page() -> void:
	if life_recruitment_page != null:
		life_recruitment_page.visible = false
	life_character_page.visible = false


func show_life_recruitment_page() -> void:
	life_recruitment_page.visible = true
	life_recruitment_feedback_label.text = ""
	refresh_life_recruitment_page()


func hide_life_recruitment_page() -> void:
	life_recruitment_page.visible = false
	rebuild_life_character_buttons()
	refresh_life_character_page()


func show_forge_page() -> void:
	forge_page.visible = true
	if selected_forge_recipe_id == &"":
		var recipe_ids: Array[StringName] = game_state.get_forge_recipe_ids()
		selected_forge_recipe_id = recipe_ids[0] if not recipe_ids.is_empty() else &""
	refresh_forge_page()


func hide_forge_page() -> void:
	forge_page.visible = false


func open_character_page_from_forge() -> void:
	hide_forge_page()
	show_character_page()


func refresh() -> void:
	resource_label.text = game_state.get_resource_summary()
	adventurer_label.text = game_state.get_adventurer_summary()
	if notification_label != null:
		var notifications: Array = game_state.get_gameplay_notifications(1)
		notification_label.text = (
			"最近提示：%s" % String(notifications[0].get("message", ""))
			if not notifications.is_empty() else "最近提示：暂无"
		)
	if logistics_overview_label != null:
		logistics_overview_label.text = format_logistics_overview()
	refresh_building_views()
	refresh_projects()
	refresh_expedition_prep()
	refresh_detail_panel()
	refresh_daily_report(game_state.get_last_daily_report())
	if character_page != null and character_page.visible:
		refresh_character_page()
	if life_character_page != null and life_character_page.visible:
		refresh_life_character_page()
	if life_recruitment_page != null and life_recruitment_page.visible:
		refresh_life_recruitment_page()
	if forge_page != null and forge_page.visible:
		refresh_forge_page()


func format_logistics_overview() -> String:
	var overview: Dictionary = game_state.get_logistics_overview()
	var resources: Dictionary = overview.get("resources", {})
	var farm_summary: Dictionary = overview.get("farm", {})
	var crop_counts: Dictionary = farm_summary.get("crop_counts", {})
	var injured_names: Array = overview.get("injured_names", [])
	var completing: Array = overview.get("completing_tomorrow", [])
	var lines := PackedStringArray()
	lines.append("后勤总览")
	lines.append("粮食%d  草药%d  口粮%d  药品%d" % [
		int(resources.get(&"food", 0)),
		int(resources.get(&"herb", 0)),
		int(resources.get(&"expedition_ration", 0)),
		int(resources.get(&"medicine", 0)),
	])
	lines.append("料理：炖汤%d  烤肉%d" % [
		int(resources.get(&"hearty_stew", 0)),
		int(resources.get(&"hunter_roast", 0)),
	])
	lines.append("农田：种植中 %d/%d，小麦%d，药草%d，%s" % [
		int(farm_summary.get("active_plot_count", crop_counts.values().size())),
		int(farm_summary.get("unlocked_plot_count", 0)),
		int(crop_counts.get(&"wheat", 0)),
		int(crop_counts.get(&"herb", 0)),
		format_next_harvest_text(int(farm_summary.get("next_harvest_days", 0))),
	])
	lines.append("食物制造所：%s" % String(overview.get("food_workshop_summary", "")))
	lines.append("医院：%s" % String(overview.get("hospital_summary", "")))
	lines.append("受伤角色：%s" % ("无" if injured_names.is_empty() else "、".join(PackedStringArray(injured_names))))
	lines.append("武器制造所：%s" % String(overview.get("forge_summary", "")))
	if not completing.is_empty():
		var parts := PackedStringArray()
		for item: Dictionary in completing:
			parts.append(String(item.get("text", "")))
		lines.append("明天完成：%s" % "；".join(parts))
	return "\n".join(lines)


func refresh_detail_panel() -> void:
	var selected_data = game_state.get_building_data(selected_panel_id)
	workshop_art_rect.texture = get_building_level_texture(selected_panel_id)
	workshop_art_rect.visible = selected_data != null and workshop_art_rect.texture != null
	forge_entry_button.visible = selected_panel_id == &"weapon_forge"
	farm_section.visible = selected_panel_id == &"farm"
	food_workshop_section.visible = selected_panel_id == &"food_workshop"
	hospital_section.visible = selected_panel_id == &"hospital"
	project_section.visible = selected_panel_id == &"weapon_forge" or selected_panel_id == &"project"
	prep_section.visible = selected_panel_id == &"prep"
	refresh_building_level_test(selected_data)
	refresh_building_jobs_section()
	refresh_farm_section()
	refresh_food_workshop_section()
	refresh_hospital_section()

	if selected_data != null:
		detail_title_label.text = "%s  Lv.%d" % [
			String(selected_data.display_name),
			int(game_state.get_building_state(selected_panel_id).get("level", 1)),
		]
		detail_body_label.text = format_building_operation_text(selected_panel_id)
		if selected_panel_id == &"hospital":
			detail_body_label.text = "当前功能：主动制药或治疗受伤角色。\n当前医院项目：%s" % game_state.get_active_hospital_summary()
		return

	match selected_panel_id:
		&"project":
			detail_title_label.text = "当前建设项目"
			detail_body_label.text = "后方项目会在远征推进天数时同步施工。\n\n%s" % game_state.get_active_project_summary()
		&"prep":
			detail_title_label.text = "开始远征"
			detail_body_label.text = "选择本次携带的粮食和药品。粮食决定最多能行动多少天，药品决定战斗中的容错。"
		_:
			detail_title_label.text = "村庄"
			detail_body_label.text = "选择场景中的建筑或入口查看详情。"


func refresh_building_level_test(selected_data) -> void:
	if building_level_test_section == null:
		return
	building_level_test_section.visible = selected_data != null
	if selected_data == null:
		return

	building_level_test_feedback_label.text = ""
	var current_level := int(game_state.get_building_state(selected_panel_id).get("level", 1))
	var max_level := int(selected_data.max_level)
	for raw_level in building_level_buttons.keys():
		var level := int(raw_level)
		var button: Button = building_level_buttons[raw_level]
		button.visible = level <= max_level
		button.disabled = level == current_level
		button.text = "Lv.%d" % level


func set_selected_building_level(level: int) -> void:
	var selected_data = game_state.get_building_data(selected_panel_id)
	if selected_data == null:
		return
	if game_state.set_building_level(selected_panel_id, level):
		refresh_detail_panel()
		refresh_building_views()
	else:
		building_level_test_feedback_label.text = game_state.get_farm_last_error() if selected_panel_id == &"farm" else "等级切换失败"


func refresh_farm_section() -> void:
	if farm_section == null:
		return
	farm_section.visible = selected_panel_id == &"farm"
	if not farm_section.visible:
		return

	var summary: Dictionary = game_state.get_farm_summary()
	var crop_counts: Dictionary = summary.get("crop_counts", {})
	farm_summary_label.text = "可用地块：%d / %d\n当前种植：小麦%d块，药草%d块\n%s" % [
		int(summary.get("unlocked_plot_count", 0)),
		int(summary.get("max_plot_count", 0)),
		int(crop_counts.get(&"wheat", 0)),
		int(crop_counts.get(&"herb", 0)),
		format_next_harvest_text(int(summary.get("next_harvest_days", 0))),
	]

	for child: Node in farm_plot_list_box.get_children():
		child.queue_free()
	for plot_state: Dictionary in game_state.get_farm_plot_states():
		farm_plot_list_box.add_child(create_farm_plot_card(plot_state))


func create_farm_plot_card(plot_state: Dictionary) -> Control:
	var panel := create_dark_panel("FarmPlot%dPanel" % int(plot_state.get("plot_id", 0)), 0.82)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin := create_margin(10)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)

	var plot_id := int(plot_state.get("plot_id", 0))
	var is_unlocked := bool(plot_state.get("is_unlocked", false))
	var title := create_label("地块%d" % plot_id, 19, Color(1.0, 0.90, 0.62), HORIZONTAL_ALIGNMENT_LEFT)
	root.add_child(title)

	if not is_unlocked:
		root.add_child(create_label("%d级农田解锁" % int(plot_state.get("unlock_level", 1)), 17, Color(0.72, 0.72, 0.66), HORIZONTAL_ALIGNMENT_LEFT))
		return panel

	var crop_id := StringName(plot_state.get("crop_id", &""))
	if crop_id == &"" or not bool(plot_state.get("is_active", false)):
		root.add_child(create_label("空闲地块\n尚未选择作物", 17, Color(0.90, 0.90, 0.82), HORIZONTAL_ALIGNMENT_LEFT))
	else:
		var progress := int(plot_state.get("progress_days", 0))
		var growth_days := int(plot_state.get("growth_days", 0))
		var output_resource_id := StringName(plot_state.get("output_resource_id", &""))
		root.add_child(create_label("%s\n进度：%d / %d天\n剩余：%d天\n成熟产出：%d%s" % [
			String(plot_state.get("crop_display_name", "")),
			progress,
			growth_days,
			int(plot_state.get("remaining_days", 0)),
			int(plot_state.get("output_amount", 0)),
			get_resource_display_name(output_resource_id),
		], 17, Color(0.94, 0.94, 0.86), HORIZONTAL_ALIGNMENT_LEFT))

	var progress_bar := ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 12)
	progress_bar.min_value = 0
	progress_bar.max_value = max(1, int(plot_state.get("growth_days", 1)))
	progress_bar.value = int(plot_state.get("progress_days", 0))
	progress_bar.visible = crop_id != &""
	root.add_child(progress_bar)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 8)
	root.add_child(button_row)
	for crop_data in game_state.get_all_crop_data():
		var button := Button.new()
		button.text = "种植%s" % String(crop_data.display_name)
		button.custom_minimum_size = Vector2(120, 36)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = crop_id == crop_data.crop_id and bool(plot_state.get("is_active", false))
		apply_button_style(button, false)
		button.pressed.connect(request_farm_crop_assignment.bind(plot_id, crop_data.crop_id))
		button_row.add_child(button)

	return panel


func request_farm_crop_assignment(plot_id: int, crop_id: StringName) -> void:
	var plot_state := get_farm_plot_state_dictionary(plot_id)
	if int(plot_state.get("progress_days", 0)) > 0 and StringName(plot_state.get("crop_id", &"")) != crop_id:
		pending_farm_plot_id = plot_id
		pending_farm_crop_id = crop_id
		var crop_data = game_state.get_crop_data(crop_id)
		farm_assign_confirm_dialog.dialog_text = "当前作物已经生长%d天。\n\n改种%s将失去当前进度，且不会获得任何产出。\n\n是否继续？" % [
			int(plot_state.get("progress_days", 0)),
			String(crop_data.display_name) if crop_data != null else String(crop_id),
		]
		farm_assign_confirm_dialog.popup_centered()
		return
	assign_farm_crop(plot_id, crop_id, false)


func confirm_pending_farm_crop_assignment() -> void:
	if pending_farm_plot_id <= 0 or pending_farm_crop_id == &"":
		return
	assign_farm_crop(pending_farm_plot_id, pending_farm_crop_id, true)
	pending_farm_plot_id = 0
	pending_farm_crop_id = &""


func assign_farm_crop(plot_id: int, crop_id: StringName, force_replace: bool) -> void:
	if game_state.assign_farm_crop(plot_id, crop_id, force_replace):
		refresh_detail_panel()
		refresh_building_views()


func get_farm_plot_state_dictionary(plot_id: int) -> Dictionary:
	for plot_state: Dictionary in game_state.get_farm_plot_states():
		if int(plot_state.get("plot_id", 0)) == plot_id:
			return plot_state
	return {}


func format_next_harvest_text(next_harvest_days: int) -> String:
	if next_harvest_days <= 0:
		return "当前没有种植"
	return "下次收获：%d天后" % next_harvest_days


func get_resource_display_name(resource_id: StringName) -> String:
	match resource_id:
		&"food":
			return "粮食"
		&"medicine":
			return "药品"
		&"ore":
			return "矿石"
		&"herb":
			return "草药"
		&"boss_core":
			return "核心"
	return String(resource_id)


func format_building_operation_text(building_id: StringName) -> String:
	var data = game_state.get_building_data(building_id)
	var state: Dictionary = game_state.get_building_state(building_id)
	var level := int(state.get("level", 1))
	var lines := PackedStringArray()
	lines.append("当前等级：%d" % level)
	lines.append("当前状态：%s" % String(state.get("status", "")))
	lines.append("")
	lines.append(String(data.description))
	if building_id == &"farm":
		var farm_summary: Dictionary = game_state.get_farm_summary()
		lines.append("")
		lines.append("当前功能：地块种植与自动收获")
		lines.append("可用地块：%d / %d" % [
			int(farm_summary.get("unlocked_plot_count", 0)),
			int(farm_summary.get("max_plot_count", 0)),
		])
		lines.append(format_next_harvest_text(int(farm_summary.get("next_harvest_days", 0))))
		return "\n".join(lines)
	match building_id:
		&"farm":
			var farm_state: Dictionary = game_state.buildings.get("farm", {})
			lines.append("")
			lines.append("当前基础功能：按现有规则生产粮食")
			lines.append("每日产量：%d 粮食" % int(farm_state.get("daily_food_production", 0)))
			lines.append("种植与作物选择将在10B阶段开放。")
		&"hospital":
			var clinic_state: Dictionary = game_state.buildings.get("clinic", {})
			lines.append("")
			lines.append("当前药品生产周期：%d 天" % int(clinic_state.get("medicine_progress_required", 0)))
			lines.append("当前生产进度：%d/%d" % [
				int(clinic_state.get("medicine_progress", 0)),
				int(clinic_state.get("medicine_progress_required", 0)),
			])
			var remaining: int = max(0, int(clinic_state.get("medicine_progress_required", 0)) - int(clinic_state.get("medicine_progress", 0)))
			lines.append("预计完成：%d 天后" % remaining)
			lines.append("主动制作药品和伤员治疗将在10D阶段开放。")
		&"weapon_forge":
			lines.append("")
			lines.append("当前制造：%s" % game_state.get_active_forge_summary())
			var project_progress := int(state.get("project_progress_days", 0))
			var project_required := int(state.get("project_required_days", 0))
			if project_required > 0:
				lines.append("制造进度：%d/%d 天" % [project_progress, project_required])
			lines.append("配方、资源需求、制造进度、领取和装备管理继续使用第9阶段装备制造系统。")
		&"food_workshop":
			lines.append("")
			lines.append("料理、远征口粮和特殊食物将在10C阶段开放。")
		&"research_lab":
			lines.append("")
			lines.append("后续用于：研究科技、解锁建筑能力、解锁配方、分析野外遗物。")
		&"residence":
			lines.append("")
			lines.append("后续用于：提高人口上限、管理居民、查看生活角色。")
		&"resource_collection":
			lines.append("")
			lines.append("后续用于：安排资源采集、开发已探索区域、获得矿石木材和其他资源。")
	return "\n".join(lines)


func refresh_building_jobs_section() -> void:
	if building_jobs_section == null or building_job_list_box == null:
		return
	var selected_data = game_state.get_building_data(selected_panel_id)
	building_jobs_section.visible = selected_data != null
	if not building_jobs_section.visible:
		return
	for child: Node in building_job_list_box.get_children():
		building_job_list_box.remove_child(child)
		child.queue_free()

	var jobs: Array = game_state.get_building_jobs(selected_panel_id)
	var filled_count := 0
	for job: Dictionary in jobs:
		if StringName(job.get("character_id", &"")) != &"":
			filled_count += 1
	var building_state: Dictionary = game_state.get_building_state(selected_panel_id)
	var building_level := int(building_state.get("level", 1))
	var production_details: Dictionary = game_state.get_building_production_details(
		selected_panel_id
	)
	var slot_config: Dictionary = game_state.get_building_job_slot_count_config(
		selected_panel_id
	)
	var next_level_text := ""
	if building_level < 4 and not slot_config.is_empty():
		next_level_text = "｜升至%d级：%d岗" % [
			building_level + 1,
			int(slot_config.get(building_level + 1, jobs.size())),
		]
	building_jobs_summary_label.text = "建筑Lv.%d｜岗位：%d｜已分配：%d%s\n人员效率：%.1f%%｜最终生产倍率：×%.3f" % [
		building_level,
		jobs.size(),
		filled_count,
		next_level_text,
		float(production_details.get("personnel_efficiency_percent", 100.0)),
		float(production_details.get("final_production_multiplier", 1.0)),
	]
	building_recent_work_label.text = format_recent_life_work_feedback(
		game_state.get_recent_life_work_feedback(selected_panel_id)
	)
	if jobs.is_empty():
		building_job_list_box.add_child(create_label(
			"当前建筑暂无生活岗位。",
			17,
			Color(0.78, 0.80, 0.74),
			HORIZONTAL_ALIGNMENT_LEFT
		))
		return

	var idle_characters: Array = game_state.get_idle_life_characters()
	for job: Dictionary in jobs:
		var building_id := selected_panel_id
		var job_id := StringName(job.get("job_id", &""))
		var character_id := StringName(job.get("character_id", &""))
		var card := create_dark_panel("%sBuildingJobCard" % String(job_id).capitalize(), 0.82)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		building_job_list_box.add_child(card)
		var margin := create_margin(10)
		card.add_child(margin)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 6)
		margin.add_child(content)

		var occupant_name := "空缺"
		var preview_text := "等待分配生活角色"
		if character_id != &"":
			var character: Dictionary = game_state.get_roster_character(character_id)
			occupant_name = String(character.get("display_name", character_id))
			var preview: Dictionary = game_state.get_life_job_efficiency_preview(
				character_id, building_id, job_id
			)
			if bool(preview.get("success", false)):
				preview_text = "%s %d｜效率 %.1f%%（特性+%.1f%%）" % [
					get_life_stat_display_name(StringName(preview.get("attribute_id", &""))),
					int(preview.get("attribute_value", 0)),
					float(preview.get("efficiency_percent", 100.0)),
					float(preview.get("trait_bonus_percent", 0.0)),
				]
		content.add_child(create_label(
			"%s｜%s\n当前人员：%s｜%s" % [
				String(job.get("display_name", job_id)),
				get_life_stat_display_name(StringName(job.get("job_type", &""))),
				occupant_name,
				preview_text,
			],
			17,
			Color(0.94, 0.93, 0.86),
			HORIZONTAL_ALIGNMENT_LEFT
		))

		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 6)
		content.add_child(actions)
		if character_id != &"":
			var view_button := Button.new()
			view_button.text = "查看 %s" % occupant_name
			view_button.custom_minimum_size = Vector2(120, 36)
			apply_button_style(view_button, false)
			view_button.pressed.connect(open_life_character_from_building.bind(character_id))
			actions.add_child(view_button)
			var unassign_button := Button.new()
			unassign_button.text = "撤下"
			unassign_button.custom_minimum_size = Vector2(86, 36)
			apply_button_style(unassign_button, true)
			unassign_button.pressed.connect(unassign_building_job.bind(building_id, job_id))
			actions.add_child(unassign_button)
		for idle: Dictionary in idle_characters:
			var idle_id := StringName(idle.get("character_id", &""))
			var assign_button := Button.new()
			assign_button.text = ("%s替换" if character_id != &"" else "分配%s") % String(
				idle.get("display_name", idle_id)
			)
			assign_button.custom_minimum_size = Vector2(112, 36)
			apply_button_style(assign_button, character_id == &"")
			assign_button.pressed.connect(assign_life_from_building.bind(
				building_id, job_id, idle_id, character_id != &""
			))
			actions.add_child(assign_button)


func assign_life_from_building(
	building_id: StringName,
	job_id: StringName,
	character_id: StringName,
	replace_existing: bool
) -> void:
	if not begin_ui_action(StringName("building_job_%s_%s" % [building_id, job_id])):
		building_job_feedback_label.text = "岗位操作正在处理中，请勿重复点击。"
		return
	var success: bool
	if replace_existing:
		success = game_state.replace_life_character_in_job(building_id, job_id, character_id)
	else:
		success = game_state.assign_life_character_to_job(character_id, building_id, job_id)
	building_job_feedback_label.text = String(
		game_state.get_last_operation_feedback().get(
			"message",
			"岗位已更新。" if success else "岗位更新失败，请确认角色为空闲且可用。"
		)
	)


func unassign_building_job(building_id: StringName, job_id: StringName) -> void:
	if not begin_ui_action(StringName("unassign_%s_%s" % [building_id, job_id])):
		building_job_feedback_label.text = "撤下操作正在处理中，请勿重复点击。"
		return
	var success: bool = game_state.unassign_building_job(building_id, job_id)
	building_job_feedback_label.text = String(
		game_state.get_last_operation_feedback().get(
			"message", "角色已撤下并恢复空闲。" if success else "撤下失败。"
		)
	)


func open_life_character_from_building(character_id: StringName) -> void:
	selected_life_character_id = character_id
	hide_detail_panel()
	show_life_character_page()


func refresh_food_workshop_section() -> void:
	if food_workshop_section == null:
		return
	food_workshop_section.visible = selected_panel_id == &"food_workshop"
	if not food_workshop_section.visible:
		return

	food_workshop_inventory_label.text = "当前库存：\n粮食：%d\n远征口粮：%d\n丰盛炖汤：%d\n猎手烤肉：%d" % [
		game_state.get_resource_amount("food"),
		game_state.get_item_count(&"expedition_ration"),
		game_state.get_item_count(&"hearty_stew"),
		game_state.get_item_count(&"hunter_roast"),
	]
	var production_state: Dictionary = game_state.get_food_production_state()
	if bool(production_state.get("is_active", false)):
		var recipe: Dictionary = game_state.get_food_recipe_data(StringName(production_state.get("recipe_id", &"")))
		var remaining: int = max(0, int(production_state.get("required_days", 0)) - int(production_state.get("progress_days", 0)))
		food_workshop_project_label.text = "当前项目：%s\n进度：%d / %d天\n剩余：%d天" % [
			String(recipe.get("display_name", "食物制造")),
			int(production_state.get("progress_days", 0)),
			int(production_state.get("required_days", 0)),
			remaining,
		]
	else:
		food_workshop_project_label.text = "当前项目：空闲"

	for child: Node in food_recipe_list_box.get_children():
		child.queue_free()
	for recipe: Dictionary in game_state.get_all_food_recipe_data():
		food_recipe_list_box.add_child(create_food_recipe_card(recipe))


func create_food_recipe_card(recipe: Dictionary) -> Control:
	var panel := create_dark_panel("FoodRecipeCard", 0.82)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := create_margin(10)
	panel.add_child(margin)
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)

	root.add_child(create_label(String(recipe.get("display_name", "")), 20, Color(1.0, 0.90, 0.62), HORIZONTAL_ALIGNMENT_LEFT))
	root.add_child(create_label(String(recipe.get("description", "")), 16, Color(0.90, 0.90, 0.82), HORIZONTAL_ALIGNMENT_LEFT))
	var ingredient_costs: Dictionary = recipe.get("ingredient_costs", {})
	var cost_parts := PackedStringArray()
	for raw_resource_id in ingredient_costs.keys():
		var resource_id := String(raw_resource_id)
		cost_parts.append("%s×%d" % [
			game_state.get_resource_display_name(resource_id),
			int(ingredient_costs[raw_resource_id]),
		])
	var effect_text := String(recipe.get("effect_text", ""))
	var output_line := "产出：%s×%d" % [
		game_state.get_item_display_name(StringName(recipe.get("output_item_id", &""))),
		int(recipe.get("output_amount", 0)),
	]
	if not effect_text.is_empty():
		output_line += "\n远征效果：%s" % effect_text
	root.add_child(create_label("消耗：%s\n工期：%d天\n%s" % [
		" ".join(cost_parts),
		int(recipe.get("duration_days", 0)),
		output_line,
	], 17, Color(0.94, 0.94, 0.86), HORIZONTAL_ALIGNMENT_LEFT))

	var recipe_id := StringName(recipe.get("recipe_id", &""))
	var error_text := String(recipe.get("start_error", ""))
	var button := Button.new()
	button.text = "开始制作" if error_text.is_empty() else error_text
	button.custom_minimum_size = Vector2(0, 38)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = not error_text.is_empty()
	button.tooltip_text = error_text
	apply_button_style(button, true)
	button.pressed.connect(start_food_recipe.bind(recipe_id))
	root.add_child(button)
	return panel


func start_food_recipe(recipe_id: StringName) -> void:
	if game_state.start_food_recipe(recipe_id):
		var recipe: Dictionary = game_state.get_food_recipe_data(recipe_id)
		food_workshop_feedback_label.text = "已开始制作：%s" % String(recipe.get("display_name", ""))
	else:
		food_workshop_feedback_label.text = game_state.get_food_recipe_start_error(recipe_id)
	refresh_food_workshop_section()
	refresh_detail_panel()
	refresh_building_views()


func refresh_hospital_section() -> void:
	if hospital_section == null:
		return
	hospital_section.visible = selected_panel_id == &"hospital"
	if not hospital_section.visible:
		return

	hospital_inventory_label.text = "当前库存：\n草药：%d\n药品：%d" % [
		game_state.get_resource_amount("herb"),
		game_state.get_resource_amount("medicine"),
	]

	var project_state: Dictionary = game_state.get_hospital_project_state()
	if bool(project_state.get("is_active", false)):
		var remaining: int = max(0, int(project_state.get("required_days", 0)) - int(project_state.get("progress_days", 0)))
		hospital_project_label.text = "当前项目：%s\n进度：%d / %d天\n剩余：%d天" % [
			String(project_state.get("display_name", "医院项目")),
			int(project_state.get("progress_days", 0)),
			int(project_state.get("required_days", 0)),
			remaining,
		]
	else:
		hospital_project_label.text = "当前项目：空闲"

	for child: Node in hospital_recipe_box.get_children():
		child.queue_free()
	hospital_recipe_box.add_child(create_hospital_medicine_card(game_state.get_hospital_medicine_recipe_data()))

	for child: Node in hospital_character_list_box.get_children():
		child.queue_free()
	for snapshot: Dictionary in game_state.get_all_combat_characters():
		var character_id := StringName(snapshot.get("character_id", &""))
		if character_id != &"":
			hospital_character_list_box.add_child(create_hospital_character_card(character_id))


func create_hospital_medicine_card(recipe: Dictionary) -> Control:
	var panel := create_dark_panel("HospitalMedicineCard", 0.82)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := create_margin(10)
	panel.add_child(margin)
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)

	root.add_child(create_label(String(recipe.get("display_name", "制作基础药品")), 20, Color(1.0, 0.90, 0.62), HORIZONTAL_ALIGNMENT_LEFT))
	root.add_child(create_label(String(recipe.get("description", "")), 16, Color(0.90, 0.90, 0.82), HORIZONTAL_ALIGNMENT_LEFT))
	root.add_child(create_label("消耗：草药×%d\n工期：%d天\n产出：药品×%d" % [
		int(recipe.get("herb_cost", 0)),
		int(recipe.get("required_days", 0)),
		int(recipe.get("medicine_output", 0)),
	], 17, Color(0.94, 0.94, 0.86), HORIZONTAL_ALIGNMENT_LEFT))

	var error_text := String(recipe.get("start_error", ""))
	var button := Button.new()
	button.text = "开始制药" if error_text.is_empty() else error_text
	button.custom_minimum_size = Vector2(0, 38)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = not error_text.is_empty()
	button.tooltip_text = error_text
	apply_button_style(button, true)
	button.pressed.connect(start_hospital_medicine_production)
	root.add_child(button)
	return panel


func create_hospital_character_card(character_id: StringName) -> Control:
	var panel := create_dark_panel("HospitalCharacterCard", 0.82)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := create_margin(10)
	panel.add_child(margin)
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)

	var detail: Dictionary = game_state.get_character_detail(character_id)
	var definition: Dictionary = detail.get("definition", {})
	var injury_state := StringName(detail.get("runtime_state", {}).get("injury_state", &"healthy"))
	var is_treating: bool = game_state.is_character_being_treated(character_id)
	var state_text := "治疗中" if is_treating else ("受伤" if injury_state == &"injured" else "健康")
	root.add_child(create_label("%s  %s" % [
		String(definition.get("display_name", character_id)),
		String(detail.get("profession_display_name", "")),
	], 20, Color(1.0, 0.90, 0.62), HORIZONTAL_ALIGNMENT_LEFT))

	var body := "状态：%s" % state_text
	if is_treating:
		var hospital_state: Dictionary = game_state.get_hospital_project_state()
		body += "\n进度：%d / %d天" % [
			int(hospital_state.get("progress_days", 0)),
			int(hospital_state.get("required_days", 0)),
		]
	elif injury_state == &"injured":
		body += "\n最大生命降低20%\n治疗消耗：草药×1\n治疗时间：1天"
	else:
		body += "\n无需治疗"
	root.add_child(create_label(body, 17, Color(0.94, 0.94, 0.86), HORIZONTAL_ALIGNMENT_LEFT))

	var error_text: String = game_state.get_treatment_disabled_reason(character_id)
	var button := Button.new()
	button.text = "开始治疗" if error_text.is_empty() else error_text
	button.custom_minimum_size = Vector2(0, 38)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = not error_text.is_empty()
	button.tooltip_text = error_text
	apply_button_style(button, false)
	button.pressed.connect(start_hospital_treatment.bind(character_id))
	root.add_child(button)
	return panel


func start_hospital_medicine_production() -> void:
	if game_state.start_medicine_production():
		hospital_feedback_label.text = "已开始制作基础药品。"
	else:
		hospital_feedback_label.text = game_state.get_medicine_disabled_reason()
	refresh_hospital_section()
	refresh_building_views()


func start_hospital_treatment(character_id: StringName) -> void:
	if game_state.start_treatment(character_id):
		hospital_feedback_label.text = "已开始治疗：%s" % game_state.get_character_display_name(character_id)
	else:
		hospital_feedback_label.text = game_state.get_treatment_disabled_reason(character_id)
	refresh_hospital_section()
	refresh_expedition_prep()
	refresh_building_views()


func refresh_projects() -> void:
	var growth: Dictionary = game_state.get_growth_summary()
	growth_label.text = "农田 Lv.%d（每日粮食 %d） | 医院 Lv.%d（%d 天/药品）\n队伍攻击 +%d | 队伍生命 +%d" % [
		int(growth["farm_level"]),
		int(growth["farm_daily_food"]),
		int(growth["clinic_level"]),
		int(growth["clinic_progress_required"]),
		int(growth["party_attack_bonus"]),
		int(growth["party_max_hp_bonus"]),
	]

	project_status_label.text = game_state.get_active_project_summary()
	growth_label.text = "农田 Lv.%d：种植中 %d/%d，下次收获 %d天\n医院 Lv.%d：%s\n队伍攻击 +%d | 队伍生命 +%d" % [
		int(growth["farm_level"]),
		int(growth["farm_active_plots"]),
		int(growth["farm_unlocked_plots"]),
		int(growth["farm_next_harvest_days"]),
		int(growth["clinic_level"]),
		game_state.get_active_hospital_summary(),
		int(growth["party_attack_bonus"]),
		int(growth["party_max_hp_bonus"]),
	]

	for raw_project_id in project_buttons.keys():
		var project_id := StringName(raw_project_id)
		var button: Button = project_buttons[project_id]
		var config: Dictionary = game_state.get_project_config(project_id)
		var cost_parts := PackedStringArray()
		if int(config.get("ore_cost", 0)) > 0:
			cost_parts.append("矿石 %d" % int(config["ore_cost"]))
		if int(config.get("herb_cost", 0)) > 0:
			cost_parts.append("草药 %d" % int(config["herb_cost"]))
		if cost_parts.is_empty():
			cost_parts.append("无消耗")

		var error_text: String = game_state.get_project_start_error(project_id)
		var state_text: String = "%d 天" % int(config["required_days"])
		if error_text == "项目已完成":
			state_text = "已完成"
		elif error_text == "已有进行中的项目":
			var project_state: Dictionary = game_state.get_project_state()
			if StringName(project_state.get("active_project_id", &"")) == project_id:
				state_text = "进行中"

		button.text = "%s | %s | %s" % [
			String(config["display_name"]),
			" ".join(cost_parts),
			state_text,
		]
		button.disabled = not error_text.is_empty()
		button.tooltip_text = error_text


func refresh_expedition_prep() -> void:
	var is_active: bool = game_state.is_expedition_active()
	var ration_stock: int = game_state.get_item_count(&"expedition_ration")
	var medicine_stock: int = game_state.get_resource_amount("medicine")

	if ration_stock < 1:
		food_spin_box.min_value = 0
		food_spin_box.max_value = 0
		food_spin_box.value = 0
		food_spin_box.editable = false
	else:
		food_spin_box.min_value = 1
		food_spin_box.max_value = min(10, ration_stock)
		food_spin_box.value = clampi(int(food_spin_box.value), 1, int(food_spin_box.max_value))
		food_spin_box.editable = not is_active

	medicine_spin_box.min_value = 0
	medicine_spin_box.max_value = min(5, medicine_stock)
	medicine_spin_box.value = clampi(int(medicine_spin_box.value), 0, int(medicine_spin_box.max_value))
	medicine_spin_box.editable = not is_active

	refresh_meal_options(is_active)
	var carried_food := int(food_spin_box.value)
	var carried_medicine := int(medicine_spin_box.value)
	expected_days_label.text = "远征口粮库存：%d\n预计支持：%d次日行动" % [ration_stock, carried_food]
	var start_error: String = game_state.get_expedition_start_error(carried_food, carried_medicine, selected_meal_id)
	start_expedition_button.disabled = not start_error.is_empty()
	start_expedition_button.tooltip_text = start_error
	advance_day_button.disabled = is_active
	advance_day_button.tooltip_text = "远征进行中时不能在村庄休整。" if is_active else ""
	if is_active:
		prep_status_label.text = "远征正在进行，请前往冒险页面。"
	elif start_error.is_empty():
		var meal_text: String = "无" if selected_meal_id == &"" else game_state.get_item_display_name(selected_meal_id)
		prep_status_label.text = "补给已就绪：远征口粮 %d，药品 %d，料理：%s。" % [carried_food, carried_medicine, meal_text]
	else:
		prep_status_label.text = start_error
	if readiness_label != null:
		readiness_label.text = format_readiness_report(game_state.get_expedition_readiness_report(carried_food, carried_medicine, selected_meal_id))


func format_readiness_report(report: Dictionary) -> String:
	var lines := PackedStringArray()
	var blocking: Array = report.get("blocking", [])
	var warnings: Array = report.get("warnings", [])
	lines.append("出发检查")
	if not blocking.is_empty():
		lines.append("暂时无法出发：")
		for item in blocking:
			lines.append("- %s" % String(item))
	elif not warnings.is_empty():
		lines.append("可以出发，但请注意：")
		for item in warnings:
			lines.append("- %s" % String(item))
	else:
		lines.append("补给和队伍状态良好。")
	return "\n".join(lines)


func refresh_daily_report(report: Dictionary) -> void:
	if report.is_empty():
		daily_report_label.text = "尚未推进时间。"
		return

	var raw_summary_lines = report.get("daily_summary_lines", null)
	if raw_summary_lines is Array:
		var summary_lines: Array = raw_summary_lines
		var display_lines := PackedStringArray(summary_lines)
		append_recent_work_feedback_lines(
			display_lines,
			int(report.get(
				"settled_day",
				report.get("day_before", game_state.current_day)
			))
		)
		daily_report_label.text = "\n".join(display_lines)
		return

	# Legacy, hot-reloaded, or partially damaged runtime reports may omit the
	# structured summary and some of the old flat keys. The daily report is UI
	# feedback, so missing optional data must degrade to defaults instead of
	# interrupting every state refresh.
	var settled_day := int(report.get(
		"settled_day",
		report.get("day_before", game_state.current_day)
	))
	var food_produced := int(report.get(
		"food_produced",
		report.get("farm_food_produced", 0)
	))
	var medicine_produced := int(report.get("medicine_produced", 0))
	var medicine_progress := int(report.get("medicine_progress", 0))
	var medicine_progress_required := int(report.get("medicine_progress_required", 0))
	var food_consumed := int(report.get("food_consumed", 0))
	var food_net := int(report.get(
		"food_net",
		int(report.get("food_after", 0)) - int(report.get("food_before", 0))
	))
	var medicine_net := int(report.get(
		"medicine_net",
		int(report.get("medicine_after", 0)) - int(report.get("medicine_before", 0))
	))
	var lines := PackedStringArray()
	lines.append("第 %d 天结算" % settled_day)
	lines.append("")
	lines.append("农田生产粮食：+%d" % food_produced)
	append_farm_report_lines(lines, report)
	if medicine_produced > 0:
		lines.append("医院完成药品：+%d" % medicine_produced)
	else:
		lines.append("医院生产进度：%d/%d" % [
			medicine_progress,
			medicine_progress_required,
		])
	lines.append("村庄消耗粮食：-%d" % food_consumed)
	if int(report.get("expedition_food_consumed", 0)) > 0:
		lines.append(
			"远征口粮消耗：-%d"
			% int(report.get("expedition_food_consumed", 0))
		)
	var project_report := get_safe_report_dictionary(report, "project_report")
	if bool(project_report.get("had_active_project", false)):
		lines.append("工坊项目：%s %d/%d" % [
			String(project_report.get("display_name", "建设项目")),
			int(project_report.get("progress_after", 0)),
			int(project_report.get("required_days", 0)),
		])
		if bool(project_report.get("project_completed", false)):
			lines.append("项目完成：%s" % String(project_report.get("effect_text", "")))
	var forge_report := get_safe_report_dictionary(report, "forge_report")
	if bool(forge_report.get("had_active_forge", false)):
		lines.append("装备打造：%s %d/%d" % [
			String(forge_report.get("display_name", "装备")),
			int(forge_report.get("progress_after", 0)),
			int(forge_report.get("required_days", 0)),
		])
		if bool(forge_report.get("forge_completed", false)):
			lines.append(String(forge_report.get("effect_text", "")))
	lines.append("")
	lines.append("粮食净变化：%s" % format_signed_amount(food_net))
	lines.append("药品净变化：%s" % format_signed_amount(medicine_net))
	daily_report_label.text = "\n".join(lines)


func get_safe_report_dictionary(report: Dictionary, key: String) -> Dictionary:
	var value = report.get(key, {})
	return value if value is Dictionary else {}


func get_safe_report_array(report: Dictionary, key: String) -> Array:
	var value = report.get(key, [])
	return value if value is Array else []


func append_recent_work_feedback_lines(lines: PackedStringArray, settled_day: int) -> void:
	var work_lines := PackedStringArray()
	for building_id: StringName in game_state.get_building_ids():
		var feedback: Dictionary = game_state.get_recent_life_work_feedback(building_id)
		if feedback.is_empty() or int(feedback.get("day", -1)) != settled_day:
			continue
		work_lines.append(format_recent_life_work_feedback(feedback))
	if work_lines.is_empty():
		return
	lines.append("")
	lines.append("角色工作成长")
	for line: String in work_lines:
		lines.append(line)


func format_recent_life_work_feedback(feedback: Dictionary) -> String:
	if feedback.is_empty():
		return "最近工作结果：暂无"
	var lines := PackedStringArray()
	lines.append("最近工作结果（第%d天）｜最终倍率 ×%.3f｜额外产出 +%d" % [
		int(feedback.get("day", 0)),
		float(feedback.get("final_production_multiplier", 1.0)),
		int(feedback.get("extra_output_amount", 0)),
	])
	if bool(feedback.get("treatment_completed", false)):
		lines.append("本次工作完成治疗。")
	for result: Dictionary in feedback.get("work_experience_results", []):
		var growth_parts := PackedStringArray()
		for raw_stat_id in result.get("growth_by_stat", {}).keys():
			var stat_id := StringName(raw_stat_id)
			var amount := int(result.get("growth_by_stat", {}).get(raw_stat_id, 0))
			if amount > 0:
				growth_parts.append("%s +%d" % [
					get_life_stat_display_name(stat_id), amount
				])
		var level_text := (
			"｜升级×%d至Lv.%d" % [
				int(result.get("levels_gained", 0)),
				int(result.get("new_level", 1)),
			]
			if int(result.get("levels_gained", 0)) > 0 else ""
		)
		if bool(result.get("at_max_level", false)):
			level_text += "｜已满级"
		lines.append("%s：工作经验 +%d%s%s" % [
			String(result.get("display_name", game_state.get_character_display_name(
				StringName(result.get("character_id", &""))
			))),
			int(result.get("experience_gained", 0)),
			level_text,
			"｜" + "、".join(growth_parts) if not growth_parts.is_empty() else "",
		])
	return "\n".join(lines)


func append_farm_report_lines(lines: PackedStringArray, report: Dictionary) -> void:
	var harvests := get_safe_report_array(report, "farm_harvests")
	if harvests.is_empty():
		var updates := get_safe_report_array(report, "farm_plot_updates")
		if updates.is_empty():
			lines.append("农田：没有种植进度")
			return
		lines.append("农田生长")
		for raw_update in updates:
			if not raw_update is Dictionary:
				continue
			var update: Dictionary = raw_update
			lines.append("地块%d：%s %d/%d" % [
				int(update.get("plot_id", 0)),
				get_crop_display_name(StringName(update.get("crop_id", &""))),
				int(update.get("progress_after", 0)),
				int(update.get("required_days", 0)),
			])
		return

	var wheat_count := 0
	var herb_count := 0
	for raw_harvest in harvests:
		if not raw_harvest is Dictionary:
			continue
		var harvest: Dictionary = raw_harvest
		match StringName(harvest.get("crop_id", &"")):
			&"wheat":
				wheat_count += 1
			&"herb":
				herb_count += 1
	lines.append("农田收获")
	if wheat_count > 0:
		lines.append("小麦成熟 x%d，粮食+%d" % [wheat_count, int(report.get("farm_food_produced", 0))])
	if herb_count > 0:
		lines.append("药草成熟 x%d，草药+%d" % [herb_count, int(report.get("farm_herb_produced", 0))])


func get_crop_display_name(crop_id: StringName) -> String:
	var crop_data = game_state.get_crop_data(crop_id)
	if crop_data == null:
		return String(crop_id)
	return String(crop_data.display_name)


func advance_day() -> void:
	game_state.advance_day("village_rest")


func start_growth_project(project_id: StringName) -> void:
	if game_state.start_project(project_id):
		var config: Dictionary = game_state.get_project_config(project_id)
		project_feedback_label.text = "已开始：%s" % String(config["display_name"])
	else:
		project_feedback_label.text = game_state.get_project_start_error(project_id)
	refresh_projects()
	refresh_detail_panel()


func on_supply_value_changed(_value: float) -> void:
	refresh_expedition_prep()


func refresh_meal_options(is_active: bool) -> void:
	if not meal_option_buttons.has(&""):
		return
	if selected_meal_id != &"" and game_state.get_item_count(selected_meal_id) <= 0:
		selected_meal_id = &""
	for raw_meal_id in meal_option_buttons.keys():
		var meal_id := StringName(raw_meal_id)
		var button: Button = meal_option_buttons[raw_meal_id]
		var count := 0
		var effect_text := ""
		if meal_id == &"":
			button.text = "不携带料理"
		else:
			count = game_state.get_item_count(meal_id)
			effect_text = game_state.food_workshop_system.get_output_effect_text(meal_id)
			button.text = "%s ×%d  %s" % [
				game_state.get_item_display_name(meal_id),
				count,
				effect_text,
			]
		button.button_pressed = meal_id == selected_meal_id
		button.disabled = is_active or (meal_id != &"" and count <= 0)
		button.tooltip_text = "库存不足" if meal_id != &"" and count <= 0 else effect_text


func select_expedition_meal(meal_id: StringName) -> void:
	selected_meal_id = meal_id
	refresh_expedition_prep()


func start_expedition() -> void:
	game_state.start_expedition(int(food_spin_box.value), int(medicine_spin_box.value), selected_meal_id)


func select_character(character_id: StringName) -> void:
	selected_character_id = character_id
	select_preferred_equipment_for_character(character_id)
	refresh_character_page()


func on_character_data_changed(_character_id: StringName) -> void:
	if character_page != null and character_page.visible:
		rebuild_character_buttons()
		refresh_character_page()


func on_character_roster_changed() -> void:
	if character_page != null and character_page.visible:
		rebuild_character_buttons()
		refresh_character_page()
	if life_character_page != null and life_character_page.visible:
		rebuild_life_character_buttons()
		refresh_life_character_page()
	if detail_panel != null and detail_panel.visible:
		refresh_building_jobs_section()


func on_life_job_assignments_changed(building_id: StringName) -> void:
	if selected_panel_id == building_id and detail_panel != null and detail_panel.visible:
		refresh_building_jobs_section()
	if life_character_page != null and life_character_page.visible:
		rebuild_life_character_buttons()
		refresh_life_character_page()


func on_life_recruitment_changed() -> void:
	if life_recruitment_page != null and life_recruitment_page.visible:
		refresh_life_recruitment_page()


func on_life_character_capacity_changed(
	_current_count: int,
	_capacity: int
) -> void:
	if life_character_page != null and life_character_page.visible:
		rebuild_life_character_buttons()
		refresh_life_character_page()
	if life_recruitment_page != null and life_recruitment_page.visible:
		refresh_life_recruitment_page()


func on_gameplay_notification_added(notification: Dictionary) -> void:
	if notification_label != null:
		notification_label.text = "最近提示：%s" % String(notification.get("message", ""))


func on_life_work_feedback_changed(building_id: StringName, _feedback: Dictionary) -> void:
	if detail_panel != null and detail_panel.visible and selected_panel_id == building_id:
		refresh_building_jobs_section()


func on_equipment_data_changed() -> void:
	if character_page != null and character_page.visible:
		refresh_equipment_panel()


func on_forge_data_changed() -> void:
	if forge_page != null and forge_page.visible:
		refresh_forge_page()


func on_food_workshop_data_changed() -> void:
	refresh_food_workshop_section()
	refresh_expedition_prep()


func on_food_recipe_report(_recipe_id: StringName) -> void:
	refresh_food_workshop_section()
	refresh_building_views()


func on_food_recipe_completed(_recipe_id: StringName, output_item_id: StringName, amount: int) -> void:
	if food_workshop_feedback_label != null:
		food_workshop_feedback_label.text = "制作完成：%s ×%d，已自动存入仓库。" % [
			game_state.get_item_display_name(output_item_id),
			amount,
		]
	refresh_food_workshop_section()
	refresh_expedition_prep()
	refresh_building_views()


func on_stackable_item_changed(_item_id: StringName, _new_count: int) -> void:
	refresh_food_workshop_section()
	refresh_expedition_prep()


func on_hospital_data_changed() -> void:
	refresh_hospital_section()
	refresh_expedition_prep()
	refresh_building_views()


func on_hospital_project_started(project_type: StringName, target_character_id: StringName) -> void:
	if hospital_feedback_label != null:
		if project_type == &"craft_medicine":
			hospital_feedback_label.text = "已开始制作基础药品。"
		elif project_type == &"treat_character":
			hospital_feedback_label.text = "已开始治疗：%s" % game_state.get_character_display_name(target_character_id)
	refresh_hospital_section()
	refresh_expedition_prep()
	refresh_building_views()


func on_medicine_production_completed(amount: int) -> void:
	if hospital_feedback_label != null:
		hospital_feedback_label.text = "基础药品制作完成，药品+%d。" % amount
	refresh_hospital_section()
	refresh_expedition_prep()
	refresh_building_views()


func on_character_treatment_started(character_id: StringName) -> void:
	if hospital_feedback_label != null:
		hospital_feedback_label.text = "%s正在医院接受治疗。" % game_state.get_character_display_name(character_id)
	refresh_hospital_section()
	refresh_expedition_prep()


func on_character_treatment_completed(character_id: StringName) -> void:
	if hospital_feedback_label != null:
		hospital_feedback_label.text = "%s治疗完成，已恢复健康。" % game_state.get_character_display_name(character_id)
	refresh_hospital_section()
	refresh_expedition_prep()
	refresh_building_views()


func on_character_injury_changed(_character_id: StringName, _injury_state: StringName) -> void:
	refresh_hospital_section()
	refresh_expedition_prep()
	if character_page != null and character_page.visible:
		refresh_character_page()


func on_building_state_changed(building_id: StringName) -> void:
	if building_views.has(building_id):
		var view: Control = building_views[building_id]
		view.refresh(game_state.get_building_state(building_id))
	if selected_panel_id == building_id:
		refresh_detail_panel()


func on_forge_report(report: Dictionary) -> void:
	if bool(report.get("forge_completed", false)) and forge_feedback_label != null:
		forge_feedback_label.text = String(report.get("effect_text", "打造完成，已加入仓库。"))
	if forge_page != null and forge_page.visible:
		refresh_forge_page()


func select_forge_recipe(recipe_id: StringName) -> void:
	selected_forge_recipe_id = recipe_id
	refresh_forge_page()


func refresh_forge_page() -> void:
	if forge_recipe_list_box == null:
		return
	refresh_forge_recipe_list()
	refresh_forge_recipe_detail()
	refresh_forge_actions()


func refresh_forge_recipe_list() -> void:
	for child: Node in forge_recipe_list_box.get_children():
		child.queue_free()
	forge_recipe_buttons.clear()

	var recipes: Array = game_state.get_all_forge_recipe_data()
	for recipe: Dictionary in recipes:
		var recipe_id: StringName = StringName(recipe.get("recipe_id", &""))
		var equipment: Dictionary = recipe.get("equipment_definition", {})
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 58)
		button.clip_text = true
		button.text = "%s\n%s  %s" % [
			String(recipe.get("display_name", "")),
			get_slot_display_name(StringName(equipment.get("slot_type", &""))),
			get_allowed_professions_text(equipment),
		]
		button.tooltip_text = String(recipe.get("start_error", ""))
		button.add_theme_font_size_override("font_size", 17)
		button.add_theme_color_override("font_color", get_rarity_color(StringName(equipment.get("rarity", &"common"))))
		button.add_theme_stylebox_override("normal", make_equipment_list_style(Color(0.07, 0.07, 0.07, 0.92), Color(0.32, 0.28, 0.22, 0.9)))
		button.add_theme_stylebox_override("hover", make_equipment_list_style(Color(0.14, 0.11, 0.08, 0.95), Color(0.72, 0.53, 0.28, 1.0)))
		button.add_theme_stylebox_override("disabled", make_equipment_list_style(Color(0.22, 0.16, 0.08, 0.98), Color(0.95, 0.70, 0.32, 1.0)))
		button.disabled = recipe_id == selected_forge_recipe_id
		button.pressed.connect(select_forge_recipe.bind(recipe_id))
		forge_recipe_list_box.add_child(button)
		forge_recipe_buttons[recipe_id] = button


func refresh_forge_recipe_detail() -> void:
	var recipe: Dictionary = game_state.get_forge_recipe_data(selected_forge_recipe_id)
	var equipment: Dictionary = recipe.get("equipment_definition", {})
	if recipe.is_empty() or equipment.is_empty():
		forge_status_label.text = "没有可用配方。"
		return

	var forge_state: Dictionary = game_state.get_forge_state()
	if bool(forge_state.get("is_active", false)):
		var active_recipe: Dictionary = game_state.get_forge_recipe_data(StringName(forge_state.get("active_recipe_id", &"")))
		forge_status_label.text = "当前打造：%s  进度：%d/%d天" % [
			String(active_recipe.get("display_name", "")),
			int(forge_state.get("progress_days", 0)),
			int(forge_state.get("required_days", 0)),
		]
	else:
		forge_status_label.text = "当前没有打造项目。选择配方后可消耗资源开始打造。"

	var rarity: StringName = StringName(equipment.get("rarity", &"common"))
	var slot_type: StringName = StringName(equipment.get("slot_type", &""))
	forge_recipe_title_label.text = String(equipment.get("display_name", ""))
	forge_recipe_title_label.add_theme_color_override("font_color", get_rarity_color(rarity))
	forge_recipe_meta_label.text = "%s   %s   %s" % [
		get_slot_display_name(slot_type),
		get_allowed_professions_text(equipment),
		get_rarity_display_name(rarity),
	]
	var power_label := "武器评分" if slot_type == &"weapon" else "护甲评分"
	forge_recipe_power_label.text = "%d  %s" % [int(equipment.get("item_power", 0)), power_label]
	forge_recipe_description_label.text = String(recipe.get("description", ""))
	forge_recipe_stats_label.text = "主要\n%s" % format_equipment_stats(equipment.get("stat_bonuses", {}))
	forge_recipe_affixes_label.text = "特殊\n%s" % format_equipment_affixes(equipment.get("affixes", []))
	forge_recipe_bottom_label.text = "需要职业：%s\n槽位：%s\n风味：%s" % [
		get_allowed_professions_text(equipment),
		get_slot_display_name(slot_type),
		String(equipment.get("flavor_text", "")),
	]


func refresh_forge_actions() -> void:
	var recipe: Dictionary = game_state.get_forge_recipe_data(selected_forge_recipe_id)
	if recipe.is_empty():
		forge_start_button.disabled = true
		forge_start_button.text = "无配方"
		forge_material_label.text = ""
		forge_time_label.text = ""
		return

	forge_material_label.text = format_forge_materials(recipe)
	forge_time_label.text = "工期：%d天\n当前状态：%s" % [
		int(recipe.get("craft_time_days", 0)),
		game_state.get_active_forge_summary(),
	]

	var error_text: String = game_state.get_forge_start_error(selected_forge_recipe_id)
	forge_start_button.disabled = not error_text.is_empty()
	forge_start_button.text = "开始打造" if error_text.is_empty() else error_text
	forge_start_button.tooltip_text = error_text


func start_selected_forge_recipe() -> void:
	if selected_forge_recipe_id == &"":
		return
	if game_state.start_forge_recipe(selected_forge_recipe_id):
		var recipe: Dictionary = game_state.get_forge_recipe_data(selected_forge_recipe_id)
		forge_feedback_label.text = "已开始打造：%s" % String(recipe.get("display_name", ""))
	else:
		forge_feedback_label.text = game_state.get_forge_start_error(selected_forge_recipe_id)
	refresh_forge_page()
	refresh_detail_panel()


func format_forge_materials(recipe: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("[color=#d8c89a]消耗[/color]")
	lines.append(format_material_line("矿石", game_state.get_resource_amount("ore"), int(recipe.get("ore_cost", 0))))
	lines.append(format_material_line("草药", game_state.get_resource_amount("herb"), int(recipe.get("herb_cost", 0))))
	if int(recipe.get("food_cost", 0)) > 0:
		lines.append(format_material_line("粮食", game_state.get_resource_amount("food"), int(recipe.get("food_cost", 0))))
	if int(recipe.get("medicine_cost", 0)) > 0:
		lines.append(format_material_line("药品", game_state.get_resource_amount("medicine"), int(recipe.get("medicine_cost", 0))))
	return "\n".join(lines)


func format_material_line(display_name: String, owned: int, required: int) -> String:
	var color := "#65d36e" if owned >= required else "#e05b4f"
	return "%s [color=%s]%d / %d[/color]" % [display_name, color, owned, required]


func select_preferred_equipment_for_character(character_id: StringName) -> void:
	var inventory: Array = game_state.get_equipment_inventory()
	for item: Dictionary in inventory:
		var instance_id: StringName = StringName(item.get("instance_id", &""))
		if game_state.can_equip_item(character_id, instance_id):
			selected_equipment_instance_id = instance_id
			return
	selected_equipment_instance_id = StringName(inventory[0].get("instance_id", &"")) if not inventory.is_empty() else &""


func refresh_equipment_panel() -> void:
	if equipment_list_box == null:
		return
	refresh_equipment_list()
	refresh_equipment_tip()
	refresh_equipment_actions()


func refresh_equipment_list() -> void:
	for child: Node in equipment_list_box.get_children():
		child.queue_free()
	equipment_buttons.clear()

	var inventory: Array = game_state.get_equipment_inventory()
	if inventory.is_empty():
		selected_equipment_instance_id = &""
		equipment_status_label.text = "仓库为空"
		return
	if selected_equipment_instance_id == &"":
		selected_equipment_instance_id = StringName(inventory[0].get("instance_id", &""))
	equipment_status_label.text = "固定测试装备：%d 件" % inventory.size()

	for item: Dictionary in inventory:
		var instance_id: StringName = StringName(item.get("instance_id", &""))
		var definition: Dictionary = item.get("definition", {})
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 38)
		button.clip_text = true
		button.text = "%s  %s%s" % [
			get_slot_display_name(StringName(definition.get("slot_type", &""))),
			String(definition.get("display_name", "")),
			get_equipped_suffix(StringName(item.get("equipped_by", &""))),
		]
		button.disabled = instance_id == selected_equipment_instance_id
		button.add_theme_font_size_override("font_size", 16)
		button.add_theme_color_override("font_color", get_rarity_color(StringName(definition.get("rarity", &"common"))))
		button.add_theme_stylebox_override("normal", make_equipment_list_style(Color(0.07, 0.07, 0.07, 0.92), Color(0.32, 0.28, 0.22, 0.9)))
		button.add_theme_stylebox_override("hover", make_equipment_list_style(Color(0.14, 0.11, 0.08, 0.95), Color(0.72, 0.53, 0.28, 1.0)))
		button.add_theme_stylebox_override("disabled", make_equipment_list_style(Color(0.22, 0.16, 0.08, 0.98), Color(0.95, 0.70, 0.32, 1.0)))
		button.pressed.connect(select_equipment.bind(instance_id))
		equipment_list_box.add_child(button)
		equipment_buttons[instance_id] = button


func select_equipment(instance_id: StringName) -> void:
	selected_equipment_instance_id = instance_id
	refresh_equipment_panel()


func refresh_equipment_tip() -> void:
	if selected_equipment_instance_id == &"":
		equipment_tip_status_label.text = "未选择装备"
		equipment_tip_name_label.text = ""
		equipment_tip_meta_label.text = ""
		equipment_tip_power_label.text = ""
		equipment_tip_primary_label.text = ""
		equipment_tip_special_label.text = ""
		equipment_tip_set_label.text = ""
		equipment_tip_flavor_label.text = ""
		equipment_tip_bottom_label.text = ""
		equipment_tip_compare_label.text = ""
		return

	var item: Dictionary = game_state.get_equipment_instance_data(selected_equipment_instance_id)
	var definition: Dictionary = item.get("definition", {})
	if definition.is_empty():
		return
	var equipped_by: StringName = StringName(item.get("equipped_by", &""))
	var slot_type: StringName = StringName(definition.get("slot_type", &""))
	var rarity: StringName = StringName(definition.get("rarity", &"common"))
	var is_equipped := equipped_by != &""

	equipment_tip_status_label.text = "已装备：%s" % get_character_display_name(equipped_by) if is_equipped else "背包中"
	equipment_tip_name_label.text = String(definition.get("display_name", ""))
	equipment_tip_name_label.add_theme_color_override("font_color", get_rarity_color(rarity))
	equipment_tip_meta_label.text = "%s   %s   %s" % [
		get_slot_display_name(slot_type),
		get_allowed_professions_text(definition),
		get_rarity_display_name(rarity),
	]
	var power_label := "武器评分" if slot_type == &"weapon" else "护甲评分"
	equipment_tip_power_label.text = "%d  %s" % [int(definition.get("item_power", 0)), power_label]
	equipment_tip_primary_label.text = "主要\n%s" % format_equipment_stats(definition.get("stat_bonuses", {}))
	equipment_tip_special_label.text = "特殊\n%s" % format_equipment_affixes(definition.get("affixes", []))
	equipment_tip_set_label.text = "套装（预留）\n%s" % String(definition.get("set_text", "当前未启用"))
	equipment_tip_flavor_label.text = "“%s”" % String(definition.get("flavor_text", ""))
	equipment_tip_bottom_label.text = "需要职业：%s\n装备唯一：否\n出售价格：%d" % [
		get_allowed_professions_text(definition),
		int(definition.get("vendor_price", 0)),
	]
	equipment_tip_compare_label.text = format_equipment_comparison(selected_character_id, selected_equipment_instance_id)


func refresh_equipment_actions() -> void:
	var has_selection := selected_equipment_instance_id != &""
	var equip_error: String = game_state.get_equip_item_error(selected_character_id, selected_equipment_instance_id) if has_selection else "未选择装备"
	var selected_item: Dictionary = game_state.get_equipment_instance_data(selected_equipment_instance_id) if has_selection else {}
	var selected_definition: Dictionary = selected_item.get("definition", {})
	var equipped_by: StringName = StringName(selected_item.get("equipped_by", &""))
	var selected_slot: StringName = StringName(selected_definition.get("slot_type", &""))
	var same_character_equipped := equipped_by == selected_character_id and equipped_by != &""
	var current_same_slot: StringName = game_state.get_equipped_equipment_instance_id(selected_character_id, selected_slot) if has_selection else &""

	if not has_selection:
		equip_button.disabled = true
		equip_button.text = "未选择"
		equip_button.tooltip_text = "未选择装备"
		equipment_action_hint_label.text = "请选择一件装备。"
	elif same_character_equipped:
		equip_button.disabled = true
		equip_button.text = "已装备"
		equip_button.tooltip_text = "这件装备已经穿在当前角色身上。"
		equipment_action_hint_label.text = "当前角色已装备这件装备。"
	elif not equip_error.is_empty():
		equip_button.disabled = true
		equip_button.text = "不可穿戴"
		equip_button.tooltip_text = equip_error
		equipment_action_hint_label.text = "不可穿戴：%s" % equip_error
	else:
		equip_button.disabled = false
		equip_button.text = "更换" if current_same_slot != &"" else "穿戴"
		equip_button.tooltip_text = ""
		equipment_action_hint_label.text = "可%s：%s" % [
			"更换" if current_same_slot != &"" else "穿戴",
			String(selected_definition.get("display_name", "")),
		]

	unequip_weapon_button.disabled = game_state.get_equipped_equipment_instance_id(selected_character_id, &"weapon") == &""
	unequip_armor_button.disabled = game_state.get_equipped_equipment_instance_id(selected_character_id, &"armor") == &""


func equip_selected_item() -> void:
	if selected_equipment_instance_id == &"":
		return
	game_state.equip_item(selected_character_id, selected_equipment_instance_id)
	refresh_character_page()


func unequip_character_slot(slot_type: StringName) -> void:
	game_state.unequip_item(selected_character_id, slot_type)
	refresh_character_page()


func select_life_character(character_id: StringName) -> void:
	selected_life_character_id = character_id
	life_assignment_feedback_label.text = ""
	refresh_life_character_page()


func on_life_filter_selected(index: int) -> void:
	life_filter_id = StringName(life_filter_option.get_item_metadata(index))
	rebuild_life_character_buttons()
	refresh_life_character_page()


func on_life_sort_selected(index: int) -> void:
	life_sort_id = StringName(life_sort_option.get_item_metadata(index))
	rebuild_life_character_buttons()
	refresh_life_character_page()


func toggle_selected_life_character_lock() -> void:
	var snapshot: Dictionary = game_state.get_roster_character(selected_life_character_id)
	if snapshot.is_empty():
		return
	var new_locked_state := not bool(snapshot.get("is_locked", false))
	var success: bool = game_state.set_life_character_locked(
		selected_life_character_id, new_locked_state
	)
	life_assignment_feedback_label.text = (
		"角色已锁定。" if new_locked_state else "角色已取消锁定。"
	) if success else "角色锁定状态修改失败。"


func request_dismiss_selected_life_character() -> void:
	var snapshot: Dictionary = game_state.get_roster_character(selected_life_character_id)
	if snapshot.is_empty() or bool(snapshot.get("is_locked", false)):
		life_assignment_feedback_label.text = "锁定角色不能解雇。"
		return
	pending_life_dismiss_id = selected_life_character_id
	var life_data: Dictionary = snapshot.get("life_data", {})
	var is_working := int(life_data.get("work_state", CharacterEnumsScript.WorkState.IDLE)) \
		== CharacterEnumsScript.WorkState.WORKING
	life_dismiss_confirm_dialog.dialog_text = "确认解雇「%s」？%s此操作不会返还资源。" % [
		String(snapshot.get("display_name", selected_life_character_id)),
		"角色将先从当前岗位安全撤下。" if is_working else "",
	]
	life_dismiss_confirm_dialog.popup_centered(Vector2i(480, 220))


func confirm_dismiss_life_character() -> void:
	var dismissed_id := pending_life_dismiss_id
	pending_life_dismiss_id = &""
	if dismissed_id == &"":
		return
	var success: bool = game_state.dismiss_life_character(dismissed_id, true)
	if success:
		var remaining: Array = game_state.get_filtered_sorted_life_characters(
			life_filter_id, life_sort_id
		)
		selected_life_character_id = StringName(
			remaining[0].get("character_id", &"")
		) if not remaining.is_empty() else &""
	life_assignment_feedback_label.text = "角色已解雇，岗位引用已清理。" if success else "解雇失败。"
	rebuild_life_character_buttons()
	refresh_life_character_page()


func refresh_life_recruitment_page() -> void:
	if life_recruitment_candidate_box == null:
		return
	for child: Node in life_recruitment_candidate_box.get_children():
		life_recruitment_candidate_box.remove_child(child)
		child.queue_free()
	var capacity: Dictionary = game_state.get_life_character_capacity_details()
	var costs: Dictionary = game_state.get_life_recruitment_costs()
	var resource_id := String(costs.get("resource_id", "food"))
	var refresh_cost := int(costs.get("refresh_cost", 0))
	var resource_amount: int = game_state.get_resource_amount(resource_id)
	life_recruitment_summary_label.text = "生活角色 %d / %d｜当前%s %d｜锁定候选刷新时保留" % [
		int(capacity.get("current_count", 0)),
		int(capacity.get("capacity", 0)),
		game_state.get_resource_display_name(resource_id),
		resource_amount,
	]
	life_recruitment_refresh_button.text = "刷新未锁定候选（%d %s）" % [
		refresh_cost,
		game_state.get_resource_display_name(resource_id),
	]
	life_recruitment_refresh_button.disabled = resource_amount < refresh_cost
	life_recruitment_refresh_button.tooltip_text = (
		"资源不足。" if resource_amount < refresh_cost else "锁定候选不会被替换。"
	)
	for candidate: Dictionary in game_state.get_life_recruitment_candidates():
		_add_life_recruitment_candidate_card(
			candidate,
			bool(capacity.get("is_full", false)),
			resource_amount
		)


func _add_life_recruitment_candidate_card(
	candidate: Dictionary,
	capacity_full: bool,
	resource_amount: int
) -> void:
	var candidate_id := StringName(candidate.get("candidate_id", &""))
	var card := create_dark_panel(
		"%sRecruitmentCandidate" % String(candidate_id).to_pascal_case(), 0.86
	)
	card.custom_minimum_size = Vector2(350, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	life_recruitment_candidate_box.add_child(card)
	var margin := create_margin(12)
	card.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)
	var portrait := TextureRect.new()
	portrait.name = "%sCandidatePortrait" % String(candidate_id).to_pascal_case()
	portrait.texture = load_texture_from_file(
		game_state.get_candidate_portrait_path(candidate)
	)
	portrait.custom_minimum_size = Vector2(0, 120)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	content.add_child(portrait)
	content.add_child(create_label(
		"%s｜%s｜Lv.%d｜%s" % [
			String(candidate.get("display_name", candidate_id)),
			String(candidate.get("quality_display_name", "普通")),
			int(candidate.get("level", 1)),
			"■ 候选锁定" if bool(candidate.get("is_locked", false)) else (
				"! 容量已满" if capacity_full else "○ 可招募"
			),
		],
		22,
		Color(1.0, 0.86, 0.52),
		HORIZONTAL_ALIGNMENT_LEFT
	))
	var stats: Dictionary = candidate.get("life_stats", {})
	content.add_child(create_label(
		"擅长：%s\n农业 %d｜制造 %d｜采集 %d｜研究 %d｜医疗 %d" % [
			String(candidate.get("specialty_display_name", "")),
			int(stats.get("farming", 0)),
			int(stats.get("crafting", 0)),
			int(stats.get("gathering", 0)),
			int(stats.get("research", 0)),
			int(stats.get("medical", 0)),
		],
		16,
		Color(0.94, 0.94, 0.86),
		HORIZONTAL_ALIGNMENT_LEFT
	))
	var trait_lines := PackedStringArray()
	for trait_data: Dictionary in candidate.get("trait_details", []):
		trait_lines.append("%s：%s" % [
			String(trait_data.get("display_name", "")),
			String(trait_data.get("description", "")),
		])
	content.add_child(create_label(
		"生活特性\n%s" % "\n".join(trait_lines),
		15,
		Color(0.84, 0.90, 0.76),
		HORIZONTAL_ALIGNMENT_LEFT
	))
	var cost := int(candidate.get("recruitment_cost", 0))
	content.add_child(create_label(
		"招募费用：%d 粮食" % cost,
		17,
		Color(0.98, 0.78, 0.44),
		HORIZONTAL_ALIGNMENT_LEFT
	))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	content.add_child(actions)
	var lock_button := Button.new()
	lock_button.name = "%sCandidateLockButton" % String(candidate_id).to_pascal_case()
	lock_button.text = "取消锁定" if bool(candidate.get("is_locked", false)) else "锁定候选"
	lock_button.custom_minimum_size = Vector2(130, 40)
	apply_button_style(lock_button, false)
	lock_button.pressed.connect(toggle_life_candidate_lock.bind(
		candidate_id, not bool(candidate.get("is_locked", false))
	))
	actions.add_child(lock_button)
	var recruit_button := Button.new()
	recruit_button.name = "%sRecruitButton" % String(candidate_id).to_pascal_case()
	recruit_button.text = "容量已满" if capacity_full else "资源不足" if resource_amount < cost else "招募"
	recruit_button.disabled = capacity_full or resource_amount < cost
	recruit_button.custom_minimum_size = Vector2(130, 40)
	apply_button_style(recruit_button, true)
	recruit_button.pressed.connect(recruit_life_candidate.bind(candidate_id))
	actions.add_child(recruit_button)


func refresh_life_candidates() -> void:
	if not begin_ui_action(&"refresh_candidates"):
		life_recruitment_feedback_label.text = "刷新操作正在处理中，请勿重复点击。"
		return
	var high_quality_names := PackedStringArray()
	for candidate: Dictionary in game_state.get_life_recruitment_candidates():
		if bool(candidate.get("is_locked", false)):
			continue
		if int(candidate.get("quality", CharacterEnumsScript.Quality.COMMON)) \
				>= CharacterEnumsScript.Quality.RARE:
			high_quality_names.append(String(candidate.get("display_name", "")))
	if not high_quality_names.is_empty():
		pending_life_refresh_confirmation = true
		life_refresh_confirm_dialog.dialog_text = (
			"以下未锁定高品质候选会被刷新：%s。\n\n已锁定候选仍会保留。是否继续？"
			% "、".join(high_quality_names)
		)
		life_refresh_confirm_dialog.popup_centered(Vector2i(540, 230))
		return
	perform_refresh_life_candidates()


func confirm_refresh_life_candidates() -> void:
	if not pending_life_refresh_confirmation:
		return
	pending_life_refresh_confirmation = false
	perform_refresh_life_candidates()


func cancel_refresh_life_candidates() -> void:
	pending_life_refresh_confirmation = false


func perform_refresh_life_candidates() -> void:
	var success: bool = game_state.refresh_life_recruitment_candidates()
	life_recruitment_feedback_label.text = (
		"未锁定候选已刷新。"
		if success
		else game_state.get_life_recruitment_last_error()
	)
	refresh_life_recruitment_page()


func toggle_life_candidate_lock(
	candidate_id: StringName,
	is_locked: bool
) -> void:
	var success: bool = game_state.set_life_recruitment_candidate_locked(
		candidate_id, is_locked
	)
	life_recruitment_feedback_label.text = (
		"候选已锁定。" if is_locked else "候选已取消锁定。"
	) if success else game_state.get_life_recruitment_last_error()
	refresh_life_recruitment_page()


func recruit_life_candidate(candidate_id: StringName) -> void:
	if not begin_ui_action(StringName("recruit_%s" % candidate_id)):
		life_recruitment_feedback_label.text = "招募操作正在处理中，请勿重复点击。"
		return
	var success: bool = game_state.recruit_life_candidate(candidate_id)
	if success:
		selected_life_character_id = candidate_id
		life_recruitment_feedback_label.text = "招募成功，角色已加入生活角色名册。"
		rebuild_life_character_buttons()
		refresh_life_character_page()
	else:
		life_recruitment_feedback_label.text = game_state.get_life_recruitment_last_error()
	refresh_life_recruitment_page()


func rebuild_life_character_buttons() -> void:
	if life_character_selector_box == null:
		return
	for child: Node in life_character_selector_box.get_children():
		life_character_selector_box.remove_child(child)
		child.queue_free()
	life_character_buttons.clear()
	for snapshot: Dictionary in game_state.get_filtered_sorted_life_characters(
		life_filter_id, life_sort_id
	):
		var character_id := StringName(snapshot.get("character_id", &""))
		var life_data: Dictionary = snapshot.get("life_data", {})
		var stats: Dictionary = life_data.get("life_stats", {})
		var building_id := StringName(life_data.get("assigned_building_id", &""))
		var job_id := StringName(life_data.get("assigned_job_id", &""))
		var assignment_text := "未分配"
		if building_id != &"" and job_id != &"":
			assignment_text = "%s｜%s" % [
				get_building_display_name(building_id),
				get_job_display_name(building_id, job_id),
			]
		var button := Button.new()
		button.name = "%sLifeCharacterButton" % String(character_id).capitalize()
		var work_status: String = game_state.get_life_work_state_display_name(
			int(life_data.get("work_state", 0))
		)
		var status_icon := (
			"●" if work_status == "工作中" else "×" if work_status == "不可用" else "○"
		)
		button.text = "%s｜%s｜Lv.%d｜%s %s%s\n%s\n农业%d 制造%d 采集%d 研究%d 医疗%d" % [
			String(snapshot.get("display_name", character_id)),
			game_state.get_life_quality_display_name(
				int(snapshot.get("quality", CharacterEnumsScript.Quality.COMMON))
			),
			int(snapshot.get("level", 1)),
			status_icon,
			work_status,
			"｜■ 已锁定" if bool(snapshot.get("is_locked", false)) else "",
			assignment_text,
			int(stats.get("farming", 0)),
			int(stats.get("crafting", 0)),
			int(stats.get("gathering", 0)),
			int(stats.get("research", 0)),
			int(stats.get("medical", 0)),
		]
		button.custom_minimum_size = Vector2(410, 88)
		button.clip_text = true
		apply_button_style(button, false)
		button.pressed.connect(select_life_character.bind(character_id))
		life_character_selector_box.add_child(button)
		life_character_buttons[character_id] = button


func refresh_life_character_page() -> void:
	if life_character_basic_label == null:
		return
	var capacity: Dictionary = game_state.get_life_character_capacity_details()
	life_capacity_label.text = "人数 %d / %d" % [
		int(capacity.get("current_count", 0)),
		int(capacity.get("capacity", 0)),
	]
	var all_life_characters: Array = game_state.get_all_life_characters()
	var life_characters: Array = game_state.get_filtered_sorted_life_characters(
		life_filter_id, life_sort_id
	)
	if life_characters.is_empty():
		if not game_state.has_roster_character(selected_life_character_id):
			selected_life_character_id = (
				StringName(all_life_characters[0].get("character_id", &""))
				if not all_life_characters.is_empty() else &""
			)
		life_character_basic_label.text = (
			"暂无生活角色，可前往招募。"
			if all_life_characters.is_empty() else "当前筛选条件下没有生活角色。"
		)
		life_character_portrait.texture = load_texture_from_file(
			game_state.get_character_portrait_path(&"")
		)
		life_character_experience_bar.value = 0
		life_lock_button.disabled = true
		life_dismiss_button.disabled = true
		return
	var snapshot: Dictionary = game_state.get_roster_character(selected_life_character_id)
	var selected_is_visible := false
	for visible_character: Dictionary in life_characters:
		if StringName(visible_character.get("character_id", &"")) == selected_life_character_id:
			selected_is_visible = true
			break
	if StringName(snapshot.get("character_type_name", &"")) != &"life" or not selected_is_visible:
		selected_life_character_id = StringName(life_characters[0].get("character_id", &""))
		snapshot = game_state.get_roster_character(selected_life_character_id)
	var life_data: Dictionary = snapshot.get("life_data", {})
	var stats: Dictionary = life_data.get("life_stats", {})
	var work_state := int(life_data.get("work_state", 0))
	var building_id := StringName(life_data.get("assigned_building_id", &""))
	var job_id := StringName(life_data.get("assigned_job_id", &""))
	for raw_id in life_character_buttons.keys():
		var button: Button = life_character_buttons[raw_id]
		button.disabled = StringName(raw_id) == selected_life_character_id

	var current_experience := int(snapshot.get(
		"experience", life_data.get("work_experience", 0)
	))
	var required_experience: int = game_state.get_life_character_upgrade_requirement(
		selected_life_character_id
	)
	var is_max_level := required_experience <= 0
	var is_locked := bool(snapshot.get("is_locked", false))
	var work_status: String = game_state.get_life_work_state_display_name(work_state)
	var status_icon := "●" if work_status == "工作中" else "×" if work_status == "不可用" else "○"
	life_character_basic_label.text = "%s\n品质：%s｜等级：Lv.%d%s\n状态：%s %s｜%s\n工作经验：%s" % [
		String(snapshot.get("display_name", selected_life_character_id)),
		game_state.get_life_quality_display_name(
			int(snapshot.get("quality", CharacterEnumsScript.Quality.COMMON))
		),
		int(snapshot.get("level", 1)),
		"（已满级）" if is_max_level else "",
		status_icon,
		work_status,
		"■ 已锁定" if is_locked else "未锁定",
		"已满级" if is_max_level else "%d / %d" % [
			current_experience, required_experience
		],
	]
	life_character_portrait.texture = load_texture_from_file(
		game_state.get_character_portrait_path(selected_life_character_id)
	)
	life_character_experience_bar.max_value = max(1, required_experience)
	life_character_experience_bar.value = 0 if is_max_level else current_experience
	life_character_experience_bar.tooltip_text = (
		"已满级" if is_max_level else "工作经验 %d / %d" % [
			current_experience, required_experience
		]
	)
	life_character_stats_label.text = "\n".join([
		"农业 farming：%d" % int(stats.get("farming", 0)),
		"制造 crafting：%d" % int(stats.get("crafting", 0)),
		"采集 gathering：%d" % int(stats.get("gathering", 0)),
		"研究 research：%d" % int(stats.get("research", 0)),
		"医疗 medical：%d" % int(stats.get("medical", 0)),
	])
	var trait_lines := PackedStringArray()
	for trait_data: Dictionary in game_state.get_life_trait_details(selected_life_character_id):
		var applicable_names := PackedStringArray()
		for raw_job_type in trait_data.get("applicable_job_types", []):
			applicable_names.append(get_life_stat_display_name(StringName(raw_job_type)))
		trait_lines.append("%s｜适用：%s\n%s" % [
			String(trait_data.get("display_name", "")),
			"、".join(applicable_names) if not applicable_names.is_empty() else "全部岗位",
			String(trait_data.get("description", "")),
		])
	life_character_trait_label.text = "\n\n".join(trait_lines) if not trait_lines.is_empty() else "无"
	if building_id == &"" or job_id == &"":
		life_character_assignment_label.text = "当前建筑：无\n当前岗位：无"
		life_character_efficiency_label.text = "选择下方岗位可查看适配属性与效率。"
	else:
		life_character_assignment_label.text = "当前建筑：%s\n当前岗位：%s" % [
			get_building_display_name(building_id),
			get_job_display_name(building_id, job_id),
		]
		var preview: Dictionary = game_state.get_life_job_efficiency_preview(
			selected_life_character_id, building_id, job_id
		)
		life_character_efficiency_label.text = format_life_efficiency_preview(preview)
	life_unassign_button.disabled = work_state != CharacterEnumsScript.WorkState.WORKING
	life_current_building_button.disabled = building_id == &""
	life_lock_button.text = "取消锁定" if is_locked else "锁定角色"
	life_lock_button.disabled = false
	life_dismiss_button.disabled = is_locked
	life_dismiss_button.tooltip_text = "锁定角色不能解雇。" if is_locked else "解雇会安全清理岗位引用。"
	rebuild_life_job_options(work_state, building_id, job_id)


func rebuild_life_job_options(work_state: int, current_building_id: StringName, current_job_id: StringName) -> void:
	if life_job_options_box == null:
		return
	for child: Node in life_job_options_box.get_children():
		life_job_options_box.remove_child(child)
		child.queue_free()
	for building_id: StringName in game_state.get_building_ids():
		for job: Dictionary in game_state.get_building_jobs(building_id):
			var job_id := StringName(job.get("job_id", &""))
			var occupant_id := StringName(job.get("character_id", &""))
			var occupant_name := "空缺"
			if occupant_id != &"":
				occupant_name = String(game_state.get_roster_character(occupant_id).get(
					"display_name", occupant_id
				))
			var preview: Dictionary = game_state.get_life_job_efficiency_preview(
				selected_life_character_id, building_id, job_id
			)
			var card := create_dark_panel(
				"%sLifeJobOption" % ("%s_%s" % [building_id, job_id]).capitalize(),
				0.82
			)
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			life_job_options_box.add_child(card)
			var margin := create_margin(9)
			card.add_child(margin)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			margin.add_child(row)
			var label := create_label(
				"%s｜%s｜当前：%s\n%s" % [
					get_building_display_name(building_id),
					String(job.get("display_name", job_id)),
					occupant_name,
					format_life_efficiency_preview(preview),
				],
				16,
				Color(0.93, 0.92, 0.84),
				HORIZONTAL_ALIGNMENT_LEFT
			)
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(label)
			var action_button := Button.new()
			action_button.custom_minimum_size = Vector2(136, 42)
			var is_current := occupant_id == selected_life_character_id \
				and building_id == current_building_id \
				and job_id == current_job_id
			if is_current:
				action_button.text = "当前岗位"
				action_button.disabled = true
			elif work_state == CharacterEnumsScript.WorkState.UNAVAILABLE:
				action_button.text = "不可分配"
				action_button.disabled = true
			elif work_state == CharacterEnumsScript.WorkState.WORKING:
				action_button.text = "请先撤下"
				action_button.disabled = true
			elif occupant_id == &"":
				action_button.text = "分配"
				action_button.pressed.connect(assign_selected_life_job.bind(
					building_id, job_id, false
				))
			else:
				action_button.text = "替换"
				action_button.pressed.connect(assign_selected_life_job.bind(
					building_id, job_id, true
				))
			apply_button_style(action_button, occupant_id == &"")
			row.add_child(action_button)


func assign_selected_life_job(
	building_id: StringName,
	job_id: StringName,
	replace_existing: bool
) -> void:
	if not begin_ui_action(StringName("life_job_%s_%s" % [building_id, job_id])):
		life_assignment_feedback_label.text = "岗位操作正在处理中，请勿重复点击。"
		return
	var success: bool
	if replace_existing:
		success = game_state.replace_life_character_in_job(
			building_id, job_id, selected_life_character_id
		)
	else:
		success = game_state.assign_life_character_to_job(
			selected_life_character_id, building_id, job_id
		)
	life_assignment_feedback_label.text = String(
		game_state.get_last_operation_feedback().get(
			"message",
			"岗位分配成功。" if success else "分配失败，请确认岗位与角色状态。"
		)
	)


func unassign_selected_life_character() -> void:
	if not begin_ui_action(StringName("unassign_life_%s" % selected_life_character_id)):
		life_assignment_feedback_label.text = "撤下操作正在处理中，请勿重复点击。"
		return
	var success: bool = game_state.unassign_life_character(selected_life_character_id)
	life_assignment_feedback_label.text = String(
		game_state.get_last_operation_feedback().get(
			"message", "已撤下，角色恢复空闲。" if success else "撤下失败。"
		)
	)


func open_selected_life_building() -> void:
	var snapshot: Dictionary = game_state.get_roster_character(selected_life_character_id)
	var building_id := StringName(snapshot.get("life_data", {}).get("assigned_building_id", &""))
	if building_id == &"":
		return
	hide_life_character_page()
	select_building(building_id)


func get_building_display_name(building_id: StringName) -> String:
	var data = game_state.get_building_data(building_id)
	return String(data.display_name) if data != null else String(building_id)


func get_job_display_name(building_id: StringName, job_id: StringName) -> String:
	for job: Dictionary in game_state.get_building_jobs(building_id):
		if StringName(job.get("job_id", &"")) == job_id:
			return String(job.get("display_name", job_id))
	return String(job_id)


func get_life_stat_display_name(stat_id: StringName) -> String:
	match stat_id:
		&"farming":
			return "农业"
		&"crafting":
			return "制造"
		&"gathering":
			return "采集"
		&"research":
			return "研究"
		&"medical":
			return "医疗"
	return String(stat_id)


func format_life_efficiency_preview(preview: Dictionary) -> String:
	if not bool(preview.get("success", false)):
		return "无法计算效率"
	return "%s %d：100%% + 属性%.1f%% + 特性%.1f%% = %.1f%%\n经验加成：+%.1f%%｜生产量加成：+%.1f%%" % [
		get_life_stat_display_name(StringName(preview.get("attribute_id", &""))),
		int(preview.get("attribute_value", 0)),
		float(preview.get("attribute_bonus_percent", 0.0)),
		float(preview.get("trait_bonus_percent", 0.0)),
		float(preview.get("efficiency_percent", 100.0)),
		float(preview.get("work_experience_bonus_percent", 0.0)),
		float(preview.get("production_bonus_percent", 0.0)),
	]


func rebuild_character_buttons() -> void:
	if character_selector_box == null:
		return
	for child: Node in character_selector_box.get_children():
		character_selector_box.remove_child(child)
		child.queue_free()
	character_buttons.clear()
	for snapshot: Dictionary in game_state.get_all_combat_characters():
		var character_id := StringName(snapshot.get("character_id", &""))
		if not COMBAT_PAGE_CHARACTER_IDS.has(character_id):
			continue
		var combat_data: Dictionary = snapshot.get("combat_data", {})
		var profession_id := StringName(combat_data.get("profession_id", &""))
		var final_stats: Dictionary = game_state.get_final_combat_stats(character_id)
		var party_text := "◆ 出战·%d位" % (int(combat_data.get("party_slot", -1)) + 1) if bool(combat_data.get("is_in_party", false)) else "◇ 待命"
		var injury_text := "✚ 受伤" if StringName(combat_data.get("injury_state", &"healthy")) == &"injured" else "健康"
		var button := Button.new()
		button.name = "%sCharacterButton" % String(character_id).capitalize()
		button.text = "%s｜%s｜Lv.%d\n生命 %d/%d｜%s｜%s" % [
			String(snapshot.get("display_name", character_id)),
			game_state.get_profession_display_name(profession_id),
			int(snapshot.get("level", 1)),
			int(combat_data.get("current_hp", 0)),
			int(final_stats.get("max_hp", 1)),
			party_text,
			injury_text,
		]
		button.custom_minimum_size = Vector2(225, 70)
		button.clip_text = true
		apply_button_style(button, false)
		button.pressed.connect(select_character.bind(character_id))
		character_selector_box.add_child(button)
		character_buttons[character_id] = button


func toggle_selected_character_party() -> void:
	var snapshot: Dictionary = game_state.get_roster_character(selected_character_id)
	var combat_data: Dictionary = snapshot.get("combat_data", {})
	if combat_data.is_empty():
		return
	var success: bool = game_state.set_character_party_status(
		selected_character_id, not bool(combat_data.get("is_in_party", false))
	)
	character_party_feedback_label.text = (
		String(game_state.get_last_operation_feedback().get("message", "编队已更新。"))
		if success else String(game_state.get_last_operation_feedback().get(
			"message", "编队失败。"
		))
	)


func move_selected_character_in_party(direction: int) -> void:
	var party_ids: Array[StringName] = game_state.get_character_ids()
	var current_slot := party_ids.find(selected_character_id)
	if current_slot < 0:
		return
	var success: bool = game_state.move_party_character(
		selected_character_id, current_slot + direction
	)
	character_party_feedback_label.text = String(
		game_state.get_last_operation_feedback().get(
			"message", "队伍顺序已调整。" if success else "队伍顺序调整失败。"
		)
	)


func refresh_character_page() -> void:
	if character_basic_label == null:
		return
	if not COMBAT_PAGE_CHARACTER_IDS.has(selected_character_id) or game_state.get_roster_character(selected_character_id).is_empty():
		selected_character_id = COMBAT_PAGE_CHARACTER_IDS[0]
	var detail: Dictionary = game_state.get_character_detail(selected_character_id)
	if detail.is_empty():
		return

	for raw_id in character_buttons.keys():
		var button: Button = character_buttons[raw_id]
		button.disabled = StringName(raw_id) == selected_character_id

	var definition: Dictionary = detail.get("definition", {})
	var runtime_state: Dictionary = detail.get("runtime_state", {})
	var roster_record: Dictionary = detail.get("roster_record", {})
	var combat_data: Dictionary = roster_record.get("combat_data", {})
	var skills: Array = detail.get("skills", [])
	var is_in_party := bool(combat_data.get("is_in_party", false))
	var party_slot := int(combat_data.get("party_slot", -1))
	var party_position := "◆ 出战·第%d位" % (party_slot + 1) if is_in_party else "◇ 待命"
	var injury_text := "✚ 受伤" if StringName(combat_data.get("injury_state", &"healthy")) == &"injured" else "健康"
	var required_experience := int(roster_record.get("experience_to_next_level", 0))
	var current_experience := int(roster_record.get("experience", 0))
	var is_max_level := required_experience <= 0
	character_basic_label.text = "%s\n职业：%s｜品质：%s\n等级：Lv.%d%s\n经验：%s\n当前生命：%d/%d\n状态：%s｜%s\n\n%s" % [
		String(definition.get("display_name", "")),
		String(detail.get("profession_display_name", "")),
		game_state.get_life_quality_display_name(int(roster_record.get(
			"quality", CharacterEnumsScript.Quality.COMMON
		))),
		int(roster_record.get("level", 1)),
		"（已满级）" if is_max_level else "",
		"已满级" if is_max_level else "%d / %d" % [
			current_experience, required_experience
		],
		int(runtime_state.get("current_hp", 0)),
		int(detail.get("final_stat_details", {}).get("max_hp", {}).get("final", 0)),
		injury_text,
		party_position,
		String(definition.get("description", "")),
	]
	character_experience_bar.max_value = max(1, required_experience)
	character_experience_bar.value = 0 if is_max_level else current_experience
	character_experience_bar.tooltip_text = (
		"已满级" if is_max_level else "经验 %d / %d" % [
			current_experience, required_experience
		]
	)

	var stat_details: Dictionary = detail.get("final_stat_details", {})
	character_combat_label.text = "\n".join([
		format_stat_line("最大生命", stat_details.get("max_hp", {})),
		format_stat_line("攻击", stat_details.get("attack", {})),
		format_stat_line("防御", stat_details.get("defense", {})),
		format_stat_line("速度", stat_details.get("speed", {})),
		"暴击率  %.1f%%" % (float(stat_details.get("crit_rate", {}).get("final", 0.0)) * 100.0),
		"暴击伤害  %.1f%%" % (float(stat_details.get("crit_damage", {}).get("final", 1.5)) * 100.0),
	])

	var skill_lines := PackedStringArray()
	for skill: Dictionary in skills:
		skill_lines.append("%s（冷却 %d 回合）" % [
			String(skill.get("skill_name", "未命名技能")),
			int(skill.get("skill_cooldown_duration", 0)),
		])
	character_skill_label.text = "\n".join(skill_lines) if not skill_lines.is_empty() else "无"

	var trait_lines := PackedStringArray()
	for trait_data: Dictionary in detail.get("traits", []):
		trait_lines.append("%s\n%s" % [
			String(trait_data.get("display_name", "")),
			String(trait_data.get("description", "")),
		])
	character_trait_label.text = "\n\n".join(trait_lines) if not trait_lines.is_empty() else "无"

	var party_ids: Array[StringName] = game_state.get_character_ids()
	var can_edit_party: bool = game_state.can_edit_party()
	character_party_label.text = "当前：%s\n出战顺序：%s" % [
		party_position,
		" → ".join(PackedStringArray(party_ids.map(func(character_id: StringName) -> String: return game_state.get_character_display_name(character_id)))),
	]
	character_party_toggle_button.text = "设为待命" if is_in_party else "加入出战"
	character_party_toggle_button.disabled = not can_edit_party or (is_in_party and party_ids.size() <= 1) or (not is_in_party and party_ids.size() >= 4)
	character_party_toggle_button.tooltip_text = "远征或战斗期间不能调整队伍" if not can_edit_party else ("至少保留1名出战角色" if is_in_party and party_ids.size() <= 1 else "")
	character_party_up_button.disabled = not can_edit_party or not is_in_party or party_slot <= 0
	character_party_down_button.disabled = not can_edit_party or not is_in_party or party_slot < 0 or party_slot >= party_ids.size() - 1

	var equipped_weapon: Dictionary = game_state.get_character_equipped_item_data(selected_character_id, &"weapon")
	var equipped_armor: Dictionary = game_state.get_character_equipped_item_data(selected_character_id, &"armor")
	var weapon_text := "未装备" if equipped_weapon.is_empty() else String(equipped_weapon.get("definition", {}).get("display_name", "未装备"))
	var armor_text := "未装备" if equipped_armor.is_empty() else String(equipped_armor.get("definition", {}).get("display_name", "未装备"))
	character_equipment_label.text = "武器：%s\n护甲：%s\n\n当前装备效果\n%s" % [
		weapon_text,
		armor_text,
		format_character_equipment_effects(selected_character_id),
	]

	refresh_character_sprite(StringName(definition.get("battle_visual_id", selected_character_id)))
	refresh_equipment_panel()


func refresh_character_sprite(visual_id: StringName) -> void:
	var visual_unit := {
		"unit_id": visual_id,
		"is_player_unit": true,
	}
	var visual: Dictionary = visual_registry.get_visual(visual_unit)
	character_sprite.sprite_frames = visual_registry.get_frames(visual_unit)
	character_sprite.scale = Vector2(1.5, 1.5)
	character_sprite.offset = Vector2(0, 0)
	character_sprite.flip_h = bool(visual.get("flip_h", false))
	if character_sprite.sprite_frames != null and character_sprite.sprite_frames.has_animation(&"idle"):
		character_sprite.play(&"idle")
	layout_character_sprite()


func layout_character_sprite() -> void:
	if character_sprite == null or character_art_area == null:
		return
	character_sprite.position = Vector2(character_art_area.size.x * 0.5, character_art_area.size.y * 0.60)


func add_character_section(parent: Control, title_text: String) -> Label:
	var panel := create_panel("%sCharacterPanel" % title_text, 0.78)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)

	var margin := create_margin(12)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	box.add_child(create_label(title_text, 22, Color(1.0, 0.86, 0.48), HORIZONTAL_ALIGNMENT_LEFT))
	var body := create_label("", 18, Color(0.94, 0.94, 0.86), HORIZONTAL_ALIGNMENT_LEFT)
	box.add_child(body)
	return body


func format_stat_line(display_name: String, detail: Dictionary) -> String:
	return "%s  基础:%d  成长:%s  村庄:%s  特性:%s  装备:%s  最终:%d" % [
		display_name,
		int(detail.get("base", 0)),
		format_signed_amount(int(detail.get("level_growth_bonus", 0))),
		format_signed_amount(int(detail.get("village_bonus", 0))),
		format_signed_amount(int(detail.get("trait_bonus", 0))),
		format_signed_amount(int(detail.get("equipment_bonus", 0))),
		int(detail.get("final", 0)),
	]


func format_equipment_stats(stat_bonuses: Dictionary) -> String:
	var lines := PackedStringArray()
	if int(stat_bonuses.get("attack", 0)) != 0:
		lines.append("%s 攻击" % format_signed_amount(int(stat_bonuses["attack"])))
	if int(stat_bonuses.get("defense", 0)) != 0:
		lines.append("%s 防御" % format_signed_amount(int(stat_bonuses["defense"])))
	if int(stat_bonuses.get("max_hp", 0)) != 0:
		lines.append("%s 最大生命" % format_signed_amount(int(stat_bonuses["max_hp"])))
	if int(stat_bonuses.get("speed", 0)) != 0:
		lines.append("%s 速度" % format_signed_amount(int(stat_bonuses["speed"])))
	if lines.is_empty():
		lines.append("无基础属性")
	return "\n".join(lines)


func format_equipment_affixes(affixes: Array) -> String:
	if affixes.is_empty():
		return "无特殊词条"
	var lines := PackedStringArray()
	for affix: Dictionary in affixes:
		lines.append("%s：%s" % [
			String(affix.get("display_name", "")),
			String(affix.get("description", "")),
		])
	return "\n".join(lines)


func format_character_equipment_effects(character_id: StringName) -> String:
	var affixes: Array = game_state.get_character_equipment_affixes(character_id)
	if affixes.is_empty():
		return "无"
	var lines := PackedStringArray()
	for affix: Dictionary in affixes:
		lines.append("%s\n%s" % [
			String(affix.get("display_name", "")),
			String(affix.get("description", "")),
		])
	return "\n\n".join(lines)


func format_equipment_comparison(character_id: StringName, instance_id: StringName) -> String:
	var diff: Dictionary = game_state.get_equipment_comparison(character_id, instance_id)
	if diff.is_empty():
		return ""
	var lines := PackedStringArray()
	lines.append("[color=#d8c89a]装备后变化[/color]")
	lines.append(format_compare_line("攻击", int(diff.get("attack", 0))))
	lines.append(format_compare_line("防御", int(diff.get("defense", 0))))
	lines.append(format_compare_line("最大生命", int(diff.get("max_hp", 0))))
	lines.append(format_compare_line("速度", int(diff.get("speed", 0))))
	return "\n".join(lines)


func format_compare_line(label_text: String, amount: int) -> String:
	var color := "#888888"
	if amount > 0:
		color = "#65d36e"
	elif amount < 0:
		color = "#e05b4f"
	return "%s [color=%s]%s[/color]" % [label_text, color, format_signed_amount(amount)]


func get_slot_display_name(slot_type: StringName) -> String:
	match slot_type:
		&"weapon":
			return "武器"
		&"armor":
			return "护甲"
	return String(slot_type)


func get_allowed_professions_text(definition: Dictionary) -> String:
	var professions: Array = definition.get("allowed_professions", [])
	if professions.is_empty():
		return "全职业"
	var names := PackedStringArray()
	for profession_id in professions:
		names.append(game_state.get_profession_display_name(StringName(profession_id)))
	return " / ".join(names)


func get_equipped_suffix(character_id: StringName) -> String:
	if character_id == &"":
		return ""
	return "（%s装备中）" % get_character_display_name(character_id)


func get_character_display_name(character_id: StringName) -> String:
	if character_id == &"":
		return ""
	return String(game_state.get_character_definition(character_id).get("display_name", character_id))


func get_rarity_display_name(rarity: StringName) -> String:
	match rarity:
		&"common":
			return "普通"
		&"magic":
			return "魔法"
		&"rare":
			return "稀有"
		&"legendary":
			return "传奇"
	return String(rarity)


func get_rarity_color(rarity: StringName) -> Color:
	match rarity:
		&"common":
			return Color(0.92, 0.92, 0.86)
		&"magic":
			return Color(0.32, 0.62, 1.0)
		&"rare":
			return Color(1.0, 0.84, 0.22)
		&"legendary":
			return Color(1.0, 0.48, 0.14)
	return Color.WHITE


func get_building_level_texture(building_id: StringName) -> Texture2D:
	var data = game_state.get_building_data(building_id)
	if data == null:
		return null
	var state: Dictionary = game_state.get_building_state(building_id)
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = load_texture_from_file(data.sheet_path)
	atlas_texture.region = data.get_level_region(int(state.get("level", 1)))
	return atlas_texture


func load_texture_from_file(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	if not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	var error := image.load(path)
	if error != OK:
		push_warning("Unable to load image: %s" % path)
		return null
	return ImageTexture.create_from_image(image)


func create_panel(node_name: String, alpha: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.add_theme_stylebox_override("panel", make_panel_style(alpha))
	return panel


func create_dark_panel(node_name: String, alpha: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.add_theme_stylebox_override("panel", make_dark_panel_style(alpha))
	return panel


func create_margin(size: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", size)
	margin.add_theme_constant_override("margin_top", size)
	margin.add_theme_constant_override("margin_right", size)
	margin.add_theme_constant_override("margin_bottom", size)
	return margin


func create_label(text: String, font_size: int, color: Color, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func create_experience_bar() -> ProgressBar:
	var bar := ProgressBar.new()
	bar.name = "CharacterExperienceBar"
	bar.custom_minimum_size = Vector2(0, 24)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 0.0
	bar.show_percentage = false
	return bar


func begin_ui_action(action_id: StringName, guard_msec: int = 300) -> bool:
	var now := Time.get_ticks_msec()
	if now < int(ui_action_guard_until_msec.get(action_id, 0)):
		return false
	ui_action_guard_until_msec[action_id] = now + maxi(1, guard_msec)
	return true


func create_supply_spin_box(minimum: int, maximum: int, value: int) -> SpinBox:
	var spin_box := SpinBox.new()
	spin_box.min_value = minimum
	spin_box.max_value = maximum
	spin_box.value = value
	spin_box.rounded = true
	spin_box.custom_minimum_size = Vector2(130, 44)
	spin_box.add_theme_font_size_override("font_size", 20)
	return spin_box


func create_spin_row(label_text: String, spin_box: SpinBox) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := create_label(label_text, 20, Color(0.94, 0.94, 0.86), HORIZONTAL_ALIGNMENT_LEFT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(spin_box)
	return row


func set_anchor_rect(control: Control, rect: Rect2) -> void:
	control.anchor_left = rect.position.x
	control.anchor_top = rect.position.y
	control.anchor_right = rect.position.x + rect.size.x
	control.anchor_bottom = rect.position.y + rect.size.y
	control.offset_left = 0
	control.offset_top = 0
	control.offset_right = 0
	control.offset_bottom = 0


func make_panel_style(alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.07, alpha)
	style.border_color = Color(0.86, 0.70, 0.38, 0.88)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	style.shadow_size = 10
	return style


func make_dark_panel_style(alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.022, 0.020, alpha)
	style.border_color = Color(0.58, 0.36, 0.18, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.62)
	style.shadow_size = 14
	return style


func make_hotspot_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.content_margin_left = 8
	style.content_margin_top = 5
	style.content_margin_right = 8
	style.content_margin_bottom = 5
	return style


func make_equipment_list_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 10
	style.content_margin_top = 6
	style.content_margin_right = 10
	style.content_margin_bottom = 6
	return style


func apply_button_style(button: Button, primary: bool) -> void:
	button.add_theme_font_size_override("font_size", 21)
	button.add_theme_color_override("font_color", Color(0.98, 0.95, 0.84))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.88))
	button.add_theme_color_override("font_pressed_color", Color(0.10, 0.08, 0.04))
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.55, 0.50))
	if primary:
		button.add_theme_stylebox_override("normal", make_hotspot_style(Color(0.36, 0.22, 0.08, 0.92), Color(0.96, 0.76, 0.32, 1.0)))
		button.add_theme_stylebox_override("hover", make_hotspot_style(Color(0.54, 0.34, 0.10, 0.96), Color(1.0, 0.88, 0.45, 1.0)))
		button.add_theme_stylebox_override("pressed", make_hotspot_style(Color(0.92, 0.72, 0.28, 1.0), Color(1.0, 0.96, 0.78, 1.0)))
	else:
		button.add_theme_stylebox_override("normal", make_hotspot_style(Color(0.11, 0.15, 0.12, 0.86), Color(0.65, 0.58, 0.38, 0.95)))
		button.add_theme_stylebox_override("hover", make_hotspot_style(Color(0.18, 0.25, 0.18, 0.92), Color(0.92, 0.76, 0.38, 1.0)))
		button.add_theme_stylebox_override("pressed", make_hotspot_style(Color(0.74, 0.60, 0.30, 1.0), Color(1.0, 0.94, 0.72, 1.0)))
	button.add_theme_stylebox_override("disabled", make_hotspot_style(Color(0.08, 0.08, 0.08, 0.72), Color(0.28, 0.28, 0.24, 0.8)))


func format_signed_amount(amount: int) -> String:
	if amount >= 0:
		return "+%d" % amount
	return str(amount)

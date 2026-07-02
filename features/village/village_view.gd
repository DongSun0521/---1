extends Control

const VILLAGE_BACKGROUND_PATH := "res://assets/art/village/village_main.png"
const FOREST_RACE_ART_PATH := "res://assets/art/characters/forest_race_sheet.png"
const BattleVisualRegistryScript := preload("res://scripts/data/battle_visual_registry.gd")
const VillageBuildingViewScript := preload("res://features/village/village_building_view.gd")

var game_state
var visual_registry: RefCounted = BattleVisualRegistryScript.new()
var selected_panel_id: StringName = &"farm"
var selected_character_id: StringName = &"guard"
var selected_equipment_instance_id: StringName = &""
var selected_forge_recipe_id: StringName = &"craft_iron_sword"
var building_views: Dictionary = {}

var resource_label: Label
var adventurer_label: Label
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
var start_expedition_button: Button
var advance_day_button: Button
var character_page: PanelContainer
var character_buttons: Dictionary = {}
var character_art_area: Control
var character_sprite: AnimatedSprite2D
var character_basic_label: Label
var character_combat_label: Label
var character_life_label: Label
var character_trait_label: Label
var character_equipment_label: Label
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


func _ready() -> void:
	game_state = get_node("/root/GameState")
	build_visual_layout()
	game_state.state_changed.connect(refresh)
	game_state.daily_report_generated.connect(refresh_daily_report)
	game_state.character_runtime_state_changed.connect(on_character_data_changed)
	game_state.character_final_stats_changed.connect(on_character_data_changed)
	game_state.equipment_inventory_changed.connect(on_equipment_data_changed)
	game_state.character_equipment_changed.connect(on_character_data_changed)
	game_state.forge_state_changed.connect(on_forge_data_changed)
	game_state.forge_project_started.connect(on_forge_report)
	game_state.forge_progress_changed.connect(on_forge_report)
	game_state.forge_project_completed.connect(on_forge_report)
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
	add_hotspot(&"codex", "角色详情", Rect2(0.03, 0.32, 0.16, 0.10))

	build_overview_panel()
	build_detail_panel()
	build_character_page()
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
	set_anchor_rect(panel, Rect2(0.02, 0.03, 0.32, 0.22))
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

	detail_body_label = create_label("", 20, Color(0.96, 0.95, 0.88), HORIZONTAL_ALIGNMENT_LEFT)
	content.add_child(detail_body_label)

	forge_entry_button = Button.new()
	forge_entry_button.text = "进入装备制造"
	forge_entry_button.custom_minimum_size = Vector2(0, 48)
	forge_entry_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply_button_style(forge_entry_button, true)
	forge_entry_button.pressed.connect(show_forge_page)
	content.add_child(forge_entry_button)

	build_project_section(content)
	build_prep_section(content)
	build_daily_report_section(content)


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

	expected_days_label = create_label("", 20, Color(0.93, 0.94, 0.86), HORIZONTAL_ALIGNMENT_LEFT)
	prep_section.add_child(expected_days_label)

	prep_status_label = create_label("", 19, Color(0.92, 0.88, 0.72), HORIZONTAL_ALIGNMENT_LEFT)
	prep_section.add_child(prep_status_label)

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

	var title := create_label("角色详情", 32, Color(1.0, 0.92, 0.66), HORIZONTAL_ALIGNMENT_LEFT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(130, 50)
	apply_button_style(close_button, true)
	close_button.pressed.connect(hide_character_page)
	header.add_child(close_button)

	var selector := HBoxContainer.new()
	selector.add_theme_constant_override("separation", 10)
	root_box.add_child(selector)
	for character_id: StringName in game_state.get_character_ids():
		var definition: Dictionary = game_state.get_character_definition(character_id)
		var button := Button.new()
		button.text = String(definition.get("display_name", character_id))
		button.custom_minimum_size = Vector2(150, 46)
		button.clip_text = true
		apply_button_style(button, false)
		button.pressed.connect(select_character.bind(character_id))
		selector.add_child(button)
		character_buttons[character_id] = button

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

	character_basic_label = add_character_section(info, "基础信息")
	character_combat_label = add_character_section(info, "战斗属性")
	character_life_label = add_character_section(info, "生活属性")
	character_trait_label = add_character_section(info, "特性")
	character_equipment_label = add_character_section(info, "装备")

	build_equipment_panel(body)


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
	button.name = "%sHotspot" % String(panel_id).capitalize()
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

	if panel_id == &"codex":
		button.pressed.connect(show_character_page)
	else:
		button.pressed.connect(select_panel.bind(panel_id))


func get_compact_hotspot_rect(panel_id: StringName, fallback_rect: Rect2) -> Rect2:
	match panel_id:
		&"prep":
			return Rect2(0.80, 0.08, 0.14, 0.07)
		&"codex":
			return Rect2(0.03, 0.35, 0.13, 0.07)
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
	select_preferred_equipment_for_character(selected_character_id)
	refresh_character_page()


func hide_character_page() -> void:
	character_page.visible = false


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
	refresh_building_views()
	refresh_projects()
	refresh_expedition_prep()
	refresh_detail_panel()
	refresh_daily_report(game_state.get_last_daily_report())
	if character_page != null and character_page.visible:
		refresh_character_page()
	if forge_page != null and forge_page.visible:
		refresh_forge_page()


func refresh_detail_panel() -> void:
	var selected_data = game_state.get_building_data(selected_panel_id)
	workshop_art_rect.texture = get_building_level_texture(selected_panel_id)
	workshop_art_rect.visible = selected_data != null and workshop_art_rect.texture != null
	forge_entry_button.visible = selected_panel_id == &"weapon_forge"
	project_section.visible = selected_panel_id == &"weapon_forge" or selected_panel_id == &"project"
	prep_section.visible = selected_panel_id == &"prep"

	if selected_data != null:
		detail_title_label.text = "%s  Lv.%d" % [
			String(selected_data.display_name),
			int(game_state.get_building_state(selected_panel_id).get("level", 1)),
		]
		detail_body_label.text = format_building_operation_text(selected_panel_id)
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


func format_building_operation_text(building_id: StringName) -> String:
	var data = game_state.get_building_data(building_id)
	var state: Dictionary = game_state.get_building_state(building_id)
	var level := int(state.get("level", 1))
	var lines := PackedStringArray()
	lines.append("当前等级：%d" % level)
	lines.append("当前状态：%s" % String(state.get("status", "")))
	lines.append("")
	lines.append(String(data.description))
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
	var food_stock: int = game_state.get_resource_amount("food")
	var medicine_stock: int = game_state.get_resource_amount("medicine")

	if food_stock < 1:
		food_spin_box.min_value = 0
		food_spin_box.max_value = 0
		food_spin_box.value = 0
		food_spin_box.editable = false
	else:
		food_spin_box.min_value = 1
		food_spin_box.max_value = min(10, food_stock)
		food_spin_box.value = clampi(int(food_spin_box.value), 1, int(food_spin_box.max_value))
		food_spin_box.editable = not is_active

	medicine_spin_box.min_value = 0
	medicine_spin_box.max_value = min(5, medicine_stock)
	medicine_spin_box.value = clampi(int(medicine_spin_box.value), 0, int(medicine_spin_box.max_value))
	medicine_spin_box.editable = not is_active

	var carried_food := int(food_spin_box.value)
	var carried_medicine := int(medicine_spin_box.value)
	expected_days_label.text = "预计最多行动：%d 天" % carried_food
	var start_error: String = game_state.get_expedition_start_error(carried_food, carried_medicine)
	start_expedition_button.disabled = not start_error.is_empty()
	start_expedition_button.tooltip_text = start_error
	advance_day_button.disabled = is_active
	advance_day_button.tooltip_text = "远征进行中时不能在村庄休整。" if is_active else ""
	if is_active:
		prep_status_label.text = "远征正在进行，请前往冒险页面。"
	elif start_error.is_empty():
		prep_status_label.text = "补给已就绪：粮食 %d，药品 %d。" % [carried_food, carried_medicine]
	else:
		prep_status_label.text = start_error


func refresh_daily_report(report: Dictionary) -> void:
	if report.is_empty():
		daily_report_label.text = "尚未推进时间。"
		return

	var lines := PackedStringArray()
	lines.append("第 %d 天结算" % int(report["settled_day"]))
	lines.append("")
	lines.append("农田生产粮食：+%d" % int(report["food_produced"]))
	if int(report["medicine_produced"]) > 0:
		lines.append("医院完成药品：+%d" % int(report["medicine_produced"]))
	else:
		lines.append("医院生产进度：%d/%d" % [
			int(report["medicine_progress"]),
			int(report["medicine_progress_required"]),
		])
	lines.append("村庄消耗粮食：-%d" % int(report["food_consumed"]))
	if int(report.get("expedition_food_consumed", 0)) > 0:
		lines.append("远征粮食消耗：-%d" % int(report["expedition_food_consumed"]))
	var project_report: Dictionary = report.get("project_report", {})
	if bool(project_report.get("had_active_project", false)):
		lines.append("工坊项目：%s %d/%d" % [
			String(project_report["display_name"]),
			int(project_report["progress_after"]),
			int(project_report["required_days"]),
		])
		if bool(project_report.get("project_completed", false)):
			lines.append("项目完成：%s" % String(project_report.get("effect_text", "")))
	var forge_report: Dictionary = report.get("forge_report", {})
	if bool(forge_report.get("had_active_forge", false)):
		lines.append("装备打造：%s %d/%d" % [
			String(forge_report["display_name"]),
			int(forge_report["progress_after"]),
			int(forge_report["required_days"]),
		])
		if bool(forge_report.get("forge_completed", false)):
			lines.append(String(forge_report.get("effect_text", "")))
	lines.append("")
	lines.append("粮食净变化：%s" % format_signed_amount(int(report["food_net"])))
	lines.append("药品净变化：%s" % format_signed_amount(int(report["medicine_net"])))
	daily_report_label.text = "\n".join(lines)


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


func start_expedition() -> void:
	game_state.start_expedition(int(food_spin_box.value), int(medicine_spin_box.value))


func select_character(character_id: StringName) -> void:
	selected_character_id = character_id
	select_preferred_equipment_for_character(character_id)
	refresh_character_page()


func on_character_data_changed(_character_id: StringName) -> void:
	if character_page != null and character_page.visible:
		refresh_character_page()


func on_equipment_data_changed() -> void:
	if character_page != null and character_page.visible:
		refresh_equipment_panel()


func on_forge_data_changed() -> void:
	if forge_page != null and forge_page.visible:
		refresh_forge_page()


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


func refresh_character_page() -> void:
	if character_basic_label == null:
		return
	var detail: Dictionary = game_state.get_character_detail(selected_character_id)
	if detail.is_empty():
		return

	for raw_id in character_buttons.keys():
		var button: Button = character_buttons[raw_id]
		button.disabled = StringName(raw_id) == selected_character_id

	var definition: Dictionary = detail.get("definition", {})
	var runtime_state: Dictionary = detail.get("runtime_state", {})
	var skills: Array = detail.get("skills", [])
	var skill: Dictionary = skills[0] if not skills.is_empty() else {}
	character_basic_label.text = "%s\n职业：%s\n当前生命：%d/%d\n技能：%s\n\n%s" % [
		String(definition.get("display_name", "")),
		String(detail.get("profession_display_name", "")),
		int(runtime_state.get("current_hp", 0)),
		int(detail.get("final_stat_details", {}).get("max_hp", {}).get("final", 0)),
		String(skill.get("skill_name", "无")),
		String(definition.get("description", "")),
	]

	var stat_details: Dictionary = detail.get("final_stat_details", {})
	character_combat_label.text = "\n".join([
		format_stat_line("最大生命", stat_details.get("max_hp", {})),
		format_stat_line("攻击", stat_details.get("attack", {})),
		format_stat_line("防御", stat_details.get("defense", {})),
		format_stat_line("速度", stat_details.get("speed", {})),
	])

	var life_stats: Dictionary = definition.get("life_stats", {})
	character_life_label.text = "种植 %d\n锻造 %d\n烹饪 %d\n医疗 %d\n研究 %d\n采集 %d" % [
		int(life_stats.get("farming", 0)),
		int(life_stats.get("smithing", 0)),
		int(life_stats.get("cooking", 0)),
		int(life_stats.get("medicine", 0)),
		int(life_stats.get("research", 0)),
		int(life_stats.get("gathering", 0)),
	]

	var trait_lines := PackedStringArray()
	for trait_data: Dictionary in detail.get("traits", []):
		trait_lines.append("%s\n%s" % [
			String(trait_data.get("display_name", "")),
			String(trait_data.get("description", "")),
		])
	character_trait_label.text = "\n\n".join(trait_lines)

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
	return "%s  基础:%d  村庄:%s  特性:%s  装备:%s  最终:%d" % [
		display_name,
		int(detail.get("base", 0)),
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

extends Control

const VILLAGE_BACKGROUND_PATH := "res://assets/art/village/village_main.png"
const WORKSHOP_ART_PATH := "res://assets/art/buildings/weapon_forge_sheet.png"
const WORKSHOP_ART_FALLBACK_PATH := "res://assets/art/buildings/WuQi.png"
const FOREST_RACE_ART_PATH := "res://assets/art/characters/forest_race_sheet.png"

var game_state
var selected_panel_id: StringName = &"farm"

var resource_label: Label
var adventurer_label: Label
var detail_title_label: Label
var detail_body_label: Label
var workshop_art_rect: TextureRect
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
var project_buttons: Dictionary = {}


func _ready() -> void:
	game_state = get_node("/root/GameState")
	build_visual_layout()
	game_state.state_changed.connect(refresh)
	game_state.daily_report_generated.connect(refresh_daily_report)
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


func build_visual_layout() -> void:
	var background := TextureRect.new()
	background.name = "VillageBackground"
	background.texture = load_texture_from_file(VILLAGE_BACKGROUND_PATH)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var shade := ColorRect.new()
	shade.name = "ReadabilityShade"
	shade.color = Color(0.0, 0.0, 0.0, 0.12)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	add_hotspot(&"farm", "农田", Rect2(0.06, 0.63, 0.27, 0.24))
	add_hotspot(&"clinic", "医院 / 后勤区", Rect2(0.69, 0.61, 0.24, 0.22))
	add_hotspot(&"workshop", "工坊", Rect2(0.64, 0.18, 0.25, 0.24))
	add_hotspot(&"project", "当前建设项目", Rect2(0.42, 0.40, 0.17, 0.18))
	add_hotspot(&"prep", "开始远征", Rect2(0.78, 0.05, 0.18, 0.10))
	add_hotspot(&"codex", "种族设定", Rect2(0.03, 0.08, 0.16, 0.10))

	build_overview_panel()
	build_detail_panel()
	build_character_page()


func build_overview_panel() -> void:
	var panel := create_panel("VillageOverviewPanel", 0.9)
	set_anchor_rect(panel, Rect2(0.02, 0.03, 0.34, 0.26))
	add_child(panel)

	var margin := create_margin(18)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)

	var title := create_label("村庄总览", 28, Color(1.0, 0.92, 0.67), HORIZONTAL_ALIGNMENT_LEFT)
	content.add_child(title)

	resource_label = create_label("", 22, Color(0.96, 0.95, 0.86), HORIZONTAL_ALIGNMENT_LEFT)
	content.add_child(resource_label)

	var goal_label := create_label("目标：准备远征，推进工坊项目，最终击败遗迹守卫。", 20, Color(0.86, 0.92, 0.80), HORIZONTAL_ALIGNMENT_LEFT)
	content.add_child(goal_label)

	adventurer_label = create_label("", 18, Color(0.90, 0.90, 0.84), HORIZONTAL_ALIGNMENT_LEFT)
	content.add_child(adventurer_label)


func build_detail_panel() -> void:
	var panel := create_panel("VillageDetailPanel", 0.91)
	set_anchor_rect(panel, Rect2(0.68, 0.18, 0.30, 0.78))
	add_child(panel)

	var margin := create_margin(18)
	panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)

	detail_title_label = create_label("", 30, Color(1.0, 0.92, 0.66), HORIZONTAL_ALIGNMENT_LEFT)
	content.add_child(detail_title_label)

	workshop_art_rect = TextureRect.new()
	workshop_art_rect.custom_minimum_size = Vector2(0, 190)
	workshop_art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	workshop_art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	workshop_art_rect.texture = get_workshop_texture()
	content.add_child(workshop_art_rect)

	detail_body_label = create_label("", 21, Color(0.96, 0.95, 0.88), HORIZONTAL_ALIGNMENT_LEFT)
	content.add_child(detail_body_label)

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
	character_page = create_panel("ForestRacePage", 0.97)
	character_page.visible = false
	character_page.mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchor_rect(character_page, Rect2(0.04, 0.04, 0.92, 0.92))
	add_child(character_page)

	var margin := create_margin(24)
	character_page.add_child(margin)

	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 20)
	margin.add_child(layout)

	var art := TextureRect.new()
	art.texture = load_texture_from_file(FOREST_RACE_ART_PATH)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(art)

	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(420, 0)
	side.add_theme_constant_override("separation", 14)
	layout.add_child(side)

	side.add_child(create_label("种族设定", 32, Color(1.0, 0.92, 0.66), HORIZONTAL_ALIGNMENT_LEFT))
	side.add_child(create_label(
		"森裔\n\n更容易出现共生、再生、感知类基因。\n\n当前阶段作为世界观图鉴展示，不影响战斗与村庄数值。",
		22,
		Color(0.96, 0.94, 0.86),
		HORIZONTAL_ALIGNMENT_LEFT
	))

	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(0, 50)
	apply_button_style(close_button, true)
	close_button.pressed.connect(hide_character_page)
	side.add_child(close_button)


func add_hotspot(panel_id: StringName, text: String, rect: Rect2) -> void:
	var button := Button.new()
	button.name = "%sHotspot" % String(panel_id).capitalize()
	button.text = text
	button.custom_minimum_size = Vector2(120, 48)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = text
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color(1.0, 0.96, 0.82))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.90))
	button.add_theme_color_override("font_pressed_color", Color(0.10, 0.08, 0.04))
	button.add_theme_stylebox_override("normal", make_hotspot_style(Color(0.05, 0.11, 0.07, 0.50), Color(0.95, 0.78, 0.34, 0.95)))
	button.add_theme_stylebox_override("hover", make_hotspot_style(Color(0.19, 0.33, 0.14, 0.68), Color(1.0, 0.92, 0.45, 1.0)))
	button.add_theme_stylebox_override("pressed", make_hotspot_style(Color(0.95, 0.76, 0.26, 0.84), Color(1.0, 0.98, 0.82, 1.0)))
	set_anchor_rect(button, rect)
	add_child(button)

	if panel_id == &"codex":
		button.pressed.connect(show_character_page)
	else:
		button.pressed.connect(select_panel.bind(panel_id))


func select_panel(panel_id: StringName) -> void:
	selected_panel_id = panel_id
	refresh_detail_panel()


func show_character_page() -> void:
	character_page.visible = true


func hide_character_page() -> void:
	character_page.visible = false


func refresh() -> void:
	resource_label.text = game_state.get_resource_summary()
	adventurer_label.text = game_state.get_adventurer_summary()
	refresh_projects()
	refresh_expedition_prep()
	refresh_detail_panel()
	refresh_daily_report(game_state.get_last_daily_report())


func refresh_detail_panel() -> void:
	var farm: Dictionary = game_state.get_building_state(&"farm")
	var clinic: Dictionary = game_state.get_building_state(&"clinic")
	var workshop: Dictionary = game_state.get_building_state(&"workshop")
	var show_workshop_art := selected_panel_id == &"workshop" or selected_panel_id == &"project"
	workshop_art_rect.visible = show_workshop_art and workshop_art_rect.texture != null
	project_section.visible = selected_panel_id == &"workshop" or selected_panel_id == &"project"
	prep_section.visible = selected_panel_id == &"prep"

	match selected_panel_id:
		&"farm":
			detail_title_label.text = "农田"
			detail_body_label.text = "当前状态：%s\n等级：%d\n每日产量：%d 粮食\n\n农田负责支撑村庄基础消耗，并决定远征前能储备多少粮食。" % [
				String(farm["status"]),
				int(farm["level"]),
				int(farm["daily_food_production"]),
			]
		&"clinic":
			detail_title_label.text = "医院 / 后勤区"
			detail_body_label.text = "当前状态：%s\n等级：%d\n生产效率：每 %d 天制作 %d 药品\n当前进度：%d/%d\n\n药品用于远征和战斗中的恢复，草药可以投入医院扩建。" % [
				String(clinic["status"]),
				int(clinic["level"]),
				int(clinic["medicine_progress_required"]),
				int(clinic["medicine_output"]),
				int(clinic["medicine_progress"]),
				int(clinic["medicine_progress_required"]),
			]
		&"workshop":
			detail_title_label.text = "工坊"
			detail_body_label.text = "当前状态：%s\n等级：%d\n%s\n\n工坊负责武器强化、护甲强化和村庄建设项目。项目会随游戏日推进，不会打断远征流程。" % [
				String(workshop["status"]),
				int(workshop["level"]),
				game_state.get_active_project_summary(),
			]
		&"project":
			detail_title_label.text = "当前建设项目"
			detail_body_label.text = "后方项目会在远征推进天数时同步施工。\n\n%s" % game_state.get_active_project_summary()
		&"prep":
			detail_title_label.text = "开始远征"
			detail_body_label.text = "选择本次携带的粮食和药品。粮食决定最多能行动多少天，药品决定战斗中的容错。"
		_:
			detail_title_label.text = "村庄"
			detail_body_label.text = "选择场景中的建筑或入口查看详情。"


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


func get_workshop_texture() -> Texture2D:
	if FileAccess.file_exists(WORKSHOP_ART_PATH):
		return load_texture_from_file(WORKSHOP_ART_PATH)
	if FileAccess.file_exists(WORKSHOP_ART_FALLBACK_PATH):
		return load_texture_from_file(WORKSHOP_ART_FALLBACK_PATH)
	return null


func load_texture_from_file(path: String) -> Texture2D:
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


func make_hotspot_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
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

extends MarginContainer

@onready var farm_label: Label = $Content/Buildings/FarmCard/FarmLabel
@onready var clinic_label: Label = $Content/Buildings/ClinicCard/ClinicLabel
@onready var workshop_label: Label = $Content/Buildings/WorkshopCard/WorkshopLabel
@onready var content_container: VBoxContainer = $Content
@onready var resource_label: Label = $Content/ResourceLabel
@onready var adventurer_label: Label = $Content/AdventurerLabel
@onready var advance_day_button: Button = $Content/Actions/AdvanceDayButton
@onready var food_spin_box: SpinBox = $Content/ExpeditionPrepPanel/PrepMargin/PrepContent/FoodRow/FoodSpinBox
@onready var medicine_spin_box: SpinBox = $Content/ExpeditionPrepPanel/PrepMargin/PrepContent/MedicineRow/MedicineSpinBox
@onready var expected_days_label: Label = $Content/ExpeditionPrepPanel/PrepMargin/PrepContent/ExpectedDaysLabel
@onready var prep_status_label: Label = $Content/ExpeditionPrepPanel/PrepMargin/PrepContent/PrepStatusLabel
@onready var start_expedition_button: Button = $Content/ExpeditionPrepPanel/PrepMargin/PrepContent/StartExpeditionButton
@onready var daily_report_label: Label = $Content/DailyReportPanel/ReportMargin/ReportContent/DailyReportLabel

var game_state
var growth_label: Label
var project_status_label: Label
var project_feedback_label: Label
var project_buttons: Dictionary = {}


func _ready() -> void:
	game_state = get_node("/root/GameState")
	setup_scroll_container()
	setup_project_panel()
	advance_day_button.text = "休整一天"
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


func setup_scroll_container() -> void:
	if content_container.get_parent() is ScrollContainer:
		return

	remove_child(content_container)
	var scroll_container := ScrollContainer.new()
	scroll_container.name = "ContentScroll"
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll_container)
	scroll_container.add_child(content_container)
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func setup_project_panel() -> void:
	if content_container.has_node("ProjectPanel"):
		return

	var project_panel := PanelContainer.new()
	project_panel.name = "ProjectPanel"
	project_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var project_margin := MarginContainer.new()
	project_margin.add_theme_constant_override("margin_left", 12)
	project_margin.add_theme_constant_override("margin_top", 10)
	project_margin.add_theme_constant_override("margin_right", 12)
	project_margin.add_theme_constant_override("margin_bottom", 10)
	project_panel.add_child(project_margin)

	var project_content := VBoxContainer.new()
	project_content.add_theme_constant_override("separation", 8)
	project_margin.add_child(project_content)

	var title_label := Label.new()
	title_label.text = "村庄成长"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	project_content.add_child(title_label)

	growth_label = Label.new()
	growth_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	project_content.add_child(growth_label)

	project_status_label = Label.new()
	project_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	project_content.add_child(project_status_label)

	var button_grid := GridContainer.new()
	button_grid.columns = 2
	button_grid.add_theme_constant_override("h_separation", 8)
	button_grid.add_theme_constant_override("v_separation", 8)
	project_content.add_child(button_grid)

	for project_id: StringName in game_state.get_project_ids():
		var project_button := Button.new()
		project_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		project_button.pressed.connect(start_growth_project.bind(project_id))
		button_grid.add_child(project_button)
		project_buttons[project_id] = project_button

	project_feedback_label = Label.new()
	project_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	project_content.add_child(project_feedback_label)

	var expedition_panel: Control = content_container.get_node("ExpeditionPrepPanel")
	var target_index: int = expedition_panel.get_index()
	content_container.add_child(project_panel)
	content_container.move_child(project_panel, target_index)


func refresh() -> void:
	refresh_buildings()
	resource_label.text = game_state.get_resource_summary()
	adventurer_label.text = game_state.get_adventurer_summary()
	refresh_projects()
	refresh_expedition_prep()
	refresh_daily_report(game_state.get_last_daily_report())


func refresh_buildings() -> void:
	var farm: Dictionary = game_state.get_building_state(&"farm")
	var clinic: Dictionary = game_state.get_building_state(&"clinic")
	var workshop: Dictionary = game_state.get_building_state(&"workshop")

	farm_label.text = "%s\n等级：%d\n状态：%s\n每日产量：%d粮食" % [
		String(farm["display_name"]),
		int(farm["level"]),
		String(farm["status"]),
		int(farm["daily_food_production"]),
	]
	clinic_label.text = "%s\n等级：%d\n状态：%s\n生产效率：每%d天制作%d药品\n当前进度：%d/%d" % [
		String(clinic["display_name"]),
		int(clinic["level"]),
		String(clinic["status"]),
		int(clinic["medicine_progress_required"]),
		int(clinic["medicine_output"]),
		int(clinic["medicine_progress"]),
		int(clinic["medicine_progress_required"]),
	]

	var workshop_project_text: String = game_state.get_active_project_summary()
	workshop_label.text = "%s\n等级：%d\n状态：%s\n%s" % [
		String(workshop["display_name"]),
		int(workshop["level"]),
		String(workshop["status"]),
		workshop_project_text,
	]


func refresh_projects() -> void:
	if growth_label == null or project_status_label == null:
		return

	var growth: Dictionary = game_state.get_growth_summary()
	growth_label.text = "农田Lv.%d（每日粮食%d） | 医院Lv.%d（%d天/药品） | 队伍攻击+%d | 队伍生命+%d" % [
		int(growth["farm_level"]),
		int(growth["farm_daily_food"]),
		int(growth["clinic_level"]),
		int(growth["clinic_progress_required"]),
		int(growth["party_attack_bonus"]),
		int(growth["party_max_hp_bonus"]),
	]

	var project_state: Dictionary = game_state.get_project_state()
	var active_project_id: StringName = project_state.get("active_project_id", &"")
	var completed_ids: Array = project_state.get("completed_project_ids", [])
	project_status_label.text = game_state.get_active_project_summary()

	for raw_project_id in project_buttons.keys():
		var project_id := StringName(raw_project_id)
		var button: Button = project_buttons[project_id]
		var config: Dictionary = game_state.get_project_config(project_id)
		var cost_parts := PackedStringArray()
		if int(config.get("ore_cost", 0)) > 0:
			cost_parts.append("矿石%d" % int(config["ore_cost"]))
		if int(config.get("herb_cost", 0)) > 0:
			cost_parts.append("草药%d" % int(config["herb_cost"]))
		if cost_parts.is_empty():
			cost_parts.append("无消耗")

		var state_text := ""
		if completed_ids.has(project_id):
			state_text = "已完成"
		elif active_project_id == project_id:
			state_text = "进行中"
		else:
			state_text = "%d天" % int(config["required_days"])

		button.text = "%s｜%s｜%s" % [
			String(config["display_name"]),
			" ".join(cost_parts),
			state_text,
		]
		button.disabled = not game_state.can_start_project(project_id)


func refresh_daily_report(report: Dictionary) -> void:
	if report.is_empty():
		daily_report_label.text = "尚未推进时间。"
		return

	var lines := PackedStringArray()
	lines.append("第%d天结算" % int(report["settled_day"]))
	lines.append("")
	lines.append("农田生产粮食：+%d" % int(report["food_produced"]))
	if int(report["medicine_produced"]) > 0:
		lines.append("医院完成药品：+%d" % int(report["medicine_produced"]))
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
	expected_days_label.text = "预计最多行动：%d天" % carried_food
	var start_error: String = game_state.get_expedition_start_error(carried_food, carried_medicine)
	start_expedition_button.disabled = not start_error.is_empty()
	advance_day_button.disabled = is_active
	if is_active:
		prep_status_label.text = "远征正在进行，请前往冒险页面。"
	elif start_error.is_empty():
		prep_status_label.text = "补给已就绪。"
	else:
		prep_status_label.text = start_error


func on_supply_value_changed(_value: float) -> void:
	refresh_expedition_prep()


func start_expedition() -> void:
	game_state.start_expedition(int(food_spin_box.value), int(medicine_spin_box.value))


func format_signed_amount(amount: int) -> String:
	if amount >= 0:
		return "+%d" % amount
	return str(amount)

extends MarginContainer

@onready var farm_label: Label = $Content/Buildings/FarmCard/FarmLabel
@onready var clinic_label: Label = $Content/Buildings/ClinicCard/ClinicLabel
@onready var workshop_label: Label = $Content/Buildings/WorkshopCard/WorkshopLabel
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


func _ready() -> void:
	game_state = get_node("/root/GameState")
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


func refresh() -> void:
	refresh_buildings()
	resource_label.text = game_state.get_resource_summary()
	adventurer_label.text = game_state.get_adventurer_summary()
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

	var workshop_project := String(workshop["current_project"])
	var workshop_project_text := "当前没有进行中的项目"
	if not workshop_project.is_empty():
		workshop_project_text = "当前项目：%s" % workshop_project
	workshop_label.text = "%s\n等级：%d\n状态：%s\n%s" % [
		String(workshop["display_name"]),
		int(workshop["level"]),
		String(workshop["status"]),
		workshop_project_text,
	]


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
	lines.append("")
	lines.append("粮食净变化：%s" % format_signed_amount(int(report["food_net"])))
	lines.append("药品净变化：%s" % format_signed_amount(int(report["medicine_net"])))
	daily_report_label.text = "\n".join(lines)


func advance_day() -> void:
	game_state.advance_day("manual_test")


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

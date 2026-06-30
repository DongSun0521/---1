extends MarginContainer

@onready var time_label: Label = $Content/TimeLabel
@onready var location_label: Label = $Content/LocationLabel
@onready var node_description_label: Label = $Content/NodeDescriptionLabel
@onready var supplies_label: Label = $Content/SuppliesPanel/SuppliesMargin/SuppliesLabel
@onready var village_status_label: Label = $Content/VillagePanel/VillageMargin/VillageStatusLabel
@onready var briefing_label: Label = $Content/BriefingPanel/BriefingMargin/BriefingLabel
@onready var next_button: Button = $Content/Actions/NextButton
@onready var gather_button: Button = $Content/Actions/GatherButton
@onready var return_button: Button = $Content/Actions/ReturnButton

var game_state
var boss_warning_dialog: ConfirmationDialog


func _ready() -> void:
	game_state = get_node("/root/GameState")
	setup_boss_warning_dialog()
	game_state.state_changed.connect(refresh)
	game_state.expedition_action_completed.connect(refresh_action_report)
	game_state.expedition_ended.connect(refresh_expedition_result)
	next_button.pressed.connect(request_move_to_next_node)
	gather_button.pressed.connect(gather_current_node)
	return_button.pressed.connect(return_to_village)
	refresh()


func _exit_tree() -> void:
	if game_state != null and game_state.state_changed.is_connected(refresh):
		game_state.state_changed.disconnect(refresh)
	if game_state != null and game_state.expedition_action_completed.is_connected(refresh_action_report):
		game_state.expedition_action_completed.disconnect(refresh_action_report)
	if game_state != null and game_state.expedition_ended.is_connected(refresh_expedition_result):
		game_state.expedition_ended.disconnect(refresh_expedition_result)


func setup_boss_warning_dialog() -> void:
	boss_warning_dialog = ConfirmationDialog.new()
	boss_warning_dialog.title = "遗迹入口"
	boss_warning_dialog.dialog_text = "遗迹入口深处存在强大的守卫。\n建议完成武器强化或护甲强化，并准备足够药品后再挑战。"
	boss_warning_dialog.confirmed.connect(move_to_next_node)
	add_child(boss_warning_dialog)


func refresh() -> void:
	time_label.text = "当前时间：第%d天" % int(game_state.current_day)
	refresh_village_status()

	if not game_state.is_expedition_active():
		location_label.text = "当前位置：未出发"
		node_description_label.text = "请先在村庄页面准备远征。"
		supplies_label.text = "远征物资：无"
		next_button.disabled = true
		gather_button.disabled = true
		return_button.disabled = true
		if game_state.get_last_expedition_report().is_empty():
			briefing_label.text = "尚未进行野外行动。"
		return

	var expedition_state: Dictionary = game_state.get_expedition_state()
	var current_node: Dictionary = game_state.get_current_expedition_node()
	location_label.text = "当前位置：%s" % String(current_node["display_name"])
	node_description_label.text = String(current_node["description"])
	if game_state.get_current_node_encounter_id() != &"" and game_state.is_current_battle_node_cleared():
		node_description_label.text += "\n本次远征已经清理。"
		if StringName(expedition_state["current_node_id"]) == &"ruins_entrance" and bool(game_state.boss_defeated):
			node_description_label.text += "\n遗迹守卫已被击败。"
	supplies_label.text = "远征粮食：%d\n远征药品：%d\n临时矿石：%d\n临时草药：%d\n临时核心：%d" % [
		int(expedition_state["carried_food"]),
		int(expedition_state["carried_medicine"]),
		int(expedition_state["cargo_ore"]),
		int(expedition_state["cargo_herb"]),
		int(expedition_state.get("cargo_core", 0)),
	]

	var next_node_name: String = game_state.get_next_expedition_node_name()
	if next_node_name.is_empty():
		next_button.text = "前方区域暂未开放"
	elif StringName(expedition_state["current_node_id"]) == &"herb_hill" and not bool(game_state.boss_defeated):
		next_button.text = "进入遗迹"
	else:
		next_button.text = "前往%s" % next_node_name
	next_button.disabled = not game_state.can_move_to_next_expedition_node()

	refresh_gather_button()
	return_button.disabled = false

	if int(expedition_state["carried_food"]) <= 0:
		briefing_label.text = "远征粮食已经耗尽，无法继续行动，请返回村庄。"
	else:
		refresh_action_report(game_state.get_last_expedition_action_report())


func refresh_village_status() -> void:
	var clinic: Dictionary = game_state.get_building_state(&"clinic")
	village_status_label.text = "后方村庄\n\n粮食库存：%d\n药品库存：%d\n矿石库存：%d\n草药库存：%d\n医院进度：%d/%d\n项目：%s" % [
		game_state.get_resource_amount("food"),
		game_state.get_resource_amount("medicine"),
		game_state.get_resource_amount("ore"),
		game_state.get_resource_amount("herb"),
		int(clinic["medicine_progress"]),
		int(clinic["medicine_progress_required"]),
		game_state.get_active_project_summary(),
	]


func refresh_gather_button() -> void:
	var gather_label: String = game_state.get_expedition_gather_label()
	if gather_label.is_empty():
		gather_button.text = "本节点无采集"
		gather_button.disabled = true
		return
	if game_state.has_collected_current_expedition_node():
		gather_button.text = "本次远征已经采集"
		gather_button.disabled = true
		return

	gather_button.text = gather_label
	gather_button.disabled = not game_state.can_gather_current_expedition_node()


func refresh_action_report(report: Dictionary) -> void:
	if report.is_empty():
		briefing_label.text = "尚未进行野外行动。"
		return

	var lines := PackedStringArray()
	lines.append("第%d天结束" % int(report["new_day"]))
	lines.append("")
	lines.append(String(report["action_text"]))
	lines.append("远征粮食：-%d" % int(report["expedition_food_consumed"]))
	if report.has("gather_resource") and int(report.get("gather_amount", 0)) > 0:
		lines.append("%s：+%d" % [
			get_resource_display_name(String(report["gather_resource"])),
			int(report["gather_amount"]),
		])
	lines.append("")
	lines.append("农田生产粮食：+%d" % int(report["food_produced"]))
	lines.append("村庄消耗粮食：-%d" % int(report["village_food_consumed"]))
	if int(report["medicine_produced"]) > 0:
		lines.append("医院完成药品：+%d" % int(report["medicine_produced"]))
	else:
		lines.append("医院生产进度：%d/%d" % [
			int(report["medicine_progress"]),
			int(report["medicine_progress_required"]),
		])
	var project_report: Dictionary = report.get("project_report", {})
	if bool(project_report.get("had_active_project", false)):
		lines.append("工坊项目：%s %d/%d" % [
			String(project_report["display_name"]),
			int(project_report["progress_after"]),
			int(project_report["required_days"]),
		])
		if bool(project_report.get("project_completed", false)):
			lines.append("项目完成：%s" % String(project_report.get("effect_text", "")))
	briefing_label.text = "\n".join(lines)


func refresh_expedition_result(report: Dictionary) -> void:
	if report.is_empty():
		return

	var lines := PackedStringArray()
	lines.append("远征完成")
	lines.append("")
	lines.append("远征持续：%d天" % int(report["duration_days"]))
	lines.append("到达最远地点：%s" % String(report["furthest_node_name"]))
	lines.append("")
	lines.append("远征消耗粮食：%d" % int(report["food_consumed"]))
	lines.append("剩余粮食带回：%d" % int(report["food_returned"]))
	lines.append("剩余药品带回：%d" % int(report["medicine_returned"]))
	lines.append("")
	lines.append("获得矿石：%d" % int(report["ore_gained"]))
	lines.append("获得草药：%d" % int(report["herb_gained"]))
	if int(report.get("core_gained", 0)) > 0:
		lines.append("获得核心：%d" % int(report["core_gained"]))
	lines.append("")
	lines.append("远征期间村庄生产粮食：%d" % int(report["village_food_produced"]))
	lines.append("远征期间村庄消耗粮食：%d" % int(report["village_food_consumed"]))
	lines.append("远征期间村庄生产药品：%d" % int(report["village_medicine_produced"]))
	briefing_label.text = "\n".join(lines)


func request_move_to_next_node() -> void:
	if should_show_boss_warning():
		boss_warning_dialog.popup_centered()
		return
	move_to_next_node()


func should_show_boss_warning() -> bool:
	if not game_state.is_expedition_active():
		return false
	var expedition_state: Dictionary = game_state.get_expedition_state()
	return StringName(expedition_state["current_node_id"]) == &"herb_hill" and not bool(game_state.boss_defeated)


func move_to_next_node() -> void:
	game_state.move_to_next_expedition_node()


func gather_current_node() -> void:
	game_state.gather_current_expedition_node()


func return_to_village() -> void:
	game_state.return_from_expedition()


func get_resource_display_name(resource_id: String) -> String:
	if resource_id == "ore":
		return "临时矿石"
	if resource_id == "herb":
		return "临时草药"
	return resource_id

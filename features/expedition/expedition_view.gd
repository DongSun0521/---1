extends MarginContainer

class RouteLayer:
	extends Control

	var node_positions: Dictionary = {}
	var node_states: Dictionary = {}

	func _draw() -> void:
		var ordered_nodes := [
			&"village_exit",
			&"forest_edge",
			&"ore_site",
			&"herb_hill",
			&"ruins_entrance",
		]
		for index in range(ordered_nodes.size() - 1):
			var from_id: StringName = ordered_nodes[index]
			var to_id: StringName = ordered_nodes[index + 1]
			if not node_positions.has(from_id) or not node_positions.has(to_id):
				continue
			var from_pos: Vector2 = node_positions[from_id]
			var to_pos: Vector2 = node_positions[to_id]
			var to_state: String = String(node_states.get(to_id, "locked"))
			var route_color := Color(0.38, 0.34, 0.24, 0.58)
			var route_width := 5.0
			if to_state == "reachable" or to_state == "boss_reachable":
				route_color = Color(1.0, 0.78, 0.28, 0.95)
				route_width = 8.0
			elif to_state == "current" or to_state == "cleared" or to_state == "collected":
				route_color = Color(0.74, 0.92, 0.70, 0.78)
				route_width = 6.0
			draw_line(from_pos, to_pos, route_color, route_width, true)
			draw_circle(from_pos.lerp(to_pos, 0.5), route_width * 0.52, route_color)


const FIELD_BACKGROUND_PATH := "res://assets/art/field/Level1.png"
const FIELD_FALLBACK_BACKGROUND_PATH := "res://assets/art/field/level2.png"
const TEAM_MARKER_PATH := "res://assets/art/team/teamlogo.png"

const NODE_ORDER := [
	&"village_exit",
	&"forest_edge",
	&"ore_site",
	&"herb_hill",
	&"ruins_entrance",
]
const NODE_VISUALS := {
	&"village_exit": {
		"display_name": "村庄出口",
		"short": "村",
		"position": Vector2(0.12, 0.72),
	},
	&"forest_edge": {
		"display_name": "森林边缘",
		"short": "林",
		"position": Vector2(0.30, 0.53),
	},
	&"ore_site": {
		"display_name": "废弃矿点",
		"short": "矿",
		"position": Vector2(0.50, 0.68),
	},
	&"herb_hill": {
		"display_name": "药草坡地",
		"short": "药",
		"position": Vector2(0.68, 0.42),
	},
	&"ruins_entrance": {
		"display_name": "遗迹入口",
		"short": "危",
		"position": Vector2(0.87, 0.28),
	},
}
const NODE_BUTTON_SIZE := Vector2(172, 76)
const TEAM_MARKER_SIZE := Vector2(76, 76)
const MOVE_ANIMATION_SECONDS := 0.78

var game_state
var input_locked: bool = false
var pending_move_to_node_id: StringName = &""
var current_team_node_id: StringName = &"village_exit"
var active_tween: Tween
var boss_warning_dialog: ConfirmationDialog

var map_panel: PanelContainer
var map_area: Control
var route_layer: RouteLayer
var team_marker: TextureRect
var lock_overlay: PanelContainer
var lock_label: Label
var node_buttons: Dictionary = {}

var location_label: Label
var supplies_label: Label
var party_label: Label
var project_label: Label
var village_stock_label: Label
var action_report_label: Label
var node_description_label: Label
var next_button: Button
var gather_button: Button
var return_button: Button


func _ready() -> void:
	game_state = get_node("/root/GameState")
	build_visual_layout()
	setup_boss_warning_dialog()
	connect_signals()
	refresh()


func _exit_tree() -> void:
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
	if game_state != null and game_state.state_changed.is_connected(refresh):
		game_state.state_changed.disconnect(refresh)
	if game_state != null and game_state.expedition_action_completed.is_connected(refresh_action_report):
		game_state.expedition_action_completed.disconnect(refresh_action_report)
	if game_state != null and game_state.expedition_ended.is_connected(refresh_expedition_result):
		game_state.expedition_ended.disconnect(refresh_expedition_result)


func connect_signals() -> void:
	game_state.state_changed.connect(refresh)
	game_state.expedition_action_completed.connect(refresh_action_report)
	game_state.expedition_ended.connect(refresh_expedition_result)
	map_area.resized.connect(layout_map_elements)
	next_button.pressed.connect(request_move_to_next_node)
	gather_button.pressed.connect(gather_current_node)
	return_button.pressed.connect(return_to_village)


func build_visual_layout() -> void:
	add_theme_constant_override("margin_left", 0)
	add_theme_constant_override("margin_top", 0)
	add_theme_constant_override("margin_right", 0)
	add_theme_constant_override("margin_bottom", 0)

	var content := VBoxContainer.new()
	content.name = "ExpeditionContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	add_child(content)

	var main_row := HBoxContainer.new()
	main_row.name = "MapAndStatus"
	main_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_row.add_theme_constant_override("separation", 12)
	content.add_child(main_row)

	build_map_panel(main_row)
	build_status_panel(main_row)
	build_action_bar(content)


func build_map_panel(parent: Control) -> void:
	map_panel = create_panel("ExpeditionMapPanel", 0.98)
	map_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_panel.size_flags_stretch_ratio = 7.0
	parent.add_child(map_panel)

	var margin := create_margin(12)
	map_panel.add_child(margin)

	map_area = Control.new()
	map_area.name = "MapArea"
	map_area.clip_contents = true
	map_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(map_area)

	var background := TextureRect.new()
	background.name = "FieldBackground"
	background.texture = get_texture_with_fallback(FIELD_BACKGROUND_PATH, FIELD_FALLBACK_BACKGROUND_PATH)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_area.add_child(background)

	var shade := ColorRect.new()
	shade.name = "MapReadabilityShade"
	shade.color = Color(0.02, 0.03, 0.02, 0.12)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_area.add_child(shade)

	route_layer = RouteLayer.new()
	route_layer.name = "RouteLayer"
	route_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	route_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_area.add_child(route_layer)

	for node_id: StringName in NODE_ORDER:
		var button := Button.new()
		button.name = "%sNodeButton" % String(node_id)
		button.custom_minimum_size = NODE_BUTTON_SIZE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.clip_text = true
		button.add_theme_font_size_override("font_size", 19)
		button.pressed.connect(request_move_to_node.bind(node_id))
		map_area.add_child(button)
		node_buttons[node_id] = button

	team_marker = TextureRect.new()
	team_marker.name = "TeamMarker"
	team_marker.texture = get_texture_with_fallback(TEAM_MARKER_PATH, "")
	team_marker.custom_minimum_size = TEAM_MARKER_SIZE
	team_marker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	team_marker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	team_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_area.add_child(team_marker)

	lock_overlay = create_panel("MapLockOverlay", 0.72)
	lock_overlay.visible = false
	lock_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	lock_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_area.add_child(lock_overlay)

	var lock_margin := create_margin(24)
	lock_overlay.add_child(lock_margin)
	var lock_box := VBoxContainer.new()
	lock_box.alignment = BoxContainer.ALIGNMENT_CENTER
	lock_margin.add_child(lock_box)
	lock_label = create_label("远征队正在移动...", 28, Color(1.0, 0.92, 0.64), HORIZONTAL_ALIGNMENT_CENTER)
	lock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lock_box.add_child(lock_label)


func build_status_panel(parent: Control) -> void:
	var status_panel := create_panel("ExpeditionStatusPanel", 0.93)
	status_panel.custom_minimum_size = Vector2(420, 0)
	status_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	status_panel.size_flags_stretch_ratio = 3.0
	parent.add_child(status_panel)

	var margin := create_margin(18)
	status_panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)

	content.add_child(create_label("远征状态", 30, Color(1.0, 0.90, 0.58), HORIZONTAL_ALIGNMENT_LEFT))
	location_label = create_label("", 22, Color(0.96, 0.95, 0.86), HORIZONTAL_ALIGNMENT_LEFT)
	content.add_child(location_label)
	node_description_label = create_label("", 18, Color(0.88, 0.92, 0.82), HORIZONTAL_ALIGNMENT_LEFT)
	content.add_child(node_description_label)

	supplies_label = add_status_section(content, "当前战利品与补给")
	party_label = add_status_section(content, "冒险队")
	project_label = add_status_section(content, "后方建设")
	village_stock_label = add_status_section(content, "村庄库存")
	action_report_label = add_status_section(content, "后方结算")


func build_action_bar(parent: Control) -> void:
	var panel := create_panel("ExpeditionActionBar", 0.94)
	panel.custom_minimum_size = Vector2(0, 104)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)

	var margin := create_margin(14)
	panel.add_child(margin)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 14)
	margin.add_child(actions)

	next_button = create_action_button("前往下一节点", true)
	gather_button = create_action_button("采集", false)
	return_button = create_action_button("返回村庄", false)
	actions.add_child(next_button)
	actions.add_child(gather_button)
	actions.add_child(return_button)


func setup_boss_warning_dialog() -> void:
	boss_warning_dialog = ConfirmationDialog.new()
	boss_warning_dialog.title = "遗迹入口"
	boss_warning_dialog.dialog_text = "遗迹入口深处存在强大的守卫。\n建议完成武器强化或护甲强化，并准备足够药品后再挑战。"
	boss_warning_dialog.confirmed.connect(confirm_boss_move)
	boss_warning_dialog.canceled.connect(unlock_input)
	boss_warning_dialog.close_requested.connect(unlock_input)
	add_child(boss_warning_dialog)


func refresh() -> void:
	refresh_status_panel()
	refresh_map()
	refresh_action_buttons()


func refresh_status_panel() -> void:
	if not game_state.is_expedition_active():
		location_label.text = "当前位置：未出发"
		node_description_label.text = "请先在村庄页面准备远征。"
		supplies_label.text = "远征物资：无"
		party_label.text = format_party_status()
		project_label.text = format_project_status()
		village_stock_label.text = format_village_stock()
		if game_state.get_last_expedition_report().is_empty():
			action_report_label.text = "尚未进行野外行动。"
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
	party_label.text = format_party_status()
	project_label.text = format_project_status()
	village_stock_label.text = format_village_stock()
	if not input_locked:
		refresh_action_report(game_state.get_last_expedition_action_report())


func refresh_map() -> void:
	var node_positions := get_node_positions()
	var node_states := get_node_visual_states()
	route_layer.node_positions = node_positions
	route_layer.node_states = node_states
	route_layer.queue_redraw()

	for node_id: StringName in NODE_ORDER:
		var button: Button = node_buttons[node_id]
		var visual: Dictionary = NODE_VISUALS[node_id]
		var state := String(node_states.get(node_id, "locked"))
		button.text = "%s  %s\n%s" % [
			String(visual["short"]),
			String(visual["display_name"]),
			get_node_status_text(node_id, state),
		]
		button.disabled = (state != "reachable" and state != "boss_reachable") or input_locked
		button.tooltip_text = get_node_tooltip(node_id, state)
		apply_node_style(button, state)

	if game_state.is_expedition_active():
		var expedition_state: Dictionary = game_state.get_expedition_state()
		current_team_node_id = StringName(expedition_state["current_node_id"])
	else:
		current_team_node_id = &"village_exit"
	team_marker.visible = game_state.is_expedition_active()
	layout_map_elements()
	lock_overlay.visible = input_locked


func refresh_action_buttons() -> void:
	var move_reason := get_move_disabled_reason()
	var gather_reason := get_gather_disabled_reason()
	next_button.disabled = not move_reason.is_empty()
	next_button.tooltip_text = move_reason
	gather_button.disabled = not gather_reason.is_empty()
	gather_button.tooltip_text = gather_reason
	var return_reason := get_return_disabled_reason()
	return_button.disabled = not return_reason.is_empty()
	return_button.tooltip_text = return_reason

	if not game_state.is_expedition_active():
		next_button.text = "尚未出发"
		gather_button.text = "尚未出发"
		return_button.text = "返回村庄"
		return

	var expedition_state: Dictionary = game_state.get_expedition_state()
	var next_node_name: String = game_state.get_next_expedition_node_name()
	if next_node_name.is_empty():
		next_button.text = "前方区域暂未开放"
	elif StringName(expedition_state["current_node_id"]) == &"herb_hill" and not bool(game_state.boss_defeated):
		next_button.text = "进入遗迹"
	else:
		next_button.text = "前往%s" % next_node_name

	var gather_label: String = game_state.get_expedition_gather_label()
	if gather_label.is_empty():
		gather_button.text = "本节点无采集"
	elif game_state.has_collected_current_expedition_node():
		gather_button.text = "本次远征已经采集"
	else:
		gather_button.text = gather_label


func layout_map_elements() -> void:
	if map_area == null:
		return
	var node_positions := get_node_positions()
	for node_id: StringName in NODE_ORDER:
		if not node_buttons.has(node_id):
			continue
		var button: Button = node_buttons[node_id]
		var center: Vector2 = node_positions[node_id]
		button.position = center - NODE_BUTTON_SIZE * 0.5
		button.size = NODE_BUTTON_SIZE

	if team_marker != null and team_marker.visible and node_positions.has(current_team_node_id):
		var marker_position: Vector2 = node_positions[current_team_node_id] - TEAM_MARKER_SIZE * 0.5 + Vector2(0, -58)
		team_marker.position = marker_position
		team_marker.size = TEAM_MARKER_SIZE

	if route_layer != null:
		route_layer.queue_redraw()


func request_move_to_node(node_id: StringName) -> void:
	if input_locked:
		return
	if not game_state.is_expedition_active():
		return
	var expedition_state: Dictionary = game_state.get_expedition_state()
	var current_node: Dictionary = game_state.get_current_expedition_node()
	if node_id != StringName(current_node["next_node_id"]):
		return
	if not game_state.can_move_to_next_expedition_node():
		return
	pending_move_to_node_id = node_id
	if should_show_boss_warning():
		lock_input("等待确认是否进入遗迹...")
		boss_warning_dialog.popup_centered()
		return
	animate_move_to_pending_node()


func request_move_to_next_node() -> void:
	if not game_state.is_expedition_active() or input_locked:
		return
	var current_node: Dictionary = game_state.get_current_expedition_node()
	var next_node_id: StringName = StringName(current_node["next_node_id"])
	if next_node_id == &"":
		return
	request_move_to_node(next_node_id)


func confirm_boss_move() -> void:
	animate_move_to_pending_node()


func animate_move_to_pending_node() -> void:
	if pending_move_to_node_id == &"":
		unlock_input()
		return
	var node_positions := get_node_positions()
	var expedition_state: Dictionary = game_state.get_expedition_state()
	var from_node_id: StringName = StringName(expedition_state["current_node_id"])
	if not node_positions.has(from_node_id) or not node_positions.has(pending_move_to_node_id):
		complete_pending_move()
		return

	lock_input("远征队正在移动...")
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
	active_tween = create_tween()
	var from_pos: Vector2 = node_positions[from_node_id] - TEAM_MARKER_SIZE * 0.5 + Vector2(0, -58)
	var to_pos: Vector2 = node_positions[pending_move_to_node_id] - TEAM_MARKER_SIZE * 0.5 + Vector2(0, -58)
	team_marker.visible = true
	team_marker.position = from_pos
	active_tween.tween_property(team_marker, "position", to_pos, MOVE_ANIMATION_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	active_tween.tween_callback(complete_pending_move)


func complete_pending_move() -> void:
	var target_node_id := pending_move_to_node_id
	pending_move_to_node_id = &""
	if target_node_id == &"":
		unlock_input()
		return
	game_state.move_to_next_expedition_node()
	unlock_input()
	refresh()


func gather_current_node() -> void:
	if input_locked or not game_state.can_gather_current_expedition_node():
		return
	lock_input("正在结算采集与后方生产...")
	game_state.gather_current_expedition_node()
	unlock_input()
	refresh()


func return_to_village() -> void:
	if input_locked:
		return
	game_state.return_from_expedition()


func should_show_boss_warning() -> bool:
	if not game_state.is_expedition_active():
		return false
	var expedition_state: Dictionary = game_state.get_expedition_state()
	return StringName(expedition_state["current_node_id"]) == &"herb_hill" and not bool(game_state.boss_defeated)


func lock_input(message: String) -> void:
	input_locked = true
	lock_label.text = message
	lock_overlay.visible = true
	refresh_action_buttons()


func unlock_input() -> void:
	input_locked = false
	pending_move_to_node_id = &""
	lock_overlay.visible = false
	refresh_action_buttons()


func refresh_action_report(report: Dictionary) -> void:
	if action_report_label == null:
		return
	if report.is_empty():
		action_report_label.text = "尚未进行野外行动。"
		return

	var lines := PackedStringArray()
	lines.append("第%d天结算" % int(report["new_day"]))
	lines.append(String(report["action_text"]))
	lines.append("远征粮食：-%d" % int(report["expedition_food_consumed"]))
	if report.has("gather_resource") and int(report.get("gather_amount", 0)) > 0:
		lines.append("%s：+%d" % [
			get_resource_display_name(String(report["gather_resource"])),
			int(report["gather_amount"]),
		])
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
		lines.append("%s进度：%d/%d" % [
			String(project_report["display_name"]),
			int(project_report["progress_after"]),
			int(project_report["required_days"]),
		])
		if bool(project_report.get("project_completed", false)):
			lines.append("%s已完成" % String(project_report["display_name"]))
			if not String(project_report.get("effect_text", "")).is_empty():
				lines.append(String(project_report["effect_text"]))
	action_report_label.text = "\n".join(lines)


func refresh_expedition_result(report: Dictionary) -> void:
	if report.is_empty() or action_report_label == null:
		return

	var lines := PackedStringArray()
	lines.append("远征完成")
	lines.append("远征持续：%d天" % int(report["duration_days"]))
	lines.append("最远到达：%s" % String(report["furthest_node_name"]))
	lines.append("远征消耗粮食：%d" % int(report["food_consumed"]))
	lines.append("剩余粮食带回：%d" % int(report["food_returned"]))
	lines.append("剩余药品带回：%d" % int(report["medicine_returned"]))
	lines.append("获得矿石：%d" % int(report["ore_gained"]))
	lines.append("获得草药：%d" % int(report["herb_gained"]))
	if int(report.get("core_gained", 0)) > 0:
		lines.append("获得核心：%d" % int(report["core_gained"]))
	lines.append("后方生产粮食：+%d" % int(report["village_food_produced"]))
	lines.append("后方消耗粮食：-%d" % int(report["village_food_consumed"]))
	lines.append("后方生产药品：+%d" % int(report["village_medicine_produced"]))
	action_report_label.text = "\n".join(lines)


func get_node_positions() -> Dictionary:
	var positions := {}
	for node_id: StringName in NODE_ORDER:
		var normalized: Vector2 = NODE_VISUALS[node_id]["position"]
		positions[node_id] = Vector2(map_area.size.x * normalized.x, map_area.size.y * normalized.y)
	return positions


func get_node_visual_states() -> Dictionary:
	var states := {}
	for node_id: StringName in NODE_ORDER:
		states[node_id] = "locked"

	if not game_state.is_expedition_active():
		states[&"village_exit"] = "current"
		return states

	var expedition_state: Dictionary = game_state.get_expedition_state()
	var current_node_id: StringName = StringName(expedition_state["current_node_id"])
	var next_node_id: StringName = StringName(game_state.get_current_expedition_node()["next_node_id"])
	var collected_node_ids: Array = expedition_state.get("collected_node_ids", [])
	var cleared_node_ids: Array = expedition_state.get("cleared_battle_node_ids", [])

	for node_id: StringName in NODE_ORDER:
		if node_id == current_node_id:
			states[node_id] = "current"
		elif collected_node_ids.has(node_id):
			states[node_id] = "collected"
		elif cleared_node_ids.has(node_id) or (node_id == &"ruins_entrance" and bool(game_state.boss_defeated)):
			states[node_id] = "cleared"
		elif NODE_ORDER.find(node_id) <= NODE_ORDER.find(current_node_id):
			states[node_id] = "visited"
		elif node_id == next_node_id and game_state.can_move_to_next_expedition_node():
			states[node_id] = "reachable"
		else:
			states[node_id] = "locked"

	if not bool(game_state.boss_defeated) and states.get(&"ruins_entrance", "locked") != "current":
		if states[&"ruins_entrance"] == "reachable":
			states[&"ruins_entrance"] = "boss_reachable"
		elif states[&"ruins_entrance"] != "cleared":
			states[&"ruins_entrance"] = "boss_danger"
	return states


func get_node_status_text(node_id: StringName, state: String) -> String:
	var markers := PackedStringArray()
	match state:
		"current":
			markers.append("当前位置")
		"reachable", "boss_reachable":
			markers.append("可前往")
		"cleared":
			markers.append("已清理")
		"collected":
			markers.append("已采集")
		"visited":
			markers.append("已到达")
		"boss_danger":
			markers.append("Boss危险")
		_:
			markers.append("未到达")
	if game_state.is_expedition_active():
		var expedition_state: Dictionary = game_state.get_expedition_state()
		var collected_node_ids: Array = expedition_state.get("collected_node_ids", [])
		var cleared_node_ids: Array = expedition_state.get("cleared_battle_node_ids", [])
		if collected_node_ids.has(node_id) and not markers.has("已采集"):
			markers.append("已采集")
		if (cleared_node_ids.has(node_id) or (node_id == &"ruins_entrance" and bool(game_state.boss_defeated))) and not markers.has("已清理"):
			markers.append("已清理")
	if node_id == &"ruins_entrance" and not bool(game_state.boss_defeated):
		markers.append("危险")
	return " / ".join(markers)


func get_node_tooltip(node_id: StringName, state: String) -> String:
	if input_locked:
		return "动画和结算期间不能操作。"
	if state == "reachable" or state == "boss_reachable":
		return "前往%s" % String(NODE_VISUALS[node_id]["display_name"])
	if state == "current":
		return "冒险队当前所在节点。"
	if not game_state.is_expedition_active():
		return "请先在村庄页面准备远征。"
	if int(game_state.get_expedition_state().get("carried_food", 0)) <= 0:
		return "远征粮食不足，不能继续前进。"
	return "只能沿路线前往高亮的下一个节点。"


func get_move_disabled_reason() -> String:
	if input_locked:
		return "动画和结算期间不能操作。"
	if not game_state.is_expedition_active():
		return "请先在村庄页面准备远征。"
	if game_state.is_battle_active():
		return "战斗进行中不能移动。"
	var expedition_state: Dictionary = game_state.get_expedition_state()
	if int(expedition_state["carried_food"]) < 1:
		return "远征粮食不足，不能继续前进。"
	if game_state.get_next_expedition_node_name().is_empty():
		return "前方区域暂未开放。"
	if not game_state.can_move_to_next_expedition_node():
		return "当前不能前往下一节点。"
	return ""


func get_gather_disabled_reason() -> String:
	if input_locked:
		return "动画和结算期间不能操作。"
	if not game_state.is_expedition_active():
		return "请先在村庄页面准备远征。"
	if game_state.is_battle_active():
		return "战斗进行中不能采集。"
	var expedition_state: Dictionary = game_state.get_expedition_state()
	if int(expedition_state["carried_food"]) < 1:
		return "远征粮食不足，不能采集。"
	if game_state.get_expedition_gather_label().is_empty():
		return "当前节点没有可采集资源。"
	if game_state.has_collected_current_expedition_node():
		return "本次远征已经采集过该节点。"
	if not game_state.can_gather_current_expedition_node():
		return "当前不能采集。"
	return ""


func get_return_disabled_reason() -> String:
	if input_locked:
		return "动画和结算期间不能返回。"
	if not game_state.is_expedition_active():
		return "请先在村庄页面准备远征。"
	if game_state.is_battle_active():
		return "战斗进行中不能返回村庄。"
	return ""


func format_party_status() -> String:
	var lines := PackedStringArray()
	for unit: Dictionary in game_state.get_battle_party_states():
		var status := "正常"
		if int(unit.get("current_hp", 0)) <= 0:
			status = "倒下"
		elif bool(unit.get("is_defending", false)):
			status = "防御"
		lines.append("%s  生命 %d/%d  %s" % [
			String(unit.get("display_name", unit.get("name", ""))),
			int(unit.get("current_hp", 0)),
			int(unit.get("max_hp", 0)),
			status,
		])
	return "\n".join(lines)


func format_project_status() -> String:
	var project_state: Dictionary = game_state.get_project_state()
	var active_project_id: StringName = StringName(project_state.get("active_project_id", &""))
	if active_project_id == &"":
		return game_state.get_active_project_summary()
	var config: Dictionary = game_state.get_project_config(active_project_id)
	return "%s\n进度：%d/%d" % [
		String(config.get("display_name", "")),
		int(project_state.get("active_project_progress", 0)),
		int(config.get("required_days", 0)),
	]


func format_village_stock() -> String:
	return "村庄粮食：%d\n村庄药品：%d" % [
		game_state.get_resource_amount("food"),
		game_state.get_resource_amount("medicine"),
	]


func get_resource_display_name(resource_id: String) -> String:
	if resource_id == "ore":
		return "临时矿石"
	if resource_id == "herb":
		return "临时草药"
	return resource_id


func add_status_section(parent: Control, title_text: String) -> Label:
	var panel := create_panel("%sPanel" % title_text, 0.76)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)

	var margin := create_margin(12)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	margin.add_child(content)

	content.add_child(create_label(title_text, 20, Color(1.0, 0.86, 0.48), HORIZONTAL_ALIGNMENT_LEFT))
	var body := create_label("", 18, Color(0.94, 0.94, 0.86), HORIZONTAL_ALIGNMENT_LEFT)
	content.add_child(body)
	return body


func create_action_button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(260, 60)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply_button_style(button, primary)
	return button


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


func get_texture_with_fallback(primary_path: String, fallback_path: String) -> Texture2D:
	if not primary_path.is_empty() and ResourceLoader.exists(primary_path):
		return load(primary_path)
	if not fallback_path.is_empty() and ResourceLoader.exists(fallback_path):
		return load(fallback_path)
	return null


func make_panel_style(alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.06, alpha)
	style.border_color = Color(0.78, 0.65, 0.36, 0.88)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	style.shadow_size = 10
	return style


func make_button_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
	return style


func apply_button_style(button: Button, primary: bool) -> void:
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color(0.98, 0.95, 0.84))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.88))
	button.add_theme_color_override("font_pressed_color", Color(0.10, 0.08, 0.04))
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.55, 0.50))
	if primary:
		button.add_theme_stylebox_override("normal", make_button_style(Color(0.36, 0.22, 0.08, 0.92), Color(0.96, 0.76, 0.32, 1.0)))
		button.add_theme_stylebox_override("hover", make_button_style(Color(0.54, 0.34, 0.10, 0.96), Color(1.0, 0.88, 0.45, 1.0)))
		button.add_theme_stylebox_override("pressed", make_button_style(Color(0.92, 0.72, 0.28, 1.0), Color(1.0, 0.96, 0.78, 1.0)))
	else:
		button.add_theme_stylebox_override("normal", make_button_style(Color(0.11, 0.15, 0.12, 0.86), Color(0.65, 0.58, 0.38, 0.95)))
		button.add_theme_stylebox_override("hover", make_button_style(Color(0.18, 0.25, 0.18, 0.92), Color(0.92, 0.76, 0.38, 1.0)))
		button.add_theme_stylebox_override("pressed", make_button_style(Color(0.74, 0.60, 0.30, 1.0), Color(1.0, 0.94, 0.72, 1.0)))
	button.add_theme_stylebox_override("disabled", make_button_style(Color(0.08, 0.08, 0.08, 0.72), Color(0.28, 0.28, 0.24, 0.8)))


func apply_node_style(button: Button, state: String) -> void:
	button.add_theme_color_override("font_color", Color(0.98, 0.96, 0.84))
	if state == "locked" or state == "boss_danger":
		button.add_theme_color_override("font_disabled_color", Color(0.62, 0.62, 0.56))
	else:
		button.add_theme_color_override("font_disabled_color", Color(0.96, 0.94, 0.82))
	match state:
		"current":
			set_node_button_styles(button, Color(0.18, 0.38, 0.24, 0.94), Color(0.74, 1.0, 0.58, 1.0))
		"reachable":
			set_node_button_styles(button, Color(0.46, 0.28, 0.07, 0.95), Color(1.0, 0.83, 0.28, 1.0))
		"boss_reachable":
			set_node_button_styles(button, Color(0.50, 0.14, 0.10, 0.95), Color(1.0, 0.48, 0.28, 1.0))
		"cleared":
			set_node_button_styles(button, Color(0.12, 0.24, 0.20, 0.86), Color(0.52, 0.86, 0.72, 0.95))
		"collected":
			set_node_button_styles(button, Color(0.12, 0.22, 0.28, 0.86), Color(0.62, 0.86, 1.0, 0.95))
		"visited":
			set_node_button_styles(button, Color(0.13, 0.14, 0.12, 0.78), Color(0.58, 0.58, 0.46, 0.9))
		"boss_danger":
			set_node_button_styles(button, Color(0.17, 0.08, 0.08, 0.64), Color(0.76, 0.30, 0.22, 0.75))
		_:
			set_node_button_styles(button, Color(0.07, 0.08, 0.07, 0.58), Color(0.30, 0.30, 0.26, 0.72))


func set_node_button_styles(button: Button, bg_color: Color, border_color: Color) -> void:
	button.add_theme_stylebox_override("normal", make_button_style(bg_color, border_color))
	button.add_theme_stylebox_override("hover", make_button_style(bg_color.lightened(0.12), border_color.lightened(0.10)))
	button.add_theme_stylebox_override("pressed", make_button_style(border_color, Color(1.0, 0.96, 0.72, 1.0)))
	button.add_theme_stylebox_override("disabled", make_button_style(bg_color, border_color))

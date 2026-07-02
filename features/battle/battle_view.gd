extends MarginContainer

const ACTION_BASIC_ATTACK := &"basic_attack"
const ACTION_SKILL := &"skill"
const ACTION_DEFEND := &"defend"
const ACTION_MEDICINE := &"medicine"
const BATTLE_BACKGROUND_PATH := "res://assets/art/battle/battle.png"

const BattleUnitViewScript := preload("res://scripts/battle/battle_unit_view.gd")
const BattleVisualRegistryScript := preload("res://scripts/data/battle_visual_registry.gd")

var game_state
var visual_registry: RefCounted
var input_locked: bool = false
var selected_action: StringName = &""
var current_targets: Array = []
var unit_views: Dictionary = {}

var root: Control
var battlefield: Control
var turn_label: Label
var target_hint_label: Label
var log_label: Label
var result_overlay: PanelContainer
var result_label: Label
var attack_button: Button
var skill_button: Button
var defend_button: Button
var medicine_button: Button


func _ready() -> void:
	game_state = get_node("/root/GameState")
	visual_registry = BattleVisualRegistryScript.new()
	build_visual_layout()
	game_state.battle_state_changed.connect(refresh)
	attack_button.pressed.connect(select_basic_attack)
	skill_button.pressed.connect(select_skill)
	defend_button.pressed.connect(use_defend)
	medicine_button.pressed.connect(select_medicine)
	battlefield.resized.connect(refresh)
	refresh()


func _exit_tree() -> void:
	if game_state != null and game_state.battle_state_changed.is_connected(refresh):
		game_state.battle_state_changed.disconnect(refresh)


func build_visual_layout() -> void:
	add_theme_constant_override("margin_left", 0)
	add_theme_constant_override("margin_top", 0)
	add_theme_constant_override("margin_right", 0)
	add_theme_constant_override("margin_bottom", 0)

	root = Control.new()
	root.name = "BattleRoot"
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root)

	var background := TextureRect.new()
	background.name = "Background"
	background.texture = load(BATTLE_BACKGROUND_PATH) if ResourceLoader.exists(BATTLE_BACKGROUND_PATH) else null
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)

	var shade := ColorRect.new()
	shade.name = "ReadabilityShade"
	shade.color = Color(0.0, 0.0, 0.0, 0.14)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)

	battlefield = Control.new()
	battlefield.name = "Battlefield"
	battlefield.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(battlefield)

	build_top_ui()
	build_bottom_ui()
	build_log_panel()
	build_result_overlay()


func build_top_ui() -> void:
	var top_panel := create_panel("TopUI", 0.72)
	set_anchor_rect(top_panel, Rect2(0.02, 0.02, 0.58, 0.10))
	root.add_child(top_panel)

	var margin := create_margin(14)
	top_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)

	turn_label = create_label("", 24, Color(1.0, 0.92, 0.62), HORIZONTAL_ALIGNMENT_LEFT)
	box.add_child(turn_label)
	target_hint_label = create_label("", 18, Color(0.84, 0.92, 1.0), HORIZONTAL_ALIGNMENT_LEFT)
	box.add_child(target_hint_label)


func build_bottom_ui() -> void:
	var bottom_panel := create_panel("BattleActionPanel", 0.86)
	set_anchor_rect(bottom_panel, Rect2(0.18, 0.84, 0.64, 0.13))
	root.add_child(bottom_panel)

	var margin := create_margin(14)
	bottom_panel.add_child(margin)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	margin.add_child(actions)

	attack_button = create_action_button("普通攻击", true)
	skill_button = create_action_button("使用技能", false)
	defend_button = create_action_button("防御", false)
	medicine_button = create_action_button("使用药品", false)
	actions.add_child(attack_button)
	actions.add_child(skill_button)
	actions.add_child(defend_button)
	actions.add_child(medicine_button)


func build_log_panel() -> void:
	var panel := create_panel("BattleLogPanel", 0.78)
	set_anchor_rect(panel, Rect2(0.69, 0.03, 0.29, 0.25))
	root.add_child(panel)

	var margin := create_margin(14)
	panel.add_child(margin)
	log_label = create_label("", 17, Color(0.94, 0.94, 0.86), HORIZONTAL_ALIGNMENT_LEFT)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	margin.add_child(log_label)


func build_result_overlay() -> void:
	result_overlay = create_panel("ResultOverlay", 0.82)
	result_overlay.visible = false
	result_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchor_rect(result_overlay, Rect2(0.32, 0.34, 0.36, 0.22))
	root.add_child(result_overlay)

	var margin := create_margin(22)
	result_overlay.add_child(margin)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(box)
	result_label = create_label("", 32, Color(1.0, 0.90, 0.54), HORIZONTAL_ALIGNMENT_CENTER)
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(result_label)


func refresh() -> void:
	if root == null:
		return
	var battle_state: Dictionary = game_state.get_battle_state()
	var has_battle_visuals: bool = not battle_state.is_empty() and (bool(battle_state.get("is_active", false)) or game_state.has_pending_battle_result() or not battle_state.get("party_states", []).is_empty())
	if not has_battle_visuals:
		clear_unit_views()
		turn_label.text = "未在战斗"
		target_hint_label.text = ""
		log_label.text = format_log(battle_state.get("battle_log", []))
		set_action_buttons_enabled(false)
		result_overlay.visible = false
		return

	update_unit_views(battle_state)
	refresh_turn_ui(battle_state)
	log_label.text = format_log(battle_state.get("battle_log", []))
	refresh_action_buttons(battle_state)
	refresh_target_highlights()


func update_unit_views(battle_state: Dictionary) -> void:
	var seen_ids: Array = []
	var party_states: Array = battle_state.get("party_states", [])
	for index in range(party_states.size()):
		var unit: Dictionary = party_states[index]
		seen_ids.append(unit["unit_id"])
		update_unit_view(unit, index)

	var enemy_states: Array = battle_state.get("enemy_states", [])
	for index in range(enemy_states.size()):
		var unit: Dictionary = enemy_states[index]
		seen_ids.append(unit["unit_id"])
		update_unit_view(unit, index)

	for raw_id in unit_views.keys():
		if not seen_ids.has(raw_id):
			var old_view = unit_views[raw_id]
			old_view.queue_free()
			unit_views.erase(raw_id)


func update_unit_view(unit: Dictionary, side_index: int) -> void:
	var unit_id: StringName = unit["unit_id"]
	var view
	if unit_views.has(unit_id):
		view = unit_views[unit_id]
		view.update_state(unit, not input_locked)
	else:
		view = BattleUnitViewScript.new()
		battlefield.add_child(view)
		unit_views[unit_id] = view
		view.unit_selected.connect(select_unit_target)
		var visual: Dictionary = visual_registry.get_visual(unit)
		view.setup(unit, visual_registry.get_frames(unit), visual)

	var base_position: Vector2 = visual_registry.get_base_position(unit, side_index)
	var actual_position: Vector2 = visual_registry.scale_position(base_position, battlefield.size)
	view.position = actual_position - view.size * 0.5


func refresh_turn_ui(battle_state: Dictionary) -> void:
	if game_state.has_pending_battle_result():
		turn_label.text = "战斗结果结算中"
		target_hint_label.text = "等待动画结束..."
		return
	if not bool(battle_state.get("is_active", false)):
		turn_label.text = "战斗结束"
		target_hint_label.text = ""
		return
	var active_unit: Dictionary = game_state.get_active_battle_unit()
	turn_label.text = "第%d回合  当前行动：%s" % [
		int(battle_state["round_number"]),
		String(active_unit.get("display_name", "")),
	]
	if selected_action == &"":
		target_hint_label.text = "选择行动。"


func refresh_action_buttons(_battle_state: Dictionary) -> void:
	if input_locked or game_state.has_pending_battle_result() or not game_state.is_battle_active():
		set_action_buttons_enabled(false)
		return

	var active_unit: Dictionary = game_state.get_active_battle_unit()
	var can_act := not active_unit.is_empty() and bool(active_unit.get("is_player_unit", false))
	set_action_buttons_enabled(can_act)
	if can_act:
		var effective_cooldown := int(active_unit.get("effective_skill_cooldown_duration", active_unit.get("skill_cooldown_duration", 0)))
		skill_button.text = "技能：%s（冷却%d）" % [
			String(active_unit.get("skill_name", "")),
			effective_cooldown,
		]
		skill_button.disabled = int(active_unit.get("skill_cooldown", 0)) > 0
		skill_button.tooltip_text = "技能冷却中：%d回合。" % int(active_unit.get("skill_cooldown", 0)) if skill_button.disabled else ""
		medicine_button.disabled = int(game_state.get_expedition_state().get("carried_medicine", 0)) <= 0
		medicine_button.tooltip_text = "远征药品不足。" if medicine_button.disabled else ""
	else:
		skill_button.text = "使用技能"


func set_action_buttons_enabled(enabled: bool) -> void:
	attack_button.disabled = not enabled
	skill_button.disabled = not enabled
	defend_button.disabled = not enabled
	medicine_button.disabled = not enabled


func select_basic_attack() -> void:
	if input_locked:
		return
	selected_action = ACTION_BASIC_ATTACK
	current_targets = get_alive_enemy_targets()
	target_hint_label.text = "点击右侧可攻击目标。"
	refresh_target_highlights()


func select_skill() -> void:
	if input_locked:
		return
	var active_unit: Dictionary = game_state.get_active_battle_unit()
	if active_unit.is_empty():
		return
	var skill_type := String(active_unit["skill_type"])
	if skill_type == "aoe_damage":
		selected_action = &""
		current_targets = []
		start_action(ACTION_SKILL)
		return
	selected_action = ACTION_SKILL
	if skill_type == "heal":
		current_targets = get_healable_party_targets()
		target_hint_label.text = "点击左侧可治疗目标。"
	else:
		current_targets = get_alive_enemy_targets()
		target_hint_label.text = "点击右侧技能目标。"
	refresh_target_highlights()


func use_defend() -> void:
	if input_locked:
		return
	selected_action = &""
	current_targets = []
	start_action(ACTION_DEFEND)


func select_medicine() -> void:
	if input_locked:
		return
	selected_action = ACTION_MEDICINE
	current_targets = get_healable_party_targets()
	target_hint_label.text = "点击左侧药品目标。"
	refresh_target_highlights()


func select_unit_target(unit_id: StringName) -> void:
	if input_locked or selected_action == &"":
		return
	for target: Dictionary in current_targets:
		if target["unit_id"] == unit_id:
			var action := selected_action
			selected_action = &""
			current_targets = []
			start_action(action, unit_id)
			return


func start_action(action_id: StringName, target_id: StringName = &"") -> void:
	input_locked = true
	result_overlay.visible = false
	refresh_target_highlights()
	refresh_action_buttons(game_state.get_battle_state())
	var success: bool = game_state.execute_battle_action(action_id, target_id)
	if not success:
		input_locked = false
		refresh()
		return

	await play_presentation_events(game_state.get_last_battle_presentation_events())
	refresh()
	if game_state.has_pending_battle_result():
		show_pending_result()
		await get_tree().create_timer(0.9).timeout
		game_state.complete_pending_battle_result()
	input_locked = false
	result_overlay.visible = false
	selected_action = &""
	current_targets = []
	refresh()


func play_presentation_events(events: Array) -> void:
	for event: Dictionary in events:
		await play_presentation_event(event)


func play_presentation_event(event: Dictionary) -> void:
	var source_id: StringName = event.get("source_id", &"")
	var source_view = unit_views.get(source_id, null)
	var action_type: StringName = event.get("action_type", &"")

	if action_type == &"defend":
		if source_view != null:
			source_view.show_float_text("盾", Color(0.62, 0.86, 1.0))
		play_target_feedback(event)
		await get_tree().create_timer(0.36).timeout
		return

	if action_type == &"medicine":
		play_target_feedback(event)
		await get_tree().create_timer(0.45).timeout
		return

	if source_view != null:
		source_view.sprite.play(&"attack")
		await get_tree().create_timer(get_impact_time(source_id)).timeout

	play_target_feedback(event)
	await get_tree().create_timer(0.35).timeout
	if source_view != null and int(get_current_hp(source_id)) > 0:
		source_view.play_idle()


func play_target_feedback(event: Dictionary) -> void:
	var target_ids: Array = event.get("target_ids", [])
	var damage_values: Array = event.get("damage_values", [])
	var healing_values: Array = event.get("healing_values", [])
	var defeated_ids: Array = event.get("defeated_ids", [])

	for index in range(target_ids.size()):
		var target_id: StringName = target_ids[index]
		var target_view = unit_views.get(target_id, null)
		if target_view == null:
			continue
		if index < damage_values.size():
			var damage := int(damage_values[index])
			target_view.show_float_text("-%d" % damage, Color(1.0, 0.34, 0.26))
			target_view.play_hit_or_death(defeated_ids.has(target_id))
		elif index < healing_values.size():
			var healing := int(healing_values[index])
			target_view.show_float_text("+%d" % healing, Color(0.36, 1.0, 0.50))


func show_pending_result() -> void:
	var result: Dictionary = game_state.pending_battle_result
	result_overlay.visible = true
	if String(result.get("outcome", "")) == "victory":
		result_label.text = "战斗胜利"
	else:
		result_label.text = "远征失败"


func refresh_target_highlights() -> void:
	var target_ids: Array = []
	for target: Dictionary in current_targets:
		target_ids.append(target["unit_id"])
	for raw_id in unit_views.keys():
		var view = unit_views[raw_id]
		view.set_targetable(not input_locked and target_ids.has(raw_id))


func clear_unit_views() -> void:
	for raw_id in unit_views.keys():
		var view = unit_views[raw_id]
		view.queue_free()
	unit_views.clear()


func get_alive_enemy_targets() -> Array:
	var targets: Array = []
	for enemy: Dictionary in game_state.get_battle_enemy_states():
		if int(enemy["current_hp"]) > 0:
			targets.append(enemy)
	return targets


func get_healable_party_targets() -> Array:
	var targets: Array = []
	for unit: Dictionary in game_state.get_battle_party_states():
		if int(unit["current_hp"]) > 0 and int(unit["current_hp"]) < int(unit["max_hp"]):
			targets.append(unit)
	return targets


func get_impact_time(source_id: StringName) -> float:
	var unit := get_unit_by_id(source_id)
	var visual: Dictionary = visual_registry.get_visual(unit)
	return float(visual.get("impact_frame", 3)) / 10.0


func get_current_hp(unit_id: StringName) -> int:
	var unit := get_unit_by_id(unit_id)
	return int(unit.get("current_hp", 0))


func get_unit_by_id(unit_id: StringName) -> Dictionary:
	for unit: Dictionary in game_state.get_battle_party_states():
		if unit["unit_id"] == unit_id:
			return unit
	for unit: Dictionary in game_state.get_battle_enemy_states():
		if unit["unit_id"] == unit_id:
			return unit
	return {}


func format_log(log_entries: Array) -> String:
	if log_entries.is_empty():
		return "尚未进入战斗。"
	var lines := PackedStringArray()
	for entry in log_entries:
		lines.append(String(entry))
	return "\n".join(lines)


func create_action_button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(210, 54)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color(0.98, 0.95, 0.84))
	button.add_theme_color_override("font_disabled_color", Color(0.52, 0.52, 0.48))
	if primary:
		button.add_theme_stylebox_override("normal", make_button_style(Color(0.38, 0.22, 0.08, 0.94), Color(0.96, 0.76, 0.32, 1.0)))
		button.add_theme_stylebox_override("hover", make_button_style(Color(0.54, 0.34, 0.10, 0.96), Color(1.0, 0.88, 0.45, 1.0)))
	else:
		button.add_theme_stylebox_override("normal", make_button_style(Color(0.10, 0.13, 0.12, 0.92), Color(0.68, 0.58, 0.36, 0.95)))
		button.add_theme_stylebox_override("hover", make_button_style(Color(0.18, 0.24, 0.20, 0.95), Color(0.92, 0.76, 0.38, 1.0)))
	button.add_theme_stylebox_override("disabled", make_button_style(Color(0.07, 0.07, 0.07, 0.76), Color(0.25, 0.25, 0.22, 0.8)))
	return button


func create_panel(node_name: String, alpha: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.add_theme_stylebox_override("panel", make_panel_style(Color(0.05, 0.07, 0.06, alpha), Color(0.80, 0.66, 0.36, 0.88), 2))
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


func set_anchor_rect(control: Control, rect: Rect2) -> void:
	control.anchor_left = rect.position.x
	control.anchor_top = rect.position.y
	control.anchor_right = rect.position.x + rect.size.x
	control.anchor_bottom = rect.position.y + rect.size.y
	control.offset_left = 0
	control.offset_top = 0
	control.offset_right = 0
	control.offset_bottom = 0


func make_panel_style(bg_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0, 0, 0, 0.42)
	style.shadow_size = 8
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

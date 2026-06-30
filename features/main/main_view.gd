extends Control

@onready var village_button: Button = $Root/Navigation/VillageButton
@onready var expedition_button: Button = $Root/Navigation/ExpeditionButton
@onready var village_view: Control = $Root/Content/VillageView
@onready var expedition_view: Control = $Root/Content/ExpeditionView
@onready var battle_view: Control = $Root/Content/BattleView

var game_state
var mvp_panel: PanelContainer
var mvp_summary_label: Label
var continue_test_button: Button
var new_game_button: Button


func _ready() -> void:
	game_state = get_node("/root/GameState")
	setup_mvp_panel()
	apply_visual_style()
	village_button.pressed.connect(show_village)
	expedition_button.pressed.connect(show_expedition)
	game_state.expedition_started.connect(show_expedition)
	game_state.expedition_ended.connect(on_expedition_ended)
	game_state.battle_started.connect(on_battle_started)
	game_state.battle_finished.connect(on_battle_finished)
	game_state.mvp_completed.connect(show_mvp_completed)
	show_village()


func apply_visual_style() -> void:
	for button: Button in [village_button, expedition_button]:
		button.custom_minimum_size = Vector2(180, 48)
		button.add_theme_font_size_override("font_size", 22)


func _exit_tree() -> void:
	if game_state != null and game_state.expedition_started.is_connected(show_expedition):
		game_state.expedition_started.disconnect(show_expedition)
	if game_state != null and game_state.expedition_ended.is_connected(on_expedition_ended):
		game_state.expedition_ended.disconnect(on_expedition_ended)
	if game_state != null and game_state.battle_started.is_connected(on_battle_started):
		game_state.battle_started.disconnect(on_battle_started)
	if game_state != null and game_state.battle_finished.is_connected(on_battle_finished):
		game_state.battle_finished.disconnect(on_battle_finished)
	if game_state != null and game_state.mvp_completed.is_connected(show_mvp_completed):
		game_state.mvp_completed.disconnect(show_mvp_completed)


func setup_mvp_panel() -> void:
	mvp_panel = PanelContainer.new()
	mvp_panel.name = "MvpCompletionPanel"
	mvp_panel.visible = false
	mvp_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	mvp_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(mvp_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_bottom", 48)
	mvp_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 16)
	margin.add_child(content)

	var title := Label.new()
	title.text = "MVP目标完成"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	mvp_summary_label = Label.new()
	mvp_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mvp_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(mvp_summary_label)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	content.add_child(actions)

	continue_test_button = Button.new()
	continue_test_button.text = "继续测试"
	continue_test_button.pressed.connect(hide_mvp_panel)
	actions.add_child(continue_test_button)

	new_game_button = Button.new()
	new_game_button.text = "新游戏"
	new_game_button.pressed.connect(start_new_game_from_mvp)
	actions.add_child(new_game_button)


func show_village() -> void:
	if game_state != null and game_state.is_battle_active():
		show_battle()
		return
	village_view.visible = true
	expedition_view.visible = false
	battle_view.visible = false
	village_button.disabled = true
	expedition_button.disabled = false


func show_expedition() -> void:
	if game_state != null and game_state.is_battle_active():
		show_battle()
		return
	village_view.visible = false
	expedition_view.visible = true
	battle_view.visible = false
	village_button.disabled = false
	expedition_button.disabled = true


func show_battle() -> void:
	village_view.visible = false
	expedition_view.visible = false
	battle_view.visible = true
	village_button.disabled = true
	expedition_button.disabled = true


func show_mvp_completed(summary: Dictionary) -> void:
	mvp_summary_label.text = format_mvp_summary(summary)
	mvp_panel.visible = true


func hide_mvp_panel() -> void:
	mvp_panel.visible = false


func start_new_game_from_mvp() -> void:
	mvp_panel.visible = false
	game_state.start_new_game()
	show_village()


func format_mvp_summary(summary: Dictionary) -> String:
	var statistics: Dictionary = summary.get("statistics", {})
	var growth: Dictionary = summary.get("growth", {})
	var lines := PackedStringArray()
	lines.append("遗迹守卫已被击败，核心材料已带回村庄。")
	lines.append("")
	lines.append("完成天数：第%d天" % int(summary.get("current_day", 0)))
	lines.append("核心材料：%d" % int(summary.get("core_material", 0)))
	lines.append("远征次数：%d" % int(statistics.get("total_expeditions_started", 0)))
	lines.append("远征失败：%d" % int(statistics.get("total_failed_expeditions", 0)))
	lines.append("战斗胜利：%d" % int(statistics.get("total_battles_won", 0)))
	lines.append("完成项目：%d" % int(statistics.get("total_projects_completed", 0)))
	lines.append("农田Lv.%d | 医院Lv.%d | 攻击+%d | 生命+%d" % [
		int(growth.get("farm_level", 1)),
		int(growth.get("clinic_level", 1)),
		int(growth.get("party_attack_bonus", 0)),
		int(growth.get("party_max_hp_bonus", 0)),
	])
	return "\n".join(lines)


func on_expedition_ended(_report: Dictionary) -> void:
	show_village()


func on_battle_started(_encounter_id: StringName) -> void:
	show_battle()


func on_battle_finished(result: Dictionary) -> void:
	if String(result["outcome"]) == "victory":
		show_expedition()
	else:
		show_village()

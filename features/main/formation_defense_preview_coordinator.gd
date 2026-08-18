class_name FormationDefensePreviewCoordinator
extends Node

signal preview_started
signal preview_returned

const BattleRouterScript := preload(
	"res://systems/formation_defense_battle_router.gd"
)
const V2_PREVIEW_HOST_SCENE_PATH := (
	"res://features/battle/formation_defense_preview_host.tscn"
)

var game_state
var overlay_parent: Control
var battle_router
var battle_route_option: OptionButton
var battle_route_start_button: Button
var battle_route_status_label: Label
var v2_preview_host
var v2_preview_summary_panel: PanelContainer
var v2_preview_summary_label: Label
var last_v2_preview_summary_text := ""
var _last_preview_request: Dictionary = {}


func setup(
	formal_game_state: Object,
	navigation: HBoxContainer,
	main_overlay_parent: Control
) -> void:
	game_state = formal_game_state
	overlay_parent = main_overlay_parent
	battle_router = BattleRouterScript.new()
	_build_route_controls(navigation)
	_build_summary_panel()


func _exit_tree() -> void:
	_teardown_v2_preview_host()


func on_battle_route_selected(option_index: int) -> void:
	var requested_mode := StringName(
		battle_route_option.get_item_metadata(option_index)
	)
	battle_router.set_mode(requested_mode)
	if battle_router.current_mode == BattleRouterScript.MODE_V1:
		battle_route_status_label.text = "V1为默认正式路径；遭遇、奖励与进度保持原流程"
	else:
		battle_route_status_label.text = "V2预览使用原型角色，不读取队伍且不执行结算"


func on_battle_route_start_pressed() -> void:
	if game_state == null:
		battle_route_status_label.text = "GameState不可用，无法启动战斗"
		return
	if game_state.is_battle_active():
		battle_route_status_label.text = "V1正式战斗进行中，不能并行启动预览"
		return
	var route_result: Dictionary = battle_router.route_selected_battle(
		game_state,
		build_battle_route_source_context()
	)
	if not bool(route_result.get("ok", false)):
		battle_route_status_label.text = "; ".join(
			route_result.get("errors", ["战斗入口启动失败"])
		)
		return
	if StringName(route_result.get("route", &"")) == BattleRouterScript.MODE_V1:
		battle_route_status_label.text = "已沿原GameState/BattleSystem入口启动V1"
		return
	_start_v2_preview_scene(route_result.get("request", {}))


func build_battle_route_source_context() -> Dictionary:
	var encounter_id := StringName(game_state.get_current_node_encounter_id())
	var expedition_state: Dictionary = game_state.get_expedition_state()
	var has_formal_context := encounter_id != &""
	return {
		"encounter_id": encounter_id,
		"encounter_node_id": String(
			expedition_state.get("current_node_id", "")
		) if has_formal_context else "",
		"source_mode": (
			&"FORMAL_EXPEDITION_CONTEXT"
			if has_formal_context
			else &"MAIN_DEVELOPMENT_PREVIEW"
		),
	}


func format_v2_preview_summary(
	result: Dictionary,
	request: Dictionary
) -> String:
	var context: Dictionary = request.get("encounter_context", {})
	var encounter_node_id := String(context.get("encounter_node_id", ""))
	var has_formal_source := String(context.get("source_mode", "")) \
		== "FORMAL_EXPEDITION_CONTEXT"
	var source_text := "无正式遭遇上下文"
	if has_formal_source:
		source_text = "%s（节点 %s）" % [
			String(request.get("battle_id", "")),
			encounter_node_id if not encounter_node_id.is_empty() else "未知",
		]
	var battle_config_ref: Dictionary = request.get("battle_config_ref", {})
	var durability: Dictionary = result.get("village_durability", {})
	var statistics: Dictionary = result.get("battle_statistics", {})
	return "\n".join(PackedStringArray([
		"battle_session_id：%s" % String(result.get("battle_session_id", "")),
		"settlement_id：%s" % String(result.get("settlement_id", "")),
		"正式来源：%s" % source_text,
		"V2 battle ID：%s" % String(
			battle_config_ref.get("wave_config_id", "")
		),
		"结果：%s｜时长：%.1f秒" % [
			String(result.get("outcome", "")),
			float(result.get("duration_seconds", 0.0)),
		],
		"村庄耐久：%d/%d" % [
			int(durability.get("remaining", 0)),
			int(durability.get("maximum", 0)),
		],
		"生成 %d｜击败 %d｜漏怪 %d" % [
			int(statistics.get("generated_enemies", 0)),
			int(statistics.get("defeated_enemies", 0)),
			int(statistics.get("leaked_enemies", 0)),
		],
		"",
		"V2-8B接入预览未执行正式结算",
		"原型角色结果未写入CharacterRoster、伤情、奖励、远征或存档。",
	]))


func close_v2_preview_summary() -> void:
	v2_preview_summary_panel.visible = false


func get_debug_snapshot() -> Dictionary:
	return {
		"mode": battle_router.current_mode,
		"host_exists": is_instance_valid(v2_preview_host),
		"summary_visible": v2_preview_summary_panel.visible,
		"summary_text": last_v2_preview_summary_text,
		"route_status": battle_route_status_label.text,
		"router": battle_router.get_snapshot(),
	}


func _start_v2_preview_scene(request: Dictionary) -> void:
	if is_instance_valid(v2_preview_host):
		battle_router.fail_active_preview("V2预览Host重复创建")
		battle_route_status_label.text = battle_router.last_error
		return
	if not ResourceLoader.exists(V2_PREVIEW_HOST_SCENE_PATH):
		battle_router.fail_active_preview(
			"V2预览Host场景加载失败：%s" % V2_PREVIEW_HOST_SCENE_PATH
		)
		battle_route_status_label.text = battle_router.last_error
		return
	var packed_scene = ResourceLoader.load(V2_PREVIEW_HOST_SCENE_PATH)
	if not packed_scene is PackedScene:
		battle_router.fail_active_preview("V2预览Host资源无效")
		battle_route_status_label.text = battle_router.last_error
		return
	var host = packed_scene.instantiate()
	if not host is Control or not host.has_method("start_preview"):
		host.queue_free()
		battle_router.fail_active_preview("V2预览Host接口无效")
		battle_route_status_label.text = battle_router.last_error
		return
	_last_preview_request = request.duplicate(true)
	v2_preview_host = host
	overlay_parent.add_child(v2_preview_host)
	v2_preview_host.preview_finished.connect(on_v2_preview_finished)
	v2_preview_host.preview_error.connect(on_v2_preview_error)
	var start_result: Dictionary = v2_preview_host.call("start_preview", request)
	if not bool(start_result.get("ok", false)):
		var message := "; ".join(
			start_result.get("errors", ["V2预览场景启动失败"])
		)
		battle_router.fail_active_preview(message)
		battle_route_status_label.text = message
		_teardown_v2_preview_host()
		preview_returned.emit()
		return
	battle_route_option.disabled = true
	battle_route_start_button.disabled = true
	battle_route_status_label.text = "V2接入预览运行中：不会执行正式结算"
	preview_started.emit()


func on_v2_preview_finished(result: Dictionary) -> void:
	var acceptance: Dictionary = battle_router.accept_preview_result(result)
	if not bool(acceptance.get("ok", false)):
		battle_route_status_label.text = "; ".join(
			acceptance.get("errors", ["V2预览结果被拒绝"])
		)
		_teardown_v2_preview_host()
		_enable_route_controls()
		preview_returned.emit()
		return
	var normalized_result: Dictionary = acceptance["value"]
	last_v2_preview_summary_text = format_v2_preview_summary(
		normalized_result,
		_last_preview_request
	)
	v2_preview_summary_label.text = last_v2_preview_summary_text
	_teardown_v2_preview_host()
	_enable_route_controls()
	v2_preview_summary_panel.visible = true
	battle_route_status_label.text = "V2预览已返回；正式数据与进度未结算"
	preview_returned.emit()


func on_v2_preview_error(message: String) -> void:
	battle_router.fail_active_preview(message)
	battle_route_status_label.text = message
	_teardown_v2_preview_host()
	_enable_route_controls()
	preview_returned.emit()


func _build_route_controls(navigation: HBoxContainer) -> void:
	var spacer := Control.new()
	spacer.name = "BattleRouteSpacer"
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation.add_child(spacer)

	var route_box := VBoxContainer.new()
	route_box.name = "BattleRouteDebug"
	route_box.custom_minimum_size = Vector2(430.0, 0.0)
	route_box.add_theme_constant_override("separation", 2)
	navigation.add_child(route_box)

	var route_row := HBoxContainer.new()
	route_row.add_theme_constant_override("separation", 6)
	route_box.add_child(route_row)
	var route_title := Label.new()
	route_title.text = "开发战斗入口"
	route_title.add_theme_font_size_override("font_size", 13)
	route_row.add_child(route_title)

	battle_route_option = OptionButton.new()
	battle_route_option.name = "BattleRouteOption"
	battle_route_option.custom_minimum_size = Vector2(190.0, 34.0)
	battle_route_option.add_item("V1正式战斗（默认）")
	battle_route_option.set_item_metadata(0, BattleRouterScript.MODE_V1)
	battle_route_option.add_item("V2接入预览（不结算）")
	battle_route_option.set_item_metadata(
		1,
		BattleRouterScript.MODE_V2_INTEGRATION_PREVIEW
	)
	battle_route_option.select(0)
	battle_route_option.item_selected.connect(on_battle_route_selected)
	route_row.add_child(battle_route_option)

	battle_route_start_button = Button.new()
	battle_route_start_button.name = "BattleRouteStartButton"
	battle_route_start_button.text = "启动所选"
	battle_route_start_button.custom_minimum_size = Vector2(92.0, 34.0)
	battle_route_start_button.pressed.connect(on_battle_route_start_pressed)
	route_row.add_child(battle_route_start_button)

	battle_route_status_label = Label.new()
	battle_route_status_label.name = "BattleRouteStatusLabel"
	battle_route_status_label.text = "V1为唯一正式结算路径；V2仅预览"
	battle_route_status_label.add_theme_font_size_override("font_size", 12)
	battle_route_status_label.add_theme_color_override(
		"font_color",
		Color(0.70, 0.80, 0.92)
	)
	route_box.add_child(battle_route_status_label)


func _build_summary_panel() -> void:
	v2_preview_summary_panel = PanelContainer.new()
	v2_preview_summary_panel.name = "V2PreviewSummaryPanel"
	v2_preview_summary_panel.visible = false
	v2_preview_summary_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	v2_preview_summary_panel.set_anchors_preset(Control.PRESET_CENTER)
	v2_preview_summary_panel.position = Vector2(-300.0, -210.0)
	v2_preview_summary_panel.size = Vector2(600.0, 420.0)
	v2_preview_summary_panel.z_index = 600
	overlay_parent.add_child(v2_preview_summary_panel)

	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 22 if side in ["left", "right"] else 18)
	v2_preview_summary_panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	var title := Label.new()
	title.text = "Combat V2 接入预览结果"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	content.add_child(title)
	v2_preview_summary_label = Label.new()
	v2_preview_summary_label.name = "V2PreviewSummaryLabel"
	v2_preview_summary_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v2_preview_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v2_preview_summary_label.add_theme_font_size_override("font_size", 16)
	content.add_child(v2_preview_summary_label)
	var close_button := Button.new()
	close_button.name = "CloseV2PreviewSummaryButton"
	close_button.text = "关闭摘要"
	close_button.pressed.connect(close_v2_preview_summary)
	content.add_child(close_button)


func _enable_route_controls() -> void:
	battle_route_option.disabled = false
	battle_route_start_button.disabled = false


func _teardown_v2_preview_host() -> void:
	if not is_instance_valid(v2_preview_host):
		v2_preview_host = null
		return
	if v2_preview_host.preview_finished.is_connected(on_v2_preview_finished):
		v2_preview_host.preview_finished.disconnect(on_v2_preview_finished)
	if v2_preview_host.preview_error.is_connected(on_v2_preview_error):
		v2_preview_host.preview_error.disconnect(on_v2_preview_error)
	if v2_preview_host.get_parent() != null:
		v2_preview_host.get_parent().remove_child(v2_preview_host)
	v2_preview_host.queue_free()
	v2_preview_host = null

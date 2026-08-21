class_name FormationDefensePreviewCoordinator
extends Node

signal preview_started
signal preview_returned

const BattleRouterScript := preload(
	"res://systems/formation_defense_battle_router.gd"
)
const FormalPartySource := preload(
	"res://systems/formation_defense_formal_party_source.gd"
)
const ProfessionCompatibility := preload(
	"res://systems/formation_defense_profession_compatibility.gd"
)
const SettlementServiceScript := preload(
	"res://systems/formation_defense_settlement_service.gd"
)
const IntegrationPolicyScript := preload(
	"res://systems/formation_defense_integration_policy.gd"
)
const V2_PREVIEW_HOST_SCENE_PATH := (
	"res://features/battle/formation_defense_preview_host.tscn"
)

var game_state
var overlay_parent: Control
var battle_router
var settlement_service
var integration_policy
var battle_route_option: OptionButton
var battle_route_start_button: Button
var battle_route_status_label: Label
var v2_preview_host
var v2_preview_summary_panel: PanelContainer
var v2_preview_summary_label: Label
var v2_preview_summary_title: Label
var settlement_confirmation_dialog: ConfirmationDialog
var last_v2_preview_summary_text := ""
var last_v2_party_debug_text := ""
var _last_preview_request: Dictionary = {}
var _active_v2_mode: StringName = &""
var _pending_settlement_context: Dictionary = {}
var _debug_route_override_active := false


func setup(
	formal_game_state: Object,
	navigation: HBoxContainer,
	main_overlay_parent: Control,
	injected_policy = null
) -> void:
	game_state = formal_game_state
	overlay_parent = main_overlay_parent
	battle_router = BattleRouterScript.new()
	settlement_service = SettlementServiceScript.new()
	integration_policy = (
		injected_policy
		if injected_policy != null
		else IntegrationPolicyScript.new()
	)
	if integration_policy.debug_tools_visible:
		_build_route_controls(navigation)
	_build_summary_panel()
	if integration_policy.debug_tools_visible:
		_build_settlement_confirmation_dialog()


func _exit_tree() -> void:
	_teardown_v2_preview_host()


func on_battle_route_selected(option_index: int) -> void:
	if not integration_policy.debug_tools_visible or battle_route_option == null:
		return
	_debug_route_override_active = true
	var requested_mode := StringName(
		battle_route_option.get_item_metadata(option_index)
	)
	battle_router.set_mode(requested_mode)
	if battle_router.current_mode == BattleRouterScript.MODE_V1:
		_set_route_status("V1为默认正式路径；遭遇、奖励与进度保持原流程")
	elif battle_router.current_mode == BattleRouterScript.MODE_V2_SETTLEMENT_VALIDATION:
		_set_route_status("V2正式结算验证：仅真实未解决遭遇可用，会改变测试存档")
	else:
		_set_route_status("V2预览读取当前正式队伍与最终属性，但不执行结算")


func on_battle_route_start_pressed() -> void:
	if not integration_policy.debug_tools_visible:
		return
	if game_state == null:
		_set_route_status("GameState不可用，无法启动战斗")
		return
	if game_state.is_battle_active():
		_set_route_status("V1正式战斗进行中，不能并行启动预览")
		return
	var source_context := build_battle_route_source_context()
	if battle_router.current_mode == BattleRouterScript.MODE_V2_SETTLEMENT_VALIDATION:
		_pending_settlement_context = source_context.duplicate(true)
		settlement_confirmation_dialog.dialog_text = (
			"V2正式结算验证会改变当前测试存档的经验、伤情、奖励和远征进度。\n"
			+ "本阶段不会自动保存，但后续手动保存会保留这些变化。\n\n"
			+ "确认使用当前真实遭遇启动吗？"
		)
		settlement_confirmation_dialog.popup_centered()
		return
	_start_selected_route(source_context)


func confirm_settlement_route_start() -> void:
	if not integration_policy.debug_tools_visible:
		return
	var source_context := _pending_settlement_context.duplicate(true)
	_pending_settlement_context = {}
	_start_selected_route(source_context)


func route_formal_encounter(encounter_id: StringName) -> bool:
	var source_context := build_battle_route_source_context()
	if StringName(source_context.get("encounter_id", &"")) != encounter_id:
		_set_route_status("正式遭遇上下文与当前节点不一致")
		return false
	var has_debug_route_override: bool = integration_policy.debug_tools_visible \
		and (
			_debug_route_override_active
			or battle_router.current_mode != BattleRouterScript.MODE_V1
		)
	if has_debug_route_override \
			and battle_router.current_mode \
				== BattleRouterScript.MODE_V2_SETTLEMENT_VALIDATION:
		_pending_settlement_context = source_context.duplicate(true)
		settlement_confirmation_dialog.dialog_text = (
			"已抵达真实战斗节点。V2正式结算验证会改变测试存档中的经验、"
			+ "伤情、奖励和远征进度，且不会自动保存。\n\n确认启动吗？"
		)
		settlement_confirmation_dialog.popup_centered()
		return true
	if has_debug_route_override:
		_start_selected_route(source_context)
		return true
	var resolution: Dictionary = integration_policy.resolve_formal_route(
		encounter_id
	)
	if not bool(resolution.get("ok", false)):
		_report_formal_route_failure("; ".join(
			resolution.get("errors", ["正式战斗路由配置无效"])
		))
		return false
	var resolved_entry: Dictionary = resolution.get("entry", {})
	var configured_node_id := StringName(
		resolved_entry.get("encounter_node_id", &"")
	)
	if configured_node_id != &"" and configured_node_id != StringName(
		source_context.get("encounter_node_id", &"")
	):
		_report_formal_route_failure("正式路由表节点与当前远征节点不一致")
		return false
	var selected_route := StringName(
		resolution.get("route", IntegrationPolicyScript.IMPLEMENTATION_V1)
	)
	if selected_route == IntegrationPolicyScript.IMPLEMENTATION_V2:
		source_context["v2_battle_id"] = StringName(
			resolved_entry.get("battle_id", &"")
		)
		battle_router.set_mode(BattleRouterScript.MODE_V2_FORMAL)
	else:
		battle_router.set_mode(BattleRouterScript.MODE_V1)
	_start_selected_route(source_context)
	return true


func _start_selected_route(source_context: Dictionary) -> void:
	if battle_router.current_mode != BattleRouterScript.MODE_V1:
		var party_creation := FormalPartySource.build_party_snapshots(game_state)
		if not bool(party_creation.get("ok", false)):
			_set_route_status("; ".join(
				party_creation.get("errors", ["正式队伍无法构建"])
			))
			return
		source_context["party_snapshots"] = party_creation["value"].duplicate(true)
		last_v2_party_debug_text = format_party_debug(
			party_creation["value"]
		)
		if integration_policy.debug_tools_visible:
			_set_route_status(last_v2_party_debug_text)
	var route_result: Dictionary = battle_router.route_selected_battle(
		game_state,
		source_context
	)
	if not bool(route_result.get("ok", false)):
		_set_route_status("; ".join(
			route_result.get("errors", ["战斗入口启动失败"])
		))
		return
	if StringName(route_result.get("route", &"")) == BattleRouterScript.MODE_V1:
		_set_route_status("已沿原GameState/BattleSystem入口启动V1")
		return
	var request: Dictionary = route_result.get("request", {}).duplicate(true)
	_active_v2_mode = StringName(route_result.get("route", &""))
	if _is_settlement_mode(_active_v2_mode):
		var opening: Dictionary = settlement_service.open_session(
			game_state,
			request
		)
		if not bool(opening.get("ok", false)):
			var message := "; ".join(opening.get("errors", ["正式结算会话启动失败"]))
			battle_router.fail_active_session(message)
			_set_route_status(message)
			_active_v2_mode = &""
			return
	_start_v2_preview_scene(request)


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
	var lines := PackedStringArray([
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
		"正式角色结果：",
	])
	var members_by_id: Dictionary = {}
	for member: Dictionary in request.get("party", []):
		members_by_id[String(member.get("character_id", ""))] = member
	for party_result: Dictionary in result.get("party_results", []):
		var character_id := String(party_result.get("character_id", ""))
		var member: Dictionary = members_by_id.get(character_id, {})
		var personal: Dictionary = party_result.get("statistics", {})
		lines.append(
			"- %s（%s）｜%s｜剩余HP %d｜伤害%d／承伤%d／治疗%d／大招%d"
			% [
				String(member.get("display_name", character_id)),
				character_id,
				"倒下" if bool(party_result.get("is_down", false)) else "存活",
				int(party_result.get("remaining_hp", 0)),
				int(personal.get("damage_dealt", 0)),
				int(personal.get("damage_taken", 0)),
				int(personal.get("healing_done", 0)),
				int(personal.get("ultimate_casts", 0)),
			]
		)
	lines.append("")
	lines.append("V2-8C正式队伍预览未执行正式结算")
	lines.append("正式角色经验、生命、装备、伤情、奖励、远征与存档均未写入。")
	return "\n".join(lines)


func format_v2_settlement_receipt(
	receipt: Dictionary,
	include_debug_diagnostics := true,
	raw_result: Dictionary = {},
	request: Dictionary = {},
	settlement_plan: Dictionary = {}
) -> String:
	var durability: Dictionary = receipt.get("village_durability", {})
	var lines := PackedStringArray([
		"结果：%s" % (
			"胜利" if String(receipt.get("outcome", "")) == "victory" else "失败"
		),
		"正式参战角色经验：",
	])
	if include_debug_diagnostics:
		lines.insert(0, "settlement_id：%s" % String(
			receipt.get("settlement_id", "")
		))
		lines.insert(2, "V2原始判定：%s｜村庄耐久：%d/%d｜倒下角色：%d" % [
			String(receipt.get("v2_outcome", "")),
			int(durability.get("remaining", 0)),
			int(durability.get("maximum", 0)),
			int(receipt.get("downed_participant_count", 0)),
		])
		lines.insert(1, "battle_session_id：%s" % String(
			receipt.get("battle_session_id", "")
		))
	for experience_result: Dictionary in receipt.get("experience_results", []):
		lines.append("- %s（%s）经验 +%d%s" % [
			String(experience_result.get("display_name", "")),
			String(experience_result.get("character_id", "")),
			int(experience_result.get("experience_gained", 0)),
			"，升级至Lv.%d" % int(experience_result.get("new_level", 1))
				if int(experience_result.get("levels_gained", 0)) > 0
				else "",
		])
	var reward_parts := PackedStringArray()
	for reward_id: String in ["ore", "herb", "core"]:
		var amount := int(receipt.get("reward_%s" % reward_id, 0))
		if amount > 0:
			reward_parts.append("%s +%d" % [
				{"ore": "矿石", "herb": "草药", "core": "Boss核心"}[reward_id],
				amount,
			])
	lines.append("奖励/临时货物：%s" % (
		"无" if reward_parts.is_empty() else "、".join(reward_parts)
	))
	var injuries: Array = receipt.get("character_injury_results", [])
	var injured_names := PackedStringArray()
	for injury: Dictionary in injuries:
		if StringName(injury.get("new_injury_state", &"healthy")) == &"injured":
			injured_names.append(game_state.get_character_display_name(
				StringName(injury.get("character_id", &""))
			))
	lines.append("新增/确认伤情：%s" % (
		"无" if injured_names.is_empty() else "、".join(injured_names)
	))
	lines.append("远征节点：%s｜远征：%s｜返回：%s" % [
		"已完成" if bool(receipt.get("node_completed", false)) else "未完成",
		"继续" if bool(receipt.get("expedition_continues", false)) else "已结束",
		"远征界面" if String(receipt.get("return_view", "")) == "expedition" else "村庄",
	])
	if include_debug_diagnostics:
		lines.append("")
		if not request.is_empty():
			lines.append("V2 battle ID：%s" % String(
				request.get("battle_config_ref", {}).get("wave_config_id", "")
			))
			lines.append("正式属性映射：%s" % last_v2_party_debug_text)
		if not settlement_plan.is_empty():
			lines.append("计划指纹：%s" % JSON.stringify(
				settlement_plan
			).sha256_text())
		if not raw_result.is_empty():
			lines.append("原始统计：%s" % JSON.stringify(
				raw_result.get("battle_statistics", {})
			))
		lines.append(String(receipt.get(
			"message",
			"V2正式结算已应用，未自动保存"
		)))
	return "\n".join(lines)


func format_v2_aborted_summary(
	result: Dictionary,
	include_debug_diagnostics := true
) -> String:
	var lines := PackedStringArray([
		"结果：已中止",
		"未执行正式结算",
		"未发经验、奖励或伤情；当前遭遇保持未解决并可重新进入。",
	])
	if include_debug_diagnostics:
		lines.insert(0, "battle_session_id：%s" % String(
			result.get("battle_session_id", "")
		))
	return "\n".join(lines)


func format_party_debug(party: Array) -> String:
	var lines := PackedStringArray(["正式队伍：%d人（V2-8C不结算预览）" % party.size()])
	for member: Dictionary in party:
		var profession_id := StringName(member.get("profession_id", &""))
		var compatibility := ProfessionCompatibility.get_compatibility(profession_id)
		var stats: Dictionary = member.get("final_stats", {})
		var report: Dictionary = member.get("stat_scale_report", {})
		var formal: Dictionary = report.get("formal_final_stats", {})
		var reference: Dictionary = report.get("formal_reference_stats", {})
		var ratios: Dictionary = report.get("ratios", {})
		var baseline: Dictionary = report.get("v2_baseline_stats", {})
		var runtime: Dictionary = report.get("v2_runtime_stats", {})
		var role_id := StringName(compatibility.get("v2_role_id", &""))
		lines.append(
			(
				"槽%d %s[%s] %s→%s\n"
			+ "  正式 HP%.1f/攻%.1f/速%.2f｜参考 %.1f/%.1f/%.2f｜比例 %.3f/%.3f/%.3f\n"
			+ "  V2基准 HP%.1f/%s%.1f/%.3fs｜运行 HP%d/%s%d/%.3fs｜范围%.0f"
			)
			% [
				int(member.get("party_slot", -1)) + 1,
				String(member.get("display_name", "")),
				String(member.get("character_id", "")),
				String(profession_id),
				String(role_id),
				float(formal.get("max_hp", 0.0)),
				float(formal.get("attack", 0.0)),
				float(formal.get("attack_speed", 0.0)),
				float(reference.get("max_hp", 0.0)),
				float(reference.get("attack", 0.0)),
				float(reference.get("attack_speed", 0.0)),
				float(ratios.get("max_hp", 0.0)),
				float(ratios.get("attack", 0.0)),
				float(ratios.get("attack_speed", 0.0)),
				float(baseline.get("max_health", 0.0)),
				"治疗" if role_id == &"doctor" else "攻击",
				float(baseline.get("attack_or_heal", 0.0)),
				float(baseline.get("action_interval", 0.0)),
				int(runtime.get("max_health", stats.get("max_hp", 0))),
				"治疗" if role_id == &"doctor" else "攻击",
				int(runtime.get("attack_or_heal", stats.get("attack", 0))),
				float(runtime.get("action_interval", 0.0)),
				float(runtime.get("action_range", compatibility.get("action_range", 0.0))),
			]
		)
	lines.append(ProfessionCompatibility.COMPATIBILITY_SOURCE)
	return "\n".join(lines)


func close_v2_preview_summary() -> void:
	v2_preview_summary_panel.visible = false


func get_debug_snapshot() -> Dictionary:
	return {
		"mode": battle_router.current_mode,
		"host_exists": is_instance_valid(v2_preview_host),
		"summary_visible": v2_preview_summary_panel != null \
			and v2_preview_summary_panel.visible,
		"summary_text": last_v2_preview_summary_text,
		"route_status": _get_route_status(),
		"party_debug_text": last_v2_party_debug_text,
		"integration_policy": integration_policy.get_snapshot(),
		"router": battle_router.get_snapshot(),
		"settlement": settlement_service.get_snapshot(),
	}


func _start_v2_preview_scene(request: Dictionary) -> void:
	if is_instance_valid(v2_preview_host):
		_fail_active_v2_start("V2预览Host重复创建")
		_set_route_status(battle_router.last_error)
		return
	_last_preview_request = request.duplicate(true)
	v2_preview_summary_panel.visible = false
	last_v2_preview_summary_text = ""
	v2_preview_summary_label.text = ""
	if not ResourceLoader.exists(V2_PREVIEW_HOST_SCENE_PATH):
		_fail_active_v2_start(
			"V2预览Host场景加载失败：%s" % V2_PREVIEW_HOST_SCENE_PATH
		)
		_set_route_status(battle_router.last_error)
		return
	var packed_scene = ResourceLoader.load(V2_PREVIEW_HOST_SCENE_PATH)
	if not packed_scene is PackedScene:
		_fail_active_v2_start("V2预览Host资源无效")
		_set_route_status(battle_router.last_error)
		return
	var host = packed_scene.instantiate()
	if not host is Control or not host.has_method("start_preview"):
		host.queue_free()
		_fail_active_v2_start("V2预览Host接口无效")
		_set_route_status(battle_router.last_error)
		return
	v2_preview_host = host
	overlay_parent.add_child(v2_preview_host)
	v2_preview_host.preview_finished.connect(on_v2_preview_finished)
	v2_preview_host.preview_error.connect(on_v2_preview_error)
	if v2_preview_host.has_method("set_debug_diagnostics_visible"):
		v2_preview_host.call(
			"set_debug_diagnostics_visible",
			integration_policy.debug_tools_visible
		)
	var start_result: Dictionary = v2_preview_host.call("start_preview", request)
	if not bool(start_result.get("ok", false)):
		var message := "; ".join(
			start_result.get("errors", ["V2预览场景启动失败"])
		)
		_fail_active_v2_start(message)
		_set_route_status(message)
		_teardown_v2_preview_host()
		preview_returned.emit()
		return
	if integration_policy.debug_tools_visible \
			and v2_preview_host.has_method("set_party_scale_debug_text"):
		v2_preview_host.call(
			"set_party_scale_debug_text",
			last_v2_party_debug_text
		)
	if battle_route_option != null:
		battle_route_option.disabled = true
	if battle_route_start_button != null:
		battle_route_start_button.disabled = true
	if _active_v2_mode == BattleRouterScript.MODE_V2_FORMAL:
		_set_route_status("阵型塔防战斗运行中")
	elif _active_v2_mode == BattleRouterScript.MODE_V2_SETTLEMENT_VALIDATION:
		_set_route_status("V2正式结算验证运行中：终态将自动结算一次且不会自动保存")
	else:
		_set_route_status("V2正式队伍预览运行中：不会执行正式结算")
	preview_started.emit()


func _fail_active_v2_start(message: String) -> void:
	var failed_mode := _active_v2_mode
	battle_router.fail_active_session(message)
	if _is_settlement_mode(failed_mode):
		settlement_service.reject_session(
			String(_last_preview_request.get("battle_session_id", "")),
			message
		)
	if failed_mode == BattleRouterScript.MODE_V2_FORMAL:
		_show_v2_failure_summary("战斗暂时无法开始", message)
	_last_preview_request = {}
	_active_v2_mode = &""


func on_v2_preview_finished(result: Dictionary) -> void:
	var is_settlement := _is_settlement_mode(_active_v2_mode)
	var is_formal_route := _active_v2_mode == BattleRouterScript.MODE_V2_FORMAL
	var acceptance: Dictionary = (
		battle_router.accept_settlement_result(result)
		if is_settlement
		else battle_router.accept_preview_result(result)
	)
	if not bool(acceptance.get("ok", false)):
		_set_route_status("; ".join(
			acceptance.get("errors", ["V2预览结果被拒绝"])
		))
		_teardown_v2_preview_host()
		_enable_route_controls()
		preview_returned.emit()
		return
	var normalized_result: Dictionary = acceptance["value"]
	if is_settlement:
		if String(normalized_result.get("outcome", "")) == "ABORTED":
			var closing: Dictionary = settlement_service.close_aborted_session(
				_last_preview_request,
				normalized_result
			)
			if not bool(closing.get("ok", false)):
				_handle_settlement_failure(closing)
				return
			last_v2_preview_summary_text = format_v2_aborted_summary(
				normalized_result,
				integration_policy.debug_tools_visible
			)
			v2_preview_summary_title.text = (
				"战斗已中止" if is_formal_route else "Combat V2 正式结算验证已中止"
			)
			_set_route_status("战斗已中止；正式数据未结算")
		else:
			var preparation: Dictionary = settlement_service.prepare_settlement(
				game_state,
				_last_preview_request,
				normalized_result
			)
			if not bool(preparation.get("ok", false)):
				_handle_settlement_failure(preparation)
				return
			var application: Dictionary = settlement_service.apply_settlement(
				game_state,
				preparation.get("value", {})
			)
			if not bool(application.get("ok", false)):
				_handle_settlement_failure(application)
				return
			last_v2_preview_summary_text = format_v2_settlement_receipt(
				application.get("value", {}),
				integration_policy.debug_tools_visible,
				normalized_result,
				_last_preview_request,
				preparation.get("value", {})
			)
			v2_preview_summary_title.text = (
				"战斗结算" if is_formal_route else "Combat V2 正式结算回执"
			)
			_set_route_status("战斗结算已完成")
	else:
		last_v2_preview_summary_text = format_v2_preview_summary(
			normalized_result,
			_last_preview_request
		)
		v2_preview_summary_title.text = "Combat V2 接入预览结果"
		_set_route_status("V2预览已返回；正式数据与进度未结算")
	v2_preview_summary_label.text = last_v2_preview_summary_text
	_teardown_v2_preview_host()
	_last_preview_request = {}
	_active_v2_mode = &""
	_enable_route_controls()
	v2_preview_summary_panel.visible = true
	preview_returned.emit()


func _handle_settlement_failure(failure: Dictionary) -> void:
	var message := "; ".join(failure.get("errors", ["V2正式结算失败"]))
	settlement_service.reject_session(
		String(_last_preview_request.get("battle_session_id", "")),
		message
	)
	_set_route_status(message)
	_show_v2_failure_summary(
		"战斗结算未完成"
		if _active_v2_mode == BattleRouterScript.MODE_V2_FORMAL
		else "Combat V2 正式结算被拒绝",
		message
	)
	_teardown_v2_preview_host()
	_last_preview_request = {}
	_active_v2_mode = &""
	_enable_route_controls()
	preview_returned.emit()


func on_v2_preview_error(message: String) -> void:
	battle_router.fail_active_session(message)
	if _is_settlement_mode(_active_v2_mode):
		settlement_service.reject_session(
			String(_last_preview_request.get("battle_session_id", "")),
			message
		)
	_set_route_status(message)
	_show_v2_failure_summary(
		"战斗无法继续"
		if _active_v2_mode == BattleRouterScript.MODE_V2_FORMAL
		else "Combat V2 运行错误",
		message
	)
	_teardown_v2_preview_host()
	_last_preview_request = {}
	_active_v2_mode = &""
	_enable_route_controls()
	preview_returned.emit()


func _show_v2_failure_summary(title: String, message: String) -> void:
	var lines := PackedStringArray([
		"结果：未执行正式结算",
		"当前遭遇仍未解决，不能前往下一节点；可重新进入该遭遇。",
	])
	if integration_policy.debug_tools_visible:
		lines.insert(1, message)
	last_v2_preview_summary_text = "\n".join(lines)
	v2_preview_summary_title.text = title
	v2_preview_summary_label.text = last_v2_preview_summary_text
	v2_preview_summary_panel.visible = true


func _report_formal_route_failure(message: String) -> void:
	_set_route_status(message)
	_show_v2_failure_summary("战斗暂时无法开始", message)


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
	battle_route_option.add_item("V2正式结算验证（会改变测试存档）")
	battle_route_option.set_item_metadata(
		2,
		BattleRouterScript.MODE_V2_SETTLEMENT_VALIDATION
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
	battle_route_status_label.text = "V1为默认正式路径；V2结算验证必须手动选择"
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
	v2_preview_summary_title = Label.new()
	v2_preview_summary_title.text = "Combat V2 接入预览结果"
	v2_preview_summary_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v2_preview_summary_title.add_theme_font_size_override("font_size", 24)
	content.add_child(v2_preview_summary_title)
	v2_preview_summary_label = Label.new()
	v2_preview_summary_label.name = "V2PreviewSummaryLabel"
	v2_preview_summary_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v2_preview_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v2_preview_summary_label.add_theme_font_size_override("font_size", 16)
	content.add_child(v2_preview_summary_label)
	var close_button := Button.new()
	close_button.name = "CloseV2PreviewSummaryButton"
	close_button.text = "关闭"
	close_button.pressed.connect(close_v2_preview_summary)
	content.add_child(close_button)


func _build_settlement_confirmation_dialog() -> void:
	settlement_confirmation_dialog = ConfirmationDialog.new()
	settlement_confirmation_dialog.name = "V2SettlementConfirmationDialog"
	settlement_confirmation_dialog.title = "确认V2正式结算验证"
	settlement_confirmation_dialog.ok_button_text = "确认启动"
	settlement_confirmation_dialog.cancel_button_text = "取消"
	settlement_confirmation_dialog.confirmed.connect(
		confirm_settlement_route_start
	)
	settlement_confirmation_dialog.canceled.connect(
		func() -> void:
			_pending_settlement_context = {}
	)
	overlay_parent.add_child(settlement_confirmation_dialog)


func _enable_route_controls() -> void:
	if battle_route_option != null:
		battle_route_option.disabled = false
	if battle_route_start_button != null:
		battle_route_start_button.disabled = false


func _is_settlement_mode(mode: StringName) -> bool:
	return mode in [
		BattleRouterScript.MODE_V2_SETTLEMENT_VALIDATION,
		BattleRouterScript.MODE_V2_FORMAL,
	]


func _set_route_status(message: String) -> void:
	if battle_route_status_label != null:
		battle_route_status_label.text = message


func _get_route_status() -> String:
	return battle_route_status_label.text if battle_route_status_label != null else ""


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

class_name FormationDefensePreviewHost
extends Control

signal preview_finished(result: Dictionary)
signal preview_error(message: String)

const BattleContract := preload(
	"res://scripts/data/formation_defense_battle_contract.gd"
)
const ProfessionCompatibility := preload(
	"res://systems/formation_defense_profession_compatibility.gd"
)
const PrototypeConfig := preload(
	"res://prototype/formation_defense/data/formation_defense_config.gd"
)

const DEFAULT_PROTOTYPE_SCENE_PATH := (
	"res://prototype/formation_defense/scenes/formation_defense_prototype.tscn"
)

var preview_scene_path := DEFAULT_PROTOTYPE_SCENE_PATH
var active_request: Dictionary = {}
var _prototype: Control
var _battle_mount: Control
var _status_label: Label
var _exit_button: Button
var _terminal_emitted := false
var _last_terminal_debug_snapshot: Dictionary = {}
var _external_party_debug_text := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 500
	_build_layout()
	visible = false
	set_process_input(false)


func start_preview(raw_request: Dictionary) -> Dictionary:
	if not active_request.is_empty() or is_instance_valid(_prototype):
		return _failure("V2预览Host已有活动场景")
	var request_creation := BattleContract.create_request(raw_request)
	if not bool(request_creation.get("ok", false)):
		return _failure(
			"V2预览输入契约非法：%s" % "; ".join(
				request_creation.get("errors", [])
			)
		)
	var request: Dictionary = request_creation["value"]
	var wave_config_id := StringName(
		request["battle_config_ref"].get("wave_config_id", &"")
	)
	var battle_config := PrototypeConfig.get_wave_battle_config(wave_config_id)
	if battle_config.is_empty():
		return _failure("V2预览battle ID不存在：%s" % String(wave_config_id))
	if int(request.get("random_seed", -1)) != int(
		battle_config.get("random_seed", -2)
	):
		return _failure("V2预览随机种子与冻结配置不一致")
	var scenario_id := _find_scenario_for_wave_config(wave_config_id)
	if scenario_id == &"":
		return _failure("V2预览battle没有可运行场景：%s" % String(wave_config_id))
	if not ResourceLoader.exists(preview_scene_path):
		return _failure("V2预览场景加载失败：%s" % preview_scene_path)
	var packed_scene = ResourceLoader.load(preview_scene_path)
	if not packed_scene is PackedScene:
		return _failure("V2预览资源不是PackedScene：%s" % preview_scene_path)
	var instance = packed_scene.instantiate()
	if not instance is Control:
		instance.queue_free()
		return _failure("V2预览场景根节点必须是Control")
	active_request = request.duplicate(true)
	_terminal_emitted = false
	_last_terminal_debug_snapshot = {}
	_prototype = instance
	_battle_mount.add_child(_prototype)
	_prototype.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var runtime_party_creation := ProfessionCompatibility.build_runtime_party(
		request.get("party", [])
	)
	if not bool(runtime_party_creation.get("ok", false)):
		_cleanup_runtime()
		return _failure(
			"V2正式队伍运行映射失败：%s" % "; ".join(
				runtime_party_creation.get("errors", [])
			)
		)
	if not _prototype.has_method("configure_integration_party"):
		_cleanup_runtime()
		return _failure("V2预览场景缺少正式队伍动态配置入口")
	var party_configuration: Dictionary = _prototype.call(
		"configure_integration_party",
		runtime_party_creation.get("value", [])
	)
	if not bool(party_configuration.get("ok", false)):
		_cleanup_runtime()
		return _failure(
			"V2正式队伍动态生成失败：%s" % "; ".join(
				party_configuration.get("errors", [])
			)
		)
	if not _prototype.has_method("select_scenario") \
			or not _prototype.call("select_scenario", scenario_id):
		_cleanup_runtime()
		return _failure("V2预览场景拒绝battle配置")
	_configure_integration_preview_ui()
	if not _prototype.call("apply_recommended_deployment"):
		_cleanup_runtime()
		return _failure("V2预览无法按正式队伍槽位部署角色")
	if not _prototype.call("start_battle"):
		_cleanup_runtime()
		return _failure("V2预览战斗启动失败")
	_prototype.battle_finished.connect(_on_prototype_battle_finished)
	_status_label.text = "V2正式队伍预览（不结算）｜%d人｜Session %s" % [
		active_request.get("party", []).size(),
		String(active_request.get("battle_session_id", "")),
	]
	_status_label.tooltip_text = get_party_debug_text()
	visible = true
	set_process_input(true)
	return {
		"ok": true,
		"errors": PackedStringArray(),
		"value": active_request.duplicate(true),
	}


func abort_preview() -> bool:
	if active_request.is_empty() or _terminal_emitted:
		return false
	return _finish_preview(BattleContract.OUTCOME_ABORTED)


func advance_for_test(delta: float) -> void:
	if not is_instance_valid(_prototype):
		return
	_prototype.call("set_automatic_simulation", false)
	_prototype.call("simulate_step", delta)


func force_defeat_for_test() -> bool:
	if not is_instance_valid(_prototype) or _terminal_emitted:
		return false
	_prototype.village_durability = 0
	_prototype.call("finish_defeat")
	return true


func force_victory_for_test() -> bool:
	if not is_instance_valid(_prototype) or _terminal_emitted:
		return false
	_prototype.call("finish_victory")
	return true


func get_active_prototype():
	return _prototype


func get_last_terminal_debug_snapshot() -> Dictionary:
	return _last_terminal_debug_snapshot.duplicate(true)


func set_party_scale_debug_text(debug_text: String) -> void:
	_external_party_debug_text = debug_text
	if is_instance_valid(_status_label):
		_status_label.tooltip_text = get_party_debug_text()


func get_snapshot() -> Dictionary:
	return {
		"active": not active_request.is_empty(),
		"battle_session_id": String(
			active_request.get("battle_session_id", "")
		),
		"prototype_scene_count": 1 if is_instance_valid(_prototype) else 0,
		"terminal_emitted": _terminal_emitted,
		"preview_scene_path": preview_scene_path,
		"party_debug_text": get_party_debug_text(),
	}


func get_party_debug_text() -> String:
	if not _external_party_debug_text.is_empty():
		return _external_party_debug_text
	if active_request.is_empty():
		return ""
	var lines := PackedStringArray([
		"正式队伍：%d人" % active_request.get("party", []).size(),
	])
	for member: Dictionary in active_request.get("party", []):
		var compatibility := ProfessionCompatibility.get_compatibility(
			StringName(member.get("profession_id", &""))
		)
		var stats: Dictionary = member.get("final_stats", {})
		var action_interval := ProfessionCompatibility.v2_attack_rate_to_action_interval(
			float(stats.get("attack_speed", 0.0))
		)
		var role_id := StringName(compatibility.get("v2_role_id", &""))
		lines.append(
			"槽%d %s｜ID=%s｜职业=%s→%s｜HP=%d｜%s=%d｜间隔=%.3fs｜范围=%.0f｜%s"
			% [
				int(member.get("party_slot", -1)) + 1,
				String(member.get("display_name", "")),
				String(member.get("character_id", "")),
				String(member.get("profession_id", "")),
				String(role_id),
				int(stats.get("max_hp", 0)),
				"治疗" if role_id == &"doctor" else "攻击",
				int(stats.get("attack", 0)),
				action_interval,
				float(compatibility.get("action_range", 0.0)),
				ProfessionCompatibility.COMPATIBILITY_SOURCE,
			]
		)
	return "\n".join(lines)


func _input(event: InputEvent) -> void:
	if not visible or active_request.is_empty():
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode != KEY_ESCAPE:
		return
	if is_instance_valid(_prototype) and (
		bool(_prototype.get("debug_panel_open"))
		or StringName(_prototype.get("ultimate_targeting_character_id")) != &""
	):
		return
	abort_preview()
	get_viewport().set_input_as_handled()


func _build_layout() -> void:
	_battle_mount = Control.new()
	_battle_mount.name = "BattleMount"
	_battle_mount.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_battle_mount)

	var header := PanelContainer.new()
	header.name = "IntegrationPreviewHeader"
	header.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	header.offset_left = -760.0
	header.offset_top = 12.0
	header.offset_right = -16.0
	header.offset_bottom = 58.0
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.z_index = 1000
	add_child(header)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	header.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	_status_label = Label.new()
	_status_label.name = "PreviewStatusLabel"
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.text = "V2接入预览（不结算）"
	_status_label.add_theme_color_override("font_color", Color(0.82, 0.94, 1.0))
	row.add_child(_status_label)
	_exit_button = Button.new()
	_exit_button.name = "ExitPreviewButton"
	_exit_button.text = "退出预览"
	_exit_button.tooltip_text = "安全中止本局并返回；不会执行正式结算"
	_exit_button.pressed.connect(abort_preview)
	row.add_child(_exit_button)


func _configure_integration_preview_ui() -> void:
	_prototype.call("set_debug_panel_open", false)
	for property_name: String in [
		"debug_toggle_button",
		"scenario_option",
		"start_button",
		"restart_button",
		"recommend_button",
		"clear_deployment_button",
		"undeploy_button",
	]:
		var control = _prototype.get(property_name)
		if is_instance_valid(control):
			control.visible = false


func _on_prototype_battle_finished(outcome: StringName) -> void:
	var normalized := (
		BattleContract.OUTCOME_VICTORY
		if outcome == &"victory"
		else BattleContract.OUTCOME_DEFEAT
	)
	_finish_preview(normalized)


func _finish_preview(outcome: String) -> bool:
	if _terminal_emitted or active_request.is_empty():
		return false
	_terminal_emitted = true
	_last_terminal_debug_snapshot = _get_prototype_snapshot().duplicate(true)
	var result_creation := BattleContract.create_result(
		_build_result_source(outcome, _last_terminal_debug_snapshot)
	)
	if not bool(result_creation.get("ok", false)):
		var message := "V2预览输出契约非法：%s" % "; ".join(
			result_creation.get("errors", [])
		)
		_cleanup_runtime()
		preview_error.emit(message)
		return false
	var result: Dictionary = result_creation["value"].duplicate(true)
	_cleanup_runtime()
	preview_finished.emit(result)
	return true


func _build_result_source(
	outcome: String,
	raw_snapshot: Dictionary = {}
) -> Dictionary:
	var snapshot := (
		raw_snapshot.duplicate(true)
		if not raw_snapshot.is_empty()
		else _get_prototype_snapshot()
	)
	var characters_by_id: Dictionary = {}
	for character: Dictionary in snapshot.get("characters", []):
		characters_by_id[StringName(character.get("character_id", &""))] = character
	var party_results: Array = []
	for member: Dictionary in active_request.get("party", []):
		var formal_id := StringName(member.get("character_id", &""))
		var character: Dictionary = characters_by_id.get(formal_id, {})
		var is_doctor := ProfessionCompatibility.get_v2_role_id(
			StringName(member.get("profession_id", &""))
		) == &"doctor"
		party_results.append({
			"character_id": String(member.get("character_id", "")),
			"is_down": not bool(character.get("is_alive", false)),
			"remaining_hp": maxi(0, int(character.get("current_health", 0))),
			"statistics": {
				"damage_dealt": (
					0 if is_doctor else int(character.get("total_effect_amount", 0))
				),
				"damage_taken": int(character.get("total_damage_taken", 0)),
				"healing_done": (
					int(character.get("total_effect_amount", 0)) if is_doctor else 0
				),
				"kills": 0,
				"ultimate_casts": int(character.get("ultimate_release_count", 0)),
			},
		})
	var wave: Dictionary = snapshot.get("wave", {})
	return {
		"contract_version": BattleContract.CONTRACT_VERSION,
		"battle_session_id": String(
			active_request.get("battle_session_id", "")
		),
		"battle_id": String(active_request.get("battle_id", "")),
		"outcome": outcome,
		"duration_seconds": maxf(0.0, float(snapshot.get("battle_elapsed", 0.0))),
		"village_durability": {
			"remaining": clampi(
				int(snapshot.get("village_durability", 0)),
				0,
				int(snapshot.get("max_durability", 10))
			),
			"maximum": maxi(1, int(snapshot.get("max_durability", 10))),
		},
		"party_results": party_results,
		"battle_statistics": {
			"generated_enemies": int(snapshot.get("generated_enemy_count", 0)),
			"defeated_enemies": int(snapshot.get("killed_enemy_count", 0)),
			"leaked_enemies": int(snapshot.get("leaked_enemy_count", 0)),
			"waves_completed": _count_completed_waves(wave),
		},
	}


func _count_completed_waves(wave: Dictionary) -> int:
	if String(wave.get("state", "")) == "COMPLETED":
		return int(wave.get("total_waves", 0))
	var completed := maxi(0, int(wave.get("current_wave_index", -1)))
	if (
		int(wave.get("current_wave_planned", -1)) >= 0
		and int(wave.get("current_wave_resolved", -2))
			== int(wave.get("current_wave_planned", -1))
	):
		completed += 1
	return mini(completed, int(wave.get("total_waves", completed)))


func _get_prototype_snapshot() -> Dictionary:
	if not is_instance_valid(_prototype) \
			or not _prototype.has_method("get_battle_snapshot"):
		return {
			"village_durability": 10,
			"max_durability": 10,
			"characters": [],
			"wave": {},
		}
	return _prototype.call("get_battle_snapshot")


func _find_scenario_for_wave_config(wave_config_id: StringName) -> StringName:
	for scenario_id: StringName in PrototypeConfig.get_scenario_ids():
		var scenario := PrototypeConfig.get_scenario(scenario_id)
		if StringName(scenario.get("wave_battle_id", &"")) == wave_config_id:
			return scenario_id
	return &""


func _cleanup_runtime() -> void:
	if is_instance_valid(_prototype):
		if _prototype.battle_finished.is_connected(_on_prototype_battle_finished):
			_prototype.battle_finished.disconnect(_on_prototype_battle_finished)
		_prototype.call("set_automatic_simulation", false)
		if _prototype.get_parent() != null:
			_prototype.get_parent().remove_child(_prototype)
		_prototype.queue_free()
	_prototype = null
	active_request = {}
	visible = false
	set_process_input(false)


func _failure(message: String) -> Dictionary:
	return {
		"ok": false,
		"errors": PackedStringArray([message]),
		"value": {},
	}

class_name FormationDefenseBattleRouter
extends RefCounted

const BattleContract := preload(
	"res://scripts/data/formation_defense_battle_contract.gd"
)
const BattleAdapter := preload(
	"res://systems/formation_defense_battle_adapter.gd"
)
const PreviewRequestBuilder := preload(
	"res://systems/formation_defense_preview_request_builder.gd"
)

const MODE_V1 := &"V1"
const MODE_V2_INTEGRATION_PREVIEW := &"V2_INTEGRATION_PREVIEW"
const MODE_V2_SETTLEMENT_VALIDATION := &"V2_SETTLEMENT_VALIDATION"
const VALID_MODES: Array[StringName] = [
	MODE_V1,
	MODE_V2_INTEGRATION_PREVIEW,
	MODE_V2_SETTLEMENT_VALIDATION,
]

var current_mode: StringName = MODE_V1
var active_request: Dictionary = {}
var active_session_mode: StringName = &""
var last_accepted_result: Dictionary = {}
var last_error := ""
var rejected_result_count := 0

var _session_sequence := 0
var _session_id_factory: Callable
var _closed_session_ids: Dictionary = {}


func set_mode(requested_mode: StringName) -> bool:
	if requested_mode not in VALID_MODES:
		current_mode = MODE_V1
		last_error = "非法战斗模式 %s，已安全回退 V1" % String(requested_mode)
		push_warning(last_error)
		return false
	current_mode = requested_mode
	last_error = ""
	return true


func set_session_id_factory_for_tests(factory: Callable) -> void:
	_session_id_factory = factory


func route_selected_battle(
	formal_battle_gateway: Object,
	source_context: Dictionary
) -> Dictionary:
	if has_active_preview_session():
		return _failure("已有V2预览会话，拒绝重复启动")
	if current_mode == MODE_V1:
		return _start_v1(formal_battle_gateway, source_context)
	if current_mode == MODE_V2_INTEGRATION_PREVIEW:
		return _start_v2_preview(source_context)
	if current_mode == MODE_V2_SETTLEMENT_VALIDATION:
		return _start_v2_settlement(source_context)
	set_mode(current_mode)
	return _failure(last_error)


func accept_preview_result(raw_result: Dictionary) -> Dictionary:
	return _accept_active_result(raw_result, MODE_V2_INTEGRATION_PREVIEW)


func accept_settlement_result(raw_result: Dictionary) -> Dictionary:
	return _accept_active_result(raw_result, MODE_V2_SETTLEMENT_VALIDATION)


func _accept_active_result(
	raw_result: Dictionary,
	expected_mode: StringName
) -> Dictionary:
	if active_request.is_empty():
		return _reject_result("无活动V2会话，结果已拒绝")
	if active_session_mode != expected_mode:
		return _reject_result("V2结果提交到了错误的会话模式")
	var creation := BattleContract.create_result(raw_result)
	if not bool(creation.get("ok", false)):
		return _reject_result(
			"V2输出契约非法：%s" % "; ".join(creation.get("errors", []))
		)
	var result: Dictionary = creation["value"]
	var active_session_id := String(active_request.get("battle_session_id", ""))
	var result_session_id := String(result.get("battle_session_id", ""))
	if result_session_id != active_session_id:
		return _reject_result(
			"V2结果session不匹配：active=%s result=%s" % [
				active_session_id,
				result_session_id,
			]
		)
	if _closed_session_ids.has(result_session_id):
		return _reject_result("V2会话已终结，重复结果已拒绝")
	var settlement_input := BattleAdapter.build_settlement_input(
		active_request,
		result
	)
	if not bool(settlement_input.get("ok", false)):
		return _reject_result(
			"V2请求与结果不一致：%s" % "; ".join(
				settlement_input.get("errors", [])
			)
		)
	_closed_session_ids[result_session_id] = true
	last_accepted_result = result.duplicate(true)
	active_request = {}
	active_session_mode = &""
	last_error = ""
	return {
		"ok": true,
		"errors": PackedStringArray(),
		"value": result.duplicate(true),
		"settlement_preview": settlement_input["value"].duplicate(true),
	}


func fail_active_preview(message: String) -> void:
	fail_active_session(message)


func fail_active_session(message: String) -> void:
	if not active_request.is_empty():
		_closed_session_ids[String(active_request.get("battle_session_id", ""))] = true
	active_request = {}
	active_session_mode = &""
	last_error = message
	push_warning(message)


func has_active_preview_session() -> bool:
	return not active_request.is_empty()


func get_active_session_id() -> String:
	return String(active_request.get("battle_session_id", ""))


func get_snapshot() -> Dictionary:
	return {
		"mode": current_mode,
		"has_active_preview": has_active_preview_session(),
		"active_session_id": get_active_session_id(),
		"active_request": active_request.duplicate(true),
		"active_session_mode": active_session_mode,
		"last_accepted_result": last_accepted_result.duplicate(true),
		"last_error": last_error,
		"rejected_result_count": rejected_result_count,
		"closed_session_count": _closed_session_ids.size(),
	}


func _start_v1(
	formal_battle_gateway: Object,
	source_context: Dictionary
) -> Dictionary:
	var encounter_id := StringName(source_context.get("encounter_id", &""))
	if encounter_id == &"":
		return _failure("V1正式战斗需要有效遭遇ID")
	if formal_battle_gateway == null \
			or not formal_battle_gateway.has_method("start_battle"):
		return _failure("V1正式战斗入口不可用")
	var started := bool(formal_battle_gateway.call("start_battle", encounter_id))
	if not started:
		return _failure("V1正式战斗未能启动")
	return {
		"ok": true,
		"errors": PackedStringArray(),
		"route": MODE_V1,
		"request": {},
	}


func _start_v2_preview(source_context: Dictionary) -> Dictionary:
	var session_id := _next_session_id()
	var request_creation := PreviewRequestBuilder.build_preview_request(
		session_id,
		source_context
	)
	if not bool(request_creation.get("ok", false)):
		last_error = "V2预览请求无效：%s" % "; ".join(
			request_creation.get("errors", [])
		)
		return request_creation
	active_request = request_creation["value"].duplicate(true)
	active_session_mode = MODE_V2_INTEGRATION_PREVIEW
	last_error = ""
	return {
		"ok": true,
		"errors": PackedStringArray(),
		"route": MODE_V2_INTEGRATION_PREVIEW,
		"request": active_request.duplicate(true),
	}


func _start_v2_settlement(source_context: Dictionary) -> Dictionary:
	var session_id := _next_session_id()
	var request_creation := PreviewRequestBuilder.build_settlement_request(
		session_id,
		source_context
	)
	if not bool(request_creation.get("ok", false)):
		last_error = "V2正式结算请求无效：%s" % "; ".join(
			request_creation.get("errors", [])
		)
		return request_creation
	active_request = request_creation["value"].duplicate(true)
	active_session_mode = MODE_V2_SETTLEMENT_VALIDATION
	last_error = ""
	return {
		"ok": true,
		"errors": PackedStringArray(),
		"route": MODE_V2_SETTLEMENT_VALIDATION,
		"request": active_request.duplicate(true),
	}


func _next_session_id() -> String:
	_session_sequence += 1
	if _session_id_factory.is_valid():
		return String(_session_id_factory.call(_session_sequence))
	return "formation-defense-preview:%d:%d" % [
		Time.get_ticks_usec(),
		_session_sequence,
	]


func _reject_result(message: String) -> Dictionary:
	rejected_result_count += 1
	last_error = message
	push_warning(message)
	return _failure(message)


func _failure(message: String) -> Dictionary:
	last_error = message
	return {
		"ok": false,
		"errors": PackedStringArray([message]),
		"value": {},
	}

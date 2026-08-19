class_name FormationDefenseSettlementService
extends RefCounted

const BattleContract := preload(
	"res://scripts/data/formation_defense_battle_contract.gd"
)
const BattleAdapter := preload(
	"res://systems/formation_defense_battle_adapter.gd"
)

const SOURCE_MODE := "FORMAL_SETTLEMENT_VALIDATION"
const STATE_UNSEEN := &"UNSEEN"
const STATE_PROCESSING := &"PROCESSING"
const STATE_APPLIED := &"APPLIED"
const STATE_REJECTED := &"REJECTED"
const STATE_CLOSED := &"CLOSED"

var last_error := ""
var last_receipt: Dictionary = {}
var rejected_count := 0

var _sessions: Dictionary = {}
var _settlements: Dictionary = {}
var _settlement_by_session: Dictionary = {}


func open_session(game_state: Object, raw_request: Dictionary) -> Dictionary:
	var request_creation := BattleContract.create_request(raw_request)
	if not bool(request_creation.get("ok", false)):
		return _reject("正式结算请求契约非法：%s" % "; ".join(
			request_creation.get("errors", [])
		))
	var request: Dictionary = request_creation["value"]
	var session_id := String(request.get("battle_session_id", ""))
	var settlement_id := BattleContract.make_settlement_id(session_id)
	if _sessions.has(session_id) or _settlement_by_session.has(session_id):
		return _reject("正式结算session已存在")
	if _settlements.has(settlement_id):
		return _reject("正式结算ID已存在")
	var context_errors := _validate_formal_context(game_state, request)
	if not context_errors.is_empty():
		return _reject("正式遭遇上下文非法：%s" % "; ".join(context_errors))
	_sessions[session_id] = {
		"state": STATE_UNSEEN,
		"request": request.duplicate(true),
		"request_fingerprint": _fingerprint(request),
		"prepared_plan": {},
		"prepared_fingerprint": "",
	}
	last_error = ""
	return _success({
		"battle_session_id": session_id,
		"settlement_id": settlement_id,
		"state": STATE_UNSEEN,
	})


func prepare_settlement(
	game_state: Object,
	raw_request: Dictionary,
	raw_result: Dictionary
) -> Dictionary:
	var settlement_input := BattleAdapter.build_settlement_input(
		raw_request,
		raw_result
	)
	if not bool(settlement_input.get("ok", false)):
		return _reject("正式结算事实非法：%s" % "; ".join(
			settlement_input.get("errors", [])
		))
	var request: Dictionary = BattleContract.create_request(raw_request)["value"]
	var result: Dictionary = BattleContract.create_result(raw_result)["value"]
	var session_id := String(result.get("battle_session_id", ""))
	if not _sessions.has(session_id):
		return _reject("正式结算没有活动session")
	var session: Dictionary = _sessions[session_id]
	if StringName(session.get("state", STATE_REJECTED)) != STATE_UNSEEN:
		return _reject("正式结算session不处于可准备状态")
	if String(session.get("request_fingerprint", "")) != _fingerprint(request):
		return _reject("正式结算请求内容与启动快照不同")
	var expected_settlement_id := BattleContract.make_settlement_id(session_id)
	if String(result.get("settlement_id", "")) != expected_settlement_id:
		return _reject("正式结算ID与session不匹配")
	if _settlements.has(expected_settlement_id):
		return _reject("正式结算ID已经被处理")
	var context_errors := _validate_formal_context(game_state, request)
	if not context_errors.is_empty():
		return _reject("正式结算时遭遇上下文已失效：%s" % "; ".join(
			context_errors
		))
	if String(result.get("outcome", "")) == BattleContract.OUTCOME_ABORTED:
		return _success({})
	var source_outcome := String(result.get("outcome", ""))
	var village_durability: Dictionary = result.get(
		"village_durability",
		{}
	).duplicate(true)
	var durability_remaining := int(village_durability.get("remaining", -1))
	if source_outcome == BattleContract.OUTCOME_VICTORY \
			and durability_remaining <= 0:
		return _reject("V2胜利事实与村庄耐久不一致")
	if source_outcome == BattleContract.OUTCOME_DEFEAT \
			and durability_remaining != 0:
		return _reject("V2失败事实与村庄耐久不一致")

	var profile: Dictionary = game_state.call(
		"get_formal_battle_settlement_profile",
		StringName(request.get("battle_id", &""))
	)
	if profile.is_empty():
		return _reject("正式遭遇没有结算配置")
	var outcome := (
		"victory"
		if String(result.get("outcome", "")) == BattleContract.OUTCOME_VICTORY
		else "failure"
	)
	var result_by_id: Dictionary = {}
	for party_result: Dictionary in result.get("party_results", []):
		result_by_id[String(party_result.get("character_id", ""))] = party_result
	var participant_ids: Array = []
	var runtime_hp_updates: Array = []
	var downed_participant_count := 0
	for member: Dictionary in request.get("party", []):
		var character_id := StringName(member.get("character_id", &""))
		var party_result: Dictionary = result_by_id.get(String(character_id), {})
		var v2_max_hp := int(member.get("final_stats", {}).get("max_hp", 0))
		var v2_remaining_hp := int(party_result.get("remaining_hp", -1))
		if v2_max_hp <= 0 or v2_remaining_hp < 0 or v2_remaining_hp > v2_max_hp:
			return _reject("V2角色剩余生命超出请求快照范围")
		var formal_stats: Dictionary = game_state.call(
			"get_final_combat_stats",
			character_id
		)
		var formal_max_hp := int(formal_stats.get("max_hp", 0))
		if formal_max_hp <= 0:
			return _reject("正式角色最大生命非法")
		var is_down := bool(party_result.get("is_down", false))
		if is_down != (v2_remaining_hp <= 0):
			return _reject("V2角色倒下事实与剩余生命不一致")
		if is_down:
			downed_participant_count += 1
		var formal_current_hp := (
			0
			if is_down
			else clampi(
				roundi(
					float(formal_max_hp)
					* float(v2_remaining_hp)
					/ float(v2_max_hp)
				),
				1,
				formal_max_hp
			)
		)
		participant_ids.append(character_id)
		runtime_hp_updates.append({
			"character_id": character_id,
			"current_hp": formal_current_hp,
			"max_hp": formal_max_hp,
			"is_down": is_down,
		})
	var rewards := {
		"ore": int(profile.get("reward_ore", 0)) if outcome == "victory" else 0,
		"herb": int(profile.get("reward_herb", 0)) if outcome == "victory" else 0,
		"core": int(profile.get("reward_core", 0)) if outcome == "victory" else 0,
	}
	var injury_changes: Array = []
	if outcome == "failure":
		for character_id in participant_ids:
			injury_changes.append({
				"character_id": character_id,
				"new_state": &"injured",
				"reason": &"expedition_failed",
			})
	var plan := {
		"settlement_id": expected_settlement_id,
		"battle_session_id": session_id,
		"battle_id": String(request.get("battle_id", "")),
		"encounter_id": StringName(request.get("battle_id", &"")),
		"node_id": StringName(
			request.get("encounter_context", {}).get("encounter_node_id", &"")
		),
		"outcome": outcome,
		"v2_outcome": source_outcome,
		"village_durability": village_durability,
		"downed_participant_count": downed_participant_count,
		"participant_ids": participant_ids,
		"experience_per_character": int(profile.get(
			"experience_victory" if outcome == "victory" else "experience_defeat",
			0
		)),
		"rewards": rewards,
		"is_boss": bool(profile.get("is_boss", false)),
		"runtime_hp_updates": runtime_hp_updates,
		"injury_changes": injury_changes,
		"node_completed": outcome == "victory",
		"expedition_action": "continue" if outcome == "victory" else "end_failure",
		"return_view": "expedition" if outcome == "victory" else "village",
	}
	var game_state_errors: PackedStringArray = game_state.call(
		"validate_formation_defense_settlement_plan",
		plan
	)
	if not game_state_errors.is_empty():
		return _reject("正式结算计划验证失败：%s" % "; ".join(
			game_state_errors
		))
	session["prepared_plan"] = plan.duplicate(true)
	session["prepared_fingerprint"] = _fingerprint(plan)
	_sessions[session_id] = session
	last_error = ""
	return _success(plan)


func apply_settlement(game_state: Object, plan: Dictionary) -> Dictionary:
	var session_id := String(plan.get("battle_session_id", ""))
	var settlement_id := String(plan.get("settlement_id", ""))
	if not _sessions.has(session_id):
		return _reject("正式结算没有活动session")
	var session: Dictionary = _sessions[session_id]
	if StringName(session.get("state", STATE_REJECTED)) != STATE_UNSEEN:
		return _reject("正式结算session已处理")
	if String(session.get("prepared_fingerprint", "")) != _fingerprint(plan):
		return _reject("正式结算计划与已验证计划不同")
	if settlement_id != BattleContract.make_settlement_id(session_id):
		return _reject("正式结算ID非法")
	if _settlements.has(settlement_id) or _settlement_by_session.has(session_id):
		return _reject("正式结算已应用")
	session["state"] = STATE_PROCESSING
	_sessions[session_id] = session
	_settlements[settlement_id] = {
		"state": STATE_PROCESSING,
		"plan_fingerprint": _fingerprint(plan),
	}
	_settlement_by_session[session_id] = settlement_id
	var application: Dictionary = game_state.call(
		"apply_formation_defense_settlement_plan",
		plan
	)
	if not bool(application.get("ok", false)):
		session["state"] = STATE_REJECTED
		_sessions[session_id] = session
		_settlements[settlement_id]["state"] = STATE_REJECTED
		return _reject("正式结算应用失败：%s" % "; ".join(
			application.get("errors", [])
		))
	var receipt: Dictionary = application.get("value", {}).duplicate(true)
	session["state"] = STATE_APPLIED
	_sessions[session_id] = session
	_settlements[settlement_id] = {
		"state": STATE_APPLIED,
		"plan_fingerprint": _fingerprint(plan),
		"receipt": receipt.duplicate(true),
	}
	last_receipt = receipt.duplicate(true)
	last_error = ""
	return _success(receipt)


func close_aborted_session(
	raw_request: Dictionary,
	raw_result: Dictionary
) -> Dictionary:
	var settlement_input := BattleAdapter.build_settlement_input(
		raw_request,
		raw_result
	)
	if not bool(settlement_input.get("ok", false)):
		return _reject("中止事实非法")
	var result: Dictionary = BattleContract.create_result(raw_result)["value"]
	if String(result.get("outcome", "")) != BattleContract.OUTCOME_ABORTED:
		return _reject("仅ABORTED结果可以关闭未结算session")
	var session_id := String(result.get("battle_session_id", ""))
	if not _sessions.has(session_id):
		return _reject("中止结果没有活动session")
	var session: Dictionary = _sessions[session_id]
	if StringName(session.get("state", STATE_REJECTED)) != STATE_UNSEEN:
		return _reject("中止session已经关闭")
	session["state"] = STATE_CLOSED
	session["prepared_plan"] = {}
	session["prepared_fingerprint"] = ""
	_sessions[session_id] = session
	last_error = ""
	return _success({
		"battle_session_id": session_id,
		"outcome": BattleContract.OUTCOME_ABORTED,
		"message": "未执行正式结算",
	})


func reject_session(session_id: String, message: String) -> void:
	if _sessions.has(session_id):
		var session: Dictionary = _sessions[session_id]
		if StringName(session.get("state", STATE_REJECTED)) == STATE_UNSEEN:
			session["state"] = STATE_REJECTED
			_sessions[session_id] = session
	last_error = message


func get_snapshot() -> Dictionary:
	var states: Dictionary = {}
	var applied_count := 0
	for session_id in _sessions.keys():
		states[session_id] = _sessions[session_id].get("state", STATE_REJECTED)
	for record: Dictionary in _settlements.values():
		if StringName(record.get("state", STATE_REJECTED)) == STATE_APPLIED:
			applied_count += 1
	return {
		"session_states": states,
		"settlement_count": _settlements.size(),
		"applied_count": applied_count,
		"rejected_count": rejected_count,
		"last_error": last_error,
		"last_receipt": last_receipt.duplicate(true),
	}


func _validate_formal_context(
	game_state: Object,
	request: Dictionary
) -> PackedStringArray:
	var errors := PackedStringArray()
	if game_state == null:
		errors.append("GameState不可用")
		return errors
	for method_name: String in [
		"is_expedition_active",
		"get_expedition_state",
		"get_current_node_encounter_id",
		"is_current_battle_node_cleared",
		"get_formal_battle_settlement_profile",
		"get_final_combat_stats",
	]:
		if not game_state.has_method(method_name):
			errors.append("GameState缺少正式结算API：%s" % method_name)
	if not errors.is_empty():
		return errors
	var context: Dictionary = request.get("encounter_context", {})
	if String(context.get("source_mode", "")) != SOURCE_MODE:
		errors.append("请求不是V2正式结算验证来源")
	if not bool(game_state.call("is_expedition_active")):
		errors.append("当前没有活动远征")
		return errors
	var expedition: Dictionary = game_state.call("get_expedition_state")
	var request_node_id := StringName(context.get("encounter_node_id", &""))
	if request_node_id == &"" or StringName(
		expedition.get("current_node_id", &"")
	) != request_node_id:
		errors.append("请求节点与当前远征节点不一致")
	var encounter_id := StringName(request.get("battle_id", &""))
	if StringName(game_state.call("get_current_node_encounter_id")) != encounter_id:
		errors.append("请求遭遇与当前节点不一致")
	if bool(game_state.call("is_current_battle_node_cleared")):
		errors.append("当前遭遇已经解决")
	var profile: Dictionary = game_state.call(
		"get_formal_battle_settlement_profile",
		encounter_id
	)
	if profile.is_empty() or StringName(profile.get("node_id", &"")) != request_node_id:
		errors.append("正式遭遇配置与节点不匹配")
	return errors


func _fingerprint(value: Variant) -> String:
	return JSON.stringify(value)


func _reject(message: String) -> Dictionary:
	rejected_count += 1
	last_error = message
	return {
		"ok": false,
		"errors": PackedStringArray([message]),
		"value": {},
	}


func _success(value: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"errors": PackedStringArray(),
		"value": value.duplicate(true),
	}

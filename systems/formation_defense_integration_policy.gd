class_name FormationDefenseIntegrationPolicy
extends RefCounted

const PrototypeConfig := preload(
	"res://prototype/formation_defense/data/formation_defense_config.gd"
)

const IMPLEMENTATION_V1 := &"V1"
const IMPLEMENTATION_V2 := &"V2"
const STATUS_TECHNICALLY_SUPPORTED := &"TECHNICALLY_SUPPORTED"
const STATUS_UNSUPPORTED := &"UNSUPPORTED"
const STATUS_UNCONFIGURED := &"UNCONFIGURED"

const FORMAL_ROUTE_TABLE := {
	&"forest_slime_pair": {
		"encounter_id": &"forest_slime_pair",
		"encounter_node_id": &"forest_edge",
		"encounter_kind": &"normal",
		"implementation": IMPLEMENTATION_V2,
		"battle_id": &"v2_7b_three_archetype_full_battle",
		"formal_settlement_supported": true,
		"support_status": STATUS_TECHNICALLY_SUPPORTED,
		"support_reason": "V2综合战与正式结算已验证；正式总开关默认关闭",
	},
	&"ruins_guard": {
		"encounter_id": &"ruins_guard",
		"encounter_node_id": &"ruins_entrance",
		"encounter_kind": &"boss",
		"implementation": IMPLEMENTATION_V1,
		"battle_id": &"",
		"formal_settlement_supported": false,
		"support_status": STATUS_UNSUPPORTED,
		"support_reason": "尚无V2 Boss机制与专属波次，继续使用V1",
	},
}

var formation_defense_rollout_enabled := false
var debug_tools_visible := false
var _route_table: Dictionary = {}


func _init(options: Dictionary = {}) -> void:
	formation_defense_rollout_enabled = bool(
		options.get("formation_defense_rollout_enabled", false)
	)
	debug_tools_visible = bool(options.get(
		"debug_tools_visible",
		Engine.is_editor_hint() or OS.is_debug_build()
	))
	var injected_table = options.get("route_table", FORMAL_ROUTE_TABLE)
	_route_table = (
		injected_table.duplicate(true)
		if injected_table is Dictionary
		else FORMAL_ROUTE_TABLE.duplicate(true)
	)


func resolve_formal_route(encounter_id: StringName) -> Dictionary:
	if not _route_table.has(encounter_id):
		return _success_v1(
			encounter_id,
			STATUS_UNCONFIGURED,
			"遭遇未配置V2正式路由，明确使用V1"
		)
	var entry: Dictionary = _route_table[encounter_id].duplicate(true)
	var configured_id := StringName(entry.get("encounter_id", &""))
	if configured_id != encounter_id:
		return _failure("正式路由表encounter_id与索引不一致")
	var implementation := StringName(
		entry.get("implementation", IMPLEMENTATION_V1)
	)
	if implementation == IMPLEMENTATION_V1:
		return _success(entry, IMPLEMENTATION_V1)
	if implementation != IMPLEMENTATION_V2:
		return _failure("正式路由表包含非法战斗实现")
	if not bool(entry.get("formal_settlement_supported", false)):
		return _success(entry, IMPLEMENTATION_V1)
	var battle_id := StringName(entry.get("battle_id", &""))
	if battle_id == &"":
		return _failure("显式V2遭遇缺少battle_id，拒绝启动")
	if PrototypeConfig.get_wave_battle_config(battle_id).is_empty():
		return _failure("显式V2遭遇battle配置不存在，拒绝启动")
	if not formation_defense_rollout_enabled:
		return _success(entry, IMPLEMENTATION_V1)
	return _success(entry, IMPLEMENTATION_V2)


func get_support_matrix() -> Array[Dictionary]:
	var matrix: Array[Dictionary] = []
	var encounter_ids: Array = _route_table.keys()
	encounter_ids.sort_custom(func(a: Variant, b: Variant) -> bool:
		return String(a) < String(b)
	)
	for encounter_id: Variant in encounter_ids:
		matrix.append(_route_table[encounter_id].duplicate(true))
	return matrix


func get_snapshot() -> Dictionary:
	return {
		"formation_defense_rollout_enabled": formation_defense_rollout_enabled,
		"debug_tools_visible": debug_tools_visible,
		"route_table": _route_table.duplicate(true),
	}


func _success_v1(
	encounter_id: StringName,
	status: StringName,
	reason: String
) -> Dictionary:
	return _success({
		"encounter_id": encounter_id,
		"encounter_node_id": &"",
		"encounter_kind": &"unknown",
		"implementation": IMPLEMENTATION_V1,
		"battle_id": &"",
		"formal_settlement_supported": false,
		"support_status": status,
		"support_reason": reason,
	}, IMPLEMENTATION_V1)


func _success(entry: Dictionary, route: StringName) -> Dictionary:
	return {
		"ok": true,
		"errors": PackedStringArray(),
		"route": route,
		"entry": entry.duplicate(true),
	}


func _failure(message: String) -> Dictionary:
	return {
		"ok": false,
		"errors": PackedStringArray([message]),
		"route": &"",
		"entry": {},
	}

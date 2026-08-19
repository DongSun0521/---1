class_name FormationDefensePreviewRequestBuilder
extends RefCounted

const BattleAdapter := preload("res://systems/formation_defense_battle_adapter.gd")
const PrototypeConfig := preload(
	"res://prototype/formation_defense/data/formation_defense_config.gd"
)

const PREVIEW_WAVE_CONFIG_ID := &"v2_7b_three_archetype_full_battle"
const PREVIEW_FALLBACK_ENCOUNTER_ID := &"development:formation_defense_preview"
const PREVIEW_ENEMY_PROFILE_IDS: Array[StringName] = [
	&"formation_guard",
	&"charge",
	&"rush_raider",
]
const SETTLEMENT_SOURCE_MODE := &"FORMAL_SETTLEMENT_VALIDATION"
const SETTLEMENT_WAVE_CONFIG_BY_ENCOUNTER := {
	&"forest_slime_pair": PREVIEW_WAVE_CONFIG_ID,
	&"ruins_guard": PREVIEW_WAVE_CONFIG_ID,
}


static func build_preview_request(
	battle_session_id: String,
	source_context: Dictionary = {}
) -> Dictionary:
	var battle_config := PrototypeConfig.get_wave_battle_config(
		PREVIEW_WAVE_CONFIG_ID
	)
	if battle_config.is_empty():
		return _failure("frozen V2 preview battle config is missing")
	var encounter_id := StringName(
		source_context.get("encounter_id", PREVIEW_FALLBACK_ENCOUNTER_ID)
	)
	if encounter_id == &"":
		encounter_id = PREVIEW_FALLBACK_ENCOUNTER_ID
	var source_mode := StringName(
		source_context.get("source_mode", &"MAIN_DEVELOPMENT_PREVIEW")
	)
	if source_mode == &"":
		source_mode = &"MAIN_DEVELOPMENT_PREVIEW"
	var raw_party_snapshots = source_context.get("party_snapshots", [])
	if not raw_party_snapshots is Array or raw_party_snapshots.is_empty():
		return _failure("formal V2 preview requires a non-empty detached party snapshot")
	var party_snapshots: Array = raw_party_snapshots.duplicate(true)
	return BattleAdapter.build_battle_request_snapshot({
		"battle_session_id": battle_session_id,
		"encounter_id": encounter_id,
		"random_seed": int(battle_config.get("random_seed", 0)),
		"party_snapshots": party_snapshots,
		"battle_config_ref": {
			"wave_config_id": PREVIEW_WAVE_CONFIG_ID,
			"enemy_profile_ids": PREVIEW_ENEMY_PROFILE_IDS.duplicate(),
		},
		"encounter_context": {
			"source_mode": source_mode,
			"encounter_node_id": String(
				source_context.get("encounter_node_id", "")
			),
		},
	})


static func build_settlement_request(
	battle_session_id: String,
	source_context: Dictionary
) -> Dictionary:
	var encounter_id := StringName(source_context.get("encounter_id", &""))
	var encounter_node_id := StringName(
		source_context.get("encounter_node_id", &"")
	)
	if encounter_id == &"" or encounter_node_id == &"":
		return _failure("V2正式结算验证需要真实遭遇与远征节点")
	if not SETTLEMENT_WAVE_CONFIG_BY_ENCOUNTER.has(encounter_id):
		return _failure("正式遭遇尚未配置V2验证战映射")
	var wave_config_id: StringName = SETTLEMENT_WAVE_CONFIG_BY_ENCOUNTER[
		encounter_id
	]
	var battle_config := PrototypeConfig.get_wave_battle_config(wave_config_id)
	if battle_config.is_empty():
		return _failure("V2正式结算验证battle配置缺失")
	var raw_party_snapshots = source_context.get("party_snapshots", [])
	if not raw_party_snapshots is Array or raw_party_snapshots.is_empty():
		return _failure("V2正式结算验证需要正式参战队伍快照")
	return BattleAdapter.build_battle_request_snapshot({
		"battle_session_id": battle_session_id,
		"encounter_id": encounter_id,
		"random_seed": int(battle_config.get("random_seed", 0)),
		"party_snapshots": raw_party_snapshots.duplicate(true),
		"battle_config_ref": {
			"wave_config_id": wave_config_id,
			"enemy_profile_ids": PREVIEW_ENEMY_PROFILE_IDS.duplicate(),
		},
		"encounter_context": {
			"source_mode": SETTLEMENT_SOURCE_MODE,
			"encounter_node_id": String(encounter_node_id),
		},
	})


static func _failure(message: String) -> Dictionary:
	return {
		"ok": false,
		"errors": PackedStringArray([message]),
		"value": {},
	}

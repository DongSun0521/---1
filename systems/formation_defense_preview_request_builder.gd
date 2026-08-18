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
const PROTOTYPE_CHARACTER_PREFIX := "prototype:"


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
	var party_snapshots: Array = []
	for party_slot: int in range(PrototypeConfig.get_character_ids().size()):
		var character_id: StringName = PrototypeConfig.get_character_ids()[party_slot]
		party_snapshots.append(_build_prototype_party_member(character_id, party_slot))
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


static func is_prototype_character_id(character_id: Variant) -> bool:
	return String(character_id).begins_with(PROTOTYPE_CHARACTER_PREFIX)


static func get_local_character_id(character_id: Variant) -> StringName:
	var normalized := String(character_id)
	if not normalized.begins_with(PROTOTYPE_CHARACTER_PREFIX):
		return &""
	return StringName(normalized.trim_prefix(PROTOTYPE_CHARACTER_PREFIX))


static func _build_prototype_party_member(
	character_id: StringName,
	party_slot: int
) -> Dictionary:
	var definition := PrototypeConfig.get_character_definition(character_id)
	var ultimate := PrototypeConfig.get_character_ultimate_definition(character_id)
	var action_interval := maxf(0.05, float(definition.get("action_interval", 1.0)))
	return {
		"character_id": PROTOTYPE_CHARACTER_PREFIX + String(character_id),
		"display_name": "%s（原型）" % String(
			definition.get("display_name", character_id)
		),
		"profession_id": String(character_id),
		"role_display_name": String(definition.get("display_name", character_id)),
		"party_slot": party_slot,
		"final_stats": {
			"max_hp": int(definition.get("max_health", 1)),
			"attack": int(definition.get("attack_damage", 0)),
			"defense": 0,
			"speed": 0,
			"attack_speed": 1.0 / action_interval,
			"crit_rate": 0.0,
			"crit_damage": 0.0,
		},
		"equipped_skill_ids": [],
		"ultimate_id": String(ultimate.get("ultimate_id", "")),
		"battle_visual_id": PROTOTYPE_CHARACTER_PREFIX + String(character_id),
		"injury_state": "prototype_untracked",
	}


static func _failure(message: String) -> Dictionary:
	return {
		"ok": false,
		"errors": PackedStringArray([message]),
		"value": {},
	}

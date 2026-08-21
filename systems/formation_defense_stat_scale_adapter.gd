class_name FormationDefenseStatScaleAdapter
extends RefCounted

const PrototypeConfig := preload(
	"res://prototype/formation_defense/data/formation_defense_config.gd"
)

const FORMAL_REFERENCE_SOURCE := (
	"CharacterDatabase._build_characters 当前四职业基础战斗属性（V2接口参考快照）"
)

# V1 attack_speed is an ordering-scale attribute, not attacks per second. V2
# therefore maps its ratio against the profession reference onto the frozen V2
# interval. Ratios above one use a C1-continuous saturating curve: the derivative
# is one on both sides of the reference point, then decreases toward a maximum
# 3x frequency. The absolute interval floor is only a final runtime safety net.
const ACTION_FREQUENCY_REFERENCE_RATIO := 1.0
const ACTION_FREQUENCY_MAX_MULTIPLIER := 3.0
const ACTION_FREQUENCY_HIGH_RATIO_HALF_SATURATION := 2.0
const ACTION_INTERVAL_SAFETY_FLOOR_SECONDS := 0.20

# CharacterDatabase currently exposes definitions by character ID rather than a
# profession-reference API. These profession-keyed values mirror the four formal
# base definitions and are used only to convert between the V1 and V2 scales.
const FORMAL_REFERENCE_STATS := {
	&"guard": {
		"max_hp": 40.0,
		"attack": 6.0,
		"attack_speed": 3.0,
	},
	&"ranger": {
		"max_hp": 26.0,
		"attack": 8.0,
		"attack_speed": 7.0,
	},
	&"mage": {
		"max_hp": 22.0,
		"attack": 7.0,
		"attack_speed": 5.0,
	},
	&"healer": {
		"max_hp": 24.0,
		"attack": 4.0,
		"attack_speed": 6.0,
	},
}


static func get_formal_reference(profession_id: StringName) -> Dictionary:
	return FORMAL_REFERENCE_STATS.get(profession_id, {}).duplicate(true)


static func get_v2_baseline(v2_role_id: StringName) -> Dictionary:
	var definition := PrototypeConfig.get_character_definition(v2_role_id)
	if definition.is_empty():
		return {}
	var is_healer := v2_role_id == &"doctor"
	return {
		"max_health": float(definition.get("max_health", 0.0)),
		"attack_or_heal": float(definition.get(
			"heal_amount" if is_healer else "attack_damage",
			0.0
		)),
		"action_interval": float(definition.get("action_interval", 0.0)),
	}


static func map_action_frequency(
	formal_attack_speed: float,
	reference_attack_speed: float,
	baseline_action_interval: float
) -> Dictionary:
	if not _is_finite_positive(formal_attack_speed):
		return _failure("正式角色攻速必须为有限正数")
	if not _is_finite_positive(reference_attack_speed):
		return _failure("正式职业参考攻速必须为有限正数")
	if not _is_finite_positive(baseline_action_interval):
		return _failure("冻结V2职业基准间隔必须为有限正数")
	var raw_ratio := formal_attack_speed / reference_attack_speed
	if not _is_finite_positive(raw_ratio):
		return _failure("正式攻速比例必须为有限正数")
	var frequency_multiplier := raw_ratio
	if raw_ratio > ACTION_FREQUENCY_REFERENCE_RATIO:
		var excess_ratio := raw_ratio - ACTION_FREQUENCY_REFERENCE_RATIO
		var maximum_gain := ACTION_FREQUENCY_MAX_MULTIPLIER \
			- ACTION_FREQUENCY_REFERENCE_RATIO
		frequency_multiplier = ACTION_FREQUENCY_REFERENCE_RATIO \
			+ maximum_gain * excess_ratio / (
				ACTION_FREQUENCY_HIGH_RATIO_HALF_SATURATION + excess_ratio
			)
	if not _is_finite_positive(frequency_multiplier):
		return _failure("递减收益曲线产生无效行动频率倍率")
	var unclamped_interval := baseline_action_interval / frequency_multiplier
	if not _is_finite_positive(unclamped_interval):
		return _failure("行动频率映射产生无效V2行动间隔")
	var safety_floor_applied := (
		unclamped_interval < ACTION_INTERVAL_SAFETY_FLOOR_SECONDS
	)
	var final_interval := maxf(
		ACTION_INTERVAL_SAFETY_FLOOR_SECONDS,
		unclamped_interval
	)
	return {
		"ok": true,
		"errors": PackedStringArray(),
		"value": {
			"formal_attack_speed": formal_attack_speed,
			"reference_attack_speed": reference_attack_speed,
			"raw_ratio": raw_ratio,
			"curved_frequency_multiplier": frequency_multiplier,
			"unclamped_action_interval": unclamped_interval,
			"final_action_interval": final_interval,
			"safety_floor_seconds": ACTION_INTERVAL_SAFETY_FLOOR_SECONDS,
			"safety_floor_applied": safety_floor_applied,
		},
	}


static func adapt_final_stats(
	character_id: StringName,
	profession_id: StringName,
	v2_role_id: StringName,
	formal_final_stats: Dictionary,
	action_range: float
) -> Dictionary:
	var validation_error := _validate_formal_final_stats(
		formal_final_stats,
		character_id
	)
	if not validation_error.is_empty():
		return _failure(validation_error)
	var reference := get_formal_reference(profession_id)
	if reference.is_empty():
		return _failure(
			"缺少正式职业参考属性：%s" % String(profession_id)
		)
	var reference_error := _validate_positive_scale_values(
		reference,
		"正式职业参考属性.%s" % String(profession_id)
	)
	if not reference_error.is_empty():
		return _failure(reference_error)
	var v2_baseline := get_v2_baseline(v2_role_id)
	if v2_baseline.is_empty():
		return _failure("缺少冻结V2职业基准：%s" % String(v2_role_id))
	var baseline_error := _validate_positive_scale_values(
		{
			"max_hp": v2_baseline.get("max_health", 0.0),
			"attack": v2_baseline.get("attack_or_heal", 0.0),
			"attack_speed": 1.0 / float(
				v2_baseline.get("action_interval", 0.0)
			) if float(v2_baseline.get("action_interval", 0.0)) > 0.0 else -1.0,
		},
		"冻结V2职业基准.%s" % String(v2_role_id)
	)
	if not baseline_error.is_empty():
		return _failure(baseline_error)

	var hp_ratio := float(formal_final_stats["max_hp"]) \
		/ float(reference["max_hp"])
	var attack_ratio := float(formal_final_stats["attack"]) \
		/ float(reference["attack"])
	var speed_ratio := float(formal_final_stats["attack_speed"]) \
		/ float(reference["attack_speed"])
	var runtime_hp_exact := float(v2_baseline["max_health"]) * hp_ratio
	var runtime_effect_exact := float(v2_baseline["attack_or_heal"]) \
		* attack_ratio
	var frequency_mapping := map_action_frequency(
		float(formal_final_stats["attack_speed"]),
		float(reference["attack_speed"]),
		float(v2_baseline["action_interval"])
	)
	if not bool(frequency_mapping.get("ok", false)):
		return _failure("行动频率映射失败：%s" % "; ".join(
			frequency_mapping.get("errors", PackedStringArray())
		))
	var frequency_value: Dictionary = frequency_mapping.get("value", {})
	var runtime_interval := float(frequency_value.get(
		"final_action_interval", 0.0
	))
	if not _is_finite_positive(runtime_hp_exact):
		return _failure("尺度转换产生无效V2最大生命：%s" % String(character_id))
	if not _is_finite_nonnegative(runtime_effect_exact):
		return _failure("尺度转换产生无效V2攻击/治疗：%s" % String(character_id))
	if not _is_finite_positive(runtime_interval):
		return _failure("尺度转换产生无效V2攻击间隔：%s" % String(character_id))
	if not _is_finite_nonnegative(action_range):
		return _failure("V2职业攻击范围无效：%s" % String(character_id))

	# The current V2 damage/health runtime is integer-based. Round exactly once at
	# this boundary; ratios and interval remain deterministic floating-point data.
	var runtime_max_hp := roundi(runtime_hp_exact)
	var runtime_effect := roundi(runtime_effect_exact)
	if runtime_max_hp <= 0:
		return _failure("尺度转换后的V2最大生命必须为正数：%s" % String(character_id))
	if runtime_effect < 0:
		return _failure("尺度转换后的V2攻击/治疗不得为负：%s" % String(character_id))
	var v2_ready_stats := {
		"max_hp": runtime_max_hp,
		"attack": runtime_effect,
		"defense": int(formal_final_stats.get("defense", 0)),
		"speed": int(formal_final_stats.get("speed", 0)),
		"attack_speed": 1.0 / runtime_interval,
		"crit_rate": float(formal_final_stats.get("crit_rate", 0.0)),
		"crit_damage": float(formal_final_stats.get("crit_damage", 1.5)),
	}
	var report := {
		"character_id": String(character_id),
		"profession_id": String(profession_id),
		"formal_reference_source": FORMAL_REFERENCE_SOURCE,
		"formal_final_stats": formal_final_stats.duplicate(true),
		"formal_reference_stats": reference.duplicate(true),
		"ratios": {
			"max_hp": hp_ratio,
			"attack": attack_ratio,
			"attack_speed": speed_ratio,
		},
		"action_frequency_mapping": frequency_value.duplicate(true),
		"v2_baseline_stats": v2_baseline.duplicate(true),
		"v2_runtime_stats": {
			"max_health": runtime_max_hp,
			"attack_or_heal": runtime_effect,
			"action_interval": runtime_interval,
			"action_range": action_range,
		},
	}
	return {
		"ok": true,
		"errors": PackedStringArray(),
		"value": {
			"final_stats": v2_ready_stats,
			"report": report,
		},
	}


static func _validate_formal_final_stats(
	formal_final_stats: Dictionary,
	character_id: StringName
) -> String:
	for stat_id: String in [
		"max_hp", "attack", "defense", "speed", "attack_speed",
		"crit_rate", "crit_damage",
	]:
		var value = formal_final_stats.get(stat_id)
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
			return "正式角色最终属性缺失或非数值：%s.%s" % [
				character_id, stat_id,
			]
		if not _is_finite(float(value)):
			return "正式角色最终属性不是有限数值：%s.%s" % [
				character_id, stat_id,
			]
	if float(formal_final_stats.get("max_hp", 0.0)) <= 0.0:
		return "正式角色最大生命必须为正数：%s" % String(character_id)
	if float(formal_final_stats.get("attack", -1.0)) < 0.0:
		return "正式角色攻击/治疗基础值不得为负：%s" % String(character_id)
	if float(formal_final_stats.get("attack_speed", 0.0)) <= 0.0:
		return "正式角色攻速必须为正数：%s" % String(character_id)
	return ""


static func _validate_positive_scale_values(values: Dictionary, path: String) -> String:
	for key: String in ["max_hp", "attack", "attack_speed"]:
		var numeric := float(values.get(key, -1.0))
		if not _is_finite_positive(numeric):
			return "%s.%s必须为有限正数" % [path, key]
	return ""


static func _is_finite(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)


static func _is_finite_positive(value: float) -> bool:
	return _is_finite(value) and value > 0.0


static func _is_finite_nonnegative(value: float) -> bool:
	return _is_finite(value) and value >= 0.0


static func _failure(message: String) -> Dictionary:
	return {
		"ok": false,
		"errors": PackedStringArray([message]),
		"value": {},
	}

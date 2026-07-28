class_name CombatStats
extends Resource

const Stage12Config := preload("res://scripts/data/stage12_balance_config.gd")

@export var max_hp: int = 0
@export var attack: int = 0
@export var defense: int = 0
@export var speed: int = 0
@export var attack_speed: float = 0.0
@export var crit_rate: float = 0.0
@export var crit_damage: float = 1.5


func setup(
	p_max_hp: int,
	p_attack: int,
	p_defense: int,
	p_speed: int,
	p_attack_speed: float = -1.0,
	p_crit_rate: float = 0.0,
	p_crit_damage: float = 1.5
) -> CombatStats:
	max_hp = p_max_hp
	attack = p_attack
	defense = p_defense
	speed = p_speed
	attack_speed = float(p_speed) if p_attack_speed < 0.0 else p_attack_speed
	crit_rate = clampf(
		p_crit_rate,
		Stage12Config.COMBAT_CRIT_RATE_MIN,
		Stage12Config.COMBAT_CRIT_RATE_MAX
	)
	# CombatStats is also used for per-level deltas, where zero crit damage is valid.
	crit_damage = clampf(
		p_crit_damage,
		Stage12Config.COMBAT_CRIT_DAMAGE_MIN,
		Stage12Config.COMBAT_CRIT_DAMAGE_MAX
	)
	return self


func to_dictionary() -> Dictionary:
	return {
		"max_hp": max_hp,
		"attack": attack,
		"defense": defense,
		"speed": speed,
		"attack_speed": attack_speed,
		"crit_rate": crit_rate,
		"crit_damage": crit_damage,
	}


static func from_dictionary(data: Dictionary) -> CombatStats:
	var parsed_speed := int(data.get("speed", roundi(float(data.get("attack_speed", 0.0)))))
	return CombatStats.new().setup(
		max(0, int(data.get("max_hp", 0))),
		int(data.get("attack", 0)),
		int(data.get("defense", 0)),
		parsed_speed,
		float(data.get("attack_speed", parsed_speed)),
		float(data.get("crit_rate", 0.0)),
		float(data.get("crit_damage", 1.5))
	)

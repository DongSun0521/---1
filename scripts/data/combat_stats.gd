class_name CombatStats
extends Resource

@export var max_hp: int = 0
@export var attack: int = 0
@export var defense: int = 0
@export var speed: int = 0


func setup(p_max_hp: int, p_attack: int, p_defense: int, p_speed: int):
	max_hp = p_max_hp
	attack = p_attack
	defense = p_defense
	speed = p_speed
	return self


func to_dictionary() -> Dictionary:
	return {
		"max_hp": max_hp,
		"attack": attack,
		"defense": defense,
		"speed": speed,
	}

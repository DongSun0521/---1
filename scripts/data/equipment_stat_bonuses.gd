class_name EquipmentStatBonuses
extends Resource

@export var attack: int = 0
@export var defense: int = 0
@export var max_hp: int = 0
@export var speed: int = 0


func setup(p_attack: int = 0, p_defense: int = 0, p_max_hp: int = 0, p_speed: int = 0):
	attack = p_attack
	defense = p_defense
	max_hp = p_max_hp
	speed = p_speed
	return self


func to_dictionary() -> Dictionary:
	return {
		"attack": attack,
		"defense": defense,
		"max_hp": max_hp,
		"speed": speed,
	}

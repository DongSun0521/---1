class_name CharacterRuntimeState
extends RefCounted

var character_id: StringName
var current_hp: int = 0
var equipped_weapon_id: StringName = &""
var equipped_armor_id: StringName = &""
var equipped_weapon_instance_id: StringName = &""
var equipped_armor_instance_id: StringName = &""
var injury_state: StringName = &"healthy"


func setup(
	p_character_id: StringName,
	p_current_hp: int,
	p_equipped_weapon_id: StringName = &"",
	p_equipped_armor_id: StringName = &"",
	p_equipped_weapon_instance_id: StringName = &"",
	p_equipped_armor_instance_id: StringName = &"",
	p_injury_state: StringName = &"healthy"
):
	character_id = p_character_id
	current_hp = p_current_hp
	equipped_weapon_id = p_equipped_weapon_id
	equipped_armor_id = p_equipped_armor_id
	equipped_weapon_instance_id = p_equipped_weapon_instance_id
	equipped_armor_instance_id = p_equipped_armor_instance_id
	injury_state = p_injury_state
	return self


func to_dictionary() -> Dictionary:
	return {
		"character_id": character_id,
		"current_hp": current_hp,
		"equipped_weapon_id": equipped_weapon_id,
		"equipped_armor_id": equipped_armor_id,
		"equipped_weapon_instance_id": equipped_weapon_instance_id,
		"equipped_armor_instance_id": equipped_armor_instance_id,
		"injury_state": injury_state,
	}


static func from_dictionary(data: Dictionary) -> CharacterRuntimeState:
	return CharacterRuntimeState.new().setup(
		StringName(data.get("character_id", &"")),
		max(0, int(data.get("current_hp", 0))),
		StringName(data.get("equipped_weapon_id", &"")),
		StringName(data.get("equipped_armor_id", &"")),
		StringName(data.get("equipped_weapon_instance_id", &"")),
		StringName(data.get("equipped_armor_instance_id", &"")),
		StringName(data.get("injury_state", &"healthy"))
	)

class_name CharacterRuntimeState
extends RefCounted

var character_id: StringName
var current_hp: int = 0
var equipped_weapon_id: StringName = &""
var equipped_armor_id: StringName = &""
var equipped_weapon_instance_id: StringName = &""
var equipped_armor_instance_id: StringName = &""


func setup(
	p_character_id: StringName,
	p_current_hp: int,
	p_equipped_weapon_id: StringName = &"",
	p_equipped_armor_id: StringName = &"",
	p_equipped_weapon_instance_id: StringName = &"",
	p_equipped_armor_instance_id: StringName = &""
):
	character_id = p_character_id
	current_hp = p_current_hp
	equipped_weapon_id = p_equipped_weapon_id
	equipped_armor_id = p_equipped_armor_id
	equipped_weapon_instance_id = p_equipped_weapon_instance_id
	equipped_armor_instance_id = p_equipped_armor_instance_id
	return self


func to_dictionary() -> Dictionary:
	return {
		"character_id": character_id,
		"current_hp": current_hp,
		"equipped_weapon_id": equipped_weapon_id,
		"equipped_armor_id": equipped_armor_id,
		"equipped_weapon_instance_id": equipped_weapon_instance_id,
		"equipped_armor_instance_id": equipped_armor_instance_id,
	}

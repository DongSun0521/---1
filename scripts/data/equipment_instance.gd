class_name EquipmentInstance
extends RefCounted

var instance_id: StringName
var equipment_id: StringName


func setup(p_instance_id: StringName, p_equipment_id: StringName):
	instance_id = p_instance_id
	equipment_id = p_equipment_id
	return self


func to_dictionary() -> Dictionary:
	return {
		"instance_id": instance_id,
		"equipment_id": equipment_id,
	}

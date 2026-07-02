class_name EquipmentDefinition
extends Resource

@export var equipment_id: StringName
@export var display_name: String
@export var description: String
@export var slot_type: StringName
@export var allowed_professions: Array[StringName] = []
@export var rarity: StringName = &"common"
@export var icon: Texture2D
@export var stat_bonuses: Resource
@export var affixes: Array[Resource] = []
@export var flavor_text: String
@export var vendor_price: int = 0
@export var item_power: int = 0
@export var set_text: String = ""


func setup(
	p_equipment_id: StringName,
	p_display_name: String,
	p_description: String,
	p_slot_type: StringName,
	p_allowed_professions: Array[StringName],
	p_rarity: StringName,
	p_stat_bonuses: Resource,
	p_affixes: Array[Resource] = [],
	p_flavor_text: String = "",
	p_vendor_price: int = 0,
	p_item_power: int = 0,
	p_set_text: String = ""
):
	equipment_id = p_equipment_id
	display_name = p_display_name
	description = p_description
	slot_type = p_slot_type
	allowed_professions = p_allowed_professions.duplicate()
	rarity = p_rarity
	stat_bonuses = p_stat_bonuses
	affixes = p_affixes.duplicate()
	flavor_text = p_flavor_text
	vendor_price = p_vendor_price
	item_power = p_item_power
	set_text = p_set_text
	return self


func to_dictionary() -> Dictionary:
	var affix_data: Array = []
	for affix in affixes:
		if affix != null and affix.has_method("to_dictionary"):
			affix_data.append(affix.to_dictionary())
	return {
		"equipment_id": equipment_id,
		"display_name": display_name,
		"description": description,
		"slot_type": slot_type,
		"allowed_professions": allowed_professions.duplicate(),
		"rarity": rarity,
		"stat_bonuses": stat_bonuses.to_dictionary() if stat_bonuses != null else {},
		"affixes": affix_data,
		"flavor_text": flavor_text,
		"vendor_price": vendor_price,
		"item_power": item_power,
		"set_text": set_text,
	}

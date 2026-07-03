class_name CropData
extends Resource

@export var crop_id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var growth_days: int = 1
@export var output_resource_id: StringName
@export var output_amount: int = 0
@export var icon: Texture2D


func setup(
	p_crop_id: StringName,
	p_display_name: String,
	p_description: String,
	p_growth_days: int,
	p_output_resource_id: StringName,
	p_output_amount: int,
	p_icon: Texture2D = null
) -> CropData:
	crop_id = p_crop_id
	display_name = p_display_name
	description = p_description
	growth_days = max(1, p_growth_days)
	output_resource_id = p_output_resource_id
	output_amount = max(0, p_output_amount)
	icon = p_icon
	return self

class_name BuildingData
extends RefCounted

var building_id: StringName
var display_name: String
var description: String
var max_level: int = 4
var sheet_path: String
var level_regions: Array[Rect2] = []
var display_scale: Vector2 = Vector2.ONE
var visual_offset: Vector2 = Vector2.ZERO
var title_offset: Vector2 = Vector2(0, -150)
var click_area_size: Vector2 = Vector2(210, 150)
var click_area_offset: Vector2 = Vector2.ZERO
var operation_type: StringName = &"info"
var is_function_unlocked: bool = false
var village_position: Vector2 = Vector2.ZERO


func setup(
	p_building_id: StringName,
	p_display_name: String,
	p_description: String,
	p_sheet_path: String,
	p_village_position: Vector2,
	p_display_scale: Vector2,
	p_visual_offset: Vector2,
	p_title_offset: Vector2,
	p_click_area_size: Vector2,
	p_click_area_offset: Vector2,
	p_operation_type: StringName,
	p_is_function_unlocked: bool
) -> BuildingData:
	building_id = p_building_id
	display_name = p_display_name
	description = p_description
	sheet_path = p_sheet_path
	village_position = p_village_position
	display_scale = p_display_scale
	visual_offset = p_visual_offset
	title_offset = p_title_offset
	click_area_size = p_click_area_size
	click_area_offset = p_click_area_offset
	operation_type = p_operation_type
	is_function_unlocked = p_is_function_unlocked
	level_regions = [
		Rect2(0, 0, 512, 512),
		Rect2(512, 0, 512, 512),
		Rect2(1024, 0, 512, 512),
		Rect2(1536, 0, 512, 512),
	]
	return self


func get_level_region(level: int) -> Rect2:
	var index := clampi(level, 1, max_level) - 1
	return level_regions[index]

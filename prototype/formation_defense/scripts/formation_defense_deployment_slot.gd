extends Button

const SLOT_SIZE := Vector2(44.0, 44.0)

var slot_id: StringName = &""
var lane_id: StringName = &""
var column_id := 0
var normalized_position := Vector2.ZERO
var deployed_character_id: StringName = &""


func configure(slot_data: Dictionary, route_color: Color) -> void:
	slot_id = StringName(slot_data.get("slot_id", &""))
	lane_id = StringName(slot_data.get("lane_id", &""))
	column_id = int(slot_data.get("column_id", 0))
	normalized_position = slot_data.get("normalized_position", Vector2.ZERO)
	name = "DeploymentSlot_%s" % String(slot_id)
	custom_minimum_size = SLOT_SIZE
	size = SLOT_SIZE
	focus_mode = Control.FOCUS_NONE
	text = "＋"
	tooltip_text = "%s 第%d列｜空部署点" % [String(lane_id), column_id]
	add_theme_font_size_override("font_size", 18)
	add_theme_color_override("font_color", route_color.lightened(0.24))
	add_theme_color_override("font_hover_color", Color.WHITE)
	modulate = Color(1.0, 1.0, 1.0, 0.88)


func update_battlefield_position(battlefield_size: Vector2) -> void:
	position = Vector2(
		normalized_position.x * battlefield_size.x,
		normalized_position.y * battlefield_size.y
	) - SLOT_SIZE * 0.5


func set_deployed_character(
	character_id: StringName,
	display_name: String
) -> void:
	deployed_character_id = character_id
	text = display_name.left(1) if not display_name.is_empty() else "＋"
	tooltip_text = (
		"%s 第%d列｜%s" % [String(lane_id), column_id, display_name]
		if character_id != &""
		else "%s 第%d列｜空部署点" % [String(lane_id), column_id]
	)


func set_deployment_locked(locked: bool) -> void:
	disabled = locked


func get_slot_snapshot() -> Dictionary:
	return {
		"slot_id": slot_id,
		"lane_id": lane_id,
		"column_id": column_id,
		"normalized_position": normalized_position,
		"deployed_character_id": deployed_character_id,
	}

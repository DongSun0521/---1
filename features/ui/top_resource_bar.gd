extends PanelContainer

@onready var resource_label: Label = $Margin/ResourceLabel

var game_state


func _ready() -> void:
	game_state = get_node("/root/GameState")
	apply_visual_style()
	game_state.state_changed.connect(refresh)
	refresh()


func _exit_tree() -> void:
	if game_state != null and game_state.state_changed.is_connected(refresh):
		game_state.state_changed.disconnect(refresh)


func refresh() -> void:
	resource_label.text = game_state.get_resource_summary()


func apply_visual_style() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.09, 0.08, 0.82)
	panel_style.border_color = Color(0.86, 0.72, 0.42, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(0)
	add_theme_stylebox_override("panel", panel_style)

	resource_label.add_theme_font_size_override("font_size", 24)
	resource_label.add_theme_color_override("font_color", Color(0.96, 0.93, 0.82))

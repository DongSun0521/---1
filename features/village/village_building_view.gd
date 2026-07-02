class_name VillageBuildingView
extends Control

signal building_pressed(building_id: StringName)

const BUILDING_VISUAL_SCALE := 2.0
const INTERACTION_AREA_OFFSET := Vector2(0, 54)

var building_data
var building_state: Dictionary = {}
var building_texture: TextureRect
var hover_highlight: Panel
var name_label: Label
var level_label: Label
var status_label: Label
var click_button: Button
var is_hovered := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = size * 0.5


func setup(p_building_data, p_building_state: Dictionary) -> void:
	building_data = p_building_data
	building_state = p_building_state.duplicate(true)
	name = "%sBuildingView" % String(building_data.building_id).capitalize()
	custom_minimum_size = Vector2(500, 420)
	size = custom_minimum_size
	pivot_offset = size * 0.5
	_build_nodes()
	refresh(p_building_state)


func refresh(p_building_state: Dictionary) -> void:
	if building_data == null:
		return
	building_state = p_building_state.duplicate(true)
	var level := clampi(int(building_state.get("level", 1)), 1, int(building_data.max_level))
	building_texture.texture = _make_level_texture(level)
	name_label.text = String(building_data.display_name)
	level_label.text = "Lv.%d" % level
	status_label.text = _format_status_text()
	status_label.visible = _should_show_status()
	modulate = Color(0.82, 0.82, 0.82, 1.0) if StringName(building_state.get("work_state", &"idle")) == &"unavailable" else Color.WHITE
	_layout_nodes()


func _build_nodes() -> void:
	if building_texture != null:
		return

	building_texture = TextureRect.new()
	building_texture.name = "BuildingTexture"
	building_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	building_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	building_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(building_texture)

	hover_highlight = Panel.new()
	hover_highlight.name = "HoverHighlight"
	hover_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_highlight.visible = false
	hover_highlight.add_theme_stylebox_override("panel", _make_outline_style())
	add_child(hover_highlight)

	var title_container := PanelContainer.new()
	title_container.name = "TitleContainer"
	title_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_container.add_theme_stylebox_override("panel", _make_title_style())
	add_child(title_container)

	var title_margin := MarginContainer.new()
	title_margin.add_theme_constant_override("margin_left", 8)
	title_margin.add_theme_constant_override("margin_top", 3)
	title_margin.add_theme_constant_override("margin_right", 8)
	title_margin.add_theme_constant_override("margin_bottom", 3)
	title_container.add_child(title_margin)

	var title_box := HBoxContainer.new()
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	title_box.add_theme_constant_override("separation", 5)
	title_margin.add_child(title_box)

	name_label = _make_label(18, Color(1.0, 0.94, 0.72), HORIZONTAL_ALIGNMENT_CENTER)
	name_label.name = "NameLabel"
	title_box.add_child(name_label)

	level_label = _make_label(14, Color(0.85, 0.94, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	level_label.name = "LevelLabel"
	title_box.add_child(level_label)

	status_label = _make_label(14, Color(0.92, 0.95, 0.84), HORIZONTAL_ALIGNMENT_CENTER)
	status_label.name = "StatusMarker"
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status_label)

	click_button = Button.new()
	click_button.name = "ClickButton"
	click_button.text = ""
	click_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	click_button.flat = true
	click_button.focus_mode = Control.FOCUS_NONE
	click_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	click_button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	click_button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	click_button.mouse_entered.connect(_on_mouse_entered)
	click_button.mouse_exited.connect(_on_mouse_exited)
	click_button.button_down.connect(_on_button_down)
	click_button.button_up.connect(_on_button_up)
	click_button.pressed.connect(_on_pressed)
	add_child(click_button)


func _layout_nodes() -> void:
	var texture_size: Vector2 = Vector2(512, 512) * building_data.display_scale * BUILDING_VISUAL_SCALE
	var center: Vector2 = size * 0.5 + building_data.visual_offset * BUILDING_VISUAL_SCALE
	building_texture.position = center - texture_size * 0.5
	building_texture.size = texture_size
	var interaction_size: Vector2 = building_data.click_area_size * BUILDING_VISUAL_SCALE
	var interaction_position: Vector2 = center + building_data.click_area_offset * BUILDING_VISUAL_SCALE + INTERACTION_AREA_OFFSET - interaction_size * 0.5
	hover_highlight.position = interaction_position
	hover_highlight.size = interaction_size

	var title := get_node("TitleContainer") as Control
	title.size = Vector2(220, 30)
	title.position = center + building_data.title_offset * BUILDING_VISUAL_SCALE - title.size * 0.5
	status_label.size = Vector2(150, 22)
	status_label.position = center + Vector2(-75, 118)

	click_button.position = interaction_position
	click_button.size = interaction_size


func _make_level_texture(level: int) -> Texture2D:
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = load(building_data.sheet_path)
	atlas_texture.region = building_data.get_level_region(level)
	return atlas_texture


func _format_status_text() -> String:
	var work_state := StringName(building_state.get("work_state", &"idle"))
	match work_state:
		&"working":
			var progress := int(building_state.get("project_progress_days", 0))
			var required := int(building_state.get("project_required_days", 0))
			return "工作中 %d/%d" % [progress, required] if required > 0 else "工作中"
		&"completed":
			return "完成"
		&"unavailable":
			return "暂未开放"
		&"locked":
			return "未解锁"
	return "空闲"


func _should_show_status() -> bool:
	var work_state := StringName(building_state.get("work_state", &"idle"))
	return is_hovered or work_state == &"working" or work_state == &"completed"


func _on_mouse_entered() -> void:
	is_hovered = true
	scale = Vector2(1.045, 1.045)
	hover_highlight.visible = true
	status_label.visible = true
	name_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.82))


func _on_mouse_exited() -> void:
	is_hovered = false
	scale = Vector2.ONE
	hover_highlight.visible = false
	status_label.visible = _should_show_status()
	name_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.72))


func _on_button_down() -> void:
	scale = Vector2(0.985, 0.985)


func _on_button_up() -> void:
	scale = Vector2(1.045, 1.045) if is_hovered else Vector2.ONE


func _on_pressed() -> void:
	building_pressed.emit(building_data.building_id)


func _make_label(font_size: int, color: Color, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.88))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label


func _make_outline_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.84, 0.24, 0.08)
	style.border_color = Color(1.0, 0.84, 0.30, 0.92)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	return style


func _make_title_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(0)
	style.set_corner_radius_all(0)
	return style

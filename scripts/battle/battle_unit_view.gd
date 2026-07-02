class_name BattleUnitView
extends Control

signal unit_selected(unit_id: StringName)

var unit_id: StringName = &""
var visual_data: Dictionary = {}
var sprite: AnimatedSprite2D
var name_label: Label
var hp_bar: ProgressBar
var hp_label: Label
var status_label: Label
var click_button: Button
var highlight: PanelContainer
var float_layer: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(unit: Dictionary, frames: SpriteFrames, visual: Dictionary) -> void:
	unit_id = unit.get("unit_id", &"")
	visual_data = visual.duplicate(true)
	custom_minimum_size = visual.get("click_area", Vector2(180, 240))
	size = custom_minimum_size

	if sprite == null:
		build_nodes()

	sprite.sprite_frames = frames
	sprite.centered = true
	sprite.scale = visual.get("scale", Vector2.ONE)
	sprite.offset = visual.get("offset", Vector2.ZERO)
	sprite.flip_h = bool(visual.get("flip_h", false))
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"idle"):
		sprite.play(&"idle")
	update_state(unit, false)


func build_nodes() -> void:
	var shadow := PanelContainer.new()
	shadow.name = "Shadow"
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.position = Vector2(20, size.y - 44)
	shadow.size = Vector2(max(90.0, size.x - 40.0), 24)
	shadow.add_theme_stylebox_override("panel", make_panel_style(Color(0, 0, 0, 0.26), Color(0, 0, 0, 0)))
	add_child(shadow)

	sprite = AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	sprite.position = size * 0.5
	add_child(sprite)

	highlight = PanelContainer.new()
	highlight.name = "SelectionHighlight"
	highlight.visible = false
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	highlight.set_anchors_preset(Control.PRESET_FULL_RECT)
	highlight.add_theme_stylebox_override("panel", make_panel_style(Color(1.0, 0.82, 0.22, 0.10), Color(1.0, 0.82, 0.24, 0.96), 3))
	add_child(highlight)

	name_label = create_label("", 18, Color(1.0, 0.95, 0.78), HORIZONTAL_ALIGNMENT_CENTER)
	name_label.position = Vector2(-30, -66)
	name_label.size = Vector2(size.x + 60, 24)
	add_child(name_label)

	hp_bar = ProgressBar.new()
	hp_bar.show_percentage = false
	hp_bar.position = Vector2(-18, -38)
	hp_bar.size = Vector2(size.x + 36, 14)
	add_child(hp_bar)

	hp_label = create_label("", 13, Color(0.98, 0.97, 0.88), HORIZONTAL_ALIGNMENT_CENTER)
	hp_label.position = Vector2(-18, -26)
	hp_label.size = Vector2(size.x + 36, 18)
	add_child(hp_label)

	status_label = create_label("", 16, Color(0.62, 0.88, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	status_label.position = Vector2(-22, size.y - 24)
	status_label.size = Vector2(size.x + 44, 22)
	add_child(status_label)

	float_layer = Control.new()
	float_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	float_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(float_layer)

	click_button = Button.new()
	click_button.name = "ClickArea"
	click_button.flat = true
	click_button.focus_mode = Control.FOCUS_NONE
	click_button.modulate = Color(1, 1, 1, 0.0)
	click_button.set_anchors_preset(Control.PRESET_FULL_RECT)
	click_button.mouse_entered.connect(set_highlight.bind(true))
	click_button.mouse_exited.connect(set_highlight.bind(false))
	click_button.pressed.connect(func() -> void: unit_selected.emit(unit_id))
	add_child(click_button)


func update_state(unit: Dictionary, play_death: bool = true) -> void:
	unit_id = StringName(unit.get("unit_id", unit_id))
	name_label.text = String(unit.get("display_name", ""))
	var max_hp: int = max(1, int(unit.get("max_hp", 1)))
	var current_hp: int = clampi(int(unit.get("current_hp", 0)), 0, max_hp)
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp
	hp_label.text = "%d/%d" % [current_hp, max_hp]
	status_label.text = "防御" if bool(unit.get("is_defending", false)) and current_hp > 0 else ""
	click_button.disabled = current_hp <= 0
	modulate = Color(0.68, 0.68, 0.68, 1.0) if current_hp <= 0 else Color.WHITE
	if current_hp <= 0 and play_death:
		play_death_hold()
	elif current_hp > 0 and sprite.animation == &"death":
		play_idle()


func set_targetable(is_targetable: bool) -> void:
	click_button.disabled = not is_targetable
	highlight.visible = is_targetable


func set_highlight(is_visible: bool) -> void:
	if not click_button.disabled:
		highlight.visible = is_visible


func play_idle() -> void:
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"idle"):
		sprite.play(&"idle")


func play_death_hold() -> void:
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(&"death"):
		return
	sprite.play(&"death")


func play_once(animation: StringName) -> void:
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(animation):
		return
	sprite.play(animation)
	if not sprite.sprite_frames.get_animation_loop(animation):
		await sprite.animation_finished


func play_hit_or_death(is_defeated: bool) -> void:
	if is_defeated:
		await play_once(&"death")
	else:
		await play_once(&"hit")
		play_idle()


func show_float_text(text: String, color: Color) -> void:
	var label := create_label(text, 24, color, HORIZONTAL_ALIGNMENT_CENTER)
	label.position = Vector2(0, -72)
	label.size = Vector2(size.x, 34)
	float_layer.add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position", label.position + Vector2(0, -54), 0.55)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.55)
	tween.tween_callback(label.queue_free)


func create_label(text: String, font_size: int, color: Color, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func make_panel_style(bg_color: Color, border_color: Color, border_width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(8)
	return style

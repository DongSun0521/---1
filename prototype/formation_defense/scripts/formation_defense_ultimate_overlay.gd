extends Control

var preview: Dictionary = {}
var effects: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	queue_redraw()


func set_preview(new_preview: Dictionary) -> void:
	preview = new_preview.duplicate(true)
	queue_redraw()


func clear_preview() -> void:
	preview.clear()
	queue_redraw()


func spawn_effect(
	ultimate_id: StringName,
	center: Vector2,
	outline_points: PackedVector2Array,
	color: Color,
	duration := 0.45
) -> void:
	effects.append({
		"ultimate_id": ultimate_id,
		"center": center,
		"outline_points": outline_points.duplicate(),
		"color": color,
		"duration": maxf(0.05, duration),
		"elapsed": 0.0,
	})
	queue_redraw()


func advance(delta: float) -> void:
	var safe_delta := maxf(0.0, delta)
	var next_effects: Array[Dictionary] = []
	for effect: Dictionary in effects:
		effect["elapsed"] = float(effect.get("elapsed", 0.0)) + safe_delta
		if float(effect.elapsed) < float(effect.duration):
			next_effects.append(effect)
	effects = next_effects
	if not effects.is_empty():
		queue_redraw()


func clear_all() -> void:
	preview.clear()
	effects.clear()
	queue_redraw()


func get_debug_snapshot() -> Dictionary:
	return {
		"preview_visible": not preview.is_empty(),
		"preview": preview.duplicate(true),
		"effect_count": effects.size(),
	}


func _draw() -> void:
	if not preview.is_empty():
		draw_preview()
	for effect: Dictionary in effects:
		draw_effect(effect)


func draw_preview() -> void:
	var valid := bool(preview.get("valid", false))
	var base_color: Color = preview.get(
		"color",
		Color(0.72, 0.82, 1.0, 0.9)
	)
	var display_color := base_color if valid else Color(0.95, 0.32, 0.34, 0.88)
	var cast_points: PackedVector2Array = preview.get(
		"cast_points",
		PackedVector2Array()
	)
	var cast_polygon: PackedVector2Array = preview.get(
		"cast_polygon",
		PackedVector2Array()
	)
	var area_points: PackedVector2Array = preview.get(
		"area_points",
		PackedVector2Array()
	)
	if cast_points.size() >= 3:
		draw_polyline(cast_points, Color(display_color, 0.48), 2.0, true)
	if cast_polygon.size() >= 4:
		var fill_polygon := PackedVector2Array()
		for index in range(cast_polygon.size() - 1):
			fill_polygon.append(cast_polygon[index])
		draw_colored_polygon(fill_polygon, Color(display_color, 0.045))
		draw_polyline(cast_polygon, Color(display_color, 0.34), 2.0, true)
	if area_points.size() >= 3:
		draw_colored_polygon(area_points, Color(display_color, 0.10))
		draw_polyline(area_points, display_color, 3.0, true)
	var origin: Vector2 = preview.get("origin", Vector2.ZERO)
	var target: Vector2 = preview.get("target", origin)
	if bool(preview.get("draw_line", false)):
		draw_line(origin, target, display_color, 3.0, true)
	draw_circle(target, 7.0, Color(display_color, 0.22))
	draw_arc(target, 13.0, 0.0, TAU, 28, display_color, 2.5, true)


func draw_effect(effect: Dictionary) -> void:
	var duration := maxf(0.05, float(effect.get("duration", 0.45)))
	var progress := clampf(float(effect.get("elapsed", 0.0)) / duration, 0.0, 1.0)
	var center: Vector2 = effect.get("center", Vector2.ZERO)
	var source_points: PackedVector2Array = effect.get(
		"outline_points",
		PackedVector2Array()
	)
	var expanded := PackedVector2Array()
	for point: Vector2 in source_points:
		expanded.append(center.lerp(point, 0.35 + progress * 0.65))
	var color: Color = effect.get("color", Color.WHITE)
	color.a = (1.0 - progress) * 0.92
	if expanded.size() >= 3:
		draw_colored_polygon(expanded, Color(color, color.a * 0.12))
		draw_polyline(expanded, color, 4.0 - progress * 2.0, true)
	else:
		draw_circle(center, 10.0 + progress * 24.0, Color(color, color.a * 0.18))
		draw_arc(
			center,
			10.0 + progress * 24.0,
			0.0,
			TAU,
			28,
			color,
			3.0,
			true
		)

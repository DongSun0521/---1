extends Control

const PrototypeConfig := preload(
	"res://prototype/formation_defense/data/formation_defense_config.gd"
)
const TRACK_WIDTH := 9.0
const DOT_SPACING := 44.0
var active_spawn_point_ids: Array[StringName] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	draw_formation_zones()
	for route_id: StringName in get_visible_route_ids():
		var points := PrototypeConfig.get_route_points(route_id, size)
		if points.size() < 2:
			continue
		var route_color := PrototypeConfig.get_route_color(route_id)
		draw_polyline(points, Color(route_color, 0.22), TRACK_WIDTH, true)
		draw_polyline(points, Color(route_color, 0.52), 2.0, true)
		draw_route_dots(points, Color(route_color, 0.82))
	draw_spawn_points()
	var entrance := PrototypeConfig.get_village_entrance_point(size)
	draw_circle(entrance, 21.0, Color(0.35, 0.92, 0.58, 0.16))
	draw_arc(
		entrance,
		21.0,
		0.0,
		TAU,
		32,
		Color(0.45, 1.0, 0.68, 0.7),
		2.0,
		true
	)


func set_active_spawn_point_ids(new_ids: Array[StringName]) -> void:
	active_spawn_point_ids = new_ids.duplicate()
	queue_redraw()


func draw_formation_zones() -> void:
	for zone: Dictionary in PrototypeConfig.get_formation_zones(size):
		var rect: Rect2 = zone.get("rect", Rect2())
		var color: Color = zone.get("color", Color(1.0, 1.0, 1.0, 0.08))
		draw_rect(rect, color, true)
		draw_rect(rect, Color(color, minf(0.48, color.a + 0.28)), false, 1.5)
		draw_string(
			ThemeDB.fallback_font,
			rect.position + Vector2(8.0, 22.0),
			String(zone.get("display_name", "")),
			HORIZONTAL_ALIGNMENT_LEFT,
			maxf(80.0, rect.size.x - 16.0),
			14,
			Color(0.84, 0.90, 0.98, 0.82)
		)


func draw_spawn_points() -> void:
	if active_spawn_point_ids.is_empty():
		return
	for spawn_point: Dictionary in PrototypeConfig.get_spawn_points():
		var spawn_point_id := StringName(
			spawn_point.get("spawn_point_id", &"")
		)
		var point := PrototypeConfig.get_spawn_point_position(
			spawn_point_id,
			size
		)
		var active := active_spawn_point_ids.has(spawn_point_id)
		if not active:
			continue
		var route_id := StringName(spawn_point.get("route_id", &""))
		var formation_route_index := int(
			spawn_point.get(
				"formation_route_index",
				PrototypeConfig.get_formation_route_index(route_id)
			)
		)
		var color := (
			Color(1.0, 0.36, 0.36, 0.95)
			if active else Color(0.55, 0.61, 0.70, 0.42)
		)
		draw_circle(point, 9.0 if active else 6.0, color)
		draw_arc(point, 14.0, 0.0, TAU, 24, Color(color, 0.75), 2.0, true)
		draw_string(
			ThemeDB.fallback_font,
			point + Vector2(-70.0, -17.0),
			"%s · %s[%d]" % [
				String(spawn_point.get("display_name", spawn_point_id)),
				String(route_id),
				formation_route_index,
			],
			HORIZONTAL_ALIGNMENT_CENTER,
			140.0,
			12,
			color
		)


func get_visible_route_ids() -> Array[StringName]:
	if active_spawn_point_ids.is_empty():
		return PrototypeConfig.get_route_ids()
	var result: Array[StringName] = []
	for spawn_point_id: StringName in active_spawn_point_ids:
		var spawn_point := PrototypeConfig.get_spawn_point(spawn_point_id)
		var route_id := StringName(spawn_point.get("route_id", &""))
		if route_id != &"" and not result.has(route_id):
			result.append(route_id)
	return result


func draw_route_dots(points: PackedVector2Array, color: Color) -> void:
	for index in range(points.size() - 1):
		var start := points[index]
		var finish := points[index + 1]
		var segment_length := start.distance_to(finish)
		var dot_count := maxi(1, int(floor(segment_length / DOT_SPACING)))
		for dot_index in range(dot_count):
			var progress := float(dot_index) / float(dot_count)
			draw_circle(start.lerp(finish, progress), 3.5, color)

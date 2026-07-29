extends Control

const PrototypeConfig := preload(
	"res://prototype/formation_defense/data/formation_defense_config.gd"
)
const TRACK_WIDTH := 9.0
const DOT_SPACING := 44.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	for route_id: StringName in PrototypeConfig.get_route_ids():
		var points := PrototypeConfig.get_route_points(route_id, size)
		if points.size() < 2:
			continue
		var route_color := PrototypeConfig.get_route_color(route_id)
		draw_polyline(points, Color(route_color, 0.22), TRACK_WIDTH, true)
		draw_polyline(points, Color(route_color, 0.52), 2.0, true)
		draw_route_dots(points, Color(route_color, 0.82))
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


func draw_route_dots(points: PackedVector2Array, color: Color) -> void:
	for index in range(points.size() - 1):
		var start := points[index]
		var finish := points[index + 1]
		var segment_length := start.distance_to(finish)
		var dot_count := maxi(1, int(floor(segment_length / DOT_SPACING)))
		for dot_index in range(dot_count):
			var progress := float(dot_index) / float(dot_count)
			draw_circle(start.lerp(finish, progress), 3.5, color)

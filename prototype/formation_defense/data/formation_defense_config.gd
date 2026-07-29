extends RefCounted

## Combat V2-1 prototype-only values. Nothing in this file is formal balance data.

const VILLAGE_MAX_DURABILITY := 10
const ENEMY_MOVE_SPEED := 60.0
const ENEMY_LEAK_DAMAGE := 1
const SPAWN_INTERVAL_SECONDS := 1.1
const DEFAULT_BATTLEFIELD_SIZE := Vector2(1600.0, 560.0)

const ROUTE_IDS: Array[StringName] = [&"top", &"middle", &"bottom"]
const ROUTE_LABELS := {
	&"top": "上路",
	&"middle": "中路",
	&"bottom": "下路",
}
const ROUTE_COLORS := {
	&"top": Color(0.45, 0.76, 1.0, 1.0),
	&"middle": Color(0.76, 0.64, 1.0, 1.0),
	&"bottom": Color(0.42, 0.88, 0.68, 1.0),
}

# Coordinates are normalized to BattlefieldContent. All routes start on the
# right and share the exact same final point at the village entrance.
const ROUTE_POINTS_NORMALIZED := {
	&"top": [
		Vector2(0.91, 0.20),
		Vector2(0.75, 0.20),
		Vector2(0.57, 0.25),
		Vector2(0.39, 0.35),
		Vector2(0.22, 0.47),
		Vector2(0.11, 0.50),
	],
	&"middle": [
		Vector2(0.91, 0.50),
		Vector2(0.72, 0.50),
		Vector2(0.51, 0.50),
		Vector2(0.30, 0.50),
		Vector2(0.11, 0.50),
	],
	&"bottom": [
		Vector2(0.91, 0.80),
		Vector2(0.75, 0.80),
		Vector2(0.57, 0.75),
		Vector2(0.39, 0.65),
		Vector2(0.22, 0.53),
		Vector2(0.11, 0.50),
	],
}

const SCENARIO_IDS: Array[StringName] = [&"survival", &"defeat"]
const SCENARIOS := {
	&"survival": {
		"display_name": "生存演示",
		"description": "共6只：上、中、下路各2只；全部漏入后剩余4点耐久。",
		"route_sequence": [
			&"top", &"middle", &"bottom",
			&"top", &"middle", &"bottom",
		],
	},
	&"defeat": {
		"display_name": "失守演示",
		"description": "共12只：上、中、下路各4只；耐久归零后立即失败。",
		"route_sequence": [
			&"top", &"middle", &"bottom",
			&"top", &"middle", &"bottom",
			&"top", &"middle", &"bottom",
			&"top", &"middle", &"bottom",
		],
	},
}


static func get_route_ids() -> Array[StringName]:
	return ROUTE_IDS.duplicate()


static func get_route_label(route_id: StringName) -> String:
	return String(ROUTE_LABELS.get(route_id, String(route_id)))


static func get_route_color(route_id: StringName) -> Color:
	return ROUTE_COLORS.get(route_id, Color.WHITE)


static func get_route_points(
	route_id: StringName,
	battlefield_size: Vector2
) -> PackedVector2Array:
	var safe_size := battlefield_size
	if safe_size.x <= 0.0 or safe_size.y <= 0.0:
		safe_size = DEFAULT_BATTLEFIELD_SIZE
	var points := PackedVector2Array()
	for normalized_point: Vector2 in ROUTE_POINTS_NORMALIZED.get(route_id, []):
		points.append(Vector2(
			normalized_point.x * safe_size.x,
			normalized_point.y * safe_size.y
		))
	return points


static func get_village_entrance_point(battlefield_size: Vector2) -> Vector2:
	var points := get_route_points(&"middle", battlefield_size)
	return points[points.size() - 1] if not points.is_empty() else Vector2.ZERO


static func get_scenario_ids() -> Array[StringName]:
	return SCENARIO_IDS.duplicate()


static func get_scenario(scenario_id: StringName) -> Dictionary:
	return SCENARIOS.get(scenario_id, SCENARIOS[&"survival"]).duplicate(true)

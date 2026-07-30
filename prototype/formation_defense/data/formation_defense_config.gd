extends RefCounted

## Combat V2 prototype-only values. Nothing in this file is formal balance data.

const VILLAGE_MAX_DURABILITY := 10
const ENEMY_MOVE_SPEED := 60.0
const ENEMY_LEAK_DAMAGE := 1
const ENEMY_MAX_HEALTH := 50
const ENEMY_ATTACK_DAMAGE := 10
const ENEMY_ATTACK_INTERVAL := 1.0
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

const DEPLOYMENT_COLUMNS := [0.30, 0.43, 0.57, 0.70]
const DEPLOYMENT_SLOTS := [
	{
		"slot_id": &"top_c1",
		"lane_id": &"top",
		"column_id": 1,
		"normalized_position": Vector2(0.30, 0.32),
	},
	{
		"slot_id": &"top_c2",
		"lane_id": &"top",
		"column_id": 2,
		"normalized_position": Vector2(0.43, 0.32),
	},
	{
		"slot_id": &"top_c3",
		"lane_id": &"top",
		"column_id": 3,
		"normalized_position": Vector2(0.57, 0.32),
	},
	{
		"slot_id": &"top_c4",
		"lane_id": &"top",
		"column_id": 4,
		"normalized_position": Vector2(0.70, 0.32),
	},
	{
		"slot_id": &"middle_c1",
		"lane_id": &"middle",
		"column_id": 1,
		"normalized_position": Vector2(0.30, 0.58),
	},
	{
		"slot_id": &"middle_c2",
		"lane_id": &"middle",
		"column_id": 2,
		"normalized_position": Vector2(0.43, 0.58),
	},
	{
		"slot_id": &"middle_c3",
		"lane_id": &"middle",
		"column_id": 3,
		"normalized_position": Vector2(0.57, 0.58),
	},
	{
		"slot_id": &"middle_c4",
		"lane_id": &"middle",
		"column_id": 4,
		"normalized_position": Vector2(0.70, 0.58),
	},
	{
		"slot_id": &"bottom_c1",
		"lane_id": &"bottom",
		"column_id": 1,
		"normalized_position": Vector2(0.30, 0.75),
	},
	{
		"slot_id": &"bottom_c2",
		"lane_id": &"bottom",
		"column_id": 2,
		"normalized_position": Vector2(0.43, 0.75),
	},
	{
		"slot_id": &"bottom_c3",
		"lane_id": &"bottom",
		"column_id": 3,
		"normalized_position": Vector2(0.57, 0.75),
	},
	{
		"slot_id": &"bottom_c4",
		"lane_id": &"bottom",
		"column_id": 4,
		"normalized_position": Vector2(0.70, 0.75),
	},
]

const CHARACTER_IDS: Array[StringName] = [&"guard", &"hunter", &"mage", &"doctor"]
const CHARACTER_DEFINITIONS := {
	&"guard": {
		"display_name": "战士",
		"role_id": &"guard",
		"max_health": 150,
		"action_interval": 0.8,
		"action_range": 82.0,
		"attack_damage": 18,
		"heal_amount": 0,
		"block_capacity": 2,
		"body_color": Color(0.35, 0.68, 1.0, 1.0),
	},
	&"hunter": {
		"display_name": "游侠",
		"role_id": &"hunter",
		"max_health": 90,
		"action_interval": 0.65,
		"action_range": 340.0,
		"attack_damage": 16,
		"heal_amount": 0,
		"block_capacity": 0,
		"body_color": Color(0.45, 0.90, 0.55, 1.0),
	},
	&"mage": {
		"display_name": "法师",
		"role_id": &"mage",
		"max_health": 80,
		"action_interval": 1.1,
		"action_range": 340.0,
		"attack_damage": 28,
		"heal_amount": 0,
		"block_capacity": 0,
		"body_color": Color(0.76, 0.52, 1.0, 1.0),
	},
	&"doctor": {
		"display_name": "治疗者",
		"role_id": &"doctor",
		"max_health": 100,
		"action_interval": 0.75,
		"action_range": 330.0,
		"attack_damage": 0,
		"heal_amount": 16,
		"block_capacity": 0,
		"body_color": Color(0.40, 0.94, 0.86, 1.0),
	},
}

const RECOMMENDED_DEPLOYMENT := {
	&"guard": &"middle_c4",
	&"hunter": &"top_c2",
	&"mage": &"bottom_c2",
	&"doctor": &"middle_c3",
}

const SCENARIO_IDS: Array[StringName] = [&"survival", &"defeat", &"auto_battle"]
const SCENARIOS := {
	&"survival": {
		"display_name": "生存演示",
		"description": "共6只：上、中、下路各2只；全部漏入后剩余4点耐久。",
		"spawn_interval": SPAWN_INTERVAL_SECONDS,
		"route_sequence": [
			&"top", &"middle", &"bottom",
			&"top", &"middle", &"bottom",
		],
	},
	&"defeat": {
		"display_name": "失守演示",
		"description": "共12只：上、中、下路各4只；耐久归零后立即失败。",
		"spawn_interval": SPAWN_INTERVAL_SECONDS,
		"route_sequence": [
			&"top", &"middle", &"bottom",
			&"top", &"middle", &"bottom",
			&"top", &"middle", &"bottom",
			&"top", &"middle", &"bottom",
		],
	},
	&"auto_battle": {
		"display_name": "自动战斗演示",
		"description": "同一组三路敌人用于对比无人部署失败与推荐部署胜利。",
		"spawn_interval": 1.35,
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


static func get_deployment_slots() -> Array:
	return DEPLOYMENT_SLOTS.duplicate(true)


static func get_deployment_slot(slot_id: StringName) -> Dictionary:
	for slot: Dictionary in DEPLOYMENT_SLOTS:
		if StringName(slot.get("slot_id", &"")) == slot_id:
			return slot.duplicate(true)
	return {}


static func get_deployment_position(
	slot_id: StringName,
	battlefield_size: Vector2
) -> Vector2:
	var slot := get_deployment_slot(slot_id)
	var normalized_position: Vector2 = slot.get("normalized_position", Vector2.ZERO)
	var safe_size := battlefield_size
	if safe_size.x <= 0.0 or safe_size.y <= 0.0:
		safe_size = DEFAULT_BATTLEFIELD_SIZE
	return Vector2(
		normalized_position.x * safe_size.x,
		normalized_position.y * safe_size.y
	)


static func get_character_ids() -> Array[StringName]:
	return CHARACTER_IDS.duplicate()


static func get_character_definition(character_id: StringName) -> Dictionary:
	return CHARACTER_DEFINITIONS.get(character_id, {}).duplicate(true)


static func get_recommended_deployment() -> Dictionary:
	return RECOMMENDED_DEPLOYMENT.duplicate(true)


static func get_scenario_ids() -> Array[StringName]:
	return SCENARIO_IDS.duplicate()


static func get_scenario(scenario_id: StringName) -> Dictionary:
	return SCENARIOS.get(scenario_id, SCENARIOS[&"survival"]).duplicate(true)

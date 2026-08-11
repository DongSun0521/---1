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

const DAMAGE_SOURCE_MELEE: StringName = &"MELEE"
const DAMAGE_SOURCE_RANGED: StringName = &"RANGED"
const DAMAGE_SOURCE_UNSPECIFIED: StringName = &"UNSPECIFIED"

const MONSTER_TYPE_IDS: Array[StringName] = [
	&"charge", &"shield", &"formation_guard", &"rush_raider",
]
const MONSTER_DEFINITIONS := {
	&"charge": {
		"display_name": "冲锋怪",
		"max_health": ENEMY_MAX_HEALTH,
		"move_speed": ENEMY_MOVE_SPEED,
		"leak_damage": ENEMY_LEAK_DAMAGE,
		"attack_damage": ENEMY_ATTACK_DAMAGE,
		"attack_interval": ENEMY_ATTACK_INTERVAL,
		"body_color": Color(0.96, 0.48, 0.27, 1.0),
	},
	&"shield": {
		"display_name": "盾甲怪",
		"max_health": ENEMY_MAX_HEALTH,
		"move_speed": ENEMY_MOVE_SPEED,
		"leak_damage": ENEMY_LEAK_DAMAGE,
		"attack_damage": ENEMY_ATTACK_DAMAGE,
		"attack_interval": ENEMY_ATTACK_INTERVAL,
		"body_color": Color(0.34, 0.70, 0.96, 1.0),
		"type_marker": &"plate",
	},
	&"formation_guard": {
		"display_name": "护阵怪",
		"max_health": 91,
		"move_speed": 42.0,
		"leak_damage": ENEMY_LEAK_DAMAGE,
		"attack_damage": ENEMY_ATTACK_DAMAGE,
		"attack_interval": ENEMY_ATTACK_INTERVAL,
		"body_color": Color(0.31, 0.48, 0.66, 1.0),
		"type_marker": &"guard_shield",
		"forming_b_warning_visual": true,
		"retain_a_effect_while_forming_b": false,
		"formation_effects": {
			FORMATION_LEVEL_A: {
				"player_damage_reduction": 0.20,
				"shield_visual_strength": 1,
				"effect_text": "护阵减伤 20%",
			},
			FORMATION_LEVEL_B: {
				"player_damage_reduction": 0.35,
				"shield_visual_strength": 2,
				"effect_text": "强化护阵减伤 35%",
			},
		},
	},
	&"rush_raider": {
		"display_name": "突袭怪",
		"max_health": 91,
		"move_speed": 42.0,
		"leak_damage": ENEMY_LEAK_DAMAGE,
		"attack_damage": ENEMY_ATTACK_DAMAGE,
		"attack_interval": ENEMY_ATTACK_INTERVAL,
		"body_color": Color(0.88, 0.30, 0.20, 1.0),
		"type_marker": &"rush_raider",
		"formation_can_participate": false,
		"rush_enabled": true,
		"rush_trigger_progress": 0.48,
		"rush_prepare_duration": 1.25,
		"rush_duration": 3.25,
		"rush_speed_multiplier": 4.00,
		"rush_once": true,
	},
}

const RUSH_STATE_APPROACH: StringName = &"APPROACH"
const RUSH_STATE_PREPARING: StringName = &"PREPARING_RUSH"
const RUSH_STATE_RUSHING: StringName = &"RUSHING"

const FORMATION_LEVEL_SINGLE: StringName = &"SINGLE"
const FORMATION_LEVEL_A: StringName = &"A"
const FORMATION_LEVEL_B: StringName = &"B"
const FORMATION_STATE_NONE: StringName = &"NONE"
const FORMATION_STATE_FORMING_A_LOCKED: StringName = &"FORMING_A_LOCKED"
const FORMATION_STATE_FORMING_B_LOCKED: StringName = &"FORMING_B_LOCKED"
const FORMATION_STATE_PREPARING_B: StringName = &"PREPARING_B"
# Compatibility aliases keep the V2-3 call sites compact while snapshots expose
# the explicit locked states required by the second-round prototype rules.
const FORMATION_STATE_FORMING_A := FORMATION_STATE_FORMING_A_LOCKED
const FORMATION_STATE_FORMING_B := FORMATION_STATE_FORMING_B_LOCKED
const FORMATION_STATE_COMPLETE: StringName = &"COMPLETE"
const DEFAULT_B_FORMATION_PREPARE_DURATION := 0.0

const INTERRUPTION_MEMBER_DIED: StringName = &"MEMBER_DIED"
const INTERRUPTION_MEMBER_LEAKED: StringName = &"MEMBER_LEAKED"
const INTERRUPTION_STUN: StringName = &"STUN"
const INTERRUPTION_KNOCKBACK: StringName = &"KNOCKBACK"
const INTERRUPTION_FORMATION_BREAK: StringName = &"FORMATION_BREAK"
const CONTROL_INTERRUPTION_REASONS: Array[StringName] = [
	INTERRUPTION_STUN,
	INTERRUPTION_KNOCKBACK,
	INTERRUPTION_FORMATION_BREAK,
]

const FORMATION_A_DURATION := 1.5
const FORMATION_B_DURATION := 2.5
const A_PAIR_RADIUS_X := 200.0
const A_PAIR_RADIUS_Y := 190.0
const B_PAIR_RADIUS_X := 240.0
const B_PAIR_RADIUS_Y := 210.0
const A_PAIR_NEIGHBOR_ROUTE_SPAN := 2
const B_PAIR_NEIGHBOR_ROUTE_SPAN := 2
const FORMING_FORWARD_SPEED_MULTIPLIER := 0.78
const FORMATION_SLOT_MOVE_SPEED := 80.0
# Complete formations use a separate maintenance rate so tuning the convergence
# window cannot change the movement/spacing behavior accepted in V2-3.
const COMPLETE_FORMATION_SLOT_MAINTENANCE_SPEED := 80.0
const FORMATION_SLOT_TOLERANCE := 7.0
const FORMATION_MEET_TIMEOUT := 8.0
const A_SLOT_GAP_Y := 56.0
const B_SLOT_GAP_X := 70.0
const B_SLOT_GAP_Y := 62.0
const FORMATION_ROUTE_SPACING_Y := 80.0
const FORMATION_ROUTE_CENTER_INDEX := 2
const SHIELD_B_PROTECTION_RADIUS := 240.0
const FORMATION_FEEDBACK_DURATION := 0.9
const CHARGE_A_SPEED_MULTIPLIER := 1.25
const CHARGE_B_SPEED_MULTIPLIER := 1.50
const SHIELD_A_RANGED_REDUCTION := 0.35
const SHIELD_B_RANGED_REDUCTION := 0.60
const SHIELD_B_ALLY_RANGED_REDUCTION := 0.30

const FORMATION_COLORS := {
	&"charge": Color(1.0, 0.55, 0.25, 1.0),
	&"shield": Color(0.30, 0.76, 1.0, 1.0),
	&"formation_guard": Color(0.45, 0.72, 0.94, 1.0),
}

const FORMATION_ZONE_SINGLE: StringName = &"SINGLE_WALK"
const FORMATION_ZONE_A: StringName = &"A_FORMATION"
const FORMATION_ZONE_A_DISPLAY: StringName = &"A_DISPLAY"
const FORMATION_ZONE_B: StringName = &"B_FORMATION"
const FORMATION_ZONE_DEFENSE: StringName = &"DEFENSE"

const ROUTE_GROUP_FORMATION: StringName = &"formation_corridor"
const ROUTE_GROUP_ISOLATED: StringName = &"isolated_corridor"
const ROUTE_GROUP_COMPATIBILITY := {
	ROUTE_GROUP_FORMATION: [ROUTE_GROUP_FORMATION],
	ROUTE_GROUP_ISOLATED: [ROUTE_GROUP_ISOLATED],
	&"legacy_top": [&"legacy_top"],
	&"legacy_middle": [&"legacy_middle"],
	&"legacy_bottom": [&"legacy_bottom"],
}

# Normalized rectangles are resolved against BattlefieldContent at runtime.
# Enemies travel right-to-left through these five mutually exclusive bands.
const FORMATION_ZONES := [
	{
		"zone_id": &"single_walk_zone",
		"zone_type": FORMATION_ZONE_SINGLE,
		"display_name": "① 单体行走区",
		"normalized_rect": Rect2(0.76, 0.10, 0.16, 0.80),
		"allowed_route_group_ids": [
			ROUTE_GROUP_FORMATION,
			ROUTE_GROUP_ISOLATED,
		],
		"color": Color(0.48, 0.56, 0.68, 0.11),
	},
	{
		"zone_id": &"a_formation_zone",
		"zone_type": FORMATION_ZONE_A,
		"display_name": "② A组阵区",
		"normalized_rect": Rect2(0.62, 0.10, 0.14, 0.80),
		"allowed_route_group_ids": [
			ROUTE_GROUP_FORMATION,
			ROUTE_GROUP_ISOLATED,
		],
		"color": Color(1.0, 0.67, 0.28, 0.14),
	},
	{
		"zone_id": &"a_display_zone",
		"zone_type": FORMATION_ZONE_A_DISPLAY,
		"display_name": "③ A阵展示区",
		"normalized_rect": Rect2(0.48, 0.10, 0.14, 0.80),
		"allowed_route_group_ids": [
			ROUTE_GROUP_FORMATION,
			ROUTE_GROUP_ISOLATED,
		],
		"color": Color(0.91, 0.78, 0.33, 0.10),
	},
	{
		"zone_id": &"b_formation_zone",
		"zone_type": FORMATION_ZONE_B,
		"display_name": "④ B组阵区",
		"normalized_rect": Rect2(0.32, 0.10, 0.16, 0.80),
		"allowed_route_group_ids": [
			ROUTE_GROUP_FORMATION,
			ROUTE_GROUP_ISOLATED,
		],
		"color": Color(0.72, 0.43, 1.0, 0.14),
	},
	{
		"zone_id": &"defense_zone",
		"zone_type": FORMATION_ZONE_DEFENSE,
		"display_name": "⑤ 防守交战区",
		"normalized_rect": Rect2(0.08, 0.10, 0.24, 0.80),
		"allowed_route_group_ids": [
			ROUTE_GROUP_FORMATION,
			ROUTE_GROUP_ISOLATED,
		],
		"color": Color(0.32, 0.82, 0.63, 0.10),
	},
]

const ROUTE_IDS: Array[StringName] = [&"top", &"middle", &"bottom"]
const FORMATION_COMPATIBLE_ROUTE_IDS: Array[StringName] = [
	&"formation_upper_outer",
	&"formation_upper",
	&"formation_center",
	&"formation_lower",
	&"formation_lower_outer",
]
const FORMATION_ROUTE_IDS: Array[StringName] = [
	&"formation_upper_outer",
	&"formation_upper",
	&"formation_center",
	&"formation_lower",
	&"formation_lower_outer",
	&"formation_isolated",
]
const ROUTE_LABELS := {
	&"top": "上路",
	&"middle": "中路",
	&"bottom": "下路",
	&"formation_upper_outer": "组阵轨 0",
	&"formation_upper": "组阵轨 1",
	&"formation_center": "组阵轨 2",
	&"formation_lower": "组阵轨 3",
	&"formation_lower_outer": "组阵轨 4",
	&"formation_isolated": "隔离测试轨",
}
const ROUTE_COLORS := {
	&"top": Color(0.45, 0.76, 1.0, 1.0),
	&"middle": Color(0.76, 0.64, 1.0, 1.0),
	&"bottom": Color(0.42, 0.88, 0.68, 1.0),
	&"formation_upper": Color(1.0, 0.64, 0.38, 1.0),
	&"formation_center": Color(0.78, 0.70, 1.0, 1.0),
	&"formation_lower": Color(0.38, 0.84, 1.0, 1.0),
	&"formation_upper_outer": Color(1.0, 0.82, 0.36, 1.0),
	&"formation_lower_outer": Color(0.38, 0.94, 0.74, 1.0),
	&"formation_isolated": Color(0.62, 0.68, 0.76, 1.0),
}

# The five compatible formation routes share one deterministic horizontal
# profile. Their Y offsets come only from FORMATION_ROUTE_SPACING_Y.
const FORMATION_ROUTE_X_FACTORS: Array[float] = [
	0.91, 0.76, 0.69, 0.62, 0.55, 0.48, 0.40, 0.32, 0.20, 0.11,
]
const FORMATION_ROUTE_OFFSET_FACTORS: Array[float] = [
	1.0, 1.0, 0.92, 0.80, 0.65, 0.50, 0.32, 0.18, 0.0, 0.0,
]

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
	&"formation_upper": [
		Vector2(0.91, 0.35),
		Vector2(0.76, 0.35),
		Vector2(0.69, 0.37),
		Vector2(0.62, 0.39),
		Vector2(0.55, 0.40),
		Vector2(0.48, 0.42),
		Vector2(0.40, 0.44),
		Vector2(0.32, 0.47),
		Vector2(0.20, 0.50),
		Vector2(0.11, 0.50),
	],
	&"formation_center": [
		Vector2(0.91, 0.50),
		Vector2(0.76, 0.50),
		Vector2(0.62, 0.50),
		Vector2(0.48, 0.50),
		Vector2(0.32, 0.50),
		Vector2(0.11, 0.50),
	],
	&"formation_lower": [
		Vector2(0.91, 0.65),
		Vector2(0.76, 0.65),
		Vector2(0.69, 0.63),
		Vector2(0.62, 0.61),
		Vector2(0.55, 0.60),
		Vector2(0.48, 0.58),
		Vector2(0.40, 0.56),
		Vector2(0.32, 0.53),
		Vector2(0.20, 0.50),
		Vector2(0.11, 0.50),
	],
	&"formation_upper_outer": [
		Vector2(0.91, 0.26),
		Vector2(0.76, 0.28),
		Vector2(0.62, 0.33),
		Vector2(0.48, 0.40),
		Vector2(0.32, 0.47),
		Vector2(0.11, 0.50),
	],
	&"formation_lower_outer": [
		Vector2(0.91, 0.74),
		Vector2(0.76, 0.72),
		Vector2(0.62, 0.67),
		Vector2(0.48, 0.60),
		Vector2(0.32, 0.53),
		Vector2(0.11, 0.50),
	],
	&"formation_isolated": [
		Vector2(0.91, 0.16),
		Vector2(0.76, 0.18),
		Vector2(0.62, 0.24),
		Vector2(0.48, 0.34),
		Vector2(0.32, 0.46),
		Vector2(0.11, 0.50),
	],
}

const ROUTE_RUNTIME_DATA := {
	&"top": {
		"route_group_id": &"legacy_top",
		"blocking_lane_id": &"top",
		"formation_route_index": 0,
	},
	&"middle": {
		"route_group_id": &"legacy_middle",
		"blocking_lane_id": &"middle",
		"formation_route_index": 1,
	},
	&"bottom": {
		"route_group_id": &"legacy_bottom",
		"blocking_lane_id": &"bottom",
		"formation_route_index": 2,
	},
	&"formation_upper_outer": {
		"route_group_id": ROUTE_GROUP_FORMATION,
		"blocking_lane_id": &"top",
		"formation_route_index": 0,
	},
	&"formation_upper": {
		"route_group_id": ROUTE_GROUP_FORMATION,
		"blocking_lane_id": &"top",
		"formation_route_index": 1,
	},
	&"formation_center": {
		"route_group_id": ROUTE_GROUP_FORMATION,
		"blocking_lane_id": &"middle",
		"formation_route_index": 2,
	},
	&"formation_lower": {
		"route_group_id": ROUTE_GROUP_FORMATION,
		"blocking_lane_id": &"bottom",
		"formation_route_index": 3,
	},
	&"formation_lower_outer": {
		"route_group_id": ROUTE_GROUP_FORMATION,
		"blocking_lane_id": &"bottom",
		"formation_route_index": 4,
	},
	&"formation_isolated": {
		"route_group_id": ROUTE_GROUP_ISOLATED,
		"blocking_lane_id": &"top",
		"formation_route_index": 2,
	},
}

const SPAWN_POINTS := [
	{
		"spawn_point_id": &"spawn_upper_outer",
		"display_name": "入口 R0",
		"route_id": &"formation_upper_outer",
		"route_group_id": ROUTE_GROUP_FORMATION,
		"blocking_lane_id": &"top",
		"formation_route_index": 0,
		"default_active": true,
	},
	{
		"spawn_point_id": &"spawn_upper",
		"display_name": "入口 R1",
		"route_id": &"formation_upper",
		"route_group_id": ROUTE_GROUP_FORMATION,
		"blocking_lane_id": &"top",
		"formation_route_index": 1,
		"default_active": true,
	},
	{
		"spawn_point_id": &"spawn_center",
		"display_name": "入口 R2",
		"route_id": &"formation_center",
		"route_group_id": ROUTE_GROUP_FORMATION,
		"blocking_lane_id": &"middle",
		"formation_route_index": 2,
		"default_active": true,
	},
	{
		"spawn_point_id": &"spawn_lower",
		"display_name": "入口 R3",
		"route_id": &"formation_lower",
		"route_group_id": ROUTE_GROUP_FORMATION,
		"blocking_lane_id": &"bottom",
		"formation_route_index": 3,
		"default_active": true,
	},
	{
		"spawn_point_id": &"spawn_lower_outer",
		"display_name": "入口 R4",
		"route_id": &"formation_lower_outer",
		"route_group_id": ROUTE_GROUP_FORMATION,
		"blocking_lane_id": &"bottom",
		"formation_route_index": 4,
		"default_active": true,
	},
	{
		"spawn_point_id": &"spawn_isolated",
		"display_name": "隔离入口",
		"route_id": &"formation_isolated",
		"route_group_id": ROUTE_GROUP_ISOLATED,
		"blocking_lane_id": &"top",
		"formation_route_index": 2,
		"default_active": false,
	},
]

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
		"damage_source_type": DAMAGE_SOURCE_MELEE,
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
		"damage_source_type": DAMAGE_SOURCE_RANGED,
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
		"damage_source_type": DAMAGE_SOURCE_RANGED,
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
		"damage_source_type": DAMAGE_SOURCE_UNSPECIFIED,
		"body_color": Color(0.40, 0.94, 0.86, 1.0),
	},
}

const RECOMMENDED_DEPLOYMENT := {
	&"guard": &"middle_c4",
	&"hunter": &"top_c2",
	&"mage": &"bottom_c2",
	&"doctor": &"middle_c3",
}
const FORMATION_DEMO_DEPLOYMENT := {
	&"guard": &"middle_c1",
	&"hunter": &"top_c1",
	&"mage": &"bottom_c1",
	&"doctor": &"middle_c2",
}

const WAVE_BATTLES := {
	&"v2_5b_validation": {
		"battle_id": &"v2_5b_validation",
		"display_name": "V2-5B 波次验证",
		"random_seed": 2505,
		"initial_countdown": 1.5,
		"inter_wave_delay": 1.2,
		"waves": [
			{
				"wave_id": &"wave_1",
				"display_name": "第一波：基础生成",
				"subwaves": [{
					"start_offset": 0.0,
					"spawn_groups": [{
						"enemy_profile_id": &"charge",
						"max_health": 100,
						"count": 2,
						"spawn_interval": 0.7,
						"allowed_spawn_points": [&"spawn_center"],
						"allowed_lanes": [&"formation_center"],
						"selection_mode": &"round_robin",
					}],
				}],
			},
			{
				"wave_id": &"wave_2",
				"display_name": "第二波：错时子波次",
				"subwaves": [
					{
						"start_offset": 0.0,
						"spawn_groups": [{
							"enemy_profile_id": &"charge",
							"max_health": 100,
							"count": 2,
							"spawn_interval": 0.8,
							"allowed_spawn_points": [
								&"spawn_upper", &"spawn_lower",
							],
							"allowed_lanes": [
								&"formation_upper", &"formation_lower",
							],
							"selection_mode": &"round_robin",
						}],
					},
					{
						"start_offset": 1.1,
						"spawn_groups": [{
							"enemy_profile_id": &"shield",
							"max_health": 120,
							"count": 2,
							"spawn_interval": 0.6,
							"allowed_spawn_points": [
								&"spawn_center", &"spawn_lower_outer",
							],
							"allowed_lanes": [
								&"formation_center", &"formation_lower_outer",
							],
							"selection_mode": &"round_robin",
						}],
					},
				],
			},
			{
				"wave_id": &"wave_3",
				"display_name": "第三波：重叠生成组",
				"subwaves": [{
					"start_offset": 0.0,
					"spawn_groups": [
						{
							"enemy_profile_id": &"charge",
							"max_health": 100,
							"count": 3,
							"spawn_interval": 0.7,
							"allowed_spawn_points": [
								&"spawn_upper_outer", &"spawn_center",
							],
							"allowed_lanes": [
								&"formation_upper_outer", &"formation_center",
							],
							"selection_mode": &"random",
						},
						{
							"enemy_profile_id": &"shield",
							"max_health": 120,
							"count": 3,
							"spawn_interval": 0.7,
							"allowed_spawn_points": [
								&"spawn_lower", &"spawn_lower_outer",
							],
							"allowed_lanes": [
								&"formation_lower", &"formation_lower_outer",
							],
							"selection_mode": &"random",
						},
					],
				}],
			},
		],
	},
	&"v2_5c_pacing": {
		"battle_id": &"v2_5c_pacing",
		"display_name": "V2-5C 3～4分钟节奏验证",
		"random_seed": 2506,
		"initial_countdown": 3.0,
		"inter_wave_delay": 4.0,
		"enemy_profile_overrides": {
			&"charge": {"max_health": 91, "move_speed": 42.0},
			&"shield": {"max_health": 91, "move_speed": 42.0},
		},
		"formation_approach_speed": 52.0,
		"formation_completion_tolerance": 12.0,
		"formation_duration_multiplier": 0.0,
		"waves": [
			{
				"wave_id": &"pacing_1",
				"display_name": "开场熟悉",
				"subwaves": [{
					"start_offset": 0.0,
					"spawn_groups": [{
						"enemy_profile_id": &"charge", "count": 4,
						"spawn_interval": 2.0,
						"allowed_spawn_points": [&"spawn_upper_outer", &"spawn_lower_outer"],
						"allowed_lanes": [&"formation_upper_outer", &"formation_lower_outer"],
						"selection_mode": &"round_robin",
					}],
				}],
			},
			{
				"wave_id": &"pacing_2",
				"display_name": "战场展开",
				"subwaves": [
					{"start_offset": 0.0, "spawn_groups": [{
						"enemy_profile_id": &"charge", "count": 3, "spawn_interval": 1.3,
						"allowed_spawn_points": [&"spawn_upper", &"spawn_center"],
						"allowed_lanes": [&"formation_upper", &"formation_center"],
						"selection_mode": &"round_robin",
					}]},
					{"start_offset": 8.0, "spawn_groups": [{
						"enemy_profile_id": &"shield", "count": 2, "spawn_interval": 2.0,
						"allowed_spawn_points": [&"spawn_lower"],
						"allowed_lanes": [&"formation_lower"],
						"selection_mode": &"round_robin",
					}]},
				],
			},
			{
				"wave_id": &"pacing_3",
				"display_name": "组阵来袭",
				"subwaves": [
					{"start_offset": 0.0, "spawn_groups": [{
						"enemy_profile_id": &"charge", "count": 4, "spawn_interval": 0.65,
						"allowed_spawn_points": [&"spawn_upper_outer", &"spawn_upper"],
						"allowed_lanes": [&"formation_upper_outer", &"formation_upper"],
						"selection_mode": &"round_robin",
					}]},
					{"start_offset": 7.0, "spawn_groups": [{
						"enemy_profile_id": &"shield", "count": 2, "spawn_interval": 1.2,
						"allowed_spawn_points": [&"spawn_center"],
						"allowed_lanes": [&"formation_center"],
						"selection_mode": &"round_robin",
					}]},
				],
			},
			{
				"wave_id": &"pacing_4",
				"display_name": "错峰推进",
				"subwaves": [
					{"start_offset": 0.0, "spawn_groups": [{
						"enemy_profile_id": &"charge", "count": 3, "spawn_interval": 1.5,
						"allowed_spawn_points": [&"spawn_upper_outer", &"spawn_upper"],
						"allowed_lanes": [&"formation_upper_outer", &"formation_upper"],
						"selection_mode": &"round_robin",
					}]},
					{"start_offset": 7.0, "spawn_groups": [{
						"enemy_profile_id": &"shield", "count": 2, "spawn_interval": 1.5,
						"allowed_spawn_points": [&"spawn_center"],
						"allowed_lanes": [&"formation_center"],
						"selection_mode": &"round_robin",
					}]},
					{"start_offset": 10.0, "spawn_groups": [{
						"enemy_profile_id": &"charge", "count": 2, "spawn_interval": 1.5,
						"allowed_spawn_points": [&"spawn_lower", &"spawn_lower_outer"],
						"allowed_lanes": [&"formation_lower", &"formation_lower_outer"],
						"selection_mode": &"round_robin",
					}]},
				],
			},
			{
				"wave_id": &"pacing_5",
				"display_name": "持续高压",
				"subwaves": [
					{"start_offset": 0.0, "spawn_groups": [{
						"enemy_profile_id": &"shield", "count": 4, "spawn_interval": 0.25,
						"allowed_spawn_points": [&"spawn_upper_outer", &"spawn_center"],
						"allowed_lanes": [&"formation_upper_outer", &"formation_center"],
						"selection_mode": &"round_robin",
					}]},
					{"start_offset": 4.0, "spawn_groups": [{
						"enemy_profile_id": &"charge", "count": 5, "spawn_interval": 0.8,
						"allowed_spawn_points": [&"spawn_center", &"spawn_lower", &"spawn_lower_outer"],
						"allowed_lanes": [&"formation_center", &"formation_lower", &"formation_lower_outer"],
						"selection_mode": &"round_robin",
					}]},
				],
			},
			{
				"wave_id": &"pacing_6",
				"display_name": "最终高潮",
				"subwaves": [
					{"start_offset": 0.0, "spawn_groups": [{
						"enemy_profile_id": &"shield", "count": 4, "spawn_interval": 0.25,
						"allowed_spawn_points": [&"spawn_upper_outer", &"spawn_center"],
						"allowed_lanes": [&"formation_upper_outer", &"formation_center"],
						"selection_mode": &"round_robin",
					}]},
					{"start_offset": 5.0, "spawn_groups": [{
						"enemy_profile_id": &"charge", "count": 5, "spawn_interval": 0.6,
						"allowed_spawn_points": [&"spawn_center", &"spawn_lower"],
						"allowed_lanes": [&"formation_center", &"formation_lower"],
						"selection_mode": &"round_robin",
					}]},
					{"start_offset": 6.5, "spawn_groups": [{
						"enemy_profile_id": &"shield", "count": 4, "spawn_interval": 0.4,
						"allowed_spawn_points": [&"spawn_upper_outer", &"spawn_lower_outer"],
						"allowed_lanes": [&"formation_upper_outer", &"formation_lower_outer"],
						"selection_mode": &"round_robin",
					}]},
				],
			},
		],
	},
	&"v2_6a_formation_guard_validation": {
		"battle_id": &"v2_6a_formation_guard_validation",
		"display_name": "V2-6A 护阵怪验证",
		"random_seed": 2601,
		"initial_countdown": 3.0,
		"inter_wave_delay": 3.0,
		"enemy_profile_overrides": {
			&"charge": {"max_health": 91, "move_speed": 42.0},
		},
		"formation_approach_speed": 52.0,
		"formation_completion_tolerance": 12.0,
		"formation_duration_multiplier": 0.0,
		"b_formation_prepare_duration": 3.0,
		"waves": [
			{
				"wave_id": &"guard_1",
				"display_name": "A阵熟悉",
				"subwaves": [{
					"start_offset": 0.0,
					"spawn_groups": [{
						"enemy_profile_id": &"formation_guard",
						"count": 2,
						"spawn_interval": 0.8,
						"allowed_spawn_points": [&"spawn_center"],
						"allowed_lanes": [&"formation_center"],
						"selection_mode": &"round_robin",
					}],
				}],
			},
			{
				"wave_id": &"guard_2",
				"display_name": "B阵验证",
				"subwaves": [{
					"start_offset": 0.0,
					"spawn_groups": [{
						"enemy_profile_id": &"formation_guard",
						"count": 4,
						"spawn_interval": 0.35,
						"allowed_spawn_points": [&"spawn_upper", &"spawn_center"],
						"allowed_lanes": [&"formation_upper", &"formation_center"],
						"selection_mode": &"round_robin",
					}],
				}],
			},
			{
				"wave_id": &"guard_3",
				"display_name": "混合判断",
				"subwaves": [
					{
						"start_offset": 0.0,
						"spawn_groups": [{
							"enemy_profile_id": &"charge",
							"count": 12,
							"spawn_interval": 1.2,
							"allowed_spawn_points": [&"spawn_center"],
							"allowed_lanes": [&"formation_center"],
							"selection_mode": &"round_robin",
						}],
					},
					{
						"start_offset": 5.0,
						"spawn_groups": [{
							"enemy_profile_id": &"formation_guard",
							"count": 4,
							"spawn_interval": 0.35,
							"allowed_spawn_points": [&"spawn_center"],
							"allowed_lanes": [&"formation_center"],
							"selection_mode": &"round_robin",
						}],
					},
				],
			},
		],
	},
	&"v2_6b_rush_raider_validation": {
		"battle_id": &"v2_6b_rush_raider_validation",
		"display_name": "V2-6B-R 突袭怪验证",
		"random_seed": 2602,
		"initial_countdown": 3.0,
		"inter_wave_delay": 3.0,
		"waves": [
			{
				"wave_id": &"rush_1",
				"display_name": "单体预警",
				"subwaves": [{
					"start_offset": 0.0,
					"spawn_groups": [{
						"enemy_profile_id": &"rush_raider",
						"count": 1,
						"spawn_interval": 0.0,
						"allowed_spawn_points": [&"spawn_center"],
						"allowed_lanes": [&"formation_center"],
						"selection_mode": &"round_robin",
					}],
				}],
			},
			{
				"wave_id": &"rush_2",
				"display_name": "错峰突袭",
				"subwaves": [{
					"start_offset": 0.0,
					"spawn_groups": [{
						"enemy_profile_id": &"rush_raider",
						"count": 2,
						"spawn_interval": 2.0,
						"allowed_spawn_points": [
							&"spawn_upper_outer", &"spawn_lower_outer",
						],
						"allowed_lanes": [
							&"formation_upper_outer", &"formation_lower_outer",
						],
						"selection_mode": &"round_robin",
					}],
				}],
			},
			{
				"wave_id": &"rush_3",
				"display_name": "多路突破",
				"subwaves": [{
					"start_offset": 0.0,
					"spawn_groups": [{
						"enemy_profile_id": &"rush_raider",
						"count": 5,
						"spawn_interval": 0.9,
						"allowed_spawn_points": [
							&"spawn_upper_outer", &"spawn_upper", &"spawn_center",
							&"spawn_lower", &"spawn_lower_outer",
						],
						"allowed_lanes": [
							&"formation_upper_outer", &"formation_upper",
							&"formation_center", &"formation_lower",
							&"formation_lower_outer",
						],
						"selection_mode": &"round_robin",
					}],
				}],
			},
		],
	},
	&"v2_6b_mixed_threat_validation": {
		"battle_id": &"v2_6b_mixed_threat_validation",
		"display_name": "V2-6B-P 混合威胁验证",
		"random_seed": 2603,
		"initial_countdown": 3.0,
		"inter_wave_delay": 3.0,
		"formation_approach_speed": 52.0,
		"formation_completion_tolerance": 12.0,
		"formation_duration_multiplier": 0.0,
		"b_formation_prepare_duration": 3.0,
		"waves": [
			{
				"wave_id": &"mixed_1",
				"display_name": "护阵前压",
				"subwaves": [{
					"start_offset": 0.0,
					"spawn_groups": [{
						"enemy_profile_id": &"formation_guard",
						"count": 2,
						"spawn_interval": 0.6,
						"allowed_spawn_points": [&"spawn_center"],
						"allowed_lanes": [&"formation_center"],
						"selection_mode": &"round_robin",
					}],
				}],
			},
			{
				"wave_id": &"mixed_2",
				"display_name": "突袭识别",
				"subwaves": [
					{
						"start_offset": 0.0,
						"spawn_groups": [{
							"enemy_profile_id": &"rush_raider",
							"count": 1,
							"spawn_interval": 0.0,
							"allowed_spawn_points": [&"spawn_center"],
							"allowed_lanes": [&"formation_center"],
							"selection_mode": &"round_robin",
						}],
					},
				],
			},
			{
				"wave_id": &"mixed_3",
				"display_name": "第一次目标冲突",
				"subwaves": [
					{
						"start_offset": 3.0,
						"spawn_groups": [{
							"enemy_profile_id": &"rush_raider",
							"count": 1,
							"spawn_interval": 0.0,
							"allowed_spawn_points": [&"spawn_center"],
							"allowed_lanes": [&"formation_center"],
							"selection_mode": &"round_robin",
						}],
					},
					{
						"start_offset": 0.0,
						"spawn_groups": [{
							"enemy_profile_id": &"formation_guard",
							"count": 6,
							"spawn_interval": 0.45,
							"allowed_spawn_points": [&"spawn_upper", &"spawn_center"],
							"allowed_lanes": [&"formation_upper", &"formation_center"],
							"selection_mode": &"round_robin",
						}],
					},
				],
			},
			{
				"wave_id": &"mixed_4",
				"display_name": "双威胁收束",
				"subwaves": [
					{
						"start_offset": 2.5,
						"spawn_groups": [{
							"enemy_profile_id": &"rush_raider",
							"count": 5,
							"spawn_interval": 0.9,
							"allowed_spawn_points": [
								&"spawn_upper_outer", &"spawn_upper", &"spawn_center",
								&"spawn_lower", &"spawn_lower_outer",
							],
							"allowed_lanes": [
								&"formation_upper_outer", &"formation_upper", &"formation_center",
								&"formation_lower", &"formation_lower_outer",
							],
							"selection_mode": &"round_robin",
						}],
					},
					{
						"start_offset": 0.0,
						"spawn_groups": [{
							"enemy_profile_id": &"formation_guard",
							"count": 8,
							"spawn_interval": 0.5,
							"allowed_spawn_points": [&"spawn_center", &"spawn_lower"],
							"allowed_lanes": [&"formation_center", &"formation_lower"],
							"selection_mode": &"round_robin",
						}],
					},
				],
			},
		],
	},
}

const SCENARIO_IDS: Array[StringName] = [
	&"survival",
	&"defeat",
	&"auto_battle",
	&"formation_demo",
	&"command_demo",
	&"wave_validation",
	&"pacing_validation",
	&"formation_guard_validation",
	&"rush_raider_validation",
	&"mixed_threat_validation",
]
const SCENARIOS := {
	&"survival": {
		"display_name": "生存演示",
		"description": "共6只：上、中、下路各2只；全部漏入后剩余4点耐久。",
		"spawn_interval": SPAWN_INTERVAL_SECONDS,
		"formations_enabled": false,
		"route_sequence": [
			&"top", &"middle", &"bottom",
			&"top", &"middle", &"bottom",
		],
	},
	&"defeat": {
		"display_name": "失守演示",
		"description": "共12只：上、中、下路各4只；耐久归零后立即失败。",
		"spawn_interval": SPAWN_INTERVAL_SECONDS,
		"formations_enabled": false,
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
		"formations_enabled": false,
		"route_sequence": [
			&"top", &"middle", &"bottom",
			&"top", &"middle", &"bottom",
			&"top", &"middle", &"bottom",
			&"top", &"middle", &"bottom",
		],
	},
	&"formation_demo": {
		"display_name": "怪物组阵演示",
		"description": "五条兼容轨道确定性演示同轨、跨1轨、跨2轨A阵与B阵靠拢。",
		"spawn_interval": 0.75,
		"formations_enabled": true,
		"auto_demo_control_resistance": true,
		"active_spawn_point_ids": [
			&"spawn_upper_outer",
			&"spawn_upper",
			&"spawn_center",
			&"spawn_lower",
			&"spawn_lower_outer",
		],
		"spawn_sequence": [
			&"spawn_center",
			&"spawn_center",
			&"spawn_upper_outer",
			&"spawn_center",
			&"spawn_lower",
			&"spawn_lower_outer",
			&"spawn_upper",
			&"spawn_upper",
			&"spawn_upper",
			&"spawn_center",
			&"spawn_center",
			&"spawn_lower_outer",
		],
		"spawn_entries": [
			{
				"spawn_point_id": &"spawn_center",
				"monster_type": &"charge",
				"move_speed": 52.0,
				"max_health": 280,
				"leak_damage": 0,
			},
			{
				"spawn_point_id": &"spawn_center",
				"monster_type": &"charge",
				"move_speed": 52.0,
				"max_health": 280,
				"leak_damage": 0,
				"delay_after": 0.35,
			},
			{
				"spawn_point_id": &"spawn_upper_outer",
				"monster_type": &"charge",
				"move_speed": 52.0,
				"max_health": 280,
				"leak_damage": 0,
			},
			{
				"spawn_point_id": &"spawn_center",
				"monster_type": &"charge",
				"move_speed": 60.0,
				"max_health": 280,
				"leak_damage": 0,
				"delay_after": 0.35,
			},
			{
				"spawn_point_id": &"spawn_lower",
				"monster_type": &"charge",
				"move_speed": 52.0,
				"max_health": 180,
				"leak_damage": 0,
			},
			{
				"spawn_point_id": &"spawn_lower_outer",
				"monster_type": &"charge",
				"move_speed": 52.0,
				"max_health": 180,
				"leak_damage": 0,
				"delay_after": 0.35,
			},
			{
				"spawn_point_id": &"spawn_upper",
				"monster_type": &"shield",
				"move_speed": 52.0,
				"max_health": 220,
				"leak_damage": 0,
			},
			{
				"spawn_point_id": &"spawn_upper",
				"monster_type": &"shield",
				"move_speed": 52.0,
				"max_health": 220,
				"leak_damage": 0,
				"delay_after": 0.35,
			},
			{
				"spawn_point_id": &"spawn_upper",
				"monster_type": &"shield",
				"move_speed": 52.0,
				"max_health": 220,
				"leak_damage": 0,
			},
			{
				"spawn_point_id": &"spawn_center",
				"monster_type": &"shield",
				"move_speed": 60.0,
				"max_health": 220,
				"leak_damage": 0,
				"delay_after": 0.35,
			},
			{
				"spawn_point_id": &"spawn_center",
				"monster_type": &"shield",
				"move_speed": 52.0,
				"max_health": 180,
				"leak_damage": 0,
			},
			{
				"spawn_point_id": &"spawn_lower_outer",
				"monster_type": &"shield",
				"move_speed": 52.0,
				"max_health": 180,
				"leak_damage": 0,
			},
		],
	},
	&"command_demo": {
		"display_name": "V2-4 集火与破阵反馈",
		"description": "复用已锁定的V2-3生成计划，验证集火、成阵前拦截与击杀后自然破阵。",
		"spawn_interval": 0.75,
		"formations_enabled": true,
		"auto_demo_control_resistance": true,
		"inherit_spawn_plan": &"formation_demo",
		"active_spawn_point_ids": [
			&"spawn_upper_outer",
			&"spawn_upper",
			&"spawn_center",
			&"spawn_lower",
			&"spawn_lower_outer",
		],
	},
	&"wave_validation": {
		"display_name": "V2-5B 波次验证",
		"description": "三波配置化子波次、重叠生成和固定种子验证。",
		"formations_enabled": true,
		"wave_battle_id": &"v2_5b_validation",
		"active_spawn_point_ids": [
			&"spawn_upper_outer",
			&"spawn_upper",
			&"spawn_center",
			&"spawn_lower",
			&"spawn_lower_outer",
		],
	},
	&"pacing_validation": {
		"display_name": "V2-5C 3～4分钟节奏验证",
		"description": "六波升压、缓和与最终高潮的完整无人节奏验证。",
		"formations_enabled": true,
		"wave_battle_id": &"v2_5c_pacing",
		"active_spawn_point_ids": [
			&"spawn_upper_outer", &"spawn_upper", &"spawn_center",
			&"spawn_lower", &"spawn_lower_outer",
		],
	},
	&"formation_guard_validation": {
		"display_name": "V2-6A 护阵怪验证",
		"description": "三波验证护阵减伤、成阵前拦截与成阵后集火差异。",
		"formations_enabled": true,
		"wave_battle_id": &"v2_6a_formation_guard_validation",
		"active_spawn_point_ids": [
			&"spawn_upper", &"spawn_center", &"spawn_lower", &"spawn_lower_outer",
		],
	},
	&"rush_raider_validation": {
		"display_name": "V2-6B-R 突袭怪验证",
		"description": "三波验证突袭预警、爆发推进与真实集火拦截。",
		"formations_enabled": true,
		"wave_battle_id": &"v2_6b_rush_raider_validation",
		"active_spawn_point_ids": [
			&"spawn_upper_outer", &"spawn_upper", &"spawn_center",
			&"spawn_lower", &"spawn_lower_outer",
		],
	},
	&"mixed_threat_validation": {
		"display_name": "V2-6B-P 护阵与突袭混合验证",
		"description": "四段验证持续护阵压力与短时突袭预警之间的目标切换。",
		"formations_enabled": true,
		"wave_battle_id": &"v2_6b_mixed_threat_validation",
		"active_spawn_point_ids": [
			&"spawn_upper_outer", &"spawn_upper", &"spawn_center",
			&"spawn_lower", &"spawn_lower_outer",
		],
	},
}


static func get_route_ids() -> Array[StringName]:
	return ROUTE_IDS.duplicate()


static func get_visual_route_ids() -> Array[StringName]:
	var result := ROUTE_IDS.duplicate()
	result.append_array(FORMATION_ROUTE_IDS)
	return result


static func get_route_label(route_id: StringName) -> String:
	return String(ROUTE_LABELS.get(route_id, String(route_id)))


static func get_route_color(route_id: StringName) -> Color:
	return ROUTE_COLORS.get(route_id, Color.WHITE)


static func get_route_runtime_data(route_id: StringName) -> Dictionary:
	return ROUTE_RUNTIME_DATA.get(route_id, {
		"route_group_id": StringName("legacy_%s" % String(route_id)),
		"blocking_lane_id": route_id,
		"formation_route_index": 0,
	}).duplicate(true)


static func get_spawn_points() -> Array:
	return SPAWN_POINTS.duplicate(true)


static func get_spawn_point(spawn_point_id: StringName) -> Dictionary:
	for spawn_point: Dictionary in SPAWN_POINTS:
		if StringName(spawn_point.get("spawn_point_id", &"")) == spawn_point_id:
			return spawn_point.duplicate(true)
	return {}


static func get_default_spawn_point_for_route(route_id: StringName) -> Dictionary:
	for spawn_point: Dictionary in SPAWN_POINTS:
		if StringName(spawn_point.get("route_id", &"")) == route_id:
			return spawn_point.duplicate(true)
	return {}


static func get_active_spawn_point_ids(scenario_id: StringName) -> Array[StringName]:
	var scenario := get_scenario(scenario_id)
	var result: Array[StringName] = []
	for spawn_point_id: StringName in scenario.get("active_spawn_point_ids", []):
		result.append(spawn_point_id)
	return result


static func get_spawn_point_position(
	spawn_point_id: StringName,
	battlefield_size: Vector2
) -> Vector2:
	var spawn_point := get_spawn_point(spawn_point_id)
	var route_id := StringName(spawn_point.get("route_id", &""))
	var route_points := get_route_points(route_id, battlefield_size)
	if not route_points.is_empty():
		return route_points[0]
	var normalized: Vector2 = spawn_point.get(
		"normalized_position",
		Vector2.ZERO
	)
	var safe_size := battlefield_size
	if safe_size.x <= 0.0 or safe_size.y <= 0.0:
		safe_size = DEFAULT_BATTLEFIELD_SIZE
	return Vector2(normalized.x * safe_size.x, normalized.y * safe_size.y)


static func are_route_groups_compatible(
	first_group_id: StringName,
	second_group_id: StringName
) -> bool:
	if first_group_id == &"" or second_group_id == &"":
		return false
	var compatible: Array = ROUTE_GROUP_COMPATIBILITY.get(first_group_id, [])
	return compatible.has(second_group_id)


static func get_formation_route_index(route_id: StringName) -> int:
	var route_data := get_route_runtime_data(route_id)
	return int(route_data.get("formation_route_index", 0))


static func is_neighbor_route_span_allowed(
	first_route_index: int,
	second_route_index: int,
	neighbor_route_span: int
) -> bool:
	return (
		abs(first_route_index - second_route_index)
			<= maxi(0, neighbor_route_span)
	)


static func get_formation_zones(battlefield_size: Vector2) -> Array:
	var safe_size := battlefield_size
	if safe_size.x <= 0.0 or safe_size.y <= 0.0:
		safe_size = DEFAULT_BATTLEFIELD_SIZE
	var result: Array = []
	for zone: Dictionary in FORMATION_ZONES:
		var copy := zone.duplicate(true)
		var normalized: Rect2 = zone.get("normalized_rect", Rect2())
		copy["rect"] = Rect2(
			Vector2(
				normalized.position.x * safe_size.x,
				normalized.position.y * safe_size.y
			),
			Vector2(
				normalized.size.x * safe_size.x,
				normalized.size.y * safe_size.y
			)
		)
		result.append(copy)
	return result


static func get_formation_zone_by_type(
	zone_type: StringName,
	battlefield_size: Vector2
) -> Dictionary:
	for zone: Dictionary in get_formation_zones(battlefield_size):
		if StringName(zone.get("zone_type", &"")) == zone_type:
			return zone
	return {}


static func get_formation_zone_at_position(
	world_position: Vector2,
	route_group_id: StringName,
	battlefield_size: Vector2
) -> Dictionary:
	for zone: Dictionary in get_formation_zones(battlefield_size):
		var allowed_groups: Array = zone.get("allowed_route_group_ids", [])
		var rect: Rect2 = zone.get("rect", Rect2())
		if allowed_groups.has(route_group_id) and rect.has_point(world_position):
			return zone
	return {}


static func is_within_ellipse(
	first_position: Vector2,
	second_position: Vector2,
	radius_x: float,
	radius_y: float
) -> bool:
	return normalized_ellipse_distance(
		first_position,
		second_position,
		radius_x,
		radius_y
	) <= 1.0


static func normalized_ellipse_distance(
	first_position: Vector2,
	second_position: Vector2,
	radius_x: float,
	radius_y: float
) -> float:
	if radius_x <= 0.0 or radius_y <= 0.0:
		return INF
	var difference := second_position - first_position
	return (
		(difference.x / radius_x) * (difference.x / radius_x)
		+ (difference.y / radius_y) * (difference.y / radius_y)
	)


static func get_monster_type_ids() -> Array[StringName]:
	return MONSTER_TYPE_IDS.duplicate()


static func get_monster_definition(monster_type: StringName) -> Dictionary:
	return MONSTER_DEFINITIONS.get(monster_type, MONSTER_DEFINITIONS[&"charge"]).duplicate(
		true
	)


static func get_formation_color(monster_type: StringName) -> Color:
	return FORMATION_COLORS.get(monster_type, Color.WHITE)


static func get_formation_effect(
	monster_type: StringName,
	formation_level: StringName
) -> Dictionary:
	var definition := get_monster_definition(monster_type)
	var configured_effects: Dictionary = definition.get("formation_effects", {})
	if configured_effects.has(formation_level):
		return Dictionary(configured_effects[formation_level]).duplicate(true)
	if monster_type == &"charge":
		if formation_level == FORMATION_LEVEL_A:
			return {
				"move_speed_multiplier": CHARGE_A_SPEED_MULTIPLIER,
				"effect_text": "移速 +25%",
			}
		if formation_level == FORMATION_LEVEL_B:
			return {
				"move_speed_multiplier": CHARGE_B_SPEED_MULTIPLIER,
				"control_resistance_charges": 1,
				"effect_text": "蓄力冲锋｜移速 +50%｜控制抵抗 1次",
			}
	if monster_type == &"shield":
		if formation_level == FORMATION_LEVEL_A:
			return {
				"ranged_damage_reduction": SHIELD_A_RANGED_REDUCTION,
				"effect_text": "远程减伤 35%",
			}
		if formation_level == FORMATION_LEVEL_B:
			return {
				"ranged_damage_reduction": SHIELD_B_RANGED_REDUCTION,
				"ally_ranged_reduction": SHIELD_B_ALLY_RANGED_REDUCTION,
				"protection_radius": SHIELD_B_PROTECTION_RADIUS,
				"effect_text": "远程减伤 60%｜友军保护 30%",
			}
	return {}


static func retains_a_effect_while_forming_b(monster_type: StringName) -> bool:
	return bool(
		get_monster_definition(monster_type).get(
			"retain_a_effect_while_forming_b",
			true
		)
	)


static func get_route_points(
	route_id: StringName,
	battlefield_size: Vector2
) -> PackedVector2Array:
	var safe_size := battlefield_size
	if safe_size.x <= 0.0 or safe_size.y <= 0.0:
		safe_size = DEFAULT_BATTLEFIELD_SIZE
	if FORMATION_COMPATIBLE_ROUTE_IDS.has(route_id):
		var route_index := get_formation_route_index(route_id)
		var route_offset := float(
			route_index - FORMATION_ROUTE_CENTER_INDEX
		) * FORMATION_ROUTE_SPACING_Y
		var center_y := safe_size.y * 0.5
		var formation_points := PackedVector2Array()
		for point_index in range(FORMATION_ROUTE_X_FACTORS.size()):
			formation_points.append(Vector2(
				FORMATION_ROUTE_X_FACTORS[point_index] * safe_size.x,
				center_y
					+ route_offset
						* FORMATION_ROUTE_OFFSET_FACTORS[point_index]
			))
		return formation_points
	var points := PackedVector2Array()
	for normalized_point: Vector2 in ROUTE_POINTS_NORMALIZED.get(route_id, []):
		points.append(Vector2(
			normalized_point.x * safe_size.x,
			normalized_point.y * safe_size.y
		))
	return points


static func get_nearest_formation_route_index(
	world_position: Vector2,
	route_group_id: StringName,
	battlefield_size: Vector2
) -> int:
	var best_index := FORMATION_ROUTE_CENTER_INDEX
	var best_route_id: StringName = &""
	var best_distance_squared := INF
	for route_id: StringName in FORMATION_COMPATIBLE_ROUTE_IDS:
		var route_data := get_route_runtime_data(route_id)
		if not are_route_groups_compatible(
			route_group_id,
			StringName(route_data.get("route_group_id", &""))
		):
			continue
		var distance_squared := get_polyline_distance_squared(
			world_position,
			get_route_points(route_id, battlefield_size)
		)
		var route_index := int(
			route_data.get("formation_route_index", FORMATION_ROUTE_CENTER_INDEX)
		)
		if (
			distance_squared < best_distance_squared - 0.0001
			or (
				is_equal_approx(distance_squared, best_distance_squared)
				and (
					route_index < best_index
					or (
						route_index == best_index
						and (
							best_route_id == &""
							or String(route_id) < String(best_route_id)
						)
					)
				)
			)
		):
			best_distance_squared = distance_squared
			best_index = route_index
			best_route_id = route_id
	return best_index


static func get_polyline_distance_squared(
	world_position: Vector2,
	points: PackedVector2Array
) -> float:
	if points.is_empty():
		return INF
	if points.size() == 1:
		return world_position.distance_squared_to(points[0])
	var best_distance_squared := INF
	for point_index in range(points.size() - 1):
		var start := points[point_index]
		var finish := points[point_index + 1]
		var segment := finish - start
		var segment_length_squared := segment.length_squared()
		var progress := 0.0
		if segment_length_squared > 0.0:
			progress = clampf(
				(world_position - start).dot(segment) / segment_length_squared,
				0.0,
				1.0
			)
		var closest := start + segment * progress
		best_distance_squared = minf(
			best_distance_squared,
			world_position.distance_squared_to(closest)
		)
	return best_distance_squared


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


static func get_recommended_deployment(
	scenario_id: StringName = &""
) -> Dictionary:
	if scenario_id in [
		&"formation_demo", &"command_demo", &"wave_validation", &"pacing_validation",
		&"formation_guard_validation",
		&"rush_raider_validation",
		&"mixed_threat_validation",
	]:
		return FORMATION_DEMO_DEPLOYMENT.duplicate(true)
	return RECOMMENDED_DEPLOYMENT.duplicate(true)


static func get_scenario_ids() -> Array[StringName]:
	return SCENARIO_IDS.duplicate()


static func get_scenario(scenario_id: StringName) -> Dictionary:
	return SCENARIOS.get(scenario_id, SCENARIOS[&"survival"]).duplicate(true)


static func get_wave_battle_config(battle_id: StringName) -> Dictionary:
	return WAVE_BATTLES.get(battle_id, {}).duplicate(true)


static func get_spawn_point_lane_map() -> Dictionary:
	var result: Dictionary = {}
	for spawn_point: Dictionary in SPAWN_POINTS:
		result[StringName(spawn_point.get("spawn_point_id", &""))] = StringName(
			spawn_point.get("route_id", &"")
		)
	return result


static func get_scenario_spawn_entries(scenario_id: StringName) -> Array[Dictionary]:
	var scenario := get_scenario(scenario_id)
	var inherited_plan := StringName(scenario.get("inherit_spawn_plan", &""))
	if inherited_plan != &"" and inherited_plan != scenario_id:
		return get_scenario_spawn_entries(inherited_plan)
	var entries: Array[Dictionary] = []
	if scenario.has("spawn_entries"):
		for entry: Dictionary in scenario.get("spawn_entries", []):
			var resolved_entry := entry.duplicate(true)
			var spawn_point_id := StringName(
				resolved_entry.get("spawn_point_id", &"")
			)
			var spawn_point := get_spawn_point(spawn_point_id)
			if not spawn_point.is_empty():
				for key: String in [
					"route_id",
					"route_group_id",
					"blocking_lane_id",
					"formation_route_index",
				]:
					if not resolved_entry.has(key):
						resolved_entry[key] = spawn_point.get(key)
			var route_id := StringName(resolved_entry.get("route_id", &"top"))
			var route_data := get_route_runtime_data(route_id)
			if not resolved_entry.has("route_group_id"):
				resolved_entry["route_group_id"] = route_data.get(
					"route_group_id",
					&""
				)
			if not resolved_entry.has("blocking_lane_id"):
				resolved_entry["blocking_lane_id"] = route_data.get(
					"blocking_lane_id",
					route_id
				)
			if not resolved_entry.has("formation_route_index"):
				resolved_entry["formation_route_index"] = route_data.get(
					"formation_route_index",
					0
				)
			entries.append(resolved_entry)
		return entries
	for route_id: StringName in scenario.get("route_sequence", []):
		var route_data := get_route_runtime_data(route_id)
		entries.append({
			"route_id": route_id,
			"route_group_id": route_data.get("route_group_id", &""),
			"blocking_lane_id": route_data.get("blocking_lane_id", route_id),
			"formation_route_index": route_data.get("formation_route_index", 0),
			"monster_type": &"charge",
		})
	return entries

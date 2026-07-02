class_name BattleVisualRegistry
extends RefCounted

const BASE_SIZE := Vector2(1920, 1080)
const EMPTY_ID := &""

const VISUALS := {
	&"guard": {
		"frames": "res://assets/art/characters/sprite_frames/ZhanShi_frames.tres",
		"scale": Vector2(1.2, 1.2),
		"offset": Vector2(0, -42),
		"flip_h": false,
		"click_area": Vector2(150, 210),
		"hp_offset": Vector2(0, -145),
		"impact_frame": 3,
	},
	&"hunter": {
		"frames": "res://assets/art/characters/sprite_frames/YouXia_frames.tres",
		"scale": Vector2(0.88, 0.88),
		"offset": Vector2(0, -40),
		"flip_h": false,
		"click_area": Vector2(145, 205),
		"hp_offset": Vector2(0, -142),
		"impact_frame": 4,
	},
	&"mage": {
		"frames": "res://assets/art/characters/sprite_frames/FaShi_frames.tres",
		"scale": Vector2(0.88, 0.88),
		"offset": Vector2(0, -40),
		"flip_h": false,
		"click_area": Vector2(145, 205),
		"hp_offset": Vector2(0, -142),
		"impact_frame": 4,
	},
	&"doctor": {
		"frames": "res://assets/art/characters/sprite_frames/ZhiLiao_frames.tres",
		"scale": Vector2(0.86, 0.86),
		"offset": Vector2(0, -38),
		"flip_h": false,
		"click_area": Vector2(145, 205),
		"hp_offset": Vector2(0, -138),
		"impact_frame": 4,
	},
	&"forest_slime": {
		"frames": "res://assets/art/monster/sprite_frames/monster01_frames.tres",
		"scale": Vector2(0.78, 0.78),
		"offset": Vector2(0, -28),
		"flip_h": false,
		"click_area": Vector2(160, 140),
		"hp_offset": Vector2(0, -112),
		"impact_frame": 4,
	},
	&"ruins_guard": {
		"frames": "res://assets/art/boss/sprite_frames/ShuJing_frames.tres",
		"scale": Vector2(1.62, 1.62),
		"offset": Vector2(0, -18),
		"flip_h": false,
		"click_area": Vector2(270, 330),
		"hp_offset": Vector2(0, -250),
		"impact_frame": 4,
	},
	&"fire_boss": {
		"frames": "res://assets/art/boss/sprite_frames/HuoYuanSu_frames.tres",
		"scale": Vector2(1.58, 1.58),
		"offset": Vector2(0, -18),
		"flip_h": false,
		"click_area": Vector2(270, 330),
		"hp_offset": Vector2(0, -248),
		"impact_frame": 4,
	},
}

const ALLY_POSITIONS := {
	&"guard": Vector2(500, 570),
	&"hunter": Vector2(320, 420),
	&"mage": Vector2(320, 730),
	&"doctor": Vector2(170, 560),
}
const NORMAL_ENEMY_POSITIONS := [
	Vector2(1400, 440),
	Vector2(1510, 700),
	Vector2(1515, 540),
]
const BOSS_POSITION := Vector2(1450, 570)


func get_visual_key(unit: Dictionary) -> StringName:
	var unit_id: StringName = unit.get("battle_visual_id", unit.get("unit_id", EMPTY_ID))
	if VISUALS.has(unit_id):
		return unit_id
	if String(unit_id).begins_with("forest_slime"):
		return &"forest_slime"
	return unit_id


func get_visual(unit: Dictionary) -> Dictionary:
	var key := get_visual_key(unit)
	return VISUALS.get(key, {}).duplicate(true)


func get_frames(unit: Dictionary) -> SpriteFrames:
	var visual := get_visual(unit)
	var frames_path := String(visual.get("frames", ""))
	if frames_path.is_empty():
		return null
	return load(frames_path)


func get_base_position(unit: Dictionary, side_index: int = 0) -> Vector2:
	var unit_id: StringName = unit.get("unit_id", EMPTY_ID)
	if bool(unit.get("is_player_unit", false)):
		return ALLY_POSITIONS.get(unit_id, Vector2(340, 560))
	if String(unit.get("ai_type", "normal")) == "boss" or unit_id == &"ruins_guard":
		return BOSS_POSITION
	var index := clampi(side_index, 0, NORMAL_ENEMY_POSITIONS.size() - 1)
	return NORMAL_ENEMY_POSITIONS[index]


func scale_position(base_position: Vector2, battlefield_size: Vector2) -> Vector2:
	if battlefield_size.x <= 0.0 or battlefield_size.y <= 0.0:
		return base_position
	return Vector2(
		base_position.x / BASE_SIZE.x * battlefield_size.x,
		base_position.y / BASE_SIZE.y * battlefield_size.y
	)

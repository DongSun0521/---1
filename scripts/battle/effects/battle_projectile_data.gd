class_name BattleProjectileData
extends Resource

enum TravelType {
	LINEAR,
	ARC,
	BEZIER,
}

@export var projectile_id: StringName = &""
@export var effect_id: StringName = &""
@export var travel_type: TravelType = TravelType.LINEAR
@export var travel_duration: float = 0.3
@export var arc_height: float = 0.0
@export var rotate_to_direction: bool = true
@export var source_anchor: StringName = &"weapon"
@export var target_anchor: StringName = &"center"
@export var source_offset: Vector2 = Vector2.ZERO
@export var target_offset: Vector2 = Vector2.ZERO
@export var impact_effect_id: StringName = &""


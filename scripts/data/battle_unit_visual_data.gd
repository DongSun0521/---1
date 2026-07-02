class_name BattleUnitVisualData
extends Resource

@export var unit_id: StringName
@export var sprite_frames: SpriteFrames
@export var display_scale: Vector2 = Vector2.ONE
@export var sprite_offset: Vector2 = Vector2.ZERO
@export var default_flip_h: bool = false
@export var idle_animation: StringName = &"idle"
@export var attack_animation: StringName = &"attack"
@export var hit_animation: StringName = &"hit"
@export var death_animation: StringName = &"death"
@export var attack_impact_frame: int = 3
@export var click_area_size: Vector2 = Vector2(180, 240)
@export var hp_bar_offset: Vector2 = Vector2(0, -138)

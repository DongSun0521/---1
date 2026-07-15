class_name BattleEffectContext
extends RefCounted

var source_view
var target_view
var world_position: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.RIGHT
var layer_override: StringName = &""
var duration_override: float = -1.0
var anchor_override: StringName = &""
var scale_multiplier: Vector2 = Vector2.ONE
var speed_scale: float = 1.0

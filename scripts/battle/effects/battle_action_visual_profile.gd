class_name BattleActionVisualProfile
extends Resource

enum ImpactTiming {
	IMMEDIATE,
	PROJECTILE_ARRIVAL,
	EFFECT_FRAME,
	DELAY,
}

@export var action_id: StringName = &""
@export var cast_effect_id: StringName = &""
@export var warning_effect_id: StringName = &""
@export var projectile_id: StringName = &""
@export var impact_effect_id: StringName = &""
@export var release_frame: int = -1
@export var warning_duration: float = 0.0
@export var impact_timing: ImpactTiming = ImpactTiming.IMMEDIATE
@export var impact_delay: float = 0.0
@export var effect_impact_frame: int = -1
@export var spawn_per_target: bool = true
@export var play_source_animation_once: bool = true
@export var source_anchor: StringName = &"weapon"
@export var target_anchor: StringName = &"center"
@export var projectile_scale_override: Vector2 = Vector2.ONE
@export var impact_scale_override: Vector2 = Vector2.ONE
@export var effect_scale_override: Vector2 = Vector2.ONE
@export var projectile_duration_override: float = -1.0
@export var effect_speed_scale: float = 1.0
@export var skip_source_animation: bool = false
@export var source_animation_name: StringName = &"attack"
@export var source_animation_speed_scale: float = 1.0
@export var target_stagger_offset: float = 0.0
@export var target_recoil_distance: float = 0.0
@export var visual_override_id: StringName = &""
@export var projectile_override_id: StringName = &""
@export var impact_effect_override_id: StringName = &""
@export var cast_sound_id: StringName = &""
@export var impact_sound_id: StringName = &""
@export var camera_shake_id: StringName = &""
@export var screen_flash_id: StringName = &""
@export var hit_stop_duration: float = 0.0

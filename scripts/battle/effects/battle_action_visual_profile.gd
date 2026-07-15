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
@export var cast_sound_id: StringName = &""
@export var impact_sound_id: StringName = &""
@export var camera_shake_id: StringName = &""
@export var screen_flash_id: StringName = &""
@export var hit_stop_duration: float = 0.0


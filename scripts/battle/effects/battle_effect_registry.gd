class_name BattleEffectRegistry
extends Node

const EffectDataScript := preload("res://scripts/battle/effects/battle_effect_data.gd")
const ProjectileDataScript := preload("res://scripts/battle/effects/battle_projectile_data.gd")
const ProfileScript := preload("res://scripts/battle/effects/battle_action_visual_profile.gd")

const EFFECT_PATHS := {
	&"arrow": "res://assets/art/effect/projectiles/arrow.png",
	&"magic_bolt": "res://assets/art/effect/sprite_frames/magic_bolt_frames.tres",
	&"hit_spark": "res://assets/art/effect/sprite_frames/hit_spark_frames.tres",
	&"arcane_burst": "res://assets/art/effect/sprite_frames/arcane_burst_frames.tres",
	&"heal_circle": "res://assets/art/effect/sprite_frames/heal_circle_frames.tres",
	&"warning_circle": "res://assets/art/effect/warning/warning_circle.png",
	&"earth_spike": "res://assets/art/effect/sprite_frames/earth_spike_frames.tres",
}

var effects: Dictionary = {}
var projectiles: Dictionary = {}
var action_visuals: Dictionary = {}
var warned_missing: Dictionary = {}


func _ready() -> void:
	initialize_defaults()


func initialize_defaults() -> void:
	if not effects.is_empty():
		return
	_register_effect(&"arrow", EffectDataScript.PlaybackType.STATIC_TEXTURE, EffectDataScript.SpawnAnchor.SOURCE_WEAPON, &"projectile", Vector2(0.115, 0.115), false, 5.0, true)
	_register_effect(&"magic_bolt", EffectDataScript.PlaybackType.SPRITE_FRAMES, EffectDataScript.SpawnAnchor.SOURCE_WEAPON, &"projectile", Vector2(0.58, 0.58), true, 5.0)
	_register_effect(&"hit_spark", EffectDataScript.PlaybackType.SPRITE_FRAMES, EffectDataScript.SpawnAnchor.TARGET_CENTER, &"impact", Vector2(0.42, 0.42), false, 0.58, true)
	_register_effect(&"arcane_burst", EffectDataScript.PlaybackType.SPRITE_FRAMES, EffectDataScript.SpawnAnchor.TARGET_CENTER, &"impact", Vector2(0.58, 0.58), false, 0.67)
	_register_effect(&"heal_circle", EffectDataScript.PlaybackType.SPRITE_FRAMES, EffectDataScript.SpawnAnchor.TARGET_GROUND, &"impact", Vector2(0.58, 0.58), false, 0.8)
	_register_effect(&"warning_circle", EffectDataScript.PlaybackType.STATIC_TEXTURE, EffectDataScript.SpawnAnchor.TARGET_GROUND, &"ground", Vector2(0.13, 0.065), false, 0.65, true)
	_register_effect(&"earth_spike", EffectDataScript.PlaybackType.SPRITE_FRAMES, EffectDataScript.SpawnAnchor.TARGET_GROUND, &"impact", Vector2(0.64, 0.64), false, 0.8)

	_register_projectile(&"arrow_projectile", &"arrow", 0.30, true, &"hit_spark")
	_register_projectile(&"magic_bolt_projectile", &"magic_bolt", 0.42, false, &"hit_spark")

	_register_profile(&"guard_basic_attack", &"hit_spark", &"", &"", 3, ProfileScript.ImpactTiming.IMMEDIATE)
	_register_profile(&"hunter_basic_attack", &"", &"arrow_projectile", &"", 4, ProfileScript.ImpactTiming.PROJECTILE_ARRIVAL)
	_register_profile(&"mage_basic_attack", &"", &"magic_bolt_projectile", &"", 4, ProfileScript.ImpactTiming.PROJECTILE_ARRIVAL)
	_register_profile(&"doctor_basic_attack", &"hit_spark", &"", &"", 4, ProfileScript.ImpactTiming.IMMEDIATE)
	_register_profile(&"shield_bash", &"hit_spark", &"", &"", 3, ProfileScript.ImpactTiming.IMMEDIATE)
	_register_profile(&"power_shot", &"", &"arrow_projectile", &"", 4, ProfileScript.ImpactTiming.PROJECTILE_ARRIVAL)
	_register_profile(&"arcane_blast", &"arcane_burst", &"", &"", 4, ProfileScript.ImpactTiming.EFFECT_FRAME, 0.25, 3)
	_register_profile(&"healing_art", &"heal_circle", &"", &"", 4, ProfileScript.ImpactTiming.EFFECT_FRAME, 0.25, 2)
	_register_profile(&"medicine", &"heal_circle", &"", &"", -1, ProfileScript.ImpactTiming.DELAY, 0.18, 2)
	var spike := _register_profile(&"ruins_guard_earth_spike", &"earth_spike", &"", &"warning_circle", 4, ProfileScript.ImpactTiming.EFFECT_FRAME, 0.30, 3)
	spike.warning_duration = 0.65
	_register_profile(&"enemy_basic_attack", &"hit_spark", &"", &"", 4, ProfileScript.ImpactTiming.IMMEDIATE)


func get_effect(effect_id: StringName) -> BattleEffectData:
	initialize_defaults()
	if effects.has(effect_id):
		return effects[effect_id]
	_warn_once(&"effect", effect_id)
	return null


func get_projectile(projectile_id: StringName) -> BattleProjectileData:
	initialize_defaults()
	if projectiles.has(projectile_id):
		return projectiles[projectile_id]
	_warn_once(&"projectile", projectile_id)
	return null


func get_action_visual(action_id: StringName) -> BattleActionVisualProfile:
	initialize_defaults()
	if action_visuals.has(action_id):
		return action_visuals[action_id]
	_warn_once(&"action_visual", action_id)
	return null


func _register_effect(effect_id: StringName, playback_type: int, anchor: int, layer: StringName, scale: Vector2, loop: bool, duration: float, remove_checkerboard: bool = false) -> BattleEffectData:
	var data := EffectDataScript.new()
	data.effect_id = effect_id
	data.playback_type = playback_type
	data.spawn_anchor = anchor
	data.default_z_group = layer
	data.display_scale = scale
	data.loop = loop
	data.fallback_duration = duration
	data.remove_baked_checkerboard = remove_checkerboard
	var path := String(EFFECT_PATHS.get(effect_id, ""))
	if ResourceLoader.exists(path):
		if playback_type == EffectDataScript.PlaybackType.STATIC_TEXTURE:
			data.texture = load(path)
		else:
			data.sprite_frames = load(path)
	effects[effect_id] = data
	return data


func _register_projectile(projectile_id: StringName, effect_id: StringName, duration: float, rotate: bool, impact_effect_id: StringName) -> BattleProjectileData:
	var data := ProjectileDataScript.new()
	data.projectile_id = projectile_id
	data.effect_id = effect_id
	data.travel_duration = duration
	data.rotate_to_direction = rotate
	data.impact_effect_id = impact_effect_id
	projectiles[projectile_id] = data
	return data


func _register_profile(action_id: StringName, impact_effect_id: StringName, projectile_id: StringName, warning_effect_id: StringName, release_frame: int, timing: int, delay: float = 0.0, effect_frame: int = -1) -> BattleActionVisualProfile:
	var profile := ProfileScript.new()
	profile.action_id = action_id
	profile.impact_effect_id = impact_effect_id
	profile.projectile_id = projectile_id
	profile.warning_effect_id = warning_effect_id
	profile.release_frame = release_frame
	profile.impact_timing = timing
	profile.impact_delay = delay
	profile.effect_impact_frame = effect_frame
	action_visuals[action_id] = profile
	return profile


func _warn_once(kind: StringName, resource_id: StringName) -> void:
	var key := "%s:%s" % [kind, resource_id]
	if warned_missing.has(key):
		return
	warned_missing[key] = true
	push_warning("Battle effect registry missing %s '%s'; presentation will continue without it." % [kind, resource_id])

class_name BattleProjectilePlayer
extends Node

const ContextScript := preload("res://scripts/battle/effects/battle_effect_context.gd")

signal projectile_arrived(projectile_id: StringName, target_view)

var registry: BattleEffectRegistry
var effect_player: BattleEffectPlayer
var last_impact_handle: BattleEffectHandle


func setup(effect_registry: BattleEffectRegistry, player: BattleEffectPlayer) -> void:
	registry = effect_registry
	effect_player = player


func launch_projectile(projectile_id: StringName, source_view, target_view, overrides: Dictionary = {}) -> bool:
	last_impact_handle = null
	if registry == null or effect_player == null:
		return false
	var data := registry.get_projectile(projectile_id)
	if data == null:
		return false
	var source_anchor := StringName(overrides.get("source_anchor", data.source_anchor))
	var target_anchor := StringName(overrides.get("target_anchor", data.target_anchor))
	var source_position := effect_player.get_view_anchor(source_view, source_anchor) + data.source_offset
	var target_position := effect_player.get_view_anchor(target_view, target_anchor) + data.target_offset
	var context := ContextScript.new()
	context.source_view = source_view
	context.target_view = target_view
	context.world_position = source_position
	context.layer_override = &"projectile"
	context.direction = (target_position - source_position).normalized()
	context.scale_multiplier = overrides.get("projectile_scale", Vector2.ONE)
	var handle := effect_player.play_effect(data.effect_id, context)
	if handle == null or handle.is_completed or not is_instance_valid(handle.node):
		return false
	var projectile := handle.node as Node2D
	if data.rotate_to_direction:
		projectile.rotation = (target_position - source_position).angle()
	var layer := projectile.get_parent() as Control
	var local_target := target_position - layer.global_position
	var tween := projectile.create_tween()
	# ARC and BEZIER intentionally fall back to linear travel in 11A.
	var travel_duration := float(overrides.get("travel_duration", data.travel_duration))
	if travel_duration <= 0.0:
		travel_duration = data.travel_duration
	tween.tween_property(projectile, "position", local_target, travel_duration).set_trans(Tween.TRANS_LINEAR)
	await tween.finished
	if handle.is_completed:
		return false
	effect_player.stop_effect(handle)
	var impact_effect_id := StringName(overrides.get("impact_effect_id", data.impact_effect_id))
	if impact_effect_id != &"":
		var impact_context := ContextScript.new()
		impact_context.source_view = source_view
		impact_context.target_view = target_view
		impact_context.anchor_override = target_anchor
		impact_context.scale_multiplier = overrides.get("impact_scale", Vector2.ONE)
		impact_context.speed_scale = float(overrides.get("effect_speed_scale", 1.0))
		last_impact_handle = effect_player.play_effect(impact_effect_id, impact_context)
	projectile_arrived.emit(projectile_id, target_view)
	return true

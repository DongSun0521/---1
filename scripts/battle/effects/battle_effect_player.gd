class_name BattleEffectPlayer
extends Node

const EffectDataScript := preload("res://scripts/battle/effects/battle_effect_data.gd")
const ContextScript := preload("res://scripts/battle/effects/battle_effect_context.gd")
const HandleScript := preload("res://scripts/battle/effects/battle_effect_handle.gd")
const BackendScript := preload("res://scripts/battle/effects/battle_effect_backend.gd")

var registry: BattleEffectRegistry
var layers: Dictionary = {}
var active_handles: Dictionary = {}
var static_backend = BackendScript.StaticTextureEffectBackend.new()
var frames_backend = BackendScript.SpriteFramesEffectBackend.new()
var audio_player := BattleAudioPlayer.new()
var camera_effects := BattleCameraEffects.new()
var checkerboard_material: ShaderMaterial


func setup(effect_registry: BattleEffectRegistry, effect_layers: Dictionary) -> void:
	registry = effect_registry
	layers = effect_layers.duplicate()
	checkerboard_material = create_checkerboard_material()


func play_effect(effect_id: StringName, context: BattleEffectContext = null) -> BattleEffectHandle:
	var handle := HandleScript.new()
	handle.effect_id = effect_id
	if registry == null:
		handle.finish()
		return handle
	var data := registry.get_effect(effect_id)
	if data == null:
		handle.finish()
		return handle
	if context == null:
		context = ContextScript.new()
	var instance := create_instance(data)
	if instance == null:
		handle.finish()
		return handle
	var layer_id := context.layer_override if context.layer_override != &"" else data.default_z_group
	var layer: Control = layers.get(layer_id, layers.get(&"impact", null))
	if layer == null:
		push_warning("Battle effect layer '%s' is unavailable; skipping '%s'." % [layer_id, effect_id])
		instance.queue_free()
		handle.finish()
		return handle
	layer.add_child(instance)
	instance.position = resolve_world_position(data, context) - layer.global_position + data.offset
	instance.scale = data.display_scale * context.scale_multiplier
	instance.rotation_degrees = data.rotation_degrees
	if data.remove_baked_checkerboard and instance is CanvasItem:
		instance.material = checkerboard_material
	handle.node = instance
	active_handles[instance] = handle
	audio_player.play_sfx(data.start_sound_id)
	camera_effects.play_shake(data.camera_shake_id)
	camera_effects.play_screen_flash(data.screen_flash_id)
	begin_playback(data, context, instance, handle)
	return handle


func stop_effect(handle: BattleEffectHandle) -> void:
	if handle == null or handle.is_completed:
		return
	var instance := handle.node
	if is_instance_valid(instance):
		active_handles.erase(instance)
		instance.queue_free()
	handle.finish()


func clear_all_effects() -> void:
	for raw_node in active_handles.keys():
		var instance: Node = raw_node
		var handle: BattleEffectHandle = active_handles[raw_node]
		if is_instance_valid(instance):
			instance.queue_free()
		handle.finish()
	active_handles.clear()


func get_active_effect_count() -> int:
	return active_handles.size()


func create_instance(data: BattleEffectData) -> Node2D:
	match data.playback_type:
		EffectDataScript.PlaybackType.STATIC_TEXTURE:
			if data.texture == null:
				return null
			return static_backend.create_effect_instance(data)
		EffectDataScript.PlaybackType.SPRITE_FRAMES:
			if data.sprite_frames == null:
				return null
			return frames_backend.create_effect_instance(data)
		EffectDataScript.PlaybackType.SPINE:
			push_warning("Spine effect '%s' is registered but no Spine backend is installed; skipping it." % data.effect_id)
	return null


func begin_playback(data: BattleEffectData, context: BattleEffectContext, instance: Node2D, handle: BattleEffectHandle) -> void:
	var duration := context.duration_override if context.duration_override > 0.0 else data.fallback_duration
	if instance is AnimatedSprite2D:
		var animated := instance as AnimatedSprite2D
		animated.speed_scale = maxf(0.01, context.speed_scale)
		var animation := data.animation_name
		if animated.sprite_frames.has_animation(animation):
			animated.sprite_frames.set_animation_loop(animation, data.loop)
			animated.play(animation)
	if data.effect_id == &"warning_circle":
		play_warning_pulse(instance, duration)
	duration /= maxf(0.01, context.speed_scale)
	finish_after(instance, handle, duration, data.auto_destroy)


func finish_after(instance: Node2D, handle: BattleEffectHandle, duration: float, auto_destroy: bool) -> void:
	var lifetime_timer := Timer.new()
	lifetime_timer.name = "EffectLifetime"
	lifetime_timer.one_shot = true
	instance.add_child(lifetime_timer)
	lifetime_timer.timeout.connect(complete_effect.bind(instance, handle, auto_destroy), CONNECT_ONE_SHOT)
	lifetime_timer.start(maxf(0.01, duration))


func complete_effect(instance: Node2D, handle: BattleEffectHandle, auto_destroy: bool) -> void:
	if handle.is_completed:
		return
	active_handles.erase(instance)
	if auto_destroy and is_instance_valid(instance):
		instance.queue_free()
	handle.finish()


func play_warning_pulse(instance: Node2D, duration: float) -> void:
	instance.modulate.a = 0.0
	var base_scale := instance.scale
	instance.scale = base_scale * 0.9
	var tween := instance.create_tween()
	tween.tween_property(instance, "modulate:a", 0.65, minf(0.12, duration * 0.25))
	tween.parallel().tween_property(instance, "scale", base_scale * 1.05, maxf(0.12, duration * 0.55))
	tween.tween_property(instance, "scale", base_scale * 0.94, maxf(0.08, duration * 0.20))


func resolve_world_position(data: BattleEffectData, context: BattleEffectContext) -> Vector2:
	if context.anchor_override != &"":
		return get_view_anchor(context.target_view, context.anchor_override)
	match data.spawn_anchor:
		EffectDataScript.SpawnAnchor.SOURCE_CENTER:
			return get_view_anchor(context.source_view, &"center")
		EffectDataScript.SpawnAnchor.SOURCE_WEAPON:
			return get_view_anchor(context.source_view, &"weapon")
		EffectDataScript.SpawnAnchor.TARGET_CENTER:
			return get_view_anchor(context.target_view, &"center")
		EffectDataScript.SpawnAnchor.TARGET_GROUND:
			return get_view_anchor(context.target_view, &"ground")
		EffectDataScript.SpawnAnchor.SCREEN_CENTER:
			var overlay: Control = layers.get(&"overlay", null)
			if overlay != null:
				return overlay.global_position + overlay.size * 0.5
	return context.world_position


func get_view_anchor(view, anchor_id: StringName) -> Vector2:
	if view != null and view.has_method("get_effect_anchor_global_position"):
		return view.get_effect_anchor_global_position(anchor_id)
	if view is Control:
		return view.global_position + view.size * 0.5
	return Vector2.ZERO


func create_checkerboard_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float hi = max(c.r, max(c.g, c.b));
	float lo = min(c.r, min(c.g, c.b));
	float saturation = hi - lo;
	float baked_grid = smoothstep(0.035, 0.13, saturation);
	c.a *= baked_grid;
	COLOR = c * COLOR;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

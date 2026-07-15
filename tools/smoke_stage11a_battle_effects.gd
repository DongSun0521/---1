extends SceneTree

const RegistryScript := preload("res://scripts/battle/effects/battle_effect_registry.gd")
const EffectPlayerScript := preload("res://scripts/battle/effects/battle_effect_player.gd")
const ProjectilePlayerScript := preload("res://scripts/battle/effects/battle_projectile_player.gd")
const ContextScript := preload("res://scripts/battle/effects/battle_effect_context.gd")
const UnitViewScript := preload("res://scripts/battle/battle_unit_view.gd")


func _init() -> void:
	call_deferred("run")


func run() -> void:
	assert_raw_resources()
	assert_sprite_frames()
	var host := Control.new()
	host.size = Vector2(1920, 1080)
	root.add_child(host)
	var layers := create_layers(host)
	var registry := RegistryScript.new()
	host.add_child(registry)
	registry.initialize_defaults()
	assert_registry(registry)
	var effect_player := EffectPlayerScript.new()
	host.add_child(effect_player)
	effect_player.setup(registry, layers)
	var projectile_player := ProjectilePlayerScript.new()
	host.add_child(projectile_player)
	projectile_player.setup(registry, effect_player)
	var source: BattleUnitView = create_unit_view(host, &"hunter", true, Vector2(260, 420))
	var target: BattleUnitView = create_unit_view(host, &"forest_slime_1", false, Vector2(1320, 420))
	assert_unit_anchors(source)
	assert_resolution_alignment(effect_player, layers, source, target)
	await assert_projectiles(registry, projectile_player, source, target)
	effect_player.clear_all_effects()
	await assert_effect_lifecycle(registry, effect_player, projectile_player, source, target)
	assert_missing_fallback(registry, effect_player, source, target)
	effect_player.clear_all_effects()
	assert(effect_player.get_active_effect_count() == 0)
	await create_timer(0.9).timeout
	host.queue_free()
	await process_frame
	await process_frame
	print("stage11a battle effects smoke ok")
	quit()


func assert_raw_resources() -> void:
	for path: String in [
		"res://assets/art/effect/projectiles/arrow.png",
		"res://assets/art/effect/projectiles/magic_bolt_sheet.png",
		"res://assets/art/effect/impact/hit_spark_sheet.png",
		"res://assets/art/effect/impact/arcane_burst_sheet.png",
		"res://assets/art/effect/heal/heal_circle_sheet.png",
		"res://assets/art/effect/warning/warning_circle.png",
		"res://assets/art/effect/boss/earth_spike_sheet.png",
	]:
		assert(ResourceLoader.exists(path))
		assert(load(path) is Texture2D)


func assert_sprite_frames() -> void:
	var specs := {
		"magic_bolt_frames.tres": [8, 12.0, true],
		"hit_spark_frames.tres": [7, 12.0, false],
		"arcane_burst_frames.tres": [8, 12.0, false],
		"heal_circle_frames.tres": [8, 10.0, false],
		"earth_spike_frames.tres": [8, 10.0, false],
	}
	for file_name: String in specs:
		var frames := load("res://assets/art/effect/sprite_frames/%s" % file_name) as SpriteFrames
		assert(frames != null)
		assert(frames.get_frame_count(&"play") == int(specs[file_name][0]))
		assert(is_equal_approx(frames.get_animation_speed(&"play"), float(specs[file_name][1])))
		assert(frames.get_animation_loop(&"play") == bool(specs[file_name][2]))


func assert_registry(registry) -> void:
	for effect_id: StringName in [&"arrow", &"magic_bolt", &"hit_spark", &"arcane_burst", &"heal_circle", &"warning_circle", &"earth_spike"]:
		assert(registry.get_effect(effect_id) != null)
	for projectile_id: StringName in [&"arrow_projectile", &"magic_bolt_projectile"]:
		assert(registry.get_projectile(projectile_id) != null)
	for action_id: StringName in [&"guard_basic_attack", &"hunter_basic_attack", &"mage_basic_attack", &"shield_bash", &"power_shot", &"arcane_blast", &"healing_art", &"medicine", &"ruins_guard_earth_spike"]:
		assert(registry.get_action_visual(action_id) != null)


func create_layers(host: Control) -> Dictionary:
	var result := {}
	for layer_id: StringName in [&"ground", &"unit", &"projectile", &"impact", &"floating", &"overlay"]:
		var layer := Control.new()
		layer.name = String(layer_id)
		layer.size = host.size
		host.add_child(layer)
		result[layer_id] = layer
	return result


func create_unit_view(host: Control, unit_id: StringName, is_player: bool, position: Vector2):
	var view := UnitViewScript.new()
	host.add_child(view)
	view.position = position
	view.setup({"unit_id": unit_id, "display_name": String(unit_id), "is_player_unit": is_player, "max_hp": 20, "current_hp": 20}, null, {"click_area": Vector2(160, 220), "scale": Vector2.ONE, "offset": Vector2.ZERO, "flip_h": false})
	return view


func assert_unit_anchors(view) -> void:
	for anchor_name: String in ["ProjectileOrigin", "BodyCenterAnchor", "GroundAnchor", "EffectAnchor", "DamageNumberAnchor"]:
		assert(view.get_node_or_null(anchor_name) != null)
	assert(view.get_effect_anchor_global_position(&"weapon") != view.get_effect_anchor_global_position(&"ground"))


func assert_resolution_alignment(effect_player, layers: Dictionary, source, target) -> void:
	for viewport_size: Vector2 in [Vector2(1920, 1080), Vector2(1600, 900), Vector2(1280, 720)]:
		for layer: Control in layers.values():
			layer.size = viewport_size
		source.position = Vector2(viewport_size.x * 0.16, viewport_size.y * 0.38)
		target.position = Vector2(viewport_size.x * 0.72, viewport_size.y * 0.38)
		var context := ContextScript.new()
		context.target_view = target
		context.duration_override = 0.02
		var handle = effect_player.play_effect(&"warning_circle", context)
		assert(handle != null and is_instance_valid(handle.node))
		assert(handle.node.global_position.distance_to(target.get_effect_anchor_global_position(&"ground")) < 0.5)
		effect_player.stop_effect(handle)


func assert_projectiles(registry, projectile_player, source, target) -> void:
	registry.get_projectile(&"arrow_projectile").travel_duration = 0.02
	registry.get_projectile(&"magic_bolt_projectile").travel_duration = 0.02
	assert(await projectile_player.launch_projectile(&"arrow_projectile", source, target))
	assert(await projectile_player.launch_projectile(&"arrow_projectile", target, source))
	assert(await projectile_player.launch_projectile(&"magic_bolt_projectile", source, target))


func assert_effect_lifecycle(registry, effect_player, projectile_player, source, target) -> void:
	for effect_id: StringName in [&"arrow", &"magic_bolt", &"hit_spark", &"arcane_burst", &"heal_circle", &"warning_circle", &"earth_spike"]:
		registry.get_effect(effect_id).fallback_duration = 0.01
	registry.get_projectile(&"arrow_projectile").travel_duration = 0.005
	registry.get_projectile(&"magic_bolt_projectile").travel_duration = 0.005
	for index in range(100):
		var context := ContextScript.new()
		context.source_view = source
		context.target_view = target
		context.duration_override = 0.01
		match index % 6:
			0:
				effect_player.play_effect(&"hit_spark", context)
			1:
				await projectile_player.launch_projectile(&"arrow_projectile", source, target)
			2:
				await projectile_player.launch_projectile(&"magic_bolt_projectile", source, target)
			3:
				effect_player.play_effect(&"heal_circle", context)
			4:
				effect_player.play_effect(&"arcane_burst", context)
			5:
				effect_player.play_effect(&"warning_circle", context)
				effect_player.play_effect(&"earth_spike", context)
	await create_timer(0.12).timeout
	assert(effect_player.get_active_effect_count() == 0)


func assert_missing_fallback(registry, effect_player, source, target) -> void:
	assert(registry.get_effect(&"missing_effect_for_test") == null)
	assert(registry.warned_missing.size() == 1)
	assert(registry.get_effect(&"missing_effect_for_test") == null)
	var context := ContextScript.new()
	context.source_view = source
	context.target_view = target
	var handle = effect_player.play_effect(&"missing_effect_for_test", context)
	assert(handle.is_completed)

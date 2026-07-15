extends SceneTree

const VisualRegistryScript := preload("res://scripts/data/battle_visual_registry.gd")
const EffectContextScript := preload("res://scripts/battle/effects/battle_effect_context.gd")

var failed: bool = false


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var game_state = root.get_node("/root/GameState")
	game_state.start_new_game()
	game_state.start_battle(&"forest_slime_pair")
	var battle_view = load("res://features/battle/battle_view.tscn").instantiate()
	root.add_child(battle_view)
	await process_frame
	await process_frame

	check_action_ids(battle_view)
	check_profiles(battle_view.effect_registry)
	check_animation_frames(battle_view.effect_registry)
	check_character_anchors(battle_view)
	await check_layers_and_scaling(battle_view)
	await check_parallel_group_effects(battle_view)
	await check_presentation_flows(battle_view)
	await check_resolution_alignment(battle_view)
	await check_hundred_action_lifecycle(battle_view)

	battle_view.effect_player.clear_all_effects()
	require_true(battle_view.effect_player.get_active_effect_count() == 0, "effects remain after explicit cleanup")
	battle_view.queue_free()
	await process_frame
	await process_frame
	if failed:
		push_error("stage11b player presentations smoke failed")
		quit(1)
		return
	print("stage11b player presentations smoke ok")
	quit()


func check_action_ids(battle_view) -> void:
	var mappings := {
		[&"attack", &"guard"]: &"guard_basic_attack",
		[&"attack", &"hunter"]: &"hunter_basic_attack",
		[&"attack", &"mage"]: &"mage_basic_attack",
		[&"attack", &"doctor"]: &"doctor_basic_attack",
		[&"skill", &"guard"]: &"shield_bash",
		[&"skill", &"hunter"]: &"power_shot",
		[&"group_attack", &"mage"]: &"arcane_blast",
		[&"heal", &"doctor"]: &"healing_art",
		[&"medicine", &"doctor"]: &"medicine",
	}
	for key: Array in mappings:
		var actual: StringName = battle_view.resolve_visual_action_id({"action_type": key[0], "source_id": key[1]})
		require_true(actual == mappings[key], "wrong visual action mapping for %s/%s" % [key[0], key[1]])


func check_profiles(registry) -> void:
	var expected_release_frames := {
		&"guard_basic_attack": 3,
		&"shield_bash": 3,
		&"hunter_basic_attack": 5,
		&"power_shot": 5,
		&"mage_basic_attack": 5,
		&"arcane_blast": 5,
		&"doctor_basic_attack": 5,
		&"healing_art": 4,
	}
	for action_id: StringName in expected_release_frames:
		var profile = registry.get_action_visual(action_id)
		require_true(profile != null, "missing profile %s" % action_id)
		if profile != null:
			require_true(profile.release_frame == expected_release_frames[action_id], "wrong release frame for %s" % action_id)
	var defend = registry.get_action_visual(&"defend")
	var medicine = registry.get_action_visual(&"medicine")
	require_true(defend != null and defend.skip_source_animation and defend.projectile_id == &"" and defend.impact_effect_id == &"", "defend must skip attack and hit effects")
	require_true(medicine != null and medicine.skip_source_animation, "medicine must skip source animation")
	require_true(medicine.impact_effect_id == &"heal_circle" and medicine.impact_scale_override.is_equal_approx(Vector2(0.78, 0.78)), "medicine heal visual override is incorrect")
	var hunter = registry.get_action_visual(&"hunter_basic_attack")
	var power = registry.get_action_visual(&"power_shot")
	require_true(hunter.projectile_id == &"arrow_projectile" and is_equal_approx(hunter.projectile_duration_override, 0.30), "ranger basic projectile timing is incorrect")
	require_true(power.projectile_id == &"arrow_projectile" and is_equal_approx(power.projectile_duration_override, 0.24), "power shot must reuse arrow with its own timing")
	require_true(power.projectile_scale_override.is_equal_approx(Vector2(1.22, 1.22)), "power shot projectile scale is incorrect")
	var arcane = registry.get_action_visual(&"arcane_blast")
	require_true(arcane.spawn_per_target and arcane.play_source_animation_once and is_zero_approx(arcane.target_stagger_offset), "arcane blast must use parallel per-target effects and one source animation")


func check_animation_frames(registry) -> void:
	var paths := {
		&"guard_basic_attack": "res://assets/art/characters/sprite_frames/ZhanShi_frames.tres",
		&"hunter_basic_attack": "res://assets/art/characters/sprite_frames/YouXia_frames.tres",
		&"mage_basic_attack": "res://assets/art/characters/sprite_frames/FaShi_frames.tres",
		&"doctor_basic_attack": "res://assets/art/characters/sprite_frames/ZhiLiao_frames.tres",
	}
	for action_id: StringName in paths:
		var frames := load(paths[action_id]) as SpriteFrames
		var profile = registry.get_action_visual(action_id)
		require_true(frames != null and frames.has_animation(&"attack"), "missing attack animation for %s" % action_id)
		if frames != null:
			require_true(profile.release_frame >= 0 and profile.release_frame < frames.get_frame_count(&"attack"), "release frame outside animation for %s" % action_id)


func check_character_anchors(battle_view) -> void:
	var visual_registry := VisualRegistryScript.new()
	var projectile_positions := {}
	for unit_id: StringName in [&"guard", &"hunter", &"mage", &"doctor"]:
		var view = battle_view.unit_views.get(unit_id)
		var unit = battle_view.get_unit_by_id(unit_id)
		var visual: Dictionary = visual_registry.get_visual(unit)
		require_true(view != null, "missing player unit view %s" % unit_id)
		if view == null:
			continue
		var expected_projectile: Vector2 = Vector2(view.size.x * 0.78, view.size.y * 0.46) + Vector2(visual.get("projectile_origin_offset", Vector2.ZERO))
		var expected_body: Vector2 = view.size * 0.5 + Vector2(visual.get("body_center_offset", Vector2.ZERO))
		var expected_ground: Vector2 = Vector2(view.size.x * 0.5, view.size.y - 42.0) + Vector2(visual.get("ground_anchor_offset", Vector2.ZERO))
		require_true(view.projectile_origin.position.is_equal_approx(expected_projectile), "wrong projectile anchor for %s" % unit_id)
		require_true(view.body_center_anchor.position.is_equal_approx(expected_body), "wrong body anchor for %s" % unit_id)
		require_true(view.ground_anchor.position.is_equal_approx(expected_ground), "wrong ground anchor for %s" % unit_id)
		projectile_positions[unit_id] = view.projectile_origin.position
	require_true(projectile_positions[&"hunter"] != projectile_positions[&"mage"], "ranger and mage projectile origins must differ")
	require_true(projectile_positions[&"mage"] != projectile_positions[&"doctor"], "mage and healer projectile origins must differ")


func check_layers_and_scaling(battle_view) -> void:
	var doctor = battle_view.unit_views[&"doctor"]
	var context := EffectContextScript.new()
	context.target_view = doctor
	context.anchor_override = &"ground"
	context.duration_override = 0.02
	context.scale_multiplier = Vector2(0.78, 0.78)
	context.speed_scale = 1.35
	var heal_handle = battle_view.effect_player.play_effect(&"heal_circle", context)
	require_true(heal_handle.node.get_parent() == battle_view.ground_effect_layer, "heal circle must use ground layer")
	require_true(heal_handle.node.global_position.distance_to(doctor.get_effect_anchor_global_position(&"ground")) < 0.5, "heal circle is not aligned to ground anchor")
	require_true(heal_handle.node.scale.is_equal_approx(battle_view.effect_registry.get_effect(&"heal_circle").display_scale * Vector2(0.78, 0.78)), "heal circle scale override was not applied")
	battle_view.effect_player.stop_effect(heal_handle)
	var enemy = battle_view.unit_views[&"forest_slime_01"]
	context = EffectContextScript.new()
	context.target_view = enemy
	context.anchor_override = &"center"
	context.duration_override = 0.02
	var hit_handle = battle_view.effect_player.play_effect(&"hit_spark", context)
	require_true(hit_handle.node.get_parent() == battle_view.impact_effect_layer, "hit spark must use impact layer")
	require_true(hit_handle.node.global_position.distance_to(enemy.get_effect_anchor_global_position(&"center")) < 0.5, "hit spark is not aligned to body center")
	battle_view.effect_player.stop_effect(hit_handle)
	doctor.show_float_text("+1", Color.GREEN)
	await process_frame
	require_true(battle_view.floating_text_layer.get_child_count() > 0, "floating text must be above effect layers")


func check_parallel_group_effects(battle_view) -> void:
	var targets := [battle_view.unit_views[&"forest_slime_01"], battle_view.unit_views[&"forest_slime_02"]]
	var handles: Array = []
	for target in targets:
		var context := EffectContextScript.new()
		context.target_view = target
		context.anchor_override = &"center"
		context.duration_override = 0.03
		handles.append(battle_view.effect_player.play_effect(&"arcane_burst", context))
	require_true(battle_view.effect_player.get_active_effect_count() >= 2, "arcane target effects did not start in parallel")
	for handle in handles:
		if not handle.is_completed:
			await handle.completed


func check_presentation_flows(battle_view) -> void:
	var state_before: Dictionary = battle_view.game_state.get_battle_state().duplicate(true)
	for action_id: StringName in [&"guard_basic_attack", &"shield_bash", &"hunter_basic_attack", &"power_shot", &"mage_basic_attack", &"doctor_basic_attack", &"healing_art", &"medicine"]:
		var profile = battle_view.effect_registry.get_action_visual(action_id)
		profile.source_animation_speed_scale *= 8.0
		profile.effect_speed_scale *= 8.0
		if profile.projectile_duration_override > 0.0:
			profile.projectile_duration_override = 0.01
	var events := [
		{"action_type": &"attack", "source_id": &"guard", "target_ids": [&"forest_slime_01"], "damage_values": [3], "healing_values": [], "defeated_ids": []},
		{"action_type": &"skill", "source_id": &"guard", "target_ids": [&"forest_slime_01"], "damage_values": [4], "healing_values": [], "defeated_ids": []},
		{"action_type": &"attack", "source_id": &"hunter", "target_ids": [&"forest_slime_02"], "damage_values": [3], "healing_values": [], "defeated_ids": []},
		{"action_type": &"skill", "source_id": &"hunter", "target_ids": [&"forest_slime_01"], "damage_values": [5], "healing_values": [], "defeated_ids": []},
		{"action_type": &"attack", "source_id": &"mage", "target_ids": [&"forest_slime_02"], "damage_values": [3], "healing_values": [], "defeated_ids": []},
		{"action_type": &"group_attack", "source_id": &"mage", "target_ids": [&"forest_slime_01", &"forest_slime_02"], "damage_values": [2, 2], "healing_values": [], "defeated_ids": []},
		{"action_type": &"attack", "source_id": &"doctor", "target_ids": [&"forest_slime_01"], "damage_values": [2], "healing_values": [], "defeated_ids": []},
		{"action_type": &"heal", "source_id": &"doctor", "target_ids": [&"guard"], "damage_values": [], "healing_values": [4], "defeated_ids": []},
		{"action_type": &"medicine", "source_id": &"doctor", "target_ids": [&"hunter"], "damage_values": [], "healing_values": [3], "defeated_ids": []},
	]
	for event: Dictionary in events:
		await battle_view.play_presentation_event(event)
	require_true(battle_view.game_state.get_battle_state() == state_before, "presentation layer mutated authoritative battle state")
	var blocked_state: Dictionary = battle_view.game_state.get_battle_state().duplicate(true)
	battle_view.presentation_in_progress = true
	battle_view.start_action(&"basic_attack", &"forest_slime_01")
	require_true(battle_view.game_state.get_battle_state() == blocked_state, "rapid input guard allowed a duplicate action")
	battle_view.presentation_in_progress = false


func check_resolution_alignment(battle_view) -> void:
	for viewport_size: Vector2 in [Vector2(1920, 1080), Vector2(1600, 900), Vector2(1280, 720)]:
		battle_view.battlefield.size = viewport_size
		battle_view.update_unit_views(battle_view.game_state.get_battle_state())
		for unit_id: StringName in [&"hunter", &"mage", &"doctor"]:
			var view = battle_view.unit_views[unit_id]
			var weapon: Vector2 = view.get_effect_anchor_global_position(&"weapon")
			var ground: Vector2 = view.get_effect_anchor_global_position(&"ground")
			require_true(weapon.x > view.global_position.x + view.size.x * 0.5, "projectile origin moved behind %s at %s" % [unit_id, viewport_size])
			require_true(weapon.y < ground.y, "projectile origin moved to feet for %s at %s" % [unit_id, viewport_size])
		var enemy = battle_view.unit_views[&"forest_slime_01"]
		var context := EffectContextScript.new()
		context.target_view = enemy
		context.anchor_override = &"center"
		context.duration_override = 0.01
		var handle = battle_view.effect_player.play_effect(&"hit_spark", context)
		require_true(handle.node.global_position.distance_to(enemy.get_effect_anchor_global_position(&"center")) < 0.5, "impact drifted at %s" % viewport_size)
		battle_view.effect_player.stop_effect(handle)
		await process_frame


func check_hundred_action_lifecycle(battle_view) -> void:
	for effect_id: StringName in [&"hit_spark", &"arcane_burst", &"heal_circle"]:
		battle_view.effect_registry.get_effect(effect_id).fallback_duration = 0.005
	battle_view.effect_registry.get_projectile(&"arrow_projectile").travel_duration = 0.003
	battle_view.effect_registry.get_projectile(&"magic_bolt_projectile").travel_duration = 0.003
	var allies := [battle_view.unit_views[&"guard"], battle_view.unit_views[&"hunter"], battle_view.unit_views[&"mage"], battle_view.unit_views[&"doctor"]]
	var enemies := [battle_view.unit_views[&"forest_slime_01"], battle_view.unit_views[&"forest_slime_02"]]
	for index in range(100):
		var context := EffectContextScript.new()
		context.source_view = allies[index % allies.size()]
		context.target_view = enemies[index % enemies.size()]
		context.duration_override = 0.005
		match index % 5:
			0:
				battle_view.effect_player.play_effect(&"hit_spark", context)
			1:
				await battle_view.projectile_player.launch_projectile(&"arrow_projectile", context.source_view, context.target_view, {"travel_duration": 0.003})
			2:
				await battle_view.projectile_player.launch_projectile(&"magic_bolt_projectile", context.source_view, context.target_view, {"travel_duration": 0.003})
			3:
				battle_view.effect_player.play_effect(&"arcane_burst", context)
			4:
				context.target_view = allies[(index + 1) % allies.size()]
				context.anchor_override = &"ground"
				battle_view.effect_player.play_effect(&"heal_circle", context)
	await create_timer(0.08).timeout
	require_true(battle_view.effect_player.get_active_effect_count() == 0, "temporary effect count did not return to zero after 100 actions")


func require_true(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("11B CHECK: %s" % message)

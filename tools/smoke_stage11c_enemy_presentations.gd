extends SceneTree

const VisualRegistryScript := preload("res://scripts/data/battle_visual_registry.gd")
const EffectContextScript := preload("res://scripts/battle/effects/battle_effect_context.gd")

var failed := false


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var game_state = root.get_node("/root/GameState")
	var slime_view = await create_battle_view(game_state, &"forest_slime_pair")
	check_monster_ids_and_profiles(slime_view)
	check_enemy_animations()
	check_slime_independence_and_anchors(slime_view)
	await check_enemy_state_transitions(slime_view)
	await check_resolution_alignment(slime_view)
	await check_leftward_projectile(slime_view)
	await check_slime_presentation_and_fallbacks(slime_view)
	await check_hundred_enemy_actions(slime_view)
	await dispose_battle_view(slime_view)

	var boss_view = await create_battle_view(game_state, &"ruins_guard")
	check_boss_profiles(boss_view)
	await check_boss_group_presentations(boss_view)
	await check_interrupted_cleanup(boss_view)
	await dispose_battle_view(boss_view)

	await check_ten_battle_cleanup_cycles(game_state)
	if failed:
		push_error("stage11c enemy presentations smoke failed")
		quit(1)
		return
	print("stage11c enemy presentations smoke ok")
	quit()


func create_battle_view(game_state, encounter_id: StringName):
	game_state.start_new_game()
	require_true(game_state.start_battle(encounter_id), "could not start encounter %s" % encounter_id)
	var battle_view = load("res://features/battle/battle_view.tscn").instantiate()
	root.add_child(battle_view)
	await process_frame
	await process_frame
	return battle_view


func dispose_battle_view(battle_view) -> void:
	if battle_view == null or not is_instance_valid(battle_view):
		return
	battle_view.effect_player.clear_all_effects()
	require_true(battle_view.effect_player.get_active_effect_count() == 0, "effects remain before battle view disposal")
	battle_view.queue_free()
	await process_frame
	await process_frame


func check_monster_ids_and_profiles(battle_view) -> void:
	var state: Dictionary = battle_view.game_state.get_battle_state()
	var enemy_ids: Array = state.get("enemy_states", []).map(func(unit: Dictionary): return unit.get("unit_id", &""))
	require_true(enemy_ids == [&"forest_slime_01", &"forest_slime_02"], "unexpected normal monster unit IDs")
	for enemy_id: StringName in enemy_ids:
		var mapped: StringName = battle_view.resolve_visual_action_id({"action_type": &"attack", "source_id": enemy_id})
		require_true(mapped == &"monster_basic_attack", "monster attack did not map to its independent profile")
	var profile = battle_view.effect_registry.get_action_visual(&"monster_basic_attack")
	var projectile = battle_view.effect_registry.get_projectile(&"monster_magic_bolt_projectile")
	require_true(profile != null and profile.projectile_id == &"monster_magic_bolt_projectile", "monster profile is missing its projectile")
	require_true(profile.release_frame == 5 and is_equal_approx(profile.projectile_duration_override, 0.40), "monster release frame or travel duration is wrong")
	require_true(profile.projectile_scale_override.is_equal_approx(Vector2(-1.0, 1.0)), "monster projectile must face left")
	require_true(projectile != null and projectile.effect_id == &"magic_bolt" and projectile.impact_effect_id == &"hit_spark", "monster projectile must reuse magic bolt and hit spark")


func check_enemy_animations() -> void:
	var specs := {
		"res://assets/art/monster/sprite_frames/monster01_frames.tres": [6, 8, 6, 6],
		"res://assets/art/boss/sprite_frames/ShuJing_frames.tres": [6, 8, 6, 6],
		"res://assets/art/boss/sprite_frames/HuoYuanSu_frames.tres": [6, 8, 6, 6],
	}
	for path: String in specs:
		var frames := load(path) as SpriteFrames
		require_true(frames != null, "missing enemy SpriteFrames %s" % path)
		if frames == null:
			continue
		var expected: Array = specs[path]
		for index in range(4):
			var animation: StringName = [&"idle", &"attack", &"hit", &"death"][index]
			require_true(frames.has_animation(animation), "%s lacks %s" % [path, animation])
			require_true(frames.get_frame_count(animation) == int(expected[index]), "%s has wrong %s frame count" % [path, animation])


func check_slime_independence_and_anchors(battle_view) -> void:
	var first = battle_view.unit_views.get(&"forest_slime_01")
	var second = battle_view.unit_views.get(&"forest_slime_02")
	require_true(first != null and second != null and first != second, "two monsters do not have independent unit views")
	if first == null or second == null:
		return
	require_true(first.sprite != second.sprite, "two monsters share one animation player")
	require_true(first.hp_bar != second.hp_bar and first.click_button != second.click_button, "two monsters share UI state")
	var visual: Dictionary = VisualRegistryScript.new().get_visual(battle_view.get_unit_by_id(&"forest_slime_01"))
	var expected_projectile: Vector2 = Vector2(first.size.x * 0.22, first.size.y * 0.46) + Vector2(visual.get("projectile_origin_offset", Vector2.ZERO))
	var expected_body: Vector2 = first.size * 0.5 + Vector2(visual.get("body_center_offset", Vector2.ZERO))
	var expected_ground: Vector2 = Vector2(first.size.x * 0.5, first.size.y - 42.0) + Vector2(visual.get("ground_anchor_offset", Vector2.ZERO))
	require_true(first.projectile_origin.position.is_equal_approx(expected_projectile), "slime projectile anchor does not use visual data")
	require_true(first.body_center_anchor.position.is_equal_approx(expected_body), "slime body anchor does not use visual data")
	require_true(first.ground_anchor.position.is_equal_approx(expected_ground), "slime ground anchor does not use visual data")
	require_true(first.projectile_origin.position.x < first.size.x * 0.5, "slime projectile origin is behind the player-facing mouth")
	require_true(first.projectile_origin.position.y < first.ground_anchor.position.y, "slime projectile origin is at its feet")
	first.sprite.play(&"attack")
	require_true(second.sprite.animation == &"idle", "one slime attack changed the other slime animation")
	first.play_idle()


func check_leftward_projectile(battle_view) -> void:
	var source = battle_view.unit_views[&"forest_slime_01"]
	var target = battle_view.unit_views[&"guard"]
	var source_position: Vector2 = source.get_effect_anchor_global_position(&"weapon")
	var target_position: Vector2 = target.get_effect_anchor_global_position(&"center")
	require_true(target_position.x < source_position.x, "monster target is not left of projectile source")
	battle_view.effect_registry.get_effect(&"hit_spark").fallback_duration = 0.01
	battle_view.projectile_player.launch_projectile(&"monster_magic_bolt_projectile", source, target, {"travel_duration": 5.0})
	await process_frame
	var dead_source: Dictionary = battle_view.get_unit_by_id(&"forest_slime_01").duplicate(true)
	dead_source["current_hp"] = 0
	source.update_state(dead_source, true)
	require_true(battle_view.projectile_layer.get_child_count() == 1, "monster projectile did not enter ProjectileLayer")
	if battle_view.projectile_layer.get_child_count() > 0:
		var projectile_node := battle_view.projectile_layer.get_child(0) as Node2D
		var start_x := projectile_node.global_position.x
		await process_frame
		await process_frame
		require_true(is_instance_valid(projectile_node) and projectile_node.global_position.x < start_x, "monster projectile did not travel left toward the player")
	battle_view.effect_player.clear_all_effects()
	await process_frame
	await process_frame
	require_true(battle_view.projectile_layer.get_child_count() == 0, "monster projectile remained after arrival")
	source.update_state(battle_view.get_unit_by_id(&"forest_slime_01"), false)
	source.play_idle()


func check_enemy_state_transitions(battle_view) -> void:
	var first = battle_view.unit_views[&"forest_slime_01"]
	var second = battle_view.unit_views[&"forest_slime_02"]
	await first.play_hit_or_death(false)
	require_true(first.sprite.animation == &"idle" and second.sprite.animation == &"idle", "slime hit did not return only the hit monster to idle")
	var defeated: Dictionary = battle_view.get_unit_by_id(&"forest_slime_01").duplicate(true)
	defeated["current_hp"] = 0
	first.update_state(defeated, true)
	await create_timer(0.85).timeout
	require_true(first.sprite.animation == &"death" and not first.sprite.is_playing(), "slime death did not hold its final frame")
	require_true(first.click_button.disabled and second.sprite.animation == &"idle", "slime death affected the other instance or left click enabled")
	first.update_state(battle_view.get_unit_by_id(&"forest_slime_01"), false)
	first.play_idle()


func check_resolution_alignment(battle_view) -> void:
	for viewport_size: Vector2 in [Vector2(1920, 1080), Vector2(1600, 900), Vector2(1280, 720)]:
		battle_view.battlefield.size = viewport_size
		battle_view.update_unit_views(battle_view.game_state.get_battle_state())
		for slime_id: StringName in [&"forest_slime_01", &"forest_slime_02"]:
			var slime = battle_view.unit_views[slime_id]
			var weapon: Vector2 = slime.get_effect_anchor_global_position(&"weapon")
			var body: Vector2 = slime.get_effect_anchor_global_position(&"center")
			var ground: Vector2 = slime.get_effect_anchor_global_position(&"ground")
			require_true(weapon.x < slime.global_position.x + slime.size.x * 0.5, "slime projectile origin moved behind it at %s" % viewport_size)
			require_true(weapon.y < ground.y and body.y < ground.y, "slime body/weapon anchor moved to its feet at %s" % viewport_size)
		var guard = battle_view.unit_views[&"guard"]
		var context := EffectContextScript.new()
		context.target_view = guard
		context.anchor_override = &"center"
		context.duration_override = 0.01
		var hit = battle_view.effect_player.play_effect(&"hit_spark", context)
		require_true(hit.node != null and hit.node.global_position.distance_to(guard.get_effect_anchor_global_position(&"center")) < 0.5, "enemy hit spark drifted at %s" % viewport_size)
		battle_view.effect_player.stop_effect(hit)
		await process_frame


func check_slime_presentation_and_fallbacks(battle_view) -> void:
	var profile = battle_view.effect_registry.get_action_visual(&"monster_basic_attack")
	profile.source_animation_speed_scale = 20.0
	profile.projectile_duration_override = 0.01
	battle_view.effect_registry.get_effect(&"hit_spark").fallback_duration = 0.01
	var state_before: Dictionary = battle_view.game_state.get_battle_state().duplicate(true)
	for event: Dictionary in [
		{"action_type": &"attack", "source_id": &"forest_slime_01", "target_ids": [&"hunter"], "damage_values": [3], "healing_values": [], "defeated_ids": []},
		{"action_type": &"attack", "source_id": &"forest_slime_02", "target_ids": [&"mage"], "damage_values": [4], "healing_values": [], "defeated_ids": []},
	]:
		await battle_view.play_presentation_event(event)
	require_true(battle_view.game_state.get_battle_state() == state_before, "enemy presentation mutated authoritative battle state")
	require_true(battle_view.unit_views[&"forest_slime_01"].sprite.animation == &"idle", "first slime did not return to idle")
	require_true(battle_view.unit_views[&"forest_slime_02"].sprite.animation == &"idle", "second slime did not return to idle")

	var missing_target_event := {"action_type": &"attack", "source_id": &"forest_slime_01", "target_ids": [&"missing_player_view"], "damage_values": [3], "healing_values": [], "defeated_ids": []}
	await battle_view.play_presentation_event(missing_target_event)
	require_true(battle_view.unit_views[&"forest_slime_01"].sprite.animation == &"idle", "missing target fallback left source outside idle")

	var original_projectile: StringName = profile.projectile_id
	profile.projectile_id = &"missing_monster_projectile_for_test"
	await battle_view.play_presentation_event({"action_type": &"attack", "source_id": &"forest_slime_01", "target_ids": [&"guard"], "damage_values": [3], "healing_values": [], "defeated_ids": []})
	profile.projectile_id = original_projectile
	require_true(battle_view.effect_registry.warned_missing.has("projectile:missing_monster_projectile_for_test"), "missing projectile did not warn once")
	require_true(battle_view.effect_player.get_active_effect_count() == 0, "missing projectile fallback left effects active")


func check_hundred_enemy_actions(battle_view) -> void:
	battle_view.effect_registry.get_effect(&"magic_bolt").fallback_duration = 0.01
	battle_view.effect_registry.get_effect(&"hit_spark").fallback_duration = 0.005
	var sources := [battle_view.unit_views[&"forest_slime_01"], battle_view.unit_views[&"forest_slime_02"]]
	var targets := [battle_view.unit_views[&"guard"], battle_view.unit_views[&"hunter"], battle_view.unit_views[&"mage"], battle_view.unit_views[&"doctor"]]
	for index in range(100):
		var source = sources[index % sources.size()]
		var target = targets[index % targets.size()]
		await battle_view.projectile_player.launch_projectile(&"monster_magic_bolt_projectile", source, target, {"travel_duration": 0.002})
	await create_timer(0.05).timeout
	require_true(battle_view.effect_player.get_active_effect_count() == 0, "temporary nodes did not return to zero after 100 enemy actions")


func check_boss_profiles(battle_view) -> void:
	require_true(battle_view.resolve_visual_action_id({"action_type": &"attack", "source_id": &"ruins_guard"}) == &"ruins_guard_basic_attack", "tree ordinary attack mapping is wrong")
	require_true(battle_view.resolve_visual_action_id({"action_type": &"group_attack", "source_id": &"ruins_guard"}) == &"ruins_guard_earth_spike", "tree group attack mapping is wrong")
	var basic = battle_view.effect_registry.get_action_visual(&"ruins_guard_basic_attack")
	var spike = battle_view.effect_registry.get_action_visual(&"ruins_guard_earth_spike")
	require_true(basic != null and basic.warning_effect_id == &"" and basic.impact_effect_id == &"hit_spark", "tree ordinary attack incorrectly uses spike effects")
	require_true(spike != null and spike.warning_effect_id == &"warning_circle" and spike.impact_effect_id == &"earth_spike", "tree spike effects are not configured")
	require_true(spike.release_frame == 4 and is_zero_approx(spike.impact_delay) and spike.effect_impact_frame == 3, "tree spike release/impact timing is wrong")
	require_true(spike.spawn_per_target and spike.play_source_animation_once and is_zero_approx(spike.target_stagger_offset), "tree spike must play parallel per-target with one source animation")


func check_boss_group_presentations(battle_view) -> void:
	var spike = battle_view.effect_registry.get_action_visual(&"ruins_guard_earth_spike")
	spike.source_animation_speed_scale = 30.0
	spike.warning_duration = 0.03
	spike.effect_speed_scale = 30.0
	battle_view.effect_registry.get_effect(&"earth_spike").fallback_duration = 0.03
	var state_before: Dictionary = battle_view.game_state.get_battle_state().duplicate(true)
	await battle_view.play_presentation_event({"action_type": &"group_attack", "source_id": &"ruins_guard", "target_ids": [&"guard"], "damage_values": [5], "healing_values": [], "defeated_ids": []})
	await battle_view.play_presentation_event({"action_type": &"group_attack", "source_id": &"ruins_guard", "target_ids": [&"guard", &"hunter", &"mage", &"doctor"], "damage_values": [5, 5, 5, 5], "healing_values": [], "defeated_ids": []})
	await battle_view.play_presentation_event({"action_type": &"group_attack", "source_id": &"ruins_guard", "target_ids": [&"guard", &"missing_target_view"], "damage_values": [5, 5], "healing_values": [], "defeated_ids": []})
	require_true(battle_view.game_state.get_battle_state() == state_before, "tree spike presentation mutated battle results")
	require_true(battle_view.unit_views[&"ruins_guard"].sprite.animation == &"idle", "tree boss did not return to idle once group presentation finished")
	require_true(battle_view.effect_player.get_active_effect_count() == 0, "tree group presentation left warning or spike effects")


func check_interrupted_cleanup(battle_view) -> void:
	var boss = battle_view.unit_views[&"ruins_guard"]
	var guard = battle_view.unit_views[&"guard"]
	var context := EffectContextScript.new()
	context.source_view = boss
	context.target_view = guard
	context.anchor_override = &"ground"
	context.duration_override = 2.0
	battle_view.effect_player.play_effect(&"warning_circle", context)
	battle_view.effect_player.play_effect(&"earth_spike", context)
	battle_view.projectile_player.launch_projectile(&"monster_magic_bolt_projectile", boss, guard, {"travel_duration": 2.0})
	await process_frame
	require_true(battle_view.effect_player.get_active_effect_count() >= 3, "interruption setup did not create temporary enemy effects")
	battle_view.effect_player.clear_all_effects()
	require_true(battle_view.effect_player.get_active_effect_count() == 0, "battle cleanup did not remove enemy effects")
	await process_frame
	await process_frame


func check_ten_battle_cleanup_cycles(game_state) -> void:
	for cycle in range(10):
		var battle_view = await create_battle_view(game_state, &"forest_slime_pair")
		var source = battle_view.unit_views[&"forest_slime_01"]
		var target = battle_view.unit_views[&"guard"]
		var context := EffectContextScript.new()
		context.source_view = source
		context.target_view = target
		context.duration_override = 1.0
		battle_view.effect_player.play_effect(&"hit_spark", context)
		await process_frame
		battle_view.effect_player.clear_all_effects()
		var action_safety := 0
		while game_state.is_battle_active() and action_safety < 100:
			action_safety += 1
			var living_target: StringName = &""
			for enemy: Dictionary in game_state.get_battle_enemy_states():
				if int(enemy.get("current_hp", 0)) > 0:
					living_target = StringName(enemy.get("unit_id", &""))
					break
			if living_target == &"":
				break
			require_true(game_state.execute_battle_action(&"basic_attack", living_target), "battle %d rejected a valid player action" % cycle)
		require_true(not game_state.is_battle_active() and game_state.has_pending_battle_result(), "battle %d did not reach a result" % cycle)
		if game_state.has_pending_battle_result():
			game_state.complete_pending_battle_result()
		await dispose_battle_view(battle_view)


func require_true(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("11C CHECK: %s" % message)

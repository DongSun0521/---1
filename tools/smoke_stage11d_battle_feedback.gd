extends SceneTree

const SettingsScript := preload("res://scripts/battle/effects/battle_presentation_settings.gd")

var failed := false


func _init() -> void:
	call_deferred("run")


func run() -> void:
	SettingsScript.reset_defaults()
	var game_state = root.get_node("/root/GameState")
	game_state.start_new_game()
	game_state.start_battle(&"forest_slime_pair")
	var battle_view = load("res://features/battle/battle_view.tscn").instantiate()
	root.add_child(battle_view)
	await process_frame
	await process_frame

	check_audio_bus_and_settings(battle_view)
	await check_audio_pool_and_fallback(battle_view)
	check_profile_feedback_mapping(battle_view)
	await check_camera_feedback_and_toggles(battle_view)
	await check_group_feedback_deduplication(battle_view)
	await check_float_and_hit_cleanup(battle_view)
	await check_hundred_feedback_cycles(battle_view)
	await check_resolution_feedback(battle_view)
	await check_scene_cleanup(battle_view)

	battle_view.queue_free()
	await process_frame
	await process_frame
	SettingsScript.reset_defaults()
	if failed:
		push_error("stage11d battle feedback smoke failed")
		quit(1)
		return
	print("stage11d battle feedback smoke ok")
	quit()


func check_audio_bus_and_settings(battle_view) -> void:
	require_true(AudioServer.get_bus_index(&"SFX") >= 0, "SFX audio bus is missing")
	require_true(battle_view.effect_player.audio_player.players.size() == 12, "battle SFX pool must stay fixed at 12 players")
	SettingsScript.master_volume = 0.5
	SettingsScript.sfx_volume = 0.4
	battle_view.effect_player.audio_player.apply_volume_settings()
	var bus_index := AudioServer.get_bus_index(&"SFX")
	require_true(is_equal_approx(AudioServer.get_bus_volume_db(bus_index), linear_to_db(0.2)), "SFX volume did not use master*sfx settings")
	var snapshot := SettingsScript.snapshot()
	require_true(snapshot.camera_shake_enabled and snapshot.screen_flash_enabled and snapshot.hit_stop_enabled, "feedback settings defaults are wrong")
	SettingsScript.master_volume = 1.0
	SettingsScript.sfx_volume = 1.0


func check_audio_pool_and_fallback(battle_view) -> void:
	var audio = battle_view.effect_player.audio_player
	var required_sound_ids := [
		&"melee_swing", &"light_impact", &"heavy_impact", &"arrow_release", &"arrow_impact",
		&"magic_cast", &"magic_impact", &"arcane_burst", &"heal", &"defend", &"medicine",
		&"monster_cast", &"earth_spike", &"unit_hit", &"unit_death", &"battle_victory",
		&"battle_defeat", &"ui_click",
	]
	for sound_id: StringName in required_sound_ids:
		var config: Dictionary = audio.get_sound_config(sound_id)
		var path := String(config.get("path", ""))
		require_true(path.begins_with("res://assets/audio/sfx/"), "registered sound uses an invalid game path: %s" % sound_id)
		require_true(ResourceLoader.exists(path), "registered sound resource is missing: %s" % sound_id)
		var player = audio.play_sfx(sound_id)
		require_true(player != null, "registered sound could not be played: %s" % sound_id)
		audio.stop_all_battle_audio()

	var missing_id := &"stage11d_missing_sound"
	BattleAudioPlayer.warned_missing_global.erase(missing_id)
	audio.play_sfx(missing_id)
	audio.play_sfx(missing_id)
	require_true(BattleAudioPlayer.warned_missing_global.has(missing_id), "missing audio did not use warn-once fallback")

	var test_stream := AudioStreamWAV.new()
	test_stream.format = AudioStreamWAV.FORMAT_8_BITS
	test_stream.mix_rate = 8000
	test_stream.stereo = false
	var samples := PackedByteArray()
	samples.resize(8000)
	test_stream.data = samples
	audio.register_runtime_sound(&"stage11d_pool_test", test_stream, {"minimum_repeat_interval": 0.0, "max_instances": 2})
	for index in range(8):
		audio.play_sfx(&"stage11d_pool_test")
	require_true(audio.get_active_player_count() <= 2, "per-sound simultaneous limit was exceeded")
	require_true(audio.players.size() == 12, "audio player pool grew during playback")
	audio.stop_all_battle_audio()
	require_true(audio.get_active_player_count() == 0, "stop_all_battle_audio left a player active")
	await process_frame


func check_profile_feedback_mapping(battle_view) -> void:
	var specs := {
		&"guard_basic_attack": [&"melee_swing", &"light_impact", &"light_hit", 0.04, &""],
		&"shield_bash": [&"melee_swing", &"heavy_impact", &"medium_hit", 0.065, &"white_flash"],
		&"hunter_basic_attack": [&"arrow_release", &"arrow_impact", &"", 0.0, &""],
		&"power_shot": [&"arrow_release", &"heavy_impact", &"light_hit", 0.055, &"white_flash"],
		&"mage_basic_attack": [&"magic_cast", &"magic_impact", &"", 0.0, &""],
		&"arcane_blast": [&"magic_cast", &"arcane_burst", &"medium_hit", 0.055, &"blue_flash"],
		&"healing_art": [&"heal", &"", &"", 0.0, &"green_flash"],
		&"medicine": [&"medicine", &"", &"", 0.0, &""],
		&"monster_basic_attack": [&"monster_cast", &"magic_impact", &"", 0.0, &""],
		&"ruins_guard_basic_attack": [&"monster_cast", &"heavy_impact", &"medium_hit", 0.05, &""],
		&"ruins_guard_earth_spike": [&"monster_cast", &"earth_spike", &"boss_skill", 0.08, &"red_flash"],
	}
	for action_id: StringName in specs:
		var profile = battle_view.effect_registry.get_action_visual(action_id)
		var release_sound: StringName = profile.heal_sound_id
		if release_sound == &"":
			release_sound = profile.projectile_sound_id
		if release_sound == &"":
			release_sound = profile.cast_sound_id
		var expected: Array = specs[action_id]
		require_true(release_sound == expected[0], "wrong release sound for %s" % action_id)
		require_true(profile.impact_sound_id == expected[1], "wrong impact sound for %s" % action_id)
		require_true(profile.camera_shake_id == expected[2], "wrong shake mapping for %s" % action_id)
		require_true(is_equal_approx(profile.hit_stop_duration, float(expected[3])), "wrong hit-stop for %s" % action_id)
		require_true(profile.screen_flash_id == expected[4], "wrong flash mapping for %s" % action_id)


func check_camera_feedback_and_toggles(battle_view) -> void:
	var camera = battle_view.effect_player.camera_effects
	var base_position: Vector2 = battle_view.battlefield.position
	camera.play_shake(&"medium_hit")
	require_true(camera.shake_tween != null, "enabled camera shake did not start")
	await create_timer(0.20).timeout
	require_true(battle_view.battlefield.position.is_equal_approx(base_position), "camera shake left a permanent offset")

	SettingsScript.camera_shake_enabled = false
	camera.play_shake(&"heavy_hit")
	require_true(camera.shake_tween == null and battle_view.battlefield.position.is_equal_approx(base_position), "disabled camera shake still moved the battlefield")
	SettingsScript.camera_shake_enabled = true

	SettingsScript.screen_flash_enabled = true
	camera.play_screen_flash(&"blue_flash")
	require_true(battle_view.overlay_effect_layer.get_child_count() == 1, "screen flash did not use OverlayEffectLayer")
	await create_timer(0.16).timeout
	require_true(battle_view.overlay_effect_layer.get_child_count() == 0, "screen flash did not self-clean")
	SettingsScript.screen_flash_enabled = false
	camera.play_screen_flash(&"red_flash")
	require_true(battle_view.overlay_effect_layer.get_child_count() == 0, "disabled screen flash created an overlay")
	SettingsScript.screen_flash_enabled = true

	SettingsScript.hit_stop_enabled = true
	var hit_stop = camera.play_hit_stop(0.04)
	require_true(battle_view.battlefield.process_mode == Node.PROCESS_MODE_DISABLED, "hit-stop did not pause only the presentation world")
	if not hit_stop.is_completed:
		await hit_stop.completed
	require_true(battle_view.battlefield.process_mode == Node.PROCESS_MODE_INHERIT, "hit-stop did not restore presentation processing")
	SettingsScript.hit_stop_enabled = false
	hit_stop = camera.play_hit_stop(0.08)
	require_true(hit_stop.is_completed and battle_view.battlefield.process_mode == Node.PROCESS_MODE_INHERIT, "disabled hit-stop still paused presentation")
	SettingsScript.hit_stop_enabled = true


func check_group_feedback_deduplication(battle_view) -> void:
	var requested := {}
	var audio = battle_view.effect_player.audio_player
	audio.sfx_requested.connect(func(sound_id: StringName) -> void: requested[sound_id] = int(requested.get(sound_id, 0)) + 1)
	var arcane = battle_view.effect_registry.get_action_visual(&"arcane_blast")
	arcane.source_animation_speed_scale = 30.0
	arcane.effect_speed_scale = 30.0
	await battle_view.play_presentation_event({
		"action_type": &"group_attack",
		"source_id": &"mage",
		"target_ids": [&"forest_slime_01", &"forest_slime_02"],
		"damage_values": [2, 2],
		"healing_values": [],
		"defeated_ids": [],
	})
	require_true(int(requested.get(&"magic_cast", 0)) == 1, "arcane cast sound requested more than once")
	require_true(int(requested.get(&"arcane_burst", 0)) == 1, "arcane main impact sound requested per target")


func check_float_and_hit_cleanup(battle_view) -> void:
	var target = battle_view.unit_views[&"forest_slime_01"]
	target.show_float_text("-1", Color.RED)
	target.play_hit_flash()
	target.play_visual_recoil(Vector2(6, 0))
	await process_frame
	require_true(battle_view.floating_text_layer.get_child_count() > 0, "floating number is not in FloatingTextLayer")
	target.clear_presentation_visuals()
	await process_frame
	require_true(target.presentation_nodes.is_empty() and target.presentation_tweens.is_empty(), "unit feedback cleanup retained nodes or tweens")
	require_true(target.sprite.position.is_equal_approx(target.size * 0.5) and target.sprite.modulate.is_equal_approx(Color.WHITE), "hit flash/recoil cleanup did not restore the sprite")


func check_hundred_feedback_cycles(battle_view) -> void:
	SettingsScript.camera_shake_enabled = false
	SettingsScript.screen_flash_enabled = false
	SettingsScript.hit_stop_enabled = false
	var profiles := [
		battle_view.effect_registry.get_action_visual(&"guard_basic_attack"),
		battle_view.effect_registry.get_action_visual(&"power_shot"),
		battle_view.effect_registry.get_action_visual(&"arcane_blast"),
		battle_view.effect_registry.get_action_visual(&"healing_art"),
		battle_view.effect_registry.get_action_visual(&"monster_basic_attack"),
		battle_view.effect_registry.get_action_visual(&"ruins_guard_earth_spike"),
	]
	for index in range(100):
		var profile = profiles[index % profiles.size()]
		battle_view.effect_player.play_profile_release_audio(profile)
		await battle_view.effect_player.play_profile_impact_feedback(profile)
		var is_healing: bool = profile.action_id == &"healing_art"
		battle_view.play_target_feedback({
			"target_ids": [&"guard"] if is_healing else [&"forest_slime_01"],
			"damage_values": [] if is_healing else [1],
			"healing_values": [1] if is_healing else [],
			"defeated_ids": [],
		}, profile)
		for view in battle_view.unit_views.values():
			view.clear_presentation_visuals()
		await process_frame
	battle_view.effect_player.audio_player.stop_all_battle_audio()
	require_true(battle_view.effect_player.audio_player.players.size() == 12, "100 feedback cycles grew the audio pool")
	require_true(battle_view.effect_player.audio_player.get_active_player_count() == 0, "100 feedback cycles left players active after cleanup")
	require_true(battle_view.floating_text_layer.get_child_count() == 0, "100 feedback cycles left floating numbers")
	SettingsScript.camera_shake_enabled = true
	SettingsScript.screen_flash_enabled = true
	SettingsScript.hit_stop_enabled = true


func check_resolution_feedback(battle_view) -> void:
	for viewport_size: Vector2 in [Vector2(1920, 1080), Vector2(1600, 900), Vector2(1280, 720)]:
		battle_view.battlefield.size = viewport_size
		await process_frame
		battle_view.effect_player.camera_effects.play_screen_flash(&"white_flash")
		require_true(battle_view.overlay_effect_layer.size.is_equal_approx(viewport_size), "overlay layer did not follow %s" % viewport_size)
		battle_view.effect_player.camera_effects.clear_all()
		await process_frame


func check_scene_cleanup(battle_view) -> void:
	var camera = battle_view.effect_player.camera_effects
	camera.play_shake(&"boss_skill")
	camera.play_screen_flash(&"red_flash")
	var hit_stop = camera.play_hit_stop(0.10)
	battle_view.effect_player.clear_all_effects()
	await process_frame
	require_true(hit_stop.is_completed, "scene cleanup did not complete pending hit-stop")
	require_true(battle_view.battlefield.process_mode == Node.PROCESS_MODE_INHERIT, "scene cleanup left the presentation world paused")
	require_true(battle_view.battlefield.position.is_equal_approx(Vector2.ZERO), "scene cleanup left camera offset")
	require_true(battle_view.overlay_effect_layer.get_child_count() == 0, "scene cleanup left screen flashes")
	require_true(battle_view.effect_player.audio_player.get_active_player_count() == 0, "scene cleanup left audio players")


func require_true(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("11D CHECK: %s" % message)

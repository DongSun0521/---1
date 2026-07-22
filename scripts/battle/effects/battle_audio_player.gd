class_name BattleAudioPlayer
extends RefCounted

signal sfx_requested(sound_id: StringName)

const SettingsScript := preload("res://scripts/battle/effects/battle_presentation_settings.gd")
const SFX_BUS := &"SFX"
const PLAYER_POOL_SIZE := 12

# Temporary battle audio is sourced from CC0 packs documented in
# docs/audio/THIRD_PARTY_AUDIO_LICENSES.md. Paths stay centralized here so the
# presentation controller never needs to know about concrete files.
const SOUND_REGISTRY := {
	&"melee_swing": {"path": "res://assets/audio/sfx/battle/melee_swing_01.ogg", "volume_db": -4.0, "minimum_repeat_interval": 0.05, "max_instances": 2},
	&"light_impact": {"path": "res://assets/audio/sfx/battle/light_impact_01.ogg", "volume_db": -5.0, "minimum_repeat_interval": 0.05, "max_instances": 3},
	&"heavy_impact": {"path": "res://assets/audio/sfx/battle/heavy_impact_01.ogg", "volume_db": -3.0, "minimum_repeat_interval": 0.08, "max_instances": 2},
	&"arrow_release": {"path": "res://assets/audio/sfx/battle/arrow_release_01.ogg", "volume_db": -5.0, "minimum_repeat_interval": 0.05, "max_instances": 2},
	&"arrow_impact": {"path": "res://assets/audio/sfx/battle/arrow_impact_01.ogg", "volume_db": -4.0, "minimum_repeat_interval": 0.05, "max_instances": 3},
	&"magic_cast": {"path": "res://assets/audio/sfx/battle/magic_cast_01.ogg", "volume_db": -6.0, "minimum_repeat_interval": 0.06, "max_instances": 2},
	&"magic_impact": {"path": "res://assets/audio/sfx/battle/magic_impact_01.ogg", "volume_db": -6.0, "minimum_repeat_interval": 0.06, "max_instances": 3},
	&"arcane_burst": {"path": "res://assets/audio/sfx/battle/arcane_burst_01.ogg", "volume_db": -6.0, "minimum_repeat_interval": 0.14, "max_instances": 1},
	&"heal": {"path": "res://assets/audio/sfx/battle/heal_01.ogg", "volume_db": -6.0, "minimum_repeat_interval": 0.10, "max_instances": 1},
	&"defend": {"path": "res://assets/audio/sfx/battle/defend_01.ogg", "volume_db": -5.0, "minimum_repeat_interval": 0.10, "max_instances": 1},
	&"medicine": {"path": "res://assets/audio/sfx/battle/medicine_01.ogg", "volume_db": -7.0, "minimum_repeat_interval": 0.10, "max_instances": 1},
	&"monster_cast": {"path": "res://assets/audio/sfx/battle/monster_cast_01.ogg", "volume_db": -6.0, "minimum_repeat_interval": 0.06, "max_instances": 2},
	&"earth_spike": {"path": "res://assets/audio/sfx/battle/earth_spike_01.ogg", "volume_db": -4.0, "minimum_repeat_interval": 0.16, "max_instances": 1},
	&"unit_hit": {"path": "res://assets/audio/sfx/battle/unit_hit_01.ogg", "volume_db": -10.0, "minimum_repeat_interval": 0.07, "max_instances": 2},
	&"unit_death": {"path": "res://assets/audio/sfx/battle/unit_death_01.ogg", "volume_db": -5.0, "minimum_repeat_interval": 0.12, "max_instances": 2},
	&"battle_victory": {"path": "res://assets/audio/sfx/battle/battle_victory_01.ogg", "volume_db": -4.0, "minimum_repeat_interval": 0.50, "max_instances": 1},
	&"battle_defeat": {"path": "res://assets/audio/sfx/battle/battle_defeat_01.ogg", "volume_db": -4.0, "minimum_repeat_interval": 0.50, "max_instances": 1},
	&"ui_click": {"path": "res://assets/audio/sfx/ui/ui_click_01.ogg", "volume_db": -8.0, "minimum_repeat_interval": 0.04, "max_instances": 2},
	# Compatibility aliases for external callers from the pre-audio 11D build.
	&"projectile_impact": {"path": "res://assets/audio/sfx/battle/light_impact_01.ogg", "volume_db": -5.0, "minimum_repeat_interval": 0.05, "max_instances": 3},
	&"button_click": {"path": "res://assets/audio/sfx/ui/ui_click_01.ogg", "volume_db": -8.0, "minimum_repeat_interval": 0.04, "max_instances": 2},
}

var host_node: Node
var players: Array[AudioStreamPlayer] = []
var warned_missing: Dictionary = {}
static var warned_missing_global: Dictionary = {}
var last_played_msec: Dictionary = {}
var runtime_stream_overrides: Dictionary = {}
var stream_cache: Dictionary = {}


func setup(host: Node) -> void:
	host_node = host
	ensure_sfx_bus()
	ensure_player_pool()
	apply_volume_settings()


func play_sfx(sound_id: StringName) -> AudioStreamPlayer:
	if sound_id == &"":
		return null
	sfx_requested.emit(sound_id)
	apply_volume_settings()
	var config := get_sound_config(sound_id)
	var stream := get_sound_stream(sound_id, config)
	if stream == null:
		return null
	var now := Time.get_ticks_msec()
	var minimum_repeat_interval := float(config.get("minimum_repeat_interval", 0.0))
	if last_played_msec.has(sound_id) and float(now - int(last_played_msec[sound_id])) / 1000.0 < minimum_repeat_interval:
		return null
	var max_instances := maxi(1, int(config.get("max_instances", 2)))
	if count_playing(sound_id) >= max_instances:
		return null
	var player := get_available_player()
	if player == null:
		return null
	last_played_msec[sound_id] = now
	player.stream = stream
	player.bus = SFX_BUS
	player.volume_db = float(config.get("volume_db", 0.0))
	player.pitch_scale = 1.0 + randf_range(-float(config.get("pitch_variation", 0.0)), float(config.get("pitch_variation", 0.0)))
	player.set_meta("battle_sound_id", sound_id)
	player.set_meta("battle_loop", false)
	player.play()
	return player


func play_sfx_at(sound_id: StringName, world_position: Vector2) -> AudioStreamPlayer:
	var player := play_sfx(sound_id)
	if player != null:
		player.set_meta("battle_world_position", world_position)
	return player


func play_loop(sound_id: StringName) -> AudioStreamPlayer:
	var player := play_sfx(sound_id)
	if player != null:
		player.set_meta("battle_loop", true)
	return player


func stop_loop(handle) -> void:
	if handle is AudioStreamPlayer and is_instance_valid(handle):
		handle.stop()
		clear_player(handle)


func stop_all_battle_audio() -> void:
	for player in players:
		if is_instance_valid(player):
			player.stop()
			clear_player(player)
	last_played_msec.clear()


func register_runtime_sound(sound_id: StringName, stream: AudioStream, config: Dictionary = {}) -> void:
	runtime_stream_overrides[sound_id] = {"stream": stream, "config": config.duplicate(true)}
	warned_missing.erase(sound_id)


func get_active_player_count() -> int:
	var result := 0
	for player in players:
		if is_instance_valid(player) and player.playing:
			result += 1
	return result


func ensure_player_pool() -> void:
	if host_node == null or not players.is_empty():
		return
	for index in range(PLAYER_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "BattleSFX%02d" % index
		player.bus = SFX_BUS
		player.finished.connect(_on_player_finished.bind(player))
		host_node.add_child(player)
		players.append(player)


func ensure_sfx_bus() -> void:
	if AudioServer.get_bus_index(SFX_BUS) >= 0:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, SFX_BUS)


func apply_volume_settings() -> void:
	var bus_index := AudioServer.get_bus_index(SFX_BUS)
	if bus_index < 0:
		return
	var volume := SettingsScript.get_combined_sfx_volume()
	AudioServer.set_bus_mute(bus_index, volume <= 0.001)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(0.001, volume)))


func get_sound_config(sound_id: StringName) -> Dictionary:
	var config: Dictionary = SOUND_REGISTRY.get(sound_id, {}).duplicate(true)
	if runtime_stream_overrides.has(sound_id):
		config.merge(runtime_stream_overrides[sound_id].get("config", {}), true)
	return config


func get_sound_stream(sound_id: StringName, config: Dictionary) -> AudioStream:
	if runtime_stream_overrides.has(sound_id):
		return runtime_stream_overrides[sound_id].get("stream", null)
	if stream_cache.has(sound_id):
		return stream_cache[sound_id]
	var path := String(config.get("path", ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		var stream := load(path) as AudioStream
		if stream != null:
			stream_cache[sound_id] = stream
		return stream
	warn_missing_once(sound_id)
	return null


func count_playing(sound_id: StringName) -> int:
	var result := 0
	for player in players:
		if is_instance_valid(player) and player.playing and StringName(player.get_meta("battle_sound_id", &"")) == sound_id:
			result += 1
	return result


func get_available_player() -> AudioStreamPlayer:
	for player in players:
		if is_instance_valid(player) and not player.playing:
			return player
	return null


func _on_player_finished(player: AudioStreamPlayer) -> void:
	if bool(player.get_meta("battle_loop", false)) and player.stream != null:
		player.play()
		return
	clear_player(player)


func clear_player(player: AudioStreamPlayer) -> void:
	player.remove_meta("battle_sound_id")
	player.remove_meta("battle_loop")
	player.remove_meta("battle_world_position")
	player.stream = null
	player.pitch_scale = 1.0


func warn_missing_once(sound_id: StringName) -> void:
	if warned_missing_global.has(sound_id):
		return
	warned_missing[sound_id] = true
	warned_missing_global[sound_id] = true
	push_warning("Battle audio '%s' has no assigned resource; playback was skipped." % sound_id)

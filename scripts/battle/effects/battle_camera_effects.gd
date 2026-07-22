class_name BattleCameraEffects
extends RefCounted

const HandleScript := preload("res://scripts/battle/effects/battle_effect_handle.gd")
const SettingsScript := preload("res://scripts/battle/effects/battle_presentation_settings.gd")

const SHAKE_CONFIGS := {
	&"light_hit": {"duration": 0.10, "amplitude": 3.0},
	&"medium_hit": {"duration": 0.15, "amplitude": 6.0},
	&"heavy_hit": {"duration": 0.22, "amplitude": 10.0},
	&"boss_skill": {"duration": 0.28, "amplitude": 14.0},
}
const FLASH_CONFIGS := {
	&"white_flash": {"duration": 0.10, "color": Color(1.0, 1.0, 1.0, 0.16)},
	&"blue_flash": {"duration": 0.12, "color": Color(0.28, 0.58, 1.0, 0.13)},
	&"green_flash": {"duration": 0.12, "color": Color(0.30, 1.0, 0.48, 0.08)},
	&"red_flash": {"duration": 0.13, "color": Color(1.0, 0.22, 0.16, 0.13)},
}

var host_node: Node
var world_layer: Control
var overlay_layer: Control
var base_world_position := Vector2.ZERO
var shake_tween: Tween
var flash_tweens: Dictionary = {}
var active_hit_stop_handle: BattleEffectHandle
var active_hit_stop_timer: Timer
var hit_stop_previous_process_mode := Node.PROCESS_MODE_INHERIT
var warned_missing: Dictionary = {}
var last_flash_msec := -1000


func setup(host: Node, world: Control, overlay: Control) -> void:
	host_node = host
	world_layer = world
	overlay_layer = overlay
	if world_layer != null:
		base_world_position = world_layer.position


func play_shake(shake_id: StringName) -> void:
	if shake_id == &"" or not SettingsScript.camera_shake_enabled:
		return
	if not SHAKE_CONFIGS.has(shake_id) or world_layer == null:
		warn_missing_once(&"shake", shake_id)
		return
	clear_shake()
	var config: Dictionary = SHAKE_CONFIGS[shake_id]
	var duration := float(config["duration"])
	var amplitude := float(config["amplitude"])
	shake_tween = world_layer.create_tween()
	for offset in [Vector2(amplitude, -amplitude * 0.45), Vector2(-amplitude * 0.75, amplitude * 0.55), Vector2(amplitude * 0.45, amplitude * 0.25)]:
		shake_tween.tween_property(world_layer, "position", base_world_position + offset, duration / 4.0).set_trans(Tween.TRANS_SINE)
	shake_tween.tween_property(world_layer, "position", base_world_position, duration / 4.0).set_trans(Tween.TRANS_SINE)
	shake_tween.finished.connect(finish_shake.bind(shake_tween), CONNECT_ONE_SHOT)


func play_screen_flash(flash_id: StringName) -> void:
	if flash_id == &"" or not SettingsScript.screen_flash_enabled:
		return
	if not FLASH_CONFIGS.has(flash_id) or overlay_layer == null:
		warn_missing_once(&"flash", flash_id)
		return
	var now := Time.get_ticks_msec()
	if now - last_flash_msec < 70:
		return
	last_flash_msec = now
	var config: Dictionary = FLASH_CONFIGS[flash_id]
	var flash := ColorRect.new()
	flash.name = "BattleScreenFlash"
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = config["color"]
	# Show immediately so a simultaneous hit-stop visibly holds the flash frame.
	flash.modulate.a = 1.0
	overlay_layer.add_child(flash)
	var tween := flash.create_tween()
	flash_tweens[flash] = tween
	var duration := float(config["duration"])
	tween.tween_property(flash, "modulate:a", 0.0, duration)
	tween.tween_callback(free_flash.bind(flash))


func play_hit_stop(duration: float) -> BattleEffectHandle:
	if duration <= 0.0 or not SettingsScript.hit_stop_enabled or host_node == null or world_layer == null:
		var skipped := HandleScript.new()
		skipped.finish()
		return skipped
	if active_hit_stop_handle != null and not active_hit_stop_handle.is_completed:
		return active_hit_stop_handle
	active_hit_stop_handle = HandleScript.new()
	hit_stop_previous_process_mode = world_layer.process_mode
	world_layer.process_mode = Node.PROCESS_MODE_DISABLED
	active_hit_stop_timer = Timer.new()
	active_hit_stop_timer.name = "BattleHitStopTimer"
	active_hit_stop_timer.one_shot = true
	active_hit_stop_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	host_node.add_child(active_hit_stop_timer)
	active_hit_stop_timer.timeout.connect(finish_hit_stop, CONNECT_ONE_SHOT)
	active_hit_stop_timer.start(clampf(duration, 0.01, 0.12))
	return active_hit_stop_handle


func clear_all() -> void:
	clear_shake()
	for raw_flash in flash_tweens.keys():
		var flash: Node = raw_flash
		var tween: Tween = flash_tweens[raw_flash]
		if tween != null and tween.is_valid():
			tween.kill()
		if is_instance_valid(flash):
			flash.queue_free()
	flash_tweens.clear()
	finish_hit_stop()


func clear_shake() -> void:
	if shake_tween != null and shake_tween.is_valid():
		shake_tween.kill()
	shake_tween = null
	if world_layer != null and is_instance_valid(world_layer):
		world_layer.position = base_world_position


func finish_shake(completed_tween: Tween) -> void:
	if shake_tween == completed_tween:
		shake_tween = null
	if world_layer != null and is_instance_valid(world_layer):
		world_layer.position = base_world_position


func finish_hit_stop() -> void:
	if world_layer != null and is_instance_valid(world_layer):
		world_layer.process_mode = hit_stop_previous_process_mode
	if active_hit_stop_timer != null and is_instance_valid(active_hit_stop_timer):
		active_hit_stop_timer.queue_free()
	active_hit_stop_timer = null
	if active_hit_stop_handle != null and not active_hit_stop_handle.is_completed:
		active_hit_stop_handle.finish()
	active_hit_stop_handle = null


func free_flash(flash: Node) -> void:
	flash_tweens.erase(flash)
	if is_instance_valid(flash):
		flash.queue_free()


func warn_missing_once(kind: StringName, effect_id: StringName) -> void:
	var key := "%s:%s" % [kind, effect_id]
	if warned_missing.has(key):
		return
	warned_missing[key] = true
	push_warning("Battle camera effect %s '%s' is not configured; skipped." % [kind, effect_id])

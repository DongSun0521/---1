extends MarginContainer

signal battle_result_acknowledged(result: Dictionary)

const ACTION_BASIC_ATTACK := &"basic_attack"
const ACTION_SKILL := &"skill"
const ACTION_DEFEND := &"defend"
const ACTION_MEDICINE := &"medicine"
const BATTLE_BACKGROUND_PATH := "res://assets/art/battle/battle.png"

const BattleUnitViewScript := preload("res://scripts/battle/battle_unit_view.gd")
const BattleVisualRegistryScript := preload("res://scripts/data/battle_visual_registry.gd")
const BattleEffectRegistryScript := preload("res://scripts/battle/effects/battle_effect_registry.gd")
const BattleEffectPlayerScript := preload("res://scripts/battle/effects/battle_effect_player.gd")
const BattleProjectilePlayerScript := preload("res://scripts/battle/effects/battle_projectile_player.gd")
const BattleEffectContextScript := preload("res://scripts/battle/effects/battle_effect_context.gd")

var game_state
var visual_registry: RefCounted
var input_locked: bool = false
var selected_action: StringName = &""
var current_targets: Array = []
var unit_views: Dictionary = {}
var presentation_in_progress: bool = false
var effect_registry: BattleEffectRegistry
var effect_player: BattleEffectPlayer
var projectile_player: BattleProjectilePlayer

var root: Control
var battlefield: Control
var ground_effect_layer: Control
var unit_layer: Control
var projectile_layer: Control
var impact_effect_layer: Control
var floating_text_layer: Control
var overlay_effect_layer: Control
var turn_label: Label
var target_hint_label: Label
var log_label: Label
var result_overlay: PanelContainer
var result_label: Label
var result_detail_label: Label
var result_continue_button: Button
var result_presentation_active: bool = false
var presented_battle_result: Dictionary = {}
var attack_button: Button
var skill_button: Button
var defend_button: Button
var medicine_button: Button


func _ready() -> void:
	game_state = get_node("/root/GameState")
	visual_registry = BattleVisualRegistryScript.new()
	build_visual_layout()
	build_effect_runtime()
	game_state.battle_state_changed.connect(refresh)
	attack_button.pressed.connect(select_basic_attack)
	skill_button.pressed.connect(select_skill)
	defend_button.pressed.connect(use_defend)
	medicine_button.pressed.connect(select_medicine)
	for button in [attack_button, skill_button, defend_button, medicine_button]:
		button.pressed.connect(effect_player.play_sfx.bind(&"ui_click"))
	battlefield.resized.connect(refresh)
	refresh()


func _exit_tree() -> void:
	presentation_in_progress = false
	input_locked = false
	if effect_player != null:
		effect_player.clear_all_effects()
	for view in unit_views.values():
		if is_instance_valid(view) and view.has_method("clear_presentation_visuals"):
			view.clear_presentation_visuals()
	if game_state != null and game_state.battle_state_changed.is_connected(refresh):
		game_state.battle_state_changed.disconnect(refresh)


func build_visual_layout() -> void:
	add_theme_constant_override("margin_left", 0)
	add_theme_constant_override("margin_top", 0)
	add_theme_constant_override("margin_right", 0)
	add_theme_constant_override("margin_bottom", 0)

	root = Control.new()
	root.name = "BattleRoot"
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root)

	var background := TextureRect.new()
	background.name = "Background"
	background.texture = load(BATTLE_BACKGROUND_PATH) if ResourceLoader.exists(BATTLE_BACKGROUND_PATH) else null
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)

	var shade := ColorRect.new()
	shade.name = "ReadabilityShade"
	shade.color = Color(0.0, 0.0, 0.0, 0.14)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)

	battlefield = Control.new()
	battlefield.name = "Battlefield"
	battlefield.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(battlefield)
	ground_effect_layer = create_battle_layer("GroundEffectLayer")
	unit_layer = create_battle_layer("UnitLayer")
	projectile_layer = create_battle_layer("ProjectileLayer")
	impact_effect_layer = create_battle_layer("ImpactEffectLayer")
	floating_text_layer = create_battle_layer("FloatingTextLayer")
	overlay_effect_layer = create_battle_layer("OverlayEffectLayer")

	build_top_ui()
	build_bottom_ui()
	build_log_panel()
	build_result_overlay()


func build_top_ui() -> void:
	var top_panel := create_panel("TopUI", 0.72)
	set_anchor_rect(top_panel, Rect2(0.02, 0.02, 0.58, 0.10))
	root.add_child(top_panel)

	var margin := create_margin(14)
	top_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)

	turn_label = create_label("", 24, Color(1.0, 0.92, 0.62), HORIZONTAL_ALIGNMENT_LEFT)
	box.add_child(turn_label)
	target_hint_label = create_label("", 18, Color(0.84, 0.92, 1.0), HORIZONTAL_ALIGNMENT_LEFT)
	box.add_child(target_hint_label)


func build_bottom_ui() -> void:
	var bottom_panel := create_panel("BattleActionPanel", 0.86)
	set_anchor_rect(bottom_panel, Rect2(0.18, 0.84, 0.64, 0.13))
	root.add_child(bottom_panel)

	var margin := create_margin(14)
	bottom_panel.add_child(margin)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	margin.add_child(actions)

	attack_button = create_action_button("普通攻击", true)
	skill_button = create_action_button("使用技能", false)
	defend_button = create_action_button("防御", false)
	medicine_button = create_action_button("使用药品", false)
	actions.add_child(attack_button)
	actions.add_child(skill_button)
	actions.add_child(defend_button)
	actions.add_child(medicine_button)


func build_log_panel() -> void:
	var panel := create_panel("BattleLogPanel", 0.78)
	set_anchor_rect(panel, Rect2(0.69, 0.03, 0.29, 0.25))
	root.add_child(panel)

	var margin := create_margin(14)
	panel.add_child(margin)
	log_label = create_label("", 17, Color(0.94, 0.94, 0.86), HORIZONTAL_ALIGNMENT_LEFT)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	margin.add_child(log_label)


func build_result_overlay() -> void:
	result_overlay = create_panel("ResultOverlay", 0.82)
	result_overlay.visible = false
	result_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchor_rect(result_overlay, Rect2(0.22, 0.15, 0.56, 0.68))
	root.add_child(result_overlay)

	var margin := create_margin(22)
	result_overlay.add_child(margin)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(box)
	result_label = create_label("", 32, Color(1.0, 0.90, 0.54), HORIZONTAL_ALIGNMENT_CENTER)
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(result_label)
	var result_scroll := ScrollContainer.new()
	result_scroll.name = "BattleResultScroll"
	result_scroll.custom_minimum_size = Vector2(0, 410)
	result_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(result_scroll)
	result_detail_label = create_label(
		"",
		18,
		Color(0.95, 0.95, 0.88),
		HORIZONTAL_ALIGNMENT_LEFT
	)
	result_detail_label.name = "BattleResultExperienceDetails"
	result_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_scroll.add_child(result_detail_label)
	result_continue_button = create_action_button("确认并继续", true)
	result_continue_button.name = "BattleResultContinueButton"
	result_continue_button.pressed.connect(acknowledge_battle_result)
	box.add_child(result_continue_button)


func refresh() -> void:
	if root == null:
		return
	var battle_state: Dictionary = game_state.get_battle_state()
	var has_battle_visuals: bool = not battle_state.is_empty() and (bool(battle_state.get("is_active", false)) or game_state.has_pending_battle_result() or not battle_state.get("party_states", []).is_empty())
	if not has_battle_visuals:
		clear_unit_views()
		turn_label.text = "未在战斗"
		target_hint_label.text = ""
		log_label.text = format_log(battle_state.get("battle_log", []))
		set_action_buttons_enabled(false)
		if not result_presentation_active:
			result_overlay.visible = false
		return

	update_unit_views(battle_state)
	refresh_turn_ui(battle_state)
	log_label.text = format_log(battle_state.get("battle_log", []))
	refresh_action_buttons(battle_state)
	refresh_target_highlights()


func update_unit_views(battle_state: Dictionary) -> void:
	var seen_ids: Array = []
	var party_states: Array = battle_state.get("party_states", [])
	for index in range(party_states.size()):
		var unit: Dictionary = party_states[index]
		seen_ids.append(unit["unit_id"])
		update_unit_view(unit, index)

	var enemy_states: Array = battle_state.get("enemy_states", [])
	for index in range(enemy_states.size()):
		var unit: Dictionary = enemy_states[index]
		seen_ids.append(unit["unit_id"])
		update_unit_view(unit, index)

	for raw_id in unit_views.keys():
		if not seen_ids.has(raw_id):
			var old_view = unit_views[raw_id]
			old_view.queue_free()
			unit_views.erase(raw_id)


func update_unit_view(unit: Dictionary, side_index: int) -> void:
	var unit_id: StringName = unit["unit_id"]
	var view
	if unit_views.has(unit_id):
		view = unit_views[unit_id]
		view.update_state(unit, not input_locked)
	else:
		view = BattleUnitViewScript.new()
		unit_layer.add_child(view)
		unit_views[unit_id] = view
		view.unit_selected.connect(select_unit_target)
		var visual: Dictionary = visual_registry.get_visual(unit)
		view.setup(unit, visual_registry.get_frames(unit), visual)
		view.set_global_float_layer(floating_text_layer)

	var base_position: Vector2 = visual_registry.get_base_position(unit, side_index)
	var actual_position: Vector2 = visual_registry.scale_position(base_position, battlefield.size)
	view.position = actual_position - view.size * 0.5


func refresh_turn_ui(battle_state: Dictionary) -> void:
	if game_state.has_pending_battle_result():
		turn_label.text = "战斗结果结算中"
		target_hint_label.text = "等待动画结束..."
		return
	if not bool(battle_state.get("is_active", false)):
		turn_label.text = "战斗结束"
		target_hint_label.text = ""
		return
	var active_unit: Dictionary = game_state.get_active_battle_unit()
	turn_label.text = "第%d回合  当前行动：%s" % [
		int(battle_state["round_number"]),
		String(active_unit.get("display_name", "")),
	]
	if selected_action == &"":
		target_hint_label.text = "选择行动。"


func refresh_action_buttons(_battle_state: Dictionary) -> void:
	if input_locked or game_state.has_pending_battle_result() or not game_state.is_battle_active():
		set_action_buttons_enabled(false)
		return

	var active_unit: Dictionary = game_state.get_active_battle_unit()
	var can_act := not active_unit.is_empty() and bool(active_unit.get("is_player_unit", false))
	set_action_buttons_enabled(can_act)
	if can_act:
		var effective_cooldown := int(active_unit.get("effective_skill_cooldown_duration", active_unit.get("skill_cooldown_duration", 0)))
		skill_button.text = "技能：%s（冷却%d）" % [
			String(active_unit.get("skill_name", "")),
			effective_cooldown,
		]
		skill_button.disabled = int(active_unit.get("skill_cooldown", 0)) > 0
		skill_button.tooltip_text = "技能冷却中：%d回合。" % int(active_unit.get("skill_cooldown", 0)) if skill_button.disabled else ""
		medicine_button.disabled = int(game_state.get_expedition_state().get("carried_medicine", 0)) <= 0
		medicine_button.tooltip_text = "远征药品不足。" if medicine_button.disabled else ""
	else:
		skill_button.text = "使用技能"


func set_action_buttons_enabled(enabled: bool) -> void:
	attack_button.disabled = not enabled
	skill_button.disabled = not enabled
	defend_button.disabled = not enabled
	medicine_button.disabled = not enabled


func select_basic_attack() -> void:
	if input_locked:
		return
	selected_action = ACTION_BASIC_ATTACK
	current_targets = get_alive_enemy_targets()
	target_hint_label.text = "点击右侧可攻击目标。"
	refresh_target_highlights()


func select_skill() -> void:
	if input_locked:
		return
	var active_unit: Dictionary = game_state.get_active_battle_unit()
	if active_unit.is_empty():
		return
	var skill_type := String(active_unit["skill_type"])
	if skill_type == "aoe_damage":
		selected_action = &""
		current_targets = []
		start_action(ACTION_SKILL)
		return
	selected_action = ACTION_SKILL
	if skill_type == "heal":
		current_targets = get_healable_party_targets()
		target_hint_label.text = "点击左侧可治疗目标。"
	else:
		current_targets = get_alive_enemy_targets()
		target_hint_label.text = "点击右侧技能目标。"
	refresh_target_highlights()


func use_defend() -> void:
	if input_locked:
		return
	selected_action = &""
	current_targets = []
	start_action(ACTION_DEFEND)


func select_medicine() -> void:
	if input_locked:
		return
	selected_action = ACTION_MEDICINE
	current_targets = get_healable_party_targets()
	target_hint_label.text = "点击左侧药品目标。"
	refresh_target_highlights()


func select_unit_target(unit_id: StringName) -> void:
	if input_locked or selected_action == &"":
		return
	for target: Dictionary in current_targets:
		if target["unit_id"] == unit_id:
			var action := selected_action
			selected_action = &""
			current_targets = []
			start_action(action, unit_id)
			return


func start_action(action_id: StringName, target_id: StringName = &"") -> void:
	if presentation_in_progress:
		return
	presentation_in_progress = true
	input_locked = true
	result_overlay.visible = false
	refresh_target_highlights()
	refresh_action_buttons(game_state.get_battle_state())
	var success: bool = game_state.execute_battle_action(action_id, target_id)
	if not success:
		presentation_in_progress = false
		input_locked = false
		refresh()
		return

	await play_presentation_events(game_state.get_last_battle_presentation_events())
	if not is_inside_tree():
		return
	refresh()
	if game_state.has_pending_battle_result():
		show_pending_result()
		await get_tree().create_timer(0.9).timeout
		result_presentation_active = true
		game_state.complete_pending_battle_result()
		presented_battle_result = game_state.get_last_battle_result()
		show_completed_result(presented_battle_result)
	input_locked = false
	presentation_in_progress = false
	selected_action = &""
	current_targets = []
	if result_presentation_active:
		return
	refresh()


func play_presentation_events(events: Array) -> void:
	for event: Dictionary in events:
		await play_presentation_event(event)
		if not is_inside_tree():
			return


func play_presentation_event(event: Dictionary) -> void:
	var source_id: StringName = event.get("source_id", &"")
	var source_view = unit_views.get(source_id, null)
	var action_type: StringName = event.get("action_type", &"")

	if action_type == &"defend":
		var defend_profile := effect_registry.get_action_visual(&"defend")
		effect_player.play_profile_release_audio(defend_profile)
		await present_defend_visual(event, defend_profile, source_view)
		return

	if action_type == &"medicine":
		var medicine_profile := effect_registry.get_action_visual(&"medicine")
		effect_player.play_profile_release_audio(medicine_profile)
		await present_profile_visual(event, medicine_profile, source_view)
		return

	var visual_action_id := resolve_visual_action_id(event)
	var profile := effect_registry.get_action_visual(visual_action_id)
	if profile == null:
		await present_legacy_visual(event, source_view, source_id)
		return
	if source_view != null and not profile.skip_source_animation:
		var release_frame: int = profile.release_frame if profile.release_frame >= 0 else int(round(get_impact_time(source_id) * 10.0))
		await source_view.play_animation_until_frame(profile.source_animation_name, release_frame, profile.source_animation_speed_scale)
	effect_player.play_profile_release_audio(profile)
	await present_profile_visual(event, profile, source_view)
	if not is_inside_tree():
		return
	if source_view != null and int(get_current_hp(source_id)) > 0:
		source_view.play_idle()


func present_profile_visual(event: Dictionary, profile: BattleActionVisualProfile, source_view) -> void:
	if profile == null:
		play_target_feedback(event, profile)
		await get_tree().create_timer(0.35).timeout
		return
	var target_views := get_event_target_views(event)
	if profile.warning_effect_id != &"":
		var warning_handles: Array = []
		for target_view in target_views:
			var warning_context := make_effect_context(source_view, target_view)
			warning_context.duration_override = profile.warning_duration
			warning_handles.append(effect_player.play_effect(profile.warning_effect_id, warning_context))
		await wait_for_effect_handles(warning_handles)

	if profile.projectile_id != &"" and not target_views.is_empty():
		var projectile_id := profile.projectile_override_id if profile.projectile_override_id != &"" else profile.projectile_id
		var impact_effect_id := profile.impact_effect_override_id
		var projectile_data = effect_registry.get_projectile(projectile_id)
		var resolved_impact_effect_id: StringName = impact_effect_id if impact_effect_id != &"" else StringName(projectile_data.impact_effect_id) if projectile_data != null else &""
		await projectile_player.launch_projectile(projectile_id, source_view, target_views[0], {
			"source_anchor": profile.source_anchor,
			"target_anchor": profile.target_anchor,
			"projectile_scale": profile.projectile_scale_override,
			"impact_scale": profile.impact_scale_override,
			"travel_duration": profile.projectile_duration_override,
			"effect_speed_scale": profile.effect_speed_scale,
			"impact_effect_id": resolved_impact_effect_id,
		})
		await effect_player.play_profile_impact_feedback(profile)
		play_target_feedback(event, profile)
		var projectile_feedback_started := Time.get_ticks_msec()
		var projectile_handles: Array = []
		if projectile_player.last_impact_handle != null and not projectile_player.last_impact_handle.is_completed:
			projectile_handles.append(projectile_player.last_impact_handle)
		await wait_for_target_feedback(event, projectile_handles, projectile_feedback_started)
		return

	var impact_handles: Array = []
	var impact_effect_id := profile.impact_effect_override_id if profile.impact_effect_override_id != &"" else profile.impact_effect_id
	if impact_effect_id != &"":
		var effect_targets := target_views if profile.spawn_per_target else target_views.slice(0, 1)
		for index in range(effect_targets.size()):
			var context := make_effect_context(source_view, effect_targets[index], profile)
			context.scale_multiplier = profile.impact_scale_override * profile.effect_scale_override
			context.speed_scale = profile.effect_speed_scale
			impact_handles.append(effect_player.play_effect(impact_effect_id, context))
			if profile.target_stagger_offset > 0.0 and index < effect_targets.size() - 1:
				await get_tree().create_timer(profile.target_stagger_offset).timeout
	var impact_delay := get_profile_impact_delay(profile, impact_effect_id)
	if impact_delay > 0.0:
		await get_tree().create_timer(impact_delay).timeout
	await effect_player.play_profile_impact_feedback(profile)
	play_profile_recoil(profile, source_view, target_views)
	play_target_feedback(event, profile)
	var feedback_started := Time.get_ticks_msec()
	await wait_for_target_feedback(event, impact_handles, feedback_started)


func present_legacy_visual(event: Dictionary, source_view, source_id: StringName) -> void:
	if source_view != null:
		source_view.sprite.play(&"attack")
		await get_tree().create_timer(get_impact_time(source_id)).timeout
	play_target_feedback(event)
	await get_tree().create_timer(0.78 if not event.get("defeated_ids", []).is_empty() else 0.62).timeout
	if source_view != null and int(get_current_hp(source_id)) > 0:
		source_view.play_idle()


func play_target_feedback(event: Dictionary, profile: BattleActionVisualProfile = null) -> void:
	var target_ids: Array = event.get("target_ids", [])
	var damage_values: Array = event.get("damage_values", [])
	var healing_values: Array = event.get("healing_values", [])
	var defeated_ids: Array = event.get("defeated_ids", [])

	var presented_targets := {}
	for index in range(target_ids.size()):
		var target_id: StringName = target_ids[index]
		if presented_targets.has(target_id):
			continue
		presented_targets[target_id] = true
		var target_view = unit_views.get(target_id, null)
		if target_view == null:
			continue
		if index < damage_values.size():
			var damage := int(damage_values[index])
			target_view.show_float_text("-%d" % damage, Color(1.0, 0.34, 0.26))
			var is_defeated := defeated_ids.has(target_id)
			effect_player.play_unit_feedback(is_defeated, profile)
			target_view.start_hit_or_death_visual(is_defeated)
		elif index < healing_values.size():
			var healing := int(healing_values[index])
			target_view.show_float_text("+%d" % healing, Color(0.36, 1.0, 0.50))
		target_view.animate_hp_to(get_current_hp(target_id))


func resolve_visual_action_id(event: Dictionary) -> StringName:
	var action_type := StringName(event.get("action_type", &""))
	var source_id := StringName(event.get("source_id", &""))
	var source := get_unit_by_id(source_id)
	if action_type == &"medicine":
		return &"medicine"
	if action_type == &"skill" or action_type == &"heal":
		return StringName(source.get("skill_id", &""))
	if action_type == &"group_attack":
		if source_id == &"ruins_guard":
			return &"ruins_guard_earth_spike"
		return StringName(source.get("skill_id", &"arcane_blast"))
	if action_type == &"attack":
		if bool(source.get("is_player_unit", false)):
			return StringName("%s_basic_attack" % source_id)
		if String(source_id).begins_with("forest_slime"):
			return &"monster_basic_attack"
		if source_id == &"ruins_guard":
			return &"ruins_guard_basic_attack"
		if String(source_id).contains("fire") or String(source.get("battle_visual_id", &"")).contains("fire"):
			return &"fire_boss_basic_attack"
		return &"enemy_basic_attack"
	return action_type


func get_event_target_views(event: Dictionary) -> Array:
	var views: Array = []
	for raw_target_id in event.get("target_ids", []):
		var view = unit_views.get(StringName(raw_target_id), null)
		if view != null:
			views.append(view)
	return views


func make_effect_context(source_view, target_view, profile: BattleActionVisualProfile = null) -> BattleEffectContext:
	var context := BattleEffectContextScript.new()
	context.source_view = source_view
	context.target_view = target_view
	if profile != null:
		context.anchor_override = profile.target_anchor
	return context


func get_profile_impact_delay(profile: BattleActionVisualProfile, effect_id: StringName) -> float:
	if profile.impact_delay > 0.0:
		return profile.impact_delay
	if profile.impact_timing != BattleActionVisualProfile.ImpactTiming.EFFECT_FRAME or profile.effect_impact_frame < 0 or effect_id == &"":
		return 0.0
	var data = effect_registry.get_effect(effect_id)
	if data == null or data.sprite_frames == null or not data.sprite_frames.has_animation(data.animation_name):
		return 0.0
	var animation_speed: float = float(data.sprite_frames.get_animation_speed(data.animation_name)) * maxf(0.01, profile.effect_speed_scale)
	return float(profile.effect_impact_frame) / maxf(0.01, animation_speed)


func play_profile_recoil(profile: BattleActionVisualProfile, source_view, target_views: Array) -> void:
	if profile.target_recoil_distance <= 0.0:
		return
	for target_view in target_views:
		if target_view == null or not target_view.has_method("play_visual_recoil"):
			continue
		var direction := Vector2.RIGHT
		if source_view != null:
			direction = (target_view.global_position - source_view.global_position).normalized()
		if direction.is_zero_approx():
			direction = Vector2.RIGHT
		target_view.play_visual_recoil(direction * profile.target_recoil_distance)


func present_defend_visual(event: Dictionary, profile: BattleActionVisualProfile, source_view) -> void:
	if source_view != null:
		var source_state := get_unit_by_id(StringName(event.get("source_id", &"")))
		if not source_state.is_empty():
			source_view.update_state(source_state, false)
		source_view.play_defend_visual()
	await get_tree().create_timer(0.12).timeout
	play_target_feedback(event, profile)
	await get_tree().create_timer(0.24).timeout


func wait_for_effect_handles(handles: Array) -> void:
	for handle in handles:
		if handle != null and not handle.is_completed:
			await handle.completed


func wait_for_target_feedback(event: Dictionary, handles: Array, started_msec: int) -> void:
	await wait_for_effect_handles(handles)
	var required_duration := 0.28
	if not event.get("damage_values", []).is_empty():
		required_duration = 0.62
	if not event.get("defeated_ids", []).is_empty():
		required_duration = 0.78
	var elapsed := float(Time.get_ticks_msec() - started_msec) / 1000.0
	var remaining := required_duration - elapsed
	if remaining > 0.0:
		await get_tree().create_timer(remaining).timeout


func build_effect_runtime() -> void:
	effect_registry = BattleEffectRegistryScript.new()
	effect_registry.name = "BattleEffectRegistry"
	add_child(effect_registry)
	effect_registry.initialize_defaults()
	effect_player = BattleEffectPlayerScript.new()
	effect_player.name = "BattleEffectPlayer"
	add_child(effect_player)
	effect_player.setup(effect_registry, {
		&"ground": ground_effect_layer,
		&"unit": unit_layer,
		&"projectile": projectile_layer,
		&"impact": impact_effect_layer,
		&"floating": floating_text_layer,
		&"overlay": overlay_effect_layer,
	})
	projectile_player = BattleProjectilePlayerScript.new()
	projectile_player.name = "BattleProjectilePlayer"
	add_child(projectile_player)
	projectile_player.setup(effect_registry, effect_player)


func create_battle_layer(layer_name: String) -> Control:
	var layer := Control.new()
	layer.name = layer_name
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	battlefield.add_child(layer)
	return layer


func show_pending_result() -> void:
	var result: Dictionary = game_state.pending_battle_result
	result_overlay.visible = true
	if String(result.get("outcome", "")) == "victory":
		effect_player.play_sfx(&"battle_victory")
		result_label.text = "战斗胜利"
	else:
		effect_player.play_sfx(&"battle_defeat")
		result_label.text = "远征失败"
	result_detail_label.text = "正在结算实际出战角色的成长……"
	result_continue_button.visible = false


func show_completed_result(result: Dictionary) -> void:
	result_overlay.visible = true
	result_continue_button.visible = true
	result_label.text = (
		"Boss战胜利"
		if String(result.get("outcome", "")) == "victory" and bool(result.get("is_boss", false))
		else "战斗胜利"
		if String(result.get("outcome", "")) == "victory"
		else "远征失败"
	)
	result_detail_label.text = format_battle_experience_result(result)


func format_battle_experience_result(result: Dictionary) -> String:
	var lines := PackedStringArray()
	var reward := int(result.get("experience_reward", 0))
	lines.append("实际出战角色成长（每人 +%d 经验）" % reward)
	lines.append("")
	var experience_results: Array = result.get("experience_results", [])
	if experience_results.is_empty():
		lines.append("本次没有可结算的实际出战角色；待命角色未获得经验。")
		return "\n".join(lines)
	for experience_result: Dictionary in experience_results:
		var display_name := String(experience_result.get(
			"display_name",
			game_state.get_character_display_name(
				StringName(experience_result.get("character_id", &""))
			)
		))
		var old_level := int(experience_result.get("old_level", 1))
		var new_level := int(experience_result.get("new_level", old_level))
		var levels_gained := int(experience_result.get("levels_gained", 0))
		var level_text := "Lv.%d → Lv.%d" % [old_level, new_level]
		if levels_gained > 0:
			level_text += "｜升级 ×%d" % levels_gained
		else:
			level_text += "｜未升级"
		if bool(experience_result.get("at_max_level", false)):
			level_text += "｜已满级"
		lines.append("%s｜经验 +%d｜%s" % [
			display_name,
			int(experience_result.get("experience_gained", reward)),
			level_text,
		])
		var stat_changes: Dictionary = experience_result.get("stat_changes", {})
		var growth_lines := PackedStringArray()
		for stat_id: String in ["max_hp", "attack", "defense", "speed"]:
			if not stat_changes.has(stat_id):
				continue
			var change: Dictionary = stat_changes[stat_id]
			growth_lines.append("%s %d→%d（+%d）" % [
				get_combat_stat_display_name(stat_id),
				int(change.get("before", 0)),
				int(change.get("after", 0)),
				int(change.get("delta", 0)),
			])
		if not growth_lines.is_empty():
			lines.append("  主要属性：" + "｜".join(growth_lines))
		elif bool(experience_result.get("at_max_level", false)):
			lines.append("  满级后不再升级，溢出经验按规则丢弃。")
		lines.append("")
	lines.append("待命角色未出战，不获得经验。")
	return "\n".join(lines)


func get_combat_stat_display_name(stat_id: String) -> String:
	match stat_id:
		"max_hp":
			return "生命"
		"attack":
			return "攻击"
		"defense":
			return "防御"
		"speed":
			return "速度"
	return stat_id


func acknowledge_battle_result() -> void:
	if not result_presentation_active:
		return
	var result := presented_battle_result.duplicate(true)
	result_presentation_active = false
	presented_battle_result = {}
	result_overlay.visible = false
	battle_result_acknowledged.emit(result)
	refresh()


func is_presenting_battle_result() -> bool:
	return result_presentation_active


func refresh_target_highlights() -> void:
	var target_ids: Array = []
	for target: Dictionary in current_targets:
		target_ids.append(target["unit_id"])
	for raw_id in unit_views.keys():
		var view = unit_views[raw_id]
		view.set_targetable(not input_locked and target_ids.has(raw_id))


func clear_unit_views() -> void:
	for raw_id in unit_views.keys():
		var view = unit_views[raw_id]
		if view.has_method("clear_presentation_visuals"):
			view.clear_presentation_visuals()
		view.queue_free()
	unit_views.clear()


func get_alive_enemy_targets() -> Array:
	var targets: Array = []
	for enemy: Dictionary in game_state.get_battle_enemy_states():
		if int(enemy["current_hp"]) > 0:
			targets.append(enemy)
	return targets


func get_healable_party_targets() -> Array:
	var targets: Array = []
	for unit: Dictionary in game_state.get_battle_party_states():
		if int(unit["current_hp"]) > 0 and int(unit["current_hp"]) < int(unit["max_hp"]):
			targets.append(unit)
	return targets


func get_impact_time(source_id: StringName) -> float:
	var unit := get_unit_by_id(source_id)
	var visual: Dictionary = visual_registry.get_visual(unit)
	return float(visual.get("impact_frame", 3)) / 10.0


func get_current_hp(unit_id: StringName) -> int:
	var unit := get_unit_by_id(unit_id)
	return int(unit.get("current_hp", 0))


func get_unit_by_id(unit_id: StringName) -> Dictionary:
	for unit: Dictionary in game_state.get_battle_party_states():
		if unit["unit_id"] == unit_id:
			return unit
	for unit: Dictionary in game_state.get_battle_enemy_states():
		if unit["unit_id"] == unit_id:
			return unit
	return {}


func format_log(log_entries: Array) -> String:
	if log_entries.is_empty():
		return "尚未进入战斗。"
	var lines := PackedStringArray()
	for entry in log_entries:
		lines.append(String(entry))
	return "\n".join(lines)


func create_action_button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(210, 54)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color(0.98, 0.95, 0.84))
	button.add_theme_color_override("font_disabled_color", Color(0.52, 0.52, 0.48))
	if primary:
		button.add_theme_stylebox_override("normal", make_button_style(Color(0.38, 0.22, 0.08, 0.94), Color(0.96, 0.76, 0.32, 1.0)))
		button.add_theme_stylebox_override("hover", make_button_style(Color(0.54, 0.34, 0.10, 0.96), Color(1.0, 0.88, 0.45, 1.0)))
	else:
		button.add_theme_stylebox_override("normal", make_button_style(Color(0.10, 0.13, 0.12, 0.92), Color(0.68, 0.58, 0.36, 0.95)))
		button.add_theme_stylebox_override("hover", make_button_style(Color(0.18, 0.24, 0.20, 0.95), Color(0.92, 0.76, 0.38, 1.0)))
	button.add_theme_stylebox_override("disabled", make_button_style(Color(0.07, 0.07, 0.07, 0.76), Color(0.25, 0.25, 0.22, 0.8)))
	return button


func create_panel(node_name: String, alpha: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.add_theme_stylebox_override("panel", make_panel_style(Color(0.05, 0.07, 0.06, alpha), Color(0.80, 0.66, 0.36, 0.88), 2))
	return panel


func create_margin(size: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", size)
	margin.add_theme_constant_override("margin_top", size)
	margin.add_theme_constant_override("margin_right", size)
	margin.add_theme_constant_override("margin_bottom", size)
	return margin


func create_label(text: String, font_size: int, color: Color, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func set_anchor_rect(control: Control, rect: Rect2) -> void:
	control.anchor_left = rect.position.x
	control.anchor_top = rect.position.y
	control.anchor_right = rect.position.x + rect.size.x
	control.anchor_bottom = rect.position.y + rect.size.y
	control.offset_left = 0
	control.offset_top = 0
	control.offset_right = 0
	control.offset_bottom = 0


func make_panel_style(bg_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0, 0, 0, 0.42)
	style.shadow_size = 8
	return style


func make_button_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
	return style

extends MarginContainer

const ACTION_BASIC_ATTACK := &"basic_attack"
const ACTION_SKILL := &"skill"
const ACTION_DEFEND := &"defend"
const ACTION_MEDICINE := &"medicine"

@onready var turn_label: Label = $Content/TurnLabel
@onready var party_label: Label = $Content/Units/PartyPanel/PartyMargin/PartyLabel
@onready var enemy_label: Label = $Content/Units/EnemyPanel/EnemyMargin/EnemyLabel
@onready var attack_button: Button = $Content/Actions/AttackButton
@onready var skill_button: Button = $Content/Actions/SkillButton
@onready var defend_button: Button = $Content/Actions/DefendButton
@onready var medicine_button: Button = $Content/Actions/MedicineButton
@onready var target_panel: PanelContainer = $Content/TargetPanel
@onready var target_title: Label = $Content/TargetPanel/TargetMargin/TargetContent/TargetTitle
@onready var target_buttons: Array[Button] = [
	$Content/TargetPanel/TargetMargin/TargetContent/TargetButtons/TargetButton1,
	$Content/TargetPanel/TargetMargin/TargetContent/TargetButtons/TargetButton2,
	$Content/TargetPanel/TargetMargin/TargetContent/TargetButtons/TargetButton3,
	$Content/TargetPanel/TargetMargin/TargetContent/TargetButtons/TargetButton4,
]
@onready var log_label: Label = $Content/LogPanel/LogMargin/LogLabel

var game_state
var selected_action: StringName = &""
var current_targets: Array = []


func _ready() -> void:
	game_state = get_node("/root/GameState")
	game_state.battle_state_changed.connect(refresh)
	attack_button.pressed.connect(select_basic_attack)
	skill_button.pressed.connect(select_skill)
	defend_button.pressed.connect(use_defend)
	medicine_button.pressed.connect(select_medicine)
	for index in range(target_buttons.size()):
		target_buttons[index].pressed.connect(select_target.bind(index))
	refresh()


func _exit_tree() -> void:
	if game_state != null and game_state.battle_state_changed.is_connected(refresh):
		game_state.battle_state_changed.disconnect(refresh)


func refresh() -> void:
	var battle_state: Dictionary = game_state.get_battle_state()
	if battle_state.is_empty() or not bool(battle_state.get("is_active", false)):
		turn_label.text = "未在战斗"
		party_label.text = format_party(game_state.get_battle_party_states())
		enemy_label.text = "敌人：无"
		log_label.text = format_log(battle_state.get("battle_log", []))
		set_action_buttons_enabled(false)
		target_panel.visible = false
		return

	var active_unit: Dictionary = game_state.get_active_battle_unit()
	turn_label.text = "第%d回合\n当前行动：%s" % [
		int(battle_state["round_number"]),
		String(active_unit.get("display_name", "")),
	]
	party_label.text = format_party(battle_state["party_states"])
	enemy_label.text = format_enemies(battle_state["enemy_states"])
	log_label.text = format_log(battle_state["battle_log"])

	var can_act := not active_unit.is_empty() and bool(active_unit["is_player_unit"])
	set_action_buttons_enabled(can_act)
	if can_act:
		skill_button.text = "使用技能：%s" % String(active_unit["skill_name"])
		skill_button.disabled = int(active_unit["skill_cooldown"]) > 0
		medicine_button.disabled = int(game_state.get_expedition_state()["carried_medicine"]) <= 0
	else:
		skill_button.text = "使用技能"
	refresh_targets()


func set_action_buttons_enabled(enabled: bool) -> void:
	attack_button.disabled = not enabled
	skill_button.disabled = not enabled
	defend_button.disabled = not enabled
	medicine_button.disabled = not enabled


func select_basic_attack() -> void:
	selected_action = ACTION_BASIC_ATTACK
	current_targets = get_alive_enemy_targets()
	target_title.text = "选择攻击目标"
	refresh_targets()


func select_skill() -> void:
	var active_unit: Dictionary = game_state.get_active_battle_unit()
	if active_unit.is_empty():
		return
	var skill_type := String(active_unit["skill_type"])
	if skill_type == "aoe_damage":
		selected_action = &""
		game_state.execute_battle_action(ACTION_SKILL)
		return
	selected_action = ACTION_SKILL
	if skill_type == "heal":
		current_targets = get_healable_party_targets()
		target_title.text = "选择治疗目标"
	else:
		current_targets = get_alive_enemy_targets()
		target_title.text = "选择技能目标"
	refresh_targets()


func use_defend() -> void:
	selected_action = &""
	game_state.execute_battle_action(ACTION_DEFEND)


func select_medicine() -> void:
	selected_action = ACTION_MEDICINE
	current_targets = get_healable_party_targets()
	target_title.text = "选择药品目标"
	refresh_targets()


func select_target(index: int) -> void:
	if selected_action == &"" or index < 0 or index >= current_targets.size():
		return
	var target: Dictionary = current_targets[index]
	var action_to_execute := selected_action
	selected_action = &""
	current_targets = []
	game_state.execute_battle_action(action_to_execute, target["unit_id"])


func refresh_targets() -> void:
	var should_show: bool = selected_action != &"" and current_targets.size() > 0 and game_state.is_battle_active()
	target_panel.visible = should_show
	for index in range(target_buttons.size()):
		var button := target_buttons[index]
		if should_show and index < current_targets.size():
			var target: Dictionary = current_targets[index]
			button.visible = true
			button.disabled = false
			button.text = "%s %d/%d" % [
				String(target["display_name"]),
				int(target["current_hp"]),
				int(target["max_hp"]),
			]
		else:
			button.visible = false
			button.disabled = true
			button.text = ""


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


func format_party(party_states: Array) -> String:
	var lines := PackedStringArray()
	lines.append("我方")
	lines.append("")
	for unit: Dictionary in party_states:
		var status := "正常"
		if int(unit["current_hp"]) <= 0:
			status = "倒下"
		elif bool(unit.get("is_defending", false)):
			status = "防御中"
		lines.append("%s  生命：%d/%d  冷却：%d  %s" % [
			String(unit["display_name"]),
			int(unit["current_hp"]),
			int(unit["max_hp"]),
			int(unit.get("skill_cooldown", 0)),
			status,
		])
	return "\n".join(lines)


func format_enemies(enemy_states: Array) -> String:
	var lines := PackedStringArray()
	lines.append("敌人")
	lines.append("")
	for enemy: Dictionary in enemy_states:
		if int(enemy["current_hp"]) <= 0:
			lines.append("%s：已击败" % String(enemy["display_name"]))
		else:
			lines.append("%s  生命：%d/%d" % [
				String(enemy["display_name"]),
				int(enemy["current_hp"]),
				int(enemy["max_hp"]),
			])
	return "\n".join(lines)


func format_log(log_entries: Array) -> String:
	if log_entries.is_empty():
		return "尚未进入战斗。"
	var lines := PackedStringArray()
	for entry in log_entries:
		lines.append(String(entry))
	return "\n".join(lines)

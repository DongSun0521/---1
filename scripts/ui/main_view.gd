extends Control

@onready var village_button: Button = $Root/Navigation/VillageButton
@onready var expedition_button: Button = $Root/Navigation/ExpeditionButton
@onready var village_view: Control = $Root/Content/VillageView
@onready var expedition_view: Control = $Root/Content/ExpeditionView
@onready var battle_view: Control = $Root/Content/BattleView

var game_state


func _ready() -> void:
	game_state = get_node("/root/GameState")
	village_button.pressed.connect(show_village)
	expedition_button.pressed.connect(show_expedition)
	game_state.expedition_started.connect(show_expedition)
	game_state.expedition_ended.connect(on_expedition_ended)
	game_state.battle_started.connect(on_battle_started)
	game_state.battle_finished.connect(on_battle_finished)
	show_village()


func _exit_tree() -> void:
	if game_state != null and game_state.expedition_started.is_connected(show_expedition):
		game_state.expedition_started.disconnect(show_expedition)
	if game_state != null and game_state.expedition_ended.is_connected(on_expedition_ended):
		game_state.expedition_ended.disconnect(on_expedition_ended)
	if game_state != null and game_state.battle_started.is_connected(on_battle_started):
		game_state.battle_started.disconnect(on_battle_started)
	if game_state != null and game_state.battle_finished.is_connected(on_battle_finished):
		game_state.battle_finished.disconnect(on_battle_finished)


func show_village() -> void:
	if game_state != null and game_state.is_battle_active():
		show_battle()
		return
	village_view.visible = true
	expedition_view.visible = false
	battle_view.visible = false
	village_button.disabled = true
	expedition_button.disabled = false


func show_expedition() -> void:
	if game_state != null and game_state.is_battle_active():
		show_battle()
		return
	village_view.visible = false
	expedition_view.visible = true
	battle_view.visible = false
	village_button.disabled = false
	expedition_button.disabled = true


func show_battle() -> void:
	village_view.visible = false
	expedition_view.visible = false
	battle_view.visible = true
	village_button.disabled = true
	expedition_button.disabled = true


func on_expedition_ended(_report: Dictionary) -> void:
	show_village()


func on_battle_started(_encounter_id: StringName) -> void:
	show_battle()


func on_battle_finished(result: Dictionary) -> void:
	if String(result["outcome"]) == "victory":
		show_expedition()
	else:
		show_village()

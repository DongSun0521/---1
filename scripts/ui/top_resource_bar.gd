extends PanelContainer

@onready var resource_label: Label = $Margin/ResourceLabel

var game_state


func _ready() -> void:
	game_state = get_node("/root/GameState")
	game_state.state_changed.connect(refresh)
	refresh()


func _exit_tree() -> void:
	if game_state != null and game_state.state_changed.is_connected(refresh):
		game_state.state_changed.disconnect(refresh)


func refresh() -> void:
	resource_label.text = game_state.get_resource_summary()

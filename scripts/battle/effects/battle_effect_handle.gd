class_name BattleEffectHandle
extends RefCounted

signal completed

var effect_id: StringName = &""
var node: Node
var is_completed: bool = false


func finish() -> void:
	if is_completed:
		return
	is_completed = true
	completed.emit()


class_name BattleEffectBackend
extends RefCounted


func create_effect_instance(_data: BattleEffectData) -> Node2D:
	return null


class StaticTextureEffectBackend extends BattleEffectBackend:
	func create_effect_instance(data: BattleEffectData) -> Node2D:
		var sprite := Sprite2D.new()
		sprite.texture = data.texture
		return sprite


class SpriteFramesEffectBackend extends BattleEffectBackend:
	func create_effect_instance(data: BattleEffectData) -> Node2D:
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = data.sprite_frames
		return sprite


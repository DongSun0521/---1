class_name BattleEffectData
extends Resource

enum PlaybackType {
	STATIC_TEXTURE,
	SPRITE_FRAMES,
	SPINE,
}

enum SpawnAnchor {
	SOURCE_CENTER,
	SOURCE_WEAPON,
	TARGET_CENTER,
	TARGET_GROUND,
	WORLD_POSITION,
	SCREEN_CENTER,
}

@export var effect_id: StringName = &""
@export var playback_type: PlaybackType = PlaybackType.STATIC_TEXTURE
@export var texture: Texture2D
@export var sprite_frames: SpriteFrames
@export var animation_name: StringName = &"play"
@export var spawn_anchor: SpawnAnchor = SpawnAnchor.TARGET_CENTER
@export var offset: Vector2 = Vector2.ZERO
@export var display_scale: Vector2 = Vector2.ONE
@export var rotation_degrees: float = 0.0
@export var loop: bool = false
@export var auto_destroy: bool = true
@export var fallback_duration: float = 0.5
@export var follow_anchor: bool = false
@export var default_z_group: StringName = &"impact"
@export var remove_baked_checkerboard: bool = false
@export var spine_resource_path: String = ""
@export var spine_animation_name: StringName = &""
@export var start_sound_id: StringName = &""
@export var impact_sound_id: StringName = &""
@export var camera_shake_id: StringName = &""
@export var screen_flash_id: StringName = &""


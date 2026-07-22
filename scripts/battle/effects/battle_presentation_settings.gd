class_name BattlePresentationSettings
extends RefCounted

# Runtime settings intentionally live outside BattleState. Static storage keeps
# them stable across battle-view recreation without touching combat saves/rules.
static var master_volume: float = 1.0
static var sfx_volume: float = 1.0
static var camera_shake_enabled: bool = true
static var screen_flash_enabled: bool = true
static var hit_stop_enabled: bool = true


static func reset_defaults() -> void:
	master_volume = 1.0
	sfx_volume = 1.0
	camera_shake_enabled = true
	screen_flash_enabled = true
	hit_stop_enabled = true


static func get_combined_sfx_volume() -> float:
	return clampf(master_volume, 0.0, 1.0) * clampf(sfx_volume, 0.0, 1.0)


static func snapshot() -> Dictionary:
	return {
		"master_volume": master_volume,
		"sfx_volume": sfx_volume,
		"camera_shake_enabled": camera_shake_enabled,
		"screen_flash_enabled": screen_flash_enabled,
		"hit_stop_enabled": hit_stop_enabled,
	}

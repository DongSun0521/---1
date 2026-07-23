class_name CharacterEnums
extends RefCounted

enum CharacterType {
	COMBAT,
	LIFE,
}

enum Quality {
	COMMON,
	RARE,
	EPIC,
	LEGENDARY,
}

enum CombatClass {
	WARRIOR,
	MAGE,
	RANGER,
	HEALER,
}

enum WorkState {
	IDLE,
	WORKING,
	UNAVAILABLE,
}


static func character_type_name(value: int) -> StringName:
	return &"life" if value == CharacterType.LIFE else &"combat"


static func quality_name(value: int) -> StringName:
	match value:
		Quality.RARE:
			return &"rare"
		Quality.EPIC:
			return &"epic"
		Quality.LEGENDARY:
			return &"legendary"
	return &"common"


static func work_state_name(value: int) -> StringName:
	match value:
		WorkState.WORKING:
			return &"working"
		WorkState.UNAVAILABLE:
			return &"unavailable"
	return &"idle"

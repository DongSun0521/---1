class_name CharacterRecord
extends RefCounted

const CharacterEnumsScript := preload("res://scripts/data/character_enums.gd")
const CombatCharacterDataScript := preload("res://scripts/data/combat_character_data.gd")
const LifeCharacterDataScript := preload("res://scripts/data/life_character_data.gd")
const Stage12Config := preload("res://scripts/data/stage12_balance_config.gd")

var character_id: StringName = &""
var character_type: int = CharacterEnumsScript.CharacterType.COMBAT
var display_name: String = ""
var portrait_path: String = ""
var quality: int = CharacterEnumsScript.Quality.COMMON
var level: int = 1
var experience: int = 0
var experience_to_next_level: int = 100
var traits: Array[StringName] = []
var is_locked: bool = false
var created_sequence: int = 0
var metadata: Dictionary = {}
var combat_data: CombatCharacterData
var life_data: LifeCharacterData


func setup_common(
	p_character_id: StringName,
	p_character_type: int,
	p_display_name: String,
	p_created_sequence: int
) -> CharacterRecord:
	character_id = p_character_id
	character_type = p_character_type
	display_name = p_display_name
	created_sequence = max(0, p_created_sequence)
	return self


func is_combat_character() -> bool:
	return character_type == CharacterEnumsScript.CharacterType.COMBAT and combat_data != null


func is_life_character() -> bool:
	return character_type == CharacterEnumsScript.CharacterType.LIFE and life_data != null


func to_dictionary() -> Dictionary:
	return {
		"character_id": character_id,
		"character_type": character_type,
		"character_type_name": CharacterEnumsScript.character_type_name(character_type),
		"display_name": display_name,
		"portrait_path": portrait_path,
		"quality": quality,
		"quality_name": CharacterEnumsScript.quality_name(quality),
		"level": level,
		"experience": experience,
		"experience_to_next_level": experience_to_next_level,
		"traits": traits.duplicate(),
		"is_locked": is_locked,
		"created_sequence": created_sequence,
		"metadata": metadata.duplicate(true),
		"combat_data": combat_data.to_dictionary() if combat_data != null else {},
		"life_data": life_data.to_dictionary() if life_data != null else {},
	}


func apply_dictionary(data: Dictionary) -> CharacterRecord:
	character_id = StringName(data.get("character_id", &""))
	character_type = clampi(int(data.get("character_type", CharacterEnumsScript.CharacterType.COMBAT)), CharacterEnumsScript.CharacterType.COMBAT, CharacterEnumsScript.CharacterType.LIFE)
	display_name = String(data.get("display_name", String(character_id)))
	portrait_path = String(data.get("portrait_path", ""))
	quality = clampi(int(data.get("quality", CharacterEnumsScript.Quality.COMMON)), CharacterEnumsScript.Quality.COMMON, CharacterEnumsScript.Quality.LEGENDARY)
	var max_level := Stage12Config.COMBAT_MAX_LEVEL \
		if character_type == CharacterEnumsScript.CharacterType.COMBAT \
		else Stage12Config.LIFE_MAX_LEVEL
	level = clampi(int(data.get("level", 1)), 1, max_level)
	experience = max(0, int(data.get("experience", 0)))
	experience_to_next_level = 0 if level >= max_level else max(
		1, int(data.get("experience_to_next_level", 100))
	)
	traits = _to_string_name_array(data.get("traits", data.get("trait_ids", [])))
	is_locked = bool(data.get("is_locked", false))
	created_sequence = max(0, int(data.get("created_sequence", data.get("created_timestamp", 0))))
	metadata = data.get("metadata", {}).duplicate(true)
	combat_data = null
	life_data = null
	if character_type == CharacterEnumsScript.CharacterType.COMBAT:
		combat_data = CombatCharacterDataScript.from_dictionary(data.get("combat_data", {}))
	else:
		life_data = LifeCharacterDataScript.from_dictionary(data.get("life_data", {}))
	return self


static func from_dictionary(data: Dictionary) -> CharacterRecord:
	return CharacterRecord.new().apply_dictionary(data)


static func _to_string_name_array(values: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for value in values:
		result.append(StringName(value))
	return result

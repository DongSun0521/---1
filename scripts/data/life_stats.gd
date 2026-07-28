class_name LifeStats
extends Resource

const Stage12Config := preload("res://scripts/data/stage12_balance_config.gd")

@export var farming: int = 0
@export var smithing: int = 0
@export var cooking: int = 0
@export var medicine: int = 0
@export var research: int = 0
@export var gathering: int = 0
@export var crafting: int = 0
@export var medical: int = 0

const CORE_STAT_IDS: Array[StringName] = [
	&"farming",
	&"crafting",
	&"gathering",
	&"research",
	&"medical",
]
const CORE_STAT_CAP := Stage12Config.LIFE_STAT_MAX


func setup(
	p_farming: int,
	p_smithing: int,
	p_cooking: int,
	p_medicine: int,
	p_research: int,
	p_gathering: int
) -> LifeStats:
	farming = p_farming
	smithing = p_smithing
	cooking = p_cooking
	medicine = p_medicine
	research = p_research
	gathering = p_gathering
	crafting = p_smithing
	medical = p_medicine
	return self


func setup_core(p_farming: int, p_crafting: int, p_gathering: int, p_research: int, p_medical: int) -> LifeStats:
	farming = p_farming
	crafting = p_crafting
	gathering = p_gathering
	research = p_research
	medical = p_medical
	# Legacy aliases remain populated for existing character-detail consumers.
	smithing = p_crafting
	medicine = p_medical
	cooking = 0
	return self


func to_dictionary() -> Dictionary:
	return {
		"farming": farming,
		"smithing": smithing,
		"cooking": cooking,
		"medicine": medicine,
		"research": research,
		"gathering": gathering,
		"crafting": crafting,
		"medical": medical,
	}


func to_core_dictionary() -> Dictionary:
	return {
		"farming": farming,
		"crafting": crafting,
		"gathering": gathering,
		"research": research,
		"medical": medical,
	}


func get_core_stat(stat_id: StringName) -> int:
	return int(to_core_dictionary().get(String(stat_id), 0))


func set_core_stat(stat_id: StringName, value: int) -> bool:
	var normalized := clampi(value, 0, CORE_STAT_CAP)
	match stat_id:
		&"farming":
			farming = normalized
		&"crafting":
			crafting = normalized
			smithing = normalized
		&"gathering":
			gathering = normalized
		&"research":
			research = normalized
		&"medical":
			medical = normalized
			medicine = normalized
		_:
			return false
	return true


func increase_core_stat(stat_id: StringName, amount: int) -> int:
	var old_value := get_core_stat(stat_id)
	if not set_core_stat(stat_id, old_value + max(0, amount)):
		return 0
	return get_core_stat(stat_id) - old_value


func clamp_core_stats() -> void:
	for stat_id: StringName in CORE_STAT_IDS:
		set_core_stat(stat_id, get_core_stat(stat_id))


static func from_dictionary(data: Dictionary) -> LifeStats:
	var parsed_crafting := int(data.get("crafting", data.get("smithing", 0)))
	var parsed_medical := int(data.get("medical", data.get("medicine", 0)))
	var result := LifeStats.new().setup_core(
		int(data.get("farming", 0)),
		parsed_crafting,
		int(data.get("gathering", 0)),
		int(data.get("research", 0)),
		parsed_medical
	)
	result.smithing = int(data.get("smithing", parsed_crafting))
	result.cooking = int(data.get("cooking", 0))
	result.medicine = int(data.get("medicine", parsed_medical))
	result.clamp_core_stats()
	return result

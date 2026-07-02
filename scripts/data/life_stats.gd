class_name LifeStats
extends Resource

@export var farming: int = 0
@export var smithing: int = 0
@export var cooking: int = 0
@export var medicine: int = 0
@export var research: int = 0
@export var gathering: int = 0


func setup(
	p_farming: int,
	p_smithing: int,
	p_cooking: int,
	p_medicine: int,
	p_research: int,
	p_gathering: int
):
	farming = p_farming
	smithing = p_smithing
	cooking = p_cooking
	medicine = p_medicine
	research = p_research
	gathering = p_gathering
	return self


func to_dictionary() -> Dictionary:
	return {
		"farming": farming,
		"smithing": smithing,
		"cooking": cooking,
		"medicine": medicine,
		"research": research,
		"gathering": gathering,
	}

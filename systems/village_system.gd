extends RefCounted

const FARM_ID := "farm"
const CLINIC_ID := "clinic"
const VILLAGE_DAILY_FOOD_CONSUMPTION := 2


func advance_day(game_state, reason: String = "manual_test") -> Dictionary:
	var settled_day: int = int(game_state.current_day)
	var report := process_daily_village(game_state)
	game_state.current_day = settled_day + 1
	report["reason"] = reason
	report["settled_day"] = settled_day
	report["new_day"] = int(game_state.current_day)
	return report


func process_daily_village(game_state) -> Dictionary:
	var resources: Dictionary = game_state.resources
	var buildings: Dictionary = game_state.buildings

	var food_before: int = int(resources["food"])
	var medicine_before: int = int(resources["medicine"])

	var report := {
		"food_before": food_before,
		"food_produced": 0,
		"farm_plot_updates": [],
		"farm_harvests": [],
		"farm_food_produced": 0,
		"farm_herb_produced": 0,
	}
	game_state.farm_system.process_daily_growth(game_state, report)
	resources = game_state.resources

	var medicine_produced := 0
	var medicine_progress := 0
	var medicine_progress_required := 0

	var food_consumed: int = min(VILLAGE_DAILY_FOOD_CONSUMPTION, int(resources["food"]))
	resources["food"] = max(0, int(resources["food"]) - food_consumed)

	game_state.resources = resources
	game_state.buildings = buildings

	var food_after: int = int(resources["food"])
	var medicine_after: int = int(resources["medicine"])

	report.merge({
		"food_after": food_after,
		"food_consumed": food_consumed,
		"food_net": food_after - food_before,
		"medicine_before": medicine_before,
		"medicine_after": medicine_after,
		"medicine_produced": medicine_produced,
		"medicine_net": medicine_after - medicine_before,
		"medicine_progress": medicine_progress,
		"medicine_progress_required": medicine_progress_required,
	}, true)
	return report

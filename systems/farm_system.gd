class_name FarmSystem
extends RefCounted

const CropDataScript := preload("res://scripts/data/crop_data.gd")
const FarmPlotStateScript := preload("res://scripts/data/farm_plot_state.gd")

const MAX_PLOTS := 6
const DEFAULT_CROP_ID: StringName = &"wheat"
const PLOT_COUNT_BY_LEVEL := {
	1: 3,
	2: 4,
	3: 5,
	4: 6,
}

var crop_data_by_id: Dictionary = {}
var last_error: String = ""


func _init() -> void:
	_build_crop_data()


func create_initial_plot_states(farm_level: int = 1) -> Array:
	var unlocked_count := get_unlocked_plot_count_for_level(farm_level)
	var plots: Array = []
	for index in range(MAX_PLOTS):
		var plot_id := index + 1
		var unlocked := plot_id <= unlocked_count
		var crop_id := DEFAULT_CROP_ID if unlocked and plot_id <= 3 else &""
		plots.append(FarmPlotStateScript.new().setup(plot_id, unlocked, crop_id, 0, crop_id != &""))
	return plots


func ensure_plot_states(game_state: Node) -> void:
	if game_state.farm_plot_states.size() != MAX_PLOTS:
		game_state.farm_plot_states = create_initial_plot_states(_get_farm_level(game_state))
		return
	_refresh_unlocks(game_state, _get_farm_level(game_state))


func get_crop_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for crop_id in crop_data_by_id.keys():
		ids.append(crop_id)
	return ids


func get_crop_data(crop_id: StringName):
	return crop_data_by_id.get(crop_id, null)


func get_all_crop_data() -> Array:
	var result: Array = []
	for crop_id in get_crop_ids():
		result.append(get_crop_data(crop_id))
	return result


func get_unlocked_plot_count(game_state: Node) -> int:
	return get_unlocked_plot_count_for_level(_get_farm_level(game_state))


func get_unlocked_plot_count_for_level(level: int) -> int:
	return int(PLOT_COUNT_BY_LEVEL.get(clampi(level, 1, 4), 3))


func get_plot_state(game_state: Node, plot_id: int):
	ensure_plot_states(game_state)
	if plot_id < 1 or plot_id > MAX_PLOTS:
		return null
	return game_state.farm_plot_states[plot_id - 1]


func get_plot_state_dictionaries(game_state: Node) -> Array:
	ensure_plot_states(game_state)
	var result: Array = []
	for plot in game_state.farm_plot_states:
		result.append(_plot_to_dictionary(game_state, plot))
	return result


func assign_crop(game_state: Node, plot_id: int, crop_id: StringName, force_replace: bool = false) -> bool:
	last_error = ""
	var plot = get_plot_state(game_state, plot_id)
	if plot == null:
		last_error = "未知地块"
		return false
	if not plot.is_unlocked:
		last_error = "地块尚未解锁"
		return false
	if not crop_data_by_id.has(crop_id):
		last_error = "未知作物"
		return false
	if plot.crop_id == crop_id and plot.is_active:
		return true
	if plot.progress_days > 0 and not force_replace:
		last_error = "改种会失去当前进度"
		return false
	plot.crop_id = crop_id
	plot.progress_days = 0
	plot.is_active = true
	return true


func clear_plot(game_state: Node, plot_id: int, force_clear: bool = false) -> bool:
	last_error = ""
	var plot = get_plot_state(game_state, plot_id)
	if plot == null:
		last_error = "未知地块"
		return false
	if not plot.is_unlocked:
		last_error = "地块尚未解锁"
		return false
	if plot.progress_days > 0 and not force_clear:
		last_error = "停止种植会失去当前进度"
		return false
	plot.crop_id = &""
	plot.progress_days = 0
	plot.is_active = false
	return true


func process_daily_growth(game_state: Node, report: Dictionary) -> Dictionary:
	ensure_plot_states(game_state)
	var plot_updates: Array = []
	var harvests: Array = []
	var produced_by_resource: Dictionary = {
		&"food": 0,
		&"herb": 0,
	}

	for plot in game_state.farm_plot_states:
		if not plot.is_unlocked or not plot.is_active or plot.crop_id == &"":
			continue
		var crop = get_crop_data(plot.crop_id)
		if crop == null:
			continue
		var before: int = plot.progress_days
		plot.progress_days += 1
		var harvested: bool = plot.progress_days >= crop.growth_days
		var update := {
			"plot_id": plot.plot_id,
			"crop_id": plot.crop_id,
			"progress_before": before,
			"progress_after": plot.progress_days,
			"required_days": crop.growth_days,
			"harvested": harvested,
		}
		if harvested:
			var resource_id: StringName = crop.output_resource_id
			var resource_key := String(resource_id)
			game_state.resources[resource_key] = int(game_state.resources.get(resource_key, 0)) + crop.output_amount
			produced_by_resource[resource_id] = int(produced_by_resource.get(resource_id, 0)) + crop.output_amount
			plot.progress_days = 0
			update["progress_after"] = 0
			update["output_resource_id"] = resource_id
			update["output_amount"] = crop.output_amount
			harvests.append(update.duplicate(true))
		plot_updates.append(update)

	report["farm_plot_updates"] = plot_updates
	report["farm_harvests"] = harvests
	report["farm_food_produced"] = int(produced_by_resource.get(&"food", 0))
	report["farm_herb_produced"] = int(produced_by_resource.get(&"herb", 0))
	report["food_produced"] = int(report.get("food_produced", 0)) + int(report["farm_food_produced"])
	return report


func can_set_farm_level(game_state: Node, level: int) -> bool:
	last_error = ""
	if level < 1 or level > 4:
		last_error = "等级超出范围"
		return false
	ensure_plot_states(game_state)
	var new_unlocked_count := get_unlocked_plot_count_for_level(level)
	for plot in game_state.farm_plot_states:
		if plot.plot_id > new_unlocked_count and plot.is_active and plot.crop_id != &"":
			last_error = "地块%d正在种植，不能降级锁定。" % plot.plot_id
			return false
	return true


func apply_farm_level(game_state: Node, level: int) -> void:
	ensure_plot_states(game_state)
	_refresh_unlocks(game_state, level)


func get_active_plot_count(game_state: Node) -> int:
	ensure_plot_states(game_state)
	var count := 0
	for plot in game_state.farm_plot_states:
		if plot.is_unlocked and plot.is_active and plot.crop_id != &"":
			count += 1
	return count


func get_next_harvest_days(game_state: Node) -> int:
	ensure_plot_states(game_state)
	var next_days := 999999
	for plot in game_state.farm_plot_states:
		if not plot.is_unlocked or not plot.is_active or plot.crop_id == &"":
			continue
		var crop = get_crop_data(plot.crop_id)
		if crop == null:
			continue
		next_days = min(next_days, max(1, crop.growth_days - plot.progress_days))
	return 0 if next_days == 999999 else next_days


func get_crop_counts(game_state: Node) -> Dictionary:
	ensure_plot_states(game_state)
	var counts := {}
	for crop_id in get_crop_ids():
		counts[crop_id] = 0
	for plot in game_state.farm_plot_states:
		if plot.is_unlocked and plot.is_active and plot.crop_id != &"":
			counts[plot.crop_id] = int(counts.get(plot.crop_id, 0)) + 1
	return counts


func get_summary(game_state: Node) -> Dictionary:
	var unlocked_count := get_unlocked_plot_count(game_state)
	var active_count := get_active_plot_count(game_state)
	return {
		"unlocked_plot_count": unlocked_count,
		"max_plot_count": MAX_PLOTS,
		"active_plot_count": active_count,
		"empty_plot_count": unlocked_count - active_count,
		"crop_counts": get_crop_counts(game_state),
		"next_harvest_days": get_next_harvest_days(game_state),
	}


func get_work_state(game_state: Node) -> StringName:
	return &"working" if get_active_plot_count(game_state) > 0 else &"idle"


func get_status_text(game_state: Node) -> String:
	var unlocked_count := get_unlocked_plot_count(game_state)
	var active_count := get_active_plot_count(game_state)
	if active_count <= 0:
		return "农田空闲"
	var next_days := get_next_harvest_days(game_state)
	if next_days > 0:
		return "种植中 %d/%d，下次收获：%d天后" % [active_count, unlocked_count, next_days]
	return "种植中 %d/%d" % [active_count, unlocked_count]


func get_last_error() -> String:
	return last_error


func _refresh_unlocks(game_state: Node, farm_level: int) -> void:
	var unlocked_count := get_unlocked_plot_count_for_level(farm_level)
	for plot in game_state.farm_plot_states:
		plot.is_unlocked = plot.plot_id <= unlocked_count
		if not plot.is_unlocked:
			plot.is_active = false
			plot.crop_id = &""
			plot.progress_days = 0


func _plot_to_dictionary(game_state: Node, plot) -> Dictionary:
	var result: Dictionary = plot.to_dictionary()
	var crop = get_crop_data(plot.crop_id)
	if crop != null:
		result["crop_display_name"] = crop.display_name
		result["growth_days"] = crop.growth_days
		result["output_resource_id"] = crop.output_resource_id
		result["output_amount"] = crop.output_amount
		result["remaining_days"] = max(0, crop.growth_days - plot.progress_days)
	else:
		result["crop_display_name"] = ""
		result["growth_days"] = 0
		result["output_resource_id"] = &""
		result["output_amount"] = 0
		result["remaining_days"] = 0
	result["unlock_level"] = _get_unlock_level_for_plot(plot.plot_id)
	result["is_unlocked"] = plot.plot_id <= get_unlocked_plot_count(game_state)
	return result


func _get_farm_level(game_state: Node) -> int:
	return clampi(int(game_state.buildings.get("farm", {}).get("level", 1)), 1, 4)


func _get_unlock_level_for_plot(plot_id: int) -> int:
	for level in range(1, 5):
		if plot_id <= get_unlocked_plot_count_for_level(level):
			return level
	return 4


func _build_crop_data() -> void:
	crop_data_by_id[&"wheat"] = CropDataScript.new().setup(
		&"wheat",
		"小麦",
		"稳定生产村庄粮食。",
		2,
		&"food",
		3
	)
	crop_data_by_id[&"herb"] = CropDataScript.new().setup(
		&"herb",
		"药草",
		"为医院、装备和后续药品系统准备草药。",
		3,
		&"herb",
		2
	)

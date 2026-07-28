class_name FoodWorkshopSystem
extends RefCounted

const FoodRecipeDataScript := preload("res://scripts/data/food_recipe_data.gd")
const ExpeditionMealDataScript := preload("res://scripts/data/expedition_meal_data.gd")
const FoodProductionStateScript := preload("res://scripts/data/food_production_state.gd")

const NO_ACTIVE_RECIPE: StringName = &""
const ITEM_EXPEDITION_RATION := &"expedition_ration"
const ITEM_HEARTY_STEW := &"hearty_stew"
const ITEM_HUNTER_ROAST := &"hunter_roast"

var recipe_definitions: Dictionary = {}
var meal_definitions: Dictionary = {}


func _init() -> void:
	_build_recipe_definitions()
	_build_meal_definitions()


func create_initial_state():
	return FoodProductionStateScript.new().setup()


func get_recipe_definition(recipe_id: StringName):
	return recipe_definitions.get(recipe_id, null)


func get_meal_definition(meal_id: StringName):
	return meal_definitions.get(meal_id, null)


func get_recipe_data(game_state: Node, recipe_id: StringName) -> Dictionary:
	var recipe = get_recipe_definition(recipe_id)
	if recipe == null:
		return {}
	var data: Dictionary = recipe.to_dictionary()
	data["can_start"] = can_start_recipe(game_state, recipe_id)
	data["start_error"] = get_start_error(game_state, recipe_id)
	data["effect_text"] = get_output_effect_text(recipe.output_item_id)
	return data


func get_all_recipe_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for recipe_id: StringName in recipe_definitions.keys():
		ids.append(recipe_id)
	ids.sort()
	return ids


func get_all_recipe_data(game_state: Node) -> Array:
	var recipes: Array = []
	for recipe_id: StringName in get_all_recipe_ids():
		recipes.append(get_recipe_data(game_state, recipe_id))
	return recipes


func get_all_meal_data() -> Array:
	var meals: Array = []
	for meal_id: StringName in meal_definitions.keys():
		meals.append(meal_definitions[meal_id].to_dictionary())
	return meals


func get_meal_data(meal_id: StringName) -> Dictionary:
	var meal = get_meal_definition(meal_id)
	return meal.to_dictionary() if meal != null else {}


func can_start_recipe(game_state: Node, recipe_id: StringName) -> bool:
	return get_start_error(game_state, recipe_id).is_empty()


func get_start_error(game_state: Node, recipe_id: StringName) -> String:
	var recipe = get_recipe_definition(recipe_id)
	if recipe == null:
		return "未知配方"
	if game_state.food_production_state == null:
		return "食物制造所状态缺失"
	if bool(game_state.food_production_state.is_active):
		return "食物制造所正在工作"
	for raw_resource_id in recipe.ingredient_costs.keys():
		var resource_id := String(raw_resource_id)
		var required := int(recipe.ingredient_costs[raw_resource_id])
		if game_state.get_resource_amount(resource_id) < required:
			return "%s不足" % game_state.get_resource_display_name(resource_id)
	return ""


func start_recipe(game_state: Node, recipe_id: StringName) -> Dictionary:
	var error_message := get_start_error(game_state, recipe_id)
	if not error_message.is_empty():
		return {
			"success": false,
			"recipe_id": recipe_id,
			"error": error_message,
		}

	var recipe = get_recipe_definition(recipe_id)
	for raw_resource_id in recipe.ingredient_costs.keys():
		var resource_id := String(raw_resource_id)
		game_state.resources[resource_id] = int(game_state.resources.get(resource_id, 0)) - int(recipe.ingredient_costs[raw_resource_id])
	game_state.food_production_state.setup(recipe.recipe_id, 0, int(recipe.duration_days), int(game_state.current_day), true)
	return _make_report(game_state, recipe_id, true, false, &"", 0, 0)


func process_daily_production(game_state: Node) -> Dictionary:
	if game_state.food_production_state == null or not bool(game_state.food_production_state.is_active):
		return {
			"had_active_food_workshop": false,
			"food_workshop_completed": false,
			"food_workshop_progress_updates": [],
		}

	var recipe_id: StringName = StringName(game_state.food_production_state.recipe_id)
	var recipe = get_recipe_definition(recipe_id)
	if recipe == null:
		game_state.food_production_state.clear()
		return {
			"had_active_food_workshop": false,
			"food_workshop_completed": false,
			"food_workshop_progress_updates": [],
			"error": "食物配方缺失，已清空制造状态。",
		}

	var progress_before := int(game_state.food_production_state.progress_days)
	var required_days := int(game_state.food_production_state.required_days)
	var progress_after := progress_before + 1
	var completed := progress_after >= required_days
	game_state.food_production_state.progress_days = progress_after

	var output_item_id: StringName = &""
	var output_amount := 0
	if completed:
		output_item_id = recipe.output_item_id
		output_amount = game_state.calculate_building_production_output(
			&"food_workshop", int(recipe.output_amount)
		)
		game_state.add_item(output_item_id, output_amount, false)
		game_state.food_production_state.clear()

	var report := _make_report(
		game_state,
		recipe_id,
		true,
		completed,
		output_item_id,
		progress_before,
		min(progress_after, required_days)
	)
	report["work_experience_results"] = []
	if completed:
		report["work_experience_results"] = game_state.settle_life_job_work_experience(
			&"food_workshop",
			StringName("food_workshop_%s_day_%d" % [String(recipe_id), int(game_state.current_day)])
		)
		game_state.record_life_work_feedback(&"food_workshop", report)
	return report


func get_active_summary(game_state: Node) -> String:
	if game_state.food_production_state == null or not bool(game_state.food_production_state.is_active):
		return "当前没有食物制造项目"
	var recipe = get_recipe_definition(StringName(game_state.food_production_state.recipe_id))
	if recipe == null:
		return "当前食物制造项目数据缺失"
	return "%s：%d/%d天" % [
		String(recipe.display_name),
		int(game_state.food_production_state.progress_days),
		int(game_state.food_production_state.required_days),
	]


func get_remaining_days(game_state: Node) -> int:
	if game_state.food_production_state == null or not bool(game_state.food_production_state.is_active):
		return 0
	return max(0, int(game_state.food_production_state.required_days) - int(game_state.food_production_state.progress_days))


func get_output_effect_text(item_id: StringName) -> String:
	var meal = get_meal_definition(item_id)
	if meal == null:
		return ""
	var parts := PackedStringArray()
	if int(meal.max_hp_bonus) > 0:
		parts.append("全队最大生命+%d" % int(meal.max_hp_bonus))
	if int(meal.attack_bonus) > 0:
		parts.append("全队攻击+%d" % int(meal.attack_bonus))
	return "，".join(parts)


func _make_report(
	game_state: Node,
	recipe_id: StringName,
	had_active: bool,
	completed: bool,
	output_item_id: StringName,
	progress_before: int,
	progress_after: int
) -> Dictionary:
	var recipe = get_recipe_definition(recipe_id)
	var required_days := int(recipe.duration_days) if recipe != null else 0
	var base_output_amount := int(recipe.output_amount) if recipe != null and completed else 0
	var output_amount: int = game_state.calculate_building_production_output(
		&"food_workshop", base_output_amount
	) if completed else 0
	var output_display_name: String = game_state.get_item_display_name(output_item_id) if output_item_id != &"" else ""
	var progress_update := {
		"recipe_id": recipe_id,
		"progress_before": progress_before,
		"progress_after": progress_after,
		"required_days": required_days,
		"completed": completed,
		"output_item_id": output_item_id,
		"base_output_amount": base_output_amount,
		"output_amount": output_amount,
	}
	return {
		"success": true,
		"had_active_food_workshop": had_active,
		"food_workshop_completed": completed,
		"food_workshop_progress_updates": [progress_update] if had_active else [],
		"recipe_id": recipe_id,
		"display_name": String(recipe.display_name) if recipe != null else "",
		"progress_before": progress_before,
		"progress_after": progress_after,
		"required_days": required_days,
		"output_item_id": output_item_id,
		"output_item_display_name": output_display_name,
		"base_output_amount": base_output_amount,
		"output_amount": output_amount,
		"production_details": game_state.get_building_production_details(&"food_workshop"),
		"effect_text": "食物制造完成：%s ×%d 已自动存入仓库。" % [output_display_name, output_amount] if completed else "",
	}


func _build_recipe_definitions() -> void:
	recipe_definitions[&"expedition_ration_recipe"] = FoodRecipeDataScript.new().setup(
		&"expedition_ration_recipe",
		"远征干粮",
		"便于保存和携带的干粮，是冒险队在野外行动时的基础补给。",
		1,
		{"food": 3},
		ITEM_EXPEDITION_RATION,
		3,
		&"ration"
	)
	recipe_definitions[&"hearty_stew_recipe"] = FoodRecipeDataScript.new().setup(
		&"hearty_stew_recipe",
		"丰盛炖汤",
		"热乎乎的炖汤，让队伍在整次远征中更加耐打。",
		2,
		{"food": 4},
		ITEM_HEARTY_STEW,
		1,
		&"special_meal"
	)
	recipe_definitions[&"hunter_roast_recipe"] = FoodRecipeDataScript.new().setup(
		&"hunter_roast_recipe",
		"猎手烤肉",
		"扎实的烤肉，让队伍在整次远征中攻击更有力。",
		2,
		{"food": 4},
		ITEM_HUNTER_ROAST,
		1,
		&"special_meal"
	)


func _build_meal_definitions() -> void:
	meal_definitions[ITEM_HEARTY_STEW] = ExpeditionMealDataScript.new().setup(
		ITEM_HEARTY_STEW,
		"丰盛炖汤",
		"整次远征中，全队最大生命值+4。",
		4,
		0
	)
	meal_definitions[ITEM_HUNTER_ROAST] = ExpeditionMealDataScript.new().setup(
		ITEM_HUNTER_ROAST,
		"猎手烤肉",
		"整次远征中，全队攻击力+1。",
		0,
		1
	)

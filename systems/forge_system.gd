class_name ForgeSystem
extends RefCounted

const CraftRecipeDefinitionScript := preload("res://scripts/data/craft_recipe_definition.gd")
const ForgeCraftStateScript := preload("res://scripts/data/forge_craft_state.gd")

const NO_ACTIVE_RECIPE: StringName = &""

var recipe_definitions: Dictionary = {}


func _init() -> void:
	_build_recipe_definitions()


func create_initial_state():
	return ForgeCraftStateScript.new().setup()


func get_recipe_definition(recipe_id: StringName):
	return recipe_definitions.get(recipe_id, null)


func get_recipe_data(game_state: Node, recipe_id: StringName) -> Dictionary:
	var recipe = get_recipe_definition(recipe_id)
	if recipe == null:
		return {}
	var data: Dictionary = recipe.to_dictionary()
	data["equipment_definition"] = game_state.equipment_system.get_equipment_definition_data(recipe.result_equipment_id)
	data["can_start"] = can_start_recipe(game_state, recipe_id)
	data["start_error"] = get_start_error(game_state, recipe_id)
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


func can_start_recipe(game_state: Node, recipe_id: StringName) -> bool:
	return get_start_error(game_state, recipe_id).is_empty()


func get_start_error(game_state: Node, recipe_id: StringName) -> String:
	var recipe = get_recipe_definition(recipe_id)
	if recipe == null:
		return "未知配方"
	if game_state.forge_state == null:
		return "制造所状态缺失"
	if bool(game_state.forge_state.is_active):
		return "已有打造项目进行中"
	if game_state.equipment_system.get_equipment_definition(recipe.result_equipment_id) == null:
		return "装备数据缺失"
	if int(game_state.resources.get("ore", 0)) < int(recipe.ore_cost):
		return "矿石不足"
	if int(game_state.resources.get("herb", 0)) < int(recipe.herb_cost):
		return "草药不足"
	if int(game_state.resources.get("food", 0)) < int(recipe.food_cost):
		return "粮食不足"
	if int(game_state.resources.get("medicine", 0)) < int(recipe.medicine_cost):
		return "药品不足"
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
	game_state.resources["ore"] = int(game_state.resources.get("ore", 0)) - int(recipe.ore_cost)
	game_state.resources["herb"] = int(game_state.resources.get("herb", 0)) - int(recipe.herb_cost)
	game_state.resources["food"] = int(game_state.resources.get("food", 0)) - int(recipe.food_cost)
	game_state.resources["medicine"] = int(game_state.resources.get("medicine", 0)) - int(recipe.medicine_cost)
	game_state.forge_state.setup(
		recipe.recipe_id,
		recipe.result_equipment_id,
		0,
		int(recipe.craft_time_days),
		int(game_state.current_day),
		true,
		false
	)

	return _make_report(game_state, recipe_id, true, false, &"", 0, 0)


func process_daily_forge(game_state: Node) -> Dictionary:
	if game_state.forge_state == null or not bool(game_state.forge_state.is_active):
		return {
			"had_active_forge": false,
			"forge_completed": false,
		}

	var recipe_id: StringName = StringName(game_state.forge_state.active_recipe_id)
	var recipe = get_recipe_definition(recipe_id)
	if recipe == null:
		game_state.forge_state.clear()
		return {
			"had_active_forge": false,
			"forge_completed": false,
			"error": "打造配方缺失，已清空制造状态。",
		}

	var progress_before := int(game_state.forge_state.progress_days)
	var required_days := int(game_state.forge_state.required_days)
	var progress_after := progress_before + 1
	var completed := progress_after >= required_days
	game_state.forge_state.progress_days = progress_after

	var equipment_instance_id: StringName = &""
	if completed:
		game_state.forge_state.is_completed = true
		equipment_instance_id = game_state.equipment_system.add_equipment(game_state, recipe.result_equipment_id)
		game_state.forge_state.clear()

	return _make_report(
		game_state,
		recipe_id,
		true,
		completed,
		equipment_instance_id,
		progress_before,
		min(progress_after, required_days)
	)


func get_active_summary(game_state: Node) -> String:
	if game_state.forge_state == null or not bool(game_state.forge_state.is_active):
		return "当前没有打造项目"
	var recipe = get_recipe_definition(StringName(game_state.forge_state.active_recipe_id))
	if recipe == null:
		return "当前打造项目数据缺失"
	return "%s：%d/%d天" % [
		String(recipe.display_name),
		int(game_state.forge_state.progress_days),
		int(game_state.forge_state.required_days),
	]


func _make_report(
	game_state: Node,
	recipe_id: StringName,
	had_active: bool,
	completed: bool,
	equipment_instance_id: StringName,
	progress_before: int,
	progress_after: int
) -> Dictionary:
	var recipe = get_recipe_definition(recipe_id)
	var equipment_definition: Dictionary = {}
	if recipe != null:
		equipment_definition = game_state.equipment_system.get_equipment_definition_data(recipe.result_equipment_id)
	return {
		"success": true,
		"had_active_forge": had_active,
		"forge_completed": completed,
		"recipe_id": recipe_id,
		"display_name": String(recipe.display_name) if recipe != null else "",
		"result_equipment_id": recipe.result_equipment_id if recipe != null else &"",
		"result_display_name": String(equipment_definition.get("display_name", "")),
		"equipment_instance_id": equipment_instance_id,
		"progress_before": progress_before,
		"progress_after": progress_after,
		"required_days": int(recipe.craft_time_days) if recipe != null else 0,
		"effect_text": "打造完成：%s 已加入仓库。" % String(equipment_definition.get("display_name", "")) if completed else "",
	}


func _build_recipe_definitions() -> void:
	recipe_definitions[&"craft_iron_sword"] = _recipe(&"craft_iron_sword", &"iron_sword", "铁制长剑", "打造一把适合守卫使用的基础长剑。", 2, 4, 0)
	recipe_definitions[&"craft_guardian_hammer"] = _recipe(&"craft_guardian_hammer", &"guardian_hammer", "守护战锤", "打造一把攻守兼备的守卫战锤。", 3, 5, 1)
	recipe_definitions[&"craft_hunter_bow"] = _recipe(&"craft_hunter_bow", &"hunter_bow", "猎人短弓", "打造一把轻便短弓，适合游侠快速开弦。", 2, 3, 1)
	recipe_definitions[&"craft_repeater_crossbow"] = _recipe(&"craft_repeater_crossbow", &"repeater_crossbow", "连射弩", "打造一把带有简易连发结构的弩机。", 3, 5, 1)
	recipe_definitions[&"craft_arcane_staff"] = _recipe(&"craft_arcane_staff", &"arcane_staff", "奥术法杖", "打造一根能稳定引导奥术的法杖。", 3, 4, 2)
	recipe_definitions[&"craft_healing_staff"] = _recipe(&"craft_healing_staff", &"healing_staff", "治愈木杖", "打造一根带有药草气味的治愈短杖。", 2, 2, 3)
	recipe_definitions[&"craft_iron_armor"] = _recipe(&"craft_iron_armor", &"iron_armor", "铁制护甲", "打造一件结实可靠的基础护甲。", 2, 4, 0)
	recipe_definitions[&"craft_light_leather_armor"] = _recipe(&"craft_light_leather_armor", &"light_leather_armor", "轻便皮甲", "打造一件轻巧且不妨碍行动的皮甲。", 2, 3, 1)


func _recipe(
	recipe_id: StringName,
	result_equipment_id: StringName,
	display_name: String,
	description: String,
	craft_time_days: int,
	ore_cost: int,
	herb_cost: int
):
	return CraftRecipeDefinitionScript.new().setup(
		recipe_id,
		result_equipment_id,
		display_name,
		description,
		craft_time_days,
		ore_cost,
		herb_cost,
		0,
		0,
		&"weapon_forge"
	)

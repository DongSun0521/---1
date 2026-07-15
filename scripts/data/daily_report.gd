class_name DailyReport
extends RefCounted

var day_before: int = 0
var day_after: int = 0
var reason: StringName = &""

var farm_events: Array = []
var food_workshop_events: Array = []
var hospital_events: Array = []
var weapon_forge_events: Array = []
var construction_events: Array = []
var village_consumption_events: Array = []
var expedition_consumption_events: Array = []

var resource_changes: Dictionary = {}
var resource_change_details: Dictionary = {}
var warnings: Array[String] = []


func setup(p_day_before: int, p_day_after: int, p_reason: StringName) -> DailyReport:
	day_before = p_day_before
	day_after = p_day_after
	reason = p_reason
	return self


func add_event(section: StringName, event: Dictionary) -> void:
	match section:
		&"farm":
			farm_events.append(event)
		&"food_workshop":
			food_workshop_events.append(event)
		&"hospital":
			hospital_events.append(event)
		&"weapon_forge":
			weapon_forge_events.append(event)
		&"construction":
			construction_events.append(event)
		&"village_consumption":
			village_consumption_events.append(event)
		&"expedition_consumption":
			expedition_consumption_events.append(event)


func add_resource_change(resource_id: StringName, amount: int, source: String) -> void:
	if amount == 0:
		return
	resource_changes[resource_id] = int(resource_changes.get(resource_id, 0)) + amount
	if not resource_change_details.has(resource_id):
		resource_change_details[resource_id] = []
	resource_change_details[resource_id].append({
		"source": source,
		"amount": amount,
	})


func to_dictionary() -> Dictionary:
	return {
		"day_before": day_before,
		"day_after": day_after,
		"reason": reason,
		"farm_events": farm_events.duplicate(true),
		"food_workshop_events": food_workshop_events.duplicate(true),
		"hospital_events": hospital_events.duplicate(true),
		"weapon_forge_events": weapon_forge_events.duplicate(true),
		"construction_events": construction_events.duplicate(true),
		"village_consumption_events": village_consumption_events.duplicate(true),
		"expedition_consumption_events": expedition_consumption_events.duplicate(true),
		"resource_changes": resource_changes.duplicate(true),
		"resource_change_details": resource_change_details.duplicate(true),
		"warnings": warnings.duplicate(true),
	}

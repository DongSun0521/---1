class_name CharacterRoster
extends RefCounted

const CharacterEnumsScript := preload("res://scripts/data/character_enums.gd")
const CharacterRecordScript := preload("res://scripts/data/character_record.gd")
const CombatCharacterDataScript := preload("res://scripts/data/combat_character_data.gd")
const LifeCharacterDataScript := preload("res://scripts/data/life_character_data.gd")
const CombatStatsScript := preload("res://scripts/data/combat_stats.gd")
const LifeStatsScript := preload("res://scripts/data/life_stats.gd")

const DEFAULT_COMBAT_IDS: Array[StringName] = [&"guard", &"hunter", &"mage", &"doctor"]
const DEFAULT_LIFE_IDS: Array[StringName] = [&"life_ahe", &"life_atie", &"life_xiaoyao"]
const MAX_PARTY_SIZE := 4
const BASE_EXPERIENCE_TO_NEXT_LEVEL := 100
const EXPERIENCE_STEP_PER_LEVEL := 50

const LEVEL_GROWTH_BY_CHARACTER := {
	&"guard": {"max_hp": 8, "attack": 1, "defense": 2, "speed": 0},
	&"hunter": {"max_hp": 4, "attack": 2, "defense": 1, "speed": 1},
	&"mage": {"max_hp": 4, "attack": 3, "defense": 0, "speed": 0},
	&"doctor": {"max_hp": 5, "attack": 1, "defense": 1, "speed": 1},
}

const COMBAT_CLASS_BY_PROFESSION := {
	&"guard": CharacterEnumsScript.CombatClass.WARRIOR,
	&"mage": CharacterEnumsScript.CombatClass.MAGE,
	&"ranger": CharacterEnumsScript.CombatClass.RANGER,
	&"healer": CharacterEnumsScript.CombatClass.HEALER,
}

const PORTRAIT_PATHS := {
	&"guard": "res://assets/art/characters/sprite_frames/ZhanShi_frames.tres",
	&"hunter": "res://assets/art/characters/sprite_frames/YouXia_frames.tres",
	&"mage": "res://assets/art/characters/sprite_frames/FaShi_frames.tres",
	&"doctor": "res://assets/art/characters/sprite_frames/ZhiLiao_frames.tres",
}

var characters: Dictionary = {}
var character_order: Array[StringName] = []
var next_generated_sequence: int = 1


func initialize_defaults(character_database: RefCounted) -> void:
	characters.clear()
	character_order.clear()
	next_generated_sequence = 1
	for party_slot: int in range(DEFAULT_COMBAT_IDS.size()):
		var character_id: StringName = DEFAULT_COMBAT_IDS[party_slot]
		var definition = character_database.get_character_definition(character_id)
		if definition == null:
			continue
		var record := CharacterRecordScript.new().setup_common(
			character_id,
			CharacterEnumsScript.CharacterType.COMBAT,
			String(definition.display_name),
			_take_sequence()
		)
		record.portrait_path = String(PORTRAIT_PATHS.get(character_id, ""))
		record.quality = CharacterEnumsScript.Quality.COMMON
		record.traits = definition.trait_ids.duplicate()
		record.is_locked = true
		record.metadata = {
			"is_default_character": true,
			"description": String(definition.description),
		}
		var base_stats := CombatStatsScript.from_dictionary(definition.base_combat_stats.to_dictionary())
		record.combat_data = CombatCharacterDataScript.new().setup(
			int(COMBAT_CLASS_BY_PROFESSION.get(definition.profession_id, CharacterEnumsScript.CombatClass.WARRIOR)),
			definition.profession_id,
			base_stats,
			base_stats.max_hp,
			definition.skill_ids,
			definition.trait_ids,
			true,
			party_slot,
			definition.battle_visual_id
		)
		record.combat_data.level_growth_stats = _create_level_growth_stats(character_id)
		record.experience_to_next_level = get_experience_to_next_level(record.level)
		add_character(record)

	_add_default_life_character(&"life_ahe", "阿禾", LifeStatsScript.new().setup_core(82, 28, 42, 24, 18))
	_add_default_life_character(&"life_atie", "阿铁", LifeStatsScript.new().setup_core(24, 85, 48, 22, 16))
	_add_default_life_character(&"life_xiaoyao", "小药", LifeStatsScript.new().setup_core(34, 26, 38, 35, 86))


func add_character(record: CharacterRecord) -> bool:
	if record == null or record.character_id == &"" or characters.has(record.character_id):
		return false
	if not record.is_combat_character() and not record.is_life_character():
		return false
	characters[record.character_id] = record
	character_order.append(record.character_id)
	next_generated_sequence = maxi(next_generated_sequence, record.created_sequence + 1)
	return true


func add_character_from_dictionary(data: Dictionary) -> bool:
	return add_character(CharacterRecordScript.from_dictionary(data))


func remove_character(character_id: StringName, force: bool = false) -> bool:
	var record: CharacterRecord = characters.get(character_id, null)
	if record == null or (record.is_locked and not force):
		return false
	var removed_party_member := record.is_combat_character() and record.combat_data != null and record.combat_data.is_in_party
	if removed_party_member and get_party_character_ids().size() <= 1:
		return false
	characters.erase(character_id)
	character_order.erase(character_id)
	if removed_party_member:
		_normalize_party_slots()
	return true


func has_character(character_id: StringName) -> bool:
	return characters.has(character_id)


func get_character(character_id: StringName) -> CharacterRecord:
	return characters.get(character_id, null)


func get_character_snapshot(character_id: StringName) -> Dictionary:
	var record := get_character(character_id)
	return record.to_dictionary() if record != null else {}


func get_all_characters() -> Array:
	return _get_records_by_type(-1)


func get_all_combat_characters() -> Array:
	return _get_records_by_type(CharacterEnumsScript.CharacterType.COMBAT)


func get_all_life_characters() -> Array:
	return _get_records_by_type(CharacterEnumsScript.CharacterType.LIFE)


func get_all_character_snapshots() -> Array:
	var result: Array = []
	for record: CharacterRecord in get_all_characters():
		result.append(record.to_dictionary())
	return result


func get_combat_character_snapshots() -> Array:
	var result: Array = []
	for record: CharacterRecord in get_all_combat_characters():
		result.append(record.to_dictionary())
	return result


func get_life_character_snapshots() -> Array:
	var result: Array = []
	for record: CharacterRecord in get_all_life_characters():
		result.append(record.to_dictionary())
	return result


func get_party_character_ids() -> Array[StringName]:
	var party_records: Array = []
	for record: CharacterRecord in get_all_combat_characters():
		if record.combat_data.is_in_party and record.combat_data.party_slot >= 0:
			party_records.append(record)
	party_records.sort_custom(func(a: CharacterRecord, b: CharacterRecord) -> bool:
		if a.combat_data.party_slot == b.combat_data.party_slot:
			return a.created_sequence < b.created_sequence
		return a.combat_data.party_slot < b.combat_data.party_slot
	)
	var ids: Array[StringName] = []
	for record: CharacterRecord in party_records:
		ids.append(record.character_id)
	return ids


func set_party_members(character_ids: Array[StringName]) -> bool:
	if character_ids.is_empty() or character_ids.size() > MAX_PARTY_SIZE:
		return false
	var unique_ids: Array[StringName] = []
	for character_id: StringName in character_ids:
		var record := get_character(character_id)
		if record == null or not record.is_combat_character() or unique_ids.has(character_id):
			return false
		unique_ids.append(character_id)
	for record: CharacterRecord in get_all_combat_characters():
		record.combat_data.is_in_party = false
		record.combat_data.party_slot = -1
	for party_slot: int in range(unique_ids.size()):
		var record := get_character(unique_ids[party_slot])
		record.combat_data.is_in_party = true
		record.combat_data.party_slot = party_slot
	return true


func set_character_party_status(character_id: StringName, is_in_party: bool) -> bool:
	var record := get_character(character_id)
	if record == null or not record.is_combat_character():
		return false
	var party_ids := get_party_character_ids()
	if is_in_party:
		if party_ids.has(character_id):
			return true
		if party_ids.size() >= MAX_PARTY_SIZE:
			return false
		party_ids.append(character_id)
	else:
		if not party_ids.has(character_id):
			return true
		if party_ids.size() <= 1:
			return false
		party_ids.erase(character_id)
	return set_party_members(party_ids)


func move_party_character(character_id: StringName, target_slot: int) -> bool:
	var party_ids := get_party_character_ids()
	var current_slot := party_ids.find(character_id)
	if current_slot < 0 or target_slot < 0 or target_slot >= party_ids.size():
		return false
	if current_slot == target_slot:
		return true
	party_ids.remove_at(current_slot)
	party_ids.insert(target_slot, character_id)
	return set_party_members(party_ids)


func generate_unique_id(prefix: String = "character") -> StringName:
	var safe_prefix := prefix.strip_edges().to_lower().replace(" ", "_")
	if safe_prefix.is_empty():
		safe_prefix = "character"
	var generated_id := StringName("%s_%06d" % [safe_prefix, next_generated_sequence])
	while characters.has(generated_id):
		next_generated_sequence += 1
		generated_id = StringName("%s_%06d" % [safe_prefix, next_generated_sequence])
	next_generated_sequence += 1
	return generated_id


func set_life_assignment(
	character_id: StringName,
	building_id: StringName,
	job_id: StringName,
	work_state: int
) -> bool:
	var record := get_character(character_id)
	if record == null or not record.is_life_character():
		return false
	record.life_data.assigned_building_id = building_id
	record.life_data.assigned_job_id = job_id
	record.life_data.work_state = clampi(work_state, CharacterEnumsScript.WorkState.IDLE, CharacterEnumsScript.WorkState.UNAVAILABLE)
	return true


func set_character_progression(character_id: StringName, level: int, experience: int, experience_to_next_level: int) -> bool:
	var record := get_character(character_id)
	if record == null:
		return false
	record.level = max(1, level)
	record.experience = max(0, experience)
	record.experience_to_next_level = max(1, experience_to_next_level)
	return true


func grant_experience(character_id: StringName, amount: int) -> Dictionary:
	var record := get_character(character_id)
	if record == null or not record.is_combat_character() or amount <= 0:
		return {"success": false, "character_id": character_id, "levels_gained": 0}
	var old_level := record.level
	record.experience += amount
	while record.experience >= record.experience_to_next_level:
		record.experience -= record.experience_to_next_level
		record.level += 1
		record.experience_to_next_level = get_experience_to_next_level(record.level)
	return {
		"success": true,
		"character_id": character_id,
		"experience_gained": amount,
		"old_level": old_level,
		"new_level": record.level,
		"levels_gained": record.level - old_level,
		"experience": record.experience,
		"experience_to_next_level": record.experience_to_next_level,
	}


func get_experience_to_next_level(level: int) -> int:
	return BASE_EXPERIENCE_TO_NEXT_LEVEL + max(0, level - 1) * EXPERIENCE_STEP_PER_LEVEL


func ensure_stage12b_defaults(previous_save_version: int) -> void:
	if previous_save_version < 2:
		for character_id: StringName in DEFAULT_COMBAT_IDS:
			var record := get_character(character_id)
			if record == null or not record.is_combat_character():
				continue
			record.combat_data.level_growth_stats = _create_level_growth_stats(character_id)
			record.experience_to_next_level = get_experience_to_next_level(record.level)
	_normalize_party_slots()


func create_combat_runtime_adapter() -> Dictionary:
	var states: Dictionary = {}
	for record: CharacterRecord in get_all_combat_characters():
		states[record.character_id] = record.combat_data
	return states


func create_party_unit_state(character_id: StringName, character_database: RefCounted, final_stat_details: Dictionary) -> Dictionary:
	var record := get_character(character_id)
	if record == null or not record.is_combat_character():
		return {}
	var combat := record.combat_data
	var final_stats: Dictionary = {}
	for stat_id: String in final_stat_details.keys():
		final_stats[stat_id] = final_stat_details[stat_id].get("final", 0)
	var skill_id: StringName = combat.skill_ids[0] if not combat.skill_ids.is_empty() else &""
	var skill: Dictionary = character_database.get_skill_data(skill_id)
	var max_hp: int = maxi(1, int(final_stats.get("max_hp", combat.base_combat_stats.max_hp)))
	return {
		"unit_id": character_id,
		"character_id": character_id,
		"display_name": record.display_name,
		"role": character_database.get_profession_display_name(combat.profession_id),
		"profession_id": combat.profession_id,
		"combat_class": combat.combat_class,
		"is_player_unit": true,
		"base_max_hp": int(combat.base_combat_stats.max_hp),
		"base_attack": int(combat.base_combat_stats.attack),
		"max_hp": max_hp,
		"current_hp": clampi(combat.current_hp, 0, max_hp),
		"attack": int(final_stats.get("attack", 0)),
		"defense": int(final_stats.get("defense", 0)),
		"speed": int(final_stats.get("speed", 0)),
		"attack_speed": float(final_stats.get("attack_speed", final_stats.get("speed", 0))),
		"crit_rate": float(final_stats.get("crit_rate", 0.0)),
		"crit_damage": float(final_stats.get("crit_damage", 1.5)),
		"skill_id": skill_id,
		"skill_name": String(skill.get("skill_name", "")),
		"skill_type": String(skill.get("skill_type", "")),
		"skill_multiplier": float(skill.get("skill_multiplier", 0.0)),
		"skill_heal_amount": int(skill.get("skill_heal_amount", 0)),
		"skill_cooldown_duration": int(skill.get("skill_cooldown_duration", 0)),
		"skill_cooldown": 0,
		"is_defending": false,
		"battle_visual_id": combat.battle_visual_id,
		"injury_state": combat.injury_state,
	}


func apply_legacy_runtime_states(legacy_states: Dictionary) -> void:
	for raw_character_id in legacy_states.keys():
		var character_id := StringName(raw_character_id)
		var record := get_character(character_id)
		if record == null or not record.is_combat_character():
			continue
		var state = legacy_states[raw_character_id]
		var data: Dictionary = state.to_dictionary() if state is Object and state.has_method("to_dictionary") else state
		record.combat_data.current_hp = max(0, int(data.get("current_hp", record.combat_data.current_hp)))
		record.combat_data.equipped_weapon_id = StringName(data.get("equipped_weapon_id", &""))
		record.combat_data.equipped_armor_id = StringName(data.get("equipped_armor_id", &""))
		record.combat_data.equipped_weapon_instance_id = StringName(data.get("equipped_weapon_instance_id", record.combat_data.equipped_weapon_id))
		record.combat_data.equipped_armor_instance_id = StringName(data.get("equipped_armor_instance_id", record.combat_data.equipped_armor_id))
		record.combat_data.injury_state = StringName(data.get("injury_state", &"healthy"))


func to_dictionary() -> Dictionary:
	var serialized_characters: Array = []
	for character_id: StringName in character_order:
		var record := get_character(character_id)
		if record != null:
			serialized_characters.append(record.to_dictionary())
	return {
		"next_generated_sequence": next_generated_sequence,
		"character_order": character_order.duplicate(),
		"characters": serialized_characters,
	}


func load_from_dictionary(data: Dictionary) -> bool:
	characters.clear()
	character_order.clear()
	next_generated_sequence = max(1, int(data.get("next_generated_sequence", 1)))
	var serialized = data.get("characters", [])
	var entries: Array = []
	if serialized is Dictionary:
		for raw_id in serialized.keys():
			var entry: Dictionary = serialized[raw_id].duplicate(true)
			if not entry.has("character_id"):
				entry["character_id"] = raw_id
			entries.append(entry)
	elif serialized is Array:
		entries = serialized
	for entry in entries:
		if not entry is Dictionary:
			continue
		var record := CharacterRecordScript.from_dictionary(entry)
		add_character(record)
	var saved_order: Array = data.get("character_order", [])
	if not saved_order.is_empty():
		var restored_order: Array[StringName] = []
		for raw_id in saved_order:
			var character_id := StringName(raw_id)
			if characters.has(character_id) and not restored_order.has(character_id):
				restored_order.append(character_id)
		for character_id: StringName in character_order:
			if not restored_order.has(character_id):
				restored_order.append(character_id)
		character_order = restored_order
	return not characters.is_empty()


func get_debug_summary() -> String:
	var lines := PackedStringArray()
	lines.append("CharacterRoster: combat=%d life=%d" % [get_all_combat_characters().size(), get_all_life_characters().size()])
	for record: CharacterRecord in get_all_characters():
		lines.append("%s | %s | %s | Lv.%d" % [
			String(record.character_id),
			record.display_name,
			String(CharacterEnumsScript.character_type_name(record.character_type)),
			record.level,
		])
		if record.is_life_character():
			var stats: Dictionary = record.life_data.life_stats.to_dictionary()
			lines.append("  farming=%d crafting=%d gathering=%d research=%d medical=%d" % [
				int(stats.get("farming", 0)), int(stats.get("crafting", 0)), int(stats.get("gathering", 0)),
				int(stats.get("research", 0)), int(stats.get("medical", 0)),
			])
	return "\n".join(lines)


func _add_default_life_character(character_id: StringName, display_name: String, stats: LifeStats) -> void:
	var record := CharacterRecordScript.new().setup_common(
		character_id,
		CharacterEnumsScript.CharacterType.LIFE,
		display_name,
		_take_sequence()
	)
	record.quality = CharacterEnumsScript.Quality.COMMON
	record.metadata = {"is_debug_character": true}
	record.life_data = LifeCharacterDataScript.new().setup(stats)
	add_character(record)


func _get_records_by_type(character_type: int) -> Array:
	var result: Array = []
	for character_id: StringName in character_order:
		var record := get_character(character_id)
		if record == null:
			continue
		if character_type < 0 or record.character_type == character_type:
			result.append(record)
	return result


func _take_sequence() -> int:
	var sequence := next_generated_sequence
	next_generated_sequence += 1
	return sequence


func _create_level_growth_stats(character_id: StringName) -> CombatStats:
	var values: Dictionary = LEVEL_GROWTH_BY_CHARACTER.get(character_id, {})
	return CombatStatsScript.new().setup(
		int(values.get("max_hp", 0)),
		int(values.get("attack", 0)),
		int(values.get("defense", 0)),
		int(values.get("speed", 0)),
		float(values.get("speed", 0)),
		0.0,
		0.0
	)


func _normalize_party_slots() -> void:
	var party_ids := get_party_character_ids()
	if party_ids.is_empty():
		for record: CharacterRecord in get_all_combat_characters():
			party_ids.append(record.character_id)
			break
	if party_ids.size() > MAX_PARTY_SIZE:
		party_ids.resize(MAX_PARTY_SIZE)
	if not party_ids.is_empty():
		set_party_members(party_ids)

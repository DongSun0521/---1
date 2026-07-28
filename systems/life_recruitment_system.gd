class_name LifeRecruitmentSystem
extends RefCounted

const CharacterEnumsScript := preload("res://scripts/data/character_enums.gd")
const CharacterRecordScript := preload("res://scripts/data/character_record.gd")
const LifeCharacterDataScript := preload("res://scripts/data/life_character_data.gd")
const LifeStatsScript := preload("res://scripts/data/life_stats.gd")
const Stage12Config := preload("res://scripts/data/stage12_balance_config.gd")

const CANDIDATE_COUNT := Stage12Config.CANDIDATE_COUNT
const RECRUITMENT_RESOURCE_ID := Stage12Config.RECRUITMENT_RESOURCE_ID
const REFRESH_COST := Stage12Config.RECRUITMENT_REFRESH_COST
const BASE_LIFE_CAPACITY := Stage12Config.BASE_LIFE_CAPACITY
const CAPACITY_PER_RESIDENCE_LEVEL := Stage12Config.CAPACITY_PER_RESIDENCE_LEVEL
const INITIAL_RANDOM_SEED := Stage12Config.RECRUITMENT_INITIAL_RANDOM_SEED

const LIFE_STAT_IDS: Array[StringName] = [
	&"farming",
	&"crafting",
	&"gathering",
	&"research",
	&"medical",
]
const STAT_DISPLAY_NAMES := {
	&"farming": "农业",
	&"crafting": "制造",
	&"gathering": "采集",
	&"research": "研究",
	&"medical": "医疗",
}
const TRAIT_BY_PRIMARY_STAT := {
	&"farming": &"seasoned_farmer",
	&"crafting": &"steady_hands",
	&"gathering": &"keen_collector",
	&"research": &"curious_researcher",
	&"medical": &"herbal_instinct",
}
const NAME_POOL: Array[String] = Stage12Config.RECRUITMENT_NAME_POOL

# Roll intervals are inclusive on the lower bound and exclusive on the upper
# bound. Legendary remains disabled for natural generation in Stage 12E.
const QUALITY_PROBABILITIES := Stage12Config.QUALITY_PROBABILITIES
const QUALITY_ATTRIBUTE_RANGES := Stage12Config.QUALITY_ATTRIBUTE_RANGES
const RECRUIT_COST_BY_QUALITY := Stage12Config.RECRUIT_COST_BY_QUALITY
const QUALITY_DISPLAY_NAMES := {
	CharacterEnumsScript.Quality.COMMON: "普通",
	CharacterEnumsScript.Quality.RARE: "稀有",
	CharacterEnumsScript.Quality.EPIC: "史诗",
	CharacterEnumsScript.Quality.LEGENDARY: "传奇",
}

var last_error: String = ""


func initialize_new_game(game_state: Node) -> Dictionary:
	game_state.life_recruitment_state = {
		"candidates": [],
		"refresh_sequence": 0,
		"random_seed": INITIAL_RANDOM_SEED,
		"random_state": 0,
	}
	var rng := RandomNumberGenerator.new()
	rng.seed = INITIAL_RANDOM_SEED
	game_state.life_recruitment_state["random_state"] = rng.state
	_fill_candidate_slots(game_state)
	last_error = ""
	return game_state.life_recruitment_state.duplicate(true)


func normalize_loaded_state(game_state: Node, raw_state: Dictionary) -> Dictionary:
	var normalized := {
		"candidates": [],
		"refresh_sequence": max(0, int(raw_state.get("refresh_sequence", 0))),
		"random_seed": int(raw_state.get("random_seed", INITIAL_RANDOM_SEED)),
		"random_state": int(raw_state.get("random_state", 0)),
	}
	if int(normalized["random_seed"]) == 0:
		normalized["random_seed"] = INITIAL_RANDOM_SEED
	if int(normalized["random_state"]) == 0:
		var initial_rng := RandomNumberGenerator.new()
		initial_rng.seed = int(normalized["random_seed"])
		normalized["random_state"] = initial_rng.state

	var seen_ids: Dictionary = {}
	var highest_created_sequence := 0
	var raw_candidates = raw_state.get("candidates", [])
	if raw_candidates is Array:
		for raw_entry in raw_candidates:
			if not raw_entry is Dictionary:
				continue
			var entry := _normalize_candidate_entry(game_state, raw_entry)
			if entry.is_empty():
				continue
			var character_data: Dictionary = entry.get("character", {})
			var character_id := StringName(character_data.get("character_id", &""))
			if seen_ids.has(character_id) or game_state.has_roster_character(character_id):
				continue
			seen_ids[character_id] = true
			highest_created_sequence = maxi(
				highest_created_sequence,
				int(character_data.get("created_sequence", 0))
			)
			normalized["candidates"].append(entry)
			if normalized["candidates"].size() >= CANDIDATE_COUNT:
				break
	game_state.character_roster.ensure_next_generated_sequence_at_least(
		highest_created_sequence + 1
	)
	game_state.life_recruitment_state = normalized
	_fill_candidate_slots(game_state)
	last_error = ""
	return game_state.life_recruitment_state.duplicate(true)


func generate_candidate(game_state: Node, forced_quality: int = -1) -> Dictionary:
	var entry := _generate_candidate_entry(game_state, forced_quality)
	return _public_candidate_snapshot(game_state, entry)


func get_candidates(game_state: Node) -> Array:
	var result: Array = []
	for entry: Dictionary in game_state.life_recruitment_state.get("candidates", []):
		result.append(_public_candidate_snapshot(game_state, entry))
	return result


func get_candidate(game_state: Node, candidate_id: StringName) -> Dictionary:
	for entry: Dictionary in game_state.life_recruitment_state.get("candidates", []):
		var character_data: Dictionary = entry.get("character", {})
		if StringName(character_data.get("character_id", &"")) == candidate_id:
			return _public_candidate_snapshot(game_state, entry)
	return {}


func set_candidate_locked(
	game_state: Node,
	candidate_id: StringName,
	is_locked: bool
) -> bool:
	var candidates: Array = game_state.life_recruitment_state.get("candidates", [])
	for index: int in range(candidates.size()):
		var entry: Dictionary = candidates[index]
		var character_data: Dictionary = entry.get("character", {})
		if StringName(character_data.get("character_id", &"")) != candidate_id:
			continue
		entry["is_locked"] = is_locked
		candidates[index] = entry
		game_state.life_recruitment_state["candidates"] = candidates
		last_error = ""
		return true
	last_error = "候选角色不存在。"
	return false


func refresh_candidates(game_state: Node) -> Dictionary:
	if game_state.get_resource_amount(RECRUITMENT_RESOURCE_ID) < REFRESH_COST:
		last_error = "粮食不足，无法刷新候选。"
		return {"success": false, "error": last_error}
	var candidates: Array = game_state.life_recruitment_state.get("candidates", [])
	var kept: Array = []
	for entry: Dictionary in candidates:
		if bool(entry.get("is_locked", false)):
			kept.append(entry)
	game_state.life_recruitment_state["candidates"] = kept
	_fill_candidate_slots(game_state)
	game_state.life_recruitment_state["refresh_sequence"] = int(
		game_state.life_recruitment_state.get("refresh_sequence", 0)
	) + 1
	game_state.add_resource(RECRUITMENT_RESOURCE_ID, -REFRESH_COST)
	last_error = ""
	return {
		"success": true,
		"refresh_cost": REFRESH_COST,
		"candidates": get_candidates(game_state),
	}


func recruit_candidate(game_state: Node, candidate_id: StringName) -> Dictionary:
	var candidates: Array = game_state.life_recruitment_state.get("candidates", [])
	var candidate_index := -1
	var entry: Dictionary = {}
	for index: int in range(candidates.size()):
		var current: Dictionary = candidates[index]
		var character_data: Dictionary = current.get("character", {})
		if StringName(character_data.get("character_id", &"")) == candidate_id:
			candidate_index = index
			entry = current
			break
	if candidate_index < 0:
		last_error = "候选角色不存在。"
		return {"success": false, "error": last_error}
	var current_count: int = game_state.get_all_life_characters().size()
	var capacity: int = get_life_character_capacity(game_state)
	if current_count >= capacity:
		last_error = "生活角色容量已满。"
		return {"success": false, "error": last_error}
	var cost := int(entry.get("recruitment_cost", 0))
	if game_state.get_resource_amount(RECRUITMENT_RESOURCE_ID) < cost:
		last_error = "粮食不足，无法招募。"
		return {"success": false, "error": last_error}

	var character_data: Dictionary = entry.get("character", {}).duplicate(true)
	character_data["is_locked"] = false
	var metadata: Dictionary = character_data.get("metadata", {}).duplicate(true)
	metadata.erase("is_recruitment_candidate")
	metadata["recruited_from_candidate"] = true
	character_data["metadata"] = metadata
	if not game_state.add_roster_character(character_data, false):
		last_error = "角色数据冲突，招募失败。"
		return {"success": false, "error": last_error}
	candidates.remove_at(candidate_index)
	game_state.life_recruitment_state["candidates"] = candidates
	_fill_candidate_slots(game_state)
	game_state.add_resource(RECRUITMENT_RESOURCE_ID, -cost)
	last_error = ""
	return {
		"success": true,
		"character_id": candidate_id,
		"recruitment_cost": cost,
		"character": game_state.get_roster_character(candidate_id),
	}


func get_life_character_capacity(game_state: Node) -> int:
	var residence_level_total := 0
	for raw_state_key in game_state.buildings.keys():
		var state_key := String(raw_state_key)
		var state = game_state.buildings[raw_state_key]
		if not state is Dictionary:
			continue
		var building_type := StringName(
			state.get("building_type", state.get("building_id", state_key))
		)
		var is_residence := building_type == &"residence" \
			or state_key == "residence" \
			or state_key.begins_with("residence_")
		if is_residence:
			residence_level_total += max(0, int(state.get("level", 1)))
	return BASE_LIFE_CAPACITY + residence_level_total * CAPACITY_PER_RESIDENCE_LEVEL


func get_capacity_details(game_state: Node) -> Dictionary:
	var current_count: int = game_state.get_all_life_characters().size()
	var capacity: int = get_life_character_capacity(game_state)
	return {
		"current_count": current_count,
		"capacity": capacity,
		"is_full": current_count >= capacity,
		"base_capacity": BASE_LIFE_CAPACITY,
		"capacity_per_residence_level": CAPACITY_PER_RESIDENCE_LEVEL,
	}


func get_cost_config() -> Dictionary:
	return {
		"resource_id": RECRUITMENT_RESOURCE_ID,
		"refresh_cost": REFRESH_COST,
		"recruit_cost_by_quality": RECRUIT_COST_BY_QUALITY.duplicate(true),
	}


func get_generation_config() -> Dictionary:
	return {
		"candidate_count": CANDIDATE_COUNT,
		"quality_probabilities": QUALITY_PROBABILITIES.duplicate(true),
		"quality_attribute_ranges": QUALITY_ATTRIBUTE_RANGES.duplicate(true),
		"name_pool": NAME_POOL.duplicate(),
		"portrait_paths": Stage12Config.LIFE_PORTRAIT_PATHS.duplicate(),
		"default_portrait_path": Stage12Config.DEFAULT_LIFE_PORTRAIT_PATH,
	}


func get_quality_for_roll(roll: int) -> int:
	var normalized_roll := clampi(roll, 0, 99)
	var cumulative := 0
	for quality: int in [
		CharacterEnumsScript.Quality.COMMON,
		CharacterEnumsScript.Quality.RARE,
		CharacterEnumsScript.Quality.EPIC,
		CharacterEnumsScript.Quality.LEGENDARY,
	]:
		cumulative += int(QUALITY_PROBABILITIES.get(quality, 0))
		if normalized_roll < cumulative:
			return quality
	return CharacterEnumsScript.Quality.COMMON


func get_quality_display_name(quality: int) -> String:
	return String(QUALITY_DISPLAY_NAMES.get(quality, "普通"))


func get_stat_display_name(stat_id: StringName) -> String:
	return String(STAT_DISPLAY_NAMES.get(stat_id, String(stat_id)))


func _fill_candidate_slots(game_state: Node) -> void:
	var candidates: Array = game_state.life_recruitment_state.get("candidates", [])
	while candidates.size() < CANDIDATE_COUNT:
		candidates.append(_generate_candidate_entry(game_state))
	if candidates.size() > CANDIDATE_COUNT:
		candidates.resize(CANDIDATE_COUNT)
	game_state.life_recruitment_state["candidates"] = candidates


func _generate_candidate_entry(game_state: Node, forced_quality: int = -1) -> Dictionary:
	var rng := _create_rng(game_state.life_recruitment_state)
	var quality := forced_quality
	if quality < CharacterEnumsScript.Quality.COMMON \
			or quality > CharacterEnumsScript.Quality.LEGENDARY:
		quality = get_quality_for_roll(rng.randi_range(0, 99))
	var primary_stat_id: StringName = LIFE_STAT_IDS[rng.randi_range(0, LIFE_STAT_IDS.size() - 1)]
	var ranges: Dictionary = QUALITY_ATTRIBUTE_RANGES.get(
		quality, QUALITY_ATTRIBUTE_RANGES[CharacterEnumsScript.Quality.COMMON]
	)
	var stats: Dictionary = {}
	var highest_other := 0
	for stat_id: StringName in LIFE_STAT_IDS:
		if stat_id == primary_stat_id:
			continue
		var value := rng.randi_range(
			int(ranges.get("other_min", 15)),
			int(ranges.get("other_max", 40))
		)
		stats[stat_id] = value
		highest_other = maxi(highest_other, value)
	var primary_min := maxi(
		int(ranges.get("primary_min", 35)),
		mini(int(ranges.get("primary_max", 55)), highest_other + 10)
	)
	stats[primary_stat_id] = rng.randi_range(
		primary_min,
		int(ranges.get("primary_max", 55))
	)
	var trait_ids := _generate_trait_ids(rng, quality, primary_stat_id)
	var created_sequence: int = game_state.character_roster.get_next_generated_sequence()
	var character_id: StringName = game_state.generate_character_id("life")
	while _candidate_id_exists(game_state, character_id):
		created_sequence = game_state.character_roster.get_next_generated_sequence()
		character_id = game_state.generate_character_id("life")
	var record := CharacterRecordScript.new().setup_common(
		character_id,
		CharacterEnumsScript.CharacterType.LIFE,
		NAME_POOL[rng.randi_range(0, NAME_POOL.size() - 1)],
		created_sequence
	)
	record.quality = quality
	record.portrait_path = Stage12Config.LIFE_PORTRAIT_PATHS[
		rng.randi_range(0, Stage12Config.LIFE_PORTRAIT_PATHS.size() - 1)
	]
	record.level = 1
	record.experience = 0
	record.experience_to_next_level = game_state.get_life_experience_to_next_level(1)
	record.traits = trait_ids.duplicate()
	record.is_locked = false
	record.metadata = {
		"is_recruitment_candidate": true,
		"specialty_stat_id": primary_stat_id,
	}
	var typed_trait_ids: Array[StringName] = []
	for raw_trait_id in trait_ids:
		typed_trait_ids.append(StringName(raw_trait_id))
	record.life_data = LifeCharacterDataScript.new().setup(
		LifeStatsScript.new().setup_core(
			int(stats.get(&"farming", 0)),
			int(stats.get(&"crafting", 0)),
			int(stats.get(&"gathering", 0)),
			int(stats.get(&"research", 0)),
			int(stats.get(&"medical", 0))
		),
		typed_trait_ids
	)
	game_state.life_recruitment_state["random_state"] = rng.state
	return {
		"character": record.to_dictionary(),
		"is_locked": false,
		"recruitment_cost": int(RECRUIT_COST_BY_QUALITY.get(quality, 6)),
	}


func _generate_trait_ids(
	rng: RandomNumberGenerator,
	quality: int,
	primary_stat_id: StringName
) -> Array[StringName]:
	var count := 1
	if quality >= CharacterEnumsScript.Quality.EPIC:
		count = 2
	elif quality == CharacterEnumsScript.Quality.RARE \
			and rng.randi_range(0, 99) < Stage12Config.RARE_SECOND_TRAIT_CHANCE_PERCENT:
		count = 2
	var result: Array[StringName] = [
		StringName(TRAIT_BY_PRIMARY_STAT.get(primary_stat_id, &"seasoned_farmer"))
	]
	var available: Array[StringName] = []
	for stat_id: StringName in LIFE_STAT_IDS:
		var trait_id := StringName(TRAIT_BY_PRIMARY_STAT.get(stat_id, &""))
		if trait_id != &"" and not result.has(trait_id):
			available.append(trait_id)
	while result.size() < count and not available.is_empty():
		var index := rng.randi_range(0, available.size() - 1)
		result.append(available[index])
		available.remove_at(index)
	return result


func _normalize_candidate_entry(game_state: Node, raw_entry: Dictionary) -> Dictionary:
	var raw_character = raw_entry.get("character", raw_entry.get("character_data", {}))
	if not raw_character is Dictionary:
		return {}
	var record := CharacterRecordScript.from_dictionary(raw_character)
	if not record.is_life_character() \
			or record.character_id == &"" \
			or record.created_sequence <= 0 \
			or record.combat_data != null \
			or record.life_data.life_stats == null:
		return {}
	record.life_data.life_stats.clamp_core_stats()
	record.level = clampi(record.level, 1, Stage12Config.LIFE_MAX_LEVEL)
	record.experience = max(0, record.experience)
	record.portrait_path = Stage12Config.resolve_life_portrait_path(record.portrait_path)
	record.experience_to_next_level = game_state.get_life_experience_to_next_level(
		record.level
	)
	if record.level >= Stage12Config.LIFE_MAX_LEVEL:
		record.experience = 0
	record.life_data.assigned_building_id = &""
	record.life_data.assigned_job_id = &""
	record.life_data.work_state = CharacterEnumsScript.WorkState.IDLE
	record.is_locked = false
	var metadata := record.metadata.duplicate(true)
	metadata["is_recruitment_candidate"] = true
	if not metadata.has("specialty_stat_id"):
		metadata["specialty_stat_id"] = _find_primary_stat(record.life_data.life_stats)
	record.metadata = metadata
	var valid_trait_ids: Array[StringName] = []
	for trait_id: StringName in record.life_data.life_trait_ids:
		if game_state.life_trait_database.get_definition(trait_id) != null \
				and not valid_trait_ids.has(trait_id):
			valid_trait_ids.append(trait_id)
	if valid_trait_ids.is_empty():
		var primary_stat_id := StringName(metadata.get("specialty_stat_id", &"farming"))
		valid_trait_ids.append(
			StringName(TRAIT_BY_PRIMARY_STAT.get(primary_stat_id, &"seasoned_farmer"))
		)
	if valid_trait_ids.size() > 2:
		valid_trait_ids.resize(2)
	record.life_data.life_trait_ids = valid_trait_ids
	record.traits = valid_trait_ids.duplicate()
	return {
		"character": record.to_dictionary(),
		"is_locked": bool(raw_entry.get("is_locked", false)),
		"recruitment_cost": int(RECRUIT_COST_BY_QUALITY.get(record.quality, 6)),
	}


func _public_candidate_snapshot(game_state: Node, entry: Dictionary) -> Dictionary:
	if entry.is_empty():
		return {}
	var character_data: Dictionary = entry.get("character", {}).duplicate(true)
	var life_data: Dictionary = character_data.get("life_data", {})
	var metadata: Dictionary = character_data.get("metadata", {})
	var specialty_stat_id := StringName(
		metadata.get(
			"specialty_stat_id",
			_find_primary_stat(LifeStatsScript.from_dictionary(life_data.get("life_stats", {})))
		)
	)
	var trait_details: Array = []
	for raw_trait_id in life_data.get("life_trait_ids", []):
		var definition: Dictionary = game_state.life_trait_database.get_definition_data(
			StringName(raw_trait_id)
		)
		if not definition.is_empty():
			trait_details.append(definition)
	return {
		"candidate_id": StringName(character_data.get("character_id", &"")),
		"character": character_data,
		"display_name": String(character_data.get("display_name", "")),
		"quality": int(character_data.get("quality", CharacterEnumsScript.Quality.COMMON)),
		"quality_display_name": get_quality_display_name(
			int(character_data.get("quality", CharacterEnumsScript.Quality.COMMON))
		),
		"level": int(character_data.get("level", 1)),
		"life_stats": life_data.get("life_stats", {}).duplicate(true),
		"life_trait_ids": life_data.get("life_trait_ids", []).duplicate(),
		"trait_details": trait_details,
		"specialty_stat_id": specialty_stat_id,
		"specialty_display_name": get_stat_display_name(specialty_stat_id),
		"recruitment_cost": int(entry.get("recruitment_cost", 0)),
		"is_locked": bool(entry.get("is_locked", false)),
	}


func _candidate_id_exists(game_state: Node, character_id: StringName) -> bool:
	for entry: Dictionary in game_state.life_recruitment_state.get("candidates", []):
		var character_data: Dictionary = entry.get("character", {})
		if StringName(character_data.get("character_id", &"")) == character_id:
			return true
	return false


func _find_primary_stat(stats: LifeStats) -> StringName:
	var selected := LIFE_STAT_IDS[0]
	var selected_value := -1
	for stat_id: StringName in LIFE_STAT_IDS:
		var value := stats.get_core_stat(stat_id)
		if value > selected_value:
			selected = stat_id
			selected_value = value
	return selected


func _create_rng(state: Dictionary) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(state.get("random_seed", INITIAL_RANDOM_SEED))
	var saved_state := int(state.get("random_state", 0))
	if saved_state != 0:
		rng.state = saved_state
	return rng

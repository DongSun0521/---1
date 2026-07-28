class_name Stage12BalanceConfig
extends RefCounted

const CharacterEnumsScript := preload("res://scripts/data/character_enums.gd")

const CONFIG_VERSION := 1

const MIN_PARTY_SIZE := 1
const MAX_PARTY_SIZE := 4
const COMBAT_MAX_LEVEL := 50
const LIFE_MAX_LEVEL := 50
const COMBAT_EXPERIENCE_BASE := 100
const COMBAT_EXPERIENCE_STEP := 50
const LIFE_EXPERIENCE_BASE := 100
const LIFE_EXPERIENCE_STEP := 50
const BATTLE_EXPERIENCE_REWARDS := {
	"normal_victory": 40,
	"boss_victory": 100,
	"defeat": 10,
}
const COMBAT_LEVEL_GROWTH_BY_CHARACTER := {
	&"guard": {"max_hp": 8, "attack": 1, "defense": 2, "speed": 0},
	&"hunter": {"max_hp": 4, "attack": 2, "defense": 1, "speed": 1},
	&"mage": {"max_hp": 4, "attack": 3, "defense": 0, "speed": 0},
	&"doctor": {"max_hp": 5, "attack": 1, "defense": 1, "speed": 1},
}

const LIFE_WORK_BASE_EXPERIENCE := 10
const LIFE_STAT_GROWTH_PER_LEVEL := 2
const LIFE_STAT_MIN := 0
const LIFE_STAT_MAX := 100
const LIFE_JOB_STAT_BONUS_PER_POINT := 0.5
const LIFE_STAT_TIE_BREAK_ORDER: Array[StringName] = [
	&"farming",
	&"crafting",
	&"gathering",
	&"research",
	&"medical",
]

const COMBAT_CRIT_RATE_MIN := 0.0
const COMBAT_CRIT_RATE_MAX := 1.0
const COMBAT_CRIT_DAMAGE_MIN := 0.0
const COMBAT_CRIT_DAMAGE_MAX := 5.0

const CANDIDATE_COUNT := 3
const RECRUITMENT_RESOURCE_ID := "food"
const RECRUITMENT_REFRESH_COST := 2
const BASE_LIFE_CAPACITY := 3
const CAPACITY_PER_RESIDENCE_LEVEL := 2
const RECRUITMENT_INITIAL_RANDOM_SEED := 1205001
const RARE_SECOND_TRAIT_CHANCE_PERCENT := 35
const QUALITY_PROBABILITIES := {
	CharacterEnumsScript.Quality.COMMON: 65,
	CharacterEnumsScript.Quality.RARE: 28,
	CharacterEnumsScript.Quality.EPIC: 7,
	CharacterEnumsScript.Quality.LEGENDARY: 0,
}
const QUALITY_ATTRIBUTE_RANGES := {
	CharacterEnumsScript.Quality.COMMON: {
		"primary_min": 35, "primary_max": 55,
		"other_min": 15, "other_max": 40,
	},
	CharacterEnumsScript.Quality.RARE: {
		"primary_min": 45, "primary_max": 65,
		"other_min": 20, "other_max": 45,
	},
	CharacterEnumsScript.Quality.EPIC: {
		"primary_min": 55, "primary_max": 75,
		"other_min": 25, "other_max": 50,
	},
	CharacterEnumsScript.Quality.LEGENDARY: {
		"primary_min": 65, "primary_max": 85,
		"other_min": 30, "other_max": 55,
	},
}
const RECRUIT_COST_BY_QUALITY := {
	CharacterEnumsScript.Quality.COMMON: 6,
	CharacterEnumsScript.Quality.RARE: 10,
	CharacterEnumsScript.Quality.EPIC: 16,
	CharacterEnumsScript.Quality.LEGENDARY: 24,
}
const RECRUITMENT_NAME_POOL: Array[String] = [
	"林禾", "苏巧", "石远", "沈青", "白芷",
	"陆鸣", "温砚", "叶秋", "陶然", "顾宁",
	"孟川", "夏竹", "江澄", "许安", "程野",
	"周岚", "韩星", "柳溪", "乔木", "唐果",
]

const DEFAULT_LIFE_PORTRAIT_PATH := "res://assets/art/characters/life_portraits/life_default.svg"
const LIFE_PORTRAIT_PATHS: Array[String] = [
	"res://assets/art/characters/life_portraits/life_amber.svg",
	"res://assets/art/characters/life_portraits/life_green.svg",
	"res://assets/art/characters/life_portraits/life_blue.svg",
	"res://assets/art/characters/life_portraits/life_purple.svg",
	"res://assets/art/characters/life_portraits/life_red.svg",
]
const DEFAULT_LIFE_PORTRAIT_BY_CHARACTER := {
	&"life_ahe": "res://assets/art/characters/life_portraits/life_green.svg",
	&"life_atie": "res://assets/art/characters/life_portraits/life_amber.svg",
	&"life_xiaoyao": "res://assets/art/characters/life_portraits/life_blue.svg",
}

const DEFAULT_JOB_SLOT_COUNT_BY_LEVEL := {
	1: 1,
	2: 2,
	3: 3,
	4: 4,
}
const JOB_SLOT_COUNT_OVERRIDE_BY_BUILDING := {
	&"residence": {
		1: 0,
		2: 0,
		3: 0,
		4: 0,
	},
}
const JOB_CONFIG_BY_BUILDING := {
	&"research_lab": [
		{"job_id": &"researcher", "job_type": &"research", "display_name": "研究岗位", "slot_index": 0},
	],
	&"residence": [],
	&"farm": [
		{"job_id": &"farmer", "job_type": &"farming", "display_name": "农业岗位", "slot_index": 0},
	],
	&"food_workshop": [
		{"job_id": &"food_crafter", "job_type": &"crafting", "display_name": "制造岗位", "slot_index": 0},
	],
	&"weapon_forge": [
		{"job_id": &"weapon_crafter", "job_type": &"crafting", "display_name": "制造岗位", "slot_index": 0},
	],
	&"hospital": [
		{"job_id": &"medic", "job_type": &"medical", "display_name": "医疗岗位", "slot_index": 0},
	],
	&"resource_collection": [
		{"job_id": &"gatherer", "job_type": &"gathering", "display_name": "采集岗位", "slot_index": 0},
	],
}

const LIFE_TRAIT_CONFIG := {
	&"seasoned_farmer": {
		"display_name": "农耕能手",
		"description": "农业岗位效率+10%，工作经验+20%，最终产量加成+5%。",
		"applicable_job_types": [&"farming"],
		"efficiency_bonus_percent": 10.0,
		"work_experience_bonus_percent": 20.0,
		"production_bonus_percent": 5.0,
	},
	&"steady_hands": {
		"display_name": "巧手工匠",
		"description": "制造岗位效率+10%，工作经验+10%。",
		"applicable_job_types": [&"crafting"],
		"efficiency_bonus_percent": 10.0,
		"work_experience_bonus_percent": 10.0,
		"production_bonus_percent": 0.0,
	},
	&"herbal_instinct": {
		"display_name": "仁心医者",
		"description": "医疗岗位效率+10%，工作经验+20%。",
		"applicable_job_types": [&"medical"],
		"efficiency_bonus_percent": 10.0,
		"work_experience_bonus_percent": 20.0,
		"production_bonus_percent": 0.0,
	},
	&"keen_collector": {
		"display_name": "寻珍好手",
		"description": "采集岗位效率+10%，工作经验+10%。",
		"applicable_job_types": [&"gathering"],
		"efficiency_bonus_percent": 10.0,
		"work_experience_bonus_percent": 10.0,
		"production_bonus_percent": 0.0,
	},
	&"curious_researcher": {
		"display_name": "求知学者",
		"description": "研究岗位效率+10%，工作经验+10%。",
		"applicable_job_types": [&"research"],
		"efficiency_bonus_percent": 10.0,
		"work_experience_bonus_percent": 10.0,
		"production_bonus_percent": 0.0,
	},
}

const MAX_GAMEPLAY_NOTIFICATIONS := 30
const MAX_RECENT_WORK_RESULTS_PER_BUILDING := 1


static func resolve_life_portrait_path(path: String) -> String:
	if not path.is_empty() and ResourceLoader.exists(path):
		return path
	return DEFAULT_LIFE_PORTRAIT_PATH

extends SceneTree

const PROTOTYPE_ROOT := "res://prototype/formation_defense/"
const PROTOTYPE_SCENE_PATH := (
	PROTOTYPE_ROOT + "scenes/formation_defense_prototype.tscn"
)
const PROTOTYPE_SCRIPT_PATH := (
	PROTOTYPE_ROOT + "scripts/formation_defense_prototype.gd"
)
const DEFAULT_SAVE_PATH := "user://adventure_village_save.json"
const FORMAL_MAIN_SCENE_PATH := "res://features/main/main.tscn"

const EXPECTED_NODE_PATHS: Array[String] = [
	"RootMargin/Content/Title",
	"RootMargin/Content/StageLabel",
	"RootMargin/Content/Battlefield",
	"RootMargin/Content/Battlefield/BattlefieldContent/SpawnPortTop",
	"RootMargin/Content/Battlefield/BattlefieldContent/SpawnPortMiddle",
	"RootMargin/Content/Battlefield/BattlefieldContent/SpawnPortBottom",
	"RootMargin/Content/Battlefield/BattlefieldContent/VillageEntrance",
	"RootMargin/Content/Notice",
]

const FORBIDDEN_RUNTIME_TOKENS: Array[String] = [
	"/root/GameState",
	"CharacterRoster",
	"SaveSystem",
	"res://autoload/",
	"res://features/",
	"res://systems/",
	"res://scripts/",
	"user://",
]

var failures: Array[String] = []


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var game_state := root.get_node_or_null("/root/GameState")
	require(game_state != null, "formal GameState autoload is unavailable")
	if game_state == null:
		quit(1)
		return

	var game_state_before := snapshot_script_variables(game_state)
	var save_file_before := snapshot_file(DEFAULT_SAVE_PATH)

	assert_project_settings_are_unchanged()
	assert_runtime_files_are_isolated()

	var packed_scene := load(PROTOTYPE_SCENE_PATH) as PackedScene
	require(packed_scene != null, "prototype entry scene could not be loaded")
	if packed_scene == null:
		quit(1)
		return

	var prototype := packed_scene.instantiate()
	require(prototype != null, "prototype entry scene could not be instantiated")
	if prototype == null:
		quit(1)
		return

	root.add_child(prototype)
	await process_frame
	await process_frame

	assert_placeholder_nodes(prototype)
	require(
		snapshot_script_variables(game_state) == game_state_before,
		"prototype startup changed GameState"
	)
	require(
		snapshot_file(DEFAULT_SAVE_PATH) == save_file_before,
		"prototype startup changed the formal save file"
	)

	prototype.queue_free()
	await process_frame

	require(
		snapshot_script_variables(game_state) == game_state_before,
		"prototype cleanup changed GameState"
	)
	require(
		snapshot_file(DEFAULT_SAVE_PATH) == save_file_before,
		"prototype cleanup changed the formal save file"
	)

	if failures.is_empty():
		print("v2-0 formation defense prototype smoke ok")
		quit(0)
		return
	quit(1)


func assert_project_settings_are_unchanged() -> void:
	require(
		String(ProjectSettings.get_setting("application/run/main_scene", ""))
			== FORMAL_MAIN_SCENE_PATH,
		"formal default main scene changed"
	)
	require(
		String(ProjectSettings.get_setting("autoload/GameState", ""))
			== "*res://autoload/game_state.gd",
		"formal GameState autoload changed"
	)
	for property: Dictionary in ProjectSettings.get_property_list():
		var property_name := String(property.get("name", ""))
		if not property_name.begins_with("autoload/"):
			continue
		var autoload_path := String(ProjectSettings.get_setting(property_name, ""))
		require(
			not autoload_path.contains(PROTOTYPE_ROOT),
			"prototype registered a global autoload"
		)


func assert_runtime_files_are_isolated() -> void:
	for runtime_path: String in [PROTOTYPE_SCENE_PATH, PROTOTYPE_SCRIPT_PATH]:
		require(FileAccess.file_exists(runtime_path), "%s is missing" % runtime_path)
		var source := FileAccess.get_file_as_string(runtime_path)
		for token: String in FORBIDDEN_RUNTIME_TOKENS:
			require(
				not source.contains(token),
				"%s references forbidden formal runtime token %s"
					% [runtime_path, token]
			)

	var dependencies := ResourceLoader.get_dependencies(PROTOTYPE_SCENE_PATH)
	for dependency: String in dependencies:
		var dependency_path := dependency.get_slice("::", dependency.get_slice_count("::") - 1)
		require(
			dependency_path.begins_with(PROTOTYPE_ROOT),
			"prototype scene has an external dependency: %s" % dependency_path
		)


func assert_placeholder_nodes(prototype: Node) -> void:
	for node_path: String in EXPECTED_NODE_PATHS:
		require(
			prototype.get_node_or_null(node_path) != null,
			"prototype placeholder node is missing: %s" % node_path
		)

	var title := prototype.get_node_or_null("RootMargin/Content/Title") as Label
	var stage_label := prototype.get_node_or_null(
		"RootMargin/Content/StageLabel"
	) as Label
	var notice := prototype.get_node_or_null(
		"RootMargin/Content/Notice/Label"
	) as Label
	require(
		title != null and title.text == "Combat V2 阵型塔防原型",
		"prototype title is incorrect"
	)
	require(
		stage_label != null and stage_label.text == "V2-0 原型环境",
		"prototype stage label is incorrect"
	)
	require(
		notice != null and notice.text == "本场景暂未实现战斗逻辑",
		"prototype notice is incorrect"
	)


func snapshot_script_variables(target: Object) -> Dictionary:
	var snapshot: Dictionary = {}
	for property: Dictionary in target.get_property_list():
		var usage := int(property.get("usage", 0))
		if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var property_name := StringName(property.get("name", &""))
		snapshot[property_name] = normalize_for_snapshot(target.get(property_name))
	return snapshot


func normalize_for_snapshot(value: Variant) -> Variant:
	match typeof(value):
		TYPE_ARRAY:
			var normalized_array: Array = []
			for item: Variant in value:
				normalized_array.append(normalize_for_snapshot(item))
			return normalized_array
		TYPE_DICTIONARY:
			var normalized_dictionary: Dictionary = {}
			for key: Variant in value.keys():
				normalized_dictionary[key] = normalize_for_snapshot(value[key])
			return normalized_dictionary
		TYPE_OBJECT:
			if value == null:
				return null
			if value.has_method("to_dictionary"):
				return normalize_for_snapshot(value.to_dictionary())
			return {
				"class": value.get_class(),
				"instance_id": value.get_instance_id(),
			}
		_:
			return value


func snapshot_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"exists": false}
	var content := FileAccess.get_file_as_bytes(path)
	return {
		"exists": true,
		"length": content.size(),
		"hash": hash(content),
		"modified_time": FileAccess.get_modified_time(path),
	}


func require(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)

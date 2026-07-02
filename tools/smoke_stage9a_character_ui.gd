extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var main_scene: PackedScene = load("res://features/main/main.tscn")
	var main_view := main_scene.instantiate()
	root.add_child(main_view)
	await process_frame
	await process_frame

	var village_view = main_view.find_child("VillageView", true, false)
	require(village_view != null, "VillageView not found")
	require(village_view.has_method("show_character_page"), "character page entry missing")
	village_view.show_character_page()
	await process_frame
	require(village_view.character_page.visible, "character page should be visible")
	require(not String(village_view.character_basic_label.text).is_empty(), "character basic info should render")
	require(String(village_view.character_equipment_label.text).contains("未装备"), "equipment placeholder should render")

	print("stage9a character ui smoke ok")
	quit()


func require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

extends Control

signal battle_finished(outcome: StringName)

const PrototypeConfig := preload(
	"res://prototype/formation_defense/data/formation_defense_config.gd"
)
const PrototypeEnemy := preload(
	"res://prototype/formation_defense/scripts/formation_defense_enemy.gd"
)

enum BattleState {
	READY,
	RUNNING,
	VICTORY,
	DEFEAT,
}

const STATE_NAMES := {
	BattleState.READY: "READY",
	BattleState.RUNNING: "RUNNING",
	BattleState.VICTORY: "VICTORY",
	BattleState.DEFEAT: "DEFEAT",
}

@onready var battlefield_content: Control = %BattlefieldContent
@onready var route_view: Control = %RouteView
@onready var enemy_layer: Node2D = %EnemyLayer
@onready var durability_label: Label = %DurabilityLabel
@onready var state_label: Label = %StateLabel
@onready var generated_label: Label = %GeneratedLabel
@onready var active_label: Label = %ActiveLabel
@onready var resolved_label: Label = %ResolvedLabel
@onready var scenario_label: Label = %ScenarioLabel
@onready var scenario_option: OptionButton = %ScenarioOption
@onready var start_button: Button = %StartButton
@onready var restart_button: Button = %RestartButton
@onready var result_label: Label = %ResultLabel

var battle_state: BattleState = BattleState.READY
var selected_scenario_id: StringName = &"survival"
var village_durability := PrototypeConfig.VILLAGE_MAX_DURABILITY
var spawn_plan: Array[StringName] = []
var spawn_index := 0
var spawn_elapsed := 0.0
var generated_enemy_count := 0
var resolved_enemy_count := 0
var active_enemies: Dictionary = {}
var settled_enemy_ids: Dictionary = {}
var generated_by_route: Dictionary = {}
var run_sequence := 0
var next_enemy_sequence := 1
var automatic_simulation := true
var battle_finish_count := 0


func _ready() -> void:
	setup_scenario_options()
	start_button.pressed.connect(start_battle)
	restart_button.pressed.connect(restart_battle)
	scenario_option.item_selected.connect(on_scenario_selected)
	battlefield_content.resized.connect(on_battlefield_resized)
	restart_battle()


func _process(delta: float) -> void:
	if automatic_simulation:
		simulate_step(delta)


func setup_scenario_options() -> void:
	scenario_option.clear()
	for scenario_id: StringName in PrototypeConfig.get_scenario_ids():
		var scenario := PrototypeConfig.get_scenario(scenario_id)
		scenario_option.add_item(String(scenario.get("display_name", scenario_id)))
		var item_index := scenario_option.item_count - 1
		scenario_option.set_item_metadata(item_index, scenario_id)
	var default_index := find_scenario_option(selected_scenario_id)
	scenario_option.select(maxi(0, default_index))


func on_scenario_selected(option_index: int) -> void:
	if battle_state != BattleState.READY:
		return
	var scenario_id := StringName(scenario_option.get_item_metadata(option_index))
	select_scenario(scenario_id)


func select_scenario(scenario_id: StringName) -> bool:
	if battle_state != BattleState.READY:
		return false
	if not PrototypeConfig.SCENARIOS.has(scenario_id):
		return false
	selected_scenario_id = scenario_id
	var option_index := find_scenario_option(scenario_id)
	if option_index >= 0 and scenario_option.selected != option_index:
		scenario_option.select(option_index)
	spawn_plan = get_selected_route_sequence()
	update_ui()
	return true


func find_scenario_option(scenario_id: StringName) -> int:
	for option_index in range(scenario_option.item_count):
		if StringName(scenario_option.get_item_metadata(option_index)) == scenario_id:
			return option_index
	return -1


func start_battle() -> bool:
	if battle_state != BattleState.READY:
		return false
	clear_active_enemies()
	village_durability = PrototypeConfig.VILLAGE_MAX_DURABILITY
	spawn_plan = get_selected_route_sequence()
	spawn_index = 0
	spawn_elapsed = 0.0
	generated_enemy_count = 0
	resolved_enemy_count = 0
	settled_enemy_ids.clear()
	generated_by_route = create_empty_route_counts()
	next_enemy_sequence = 1
	battle_state = BattleState.RUNNING
	spawn_next_enemy()
	update_ui()
	return true


func restart_battle() -> void:
	run_sequence += 1
	clear_active_enemies()
	battle_state = BattleState.READY
	village_durability = PrototypeConfig.VILLAGE_MAX_DURABILITY
	spawn_plan = get_selected_route_sequence()
	spawn_index = 0
	spawn_elapsed = 0.0
	generated_enemy_count = 0
	resolved_enemy_count = 0
	settled_enemy_ids.clear()
	generated_by_route = create_empty_route_counts()
	next_enemy_sequence = 1
	update_ui()


func set_automatic_simulation(enabled: bool) -> void:
	automatic_simulation = enabled
	set_process(enabled)


func simulate_step(delta: float) -> void:
	if battle_state != BattleState.RUNNING:
		return
	var safe_delta := maxf(0.0, delta)
	process_spawning(safe_delta)
	var enemies_this_step: Array = active_enemies.values()
	for enemy in enemies_this_step:
		if battle_state != BattleState.RUNNING:
			break
		if not is_instance_valid(enemy):
			continue
		if not active_enemies.has(enemy.runtime_id):
			continue
		enemy.advance(safe_delta)
	evaluate_victory()
	update_ui()


func process_spawning(delta: float) -> void:
	if spawn_index >= spawn_plan.size():
		return
	spawn_elapsed += delta
	while (
		battle_state == BattleState.RUNNING
		and spawn_index < spawn_plan.size()
		and spawn_elapsed >= PrototypeConfig.SPAWN_INTERVAL_SECONDS
	):
		spawn_elapsed -= PrototypeConfig.SPAWN_INTERVAL_SECONDS
		spawn_next_enemy()


func spawn_next_enemy() -> void:
	if battle_state != BattleState.RUNNING or spawn_index >= spawn_plan.size():
		return
	var route_id := spawn_plan[spawn_index]
	var route_points := get_route_points(route_id)
	if route_points.size() < 2:
		push_error("Prototype route %s has fewer than two points" % String(route_id))
		return
	var enemy := PrototypeEnemy.new()
	var enemy_id := StringName(
		"run_%d_enemy_%d" % [run_sequence, next_enemy_sequence]
	)
	next_enemy_sequence += 1
	enemy.name = String(enemy_id)
	enemy.configure(
		enemy_id,
		route_id,
		PrototypeConfig.ENEMY_MOVE_SPEED,
		PrototypeConfig.ENEMY_LEAK_DAMAGE,
		route_points,
		PrototypeConfig.get_route_color(route_id)
	)
	enemy.reached_entrance.connect(handle_enemy_arrival)
	enemy_layer.add_child(enemy)
	active_enemies[enemy_id] = enemy
	spawn_index += 1
	generated_enemy_count += 1
	generated_by_route[route_id] = int(generated_by_route.get(route_id, 0)) + 1


func handle_enemy_arrival(
	enemy_id: StringName,
	_route_id: StringName,
	leak_damage: int
) -> void:
	if settled_enemy_ids.has(enemy_id):
		return
	if battle_state != BattleState.RUNNING:
		remove_enemy(enemy_id)
		return
	if not active_enemies.has(enemy_id):
		return
	settled_enemy_ids[enemy_id] = true
	resolved_enemy_count += 1
	village_durability = maxi(0, village_durability - maxi(0, leak_damage))
	remove_enemy(enemy_id)
	if village_durability <= 0:
		finish_defeat()
		return
	evaluate_victory()
	update_ui()


func remove_enemy(enemy_id: StringName) -> void:
	var enemy = active_enemies.get(enemy_id)
	active_enemies.erase(enemy_id)
	if is_instance_valid(enemy):
		enemy.cancel()
		enemy.queue_free()


func clear_active_enemies() -> void:
	for enemy in active_enemies.values():
		if not is_instance_valid(enemy):
			continue
		enemy.cancel()
		enemy.queue_free()
	active_enemies.clear()


func evaluate_victory() -> void:
	if battle_state != BattleState.RUNNING:
		return
	var all_enemies_generated := spawn_index >= spawn_plan.size()
	if (
		all_enemies_generated
		and active_enemies.is_empty()
		and village_durability > 0
	):
		finish_victory()


func finish_victory() -> void:
	if battle_state != BattleState.RUNNING or village_durability <= 0:
		return
	battle_state = BattleState.VICTORY
	battle_finish_count += 1
	update_ui()
	battle_finished.emit(&"victory")


func finish_defeat() -> void:
	if battle_state != BattleState.RUNNING:
		return
	battle_state = BattleState.DEFEAT
	village_durability = 0
	battle_finish_count += 1
	clear_active_enemies()
	update_ui()
	battle_finished.emit(&"defeat")


func on_battlefield_resized() -> void:
	route_view.queue_redraw()
	for enemy in active_enemies.values():
		if is_instance_valid(enemy):
			enemy.set_route_points(get_route_points(enemy.route_id), true)


func get_route_ids() -> Array[StringName]:
	return PrototypeConfig.get_route_ids()


func get_route_points(route_id: StringName) -> PackedVector2Array:
	return PrototypeConfig.get_route_points(route_id, battlefield_content.size)


func get_village_entrance_point() -> Vector2:
	return PrototypeConfig.get_village_entrance_point(battlefield_content.size)


func get_active_enemy_nodes() -> Array:
	return active_enemies.values()


func get_selected_route_sequence() -> Array[StringName]:
	var scenario := PrototypeConfig.get_scenario(selected_scenario_id)
	var sequence: Array[StringName] = []
	for route_id: StringName in scenario.get("route_sequence", []):
		sequence.append(route_id)
	return sequence


func create_empty_route_counts() -> Dictionary:
	var counts: Dictionary = {}
	for route_id: StringName in PrototypeConfig.get_route_ids():
		counts[route_id] = 0
	return counts


func get_state_name() -> String:
	return String(STATE_NAMES.get(battle_state, "UNKNOWN"))


func get_battle_snapshot() -> Dictionary:
	return {
		"state": get_state_name(),
		"scenario_id": selected_scenario_id,
		"village_durability": village_durability,
		"max_durability": PrototypeConfig.VILLAGE_MAX_DURABILITY,
		"planned_enemy_count": spawn_plan.size(),
		"generated_enemy_count": generated_enemy_count,
		"active_enemy_count": active_enemies.size(),
		"resolved_enemy_count": resolved_enemy_count,
		"spawn_index": spawn_index,
		"spawn_elapsed": spawn_elapsed,
		"generated_by_route": generated_by_route.duplicate(true),
		"battle_finish_count": battle_finish_count,
		"run_sequence": run_sequence,
	}


func update_ui() -> void:
	if not is_node_ready():
		return
	var scenario := PrototypeConfig.get_scenario(selected_scenario_id)
	var scenario_name := String(scenario.get("display_name", selected_scenario_id))
	var planned_count := spawn_plan.size()
	durability_label.text = "村庄耐久：%d/%d" % [
		village_durability,
		PrototypeConfig.VILLAGE_MAX_DURABILITY,
	]
	state_label.text = "当前状态：%s" % get_state_name()
	generated_label.text = "已生成：%d/%d" % [generated_enemy_count, planned_count]
	active_label.text = "场上敌人：%d" % active_enemies.size()
	resolved_label.text = "已解决：%d" % resolved_enemy_count
	scenario_label.text = "当前方案：%s" % scenario_name
	start_button.disabled = battle_state != BattleState.READY
	scenario_option.disabled = battle_state != BattleState.READY
	match battle_state:
		BattleState.READY:
			result_label.text = "准备就绪：选择测试方案后开始"
			result_label.add_theme_color_override(
				"font_color", Color(0.72, 0.80, 0.90)
			)
		BattleState.RUNNING:
			result_label.text = "敌人正在从三路向同一个村庄入口推进"
			result_label.add_theme_color_override(
				"font_color", Color(0.66, 0.82, 1.0)
			)
		BattleState.VICTORY:
			result_label.text = "胜利：敌人已全部解决，村庄仍有耐久"
			result_label.add_theme_color_override(
				"font_color", Color(0.45, 1.0, 0.66)
			)
		BattleState.DEFEAT:
			result_label.text = "失败：村庄入口耐久归零"
			result_label.add_theme_color_override(
				"font_color", Color(1.0, 0.45, 0.48)
			)

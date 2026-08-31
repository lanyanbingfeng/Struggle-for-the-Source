extends Node

const TREE_SCENE: PackedScene = preload("res://game/world/tree.tscn")
const STONE_SCENE: PackedScene = preload("res://game/world/stone.tscn")
const IRON_SCENE: PackedScene = preload("res://game/world/iron_deposit.tscn")
const LUMBER_MACHINE_SCENE: PackedScene = preload("res://game/units/lumber_machine.tscn")
const QUARRY_MACHINE_SCENE: PackedScene = preload("res://game/units/quarry_machine.tscn")
const MAIN_SCENE: PackedScene = preload("res://game/main/main.tscn")
const TILE_SIZE: int = 32

var _failures: PackedStringArray = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred(&"_run")

func _run() -> void:
	_test_percentage_harvest_progress()
	_test_streamed_tree_footprint_occupancy()
	_test_astar_shortest_routes()
	_test_worker_nearest_resource_selection()
	_test_moving_unit_collision_layers()
	await _test_map_worker_navigation_integration()
	await get_tree().process_frame
	_finish()

func _test_streamed_tree_footprint_occupancy() -> void:
	var streamer: WorldResourceStreamer = WorldResourceStreamer.new()
	var tree_container: Node2D = Node2D.new()
	var stone_container: Node2D = Node2D.new()
	var mineral_container: Node2D = Node2D.new()
	streamer.configure(64, TILE_SIZE, tree_container, stone_container, mineral_container)
	var tree_cell: Vector2i = Vector2i(8, 8)
	var tree_upper_cell: Vector2i = tree_cell + Vector2i.UP
	_expect(bool(streamer.call(&"_try_store_resource", &"tree", tree_cell)), "流送器没有接受空地上的两格树木")
	_expect(not bool(streamer.call(&"_try_store_resource", &"stone", tree_upper_cell)), "树木上格仍允许生成石头")
	_expect(not bool(streamer.call(&"_try_store_resource", &"iron", tree_cell)), "树木根部格仍允许生成矿物")
	var occupied_cells: Dictionary = streamer.get("_occupied_cells") as Dictionary
	_expect(occupied_cells.has(tree_cell) and occupied_cells.has(tree_upper_cell), "两格树木没有完整登记根部格和上格")
	var claimed_tree: Dictionary = streamer.claim_resource_by_id(1, &"tree")
	_expect(not claimed_tree.is_empty(), "测试树木无法从流送器移除")
	occupied_cells = streamer.get("_occupied_cells") as Dictionary
	_expect(not occupied_cells.has(tree_cell) and not occupied_cells.has(tree_upper_cell), "树木移除后没有释放完整两格占用")
	_expect(bool(streamer.call(&"_try_store_resource", &"stone", tree_upper_cell)), "树木移除后上格仍被幽灵占用")
	_expect(not bool(streamer.call(&"_try_store_resource", &"tree", tree_cell)), "已有资源的下方仍允许生成会与其重叠的树木")
	streamer.free()
	tree_container.free()
	stone_container.free()
	mineral_container.free()

func _test_percentage_harvest_progress() -> void:
	var tree: HarvestTree = TREE_SCENE.instantiate() as HarvestTree
	get_tree().root.add_child(tree)
	_expect(is_equal_approx(tree.harvest_progress_percent, 100.0), "树木初始采集进度不是100%")
	tree.consume_harvest_progress(34.0)
	_expect(is_equal_approx(tree.harvest_progress_percent, 66.0), "树木没有按百分比扣减采集进度")
	tree.consume_harvest_progress(66.0)
	_expect(is_zero_approx(tree.harvest_progress_percent), "树木采集进度归零失败")
	_expect(not tree.can_be_targeted(), "采集进度归零的树木仍可被选为目标")

	var stone: Node2D = STONE_SCENE.instantiate() as Node2D
	get_tree().root.add_child(stone)
	stone.call(&"consume_harvest_progress", 25.0)
	_expect(is_equal_approx(float(stone.get("harvest_progress_percent")), 75.0), "石头没有独立保存百分比采集进度")

	var iron: MineralResource = IRON_SCENE.instantiate() as MineralResource
	get_tree().root.add_child(iron)
	iron.consume_harvest_progress(20.0)
	_expect(is_equal_approx(iron.harvest_progress_percent, 80.0), "矿物没有独立保存百分比采集进度")

func _test_astar_shortest_routes() -> void:
	var pathfinder: WorldPathfinder = WorldPathfinder.new()
	get_tree().root.add_child(pathfinder)
	pathfinder.configure(Vector2i(40, 30), TILE_SIZE)
	var wall_cells: Array[Vector2i] = []
	for y: int in range(4, 23):
		if y not in [7, 8]:
			wall_cells.append(Vector2i(16, y))
	pathfinder.set_external_obstacles(wall_cells)
	var start: Vector2 = _cell_center(Vector2i(6, 16))
	var target: Vector2 = _cell_center(Vector2i(28, 16))
	var path: PackedVector2Array = pathfinder.find_path(start, target)
	_expect(not path.is_empty(), "A*没有找到穿过墙体缺口的路线")
	_expect(_path_avoids_obstacles(pathfinder, start, path), "A*平滑后的路线穿过了障碍")
	_expect(_path_length(start, path) < 1000.0, "A*路线出现不必要的大范围绕行")

	var corner_pathfinder: WorldPathfinder = WorldPathfinder.new()
	get_tree().root.add_child(corner_pathfinder)
	corner_pathfinder.configure(Vector2i(24, 24), TILE_SIZE)
	corner_pathfinder.set_external_obstacles([Vector2i(10, 9), Vector2i(9, 10)])
	var corner_start: Vector2 = _cell_center(Vector2i(9, 9))
	var corner_target: Vector2 = _cell_center(Vector2i(10, 10))
	var corner_path: PackedVector2Array = corner_pathfinder.find_path(corner_start, corner_target)
	_expect(corner_path.size() > 1, "A*仍在两个障碍之间斜穿墙角")

	var u_pathfinder: WorldPathfinder = WorldPathfinder.new()
	get_tree().root.add_child(u_pathfinder)
	u_pathfinder.configure(Vector2i(40, 32), TILE_SIZE)
	var u_cells: Array[Vector2i] = []
	for y: int in range(8, 21):
		u_cells.append(Vector2i(12, y))
		u_cells.append(Vector2i(20, y))
	for x: int in range(13, 20):
		u_cells.append(Vector2i(x, 20))
	u_pathfinder.set_external_obstacles(u_cells)
	var u_start: Vector2 = _cell_center(Vector2i(16, 16))
	var u_target: Vector2 = _cell_center(Vector2i(16, 24))
	var u_path: PackedVector2Array = u_pathfinder.find_path(u_start, u_target)
	_expect(not u_path.is_empty(), "A*在需要扩大搜索范围的U形障碍内卡住")
	_expect(_path_avoids_obstacles(u_pathfinder, u_start, u_path), "A*离开U形障碍时穿墙")

func _test_worker_nearest_resource_selection() -> void:
	var pathfinder: WorldPathfinder = WorldPathfinder.new()
	get_tree().root.add_child(pathfinder)
	pathfinder.configure(Vector2i(64, 64), TILE_SIZE)

	var trees: Node2D = Node2D.new()
	get_tree().root.add_child(trees)
	var left_tree: HarvestTree = _add_tree(trees, Vector2i(12, 12), 1)
	var right_tree: HarvestTree = _add_tree(trees, Vector2i(24, 12), 1)
	_add_tree(trees, Vector2i(10, 12), 2)
	pathfinder.rebuild_obstacles([trees])

	var left_machine: LumberMachine = LUMBER_MACHINE_SCENE.instantiate() as LumberMachine
	get_tree().root.add_child(left_machine)
	left_machine.global_position = _cell_center(Vector2i(8, 12))
	left_machine.setup(trees, 1, true, pathfinder.find_path)
	left_machine.set_physics_process(false)
	left_machine.call(&"_physics_process", 0.0)
	_expect(left_machine.get("_target_tree") == left_tree, "左侧伐木单位没有选择自己最近的领地内树木")
	left_machine.global_position = left_machine.get("_target_work_position") as Vector2
	left_machine.call(&"_physics_process", 1.01)
	_expect(left_tree.harvest_progress_percent < 100.0, "伐木单位工作时没有消耗树木的百分比采集进度")

	var right_machine: LumberMachine = LUMBER_MACHINE_SCENE.instantiate() as LumberMachine
	get_tree().root.add_child(right_machine)
	right_machine.global_position = _cell_center(Vector2i(28, 12))
	right_machine.setup(trees, 1, true, pathfinder.find_path)
	right_machine.set_physics_process(false)
	right_machine.call(&"_physics_process", 0.0)
	_expect(right_machine.get("_target_tree") == right_tree, "右侧伐木单位没有独立选择自己最近的树木")

	var mineables: Node2D = Node2D.new()
	get_tree().root.add_child(mineables)
	var near_stone: Node2D = _add_stone(mineables, Vector2i(12, 28), 1)
	_add_stone(mineables, Vector2i(22, 28), 1)
	_add_stone(mineables, Vector2i(10, 28), 2)
	pathfinder.rebuild_obstacles([trees, mineables])
	var quarry: QuarryMachine = QUARRY_MACHINE_SCENE.instantiate() as QuarryMachine
	get_tree().root.add_child(quarry)
	quarry.global_position = _cell_center(Vector2i(8, 28))
	quarry.setup(mineables, 1, true, pathfinder.find_path)
	quarry.set_physics_process(false)
	quarry.call(&"_physics_process", 0.0)
	_expect(quarry.get("_target_stone") == near_stone, "采矿单位没有选择自己最近的领地内矿物")
	quarry.global_position = quarry.get("_target_work_position") as Vector2
	quarry.call(&"_physics_process", 0.86)
	_expect(float(near_stone.get("harvest_progress_percent")) < 100.0, "采矿单位工作时没有消耗矿物的百分比采集进度")

func _test_moving_unit_collision_layers() -> void:
	var scene_paths: PackedStringArray = [
		"res://game/units/treant_unit.tscn",
		"res://game/units/swordsman_unit.tscn",
		"res://game/units/explorer_unit.tscn",
		"res://game/units/builder_unit.tscn",
	]
	for scene_path: String in scene_paths:
		var scene: PackedScene = load(scene_path) as PackedScene
		var unit: CharacterBody2D = scene.instantiate() as CharacterBody2D
		_expect(unit.collision_layer == 1 and unit.collision_mask == 2, "%s没有使用单位/静态障碍分离碰撞层" % scene_path)
		unit.free()

func _test_map_worker_navigation_integration() -> void:
	var map: Node2D = MAIN_SCENE.instantiate() as Node2D
	get_tree().root.add_child(map)
	for abundance: int in range(3):
		map.set("_resource_abundance", abundance)
		var fair_tree_cells: Array[Vector2i] = map.call(&"_get_tree_cells_for_abundance") as Array[Vector2i]
		var fair_stone_cells: Array[Vector2i] = map.call(&"_get_stone_cells_for_abundance") as Array[Vector2i]
		var fair_mineral_layout: Array[Dictionary] = map.call(&"_build_rare_mineral_layout", fair_tree_cells, fair_stone_cells) as Array[Dictionary]
		var fair_other_resource_cells: Dictionary[Vector2i, bool] = {}
		for stone_cell: Vector2i in fair_stone_cells:
			fair_other_resource_cells[stone_cell] = true
		for mineral_data: Dictionary in fair_mineral_layout:
			fair_other_resource_cells[mineral_data.get("cell", Vector2i.ZERO) as Vector2i] = true
		for tree_cell: Vector2i in fair_tree_cells:
			_expect(not fair_other_resource_cells.has(tree_cell), "资源档%d的初始领地仍可能在树木根部格生成其他资源" % abundance)
			_expect(not fair_other_resource_cells.has(tree_cell + Vector2i.UP), "资源档%d的初始领地仍可能在树木上格生成其他资源" % abundance)
	map.call(&"_on_start_requested", false)
	await get_tree().process_frame
	var ai_controller: SimpleAIController = map.get("ai_controller") as SimpleAIController
	ai_controller.configure(false)
	var units: Dictionary = map.get("_network_units") as Dictionary
	var checked_workers: int = 0
	for unit_value: Variant in units.values():
		var unit: Node2D = unit_value as Node2D
		var definition: UnitDefinition = unit.get("definition") as UnitDefinition
		if definition == null or definition.unit_id not in [&"lumber", &"quarry"]:
			continue
		unit.call(&"_physics_process", 0.0)
		var target_property: StringName = &"_target_tree" if definition.unit_id == &"lumber" else &"_target_stone"
		var target: Node2D = unit.get(target_property) as Node2D
		_expect(is_instance_valid(target), "%s在主地图中没有取得可达资源目标" % definition.display_name)
		if is_instance_valid(target):
			_expect(int(target.get("territory_id")) == int(unit.get("territory_id")), "%s选择了领地外资源" % definition.display_name)
			_expect(not (unit.get("_navigation_path") as PackedVector2Array).is_empty(), "%s没有获得自动采集A*路径" % definition.display_name)
		checked_workers += 1
	_expect(checked_workers >= 2, "主地图没有生成可验证的AI采集单位")
	map.queue_free()
	await get_tree().process_frame

func _add_tree(parent: Node2D, cell: Vector2i, territory_id: int) -> HarvestTree:
	var tree: HarvestTree = TREE_SCENE.instantiate() as HarvestTree
	tree.territory_id = territory_id
	tree.position = _resource_position(cell)
	parent.add_child(tree)
	return tree

func _add_stone(parent: Node2D, cell: Vector2i, territory_id: int) -> Node2D:
	var stone: Node2D = STONE_SCENE.instantiate() as Node2D
	stone.set("territory_id", territory_id)
	stone.position = _resource_position(cell)
	parent.add_child(stone)
	return stone

func _path_avoids_obstacles(pathfinder: WorldPathfinder, start: Vector2, path: PackedVector2Array) -> bool:
	var previous: Vector2 = start
	for waypoint: Vector2 in path:
		var distance: float = previous.distance_to(waypoint)
		var sample_count: int = maxi(1, ceili(distance / 4.0))
		for sample_index: int in range(sample_count + 1):
			var sample: Vector2 = previous.lerp(waypoint, float(sample_index) / float(sample_count))
			if not pathfinder.is_world_position_walkable(sample):
				return false
		previous = waypoint
	return true

func _path_length(start: Vector2, path: PackedVector2Array) -> float:
	var result: float = 0.0
	var previous: Vector2 = start
	for waypoint: Vector2 in path:
		result += previous.distance_to(waypoint)
		previous = waypoint
	return result

func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE_SIZE) + Vector2.ONE * float(TILE_SIZE) * 0.5

func _resource_position(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_SIZE + TILE_SIZE * 0.5, (cell.y + 1) * TILE_SIZE)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("RESOURCE_NAVIGATION_REGRESSION_OK")
		await get_tree().create_timer(0.5).timeout
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("RESOURCE_NAVIGATION_REGRESSION: %s" % failure)
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(1)

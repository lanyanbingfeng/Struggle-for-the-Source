class_name LumberMachine
extends Node2D

const MachineProgressionData: Script = preload("res://game/data/machine_progression.gd")

enum State { SEARCHING, MOVING, CHOPPING, MANUAL_MOVING, WAITING }

const MOVE_SPEED: float = 96.0
const HARVEST_DISTANCE: float = 3.0
const CHOP_INTERVAL: float = 1.0
const TREE_WORK_OFFSET: Vector2 = Vector2(32.0, -16.0)
const SAW_ROTATION_SPEED: float = TAU * 2.8

@onready var visuals: Node2D = $Visuals
@onready var saw_pivot: Node2D = $Visuals/SawPivot

var unit_id: int = 0
var owner_peer_id: int = 0
var territory_id: int = 0
var definition: UnitDefinition
var simulation_enabled: bool = true
var machine_level: int = 1
var work_enabled: bool = true
var _tree_container: Node2D
var _path_provider: Callable
var _target_tree: Node2D
var _target_work_position: Vector2 = Vector2.ZERO
var _state: State = State.WAITING
var _chop_elapsed: float = 0.0
var _network_position: Vector2 = Vector2.ZERO
var _network_working: bool = false
var _navigation_path: PackedVector2Array = PackedVector2Array()
var _navigation_index: int = 0
var _selected: bool = false
var _control_remaining: float = 0.0

func setup(
	tree_container: Node2D,
	new_territory_id: int = 0,
	should_simulate: bool = true,
	path_provider: Callable = Callable()
) -> void:
	_tree_container = tree_container
	_path_provider = path_provider
	territory_id = new_territory_id
	simulation_enabled = should_simulate
	_network_position = global_position
	_target_tree = null
	_target_work_position = Vector2.ZERO
	_chop_elapsed = 0.0
	_control_remaining = 0.0
	_set_state(State.SEARCHING if simulation_enabled and work_enabled else State.WAITING)

func configure_network(new_unit_id: int, new_owner_peer_id: int, new_definition: UnitDefinition) -> void:
	unit_id = new_unit_id
	owner_peer_id = new_owner_peer_id
	definition = new_definition

func apply_network_state(network_position: Vector2, working: bool, enabled: bool = true, level: int = 1) -> void:
	_network_position = network_position
	_network_working = working
	work_enabled = enabled
	machine_level = clampi(level, 1, MachineProgressionData.MAX_LEVEL)

func set_work_enabled(enabled: bool) -> void:
	work_enabled = enabled
	_target_tree = null
	_target_work_position = Vector2.ZERO
	_chop_elapsed = 0.0
	_navigation_path.clear()
	_navigation_index = 0
	_set_state(State.SEARCHING if enabled else State.WAITING)

func set_machine_level(level: int) -> void:
	machine_level = clampi(level, 1, MachineProgressionData.MAX_LEVEL)

func set_navigation_path(path: PackedVector2Array) -> void:
	if work_enabled:
		return
	_navigation_path = path
	_navigation_index = 0
	_set_state(State.MANUAL_MOVING if not path.is_empty() else State.WAITING)

func set_selected(selected: bool) -> void:
	_selected = selected
	queue_redraw()

func is_working() -> bool:
	return _state == State.CHOPPING and _control_remaining <= 0.0

func get_vision_radius_world(tile_size: int) -> float:
	return (definition.vision_radius_tiles if definition != null else 4.0) * float(tile_size)

func _physics_process(delta: float) -> void:
	if not simulation_enabled:
		global_position = global_position.lerp(_network_position, 0.45)
		_update_saw(delta, _network_working)
		return
	_control_remaining = maxf(0.0, _control_remaining - delta)
	if _control_remaining > 0.0:
		_update_saw(delta, false)
		return
	_update_saw(delta, _state == State.CHOPPING)
	if not work_enabled:
		_process_manual_move(delta)
		return
	if not is_instance_valid(_tree_container):
		_set_state(State.WAITING)
		return
	if not _is_valid_tree(_target_tree):
		_select_nearest_tree()
		_chop_elapsed = 0.0
	if _target_tree == null:
		_set_state(State.WAITING)
		return
	_update_facing_to_target()
	if global_position.distance_to(_target_work_position) > HARVEST_DISTANCE:
		_set_state(State.MOVING)
		if not _follow_navigation_path(delta, MOVE_SPEED * MachineProgressionData.get_speed_multiplier(machine_level)):
			_clear_harvest_target()
		return
	_set_state(State.CHOPPING)
	_chop_elapsed += delta * MachineProgressionData.get_speed_multiplier(machine_level)
	if _chop_elapsed < CHOP_INTERVAL:
		return
	_chop_elapsed -= CHOP_INTERVAL
	_consume_target_progress(_target_tree)
	if not _is_valid_tree(_target_tree):
		_clear_harvest_target()

func _process_manual_move(delta: float) -> void:
	while _navigation_index < _navigation_path.size() and global_position.distance_to(_navigation_path[_navigation_index]) <= 3.0:
		_navigation_index += 1
	if _navigation_index >= _navigation_path.size():
		_set_state(State.WAITING)
		return
	_set_state(State.MANUAL_MOVING)
	global_position = global_position.move_toward(_navigation_path[_navigation_index], MOVE_SPEED * delta)

func apply_control(duration: float) -> void:
	_control_remaining = maxf(_control_remaining, duration)

func get_control_remaining() -> float:
	return _control_remaining

func _select_nearest_tree() -> void:
	_clear_harvest_target()
	var nearest_distance: float = INF
	for child: Node in _tree_container.get_children():
		var tree: Node2D = child as Node2D
		if not _is_valid_tree(tree) or int(tree.get("territory_id")) != territory_id:
			continue
		for work_position: Vector2 in _get_tree_work_positions(tree):
			var path: PackedVector2Array = _calculate_path(work_position)
			if path.is_empty() or path[path.size() - 1].distance_to(work_position) > HARVEST_DISTANCE:
				continue
			var distance: float = _path_length(global_position, path)
			if distance >= nearest_distance:
				continue
			nearest_distance = distance
			_target_tree = tree
			_target_work_position = work_position
			_navigation_path = path
			_navigation_index = 0

func _is_valid_tree(tree: Node2D) -> bool:
	return is_instance_valid(tree) and tree.has_method(&"can_be_targeted") and bool(tree.call(&"can_be_targeted"))

func _get_tree_work_positions(tree: Node2D) -> PackedVector2Array:
	if tree.has_method(&"get_harvest_positions"):
		var positions_result: Variant = tree.call(&"get_harvest_positions", global_position)
		if positions_result is PackedVector2Array:
			return positions_result as PackedVector2Array
	if tree.has_method(&"get_harvest_position"):
		var result: Variant = tree.call(&"get_harvest_position", global_position)
		if result is Vector2:
			return PackedVector2Array([result as Vector2])
	return PackedVector2Array([tree.global_position + TREE_WORK_OFFSET])

func _calculate_path(work_position: Vector2) -> PackedVector2Array:
	if not _path_provider.is_valid():
		return PackedVector2Array([work_position])
	var result: Variant = _path_provider.call(global_position, work_position)
	return result as PackedVector2Array if result is PackedVector2Array else PackedVector2Array()

func _path_length(start_position: Vector2, path: PackedVector2Array) -> float:
	var length: float = 0.0
	var previous: Vector2 = start_position
	for waypoint: Vector2 in path:
		length += previous.distance_to(waypoint)
		previous = waypoint
	return length

func _follow_navigation_path(delta: float, speed: float) -> bool:
	while _navigation_index < _navigation_path.size() and global_position.distance_to(_navigation_path[_navigation_index]) <= HARVEST_DISTANCE:
		_navigation_index += 1
	if _navigation_index >= _navigation_path.size():
		return global_position.distance_to(_target_work_position) <= HARVEST_DISTANCE
	global_position = global_position.move_toward(_navigation_path[_navigation_index], speed * delta)
	return true

func _consume_target_progress(tree: Node2D) -> void:
	if not tree.has_method(&"consume_harvest_progress"):
		tree.call(&"register_hit")
		return
	var cost_percent: float = 100.0
	if tree.has_method(&"get_harvest_cycle_cost_percent"):
		cost_percent = float(tree.call(&"get_harvest_cycle_cost_percent"))
	tree.call(&"consume_harvest_progress", cost_percent)

func _clear_harvest_target() -> void:
	_target_tree = null
	_target_work_position = Vector2.ZERO
	_navigation_path.clear()
	_navigation_index = 0

func _update_facing_to_target() -> void:
	if is_instance_valid(_target_tree) and absf(_target_tree.global_position.x - global_position.x) > 0.01:
		visuals.scale.x = 1.0 if _target_tree.global_position.x > global_position.x else -1.0

func _update_saw(delta: float, active: bool) -> void:
	if active:
		saw_pivot.rotation += SAW_ROTATION_SPEED * delta * MachineProgressionData.get_speed_multiplier(machine_level)
	else:
		saw_pivot.rotation = 0.0

func _set_state(next_state: State) -> void:
	_state = next_state
	if _state != State.CHOPPING:
		saw_pivot.rotation = 0.0

func _draw() -> void:
	if _selected:
		draw_arc(Vector2(0.0, 10.0), 14.0, 0.0, TAU, 32, Color("#7dff9ed0"), 2.0, true)

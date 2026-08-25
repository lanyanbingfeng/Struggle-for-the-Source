class_name QuarryMachine
extends Node2D

const MachineProgressionData: Script = preload("res://game/data/machine_progression.gd")

enum State { SEARCHING, MOVING, MINING, MANUAL_MOVING, WAITING }

const MOVE_SPEED: float = 88.0
const HARVEST_DISTANCE: float = 3.0
const MINE_INTERVAL: float = 0.85
const STONE_WORK_OFFSET: Vector2 = Vector2(28.0, -14.0)
const DRILL_ROTATION_SPEED: float = TAU * 2.2

@onready var visuals: Node2D = $Visuals
@onready var drill_pivot: Node2D = $Visuals/DrillPivot

var unit_id: int = 0
var owner_peer_id: int = 0
var territory_id: int = 0
var definition: UnitDefinition
var simulation_enabled: bool = true
var machine_level: int = 1
var work_enabled: bool = true
var _mineable_container: Node2D
var _target_stone: Node2D
var _state: State = State.WAITING
var _mine_elapsed: float = 0.0
var _network_position: Vector2 = Vector2.ZERO
var _network_working: bool = false
var _navigation_path: PackedVector2Array = PackedVector2Array()
var _navigation_index: int = 0
var _selected: bool = false

func setup(mineable_container: Node2D, new_territory_id: int = 0, should_simulate: bool = true) -> void:
	_mineable_container = mineable_container
	territory_id = new_territory_id
	simulation_enabled = should_simulate
	_network_position = global_position
	_target_stone = null
	_mine_elapsed = 0.0
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
	_target_stone = null
	_mine_elapsed = 0.0
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
	return _state == State.MINING

func get_vision_radius_world(tile_size: int) -> float:
	return (definition.vision_radius_tiles if definition != null else 4.0) * float(tile_size)

func _physics_process(delta: float) -> void:
	if not simulation_enabled:
		global_position = global_position.lerp(_network_position, 0.45)
		_update_drill(delta, _network_working)
		return
	_update_drill(delta, _state == State.MINING)
	if not work_enabled:
		_process_manual_move(delta)
		return
	if not is_instance_valid(_mineable_container):
		_set_state(State.WAITING)
		return
	if not _is_valid_mineable(_target_stone):
		_target_stone = _find_nearest_mineable()
		_mine_elapsed = 0.0
	if _target_stone == null:
		_set_state(State.WAITING)
		return
	_update_facing_to_target()
	var work_position: Vector2 = _get_work_position(_target_stone)
	if global_position.distance_to(work_position) > HARVEST_DISTANCE:
		_set_state(State.MOVING)
		global_position = global_position.move_toward(work_position, MOVE_SPEED * MachineProgressionData.get_speed_multiplier(machine_level) * delta)
		return
	_set_state(State.MINING)
	_mine_elapsed += delta * MachineProgressionData.get_speed_multiplier(machine_level)
	if _mine_elapsed < MINE_INTERVAL:
		return
	_mine_elapsed -= MINE_INTERVAL
	_target_stone.call(&"register_hit")
	if not _is_valid_mineable(_target_stone):
		_target_stone = null

func _process_manual_move(delta: float) -> void:
	while _navigation_index < _navigation_path.size() and global_position.distance_to(_navigation_path[_navigation_index]) <= 3.0:
		_navigation_index += 1
	if _navigation_index >= _navigation_path.size():
		_set_state(State.WAITING)
		return
	_set_state(State.MANUAL_MOVING)
	global_position = global_position.move_toward(_navigation_path[_navigation_index], MOVE_SPEED * delta)

func _find_nearest_mineable() -> Node2D:
	var nearest: Node2D
	var nearest_distance: float = INF
	for child: Node in _get_mineable_nodes(_mineable_container):
		var mineable: Node2D = child as Node2D
		if not _is_valid_mineable(mineable) or int(mineable.get("territory_id")) != territory_id:
			continue
		var distance: float = global_position.distance_squared_to(_get_work_position(mineable))
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = mineable
	return nearest

func _get_mineable_nodes(root: Node) -> Array[Node]:
	var nodes: Array[Node] = []
	for child: Node in root.get_children():
		if child.has_method(&"can_be_targeted"):
			nodes.append(child)
		else:
			nodes.append_array(_get_mineable_nodes(child))
	return nodes

func _is_valid_mineable(mineable: Node2D) -> bool:
	if not is_instance_valid(mineable) or not mineable.has_method(&"can_be_targeted"):
		return false
	var resource_type: StringName = StringName(str(mineable.get("resource_type")))
	return MachineProgressionData.quarry_can_harvest(machine_level, resource_type) and bool(mineable.call(&"can_be_targeted"))

func _get_work_position(mineable: Node2D) -> Vector2:
	if mineable.has_method(&"get_harvest_position"):
		var result: Variant = mineable.call(&"get_harvest_position", global_position)
		if result is Vector2:
			return result
	return mineable.global_position + STONE_WORK_OFFSET

func _update_facing_to_target() -> void:
	if is_instance_valid(_target_stone) and absf(_target_stone.global_position.x - global_position.x) > 0.01:
		visuals.scale.x = 1.0 if _target_stone.global_position.x > global_position.x else -1.0

func _update_drill(delta: float, active: bool) -> void:
	if active:
		drill_pivot.rotation += DRILL_ROTATION_SPEED * delta * MachineProgressionData.get_speed_multiplier(machine_level)
	else:
		drill_pivot.rotation = 0.0

func _set_state(next_state: State) -> void:
	_state = next_state
	if _state != State.MINING:
		drill_pivot.rotation = 0.0

func _draw() -> void:
	if _selected:
		draw_arc(Vector2(0.0, 10.0), 14.0, 0.0, TAU, 32, Color("#8bd7ffd0"), 2.0, true)

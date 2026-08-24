extends Node2D

enum State { SEARCHING, MOVING, MINING, WAITING }

const MOVE_SPEED: float = 88.0
const HARVEST_DISTANCE: float = 3.0
const MINE_INTERVAL: float = 0.85
const STONE_WORK_OFFSET: Vector2 = Vector2(28.0, -14.0)
const DRILL_ROTATION_SPEED: float = TAU * 2.2

@onready var visuals: Node2D = $Visuals
@onready var drill_pivot: Node2D = $Visuals/DrillPivot

var _stone_container: Node2D
var _target_stone: Node2D
var _territory_id: int = 0
var _state: State = State.WAITING
var _mine_elapsed: float = 0.0

func setup(stone_container: Node2D, territory_id: int = 0) -> void:
	_stone_container = stone_container
	_territory_id = territory_id
	_target_stone = null
	_mine_elapsed = 0.0
	_set_state(State.SEARCHING)

func _physics_process(delta: float) -> void:
	if _state == State.MINING:
		drill_pivot.rotation += DRILL_ROTATION_SPEED * delta
	if not is_instance_valid(_stone_container):
		_set_state(State.WAITING)
		return
	if not _is_valid_stone(_target_stone):
		_target_stone = _find_nearest_stone()
		_mine_elapsed = 0.0
	if _target_stone == null:
		_set_state(State.WAITING)
		return
	_update_facing_to_target()
	var work_position: Vector2 = _get_stone_work_position(_target_stone)
	if global_position.distance_to(work_position) > HARVEST_DISTANCE:
		_set_state(State.MOVING)
		global_position = global_position.move_toward(work_position, MOVE_SPEED * delta)
		return
	_set_state(State.MINING)
	_mine_elapsed += delta
	if _mine_elapsed < MINE_INTERVAL:
		return
	_mine_elapsed -= MINE_INTERVAL
	_target_stone.call(&"register_hit")
	if not _is_valid_stone(_target_stone):
		_target_stone = null

func _find_nearest_stone() -> Node2D:
	var nearest_stone: Node2D
	var nearest_distance: float = INF
	for child: Node in _stone_container.get_children():
		var stone: Node2D = child as Node2D
		if not _is_valid_stone(stone):
			continue
		if int(stone.get("territory_id")) != _territory_id:
			continue
		var distance: float = global_position.distance_squared_to(_get_stone_work_position(stone))
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_stone = stone
	return nearest_stone

func _is_valid_stone(stone: Node2D) -> bool:
	if not is_instance_valid(stone):
		return false
	if not stone.has_method(&"can_be_targeted"):
		return false
	return bool(stone.call(&"can_be_targeted"))

func _get_stone_work_position(stone: Node2D) -> Vector2:
	if stone.has_method(&"get_harvest_position"):
		var position_value: Variant = stone.call(&"get_harvest_position", global_position)
		if position_value is Vector2:
			return position_value
	return stone.global_position + STONE_WORK_OFFSET

func _update_facing_to_target() -> void:
	if not is_instance_valid(_target_stone):
		return
	var horizontal_delta: float = _target_stone.global_position.x - global_position.x
	if absf(horizontal_delta) > 0.01:
		visuals.scale.x = 1.0 if horizontal_delta > 0.0 else -1.0

func _set_state(next_state: State) -> void:
	if _state == next_state:
		return
	_state = next_state
	if _state != State.MINING:
		drill_pivot.rotation = 0.0

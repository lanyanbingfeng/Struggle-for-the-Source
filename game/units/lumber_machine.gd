extends Node2D

enum State { SEARCHING, MOVING, CHOPPING, WAITING }

const MOVE_SPEED: float = 96.0
const HARVEST_DISTANCE: float = 3.0
const CHOP_INTERVAL: float = 1.0
const TREE_WORK_OFFSET: Vector2 = Vector2(32.0, -16.0)
const SAW_ROTATION_SPEED: float = TAU * 2.8

@onready var visuals: Node2D = $Visuals
@onready var saw_pivot: Node2D = $Visuals/SawPivot

var _tree_container: Node2D
var _target_tree: Node2D
var _territory_id: int = 0
var _state: State = State.WAITING
var _chop_elapsed: float = 0.0

func setup(tree_container: Node2D, territory_id: int = 0) -> void:
	_tree_container = tree_container
	_territory_id = territory_id
	_target_tree = null
	_chop_elapsed = 0.0
	_set_state(State.SEARCHING)

func _physics_process(delta: float) -> void:
	if _state == State.CHOPPING:
		saw_pivot.rotation += SAW_ROTATION_SPEED * delta
	if not is_instance_valid(_tree_container):
		_set_state(State.WAITING)
		return

	if not _is_valid_tree(_target_tree):
		_target_tree = _find_nearest_tree()
		_chop_elapsed = 0.0

	if _target_tree == null:
		_set_state(State.WAITING)
		return

	_update_facing_to_target()
	var work_position: Vector2 = _get_tree_work_position(_target_tree)
	var distance: float = global_position.distance_to(work_position)
	if distance > HARVEST_DISTANCE:
		_set_state(State.MOVING)
		global_position = global_position.move_toward(work_position, MOVE_SPEED * delta)
		return

	_set_state(State.CHOPPING)
	_chop_elapsed += delta
	if _chop_elapsed < CHOP_INTERVAL:
		return

	_chop_elapsed -= CHOP_INTERVAL
	_target_tree.call(&"register_hit")
	if not _is_valid_tree(_target_tree):
		_target_tree = null

func _find_nearest_tree() -> Node2D:
	var nearest_tree: Node2D
	var nearest_distance: float = INF
	for child: Node in _tree_container.get_children():
		var tree: Node2D = child as Node2D
		if not _is_valid_tree(tree):
			continue
		if int(tree.get("territory_id")) != _territory_id:
			continue
		var distance: float = global_position.distance_squared_to(_get_tree_work_position(tree))
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_tree = tree
	return nearest_tree

func _is_valid_tree(tree: Node2D) -> bool:
	if not is_instance_valid(tree):
		return false
	if not tree.has_method(&"can_be_targeted"):
		return false
	return bool(tree.call(&"can_be_targeted"))

func _get_tree_work_position(tree: Node2D) -> Vector2:
	if tree.has_method(&"get_harvest_position"):
		var position_value: Variant = tree.call(&"get_harvest_position", global_position)
		if position_value is Vector2:
			return position_value
	return tree.global_position + TREE_WORK_OFFSET

func _update_facing_to_target() -> void:
	if not is_instance_valid(_target_tree):
		return
	var horizontal_delta: float = _target_tree.global_position.x - global_position.x
	if absf(horizontal_delta) > 0.01:
		visuals.scale.x = 1.0 if horizontal_delta > 0.0 else -1.0

func _set_state(next_state: State) -> void:
	if _state == next_state:
		return
	_state = next_state
	if _state != State.CHOPPING:
		saw_pivot.rotation = 0.0

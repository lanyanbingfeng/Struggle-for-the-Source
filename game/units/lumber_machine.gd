extends Node2D

enum State { SEARCHING, MOVING, CHOPPING, WAITING }

const MOVE_SPEED: float = 96.0
const HARVEST_DISTANCE: float = 3.0
const CHOP_INTERVAL: float = 1.0
const TREE_WORK_OFFSET: Vector2 = Vector2(32.0, -16.0)

@onready var sprite: Sprite2D = $Sprite2D

var _tree_container: Node2D
var _target_tree: Node2D
var _state: State = State.WAITING
var _chop_elapsed: float = 0.0

func setup(tree_container: Node2D) -> void:
	_tree_container = tree_container
	_target_tree = null
	_chop_elapsed = 0.0
	_state = State.SEARCHING

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_tree_container):
		_state = State.WAITING
		return

	if not _is_valid_tree(_target_tree):
		_target_tree = _find_nearest_tree()
		_chop_elapsed = 0.0

	if _target_tree == null:
		_state = State.WAITING
		return

	var work_position: Vector2 = _get_tree_work_position(_target_tree)
	var distance: float = global_position.distance_to(work_position)
	if distance > HARVEST_DISTANCE:
		_state = State.MOVING
		var previous_position: Vector2 = global_position
		global_position = global_position.move_toward(work_position, MOVE_SPEED * delta)
		_update_facing(global_position - previous_position)
		return

	_state = State.CHOPPING
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

func _update_facing(movement: Vector2) -> void:
	if absf(movement.x) > 0.01:
		sprite.flip_h = movement.x > 0.0

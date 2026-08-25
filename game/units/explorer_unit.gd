class_name ExplorerUnit
extends CharacterBody2D

var unit_id: int = 0
var owner_peer_id: int = 0
var territory_id: int = 0
var definition: UnitDefinition
var simulation_enabled: bool = false
var move_target: Vector2 = Vector2.ZERO
var has_move_target: bool = false
var _navigation_path: PackedVector2Array = PackedVector2Array()
var _navigation_index: int = 0
var _network_position: Vector2 = Vector2.ZERO
var _selected: bool = false

func configure_network(new_unit_id: int, new_owner_peer_id: int, new_territory_id: int, new_definition: UnitDefinition, should_simulate: bool) -> void:
	unit_id = new_unit_id
	owner_peer_id = new_owner_peer_id
	territory_id = new_territory_id
	definition = new_definition
	simulation_enabled = should_simulate
	_network_position = global_position
	queue_redraw()

func set_navigation_path(path: PackedVector2Array) -> void:
	_navigation_path = path
	_navigation_index = 0
	if path.is_empty():
		velocity = Vector2.ZERO
		has_move_target = false
		return
	move_target = path[path.size() - 1]
	has_move_target = true
	_advance_reached_waypoints()

func apply_network_state(network_position: Vector2, network_target: Vector2, moving: bool) -> void:
	_network_position = network_position
	move_target = network_target
	has_move_target = moving
	if not moving:
		_navigation_path = PackedVector2Array()
		_navigation_index = 0

func set_selected(selected: bool) -> void:
	_selected = selected
	queue_redraw()

func get_vision_radius_world(tile_size: int) -> float:
	return (definition.vision_radius_tiles if definition != null else 8.0) * float(tile_size)

func _physics_process(_delta: float) -> void:
	if not simulation_enabled:
		global_position = global_position.lerp(_network_position, 0.45)
		return
	if not has_move_target or definition == null:
		velocity = Vector2.ZERO
		return
	_advance_reached_waypoints()
	if _navigation_index >= _navigation_path.size():
		global_position = move_target
		velocity = Vector2.ZERO
		has_move_target = false
		return
	velocity = global_position.direction_to(_navigation_path[_navigation_index]) * definition.movement_speed
	move_and_slide()

func _advance_reached_waypoints() -> void:
	while _navigation_index < _navigation_path.size() and global_position.distance_to(_navigation_path[_navigation_index]) <= 4.0:
		_navigation_index += 1

func _draw() -> void:
	if _selected:
		draw_arc(Vector2(0.0, 10.0), 14.0, 0.0, TAU, 32, Color("#ffd166d0"), 2.0, true)

class_name ExplorerUnit
extends CharacterBody2D

const ARRIVAL_DISTANCE: float = 4.0
const STUCK_REPATH_SECONDS: float = 0.45
const PATH_PROGRESS_EPSILON: float = 0.05

var unit_id: int = 0
var owner_peer_id: int = 0
var territory_id: int = 0
var definition: UnitDefinition
var simulation_enabled: bool = false
var move_target: Vector2 = Vector2.ZERO
var has_move_target: bool = false
var _navigation_path: PackedVector2Array = PackedVector2Array()
var _navigation_index: int = 0
var _path_provider: Callable
var _path_stuck_elapsed: float = 0.0
var _network_position: Vector2 = Vector2.ZERO
var _selected: bool = false
var construction_busy: bool = false

func configure_network(new_unit_id: int, new_owner_peer_id: int, new_territory_id: int, new_definition: UnitDefinition, should_simulate: bool) -> void:
	unit_id = new_unit_id
	owner_peer_id = new_owner_peer_id
	territory_id = new_territory_id
	definition = new_definition
	simulation_enabled = should_simulate
	_network_position = global_position
	queue_redraw()

func setup_navigation(path_provider: Callable) -> void:
	_path_provider = path_provider

func set_navigation_path(path: PackedVector2Array) -> void:
	_navigation_path = path
	_navigation_index = 0
	_path_stuck_elapsed = 0.0
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

func set_construction_busy(busy: bool, restored_position: Vector2 = Vector2.INF) -> void:
	construction_busy = busy
	set_meta(&"construction_busy", busy)
	if restored_position != Vector2.INF:
		global_position = restored_position
		_network_position = restored_position
	if busy:
		set_navigation_path(PackedVector2Array())
		set_selected(false)
	visible = not busy
	collision_layer = 0 if busy else 1
	collision_mask = 0 if busy else 2
	var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if is_instance_valid(collision_shape):
		collision_shape.set_deferred(&"disabled", busy)
	set_physics_process(not busy)

func get_vision_radius_world(tile_size: int) -> float:
	return (definition.vision_radius_tiles if definition != null else 8.0) * float(tile_size)

func _physics_process(delta: float) -> void:
	if not simulation_enabled:
		global_position = global_position.lerp(_network_position, 0.45)
		return
	if not has_move_target or definition == null:
		velocity = Vector2.ZERO
		_path_stuck_elapsed = 0.0
		return
	if _path_stuck_elapsed >= STUCK_REPATH_SECONDS:
		_rebuild_navigation_path()
	_advance_reached_waypoints()
	if _navigation_index >= _navigation_path.size():
		global_position = move_target
		velocity = Vector2.ZERO
		has_move_target = false
		_path_stuck_elapsed = 0.0
		return
	var waypoint: Vector2 = _navigation_path[_navigation_index]
	var previous_position: Vector2 = global_position
	velocity = global_position.direction_to(waypoint) * definition.movement_speed
	move_and_slide()
	var previous_distance: float = previous_position.distance_to(waypoint)
	var current_distance: float = global_position.distance_to(waypoint)
	if current_distance <= ARRIVAL_DISTANCE or current_distance < previous_distance - PATH_PROGRESS_EPSILON:
		_path_stuck_elapsed = 0.0
	else:
		_path_stuck_elapsed += delta

func _advance_reached_waypoints() -> void:
	while _navigation_index < _navigation_path.size() and global_position.distance_to(_navigation_path[_navigation_index]) <= ARRIVAL_DISTANCE:
		_navigation_index += 1

func _rebuild_navigation_path() -> void:
	_path_stuck_elapsed = 0.0
	if not _path_provider.is_valid():
		return
	var result: Variant = _path_provider.call(global_position, move_target)
	if result is not PackedVector2Array or (result as PackedVector2Array).is_empty():
		set_navigation_path(PackedVector2Array())
		return
	set_navigation_path(result as PackedVector2Array)

func _draw() -> void:
	if _selected:
		draw_arc(Vector2(0.0, 10.0), 14.0, 0.0, TAU, 32, Color("#ffd166d0"), 2.0, true)

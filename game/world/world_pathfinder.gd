class_name WorldPathfinder
extends Node

const INVALID_CELL: Vector2i = Vector2i(-1, -1)
const MAX_NEAREST_CELL_RADIUS: int = 12
const MAX_DETOURS: int = 64

var _grid_size: Vector2i = Vector2i.ZERO
var _tile_size: int = 32
var _solid_cells: Dictionary[Vector2i, bool] = {}

func configure(grid_size: Vector2i, tile_size: int) -> void:
	_grid_size = grid_size
	_tile_size = maxi(1, tile_size)
	_solid_cells.clear()

func rebuild_obstacles(obstacle_roots: Array[Node]) -> void:
	_solid_cells.clear()
	for obstacle_root: Node in obstacle_roots:
		_mark_collision_shapes(obstacle_root)

func find_path(start_position: Vector2, requested_target: Vector2) -> PackedVector2Array:
	if _grid_size.x <= 0 or _grid_size.y <= 0:
		return PackedVector2Array()
	var start_cell: Vector2i = _nearest_walkable_cell(_world_to_cell(start_position))
	var requested_target_cell: Vector2i = _world_to_cell(requested_target)
	var target_cell: Vector2i = _nearest_walkable_cell(requested_target_cell)
	if start_cell == INVALID_CELL or target_cell == INVALID_CELL:
		return PackedVector2Array()
	var path: PackedVector2Array = PackedVector2Array()
	var current: Vector2i = start_cell
	for _detour_index: int in MAX_DETOURS:
		var blocked: Vector2i = _first_blocked_on_line(current, target_cell)
		if blocked == INVALID_CELL:
			path.append(_clamp_world_position(requested_target) if target_cell == requested_target_cell else _cell_center(target_cell))
			return path
		var detour: Vector2i = _choose_detour(current, blocked, target_cell)
		if detour == INVALID_CELL or detour == current:
			return PackedVector2Array()
		path.append(_cell_center(detour))
		current = detour
	return PackedVector2Array()

func is_world_position_walkable(world_position: Vector2) -> bool:
	var cell: Vector2i = _world_to_cell(world_position)
	return _is_cell_in_bounds(cell) and not _solid_cells.has(cell)

func get_solid_cell_count() -> int:
	return _solid_cells.size()

func _choose_detour(current: Vector2i, blocked: Vector2i, target: Vector2i) -> Vector2i:
	var travel: Vector2 = Vector2(target - current).normalized()
	var perpendicular: Vector2 = Vector2(-travel.y, travel.x)
	var best: Vector2i = INVALID_CELL
	var best_score: float = INF
	for radius: int in range(2, 9):
		for sign_value: int in [-1, 1]:
			var candidate: Vector2i = blocked + Vector2i(roundi(perpendicular.x * radius * sign_value), roundi(perpendicular.y * radius * sign_value))
			if not _is_cell_in_bounds(candidate) or _solid_cells.has(candidate):
				continue
			if _first_blocked_on_line(current, candidate) != INVALID_CELL:
				continue
			var score: float = Vector2(candidate).distance_squared_to(Vector2(target))
			if score < best_score:
				best_score = score
				best = candidate
		if best != INVALID_CELL:
			return best
	return best

func _first_blocked_on_line(from_cell: Vector2i, to_cell: Vector2i) -> Vector2i:
	var x0: int = from_cell.x
	var y0: int = from_cell.y
	var x1: int = to_cell.x
	var y1: int = to_cell.y
	var dx: int = absi(x1 - x0)
	var sx: int = 1 if x0 < x1 else -1
	var dy: int = -absi(y1 - y0)
	var sy: int = 1 if y0 < y1 else -1
	var error: int = dx + dy
	while true:
		var cell: Vector2i = Vector2i(x0, y0)
		if cell != from_cell and cell != to_cell and _solid_cells.has(cell):
			return cell
		if x0 == x1 and y0 == y1:
			break
		var doubled_error: int = error * 2
		if doubled_error >= dy:
			error += dy
			x0 += sx
		if doubled_error <= dx:
			error += dx
			y0 += sy
	return INVALID_CELL

func _mark_collision_shapes(node: Node) -> void:
	if not is_instance_valid(node) or node.is_queued_for_deletion():
		return
	if node is CollisionShape2D:
		_mark_collision_shape(node as CollisionShape2D)
	for child: Node in node.get_children():
		_mark_collision_shapes(child)

func _mark_collision_shape(collision_shape: CollisionShape2D) -> void:
	if collision_shape.disabled or collision_shape.shape == null:
		return
	var local_rect: Rect2 = collision_shape.shape.get_rect()
	var local_points: PackedVector2Array = PackedVector2Array([
		local_rect.position, Vector2(local_rect.end.x, local_rect.position.y),
		local_rect.end, Vector2(local_rect.position.x, local_rect.end.y),
	])
	var minimum: Vector2 = Vector2(INF, INF)
	var maximum: Vector2 = Vector2(-INF, -INF)
	for local_point: Vector2 in local_points:
		var world_point: Vector2 = collision_shape.global_transform * local_point
		minimum = Vector2(minf(minimum.x, world_point.x), minf(minimum.y, world_point.y))
		maximum = Vector2(maxf(maximum.x, world_point.x), maxf(maximum.y, world_point.y))
	var first_cell: Vector2i = _world_to_cell(minimum)
	var last_cell: Vector2i = _world_to_cell(maximum - Vector2(0.001, 0.001))
	for y: int in range(first_cell.y, last_cell.y + 1):
		for x: int in range(first_cell.x, last_cell.x + 1):
			var cell: Vector2i = Vector2i(x, y)
			if _is_cell_in_bounds(cell):
				_solid_cells[cell] = true

func _nearest_walkable_cell(origin: Vector2i) -> Vector2i:
	var clamped_origin: Vector2i = _clamp_cell(origin)
	if not _solid_cells.has(clamped_origin):
		return clamped_origin
	for radius: int in range(1, MAX_NEAREST_CELL_RADIUS + 1):
		for y_offset: int in range(-radius, radius + 1):
			for x_offset: int in range(-radius, radius + 1):
				if maxi(absi(x_offset), absi(y_offset)) != radius:
					continue
				var candidate: Vector2i = clamped_origin + Vector2i(x_offset, y_offset)
				if _is_cell_in_bounds(candidate) and not _solid_cells.has(candidate):
					return candidate
	return INVALID_CELL

func _world_to_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(floori(world_position.x / float(_tile_size)), floori(world_position.y / float(_tile_size)))

func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell * _tile_size) + Vector2.ONE * float(_tile_size) * 0.5

func _clamp_cell(cell: Vector2i) -> Vector2i:
	return Vector2i(clampi(cell.x, 0, _grid_size.x - 1), clampi(cell.y, 0, _grid_size.y - 1))

func _clamp_world_position(world_position: Vector2) -> Vector2:
	var inset: float = float(_tile_size) * 0.5
	return Vector2(clampf(world_position.x, inset, float(_grid_size.x * _tile_size) - inset), clampf(world_position.y, inset, float(_grid_size.y * _tile_size) - inset))

func _is_cell_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _grid_size.x and cell.y < _grid_size.y

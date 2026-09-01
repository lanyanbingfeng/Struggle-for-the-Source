class_name WorldPathfinder
extends Node

const INVALID_CELL: Vector2i = Vector2i(-1, -1)
const MAX_NEAREST_CELL_RADIUS: int = 12
const MAX_EXPANDED_CELLS_PER_SEARCH: int = 220000
const CARDINAL_MOVE_COST: float = 10.0
const DIAGONAL_MOVE_COST: float = 14.1421356237
const SEARCH_MARGINS: Array[int] = [6, 12, 24, 48, 96]
const NEIGHBOR_DIRECTIONS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]

var _grid_size: Vector2i = Vector2i.ZERO
var _tile_size: int = 32
var _solid_cells: Dictionary[Vector2i, bool] = {}
var _external_solid_cells: Dictionary[Vector2i, bool] = {}

func configure(grid_size: Vector2i, tile_size: int) -> void:
	_grid_size = grid_size
	_tile_size = maxi(1, tile_size)
	_solid_cells.clear()
	_external_solid_cells.clear()

func rebuild_obstacles(obstacle_roots: Array[Node]) -> void:
	_solid_cells.clear()
	for obstacle_root: Node in obstacle_roots:
		_mark_collision_shapes(obstacle_root)

func set_external_obstacles(extra_solid_cells: Array[Vector2i]) -> void:
	_external_solid_cells.clear()
	for cell: Vector2i in extra_solid_cells:
		if _is_cell_in_bounds(cell):
			_external_solid_cells[cell] = true

func find_path(start_position: Vector2, requested_target: Vector2) -> PackedVector2Array:
	return _find_path_with_footprint(start_position, requested_target, Vector2i.ONE)

func find_path_for_footprint(start_position: Vector2, requested_target: Vector2, footprint: Vector2i) -> PackedVector2Array:
	var safe_footprint: Vector2i = Vector2i(maxi(1, footprint.x), maxi(1, footprint.y))
	return _find_path_with_footprint(start_position, requested_target, safe_footprint)

func _find_path_with_footprint(start_position: Vector2, requested_target: Vector2, footprint: Vector2i) -> PackedVector2Array:
	if _grid_size.x <= 0 or _grid_size.y <= 0:
		return PackedVector2Array()
	var requested_start_cell: Vector2i = _world_to_cell(start_position)
	var requested_target_cell: Vector2i = _world_to_cell(requested_target)
	var start_cell: Vector2i = _nearest_walkable_cell(requested_start_cell, requested_target_cell, footprint)
	var target_cell: Vector2i = _nearest_walkable_cell(requested_target_cell, start_cell, footprint)
	if start_cell == INVALID_CELL or target_cell == INVALID_CELL:
		return PackedVector2Array()
	var clamped_target: Vector2 = _clamp_world_position(requested_target)
	var final_position: Vector2 = clamped_target if target_cell == requested_target_cell and _is_world_point_clear_for_footprint(clamped_target, footprint) else _cell_center(target_cell)
	if start_cell == target_cell:
		return PackedVector2Array([final_position])
	if _is_grid_segment_walkable(start_cell, target_cell, footprint):
		return PackedVector2Array([final_position])
	var cell_path: Array[Vector2i] = _find_astar_path(start_cell, target_cell, footprint)
	if cell_path.is_empty():
		return PackedVector2Array()
	var smoothed_path: Array[Vector2i] = _smooth_cell_path(cell_path, footprint)
	var world_path: PackedVector2Array = PackedVector2Array()
	for index: int in range(1, smoothed_path.size()):
		if index == smoothed_path.size() - 1:
			world_path.append(final_position)
		else:
			world_path.append(_cell_center(smoothed_path[index]))
	return world_path

func is_world_position_walkable(world_position: Vector2) -> bool:
	var cell: Vector2i = _world_to_cell(world_position)
	return _is_cell_in_bounds(cell) and not _is_cell_solid(cell)

func is_cell_rect_walkable(cell_rect: Rect2i) -> bool:
	if cell_rect.size.x <= 0 or cell_rect.size.y <= 0:
		return false
	for y: int in range(cell_rect.position.y, cell_rect.end.y):
		for x: int in range(cell_rect.position.x, cell_rect.end.x):
			var cell := Vector2i(x, y)
			if not _is_cell_in_bounds(cell) or _is_cell_solid(cell):
				return false
	return true

func get_solid_cell_count() -> int:
	return _solid_cells.size() + _external_solid_cells.size()

func _find_astar_path(start: Vector2i, target: Vector2i, footprint: Vector2i) -> Array[Vector2i]:
	for margin: int in SEARCH_MARGINS:
		var search_bounds: Rect2i = _make_search_bounds(start, target, margin)
		var path: Array[Vector2i] = _find_astar_path_in_bounds(start, target, search_bounds, footprint)
		if not path.is_empty():
			return path
		if search_bounds.position == Vector2i.ZERO and search_bounds.size == _grid_size:
			break
	return []

func _find_astar_path_in_bounds(start: Vector2i, target: Vector2i, search_bounds: Rect2i, footprint: Vector2i) -> Array[Vector2i]:
	var open_cells: Array[Vector2i] = []
	var open_priorities: Array[float] = []
	var open_heuristics: Array[float] = []
	var came_from: Dictionary[Vector2i, Vector2i] = {}
	var g_score: Dictionary[Vector2i, float] = {start: 0.0}
	var closed: Dictionary[Vector2i, bool] = {}
	var initial_heuristic: float = _octile_distance(start, target)
	_heap_push(open_cells, open_priorities, open_heuristics, start, initial_heuristic, initial_heuristic)
	var expanded_cells: int = 0
	while not open_cells.is_empty() and expanded_cells < MAX_EXPANDED_CELLS_PER_SEARCH:
		var current: Vector2i = _heap_pop(open_cells, open_priorities, open_heuristics)
		if closed.has(current):
			continue
		if current == target:
			return _reconstruct_cell_path(came_from, current)
		closed[current] = true
		expanded_cells += 1
		var current_cost: float = g_score.get(current, INF)
		for direction: Vector2i in NEIGHBOR_DIRECTIONS:
			var neighbor: Vector2i = current + direction
			if not search_bounds.has_point(neighbor) or closed.has(neighbor) or not _is_footprint_walkable(neighbor, footprint):
				continue
			var diagonal: bool = direction.x != 0 and direction.y != 0
			if diagonal and (not _is_footprint_walkable(current + Vector2i(direction.x, 0), footprint) or not _is_footprint_walkable(current + Vector2i(0, direction.y), footprint)):
				continue
			var step_cost: float = DIAGONAL_MOVE_COST if diagonal else CARDINAL_MOVE_COST
			var tentative_cost: float = current_cost + step_cost
			if tentative_cost >= g_score.get(neighbor, INF):
				continue
			came_from[neighbor] = current
			g_score[neighbor] = tentative_cost
			var heuristic: float = _octile_distance(neighbor, target)
			_heap_push(open_cells, open_priorities, open_heuristics, neighbor, tentative_cost + heuristic, heuristic)
	return []

func _reconstruct_cell_path(came_from: Dictionary[Vector2i, Vector2i], current: Vector2i) -> Array[Vector2i]:
	var reversed_path: Array[Vector2i] = [current]
	while came_from.has(current):
		current = came_from[current]
		reversed_path.append(current)
	reversed_path.reverse()
	return reversed_path

func _smooth_cell_path(cell_path: Array[Vector2i], footprint: Vector2i) -> Array[Vector2i]:
	if cell_path.size() <= 2:
		return cell_path
	var smoothed: Array[Vector2i] = [cell_path[0]]
	var anchor_index: int = 0
	while anchor_index < cell_path.size() - 1:
		var next_index: int = cell_path.size() - 1
		while next_index > anchor_index + 1 and not _is_grid_segment_walkable(cell_path[anchor_index], cell_path[next_index], footprint):
			next_index -= 1
		smoothed.append(cell_path[next_index])
		anchor_index = next_index
	return smoothed

func _is_grid_segment_walkable(from_cell: Vector2i, to_cell: Vector2i, footprint: Vector2i) -> bool:
	if not _is_footprint_walkable(from_cell, footprint) or not _is_footprint_walkable(to_cell, footprint):
		return false
	var from_position: Vector2 = _cell_center(from_cell)
	var to_position: Vector2 = _cell_center(to_cell)
	var distance: float = from_position.distance_to(to_position)
	var sample_spacing: float = maxf(2.0, float(_tile_size) * 0.2)
	var sample_count: int = maxi(1, ceili(distance / sample_spacing))
	for sample_index: int in range(sample_count + 1):
		var sample: Vector2 = from_position.lerp(to_position, float(sample_index) / float(sample_count))
		if not _is_world_point_clear_for_footprint(sample, footprint):
			return false
	return true

func _is_world_point_clear_for_footprint(world_position: Vector2, footprint: Vector2i) -> bool:
	var half: Vector2i = Vector2i(footprint.x >> 1, footprint.y >> 1)
	for y: int in range(footprint.y):
		for x: int in range(footprint.x):
			var offset: Vector2i = Vector2i(x, y) - half
			if not _is_world_point_clear(world_position + Vector2(offset * _tile_size)):
				return false
	return true

func _is_world_point_clear(world_position: Vector2) -> bool:
	var center_cell: Vector2i = _world_to_cell(world_position)
	if not _is_cell_in_bounds(center_cell) or _is_cell_solid(center_cell):
		return false
	var clearance: float = minf(float(_tile_size) * 0.34, float(_tile_size) * 0.5 - 1.0)
	for y_offset: int in range(-1, 2):
		for x_offset: int in range(-1, 2):
			var obstacle_cell: Vector2i = center_cell + Vector2i(x_offset, y_offset)
			if not _is_cell_solid(obstacle_cell):
				continue
			var obstacle_rect: Rect2 = Rect2(
				Vector2(obstacle_cell * _tile_size) - Vector2.ONE * clearance,
				Vector2.ONE * (float(_tile_size) + clearance * 2.0)
			)
			if obstacle_rect.has_point(world_position):
				return false
	return true

func _make_search_bounds(start: Vector2i, target: Vector2i, margin: int) -> Rect2i:
	var minimum: Vector2i = Vector2i(maxi(0, mini(start.x, target.x) - margin), maxi(0, mini(start.y, target.y) - margin))
	var maximum: Vector2i = Vector2i(mini(_grid_size.x - 1, maxi(start.x, target.x) + margin), mini(_grid_size.y - 1, maxi(start.y, target.y) + margin))
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)

func _octile_distance(from_cell: Vector2i, to_cell: Vector2i) -> float:
	var dx: float = float(absi(to_cell.x - from_cell.x))
	var dy: float = float(absi(to_cell.y - from_cell.y))
	return CARDINAL_MOVE_COST * (dx + dy) + (DIAGONAL_MOVE_COST - CARDINAL_MOVE_COST * 2.0) * minf(dx, dy)

func _heap_push(
	cells: Array[Vector2i],
	priorities: Array[float],
	heuristics: Array[float],
	cell: Vector2i,
	priority: float,
	heuristic: float
) -> void:
	cells.append(cell)
	priorities.append(priority)
	heuristics.append(heuristic)
	var index: int = cells.size() - 1
	while index > 0:
		var parent: int = floori(float(index - 1) * 0.5)
		if not _heap_entry_precedes(priorities[index], heuristics[index], priorities[parent], heuristics[parent]):
			break
		_heap_swap(cells, priorities, heuristics, index, parent)
		index = parent

func _heap_pop(cells: Array[Vector2i], priorities: Array[float], heuristics: Array[float]) -> Vector2i:
	var result: Vector2i = cells[0]
	var last_index: int = cells.size() - 1
	if last_index == 0:
		cells.pop_back()
		priorities.pop_back()
		heuristics.pop_back()
		return result
	cells[0] = cells[last_index]
	priorities[0] = priorities[last_index]
	heuristics[0] = heuristics[last_index]
	cells.pop_back()
	priorities.pop_back()
	heuristics.pop_back()
	var index: int = 0
	while true:
		var left: int = index * 2 + 1
		if left >= cells.size():
			break
		var right: int = left + 1
		var best_child: int = left
		if right < cells.size() and _heap_entry_precedes(priorities[right], heuristics[right], priorities[left], heuristics[left]):
			best_child = right
		if not _heap_entry_precedes(priorities[best_child], heuristics[best_child], priorities[index], heuristics[index]):
			break
		_heap_swap(cells, priorities, heuristics, index, best_child)
		index = best_child
	return result

func _heap_entry_precedes(priority_a: float, heuristic_a: float, priority_b: float, heuristic_b: float) -> bool:
	if not is_equal_approx(priority_a, priority_b):
		return priority_a < priority_b
	return heuristic_a < heuristic_b

func _heap_swap(
	cells: Array[Vector2i],
	priorities: Array[float],
	heuristics: Array[float],
	index_a: int,
	index_b: int
) -> void:
	var cell: Vector2i = cells[index_a]
	cells[index_a] = cells[index_b]
	cells[index_b] = cell
	var priority: float = priorities[index_a]
	priorities[index_a] = priorities[index_b]
	priorities[index_b] = priority
	var heuristic: float = heuristics[index_a]
	heuristics[index_a] = heuristics[index_b]
	heuristics[index_b] = heuristic

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

func _nearest_walkable_cell(origin: Vector2i, reference: Vector2i, footprint: Vector2i) -> Vector2i:
	var clamped_origin: Vector2i = _clamp_cell(origin)
	if _is_footprint_walkable(clamped_origin, footprint):
		return clamped_origin
	for radius: int in range(1, MAX_NEAREST_CELL_RADIUS + 1):
		var best: Vector2i = INVALID_CELL
		var best_origin_distance: float = INF
		var best_reference_distance: float = INF
		for y_offset: int in range(-radius, radius + 1):
			for x_offset: int in range(-radius, radius + 1):
				if maxi(absi(x_offset), absi(y_offset)) != radius:
					continue
				var candidate: Vector2i = clamped_origin + Vector2i(x_offset, y_offset)
				if not _is_footprint_walkable(candidate, footprint):
					continue
				var origin_distance: float = Vector2(candidate).distance_squared_to(Vector2(clamped_origin))
				var reference_distance: float = Vector2(candidate).distance_squared_to(Vector2(reference))
				if origin_distance < best_origin_distance or (is_equal_approx(origin_distance, best_origin_distance) and reference_distance < best_reference_distance):
					best = candidate
					best_origin_distance = origin_distance
					best_reference_distance = reference_distance
		if best != INVALID_CELL:
			return best
	return INVALID_CELL

func _is_cell_solid(cell: Vector2i) -> bool:
	return _solid_cells.has(cell) or _external_solid_cells.has(cell)

func _is_footprint_walkable(center_cell: Vector2i, footprint: Vector2i) -> bool:
	var top_left: Vector2i = center_cell - Vector2i(footprint.x >> 1, footprint.y >> 1)
	for y: int in range(top_left.y, top_left.y + footprint.y):
		for x: int in range(top_left.x, top_left.x + footprint.x):
			var cell: Vector2i = Vector2i(x, y)
			if not _is_cell_in_bounds(cell) or _is_cell_solid(cell):
				return false
	return true

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

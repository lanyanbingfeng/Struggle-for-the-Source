@tool
class_name WorldResourceStreamer
extends Node

const CHUNK_SIZE_TILES: int = 32
const STREAM_RADIUS_CHUNKS: int = 1
const INVALID_CHUNK: Vector2i = Vector2i(-99999, -99999)
const RESOURCE_MARKER_SCRIPT: Script = preload("res://game/world/world_resource_marker.gd")
const TREE_FOOTPRINT_OFFSETS: Array[Vector2i] = [Vector2i.ZERO, Vector2i.UP]

var _map_size_tiles: int = 500
var _tile_size: int = 32
var _tree_container: Node2D
var _stone_container: Node2D
var _mineral_container: Node2D
var _resource_data_by_id: Dictionary[int, Dictionary] = {}
var _resource_ids_by_chunk: Dictionary[Vector2i, Array] = {}
var _loaded_markers_by_id: Dictionary[int, Node2D] = {}
var _active_chunks: Dictionary[Vector2i, bool] = {}
var _occupied_cells: Dictionary[Vector2i, bool] = {}
var _next_resource_id: int = 1
var _center_chunk: Vector2i = INVALID_CHUNK

func configure(map_size_tiles: int, tile_size: int, tree_container: Node2D, stone_container: Node2D, mineral_container: Node2D) -> void:
	_map_size_tiles = map_size_tiles
	_tile_size = tile_size
	_tree_container = tree_container
	_stone_container = stone_container
	_mineral_container = mineral_container

func regenerate(resource_seed: int, abundance: int, excluded_rects: Array[Rect2i]) -> void:
	clear_all()
	for excluded_rect: Rect2i in excluded_rects:
		for y: int in range(excluded_rect.position.y, excluded_rect.end.y):
			for x: int in range(excluded_rect.position.x, excluded_rect.end.x):
				_occupied_cells[Vector2i(x, y)] = true
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = resource_seed ^ 0x37A9D14B
	var chunks_per_axis: int = ceili(float(_map_size_tiles) / float(CHUNK_SIZE_TILES))
	for chunk_y: int in chunks_per_axis:
		for chunk_x: int in chunks_per_axis:
			_generate_chunk(Vector2i(chunk_x, chunk_y), abundance, rng)
	_center_chunk = INVALID_CHUNK

func update_streaming(camera_world_position: Vector2, force: bool = false) -> bool:
	var next_center: Vector2i = _world_to_chunk(camera_world_position)
	if not force and next_center == _center_chunk:
		return false
	_center_chunk = next_center
	var desired_chunks: Dictionary[Vector2i, bool] = {}
	var chunks_per_axis: int = ceili(float(_map_size_tiles) / float(CHUNK_SIZE_TILES))
	for y_offset: int in range(-STREAM_RADIUS_CHUNKS, STREAM_RADIUS_CHUNKS + 1):
		for x_offset: int in range(-STREAM_RADIUS_CHUNKS, STREAM_RADIUS_CHUNKS + 1):
			var chunk: Vector2i = next_center + Vector2i(x_offset, y_offset)
			if chunk.x >= 0 and chunk.y >= 0 and chunk.x < chunks_per_axis and chunk.y < chunks_per_axis:
				desired_chunks[chunk] = true
	var chunks_to_unload: Array[Vector2i] = []
	for chunk: Vector2i in _active_chunks.keys():
		if not desired_chunks.has(chunk):
			chunks_to_unload.append(chunk)
	for chunk: Vector2i in chunks_to_unload:
		_unload_chunk(chunk)
	for chunk: Vector2i in desired_chunks.keys():
		if not _active_chunks.has(chunk):
			_load_chunk(chunk)
	_active_chunks = desired_chunks
	return true

func claim_resources_in_rect(rect: Rect2i) -> Array[Dictionary]:
	var claimed_data: Array[Dictionary] = []
	var resource_ids: Array[int] = _resource_ids_in_rect(rect)
	for resource_id: int in resource_ids:
		var data: Dictionary = (_resource_data_by_id.get(resource_id, {}) as Dictionary).duplicate(true)
		if data.is_empty():
			continue
		claimed_data.append(data)
		_remove_resource_data(resource_id)
	return claimed_data

func claim_resource_by_id(resource_id: int, expected_type: StringName = &"") -> Dictionary:
	var data: Dictionary = (_resource_data_by_id.get(resource_id, {}) as Dictionary).duplicate(true)
	if data.is_empty():
		return {}
	var resource_type: StringName = data.get("resource_type", &"tree") as StringName
	if not expected_type.is_empty() and resource_type != expected_type:
		return {}
	_remove_resource_data(resource_id)
	return data

func get_resource_data(resource_id: int) -> Dictionary:
	return (_resource_data_by_id.get(resource_id, {}) as Dictionary).duplicate(true)

func get_all_resource_data() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for resource_id: int in _resource_data_by_id.keys():
		var data: Dictionary = _resource_data_by_id.get(resource_id, {}) as Dictionary
		if not data.is_empty():
			result.append(data.duplicate(true))
	return result

func restore_resource_data(saved_resources: Array) -> void:
	clear_all()
	var highest_resource_id: int = 0
	for value: Variant in saved_resources:
		if value is not Dictionary:
			continue
		var saved: Dictionary = (value as Dictionary).duplicate(true)
		var resource_id: int = int(saved.get("resource_id", 0))
		var resource_type: StringName = StringName(str(saved.get("resource_type", "")))
		var cell: Vector2i = saved.get("cell", Vector2i(-1, -1)) as Vector2i
		if resource_id <= 0 or resource_type not in [&"tree", &"stone", &"iron", &"chest"]:
			continue
		if cell.x < 0 or cell.y < 0 or cell.x >= _map_size_tiles or cell.y >= _map_size_tiles:
			continue
		var footprint: Array[Vector2i] = _resource_footprint_cells(resource_type, cell)
		var overlaps: bool = false
		for footprint_cell: Vector2i in footprint:
			if _occupied_cells.has(footprint_cell):
				overlaps = true
				break
		if overlaps:
			continue
		for footprint_cell: Vector2i in footprint:
			_occupied_cells[footprint_cell] = true
		var chunk: Vector2i = _cell_to_chunk(cell)
		saved["resource_id"] = resource_id
		saved["resource_type"] = resource_type
		saved["cell"] = cell
		saved["chunk"] = chunk
		_resource_data_by_id[resource_id] = saved
		var chunk_ids: Array = _resource_ids_by_chunk.get(chunk, []) as Array
		chunk_ids.append(resource_id)
		_resource_ids_by_chunk[chunk] = chunk_ids
		highest_resource_id = maxi(highest_resource_id, resource_id)
	_next_resource_id = highest_resource_id + 1
	_center_chunk = INVALID_CHUNK

func count_resources_in_rect(rect: Rect2i) -> Dictionary:
	var counts: Dictionary = {&"tree": 0, &"stone": 0, &"iron": 0, &"chest": 0}
	for resource_id: int in _resource_ids_in_rect(rect):
		var data: Dictionary = _resource_data_by_id.get(resource_id, {}) as Dictionary
		var resource_type: StringName = data.get("resource_type", &"tree") as StringName
		counts[resource_type] = int(counts.get(resource_type, 0)) + 1
	return counts

func get_total_counts() -> Dictionary:
	var counts: Dictionary = {&"tree": 0, &"stone": 0, &"iron": 0, &"chest": 0}
	for data: Dictionary in _resource_data_by_id.values():
		var resource_type: StringName = data.get("resource_type", &"tree") as StringName
		counts[resource_type] = int(counts.get(resource_type, 0)) + 1
	return counts

func get_loaded_marker_count() -> int:
	return _loaded_markers_by_id.size()

func get_active_chunk_count() -> int:
	return _active_chunks.size()

func get_total_resource_count() -> int:
	return _resource_data_by_id.size()

func get_navigation_obstacle_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for data: Dictionary in _resource_data_by_id.values():
		var cell: Vector2i = data.get("cell", Vector2i.ZERO) as Vector2i
		var resource_type: StringName = data.get("resource_type", &"tree") as StringName
		cells.append(cell)
		if resource_type == &"tree":
			cells.append(cell + Vector2i.UP)
	return cells

func get_layout_metrics() -> Dictionary:
	var grouped_counts: Dictionary = {&"tree": 0, &"iron": 0, &"chest": 0}
	var total_counts: Dictionary = {&"tree": 0, &"iron": 0, &"chest": 0}
	for resource_ids_value: Variant in _resource_ids_by_chunk.values():
		var cells_by_type: Dictionary = {&"tree": [], &"iron": [], &"chest": []}
		for resource_id_value: Variant in (resource_ids_value as Array):
			var data: Dictionary = _resource_data_by_id.get(int(resource_id_value), {}) as Dictionary
			var resource_type: StringName = data.get("resource_type", &"stone") as StringName
			if not cells_by_type.has(resource_type):
				continue
			(cells_by_type[resource_type] as Array).append(data.get("cell", Vector2i.ZERO) as Vector2i)
		for resource_type: StringName in cells_by_type.keys():
			var cells: Array = cells_by_type[resource_type] as Array
			total_counts[resource_type] = int(total_counts[resource_type]) + cells.size()
			for cell_value: Variant in cells:
				var cell: Vector2i = cell_value as Vector2i
				for neighbor_value: Variant in cells:
					var neighbor: Vector2i = neighbor_value as Vector2i
					if neighbor != cell and maxi(absi(neighbor.x - cell.x), absi(neighbor.y - cell.y)) <= 4:
						grouped_counts[resource_type] = int(grouped_counts[resource_type]) + 1
						break
	var metrics: Dictionary = {}
	for resource_type: StringName in total_counts.keys():
		metrics["%s_grouped_ratio" % str(resource_type)] = float(grouped_counts[resource_type]) / maxf(1.0, float(total_counts[resource_type]))
	return metrics

func clear_streamed_markers() -> void:
	for marker: Node2D in _loaded_markers_by_id.values():
		if is_instance_valid(marker):
			var parent: Node = marker.get_parent()
			if is_instance_valid(parent):
				parent.remove_child(marker)
			marker.queue_free()
	_loaded_markers_by_id.clear()
	_active_chunks.clear()
	_center_chunk = INVALID_CHUNK

func clear_all() -> void:
	clear_streamed_markers()
	_resource_data_by_id.clear()
	_resource_ids_by_chunk.clear()
	_occupied_cells.clear()
	_next_resource_id = 1

func _generate_chunk(chunk: Vector2i, abundance: int, rng: RandomNumberGenerator) -> void:
	var chunk_rect: Rect2i = _chunk_cell_rect(chunk)
	var forest_clusters: int
	match abundance:
		0: forest_clusters = 1 if rng.randf() < 0.62 else 0
		2: forest_clusters = 2 + (1 if rng.randf() < 0.35 else 0)
		_: forest_clusters = 1 + (1 if rng.randf() < 0.35 else 0)
	for _cluster_index: int in forest_clusters:
		_add_cluster(&"tree", _random_cell_in_rect(chunk_rect, rng, 4), rng.randi_range(5, 9), 3, chunk_rect, rng)

	var stone_count: int
	match abundance:
		0: stone_count = rng.randi_range(5, 8)
		2: stone_count = rng.randi_range(15, 21)
		_: stone_count = rng.randi_range(9, 14)
	for _stone_index: int in stone_count:
		_try_store_resource(&"stone", _random_cell_in_rect(chunk_rect, rng, 2))

	var iron_clusters: int = _probability_cluster_count(rng, abundance, 0.55, 0.90, 1.0, 0.58)
	for _cluster_index: int in iron_clusters:
		_add_cluster(&"iron", _random_cell_in_rect(chunk_rect, rng, 4), rng.randi_range(5, 8), 3, chunk_rect, rng)
	var chest_count: int = _probability_cluster_count(rng, abundance, 0.12, 0.26, 0.48, 0.08)
	for _chest_index: int in chest_count:
		_try_store_resource(&"chest", _random_cell_in_rect(chunk_rect, rng, 3))

func _probability_cluster_count(rng: RandomNumberGenerator, abundance: int, scarce_chance: float, standard_chance: float, rich_chance: float, rich_second_chance: float) -> int:
	var chance: float = standard_chance
	if abundance == 0:
		chance = scarce_chance
	elif abundance == 2:
		chance = rich_chance
	var count: int = 1 if rng.randf() < chance else 0
	if abundance == 2 and rich_second_chance > 0.0 and rng.randf() < rich_second_chance:
		count += 1
	return count

func _add_cluster(resource_type: StringName, center: Vector2i, desired_count: int, radius: int, chunk_rect: Rect2i, rng: RandomNumberGenerator) -> void:
	var placed: int = 0
	var attempts: int = 0
	while placed < desired_count and attempts < desired_count * 18:
		attempts += 1
		var offset: Vector2i = Vector2i(rng.randi_range(-radius, radius), rng.randi_range(-radius, radius))
		if Vector2(offset).length_squared() > float(radius * radius):
			continue
		var cell: Vector2i = center + offset
		if not chunk_rect.has_point(cell):
			continue
		if _try_store_resource(resource_type, cell):
			placed += 1

func _try_store_resource(resource_type: StringName, cell: Vector2i) -> bool:
	if cell.x < 2 or cell.y < 2 or cell.x >= _map_size_tiles - 2 or cell.y >= _map_size_tiles - 2:
		return false
	var footprint_cells: Array[Vector2i] = _resource_footprint_cells(resource_type, cell)
	for footprint_cell: Vector2i in footprint_cells:
		if _occupied_cells.has(footprint_cell):
			return false
	for footprint_cell: Vector2i in footprint_cells:
		_occupied_cells[footprint_cell] = true
	var chunk: Vector2i = _cell_to_chunk(cell)
	var resource_id: int = _next_resource_id
	_next_resource_id += 1
	var data: Dictionary = {
		"resource_id": resource_id,
		"resource_type": resource_type,
		"cell": cell,
		"chunk": chunk,
	}
	_resource_data_by_id[resource_id] = data
	var ids: Array = _resource_ids_by_chunk.get(chunk, []) as Array
	ids.append(resource_id)
	_resource_ids_by_chunk[chunk] = ids
	return true

func _resource_footprint_cells(resource_type: StringName, cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if resource_type == &"tree":
		for offset: Vector2i in TREE_FOOTPRINT_OFFSETS:
			cells.append(cell + offset)
	else:
		cells.append(cell)
	return cells

func _load_chunk(chunk: Vector2i) -> void:
	var resource_ids: Array = _resource_ids_by_chunk.get(chunk, []) as Array
	for resource_id_value: Variant in resource_ids:
		var resource_id: int = int(resource_id_value)
		if _loaded_markers_by_id.has(resource_id):
			continue
		var data: Dictionary = _resource_data_by_id.get(resource_id, {}) as Dictionary
		if data.is_empty():
			continue
		var resource_type: StringName = data.get("resource_type", &"tree") as StringName
		var marker: Node2D = RESOURCE_MARKER_SCRIPT.new() as Node2D
		marker.name = "Streamed_%s_%06d" % [str(resource_type).to_pascal_case(), resource_id]
		marker.call(&"configure", resource_id, resource_type, _resource_texture(resource_type))
		_resource_parent(resource_type).add_child(marker)
		marker.position = _resource_world_position(data.get("cell", Vector2i.ZERO) as Vector2i)
		_loaded_markers_by_id[resource_id] = marker

func _unload_chunk(chunk: Vector2i) -> void:
	var resource_ids: Array = _resource_ids_by_chunk.get(chunk, []) as Array
	for resource_id_value: Variant in resource_ids:
		_unload_marker(int(resource_id_value))
	_active_chunks.erase(chunk)

func _unload_marker(resource_id: int) -> void:
	var marker: Node2D = _loaded_markers_by_id.get(resource_id) as Node2D
	_loaded_markers_by_id.erase(resource_id)
	if not is_instance_valid(marker):
		return
	var parent: Node = marker.get_parent()
	if is_instance_valid(parent):
		parent.remove_child(marker)
	marker.queue_free()

func _remove_resource_data(resource_id: int) -> void:
	var data: Dictionary = _resource_data_by_id.get(resource_id, {}) as Dictionary
	if data.is_empty():
		return
	_unload_marker(resource_id)
	var chunk: Vector2i = data.get("chunk", Vector2i.ZERO) as Vector2i
	var ids: Array = _resource_ids_by_chunk.get(chunk, []) as Array
	ids.erase(resource_id)
	_resource_ids_by_chunk[chunk] = ids
	var cell: Vector2i = data.get("cell", Vector2i.ZERO) as Vector2i
	var resource_type: StringName = data.get("resource_type", &"tree") as StringName
	for footprint_cell: Vector2i in _resource_footprint_cells(resource_type, cell):
		_occupied_cells.erase(footprint_cell)
	_resource_data_by_id.erase(resource_id)

func _resource_ids_in_rect(rect: Rect2i) -> Array[int]:
	var result: Array[int] = []
	var first_chunk: Vector2i = _cell_to_chunk(rect.position)
	var last_chunk: Vector2i = _cell_to_chunk(rect.end - Vector2i.ONE)
	for chunk_y: int in range(first_chunk.y, last_chunk.y + 1):
		for chunk_x: int in range(first_chunk.x, last_chunk.x + 1):
			var ids: Array = _resource_ids_by_chunk.get(Vector2i(chunk_x, chunk_y), []) as Array
			for resource_id_value: Variant in ids:
				var resource_id: int = int(resource_id_value)
				var data: Dictionary = _resource_data_by_id.get(resource_id, {}) as Dictionary
				if rect.has_point(data.get("cell", Vector2i.ZERO) as Vector2i):
					result.append(resource_id)
	return result

func _random_cell_in_rect(rect: Rect2i, rng: RandomNumberGenerator, margin: int) -> Vector2i:
	var minimum: Vector2i = rect.position + Vector2i.ONE * margin
	var maximum: Vector2i = rect.end - Vector2i.ONE * (margin + 1)
	if minimum.x > maximum.x or minimum.y > maximum.y:
		minimum = rect.position
		maximum = rect.end - Vector2i.ONE
	return Vector2i(rng.randi_range(minimum.x, maximum.x), rng.randi_range(minimum.y, maximum.y))

func _chunk_cell_rect(chunk: Vector2i) -> Rect2i:
	var position: Vector2i = chunk * CHUNK_SIZE_TILES
	var end: Vector2i = Vector2i(mini(position.x + CHUNK_SIZE_TILES, _map_size_tiles), mini(position.y + CHUNK_SIZE_TILES, _map_size_tiles))
	return Rect2i(position, end - position)

func _world_to_chunk(world_position: Vector2) -> Vector2i:
	return _cell_to_chunk(Vector2i(floori(world_position.x / float(_tile_size)), floori(world_position.y / float(_tile_size))))

func _cell_to_chunk(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / float(CHUNK_SIZE_TILES)), floori(float(cell.y) / float(CHUNK_SIZE_TILES)))

func _resource_world_position(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * _tile_size + _tile_size / 2.0, (cell.y + 1) * _tile_size)

func _resource_parent(resource_type: StringName) -> Node2D:
	if resource_type == &"tree":
		return _tree_container
	if resource_type == &"stone":
		return _stone_container
	return _mineral_container

func _resource_texture(resource_type: StringName) -> Texture2D:
	match resource_type:
		&"tree": return load("res://art/resources/resource_tree_oak_1x2.png")
		&"stone": return load("res://art/resources/resource_stone_1x1.png")
		&"iron": return load("res://art/resources/resource_iron_deposit_1x1.png")
		_: return load("res://art/resources/resource_treasure_chest_imagegen_1x1.png")

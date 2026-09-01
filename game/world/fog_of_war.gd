class_name FogOfWar
extends Node2D

const FOG_COLOR: Color = Color(0.02, 0.035, 0.035, 0.46)

var _map_size_tiles: Vector2i = Vector2i(500, 500)
var _tile_size: int = 32
var _owned_territories: Array[Rect2i] = []
var _vision_sources: Array[Dictionary] = []
var _full_vision: bool = false
var _explored_cells: PackedByteArray = PackedByteArray()
var _exploration_image: Image
var _exploration_texture: ImageTexture

func _ready() -> void:
	z_index = 1000
	show_behind_parent = false

func configure(map_size_tiles: Vector2i, tile_size: int, owned_territory: Rect2i) -> void:
	_map_size_tiles = map_size_tiles
	_tile_size = tile_size
	_owned_territories = [owned_territory]
	_reset_exploration()
	_mark_owned_territories_explored()
	_upload_exploration_texture()
	queue_redraw()

func set_owned_territories(territories: Array[Rect2i]) -> void:
	_owned_territories = territories.duplicate()
	if _mark_owned_territories_explored():
		_upload_exploration_texture()
	queue_redraw()

func update_visibility(vision_sources: Array[Dictionary], full_vision: bool) -> void:
	_vision_sources = vision_sources
	_full_vision = full_vision
	var exploration_changed: bool = false
	for source: Dictionary in _vision_sources:
		exploration_changed = _mark_source_explored(source) or exploration_changed
	if exploration_changed:
		_upload_exploration_texture()
	visible = not _full_vision
	queue_redraw()

func is_cell_explored(cell: Vector2i) -> bool:
	if not _is_cell_in_bounds(cell) or _explored_cells.is_empty():
		return false
	return _explored_cells[_cell_index(cell)] != 0

func is_world_position_explored(world_position: Vector2) -> bool:
	return is_cell_explored(Vector2i(floori(world_position.x / float(_tile_size)), floori(world_position.y / float(_tile_size))))

func is_cell_rect_explored(cell_rect: Rect2i) -> bool:
	var clipped: Rect2i = cell_rect.intersection(Rect2i(Vector2i.ZERO, _map_size_tiles))
	for y: int in range(clipped.position.y, clipped.end.y):
		for x: int in range(clipped.position.x, clipped.end.x):
			if is_cell_explored(Vector2i(x, y)):
				return true
	return false

func get_exploration_texture() -> Texture2D:
	return _exploration_texture

func is_full_vision_enabled() -> bool:
	return _full_vision

func get_map_size_tiles() -> Vector2i:
	return _map_size_tiles

func is_world_position_visible(world_position: Vector2) -> bool:
	if _full_vision:
		return true
	return _is_cell_visible(Vector2i(floori(world_position.x / float(_tile_size)), floori(world_position.y / float(_tile_size))))

func is_world_rect_visible(cell_rect: Rect2i) -> bool:
	if _full_vision:
		return true
	for y: int in range(cell_rect.position.y, cell_rect.end.y):
		for x: int in range(cell_rect.position.x, cell_rect.end.x):
			if _is_cell_visible(Vector2i(x, y)):
				return true
	return false

func _draw() -> void:
	if _full_vision:
		return
	# Draw only cells currently on screen. On large configured maps this keeps fog work
	# proportional to the viewport instead of the million-cell world size.
	var inverse_canvas: Transform2D = get_viewport().get_canvas_transform().affine_inverse()
	var viewport_size: Vector2 = get_viewport_rect().size
	var world_a: Vector2 = inverse_canvas * Vector2.ZERO
	var world_b: Vector2 = inverse_canvas * viewport_size
	var first: Vector2i = Vector2i(
		clampi(floori(minf(world_a.x, world_b.x) / float(_tile_size)) - 1, 0, _map_size_tiles.x - 1),
		clampi(floori(minf(world_a.y, world_b.y) / float(_tile_size)) - 1, 0, _map_size_tiles.y - 1)
	)
	var last: Vector2i = Vector2i(
		clampi(ceili(maxf(world_a.x, world_b.x) / float(_tile_size)) + 1, 0, _map_size_tiles.x - 1),
		clampi(ceili(maxf(world_a.y, world_b.y) / float(_tile_size)) + 1, 0, _map_size_tiles.y - 1)
	)
	for y: int in range(first.y, last.y + 1):
		for x: int in range(first.x, last.x + 1):
			var cell: Vector2i = Vector2i(x, y)
			if not _is_cell_visible(cell):
				draw_rect(Rect2(Vector2(cell * _tile_size), Vector2(_tile_size, _tile_size)), FOG_COLOR, true)

func _is_cell_visible(cell: Vector2i) -> bool:
	for territory: Rect2i in _owned_territories:
		if territory.has_point(cell):
			return true
	var cell_center: Vector2 = Vector2(cell * _tile_size) + Vector2.ONE * float(_tile_size) * 0.5
	for source: Dictionary in _vision_sources:
		var source_position: Vector2 = source.get("position", Vector2.ZERO) as Vector2
		var radius: float = float(source.get("radius", 0.0))
		if source_position.distance_squared_to(cell_center) <= radius * radius:
			return true
	return false

func _reset_exploration() -> void:
	var cell_count: int = maxi(0, _map_size_tiles.x * _map_size_tiles.y)
	_explored_cells.resize(cell_count)
	_explored_cells.fill(0)
	_exploration_image = Image.create(_map_size_tiles.x, _map_size_tiles.y, false, Image.FORMAT_RGBA8)
	_exploration_image.fill(Color.TRANSPARENT)
	_exploration_texture = ImageTexture.create_from_image(_exploration_image)

func _mark_owned_territories_explored() -> bool:
	var changed: bool = false
	for territory: Rect2i in _owned_territories:
		var clipped: Rect2i = territory.intersection(Rect2i(Vector2i.ZERO, _map_size_tiles))
		for y: int in range(clipped.position.y, clipped.end.y):
			for x: int in range(clipped.position.x, clipped.end.x):
				changed = _mark_cell_explored(Vector2i(x, y)) or changed
	return changed

func _mark_source_explored(source: Dictionary) -> bool:
	var source_position: Vector2 = source.get("position", Vector2.ZERO) as Vector2
	var radius: float = maxf(0.0, float(source.get("radius", 0.0)))
	var minimum_cell: Vector2i = Vector2i(
		clampi(floori((source_position.x - radius) / float(_tile_size)), 0, _map_size_tiles.x - 1),
		clampi(floori((source_position.y - radius) / float(_tile_size)), 0, _map_size_tiles.y - 1)
	)
	var maximum_cell: Vector2i = Vector2i(
		clampi(floori((source_position.x + radius) / float(_tile_size)), 0, _map_size_tiles.x - 1),
		clampi(floori((source_position.y + radius) / float(_tile_size)), 0, _map_size_tiles.y - 1)
	)
	var changed: bool = false
	var radius_squared: float = radius * radius
	for y: int in range(minimum_cell.y, maximum_cell.y + 1):
		for x: int in range(minimum_cell.x, maximum_cell.x + 1):
			var cell: Vector2i = Vector2i(x, y)
			var cell_center: Vector2 = Vector2(cell * _tile_size) + Vector2.ONE * float(_tile_size) * 0.5
			if source_position.distance_squared_to(cell_center) <= radius_squared:
				changed = _mark_cell_explored(cell) or changed
	return changed

func _mark_cell_explored(cell: Vector2i) -> bool:
	if not _is_cell_in_bounds(cell) or _explored_cells.is_empty():
		return false
	var index: int = _cell_index(cell)
	if _explored_cells[index] != 0:
		return false
	_explored_cells[index] = 1
	if _exploration_image != null:
		_exploration_image.set_pixelv(cell, Color("#55765f"))
	return true

func _upload_exploration_texture() -> void:
	if _exploration_image == null:
		return
	if _exploration_texture == null:
		_exploration_texture = ImageTexture.create_from_image(_exploration_image)
	else:
		_exploration_texture.update(_exploration_image)

func _is_cell_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _map_size_tiles.x and cell.y < _map_size_tiles.y

func _cell_index(cell: Vector2i) -> int:
	return cell.y * _map_size_tiles.x + cell.x

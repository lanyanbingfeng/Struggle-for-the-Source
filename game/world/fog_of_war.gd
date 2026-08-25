class_name FogOfWar
extends Node2D

const FOG_COLOR: Color = Color(0.02, 0.035, 0.035, 0.46)

var _map_size_tiles: Vector2i = Vector2i(1000, 1000)
var _tile_size: int = 32
var _owned_territories: Array[Rect2i] = []
var _vision_sources: Array[Dictionary] = []
var _full_vision: bool = false

func _ready() -> void:
	z_index = 1000
	show_behind_parent = false

func configure(map_size_tiles: Vector2i, tile_size: int, owned_territory: Rect2i) -> void:
	_map_size_tiles = map_size_tiles
	_tile_size = tile_size
	_owned_territories = [owned_territory]
	queue_redraw()

func set_owned_territories(territories: Array[Rect2i]) -> void:
	_owned_territories = territories.duplicate()
	queue_redraw()

func update_visibility(vision_sources: Array[Dictionary], full_vision: bool) -> void:
	_vision_sources = vision_sources
	_full_vision = full_vision
	visible = not _full_vision
	queue_redraw()

func is_world_position_visible(world_position: Vector2) -> bool:
	if _full_vision:
		return true
	return _is_cell_visible(Vector2i(floori(world_position.x / float(_tile_size)), floori(world_position.y / float(_tile_size))))

func _draw() -> void:
	if _full_vision:
		return
	# Draw only cells currently on screen. On a 1000×1000 map this keeps fog work
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

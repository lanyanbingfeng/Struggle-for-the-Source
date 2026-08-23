@tool
extends Node2D

const GRID_SIZE: int = 100
const TILE_SIZE: int = 32
const BASE_ACTION_ORIGIN_OFFSET: Vector2 = Vector2(0, 0)

@onready var ground_layer: TileMapLayer = $Ground
@onready var base: Sprite2D = $Base
@onready var base_interaction: BaseInteraction = $BaseInteraction
@onready var base_action_menu: BaseActionMenu = $BaseActionMenu
@onready var map_camera: Camera2D = $MapCamera

func _ready() -> void:
	_build_ground_tileset()
	_fill_ground()
	base.position = _map_center()
	base_interaction.position = base.position
	map_camera.set("map_size", Vector2(GRID_SIZE * TILE_SIZE, GRID_SIZE * TILE_SIZE))
	map_camera.position = _map_center()
	base_interaction.selected.connect(_on_base_selected)
	base_action_menu.action_selected.connect(_on_base_action_selected)

func _build_ground_tileset() -> void:
	var grass_texture: Texture2D = load("res://art/ground/tile_grass_a.png")
	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	var atlas: TileSetAtlasSource = TileSetAtlasSource.new()
	atlas.texture = grass_texture
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	atlas.create_tile(Vector2i.ZERO)
	tile_set.add_source(atlas, 0)
	ground_layer.tile_set = tile_set

func _fill_ground() -> void:
	for y in GRID_SIZE:
		for x in GRID_SIZE:
			ground_layer.set_cell(Vector2i(x, y), 0, Vector2i.ZERO, 0)

func _map_center() -> Vector2:
	return Vector2(GRID_SIZE * TILE_SIZE / 2.0, GRID_SIZE * TILE_SIZE / 2.0)

func _on_base_selected(screen_position: Vector2) -> void:
	base_action_menu.toggle_at(screen_position + BASE_ACTION_ORIGIN_OFFSET)

func _on_base_action_selected(action_id: StringName) -> void:
	print("地图收到基地操作: ", action_id)

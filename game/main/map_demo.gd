@tool
extends Node2D

const GRID_SIZE: int = 100
const TILE_SIZE: int = 32
const TREE_COUNT: int = 80
const TREE_MARGIN_TILES: int = 5
const BASE_ACTION_ORIGIN_OFFSET: Vector2 = Vector2(0, 0)
const MACHINE_SPAWN_OFFSET: Vector2 = Vector2(0, 64)
const TREE_SCENE: PackedScene = preload("res://game/world/tree.tscn")
const LUMBER_MACHINE_SCENE: PackedScene = preload("res://game/units/lumber_machine.tscn")

@onready var ground_layer: TileMapLayer = $Ground
@onready var base: Sprite2D = $Base
@onready var base_interaction: Area2D = $BaseInteraction
@onready var base_action_menu: BaseActionMenu = $BaseActionMenu
@onready var map_camera: Camera2D = $MapCamera
@onready var tree_container: Node2D = $Trees
@onready var unit_container: Node2D = $Units
@onready var resource_manager: Node = $ResourceManager
@onready var resource_hud: CanvasLayer = $ResourceHUD
@onready var main_menu: CanvasLayer = $MainMenu
@onready var pause_menu: CanvasLayer = $PauseMenu

var _lumber_machine: Node2D
var _multiplayer_mode: bool = false
var _game_started: bool = false

func _ready() -> void:
	_build_ground_tileset()
	_fill_ground()
	base.position = _map_center()
	base_interaction.position = base.position
	_spawn_trees()
	map_camera.set("map_size", Vector2(GRID_SIZE * TILE_SIZE, GRID_SIZE * TILE_SIZE))
	map_camera.position = _map_center()
	if Engine.is_editor_hint():
		return
	resource_hud.call(&"bind", resource_manager)
	base_interaction.connect(&"selected", _on_base_selected)
	base_action_menu.action_selected.connect(_on_base_action_selected)
	main_menu.start_requested.connect(_on_start_requested)
	pause_menu.return_to_main_menu.connect(_on_return_to_main_menu)
	_show_main_menu()

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

func _spawn_trees() -> void:
	for child: Node in tree_container.get_children():
		child.free()
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 20260823
	var used_cells: Dictionary = {}
	var created_count: int = 0
	while created_count < TREE_COUNT:
		var cell: Vector2i = Vector2i(random.randi_range(1, GRID_SIZE - 2), random.randi_range(1, GRID_SIZE - 2))
		if used_cells.has(cell) or _is_near_base(cell):
			continue
		used_cells[cell] = true
		var tree: Node2D = TREE_SCENE.instantiate() as Node2D
		tree.position = Vector2(cell.x * TILE_SIZE + TILE_SIZE / 2.0, (cell.y + 1) * TILE_SIZE)
		tree_container.add_child(tree)
		tree.connect(&"felled", _on_tree_felled)
		created_count += 1

func _is_near_base(cell: Vector2i) -> bool:
	var base_cell: Vector2i = Vector2i(GRID_SIZE >> 1, GRID_SIZE >> 1)
	return abs(cell.x - base_cell.x) <= TREE_MARGIN_TILES and abs(cell.y - base_cell.y) <= TREE_MARGIN_TILES

func _on_base_selected(screen_position: Vector2) -> void:
	if not _game_started:
		return
	base_action_menu.toggle_at(screen_position + BASE_ACTION_ORIGIN_OFFSET)

func _on_base_action_selected(action_id: StringName) -> void:
	match action_id:
		&"recruit":
			_recruit_lumber_machine()
		&"summon", &"upgrade":
			print("地图收到基地操作: ", action_id)

func _on_start_requested(multiplayer_mode: bool) -> void:
	_multiplayer_mode = multiplayer_mode
	_reset_game_state()
	_game_started = true
	main_menu.hide()
	pause_menu.show()
	pause_menu.configure(_multiplayer_mode)
	pause_menu.force_close()
	resource_hud.show()
	get_tree().paused = false

func _on_return_to_main_menu() -> void:
	_show_main_menu()

func _show_main_menu() -> void:
	_game_started = false
	base_action_menu.close()
	pause_menu.force_close()
	pause_menu.hide()
	resource_hud.hide()
	main_menu.show()
	get_tree().paused = true

func _reset_game_state() -> void:
	if is_instance_valid(_lumber_machine):
		_lumber_machine.free()
	_lumber_machine = null
	for child: Node in unit_container.get_children():
		child.free()
	_spawn_trees()
	resource_manager.call(&"reset_development_state")
	base_action_menu.close()
	map_camera.position = _map_center()

func _recruit_lumber_machine() -> void:
	if is_instance_valid(_lumber_machine):
		print("伐木机器已在地图中")
		return
	_lumber_machine = LUMBER_MACHINE_SCENE.instantiate() as Node2D
	_lumber_machine.position = base.position + MACHINE_SPAWN_OFFSET
	unit_container.add_child(_lumber_machine)
	_lumber_machine.call(&"setup", tree_container)
	print("已招募伐木机器，开始自动寻找树木")

func _on_tree_felled(_tree: Node2D) -> void:
	resource_manager.call(&"apply_tree_harvest")

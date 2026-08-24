@tool
extends Node2D

const GRID_SIZE: int = 100
const TILE_SIZE: int = 32
const TERRITORY_SIZE: int = 20
const ACTIVE_PLAYER_ID: int = 1
const BASE_ACTION_ORIGIN_OFFSET: Vector2 = Vector2(0, 0)
const TEST_OVERVIEW_ZOOM: Vector2 = Vector2(0.75, 0.75)
const TREE_SCENE: PackedScene = preload("res://game/world/tree.tscn")
const STONE_SCENE: PackedScene = preload("res://game/world/stone.tscn")
const TERRITORY_SCENE: PackedScene = preload("res://game/world/player_territory.tscn")
const LUMBER_MACHINE_SCENE: PackedScene = preload("res://game/units/lumber_machine.tscn")
const QUARRY_MACHINE_SCENE: PackedScene = preload("res://game/units/quarry_machine.tscn")
const TERRITORY_ORIGINS: Array[Vector2i] = [Vector2i(15, 40), Vector2i(37, 40)]
const TERRITORY_COLORS: Array[Color] = [Color("#65b8ff"), Color("#ff8b72")]
const FAIR_TREE_CELLS: Array[Vector2i] = [
	Vector2i(2, 2), Vector2i(5, 3), Vector2i(8, 2), Vector2i(13, 3),
	Vector2i(17, 2), Vector2i(3, 7), Vector2i(16, 7), Vector2i(2, 12),
	Vector2i(17, 12), Vector2i(4, 16), Vector2i(9, 17), Vector2i(15, 16),
]
const FAIR_STONE_CELLS: Array[Vector2i] = [
	Vector2i(3, 4), Vector2i(10, 3), Vector2i(16, 4), Vector2i(5, 9),
	Vector2i(15, 10), Vector2i(3, 15), Vector2i(11, 15), Vector2i(17, 16),
]
const RICH_TREE_BONUS_CELLS: Array[Vector2i] = [
	Vector2i(11, 6), Vector2i(7, 10), Vector2i(13, 13), Vector2i(7, 15),
]
const RICH_STONE_BONUS_CELLS: Array[Vector2i] = [
	Vector2i(7, 5), Vector2i(12, 9), Vector2i(7, 13), Vector2i(15, 15),
]
const RESOURCE_SCARCE: int = 0
const RESOURCE_STANDARD: int = 1
const RESOURCE_RICH: int = 2

@onready var ground_layer: TileMapLayer = $Ground
@onready var base: Sprite2D = $Base
@onready var base_interaction: Area2D = $BaseInteraction
@onready var base_action_menu: BaseActionMenu = $BaseActionMenu
@onready var map_camera: Camera2D = $MapCamera
@onready var territory_container: Node2D = $Territories
@onready var test_base_container: Node2D = $TestBases
@onready var tree_container: Node2D = $Trees
@onready var stone_container: Node2D = $Stones
@onready var unit_container: Node2D = $Units
@onready var resource_manager: Node = $ResourceManager
@onready var lan_session: Node = $LanSession
@onready var resource_hud: CanvasLayer = $ResourceHUD
@onready var main_menu: MainMenu = $MainMenu
@onready var lan_lobby: CanvasLayer = $LanLobby
@onready var pause_menu: CanvasLayer = $PauseMenu

var _territory_rects: Array[Rect2i] = []
var _recruit_counts: Dictionary[StringName, int] = {}
var _recruit_sequence: int = 0
var _multiplayer_mode: bool = false
var _game_started: bool = false
var _multiplayer_snapshot: Dictionary = {}
var _resource_abundance: int = RESOURCE_STANDARD

func _ready() -> void:
	_build_ground_tileset()
	_fill_ground()
	_setup_test_territories()
	base.position = _territory_base_position(0)
	base_interaction.position = base.position
	_spawn_fair_resources()
	map_camera.set("map_size", Vector2(GRID_SIZE * TILE_SIZE, GRID_SIZE * TILE_SIZE))
	map_camera.zoom = TEST_OVERVIEW_ZOOM
	map_camera.position = _territory_overview_position()
	if Engine.is_editor_hint():
		return
	resource_hud.call(&"bind", resource_manager)
	base_interaction.connect(&"selected", _on_base_selected)
	base_action_menu.action_selected.connect(_on_base_action_selected)
	main_menu.start_requested.connect(_on_start_requested)
	main_menu.multiplayer_requested.connect(_on_multiplayer_requested)
	lan_lobby.call(&"bind", lan_session)
	lan_lobby.connect(&"back_requested", _on_lobby_back_requested)
	lan_lobby.connect(&"game_start_requested", _on_multiplayer_game_start_requested)
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

func _setup_test_territories() -> void:
	_territory_rects.clear()
	for territory_index: int in TERRITORY_ORIGINS.size():
		var rect: Rect2i = Rect2i(TERRITORY_ORIGINS[territory_index], Vector2i(TERRITORY_SIZE, TERRITORY_SIZE))
		_territory_rects.append(rect)
		var territory: Node2D = _get_or_create_territory(territory_index)
		territory.call(&"configure", territory_index + 1, rect, TERRITORY_COLORS[territory_index])
		if territory_index == 0:
			continue
		var test_base: Sprite2D = _get_or_create_test_base(territory_index - 1)
		test_base.texture = base.texture
		test_base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		test_base.position = _territory_base_position(territory_index)
		test_base.modulate = TERRITORY_COLORS[territory_index].lightened(0.2)

func _get_or_create_territory(territory_index: int) -> Node2D:
	if territory_index < territory_container.get_child_count():
		return territory_container.get_child(territory_index) as Node2D
	var territory: Node2D = TERRITORY_SCENE.instantiate() as Node2D
	territory.name = "Player%dTerritory" % (territory_index + 1)
	territory_container.add_child(territory)
	if Engine.is_editor_hint():
		territory.owner = self
	return territory

func _get_or_create_test_base(base_index: int) -> Sprite2D:
	if base_index < test_base_container.get_child_count():
		return test_base_container.get_child(base_index) as Sprite2D
	var test_base: Sprite2D = Sprite2D.new()
	test_base.name = "TestBase%d" % (base_index + 2)
	test_base_container.add_child(test_base)
	if Engine.is_editor_hint():
		test_base.owner = self
	return test_base

func _spawn_fair_resources() -> void:
	_clear_children(tree_container)
	_clear_children(stone_container)
	var tree_cells: Array[Vector2i] = _get_tree_cells_for_abundance()
	var stone_cells: Array[Vector2i] = _get_stone_cells_for_abundance()
	for territory_index: int in _territory_rects.size():
		var territory_id: int = territory_index + 1
		var origin: Vector2i = _territory_rects[territory_index].position
		for local_cell: Vector2i in tree_cells:
			var tree: Node2D = TREE_SCENE.instantiate() as Node2D
			tree.set("territory_id", territory_id)
			tree.position = _resource_world_position(origin + local_cell)
			tree_container.add_child(tree)
			tree.connect(&"felled", _on_tree_felled)
		for local_cell: Vector2i in stone_cells:
			var stone: Node2D = STONE_SCENE.instantiate() as Node2D
			stone.set("territory_id", territory_id)
			stone.position = _resource_world_position(origin + local_cell)
			stone_container.add_child(stone)
			stone.connect(&"depleted", _on_stone_depleted)

func _get_tree_cells_for_abundance() -> Array[Vector2i]:
	if _resource_abundance == RESOURCE_SCARCE:
		return FAIR_TREE_CELLS.slice(0, 8)
	var cells: Array[Vector2i] = FAIR_TREE_CELLS.duplicate()
	if _resource_abundance == RESOURCE_RICH:
		cells.append_array(RICH_TREE_BONUS_CELLS)
	return cells

func _get_stone_cells_for_abundance() -> Array[Vector2i]:
	if _resource_abundance == RESOURCE_SCARCE:
		return FAIR_STONE_CELLS.slice(0, 5)
	var cells: Array[Vector2i] = FAIR_STONE_CELLS.duplicate()
	if _resource_abundance == RESOURCE_RICH:
		cells.append_array(RICH_STONE_BONUS_CELLS)
	return cells

func _clear_children(container: Node) -> void:
	for child: Node in container.get_children():
		child.free()

func _resource_world_position(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_SIZE + TILE_SIZE / 2.0, (cell.y + 1) * TILE_SIZE)

func _territory_base_position(territory_index: int) -> Vector2:
	var rect: Rect2i = _territory_rects[territory_index]
	var half_size: int = TERRITORY_SIZE >> 1
	var center_cell: Vector2i = rect.position + Vector2i(half_size, half_size)
	return Vector2(center_cell.x * TILE_SIZE + TILE_SIZE / 2.0, center_cell.y * TILE_SIZE + TILE_SIZE / 2.0)

func _territory_overview_position() -> Vector2:
	if _territory_rects.is_empty():
		return _map_center()
	var position_sum: Vector2 = Vector2.ZERO
	for territory_index: int in _territory_rects.size():
		position_sum += _territory_base_position(territory_index)
	return position_sum / float(_territory_rects.size())

func _on_base_selected(screen_position: Vector2) -> void:
	if not _game_started:
		return
	base_action_menu.toggle_at(screen_position + BASE_ACTION_ORIGIN_OFFSET)

func _on_base_action_selected(action_id: StringName) -> void:
	match action_id:
		&"recruit_lumber":
			_recruit_unit(&"lumber", LUMBER_MACHINE_SCENE, tree_container)
		&"recruit_quarry":
			_recruit_unit(&"quarry", QUARRY_MACHINE_SCENE, stone_container)
		&"summon", &"upgrade":
			print("地图收到基地操作: ", action_id)

func _on_start_requested(multiplayer_mode: bool) -> void:
	_multiplayer_mode = multiplayer_mode
	if not multiplayer_mode:
		_multiplayer_snapshot.clear()
		_resource_abundance = RESOURCE_STANDARD
	_reset_game_state()
	_game_started = true
	main_menu.hide()
	lan_lobby.call(&"close_lobby", false)
	pause_menu.show()
	pause_menu.configure(_multiplayer_mode)
	pause_menu.force_close()
	resource_hud.show()
	get_tree().paused = false

func _on_multiplayer_requested() -> void:
	main_menu.hide()
	pause_menu.hide()
	resource_hud.hide()
	lan_lobby.call(&"open")
	get_tree().paused = true

func _on_lobby_back_requested() -> void:
	main_menu.show()
	get_tree().paused = true

func _on_multiplayer_game_start_requested(snapshot: Dictionary) -> void:
	_multiplayer_snapshot = snapshot.duplicate(true)
	var settings: Dictionary = snapshot.get("settings", {}) as Dictionary
	_resource_abundance = clampi(int(settings.get("resource_abundance", RESOURCE_STANDARD)), RESOURCE_SCARCE, RESOURCE_RICH)
	_on_start_requested(true)

func _on_return_to_main_menu() -> void:
	_show_main_menu()

func _show_main_menu() -> void:
	_game_started = false
	_multiplayer_snapshot.clear()
	_resource_abundance = RESOURCE_STANDARD
	base_action_menu.close()
	pause_menu.force_close()
	pause_menu.hide()
	resource_hud.hide()
	lan_lobby.call(&"close_lobby", true)
	main_menu.show()
	get_tree().paused = true

func _reset_game_state() -> void:
	_clear_children(unit_container)
	_recruit_counts.clear()
	_recruit_sequence = 0
	_spawn_fair_resources()
	resource_manager.call(&"reset_development_state")
	base_action_menu.close()
	map_camera.zoom = TEST_OVERVIEW_ZOOM
	map_camera.position = _territory_overview_position()

func _recruit_unit(unit_type: StringName, unit_scene: PackedScene, resource_container: Node2D) -> void:
	var recruited_count: int = int(_recruit_counts.get(unit_type, 0))
	var unit: Node2D = unit_scene.instantiate() as Node2D
	unit.position = _machine_spawn_position(_recruit_sequence)
	unit_container.add_child(unit)
	unit.call(&"setup", resource_container, ACTIVE_PLAYER_ID)
	_recruit_counts[unit_type] = recruited_count + 1
	_recruit_sequence += 1
	print("已招募", unit_type, "机器 #", recruited_count + 1)

func _machine_spawn_position(recruited_count: int) -> Vector2:
	var column: int = recruited_count % 3
	var row: int = floori(float(recruited_count) / 3.0)
	return base.position + Vector2(float(column - 1) * 24.0, 64.0 + float(row) * 24.0)

func _on_tree_felled(_tree: Node2D) -> void:
	resource_manager.call(&"apply_tree_harvest")

func _on_stone_depleted(_stone: Node2D) -> void:
	resource_manager.call(&"apply_stone_harvest")

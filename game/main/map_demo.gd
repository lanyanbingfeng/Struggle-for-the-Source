@tool
extends Node2D

const MachineProgressionData: Script = preload("res://game/data/machine_progression.gd")
const WORLD_RESOURCE_MARKER_SCRIPT: Script = preload("res://game/world/world_resource_marker.gd")
const HEALTH_COMPONENT_SCRIPT: Script = preload("res://game/systems/health_component.gd")
const HEALTH_BAR_SCRIPT: Script = preload("res://game/ui/health_bar_2d.gd")

const GRID_SIZE: int = 1000
const TILE_SIZE: int = 32
const TERRITORY_SIZE: int = 20
const TERRITORY_GRID_COLUMNS: int = 4
const TERRITORY_GRID_MARGIN: int = 60
const TERRITORY_GRID_STRIDE: int = 36
const MAX_TERRITORIES: int = 64
const BASE_ACTION_ORIGIN_OFFSET: Vector2 = Vector2.ZERO
const LOCAL_TERRITORY_ZOOM: Vector2 = Vector2(0.8, 0.8)
const TEST_OVERVIEW_ZOOM: Vector2 = Vector2(0.75, 0.75)
const UNIT_STATE_INTERVAL: float = 0.1
const FOG_UPDATE_INTERVAL: float = 0.15
const DRAG_THRESHOLD_PIXELS: float = 7.0
const EXPLORER_BUILD_ZOOM: Vector2 = Vector2(0.42, 0.42)
const TREE_SCENE: PackedScene = preload("res://game/world/tree.tscn")
const STONE_SCENE: PackedScene = preload("res://game/world/stone.tscn")
const IRON_DEPOSIT_SCENE: PackedScene = preload("res://game/world/iron_deposit.tscn")
const GOLD_DEPOSIT_SCENE: PackedScene = preload("res://game/world/gold_deposit.tscn")
const DIAMOND_DEPOSIT_SCENE: PackedScene = preload("res://game/world/diamond_deposit.tscn")
const TERRITORY_SCENE: PackedScene = preload("res://game/world/player_territory.tscn")
const PLAYER_BASE_SCENE: PackedScene = preload("res://game/world/player_base.tscn")
const PRODUCTION_BUILDING_SCENE: PackedScene = preload("res://game/world/production_building.tscn")
const UNIT_CATALOG: UnitCatalog = preload("res://game/data/unit_catalog.tres")
const BUILDING_CATALOG: BuildingCatalog = preload("res://game/data/building_catalog.tres")
const TERRITORY_COLORS: Array[Color] = [
	Color("#65b8ff"), Color("#ff8b72"), Color("#8bd17c"), Color("#d49bff"),
	Color("#ffd166"), Color("#63d6c6"), Color("#ff7eb6"), Color("#a7b7ff"),
]
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
const DEVELOPMENT_GOLD: int = 9999
const TREE_WOOD_REWARD: int = 10
const TREE_GOLD_COST: int = 1
const STONE_REWARD: int = 8
const STONE_GOLD_COST: int = 1
const MINERAL_GOLD_COST: int = 1
const MINERAL_REWARDS: Dictionary = {&"iron": 6, &"gold_ore": 3, &"diamond": 1}

@onready var ground_layer: TileMapLayer = $Ground
@onready var legacy_base: Sprite2D = $Base
@onready var legacy_base_interaction: Area2D = $BaseInteraction
@onready var base_action_menu: BaseActionMenu = $BaseActionMenu
@onready var map_camera: Camera2D = $MapCamera
@onready var territory_container: Node2D = $Territories
@onready var legacy_test_base_container: Node2D = $TestBases
@onready var base_container: Node2D = $Bases
@onready var building_container: Node2D = $Buildings
@onready var tree_container: Node2D = $Trees
@onready var mineable_container: Node2D = $Mineables
@onready var stone_container: Node2D = $Mineables/Stones
@onready var rare_mineral_container: Node2D = $Mineables/RareMinerals
@onready var unit_container: Node2D = $Units
@onready var fog_of_war: FogOfWar = $FogOfWar
@onready var command_overlay: WorldCommandOverlay = $WorldCommandOverlay
@onready var world_pathfinder: WorldPathfinder = $WorldPathfinder
@onready var world_resource_streamer: Node = $WorldResourceStreamer
@onready var resource_manager: Node = $ResourceManager
@onready var lan_session: Node = $LanSession
@onready var resource_hud: CanvasLayer = $ResourceHUD
@onready var developer_panel: DeveloperPanel = $DeveloperPanel
@onready var unit_command_panel: UnitCommandPanel = $UnitCommandPanel
@onready var ai_controller: SimpleAIController = $SimpleAIController
@onready var summon_card_menu: SummonCardMenu = $SummonCardMenu
@onready var main_menu: MainMenu = $MainMenu
@onready var lan_lobby: CanvasLayer = $LanLobby
@onready var pause_menu: CanvasLayer = $PauseMenu

var _territory_rects: Array[Rect2i] = []
var _territory_owner_by_id: Dictionary[int, int] = {}
var _player_by_peer_id: Dictionary[int, Dictionary] = {}
var _network_units: Dictionary[int, Node2D] = {}
var _network_buildings: Dictionary[int, ProductionBuilding] = {}
var _selected_unit_ids: Array[int] = []
var _spawn_sequence_by_peer: Dictionary[int, int] = {}
var _player_resource_states: Dictionary[int, Dictionary] = {}
var _base_level_by_peer_id: Dictionary[int, int] = {}
var _player_base_by_peer_id: Dictionary[int, PlayerBase] = {}
var _player_base_by_territory_id: Dictionary[int, PlayerBase] = {}
var _pending_summon_by_peer_id: Dictionary[int, Dictionary] = {}
var _next_network_unit_id: int = 1
var _next_network_building_id: int = 1
var _next_summon_offer_id: int = 1
var _local_peer_id: int = 1
var _local_territory_id: int = 1
var _active_player_base: PlayerBase
var _multiplayer_mode: bool = false
var _game_started: bool = false
var _multiplayer_snapshot: Dictionary = {}
var _resource_abundance: int = RESOURCE_STANDARD
var _resource_seed: int = 1
var _full_vision: bool = false
var _dragging_selection: bool = false
var _drag_start_screen: Vector2 = Vector2.ZERO
var _unit_state_elapsed: float = 0.0
var _fog_elapsed: float = 0.0
var _navigation_rebuild_pending: bool = false
var _card_menu_mode: StringName = &""
var _active_summon_offer_id: int = 0
var _summon_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _ai_peer_id: int = 0
var _ai_expansion_started: bool = false
var _build_preview_unit_id: int = 0
var _build_preview_rect: Rect2i = Rect2i()
var _structure_preview_unit_id: int = 0
var _structure_preview_building_id: StringName = &""
var _structure_preview_rect: Rect2i = Rect2i()
var _preview_camera_position: Vector2 = Vector2.ZERO
var _preview_camera_zoom: Vector2 = Vector2.ONE

func _ready() -> void:
	_build_ground_tileset()
	_fill_ground()
	_setup_territories(2)
	_setup_legacy_editor_bases()
	world_resource_streamer.call(&"configure", GRID_SIZE, TILE_SIZE, tree_container, stone_container, rare_mineral_container)
	map_camera.set("map_size", Vector2(GRID_SIZE * TILE_SIZE, GRID_SIZE * TILE_SIZE))
	map_camera.zoom = TEST_OVERVIEW_ZOOM
	map_camera.position = _territory_overview_position()
	if Engine.is_editor_hint():
		_spawn_fair_resources()
		return
	world_pathfinder.configure(Vector2i(GRID_SIZE, GRID_SIZE), TILE_SIZE)
	_rebuild_navigation_obstacles()
	legacy_base.hide()
	legacy_base_interaction.input_pickable = false
	legacy_test_base_container.hide()
	fog_of_war.hide()
	resource_hud.call(&"bind", resource_manager)
	base_action_menu.action_selected.connect(_on_base_action_selected)
	summon_card_menu.unit_selected.connect(_on_summon_card_selected)
	developer_panel.full_vision_changed.connect(_on_full_vision_changed)
	developer_panel.ai_paused_changed.connect(_on_ai_paused_changed)
	unit_command_panel.work_toggled.connect(_on_machine_work_toggled)
	unit_command_panel.upgrade_requested.connect(_on_machine_upgrade_requested)
	unit_command_panel.build_preview_requested.connect(_on_build_preview_requested)
	unit_command_panel.build_confirmed.connect(_on_build_confirmed)
	unit_command_panel.build_cancelled.connect(_cancel_build_preview)
	unit_command_panel.structure_preview_requested.connect(_on_structure_preview_requested)
	unit_command_panel.structure_confirmed.connect(_on_structure_confirmed)
	unit_command_panel.structure_cancelled.connect(_cancel_structure_preview)
	ai_controller.think_requested.connect(_on_ai_think)
	main_menu.start_requested.connect(_on_start_requested)
	main_menu.multiplayer_requested.connect(_on_multiplayer_requested)
	lan_lobby.call(&"bind", lan_session)
	lan_lobby.connect(&"back_requested", _on_lobby_back_requested)
	lan_lobby.connect(&"game_start_requested", _on_multiplayer_game_start_requested)
	pause_menu.return_to_main_menu.connect(_on_return_to_main_menu)
	_show_main_menu()

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not _game_started:
		return
	if bool(world_resource_streamer.call(&"update_streaming", map_camera.position)):
		_refresh_entity_visibility()
	if _has_gameplay_authority():
		_unit_state_elapsed += delta
		if _multiplayer_mode and _unit_state_elapsed >= UNIT_STATE_INTERVAL:
			_unit_state_elapsed = 0.0
			_broadcast_unit_states()
	_fog_elapsed += delta
	if _fog_elapsed >= FOG_UPDATE_INTERVAL:
		_fog_elapsed = 0.0
		_refresh_fog()

func _unhandled_input(event: InputEvent) -> void:
	if not _game_started:
		return
	if event is InputEventMouseMotion and _dragging_selection:
		command_overlay.update_drag(get_global_mouse_position())
		return
	if event is not InputEventMouseButton:
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		_handle_left_mouse(mouse_event)
	elif mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
		_handle_move_command(get_global_mouse_position())

func _handle_left_mouse(event: InputEventMouseButton) -> void:
	if event.pressed:
		if _pointer_is_over_blocking_ui():
			return
		_dragging_selection = true
		_drag_start_screen = event.position
		command_overlay.begin_drag(get_global_mouse_position())
		return
	if not _dragging_selection:
		return
	_dragging_selection = false
	var selection_rect: Rect2 = command_overlay.end_drag()
	if event.position.distance_to(_drag_start_screen) < DRAG_THRESHOLD_PIXELS:
		_select_single_unit(get_global_mouse_position())
	else:
		_select_units_in_rect(selection_rect)

func _handle_move_command(target_position: Vector2) -> void:
	if _selected_unit_ids.is_empty() or _pointer_is_over_blocking_ui():
		return
	command_overlay.show_move_marker(target_position)
	if _has_gameplay_authority():
		_server_move_units(_local_peer_id, _selected_unit_ids, target_position)
	else:
		_rpc_request_move_units.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, _selected_unit_ids, target_position)

func _pointer_is_over_blocking_ui() -> bool:
	var hovered: Control = get_viewport().gui_get_hovered_control()
	return hovered != null and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE

func _build_ground_tileset() -> void:
	ground_layer.clear()
	ground_layer.tile_set = null

func _fill_ground() -> void:
	var existing: Sprite2D = ground_layer.get_node_or_null("RepeatedGrass") as Sprite2D
	if existing == null:
		existing = Sprite2D.new()
		existing.name = "RepeatedGrass"
		ground_layer.add_child(existing)
	existing.texture = load("res://art/ground/tile_grass_a.png")
	existing.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	existing.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	existing.centered = false
	existing.region_enabled = true
	existing.region_rect = Rect2(Vector2.ZERO, Vector2(GRID_SIZE * TILE_SIZE, GRID_SIZE * TILE_SIZE))

func _setup_territories(territory_count: int) -> void:
	var clamped_count: int = clampi(territory_count, 2, MAX_TERRITORIES)
	_territory_rects.clear()
	for territory_index: int in clamped_count:
		var territory_id: int = territory_index + 1
		var rect: Rect2i = Rect2i(_territory_origin(territory_id), Vector2i(TERRITORY_SIZE, TERRITORY_SIZE))
		_territory_rects.append(rect)
		var territory: Node2D = _get_or_create_territory(territory_index)
		territory.show()
		territory.call(&"configure", territory_id, rect, _territory_color(territory_id))
	for index: int in range(clamped_count, territory_container.get_child_count()):
		territory_container.get_child(index).hide()

func _territory_origin(territory_id: int) -> Vector2i:
	var index: int = maxi(0, territory_id - 1)
	return Vector2i(
		TERRITORY_GRID_MARGIN + index % TERRITORY_GRID_COLUMNS * TERRITORY_GRID_STRIDE,
		TERRITORY_GRID_MARGIN + floori(float(index) / float(TERRITORY_GRID_COLUMNS)) * TERRITORY_GRID_STRIDE
	)

func _territory_color(territory_id: int) -> Color:
	return TERRITORY_COLORS[(territory_id - 1) % TERRITORY_COLORS.size()]

func _get_or_create_territory(territory_index: int) -> Node2D:
	if territory_index < territory_container.get_child_count():
		return territory_container.get_child(territory_index) as Node2D
	var territory: Node2D = TERRITORY_SCENE.instantiate() as Node2D
	territory.name = "Player%dTerritory" % (territory_index + 1)
	territory_container.add_child(territory)
	if Engine.is_editor_hint():
		territory.owner = self
	return territory

func _setup_legacy_editor_bases() -> void:
	legacy_base.position = _territory_base_position(1)
	legacy_base_interaction.position = legacy_base.position
	for base_index: int in range(1, _territory_rects.size()):
		var test_base: Sprite2D = _get_or_create_legacy_test_base(base_index - 1)
		test_base.texture = legacy_base.texture
		test_base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		test_base.position = _territory_base_position(base_index + 1)
		test_base.modulate = _territory_color(base_index + 1).lightened(0.2)

func _get_or_create_legacy_test_base(base_index: int) -> Sprite2D:
	if base_index < legacy_test_base_container.get_child_count():
		return legacy_test_base_container.get_child(base_index) as Sprite2D
	var test_base: Sprite2D = Sprite2D.new()
	test_base.name = "TestBase%d" % (base_index + 2)
	legacy_test_base_container.add_child(test_base)
	if Engine.is_editor_hint():
		test_base.owner = self
	return test_base

func _setup_runtime_players(snapshot: Dictionary) -> void:
	_player_by_peer_id.clear()
	_territory_owner_by_id.clear()
	_base_level_by_peer_id.clear()
	_ai_peer_id = 0
	var players: Array = snapshot.get("players", []) as Array
	var highest_territory_id: int = 2
	for player_index: int in players.size():
		var player: Dictionary = (players[player_index] as Dictionary).duplicate(true)
		var peer_id: int = int(player.get("peer_id", player_index + 1))
		var territory_id: int = int(player.get("territory_id", player_index + 1))
		player["territory_id"] = territory_id
		_player_by_peer_id[peer_id] = player
		_territory_owner_by_id[territory_id] = peer_id
		_base_level_by_peer_id[peer_id] = clampi(int(player.get("base_level", 1)), 1, BaseProgression.MAX_LEVEL)
		if bool(player.get("is_ai", false)):
			_ai_peer_id = peer_id
		highest_territory_id = maxi(highest_territory_id, territory_id)
	_setup_territories(highest_territory_id)
	_local_peer_id = int(lan_session.call(&"get_local_peer_id")) if _multiplayer_mode else 1
	if _local_peer_id <= 0:
		_local_peer_id = 1
	var local_player: Dictionary = _player_by_peer_id.get(_local_peer_id, {}) as Dictionary
	_local_territory_id = int(local_player.get("territory_id", 1))
	_setup_runtime_bases()

func _setup_runtime_bases() -> void:
	_clear_children(base_container)
	_player_base_by_peer_id.clear()
	_player_base_by_territory_id.clear()
	for peer_id: int in _player_by_peer_id.keys():
		var player: Dictionary = _player_by_peer_id[peer_id]
		var territory_id: int = int(player.get("territory_id", 1))
		var player_base: PlayerBase = PLAYER_BASE_SCENE.instantiate() as PlayerBase
		player_base.name = "PlayerBase_%d" % territory_id
		player_base.position = _territory_base_position(territory_id)
		base_container.add_child(player_base)
		player_base.configure(peer_id, territory_id, peer_id == _local_peer_id, _are_peers_hostile(_local_peer_id, peer_id))
		player_base.set_level(int(_base_level_by_peer_id.get(peer_id, 1)))
		_attach_vitals(player_base, peer_id, 1800.0, 45.0, 0.0, 0.0, 0.0, Vector2(0.0, -76.0), 58.0, &"base", territory_id)
		_player_base_by_peer_id[peer_id] = player_base
		_player_base_by_territory_id[territory_id] = player_base
		if peer_id == _local_peer_id:
			player_base.selected.connect(_on_player_base_selected)

func _spawn_fair_resources() -> void:
	world_resource_streamer.call(&"clear_all")
	_clear_children(tree_container)
	_clear_children(stone_container)
	_clear_children(rare_mineral_container)
	var tree_cells: Array[Vector2i] = _get_tree_cells_for_abundance()
	var stone_cells: Array[Vector2i] = _get_stone_cells_for_abundance()
	var mineral_layout: Array[Dictionary] = _build_rare_mineral_layout(tree_cells, stone_cells)
	for territory_index: int in _territory_rects.size():
		var territory_id: int = territory_index + 1
		var origin: Vector2i = _territory_rects[territory_index].position
		for resource_index: int in tree_cells.size():
			var tree: Node2D = TREE_SCENE.instantiate() as Node2D
			tree.name = "Tree_T%d_%02d" % [territory_id, resource_index]
			tree.set("territory_id", territory_id)
			tree.position = _resource_world_position(origin + tree_cells[resource_index])
			tree_container.add_child(tree)
			tree.connect(&"felled", _on_tree_felled)
		for resource_index: int in stone_cells.size():
			var stone: Node2D = STONE_SCENE.instantiate() as Node2D
			stone.name = "Stone_T%d_%02d" % [territory_id, resource_index]
			stone.set("territory_id", territory_id)
			stone.position = _resource_world_position(origin + stone_cells[resource_index])
			stone_container.add_child(stone)
			stone.connect(&"depleted", _on_stone_depleted)
		for resource_index: int in mineral_layout.size():
			var mineral_data: Dictionary = mineral_layout[resource_index]
			var resource_type: StringName = mineral_data.get("resource_type", &"iron") as StringName
			var mineral: Node2D = _mineral_scene_for(resource_type).instantiate() as Node2D
			mineral.name = "%s_T%d_%02d" % [str(resource_type).to_pascal_case(), territory_id, resource_index]
			mineral.territory_id = territory_id
			mineral.position = _resource_world_position(origin + (mineral_data.get("cell", Vector2i.ZERO) as Vector2i))
			mineral.connect(&"depleted", _on_mineral_depleted)
			rare_mineral_container.add_child(mineral)
	_spawn_world_resources()

func _spawn_world_resources() -> void:
	world_resource_streamer.call(&"regenerate", _resource_seed, _resource_abundance, _territory_rects)
	if Engine.is_editor_hint():
		world_resource_streamer.call(&"update_streaming", map_camera.position, true)

func _build_rare_mineral_layout(tree_cells: Array[Vector2i], stone_cells: Array[Vector2i]) -> Array[Dictionary]:
	var occupied: Dictionary = {}
	for cell: Vector2i in tree_cells:
		occupied[cell] = true
	for cell: Vector2i in stone_cells:
		occupied[cell] = true
	for y: int in range(8, 13):
		for x: int in range(8, 13):
			occupied[Vector2i(x, y)] = true
	var candidates: Array[Vector2i] = []
	for y: int in range(2, TERRITORY_SIZE - 2):
		for x: int in range(2, TERRITORY_SIZE - 2):
			var cell: Vector2i = Vector2i(x, y)
			if not occupied.has(cell):
				candidates.append(cell)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _resource_seed
	for index: int in range(candidates.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var swap_value: Vector2i = candidates[index]
		candidates[index] = candidates[swap_index]
		candidates[swap_index] = swap_value
	var counts: PackedInt32Array = _rare_mineral_counts()
	var types: Array[StringName] = []
	for _index: int in counts[0]:
		types.append(&"iron")
	for _index: int in counts[1]:
		types.append(&"gold_ore")
	for _index: int in counts[2]:
		types.append(&"diamond")
	var layout: Array[Dictionary] = []
	for index: int in mini(types.size(), candidates.size()):
		layout.append({"resource_type": types[index], "cell": candidates[index]})
	return layout

func _rare_mineral_counts() -> PackedInt32Array:
	match _resource_abundance:
		RESOURCE_SCARCE:
			return PackedInt32Array([3, 1, 1])
		RESOURCE_RICH:
			return PackedInt32Array([8, 5, 2])
		_:
			return PackedInt32Array([5, 3, 1])

func _mineral_scene_for(resource_type: StringName) -> PackedScene:
	match resource_type:
		&"gold_ore":
			return GOLD_DEPOSIT_SCENE
		&"diamond":
			return DIAMOND_DEPOSIT_SCENE
		_:
			return IRON_DEPOSIT_SCENE

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

func _resource_world_position(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_SIZE + TILE_SIZE / 2.0, (cell.y + 1) * TILE_SIZE)

func _territory_base_position(territory_id: int) -> Vector2:
	var index: int = clampi(territory_id - 1, 0, _territory_rects.size() - 1)
	var rect: Rect2i = _territory_rects[index]
	var center_cell: Vector2i = rect.position + Vector2i(TERRITORY_SIZE >> 1, TERRITORY_SIZE >> 1)
	return Vector2(center_cell.x * TILE_SIZE + TILE_SIZE / 2.0, center_cell.y * TILE_SIZE + TILE_SIZE / 2.0)

func _territory_overview_position() -> Vector2:
	if _territory_rects.is_empty():
		return _map_center()
	var position_sum: Vector2 = Vector2.ZERO
	for territory_id: int in range(1, _territory_rects.size() + 1):
		position_sum += _territory_base_position(territory_id)
	return position_sum / float(_territory_rects.size())

func _map_center() -> Vector2:
	return Vector2(GRID_SIZE * TILE_SIZE / 2.0, GRID_SIZE * TILE_SIZE / 2.0)

func _on_player_base_selected(player_base: PlayerBase) -> void:
	if not _game_started or player_base.owner_peer_id != _local_peer_id:
		return
	_active_player_base = player_base
	base_action_menu.toggle_for(player_base, BASE_ACTION_ORIGIN_OFFSET)
	if base_action_menu.visible:
		var current_level: int = int(_base_level_by_peer_id.get(_local_peer_id, 1))
		base_action_menu.set_summon_tooltip(_build_summon_tooltip(current_level))
		base_action_menu.set_upgrade_tooltip(_build_upgrade_tooltip(current_level))

func _on_base_action_selected(action_id: StringName) -> void:
	match action_id:
		&"recruit":
			_card_menu_mode = &"recruit"
			_active_summon_offer_id = 0
			if is_instance_valid(_active_player_base):
				summon_card_menu.open_for(_active_player_base, UNIT_CATALOG.build_recruitment_cards(), false)
		&"summon":
			_request_purchase_summon()
		&"upgrade":
			_request_base_upgrade()

func _on_summon_card_selected(unit_definition_id: StringName) -> void:
	if _card_menu_mode == &"recruit":
		_request_recruit_unit(unit_definition_id)
	elif _card_menu_mode == &"summon" and _active_summon_offer_id > 0:
		_request_claim_summon(_active_summon_offer_id, unit_definition_id)
	_card_menu_mode = &""
	_active_summon_offer_id = 0

func _request_recruit_unit(unit_definition_id: StringName) -> void:
	var territory_id: int = _active_player_base.territory_id if is_instance_valid(_active_player_base) else _local_territory_id
	if _has_gameplay_authority():
		_server_recruit_unit(_local_peer_id, unit_definition_id, territory_id)
	else:
		_rpc_request_recruit_unit.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, str(unit_definition_id), territory_id)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_recruit_unit(unit_definition_id: String, territory_id: int) -> void:
	if not _has_gameplay_authority():
		return
	var requesting_peer_id: int = multiplayer.get_remote_sender_id()
	_server_recruit_unit(requesting_peer_id, StringName(unit_definition_id), territory_id)

func _server_recruit_unit(owner_peer_id: int, unit_definition_id: StringName, territory_id: int = 0) -> bool:
	var definition: UnitDefinition = UNIT_CATALOG.get_definition(unit_definition_id)
	if definition == null or definition.category != UnitDefinition.Category.WORKER:
		return false
	if not UNIT_CATALOG.recruitment_pool.has(definition):
		return false
	if territory_id <= 0:
		territory_id = int((_player_by_peer_id.get(owner_peer_id, {}) as Dictionary).get("territory_id", 0))
	if int(_territory_owner_by_id.get(territory_id, 0)) != owner_peer_id:
		return false
	if not _player_resource_states.has(owner_peer_id):
		return false
	var state: Dictionary = (_player_resource_states[owner_peer_id] as Dictionary).duplicate(true)
	if int(state.get("gold", 0)) < definition.recruit_cost_gold:
		unit_command_panel.show_notice("招募失败：金币不足，需要%d" % definition.recruit_cost_gold)
		return false
	if definition.recruit_cost_gold > 0:
		state["gold"] = int(state.get("gold", 0)) - definition.recruit_cost_gold
		_player_resource_states[owner_peer_id] = state
		_send_resource_state(owner_peer_id, state)
	return _server_spawn_unit(owner_peer_id, unit_definition_id, territory_id)

func _request_purchase_summon() -> void:
	if _has_gameplay_authority():
		_server_purchase_summon(_local_peer_id)
	else:
		_rpc_request_purchase_summon.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_purchase_summon() -> void:
	if _has_gameplay_authority():
		_server_purchase_summon(multiplayer.get_remote_sender_id())

func _server_purchase_summon(owner_peer_id: int) -> bool:
	if not _has_gameplay_authority() or not _player_resource_states.has(owner_peer_id):
		return false
	var state: Dictionary = (_player_resource_states[owner_peer_id] as Dictionary).duplicate(true)
	if int(state.get("gold", 0)) < BaseProgression.SUMMON_COST:
		print("召唤失败：金币不足")
		return false
	state["gold"] = int(state.get("gold", 0)) - BaseProgression.SUMMON_COST
	_player_resource_states[owner_peer_id] = state
	_send_resource_state(owner_peer_id, state)
	var level: int = int(_base_level_by_peer_id.get(owner_peer_id, 1))
	var cards: Array[UnitDefinition] = UNIT_CATALOG.build_summon_cards(level, BaseProgression.SUMMON_CARD_COUNT, _summon_rng)
	var card_ids: Array[String] = []
	for definition: UnitDefinition in cards:
		card_ids.append(str(definition.unit_id))
	var offer_id: int = _next_summon_offer_id
	_next_summon_offer_id += 1
	_pending_summon_by_peer_id[owner_peer_id] = {"offer_id": offer_id, "card_ids": card_ids}
	if owner_peer_id == _local_peer_id:
		_receive_summon_offer(offer_id, card_ids)
	elif _multiplayer_mode:
		_rpc_receive_summon_offer.rpc_id(owner_peer_id, offer_id, card_ids)
	return true

@rpc("authority", "call_remote", "reliable")
func _rpc_receive_summon_offer(offer_id: int, card_ids: Array[String]) -> void:
	_receive_summon_offer(offer_id, card_ids)

func _receive_summon_offer(offer_id: int, card_ids: Array) -> void:
	_card_menu_mode = &"summon"
	_active_summon_offer_id = offer_id
	var target: PlayerBase = _player_base_by_peer_id.get(_local_peer_id) as PlayerBase
	if is_instance_valid(target):
		_active_player_base = target
		summon_card_menu.open_for(target, UNIT_CATALOG.definitions_from_ids(card_ids), true)

func _request_claim_summon(offer_id: int, unit_definition_id: StringName) -> void:
	if _has_gameplay_authority():
		_server_claim_summon(_local_peer_id, offer_id, unit_definition_id)
	else:
		_rpc_request_claim_summon.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, offer_id, str(unit_definition_id))

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_claim_summon(offer_id: int, unit_definition_id: String) -> void:
	if _has_gameplay_authority():
		_server_claim_summon(multiplayer.get_remote_sender_id(), offer_id, StringName(unit_definition_id))

func _server_claim_summon(owner_peer_id: int, offer_id: int, unit_definition_id: StringName) -> bool:
	var offer: Dictionary = _pending_summon_by_peer_id.get(owner_peer_id, {}) as Dictionary
	if int(offer.get("offer_id", 0)) != offer_id:
		return false
	var card_ids: Array = offer.get("card_ids", []) as Array
	if not card_ids.has(str(unit_definition_id)):
		return false
	_pending_summon_by_peer_id.erase(owner_peer_id)
	return _server_spawn_unit(owner_peer_id, unit_definition_id)

func _request_base_upgrade() -> void:
	if _has_gameplay_authority():
		_server_upgrade_base(_local_peer_id)
	else:
		_rpc_request_base_upgrade.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_base_upgrade() -> void:
	if _has_gameplay_authority():
		_server_upgrade_base(multiplayer.get_remote_sender_id())

func _server_upgrade_base(owner_peer_id: int) -> bool:
	if not _has_gameplay_authority() or not _player_resource_states.has(owner_peer_id):
		return false
	var current_level: int = int(_base_level_by_peer_id.get(owner_peer_id, 1))
	var cost: Dictionary = BaseProgression.get_upgrade_cost(current_level)
	if cost.is_empty():
		return false
	var state: Dictionary = (_player_resource_states[owner_peer_id] as Dictionary).duplicate(true)
	if not _resource_state_can_afford(state, cost):
		print("基地升级失败：资源不足（%s）" % BaseProgression.upgrade_cost_summary(current_level))
		return false
	for resource_id: String in cost.keys():
		state[resource_id] = int(state.get(resource_id, 0)) - int(cost[resource_id])
	_player_resource_states[owner_peer_id] = state
	_base_level_by_peer_id[owner_peer_id] = current_level + 1
	_send_resource_state(owner_peer_id, state)
	_apply_base_level(owner_peer_id, current_level + 1)
	if _multiplayer_mode:
		_rpc_apply_base_level.rpc(owner_peer_id, current_level + 1)
	return true

func _resource_state_can_afford(state: Dictionary, cost: Dictionary) -> bool:
	for resource_id: String in cost.keys():
		if int(state.get(resource_id, 0)) < int(cost[resource_id]):
			return false
	return true

@rpc("authority", "call_remote", "reliable")
func _rpc_apply_base_level(owner_peer_id: int, level: int) -> void:
	_apply_base_level(owner_peer_id, level)

func _apply_base_level(owner_peer_id: int, level: int) -> void:
	_base_level_by_peer_id[owner_peer_id] = clampi(level, 1, BaseProgression.MAX_LEVEL)
	for player_base: PlayerBase in _player_base_by_territory_id.values():
		if is_instance_valid(player_base) and player_base.owner_peer_id == owner_peer_id:
			player_base.set_level(level)

func _build_summon_tooltip(level: int) -> String:
	return "消耗%d金币召唤一次\n召唤不可反悔\n基地Lv.%d概率：%s" % [
		BaseProgression.SUMMON_COST, level, BaseProgression.probability_summary(level),
	]

func _build_upgrade_tooltip(level: int) -> String:
	if level >= BaseProgression.MAX_LEVEL:
		return "基地已达到最高等级"
	return "升级至 Lv.%d\n%s" % [level + 1, BaseProgression.upgrade_cost_summary(level)]

func _server_spawn_unit(owner_peer_id: int, unit_definition_id: StringName, preferred_territory_id: int = 0) -> bool:
	if not _has_gameplay_authority() or not _player_by_peer_id.has(owner_peer_id):
		return false
	var definition: UnitDefinition = UNIT_CATALOG.get_definition(unit_definition_id)
	if definition == null or definition.scene == null:
		return false
	var player: Dictionary = _player_by_peer_id[owner_peer_id]
	var territory_id: int = preferred_territory_id if preferred_territory_id > 0 else int(player.get("territory_id", 0))
	if int(_territory_owner_by_id.get(territory_id, 0)) != owner_peer_id:
		return false
	var sequence: int = int(_spawn_sequence_by_peer.get(owner_peer_id, 0))
	var spawn_data: Dictionary = {
		"unit_id": _next_network_unit_id,
		"definition_id": str(unit_definition_id),
		"owner_peer_id": owner_peer_id,
		"territory_id": territory_id,
		"position": _unit_spawn_position(territory_id, sequence),
	}
	_next_network_unit_id += 1
	_spawn_sequence_by_peer[owner_peer_id] = sequence + 1
	_spawn_network_unit(spawn_data)
	if _multiplayer_mode:
		_rpc_spawn_unit.rpc(spawn_data)
	return true

@rpc("authority", "call_remote", "reliable")
func _rpc_spawn_unit(spawn_data: Dictionary) -> void:
	_spawn_network_unit(spawn_data)

func _spawn_network_unit(spawn_data: Dictionary) -> void:
	var network_unit_id: int = int(spawn_data.get("unit_id", 0))
	if network_unit_id <= 0 or _network_units.has(network_unit_id):
		return
	var definition: UnitDefinition = UNIT_CATALOG.get_definition(StringName(str(spawn_data.get("definition_id", ""))))
	if definition == null or definition.scene == null:
		return
	var unit: Node2D = definition.scene.instantiate() as Node2D
	if unit == null:
		return
	unit.name = "NetworkUnit_%d" % network_unit_id
	unit.position = spawn_data.get("position", Vector2.ZERO) as Vector2
	unit_container.add_child(unit)
	var owner_peer_id: int = int(spawn_data.get("owner_peer_id", 0))
	var territory_id: int = int(spawn_data.get("territory_id", 0))
	unit.set("unit_id", network_unit_id)
	unit.set("owner_peer_id", owner_peer_id)
	unit.set("definition", definition)
	if definition.category == UnitDefinition.Category.COMBAT or definition.unit_id in [&"explorer", &"builder"]:
		unit.call(&"configure_network", network_unit_id, owner_peer_id, territory_id, definition, _has_gameplay_authority())
	else:
		unit.call(&"configure_network", network_unit_id, owner_peer_id, definition)
		var resource_container: Node2D = tree_container if definition.unit_id == &"lumber" else mineable_container
		unit.call(&"setup", resource_container, territory_id, _has_gameplay_authority())
	_apply_unit_faction_tint(unit, owner_peer_id)
	_network_units[network_unit_id] = unit
	_attach_vitals(
		unit, owner_peer_id, float(definition.max_health), float(definition.defense), definition.evasion_chance,
		float(definition.max_mana), definition.mana_regen_per_second, Vector2(0.0, -24.0), 30.0, &"unit", network_unit_id
	)
	if definition.category == UnitDefinition.Category.COMBAT and unit.has_method(&"setup_combat_context"):
		unit.call(
			&"setup_combat_context",
			_get_enemy_damageables.bind(owner_peer_id),
			_get_friendly_damageables.bind(owner_peer_id),
			TILE_SIZE
		)

func _apply_unit_faction_tint(unit: Node2D, owner_peer_id: int) -> void:
	var tint: Color = PlayerBase.ENEMY_FACTION_TINT if _are_peers_hostile(_local_peer_id, owner_peer_id) else Color.WHITE
	for visual_node: Node in unit.find_children("*", "Sprite2D", true, false):
		var sprite: Sprite2D = visual_node as Sprite2D
		if sprite != null:
			sprite.self_modulate = tint

func _unit_spawn_position(territory_id: int, sequence: int) -> Vector2:
	var column: int = sequence % 4
	var row: int = floori(float(sequence) / 4.0)
	return _territory_base_position(territory_id) + Vector2(float(column) * 38.0 - 57.0, 66.0 + float(row) * 38.0)

func _select_single_unit(world_position: Vector2) -> void:
	var nearest_unit_id: int = 0
	var nearest_distance: float = 18.0 * 18.0
	for network_unit_id: int in _network_units.keys():
		var unit: Node2D = _network_units[network_unit_id]
		if not _is_local_combat_unit(unit):
			continue
		var distance: float = unit.global_position.distance_squared_to(world_position)
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest_unit_id = network_unit_id
	var selected_ids: Array[int] = []
	if nearest_unit_id > 0:
		selected_ids.append(nearest_unit_id)
	_set_selected_units(selected_ids)

func _select_units_in_rect(selection_rect: Rect2) -> void:
	var selected_ids: Array[int] = []
	for network_unit_id: int in _network_units.keys():
		var unit: Node2D = _network_units[network_unit_id]
		if _is_local_combat_unit(unit) and selection_rect.has_point(unit.global_position):
			selected_ids.append(network_unit_id)
	selected_ids.sort()
	_set_selected_units(selected_ids)

func _set_selected_units(unit_ids: Array[int]) -> void:
	for previous_id: int in _selected_unit_ids:
		var previous_unit: Node2D = _network_units.get(previous_id) as Node2D
		if is_instance_valid(previous_unit) and previous_unit.has_method(&"set_selected"):
			previous_unit.call(&"set_selected", false)
	_selected_unit_ids = unit_ids.duplicate()
	for selected_id: int in _selected_unit_ids:
		var selected_unit: Node2D = _network_units.get(selected_id) as Node2D
		if is_instance_valid(selected_unit) and selected_unit.has_method(&"set_selected"):
			selected_unit.call(&"set_selected", true)
	_refresh_unit_command_panel()

func _refresh_unit_command_panel() -> void:
	if _selected_unit_ids.size() != 1:
		unit_command_panel.hide_selection()
		return
	var unit: Node2D = _network_units.get(_selected_unit_ids[0]) as Node2D
	if not is_instance_valid(unit):
		unit_command_panel.hide_selection()
		return
	var definition: UnitDefinition = unit.get("definition") as UnitDefinition
	if definition == null:
		unit_command_panel.hide_selection()
	elif definition.unit_id == &"lumber" or definition.unit_id == &"quarry":
		var level: int = int(unit.get("machine_level"))
		var permission: String = "采集速度 ×%.2f" % MachineProgressionData.get_speed_multiplier(level)
		if definition.unit_id == &"quarry":
			permission += "\n" + MachineProgressionData.quarry_permission_text(level)
		unit_command_panel.show_machine(int(unit.get("unit_id")), definition.display_name, level, bool(unit.get("work_enabled")), permission)
	elif definition.unit_id == &"explorer":
		unit_command_panel.show_explorer(int(unit.get("unit_id")))
	elif definition.unit_id == &"builder":
		unit_command_panel.show_builder(int(unit.get("unit_id")), BUILDING_CATALOG.definitions)
	else:
		unit_command_panel.hide_selection()

func _is_local_combat_unit(unit: Node2D) -> bool:
	return is_instance_valid(unit) and int(unit.get("owner_peer_id")) == _local_peer_id

func _on_machine_work_toggled(unit_id: int, enabled: bool) -> void:
	if _has_gameplay_authority():
		_server_set_machine_work(_local_peer_id, unit_id, enabled)
	else:
		_rpc_request_machine_work.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, unit_id, enabled)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_machine_work(unit_id: int, enabled: bool) -> void:
	if _has_gameplay_authority():
		_server_set_machine_work(multiplayer.get_remote_sender_id(), unit_id, enabled)

func _server_set_machine_work(owner_peer_id: int, unit_id: int, enabled: bool) -> bool:
	var unit: Node2D = _network_units.get(unit_id) as Node2D
	if not _is_owned_machine(unit, owner_peer_id):
		return false
	unit.call(&"set_work_enabled", enabled)
	if _multiplayer_mode:
		_rpc_apply_machine_configuration.rpc(unit_id, enabled, int(unit.get("machine_level")))
	if owner_peer_id == _local_peer_id:
		_refresh_unit_command_panel()
	return true

func _on_machine_upgrade_requested(unit_id: int) -> void:
	if _has_gameplay_authority():
		_server_upgrade_machine(_local_peer_id, unit_id)
	else:
		_rpc_request_machine_upgrade.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, unit_id)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_machine_upgrade(unit_id: int) -> void:
	if _has_gameplay_authority():
		_server_upgrade_machine(multiplayer.get_remote_sender_id(), unit_id)

func _server_upgrade_machine(owner_peer_id: int, unit_id: int) -> bool:
	var unit: Node2D = _network_units.get(unit_id) as Node2D
	if not _is_owned_machine(unit, owner_peer_id) or not _player_resource_states.has(owner_peer_id):
		return false
	var current_level: int = int(unit.get("machine_level"))
	var cost: Dictionary = MachineProgressionData.get_upgrade_cost(current_level)
	if cost.is_empty():
		_notify_peer(owner_peer_id, "机器已经满级")
		return false
	var state: Dictionary = (_player_resource_states[owner_peer_id] as Dictionary).duplicate(true)
	if not _resource_state_can_afford(state, cost):
		_notify_peer(owner_peer_id, "升级资源不足：%s" % MachineProgressionData.cost_summary(current_level))
		return false
	for resource_id: String in cost.keys():
		state[resource_id] = int(state.get(resource_id, 0)) - int(cost[resource_id])
	_player_resource_states[owner_peer_id] = state
	_send_resource_state(owner_peer_id, state)
	var next_level: int = current_level + 1
	unit.call(&"set_machine_level", next_level)
	if _multiplayer_mode:
		_rpc_apply_machine_configuration.rpc(unit_id, bool(unit.get("work_enabled")), next_level)
	_notify_peer(owner_peer_id, "机器已升级至 Lv.%d" % next_level)
	if owner_peer_id == _local_peer_id:
		_refresh_unit_command_panel()
	return true

func _is_owned_machine(unit: Node2D, owner_peer_id: int) -> bool:
	if not is_instance_valid(unit) or int(unit.get("owner_peer_id")) != owner_peer_id:
		return false
	var definition: UnitDefinition = unit.get("definition") as UnitDefinition
	return definition != null and definition.unit_id in [&"lumber", &"quarry"]

@rpc("authority", "call_remote", "reliable")
func _rpc_apply_machine_configuration(unit_id: int, enabled: bool, level: int) -> void:
	var unit: Node2D = _network_units.get(unit_id) as Node2D
	if not is_instance_valid(unit):
		return
	unit.call(&"set_work_enabled", enabled)
	unit.call(&"set_machine_level", level)
	if _selected_unit_ids.has(unit_id):
		_refresh_unit_command_panel()

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_move_units(unit_id_values: Array, target_position: Vector2) -> void:
	if not _has_gameplay_authority():
		return
	var unit_ids: Array[int] = []
	for unit_id_value: Variant in unit_id_values:
		unit_ids.append(int(unit_id_value))
	_server_move_units(multiplayer.get_remote_sender_id(), unit_ids, target_position)

func _server_move_units(requesting_peer_id: int, requested_unit_ids: Array[int], target_position: Vector2) -> bool:
	if not _has_gameplay_authority():
		return false
	var formation_ids: Array[int] = []
	var assignments: Array[Dictionary] = []
	var formation_spacing: float = 40.0
	for network_unit_id: int in requested_unit_ids:
		var unit: Node2D = _network_units.get(network_unit_id) as Node2D
		if not is_instance_valid(unit) or int(unit.get("owner_peer_id")) != requesting_peer_id:
			continue
		var definition: UnitDefinition = unit.get("definition") as UnitDefinition
		if definition == null:
			continue
		if definition.category == UnitDefinition.Category.COMBAT or definition.can_leave_territory:
			formation_ids.append(network_unit_id)
			formation_spacing = maxf(formation_spacing, definition.formation_spacing)
			continue
		if not definition.can_build_structures and bool(unit.get("work_enabled")):
			_notify_peer(requesting_peer_id, "请先让机器休息，再下达移动指令")
			continue
		var territory_id: int = int(unit.get("territory_id"))
		var restricted_target: Vector2 = _clamp_world_position_to_territory(target_position, territory_id)
		if restricted_target.distance_squared_to(target_position) > 1.0:
			_notify_peer(requesting_peer_id, "无法控制对象移动到领地外围，已移动到边界位置")
		var worker_path: PackedVector2Array = world_pathfinder.find_path(unit.global_position, restricted_target)
		if not worker_path.is_empty():
			assignments.append({"unit_id": network_unit_id, "target": worker_path[-1], "path": worker_path})
	formation_ids.sort()
	assignments.append_array(_build_formation_assignments(formation_ids, target_position, formation_spacing))
	if assignments.is_empty():
		return false
	_apply_move_assignments(assignments)
	if _multiplayer_mode:
		_rpc_apply_move_assignments.rpc(assignments)
	return true

func _clamp_world_position_to_territory(target_position: Vector2, territory_id: int) -> Vector2:
	if territory_id <= 0 or territory_id > _territory_rects.size():
		return target_position
	var rect: Rect2i = _territory_rects[territory_id - 1]
	var inset: float = 16.0
	return Vector2(
		clampf(target_position.x, float(rect.position.x * TILE_SIZE) + inset, float(rect.end.x * TILE_SIZE) - inset),
		clampf(target_position.y, float(rect.position.y * TILE_SIZE) + inset, float(rect.end.y * TILE_SIZE) - inset)
	)

func _notify_peer(peer_id: int, message: String) -> void:
	if peer_id == _local_peer_id:
		unit_command_panel.show_notice(message)
	elif _multiplayer_mode:
		_rpc_show_notice.rpc_id(peer_id, message)

@rpc("authority", "call_remote", "reliable")
func _rpc_show_notice(message: String) -> void:
	unit_command_panel.show_notice(message)

func _build_formation_assignments(unit_ids: Array[int], center: Vector2, spacing: float) -> Array[Dictionary]:
	var assignments: Array[Dictionary] = []
	if unit_ids.is_empty():
		return assignments
	var columns: int = ceili(sqrt(float(unit_ids.size())))
	var rows: int = ceili(float(unit_ids.size()) / float(columns))
	var map_max: float = float(GRID_SIZE * TILE_SIZE - 16)
	for index: int in unit_ids.size():
		var column: int = index % columns
		var row: int = floori(float(index) / float(columns))
		var offset: Vector2 = Vector2(
			(float(column) - float(columns - 1) * 0.5) * spacing,
			(float(row) - float(rows - 1) * 0.5) * spacing
		)
		var destination: Vector2 = center + offset
		destination.x = clampf(destination.x, 16.0, map_max)
		destination.y = clampf(destination.y, 16.0, map_max)
		var unit: Node2D = _network_units.get(unit_ids[index]) as Node2D
		if not is_instance_valid(unit):
			continue
		var path: PackedVector2Array = world_pathfinder.find_path(unit.global_position, destination)
		if path.is_empty():
			continue
		assignments.append({"unit_id": unit_ids[index], "target": path[path.size() - 1], "path": path})
	return assignments

@rpc("authority", "call_remote", "reliable")
func _rpc_apply_move_assignments(assignments: Array) -> void:
	_apply_move_assignments(assignments)

func _apply_move_assignments(assignments: Array) -> void:
	for assignment_value: Variant in assignments:
		var assignment: Dictionary = assignment_value as Dictionary
		var network_unit_id: int = int(assignment.get("unit_id", 0))
		var unit: Node2D = _network_units.get(network_unit_id) as Node2D
		if is_instance_valid(unit) and unit.has_method(&"set_navigation_path"):
			var path: PackedVector2Array = assignment.get("path", PackedVector2Array())
			unit.call(&"set_navigation_path", path)

func _broadcast_unit_states() -> void:
	var states: Array[Dictionary] = []
	for network_unit_id: int in _network_units.keys():
		var unit: Node2D = _network_units[network_unit_id]
		if not is_instance_valid(unit):
			continue
		var state: Dictionary = {"unit_id": network_unit_id, "position": unit.global_position}
		if unit is TreantUnit or unit is ExplorerUnit:
			state["target"] = unit.get("move_target")
			state["moving"] = bool(unit.get("has_move_target"))
		else:
			state["working"] = bool(unit.call(&"is_working"))
			state["work_enabled"] = bool(unit.get("work_enabled"))
			state["machine_level"] = int(unit.get("machine_level"))
		var health := unit.get_node_or_null("HealthComponent") as HealthComponent
		if is_instance_valid(health):
			state["health"] = health.current_health
			state["mana"] = health.current_mana
		states.append(state)
	_rpc_apply_unit_states.rpc(states)
	var structure_states: Array[Dictionary] = []
	for territory_id: int in _player_base_by_territory_id.keys():
		var player_base := _player_base_by_territory_id.get(territory_id) as PlayerBase
		if not is_instance_valid(player_base):
			continue
		var base_health := player_base.get_node_or_null("HealthComponent") as HealthComponent
		if is_instance_valid(base_health):
			structure_states.append({"kind": "base", "id": territory_id, "health": base_health.current_health})
	for building_id: int in _network_buildings.keys():
		var building := _network_buildings.get(building_id) as ProductionBuilding
		if not is_instance_valid(building):
			continue
		var building_health := building.get_node_or_null("HealthComponent") as HealthComponent
		if is_instance_valid(building_health):
			structure_states.append({"kind": "building", "id": building_id, "health": building_health.current_health})
	_rpc_apply_structure_states.rpc(structure_states)

@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _rpc_apply_unit_states(states: Array) -> void:
	for state_value: Variant in states:
		var state: Dictionary = state_value as Dictionary
		var network_unit_id: int = int(state.get("unit_id", 0))
		var unit: Node2D = _network_units.get(network_unit_id) as Node2D
		if not is_instance_valid(unit):
			continue
		if unit is TreantUnit or unit is ExplorerUnit:
			unit.call(&"apply_network_state", state.get("position", unit.global_position), state.get("target", unit.global_position), bool(state.get("moving", false)))
		else:
			unit.call(&"apply_network_state", state.get("position", unit.global_position), bool(state.get("working", false)), bool(state.get("work_enabled", true)), int(state.get("machine_level", 1)))
		var health := unit.get_node_or_null("HealthComponent") as HealthComponent
		if is_instance_valid(health):
			health.apply_network_state(float(state.get("health", health.current_health)), float(state.get("mana", health.current_mana)))

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _rpc_apply_structure_states(states: Array) -> void:
	for state_value: Variant in states:
		var state := state_value as Dictionary
		var target: Node2D
		if str(state.get("kind", "")) == "base":
			target = _player_base_by_territory_id.get(int(state.get("id", 0))) as Node2D
		else:
			target = _network_buildings.get(int(state.get("id", 0))) as Node2D
		if not is_instance_valid(target):
			continue
		var health := target.get_node_or_null("HealthComponent") as HealthComponent
		if is_instance_valid(health):
			health.apply_network_state(float(state.get("health", health.current_health)), health.current_mana)

func _refresh_fog() -> void:
	var sources: Array[Dictionary] = []
	var owned_rects: Array[Rect2i] = []
	for territory_id: int in _territory_owner_by_id.keys():
		if int(_territory_owner_by_id[territory_id]) == _local_peer_id and territory_id > 0 and territory_id <= _territory_rects.size():
			owned_rects.append(_territory_rects[territory_id - 1])
	for unit: Node2D in _network_units.values():
		if not is_instance_valid(unit) or int(unit.get("owner_peer_id")) != _local_peer_id:
			continue
		if unit.has_method(&"get_vision_radius_world"):
			sources.append({"position": unit.global_position, "radius": float(unit.call(&"get_vision_radius_world", TILE_SIZE))})
	fog_of_war.set_owned_territories(owned_rects)
	fog_of_war.update_visibility(sources, _full_vision)
	_refresh_entity_visibility()

func _refresh_entity_visibility() -> void:
	for unit: Node2D in _network_units.values():
		if not is_instance_valid(unit):
			continue
		var is_local_unit: bool = int(unit.get("owner_peer_id")) == _local_peer_id
		unit.visible = is_local_unit or fog_of_war.is_world_position_visible(unit.global_position)
	for base_node: Node in base_container.get_children():
		if base_node is not PlayerBase:
			continue
		var player_base: PlayerBase = base_node as PlayerBase
		player_base.visible = player_base.owner_peer_id == _local_peer_id or fog_of_war.is_world_position_visible(player_base.global_position)
	for building: ProductionBuilding in _network_buildings.values():
		if is_instance_valid(building):
			building.visible = building.owner_peer_id == _local_peer_id or fog_of_war.is_world_position_visible(building.global_position)
	for territory_index: int in territory_container.get_child_count():
		var territory: Node2D = territory_container.get_child(territory_index) as Node2D
		var territory_id: int = territory_index + 1
		if territory_id > _territory_rects.size() or not _territory_owner_by_id.has(territory_id):
			territory.hide()
			continue
		var is_owned: bool = int(_territory_owner_by_id[territory_id]) == _local_peer_id
		territory.visible = is_owned or _is_territory_visible(_territory_rects[territory_id - 1])
	for resource_root: Node2D in [tree_container, stone_container, rare_mineral_container]:
		for child: Node in resource_root.get_children():
			if child is Node2D:
				var resource: Node2D = child as Node2D
				resource.visible = fog_of_war.is_world_position_visible(resource.global_position)

func _is_territory_visible(rect: Rect2i) -> bool:
	if _full_vision:
		return true
	var sample_cells: Array[Vector2i] = [
		rect.position,
		Vector2i(rect.end.x - 1, rect.position.y),
		rect.end - Vector2i.ONE,
		Vector2i(rect.position.x, rect.end.y - 1),
		rect.position + Vector2i(rect.size.x >> 1, rect.size.y >> 1),
	]
	for cell: Vector2i in sample_cells:
		var world_position: Vector2 = Vector2(cell * TILE_SIZE) + Vector2.ONE * float(TILE_SIZE) * 0.5
		if fog_of_war.is_world_position_visible(world_position):
			return true
	return false

func _on_full_vision_changed(enabled: bool) -> void:
	_full_vision = enabled
	_refresh_fog()

func _on_build_preview_requested(unit_id: int) -> void:
	var unit: Node2D = _network_units.get(unit_id) as Node2D
	if not is_instance_valid(unit) or int(unit.get("owner_peer_id")) != _local_peer_id:
		return
	var definition: UnitDefinition = unit.get("definition") as UnitDefinition
	if definition == null or not definition.can_build_base:
		return
	var center_cell: Vector2i = Vector2i(floori(unit.global_position.x / TILE_SIZE), floori(unit.global_position.y / TILE_SIZE))
	var rect: Rect2i = Rect2i(center_cell - Vector2i(TERRITORY_SIZE >> 1, TERRITORY_SIZE >> 1), Vector2i(TERRITORY_SIZE, TERRITORY_SIZE))
	if not _is_valid_expansion_rect(rect):
		unit_command_panel.show_notice("此处无法建造：新领地必须在地图内且不能与现有领地重叠")
		return
	_build_preview_unit_id = unit_id
	_build_preview_rect = rect
	_preview_camera_position = map_camera.position
	_preview_camera_zoom = map_camera.zoom
	map_camera.set_process(false)
	command_overlay.show_build_preview(rect, TILE_SIZE)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(map_camera, "position", _rect_world_center(rect), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(map_camera, "zoom", EXPLORER_BUILD_ZOOM, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	unit_command_panel.show_build_confirmation(_resource_summary_in_rect(rect))

func _on_build_confirmed() -> void:
	if _build_preview_unit_id <= 0:
		return
	if _has_gameplay_authority():
		_server_build_base(_local_peer_id, _build_preview_unit_id, _build_preview_rect)
	else:
		_rpc_request_build_base.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, _build_preview_unit_id, _build_preview_rect)
	_cancel_build_preview()

func _cancel_build_preview() -> void:
	if _build_preview_unit_id <= 0:
		unit_command_panel.hide_build_confirmation()
		return
	_build_preview_unit_id = 0
	_build_preview_rect = Rect2i()
	command_overlay.hide_build_preview()
	unit_command_panel.hide_build_confirmation()
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(map_camera, "position", _preview_camera_position, 0.3)
	tween.tween_property(map_camera, "zoom", _preview_camera_zoom, 0.3)
	tween.chain().tween_callback(func() -> void: map_camera.set_process(true))

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_build_base(unit_id: int, rect: Rect2i) -> void:
	if _has_gameplay_authority():
		_server_build_base(multiplayer.get_remote_sender_id(), unit_id, rect)

func _server_build_base(owner_peer_id: int, unit_id: int, rect: Rect2i) -> bool:
	if not _has_gameplay_authority() or not _is_valid_expansion_rect(rect):
		return false
	var explorer: Node2D = _network_units.get(unit_id) as Node2D
	if not is_instance_valid(explorer) or int(explorer.get("owner_peer_id")) != owner_peer_id:
		return false
	var definition: UnitDefinition = explorer.get("definition") as UnitDefinition
	if definition == null or not definition.can_build_base:
		return false
	var explorer_cell: Vector2i = Vector2i(floori(explorer.global_position.x / TILE_SIZE), floori(explorer.global_position.y / TILE_SIZE))
	if not rect.has_point(explorer_cell):
		return false
	var territory_id: int = _territory_rects.size() + 1
	var territory_data: Dictionary = {"territory_id": territory_id, "owner_peer_id": owner_peer_id, "rect": rect}
	_apply_new_territory(territory_data)
	if _multiplayer_mode:
		_rpc_apply_new_territory.rpc(territory_data)
	_notify_peer(owner_peer_id, "新基地建立完成，领地范围扩大20×20")
	return true

@rpc("authority", "call_remote", "reliable")
func _rpc_apply_new_territory(territory_data: Dictionary) -> void:
	_apply_new_territory(territory_data)

func _apply_new_territory(territory_data: Dictionary) -> void:
	var territory_id: int = int(territory_data.get("territory_id", 0))
	var owner_peer_id: int = int(territory_data.get("owner_peer_id", 0))
	var rect: Rect2i = territory_data.get("rect", Rect2i()) as Rect2i
	if territory_id <= 0 or territory_id <= _territory_rects.size():
		return
	_territory_rects.append(rect)
	_territory_owner_by_id[territory_id] = owner_peer_id
	var territory: Node2D = _get_or_create_territory(territory_id - 1)
	territory.show()
	territory.call(&"configure", territory_id, rect, _territory_color(territory_id))
	var player_base: PlayerBase = PLAYER_BASE_SCENE.instantiate() as PlayerBase
	player_base.name = "PlayerBase_%d" % territory_id
	player_base.position = _rect_world_center(rect)
	base_container.add_child(player_base)
	player_base.configure(
		owner_peer_id,
		territory_id,
		owner_peer_id == _local_peer_id,
		_are_peers_hostile(_local_peer_id, owner_peer_id)
	)
	player_base.set_level(int(_base_level_by_peer_id.get(owner_peer_id, 1)))
	_attach_vitals(player_base, owner_peer_id, 1800.0, 45.0, 0.0, 0.0, 0.0, Vector2(0.0, -76.0), 58.0, &"base", territory_id)
	_player_base_by_territory_id[territory_id] = player_base
	if owner_peer_id == _local_peer_id:
		player_base.selected.connect(_on_player_base_selected)
	_claim_resources_in_rect(territory_id, rect)
	_schedule_navigation_rebuild()
	_refresh_fog()

func _is_valid_expansion_rect(rect: Rect2i) -> bool:
	if rect.size != Vector2i(TERRITORY_SIZE, TERRITORY_SIZE):
		return false
	if rect.position.x < 0 or rect.position.y < 0 or rect.end.x > GRID_SIZE or rect.end.y > GRID_SIZE:
		return false
	for existing: Rect2i in _territory_rects:
		if existing.intersects(rect):
			return false
	return true

func _on_structure_preview_requested(unit_id: int, building_definition_id: StringName) -> void:
	var builder := _network_units.get(unit_id) as Node2D
	var definition := BUILDING_CATALOG.get_definition(building_definition_id)
	if not is_instance_valid(builder) or definition == null or int(builder.get("owner_peer_id")) != _local_peer_id:
		return
	var unit_definition := builder.get("definition") as UnitDefinition
	if unit_definition == null or not unit_definition.can_build_structures:
		return
	var rect := _structure_rect_at(builder.global_position, definition.footprint_tiles)
	var territory_id := int(builder.get("territory_id"))
	var failure := _structure_validation_failure(_local_peer_id, territory_id, rect, definition)
	if not failure.is_empty():
		unit_command_panel.show_notice("无法建造：%s" % failure)
		return
	_structure_preview_unit_id = unit_id
	_structure_preview_building_id = building_definition_id
	_structure_preview_rect = rect
	command_overlay.show_build_preview(rect, TILE_SIZE)
	unit_command_panel.show_structure_confirmation(definition, _structure_condition_summary(definition))

func _on_structure_confirmed() -> void:
	if _structure_preview_unit_id <= 0 or _structure_preview_building_id.is_empty():
		return
	if _has_gameplay_authority():
		_server_build_structure(_local_peer_id, _structure_preview_unit_id, _structure_preview_building_id, _structure_preview_rect)
	else:
		_rpc_request_build_structure.rpc_id(
			MultiplayerPeer.TARGET_PEER_SERVER,
			_structure_preview_unit_id,
			str(_structure_preview_building_id),
			_structure_preview_rect
		)
	_cancel_structure_preview()

func _cancel_structure_preview() -> void:
	_structure_preview_unit_id = 0
	_structure_preview_building_id = &""
	_structure_preview_rect = Rect2i()
	command_overlay.hide_build_preview()
	unit_command_panel.hide_build_confirmation()

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_build_structure(unit_id: int, building_definition_id: String, rect: Rect2i) -> void:
	if _has_gameplay_authority():
		_server_build_structure(multiplayer.get_remote_sender_id(), unit_id, StringName(building_definition_id), rect)

func _server_build_structure(owner_peer_id: int, unit_id: int, building_definition_id: StringName, rect: Rect2i) -> bool:
	if not _has_gameplay_authority():
		return false
	var builder := _network_units.get(unit_id) as Node2D
	var definition := BUILDING_CATALOG.get_definition(building_definition_id)
	if not is_instance_valid(builder) or definition == null or int(builder.get("owner_peer_id")) != owner_peer_id:
		return false
	var unit_definition := builder.get("definition") as UnitDefinition
	if unit_definition == null or not unit_definition.can_build_structures:
		return false
	var expected_rect := _structure_rect_at(builder.global_position, definition.footprint_tiles)
	if rect != expected_rect:
		_notify_peer(owner_peer_id, "建造失败：工人位置已经变化，请重新选择建筑")
		return false
	var territory_id := int(builder.get("territory_id"))
	var failure := _structure_validation_failure(owner_peer_id, territory_id, rect, definition)
	if not failure.is_empty():
		_notify_peer(owner_peer_id, "建造失败：%s" % failure)
		return false
	var state := (_player_resource_states[owner_peer_id] as Dictionary).duplicate(true)
	for resource_id: String in definition.cost_dictionary().keys():
		state[resource_id] = int(state.get(resource_id, 0)) - int(definition.cost_dictionary()[resource_id])
	_player_resource_states[owner_peer_id] = state
	_send_resource_state(owner_peer_id, state)
	var spawn_data: Dictionary = {
		"building_id": _next_network_building_id,
		"definition_id": str(definition.building_id),
		"owner_peer_id": owner_peer_id,
		"territory_id": territory_id,
		"position": _rect_world_center(rect),
		"cell_rect": rect,
	}
	_next_network_building_id += 1
	_spawn_network_building(spawn_data)
	if _multiplayer_mode:
		_rpc_spawn_building.rpc(spawn_data)
	_notify_peer(owner_peer_id, "%s建造完成" % definition.display_name)
	return true

@rpc("authority", "call_remote", "reliable")
func _rpc_spawn_building(spawn_data: Dictionary) -> void:
	_spawn_network_building(spawn_data)

func _spawn_network_building(spawn_data: Dictionary) -> void:
	var network_building_id := int(spawn_data.get("building_id", 0))
	if network_building_id <= 0 or _network_buildings.has(network_building_id):
		return
	var definition := BUILDING_CATALOG.get_definition(StringName(str(spawn_data.get("definition_id", ""))))
	if definition == null:
		return
	var building := PRODUCTION_BUILDING_SCENE.instantiate() as ProductionBuilding
	building.name = "NetworkBuilding_%d" % network_building_id
	building.position = spawn_data.get("position", Vector2.ZERO) as Vector2
	building_container.add_child(building)
	var owner_peer_id := int(spawn_data.get("owner_peer_id", 0))
	var territory_id := int(spawn_data.get("territory_id", 0))
	building.configure(network_building_id, owner_peer_id, territory_id, definition, _has_gameplay_authority())
	building.set_meta(&"cell_rect", spawn_data.get("cell_rect", Rect2i()) as Rect2i)
	building.production_ready.connect(_on_building_production_ready)
	_network_buildings[network_building_id] = building
	_attach_vitals(
		building, owner_peer_id, float(definition.max_health), float(definition.defense), 0.0,
		0.0, 0.0, Vector2(0.0, -38.0), 46.0, &"building", network_building_id
	)
	_schedule_navigation_rebuild()

func _on_building_production_ready(owner_peer_id: int, resource_type: StringName, amount: int) -> void:
	if not _has_gameplay_authority() or not _player_resource_states.has(owner_peer_id):
		return
	var state := (_player_resource_states[owner_peer_id] as Dictionary).duplicate(true)
	state[resource_type] = int(state.get(resource_type, 0)) + amount
	_player_resource_states[owner_peer_id] = state
	_send_resource_state(owner_peer_id, state)

func _structure_rect_at(world_position: Vector2, footprint_tiles: int) -> Rect2i:
	var center_cell := Vector2i(floori(world_position.x / TILE_SIZE), floori(world_position.y / TILE_SIZE))
	return Rect2i(center_cell - Vector2i.ONE * (footprint_tiles >> 1), Vector2i.ONE * footprint_tiles)

func _structure_validation_failure(owner_peer_id: int, territory_id: int, rect: Rect2i, definition: BuildingDefinition) -> String:
	if territory_id <= 0 or territory_id > _territory_rects.size() or int(_territory_owner_by_id.get(territory_id, 0)) != owner_peer_id:
		return "只能在己方领地内建造"
	var territory_rect := _territory_rects[territory_id - 1]
	if rect.position.x < territory_rect.position.x or rect.position.y < territory_rect.position.y or rect.end.x > territory_rect.end.x or rect.end.y > territory_rect.end.y:
		return "2×2建筑必须完整位于己方领地内"
	for player_base: PlayerBase in _player_base_by_territory_id.values():
		if is_instance_valid(player_base) and rect.intersects(_structure_rect_at(player_base.global_position, 3)):
			return "不能与基地重叠"
	for existing: ProductionBuilding in _network_buildings.values():
		if is_instance_valid(existing) and rect.intersects(existing.get_meta(&"cell_rect", Rect2i()) as Rect2i):
			return "不能与已有建筑重叠"
	if not _player_resource_states.has(owner_peer_id) or not _resource_state_can_afford(_player_resource_states[owner_peer_id] as Dictionary, definition.cost_dictionary()):
		return "资源不足，需要%s" % definition.cost_summary()
	if not definition.required_resource_type.is_empty() and not _has_nearby_required_resource(territory_id, rect, definition):
		return "附近%.1f格内需要%s" % [definition.required_resource_radius_tiles, _resource_display_name(definition.required_resource_type)]
	return ""

func _has_nearby_required_resource(territory_id: int, rect: Rect2i, definition: BuildingDefinition) -> bool:
	var center := _rect_world_center(rect)
	var max_distance_squared := pow(definition.required_resource_radius_tiles * TILE_SIZE, 2.0)
	for root: Node2D in [tree_container, stone_container, rare_mineral_container]:
		for child: Node in root.get_children():
			var resource := child as Node2D
			if not is_instance_valid(resource) or int(resource.get("territory_id")) != territory_id:
				continue
			var resource_type: StringName
			if root == tree_container:
				resource_type = &"tree"
			elif root == stone_container:
				resource_type = &"stone"
			else:
				resource_type = StringName(str(resource.get("resource_type")))
			if resource_type == definition.required_resource_type and center.distance_squared_to(resource.global_position) <= max_distance_squared:
				return true
	return false

func _structure_condition_summary(definition: BuildingDefinition) -> String:
	if definition.required_resource_type.is_empty():
		return "条件：领地内空闲位置"
	return "条件：附近%.1f格存在%s" % [definition.required_resource_radius_tiles, _resource_display_name(definition.required_resource_type)]

func _resource_display_name(resource_type: StringName) -> String:
	match resource_type:
		&"tree": return "树木"
		&"stone": return "石头"
		&"iron": return "铁矿"
		&"gold_ore": return "金矿"
		&"diamond": return "钻石矿"
		_: return str(resource_type)

func _claim_resources_in_rect(territory_id: int, rect: Rect2i) -> void:
	var streamed_resources: Array = world_resource_streamer.call(&"claim_resources_in_rect", rect) as Array
	for data_value: Variant in streamed_resources:
		_materialize_world_resource_data(data_value as Dictionary, territory_id)
	for root: Node2D in [tree_container, stone_container, rare_mineral_container]:
		for resource: Node in root.get_children():
			if resource is not Node2D:
				continue
			var node: Node2D = resource as Node2D
			if node.get_script() == WORLD_RESOURCE_MARKER_SCRIPT:
				continue
			var cell: Vector2i = Vector2i(floori(node.global_position.x / TILE_SIZE), floori(node.global_position.y / TILE_SIZE))
			if rect.has_point(cell):
				node.set("territory_id", territory_id)

func _materialize_world_resource_data(data: Dictionary, territory_id: int) -> void:
	var resource_type: StringName = data.get("resource_type", &"tree") as StringName
	var resource_id: int = int(data.get("resource_id", 0))
	var resource: Node2D
	var parent: Node2D
	if resource_type == &"tree":
		resource = TREE_SCENE.instantiate() as Node2D
		resource.connect(&"felled", _on_tree_felled)
		parent = tree_container
	elif resource_type == &"stone":
		resource = STONE_SCENE.instantiate() as Node2D
		resource.connect(&"depleted", _on_stone_depleted)
		parent = stone_container
	else:
		resource = _mineral_scene_for(resource_type).instantiate() as Node2D
		resource.connect(&"depleted", _on_mineral_depleted)
		parent = rare_mineral_container
	resource.name = "%s_T%d_World%06d" % [str(resource_type).to_pascal_case(), territory_id, resource_id]
	resource.position = _resource_world_position(data.get("cell", Vector2i.ZERO) as Vector2i)
	resource.set("territory_id", territory_id)
	parent.add_child(resource)

func _resource_summary_in_rect(rect: Rect2i) -> String:
	var streamed_counts: Dictionary = world_resource_streamer.call(&"count_resources_in_rect", rect) as Dictionary
	var counts: Dictionary = {
		"树木": int(streamed_counts.get(&"tree", 0)),
		"石头": int(streamed_counts.get(&"stone", 0)),
		"铁矿": int(streamed_counts.get(&"iron", 0)),
		"金矿": int(streamed_counts.get(&"gold_ore", 0)),
		"钻石": int(streamed_counts.get(&"diamond", 0)),
	}
	for root: Node2D in [tree_container, stone_container, rare_mineral_container]:
		for resource: Node in root.get_children():
			if resource is not Node2D:
				continue
			var node: Node2D = resource as Node2D
			if node.get_script() == WORLD_RESOURCE_MARKER_SCRIPT:
				continue
			var cell: Vector2i = Vector2i(floori(node.global_position.x / TILE_SIZE), floori(node.global_position.y / TILE_SIZE))
			if not rect.has_point(cell):
				continue
			var label: String = "树木" if root == tree_container else "石头"
			if root == rare_mineral_container:
				match StringName(str(node.get("resource_type"))):
					&"iron": label = "铁矿"
					&"gold_ore": label = "金矿"
					&"diamond": label = "钻石"
			counts[label] = int(counts[label]) + 1
	return "树木%d  石头%d  铁矿%d  金矿%d  钻石%d" % [counts["树木"], counts["石头"], counts["铁矿"], counts["金矿"], counts["钻石"]]

func _rect_world_center(rect: Rect2i) -> Vector2:
	return Vector2(rect.position * TILE_SIZE) + Vector2(rect.size * TILE_SIZE) * 0.5

func _attach_vitals(
	root: Node2D,
	owner_peer_id: int,
	max_health: float,
	defense: float,
	evasion: float,
	max_mana: float,
	mana_regen: float,
	bar_offset: Vector2,
	bar_width: float,
	entity_kind: StringName,
	entity_id: int
) -> HealthComponent:
	var existing := root.get_node_or_null("HealthComponent") as HealthComponent
	if is_instance_valid(existing):
		return existing
	var component := HEALTH_COMPONENT_SCRIPT.new() as HealthComponent
	component.name = "HealthComponent"
	root.add_child(component)
	component.configure(root, owner_peer_id, max_health, defense, evasion, max_mana, mana_regen)
	component.combat_radius = 41.0 if entity_kind == &"base" else (28.0 if entity_kind == &"building" else 0.0)
	component.died.connect(_on_health_component_died)
	root.set_meta(&"damageable_kind", entity_kind)
	root.set_meta(&"damageable_id", entity_id)
	var health_bar := HEALTH_BAR_SCRIPT.new() as HealthBar2D
	health_bar.name = "HealthBar"
	health_bar.z_index = 950
	root.add_child(health_bar)
	health_bar.bind(component, bar_offset, bar_width)
	return component

func _get_enemy_damageables(owner_peer_id: int) -> Array:
	var result: Array[HealthComponent] = []
	for component: HealthComponent in _all_damageables():
		if component.owner_peer_id != owner_peer_id and _are_peers_hostile(owner_peer_id, component.owner_peer_id):
			result.append(component)
	return result

func _get_friendly_damageables(owner_peer_id: int) -> Array:
	var result: Array[HealthComponent] = []
	for unit: Node2D in _network_units.values():
		if not is_instance_valid(unit):
			continue
		var component := unit.get_node_or_null("HealthComponent") as HealthComponent
		if is_instance_valid(component) and component.is_alive() and not _are_peers_hostile(owner_peer_id, component.owner_peer_id):
			result.append(component)
	return result

func _all_damageables() -> Array[HealthComponent]:
	var result: Array[HealthComponent] = []
	for unit: Node2D in _network_units.values():
		if is_instance_valid(unit):
			var unit_health := unit.get_node_or_null("HealthComponent") as HealthComponent
			if is_instance_valid(unit_health) and unit_health.is_alive():
				result.append(unit_health)
	for building: ProductionBuilding in _network_buildings.values():
		if is_instance_valid(building):
			var building_health := building.get_node_or_null("HealthComponent") as HealthComponent
			if is_instance_valid(building_health) and building_health.is_alive():
				result.append(building_health)
	for player_base: PlayerBase in _player_base_by_territory_id.values():
		if is_instance_valid(player_base):
			var base_health := player_base.get_node_or_null("HealthComponent") as HealthComponent
			if is_instance_valid(base_health) and base_health.is_alive():
				result.append(base_health)
	return result

func _are_peers_hostile(first_peer_id: int, second_peer_id: int) -> bool:
	if first_peer_id == second_peer_id:
		return false
	var first_player := _player_by_peer_id.get(first_peer_id, {}) as Dictionary
	var second_player := _player_by_peer_id.get(second_peer_id, {}) as Dictionary
	if first_player.is_empty() or second_player.is_empty():
		return true
	return int(first_player.get("team", first_peer_id)) != int(second_player.get("team", second_peer_id))

func _on_health_component_died(component: HealthComponent) -> void:
	if not _has_gameplay_authority() or not is_instance_valid(component.target_root):
		return
	var root := component.target_root
	var entity_kind := root.get_meta(&"damageable_kind", &"") as StringName
	var entity_id := int(root.get_meta(&"damageable_id", 0))
	_remove_damageable(entity_kind, entity_id)
	if _multiplayer_mode:
		_rpc_remove_damageable.rpc(str(entity_kind), entity_id)

@rpc("authority", "call_remote", "reliable")
func _rpc_remove_damageable(entity_kind_value: String, entity_id: int) -> void:
	_remove_damageable(StringName(entity_kind_value), entity_id)

func _remove_damageable(entity_kind: StringName, entity_id: int) -> void:
	var target: Node2D
	match entity_kind:
		&"unit":
			target = _network_units.get(entity_id) as Node2D
			_network_units.erase(entity_id)
			_selected_unit_ids.erase(entity_id)
			_refresh_unit_command_panel()
		&"building":
			target = _network_buildings.get(entity_id) as Node2D
			_network_buildings.erase(entity_id)
			_schedule_navigation_rebuild()
		&"base":
			target = _player_base_by_territory_id.get(entity_id) as Node2D
			if is_instance_valid(target):
				var player_base := target as PlayerBase
				_player_base_by_territory_id.erase(entity_id)
				if _player_base_by_peer_id.get(player_base.owner_peer_id) == player_base:
					_player_base_by_peer_id.erase(player_base.owner_peer_id)
				if player_base == _active_player_base:
					_active_player_base = null
					base_action_menu.close()
			_schedule_navigation_rebuild()
	if is_instance_valid(target):
		target.queue_free()

func _initialize_player_resources() -> void:
	_player_resource_states.clear()
	for peer_id: int in _player_by_peer_id.keys():
		_player_resource_states[peer_id] = {
			"gold": DEVELOPMENT_GOLD, "wood": 0, "stone": 0,
			"iron": 0, "gold_ore": 0, "diamond": 0,
		}
	resource_manager.call(&"set_state", DEVELOPMENT_GOLD, 0, 0, 0, 0, 0)

func _server_apply_harvest(territory_id: int, resource_type: StringName) -> void:
	if not _has_gameplay_authority():
		return
	var owner_peer_id: int = int(_territory_owner_by_id.get(territory_id, 0))
	if owner_peer_id <= 0:
		return
	var state: Dictionary = (_player_resource_states.get(owner_peer_id, {}) as Dictionary).duplicate(true)
	if resource_type == &"tree":
		state["wood"] = int(state.get("wood", 0)) + TREE_WOOD_REWARD
		state["gold"] = maxi(0, int(state.get("gold", DEVELOPMENT_GOLD)) - TREE_GOLD_COST)
	elif resource_type == &"stone":
		state["stone"] = int(state.get("stone", 0)) + STONE_REWARD
		state["gold"] = maxi(0, int(state.get("gold", DEVELOPMENT_GOLD)) - STONE_GOLD_COST)
	elif MINERAL_REWARDS.has(resource_type):
		state[resource_type] = int(state.get(resource_type, 0)) + int(MINERAL_REWARDS[resource_type])
		state["gold"] = maxi(0, int(state.get("gold", DEVELOPMENT_GOLD)) - MINERAL_GOLD_COST)
	_player_resource_states[owner_peer_id] = state
	_send_resource_state(owner_peer_id, state)

func _send_resource_state(owner_peer_id: int, state: Dictionary) -> void:
	if owner_peer_id == _local_peer_id:
		_apply_local_resource_state(state)
	elif _multiplayer_mode:
		_rpc_receive_resource_state.rpc_id(owner_peer_id, state)

@rpc("authority", "call_remote", "reliable")
func _rpc_receive_resource_state(state: Dictionary) -> void:
	_apply_local_resource_state(state)

func _apply_local_resource_state(state: Dictionary) -> void:
	resource_manager.call(
		&"set_state",
		int(state.get("gold", DEVELOPMENT_GOLD)),
		int(state.get("wood", 0)),
		int(state.get("stone", 0)),
		int(state.get("iron", 0)),
		int(state.get("gold_ore", 0)),
		int(state.get("diamond", 0))
	)

func _on_tree_felled(tree: Node2D) -> void:
	if not _has_gameplay_authority():
		return
	_server_apply_harvest(int(tree.get("territory_id")), &"tree")
	_schedule_navigation_rebuild()
	if _multiplayer_mode:
		_rpc_remove_resource.rpc("tree", str(tree.name))

func _on_stone_depleted(stone: Node2D) -> void:
	if not _has_gameplay_authority():
		return
	_server_apply_harvest(int(stone.get("territory_id")), &"stone")
	_schedule_navigation_rebuild()
	if _multiplayer_mode:
		_rpc_remove_resource.rpc("stone", str(stone.name))

func _on_mineral_depleted(mineral: Node2D) -> void:
	if not _has_gameplay_authority():
		return
	_server_apply_harvest(int(mineral.get("territory_id")), StringName(str(mineral.get("resource_type"))))
	_schedule_navigation_rebuild()
	if _multiplayer_mode:
		_rpc_remove_resource.rpc(str(mineral.get("resource_type")), str(mineral.name))

@rpc("authority", "call_remote", "reliable")
func _rpc_remove_resource(resource_type: String, resource_name: String) -> void:
	var container: Node2D
	if resource_type == "tree":
		container = tree_container
	elif resource_type == "stone":
		container = stone_container
	else:
		container = rare_mineral_container
	var resource: Node = container.get_node_or_null(NodePath(resource_name))
	if is_instance_valid(resource):
		resource.queue_free()
		_schedule_navigation_rebuild()

func _on_start_requested(multiplayer_mode: bool) -> void:
	_multiplayer_mode = multiplayer_mode
	if not multiplayer_mode:
		_resource_abundance = RESOURCE_STANDARD
		_multiplayer_snapshot = _build_single_player_snapshot()
	var settings: Dictionary = _multiplayer_snapshot.get("settings", {}) as Dictionary
	_resource_seed = int(settings.get("resource_seed", 1))
	_reset_game_state()
	_game_started = true
	main_menu.hide()
	lan_lobby.call(&"close_lobby", false)
	pause_menu.show()
	pause_menu.configure(_multiplayer_mode)
	pause_menu.force_close()
	resource_hud.show()
	developer_panel.show()
	ai_controller.configure(not _multiplayer_mode and _ai_peer_id > 0)
	fog_of_war.show()
	get_tree().paused = false
	_refresh_fog()

func _on_multiplayer_requested() -> void:
	main_menu.hide()
	pause_menu.hide()
	resource_hud.hide()
	developer_panel.hide()
	lan_lobby.call(&"open")
	get_tree().paused = true

func _on_lobby_back_requested() -> void:
	main_menu.show()
	get_tree().paused = true

func _on_multiplayer_game_start_requested(snapshot: Dictionary) -> void:
	_multiplayer_snapshot = snapshot.duplicate(true)
	var settings: Dictionary = snapshot.get("settings", {}) as Dictionary
	_resource_abundance = clampi(int(settings.get("resource_abundance", RESOURCE_STANDARD)), RESOURCE_SCARCE, RESOURCE_RICH)
	_resource_seed = int(settings.get("resource_seed", 1))
	_on_start_requested(true)

func _on_return_to_main_menu() -> void:
	_show_main_menu()

func _show_main_menu() -> void:
	_game_started = false
	_multiplayer_snapshot.clear()
	_resource_abundance = RESOURCE_STANDARD
	_resource_seed = 1
	_full_vision = false
	_dragging_selection = false
	_active_player_base = null
	_build_preview_unit_id = 0
	_build_preview_rect = Rect2i()
	_structure_preview_unit_id = 0
	_structure_preview_building_id = &""
	_structure_preview_rect = Rect2i()
	command_overlay.hide_build_preview()
	map_camera.set_process(true)
	_set_selected_units([])
	base_action_menu.close()
	summon_card_menu.close(true)
	pause_menu.force_close()
	pause_menu.hide()
	resource_hud.hide()
	developer_panel.reset()
	developer_panel.hide()
	ai_controller.configure(false)
	world_resource_streamer.call(&"clear_streamed_markers")
	fog_of_war.hide()
	lan_lobby.call(&"close_lobby", true)
	main_menu.show()
	get_tree().paused = true

func _reset_game_state() -> void:
	_clear_children(unit_container)
	_clear_children(building_container)
	_network_units.clear()
	_network_buildings.clear()
	_selected_unit_ids.clear()
	unit_command_panel.hide_selection()
	command_overlay.hide_build_preview()
	_build_preview_unit_id = 0
	_build_preview_rect = Rect2i()
	_structure_preview_unit_id = 0
	_structure_preview_building_id = &""
	_structure_preview_rect = Rect2i()
	_spawn_sequence_by_peer.clear()
	_pending_summon_by_peer_id.clear()
	_next_network_unit_id = 1
	_next_network_building_id = 1
	_next_summon_offer_id = 1
	_card_menu_mode = &""
	_active_summon_offer_id = 0
	_summon_rng.seed = int(_resource_seed) ^ 0x5A17C0DE
	_unit_state_elapsed = 0.0
	_fog_elapsed = 0.0
	_setup_runtime_players(_multiplayer_snapshot)
	_spawn_fair_resources()
	_rebuild_navigation_obstacles()
	_initialize_player_resources()
	_ai_expansion_started = false
	if not _multiplayer_mode and _ai_peer_id > 0:
		_server_recruit_unit(_ai_peer_id, &"lumber")
		_server_recruit_unit(_ai_peer_id, &"quarry")
		_server_recruit_unit(_ai_peer_id, &"explorer")
	base_action_menu.close()
	summon_card_menu.close(true)
	developer_panel.reset()
	var local_rect_index: int = clampi(_local_territory_id - 1, 0, _territory_rects.size() - 1)
	fog_of_war.configure(Vector2i(GRID_SIZE, GRID_SIZE), TILE_SIZE, _territory_rects[local_rect_index])
	map_camera.zoom = LOCAL_TERRITORY_ZOOM
	map_camera.position = _territory_base_position(_local_territory_id)
	world_resource_streamer.call(&"update_streaming", map_camera.position, true)

func _build_single_player_snapshot() -> Dictionary:
	return {
		"settings": {
			"room_name": "单人游戏",
			"resource_abundance": RESOURCE_STANDARD,
			"resource_seed": randi(),
		},
		"players": [{
			"peer_id": 1,
			"name": "玩家",
			"team": 1,
			"slot": 1,
			"territory_id": 1,
			"ready": true,
			"is_host": true,
		}, {
			"peer_id": 2,
			"name": "人机对手",
			"team": 2,
			"slot": 2,
			"territory_id": 2,
			"ready": true,
			"is_host": false,
			"is_ai": true,
		}],
	}

func _on_ai_paused_changed(paused: bool) -> void:
	ai_controller.set_ai_paused(paused)
	for unit: Node2D in _network_units.values():
		if is_instance_valid(unit) and int(unit.get("owner_peer_id")) == _ai_peer_id:
			unit.set_physics_process(not paused)
	unit_command_panel.show_notice("人机操作已暂停" if paused else "人机操作已恢复")

func _on_ai_think() -> void:
	if not _has_gameplay_authority() or _ai_peer_id <= 0:
		return
	var ai_units: Array[Node2D] = []
	var combat_units: Array[int] = []
	var explorer: ExplorerUnit
	for unit: Node2D in _network_units.values():
		if not is_instance_valid(unit) or int(unit.get("owner_peer_id")) != _ai_peer_id:
			continue
		ai_units.append(unit)
		var definition: UnitDefinition = unit.get("definition") as UnitDefinition
		if definition == null:
			continue
		if definition.category == UnitDefinition.Category.COMBAT:
			combat_units.append(int(unit.get("unit_id")))
		elif definition.unit_id == &"explorer":
			explorer = unit as ExplorerUnit
		elif definition.unit_id in [&"lumber", &"quarry"] and int(unit.get("machine_level")) < MachineProgressionData.MAX_LEVEL:
			_server_upgrade_machine(_ai_peer_id, int(unit.get("unit_id")))
	# The AI explores toward open land, then establishes a second base once it arrives.
	if is_instance_valid(explorer):
		var desired_rect: Rect2i = Rect2i(Vector2i(96, 90), Vector2i(TERRITORY_SIZE, TERRITORY_SIZE))
		if _is_valid_expansion_rect(desired_rect):
			var destination: Vector2 = _rect_world_center(desired_rect)
			if explorer.global_position.distance_to(destination) <= 24.0:
				_server_build_base(_ai_peer_id, explorer.unit_id, desired_rect)
			else:
				_server_move_units(_ai_peer_id, [explorer.unit_id], destination)
			_ai_expansion_started = true
	if combat_units.size() < 4:
		_server_purchase_summon(_ai_peer_id)
		var offer: Dictionary = _pending_summon_by_peer_id.get(_ai_peer_id, {}) as Dictionary
		var offer_cards: Array = offer.get("card_ids", []) as Array
		for card_id: Variant in offer_cards:
			var offered_definition: UnitDefinition = UNIT_CATALOG.get_definition(StringName(str(card_id)))
			if offered_definition != null and offered_definition.category == UnitDefinition.Category.COMBAT:
				_server_claim_summon(_ai_peer_id, int(offer.get("offer_id", 0)), offered_definition.unit_id)
				break
	if not combat_units.is_empty():
		_server_move_units(_ai_peer_id, combat_units, _territory_base_position(_local_territory_id))
	_server_upgrade_base(_ai_peer_id)

func _has_gameplay_authority() -> bool:
	return not _multiplayer_mode or multiplayer.is_server()

func _schedule_navigation_rebuild() -> void:
	if _navigation_rebuild_pending:
		return
	_navigation_rebuild_pending = true
	call_deferred(&"_rebuild_navigation_obstacles")

func _rebuild_navigation_obstacles() -> void:
	_navigation_rebuild_pending = false
	var obstacle_roots: Array[Node] = [base_container, building_container, tree_container, stone_container, rare_mineral_container]
	world_pathfinder.rebuild_obstacles(obstacle_roots)

func _clear_children(container: Node) -> void:
	for child: Node in container.get_children():
		child.free()

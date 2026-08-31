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
const TREASURE_CHEST_SCENE: PackedScene = preload("res://game/world/treasure_chest.tscn")
const WILD_MONSTER_SCENE: PackedScene = preload("res://game/world/wild_monster.tscn")
const TERRITORY_SCENE: PackedScene = preload("res://game/world/player_territory.tscn")
const PLAYER_BASE_SCENE: PackedScene = preload("res://game/world/player_base.tscn")
const PRODUCTION_BUILDING_SCENE: PackedScene = preload("res://game/world/production_building.tscn")
const UPGRADE_VFX_SCENE: PackedScene = preload("res://game/world/vfx/upgrade_vfx.tscn")
const UPGRADE_VFX_SCRIPT: Script = preload("res://game/world/vfx/upgrade_vfx.gd")
const UNIT_CATALOG: UnitCatalog = preload("res://game/data/unit_catalog.tres")
const BUILDING_CATALOG: BuildingCatalog = preload("res://game/data/building_catalog.tres")
const UPGRADE_TARGET_BASE: StringName = &"base"
const UPGRADE_TARGET_UNIT: StringName = &"unit"
const UPGRADE_TARGET_BUILDING: StringName = &"building"
const UPGRADE_UNIT_VISUAL_DIAMETER: float = 52.0
const UPGRADE_BUILDING_VISUAL_DIAMETER: float = 84.0
const UPGRADE_BASE_VISUAL_DIAMETER: float = 92.0
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
	Vector2i(7, 5), Vector2i(12, 9), Vector2i(7, 13), Vector2i(16, 15),
]
const RESOURCE_SCARCE: int = 0
const RESOURCE_STANDARD: int = 1
const RESOURCE_RICH: int = 2
const DEVELOPMENT_GOLD: int = 700
const DEVELOPMENT_INFINITE_RESOURCE_AMOUNT: int = 999999
const TREE_WOOD_REWARD: int = 10
const STONE_REWARD: int = 8
const MINERAL_REWARDS: Dictionary = {&"iron": 6}
const CHEST_REWARDS: Dictionary = {"gold": 30, "iron": 2, "summon_token": 1, "skill_experience": 4, "experience": 10}
const MONSTER_DROP_REWARDS: Dictionary = {"iron": 4, "summon_token": 1, "skill_experience": 6, "experience": 20}
const TREE_REGROW_SECONDS: float = 60.0
const HERO_INITIAL_SUMMON_COST: int = 2
const HERO_REPLACEMENT_COST: int = 1
const WILD_MONSTER_CELLS: Array[Vector2i] = [
	Vector2i(87, 69), Vector2i(87, 91), Vector2i(51, 70),
	Vector2i(125, 70), Vector2i(69, 50), Vector2i(105, 50),
]
const AI_EXPANSION_RECT: Rect2i = Rect2i(Vector2i(96, 90), Vector2i(TERRITORY_SIZE, TERRITORY_SIZE))
const AI_SCOUT_OFFSETS_TILES: Array[Vector2i] = [
	Vector2i(0, -32), Vector2i(32, 0), Vector2i(0, 32), Vector2i(-32, 0),
	Vector2i(24, -24), Vector2i(24, 24), Vector2i(-24, 24), Vector2i(-24, -24),
]
const AI_SCOUT_STEP: int = 3
const AI_TARGET_ARRIVAL_DISTANCE: float = 64.0
const BUILDER_ARRIVAL_DISTANCE: float = 6.0
const STREAMED_CHEST_ID_OFFSET: int = 1000000

@onready var ground_layer: TileMapLayer = $Ground
@onready var legacy_base: Sprite2D = $Base
@onready var legacy_base_interaction: Area2D = $BaseInteraction
@onready var base_action_menu: BaseActionMenu = $BaseActionMenu
@onready var map_camera: Camera2D = $MapCamera
@onready var territory_container: Node2D = $Territories
@onready var legacy_test_base_container: Node2D = $TestBases
@onready var base_container: Node2D = $Bases
@onready var building_container: Node2D = $Buildings
@onready var wild_monster_container: Node2D = $WildMonsters
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
@onready var hero_summon_panel: HeroSummonPanel = $HeroSummonPanel
@onready var main_menu: MainMenu = $MainMenu
@onready var lan_lobby: CanvasLayer = $LanLobby
@onready var pause_menu: CanvasLayer = $PauseMenu

var _territory_rects: Array[Rect2i] = []
var _territory_owner_by_id: Dictionary[int, int] = {}
var _player_by_peer_id: Dictionary[int, Dictionary] = {}
var _network_units: Dictionary[int, Node2D] = {}
var _network_buildings: Dictionary[int, ProductionBuilding] = {}
var _pending_structure_job_by_unit_id: Dictionary[int, Dictionary] = {}
var _builder_unit_id_by_building_id: Dictionary[int, int] = {}
var _wild_monsters: Dictionary[int, WildMonster] = {}
var _combat_chests: Dictionary[int, Node2D] = {}
var _selected_unit_ids: Array[int] = []
var _selected_enemy_target: HealthComponent
var _selected_chest_target_id: int = 0
var _spawn_sequence_by_peer: Dictionary[int, int] = {}
var _player_resource_states: Dictionary[int, Dictionary] = {}
var _infinite_resources_by_peer_id: Dictionary[int, bool] = {}
var _base_level_by_peer_id: Dictionary[int, int] = {}
var _player_base_by_peer_id: Dictionary[int, PlayerBase] = {}
var _player_base_by_territory_id: Dictionary[int, PlayerBase] = {}
var _pending_summon_by_peer_id: Dictionary[int, Dictionary] = {}
var _next_network_unit_id: int = 1
var _next_network_building_id: int = 1
var _next_monster_id: int = 1
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
var _active_hero_altar_id: int = 0
var _hero_unit_by_peer_id: Dictionary[int, int] = {}
var _initial_tree_count_by_territory: Dictionary[int, int] = {}
var _tree_regrow_positions_by_territory: Dictionary[int, Array] = {}
var _tree_regrow_elapsed_by_territory: Dictionary[int, float] = {}
var _next_regrown_tree_id: int = 1
var _summon_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _ai_peer_id: int = 0
var _ai_difficulty: int = SimpleAIController.Difficulty.NORMAL
var _ai_expansion_completed: bool = false
var _ai_has_known_enemy: bool = false
var _ai_known_enemy_position: Vector2 = Vector2.ZERO
var _ai_known_enemy_kind: StringName = &""
var _ai_known_enemy_id: int = 0
var _ai_scout_origin: Vector2 = Vector2.ZERO
var _ai_scout_waypoint_index: int = 0
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
	hero_summon_panel.hero_selected.connect(_on_hero_panel_selected)
	hero_summon_panel.closed.connect(_on_hero_panel_closed)
	developer_panel.full_vision_changed.connect(_on_full_vision_changed)
	developer_panel.ai_paused_changed.connect(_on_ai_paused_changed)
	developer_panel.infinite_resources_changed.connect(_on_infinite_resources_changed)
	unit_command_panel.work_toggled.connect(_on_machine_work_toggled)
	unit_command_panel.upgrade_requested.connect(_on_machine_upgrade_requested)
	unit_command_panel.build_preview_requested.connect(_on_build_preview_requested)
	unit_command_panel.build_confirmed.connect(_on_build_confirmed)
	unit_command_panel.build_cancelled.connect(_cancel_build_preview)
	unit_command_panel.structure_preview_requested.connect(_on_structure_preview_requested)
	unit_command_panel.structure_confirmed.connect(_on_structure_confirmed)
	unit_command_panel.structure_cancelled.connect(_cancel_structure_preview)
	unit_command_panel.hero_level_up_requested.connect(_on_hero_level_up_requested)
	unit_command_panel.hero_skill_up_requested.connect(_on_hero_skill_up_requested)
	unit_command_panel.hero_cast_requested.connect(_on_hero_cast_requested)
	unit_command_panel.building_upgrade_requested.connect(_on_building_upgrade_requested)
	unit_command_panel.building_demolish_requested.connect(_on_building_demolish_requested)
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
	_update_selected_hero_cooldown_ui()
	if bool(world_resource_streamer.call(&"update_streaming", map_camera.position)):
		_refresh_entity_visibility()
	if _has_gameplay_authority():
		_process_tree_regrowth(delta)
		_process_pending_structure_jobs()
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
	if _build_preview_unit_id > 0 and event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo and _try_nudge_build_preview(key_event.physical_keycode):
			get_viewport().set_input_as_handled()
		return
	if _structure_preview_unit_id > 0 and event is InputEventKey:
		var structure_key_event: InputEventKey = event as InputEventKey
		if structure_key_event.pressed and not structure_key_event.echo and _try_nudge_structure_preview(structure_key_event.physical_keycode):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		var hero_key_event: InputEventKey = event as InputEventKey
		if hero_key_event.pressed and not hero_key_event.echo and _try_activate_hero_hotkey(hero_key_event):
			get_viewport().set_input_as_handled()
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
		_cancel_pending_hero_skill()
		_handle_move_command(get_global_mouse_position())

func _handle_left_mouse(event: InputEventMouseButton) -> void:
	if event.pressed:
		if _pointer_is_over_blocking_ui():
			return
		if _try_cast_pending_hero_skill(get_global_mouse_position()):
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

func _cancel_pending_hero_skill() -> void:
	for unit_id: int in _selected_unit_ids:
		var unit: Node2D = _network_units.get(unit_id) as Node2D
		if is_instance_valid(unit) and unit.has_meta(&"pending_hero_skill"):
			unit.remove_meta(&"pending_hero_skill")
	unit_command_panel.set_active_hero_skill(&"")

func _try_activate_hero_hotkey(event: InputEventKey) -> bool:
	var keycode: int = int(event.keycode)
	if unit_command_panel.activate_hero_skill_hotkey(keycode):
		return true
	var physical_keycode: int = int(event.physical_keycode)
	return physical_keycode != keycode and unit_command_panel.activate_hero_skill_hotkey(physical_keycode)

func _try_cast_pending_hero_skill(target_position: Vector2) -> bool:
	if _selected_unit_ids.size() != 1:
		return false
	var unit: Node2D = _network_units.get(_selected_unit_ids[0]) as Node2D
	if not is_instance_valid(unit) or not unit.has_meta(&"pending_hero_skill"):
		return false
	var skill_id: StringName = unit.get_meta(&"pending_hero_skill") as StringName
	if _has_gameplay_authority():
		if _server_cast_hero_skill(_local_peer_id, int(unit.get("unit_id")), skill_id, target_position):
			unit.remove_meta(&"pending_hero_skill")
			unit_command_panel.set_active_hero_skill(&"")
	else:
		_rpc_request_cast_hero_skill.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, int(unit.get("unit_id")), str(skill_id), target_position)
		unit.remove_meta(&"pending_hero_skill")
		unit_command_panel.set_active_hero_skill(&"")
	return true

func _handle_move_command(target_position: Vector2) -> void:
	if _selected_unit_ids.is_empty() or _pointer_is_over_blocking_ui():
		return
	var chest_target: Dictionary = _find_attackable_chest_at(target_position)
	if not chest_target.is_empty():
		var chest_id: int = int(chest_target.get("chest_id", 0))
		var chest_root: Node2D = chest_target.get("root") as Node2D
		var chest_health: HealthComponent = chest_root.get_node_or_null("HealthComponent") as HealthComponent
		if is_instance_valid(chest_health):
			_set_selected_enemy_target(chest_health)
		else:
			_selected_enemy_target = null
			_selected_chest_target_id = chest_id
			command_overlay.show_attack_target(chest_root, 20.0)
		_request_selected_units_attack_identity(&"chest", chest_id)
		return
	var enemy_target: HealthComponent = _find_enemy_damageable_at(target_position, _local_peer_id)
	if is_instance_valid(enemy_target):
		_set_selected_enemy_target(enemy_target)
		_request_selected_units_attack(enemy_target)
		return
	_clear_selected_enemy_target()
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
	_combat_chests.clear()
	_selected_chest_target_id = 0
	_initial_tree_count_by_territory.clear()
	_tree_regrow_positions_by_territory.clear()
	_tree_regrow_elapsed_by_territory.clear()
	_clear_children(tree_container)
	_clear_children(stone_container)
	_clear_children(rare_mineral_container)
	var tree_cells: Array[Vector2i] = _get_tree_cells_for_abundance()
	var stone_cells: Array[Vector2i] = _get_stone_cells_for_abundance()
	var mineral_layout: Array[Dictionary] = _build_rare_mineral_layout(tree_cells, stone_cells)
	for territory_index: int in _territory_rects.size():
		var territory_id: int = territory_index + 1
		_initial_tree_count_by_territory[territory_id] = tree_cells.size()
		_tree_regrow_positions_by_territory[territory_id] = []
		_tree_regrow_elapsed_by_territory[territory_id] = 0.0
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
			if resource_type == &"chest":
				_register_combat_chest(mineral, territory_id * 1000 + resource_index + 1)
	_spawn_world_resources()

func _spawn_world_resources() -> void:
	world_resource_streamer.call(&"regenerate", _resource_seed, _resource_abundance, _territory_rects)
	world_pathfinder.set_external_obstacles(world_resource_streamer.get_navigation_obstacle_cells())
	if Engine.is_editor_hint():
		world_resource_streamer.call(&"update_streaming", map_camera.position, true)

func _build_rare_mineral_layout(tree_cells: Array[Vector2i], stone_cells: Array[Vector2i]) -> Array[Dictionary]:
	var occupied: Dictionary = {}
	for cell: Vector2i in tree_cells:
		occupied[cell] = true
		occupied[cell + Vector2i.UP] = true
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
		types.append(&"chest")
	var layout: Array[Dictionary] = []
	for index: int in mini(types.size(), candidates.size()):
		layout.append({"resource_type": types[index], "cell": candidates[index]})
	return layout

func _rare_mineral_counts() -> PackedInt32Array:
	match _resource_abundance:
		RESOURCE_SCARCE:
			return PackedInt32Array([3, 1])
		RESOURCE_RICH:
			return PackedInt32Array([8, 3])
		_:
			return PackedInt32Array([5, 2])

func _mineral_scene_for(resource_type: StringName) -> PackedScene:
	match resource_type:
		&"chest": return TREASURE_CHEST_SCENE
		_: return IRON_DEPOSIT_SCENE

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
	hero_summon_panel.close()
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

func _on_hero_panel_selected(hero_definition_id: StringName) -> void:
	if _active_hero_altar_id > 0:
		_request_altar_hero(_active_hero_altar_id, hero_definition_id)
	_active_hero_altar_id = 0

func _on_hero_panel_closed() -> void:
	_active_hero_altar_id = 0

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
		_notify_peer(owner_peer_id, "召唤失败：金币不足，需要%d" % BaseProgression.SUMMON_COST)
		return false
	var level: int = int(_base_level_by_peer_id.get(owner_peer_id, 1))
	var cards: Array[UnitDefinition] = UNIT_CATALOG.build_summon_cards(level, BaseProgression.SUMMON_CARD_COUNT, _summon_rng)
	if cards.size() != BaseProgression.SUMMON_CARD_COUNT:
		_notify_peer(owner_peer_id, "召唤失败：战斗单位卡池配置不完整")
		return false
	state["gold"] = int(state.get("gold", 0)) - BaseProgression.SUMMON_COST
	_player_resource_states[owner_peer_id] = state
	_send_resource_state(owner_peer_id, state)
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
	_broadcast_upgrade_visual(UPGRADE_TARGET_BASE, owner_peer_id)
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
	return "消耗%d金币，获得%d张战斗单位卡牌\n支付后必须选择一张\nLv.%d：%s\n英雄台仍可消耗召唤符定向选择英雄" % [
		BaseProgression.SUMMON_COST, BaseProgression.SUMMON_CARD_COUNT,
		level, BaseProgression.probability_summary(level),
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
		"star_level": 1,
		"hero_level": 1,
		"skill_levels": {},
	}
	_next_network_unit_id += 1
	_spawn_sequence_by_peer[owner_peer_id] = sequence + 1
	_spawn_network_unit(spawn_data)
	if _multiplayer_mode:
		_rpc_spawn_unit.rpc(spawn_data)
	if definition.category == UnitDefinition.Category.COMBAT:
		_resolve_forced_combat_unit_fusions(owner_peer_id, unit_definition_id)
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
	var combat_unit: TreantUnit = unit as TreantUnit
	if definition.category == UnitDefinition.Category.COMBAT or definition.category == UnitDefinition.Category.HERO or definition.unit_id in [&"explorer", &"builder"]:
		unit.call(&"configure_network", network_unit_id, owner_peer_id, territory_id, definition, _has_gameplay_authority())
		if unit.has_method(&"setup_navigation"):
			unit.call(&"setup_navigation", world_pathfinder.find_path)
	else:
		unit.call(&"configure_network", network_unit_id, owner_peer_id, definition)
		var resource_container: Node2D = tree_container if definition.unit_id == &"lumber" else mineable_container
		unit.call(&"setup", resource_container, territory_id, _has_gameplay_authority(), world_pathfinder.find_path)
	if definition.category == UnitDefinition.Category.COMBAT and combat_unit != null:
		combat_unit.set_star_level(int(spawn_data.get("star_level", 1)))
	_apply_unit_faction_tint(unit, owner_peer_id)
	_network_units[network_unit_id] = unit
	var unit_max_health: float = float(definition.max_health)
	var unit_defense: float = float(definition.defense)
	if definition.category == UnitDefinition.Category.COMBAT and combat_unit != null:
		unit_max_health = combat_unit.get_effective_max_health()
		unit_defense = combat_unit.get_effective_defense()
	_attach_vitals(
		unit, owner_peer_id, unit_max_health, unit_defense, definition.evasion_chance,
		float(definition.max_mana), definition.mana_regen_per_second, Vector2(0.0, -24.0), 30.0, &"unit", network_unit_id
	)
	if definition.category == UnitDefinition.Category.COMBAT or definition.category == UnitDefinition.Category.HERO:
		if combat_unit != null:
			if definition.category == UnitDefinition.Category.HERO and combat_unit.has_method(&"set_hero_progression"):
				combat_unit.call(&"set_hero_progression", int(spawn_data.get("hero_level", 1)), spawn_data.get("skill_levels", {}) as Dictionary)
			combat_unit.setup_combat_context(
				_get_enemy_damageables.bind(owner_peer_id),
				_get_friendly_damageables.bind(owner_peer_id),
				world_pathfinder.find_path,
				TILE_SIZE
			)
			combat_unit.attack_visual_requested.connect(_on_unit_attack_visual_requested)
			combat_unit.skill_visual_requested.connect(_on_unit_skill_visual_requested)

func _resolve_forced_combat_unit_fusions(owner_peer_id: int, definition_id: StringName) -> void:
	if not _has_gameplay_authority():
		return
	var definition: UnitDefinition = UNIT_CATALOG.get_definition(definition_id)
	if definition == null or definition.category != UnitDefinition.Category.COMBAT:
		return
	while true:
		var fusion_star_level: int = 0
		var candidates: Array[TreantUnit] = []
		for candidate_star_level: int in range(1, TreantUnit.MAX_STAR_LEVEL):
			candidates.clear()
			for unit: Node2D in _network_units.values():
				var combat_candidate: TreantUnit = unit as TreantUnit
				if not is_instance_valid(combat_candidate):
					continue
				if combat_candidate.owner_peer_id != owner_peer_id or combat_candidate.definition != definition:
					continue
				if combat_candidate.star_level == candidate_star_level:
					candidates.append(combat_candidate)
			if candidates.size() >= 3:
				fusion_star_level = candidate_star_level
				break
		if fusion_star_level <= 0:
			return
		candidates.sort_custom(_sort_combat_units_by_id)
		var survivor: TreantUnit = candidates[0]
		var consumed_ids: PackedInt32Array = PackedInt32Array([candidates[1].unit_id, candidates[2].unit_id])
		var merged_health: float = 0.0
		var merged_mana: float = 0.0
		for source_index: int in 3:
			var source_health: HealthComponent = candidates[source_index].get_node_or_null("HealthComponent") as HealthComponent
			if is_instance_valid(source_health):
				merged_health += source_health.current_health
				merged_mana += source_health.current_mana
		var new_star_level: int = fusion_star_level + 1
		_apply_combat_unit_fusion(survivor.unit_id, consumed_ids, new_star_level, merged_health, merged_mana)
		if _multiplayer_mode:
			_rpc_apply_combat_unit_fusion.rpc(survivor.unit_id, consumed_ids, new_star_level, merged_health, merged_mana)
		_notify_peer(owner_peer_id, "%s已强制融合为%d星" % [definition.display_name, new_star_level])

func _sort_combat_units_by_id(first: TreantUnit, second: TreantUnit) -> bool:
	return first.unit_id < second.unit_id

@rpc("authority", "call_remote", "reliable")
func _rpc_apply_combat_unit_fusion(
	survivor_id: int,
	consumed_ids: PackedInt32Array,
	new_star_level: int,
	merged_health: float,
	merged_mana: float
) -> void:
	_apply_combat_unit_fusion(survivor_id, consumed_ids, new_star_level, merged_health, merged_mana)

func _apply_combat_unit_fusion(
	survivor_id: int,
	consumed_ids: PackedInt32Array,
	new_star_level: int,
	merged_health: float,
	merged_mana: float
) -> void:
	var survivor: TreantUnit = _network_units.get(survivor_id) as TreantUnit
	if not is_instance_valid(survivor) or survivor.definition == null or survivor.definition.category != UnitDefinition.Category.COMBAT:
		return
	var retain_selection: bool = _selected_unit_ids.has(survivor_id)
	for consumed_id: int in consumed_ids:
		retain_selection = retain_selection or _selected_unit_ids.has(consumed_id)
		_remove_damageable(&"unit", consumed_id)
	survivor.set_star_level(new_star_level)
	var health: HealthComponent = survivor.get_node_or_null("HealthComponent") as HealthComponent
	if is_instance_valid(health):
		health.apply_network_state(merged_health, merged_mana)
	if retain_selection and not _selected_unit_ids.has(survivor_id):
		_selected_unit_ids.append(survivor_id)
	_refresh_unit_command_panel()
	_play_upgrade_visual(UPGRADE_TARGET_UNIT, survivor_id)

func _on_unit_attack_visual_requested(network_unit_id: int, target_position: Vector2) -> void:
	if not _has_gameplay_authority() or not _multiplayer_mode:
		return
	_rpc_play_unit_attack_visual.rpc(network_unit_id, target_position)

@rpc("authority", "call_remote", "reliable")
func _rpc_play_unit_attack_visual(network_unit_id: int, target_position: Vector2) -> void:
	var unit: TreantUnit = _network_units.get(network_unit_id) as TreantUnit
	if is_instance_valid(unit):
		unit.play_attack_visual(target_position)

func _on_unit_skill_visual_requested(network_unit_id: int, skill_id: StringName, target_position: Vector2, target_kind: StringName, target_id: int) -> void:
	if not _has_gameplay_authority() or not _multiplayer_mode:
		return
	_rpc_play_unit_skill_visual.rpc(network_unit_id, str(skill_id), target_position, str(target_kind), target_id)

@rpc("authority", "call_remote", "reliable")
func _rpc_play_unit_skill_visual(network_unit_id: int, skill_id_value: String, target_position: Vector2, target_kind_value: String = "", target_id: int = 0) -> void:
	var unit: TreantUnit = _network_units.get(network_unit_id) as TreantUnit
	if is_instance_valid(unit):
		var skill_id: StringName = StringName(skill_id_value)
		if unit is HeroUnit:
			var hero: HeroUnit = unit as HeroUnit
			var definition: UnitDefinition = hero.definition
			var skill: Resource = definition.call(&"get_hero_skill", skill_id) as Resource if definition != null else null
			if skill != null:
				hero.begin_skill_cooldown(skill_id, float(skill.get("cooldown_seconds")))
			var target_root: Node2D = _resolve_skill_visual_target(StringName(target_kind_value), target_id)
			if is_instance_valid(target_root):
				hero.play_skill_visual_on_target(skill_id, target_root, target_position)
			return
		unit.play_skill_visual(skill_id, target_position)

func _on_monster_attack_visual_requested(monster_id: int, target_position: Vector2) -> void:
	if not _has_gameplay_authority() or not _multiplayer_mode:
		return
	_rpc_play_monster_attack_visual.rpc(monster_id, target_position)

@rpc("authority", "call_remote", "reliable")
func _rpc_play_monster_attack_visual(monster_id: int, target_position: Vector2) -> void:
	var monster: WildMonster = _wild_monsters.get(monster_id) as WildMonster
	if is_instance_valid(monster):
		monster.play_attack_visual(target_position)

func _on_monster_skill_visual_requested(monster_id: int, target_position: Vector2) -> void:
	if not _has_gameplay_authority() or not _multiplayer_mode:
		return
	_rpc_play_monster_skill_visual.rpc(monster_id, target_position)

@rpc("authority", "call_remote", "reliable")
func _rpc_play_monster_skill_visual(monster_id: int, target_position: Vector2) -> void:
	var monster: WildMonster = _wild_monsters.get(monster_id) as WildMonster
	if is_instance_valid(monster):
		monster.play_skill_visual(target_position)

func _resolve_skill_visual_target(target_kind: StringName, target_id: int) -> Node2D:
	match target_kind:
		&"unit":
			return _network_units.get(target_id) as Node2D
		&"building":
			return _network_buildings.get(target_id) as Node2D
		&"base":
			return _player_base_by_territory_id.get(target_id) as Node2D
		&"monster":
			return _wild_monsters.get(target_id) as Node2D
	return null

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
		_apply_selected_enemy_target_to_units()
		return
	var enemy_target: HealthComponent = _find_enemy_damageable_at(world_position, _local_peer_id)
	if is_instance_valid(enemy_target):
		_set_selected_enemy_target(enemy_target)
		_request_selected_units_attack(enemy_target)
		return
	_clear_selected_enemy_target()
	_set_selected_units([])

func _select_units_in_rect(selection_rect: Rect2) -> void:
	var selected_ids: Array[int] = []
	for network_unit_id: int in _network_units.keys():
		var unit: Node2D = _network_units[network_unit_id]
		if _is_local_combat_unit(unit) and selection_rect.has_point(unit.global_position):
			selected_ids.append(network_unit_id)
	selected_ids.sort()
	_set_selected_units(selected_ids)
	_apply_selected_enemy_target_to_units()

func _set_selected_units(unit_ids: Array[int]) -> void:
	_cancel_pending_hero_skill()
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
	elif definition.category == UnitDefinition.Category.HERO:
		unit_command_panel.show_hero(int(unit.get("unit_id")), definition, int(unit.get("hero_level")), unit.get("skill_levels") as Dictionary)
		unit_command_panel.set_active_hero_skill(unit.get_meta(&"pending_hero_skill", &"") as StringName)
		unit_command_panel.update_hero_skill_cooldowns(unit.get("skill_cooldowns") as Dictionary)
	else:
		unit_command_panel.hide_selection()

func _update_selected_hero_cooldown_ui() -> void:
	if _selected_unit_ids.size() != 1:
		return
	var hero: HeroUnit = _network_units.get(_selected_unit_ids[0]) as HeroUnit
	if not is_instance_valid(hero):
		return
	unit_command_panel.update_hero_skill_cooldowns(hero.skill_cooldowns)

func _is_local_combat_unit(unit: Node2D) -> bool:
	return is_instance_valid(unit) and int(unit.get("owner_peer_id")) == _local_peer_id and not bool(unit.get_meta(&"construction_busy", false))

func _find_enemy_damageable_at(world_position: Vector2, requesting_peer_id: int) -> HealthComponent:
	var nearest: HealthComponent
	var nearest_distance: float = INF
	for candidate: HealthComponent in _all_damageables():
		if candidate.owner_peer_id == requesting_peer_id or not _are_peers_hostile(requesting_peer_id, candidate.owner_peer_id):
			continue
		if not is_instance_valid(candidate.target_root) or not candidate.target_root.is_visible_in_tree():
			continue
		var pick_radius: float = maxf(18.0, candidate.combat_radius)
		var distance: float = candidate.get_target_position().distance_squared_to(world_position)
		if distance <= pick_radius * pick_radius and distance < nearest_distance:
			nearest_distance = distance
			nearest = candidate
	return nearest

func _find_attackable_chest_at(world_position: Vector2) -> Dictionary:
	var nearest: Dictionary = {}
	var nearest_distance: float = INF
	for chest_id: int in _combat_chests.keys():
		var chest: Node2D = _combat_chests.get(chest_id) as Node2D
		if not is_instance_valid(chest) or not chest.is_visible_in_tree():
			continue
		var health: HealthComponent = chest.get_node_or_null("HealthComponent") as HealthComponent
		if not is_instance_valid(health) or not health.is_alive():
			continue
		var distance: float = (chest.global_position + Vector2(0.0, -16.0)).distance_squared_to(world_position)
		if distance <= 24.0 * 24.0 and distance < nearest_distance:
			nearest_distance = distance
			nearest = {"chest_id": chest_id, "root": chest}
	for child: Node in rare_mineral_container.get_children():
		var marker: Node2D = child as Node2D
		if not is_instance_valid(marker) or marker.get_script() != WORLD_RESOURCE_MARKER_SCRIPT:
			continue
		if StringName(str(marker.get("resource_type"))) != &"chest" or not marker.is_visible_in_tree():
			continue
		var distance: float = (marker.global_position + Vector2(0.0, -16.0)).distance_squared_to(world_position)
		if distance <= 24.0 * 24.0 and distance < nearest_distance:
			nearest_distance = distance
			nearest = {
				"chest_id": STREAMED_CHEST_ID_OFFSET + int(marker.get("resource_id")),
				"root": marker,
			}
	return nearest

func _set_selected_enemy_target(target: HealthComponent) -> void:
	_selected_enemy_target = target
	if is_instance_valid(target) and is_instance_valid(target.target_root):
		_selected_chest_target_id = int(target.target_root.get_meta(&"damageable_id", 0)) if target.target_root.get_meta(&"damageable_kind", &"") == &"chest" else 0
		command_overlay.show_attack_target(target.target_root, target.combat_radius)

func _clear_selected_enemy_target() -> void:
	_selected_enemy_target = null
	_selected_chest_target_id = 0
	command_overlay.clear_attack_target()

func _apply_selected_enemy_target_to_units() -> void:
	if is_instance_valid(_selected_enemy_target) and _selected_enemy_target.is_alive():
		_request_selected_units_attack(_selected_enemy_target)

func _request_selected_units_attack(target: HealthComponent) -> void:
	if _selected_unit_ids.is_empty() or not is_instance_valid(target) or not is_instance_valid(target.target_root):
		return
	var target_kind: StringName = target.target_root.get_meta(&"damageable_kind", &"") as StringName
	var target_id: int = int(target.target_root.get_meta(&"damageable_id", 0))
	if target_kind == &"" or target_id <= 0:
		return
	_request_selected_units_attack_identity(target_kind, target_id)

func _request_selected_units_attack_identity(target_kind: StringName, target_id: int) -> void:
	if _selected_unit_ids.is_empty() or target_kind.is_empty() or target_id <= 0:
		return
	if _has_gameplay_authority():
		if _server_attack_target(_local_peer_id, _selected_unit_ids, target_kind, target_id):
			var resolved_target: HealthComponent = _get_damageable_by_identity(target_kind, target_id)
			if is_instance_valid(resolved_target):
				_set_selected_enemy_target(resolved_target)
	else:
		_rpc_request_attack_target.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, _selected_unit_ids, str(target_kind), target_id)

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
	_broadcast_upgrade_visual(UPGRADE_TARGET_UNIT, unit_id)
	_notify_peer(owner_peer_id, "机器已升级至 Lv.%d" % next_level)
	if owner_peer_id == _local_peer_id:
		_refresh_unit_command_panel()
	return true

func _on_hero_level_up_requested(unit_id: int) -> void:
	_request_hero_upgrade(unit_id, &"")

func _on_hero_skill_up_requested(unit_id: int, skill_id: StringName = &"you_jiao_wu_lei") -> void:
	_request_hero_upgrade(unit_id, skill_id)

func _on_hero_cast_requested(unit_id: int, skill_id: StringName) -> void:
	var unit: Node2D = _network_units.get(unit_id) as Node2D
	if not is_instance_valid(unit) or int(unit.get("owner_peer_id")) != _local_peer_id:
		unit_command_panel.set_active_hero_skill(&"")
		return
	var definition: UnitDefinition = unit.get("definition") as UnitDefinition
	var skill: Resource = definition.call(&"get_hero_skill", skill_id) as Resource if definition != null else null
	if skill == null:
		unit_command_panel.set_active_hero_skill(&"")
		return
	unit.set_meta(&"pending_hero_skill", skill_id)
	unit_command_panel.set_active_hero_skill(skill_id)
	unit_command_panel.show_notice("%s：左键选择目标，右键取消" % str(skill.get("display_name")))

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_cast_hero_skill(unit_id: int, skill_id_value: String, target_position: Vector2) -> void:
	if _has_gameplay_authority():
		_server_cast_hero_skill(multiplayer.get_remote_sender_id(), unit_id, StringName(skill_id_value), target_position)

func _server_cast_hero_skill(owner_peer_id: int, unit_id: int, skill_id: StringName, target_position: Vector2) -> bool:
	var hero: HeroUnit = _network_units.get(unit_id) as HeroUnit
	var definition: UnitDefinition = hero.get("definition") as UnitDefinition if is_instance_valid(hero) else null
	if not is_instance_valid(hero) or definition == null or definition.category != UnitDefinition.Category.HERO or int(hero.get("owner_peer_id")) != owner_peer_id:
		return false
	var skill: Resource = definition.call(&"get_hero_skill", skill_id) as Resource
	var health: HealthComponent = hero.get_node_or_null("HealthComponent") as HealthComponent
	if skill == null or not is_instance_valid(health) or not health.is_alive():
		return false
	if hero.get_skill_cooldown(skill_id) > 0.0:
		_notify_peer(owner_peer_id, "技能正在冷却")
		return false
	var cast_range: float = float(skill.get("cast_range_tiles")) * TILE_SIZE
	if hero.global_position.distance_to(target_position) > cast_range:
		_notify_peer(owner_peer_id, "目标超出施法范围")
		return false
	if health.current_mana + 0.001 < float(skill.get("mana_cost")):
		_notify_peer(owner_peer_id, "魔法不足")
		return false
	var friendly_target: HealthComponent
	var travel_path: PackedVector2Array = PackedVector2Array()
	var visual_target_position: Vector2 = target_position
	match skill_id:
		&"ren_zhe_ai_ren":
			friendly_target = _find_friendly_damageable_at(target_position, owner_peer_id)
			if not is_instance_valid(friendly_target):
				friendly_target = health
			visual_target_position = friendly_target.get_target_position()
		&"li_yue_jiao_hua":
			pass
		&"zhou_you_lie_guo":
			travel_path = world_pathfinder.find_path(hero.global_position, target_position)
			if travel_path.is_empty():
				_notify_peer(owner_peer_id, "该位置不可到达")
				return false
		_:
			return false
	if not health.spend_mana(float(skill.get("mana_cost"))):
		return false
	var level: int = hero.get_skill_level(skill_id)
	var ritual_visual_count: int = 0
	match skill_id:
		&"ren_zhe_ai_ren":
			friendly_target.heal(friendly_target.max_health * float(skill.call(&"value_at", level)) / 100.0)
			hero.play_and_request_skill_visual_on_target(skill_id, friendly_target.target_root, visual_target_position)
		&"li_yue_jiao_hua":
			ritual_visual_count = _apply_confucius_ritual_field(hero, skill, level, target_position)
		&"zhou_you_lie_guo":
			hero.begin_travel(travel_path, travel_path[travel_path.size() - 1])
			hero.play_and_request_skill_visual_on_target(skill_id, hero, target_position)
	hero.begin_skill_cooldown(skill_id, float(skill.get("cooldown_seconds")))
	if skill_id == &"li_yue_jiao_hua" and ritual_visual_count == 0:
		hero.skill_visual_requested.emit(unit_id, skill_id, target_position, &"", 0)
	return true

func _apply_confucius_ritual_field(hero: HeroUnit, skill: Resource, level: int, target_position: Vector2) -> int:
	var radius_squared: float = pow(float(skill.get("radius_tiles")) * TILE_SIZE, 2.0)
	var control_duration: float = float(skill.call(&"value_at", level))
	var defense_bonus: float = float(skill.call(&"secondary_value_at", level))
	var defense_duration: float = float(skill.get("effect_duration_seconds"))
	var source_id: StringName = StringName("confucius_w_%d" % hero.unit_id)
	var visual_count: int = 0
	for enemy: HealthComponent in _get_enemy_damageables(hero.owner_peer_id):
		if target_position.distance_squared_to(enemy.get_target_position()) > radius_squared:
			continue
		var enemy_root: Node2D = enemy.target_root
		if is_instance_valid(enemy_root) and enemy_root.has_method(&"apply_control"):
			enemy_root.call(&"apply_control", control_duration)
	for ally: HealthComponent in _get_friendly_damageables(hero.owner_peer_id):
		if target_position.distance_squared_to(ally.get_target_position()) <= radius_squared:
			ally.apply_temporary_defense_bonus(source_id, defense_bonus, defense_duration)
			if is_instance_valid(ally.target_root):
				hero.play_and_request_skill_visual_on_target(HeroUnit.CONFUCIUS_W_ID, ally.target_root, ally.target_root.global_position)
				visual_count += 1
	return visual_count

func _find_friendly_damageable_at(world_position: Vector2, owner_peer_id: int) -> HealthComponent:
	var closest: HealthComponent
	var closest_distance: float = INF
	for candidate: HealthComponent in _get_friendly_damageables(owner_peer_id):
		var distance: float = candidate.get_target_position().distance_squared_to(world_position)
		if distance < closest_distance and distance <= 28.0 * 28.0:
			closest = candidate
			closest_distance = distance
	return closest

func _request_hero_upgrade(unit_id: int, skill_id: StringName) -> void:
	if _has_gameplay_authority():
		_server_upgrade_hero(_local_peer_id, unit_id, skill_id)
	else:
		_rpc_request_hero_upgrade.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, unit_id, str(skill_id))

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_hero_upgrade(unit_id: int, skill_id_value: String) -> void:
	if _has_gameplay_authority():
		_server_upgrade_hero(multiplayer.get_remote_sender_id(), unit_id, StringName(skill_id_value))

func _server_upgrade_hero(owner_peer_id: int, unit_id: int, skill_id: StringName) -> bool:
	var unit: Node2D = _network_units.get(unit_id) as Node2D
	var definition: UnitDefinition = unit.get("definition") as UnitDefinition if is_instance_valid(unit) else null
	if not is_instance_valid(unit) or int(unit.get("owner_peer_id")) != owner_peer_id or definition == null or definition.category != UnitDefinition.Category.HERO:
		return false
	if not _player_resource_states.has(owner_peer_id):
		return false
	var skill_upgrade: bool = not skill_id.is_empty()
	var current_level: int = int(unit.call(&"get_skill_level", skill_id)) if skill_upgrade else int(unit.get("hero_level"))
	var cost: int = HeroProgression.skill_level_cost(current_level) if skill_upgrade else HeroProgression.hero_level_cost(current_level)
	if cost <= 0:
		_notify_peer(owner_peer_id, "技能已满级" if skill_upgrade else "英雄已满级")
		return false
	var resource_id: String = "skill_experience" if skill_upgrade else "experience"
	var state: Dictionary = (_player_resource_states[owner_peer_id] as Dictionary).duplicate(true)
	if int(state.get(resource_id, 0)) < cost:
		_notify_peer(owner_peer_id, "%s不足，需要%d" % ["技能经验" if skill_upgrade else "经验", cost])
		return false
	state[resource_id] = int(state.get(resource_id, 0)) - cost
	_player_resource_states[owner_peer_id] = state
	_send_resource_state(owner_peer_id, state)
	var next_hero_level: int = int(unit.get("hero_level")) if skill_upgrade else int(unit.get("hero_level")) + 1
	var skill_levels: Dictionary = unit.get("skill_levels") as Dictionary
	if skill_upgrade:
		skill_levels[skill_id] = current_level + 1
	unit.call(&"set_hero_progression", next_hero_level, skill_levels)
	if _multiplayer_mode:
		_rpc_apply_hero_progression.rpc(unit_id, next_hero_level, skill_levels)
	_broadcast_upgrade_visual(UPGRADE_TARGET_UNIT, unit_id)
	_notify_peer(owner_peer_id, "%s已升至 Lv.%d" % ["技能" if skill_upgrade else "英雄", current_level + 1])
	if owner_peer_id == _local_peer_id:
		_refresh_unit_command_panel()
	return true

@rpc("authority", "call_remote", "reliable")
func _rpc_apply_hero_progression(unit_id: int, hero_level: int, skill_levels: Dictionary) -> void:
	var unit: Node2D = _network_units.get(unit_id) as Node2D
	if is_instance_valid(unit) and unit.has_method(&"set_hero_progression"):
		unit.call(&"set_hero_progression", hero_level, skill_levels)

func _on_building_upgrade_requested(building_id: int) -> void:
	if _has_gameplay_authority():
		_server_upgrade_building(_local_peer_id, building_id)
	else:
		_rpc_request_building_upgrade.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, building_id)

func _on_building_demolish_requested(building_id: int) -> void:
	if _has_gameplay_authority():
		_server_demolish_building(_local_peer_id, building_id)
	else:
		_rpc_request_demolish_building.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, building_id)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_demolish_building(building_id: int) -> void:
	if _has_gameplay_authority():
		_server_demolish_building(multiplayer.get_remote_sender_id(), building_id)

func _server_demolish_building(owner_peer_id: int, building_id: int) -> bool:
	var building: ProductionBuilding = _network_buildings.get(building_id) as ProductionBuilding
	if not is_instance_valid(building) or building.owner_peer_id != owner_peer_id or not building.construction_complete or building.definition.interaction_type == &"hero_altar":
		return false
	var state: Dictionary = (_player_resource_states.get(owner_peer_id, {}) as Dictionary).duplicate(true)
	var pending: int = building.take_pending_amount()
	if pending > 0 and not building.definition.production_resource_type.is_empty():
		var produced: StringName = building.definition.production_resource_type
		state[produced] = int(state.get(produced, 0)) + pending
	for resource_id: StringName in building.definition.build_cost.keys():
		state[resource_id] = int(state.get(resource_id, 0)) + floori(float(building.definition.build_cost[resource_id]) * 0.5)
	_player_resource_states[owner_peer_id] = state
	_send_resource_state(owner_peer_id, state)
	_remove_damageable(&"building", building_id)
	if _multiplayer_mode:
		_rpc_remove_damageable.rpc("building", building_id)
	_notify_peer(owner_peer_id, "已拆除%s，并返还一半初始材料" % building.definition.display_name)
	return true

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_building_upgrade(building_id: int) -> void:
	if _has_gameplay_authority():
		_server_upgrade_building(multiplayer.get_remote_sender_id(), building_id)

func _server_upgrade_building(owner_peer_id: int, building_id: int) -> bool:
	var building: ProductionBuilding = _network_buildings.get(building_id) as ProductionBuilding
	if not is_instance_valid(building) or building.owner_peer_id != owner_peer_id or not building.construction_complete:
		return false
	var cost: int = building.get_upgrade_iron_cost()
	if cost <= 0:
		_notify_peer(owner_peer_id, "建筑已经满级")
		return false
	var state: Dictionary = (_player_resource_states.get(owner_peer_id, {}) as Dictionary).duplicate(true)
	if int(state.get("iron", 0)) < cost:
		_notify_peer(owner_peer_id, "建筑升级失败：需要铁%d" % cost)
		return false
	state["iron"] = int(state.get("iron", 0)) - cost
	_player_resource_states[owner_peer_id] = state
	_send_resource_state(owner_peer_id, state)
	building.set_building_level(building.building_level + 1)
	if _multiplayer_mode:
		_rpc_apply_building_level.rpc(building_id, building.building_level)
	_broadcast_upgrade_visual(UPGRADE_TARGET_BUILDING, building_id)
	unit_command_panel.show_building(building_id, building.definition, building.building_level, building.pending_amount)
	_notify_peer(owner_peer_id, "%s已升级至 Lv.%d" % [building.definition.display_name, building.building_level])
	return true

@rpc("authority", "call_remote", "reliable")
func _rpc_apply_building_level(building_id: int, level: int) -> void:
	var building: ProductionBuilding = _network_buildings.get(building_id) as ProductionBuilding
	if is_instance_valid(building):
		building.set_building_level(level)

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

func _broadcast_upgrade_visual(target_kind: StringName, target_id: int) -> void:
	_play_upgrade_visual(target_kind, target_id)
	if _multiplayer_mode:
		_rpc_play_upgrade_visual.rpc(str(target_kind), target_id)

@rpc("authority", "call_remote", "reliable")
func _rpc_play_upgrade_visual(target_kind_value: String, target_id: int) -> void:
	_play_upgrade_visual(StringName(target_kind_value), target_id)

func _play_upgrade_visual(target_kind: StringName, target_id: int) -> void:
	match target_kind:
		UPGRADE_TARGET_BASE:
			for player_base: PlayerBase in _player_base_by_territory_id.values():
				if is_instance_valid(player_base) and player_base.owner_peer_id == target_id:
					_spawn_upgrade_visual(player_base, UPGRADE_BASE_VISUAL_DIAMETER)
		UPGRADE_TARGET_UNIT:
			var unit: Node2D = _network_units.get(target_id) as Node2D
			if is_instance_valid(unit):
				_spawn_upgrade_visual(unit, UPGRADE_UNIT_VISUAL_DIAMETER)
		UPGRADE_TARGET_BUILDING:
			var building: ProductionBuilding = _network_buildings.get(target_id) as ProductionBuilding
			if is_instance_valid(building):
				_spawn_upgrade_visual(building, UPGRADE_BUILDING_VISUAL_DIAMETER)

func _spawn_upgrade_visual(target_root: Node2D, visual_diameter: float) -> void:
	var upgrade_vfx: Node2D = UPGRADE_VFX_SCENE.instantiate() as Node2D
	if upgrade_vfx == null:
		return
	if upgrade_vfx.get_script() != UPGRADE_VFX_SCRIPT:
		upgrade_vfx.queue_free()
		return
	upgrade_vfx.name = "UpgradeVfx_%d" % Time.get_ticks_msec()
	target_root.add_child(upgrade_vfx)
	upgrade_vfx.call(&"configure_visual_size", visual_diameter)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_attack_target(unit_id_values: Array, target_kind_value: String, target_id: int) -> void:
	if not _has_gameplay_authority():
		return
	var unit_ids: Array[int] = []
	for unit_id_value: Variant in unit_id_values:
		unit_ids.append(int(unit_id_value))
	_server_attack_target(multiplayer.get_remote_sender_id(), unit_ids, StringName(target_kind_value), target_id)

func _server_attack_target(requesting_peer_id: int, requested_unit_ids: Array[int], target_kind: StringName, target_id: int) -> bool:
	if not _has_gameplay_authority():
		return false
	if target_kind == &"chest" and target_id >= STREAMED_CHEST_ID_OFFSET and not _combat_chests.has(target_id):
		var resource_id: int = target_id - STREAMED_CHEST_ID_OFFSET
		var streamed_data: Dictionary = world_resource_streamer.call(&"get_resource_data", resource_id) as Dictionary
		if streamed_data.is_empty() or StringName(str(streamed_data.get("resource_type", ""))) != &"chest":
			return false
		var streamed_position: Vector2 = _resource_world_position(streamed_data.get("cell", Vector2i.ZERO) as Vector2i)
		if not _is_world_position_visible_to_peer(streamed_position, requesting_peer_id):
			return false
	var target: HealthComponent = _get_damageable_by_identity(target_kind, target_id)
	var is_chest_target: bool = target_kind == &"chest"
	if not is_instance_valid(target) or not target.is_alive():
		return false
	if is_chest_target and not _is_world_position_visible_to_peer(target.get_target_position(), requesting_peer_id):
		return false
	if not is_chest_target and not _are_peers_hostile(requesting_peer_id, target.owner_peer_id):
		return false
	var applied: bool = false
	for network_unit_id: int in requested_unit_ids:
		var unit: TreantUnit = _network_units.get(network_unit_id) as TreantUnit
		if not is_instance_valid(unit) or unit.owner_peer_id != requesting_peer_id or unit.definition == null:
			continue
		if unit.definition.category != UnitDefinition.Category.COMBAT and unit.definition.category != UnitDefinition.Category.HERO:
			continue
		applied = unit.set_priority_attack_target(target) or applied
	return applied

func _get_damageable_by_identity(target_kind: StringName, target_id: int) -> HealthComponent:
	var target_root: Node2D
	match target_kind:
		&"unit":
			target_root = _network_units.get(target_id) as Node2D
		&"building":
			target_root = _network_buildings.get(target_id) as Node2D
		&"base":
			target_root = _player_base_by_territory_id.get(target_id) as Node2D
		&"chest":
			target_root = _combat_chests.get(target_id) as Node2D
			if not is_instance_valid(target_root) and target_id >= STREAMED_CHEST_ID_OFFSET and _has_gameplay_authority():
				target_root = _materialize_streamed_chest(target_id - STREAMED_CHEST_ID_OFFSET)
	if not is_instance_valid(target_root):
		return null
	return target_root.get_node_or_null("HealthComponent") as HealthComponent

func _materialize_streamed_chest(resource_id: int) -> Node2D:
	var chest_id: int = STREAMED_CHEST_ID_OFFSET + resource_id
	var existing: Node2D = _combat_chests.get(chest_id) as Node2D
	if is_instance_valid(existing):
		return existing
	var data: Dictionary = world_resource_streamer.call(&"claim_resource_by_id", resource_id, &"chest") as Dictionary
	if data.is_empty():
		return null
	_materialize_world_resource_data(data, 0)
	world_pathfinder.set_external_obstacles(world_resource_streamer.get_navigation_obstacle_cells())
	_schedule_navigation_rebuild()
	if _multiplayer_mode:
		_rpc_materialize_streamed_chest.rpc(data)
	return _combat_chests.get(chest_id) as Node2D

@rpc("authority", "call_remote", "reliable")
func _rpc_materialize_streamed_chest(data: Dictionary) -> void:
	var resource_id: int = int(data.get("resource_id", 0))
	if resource_id <= 0:
		return
	world_resource_streamer.call(&"claim_resource_by_id", resource_id, &"chest")
	_materialize_world_resource_data(data, 0)
	world_pathfinder.set_external_obstacles(world_resource_streamer.get_navigation_obstacle_cells())
	_schedule_navigation_rebuild()
	var chest_id: int = STREAMED_CHEST_ID_OFFSET + resource_id
	if _selected_chest_target_id == chest_id:
		var chest: Node2D = _combat_chests.get(chest_id) as Node2D
		var health: HealthComponent = chest.get_node_or_null("HealthComponent") as HealthComponent if is_instance_valid(chest) else null
		if is_instance_valid(health):
			_set_selected_enemy_target(health)

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
		if bool(unit.get_meta(&"construction_busy", false)) or _pending_structure_job_by_unit_id.has(network_unit_id):
			_notify_peer(requesting_peer_id, "建筑工人正在执行施工任务，暂时不能接受移动指令")
			continue
		var definition: UnitDefinition = unit.get("definition") as UnitDefinition
		if definition == null:
			continue
		if definition.category == UnitDefinition.Category.COMBAT or definition.category == UnitDefinition.Category.HERO or definition.can_leave_territory:
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
			state["construction_busy"] = bool(unit.get_meta(&"construction_busy", false))
			if unit is TreantUnit:
				state["star_level"] = (unit as TreantUnit).star_level
				state["combat_status"] = (unit as TreantUnit).get_combat_status_network_state()
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
	for monster_id: int in _wild_monsters.keys():
		var monster: WildMonster = _wild_monsters.get(monster_id) as WildMonster
		if not is_instance_valid(monster):
			continue
		var monster_health: HealthComponent = monster.get_node_or_null("HealthComponent") as HealthComponent
		if is_instance_valid(monster_health):
			structure_states.append({
				"kind": "monster",
				"id": monster_id,
				"health": monster_health.current_health,
				"position": monster.global_position,
			})
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
			if unit is TreantUnit:
				var combat_unit: TreantUnit = unit as TreantUnit
				if combat_unit.definition != null and combat_unit.definition.category == UnitDefinition.Category.COMBAT:
					combat_unit.set_star_level(int(state.get("star_level", combat_unit.star_level)))
				combat_unit.apply_combat_status_network_state(state.get("combat_status", {}) as Dictionary)
			if unit.has_method(&"set_construction_busy"):
				var busy: bool = bool(state.get("construction_busy", false))
				if busy != bool(unit.get_meta(&"construction_busy", false)):
					unit.call(&"set_construction_busy", busy, state.get("position", unit.global_position) as Vector2)
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
		elif str(state.get("kind", "")) == "monster":
			var monster: WildMonster = _wild_monsters.get(int(state.get("id", 0))) as WildMonster
			target = monster
			if is_instance_valid(monster):
				monster.apply_network_state(state.get("position", monster.global_position) as Vector2)
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
		if not is_instance_valid(unit):
			continue
		if int(unit.get("owner_peer_id")) != _local_peer_id:
			if unit.has_method(&"is_revealed_to_peer") and bool(unit.call(&"is_revealed_to_peer", _local_peer_id)):
				sources.append({"position": unit.global_position, "radius": 1.5 * float(TILE_SIZE)})
			continue
		if bool(unit.get_meta(&"construction_busy", false)):
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
		var construction_busy: bool = bool(unit.get_meta(&"construction_busy", false))
		unit.visible = not construction_busy and (is_local_unit or fog_of_war.is_world_position_visible(unit.global_position))
	for base_node: Node in base_container.get_children():
		if base_node is not PlayerBase:
			continue
		var player_base: PlayerBase = base_node as PlayerBase
		player_base.visible = player_base.owner_peer_id == _local_peer_id or fog_of_war.is_world_position_visible(player_base.global_position)
	for building: ProductionBuilding in _network_buildings.values():
		if is_instance_valid(building):
			building.visible = building.owner_peer_id == _local_peer_id or fog_of_war.is_world_position_visible(building.global_position)
	for monster: WildMonster in _wild_monsters.values():
		if is_instance_valid(monster):
			monster.visible = fog_of_war.is_world_position_visible(monster.global_position)
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

func _try_nudge_build_preview(keycode: Key) -> bool:
	var offset: Vector2i = Vector2i.ZERO
	match keycode:
		KEY_W:
			offset = Vector2i.UP
		KEY_A:
			offset = Vector2i.LEFT
		KEY_S:
			offset = Vector2i.DOWN
		KEY_D:
			offset = Vector2i.RIGHT
		_:
			return false
	var candidate: Rect2i = Rect2i(_build_preview_rect.position + offset, _build_preview_rect.size)
	var explorer: Node2D = _network_units.get(_build_preview_unit_id) as Node2D
	if not is_instance_valid(explorer):
		_cancel_build_preview()
		return true
	var explorer_cell: Vector2i = Vector2i(floori(explorer.global_position.x / TILE_SIZE), floori(explorer.global_position.y / TILE_SIZE))
	if not candidate.has_point(explorer_cell):
		unit_command_panel.show_notice("无法继续微调：新领地必须包含探索者")
		return true
	if not _is_valid_expansion_rect(candidate):
		unit_command_panel.show_notice("无法移动到该位置：领地会越界或与现有领地重叠")
		return true
	_build_preview_rect = candidate
	command_overlay.show_build_preview(candidate, TILE_SIZE)
	map_camera.position = _rect_world_center(candidate)
	unit_command_panel.update_build_confirmation(_resource_summary_in_rect(candidate))
	return true

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
	_initial_tree_count_by_territory[territory_id] = _count_territory_trees(territory_id)
	_tree_regrow_positions_by_territory[territory_id] = []
	_tree_regrow_elapsed_by_territory[territory_id] = 0.0
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
	_structure_preview_unit_id = unit_id
	_structure_preview_building_id = building_definition_id
	_structure_preview_rect = rect
	_preview_camera_position = map_camera.position
	_preview_camera_zoom = map_camera.zoom
	map_camera.set_process(false)
	_refresh_structure_preview_state()
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(map_camera, "position", _rect_world_center(rect), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(map_camera, "zoom", LOCAL_TERRITORY_ZOOM, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var territory_id: int = int(builder.get("territory_id"))
	var failure: String = _structure_validation_failure(_local_peer_id, territory_id, rect, definition)
	unit_command_panel.show_structure_confirmation(definition, _structure_condition_summary(definition), failure)

func _try_nudge_structure_preview(keycode: Key) -> bool:
	var offset: Vector2i = Vector2i.ZERO
	match keycode:
		KEY_W:
			offset = Vector2i.UP
		KEY_A:
			offset = Vector2i.LEFT
		KEY_S:
			offset = Vector2i.DOWN
		KEY_D:
			offset = Vector2i.RIGHT
		_:
			return false
	var builder: Node2D = _network_units.get(_structure_preview_unit_id) as Node2D
	var definition: BuildingDefinition = BUILDING_CATALOG.get_definition(_structure_preview_building_id)
	if not is_instance_valid(builder) or definition == null:
		_cancel_structure_preview()
		return true
	var candidate := Rect2i(_structure_preview_rect.position + offset, _structure_preview_rect.size)
	_structure_preview_rect = candidate
	_refresh_structure_preview_state()
	map_camera.position = _rect_world_center(candidate)
	return true

func _refresh_structure_preview_state() -> void:
	var builder: Node2D = _network_units.get(_structure_preview_unit_id) as Node2D
	var definition: BuildingDefinition = BUILDING_CATALOG.get_definition(_structure_preview_building_id)
	if not is_instance_valid(builder) or definition == null:
		return
	var territory_id: int = int(builder.get("territory_id"))
	var failure: String = _structure_validation_failure(_local_peer_id, territory_id, _structure_preview_rect, definition)
	command_overlay.show_build_preview(_structure_preview_rect, TILE_SIZE, failure.is_empty())
	unit_command_panel.update_structure_confirmation(definition, _structure_condition_summary(definition), failure)

func _on_structure_confirmed() -> void:
	if _structure_preview_unit_id <= 0 or _structure_preview_building_id.is_empty():
		return
	var builder: Node2D = _network_units.get(_structure_preview_unit_id) as Node2D
	var definition: BuildingDefinition = BUILDING_CATALOG.get_definition(_structure_preview_building_id)
	if not is_instance_valid(builder) or definition == null:
		_cancel_structure_preview()
		return
	var territory_id: int = int(builder.get("territory_id"))
	var failure: String = _structure_validation_failure(_local_peer_id, territory_id, _structure_preview_rect, definition)
	if not failure.is_empty():
		unit_command_panel.show_notice("无法建造：%s" % failure)
		_refresh_structure_preview_state()
		return
	if _has_gameplay_authority():
		if not _server_build_structure(_local_peer_id, _structure_preview_unit_id, _structure_preview_building_id, _structure_preview_rect):
			_refresh_structure_preview_state()
			return
	else:
		_rpc_request_build_structure.rpc_id(
			MultiplayerPeer.TARGET_PEER_SERVER,
			_structure_preview_unit_id,
			str(_structure_preview_building_id),
			_structure_preview_rect
		)
	_cancel_structure_preview()

func _cancel_structure_preview() -> void:
	var had_preview: bool = _structure_preview_unit_id > 0
	_structure_preview_unit_id = 0
	_structure_preview_building_id = &""
	_structure_preview_rect = Rect2i()
	command_overlay.hide_build_preview()
	unit_command_panel.hide_build_confirmation()
	if had_preview:
		var tween: Tween = create_tween().set_parallel(true)
		tween.tween_property(map_camera, "position", _preview_camera_position, 0.25)
		tween.tween_property(map_camera, "zoom", _preview_camera_zoom, 0.25)
		tween.chain().tween_callback(func() -> void: map_camera.set_process(true))

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
	if _pending_structure_job_by_unit_id.has(unit_id) or bool(builder.get_meta(&"construction_busy", false)):
		_notify_peer(owner_peer_id, "建造失败：该建筑工人正在执行施工任务")
		return false
	var territory_id := int(builder.get("territory_id"))
	var failure := _structure_validation_failure(owner_peer_id, territory_id, rect, definition)
	if not failure.is_empty():
		_notify_peer(owner_peer_id, "建造失败：%s" % failure)
		return false
	var approach_path: PackedVector2Array = _find_builder_approach_path(builder, territory_id, rect)
	if approach_path.is_empty():
		_notify_peer(owner_peer_id, "建造失败：建筑工人无法到达施工位置")
		return false
	var state := (_player_resource_states[owner_peer_id] as Dictionary).duplicate(true)
	var reserved_cost: Dictionary = definition.cost_dictionary()
	for resource_id: String in reserved_cost.keys():
		state[resource_id] = int(state.get(resource_id, 0)) - int(reserved_cost[resource_id])
	_player_resource_states[owner_peer_id] = state
	_send_resource_state(owner_peer_id, state)
	var approach_position: Vector2 = approach_path[approach_path.size() - 1]
	_pending_structure_job_by_unit_id[unit_id] = {
		"owner_peer_id": owner_peer_id,
		"unit_id": unit_id,
		"definition_id": str(definition.building_id),
		"territory_id": territory_id,
		"cell_rect": rect,
		"approach_position": approach_position,
		"reserved_cost": reserved_cost.duplicate(true),
	}
	var assignments: Array[Dictionary] = [{"unit_id": unit_id, "target": approach_position, "path": approach_path}]
	_apply_move_assignments(assignments)
	if _multiplayer_mode:
		_rpc_apply_move_assignments.rpc(assignments)
	_notify_peer(owner_peer_id, "%s选址已确认，建筑工人正在前往施工位置" % definition.display_name)
	return true

func _find_builder_approach_path(builder: Node2D, territory_id: int, rect: Rect2i) -> PackedVector2Array:
	if territory_id <= 0 or territory_id > _territory_rects.size():
		return PackedVector2Array()
	var territory_rect: Rect2i = _territory_rects[territory_id - 1]
	var center_x: int = rect.position.x + (rect.size.x >> 1)
	var center_y: int = rect.position.y + (rect.size.y >> 1)
	var candidate_cells: Array[Vector2i] = [
		Vector2i(center_x, rect.end.y),
		Vector2i(rect.end.x, center_y),
		Vector2i(center_x, rect.position.y - 1),
		Vector2i(rect.position.x - 1, center_y),
	]
	var best_path: PackedVector2Array = PackedVector2Array()
	var best_distance: float = INF
	for cell: Vector2i in candidate_cells:
		if not territory_rect.has_point(cell):
			continue
		var destination: Vector2 = Vector2(cell * TILE_SIZE) + Vector2.ONE * float(TILE_SIZE) * 0.5
		var path: PackedVector2Array = world_pathfinder.find_path(builder.global_position, destination)
		if path.is_empty() and builder.global_position.distance_to(destination) <= BUILDER_ARRIVAL_DISTANCE:
			path = PackedVector2Array([destination])
		if path.is_empty():
			continue
		var distance: float = builder.global_position.distance_to(path[0])
		for index: int in range(1, path.size()):
			distance += path[index - 1].distance_to(path[index])
		if distance < best_distance:
			best_distance = distance
			best_path = path
	return best_path

func _process_pending_structure_jobs() -> void:
	for unit_id: int in _pending_structure_job_by_unit_id.keys():
		var job: Dictionary = _pending_structure_job_by_unit_id[unit_id] as Dictionary
		var builder: Node2D = _network_units.get(unit_id) as Node2D
		if not is_instance_valid(builder):
			_cancel_pending_structure_job(unit_id, true, "建筑工人已不存在，建造资源已返还")
			continue
		var approach_position: Vector2 = job.get("approach_position", builder.global_position) as Vector2
		if bool(builder.get("has_move_target")):
			continue
		if builder.global_position.distance_to(approach_position) > BUILDER_ARRIVAL_DISTANCE:
			var retry_path: PackedVector2Array = world_pathfinder.find_path(builder.global_position, approach_position)
			if retry_path.is_empty():
				_cancel_pending_structure_job(unit_id, true, "施工位置无法到达，建造资源已返还")
				continue
			var assignments: Array[Dictionary] = [{"unit_id": unit_id, "target": retry_path[-1], "path": retry_path}]
			_apply_move_assignments(assignments)
			if _multiplayer_mode:
				_rpc_apply_move_assignments.rpc(assignments)
			continue
		_start_pending_structure_job(unit_id, builder, job)

func _start_pending_structure_job(unit_id: int, builder: Node2D, job: Dictionary) -> void:
	var owner_peer_id: int = int(job.get("owner_peer_id", 0))
	var territory_id: int = int(job.get("territory_id", 0))
	var rect: Rect2i = job.get("cell_rect", Rect2i()) as Rect2i
	var definition: BuildingDefinition = BUILDING_CATALOG.get_definition(StringName(str(job.get("definition_id", ""))))
	if definition == null:
		_cancel_pending_structure_job(unit_id, true, "建筑配置失效，建造资源已返还")
		return
	var failure: String = _structure_validation_failure(owner_peer_id, territory_id, rect, definition, false)
	if not failure.is_empty():
		_cancel_pending_structure_job(unit_id, true, "施工位置失效：%s；建造资源已返还" % failure)
		return
	var building_id: int = _next_network_building_id
	var return_position: Vector2 = job.get("approach_position", builder.global_position) as Vector2
	var spawn_data: Dictionary = {
		"building_id": building_id,
		"definition_id": str(definition.building_id),
		"owner_peer_id": owner_peer_id,
		"territory_id": territory_id,
		"position": _rect_world_center(rect),
		"cell_rect": rect,
		"builder_unit_id": unit_id,
		"builder_return_position": return_position,
	}
	_next_network_building_id += 1
	_pending_structure_job_by_unit_id.erase(unit_id)
	_spawn_network_building(spawn_data)
	if _multiplayer_mode:
		_rpc_spawn_building.rpc(spawn_data)
	_notify_peer(owner_peer_id, "%s开始建造，预计%.1f秒完成" % [definition.display_name, definition.construction_seconds])

func _cancel_pending_structure_job(unit_id: int, refund: bool, message: String) -> void:
	if not _pending_structure_job_by_unit_id.has(unit_id):
		return
	var job: Dictionary = _pending_structure_job_by_unit_id[unit_id] as Dictionary
	_pending_structure_job_by_unit_id.erase(unit_id)
	if refund:
		var owner_peer_id: int = int(job.get("owner_peer_id", 0))
		if _player_resource_states.has(owner_peer_id):
			var state: Dictionary = (_player_resource_states[owner_peer_id] as Dictionary).duplicate(true)
			var reserved_cost: Dictionary = job.get("reserved_cost", {}) as Dictionary
			for resource_id: String in reserved_cost.keys():
				state[resource_id] = int(state.get(resource_id, 0)) + int(reserved_cost[resource_id])
			_player_resource_states[owner_peer_id] = state
			_send_resource_state(owner_peer_id, state)
			_notify_peer(owner_peer_id, message)

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
	building.set_building_level(int(spawn_data.get("building_level", 1)))
	building.set_pending_amount(int(spawn_data.get("pending_amount", 0)))
	building.set_collection_visible_to_local(owner_peer_id == _local_peer_id)
	building.set_meta(&"cell_rect", spawn_data.get("cell_rect", Rect2i()) as Rect2i)
	var builder_unit_id: int = int(spawn_data.get("builder_unit_id", 0))
	var builder_return_position: Vector2 = spawn_data.get("builder_return_position", building.global_position) as Vector2
	building.set_meta(&"builder_unit_id", builder_unit_id)
	building.set_meta(&"builder_return_position", builder_return_position)
	if builder_unit_id > 0:
		_builder_unit_id_by_building_id[network_building_id] = builder_unit_id
		_set_builder_construction_state(builder_unit_id, true, builder_return_position)
	building.production_ready.connect(_on_building_production_ready)
	building.construction_completed.connect(_on_building_construction_completed)
	building.interaction_requested.connect(_on_building_interaction_requested)
	building.collection_requested.connect(_on_building_collection_requested)
	_network_buildings[network_building_id] = building
	_attach_vitals(
		building, owner_peer_id, float(definition.max_health), float(definition.defense), 0.0,
		0.0, 0.0, Vector2(0.0, -38.0), 46.0, &"building", network_building_id
	)
	_schedule_navigation_rebuild()

func _on_building_construction_completed(building: ProductionBuilding) -> void:
	if not _has_gameplay_authority() or not is_instance_valid(building):
		return
	_release_builder_for_building(building)
	if _multiplayer_mode:
		_rpc_complete_building_construction.rpc(building.building_id)
	_notify_peer(building.owner_peer_id, "%s建造完成" % building.definition.display_name)

@rpc("authority", "call_remote", "reliable")
func _rpc_complete_building_construction(building_id: int) -> void:
	var building: ProductionBuilding = _network_buildings.get(building_id) as ProductionBuilding
	if not is_instance_valid(building):
		return
	building.force_finish_construction()
	_release_builder_for_building(building)

func _set_builder_construction_state(unit_id: int, busy: bool, restored_position: Vector2) -> void:
	var builder: Node2D = _network_units.get(unit_id) as Node2D
	if not is_instance_valid(builder) or not builder.has_method(&"set_construction_busy"):
		return
	builder.call(&"set_construction_busy", busy, restored_position)
	if busy:
		_selected_unit_ids.erase(unit_id)
		_refresh_unit_command_panel()
	_refresh_entity_visibility()

func _release_builder_for_building(building: ProductionBuilding) -> void:
	var builder_unit_id: int = int(building.get_meta(&"builder_unit_id", 0))
	if builder_unit_id <= 0:
		return
	var return_position: Vector2 = building.get_meta(&"builder_return_position", building.global_position) as Vector2
	_set_builder_construction_state(builder_unit_id, false, return_position)
	_builder_unit_id_by_building_id.erase(building.building_id)
	building.set_meta(&"builder_unit_id", 0)

func _on_building_interaction_requested(building: ProductionBuilding) -> void:
	if not is_instance_valid(building) or building.owner_peer_id != _local_peer_id:
		return
	if building.construction_complete and building.definition.interaction_type == &"hero_altar":
		_active_hero_altar_id = building.building_id
		_card_menu_mode = &""
		var replacing: bool = _hero_unit_by_peer_id.has(_local_peer_id)
		summon_card_menu.close(true)
		hero_summon_panel.open_for(UNIT_CATALOG.build_hero_choices(), replacing)
	else:
		unit_command_panel.show_building(building.building_id, building.definition, building.building_level, building.pending_amount, building.get_construction_progress(), building.get_remaining_construction_seconds())

func _request_altar_hero(altar_id: int, definition_id: StringName) -> void:
	if _has_gameplay_authority():
		_server_summon_altar_hero(_local_peer_id, altar_id, definition_id)
	else:
		_rpc_request_altar_hero.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, altar_id, str(definition_id))

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_altar_hero(altar_id: int, definition_id_value: String) -> void:
	if _has_gameplay_authority():
		_server_summon_altar_hero(multiplayer.get_remote_sender_id(), altar_id, StringName(definition_id_value))

func _server_summon_altar_hero(owner_peer_id: int, altar_id: int, definition_id: StringName) -> bool:
	var altar: ProductionBuilding = _network_buildings.get(altar_id) as ProductionBuilding
	var definition: UnitDefinition = UNIT_CATALOG.get_definition(definition_id)
	if not is_instance_valid(altar) or altar.owner_peer_id != owner_peer_id or not altar.construction_complete:
		return false
	if altar.definition.interaction_type != &"hero_altar" or definition == null or definition.category != UnitDefinition.Category.HERO:
		return false
	if not UNIT_CATALOG.build_hero_choices().has(definition) or not _player_resource_states.has(owner_peer_id):
		return false
	var previous_id: int = int(_hero_unit_by_peer_id.get(owner_peer_id, 0))
	var previous: Node2D = _network_units.get(previous_id) as Node2D
	var replacing: bool = is_instance_valid(previous)
	var cost: int = HERO_REPLACEMENT_COST if replacing else HERO_INITIAL_SUMMON_COST
	var state: Dictionary = (_player_resource_states[owner_peer_id] as Dictionary).duplicate(true)
	if int(state.get("summon_token", 0)) < cost:
		_notify_peer(owner_peer_id, "召唤失败：需要%d张召唤符" % cost)
		return false
	state["summon_token"] = int(state.get("summon_token", 0)) - cost
	_player_resource_states[owner_peer_id] = state
	_send_resource_state(owner_peer_id, state)
	if replacing:
		_remove_damageable(&"unit", previous_id)
		if _multiplayer_mode:
			_rpc_remove_damageable.rpc("unit", previous_id)
	var new_unit_id: int = _next_network_unit_id
	if not _server_spawn_unit(owner_peer_id, definition_id, altar.territory_id):
		state["summon_token"] = int(state.get("summon_token", 0)) + cost
		_player_resource_states[owner_peer_id] = state
		_send_resource_state(owner_peer_id, state)
		return false
	_hero_unit_by_peer_id[owner_peer_id] = new_unit_id
	if _multiplayer_mode:
		_rpc_apply_active_hero.rpc(owner_peer_id, new_unit_id)
	_notify_peer(owner_peer_id, "%s%s成功" % ["替换" if replacing else "召唤", definition.display_name])
	return true

@rpc("authority", "call_remote", "reliable")
func _rpc_apply_active_hero(owner_peer_id: int, unit_id: int) -> void:
	if unit_id > 0:
		_hero_unit_by_peer_id[owner_peer_id] = unit_id
	else:
		_hero_unit_by_peer_id.erase(owner_peer_id)

func _on_building_production_ready(building: ProductionBuilding, _resource_type: StringName, pending_amount: int) -> void:
	if not _has_gameplay_authority() or not is_instance_valid(building):
		return
	if _multiplayer_mode:
		_rpc_apply_building_pending.rpc(building.building_id, pending_amount)
	if building.owner_peer_id == _local_peer_id:
		_refresh_unit_command_panel()

func _on_building_collection_requested(building: ProductionBuilding) -> void:
	if not is_instance_valid(building):
		return
	if _has_gameplay_authority():
		_server_collect_building_output(_local_peer_id, building.building_id)
	else:
		_rpc_request_collect_building_output.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, building.building_id)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_collect_building_output(building_id: int) -> void:
	if _has_gameplay_authority():
		_server_collect_building_output(multiplayer.get_remote_sender_id(), building_id)

func _server_collect_building_output(owner_peer_id: int, building_id: int) -> bool:
	var building: ProductionBuilding = _network_buildings.get(building_id) as ProductionBuilding
	if not is_instance_valid(building) or building.owner_peer_id != owner_peer_id or not building.construction_complete or building.definition == null:
		return false
	var amount: int = building.take_pending_amount()
	if amount <= 0 or building.definition.production_resource_type.is_empty() or not _player_resource_states.has(owner_peer_id):
		return false
	var state: Dictionary = (_player_resource_states[owner_peer_id] as Dictionary).duplicate(true)
	var resource_id: StringName = building.definition.production_resource_type
	state[resource_id] = int(state.get(resource_id, 0)) + amount
	_player_resource_states[owner_peer_id] = state
	_send_resource_state(owner_peer_id, state)
	if _multiplayer_mode:
		_rpc_apply_building_pending.rpc(building_id, 0)
	_notify_peer(owner_peer_id, "%s +%d" % [_resource_display_name(resource_id), amount])
	return true

@rpc("authority", "call_remote", "reliable")
func _rpc_apply_building_pending(building_id: int, pending_amount: int) -> void:
	var building: ProductionBuilding = _network_buildings.get(building_id) as ProductionBuilding
	if is_instance_valid(building):
		building.set_pending_amount(pending_amount)

func _spawn_wild_monsters() -> void:
	_clear_children(wild_monster_container)
	_wild_monsters.clear()
	_next_monster_id = 1
	for center_cell: Vector2i in WILD_MONSTER_CELLS:
		var footprint_rect := Rect2i(center_cell - Vector2i.ONE, Vector2i(2, 2))
		var spawn_data: Dictionary = {
			"monster_id": _next_monster_id,
			"position": _rect_world_center(footprint_rect),
			"cell_rect": footprint_rect,
		}
		_next_monster_id += 1
		_spawn_network_monster(spawn_data)

func _spawn_network_monster(spawn_data: Dictionary) -> void:
	var monster_id: int = int(spawn_data.get("monster_id", 0))
	if monster_id <= 0 or _wild_monsters.has(monster_id):
		return
	var monster: WildMonster = WILD_MONSTER_SCENE.instantiate() as WildMonster
	monster.name = "WildMonster_%d" % monster_id
	monster.position = spawn_data.get("position", Vector2.ZERO) as Vector2
	wild_monster_container.add_child(monster)
	monster.configure(monster_id, _has_gameplay_authority())
	monster.set_meta(&"cell_rect", spawn_data.get("cell_rect", Rect2i()) as Rect2i)
	monster.setup_combat_context(_get_monster_targets, world_pathfinder.find_path, TILE_SIZE)
	monster.attack_visual_requested.connect(_on_monster_attack_visual_requested)
	monster.skill_visual_requested.connect(_on_monster_skill_visual_requested)
	_wild_monsters[monster_id] = monster
	var health: HealthComponent = _attach_vitals(
		monster, 0, WildMonster.MAX_HEALTH, WildMonster.DEFENSE, 0.0, 0.0, 0.0,
		Vector2(0.0, -75.0), 86.0, &"monster", monster_id
	)
	health.combat_radius = 44.0

func _get_monster_targets() -> Array[HealthComponent]:
	var result: Array[HealthComponent] = []
	for component: HealthComponent in _all_damageables():
		if component.owner_peer_id > 0 and component.is_alive():
			result.append(component)
	return result

func _structure_rect_at(world_position: Vector2, footprint_tiles: int) -> Rect2i:
	var center_cell := Vector2i(floori(world_position.x / TILE_SIZE), floori(world_position.y / TILE_SIZE))
	return Rect2i(center_cell - Vector2i.ONE * (footprint_tiles >> 1), Vector2i.ONE * footprint_tiles)

func _structure_validation_failure(owner_peer_id: int, territory_id: int, rect: Rect2i, definition: BuildingDefinition, check_cost: bool = true) -> String:
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
	if check_cost and (not _player_resource_states.has(owner_peer_id) or not _resource_state_can_afford(_player_resource_states[owner_peer_id] as Dictionary, definition.cost_dictionary())):
		return "资源不足，需要%s" % definition.cost_summary()
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
		&"iron": return "铁"
		&"chest": return "宝箱"
		_: return str(resource_type)

func _claim_resources_in_rect(territory_id: int, rect: Rect2i) -> void:
	var streamed_resources: Array = world_resource_streamer.call(&"claim_resources_in_rect", rect) as Array
	world_pathfinder.set_external_obstacles(world_resource_streamer.get_navigation_obstacle_cells())
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
	if resource_type == &"chest" and _combat_chests.has(STREAMED_CHEST_ID_OFFSET + resource_id):
		return
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
	if resource_type == &"chest":
		_register_combat_chest(resource, STREAMED_CHEST_ID_OFFSET + resource_id)

func _register_combat_chest(chest: Node2D, chest_id: int) -> void:
	if not is_instance_valid(chest) or chest_id <= 0:
		return
	var existing: Node2D = _combat_chests.get(chest_id) as Node2D
	if is_instance_valid(existing) and existing != chest:
		return
	var health: HealthComponent = chest.get_node_or_null("HealthComponent") as HealthComponent
	if not is_instance_valid(health):
		health = HEALTH_COMPONENT_SCRIPT.new() as HealthComponent
		health.name = "HealthComponent"
		chest.add_child(health)
	health.configure(chest, 0, 1.0, 0.0)
	health.combat_radius = 18.0
	if not health.died.is_connected(_on_health_component_died):
		health.died.connect(_on_health_component_died)
	chest.set_meta(&"damageable_kind", &"chest")
	chest.set_meta(&"damageable_id", chest_id)
	_combat_chests[chest_id] = chest

func _resource_summary_in_rect(rect: Rect2i) -> String:
	var streamed_counts: Dictionary = world_resource_streamer.call(&"count_resources_in_rect", rect) as Dictionary
	var counts: Dictionary = {
		"树木": int(streamed_counts.get(&"tree", 0)),
		"石头": int(streamed_counts.get(&"stone", 0)),
		"铁": int(streamed_counts.get(&"iron", 0)),
		"宝箱": int(streamed_counts.get(&"chest", 0)),
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
					&"iron": label = "铁"
					&"chest": label = "宝箱"
			counts[label] = int(counts[label]) + 1
	return "树木%d  石头%d  铁%d  宝箱%d" % [counts["树木"], counts["石头"], counts["铁"], counts["宝箱"]]

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
		if bool(unit.get_meta(&"construction_busy", false)):
			continue
		var component := unit.get_node_or_null("HealthComponent") as HealthComponent
		if is_instance_valid(component) and component.is_alive() and not _are_peers_hostile(owner_peer_id, component.owner_peer_id):
			result.append(component)
	return result

func _all_damageables() -> Array[HealthComponent]:
	var result: Array[HealthComponent] = []
	for unit: Node2D in _network_units.values():
		if is_instance_valid(unit) and not bool(unit.get_meta(&"construction_busy", false)):
			var unit_health := unit.get_node_or_null("HealthComponent") as HealthComponent
			if is_instance_valid(unit_health) and unit_health.is_alive():
				result.append(unit_health)
	for building: ProductionBuilding in _network_buildings.values():
		if is_instance_valid(building):
			var building_health := building.get_node_or_null("HealthComponent") as HealthComponent
			if is_instance_valid(building_health) and building_health.is_alive():
				result.append(building_health)
	for monster: WildMonster in _wild_monsters.values():
		if is_instance_valid(monster):
			var monster_health: HealthComponent = monster.get_node_or_null("HealthComponent") as HealthComponent
			if is_instance_valid(monster_health) and monster_health.is_alive():
				result.append(monster_health)
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
	if entity_kind == &"chest":
		if component.last_damage_owner_peer_id > 0:
			_apply_chest_rewards(component.last_damage_owner_peer_id)
		_open_combat_chest(entity_id)
		if _multiplayer_mode:
			_rpc_open_combat_chest.rpc(entity_id)
		return
	if entity_kind == &"monster" and component.last_damage_owner_peer_id > 0:
		_apply_monster_drops(component.last_damage_owner_peer_id)
	_remove_damageable(entity_kind, entity_id)
	if _multiplayer_mode:
		_rpc_remove_damageable.rpc(str(entity_kind), entity_id)

func _apply_monster_drops(owner_peer_id: int) -> void:
	if not _player_resource_states.has(owner_peer_id):
		return
	var state: Dictionary = (_player_resource_states[owner_peer_id] as Dictionary).duplicate(true)
	for resource_id: String in MONSTER_DROP_REWARDS.keys():
		state[resource_id] = int(state.get(resource_id, 0)) + int(MONSTER_DROP_REWARDS[resource_id])
	_player_resource_states[owner_peer_id] = state
	_send_resource_state(owner_peer_id, state)
	_notify_peer(owner_peer_id, "击败野怪：铁+4 召唤符+1 技能经验+6 经验+20")

func _apply_chest_rewards(owner_peer_id: int) -> void:
	if not _player_resource_states.has(owner_peer_id):
		return
	var state: Dictionary = (_player_resource_states[owner_peer_id] as Dictionary).duplicate(true)
	for resource_id: String in CHEST_REWARDS.keys():
		state[resource_id] = int(state.get(resource_id, 0)) + int(CHEST_REWARDS[resource_id])
	_player_resource_states[owner_peer_id] = state
	_send_resource_state(owner_peer_id, state)
	_notify_peer(owner_peer_id, "打开宝箱：金币+30 铁+2 召唤符+1 技能经验+4 经验+10")

func _open_combat_chest(chest_id: int) -> void:
	var chest: Node2D = _combat_chests.get(chest_id) as Node2D
	_combat_chests.erase(chest_id)
	if not is_instance_valid(chest):
		return
	chest.set_meta(&"combat_reward_claimed", true)
	if is_instance_valid(_selected_enemy_target) and _selected_enemy_target.target_root == chest:
		_clear_selected_enemy_target()
	if chest.has_method(&"consume_harvest_progress"):
		chest.call(&"consume_harvest_progress", 100.0)
	else:
		chest.queue_free()
	_schedule_navigation_rebuild()

@rpc("authority", "call_remote", "reliable")
func _rpc_open_combat_chest(chest_id: int) -> void:
	_open_combat_chest(chest_id)

@rpc("authority", "call_remote", "reliable")
func _rpc_remove_damageable(entity_kind_value: String, entity_id: int) -> void:
	_remove_damageable(StringName(entity_kind_value), entity_id)

func _remove_damageable(entity_kind: StringName, entity_id: int) -> void:
	var target: Node2D
	match entity_kind:
		&"unit":
			target = _network_units.get(entity_id) as Node2D
			if _has_gameplay_authority() and _pending_structure_job_by_unit_id.has(entity_id):
				_cancel_pending_structure_job(entity_id, true, "建筑工人已阵亡，建造资源已返还")
			_network_units.erase(entity_id)
			_selected_unit_ids.erase(entity_id)
			for peer_id: int in _hero_unit_by_peer_id.keys():
				if int(_hero_unit_by_peer_id[peer_id]) == entity_id:
					_hero_unit_by_peer_id.erase(peer_id)
			_refresh_unit_command_panel()
		&"building":
			target = _network_buildings.get(entity_id) as Node2D
			var production_building: ProductionBuilding = target as ProductionBuilding
			if is_instance_valid(production_building):
				_release_builder_for_building(production_building)
			_network_buildings.erase(entity_id)
			_schedule_navigation_rebuild()
		&"monster":
			target = _wild_monsters.get(entity_id) as Node2D
			_wild_monsters.erase(entity_id)
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
		if is_instance_valid(_selected_enemy_target) and _selected_enemy_target.target_root == target:
			_clear_selected_enemy_target()
		target.queue_free()

func _initialize_player_resources() -> void:
	_player_resource_states.clear()
	for peer_id: int in _player_by_peer_id.keys():
		_player_resource_states[peer_id] = {
			"gold": DEVELOPMENT_GOLD, "wood": 0, "stone": 0,
			"iron": 0, "summon_token": 0, "skill_experience": 0, "experience": 0,
		}
	resource_manager.call(&"set_state", DEVELOPMENT_GOLD, 0, 0, 0, 0, 0, 0)

func _server_apply_harvest(territory_id: int, resource_type: StringName) -> void:
	if not _has_gameplay_authority():
		return
	var owner_peer_id: int = int(_territory_owner_by_id.get(territory_id, 0))
	if owner_peer_id <= 0:
		return
	var state: Dictionary = (_player_resource_states.get(owner_peer_id, {}) as Dictionary).duplicate(true)
	if resource_type == &"tree":
		state["wood"] = int(state.get("wood", 0)) + TREE_WOOD_REWARD
	elif resource_type == &"stone":
		state["stone"] = int(state.get("stone", 0)) + STONE_REWARD
	elif MINERAL_REWARDS.has(resource_type):
		state[resource_type] = int(state.get(resource_type, 0)) + int(MINERAL_REWARDS[resource_type])
	elif resource_type == &"chest":
		for reward_id: String in CHEST_REWARDS.keys():
			state[reward_id] = int(state.get(reward_id, 0)) + int(CHEST_REWARDS[reward_id])
	_player_resource_states[owner_peer_id] = state
	_send_resource_state(owner_peer_id, state)

func _send_resource_state(owner_peer_id: int, state: Dictionary) -> void:
	if bool(_infinite_resources_by_peer_id.get(owner_peer_id, false)):
		_fill_resource_state(state)
		_player_resource_states[owner_peer_id] = state
	if owner_peer_id == _local_peer_id:
		_apply_local_resource_state(state)
	elif _multiplayer_mode:
		_rpc_receive_resource_state.rpc_id(owner_peer_id, state)

func _fill_resource_state(state: Dictionary) -> void:
	for resource_id: String in ["gold", "wood", "stone", "iron", "summon_token", "skill_experience", "experience"]:
		state[resource_id] = DEVELOPMENT_INFINITE_RESOURCE_AMOUNT

func _on_infinite_resources_changed(enabled: bool) -> void:
	if _has_gameplay_authority():
		_server_set_infinite_resources(_local_peer_id, enabled)
	else:
		_rpc_request_infinite_resources.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, enabled)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_infinite_resources(enabled: bool) -> void:
	if _has_gameplay_authority():
		_server_set_infinite_resources(multiplayer.get_remote_sender_id(), enabled)

func _server_set_infinite_resources(owner_peer_id: int, enabled: bool) -> void:
	if not _player_resource_states.has(owner_peer_id):
		return
	_infinite_resources_by_peer_id[owner_peer_id] = enabled
	var state: Dictionary = (_player_resource_states[owner_peer_id] as Dictionary).duplicate(true)
	if enabled:
		_fill_resource_state(state)
	_player_resource_states[owner_peer_id] = state
	_send_resource_state(owner_peer_id, state)
	_notify_peer(owner_peer_id, "开发者无限资源已开启" if enabled else "开发者无限资源已关闭")

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
		int(state.get("summon_token", 0)),
		int(state.get("skill_experience", 0)),
		int(state.get("experience", 0))
	)

func _on_tree_felled(tree: Node2D) -> void:
	if not _has_gameplay_authority():
		return
	var territory_id: int = int(tree.get("territory_id"))
	_queue_tree_regrowth(territory_id, tree.global_position)
	_server_apply_harvest(territory_id, &"tree")
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
	if StringName(str(mineral.get("resource_type"))) == &"chest":
		var chest_id: int = int(mineral.get_meta(&"damageable_id", 0))
		_combat_chests.erase(chest_id)
		if is_instance_valid(_selected_enemy_target) and _selected_enemy_target.target_root == mineral:
			_clear_selected_enemy_target()
		if bool(mineral.get_meta(&"combat_reward_claimed", false)):
			_schedule_navigation_rebuild()
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
		if resource is Node2D and StringName(str(resource.get("resource_type"))) == &"chest":
			var chest: Node2D = resource as Node2D
			_combat_chests.erase(int(chest.get_meta(&"damageable_id", 0)))
			if is_instance_valid(_selected_enemy_target) and _selected_enemy_target.target_root == chest:
				_clear_selected_enemy_target()
		resource.queue_free()
		_schedule_navigation_rebuild()

func _queue_tree_regrowth(territory_id: int, world_position: Vector2) -> void:
	if territory_id <= 0 or not _initial_tree_count_by_territory.has(territory_id):
		return
	var positions: Array = _tree_regrow_positions_by_territory.get(territory_id, []) as Array
	positions.append(world_position)
	_tree_regrow_positions_by_territory[territory_id] = positions

func _process_tree_regrowth(delta: float) -> void:
	for territory_id: int in _initial_tree_count_by_territory.keys():
		var positions: Array = _tree_regrow_positions_by_territory.get(territory_id, []) as Array
		if positions.is_empty() or _count_territory_trees(territory_id) >= int(_initial_tree_count_by_territory[territory_id]):
			_tree_regrow_elapsed_by_territory[territory_id] = 0.0
			continue
		var elapsed: float = float(_tree_regrow_elapsed_by_territory.get(territory_id, 0.0)) + delta
		if elapsed < TREE_REGROW_SECONDS:
			_tree_regrow_elapsed_by_territory[territory_id] = elapsed
			continue
		var world_position: Vector2 = positions.pop_front() as Vector2
		if not _can_regrow_tree_at(world_position):
			positions.append(world_position)
			_tree_regrow_positions_by_territory[territory_id] = positions
			_tree_regrow_elapsed_by_territory[territory_id] = 0.0
			continue
		_tree_regrow_positions_by_territory[territory_id] = positions
		_tree_regrow_elapsed_by_territory[territory_id] = elapsed - TREE_REGROW_SECONDS
		var tree_name: String = "RegrownTree_T%d_%04d" % [territory_id, _next_regrown_tree_id]
		_next_regrown_tree_id += 1
		_spawn_regrown_tree(tree_name, territory_id, world_position)
		if _multiplayer_mode:
			_rpc_spawn_regrown_tree.rpc(tree_name, territory_id, world_position)

func _count_territory_trees(territory_id: int) -> int:
	var count: int = 0
	for child: Node in tree_container.get_children():
		if child is Node2D and child.get_script() != WORLD_RESOURCE_MARKER_SCRIPT and int(child.get("territory_id")) == territory_id:
			count += 1
	return count

func _can_regrow_tree_at(world_position: Vector2) -> bool:
	var tree_cell: Vector2i = Vector2i(floori(world_position.x / TILE_SIZE), floori(world_position.y / TILE_SIZE))
	for building: ProductionBuilding in _network_buildings.values():
		if is_instance_valid(building) and (building.get_meta(&"cell_rect", Rect2i()) as Rect2i).has_point(tree_cell):
			return false
	for player_base: PlayerBase in _player_base_by_territory_id.values():
		if is_instance_valid(player_base) and _structure_rect_at(player_base.global_position, 3).has_point(tree_cell):
			return false
	return true

func _spawn_regrown_tree(tree_name: String, territory_id: int, world_position: Vector2) -> void:
	if tree_container.has_node(NodePath(tree_name)):
		return
	var tree: Node2D = TREE_SCENE.instantiate() as Node2D
	tree.name = tree_name
	tree.set("territory_id", territory_id)
	tree.position = world_position
	tree_container.add_child(tree)
	tree.connect(&"felled", _on_tree_felled)
	_schedule_navigation_rebuild()

@rpc("authority", "call_remote", "reliable")
func _rpc_spawn_regrown_tree(tree_name: String, territory_id: int, world_position: Vector2) -> void:
	_spawn_regrown_tree(tree_name, territory_id, world_position)

func _on_start_requested(multiplayer_mode: bool, selected_ai_difficulty: int = SimpleAIController.Difficulty.NORMAL) -> void:
	_multiplayer_mode = multiplayer_mode
	if not multiplayer_mode:
		_ai_difficulty = clampi(selected_ai_difficulty, SimpleAIController.Difficulty.EASY, SimpleAIController.Difficulty.HELL)
		_resource_abundance = RESOURCE_STANDARD
		_multiplayer_snapshot = _build_single_player_snapshot()
	var settings: Dictionary = _multiplayer_snapshot.get("settings", {}) as Dictionary
	_resource_seed = int(settings.get("resource_seed", 1))
	_ai_difficulty = clampi(int(settings.get("ai_difficulty", _ai_difficulty)), SimpleAIController.Difficulty.EASY, SimpleAIController.Difficulty.HELL)
	_reset_game_state()
	_game_started = true
	main_menu.hide()
	lan_lobby.call(&"close_lobby", false)
	pause_menu.show()
	pause_menu.configure(_multiplayer_mode)
	pause_menu.force_close()
	resource_hud.show()
	developer_panel.show()
	ai_controller.configure(not _multiplayer_mode and _ai_peer_id > 0, _ai_difficulty)
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
	_clear_selected_enemy_target()
	_set_selected_units([])
	base_action_menu.close()
	summon_card_menu.close(true)
	hero_summon_panel.close()
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
	_clear_children(wild_monster_container)
	_network_units.clear()
	_network_buildings.clear()
	_pending_structure_job_by_unit_id.clear()
	_builder_unit_id_by_building_id.clear()
	_wild_monsters.clear()
	_hero_unit_by_peer_id.clear()
	_selected_unit_ids.clear()
	_clear_selected_enemy_target()
	unit_command_panel.hide_selection()
	command_overlay.hide_build_preview()
	_build_preview_unit_id = 0
	_build_preview_rect = Rect2i()
	_structure_preview_unit_id = 0
	_structure_preview_building_id = &""
	_structure_preview_rect = Rect2i()
	_spawn_sequence_by_peer.clear()
	_pending_summon_by_peer_id.clear()
	_infinite_resources_by_peer_id.clear()
	_next_network_unit_id = 1
	_next_network_building_id = 1
	_next_monster_id = 1
	_next_regrown_tree_id = 1
	_next_summon_offer_id = 1
	_card_menu_mode = &""
	_active_summon_offer_id = 0
	_active_hero_altar_id = 0
	_summon_rng.seed = int(_resource_seed) ^ 0x5A17C0DE
	_unit_state_elapsed = 0.0
	_fog_elapsed = 0.0
	_setup_runtime_players(_multiplayer_snapshot)
	_spawn_fair_resources()
	_spawn_wild_monsters()
	_rebuild_navigation_obstacles()
	_initialize_player_resources()
	_ai_expansion_completed = false
	_ai_has_known_enemy = false
	_ai_known_enemy_position = Vector2.ZERO
	_ai_known_enemy_kind = &""
	_ai_known_enemy_id = 0
	var ai_player: Dictionary = _player_by_peer_id.get(_ai_peer_id, {}) as Dictionary
	var ai_territory_id: int = int(ai_player.get("territory_id", 1))
	_ai_scout_origin = _territory_base_position(ai_territory_id)
	_ai_scout_waypoint_index = absi(_resource_seed) % AI_SCOUT_OFFSETS_TILES.size()
	if not _multiplayer_mode and _ai_peer_id > 0:
		_server_recruit_unit(_ai_peer_id, &"lumber")
		_server_recruit_unit(_ai_peer_id, &"quarry")
		_server_recruit_unit(_ai_peer_id, &"explorer")
	base_action_menu.close()
	summon_card_menu.close(true)
	hero_summon_panel.close()
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
			"ai_difficulty": _ai_difficulty,
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
			"name": "人机对手（%s）" % SimpleAIController.get_difficulty_name(_ai_difficulty),
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
	_ai_refresh_enemy_knowledge()
	var combat_units: Array[int] = []
	var explorer: ExplorerUnit
	var upgradeable_machines: Array[Node2D] = []
	for unit: Node2D in _network_units.values():
		if not is_instance_valid(unit) or int(unit.get("owner_peer_id")) != _ai_peer_id:
			continue
		var definition: UnitDefinition = unit.get("definition") as UnitDefinition
		if definition == null:
			continue
		if definition.category == UnitDefinition.Category.COMBAT:
			combat_units.append(int(unit.get("unit_id")))
		elif definition.unit_id == &"explorer":
			explorer = unit as ExplorerUnit
		elif definition.unit_id in [&"lumber", &"quarry"] and int(unit.get("machine_level")) < MachineProgressionData.MAX_LEVEL:
			upgradeable_machines.append(unit)
	combat_units.sort()
	upgradeable_machines.sort_custom(func(first: Node2D, second: Node2D) -> bool: return int(first.get("unit_id")) < int(second.get("unit_id")))

	# One think signal performs at most one control operation. Non-hell
	# difficulties therefore visibly pause between planning steps.
	if _ai_try_claim_summon():
		return
	if _ai_try_expand(explorer):
		return
	if _ai_has_known_enemy and not combat_units.is_empty():
		if _ai_should_clear_mobile_enemy_memory(combat_units):
			_ai_clear_enemy_knowledge()
		elif _ai_combat_needs_move_command(combat_units, _ai_known_enemy_position):
			_server_move_units(_ai_peer_id, combat_units, _ai_known_enemy_position)
			return
	if combat_units.size() < _ai_desired_combat_unit_count() and _ai_try_purchase_summon():
		return
	if not _ai_has_known_enemy and _ai_try_scout(combat_units):
		return
	if _ai_try_upgrade_machine(upgradeable_machines):
		return
	_ai_try_upgrade_base()

func _ai_refresh_enemy_knowledge() -> void:
	var best_priority: int = 99
	var best_distance: float = INF
	var best_position: Vector2 = Vector2.ZERO
	var best_kind: StringName = &""
	var best_id: int = 0
	for peer_id: int in _player_base_by_peer_id.keys():
		var player_base: PlayerBase = _player_base_by_peer_id[peer_id]
		if not is_instance_valid(player_base) or not _are_peers_hostile(_ai_peer_id, peer_id):
			continue
		if not _is_world_position_visible_to_peer(player_base.global_position, _ai_peer_id):
			continue
		var distance: float = _ai_scout_origin.distance_squared_to(player_base.global_position)
		if 0 < best_priority or distance < best_distance:
			best_priority = 0
			best_distance = distance
			best_position = player_base.global_position
			best_kind = &"base"
			best_id = peer_id
	for building_id: int in _network_buildings.keys():
		var building: ProductionBuilding = _network_buildings[building_id]
		if not is_instance_valid(building) or not _are_peers_hostile(_ai_peer_id, building.owner_peer_id):
			continue
		if not _is_world_position_visible_to_peer(building.global_position, _ai_peer_id):
			continue
		var distance: float = _ai_scout_origin.distance_squared_to(building.global_position)
		if 1 < best_priority or (best_priority == 1 and distance < best_distance):
			best_priority = 1
			best_distance = distance
			best_position = building.global_position
			best_kind = &"building"
			best_id = building_id
	for unit_id: int in _network_units.keys():
		var unit: Node2D = _network_units[unit_id]
		if not is_instance_valid(unit):
			continue
		var owner_peer_id: int = int(unit.get("owner_peer_id"))
		if not _are_peers_hostile(_ai_peer_id, owner_peer_id):
			continue
		if not _is_world_position_visible_to_peer(unit.global_position, _ai_peer_id):
			continue
		var distance: float = _ai_scout_origin.distance_squared_to(unit.global_position)
		if 2 < best_priority or (best_priority == 2 and distance < best_distance):
			best_priority = 2
			best_distance = distance
			best_position = unit.global_position
			best_kind = &"unit"
			best_id = unit_id
	if best_priority < 99:
		_ai_has_known_enemy = true
		_ai_known_enemy_position = best_position
		_ai_known_enemy_kind = best_kind
		_ai_known_enemy_id = best_id
	else:
		_ai_validate_enemy_knowledge()

func _ai_validate_enemy_knowledge() -> void:
	if not _ai_has_known_enemy:
		return
	var known_target: Node2D
	match _ai_known_enemy_kind:
		&"base":
			known_target = _player_base_by_peer_id.get(_ai_known_enemy_id) as Node2D
		&"building":
			known_target = _network_buildings.get(_ai_known_enemy_id) as Node2D
		&"unit":
			known_target = _network_units.get(_ai_known_enemy_id) as Node2D
	if not is_instance_valid(known_target):
		_ai_clear_enemy_knowledge()
		return
	# Mobile targets are updated only while currently visible. Outside vision the
	# stored position remains a genuine last-known location.
	if _ai_known_enemy_kind == &"unit" and _is_world_position_visible_to_peer(known_target.global_position, _ai_peer_id):
		_ai_known_enemy_position = known_target.global_position

func _ai_clear_enemy_knowledge() -> void:
	_ai_has_known_enemy = false
	_ai_known_enemy_position = Vector2.ZERO
	_ai_known_enemy_kind = &""
	_ai_known_enemy_id = 0

func _is_world_position_visible_to_peer(world_position: Vector2, peer_id: int) -> bool:
	var cell: Vector2i = Vector2i(
		floori(world_position.x / float(TILE_SIZE)),
		floori(world_position.y / float(TILE_SIZE))
	)
	for territory_id: int in _territory_owner_by_id.keys():
		if int(_territory_owner_by_id[territory_id]) != peer_id or territory_id <= 0 or territory_id > _territory_rects.size():
			continue
		if _territory_rects[territory_id - 1].has_point(cell):
			return true
	var cell_center: Vector2 = Vector2(cell * TILE_SIZE) + Vector2.ONE * float(TILE_SIZE) * 0.5
	for unit: Node2D in _network_units.values():
		if not is_instance_valid(unit) or int(unit.get("owner_peer_id")) != peer_id:
			continue
		if not unit.has_method(&"get_vision_radius_world"):
			continue
		var radius: float = float(unit.call(&"get_vision_radius_world", TILE_SIZE))
		if unit.global_position.distance_squared_to(cell_center) <= radius * radius:
			return true
	for unit: Node2D in _network_units.values():
		if not is_instance_valid(unit) or int(unit.get("owner_peer_id")) == peer_id:
			continue
		if unit.has_method(&"is_revealed_to_peer") and bool(unit.call(&"is_revealed_to_peer", peer_id)):
			var reveal_radius: float = 1.5 * float(TILE_SIZE)
			if unit.global_position.distance_squared_to(cell_center) <= reveal_radius * reveal_radius:
				return true
	return false

func _ai_try_claim_summon() -> bool:
	var offer: Dictionary = _pending_summon_by_peer_id.get(_ai_peer_id, {}) as Dictionary
	var offer_id: int = int(offer.get("offer_id", 0))
	if offer_id <= 0:
		return false
	var offer_cards: Array = offer.get("card_ids", []) as Array
	for card_id: Variant in offer_cards:
		var definition: UnitDefinition = UNIT_CATALOG.get_definition(StringName(str(card_id)))
		if definition != null and definition.category == UnitDefinition.Category.COMBAT:
			return _server_claim_summon(_ai_peer_id, offer_id, definition.unit_id)
	return false

func _ai_try_purchase_summon() -> bool:
	return _server_purchase_summon(_ai_peer_id)

func _ai_try_expand(explorer: ExplorerUnit) -> bool:
	if _ai_expansion_completed or not is_instance_valid(explorer):
		return false
	if not _is_valid_expansion_rect(AI_EXPANSION_RECT):
		return false
	var destination: Vector2 = _rect_world_center(AI_EXPANSION_RECT)
	if explorer.global_position.distance_to(destination) <= 24.0:
		_ai_expansion_completed = _server_build_base(_ai_peer_id, explorer.unit_id, AI_EXPANSION_RECT)
		return _ai_expansion_completed
	if explorer.has_move_target and explorer.move_target.distance_to(destination) <= float(TILE_SIZE):
		return false
	return _server_move_units(_ai_peer_id, [explorer.unit_id], destination)

func _ai_try_scout(combat_units: Array[int]) -> bool:
	if combat_units.is_empty():
		return false
	for unit_id: int in combat_units:
		var unit: Node2D = _network_units.get(unit_id) as Node2D
		if is_instance_valid(unit) and bool(unit.get("has_move_target")):
			return false
	var offset: Vector2i = AI_SCOUT_OFFSETS_TILES[_ai_scout_waypoint_index]
	_ai_scout_waypoint_index = (_ai_scout_waypoint_index + AI_SCOUT_STEP) % AI_SCOUT_OFFSETS_TILES.size()
	var map_max: float = float(GRID_SIZE * TILE_SIZE - 16)
	var target: Vector2 = _ai_scout_origin + Vector2(offset * TILE_SIZE)
	target = Vector2(clampf(target.x, 16.0, map_max), clampf(target.y, 16.0, map_max))
	return _server_move_units(_ai_peer_id, combat_units, target)

func _ai_combat_needs_move_command(combat_units: Array[int], target: Vector2) -> bool:
	for unit_id: int in combat_units:
		var unit: Node2D = _network_units.get(unit_id) as Node2D
		if not is_instance_valid(unit):
			continue
		if unit.global_position.distance_to(target) <= AI_TARGET_ARRIVAL_DISTANCE:
			continue
		if not bool(unit.get("has_move_target")) or (unit.get("move_target") as Vector2).distance_to(target) > float(TILE_SIZE):
			return true
	return false

func _ai_should_clear_mobile_enemy_memory(combat_units: Array[int]) -> bool:
	if _ai_known_enemy_kind != &"unit":
		return false
	var known_unit: Node2D = _network_units.get(_ai_known_enemy_id) as Node2D
	if is_instance_valid(known_unit) and _is_world_position_visible_to_peer(known_unit.global_position, _ai_peer_id):
		return false
	for unit_id: int in combat_units:
		var combat_unit: Node2D = _network_units.get(unit_id) as Node2D
		if is_instance_valid(combat_unit) and combat_unit.global_position.distance_to(_ai_known_enemy_position) > AI_TARGET_ARRIVAL_DISTANCE:
			return false
	return true

func _ai_try_upgrade_machine(machines: Array[Node2D]) -> bool:
	var state: Dictionary = _player_resource_states.get(_ai_peer_id, {}) as Dictionary
	for machine: Node2D in machines:
		var current_level: int = int(machine.get("machine_level"))
		var cost: Dictionary = MachineProgressionData.get_upgrade_cost(current_level)
		if not cost.is_empty() and _resource_state_can_afford(state, cost):
			return _server_upgrade_machine(_ai_peer_id, int(machine.get("unit_id")))
	return false

func _ai_try_upgrade_base() -> bool:
	var current_level: int = int(_base_level_by_peer_id.get(_ai_peer_id, 1))
	var cost: Dictionary = BaseProgression.get_upgrade_cost(current_level)
	var state: Dictionary = _player_resource_states.get(_ai_peer_id, {}) as Dictionary
	if cost.is_empty() or not _resource_state_can_afford(state, cost):
		return false
	return _server_upgrade_base(_ai_peer_id)

func _ai_desired_combat_unit_count() -> int:
	match _ai_difficulty:
		SimpleAIController.Difficulty.EASY:
			return 2
		SimpleAIController.Difficulty.HARD:
			return 6
		SimpleAIController.Difficulty.HELL:
			return 8
		_:
			return 4

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

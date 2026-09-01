extends Node

const MAIN_SCENE: PackedScene = preload("res://game/main/main.tscn")
const MapSizeSettingData: Script = preload("res://game/data/map_size_setting.gd")

var _failures: PackedStringArray = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred(&"_run")

func _run() -> void:
	_expect(MapSizeSettingData.TILE_COUNTS == [100, 250, 500], "地图档位不是 100 / 250 / 500")
	_expect(MapSizeSettingData.normalize_tile_count(1000) == 500, "旧 1000×1000 地图值没有回退到 500×500")
	for map_size_tiles: int in MapSizeSettingData.TILE_COUNTS:
		await _verify_map_size(map_size_tiles)
	_finish()

func _verify_map_size(map_size_tiles: int) -> void:
	var map: Node2D = MAIN_SCENE.instantiate() as Node2D
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame
	map.call(
		&"_on_start_requested",
		false,
		SimpleAIController.Difficulty.NORMAL,
		map_size_tiles,
		WildEnemyDifficulty.Level.HARD
	)
	await get_tree().process_frame

	_expect(int(map.get("_map_size_tiles")) == map_size_tiles, "%d×%d 地图大小没有传入主地图" % [map_size_tiles, map_size_tiles])
	var snapshot: Dictionary = map.get("_multiplayer_snapshot") as Dictionary
	var settings: Dictionary = snapshot.get("settings", {}) as Dictionary
	_expect(int(settings.get("map_size_tiles", 0)) == map_size_tiles, "%d×%d 没有写入单人快照" % [map_size_tiles, map_size_tiles])
	_expect(int(map.get("_wild_enemy_difficulty")) == WildEnemyDifficulty.Level.HARD, "%d×%d 丢失独立野怪强度" % [map_size_tiles, map_size_tiles])

	var camera: Camera2D = map.get("map_camera") as Camera2D
	var expected_world_size: Vector2 = Vector2.ONE * float(map_size_tiles * 32)
	_expect((camera.get("map_size") as Vector2) == expected_world_size, "%d×%d 镜头边界不正确" % [map_size_tiles, map_size_tiles])
	var ground: TileMapLayer = map.get("ground_layer") as TileMapLayer
	var repeated_grass: Sprite2D = ground.get_node_or_null("RepeatedGrass") as Sprite2D
	_expect(is_instance_valid(repeated_grass) and repeated_grass.region_rect.size == expected_world_size, "%d×%d 草地覆盖范围不正确" % [map_size_tiles, map_size_tiles])

	var streamer: WorldResourceStreamer = map.get("world_resource_streamer") as WorldResourceStreamer
	var pathfinder: WorldPathfinder = map.get("world_pathfinder") as WorldPathfinder
	var fog: FogOfWar = map.get("fog_of_war") as FogOfWar
	_expect(int(streamer.get("_map_size_tiles")) == map_size_tiles, "%d×%d 资源流送边界不正确" % [map_size_tiles, map_size_tiles])
	_expect((pathfinder.get("_grid_size") as Vector2i) == Vector2i.ONE * map_size_tiles, "%d×%d 寻路边界不正确" % [map_size_tiles, map_size_tiles])
	_expect((fog.get("_map_size_tiles") as Vector2i) == Vector2i.ONE * map_size_tiles, "%d×%d 迷雾边界不正确" % [map_size_tiles, map_size_tiles])

	var territory_rects: Array[Rect2i] = map.get("_territory_rects") as Array[Rect2i]
	_expect(territory_rects.size() == 2, "%d×%d 没有生成两块初始领地" % [map_size_tiles, map_size_tiles])
	for territory_rect: Rect2i in territory_rects:
		_expect(territory_rect.position.x >= 0 and territory_rect.position.y >= 0, "%d×%d 初始领地小于地图下界" % [map_size_tiles, map_size_tiles])
		_expect(territory_rect.end.x <= map_size_tiles and territory_rect.end.y <= map_size_tiles, "%d×%d 初始领地超过地图上界" % [map_size_tiles, map_size_tiles])
	if territory_rects.size() == 2:
		_expect(not territory_rects[0].intersects(territory_rects[1]), "%d×%d 两块初始领地发生重叠" % [map_size_tiles, map_size_tiles])
	var ai_expansion_rect: Rect2i = map.call(&"_get_ai_expansion_rect") as Rect2i
	_expect(ai_expansion_rect.size == Vector2i(20, 20) and bool(map.call(&"_is_valid_expansion_rect", ai_expansion_rect)), "%d×%d 没有合法的人机扩张位置" % [map_size_tiles, map_size_tiles])
	_expect((map.get("_wild_monsters") as Dictionary).size() == 5, "%d×%d 没有生成五只野怪" % [map_size_tiles, map_size_tiles])
	var world_boss: WorldBoss = map.get("_world_boss") as WorldBoss
	_expect(is_instance_valid(world_boss), "%d×%d 没有生成世界 BOSS" % [map_size_tiles, map_size_tiles])

	var controller: SimpleAIController = map.get("ai_controller") as SimpleAIController
	controller.configure(false)
	map.queue_free()
	await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("MAP_SIZE_SETTINGS_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("MAP_SIZE_SETTINGS_SMOKE_TEST: %s" % failure)
	get_tree().quit(1)

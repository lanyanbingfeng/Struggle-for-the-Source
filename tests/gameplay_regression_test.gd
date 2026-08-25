extends SceneTree

const UNIT_CATALOG: UnitCatalog = preload("res://game/data/unit_catalog.tres")
const BUILDING_CATALOG: BuildingCatalog = preload("res://game/data/building_catalog.tres")

var _failures: PackedStringArray = []

func _init() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var scene := load("res://game/main/main.tscn") as PackedScene
	var map := scene.instantiate() as Node2D
	root.add_child(map)
	await process_frame
	await process_frame
	map.call(&"_on_start_requested", false)
	await process_frame
	(map.get("ai_controller") as SimpleAIController).configure(false)
	var states := map.get("_player_resource_states") as Dictionary
	states[1] = {"gold": 9999, "wood": 9999, "stone": 9999, "iron": 9999, "gold_ore": 9999, "diamond": 9999}
	states[2] = {"gold": 9999, "wood": 9999, "stone": 9999, "iron": 9999, "gold_ore": 9999, "diamond": 9999}

	_expect(bool(map.call(&"_server_recruit_unit", 1, &"builder", 1)), "建筑工人应可从招募池招募")
	_expect(bool(map.call(&"_server_spawn_unit", 1, &"swordsman", 1)), "玩家应可生成剑士")
	_expect(bool(map.call(&"_server_spawn_unit", 2, &"swordsman", 2)), "敌方应可生成剑士")
	_expect(bool(map.call(&"_server_spawn_unit", 1, &"treant", 1)), "玩家应可生成树人")
	await process_frame

	var units := map.get("_network_units") as Dictionary
	var builder := _find_unit(units, 1, &"builder")
	var local_sword := _find_unit(units, 1, &"swordsman")
	var enemy_sword := _find_unit(units, 2, &"swordsman")
	var treant := _find_unit(units, 1, &"treant")
	_expect(is_instance_valid(builder), "建筑工人实例缺失")
	_expect(is_instance_valid(local_sword) and is_instance_valid(enemy_sword), "剑士实例缺失")
	_expect(is_instance_valid(treant), "树人实例缺失")
	if not _failures.is_empty():
		_finish(map)
		return

	# All equal unit types must point at the same shared .tres definition object.
	_expect(local_sword.get("definition") == enemy_sword.get("definition"), "同类单位没有共享同一份UnitDefinition资源")

	# Attack must wait for the full interval after entering range.
	local_sword.global_position = Vector2(3000.0, 3000.0)
	enemy_sword.global_position = Vector2(3020.0, 3000.0)
	var enemy_health := enemy_sword.get_node("HealthComponent") as HealthComponent
	enemy_health.evasion_chance = 0.0
	var enemy_before := enemy_health.current_health
	await create_timer(1.0).timeout
	_expect(is_equal_approx(enemy_health.current_health, enemy_before), "剑士进入范围后未等攻速时间就造成伤害")
	await create_timer(1.15).timeout
	_expect(enemy_health.current_health < enemy_before, "剑士达到攻速时间后没有造成伤害")

	# Photosynthesis heals the lowest-health nearby friendly unit and spends mana.
	treant.global_position = Vector2(2200.0, 2200.0)
	builder.global_position = Vector2(2220.0, 2200.0)
	var builder_health := builder.get_node("HealthComponent") as HealthComponent
	builder_health.evasion_chance = 0.0
	builder_health.apply_attack(60.0)
	var builder_damaged := builder_health.current_health
	var treant_health := treant.get_node("HealthComponent") as HealthComponent
	var mana_before := treant_health.current_mana
	await create_timer(0.55).timeout
	_expect(builder_health.current_health > builder_damaged, "树人光合作用没有治疗附近最低血量友军")
	_expect(treant_health.current_mana < mana_before, "树人光合作用没有消耗魔法")

	# Builder places a 2x2 production building at its current position.
	builder.global_position = Vector2(66.5 * 32.0, 75.5 * 32.0)
	var coin_definition := BUILDING_CATALOG.get_definition(&"coin_table")
	var placement_rect := map.call(&"_structure_rect_at", builder.global_position, coin_definition.footprint_tiles) as Rect2i
	_expect(bool(map.call(&"_server_build_structure", 1, int(builder.get("unit_id")), &"coin_table", placement_rect)), "建筑工人无法在领地空地建造金币生产台")
	await process_frame
	var buildings := map.get("_network_buildings") as Dictionary
	_expect(buildings.size() == 1, "建造完成后建筑网络字典数量不正确")
	if not buildings.is_empty():
		var building := buildings.values()[0] as ProductionBuilding
		_expect(building.has_node("HealthComponent") and building.has_node("HealthBar"), "建筑缺少生命组件或生命条")
		var building_health := building.get_node("HealthComponent") as HealthComponent
		var building_health_before := building_health.current_health
		builder.global_position += Vector2(240.0, 0.0)
		enemy_sword.call(&"set_navigation_path", PackedVector2Array())
		enemy_sword.global_position = building.global_position + Vector2(20.0, 0.0)
		await create_timer(2.45).timeout
		_expect(building_health.current_health < building_health_before, "敌方战斗单位无法攻击建筑并扣除生命")
		var gold_before := int((states[1] as Dictionary).get("gold", 0))
		building.call(&"_process", coin_definition.production_interval_seconds + 0.1)
		_expect(int((states[1] as Dictionary).get("gold", 0)) >= gold_before + coin_definition.production_amount, "金币生产台没有按配置产出资源")

	# Every unit and base spawned in this test must own one shared health UI pipeline.
	for unit: Node2D in units.values():
		if is_instance_valid(unit):
			_expect(unit.has_node("HealthComponent") and unit.has_node("HealthBar"), "%s缺少生命组件或生命条" % unit.name)
	var bases := map.get("_player_base_by_territory_id") as Dictionary
	for player_base: PlayerBase in bases.values():
		_expect(player_base.has_node("HealthComponent") and player_base.has_node("HealthBar"), "%s缺少生命组件或生命条" % player_base.name)
	var local_base := bases.get(1) as PlayerBase
	var enemy_base := bases.get(2) as PlayerBase
	_expect_sprite_tint(local_base, Color.WHITE, "己方基地")
	_expect_sprite_tint(enemy_base, PlayerBase.ENEMY_FACTION_TINT, "敌方基地")
	_expect_sprite_tint(local_sword, Color.WHITE, "己方单位")
	_expect_sprite_tint(enemy_sword, PlayerBase.ENEMY_FACTION_TINT, "敌方单位")

	# Paid summon cards are mandatory; recruitment cards remain cancellable.
	var summon_menu := map.get("summon_card_menu") as SummonCardMenu
	summon_menu.open_for(local_base, [UNIT_CATALOG.get_definition(&"swordsman")], true)
	summon_menu.close()
	_expect(summon_menu.visible, "付费召唤仍能通过空白取消")
	summon_menu.close(true)
	summon_menu.open_for(local_base, [UNIT_CATALOG.get_definition(&"builder")], false)
	summon_menu.close()
	_expect(not summon_menu.visible, "普通招募不再允许取消")

	_expect(BUILDING_CATALOG.definitions.size() == 6, "建筑目录必须恰好包含六类资源建筑")
	_expect_asset("res://art/units/unit_swordsman_1x1.png", Vector2i(32, 32))
	_expect_asset("res://art/units/unit_builder_1x1.png", Vector2i(32, 32))
	_expect_asset("res://art/structures/structure_resource_workshop_2x2.png", Vector2i(64, 64))
	_finish(map)

func _find_unit(units: Dictionary, owner_peer_id: int, definition_id: StringName) -> Node2D:
	for unit: Node2D in units.values():
		var definition := unit.get("definition") as UnitDefinition
		if int(unit.get("owner_peer_id")) == owner_peer_id and definition != null and definition.unit_id == definition_id:
			return unit
	return null

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _expect_sprite_tint(root_node: Node, expected_tint: Color, label: String) -> void:
	if not is_instance_valid(root_node):
		_expect(false, "%s实例缺失" % label)
		return
	var sprites: Array[Node] = root_node.find_children("*", "Sprite2D", true, false)
	_expect(not sprites.is_empty(), "%s没有可着色的Sprite2D" % label)
	for visual_node: Node in sprites:
		var sprite: Sprite2D = visual_node as Sprite2D
		_expect(sprite != null and sprite.self_modulate.is_equal_approx(expected_tint), "%s颜色不正确" % label)

func _expect_asset(path: String, expected_size: Vector2i) -> void:
	var image := Image.new()
	var load_error := image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
	_expect(load_error == OK, "%s无法加载：%s" % [path, error_string(load_error)])
	_expect(not image.is_empty(), "%s无法加载" % path)
	if image.is_empty():
		return
	_expect(image.get_size() == expected_size, "%s尺寸不是%s" % [path, expected_size])
	var has_transparent_pixel := false
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a < 0.999:
				has_transparent_pixel = true
				break
		if has_transparent_pixel:
			break
	_expect(has_transparent_pixel, "%s缺少透明背景" % path)

func _finish(map: Node) -> void:
	map.queue_free()
	if _failures.is_empty():
		print("GAMEPLAY_REGRESSION_OK")
		quit(0)
		return
	for failure: String in _failures:
		push_error("GAMEPLAY_REGRESSION: %s" % failure)
	quit(1)

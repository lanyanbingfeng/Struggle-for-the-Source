extends Node

const MAIN_SCENE: PackedScene = preload("res://game/main/main.tscn")
const UNIT_CATALOG: UnitCatalog = preload("res://game/data/unit_catalog.tres")

var _failures: PackedStringArray = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred(&"_run")

func _run() -> void:
	_verify_difficulty_profiles()

	var map: Node2D = MAIN_SCENE.instantiate() as Node2D
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame

	var main_menu: MainMenu = map.get("main_menu") as MainMenu
	_expect(main_menu.get_selected_ai_difficulty() == SimpleAIController.Difficulty.NORMAL, "主菜单默认难度不是普通")
	var difficulty_picker: OptionButton = main_menu.get("_difficulty_picker") as OptionButton
	_expect(is_instance_valid(difficulty_picker) and difficulty_picker.item_count == 4, "主菜单没有提供四档人机难度")

	map.call(&"_on_start_requested", false, SimpleAIController.Difficulty.HARD)
	await get_tree().process_frame
	var controller: SimpleAIController = map.get("ai_controller") as SimpleAIController
	_expect(int(map.get("_ai_difficulty")) == SimpleAIController.Difficulty.HARD, "单人难度没有传递给地图")
	_expect(controller.difficulty == SimpleAIController.Difficulty.HARD, "单人难度没有传递给决策器")
	controller.enabled = false
	controller.set_process(false)

	var bases: Dictionary = map.get("_player_base_by_peer_id") as Dictionary
	var player_base: PlayerBase = bases.get(1) as PlayerBase
	_expect(is_instance_valid(player_base), "玩家基地缺失")
	_expect(not bool(map.call(&"_is_world_position_visible_to_peer", player_base.global_position, 2)), "人机开局越过视野看见了玩家基地")
	map.call(&"_ai_refresh_enemy_knowledge")
	_expect(not bool(map.get("_ai_has_known_enemy")), "人机开局凭空获得了敌方位置")

	var units_before: Dictionary = map.get("_network_units") as Dictionary
	var initial_unit_count: int = units_before.size()
	map.call(&"_on_ai_think")
	_expect((map.get("_network_units") as Dictionary).size() == initial_unit_count, "一次思考同时执行了扩张和召唤")
	_expect((map.get("_pending_summon_by_peer_id") as Dictionary).is_empty(), "扩张步骤同时购买了召唤卡")
	map.call(&"_on_ai_think")
	var ai_offer: Dictionary = (map.get("_pending_summon_by_peer_id") as Dictionary).get(2, {}) as Dictionary
	var ai_card_ids: Array = ai_offer.get("card_ids", []) as Array
	_expect(ai_card_ids.size() == BaseProgression.SUMMON_CARD_COUNT, "人机没有使用恢复后的基地五卡召唤")
	for card_id_value: Variant in ai_card_ids:
		var offered_definition: UnitDefinition = UNIT_CATALOG.get_definition(StringName(str(card_id_value)))
		_expect(offered_definition != null and offered_definition.category == UnitDefinition.Category.COMBAT, "人机基地召唤卡混入非战斗单位")
	_expect((map.get("_network_units") as Dictionary).size() == initial_unit_count, "购买召唤卡的同一次思考又生成了单位")
	map.call(&"_on_ai_think")
	_expect((map.get("_pending_summon_by_peer_id") as Dictionary).is_empty(), "人机下一次思考没有领取已购买的召唤卡")
	_expect((map.get("_network_units") as Dictionary).size() == initial_unit_count + 1, "人机领取基地召唤卡后没有生成战斗单位")

	_expect(bool(map.call(&"_server_spawn_unit", 1, &"swordsman", 1)), "测试用玩家剑士生成失败")
	var player_unit: Node2D = _find_unit(map.get("_network_units") as Dictionary, 1, &"swordsman")
	_expect(is_instance_valid(player_unit), "测试用玩家剑士缺失")
	var ai_origin: Vector2 = map.get("_ai_scout_origin") as Vector2
	player_unit.global_position = ai_origin + Vector2(64.0, 0.0)
	map.call(&"_ai_refresh_enemy_knowledge")
	_expect(StringName(map.get("_ai_known_enemy_kind")) == &"unit", "人机没有发现视野内的玩家单位")
	var last_seen_position: Vector2 = map.get("_ai_known_enemy_position") as Vector2
	player_unit.global_position = Vector2(500.0, 500.0) * 32.0
	map.call(&"_ai_refresh_enemy_knowledge")
	_expect((map.get("_ai_known_enemy_position") as Vector2).is_equal_approx(last_seen_position), "人机持续追踪了迷雾内的移动单位")

	var explorer: ExplorerUnit = _find_unit(map.get("_network_units") as Dictionary, 2, &"explorer") as ExplorerUnit
	_expect(is_instance_valid(explorer), "人机探索者缺失")
	explorer.global_position = player_base.global_position + Vector2(32.0, 0.0)
	map.call(&"_ai_refresh_enemy_knowledge")
	_expect(StringName(map.get("_ai_known_enemy_kind")) == &"base", "探索者进入视野后仍未发现玩家基地")
	_expect((map.get("_ai_known_enemy_position") as Vector2).is_equal_approx(player_base.global_position), "人机记录的基地位置不正确")

	map.queue_free()
	await get_tree().process_frame
	if _failures.is_empty():
		print("AI_DIFFICULTY_SMOKE_TEST: PASS")
		await get_tree().create_timer(2.0).timeout
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("AI_DIFFICULTY_SMOKE_TEST: %s" % failure)
	await get_tree().create_timer(2.0).timeout
	get_tree().quit(1)

func _verify_difficulty_profiles() -> void:
	var easy_delay: Vector2 = SimpleAIController.get_think_delay_range(SimpleAIController.Difficulty.EASY)
	var normal_delay: Vector2 = SimpleAIController.get_think_delay_range(SimpleAIController.Difficulty.NORMAL)
	var hard_delay: Vector2 = SimpleAIController.get_think_delay_range(SimpleAIController.Difficulty.HARD)
	var hell_delay: Vector2 = SimpleAIController.get_think_delay_range(SimpleAIController.Difficulty.HELL)
	_expect(easy_delay.x > normal_delay.x and normal_delay.x > hard_delay.x, "简单、普通、困难的思考时间没有逐级缩短")
	_expect(hard_delay.x > 0.0, "困难难度不应取消思考时间")
	_expect(hell_delay == Vector2.ZERO, "地狱难度仍然存在人工思考延迟")

func _find_unit(units: Dictionary, owner_peer_id: int, definition_id: StringName) -> Node2D:
	for unit_value: Variant in units.values():
		var unit: Node2D = unit_value as Node2D
		if not is_instance_valid(unit) or int(unit.get("owner_peer_id")) != owner_peer_id:
			continue
		var definition: UnitDefinition = unit.get("definition") as UnitDefinition
		if definition != null and definition.unit_id == definition_id:
			return unit
	return null

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

extends Node

const UNIT_CATALOG: UnitCatalog = preload("res://game/data/unit_catalog.tres")
const BUILDING_CATALOG: BuildingCatalog = preload("res://game/data/building_catalog.tres")
const UPGRADE_VFX_SCRIPT: Script = preload("res://game/world/vfx/upgrade_vfx.gd")
const UPGRADE_UNIT_EXPECTED_SCALE: float = 52.0 / 64.0
const UPGRADE_BUILDING_EXPECTED_SCALE: float = 84.0 / 64.0
const UPGRADE_BASE_EXPECTED_SCALE: float = 92.0 / 64.0

var _failures: PackedStringArray = []

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred(&"_run")

func _run() -> void:
	var scene := load("res://game/main/main.tscn") as PackedScene
	var map := scene.instantiate() as Node2D
	get_tree().root.add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame
	map.call(&"_on_start_requested", false)
	await get_tree().process_frame
	(map.get("ai_controller") as SimpleAIController).configure(false)
	var base_action_configs: Array[Dictionary] = (map.get("base_action_menu") as BaseActionMenu).get("_action_configs") as Array[Dictionary]
	var summon_button_text: String = ""
	for action_config: Dictionary in base_action_configs:
		if StringName(str(action_config.get("action", ""))) == &"summon":
			summon_button_text = str(action_config.get("text", ""))
	_expect(summon_button_text == "召唤", "基地召唤按钮没有恢复为“召唤”文案")
	var states := map.get("_player_resource_states") as Dictionary
	states[1] = {"gold": 9999, "wood": 9999, "stone": 9999, "iron": 9999, "summon_token": 9999, "skill_experience": 9999, "experience": 9999}
	states[2] = {"gold": 9999, "wood": 9999, "stone": 9999, "iron": 9999, "summon_token": 9999, "skill_experience": 9999, "experience": 9999}

	# The base summon button restores the paid five-card combat offer; the hero altar remains a separate direct-choice path.
	var gold_before_base_summon: int = int((states[1] as Dictionary).get("gold", 0))
	map.call(&"_on_base_action_selected", &"summon")
	var base_summon_offer: Dictionary = (map.get("_pending_summon_by_peer_id") as Dictionary).get(1, {}) as Dictionary
	var base_summon_cards: Array = base_summon_offer.get("card_ids", []) as Array
	var base_summon_menu: SummonCardMenu = map.get("summon_card_menu") as SummonCardMenu
	var base_summon_card_row: HBoxContainer = base_summon_menu.get("_card_row") as HBoxContainer
	_expect(base_summon_cards.size() == BaseProgression.SUMMON_CARD_COUNT and base_summon_card_row.get_child_count() == BaseProgression.SUMMON_CARD_COUNT, "点击基地召唤没有显示五张单位卡牌")
	_expect(int((states[1] as Dictionary).get("gold", 0)) == gold_before_base_summon - BaseProgression.SUMMON_COST, "基地五卡召唤没有扣除10金币")
	for card_id_value: Variant in base_summon_cards:
		var offered_definition: UnitDefinition = UNIT_CATALOG.get_definition(StringName(str(card_id_value)))
		_expect(offered_definition != null and offered_definition.category == UnitDefinition.Category.COMBAT, "基地召唤卡牌混入了非战斗单位")
	base_summon_menu.close(true)
	(map.get("_pending_summon_by_peer_id") as Dictionary).erase(1)
	map.set("_card_menu_mode", &"")
	map.set("_active_summon_offer_id", 0)
	var upgrade_test_bases: Dictionary = map.get("_player_base_by_territory_id") as Dictionary
	var upgrade_test_base: PlayerBase = upgrade_test_bases.get(1) as PlayerBase
	_expect(bool(map.call(&"_server_upgrade_base", 1)), "基地升级失败")
	_expect(is_instance_valid(upgrade_test_base) and upgrade_test_base.base_level == 2, "基地升级没有提升等级")
	_expect_upgrade_vfx(upgrade_test_base, "基地", UPGRADE_BASE_EXPECTED_SCALE)

	# Streamed resources outside territories must remain part of navigation even when their markers are unloaded.
	var world_pathfinder := map.get("world_pathfinder") as WorldPathfinder
	var world_resource_streamer := map.get("world_resource_streamer") as WorldResourceStreamer
	var external_obstacle_cells: Array[Vector2i] = world_resource_streamer.get_navigation_obstacle_cells()
	_expect(not external_obstacle_cells.is_empty(), "领地外资源没有生成寻路障碍数据")
	var external_detour: Dictionary = _find_external_resource_detour(world_pathfinder, external_obstacle_cells, 32)
	_expect(not external_detour.is_empty(), "寻路系统没有为领地外资源生成绕行路径")
	if not external_detour.is_empty():
		var external_cell: Vector2i = external_detour.get("cell", Vector2i.ZERO) as Vector2i
		var external_cell_center: Vector2 = _cell_center(external_cell, 32)
		var detour_path: PackedVector2Array = external_detour.get("path", PackedVector2Array()) as PackedVector2Array
		_expect(not world_pathfinder.is_world_position_walkable(external_cell_center), "领地外资源所在格仍被判定为可通行")
		_expect(detour_path.size() > 1, "单位路径仍然直接穿过领地外资源")
	var world_counts: Dictionary = world_resource_streamer.get_total_counts()
	_expect(int(world_counts.get(&"summon_token", 0)) == 0 and int(world_counts.get(&"skill_experience", 0)) == 0, "场景仍直接生成召唤符或技能经验矿点")
	_expect(int(world_counts.get(&"chest", 0)) > 0, "领地外没有生成宝箱")
	var streamed_chest_data: Dictionary = {}
	for data_value: Variant in (world_resource_streamer.get("_resource_data_by_id") as Dictionary).values():
		var candidate_data: Dictionary = data_value as Dictionary
		if StringName(str(candidate_data.get("resource_type", ""))) == &"chest":
			streamed_chest_data = candidate_data
			break
	_expect(not streamed_chest_data.is_empty(), "没有找到可右键攻击的领地外流送宝箱")
	if not streamed_chest_data.is_empty():
		var streamed_resource_id: int = int(streamed_chest_data.get("resource_id", 0))
		var streamed_chest_position: Vector2 = map.call(&"_resource_world_position", streamed_chest_data.get("cell", Vector2i.ZERO) as Vector2i) as Vector2
		world_resource_streamer.update_streaming(streamed_chest_position, true)
		var streamed_pick: Dictionary = map.call(&"_find_attackable_chest_at", streamed_chest_position + Vector2(0.0, -16.0)) as Dictionary
		_expect(int(streamed_pick.get("chest_id", 0)) == 1000000 + streamed_resource_id, "右键检测没有识别领地外流送宝箱")
		var streamed_chest_health: HealthComponent = map.call(&"_get_damageable_by_identity", &"chest", 1000000 + streamed_resource_id) as HealthComponent
		_expect(is_instance_valid(streamed_chest_health) and not (world_resource_streamer.get("_resource_data_by_id") as Dictionary).has(streamed_resource_id), "领地外宝箱没有按需实体化为战斗目标")

	# A depleted territory restores exactly one queued tree after sixty seconds.
	var initial_tree_count: int = int(map.call(&"_count_territory_trees", 1))
	var removed_tree: Node2D
	for child: Node in (map.get("tree_container") as Node2D).get_children():
		if child is Node2D and int(child.get("territory_id")) == 1:
			removed_tree = child as Node2D
			break
	_expect(is_instance_valid(removed_tree), "没有找到可用于恢复测试的领地树木")
	if is_instance_valid(removed_tree):
		map.call(&"_queue_tree_regrowth", 1, removed_tree.global_position)
		removed_tree.queue_free()
		await get_tree().process_frame
		map.call(&"_process_tree_regrowth", 59.0)
		_expect(int(map.call(&"_count_territory_trees", 1)) == initial_tree_count - 1, "领地树木在未满一分钟时提前恢复")
		map.call(&"_process_tree_regrowth", 1.0)
		_expect(int(map.call(&"_count_territory_trees", 1)) == initial_tree_count, "领地树木没有在一分钟后恢复一棵")

	_expect(bool(map.call(&"_server_recruit_unit", 1, &"builder", 1)), "建筑工人应可从招募池招募")
	_expect(bool(map.call(&"_server_spawn_unit", 1, &"lumber", 1)), "玩家应可生成伐木机器用于升级特效验证")
	_expect(bool(map.call(&"_server_spawn_unit", 1, &"swordsman", 1)), "玩家应可生成剑士")
	_expect(bool(map.call(&"_server_spawn_unit", 2, &"swordsman", 2)), "敌方应可生成剑士")
	_expect(bool(map.call(&"_server_spawn_unit", 2, &"swordsman", 2)), "敌方应可生成第二名剑士")
	_expect(bool(map.call(&"_server_spawn_unit", 1, &"treant", 1)), "玩家应可生成树人")
	await get_tree().process_frame

	var units := map.get("_network_units") as Dictionary
	var wild_monsters := map.get("_wild_monsters") as Dictionary
	_expect(wild_monsters.size() == 6, "野外蜘蛛精英数量不正确")
	var builder := _find_unit(units, 1, &"builder")
	var lumber_machine: Node2D = _find_unit(units, 1, &"lumber")
	var local_sword := _find_unit(units, 1, &"swordsman")
	var enemy_swords: Array[Node2D] = _find_units(units, 2, &"swordsman")
	var enemy_sword: Node2D = enemy_swords[0] if not enemy_swords.is_empty() else null
	var execute_victim: Node2D = enemy_swords[1] if enemy_swords.size() > 1 else null
	var treant := _find_unit(units, 1, &"treant")
	var local_sword_ids: Array[int] = []
	if is_instance_valid(local_sword):
		local_sword_ids.append(int(local_sword.get("unit_id")))
	_expect(is_instance_valid(builder), "建筑工人实例缺失")
	_expect(is_instance_valid(lumber_machine), "伐木机器实例缺失")
	_expect(is_instance_valid(local_sword) and is_instance_valid(enemy_sword) and is_instance_valid(execute_victim), "剑士实例缺失")
	_expect(is_instance_valid(treant), "树人实例缺失")
	if is_instance_valid(lumber_machine):
		lumber_machine.call(&"set_work_enabled", false)
		_expect(bool(map.call(&"_server_upgrade_machine", 1, int(lumber_machine.get("unit_id")))), "伐木机器升级失败")
		_expect(int(lumber_machine.get("machine_level")) == 2, "伐木机器升级没有提升等级")
		_expect_upgrade_vfx(lumber_machine, "机器单位", UPGRADE_UNIT_EXPECTED_SCALE)
	var combat_chests: Dictionary = map.get("_combat_chests") as Dictionary
	var territory_chest: Node2D
	for chest: Node2D in combat_chests.values():
		if is_instance_valid(chest) and int(chest.get("territory_id")) == 1:
			territory_chest = chest
			break
	_expect(is_instance_valid(territory_chest), "玩家领地内没有可供战斗单位打开的宝箱")
	if is_instance_valid(territory_chest) and is_instance_valid(local_sword):
		var chest_health: HealthComponent = territory_chest.get_node_or_null("HealthComponent") as HealthComponent
		var chest_gold_before: int = int((states[1] as Dictionary).get("gold", 0))
		var chest_iron_before: int = int((states[1] as Dictionary).get("iron", 0))
		var chest_token_before: int = int((states[1] as Dictionary).get("summon_token", 0))
		map.call(&"_set_selected_units", local_sword_ids)
		local_sword.global_position = territory_chest.global_position + Vector2(140.0, 0.0)
		map.call(&"_handle_move_command", territory_chest.global_position + Vector2(0.0, -16.0))
		_expect(local_sword.get("_priority_target") == chest_health and bool(local_sword.get("has_move_target")), "右键宝箱没有让选中的战斗单位寻路攻击")
		local_sword.global_position = territory_chest.global_position + Vector2(40.0, 0.0)
		local_sword.call(&"_process_combat_target", UNIT_CATALOG.get_definition(&"swordsman").attack_interval_seconds)
		await get_tree().create_timer(0.5).timeout
		_expect(not is_instance_valid(territory_chest), "战斗单位攻击后宝箱没有打开并消失")
		_expect(not bool(local_sword.get("_returning_from_combat")) and not bool(local_sword.get("has_move_target")), "战斗单位打开玩家指定的宝箱后错误返回初始位置")
		_expect(int((states[1] as Dictionary).get("gold", 0)) == chest_gold_before + 30 and int((states[1] as Dictionary).get("iron", 0)) == chest_iron_before + 2, "战斗单位打开宝箱没有获得金币和铁")
		_expect(int((states[1] as Dictionary).get("summon_token", 0)) == chest_token_before + 1, "战斗单位打开宝箱没有获得召唤符")
		local_sword.call(&"set_navigation_path", PackedVector2Array())
	if not wild_monsters.is_empty():
		var monster: WildMonster = wild_monsters.values()[0] as WildMonster
		var monster_health: HealthComponent = monster.get_node("HealthComponent") as HealthComponent
		_expect(monster is CharacterBody2D, "幽网织母仍不是可移动的CharacterBody2D")
		_expect(monster.get_display_name() == "幽网织母·维洛莎", "蜘蛛精英名称不正确")
		_expect(is_equal_approx(monster_health.max_health, WildMonster.MAX_HEALTH) and is_equal_approx(monster_health.defense, WildMonster.DEFENSE), "蜘蛛精英没有使用强化后的生命与防御")
		_expect(WildMonster.ATTACK_DAMAGE >= 48.0 and WildMonster.MOVEMENT_SPEED > 0.0, "蜘蛛精英的攻击或移动数值仍然过弱")
		var name_label: Label = monster.get_node_or_null("NameLabel") as Label
		_expect(is_instance_valid(name_label) and name_label.text.contains("精英") and name_label.text.contains("维洛莎"), "蜘蛛精英没有显示名称与精英标记")
		monster.simulation_enabled = false
		var monster_origin: Vector2 = monster.global_position
		monster.call(&"_move_toward_point", monster_origin + Vector2(160.0, 0.0))
		_expect(monster.velocity.length() >= WildMonster.MOVEMENT_SPEED - 0.01, "蜘蛛精英追击时没有产生移动速度")
		monster.global_position = monster_origin
		monster.velocity = Vector2.ZERO
		monster.play_attack_visual(monster_origin + Vector2(128.0, 0.0))
		var web_victim_health: HealthComponent = local_sword.get_node("HealthComponent") as HealthComponent
		var victim_origin: Vector2 = local_sword.global_position
		local_sword.global_position = monster_origin + Vector2(96.0, 0.0)
		web_victim_health.evasion_chance = 0.0
		var victim_health_before_web: float = web_victim_health.current_health
		var web_targets: Array[HealthComponent] = [web_victim_health]
		monster.setup_combat_context(_return_health_targets.bind(web_targets), Callable(), 32)
		monster.set("_target", web_victim_health)
		monster.set("_skill_cooldown_remaining", 0.0)
		_expect(bool(monster.call(&"_try_cast_web_skill")), "幽网织母没有成功施放范围蛛网")
		_expect(web_victim_health.current_health < victim_health_before_web, "范围蛛网没有造成伤害")
		_expect(float(local_sword.call(&"get_control_remaining")) >= WildMonster.WEB_SKILL_CONTROL_SECONDS - 0.01, "范围蛛网没有控制命中单位")
		await get_tree().process_frame
		_expect(is_instance_valid(monster.get_node_or_null("EliteSpiderVenomBoltVfx")), "毒液弹幕攻击特效没有生成")
		_expect(is_instance_valid(monster.get_node_or_null("EliteSpiderWebFieldVfx")), "范围蛛网技能特效没有生成")
		web_victim_health.apply_network_state(web_victim_health.max_health, web_victim_health.current_mana)
		local_sword.set("_control_remaining", 0.0)
		local_sword.global_position = victim_origin
		var token_before_drop: int = int((states[1] as Dictionary).get("summon_token", 0))
		var skill_before_drop: int = int((states[1] as Dictionary).get("skill_experience", 0))
		var experience_before_drop: int = int((states[1] as Dictionary).get("experience", 0))
		monster_health.apply_attack(99999.0, 1)
		_expect(int((states[1] as Dictionary).get("summon_token", 0)) == token_before_drop + 1, "击杀野怪没有掉落召唤符")
		_expect(int((states[1] as Dictionary).get("skill_experience", 0)) == skill_before_drop + 6, "击杀野怪没有掉落技能经验")
		_expect(int((states[1] as Dictionary).get("experience", 0)) == experience_before_drop + 20, "击杀野怪没有掉落英雄经验")
	_expect_vfx_frames(local_sword, "AttackVfx", 8, "剑士普攻")
	_expect_vfx_frames(local_sword, "SkillVfx", 8, "剑士技能")
	_expect_vfx_frames(treant, "AttackVfx", 8, "树人普攻")
	_expect_vfx_frames(treant, "SkillVfx", 8, "树人技能")
	_expect_treant_skill_frame_size(&"treant", 208)
	_expect_treant_skill_frame_size(&"ironbark_treant", 224)
	_expect_treant_skill_frame_size(&"ancient_treant", 240)
	_expect_treant_skill_frame_size(&"worldroot_guardian", 256)
	if not _failures.is_empty():
		_finish(map)
		return

	# All equal unit types must point at the same shared .tres definition object.
	_expect(local_sword.get("definition") == enemy_sword.get("definition"), "同类单位没有共享同一份UnitDefinition资源")
	var enemy_health := enemy_sword.get_node("HealthComponent") as HealthComponent
	var execute_health := execute_victim.get_node("HealthComponent") as HealthComponent
	var local_sword_health := local_sword.get_node("HealthComponent") as HealthComponent
	enemy_health.evasion_chance = 0.0
	execute_health.evasion_chance = 0.0

	# A player move command owns the unit until it reaches the destination, even with an enemy nearby.
	local_sword.global_position = Vector2(3000.0, 3000.0)
	enemy_sword.global_position = Vector2(2970.0, 3000.0)
	execute_victim.global_position = Vector2(6000.0, 6000.0)
	local_sword_health.current_mana = 0.0
	local_sword_health.apply_network_state(local_sword_health.max_health, local_sword_health.current_mana)
	enemy_health.apply_network_state(enemy_health.max_health, enemy_health.current_mana)
	var manual_destination := Vector2(3200.0, 3000.0)
	var manual_distance_before: float = local_sword.global_position.distance_to(manual_destination)
	var enemy_health_before_manual: float = enemy_health.current_health
	_expect(bool(map.call(&"_server_move_units", 1, local_sword_ids, manual_destination)), "玩家移动指令没有被服务器接受")
	_expect(bool(local_sword.get("_manual_move_active")), "玩家移动指令没有进入手动优先状态")
	await get_tree().create_timer(0.6).timeout
	_expect(local_sword.global_position.distance_to(manual_destination) < manual_distance_before, "剑士没有服从玩家移动指令")
	_expect(is_equal_approx(enemy_health.current_health, enemy_health_before_manual), "剑士执行玩家移动指令时仍擅自攻击附近敌人")
	local_sword.call(&"set_navigation_path", PackedVector2Array())
	local_sword_health.apply_network_state(local_sword_health.max_health, local_sword_health.current_mana)

	# Clicking a hostile preserves friendly selection and makes it the explicit priority target.
	local_sword.global_position = Vector2(3300.0, 3300.0)
	enemy_sword.global_position = Vector2(3310.0, 3300.0)
	execute_victim.global_position = Vector2(3330.0, 3300.0)
	enemy_sword.show()
	execute_victim.show()
	enemy_health.apply_network_state(enemy_health.max_health, enemy_health.current_mana)
	execute_health.apply_network_state(execute_health.max_health, execute_health.current_mana)
	map.call(&"_set_selected_units", local_sword_ids)
	map.call(&"_select_single_unit", execute_victim.global_position)
	_expect(map.get("_selected_enemy_target") == execute_health, "点击敌方单位后没有记录玩家指定目标")
	_expect(local_sword.get("_priority_target") == execute_health, "剑士没有优先锁定玩家选中的敌方单位")
	var nearer_enemy_before: float = enemy_health.current_health
	var priority_enemy_before: float = execute_health.current_health
	if is_instance_valid(local_sword.get("_combat_target") as HealthComponent):
		local_sword.call(&"_process_combat_target", 0.6)
	_expect(execute_health.current_health < priority_enemy_before, "剑士没有攻击玩家指定的敌方单位")
	_expect(is_equal_approx(enemy_health.current_health, nearer_enemy_before), "剑士错误地攻击了更近但未被玩家指定的敌人")
	execute_health.apply_network_state(execute_health.max_health, execute_health.current_mana)
	local_sword.call(&"set_navigation_path", PackedVector2Array())
	map.call(&"_clear_selected_enemy_target")

	# Swordsman attacks quickly, but still exposes a readable anticipation window.
	var swordsman_definition: UnitDefinition = UNIT_CATALOG.get_definition(&"swordsman")
	_expect(swordsman_definition.attack_interval_seconds <= 1.1, "剑士攻速仍然过慢")
	_expect(swordsman_definition.attack <= 44, "提速后剑士单刀伤害没有同步收敛")
	_expect(swordsman_definition.skill_name == "这一剑会很帅", "剑士技能名称不正确")
	local_sword.global_position = Vector2(3000.0, 3000.0)
	enemy_sword.global_position = Vector2(3020.0, 3000.0)
	execute_victim.global_position = Vector2(6000.0, 6000.0)
	enemy_health.apply_network_state(enemy_health.max_health, enemy_health.current_mana)
	enemy_health.evasion_chance = 0.0
	local_sword_health.current_mana = 0.0
	var local_sword_sprite: Sprite2D = local_sword.get_node("Sprite") as Sprite2D
	var sword_scale_before_attack: Vector2 = local_sword_sprite.scale
	var enemy_before := enemy_health.current_health
	await get_tree().create_timer(0.25).timeout
	_expect(is_equal_approx(enemy_health.current_health, enemy_before), "剑士攻击缺少可读的前摇")
	await get_tree().create_timer(0.5).timeout
	_expect(enemy_health.current_health < enemy_before, "剑士提速后仍未及时造成伤害")
	_expect(
		is_equal_approx(absf(local_sword_sprite.scale.x), absf(sword_scale_before_attack.x))
		and is_equal_approx(local_sword_sprite.scale.y, sword_scale_before_attack.y),
		"剑士攻击动画破坏了世界卡图缩放"
	)

	# Stylish Slash deals 200% attack damage in a wide area and directly executes only targets below 5% health.
	local_sword.global_position = Vector2(3400.0, 3400.0)
	enemy_sword.global_position = Vector2(3460.0, 3400.0)
	execute_victim.global_position = Vector2(3480.0, 3400.0)
	local_sword_health.current_mana = local_sword_health.max_mana
	local_sword.set("_skill_cooldown_remaining", 0.0)
	local_sword.set("_skill_scan_elapsed", 0.0)
	enemy_health.evasion_chance = 0.0
	execute_health.evasion_chance = 0.0
	execute_health.apply_network_state(execute_health.max_health * 0.04, execute_health.current_mana)
	var splash_before: float = enemy_health.current_health
	local_sword.call(&"_process_skill", 0.25)
	var splash_damage: float = splash_before - enemy_health.current_health
	var expected_skill_damage: float = maxf(1.0, float(swordsman_definition.attack) * 2.0 - enemy_health.defense)
	_expect(is_equal_approx(swordsman_definition.skill_attack_multiplier, 2.0), "这一剑会很帅没有配置为200%攻击力倍率")
	_expect(is_equal_approx(swordsman_definition.get_skill_damage(), float(swordsman_definition.attack) * 2.0), "这一剑会很帅没有按攻击力倍率计算原始伤害")
	_expect(is_equal_approx(splash_damage, expected_skill_damage), "这一剑会很帅没有造成200%攻击力伤害")
	_expect(not execute_health.is_alive(), "这一剑会很帅没有斩杀生命低于5%的敌人")
	var slash_vfx := local_sword.get_node_or_null("SkillVfx") as AnimatedSprite2D
	_expect(is_instance_valid(slash_vfx) and slash_vfx.is_playing(), "这一剑会很帅没有播放金色序列帧")
	local_sword.global_position = Vector2(5000.0, 5000.0)
	enemy_sword.global_position = Vector2(5200.0, 5200.0)

	# Photosynthesis heals every injured friendly in range for exactly 10% maximum health.
	treant.global_position = Vector2(2200.0, 2200.0)
	builder.global_position = Vector2(2220.0, 2200.0)
	local_sword.global_position = Vector2(2240.0, 2200.0)
	var builder_health: HealthComponent = builder.get_node("HealthComponent") as HealthComponent
	var treant_health: HealthComponent = treant.get_node("HealthComponent") as HealthComponent
	builder_health.apply_network_state(builder_health.max_health * 0.5, builder_health.current_mana)
	local_sword_health.apply_network_state(local_sword_health.max_health * 0.5, local_sword_health.current_mana)
	treant_health.apply_network_state(treant_health.max_health * 0.5, treant_health.max_mana)
	var builder_before_heal: float = builder_health.current_health
	var sword_before_heal: float = local_sword_health.current_health
	var treant_before_heal: float = treant_health.current_health
	var mana_before: float = treant_health.current_mana
	var treant_definition: UnitDefinition = UNIT_CATALOG.get_definition(&"treant")
	treant.set("_skill_cooldown_remaining", 0.0)
	var photosynthesis_cast: bool = bool(treant.call(&"_try_cast_photosynthesis"))
	_expect(photosynthesis_cast, "树人光合作用没有在范围内存在受伤友方时施放")
	_expect(is_equal_approx(builder_health.current_health - builder_before_heal, builder_health.max_health * 0.1), "光合作用没有治疗范围内建筑工人10%最大生命")
	_expect(is_equal_approx(local_sword_health.current_health - sword_before_heal, local_sword_health.max_health * 0.1), "光合作用没有治疗范围内剑士10%最大生命")
	_expect(is_equal_approx(treant_health.current_health - treant_before_heal, treant_health.max_health * 0.1), "光合作用没有治疗施法树人自身10%最大生命")
	_expect(is_equal_approx(mana_before - treant_health.current_mana, float(treant_definition.skill_mana_cost)), "树人光合作用没有只消耗一次技能魔法")
	_expect(is_equal_approx(treant_definition.skill_heal_percent, 0.1), "树人光合作用没有配置为10%最大生命范围治疗")
	_expect(is_equal_approx(float(treant.get("_skill_cooldown_remaining")), treant_definition.skill_cooldown_seconds), "树人光合作用没有进入独立冷却")
	var photosynthesis_vfx: AnimatedSprite2D = treant.get_node_or_null("SkillVfx") as AnimatedSprite2D
	_expect(is_instance_valid(photosynthesis_vfx) and photosynthesis_vfx.is_playing(), "树人光合作用没有播放绿色范围序列帧")
	var treant_ids: Array[StringName] = [&"treant", &"ironbark_treant", &"ancient_treant", &"worldroot_guardian"]
	var expected_treant_stats: Dictionary = {
		&"treant": Vector2i(280, 40),
		&"ironbark_treant": Vector2i(360, 48),
		&"ancient_treant": Vector2i(500, 60),
		&"worldroot_guardian": Vector2i(700, 80),
	}
	for treant_id: StringName in treant_ids:
		var tier_definition: UnitDefinition = UNIT_CATALOG.get_definition(treant_id)
		_expect(tier_definition != null and is_equal_approx(tier_definition.skill_heal_percent, 0.1), "%s光合作用不是10%%范围治疗" % treant_id)
		var expected_stats: Vector2i = expected_treant_stats.get(treant_id, Vector2i.ZERO) as Vector2i
		_expect(
			tier_definition != null
				and tier_definition.max_health == expected_stats.x
				and tier_definition.defense == expected_stats.y,
			"%s树人坦度属性没有应用当前削弱" % treant_id
		)

	# Builder previews a 2x2 building, nudges it by one tile, walks there, then disappears during construction.
	var coin_definition := BUILDING_CATALOG.get_definition(&"coin_table")
	_expect(coin_definition.cost_gold == 0 and coin_definition.cost_wood > 0 and coin_definition.cost_stone > 0, "金币生产台没有改为只消耗木材和石头")
	builder.global_position = map.call(&"_territory_base_position", 1) as Vector2
	map.call(&"_on_structure_preview_requested", int(builder.get("unit_id")), &"coin_table")
	_expect(int(map.get("_structure_preview_unit_id")) == int(builder.get("unit_id")) and not bool((map.get("command_overlay") as WorldCommandOverlay).get("_build_preview_valid")), "建筑当前位置无效时没有进入红色选址预览")
	var invalid_preview_before: Rect2i = map.get("_structure_preview_rect") as Rect2i
	map.call(&"_on_structure_confirmed")
	_expect(int(map.get("_structure_preview_unit_id")) == int(builder.get("unit_id")), "红色无效位置确认后错误地关闭了建筑预览")
	_expect(bool(map.call(&"_try_nudge_structure_preview", KEY_D)) and (map.get("_structure_preview_rect") as Rect2i).position == invalid_preview_before.position + Vector2i.RIGHT, "红色无效位置仍然阻止了WASD微调")
	map.call(&"_cancel_structure_preview")
	builder.global_position = Vector2(66.5 * 32.0, 75.5 * 32.0)
	var placement_rect := map.call(&"_structure_rect_at", builder.global_position, coin_definition.footprint_tiles) as Rect2i
	map.call(&"_on_structure_preview_requested", int(builder.get("unit_id")), &"coin_table")
	_expect(bool((map.get("command_overlay") as WorldCommandOverlay).get("_build_preview_valid")), "可建造位置没有显示绿色预览")
	var preview_rect_before: Rect2i = map.get("_structure_preview_rect") as Rect2i
	_expect(bool(map.call(&"_try_nudge_structure_preview", KEY_D)), "建筑预览没有接收WASD微调")
	placement_rect = map.get("_structure_preview_rect") as Rect2i
	_expect(placement_rect.position == preview_rect_before.position + Vector2i.RIGHT, "建筑预览没有按单格向右移动")
	map.call(&"_cancel_structure_preview")
	_expect(bool(map.call(&"_server_build_structure", 1, int(builder.get("unit_id")), &"coin_table", placement_rect)), "建筑工人无法在领地空地建造金币生产台")
	_expect((map.get("_network_buildings") as Dictionary).is_empty(), "工人尚未到达时建筑已经提前生成")
	_expect((map.get("_pending_structure_job_by_unit_id") as Dictionary).has(int(builder.get("unit_id"))), "确认后没有创建建筑工人的寻路施工任务")
	var coin_job: Dictionary = (map.get("_pending_structure_job_by_unit_id") as Dictionary).get(int(builder.get("unit_id")), {}) as Dictionary
	var approach_position: Vector2 = coin_job.get("approach_position", builder.global_position) as Vector2
	var distance_before_walk: float = builder.global_position.distance_to(approach_position)
	_expect(builder.visible and not bool(builder.get_meta(&"construction_busy", false)), "建筑工人在到达施工位置前不应消失")
	_expect(bool(builder.get("has_move_target")), "确认建造后建筑工人没有开始向施工位置移动")
	await get_tree().create_timer(0.2).timeout
	_expect(builder.global_position.distance_to(approach_position) < distance_before_walk, "建筑工人没有实际向施工位置靠近")
	builder.global_position = coin_job.get("approach_position", builder.global_position) as Vector2
	builder.call(&"set_navigation_path", PackedVector2Array())
	map.call(&"_process_pending_structure_jobs")
	await get_tree().process_frame
	var buildings := map.get("_network_buildings") as Dictionary
	_expect(buildings.size() == 1, "建造完成后建筑网络字典数量不正确")
	if not buildings.is_empty():
		var building := buildings.values()[0] as ProductionBuilding
		_expect(building.has_node("HealthComponent") and building.has_node("HealthBar"), "建筑缺少生命组件或生命条")
		_expect(not building.construction_complete and building.get_node("ConstructionBar").visible, "建筑生成后没有进入施工状态")
		_expect(bool(builder.get_meta(&"construction_busy", false)) and not builder.visible, "建筑工人没有在施工期间消失")
		building.call(&"_process", coin_definition.construction_seconds + 0.1)
		_expect(building.construction_complete and not building.get_node("ConstructionBar").visible, "建筑施工倒计时结束后没有完成")
		_expect(not bool(builder.get_meta(&"construction_busy", false)) and builder.visible, "建筑完成后建筑工人没有重新出现")
		var building_health := building.get_node("HealthComponent") as HealthComponent
		var building_health_before := building_health.current_health
		builder.global_position += Vector2(240.0, 0.0)
		enemy_sword.call(&"set_navigation_path", PackedVector2Array())
		enemy_sword.global_position = building.global_position + Vector2(20.0, 0.0)
		await get_tree().create_timer(2.45).timeout
		_expect(building_health.current_health < building_health_before, "敌方战斗单位无法攻击建筑并扣除生命")
		var gold_before := int((states[1] as Dictionary).get("gold", 0))
		building.call(&"_process", coin_definition.production_interval_seconds + 0.1)
		_expect(building.pending_amount == coin_definition.production_amount and int((states[1] as Dictionary).get("gold", 0)) == gold_before, "金币生产台没有先把产出累计到待领取库存")
		_expect(building.bubble_area.visible and building.bubble_area.input_pickable and building.bubble_icon.texture != null, "金币生产气泡没有显示资源美术或不可点击")
		_expect(bool(map.call(&"_server_collect_building_output", 1, building.building_id)), "点击气泡对应的服务端收货失败")
		_expect(building.pending_amount == 0 and int((states[1] as Dictionary).get("gold", 0)) == gold_before + coin_definition.production_amount, "金币生产台收货没有一次结清库存")
		var iron_before_upgrade: int = int((states[1] as Dictionary).get("iron", 0))
		_expect(bool(map.call(&"_server_upgrade_building", 1, building.building_id)), "铁无法用于升级建筑")
		_expect(building.building_level == 2 and int((states[1] as Dictionary).get("iron", 0)) < iron_before_upgrade, "建筑升级没有提升等级或扣除铁")
		_expect_upgrade_vfx(building, "生产建筑", UPGRADE_BUILDING_EXPECTED_SCALE)

	# The hero altar offers all heroes, charges 2 summon tokens initially and 1 on replacement.
	builder.global_position = Vector2(73.5 * 32.0, 75.5 * 32.0)
	var altar_definition: BuildingDefinition = BUILDING_CATALOG.get_definition(&"hero_altar")
	var altar_rect: Rect2i = map.call(&"_structure_rect_at", builder.global_position, altar_definition.footprint_tiles) as Rect2i
	_expect(bool(map.call(&"_server_build_structure", 1, int(builder.get("unit_id")), &"hero_altar", altar_rect)), "建筑工人无法建造英雄台")
	var altar_job: Dictionary = (map.get("_pending_structure_job_by_unit_id") as Dictionary).get(int(builder.get("unit_id")), {}) as Dictionary
	builder.global_position = altar_job.get("approach_position", builder.global_position) as Vector2
	builder.call(&"set_navigation_path", PackedVector2Array())
	map.call(&"_process_pending_structure_jobs")
	await get_tree().process_frame
	var altar: ProductionBuilding
	for candidate: ProductionBuilding in (map.get("_network_buildings") as Dictionary).values():
		if candidate.definition.building_id == &"hero_altar":
			altar = candidate
			break
	_expect(is_instance_valid(altar), "英雄台实例缺失")
	if is_instance_valid(altar):
		altar.call(&"_process", altar_definition.construction_seconds + 0.1)
		map.call(&"_on_building_interaction_requested", altar)
		var hero_menu: HeroSummonPanel = map.get("hero_summon_panel") as HeroSummonPanel
		var hero_choices: Array[UnitDefinition] = UNIT_CATALOG.build_hero_choices()
		var hero_card_grid: GridContainer = hero_menu.get("_card_grid") as GridContainer
		_expect(map.get("_card_menu_mode") == &"" and int(map.get("_active_hero_altar_id")) == altar.building_id, "点击已完成英雄台没有进入独立英雄面板模式")
		_expect(hero_menu.visible and hero_choices.size() == 1 and hero_card_grid.get_child_count() == 1 and hero_choices[0].unit_id == &"confucius", "独立英雄面板没有展示孔夫子英雄卡")
		hero_menu.close()
		var tokens_before_summon: int = int((states[1] as Dictionary).get("summon_token", 0))
		_expect(bool(map.call(&"_server_summon_altar_hero", 1, altar.building_id, &"confucius")), "英雄台首次召唤孔夫子失败")
		_expect(int((states[1] as Dictionary).get("summon_token", 0)) == tokens_before_summon - 2, "英雄台首次召唤没有扣除2张召唤符")
		_expect(bool(map.call(&"_server_summon_altar_hero", 1, altar.building_id, &"confucius")), "英雄台替换英雄失败")
		_expect(int((states[1] as Dictionary).get("summon_token", 0)) == tokens_before_summon - 3, "英雄台替换没有再扣除1张召唤符")
		var active_hero_id: int = int((map.get("_hero_unit_by_peer_id") as Dictionary).get(1, 0))
		var active_hero: HeroUnit = (map.get("_network_units") as Dictionary).get(active_hero_id) as HeroUnit
		_expect(is_instance_valid(active_hero), "英雄台没有保持唯一活动英雄")
		if is_instance_valid(active_hero):
			var experience_before_upgrade: int = int((states[1] as Dictionary).get("experience", 0))
			var skill_experience_before_upgrade: int = int((states[1] as Dictionary).get("skill_experience", 0))
			_expect(bool(map.call(&"_server_upgrade_hero", 1, active_hero_id, &"")), "经验无法升级英雄")
			_expect(bool(map.call(&"_server_upgrade_hero", 1, active_hero_id, &"you_jiao_wu_lei")), "技能经验无法升级英雄技能")
			_expect(active_hero.hero_level == 2 and active_hero.get_skill_level(&"you_jiao_wu_lei") == 2, "英雄或技能等级没有提升")
			_expect(int((states[1] as Dictionary).get("experience", 0)) < experience_before_upgrade and int((states[1] as Dictionary).get("skill_experience", 0)) < skill_experience_before_upgrade, "英雄成长没有扣除对应经验")
			_expect_upgrade_vfx(active_hero, "英雄与技能", UPGRADE_UNIT_EXPECTED_SCALE)

			# The passive aura and all three active Confucius skills must apply real authority-side effects.
			var command_panel: UnitCommandPanel = map.get("unit_command_panel") as UnitCommandPanel
			var hero_selection: Array[int] = [active_hero_id]
			map.call(&"_set_selected_units", hero_selection)
			await get_tree().process_frame
			var hero_panel: PanelContainer = command_panel.get("_hero_panel") as PanelContainer
			var standard_panel: PanelContainer = command_panel.get("_panel") as PanelContainer
			var hero_skill_bar: HBoxContainer = command_panel.get("_hero_skill_bar") as HBoxContainer
			var hero_skill_buttons: Dictionary = command_panel.get("_hero_skill_buttons") as Dictionary
			var cooldown_overlays: Dictionary = command_panel.get("_hero_skill_cooldown_overlays") as Dictionary
			_expect(hero_panel.visible and not standard_panel.visible and hero_panel.size.x > hero_panel.size.y * 4.0, "英雄指令面板没有切换为底部横向技能栏")
			_expect(hero_skill_bar.get_child_count() == 4 and hero_skill_buttons.size() == 4, "英雄技能栏没有显示四个技能图标")
			_expect(cooldown_overlays.size() == 3, "Q/W/E技能没有各自创建径向冷却遮罩")
			for skill_id_value: Variant in [&"ren_zhe_ai_ren", &"li_yue_jiao_hua", &"zhou_you_lie_guo"]:
				var skill_id: StringName = StringName(str(skill_id_value))
				var cast_button: Button = hero_skill_buttons.get(skill_id) as Button
				_expect(cast_button != null and cast_button.icon != null, "%s技能按钮缺少图标" % skill_id)
				if cast_button != null:
					cast_button.pressed.emit()
					_expect(active_hero.has_meta(&"pending_hero_skill") and active_hero.get_meta(&"pending_hero_skill") == skill_id, "%s图标点击没有进入技能选取状态" % skill_id)
				map.call(&"_cancel_pending_hero_skill")
			var e_key_event: InputEventKey = InputEventKey.new()
			e_key_event.physical_keycode = KEY_E
			e_key_event.pressed = true
			map.call(&"_unhandled_input", e_key_event)
			_expect(active_hero.has_meta(&"pending_hero_skill") and active_hero.get_meta(&"pending_hero_skill") == &"zhou_you_lie_guo", "键盘E没有进入周游列国选取状态")
			map.call(&"_cancel_pending_hero_skill")
			var hero_health: HealthComponent = active_hero.get_node("HealthComponent") as HealthComponent
			local_sword.global_position = active_hero.global_position + Vector2(32.0, 0.0)
			enemy_sword.global_position = active_hero.global_position + Vector2(64.0, 0.0)
			active_hero.call(&"_process_passive_aura", 1.0)
			var passive_source: StringName = StringName("confucius_passive_%d" % active_hero_id)
			_expect(local_sword.get_combat_buff_remaining(passive_source) > 0.0, "有教无类没有给范围内友军增加攻击")
			_expect(is_equal_approx(local_sword_health.get_temporary_defense_bonus(passive_source), 6.0), "二级有教无类没有给范围内友军增加6点防御")

			local_sword_health.apply_network_state(local_sword_health.max_health * 0.5, local_sword_health.current_mana)
			hero_health.apply_network_state(hero_health.current_health, hero_health.max_mana)
			var health_before_q: float = local_sword_health.current_health
			var q_cast_button: Button = hero_skill_buttons.get(&"ren_zhe_ai_ren") as Button
			q_cast_button.pressed.emit()
			map.call(&"_try_cast_pending_hero_skill", active_hero.global_position + Vector2(1000.0, 0.0))
			_expect(active_hero.has_meta(&"pending_hero_skill"), "仁者爱人选到无效目标后错误退出选取状态")
			map.call(&"_try_cast_pending_hero_skill", local_sword.global_position)
			_expect(not active_hero.has_meta(&"pending_hero_skill"), "仁者爱人有效目标施放后没有退出选取状态")
			_expect(is_equal_approx(local_sword_health.current_health, health_before_q + local_sword_health.max_health * 0.12), "一级仁者爱人没有治疗12%最大生命")
			_expect(is_equal_approx(hero_health.current_mana, hero_health.max_mana - 35.0) and is_equal_approx(active_hero.get_skill_cooldown(&"ren_zhe_ai_ren"), 8.0), "仁者爱人没有正确消耗魔法或进入冷却")
			map.call(&"_update_selected_hero_cooldown_ui")
			var q_cooldown_overlay: Control = cooldown_overlays.get(&"ren_zhe_ai_ren") as Control
			var q_cooldown_mask: ColorRect = q_cooldown_overlay.get_node("Mask") as ColorRect
			var q_cooldown_material: ShaderMaterial = q_cooldown_mask.material as ShaderMaterial
			_expect(q_cooldown_overlay.visible and is_equal_approx(float(q_cooldown_overlay.call(&"get_remaining_ratio")), 1.0), "仁者爱人施放后没有显示完整径向冷却遮罩")
			_expect(q_cooldown_material != null, "仁者爱人冷却遮罩没有使用径向Shader材质")
			active_hero.skill_cooldowns[&"ren_zhe_ai_ren"] = 4.0
			map.call(&"_update_selected_hero_cooldown_ui")
			_expect(is_equal_approx(float(q_cooldown_overlay.call(&"get_remaining_ratio")), 0.5) and is_equal_approx(float(q_cooldown_material.get_shader_parameter(&"remaining_ratio")), 0.5) and (q_cooldown_overlay.get_node("Countdown") as Label).text == "4", "径向冷却遮罩没有随剩余时间收缩或更新秒数")
			active_hero.skill_cooldowns[&"ren_zhe_ai_ren"] = 0.0
			map.call(&"_update_selected_hero_cooldown_ui")
			_expect(not q_cooldown_overlay.visible, "技能冷却结束后径向遮罩没有隐藏")
			var q_vfx_path: String = "ConfuciusQSkillVfx_%d" % active_hero_id
			var q_skill_vfx: AnimatedSprite2D = local_sword.get_node_or_null(q_vfx_path) as AnimatedSprite2D
			_expect(is_instance_valid(q_skill_vfx) and q_skill_vfx.get_parent() == local_sword and q_skill_vfx.is_playing(), "仁者爱人治疗特效没有挂到实际受术队友")
			_expect(map.call(&"_resolve_skill_visual_target", &"unit", int(local_sword.get("unit_id"))) == local_sword, "多人技能特效目标ID没有解析回实际队友")
			local_sword.global_position += Vector2(8.0, 0.0)
			_expect(q_skill_vfx.global_position.is_equal_approx(local_sword.global_position), "仁者爱人特效没有跟随受术队友移动")
			_expect(not active_hero.has_node("QSkillVfx"), "孔夫子场景仍保留固定Q技能特效子节点")

			hero_health.apply_network_state(hero_health.current_health, hero_health.max_mana)
			var ritual_target: Vector2 = active_hero.global_position + Vector2(48.0, 0.0)
			local_sword.global_position = ritual_target + Vector2(12.0, 0.0)
			enemy_sword.global_position = ritual_target + Vector2(24.0, 0.0)
			_expect(bool(map.call(&"_server_cast_hero_skill", 1, active_hero_id, &"li_yue_jiao_hua", ritual_target)), "礼乐教化施放失败")
			var ritual_source: StringName = StringName("confucius_w_%d" % active_hero_id)
			_expect(enemy_sword.get_control_remaining() >= 1.19, "一级礼乐教化没有眩晕范围内敌人1.2秒")
			_expect(is_equal_approx(local_sword_health.get_temporary_defense_bonus(ritual_source), 6.0), "一级礼乐教化没有给范围内友军增加6点防御")
			_expect(is_equal_approx(hero_health.current_mana, hero_health.max_mana - 55.0) and is_equal_approx(active_hero.get_skill_cooldown(&"li_yue_jiao_hua"), 14.0), "礼乐教化没有正确消耗魔法或进入冷却")
			var w_vfx_path: String = "ConfuciusWSkillVfx_%d" % active_hero_id
			var w_skill_vfx: AnimatedSprite2D = local_sword.get_node_or_null(w_vfx_path) as AnimatedSprite2D
			_expect(is_instance_valid(w_skill_vfx) and w_skill_vfx.get_parent() == local_sword and w_skill_vfx.is_playing(), "礼乐教化特效没有挂到获得防御的队友")
			_expect(not active_hero.has_node("WSkillVfx"), "孔夫子场景仍保留固定W技能特效子节点")

			hero_health.apply_network_state(hero_health.current_health, hero_health.max_mana)
			enemy_sword.global_position = Vector2(9000.0, 9000.0)
			var travel_target: Vector2 = Vector2.INF
			for offset: Vector2 in [Vector2(64.0, 0.0), Vector2(0.0, 64.0), Vector2(-64.0, 0.0), Vector2(0.0, -64.0)]:
				var candidate_path: PackedVector2Array = world_pathfinder.find_path(active_hero.global_position, active_hero.global_position + offset)
				if not candidate_path.is_empty():
					travel_target = candidate_path[candidate_path.size() - 1]
					break
			_expect(travel_target != Vector2.INF, "没有找到可测试周游列国的邻近可达位置")
			if travel_target != Vector2.INF:
				_expect(bool(map.call(&"_server_cast_hero_skill", 1, active_hero_id, &"zhou_you_lie_guo", travel_target)), "周游列国施放失败")
				_expect(is_equal_approx(active_hero.get_movement_multiplier(), 2.0), "周游列国赶路阶段不是2倍速度")
				var e_travel_vfx_path: String = "ConfuciusETravelVfx_%d" % active_hero_id
				var e_travel_vfx: AnimatedSprite2D = active_hero.get_node_or_null(e_travel_vfx_path) as AnimatedSprite2D
				_expect(is_instance_valid(e_travel_vfx) and e_travel_vfx.get_parent() == active_hero and e_travel_vfx.is_playing(), "周游列国赶路阶段没有跟随正在移动的孔夫子")
				var travel_destination: Vector2 = active_hero.get("_travel_destination") as Vector2
				local_sword.global_position = travel_destination + Vector2(16.0, 0.0)
				active_hero.global_position = travel_destination
				active_hero.call(&"_physics_process", 0.01)
				active_hero.call(&"_physics_process", 0.01)
				var inspiration_source: StringName = StringName("confucius_e_%d" % active_hero_id)
				_expect(local_sword.get_combat_buff_remaining(inspiration_source) > 5.9, "周游列国抵达后没有给附近友军施加6秒鼓舞")
				_expect(local_sword.get_attack_multiplier() >= 1.21 and local_sword.get_movement_multiplier() >= 1.15, "一级周游列国没有提升15%攻击与移动速度")
				_expect(absf(hero_health.current_mana - (hero_health.max_mana - 45.0)) <= 0.2 and active_hero.get_skill_cooldown(&"zhou_you_lie_guo") > 11.9, "周游列国没有正确消耗魔法或进入冷却")
				var e_arrival_vfx_path: String = "ConfuciusEArrivalVfx_%d" % active_hero_id
				var e_arrival_vfx: AnimatedSprite2D = local_sword.get_node_or_null(e_arrival_vfx_path) as AnimatedSprite2D
				_expect(is_instance_valid(e_arrival_vfx) and e_arrival_vfx.get_parent() == local_sword and e_arrival_vfx.is_playing(), "周游列国抵达鼓舞特效没有挂到获得增益的队友")
				_expect_vfx_frames(local_sword, e_arrival_vfx_path, 8, "孔夫子E抵达技能")
			_expect_vfx_frames(local_sword, q_vfx_path, 8, "孔夫子Q技能")
			_expect_vfx_frames(local_sword, w_vfx_path, 8, "孔夫子W技能")
			_expect(not active_hero.has_node("ESkillVfx"), "孔夫子场景仍保留固定E技能特效子节点")
			await get_tree().create_timer(0.9).timeout
			_expect(not is_instance_valid(q_skill_vfx) and not is_instance_valid(w_skill_vfx), "挂在受术队友上的孔夫子技能序列播放结束后没有自动释放")

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

	_expect(BUILDING_CATALOG.definitions.size() == 5, "建筑目录应包含金币台、三类资源建筑和英雄台")
	var building_texture_paths: Dictionary = {}
	for building_definition: BuildingDefinition in BUILDING_CATALOG.definitions:
		building_texture_paths[building_definition.texture.resource_path] = true
	_expect(building_texture_paths.size() == 5, "五类建筑没有使用五张独立美术资源")
	_expect_asset("res://art/ui/cards/card_builder_art.png", Vector2i(1254, 1254))
	_expect_asset("res://art/ui/cards/card_explorer_art.png", Vector2i(1254, 1254))
	_expect_asset("res://art/ui/cards/card_lumber_machine_art.png", Vector2i(1254, 1254))
	_expect_asset("res://art/ui/cards/card_quarry_machine_art.png", Vector2i(1254, 1254))
	_expect_asset("res://art/ui/cards/card_swordsman_art.png", Vector2i(1254, 1254))
	_expect_asset("res://art/ui/cards/card_treant_art.png", Vector2i(1254, 1254))
	_expect_asset("res://art/ui/resource_icons/resource_gold.png", Vector2i(1254, 1254))
	_expect_asset("res://art/ui/resource_icons/resource_wood.png", Vector2i(1254, 1254))
	_expect_asset("res://art/ui/resource_icons/resource_stone.png", Vector2i(1254, 1254))
	_expect_asset("res://art/ui/resource_icons/resource_iron.png", Vector2i(1448, 1086))
	_expect_asset("res://art/units/confucius_card.png", Vector2i(1024, 1536))
	_expect_asset("res://art/ui/skills/confucius_passive_education_icon.png", Vector2i(1254, 1254))
	_expect_asset("res://art/ui/skills/confucius_q_benevolence_icon.png", Vector2i(1254, 1254))
	_expect_asset("res://art/ui/skills/confucius_w_ritual_icon.png", Vector2i(1254, 1254))
	_expect_asset("res://art/ui/skills/confucius_e_travel_icon.png", Vector2i(1254, 1254))
	_expect_asset("res://art/structures/structure_coin_table_imagegen_2x2.png", Vector2i(64, 64), true)
	_expect_asset("res://art/structures/structure_lumber_camp_imagegen_2x2.png", Vector2i(64, 64), true)
	_expect_asset("res://art/structures/structure_quarry_yard_imagegen_2x2.png", Vector2i(64, 64), true)
	_expect_asset("res://art/structures/structure_iron_mine_imagegen_2x2.png", Vector2i(64, 64), true)
	_expect_asset("res://art/structures/structure_hero_altar_imagegen_2x2.png", Vector2i(64, 64), true)
	_expect_asset("res://art/structures/structure_under_construction_imagegen_2x2.png", Vector2i(64, 64), true)
	_expect_asset("res://art/resources/resource_treasure_chest_imagegen_1x1.png", Vector2i(32, 32), true)
	_expect_asset("res://art/units/unit_wild_beetle_imagegen_2x2.png", Vector2i(64, 64), true)
	_expect_asset("res://art/vfx/swordsman_attack_white_slash_8f.png", Vector2i(256, 128))
	_expect_asset("res://art/vfx/swordsman_skill_gold_slash_8f.png", Vector2i(896, 448))
	_expect_asset("res://art/vfx/treant_attack_vine_8f.png", Vector2i(256, 128))
	_expect_asset("res://art/vfx/treant_skill_green_particles_r104_8f.png", Vector2i(832, 416), true)
	_expect_asset("res://art/vfx/treant_skill_green_particles_r112_8f.png", Vector2i(896, 448), true)
	_expect_asset("res://art/vfx/treant_skill_green_particles_r120_8f.png", Vector2i(960, 480), true)
	_expect_asset("res://art/vfx/treant_skill_green_particles_r128_8f.png", Vector2i(1024, 512), true)
	_expect_asset("res://art/vfx/confucius_q_benevolence_heal_8f.png", Vector2i(1776, 888))
	_expect_asset("res://art/vfx/confucius_w_ritual_field_8f.png", Vector2i(1776, 888))
	_expect_asset("res://art/vfx/confucius_e_travel_inspiration_8f.png", Vector2i(1776, 888))
	_expect_asset("res://art/vfx/elite_spider_venom_bolt.png", Vector2i(1774, 887))
	_expect_asset("res://art/vfx/elite_spider_web_field.png", Vector2i(1254, 1254))
	_finish(map)

func _find_unit(units: Dictionary, owner_peer_id: int, definition_id: StringName) -> Node2D:
	for unit: Node2D in units.values():
		var definition := unit.get("definition") as UnitDefinition
		if int(unit.get("owner_peer_id")) == owner_peer_id and definition != null and definition.unit_id == definition_id:
			return unit
	return null

func _find_units(units: Dictionary, owner_peer_id: int, definition_id: StringName) -> Array[Node2D]:
	var matches: Array[Node2D] = []
	for unit: Node2D in units.values():
		var definition: UnitDefinition = unit.get("definition") as UnitDefinition
		if int(unit.get("owner_peer_id")) == owner_peer_id and definition != null and definition.unit_id == definition_id:
			matches.append(unit)
	return matches

func _return_health_targets(targets: Array[HealthComponent]) -> Array[HealthComponent]:
	return targets

func _find_external_resource_detour(pathfinder: WorldPathfinder, obstacle_cells: Array[Vector2i], tile_size: int) -> Dictionary:
	var axes: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN]
	var inspected: int = 0
	for obstacle_cell: Vector2i in obstacle_cells:
		inspected += 1
		if inspected > 512:
			break
		for axis: Vector2i in axes:
			var start_position: Vector2 = _cell_center(obstacle_cell - axis * 4, tile_size)
			var target_position: Vector2 = _cell_center(obstacle_cell + axis * 4, tile_size)
			if not pathfinder.is_world_position_walkable(start_position) or not pathfinder.is_world_position_walkable(target_position):
				continue
			var path: PackedVector2Array = pathfinder.find_path(start_position, target_position)
			if path.size() > 1:
				return {"cell": obstacle_cell, "path": path}
	return {}

func _cell_center(cell: Vector2i, tile_size: int) -> Vector2:
	return Vector2(cell * tile_size) + Vector2.ONE * float(tile_size) * 0.5

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

func _expect_upgrade_vfx(target_root: Node, label: String, expected_scale: float) -> void:
	if not is_instance_valid(target_root):
		_expect(false, "%s实例缺失，无法验证升级特效" % label)
		return
	var matched_vfx: Node2D
	for child: Node in target_root.get_children():
		if child is Node2D and child.get_script() == UPGRADE_VFX_SCRIPT:
			matched_vfx = child as Node2D
			break
	_expect(is_instance_valid(matched_vfx), "%s升级成功后没有触发共享升级特效" % label)
	if not is_instance_valid(matched_vfx):
		return
	var surface: ColorRect = matched_vfx.get_node_or_null("UpgradeSurface") as ColorRect
	var surface_material: ShaderMaterial = surface.material as ShaderMaterial if surface != null else null
	_expect(surface_material != null and surface_material.shader != null, "%s升级特效没有使用CanvasItem Shader" % label)
	_expect(matched_vfx.get_node_or_null("UpgradeSparkles") is CPUParticles2D, "%s升级特效缺少上升粒子" % label)
	_expect(matched_vfx.scale.is_equal_approx(Vector2.ONE * expected_scale), "%s升级特效没有使用收紧后的目标尺寸" % label)

func _expect_vfx_frames(root_node: Node, node_path: String, expected_count: int, label: String) -> void:
	var vfx := root_node.get_node_or_null(node_path) as AnimatedSprite2D
	_expect(is_instance_valid(vfx), "%s缺少AnimatedSprite2D节点" % label)
	if not is_instance_valid(vfx):
		return
	_expect(vfx.sprite_frames != null, "%s缺少SpriteFrames资源" % label)
	if vfx.sprite_frames != null:
		_expect(vfx.sprite_frames.get_frame_count(&"default") == expected_count, "%s不是%d帧序列" % [label, expected_count])
		_expect(not vfx.sprite_frames.get_animation_loop(&"default"), "%s序列不应循环播放" % label)

func _expect_treant_skill_frame_size(definition_id: StringName, expected_size: int) -> void:
	var unit_definition: UnitDefinition = UNIT_CATALOG.get_definition(definition_id)
	_expect(unit_definition != null and unit_definition.scene != null, "%s缺少单位场景" % definition_id)
	if unit_definition == null or unit_definition.scene == null:
		return
	var unit := unit_definition.scene.instantiate() as TreantUnit
	add_child(unit)
	unit.configure_network(0, 1, 1, unit_definition, false)
	var vfx := unit.get_node_or_null("SkillVfx") as AnimatedSprite2D
	_expect(is_instance_valid(vfx) and vfx.sprite_frames != null, "%s缺少技能序列帧" % definition_id)
	if is_instance_valid(vfx) and vfx.sprite_frames != null:
		var frame_texture: Texture2D = vfx.sprite_frames.get_frame_texture(&"default", 0)
		_expect(frame_texture != null and Vector2i(frame_texture.get_size()) == Vector2i(expected_size, expected_size), "%s技能帧尺寸不是%dx%d" % [definition_id, expected_size, expected_size])
	unit.queue_free()

func _expect_asset(path: String, expected_size: Vector2i, require_binary_alpha: bool = false) -> void:
	var image := Image.new()
	var load_error := image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
	_expect(load_error == OK, "%s无法加载：%s" % [path, error_string(load_error)])
	_expect(not image.is_empty(), "%s无法加载" % path)
	if image.is_empty():
		return
	_expect(image.get_size() == expected_size, "%s尺寸不是%s" % [path, expected_size])
	var has_transparent_pixel: bool = false
	var has_partial_alpha: bool = false
	for y: int in image.get_height():
		for x: int in image.get_width():
			var alpha: float = image.get_pixel(x, y).a
			if alpha < 0.999:
				has_transparent_pixel = true
			if alpha > 0.001 and alpha < 0.999:
				has_partial_alpha = true
	_expect(has_transparent_pixel, "%s缺少透明背景" % path)
	if require_binary_alpha:
		_expect(not has_partial_alpha, "%s包含半透明脏边" % path)

func _finish(map: Node) -> void:
	map.queue_free()
	if _failures.is_empty():
		print("GAMEPLAY_REGRESSION_OK")
		await get_tree().create_timer(1.5).timeout
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("GAMEPLAY_REGRESSION: %s" % failure)
	await get_tree().create_timer(1.5).timeout
	get_tree().quit(1)

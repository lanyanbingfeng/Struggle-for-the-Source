extends Node

const WORLD_BOSS_SCENE: PackedScene = preload("res://game/world/world_boss.tscn")
const WILD_MONSTER_SCENE: PackedScene = preload("res://game/world/wild_monster.tscn")
const TEST_TARGET_SCRIPT: Script = preload("res://tests/world_boss_test_target.gd")
const TILE_SIZE: int = 32

var _failures: PackedStringArray = []

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred(&"_run")

func _run() -> void:
	var main_scene: PackedScene = load("res://game/main/main.tscn") as PackedScene
	var map: Node2D = main_scene.instantiate() as Node2D
	get_tree().root.add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame
	map.call(&"_on_start_requested", false, SimpleAIController.Difficulty.NORMAL)
	await get_tree().process_frame
	(map.get("ai_controller") as SimpleAIController).configure(false)

	var boss_container: Node2D = map.get("world_boss_container") as Node2D
	var boss: WorldBoss = map.get("_world_boss") as WorldBoss
	_expect(boss_container.get_child_count() == 1 and is_instance_valid(boss), "单局没有保持唯一世界BOSS")
	if not is_instance_valid(boss):
		_finish(map)
		return
	var boss_health: HealthComponent = boss.get_node_or_null("HealthComponent") as HealthComponent
	var footprint: Rect2i = boss.get_meta(&"cell_rect", Rect2i()) as Rect2i
	_expect(footprint.size == Vector2i(3, 3) and boss.get_footprint_rect(TILE_SIZE) == footprint, "BOSS逻辑占地不是3×3")
	_expect(is_instance_valid(boss_health) and not boss.has_node("HealthBar"), "BOSS没有独立生命组件或错误叠加普通世界生命条")
	_expect(is_equal_approx(boss_health.max_health, 5200.0) and is_equal_approx(boss_health.defense, 26.0), "普通难度BOSS基础生命或防御错误")
	_expect(is_equal_approx(boss.get_movement_speed(), 68.0) and is_equal_approx(boss.get_attack_damage(), 62.0) and is_equal_approx(boss.get_attack_interval(), 2.0), "普通难度BOSS基础战斗属性错误")
	_expect(WorldBoss.AGGRO_RANGE_TILES == 12.0 and WorldBoss.CHASE_RANGE_TILES == 18.0 and WorldBoss.ATTACK_RANGE_TILES == 2.25, "BOSS索敌、追击或攻击距离错误")
	_expect(WorldBoss.COMBAT_RADIUS == 52.0, "BOSS战斗半径错误")

	var seed: int = int(map.get("_resource_seed"))
	var deterministic_a: Rect2i = map.call(&"_build_world_boss_spawn_rect", seed) as Rect2i
	var deterministic_b: Rect2i = map.call(&"_build_world_boss_spawn_rect", seed) as Rect2i
	var changed_seed: Rect2i = map.call(&"_build_world_boss_spawn_rect", seed ^ 0x13579BDF) as Rect2i
	_expect(deterministic_a == deterministic_b and deterministic_a == footprint, "BOSS巢穴没有按地图种子稳定复现")
	_expect(changed_seed != deterministic_a, "不同地图种子没有改变BOSS巢穴")
	_validate_spawn_clearance(map, footprint)
	_test_footprint_pathfinding()
	_test_difficulty_multipliers()
	_test_boss_combat_state_machine()
	_test_lan_contract(map)
	_test_hud_and_visibility(map, boss, boss_health)
	var developer_spawn_result: Dictionary = _test_developer_enemy_spawning(map, boss)
	boss = developer_spawn_result.get("boss", boss) as WorldBoss
	boss_health = developer_spawn_result.get("health", boss_health) as HealthComponent
	_test_last_hit_reward(map, boss, boss_health)
	_validate_assets()
	_finish(map)

func _validate_spawn_clearance(map: Node2D, boss_rect: Rect2i) -> void:
	var territory_rects: Array[Rect2i] = map.get("_territory_rects") as Array[Rect2i]
	var cluster: Rect2i = territory_rects[0]
	for territory: Rect2i in territory_rects:
		var minimum := Vector2i(mini(cluster.position.x, territory.position.x), mini(cluster.position.y, territory.position.y))
		var maximum := Vector2i(maxi(cluster.end.x, territory.end.x), maxi(cluster.end.y, territory.end.y))
		cluster = Rect2i(minimum, maximum - minimum)
	_expect(not cluster.grow(24).intersects(boss_rect) and cluster.grow(52).intersects(boss_rect), "BOSS巢穴不在初始领地群外24～52格环带")
	var blocked: Dictionary[Vector2i, bool] = {}
	var streamer: WorldResourceStreamer = map.get("world_resource_streamer") as WorldResourceStreamer
	for cell: Vector2i in streamer.get_navigation_obstacle_cells():
		blocked[cell] = true
	for y: int in range(boss_rect.grow(2).position.y, boss_rect.grow(2).end.y):
		for x: int in range(boss_rect.grow(2).position.x, boss_rect.grow(2).end.x):
			_expect(not blocked.has(Vector2i(x, y)), "BOSS巢穴没有避开资源至少2格")
	var monsters: Dictionary = map.get("_wild_monsters") as Dictionary
	for monster: WildMonster in monsters.values():
		var elite_rect: Rect2i = monster.get_meta(&"cell_rect", Rect2i()) as Rect2i
		_expect(not elite_rect.grow(14).intersects(boss_rect), "BOSS巢穴距离精英蜘蛛不足14格")

func _test_footprint_pathfinding() -> void:
	var pathfinder := WorldPathfinder.new()
	add_child(pathfinder)
	pathfinder.configure(Vector2i(12, 12), TILE_SIZE)
	var wall: Array[Vector2i] = []
	for y: int in range(12):
		if y != 6:
			wall.append(Vector2i(6, y))
	pathfinder.set_external_obstacles(wall)
	var start: Vector2 = _cell_center(Vector2i(2, 6))
	var target: Vector2 = _cell_center(Vector2i(9, 6))
	_expect(not pathfinder.find_path(start, target).is_empty(), "单格单位无法通过单格缺口")
	_expect(pathfinder.find_path_for_footprint(start, target, Vector2i(3, 3)).is_empty(), "3×3寻路错误穿过单格缺口")
	pathfinder.queue_free()

func _test_difficulty_multipliers() -> void:
	var expected_health: Array[float] = [0.80, 1.00, 1.20, 1.40]
	var expected_damage: Array[float] = [0.85, 1.00, 1.10, 1.20]
	var expected_interval: Array[float] = [1.15, 1.00, 0.90, 0.82]
	for difficulty: int in range(WildEnemyDifficulty.Level.EASY, WildEnemyDifficulty.Level.HELL + 1):
		var boss: WorldBoss = WORLD_BOSS_SCENE.instantiate() as WorldBoss
		add_child(boss)
		boss.configure(100 + difficulty, false, difficulty)
		_expect(is_equal_approx(boss.get_max_health(), WorldBoss.MAX_HEALTH * expected_health[difficulty]), "%sBOSS生命倍率错误" % WildEnemyDifficulty.get_display_name(difficulty))
		_expect(is_equal_approx(boss.get_attack_damage(), WorldBoss.ATTACK_DAMAGE * expected_damage[difficulty]), "%sBOSS伤害倍率错误" % WildEnemyDifficulty.get_display_name(difficulty))
		_expect(is_equal_approx(boss.get_attack_interval(), WorldBoss.ATTACK_INTERVAL * expected_interval[difficulty]), "%sBOSS节奏倍率错误" % WildEnemyDifficulty.get_display_name(difficulty))
		var elite: WildMonster = WILD_MONSTER_SCENE.instantiate() as WildMonster
		add_child(elite)
		elite.configure(200 + difficulty, false, difficulty)
		_expect(is_equal_approx(elite.get_max_health(), WildMonster.MAX_HEALTH * expected_health[difficulty]), "%s精英生命倍率错误" % WildEnemyDifficulty.get_display_name(difficulty))
		_expect(is_equal_approx(elite.get_attack_damage(), WildMonster.ATTACK_DAMAGE * expected_damage[difficulty]), "%s精英伤害倍率错误" % WildEnemyDifficulty.get_display_name(difficulty))
		_expect(is_equal_approx(elite.get_attack_interval(), WildMonster.ATTACK_INTERVAL * expected_interval[difficulty]), "%s精英节奏倍率错误" % WildEnemyDifficulty.get_display_name(difficulty))
		boss.queue_free()
		elite.queue_free()

func _test_boss_combat_state_machine() -> void:
	var boss: WorldBoss = WORLD_BOSS_SCENE.instantiate() as WorldBoss
	add_child(boss)
	boss.global_position = Vector2(640.0, 640.0)
	boss.configure(999, true, WildEnemyDifficulty.Level.NORMAL)
	boss.set_physics_process(false)
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	boss.add_child(health)
	health.configure(boss, 0, boss.get_max_health(), WorldBoss.DEFENSE)
	health.combat_radius = WorldBoss.COMBAT_RADIUS
	var targets: Array[HealthComponent] = []
	boss.setup_combat_context(_return_targets.bind(targets), Callable(), TILE_SIZE)
	health.apply_attack(1000.0)
	var damaged_health: float = health.current_health
	boss.call(&"_physics_process", 4.9)
	_expect(is_equal_approx(health.current_health, damaged_health), "BOSS回巢未等待5秒就开始回血")
	boss.call(&"_physics_process", 0.2)
	_expect(health.current_health > damaged_health and is_equal_approx(health.current_health - damaged_health, health.max_health * 0.02 * 0.2), "BOSS没有按每秒2%最大生命回血")
	health.apply_network_state(health.max_health * 0.49, 0.0)
	boss.refresh_phase_from_health()
	_expect(boss.get_phase() == 2 and is_equal_approx(boss.get_movement_speed(), 68.0 * 1.12) and is_equal_approx(boss.get_attack_interval(), 2.0 * 0.82), "BOSS半血没有进入二阶段或应用速度/节奏倍率")
	_expect(is_equal_approx(boss.get_skill_cooldown(WorldBoss.SKILL_MOUNTAIN_BREAK), 9.0 * 0.82) and is_equal_approx(boss.get_skill_cooldown(WorldBoss.SKILL_HEAVENFIRE), 16.0 * 0.82), "BOSS二阶段没有让三个技能冷却乘以0.82")
	health.apply_network_state(health.max_health * 0.60, 0.0)
	boss.refresh_phase_from_health()
	_expect(boss.get_phase() == 1, "BOSS回血超过50%后没有退出二阶段")

	var target_root: Node2D = TEST_TARGET_SCRIPT.new() as Node2D
	add_child(target_root)
	var target_health := HealthComponent.new()
	target_health.name = "HealthComponent"
	target_root.add_child(target_health)
	target_health.configure(target_root, 1, 1000.0, 10.0)
	target_health.combat_radius = 0.0
	targets.append(target_health)
	boss.setup_combat_context(_return_targets.bind(targets), Callable(), TILE_SIZE)
	boss.global_position = Vector2(640.0, 640.0)
	target_root.global_position = boss.global_position + Vector2(32.0, 0.0)
	var before: float = target_health.current_health
	boss.call(&"_resolve_skill", WorldBoss.SKILL_MOUNTAIN_BREAK, PackedVector2Array([boss.global_position]))
	_expect(is_equal_approx(before - target_health.current_health, 78.0 - 10.0) and is_equal_approx(float(target_root.call(&"get_control_remaining")), 1.0), "镇岳崩伤害或1秒控制错误")
	target_health.apply_network_state(1000.0, 0.0)
	target_root.set("control_remaining", 0.0)
	var charge_start: Vector2 = boss.global_position
	var charge_end: Vector2 = charge_start + Vector2(7.0 * TILE_SIZE, 0.0)
	target_root.global_position = charge_start + Vector2(110.0, 30.0)
	boss.call(&"_resolve_skill", WorldBoss.SKILL_INFERNAL_CHARGE, PackedVector2Array([charge_start, charge_end]))
	_expect(is_equal_approx(1000.0 - target_health.current_health, 92.0 - 10.0) and is_equal_approx(float(target_root.call(&"get_control_remaining")), 0.65), "赤狱冲阵路径伤害、单次命中或控制错误")
	_expect(boss.get_home_position().distance_to(boss.global_position) <= WorldBoss.CHASE_RANGE_TILES * TILE_SIZE + 0.1, "赤狱冲阵终点越过18格追击边界")
	target_health.apply_network_state(1000.0, 0.0)
	target_root.global_position = boss.global_position + Vector2(20.0, 0.0)
	var meteor_centers := PackedVector2Array([target_root.global_position, target_root.global_position + Vector2(10.0, 0.0), target_root.global_position - Vector2(10.0, 0.0)])
	boss.call(&"_resolve_skill", WorldBoss.SKILL_HEAVENFIRE, meteor_centers)
	_expect(is_equal_approx(1000.0 - target_health.current_health, 110.0 - 10.0), "天火灭阵重叠落点让同一目标重复受伤")
	_expect(is_equal_approx(boss.get_skill_cooldown(WorldBoss.SKILL_MOUNTAIN_BREAK), 9.0) and is_equal_approx(boss.get_skill_cooldown(WorldBoss.SKILL_INFERNAL_CHARGE), 13.0) and is_equal_approx(boss.get_skill_cooldown(WorldBoss.SKILL_HEAVENFIRE), 16.0), "三技能独立冷却错误")
	boss.play_skill_visual(WorldBoss.SKILL_MOUNTAIN_BREAK, PackedVector2Array([boss.global_position]))
	var boss_sprite: Sprite2D = boss.get_node("Sprite") as Sprite2D
	var mountain_impact: Sprite2D
	var mountain_ring: Line2D = boss.get_node_or_null("BossSkillWarningRing") as Line2D
	for child: Node in boss.get_children():
		if child is Sprite2D and (child as Sprite2D).texture == WorldBoss.MOUNTAIN_BREAK_TEXTURE:
			mountain_impact = child as Sprite2D
			break
	_expect(is_instance_valid(mountain_impact) and mountain_impact.z_index < boss_sprite.z_index, "镇岳崩冲击特效仍然覆盖BOSS本体")
	_expect(is_instance_valid(mountain_ring) and mountain_ring.z_index < boss_sprite.z_index, "镇岳崩预警圈仍然覆盖BOSS本体")
	target_root.queue_free()
	boss.queue_free()

func _test_lan_contract(map: Node2D) -> void:
	_expect(LanSession.PROTOCOL_VERSION == 3, "新增多人存档恢复握手后联机协议版本没有递增")
	var session := LanSession.new()
	add_child(session)
	session.set("_settings", {
		"room_name": "测试房间",
		"team_count": 2,
		"players_per_team": 2,
		"resource_abundance": LanSession.ResourceAbundance.STANDARD,
		"wild_enemy_difficulty": WildEnemyDifficulty.Level.HELL,
	})
	var room_info: Dictionary = session.call(&"_build_discovery_room_info") as Dictionary
	_expect(int(room_info.get("wild_enemy_difficulty", -1)) == WildEnemyDifficulty.Level.HELL, "房间发现广播没有携带野怪难度")
	var map_source: String = FileAccess.get_file_as_string("res://game/main/map_demo.gd")
	var reliable_skill_signature: String = "@rpc(\"authority\", \"call_remote\", \"reliable\")\nfunc _rpc_play_boss_skill_visual"
	var reliable_attack_signature: String = "@rpc(\"authority\", \"call_remote\", \"reliable\")\nfunc _rpc_play_boss_attack_visual"
	var reliable_developer_spawn_signature: String = "@rpc(\"authority\", \"call_remote\", \"reliable\")\nfunc _rpc_apply_developer_enemy_spawn"
	_expect(map_source.contains(reliable_skill_signature) and map_source.contains(reliable_attack_signature), "BOSS技能或普攻表现RPC不是可靠传输")
	_expect(map_source.contains(reliable_developer_spawn_signature), "开发者生成敌人没有使用房主可靠RPC同步")
	session.queue_free()

func _test_developer_enemy_spawning(map: Node2D, original_boss: WorldBoss) -> Dictionary:
	var panel: DeveloperPanel = map.get("developer_panel") as DeveloperPanel
	var boss_button: Button = panel.find_child("SpawnBossButton", true, false) as Button
	var elite_button: Button = panel.find_child("SpawnEliteButton", true, false) as Button
	_expect(is_instance_valid(boss_button) and boss_button.text == "生成 BOSS", "开发者面板缺少生成BOSS按钮")
	_expect(is_instance_valid(elite_button) and elite_button.text == "生成精英", "开发者面板缺少生成精英按钮")
	if not is_instance_valid(boss_button) or not is_instance_valid(elite_button):
		return {"boss": original_boss, "health": original_boss.get_node_or_null("HealthComponent")}
	var original_rect: Rect2i = original_boss.get_meta(&"cell_rect", Rect2i()) as Rect2i
	var boss_excluded: Array[Rect2i] = [original_rect]
	var boss_rect: Rect2i = _find_clear_developer_spawn_rect(map, Vector2i(3, 3), original_rect.position, boss_excluded)
	_expect(boss_rect.size == Vector2i(3, 3), "未找到用于开发者BOSS生成测试的合法位置")
	boss_button.pressed.emit()
	_expect((map.get("_developer_spawn_kind") as StringName) == &"boss", "生成BOSS按钮没有进入地图选点模式")
	var overlay: WorldCommandOverlay = map.get("command_overlay") as WorldCommandOverlay
	_expect(bool(overlay.get("_enemy_spawn_preview_visible")), "开发者选点模式没有显示占地预览")
	map.call(&"_confirm_developer_enemy_spawn", map.call(&"_rect_world_center", boss_rect) as Vector2)
	var replacement_boss: WorldBoss = map.get("_world_boss") as WorldBoss
	var boss_container: Node2D = map.get("world_boss_container") as Node2D
	_expect(not is_instance_valid(original_boss) and is_instance_valid(replacement_boss), "开发者生成BOSS没有替换原有唯一实例")
	_expect(boss_container.get_child_count() == 1 and (replacement_boss.get_meta(&"cell_rect", Rect2i()) as Rect2i) == boss_rect, "开发者BOSS没有生成在选中的3×3位置")
	_expect((map.get("_developer_spawn_kind") as StringName).is_empty() and not bool(overlay.get("_enemy_spawn_preview_visible")), "生成完成后没有退出选点模式")
	var replacement_health: HealthComponent = replacement_boss.get_node_or_null("HealthComponent") as HealthComponent
	_expect(is_instance_valid(replacement_health) and is_equal_approx(replacement_health.current_health, replacement_health.max_health), "开发者生成的BOSS不是满生命")
	var monsters_before: int = (map.get("_wild_monsters") as Dictionary).size()
	var elite_excluded: Array[Rect2i] = [boss_rect]
	var elite_rect: Rect2i = _find_clear_developer_spawn_rect(map, Vector2i(2, 2), boss_rect.position, elite_excluded)
	elite_button.pressed.emit()
	_expect((map.get("_developer_spawn_kind") as StringName) == &"elite", "生成精英按钮没有进入地图选点模式")
	map.call(&"_confirm_developer_enemy_spawn", map.call(&"_rect_world_center", elite_rect) as Vector2)
	var monsters: Dictionary = map.get("_wild_monsters") as Dictionary
	_expect(monsters.size() == monsters_before + 1, "开发者生成精英没有追加新实例")
	var spawned_elite: WildMonster = monsters.get(int(map.get("_next_monster_id")) - 1) as WildMonster
	_expect(is_instance_valid(spawned_elite) and (spawned_elite.get_meta(&"cell_rect", Rect2i()) as Rect2i) == elite_rect, "开发者精英没有生成在选中的2×2位置")
	return {"boss": replacement_boss, "health": replacement_health}

func _find_clear_developer_spawn_rect(map: Node2D, footprint: Vector2i, origin: Vector2i, excluded: Array[Rect2i]) -> Rect2i:
	for radius: int in range(2, 80):
		for offset: Vector2i in [Vector2i(radius, 0), Vector2i(-radius, 0), Vector2i(0, radius), Vector2i(0, -radius), Vector2i(radius, radius), Vector2i(-radius, radius), Vector2i(radius, -radius), Vector2i(-radius, -radius)]:
			var candidate := Rect2i(origin + offset, footprint)
			var overlaps_excluded: bool = false
			for excluded_rect: Rect2i in excluded:
				if excluded_rect.intersects(candidate):
					overlaps_excluded = true
					break
			if overlaps_excluded:
				continue
			if (map.call(&"_developer_enemy_spawn_failure", candidate) as String).is_empty():
				return candidate
	return Rect2i()

func _test_hud_and_visibility(map: Node2D, boss: WorldBoss, health: HealthComponent) -> void:
	var hud: BossHealthHud = map.get("boss_health_hud") as BossHealthHud
	map.set("_full_vision", false)
	map.call(&"_refresh_fog")
	_expect(not hud.visible, "BOSS完全离开本地视野后顶部血条没有隐藏")
	var fog: FogOfWar = map.get("fog_of_war") as FogOfWar
	var boss_rect: Rect2i = boss.get_footprint_rect(TILE_SIZE)
	fog.set_owned_territories([Rect2i(boss_rect.position, Vector2i.ONE)])
	fog.update_visibility([], false)
	map.call(&"_refresh_entity_visibility")
	_expect(boss.visible and hud.visible, "BOSS 3×3占地任意一格可见时没有显示模型和HUD")
	var health_label: Label = hud.get("_health_label") as Label
	var panel: PanelContainer = hud.get("_panel") as PanelContainer
	_expect(health_label.text == "%d / %d" % [roundi(health.current_health), roundi(health.max_health)], "BOSS HUD没有显示精确整数生命")
	_expect(is_equal_approx(panel.offset_top, 90.0) and is_equal_approx(panel.offset_right - panel.offset_left, 460.0) and is_equal_approx(panel.offset_bottom - panel.offset_top, 52.0), "640×480 BOSS HUD尺寸或纵向偏移错误")
	map.set("_full_vision", true)
	map.call(&"_refresh_fog")
	_expect(boss.visible and hud.visible, "开发者全图视野没有显示BOSS和HUD")
	health.apply_network_state(health.max_health * 0.49, 0.0)
	boss.refresh_phase_from_health()
	var title_label: Label = hud.get("_title_label") as Label
	_expect(boss.get_phase() == 2 and title_label.text.contains("第二阶段"), "BOSS HUD没有同步第二阶段与赤金配色状态")
	health.apply_network_state(health.max_health * 0.60, 0.0)
	boss.refresh_phase_from_health()
	_expect(boss.get_phase() == 1 and title_label.text.contains("第一阶段"), "BOSS恢复过半后HUD没有回到第一阶段")
	map.set("_full_vision", false)
	map.call(&"_refresh_fog")

func _test_last_hit_reward(map: Node2D, boss: WorldBoss, health: HealthComponent) -> void:
	var states: Dictionary = map.get("_player_resource_states") as Dictionary
	var before: Dictionary = (states[1] as Dictionary).duplicate(true)
	health.apply_attack(999999.0, 1)
	_expect(int((states[1] as Dictionary).get("gold", 0)) == int(before.get("gold", 0)) + 300, "BOSS最后一击没有独享300金币")
	_expect(int((states[1] as Dictionary).get("iron", 0)) == int(before.get("iron", 0)) + 40, "BOSS最后一击没有独享40铁")
	_expect(int((states[1] as Dictionary).get("summon_token", 0)) == int(before.get("summon_token", 0)) + 5, "BOSS最后一击没有独享5召唤符")
	_expect(int((states[1] as Dictionary).get("skill_experience", 0)) == int(before.get("skill_experience", 0)) + 80, "BOSS最后一击没有独享80技能经验")
	_expect(int((states[1] as Dictionary).get("experience", 0)) == int(before.get("experience", 0)) + 250, "BOSS最后一击没有独享250经验")
	_expect(bool(map.get("_world_boss_defeated")) and not is_instance_valid(map.get("_world_boss") as WorldBoss), "BOSS死亡状态没有记录")
	map.call(&"_spawn_world_boss")
	_expect((map.get("world_boss_container") as Node2D).get_child_count() == 0, "BOSS死亡后在同一局重新刷新")
	_expect(not (map.get("boss_health_hud") as BossHealthHud).visible, "BOSS死亡后顶部血条没有隐藏")

func _validate_assets() -> void:
	var paths: Array[String] = [
		"res://art/units/world_boss_xuanyu.png",
		"res://art/vfx/world_boss_lair.png",
		"res://art/vfx/world_boss_mountain_break.png",
		"res://art/vfx/world_boss_infernal_charge.png",
		"res://art/vfx/world_boss_heavenfire.png",
	]
	for path: String in paths:
		var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
		_expect(not image.is_empty() and image.get_width() >= 1024 and image.get_height() >= 1024, "%s不是原始高清PNG" % path)
		_expect(image.get_format() == Image.FORMAT_RGBA8 and image.get_pixel(0, 0).a <= 0.001, "%s不是RGBA透明资源" % path)

func _return_targets(targets: Array[HealthComponent]) -> Array[HealthComponent]:
	return targets

func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE_SIZE) + Vector2.ONE * float(TILE_SIZE) * 0.5

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish(map: Node2D) -> void:
	map.queue_free()
	if _failures.is_empty():
		print("WORLD_BOSS_REGRESSION_OK")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("WORLD_BOSS_REGRESSION: %s" % failure)
	get_tree().quit(1)

extends Node

const UNIT_CATALOG: UnitCatalog = preload("res://game/data/unit_catalog.tres")

var _failures: PackedStringArray = []

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred(&"_run")

func _run() -> void:
	_expect(
		BaseProgression.RARITY_NAMES == PackedStringArray(["白色一般", "绿色普通", "蓝色优秀", "紫色优秀", "金色传说"]),
		"五档品质名称或顺序不正确"
	)
	_expect(BaseProgression.probability_summary(1) == "白色一般100%", "Lv.1召唤概率没有显示白色一般100%")
	var treant_definition: UnitDefinition = UNIT_CATALOG.get_definition(&"treant")
	var swordsman_definition: UnitDefinition = UNIT_CATALOG.get_definition(&"swordsman")
	_expect(treant_definition != null and treant_definition.rarity == UnitDefinition.Rarity.COMMON, "树人不是白色一般品质")
	_expect(swordsman_definition != null and swordsman_definition.rarity == UnitDefinition.Rarity.COMMON, "剑士不是白色一般品质")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20260830
	for _draw_index: int in 100:
		var cards: Array[UnitDefinition] = UNIT_CATALOG.build_summon_cards(1, 1, rng)
		_expect(cards.size() == 1 and cards[0].rarity == UnitDefinition.Rarity.COMMON, "Lv.1召唤仍会产出非白色一般品质")

	var main_scene: PackedScene = load("res://game/main/main.tscn") as PackedScene
	var map: Node2D = main_scene.instantiate() as Node2D
	get_tree().root.add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame
	map.call(&"_on_start_requested", false)
	await get_tree().process_frame
	(map.get("ai_controller") as SimpleAIController).configure(false)

	var units: Dictionary = map.get("_network_units") as Dictionary
	var builder_count_before: int = _find_units(units, 1, &"builder").size()
	for _spawn_index: int in 3:
		_expect(bool(map.call(&"_server_spawn_unit", 1, &"builder", 1)), "建筑工人生成失败")
	_expect(_find_units(units, 1, &"builder").size() == builder_count_before + 3, "非战斗单位被错误地自动融合")

	var hero_count_before: int = _find_units(units, 1, &"confucius").size()
	for _spawn_index: int in 3:
		_expect(bool(map.call(&"_server_spawn_unit", 1, &"confucius", 1)), "英雄生成失败")
	var heroes: Array[Node2D] = _find_units(units, 1, &"confucius")
	_expect(heroes.size() == hero_count_before + 3, "英雄被错误地接入战斗单位融合机制")
	for hero: Node2D in heroes:
		_expect(not hero.has_node("StarLabel"), "英雄头顶错误显示了战斗单位星级")

	_expect(_find_units(units, 1, &"ironbark_treant").is_empty(), "升星专项测试开始前已有铁木树人")
	for _spawn_index: int in 3:
		_expect(bool(map.call(&"_server_spawn_unit", 1, &"ironbark_treant", 1)), "铁木树人生成失败")
	var promoted_units: Array[Node2D] = _find_units(units, 1, &"ironbark_treant")
	_expect(promoted_units.size() == 1, "三个一星单位没有强制融合成一个二星单位")
	var two_star_unit: TreantUnit = promoted_units[0] as TreantUnit if not promoted_units.is_empty() else null
	if is_instance_valid(two_star_unit):
		var two_star_health: HealthComponent = two_star_unit.get_node_or_null("HealthComponent") as HealthComponent
		var two_star_label: Label = two_star_unit.get_node_or_null("StarLabel") as Label
		_expect(two_star_unit.star_level == 2, "融合后的单位不是二星")
		_expect(is_instance_valid(two_star_label) and two_star_label.text == "★★", "二星单位头顶没有显示两颗星")
		_expect(two_star_unit.get_effective_attack() > float(two_star_unit.definition.attack) * 3.0, "二星攻击力没有严格超过三个一星单位")
		_expect(is_instance_valid(two_star_health) and two_star_health.max_health > float(two_star_unit.definition.max_health) * 3.0, "二星生命没有严格超过三个一星单位")
		_expect(is_instance_valid(two_star_health) and two_star_health.base_defense > float(two_star_unit.definition.defense) * 3.0, "二星防御没有严格超过三个一星单位")

	for _spawn_index: int in 6:
		_expect(bool(map.call(&"_server_spawn_unit", 1, &"ironbark_treant", 1)), "三星连锁融合所需单位生成失败")
	var max_star_units: Array[Node2D] = _find_units(units, 1, &"ironbark_treant")
	_expect(max_star_units.size() == 1, "九个一星单位没有连锁融合成一个三星单位")
	var three_star_unit: TreantUnit = max_star_units[0] as TreantUnit if not max_star_units.is_empty() else null
	if is_instance_valid(three_star_unit):
		var three_star_label: Label = three_star_unit.get_node_or_null("StarLabel") as Label
		_expect(three_star_unit.star_level == 3, "连锁融合后的单位不是三星")
		_expect(is_instance_valid(three_star_label) and three_star_label.text == "★★★", "三星单位头顶没有显示三颗星")
		_expect(
			three_star_unit.get_star_stat_multiplier() > TreantUnit.STAR_STAT_MULTIPLIERS[1] * 3.0,
			"三星核心属性没有严格超过三个二星单位"
		)

	map.queue_free()
	if _failures.is_empty():
		print("COMBAT_UNIT_STAR_FUSION_TEST: PASS")
		await get_tree().create_timer(0.5).timeout
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("COMBAT_UNIT_STAR_FUSION_TEST: %s" % failure)
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(1)

func _find_units(units: Dictionary, owner_peer_id: int, definition_id: StringName) -> Array[Node2D]:
	var matches: Array[Node2D] = []
	for unit: Node2D in units.values():
		if not is_instance_valid(unit):
			continue
		var definition: UnitDefinition = unit.get("definition") as UnitDefinition
		if int(unit.get("owner_peer_id")) == owner_peer_id and definition != null and definition.unit_id == definition_id:
			matches.append(unit)
	return matches

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

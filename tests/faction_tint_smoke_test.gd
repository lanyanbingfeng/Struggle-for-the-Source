extends Node

const MAIN_SCENE: PackedScene = preload("res://game/main/main.tscn")
const EXPECTED_ENEMY_TINT: Color = Color("#ff947d")

var _failures: PackedStringArray = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred(&"_run")

func _run() -> void:
	var map: Node2D = MAIN_SCENE.instantiate() as Node2D
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame
	map.call(&"_on_start_requested", false)
	await get_tree().process_frame
	(map.get("ai_controller") as SimpleAIController).configure(false)
	_expect(bool(map.call(&"_server_spawn_unit", 1, &"swordsman", 1)), "己方剑士生成失败")
	_expect(bool(map.call(&"_server_spawn_unit", 2, &"swordsman", 2)), "敌方剑士生成失败")
	await get_tree().process_frame

	var bases: Dictionary = map.get("_player_base_by_territory_id") as Dictionary
	_expect_sprite_tint(bases.get(1) as Node, Color.WHITE, "己方基地")
	_expect_sprite_tint(bases.get(2) as Node, EXPECTED_ENEMY_TINT, "敌方基地")

	var units: Dictionary = map.get("_network_units") as Dictionary
	var checked_local_unit: bool = false
	var checked_enemy_unit: bool = false
	for unit_value: Variant in units.values():
		var unit: Node2D = unit_value as Node2D
		if unit == null:
			continue
		var is_local: bool = int(unit.get("owner_peer_id")) == 1
		_expect_sprite_tint(unit, Color.WHITE if is_local else EXPECTED_ENEMY_TINT, "己方单位" if is_local else "敌方单位")
		var health_bar: Node2D = unit.get_node_or_null("HealthBar") as Node2D
		_expect(health_bar != null and health_bar.self_modulate.is_equal_approx(Color.WHITE), "%s的生命条不应被阵营色染色" % unit.name)
		checked_local_unit = checked_local_unit or is_local
		checked_enemy_unit = checked_enemy_unit or not is_local
	_expect(checked_local_unit, "没有验证到己方单位")
	_expect(checked_enemy_unit, "没有验证到敌方单位")

	map.queue_free()
	if _failures.is_empty():
		print("FACTION_TINT_SMOKE_OK")
		await get_tree().create_timer(0.5).timeout
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("FACTION_TINT_SMOKE: %s" % failure)
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(1)

func _expect_sprite_tint(root_node: Node, expected_tint: Color, label: String) -> void:
	if not is_instance_valid(root_node):
		_expect(false, "%s实例缺失" % label)
		return
	var sprites: Array[Node] = root_node.find_children("*", "Sprite2D", true, false)
	_expect(not sprites.is_empty(), "%s没有可着色的Sprite2D" % label)
	for visual_node: Node in sprites:
		var sprite: Sprite2D = visual_node as Sprite2D
		_expect(sprite != null and sprite.self_modulate.is_equal_approx(expected_tint), "%s颜色不正确" % label)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

extends Node

const UNIT_CATALOG: UnitCatalog = preload("res://game/data/unit_catalog.tres")
const BUILDING_CATALOG: BuildingCatalog = preload("res://game/data/building_catalog.tres")
const SWORDSMAN_SCENE: PackedScene = preload("res://game/units/swordsman_unit.tscn")
const BUILDING_SCENE: PackedScene = preload("res://game/world/production_building.tscn")

var _failures: PackedStringArray = []

func _ready() -> void:
	call_deferred(&"_run")

func _run() -> void:
	_test_chest_command_does_not_return()
	_test_building_input_and_countdown()
	await get_tree().process_frame
	if _failures.is_empty():
		print("BUILDING_CHEST_INTERACTION_REGRESSION_OK")
		await get_tree().create_timer(1.0).timeout
		get_tree().quit(0)
	else:
		for failure: String in _failures:
			push_error(failure)
		await get_tree().create_timer(1.0).timeout
		get_tree().quit(1)

func _test_chest_command_does_not_return() -> void:
	var unit: TreantUnit = SWORDSMAN_SCENE.instantiate() as TreantUnit
	add_child(unit)
	unit.configure_network(1, 1, 1, UNIT_CATALOG.get_definition(&"swordsman"), true)
	unit.setup_combat_context(Callable(), Callable(), Callable(), 32)
	var chest: Node2D = Node2D.new()
	add_child(chest)
	var health: HealthComponent = HealthComponent.new()
	chest.add_child(health)
	health.configure(chest, 0, 1.0, 0.0)
	_expect(unit.set_priority_attack_target(health), "无法对宝箱设置玩家指定攻击")
	health.apply_attack(10.0, 1)
	unit.call(&"_validate_combat_target")
	_expect(not bool(unit.get("_returning_from_combat")), "打开宝箱后战斗单位仍返回初始位置")
	_expect(not bool(unit.get("has_move_target")), "打开宝箱后残留了返航移动目标")
	unit.queue_free()
	chest.queue_free()

func _test_building_input_and_countdown() -> void:
	var building: ProductionBuilding = BUILDING_SCENE.instantiate() as ProductionBuilding
	add_child(building)
	building.configure(7, 1, 1, BUILDING_CATALOG.get_definition(&"coin_table"), true)
	_expect(not building.construction_label.text.is_empty(), "施工建筑没有显示剩余时间")
	building.force_finish_construction()
	building.set_pending_amount(35)
	_expect(building.bubble_area.visible and building.bubble_area.input_pickable, "生产气泡没有正确显示或不可点击")
	_expect(building.bubble_icon.texture != null and not building.bubble_glyph.visible, "生产气泡没有显示对应资源美术")
	var collected: Array[bool] = []
	building.collection_requested.connect(func(_source: ProductionBuilding) -> void: collected.append(true))
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	building.call(&"_on_bubble_input", get_viewport(), click, 0)
	_expect(collected.size() == 1, "点击生产气泡没有发出收货请求")
	var interacted: Array[bool] = []
	building.interaction_requested.connect(func(_source: ProductionBuilding) -> void: interacted.append(true))
	building.call(&"_on_interaction_input", get_viewport(), click, 0)
	_expect(interacted.size() == 1, "点击英雄台使用的建筑交互区没有响应")
	building.queue_free()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

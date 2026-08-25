extends Node

const UNIT_CATALOG: UnitCatalog = preload("res://game/data/unit_catalog.tres")
const BUILDING_CATALOG: BuildingCatalog = preload("res://game/data/building_catalog.tres")

var _failures: PackedStringArray = []

func _ready() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var target := Node2D.new()
	target.position = Vector2(640.0, 500.0)
	get_tree().root.add_child(target)

	var summon_menu := SummonCardMenu.new()
	get_tree().root.add_child(summon_menu)
	await get_tree().process_frame

	var recruitment_cards: Array[UnitDefinition] = UNIT_CATALOG.build_recruitment_cards()
	_expect(recruitment_cards.size() == 4, "招募池没有生成4张选择卡")
	summon_menu.open_for(target, recruitment_cards, false)
	_expect(summon_menu.visible, "招募卡牌菜单打开后不可见")
	summon_menu.call(&"_on_backdrop_pressed")
	_expect(summon_menu.visible, "打开卡牌的同一次点击穿透并关闭了菜单")
	await get_tree().process_frame

	var card_row := summon_menu.get("_card_row") as HBoxContainer
	_expect(card_row != null and card_row.get_child_count() == 4, "招募卡牌节点数量不正确")
	if card_row != null:
		for card: Button in card_row.get_children():
			_expect(card.custom_minimum_size == Vector2(104.0, 136.0), "卡牌没有使用新版高清布局尺寸")

	for unit_id: StringName in [&"lumber", &"explorer", &"builder", &"swordsman"]:
		var definition: UnitDefinition = UNIT_CATALOG.get_definition(unit_id)
		_expect(definition != null and definition.card_texture != null, "%s缺少卡牌立绘" % unit_id)
		if definition != null and definition.card_texture != null:
			_expect(definition.card_texture.get_width() > 32 and definition.card_texture.get_height() > 32, "%s仍在使用32像素地图贴图" % unit_id)

	var command_panel := UnitCommandPanel.new()
	get_tree().root.add_child(command_panel)
	await get_tree().process_frame
	command_panel.show_builder(1, BUILDING_CATALOG.definitions)
	var building_list := command_panel.get("_building_list") as GridContainer
	_expect(building_list != null and building_list.get_child_count() == BUILDING_CATALOG.definitions.size(), "建筑选择按钮数量不正确")
	if building_list != null:
		for child: Node in building_list.get_children():
			var button := child as Button
			_expect(button != null and button.icon != null, "建筑选择按钮没有使用工坊美术")
			if button != null and button.icon != null:
				_expect(button.icon.get_width() > 32, "建筑选择按钮仍在使用低分辨率图标")

	if _failures.is_empty():
		print("CARD_UI_SMOKE_TEST: PASS")
		await get_tree().create_timer(3.0).timeout
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("CARD_UI_SMOKE_TEST: FAIL (%d)" % _failures.size())
	await get_tree().create_timer(3.0).timeout
	get_tree().quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

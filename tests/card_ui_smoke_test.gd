extends Node

const UNIT_CATALOG: UnitCatalog = preload("res://game/data/unit_catalog.tres")
const BUILDING_CATALOG: BuildingCatalog = preload("res://game/data/building_catalog.tres")
const WORLD_SPRITE_PATHS: Dictionary = {
	&"lumber": NodePath("Visuals/Body"),
	&"quarry": NodePath("Visuals/Body"),
	&"explorer": NodePath("Sprite"),
	&"builder": NodePath("Sprite"),
	&"swordsman": NodePath("Sprite"),
	&"treant": NodePath("Sprite"),
}

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
			if StringName(card.get_meta(&"unit_id", &"")) == &"swordsman":
				var swordsman_definition: UnitDefinition = UNIT_CATALOG.get_definition(&"swordsman")
				summon_menu.call(&"_on_card_mouse_entered", card, swordsman_definition)
				await get_tree().process_frame
				var skill_label := summon_menu.get("_detail_skill") as Label
				var detail_panel := summon_menu.get("_detail_panel") as PanelContainer
				_expect(skill_label != null and skill_label.text.contains("这一剑会很帅"), "剑士技能名称没有显示在召唤卡详情中")
				_expect(skill_label != null and skill_label.text.contains("200%攻击力"), "剑士技能介绍没有显示200%攻击力伤害")
				_expect(skill_label != null and skill_label.text.contains("低于5%"), "剑士技能介绍没有显示斩杀条件")
				_expect(detail_panel != null and detail_panel.custom_minimum_size == Vector2(260.0, 188.0), "召唤卡详情面板没有使用紧凑尺寸")
				_expect(detail_panel != null and detail_panel.size.x <= 260.0 and detail_panel.size.y <= 205.0, "召唤卡详情内容仍然撑得过大")

	for unit_id: StringName in [&"lumber", &"quarry", &"explorer", &"builder", &"swordsman", &"treant"]:
		var definition: UnitDefinition = UNIT_CATALOG.get_definition(unit_id)
		_expect(definition != null and definition.card_texture != null, "%s缺少卡牌立绘" % unit_id)
		if definition != null and definition.card_texture != null:
			_expect(definition.card_texture.get_width() > 32 and definition.card_texture.get_height() > 32, "%s仍在使用32像素地图贴图" % unit_id)
			var unit: Node = definition.scene.instantiate()
			var sprite_path: NodePath = WORLD_SPRITE_PATHS.get(unit_id, NodePath("Sprite"))
			var sprite: Sprite2D = unit.get_node_or_null(sprite_path) as Sprite2D
			_expect(sprite != null, "%s缺少世界美术节点" % unit_id)
			if sprite != null:
				_expect(sprite.texture != null and sprite.texture.resource_path == definition.card_texture.resource_path, "%s的卡牌与世界没有共享同一张纹理" % unit_id)
				var image: Image = sprite.texture.get_image()
				var used_size: Vector2 = Vector2(image.get_used_rect().size) * sprite.scale.abs()
				_expect(used_size.x <= 32.0 and used_size.y <= 32.0, "%s的世界美术超过一格：%s" % [unit_id, used_size])
			unit.free()

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

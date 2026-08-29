class_name HeroSummonPanel
extends CanvasLayer

signal hero_selected(hero_id: StringName)
signal closed

const CARD_SIZE: Vector2 = Vector2(230.0, 344.0)

var _root: Control
var _panel: PanelContainer
var _title: Label
var _cost_label: Label
var _card_grid: GridContainer

func _ready() -> void:
	layer = 20
	_build_ui()
	hide()

func open_for(heroes: Array[UnitDefinition], replacing: bool) -> void:
	_title.text = "英雄召唤"
	_cost_label.text = "替换当前英雄消耗 1 张召唤符" if replacing else "首次召唤消耗 2 张召唤符"
	_rebuild_cards(heroes)
	show()

func close() -> void:
	hide()
	closed.emit()

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("#07100dcc")
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(backdrop)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -310.0
	_panel.offset_top = -215.0
	_panel.offset_right = 310.0
	_panel.offset_bottom = 215.0
	_panel.add_theme_stylebox_override(&"panel", _panel_style())
	_root.add_child(_panel)

	var margin := MarginContainer.new()
	for side: StringName in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 14)
	_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 8)
	margin.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	_title = Label.new()
	_title.text = "英雄召唤"
	_title.add_theme_font_size_override(&"font_size", 22)
	_title.add_theme_color_override(&"font_color", Color("#ffe3a0"))
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.pressed.connect(close)
	header.add_child(close_button)

	_cost_label = Label.new()
	_cost_label.add_theme_font_size_override(&"font_size", 13)
	_cost_label.add_theme_color_override(&"font_color", Color("#b8e8cd"))
	column.add_child(_cost_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_card_grid = GridContainer.new()
	_card_grid.columns = 4
	_card_grid.add_theme_constant_override(&"h_separation", 12)
	_card_grid.add_theme_constant_override(&"v_separation", 12)
	scroll.add_child(_card_grid)

func _rebuild_cards(heroes: Array[UnitDefinition]) -> void:
	for child: Node in _card_grid.get_children():
		child.queue_free()
	for hero: UnitDefinition in heroes:
		if hero != null and hero.category == UnitDefinition.Category.HERO:
			_card_grid.add_child(_create_hero_card(hero))

func _create_hero_card(hero: UnitDefinition) -> Button:
	var card := Button.new()
	card.custom_minimum_size = CARD_SIZE
	card.clip_contents = true
	card.focus_mode = Control.FOCUS_ALL
	card.add_theme_stylebox_override(&"normal", _card_style(Color("#2a4638")))
	card.add_theme_stylebox_override(&"hover", _card_style(Color("#365d49")))
	card.add_theme_stylebox_override(&"pressed", _card_style(Color("#20392e")))
	card.pressed.connect(_on_card_pressed.bind(hero.unit_id))

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 10.0
	column.offset_top = 10.0
	column.offset_right = -10.0
	column.offset_bottom = -10.0
	column.add_theme_constant_override(&"separation", 4)
	card.add_child(column)

	var portrait := TextureRect.new()
	portrait.texture = hero.card_texture
	portrait.custom_minimum_size = Vector2(210.0, 210.0)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(portrait)

	var name_label := Label.new()
	name_label.text = hero.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override(&"font_size", 18)
	name_label.add_theme_color_override(&"font_color", Color("#ffe2a1"))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(name_label)

	var role_label := Label.new()
	role_label.text = "%s｜生命 %d｜攻击 %d｜防御 %d" % [hero.role_name, hero.max_health, hero.attack, hero.defense]
	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_label.add_theme_font_size_override(&"font_size", 10)
	role_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(role_label)

	var skill_label := Label.new()
	skill_label.text = _hero_skill_summary(hero)
	skill_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_label.add_theme_font_size_override(&"font_size", 10)
	skill_label.add_theme_color_override(&"font_color", Color("#9fe6ff"))
	skill_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(skill_label)

	var action_label := Label.new()
	action_label.text = "点击召唤"
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_label.add_theme_font_size_override(&"font_size", 12)
	action_label.add_theme_color_override(&"font_color", Color("#b7ef9d"))
	action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(action_label)
	return card

func _hero_skill_summary(hero: UnitDefinition) -> String:
	var names: PackedStringArray = []
	var passive: Resource = hero.get("passive_skill") as Resource
	if passive != null:
		names.append(str(passive.get("display_name")))
	var active_skills: Array = hero.get("active_skills") as Array
	for skill_value: Variant in active_skills:
		var skill: Resource = skill_value as Resource
		if skill != null:
			names.append(str(skill.get("display_name")))
	return "技能：%s" % "、".join(names)

func _on_card_pressed(hero_id: StringName) -> void:
	hero_selected.emit(hero_id)
	close()

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#10271ff7")
	style.border_color = Color("#c58b43")
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.shadow_color = Color("#000000aa")
	style.shadow_size = 10
	return style

func _card_style(background: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = Color("#d4ac63")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style

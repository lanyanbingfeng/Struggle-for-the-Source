class_name SummonCardMenu
extends CanvasLayer

signal unit_selected(unit_id: StringName)

const CARD_SIZE: Vector2 = Vector2(104.0, 136.0)
const CARD_GAP: float = 8.0
const CARD_WORLD_GAP: float = 20.0
const DETAIL_SIZE: Vector2 = Vector2(260.0, 188.0)
const DETAIL_GAP: float = 8.0

var _root: Control
var _backdrop: Button
var _card_row: HBoxContainer
var _detail_panel: PanelContainer
var _detail_title: Label
var _detail_role: Label
var _detail_stats: Label
var _detail_secondary: Label
var _detail_skill: Label
var _detail_description: Label
var _follow_target: Node2D
var _hovered_card: Button
var _mandatory_selection: bool = false
var _backdrop_close_allowed_at_msec: int = 0

func _ready() -> void:
	layer = 18
	_build_ui()
	hide()

func _process(_delta: float) -> void:
	if not visible:
		return
	if not is_instance_valid(_follow_target):
		close(true)
		return
	_reposition_card_row()
	if is_instance_valid(_hovered_card) and _detail_panel.visible:
		_reposition_detail_panel(_hovered_card)

func open_for(target: Node2D, cards: Array[UnitDefinition], mandatory_selection: bool = false) -> void:
	_follow_target = target
	_mandatory_selection = mandatory_selection
	_backdrop_close_allowed_at_msec = Time.get_ticks_msec() + 150
	_backdrop.disabled = true
	_clear_cards()
	for definition: UnitDefinition in cards:
		if definition != null:
			_card_row.add_child(_create_card(definition))
	_reposition_card_row()
	show()
	_backdrop.set_deferred(&"disabled", false)

func close(force: bool = false) -> void:
	if _mandatory_selection and not force:
		return
	_hovered_card = null
	_follow_target = null
	_mandatory_selection = false
	_detail_panel.hide()
	hide()

func _build_ui() -> void:
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_backdrop = Button.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.focus_mode = Control.FOCUS_NONE
	_backdrop.flat = true
	_backdrop.set_meta(&"allow_edge_scroll", true)
	_backdrop.pressed.connect(_on_backdrop_pressed)
	_root.add_child(_backdrop)

	_card_row = HBoxContainer.new()
	_card_row.add_theme_constant_override(&"separation", int(CARD_GAP))
	_root.add_child(_card_row)

	_detail_panel = PanelContainer.new()
	_detail_panel.custom_minimum_size = DETAIL_SIZE
	_detail_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_panel.z_index = 5
	_detail_panel.add_theme_stylebox_override(&"panel", _make_detail_style())
	_root.add_child(_detail_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 9)
	margin.add_theme_constant_override(&"margin_top", 7)
	margin.add_theme_constant_override(&"margin_right", 9)
	margin.add_theme_constant_override(&"margin_bottom", 7)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_panel.add_child(margin)

	var details: VBoxContainer = VBoxContainer.new()
	details.add_theme_constant_override(&"separation", 1)
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(details)

	_detail_title = _create_detail_label(14, Color("#ffe29a"))
	_detail_role = _create_detail_label(10, Color("#a8d97b"))
	_detail_stats = _create_detail_label(10, Color("#fff2c8"))
	_detail_secondary = _create_detail_label(9, Color("#c3d6c9"))
	_detail_skill = _create_detail_label(9, Color("#9fe6ff"))
	_detail_skill.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_skill.custom_minimum_size = Vector2(242.0, 0.0)
	_detail_description = _create_detail_label(9, Color("#e8e0c8"))
	_detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_description.custom_minimum_size = Vector2(242.0, 0.0)
	var detail_labels: Array[Label] = [_detail_title, _detail_role, _detail_stats, _detail_secondary, _detail_skill, _detail_description]
	for label: Label in detail_labels:
		details.add_child(label)
	_detail_panel.hide()

func _clear_cards() -> void:
	_hovered_card = null
	_detail_panel.hide()
	for child: Node in _card_row.get_children():
		_card_row.remove_child(child)
		child.queue_free()

func _create_card(definition: UnitDefinition) -> Button:
	var button: Button = Button.new()
	var rarity_color: Color = _rarity_color(definition.rarity)
	button.custom_minimum_size = CARD_SIZE
	button.size = CARD_SIZE
	button.set_meta(&"unit_id", definition.unit_id)
	button.clip_contents = true
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	button.pivot_offset = CARD_SIZE * 0.5
	button.add_theme_stylebox_override(&"normal", _make_card_style(rarity_color, Color("#111b18f8"), 2))
	button.add_theme_stylebox_override(&"hover", _make_card_style(rarity_color.lightened(0.16), Color("#1b2a24ff"), 3))
	button.add_theme_stylebox_override(&"pressed", _make_card_style(rarity_color.darkened(0.08), Color("#0d1512ff"), 3))
	button.add_theme_stylebox_override(&"focus", _make_card_style(rarity_color.lightened(0.24), Color("#15231eff"), 3))
	button.pressed.connect(_on_card_pressed.bind(definition.unit_id))
	button.mouse_entered.connect(_on_card_mouse_entered.bind(button, definition))
	button.mouse_exited.connect(_on_card_mouse_exited.bind(button))

	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 0)
	button.add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 6.0
	column.offset_top = 7.0
	column.offset_right = -6.0
	column.offset_bottom = -6.0

	var art_panel: PanelContainer = PanelContainer.new()
	art_panel.custom_minimum_size = Vector2(92.0, 100.0)
	art_panel.clip_contents = true
	art_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_panel.add_theme_stylebox_override(&"panel", _make_art_style(rarity_color))
	column.add_child(art_panel)

	var texture: TextureRect = TextureRect.new()
	texture.texture = definition.card_texture
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_panel.add_child(texture)
	texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture.offset_left = 3.0
	texture.offset_top = 3.0
	texture.offset_right = -3.0
	texture.offset_bottom = -3.0

	var name_label: Label = Label.new()
	name_label.text = definition.display_name
	name_label.custom_minimum_size = Vector2(0.0, 23.0)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override(&"font_size", 13)
	name_label.add_theme_color_override(&"font_color", Color("#fff6da"))
	name_label.add_theme_color_override(&"font_outline_color", Color("#101410"))
	name_label.add_theme_constant_override(&"outline_size", 3)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(name_label)

	var category_badge: Label = _create_card_badge("工" if definition.category == UnitDefinition.Category.WORKER else "战", rarity_color)
	button.add_child(category_badge)
	category_badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
	category_badge.offset_left = 8.0
	category_badge.offset_top = 9.0
	category_badge.offset_right = 30.0
	category_badge.offset_bottom = 29.0

	var rarity_badge: Label = _create_card_badge(_rarity_short_name(definition.rarity), rarity_color)
	button.add_child(rarity_badge)
	rarity_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	rarity_badge.offset_left = -30.0
	rarity_badge.offset_top = 9.0
	rarity_badge.offset_right = -8.0
	rarity_badge.offset_bottom = 29.0
	return button

func _on_card_pressed(unit_id: StringName) -> void:
	unit_selected.emit(unit_id)
	close(true)

func _on_backdrop_pressed() -> void:
	if Time.get_ticks_msec() < _backdrop_close_allowed_at_msec:
		return
	close(false)

func _on_card_mouse_entered(button: Button, definition: UnitDefinition) -> void:
	_hovered_card = button
	_animate_card(button, Vector2(1.045, 1.045))
	_detail_title.text = definition.display_name
	_detail_role.text = "品质：%s    定位：%s" % [BaseProgression.RARITY_NAMES[int(definition.rarity)], definition.role_name]
	_detail_stats.text = "生命 %d    攻击 %d    防御 %d" % [definition.max_health, definition.attack, definition.defense]
	_detail_secondary.text = "攻速 %.2f秒    攻距 %.1f格    闪避 %d%%\n追击 %.1f格    移速 %.0f    魔法 %d" % [
		definition.attack_interval_seconds, definition.attack_range_tiles, roundi(definition.evasion_chance * 100.0),
		definition.chase_range_tiles, definition.movement_speed, definition.max_mana,
	]
	if definition.recruit_cost_gold > 0:
		_detail_secondary.text += "    招募%d金币" % definition.recruit_cost_gold
	_detail_skill.text = "技能：无" if definition.skill_name.is_empty() else "技能：%s｜%s" % [definition.skill_name, definition.skill_description]
	_detail_description.text = definition.description
	_detail_panel.show()
	_reposition_detail_panel(button)

func _on_card_mouse_exited(button: Button) -> void:
	_animate_card(button, Vector2.ONE)
	if _hovered_card != button:
		return
	_hovered_card = null
	_detail_panel.hide()

func _reposition_card_row() -> void:
	if not is_instance_valid(_follow_target):
		return
	var card_count: int = _card_row.get_child_count()
	var total_width: float = float(card_count) * CARD_SIZE.x + float(maxi(0, card_count - 1)) * CARD_GAP
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var target_screen_position: Vector2 = _follow_target.get_global_transform_with_canvas().origin
	_card_row.position = Vector2(
		clampf(target_screen_position.x - total_width * 0.5, 8.0, maxf(8.0, viewport_size.x - total_width - 8.0)),
		clampf(target_screen_position.y - CARD_SIZE.y - CARD_WORLD_GAP, 8.0, maxf(8.0, viewport_size.y - CARD_SIZE.y - 8.0))
	)

func _reposition_detail_panel(button: Button) -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var card_rect: Rect2 = button.get_global_rect()
	var panel_position: Vector2 = Vector2(
		card_rect.position.x + (CARD_SIZE.x - DETAIL_SIZE.x) * 0.5,
		card_rect.end.y + DETAIL_GAP
	)
	if panel_position.y + DETAIL_SIZE.y > viewport_size.y - 8.0:
		panel_position.y = card_rect.position.y - DETAIL_SIZE.y - DETAIL_GAP
	panel_position.x = clampf(panel_position.x, 8.0, maxf(8.0, viewport_size.x - DETAIL_SIZE.x - 8.0))
	panel_position.y = clampf(panel_position.y, 8.0, maxf(8.0, viewport_size.y - DETAIL_SIZE.y - 8.0))
	_detail_panel.position = panel_position

func _create_detail_label(font_size: int, font_color: Color) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", font_color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _create_card_badge(text: String, accent: Color) -> Label:
	var badge: Label = Label.new()
	badge.text = text
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_font_size_override(&"font_size", 10)
	badge.add_theme_color_override(&"font_color", Color("#172019"))
	badge.add_theme_stylebox_override(&"normal", _make_badge_style(accent))
	return badge

func _animate_card(button: Button, target_scale: Vector2) -> void:
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", target_scale, 0.11)

func _make_card_style(border_color: Color, background: Color, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(9)
	style.shadow_color = Color("#00000099")
	style.shadow_size = 5
	style.shadow_offset = Vector2(0.0, 3.0)
	return style

func _make_art_style(accent: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("#0b1411")
	style.border_color = accent.darkened(0.28)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style

func _make_badge_style(accent: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = accent
	style.border_color = Color("#fff8d0aa")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style

func _rarity_short_name(rarity: UnitDefinition.Rarity) -> String:
	match rarity:
		UnitDefinition.Rarity.UNCOMMON:
			return "良"
		UnitDefinition.Rarity.RARE:
			return "稀"
		UnitDefinition.Rarity.EPIC:
			return "史"
		UnitDefinition.Rarity.LEGENDARY:
			return "传"
		_:
			return "普"

func _rarity_color(rarity: UnitDefinition.Rarity) -> Color:
	match rarity:
		UnitDefinition.Rarity.UNCOMMON:
			return Color("#bde9a5")
		UnitDefinition.Rarity.RARE:
			return Color("#8fc5ff")
		UnitDefinition.Rarity.EPIC:
			return Color("#c9a0ff")
		UnitDefinition.Rarity.LEGENDARY:
			return Color("#ffd36a")
		_:
			return Color("#fff1bd")

func _make_detail_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("#10291fee")
	style.border_color = Color("#a66d2c")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = Color("#00000088")
	style.shadow_size = 6
	style.shadow_offset = Vector2(0.0, 3.0)
	return style

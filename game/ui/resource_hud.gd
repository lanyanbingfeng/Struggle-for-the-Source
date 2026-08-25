extends CanvasLayer

const PANEL_POSITION: Vector2 = Vector2(10.0, 10.0)
const PANEL_SIZE: Vector2 = Vector2(466.0, 44.0)
const CARD_SIZE: Vector2 = Vector2(69.0, 30.0)

var _resource_manager: Node
var _value_labels: Dictionary = {}

func _ready() -> void:
	_build_ui()

func bind(resource_manager: Node) -> void:
	_resource_manager = resource_manager
	if not _resource_manager.is_connected(&"resources_changed", _on_resources_changed):
		_resource_manager.connect(&"resources_changed", _on_resources_changed)
	_on_resources_changed(
		int(_resource_manager.get("gold")),
		int(_resource_manager.get("wood")),
		int(_resource_manager.get("stone")),
		int(_resource_manager.get("iron")),
		int(_resource_manager.get("gold_ore")),
		int(_resource_manager.get("diamond"))
	)

func _build_ui() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.position = PANEL_POSITION
	panel.custom_minimum_size = PANEL_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 5)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)

	var resource_row: HBoxContainer = HBoxContainer.new()
	resource_row.add_theme_constant_override("separation", 4)
	resource_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(resource_row)

	_add_resource_card(resource_row, &"gold", "金币", Color("#f2c14e"))
	_add_resource_card(resource_row, &"wood", "木材", Color("#b9753b"))
	_add_resource_card(resource_row, &"stone", "石头", Color("#9aa6ad"))
	_add_resource_card(resource_row, &"iron", "铁矿", Color("#7da7c2"))
	_add_resource_card(resource_row, &"gold_ore", "金矿", Color("#e5a93d"))
	_add_resource_card(resource_row, &"diamond", "钻石", Color("#72e7ee"))

func _add_resource_card(
	parent: HBoxContainer,
	resource_id: StringName,
	resource_name: String,
	accent_color: Color
) -> void:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", _make_card_style())
	parent.add_child(card)

	var card_row: HBoxContainer = HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 4)
	card_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(card_row)

	var accent: ColorRect = ColorRect.new()
	accent.custom_minimum_size = Vector2(5.0, 20.0)
	accent.color = accent_color
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_row.add_child(accent)

	var text_column: VBoxContainer = VBoxContainer.new()
	text_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_row.add_child(text_column)

	var title: Label = Label.new()
	title.text = resource_name
	title.add_theme_font_size_override("font_size", 8)
	title.add_theme_color_override("font_color", Color("#d7c9a3"))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_column.add_child(title)

	var value: Label = Label.new()
	value.text = "0"
	value.add_theme_font_size_override("font_size", 11)
	value.add_theme_color_override("font_color", Color("#fff4c4"))
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_column.add_child(value)
	_value_labels[resource_id] = value

func _make_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("#263a39e8")
	style.border_color = Color("#d6b56a")
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	return style

func _make_card_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("#182827d9")
	style.border_color = Color("#526c61")
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 3.0
	style.content_margin_top = 2.0
	style.content_margin_right = 3.0
	style.content_margin_bottom = 2.0
	return style

func _on_resources_changed(new_gold: int, new_wood: int, new_stone: int, new_iron: int, new_gold_ore: int, new_diamond: int) -> void:
	_set_value(&"gold", new_gold)
	_set_value(&"wood", new_wood)
	_set_value(&"stone", new_stone)
	_set_value(&"iron", new_iron)
	_set_value(&"gold_ore", new_gold_ore)
	_set_value(&"diamond", new_diamond)

func _set_value(resource_id: StringName, amount: int) -> void:
	var value_label: Label = _value_labels.get(resource_id) as Label
	if value_label != null:
		value_label.text = str(amount)

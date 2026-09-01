class_name TacticalMap
extends CanvasLayer

signal camera_jump_requested(world_position: Vector2)

var _available: bool = false
var _root: Control
var _panel: PanelContainer
var _map_view: TacticalMapView
var _summary_label: Label
var _hover_label: Label

func _ready() -> void:
	layer = 70
	_build_ui()
	hide()

func configure(
	fog_of_war: FogOfWar,
	world_size: Vector2,
	tile_size: int,
	map_data_provider: Callable,
	camera: Camera2D
) -> void:
	_map_view.configure(fog_of_war, world_size, tile_size, map_data_provider, camera)
	_available = true

func set_available(available: bool) -> void:
	_available = available
	if not _available:
		close_map()

func toggle_map() -> void:
	if not _available:
		return
	if visible:
		close_map()
	else:
		open_map()

func open_map() -> void:
	if not _available:
		return
	show()
	_map_view.set_map_active(true)
	_map_view.grab_focus()

func close_map() -> void:
	_map_view.set_map_active(false)
	hide()

func _input(event: InputEvent) -> void:
	if not _available or event is not InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	var is_map_key: bool = key_event.keycode == KEY_M or key_event.physical_keycode == KEY_M
	if is_map_key:
		toggle_map()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed(&"ui_cancel"):
		# Keep Esc from opening another overlay while the tactical map is active.
		# The map itself is intentionally closed only by pressing M again.
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color("#020706d9")
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(shade)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(620.0, 462.0)
	_panel.add_theme_stylebox_override(&"panel", _make_panel_style())
	center.add_child(_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 12)
	margin.add_theme_constant_override(&"margin_top", 9)
	margin.add_theme_constant_override(&"margin_right", 12)
	margin.add_theme_constant_override(&"margin_bottom", 9)
	_panel.add_child(margin)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 4)
	margin.add_child(column)

	var header: HBoxContainer = HBoxContainer.new()
	column.add_child(header)
	var title: Label = Label.new()
	title.text = "战术地图"
	title.add_theme_font_size_override(&"font_size", 22)
	title.add_theme_color_override(&"font_color", Color("#fff0bc"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(title)
	var close_hint: Label = Label.new()
	close_hint.text = "按 M 关闭"
	close_hint.add_theme_font_size_override(&"font_size", 12)
	close_hint.add_theme_color_override(&"font_color", Color("#c9d8cc"))
	close_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(close_hint)

	_summary_label = Label.new()
	_summary_label.text = "正在读取已探索区域情报……"
	_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary_label.add_theme_font_size_override(&"font_size", 11)
	_summary_label.add_theme_color_override(&"font_color", Color("#d9e8d5"))
	_summary_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_summary_label)

	var legend: HBoxContainer = HBoxContainer.new()
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	legend.add_theme_constant_override(&"separation", 10)
	column.add_child(legend)
	_add_legend_item(legend, "●", "战斗单位", Color("#78f0a1"))
	_add_legend_item(legend, "◆", "基地", Color("#f2cc75"))
	_add_legend_item(legend, "■", "建筑", Color("#72c8ff"))
	_add_legend_item(legend, "▲", "树", Color("#74c66a"))
	_add_legend_item(legend, "◆", "石", Color("#b4bec7"))
	_add_legend_item(legend, "✚", "铁", Color("#63b8d8"))
	_add_legend_item(legend, "▣", "宝箱", Color("#e9b94e"))

	_map_view = TacticalMapView.new()
	_map_view.custom_minimum_size = Vector2(592.0, 315.0)
	_map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_view.world_selected.connect(_on_world_selected)
	_map_view.hover_changed.connect(_on_hover_changed)
	_map_view.summary_changed.connect(_on_summary_changed)
	column.add_child(_map_view)

	_hover_label = Label.new()
	_hover_label.text = "悬停图标查看名称、阵营、生命和状态"
	_hover_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hover_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_hover_label.add_theme_font_size_override(&"font_size", 11)
	_hover_label.add_theme_color_override(&"font_color", Color("#f3dea2"))
	_hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_hover_label)

	var hint: Label = Label.new()
	hint.text = "滚轮缩放　·　按住左键拖动地图　·　单击定位且保持打开　·　按 M 关闭"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override(&"font_size", 11)
	hint.add_theme_color_override(&"font_color", Color("#b8cbbd"))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(hint)

func _on_world_selected(world_position: Vector2) -> void:
	camera_jump_requested.emit(world_position)

func _on_hover_changed(detail_text: String) -> void:
	_hover_label.text = detail_text if not detail_text.is_empty() else "悬停图标查看名称、阵营、生命和状态"

func _on_summary_changed(summary_text: String) -> void:
	_summary_label.text = summary_text

func _add_legend_item(parent: HBoxContainer, glyph: String, label_text: String, color: Color) -> void:
	var label: Label = Label.new()
	label.text = "%s %s" % [glyph, label_text]
	label.add_theme_font_size_override(&"font_size", 10)
	label.add_theme_color_override(&"font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)

func _make_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("#10211ef5")
	style.border_color = Color("#d7b76b")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	return style

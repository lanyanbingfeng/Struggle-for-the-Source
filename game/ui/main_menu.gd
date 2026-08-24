class_name MainMenu
extends CanvasLayer

signal start_requested(multiplayer_mode: bool)

const BACKGROUND_TEXTURE: Texture2D = preload("res://art/ui/main_menu_background.png")
const MENU_WIDTH: float = 270.0
const MENU_TOP: float = 52.0

var _root: Control
var _menu_panel: PanelContainer
var _modal_layer: Control
var _modal_panel: Panel
var _modal_title: Label
var _modal_body: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = true

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.resized.connect(_layout_ui)

	var background: TextureRect = TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = BACKGROUND_TEXTURE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(background)

	var screen_tint: ColorRect = ColorRect.new()
	screen_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_tint.color = Color("#07141aa8")
	screen_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(screen_tint)

	var left_shade: ColorRect = ColorRect.new()
	left_shade.position = Vector2.ZERO
	left_shade.size = Vector2(340.0, 480.0)
	left_shade.color = Color("#071218d9")
	left_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(left_shade)

	_menu_panel = PanelContainer.new()
	_menu_panel.position = Vector2(30.0, MENU_TOP)
	_menu_panel.size = Vector2(MENU_WIDTH, 370.0)
	_menu_panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#10211ed6"), Color("#d7b76b"), 2))
	_root.add_child(_menu_panel)

	var menu_margin: MarginContainer = MarginContainer.new()
	menu_margin.add_theme_constant_override("margin_left", 18)
	menu_margin.add_theme_constant_override("margin_top", 17)
	menu_margin.add_theme_constant_override("margin_right", 18)
	menu_margin.add_theme_constant_override("margin_bottom", 16)
	_menu_panel.add_child(menu_margin)

	var menu_column: VBoxContainer = VBoxContainer.new()
	menu_column.add_theme_constant_override("separation", 8)
	menu_margin.add_child(menu_column)

	var eyebrow: Label = _make_label("FRONTIER  //  ALPHA", 10, Color("#d3b96f"))
	eyebrow.add_theme_constant_override("outline_size", 3)
	menu_column.add_child(eyebrow)

	var title: Label = _make_label("争源", 42, Color("#fff0bc"))
	title.add_theme_color_override("font_shadow_color", Color("#061014b8"))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	menu_column.add_child(title)

	var subtitle: Label = _make_label("在荒野中建立你的新秩序", 13, Color("#bdd0bb"))
	menu_column.add_child(subtitle)

	var rule: ColorRect = ColorRect.new()
	rule.custom_minimum_size = Vector2(0.0, 2.0)
	rule.color = Color("#d7b76b99")
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_column.add_child(rule)

	var menu_hint: Label = _make_label("选择你的远征方式", 11, Color("#829b91"))
	menu_column.add_child(menu_hint)

	var single_player: Button = _make_menu_button("单人游戏", true)
	single_player.pressed.connect(_on_single_player_pressed)
	menu_column.add_child(single_player)

	var multiplayer_button: Button = _make_menu_button("多人游戏", false)
	multiplayer_button.pressed.connect(_on_multiplayer_pressed)
	menu_column.add_child(multiplayer_button)

	var settings: Button = _make_menu_button("设置", false)
	settings.pressed.connect(_on_settings_pressed)
	menu_column.add_child(settings)

	var about: Button = _make_menu_button("关于", false)
	about.pressed.connect(_on_about_pressed)
	menu_column.add_child(about)

	var exit_game: Button = _make_menu_button("退出游戏", false)
	exit_game.pressed.connect(_on_exit_pressed)
	menu_column.add_child(exit_game)

	var footer: Label = _make_label("鼠标选择  ·  Esc 打开游戏菜单", 10, Color("#789087"))
	footer.custom_minimum_size = Vector2(0.0, 24.0)
	footer.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	menu_column.add_child(footer)

	var build_label: Label = _make_label("BUILD 0.1  /  争源计划", 9, Color("#50685f"))
	build_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	menu_column.add_child(build_label)

	_build_modal()
	_layout_ui()

func _build_modal() -> void:
	_modal_layer = Control.new()
	_modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_modal_layer)

	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color("#040a0ccc")
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_layer.add_child(shade)

	_modal_panel = Panel.new()
	_modal_panel.size = Vector2(350.0, 230.0)
	_modal_panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#10211ef5"), Color("#d7b76b"), 2))
	_modal_layer.add_child(_modal_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	_modal_panel.add_child(margin)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	_modal_title = _make_label("", 22, Color("#fff0bc"))
	column.add_child(_modal_title)

	_modal_body = _make_label("", 12, Color("#bdd0bb"))
	_modal_body.custom_minimum_size = Vector2(0.0, 82.0)
	_modal_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_modal_body)

	var close_button: Button = _make_menu_button("返回", false)
	close_button.pressed.connect(_hide_modal)
	column.add_child(close_button)

	_modal_layer.hide()

func _layout_ui() -> void:
	if not is_instance_valid(_root):
		return
	var viewport_size: Vector2 = _root.size
	var left_shade: ColorRect = _root.get_child(2) as ColorRect
	if left_shade != null:
		left_shade.size = Vector2(minf(340.0, viewport_size.x * 0.55), viewport_size.y)
	if is_instance_valid(_menu_panel):
		_menu_panel.position = Vector2(30.0, MENU_TOP)
		_menu_panel.size = Vector2(MENU_WIDTH, minf(370.0, maxf(340.0, viewport_size.y - MENU_TOP - 28.0)))
	if is_instance_valid(_modal_panel):
		_modal_panel.position = (viewport_size - _modal_panel.size) / 2.0

func _make_label(text_value: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _make_menu_button(text_value: String, primary: bool) -> Button:
	var button: Button = Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0.0, 34.0 if primary else 30.0)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.add_theme_font_size_override("font_size", 14 if primary else 12)
	button.add_theme_color_override("font_color", Color("#fff2c4"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color("#ffe28d"))
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _make_button_style(Color("#27433bcf"), Color("#5d7f6b")))
	button.add_theme_stylebox_override("hover", _make_button_style(Color("#426653ef"), Color("#f0cf78")))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color("#1b302bd9"), Color("#fff0b0")))
	button.add_theme_stylebox_override("focus", _make_button_style(Color("#426653ef"), Color("#fff0b0")))
	return button

func _make_button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	return style

func _make_panel_style(background: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(5)
	return style

func _on_single_player_pressed() -> void:
	start_requested.emit(false)

func _on_multiplayer_pressed() -> void:
	start_requested.emit(true)

func _on_settings_pressed() -> void:
	_show_modal("设置", "当前版本保留像素风显示与基础操作配置。\n\n进入游戏后按 Esc 可打开游戏菜单；单人模式会暂停时间，多人模式不会暂停。")

func _on_about_pressed() -> void:
	_show_modal("关于争源", "《争源》是一款 2D 像素风俯视角策略与资源经营原型。\n\n在荒野中建立基地、收集资源，并逐步扩张你的势力。\n\n当前版本：基础交互原型")

func _on_exit_pressed() -> void:
	get_tree().quit()

func _show_modal(title_text: String, body_text: String) -> void:
	_modal_title.text = title_text
	_modal_body.text = body_text
	_modal_layer.show()
	_layout_ui()

func _hide_modal() -> void:
	_modal_layer.hide()

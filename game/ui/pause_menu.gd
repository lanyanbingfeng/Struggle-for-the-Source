class_name PauseMenu
extends CanvasLayer

signal return_to_main_menu

var _root: Control
var _menu_panel: PanelContainer
var _status_label: Label
var _modal_layer: Control
var _modal_panel: Panel
var _modal_title: Label
var _modal_body: Label
var _resume_button: Button
var _multiplayer_mode: bool = false
var _menu_open: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false

func configure(multiplayer_mode: bool) -> void:
	_multiplayer_mode = multiplayer_mode
	if is_instance_valid(_status_label):
		_status_label.text = _get_mode_status()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		if _modal_layer.visible:
			_hide_modal()
		else:
			toggle_menu()
		get_viewport().set_input_as_handled()

func toggle_menu() -> void:
	if _menu_open:
		close_menu()
	else:
		open_menu()

func open_menu() -> void:
	if _menu_open:
		return
	_menu_open = true
	visible = true
	_root.show()
	_status_label.text = _get_mode_status()
	if not _multiplayer_mode:
		get_tree().paused = true
	_resume_button.grab_focus()

func close_menu() -> void:
	if not _menu_open:
		return
	_menu_open = false
	_modal_layer.hide()
	_root.hide()
	if not _multiplayer_mode:
		get_tree().paused = false

func force_close() -> void:
	_menu_open = false
	_modal_layer.hide()
	_root.hide()

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.resized.connect(_layout_ui)

	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color("#020607b8")
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(shade)

	_menu_panel = PanelContainer.new()
	_menu_panel.size = Vector2(310.0, 330.0)
	_menu_panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#10211ef5"), Color("#d7b76b"), 2))
	_root.add_child(_menu_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	_menu_panel.add_child(margin)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	margin.add_child(column)

	var eyebrow: Label = _make_label("GAME MENU", 10, Color("#d3b96f"))
	column.add_child(eyebrow)

	var title: Label = _make_label("游戏菜单", 25, Color("#fff0bc"))
	column.add_child(title)

	_status_label = _make_label(_get_mode_status(), 11, Color("#9fb8a4"))
	column.add_child(_status_label)

	var rule: ColorRect = ColorRect.new()
	rule.custom_minimum_size = Vector2(0.0, 2.0)
	rule.color = Color("#d7b76b99")
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule)

	_resume_button = _make_menu_button("返回游戏", true)
	_resume_button.pressed.connect(close_menu)
	column.add_child(_resume_button)

	var settings_button: Button = _make_menu_button("设置", false)
	settings_button.pressed.connect(_on_settings_pressed)
	column.add_child(settings_button)

	var main_menu_button: Button = _make_menu_button("返回主菜单", false)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	column.add_child(main_menu_button)

	var exit_button: Button = _make_menu_button("退出游戏", false)
	exit_button.pressed.connect(_on_exit_pressed)
	column.add_child(exit_button)

	var hint: Label = _make_label("Esc 关闭菜单", 10, Color("#789087"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(hint)

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
	if not is_instance_valid(_root) or not is_instance_valid(_menu_panel):
		return
	var viewport_size: Vector2 = _root.size
	_menu_panel.position = (viewport_size - _menu_panel.size) / 2.0
	if is_instance_valid(_modal_panel):
		_modal_panel.position = (viewport_size - _modal_panel.size) / 2.0

func _get_mode_status() -> String:
	if _multiplayer_mode:
		return "多人模式  ·  菜单打开时游戏继续"
	return "单人模式  ·  菜单打开时游戏暂停"

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

func _on_settings_pressed() -> void:
	_show_modal("设置", "当前版本使用像素风显示和基础 UI 配置。\n\n单人游戏：打开菜单时暂停世界。\n多人游戏：打开菜单时世界继续运行。")

func _on_main_menu_pressed() -> void:
	close_menu()
	return_to_main_menu.emit()

func _on_exit_pressed() -> void:
	get_tree().quit()

func _show_modal(title_text: String, body_text: String) -> void:
	_modal_title.text = title_text
	_modal_body.text = body_text
	_modal_layer.show()
	_layout_ui()

func _hide_modal() -> void:
	_modal_layer.hide()

class_name DeveloperPanel
extends CanvasLayer

signal full_vision_changed(enabled: bool)
signal ai_paused_changed(paused: bool)

var _toggle: CheckButton
var _ai_toggle: CheckButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -178.0
	panel.offset_top = 12.0
	panel.offset_right = -12.0
	panel.offset_bottom = 88.0
	panel.custom_minimum_size = Vector2(184.0, 76.0)
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 2)
	margin.add_child(column)
	_toggle = CheckButton.new()
	_toggle.text = "开发者：显示全图"
	_toggle.add_theme_font_size_override("font_size", 11)
	_toggle.toggled.connect(_on_toggled)
	column.add_child(_toggle)
	_ai_toggle = CheckButton.new()
	_ai_toggle.text = "开发者：暂停人机"
	_ai_toggle.add_theme_font_size_override(&"font_size", 11)
	_ai_toggle.toggled.connect(_on_ai_toggled)
	column.add_child(_ai_toggle)
	hide()

func reset() -> void:
	_toggle.set_pressed_no_signal(false)
	_ai_toggle.set_pressed_no_signal(false)
	full_vision_changed.emit(false)
	ai_paused_changed.emit(false)

func _on_toggled(enabled: bool) -> void:
	full_vision_changed.emit(enabled)

func _on_ai_toggled(paused: bool) -> void:
	ai_paused_changed.emit(paused)

func _make_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("#231b18e8")
	style.border_color = Color("#d56b5d")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style

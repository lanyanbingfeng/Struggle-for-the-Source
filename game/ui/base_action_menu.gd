class_name BaseActionMenu
extends CanvasLayer

signal action_selected(action_id: StringName)

const BUTTON_TEXTURE: Texture2D = preload("res://art/ui/ui_base_action_button.png")
const BUTTON_SIZE: Vector2 = Vector2(66.0, 24.0)
const MENU_GAP: float = 16.0
const BUTTON_GAP: float = 6.0
const BUTTON_POP_SCALE: float = 0.2
const BUTTON_POP_DURATION: float = 0.2

@onready var backdrop: Button = %Backdrop
@onready var button_list: Control = %ButtonList

var _base_screen_position: Vector2 = Vector2.ZERO
var _follow_target: Node2D
var _screen_offset: Vector2 = Vector2.ZERO
var _menu_size: Vector2 = Vector2.ZERO
var _open_tween: Tween
var _action_configs: Array[Dictionary] = []

func _ready() -> void:
	backdrop.set_meta(&"allow_edge_scroll", true)
	backdrop.pressed.connect(close)
	visible = false
	_show_main_actions()
	_rebuild_buttons()

func _process(_delta: float) -> void:
	if not visible:
		return
	if not is_instance_valid(_follow_target):
		close()
		return
	var current_screen_position: Vector2 = _target_screen_position()
	if not current_screen_position.is_equal_approx(_base_screen_position):
		_base_screen_position = current_screen_position
		_position_menu()

func open_for(target: Node2D, screen_offset: Vector2 = Vector2.ZERO) -> void:
	_follow_target = target
	_screen_offset = screen_offset
	_base_screen_position = _target_screen_position()
	_show_main_actions()
	_rebuild_buttons()
	_reposition_menu()
	visible = true
	_play_open_animation()

func close() -> void:
	if is_instance_valid(_open_tween):
		_open_tween.kill()
	visible = false
	_follow_target = null

func toggle_for(target: Node2D, screen_offset: Vector2 = Vector2.ZERO) -> void:
	if visible and _follow_target == target:
		close()
	else:
		open_for(target, screen_offset)

func set_action_configs(configs: Array[Dictionary]) -> void:
	_action_configs = configs
	_rebuild_buttons()

func _rebuild_buttons() -> void:
	if not is_node_ready():
		return
	for child: Node in button_list.get_children():
		button_list.remove_child(child)
		child.queue_free()
	for config: Dictionary in _action_configs:
		var button: Button = _create_action_button(config)
		button_list.add_child(button)

func _create_action_button(config: Dictionary) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = BUTTON_SIZE
	button.size = BUTTON_SIZE
	button.text = str(config.get("text", ""))
	button.tooltip_text = str(config.get("tooltip", ""))
	button.disabled = bool(config.get("disabled", false))
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color("#fff4c4"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color("#ffe89a"))
	button.add_theme_color_override("font_disabled_color", Color("#8f8f8f"))
	button.add_theme_stylebox_override("normal", _make_button_style(Color.WHITE))
	button.add_theme_stylebox_override("hover", _make_button_style(Color("#fff2bf")))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color("#d7e8a2")))
	button.add_theme_stylebox_override("disabled", _make_button_style(Color("#777777")))
	var action_id: StringName = StringName(str(config.get("action", config.get("id", ""))))
	button.pressed.connect(_on_action_button_pressed.bind(action_id))
	return button

func _make_button_style(_tint: Color) -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = BUTTON_TEXTURE
	style.texture_margin_left = 8.0
	style.texture_margin_top = 8.0
	style.texture_margin_right = 8.0
	style.texture_margin_bottom = 8.0
	return style

func _on_action_button_pressed(action_id: StringName) -> void:
	action_selected.emit(action_id)
	print("基地操作: ", action_id)
	close()

func _show_main_actions() -> void:
	_action_configs = [
		{"id": &"recruit", "text": "招募", "action": &"recruit", "disabled": false},
		{
			"id": &"summon",
			"text": "召唤",
			"action": &"summon",
			"disabled": false,
			"tooltip": "消耗10金币召唤一次\n费用支付后不可退还",
		},
		{"id": &"upgrade", "text": "升级", "action": &"upgrade", "disabled": false},
	]

func set_summon_tooltip(tooltip: String) -> void:
	_set_action_tooltip(&"summon", tooltip)

func set_upgrade_tooltip(tooltip: String) -> void:
	_set_action_tooltip(&"upgrade", tooltip)

func _set_action_tooltip(action_id: StringName, tooltip: String) -> void:
	for config: Dictionary in _action_configs:
		if StringName(str(config.get("action", ""))) == action_id:
			config["tooltip"] = tooltip
	_rebuild_buttons()
	if visible:
		_reposition_menu()

func _reposition_menu() -> void:
	_menu_size = _layout_buttons()
	button_list.size = _menu_size
	button_list.pivot_offset = _menu_size / 2.0
	_position_menu()

func _position_menu() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var menu_position: Vector2 = Vector2(
		_base_screen_position.x - _menu_size.x / 2.0,
		_base_screen_position.y - _menu_size.y - MENU_GAP
	)
	menu_position.x = clampf(menu_position.x, 8.0, maxf(8.0, viewport_size.x - _menu_size.x - 8.0))
	menu_position.y = clampf(menu_position.y, 8.0, maxf(8.0, viewport_size.y - _menu_size.y - 8.0))
	button_list.position = menu_position

func _target_screen_position() -> Vector2:
	if not is_instance_valid(_follow_target):
		return Vector2.ZERO
	return _follow_target.get_global_transform_with_canvas().origin + _screen_offset

func _layout_buttons() -> Vector2:
	var button_count: int = button_list.get_child_count()
	if button_count == 0:
		return Vector2.ZERO
	var menu_size: Vector2 = Vector2.ZERO
	for index: int in button_count:
		var button: Control = button_list.get_child(index) as Control
		menu_size.x += button.size.x
		menu_size.y = maxf(menu_size.y, button.size.y)
	if button_count > 1:
		menu_size.x += BUTTON_GAP * float(button_count - 1)
	var x: float = 0.0
	for index: int in button_count:
		var button: Control = button_list.get_child(index) as Control
		button.position = Vector2(x, (menu_size.y - button.size.y) / 2.0)
		x += button.size.x + BUTTON_GAP
	return menu_size

func _play_open_animation() -> void:
	if is_instance_valid(_open_tween):
		_open_tween.kill()
	_open_tween = create_tween()
	_open_tween.set_parallel(false)
	for index: int in button_list.get_child_count():
		var button: Control = button_list.get_child(index) as Control
		var target_position: Vector2 = button.position
		var base_local_position: Vector2 = _base_screen_position - button_list.position
		var start_position: Vector2 = base_local_position - button.size / 2.0
		button.pivot_offset = button.size / 2.0
		button.position = start_position
		button.scale = Vector2.ONE * BUTTON_POP_SCALE
		_open_tween.parallel().tween_property(button, "position", target_position, BUTTON_POP_DURATION).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
		_open_tween.parallel().tween_property(button, "scale", Vector2.ONE, BUTTON_POP_DURATION).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)

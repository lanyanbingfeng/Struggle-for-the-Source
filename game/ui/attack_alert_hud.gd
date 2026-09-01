class_name AttackAlertHud
extends CanvasLayer

signal focus_requested(world_position: Vector2)

const ALERT_LIFETIME_MSEC: int = 6500
const MAX_ALERTS: int = 4

var _available: bool = false
var _root: Control
var _stack: VBoxContainer
var _alerts: Dictionary[int, Dictionary] = {}

func _ready() -> void:
	layer = 45
	_build_ui()
	set_process(false)
	hide()

func set_available(available: bool) -> void:
	_available = available
	if available:
		show()
	else:
		clear_alerts()
		hide()

func show_attack_alert(
	target_unit_id: int,
	target_name: String,
	source_description: String,
	damage: float,
	world_position: Vector2
) -> void:
	if not _available or target_unit_id <= 0:
		return
	var now_msec: int = Time.get_ticks_msec()
	var entry: Dictionary = _alerts.get(target_unit_id, {}) as Dictionary
	if entry.is_empty() or not is_instance_valid(entry.get("button") as Button):
		entry = _create_alert(target_unit_id)
		_alerts[target_unit_id] = entry
	entry["target_name"] = target_name
	entry["source"] = source_description
	entry["damage"] = damage
	entry["position"] = world_position
	entry["count"] = int(entry.get("count", 0)) + 1
	entry["expires"] = now_msec + ALERT_LIFETIME_MSEC
	_alerts[target_unit_id] = entry
	_refresh_alert_text(entry)
	var button: Button = entry.get("button") as Button
	_stack.move_child(button, 0)
	_trim_alerts()
	set_process(true)

func clear_alerts() -> void:
	for entry: Dictionary in _alerts.values():
		var button: Button = entry.get("button") as Button
		if is_instance_valid(button):
			button.queue_free()
	_alerts.clear()
	set_process(false)

func get_alert_count() -> int:
	return _alerts.size()

func _process(_delta: float) -> void:
	var now_msec: int = Time.get_ticks_msec()
	for target_unit_id: int in _alerts.keys():
		var entry: Dictionary = _alerts[target_unit_id]
		if now_msec >= int(entry.get("expires", 0)):
			_remove_alert(target_unit_id)
	if _alerts.is_empty():
		set_process(false)

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_stack = VBoxContainer.new()
	_stack.set_anchor(SIDE_LEFT, 1.0)
	_stack.set_anchor(SIDE_TOP, 1.0)
	_stack.set_anchor(SIDE_RIGHT, 1.0)
	_stack.set_anchor(SIDE_BOTTOM, 1.0)
	_stack.offset_left = -346.0
	_stack.offset_top = -310.0
	_stack.offset_right = -12.0
	_stack.offset_bottom = -12.0
	_stack.alignment = BoxContainer.ALIGNMENT_END
	_stack.add_theme_constant_override(&"separation", 7)
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_stack)

func _create_alert(target_unit_id: int) -> Dictionary:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(330.0, 66.0)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override(&"font_size", 12)
	button.add_theme_color_override(&"font_color", Color("#fff2de"))
	button.add_theme_color_override(&"font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override(&"normal", _make_alert_style(Color("#4a1612ee"), Color("#e85a45")))
	button.add_theme_stylebox_override(&"hover", _make_alert_style(Color("#6a2019f5"), Color("#ffb05c")))
	button.add_theme_stylebox_override(&"pressed", _make_alert_style(Color("#32100ee8"), Color("#ffe09a")))
	button.add_theme_stylebox_override(&"focus", _make_alert_style(Color("#6a2019f5"), Color("#ffe09a")))
	button.pressed.connect(_on_alert_pressed.bind(target_unit_id))
	_stack.add_child(button)
	return {"button": button, "count": 0}

func _refresh_alert_text(entry: Dictionary) -> void:
	var button: Button = entry.get("button") as Button
	if not is_instance_valid(button):
		return
	var repeat_text: String = "　连续 %d 次" % int(entry.get("count", 1)) if int(entry.get("count", 1)) > 1 else ""
	button.text = "⚠ 单位遭到攻击%s\n%s受到：%s，损失 %.0f 生命　｜　点击前往" % [
		repeat_text,
		str(entry.get("target_name", "单位")),
		str(entry.get("source", "未知攻击")),
		float(entry.get("damage", 0.0)),
	]

func _trim_alerts() -> void:
	while _alerts.size() > MAX_ALERTS:
		var oldest_id: int = 0
		var oldest_expiry: int = 0x7FFFFFFF
		for target_unit_id: int in _alerts.keys():
			var expiry: int = int((_alerts[target_unit_id] as Dictionary).get("expires", 0))
			if expiry < oldest_expiry:
				oldest_expiry = expiry
				oldest_id = target_unit_id
		_remove_alert(oldest_id)

func _on_alert_pressed(target_unit_id: int) -> void:
	var entry: Dictionary = _alerts.get(target_unit_id, {}) as Dictionary
	if entry.is_empty():
		return
	focus_requested.emit(entry.get("position", Vector2.ZERO) as Vector2)
	_remove_alert(target_unit_id)

func _remove_alert(target_unit_id: int) -> void:
	var entry: Dictionary = _alerts.get(target_unit_id, {}) as Dictionary
	var button: Button = entry.get("button") as Button
	if is_instance_valid(button):
		button.queue_free()
	_alerts.erase(target_unit_id)

func _make_alert_style(background: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.content_margin_left = 12.0
	style.content_margin_right = 10.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	return style

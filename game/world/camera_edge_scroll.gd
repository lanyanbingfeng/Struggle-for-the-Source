class_name EdgeScrollCamera
extends Camera2D

@export_range(0.05, 0.25, 0.01) var edge_margin_ratio: float = 0.12
@export var scroll_speed: float = 600.0
@export_range(0.1, 1.0, 0.05) var minimum_zoom: float = 0.35
@export_range(1.0, 4.0, 0.05) var maximum_zoom: float = 1.5
@export_range(1.01, 1.5, 0.01) var zoom_step: float = 1.1
@export var map_size: Vector2 = Vector2(3200.0, 3200.0)

func _ready() -> void:
	position = _clamped_position(position)

func _process(delta: float) -> void:
	if not enabled:
		return
	if _is_pointer_over_ui():
		return

	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	var edge_size: Vector2 = viewport_size * edge_margin_ratio
	var edge_strength: Vector2 = _get_edge_strength(mouse_position, viewport_size, edge_size)
	if edge_strength == Vector2.ZERO:
		return

	var movement: Vector2 = edge_strength * scroll_speed * delta
	position = _clamped_position(position + movement)

func _unhandled_input(event: InputEvent) -> void:
	if not enabled or not is_processing() or _is_pointer_over_ui():
		return
	if not event is InputEventMouseButton:
		return

	var mouse_event: InputEventMouseButton = event
	if not mouse_event.pressed:
		return
	if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_zoom_at_pointer(zoom_step)
	elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_zoom_at_pointer(1.0 / zoom_step)
	else:
		return
	get_viewport().set_input_as_handled()

func _zoom_at_pointer(factor: float) -> void:
	var world_position_before_zoom: Vector2 = get_global_mouse_position()
	var target_zoom_value: float = clampf(zoom.x * factor, minimum_zoom, maximum_zoom)
	if is_equal_approx(target_zoom_value, zoom.x):
		return

	zoom = Vector2.ONE * target_zoom_value
	var world_position_after_zoom: Vector2 = get_global_mouse_position()
	position = _clamped_position(position + world_position_before_zoom - world_position_after_zoom)

func jump_to_world_position(world_position: Vector2) -> void:
	position = _clamped_position(world_position)

func _get_edge_strength(mouse_position: Vector2, viewport_size: Vector2, edge_size: Vector2) -> Vector2:
	var strength: Vector2 = Vector2.ZERO
	if mouse_position.x < edge_size.x:
		strength.x = -_smooth_edge_strength(mouse_position.x / edge_size.x)
	elif mouse_position.x > viewport_size.x - edge_size.x:
		strength.x = _smooth_edge_strength((viewport_size.x - mouse_position.x) / edge_size.x)

	if mouse_position.y < edge_size.y:
		strength.y = -_smooth_edge_strength(mouse_position.y / edge_size.y)
	elif mouse_position.y > viewport_size.y - edge_size.y:
		strength.y = _smooth_edge_strength((viewport_size.y - mouse_position.y) / edge_size.y)
	return strength

func _smooth_edge_strength(distance_ratio: float) -> float:
	return 1.0 - smoothstep(0.0, 1.0, clampf(distance_ratio, 0.0, 1.0))

func _clamped_position(target_position: Vector2) -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var half_view_size: Vector2 = viewport_size / (2.0 * zoom)
	return Vector2(
		_clamp_axis(target_position.x, half_view_size.x, map_size.x - half_view_size.x, map_size.x / 2.0),
		_clamp_axis(target_position.y, half_view_size.y, map_size.y - half_view_size.y, map_size.y / 2.0)
	)

func _clamp_axis(value: float, minimum: float, maximum: float, center: float) -> float:
	if minimum > maximum:
		return center
	return clampf(value, minimum, maximum)

func _is_pointer_over_ui() -> bool:
	var hovered_control: Control = get_viewport().gui_get_hovered_control()
	if hovered_control == null or not hovered_control.is_visible_in_tree():
		return false
	return _control_blocks_edge_scroll(hovered_control)

func _control_blocks_edge_scroll(control: Control) -> bool:
	if control == null:
		return false
	var current: Node = control
	while current is Control:
		if bool(current.get_meta(&"allow_edge_scroll", false)):
			return false
		current = current.get_parent()
	return true

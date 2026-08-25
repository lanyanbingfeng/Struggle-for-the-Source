class_name EdgeScrollCamera
extends Camera2D

@export_range(0.05, 0.25, 0.01) var edge_margin_ratio: float = 0.12
@export var scroll_speed: float = 600.0
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

class_name WorldCommandOverlay
extends Node2D

var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _drag_end: Vector2 = Vector2.ZERO
var _marker_position: Vector2 = Vector2.ZERO
var _marker_time: float = 0.0
var _attack_target: Node2D
var _attack_target_radius: float = 18.0
var _attack_pulse_time: float = 0.0
var _build_preview_rect: Rect2 = Rect2()
var _build_preview_visible: bool = false
var _build_preview_valid: bool = true
var _enemy_spawn_preview_rect: Rect2 = Rect2()
var _enemy_spawn_preview_visible: bool = false
var _enemy_spawn_preview_valid: bool = true
var _enemy_spawn_preview_is_boss: bool = false

func _ready() -> void:
	z_index = 900

func begin_drag(world_position: Vector2) -> void:
	_dragging = true
	_drag_start = world_position
	_drag_end = world_position
	queue_redraw()

func update_drag(world_position: Vector2) -> void:
	if not _dragging:
		return
	_drag_end = world_position
	queue_redraw()

func end_drag() -> Rect2:
	_dragging = false
	queue_redraw()
	return Rect2(_drag_start, _drag_end - _drag_start).abs()

func show_move_marker(world_position: Vector2) -> void:
	_marker_position = world_position
	_marker_time = 0.55
	set_process(true)
	queue_redraw()

func show_attack_target(target: Node2D, radius: float) -> void:
	_attack_target = target
	_attack_target_radius = maxf(18.0, radius)
	_attack_pulse_time = 0.0
	set_process(true)
	queue_redraw()

func clear_attack_target() -> void:
	_attack_target = null
	queue_redraw()
	if _marker_time <= 0.0:
		set_process(false)

func show_build_preview(cell_rect: Rect2i, tile_size: int, is_valid: bool = true) -> void:
	_build_preview_rect = Rect2(Vector2(cell_rect.position * tile_size), Vector2(cell_rect.size * tile_size))
	_build_preview_visible = true
	_build_preview_valid = is_valid
	queue_redraw()

func hide_build_preview() -> void:
	_build_preview_visible = false
	queue_redraw()

func show_enemy_spawn_preview(cell_rect: Rect2i, tile_size: int, is_valid: bool, is_boss: bool) -> void:
	_enemy_spawn_preview_rect = Rect2(Vector2(cell_rect.position * tile_size), Vector2(cell_rect.size * tile_size))
	_enemy_spawn_preview_visible = true
	_enemy_spawn_preview_valid = is_valid
	_enemy_spawn_preview_is_boss = is_boss
	queue_redraw()

func hide_enemy_spawn_preview() -> void:
	_enemy_spawn_preview_visible = false
	queue_redraw()

func _process(delta: float) -> void:
	_marker_time = maxf(0.0, _marker_time - delta)
	_attack_pulse_time += delta
	if not is_instance_valid(_attack_target):
		_attack_target = null
	queue_redraw()
	if _marker_time <= 0.0 and _attack_target == null:
		set_process(false)

func _draw() -> void:
	if _enemy_spawn_preview_visible:
		var spawn_color: Color = Color("#ff5f62")
		if _enemy_spawn_preview_valid:
			spawn_color = Color("#f0b94f") if _enemy_spawn_preview_is_boss else Color("#b776ff")
		draw_rect(_enemy_spawn_preview_rect, Color(spawn_color, 0.22), true)
		draw_rect(_enemy_spawn_preview_rect, spawn_color, false, 5.0)
		var spawn_center: Vector2 = _enemy_spawn_preview_rect.get_center()
		draw_circle(spawn_center, minf(_enemy_spawn_preview_rect.size.x, _enemy_spawn_preview_rect.size.y) * 0.32, Color(spawn_color, 0.18), true)
		draw_circle(spawn_center, minf(_enemy_spawn_preview_rect.size.x, _enemy_spawn_preview_rect.size.y) * 0.32, spawn_color, false, 3.0)
		draw_line(_enemy_spawn_preview_rect.position, _enemy_spawn_preview_rect.end, Color(spawn_color, 0.72), 2.0)
		draw_line(Vector2(_enemy_spawn_preview_rect.end.x, _enemy_spawn_preview_rect.position.y), Vector2(_enemy_spawn_preview_rect.position.x, _enemy_spawn_preview_rect.end.y), Color(spawn_color, 0.72), 2.0)
	if _build_preview_visible:
		var preview_color: Color = Color("#62dc78") if _build_preview_valid else Color("#ff5f62")
		draw_rect(_build_preview_rect, Color(preview_color, 0.18), true)
		draw_rect(_build_preview_rect, preview_color, false, 4.0)
		var center: Vector2 = _build_preview_rect.get_center()
		draw_line(Vector2(_build_preview_rect.position.x, center.y), Vector2(_build_preview_rect.end.x, center.y), Color(preview_color, 0.55), 2.0)
		draw_line(Vector2(center.x, _build_preview_rect.position.y), Vector2(center.x, _build_preview_rect.end.y), Color(preview_color, 0.55), 2.0)
	if _dragging:
		var drag_rect: Rect2 = Rect2(_drag_start, _drag_end - _drag_start).abs()
		draw_rect(drag_rect, Color("#d95d5050"), true)
		draw_rect(drag_rect, Color("#ff7968"), false, 2.0)
	if _marker_time > 0.0:
		var progress: float = 1.0 - _marker_time / 0.55
		var radius: float = lerpf(7.0, 19.0, progress)
		var alpha: float = 1.0 - progress
		draw_circle(_marker_position, radius, Color(0.9, 0.25, 0.18, alpha), false, 2.0)
	if is_instance_valid(_attack_target):
		var target_position: Vector2 = to_local(_attack_target.global_position)
		var pulse: float = sin(_attack_pulse_time * 6.0) * 2.0
		var radius: float = _attack_target_radius + pulse
		draw_circle(target_position, radius, Color("#ffca5cdd"), false, 3.0, true)
		draw_arc(target_position, radius + 6.0, -0.85, 0.15, 10, Color("#ff684fcc"), 3.0, true)
		draw_arc(target_position, radius + 6.0, PI - 0.85, PI + 0.15, 10, Color("#ff684fcc"), 3.0, true)

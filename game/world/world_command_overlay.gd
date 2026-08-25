class_name WorldCommandOverlay
extends Node2D

var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _drag_end: Vector2 = Vector2.ZERO
var _marker_position: Vector2 = Vector2.ZERO
var _marker_time: float = 0.0
var _build_preview_rect: Rect2 = Rect2()
var _build_preview_visible: bool = false

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

func show_build_preview(cell_rect: Rect2i, tile_size: int) -> void:
	_build_preview_rect = Rect2(Vector2(cell_rect.position * tile_size), Vector2(cell_rect.size * tile_size))
	_build_preview_visible = true
	queue_redraw()

func hide_build_preview() -> void:
	_build_preview_visible = false
	queue_redraw()

func _process(delta: float) -> void:
	_marker_time = maxf(0.0, _marker_time - delta)
	queue_redraw()
	if _marker_time <= 0.0:
		set_process(false)

func _draw() -> void:
	if _build_preview_visible:
		draw_rect(_build_preview_rect, Color("#ffd16624"), true)
		draw_rect(_build_preview_rect, Color("#ffd166"), false, 4.0)
		var center: Vector2 = _build_preview_rect.get_center()
		draw_line(Vector2(_build_preview_rect.position.x, center.y), Vector2(_build_preview_rect.end.x, center.y), Color("#ffd16688"), 2.0)
		draw_line(Vector2(center.x, _build_preview_rect.position.y), Vector2(center.x, _build_preview_rect.end.y), Color("#ffd16688"), 2.0)
	if _dragging:
		var drag_rect: Rect2 = Rect2(_drag_start, _drag_end - _drag_start).abs()
		draw_rect(drag_rect, Color("#d95d5050"), true)
		draw_rect(drag_rect, Color("#ff7968"), false, 2.0)
	if _marker_time > 0.0:
		var progress: float = 1.0 - _marker_time / 0.55
		var radius: float = lerpf(7.0, 19.0, progress)
		var alpha: float = 1.0 - progress
		draw_circle(_marker_position, radius, Color(0.9, 0.25, 0.18, alpha), false, 2.0)

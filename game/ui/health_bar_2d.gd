class_name HealthBar2D
extends Node2D

var _health: HealthComponent
var _bar_width: float = 30.0
var _bar_height: float = 4.0

func bind(component: HealthComponent, world_offset: Vector2, width: float = 30.0) -> void:
	_health = component
	position = world_offset
	_bar_width = width
	_bar_height = 5.0 if width >= 42.0 else 4.0
	if not _health.state_changed.is_connected(_on_state_changed):
		_health.state_changed.connect(_on_state_changed)
	queue_redraw()

func _on_state_changed(_health_value: float, _max_health: float, _mana_value: float, _max_mana: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(_health):
		return
	var start := Vector2(-_bar_width * 0.5, 0.0)
	draw_rect(Rect2(start - Vector2.ONE, Vector2(_bar_width + 2.0, _bar_height + 2.0)), Color("#1a120ddd"), true)
	draw_rect(Rect2(start, Vector2(_bar_width, _bar_height)), Color("#6b1f24"), true)
	var health_ratio := clampf(_health.get_health_ratio(), 0.0, 1.0)
	var health_color := Color("#70cf62") if health_ratio > 0.35 else Color("#efb84a")
	draw_rect(Rect2(start, Vector2(_bar_width * health_ratio, _bar_height)), health_color, true)
	if _health.max_mana > 0.0:
		var mana_ratio := clampf(_health.current_mana / _health.max_mana, 0.0, 1.0)
		draw_rect(Rect2(start + Vector2(0.0, _bar_height + 2.0), Vector2(_bar_width, 2.0)), Color("#17243d"), true)
		draw_rect(Rect2(start + Vector2(0.0, _bar_height + 2.0), Vector2(_bar_width * mana_ratio, 2.0)), Color("#4f92e8"), true)

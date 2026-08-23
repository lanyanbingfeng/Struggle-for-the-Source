class_name BaseInteraction
extends Area2D

signal selected(screen_position: Vector2)

func _ready() -> void:
	input_event.connect(_on_input_event)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		selected.emit(get_global_transform_with_canvas().origin)

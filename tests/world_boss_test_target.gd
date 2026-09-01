extends Node2D

var control_remaining: float = 0.0

func apply_control(duration: float) -> void:
	control_remaining = maxf(control_remaining, duration)

func get_control_remaining() -> float:
	return control_remaining

class_name SimpleAIController
extends Node

signal think_requested

@export_range(1.0, 30.0, 0.5) var think_interval: float = 4.0
var paused: bool = false
var enabled: bool = false
var _elapsed: float = 0.0

func configure(should_enable: bool) -> void:
	enabled = should_enable
	paused = false
	_elapsed = 0.0
	set_process(enabled)

func set_ai_paused(should_pause: bool) -> void:
	paused = should_pause

func _process(delta: float) -> void:
	if not enabled or paused:
		return
	_elapsed += delta
	if _elapsed < think_interval:
		return
	_elapsed -= think_interval
	think_requested.emit()

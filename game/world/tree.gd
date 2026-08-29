class_name HarvestTree
extends Node2D

signal felled(tree: Node2D)
signal harvest_progress_changed(resource: Node2D, remaining_percent: float)

enum State { HEALTHY, SHAKING, FALLING, REMOVED }

const SHAKE_TIME: float = 0.16
const SHAKE_DISTANCE: float = 3.0
const HARVEST_SIDE_DISTANCE: float = 32.0
const HARVEST_VERTICAL_OFFSET: float = -16.0

@onready var visuals: Node2D = $Visuals
@onready var static_sprite: Sprite2D = $Visuals/StaticSprite
@onready var fall_sprite: AnimatedSprite2D = $Visuals/FallSprite
@onready var hit_area: Area2D = $HitArea

@export var territory_id: int = 0
@export_range(0.0, 100.0, 0.1) var harvest_progress_percent: float = 100.0
@export_range(0.1, 100.0, 0.1) var harvest_cost_per_cycle_percent: float = 34.0

var _state: State = State.HEALTHY
var _visual_origin: Vector2
var _hit_tween: Tween

func _ready() -> void:
	_visual_origin = visuals.position
	harvest_progress_percent = clampf(harvest_progress_percent, 0.0, 100.0)
	hit_area.input_pickable = false
	fall_sprite.animation_finished.connect(_on_fall_animation_finished)
	fall_sprite.hide()

func can_receive_hit() -> bool:
	return can_be_targeted()

func can_be_targeted() -> bool:
	return harvest_progress_percent > 0.0 and (_state == State.HEALTHY or _state == State.SHAKING)

func get_harvest_positions(approach_position: Vector2) -> PackedVector2Array:
	var preferred_side: float = -1.0 if approach_position.x < global_position.x else 1.0
	return PackedVector2Array([
		global_position + Vector2(preferred_side * HARVEST_SIDE_DISTANCE, HARVEST_VERTICAL_OFFSET),
		global_position + Vector2(-preferred_side * HARVEST_SIDE_DISTANCE, HARVEST_VERTICAL_OFFSET),
	])

func get_harvest_position(approach_position: Vector2) -> Vector2:
	return get_harvest_positions(approach_position)[0]

func get_harvest_cycle_cost_percent() -> float:
	return harvest_cost_per_cycle_percent

func consume_harvest_progress(amount_percent: float) -> bool:
	if not can_be_targeted() or amount_percent <= 0.0:
		return false
	harvest_progress_percent = maxf(0.0, harvest_progress_percent - amount_percent)
	harvest_progress_changed.emit(self, harvest_progress_percent)
	var should_fall: bool = harvest_progress_percent <= 0.0
	if should_fall:
		hit_area.input_pickable = false
	_play_hit_reaction(should_fall)
	return true

func register_hit() -> void:
	consume_harvest_progress(harvest_cost_per_cycle_percent)

func _play_hit_reaction(should_fall: bool) -> void:
	if is_instance_valid(_hit_tween):
		_hit_tween.kill()
	_state = State.SHAKING
	visuals.position = _visual_origin
	_hit_tween = create_tween()
	_hit_tween.set_trans(Tween.TRANS_SINE)
	_hit_tween.set_ease(Tween.EASE_OUT)
	_hit_tween.tween_property(visuals, "position", _visual_origin + Vector2(-SHAKE_DISTANCE, 0.0), SHAKE_TIME * 0.25)
	_hit_tween.tween_property(visuals, "position", _visual_origin + Vector2(SHAKE_DISTANCE, 0.0), SHAKE_TIME * 0.5)
	_hit_tween.tween_property(visuals, "position", _visual_origin, SHAKE_TIME * 0.25)
	_hit_tween.finished.connect(_on_hit_reaction_finished.bind(should_fall))

func _on_hit_reaction_finished(should_fall: bool) -> void:
	if should_fall:
		_fall()
	elif harvest_progress_percent > 0.0:
		_state = State.HEALTHY

func _fall() -> void:
	_state = State.FALLING
	visuals.position = _visual_origin
	static_sprite.hide()
	fall_sprite.show()
	fall_sprite.play(&"fall")

func _on_fall_animation_finished() -> void:
	_state = State.REMOVED
	felled.emit(self)
	queue_free()

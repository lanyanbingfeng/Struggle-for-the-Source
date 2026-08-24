class_name HarvestTree
extends Node2D

signal felled(tree: Node2D)

enum State { HEALTHY, SHAKING, FALLING, REMOVED }

const HITS_TO_FELL: int = 3
const SHAKE_TIME: float = 0.16
const SHAKE_DISTANCE: float = 3.0
const HARVEST_SIDE_DISTANCE: float = 32.0
const HARVEST_VERTICAL_OFFSET: float = -16.0

@onready var visuals: Node2D = $Visuals
@onready var static_sprite: Sprite2D = $Visuals/StaticSprite
@onready var fall_sprite: AnimatedSprite2D = $Visuals/FallSprite
@onready var hit_area: Area2D = $HitArea

var _state: State = State.HEALTHY
var _hit_count: int = 0
var _visual_origin: Vector2

func _ready() -> void:
	_visual_origin = visuals.position
	hit_area.input_pickable = false
	fall_sprite.animation_finished.connect(_on_fall_animation_finished)
	fall_sprite.hide()

func can_receive_hit() -> bool:
	return _state == State.HEALTHY

func can_be_targeted() -> bool:
	return _state == State.HEALTHY or _state == State.SHAKING

func get_harvest_position(approach_position: Vector2) -> Vector2:
	var side: float = 1.0
	if approach_position.x < global_position.x:
		side = -1.0
	return global_position + Vector2(side * HARVEST_SIDE_DISTANCE, HARVEST_VERTICAL_OFFSET)

func register_hit() -> void:
	if _state != State.HEALTHY:
		return
	_hit_count += 1
	var should_fall: bool = _hit_count >= HITS_TO_FELL
	if should_fall:
		hit_area.input_pickable = false
	_play_hit_reaction(should_fall)

func _play_hit_reaction(should_fall: bool) -> void:
	_state = State.SHAKING
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(visuals, "position", _visual_origin + Vector2(-SHAKE_DISTANCE, 0.0), SHAKE_TIME * 0.25)
	tween.tween_property(visuals, "position", _visual_origin + Vector2(SHAKE_DISTANCE, 0.0), SHAKE_TIME * 0.5)
	tween.tween_property(visuals, "position", _visual_origin, SHAKE_TIME * 0.25)
	tween.finished.connect(_on_hit_reaction_finished.bind(should_fall))

func _on_hit_reaction_finished(should_fall: bool) -> void:
	if should_fall:
		_fall()
	else:
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

extends Node2D

signal depleted(stone_resource: Node2D)

enum State { HEALTHY, SHAKING, BREAKING, REMOVED }

const HITS_TO_BREAK: int = 4
const SHAKE_TIME: float = 0.14
const SHAKE_DISTANCE: float = 2.0
const HARVEST_SIDE_DISTANCE: float = 28.0
const HARVEST_VERTICAL_OFFSET: float = -14.0

@export var territory_id: int = 0

@onready var visual: Sprite2D = $Visual

var _state: State = State.HEALTHY
var _hit_count: int = 0
var _visual_origin: Vector2 = Vector2.ZERO

func _ready() -> void:
	_visual_origin = visual.position

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
	_state = State.SHAKING
	var should_break: bool = _hit_count >= HITS_TO_BREAK
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "position", _visual_origin + Vector2(-SHAKE_DISTANCE, 0.0), SHAKE_TIME * 0.25)
	tween.tween_property(visual, "position", _visual_origin + Vector2(SHAKE_DISTANCE, 0.0), SHAKE_TIME * 0.5)
	tween.tween_property(visual, "position", _visual_origin, SHAKE_TIME * 0.25)
	tween.finished.connect(_on_hit_reaction_finished.bind(should_break))

func _on_hit_reaction_finished(should_break: bool) -> void:
	if not should_break:
		_state = State.HEALTHY
		return
	_state = State.BREAKING
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(visual, "scale", Vector2(1.12, 0.55), 0.11)
	tween.tween_property(visual, "scale", Vector2.ZERO, 0.12)
	tween.finished.connect(_finish_depletion)

func _finish_depletion() -> void:
	_state = State.REMOVED
	depleted.emit(self)
	queue_free()

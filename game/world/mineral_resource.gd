class_name MineralResource
extends Node2D

signal depleted(mineral: MineralResource)

enum State { AVAILABLE, SHAKING, BREAKING, REMOVED }

const SHAKE_TIME: float = 0.14
const SHAKE_DISTANCE: float = 2.0
const HARVEST_SIDE_DISTANCE: float = 28.0
const HARVEST_VERTICAL_OFFSET: float = -14.0

@export var territory_id: int = 0
@export var resource_type: StringName = &"iron"
@export_range(1, 20, 1) var hits_to_deplete: int = 5

@onready var visual: Sprite2D = $Visual

var _state: State = State.AVAILABLE
var _hit_count: int = 0
var _visual_origin: Vector2 = Vector2.ZERO

func _ready() -> void:
	_visual_origin = visual.position

func can_be_targeted() -> bool:
	return _state == State.AVAILABLE or _state == State.SHAKING

func get_harvest_position(approach_position: Vector2) -> Vector2:
	var side: float = -1.0 if approach_position.x < global_position.x else 1.0
	return global_position + Vector2(side * HARVEST_SIDE_DISTANCE, HARVEST_VERTICAL_OFFSET)

func register_hit() -> void:
	if _state != State.AVAILABLE:
		return
	_hit_count += 1
	_state = State.SHAKING
	var should_break: bool = _hit_count >= hits_to_deplete
	var tween: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "position", _visual_origin + Vector2(-SHAKE_DISTANCE, 0.0), SHAKE_TIME * 0.25)
	tween.tween_property(visual, "position", _visual_origin + Vector2(SHAKE_DISTANCE, 0.0), SHAKE_TIME * 0.5)
	tween.tween_property(visual, "position", _visual_origin, SHAKE_TIME * 0.25)
	tween.finished.connect(_on_hit_reaction_finished.bind(should_break))

func _on_hit_reaction_finished(should_break: bool) -> void:
	if not should_break:
		_state = State.AVAILABLE
		return
	_state = State.BREAKING
	var tween: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(visual, "scale", Vector2(1.12, 0.55), 0.11)
	tween.tween_property(visual, "scale", Vector2.ZERO, 0.12)
	tween.finished.connect(_finish_depletion)

func _finish_depletion() -> void:
	_state = State.REMOVED
	depleted.emit(self)
	queue_free()

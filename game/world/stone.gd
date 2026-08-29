extends Node2D

signal depleted(stone_resource: Node2D)
signal harvest_progress_changed(resource: Node2D, remaining_percent: float)

enum State { HEALTHY, SHAKING, BREAKING, REMOVED }

const SHAKE_TIME: float = 0.14
const SHAKE_DISTANCE: float = 2.0
const HARVEST_SIDE_DISTANCE: float = 28.0
const HARVEST_VERTICAL_OFFSET: float = -14.0

@export var territory_id: int = 0
@export var resource_type: StringName = &"stone"
@export_range(0.0, 100.0, 0.1) var harvest_progress_percent: float = 100.0
@export_range(0.1, 100.0, 0.1) var harvest_cost_per_cycle_percent: float = 25.0

@onready var visual: Sprite2D = $Visual

var _state: State = State.HEALTHY
var _visual_origin: Vector2 = Vector2.ZERO
var _hit_tween: Tween

func _ready() -> void:
	_visual_origin = visual.position
	harvest_progress_percent = clampf(harvest_progress_percent, 0.0, 100.0)

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
	_play_hit_reaction(harvest_progress_percent <= 0.0)
	return true

func register_hit() -> void:
	consume_harvest_progress(harvest_cost_per_cycle_percent)

func _play_hit_reaction(should_break: bool) -> void:
	if is_instance_valid(_hit_tween):
		_hit_tween.kill()
	_state = State.SHAKING
	visual.position = _visual_origin
	visual.scale = Vector2.ONE
	_hit_tween = create_tween()
	_hit_tween.set_trans(Tween.TRANS_SINE)
	_hit_tween.set_ease(Tween.EASE_OUT)
	_hit_tween.tween_property(visual, "position", _visual_origin + Vector2(-SHAKE_DISTANCE, 0.0), SHAKE_TIME * 0.25)
	_hit_tween.tween_property(visual, "position", _visual_origin + Vector2(SHAKE_DISTANCE, 0.0), SHAKE_TIME * 0.5)
	_hit_tween.tween_property(visual, "position", _visual_origin, SHAKE_TIME * 0.25)
	_hit_tween.finished.connect(_on_hit_reaction_finished.bind(should_break))

func _on_hit_reaction_finished(should_break: bool) -> void:
	if not should_break and harvest_progress_percent > 0.0:
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

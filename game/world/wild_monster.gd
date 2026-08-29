class_name WildMonster
extends Node2D

const TARGET_SCAN_INTERVAL: float = 0.2
const ATTACK_INTERVAL: float = 1.8
const ATTACK_RANGE_TILES: float = 3.0
const ATTACK_DAMAGE: float = 18.0

@onready var sprite: Sprite2D = $Sprite

var monster_id: int = 0
var simulation_enabled: bool = false
var _target_provider: Callable
var _tile_size: float = 32.0
var _target: HealthComponent
var _scan_elapsed: float = 0.0
var _attack_elapsed: float = 0.0
var _control_remaining: float = 0.0

func configure(new_monster_id: int, should_simulate: bool) -> void:
	monster_id = new_monster_id
	simulation_enabled = should_simulate
	_scan_elapsed = 0.0
	_attack_elapsed = 0.0
	_control_remaining = 0.0

func setup_combat_context(target_provider: Callable, tile_size: int) -> void:
	_target_provider = target_provider
	_tile_size = float(tile_size)

func _physics_process(delta: float) -> void:
	if not simulation_enabled:
		return
	_control_remaining = maxf(0.0, _control_remaining - delta)
	if _control_remaining > 0.0:
		return
	_validate_target()
	_scan_elapsed += delta
	if _target == null and _scan_elapsed >= TARGET_SCAN_INTERVAL:
		_scan_elapsed = 0.0
		_acquire_target()
	if _target == null:
		return
	_attack_elapsed += delta
	if _attack_elapsed < ATTACK_INTERVAL:
		return
	_attack_elapsed -= ATTACK_INTERVAL
	_target.apply_attack(ATTACK_DAMAGE)
	_play_attack_reaction(_target.get_target_position())

func _acquire_target() -> void:
	if not _target_provider.is_valid():
		return
	var range_squared: float = pow(ATTACK_RANGE_TILES * _tile_size, 2.0)
	var nearest_distance: float = INF
	for value: Variant in (_target_provider.call() as Array):
		var candidate: HealthComponent = value as HealthComponent
		if not is_instance_valid(candidate) or not candidate.is_alive():
			continue
		var distance: float = global_position.distance_squared_to(candidate.get_target_position())
		if distance <= range_squared and distance < nearest_distance:
			nearest_distance = distance
			_target = candidate

func _validate_target() -> void:
	if _target == null:
		return
	var max_distance: float = ATTACK_RANGE_TILES * _tile_size
	if not is_instance_valid(_target) or not _target.is_alive() or global_position.distance_to(_target.get_target_position()) > max_distance:
		_target = null
		_attack_elapsed = 0.0

func _play_attack_reaction(target_position: Vector2) -> void:
	var direction: Vector2 = global_position.direction_to(target_position)
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "position", direction * 5.0, 0.08)
	tween.tween_property(sprite, "position", Vector2.ZERO, 0.12)

func apply_control(duration: float) -> void:
	_control_remaining = maxf(_control_remaining, duration)

func get_control_remaining() -> float:
	return _control_remaining

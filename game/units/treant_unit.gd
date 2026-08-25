class_name TreantUnit
extends CharacterBody2D

const TARGET_SCAN_INTERVAL: float = 0.15
const SKILL_SCAN_INTERVAL: float = 0.4
const ARRIVAL_DISTANCE: float = 4.0

@onready var sprite: Sprite2D = $Sprite

var unit_id: int = 0
var owner_peer_id: int = 0
var territory_id: int = 0
var definition: UnitDefinition
var simulation_enabled: bool = false
var move_target: Vector2 = Vector2.ZERO
var has_move_target: bool = false
var _navigation_path: PackedVector2Array = PackedVector2Array()
var _navigation_index: int = 0
var _network_position: Vector2 = Vector2.ZERO
var _selected: bool = false
var _health: HealthComponent
var _enemy_provider: Callable
var _ally_provider: Callable
var _tile_size: float = 32.0
var _combat_target: HealthComponent
var _combat_origin: Vector2 = Vector2.ZERO
var _returning_from_combat: bool = false
var _attack_elapsed: float = 0.0
var _target_scan_elapsed: float = 0.0
var _skill_scan_elapsed: float = 0.0
var _slow_remaining: float = 0.0
var _skill_flash_remaining: float = 0.0
var _attack_tween: Tween

func configure_network(new_unit_id: int, new_owner_peer_id: int, new_territory_id: int, new_definition: UnitDefinition, should_simulate: bool) -> void:
	unit_id = new_unit_id
	owner_peer_id = new_owner_peer_id
	territory_id = new_territory_id
	definition = new_definition
	simulation_enabled = should_simulate
	_network_position = global_position
	_combat_origin = global_position
	queue_redraw()

func setup_combat_context(enemy_provider: Callable, ally_provider: Callable, tile_size: int) -> void:
	_enemy_provider = enemy_provider
	_ally_provider = ally_provider
	_tile_size = float(tile_size)
	_health = get_node_or_null("HealthComponent") as HealthComponent

func set_move_target(target: Vector2) -> void:
	set_navigation_path(PackedVector2Array([target]))

func set_navigation_path(path: PackedVector2Array) -> void:
	_drop_combat_target(false)
	_returning_from_combat = false
	_navigation_path = path
	_navigation_index = 0
	if _navigation_path.is_empty():
		velocity = Vector2.ZERO
		has_move_target = false
		return
	move_target = _navigation_path[_navigation_path.size() - 1]
	has_move_target = true
	_advance_reached_waypoints()

func apply_network_state(network_position: Vector2, network_target: Vector2, moving: bool) -> void:
	_network_position = network_position
	move_target = network_target
	has_move_target = moving
	if not moving:
		_navigation_path = PackedVector2Array()
		_navigation_index = 0

func set_selected(selected: bool) -> void:
	_selected = selected
	queue_redraw()

func get_vision_radius_world(tile_size: int) -> float:
	return (definition.vision_radius_tiles if definition != null else 4.0) * float(tile_size)

func _physics_process(delta: float) -> void:
	if not simulation_enabled:
		global_position = global_position.lerp(_network_position, 0.45)
		return
	if definition == null:
		velocity = Vector2.ZERO
		return
	if not is_instance_valid(_health):
		_health = get_node_or_null("HealthComponent") as HealthComponent
	if not is_instance_valid(_health) or not _health.is_alive():
		velocity = Vector2.ZERO
		return
	_health.regenerate_mana(delta)
	_slow_remaining = maxf(0.0, _slow_remaining - delta)
	_skill_flash_remaining = maxf(0.0, _skill_flash_remaining - delta)
	_process_skill(delta)
	_validate_combat_target()
	if is_instance_valid(_combat_target):
		_process_combat_target(delta)
		return
	if _returning_from_combat:
		_process_combat_return()
		return
	_target_scan_elapsed += delta
	if _target_scan_elapsed >= TARGET_SCAN_INTERVAL:
		_target_scan_elapsed = 0.0
		_acquire_enemy_in_attack_range()
		if is_instance_valid(_combat_target):
			_process_combat_target(delta)
			return
	_process_manual_navigation()

func _process_manual_navigation() -> void:
	if not has_move_target:
		velocity = Vector2.ZERO
		return
	_advance_reached_waypoints()
	if _navigation_index >= _navigation_path.size():
		global_position = move_target
		velocity = Vector2.ZERO
		has_move_target = false
		return
	_move_toward_point(_navigation_path[_navigation_index])

func _process_combat_target(delta: float) -> void:
	var target_position := _combat_target.get_target_position()
	var chase_radius := definition.chase_range_tiles * _tile_size
	if _combat_origin.distance_to(target_position) > chase_radius:
		_drop_combat_target(true)
		return
	var attack_radius := definition.attack_range_tiles * _tile_size + _combat_target.combat_radius
	if global_position.distance_to(target_position) > attack_radius:
		_attack_elapsed = 0.0
		move_target = target_position
		has_move_target = true
		_move_toward_point(target_position)
		return
	velocity = Vector2.ZERO
	has_move_target = false
	_attack_elapsed += delta
	if _attack_elapsed < definition.attack_interval_seconds:
		return
	_attack_elapsed -= definition.attack_interval_seconds
	_combat_target.apply_attack(float(definition.attack))
	_play_attack_animation(target_position)

func _process_combat_return() -> void:
	if global_position.distance_to(_combat_origin) <= ARRIVAL_DISTANCE:
		global_position = _combat_origin
		velocity = Vector2.ZERO
		has_move_target = false
		_returning_from_combat = false
		return
	move_target = _combat_origin
	has_move_target = true
	_move_toward_point(_combat_origin)

func _move_toward_point(point: Vector2) -> void:
	var speed_multiplier := definition.skill_move_speed_multiplier if _slow_remaining > 0.0 else 1.0
	velocity = global_position.direction_to(point) * definition.movement_speed * speed_multiplier
	move_and_slide()

func _acquire_enemy_in_attack_range() -> void:
	if not _enemy_provider.is_valid():
		return
	var nearest_distance := INF
	var nearest: HealthComponent
	var candidates: Array = _enemy_provider.call()
	for candidate_value: Variant in candidates:
		var candidate := candidate_value as HealthComponent
		if not is_instance_valid(candidate) or not candidate.is_alive():
			continue
		var distance := global_position.distance_squared_to(candidate.get_target_position())
		var candidate_attack_radius := definition.attack_range_tiles * _tile_size + candidate.combat_radius
		if distance <= candidate_attack_radius * candidate_attack_radius and distance < nearest_distance:
			nearest_distance = distance
			nearest = candidate
	if nearest == null:
		return
	_combat_target = nearest
	_combat_origin = global_position
	_attack_elapsed = 0.0
	_returning_from_combat = false

func _validate_combat_target() -> void:
	if is_instance_valid(_combat_target) and _combat_target.is_alive():
		return
	if is_instance_valid(_combat_target):
		_drop_combat_target(true)
	else:
		_combat_target = null

func _drop_combat_target(should_return: bool) -> void:
	_combat_target = null
	_attack_elapsed = 0.0
	_returning_from_combat = should_return

func _process_skill(delta: float) -> void:
	if definition.skill_id != &"photosynthesis" or definition.skill_mana_cost <= 0:
		return
	_skill_scan_elapsed += delta
	if _skill_scan_elapsed < SKILL_SCAN_INTERVAL:
		return
	_skill_scan_elapsed = 0.0
	if not _ally_provider.is_valid() or _health.current_mana + 0.001 < float(definition.skill_mana_cost):
		return
	var heal_radius_squared := pow(definition.skill_radius_tiles * _tile_size, 2.0)
	var lowest_ratio := 1.0
	var lowest: HealthComponent
	var allies: Array = _ally_provider.call()
	for ally_value: Variant in allies:
		var ally := ally_value as HealthComponent
		if not is_instance_valid(ally) or not ally.is_alive():
			continue
		if global_position.distance_squared_to(ally.get_target_position()) > heal_radius_squared:
			continue
		var ratio := ally.get_health_ratio()
		if ratio < lowest_ratio:
			lowest_ratio = ratio
			lowest = ally
	if lowest == null or not _health.spend_mana(float(definition.skill_mana_cost)):
		return
	lowest.heal(lowest.max_health * definition.skill_heal_percent)
	_slow_remaining = definition.skill_slow_duration_seconds
	_skill_flash_remaining = 0.45
	queue_redraw()

func _play_attack_animation(target_position: Vector2) -> void:
	if is_instance_valid(_attack_tween):
		_attack_tween.kill()
	var direction_sign := 1.0 if target_position.x >= global_position.x else -1.0
	sprite.scale.x = direction_sign
	_attack_tween = create_tween()
	_attack_tween.tween_property(sprite, "rotation", 0.22 * direction_sign, 0.08)
	_attack_tween.tween_property(sprite, "rotation", -0.12 * direction_sign, 0.08)
	_attack_tween.tween_property(sprite, "rotation", 0.0, 0.1)

func _advance_reached_waypoints() -> void:
	while _navigation_index < _navigation_path.size():
		if global_position.distance_to(_navigation_path[_navigation_index]) > ARRIVAL_DISTANCE:
			return
		_navigation_index += 1

func _draw() -> void:
	if _skill_flash_remaining > 0.0 and definition != null:
		var alpha := _skill_flash_remaining / 0.45
		draw_circle(Vector2.ZERO, definition.skill_radius_tiles * _tile_size, Color(0.45, 0.95, 0.4, 0.08 * alpha), true)
		draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 32, Color(0.65, 1.0, 0.45, alpha), 2.0, true)
	if _selected:
		draw_ellipse(Vector2(0.0, 11.0), 15.0, 7.0, Color("#b31f24b0"), false, 2.0, true)

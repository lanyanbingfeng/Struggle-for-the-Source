class_name TreantUnit
extends CharacterBody2D

signal skill_visual_requested(network_unit_id: int, skill_id: StringName, target_position: Vector2, target_kind: StringName, target_id: int)
signal attack_visual_requested(network_unit_id: int, target_position: Vector2)

const TARGET_SCAN_INTERVAL: float = 0.1
const SKILL_SCAN_INTERVAL: float = 0.2
const ARRIVAL_DISTANCE: float = 4.0
const ATTACK_READY_ON_ACQUIRE: float = 0.52
const MOVING_ATTACK_CHARGE_LIMIT: float = 0.72
const COMBAT_PATH_REFRESH_INTERVAL: float = 0.35
const STUCK_REPATH_SECONDS: float = 0.45
const PATH_PROGRESS_EPSILON: float = 0.05
const PHOTOSYNTHESIS_FRAMES_R104: SpriteFrames = preload("res://game/units/vfx/treant_skill_green_particles_r104_frames.tres")
const PHOTOSYNTHESIS_FRAMES_R112: SpriteFrames = preload("res://game/units/vfx/treant_skill_green_particles_r112_frames.tres")
const PHOTOSYNTHESIS_FRAMES_R120: SpriteFrames = preload("res://game/units/vfx/treant_skill_green_particles_r120_frames.tres")
const PHOTOSYNTHESIS_FRAMES_R128: SpriteFrames = preload("res://game/units/vfx/treant_skill_green_particles_r128_frames.tres")

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
var _manual_move_active: bool = false
var _network_position: Vector2 = Vector2.ZERO
var _selected: bool = false
var _health: HealthComponent
var _enemy_provider: Callable
var _ally_provider: Callable
var _path_provider: Callable
var _tile_size: float = 32.0
var _combat_target: HealthComponent
var _priority_target: HealthComponent
var _priority_target_was_player_command: bool = false
var _combat_origin: Vector2 = Vector2.ZERO
var _combat_navigation_path: PackedVector2Array = PackedVector2Array()
var _combat_navigation_index: int = 0
var _combat_path_elapsed: float = COMBAT_PATH_REFRESH_INTERVAL
var _combat_path_target: Vector2 = Vector2.INF
var _path_stuck_elapsed: float = 0.0
var _returning_from_combat: bool = false
var _attack_elapsed: float = 0.0
var _target_scan_elapsed: float = 0.0
var _skill_scan_elapsed: float = 0.0
var _skill_cooldown_remaining: float = 0.0
var _slow_remaining: float = 0.0
var _control_remaining: float = 0.0
var _combat_buff_durations: Dictionary[StringName, float] = {}
var _attack_bonus_percent_by_source: Dictionary[StringName, float] = {}
var _movement_bonus_percent_by_source: Dictionary[StringName, float] = {}
var _attack_tween: Tween
var _attack_vfx: AnimatedSprite2D
var _skill_vfx: AnimatedSprite2D
var _sprite_base_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	_sprite_base_scale = sprite.scale.abs()
	_attack_vfx = get_node_or_null("AttackVfx") as AnimatedSprite2D
	_skill_vfx = get_node_or_null("SkillVfx") as AnimatedSprite2D
	if is_instance_valid(_attack_vfx):
		_attack_vfx.animation_finished.connect(_hide_vfx.bind(_attack_vfx))
	if is_instance_valid(_skill_vfx):
		_skill_vfx.animation_finished.connect(_hide_vfx.bind(_skill_vfx))

func configure_network(new_unit_id: int, new_owner_peer_id: int, new_territory_id: int, new_definition: UnitDefinition, should_simulate: bool) -> void:
	unit_id = new_unit_id
	owner_peer_id = new_owner_peer_id
	territory_id = new_territory_id
	definition = new_definition
	simulation_enabled = should_simulate
	_network_position = global_position
	_combat_origin = global_position
	_control_remaining = 0.0
	_combat_buff_durations.clear()
	_attack_bonus_percent_by_source.clear()
	_movement_bonus_percent_by_source.clear()
	_configure_skill_vfx_frames()
	queue_redraw()

func setup_combat_context(enemy_provider: Callable, ally_provider: Callable, path_provider: Callable, tile_size: int) -> void:
	_enemy_provider = enemy_provider
	_ally_provider = ally_provider
	_path_provider = path_provider
	_tile_size = float(tile_size)
	_health = get_node_or_null("HealthComponent") as HealthComponent

func set_move_target(target: Vector2) -> void:
	set_navigation_path(PackedVector2Array([target]))

func set_navigation_path(path: PackedVector2Array) -> void:
	_priority_target = null
	_priority_target_was_player_command = false
	_manual_move_active = not path.is_empty()
	_drop_combat_target(false)
	_returning_from_combat = false
	_navigation_path = path
	_navigation_index = 0
	_path_stuck_elapsed = 0.0
	if _navigation_path.is_empty():
		velocity = Vector2.ZERO
		has_move_target = false
		_manual_move_active = false
		return
	move_target = _navigation_path[_navigation_path.size() - 1]
	has_move_target = true
	_advance_reached_waypoints()

func set_priority_attack_target(target: HealthComponent) -> bool:
	if not is_instance_valid(target) or not target.is_alive():
		return false
	_manual_move_active = false
	_navigation_path = PackedVector2Array()
	_navigation_index = 0
	_priority_target = target
	_priority_target_was_player_command = true
	_combat_target = target
	_combat_origin = global_position
	_attack_elapsed = maxf(_attack_elapsed, definition.attack_interval_seconds * ATTACK_READY_ON_ACQUIRE)
	_returning_from_combat = false
	_clear_combat_navigation()
	move_target = target.get_target_position()
	has_move_target = true
	return true

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

func play_attack_visual(target_position: Vector2) -> void:
	if not is_instance_valid(_attack_vfx) or definition == null:
		return
	var direction: Vector2 = global_position.direction_to(target_position)
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	if definition.skill_id == &"photosynthesis":
		_attack_vfx.position = to_local(target_position) - Vector2(0.0, 32.0)
		_attack_vfx.rotation = 0.0
	else:
		_attack_vfx.position = direction * 18.0
		_attack_vfx.rotation = direction.angle()
	_restart_vfx(_attack_vfx)

func play_skill_visual(skill_id: StringName, target_position: Vector2) -> void:
	if not is_instance_valid(_skill_vfx):
		return
	_skill_vfx.position = Vector2.ZERO
	match skill_id:
		&"photosynthesis":
			_skill_vfx.rotation = 0.0
			_restart_vfx(_skill_vfx)
		&"stylish_slash":
			var slash_direction: Vector2 = global_position.direction_to(target_position)
			if slash_direction.is_zero_approx():
				slash_direction = Vector2.RIGHT
			_skill_vfx.rotation = slash_direction.angle()
			_restart_vfx(_skill_vfx)

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
	_skill_cooldown_remaining = maxf(0.0, _skill_cooldown_remaining - delta)
	_update_temporary_combat_effects(delta)
	if _control_remaining > 0.0:
		velocity = Vector2.ZERO
		return
	if _manual_move_active:
		_process_manual_navigation(delta)
		return
	_process_skill(delta)
	_validate_combat_target()
	if is_instance_valid(_combat_target):
		_process_combat_target(delta)
		return
	if _returning_from_combat:
		_process_combat_return(delta)
		return
	_target_scan_elapsed += delta
	if _target_scan_elapsed >= TARGET_SCAN_INTERVAL:
		_target_scan_elapsed = 0.0
		_acquire_enemy_in_engage_range()
		if is_instance_valid(_combat_target):
			_process_combat_target(delta)
			return
	_process_manual_navigation(delta)
func _process_manual_navigation(delta: float) -> void:
	if not has_move_target:
		velocity = Vector2.ZERO
		_path_stuck_elapsed = 0.0
		return
	if _path_stuck_elapsed >= STUCK_REPATH_SECONDS:
		_rebuild_manual_navigation()
	_advance_reached_waypoints()
	if _navigation_index >= _navigation_path.size():
		global_position = move_target
		velocity = Vector2.ZERO
		has_move_target = false
		_manual_move_active = false
		_path_stuck_elapsed = 0.0
		return
	var waypoint: Vector2 = _navigation_path[_navigation_index]
	var previous_position: Vector2 = global_position
	_move_toward_point(waypoint)
	_record_path_progress(delta, previous_position, waypoint)

func _process_combat_target(delta: float) -> void:
	var target_position: Vector2 = _combat_target.get_target_position()
	var chase_radius: float = definition.chase_range_tiles * _tile_size
	if _combat_target != _priority_target and _combat_origin.distance_to(target_position) > chase_radius:
		_drop_combat_target(true)
		return
	var attack_radius: float = definition.attack_range_tiles * _tile_size + _combat_target.combat_radius
	if global_position.distance_to(target_position) > attack_radius:
		var ready_limit: float = definition.attack_interval_seconds * MOVING_ATTACK_CHARGE_LIMIT
		_attack_elapsed = minf(ready_limit, _attack_elapsed + delta)
		move_target = target_position
		has_move_target = true
		_process_combat_navigation(delta, target_position)
		return
	_clear_combat_navigation()
	velocity = Vector2.ZERO
	has_move_target = false
	_attack_elapsed += delta
	if _attack_elapsed < definition.attack_interval_seconds:
		return
	_attack_elapsed -= definition.attack_interval_seconds
	_combat_target.apply_attack(float(definition.attack) * get_attack_multiplier(), owner_peer_id)
	_play_attack_animation(target_position)

func _process_combat_return(delta: float) -> void:
	if global_position.distance_to(_combat_origin) <= ARRIVAL_DISTANCE:
		global_position = _combat_origin
		velocity = Vector2.ZERO
		has_move_target = false
		_returning_from_combat = false
		_clear_combat_navigation()
		return
	move_target = _combat_origin
	has_move_target = true
	_process_combat_navigation(delta, _combat_origin)

func _process_combat_navigation(delta: float, target_position: Vector2) -> void:
	if not _path_provider.is_valid():
		_move_toward_point(target_position)
		return
	_combat_path_elapsed += delta
	var target_moved: bool = _combat_path_target.distance_squared_to(target_position) > pow(_tile_size * 0.5, 2.0)
	var path_finished: bool = _combat_navigation_index >= _combat_navigation_path.size()
	var path_stuck: bool = _path_stuck_elapsed >= STUCK_REPATH_SECONDS
	if _combat_path_elapsed >= COMBAT_PATH_REFRESH_INTERVAL and (path_finished or target_moved or path_stuck):
		var calculated_path: PackedVector2Array = _path_provider.call(global_position, target_position)
		_combat_navigation_path = calculated_path
		_combat_navigation_index = 0
		_combat_path_elapsed = 0.0
		_combat_path_target = target_position
		_path_stuck_elapsed = 0.0
	_advance_combat_waypoints()
	if _combat_navigation_index >= _combat_navigation_path.size():
		velocity = Vector2.ZERO
		return
	var waypoint: Vector2 = _combat_navigation_path[_combat_navigation_index]
	var previous_position: Vector2 = global_position
	_move_toward_point(waypoint)
	_record_path_progress(delta, previous_position, waypoint)

func _advance_combat_waypoints() -> void:
	while _combat_navigation_index < _combat_navigation_path.size():
		if global_position.distance_to(_combat_navigation_path[_combat_navigation_index]) > ARRIVAL_DISTANCE:
			return
		_combat_navigation_index += 1

func _clear_combat_navigation() -> void:
	_combat_navigation_path = PackedVector2Array()
	_combat_navigation_index = 0
	_combat_path_elapsed = COMBAT_PATH_REFRESH_INTERVAL
	_combat_path_target = Vector2.INF
	_path_stuck_elapsed = 0.0

func _rebuild_manual_navigation() -> void:
	_path_stuck_elapsed = 0.0
	if not _path_provider.is_valid():
		return
	var result: Variant = _path_provider.call(global_position, move_target)
	if result is not PackedVector2Array or (result as PackedVector2Array).is_empty():
		velocity = Vector2.ZERO
		has_move_target = false
		_manual_move_active = false
		_navigation_path = PackedVector2Array()
		_navigation_index = 0
		return
	_navigation_path = result as PackedVector2Array
	_navigation_index = 0
	move_target = _navigation_path[_navigation_path.size() - 1]

func _record_path_progress(delta: float, previous_position: Vector2, waypoint: Vector2) -> void:
	var previous_distance: float = previous_position.distance_to(waypoint)
	var current_distance: float = global_position.distance_to(waypoint)
	if current_distance <= ARRIVAL_DISTANCE or current_distance < previous_distance - PATH_PROGRESS_EPSILON:
		_path_stuck_elapsed = 0.0
	else:
		_path_stuck_elapsed += delta

func _move_toward_point(point: Vector2) -> void:
	var speed_multiplier: float = definition.skill_move_speed_multiplier if _slow_remaining > 0.0 else 1.0
	velocity = global_position.direction_to(point) * definition.movement_speed * speed_multiplier * get_movement_multiplier()
	move_and_slide()

func _acquire_enemy_in_engage_range(preserve_combat_origin: bool = false) -> bool:
	if not _enemy_provider.is_valid():
		return false
	var nearest_distance: float = INF
	var nearest: HealthComponent
	var engage_radius: float = minf(definition.chase_range_tiles, definition.attack_range_tiles + 2.25) * _tile_size
	var candidates: Array = _enemy_provider.call()
	for candidate_value: Variant in candidates:
		var candidate: HealthComponent = candidate_value as HealthComponent
		if not is_instance_valid(candidate) or not candidate.is_alive():
			continue
		var distance: float = global_position.distance_squared_to(candidate.get_target_position())
		var candidate_engage_radius: float = engage_radius + candidate.combat_radius
		if distance <= candidate_engage_radius * candidate_engage_radius and distance < nearest_distance:
			nearest_distance = distance
			nearest = candidate
	if nearest == null:
		return false
	_combat_target = nearest
	if not preserve_combat_origin:
		_combat_origin = global_position
	_attack_elapsed = maxf(_attack_elapsed, definition.attack_interval_seconds * ATTACK_READY_ON_ACQUIRE)
	_returning_from_combat = false
	_clear_combat_navigation()
	return true

func _validate_combat_target() -> void:
	if is_instance_valid(_priority_target) and _priority_target.is_alive():
		_combat_target = _priority_target
		return
	var completed_player_command: bool = _priority_target_was_player_command
	_priority_target = null
	_priority_target_was_player_command = false
	if _combat_target == null:
		return
	if is_instance_valid(_combat_target) and _combat_target.is_alive():
		return
	_combat_target = null
	if completed_player_command:
		_attack_elapsed = 0.0
		_returning_from_combat = false
		has_move_target = false
		velocity = Vector2.ZERO
		_clear_combat_navigation()
		return
	if _acquire_enemy_in_engage_range(true):
		return
	_attack_elapsed = 0.0
	_returning_from_combat = true

func _drop_combat_target(should_return: bool) -> void:
	_combat_target = null
	_priority_target = null
	_priority_target_was_player_command = false
	_attack_elapsed = 0.0
	_returning_from_combat = should_return
	_clear_combat_navigation()

func _process_skill(delta: float) -> void:
	if definition.skill_id == &"" or definition.skill_mana_cost <= 0 or _skill_cooldown_remaining > 0.0:
		return
	_skill_scan_elapsed += delta
	if _skill_scan_elapsed < SKILL_SCAN_INTERVAL:
		return
	_skill_scan_elapsed = 0.0
	if _health.current_mana + 0.001 < float(definition.skill_mana_cost):
		return
	match definition.skill_id:
		&"photosynthesis":
			_try_cast_photosynthesis()
		&"stylish_slash":
			_try_cast_stylish_slash()

func _try_cast_photosynthesis() -> bool:
	if not _ally_provider.is_valid():
		return false
	var heal_radius_squared: float = pow(definition.skill_radius_tiles * _tile_size, 2.0)
	var targets: Array[HealthComponent] = []
	var has_injured_target: bool = false
	var allies: Array = _ally_provider.call()
	for ally_value: Variant in allies:
		var ally: HealthComponent = ally_value as HealthComponent
		if not is_instance_valid(ally) or not ally.is_alive():
			continue
		if global_position.distance_squared_to(ally.get_target_position()) > heal_radius_squared:
			continue
		targets.append(ally)
		has_injured_target = has_injured_target or ally.current_health < ally.max_health
	if not has_injured_target or not _health.spend_mana(float(definition.skill_mana_cost)):
		return false
	for target: HealthComponent in targets:
		target.heal(target.max_health * definition.skill_heal_percent)
	_slow_remaining = definition.skill_slow_duration_seconds
	_skill_cooldown_remaining = definition.skill_cooldown_seconds
	play_skill_visual(&"photosynthesis", global_position)
	skill_visual_requested.emit(unit_id, &"photosynthesis", global_position, &"unit", unit_id)
	return true

func _try_cast_stylish_slash() -> bool:
	var skill_damage: float = definition.get_skill_damage()
	if not _enemy_provider.is_valid() or skill_damage <= 0.0:
		return false
	var targets: Array[HealthComponent] = []
	var nearest_distance: float = INF
	var visual_target_position: Vector2 = global_position + Vector2.RIGHT
	var candidates: Array = _enemy_provider.call()
	for candidate_value: Variant in candidates:
		var candidate: HealthComponent = candidate_value as HealthComponent
		if not is_instance_valid(candidate) or not candidate.is_alive():
			continue
		var target_position: Vector2 = candidate.get_target_position()
		var distance: float = global_position.distance_squared_to(target_position)
		var effective_radius: float = definition.skill_radius_tiles * _tile_size + candidate.combat_radius
		if distance > effective_radius * effective_radius:
			continue
		targets.append(candidate)
		if distance < nearest_distance:
			nearest_distance = distance
			visual_target_position = target_position
	if targets.is_empty() or not _health.spend_mana(float(definition.skill_mana_cost)):
		return false
	for target: HealthComponent in targets:
		if target.execute_if_below(definition.skill_execute_health_ratio, owner_peer_id):
			continue
		target.apply_attack(skill_damage, owner_peer_id)
	_skill_cooldown_remaining = definition.skill_cooldown_seconds
	_attack_elapsed = 0.0
	play_skill_visual(&"stylish_slash", visual_target_position)
	skill_visual_requested.emit(unit_id, &"stylish_slash", visual_target_position, &"unit", unit_id)
	return true

func _play_attack_animation(target_position: Vector2) -> void:
	if is_instance_valid(_attack_tween):
		_attack_tween.kill()
	var direction: Vector2 = global_position.direction_to(target_position)
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	play_attack_visual(target_position)
	attack_visual_requested.emit(unit_id, target_position)
	var direction_sign: float = 1.0 if direction.x >= 0.0 else -1.0
	sprite.scale = Vector2(_sprite_base_scale.x * direction_sign, _sprite_base_scale.y)
	sprite.position = Vector2.ZERO
	_attack_tween = create_tween()
	_attack_tween.set_trans(Tween.TRANS_QUAD)
	_attack_tween.set_ease(Tween.EASE_OUT)
	_attack_tween.tween_property(sprite, "position", direction * 5.0, 0.07)
	_attack_tween.parallel().tween_property(sprite, "rotation", 0.25 * direction_sign, 0.07)
	_attack_tween.tween_property(sprite, "position", -direction * 2.0, 0.08)
	_attack_tween.parallel().tween_property(sprite, "rotation", -0.14 * direction_sign, 0.08)
	_attack_tween.tween_property(sprite, "position", Vector2.ZERO, 0.09)
	_attack_tween.parallel().tween_property(sprite, "rotation", 0.0, 0.09)

func _advance_reached_waypoints() -> void:
	while _navigation_index < _navigation_path.size():
		if global_position.distance_to(_navigation_path[_navigation_index]) > ARRIVAL_DISTANCE:
			return
		_navigation_index += 1

func _configure_skill_vfx_frames() -> void:
	if not is_instance_valid(_skill_vfx) or definition == null or definition.skill_id != &"photosynthesis":
		return
	var radius_pixels: int = roundi(definition.skill_radius_tiles * _tile_size)
	if radius_pixels <= 104:
		_skill_vfx.sprite_frames = PHOTOSYNTHESIS_FRAMES_R104
	elif radius_pixels <= 112:
		_skill_vfx.sprite_frames = PHOTOSYNTHESIS_FRAMES_R112
	elif radius_pixels <= 120:
		_skill_vfx.sprite_frames = PHOTOSYNTHESIS_FRAMES_R120
	else:
		_skill_vfx.sprite_frames = PHOTOSYNTHESIS_FRAMES_R128

func _restart_vfx(vfx: AnimatedSprite2D) -> void:
	vfx.stop()
	vfx.frame = 0
	vfx.visible = true
	vfx.play(&"default")

func _hide_vfx(vfx: AnimatedSprite2D) -> void:
	vfx.visible = false

func apply_control(duration: float) -> void:
	_control_remaining = maxf(_control_remaining, duration)

func get_control_remaining() -> float:
	return _control_remaining

func apply_combat_buff(source_id: StringName, attack_bonus_percent: float, movement_bonus_percent: float, duration: float) -> void:
	if source_id.is_empty() or duration <= 0.0:
		return
	_combat_buff_durations[source_id] = maxf(duration, float(_combat_buff_durations.get(source_id, 0.0)))
	_attack_bonus_percent_by_source[source_id] = maxf(0.0, attack_bonus_percent)
	_movement_bonus_percent_by_source[source_id] = maxf(0.0, movement_bonus_percent)

func get_combat_buff_remaining(source_id: StringName) -> float:
	return float(_combat_buff_durations.get(source_id, 0.0))

func get_attack_multiplier() -> float:
	return 1.0 + _sum_modifier_percent(_attack_bonus_percent_by_source) / 100.0

func get_movement_multiplier() -> float:
	return 1.0 + _sum_modifier_percent(_movement_bonus_percent_by_source) / 100.0

func _update_temporary_combat_effects(delta: float) -> void:
	_control_remaining = maxf(0.0, _control_remaining - delta)
	for source_id_value: Variant in _combat_buff_durations.keys():
		var source_id: StringName = StringName(str(source_id_value))
		var remaining: float = maxf(0.0, float(_combat_buff_durations[source_id]) - delta)
		if remaining > 0.0:
			_combat_buff_durations[source_id] = remaining
			continue
		_combat_buff_durations.erase(source_id)
		_attack_bonus_percent_by_source.erase(source_id)
		_movement_bonus_percent_by_source.erase(source_id)

func _sum_modifier_percent(modifiers: Dictionary[StringName, float]) -> float:
	var total: float = 0.0
	for value: float in modifiers.values():
		total += value
	return total

func _draw() -> void:
	if _selected:
		draw_ellipse(Vector2(0.0, 11.0), 15.0, 7.0, Color("#b31f24b0"), false, 2.0, true)

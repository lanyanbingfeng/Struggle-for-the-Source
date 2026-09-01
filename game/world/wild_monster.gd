class_name WildMonster
extends CharacterBody2D

signal attack_visual_requested(monster_id: int, target_position: Vector2)
signal skill_visual_requested(monster_id: int, target_position: Vector2)

const DISPLAY_NAME: String = "幽网织母·维洛莎"
const ELITE_LABEL: String = "精英"
const TARGET_SCAN_INTERVAL: float = 0.15
const ATTACK_INTERVAL: float = 1.45
const ATTACK_RANGE_TILES: float = 4.25
const ATTACK_DAMAGE: float = 48.0
const MAX_HEALTH: float = 980.0
const DEFENSE: float = 16.0
const MOVEMENT_SPEED: float = 78.0
const AGGRO_RANGE_TILES: float = 9.0
const CHASE_RANGE_TILES: float = 12.0
const ATTACK_READY_ON_ACQUIRE: float = 0.45
const MOVING_ATTACK_CHARGE_LIMIT: float = 0.72
const WEB_SKILL_DAMAGE: float = 72.0
const WEB_SKILL_RADIUS_TILES: float = 2.75
const WEB_SKILL_CAST_RANGE_TILES: float = 5.5
const WEB_SKILL_CONTROL_SECONDS: float = 1.75
const WEB_SKILL_COOLDOWN_SECONDS: float = 9.0
const WEB_SKILL_INITIAL_DELAY_SECONDS: float = 3.0
const PATH_REFRESH_INTERVAL: float = 0.35
const ARRIVAL_DISTANCE: float = 5.0
const VENOM_BOLT_DISPLAY_WIDTH: float = 58.0
const VENOM_BOLT_TRAVEL_SECONDS: float = 0.28
const VENOM_BOLT_TEXTURE: Texture2D = preload("res://art/vfx/elite_spider_venom_bolt.png")
const WEB_FIELD_TEXTURE: Texture2D = preload("res://art/vfx/elite_spider_web_field.png")

@onready var sprite: Sprite2D = $Sprite

var monster_id: int = 0
var simulation_enabled: bool = false
var _target_provider: Callable
var _path_provider: Callable
var _tile_size: float = 32.0
var _target: HealthComponent
var _health: HealthComponent
var _home_position: Vector2 = Vector2.ZERO
var _network_position: Vector2 = Vector2.ZERO
var _network_in_combat: bool = false
var _navigation_path: PackedVector2Array = PackedVector2Array()
var _navigation_index: int = 0
var _navigation_elapsed: float = PATH_REFRESH_INTERVAL
var _navigation_target: Vector2 = Vector2.INF
var _returning_home: bool = false
var _scan_elapsed: float = 0.0
var _attack_elapsed: float = 0.0
var _skill_cooldown_remaining: float = WEB_SKILL_INITIAL_DELAY_SECONDS
var _control_remaining: float = 0.0
var _attack_tween: Tween
var _difficulty: int = WildEnemyDifficulty.Level.NORMAL
var _health_multiplier: float = 1.0
var _damage_multiplier: float = 1.0
var _interval_multiplier: float = 1.0

func configure(new_monster_id: int, should_simulate: bool, difficulty: int = WildEnemyDifficulty.Level.NORMAL) -> void:
	monster_id = new_monster_id
	simulation_enabled = should_simulate
	_difficulty = WildEnemyDifficulty.normalize(difficulty)
	_health_multiplier = WildEnemyDifficulty.get_health_multiplier(_difficulty)
	_damage_multiplier = WildEnemyDifficulty.get_damage_multiplier(_difficulty)
	_interval_multiplier = WildEnemyDifficulty.get_interval_multiplier(_difficulty)
	_home_position = global_position
	_network_position = global_position
	_network_in_combat = false
	_scan_elapsed = 0.0
	_attack_elapsed = 0.0
	_skill_cooldown_remaining = WEB_SKILL_INITIAL_DELAY_SECONDS * _interval_multiplier
	_control_remaining = 0.0
	_target = null
	_returning_home = false
	_clear_navigation()

func setup_combat_context(target_provider: Callable, path_provider: Callable, tile_size: int) -> void:
	_target_provider = target_provider
	_path_provider = path_provider
	_tile_size = float(tile_size)
	_health = get_node_or_null("HealthComponent") as HealthComponent

func apply_network_state(network_position: Vector2, in_combat: bool = false) -> void:
	_network_position = network_position
	_network_in_combat = in_combat

func get_display_name() -> String:
	return DISPLAY_NAME

func is_in_combat() -> bool:
	return is_instance_valid(_target) and _target.is_alive() if simulation_enabled else _network_in_combat

func get_max_health() -> float:
	return MAX_HEALTH * _health_multiplier

func get_attack_damage() -> float:
	return ATTACK_DAMAGE * _damage_multiplier

func get_attack_interval() -> float:
	return ATTACK_INTERVAL * _interval_multiplier

func get_web_skill_damage() -> float:
	return WEB_SKILL_DAMAGE * _damage_multiplier

func get_web_skill_cooldown() -> float:
	return WEB_SKILL_COOLDOWN_SECONDS * _interval_multiplier

func get_difficulty() -> int:
	return _difficulty

func _physics_process(delta: float) -> void:
	if not simulation_enabled:
		global_position = global_position.lerp(_network_position, 0.45)
		velocity = Vector2.ZERO
		return
	if not is_instance_valid(_health):
		_health = get_node_or_null("HealthComponent") as HealthComponent
	if not is_instance_valid(_health) or not _health.is_alive():
		velocity = Vector2.ZERO
		return
	_control_remaining = maxf(0.0, _control_remaining - delta)
	_skill_cooldown_remaining = maxf(0.0, _skill_cooldown_remaining - delta)
	if _control_remaining > 0.0:
		velocity = Vector2.ZERO
		return
	_validate_target()
	_scan_elapsed += delta
	if _target == null and _scan_elapsed >= TARGET_SCAN_INTERVAL:
		_scan_elapsed = 0.0
		_acquire_target()
	if is_instance_valid(_target):
		if _try_cast_web_skill():
			velocity = Vector2.ZERO
			return
		_process_combat_target(delta)
		return
	_process_return_home(delta)

func _acquire_target() -> void:
	if not _target_provider.is_valid():
		return
	var aggro_radius: float = AGGRO_RANGE_TILES * _tile_size
	var leash_radius: float = CHASE_RANGE_TILES * _tile_size
	var nearest_distance: float = INF
	for value: Variant in (_target_provider.call() as Array):
		var candidate: HealthComponent = value as HealthComponent
		if not is_instance_valid(candidate) or not candidate.is_alive():
			continue
		var target_position: Vector2 = candidate.get_target_position()
		if _home_position.distance_to(target_position) > leash_radius + candidate.combat_radius:
			continue
		var distance: float = global_position.distance_squared_to(target_position)
		var candidate_aggro_radius: float = aggro_radius + candidate.combat_radius
		if distance <= candidate_aggro_radius * candidate_aggro_radius and distance < nearest_distance:
			nearest_distance = distance
			_target = candidate
	if _target == null:
		return
	_returning_home = false
	_attack_elapsed = maxf(_attack_elapsed, get_attack_interval() * ATTACK_READY_ON_ACQUIRE)
	_clear_navigation()

func _validate_target() -> void:
	if _target == null:
		return
	if not is_instance_valid(_target) or not _target.is_alive():
		_drop_target(true)
		return
	var leash_radius: float = CHASE_RANGE_TILES * _tile_size + _target.combat_radius
	if _home_position.distance_to(_target.get_target_position()) > leash_radius:
		_drop_target(true)

func _process_combat_target(delta: float) -> void:
	if not is_instance_valid(_target):
		return
	var target_position: Vector2 = _target.get_target_position()
	var attack_radius: float = ATTACK_RANGE_TILES * _tile_size + _target.combat_radius
	if global_position.distance_to(target_position) > attack_radius:
		var ready_limit: float = get_attack_interval() * MOVING_ATTACK_CHARGE_LIMIT
		_attack_elapsed = minf(ready_limit, _attack_elapsed + delta)
		_process_navigation(target_position)
		return
	velocity = Vector2.ZERO
	_clear_navigation()
	_attack_elapsed += delta
	var attack_interval: float = get_attack_interval()
	if _attack_elapsed < attack_interval:
		return
	_attack_elapsed -= attack_interval
	_target.apply_attack(get_attack_damage(), 0, 0.0, "%s的毒液攻击" % DISPLAY_NAME)
	_play_attack_reaction(target_position)
	play_attack_visual(target_position)
	attack_visual_requested.emit(monster_id, target_position)

func _try_cast_web_skill() -> bool:
	if _skill_cooldown_remaining > 0.0 or not is_instance_valid(_target) or not _target_provider.is_valid():
		return false
	var center_position: Vector2 = _target.get_target_position()
	var cast_radius: float = WEB_SKILL_CAST_RANGE_TILES * _tile_size + _target.combat_radius
	if global_position.distance_to(center_position) > cast_radius:
		return false
	var targets: Array[HealthComponent] = []
	for value: Variant in (_target_provider.call() as Array):
		var candidate: HealthComponent = value as HealthComponent
		if not is_instance_valid(candidate) or not candidate.is_alive():
			continue
		var effect_radius: float = WEB_SKILL_RADIUS_TILES * _tile_size + candidate.combat_radius
		if center_position.distance_squared_to(candidate.get_target_position()) <= effect_radius * effect_radius:
			targets.append(candidate)
	if targets.is_empty():
		return false
	for target: HealthComponent in targets:
		target.apply_attack(get_web_skill_damage(), 0, 0.0, "%s的蛛网缚杀" % DISPLAY_NAME)
		if target.is_alive() and is_instance_valid(target.target_root) and target.target_root.has_method(&"apply_control"):
			target.target_root.call(&"apply_control", WEB_SKILL_CONTROL_SECONDS)
	_skill_cooldown_remaining = get_web_skill_cooldown()
	_attack_elapsed = 0.0
	play_skill_visual(center_position)
	skill_visual_requested.emit(monster_id, center_position)
	return true

func _process_return_home(delta: float) -> void:
	if not _returning_home:
		velocity = Vector2.ZERO
		return
	if global_position.distance_to(_home_position) <= ARRIVAL_DISTANCE:
		global_position = _home_position
		velocity = Vector2.ZERO
		_returning_home = false
		_clear_navigation()
		return
	_attack_elapsed = minf(get_attack_interval() * MOVING_ATTACK_CHARGE_LIMIT, _attack_elapsed + delta)
	_process_navigation(_home_position)

func _process_navigation(target_position: Vector2) -> void:
	if not _path_provider.is_valid():
		_move_toward_point(target_position)
		return
	_navigation_elapsed += get_physics_process_delta_time()
	var target_moved: bool = _navigation_target.distance_squared_to(target_position) > pow(_tile_size * 0.5, 2.0)
	var path_finished: bool = _navigation_index >= _navigation_path.size()
	if _navigation_elapsed >= PATH_REFRESH_INTERVAL and (target_moved or path_finished):
		var path_result: Variant = _path_provider.call(global_position, target_position)
		_navigation_path = path_result as PackedVector2Array if path_result is PackedVector2Array else PackedVector2Array()
		_navigation_index = 0
		_navigation_elapsed = 0.0
		_navigation_target = target_position
	_advance_navigation_waypoints()
	if _navigation_index >= _navigation_path.size():
		velocity = Vector2.ZERO
		return
	_move_toward_point(_navigation_path[_navigation_index])

func _advance_navigation_waypoints() -> void:
	while _navigation_index < _navigation_path.size():
		if global_position.distance_to(_navigation_path[_navigation_index]) > ARRIVAL_DISTANCE:
			return
		_navigation_index += 1

func _move_toward_point(point: Vector2) -> void:
	var direction: Vector2 = global_position.direction_to(point)
	if direction.is_zero_approx():
		velocity = Vector2.ZERO
		return
	velocity = direction * MOVEMENT_SPEED
	move_and_slide()
	if not is_zero_approx(direction.x):
		sprite.flip_h = direction.x < 0.0

func _drop_target(should_return_home: bool) -> void:
	_target = null
	_attack_elapsed = 0.0
	_returning_home = should_return_home
	_clear_navigation()

func _clear_navigation() -> void:
	_navigation_path = PackedVector2Array()
	_navigation_index = 0
	_navigation_elapsed = PATH_REFRESH_INTERVAL
	_navigation_target = Vector2.INF

func _play_attack_reaction(target_position: Vector2) -> void:
	if is_instance_valid(_attack_tween):
		_attack_tween.kill()
	var direction: Vector2 = global_position.direction_to(target_position)
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	sprite.position = Vector2.ZERO
	_attack_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_attack_tween.tween_property(sprite, "position", direction * 6.0, 0.08)
	_attack_tween.tween_property(sprite, "position", Vector2.ZERO, 0.12)

func play_attack_visual(target_position: Vector2) -> void:
	var direction: Vector2 = global_position.direction_to(target_position)
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	var vfx := Sprite2D.new()
	vfx.name = "EliteSpiderVenomBoltVfx"
	vfx.texture = VENOM_BOLT_TEXTURE
	vfx.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	vfx.z_index = 8
	vfx.rotation = direction.angle()
	var texture_width: float = maxf(1.0, VENOM_BOLT_TEXTURE.get_size().x)
	var visual_scale: float = VENOM_BOLT_DISPLAY_WIDTH / texture_width
	vfx.scale = Vector2.ONE * visual_scale
	add_child(vfx)
	vfx.top_level = true
	vfx.global_position = global_position + direction * 25.0
	var tween: Tween = vfx.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(vfx, "global_position", target_position, VENOM_BOLT_TRAVEL_SECONDS)
	tween.parallel().tween_property(vfx, "modulate:a", 0.25, VENOM_BOLT_TRAVEL_SECONDS)
	tween.tween_callback(vfx.queue_free)

func play_skill_visual(target_position: Vector2) -> void:
	var vfx := Sprite2D.new()
	vfx.name = "EliteSpiderWebFieldVfx"
	vfx.texture = WEB_FIELD_TEXTURE
	vfx.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	vfx.z_index = -1
	vfx.modulate.a = 0.0
	var texture_width: float = maxf(1.0, WEB_FIELD_TEXTURE.get_size().x)
	var final_scale_value: float = WEB_SKILL_RADIUS_TILES * _tile_size * 2.0 / texture_width
	var final_scale: Vector2 = Vector2.ONE * final_scale_value
	vfx.scale = final_scale * 0.35
	add_child(vfx)
	vfx.top_level = true
	vfx.global_position = target_position
	var tween: Tween = vfx.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(vfx, "scale", final_scale, 0.16)
	tween.parallel().tween_property(vfx, "modulate:a", 0.86, 0.16)
	tween.tween_interval(maxf(0.1, WEB_SKILL_CONTROL_SECONDS - 0.56))
	tween.tween_property(vfx, "modulate:a", 0.0, 0.4)
	tween.parallel().tween_property(vfx, "scale", final_scale * 1.05, 0.4)
	tween.tween_callback(vfx.queue_free)

func apply_control(duration: float) -> void:
	_control_remaining = maxf(_control_remaining, duration)

func get_control_remaining() -> float:
	return _control_remaining

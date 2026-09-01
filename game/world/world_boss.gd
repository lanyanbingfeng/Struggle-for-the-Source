class_name WorldBoss
extends CharacterBody2D

signal attack_visual_requested(boss_id: int, target_position: Vector2)
signal skill_visual_requested(boss_id: int, skill_id: StringName, positions: PackedVector2Array)
signal phase_changed(boss_id: int, phase: int)

enum State { IDLE, CHASING, CASTING, RETURNING, HEALING }

const DISPLAY_NAME: String = "镇岳魔神·玄狱"
const HUD_NAME: String = "世界BOSS｜镇岳魔神·玄狱"
const FOOTPRINT_TILES: Vector2i = Vector2i(3, 3)
const MAX_HEALTH: float = 5200.0
const DEFENSE: float = 26.0
const MOVEMENT_SPEED: float = 68.0
const ATTACK_DAMAGE: float = 62.0
const ATTACK_INTERVAL: float = 2.0
const ATTACK_RANGE_TILES: float = 2.25
const AGGRO_RANGE_TILES: float = 12.0
const CHASE_RANGE_TILES: float = 18.0
const COMBAT_RADIUS: float = 52.0
const PHASE_TWO_HEALTH_RATIO: float = 0.50
const PHASE_TWO_SPEED_MULTIPLIER: float = 1.12
const PHASE_TWO_INTERVAL_MULTIPLIER: float = 0.82
const HEAL_DELAY_SECONDS: float = 5.0
const HEAL_RATIO_PER_SECOND: float = 0.02

const SKILL_MOUNTAIN_BREAK: StringName = &"mountain_break"
const SKILL_INFERNAL_CHARGE: StringName = &"infernal_charge"
const SKILL_HEAVENFIRE: StringName = &"heavenfire"
const SKILL_IDS: Array[StringName] = [SKILL_MOUNTAIN_BREAK, SKILL_INFERNAL_CHARGE, SKILL_HEAVENFIRE]
const MOUNTAIN_BREAK_INITIAL_DELAY: float = 4.0
const MOUNTAIN_BREAK_COOLDOWN: float = 9.0
const MOUNTAIN_BREAK_WARNING: float = 0.9
const MOUNTAIN_BREAK_RADIUS_TILES: float = 4.25
const MOUNTAIN_BREAK_DAMAGE: float = 78.0
const MOUNTAIN_BREAK_CONTROL_SECONDS: float = 1.0
const INFERNAL_CHARGE_INITIAL_DELAY: float = 7.0
const INFERNAL_CHARGE_COOLDOWN: float = 13.0
const INFERNAL_CHARGE_WARNING: float = 0.75
const INFERNAL_CHARGE_MAX_TILES: float = 7.0
const INFERNAL_CHARGE_RADIUS_TILES: float = 1.5
const INFERNAL_CHARGE_DAMAGE: float = 92.0
const INFERNAL_CHARGE_CONTROL_SECONDS: float = 0.65
const HEAVENFIRE_INITIAL_DELAY: float = 10.0
const HEAVENFIRE_COOLDOWN: float = 16.0
const HEAVENFIRE_WARNING: float = 1.2
const HEAVENFIRE_RADIUS_TILES: float = 2.75
const HEAVENFIRE_DAMAGE: float = 110.0
const TARGET_SCAN_INTERVAL: float = 0.15
const PATH_REFRESH_INTERVAL: float = 0.30
const ARRIVAL_DISTANCE: float = 5.0
const ATTACK_READY_ON_ACQUIRE: float = 0.40
const MOVING_ATTACK_CHARGE_LIMIT: float = 0.72
const BOSS_DISPLAY_HEIGHT: float = 170.0
const LAIR_DISPLAY_WIDTH: float = 176.0
const AURA_DISPLAY_WIDTH: float = 212.0
const CHARGE_SEGMENT_SPACING: float = 46.0

const MOUNTAIN_BREAK_TEXTURE: Texture2D = preload("res://art/vfx/world_boss_mountain_break.png")
const INFERNAL_CHARGE_TEXTURE: Texture2D = preload("res://art/vfx/world_boss_infernal_charge.png")
const HEAVENFIRE_TEXTURE: Texture2D = preload("res://art/vfx/world_boss_heavenfire.png")

@onready var sprite: Sprite2D = $Sprite
@onready var lair: Sprite2D = $Lair
@onready var aura: Sprite2D = $Aura
@onready var name_label: Label = $NameLabel

var boss_id: int = 1
var simulation_enabled: bool = false
var _difficulty: int = WildEnemyDifficulty.Level.NORMAL
var _health_multiplier: float = 1.0
var _damage_multiplier: float = 1.0
var _interval_multiplier: float = 1.0
var _tile_size: float = 32.0
var _home_position: Vector2 = Vector2.ZERO
var _network_position: Vector2 = Vector2.ZERO
var _network_in_combat: bool = false
var _target_provider: Callable
var _path_provider: Callable
var _target: HealthComponent
var _health: HealthComponent
var _state: State = State.IDLE
var _phase: int = 1
var _scan_elapsed: float = 0.0
var _attack_elapsed: float = 0.0
var _out_of_combat_elapsed: float = 0.0
var _skill_cycle_index: int = 0
var _skill_cooldowns: Dictionary[StringName, float] = {}
var _casting_skill: StringName = &""
var _cast_remaining: float = 0.0
var _cast_positions: PackedVector2Array = PackedVector2Array()
var _navigation_path: PackedVector2Array = PackedVector2Array()
var _navigation_index: int = 0
var _navigation_elapsed: float = PATH_REFRESH_INTERVAL
var _navigation_target: Vector2 = Vector2.INF
var _attack_tween: Tween

func _ready() -> void:
	_fit_sprite_height(sprite, BOSS_DISPLAY_HEIGHT)
	_fit_sprite_width(lair, LAIR_DISPLAY_WIDTH)
	_fit_sprite_width(aura, AURA_DISPLAY_WIDTH)
	lair.top_level = true
	lair.global_position = global_position
	aura.visible = false
	name_label.text = "世界BOSS｜%s" % DISPLAY_NAME

func configure(new_boss_id: int, should_simulate: bool, difficulty: int = WildEnemyDifficulty.Level.NORMAL) -> void:
	boss_id = new_boss_id
	simulation_enabled = should_simulate
	_difficulty = WildEnemyDifficulty.normalize(difficulty)
	_health_multiplier = WildEnemyDifficulty.get_health_multiplier(_difficulty)
	_damage_multiplier = WildEnemyDifficulty.get_damage_multiplier(_difficulty)
	_interval_multiplier = WildEnemyDifficulty.get_interval_multiplier(_difficulty)
	_home_position = global_position
	_network_position = global_position
	_network_in_combat = false
	lair.global_position = _home_position
	_state = State.IDLE
	_phase = 1
	_target = null
	_scan_elapsed = 0.0
	_attack_elapsed = 0.0
	_out_of_combat_elapsed = 0.0
	_skill_cycle_index = 0
	_skill_cooldowns = {
		SKILL_MOUNTAIN_BREAK: MOUNTAIN_BREAK_INITIAL_DELAY * _interval_multiplier,
		SKILL_INFERNAL_CHARGE: INFERNAL_CHARGE_INITIAL_DELAY * _interval_multiplier,
		SKILL_HEAVENFIRE: HEAVENFIRE_INITIAL_DELAY * _interval_multiplier,
	}
	_casting_skill = &""
	_cast_remaining = 0.0
	_cast_positions = PackedVector2Array()
	_clear_navigation()
	_update_phase_visuals(false)

func setup_combat_context(target_provider: Callable, path_provider: Callable, tile_size: int) -> void:
	_target_provider = target_provider
	_path_provider = path_provider
	_tile_size = float(tile_size)
	_health = get_node_or_null("HealthComponent") as HealthComponent

func apply_network_state(network_position: Vector2, phase: int, in_combat: bool = false) -> void:
	_network_position = network_position
	_network_in_combat = in_combat
	_set_phase(clampi(phase, 1, 2), false)

func get_display_name() -> String:
	return DISPLAY_NAME

func is_in_combat() -> bool:
	return _state in [State.CHASING, State.CASTING] if simulation_enabled else _network_in_combat

func get_max_health() -> float:
	return MAX_HEALTH * _health_multiplier

func get_attack_damage() -> float:
	return ATTACK_DAMAGE * _damage_multiplier

func get_attack_interval() -> float:
	return ATTACK_INTERVAL * _current_interval_multiplier()

func get_movement_speed() -> float:
	return MOVEMENT_SPEED * (PHASE_TWO_SPEED_MULTIPLIER if _phase == 2 else 1.0)

func get_skill_damage(skill_id: StringName) -> float:
	match skill_id:
		SKILL_MOUNTAIN_BREAK:
			return MOUNTAIN_BREAK_DAMAGE * _damage_multiplier
		SKILL_INFERNAL_CHARGE:
			return INFERNAL_CHARGE_DAMAGE * _damage_multiplier
		SKILL_HEAVENFIRE:
			return HEAVENFIRE_DAMAGE * _damage_multiplier
	return 0.0

func get_skill_cooldown(skill_id: StringName) -> float:
	var base_cooldown: float = 0.0
	match skill_id:
		SKILL_MOUNTAIN_BREAK:
			base_cooldown = MOUNTAIN_BREAK_COOLDOWN
		SKILL_INFERNAL_CHARGE:
			base_cooldown = INFERNAL_CHARGE_COOLDOWN
		SKILL_HEAVENFIRE:
			base_cooldown = HEAVENFIRE_COOLDOWN
	return base_cooldown * _current_interval_multiplier()

func get_skill_cooldown_remaining(skill_id: StringName) -> float:
	return float(_skill_cooldowns.get(skill_id, 0.0))

func get_phase() -> int:
	return _phase

func get_state() -> State:
	return _state

func get_home_position() -> Vector2:
	return _home_position

func get_difficulty() -> int:
	return _difficulty

func get_footprint_rect(tile_size: int = 32) -> Rect2i:
	var center_cell: Vector2i = Vector2i(floori(global_position.x / float(tile_size)), floori(global_position.y / float(tile_size)))
	return Rect2i(center_cell - Vector2i.ONE, FOOTPRINT_TILES)

func refresh_phase_from_health() -> void:
	_update_phase_from_health()

func _physics_process(delta: float) -> void:
	if not simulation_enabled:
		global_position = global_position.lerp(_network_position, 0.42)
		velocity = Vector2.ZERO
		return
	if not is_instance_valid(_health):
		_health = get_node_or_null("HealthComponent") as HealthComponent
	if not is_instance_valid(_health) or not _health.is_alive():
		velocity = Vector2.ZERO
		return
	_update_phase_from_health()
	_tick_skill_cooldowns(delta)
	if _state == State.CASTING:
		_process_casting(delta)
		return
	_validate_target()
	_scan_elapsed += delta
	if _target == null and _scan_elapsed >= TARGET_SCAN_INTERVAL:
		_scan_elapsed = 0.0
		_acquire_target()
	if is_instance_valid(_target):
		_out_of_combat_elapsed = 0.0
		if _try_start_next_skill():
			return
		_process_combat_target(delta)
		return
	_process_return_and_heal(delta)

func _tick_skill_cooldowns(delta: float) -> void:
	for skill_id: StringName in _skill_cooldowns.keys():
		_skill_cooldowns[skill_id] = maxf(0.0, _skill_cooldowns[skill_id] - delta)

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
		var candidate_radius: float = aggro_radius + candidate.combat_radius
		if distance <= candidate_radius * candidate_radius and distance < nearest_distance:
			nearest_distance = distance
			_target = candidate
	if _target == null:
		return
	_state = State.CHASING
	_out_of_combat_elapsed = 0.0
	_attack_elapsed = maxf(_attack_elapsed, get_attack_interval() * ATTACK_READY_ON_ACQUIRE)
	_clear_navigation()

func _validate_target() -> void:
	if _target == null:
		return
	if not is_instance_valid(_target) or not _target.is_alive():
		_drop_target()
		return
	var leash_radius: float = CHASE_RANGE_TILES * _tile_size + _target.combat_radius
	if _home_position.distance_to(_target.get_target_position()) > leash_radius:
		_drop_target()

func _drop_target() -> void:
	_target = null
	_state = State.RETURNING
	_attack_elapsed = 0.0
	_out_of_combat_elapsed = 0.0
	_clear_navigation()

func _process_combat_target(delta: float) -> void:
	if not is_instance_valid(_target):
		return
	var target_position: Vector2 = _target.get_target_position()
	var attack_radius: float = ATTACK_RANGE_TILES * _tile_size + _target.combat_radius
	if global_position.distance_to(target_position) > attack_radius:
		_state = State.CHASING
		_attack_elapsed = minf(get_attack_interval() * MOVING_ATTACK_CHARGE_LIMIT, _attack_elapsed + delta)
		_process_navigation(target_position)
		return
	velocity = Vector2.ZERO
	_clear_navigation()
	_attack_elapsed += delta
	var attack_interval: float = get_attack_interval()
	if _attack_elapsed < attack_interval:
		return
	_attack_elapsed -= attack_interval
	_target.apply_attack(get_attack_damage(), 0, 0.0, "%s的重击" % DISPLAY_NAME)
	_play_attack_reaction(target_position)
	play_attack_visual(target_position)
	attack_visual_requested.emit(boss_id, target_position)

func _try_start_next_skill() -> bool:
	if not is_instance_valid(_target):
		return false
	for offset: int in range(SKILL_IDS.size()):
		var index: int = (_skill_cycle_index + offset) % SKILL_IDS.size()
		var skill_id: StringName = SKILL_IDS[index]
		if get_skill_cooldown_remaining(skill_id) > 0.0:
			continue
		var positions: PackedVector2Array = _build_skill_positions(skill_id)
		if positions.is_empty():
			continue
		_skill_cycle_index = (index + 1) % SKILL_IDS.size()
		_start_skill_cast(skill_id, positions)
		return true
	return false

func _build_skill_positions(skill_id: StringName) -> PackedVector2Array:
	if not is_instance_valid(_target):
		return PackedVector2Array()
	var target_position: Vector2 = _target.get_target_position()
	match skill_id:
		SKILL_MOUNTAIN_BREAK:
			var cast_radius: float = MOUNTAIN_BREAK_RADIUS_TILES * _tile_size + _target.combat_radius
			return PackedVector2Array([global_position]) if global_position.distance_to(target_position) <= cast_radius else PackedVector2Array()
		SKILL_INFERNAL_CHARGE:
			var direction: Vector2 = global_position.direction_to(target_position)
			if direction.is_zero_approx():
				return PackedVector2Array()
			var charge_distance: float = minf(INFERNAL_CHARGE_MAX_TILES * _tile_size, global_position.distance_to(target_position))
			var end_position: Vector2 = global_position + direction * charge_distance
			var leash_radius: float = CHASE_RANGE_TILES * _tile_size
			if _home_position.distance_to(end_position) > leash_radius:
				end_position = _home_position + _home_position.direction_to(end_position) * leash_radius
			return PackedVector2Array([global_position, end_position])
		SKILL_HEAVENFIRE:
			var cast_limit: float = AGGRO_RANGE_TILES * _tile_size + _target.combat_radius
			if global_position.distance_to(target_position) > cast_limit:
				return PackedVector2Array()
			var angle: float = float((boss_id * 37 + _skill_cycle_index * 71) % 360) * PI / 180.0
			var spread: float = 2.15 * _tile_size
			return PackedVector2Array([
				target_position,
				target_position + Vector2.RIGHT.rotated(angle) * spread,
				target_position + Vector2.RIGHT.rotated(angle + TAU * 0.5) * spread,
			])
	return PackedVector2Array()

func _start_skill_cast(skill_id: StringName, positions: PackedVector2Array) -> void:
	_casting_skill = skill_id
	_cast_positions = positions
	_cast_remaining = _get_skill_warning(skill_id)
	_skill_cooldowns[skill_id] = get_skill_cooldown(skill_id)
	_state = State.CASTING
	velocity = Vector2.ZERO
	_attack_elapsed = 0.0
	play_skill_visual(skill_id, positions)
	skill_visual_requested.emit(boss_id, skill_id, positions)

func _process_casting(delta: float) -> void:
	velocity = Vector2.ZERO
	_cast_remaining = maxf(0.0, _cast_remaining - delta)
	if _cast_remaining > 0.0:
		return
	_resolve_skill(_casting_skill, _cast_positions)
	_casting_skill = &""
	_cast_positions = PackedVector2Array()
	_state = State.CHASING if is_instance_valid(_target) else State.RETURNING

func _resolve_skill(skill_id: StringName, positions: PackedVector2Array) -> void:
	if not _target_provider.is_valid() or positions.is_empty():
		return
	match skill_id:
		SKILL_MOUNTAIN_BREAK:
			_apply_radial_skill_damage(positions[0], MOUNTAIN_BREAK_RADIUS_TILES, get_skill_damage(skill_id), MOUNTAIN_BREAK_CONTROL_SECONDS)
		SKILL_INFERNAL_CHARGE:
			if positions.size() < 2:
				return
			_apply_charge_damage(positions[0], positions[1])
			var collision: KinematicCollision2D = move_and_collide(positions[1] - global_position)
			if collision == null:
				global_position = positions[1]
			_clear_navigation()
		SKILL_HEAVENFIRE:
			_apply_heavenfire_damage(positions)

func _apply_radial_skill_damage(center: Vector2, radius_tiles: float, raw_damage: float, control_seconds: float) -> void:
	for value: Variant in (_target_provider.call() as Array):
		var candidate: HealthComponent = value as HealthComponent
		if not is_instance_valid(candidate) or not candidate.is_alive():
			continue
		var radius: float = radius_tiles * _tile_size + candidate.combat_radius
		if center.distance_squared_to(candidate.get_target_position()) > radius * radius:
			continue
		candidate.apply_attack(raw_damage, 0, 0.0, _skill_source_description(SKILL_MOUNTAIN_BREAK))
		_apply_target_control(candidate, control_seconds)

func _apply_charge_damage(start_position: Vector2, end_position: Vector2) -> void:
	for value: Variant in (_target_provider.call() as Array):
		var candidate: HealthComponent = value as HealthComponent
		if not is_instance_valid(candidate) or not candidate.is_alive():
			continue
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(candidate.get_target_position(), start_position, end_position)
		var radius: float = INFERNAL_CHARGE_RADIUS_TILES * _tile_size + candidate.combat_radius
		if closest.distance_squared_to(candidate.get_target_position()) > radius * radius:
			continue
		candidate.apply_attack(get_skill_damage(SKILL_INFERNAL_CHARGE), 0, 0.0, _skill_source_description(SKILL_INFERNAL_CHARGE))
		_apply_target_control(candidate, INFERNAL_CHARGE_CONTROL_SECONDS)

func _apply_heavenfire_damage(positions: PackedVector2Array) -> void:
	for value: Variant in (_target_provider.call() as Array):
		var candidate: HealthComponent = value as HealthComponent
		if not is_instance_valid(candidate) or not candidate.is_alive():
			continue
		var radius: float = HEAVENFIRE_RADIUS_TILES * _tile_size + candidate.combat_radius
		for center: Vector2 in positions:
			if center.distance_squared_to(candidate.get_target_position()) <= radius * radius:
				candidate.apply_attack(get_skill_damage(SKILL_HEAVENFIRE), 0, 0.0, _skill_source_description(SKILL_HEAVENFIRE))
				break

func _skill_source_description(skill_id: StringName) -> String:
	var skill_name: String = "技能"
	match skill_id:
		SKILL_MOUNTAIN_BREAK:
			skill_name = "镇岳崩"
		SKILL_INFERNAL_CHARGE:
			skill_name = "炼狱冲阵"
		SKILL_HEAVENFIRE:
			skill_name = "天火劫"
	return "%s的%s" % [DISPLAY_NAME, skill_name]

func _apply_target_control(candidate: HealthComponent, duration: float) -> void:
	if candidate.is_alive() and is_instance_valid(candidate.target_root) and candidate.target_root.has_method(&"apply_control"):
		candidate.target_root.call(&"apply_control", duration)

func _process_return_and_heal(delta: float) -> void:
	if global_position.distance_to(_home_position) > ARRIVAL_DISTANCE:
		_state = State.RETURNING
		_out_of_combat_elapsed = 0.0
		_process_navigation(_home_position)
		return
	global_position = _home_position
	velocity = Vector2.ZERO
	_clear_navigation()
	_state = State.HEALING
	_out_of_combat_elapsed += delta
	if _out_of_combat_elapsed >= HEAL_DELAY_SECONDS and _health.current_health < _health.max_health:
		_health.heal(_health.max_health * HEAL_RATIO_PER_SECOND * delta)

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
	velocity = direction * get_movement_speed()
	move_and_slide()
	if not is_zero_approx(direction.x):
		sprite.flip_h = direction.x < 0.0

func _clear_navigation() -> void:
	_navigation_path = PackedVector2Array()
	_navigation_index = 0
	_navigation_elapsed = PATH_REFRESH_INTERVAL
	_navigation_target = Vector2.INF

func _update_phase_from_health() -> void:
	if not is_instance_valid(_health):
		return
	var next_phase: int = 2 if _health.get_health_ratio() <= PHASE_TWO_HEALTH_RATIO else 1
	_set_phase(next_phase, true)

func _set_phase(next_phase: int, should_emit: bool) -> void:
	if _phase == next_phase:
		return
	_phase = next_phase
	_update_phase_visuals(true)
	if should_emit:
		phase_changed.emit(boss_id, _phase)

func _update_phase_visuals(roar: bool) -> void:
	aura.visible = _phase == 2
	name_label.modulate = Color("#ffbd48") if _phase == 2 else Color.WHITE
	if not roar or _phase != 2:
		return
	var original_scale: Vector2 = sprite.scale
	var tween: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", original_scale * 1.14, 0.16)
	tween.tween_property(sprite, "scale", original_scale, 0.28)

func _current_interval_multiplier() -> float:
	return _interval_multiplier * (PHASE_TWO_INTERVAL_MULTIPLIER if _phase == 2 else 1.0)

func _get_skill_warning(skill_id: StringName) -> float:
	match skill_id:
		SKILL_MOUNTAIN_BREAK:
			return MOUNTAIN_BREAK_WARNING
		SKILL_INFERNAL_CHARGE:
			return INFERNAL_CHARGE_WARNING
		SKILL_HEAVENFIRE:
			return HEAVENFIRE_WARNING
	return 0.0

func _play_attack_reaction(target_position: Vector2) -> void:
	if is_instance_valid(_attack_tween):
		_attack_tween.kill()
	var direction: Vector2 = global_position.direction_to(target_position)
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	var start_position: Vector2 = sprite.position
	_attack_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_attack_tween.tween_property(sprite, "position", start_position + direction * 10.0, 0.10)
	_attack_tween.tween_property(sprite, "position", start_position, 0.16)

func play_attack_visual(target_position: Vector2) -> void:
	var direction: Vector2 = global_position.direction_to(target_position)
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	var vfx: Sprite2D = _make_vfx_sprite(INFERNAL_CHARGE_TEXTURE, 62.0, 10)
	vfx.rotation = direction.angle()
	vfx.global_position = global_position + direction * 36.0
	var tween: Tween = vfx.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(vfx, "global_position", target_position, 0.30)
	tween.parallel().tween_property(vfx, "modulate:a", 0.20, 0.30)
	tween.tween_callback(vfx.queue_free)

func play_skill_visual(skill_id: StringName, positions: PackedVector2Array) -> void:
	if positions.is_empty():
		return
	match skill_id:
		SKILL_MOUNTAIN_BREAK:
			_play_area_telegraph(
				positions[0],
				MOUNTAIN_BREAK_RADIUS_TILES,
				MOUNTAIN_BREAK_WARNING,
				MOUNTAIN_BREAK_TEXTURE,
				sprite.z_index - 1
			)
		SKILL_INFERNAL_CHARGE:
			if positions.size() >= 2:
				_play_charge_telegraph(positions[0], positions[1])
		SKILL_HEAVENFIRE:
			for center: Vector2 in positions:
				_play_area_telegraph(center, HEAVENFIRE_RADIUS_TILES, HEAVENFIRE_WARNING, HEAVENFIRE_TEXTURE)

func _play_area_telegraph(
	center: Vector2,
	radius_tiles: float,
	warning_seconds: float,
	texture: Texture2D,
	effect_layer: int = 7
) -> void:
	var radius: float = radius_tiles * _tile_size
	var ring: Line2D = _make_circle_ring(center, radius, mini(effect_layer, 6))
	ring.modulate = Color(1.0, 0.12, 0.02, 0.18)
	var ring_tween: Tween = ring.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	ring_tween.tween_property(ring, "modulate:a", 0.95, warning_seconds)
	ring_tween.tween_property(ring, "modulate:a", 0.0, 0.24)
	ring_tween.tween_callback(ring.queue_free)
	var impact: Sprite2D = _make_vfx_sprite(texture, radius * 2.0, effect_layer)
	impact.global_position = center
	impact.modulate.a = 0.0
	var final_scale: Vector2 = impact.scale
	impact.scale = final_scale * 0.68
	var impact_tween: Tween = impact.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	impact_tween.tween_interval(warning_seconds)
	impact_tween.tween_property(impact, "scale", final_scale, 0.18)
	impact_tween.parallel().tween_property(impact, "modulate:a", 0.94, 0.12)
	impact_tween.tween_interval(0.22)
	impact_tween.tween_property(impact, "modulate:a", 0.0, 0.42)
	impact_tween.parallel().tween_property(impact, "scale", final_scale * 1.08, 0.42)
	impact_tween.tween_callback(impact.queue_free)

func _play_charge_telegraph(start_position: Vector2, end_position: Vector2) -> void:
	var direction: Vector2 = start_position.direction_to(end_position)
	var normal: Vector2 = direction.orthogonal() * INFERNAL_CHARGE_RADIUS_TILES * _tile_size
	var corridor := Polygon2D.new()
	corridor.name = "InfernalChargeWarning"
	corridor.polygon = PackedVector2Array([start_position + normal, end_position + normal, end_position - normal, start_position - normal])
	corridor.color = Color(0.95, 0.08, 0.015, 0.20)
	corridor.z_index = 5
	add_child(corridor)
	corridor.top_level = true
	var corridor_tween: Tween = corridor.create_tween()
	corridor_tween.tween_property(corridor, "color:a", 0.72, INFERNAL_CHARGE_WARNING)
	corridor_tween.tween_property(corridor, "color:a", 0.0, 0.24)
	corridor_tween.tween_callback(corridor.queue_free)
	var distance: float = start_position.distance_to(end_position)
	var count: int = maxi(2, ceili(distance / CHARGE_SEGMENT_SPACING))
	for index: int in range(count + 1):
		var segment: Sprite2D = _make_vfx_sprite(INFERNAL_CHARGE_TEXTURE, 68.0, 8)
		segment.global_position = start_position.lerp(end_position, float(index) / float(count))
		segment.rotation = direction.angle()
		segment.modulate.a = 0.0
		var tween: Tween = segment.create_tween()
		tween.tween_interval(INFERNAL_CHARGE_WARNING)
		tween.tween_property(segment, "modulate:a", 0.88, 0.10)
		tween.tween_interval(0.24)
		tween.tween_property(segment, "modulate:a", 0.0, 0.42)
		tween.tween_callback(segment.queue_free)

func _make_circle_ring(center: Vector2, radius: float, layer: int = 6) -> Line2D:
	var ring := Line2D.new()
	ring.name = "BossSkillWarningRing"
	ring.width = 4.0
	ring.default_color = Color("#ff5a20")
	ring.antialiased = true
	ring.z_index = layer
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(65):
		points.append(center + Vector2.RIGHT.rotated(TAU * float(index) / 64.0) * radius)
	ring.points = points
	add_child(ring)
	ring.top_level = true
	return ring

func _make_vfx_sprite(texture: Texture2D, display_max_dimension: float, layer: int) -> Sprite2D:
	var vfx := Sprite2D.new()
	vfx.texture = texture
	vfx.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	vfx.z_index = layer
	var texture_size: Vector2 = texture.get_size()
	var scale_value: float = display_max_dimension / maxf(1.0, maxf(texture_size.x, texture_size.y))
	vfx.scale = Vector2.ONE * scale_value
	add_child(vfx)
	vfx.top_level = true
	return vfx

func _fit_sprite_height(target_sprite: Sprite2D, display_height: float) -> void:
	target_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var texture_height: float = maxf(1.0, target_sprite.texture.get_size().y)
	target_sprite.scale = Vector2.ONE * (display_height / texture_height)

func _fit_sprite_width(target_sprite: Sprite2D, display_width: float) -> void:
	target_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var texture_width: float = maxf(1.0, target_sprite.texture.get_size().x)
	target_sprite.scale = Vector2.ONE * (display_width / texture_width)

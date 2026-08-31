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
const GENERATED_VFX_SCALE_THRESHOLD: float = 320.0
const GENERATED_ATTACK_VFX_DISPLAY_SIZE: float = 72.0
const GENERATED_SKILL_VFX_DISPLAY_SIZE: float = 144.0
const MAX_STAR_LEVEL: int = 3
const STAR_STAT_MULTIPLIERS: Array[float] = [1.0, 3.25, 10.75]
const PHOTOSYNTHESIS_FRAMES_R104: SpriteFrames = preload("res://game/units/vfx/treant_skill_green_particles_r104_frames.tres")
const PHOTOSYNTHESIS_FRAMES_R112: SpriteFrames = preload("res://game/units/vfx/treant_skill_green_particles_r112_frames.tres")
const PHOTOSYNTHESIS_FRAMES_R120: SpriteFrames = preload("res://game/units/vfx/treant_skill_green_particles_r120_frames.tres")
const PHOTOSYNTHESIS_FRAMES_R128: SpriteFrames = preload("res://game/units/vfx/treant_skill_green_particles_r128_frames.tres")

@onready var sprite: Sprite2D = $Sprite

var unit_id: int = 0
var owner_peer_id: int = 0
var territory_id: int = 0
var definition: UnitDefinition
var star_level: int = 1
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
var _forced_taunt_remaining: float = 0.0
var _forced_taunt_target: HealthComponent
var _combat_buff_durations: Dictionary[StringName, float] = {}
var _attack_bonus_percent_by_source: Dictionary[StringName, float] = {}
var _movement_bonus_percent_by_source: Dictionary[StringName, float] = {}
var _attack_tween: Tween
var _attack_vfx: AnimatedSprite2D
var _skill_vfx: AnimatedSprite2D
var _sprite_base_scale: Vector2 = Vector2.ONE
var _star_label: Label
var _status: CombatStatusController

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
	star_level = 1
	_configure_unit_art()
	_refresh_star_label()
	_configure_skill_vfx_frames()
	queue_redraw()

func set_star_level(new_star_level: int) -> void:
	if definition == null or definition.category != UnitDefinition.Category.COMBAT:
		star_level = 1
		_refresh_star_label()
		return
	star_level = clampi(new_star_level, 1, MAX_STAR_LEVEL)
	_refresh_star_label()
	if not is_instance_valid(_health):
		_health = get_node_or_null("HealthComponent") as HealthComponent
	if is_instance_valid(_health):
		_health.set_max_health(get_effective_max_health())
		_health.set_base_defense(get_effective_defense())

func get_star_stat_multiplier() -> float:
	return STAR_STAT_MULTIPLIERS[clampi(star_level, 1, MAX_STAR_LEVEL) - 1]

func get_effective_max_health() -> float:
	return float(definition.max_health) * get_star_stat_multiplier() if definition != null else 1.0

func get_effective_attack() -> float:
	return float(definition.attack) * get_star_stat_multiplier() if definition != null else 0.0

func get_effective_defense() -> float:
	return float(definition.defense) * get_star_stat_multiplier() if definition != null else 0.0

func get_effective_skill_damage() -> float:
	return definition.get_skill_damage() * get_star_stat_multiplier() if definition != null else 0.0

func setup_combat_context(enemy_provider: Callable, ally_provider: Callable, path_provider: Callable, tile_size: int) -> void:
	_enemy_provider = enemy_provider
	_ally_provider = ally_provider
	_path_provider = path_provider
	_tile_size = float(tile_size)
	_health = get_node_or_null("HealthComponent") as HealthComponent
	_ensure_status_controller()

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
	_forced_taunt_target = null
	_forced_taunt_remaining = 0.0
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
	if definition.attack_vfx_placement == UnitDefinition.AttackVfxPlacement.TARGET_CENTER or definition.skill_id == &"photosynthesis":
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
	if definition != null and definition.combat_skill != null:
		match definition.combat_skill.vfx_placement:
			CombatSkillDefinition.VfxPlacement.TARGET_CENTER, CombatSkillDefinition.VfxPlacement.AREA_CENTER:
				_skill_vfx.position = to_local(target_position)
			CombatSkillDefinition.VfxPlacement.CASTER_FORWARD:
				var configured_direction: Vector2 = global_position.direction_to(target_position)
				if configured_direction.is_zero_approx():
					configured_direction = Vector2.RIGHT
				_skill_vfx.position = configured_direction * 18.0
				_skill_vfx.rotation = configured_direction.angle()
			_:
				pass
		_restart_vfx(_skill_vfx)
		return
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
	_forced_taunt_remaining = maxf(0.0, _forced_taunt_remaining - delta)
	if _forced_taunt_remaining <= 0.0:
		_forced_taunt_target = null
	_skill_cooldown_remaining = maxf(0.0, _skill_cooldown_remaining - delta)
	_update_temporary_combat_effects(delta)
	if _control_remaining > 0.0 or (is_instance_valid(_status) and _status.is_stunned()):
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
	if is_instance_valid(_status) and _status.is_rooted():
		velocity = Vector2.ZERO
		return
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
		if is_instance_valid(_status) and _status.is_rooted():
			velocity = Vector2.ZERO
			return
		var ready_limit: float = get_effective_attack_interval() * MOVING_ATTACK_CHARGE_LIMIT
		_attack_elapsed = minf(ready_limit, _attack_elapsed + delta)
		move_target = target_position
		has_move_target = true
		_process_combat_navigation(delta, target_position)
		return
	_clear_combat_navigation()
	velocity = Vector2.ZERO
	has_move_target = false
	_attack_elapsed += delta
	var effective_attack_interval: float = get_effective_attack_interval()
	if _attack_elapsed < effective_attack_interval:
		return
	_attack_elapsed -= effective_attack_interval
	_combat_target.apply_attack(get_effective_attack() * get_attack_multiplier(), owner_peer_id)
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
	if is_instance_valid(_forced_taunt_target) and _forced_taunt_target.is_alive() and _forced_taunt_remaining > 0.0:
		_combat_target = _forced_taunt_target
		return
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
	if definition.combat_skill != null:
		_process_configured_skill(delta)
		return
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

func _process_configured_skill(delta: float) -> void:
	var skill: CombatSkillDefinition = definition.combat_skill
	if skill == null or skill.mana_cost <= 0 or _skill_cooldown_remaining > 0.0:
		return
	_skill_scan_elapsed += delta
	if _skill_scan_elapsed < SKILL_SCAN_INTERVAL:
		return
	_skill_scan_elapsed = 0.0
	if _health.current_mana + 0.001 < float(skill.mana_cost):
		return
	var targets: Array[HealthComponent] = []
	var visual_position: Vector2 = global_position
	if skill.target_mode in [CombatSkillDefinition.TargetMode.SELF, CombatSkillDefinition.TargetMode.LOWEST_HEALTH_ALLY, CombatSkillDefinition.TargetMode.ALLY_AREA, CombatSkillDefinition.TargetMode.DEBUFFED_ALLIES]:
		targets = _select_friendly_skill_targets(skill)
		if not targets.is_empty():
			visual_position = targets[0].get_target_position()
	else:
		var selection: Dictionary = _select_enemy_skill_targets(skill)
		targets = selection.get("targets", []) as Array[HealthComponent]
		visual_position = selection.get("position", global_position) as Vector2
	if targets.is_empty():
		return
	if skill.skill_id == &"cloudstep_combo" and not _perform_cloudstep(targets[0]):
		return
	if not _health.spend_mana(float(skill.mana_cost)):
		return
	_apply_configured_skill(skill, targets)
	_skill_cooldown_remaining = skill.cooldown_seconds
	_attack_elapsed = 0.0
	play_skill_visual(skill.skill_id, visual_position)
	var visual_target: HealthComponent = targets[0]
	var target_root: Node2D = visual_target.target_root
	var target_kind: StringName = target_root.get_meta(&"damageable_kind", &"") as StringName if is_instance_valid(target_root) else &""
	var target_id: int = int(target_root.get_meta(&"damageable_id", 0)) if is_instance_valid(target_root) else 0
	skill_visual_requested.emit(unit_id, skill.skill_id, visual_position, target_kind, target_id)

func _select_friendly_skill_targets(skill: CombatSkillDefinition) -> Array[HealthComponent]:
	var result: Array[HealthComponent] = []
	if skill.target_mode == CombatSkillDefinition.TargetMode.SELF:
		var nearby_enemies: Array[HealthComponent] = _valid_enemies_within(skill.radius_tiles)
		if nearby_enemies.is_empty():
			return result
		result.append(_health)
		return result
	if not _ally_provider.is_valid():
		return result
	var radius_squared: float = pow(skill.radius_tiles * _tile_size, 2.0)
	var lowest: HealthComponent
	var lowest_ratio: float = INF
	for value: Variant in _ally_provider.call():
		var ally: HealthComponent = value as HealthComponent
		if not is_instance_valid(ally) or not ally.is_alive() or global_position.distance_squared_to(ally.get_target_position()) > radius_squared:
			continue
		if skill.target_mode in [CombatSkillDefinition.TargetMode.LOWEST_HEALTH_ALLY, CombatSkillDefinition.TargetMode.ALLY_AREA, CombatSkillDefinition.TargetMode.DEBUFFED_ALLIES] and ally.target_root is not TreantUnit:
			continue
		if skill.target_mode == CombatSkillDefinition.TargetMode.LOWEST_HEALTH_ALLY:
			var health_ratio: float = ally.get_health_ratio()
			if health_ratio <= skill.trigger_health_ratio and health_ratio < lowest_ratio:
				lowest = ally
				lowest_ratio = health_ratio
		elif skill.target_mode == CombatSkillDefinition.TargetMode.DEBUFFED_ALLIES:
			var ally_status: CombatStatusController = _status_for_health(ally)
			if is_instance_valid(ally_status) and ally_status.has_cleanseable_debuff():
				result.append(ally)
		else:
			result.append(ally)
	if skill.target_mode == CombatSkillDefinition.TargetMode.LOWEST_HEALTH_ALLY and is_instance_valid(lowest):
		result.append(lowest)
	if skill.target_mode == CombatSkillDefinition.TargetMode.ALLY_AREA:
		if result.size() < 2 or _valid_enemies_within(skill.cast_range_tiles).is_empty():
			result.clear()
	return result

func _select_enemy_skill_targets(skill: CombatSkillDefinition) -> Dictionary:
	var result: Array[HealthComponent] = []
	var candidates: Array[HealthComponent] = _valid_enemies_within(skill.cast_range_tiles)
	if candidates.is_empty():
		return {"targets": result, "position": global_position}
	if skill.shape == CombatSkillDefinition.Shape.SELF_AREA:
		result = _valid_enemies_within(skill.radius_tiles)
		return {"targets": result, "position": global_position}
	if skill.shape == CombatSkillDefinition.Shape.LINE or skill.shape == CombatSkillDefinition.Shape.CONE:
		result = _best_directional_targets(skill, candidates)
		return {"targets": result, "position": result[0].get_target_position() if not result.is_empty() else global_position}
	if skill.shape == CombatSkillDefinition.Shape.CIRCLE or skill.target_mode == CombatSkillDefinition.TargetMode.ENEMY_CLUSTER:
		var best_center: Vector2 = candidates[0].get_target_position()
		for center_candidate: HealthComponent in candidates:
			var center: Vector2 = center_candidate.get_target_position()
			var group: Array[HealthComponent] = []
			for candidate: HealthComponent in candidates:
				var effective_radius: float = skill.radius_tiles * _tile_size + candidate.combat_radius
				if center.distance_squared_to(candidate.get_target_position()) <= effective_radius * effective_radius:
					group.append(candidate)
			if group.size() > result.size():
				result = group
				best_center = center
		return {"targets": result, "position": best_center}
	var primary: HealthComponent = _choose_primary_enemy(skill, candidates)
	if not is_instance_valid(primary):
		return {"targets": result, "position": global_position}
	result.append(primary)
	if skill.shape == CombatSkillDefinition.Shape.CHAIN:
		var current: HealthComponent = primary
		while result.size() < skill.max_targets:
			var next: HealthComponent
			var next_distance: float = INF
			for candidate: HealthComponent in candidates:
				if result.has(candidate):
					continue
				var distance: float = current.get_target_position().distance_squared_to(candidate.get_target_position())
				if distance <= pow(skill.chain_range_tiles * _tile_size, 2.0) and distance < next_distance:
					next = candidate
					next_distance = distance
			if not is_instance_valid(next):
				break
			result.append(next)
			current = next
	return {"targets": result, "position": primary.get_target_position()}

func _choose_primary_enemy(skill: CombatSkillDefinition, candidates: Array[HealthComponent]) -> HealthComponent:
	var chosen: HealthComponent = candidates[0]
	match skill.target_mode:
		CombatSkillDefinition.TargetMode.LOW_HEALTH_ENEMY:
			var lowest_ratio: float = INF
			chosen = null
			for candidate: HealthComponent in candidates:
				var ratio: float = candidate.get_health_ratio()
				if ratio <= skill.trigger_health_ratio and ratio < lowest_ratio:
					chosen = candidate
					lowest_ratio = ratio
		CombatSkillDefinition.TargetMode.HIGHEST_DEFENSE_ENEMY:
			for candidate: HealthComponent in candidates:
				if candidate.defense > chosen.defense:
					chosen = candidate
		CombatSkillDefinition.TargetMode.HIGHEST_MAX_HEALTH_ENEMY:
			for candidate: HealthComponent in candidates:
				if candidate.max_health > chosen.max_health:
					chosen = candidate
		_:
			var nearest_distance: float = global_position.distance_squared_to(chosen.get_target_position())
			for candidate: HealthComponent in candidates:
				var distance: float = global_position.distance_squared_to(candidate.get_target_position())
				if distance < nearest_distance:
					chosen = candidate
					nearest_distance = distance
	return chosen

func _best_directional_targets(skill: CombatSkillDefinition, candidates: Array[HealthComponent]) -> Array[HealthComponent]:
	var best: Array[HealthComponent] = []
	var range_world: float = skill.cast_range_tiles * _tile_size
	for aim: HealthComponent in candidates:
		var direction: Vector2 = global_position.direction_to(aim.get_target_position())
		var group: Array[HealthComponent] = []
		for candidate: HealthComponent in candidates:
			var offset: Vector2 = candidate.get_target_position() - global_position
			if offset.length() > range_world + candidate.combat_radius:
				continue
			if skill.shape == CombatSkillDefinition.Shape.LINE:
				var projection: float = offset.dot(direction)
				var perpendicular: float = absf(offset.cross(direction))
				if projection >= 0.0 and perpendicular <= skill.line_width_tiles * _tile_size * 0.5 + candidate.combat_radius:
					group.append(candidate)
			else:
				var angle: float = absf(rad_to_deg(direction.angle_to(offset.normalized())))
				if angle <= skill.cone_angle_degrees * 0.5:
					group.append(candidate)
		if group.size() > best.size():
			best = group
	return best

func _valid_enemies_within(radius_tiles: float) -> Array[HealthComponent]:
	var result: Array[HealthComponent] = []
	if not _enemy_provider.is_valid():
		return result
	for value: Variant in _enemy_provider.call():
		var enemy: HealthComponent = value as HealthComponent
		if not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		var radius: float = radius_tiles * _tile_size + enemy.combat_radius
		if global_position.distance_squared_to(enemy.get_target_position()) <= radius * radius:
			result.append(enemy)
	return result

func _apply_configured_skill(skill: CombatSkillDefinition, targets: Array[HealthComponent]) -> void:
	var source_id: StringName = StringName("%s_%d" % [skill.skill_id, unit_id])
	var fixed_scale: float = get_star_stat_multiplier()
	for target: HealthComponent in targets:
		if skill.damage_multiplier > 0.0:
			target.apply_attack(get_effective_attack() * skill.damage_multiplier, owner_peer_id, skill.defense_ignore_ratio)
		if skill.heal_percent > 0.0:
			target.heal(target.max_health * skill.heal_percent)
		if not is_zero_approx(skill.defense_modifier):
			target.apply_temporary_defense_modifier(source_id, skill.defense_modifier * fixed_scale, skill.effect_duration_seconds)
		var target_status: CombatStatusController = _status_for_health(target)
		if is_instance_valid(target_status):
			_apply_status_effects(skill, target_status, target, source_id)
		var target_unit: TreantUnit = target.target_root as TreantUnit
		if is_instance_valid(target_unit):
			if skill.attack_bonus_ratio > 0.0 or skill.movement_bonus_ratio > 0.0:
				target_unit.apply_combat_buff(source_id, skill.attack_bonus_ratio * 100.0, skill.movement_bonus_ratio * 100.0, skill.effect_duration_seconds)
			if skill.knockback_tiles > 0.0:
				target_unit.apply_knockback(global_position.direction_to(target.get_target_position()), skill.knockback_tiles * _tile_size)
	if skill.taunt_duration_seconds > 0.0:
		for enemy: HealthComponent in _valid_enemies_within(skill.radius_tiles):
			var enemy_unit: TreantUnit = enemy.target_root as TreantUnit
			if is_instance_valid(enemy_unit):
				enemy_unit.force_taunt(_health, skill.taunt_duration_seconds)

func _apply_status_effects(skill: CombatSkillDefinition, status: CombatStatusController, _target: HealthComponent, source_id: StringName) -> void:
	if skill.control_type == CombatSkillDefinition.ControlType.ROOT:
		status.apply_root(skill.control_duration_seconds)
	elif skill.control_type == CombatSkillDefinition.ControlType.STUN:
		status.apply_stun(skill.control_duration_seconds)
	if skill.movement_slow_ratio > 0.0:
		status.apply_movement_slow(skill.movement_slow_ratio, skill.effect_duration_seconds)
	if skill.attack_interval_increase_ratio > 0.0:
		status.apply_attack_slow(skill.attack_interval_increase_ratio, skill.effect_duration_seconds)
	if skill.damage_taken_bonus_ratio > 0.0:
		status.apply_damage_amp(skill.damage_taken_bonus_ratio, skill.effect_duration_seconds)
	if skill.next_hit_reduction_ratio > 0.0:
		status.apply_next_hit_reduction(skill.next_hit_reduction_ratio, skill.effect_duration_seconds)
	if skill.control_duration_reduction_ratio > 0.0:
		status.apply_control_resistance(skill.control_duration_reduction_ratio, skill.effect_duration_seconds)
	if skill.dot_damage_multiplier > 0.0:
		status.apply_dot(source_id, get_effective_attack() * skill.dot_damage_multiplier, skill.dot_duration_seconds, skill.dot_interval_seconds, owner_peer_id)
	if skill.reveal_radius_tiles > 0.0:
		status.reveal_to_peer(owner_peer_id, skill.effect_duration_seconds)
	if skill.cleanse_damage_over_time or skill.cleanse_movement_slow or skill.cleanse_attack_slow or skill.cleanse_defense_reduction or skill.cleanse_control:
		status.cleanse(skill.cleanse_damage_over_time, skill.cleanse_movement_slow, skill.cleanse_attack_slow, skill.cleanse_defense_reduction, skill.cleanse_control)
	if skill.grant_control_immunity:
		status.apply_control_immunity(skill.effect_duration_seconds)

func _status_for_health(health: HealthComponent) -> CombatStatusController:
	if not is_instance_valid(health) or not is_instance_valid(health.target_root):
		return null
	return health.target_root.get_node_or_null("CombatStatusController") as CombatStatusController

func _perform_cloudstep(target: HealthComponent) -> bool:
	if not is_instance_valid(target) or not target.is_alive():
		return false
	var target_position: Vector2 = target.get_target_position()
	var direction: Vector2 = global_position.direction_to(target_position)
	if direction.is_zero_approx():
		return true
	var desired_position: Vector2 = target_position - direction * (definition.attack_range_tiles * _tile_size + target.combat_radius)
	if _path_provider.is_valid():
		var path: PackedVector2Array = _path_provider.call(global_position, desired_position) as PackedVector2Array
		if path.is_empty():
			return false
	var collision: KinematicCollision2D = move_and_collide(desired_position - global_position)
	if collision != null and global_position.distance_to(target_position) > definition.attack_range_tiles * _tile_size + target.combat_radius:
		return false
	return true

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
	var skill_damage: float = get_effective_skill_damage()
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
	if definition == null:
		return
	if is_instance_valid(_attack_vfx) and definition.attack_vfx_frames != null:
		_attack_vfx.sprite_frames = definition.attack_vfx_frames
		_fit_generated_vfx(_attack_vfx, GENERATED_ATTACK_VFX_DISPLAY_SIZE)
	if is_instance_valid(_skill_vfx) and definition.combat_skill != null and definition.combat_skill.vfx_frames != null:
		_skill_vfx.sprite_frames = definition.combat_skill.vfx_frames
		_fit_generated_vfx(_skill_vfx, GENERATED_SKILL_VFX_DISPLAY_SIZE)
		return
	if not is_instance_valid(_skill_vfx) or definition.skill_id != &"photosynthesis":
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
	_fit_generated_vfx(_skill_vfx, GENERATED_SKILL_VFX_DISPLAY_SIZE)

func _fit_generated_vfx(vfx: AnimatedSprite2D, display_size: float) -> void:
	vfx.scale = Vector2.ONE
	if vfx.sprite_frames == null or vfx.sprite_frames.get_frame_count(&"default") <= 0:
		return
	var frame_texture: Texture2D = vfx.sprite_frames.get_frame_texture(&"default", 0)
	if frame_texture == null:
		return
	var frame_size: Vector2 = frame_texture.get_size()
	var longest_edge: float = maxf(frame_size.x, frame_size.y)
	if longest_edge <= GENERATED_VFX_SCALE_THRESHOLD:
		return
	var display_scale: float = display_size / longest_edge
	vfx.scale = Vector2.ONE * display_scale

func _configure_unit_art() -> void:
	if definition == null or definition.card_texture == null:
		return
	sprite.texture = definition.card_texture
	var texture_size: Vector2 = definition.card_texture.get_size()
	var longest_edge: float = maxf(texture_size.x, texture_size.y)
	if longest_edge <= 0.0:
		return
	var display_scale: float = 30.0 / longest_edge
	sprite.scale = Vector2.ONE * display_scale
	_sprite_base_scale = sprite.scale.abs()

func _restart_vfx(vfx: AnimatedSprite2D) -> void:
	vfx.stop()
	vfx.frame = 0
	vfx.visible = true
	vfx.play(&"default")

func _hide_vfx(vfx: AnimatedSprite2D) -> void:
	vfx.visible = false

func apply_control(duration: float) -> void:
	if is_instance_valid(_status) and _status.is_control_immune():
		return
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
	var status_multiplier: float = _status.get_movement_multiplier() if is_instance_valid(_status) else 1.0
	return (1.0 + _sum_modifier_percent(_movement_bonus_percent_by_source) / 100.0) * status_multiplier

func get_effective_attack_interval() -> float:
	var status_multiplier: float = _status.get_attack_interval_multiplier() if is_instance_valid(_status) else 1.0
	return definition.attack_interval_seconds * status_multiplier

func force_taunt(target: HealthComponent, duration: float) -> void:
	if not is_instance_valid(target) or duration <= 0.0:
		return
	_forced_taunt_target = target
	_forced_taunt_remaining = maxf(_forced_taunt_remaining, duration)
	_combat_target = target

func clear_forced_taunt() -> void:
	_forced_taunt_target = null
	_forced_taunt_remaining = 0.0

func clear_control_state() -> void:
	_control_remaining = 0.0

func apply_knockback(direction: Vector2, distance: float) -> void:
	if not simulation_enabled or direction.is_zero_approx() or distance <= 0.0:
		return
	move_and_collide(direction.normalized() * distance)

func is_revealed_to_peer(peer_id: int) -> bool:
	return is_instance_valid(_status) and _status.is_revealed_to_peer(peer_id)

func get_combat_status_network_state() -> Dictionary:
	return _status.get_network_state() if is_instance_valid(_status) else {}

func apply_combat_status_network_state(state: Dictionary) -> void:
	_ensure_status_controller()
	_status.apply_network_state(state)

func _ensure_status_controller() -> void:
	_status = get_node_or_null("CombatStatusController") as CombatStatusController
	if not is_instance_valid(_status):
		_status = CombatStatusController.new()
		_status.name = "CombatStatusController"
		add_child(_status)
	_status.configure(self, _health)

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

func _refresh_star_label() -> void:
	var should_show: bool = definition != null and definition.category == UnitDefinition.Category.COMBAT
	if not should_show:
		if is_instance_valid(_star_label):
			_star_label.hide()
		return
	if not is_instance_valid(_star_label):
		_star_label = Label.new()
		_star_label.name = "StarLabel"
		_star_label.position = Vector2(-36.0, -47.0)
		_star_label.size = Vector2(72.0, 18.0)
		_star_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_star_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_star_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_star_label.z_index = 960
		_star_label.add_theme_font_size_override(&"font_size", 14)
		_star_label.add_theme_color_override(&"font_outline_color", Color("#1a1205"))
		_star_label.add_theme_constant_override(&"outline_size", 4)
		add_child(_star_label)
	var star_text: String = ""
	for _index: int in star_level:
		star_text += "★"
	_star_label.text = star_text
	_star_label.add_theme_color_override(&"font_color", _star_color())
	_star_label.show()

func _star_color() -> Color:
	match star_level:
		2:
			return Color("#ffe16b")
		3:
			return Color("#ff9f43")
		_:
			return Color("#f4f4f4")

func _draw() -> void:
	if _selected:
		draw_ellipse(Vector2(0.0, 11.0), 15.0, 7.0, Color("#b31f24b0"), false, 2.0, true)

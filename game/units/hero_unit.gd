class_name HeroUnit
extends TreantUnit

const HeroProgressionData: Script = preload("res://game/data/hero_progression.gd")
const CONFUCIUS_PASSIVE_ID: StringName = &"you_jiao_wu_lei"
const CONFUCIUS_Q_ID: StringName = &"ren_zhe_ai_ren"
const CONFUCIUS_W_ID: StringName = &"li_yue_jiao_hua"
const CONFUCIUS_E_ID: StringName = &"zhou_you_lie_guo"
const CONFUCIUS_E_ARRIVAL_VFX_ID: StringName = &"zhou_you_lie_guo_arrival"
const PASSIVE_REFRESH_INTERVAL: float = 0.25
const Q_VFX_DIAMETER: float = 112.0
const W_VFX_DIAMETER: float = 192.0
const E_TRAVEL_VFX_DIAMETER: float = 112.0
const E_ARRIVAL_VFX_DIAMETER: float = 224.0
const Q_VFX_FRAMES: SpriteFrames = preload("res://game/units/vfx/confucius_q_benevolence_frames.tres")
const W_VFX_FRAMES: SpriteFrames = preload("res://game/units/vfx/confucius_w_ritual_field_frames.tres")
const E_VFX_FRAMES: SpriteFrames = preload("res://game/units/vfx/confucius_e_travel_inspiration_frames.tres")

var hero_level: int = 1
var skill_levels: Dictionary[StringName, int] = {}
var skill_cooldowns: Dictionary[StringName, float] = {}
var _travel_active: bool = false
var _travel_destination: Vector2 = Vector2.ZERO
var _passive_refresh_elapsed: float = 0.0

func configure_network(new_unit_id: int, new_owner_peer_id: int, new_territory_id: int, new_definition: UnitDefinition, should_simulate: bool) -> void:
	super.configure_network(new_unit_id, new_owner_peer_id, new_territory_id, new_definition, should_simulate)
	hero_level = 1
	skill_levels.clear()
	skill_cooldowns.clear()
	_travel_active = false
	_passive_refresh_elapsed = PASSIVE_REFRESH_INTERVAL
	if definition != null and definition.category == UnitDefinition.Category.HERO:
		var hero_definition: Resource = definition as Resource
		var passive: Resource = hero_definition.get("passive_skill") as Resource
		if passive != null:
			skill_levels[StringName(str(passive.get("skill_id")))] = 1
		var skills: Array = hero_definition.get("active_skills") as Array
		for skill_value: Variant in skills:
			var skill: Resource = skill_value as Resource
			if skill != null:
				skill_levels[StringName(str(skill.get("skill_id")))] = 1

func _physics_process(delta: float) -> void:
	for skill_id: StringName in skill_cooldowns.keys():
		skill_cooldowns[skill_id] = maxf(0.0, float(skill_cooldowns[skill_id]) - delta)
	if simulation_enabled:
		_process_passive_aura(delta)
	if _travel_active and not has_move_target:
		var reached_destination: bool = global_position.distance_to(_travel_destination) <= ARRIVAL_DISTANCE + 1.0
		_travel_active = false
		if reached_destination:
			_apply_travel_inspiration()
	super._physics_process(delta)

func _process_skill(_delta: float) -> void:
	pass

func get_attack_multiplier() -> float:
	return HeroProgressionData.stat_multiplier(hero_level) * super.get_attack_multiplier()

func get_movement_multiplier() -> float:
	var travel_multiplier: float = 2.0 if _travel_active else 1.0
	return travel_multiplier * super.get_movement_multiplier()

func set_hero_progression(new_hero_level: int, new_skill_levels: Dictionary) -> void:
	hero_level = clampi(new_hero_level, 1, HeroProgressionData.MAX_HERO_LEVEL)
	for skill_id_value: Variant in new_skill_levels.keys():
		var skill_id: StringName = StringName(str(skill_id_value))
		skill_levels[skill_id] = clampi(int(new_skill_levels[skill_id_value]), 1, HeroProgressionData.MAX_SKILL_LEVEL)
	var health: HealthComponent = get_node_or_null("HealthComponent") as HealthComponent
	if is_instance_valid(health) and definition != null:
		health.set_max_health(float(definition.max_health) * HeroProgressionData.stat_multiplier(hero_level))

func get_skill_level(skill_id: StringName) -> int:
	return int(skill_levels.get(skill_id, 1))

func get_skill_cooldown(skill_id: StringName) -> float:
	return float(skill_cooldowns.get(skill_id, 0.0))

func begin_skill_cooldown(skill_id: StringName, cooldown: float) -> void:
	skill_cooldowns[skill_id] = maxf(0.0, cooldown)

func set_navigation_path(path: PackedVector2Array) -> void:
	_travel_active = false
	super.set_navigation_path(path)

func begin_travel(path: PackedVector2Array, destination: Vector2) -> void:
	set_navigation_path(path)
	_travel_destination = destination
	_travel_active = not path.is_empty()

func cancel_travel() -> void:
	_travel_active = false

func play_skill_visual(skill_id: StringName, target_position: Vector2) -> void:
	if _frames_for_skill_visual(skill_id) == null:
		super.play_skill_visual(skill_id, target_position)
		return
	play_skill_visual_on_target(skill_id, self, target_position)

func play_skill_visual_on_target(skill_id: StringName, target_root: Node2D, target_position: Vector2) -> AnimatedSprite2D:
	var frames: SpriteFrames = _frames_for_skill_visual(skill_id)
	if frames == null or not is_instance_valid(target_root) or frames.get_frame_count(&"default") <= 0:
		return null
	var texture: Texture2D = frames.get_frame_texture(&"default", 0)
	if texture == null:
		return null
	var vfx: AnimatedSprite2D = AnimatedSprite2D.new()
	vfx.name = _node_name_for_skill_visual(skill_id)
	vfx.z_index = 19 if skill_id == CONFUCIUS_W_ID else 20
	vfx.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	vfx.sprite_frames = frames
	vfx.position = Vector2.ZERO
	vfx.rotation = _rotation_for_skill_visual(skill_id, target_position)
	var texture_extent: float = maxf(texture.get_width(), texture.get_height())
	vfx.scale = Vector2.ONE * _diameter_for_skill_visual(skill_id) / texture_extent
	vfx.modulate = Color.WHITE
	target_root.add_child(vfx)
	vfx.animation_finished.connect(vfx.queue_free, CONNECT_ONE_SHOT)
	vfx.play(&"default")
	return vfx

func play_and_request_skill_visual_on_target(skill_id: StringName, target_root: Node2D, target_position: Vector2) -> AnimatedSprite2D:
	if not is_instance_valid(target_root):
		return null
	var vfx: AnimatedSprite2D = play_skill_visual_on_target(skill_id, target_root, target_position)
	var target_kind: StringName = target_root.get_meta(&"damageable_kind", &"") as StringName
	var target_id: int = int(target_root.get_meta(&"damageable_id", 0))
	skill_visual_requested.emit(unit_id, skill_id, target_position, target_kind, target_id)
	return vfx

func _process_passive_aura(delta: float) -> void:
	_passive_refresh_elapsed += delta
	if _passive_refresh_elapsed < PASSIVE_REFRESH_INTERVAL:
		return
	_passive_refresh_elapsed = 0.0
	if definition == null or not _ally_provider.is_valid():
		return
	var skill: Resource = definition.call(&"get_hero_skill", CONFUCIUS_PASSIVE_ID) as Resource
	if skill == null:
		return
	var level: int = get_skill_level(CONFUCIUS_PASSIVE_ID)
	var attack_bonus_percent: float = float(skill.call(&"value_at", level))
	var defense_bonus: float = float(skill.call(&"secondary_value_at", level))
	var duration: float = float(skill.get("effect_duration_seconds"))
	var radius_squared: float = pow(float(skill.get("cast_range_tiles")) * _tile_size, 2.0)
	var source_id: StringName = StringName("confucius_passive_%d" % unit_id)
	for ally_value: Variant in (_ally_provider.call() as Array):
		var ally: HealthComponent = ally_value as HealthComponent
		if not is_instance_valid(ally) or global_position.distance_squared_to(ally.get_target_position()) > radius_squared:
			continue
		var ally_root: Node2D = ally.target_root
		if is_instance_valid(ally_root) and ally_root.has_method(&"apply_combat_buff"):
			ally_root.call(&"apply_combat_buff", source_id, attack_bonus_percent, 0.0, duration)
		ally.apply_temporary_defense_bonus(source_id, defense_bonus, duration)

func _apply_travel_inspiration() -> void:
	if definition == null or not _ally_provider.is_valid():
		return
	var skill: Resource = definition.call(&"get_hero_skill", CONFUCIUS_E_ID) as Resource
	if skill == null:
		return
	var level: int = get_skill_level(CONFUCIUS_E_ID)
	var bonus_percent: float = float(skill.call(&"value_at", level))
	var duration: float = float(skill.get("effect_duration_seconds"))
	var radius_squared: float = pow(float(skill.get("radius_tiles")) * _tile_size, 2.0)
	var source_id: StringName = StringName("confucius_e_%d" % unit_id)
	for ally_value: Variant in (_ally_provider.call() as Array):
		var ally: HealthComponent = ally_value as HealthComponent
		if not is_instance_valid(ally) or global_position.distance_squared_to(ally.get_target_position()) > radius_squared:
			continue
		var ally_root: Node2D = ally.target_root
		if is_instance_valid(ally_root) and ally_root.has_method(&"apply_combat_buff"):
			ally_root.call(&"apply_combat_buff", source_id, bonus_percent, bonus_percent, duration)
			play_and_request_skill_visual_on_target(CONFUCIUS_E_ARRIVAL_VFX_ID, ally_root, ally_root.global_position)

func _frames_for_skill_visual(skill_id: StringName) -> SpriteFrames:
	match skill_id:
		CONFUCIUS_Q_ID:
			return Q_VFX_FRAMES
		CONFUCIUS_W_ID:
			return W_VFX_FRAMES
		CONFUCIUS_E_ID, CONFUCIUS_E_ARRIVAL_VFX_ID:
			return E_VFX_FRAMES
	return null

func _diameter_for_skill_visual(skill_id: StringName) -> float:
	match skill_id:
		CONFUCIUS_Q_ID:
			return Q_VFX_DIAMETER
		CONFUCIUS_W_ID:
			return W_VFX_DIAMETER
		CONFUCIUS_E_ID:
			return E_TRAVEL_VFX_DIAMETER
		CONFUCIUS_E_ARRIVAL_VFX_ID:
			return E_ARRIVAL_VFX_DIAMETER
	return 0.0

func _rotation_for_skill_visual(skill_id: StringName, target_position: Vector2) -> float:
	if skill_id != CONFUCIUS_E_ID:
		return 0.0
	var travel_direction: Vector2 = target_position - global_position
	return travel_direction.angle() if not travel_direction.is_zero_approx() else 0.0

func _node_name_for_skill_visual(skill_id: StringName) -> String:
	match skill_id:
		CONFUCIUS_Q_ID:
			return "ConfuciusQSkillVfx_%d" % unit_id
		CONFUCIUS_W_ID:
			return "ConfuciusWSkillVfx_%d" % unit_id
		CONFUCIUS_E_ID:
			return "ConfuciusETravelVfx_%d" % unit_id
		CONFUCIUS_E_ARRIVAL_VFX_ID:
			return "ConfuciusEArrivalVfx_%d" % unit_id
	return "ConfuciusSkillVfx_%d" % unit_id

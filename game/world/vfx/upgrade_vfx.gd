class_name UpgradeVfx
extends Node2D

const DURATION_SECONDS: float = 1.25
const BASE_VISUAL_DIAMETER: float = 64.0
const MINIMUM_SCALE: float = 0.8
const MAXIMUM_SCALE: float = 2.35
const PARTICLE_COUNT: int = 22
const PARTICLE_LIFETIME_SECONDS: float = 0.85
const ENERGY_COLOR: Color = Color("#58f1ff")
const HIGHLIGHT_COLOR: Color = Color("#ffd65a")

@onready var upgrade_surface: ColorRect = %UpgradeSurface
@onready var upgrade_label: Label = %UpgradeLabel

var _visual_diameter: float = BASE_VISUAL_DIAMETER
var _surface_material: ShaderMaterial

func _ready() -> void:
	add_to_group(&"upgrade_vfx")
	_prepare_shader_material()
	_apply_visual_scale()
	_create_spark_particles()
	_play_animation()

func configure_visual_size(visual_diameter: float) -> void:
	_visual_diameter = maxf(1.0, visual_diameter)
	if is_node_ready():
		_apply_visual_scale()

func _prepare_shader_material() -> void:
	var source_material: ShaderMaterial = upgrade_surface.material as ShaderMaterial
	if source_material == null:
		return
	_surface_material = source_material.duplicate() as ShaderMaterial
	upgrade_surface.material = _surface_material
	_surface_material.set_shader_parameter(&"progress", 0.0)

func _apply_visual_scale() -> void:
	var effect_scale: float = clampf(_visual_diameter / BASE_VISUAL_DIAMETER, MINIMUM_SCALE, MAXIMUM_SCALE)
	scale = Vector2.ONE * effect_scale

func _create_spark_particles() -> void:
	var sparkles: CPUParticles2D = CPUParticles2D.new()
	sparkles.name = "UpgradeSparkles"
	sparkles.z_index = 2
	sparkles.amount = PARTICLE_COUNT
	sparkles.lifetime = PARTICLE_LIFETIME_SECONDS
	sparkles.one_shot = true
	sparkles.explosiveness = 0.92
	sparkles.randomness = 0.55
	sparkles.direction = Vector2.UP
	sparkles.spread = 42.0
	sparkles.gravity = Vector2(0.0, -24.0)
	sparkles.initial_velocity_min = 42.0
	sparkles.initial_velocity_max = 82.0
	sparkles.scale_amount_min = 1.5
	sparkles.scale_amount_max = 3.1
	sparkles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	sparkles.emission_sphere_radius = 22.0
	var color_ramp: Gradient = Gradient.new()
	color_ramp.offsets = PackedFloat32Array([0.0, 0.58, 1.0])
	color_ramp.colors = PackedColorArray([HIGHLIGHT_COLOR, ENERGY_COLOR, Color(ENERGY_COLOR, 0.0)])
	sparkles.color_ramp = color_ramp
	add_child(sparkles)
	sparkles.restart()

func _play_animation() -> void:
	upgrade_label.modulate.a = 0.0
	var starting_label_position: Vector2 = upgrade_label.position

	var effect_tween: Tween = create_tween()
	effect_tween.tween_method(_set_shader_progress, 0.0, 1.0, DURATION_SECONDS).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	effect_tween.finished.connect(queue_free, CONNECT_ONE_SHOT)

	var label_motion_tween: Tween = create_tween()
	label_motion_tween.tween_property(upgrade_label, ^"position", starting_label_position + Vector2(0.0, -14.0), DURATION_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var label_fade_tween: Tween = create_tween()
	label_fade_tween.tween_property(upgrade_label, ^"modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	label_fade_tween.tween_interval(0.62)
	label_fade_tween.tween_property(upgrade_label, ^"modulate:a", 0.0, DURATION_SECONDS - 0.78).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _set_shader_progress(value: float) -> void:
	if _surface_material != null:
		_surface_material.set_shader_parameter(&"progress", value)

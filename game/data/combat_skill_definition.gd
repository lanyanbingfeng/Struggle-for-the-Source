class_name CombatSkillDefinition
extends Resource

enum TargetMode {
	SELF,
	NEAREST_ENEMY,
	LOW_HEALTH_ENEMY,
	HIGHEST_DEFENSE_ENEMY,
	HIGHEST_MAX_HEALTH_ENEMY,
	ENEMY_CLUSTER,
	LOWEST_HEALTH_ALLY,
	ALLY_AREA,
	DEBUFFED_ALLIES,
}

enum Shape {
	SINGLE,
	SELF_AREA,
	CIRCLE,
	LINE,
	CONE,
	CHAIN,
}

enum ControlType { NONE, ROOT, STUN }
enum VfxPlacement { CASTER_FORWARD, TARGET_CENTER, SELF_CENTER, AREA_CENTER }

@export var skill_id: StringName = &"skill"
@export var display_name: String = "技能"
@export_multiline var description: String = ""
@export var target_mode: TargetMode = TargetMode.NEAREST_ENEMY
@export var shape: Shape = Shape.SINGLE
@export var vfx_placement: VfxPlacement = VfxPlacement.TARGET_CENTER
@export var vfx_frames: SpriteFrames
@export_range(0, 1000, 1) var mana_cost: int = 0
@export_range(0.0, 60.0, 0.25) var cooldown_seconds: float = 0.0
@export_range(0.5, 20.0, 0.25) var cast_range_tiles: float = 3.0
@export_range(0.0, 20.0, 0.25) var radius_tiles: float = 0.0
@export_range(0.0, 20.0, 0.25) var line_width_tiles: float = 0.0
@export_range(1.0, 180.0, 1.0) var cone_angle_degrees: float = 70.0
@export_range(1, 16, 1) var max_targets: int = 1
@export_range(0.0, 20.0, 0.25) var chain_range_tiles: float = 0.0
@export_range(0.0, 10.0, 0.05) var damage_multiplier: float = 0.0
@export_range(0.0, 1.0, 0.05) var defense_ignore_ratio: float = 0.0
@export_range(0.0, 10.0, 0.05) var dot_damage_multiplier: float = 0.0
@export_range(0.0, 20.0, 0.25) var dot_duration_seconds: float = 0.0
@export_range(0.1, 5.0, 0.1) var dot_interval_seconds: float = 1.0
@export_range(0.0, 1.0, 0.01) var heal_percent: float = 0.0
@export_range(-1000.0, 1000.0, 1.0) var defense_modifier: float = 0.0
@export_range(0.0, 20.0, 0.25) var effect_duration_seconds: float = 0.0
@export_range(0.0, 2.0, 0.01) var attack_bonus_ratio: float = 0.0
@export_range(0.0, 2.0, 0.01) var movement_bonus_ratio: float = 0.0
@export_range(0.0, 1.0, 0.01) var movement_slow_ratio: float = 0.0
@export_range(0.0, 2.0, 0.01) var attack_interval_increase_ratio: float = 0.0
@export_range(0.0, 1.0, 0.01) var damage_taken_bonus_ratio: float = 0.0
@export var control_type: ControlType = ControlType.NONE
@export_range(0.0, 10.0, 0.1) var control_duration_seconds: float = 0.0
@export_range(0.0, 5.0, 0.25) var knockback_tiles: float = 0.0
@export_range(0.0, 1.0, 0.01) var trigger_health_ratio: float = 1.0
@export_range(0.0, 1.0, 0.01) var next_hit_reduction_ratio: float = 0.0
@export_range(0.0, 1.0, 0.01) var control_duration_reduction_ratio: float = 0.0
@export_range(0.0, 10.0, 0.25) var reveal_radius_tiles: float = 0.0
@export_range(0.0, 20.0, 0.25) var taunt_duration_seconds: float = 0.0
@export var cleanse_damage_over_time: bool = false
@export var cleanse_movement_slow: bool = false
@export var cleanse_attack_slow: bool = false
@export var cleanse_defense_reduction: bool = false
@export var cleanse_control: bool = false
@export var grant_control_immunity: bool = false


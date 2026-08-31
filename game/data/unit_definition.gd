class_name UnitDefinition
extends Resource

enum Category { WORKER, COMBAT, HERO }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }
enum AttackVfxPlacement { CASTER_FORWARD, TARGET_CENTER }

@export var unit_id: StringName = &"unit"
@export var display_name: String = "单位"
@export var category: Category = Category.COMBAT
@export var rarity: Rarity = Rarity.COMMON
@export var scene: PackedScene
@export var card_texture: Texture2D
@export var attack_vfx_frames: SpriteFrames
@export var attack_vfx_placement: AttackVfxPlacement = AttackVfxPlacement.CASTER_FORWARD
@export var combat_skill: CombatSkillDefinition
@export var role_name: String = "单位"
@export_multiline var description: String = ""
@export_range(1, 10000, 1) var max_health: int = 100
@export_range(0, 1000, 1) var attack: int = 10
@export_range(0, 1000, 1) var defense: int = 5
@export_range(0.1, 10.0, 0.05) var attack_interval_seconds: float = 1.5
@export_range(0.5, 20.0, 0.25) var attack_range_tiles: float = 1.0
@export_range(0.5, 30.0, 0.25) var chase_range_tiles: float = 6.0
@export_range(0.0, 0.95, 0.01) var evasion_chance: float = 0.0
@export_range(1.0, 20.0, 0.5) var vision_radius_tiles: float = 4.0
@export_range(0.0, 300.0, 1.0) var movement_speed: float = 96.0
@export_range(0, 1000, 1) var max_mana: int = 0
@export_range(0.0, 100.0, 0.25) var mana_regen_per_second: float = 0.0
@export var skill_id: StringName = &""
@export var skill_name: String = ""
@export_multiline var skill_description: String = ""
@export_range(0, 1000, 1) var skill_mana_cost: int = 0
@export_range(0.0, 60.0, 0.25) var skill_cooldown_seconds: float = 0.0
@export_range(0.0, 1000.0, 1.0) var skill_damage: float = 0.0
@export_range(0.0, 10.0, 0.05) var skill_attack_multiplier: float = 0.0
@export_range(0.0, 1.0, 0.01) var skill_heal_percent: float = 0.0
@export_range(0.5, 20.0, 0.25) var skill_radius_tiles: float = 3.0
@export_range(0.0, 1.0, 0.01) var skill_trigger_health_ratio: float = 1.0
@export_range(0.0, 0.5, 0.01) var skill_execute_health_ratio: float = 0.0
@export_range(0.1, 1.0, 0.05) var skill_move_speed_multiplier: float = 1.0
@export_range(0.0, 20.0, 0.25) var skill_slow_duration_seconds: float = 0.0
@export_range(1, 4, 1) var footprint_tiles: int = 1
@export_range(32.0, 128.0, 1.0) var formation_spacing: float = 40.0
@export_range(0, 100000, 1) var recruit_cost_gold: int = 0
@export var can_leave_territory: bool = false
@export var can_build_base: bool = false
@export var can_build_structures: bool = false

func get_skill_damage() -> float:
	if skill_attack_multiplier > 0.0:
		return float(attack) * skill_attack_multiplier
	return skill_damage

class_name HeroSkillDefinition
extends Resource

enum TargetMode { PASSIVE, ALLY, GROUND }

@export var skill_id: StringName = &"hero_skill"
@export var display_name: String = "英雄技能"
@export var hotkey: String = ""
@export_multiline var description: String = ""
@export var target_mode: TargetMode = TargetMode.PASSIVE
@export var icon: Texture2D
@export_range(0, 200, 1) var mana_cost: int = 0
@export_range(0.0, 60.0, 0.25) var cooldown_seconds: float = 0.0
@export_range(0.0, 20.0, 0.25) var cast_range_tiles: float = 0.0
@export_range(0.0, 20.0, 0.25) var radius_tiles: float = 0.0
@export_range(0.0, 60.0, 0.25) var effect_duration_seconds: float = 0.0
@export var values: PackedFloat32Array = PackedFloat32Array()
@export var secondary_values: PackedFloat32Array = PackedFloat32Array()

func value_at(level: int) -> float:
	if values.is_empty():
		return 0.0
	return values[clampi(level, 1, values.size()) - 1]

func secondary_value_at(level: int) -> float:
	if secondary_values.is_empty():
		return 0.0
	return secondary_values[clampi(level, 1, secondary_values.size()) - 1]

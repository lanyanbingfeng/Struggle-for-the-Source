class_name BuildingDefinition
extends Resource

@export var building_id: StringName = &"building"
@export var display_name: String = "建筑"
@export_multiline var description: String = ""
@export var texture: Texture2D
@export var card_texture: Texture2D
@export var tint: Color = Color.WHITE
@export var icon_text: String = "建"
@export_range(1, 4, 1) var footprint_tiles: int = 2
@export_range(1, 10000, 1) var max_health: int = 500
@export_range(0, 1000, 1) var defense: int = 20
@export_range(0, 100000, 1) var cost_gold: int = 0
@export_range(0, 100000, 1) var cost_wood: int = 0
@export_range(0, 100000, 1) var cost_stone: int = 0
@export_range(0, 100000, 1) var cost_iron: int = 0
@export_range(0, 100000, 1) var cost_summon_token: int = 0
@export_range(0, 100000, 1) var cost_skill_experience: int = 0
@export_range(1.0, 120.0, 0.5) var construction_seconds: float = 8.0
@export_range(1, 10, 1) var max_level: int = 4
@export_range(0, 10000, 1) var upgrade_iron_base_cost: int = 8
@export var interaction_type: StringName = &""
@export var required_resource_type: StringName = &""
@export_range(0.0, 12.0, 0.5) var required_resource_radius_tiles: float = 0.0
@export var production_resource_type: StringName = &"wood"
@export_range(1, 1000, 1) var production_amount: int = 1
@export_range(0.25, 120.0, 0.25) var production_interval_seconds: float = 5.0

func cost_dictionary() -> Dictionary:
	var result: Dictionary = {}
	for entry: Array in [
		["gold", cost_gold], ["wood", cost_wood], ["stone", cost_stone],
		["iron", cost_iron], ["summon_token", cost_summon_token], ["skill_experience", cost_skill_experience],
	]:
		if int(entry[1]) > 0:
			result[entry[0]] = int(entry[1])
	return result

func cost_summary() -> String:
	var labels := {"gold": "金币", "wood": "木材", "stone": "石头", "iron": "铁", "summon_token": "召唤符", "skill_experience": "技能经验"}
	var parts: PackedStringArray = []
	for resource_id: String in cost_dictionary().keys():
		parts.append("%s%d" % [labels[resource_id], int(cost_dictionary()[resource_id])])
	return " / ".join(parts)

func upgrade_iron_cost(current_level: int) -> int:
	if current_level < 1 or current_level >= max_level:
		return 0
	return upgrade_iron_base_cost * current_level

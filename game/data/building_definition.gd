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
@export_range(0, 100000, 1) var cost_gold_ore: int = 0
@export_range(0, 100000, 1) var cost_diamond: int = 0
@export var required_resource_type: StringName = &""
@export_range(0.0, 12.0, 0.5) var required_resource_radius_tiles: float = 0.0
@export var production_resource_type: StringName = &"wood"
@export_range(1, 1000, 1) var production_amount: int = 1
@export_range(0.25, 120.0, 0.25) var production_interval_seconds: float = 5.0

func cost_dictionary() -> Dictionary:
	var result: Dictionary = {}
	for entry: Array in [
		["gold", cost_gold], ["wood", cost_wood], ["stone", cost_stone],
		["iron", cost_iron], ["gold_ore", cost_gold_ore], ["diamond", cost_diamond],
	]:
		if int(entry[1]) > 0:
			result[entry[0]] = int(entry[1])
	return result

func cost_summary() -> String:
	var labels := {"gold": "金币", "wood": "木材", "stone": "石头", "iron": "铁矿", "gold_ore": "金矿", "diamond": "钻石"}
	var parts: PackedStringArray = []
	for resource_id: String in cost_dictionary().keys():
		parts.append("%s%d" % [labels[resource_id], int(cost_dictionary()[resource_id])])
	return " / ".join(parts)

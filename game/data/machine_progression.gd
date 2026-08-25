class_name MachineProgression
extends RefCounted

const MAX_LEVEL: int = 4
const SPEED_MULTIPLIERS: Array[float] = [1.0, 1.30, 1.65, 2.10]
const UPGRADE_COSTS: Array[Dictionary] = [
	{},
	{"gold": 150, "wood": 20, "stone": 25},
	{"gold": 300, "wood": 35, "iron": 18},
	{"gold": 600, "wood": 50, "gold_ore": 12},
]
const RESOURCE_NAMES: Dictionary = {
	"gold": "金币", "wood": "木材", "stone": "石头",
	"iron": "铁矿", "gold_ore": "金矿", "diamond": "钻石",
}
const QUARRY_LEVEL_BY_RESOURCE: Dictionary = {
	&"stone": 1, &"iron": 2, &"gold_ore": 3, &"diamond": 4,
}

static func get_speed_multiplier(level: int) -> float:
	return SPEED_MULTIPLIERS[clampi(level, 1, MAX_LEVEL) - 1]

static func get_upgrade_cost(current_level: int) -> Dictionary:
	if current_level < 1 or current_level >= MAX_LEVEL:
		return {}
	return UPGRADE_COSTS[current_level].duplicate(true)

static func cost_summary(current_level: int) -> String:
	var cost: Dictionary = get_upgrade_cost(current_level)
	if cost.is_empty():
		return "已满级"
	var parts: PackedStringArray = PackedStringArray()
	for resource_id: String in ["gold", "wood", "stone", "iron", "gold_ore", "diamond"]:
		if cost.has(resource_id):
			parts.append("%s%d" % [str(RESOURCE_NAMES.get(resource_id, resource_id)), int(cost[resource_id])])
	return " + ".join(parts)

static func quarry_can_harvest(level: int, resource_type: StringName) -> bool:
	return level >= int(QUARRY_LEVEL_BY_RESOURCE.get(resource_type, MAX_LEVEL + 1))

static func quarry_permission_text(level: int) -> String:
	match clampi(level, 1, MAX_LEVEL):
		1: return "可采：石头"
		2: return "可采：石头、铁矿"
		3: return "可采：石头、铁矿、金矿"
		_: return "可采：石头、铁矿、金矿、钻石"

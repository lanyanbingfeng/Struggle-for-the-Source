class_name BaseProgression
extends RefCounted

const MAX_LEVEL: int = 9
const SUMMON_COST: int = 10
const SUMMON_CARD_COUNT: int = 5

const RARITY_NAMES: PackedStringArray = ["普通", "优秀", "稀有", "史诗", "传说"]
const SUMMON_PROBABILITIES: Array = [
	[100, 0, 0, 0, 0],
	[90, 10, 0, 0, 0],
	[75, 25, 0, 0, 0],
	[55, 30, 15, 0, 0],
	[45, 33, 20, 2, 0],
	[30, 40, 25, 5, 0],
	[19, 30, 35, 15, 1],
	[16, 20, 35, 25, 4],
	[9, 15, 30, 30, 16],
]

# 索引为当前等级；第 0 项占位，第 1 项是 1→2 的费用。
const UPGRADE_COSTS: Array[Dictionary] = [
	{},
	{"gold": 100, "wood": 10, "stone": 5, "iron": 0},
	{"gold": 200, "wood": 12, "stone": 7, "iron": 0},
	{"gold": 350, "wood": 14, "stone": 8, "iron": 2},
	{"gold": 550, "wood": 14, "stone": 8, "iron": 4},
	{"gold": 800, "wood": 14, "stone": 8, "iron": 6},
	{"gold": 1200, "wood": 14, "stone": 8, "iron": 8},
	{"gold": 1700, "wood": 12, "stone": 8, "iron": 10},
	{"gold": 2400, "wood": 10, "stone": 8, "iron": 14},
]

static func get_probabilities(level: int) -> PackedInt32Array:
	return PackedInt32Array(SUMMON_PROBABILITIES[clampi(level, 1, MAX_LEVEL) - 1])

static func probability_summary(level: int) -> String:
	var probabilities: PackedInt32Array = get_probabilities(level)
	var parts: PackedStringArray = []
	for rarity_index: int in probabilities.size():
		if probabilities[rarity_index] > 0:
			parts.append("%s%d%%" % [RARITY_NAMES[rarity_index], probabilities[rarity_index]])
	return "  ".join(parts)

static func get_upgrade_cost(current_level: int) -> Dictionary:
	if current_level < 1 or current_level >= MAX_LEVEL:
		return {}
	return UPGRADE_COSTS[current_level].duplicate(true)

static func upgrade_cost_summary(current_level: int) -> String:
	if current_level >= MAX_LEVEL:
		return "基地已达到最高等级"
	var cost: Dictionary = get_upgrade_cost(current_level)
	return "金币%d  木材%d  石头%d  铁%d" % [
		int(cost.get("gold", 0)), int(cost.get("wood", 0)), int(cost.get("stone", 0)),
		int(cost.get("iron", 0)),
	]

static func roll_rarity(level: int, rng: RandomNumberGenerator) -> UnitDefinition.Rarity:
	var roll: int = rng.randi_range(1, 100)
	var cumulative: int = 0
	var probabilities: PackedInt32Array = get_probabilities(level)
	for rarity_index: int in probabilities.size():
		cumulative += probabilities[rarity_index]
		if roll <= cumulative:
			return rarity_index as UnitDefinition.Rarity
	return UnitDefinition.Rarity.COMMON

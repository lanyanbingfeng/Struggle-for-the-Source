class_name WildEnemyDifficulty
extends RefCounted

enum Level { EASY, NORMAL, HARD, HELL }

const NAMES: Array[String] = ["简单", "普通", "困难", "地狱"]
const HEALTH_MULTIPLIERS: Array[float] = [0.80, 1.00, 1.20, 1.40]
const DAMAGE_MULTIPLIERS: Array[float] = [0.85, 1.00, 1.10, 1.20]
const INTERVAL_MULTIPLIERS: Array[float] = [1.15, 1.00, 0.90, 0.82]

static func normalize(level: int) -> int:
	return clampi(level, Level.EASY, Level.HELL)

static func get_display_name(level: int) -> String:
	return NAMES[normalize(level)]

static func get_health_multiplier(level: int) -> float:
	return HEALTH_MULTIPLIERS[normalize(level)]

static func get_damage_multiplier(level: int) -> float:
	return DAMAGE_MULTIPLIERS[normalize(level)]

static func get_interval_multiplier(level: int) -> float:
	return INTERVAL_MULTIPLIERS[normalize(level)]

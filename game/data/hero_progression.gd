class_name HeroProgression
extends RefCounted

const MAX_HERO_LEVEL: int = 10
const MAX_SKILL_LEVEL: int = 5

static func hero_level_cost(current_level: int) -> int:
	return 0 if current_level >= MAX_HERO_LEVEL else 25 * current_level

static func skill_level_cost(current_level: int) -> int:
	return 0 if current_level >= MAX_SKILL_LEVEL else 10 * current_level

static func stat_multiplier(level: int) -> float:
	return 1.0 + 0.1 * float(clampi(level, 1, MAX_HERO_LEVEL) - 1)

static func skill_multiplier(level: int) -> float:
	return 1.0 + 0.12 * float(clampi(level, 1, MAX_SKILL_LEVEL) - 1)

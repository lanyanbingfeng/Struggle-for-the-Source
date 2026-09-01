class_name MapSizeSetting
extends RefCounted

enum Level { SMALL, MEDIUM, LARGE }

const NAMES: Array[String] = ["小", "中", "大"]
const TILE_COUNTS: Array[int] = [100, 250, 500]
const DEFAULT_LEVEL: int = Level.LARGE

static func normalize_level(level: int) -> int:
	return clampi(level, Level.SMALL, Level.LARGE)

static func normalize_tile_count(tile_count: int) -> int:
	for supported_tile_count: int in TILE_COUNTS:
		if tile_count == supported_tile_count:
			return supported_tile_count
	return TILE_COUNTS[DEFAULT_LEVEL]

static func get_display_name(level: int) -> String:
	return NAMES[normalize_level(level)]

static func get_tile_count(level: int) -> int:
	return TILE_COUNTS[normalize_level(level)]

static func get_level_from_tile_count(tile_count: int) -> int:
	var normalized_tile_count: int = normalize_tile_count(tile_count)
	return TILE_COUNTS.find(normalized_tile_count)

static func get_option_label(level: int) -> String:
	var safe_level: int = normalize_level(level)
	var tile_count: int = get_tile_count(safe_level)
	return "%s · %d×%d" % [get_display_name(safe_level), tile_count, tile_count]

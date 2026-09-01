class_name GameSaveManager
extends Node

signal saves_changed

const FORMAT_VERSION: int = 1
const SAVE_ROOT: String = "user://saves"
const SINGLE_SAVE_PATH: String = SAVE_ROOT + "/single_player.save"
const MULTIPLAYER_DIR: String = SAVE_ROOT + "/multiplayer"
const IDENTITY_PATH: String = SAVE_ROOT + "/local_identity.save"

var _device_id: String = ""

func _ready() -> void:
	_ensure_directories()
	_device_id = _load_or_create_device_id()

func get_device_id() -> String:
	if _device_id.is_empty():
		_ensure_directories()
		_device_id = _load_or_create_device_id()
	return _device_id

func create_game_id() -> String:
	var source: String = "%s:%d:%d" % [get_device_id(), int(Time.get_unix_time_from_system()), randi()]
	return source.sha256_text().left(24)

func has_single_player_save() -> bool:
	return not get_single_player_save().is_empty()

func get_single_player_save() -> Dictionary:
	var record: Dictionary = _read_record(SINGLE_SAVE_PATH)
	if str(record.get("mode", "")) != "single":
		return {}
	return record

func save_single_player(record: Dictionary) -> bool:
	var normalized: Dictionary = record.duplicate(true)
	normalized["format_version"] = FORMAT_VERSION
	normalized["mode"] = "single"
	normalized["saved_at_unix"] = int(Time.get_unix_time_from_system())
	var success: bool = _write_record(SINGLE_SAVE_PATH, normalized)
	if success:
		saves_changed.emit()
	return success

func delete_single_player_save() -> void:
	if FileAccess.file_exists(SINGLE_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SINGLE_SAVE_PATH))
	saves_changed.emit()

func list_multiplayer_saves() -> Array[Dictionary]:
	_ensure_directories()
	var records: Array[Dictionary] = []
	var directory: DirAccess = DirAccess.open(MULTIPLAYER_DIR)
	if directory == null:
		return records
	directory.list_dir_begin()
	var file_name: String = directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.ends_with(".save"):
			var record: Dictionary = _read_record(MULTIPLAYER_DIR + "/" + file_name)
			if str(record.get("mode", "")) == "multiplayer":
				records.append(record)
		file_name = directory.get_next()
	directory.list_dir_end()
	records.sort_custom(_sort_multiplayer_records)
	return records

func get_multiplayer_save(game_id: String) -> Dictionary:
	var safe_game_id: String = _sanitize_game_id(game_id)
	if safe_game_id.is_empty():
		return {}
	var record: Dictionary = _read_record(MULTIPLAYER_DIR + "/" + safe_game_id + ".save")
	if str(record.get("mode", "")) != "multiplayer" or str(record.get("game_id", "")) != safe_game_id:
		return {}
	return record

func save_multiplayer(record: Dictionary) -> bool:
	var normalized: Dictionary = record.duplicate(true)
	var game_id: String = _sanitize_game_id(str(normalized.get("game_id", "")))
	if game_id.is_empty():
		return false
	normalized["format_version"] = FORMAT_VERSION
	normalized["mode"] = "multiplayer"
	normalized["game_id"] = game_id
	normalized["saved_at_unix"] = int(Time.get_unix_time_from_system())
	var path: String = MULTIPLAYER_DIR + "/" + game_id + ".save"
	var success: bool = _write_record(path, normalized)
	if success:
		saves_changed.emit()
	return success

func accept_newer_multiplayer_save(record: Dictionary) -> bool:
	if not is_valid_record(record, "multiplayer"):
		return false
	var game_id: String = str(record.get("game_id", ""))
	var existing: Dictionary = get_multiplayer_save(game_id)
	if not existing.is_empty() and int(existing.get("revision", 0)) > int(record.get("revision", 0)):
		return false
	return save_multiplayer(record)

func is_valid_record(record: Dictionary, expected_mode: String = "") -> bool:
	if int(record.get("format_version", 0)) != FORMAT_VERSION:
		return false
	if not expected_mode.is_empty() and str(record.get("mode", "")) != expected_mode:
		return false
	if record.get("session_snapshot") is not Dictionary or record.get("world_state") is not Dictionary:
		return false
	if str(record.get("mode", "")) == "multiplayer" and _sanitize_game_id(str(record.get("game_id", ""))).is_empty():
		return false
	return true

func describe_record(record: Dictionary) -> String:
	var revision: int = int(record.get("revision", 0))
	var player_count: int = int(record.get("player_count", 1))
	var saved_at: int = int(record.get("saved_at_unix", 0))
	var time_text: String = Time.get_datetime_string_from_unix_time(saved_at, true) if saved_at > 0 else "未知时间"
	return "%d 人 · 版本 %d · %s" % [player_count, revision, time_text]

func _ensure_directories() -> void:
	var absolute_path: String = ProjectSettings.globalize_path(MULTIPLAYER_DIR)
	var error: Error = DirAccess.make_dir_recursive_absolute(absolute_path)
	if error != OK and error != ERR_ALREADY_EXISTS:
		push_error("无法创建存档目录：%s" % error_string(error))

func _load_or_create_device_id() -> String:
	var identity: Dictionary = _read_dictionary(IDENTITY_PATH)
	var existing_id: String = str(identity.get("device_id", ""))
	if not existing_id.is_empty():
		return existing_id
	var generated: String = ("%d:%d:%s" % [int(Time.get_unix_time_from_system()), randi(), OS.get_unique_id()]).sha256_text().left(24)
	_write_dictionary(IDENTITY_PATH, {"device_id": generated})
	return generated

func _read_record(path: String) -> Dictionary:
	var record: Dictionary = _read_dictionary(path)
	if record.is_empty() or not is_valid_record(record):
		return {}
	return record

func _read_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var value: Variant = file.get_var(false)
	if value is Dictionary:
		return value as Dictionary
	return {}

func _write_record(path: String, record: Dictionary) -> bool:
	if not is_valid_record(record):
		push_error("拒绝写入格式无效的游戏存档")
		return false
	return _write_dictionary(path, record)

func _write_dictionary(path: String, value: Dictionary) -> bool:
	_ensure_directories()
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("无法写入存档：%s" % path)
		return false
	file.store_var(value, false)
	file.flush()
	return file.get_error() == OK

func _sanitize_game_id(game_id: String) -> String:
	var sanitized: String = ""
	for character: String in game_id.left(64):
		if character.to_lower() in "abcdefghijklmnopqrstuvwxyz0123456789-_":
			sanitized += character.to_lower()
	return sanitized

func _sort_multiplayer_records(left: Dictionary, right: Dictionary) -> bool:
	var left_time: int = int(left.get("saved_at_unix", 0))
	var right_time: int = int(right.get("saved_at_unix", 0))
	if left_time == right_time:
		return int(left.get("revision", 0)) > int(right.get("revision", 0))
	return left_time > right_time

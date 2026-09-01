extends Node

const MAIN_SCENE: PackedScene = preload("res://game/main/main.tscn")

var _failures: PackedStringArray = []
var _temporary_save_path: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred(&"_run")

func _run() -> void:
	var map: Node2D = MAIN_SCENE.instantiate() as Node2D
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame
	map.call(
		&"_on_start_requested",
		false,
		SimpleAIController.Difficulty.NORMAL,
		100,
		WildEnemyDifficulty.Level.NORMAL
	)
	await get_tree().process_frame

	var player_states: Dictionary = map.get("_player_resource_states") as Dictionary
	var player_one: Dictionary = (player_states.get(1, {}) as Dictionary).duplicate(true)
	player_one["gold"] = 1234
	player_one["wood"] = 321
	player_states[1] = player_one
	map.set("_player_resource_states", player_states)
	_expect(bool(map.call(&"_server_spawn_unit", 1, &"treant")), "无法生成用于存档往返的树人")

	var saved_unit_id: int = 0
	var units: Dictionary = map.get("_network_units") as Dictionary
	for unit_id_value: Variant in units.keys():
		var unit: Node2D = units[unit_id_value] as Node2D
		var definition: UnitDefinition = unit.get("definition") as UnitDefinition
		if definition != null and definition.unit_id == &"treant" and int(unit.get("owner_peer_id")) == 1:
			saved_unit_id = int(unit_id_value)
			unit.global_position = Vector2(1234.0, 987.0)
			var health: HealthComponent = unit.get_node_or_null("HealthComponent") as HealthComponent
			if is_instance_valid(health):
				health.apply_network_state(42.0, health.current_mana)
			break
	_expect(saved_unit_id > 0, "没有找到用于存档往返的树人")

	var world_state: Dictionary = map.call(&"_capture_world_state") as Dictionary
	var snapshot: Dictionary = (map.get("_multiplayer_snapshot") as Dictionary).duplicate(true)
	var game_id: String = "save-smoke-%d" % Time.get_ticks_msec()
	var record: Dictionary = {
		"format_version": 1,
		"mode": "multiplayer",
		"game_id": game_id,
		"revision": 7,
		"player_count": 2,
		"session_snapshot": snapshot,
		"world_state": world_state,
	}
	var save_manager: Node = map.get("game_save_manager") as Node
	_expect(bool(save_manager.call(&"save_multiplayer", record)), "多人存档没有写入磁盘")
	var loaded: Dictionary = save_manager.call(&"get_multiplayer_save", game_id) as Dictionary
	_expect(int(loaded.get("revision", 0)) == 7, "多人存档磁盘往返丢失版本号")
	_expect((loaded.get("world_state", {}) as Dictionary).get("units", []).size() == (world_state.get("units", []) as Array).size(), "多人存档磁盘往返丢失单位数据")
	var older_record: Dictionary = record.duplicate(true)
	older_record["revision"] = 6
	_expect(not bool(save_manager.call(&"accept_newer_multiplayer_save", older_record)), "旧版本存档覆盖了本机最新副本")
	loaded = save_manager.call(&"get_multiplayer_save", game_id) as Dictionary
	_expect(int(loaded.get("revision", 0)) == 7, "拒绝旧版本后本机最新副本发生变化")
	var newer_record: Dictionary = record.duplicate(true)
	newer_record["revision"] = 9
	_expect(bool(save_manager.call(&"accept_newer_multiplayer_save", newer_record)), "新版本存档没有替换本机旧副本")
	loaded = save_manager.call(&"get_multiplayer_save", game_id) as Dictionary
	_expect(int(loaded.get("revision", 0)) == 9, "新版本存档替换后版本号不正确")
	_temporary_save_path = "user://saves/multiplayer/%s.save" % game_id

	map.call(&"_reset_game_state")
	map.call(&"_apply_world_state", world_state)
	map.call(&"_refresh_after_world_restore")
	var restored_player_states: Dictionary = map.get("_player_resource_states") as Dictionary
	var restored_player_one: Dictionary = restored_player_states.get(1, {}) as Dictionary
	_expect(int(restored_player_one.get("gold", 0)) == 1234 and int(restored_player_one.get("wood", 0)) == 321, "世界恢复后玩家资源不一致")
	var restored_units: Dictionary = map.get("_network_units") as Dictionary
	var restored_unit: Node2D = restored_units.get(saved_unit_id) as Node2D
	_expect(is_instance_valid(restored_unit), "世界恢复后树人缺失")
	if is_instance_valid(restored_unit):
		_expect(restored_unit.global_position.is_equal_approx(Vector2(1234.0, 987.0)), "世界恢复后树人位置不一致")
		var restored_health: HealthComponent = restored_unit.get_node_or_null("HealthComponent") as HealthComponent
		_expect(is_instance_valid(restored_health) and is_equal_approx(restored_health.current_health, 42.0), "世界恢复后树人生命不一致")

	_verify_resume_seat_replacement(map, record)
	map.queue_free()
	await get_tree().process_frame
	_finish()

func _verify_resume_seat_replacement(map: Node2D, record: Dictionary) -> void:
	var resume_record: Dictionary = record.duplicate(true)
	resume_record["session_snapshot"] = {
		"settings": {"room_name": "A与B的战斗", "team_count": 2, "players_per_team": 1},
		"players": [
			{"peer_id": 11, "name": "玩家A", "team": 1, "slot": 1, "territory_id": 1, "participant_id": "device-a"},
			{"peer_id": 22, "name": "玩家B", "team": 2, "slot": 1, "territory_id": 2, "participant_id": "device-b"},
		],
	}
	var session: LanSession = map.get("lan_session") as LanSession
	session.set("_players", {})
	session.call(&"_set_resume_record", resume_record)
	session.call(&"_connect_resume_player", 1, "玩家A", "device-a", true)
	session.call(&"_connect_resume_player", 3, "玩家C", "device-c", false)
	session.call(&"_server_claim_resume_seat", 3, 2, 1)
	var roster: Array[Dictionary] = session.get("_resume_roster") as Array[Dictionary]
	var replacement: Dictionary = roster[1] if roster.size() > 1 else {}
	_expect(str(replacement.get("participant_id", "")) == "device-c", "无存档玩家没有顶替原离线席位")
	_expect(str(replacement.get("replaced_participant_id", "")) == "device-b", "席位顶替没有保留被替换玩家标识")
	_expect(int(replacement.get("territory_id", 0)) == 2, "席位顶替改变了原战斗领地归属")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if not _temporary_save_path.is_empty() and FileAccess.file_exists(_temporary_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_temporary_save_path))
	if _failures.is_empty():
		print("SAVE_SYSTEM_SMOKE_TEST: PASS")
		await get_tree().create_timer(2.0, true).timeout
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("SAVE_SYSTEM_SMOKE_TEST: %s" % failure)
	await get_tree().create_timer(2.0, true).timeout
	get_tree().quit(1)

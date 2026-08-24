class_name LanSession
extends Node

signal rooms_changed(rooms: Array[Dictionary])
signal connection_state_changed(state: int, message: String)
signal room_joined(snapshot: Dictionary)
signal room_updated(snapshot: Dictionary)
signal room_left
signal action_rejected(message: String)
signal game_start_received(snapshot: Dictionary)

enum State { IDLE, BROWSING, CONNECTING, IN_ROOM }
enum ResourceAbundance { SCARCE, STANDARD, RICH }

const DISCOVERY_PORT: int = 45454
const GAME_PORT: int = 45455
const PROTOCOL_VERSION: int = 1
const MAX_NETWORK_CLIENTS: int = 16
const DISCOVERY_QUERY_INTERVAL: float = 0.8
const ROOM_EXPIRY_MSEC: int = 3200
const BROADCAST_ADDRESS: String = "255.255.255.255"

var state: State = State.IDLE

var _discovery_client: PacketPeerUDP
var _discovery_server: PacketPeerUDP
var _discovery_elapsed: float = 0.0
var _discovered_rooms: Dictionary = {}

var _network_peer: ENetMultiplayerPeer
var _is_host: bool = false
var _room_password: String = ""
var _room_nonce: String = ""
var _local_player_name: String = "玩家"
var _pending_password: String = ""
var _pending_room: Dictionary = {}
var _join_rejected: bool = false

var _settings: Dictionary = {}
var _players: Dictionary = {}
var _room_snapshot: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _process(delta: float) -> void:
	_poll_discovery_server()
	_poll_discovery_client()
	if not is_instance_valid(_discovery_client):
		return
	_discovery_elapsed += delta
	if _discovery_elapsed >= DISCOVERY_QUERY_INTERVAL:
		_discovery_elapsed = 0.0
		_send_discovery_query()
	_expire_stale_rooms()

func start_discovery() -> bool:
	if is_instance_valid(_discovery_client) and _discovery_client.is_bound():
		_set_state(State.BROWSING, "正在搜索局域网房间…")
		_send_discovery_query()
		return true
	_discovery_client = PacketPeerUDP.new()
	var bind_error: Error = _discovery_client.bind(0)
	if bind_error != OK:
		_discovery_client = null
		_reject("无法启动局域网搜索，UDP 错误：%s" % error_string(bind_error))
		return false
	_discovery_client.set_broadcast_enabled(true)
	_discovery_elapsed = DISCOVERY_QUERY_INTERVAL
	_set_state(State.BROWSING, "正在搜索局域网房间…")
	return true

func stop_discovery() -> void:
	if is_instance_valid(_discovery_client):
		_discovery_client.close()
	_discovery_client = null
	_discovered_rooms.clear()
	var empty_rooms: Array[Dictionary] = []
	rooms_changed.emit(empty_rooms)
	if state == State.BROWSING:
		_set_state(State.IDLE, "")

func refresh_discovery() -> void:
	if not is_instance_valid(_discovery_client):
		start_discovery()
		return
	_send_discovery_query()

func create_room(
	room_name: String,
	password: String,
	player_name: String,
	team_count: int = 2,
	players_per_team: int = 2,
	resource_abundance: int = ResourceAbundance.STANDARD
) -> bool:
	leave_room(false)
	stop_discovery()
	_local_player_name = _sanitize_name(player_name, "房主")
	_room_password = password.left(32)
	_room_nonce = "%d-%d" % [int(Time.get_unix_time_from_system()), randi()]
	_settings = {
		"room_name": _sanitize_name(room_name, "%s的房间" % _local_player_name),
		"team_count": clampi(team_count, 2, 4),
		"players_per_team": clampi(players_per_team, 1, 4),
		"resource_abundance": clampi(resource_abundance, ResourceAbundance.SCARCE, ResourceAbundance.RICH),
	}

	_discovery_server = PacketPeerUDP.new()
	var discovery_error: Error = _discovery_server.bind(DISCOVERY_PORT)
	if discovery_error != OK:
		_discovery_server = null
		_reject("无法创建房间：发现端口 %d 被占用（%s）" % [DISCOVERY_PORT, error_string(discovery_error)])
		return false

	_network_peer = ENetMultiplayerPeer.new()
	var server_error: Error = _network_peer.create_server(GAME_PORT, MAX_NETWORK_CLIENTS)
	if server_error != OK:
		_discovery_server.close()
		_discovery_server = null
		_network_peer = null
		_reject("无法创建房间：游戏端口 %d 被占用（%s）" % [GAME_PORT, error_string(server_error)])
		return false

	multiplayer.multiplayer_peer = _network_peer
	_is_host = true
	_players.clear()
	_players[MultiplayerPeer.TARGET_PEER_SERVER] = _make_player(
		MultiplayerPeer.TARGET_PEER_SERVER,
		_local_player_name,
		1,
		1,
		true
	)
	_set_state(State.IN_ROOM, "房间已创建")
	_broadcast_snapshot()
	room_joined.emit(_room_snapshot.duplicate(true))
	return true

func join_room(room: Dictionary, password: String, player_name: String) -> bool:
	var address: String = str(room.get("address", ""))
	var port: int = int(room.get("game_port", GAME_PORT))
	if address.is_empty():
		_reject("房间地址无效")
		return false
	leave_room(false)
	stop_discovery()
	_local_player_name = _sanitize_name(player_name, "玩家")
	_pending_password = password.left(32)
	_pending_room = room.duplicate(true)
	_join_rejected = false
	_network_peer = ENetMultiplayerPeer.new()
	var client_error: Error = _network_peer.create_client(address, port)
	if client_error != OK:
		_network_peer = null
		_reject("无法连接 %s:%d（%s）" % [address, port, error_string(client_error)])
		start_discovery()
		return false
	multiplayer.multiplayer_peer = _network_peer
	_is_host = false
	_set_state(State.CONNECTING, "正在连接 %s…" % str(room.get("room_name", address)))
	return true

func leave_room(resume_discovery: bool = false) -> void:
	var was_in_room: bool = state == State.IN_ROOM or state == State.CONNECTING
	if is_instance_valid(_network_peer):
		_network_peer.close()
	_network_peer = null
	multiplayer.multiplayer_peer = null
	if is_instance_valid(_discovery_server):
		_discovery_server.close()
	_discovery_server = null
	_is_host = false
	_room_password = ""
	_room_nonce = ""
	_pending_password = ""
	_pending_room.clear()
	_players.clear()
	_settings.clear()
	_room_snapshot.clear()
	if was_in_room:
		room_left.emit()
	if resume_discovery:
		start_discovery()
	else:
		_set_state(State.IDLE, "")

func is_host() -> bool:
	return _is_host and state == State.IN_ROOM

func get_local_peer_id() -> int:
	if state != State.IN_ROOM:
		return 0
	return multiplayer.get_unique_id()

func get_room_snapshot() -> Dictionary:
	return _room_snapshot.duplicate(true)

func update_room_settings(team_count: int, players_per_team: int, resource_abundance: int) -> void:
	if not is_host():
		_reject("只有房主可以修改房间设置")
		return
	var new_team_count: int = clampi(team_count, 2, 4)
	var new_players_per_team: int = clampi(players_per_team, 1, 4)
	if new_team_count * new_players_per_team < _players.size():
		_reject("座位容量不能小于当前玩家人数")
		_broadcast_snapshot()
		return
	_settings["team_count"] = new_team_count
	_settings["players_per_team"] = new_players_per_team
	_settings["resource_abundance"] = clampi(resource_abundance, ResourceAbundance.SCARCE, ResourceAbundance.RICH)
	_repack_players()
	_broadcast_snapshot()

func request_seat(team: int, slot: int) -> void:
	if state != State.IN_ROOM:
		return
	if is_host():
		_server_move_player(MultiplayerPeer.TARGET_PEER_SERVER, team, slot)
	else:
		_rpc_request_seat.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, team, slot)

func set_local_ready(is_ready: bool) -> void:
	if state != State.IN_ROOM:
		return
	if is_host():
		_server_set_ready(MultiplayerPeer.TARGET_PEER_SERVER, is_ready)
	else:
		_rpc_set_ready.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, is_ready)

func request_start_game() -> void:
	if not is_host():
		_reject("只有房主可以开始游戏")
		return
	if not _can_start_game():
		_reject("所有玩家准备后才能开始游戏")
		return
	var snapshot: Dictionary = _build_snapshot()
	_rpc_start_game.rpc(snapshot)
	game_start_received.emit(snapshot.duplicate(true))

@rpc("any_peer", "call_remote", "reliable")
func _rpc_submit_join(password: String, player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id: int = multiplayer.get_remote_sender_id()
	if peer_id <= MultiplayerPeer.TARGET_PEER_SERVER:
		return
	if password != _room_password:
		_rpc_join_result.rpc_id(peer_id, false, "房间密码错误", {})
		_schedule_peer_disconnect(peer_id)
		return
	var capacity: int = int(_settings.get("team_count", 2)) * int(_settings.get("players_per_team", 2))
	if _players.size() >= capacity:
		_rpc_join_result.rpc_id(peer_id, false, "房间已满", {})
		_schedule_peer_disconnect(peer_id)
		return
	var seat: Vector2i = _find_first_empty_seat()
	var unique_name: String = _make_unique_player_name(_sanitize_name(player_name, "玩家%d" % peer_id))
	_players[peer_id] = _make_player(peer_id, unique_name, seat.x, seat.y, false)
	var snapshot: Dictionary = _build_snapshot()
	_rpc_join_result.rpc_id(peer_id, true, "加入成功", snapshot)
	_broadcast_snapshot()

@rpc("authority", "call_remote", "reliable")
func _rpc_join_result(accepted: bool, message: String, snapshot: Dictionary) -> void:
	if accepted:
		_room_snapshot = snapshot.duplicate(true)
		_set_state(State.IN_ROOM, message)
		room_joined.emit(_room_snapshot.duplicate(true))
		return
	_join_rejected = true
	_reject(message)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_seat(team: int, slot: int) -> void:
	if not multiplayer.is_server():
		return
	var peer_id: int = multiplayer.get_remote_sender_id()
	if _players.has(peer_id):
		_server_move_player(peer_id, team, slot)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_set_ready(is_ready: bool) -> void:
	if not multiplayer.is_server():
		return
	var peer_id: int = multiplayer.get_remote_sender_id()
	if _players.has(peer_id):
		_server_set_ready(peer_id, is_ready)

@rpc("authority", "call_remote", "reliable")
func _rpc_receive_snapshot(snapshot: Dictionary) -> void:
	_room_snapshot = snapshot.duplicate(true)
	room_updated.emit(_room_snapshot.duplicate(true))

@rpc("authority", "call_remote", "reliable")
func _rpc_start_game(snapshot: Dictionary) -> void:
	_room_snapshot = snapshot.duplicate(true)
	game_start_received.emit(_room_snapshot.duplicate(true))

func _server_move_player(peer_id: int, team: int, slot: int) -> void:
	if not _players.has(peer_id):
		return
	var team_count: int = int(_settings.get("team_count", 2))
	var players_per_team: int = int(_settings.get("players_per_team", 2))
	if team < 1 or team > team_count or slot < 1 or slot > players_per_team:
		_reject("目标座位无效")
		return
	var moving_player: Dictionary = (_players[peer_id] as Dictionary).duplicate(true)
	var old_team: int = int(moving_player.get("team", 1))
	var old_slot: int = int(moving_player.get("slot", 1))
	var occupant_id: int = _find_player_at(team, slot)
	moving_player["team"] = team
	moving_player["slot"] = slot
	_players[peer_id] = moving_player
	if occupant_id > 0 and occupant_id != peer_id:
		var occupant: Dictionary = (_players[occupant_id] as Dictionary).duplicate(true)
		occupant["team"] = old_team
		occupant["slot"] = old_slot
		_players[occupant_id] = occupant
	_broadcast_snapshot()

func _server_set_ready(peer_id: int, is_ready: bool) -> void:
	if not _players.has(peer_id):
		return
	var player: Dictionary = (_players[peer_id] as Dictionary).duplicate(true)
	player["ready"] = is_ready
	_players[peer_id] = player
	_broadcast_snapshot()

func _repack_players() -> void:
	var peer_ids: Array[int] = []
	for peer_id_value: Variant in _players.keys():
		peer_ids.append(int(peer_id_value))
	peer_ids.sort()
	var players_per_team: int = int(_settings.get("players_per_team", 2))
	for index: int in peer_ids.size():
		var peer_id: int = peer_ids[index]
		var player: Dictionary = (_players[peer_id] as Dictionary).duplicate(true)
		player["team"] = floori(float(index) / float(players_per_team)) + 1
		player["slot"] = index % players_per_team + 1
		player["ready"] = false
		_players[peer_id] = player

func _broadcast_snapshot() -> void:
	if not is_host():
		return
	_room_snapshot = _build_snapshot()
	room_updated.emit(_room_snapshot.duplicate(true))
	_rpc_receive_snapshot.rpc(_room_snapshot)

func _build_snapshot() -> Dictionary:
	var player_list: Array[Dictionary] = []
	for player_value: Variant in _players.values():
		player_list.append((player_value as Dictionary).duplicate(true))
	player_list.sort_custom(_sort_players)
	return {
		"room_id": _room_nonce,
		"host_id": MultiplayerPeer.TARGET_PEER_SERVER,
		"settings": _settings.duplicate(true),
		"players": player_list,
		"can_start": _can_start_game(),
	}

func _make_player(peer_id: int, player_name: String, team: int, slot: int, host: bool) -> Dictionary:
	return {
		"peer_id": peer_id,
		"name": player_name,
		"team": team,
		"slot": slot,
		"ready": false,
		"is_host": host,
	}

func _find_first_empty_seat() -> Vector2i:
	var team_count: int = int(_settings.get("team_count", 2))
	var players_per_team: int = int(_settings.get("players_per_team", 2))
	for team: int in range(1, team_count + 1):
		for slot: int in range(1, players_per_team + 1):
			if _find_player_at(team, slot) == 0:
				return Vector2i(team, slot)
	return Vector2i(1, 1)

func _find_player_at(team: int, slot: int) -> int:
	for peer_id_value: Variant in _players.keys():
		var peer_id: int = int(peer_id_value)
		var player: Dictionary = _players[peer_id] as Dictionary
		if int(player.get("team", 0)) == team and int(player.get("slot", 0)) == slot:
			return peer_id
	return 0

func _can_start_game() -> bool:
	if _players.is_empty():
		return false
	for player_value: Variant in _players.values():
		var player: Dictionary = player_value as Dictionary
		if not bool(player.get("ready", false)):
			return false
	return true

func _make_unique_player_name(requested_name: String) -> String:
	var used_names: Dictionary = {}
	for player_value: Variant in _players.values():
		used_names[str((player_value as Dictionary).get("name", ""))] = true
	if not used_names.has(requested_name):
		return requested_name
	var suffix: int = 2
	while used_names.has("%s%d" % [requested_name, suffix]):
		suffix += 1
	return "%s%d" % [requested_name, suffix]

func _sort_players(left: Dictionary, right: Dictionary) -> bool:
	var left_key: int = int(left.get("team", 0)) * 100 + int(left.get("slot", 0))
	var right_key: int = int(right.get("team", 0)) * 100 + int(right.get("slot", 0))
	return left_key < right_key

func _on_connected_to_server() -> void:
	_rpc_submit_join.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, _pending_password, _local_player_name)

func _on_connection_failed() -> void:
	_cleanup_client_connection()
	_reject("连接房间失败")
	start_discovery()

func _on_server_disconnected() -> void:
	var message: String = "房主已关闭房间"
	if _join_rejected:
		message = "加入房间失败"
	_cleanup_client_connection()
	_reject(message)
	start_discovery()

func _on_peer_connected(_peer_id: int) -> void:
	pass

func _on_peer_disconnected(peer_id: int) -> void:
	if not is_host() or not _players.has(peer_id):
		return
	_players.erase(peer_id)
	_broadcast_snapshot()

func _cleanup_client_connection() -> void:
	if is_instance_valid(_network_peer):
		_network_peer.close()
	_network_peer = null
	multiplayer.multiplayer_peer = null
	_players.clear()
	_room_snapshot.clear()
	_is_host = false
	_set_state(State.IDLE, "")
	room_left.emit()

func _schedule_peer_disconnect(peer_id: int) -> void:
	var timer: SceneTreeTimer = get_tree().create_timer(0.25, true)
	timer.timeout.connect(_disconnect_peer.bind(peer_id), CONNECT_ONE_SHOT)

func _disconnect_peer(peer_id: int) -> void:
	if is_host() and is_instance_valid(_network_peer):
		_network_peer.disconnect_peer(peer_id)

func _send_discovery_query() -> void:
	if not is_instance_valid(_discovery_client):
		return
	var address_error: Error = _discovery_client.set_dest_address(BROADCAST_ADDRESS, DISCOVERY_PORT)
	if address_error != OK:
		return
	var query: Dictionary = {"type": "discover", "protocol": PROTOCOL_VERSION}
	_discovery_client.put_packet(_encode_message(query))

func _poll_discovery_server() -> void:
	if not is_instance_valid(_discovery_server) or not is_host():
		return
	while _discovery_server.get_available_packet_count() > 0:
		var packet: PackedByteArray = _discovery_server.get_packet()
		var sender_ip: String = _discovery_server.get_packet_ip()
		var sender_port: int = _discovery_server.get_packet_port()
		var message: Dictionary = _decode_message(packet)
		if str(message.get("type", "")) != "discover" or int(message.get("protocol", 0)) != PROTOCOL_VERSION:
			continue
		var room_info: Dictionary = _build_discovery_room_info()
		if _discovery_server.set_dest_address(sender_ip, sender_port) == OK:
			_discovery_server.put_packet(_encode_message(room_info))

func _poll_discovery_client() -> void:
	if not is_instance_valid(_discovery_client):
		return
	while is_instance_valid(_discovery_client) and _discovery_client.get_available_packet_count() > 0:
		var packet: PackedByteArray = _discovery_client.get_packet()
		var sender_ip: String = _discovery_client.get_packet_ip()
		var room: Dictionary = _decode_message(packet)
		if str(room.get("type", "")) != "room" or int(room.get("protocol", 0)) != PROTOCOL_VERSION:
			continue
		room["address"] = sender_ip
		room["last_seen_msec"] = Time.get_ticks_msec()
		var key: String = "%s:%d" % [sender_ip, int(room.get("game_port", GAME_PORT))]
		var changed: bool = not _discovered_rooms.has(key) or _room_info_changed(_discovered_rooms[key] as Dictionary, room)
		_discovered_rooms[key] = room
		if changed:
			_emit_discovered_rooms()

func _build_discovery_room_info() -> Dictionary:
	var team_count: int = int(_settings.get("team_count", 2))
	var players_per_team: int = int(_settings.get("players_per_team", 2))
	return {
		"type": "room",
		"protocol": PROTOCOL_VERSION,
		"room_id": _room_nonce,
		"room_name": str(_settings.get("room_name", "局域网房间")),
		"game_port": GAME_PORT,
		"password_required": not _room_password.is_empty(),
		"player_count": _players.size(),
		"max_players": team_count * players_per_team,
		"team_count": team_count,
		"players_per_team": players_per_team,
		"resource_abundance": int(_settings.get("resource_abundance", ResourceAbundance.STANDARD)),
	}

func _room_info_changed(previous: Dictionary, current: Dictionary) -> bool:
	for key_value: Variant in current.keys():
		var key: String = str(key_value)
		if key == "last_seen_msec":
			continue
		if previous.get(key) != current.get(key):
			return true
	return false

func _expire_stale_rooms() -> void:
	var now: int = Time.get_ticks_msec()
	var expired_keys: Array[Variant] = []
	for key_value: Variant in _discovered_rooms.keys():
		var room: Dictionary = _discovered_rooms[key_value] as Dictionary
		if now - int(room.get("last_seen_msec", 0)) > ROOM_EXPIRY_MSEC:
			expired_keys.append(key_value)
	if expired_keys.is_empty():
		return
	for key_value: Variant in expired_keys:
		_discovered_rooms.erase(key_value)
	_emit_discovered_rooms()

func _emit_discovered_rooms() -> void:
	var rooms: Array[Dictionary] = []
	for room_value: Variant in _discovered_rooms.values():
		var room: Dictionary = (room_value as Dictionary).duplicate(true)
		room.erase("last_seen_msec")
		rooms.append(room)
	rooms.sort_custom(_sort_rooms)
	rooms_changed.emit(rooms)

func _sort_rooms(left: Dictionary, right: Dictionary) -> bool:
	return str(left.get("room_name", "")) < str(right.get("room_name", ""))

func _encode_message(message: Dictionary) -> PackedByteArray:
	return JSON.stringify(message).to_utf8_buffer()

func _decode_message(packet: PackedByteArray) -> Dictionary:
	var parsed: Variant = JSON.parse_string(packet.get_string_from_utf8())
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}

func _sanitize_name(value: String, fallback: String) -> String:
	var sanitized: String = value.strip_edges().left(24)
	return fallback if sanitized.is_empty() else sanitized

func _set_state(next_state: State, message: String) -> void:
	state = next_state
	connection_state_changed.emit(state, message)

func _reject(message: String) -> void:
	action_rejected.emit(message)

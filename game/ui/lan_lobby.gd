class_name LanLobby
extends CanvasLayer

signal back_requested
signal game_start_requested(snapshot: Dictionary)

const PANEL_COLOR: Color = Color("#10211ef5")
const BORDER_COLOR: Color = Color("#d7b76b")
const TEXT_COLOR: Color = Color("#fff0bc")
const MUTED_COLOR: Color = Color("#a7bbb1")
const ACCENT_COLOR: Color = Color("#426653")

var _session: LanSession
var _root: Control
var _panel: PanelContainer
var _title_label: Label
var _status_label: Label
var _error_dialog: AcceptDialog
var _content: VBoxContainer
var _room_list: ItemList
var _room_detail: Label
var _join_password: LineEdit
var _rooms: Array[Dictionary] = []
var _selected_room_index: int = -1
var _player_name: String = "玩家"
var _last_snapshot: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 40
	_build_shell()
	hide()

func bind(session: LanSession) -> void:
	if is_instance_valid(_session):
		return
	_session = session
	_session.rooms_changed.connect(_on_rooms_changed)
	_session.connection_state_changed.connect(_on_connection_state_changed)
	_session.room_joined.connect(_on_room_snapshot)
	_session.room_updated.connect(_on_room_snapshot)
	_session.room_left.connect(_on_room_left)
	_session.action_rejected.connect(_on_action_rejected)
	_session.game_start_received.connect(_on_game_start_received)

func open() -> void:
	if not is_instance_valid(_session):
		return
	show()
	_show_browser()
	_session.start_discovery()

func close_lobby(leave_network: bool = true) -> void:
	hide()
	if leave_network and is_instance_valid(_session):
		_session.leave_room(false)

func _build_shell() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	_root.resized.connect(_layout_panel)

	var backdrop: ColorRect = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("#061014f2")
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(backdrop)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _make_panel_style())
	_root.add_child(_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	_panel.add_child(margin)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	_title_label = _make_label("局域网大厅", 24, TEXT_COLOR)
	column.add_child(_title_label)

	_status_label = _make_label("", 11, MUTED_COLOR)
	_status_label.custom_minimum_size = Vector2(0.0, 18.0)
	column.add_child(_status_label)

	var rule: HSeparator = HSeparator.new()
	column.add_child(rule)

	_content = VBoxContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	column.add_child(_content)

	_error_dialog = AcceptDialog.new()
	_error_dialog.title = "无法完成操作"
	_error_dialog.dialog_text = ""
	_error_dialog.ok_button_text = "确定"
	_error_dialog.exclusive = true
	_error_dialog.min_size = Vector2i(360, 150)
	add_child(_error_dialog)
	_layout_panel()

func _layout_panel() -> void:
	if not is_instance_valid(_panel):
		return
	var viewport_size: Vector2 = _root.size
	var panel_size: Vector2 = Vector2(minf(610.0, viewport_size.x - 20.0), minf(450.0, viewport_size.y - 20.0))
	_panel.position = (viewport_size - panel_size) / 2.0
	_panel.size = panel_size

func _show_browser() -> void:
	_title_label.text = "局域网大厅  /  可用房间"
	_clear_content()

	var identity_row: HBoxContainer = HBoxContainer.new()
	identity_row.add_theme_constant_override("separation", 8)
	_content.add_child(identity_row)
	identity_row.add_child(_make_label("玩家名称", 12, MUTED_COLOR))
	var player_name_edit: LineEdit = LineEdit.new()
	player_name_edit.text = _player_name
	player_name_edit.max_length = 24
	player_name_edit.placeholder_text = "输入玩家名称"
	player_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_name_edit.text_changed.connect(_on_player_name_changed)
	identity_row.add_child(player_name_edit)

	var browser_row: HBoxContainer = HBoxContainer.new()
	browser_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	browser_row.add_theme_constant_override("separation", 10)
	_content.add_child(browser_row)

	_room_list = ItemList.new()
	_room_list.custom_minimum_size = Vector2(335.0, 210.0)
	_room_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_room_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_room_list.item_selected.connect(_on_room_selected)
	_room_list.item_activated.connect(_on_room_activated)
	browser_row.add_child(_room_list)

	var detail_column: VBoxContainer = VBoxContainer.new()
	detail_column.custom_minimum_size = Vector2(215.0, 0.0)
	detail_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_column.add_theme_constant_override("separation", 8)
	browser_row.add_child(detail_column)
	_room_detail = _make_label("选择一个房间查看详情", 11, MUTED_COLOR)
	_room_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_room_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_column.add_child(_room_detail)
	_join_password = LineEdit.new()
	_join_password.placeholder_text = "房间密码（如需要）"
	_join_password.secret = true
	detail_column.add_child(_join_password)
	var join_button: Button = _make_button("加入房间", true)
	join_button.pressed.connect(_join_selected_room)
	detail_column.add_child(join_button)

	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	_content.add_child(actions)
	var refresh_button: Button = _make_button("刷新", false)
	refresh_button.pressed.connect(_refresh_rooms)
	actions.add_child(refresh_button)
	var create_button: Button = _make_button("创建房间", true)
	create_button.pressed.connect(_show_create_room)
	actions.add_child(create_button)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	var back_button: Button = _make_button("返回主菜单", false)
	back_button.pressed.connect(_back_to_main_menu)
	actions.add_child(back_button)
	_populate_room_list()

func _show_create_room() -> void:
	_title_label.text = "局域网大厅  /  创建房间"
	_status_label.text = "本机将作为房主，局域网内其他玩家可自动发现此房间。"
	_clear_content()

	var room_name_edit: LineEdit = _add_labeled_line_edit("房间名称", "%s的房间" % _player_name, false)
	var password_edit: LineEdit = _add_labeled_line_edit("房间密码", "可留空", true)
	_content.add_child(_make_label("创建后可在准备界面调整队伍数量、每队人数与资源丰富度。", 11, MUTED_COLOR))
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(spacer)
	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	_content.add_child(actions)
	var create_button: Button = _make_button("创建并进入准备界面", true)
	create_button.pressed.connect(_create_room.bind(room_name_edit, password_edit))
	actions.add_child(create_button)
	var cancel_button: Button = _make_button("取消", false)
	cancel_button.pressed.connect(_cancel_create)
	actions.add_child(cancel_button)

func _render_room(snapshot: Dictionary) -> void:
	_last_snapshot = snapshot.duplicate(true)
	var settings: Dictionary = snapshot.get("settings", {}) as Dictionary
	var players: Array = snapshot.get("players", []) as Array
	_title_label.text = "准备界面  /  %s" % str(settings.get("room_name", "局域网房间"))
	_clear_content()

	var host_controls: HBoxContainer = HBoxContainer.new()
	host_controls.add_theme_constant_override("separation", 8)
	_content.add_child(host_controls)
	var team_option: OptionButton = _make_number_option("队伍数", 2, 4, int(settings.get("team_count", 2)))
	var size_option: OptionButton = _make_number_option("每队人数", 1, 4, int(settings.get("players_per_team", 2)))
	var abundance_option: OptionButton = OptionButton.new()
	abundance_option.add_item("贫瘠")
	abundance_option.add_item("标准")
	abundance_option.add_item("丰富")
	abundance_option.select(clampi(int(settings.get("resource_abundance", 1)), 0, 2))
	host_controls.add_child(_make_label("资源", 11, MUTED_COLOR))
	host_controls.add_child(abundance_option)
	team_option.disabled = not _session.is_host()
	size_option.disabled = not _session.is_host()
	abundance_option.disabled = not _session.is_host()
	team_option.item_selected.connect(_on_settings_changed.bind(team_option, size_option, abundance_option))
	size_option.item_selected.connect(_on_settings_changed.bind(team_option, size_option, abundance_option))
	abundance_option.item_selected.connect(_on_settings_changed.bind(team_option, size_option, abundance_option))

	var seats_scroll: ScrollContainer = ScrollContainer.new()
	seats_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	seats_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(seats_scroll)
	var teams_row: HBoxContainer = HBoxContainer.new()
	teams_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	teams_row.add_theme_constant_override("separation", 8)
	seats_scroll.add_child(teams_row)
	var team_count: int = int(settings.get("team_count", 2))
	var players_per_team: int = int(settings.get("players_per_team", 2))
	for team: int in range(1, team_count + 1):
		var team_panel: PanelContainer = PanelContainer.new()
		team_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		team_panel.add_theme_stylebox_override("panel", _make_subpanel_style())
		teams_row.add_child(team_panel)
		var team_column: VBoxContainer = VBoxContainer.new()
		team_column.add_theme_constant_override("separation", 5)
		team_panel.add_child(team_column)
		var team_title: Label = _make_label("队伍 %d" % team, 13, TEXT_COLOR)
		team_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		team_column.add_child(team_title)
		for slot: int in range(1, players_per_team + 1):
			var occupant: Dictionary = _find_player(players, team, slot)
			var seat_text: String = "%d. 空位" % slot
			if not occupant.is_empty():
				seat_text = "%d. %s%s%s" % [
					slot,
					str(occupant.get("name", "玩家")),
					" [房主]" if bool(occupant.get("is_host", false)) else "",
					" ✓" if bool(occupant.get("ready", false)) else "",
				]
			var seat_button: Button = _make_button(seat_text, int(occupant.get("peer_id", 0)) == _session.get_local_peer_id())
			seat_button.pressed.connect(_on_seat_pressed.bind(team, slot))
			team_column.add_child(seat_button)

	var local_player: Dictionary = _find_player_by_peer(players, _session.get_local_peer_id())
	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	_content.add_child(actions)
	var ready_button: Button = _make_button("取消准备" if bool(local_player.get("ready", false)) else "准备", true)
	ready_button.pressed.connect(_toggle_ready.bind(not bool(local_player.get("ready", false))))
	actions.add_child(ready_button)
	if _session.is_host():
		var start_button: Button = _make_button("开始游戏", true)
		start_button.disabled = not bool(snapshot.get("can_start", false))
		start_button.pressed.connect(_session.request_start_game)
		actions.add_child(start_button)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	var leave_button: Button = _make_button("离开房间", false)
	leave_button.pressed.connect(_leave_room)
	actions.add_child(leave_button)
	_status_label.text = "%d 名玩家 · 点击任意座位可移动；占用座位会与对方交换。" % players.size()

func _clear_content() -> void:
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()

func _populate_room_list() -> void:
	if not is_instance_valid(_room_list):
		return
	_room_list.clear()
	for room: Dictionary in _rooms:
		var lock_mark: String = " [密码]" if bool(room.get("password_required", false)) else ""
		_room_list.add_item("%s%s    %d/%d" % [room.get("room_name", "房间"), lock_mark, room.get("player_count", 0), room.get("max_players", 0)])
	if _rooms.is_empty():
		_room_detail.text = "尚未发现房间。\n\n搜索会自动持续进行，也可点击刷新。"
		_selected_room_index = -1
	elif _selected_room_index >= 0 and _selected_room_index < _rooms.size():
		_room_list.select(_selected_room_index)
		_update_room_detail()

func _update_room_detail() -> void:
	if _selected_room_index < 0 or _selected_room_index >= _rooms.size():
		return
	var room: Dictionary = _rooms[_selected_room_index]
	var abundance_names: Array[String] = ["贫瘠", "标准", "丰富"]
	var abundance: int = clampi(int(room.get("resource_abundance", 1)), 0, 2)
	_room_detail.text = "%s\n\n地址：%s:%d\n队伍：%d\n每队人数：%d\n资源：%s" % [
		room.get("room_name", "房间"), room.get("address", ""), room.get("game_port", 0),
		room.get("team_count", 2), room.get("players_per_team", 2), abundance_names[abundance],
	]
	_join_password.visible = bool(room.get("password_required", false))

func _add_labeled_line_edit(label_text: String, placeholder: String, secret: bool) -> LineEdit:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_content.add_child(row)
	var label: Label = _make_label(label_text, 12, MUTED_COLOR)
	label.custom_minimum_size = Vector2(90.0, 0.0)
	row.add_child(label)
	var edit: LineEdit = LineEdit.new()
	edit.placeholder_text = placeholder
	edit.secret = secret
	edit.max_length = 32
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(edit)
	return edit

func _make_number_option(label_text: String, minimum: int, maximum: int, selected_value: int) -> OptionButton:
	var label: Label = _make_label(label_text, 11, MUTED_COLOR)
	_content.get_child(_content.get_child_count() - 1).add_child(label)
	var option: OptionButton = OptionButton.new()
	for value: int in range(minimum, maximum + 1):
		option.add_item(str(value), value)
	option.select(clampi(selected_value, minimum, maximum) - minimum)
	_content.get_child(_content.get_child_count() - 1).add_child(option)
	return option

func _make_label(text_value: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _make_button(text_value: String, primary: bool) -> Button:
	var button: Button = Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0.0, 30.0)
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_stylebox_override("normal", _make_button_style(ACCENT_COLOR if primary else Color("#263a34")))
	button.add_theme_stylebox_override("hover", _make_button_style(Color("#567c64")))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color("#1b302b")))
	return button

func _make_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	return style

func _make_subpanel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("#172d28")
	style.border_color = Color("#5d7f6b")
	style.set_border_width_all(1)
	style.set_content_margin_all(7.0)
	return style

func _make_button_style(background: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = Color("#789987")
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	return style

func _on_player_name_changed(value: String) -> void:
	_player_name = value.strip_edges().left(24)

func _on_rooms_changed(rooms: Array[Dictionary]) -> void:
	_rooms = rooms
	if _selected_room_index >= _rooms.size():
		_selected_room_index = -1
	_populate_room_list()

func _on_room_selected(index: int) -> void:
	_selected_room_index = index
	_update_room_detail()

func _on_room_activated(index: int) -> void:
	_selected_room_index = index
	_join_selected_room()

func _join_selected_room() -> void:
	if _selected_room_index < 0 or _selected_room_index >= _rooms.size():
		_status_label.text = "请先选择一个房间。"
		return
	var password: String = _join_password.text if is_instance_valid(_join_password) else ""
	_session.join_room(_rooms[_selected_room_index], password, _player_name)

func _refresh_rooms() -> void:
	_status_label.text = "正在刷新局域网房间…"
	_session.refresh_discovery()

func _create_room(room_name_edit: LineEdit, password_edit: LineEdit) -> void:
	_session.create_room(room_name_edit.text, password_edit.text, _player_name)

func _cancel_create() -> void:
	_show_browser()
	_session.start_discovery()

func _back_to_main_menu() -> void:
	_session.stop_discovery()
	hide()
	back_requested.emit()

func _leave_room() -> void:
	_session.leave_room(true)
	_show_browser()

func _on_settings_changed(_selected_index: int, team_option: OptionButton, size_option: OptionButton, abundance_option: OptionButton) -> void:
	_session.update_room_settings(team_option.get_selected_id(), size_option.get_selected_id(), abundance_option.selected)

func _on_seat_pressed(team: int, slot: int) -> void:
	_session.request_seat(team, slot)

func _toggle_ready(is_ready: bool) -> void:
	_session.set_local_ready(is_ready)

func _on_connection_state_changed(_state: int, message: String) -> void:
	if not message.is_empty():
		_status_label.text = message

func _on_room_snapshot(snapshot: Dictionary) -> void:
	call_deferred("_render_room", snapshot.duplicate(true))

func _on_room_left() -> void:
	if visible:
		call_deferred("_show_browser")

func _on_action_rejected(message: String) -> void:
	_status_label.text = message
	_error_dialog.dialog_text = message
	_error_dialog.popup_centered(Vector2i(360, 150))

func _on_game_start_received(snapshot: Dictionary) -> void:
	hide()
	game_start_requested.emit(snapshot.duplicate(true))

func _find_player(players: Array, team: int, slot: int) -> Dictionary:
	for player_value: Variant in players:
		var player: Dictionary = player_value as Dictionary
		if int(player.get("team", 0)) == team and int(player.get("slot", 0)) == slot:
			return player
	return {}

func _find_player_by_peer(players: Array, peer_id: int) -> Dictionary:
	for player_value: Variant in players:
		var player: Dictionary = player_value as Dictionary
		if int(player.get("peer_id", 0)) == peer_id:
			return player
	return {}

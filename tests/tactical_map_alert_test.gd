extends Node

var _damage_signal_received: bool = false
var _damage_source: String = ""
var _focused_position: Vector2 = Vector2.ZERO
var _map_selected_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	_test_persistent_exploration()
	_test_map_zoom_selection_and_hotkey()
	_test_damage_source_signal()
	_test_alert_coalescing_and_focus()
	_test_camera_jump_clamping()
	print("TACTICAL_MAP_ALERT_TEST: PASS")
	get_tree().quit()

func _test_persistent_exploration() -> void:
	var fog: FogOfWar = FogOfWar.new()
	add_child(fog)
	fog.configure(Vector2i(100, 100), 32, Rect2i(2, 2, 20, 20))
	_assert_true(fog.is_cell_explored(Vector2i(2, 2)), "己方领地应在开局时写入探索记录")
	_assert_true(not fog.is_cell_explored(Vector2i(90, 90)), "未到达区域不应提前探索")
	fog.update_visibility([{"position": Vector2(40.5 * 32.0, 40.5 * 32.0), "radius": 64.0}], false)
	_assert_true(fog.is_cell_explored(Vector2i(40, 40)), "单位视野应写入探索记录")
	fog.update_visibility([{"position": Vector2(60.5 * 32.0, 60.5 * 32.0), "radius": 64.0}], false)
	_assert_true(fog.is_cell_explored(Vector2i(40, 40)), "单位离开后历史探索记录应保留")
	_assert_true(fog.is_cell_rect_explored(Rect2i(39, 39, 3, 3)), "领地边框查询应识别与已探索格相交的区域")
	_assert_true(not fog.is_cell_rect_explored(Rect2i(88, 88, 4, 4)), "未探索区域不应提前出现在战术地图")
	_assert_true(fog.get_exploration_texture() != null, "战术地图应能取得探索纹理")
	fog.queue_free()

func _test_map_zoom_selection_and_hotkey() -> void:
	var fog: FogOfWar = FogOfWar.new()
	add_child(fog)
	fog.configure(Vector2i(100, 100), 32, Rect2i(2, 2, 20, 20))
	var camera: Camera2D = Camera2D.new()
	add_child(camera)
	var map_view: TacticalMapView = TacticalMapView.new()
	map_view.size = Vector2(300.0, 300.0)
	add_child(map_view)
	map_view.configure(fog, Vector2(3200.0, 3200.0), 32, _sample_map_data, camera)
	var entry_counts: Dictionary = map_view.get_cached_entry_counts()
	_assert_true(int(entry_counts.get("units", 0)) == 1, "详细地图应缓存战斗单位情报")
	_assert_true(int(entry_counts.get("resources", 0)) == 1, "详细地图应缓存已探索资源情报")
	_assert_true(int(entry_counts.get("buildings", 0)) == 1, "详细地图应缓存基地与建筑情报")
	_assert_true(int(entry_counts.get("territories", 0)) == 1, "详细地图应缓存已探索领地边界")
	map_view.world_selected.connect(_on_test_map_selected)
	var wheel_event: InputEventMouseButton = InputEventMouseButton.new()
	wheel_event.position = Vector2(150.0, 150.0)
	wheel_event.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_event.pressed = true
	map_view.call(&"_gui_input", wheel_event)
	_assert_true(map_view.get_map_zoom() > 1.0, "地图滚轮向上应放大")
	var center_before_drag: Vector2 = map_view.get_view_center()
	var drag_press: InputEventMouseButton = _left_mouse_event(Vector2(150.0, 150.0), true)
	map_view.call(&"_gui_input", drag_press)
	var drag_motion: InputEventMouseMotion = InputEventMouseMotion.new()
	drag_motion.position = Vector2(200.0, 150.0)
	drag_motion.relative = Vector2(50.0, 0.0)
	map_view.call(&"_gui_input", drag_motion)
	var drag_release: InputEventMouseButton = _left_mouse_event(Vector2(200.0, 150.0), false)
	map_view.call(&"_gui_input", drag_release)
	_assert_true(map_view.get_view_center().distance_to(center_before_drag) > 1.0, "地图放大后按住左键拖动应平移地图内容")
	_assert_true(_map_selected_position == Vector2.ZERO, "左键拖动不应误触发主视角定位")
	var click_press: InputEventMouseButton = _left_mouse_event(Vector2(150.0, 150.0), true)
	map_view.call(&"_gui_input", click_press)
	_assert_true(_map_selected_position == Vector2.ZERO, "左键按下阶段不应提前触发定位")
	var click_release: InputEventMouseButton = _left_mouse_event(Vector2(150.0, 150.0), false)
	map_view.call(&"_gui_input", click_release)
	_assert_true(_map_selected_position != Vector2.ZERO, "左键短按并释放应转换并发出世界坐标")

	var tactical_map: TacticalMap = TacticalMap.new()
	add_child(tactical_map)
	tactical_map.configure(fog, Vector2(3200.0, 3200.0), 32, _sample_map_data, camera)
	tactical_map.set_available(true)
	var map_key: InputEventKey = InputEventKey.new()
	map_key.keycode = KEY_M
	map_key.pressed = true
	tactical_map.call(&"_input", map_key)
	_assert_true(tactical_map.visible, "按 M 应打开战术地图")
	tactical_map.call(&"_on_world_selected", Vector2(704.0, 864.0))
	_assert_true(tactical_map.visible, "单击地图定位后战术地图应继续保持打开")
	var escape_key: InputEventKey = InputEventKey.new()
	escape_key.keycode = KEY_ESCAPE
	escape_key.pressed = true
	tactical_map.call(&"_input", escape_key)
	_assert_true(tactical_map.visible, "按 Esc 不应关闭只能由 M 切换的战术地图")
	tactical_map.call(&"_input", map_key)
	_assert_true(not tactical_map.visible, "再次按 M 应关闭战术地图")
	tactical_map.queue_free()
	map_view.queue_free()
	camera.queue_free()
	fog.queue_free()

func _test_damage_source_signal() -> void:
	var target: Node2D = Node2D.new()
	add_child(target)
	var health: HealthComponent = HealthComponent.new()
	target.add_child(health)
	health.configure(target, 1, 100.0, 5.0)
	health.damaged.connect(_on_test_damaged)
	var applied_damage: float = health.apply_attack(25.0, 2, 0.0, "测试剑士的普通攻击")
	_assert_true(is_equal_approx(applied_damage, 20.0), "伤害仍应按攻击减防御结算")
	_assert_true(_damage_signal_received, "受击时应发出带来源的 damaged 信号")
	_assert_true(_damage_source == "测试剑士的普通攻击", "damaged 信号应保留具体攻击来源")
	target.queue_free()

func _test_alert_coalescing_and_focus() -> void:
	var hud: AttackAlertHud = AttackAlertHud.new()
	add_child(hud)
	hud.set_available(true)
	hud.focus_requested.connect(_on_test_focus_requested)
	hud.show_attack_alert(7, "树人", "幽网织母的毒液攻击", 18.0, Vector2(640.0, 960.0))
	hud.show_attack_alert(7, "树人", "幽网织母的毒液攻击", 18.0, Vector2(672.0, 992.0))
	_assert_true(hud.get_alert_count() == 1, "同一单位连续受击应合并为一条提醒")
	hud.call(&"_on_alert_pressed", 7)
	_assert_true(_focused_position == Vector2(672.0, 992.0), "点击提醒应使用目标最新位置")
	_assert_true(hud.get_alert_count() == 0, "点击后的提醒应移出队列")
	hud.queue_free()

func _test_camera_jump_clamping() -> void:
	var camera: EdgeScrollCamera = EdgeScrollCamera.new()
	camera.map_size = Vector2(3200.0, 3200.0)
	camera.zoom = Vector2.ONE
	add_child(camera)
	camera.jump_to_world_position(Vector2(-500.0, 5000.0))
	_assert_true(camera.position.x >= 0.0 and camera.position.y <= camera.map_size.y, "视角跳转必须限制在地图边界内")
	camera.queue_free()

func _on_test_damaged(_component: HealthComponent, _damage: float, _source_owner_peer_id: int, source_description: String) -> void:
	_damage_signal_received = true
	_damage_source = source_description

func _on_test_focus_requested(world_position: Vector2) -> void:
	_focused_position = world_position

func _on_test_map_selected(world_position: Vector2) -> void:
	_map_selected_position = world_position

func _sample_map_data() -> Dictionary:
	return {
		"units": [{
			"key": "unit:1",
			"id": 1,
			"position": Vector2(480.0, 480.0),
			"color": Color("#78f0a1"),
			"category": &"combat",
			"health_ratio": 0.75,
			"in_combat": true,
			"hover": "测试剑士｜己方｜生命 75/100｜交战中",
		}],
		"resources": [{
			"key": "resource:1",
			"position": Vector2(520.0, 500.0),
			"resource_type": &"tree",
			"hover": "树木｜已探索资源点",
		}],
		"buildings": [{
			"key": "base:1",
			"position": Vector2(560.0, 560.0),
			"building_kind": &"base",
			"color": Color("#78f0a1"),
			"health_ratio": 1.0,
			"hover": "基地 Lv.1｜己方｜生命 1800/1800",
		}],
		"territories": [{
			"key": "territory:1",
			"world_rect": Rect2(64.0, 64.0, 640.0, 640.0),
			"color": Color("#78f0a1"),
			"is_local": true,
			"hover": "领地 1｜己方",
		}],
	}

func _left_mouse_event(event_position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = event_position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	return event

func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("TACTICAL_MAP_ALERT_TEST FAILED: %s" % message)
	get_tree().quit(1)

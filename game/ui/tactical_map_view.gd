class_name TacticalMapView
extends Control

signal world_selected(world_position: Vector2)
signal hover_changed(detail_text: String)
signal summary_changed(summary_text: String)

const MINIMUM_ZOOM: float = 1.0
const MAXIMUM_ZOOM: float = 8.0
const ZOOM_STEP: float = 1.35
const MOUSE_DRAG_THRESHOLD: float = 6.0
const DATA_REFRESH_INTERVAL: float = 0.4
const MAP_BACKGROUND: Color = Color("#07100fe8")
const MAP_BORDER: Color = Color("#d4b766")
const GRID_COLOR: Color = Color("#8ba89538")
const MINOR_GRID_COLOR: Color = Color("#8ba8951c")
const EXPLORED_FULL_VISION_COLOR: Color = Color("#55765f")
const CAMERA_COLOR: Color = Color("#f6df8d")
const COMBAT_COLOR: Color = Color("#ff493d")
const SELECTION_COLOR: Color = Color("#fff5bd")

var _fog_of_war: FogOfWar
var _map_data_provider: Callable
var _camera: Camera2D
var _world_size: Vector2 = Vector2.ONE
var _tile_size: int = 32
var _view_center: Vector2 = Vector2.ZERO
var _map_zoom: float = MINIMUM_ZOOM
var _pulse_elapsed: float = 0.0
var _data_refresh_elapsed: float = 0.0
var _left_press_active: bool = false
var _dragging_map: bool = false
var _left_press_position: Vector2 = Vector2.ZERO
var _drag_start_view_center: Vector2 = Vector2.ZERO
var _map_data: Dictionary = {
	"units": [],
	"resources": [],
	"buildings": [],
	"territories": [],
}
var _hovered_entry: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	resized.connect(queue_redraw)
	mouse_exited.connect(_clear_hover)
	set_process(false)

func configure(
	fog_of_war: FogOfWar,
	world_size: Vector2,
	tile_size: int,
	map_data_provider: Callable,
	camera: Camera2D
) -> void:
	_fog_of_war = fog_of_war
	_world_size = Vector2(maxf(1.0, world_size.x), maxf(1.0, world_size.y))
	_tile_size = maxi(1, tile_size)
	_map_data_provider = map_data_provider
	_camera = camera
	reset_view()
	_refresh_map_data()

func reset_view() -> void:
	_cancel_pointer_interaction()
	_map_zoom = MINIMUM_ZOOM
	_view_center = _world_size * 0.5
	queue_redraw()

func center_on(world_position: Vector2) -> void:
	_view_center = _clamped_view_center(world_position)
	queue_redraw()

func set_map_active(active: bool) -> void:
	set_process(active)
	if not active:
		_cancel_pointer_interaction()
	if active:
		_pulse_elapsed = 0.0
		_data_refresh_elapsed = DATA_REFRESH_INTERVAL
		_refresh_map_data()
		queue_redraw()

func get_map_zoom() -> float:
	return _map_zoom

func get_view_center() -> Vector2:
	return _view_center

func get_cached_entry_counts() -> Dictionary:
	return {
		"units": (_map_data.get("units", []) as Array).size(),
		"resources": (_map_data.get("resources", []) as Array).size(),
		"buildings": (_map_data.get("buildings", []) as Array).size(),
		"territories": (_map_data.get("territories", []) as Array).size(),
	}

func _process(delta: float) -> void:
	_pulse_elapsed += delta
	_data_refresh_elapsed += delta
	if _data_refresh_elapsed >= DATA_REFRESH_INTERVAL:
		_data_refresh_elapsed = 0.0
		_refresh_map_data()
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event as InputEventMouseMotion
		if _left_press_active:
			var pointer_delta: Vector2 = motion_event.position - _left_press_position
			if not _dragging_map and pointer_delta.length() >= MOUSE_DRAG_THRESHOLD:
				_dragging_map = true
				mouse_default_cursor_shape = Control.CURSOR_DRAG
				_clear_hover()
			if _dragging_map:
				_pan_from_drag(pointer_delta)
				accept_event()
				return
		_update_hover(motion_event.position)
		return
	if event is not InputEventMouseButton:
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		_handle_left_mouse_button(mouse_event)
		return
	if not mouse_event.pressed or not _map_bounds().has_point(mouse_event.position):
		return
	if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_zoom_at_pointer(mouse_event.position, ZOOM_STEP)
	elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_zoom_at_pointer(mouse_event.position, 1.0 / ZOOM_STEP)
	else:
		return
	accept_event()

func _handle_left_mouse_button(mouse_event: InputEventMouseButton) -> void:
	if mouse_event.pressed:
		if not _map_bounds().has_point(mouse_event.position):
			return
		_left_press_active = true
		_dragging_map = false
		_left_press_position = mouse_event.position
		_drag_start_view_center = _view_center
		accept_event()
		return
	if not _left_press_active:
		return
	var should_select_world: bool = not _dragging_map and _map_bounds().has_point(mouse_event.position)
	_left_press_active = false
	_dragging_map = false
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	if should_select_world:
		world_selected.emit(_map_to_world(mouse_event.position))
	else:
		_update_hover(mouse_event.position)
	accept_event()

func _pan_from_drag(pointer_delta: Vector2) -> void:
	var bounds: Rect2 = _map_bounds()
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	var world_delta: Vector2 = pointer_delta / bounds.size * (_world_size / _map_zoom)
	_view_center = _clamped_view_center(_drag_start_view_center - world_delta)
	queue_redraw()

func _cancel_pointer_interaction() -> void:
	_left_press_active = false
	_dragging_map = false
	mouse_default_cursor_shape = Control.CURSOR_ARROW

func _draw() -> void:
	var bounds: Rect2 = _map_bounds()
	var visible_world: Rect2 = _visible_world_rect()
	draw_rect(bounds, MAP_BACKGROUND, true)
	_draw_exploration(bounds, visible_world)
	_draw_grid(bounds)
	_draw_territories(bounds, visible_world)
	_draw_resources(bounds, visible_world)
	_draw_buildings(bounds, visible_world)
	_draw_units(bounds, visible_world)
	_draw_camera_view(bounds, visible_world)
	_draw_hover_highlight(bounds, visible_world)
	draw_rect(bounds, MAP_BORDER, false, 2.0)

func _draw_exploration(bounds: Rect2, visible_world: Rect2) -> void:
	if not is_instance_valid(_fog_of_war):
		return
	if _fog_of_war.is_full_vision_enabled():
		draw_rect(bounds, EXPLORED_FULL_VISION_COLOR, true)
		return
	var exploration_texture: Texture2D = _fog_of_war.get_exploration_texture()
	if exploration_texture == null:
		return
	var source_rect: Rect2 = Rect2(visible_world.position / float(_tile_size), visible_world.size / float(_tile_size))
	draw_texture_rect_region(exploration_texture, bounds, source_rect)

func _draw_grid(bounds: Rect2) -> void:
	var division_count: int = 8 if _map_zoom < 2.0 else 16
	var major_interval: int = maxi(1, division_count >> 2)
	for division: int in range(1, division_count):
		var ratio: float = float(division) / float(division_count)
		var line_color: Color = GRID_COLOR if division % major_interval == 0 else MINOR_GRID_COLOR
		var vertical_x: float = lerpf(bounds.position.x, bounds.end.x, ratio)
		var horizontal_y: float = lerpf(bounds.position.y, bounds.end.y, ratio)
		draw_line(Vector2(vertical_x, bounds.position.y), Vector2(vertical_x, bounds.end.y), line_color, 1.0)
		draw_line(Vector2(bounds.position.x, horizontal_y), Vector2(bounds.end.x, horizontal_y), line_color, 1.0)

func _draw_territories(bounds: Rect2, visible_world: Rect2) -> void:
	for value: Variant in (_map_data.get("territories", []) as Array):
		var territory: Dictionary = value as Dictionary
		var world_rect: Rect2 = territory.get("world_rect", Rect2()) as Rect2
		var clipped_rect: Rect2 = world_rect.intersection(visible_world)
		if not clipped_rect.has_area():
			continue
		var draw_rect_value: Rect2 = _world_rect_to_map(clipped_rect, bounds, visible_world)
		var color: Color = territory.get("color", Color.WHITE) as Color
		var fill_color: Color = color
		fill_color.a = 0.08 if bool(territory.get("is_local", false)) else 0.035
		draw_rect(draw_rect_value, fill_color, true)
		color.a = 0.88 if bool(territory.get("is_local", false)) else 0.55
		draw_rect(draw_rect_value, color, false, 2.0 if bool(territory.get("is_local", false)) else 1.2)

func _draw_resources(bounds: Rect2, visible_world: Rect2) -> void:
	var grouped: Dictionary[String, Dictionary] = {}
	var bucket_size: float = 5.0 if _map_zoom < 2.0 else (3.5 if _map_zoom < 4.0 else 1.0)
	for value: Variant in (_map_data.get("resources", []) as Array):
		var resource: Dictionary = value as Dictionary
		var world_position: Vector2 = resource.get("position", Vector2.ZERO) as Vector2
		if not visible_world.has_point(world_position):
			continue
		var map_position: Vector2 = _world_to_map(world_position, bounds, visible_world)
		var resource_type: StringName = resource.get("resource_type", &"tree") as StringName
		var bucket: Vector2i = Vector2i(floori(map_position.x / bucket_size), floori(map_position.y / bucket_size))
		var bucket_key: String = "%s:%d:%d" % [str(resource_type), bucket.x, bucket.y]
		if grouped.has(bucket_key):
			var existing: Dictionary = grouped[bucket_key]
			existing["count"] = int(existing.get("count", 1)) + 1
			grouped[bucket_key] = existing
		else:
			grouped[bucket_key] = {
				"position": map_position,
				"resource_type": resource_type,
				"count": 1,
			}
	for group: Dictionary in grouped.values():
		var marker_size: float = 2.5 + minf(2.25, log(float(int(group.get("count", 1))) + 1.0) * 0.85)
		_draw_resource_marker(
			group.get("position", Vector2.ZERO) as Vector2,
			group.get("resource_type", &"tree") as StringName,
			marker_size
		)

func _draw_resource_marker(marker_position: Vector2, resource_type: StringName, marker_size: float) -> void:
	match resource_type:
		&"tree":
			var points: PackedVector2Array = PackedVector2Array([
				marker_position + Vector2(0.0, -marker_size),
				marker_position + Vector2(marker_size, marker_size),
				marker_position + Vector2(-marker_size, marker_size),
			])
			draw_colored_polygon(points, Color("#74c66a"))
			draw_line(marker_position + Vector2(0.0, marker_size * 0.35), marker_position + Vector2(0.0, marker_size + 1.5), Color("#704a2c"), 1.0)
		&"stone":
			_draw_diamond(marker_position, marker_size, Color("#b4bec7"), Color("#263038"))
		&"iron":
			draw_rect(Rect2(marker_position - Vector2.ONE * marker_size, Vector2.ONE * marker_size * 2.0), Color("#63b8d8"), true)
			draw_line(marker_position + Vector2(-marker_size, 0.0), marker_position + Vector2(marker_size, 0.0), Color("#d8f5ff"), 1.0)
			draw_line(marker_position + Vector2(0.0, -marker_size), marker_position + Vector2(0.0, marker_size), Color("#d8f5ff"), 1.0)
		&"chest":
			var chest_rect: Rect2 = Rect2(marker_position - Vector2(marker_size, marker_size * 0.75), Vector2(marker_size * 2.0, marker_size * 1.5))
			draw_rect(chest_rect, Color("#e9b94e"), true)
			draw_rect(chest_rect, Color("#5c3516"), false, 1.0)
			draw_line(Vector2(chest_rect.position.x, marker_position.y), Vector2(chest_rect.end.x, marker_position.y), Color("#fff0a3"), 1.0)
		_:
			draw_circle(marker_position, marker_size, Color("#d7d7d7"))

func _draw_buildings(bounds: Rect2, visible_world: Rect2) -> void:
	for value: Variant in (_map_data.get("buildings", []) as Array):
		var building: Dictionary = value as Dictionary
		var world_position: Vector2 = building.get("position", Vector2.ZERO) as Vector2
		if not visible_world.has_point(world_position):
			continue
		var map_position: Vector2 = _world_to_map(world_position, bounds, visible_world)
		var color: Color = building.get("color", Color.WHITE) as Color
		var kind: StringName = building.get("building_kind", &"building") as StringName
		var size_value: float = 6.5 if kind == &"base" else 5.0
		if kind == &"base":
			_draw_diamond(map_position, size_value, color, Color("#fff0b0"))
			draw_circle(map_position, 1.8, Color("#fff4c8"))
		else:
			var building_rect: Rect2 = Rect2(map_position - Vector2.ONE * size_value, Vector2.ONE * size_value * 2.0)
			draw_rect(building_rect, color.darkened(0.18), true)
			draw_rect(building_rect, color.lightened(0.2), false, 1.5)
			if not bool(building.get("construction_complete", true)):
				draw_line(building_rect.position, building_rect.end, Color("#ffbd57"), 1.5)
				draw_line(Vector2(building_rect.end.x, building_rect.position.y), Vector2(building_rect.position.x, building_rect.end.y), Color("#ffbd57"), 1.5)
		if _map_zoom >= 2.0:
			_draw_health_bar(map_position + Vector2(0.0, size_value + 3.0), size_value * 2.4, float(building.get("health_ratio", 1.0)))

func _draw_units(bounds: Rect2, visible_world: Rect2) -> void:
	for value: Variant in (_map_data.get("units", []) as Array):
		var unit_data: Dictionary = value as Dictionary
		var world_position: Vector2 = unit_data.get("position", Vector2.ZERO) as Vector2
		if not visible_world.has_point(world_position):
			continue
		var map_position: Vector2 = _world_to_map(world_position, bounds, visible_world)
		var radius: float = float(unit_data.get("radius", 4.0)) + minf(1.5, (_map_zoom - 1.0) * 0.25)
		var color: Color = unit_data.get("color", Color.WHITE) as Color
		var category: StringName = unit_data.get("category", &"combat") as StringName
		_draw_unit_marker(map_position, radius, color, category)
		if bool(unit_data.get("selected", false)):
			draw_arc(map_position, radius + 3.0, 0.0, TAU, 24, SELECTION_COLOR, 1.8, true)
		if bool(unit_data.get("in_combat", false)):
			_draw_combat_ripple(map_position, radius, int(unit_data.get("id", 0)))
		if _map_zoom >= 2.4:
			_draw_health_bar(map_position + Vector2(0.0, radius + 3.0), radius * 2.8, float(unit_data.get("health_ratio", 1.0)))

func _draw_unit_marker(marker_position: Vector2, radius: float, color: Color, category: StringName) -> void:
	match category:
		&"hero", &"boss":
			_draw_diamond(marker_position, radius, color, Color("#fff1aa"))
			draw_circle(marker_position, 1.6, Color.WHITE)
		&"worker":
			var worker_rect: Rect2 = Rect2(marker_position - Vector2.ONE * radius * 0.72, Vector2.ONE * radius * 1.44)
			draw_rect(worker_rect, Color("#07100f"), true)
			draw_rect(worker_rect.grow(-1.2), color, true)
		&"monster":
			draw_circle(marker_position, radius + 1.4, Color("#200927"))
			draw_circle(marker_position, radius, color)
			draw_line(marker_position + Vector2(-radius * 0.55, -radius * 0.55), marker_position + Vector2(radius * 0.55, radius * 0.55), Color("#f5c9ff"), 1.0)
			draw_line(marker_position + Vector2(radius * 0.55, -radius * 0.55), marker_position + Vector2(-radius * 0.55, radius * 0.55), Color("#f5c9ff"), 1.0)
		_:
			draw_circle(marker_position, radius + 1.5, Color("#07100f"))
			draw_circle(marker_position, radius, color)

func _draw_camera_view(bounds: Rect2, visible_world: Rect2) -> void:
	if not is_instance_valid(_camera):
		return
	var camera_world_size: Vector2 = _camera.get_viewport_rect().size / _camera.zoom
	var camera_world_rect: Rect2 = Rect2(_camera.global_position - camera_world_size * 0.5, camera_world_size)
	var top_left: Vector2 = _world_to_map(camera_world_rect.position, bounds, visible_world)
	var bottom_right: Vector2 = _world_to_map(camera_world_rect.end, bounds, visible_world)
	draw_rect(Rect2(top_left, bottom_right - top_left), CAMERA_COLOR, false, 1.5)

func _draw_combat_ripple(center: Vector2, unit_radius: float, unit_id: int) -> void:
	for ring_index: int in 2:
		var phase: float = fmod(_pulse_elapsed * 1.35 + float(ring_index) * 0.5 + float(unit_id % 7) * 0.07, 1.0)
		var ring_radius: float = unit_radius + 3.0 + phase * 15.0
		var ring_color: Color = COMBAT_COLOR
		ring_color.a = (1.0 - phase) * 0.9
		draw_arc(center, ring_radius, 0.0, TAU, 32, ring_color, 2.0, true)

func _draw_health_bar(bar_position: Vector2, width: float, health_ratio: float) -> void:
	var clamped_ratio: float = clampf(health_ratio, 0.0, 1.0)
	var background: Rect2 = Rect2(bar_position - Vector2(width * 0.5, 0.0), Vector2(width, 2.5))
	draw_rect(background, Color("#250b0b"), true)
	var fill_color: Color = Color("#6fe083") if clamped_ratio > 0.5 else (Color("#efc452") if clamped_ratio > 0.25 else Color("#f05b52"))
	draw_rect(Rect2(background.position, Vector2(background.size.x * clamped_ratio, background.size.y)), fill_color, true)

func _draw_diamond(marker_position: Vector2, radius: float, fill_color: Color, outline_color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array([
		marker_position + Vector2(0.0, -radius),
		marker_position + Vector2(radius, 0.0),
		marker_position + Vector2(0.0, radius),
		marker_position + Vector2(-radius, 0.0),
	])
	draw_colored_polygon(points, fill_color)
	var outline: PackedVector2Array = points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, outline_color, 1.2, true)

func _draw_hover_highlight(bounds: Rect2, visible_world: Rect2) -> void:
	if _hovered_entry.is_empty():
		return
	if _hovered_entry.has("world_rect"):
		var world_rect: Rect2 = _hovered_entry.get("world_rect", Rect2()) as Rect2
		var clipped_rect: Rect2 = world_rect.intersection(visible_world)
		if clipped_rect.has_area():
			draw_rect(_world_rect_to_map(clipped_rect, bounds, visible_world), Color("#fff2a3"), false, 2.0)
		return
	var world_position: Vector2 = _hovered_entry.get("position", Vector2.INF) as Vector2
	if visible_world.has_point(world_position):
		draw_arc(_world_to_map(world_position, bounds, visible_world), 10.0, 0.0, TAU, 24, Color("#fff2a3"), 1.5, true)

func _refresh_map_data() -> void:
	if not _map_data_provider.is_valid():
		return
	var provided: Variant = _map_data_provider.call()
	if provided is Dictionary:
		var provided_data: Dictionary = provided as Dictionary
		_map_data = {
			"units": provided_data.get("units", []) as Array,
			"resources": provided_data.get("resources", []) as Array,
			"buildings": provided_data.get("buildings", []) as Array,
			"territories": provided_data.get("territories", []) as Array,
		}
	elif provided is Array:
		_map_data = {"units": provided as Array, "resources": [], "buildings": [], "territories": []}
	_emit_summary()
	_refresh_hovered_entry()

func _emit_summary() -> void:
	var combat_count: int = 0
	for value: Variant in (_map_data.get("units", []) as Array):
		var unit_data: Dictionary = value as Dictionary
		var category: StringName = unit_data.get("category", &"combat") as StringName
		if category in [&"combat", &"hero", &"monster", &"boss"]:
			combat_count += 1
	summary_changed.emit(
		"已知资源 %d　｜　战斗单位/目标 %d　｜　基地与建筑 %d" % [
			(_map_data.get("resources", []) as Array).size(),
			combat_count,
			(_map_data.get("buildings", []) as Array).size(),
		]
	)

func _update_hover(pointer_position: Vector2) -> void:
	if not _map_bounds().has_point(pointer_position):
		_clear_hover()
		return
	var bounds: Rect2 = _map_bounds()
	var visible_world: Rect2 = _visible_world_rect()
	var best_entry: Dictionary = {}
	var best_distance: float = 11.0 * 11.0
	for collection_name: String in ["units", "buildings", "resources"]:
		for value: Variant in (_map_data.get(collection_name, []) as Array):
			var entry: Dictionary = value as Dictionary
			var world_position: Vector2 = entry.get("position", Vector2.INF) as Vector2
			if not visible_world.has_point(world_position):
				continue
			var distance: float = pointer_position.distance_squared_to(_world_to_map(world_position, bounds, visible_world))
			if distance < best_distance:
				best_distance = distance
				best_entry = entry
	if best_entry.is_empty():
		var world_position_under_pointer: Vector2 = _map_to_world(pointer_position)
		for value: Variant in (_map_data.get("territories", []) as Array):
			var territory: Dictionary = value as Dictionary
			if (territory.get("world_rect", Rect2()) as Rect2).has_point(world_position_under_pointer):
				best_entry = territory
				break
	_set_hovered_entry(best_entry)

func _set_hovered_entry(entry: Dictionary) -> void:
	var next_key: String = str(entry.get("key", ""))
	var current_key: String = str(_hovered_entry.get("key", ""))
	if next_key == current_key:
		return
	_hovered_entry = entry
	hover_changed.emit(str(entry.get("hover", "")) if not entry.is_empty() else "")
	queue_redraw()

func _clear_hover() -> void:
	_set_hovered_entry({})

func _refresh_hovered_entry() -> void:
	var hovered_key: String = str(_hovered_entry.get("key", ""))
	if hovered_key.is_empty():
		return
	for collection_name: String in ["units", "buildings", "resources", "territories"]:
		for value: Variant in (_map_data.get(collection_name, []) as Array):
			var entry: Dictionary = value as Dictionary
			if str(entry.get("key", "")) == hovered_key:
				_hovered_entry = entry
				hover_changed.emit(str(entry.get("hover", "")))
				return
	_clear_hover()

func _zoom_at_pointer(pointer_position: Vector2, factor: float) -> void:
	var world_before_zoom: Vector2 = _map_to_world(pointer_position)
	var target_zoom: float = clampf(_map_zoom * factor, MINIMUM_ZOOM, MAXIMUM_ZOOM)
	if is_equal_approx(target_zoom, _map_zoom):
		return
	_map_zoom = target_zoom
	var bounds: Rect2 = _map_bounds()
	var pointer_ratio: Vector2 = (pointer_position - bounds.position) / bounds.size
	var new_visible_size: Vector2 = _world_size / _map_zoom
	_view_center = world_before_zoom + (Vector2.ONE * 0.5 - pointer_ratio) * new_visible_size
	_view_center = _clamped_view_center(_view_center)
	_update_hover(pointer_position)
	queue_redraw()

func _map_to_world(map_position: Vector2) -> Vector2:
	var bounds: Rect2 = _map_bounds()
	var ratio: Vector2 = (map_position - bounds.position) / bounds.size
	var visible_world: Rect2 = _visible_world_rect()
	return visible_world.position + ratio * visible_world.size

func _world_to_map(world_position: Vector2, bounds: Rect2, visible_world: Rect2) -> Vector2:
	return bounds.position + (world_position - visible_world.position) / visible_world.size * bounds.size

func _world_rect_to_map(world_rect: Rect2, bounds: Rect2, visible_world: Rect2) -> Rect2:
	var top_left: Vector2 = _world_to_map(world_rect.position, bounds, visible_world)
	var bottom_right: Vector2 = _world_to_map(world_rect.end, bounds, visible_world)
	return Rect2(top_left, bottom_right - top_left)

func _visible_world_rect() -> Rect2:
	var visible_size: Vector2 = _world_size / _map_zoom
	var clamped_center: Vector2 = _clamped_view_center(_view_center)
	return Rect2(clamped_center - visible_size * 0.5, visible_size)

func _clamped_view_center(candidate: Vector2) -> Vector2:
	var half_size: Vector2 = _world_size / (_map_zoom * 2.0)
	return Vector2(
		clampf(candidate.x, half_size.x, _world_size.x - half_size.x),
		clampf(candidate.y, half_size.y, _world_size.y - half_size.y)
	)

func _map_bounds() -> Rect2:
	var side_length: float = maxf(1.0, minf(size.x, size.y) - 4.0)
	var bounds_size: Vector2 = Vector2.ONE * side_length
	return Rect2((size - bounds_size) * 0.5, bounds_size)

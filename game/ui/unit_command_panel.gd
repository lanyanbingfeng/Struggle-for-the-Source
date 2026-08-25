class_name UnitCommandPanel
extends CanvasLayer

const MachineProgressionData: Script = preload("res://game/data/machine_progression.gd")

signal work_toggled(unit_id: int, enabled: bool)
signal upgrade_requested(unit_id: int)
signal build_preview_requested(unit_id: int)
signal build_confirmed
signal build_cancelled
signal structure_preview_requested(unit_id: int, building_id: StringName)
signal structure_confirmed
signal structure_cancelled

var _panel: PanelContainer
var _title: Label
var _details: Label
var _primary_button: Button
var _upgrade_button: Button
var _build_button: Button
var _building_list: GridContainer
var _confirmation: PanelContainer
var _confirmation_text: Label
var _toast: Label
var _selected_unit_id: int = 0
var _selection_mode: StringName = &""
var _confirmation_mode: StringName = &""
var _toast_tween: Tween

func _ready() -> void:
	layer = 28
	_build_ui()
	hide_selection()

func show_machine(unit_id: int, display_name: String, level: int, work_enabled: bool, permission_text: String) -> void:
	_selected_unit_id = unit_id
	_selection_mode = &"machine"
	_panel.show()
	_confirmation.hide()
	_title.text = "%s  Lv.%d" % [display_name, level]
	_details.text = permission_text
	_primary_button.text = "休息" if work_enabled else "工作"
	_primary_button.show()
	_upgrade_button.text = "升级：%s" % MachineProgressionData.cost_summary(level)
	_upgrade_button.disabled = level >= MachineProgressionData.MAX_LEVEL
	_upgrade_button.show()
	_build_button.hide()
	_building_list.hide()

func show_explorer(unit_id: int) -> void:
	_selected_unit_id = unit_id
	_selection_mode = &"explorer"
	_panel.show()
	_confirmation.hide()
	_title.text = "探索者"
	_details.text = "可前往地图任意位置并建立新的20×20领地"
	_primary_button.hide()
	_upgrade_button.hide()
	_build_button.text = "建造基地"
	_build_button.show()
	_building_list.hide()

func show_builder(unit_id: int, definitions: Array[BuildingDefinition]) -> void:
	_selected_unit_id = unit_id
	_selection_mode = &"builder"
	_panel.show()
	_confirmation.hide()
	_title.text = "建筑工人"
	_details.text = "仅可在己方领地内建设，建筑固定在工人当前位置"
	_primary_button.hide()
	_upgrade_button.hide()
	_build_button.text = "建筑"
	_build_button.show()
	_rebuild_building_list(definitions)
	_building_list.hide()

func hide_selection() -> void:
	_selected_unit_id = 0
	_selection_mode = &""
	if is_instance_valid(_panel):
		_panel.hide()
	if is_instance_valid(_confirmation):
		_confirmation.hide()

func show_build_confirmation(summary: String) -> void:
	_confirmation_mode = &"base"
	_confirmation_text.text = "新基地覆盖资源\n%s\n确认建立这块20×20领地？" % summary
	_confirmation.show()

func show_structure_confirmation(definition: BuildingDefinition, condition_text: String) -> void:
	_confirmation_mode = &"structure"
	_confirmation_text.text = "%s（2×2）\n%s\n%s\n确认在当前位置建造？" % [
		definition.display_name, definition.cost_summary(), condition_text,
	]
	_confirmation.show()

func hide_build_confirmation() -> void:
	_confirmation_mode = &""
	_confirmation.hide()

func show_notice(message: String) -> void:
	_toast.text = message
	_toast.modulate.a = 1.0
	_toast.show()
	if is_instance_valid(_toast_tween):
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.35)
	_toast_tween.tween_callback(_toast.hide)

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_panel.offset_left = -270.0
	_panel.offset_top = -260.0
	_panel.offset_right = -12.0
	_panel.offset_bottom = -12.0
	_panel.add_theme_stylebox_override(&"panel", _panel_style(Color("#183024f2"), Color("#c99042")))
	add_child(_panel)
	var margin := MarginContainer.new()
	for side: StringName in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 8)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 5)
	margin.add_child(column)
	_title = Label.new()
	_title.add_theme_font_size_override(&"font_size", 15)
	column.add_child(_title)
	_details = Label.new()
	_details.add_theme_font_size_override(&"font_size", 11)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.custom_minimum_size = Vector2(232.0, 34.0)
	column.add_child(_details)
	_primary_button = Button.new()
	_primary_button.pressed.connect(func() -> void: work_toggled.emit(_selected_unit_id, _primary_button.text == "工作"))
	column.add_child(_primary_button)
	_upgrade_button = Button.new()
	_upgrade_button.pressed.connect(func() -> void: upgrade_requested.emit(_selected_unit_id))
	column.add_child(_upgrade_button)
	_build_button = Button.new()
	_build_button.pressed.connect(_on_build_button_pressed)
	column.add_child(_build_button)
	_building_list = GridContainer.new()
	_building_list.columns = 2
	_building_list.add_theme_constant_override(&"h_separation", 4)
	_building_list.add_theme_constant_override(&"v_separation", 4)
	column.add_child(_building_list)

	_confirmation = PanelContainer.new()
	_confirmation.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_confirmation.offset_left = -350.0
	_confirmation.offset_top = -88.0
	_confirmation.offset_right = -16.0
	_confirmation.offset_bottom = 88.0
	_confirmation.add_theme_stylebox_override(&"panel", _panel_style(Color("#13251ff8"), Color("#e0aa55")))
	add_child(_confirmation)
	var confirm_margin := MarginContainer.new()
	for side: StringName in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		confirm_margin.add_theme_constant_override(side, 10)
	_confirmation.add_child(confirm_margin)
	var confirm_column := VBoxContainer.new()
	confirm_column.alignment = BoxContainer.ALIGNMENT_CENTER
	confirm_column.add_theme_constant_override(&"separation", 8)
	confirm_margin.add_child(confirm_column)
	_confirmation_text = Label.new()
	_confirmation_text.add_theme_font_size_override(&"font_size", 12)
	_confirmation_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirmation_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_column.add_child(_confirmation_text)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	confirm_column.add_child(buttons)
	var confirm_button := Button.new()
	confirm_button.text = "确认建造"
	confirm_button.pressed.connect(_on_confirmation_accepted)
	buttons.add_child(confirm_button)
	var cancel_button := Button.new()
	cancel_button.text = "取消"
	cancel_button.pressed.connect(_on_confirmation_cancelled)
	buttons.add_child(cancel_button)
	_confirmation.hide()

	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -190.0
	_toast.offset_top = 56.0
	_toast.offset_right = 190.0
	_toast.offset_bottom = 84.0
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override(&"font_size", 12)
	_toast.add_theme_color_override(&"font_color", Color("#fff1c9"))
	_toast.add_theme_color_override(&"font_outline_color", Color("#321912"))
	_toast.add_theme_constant_override(&"outline_size", 4)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast)
	_toast.hide()

func _on_build_button_pressed() -> void:
	if _selection_mode == &"explorer":
		build_preview_requested.emit(_selected_unit_id)
	elif _selection_mode == &"builder":
		_building_list.visible = not _building_list.visible

func _rebuild_building_list(definitions: Array[BuildingDefinition]) -> void:
	for child: Node in _building_list.get_children():
		child.queue_free()
	for definition: BuildingDefinition in definitions:
		if definition == null:
			continue
		var button := Button.new()
		button.text = definition.display_name
		button.custom_minimum_size = Vector2(112.0, 44.0)
		button.icon = definition.card_texture
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		button.add_theme_font_size_override(&"font_size", 10)
		button.add_theme_constant_override(&"icon_max_width", 34)
		button.add_theme_constant_override(&"icon_separation", 4)
		button.add_theme_stylebox_override(&"normal", _structure_button_style(definition.tint, false))
		button.add_theme_stylebox_override(&"hover", _structure_button_style(definition.tint, true))
		button.add_theme_stylebox_override(&"pressed", _structure_button_style(definition.tint.darkened(0.14), true))
		button.add_theme_stylebox_override(&"focus", _structure_button_style(definition.tint.lightened(0.14), true))
		button.tooltip_text = "%s\n%s" % [definition.description, definition.cost_summary()]
		button.pressed.connect(_on_structure_button_pressed.bind(definition.building_id))
		_building_list.add_child(button)

func _on_structure_button_pressed(building_id: StringName) -> void:
	_building_list.hide()
	structure_preview_requested.emit(_selected_unit_id, building_id)

func _on_confirmation_accepted() -> void:
	if _confirmation_mode == &"base":
		build_confirmed.emit()
	elif _confirmation_mode == &"structure":
		structure_confirmed.emit()

func _on_confirmation_cancelled() -> void:
	if _confirmation_mode == &"base":
		build_cancelled.emit()
	elif _confirmation_mode == &"structure":
		structure_cancelled.emit()

func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	return style

func _structure_button_style(accent: Color, highlighted: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#243a31ff") if highlighted else Color("#15261fff")
	style.border_color = accent
	style.border_width_left = 3
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.set_corner_radius_all(6)
	style.content_margin_left = 5.0
	style.content_margin_right = 5.0
	style.shadow_color = Color("#00000066")
	style.shadow_size = 2
	return style

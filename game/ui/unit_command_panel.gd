class_name UnitCommandPanel
extends CanvasLayer

const MachineProgressionData: Script = preload("res://game/data/machine_progression.gd")
const HeroProgressionData: Script = preload("res://game/data/hero_progression.gd")
const SkillCooldownOverlayScript: Script = preload("res://game/ui/skill_cooldown_overlay.gd")

signal work_toggled(unit_id: int, enabled: bool)
signal upgrade_requested(unit_id: int)
signal build_preview_requested(unit_id: int)
signal build_confirmed
signal build_cancelled
signal structure_preview_requested(unit_id: int, building_id: StringName)
signal structure_confirmed
signal structure_cancelled
signal hero_level_up_requested(unit_id: int)
signal hero_skill_up_requested(unit_id: int, skill_id: StringName)
signal hero_cast_requested(unit_id: int, skill_id: StringName)
signal building_upgrade_requested(building_id: int)
signal building_demolish_requested(building_id: int)

var _panel: PanelContainer
var _title: Label
var _details: Label
var _primary_button: Button
var _upgrade_button: Button
var _build_button: Button
var _building_list: GridContainer
var _hero_panel: PanelContainer
var _hero_title: Label
var _hero_hint: Label
var _hero_level_button: Button
var _hero_skill_bar: HBoxContainer
var _hero_tooltip_panel: PanelContainer
var _hero_tooltip_title: Label
var _hero_tooltip_meta: Label
var _hero_tooltip_description: Label
var _confirmation: VBoxContainer
var _confirmation_text: Label
var _toast: Label
var _selected_unit_id: int = 0
var _selected_building_id: int = 0
var _selection_mode: StringName = &""
var _confirmation_mode: StringName = &""
var _toast_tween: Tween
var _active_hero_skill_id: StringName = &""
var _hero_skill_buttons: Dictionary[StringName, Button] = {}
var _hero_skill_cooldown_overlays: Dictionary[StringName, Control] = {}
var _hero_skill_cooldown_durations: Dictionary[StringName, float] = {}
var _hero_skill_id_by_keycode: Dictionary[int, StringName] = {}
var _hero_skill_name_by_id: Dictionary[StringName, String] = {}

func _ready() -> void:
	layer = 28
	_build_ui()
	hide_selection()

func show_machine(unit_id: int, display_name: String, level: int, work_enabled: bool, permission_text: String) -> void:
	_selected_unit_id = unit_id
	_selection_mode = &"machine"
	_show_standard_panel()
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
	_show_standard_panel()
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
	_show_standard_panel()
	_confirmation.hide()
	_title.text = "建筑工人"
	_details.text = "选择建筑后可用WASD微调，确认后工人会走过去施工"
	_primary_button.hide()
	_upgrade_button.hide()
	_build_button.text = "建筑"
	_build_button.show()
	_rebuild_building_list(definitions)
	_building_list.hide()

func show_hero(unit_id: int, definition: UnitDefinition, hero_level: int, skill_levels: Dictionary) -> void:
	_selected_unit_id = unit_id
	_selected_building_id = 0
	_selection_mode = &"hero"
	_panel.hide()
	_hero_tooltip_panel.hide()
	_hero_panel.show()
	_confirmation.hide()
	_hero_title.text = "%s  Lv.%d" % [definition.display_name, hero_level]
	_hero_hint.text = "点击技能或按 Q / W / E，再左键选择目标"
	_hero_level_button.text = "升级英雄  %d经验" % HeroProgressionData.hero_level_cost(hero_level)
	_hero_level_button.disabled = hero_level >= HeroProgressionData.MAX_HERO_LEVEL
	_rebuild_hero_actions(definition, skill_levels)

func show_building(building_id: int, definition: BuildingDefinition, level: int, pending_amount: int = 0, construction_progress: float = 1.0, construction_remaining: float = 0.0) -> void:
	_selected_unit_id = 0
	_selected_building_id = building_id
	_selection_mode = &"building"
	_show_standard_panel()
	_confirmation.hide()
	_title.text = "%s  Lv.%d" % [definition.display_name, level]
	if construction_progress < 1.0:
		_details.text = "%s\n施工进度：%d%%，剩余 %.0f 秒\n生命 %d　防御 %d" % [definition.description, roundi(construction_progress * 100.0), construction_remaining, definition.max_health, definition.defense]
	else:
		var production: String = "不生产资源" if definition.production_resource_type.is_empty() else "生产：%s　每次 %d　间隔 %.0f 秒\n待领取：%d" % [str(definition.production_resource_type), definition.production_amount * level, definition.production_interval_seconds, pending_amount]
		_details.text = "%s\n生命 %d　防御 %d\n%s" % [definition.description, definition.max_health, definition.defense, production]
	_primary_button.hide()
	_upgrade_button.text = "升级：铁%d" % definition.upgrade_iron_cost(level)
	_upgrade_button.disabled = level >= definition.max_level or definition.interaction_type == &"hero_altar" or construction_progress < 1.0
	_upgrade_button.visible = definition.interaction_type != &"hero_altar"
	_primary_button.text = "拆除（返还初始材料50%%）"
	_primary_button.disabled = construction_progress < 1.0 or definition.interaction_type == &"hero_altar"
	_primary_button.visible = definition.interaction_type != &"hero_altar"
	_build_button.hide()
	_building_list.hide()

func hide_selection() -> void:
	_selected_unit_id = 0
	_selected_building_id = 0
	_selection_mode = &""
	_active_hero_skill_id = &""
	_hero_skill_id_by_keycode.clear()
	if is_instance_valid(_panel):
		_panel.hide()
	if is_instance_valid(_hero_panel):
		_hero_panel.hide()
	if is_instance_valid(_hero_tooltip_panel):
		_hero_tooltip_panel.hide()
	if is_instance_valid(_confirmation):
		_confirmation.hide()

func show_build_confirmation(summary: String) -> void:
	_confirmation_mode = &"base"
	_title.text = "新基地选址"
	_details.text = "WASD 微调位置（每次移动1格）"
	_build_button.hide()
	_confirmation_text.text = "覆盖资源：%s\n确认建立这块20×20领地？" % summary
	_confirmation.show()

func update_build_confirmation(summary: String) -> void:
	if _confirmation_mode != &"base":
		return
	_confirmation_text.text = "覆盖资源：%s\n确认建立这块20×20领地？" % summary

func show_structure_confirmation(definition: BuildingDefinition, condition_text: String, failure: String = "") -> void:
	_confirmation_mode = &"structure"
	_title.text = "%s选址" % definition.display_name
	_details.text = "WASD 微调位置（每次移动1格）"
	_build_button.hide()
	_building_list.hide()
	update_structure_confirmation(definition, condition_text, failure)
	_confirmation.show()

func update_structure_confirmation(definition: BuildingDefinition, condition_text: String, failure: String) -> void:
	if _confirmation_mode != &"structure":
		return
	var status_text: String = "可以建造" if failure.is_empty() else "不可建造：%s" % failure
	var status_color: Color = Color("#72e486") if failure.is_empty() else Color("#ff7777")
	_confirmation_text.add_theme_color_override(&"font_color", status_color)
	_confirmation_text.text = "%s（2×2）\n%s\n%s\n%s\n确认后工人会前往此处施工" % [
		definition.display_name, definition.cost_summary(), condition_text, status_text,
	]

func hide_build_confirmation() -> void:
	_confirmation_mode = &""
	_confirmation.hide()
	if _selection_mode == &"explorer":
		_title.text = "探索者"
		_details.text = "可前往地图任意位置并建立新的20×20领地"
		_build_button.text = "建造基地"
		_build_button.show()
	elif _selection_mode == &"builder":
		_title.text = "建筑工人"
		_details.text = "选择建筑后可用WASD微调，确认后工人会走过去施工"
		_build_button.text = "建筑"
		_build_button.show()

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
	_panel.offset_top = -290.0
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
	_primary_button.pressed.connect(_on_primary_button_pressed)
	column.add_child(_primary_button)
	_upgrade_button = Button.new()
	_upgrade_button.pressed.connect(_on_upgrade_button_pressed)
	column.add_child(_upgrade_button)
	_build_button = Button.new()
	_build_button.pressed.connect(_on_build_button_pressed)
	column.add_child(_build_button)
	_building_list = GridContainer.new()
	_building_list.columns = 2
	_building_list.add_theme_constant_override(&"h_separation", 4)
	_building_list.add_theme_constant_override(&"v_separation", 4)
	column.add_child(_building_list)

	_confirmation = VBoxContainer.new()
	_confirmation.alignment = BoxContainer.ALIGNMENT_CENTER
	_confirmation.add_theme_constant_override(&"separation", 8)
	column.add_child(_confirmation)
	_confirmation_text = Label.new()
	_confirmation_text.add_theme_font_size_override(&"font_size", 12)
	_confirmation_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirmation_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirmation.add_child(_confirmation_text)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_confirmation.add_child(buttons)
	var confirm_button := Button.new()
	confirm_button.text = "确认建造"
	confirm_button.pressed.connect(_on_confirmation_accepted)
	buttons.add_child(confirm_button)
	var cancel_button := Button.new()
	cancel_button.text = "取消"
	cancel_button.pressed.connect(_on_confirmation_cancelled)
	buttons.add_child(cancel_button)
	_confirmation.hide()

	_build_hero_ui()

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

func _build_hero_ui() -> void:
	_hero_panel = PanelContainer.new()
	_hero_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hero_panel.offset_left = -250.0
	_hero_panel.offset_top = -112.0
	_hero_panel.offset_right = 250.0
	_hero_panel.offset_bottom = -8.0
	_hero_panel.add_theme_stylebox_override(&"panel", _panel_style(Color("#0c1c19f2"), Color("#b98a42")))
	add_child(_hero_panel)

	var margin: MarginContainer = MarginContainer.new()
	for side: StringName in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 8)
	_hero_panel.add_child(margin)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	margin.add_child(row)

	var identity: VBoxContainer = VBoxContainer.new()
	identity.custom_minimum_size = Vector2(145.0, 0.0)
	identity.add_theme_constant_override(&"separation", 3)
	row.add_child(identity)
	_hero_title = Label.new()
	_hero_title.add_theme_font_size_override(&"font_size", 16)
	_hero_title.add_theme_color_override(&"font_color", Color("#fff1c9"))
	identity.add_child(_hero_title)
	_hero_hint = Label.new()
	_hero_hint.add_theme_font_size_override(&"font_size", 9)
	_hero_hint.add_theme_color_override(&"font_color", Color("#b9cec4"))
	_hero_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hero_hint.custom_minimum_size = Vector2(145.0, 25.0)
	identity.add_child(_hero_hint)
	_hero_level_button = Button.new()
	_hero_level_button.custom_minimum_size = Vector2(145.0, 23.0)
	_hero_level_button.focus_mode = Control.FOCUS_NONE
	_hero_level_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_hero_level_button.add_theme_font_size_override(&"font_size", 10)
	_hero_level_button.pressed.connect(_on_upgrade_button_pressed)
	identity.add_child(_hero_level_button)

	var separator: VSeparator = VSeparator.new()
	row.add_child(separator)
	_hero_skill_bar = HBoxContainer.new()
	_hero_skill_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hero_skill_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_hero_skill_bar.add_theme_constant_override(&"separation", 6)
	row.add_child(_hero_skill_bar)

	_hero_tooltip_panel = PanelContainer.new()
	_hero_tooltip_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hero_tooltip_panel.offset_left = -190.0
	_hero_tooltip_panel.offset_top = -270.0
	_hero_tooltip_panel.offset_right = 190.0
	_hero_tooltip_panel.offset_bottom = -120.0
	_hero_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_tooltip_panel.add_theme_stylebox_override(&"panel", _panel_style(Color("#091512f7"), Color("#8ab89c")))
	add_child(_hero_tooltip_panel)
	var tooltip_margin: MarginContainer = MarginContainer.new()
	tooltip_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: StringName in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		tooltip_margin.add_theme_constant_override(side, 10)
	_hero_tooltip_panel.add_child(tooltip_margin)
	var tooltip_column: VBoxContainer = VBoxContainer.new()
	tooltip_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_column.add_theme_constant_override(&"separation", 4)
	tooltip_margin.add_child(tooltip_column)
	_hero_tooltip_title = Label.new()
	_hero_tooltip_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_tooltip_title.add_theme_font_size_override(&"font_size", 16)
	_hero_tooltip_title.add_theme_color_override(&"font_color", Color("#ffe5a1"))
	tooltip_column.add_child(_hero_tooltip_title)
	_hero_tooltip_meta = Label.new()
	_hero_tooltip_meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_tooltip_meta.add_theme_font_size_override(&"font_size", 10)
	_hero_tooltip_meta.add_theme_color_override(&"font_color", Color("#8ee7d3"))
	tooltip_column.add_child(_hero_tooltip_meta)
	_hero_tooltip_description = Label.new()
	_hero_tooltip_description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_tooltip_description.add_theme_font_size_override(&"font_size", 11)
	_hero_tooltip_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hero_tooltip_description.custom_minimum_size = Vector2(338.0, 56.0)
	tooltip_column.add_child(_hero_tooltip_description)
	_hero_panel.hide()
	_hero_tooltip_panel.hide()

func _show_standard_panel() -> void:
	_active_hero_skill_id = &""
	_hero_skill_id_by_keycode.clear()
	_hero_panel.hide()
	_hero_tooltip_panel.hide()
	_panel.show()

func _on_build_button_pressed() -> void:
	if _selection_mode == &"explorer":
		build_preview_requested.emit(_selected_unit_id)
	elif _selection_mode == &"builder":
		_building_list.visible = not _building_list.visible

func _on_primary_button_pressed() -> void:
	if _selection_mode == &"machine":
		work_toggled.emit(_selected_unit_id, _primary_button.text == "工作")
	elif _selection_mode == &"hero":
		pass
	elif _selection_mode == &"building":
		building_demolish_requested.emit(_selected_building_id)

func _on_upgrade_button_pressed() -> void:
	if _selection_mode == &"machine":
		upgrade_requested.emit(_selected_unit_id)
	elif _selection_mode == &"hero":
		hero_level_up_requested.emit(_selected_unit_id)
	elif _selection_mode == &"building":
		building_upgrade_requested.emit(_selected_building_id)

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

func _rebuild_hero_actions(definition: UnitDefinition, skill_levels: Dictionary) -> void:
	for child: Node in _hero_skill_bar.get_children():
		child.queue_free()
	_hero_skill_buttons.clear()
	_hero_skill_cooldown_overlays.clear()
	_hero_skill_cooldown_durations.clear()
	_hero_skill_id_by_keycode.clear()
	_hero_skill_name_by_id.clear()
	var passive: Resource = definition.get("passive_skill") as Resource
	var skills: Array = definition.get("active_skills") as Array
	var all_skills: Array[Resource] = []
	if passive != null:
		all_skills.append(passive)
	for skill: Resource in skills:
		if skill != null:
			all_skills.append(skill)
	for skill: Resource in all_skills:
		var skill_id: StringName = StringName(str(skill.get("skill_id")))
		var level: int = int(skill_levels.get(skill_id, 1))
		var is_passive: bool = int(skill.get("target_mode")) == HeroSkillDefinition.TargetMode.PASSIVE
		var hotkey: String = str(skill.get("hotkey")).to_upper()
		_hero_skill_name_by_id[skill_id] = str(skill.get("display_name"))
		var slot: VBoxContainer = VBoxContainer.new()
		slot.custom_minimum_size = Vector2(64.0, 0.0)
		slot.add_theme_constant_override(&"separation", 3)
		_hero_skill_bar.add_child(slot)

		var cast_button: Button = Button.new()
		cast_button.name = "Skill_%s" % skill_id
		cast_button.custom_minimum_size = Vector2(64.0, 58.0)
		cast_button.icon = skill.get("icon") as Texture2D
		cast_button.expand_icon = true
		cast_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cast_button.focus_mode = Control.FOCUS_NONE
		cast_button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		cast_button.add_theme_constant_override(&"icon_max_width", 50)
		cast_button.mouse_default_cursor_shape = Control.CURSOR_HELP if is_passive else Control.CURSOR_POINTING_HAND
		cast_button.mouse_entered.connect(_show_hero_skill_tooltip.bind(skill, level))
		cast_button.mouse_exited.connect(_hide_hero_skill_tooltip)
		if not is_passive:
			cast_button.pressed.connect(_on_hero_cast_pressed.bind(skill_id))
			var keycode: int = _hotkey_to_keycode(hotkey)
			if keycode != 0:
				_hero_skill_id_by_keycode[keycode] = skill_id
		slot.add_child(cast_button)
		_hero_skill_buttons[skill_id] = cast_button
		if not is_passive:
			var cooldown_overlay: Control = SkillCooldownOverlayScript.new() as Control
			cast_button.add_child(cooldown_overlay)
			cooldown_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			_hero_skill_cooldown_overlays[skill_id] = cooldown_overlay
			_hero_skill_cooldown_durations[skill_id] = float(skill.get("cooldown_seconds"))

		var badge: Label = Label.new()
		badge.text = "被动" if is_passive else hotkey
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_font_size_override(&"font_size", 10)
		badge.add_theme_color_override(&"font_color", Color("#fff4cf"))
		badge.add_theme_color_override(&"font_outline_color", Color("#101410"))
		badge.add_theme_constant_override(&"outline_size", 3)
		badge.add_theme_stylebox_override(&"normal", _skill_badge_style())
		cast_button.add_child(badge)
		badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
		badge.offset_left = 3.0
		badge.offset_top = 3.0
		badge.offset_right = 34.0 if is_passive else 24.0
		badge.offset_bottom = 22.0

		var upgrade: Button = Button.new()
		upgrade.text = "Lv.%d  ↑%d" % [level, HeroProgressionData.skill_level_cost(level)]
		upgrade.disabled = level >= HeroProgressionData.MAX_SKILL_LEVEL
		upgrade.custom_minimum_size = Vector2(64.0, 20.0)
		upgrade.focus_mode = Control.FOCUS_NONE
		upgrade.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		upgrade.add_theme_font_size_override(&"font_size", 9)
		upgrade.mouse_entered.connect(_hide_hero_skill_tooltip)
		upgrade.pressed.connect(_on_hero_skill_upgrade_pressed.bind(skill_id))
		slot.add_child(upgrade)
	_refresh_hero_skill_button_styles()

func update_hero_skill_cooldowns(cooldowns: Dictionary) -> void:
	if _selection_mode != &"hero":
		return
	for skill_id: StringName in _hero_skill_cooldown_overlays:
		var overlay: Control = _hero_skill_cooldown_overlays[skill_id]
		overlay.call(&"set_cooldown",
			float(cooldowns.get(skill_id, 0.0)),
			float(_hero_skill_cooldown_durations.get(skill_id, 0.0))
		)

func activate_hero_skill_hotkey(keycode: int) -> bool:
	if _selection_mode != &"hero" or not _hero_skill_id_by_keycode.has(keycode):
		return false
	_on_hero_cast_pressed(_hero_skill_id_by_keycode[keycode])
	return true

func set_active_hero_skill(skill_id: StringName) -> void:
	_active_hero_skill_id = skill_id
	if skill_id.is_empty():
		_hero_hint.text = "点击技能或按 Q / W / E，再左键选择目标"
	else:
		_hero_hint.text = "已选择%s：左键目标｜右键取消" % _hero_skill_name_by_id.get(skill_id, str(skill_id))
	_refresh_hero_skill_button_styles()

func _refresh_hero_skill_button_styles() -> void:
	for skill_id: StringName in _hero_skill_buttons:
		var button: Button = _hero_skill_buttons[skill_id]
		var active: bool = skill_id == _active_hero_skill_id
		button.add_theme_stylebox_override(&"normal", _skill_icon_style(active, false))
		button.add_theme_stylebox_override(&"hover", _skill_icon_style(active, true))
		button.add_theme_stylebox_override(&"pressed", _skill_icon_style(true, true))
		button.add_theme_stylebox_override(&"focus", _skill_icon_style(active, true))

func _show_hero_skill_tooltip(skill: Resource, level: int) -> void:
	var hotkey: String = str(skill.get("hotkey")).to_upper()
	var is_passive: bool = int(skill.get("target_mode")) == HeroSkillDefinition.TargetMode.PASSIVE
	_hero_tooltip_title.text = "%s  Lv.%d" % [str(skill.get("display_name")), level]
	if is_passive:
		_hero_tooltip_meta.text = "被动技能　升级消耗：%d技能经验" % HeroProgressionData.skill_level_cost(level)
	else:
		_hero_tooltip_meta.text = "[%s]　魔法 %d　冷却 %.1f秒　升级消耗 %d" % [hotkey, int(skill.get("mana_cost")), float(skill.get("cooldown_seconds")), HeroProgressionData.skill_level_cost(level)]
	_hero_tooltip_description.text = str(skill.get("description"))
	_hero_tooltip_panel.show()

func _hide_hero_skill_tooltip() -> void:
	_hero_tooltip_panel.hide()

func _hotkey_to_keycode(hotkey: String) -> int:
	match hotkey:
		"Q":
			return KEY_Q
		"W":
			return KEY_W
		"E":
			return KEY_E
	return 0

func _on_hero_skill_upgrade_pressed(skill_id: StringName) -> void:
	hero_skill_up_requested.emit(_selected_unit_id, skill_id)

func _on_hero_cast_pressed(skill_id: StringName) -> void:
	set_active_hero_skill(skill_id)
	hero_cast_requested.emit(_selected_unit_id, skill_id)

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

func _skill_icon_style(active: bool, hovered: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("#18352eff") if active else Color("#101c19ee")
	if hovered:
		style.bg_color = style.bg_color.lightened(0.1)
	style.border_color = Color("#ffd36b") if active else Color("#55796cff")
	style.set_border_width_all(3 if active else 2)
	style.set_corner_radius_all(7)
	style.content_margin_left = 4.0
	style.content_margin_top = 4.0
	style.content_margin_right = 4.0
	style.content_margin_bottom = 4.0
	style.shadow_color = Color("#f3c95b55") if active else Color("#00000077")
	style.shadow_size = 5 if active else 2
	return style

func _skill_badge_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("#07100ddd")
	style.border_color = Color("#d6b25d")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
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

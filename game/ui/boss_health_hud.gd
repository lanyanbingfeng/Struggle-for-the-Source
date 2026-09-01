class_name BossHealthHud
extends CanvasLayer

const PANEL_SIZE: Vector2 = Vector2(460.0, 52.0)
const TOP_OFFSET: float = 90.0

var _boss: WorldBoss
var _health: HealthComponent
var _encounter_visible: bool = false
var _panel: PanelContainer
var _title_label: Label
var _bar: ProgressBar
var _health_label: Label

func _ready() -> void:
	layer = 25
	_build_ui()
	hide()

func bind_boss(boss: WorldBoss, health: HealthComponent) -> void:
	unbind_boss()
	_boss = boss
	_health = health
	if is_instance_valid(_health):
		_health.state_changed.connect(_on_health_state_changed)
	if is_instance_valid(_boss):
		_boss.phase_changed.connect(_on_boss_phase_changed)
		_boss.tree_exited.connect(_on_boss_tree_exited)
	_refresh()

func unbind_boss() -> void:
	if is_instance_valid(_health) and _health.state_changed.is_connected(_on_health_state_changed):
		_health.state_changed.disconnect(_on_health_state_changed)
	if is_instance_valid(_boss):
		if _boss.phase_changed.is_connected(_on_boss_phase_changed):
			_boss.phase_changed.disconnect(_on_boss_phase_changed)
		if _boss.tree_exited.is_connected(_on_boss_tree_exited):
			_boss.tree_exited.disconnect(_on_boss_tree_exited)
	_boss = null
	_health = null
	_encounter_visible = false
	hide()

func set_encounter_visible(value: bool) -> void:
	_encounter_visible = value
	_refresh()

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_panel = PanelContainer.new()
	_panel.set_anchor(SIDE_LEFT, 0.5)
	_panel.set_anchor(SIDE_RIGHT, 0.5)
	_panel.offset_left = -PANEL_SIZE.x * 0.5
	_panel.offset_top = TOP_OFFSET
	_panel.offset_right = PANEL_SIZE.x * 0.5
	_panel.offset_bottom = TOP_OFFSET + PANEL_SIZE.y
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_panel)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#120b0ae8")
	panel_style.border_color = Color("#c99236")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(5)
	_panel.add_theme_stylebox_override("panel", panel_style)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 1)
	stack.add_theme_constant_override("margin_left", 8)
	stack.add_theme_constant_override("margin_right", 8)
	_panel.add_child(stack)
	_title_label = Label.new()
	_title_label.custom_minimum_size = Vector2(0.0, 23.0)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_color_override(&"font_color", Color("#f4d184"))
	_title_label.add_theme_color_override(&"font_outline_color", Color("#180705"))
	_title_label.add_theme_constant_override(&"outline_size", 3)
	_title_label.add_theme_font_size_override(&"font_size", 14)
	stack.add_child(_title_label)
	var bar_layer := Control.new()
	bar_layer.custom_minimum_size = Vector2(0.0, 20.0)
	stack.add_child(bar_layer)
	_bar = ProgressBar.new()
	_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bar.show_percentage = false
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_layer.add_child(_bar)
	_health_label = Label.new()
	_health_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_health_label.add_theme_color_override(&"font_color", Color.WHITE)
	_health_label.add_theme_color_override(&"font_outline_color", Color("#190504"))
	_health_label.add_theme_constant_override(&"outline_size", 3)
	_health_label.add_theme_font_size_override(&"font_size", 12)
	_health_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_layer.add_child(_health_label)
	_apply_phase_palette(1)

func _on_health_state_changed(_current_health: float, _max_health: float, _current_mana: float, _max_mana: float) -> void:
	_refresh()

func _on_boss_phase_changed(_boss_id: int, phase: int) -> void:
	_apply_phase_palette(phase)
	_refresh()

func _on_boss_tree_exited() -> void:
	call_deferred(&"unbind_boss")

func _refresh() -> void:
	var can_show: bool = _encounter_visible and is_instance_valid(_boss) and is_instance_valid(_health) and _health.is_alive()
	visible = can_show
	if not can_show:
		return
	var phase: int = _boss.get_phase()
	_title_label.text = "%s　｜　第%s阶段" % [WorldBoss.HUD_NAME, "二" if phase == 2 else "一"]
	_bar.max_value = _health.max_health
	_bar.value = _health.current_health
	_health_label.text = "%d / %d" % [roundi(_health.current_health), roundi(_health.max_health)]
	_apply_phase_palette(phase)

func _apply_phase_palette(phase: int) -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color("#24100d")
	background.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#e13b22") if phase == 2 else Color("#a92d23")
	fill.border_color = Color("#ffc75a") if phase == 2 else Color("#d49a42")
	fill.set_border_width_all(1)
	fill.set_corner_radius_all(3)
	_bar.add_theme_stylebox_override("background", background)
	_bar.add_theme_stylebox_override("fill", fill)
	_title_label.add_theme_color_override(&"font_color", Color("#ffbd48") if phase == 2 else Color("#f4d184"))

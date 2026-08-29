class_name SkillCooldownOverlay
extends Control

const COOLDOWN_SHADER: Shader = preload("res://game/ui/shaders/canvas_ui_radial_cooldown.gdshader")
const HIDDEN_THRESHOLD_SECONDS: float = 0.01

var _mask: ColorRect
var _countdown_label: Label
var _mask_material: ShaderMaterial
var _remaining_seconds: float = 0.0
var _duration_seconds: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

	_mask = ColorRect.new()
	_mask.name = "Mask"
	_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mask_material = ShaderMaterial.new()
	_mask_material.shader = COOLDOWN_SHADER
	_mask.material = _mask_material
	add_child(_mask)
	_mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_countdown_label = Label.new()
	_countdown_label.name = "Countdown"
	_countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown_label.add_theme_font_size_override(&"font_size", 17)
	_countdown_label.add_theme_color_override(&"font_color", Color.WHITE)
	_countdown_label.add_theme_color_override(&"font_outline_color", Color("#111815"))
	_countdown_label.add_theme_constant_override(&"outline_size", 5)
	add_child(_countdown_label)
	_countdown_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply_visual_state()

func set_cooldown(remaining_seconds: float, duration_seconds: float) -> void:
	var next_duration: float = maxf(0.0, duration_seconds)
	var next_remaining: float = clampf(remaining_seconds, 0.0, next_duration) if next_duration > 0.0 else 0.0
	if is_equal_approx(next_remaining, _remaining_seconds) and is_equal_approx(next_duration, _duration_seconds):
		return
	_remaining_seconds = next_remaining
	_duration_seconds = next_duration
	if is_node_ready():
		_apply_visual_state()

func get_remaining_seconds() -> float:
	return _remaining_seconds

func get_remaining_ratio() -> float:
	if _duration_seconds <= 0.0:
		return 0.0
	return clampf(_remaining_seconds / _duration_seconds, 0.0, 1.0)

func _apply_visual_state() -> void:
	var cooling_down: bool = _remaining_seconds > HIDDEN_THRESHOLD_SECONDS and _duration_seconds > 0.0
	visible = cooling_down
	if not cooling_down:
		return
	_mask_material.set_shader_parameter(&"remaining_ratio", get_remaining_ratio())
	_countdown_label.text = str(maxi(1, ceili(_remaining_seconds)))

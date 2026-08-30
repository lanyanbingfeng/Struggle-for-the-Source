extends Node

const UPGRADE_VFX_SCENE: PackedScene = preload("res://game/world/vfx/upgrade_vfx.tscn")
const EFFECT_DURATION_SECONDS: float = 1.25
const EXPECTED_PARTICLE_COUNT: int = 22

var _failures: PackedStringArray = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred(&"_run")

func _run() -> void:
	var target: Node2D = Node2D.new()
	target.name = "MovingUpgradeTarget"
	add_child(target)
	var vfx: Node2D = UPGRADE_VFX_SCENE.instantiate() as Node2D
	target.add_child(vfx)
	vfx.call(&"configure_visual_size", 96.0)
	await get_tree().process_frame

	var surface: ColorRect = vfx.get_node_or_null("UpgradeSurface") as ColorRect
	var material: ShaderMaterial = surface.material as ShaderMaterial if surface != null else null
	var sparkles: CPUParticles2D = vfx.get_node_or_null("UpgradeSparkles") as CPUParticles2D
	_expect(vfx.get_parent() == target and vfx.is_in_group(&"upgrade_vfx"), "升级特效没有挂到升级对象或没有登记特效组")
	_expect(surface != null and material != null and material.shader != null, "升级特效没有使用独立的CanvasItem Shader材质")
	_expect(sparkles != null and sparkles.emitting and sparkles.amount == EXPECTED_PARTICLE_COUNT, "升级特效没有播放轻量上升粒子")
	_expect(vfx.scale.is_equal_approx(Vector2.ONE * 1.5), "升级特效没有按目标视觉尺寸等比缩放")

	target.position += Vector2(37.0, -19.0)
	await get_tree().process_frame
	_expect(vfx.global_position.is_equal_approx(target.global_position), "升级特效没有跟随移动单位")
	await get_tree().create_timer(EFFECT_DURATION_SECONDS + 0.2).timeout
	_expect(not is_instance_valid(vfx), "升级特效播放结束后没有自动释放")

	if _failures.is_empty():
		print("UPGRADE_VFX_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("UPGRADE_VFX_SMOKE_TEST: %s" % failure)
	get_tree().quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

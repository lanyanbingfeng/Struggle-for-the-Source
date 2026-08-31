extends Node

const SKILL_IDS: PackedStringArray = [
	"iron_wall_stance", "spear_repulse", "armor_breaking_sweep", "stone_lion_roar",
	"cloudstep_combo", "armor_piercing_bolt", "five_bolt_fan", "thunder_line_shot",
	"ground_fire_pot", "hawk_mark", "binding_talisman", "chain_lightning",
	"cold_tide_field", "paper_substitute_armor", "rejuvenating_powder", "war_drum",
	"battle_banner", "cleansing_melody",
]

var _failures: PackedStringArray = []

func _ready() -> void:
	call_deferred(&"_run")

func _run() -> void:
	for skill_id: String in SKILL_IDS:
		var skill: CombatSkillDefinition = load("res://game/data/skills/%s.tres" % skill_id) as CombatSkillDefinition
		_expect(skill != null, "%s技能资源无法加载" % skill_id)
		if skill != null:
			_expect(skill.skill_id == StringName(skill_id), "%s技能ID不一致" % skill_id)
			_expect(skill.mana_cost > 0 and skill.cooldown_seconds > 0.0, "%s蓝耗或冷却无效" % skill_id)
			_expect(skill.vfx_frames != null and skill.vfx_frames.get_frame_count(&"default") == 8, "%s技能特效不是8帧" % skill_id)
	for skill_id: String in SKILL_IDS:
		var unit_id: String = _unit_id_for_skill(skill_id)
		var definition: UnitDefinition = load("res://game/data/%s_definition.tres" % unit_id) as UnitDefinition
		_expect(definition != null, "%s单位定义无法加载" % unit_id)
		if definition != null:
			_expect(definition.category == UnitDefinition.Category.COMBAT and definition.rarity == UnitDefinition.Rarity.COMMON, "%s不是白色一般战斗单位" % unit_id)
			_expect(definition.scene != null and definition.combat_skill != null, "%s缺少场景或技能资源" % unit_id)
			_expect(definition.max_mana == 100 and definition.skill_id == StringName(skill_id), "%s魔法或技能ID不正确" % unit_id)
			_expect(definition.card_texture != null, "%s缺少卡牌与世界共享立绘" % unit_id)
			_expect(definition.attack_vfx_frames != null and definition.attack_vfx_frames.get_frame_count(&"default") == 8, "%s普攻特效不是8帧" % unit_id)
			if definition.scene != null:
				var instance: Node = definition.scene.instantiate()
				_expect(instance.get_node_or_null("Sprite") != null, "%s场景缺少Sprite" % unit_id)
				_expect(instance.get_node_or_null("AttackVfx") != null, "%s场景缺少AttackVfx" % unit_id)
				_expect(instance.get_node_or_null("SkillVfx") != null, "%s场景缺少SkillVfx" % unit_id)
				add_child(instance)
				instance.call(&"configure_network", 1, 1, 1, definition, false)
				var attack_vfx: AnimatedSprite2D = instance.get_node_or_null("AttackVfx") as AnimatedSprite2D
				var skill_vfx: AnimatedSprite2D = instance.get_node_or_null("SkillVfx") as AnimatedSprite2D
				if attack_vfx != null:
					_expect(attack_vfx.scale.x < 0.2 and attack_vfx.scale.x > 0.15, "%s普攻特效显示尺寸未缩小到约72像素" % unit_id)
				if skill_vfx != null:
					_expect(skill_vfx.scale.x < 0.35 and skill_vfx.scale.x > 0.3, "%s技能特效显示尺寸未缩小到约144像素" % unit_id)
				remove_child(instance)
				instance.free()

	var root: Node2D = Node2D.new()
	add_child(root)
	var health: HealthComponent = HealthComponent.new()
	health.name = "HealthComponent"
	root.add_child(health)
	health.configure(root, 1, 100.0, 10.0)
	var status: CombatStatusController = CombatStatusController.new()
	status.name = "CombatStatusController"
	root.add_child(status)
	status.configure(root, health)
	status.apply_damage_amp(0.2, 5.0)
	var amplified_damage: float = health.apply_attack(50.0, 2)
	_expect(is_equal_approx(amplified_damage, 48.0), "20%易伤没有作用于最终伤害")
	health.configure(root, 1, 100.0, 10.0)
	status.configure(root, health)
	status.apply_next_hit_reduction(0.75, 5.0)
	var reduced_damage: float = health.apply_attack(50.0, 2)
	_expect(is_equal_approx(reduced_damage, 10.0), "替身纸甲没有降低75%实际伤害")
	health.configure(root, 1, 100.0, 10.0)
	health.apply_temporary_defense_modifier(&"test_shred", -12.0, 5.0)
	_expect(is_equal_approx(health.defense, 0.0), "破甲后防御没有限制为0")
	status.apply_root(2.5)
	_expect(status.is_rooted(), "定身状态没有生效")
	status.cleanse(false, false, false, true, true)
	_expect(not status.is_rooted(), "清心曲没有清除定身")
	_expect(is_equal_approx(health.defense, 10.0), "回春散没有清除负防御修正")

	root.queue_free()
	if _failures.is_empty():
		print("WHITE_UNIT_SKILL_FRAMEWORK_TEST: PASS")
		await get_tree().create_timer(1.0).timeout
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	await get_tree().create_timer(1.0).timeout
	get_tree().quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _unit_id_for_skill(skill_id: String) -> String:
	var mapping: Dictionary[String, String] = {
		"iron_wall_stance": "xuanjia_guard",
		"spear_repulse": "imperial_spearman",
		"armor_breaking_sweep": "modao_warrior",
		"stone_lion_roar": "guardian_stone_lion",
		"cloudstep_combo": "spirit_monkey_fighter",
		"armor_piercing_bolt": "divine_arm_crossbowman",
		"five_bolt_fan": "repeating_crossbowman",
		"thunder_line_shot": "thunder_gunner",
		"ground_fire_pot": "fire_pot_thrower",
		"hawk_mark": "hawk_scout",
		"binding_talisman": "talisman_acolyte",
		"chain_lightning": "five_thunder_mage",
		"cold_tide_field": "water_mage",
		"paper_substitute_armor": "paper_puppeteer",
		"rejuvenating_powder": "wandering_healer",
		"war_drum": "war_drummer",
		"battle_banner": "banner_bearer",
		"cleansing_melody": "cleansing_musician",
	}
	return mapping.get(skill_id, "")

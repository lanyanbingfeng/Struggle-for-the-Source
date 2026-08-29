# 孔夫子受术对象归属特效

## 已确认事实

- `confucius_hero.tscn` 不再保存固定挂在孔夫子根节点下的 `QSkillVfx`、`WSkillVfx` 和 `ESkillVfx`；三套 `SpriteFrames` 由 `HeroUnit` 预加载，并在每次技能生效时创建独立的临时 `AnimatedSprite2D`。
- Q“仁者爱人”的治疗序列挂到实际被治疗对象的 `HealthComponent.target_root`；目标移动时序列跟随目标，目标被移除时序列随目标清理。
- W“礼乐教化”会在每个实际获得临时防御的友方对象下分别播放礼制序列；E“周游列国”的赶路序列挂在移动中的孔夫子自身，抵达后的鼓舞序列则分别挂在每个实际获得攻速/移速增益的友方战斗单位下。
- 临时技能序列在 `animation_finished` 后直接 `queue_free()`，不在孔夫子场景中保留隐藏的固定实例。
- 共享 `skill_visual_requested` 信号与可靠 RPC 除技能 ID、坐标外，还传递目标实体的 `damageable_kind` 和 `damageable_id`；远端通过本地实体字典解析同一个目标节点，再把特效实例添加为该目标的子节点。目标不存在时不回退到孔夫子，避免再次出现错误归属。

## 验证

- Godot 4.7.2 在 D3D12、Forward Mobile 渲染路径运行 `res://tests/gameplay_regression_test.tscn`，输出 `GAMEPLAY_REGRESSION_OK`；覆盖 Q/W/E 特效父节点、目标移动跟随、多人目标 ID 解析、8 帧资源与播放结束自动释放。
- `card_ui_smoke_test`、`faction_tint_smoke_test`、`ai_difficulty_smoke_test`、`resource_navigation_regression_test` 和 `building_chest_interaction_regression_test` 全部输出 PASS/OK。
- Godot MCP 启动主项目，调试输出无资源、脚本或运行错误。

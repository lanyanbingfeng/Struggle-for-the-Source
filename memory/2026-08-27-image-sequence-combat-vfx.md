# 图片序列帧战斗特效

## 已确认事实

- 剑士和树人的普攻、技能特效均改为图片生成的 8 帧、4×2 透明 PNG 序列，并通过 `AnimatedSprite2D` 与 `SpriteFrames` 播放；程序只负责触发、定位和朝向，不再用 `_draw()`、运行时生成纹理或 `CPUParticles2D` 绘制这些战斗特效。
- 剑士普攻使用 `art/vfx/swordsman_attack_white_slash_8f.png`，单帧 64×64；剑士技能使用 `art/vfx/swordsman_skill_gold_slash_8f.png`，单帧 224×224，对应原有 3.5 格、112 像素半径。
- 树人普攻使用 `art/vfx/treant_attack_vine_8f.png`，单帧 64×64，动画在攻击目标脚下伸出后缩回。
- 树人技能按四档实际半径使用 208、224、240、256 像素单帧资源，分别对应 3.25、3.5、3.75、4 格范围；`TreantUnit.configure_network()` 根据定义选择匹配的 `SpriteFrames`，没有运行时缩放。
- 战斗单位场景统一包含 `AttackVfx` 和 `SkillVfx` 两个 `AnimatedSprite2D` 节点。普通攻击特效通过可靠 RPC 同步给联机客户端，技能继续沿用可靠 RPC 同步。
- 特效没有碰撞体，不改变攻击或技能判定范围。所有 PNG 只包含完全透明或完全不透明像素，Godot 导入保持无 Mipmap，场景节点使用最近邻纹理过滤。

## 验证方式

- 运行 `res://tests/gameplay_regression_test.tscn`，应输出 `GAMEPLAY_REGRESSION_OK`；测试会确认四种特效节点各有 8 帧，并校验主要 PNG 的尺寸与透明背景。
- 运行 `res://tests/card_ui_smoke_test.tscn`、`res://tests/faction_tint_smoke_test.tscn`、`res://tests/ai_difficulty_smoke_test.tscn`，应分别输出 `CARD_UI_SMOKE_TEST: PASS`、`FACTION_TINT_SMOKE_OK`、`AI_DIFFICULTY_SMOKE_TEST: PASS`。
- 使用 Godot MCP 4.7.2 启动主项目，调试输出应无脚本解析、资源加载或运行错误。

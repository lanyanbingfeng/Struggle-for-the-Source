# 孔夫子四技能实装与 ImageGen 特效

## 已确认事实

- 孔夫子四项技能已从数据占位改为房主权威结算：被动“有教无类”每 0.25 秒刷新 4 格光环；Q“仁者爱人”、W“礼乐教化”和 E“周游列国”通过英雄指令面板按钮选择技能，再左键选择目标，右键取消。
- 有教无类按技能等级使 4 格内友方战斗单位攻击提升 4%/6%/8%/10%/12%，并增加 4/6/8/10/12 点防御。光环以短时同来源状态反复刷新，离开范围后自动失效。
- 仁者爱人消耗 35 魔法、冷却 8 秒，治疗自身或 5 格内一名友军 12%/14%/16%/18%/20% 最大生命；点击空地且没有友军目标时治疗孔夫子自身。
- 礼乐教化消耗 55 魔法、冷却 14 秒，在 6 格施法距离内选择中心，对 2.75 格范围内可控制敌方单位和野怪造成 1.2/1.4/1.6/1.8/2 秒眩晕，并使范围内友方战斗单位增加 6/8/10/12/14 点防御，持续 5 秒。
- 周游列国消耗 45 魔法、冷却 12 秒，以 2 倍速度沿 A* 路径赶往 7 格内可达位置；抵达后使 3.5 格内友方战斗单位攻击和移动速度提升 15%/20%/25%/30%/35%，持续 6 秒。
- `TreantUnit` 统一管理带来源的临时攻击/移速增益和控制时间；`HealthComponent` 统一管理带来源的临时防御增益并在到期后恢复基础防御；不同技能来源可以叠加，同一来源只刷新数值与持续时间。
- 英雄按钮改用显式 `bind()` 连接对应技能 ID，避免循环闭包导致 Q/W/E 串键。施法成功后特效通过已有可靠 RPC 同步，客户端只播放视觉效果，数值仍只由单人/房主权威端结算。

## 正式特效资源

- Q：`art/vfx/confucius_q_benevolence_heal_8f.png`，青玉与金色仁爱治愈光阵，从聚气、绽放到消散。
- W：`art/vfx/confucius_w_ritual_field_8f.png`，礼制阵纹从铺开、震慑峰值、护阵维持到瓦解。
- E：`art/vfx/confucius_e_travel_inspiration_8f.png`，向前流动的青玉金色书卷风，从加速、鼓舞爆发到尾迹消散。
- 三张正式图片均由内置 ImageGen 生成并转为真实 RGBA，统一尺寸 1776×888；排布为 4 列×2 行、共 8 帧，每帧 444×444。Godot 通过 `AtlasTexture` 切帧并由 `AnimatedSprite2D` 非循环播放，Q/W/E 分别使用 12/10/14 FPS；播放结束信号负责隐藏节点，不再用单图 Tween 模拟动画。
- 原有 1254×1254 单图只保留为 ImageGen 构图来源，运行时 SpriteFrames 不再引用它们。

## 验证

- Godot MCP 4.7.2 运行 `res://tests/gameplay_regression_test.tscn` 输出 `GAMEPLAY_REGRESSION_OK`；覆盖 Q/W/E 按钮绑定、四项技能数值、魔法、冷却、状态持续时间、抵达触发、8 帧 SpriteFrames、实际播放状态、播放结束自动隐藏和 1776×888 RGBA 序列图。
- `res://tests/card_ui_smoke_test.tscn`、`res://tests/faction_tint_smoke_test.tscn`、`res://tests/ai_difficulty_smoke_test.tscn`、`res://tests/resource_navigation_regression_test.tscn`、`res://tests/building_chest_interaction_regression_test.tscn` 均输出各自 PASS/OK 标记。
- Godot MCP 4.7.2 最终启动 `res://game/main/main.tscn`，调试输出无资源加载、脚本解析或运行错误。

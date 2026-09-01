# BOSS 顶部血条与镇岳崩遮挡修复

## 已确认修改

- 顶部 BOSS HUD 的设计坐标由 `Y=118` 上移到 `Y=90`，面板仍保持顶部居中 460×52，生命整数值、阶段配色和视野显隐规则不变。本记录替代 `2026-08-31-world-boss.md` 中旧的 `Y=118` 布局事实。
- `WorldBoss._play_area_telegraph()` 增加可选表现层级；“镇岳崩”的冲击贴图和预警圈统一使用 `Sprite.z_index - 1`，保证 BOSS 本体始终绘制在自身范围特效上方。
- “天火灭阵”继续使用原有冲击贴图 `z_index=7`、预警圈 `z_index=6`，赤狱冲阵和全部伤害范围、预警时间、伤害结算均未修改。

## 验证事实

- Godot 4.7.2 运行 `res://tests/world_boss_regression_test.tscn` 输出 `WORLD_BOSS_REGRESSION_OK`；新增断言覆盖 HUD `Y=90`，以及镇岳崩冲击贴图和预警圈均低于 BOSS Sprite 层级。
- Godot MCP 使用 4.7.2、Forward Mobile 启动 `res://game/main/main.tscn`，脚本解析、资源加载和运行时输出均无错误。

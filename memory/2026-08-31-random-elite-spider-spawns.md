# 蜘蛛精英随机出生

## 已确认事实

- 每局在初始领地群附近的野外生成 5 只蜘蛛精英“幽网织母·维洛莎”，不再使用固定的 6 个出生坐标。
- 出生布局使用房主同步的 `resource_seed` 加独立盐值生成；同一种子可稳定复现，换种子会产生不同位置，因此单机每局随机且多人各端保持一致。
- 每个出生点保留 2×2 逻辑占地，并避开初始领地及其缓冲区、领地外流式资源、地图边缘和其他蜘蛛出生点；随机尝试未凑足 5 个位置时使用确定性扫描兜底。
- 本文档替代 `memory/2026-08-28-resource-loop-hero-altar-wild-monster.md` 和 `memory/2026-08-30-elite-spider-combat.md` 中关于蜘蛛数量与固定出生位置的旧规则；蜘蛛战斗属性、权威同步、技能和掉落规则不变。

## 验证方式

- Godot 4.7.2 运行 `res://tests/gameplay_regression_test.tscn`，输出 `GAMEPLAY_REGRESSION_OK`；覆盖数量为 5、同种子复现、不同种子变化、2×2 占地、地图边界、领地避让和出生点不重叠。
- 运行 `res://tests/resource_navigation_regression_test.tscn`、`res://tests/card_ui_smoke_test.tscn`、`res://tests/faction_tint_smoke_test.tscn` 和 `res://tests/ai_difficulty_smoke_test.tscn`，分别输出通过标记且退出码为 0。
- 使用 Godot MCP 启动 `res://game/main/main.tscn`，调试输出无脚本解析、资源加载或运行时错误。

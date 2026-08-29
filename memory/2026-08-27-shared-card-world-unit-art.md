# 单格单位共享卡牌与世界美术

- 单格单位不再维护独立的 32×32 世界造型；卡牌 UI 与世界 Sprite 直接引用同一张高清 RGBA 立绘，世界侧等比缩放，使主体最长边约 28～30 px 并完整落入 32×32 一格。
- 当前建筑工人、探索者、剑士、树人、伐木机和采石机场景均已切换为对应卡牌纹理；世界侧使用 Linear 过滤，碰撞、移动和玩法数值不变。
- 多格单位不适用共享缩小规则，必须单独生成与其视觉占地匹配的世界资源。
- 采石机新增高清卡牌 `art/ui/cards/card_quarry_machine_art.png`，保留橙蓝履带车体，工作部件为与伐木机一致的银色齿轮，不使用钻头；`quarry_machine_definition.tres` 已改为引用该卡图。
- `docs/asset-generation-spec.md` 已升级到 v3.0，正式替代旧的“所有 1×1 单位必须原生 32×32、禁止缩放卡图”规则。
- 旧的四张 `art/units/unit_*_1x1.png`、两张机器车体和两个独立机器部件已删除；原生资源生成脚本不再重新生成剑士或建筑工人的 32×32 副本。
- 验证结果：Godot 4.7.2 MCP 运行 `tests/card_ui_smoke_test.tscn` 输出 `CARD_UI_SMOKE_TEST: PASS`，确认六类单格单位共享卡牌/世界纹理且主体不超过一格；`tests/gameplay_regression_test.tscn` 输出 `GAMEPLAY_REGRESSION_OK`；主场景启动后 `errors: []`。

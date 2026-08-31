# 树人坦度削弱

## 已确认调整

- 四档树人的基础生命与防御已统一下调，保留坦克定位但减少过高的持续承伤能力：普通树人为 280 生命/40 防御，铁木树人为 360 生命/48 防御，远古树人为 500 生命/60 防御，世界根守卫为 700 生命/80 防御。
- 四档树人的攻击、攻速、攻击距离、闪避、移速、魔法、光合作用治疗比例、范围、消耗与冷却均保持不变。
- `tests/gameplay_regression_test.gd` 已增加四档树人生命与防御的回归断言；本记录中的数值替代早期树人卡牌记忆中记录的旧数值。

## 验证方式

- 使用 Godot 4.7.2 无头运行 `res://tests/gameplay_regression_test.tscn`，日志输出 `GAMEPLAY_REGRESSION_OK`，无错误。
- 使用 Godot 4.7.2 无头运行 `res://tests/card_ui_smoke_test.tscn`，日志输出 `CARD_UI_SMOKE_TEST: PASS`。
- 使用 Godot MCP 启动并停止 `res://game/main/main.tscn`，最终调试输出无错误。

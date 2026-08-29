# 指定开箱与建筑交互回归修复

- 玩家右键指定宝箱属于一次玩家攻击指令。宝箱被打开后，战斗单位在当前位置结束该指令，不执行自动索敌使用的脱战返航。
- `ProductionBuilding` 的建筑交互区与收货气泡使用非零 2D 碰撞层，保证 Godot 鼠标拾取可以触发 `input_event`；气泡仍只对建筑所有者显示和响应。
- 生产建筑产出先累计在 `pending_amount`。点击气泡发出收货请求，房主一次结清库存并同步资源与气泡状态。
- 气泡在独立资源图片尚未绑定时显示“金、木、石、铁”资源标记和精确/`999+` 数量，避免只显示孤立数字。
- 施工建筑恢复头顶剩余秒数，同时保留施工进度条；完工后两者一起隐藏。
- 英雄台与其他建筑共用可靠的建筑点击输入区；已完成且属于本地玩家的英雄台会进入独立英雄召唤模式。
- 新增 `tests/building_chest_interaction_regression_test.tscn`，覆盖开箱不返航、建筑/气泡输入信号、资源标记和施工倒计时。总玩法回归中的旧英雄混合召唤、建筑直接入账断言已更新为孔夫子独立召唤和手动收货规则。

## 验证

- Godot 4.7.2 通过 MCP 启动 `res://game/main/main.tscn`，调试输出无脚本解析、资源加载或运行时错误。
- 定向回归场景：`res://tests/building_chest_interaction_regression_test.tscn`。
- 总玩法回归场景：`res://tests/gameplay_regression_test.tscn`。

# 玩家指令优先、指定集火与全图资源寻路

## 已确认修改

- 战斗单位采用“玩家移动指令 > 玩家指定攻击目标 > 自动索敌”的控制优先级。
- 玩家下达移动指令后，单位会清除当前攻击目标并持续执行路径，抵达前不会被附近敌人重新拉走；新的玩家攻击指令可以覆盖移动指令。
- 左键点击可见敌方单位或对其下达右键命令，会保留当前友军选择并让所选战斗单位优先攻击该目标；目标位置显示持续脉冲标记。移动到空地会取消指定目标。
- 指定目标请求走服务端权威校验：目标必须存活且敌对，单位必须属于请求玩家并且是战斗单位。
- 自动追击、指定目标追击和脱战返回均复用 `WorldPathfinder`，避免战斗追击绕过地图障碍。
- 领地外流式资源不再依赖当前是否加载可视 Marker。`WorldResourceStreamer` 从全量资源数据提供障碍格，树占锚点格及其上方一格，其他资源占一格。
- `WorldPathfinder` 分开保存实体碰撞障碍和流式资源障碍，因此建筑、领地内资源变化触发的常规重建不会丢失领地外障碍；世界资源重生成或被领地认领时会刷新流式障碍集合。

## 影响范围

- `game/main/map_demo.gd`
- `game/units/treant_unit.gd`
- `game/world/world_command_overlay.gd`
- `game/world/world_pathfinder.gd`
- `game/world/world_resource_streamer.gd`
- `tests/gameplay_regression_test.gd`

## 验证

- Godot 4.7.2 `gameplay_regression_test.tscn`：`GAMEPLAY_REGRESSION_OK`。
- Godot 4.7.2 `card_ui_smoke_test.tscn`：`CARD_UI_SMOKE_TEST: PASS`。
- Godot 4.7.2 `faction_tint_smoke_test.tscn`：`FACTION_TINT_SMOKE_OK`。
- Godot 4.7.2 `ai_difficulty_smoke_test.tscn`：`AI_DIFFICULTY_SMOKE_TEST: PASS`。
- 通过 Godot MCP 启动 `game/main/main.tscn`，调试输出无脚本解析、资源加载或运行时错误。

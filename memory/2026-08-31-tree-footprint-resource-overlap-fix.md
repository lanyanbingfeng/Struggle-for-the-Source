# 树木两格资源占用重叠修复

## 已确认修改

- 树木逻辑占用根部格和其正上方一格。`WorldResourceStreamer` 在生成树木前会同时检查两格，并将两格都登记到资源占用表；石头、矿物和宝箱因此不能再生成到树木上格。
- 如果任一树木占用格已有其他资源，流送器会拒绝生成该树；树木被领取或移除时会同时释放两格，避免残留幽灵占用。
- 初始领地的随机稀有资源候选会排除树木根部格和上格。丰富资源档原本位于 `(15,15)`、与 `(15,16)` 树木上格重叠的额外石头已平移到 `(16,15)`，资源数量和双方公平布局不变。

## 影响文件

- 流送资源两格占用：`game/world/world_resource_streamer.gd`
- 初始领地资源布局：`game/main/map_demo.gd`
- 回归覆盖：`tests/resource_navigation_regression_test.gd`

## 验证

- Godot 4.7.2 运行 `res://tests/resource_navigation_regression_test.tscn` 输出 `RESOURCE_NAVIGATION_REGRESSION_OK`，覆盖流送树木两格冲突、移除后完整释放、已有上格资源时拒绝生成树木，以及稀缺/标准/丰富三档初始布局。
- 通过 Godot MCP 启动 `res://game/main/main.tscn`，调试输出无脚本解析、资源加载或运行时错误。

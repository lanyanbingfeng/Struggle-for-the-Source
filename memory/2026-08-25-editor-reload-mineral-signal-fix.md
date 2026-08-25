# 编辑器重载矿物信号竞态修复

- 编辑器重新加载项目时，稀有矿物在加入场景树后、连接 `depleted` 信号前可能被场景重载释放，导致 `map_demo.gd` 访问已删除 `MineralResource`。
- `_spawn_initial_resources()` 现在先通过 `connect()` 连接矿物耗尽信号，再调用 `rare_mineral_container.add_child()`；矿物生成、资源类型和耗尽逻辑不变。
- Godot MCP 随后启动主场景，调试输出 `errors: []`，重载竞态没有再次出现。

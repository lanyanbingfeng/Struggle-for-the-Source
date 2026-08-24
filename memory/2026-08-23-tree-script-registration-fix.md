# 树脚本类型注册兼容修复

- 问题：编辑器重载时，`BaseInteraction` 和 `HarvestTree` 的 `class_name` 可能尚未注册，导致地图脚本将节点解析为基础类型并报信号、类型不存在。
- 修复：地图脚本对基地交互使用 `Area2D`，通过 `connect(&"selected", ...)` 连接信号；树实例使用 `Node2D` 接收，不依赖 `HarvestTree` 全局类注册。
- 影响范围：不改变基地交互信号、树场景行为或树的随机生成逻辑，降低编辑器脚本重载时的类型注册依赖。
- 验证方式：Godot 4.7.1 headless 项目启动检查通过，未再出现 `selected` 或 `HarvestTree` 解析错误。

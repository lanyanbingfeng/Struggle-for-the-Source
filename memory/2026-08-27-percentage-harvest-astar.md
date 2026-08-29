# 百分比采集、就近资源分配与稳定A星寻路

## 已确认修改

- 树木、石头、铁矿、金矿和钻石矿实例均保存独立的 `harvest_progress_percent`，初始值为100；采集单位通过 `consume_harvest_progress()` 按周期扣减，进度归零后资源立即不可再选，随后播放原有倒下或破碎动画并结算。
- 为保持原有采集耗时，单周期扣减分别为：树木34%、石头25%、铁矿20%、金矿16.6667%、钻石12.5%；机器等级仍通过采集周期速度倍率生效。
- 每台伐木机和采矿机独立遍历自身 `territory_id` 内可采资源，同时计算资源左右工作位的可达路径，并按实际路径总长度选择最近目标；自动采集移动复用 `WorldPathfinder`，不再直线穿过障碍。
- `WorldPathfinder` 已由“直线检测加局部绕点”替换为按需八方向A星：使用八方向距离启发、二叉最小堆、防止斜穿墙角、递增搜索走廊和带单位净空的路径平滑。1000×1000世界仍不创建常驻百万格图。
- 移动单位使用碰撞层1、仅检测静态障碍层2，避免编队成员互相堵死；战斗单位、探索者和建筑工人在路径没有实际推进0.45秒后会自动重新寻路。

## 影响范围

- 资源状态：`game/world/tree.gd`、`stone.gd`、`mineral_resource.gd`及三类矿物场景。
- 采集单位：`game/units/lumber_machine.gd`、`quarry_machine.gd`。
- 通用移动与寻路：`game/world/world_pathfinder.gd`、`game/units/treant_unit.gd`、`explorer_unit.gd`及单位场景碰撞配置。
- 主地图接线：`game/main/map_demo.gd`。

## 验证

- Godot 4.7.2 运行 `res://tests/resource_navigation_regression_test.gd` 输出 `RESOURCE_NAVIGATION_REGRESSION_OK`：覆盖百分比扣减、归零不可选、伐木/采矿单位独立最近目标、领地隔离、墙体缺口最短路线、防斜穿墙角、U形障碍脱困、单位碰撞分层和主地图AI采集接线。
- 通过 Godot MCP 启动 `res://game/main/main.tscn`，调试输出无脚本解析、资源加载或运行时错误。

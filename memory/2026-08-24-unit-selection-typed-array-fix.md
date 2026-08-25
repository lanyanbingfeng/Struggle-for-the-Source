# 单位单选强类型数组修复

## 问题与修复

- 单击地图触发 `_select_single_unit()` 时，三元表达式 `[nearest_unit_id] if ... else []` 的结果会被 GDScript 推断为普通 `Array`，不能作为 `Array[int]` 传给 `_set_selected_units()`，因而在 Godot 4.7.2 运行时报类型错误。
- `game/main/map_demo.gd` 现在先显式创建 `Array[int]`，命中单位时再追加单位 ID，最后把这个强类型数组交给 `_set_selected_units()`。
- 对要求强类型数组的函数，避免直接传入由三元表达式合成的数组字面量；应先声明目标元素类型。

## 验证

- 回归场景依次执行空地点选和树人点选，输出 `SELECTION_REGRESSION PASS`，Godot 日志没有脚本错误。
- 临时回归脚本和场景在验证后已逐个删除，不属于正式项目文件。

# 升级特效尺寸与裁切修复

## 已确认调整

- 玩家实机截图确认初版基地升级特效过大，并且圆环最终半径和柔边超过 `UpgradeSurface` 的底部绘制边界，造成圆环缺口。
- 单位、生产建筑、基地的特效视觉直径由 `56/96/132` 调整为 `52/84/92`；基地版本缩小最明显，避免升级时覆盖大范围地图内容。
- `canvas_world_upgrade_vfx.gdshader` 的外环最大 UV 半径由 `0.43` 收紧到 `0.30`，内环、光晕和放射线同步限制在安全绘制区；能量柱顶部增加淡出，所有主要图层都不会在 `ColorRect` 边缘硬截断。
- 本文档替代 `memory/2026-08-30-shared-upgrade-vfx.md` 中记录的旧尺寸，其他升级触发、联机同步、跟随目标和自动释放规则不变。

## 验证

- D3D12、Forward Mobile 实际渲染截图确认基地圆环完整闭合，底部和左右没有裁切，临时验收场景与截图已清理。
- `res://tests/upgrade_vfx_smoke_test.tscn` 输出 `UPGRADE_VFX_SMOKE_TEST: PASS`。
- `res://tests/gameplay_regression_test.tscn` 输出 `GAMEPLAY_REGRESSION_OK`，并覆盖单位、生产建筑和基地的新缩放值。
- Godot MCP 4.7.2 启动主场景，调试输出无脚本、Shader、资源加载或运行错误。

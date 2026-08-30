# 共享单位与建筑升级特效

## 已确认实现

- `game/world/vfx/upgrade_vfx.tscn` 是单位与建筑共用的升级视觉组件，使用 `canvas_world_upgrade_vfx.gdshader` 绘制青金能量柱、双层扩散光环和放射光芒，并叠加 22 个轻量 `CPUParticles2D` 上升粒子及“升级!”浮字。
- 特效持续 1.25 秒，挂在实际升级对象下，因此会跟随移动单位；播放结束后自动 `queue_free()`。单位、生产建筑和基地分别按 56、96、132 像素视觉直径等比适配，不改变纹理宽高比，也不创建碰撞或玩法判定。
- 基地、伐木/采石机器、英雄等级、英雄技能和生产建筑的服务端成功升级路径都会触发同一特效；AI 复用相同的服务端升级函数，因此 AI 升级也会触发。资源不足、满级或其他失败升级不会播放。
- 联机时由权威端在升级状态同步后发送可靠的独立视觉 RPC；每个客户端在对应本地实体下创建特效，视觉事件不参与数值结算。

## 配置位置

- 特效场景、脚本与 Shader：`game/world/vfx/upgrade_vfx.tscn`、`upgrade_vfx.gd`、`canvas_world_upgrade_vfx.gdshader`
- 升级成功入口和联机视觉事件：`game/main/map_demo.gd`
- 独立生命周期测试：`tests/upgrade_vfx_smoke_test.tscn`
- 五类升级接入回归：`tests/gameplay_regression_test.tscn`

## 验证

- Godot 4.7.2 运行 `res://tests/upgrade_vfx_smoke_test.tscn`，输出 `UPGRADE_VFX_SMOKE_TEST: PASS`；覆盖 Shader、粒子、尺寸适配、移动跟随和自动释放。
- `gameplay_regression_test`、`card_ui_smoke_test`、`faction_tint_smoke_test`、`ai_difficulty_smoke_test`、`resource_navigation_regression_test` 和 `building_chest_interaction_regression_test` 均输出 PASS/OK。
- Godot MCP 在 D3D12、Forward Mobile 渲染路径启动主场景，调试输出无资源加载、脚本解析、Shader 编译或运行错误。
- `memory/2026-08-30-resource-hud-progress-icons.md` 验证段记录的 Shader 内置 `PI` 重定义问题已在本次实现中修复，该错误不再是当前项目状态。

# 技能图标径向冷却遮罩

## 已确认事实

- 主动技能图标采用标准“径向冷却遮罩（Radial Cooldown Wipe / Clock Wipe）”：冷却期间先覆盖半透明黑色蒙版，再从图标 12 点方向绘制随剩余比例顺时针收缩的白色扇形，并在扇形边界显示亮白扫描线。
- `game/ui/skill_cooldown_overlay.gd` 是可复用的冷却 UI 控件；中央以向上取整的整数显示剩余秒数，冷却归零后整个遮罩自动隐藏。被动技能不创建冷却遮罩。
- `game/ui/shaders/canvas_ui_radial_cooldown.gdshader` 是 Mobile 渲染器兼容的 `canvas_item` Shader；使用 `step`、`smoothstep` 和混合运算完成扇形与扫描边，不进行纹理采样或动态分支。
- `UnitCommandPanel` 从每项 `HeroSkillDefinition.cooldown_seconds` 读取总时长，`MapDemo` 每帧把当前选中 `HeroUnit.skill_cooldowns` 的真实剩余值更新到 Q/W/E 遮罩，UI 不维护独立计时器。
- 多人游戏的远端客户端收到英雄技能视觉 RPC 时，会根据同一技能资源启动本地显示用冷却倒计时；实际技能合法性与数值结算仍由权威端控制。

## 验证

- Godot 4.7.2 在 D3D12、Forward Mobile 渲染路径运行 `res://tests/gameplay_regression_test.tscn`，输出 `GAMEPLAY_REGRESSION_OK`；覆盖 Q/W/E 三个遮罩、完整冷却、50% 冷却、Shader 参数、秒数更新和归零隐藏。
- `res://tests/card_ui_smoke_test.tscn` 输出 `CARD_UI_SMOKE_TEST: PASS`。
- Godot MCP 启动主项目后调试错误列表为空。

# 孔夫子底部技能栏与 QWE 输入修复

## 已确认事实

- `UnitCommandPanel` 的机器、探索者、建筑工人和建筑面板继续使用右下角通用布局；英雄选中时改为独立的底部中央横向技能栏，逻辑尺寸约 500×104，不再显示遮挡右侧视野的大段英雄说明。
- 英雄技能栏依次显示被动、Q、W、E 四个图标。每个图标下方保留紧凑的技能等级/升级按钮；被动标记“被动”，三个主动技能在图标左上角显示 Q/W/E。
- 鼠标进入技能图标或升级按钮时，在技能栏上方显示固定尺寸的自定义说明面板，包含技能名、等级、热键、魔法、冷却、升级消耗和完整技能描述；不再使用会铺满底部的大型系统 Tooltip。
- 主动技能可以通过点击图标或键盘 Q/W/E 进入目标选取状态。选中技能会显示金色边框和“左键目标、右键取消”提示；选择越界或其他无效目标时不会清掉待施放状态，有效施放、右键取消或切换单位后才清除。
- `MapDemo._unhandled_input()` 同时识别逻辑键码和物理键码；建筑/领地预览期间仍优先把 W/A/S/D 用于位置微调，不与英雄热键冲突。
- 四个技能图标由 `HeroSkillDefinition.icon` 数据字段提供，UI 不硬编码孔夫子路径，后续英雄可复用同一技能栏。

## 正式资源

- `art/ui/skills/confucius_passive_education_icon.png`
- `art/ui/skills/confucius_q_benevolence_icon.png`
- `art/ui/skills/confucius_w_ritual_icon.png`
- `art/ui/skills/confucius_e_travel_icon.png`
- 四张图均为内置 ImageGen 生成的 1254×1254 RGBA 高清 PNG，Godot 以 Linear 过滤等比缩放到技能按钮内；热键文字由 UI 单独绘制，没有烘进图片。

## 验证

- Godot MCP 4.7.2 运行 `res://tests/gameplay_regression_test.tscn` 输出 `GAMEPLAY_REGRESSION_OK`；覆盖底部横向布局、四图标、图标点击、键盘 E、无效目标保持选取、有效目标施放、魔法/冷却与技能特效。
- `res://tests/card_ui_smoke_test.tscn` 输出 `CARD_UI_SMOKE_TEST: PASS`，确认通用建筑选择 UI 未受英雄栏拆分影响。
- Godot MCP 4.7.2 启动 `res://game/main/main.tscn`，调试错误列表为空。

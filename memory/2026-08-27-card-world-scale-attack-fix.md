# 共享卡图攻击缩放修复

## 已确认问题

- 剑士与树人共用的 `TreantUnit._play_attack_animation()` 曾把 `Sprite2D.scale.x` 直接赋值为 `1` 或 `-1`。
- 单格单位改为共享 1254×1254 卡牌美术后，世界贴图依赖约 `0.025` 的节点缩放；首次攻击覆盖横向缩放会把整张卡图横向展开，形成贯穿屏幕的彩色色带。

## 修复决定

- 单位进入场景时缓存 `Sprite2D` 的绝对基础缩放。
- 攻击朝向只改变基础横向缩放的正负号，同时保留基础横纵缩放比例；禁止再用 `±1` 覆盖卡图 Sprite 的局部缩放。
- 战斗回归测试在剑士完成真实攻击后比较攻击前后的绝对缩放，防止共享卡图再次被动画放大。

## 影响范围与验证

- 影响使用 `game/units/treant_unit.gd` 的剑士与树人单位。
- Godot 4.7.2 Mobile 实跑 `tests/gameplay_regression_test.tscn`，输出 `GAMEPLAY_REGRESSION_OK`，无错误。
- Godot 4.7.2 Mobile 实跑 `tests/card_ui_smoke_test.tscn`，输出 `CARD_UI_SMOKE_TEST: PASS`，无错误。
- 启动 `game/main/main.tscn` 后 Godot 调试输出无脚本、资源或运行错误。

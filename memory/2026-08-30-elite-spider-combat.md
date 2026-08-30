# 幽网织母蜘蛛精英战斗

## 已确认事实

- 原占地四格（2×2）的基础野怪现定位为蜘蛛精英“幽网织母·维洛莎”，场景上方常驻显示“精英”标记与正式名称；正式单位贴图仍沿用历史路径 `art/units/unit_wild_beetle_imagegen_2x2.png`。
- 精英基础属性为 980 生命、16 防御、48 普攻、1.45 秒攻击间隔、4.25 格攻击距离和 78 移速。它会在 9 格内索敌、以 12 格出生点半径为追击边界，通过 `WorldPathfinder.find_path()` 主动追击并在脱战后返回出生点。
- 野怪继续由单人端或房主权威执行索敌、移动、攻击、技能、受伤与死亡；多人客户端每 0.1 秒接收蜘蛛位置与生命同步，普攻和技能特效通过可靠 RPC 播放。
- 普攻表现为飞向目标的毒液弹幕，使用高清透明原图 `art/vfx/elite_spider_venom_bolt.png`；技能会在目标位置铺设 2.75 格范围蛛网，造成 72 点受防御影响的原始伤害并控制可移动单位 1.75 秒，初次施放延迟 3 秒、冷却 9 秒，使用 `art/vfx/elite_spider_web_field.png`。
- 战斗单位、英雄、探索者、建筑工人、伐木机和采石机均可响应蛛网控制；基地和建筑仍可受到蛛网伤害，但不会执行移动控制。
- 移动蜘蛛不再作为静态格写入 `WorldPathfinder` 障碍集合，其 2×2 逻辑占地由 `CharacterBody2D` 的 54×46 碰撞形状和 44 像素战斗半径维持，避免寻路缓存保留已离开的出生格。

## 验证方式

- Godot 4.7.2 运行 `res://tests/gameplay_regression_test.tscn`，应输出 `GAMEPLAY_REGRESSION_OK`；测试覆盖精英名称、强化属性、移动速度、毒液特效、蛛网范围伤害与控制以及两张高清透明资源。
- 运行 `res://tests/card_ui_smoke_test.tscn`、`res://tests/faction_tint_smoke_test.tscn`、`res://tests/ai_difficulty_smoke_test.tscn` 和 `res://tests/resource_navigation_regression_test.tscn`，应分别输出 PASS/OK 标记。
- 使用 Godot MCP 启动 `res://game/main/main.tscn`，主场景应无脚本解析、资源加载和运行时错误；接近蜘蛛后确认其主动追击、毒液飞行、蛛网范围与受控单位停步表现。

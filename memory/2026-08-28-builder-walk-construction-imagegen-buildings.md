# 建筑工人寻路施工与 ImageGen 独立建筑美术

- 基地中间操作按钮保持显示“召唤”，但只负责说明现行召唤规则；英雄选择与实际召唤只能由玩家点击已完工的英雄台进入，英雄台展示全部可用英雄。
- 建筑选址与探索者预览采用相同键盘习惯：选择建筑后显示 2×2 预览，WASD 每次移动一格；确认后先预扣建造资源并为建筑工人计算通往建筑相邻格的路径。
- 建筑不会在确认时立即生成。工人实际抵达相邻施工位后才创建建筑并开始倒计时；施工期间工人隐藏、停止碰撞/移动且不提供视野，建筑完成或施工建筑被移除时在施工位重新出现。
- 工人死亡、路径失效或到达后选址失效时会取消待施工任务并返还预扣资源；正在前往或施工的工人不能接受普通移动或第二个建筑任务。
- 金币生产台、伐木场、采石场、铁矿场和英雄台各自使用独立 64×64 正式贴图，不再共用通用工坊。通用施工架、宝箱和 2×2 基础甲虫也替换为独立正式贴图。
- 本次八张正式美术全部由 Codex 内置 ImageGen 生成。原始生成图保存在 `art/sources/imagegen/`；正式图使用透明 RGBA、正交俯视、左上光源和硬像素边缘，并通过机械透明边界裁切、Nearest 缩放及底部对齐得到 64×64 或 32×32 文件。
- 正式路径分别为 `art/structures/structure_coin_table_imagegen_2x2.png`、`structure_lumber_camp_imagegen_2x2.png`、`structure_quarry_yard_imagegen_2x2.png`、`structure_iron_mine_imagegen_2x2.png`、`structure_hero_altar_imagegen_2x2.png`、`structure_under_construction_imagegen_2x2.png`、`art/resources/resource_treasure_chest_imagegen_1x1.png` 和 `art/units/unit_wild_beetle_imagegen_2x2.png`。
- 旧的程序生成通用工坊、施工架、宝箱、甲虫正式贴图及 `art/sources/generate_unit_and_building_assets.gd` 已删除。本文档替代旧记忆中“建筑固定在工人当前格直接生成”和上述旧资源路径的现行说明。

## 验证

- Godot 4.7.2 运行 `res://tests/gameplay_regression_test.tscn`，应输出 `GAMEPLAY_REGRESSION_OK`；该测试覆盖基地“召唤”标签、点击英雄台展示全部英雄、WASD 单格微调、工人实际靠近工地、到达前可见、施工中隐藏、完工后重现及五类建筑贴图互不相同。
- 运行 `res://tests/card_ui_smoke_test.tscn`、`res://tests/faction_tint_smoke_test.tscn`、`res://tests/ai_difficulty_smoke_test.tscn` 和 `res://tests/resource_navigation_regression_test.tscn`，应分别输出 PASS/OK 标记且调试输出无错误。
- 运行 `res://game/main/main.tscn`，确认能进入主界面且调试输出无资源加载、脚本解析和旧路径错误。

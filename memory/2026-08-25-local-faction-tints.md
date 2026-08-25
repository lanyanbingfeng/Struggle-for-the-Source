# 本地视角阵营着色规则

- 基地与单位的阵营颜色都以当前客户端的队伍关系为参照：本地玩家及同队玩家保持原始贴图颜色，敌对玩家统一使用暖红色 `#ff947d`。
- `PlayerBase.ENEMY_FACTION_TINT` 是敌方基地与敌方单位共用的颜色常量，避免两类实体出现不同红色。
- 单位生成后只给其已有的 `Sprite2D` 美术节点设置 `self_modulate`；生命条、选择圈和其他运行时交互节点不参与染色。
- 运行 `res://tests/faction_tint_smoke_test.tscn`，看到 `FACTION_TINT_SMOKE_OK` 即可验证己方基地/单位保持原色、敌方基地/单位均为暖红色，且生命条不被染色；综合回归测试 `res://tests/gameplay_regression_test.gd` 也包含同样断言。

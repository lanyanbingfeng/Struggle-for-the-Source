# 战斗单位强制升星与品质修正

## 已确认实现

- 升星只适用于 `UnitDefinition.Category.COMBAT` 的召唤战斗单位；英雄、建筑工人、探索者和采集机器不参与，也不显示战斗单位星级。
- 权威端每次生成战斗单位后，都会检查同一玩家、同一 `UnitDefinition`、同一星级的单位。三个一星强制融合为一个二星，三个二星继续强制融合为一个三星，最高三星且支持一次生成后的连锁融合。
- 融合保留三个候选中网络 ID 最小的既有单位，因此其世界位置和当前行为不会因新召唤单位而被拉回基地；另外两个单位从权威单位表和选择状态中移除。若任一被融合单位已选中，选择会转移/保留到融合后的单位。
- 一星、二星、三星的核心属性倍率分别为 `1.0 / 3.25 / 10.75`，作用于最大生命、攻击、技能伤害和基础防御。每一级都严格强于三个前一级单位的对应核心属性。融合时三个来源的当前生命与魔法相加，再按新单位上限截断。
- 所有战斗单位头顶常驻显示 `★`、`★★` 或 `★★★`；二星为黄色、三星为橙色，并复用共享升级特效表现融合。
- 融合结果通过可靠 RPC 同步消耗单位、保留单位、星级和当前生命/魔法；0.1 秒单位状态快照额外携带星级，用于持续纠正客户端状态。

## 品质修正

- 五档品质显示统一为：白色一般、绿色普通、蓝色优秀、紫色优秀、金色传说；卡牌边框与单字徽章使用对应颜色和名称。
- 基础树人和剑士均改为第 0 档白色一般品质。Lv.1 的召唤概率摘要现在显示“白色一般100%”，且实际抽取只会得到白色一般的树人或剑士，不再依赖向上品质回退。

## 关键文件与验证

- 权威融合、RPC 和星级快照：`game/main/map_demo.gd`
- 星级倍率、有效战斗属性和头顶星标：`game/units/treant_unit.gd`
- 运行时基础防御更新：`game/systems/health_component.gd`
- 品质名称、颜色与基础单位资源：`game/data/base_progression.gd`、`game/ui/summon_card_menu.gd`、`game/data/treant_definition.tres`、`game/data/swordsman_definition.tres`
- Godot 4.7.2 专项回归 `res://tests/combat_unit_star_fusion_test.tscn` 输出 `COMBAT_UNIT_STAR_FUSION_TEST: PASS`。
- Godot 4.7.2 完整玩法回归和卡牌 UI 回归分别输出 `GAMEPLAY_REGRESSION_OK`、`CARD_UI_SMOKE_TEST: PASS`。

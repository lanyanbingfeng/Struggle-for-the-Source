# 十八种白色战斗单位与完整特效资源

- 在树人和剑士之外新增18种一般品质战斗单位，并全部加入 `unit_catalog.tres` 的正式定义列表与召唤池。
- 每个单位拥有独立 `UnitDefinition`、单位场景和数据驱动 `CombatSkillDefinition`；单位场景统一保留 `Sprite`、`AttackVfx`、`SkillVfx`，并复用共享战斗脚本。
- `UnitDefinition` 现支持共享卡牌/世界立绘、普攻 `SpriteFrames`、普攻特效放置模式与数据驱动技能引用。
- 新增组合式 `CombatStatusController`，覆盖定身、眩晕、控制免疫、控制抵抗、移速/攻速变化、易伤、持续伤害、单次减伤、净化与视野标记；同来源持续状态刷新而不叠加。
- 已生成并接入54张透明高清PNG：18张共享单位立绘、18张普攻8帧序列图、18张技能8帧序列图。序列原图为服务输出的1774×887透明2:1画布，按4×2等分为八个443.5×443.5高清帧，不拉伸或重采样原图。
- 权威端继续负责伤害、治疗、碰撞、范围与状态结算；可靠RPC只同步普攻/技能表现和战斗状态快照。

## 验证

- Godot 4.7.2 主场景启动无资源加载或脚本解析错误。
- `WHITE_UNIT_SKILL_FRAMEWORK_TEST: PASS`：验证18个定义/技能、54张资源引用、36套八帧动画与单位场景节点结构。
- `CARD_UI_SMOKE_TEST: PASS`、`COMBAT_UNIT_STAR_FUSION_TEST: PASS`、`FACTION_TINT_SMOKE_OK`、`GAMEPLAY_REGRESSION_OK`、`AI_DIFFICULTY_SMOKE_TEST: PASS`。
- 资源导航回归仍存在与本功能无关的既有随机地图失败：资源档2初始领地可能在树木占格生成其他资源。

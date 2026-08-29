# 争源项目记忆库

> 这是项目记忆的唯一入口。开始任务前先阅读本文档，再按任务读取 `memory/` 下的相关文档。
>
> 索引规则：新增、重命名、移动或删除记忆文档时，必须同步更新本索引。

## 记忆文档索引

- [开始界面与游戏菜单](memory/2026-08-23-main-menu-pause-menu.md)
- [首批瓦片资源及导入规范](memory/2026-08-22-tile-resources.md)
- [伐木机器最终尺寸决定](memory/2026-08-23-lumber-machine-size.md)
- [基地操作菜单交互](memory/2026-08-23-base-action-menu.md)
- [鼠标边缘滚屏视角](memory/2026-08-23-camera-edge-scroll.md)
- [随机树与临时砍伐测试](memory/2026-08-23-random-tree-harvest-test.md)
- [树脚本类型注册兼容修复](memory/2026-08-23-tree-script-registration-fix.md)
- [树木砍伐倒下动画序列帧](memory/2026-08-23-tree-fall-animation.md)
- [资源 HUD 与自动伐木机器](memory/2026-08-23-resource-hud-auto-lumber-machine.md)
- [菜单输入层与伐木机器朝向修复](memory/2026-08-23-pause-menu-lumber-machine-fixes.md)
- [项目文件目录整理](memory/2026-08-23-project-file-organization.md)
- [公平领地、可重复招募与双采集机器](memory/2026-08-24-territory-recruitment-harvest-machines.md)
- [第二领地场景可见性修复](memory/2026-08-24-territory-editor-visibility-fix.md)
- [局域网多人大厅与准备同步](memory/2026-08-24-lan-multiplayer-lobby.md)
- [局域网错误密码弹窗修复](memory/2026-08-24-lan-password-error-dialog.md)
- [权威领地同步、战争迷雾与树人编队](memory/2026-08-24-authoritative-gameplay-fog-treant.md)
- [单位单选强类型数组修复](memory/2026-08-24-unit-selection-typed-array-fix.md)
- [基地 UI 跟随、A* 寻路与树人卡牌](memory/2026-08-24-base-ui-astar-treant-card.md)
- [九级基地召唤、卡牌招募与稀有矿物](memory/2026-08-24-base-progression-rare-minerals.md)
- [百万格世界、人机、机器升级与探索者扩张](memory/2026-08-24-large-world-ai-machine-explorer.md)
- [区块资源流送、迷雾实体裁剪与纯战斗召唤池](memory/2026-08-24-resource-streaming-fog-summon.md)
- [不可取消召唤、共享战斗组件与建筑工人](memory/2026-08-25-combat-builder-structures.md)
- [高清卡牌立绘与建筑选择美化](memory/2026-08-25-card-art-ui-polish.md)
- [编辑器重载矿物信号竞态修复](memory/2026-08-25-editor-reload-mineral-signal-fix.md)
- [本地视角阵营着色规则](memory/2026-08-25-local-faction-tints.md)
- [公平视野人机与四档难度](memory/2026-08-26-fair-ai-difficulty.md)
- [灵活战斗、技能平衡与范围特效](memory/2026-08-26-combat-skills-vfx.md)
- [玩家指令优先、指定集火与全图资源寻路](memory/2026-08-26-player-command-resource-pathfinding.md)
- [百分比采集、就近资源分配与稳定A星寻路](memory/2026-08-27-percentage-harvest-astar.md)
- [图片序列帧战斗特效](memory/2026-08-27-image-sequence-combat-vfx.md)
- [单格单位共享卡牌与世界美术](memory/2026-08-27-shared-card-world-unit-art.md)
- [共享卡图攻击缩放修复](memory/2026-08-27-card-world-scale-attack-fix.md)
- [树人范围治疗与治疗光环](memory/2026-08-27-treant-area-healing-aura.md)
- [鼠标滚轮视角缩放](memory/2026-08-27-camera-wheel-zoom.md)
- [基地选址内嵌确认与键盘微调](memory/2026-08-27-base-placement-inline-confirmation.md)
- [资源闭环、英雄台与野怪](memory/2026-08-28-resource-loop-hero-altar-wild-monster.md)
- [开发者无限资源模式](memory/2026-08-28-developer-infinite-resources.md)
- [建筑工人寻路施工与 ImageGen 独立建筑美术](memory/2026-08-28-builder-walk-construction-imagegen-buildings.md)
- [基地五卡召唤、战斗开箱与建筑红绿预览](memory/2026-08-28-base-summon-chest-combat-build-preview.md)
- [指定开箱与建筑交互回归修复](memory/2026-08-29-chest-building-interaction-regression.md)
- [高清原图直用、生产资源图标与独立英雄召唤面板](memory/2026-08-29-direct-art-hero-summon-panel.md)
- [孔夫子四技能实装与 ImageGen 特效](memory/2026-08-29-confucius-skills-vfx.md)
- [孔夫子底部技能栏与 QWE 输入修复](memory/2026-08-29-confucius-bottom-skill-hud-input-fix.md)
- [技能图标径向冷却遮罩](memory/2026-08-29-radial-skill-cooldown-mask.md)
- [孔夫子受术对象归属特效](memory/2026-08-29-confucius-target-owned-vfx.md)

## 维护规则

- 只有在开发过程中确实产生记忆，或用户明确要求更新记忆时，才创建新的文档；不要预先创建模板文件。
- 每次更新记忆时，原则上新增一个独立文档，不覆盖已有历史记忆。
- 命名格式统一为 `YYYY-MM-DD-简短主题.md`，日期使用创建日期，主题使用小写英文 kebab-case，简洁描述本次修改，例如 `memory/2026-08-22-player-data-save.md`。
- 文件名不要使用空格、特殊符号或过长描述；同一天的不同记忆通过不同主题区分。
- 每份记忆必须精炼写清楚本次修改做了什么，并记录必要的影响范围和验证方式。
- 记忆内容使用事实描述；不确定内容先不要写入长期记忆。
- 记忆数量增多后，可以使用 `memory/` 子目录分类，但必须在此处增加对应索引。
- 新建、重命名、移动或删除记忆文档时，必须同步更新本索引。
- 不要删除历史记忆；如果内容失效，创建新记忆说明替代关系，并更新索引。

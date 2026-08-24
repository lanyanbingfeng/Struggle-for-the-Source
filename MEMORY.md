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

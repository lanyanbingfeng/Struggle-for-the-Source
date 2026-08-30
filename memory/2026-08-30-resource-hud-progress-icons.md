# 左上角进度资源独立图标

## 正式资源

- 召唤符、技能经验和经验分别使用独立的高清透明 PNG：
  - `art/ui/resource_icons/resource_summon_token.png`
  - `art/ui/resource_icons/resource_skill_experience.png`
  - `art/ui/resource_icons/resource_experience.png`
- 三张图标均保留 ImageGen 生成的原始高清尺寸，通过 Godot UI 等比缩放到 `20×20` 显示，不制作缩小副本。

## 使用范围

- 三张图标只由 `game/ui/resource_hud.gd` 的 `RESOURCE_ICONS` 映射加载，用于左上角资源 HUD。
- 召唤符使用金橙色召唤令牌，技能经验使用青蓝色技能结晶，普通经验使用绿色成长精华，以小尺寸颜色和轮廓区分。
- 未把这三张图标接入世界实体、卡牌、待收货气泡或其他面板。

## 验证

- 三张源文件均为带透明通道的 RGBA PNG，四角 alpha 为 0；Godot 4.7.2 已生成对应 `.png.import` 并可完成脚本预载。
- 全项目路径搜索确认代码引用仅存在于 `game/ui/resource_hud.gd`。
- MCP 启动主场景已越过资源预载和 HUD 脚本解析；当前项目仍会报告与本次改动无关的 `canvas_world_upgrade_vfx.gdshader` 内置 `PI` 重定义错误。

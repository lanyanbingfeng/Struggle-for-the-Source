# 开始界面与游戏菜单

- 修改内容：新增全屏开始界面、游戏内 Esc 菜单、设置/关于说明弹窗，以及单人/多人启动入口；新增像素风开始界面背景。
- 影响范围：`main_menu.gd`、`main_menu.tscn`、`pause_menu.gd`、`pause_menu.tscn`、`map_demo.gd`、`main.tscn`、`art/ui/main_menu_background.png`。
- 使用约定：单人模式打开游戏菜单时暂停 SceneTree；多人模式只覆盖菜单而不暂停世界；返回主菜单会清理单位、重置资源、重生树木并复位相机。
- 验证方式：使用 Godot 4.7.1 运行项目，实测开始界面按钮、Esc 开关菜单、两种模式状态文字、设置弹窗、Esc 关闭弹窗和返回主菜单路径均正常，调试输出无错误。

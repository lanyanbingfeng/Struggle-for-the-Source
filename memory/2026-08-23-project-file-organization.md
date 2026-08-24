# 项目文件目录整理

- 修改内容：将原本平铺在项目根目录的玩法场景、脚本和运行时资源移动到 `game/`，并按 `main`、`ui`、`world`、`units`、`systems` 功能域分类。
- 路径约定：主场景为 `res://game/main/main.tscn`；场景与其直接关联的脚本优先放在同一功能目录；美术、文档和项目记忆继续分别放在 `art/`、`docs/`、`memory/`。
- 兼容处理：同步更新 `project.godot`、场景外部资源路径、脚本 `preload()` 路径和 README 结构说明，脚本 `.uid` 文件与脚本一同移动；通过 Godot 4.7.1 的 `--import` 流程重建移动后的 UID 缓存。
- 验证方式：使用 Godot 4.7.1 MCP 启动主项目，确认所有资源可加载且调试输出无错误或警告。

# 争源项目开发规范

## 项目记忆系统

- 开始任何任务前，必须先阅读项目根目录的 `MEMORY.md`。
- 根据当前任务，从 `MEMORY.md` 中选择并阅读相关的记忆文档；不要默认读取整个 `memory/` 目录。
- 当用户要求“根据你的修改，更新记忆”时，按照 `MEMORY.md` 中的维护规则创建并登记记忆。
- 记忆文档只记录已经确认的项目事实、决策和可复用经验，不记录临时猜测。
- 完成功能、修复 Bug 或改变架构后，必须告诉用户新增或更新了哪些记忆文档，以及如何验证。

## 项目级 Godot Skill 使用规范

- 项目级 Skill 安装在 `D:/GodotProjects/争源/.codex/skills/`，优先使用这里的 Skill，不要求也不应为了本项目任务安装到全局目录。
- 遇到 Godot 相关问题时，应根据任务适当使用对应 Skill；不能因为问题看起来简单就默认跳过相关 Skill。使用前先读取对应目录中的完整 `SKILL.md`，必要时再读取它引用的参考文档。
- 通用 Godot 引擎问题、场景/节点架构、信号、Resource、Autoload、项目设置和导出配置：使用 `godot`。
- `.gd` 文件编写、审查、静态类型、协程、状态机、信号设计和 GDScript 性能：使用 `godot-gdscript`。
- C# 脚本、`partial class`、Signal delegate、异步代码、`.csproj` 或 NuGet：使用 `godot-csharp`。
- C++/Rust GDExtension、godot-cpp、godot-rust、原生节点和计算热点优化：使用 `godot-gdextension`。
- `.gdshader`、Visual Shader、材质、粒子、后处理和渲染管线：使用 `godot-shader`。
- 一个任务涉及多个领域时，可以组合使用多个相关 Skill；没有相关内容时不要为了形式强行加载无关 Skill。
- Skill 文档中的版本说明是参考依据，不替代项目实际配置。本项目当前以 `project.godot` 的 Godot 4.7、Mobile 渲染配置和现有插件配置为最终事实；发现 Skill 示例与项目版本不一致时，必须先核对 API 和项目运行结果。
- 使用 Skill 后，在操作报告中说明使用了哪些 Skill，以及它们如何影响方案、代码或验证方式。

## 2D 资源生成规范

- 生成或修改任何 Ground、Resource、Decoration、Structure、Unit、Transition 或其他像素美术资源前，必须先阅读项目内的 [docs/asset-generation-spec.md](docs/asset-generation-spec.md)，并将其作为当前项目的默认生成规范。
- 默认使用 32×32 Tile 网格；1×1 资源必须原生按 32×32 设计，禁止把复杂的 64×64 或 AI 大图直接缩小后作为 32×32 正式资源。
- 生成提示词必须明确逻辑占地、最终文件尺寸、透明度要求、正交俯视角、左上光源和硬像素边缘；AI 预览画布尺寸不代表最终游戏尺寸。
- 生成后必须检查最终 PNG 尺寸、RGBA/透明度、100% 原始尺寸可读性和 Godot 导入设置。若缩小后细节丢失，应重画轮廓或减少细节，不得继续依赖重复缩放。
- 视觉尺寸可以大于碰撞尺寸，但必须在任务中明确记录两者；Sprite 不得通过运行时缩放来弥补错误资源尺寸。

## Godot MCP 优先

- 涉及 Godot 编辑器、场景、节点、资源、脚本调试、运行状态或编辑器输出的操作，优先使用已连接的 Godot MCP Server。
- 当前使用 `@coding-solo/godot-mcp` 的 stdio MCP 服务，由 Codex 通过 `npx.cmd --yes @coding-solo/godot-mcp` 启动。
- Codex 配置中的 `GODOT_PATH` 指向 `C:\Users\ZhuanZ\Desktop\Godot_v4.7.1-stable_win64.exe`。
- 该服务通过 Godot CLI 启动、运行和检查项目，不依赖旧的 GodotMCP 编辑器插件面板。
- 能通过 MCP 完成的操作，不要改用模拟鼠标键盘或绕过 Godot 编辑器的方式完成。
- 普通代码阅读、文本搜索和版本控制检查可以直接使用本地文件工具；涉及 Godot 编辑器状态时仍以 MCP 返回结果为准。

## MCP 连接失败时

如果 Godot MCP 工具不可用、请求失败或返回连接错误：

1. 检查 Godot 是否正在运行并打开本项目 `D:/GodotProjects/争源`。
2. 检查 Codex 全局 MCP 配置中的 `godot_mcp` 是否使用 `npx.cmd` 和 `@coding-solo/godot-mcp`。
3. 检查 `GODOT_PATH` 是否指向有效的 Godot 可执行文件。
4. 检查 Node.js/npm 是否可用，必要时重新启动该 stdio MCP 服务。
5. 重启 Codex 客户端后重试一次 MCP 请求。

如果仍然无法连接，必须先告诉用户：

- 具体失败原因和已完成的检查；
- 建议的修复方式或需要用户手动开启的服务；
- 在用户确认或服务恢复前，不要假装已经通过 MCP 完成操作。

## Git 与远程仓库操作

- 不得擅自向 Git 仓库上传、推送或同步任何内容。
- 只有用户明确说明需要提交、上传或推送时，才允许执行对应的 Git 远程操作；“完成任务”“保存修改”或“整理代码”不等同于授权推送。
- 未获得明确授权时，可以进行只读的状态、日志和差异检查，但不得执行 `git push`、远程上传或其他会改变远程仓库状态的命令。
- 如果用户明确要求推送，执行前仍需说明目标远程仓库、分支和将要推送的范围；若信息不完整，先向用户确认。

## 操作报告

- 每次使用 MCP 修改或控制 Godot 后，说明实际调用结果。
- 如果进行了配置修复或启动服务，说明修改位置、启动方式，以及是否需要重启 Godot 或 Codex。
- 涉及可能修改项目文件的操作，完成后说明用户如何验证结果。

# 伐木机器最终尺寸决定

- 背景：对比 32×32 与 64×64 伐木机器后，确认缩放 64×64 会破坏像素点与项目规范的一致性。
- 最终决定：使用原生 32×32 的 `art/resources/resource_lumber_machine_1x1.png`，作为 1×1 Tile 伐木机器；不采用 64×64 视觉版本。
- 已删除：`art/generated/resource_lumber_machine_visual_2x2.png`。
- 使用约定：Sprite 保持原始尺寸显示，不再二次缩放；Godot 导入关闭 Filter、Mipmaps，使用 Nearest，Repeat 关闭。
- 验证方式：确认 64×64 文件已删除，32×32 资源仍保留。

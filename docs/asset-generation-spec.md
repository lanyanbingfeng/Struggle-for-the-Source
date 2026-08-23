# 争源资源生成规范 v2.0

适用：Godot 4.x、2D 像素风、正交俯视角资源。

本文件是项目内生成 Ground、Resource、Decoration、Structure 和 Unit 资源的执行规范。原始参考文档为《争源_瓦片资源统一生成规范_v1.1.md》；本版本将其整理为可直接执行的规则，并补充 32×32 小资源的可读性要求。

## 一、不可违背的硬规则

1. 基础网格固定为 `1 Tile = 32×32 px`。
2. 最终 PNG 文件尺寸必须等于实际视觉占地尺寸：`宽 Tile 数 × 32`、`高 Tile 数 × 32`。
3. 1×1 资源必须原生按 32×32 设计；禁止把复杂的 64×64 或 1024×1024 资源直接缩小后当作 32×32 正式资源。
4. 最终资源禁止使用 Bilinear、Bicubic、Lanczos；需要重采样时只使用 Nearest Neighbor。
5. 所有资源必须使用同一套低分辨率像素颗粒，不得出现柔边、抗锯齿、半透明脏边或白边。
6. 所有资源采用正交俯视角，不使用等距、透视、斜侧视或 3D 渲染感。
7. 统一左上光源：左上亮、右下暗；阴影使用离散硬像素，不使用模糊软阴影。
8. 基础地面不透明并填满画布；物体、建筑、单位和装饰使用真正的 RGBA 透明背景。
9. 不出现文字、UI、编号、水印、边框或无关场景。
10. AI 预览画布只是工作中间图，不能作为最终游戏资源直接使用。

## 二、风格基准

- 明亮、自然、低噪点、轻奇幻、易读。
- 颜色使用明确色阶，不使用大量相近颜色。
- Ground 使用中等饱和度，Resource、Unit 和重要交互对象可略高饱和。
- 轮廓使用深色同色系，不使用粗纯黑描边。
- 优先大轮廓和大色块，细节必须服务于小尺寸识别。
- 基础地图自然元素约占 80%，奇幻元素约占 20%。

## 三、尺寸和视觉占地

| 逻辑占地 | 最终文件尺寸 | 适用示例 |
|---|---:|---|
| 1×1 | 32×32 | 草地、单格矿石、单格机器、单位基础 Sprite |
| 1×2 | 32×64 | 高装饰、部分树木 |
| 2×1 | 64×32 | 横向装饰、桥段 |
| 2×2 | 64×64 | 大树、中型矿石、小型建筑 |
| 3×3 | 96×96 | 主基地、大型资源点 |
| 4×4 | 128×128 | 大型基地、Boss 建筑 |

视觉尺寸可以大于碰撞尺寸，但必须在任务中明确写出两者。例如：树视觉 64×64，树根碰撞 32×32；不能把视觉尺寸与逻辑尺寸混淆。

重要：如果资源最终要以 32×32 显示，就必须直接按 32×32 的像素画设计；不得先制作 64×64 再缩小。若需要更多细节，应扩大视觉占地，而不是缩小后强行塞回 1×1。

## 四、1×1 小资源专用规则

1×1 资源在原始 32×32 尺寸下必须一眼可认：

- 主体有效轮廓约占画布 75%–90%，四周只留必要透明边。
- 最多保留 2–4 个识别重点；例如伐木机器只保留锯片、车体、机械臂和木材仓。
- 每个重要部件至少形成连续的 2–3 像素色块，不能依赖 1 像素微纹理表达。
- 颜色优先使用大色块和强明暗对比，避免复杂渐变。
- 删除螺丝、细密履带纹、细小高光、真实裂纹等缩小后会变成噪点的细节。
- 输出后必须在 100% 原始尺寸检查，不得只看 AI 大图或放大预览。

## 五、各类资源规则

### Ground

- 32×32、不透明、四边无缝、低信息密度。
- 基础色约 70%–80%，暗色 10%–20%，亮色 5%–10%。
- 不放大型植物、独立石块、建筑、角色或固定中心图案。
- Grass 至少规划 A/B/C 三个可互换变体，变化只放在内部细节，边缘必须一致。
- 花、草簇、石子、蘑菇、树枝等放在 Decoration Layer，不画死在基础地面中。

### Resource / Decoration / Unit / Structure

- 使用透明 RGBA PNG，边缘必须是完整像素。
- 主体必须居中并明确底部定位点；树、建筑和单位建议 Pivot 在底部中心。
- 轮廓、主色、阴影和高光必须在 100% 尺寸仍然可区分。
- 需要视觉覆盖邻近 Tile 时，明确写出视觉尺寸与碰撞尺寸；Y-Sort 资源要保留清晰根部或底部。

### Transition / Water

- Transition 单独制作，不让 Grass 与 Dirt、Water 等直接形成生硬直线。
- 需要制作上、下、左、右、内角、外角和特殊连接情况。
- Water 基础帧每帧 32×32，四边无缝；动画建议 4 帧、4–8 FPS，颜色不要明显闪烁。

## 六、统一 AI 提示词模板

生成前必须明确逻辑占地和最终尺寸。透明物体使用以下模板改写：

```text
Create a game-ready 2D pixel-art [asset] for Godot 4.

Logical footprint: [W]x[H] tiles.
Final in-game resolution: [W*32]x[H*32] pixels.
Design directly for the final native pixel resolution; do not create finer detail than the existing 32x32 grass tile.

Orthographic top-down view, bright fantasy natural style, clean readable silhouette,
consistent low-resolution pixel scale, crisp hard pixel edges, no anti-aliasing.
Upper-left lighting, lower-right discrete pixel shadow if needed.
Transparent RGBA background, no text, no UI, no watermark, no border,
no perspective, no isometric view, no 3D render, no smooth shading, no painted texture.
Prioritize large readable shapes and clear color blocks at 100% native size.
```

Ground 额外加入：

```text
Opaque edge-to-edge square tile, seamless on all four edges,
must tile naturally in a 5x5 grid, no large center object, no external shadow.
```

## 七、生成后处理流程

```text
明确逻辑占地与最终尺寸
↓
生成 AI 预览
↓
检查视角、构图和主体识别度
↓
按目标尺寸用 Nearest Neighbor 重采样，或直接进行原生像素绘制
↓
清理抗锯齿、半透明边缘、白边和黑边
↓
检查透明度与文件尺寸
↓
在 100% 原始尺寸查看
↓
Ground 做 5×5 平铺测试；物体与草地做同场景比例测试
↓
导入 Godot
```

如果重采样后主体识别度下降，不能继续反复缩放；应回到生成或像素修整阶段，减少细节并重画轮廓。

## 八、Godot 导入配置

- Pixel Art 纹理：Filter 关闭、Mipmaps 关闭、Repeat 按用途配置。
- Ground Tile：可按平铺需要开启 Repeat。
- Sprite、Resource、Unit、Structure：Repeat 关闭。
- Sprite 默认保持原始尺寸显示；不要通过运行时缩放修复错误的像素尺寸。
- 逻辑碰撞、视觉尺寸和 Pivot 分开配置，并在场景中叠加 32×32 网格验证。

## 九、最终验收清单

- [ ] 文件尺寸等于逻辑占地 × 32。
- [ ] 1×1 资源是否原生按 32×32 设计，而非复杂大图缩小？
- [ ] 100% 原始尺寸下主体是否一眼可认？
- [ ] 像素颗粒是否与草地一致？
- [ ] 是否正交俯视、左上光源、右下硬阴影？
- [ ] 是否没有抗锯齿、模糊、白边、黑边和半透明脏边？
- [ ] 透明资源是否真正透明，Ground 是否完全不透明？
- [ ] Ground 是否通过 5×5 平铺测试？
- [ ] 是否没有文字、UI、水印和多余场景？
- [ ] Godot 是否关闭 Filter 和 Mipmaps，并正确设置 Repeat？
- [ ] 视觉尺寸与碰撞尺寸是否分别明确？


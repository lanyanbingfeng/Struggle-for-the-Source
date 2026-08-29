# 高清原图直用、生产资源图标与独立英雄召唤面板

## 已确认决策

- `docs/asset-generation-spec.md` 已升级为 v4.0：后续新生成及玩家指定的美术直接使用原始高清 PNG，不再默认要求像素风、占地×32 文件尺寸、硬像素边缘或 Nearest 重采样。
- `1 Tile = 32×32` 只用于逻辑占地、碰撞、寻路和距离；视觉纹理由 Godot 节点等比缩放，默认使用 Linear 过滤。
- 同一主体在卡牌、世界、HUD 和建筑气泡中的不同显示尺寸不再通过复制缩小文件实现，而是共享正式高清纹理。

## 正式资源

- 玩家提供的金币图标直接保存为 `art/ui/resource_icons/resource_gold.png`。
- ImageGen 生成的木头、石头、铁图标分别保存为：
  - `art/ui/resource_icons/resource_wood.png`
  - `art/ui/resource_icons/resource_stone.png`
  - `art/ui/resource_icons/resource_iron.png`
- 玩家提供的孔夫子美术直接保存为 `art/units/confucius_card.png`；`confucius_definition.tres` 的卡牌与 `confucius_hero.tscn` 的世界 Sprite 共享该纹理。
- 四种生产资源图标由 `ResourceHUD` 和 `ProductionBuilding` 的待收货气泡共同复用；气泡只显示资源图标和数量，不再依赖文字字形代替图标。

## 英雄台交互

- 英雄台不再打开基地战斗单位使用的 `SummonCardMenu`。
- 点击己方已完成英雄台会打开独立 `HeroSummonPanel`，面板数据从 `UnitCatalog.hero_pool` 动态生成，当前显示孔夫子卡牌，后续新增英雄可继续加入同一面板。
- 面板选择英雄后仍沿用房主权威的英雄台召唤请求；首次召唤消耗 2 张召唤符，替换存活英雄消耗 1 张。

## 验证

- 四张资源图标和孔夫子图片均已确认是带透明通道的高清 PNG，并由 Godot 成功导入。
- 使用 Godot 4.7.2 启动主场景，确认新增场景、脚本和纹理可加载，调试输出无脚本解析或资源加载错误。

## 替代关系

- 本记忆中的 v4.0 美术规则替代旧记忆里将像素风、原生 32×32 或占地×32 作为后续资源默认要求的部分；历史资源无需批量返工。

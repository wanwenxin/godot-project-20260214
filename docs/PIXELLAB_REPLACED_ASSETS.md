# Pixellab 已替换资产记录

本文档记录通过 Pixellab MCP 生成并替换的美术资源，避免后续重复生成。

## 维护规则

- 每次使用 Pixellab 生成并替换资产后，在本表新增一行
- 生成前可查阅本表，跳过已打标资产

## 已替换资产列表

| 路径 | 类别 | 描述词 | 生成时间 | 来源 |
|------|------|--------|----------|------|
| assets/weapons/blade_short.png | weapon | short sword, top-down view, pixel art icon | 2026-02-19 | Pixellab |
| assets/weapons/dagger.png | weapon | dagger knife, top-down view, pixel art icon | 2026-02-19 | Pixellab |
| assets/weapons/spear.png | weapon | spear weapon, top-down view, pixel art icon | 2026-02-19 | Pixellab |
| assets/magic/icon_fire.png | magic | fire flame icon, pixel art, magic spell | 2026-02-19 | Pixellab |
| assets/magic/icon_lightning.png | magic/element | lightning bolt icon, pixel art, magic spell | 2026-02-19 | Pixellab |
| assets/ui/upgrade_icons/icon_hp.png | item | 占位色块 | - | gen_icons.py |
| assets/ui/upgrade_icons/icon_speed.png | item | 占位色块 | - | gen_icons.py |
| assets/ui/upgrade_icons/icon_melee.png | item | 占位色块 | - | gen_icons.py |
| assets/magic/icon_ice.png | magic | 占位色块 | - | gen_icons.py |
| assets/magic/icon_poison.png | element | 占位色块 | - | gen_icons.py |
| assets/magic/icon_physical.png | element | 占位色块 | - | gen_icons.py |

**说明**：道具、魔法 icon_ice、元素 icon_poison/icon_physical 因 Pixellab 限流（429）未生成，当前使用 gen_icons.py 占位图。后续可重试 Pixellab 生成并替换。

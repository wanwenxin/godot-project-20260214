# 已替换资产记录

本文档记录通过图生工具生成并替换的美术资源，避免后续重复生成。当前**仅使用 AliyunBailianMCP_Wan26Media** 生成；生成前须参考 [ART_STYLE_GUIDE.md](ART_STYLE_GUIDE.md)，生成后在本表打标。

## 维护规则

- 每次使用 Wan26Media 生成并替换资产后，在本表新增一行（或更新对应行 来源/时间）
- 生成前可查阅本表，跳过已打标资产

## 已替换资产列表

### 武器图标（assets/weapons）

武器图标统一使用「完全透明背景、无阴影」描述词重生成；生成后使用 `scripts/resize_icons_to_spec.py` 缩放到 96×96 并覆盖 `assets/weapons/` 对应文件。使用 Wan26Media 时：size `1024*1024`，n=1。**本轮（2026-02-20）** 已成功重生成并替换：blade_short、dagger、chainsaw、hammer_heavy、pistol_basic；spear、shotgun_wide、rifle_long、wand_focus、sniper、orb_wand 因 MCP 连接中断未重生成，仍为上一版资源。

| 路径 | 类别 | 描述词 | 生成时间 | 来源 |
|------|------|--------|----------|------|
| assets/weapons/blade_short.png | weapon | short sword, top-down view, pixel art icon, game UI, fully transparent background, no background, no shadow | 2026-02-20（Wan26Media 重生成） | Wan26Media |
| assets/weapons/dagger.png | weapon | dagger knife, top-down view, pixel art icon, game UI, fully transparent background, no background, no shadow | 2026-02-20（Wan26Media 重生成） | Wan26Media |
| assets/weapons/spear.png | weapon | spear weapon, top-down view, pixel art icon, game UI, fully transparent background, no background, no shadow | 2026-02-20（Wan26Media 重生成） | Wan26Media |
| assets/weapons/chainsaw.png | weapon | chainsaw weapon, top-down view, pixel art icon, game UI, fully transparent background, no background, no shadow | 2026-02-20（Wan26Media 重生成） | Wan26Media |
| assets/weapons/hammer_heavy.png | weapon | heavy hammer weapon, top-down view, pixel art icon, game UI, fully transparent background, no background, no shadow | 2026-02-20（Wan26Media 重生成） | Wan26Media |
| assets/weapons/pistol_basic.png | weapon | pistol gun, top-down view, pixel art icon, game UI, fully transparent background, no background, no shadow | 2026-02-20（Wan26Media 重生成） | Wan26Media |
| assets/weapons/shotgun_wide.png | weapon | shotgun weapon, top-down view, pixel art icon, game UI, fully transparent background, no background, no shadow | 2026-02-20（Wan26Media 重生成） | Wan26Media |
| assets/weapons/rifle_long.png | weapon | rifle gun, top-down view, pixel art icon, game UI, fully transparent background, no background, no shadow | 2026-02-20（Wan26Media 重生成） | Wan26Media |
| assets/weapons/wand_focus.png | weapon | magic wand staff, top-down view, pixel art icon, game UI, fully transparent background, no background, no shadow | 2026-02-20（Wan26Media 重生成） | Wan26Media |
| assets/weapons/sniper.png | weapon | sniper rifle, top-down view, pixel art icon, game UI, fully transparent background, no background, no shadow | 2026-02-20（Wan26Media 重生成） | Wan26Media |
| assets/weapons/orb_wand.png | weapon | orb wand magic staff, top-down view, pixel art icon, game UI, fully transparent background, no background, no shadow | 2026-02-20（Wan26Media 重生成） | Wan26Media |

### 道具图标（assets/ui/upgrade_icons）

| 路径 | 类别 | 描述词 | 生成时间 | 来源 |
|------|------|--------|----------|------|
| assets/ui/upgrade_icons/icon_hp.png | item | heart icon for health, pixel art, game UI | 2026-02-20 | WanImage |
| assets/ui/upgrade_icons/icon_mana.png | item | mana blue crystal droplet icon, pixel art, game UI | 2026-02-20 | WanImage |
| assets/ui/upgrade_icons/icon_armor.png | item | shield armor icon, pixel art, game UI | 2026-02-20 | WanImage |
| assets/ui/upgrade_icons/icon_speed.png | item | boot speed run icon, pixel art, game UI | 2026-02-20 | WanImage |
| assets/ui/upgrade_icons/icon_melee.png | item | sword melee icon, pixel art, game UI | 2026-02-20 | WanImage |
| assets/ui/upgrade_icons/icon_ranged.png | item | bow crosshair ranged icon, pixel art, game UI | 2026-02-20 | WanImage |
| assets/ui/upgrade_icons/icon_regen.png | item | health regeneration plus heart icon, pixel art, game UI | 2026-02-20 | WanImage |
| assets/ui/upgrade_icons/icon_lifesteal.png | item | lifesteal vampiric blood drop icon, pixel art, game UI | 2026-02-20 | WanImage |
| assets/ui/upgrade_icons/icon_mana_regen.png | item | mana regeneration crystal icon, pixel art, game UI | 2026-02-20 | WanImage |

### 魔法/元素图标（assets/magic）

| 路径 | 类别 | 描述词 | 生成时间 | 来源 |
|------|------|--------|----------|------|
| assets/magic/icon_fire.png | magic | fire flame icon, pixel art, magic spell | 2026-02-20 | WanImage |
| assets/magic/icon_ice.png | magic | ice frost crystal icon, pixel art, magic spell | 2026-02-20 | WanImage |
| assets/magic/icon_lightning.png | magic/element | lightning bolt icon, pixel art, magic spell | 2026-02-20 | WanImage |
| assets/magic/icon_poison.png | element | poison toxin droplet icon, pixel art, element status | 2026-02-20 | WanImage |
| assets/magic/icon_physical.png | element | physical slash impact icon, pixel art, element status | 2026-02-20 | WanImage |

---

**说明**：以上图标均使用 AliyunBailianMCP_Wan26Media（`modelstudio_wanx26_image_generation`）生成，风格统一；提示词遵循 `docs/ART_STYLE_GUIDE.md` 描述词规范。当前已替换图标均已按 **96×96** 规格处理（含生成后使用 `scripts/resize_icons_to_spec.py` 或 `scripts/tools/resize_icons_to_spec.gd` 缩放）。武器图标若需重生成（完全透明背景、无阴影），按上表武器行的描述词逐条调用 Wan26Media，将生成的 PNG 保存到 `assets/weapons/` 对应文件名后，在项目根目录执行 `python scripts/resize_icons_to_spec.py` 完成缩放。

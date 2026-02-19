# 美术风格指南

本文档记录项目自动生成美术资源的风格规范，以 Pixellab 生成的文件为参考，保证新生成资源与现有资产的一致性。

---

## 一、参考资产（Pixellab 已生成）

| 路径 | 类别 | 描述词 |
|------|------|--------|
| assets/weapons/blade_short.png | 武器 | short sword, top-down view, pixel art icon |
| assets/weapons/dagger.png | 武器 | dagger knife, top-down view, pixel art icon |
| assets/weapons/spear.png | 武器 | spear weapon, top-down view, pixel art icon |
| assets/magic/icon_fire.png | 魔法 | fire flame icon, pixel art, magic spell |
| assets/magic/icon_lightning.png | 魔法/元素 | lightning bolt icon, pixel art, magic spell |

生成新资源前，**务必查看上述文件**以把握视觉风格。

---

## 二、各类美术资源规格

### 2.1 武器图标

| 项目 | 要求 |
|------|------|
| **尺寸** | 96×96 像素 |
| **格式** | PNG，支持透明通道 |
| **路径** | `assets/weapons/*.png` |
| **视角** | 高位俯视（high top-down），适合 UI 展示 |
| **其他** | 透明背景；引用见 `weapon_defs.gd` 的 `icon_path` |

### 2.2 武器挥击图（近战）

| 项目 | 要求 |
|------|------|
| **尺寸** | 24×8 像素 |
| **格式** | PNG，支持透明通道 |
| **路径** | `assets/weapons/swing_*.png` |
| **其他** | 挥击轨迹/弧光；引用见 `weapon_defs.gd` 的 `swing_texture_path` |

### 2.3 道具图标

| 项目 | 要求 |
|------|------|
| **尺寸** | 96×96 像素 |
| **格式** | PNG，支持透明通道 |
| **路径** | `assets/ui/upgrade_icons/icon_*.png` |
| **视角** | 高位俯视或正面，适合 UI 图标 |
| **其他** | 透明背景；引用见 `shop_item_defs.gd`、`upgrade_defs.gd` 的 `icon_path` |

### 2.4 魔法图标

| 项目 | 要求 |
|------|------|
| **尺寸** | 96×96 像素 |
| **格式** | PNG，支持透明通道 |
| **路径** | `assets/magic/icon_*.png` |
| **视角** | 高位俯视或正面，适合魔法/元素表现 |
| **其他** | 透明背景；引用见 `magic_defs.gd`、`shop_item_defs.gd`、`enemy_base.gd` |

### 2.5 元素状态图标

| 项目 | 要求 |
|------|------|
| **尺寸** | 96×96 像素（显示时按 `ELEMENT_ICONS_SCALE` 缩放为小图标） |
| **格式** | PNG，支持透明通道 |
| **路径** | `assets/magic/icon_fire.png`、`icon_ice.png`、`icon_lightning.png`、`icon_poison.png`、`icon_physical.png` |
| **其他** | 透明背景；引用见 `enemy_base.gd` 的 `_get_element_icon_texture` |

### 2.6 角色精灵

| 项目 | 要求 |
|------|------|
| **单帧尺寸** | 24×24 像素 |
| **精灵图尺寸** | 192×72（8 列 × 3 行） |
| **格式** | PNG，支持透明通道 |
| **路径** | `assets/characters/player_scheme_*.png`、`*_sheet.png` |
| **结构** | 8 列 × 3 行（站立、行走帧1、行走帧2），方向顺序 E, SE, S, SW, W, NW, N, NE |

### 2.7 敌人精灵

| 项目 | 要求 |
|------|------|
| **单帧尺寸** | 18×18 像素 |
| **精灵图尺寸** | 144×54（8 列 × 3 行） |
| **格式** | PNG，支持透明通道 |
| **路径** | `assets/enemies/enemy_*.png`、`*_sheet.png` |
| **结构** | 8 列 × 3 行（站立、行走帧1、行走帧2） |

### 2.8 子弹与掉落

| 类型 | 纹理尺寸 | 格式 | 路径 | 其他 |
|------|----------|------|------|------|
| 枪械子弹 | 4×4（基准） | PNG | `assets/bullets/bullet_firearm.png` | 透明背景；pistol 4×4、shotgun 6×6、rifle 8×2 显示时按类型缩放 |
| 激光子弹 | 12×2 | PNG | `assets/bullets/bullet_laser.png` | 透明背景 |
| 法球子弹 | 8×8 | PNG | `assets/bullets/bullet_orb.png` | 透明背景 |
| 金币 | 8×8 | PNG | `assets/pickups/coin.png` | 透明背景 |
| 治疗 | 8×8 | PNG | `assets/pickups/heal.png` | 透明背景 |

### 2.9 地形瓦片

| 项目 | 要求 |
|------|------|
| **尺寸** | 按 atlas 切分（如 64×64 单格） |
| **格式** | PNG，可无缝平铺 |
| **路径** | `assets/terrain/terrain_atlas.png` 等 |
| **其他** | 3 行 × 7 列（flat/seaside/mountain 地板） |

### 2.10 面板背景图（可选替换）

| 项目 | 要求 |
|------|------|
| **尺寸** | 48×48 或 64×64，九宫格切分 |
| **格式** | PNG |
| **边框区域** | expand_margin 6~8 像素，中间可拉伸 |
| **其他** | 当前由程序生成，若替换需与 `UiThemeConfig`、`StyleBoxTexture` 配置一致 |

### 2.11 通用要求

- **格式**：PNG，支持透明通道（RGBA），UI 图标与精灵图必须透明背景
- **风格**：像素风，边缘清晰，色块分明，非抗锯齿
- **命名**：与配置中的 `icon_path`、`texture_path` 等路径一致

---

## 三、Pixellab 生成参数（适用于武器/道具/魔法/元素图标）

为保证风格一致，所有通过 Pixellab `create_map_object` 生成的图标须使用以下参数：

| 参数 | 值 | 说明 |
|------|-----|------|
| width | 96 | 画布宽度（武器/道具/魔法/元素图标） |
| height | 96 | 画布高度 |
| view | `high top-down` | 高位俯视视角，适合 UI 图标 |
| outline | `single color outline` | 单色描边，轮廓清晰 |
| shading | `medium shading` | 中等阴影，有立体感 |
| detail | `medium detail` | 中等细节，避免过于复杂 |
| background_image | 不传 | Basic 模式，透明背景 |

**不传 `background_image`** 即使用 Basic 模式，生成独立对象，背景透明。

---

## 四、描述词（description）规范

### 4.1 格式

```
[主体描述], [视角], [风格], [用途]
```

- **主体描述**：具体对象（如 short sword、fire flame、heart icon）
- **视角**：top-down view（若与 view 参数一致可省略）
- **风格**：pixel art、pixel art icon
- **用途**：game UI、magic spell、element status

### 4.2 分类示例

| 类别 | 示例描述词 |
|------|------------|
| 武器 | `short sword, top-down view, pixel art icon, game UI` |
| 道具 | `heart icon for health, pixel art, game UI` |
| 魔法 | `fire flame icon, pixel art, magic spell` |
| 元素状态 | `lightning bolt icon, pixel art, element status` |

### 4.3 注意事项

- 描述词使用英文
- 保持简洁，避免过长
- 与参考资产的描述词风格一致

---

## 五、视觉特征（参考 Pixellab 输出）

- **像素风格**：边缘清晰，色块分明，非抗锯齿
- **透明背景**：无背景色，便于叠加到 UI
- **配色**：主体色明确，阴影与高光过渡自然
- **轮廓**：单色描边，与主体色区分
- **尺寸**：96×96 适用于武器/道具/魔法/元素图标；其他类型见上文「二、各类美术资源规格」

---

## 六、生成流程

1. **查阅** [PIXELLAB_REPLACED_ASSETS.md](PIXELLAB_REPLACED_ASSETS.md)，跳过已打标资产
2. **参考** 本文档的参考资产与参数
3. **调用** Pixellab MCP `create_map_object`，使用固定参数 + 对应描述词
4. **轮询** `get_map_object` 直至完成
5. **下载** PNG 并保存到 `assets/` 对应路径
6. **打标** 在 PIXELLAB_REPLACED_ASSETS 中新增记录

**失败处理**：若 Pixellab 调用失败（如限流 429），**仅提示哪些资产生成失败**，不调用其他接口（如 GenerateImage）替代生成。

---

## 七、维护

- 新增 Pixellab 生成资产后，若风格有显著变化，可更新本文档「参考资产」与「视觉特征」
- 参数变更时同步更新「Pixellab 生成参数」表

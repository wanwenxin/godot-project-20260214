# 美术资源替换指南

本文档说明如何替换地形、敌人、角色、武器、UI 的美术资源，包括所需资源规格、AI 生成建议及替换步骤。

---

## 一、当前资源架构概览

项目采用**双轨制**：

- **纹理路径**：`resources/texture_paths.tres` + `VisualAssetRegistry.get_texture()`
- **无纹理时**：优先使用 `PixelGenerator` 生成色块，或 `VisualAssetRegistry.make_color_texture()` 生成纯色贴图

若纹理文件存在且路径正确，则加载纹理；否则会 fallback 到运行时生成的色块。

---

## 二、所需美术资源清单

### 2.1 地形（Terrain）

地板优先使用 **TileMap** 像素图（`terrain_atlas.png`，3 行 x 7 列，含 flat/seaside/mountain 地板）；草/水/障碍等仍由 `terrain_colors.tres` 或 ColorRect 回退控制。

| 类型 | 用途 | 当前颜色 | 建议 |
|------|------|----------|------|
| floor_a | 地板棋盘格 A | 浅灰 | 可改为纹理贴图 |
| floor_b | 地板棋盘格 B | 稍深灰 | 可改为纹理贴图 |
| boundary | 边界 | 深灰 | 可改为纹理贴图 |
| obstacle | 障碍物 | 深灰黑 | 可改为纹理贴图 |
| grass | 草丛 | 半透明绿 | 可改为纹理贴图 |
| shallow_water | 浅水 | 半透明蓝 | 可改为纹理贴图 |
| deep_water | 深水 | 半透明深蓝 | 可改为纹理贴图 |

**若继续用纯色**：只需改 `terrain_colors.tres` 中的颜色值即可。

**若改为纹理**：需要修改 `game.gd` 中 `_spawn_walkable_floor`、`_spawn_terrain_zone`、`_spawn_obstacle`、`_spawn_boundary_body` 等，把 `ColorRect` 换成 `TextureRect` 或 `Sprite2D`，并增加纹理路径配置。

---

### 2.2 角色（Player）

| 资源 | 用途 | 尺寸 | 路径 | 格式 |
|------|------|------|------|------|
| player_scheme_0 | 角色 1 外观 | 24×24 | `res://assets/characters/player_scheme_0.png` | PNG |
| player_scheme_1 | 角色 2 外观 | 24×24 | `res://assets/characters/player_scheme_1.png` | PNG |
| player_scheme_0_sheet | 角色 1 8 方向精灵图 | 192×72 | `res://assets/characters/player_scheme_0_sheet.png` | PNG |
| player_scheme_1_sheet | 角色 2 8 方向精灵图 | 192×72 | `res://assets/characters/player_scheme_1_sheet.png` | PNG |

精灵图结构：8 列 × 3 行（站立、行走帧1、行走帧2），每格 24×24。方向顺序：E, SE, S, SW, W, NW, N, NE。

---

### 2.3 敌人（Enemies）

| 资源 | 用途 | 尺寸 | 路径 | 格式 |
|------|------|------|------|------|
| enemy_melee | 近战敌人 | 18×18 | `res://assets/enemies/enemy_melee.png` | PNG |
| enemy_ranged | 远程敌人 | 18×18 | `res://assets/enemies/enemy_ranged.png` | PNG |
| enemy_tank | 坦克敌人 | 18×18 | `res://assets/enemies/enemy_tank.png` | PNG |
| enemy_boss | Boss | 18×18 | `res://assets/enemies/enemy_boss.png` | PNG |
| enemy_aquatic | 水中敌人 | 18×18 | `res://assets/enemies/enemy_aquatic.png` | PNG |
| enemy_dasher | 冲刺敌人 | 18×18 | `res://assets/enemies/enemy_dasher.png` | PNG |
| enemy_*_sheet | 6 种敌人 8 方向精灵图 | 144×54 | `res://assets/enemies/enemy_*_sheet.png` | PNG |

精灵图结构：8 列 × 3 行（站立、行走帧1、行走帧2），每格 18×18。

---

### 2.4 武器图标与挥击图（Weapon Icons & Melee Swing）

| 资源 | 用途 | 建议尺寸 | 路径 | 格式 |
|------|------|----------|------|------|
| weapon_blade_short | 短刃 | 96×96 | `res://assets/weapons/blade_short.png` | PNG |
| weapon_hammer_heavy | 重锤 | 96×96 | `res://assets/weapons/hammer_heavy.png` | PNG |
| weapon_dagger | 刺刀 | 96×96 | `res://assets/weapons/dagger.png` | PNG |
| weapon_spear | 长矛 | 96×96 | `res://assets/weapons/spear.png` | PNG |
| weapon_chainsaw | 链锯 | 96×96 | `res://assets/weapons/chainsaw.png` | PNG |
| weapon_pistol_basic | 手枪 | 96×96 | `res://assets/weapons/pistol_basic.png` | PNG |
| weapon_shotgun_wide | 霰弹枪 | 96×96 | `res://assets/weapons/shotgun_wide.png` | PNG |
| weapon_rifle_long | 长步枪 | 96×96 | `res://assets/weapons/rifle_long.png` | PNG |
| weapon_wand_focus | 聚焦法杖 | 96×96 | `res://assets/weapons/wand_focus.png` | PNG |
| weapon_sniper | 狙击枪 | 96×96 | `res://assets/weapons/sniper.png` | PNG |
| weapon_orb_wand | 法球杖 | 96×96 | `res://assets/weapons/orb_wand.png` | PNG |
| swing_blade_short | 短刃挥击 | 24×8 | `res://assets/weapons/swing_blade_short.png` | PNG |
| swing_hammer_heavy | 重锤挥击 | 24×8 | `res://assets/weapons/swing_hammer_heavy.png` | PNG |
| swing_dagger | 刺刀挥击 | 24×8 | `res://assets/weapons/swing_dagger.png` | PNG |
| swing_spear | 长矛挥击 | 24×8 | `res://assets/weapons/swing_spear.png` | PNG |
| swing_chainsaw | 链锯挥击 | 24×8 | `res://assets/weapons/swing_chainsaw.png` | PNG |

---

### 2.5 子弹与掉落（Bullets & Pickups）

| 资源 | 用途 | 尺寸 | 路径 | 格式 |
|------|------|------|------|------|
| bullet_player | 玩家子弹 | 4×4 | `res://assets/bullets/player_bullet.png` | PNG |
| bullet_enemy | 敌人子弹 | 4×4 | `res://assets/bullets/enemy_bullet.png` | PNG |
| bullet_firearm | 枪械子弹（pistol/shotgun/rifle） | 4×4 | `res://assets/bullets/bullet_firearm.png` | PNG |
| bullet_laser | 激光子弹 | 12×2 | `res://assets/bullets/bullet_laser.png` | PNG |
| bullet_orb | 法球子弹 | 8×8 | `res://assets/bullets/bullet_orb.png` | PNG |
| pickup_coin | 金币 | 8×8 | `res://assets/pickups/coin.png` | PNG |
| pickup_heal | 治疗 | 8×8 | `res://assets/pickups/heal.png` | PNG |

> 子弹实际形状由 `bullet_type` 决定（pistol 4×4、shotgun 6×6、rifle 8×2、laser 12×2）。若用纹理，需在 `bullet.gd` 中调整逻辑。

---

### 2.6 UI

| 类型 | 用途 | 当前实现 | 说明 |
|------|------|----------|------|
| 模态背景 | 升级/商店遮罩 | 纯色 | `ui.modal_backdrop` |
| 面板背景 | 弹窗背景 | 纯色 | `ui.modal_panel_bg` |
| 面板边框 | 弹窗边框 | 纯色 | `ui.modal_panel_border` |
| 升级图标 | 升级三选一 | 96×96 色块 | `upgrade.icon.damage` 等 |

UI 颜色在 `visual_asset_registry.gd` 的 `COLOR_MAP` 中定义；升级图标若未配置纹理，会 fallback 到色块。如需图标，需在 `texture_path_config.gd` 中增加 `upgrade_icon_*` 等字段并配置路径。

---

## 三、AI 生成美术资源建议

### 3.1 推荐工具

- **Stable Diffusion / Midjourney / DALL·E**：生成概念图或高分辨率图
- **Cursor 内置 GenerateImage**：可生成简单图标或 UI 元素
- **Piskel / Aseprite**：像素风格编辑（AI 生成后微调）

### 3.2 生成提示词（Prompt）示例

#### 角色（24×24 像素）

```
Top-down pixel art character sprite, 24x24 pixels, simple silhouette, 
blue/white color scheme, game character, transparent background, PNG
```

#### 敌人（18×18 像素）

```
Top-down pixel art enemy sprite, 18x18 pixels, red melee enemy with horns,
simple silhouette, transparent background, game sprite
```

#### 武器图标（96×96）

```
Pixel art weapon icon, short sword, 96x96, top-down view, 
simple silhouette, game UI icon, transparent background
```

#### 地形（若改为纹理）

```
Seamless tile texture, grass, 64x64 pixels, tileable, pixel art style
```

```
Seamless water texture, shallow water, transparent, 64x64 tileable
```

```
Pixel art obstacle, rock or boulder, 64x64, top-down view
```

### 3.3 生成后处理

1. **尺寸**：裁剪/缩放至目标尺寸（24×24、18×18、96×96 等）
2. **格式**：导出为 PNG，支持透明通道
3. **风格**：像素风格建议统一，避免混用写实与像素风

---

## 四、替换流程

### 4.1 仅替换颜色（地形、UI）

1. 打开 `resources/terrain_colors.tres`（或 Godot 中 Inspector）
2. 修改 `floor_a`、`floor_b`、`grass`、`shallow_water`、`deep_water`、`obstacle`、`boundary` 的颜色值
3. UI 颜色需在 `visual_asset_registry.gd` 的 `COLOR_MAP` 中修改，或扩展 `terrain_color_config` 支持 UI 颜色

### 4.2 替换纹理（角色、敌人、武器、子弹、掉落）

**快速生成**：运行 `python scripts/tools/export_pixel_assets.py` 可自动生成与 `PixelGenerator` 一致的像素图到 `assets/` 目录，包括：
- 角色/敌人 8 方向精灵图（`*_sheet.png`），含 3 行行走动画（站立、行走帧1、行走帧2）
- 武器挥击图（`swing_blade_short.png`、`swing_hammer_heavy.png`、`swing_dagger.png`、`swing_spear.png`、`swing_chainsaw.png`）
- 3 种子弹类型（`bullet_firearm.png`、`bullet_laser.png`、`bullet_orb.png`）
- 地形 tile（`assets/terrain/`）

GDScript 导出：`godot -s res://scripts/tools/export_pixel_assets_standalone.gd` 或编辑器内运行 `export_pixel_assets.gd`，同样会导出子弹类型与武器图标。

1. **创建目录**（若不存在）：

   ```
   assets/
   ├── characters/
   ├── enemies/
   ├── weapons/
   ├── bullets/
   └── pickups/
   ```

2. **放入 PNG 文件**：按 `texture_paths.tres` 中路径命名，例如：
   - `assets/characters/player_scheme_0.png`
   - `assets/enemies/enemy_melee.png`
   - `assets/weapons/blade_short.png`
   - 等

3. **检查路径**：若路径与默认不同，在 Godot 中打开 `resources/texture_paths.tres`，在 Inspector 中修改对应路径

4. **验证**：运行游戏，若纹理加载成功，会替换色块；若失败，会 fallback 到 `PixelGenerator` 生成的色块

### 4.3 替换流程总结

1. 生成或准备 PNG 资源
2. 放入 `assets/` 对应子目录
3. 若需要新路径，在 `texture_paths.tres` 中配置
4. 运行游戏验证

---

## 五、扩展：新增纹理配置

若需为**升级图标**等增加纹理：

1. 在 `resources/texture_path_config.gd` 中增加 `@export_file` 字段，例如：
   ```gdscript
   @export_file("*.png") var upgrade_icon_damage: String = "res://assets/ui/upgrade_damage.png"
   ```

2. 在 `visual_asset_registry.gd` 的 `_TEXTURE_KEY_TO_PROPERTY` 中增加映射：
   ```gdscript
   "upgrade.icon.damage": "upgrade_icon_damage"
   ```

3. 在 `texture_paths.tres` 中配置实际路径

4. 将 PNG 放入 `assets/ui/` 等目录

---

## 六、资源路径与回退逻辑

| 资源类型 | 配置入口 | 回退逻辑 |
|----------|----------|----------|
| 地形颜色 | `terrain_colors.tres` | `COLOR_MAP` 默认值 |
| 角色/敌人/武器/子弹/掉落 | `texture_paths.tres` | `PixelGenerator` 或 `make_color_texture` |
| UI 颜色 | `visual_asset_registry.gd` 内 | `COLOR_MAP` |

只要纹理路径正确且文件存在，`VisualAssetRegistry.get_texture()` 会优先加载纹理，否则使用 fallback 逻辑。

# 美术风格指南

本文档记录项目自动生成美术资源的风格规范。**图片类美术资源仅使用 AliyunBailianMCP_WanImage（`modelstudio_image_gen`）生成**，生成时必须遵循本文档的规格与描述词要求，保证新生成资源与现有资产的一致性。

---

## 一、参考资产（WanImage 已生成）

| 路径 | 类别 | 描述词 |
|------|------|--------|
| assets/weapons/blade_short.png | 武器 | short sword, top-down view, pixel art icon, game UI |
| assets/weapons/dagger.png | 武器 | dagger knife, top-down view, pixel art icon, game UI |
| assets/weapons/spear.png | 武器 | spear weapon, top-down view, pixel art icon, game UI |
| assets/magic/icon_fire.png | 魔法 | fire flame icon, pixel art, magic spell |
| assets/magic/icon_lightning.png | 魔法/元素 | lightning bolt icon, pixel art, magic spell |
| assets/ui/upgrade_icons/icon_hp.png | 道具 | heart icon for health, pixel art, game UI |

生成新资源前，**务必查看上述文件**以把握视觉风格；已替换清单见 [PIXELLAB_REPLACED_ASSETS.md](PIXELLAB_REPLACED_ASSETS.md)。

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
| **单帧尺寸** | 32×32 像素（提高分辨率以体现细节） |
| **精灵图尺寸** | 256×416（8 列 × 13 行） |
| **格式** | PNG，支持透明通道 |
| **路径** | `assets/characters/player_scheme_*.png`、`*_sheet.png` |
| **结构** | 8 列 × 13 行（站立 1 帧 + 行走 12 帧），方向顺序 E, SE, S, SW, W, NW, N, NE |
| **精细度** | 达到能展示细节的程度（五官、服饰、装备轮廓等可辨识） |

### 2.7 敌人精灵（普通）

| 项目 | 要求 |
|------|------|
| **单帧尺寸** | 24×24 像素（提高分辨率以体现细节） |
| **精灵图尺寸** | 192×168（8 列 × 7 行） |
| **格式** | PNG，支持透明通道 |
| **路径** | `assets/enemies/enemy_*.png`、`*_sheet.png`（非 BOSS） |
| **结构** | 8 列 × 7 行（站立 1 帧 + 行走 6 帧） |
| **精细度** | 达到能展示细节的程度（外形特征、配色、轮廓可辨识） |

### 2.8 敌人精灵（BOSS）

| 项目 | 要求 |
|------|------|
| **单帧尺寸** | 72×72 像素（单独设置，约为普通敌人 3 倍，提高分辨率以体现细节） |
| **精灵图尺寸** | 576×504（8 列 × 7 行） |
| **格式** | PNG，支持透明通道 |
| **路径** | `assets/enemies/enemy_*_boss.png`、`*_boss_sheet.png` 或 BOSS 专用路径 |
| **结构** | 8 列 × 7 行（站立 1 帧 + 行走 6 帧） |
| **精细度** | 达到能展示细节的程度；BOSS 体积大，需更高分辨率以保持清晰 |
| **其他** | 显示时使用 `GameConstants.BOSS_SCALE`（默认 8）缩放 |

### 2.9 子弹与掉落

| 类型 | 纹理尺寸 | 格式 | 路径 | 其他 |
|------|----------|------|------|------|
| 枪械子弹 | 4×4（基准） | PNG | `assets/bullets/bullet_firearm.png` | 透明背景；pistol 4×4、shotgun 6×6、rifle 8×2 显示时按类型缩放 |
| 激光子弹 | 12×2 | PNG | `assets/bullets/bullet_laser.png` | 透明背景 |
| 法球子弹 | 8×8 | PNG | `assets/bullets/bullet_orb.png` | 透明背景 |
| 金币 | 8×8 | PNG | `assets/pickups/coin.png` | 透明背景 |
| 治疗 | 8×8 | PNG | `assets/pickups/heal.png` | 透明背景 |

### 2.10 地形瓦片

| 项目 | 要求 |
|------|------|
| **尺寸** | 按 atlas 切分（如 64×64 单格） |
| **格式** | PNG，可无缝平铺 |
| **路径** | `assets/terrain/terrain_atlas.png` 等 |
| **其他** | 3 行 × 7 列（flat/seaside/mountain 地板） |

### 2.11 面板背景图（可选替换）

| 项目 | 要求 |
|------|------|
| **尺寸** | 48×48 或 64×64，九宫格切分 |
| **格式** | PNG |
| **边框区域** | expand_margin 6~8 像素，中间可拉伸 |
| **其他** | 当前由程序生成，若替换需与 `UiThemeConfig`、`StyleBoxTexture` 配置一致 |

### 2.12 通用要求

- **格式**：PNG，支持透明通道（RGBA），UI 图标与精灵图必须透明背景
- **风格**：像素风，边缘清晰，色块分明，非抗锯齿
- **命名**：与配置中的 `icon_path`、`texture_path` 等路径一致

---

## 三、WanImage 生成参数（武器/道具/魔法/元素图标）

当前**仅使用 AliyunBailianMCP_WanImage** 生成图片。调用 `modelstudio_image_gen` 时须遵循本文档：

| 参数 | 建议 | 说明 |
|------|------|------|
| prompt | 见「四、描述词规范」 | 正向提示词，描述期望画面；**必须包含**视角（如 top-down）、风格（pixel art icon）及 **transparent background** |
| size | `1024*1024` 或按需 | 若 API 支持 96*96 则优先使用；否则使用 1024*1024 生成后，**必须**用项目提供的缩放脚本将输出缩放到 96×96 再保存到规定路径（GDScript：`scripts/tools/resize_icons_to_spec.gd`；Python：`scripts/resize_icons_to_spec.py`，需 `pip install Pillow`） |
| negative_prompt | 可选 | 不希望在画面中出现的内容 |
| n | 1 | 生成张数，通常 1 |
| watermark | false | 建议不加水印 |

生成后须保存到「二」中规定的路径，并满足像素风、透明背景等「二」「五」要求；尺寸若非 96×96 须执行图标缩放脚本再打标。

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

- 描述词使用英文；**必须包含 transparent background** 以要求透明背景
- 保持简洁，避免过长
- 与参考资产的描述词风格一致

---

## 五、视觉特征（生成图须满足）

- **像素风格**：边缘清晰，色块分明，非抗锯齿
- **透明背景**：无背景色，便于叠加到 UI
- **配色**：主体色明确，阴影与高光过渡自然
- **轮廓**：单色描边，与主体色区分
- **尺寸**：96×96 适用于武器/道具/魔法/元素图标；其他类型见「二、各类美术资源规格」

---

## 六、生成流程（WanImage）

1. **查阅** 项目内已生成资产记录（如有），跳过已打标资产
2. **参考** 本文档「二、各类美术资源规格」与「四、描述词规范」，确定尺寸、路径与提示词；提示词须包含 **transparent background**
3. **调用** **AliyunBailianMCP_WanImage** 的 `modelstudio_image_gen` 工具：`prompt` 按描述词规范，`size` 按规格（若 API 支持 96*96 则用，否则 1024*1024），`n` 按需
4. **下载** 返回的图片 URL，保存为 PNG 到 `assets/` 对应路径（见「二」中各类型路径）
5. **缩放** 若保存的图片尺寸非 96×96，须执行项目内图标缩放脚本（`scripts/tools/resize_icons_to_spec.gd` 或 `scripts/resize_icons_to_spec.py`）将对应文件缩放到 96×96 后再继续
6. **打标** 在已生成资产记录中新增记录（如有）

生成结果须符合本文档要求：**尺寸、格式、路径、视角、像素风、透明背景**等与「二」「五」一致。

**失败处理**：若 WanImage 调用失败，**仅提示哪些资产生成失败**，不调用其他图生接口（如 Pixellab、ali-image、GenerateImage 等）替代生成。

### 6.1 Pixellab（可选，非当前图生工具）

项目规定图片美术资源**仅使用 AliyunBailianMCP_WanImage** 生成，以下仅供了解。Pixellab 支持账号登录，使用 API Token 可提高配额、减少限流：

1. **注册/登录**：访问 [pixellab.ai/signin](https://www.pixellab.ai/signin)，使用邮箱或 Google 登录
2. **获取 Token**：登录后进入 [pixellab.ai/account](https://www.pixellab.ai/account)，在账户设置中获取 API Token
3. **配置 MCP**：在 Cursor 的 MCP 配置（`~/.cursor/mcp.json` 或项目 `.cursor/mcp.json`）中添加：

```json
{
  "mcpServers": {
    "user-pixellab": {
      "url": "https://api.pixellab.ai/mcp",
      "transport": "http",
      "headers": {
        "Authorization": "Bearer YOUR_API_TOKEN"
      }
    }
  }
}
```

将 `YOUR_API_TOKEN` 替换为从账户页面获取的 Token。配置后 MCP 请求将携带认证，通常可获得更高配额、减少 429 限流。

### 6.2 WanImage（当前图生工具）

**图片美术资源仅使用 AliyunBailianMCP_WanImage**，工具名为 `modelstudio_image_gen`。生成前须阅读本文档规格与描述词，生成后保存到规定路径并满足尺寸与风格要求。

### 6.3 ali-image（阿里云 DashScope / FLUX，非默认图生工具）

项目内 **ali-image** MCP 使用 [ali-flux-mcp](https://github.com/echozyr2001/ali-flux-mcp) 本地部署；按规定**不**用于替代 WanImage 做美术资产生成。

- **位置**：`.cursor/tools/ali-flux-mcp`
- **配置**：`mcp.json` 中 `ali-image` 的 `env` 需提供 `DASHSCOPE_API_KEY`；可选 `SAVE_DIR`
- **默认保存目录**：`assets/generated_images`

---

## 七、维护

- 新增 WanImage 生成资产后，若风格有显著变化，可更新本文档「参考资产」与「视觉特征」
- 参数或工具变更时同步更新「三、WanImage 生成参数」与「六、生成流程」

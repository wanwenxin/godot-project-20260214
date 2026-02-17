# 代码索引目录

按业务流程与功能模块组织的文件索引，便于开发者快速定位与理解工程细节。架构概览参见 [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md)。美术资源替换说明参见 [ART_ASSET_REPLACEMENT_GUIDE.md](ART_ASSET_REPLACEMENT_GUIDE.md)。

---

## 1. 业务流程索引

### 1.1 启动与主菜单

| 流程 | 文件 | 说明 |
|------|------|------|
| 入口 | [scripts/ui/main_menu.gd](scripts/ui/main_menu.gd) | 主菜单：新游戏、继续、设置、退出；展示存档统计 |
| 设置 | [scripts/ui/settings_menu.gd](scripts/ui/settings_menu.gd) | 音量、分辨率、按键、惯性等；修改即生效并保存 |
| 全局 | [scripts/autoload/game_manager.gd](scripts/autoload/game_manager.gd) | 场景切换、角色/武器配置、本局状态 |
| 存档 | [scripts/autoload/save_manager.gd](scripts/autoload/save_manager.gd) | `user://savegame/save.json` 读写、设置持久化 |

### 1.2 角色选择

| 流程 | 文件 | 说明 |
|------|------|------|
| 界面 | [scripts/ui/character_select.gd](scripts/ui/character_select.gd) | 双角色卡片、属性与历史战绩展示 |
| 数据 | [scripts/autoload/game_manager.gd](scripts/autoload/game_manager.gd) | `get_character_data()`、`start_new_game()` |

### 1.3 战斗与波次

| 流程 | 文件 | 说明 |
|------|------|------|
| 主控 | [scripts/game.gd](scripts/game.gd) | 生成玩家与地形、挂接波次/HUD 信号、暂停与结算、摄像机缩放按键 |
| 波次 | [scripts/wave_manager.gd](scripts/wave_manager.gd) | 敌人生成、击杀统计、掉落、倒计时、清场信号 |
| 玩家 | [scripts/player.gd](scripts/player.gd) | 移动、索敌、开火、受伤、死亡、升级应用 |
| 提示 | [scripts/spawn_telegraph.gd](scripts/spawn_telegraph.gd) | 敌人生成前警示圈与倒计时 |

### 1.4 升级与商店

| 流程 | 文件 | 说明 |
|------|------|------|
| 逻辑 | [scripts/game.gd](scripts/game.gd) | `_on_upgrade_selected`、`_on_weapon_shop_selected`、`_roll_upgrade_options`、`_roll_shop_items` |
| UI | [scripts/ui/hud.gd](scripts/ui/hud.gd) | `show_upgrade_options`、`show_weapon_shop`、`show_start_weapon_pick` |
| 升级配置 | [resources/upgrade_defs.gd](resources/upgrade_defs.gd) | 升级池、等级奖励公式 |
| 商店配置 | [resources/shop_item_defs.gd](resources/shop_item_defs.gd) | 道具池、波次涨价 |
| 全局 | [scripts/autoload/game_manager.gd](scripts/autoload/game_manager.gd) | `run_currency`、`run_experience`、`run_level`、`add_experience` |

### 1.5 结算与死亡/通关

| 流程 | 文件 | 说明 |
|------|------|------|
| 死亡 | [scripts/ui/game_over_screen.gd](scripts/ui/game_over_screen.gd) | `show_result(wave, kills, time, player_node)` |
| 通关 | [scripts/ui/victory_screen.gd](scripts/ui/victory_screen.gd) | 同上，标题「通关」 |
| 共享 | [scripts/ui/result_panel_shared.gd](scripts/ui/result_panel_shared.gd) | `build_score_block`、`build_player_stats_block` |
| 触发 | [scripts/game.gd](scripts/game.gd) | `_on_player_died`、`_on_wave_cleared`（`wave >= victory_wave`） |

---

## 2. 功能模块索引

### 2.1 全局管理（Autoload）

| 文件 | 职责 | 关键导出/信号 |
|------|------|---------------|
| [scripts/autoload/affix_manager.gd](scripts/autoload/affix_manager.gd) | 词条收集、聚合、效果应用 | `collect_affixes_from_player`、`refresh_player`、`get_visible_affixes` |
| [scripts/autoload/game_manager.gd](scripts/autoload/game_manager.gd) | 场景切换、角色/武器配置、本局金币与武器库存 | `change_scene`、`get_character_data`、`run_currency` |
| [scripts/autoload/save_manager.gd](scripts/autoload/save_manager.gd) | 存档读写、设置持久化、统计聚合 | `load_game`、`set_settings`、`has_save` |
| [scripts/autoload/audio_manager.gd](scripts/autoload/audio_manager.gd) | 合成音效与 BGM | `play_shoot_by_type`、`play_menu_bgm`、`play_game_bgm` |
| [scripts/autoload/localization_manager.gd](scripts/autoload/localization_manager.gd) | 多语言、文案 key | `tr_key`、`language_changed` |
| [scripts/autoload/log_manager.gd](scripts/autoload/log_manager.gd) | 游戏进程错误/警告输出到 `user://logs/game_errors.log` | 自动捕获，无需调用 |
| [addons/editor_logger/plugin.gd](addons/editor_logger/plugin.gd) | 编辑器进程错误/警告输出到 `user://logs/game_errors.log`（与游戏同文件）；从 godot.log 中继 GDScript::reload 解析错误 | 需在项目设置中启用插件 |
| [scripts/autoload/visual_asset_registry.gd](scripts/autoload/visual_asset_registry.gd) | 纯色贴图工具 | `make_color_texture` |

### 2.2 战斗核心

| 文件 | 职责 | 关键导出/信号 |
|------|------|---------------|
| [scripts/game.gd](scripts/game.gd) | 主游戏控制器、地形生成、升级/商店流程、摄像机缩放 | `victory_wave`、`get_player_for_pause` |
| [scripts/player.gd](scripts/player.gd) | 玩家移动、索敌、开火、受伤、死亡 | `died`、`health_changed`、`get_equipped_weapon_details`、`get_full_stats_for_pause`、`get_attack_speed` |
| [scripts/bullet.gd](scripts/bullet.gd) | 子弹飞行、命中、穿透、去重 | `hit_player`、`remaining_pierce` |
| [scripts/enemy_bullet.gd](scripts/enemy_bullet.gd) | 敌人专用子弹，更大更慢 | 继承 bullet |
| [scripts/pickup.gd](scripts/pickup.gd) | 金币/治疗掉落、拾取、飘动、金币吸收动画 | `pickup_type`、`value`、`absorb_range` |

### 2.3 敌人与波次

| 文件 | 职责 | 关键导出/信号 |
|------|------|---------------|
| [scripts/enemy_base.gd](scripts/enemy_base.gd) | 通用生命、接触伤害、击退、地形效果 | `apply_knockback`、`set_terrain_effect` |
| [scripts/enemy_melee.gd](scripts/enemy_melee.gd) | 追击型近战敌人 | 继承 enemy_base |
| [scripts/enemy_ranged.gd](scripts/enemy_ranged.gd) | 保持距离并射击 | 继承 enemy_base |
| [scripts/enemy_tank.gd](scripts/enemy_tank.gd) | 高血低速坦克 | 继承 enemy_base |
| [scripts/enemy_boss.gd](scripts/enemy_boss.gd) | Boss 波扇形弹幕 | 继承 enemy_base |
| [scripts/enemy_aquatic.gd](scripts/enemy_aquatic.gd) | 水中专属敌人，离水扣血 | 继承 enemy_base，`is_water_only()` |
| [scripts/enemy_dasher.gd](scripts/enemy_dasher.gd) | 蓄力冲刺攻击敌人 | 继承 enemy_base |
| [scripts/wave_manager.gd](scripts/wave_manager.gd) | 波次推进、敌人生成、掉落、倒计时 | `wave_started`、`wave_cleared`、`kill_count_changed` |
| [scripts/spawn_telegraph.gd](scripts/spawn_telegraph.gd) | 敌人生成前警示，显示数量（×N） | 配合 wave_manager 使用 |


### 2.4 地形系统

| 文件 | 职责 | 关键导出/信号 |
|------|------|---------------|
| [scripts/terrain_zone.gd](scripts/terrain_zone.gd) | 草丛/浅水/深水逻辑、速度倍率、深水 DOT | `terrain_type`、`speed_multiplier` |
| [scripts/game.gd](scripts/game.gd) | `_spawn_terrain_map` 簇团式分层生成、TileMapLayer 像素图（含 flat/seaside/mountain 地板）、严格无重叠 | 深水→浅水→障碍→草丛→边界 |
| [resources/terrain_colors.tres](resources/terrain_colors.tres) | 地形色块统一配置入口，供 game.gd 引用 | floor_a/b、grass、shallow_water、deep_water、obstacle、boundary |

### 2.5 角色特质

| 文件 | 职责 | 关键导出/信号 |
|------|------|---------------|
| [scripts/characters/character_traits_base.gd](scripts/characters/character_traits_base.gd) | 角色特质基类，默认属性与数值计算虚方法 | `get_final_damage`、`get_damage_multiplier`、`get_elemental_enchantment` |
| [scripts/characters/rapid_shooter_traits.gd](scripts/characters/rapid_shooter_traits.gd) | RapidShooter 特质（伤害系数、火附魔） | 继承 character_traits_base |
| [scripts/characters/heavy_gunner_traits.gd](scripts/characters/heavy_gunner_traits.gd) | HeavyGunner 特质（伤害系数、重锤加成） | 继承 character_traits_base |

### 2.6 武器系统

| 文件 | 职责 | 关键导出/信号 |
|------|------|---------------|
| [scripts/weapons/weapon_base.gd](scripts/weapons/weapon_base.gd) | 武器基类、冷却、配置、升级接口 | `configure_from_def`、`tick_and_try_attack` |
| [scripts/weapons/weapon_melee_base.gd](scripts/weapons/weapon_melee_base.gd) | 近战基类、挥击与碰触判定 | 继承 weapon_base |
| [scripts/weapons/weapon_ranged_base.gd](scripts/weapons/weapon_ranged_base.gd) | 远程基类、子弹发射 | 继承 weapon_base |
| [scripts/weapons/melee/weapon_blade_short.gd](scripts/weapons/melee/weapon_blade_short.gd) | 短刃 | 继承 weapon_melee_base |
| [scripts/weapons/melee/weapon_hammer_heavy.gd](scripts/weapons/melee/weapon_hammer_heavy.gd) | 重锤 | 继承 weapon_melee_base |
| [scripts/weapons/ranged/weapon_pistol_basic.gd](scripts/weapons/ranged/weapon_pistol_basic.gd) | 手枪 | 继承 weapon_ranged_base |
| [scripts/weapons/ranged/weapon_shotgun_wide.gd](scripts/weapons/ranged/weapon_shotgun_wide.gd) | 霰弹枪 | 继承 weapon_ranged_base |
| [scripts/weapons/ranged/weapon_rifle_long.gd](scripts/weapons/ranged/weapon_rifle_long.gd) | 长步枪 | 继承 weapon_ranged_base |
| [scripts/weapons/ranged/weapon_wand_focus.gd](scripts/weapons/ranged/weapon_wand_focus.gd) | 聚焦法杖 | 继承 weapon_ranged_base |
| [scripts/weapon.gd](scripts/weapon.gd) | 旧版武器基类（部分兼容） | - |
| [resources/weapon_defs.gd](resources/weapon_defs.gd) | 武器定义池 | `WEAPON_DEFS` |
| [resources/tier_config.gd](resources/tier_config.gd) | 品级配置 | `get_tier_color`、`get_damage_multiplier`、`get_cooldown_multiplier` |

### 2.6b 魔法系统

| 文件 | 职责 | 关键导出/信号 |
|------|------|---------------|
| [scripts/magic/magic_base.gd](scripts/magic/magic_base.gd) | 魔法基类 | `cast(caster, target_dir)`、`cast_at_position(caster, world_pos)` |
| [scripts/magic/fire_bolt.gd](scripts/magic/fire_bolt.gd) | 火球术 | 火焰弹道 |
| [scripts/magic/ice_shard.gd](scripts/magic/ice_shard.gd) | 冰霜碎片 | 冰霜弹道 |
| [scripts/magic/area_shockwave.gd](scripts/magic/area_shockwave.gd) | 冲击波 | 区域一次性伤害 |
| [scripts/magic/area_burn.gd](scripts/magic/area_burn.gd) | 燃烧区域 | 区域持续燃烧伤害 |
| [scripts/magic/burn_zone_node.gd](scripts/magic/burn_zone_node.gd) | 燃烧区域节点 | 持续存在并周期性造成伤害 |
| [scripts/ui/magic_targeting_overlay.gd](scripts/ui/magic_targeting_overlay.gd) | 区域施法选择 | 圆形范围跟随鼠标，左键施放、右键/Esc 取消 |
| [resources/magic_defs.gd](resources/magic_defs.gd) | 魔法定义（含 cast_mode、area_radius、effect_type、cooldown） |
| [resources/upgrade_defs.gd](resources/upgrade_defs.gd) | 升级配置（含 spell_speed） |
| [resources/shop_item_defs.gd](resources/shop_item_defs.gd) | 商店道具配置 |

### 2.6c 词条系统

| 文件 | 职责 | 关键导出/信号 |
|------|------|---------------|
| [scripts/affix/affix_base.gd](scripts/affix/affix_base.gd) | 词条基类 | `id`、`visible`、`params`、`get_display_name` |
| [scripts/affix/weapon_affix.gd](scripts/affix/weapon_affix.gd) | 武器词条 | 继承 AffixBase |
| [scripts/affix/magic_affix.gd](scripts/affix/magic_affix.gd) | 魔法词条 | 继承 AffixBase |
| [scripts/affix/item_affix.gd](scripts/affix/item_affix.gd) | 道具词条 | 继承 AffixBase |
| [resources/item_affix_defs.gd](resources/item_affix_defs.gd) | 道具词条库 | `ITEM_AFFIX_POOL` |
| [resources/weapon_affix_defs.gd](resources/weapon_affix_defs.gd) | 武器词条库 | `WEAPON_AFFIX_POOL` |
| [resources/magic_affix_defs.gd](resources/magic_affix_defs.gd) | 魔法词条库 | `MAGIC_AFFIX_POOL` |
| [resources/affix_combo_defs.gd](resources/affix_combo_defs.gd) | 词条组合效果配置 | `COMBO_POOL` |

### 2.7 UI 层

| 文件 | 职责 | 关键导出/信号 |
|------|------|---------------|
| [scripts/ui/hud.gd](scripts/ui/hud.gd) | 战斗信息、升级/商店面板、触控 | `upgrade_selected`、`weapon_shop_selected`、`pause_pressed` |
| [scripts/ui/main_menu.gd](scripts/ui/main_menu.gd) | 主菜单 | - |
| [scripts/ui/character_select.gd](scripts/ui/character_select.gd) | 角色选择 | - |
| [scripts/ui/pause_menu.gd](scripts/ui/pause_menu.gd) | 暂停菜单、玩家信息 | `set_visible_menu`、`set_player_stats_full` |
| [scripts/ui/settings_menu.gd](scripts/ui/settings_menu.gd) | 设置 | `open_menu`、`closed` |
| [scripts/ui/game_over_screen.gd](scripts/ui/game_over_screen.gd) | 死亡结算 | `show_result` |
| [scripts/ui/victory_screen.gd](scripts/ui/victory_screen.gd) | 通关结算 | `show_result` |
| [scripts/ui/result_panel_shared.gd](scripts/ui/result_panel_shared.gd) | 结算面板共享 UI | `build_score_block`、`build_player_stats_block`（支持完整 stats 字典） |
| [scripts/ui/magic_targeting_overlay.gd](scripts/ui/magic_targeting_overlay.gd) | 区域施法选择覆盖层 | `start_targeting`、`cast_confirmed`、`cast_cancelled` |

### 2.8 资源与工具

| 文件 | 职责 | 关键导出/信号 |
|------|------|---------------|
| [scripts/pixel_generator.gd](scripts/pixel_generator.gd) | 运行时生成像素图 | `generate_bullet_sprite_by_type`、`generate_pickup_sprite` |
| [resources/terrain_color_config.gd](resources/terrain_color_config.gd) | 地形色块 Resource 脚本 | 供 terrain_colors.tres 使用 |
| [resources/default_terrain_colors.gd](resources/default_terrain_colors.gd) | 默认地形配色（flat/seaside/mountain），供 ColorRect 回退 | `get_floor_colors` |
| [resources/texture_path_config.gd](resources/texture_path_config.gd) | 纹理路径 Resource 脚本（可选，部分场景仍可参考） | 人物/敌人/武器等美术路径 |
| [resources/texture_paths.tres](resources/texture_paths.tres) | 纹理路径配置（可选） | 美术已解耦至各实现类/weapon_defs |
| [resources/character_data.gd](resources/character_data.gd) | 角色数据（若存在） | - |

---

## 3. 文件速查表

| 文件路径 | 模块 | 职责摘要 |
|----------|------|----------|
| scripts/autoload/affix_manager.gd | 全局管理 | 词条收集、聚合、效果应用 |
| scripts/autoload/game_manager.gd | 全局管理 | 场景切换、角色/武器配置、本局状态 |
| scripts/autoload/save_manager.gd | 全局管理 | 存档读写、设置持久化 |
| scripts/autoload/audio_manager.gd | 全局管理 | 音效与 BGM |
| scripts/autoload/localization_manager.gd | 全局管理 | 多语言 |
| scripts/autoload/log_manager.gd | 全局管理 | 错误/警告日志输出 |
| scripts/autoload/visual_asset_registry.gd | 全局管理 | 纹理/颜色注册 |
| scripts/game.gd | 战斗核心 | 主游戏控制器、地形生成 |
| scripts/player.gd | 战斗核心 | 玩家移动、索敌、开火、受伤 |
| scripts/bullet.gd | 战斗核心 | 子弹飞行与命中 |
| scripts/enemy_bullet.gd | 战斗核心 | 敌人专用子弹 |
| scripts/pickup.gd | 战斗核心 | 掉落物拾取 |
| scripts/enemy_base.gd | 敌人 | 敌人基类 |
| scripts/enemy_melee.gd | 敌人 | 追击型 |
| scripts/enemy_ranged.gd | 敌人 | 远程型 |
| scripts/enemy_tank.gd | 敌人 | 坦克型 |
| scripts/enemy_boss.gd | 敌人 | Boss |
| scripts/enemy_aquatic.gd | 敌人 | 水中专属 |
| scripts/enemy_dasher.gd | 敌人 | 冲刺攻击 |
| scripts/wave_manager.gd | 波次 | 波次推进、敌人生成、掉落 |
| scripts/spawn_telegraph.gd | 波次 | 生成警示 |
| scripts/terrain_zone.gd | 地形 | 草丛/浅水/深水 |
| scripts/weapons/weapon_base.gd | 武器 | 武器基类 |
| scripts/weapons/weapon_melee_base.gd | 武器 | 近战基类 |
| scripts/weapons/weapon_ranged_base.gd | 武器 | 远程基类 |
| scripts/weapons/melee/*.gd | 武器 | 具体近战武器 |
| scripts/weapons/ranged/*.gd | 武器 | 具体远程武器 |
| scripts/weapon.gd | 武器 | 旧版武器基类 |
| scripts/characters/character_traits_base.gd | 角色特质 | 特质基类 |
| scripts/characters/rapid_shooter_traits.gd | 角色特质 | RapidShooter |
| scripts/characters/heavy_gunner_traits.gd | 角色特质 | HeavyGunner |
| scripts/ui/hud.gd | UI | 战斗 HUD、升级/商店 |
| scripts/ui/main_menu.gd | UI | 主菜单 |
| scripts/ui/character_select.gd | UI | 角色选择 |
| scripts/ui/pause_menu.gd | UI | 暂停菜单 |
| scripts/ui/settings_menu.gd | UI | 设置 |
| scripts/ui/game_over_screen.gd | UI | 死亡结算 |
| scripts/ui/victory_screen.gd | UI | 通关结算 |
| scripts/ui/result_panel_shared.gd | UI | 结算共享 UI |
| scripts/ui/magic_targeting_overlay.gd | UI | 区域施法选择 |
| scripts/magic/area_shockwave.gd | 魔法 | 冲击波 |
| scripts/magic/area_burn.gd | 魔法 | 燃烧区域 |
| scripts/magic/burn_zone_node.gd | 魔法 | 燃烧区域节点 |
| scripts/pixel_generator.gd | 工具 | 像素图生成 |
| resources/weapon_defs.gd | 资源 | 武器定义 |
| resources/tier_config.gd | 资源 | 品级颜色与倍率 |
| resources/terrain_color_config.gd | 资源 | 地形色块配置脚本 |
| resources/default_terrain_colors.gd | 资源 | 默认地形配色（flat/seaside/mountain） |
| resources/terrain_colors.tres | 资源 | 地形色块统一入口 |
| resources/texture_path_config.gd | 资源 | 纹理路径配置脚本 |
| resources/texture_paths.tres | 资源 | 人物/敌人/武器纹理统一入口 |
| resources/character_data.gd | 资源 | 角色数据 |
| scripts/affix/affix_base.gd | 词条 | 词条基类 |
| scripts/affix/weapon_affix.gd | 词条 | 武器词条 |
| scripts/affix/magic_affix.gd | 词条 | 魔法词条 |
| scripts/affix/item_affix.gd | 词条 | 道具词条 |
| resources/item_affix_defs.gd | 资源 | 道具词条库 |
| resources/weapon_affix_defs.gd | 资源 | 武器词条库 |
| resources/magic_affix_defs.gd | 资源 | 魔法词条库 |
| resources/affix_combo_defs.gd | 资源 | 词条组合效果配置 |

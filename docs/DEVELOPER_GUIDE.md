# Developer Guide

本文件面向维护该 Demo 的开发者，覆盖当前版本（含升级系统、地形系统、掉落、Boss、触控与音频）的架构说明与排障建议。按业务流程与功能模块组织的代码索引见 [CODE_INDEX.md](CODE_INDEX.md)。

## 1. 技术栈与项目约定

- 引擎：Godot 4.x
- 显示：`canvas_items` 拉伸 + `ignore` 宽高比，运行时 `content_scale_size` 设为窗口尺寸，画面填满；窗口支持 50%/75%/100%/全屏
- 语言：GDScript
- 类型：2D 俯视角波次生存射击
- 资源策略：优先运行时生成（像素图与合成音），减少外部资源依赖

约定：

- 全局单例放在 `scripts/autoload/`
- 场景在 `scenes/`，逻辑在 `scripts/`
- UI 场景在 `scenes/ui/`，UI 脚本在 `scripts/ui/`
- 大多数跨模块通信走信号（wave/hud/player）

## 2. 核心模块职责

### 2.1 全局管理（autoload）

- `scripts/autoload/game_manager.gd`
  - 场景切换（主菜单/角色选择/战斗）
  - 角色模板数据
  - 本局金币 `run_currency`
  - 本局武器库存 `run_weapons`（最多 6 把）
  - 武器定义池 `weapon_defs`（近战/远程）
  - 最近战绩缓存 `last_run_result`
  - 设置应用入口（窗口模式/按键映射/敌人血条显隐）

- `scripts/autoload/save_manager.gd`
  - `user://savegame/save.json` 读写
  - 字段兼容合并（避免老存档缺字段崩溃）
  - 聚合统计：全局最佳、按角色统计、最近战绩、成就
  - 设置结构持久化：`settings.system` + `settings.game`

- `scripts/autoload/audio_manager.gd`
  - 运行时合成提示音（射击/受击/击杀/拾取/按钮/波次）
  - 轻量 BGM（菜单与战斗）
  - 后续替换真实音频资源时，优先改这里

- `scripts/autoload/localization_manager.gd`
  - 管理当前语言（`zh-CN` / `en-US`）
  - 从 `i18n/*.json` 读取文案 key
  - 提供 `tr_key(key, params)` 与 `language_changed` 信号

### 2.2 战斗核心

- `scripts/game.gd`
  - 生成玩家与地形
  - 挂接波次信号与 HUD 信号
  - 处理升级选择、回合间隔、暂停、结算
  - 处理摄像机缩放按键（`camera_zoom_in`/`camera_zoom_out`）
  - 触控输入转发到 Player
  - 波次开始：玩家传送到地图中心
  - 波次结束：清除剩余敌人（`enemies` 组）与子弹（`bullets` 组）
  - `get_player_for_pause()`：供暂停菜单展示玩家数值

- `scripts/player.gd`
  - 键盘+触控移动融合
  - 支持可配置移动惯性（`inertia_factor`）
  - 自动索敌与开火
  - 无敌帧/受伤/死亡
  - 升级应用（伤害、射速、穿透、多弹等）
  - 地形减速效果合并
  - 持有 `CharacterTraitsBase`，通过 `get_final_damage`、`get_elemental_enchantment` 供武器参与数值计算

- `scripts/characters/character_traits_base.gd` 及子类
  - 角色特质基类（Resource），供 Player 持有
  - 子类可重写 `get_damage_multiplier`、`get_elemental_enchantment`、`get_weapon_damage_bonus`、`get_speed_multiplier`、`get_max_health_multiplier`
  - 武器/子弹通过 Player 调用 `get_final_damage` 获取经角色修正后的伤害

- `scripts/weapon.gd`
  - 冷却射击
  - 扇形扩散（`pellet_count` + `spread_degrees`）
  - 子弹穿透（`bullet_pierce`）

- `scripts/bullet.gd`
  - 子弹寿命与命中
  - 同目标去重命中
  - 穿透后延迟销毁
  - 加入 `bullets` 组，波次结束时统一清除
  - 玩家子弹支持 `bullet_type` / `bullet_color` 区分外观与命中反馈

- `scripts/enemy_bullet.gd` + `scenes/enemy_bullet.tscn`
  - 敌人专用子弹：继承 bullet，个头更大（10x10 像素、collision_radius=6）、速度更慢（约 180–190）
  - 使用 `assets/bullets/enemy_bullet.png` 专用像素图
  - enemy_ranged、enemy_boss 使用此场景

- `scripts/pickup.gd`
  - 掉落物（金币/治疗）
  - 金币按价值分级着色（铜/银/金）
  - 金币吸收：玩家进入 `absorb_range` 后飞向玩家并缩小，带动画
  - 自动飘动与超时销毁

### 2.3 敌人与波次

- `scripts/enemy_base.gd`
  - 通用生命/接触伤害
  - 接触持续伤害：玩家与 HurtArea 重叠时，按 `contact_damage_interval` 持续造成伤害（`_on_contact_timer_timeout` 检查重叠并再次施加）
  - 地形速度系数（与玩家规则一致）
  - `apply_knockback(dir, force)`：受击击退，累加冲击速度并每帧衰减

- `scripts/enemy_melee.gd`：追击型
- `scripts/enemy_ranged.gd`：保持距离并射击
- `scripts/enemy_tank.gd`：高血低速
- `scripts/enemy_boss.gd`：Boss 波扇形弹幕

- `scripts/wave_manager.gd`
  - 波次推进、敌人构成、难度缩放
  - 清场信号、击杀信号、间隔信号、波次倒计时信号 `wave_countdown_changed`
  - `wave_duration`：每波最大时长（秒），倒计时归零视为波次结束
  - 波次结束条件：全灭敌人 或 倒计时归零
  - 出生点多人：`spawn_positions_count` 个出生点，单出生点可产生多个敌人，`spawn_telegraph` 显示数量（×N）
  - 掉落生成（使用 `call_deferred` 避免 physics flushing 报错）
  - Boss 额外金币掉落与掉落概率配置
  - 生成规则：边界内随机、避开玩家安全半径、提示后落地

### 2.4 地形系统

- `scripts/terrain_zone.gd`
  - 统一草丛/浅水/深水逻辑
  - 进入时设置速度倍率，离开时清除
  - 深水支持持续伤害（DOT）

- 在 `game.gd::_spawn_terrain_map()` 中使用“簇团式分层生成”：
  - 先铺浅灰可移动地面块（FloorLayer）
  1. 深水（严格占位）
  2. 浅水（与深水互斥）
  3. 障碍物（全图散布，避让所有水域，障碍物间保留间距）
  4. 草丛（严格无重叠，避让水域与障碍）
  - 最后生成四周边界（实体阻挡）
  - **所有地形不得重叠**，各地形间保持配置的 padding 间距

- 每关各地形数量在 `*_count_min` ~ `*_count_max` 范围内随机

- 地形色块统一配置入口：`resources/terrain_colors.tres`，由 `game.gd` 直接引用（`@export var terrain_colors`）

地形冲突规则（严格无重叠）：

| 地形A \\ 地形B | 深水 | 浅水 | 障碍 | 草丛 |
| --- | --- | --- | --- | --- |
| 深水 | 禁止 | 禁止 | 禁止 | 禁止 |
| 浅水 | 禁止 | 禁止 | 禁止 | 禁止 |
| 障碍 | 禁止 | 禁止 | 禁止 | 禁止 |
| 草丛 | 禁止 | 禁止 | 禁止 | 禁止 |

说明：

- “障碍全图散布”通过网格 cell + 随机抖动实现，避免只在局部聚堆。
- 可移动地面采用浅灰色棋盘块，提升空间可读性。
- 边界使用与障碍同碰撞层，玩家和敌人均不可越界。

### 2.5 HUD 与菜单

- `scripts/ui/hud.gd`
  - 战斗信息（血量/波次/击杀/时间/金币）
  - 波次倒计时（正上方）、间隔倒计时与波次横幅
  - 升级三选一面板（运行时构建）
  - 武器商店（仅在波次完成后出现，标题显示完成波次）
  - 升级/商店结算层使用全屏纯色不透明 backdrop
  - 触控按钮（移动 + 暂停）

- `scripts/ui/result_panel_shared.gd`（Autoload）
  - 结算/死亡/通关界面共享 UI 构建逻辑
  - `build_score_block(wave, kills, time, best_wave, best_time)`：得分区（波次、击杀、时间、新纪录标记）
  - `build_player_stats_block(hp_current, hp_max, speed, inertia, weapon_details)`：玩家信息区（HP、移速、惯性、武器卡片）
  - 供 pause_menu、game_over_screen、victory_screen 复用

- `scripts/ui/game_over_screen.gd` + `scenes/ui/game_over_screen.tscn`
  - 死亡结算界面：CanvasLayer layer=100，全屏遮罩 + 居中 Panel
  - 展示标题「游戏结束」、得分区、玩家信息区、仅「返回主菜单」按钮
  - 接口：`show_result(wave, kills, time, player_node)`

- `scripts/ui/victory_screen.gd` + `scenes/ui/victory_screen.tscn`
  - 通关结算界面：布局与死亡界面一致，标题「通关」
  - 接口：`show_result(wave, kills, time, player_node)`

### 2.6 武器系统

- 角色默认不带攻击，必须装备武器才能输出
- 武器分层：
  - 统一基类：`scripts/weapons/weapon_base.gd`
  - 近战基类：`scripts/weapons/weapon_melee_base.gd`
  - 远程基类：`scripts/weapons/weapon_ranged_base.gd`
  - 具体武器：`scripts/weapons/melee/*.gd` 与 `scripts/weapons/ranged/*.gd`
- 每把武器独立冷却与独立伤害结算
- 近战采用“挥击位移 + 碰触判定”：
  - 仅武器碰触敌人时生效
  - `touch_interval` 按“每把武器 x 每个敌人”独立计时
- 远程子弹从武器节点位置发射，不再固定从玩家中心出生
- 子弹按 `bullet_type` 区分：pistol（手枪 4x4）、shotgun（霰弹 6x6）、rifle（机枪 8x2）、laser（法杖 12x2），颜色取自武器 `color`
- 分类型射击音效：`AudioManager.play_shoot_by_type(type)` 对应不同音高与时长
- 命中反馈：击退（`enemy_base.apply_knockback`）、命中闪烁（颜色与子弹一致）
- 武器数值集中配置于：`resources/weapon_defs.gd`，远程武器需配置 `bullet_type`
- 玩家默认最多持有 6 把武器，并在玩家周围显示色块
- 流程：
  1. 开局默认装备短刃（blade_short）直接开始波次
  2. 每波结算先属性升级，再进入武器商店（金币购买或跳过），商店标题显示“第 N 波完成”

- `scripts/ui/main_menu.gd`
  - 显示总统计、最近战绩、成就数量
  - 设置入口按钮（弹出 `settings_menu`）

- `scripts/ui/character_select.gd`
  - 显示角色属性 + 该角色历史战绩

- `scripts/ui/pause_menu.gd`
  - 暂停按钮逻辑
  - 全屏左右分栏布局：左侧系统信息（标题、按键提示、继续/主菜单），右侧玩家信息（调用 `ResultPanelShared.build_player_stats_block` 构建 HP、移速、惯性、装备武器）
  - Root 设置为 `MOUSE_FILTER_IGNORE`，避免吞掉 HUD 点击
  - 暂停层新增全屏纯色不透明 backdrop
  - 面板样式强制不透明，保证暂停文本可读
  - 显示当前可操作按键（随改键同步）
  - 显示玩家当前 HP、移速、惯性及装备武器详情（每把武器的伤害、冷却、范围及近战/远程专属属性）；武器卡片在 HBox 中横向排列

- `scripts/ui/settings_menu.gd`
  - 全屏展示布局（与暂停页类似）：Panel 铺满、OuterMargin 边距、CenterContainer 居中内容
  - 系统分页：主音量、分辨率
  - 游戏分页：移动键预设、移动惯性、暂停键、血条切换键、敌人血条开关、暂停提示开关
  - 设置层新增全屏纯色不透明 backdrop
  - 面板样式强制不透明，避免底层画面干扰设置阅读
  - 修改即生效并自动保存

## 3. 当前数据流

```mermaid
flowchart TD
    mainMenu[MainMenu]
    characterSelect[CharacterSelect]
    gameScene[GameScene]
    gameManager[GameManager]
    saveManager[SaveManager]
    audioManager[AudioManager]
    waveManager[WaveManager]
    terrainZone[TerrainZone]
    player[Player]
    enemies[Enemies]
    hud[HUD]
    pickup[Pickup]

    mainMenu -->|"newGame"| characterSelect
    characterSelect -->|"startNewGame"| gameManager
    gameManager -->|"changeScene"| gameScene

    gameScene -->|"spawnPlayer"| player
    gameScene -->|"setup"| waveManager
    gameScene -->|"spawnTerrain"| terrainZone
    waveManager -->|"spawn"| enemies

    player -->|"autoShoot"| enemies
    enemies -->|"contact/bullet"| player
    terrainZone -->|"speedMod/dot"| player
    terrainZone -->|"speedMod/dot"| enemies
    waveManager -->|"drop"| pickup
    pickup -->|"heal/gold"| player

    waveManager -->|"wave/kill/intermission"| hud
    hud -->|"upgradeSelected/mobileMove"| gameScene
    gameScene -->|"saveRunResult"| gameManager
    gameManager -->|"updateRunResult"| saveManager
    gameScene -->|"playSfxBgm"| audioManager
```

### 3.5 数值计算流程

伤害计算由武器发起，经 Player 委托给 CharacterTraits 参与修正：

1. **近战**：`weapon_melee_base._apply_touch_hits()` 若 owner 有 `get_final_damage`，则用其替代武器 `damage`，并获取 `get_elemental_enchantment` 传入 `enemy.take_damage(amount, elemental)`
2. **远程**：`weapon_ranged_base._start_attack()` 若 owner 有 `get_final_damage`，则计算最终伤害并设置到 bullet，同时设置 `elemental_type`
3. **敌人**：`enemy_base.take_damage(amount, elemental)` 的 `elemental` 参数预留抗性/DOT 扩展

### 3.6 玩家受击与伤害缓冲

- **多伤害源取最大**：子弹、接触、地形 DOT 等调用 `player.take_damage(amount)` 时，伤害先缓冲到 `_pending_damages`，帧末取最大值后统一结算，避免同帧多源叠加秒杀
- **无敌帧**：受击后 `invulnerable_duration`（默认 0.5 秒）内不再接受伤害
- **受击音效**：`AudioManager.play_hit()` 使用专用通道，播放中不重叠，避免同帧多次受击时音效堆叠

## 4. 关键配置项

### 4.1 `game.gd`

- `victory_wave`：通关波次（默认 5），达到该波次时显示通关界面并跳过升级/商店流程
- `grass_count_min` / `grass_count_max`：草丛数量范围（默认 4~9），每关随机
- `shallow_water_count_min` / `shallow_water_count_max`：浅水数量范围（默认 3~6）
- `deep_water_count_min` / `deep_water_count_max`：深水数量范围（默认 2~5）
- `obstacle_count_min` / `obstacle_count_max`：障碍数量范围（默认 4~8）
- `terrain_margin`：生成边界留白
- `placement_attempts`：单块最大尝试次数
- `water_padding`：水域互斥间距（默认 8）
- `obstacle_padding`：障碍物最小间距（默认 10）
- `grass_padding`：草丛与其它地形最小间距（默认 4）
- `floor_tile_size`：可移动地面块尺寸
- `floor_color_a` / `floor_color_b`：可移动地面块配色（fallback，优先用 terrain_colors.tres）
- `boundary_thickness`：地图边界厚度（边界碰撞体不可见，仅保留碰撞）
- `boundary_color`：地图边界颜色（fallback，当前边界无视觉）
- `camera_zoom_scale`：摄像机缩放系数（0.7 更远、1.3 更近，默认 0.6 会在初始化时 clamp 到 0.7～1.3）
- `camera_zoom_min` / `camera_zoom_max`：缩放范围（默认 0.7～1.3）
- `camera_zoom_step`：每次按键变化量（默认 0.05）
- `camera_dead_zone_ratio`：玩家偏离中心超过此比例时摄像机开始跟随（默认 0.30）
- `*_cluster_count`：每类地形簇数量
- `*_cluster_radius`：每类簇半径
- `*_cluster_items`：每簇生成块数量范围
- `_upgrade_pool`：升级候选池

**LevelConfig 地形扩展**（`resources/level_config.gd`）：
- `map_size_scale`：地图大小系数，0.8=小、1.0=中、1.2=大
- `default_terrain_type`：默认地形类型，`flat`=平地、`seaside`=海边、`mountain`=山地；地板瓦片按此选择像素图（terrain_atlas 第 0/1/2 行），默认 `flat`

**摄像机**（`GameCamera2D`）：
- 缩放由 `camera_zoom_scale` 控制，可通过按键 `=`/`-`（`camera_zoom_in`/`camera_zoom_out`）调节
- 当地图大于可视区域时跟随玩家，保持玩家在 `camera_dead_zone_ratio` 死区内
- 敌人生成区域与 `get_playable_bounds()` 对齐

### 4.2 `wave_manager.gd`

- `wave_duration`：每波最大时长（秒），倒计时归零视为波次结束（默认 20）
  - 倒计时每帧扣减的 delta 被限制为最多 0.5 秒，避免首帧或切回标签页时 delta 过大导致波次瞬间结束
- `intermission_time`：波次间隔
- `spawn_min_player_distance`：与玩家的最小出生距离（默认 340）
- `spawn_positions_count`：出生点数量，单出生点可产生多个敌人（默认 5）
- `spawn_attempts`：合法出生点采样重试次数
- `spawn_region_margin`：出生区域边界留白
- `telegraph_enabled`：是否启用出生提示
- `telegraph_duration`：提示持续时长
- `telegraph_show_ring`：是否显示警示圈
- `telegraph_show_countdown`：是否显示倒计时
- `coin_drop_chance`：金币掉落概率（默认 0.38）
- `heal_drop_chance`：治疗掉落概率（默认 0.17）
- `boss_bonus_coin_count`：Boss 额外掉落金币数量范围（默认 `2~3`）
- `tank_scene/boss_scene`：进阶敌人
- `aquatic_scene`：水中专属敌人，仅在有水域时在水域内生成
- `dasher_scene`：冲刺攻击敌人，波次 ≥ 2 时生成
- `coin_pickup_scene/heal_pickup_scene`：掉落资源
- `telegraph_scene`：出生提示节点场景

### 4.3 `game_manager.gd`

- `characters`：角色模板（含多弹/穿透字段）
- `characters[].traits_path`：角色特质脚本路径，供 Player 加载并参与数值计算
- `weapon_defs`：启动时从 `resources/weapon_defs.gd::WEAPON_DEFS` 载入

### 4.4 `terrain_zone.gd`

- `terrain_type`
- `speed_multiplier`
- `damage_per_tick`
- `damage_interval`
- 水域（`shallow_water`/`deep_water`）时对进入 body 设置 `water_zone_count` meta，供水中敌人 `_is_in_water()` 判断

### 4.5 地形色块统一配置

- `resources/terrain_colors.tres`：地形色块统一入口，含 `floor_a`、`floor_b`、`boundary`、`obstacle`、`grass`、`shallow_water`、`deep_water`
- `resources/terrain_color_config.gd`：Resource 脚本，定义上述颜色字段
- `game.gd` 通过 `@export var terrain_colors` 直接引用，`_get_terrain_color(key, fallback)` 优先从该配置读取

### 4.6 美术资源解耦与独立配置

- 各实现类自行绑定所需美术，不再通过 `VisualAssetRegistry` 集中管理纹理路径
- **Player**：`player.gd` 的 `@export_file texture_sheet`、`texture_single`、`frame_size`、`sheet_columns`、`sheet_rows`
- **Enemies**：`enemy_base.gd` 的 `@export_file texture_sheet`、`texture_single`，各敌人场景在 Inspector 配置
- **Bullet**：`bullet.gd` 的 `@export_file texture_path`、`@export collision_radius`，武器 def 的 `bullet_texture_path`、`bullet_collision_radius`
- **近战挥击**：`weapon_melee_base.gd` 的 `@export_file swing_texture_path`、`@export swing_frame_size`，weapon_defs 的 `swing_texture_path`
- **武器图标**：weapon_defs 的 `icon_path`，HUD/player 从 option 或 weapon 节点读取
- **掉落物**：`pickup.gd` 的 `@export_file texture_coin`、`texture_heal`
- **升级图标**：`_upgrade_pool` 的 `icon_path`，HUD 从 option 读取
- **VisualAssetRegistry**：仅保留 `make_color_texture(color, size)` 作为纯色贴图工具

### 4.7 默认地形与像素图

- `resources/default_terrain_colors.gd`：默认地形 3 种配色（flat/seaside/mountain），供 Polygon2D 回退使用
- `terrain_atlas.png`：3 行 x 7 列，第 0/1/2 行分别为 flat、seaside、mountain 地板瓦片
- 使用单层 TileMapLayer（Godot 4.6）：`_terrain_layer` 先铺满默认地形，再覆盖草/水/障碍
- `_spawn_walkable_floor` 优先使用 TileMapLayer 像素图，按 `default_terrain_type` 选择 atlas 行；无 TileMapLayer 时回退 Polygon2D

### 4.8 武器配置

- `resources/weapon_defs.gd::WEAPON_DEFS` 字段说明：
  - `id`, `type`, `name_key`, `desc_key`, `cost`, `color`
  - `script_path`（具体武器脚本路径）
  - `icon_path`（武器图标路径，HUD/武器环使用）
  - `swing_texture_path`（近战挥击纹理，仅近战）
  - `bullet_texture_path`、`bullet_collision_radius`（远程子弹，仅远程）
  - `stats`（示例：`damage`, `cooldown`, `range`, `touch_interval`, `swing_duration`, `swing_degrees`, `swing_reach`, `hitbox_radius`, `bullet_speed`, `pellet_count`, `spread_degrees`, `bullet_pierce`）

### 4.9 多语言配置

- 语言文件：
  - `i18n/zh-CN.json`
  - `i18n/en-US.json`
- 存档字段：
  - `save.json.language`
- 入口：
  - 主菜单语言下拉（`main_menu.tscn` + `main_menu.gd`）
- 运行时刷新：
  - 各 UI 监听 `LocalizationManager.language_changed` 并重绘文本

### 4.10 设置结构（SaveManager）

`save.json.settings` 当前结构：

- `settings.system.master_volume`: `0.0~1.0`
- `settings.system.resolution`: 窗口模式 `50%`/`75%`/`100%`/`Fullscreen`（兼容旧格式 `1280x720` 等）
- `settings.game.key_preset`: `wasd/arrows`
- `settings.game.move_inertia`: `0.0~0.9`（角色移动惯性，越大越“滑”）
- `settings.game.pause_key`: 暂停键（字符串）
- `settings.game.toggle_enemy_hp_key`: 敌人血条切换键（字符串）
- `settings.game.show_enemy_health_bar`: 是否显示敌人血条
- `settings.game.show_key_hints_in_pause`: 暂停页是否显示按键提示

## 5. 常见扩展入口

### 5.1 新增升级项

1. 在 `game.gd::_upgrade_pool` 增加条目
2. 在 `player.gd::apply_upgrade()` 实现对应分支
3. 若需要新 UI 文案，可直接改 `hud.gd::show_upgrade_options()`

### 5.2 新增敌人

1. 继承 `enemy_base.gd`
2. 新建 `scenes/enemies/*.tscn`
3. 在 `wave_manager.gd::_start_next_wave()` 接入生成策略
4. 若需水中专属敌人：`is_water_only()` 返回 true，由 `terrain_zone` 维护 `water_zone_count` meta，离水时 `enemy_base` 自动施加伤害
5. 若需自定义出生点（如水中）：在 `get_enemy_spawn_orders` 返回的 order 中设置 `pos_override` 为 `Vector2`；`game.gd` 提供 `get_random_water_spawn_position()`、`has_water_spawn_positions()`

### 5.3 调整敌人出生规则（无需改代码）

优先调整 `wave_manager.gd` 导出参数：

1. `spawn_min_player_distance`：决定“刷脸”强度
2. `spawn_region_margin`：决定出生点离边界的安全空间
3. `spawn_attempts`：决定严格规则下的稳定性
4. `telegraph_duration`：决定玩家反应窗口
5. `telegraph_show_ring/show_countdown`：决定提示信息密度

### 5.4 新增地形效果

1. `game.gd::_spawn_terrain_map()` 增加生成逻辑
2. `terrain_zone.gd` 添加新效果字段与处理
3. 若是单位侧效果，扩展 Player/Enemy 的 terrain 接口
4. 在 `resources/terrain_colors.tres` 中添加新地形色块（若使用 ColorRect 显示）

如果是“只改分布规则不改效果”，优先调整：

1. `terrain_margin`（可通行空间）
2. `*_count_min` / `*_count_max`（每关各地形数量范围）
3. `*_cluster_count` 和 `*_cluster_radius`（簇团密度与自然感）
4. `water_padding` / `obstacle_padding` / `grass_padding`（各地形间最小间距）
4. `placement_attempts`（生成成功率）

### 5.5 真音频替换

1. 在 `audio_manager.gd` 中改 `play_*` 实现
2. 可保持对外 API 不变，避免改动调用方

### 5.6 新增一种语言

1. 在 `i18n/` 下新增语言 JSON（例如 `ja-JP.json`）
2. 在 `localization_manager.gd` 的 `LANGUAGE_FILES` 增加映射
3. 在 JSON 中补齐已有 key
4. 在主菜单下拉中验证切换和回退逻辑

### 5.7 扩展设置项

1. 在 `save_manager.gd` 的 `default_data.settings` 增加字段
2. 在 `settings_menu.gd` 新增控件并在 `_reload_from_save()` 绑定值
3. 在 `_save_and_apply()` 之后由 `game_manager.gd::apply_saved_settings()` 统一应用
4. 若涉及战斗运行时行为，在 `game.gd` 或对应模块监听输入并回写设置（如 `player.set_move_inertia()`）

### 5.8 新增武器

1. 在 `resources/weapon_defs.gd::WEAPON_DEFS` 增加武器定义（含 `script_path`）
2. 若是近战，新增 `scripts/weapons/melee/weapon_*.gd` 并继承 `weapon_melee_base.gd`
3. 若是远程，新增 `scripts/weapons/ranged/weapon_*.gd` 并继承 `weapon_ranged_base.gd`
4. 在 `player.gd::equip_weapon_by_id()` 中验证该脚本可实例化
5. 在 `texture_path_config.gd` 增加 `weapon_{id}` 属性，并在 `texture_paths.tres` 配置图标路径
5. 在 i18n 文件补齐 `weapon.*` 文案 key

### 5.9 新增角色特质

1. 在 `scripts/characters/` 下新增特质脚本，继承 `character_traits_base.gd`
2. 按需重写 `get_damage_multiplier`、`get_elemental_enchantment`、`get_weapon_damage_bonus`、`get_speed_multiplier`、`get_max_health_multiplier`
3. 在 `game_manager.gd::characters` 中为对应角色增加 `traits_path` 字段，指向新脚本路径

## 6. 常见问题与排障

> 每次修复 BUG 后须在 [BUG_LOG.md](BUG_LOG.md) 中记录（现象、原因、修复、预防）。执行 coding 计划前参考 BUG_LOG，避免同类问题。

### 6.1 `Can't change this state while flushing queries`

场景：碰撞回调链中直接 `add_child(Area2D)`  
解决：在 `wave_manager.gd` 使用 `call_deferred("add_child", node)`

### 6.2 `INTEGER_DIVISION` 告警

场景：`int(a / b)` 中 `a`、`b` 都是整型  
解决：改为浮点除法再转整型，如 `int(current_wave / 4.0)`

### 6.3 `SHADOWED_VARIABLE_BASE_CLASS`

场景：参数名与基类属性重名（例如 `visible`）  
解决：重命名参数（如 `show_hint`）

### 6.4 升级按钮点击无效

优先检查：

1. `pause_menu` 的全屏 Root 是否吞输入（应 `MOUSE_FILTER_IGNORE`）
2. 触控容器 `_touch_panel` 是否吞输入（应 `MOUSE_FILTER_IGNORE`）
3. 升级按钮是否因金币不足被 `disabled`

### 6.5 死亡/通关结算界面按钮无效

优先检查：

1. `game_over_screen` / `victory_screen` 使用 `CanvasLayer` layer=100、`process_mode=PROCESS_MODE_ALWAYS`，确保暂停时仍可响应
2. 居中 Panel 与 Backdrop 的 `mouse_filter=STOP`，按钮可点击
3. `game.gd` 中 `_on_player_died()` 调用 `game_over_screen.show_result()`，`_on_wave_cleared()` 在 `wave >= victory_wave` 时调用 `victory_screen.show_result()`

### 6.6 全屏/窗口缩放时画面只占一小块

原因：project.godot 固定 `viewport_width=1280`、`viewport_height=720` 作为设计尺寸，拉伸后可能留黑边。  
解决：
1. `project.godot` 使用 `aspect="ignore"` 强制填满（无黑边，可能轻微拉伸）
2. `game_manager.gd` 在应用窗口设置时调用 `_apply_content_scale_to_window()`，将根视口 `content_scale_size` 设为当前窗口尺寸，覆盖固定 1280×720
3. `game.gd` 中 `_resize_world_background()` 用 offset 动态设置 WorldBackground 尺寸

## 7. 验证清单

1. 主菜单可进入新游戏/继续游戏，统计展示正常
2. 角色页能显示按角色战绩
3. 波次推进正常，5 波有 Boss
4. 掉落可拾取（金钱/治疗）且无 flushing 报错
5. 升级面板可点击并进入下一波间隔
6. 地形交互生效（草丛/浅水/深水/障碍）
7. 设置菜单可用（音量/分辨率/按键/血条）且重启后保持
8. 暂停页按键提示与改键结果一致
9. 无 parser/lint 错误

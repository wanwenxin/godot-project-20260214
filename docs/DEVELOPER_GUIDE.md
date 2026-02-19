# Developer Guide

本文件面向维护该 Demo 的开发者，覆盖当前版本（含升级系统、地形系统、掉落、Boss、触控与音频）的架构说明与排障建议。按业务流程与功能模块组织的代码索引见 [CODE_INDEX.md](CODE_INDEX.md)。词条完整列表见 [AFFIX_CATALOG.md](AFFIX_CATALOG.md)。

## 1. 技术栈与项目约定

- 引擎：Godot 4.x
- 显示：设计分辨率固定 1280×720，`aspect="keep"` 等比例缩放，多余区域留黑边；`content_scale_size` 固定为设计尺寸；窗口支持 50%/75%/100%/全屏
- 语言：GDScript
- 类型：2D 俯视角波次生存射击
- 资源策略：优先运行时生成（像素图与合成音），减少外部资源依赖

约定：

- 全局单例放在 `scripts/autoload/`
- 场景在 `scenes/`，逻辑在 `scripts/`
- UI 场景在 `scenes/ui/`，UI 脚本在 `scripts/ui/`
- **固定布局 UI**：不随数据变动的结构在 `.tscn` 中编辑，脚本仅通过 @onready 引用、控制显隐与填充内容；**动态位置或数量**（如每敌一个血条、列表项）使用预制场景实例化。
- 大多数跨模块通信走信号（wave/hud/player）

## 2. 核心模块职责

### 2.1 全局管理（autoload）

- `scripts/autoload/object_pool.gd`
  - 对象池：对子弹、掉落物等高频实例化对象做池化，减少 instantiate/queue_free 开销
  - `acquire(scene, parent, deferred)`：从池中获取或实例化，加入 parent；deferred=true 时用 call_deferred 避免 physics flushing
  - `recycle(node)`：回收到池；非池化实例则 queue_free
  - `recycle_group(group_name)`：批量回收指定组内可池化节点
  - 池化节点需实现 `reset_for_pool()` 重置状态；bullet/pickup 已支持

- `scripts/autoload/game_manager.gd`
  - 场景切换（主菜单/角色选择/战斗）
  - 角色模板数据
  - 本局金币 `run_currency`（新游戏/继续默认 500）、本局总伤害 `run_total_damage`（结算展示，`add_record_damage_dealt` 记录）、经验值 `run_experience`、等级 `run_level`
  - 本局武器库存 `run_weapons`（每项 `{id, tier, random_affix_ids}`，最多 6 把；手动合成，`merge_run_weapons`）
  - 商店刷新次数 `shop_refresh_count`（新游戏/继续重置）；刷新费用 `get_shop_refresh_cost(wave)`，`try_spend_shop_refresh(wave)` 扣费并 +1
  - 本局已购道具 `run_items`（道具 id 列表）
  - 本局玩家相关升级 `run_upgrades`（每项 `{id, value}`，供词条系统聚合）
  - 本局武器相关升级 `run_weapon_upgrades`（升级 id 列表，同步武器时应用）
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

- `scripts/autoload/affix_manager.gd`
  - 词条系统：从 run_items、run_upgrades 收集词条，聚合效果并应用到玩家
  - `collect_affixes_from_player(player)`：按类型分组收集
  - `get_aggregated_effects(affixes)`：按 effect_type 聚合
  - `refresh_player(player)`：收集、聚合、应用
  - `get_visible_affixes(affixes)`：供 UI 展示可见词条
  - `check_combos(affixes)`：预留组合效果扩展点

- `scripts/autoload/log_manager.gd`
  - 将调试器面板的报错与警告输出到 `user://logs/game_errors.log`
  - 捕获 `push_error`、`push_warning`、`printerr`、GDScript 运行时错误
  - 依赖 Godot 4.5+ 的 `OS.add_logger` / `Logger` 接口

- `scripts/autoload/game_constants.gd`
  - 游戏内视觉与数值常量：角色/敌人/BOSS/子弹缩放、摄像机、地形、波次、经验等系数与默认值，统一在此修改
  - 含 `PLAYER_SCALE`、`ENEMY_SCALE`、`BOSS_SCALE`、`BULLET_SCALE`、`CAMERA_*`、`TERRAIN_*`、`WAVE_*`、`XP_BASE`/`XP_CURVE` 等（详见 §4 关键配置项）

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
  - 导航系统：`NavigationRegion2D` 子节点，`_spawn_obstacle` 记录 `_obstacle_rects`，`_spawn_terrain_map` 结束后 `call_deferred("_bake_navigation")`；`_bake_navigation()` 使用 `NavigationMeshSourceGeometryData2D` 烘焙可玩区域为可行走区、障碍物为孔洞，供敌人 `NavigationAgent2D` 寻路

- `scripts/player.gd`
  - 键盘+触控移动融合
  - 支持可配置移动惯性（`inertia_factor`）
  - 自动索敌与开火
  - 受伤/死亡；**碰撞与无敌**：`collision_mask = 8`（不检测 layer 2 敌人），玩家可穿过敌人，接触伤害由敌人 HurtArea 触发；`take_damage(amount, from_contact)`：`from_contact=true` 为碰撞伤害，有 `_contact_invulnerable_timer` 无敌；远程伤害（`from_contact=false`）无无敌时间
  - 扩展属性：血量上限、魔力上限、护甲、近战/远程伤害加成、血量/魔力恢复、吸血概率（由词条系统聚合）
  - 魔法槽（最多 3 个），按 Q/E/R 释放
  - 升级应用：玩家相关升级走词条系统，武器相关升级传递至每把武器
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
  - 子弹寿命与命中：玩家子弹用 `life_time` 超时销毁；敌人子弹（`hit_player=true`）出界前不消失，仅当超出可玩区域时销毁
  - 同目标去重命中
  - 穿透后延迟销毁
  - 加入 `bullets` 组，波次结束时 ObjectPool.recycle_group 批量回收
  - 玩家子弹支持 `bullet_type` / `bullet_color` 区分外观与命中反馈
  - 对象池支持：`reset_for_pool()` 清空 `_hit_targets`；命中/超时后 `_recycle_or_free()` 回池

- `scripts/enemy_bullet.gd` + `scenes/enemy_bullet.tscn`
  - 敌人专用子弹：继承 bullet，个头更大（10x10 像素、collision_radius=6）、速度更慢（约 180–190）
  - 使用 `assets/bullets/enemy_bullet.png` 专用像素图
  - enemy_ranged、enemy_boss 使用此场景

- **体积与子弹**：缩放倍率与敌人子弹速度统一在 autoload `GameConstants`（[scripts/autoload/game_constants.gd](scripts/autoload/game_constants.gd)）中配置：玩家/普通敌人用 `PLAYER_SCALE`/`ENEMY_SCALE`（默认 3），BOSS 用 `BOSS_SCALE`（默认 15），子弹用 `BULLET_SCALE`（默认 2），敌人血条上元素图标用 `ELEMENT_ICONS_SCALE`（默认 0.1），敌人子弹速度为 `ENEMY_BULLET_SPEED`（默认 126）。
- **元素附着与反应**（`enemy_base.gd`）：
  - `take_damage(amount, _elemental, _element_amount)`：当 `_element_amount > 0` 时对敌人增加对应元素量（`_element_amounts` 字典）。
  - 元素量档位：少量 1、大量 10、巨量 20；武器=1，魔法=10。
  - 每累计 1 秒执行一次衰减：每种元素量减 1，为 0 则移除。若存在至少两种元素且量均 > 0，取两种等量消耗（`consumed = min(量A, 量B)`），两者减去 consumed 后根据元素类型触发**元素反应**（如 fire+ice→融化伤害、fire+lightning→过载伤害+击退、ice+lightning→超导伤害等）；反应仅造成无元素伤害，避免二次附着。
  - **元素图标 UI**：血条上方横向排布当前附着元素的小图标（4×4，多元素全部显示），fire/ice/lightning/poison/physical 均用 `assets/magic/icon_*.png`（见 `_get_element_icon_texture`）；某元素量不足 5 点时该图标每约 250ms 半透明/不透明交替闪烁。显隐与血条一致（`set_healthbar_visible`）。
  - 寻路时尽量不重叠：`NavigationAgent2D.avoidance_enabled = true`，`radius` 按碰撞圆半径×scale 设置，`max_neighbors`/`neighbor_distance` 用于 RVO 避障。
  - 扩展：新增元素类型或反应组合时，在 `_trigger_element_reaction` 中补充 (elem_a, elem_b) 分支与效果。

- `scripts/pickup.gd`
  - 掉落物（金币/治疗）
  - 金币按价值分级着色（铜/银/金）
  - 金币吸收：玩家进入 `absorb_range` 后飞向玩家并缩小，带动画
  - 自动飘动与超时销毁
  - 对象池支持：`configure_for_spawn(type, value)` 配置类型与纹理；`reset_for_pool()` 重置状态；拾取/超时后 `_recycle_or_free()` 回池

### 2.3 敌人与波次

- `resources/enemy_defs.gd`
  - 敌人定义集中化：36 种敌人（6 原有 + 30 扩展），含 `tier`（normal/elite/boss）、`base_id`、`behavior_mode`、`scene_path`、`name_key`、`desc_key`、`icon_path`
  - 行为模式：`CHASE_DIRECT`(0) 直线追击、`CHASE_NAV`(1) 寻路追击、`KEEP_DISTANCE`(2) 保持距离、`FLANK`(3) 侧翼包抄、`CHARGE`(4) 蓄力冲刺、`BOSS_CUSTOM`(5) Boss 自定义
  - `get_enemy_def(id)`、`get_ids_by_tier(tier)` 供图鉴与生成使用

- `resources/enemy_scene_registry.gd`（Autoload `EnemySceneRegistry`）
  - `id -> PackedScene` 映射，`get_scene(enemy_id)` 供 wave_manager 按 enemy_id 加载场景

- `scripts/enemy_base.gd`
  - 死亡时播放差异化动画（按 `enemy_type`：melee 闪灭缩小、ranged 淡出旋转、tank 碎裂、boss 爆炸、aquatic 水花、dasher 拖尾），动画结束后 emit `died` 并 `queue_free`
  - 通用生命/接触伤害
  - `exp_value`：击败该敌人获得的经验值，各敌人在场景中配置
  - 接触持续伤害：玩家与 HurtArea 重叠时，按 `contact_damage_interval` 持续造成伤害（`_on_contact_timer_timeout` 检查重叠并再次施加）
  - 地形速度系数（与玩家规则一致）
  - `apply_knockback(dir, force)`：受击击退，累加冲击速度并每帧衰减
  - `enemy_id`：若设置则从 EnemyDefs 取 `behavior_mode`，并创建 `NavigationAgent2D`（CHASE_NAV/FLANK/KEEP_DISTANCE 时）
  - 寻路移动：`_move_towards_player_nav`、`_move_away_nav`、`_move_towards_flank_nav` 供不同行为模式使用

- `scripts/enemy_melee.gd`：追击型（支持 CHASE_NAV/FLANK 寻路）
- `scripts/enemy_ranged.gd`：保持距离并射击（KEEP_DISTANCE 时用寻路靠近/远离）
- `scripts/enemy_tank.gd`：高血低速
- `scripts/enemy_boss.gd`：Boss 波扇形弹幕
- `scripts/enemy_aquatic.gd`：水中专属，离水扣血
- `scripts/enemy_dasher.gd`：蓄力冲刺（CHARGE 行为）

- `scripts/wave_manager.gd`
  - 波次推进、敌人构成、难度缩放
  - 清场信号、击杀信号、间隔信号、波次倒计时信号 `wave_countdown_changed`
  - 预生成倒计时：`pre_spawn_countdown`（默认 3 秒）、`start_pre_spawn_countdown()` 由 game 在地形刷新完成后调用；`pre_spawn_countdown_started`、`pre_spawn_countdown_changed` 供 HUD 显示
  - 波次开始流程：emit `wave_started` → game 重置玩家、刷新地图 → 地形完成后调用 `start_pre_spawn_countdown` → 倒计时结束才生成第 1 批敌人
  - `start_next_wave_now()`：跳过间隔，商店点击下一波时调用，立即进入上述流程
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
  - 战斗信息（血量/魔力条/护甲/经验条/等级/波次/击杀/时间/金币）
  - 魔力条与护甲由 `game.gd` 在 `_process` 中从 player 读取并调用 `set_mana`、`set_armor`
  - HUD 脏检查：`set_mana`、`set_armor`、`set_health`、`set_magic_ui` 等入口在值未变时 early return，减少每帧 StyleBox 重建与 Label 赋值；魔法冷却遮罩按 remaining_cd 变化阈值（0.05s）节流
  - 魔法面板：左下角，横向排列已装备魔法，当前选中绿色边框，独立冷却遮罩；`set_magic_ui(magic_data)` 由 game 每帧传入 `player.get_magic_ui_data()`
  - 多行按键提示：移动、暂停、镜头缩放、魔法、敌人血条（复用 `ResultPanelShared.action_to_text`）
  - 波次倒计时（中上）：预生成/间隔时「第X波-X.Xs」，波次进行中「第X波-剩余Xs」；波次横幅
  - 波次横幅与倒计时文字特效：描边、缩放动画
  - 各模块独立背景（PanelContainer + StyleBoxTexture 程序生成纹理，九宫格拉伸）
  - 升级/商店卡片间距 24、统一基准字号 18
  - 升级四选一面板（可金币刷新，等级越高奖励越多）
  - 商店：TabContainer（商店 / 背包 / 角色信息），Tab 置于底部；商店 Tab 含武器 4 件 + 刷新按钮（刷新费用 1+refresh_count*(1+wave*0.15)）；背包 Tab 打开背包覆盖层；角色信息 Tab 展示 build_player_stats_block(stats_only=true)
  - 商店角色信息 Tab 脏检查：`_update_shop_stats_tab` 对 stats 做轻量哈希，未变时跳过重建
  - 背包覆盖层复用：`game.gd::_show_backpack_from_shop` 关闭时仅 hide，再次打开时 show + set_stats，避免重复 load/new BackpackPanel
  - 升级/商店结算层使用全屏纯色不透明 backdrop
  - 触控按钮（移动 + 暂停）

- `scripts/ui/result_panel_shared.gd`（Autoload）
  - 结算/死亡/通关界面共享 UI 构建逻辑
  - `action_to_text(actions)`：将 InputMap 动作名转为按键字符串，供 HUD、暂停菜单按键提示复用
  - `build_score_block(wave, kills, time, best_wave, best_time, gold?, total_damage?)`：得分区（波次、击杀、时间、金币、总伤害、新纪录标记）
  - `build_player_stats_block(stats, ..., stats_only)`：玩家信息区；`stats_only=true` 时仅构建角色属性区（供暂停菜单属性 Tab）；默认完整展示武器/道具/词条/魔法（供死亡/通关界面）；`stats.weapon_set_bonus_info` 含 2/4/6 件套装完整展示，生效档位高亮
  - 统一基准字号 `BASE_FONT_SIZE`（18）
  - 供 pause_menu、game_over_screen、victory_screen 复用

- `scripts/ui/game_over_screen.gd` + `scenes/ui/game_over_screen.tscn`
  - 死亡结算界面：CanvasLayer layer=100，全屏遮罩 + 居中 Panel
  - TabContainer（得分 / 背包 / 角色信息），Tab 置于顶部；得分 Tab 含标题、得分区（波次/击杀/时间/金币/总伤害）、返回主菜单；背包 Tab 复用 BackpackPanel（只读）；角色信息 Tab 展示完整玩家信息
  - 接口：`show_result(wave, kills, time, player_node)`

- `scripts/ui/victory_screen.gd` + `scenes/ui/victory_screen.tscn`
  - 通关结算界面：布局与死亡界面一致，TabContainer（得分 / 背包 / 角色信息）
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
- **武器元素词条**：`weapon_base.weapon_element` 来自 def 的 `element_affix_id`（固定）或商店随机元素词条；攻击时若有元素则对敌人附着元素量 1（少量）；武器与魔法各自至多一种元素。

### 2.7 词条系统

- 词条附着于武器、魔法、道具，用于限定范围、批量应用效果，使效果与具体物体解耦
- 类层次：`AffixBase`（基类）→ `WeaponAffix`、`MagicAffix`、`ItemAffix`（三子类）
- 词条库：`resources/item_affix_defs.gd`、`weapon_affix_defs.gd`、`magic_affix_defs.gd`，互不干涉
- 物体定义可带 `affix_ids: []`，运行时（商店购买、升级选择）可追加
- 词条分可见/不可见，可见词条在暂停菜单、结算面板展示
- **数值可调节**：词条定义中的 `base_value` 为默认值；绑定时（如 `shop_item_defs` 的 item 中 `base_value`）可指定具体值覆盖，`AffixManager.collect_affixes_from_player` 优先使用绑定值
- **武器词条分类**：`weapon_affix_defs` 中 `weapon_type` 为 `melee` | `ranged` | `both`，供 UI 筛选与展示
- **武器元素词条池**：`weapon_affix_defs.gd` 的 `WEAPON_ELEMENT_AFFIX_POOL`（fire/ice/lightning/poison/physical），`effect_type: "element"`；`get_affix_def` 同时查找数值词条池与元素词条池。商店刷新时，仅当武器 def 无 `element_affix_id` 时以约 15% 概率追加 1 个随机武器元素词条。
- 效果应用流程：`AffixManager.collect_affixes_from_player` → `get_aggregated_effects` → `_apply_affix_aggregated` 写入玩家
- 组合效果扩展：`resources/affix_combo_defs.gd` 配置，`AffixManager.check_combos` 检测
- 武器数值集中配置于：`resources/weapon_defs.gd`，远程武器需配置 `bullet_type`
- 玩家默认最多持有 6 把武器，并在玩家周围显示色块
- **品级系统**：`run_weapons` 每项为 `{id, tier, random_affix_ids}`；手动合成：背包悬浮面板点击「合成」选择素材，`GameManager.merge_run_weapons` 合并；品级越高伤害越高、冷却越短；武器名按品级着色（`resources/tier_config.gd`）
- **武器类型/主题词条**：`weapon_defs` 中每把武器绑定 `type_affix_id`、`theme_affix_id`；2-6 件同类套装生效，线性增长；多把同名武器只计 1 次；`AffixManager.get_set_bonus_effects` 计算并合并到玩家属性
- **商店随机词条**：`_roll_shop_items` 为武器随机附加 0~2 个词条（按 weapon_type 筛选），购买时传入 `add_run_weapon`；`sync_weapons_from_run` 对每把武器应用 `random_affix_ids`
- **攻击速度**：玩家属性 `attack_speed`，系数越高武器冷却越短
- 流程：
  1. 开局默认装备虚空短刃（blade_short）直接开始波次
  2. 每波结算先升级（4 选 1，免费，可金币刷新），再进入商店（武器+道具+魔法，购买后刷新或点下一波）；点击下一波后立即重置玩家、刷新地图、预生成倒计时、生成敌人（无间隔等待）

### 2.7 魔法系统

- `scripts/magic/magic_base.gd`：魔法基类，定义 `cast(caster, target_dir)`（直线型）与 `cast_at_position(caster, world_pos)`（圆区域型）接口
- `resources/magic_defs.gd`：魔法定义池（mana_cost、power、cooldown、range_affix_id、effect_affix_id、element_affix_id）；威力/消耗/冷却保留，范围/效果/元素由词条决定
- `resources/magic_affix_defs.gd`：魔法词条三类池（RANGE_AFFIX_POOL、EFFECT_AFFIX_POOL、ELEMENT_AFFIX_POOL），每魔法各 1 个
- **统一施法流程**：所有魔法均为按键 → 进入准备施法 → 显示施法范围 → 左键确认 / 右键取消；`range_type` 决定范围形状与确认后的调用方式
- **魔法施法覆盖层**：`scripts/ui/magic_targeting_overlay.gd` 按 `range_type` 显示：`line` 直线（角色到鼠标）、`mouse_circle` 鼠标圆心圆、`char_circle` 角色圆心圆；左键施放、右键/Esc 取消
- **施法速度**：玩家属性 `spell_speed`，系数越高魔法冷却越短；升级与道具可提升
- 玩家魔法槽位数量由角色 `usable_magic_count` 决定（默认 3），左右方向键切换当前魔法，E 键施放（cast_magic、magic_prev、magic_next）
- 确认后：`line` 调用 `cast(caster, dir)`，圆区域调用 `cast_at_position(caster, world_pos)`
- **施法 VFX**：一次性魔法（绯焰弹、霜华刺、冲击波）在施放点实例化 `scenes/vfx/magic_cast_burst.tscn`，短时粒子后自动 queue_free；持续魔法（蚀魂域）在 `burn_zone_node` 的 _ready 中挂接 `scenes/vfx/magic_zone_fire.tscn`，随 zone 存在而持续发射，随 zone 释放而消失。详见 CODE_INDEX「2.6b2 魔法施法 VFX」。
- 魔法可在商店购买；世界观与命名参考 `docs/WORLD_BACKGROUND.md`

- `scripts/ui/main_menu.gd`
  - 显示总统计、最近战绩、成就数量
  - 设置入口按钮（弹出 `settings_menu`）
  - 图鉴入口按钮（弹出 `encyclopedia_menu`）

- `scripts/ui/encyclopedia_menu.gd`
  - 图鉴菜单：按类型 Tab 展示角色、敌人、道具、武器、魔法、词条及其详细信息
  - 道具 Tab 仅展示 `type!="magic"` 的 ITEM_POOL 项；武器 Tab 内嵌套 TabContainer（近战/远程）；词条 Tab 内嵌套 TabContainer（魔法、道具、武器-通用、武器-近战、武器-远程、武器-类型、武器-主题）
  - 数据来源：GameManager.characters、EnemyDefs、ShopItemDefs、weapon_defs、MagicDefs、各 affix_defs
  - 只读浏览，不修改游戏状态

- `scripts/ui/character_select.gd`
  - 显示角色属性 + 该角色历史战绩

- `scripts/ui/pause_menu.gd`
  - 暂停按钮逻辑
  - TabContainer（系统 / 背包 / 角色信息），Tab 置于底部
  - 系统 Tab：标题、按键提示、继续、主菜单
  - 背包 Tab：`BackpackPanel` 展示装备武器、魔法、道具的图标网格（图标 + 名称），点击或悬浮时在右侧 DetailPanel 显示详情
  - 角色信息 Tab：调用 `ResultPanelShared.build_player_stats_block(stats, ..., true)` 仅构建角色属性区（HP、魔力、护甲、移速等）
  - 右侧内容区使用 ScrollContainer，内容超出时显示垂直滚动条
  - Root 设置为 `MOUSE_FILTER_IGNORE`，避免吞掉 HUD 点击
  - 暂停层新增全屏纯色不透明 backdrop
  - 面板样式强制不透明，保证暂停文本可读
  - 按键提示：移动、暂停、镜头缩放、魔法、敌人血条、按键提示切换（随改键同步）
  - 属性 Tab 仅显示角色属性；死亡/通关界面仍显示完整信息（武器、道具、词条、魔法）

- `scripts/ui/backpack_panel.gd`
  - 背包面板：根为 HBoxContainer，双独立面板：ContentPanel（ContentScroll 包裹 LeftVBox，武器/魔法/道具网格可滚动）+ DetailPanel（DetailScroll 包裹 DetailContent，物品详情可滚动，min 280px），均填满可用空间
  - `set_stats(stats)`：根据 `weapon_details`、`magic_details`、`item_ids` 构建三区；脏检查：stats 哈希未变且 shop_context 未变时跳过重建
  - 槽位 StyleBox 复用：`_get_slot_style()` 缓存单例，减少对象分配
  - 图标加载走 `VisualAssetRegistry.get_texture_cached`，缺失时用 `make_color_texture` 生成占位图
  - 点击或悬浮槽位时在右侧 DetailPanel 显示详情（标题、词条、效果、套装 2/4/6 件、售卖/合成按钮）；无选中且无悬浮时显示占位文案
  - 武器详情仅展示该武器所属套装（`WeaponSetDefs.get_weapon_set_full_display_info_for_weapon`），生效档位高亮；词条与效果分行 ul/li 风格
  - 道具 tooltip 仅展示最终效果加成；道具名用 `display_name_key`（如疾风靴、恶魔药剂）
  - 武器 tooltip 含「合成」按钮（非最高品级且存在同名同品级其他武器时）；点击后进入合并模式，选择素材完成手动合成
  - `hide_tooltip()`：暂停菜单关闭时清空选中并显示占位

- `scripts/ui/backpack_tooltip_popup.gd`
  - 背包悬浮面板：PanelContainer 实现，挂到暂停菜单 CanvasLayer 保证同视口、文字可显示；tooltip 数据轻量哈希（title/weapon_index/affixes/effect_parts）避免 JSON.stringify 开销；支持 effect_parts 数组分行 ul/li 展示
  - 词条二级面板：独立 PanelContainer，与主 tooltip 同级（CanvasLayer），首次显示时加入场景树，屏幕坐标定位；AFFIX_TOOLTIP_WIDTH 200、字体 14；完整描述+数值
  - `show_tooltip(text)`：纯文本模式，用于魔法等无词条项；同一物体悬浮移动时不重生成
  - `show_structured_tooltip(data)`：结构化模式，名称 + 词条 Chip 横向排布（可 hover 显示描述与数值）+ 效果；武器可含合成按钮
  - `synthesize_requested(weapon_index)`：合成按钮点击时发出
  - `schedule_hide()`：槽位/面板 mouse_exited 时调用，延迟 0.5s 隐藏，便于鼠标移入 tooltip
  - `is_scheduled_to_hide()`：是否正在延迟关闭（已移除槽位侧阻塞，进入新槽位时取消 hide 并显示）
  - `hide_tooltip()`：关闭提示
  - 词条二级面板：chip 离开后延迟 0.5s 隐藏，鼠标在词条/面板上时均不关闭；主 tooltip mouse_exited 时若鼠标在词条面板上则不调度关闭

- `scripts/ui/backpack_slot.gd`
  - 单个背包槽：VBoxContainer（图标 TextureRect + 名称 Label），名称按品级着色
  - `configure(..., tip_data, weapon_index, slot_type, slot_index)`：tip_data 用于右侧详情面板；slot_type 为 "weapon"/"magic"/"item"
  - `slot_detail_requested(slot_type, slot_index, tip_data)`：左键点击（非合并/非交换）时发出，供 BackpackPanel 刷新 DetailPanel
  - `slot_hover_entered(tip_data)`、`slot_hover_exited()`：鼠标进入/离开时发出，无选中时用于悬浮详情
  - `set_merge_selectable(selectable)`：合并模式下置灰不可选或高亮可选
  - `slot_clicked(weapon_index)`：合并模式下点击可选武器槽时发出

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

1. **近战**：`weapon_melee_base._apply_touch_hits()` 若 owner 有 `get_final_damage` 则用其替代武器 `damage`；元素优先取武器 `weapon_element`，否则 `get_elemental_enchantment`；有元素时传入 `enemy.take_damage(amount, elemental, 1)`
2. **远程**：`weapon_ranged_base._start_attack()` 同上，并将 `elemental_type`、`elemental_amount`（1 或 0）写入 bullet；子弹命中时 `take_damage(damage, elemental_type, elemental_amount)`
3. **敌人**：`enemy_base.take_damage(amount, elemental, element_amount)` 的 `element_amount > 0` 时增加对应元素附着量；每秒衰减与双元素反应见「2.3 元素附着与反应」

### 3.6 玩家受击与伤害缓冲

- **多伤害源取最大**：子弹、接触、地形 DOT 等调用 `player.take_damage(amount)` 时，伤害先缓冲到 `_pending_damages`，帧末取最大值后统一结算，避免同帧多源叠加秒杀
- **无敌帧**：受击后 `invulnerable_duration`（默认 0.5 秒）内不再接受伤害
- **受击音效**：`AudioManager.play_hit()` 使用专用通道，播放中不重叠，避免同帧多次受击时音效堆叠

## 4. 关键配置项

### 4.0 `GameConstants`（autoload）

修改 [scripts/autoload/game_constants.gd](scripts/autoload/game_constants.gd) 即可统一调整角色、敌人、BOSS、子弹的视觉缩放、摄像机、地形、波次、经验等系数与默认值，无需在各脚本中查找硬编码。

**缩放与子弹**
- `PLAYER_SCALE`、`ENEMY_SCALE`、`BOSS_SCALE`：玩家/普通敌人/BOSS 体积缩放（默认 3/3/15）
- `BULLET_SCALE`、`ELEMENT_ICONS_SCALE`：子弹体积、敌人血条上元素图标缩放（默认 2.0、0.1）
- `ENEMY_BULLET_SPEED`：敌人子弹飞行速度（默认 126.0）

**摄像机**
- `CAMERA_ZOOM_DEFAULT`、`CAMERA_ZOOM_MIN`、`CAMERA_ZOOM_MAX`、`CAMERA_ZOOM_STEP`、`CAMERA_DEAD_ZONE_RATIO`：缩放默认/范围/步进/死区比例

**地形与移动**
- `ZONE_AREA_SCALE_DEFAULT`：单块地形面积倍率（默认 5.0）
- `TERRAIN_SPEED_MULTIPLIER_DEFAULT`、`TERRAIN_SPEED_CLAMP_MIN`、`TERRAIN_SPEED_CLAMP_MAX`：地形速度倍率默认与 clamp 范围

**玩家**
- `INVULNERABLE_DURATION_DEFAULT`、`INERTIA_FACTOR_DEFAULT`、`INERTIA_FACTOR_MAX`：无敌时长、移动惯性默认与上限

**波次与生成**
- `WAVE_DURATION_DEFAULT`、`TELEGRAPH_DURATION_DEFAULT`、`PRE_SPAWN_COUNTDOWN_DEFAULT`、`INTERMISSION_TIME_DEFAULT`：波次时长、警示时长、预生成倒计时、波次间隔
- `COIN_DROP_CHANCE_DEFAULT`、`HEAL_DROP_CHANCE_DEFAULT`：金币/治疗掉落概率
- `SPAWN_BATCH_COUNT_DEFAULT`、`SPAWN_BATCH_INTERVAL_DEFAULT`、`SPAWN_POSITIONS_COUNT_DEFAULT`：批次数、间隔、出生点数量

**游戏流程**
- `VICTORY_WAVE_DEFAULT`、`UPGRADE_REFRESH_COST`：通关波次、刷新升级消耗金币

**敌人**
- `BOSS_FIRE_RATE_DEFAULT`、`BOSS_MOVE_SCALE`：BOSS 射击冷却、移动倍率
- `DASH_*`、`WIND_UP_*`、`RECOVER_*`、`DASHER_IDLE_MOVE_SCALE`：冲刺怪冷却/速度/时长与待机移动倍率

**子弹与魔法**
- `BULLET_LIFE_TIME_DEFAULT`、`BURN_DURATION_DEFAULT`：子弹存活时间、燃烧持续时长

**经验**
- `XP_BASE`、`XP_CURVE`：经验曲线基数与指数（升级所需 = XP_BASE × level^XP_CURVE）

### 4.0b `UiThemeConfig`（resources/ui_theme_config.gd）

修改 [resources/ui_theme.tres](resources/ui_theme.tres) 或 [resources/ui_theme_config.gd](resources/ui_theme_config.gd) 可统一调整 UI 主题、边距、字体与视觉层次。

**颜色**
- `modal_backdrop`、`modal_panel_bg`、`modal_panel_border`：模态背景、面板背景、边框
- `content_panel_bg`、`detail_panel_bg`：背包 ContentPanel/DetailPanel 背景色（略深/略浅区分）

**面板样式**
- `get_panel_stylebox_for_bg(bg_color)`：带边框的面板样式
- `get_panel_stylebox_borderless(bg_color)`：无可见边框的面板样式，供背包等去除白边使用

**边距与间距**
- `margin_default`、`margin_small`、`margin_tight`：常用边距（默认 32/24/16）
- `panel_padding`：面板内容区统一内边距（默认 16，与 margin_tight 一致）
- `separation_default`、`separation_tight`：容器间距（默认 12/8）
- `separation_grid`、`separation_grid_h`、`separation_grid_v`：网格/紧凑布局间距（默认 6/10/2）

**字体类型常量**（按用途区分，统一通过 `get_scaled_font_size(base)` 获取缩放后字号）
- `font_size_title`：面板主标题（默认 26）
- `font_size_subtitle`：Tab 标签、区段标题（默认 22）
- `font_size_list`：内容列表、得分区、武器卡片名称（默认 20）
- `font_size_list_secondary`：套装档位、词条子项（默认 18）
- `font_size_body`：详情正文、词条描述（默认 17）
- `font_size_hint`：操作说明、按键提示、小标签（默认 14）
- `font_size_hud`：血条、金币、波次等顶部信息（默认 14）
- `font_size_hud_small`：魔法槽名称、数值等小字（默认 11）

**StyleBox 边距**
- `stylebox_expand_margin`：模态面板 StyleBox 扩展边距（默认 8）
- `style_expand_margin_hud`、`style_content_margin_hud`：HUD 小面板边距（默认 6/8）

**Tab 选中放大**
- `tab_selected_scale`：保留于 UiThemeConfig 供后续复用；当前 `TabContainerSelectedScale` 仅移除内容区 panel 背景，使用引擎默认 TabBar，避免重复层与文字遮盖

**兼容旧引用**
- `tab_font_size`、`content_font_size`：Tab 与内容区字号（默认 22/20）

**可访问性**
- `font_scale`：字体缩放系数（默认 1.0），供多语言/无障碍适配；使用 `get_scaled_font_size(base_size)` 获取缩放后字号

### 4.1 `game.gd`

- `victory_wave`：通关波次（由预设关卡数量决定，标准预设为 10 关），达到该波次时显示通关界面并跳过升级/商店流程
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
- `use_extended_spawn`：启用扩展敌人生成（`normal_enemy_ids`、`elite_enemy_ids`、`boss_enemy_ids` 池，按波次精英概率、Boss 波抽取）；默认 false 时沿用原 `melee_count`/`ranged_count` 等逻辑
- 默认敌人数：`melee_count_min/max`（18～28）、`ranged_count_min/max`（0～2，减少远程）、`tank_count`（2～4）、`dasher_count`（2～5）；`spawn_positions_count` 默认 8；扩展池时 `total = 14+wave*4` 上限 50，约 15% 为远程
- `elite_spawn_chance_base`、`elite_spawn_chance_per_wave`：精英生成概率
- `map_size_scale`：地图大小系数，0.8=小、1.0=中、1.2=大
- `default_terrain_type`：默认地形类型，`flat`=平地、`seaside`=海边、`mountain`=山地；地板瓦片按此选择像素图（terrain_atlas 第 0/1/2 行），默认 `flat`

**摄像机**（`GameCamera2D`）：
- 缩放由 `camera_zoom_scale` 控制，可通过按键 `=`/`-`（`camera_zoom_in`/`camera_zoom_out`）调节
- 当地图大于可视区域时跟随玩家，保持玩家在 `camera_dead_zone_ratio` 死区内
- 敌人生成区域与 `get_playable_bounds()` 对齐

### 4.2 `wave_manager.gd`

- `wave_duration`：每波最大时长（秒），倒计时归零视为波次结束（默认 20）
  - 倒计时每帧扣减的 delta 被限制为最多 0.5 秒，避免首帧或切回标签页时 delta 过大导致波次瞬间结束
- `intermission_time`：波次间隔（当前商店流程已跳过，由 `start_next_wave_now` 直接进入下一波；保留供扩展）
- `pre_spawn_countdown`：预生成倒计时（秒），地形刷新完成后显示，倒计时结束才生成第 1 批敌人（默认 3）
- `spawn_min_player_distance`：与玩家的最小出生距离（默认 340）
- `spawn_positions_count`：出生点数量，单出生点可产生多个敌人（LevelConfig 默认 8）
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
- `characters[].usable_weapon_count`：可用武器槽位数，默认 6
- `characters[].usable_magic_count`：可用魔法槽位数，默认 3，与武器生效数量逻辑一致
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
- **Enemies**：`enemy_base.gd` 的 `@export_file texture_sheet`、`texture_single`、`enemy_type`（0=melee, 1=ranged, 2=tank, 3=boss, 4=aquatic, 5=dasher，用于死亡动画与 PixelGenerator 回退），各敌人场景在 Inspector 配置
- **Bullet**：`bullet.gd` 的 `@export_file texture_path`、`@export collision_radius`，武器 def 的 `bullet_texture_path`、`bullet_collision_radius`
- **近战挥击**：`weapon_melee_base.gd` 的 `@export_file swing_texture_path`、`@export swing_frame_size`，weapon_defs 的 `swing_texture_path`
- **武器图标**：weapon_defs 的 `icon_path`，HUD/player 从 option 或 weapon 节点读取；AI 生成图标须参考 `docs/ART_STYLE_GUIDE.md`，仅使用 Pixellab
- **掉落物**：`pickup.gd` 的 `@export_file texture_coin`、`texture_heal`
- **升级图标**：`_upgrade_pool` 的 `icon_path`，HUD 从 option 读取
- **VisualAssetRegistry**：`get_texture_cached(path)` 按路径缓存纹理，避免重复 load；`make_color_texture(color, size)` 纯色贴图（同色同尺寸复用缓存）；`make_panel_frame_texture(...)` 生成九宫格面板框纹理

### 4.7 默认地形与像素图

- `resources/default_terrain_colors.gd`：默认地形 3 种配色（flat/seaside/mountain），供 Polygon2D 回退使用
- `terrain_atlas.png`：3 行 x 7 列，第 0/1/2 行分别为 flat、seaside、mountain 地板瓦片
- 使用单层 TileMapLayer（Godot 4.6）：`_terrain_layer` 先铺满默认地形，再覆盖草/水/障碍
- `_spawn_walkable_floor` 优先使用 TileMapLayer 像素图，按 `default_terrain_type` 选择 atlas 行；无 TileMapLayer 时回退 Polygon2D

### 4.8 品级配置

- `resources/tier_config.gd`：品级颜色、伤害倍率、冷却倍率、道具/魔法品级倍率
  - **品级规范**：最多 5 档，从低到高 灰、绿、蓝、金、红（tier 0~4）
  - `get_tier_color(tier)`：0=灰、1=绿、2=蓝、3=金、4=红
  - `get_damage_multiplier(tier)`：1.0 + tier * 0.2
  - `get_cooldown_multiplier(tier)`：1.0 - tier * 0.1，最小 0.5
  - `get_item_tier_multiplier(tier)`：1.0 + tier * 0.15

### 4.9 武器配置

- **武器基础值与成长系数**：`weapon_defs.stats` 为 tier 0（最低品级）的基础值；damage、cooldown、touch_interval 等由 `TierConfig.get_damage_multiplier`、`get_cooldown_multiplier` 计算
- `resources/weapon_defs.gd::WEAPON_DEFS` 字段说明：
  - `id`, `type`, `name_key`, `desc_key`, `cost`, `color`
  - `script_path`（具体武器脚本路径）
  - `icon_path`（武器图标路径，HUD/武器环使用）
  - `swing_texture_path`（近战挥击纹理，仅近战）
  - `bullet_texture_path`、`bullet_collision_radius`（远程子弹，仅远程）
  - `stats`（示例：`damage`, `cooldown`, `range`, `touch_interval`, `swing_duration`, `swing_degrees`, `swing_reach`, `hitbox_radius`, `bullet_speed`, `pellet_count`, `spread_degrees`, `bullet_pierce`）

### 4.10 多语言配置

- 语言文件：
  - `i18n/zh-CN.json`
  - `i18n/en-US.json`
- 套装效果 i18n：`weapon_set.blade`、`weapon_set.firearm`、`weapon_set.magic`、`weapon_set.heavy` 及 `*.desc`、`*.bonus_2/4/6`；件数用 `common.piece`、`common.piece_threshold`、`common.set_active`
- 存档字段：
  - `save.json.language`
- 入口：
  - 主菜单语言下拉（`main_menu.tscn` + `main_menu.gd`）
- 运行时刷新：
  - 各 UI 监听 `LocalizationManager.language_changed` 并重绘文本

### 4.11 日志与排障

- **内置文件日志**：`project.godot` 中 `[debug]` 启用 `file_logging`，引擎将 `print`、`push_error`、`push_warning` 等输出到 `user://logs/godot.log`
- **统一日志**：`LogManager`（游戏）与 `addons/editor_logger`（编辑器）均写入 `user://logs/game_errors.log`，前缀 `[GAME]` / `[EDITOR]` 区分
- **GDScript::reload 补充**：脚本重载时的解析错误（UNUSED_PARAMETER 等）可能不经过 `OS.add_logger`。EditorLogger 定时从 `godot.log` 与 Output 面板双路中继到 `game_errors.log`，前缀 `[EDITOR][RELAY]` / `[EDITOR][OUTPUT]`
- **插件验证**：启动编辑器后，若 `game_errors.log` 出现 `[EditorLogger] 插件已加载`，说明插件生效；若无，检查「项目 → 项目设置 → 插件」中 Editor Logger 是否启用
- **日志路径**：通过 Godot 菜单「项目 → 打开项目数据文件夹」可找到 `user://` 对应目录，其下 `logs/` 为日志文件

### 4.12 设置结构（SaveManager）

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

1. 在 `resources/upgrade_defs.gd` 的 `UPGRADE_POOL` 增加条目
2. 玩家相关升级：由词条系统聚合，无需改 `player.gd`；若需新 effect_type，在 `item_affix_defs.gd` 与 `affix_manager._UPGRADE_TO_EFFECT` 中补充
3. 武器相关升级：在 `game.gd::WEAPON_UPGRADE_IDS` 中加入 id，在武器 `apply_upgrade` 中实现
4. 若需要新 UI 文案，在 `i18n/*.json` 与 `hud.gd` 中补充

### 5.1b 新增词条

1. 在对应词条库（`item_affix_defs.gd` / `weapon_affix_defs.gd` / `magic_affix_defs.gd`）增加定义：`id`、`visible`、`effect_type`、`base_value`、`name_key`；武器词条需加 `weapon_type`（`melee` | `ranged` | `both`）
2. 道具：在 `shop_item_defs.gd` 的 item 中增加 `affix_ids: ["xxx"]`；item 的 `base_value` 可覆盖词条默认值
3. 武器/魔法：在 def 中增加 `affix_ids: []`（可选）
4. 若 effect_type 为新类型，在 `player._apply_affix_aggregated` 或对应效果应用处补充处理
5. **武器元素词条**：在 `weapon_affix_defs.gd` 的 `WEAPON_ELEMENT_AFFIX_POOL` 中增加条目（`effect_type: "element"`、`element`、`weapon_type`、`name_key`、`desc_key`），并在 i18n 中补充对应 key

### 5.1c 新增元素类型/反应

1. **新元素类型**：在 `weapon_affix_defs.WEAPON_ELEMENT_AFFIX_POOL` 与 `magic_affix_defs.ELEMENT_AFFIX_POOL` 中增加对应元素 id；攻击/魔法传 `take_damage(..., element, amount)` 时使用该元素名
2. **新元素反应**：在 `enemy_base.gd` 的 `_trigger_element_reaction(elem_a, elem_b, consumed)` 中增加 (elem_a, elem_b) 分支（规范化为字典序 lo/hi），根据 consumed 计算反应伤害或击退等效果；反应仅造成无元素伤害（`current_health -= reaction_damage` 等），避免二次附着

### 5.2 新增敌人

1. 在 `resources/enemy_defs.gd` 的 `ENEMY_DEFS` 中新增条目（含 `id`、`tier`、`base_id`、`behavior_mode`、`scene_path`、`name_key`、`desc_key`、`icon_path` 及数值）
2. 在 `resources/enemy_scene_registry.gd` 的 `_scene_paths` 中注册 `id -> scene_path`（若使用自动扫描则无需手动添加）
3. 创建场景 `scenes/enemies/enemy_{id}.tscn`，继承对应基类（melee/ranged/tank/aquatic/dasher/boss），配置 `enemy_id`、纹理
4. 在 `i18n/zh-CN.json`、`i18n/en-US.json` 中新增 `enemy.{id}.name`、`enemy.{id}.desc`
5. 若需自定义逻辑，继承 `enemy_base.gd`
6. 若需水中专属敌人：`is_water_only()` 返回 true，由 `terrain_zone` 维护 `water_zone_count` meta，离水时 `enemy_base` 自动施加伤害
7. 若需自定义出生点（如水中）：在 `get_enemy_spawn_orders` 返回的 order 中设置 `pos_override` 为 `Vector2`；`game.gd` 提供 `get_random_water_spawn_position()`、`has_water_spawn_positions()`

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

### 6.6 分辨率与等比例缩放

设计分辨率固定 1280×720，窗口调整时强制等比例缩放，多余区域留黑边（letterbox）。  
实现：
1. `project.godot` 使用 `aspect="keep"` 保持比例
2. `game_manager.gd` 中 `_apply_content_scale_to_window()` 将根视口 `content_scale_size` 固定为 1280×720（`DESIGN_VIEWPORT`）
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

---

## 8. 优化功能说明（2026-02-19）

### 8.1 敌人 LOD 系统

为提升性能，敌人现在支持三级 LOD（Level of Detail）：

- **Level 0（近处）**：完整更新，每帧处理
- **Level 1（远处）**：降低更新频率至 0.1 秒
- **Level 2（超远处）**：降低更新频率至 0.5 秒，隐藏视觉

**相关文件**：
- `scripts/enemy_base.gd`：`update_lod_level()`、`force_full_lod()`
- `scripts/game.gd`:`_update_enemy_lod()`

**配置参数**：
```gdscript
const LOD_DISTANCE_NEAR := 400.0   # 近处边界
const LOD_DISTANCE_FAR := 800.0    # 远处边界  
const LOD_DISTANCE_HIDE := 1200.0  # 隐藏边界
```

### 8.2 对象池扩展

对象池现在支持敌人池化，减少 instantiate/queue_free 开销：

**相关文件**：
- `scripts/autoload/object_pool.gd`：`acquire_enemy()`、`recycle_enemy()`
- `scripts/enemy_base.gd`:`reset_for_pool()`

**使用方法**：
```gdscript
# 获取敌人
var enemy = ObjectPool.acquire_enemy(enemy_id, scene, parent)

# 回收敌人（死亡时自动回收）
ObjectPool.recycle_enemy(enemy)
```

### 8.3 背包交互优化

背包现在支持排序和过滤功能：

**相关文件**：
- `scripts/ui/backpack_panel.gd`:`set_sort_mode()`、`set_filter_type()`、`batch_sell_by_tier()`

**排序模式**：
- 0 = 默认
- 1 = 品级高到低
- 2 = 品级低到高
- 3 = 类型分组

**过滤类型**：`""`（全部）、`"melee"`、`"ranged"`

### 8.3.1 UI 全屏与背包双面板（2026-02-19）

**全屏扩展**：结算、暂停、设置、图鉴等面板扩展至全屏，去掉固定尺寸与 CenterContainer，用 `size_flags` 填满可用空间，减少滚动条。

**背包双独立面板**：`backpack_panel.tscn` 拆分为 ContentPanel（背包内容：武器/魔法/道具网格）与 DetailPanel（物品详情），两面板均 `size_flags_horizontal = 3` 按比例分配宽度，`custom_minimum_size` 防止过窄。

**涉及文件**：
- `scenes/ui/backpack_panel.tscn`：ContentPanel + DetailPanel 双 Panel 布局
- `scenes/ui/game_over_screen.tscn`、`victory_screen.tscn`：Panel 全屏，去掉 ScoreScroll/BackpackScroll/StatsScroll
- `scenes/ui/pause_menu.tscn`：PauseTabs 填满，BackpackTabContainer/StatsContainer 直接作为 Tab 子节点
- `scenes/ui/settings_menu.tscn`、`encyclopedia_menu.tscn`：去掉 CenterContainer 与固定宽高
- `scenes/ui/backpack_overlay.tscn`、`hud.tscn`：BackpackScroll 填满或改为 BackpackTabContainer

### 8.3.2 UI 优化建议实现（2026-02-19）

**布局与信息密度**
- Tab 标签：`top_margin = 20`、`side_margin = 16`，使标签更紧凑
- 背包网格：`h_separation`/`v_separation` 降至 6；`BackpackSlot.SLOT_SIZE_COMPACT = 44` 可选紧凑槽位

**响应式与边距**
- 全屏面板根节点 `anchors_preset = 15`，子级用 `size_flags` 填满
- 边距常量：`UiThemeConfig.margin_default`/`margin_small`/`margin_tight` 供各面板引用

**面板 padding 统一标准**（以波次间商店背包页为基准）
- 所有面板内容区与边框/边缘至少保持 16px 距离（`margin_tight` / `panel_padding`）
- HUD 升级面板、武器/商店面板：`UpgradeMargin`/`WeaponMargin` 使用 16
- 背包 ContentPanel/DetailPanel、结算/图鉴卡片：`content_margin` 或 `MarginContainer` 使用 16
- 暂停菜单角色属性 Tab：`StatsContainer` 外包 `StatsMargin` 使用 16

**标题与字体**
- 各面板主标题居中（`horizontal_alignment = 1`），字号使用 `font_size_title`（26）
- 区段标题（如 Weapons、Magics）居中，字号使用 `font_size_subtitle`（22）

**滚动条**
- ScrollContainer 显式 `vertical_scroll_mode = 1`（SCROLL_MODE_AUTO）按需显示

**视觉层次**
- ContentPanel/DetailPanel 使用 `get_panel_stylebox_borderless()` 无边框样式区分背景色，中间 VSeparator 强化分区

**可访问性**
- 暂停、设置、结算等关键按钮设置 `focus_neighbor_*` 支持键盘/手柄导航
- `UiThemeConfig.font_scale`、`get_scaled_font_size()` 预留字体缩放

**性能扩展点**
- 若某 Tab 将来有上百条目，可考虑 ItemList 或虚拟列表，仅渲染可见项；当前规模暂不实现

---

## 9. HUD 按键提示与背包改动（2026-02-19）

### 9.1 按键提示改名与按 I 切换

**改动内容**：
- `PauseHint` 改名为 `KeyHints`，显示「按键提示」
- 默认显示 2 行核心按键（移动+暂停）
- 按 I 键可展开/收起，显示全部按键

**相关文件**：
- `scripts/ui/hud.gd`：`key_hints_label`、`_build_key_hints_text()`、`toggle_key_hints_expanded()`
- `scripts/game.gd`：处理 `toggle_key_hints` 输入
- `project.godot`：新增 `toggle_key_hints` 输入动作（绑定 I 键）
- `scripts/ui/settings_menu.gd`：ACTION_NAME_KEYS 增加 `toggle_key_hints`
- `i18n/zh-CN.json`、`i18n/en-US.json`：新增相关本地化 key

### 9.2 升级面板移除跳过按钮

**改动内容**：
- 移除升级面板的「跳过」按钮
- 玩家必须选择一项升级才能继续

**相关文件**：
- `scenes/ui/hud.tscn`：已删除 `SkipBtn` 节点

### 9.3 魔法 UI 与动态槽位

**改动内容**：
- 魔法面板始终显示，无论是否有魔法
- 魔法槽位数量由角色 `usable_magic_count` 决定（默认 3），与武器 `usable_weapon_count` 逻辑一致
- `get_magic_ui_data()` 返回与 `get_usable_magic_count()` 一致的槽位数量，空槽用占位数据
- HUD 预置 Slot0~5，按 `magic_data.size()` 显示/隐藏

**相关文件**：
- `scripts/ui/hud.gd`：`set_magic_ui()` 始终设置 `_magic_panel.visible = true`，`_magic_slots` 支持最多 6 个槽
- `scripts/player.gd`：`get_usable_magic_count()`、`get_magic_ui_data()` 按角色配置返回槽位
- `scripts/autoload/game_manager.gd`：`characters` 中每角色含 `usable_magic_count`（默认 3）

### 9.4 背包武器无上限 + 仅前 N 把可用

**改动内容**：
- 移除武器持有上限（`MAX_WEAPONS`），可无限购买
- 添加 `usable_weapon_count`、`usable_magic_count` 角色配置，武器默认 6 把、魔法默认 3 个
- 仅前 N 把武器参与战斗，超出部分仅存储在背包中
- 武器详情添加 `usable` 标记

**相关文件**：
- `scripts/autoload/game_manager.gd`：`DEFAULT_USABLE_WEAPON_COUNT`、移除容量检查、`reorder_run_weapons()`
- `scripts/player.gd`：`get_usable_weapon_count()`、`sync_weapons_from_run()` 仅同步前 N 把
- `scripts/ui/backpack_panel.gd`：显示所有武器，但标记不可用状态

### 9.5 背包武器与魔法点击交换

**改动内容**：
- 背包武器和魔法支持点击交换：第一次点击选中（绿色描边），第二次点击同类型另一槽交换，右键取消
- 同类槽位之间可交换（武器↔武器，魔法↔魔法）

**相关文件**：
- `scripts/ui/backpack_slot.gd`：`slot_swap_clicked(slot_index, slot_type)`、`slot_swap_cancel_requested` 信号；`get_slot_index()`、`get_slot_type()` 供面板查找
- `scripts/ui/backpack_panel.gd`：`_on_slot_swap_clicked` 处理交换逻辑，`_exit_swap_mode` 取消选中，`_unhandled_input` 检测右键取消；调用 `reorder_run_weapons()` 或 `reorder_magics()`

**相关文件**：
- `scripts/ui/backpack_panel.gd`:`set_sort_mode()`、`set_filter_type()`、`batch_sell_by_tier()`

**排序模式**：
- 0 = 默认
- 1 = 品级高到低
- 2 = 品级低到高
- 3 = 类型分组

**过滤类型**：`""`（全部）、`"melee"`、`"ranged"`

### 8.4 动态波次难度

波次系统现在支持动态难度调整：

- **波次时长**：前期 15 秒，后期 25 秒
- **连杀系统**：连续击杀增加精英生成概率
- **动态计算**：`LevelConfig.get_dynamic_wave_duration()`、`get_dynamic_elite_chance()`

**相关文件**：
- `resources/level_config.gd`
- `scripts/wave_manager.gd`：连杀追踪

### 8.5 武器套装效果

同套装武器同时装备时激活套装加成：

**套装列表**（`resources/weapon_set_defs.gd`）：
- `blade_set`：刀剑套装（暴击、流血）
- `firearm_set`：火器套装（射速、穿透）
- `magic_set`：魔法套装（魔力、法强）
- `heavy_set`：重装套装（护甲、眩晕）

**展示接口**：`WeaponSetDefs.get_weapon_set_full_display_info(equipped_weapons)` 返回全部套装 2/4/6 件完整描述，供角色信息面板展示；`get_weapon_set_full_display_info_for_weapon(equipped_weapons, weapon_id)` 仅返回该武器所属套装，供背包物品详情使用。

**套装加成**：
- 2 件：基础加成
- 4 件：进阶加成
- 6 件：终极加成

### 8.6 纹理压缩配置

`project.godot` 新增渲染优化配置：

```ini
[rendering]
textures/vram_compression/import_s3tc=true
textures/vram_compression/import_etc=true
2d/snap/snap_2d_vertices_to_pixel=true
batching/options/use_single_quad_fallback=true
```

### 8.7 UI 动画过渡

面板现在支持淡入/淡出动画：

**相关文件**：
- `scripts/ui/hud.gd`:`_animate_panel_in()`、`_animate_panel_out()`

**动画方法**：
- `show_upgrade_options_animated()`
- `hide_upgrade_options_animated()`
- `show_weapon_shop_animated()`
- `hide_weapon_panel_animated()`

### 8.8 无尽模式

无尽模式支持无限制波次挑战：

**相关文件**：
- `scripts/autoload/game_manager.gd`:`start_endless_mode()`、`get_endless_difficulty_bonus()`

**特性**：
- 无通关波次限制
- 每波难度递增 5%
- 每 5 波额外金币奖励
- 每 10 波额外 Boss

**启用方法**：
```gdscript
GameManager.start_endless_mode(character_id)
```

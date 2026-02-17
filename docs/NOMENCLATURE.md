# 项目内部命名规范

本文档规范菜单、UI、功能模块的**项目内部称呼**，仅用于开发与文档，玩家不可见。后续任务涉及相关名词时，请参考本文档。

---

## 一、页面 / 场景

| 规范称呼 | 说明 | 场景/脚本 |
|----------|------|-----------|
| 主菜单 | 游戏入口，新游戏/继续/设置/退出 | main_menu.tscn, main_menu.gd |
| 角色选择页 | 双角色卡片、关卡预设、开始按钮 | character_select.tscn, character_select.gd |
| 战斗场景 | 主游戏，玩家、地形、波次、HUD | game.tscn, game.gd |

---

## 二、菜单

| 规范称呼 | 说明 | 场景/脚本 |
|----------|------|-----------|
| 主菜单 | 见「页面」 | main_menu |
| 暂停菜单 | 游戏中按暂停键弹出，左右分栏（系统信息 + 玩家属性） | pause_menu.tscn, pause_menu.gd |
| 设置菜单 | 全屏设置页，系统/游戏/按键三标签 | settings_menu.tscn, settings_menu.gd |

---

## 三、面板

| 规范称呼 | 说明 | 所属 | 变量/节点 |
|----------|------|------|-----------|
| 升级面板 | 波次结束四选一升级，可刷新 | HUD | _upgrade_panel |
| 武器面板 | 开局武器选择 / 波次商店，共用同一面板 | HUD | _weapon_panel |
| 魔法面板 | 左下角已装备魔法槽，含当前选中与冷却 | HUD | _magic_panel |
| 触控面板 | 触控虚拟摇杆与暂停按钮容器 | HUD | _touch_panel |
| 顶部信息行 | 血量/魔力/经验/波次/击杀/时间等横向区域 | HUD | TopRow |
| 结算面板 | 死亡/通关时的得分与玩家信息区 | game_over_screen / victory_screen | _panel |

---

## 四、覆盖层与遮罩

| 规范称呼 | 说明 | 所属 | 变量/节点 |
|----------|------|------|-----------|
| 模态遮罩 | 升级/商店时全屏半透明背景，阻挡下层点击 | HUD | _modal_backdrop |
| 全屏遮罩 | 暂停/设置等全屏弹窗后的背景遮罩 | pause_menu / settings_menu / game_over_screen / victory_screen | _fullscreen_backdrop / _backdrop |
| 区域施法覆盖层 | 区域型魔法选点时的圆形范围跟随鼠标 | game | magic_targeting_overlay |
| 魔法槽冷却遮罩 | 单个魔法槽上的冷却进度半透明覆盖 | HUD 魔法面板 | cd_overlay |
| 不透明背景 | 升级/武器面板内的纯色背景块 | HUD | OpaqueBackdrop |

---

## 五、HUD 组件

| 规范称呼 | 说明 | 变量/节点 |
|----------|------|-----------|
| 血量条 | 血条 ProgressBar | health_bar |
| 血量标签 | 显示 "当前/最大" | health_label |
| 魔力条 | 魔力 ProgressBar | mana_bar |
| 魔力标签 | 显示 "当前/最大" | mana_label |
| 经验条 | 升级进度 ProgressBar | exp_bar |
| 等级标签 | Lv.N | level_label |
| 护甲标签 | Armor: N | armor_label |
| 波次标签 | Wave: N | wave_label |
| 击杀标签 | Kills: N | kill_label |
| 时间标签 | Time: N.Ns | timer_label |
| 金币标签 | 当前金币数 | _currency_label |
| 波次间隔倒计时 | 下一波 X.Xs | _intermission_label |
| 波次剩余倒计时 | 正上方波次剩余时间 | _wave_countdown_label |
| 波次横幅 | 正上方 "第 N 波" 淡出动画 | _wave_banner |
| 按键提示 | 左下角移动/暂停/魔法等按键说明 | pause_hint |
| 魔法槽 | 魔法面板内单个魔法位（图标 + 冷却遮罩） | _magic_slots[i] |

---

## 六、功能模块

| 规范称呼 | 说明 | 脚本/资源 |
|----------|------|-----------|
| 波次管理器 | 敌人生成、击杀统计、掉落、倒计时、清场 | wave_manager.gd |
| 升级系统 | 四选一升级、刷新、奖励计算 | game.gd, upgrade_defs.gd |
| 武器商店 | 波次后商店，武器+道具+魔法 | game.gd, shop_item_defs.gd |
| 开局武器选择 | 新游戏/继续后首次选武器 | game.gd, hud.gd |
| 魔法系统 | 弹道/区域施法、冷却、施法速度 | player.gd, magic_defs.gd, magic_base.gd |
| 区域施法 | 圆形选点、左键施放、右键取消 | magic_targeting_overlay.gd |
| 结算共享 | 得分区、玩家属性区构建，供死亡/通关/暂停复用 | result_panel_shared.gd |
| 按键绑定 | 可配置动作与冲突校验 | game_manager.gd, settings_menu.gd |
| 存档系统 | 读写 save.json、设置持久化 | save_manager.gd |
| 本地化 | 多语言、文案 key | localization_manager.gd |
| 音频管理 | 音效与 BGM | audio_manager.gd |
| 地形系统 | 草丛/浅水/深水/障碍生成 | game.gd, terrain_zone.gd |
| 武器系统 | 近战/远程、品级、冷却 | weapon_defs.gd, weapons/ |
| 敌人系统 | 各类敌人、接触伤害、击退 | enemy_base.gd, enemies/ |

---

## 七、设置页标签

| 规范称呼 | 说明 | Tab 索引 |
|----------|------|----------|
| 系统标签 | 音量、分辨率、窗口模式 | 0 |
| 游戏标签 | 移动预设、惯性、暂停键、敌人血条、按键提示 | 1 |
| 按键标签 | 11 个可配置动作的按键绑定 | 2 |

---

## 八、武器面板模式

| 规范称呼 | 说明 | _weapon_mode 值 |
|----------|------|-----------------|
| 开局选择模式 | 新游戏/继续后首次选武器 | "start" |
| 商店模式 | 波次结束后的武器/道具/魔法商店 | "shop" |

---

## 九、结算界面

| 规范称呼 | 说明 | 场景/脚本 |
|----------|------|-----------|
| 死亡结算界面 | 玩家死亡后展示得分与玩家信息 | game_over_screen.tscn, game_over_screen.gd |
| 通关结算界面 | 达到通关波次后展示 | victory_screen.tscn, victory_screen.gd |

---

## 十、命名约定

- **菜单**：以「菜单」结尾，如 主菜单、暂停菜单、设置菜单
- **面板**：以「面板」结尾，如 升级面板、武器面板、魔法面板
- **覆盖层**：以「覆盖层」结尾，如 区域施法覆盖层
- **遮罩**：以「遮罩」结尾，如 模态遮罩、全屏遮罩
- **标签**：以「标签」结尾，如 波次标签、金币标签
- **条**：进度条类以「条」结尾，如 血量条、魔力条、经验条
- **系统/模块**：以「系统」或「模块」结尾，如 魔法系统、波次管理器

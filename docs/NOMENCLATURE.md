# 项目内部命名规范

本文档规范菜单、UI、功能模块的**项目内部称呼**，仅用于开发与文档，玩家不可见。后续任务涉及相关名词时，请参考本文档。

## 维护规则

**涉及专业名词新增或改动的，须同步修改本文件。**

- 新增菜单、面板、覆盖层、遮罩、标签、功能模块等时，在对应章节补充条目
- 已有名词的说明、所属、变量/节点发生变更时，更新对应条目
- 新增命名约定时，在「十二、命名约定」中补充

### 各菜单页专业名词速查

按菜单页梳理，便于开发时快速定位。

| 菜单页 | 所属 | 专业名词 | 说明 |
|--------|------|----------|------|
| **商店** | HUD 武器面板 | 武器面板 | 开局选择 / 波次商店共用，含 Tab 容器 |
| | | 商店 Tab | Tab 0：武器选项、刷新按钮、标题、描述 |
| | | 背包 Tab | Tab 1：内嵌 BackpackPanel，武器/魔法/道具网格，shop_context 时显示售卖/合并 |
| | | 角色信息 Tab | Tab 2：HP、魔力、护甲、移速、武器等属性区 |
| | | 背包面板 | 背包 Tab 内 BackpackPanel，与暂停菜单同组件 |
| | | 背包槽 | 背包面板内单槽（图标+名称，品级着色） |
| | | 背包悬浮面板 | 悬浮背包槽时弹出的 Popup，展示名称、词条、效果 |
| | | 下一波按钮 | 关闭商店，立即重置玩家、刷新地图、倒计时后生成敌人 |
| | | 模态遮罩 | 商店打开时全屏背景，阻挡下层点击 |
| **图鉴** | 主菜单 | 图鉴菜单 | 按类型 Tab 展示角色、敌人、道具、武器、魔法、词条 |
| | | 角色标签 | Tab 0，角色静止图与属性 |
| | | 敌人标签 | Tab 1，敌人静止图与属性 |
| | | 道具标签 | Tab 2，道具图标与描述（仅 attribute，排除 magic） |
| | | 武器标签 | Tab 3，含子 Tab（近战/远程） |
| | | 魔法标签 | Tab 4，魔法图标与属性 |
| | | 词条标签 | Tab 5，含子 Tab（魔法-范围/效果/元素、道具、武器-通用、武器-近战、武器-远程） |
| | | 图鉴项 | 各 Tab 内单条卡片（左侧图片 + 右侧名称与详情） |
| **结算** | game_over / victory | 死亡结算界面 | 玩家死亡后展示 |
| | | 通关结算界面 | 达到通关波次后展示 |
| | | 得分 Tab | Tab 0：标题、波次/击杀/时间/金币/总伤害/最佳记录、返回主菜单 |
| | | 背包 Tab | Tab 1：内嵌 BackpackPanel，shop_context=false，只读展示 |
| | | 角色信息 Tab | Tab 2：HP、魔力、护甲、武器等（ResultPanelShared 构建） |
| | | 全屏遮罩 | 结算界面背景遮罩 |
| **设置** | 主菜单 | 设置菜单 | 全屏设置页 |
| | | 系统标签 | Tab 0：音量、分辨率、窗口模式 |
| | | 游戏标签 | Tab 1：惯性、敌人血条切换键、敌人血条显隐 |
| | | 按键标签 | Tab 2：11 个可配置动作的按键绑定 |
| **暂停** | 战斗中 | 暂停菜单 | 按暂停键弹出，左右分栏 |
| | | 系统 Tab | Tab 0：标题、按键提示、继续、主菜单 |
| | | 背包 Tab | Tab 1：BackpackPanel，无 shop_context，不显示售卖/合并 |
| | | 角色信息 Tab | Tab 2：HP、魔力、护甲、武器等 |
| | | 背包面板 | 同商店，此处 shop_context=false |
| | | 全屏遮罩 | 暂停时背景遮罩 |

---

## 一、页面 / 场景

| 规范称呼 | 说明 | 场景/脚本 |
|----------|------|-----------|
| 主菜单 | 游戏入口，新游戏/继续/设置/图鉴/退出 | main_menu.tscn, main_menu.gd |
| 角色选择页 | 双角色卡片、关卡预设、开始按钮 | character_select.tscn, character_select.gd |
| 战斗场景 | 主游戏，玩家、地形、波次、HUD | game.tscn, game.gd |

---

## 二、菜单

| 规范称呼 | 说明 | 场景/脚本 |
|----------|------|-----------|
| 主菜单 | 见「页面」 | main_menu |
| 暂停菜单 | 游戏中按暂停键弹出，左右分栏（系统信息 + 属性/背包 Tab） | pause_menu.tscn, pause_menu.gd |
| 设置菜单 | 全屏设置页，系统/游戏/按键三标签 | settings_menu.tscn, settings_menu.gd |
| 图鉴菜单 | 主菜单入口打开，按类型 Tab 展示角色、敌人、道具、武器、魔法、词条 | encyclopedia_menu.tscn, encyclopedia_menu.gd |

---

## 二b、图鉴

| 规范称呼 | 说明 | 所属 | 变量/节点 |
|----------|------|------|-----------|
| 图鉴菜单 | 见「菜单」 | main_menu | EncyclopediaMenu |
| 图鉴项 | 图鉴 Tab 内单个条目卡片（左侧图片 + 右侧名称与详情） | 图鉴菜单 | _add_entry 创建的 PanelContainer |
| 图鉴标签 | 图鉴 TabContainer 的 6 个 Tab（角色、敌人、道具、武器、魔法、词条）；武器/词条 Tab 内各有子 Tab | 图鉴菜单 | Tabs |
| 敌人 tier 分组 | 图鉴敌人 Tab 内按普通/精英/BOSS 分组的标题 | 图鉴菜单 | _build_enemies_tab 中的 Label |

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
| 背包面板 | 暂停菜单内背包 Tab，双独立面板：ContentPanel（背包内容：武器/魔法/道具网格）+ DetailPanel（物品详情）；中间 VSeparator 分隔；ContentPanel 略深、DetailPanel 略浅背景区分；点击或悬浮槽位在右侧显示详情 | pause_menu | BackpackPanel |
| 背包内容面板 | 背包左侧 ContentPanel，含武器/魔法/道具三区网格，背景略深 | BackpackPanel | ContentPanel |
| 背包详情面板 | 背包右侧 DetailPanel，展示选中/悬浮槽位的名称、词条、效果、套装 2/4/6 件、售卖/合成按钮，背景略浅 | BackpackPanel | DetailPanel |
| 面板分隔线 | ContentPanel 与 DetailPanel 之间的 VSeparator，强化分区 | BackpackPanel | PanelSeparator |
| 背包槽 | 背包面板内单个槽位（图标 + 名称，名称按品级着色） | BackpackPanel | BackpackSlot |

---

## 四、覆盖层与遮罩

| 规范称呼 | 说明 | 所属 | 变量/节点 |
|----------|------|------|-----------|
| 模态遮罩 | 升级/商店时全屏半透明背景，阻挡下层点击 | HUD | _modal_backdrop |
| 全屏遮罩 | 暂停/设置等全屏弹窗后的背景遮罩 | pause_menu / settings_menu / game_over_screen / victory_screen | _fullscreen_backdrop / _backdrop |
| 魔法施法覆盖层 | 所有魔法选点时的施法范围（直线/鼠标圆心圆/角色圆心圆），左键施放、右键取消 | game | magic_targeting_overlay |
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
| 波次倒计时 | 中上：预生成/间隔时「第X波-X.Xs」，波次进行中「第X波-剩余Xs」 | _wave_countdown_label |
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
| 魔法施法 | 统一 targeting 流程：按键进入准备、显示范围、左键施放、右键取消 | magic_targeting_overlay.gd |
| 结算共享 | 得分区、玩家属性区构建，供死亡/通关/暂停复用 | result_panel_shared.gd |
| 按键绑定 | 可配置动作与冲突校验 | game_manager.gd, settings_menu.gd |
| 存档系统 | 读写 save.json、设置持久化 | save_manager.gd |
| 本地化 | 多语言、文案 key | localization_manager.gd |
| 音频管理 | 音效与 BGM | audio_manager.gd |
| 地形系统 | 草丛/浅水/深水/障碍生成 | game.gd, terrain_zone.gd |
| 武器系统 | 近战/远程、品级、冷却 | weapon_defs.gd, weapons/ |
| 敌人系统 | 各类敌人、接触伤害、击退 | enemy_base.gd, enemies/ |

---

## 七、暂停菜单标签

| 规范称呼 | 说明 | Tab 索引 |
|----------|------|----------|
| 属性页 | 暂停菜单 Tab 0，仅展示角色属性区 | 0 |
| 属性标签 | 同「属性页」 | 0 |
| 角色属性区 | 属性页内的 GridContainer，展示 HP、魔力、护甲、移速、惯性、攻速等数值 | result_panel_shared |
| 背包标签 | 装备武器/魔法/道具的图标网格（图标 + 名称），悬浮显示背包悬浮面板 | 1 |

---

## 七b、图鉴标签

| 规范称呼 | 说明 | Tab 索引 |
|----------|------|----------|
| 角色标签 | 图鉴内角色 Tab，展示角色静止图与属性 | 0 |
| 敌人标签 | 图鉴内敌人 Tab，展示敌人静止图与属性 | 1 |
| 道具标签 | 图鉴内道具 Tab，展示道具图标与描述（仅 attribute 类，排除 magic） | 2 |
| 武器标签 | 图鉴内武器 Tab，含子 Tab（近战/远程） | 3 |
| 魔法标签 | 图鉴内魔法 Tab，展示魔法图标与属性 | 4 |
| 词条标签 | 图鉴内词条 Tab，含子 Tab（魔法、道具、武器-通用、武器-近战、武器-远程） | 5 |

---

## 八、设置页标签

| 规范称呼 | 说明 | Tab 索引 |
|----------|------|----------|
| 系统标签 | 音量、分辨率、窗口模式 | 0 |
| 游戏标签 | 惯性、敌人血条切换键、敌人血条显隐 | 1 |
| 按键标签 | 11 个可配置动作的按键绑定 | 2 |

---

## 九、武器面板模式

| 规范称呼 | 说明 | _weapon_mode 值 |
|----------|------|-----------------|
| 开局选择模式 | 新游戏/继续后首次选武器 | "start" |
| 商店模式 | 波次结束后的武器/道具/魔法商店 | "shop" |

---

## 十、结算界面

| 规范称呼 | 说明 | 场景/脚本 |
|----------|------|-----------|
| 死亡结算界面 | 玩家死亡后展示得分与玩家信息 | game_over_screen.tscn, game_over_screen.gd |
| 通关结算界面 | 达到通关波次后展示 | victory_screen.tscn, victory_screen.gd |

---

## 十一、武器 / 魔法 / 道具

| 规范称呼 | 说明 | 数据来源 |
|----------|------|----------|
| 武器 | 近战/远程装备，有品级、伤害、冷却 | weapon_defs.gd, run_weapons |
| 魔法 | 弹道/区域施法，有魔力消耗、威力、冷却 | magic_defs.gd, _equipped_magics |
| 道具 | 商店购买的属性增强或魔法装备 | shop_item_defs.gd, run_items |
| 词条 | 附着于武器/魔法/道具的效果标签，用于限定范围与批量应用效果 | affix 系统 |
| 武器词条 | 仅作用于武器的词条 | WeaponAffix |
| 魔法词条 | 仅作用于魔法的词条 | MagicAffix |
| 道具词条 | 仅作用于道具的词条 | ItemAffix |
| 元素词条 | 武器或魔法上携带的元素类型（火/冰/雷/毒/物理），攻击时对敌人进行元素附着 | weapon_element / magic element_affix_id |
| 元素量 | 附着时增加的数值档位：少量 1、大量 10、巨量 20；武器=1，魔法=10 | EnemyBase.ELEMENT_AMOUNT_* |
| 元素附着 | 对敌人造成伤害时若带元素且 element_amount>0，则增加该敌人身上的该元素量 | enemy_base._element_amounts |
| 元素反应 | 敌人身上存在两种元素时每秒等量消耗并触发一次效果（如融化、过载、超导等） | enemy_base._trigger_element_reaction |

---

## 十二、命名约定

- **菜单**：以「菜单」结尾，如 主菜单、暂停菜单、设置菜单、图鉴菜单
- **面板**：以「面板」结尾，如 升级面板、武器面板、魔法面板
- **覆盖层**：以「覆盖层」结尾，如 区域施法覆盖层
- **遮罩**：以「遮罩」结尾，如 模态遮罩、全屏遮罩
- **标签**：以「标签」结尾，如 波次标签、金币标签
- **条**：进度条类以「条」结尾，如 血量条、魔力条、经验条
- **系统/模块**：以「系统」或「模块」结尾，如 魔法系统、波次管理器

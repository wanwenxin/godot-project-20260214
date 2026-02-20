# BUG 修复记录

本文件记录每次报错修复的 BUG，包含现象、原因分析与修复方式。**执行 coding 计划前须参考本文档**，避免出现同类问题。

## 记录格式

每条记录包含：

- **日期**：修复日期
- **现象**：报错信息或异常表现
- **原因**：根因分析
- **修复**：具体修改
- **预防**：后续如何避免同类问题

---

## 记录列表

（按时间倒序，最新在上）

### 2026-02-20：武器图标重生成计划（WanImage 工具不可用）

- **现象**：计划「武器美术重生成与规则」中需调用 WanImage 的 `modelstudio_image_gen` 生成 11 张武器图，调用报错 Tool not found。
- **原因**：当前工作区 mcps 下 `user-AliyunBailianMCP_WanImage` 仅有 SERVER_METADATA/INSTRUCTIONS，未暴露 tools（无 modelstudio_image_gen 描述符），故无法通过 MCP 自动生成。
- **修复**：规则与 ART_STYLE_GUIDE、player.gd 的 z_index、PIXELLAB_REPLACED_ASSETS 打标与描述词均已按计划完成。实际 11 张武器图需在具备 WanImage 生成能力的环境下手动按 `docs/PIXELLAB_REPLACED_ASSETS.md` 武器表描述词逐条生成，保存至 `assets/weapons/` 后运行 `python scripts/resize_icons_to_spec.py`。
- **预防**：若需在本项目内自动调用 WanImage 生成资产，需确保 AliyunBailianMCP_WanImage 服务器在 mcps 中提供对应 tool 描述符（如 modelstudio_image_gen）。

### 2026-02-19：模态面板白边去除

- **现象**：商店、升级、暂停等模态面板外圈有浅灰/白边
- **原因**：`get_modal_panel_stylebox` 使用 `modal_panel_border` 绘制边框
- **修复**：边框色改为 `modal_panel_bg`，与背景一致，去除可见白边
- **预防**：无边框时使用 borderless 变体（边框色=背景色）

### 2026-02-19：商店 Tab 文字遮盖与下层重复文字

- **现象**：商店 Tab 区选中文字被裁切、标签下有重复文字层、背包 Tab 尺寸过大遮盖下方说明
- **原因**：自定义 TabBar 脚本完全重绘与引擎内部结构冲突产生重复层；rect 扩大导致遮盖
- **修复**：`tab_container_selected_scale.gd` 移除 TabBar 脚本注入，仅保留 panel 背景移除，使用引擎默认 TabBar
- **预防**：避免对 TabBar 做完全重绘式替换；选中态可用主题（tab_selected 样式）区分

### 2026-02-19：商店 TabContainer 下层重复面板

- **现象**：商店面板（WeaponPanel）内，Tab 标签下方出现一层重复的面板背景
- **原因**：TabContainer 默认有 `panel` 主题样式绘制内容区背景，与外层 WeaponPanel 的 modal 样式叠加，形成双层面板
- **修复**：`tab_container_selected_scale.gd` 在 `_ready` 中 `add_theme_stylebox_override("panel", StyleBoxEmpty.new())` 移除 TabContainer 内容区背景
- **预防**：TabContainer 置于 Panel 内时，可移除其 panel 主题以避免重复背景

### 2026-02-19：角色信息面板属性文本贴边

- **现象**：角色信息面板（暂停菜单属性 Tab、HUD 商店角色信息 Tab）内属性文本紧贴边框，无内边距
- **原因**：`build_player_stats_block` 返回的 VBoxContainer 直接加入父容器，未包裹 MarginContainer；且返回的 MarginContainer 未设置 size_flags，在父容器中不扩展时布局异常
- **修复**：`result_panel_shared.gd` 新增 `_wrap_in_margin`，用 MarginContainer（margin_tight=16px）包裹返回值；为 MarginContainer 设置 `size_flags_horizontal/vertical = SIZE_EXPAND_FILL` 确保正确填充父容器
- **预防**：面板内容区需统一内边距时，用 MarginContainer 包裹并设置 size_flags 以正确扩展

### 2026-02-19：背包面板 UI 修复

- **现象**：背包滚动条无效；商店背包两侧空白；文字贴边；背包有白边；首次进入战斗与波次间商店面板样式不一致
- **原因**：ContentPanel 无 ScrollContainer；ShopCenter 为 CenterContainer 导致居中留白；ContentMargin/DetailMargin 仅 8px；get_panel_stylebox_for_bg 使用 modal_panel_border 产生白边；首次打开时布局可能未完成
- **修复**：(1) ContentPanel 内增加 ContentScroll 包裹 LeftVBox；(2) ShopCenter 改为 MarginContainer，MainVbox 增加 size_flags_horizontal=3；(3) ContentMargin/DetailMargin 改为 16px；(4) UiThemeConfig 新增 get_panel_stylebox_borderless，BackpackPanel 改用；(5) show_weapon_shop 末尾 call_deferred("_deferred_ensure_shop_layout")
- **预防**：背包内容区需 ScrollContainer 支持溢出滚动；商店 Tab 内容应铺满宽度；面板内边距参考 margin_tight；无边框样式用 borderless 变体

### 2026-02-19：商店背包 _build_item_tooltip_data 报错

- **现象**：打开武器商店、选择商品时 backtrace 指向 `_build_item_tooltip_data`；报错 `Trying to assign an array of type "Array" to a variable of type "Array[String]"` 或 `_format_item_effect` 内类型转换异常
- **原因**：(1) `[effect_str] if ... else []` 产生无类型 Array，不能赋给 `Array[String]`；(2) `run_items` 含魔法类道具，def 无 `attr`/`base_value`，`val` 可能为 null 或非数值
- **修复**：`effect_parts` 改为先声明 `Array[String]` 空数组，再 `append(effect_str)`；`_format_item_effect` 增加 null/类型/String 校验
- **预防**：GDScript 中 `[x]`、`[]` 为无类型 Array，赋给 `Array[T]` 时需显式构造（如 `var a: Array[String] = []` 再 `append`）

### 2026-02-19：武器 7+ 无图修复

- **现象**：背包中第 7 把及以后的武器槽无图标显示
- **原因**：`player.get_equipped_weapon_details` 中，当 `idx >= _equipped_weapons.size()` 时走占位分支，`icon_path` 写死为 `""`，未从武器 def 读取
- **修复**：占位 dict 的 `icon_path` 改为 `str(def.get("icon_path", ""))`，并补充 `"usable": is_usable`
- **预防**：占位/默认数据需从定义中读取完整字段，避免硬编码空串

### 2026-02-18：玩家子弹发射一段时间后无法再发射

- **现象**：发射一段时间后子弹不再出现，但有发射音效
- **原因**：子弹对象池复用后 `reset_for_pool()` 未重置 `life_time`；玩家子弹在 `_process` 中 `life_time -= delta`，回收时 life_time 已为 0，复用后首帧即 `life_time <= 0` 触发回收，子弹立即消失
- **修复**：`bullet.reset_for_pool()` 增加 `life_time = 2.0`；所有 acquire 子弹处显式设置 `collision_mask`（玩家/魔法=2，敌人=1），因复用节点 _ready 不重跑
- **预防**：对象池 `reset_for_pool` 需重置所有影响复用后行为的属性

### 2026-02-18：pickup body_entered 中回收报错

- **现象**：`Removing a CollisionObject node during a physics callback is not allowed`，backtrace 指向 pickup.gd _on_body_entered → _do_pickup → _recycle_or_free → ObjectPool.recycle
- **原因**：`body_entered` 为物理回调，直接调用 `ObjectPool.recycle` 会执行 `remove_child`，在物理回调中移除 Area2D 不被允许
- **修复**：`_do_pickup` 新增 `defer_recycle` 参数；`_on_body_entered` 调用 `_do_pickup(body, true)`，true 时用 `call_deferred("_recycle_or_free")` 延后回收
- **预防**：物理回调（body_entered、area_entered 等）中移除或回收节点需使用 `call_deferred` 延后执行

### 2026-02-18：pickup configure_for_spawn 时 sprite 为 null

- **现象**：`_apply_coin_visual_by_value` 报错，调用链为 enemy died → _spawn_coin_drop → ObjectPool.acquire(deferred=true) → configure_for_spawn
- **原因**：acquire(deferred=true) 使用 call_deferred 加入 parent，configure_for_spawn 在入树前被调用，此时 @onready sprite 尚未初始化
- **修复**：`_apply_coin_visual_by_value` 开头增加 `if not is_instance_valid(sprite): return`；_ready 入树后会再次调用并正确设置
- **预防**：对象池 deferred add 时，configure 在入树前调用，需对 @onready 子节点做空检查

### 2026-02-18：子弹回收在物理回调中移除 CollisionObject 报错

- **现象**：`Removing a CollisionObject node during a physics callback is not allowed`；`get_tree()` 为 null 导致 `_spawn_hit_flash` 报错
- **原因**：`body_entered` 为物理回调，`_recycle_or_free` 直接调用 `ObjectPool.recycle`，后者执行 `remove_child` 在物理回调中移除节点；回收后节点可能已脱离场景树，后续 `_spawn_hit_flash` 中 `get_tree()` 为 null
- **修复**：`_recycle_or_free` 改用 `call_deferred("_deferred_recycle")` 或 `call_deferred("queue_free")`；`_spawn_hit_flash` 增加 `get_tree()` 空检查
- **预防**：物理回调（body_entered、area_entered 等）中移除节点需使用 `call_deferred` 延后执行

### 2026-02-18：level_config boss_count 自引用

- **现象**：`_get_extended_spawn_orders` 中 `var boss_count := 1 if (wave % 5 == 0 and wave > 0) else boss_count` 的 else 分支引用自身，导致逻辑错误
- **原因**：局部变量 boss_count 在声明时引用自身（应为导出变量 boss_count）
- **修复**：改为 `var boss_num := 1 if (wave % 5 == 0 and wave > 0) else boss_count`，后续使用 boss_num
- **预防**：声明局部变量时避免在初始化表达式中引用同名变量

### 2026-02-17：Tab 与商店系统优化

- **现象**：Tab 样式不统一；设置游戏标签项过多；商店售卖无价格显示；价格公式未含品级系数
- **原因**：各菜单 Tab 独立实现；设置项未精简；售卖价未在 UI 展示；weapon_defs 用 cost 非 base_cost
- **修复**：(1) 所有 TabContainer 字体 20、side_margin/top_margin 16，暂停/结算 Tab 置顶；(2) 设置游戏标签移除移动预设、暂停键、按键提示；(3) stats 增加 wave，BackpackPanel 计算 sell_price 并在 tooltip 显示；(4) weapon_defs cost→base_cost，ShopItemDefs 新增 get_price_with_tier(base,tier,wave)，售卖价=base*tier_coef*wave_coef*0.3
- **预防**：价格公式统一走 ShopItemDefs；基础价格写入各定义文件

### 2026-02-17：hud.gd get_viewport_rect 未找到

- **现象**：`res://scripts/ui/hud.gd` 第 699 行报错 `Function "get_viewport_rect()" not found in base self`
- **原因**：HUD 继承 `CanvasLayer`（继承 `Node`），`get_viewport_rect()` 为 `Viewport`/`Control` 方法，Node 无此方法
- **修复**：改为 `get_viewport().get_visible_rect().size` 获取视口尺寸
- **预防**：在非 Control 节点中获取视口尺寸时，使用 `get_viewport().get_visible_rect().size`

### 2026-02-17：商店背包 Tab 空白

- **现象**：商店内背包 Tab 仅有一个「打开背包」按钮，点击后打开覆盖层；用户反馈「背包页里什么都没有」
- **原因**：背包 Tab 仅有一个按钮，未在 Tab 内直接展示背包内容；用户期望在 Tab 内直接看到背包
- **修复**：背包 Tab 内嵌 `BackpackPanel`（与暂停菜单相同），替代单一按钮；`ScrollContainer` + `BackpackPanel`，`show_weapon_shop` 时调用 `_shop_backpack_panel.set_stats(stats, true)` 刷新；背包 Tab 内直接展示武器/魔法/道具，售卖/合并按钮仅在 shop_context 时显示
- **预防**：商店与暂停菜单的背包展示需用 shop_context 区分；BackpackPanel 需在加入场景树后调用 set_stats

### 2026-02-17：武器合并索引不匹配、无法合并

- **现象**：商店背包内点击合成后选择素材，合并不生效
- **原因**：`get_equipped_weapon_details()` 在 `sync_weapons_from_run` 跳过无效武器时 `continue`，返回的 weapon_details 长度小于 run_weapons，索引不对应；`merge_run_weapons(base_index, material_index)` 期望 run_weapons 索引
- **修复**：(1) `sync_weapons_from_run` 失败项 append null，保证 _equipped_weapons 与 run_weapons 索引 1:1；(2) `get_equipped_weapon_details` 按 run_list 遍历，有效则取详情，null 则用 run 数据构建占位 dict；(3) 迭代 _equipped_weapons 处增加 null 判断
- **预防**：合并等依赖索引的 UI 操作，需保证数据源与 run_weapons 索引一致

### 2026-02-17：商店背包覆盖层 set_stats 时 get_tree 为 null

- **现象**：商店内点击「背包」后报错 `Parameter "data.tree" is null`、`Invalid access to property or key 'root' on a base object of type 'null instance'`，backtrace 指向 backpack_panel.set_stats
- **原因**：`_show_backpack_from_shop` 在 overlay 加入场景树之前就调用了 `backpack_panel.set_stats`，此时节点尚未入树，`get_tree()` 与 `_find_canvas_layer()` 均不可用
- **修复**：将 `hud.add_child(overlay)` 提前到 `set_stats` 之前执行，确保覆盖层已入树再调用 set_stats
- **预防**：对尚未入树的节点调用依赖 `get_tree()` 或父链遍历的方法前，需先将其加入场景树

### 2026-02-17：新游戏商店优先与背包售卖

- **现象**：新游戏默认装备短刀并直接开始波次 1；商店内无法打开背包；背包无法售卖武器；暂停菜单中不应显示售卖/合并按钮
- **原因**：game.gd 在 _ready 中直接装备武器并 setup 波次；商店面板无背包入口；BackpackPanel 无 shop_context 区分
- **修复**：(1) 移除默认武器，_ready 末尾调用 _open_start_shop 显示开局商店（波次 0），首次关闭商店时再 wave_manager.setup；(2) HUD 武器商店增加「背包」按钮，发出 backpack_requested；(3) Game 新增 show_backpack_from_shop，创建背包覆盖层并 set_stats(stats, true)；(4) BackpackPanel.set_stats 增加 shop_context，仅 shop_context=true 时显示售卖/合并；(5) BackpackTooltipPopup 增加售卖按钮与 sell_requested 信号；(6) GameManager 新增 remove_run_weapon；(7) i18n 新增 backpack.sell、backpack.open
- **预防**：商店与暂停菜单的背包展示需用 shop_context 区分；售卖价格 = base_cost * (1+wave*0.15) * 0.3

### 2026-02-17：词条独立面板、图鉴武器词条细分

- **现象**：词条悬浮面板为主 tooltip 子节点，非独立；词条仅显示名称；图鉴词条缺武器-类型、武器-主题子标签
- **原因**：`_affix_tooltip` 通过 add_child 挂到主 tooltip；此前简化仅保留 name_key；词条 Tab 仅 5 个子标签
- **修复**：(1) 词条面板首次显示时加入与主 tooltip 同级（CanvasLayer），position 用屏幕坐标；(2) 恢复 desc+value 双 Label、_effect_type_to_name、_format_bonus；(3) 词条 Tab 新增武器-类型、武器-主题，WeaponTypeAffixDefs/WeaponThemeAffixDefs 各入专属 Tab
- **预防**：独立悬浮面板需与主面板同级；图鉴细分按数据源建 Tab

### 2026-02-17：词条悬浮简化、图鉴语言切换不刷新

- **现象**：词条悬浮面板展示描述+数值较复杂；图鉴切换语言后内容仍为旧语言
- **原因**：词条二级面板为双 Label 结构；`_on_language_changed` 仅更新标题/Tab 标题，未重建 Tab 内条目
- **修复**：(1) 词条悬浮面板简化为单 Label 仅显示名称（name_key 翻译）；(2) `_on_language_changed` 清空 `_tabs` 子节点、重置 `_weapons_sub`/`_affixes_sub`、调用 `_build_tabs()` 重建内容
- **预防**：语言切换时需重建依赖 tr_key 的动态内容；词条悬浮按需简化展示

### 2026-02-17：词条面板定位、背包尺寸、关闭后无法再打开、图鉴英文

- **现象**：词条切换仍不便；背包悬浮面板关闭后可能无法再打开；中文模式下图鉴有英文（HP、effect_type、weapon_type、element 等）
- **原因**：词条面板以主 tooltip 右边界定位仍可能遮挡；is_scheduled_to_hide 阻止新槽位显示；图鉴硬编码或直接显示原始 key
- **修复**：(1) 词条面板改为鼠标定位、AFFIX_TOOLTIP_WIDTH 200、AFFIX_TOOLTIP_FONT_SIZE 14；(2) 主 tooltip TOOLTIP_WIDTH 280→340、TOOLTIP_MAX_HEIGHT 200→280；(3) 移除 BackpackSlot 中 is_scheduled_to_hide 判断；(4) 图鉴所有 stat/effect/element 等改为 tr_key，新增 encyclopedia.*、magic.element_*、pause.stat_fire_rate 等 i18n
- **预防**：词条二级面板优先跟随鼠标；进入新槽位时取消 hide 并显示；图鉴文案统一走 i18n

### 2026-02-17：词条悬浮面板与背包悬浮面板重叠、图鉴细化

- **现象**：词条悬浮面板与背包悬浮面板重叠（同位置同大小），无法切换词条；图鉴武器/词条未细分；道具 Tab 含魔法
- **原因**：词条面板以 chip 为基准定位，靠右时翻到 chip 左侧与主 tooltip 重叠；图鉴道具 Tab 直接遍历 ShopItemDefs.ITEM_POOL（含 type=magic）；武器/词条未细分
- **修复**：(1) `_position_affix_tooltip` 以主 tooltip 右边界为基准，右侧不足时改为主 tooltip 下方，再不足时改左侧；(2) 道具 Tab 过滤 `type=="magic"`；(3) 武器 Tab 嵌套 TabContainer（近战/远程）；(4) 词条 Tab 嵌套 TabContainer（魔法、道具、武器-通用、武器-近战、武器-远程）；(5) 新增 i18n 键 encyclopedia.weapon_melee/ranged、encyclopedia.affix_*
- **预防**：二级 tooltip 定位时避免与主 tooltip 重叠；图鉴道具与魔法数据源分离；细分 Tab 时用嵌套 TabContainer

### 2026-02-17：图鉴文字重叠、词条悬浮面板闪跳、背包悬浮面板误关闭

- **现象**：图鉴名称与描述重叠；词条 chip hover 时二级面板闪跳；打开词条悬浮面板后背包主面板不久消失
- **原因**：图鉴 `_add_entry` 中 MarginContainer 直接添加多个子节点导致布局异常；chip mouse_exited 立即隐藏词条面板，鼠标移向面板前已关闭；主 tooltip mouse_exited 时未判断鼠标是否在词条面板上
- **修复**：(1) 图鉴文本区改为 MarginContainer -> VBoxContainer -> title_lbl, detail_lbl，移除 detail_lbl.size_flags_vertical；(2) 词条面板新增 `_affix_hide_timer`，chip/词条面板 mouse_exited 改为延迟 0.5s 隐藏；(3) 主 tooltip `_on_self_mouse_exited` 检查鼠标是否在词条面板上，若是则不 schedule_hide；(4) HIDE_DELAY 0.4→0.5；(5) BackpackTooltipPopup 新增 `is_scheduled_to_hide()`，BackpackSlot 在关闭期间不响应新槽位
- **预防**：MarginContainer 仅作边距时内层用单一布局容器；悬浮面板离开时统一延迟隐藏，离开前检查鼠标是否在关联面板上

### 2026-02-17：背包悬浮与武器手动合成改造

- **现象**：悬浮面板鼠标移入时易关闭；道具名用词条名不直观；武器自动合成不符合预期；需手动选择素材合成
- **原因**：HIDE_DELAY 过短；道具无 display_name_key；add_run_weapon 内置自动合并逻辑
- **修复**：(1) HIDE_DELAY 0.15→0.4，词条区 HFlowContainer→HBoxContainer 横向排布；(2) shop_item_defs 增加 display_name_key，道具 tooltip 仅展示效果；(3) add_run_weapon 移除自动合并，新增 merge_run_weapons；(4) 武器 tooltip 增加合成按钮，点击进入合并模式，选择素材完成合并，可取消
- **预防**：手动合成需在 UI 层实现选择流程，GameManager 仅提供 merge_run_weapons API

### 2026-02-17：背包悬浮面板词条展示不完整、无法 hover 词条详情

- **现象**：武器 tooltip 仅展示 weapon_upgrades，漏掉 type_affix_id、theme_affix_id、random_affix_ids；道具仅展示词条名称，无描述与数值；鼠标移向 tooltip 时 tooltip 消失，无法对词条 hover 显示详情
- **原因**：tooltip 为单 Label 纯文本，词条构建逻辑未包含完整词条；槽位 mouse_exited 立即 hide，tooltip 为 MOUSE_FILTER_IGNORE 无法接收鼠标
- **修复**：(1) BackpackTooltipPopup 新增 `show_structured_tooltip(data)`，VBoxContainer + 词条 Chip（HFlowContainer），每个 Chip 可 hover 显示二级 tooltip；(2) mouse_filter 改为 STOP，槽位 mouse_exited 调用 `schedule_hide()` 延迟 0.15s，tooltip mouse_entered 取消延迟；(3) BackpackPanel 实现 `_build_weapon_tooltip_data`、`_build_item_tooltip_data` 补全 type/theme/random 词条；(4) BackpackSlot 支持 tip_data 参数，有则用 show_structured_tooltip
- **预防**：结构化 tooltip 需支持延迟隐藏与 mouse_entered 取消，词条 Chip 需单独 Control 以支持 hover

### 2026-02-17：背包悬浮面板无文字、同物体重复生成

- **现象**：背包槽悬浮时弹出的 Tooltip 无任何文字；在同一物体上移动时反复调用 show_tooltip 导致重生成
- **原因**：BackpackTooltipPopup 继承 Popup（Window），挂到 get_tree().root 后与主视口坐标系/渲染上下文不一致，Label 内容不显示；未判断当前 tip 是否与上次相同
- **修复**：(1) 改为继承 PanelContainer，挂到暂停菜单所在 CanvasLayer，保证与暂停菜单同视口；(2) show_tooltip 内若 visible 且 _last_tip == text，仅更新位置不重设文本
- **预防**：自定义 Tooltip 优先挂到与触发控件同视口的 CanvasLayer；同物体悬浮时用 tip 文本去重避免重生成

### 2026-02-17：settings_menu 中 action 未声明、area_shockwave 中 dist_sq 类型推断失败

- **现象**：settings_menu.gd:325/336/342 报 `Identifier "action" not declared in the current scope`；area_shockwave.gd:30 报 `Cannot infer the type of "dist_sq" variable`
- **原因**：settings_menu 在 `_unhandled_input` 中先清空 `_waiting_for_action` 再使用其值，导致 `action` 未定义；area_shockwave 中 `node` 来自 `get_nodes_in_group` 返回的 Array，GDScript 无法推断 `length_squared()` 的返回类型
- **修复**：在清空前 `var action := _waiting_for_action`；为 dist_sq 显式标注 `var dist_sq: float =`
- **预防**：使用会清空的变量前先保存到局部变量；涉及泛型/弱类型表达式时显式标注类型

### 2026-02-17：player、wave_manager 中 INTEGER_DIVISION 与 CONFUSABLE_LOCAL_DECLARATION

- **现象**：player.gd:374 整型除法；wave_manager.gd:160 idx 与父块下方声明混淆；wave_manager.gd:169 整型除法
- **修复**：`/150`→`/150.0`；内层 `idx`→`pos_idx` 避免与 171 行 `idx` 混淆；`size()/temporal_count` 改为 `float(size())/float(temporal_count)` 再取整

### 2026-02-17：visual_asset_registry、game、magic_base 多处 GDScript 警告

- **现象**：UNUSED_PARAMETER（corner_radius、caster）、INTEGER_DIVISION、CONFUSABLE_LOCAL_DECLARATION 等未写入日志
- **修复**：corner_radius→_corner_radius；mini(w,h)/2→int(mini(w,h)/2.0)；game.gd 中 v→v_float 避免与下层 v 混淆；magic_base cast 参数 caster→_caster；扩展 EditorLogger 中继过滤器（confusable_local_declaration、narrowing_conversion、decimal part will be discarded、loses precision 等）
- **说明**：hud.gd NARROWING_CONVERSION 因 _last_mana_current、_last_mana_max 推断为 int 却接收 float，改为 0.0/1.0 声明为 float

### 2026-02-17：ResultPanelShared 静态方法被实例调用触发 STATIC_CALLED_ON_INSTANCE

- **现象**：`action_to_text()` is a static function but was called from an instance
- **原因**：ResultPanelShared 为 autoload 单例，调用 ResultPanelShared.action_to_text() 实为实例调用，而方法声明为 static
- **修复**：移除 action_to_text、build_score_block、build_player_stats_block 的 static 关键字，改为实例方法
- **预防**：autoload 单例上的工具方法若需通过单例名调用，不宜用 static

### 2026-02-17：character_traits_base get_final_damage 中 context 未使用、enemy_base 整型除法

- **现象**：UNUSED_PARAMETER（context）、INTEGER_DIVISION（int(.../150)）
- **修复**：context 改为 _context；150 改为 150.0 避免整型除法

### 2026-02-17：enemy_base take_damage 中 elemental 未使用触发 UNUSED_PARAMETER

- **现象**：GDScript::reload 报错 `The parameter "elemental" is never used in the function "take_damage()"`
- **原因**：基类 `take_damage(amount, elemental)` 暂未使用 elemental 参数，GDScript 要求未用参数加下划线
- **修复**：将参数改为 `_elemental`，子类重写时可使用

### 2026-02-17：FileAccess.READ_WRITE 导致日志文件未创建、调试报错未落盘

- **现象**：调试运行时的报错/警告未出现在 `game_errors.log`
- **原因**：`FileAccess.READ_WRITE` 在文件不存在时返回 null，不创建文件；首次写入被静默跳过
- **修复**：若 `READ_WRITE` 返回 null，则用 `FileAccess.WRITE` 创建文件后再写入
- **预防**：对可能不存在的 user:// 文件，先尝试 READ_WRITE，失败则用 WRITE 创建

### 2026-02-17：GDScript::reload 解析错误未写入 game_errors.log

- **现象**：UNUSED_PARAMETER、STATIC_CALLED_ON_INSTANCE、INTEGER_DIVISION 等 GDScript 解析错误仅出现在 Output 面板，未写入 `game_errors.log`
- **原因**：此类错误走 `_err_print_error` → 引擎 `file_logging` 的 `godot.log`，不经过 `OS.add_logger` 的 Logger 链
- **修复**：EditorLogger 增加定时器，每 2 秒从 `godot.log` 读取新增内容，筛选 GDScript 相关错误行并中继到 `game_errors.log`，前缀 `[EDITOR][RELAY]`
- **预防**：保持 `project.godot` 中 `file_logging` 启用，路径与 EditorLogger 的 `GODOT_LOG_PATH` 一致（默认 `user://logs/godot.log`）

### 2026-02-17：character_traits_base 中 weapon_id 未使用触发 UNUSED_PARAMETER

- **现象**：GDScript::reload 报错 `The parameter "weapon_id" is never used in the function "get_weapon_damage_bonus()"`
- **原因**：基类 `get_weapon_damage_bonus(weapon_id)` 仅返回 0，未使用参数；GDScript 要求未用参数加下划线前缀
- **修复**：将参数改为 `_weapon_id`，表示基类中刻意未使用，子类重写时可使用
- **说明**：GDScript 重载时的报错发生在编辑器进程，现由 EditorLogger 从 godot.log 中继到 game_errors.log

### 2026-02-17：hud.gd 中 reparent(null) 导致 Required object "rp_parent" is null

- **现象**：`_apply_hud_module_backgrounds`、`_wrap_label_in_panel`、`_wrap_anchored_label_in_panel` 报错 `Required object "rp_parent" is null` 及 `Can't add child 'X' to 'Y', already has a parent 'Root'`
- **原因**：`node.reparent(null)` 在 Godot 4 中无效，`reparent()` 要求传入有效的新父节点，传 `null` 会触发引擎报错；且节点未被正确移出，导致后续 `add_child` 时出现「已有父节点」冲突
- **修复**：先创建新 Panel，再调用 `node.reparent(new_panel)` 将节点重父到新 Panel，最后将 Panel 加入原父节点并调整顺序
- **预防**：节点重父时使用 `reparent(new_parent)` 传入目标父节点，禁止使用 `reparent(null)`；参考 BUG_LOG 中「物理回调中生成节点」使用 `call_deferred` 的规则

### 2026-02-17：hud.gd 中 _upgrade_refresh_btn 重复声明

- **现象**：`scripts/ui/hud.gd` 第 34 行报错 `Variable "_upgrade_refresh_btn" has the same name as a previously declared variable.`
- **原因**：`_upgrade_refresh_btn` 在第 33、34 行被重复声明
- **修复**：删除第 34 行重复声明
- **预防**：添加新变量时检查是否已存在同名声明，避免复制粘贴导致重复

### 2026-02-17：_equipped_magics[slot] 返回 Variant 导致 mag 类型推断失败

- **现象**：`scripts/player.gd` 第 281 行报错 `Cannot infer the type of "mag" variable because the value doesn't have a set type.`
- **原因**：`var mag := _equipped_magics[slot]` 中，Array 下标访问返回 Variant，GDScript 无法推断 `mag` 的类型
- **修复**：显式声明类型 `var mag: Dictionary = _equipped_magics[slot]`
- **预防**：从 Array 下标访问获取元素时，若需明确类型，对接收变量显式标注（如 `Dictionary`）

### 2026-02-17：get_reward_value 中 raw 变量类型推断失败

- **现象**：`resources/upgrade_defs.gd` 第 30 行报错 `Cannot infer the type of "raw" variable because the value doesn't have a set type.`
- **原因**：`var raw := float(base_val) + float(level) * scale_val` 中，`base_val` 来自 `upgrade.get("base_value", 0)` 返回 Variant，表达式整体无法被 GDScript 推断为固定类型
- **修复**：显式声明类型 `var raw: float = float(base_val) + float(level) * scale_val`
- **预防**：涉及 `Dictionary.get()` 等返回 Variant 的表达式时，对接收变量显式标注类型（如 `float`、`int`）

### 2026-02-17：item.duplicate(true) 返回 Variant 导致 it 类型推断失败

- **现象**：`game.gd` 第 554 行报错 `Cannot infer the type of "it" variable because the value doesn't have a set type.`
- **原因**：`for item in ShopItemDefs.ITEM_POOL` 中 `item` 来自 const 数组，`item.duplicate(true)` 返回 Variant，GDScript 无法推断 `it` 的类型
- **修复**：显式声明类型 `var it: Dictionary = item.duplicate(true)`
- **预防**：从 const 数组或返回 Variant 的方法（如 `duplicate()`）接收值时，对变量显式标注类型

### 2025-02-16：Array.max() 返回 Variant 导致类型推断警告

- **现象**：`player.gd` 第 123 行报错 `The variable type is being inferred from a Variant value, so it will be typed as Variant. (Warning treated as error.)`
- **原因**：`var max_amount := _pending_damages.max()` 中，`Array.max()` 返回 `Variant`，GDScript 将 `max_amount` 推断为 Variant，在"警告当错误"模式下触发
- **修复**：显式声明类型 `var max_amount: int = _pending_damages.max()`
- **预防**：使用 `Array.max()`、`min()` 等返回 Variant 的方法时，对接收变量显式标注类型（如 `int`、`float`）

### 2026-02-19：Dictionary.get() 方法参数过多错误

- **现象**：`res://scripts/autoload/affix_manager.gd` 第 163 行报错 `Too many arguments for "get()" call. Expected at most 1 but received 2.`
- **原因**：GDScript 中 Dictionary.get(key, default) 语法在当前 Godot 版本中不被支持，Dictionary 的 get 方法只接受一个参数
- **修复**：将所有 `dict.get(key, default)` 调用替换为 `dict.get(key) if dict.has(key) else default` 或 `dict[key] if dict.has(key) else default` 的形式
- **预防**：在使用 Dictionary.get() 时注意 Godot 版本兼容性，使用 has() 检查后再获取值确保安全性

<!-- 示例：
### 2025-02-15：整型除法警告

- **现象**：`int(a/b)` 产生 GDScript 警告
- **原因**：GDScript 中 `/` 为浮点除法，`int()` 转换前需确保类型正确
- **修复**：改为 `int(a / float(b))` 或 `int(a / 4.0)`
- **预防**：避免 `int(a/b)` 写法，显式浮点除法后再取整
-->

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
- **原因**：`var max_amount := _pending_damages.max()` 中，`Array.max()` 返回 `Variant`，GDScript 将 `max_amount` 推断为 Variant，在“警告当错误”模式下触发
- **修复**：显式声明类型 `var max_amount: int = _pending_damages.max()`
- **预防**：使用 `Array.max()`、`min()` 等返回 Variant 的方法时，对接收变量显式标注类型（如 `int`、`float`）

<!-- 示例：
### 2025-02-15：整型除法警告

- **现象**：`int(a/b)` 产生 GDScript 警告
- **原因**：GDScript 中 `/` 为浮点除法，`int()` 转换前需确保类型正确
- **修复**：改为 `int(a / float(b))` 或 `int(a / 4.0)`
- **预防**：避免 `int(a/b)` 写法，显式浮点除法后再取整
-->

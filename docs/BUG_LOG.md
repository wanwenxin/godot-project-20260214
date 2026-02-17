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

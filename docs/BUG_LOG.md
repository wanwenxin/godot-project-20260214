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

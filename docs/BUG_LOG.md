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

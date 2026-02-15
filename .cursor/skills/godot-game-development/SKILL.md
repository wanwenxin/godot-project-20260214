---
name: godot-game-development
description: Follows GDScript conventions, scene layout, and common patterns for Godot 4.x projects. Use when developing Godot games, writing .gd scripts, editing .tscn scenes, or adding new game features. Mandatory: add comments to generated code; reserve extension interfaces for new modules.
---

# Godot 游戏开发规范

开发 Godot 4.x 项目时遵循本规范。**强制要求**：1）生成代码时必须写注释；2）生成新功能模块时必须预留拓展接口。

## 1. 代码注释

生成或修改代码时：

- **文件头**：用 1–3 行注释说明脚本职责
- **复杂逻辑**：在分支、循环、重要算法处加行内或块注释
- **导出变量**：用 `#` 说明用途，必要时说明单位或取值范围

示例：

```gdscript
# 敌人基类：
# - 生命与死亡事件
# - 与玩家碰撞接触伤害
@export var max_health := 25  # 初始生命值
```

## 2. 拓展接口约定

新增功能模块（系统、管理器、子系统）时，必须预留拓展接口：

- **虚方法**：基类定义 `func _on_xxx()` 或 `func _handle_xxx()` 供子类 override
- **信号**：在状态变化或关键事件处 emit 信号，供外部挂接
- **可配置**：用 `@export` 暴露可在编辑器中调节的参数

```gdscript
# 基类预留虚方法
func _before_spawn() -> void:
	pass  # 子类可 override 在生成前执行逻辑

func _after_spawn(node: Node) -> void:
	pass  # 子类可 override 在生成后执行逻辑

signal spawn_requested(type: String, position: Vector2)  # 外部可监听
```

详细模板见 [reference.md](reference.md)。

## 3. GDScript 规范

- **类型标注**：变量、参数、返回值尽量标注类型（`var x: int`、`func f() -> void`）
- **命名**：`snake_case` 变量/函数；`PascalCase` 类/场景
- **常量**：用 `const`，全大写加下划线
- **避免**：`int(a/b)` 整型除法警告 → 用 `int(a / float(b))` 或 `int(a / 4.0)`
- **避免**：参数与基类属性同名（`visible` 等）→ 重命名如 `show_hint`

## 4. 场景与目录结构

| 内容       | 路径                |
|------------|---------------------|
| 全局单例   | `scripts/autoload/` |
| 场景       | `scenes/`           |
| 脚本       | `scripts/`          |
| UI 场景    | `scenes/ui/`        |
| UI 脚本    | `scripts/ui/`       |
| 敌人       | `scenes/enemies/`   |

跨模块通信优先使用信号，避免直接引用其它模块内部实现。

## 5. 常见模式

### 新增敌人

1. 继承 `enemy_base.gd`
2. 新建 `scenes/enemies/*.tscn`
3. 在 `wave_manager.gd` 的 `_start_next_wave()` 中接入生成逻辑

### 新增升级项

1. 在 `game.gd::_upgrade_pool` 增加条目
2. 在 `player.gd::apply_upgrade()` 实现分支
3. 若有新 UI 文案，更新 `hud.gd::show_upgrade_options()`

### 物理回调中生成节点

- 禁止在碰撞回调链中直接 `add_child`
- 使用 `call_deferred("add_child", node)` 或 `call_deferred` 包裹生成逻辑

## 6. 项目参考

- 架构与数据流：`docs/DEVELOPER_GUIDE.md`
- 核心脚本示例：`scripts/game.gd`、`scripts/enemy_base.gd`

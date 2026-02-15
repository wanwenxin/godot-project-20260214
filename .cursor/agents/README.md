# Godot 游戏开发 Subagents

本目录包含面向 Godot 4.x 项目的自定义子代理，可与主代理协同完成复杂任务。

## 子代理列表

| 名称 | 用途 | 调用示例 |
|------|------|----------|
| **godot-implementer** | 新增功能模块（敌人、升级、地形、UI 等） | `/godot-implementer 添加一种会冲刺的敌人` |
| **godot-scene-designer** | 场景与节点结构、信号连接 | `/godot-scene-designer 重构主菜单场景结构` |
| **godot-debugger** | Godot 特有错误排查 | `/godot-debugger 报错 flushing queries` |

## 使用方式

1. **自动委托**：主代理会根据任务复杂度与描述自动选择合适的子代理
2. **显式调用**：在提示词中使用 `/子代理名 任务描述`
3. **自然提及**：如 "用 godot-debugger 排查这个错误"

## 与 Skills 的关系

- **Skills**（`.cursor/skills/godot-game-development`）：提供 GDScript 规范、注释与拓展接口等「规则」
- **Subagents**：在独立上下文中执行具体任务，可并行处理不同子问题

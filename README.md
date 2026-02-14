# Potato Style Demo (Godot 4)

一个基于 Godot 4 的 2D 单人波次生存射击 Demo，玩法参考 Brotato 风格：

- 单人游戏
- 2 个可选角色
- 自动瞄准 + 远程射击
- 2 种敌人（近战/远程）
- 敌人碰撞伤害
- 本地存档
- 无外部美术资源（运行时生成像素贴图）

## 1. 运行方式

1. 使用 Godot 4.x 打开项目根目录。
2. 运行主场景：`res://scenes/main_menu.tscn`（项目已配置为 main scene）。
3. 菜单中选择 `NewGame`，在角色页选择角色后进入战斗。

### 操作说明

- `W/A/S/D`: 移动
- `P`: 暂停/继续
- 射击：自动朝最近敌人射击

## 2. 目录结构

```text
res://
├─ scenes/
│  ├─ main_menu.tscn
│  ├─ character_select.tscn
│  ├─ game.tscn
│  ├─ player.tscn
│  ├─ bullet.tscn
│  ├─ enemies/
│  │  ├─ enemy_melee.tscn
│  │  └─ enemy_ranged.tscn
│  └─ ui/
│     ├─ hud.tscn
│     └─ pause_menu.tscn
├─ scripts/
│  ├─ autoload/
│  │  ├─ game_manager.gd
│  │  └─ save_manager.gd
│  ├─ game.gd
│  ├─ player.gd
│  ├─ weapon.gd
│  ├─ bullet.gd
│  ├─ enemy_base.gd
│  ├─ enemy_melee.gd
│  ├─ enemy_ranged.gd
│  ├─ wave_manager.gd
│  ├─ pixel_generator.gd
│  └─ ui/
│     ├─ main_menu.gd
│     ├─ character_select.gd
│     ├─ hud.gd
│     └─ pause_menu.gd
└─ project.godot
```

## 3. 核心系统说明

### 3.1 全局管理

- `scripts/autoload/game_manager.gd`
  - 管理场景切换（主菜单、角色选择、游戏）
  - 维护角色模板数据
  - 记录本局结算结果并调用存档更新

- `scripts/autoload/save_manager.gd`
  - 本地 JSON 存档读写
  - 维护统计字段：
    - `best_wave`
    - `best_survival_time`
    - `total_kills`
    - `last_character_id`

### 3.2 战斗核心

- `scripts/game.gd`
  - 生成玩家
  - 初始化波次管理
  - 更新存活时间 HUD
  - 处理暂停、死亡结算、重开与回主菜单

- `scripts/player.gd`
  - 移动输入
  - 自动索敌
  - 受伤与无敌帧
  - 角色参数应用（血量、移速、射速、伤害等）

- `scripts/weapon.gd` + `scripts/bullet.gd`
  - 武器冷却与发射
  - 子弹飞行与命中判定
  - 通过 `hit_player` 区分我方/敌方子弹阵营

### 3.3 敌人与波次

- `scripts/enemy_base.gd`
  - 敌人通用生命、接触伤害、死亡信号
  - 通用追踪逻辑

- `scripts/enemy_melee.gd`
  - 直接追击玩家

- `scripts/enemy_ranged.gd`
  - 维持距离并周期射击

- `scripts/wave_manager.gd`
  - 维护波次、击杀、存活敌人数
  - 每波动态生成近战/远程敌人
  - 清场后间隔进入下一波
  - 难度随波次递增（数量、生命、速度）

### 3.4 像素资源生成

- `scripts/pixel_generator.gd`
  - 使用 `Image` 运行时生成玩家/敌人/子弹贴图
  - 无需外部 PNG 资源即可运行

## 4. 角色与敌人

### 角色

1. `RapidShooter`
   - 射速快
   - 单发伤害低
   - 移速较快

2. `HeavyGunner`
   - 射速慢
   - 单发伤害高
   - 移速较慢

### 敌人

1. `MeleeEnemy`
   - 主动追击
   - 接触造成伤害

2. `RangedEnemy`
   - 与玩家保持距离
   - 发射敌方子弹
   - 也可通过接触造成伤害

## 5. 存档说明

- 存档路径：`user://savegame/save.json`
- 游戏结束时自动更新统计数据
- 主菜单会读取并显示关键统计

## 6. 已知限制

- 当前没有音效与背景音乐。
- 当前没有升级/天赋系统（可在波次清场后扩展）。
- 敌人 AI 为轻量实现，适合 Demo 原型阶段。

## 7. 后续可扩展方向

- 波次结束升级选择（3 选 1）
- 武器词条和多武器系统
- 掉落经验与等级成长
- Boss 波次
- 更完整的视觉特效（命中闪烁、死亡爆裂等）

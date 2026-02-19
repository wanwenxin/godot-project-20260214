# 游戏内视觉与数值常量：角色/敌人/BOSS/子弹等缩放与速度，便于统一调参。
# 修改本文件即可调整全局限定，无需在各脚本中查找硬编码。

extends Node

## 玩家节点整体缩放倍率（相对原始精灵尺寸）
const PLAYER_SCALE := 3.0
## 普通敌人体积缩放倍率（与玩家一致）
const ENEMY_SCALE := 3.0
## BOSS 体积缩放倍率（至少为玩家的 5 倍视觉，玩家已 3 倍故取 15）
const BOSS_SCALE := 15.0
## 子弹（玩家/敌人通用）体积缩放倍率
const BULLET_SCALE := 2.0
## 敌人血条上方元素附着图标的缩放倍率（小图标避免盖住敌人）
const ELEMENT_ICONS_SCALE := 0.1
## 敌人子弹飞行速度（较玩家子弹慢，便于玩家反应；约原 180 的 70%）
const ENEMY_BULLET_SPEED := 126.0

# ---- 摄像机 ----
## 摄像机缩放默认值（<1 为靠近地面）
const CAMERA_ZOOM_DEFAULT := 0.8
## 摄像机缩放下限（更近）
const CAMERA_ZOOM_MIN := 0.7
## 摄像机缩放上限（更远）
const CAMERA_ZOOM_MAX := 1.3
## 每次按键缩放变化量
const CAMERA_ZOOM_STEP := 0.05
## 玩家偏离视口中心超过此比例时摄像机开始跟随
const CAMERA_DEAD_ZONE_RATIO := 0.30

# ---- 地形与移动 ----
## 单块地形面积倍率，线性约 sqrt 倍
const ZONE_AREA_SCALE_DEFAULT := 5.0
## 草地等地形默认速度倍率（进入时移速乘以此值）
const TERRAIN_SPEED_MULTIPLIER_DEFAULT := 0.9
## 地形速度倍率 clamp 下限（避免过慢）
const TERRAIN_SPEED_CLAMP_MIN := 0.2
## 地形速度倍率 clamp 上限（避免过快）
const TERRAIN_SPEED_CLAMP_MAX := 1.2

# ---- 玩家 ----
## 受击后无敌时长（秒）
const INVULNERABLE_DURATION_DEFAULT := 0.5
## 移动惯性系数默认值，0=无惯性
const INERTIA_FACTOR_DEFAULT := 0.0
## 移动惯性系数上限（设置与 clamp 用）
const INERTIA_FACTOR_MAX := 0.9

# ---- 波次与生成 ----
## 每波最大时长（秒），倒计时归零视为波次结束
const WAVE_DURATION_DEFAULT := 20.0
## 生成警示圈显示时长（秒）
const TELEGRAPH_DURATION_DEFAULT := 0.9
## 地图刷新后、敌人生成前的倒计时（秒）
const PRE_SPAWN_COUNTDOWN_DEFAULT := 3.0
## 波次间隔时长（秒）
const INTERMISSION_TIME_DEFAULT := 3.5
## 敌人死亡掉落金币概率 0~1
const COIN_DROP_CHANCE_DEFAULT := 0.38
## 敌人死亡掉落治疗概率 0~1
const HEAL_DROP_CHANCE_DEFAULT := 0.17
## 每波生成批次数
const SPAWN_BATCH_COUNT_DEFAULT := 3
## 每批生成间隔（秒）
const SPAWN_BATCH_INTERVAL_DEFAULT := 6.0
## 出生点数量
const SPAWN_POSITIONS_COUNT_DEFAULT := 5

# ---- 游戏流程 ----
## 通关波次（达到后显示通关界面）
const VICTORY_WAVE_DEFAULT := 5
## 刷新升级选项消耗的金币数
const UPGRADE_REFRESH_COST := 2

# ---- 敌人 ----
## BOSS 射击冷却间隔（秒）
const BOSS_FIRE_RATE_DEFAULT := 0.95
## BOSS 移动速度倍率（相对正常追击）
const BOSS_MOVE_SCALE := 0.55
## 冲刺怪：冲刺冷却（秒）
const DASH_COOLDOWN_DEFAULT := 2.5
## 冲刺怪：冲刺速度
const DASH_SPEED_DEFAULT := 380.0
## 冲刺怪：冲刺持续时间（秒）
const DASH_DURATION_DEFAULT := 0.55
## 冲刺怪：蓄力时长（秒）
const WIND_UP_DURATION_DEFAULT := 0.4
## 冲刺怪：冲刺后恢复时长（秒）
const RECOVER_DURATION_DEFAULT := 0.3
## 冲刺怪：非冲刺时移动速度倍率
const DASHER_IDLE_MOVE_SCALE := 0.6

# ---- 子弹与魔法 ----
## 子弹默认存活时间（秒），超时销毁
const BULLET_LIFE_TIME_DEFAULT := 2.0
## 燃烧效果默认持续时长（秒）
const BURN_DURATION_DEFAULT := 4.0

# ---- 经验 ----
## 经验曲线基数，升级所需 = XP_BASE * (level ^ XP_CURVE)
const XP_BASE := 50
## 经验曲线指数
const XP_CURVE := 1.2

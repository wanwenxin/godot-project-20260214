extends RefCounted
class_name TierConfig

# 品级系统统一配置：
# - 品级颜色（武器名、UI 显示）
# - 伤害倍率、冷却倍率（品级越高伤害越高、冷却越短）
# - 道具品级倍率（固定品级时 base_value * multiplier）

## 品级颜色映射：0=灰白、1=绿、2=蓝、3=紫、4+=金
const TIER_COLORS := [
	Color(0.85, 0.85, 0.88, 1.0),   # tier 0: 灰白
	Color(0.35, 0.85, 0.45, 1.0),   # tier 1: 绿
	Color(0.40, 0.65, 0.95, 1.0),   # tier 2: 蓝
	Color(0.75, 0.45, 0.95, 1.0),   # tier 3: 紫
	Color(0.95, 0.75, 0.25, 1.0),   # tier 4+: 金
]

## 伤害倍率：tier 0 = 1.0，每级 +20%
const DAMAGE_SCALE_PER_TIER := 0.20
## 冷却倍率：tier 0 = 1.0，每级 -10%（冷却缩短）
const COOLDOWN_REDUCE_PER_TIER := 0.10
## 道具/魔法品级倍率：base_value * (1 + tier * scale)
const ITEM_TIER_SCALE := 0.15


## 获取品级对应颜色；超出预设则用最高档。
static func get_tier_color(tier: int) -> Color:
	var idx := clampi(tier, 0, TIER_COLORS.size() - 1)
	return TIER_COLORS[idx]


## 伤害倍率：1.0 + tier * 0.2
static func get_damage_multiplier(tier: int) -> float:
	return 1.0 + maxi(0, tier) * DAMAGE_SCALE_PER_TIER


## 冷却倍率：1.0 - tier * 0.1，最小 0.5
static func get_cooldown_multiplier(tier: int) -> float:
	return maxf(0.5, 1.0 - maxi(0, tier) * COOLDOWN_REDUCE_PER_TIER)


## 道具/魔法品级倍率：1.0 + tier * 0.15
static func get_item_tier_multiplier(tier: int) -> float:
	return 1.0 + maxi(0, tier) * ITEM_TIER_SCALE

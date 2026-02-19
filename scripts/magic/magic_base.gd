extends RefCounted
class_name MagicBase

# 魔法基类：定义 cast(caster, target_dir) 接口，子类实现具体弹道与命中逻辑。
# 威力、消耗、冷却由 def 提供；元素、范围、效果由词条解析。
var magic_id := ""
var mana_cost := 0
var power := 0
var element := ""
## （已弃用）原施法模式，现已统一为 targeting 流程；保留仅作兼容，不再用于分支。
var cast_mode := "projectile"
## 范围类型："line" | "mouse_circle" | "char_circle"
var range_type := "line"
## 范围尺寸：line 时为宽度，circle 时为半径
var range_size := 40.0
## 效果类型："shockwave" 一次伤害 | "burn" 持续伤害 | pull_line/push_line/pull_circle/push_circle
var effect_type := "shockwave"
## 持续伤害参数（effect_type=burn 时有效）
var burn_duration := GameConstants.BURN_DURATION_DEFAULT
var burn_damage_per_tick := 8
var burn_interval := 0.5


## 从 def 配置，tier 影响 power 与 mana_cost；元素、范围、效果从词条解析。
func configure_from_def(def: Dictionary, tier: int = 0) -> void:
	var base_power := int(def.get("power", power))
	var base_cost := int(def.get("mana_cost", mana_cost))
	var mult: float = TierConfig.get_item_tier_multiplier(tier)
	power = int(float(base_power) * mult)
	mana_cost = maxi(1, int(float(base_cost) * mult))
	magic_id = str(def.get("id", magic_id))
	# 从词条解析元素
	var elem_affix := MagicAffixDefs.get_affix_def(str(def.get("element_affix_id", "")))
	element = str(elem_affix.get("element", "")) if not elem_affix.is_empty() else ""
	# 从词条解析范围
	var range_affix := MagicAffixDefs.get_affix_def(str(def.get("range_affix_id", "")))
	if not range_affix.is_empty():
		range_type = str(range_affix.get("range_type", "line"))
		range_size = float(range_affix.get("value_default", 40.0))
		cast_mode = "area" if range_type != "line" else "projectile"
	else:
		range_type = "line"
		range_size = 40.0
		cast_mode = "projectile"
	# 从词条解析效果
	var effect_affix := MagicAffixDefs.get_affix_def(str(def.get("effect_affix_id", "")))
	if not effect_affix.is_empty():
		effect_type = str(effect_affix.get("effect_type", "shockwave"))
		burn_duration = float(effect_affix.get("burn_duration", GameConstants.BURN_DURATION_DEFAULT))
		burn_damage_per_tick = int(effect_affix.get("burn_damage_per_tick", 8))
		burn_interval = float(effect_affix.get("burn_interval", 0.5))
	else:
		effect_type = "shockwave"


func cast(_caster: Node2D, _target_dir: Vector2) -> bool:
	# 子类 override：生成弹道/范围效果，命中敌人时调用 enemy.take_damage(power, element)
	return false


## 区域型魔法：在世界坐标施放。子类 override。
func cast_at_position(_caster: Node2D, _world_pos: Vector2) -> bool:
	return false

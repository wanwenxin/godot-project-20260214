extends RefCounted
class_name MagicBase

# 魔法基类：定义 cast(caster, target_dir) 接口，子类实现具体弹道与命中逻辑。
# 品级影响 power 与 mana_cost。
var magic_id := ""
var mana_cost := 0
var power := 0
var element := ""


## 从 def 配置，tier 影响 power 与 mana_cost 倍率。
func configure_from_def(def: Dictionary, tier: int = 0) -> void:
	var base_power := int(def.get("power", power))
	var base_cost := int(def.get("mana_cost", mana_cost))
	var mult: float = TierConfig.get_item_tier_multiplier(tier)
	power = int(float(base_power) * mult)
	mana_cost = maxi(1, int(float(base_cost) * mult))
	element = str(def.get("element", element))
	magic_id = str(def.get("id", magic_id))


func cast(_caster: Node2D, _target_dir: Vector2) -> bool:
	# 子类 override：生成弹道/范围效果，命中敌人时调用 enemy.take_damage(power, element)
	return false

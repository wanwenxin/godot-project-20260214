extends RefCounted
class_name MagicBase

# 魔法基类：定义 cast(caster, target_dir) 接口，子类实现具体弹道与命中逻辑。
var magic_id := ""
var mana_cost := 0
var power := 0
var element := ""


func cast(caster: Node2D, target_dir: Vector2) -> bool:
	# 子类 override：生成弹道/范围效果，命中敌人时调用 enemy.take_damage(power, element)
	return false

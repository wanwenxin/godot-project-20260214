extends CharacterTraitsBase
class_name RapidShooterTraits

# RapidShooter 角色特质：
# - 伤害加成系数 1.15
# - 火属性附魔（攻击自带火属性）

func get_damage_multiplier() -> float:
	return 1.15


func get_elemental_enchantment() -> String:
	return "fire"
